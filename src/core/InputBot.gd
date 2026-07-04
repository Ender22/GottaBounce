class_name InputBot
extends RefCounted
## Human-sim bot (INV-8): emits InputIntent like a human, no cheating. Difficulty via a BotProfile
## (lethality spec §3.1). Decisions refresh on reaction_time; survival recovery is reflexive.
##
## v2 intent model (lethality spec §3): the readable rhythm is
##   bounce -> hunt -> AIM -> BLAST -> dive to refuel -> repeat
## The skill axes are aim quality (aim_error + target_lead) and aim speed (super_aim_time).
## There is no power to bank — every super is full power — so "bank-then-strike" is dead;
## refuel_floor gates attack runs on travel + post-miss escape budget instead.

# dodge_super trigger geometry (spec §3.1 dial definition: "enters AIM within 500px with their
# aim within 0.5 rad of me") — part of the dial's contract, not a game-feel constant.
const DODGE_SENSE_RANGE := 500.0
const DODGE_AIM_CONE := 0.5

# --- Void-avoidance geometry (CD verdict #4 self-suicide fix). The bot-as-human-sim treats off-island
# OPEN SPACE (no landing surface below) as DANGER: it won't drift/boost out over the void without the
# fuel + trajectory to reach a surface, aborts a doomed traversal, uses the recovery gamble when knocked
# over the void, and won't whiff a super out over open void. These are bot SPATIAL-REASONING constants
# (geometry-generic, derived by raycast — no hardcoded pit coords), NOT fenced game-feel Tuning. ---
const VOID_PROBE_DROP := 2200.0        # ray length probing for a landing surface below (matches _ground_below)
const VOID_FUTURE_LOOKAHEAD := 0.45    # s of current velocity used to anticipate drifting over the void
const VOID_LAND_MARGIN := 180.0        # aim this far ABOVE a target surface top so we clear the lip
const VOID_LAND_NUDGE := 150.0         # aim this far PAST the island lip so we land with runway, not on the edge
const CROSS_FUEL_PER_PX := 0.045       # est. fuel to translate 1px horizontally under boost (100/3.5s @ 760px/s)
const CROSS_FUEL_RESERVE := 10.0       # fuel to keep after reaching a landing (> super_boost_min_fuel=5)
const SUPER_CARRY := 720.0             # est. horizontal carry of a WHIFFED super (self-ringout range)

var me: Player
var arena
var profile: BotProfile
var level := 3
var _intent := InputIntent.new()
var _pu_use_timer := -1.0    # counts down to using a held powerup (v1: minimal bot behavior)
var _had_powerup := false
var _react := 0.0
var _cached_aim := Vector2.ZERO
var _cached_boost := false
var _cached_super := false   # decision to press super (enter AIM) this frame
var _hunt := false
var _commit_t := 0.0         # rolled hunt stays TRUE this long (§3.1 commit_time)
var _target = null           # committed target (Player)
var _my_aim_t := 0.0         # time spent in my own AIM state
var _aim_roll := 0.0         # current aim-jitter roll (re-rolled per reaction tick while aiming)
var _dodge_dir := Vector2.ZERO   # pending dodge-super direction (fires snap, §3.2 rule 5)
var _dodged := {}            # enemy instance_id -> fired a dodge for their current aim window
var _finisher := false       # §5.5: down to <= finisher_opponents_left living opponents -> commit-mode
                             # runtime-only dial overrides (never mutates profile; reverts on stage reset)
# --- v1_kill_economy §2c flee-to-heal RETREAT state ---
var _retreat := false        # currently fleeing to safe ground to heal
var _retreat_t := 0.0        # seconds spent in the current RETREAT (anti-permanent-evasion cap)
var _retreat_target := Vector2.ZERO  # the safe-platform position being fled to

func _init(player: Player, arena_ref, bot_level := 3) -> void:
	me = player
	arena = arena_ref
	level = bot_level
	profile = BotProfile.for_level(bot_level)

## §5.5: count living opponents from the EXISTING arena.players contract (valid, not me, not dead) —
## same predicate PartyMatch.nearest_opponent uses. No new arena field (§9 contract untouched).
func _alive_opponents() -> int:
	if arena == null or not ("players" in arena):
		return 99
	var n := 0
	for p in arena.players:
		if p == me or not is_instance_valid(p) or p.is_dead():
			continue
		n += 1
	return n

# --- Effective dials (§5.5): profile value outside the endgame; finisher override at <=1 opponent.
# Aim quality (aim_error, target_lead, super_aim_time, reaction_time) has NO accessor — it is never
# overridden. These raise COMMITMENT only.
func _eff_aggression() -> float:
	return maxf(profile.aggression, Tuning.finisher_aggression_floor) if _finisher else profile.aggression

func _eff_attack_range() -> float:
	if not _finisher:
		return profile.attack_range
	# §2b: scale the finisher AIM-entry range with arena width (close-then-blast on a huge map).
	# Width factor clamps to 1.0 on the small arena -> byte-identical to the shipped §5.5 there.
	var wf: float = clampf(_bounds().size.x / Tuning.finisher_range_width_ref, 1.0, Tuning.finisher_range_width_max)
	return profile.attack_range * Tuning.finisher_attack_range_mult * wf

func _eff_commit_time() -> float:
	return maxf(profile.commit_time, Tuning.finisher_commit_time_floor) if _finisher else profile.commit_time

func _eff_refuel_floor() -> float:
	return Tuning.finisher_refuel_floor if _finisher else profile.refuel_floor

func _eff_dodge_super() -> float:
	return minf(profile.dodge_super, Tuning.finisher_dodge_super_cap) if _finisher else profile.dodge_super

func poll() -> InputIntent:
	var it := _intent
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	it.use_powerup = false
	it.flap = false
	it.super_hold = false
	_react -= dt
	_commit_t = maxf(0.0, _commit_t - dt)
	if _retreat:
		_retreat_t += dt   # anti-permanent-evasion cap counts on the wall clock (§2c)
	if me == null or not is_instance_valid(me) or me.is_dead():
		it.aim = Vector2.ZERO
		it.boost = false
		return it
	_clean_dodge_flags()
	# §5.5: finisher mode is a per-poll runtime flag — recomputed from the live alive-count every
	# tick, so it reverts automatically when a stage reset repopulates the arena. Dial overrides are
	# read through the _eff_* accessors below; profile is never mutated (INV-8: commitment, not aim).
	_finisher = _alive_opponents() <= Tuning.finisher_opponents_left
	# --- own AIM state: steer the led solution, fire when good enough or timed out (§3.2 rule 1)
	if me.is_super_aiming():
		_my_aim_t += dt
		_tick_aiming(it)
		return it
	_my_aim_t = 0.0
	# Recovery is re-evaluated EVERY frame (not just on reaction_time): bailing out of a fall is
	# reflexive, and waiting up to reaction_time to react is what sends bots off the map.
	if _danger_recover(it):
		return it
	if _react <= 0.0:
		_react = profile.reaction_time
		# dodge-super roll first (§3.2 rule 5): the human commits to an aim, the menace bots MOVE
		if _check_dodge():
			_cached_super = true
		else:
			_decide()
	it.aim = _cached_aim
	it.boost = _cached_boost
	if _cached_super:
		_cached_super = false
		it.super_hold = true   # press: Player enters AIM this frame; _tick_aiming takes over next
		it.boost = false
		_aim_roll = randf_range(-profile.aim_error, profile.aim_error)
	_tick_powerup(it, dt)
	# Steer the thrust around walls/platforms so the bot stops boosting straight into geometry.
	if it.boost:
		it.aim = _steer(it.aim)
	return it

## While in the AIM state: keep steering at the led target; fire (release) when the current
## jitter roll is inside aim_error * 0.5, or when super_aim_time runs out (§3.2 rule 1).
## Low-lead bots still whiff constantly — the comedy survives, the freeze-and-pray doesn't.
func _tick_aiming(it: InputIntent) -> void:
	it.boost = false
	var desired := Vector2.UP
	var fire := false
	if _dodge_dir != Vector2.ZERO:
		# dodge-super: snap-fire perpendicular/away as soon as the aim registers
		desired = _dodge_dir
		fire = _my_aim_t >= maxf(profile.reaction_time * 0.5, 0.08)
	elif _in_danger():
		# recovery super: snap-aim back at the stage; recovery_skill governs aim/timing only —
		# the blast itself is always full power (L1's comedy self-destructs get BIGGER)
		desired = _recovery_dir()
		if randf() > profile.recovery_skill:
			desired = desired.rotated(randf_range(-0.8, 0.8))
		fire = _my_aim_t >= lerpf(0.6, 0.12, profile.recovery_skill)
	else:
		var t = _target
		if t == null or not is_instance_valid(t) or t.is_dead():
			t = arena.nearest_opponent(me)
		if t == null:
			fire = true
		else:
			if _react <= 0.0:
				_react = profile.reaction_time
				_aim_roll = randf_range(-profile.aim_error, profile.aim_error)
			desired = _led_dir(t).rotated(_aim_roll)
			fire = absf(_aim_roll) < profile.aim_error * 0.5
	if _my_aim_t >= profile.super_aim_time:
		fire = true   # L1 hangs comically (sometimes hits the 2s auto-fire); L5 snap-fires
	it.aim = desired
	it.super_hold = not fire
	if fire:
		_dodge_dir = Vector2.ZERO

## Aim at the led intercept point (§3.1 target_lead — the single biggest hit-rate fix):
## target_pos + target_vel * (dist / super_boost_impulse_full) * target_lead.
func _led_dir(t) -> Vector2:
	var d: Vector2 = t.global_position - me.global_position
	var lead_t: float = (d.length() / Tuning.super_boost_impulse_full) * profile.target_lead
	var predicted: Vector2 = t.global_position + t.velocity * lead_t
	var dir := predicted - me.global_position
	return dir.normalized() if dir.length() > 0.01 else Vector2.UP

func _bounds() -> Rect2:
	return arena.bounds

func _stage() -> Rect2:
	if arena.has_method("stage_rect"):
		return arena.stage_rect()
	var b := _bounds()
	return b

func _stage_center() -> Vector2:
	if arena.has_method("stage_center"):
		return arena.stage_center()
	return _stage().get_center()

func _in_danger() -> bool:
	var pos: Vector2 = me.global_position
	# already over open void (no landing surface anywhere below) -> reflexive recovery, top priority
	if _over_void(pos):
		return true
	var future: Vector2 = pos + me.velocity * 0.6
	var outside_soon := not _bounds().grow(-80.0).has_point(future)
	var off_stage := not _stage().grow(440.0).has_point(pos)
	if outside_soon or off_stage:
		return true
	# ANTICIPATORY void-abort: about to DRIFT out over the void with no fuel to reach the island in the
	# heading direction. A REACHABLE, deliberate crossing is NOT flagged (so bots still fly gaps & fight);
	# only a doomed drift aborts. Falling straight into a gap (no horizontal heading) always aborts.
	var soon: Vector2 = pos + me.velocity * VOID_FUTURE_LOOKAHEAD
	if _over_void(soon):
		var dir_x := signf(me.velocity.x)
		if dir_x == 0.0:
			return true
		var lo: float = _bounds().position.x + 60.0
		var hi: float = _bounds().end.x - 60.0
		var limit: float = hi if dir_x > 0.0 else lo
		var head_x := _scan_ground_x(clampf(pos.x, lo, hi), limit, dir_x)
		if is_nan(head_x) or not _can_reach(absf(head_x - pos.x)):
			return true
	return false

func _recovery_dir() -> Vector2:
	# back toward the nearest REACHABLE landing surface (never stage_center — on islands_void the
	# stage-rect center sits over a void gap; aiming there dives bots INTO the chasm).
	var dir := _land_target(me.global_position) - me.global_position
	return dir.normalized() if dir.length() > 1.0 else Vector2.UP

## Reflexive survival (§3.2 rule 4 — untouched top priority): if knocked off the stage or about
## to leave the arena, boost back toward the platforms. When boost can't win (tank nearly dry or
## momentum too hot), gamble the recovery super — always full power now (§1).
func _danger_recover(it: InputIntent) -> bool:
	if not _in_danger():
		return false
	var land := _land_target(me.global_position)
	var dir := land - me.global_position
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.UP
	var land_dist := me.global_position.distance_to(land)
	# low recovery_skill: panic flail (the funny death). high skill: clean, hard recovery.
	if randf() > profile.recovery_skill:
		dir = dir.rotated(randf_range(-0.8, 0.8))
	else:
		dir = _steer(dir)
	it.aim = dir
	it.boost = me.fuel > 4.0
	it.super_hold = false
	it.use_powerup = false
	if me.wings_flaps > 0:
		it.flap = randf() < 0.5
	# recovery super (the gamble, spec §1.3): boost alone can't reel in a hot launch, an empty tank, or
	# a landing too far to reach on the tank we have while stranded over the void — enter AIM and let
	# _tick_aiming snap the counter back at the island.
	var out_speed: float = -me.velocity.dot(dir)
	var stranded: bool = _over_void(me.global_position) and not _can_reach(land_dist)
	if me.fuel >= Tuning.super_boost_min_fuel and (me.fuel <= 12.0 or out_speed > 1400.0 or stranded):
		it.super_hold = true
		it.boost = false
	_cached_aim = dir
	_cached_boost = it.boost
	return true

## Reaction-tick decision (§3.2): refuel rhythm > hunt/AIM > drift home.
func _decide() -> void:
	var pos: Vector2 = me.global_position
	_cached_super = false
	# --- refuel rhythm (rule 2): below the floor, dive to a bounce surface — one bounce re-arms
	if me.fuel < _eff_refuel_floor():
		var sr := _stage()
		var desired_x := pos.x
		# §2a: a finisher refuels IN-TRANSIT — bias the dive x toward the lone opponent so every
		# refuel bounce advances the chase (never retreat away from the lone target to refuel).
		if _finisher:
			var opp = arena.nearest_opponent(me)
			if opp != null and is_instance_valid(opp):
				desired_x = opp.global_position.x
		# §4/§2 pathing: dive to a real bounce SURFACE, never straight down into the OPEN pit (the
		# removed mid-pit bridge left empty air at mid-x — a naive current-x dive self-destructs).
		# Ray-probe for ground below; snap to the nearest floored column if over a gap.
		var tx := _refuel_x(desired_x, sr, pos.y)
		var target := Vector2(tx, sr.end.y)
		var dir := (target - pos).normalized()
		_cached_aim = dir
		# boost if falling AWAY from the surface, OR if we must TRANSLATE horizontally to reach
		# ground (over the pit): otherwise the bot just drops straight into the gap.
		var must_cross: bool = absf(tx - pos.x) > 120.0
		_cached_boost = me.fuel > 2.0 and (me.velocity.dot(dir) < -60.0 or must_cross)
		_hunt = false
		return
	# §2c flee-to-heal RETREAT: a wounded bot may break off to safe ground to heal, bounded by
	# flee_max / finisher_flee_max so the chaser always closes. Evaluated AFTER refuel (secure fuel
	# first) and AFTER reflexive _danger_recover (checked in poll — safety always wins).
	if _update_retreat(pos):
		return
	# §2a finisher PURSUE: beeline straight at the lone survivor — no stage-center diversion, never
	# disengage on distance. Reflexive _danger_recover already preempted this in poll (safety first).
	if _finisher:
		var fopp = _pick_target()
		if fopp == null or not is_instance_valid(fopp) or fopp.is_dead():
			fopp = arena.nearest_opponent(me)
		if fopp != null and is_instance_valid(fopp):
			_target = fopp
			var fd: Vector2 = fopp.global_position - pos
			var fdist := fd.length()
			_cached_aim = _jitter(fd.normalized())
			_hunt = true
			_commit_t = _eff_commit_time()
			_cached_boost = fdist > _eff_attack_range() * 0.8 and me.fuel > _eff_refuel_floor()
			if fdist < _eff_attack_range() and me.fuel >= _eff_refuel_floor() \
					and _super_safe(pos, fopp.global_position):
				_cached_super = true
			return
	var on_stage := _stage().grow(360.0).has_point(pos)
	var target = _pick_target()
	_target = target
	if target != null and is_instance_valid(target) and on_stage:
		var tp: Vector2 = target.global_position
		var d: Vector2 = tp - pos
		var dist := d.length()
		_cached_aim = _jitter(d.normalized())
		# hunt commitment (§3.1 commit_time): once rolled TRUE it sticks — no re-rolling every tick
		var target_near := _stage().grow(520.0).has_point(tp)
		# §5.5: in finisher, never disengage the lone survivor on distance — chase it to the edge
		# (where the kill lives); otherwise keep the dist-gated + edge-guard prey logic.
		var target_ok := true if _finisher else (target_near or _is_edge_guard_prey(target))
		if not (_hunt and _commit_t > 0.0):
			_hunt = randf() < _eff_aggression() and target_ok
			if _hunt:
				_commit_t = _eff_commit_time()
		elif not target_ok:
			_hunt = false
		_cached_boost = _hunt and dist > _eff_attack_range() * 0.8 and me.fuel > _eff_refuel_floor()
		# enter AIM (rule 1): hunting, in range, fueled past the floor (attack-run budget), and the
		# blast won't launch me out over the void with no target in line (§ whiff-super self-ringout).
		if _hunt and dist < _eff_attack_range() and me.fuel >= _eff_refuel_floor() \
				and _super_safe(pos, tp):
			_cached_super = true
	else:
		# no target / off-stage drift: ease back toward the nearest LANDING surface (never stage_center,
		# which sits over a void gap on islands_void — that dove drifting bots into the chasm).
		var land := _land_target(pos)
		var to_land := land - pos
		_cached_aim = _jitter(to_land.normalized()) if to_land.length() > 160.0 else Vector2.ZERO
		_cached_boost = me.fuel > 35.0 and to_land.length() > 360.0
		_hunt = false

## §2c RETREAT state machine. Returns true when RETREAT is driving movement this tick (caller returns).
## Entry: damaged + no attack opportunity + a heal window worth fleeing for, rolled on flee_skill.
## Hold: boost toward the safe platform; on arrival hold in place and heal. Exit (any): healed to Lv0,
## the anti-evasion cap fired, a kill opportunity appeared, or idle-hunt overrides.
func _update_retreat(pos: Vector2) -> bool:
	var cap: float = Tuning.finisher_flee_max if _finisher else Tuning.flee_max
	if _retreat:
		var force_engage := _retreat_t >= cap
		var healed := me.damage_level < 1
		var opportunity := _has_kill_opportunity()
		var idle_override = arena.has_method("idle_hunt_target") and arena.idle_hunt_target(me) != null
		if force_engage or healed or opportunity or idle_override:
			_retreat = false
			return false
	else:
		if not _should_flee():
			return false
		_retreat = true
		_retreat_t = 0.0
		_retreat_target = _safe_platform(pos)
	# drive the flight to safe ground (re-pick if the target went stale)
	if _retreat_target == Vector2.ZERO:
		_retreat_target = _safe_platform(pos)
	var d: Vector2 = _retreat_target - pos
	if d.length() < 220.0:
		# arrived: hold and heal — stop pushing, let the bounce rhythm carry it (no camp: capped)
		_cached_aim = Vector2.ZERO
		_cached_boost = false
	else:
		_cached_aim = _steer(d.normalized())
		_cached_boost = me.fuel > 6.0
	_cached_super = false
	_hunt = false
	return true

## §2c flee trigger: wounded, a heal window worth fleeing for (> 2s left), no strong attack
## opportunity, rolled on the per-difficulty flee_skill dial. Aim quality is never touched (INV-8).
func _should_flee() -> bool:
	if me.damage_level < 1 or profile.flee_skill <= 0.0:
		return false
	if me.heal_time_left() <= 2.0:
		return false
	if _has_kill_opportunity():
		return false
	return randf() < profile.flee_skill

## A "strong attack opportunity" that suppresses/breaks a flee: already committed to a finishing AIM,
## a wounded prey inside the §3 chase radius, or the nearest opponent inside my effective attack range.
func _has_kill_opportunity() -> bool:
	if me.is_super_aiming():
		return true
	if _most_wounded_in_range() != null:
		return true
	var opp = arena.nearest_opponent(me)
	return opp != null and is_instance_valid(opp) \
		and me.global_position.distance_to(opp.global_position) <= _eff_attack_range()

## Pick the safe spawn/platform that MAXIMIZES distance from the nearest opponent, lightly penalizing
## far travel so it stays reachable by boost (spawns sit on the level's platforms; no new contract).
func _safe_platform(pos: Vector2) -> Vector2:
	var opp = arena.nearest_opponent(me)
	var threat: Vector2 = opp.global_position if (opp != null and is_instance_valid(opp)) else _stage_center()
	var candidates: Array = arena._spawns if ("_spawns" in arena) else []
	if candidates.is_empty():
		return _stage_center()
	# §4 pit-safety: only flee to platforms REACHABLE on the current tank, else a wounded bot flies
	# across the 960px pit, runs dry mid-air, and self-destructs (the dominant uncredited death).
	# budget scales with fuel; nearest reachable is the fallback so we always return a real target.
	var budget: float = clampf(me.fuel / Tuning.fuel_max, 0.15, 1.0) * 2400.0
	var best := Vector2.ZERO
	var best_score := -INF
	var fallback := Vector2.ZERO
	var fb_d := INF
	for s in candidates:
		var sp: Vector2 = s
		var d_me: float = sp.distance_to(pos)
		if d_me < fb_d:
			fb_d = d_me
			fallback = sp
		if d_me > budget:
			continue
		var score: float = sp.distance_to(threat) - 0.35 * d_me
		if score > best_score:
			best_score = score
			best = sp
	return best if best != Vector2.ZERO else fallback

## §3: the chase-the-wounded radius, SCALED with arena width (floored on the attack-range term).
func _wounded_reach() -> float:
	return clampf(maxf(_eff_attack_range() * Tuning.wounded_focus_range_mult,
			Tuning.wounded_focus_frac * _bounds().size.x),
			0.0, Tuning.wounded_focus_range_max)

## Target selection (§3.1): idle-hunt override > leader_focus > edge_guard prey > nearest.
func _pick_target():
	# rule 3: past idle_hunt_after, the nearest living bot overrides targeting to the idler
	if arena.has_method("idle_hunt_target"):
		var idler = arena.idle_hunt_target(me)
		if idler != null:
			return idler
	# §5.6 COMMIT / follow-up: stick to a wounded target already committed to, so repeat hits land
	# inside the 8s heal window (the owner's "finish before they heal"). Release when it heals to Lv0,
	# dies, or flees past the chase radius. Held every tick regardless of the acquire roll below.
	if _target != null and is_instance_valid(_target) and not _target.is_dead() \
			and _target.damage_level >= 1 \
			and me.global_position.distance_to(_target.global_position) <= _wounded_reach():
		return _target
	# §5.6 ACQUIRE: roll wounded_focus; on success, target the MOST-damaged opponent in chase range
	# (tie-break nearest). null falls through to leader_focus / edge_guard / nearest as today.
	if profile.wounded_focus > 0.0 and randf() < profile.wounded_focus:
		var prey = _most_wounded_in_range()
		if prey != null:
			return prey
	var nearest = arena.nearest_opponent(me)
	# leader_focus: with this probability, target the score leader if within 1.5x attack_range —
	# gives the race a villain; keeps a lucky L2 honest
	if profile.leader_focus > 0.0 and randf() < profile.leader_focus:
		var leader = _score_leader()
		if leader != null and me.global_position.distance_to(leader.global_position) <= _eff_attack_range() * 1.5:
			return leader
	# edge_guard: pursue off-stage victims and smash them outward. Self-preservation gate:
	# own fuel >= refuel_floor AND own position inside bounds.grow(-250).
	if profile.edge_guard > 0.0 and randf() < profile.edge_guard \
			and me.fuel >= _eff_refuel_floor() and _bounds().grow(-250.0).has_point(me.global_position):
		var prey = null
		var prey_d := INF
		for p in arena.players:
			if p == me or not is_instance_valid(p) or p.is_dead():
				continue
			if _is_edge_guard_prey(p):
				var pd: float = me.global_position.distance_to(p.global_position)
				if pd < prey_d:
					prey_d = pd
					prey = p
		if prey != null:
			return prey
	return nearest

## §5.6: among valid, non-dead, non-self opponents within the chase radius with damage_level >= 1,
## return the most-damaged (tie-break nearest); null if none. Uses arena.players (no new contract).
func _most_wounded_in_range():
	var best = null
	var best_dmg := 0
	var best_d := INF
	var reach := _wounded_reach()
	for p in arena.players:
		if p == me or not is_instance_valid(p) or p.is_dead() or p.damage_level < 1:
			continue
		var d: float = me.global_position.distance_to(p.global_position)
		if d > reach:
			continue
		if p.damage_level > best_dmg or (p.damage_level == best_dmg and d < best_d):
			best_dmg = p.damage_level
			best = p
			best_d = d
	return best

func _is_edge_guard_prey(p) -> bool:
	return not _stage().grow(360.0).has_point(p.global_position)

func _score_leader():
	if not ("scores" in arena and "players" in arena):
		return null
	var best = null
	var best_s := 0
	for i in range(arena.players.size()):
		var p = arena.players[i]
		if p == me or not is_instance_valid(p) or p.is_dead():
			continue
		if i < arena.scores.size() and int(arena.scores[i]) > best_s:
			best_s = int(arena.scores[i])
			best = p
	return best

## Dodge-super roll (§3.1 dodge_super, §3.2 rule 5): when an enemy enters AIM within 500px with
## their aim within 0.5 rad of me, roll per reaction tick -> fire my own super perpendicular/away
## (prefer the side that lands on a bounce surface — refuel follows). Once per enemy aim window.
func _check_dodge() -> bool:
	if _eff_dodge_super() <= 0.0 or me.fuel < Tuning.super_boost_min_fuel:
		return false
	for p in arena.players:
		if p == me or not is_instance_valid(p) or p.is_dead() or not p.is_super_aiming():
			continue
		var to_me: Vector2 = me.global_position - p.global_position
		if to_me.length() > DODGE_SENSE_RANGE:
			continue
		if absf(p.get_super_aim_dir().angle_to(to_me.normalized())) > DODGE_AIM_CONE:
			continue
		var pid: int = p.get_instance_id()
		if _dodged.get(pid, false):
			continue   # already answered this aim window
		if randf() < _eff_dodge_super():
			_dodged[pid] = true
			var threat: Vector2 = p.get_super_aim_dir()
			var perp := Vector2(-threat.y, threat.x)
			var to_stage := (_stage_center() - me.global_position).normalized()
			if perp.dot(to_stage) < 0.0:
				perp = -perp   # prefer the side that carries me back over bounce surfaces
			_dodge_dir = perp
			return true
	return false

func _clean_dodge_flags() -> void:
	# an enemy's aim window ended -> they're dodge-able again next window
	for pid in _dodged.keys().duplicate():
		var obj = instance_from_id(pid)
		if obj == null or not is_instance_valid(obj) or obj.is_dead() or not obj.is_super_aiming():
			_dodged.erase(pid)

## Powerups (spec v1, minimal bot behavior): bots collect on touch (bubble Area2D handles it)
## and use what they hold after bot_powerup_delay + level-scaled variance. No seeking/strategy
## yet — a dedicated bot-powerup-brain pass is its own future task (spec §7).
func _tick_powerup(it: InputIntent, dt: float) -> void:
	var has_pu: bool = me.held_powerup != ""
	if has_pu and not _had_powerup:
		_pu_use_timer = Tuning.bot_powerup_delay + randf_range(0.0, 0.4 * float(6 - clampi(level, 1, 5)))
	_had_powerup = has_pu
	if has_pu and _pu_use_timer >= 0.0:
		_pu_use_timer -= dt
		if _pu_use_timer <= 0.0:
			it.use_powerup = true
			_pu_use_timer = -1.0
	# Wings active: occasionally tap a flap to fly while boosting.
	if me.wings_flaps > 0 and it.boost and randf() < 0.15:
		it.flap = true

func _jitter(dir: Vector2) -> Vector2:
	return dir.rotated(randf_range(-profile.aim_error, profile.aim_error))

## World-y of the nearest bounce surface directly below (x, from_y), or INF if none within the drop.
## Ray-probe, so void/pit reasoning is GEOMETRY-generic (no hardcoded coords — works on any level).
func _ground_y_below(x: float, from_y: float) -> float:
	if me == null or not is_instance_valid(me):
		return INF
	var space := me.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, from_y), Vector2(x, from_y + VOID_PROBE_DROP), Player.MASK_SURFACES)
	q.exclude = [me.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else INF

## Is there a bounce surface directly below this world x (within a generous drop)?
func _ground_below(x: float, from_y: float) -> bool:
	return _ground_y_below(x, from_y) < INF

## Over the void = no landing surface anywhere below this world position (off an island, over open
## space). `at` defaults to my own position. This is the bot's core DANGER sense (CD verdict #4).
func _over_void(at := Vector2.INF) -> bool:
	if me == null or not is_instance_valid(me):
		return false
	var p: Vector2 = me.global_position if at == Vector2.INF else at
	return _ground_y_below(p.x, p.y - 40.0) == INF

## Fuel needed to translate `dx` px horizontally under boost, plus a reserve to keep after landing.
func _can_reach(dx: float) -> bool:
	return me.fuel >= dx * CROSS_FUEL_PER_PX + CROSS_FUEL_RESERVE

## Nearest world-x (stepping in `dir`) that has a landing surface below, or NAN if none before `limit`.
func _scan_ground_x(from_x: float, limit_x: float, dir: float) -> float:
	var step := 100.0
	var x := from_x
	for _i in range(70):
		if _ground_y_below(x, me.global_position.y - 40.0) < INF:
			return x
		x += dir * step
		if (dir > 0.0 and x > limit_x) or (dir < 0.0 and x < limit_x):
			return NAN
	return NAN

## Choose a world point on a REACHABLE landing surface to fly toward, biased by intent (chase-target
## side) then momentum. Continues a good crossing (forward island reachable) and aborts a doomed one
## (turn back to the nearest reachable island); if NOTHING is reachable, returns the nearest surface so
## the recovery-super gamble in _danger_recover can try for it. Falls back to legacy stage-center behavior
## only if the whole level has no surface below the search band (never on a real level).
func _land_target(pos: Vector2) -> Vector2:
	var lo: float = _bounds().position.x + 60.0
	var hi: float = _bounds().end.x - 60.0
	var cx: float = clampf(pos.x, lo, hi)
	var left_x: float = _scan_ground_x(cx, lo, -1.0)
	var right_x: float = _scan_ground_x(cx, hi, 1.0)
	# intent bias: chase-target side wins, else current momentum
	var bias := 0.0
	if _hunt and _target != null and is_instance_valid(_target) and not _target.is_dead():
		bias = signf(_target.global_position.x - pos.x)
	elif absf(me.velocity.x) > 60.0:
		bias = signf(me.velocity.x)
	var choices: Array = []
	if not is_nan(left_x):
		choices.append({"x": left_x, "dx": absf(left_x - pos.x), "side": -1.0})
	if not is_nan(right_x):
		choices.append({"x": right_x, "dx": absf(right_x - pos.x), "side": 1.0})
	if choices.is_empty():
		return _stage_center() + Vector2(0, -120)
	var chosen = null
	# 1) the biased side, if reachable
	for c in choices:
		if c.side == bias and _can_reach(c.dx):
			chosen = c
	# 2) else the nearest REACHABLE side
	if chosen == null:
		for c in choices:
			if _can_reach(c.dx) and (chosen == null or c.dx < chosen.dx):
				chosen = c
	# 3) else the nearest side overall (gamble the recovery super for it)
	if chosen == null:
		for c in choices:
			if chosen == null or c.dx < chosen.dx:
				chosen = c
	# aim PAST the lip so we land with runway, not on the edge; re-probe surface-y at the nudged column
	var tx: float = clampf(float(chosen.x) + float(chosen.side) * VOID_LAND_NUDGE, lo, hi)
	var sy: float = _ground_y_below(tx, pos.y - 40.0)
	if sy == INF:
		tx = float(chosen.x)
		sy = _ground_y_below(tx, pos.y - 40.0)
	var ty: float = (sy - VOID_LAND_MARGIN) if sy < INF else pos.y - 120.0
	return Vector2(tx, ty)

## Would committing a super from `from` toward `target_pos` be safe (not a whiff-super self-ringout)?
## Safe when: not already over the void, AND either no void lies between me and the target (a same-
## landmass smash — the wider v3 islands + smash_self_retain=0.1 keep a CONNECTING attacker on-island)
## OR a whiffed launch (the full impulse carries ~SUPER_CARRY along the aim) still comes down over a
## surface rather than out in the open void. This kills the CLEAR self-ringout — firing a blast OUT
## over a gap. It does NOT gate a same-island shot whose aim_error JITTER happens to spray outward
## (that residual is the arena-relative-super / aim-dial question, shared with the human — see report);
## nor the recovery/dodge supers (the intended escape gamble). Empirically a tighter always-carry gate
## suppressed connecting offense WITHOUT catching the jitter-ringouts, so it is deliberately not used.
func _super_safe(from: Vector2, target_pos: Vector2) -> bool:
	if _over_void(from):
		return false
	if not _path_crosses_void(from, target_pos):
		return true
	var dir := target_pos - from
	if dir.length() < 1.0:
		return true
	return not _over_void(from + dir.normalized() * SUPER_CARRY)

## Does the straight path from a to b pass over open void at any interior sample?
func _path_crosses_void(a: Vector2, b: Vector2) -> bool:
	var n := 5
	for i in range(1, n):
		if _over_void(a.lerp(b, float(i) / float(n))):
			return true
	return false

## Choose a refuel dive column that actually has ground below it (§4 pit-avoidance). Start from the
## desired x; if that column is over a gap, scan outward for the nearest floored column.
func _refuel_x(desired_x: float, sr: Rect2, from_y: float) -> float:
	var lo := sr.position.x + 100.0
	var hi := sr.end.x - 100.0
	desired_x = clampf(desired_x, lo, hi)
	if _ground_below(desired_x, from_y):
		return desired_x
	var step := 120.0
	var off := step
	while off <= (hi - lo):
		if desired_x + off <= hi and _ground_below(desired_x + off, from_y):
			return desired_x + off
		if desired_x - off >= lo and _ground_below(desired_x - off, from_y):
			return desired_x - off
		off += step
	return desired_x

## Lightweight obstacle avoidance: probe feeler rays fanning out from the desired heading and
## return the nearest CLEAR one, so the bot steers around surfaces instead of slamming into them.
func _steer(desired: Vector2) -> Vector2:
	if desired == Vector2.ZERO or me == null or not is_instance_valid(me):
		return desired
	var space := me.get_world_2d().direct_space_state
	var from: Vector2 = me.global_position
	var probe := 240.0
	for ang in [0.0, 0.35, -0.35, 0.75, -0.75, 1.2, -1.2, 1.7, -1.7]:
		var d := desired.rotated(ang)
		var q := PhysicsRayQueryParameters2D.create(from, from + d * probe, Player.MASK_SURFACES)
		q.exclude = [me.get_rid()]
		if space.intersect_ray(q).is_empty():
			return d
	return desired
