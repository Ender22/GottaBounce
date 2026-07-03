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
	return profile.attack_range * Tuning.finisher_attack_range_mult if _finisher else profile.attack_range

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
	var future: Vector2 = me.global_position + me.velocity * 0.6
	var outside_soon := not _bounds().grow(-80.0).has_point(future)
	var off_stage := not _stage().grow(440.0).has_point(me.global_position)
	return outside_soon or off_stage

func _recovery_dir() -> Vector2:
	# back toward the stage (aim slightly above its center so we land on top, not under it)
	var dir := (_stage_center() + Vector2(0, -120)) - me.global_position
	return dir.normalized() if dir.length() > 1.0 else Vector2.UP

## Reflexive survival (§3.2 rule 4 — untouched top priority): if knocked off the stage or about
## to leave the arena, boost back toward the platforms. When boost can't win (tank nearly dry or
## momentum too hot), gamble the recovery super — always full power now (§1).
func _danger_recover(it: InputIntent) -> bool:
	if not _in_danger():
		return false
	var dir := _recovery_dir()
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
	# recovery super: boost alone can't reel in a hot launch or an empty tank — enter AIM and
	# let _tick_aiming snap the counter (this IS the recovery gamble, spec §1.3)
	var out_speed: float = -me.velocity.dot(dir)
	if me.fuel >= Tuning.super_boost_min_fuel and (me.fuel <= 12.0 or out_speed > 1400.0):
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
		var target := Vector2(clampf(pos.x, sr.position.x + 100.0, sr.end.x - 100.0), sr.end.y)
		var dir := (target - pos).normalized()
		_cached_aim = dir
		# boost only if falling AWAY from the surface; otherwise let gravity deliver the bounce
		_cached_boost = me.velocity.dot(dir) < -60.0 and me.fuel > 2.0
		_hunt = false
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
		# enter AIM (rule 1): hunting, in range, and fueled past the floor (attack-run budget)
		if _hunt and dist < _eff_attack_range() and me.fuel >= _eff_refuel_floor():
			_cached_super = true
	else:
		# no target / off-stage drift: ease back toward the stage
		var to_stage := _stage_center() - pos
		_cached_aim = _jitter(to_stage.normalized()) if to_stage.length() > 160.0 else Vector2.ZERO
		_cached_boost = me.fuel > 35.0 and to_stage.length() > 360.0
		_hunt = false

## Target selection (§3.1): idle-hunt override > leader_focus > edge_guard prey > nearest.
func _pick_target():
	# rule 3: past idle_hunt_after, the nearest living bot overrides targeting to the idler
	if arena.has_method("idle_hunt_target"):
		var idler = arena.idle_hunt_target(me)
		if idler != null:
			return idler
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
