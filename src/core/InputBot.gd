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
const CROSS_FUEL_PER_PX := 0.042       # WK-95 BR-6: est. fuel per px under boost (steered flight 28.57/815 = 0.035 + ~20%)
const CROSS_FUEL_RESERVE := 15.0       # WK-95 BR-6: fuel kept after reaching a landing (> super_boost_min_fuel = 10)
const CROSS_FUEL_PER_PX_LEGACY := 0.045   # pre-WK-95 brain (A/B switch OFF): sized for the lossy 760 px/s arcs
const CROSS_FUEL_RESERVE_LEGACY := 10.0   # pre-WK-95 brain: > the old super_boost_min_fuel 5
const SUPER_REACH_FRAC := 0.85         # WK-95 BR-3: offensive super reach = impulse x super_active_time x this (~1070 px)
const SUPER_CARRY := 720.0             # est. horizontal carry of a WHIFFED super (self-ringout range)
# WK-127 spatial reasoning (bot geometry sense, like the VOID_* constants above — not game-feel Tuning):
const CLIMB_PROBES := [300.0, 600.0, 900.0, 1200.0]   # px above me re-probed for a landing when none is below
const WHIFF_SIM_DT := 1.0 / 30.0       # s step of the post-miss trajectory prediction
const WHIFF_SIM_T := 2.5               # s horizon: no surface touched by then (and still in bounds) = falling to the void
const WHIFF_AIM_KEEP := 0.45           # share of current velocity left after the aim hover (super_aim_damp 2.5/s, ~0.3 s)
const RECOVER_SIM_T := 2.0             # s horizon of the recovery-flight prediction
const RECOVER_ARRIVE := 140.0          # px from the landing point (180 px over the surface) that counts as home
const DUMP_LEAD := 0.5                 # s before the 2 s auto-fire when a soured attack aim gives up and dumps

# --- Obstacle-aware ASCENT geometry (owner head-bang fix 2026-07-04). The bot's spatial sense was
# DOWNWARD-ONLY (_ground_y_below/_scan_ground_x find LANDING surfaces below). Platforms are SOLID and
# bounce you off their UNDERSIDE, so a bot wanting a goal ABOVE boosted straight up, bounced off the
# platform in the way, and retried forever. These add an UPWARD sense so the bot routes LATERALLY to a
# platform EDGE before climbing. Geometry-generic (ray-probe, no hardcoded coords), human-ranged. ---
const ASCENT_PROBE := 460.0            # upward ray length: how far overhead we sense a blocking platform
const ASCENT_AIM_UP := -0.30           # aim.y below this (pointing up) => we're trying to ascend
const ASCENT_EDGE_MARGIN := 200.0      # steer this far PAST the platform edge before turning up (clear the lip)
const ASCENT_EDGE_STEP := 90.0         # x-step scanning outward for where the overhead platform ends
const ASCENT_EDGE_MAX := 46            # max scan steps (bounded, human-ish reach — no omniscient solve)

# A/B regression switch (default ON): the motion-health probe stays live in BOTH states, so QA can
# measure BEFORE (fix off) vs AFTER (fix on) in one build. Flip via gbplay eval: InputBot.ascent_fix_enabled = false
static var ascent_fix_enabled := true

# A/B regression switch for the GRAVITY-FRAME sense (bot brains v2 slice 1, default ON): OFF
# reproduces the screen-down-biased v1 bot (orbit-decay in radial wells) for BEFORE measurements.
# Flip via gbplay eval: InputBot.gravity_fix_enabled = false
static var gravity_fix_enabled := true

# A/B regression switch for WK-94 (default ON): OFF reproduces the pre-WK-94 aim (per-frame snap to the
# solution, error re-rolled as instant jumps, recovery panic re-rolled EVERY frame) for BEFORE recordings.
# Flip via gbplay eval / RecordBoot arg: InputBot.aim_sweep_enabled = false
static var aim_sweep_enabled := true

# A/B regression switch for WK-95 (default ON; owner ruling 2026-11-14 "super = attack, flight = travel"):
# OFF reproduces the pre-WK-95 brain: the fuel<=12 fumes recovery super, offensive supers without the
# range/line-of-sight attack window, flight aimed straight at targets (no sag compensation), no flight-stick
# smoothing, and the old CROSS_FUEL constants. Flip via gbplay eval: InputBot.wk95_brain_enabled = false
static var wk95_brain_enabled := true
# EXPERIMENT (default OFF = spec BR-4 as written): HOT also requires that a full normal-boost brake could
# NOT stop the outward motion before the blast line (v^2 / 2a > distance to bounds - margin).
static var wk95_hot_stopdist := true   # director ruling 2026-11-14 (DECISIONS): ON - meets owner super=attack ruling (9.8% traversal supers)
# A/B regression switch for WK-127 (default ON; bots self-KO'd 36% of their deaths, 59% of 4-bot stages lost a
# fighter before 3 s). ON: (a) no attack super at a spawn-protected (blinking) target, and none whose WHIFF would
# carry me out through a blast line before I touch a refuelling surface (post-miss trajectory predicted; re-checked
# at release, a soured aim holds and late in the 2 s window dumps into the floor = purpose "attack_dump"); no
# boosting at a target I won't shoot; (b) the "recovery_unreachable" super counts landings ABOVE me (the WK-95
# measure only scanned for ground below my height, so a bot knocked under the spire tops / the_ascent's bottom
# tier read INF and dumped a 50-97 fuel tank) plus a momentum test (predicted recovery flight still exits a blast
# line); recovery flight BRAKES against the velocity when about to cross a blast line; the recovery super's aim
# leans into the current velocity. OFF reproduces the WK-108 brain. Flip via gbplay eval: InputBot.wk127_enabled = false
static var wk127_enabled := true
# A/B regression switch for WK-128 BR-128 (default ON; docs/specs/wk128_fuel_exploits_2026-11-14.md §7.4). A face now
# pays once per REAL bounce, so the refuel dive's "boost toward the floor whenever moving away from it" turned every
# bounce into an entry-chop hop that never re-arms (a bot needing two refunds would dribble forever without income).
# ON: in the refuel dive (flat + radial) don't thrust toward the surface while still rising off a paying contact whose
# face has not re-armed — let the bounce carry to its apex, then dive as before. must_cross dives are unaffected.
# OFF = the WK-127 dive. NO EFFECT while the Tuning refund gate is OFF (pending WK-135): no face ever stays unarmed, so
# Player.refund_rearm_pending() is always false. Flip via gbplay eval: InputBot.wk128_refuel_wait = false
static var wk128_refuel_wait := true
# WK-135 BR-135 (docs/specs/wk135_bumper_min_bounce_2026-11-15.md §5; default ON). Bots never thrust-pin a bumper:
# (a) the radial refuel dive never targets a WALL/CEILING-class bumper face (flat dives already only hit tops: the probe
# is a downward ray); (b) PIN BREAKER: >= Tuning.bot_pin_contacts contacts with ONE bumper face within bot_pin_window
# while thrusting into it -> boost released for one reaction tick, then a re-plan with that face excluded for
# bot_pin_exclude_s (not a refuel target; a boost aim into it within bot_pin_avoid_px slides along it instead);
# (c) the radial landing/recovery reuses (b) (steer only: a recovery never drops its boost).
# OFF = the phase-1 brain exactly. Flip via gbplay eval: InputBot.wk135_no_pin = false
static var wk135_no_pin := true

# --- Motion-health telemetry geometry (process-gate 2026-07-04: make "looks dumb" a NUMBER). ---
const MH_STUCK_WINDOW := 1.0           # s window for the no-progress (stuck) test
const MH_STUCK_DISP := 90.0            # net displacement below this over the window while intending = stuck
const MH_ASCENT_STALL := 0.7           # s of up-intent with no upward progress before flagging blocked-ascent
const MH_ASCENT_PROGRESS := 24.0       # px of upward gain that counts as real ascent progress (resets the stall)

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
# --- v1_vfx_telegraphy §5: super-aim DWELL (commitment, NOT accuracy — INV-8). _pending_aim_min is
# rolled when an OFFENSIVE super is committed; it's copied to _aim_min_this on the aim-start edge and
# is the min seconds the bot holds the AIM before it may release. 0 for dodge/recovery supers. ---
var _pending_aim_min := 0.0
var _aim_min_this := 0.0
var _was_aiming := false
var _dodge_dir := Vector2.ZERO   # pending dodge-super direction (fires snap, §3.2 rule 5)
var _sim_normal := Vector2.UP    # WK-127: contact normal of the last _sim_step hit (scratch for the predictors)
var _aim_dump := false           # WK-127: this offensive aim turned unsafe (a whiff would exit a blast line) -> dump it
var _braking := false            # WK-127: the recovery is braking before a blast line this frame (fast stick slew)
var _refuel_dive := false        # WK-128: the cached decision is a refuel dive (BR-128 re-checks it every frame)
var _refuel_dir := Vector2.ZERO  # WK-128: that dive's direction into the surface
var _refuel_cross := false       # WK-128: ...and it is a must_cross translation (BR-128 does not apply)
var _mh_below_floor_s := 0.0     # WK-128 §8: s with fuel below the effective refuel floor (motion-health feed)
var _pin_clock := 0.0            # WK-135 BR-135b: s (this brain's own clock; never reset mid-life)
var _pin_key := ""               # WK-135 BR-135b: bumper face of the current contact run
var _pin_hits: Array = []        # WK-135: clocks (_mh_clock) of thrust-into contacts with that face in the window
var _pin_release_t := 0.0        # WK-135: s left of the forced boost release (one reaction tick)
var _pin_ex_t := 0.0             # WK-135: s left of the face exclusion
var _pin_ex_key := ""            # WK-135: the excluded face
var _pin_ex_n := Vector2.ZERO    # WK-135: its outward normal (rect faces)
var _pin_ex_p := Vector2.ZERO    # WK-135: a contact point on it
var _pin_ex_round := false       # WK-135: round collider (normal = radial from _pin_ex_c)
var _pin_ex_c := Vector2.ZERO    # WK-135: round centre
var _pin_ex_r := 0.0             # WK-135: round surface radius (centre to contact)
var _pin_ex_wall := false        # WK-135: WALL-class face (slides go round it against gravity: over a post, not under it)
var _pin_ex_body: WeakRef = null # WK-135: the face's body (rect extent read live: moving bumpers)
var _pin_ex_off := Vector2.ZERO  # WK-135: its RectangleShape2D offset in the body
var _pin_ex_half_t := -1.0       # WK-135: face half-length along its tangent (-1 = unknown shape: plane test)
var _pin_ex_half_n := 0.0        # WK-135: rect half-extent along the face normal
var _pin_avoiding := false       # WK-135: _pin_avoid redirected the aim this frame (snap the stick: bot_pin_turn_mult)
# WK-161: per-episode dump (telemetry only, never read by decisions). motion_health()["wk161_dump"] carries one record per
# STUCK episode and per bot-side PIN episode (Player's bumper_pin_episodes rule: >= Player.PIN_CONTACTS contacts with one
# bumper face within Player.PIN_WINDOW, ANY thrust) with thrust dir, hitstun, black-hole / well state and contact point.
var _wk161_dump: Array = []      # WK-161: this stage's records (capped at Tuning.wk161_dump_max)
var _wk161_path := ""            # WK-161: which poll branch emitted the last intent (aim / recover / plan)
var _wk161_pin_key := ""         # WK-161: bot-side pin detector, face of the current run (any thrust)
var _wk161_pin_times: Array = [] # WK-161: _mh_clock of its contacts in the window
var _wk161_in_pin := false       # WK-161: inside a pin episode (one record per episode)
var _wk161_pin_eps := 0          # WK-161: bot-side pin episodes this stage (cross-check vs wk128.bumper_pin_episodes)
var _wk161_well_skips := 0       # WK-161: breaker trips inside a well that skipped exclusion + slide (knob ON)
var _wk161_last_t := -INF        # WK-161: _mh_clock of my last surface contact (any surface)
var _wk161_last_p := Vector2.ZERO  # WK-161: its contact point
var _wk161_last_n := Vector2.ZERO  # WK-161: its normal
var _wk161_last_face := ""       # WK-161: its class (core / floor / wall / ceiling / surface)
# WK-95 BR-7: purpose of the super this bot last pressed (attack / finisher_attack / dodge / recovery_hot /
# recovery_unreachable / attack_dump (WK-127); the pre-WK-95 brain also emits recovery_lowfuel). PartyMatch copies it into
# round_stats.supers_fired[].purpose_bot at fire time. Telemetry only — never read by the decision code.
var _super_purpose := ""
var _bang_t := 0.0               # WK-95: s left of the post-head-bang lateral escape
var _bang_dir := Vector2.ZERO    # WK-95: lateral direction (toward the nearer clear edge) to escape an underside
var _fly_out := Vector2.ZERO     # WK-95/WK-103: the swept flight-stick direction actually emitted (ZERO = unseeded)
var _obj_live := false           # WK-108b: the last decision took the mode-objective branch (sports)
var _obj_replan_t := 0.0         # WK-108b K2: s until the next fast objective re-plan
var wk108b_replans := 0          # WK-108b: telemetry - fast re-plans run
var wk108b_guards := 0           # WK-108b: telemetry - frames the strike guard / net brake replaced the aim
var _wk108b_has_guard := -1      # WK-108b: -1 unknown, 1 the mode has bot_strike_guard (sports), 0 not
# --- WK-94 (owner 2026-11-14: bot super-aim "spins like nuts"). A bot's aim is a HUMAN STICK: the emitted
# super-aim direction sweeps toward the solution at <= Tuning.bot_aim_turn_rate[level] rad/s (never a
# per-frame snap), and every error term is a SLOW DRIFT toward a target re-rolled on a timer — never
# white noise re-rolled each physics frame. Difficulty stays input quality only (INV-8). ---
var _aim_out := Vector2.ZERO     # the swept stick direction actually emitted while in AIM (ZERO = unseeded)
var _aim_roll_target := 0.0      # offensive aim error drifts toward this (re-rolled per reaction tick)
var _panic_cur := 0.0            # low-recovery_skill panic offset (recovery boost + recovery super), drifting
var _panic_target := 0.0         # ...toward this, re-rolled every Tuning.bot_panic_reroll s
var _panic_t := 0.0              # countdown to the next panic re-roll
var _dodged := {}            # enemy instance_id -> fired a dodge for their current aim window
var _finisher := false       # §5.5: down to <= finisher_opponents_left living opponents -> commit-mode
                             # runtime-only dial overrides (never mutates profile; reverts on stage reset)
# --- v1_kill_economy §2c flee-to-heal RETREAT state ---
var _retreat := false        # currently fleeing to safe ground to heal
var _retreat_t := 0.0        # seconds spent in the current RETREAT (anti-permanent-evasion cap)
var _retreat_target := Vector2.ZERO  # the safe-platform position being fled to

# --- Motion-health telemetry (process gate: surfaces locomotion pathologies as NUMBERS in the QA feed).
# (a) stuck/no-progress episodes, (b) underside-bounce count (head-bang), (c) blocked-ascent. Reset per
# stage by PartyMatch._bounce_go; snapshotted into round_stats at stage end as a permanent regression guard. ---
var _mh_samples: Array = []          # rolling {t,pos,move} window for the no-progress test
var _mh_clock := 0.0
var _mh_in_stuck := false
var _mh_stuck_episodes := 0
var _mh_stuck_secs := 0.0
var _mh_underside := 0                # bounces whose contact normal points DOWN (hit a ceiling underside)
var _mh_underside_boosted := 0        # subset SELF-PROPELLED: hit the underside while boosting UP (the AI bug,
                                      # vs knockback into a ceiling which is legit combat physics)
var _mh_asc_active := false
var _mh_asc_ref_pos := Vector2.ZERO  # highest point (against LOCAL gravity) reached in the current ascent attempt
var _mh_asc_t := 0.0                 # s since last upward progress while ascending
var _mh_blocked_now := false         # live BLOCKED-ASCENT flag (wants up, Y not decreasing)
var _mh_blocked_ascent_episodes := 0
var _mh_blocked_ascent_secs := 0.0
var _mh_detours := 0                  # frames the ascent-detour actively redirected (fix-engagement telemetry)

func _init(player: Player, arena_ref, bot_level := 3) -> void:
	me = player
	arena = arena_ref
	level = bot_level
	profile = BotProfile.for_level(bot_level)
	var wk161_env: String = OS.get_environment("GB_WK161")   # WK-161 QA arm override ("1" ON, "0" OFF, unset = Tuning)
	if wk161_env == "1" or wk161_env == "0":   # WK-161
		Tuning.wk161_radial_pin_skip = wk161_env == "1"   # WK-161
	# underside-bounce sense (INV-12 subscriber): the sim emits surface_bounced with the contact
	# normal; a normal pointing DOWN means we hit a platform's underside (head-bang). Read-only.
	EventBus.surface_bounced.connect(_on_surface_bounced)

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

## WK-95 BR-7: the purpose tag of the super currently being aimed / last fired (QA telemetry).
func super_purpose_tag() -> String:
	return _super_purpose

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
	_pin_clock += dt   # WK-135 BR-135b
	_pin_release_t = maxf(0.0, _pin_release_t - dt)   # WK-135
	_pin_ex_t = maxf(0.0, _pin_ex_t - dt)   # WK-135
	_commit_t = maxf(0.0, _commit_t - dt)
	if _retreat:
		_retreat_t += dt   # anti-permanent-evasion cap counts on the wall clock (§2c)
	if me == null or not is_instance_valid(me) or me.is_dead():
		it.aim = Vector2.ZERO
		it.boost = false
		return it
	# motion-health reads the PREVIOUS frame's committed intent (it.aim/it.boost persist across polls)
	# against the resulting motion this frame — covers every path (hunt/recover/aim) uniformly.
	_update_motion_health(dt, it.boost, it.aim)
	if me.fuel < _eff_refuel_floor():
		_mh_below_floor_s += dt
	_clean_dodge_flags()
	# §5.5: finisher mode is a per-poll runtime flag — recomputed from the live alive-count every
	# tick, so it reverts automatically when a stage reset repopulates the arena. Dial overrides are
	# read through the _eff_* accessors below; profile is never mutated (INV-8: commitment, not aim).
	_finisher = _alive_opponents() <= Tuning.finisher_opponents_left
	# §5 dwell: latch the sampled floor on the aim-start EDGE (offensive aims set _pending_aim_min
	# the frame they commit; dodge/recovery leave it 0). Runs before the is_super_aiming return.
	var aiming_now: bool = me.is_super_aiming()
	if aiming_now and not _was_aiming:
		_aim_min_this = _pending_aim_min
		_pending_aim_min = 0.0
		# WK-94: the sweep starts from wherever the arrow actually is (the press-frame stick / straight up)
		_aim_out = me.get_super_aim_dir()
		_aim_roll_target = _aim_roll
		_aim_dump = false
	_was_aiming = aiming_now
	_tick_panic(dt)
	# --- own AIM state: steer the led solution, fire when good enough or timed out (§3.2 rule 1)
	if me.is_super_aiming():
		_my_aim_t += dt
		_wk161_path = "aim"   # WK-161
		_tick_aiming(it)
		return it
	_my_aim_t = 0.0
	# Recovery is re-evaluated EVERY frame (not just on reaction_time): bailing out of a fall is
	# reflexive, and waiting up to reaction_time to react is what sends bots off the map.
	_bang_t = maxf(0.0, _bang_t - dt)
	_braking = false
	_pin_avoiding = false   # WK-135
	if _danger_recover(it):
		_wk161_path = "recover"   # WK-161
		it.aim = _bang_escape(it.aim, it.boost)
		if it.boost:
			it.aim = _pin_avoid(it.aim)   # WK-135 BR-135c: a recovery steers off an excluded face (never drops its boost)
		var rguard: Vector2 = _wk108b_guard(true)   # WK-108b K3: the clear rule also covers recovery flight (soccer only)
		if rguard != Vector2.ZERO:   # WK-108b
			it.aim = rguard   # WK-108b
			it.boost = me.fuel > 2.0   # WK-108b
			wk108b_guards += 1   # WK-108b
		var rm: float = Tuning.bot_brake_turn_mult if _braking else 1.0   # WK-135: + snap off an excluded face
		if rguard != Vector2.ZERO:   # WK-108b: the swerve snaps the stick (wk108b_guard_turn_mult)
			rm = maxf(rm, Tuning.wk108b_guard_turn_mult)   # WK-108b
		it.aim = _smooth_fly(it.aim, dt, maxf(rm, Tuning.bot_pin_turn_mult) if _pin_avoiding else rm)   # WK-135
		return it
	if _react <= 0.0:
		_react = profile.reaction_time
		# dodge-super roll first (§3.2 rule 5): the human commits to an aim, the menace bots MOVE
		if _check_dodge():
			_cached_super = true
			_super_purpose = "dodge"
		else:
			_decide()
	if _obj_live and not _cached_super:   # WK-108b K2: fast objective re-plan between reaction ticks (sports only)
		_wk108b_replan(dt)   # WK-108b
	it.aim = _cached_aim
	it.boost = _cached_boost
	_wk161_path = "refuel" if _refuel_dive else ("hunt" if _hunt else "plan")   # WK-161
	# WK-128 BR-128 (reflex, every frame — a cached dive boost can outlive the bounce it was decided before)
	if it.boost and _refuel_dive and not _refuel_cross and wk128_refuel_wait and me.refund_rearm_pending(_refuel_dir):
		it.boost = false
	if _pin_release_t > 0.0 and wk135_no_pin:   # WK-135 BR-135b: the pin breaker's one-reaction-tick boost release
		it.boost = false
	var guarded := false   # WK-108b
	if not _cached_super:   # WK-108b K3/K5: goal-mouth clear rule / Dropshot net brake (per-frame reflex; every sports path)
		var guard: Vector2 = _wk108b_guard(false)   # WK-108b
		guarded = guard != Vector2.ZERO   # WK-108b
		if guarded:   # WK-108b
			it.aim = guard   # WK-108b
			it.boost = me.fuel > 2.0 and not (_pin_release_t > 0.0 and wk135_no_pin)   # WK-108b (WK-135 pin release still wins)
			wk108b_guards += 1   # WK-108b
	if _cached_super and me.super_arm_locked():   # WK-20d: truce / fumble-reserve gate would drop the press -> keep flying
		_cached_super = false
	if _cached_super:
		_cached_super = false
		it.super_hold = true   # press: Player enters AIM this frame; _tick_aiming takes over next
		it.boost = false
		_aim_roll = randf_range(-profile.aim_error, profile.aim_error)
		_aim_roll_target = _aim_roll
		# §5: roll the dwell floor for this OFFENSIVE aim only (dodge sets _dodge_dir first -> skip).
		# Capped below the 2s auto-fire ceiling so a bot can never camp the aim (Pillar 2).
		if _dodge_dir == Vector2.ZERO and profile.super_aim_min > 0.0 and randf() < profile.super_aim_min_chance:
			_pending_aim_min = minf(randf_range(profile.super_aim_min, profile.super_aim_min + 0.4),
				Tuning.super_aim_max - 0.1)
		else:
			_pending_aim_min = 0.0
	_tick_powerup(it, dt)
	# Steer the thrust around walls/platforms so the bot stops boosting straight into geometry.
	# Ascent-detour first (macro lateral routing around an overhead platform edge), then the local
	# feeler-steer for fine avoidance.
	if it.boost:
		it.aim = _ascent_detour(it.aim)
		it.aim = _steer(it.aim)
		it.aim = _pin_avoid(it.aim)   # WK-135 BR-135b: no thrust into an excluded (just-pinned) bumper face
	if not it.super_hold:
		it.aim = _ceiling_guard(_bang_escape(it.aim, it.boost), it.boost)
		var tm: float = Tuning.bot_pin_turn_mult if _pin_avoiding else 1.0   # WK-135: snap off an excluded face
		if guarded:   # WK-108b: the clear-rule swerve / net brake snaps the stick
			tm = maxf(tm, Tuning.wk108b_guard_turn_mult)   # WK-108b
		it.aim = _smooth_fly(it.aim, dt, tm)   # WK-135 / WK-108b
	else:
		_fly_out = Vector2.ZERO   # the super aim takes over (WK-94 sweep); re-seed flight from the arrow after
	return it

## WK-95 (folds in WK-103): the bot's FLIGHT stick is a human stick. The emitted boost/drift aim rotates toward
## the wanted heading at <= Tuning.bot_flight_turn_rate[level] rad/s instead of snapping (feeler-steer swaps,
## jitter re-rolls and land-target swaps used to flick the arrow >30 deg per frame). Releasing the stick stays
## instant (ZERO passes through); the sweep resumes from the last emitted direction.
func _smooth_fly(desired: Vector2, dt: float, rate_mult := 1.0) -> Vector2:
	if not wk95_brain_enabled or desired == Vector2.ZERO:
		return desired
	var want := desired.normalized()
	if _fly_out == Vector2.ZERO:
		var last: Vector2 = me.get_aim()
		_fly_out = last.normalized() if last.length() > 0.01 else want
	var rates: Array = Tuning.bot_flight_turn_rate
	var r: float = 8.0 if rates.is_empty() else float(rates[clampi(level - 1, 0, rates.size() - 1)])
	var step: float = r * rate_mult * dt
	_fly_out = _fly_out.rotated(clampf(_fly_out.angle_to(want), -step, step)).normalized()
	return _fly_out * minf(desired.length(), 1.0)

## WK-95 BR-4: horizontal distance to the nearest x-column with a landing surface below (left or right), the
## same measure the spec §8.1 RECOVERY_NEEDED classifier uses. INF when none in range.
func _nearest_ground_dx(pos: Vector2) -> float:
	if not _over_void(pos):
		return 0.0
	var lo: float = _bounds().position.x + 60.0
	var hi: float = _bounds().end.x - 60.0
	var cx: float = clampf(pos.x, lo, hi)
	var best := INF
	for dir_x in [-1.0, 1.0]:
		var gx := _scan_ground_x(cx, lo if dir_x < 0.0 else hi, dir_x)
		if not is_nan(gx):
			best = minf(best, absf(gx - pos.x))
	return best

## EXPERIMENT (wk95_hot_stopdist): could a full normal-boost brake arrest `out_speed` before the blast line?
func _can_arrest(out_speed: float) -> bool:
	var v: Vector2 = me.velocity
	if v.length() < 1.0:
		return true
	var u := v.normalized()
	var b := _bounds()
	var pos: Vector2 = me.global_position
	var tx: float = INF
	var ty: float = INF
	if u.x > 0.001:
		tx = (b.end.x - pos.x) / u.x
	elif u.x < -0.001:
		tx = (b.position.x - pos.x) / u.x
	if u.y > 0.001:
		ty = (b.end.y - pos.y) / u.y
	elif u.y < -0.001:
		ty = (b.position.y - pos.y) / u.y
	var dist: float = minf(tx, ty)
	var accel: float = Tuning.normal_boost_accel * me.profile.eff_boost_power()
	return out_speed * out_speed / (2.0 * accel) < dist - 250.0

## WK-95: after a BOOSTED head-bang on a platform underside, fly laterally toward the nearer clear edge of
## that platform for a moment instead of re-thrusting into it. Steered flight holds the aimed line, so the
## bounce's downward kick was being cancelled at once and bots buzzed the same underside (bumper undersides
## refund fuel, so it could last a whole stage: 113 underside bounces in one 11 s Bumper Gauntlet stage).
func _bang_escape(aim: Vector2, boosting: bool) -> Vector2:
	if not wk95_brain_enabled or _bang_t <= 0.0 or not boosting or _bang_dir == Vector2.ZERO:
		return aim
	return _bang_dir

## WK-108: true when the active mode is an enclosed court (SportsMode.bot_enclosed_court).
func _enclosed() -> bool:
	if not wk95_brain_enabled or arena == null or not ("_mode" in arena) or arena._mode == null:
		return false
	return arena._mode.has_method("bot_enclosed_court") and bool(arena._mode.bot_enclosed_court())

## WK-108: in an enclosed court, never keep thrusting UP into a ceiling that is about to arrive (the out-of-arena
## look-ahead used to turn bots away from it; without it they would ram it): within the stopping look-ahead,
## an upward aim is laid flat toward the side it was heading (a little downward), so the bot skims under it.
func _ceiling_guard(aim: Vector2, boosting: bool) -> Vector2:
	if not boosting or aim == Vector2.ZERO or not _enclosed():
		return aim
	var down := _gdown()
	if aim.dot(-down) <= 0.15:
		return aim
	var rise: float = maxf(0.0, me.velocity.dot(-down))
	var reach: float = rise * Tuning.bot_ceiling_lookahead + Tuning.bot_ceiling_margin
	var pos: Vector2 = me.global_position
	var side_off := Vector2(-down.y, down.x) * 40.0   # body-width probes: a block edge must not slip past one ray
	var blocked := false
	for o in [Vector2.ZERO, side_off, -side_off]:
		var hit := _surface_along(pos + o, -down, reach)
		if not hit.is_empty():
			blocked = true
			break
	if not blocked and me.velocity.length() > 1.0:
		# also along the flight line (a diagonal climb into the underside of a mid-court block)
		var vd: Vector2 = me.velocity.normalized()
		var vh := _surface_along(pos, vd, me.velocity.length() * Tuning.bot_ceiling_lookahead + Tuning.bot_ceiling_margin)
		blocked = not vh.is_empty() and (vh["normal"] as Vector2).dot(down) > 0.5
	if not blocked:
		return aim
	var side: float = signf(aim.x) if absf(aim.x) > 0.05 else (signf(me.velocity.x) if absf(me.velocity.x) > 1.0 else 1.0)
	return (Vector2(side, 0.0) + down * 0.25).normalized()

## WK-95 BR-2: gravity-compensated flight aim. Under the steering grip a held boost settles with a steady
## perpendicular sag of boost_gravity_scale*g*cos(theta)/boost_grip_rate (~160 px/s level), so aim ABOVE the
## target line by atan(sag / thrust_cap) (~11 deg level, 0 straight up/down) to actually arrive at it.
## Derived from Tuning every call (never hardcoded). OFF with the brain switch or with grip off.
func _fly_aim(dir: Vector2) -> Vector2:
	if not wk95_brain_enabled or dir == Vector2.ZERO or Tuning.boost_grip_rate <= 0.0:
		return dir
	var a := dir.normalized()
	var g: Vector2 = GravityField.get_gravity_at(me.global_position)
	if g.length_squared() < 0.01:
		return dir
	var down := g.normalized()
	var cos_t: float = absf(a.cross(down))   # share of gravity perpendicular to the thrust
	var cap: float = Tuning.normal_boost_max_speed * me.profile.eff_boost_power()
	var sag: float = Tuning.boost_gravity_scale * g.length() * cos_t / Tuning.boost_grip_rate
	var comp: float = atan(sag / maxf(cap, 1.0))
	var to_up: float = a.angle_to(-down)
	return a.rotated(signf(to_up) * minf(comp, absf(to_up)))

## WK-95 BR-3: the offensive-super ATTACK WINDOW. All must hold: the LED target point is within
## min(_eff_attack_range(), super reach ~1070 px); a clear line of sight (no bounce surface) to it; fuel >=
## max(refuel floor, super_boost_min_fuel); and _super_safe. Outside it the bot FLIES; it never supers to close.
func _attack_window(t) -> bool:
	return _attack_window_why(t) == 0

## 0 = window open; 1 = out of range; 2 = fuel; 3 = line of sight blocked; 4 = _super_safe failed;
## 5 = target spawn-protected (WK-127); 6 = a whiff would carry me out through a blast line (WK-127).
func _attack_window_why(t) -> int:
	if t == null or not is_instance_valid(t):
		return 1
	var pos: Vector2 = me.global_position
	var d: Vector2 = t.global_position - pos
	var lead_t: float = (d.length() / Tuning.super_boost_impulse_full) * profile.target_lead
	var led: Vector2 = t.global_position + t.velocity * lead_t
	var reach: float = minf(_eff_attack_range(), Tuning.super_boost_impulse_full * Tuning.super_active_time * SUPER_REACH_FRAC)
	if pos.distance_to(led) > reach:
		return 1
	if me.fuel < maxf(_eff_refuel_floor(), Tuning.super_boost_min_fuel):
		return 2
	if pos.distance_to(led) > 1.0 and not _surface_along(pos, (led - pos).normalized(), pos.distance_to(led)).is_empty():
		return 3   # line of sight blocked: a super through a platform is a bounce, i.e. travel
	if not _super_safe(pos, t.global_position):
		return 4
	if wk127_enabled:
		# a blinking (spawn-protected) target takes no knockback: a super at it is a guaranteed whiff. Every
		# fighter blinks for the first 1.3 s after BOUNCE, so this is also the opening hold.
		if t.has_method("spawn_protect_left") and float(t.spawn_protect_left()) > 0.0:
			return 5
		if not _whiff_survivable(pos, (led - pos).normalized()):
			return 6
	return 0

## WK-127 (a): predict the trajectory of a MISSED super fired along `dir` from `from` (the tank is dumped, so
## no thrust after: gravity + air drift only) and say whether it touches a bounce surface (a bounce refuels)
## before it crosses a blast line. Three stick variants (neutral, drift left, drift right): the bot steers
## after a whiff, so one survivable line is enough. A HIT stops the attacker (smash_self_retain), so only the
## miss matters. Geometry by ray (no hardcoded coords); gravity from GravityField (radial wells included).
func _whiff_survivable(from: Vector2, dir: Vector2) -> bool:
	if me == null or not is_instance_valid(me) or dir == Vector2.ZERO:
		return true
	var b := _bounds()
	var ac: float = me.profile.eff_air_control()
	var drift_max: float = Tuning.air_drift_max_speed * ac
	var drift_acc: float = Tuning.air_drift_accel * ac * WHIFF_SIM_DT
	var v0: Vector2 = (me.velocity * WHIFF_AIM_KEEP + dir * Tuning.super_boost_impulse_full * float(me.speed_mult)) \
		.limit_length(Tuning.max_speed)
	for drift in [0.0, -1.0, 1.0]:
		var p := from
		var v := v0
		var t := 0.0
		var survived := false
		while t < WHIFF_SIM_T:
			v += GravityField.get_gravity_at(p) * WHIFF_SIM_DT
			v.x = move_toward(v.x, drift * drift_max, drift_acc)
			v = v.limit_length(Tuning.max_speed)
			var hit := _sim_step(p, v, GravityField.get_gravity_at(p))
			if hit == 1:
				survived = true
				break
			if hit == 2:
				v = v.bounce(_sim_normal) * 0.6   # an underside: no refuel, knocked back the way it came
			else:
				p += v * WHIFF_SIM_DT
			if not b.has_point(p):
				break
			t += WHIFF_SIM_DT
		if survived or (t >= WHIFF_SIM_T and b.has_point(p)):
			return true
	return false

## While in the AIM state: keep steering at the led target; fire (release) when the current
## jitter roll is inside aim_error * 0.5 AND (WK-94) the swept arrow has arrived within bot_aim_fire_tol,
## or when super_aim_time runs out (§3.2 rule 1).
## Low-lead bots still whiff constantly — the comedy survives, the freeze-and-pray doesn't.
func _tick_aiming(it: InputIntent) -> void:
	it.boost = false
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var desired := Vector2.UP
	var mode := 0   # 0 offensive, 1 dodge, 2 recovery, 3 no target
	if _dodge_dir != Vector2.ZERO:
		# dodge-super: sweep perpendicular/away as fast as this bot's stick allows
		desired = _dodge_dir
		mode = 1
	elif _in_danger():
		# recovery super: aim back at the stage; recovery_skill governs aim/timing only — the blast
		# itself is always full power (L1's comedy self-destructs get BIGGER). WK-94: the panic error is
		# the slow-drifting _panic_cur (re-rolled on a timer), NOT a fresh ±0.8 rad roll every frame.
		desired = _recovery_dir()
		if wk127_enabled:
			desired = _comp_super_aim(desired)
		desired = desired.rotated(_panic_cur)
		mode = 2
	elif _aim_dump:
		# WK-127: the shot went bad mid-aim (the target moved so the line now whiffs out through a blast
		# line). Nobody can cancel a super, so dump it where the miss is safe: into the floor below, or back
		# at the island when over the void (velocity-compensated like a recovery).
		desired = _dump_dir()
		mode = 4
	else:
		var t = _target
		if t == null or not is_instance_valid(t) or t.is_dead():
			t = arena.nearest_opponent(me)
		if t == null:
			mode = 3
		else:
			if _react <= 0.0:
				_react = profile.reaction_time
				_aim_roll_target = randf_range(-profile.aim_error, profile.aim_error)
			# WK-94: the error DRIFTS toward its re-rolled target (a wandering thumb), never snaps
			if aim_sweep_enabled:
				_aim_roll = move_toward(_aim_roll, _aim_roll_target, Tuning.bot_aim_noise_drift * dt)
			else:
				_aim_roll = _aim_roll_target   # legacy: instant jump on every re-roll
			desired = _led_dir(t).rotated(_aim_roll)
	# WK-94 human-stick sweep: the emitted aim rotates toward `desired` at <= turn_rate rad/s.
	var on_target := true
	if aim_sweep_enabled:
		if _aim_out == Vector2.ZERO:
			_aim_out = me.get_super_aim_dir() if me.get_super_aim_dir() != Vector2.ZERO else desired
		var rate: float = _aim_turn_rate() * dt
		_aim_out = _aim_out.rotated(clampf(_aim_out.angle_to(desired), -rate, rate)).normalized()
		on_target = absf(_aim_out.angle_to(desired)) <= Tuning.bot_aim_fire_tol
	else:
		_aim_out = desired   # legacy: the arrow snaps to the solution every physics frame
	var fire := false
	match mode:
		1:
			fire = _my_aim_t >= maxf(profile.reaction_time * 0.5, 0.08) \
				and (on_target or _my_aim_t >= Tuning.bot_aim_dodge_max)
		2:
			var rt: float = lerpf(0.6, 0.12, profile.recovery_skill)
			fire = _my_aim_t >= rt and (on_target or _my_aim_t >= rt + Tuning.bot_aim_settle_max)
		3:
			fire = true
		4:
			fire = on_target or _my_aim_t >= Tuning.super_aim_max - 0.1
		_:
			fire = absf(_aim_roll) < profile.aim_error * 0.5 and on_target
	# §5 commit DWELL: hold the aim at least _aim_min_this before releasing so the §3 charge tell has
	# time to read (commitment only — aim quality is already baked into `desired`/`fire` above). The
	# fire-by ceiling extends to cover the floor; the 2s hard cap (super_aim_max) still auto-fires in
	# Player, so a bot can never camp. _aim_min_this is 0 for dodge/recovery aims, so they're unchanged.
	if _my_aim_t < _aim_min_this:
		fire = false
	if _my_aim_t >= maxf(profile.super_aim_time, _aim_min_this):
		fire = true   # L1 hangs comically (sometimes hits the 2s auto-fire); L5 snap-fires
	# WK-127 (a): the attack window was checked when the aim STARTED; re-check the line at release. If the
	# miss now carries me out through a blast line, HOLD (keep tracking: the line may come good again); only
	# in the last DUMP_LEAD s before the 2 s auto-fire swing to the dump direction instead.
	if wk127_enabled and mode == 0 and (fire or _my_aim_t >= Tuning.super_aim_max - DUMP_LEAD) \
			and not _whiff_survivable(me.global_position, _aim_out):
		fire = false
		if _my_aim_t >= Tuning.super_aim_max - DUMP_LEAD:
			_aim_dump = true
			_super_purpose = "attack_dump"
	it.aim = _aim_out
	it.super_hold = not fire
	if fire:
		_dodge_dir = Vector2.ZERO
		_aim_dump = false
		_aim_min_this = 0.0
		_aim_out = Vector2.ZERO

## WK-127: where a soured offensive aim is dumped: straight down the local pull into the floor (a slam = a
## bounce = refuel) when there is ground below, else back at the landing like a recovery super.
func _dump_dir() -> Vector2:
	var pos: Vector2 = me.global_position
	if not _over_void(pos):
		return _gdown(pos)
	return _comp_super_aim(_recovery_dir())

## WK-127: the super ADDS its impulse to the velocity I already have, so a goat falling at 1500 px/s that aims
## the blast straight at the island ends up launched below it. Aim so that velocity + impulse points along
## `want` (solve |k*want - v| = impulse for the forward root), i.e. lean the shot into the fall like a human.
## Falls back to `want` when the sideways velocity is larger than the impulse can cancel.
func _comp_super_aim(want: Vector2) -> Vector2:
	var u := want.normalized()
	var v: Vector2 = me.velocity
	var s: float = Tuning.super_boost_impulse_full * float(me.speed_mult)
	var uv: float = u.dot(v)
	var disc: float = uv * uv - v.length_squared() + s * s
	if disc <= 0.0 or s <= 0.0:
		return u
	var k: float = uv + sqrt(disc)
	if k <= 0.0:
		return u
	var aim: Vector2 = (u * k - v) / s
	return aim.normalized() if aim.length() > 0.01 else u

## WK-94: this bot's max super-aim stick speed (rad/s), by level from Tuning.bot_aim_turn_rate.
func _aim_turn_rate() -> float:
	var rates: Array = Tuning.bot_aim_turn_rate
	if rates.is_empty():
		return 6.0
	var r: float = float(rates[clampi(level - 1, 0, rates.size() - 1)])
	return r

## WK-94: low-recovery_skill PANIC is a slow wander, not per-frame white noise. Every bot_panic_reroll s a
## new target offset is rolled (±0.8 rad on a failed recovery_skill roll, else 0) and _panic_cur drifts
## toward it at bot_aim_noise_drift. Read by the recovery boost (_danger_recover) and the recovery super.
func _tick_panic(dt: float) -> void:
	if not aim_sweep_enabled:
		# legacy (pre-WK-94): a fresh ±0.8 rad roll EVERY physics frame on a failed recovery_skill roll
		_panic_target = randf_range(-0.8, 0.8) if randf() > profile.recovery_skill else 0.0
		_panic_cur = _panic_target
		return
	_panic_t -= dt
	if _panic_t <= 0.0:
		_panic_t = Tuning.bot_panic_reroll
		_panic_target = randf_range(-0.8, 0.8) if randf() > profile.recovery_skill else 0.0
	_panic_cur = move_toward(_panic_cur, _panic_target, Tuning.bot_aim_noise_drift * dt)

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

# ------------------------------------------------- gravity frame (bot brains v2 slice 1, INV-1)
# The bot's spatial sense expresses "down/up/fall" in the LOCAL gravity frame queried from
# GravityField. In a flat arena the field returns exactly global down, so _radial() is false
# everywhere and every branch below reduces to the legacy screen-down code path (regression-tested).

## Local unit "down" at a world position (defaults to my own position).
func _gdown(at := Vector2.INF) -> Vector2:
	if me == null or not is_instance_valid(me):
		return Vector2.DOWN
	var p: Vector2 = me.global_position if at == Vector2.INF else at
	var g: Vector2 = GravityField.get_gravity_at(p)
	return g.normalized() if g.length_squared() > 0.01 else Vector2.DOWN

## Is the local frame meaningfully rotated away from screen-down (off-axis inside a radial well)?
## Flat arenas / the well's straight-below-the-center column return false -> legacy code paths.
func _radial(down: Vector2) -> bool:
	return gravity_fix_enabled and down.y < Tuning.bot_radial_down_dot

## First bounce surface along `dir` from `from`, or {} if none within `dist`. The gravity-frame
## analogue of _ground_y_below: cast ALONG the local pull, whatever direction that is.
func _surface_along(from: Vector2, dir: Vector2, dist: float) -> Dictionary:
	if me == null or not is_instance_valid(me):
		return {}
	var space := me.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * dist, Player.MASK_SURFACES)
	q.exclude = [me.get_rid()]
	return space.intersect_ray(q)

## Gravity-aware "on/near the stage": flat frame = the legacy stage-rect test; radial frame = a
## position with floor along the local pull IS stage (any face of a round body is standable ground),
## so bots fight on moon faces instead of writing them off as off-stage space.
func _near_stage(p: Vector2, grow_px: float) -> bool:
	if _radial(_gdown(p)):
		return not _over_void(p)
	return _stage().grow(grow_px).has_point(p)

func _in_danger() -> bool:
	var pos: Vector2 = me.global_position
	# already over open void (no landing surface anywhere below) -> reflexive recovery, top priority
	if _over_void(pos):
		return true
	var future: Vector2 = pos + me.velocity * 0.6
	# WK-108: in an ENCLOSED court (sports) walls and ceiling stop you before the bounds do, so flying fast at a
	# wall is not "about to leave the arena" (that U-turned sports bots at every wall). Void (Dropshot holes) stays.
	var outside_soon := not _enclosed() and not _bounds().grow(-80.0).has_point(future)
	if outside_soon:
		return true
	# Radial frame: the well's round body IS the stage — a bot on ANY face of it is on safe ground.
	# The rect off_stage test and the x-column drift scan below are screen-down constructs and read
	# garbage off-axis; here danger is ONLY bounds-exit (above) or no floor along the pull (top).
	if _radial(_gdown(pos)):
		return false
	var off_stage := not _stage().grow(440.0).has_point(pos)
	if off_stage:
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
	var land_dir := dir
	# WK-95e: the WK-95 "arrive" steering that used to sit here (thrust along desired-minus-current velocity,
	# easing off near the landing point) was REMOVED. A 320-stage A/B showed it was the whole stuck/underside
	# regression: it held bots hovering and dribbling at the landing point while danger persisted and pushed
	# them into island undersides. Without it: stuck 2.76 -> 1.74/stage, underside 4.79 -> 3.61, boosted
	# underside 1.28 -> 0.42 (pre-WK-95 1.87 / 3.37 / 0.42). The circling it was added for no longer
	# appears in the wk95e_after_* recordings.
	# low recovery_skill: panic flail (the funny death). high skill: clean, hard recovery.
	# WK-94: the flail is the slow-drifting _panic_cur (a thumb wandering under stress), no longer a
	# fresh ±0.8 rad roll EVERY physics frame (which made the aim arrow strobe/spin).
	var braking := false
	if wk127_enabled:
		var hd := _recover_heading(me.global_position, me.velocity, dir)
		braking = hd != dir
		_braking = braking
		dir = hd
	if absf(_panic_target) > 0.0 or absf(_panic_cur) > 0.01:
		dir = dir.rotated(_panic_cur)
	elif braking:
		pass   # WK-127: a brake is never re-routed by the ascent detour / feeler-steer
	elif wk95_brain_enabled:
		# WK-95: steered flight now actually HOLDS the line to the landing point, so a recovery from under an
		# island flew straight into its underside. Route round the overhead platform edge first (the same
		# ascent detour the hunt path uses), then the feeler-steer.
		dir = _steer(_ascent_detour(dir))
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
	var out_speed: float = -me.velocity.dot(land_dir if wk95_brain_enabled else dir)
	if wk95_brain_enabled:
		# WK-95 BR-4: the recovery super is a LAST RESORT: too hot to reel in by flight, or STRANDED (over the
		# void and the landing is unreachable on the fuel we have). Low fuel alone is never a reason (low +
		# reachable = boost home). "Reachable" here is the spec §8.1 test (fuel / CROSS_FUEL_PER_PX, NO landing
		# reserve): the reserve is a margin for planning a deliberate crossing, not for deciding to gamble.
		var unreachable := false
		if wk127_enabled:
			# WK-127 (b): the WK-95 dx-below test read INF whenever the goat was under the platform tops (spires /
			# the_ascent's bottom tier) and fired at 50-97 fuel. Now (A) the RANGE test counts landings above me
			# too (climb-aware), and (B) a MOMENTUM test: the predicted recovery flight (my thrust law, grip,
			# gravity, fuel) still crosses a blast line while it has thrust left (too fast to brake in time).
			# Skipped when the super can't fire anyway.
			var pos0: Vector2 = me.global_position
			if me.fuel >= Tuning.super_boost_min_fuel and _over_void(pos0):
				var budget: float = me.fuel / CROSS_FUEL_PER_PX
				unreachable = _nearest_ground_dx(pos0) > budget and _climb_landing(pos0, budget).is_empty()
				if not unreachable:
					unreachable = _flight_recovers(pos0, land) == 1
		else:
			unreachable = _over_void(me.global_position) \
				and me.fuel < _nearest_ground_dx(me.global_position) * CROSS_FUEL_PER_PX
		var hot: bool = out_speed > 1400.0 and (not wk95_hot_stopdist or not _can_arrest(out_speed))
		if me.fuel >= Tuning.super_boost_min_fuel and (hot or unreachable) and not me.super_arm_locked():   # WK-20d: a locked super press is dropped -> boost instead
			it.super_hold = true
			it.boost = false
			_super_purpose = "recovery_hot" if hot else "recovery_unreachable"
		elif not braking:
			it.aim = _fly_aim(it.aim)   # BR-2: boost home on a sag-compensated line
	else:
		var stranded: bool = _over_void(me.global_position) and not _can_reach(land_dist)
		if me.fuel >= Tuning.super_boost_min_fuel and (me.fuel <= 12.0 or out_speed > 1400.0 or stranded) and not me.super_arm_locked():   # WK-20d
			it.super_hold = true
			it.boost = false
			_super_purpose = "recovery_hot" if out_speed > 1400.0 else ("recovery_unreachable" if stranded else "recovery_lowfuel")
	_cached_aim = dir
	_cached_boost = it.boost
	return true

## Reaction-tick decision (§3.2): refuel rhythm > hunt/AIM > drift home.
func _decide() -> void:
	var pos: Vector2 = me.global_position
	_cached_super = false
	_refuel_dive = false
	_obj_live = false   # WK-108b
	# --- refuel rhythm (rule 2): below the floor, dive to a bounce surface — one bounce re-arms
	if me.fuel < _eff_refuel_floor():
		# Radial frame: the refuel dive is ALONG the local pull — the well's round body / shell
		# platform below is the bounce surface (one bounce re-arms). The stage-rect-bottom dive and
		# _refuel_x column scan below are screen-down constructs. (§2a finisher transit bias skipped:
		# wells are small, every dive lands near the fight.)
		var rdown := _gdown(pos)
		if _radial(rdown):
			var rhit := _surface_along(pos - rdown * 40.0, rdown, VOID_PROBE_DROP)
			var no_target := false   # WK-135 BR-135a: surfaces along the pull, but none that can pay
			var wk161_skip_a: bool = Tuning.wk161_radial_pin_skip and Tuning.wk161_radial_skip_target and _wk161_in_well(pos)   # WK-161
			if wk135_no_pin and not wk161_skip_a and not rhit.is_empty() and not _wk135_refuel_ok(rhit):   # WK-135 BR-135a (WK-161)
				rhit = {}   # WK-135
				for ang in [0.45, -0.45]:   # WK-135: look a little either side of the pull for a paying face
					var alt := _surface_along(pos - rdown * 40.0, rdown.rotated(ang), VOID_PROBE_DROP)   # WK-135
					if not alt.is_empty() and _wk135_refuel_ok(alt):   # WK-135
						rhit = alt   # WK-135
						break   # WK-135
				no_target = rhit.is_empty()   # WK-135
			var rtarget: Vector2 = (rhit["position"] as Vector2) if not rhit.is_empty() \
				else pos + rdown * Tuning.bot_radial_dive_fallback
			var rdir := (rtarget - pos).normalized()
			_cached_aim = rdir
			_refuel_dive = true
			_refuel_dir = rdir
			_refuel_cross = false
			# boost only when falling AWAY from the surface (same trigger as the flat dive)
			_cached_boost = me.fuel > 2.0 and me.velocity.dot(rdir) < -60.0
			if _cached_boost and wk128_refuel_wait and me.refund_rearm_pending(rdir):
				_cached_boost = false   # WK-128 BR-128: ride this paying bounce to its apex (a chop-hop would not pay)
			if _cached_boost and (no_target or _wk135_into_excluded(rdir)):   # WK-135 BR-135a/b: never thrust at a
				_cached_boost = false   # non-paying or just-pinned face; the pull carries us onto whatever is below  # WK-135
			_hunt = false
			return
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
		_refuel_dive = true
		_refuel_dir = dir
		_refuel_cross = must_cross
		_cached_boost = me.fuel > 2.0 and (me.velocity.dot(dir) < -60.0 or must_cross)
		if _cached_boost and not must_cross and wk128_refuel_wait and me.refund_rearm_pending(dir):
			_cached_boost = false   # WK-128 BR-128: ride this paying bounce to its apex (a chop-hop would not pay)
		if _cached_boost and not must_cross and _wk135_into_excluded(dir):   # WK-135 BR-135b: no thrust-dribble into a
			_cached_boost = false   # just-pinned bumper top (flat dives only ever target tops: the probe is a downward ray)  # WK-135
		if _cached_boost and must_cross:
			_cached_aim = _fly_aim(dir)   # WK-95 BR-2: a crossing dive flies a held line
		_hunt = false
		return
	# --- MODE OBJECTIVE OVERRIDE (v5_sports bot-play fix): if the active mode supplies a world point to
	# go to (SPORTS -> a strike point on the ball), fly there with the EXISTING movement/boost logic and
	# skip the nearest_opponent hunt. Default (BRAWL/TRIALS/GAUNTLET) returns null -> unchanged below.
	# Evaluated AFTER refuel (secure fuel first) and AFTER reflexive _danger_recover (checked in poll).
	var objective: Variant = _mode_objective()
	if objective is Vector2:
		_pursue_objective(objective, pos)
		_obj_live = true   # WK-108b
		var iv: float = _wk108b_replan_iv()   # WK-108b K2: the next fast re-plan counts from this decision
		_obj_replan_t = iv if iv < INF else 0.05   # WK-108b
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
			_hunt = true
			_commit_t = _eff_commit_time()
			if wk95_brain_enabled:
				# WK-95 BR-1/BR-3: fly the approach; super only inside the attack window (range <= ~1070 + LOS)
				var fwhy := _attack_window_why(fopp)
				var fwin := fwhy == 0
				_cached_aim = _jitter(_fly_aim(fd.normalized()))
				# close the distance by flight; inside 0.8 x range keep flying only to get AROUND a blocker (LOS),
				# never orbit a target we cannot safely shoot (the first after-recordings showed bots circling)
				_cached_boost = me.fuel > _eff_refuel_floor() and (fdist > _eff_attack_range() * 0.8 or fwhy == 3)
				if fwhy == 5 or fwhy == 6:
					_cached_boost = false   # WK-127: in reach but no shot (blinking / whiff exits) -> wait, don't crowd the line
				if fwin:
					_cached_super = true
					_super_purpose = "finisher_attack"
				return
			_cached_aim = _jitter(fd.normalized())
			_cached_boost = fdist > _eff_attack_range() * 0.8 and me.fuel > _eff_refuel_floor()
			if fdist < _eff_attack_range() and me.fuel >= _eff_refuel_floor() \
					and _super_safe(pos, fopp.global_position):
				_cached_super = true
				_super_purpose = "finisher_attack"
			return
	var on_stage := _near_stage(pos, 360.0)
	var target = _pick_target()
	_target = target
	if target != null and is_instance_valid(target) and on_stage:
		var tp: Vector2 = target.global_position
		var d: Vector2 = tp - pos
		var dist := d.length()
		_cached_aim = _jitter(d.normalized())
		# hunt commitment (§3.1 commit_time): once rolled TRUE it sticks — no re-rolling every tick
		var target_near := _near_stage(tp, 520.0)
		# §5.5: in finisher, never disengage the lone survivor on distance — chase it to the edge
		# (where the kill lives); otherwise keep the dist-gated + edge-guard prey logic.
		var target_ok := true if _finisher else (target_near or _is_edge_guard_prey(target))
		if not (_hunt and _commit_t > 0.0):
			_hunt = randf() < _eff_aggression() and target_ok
			if _hunt:
				_commit_t = _eff_commit_time()
		elif not target_ok:
			_hunt = false
		if wk95_brain_enabled:
			# WK-95 BR-1/BR-2/BR-3: the approach is FLOWN (sag-compensated aim); the super fires only inside
			# the attack window (led target in range <= ~1070, line of sight clear, fuel, _super_safe). In range
			# but no window (a platform in the way): keep flying around it, never super to close distance.
			var why: int = _attack_window_why(target) if _hunt else 1
			var win: bool = _hunt and why == 0
			_cached_aim = _jitter(_fly_aim(d.normalized()))
			# close the distance by flight; inside 0.8 x range keep flying only to get AROUND a blocker (LOS),
			# never orbit a target we cannot safely shoot (the first after-recordings showed bots circling)
			_cached_boost = _hunt and me.fuel > _eff_refuel_floor() and (dist > _eff_attack_range() * 0.8 or why == 3)
			if why == 5 or why == 6:
				_cached_boost = false   # WK-127: in reach but no shot (blinking / whiff exits) -> wait, don't crowd the line
			if win:
				_cached_super = true
				_super_purpose = "attack"
			return
		_cached_boost = _hunt and dist > _eff_attack_range() * 0.8 and me.fuel > _eff_refuel_floor()
		# enter AIM (rule 1): hunting, in range, fueled past the floor (attack-run budget), and the
		# blast won't launch me out over the void with no target in line (§ whiff-super self-ringout).
		if _hunt and dist < _eff_attack_range() and me.fuel >= _eff_refuel_floor() \
				and _super_safe(pos, tp):
			_cached_super = true
			_super_purpose = "attack"
	else:
		# no target / off-stage drift: ease back toward the nearest LANDING surface (never stage_center,
		# which sits over a void gap on islands_void — that dove drifting bots into the chasm).
		var land := _land_target(pos)
		var to_land := land - pos
		_cached_aim = _jitter(_fly_aim(to_land.normalized())) if to_land.length() > 160.0 else Vector2.ZERO
		_cached_boost = me.fuel > 35.0 and to_land.length() > 360.0
		_hunt = false

## Ask the active mode for a world-point objective this tick (v5_sports bot-play fix). Returns a
## Vector2 (fly here) or null (no override -> default hunt). `arena._mode` is the runner's GameMode;
## the base GameMode.bot_objective returns null, so BRAWL/TRIALS/GAUNTLET are byte-for-byte unchanged.
func _mode_objective() -> Variant:
	if arena == null or not ("_mode" in arena):
		return null
	var mode = arena._mode
	if mode == null or not mode.has_method("bot_objective"):
		return null
	return mode.bot_objective(arena, me)

## Fly toward a mode-supplied world point using the SAME steering the hunt path uses: jittered aim at
## the target, boost when it's far enough and there's fuel to spend. No super, no hunt-commit — the
## objective (e.g. the SPORTS strike point) fully governs WHERE; poll() still runs the ascent-detour +
## feeler-steer on the resulting aim, so the bot routes around bumpers instead of head-banging them.
func _pursue_objective(target: Vector2, pos: Vector2) -> void:
	_cached_super = false
	_hunt = false
	var d: Vector2 = target - pos
	var dist := d.length()
	if dist < 1.0:
		_cached_aim = Vector2.ZERO
		_cached_boost = false
		return
	_cached_aim = _jitter(_fly_aim(d.normalized()))
	_cached_boost = dist > 90.0 and me.fuel > 2.0

## WK-108b K2: the mode's fast re-plan interval for me right now (INF = none / not a sports mode).
func _wk108b_replan_iv() -> float:
	if arena == null or not ("_mode" in arena) or arena._mode == null or not arena._mode.has_method("bot_replan_interval"):
		return INF
	return float(arena._mode.bot_replan_interval(arena, me))

## WK-108b K2: between reaction ticks, re-run ONLY the sports objective (no dodge roll, no refuel/hunt re-decision) every
## bot_replan_interval while the ball is fast or near. Skipped below the refuel floor (the next real tick dives to refuel).
func _wk108b_replan(dt: float) -> void:
	_obj_replan_t -= dt
	if _obj_replan_t > 0.0:
		return
	var iv: float = _wk108b_replan_iv()
	_obj_replan_t = iv if iv < INF else 0.05   # off / slow ball: look again shortly (cheap)
	if iv == INF or me.fuel < _eff_refuel_floor():
		return
	var objective: Variant = _mode_objective()
	if objective is Vector2:
		_pursue_objective(objective, me.global_position)
		wk108b_replans += 1

## WK-108b K3/K5: the mode's per-frame strike guard (Vector2.ZERO = keep my aim). `recovering` = called from the danger
## recovery (the mode skips the Dropshot net brake there: a floor hole is real void). Non-sports modes: one has_method, cached.
func _wk108b_guard(recovering: bool) -> Vector2:
	if _wk108b_has_guard < 0:
		_wk108b_has_guard = 1 if arena != null and ("_mode" in arena) and arena._mode != null 			and arena._mode.has_method("bot_strike_guard") else 0
	if _wk108b_has_guard == 0:
		return Vector2.ZERO
	return arena._mode.bot_strike_guard(arena, me, recovering)

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
		_cached_aim = _steer(_fly_aim(d.normalized()))
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
	# gravity-aware: a rival standing on a moon face is ON stage, not off-stage prey
	return not _near_stage(p.global_position, 360.0)

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
			# prefer the side that carries me back over bounce surfaces — in a radial frame the
			# bounce floor is along the LOCAL pull (the well's body), not at the stage-rect center
			var down := _gdown()
			var to_safe: Vector2 = down if _radial(down) \
				else (_stage_center() - me.global_position).normalized()
			if perp.dot(to_safe) < 0.0:
				perp = -perp
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
	var down := _gdown(p)
	if _radial(down):
		# radial frame: "below" is along the local pull — a body face along it IS floor
		return _surface_along(p - down * 40.0, down, VOID_PROBE_DROP).is_empty()
	return _ground_y_below(p.x, p.y - 40.0) == INF

## Fuel needed to translate `dx` px horizontally under boost, plus a reserve to keep after landing.
func _can_reach(dx: float) -> bool:
	if not wk95_brain_enabled:
		return me.fuel >= dx * CROSS_FUEL_PER_PX_LEGACY + CROSS_FUEL_RESERVE_LEGACY
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
	var down := _gdown(pos)
	if _radial(down):
		# Radial frame: recover ALONG the local pull to the surface it lands on (a moon face IS
		# floor; in Singularity the shell platforms/bumper hub are the catch). Hover the landing
		# margin above it so we clear any lip. The x-column scans below are screen-down constructs.
		var hit := _surface_along(pos - down * 40.0, down, VOID_PROBE_DROP)
		if not hit.is_empty():
			return (hit["position"] as Vector2) - down * VOID_LAND_MARGIN
		return pos + down * Tuning.bot_radial_dive_fallback   # defensive: ride the pull inward
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
		if wk127_enabled:
			# WK-127 (b): nothing below my height (knocked under the spire tops / beside a tier) -> fly to the
			# nearest landing ABOVE me that the tank can reach, not just the nearest spawn
			var cl := _climb_landing(pos, me.fuel / CROSS_FUEL_PER_PX)
			if not cl.is_empty():
				var cp: Vector2 = cl["point"]
				# below the landing's height: climb my own (void, so open) column to that height FIRST, then
				# cross — a diagonal line from under the lip hits the platform's corner/underside and stalls
				if pos.y > cp.y + 60.0 and absf(cp.x - pos.x) > 60.0:
					return Vector2(pos.x, cp.y)
				return cp
		return _fallback_land(pos)
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

## WK-127 (b): the nearest landing within `budget_px` of flight when the surfaces may be ABOVE me. Re-runs the
## column scan from probe heights CLIMB_PROBES above my position (a ray down from there finds platform tops
## up to that high), and costs each landing as the straight flight to just over its lip (a climb under boost
## costs about the same fuel per px as a level crossing: 5400 accel >> 0.8 g, same 800 px/s cap). Flat frame
## only (radial wells recover along the pull). Returns {"point", "px"} or {} when nothing is in budget.
func _climb_landing(pos: Vector2, budget_px: float) -> Dictionary:
	if _radial(_gdown(pos)):
		return {}
	var b := _bounds()
	var lo: float = maxf(b.position.x + 60.0, pos.x - budget_px)
	var hi: float = minf(b.end.x - 60.0, pos.x + budget_px)
	var cx: float = clampf(pos.x, b.position.x + 60.0, b.end.x - 60.0)
	var best := {}
	var best_px := budget_px
	for h in CLIMB_PROBES:
		var py: float = pos.y - float(h)
		if py < b.position.y + 80.0 or float(h) > best_px:
			break
		for dir_x in [-1.0, 1.0]:
			var x := cx
			while (dir_x < 0.0 and x >= lo) or (dir_x > 0.0 and x <= hi):
				if absf(x - pos.x) > best_px:
					break
				var sy: float = _ground_y_below(x, py)
				if sy < INF:
					# land just over the lip, nudged onto the platform (runway), never into the underside
					var tx: float = x + dir_x * VOID_LAND_NUDGE
					if _ground_y_below(tx, py) == INF:
						tx = x
					var pt := Vector2(tx, sy - VOID_LAND_MARGIN)
					var px: float = pos.distance_to(pt)
					if px < best_px:
						best_px = px
						best = {"point": pt, "px": px}
					break
				x += dir_x * 100.0
	return best

## WK-127 (b): predict the bot's recovery FLIGHT from its current state, flying the same heading law as
## _danger_recover (_recover_heading: brake against the velocity when about to cross a blast line, else
## toward `land`) with Player's boost rules (cap along the aim, 0.8 g while thrusting, the steering grip below
## boost_grip_speed_max, drain; boost stops at <= 4 fuel and the stick then only air-drifts).
## 0 = recovers (within RECOVER_ARRIVE of the landing point, a refuelling touch, or still in bounds at the
## horizon); 1 = crosses a blast line while it still has thrust (momentum: too fast to brake);
## 2 = crosses after the tank ran dry (range).
func _flight_recovers(pos: Vector2, land: Vector2) -> int:
	if me == null or not is_instance_valid(me):
		return 0
	var b := _bounds()
	var dt := WHIFF_SIM_DT
	var p := pos
	var v: Vector2 = me.velocity
	var fuel: float = me.fuel
	var bp: float = me.profile.eff_boost_power()
	var cap: float = Tuning.normal_boost_max_speed * bp
	var acc: float = Tuning.normal_boost_accel * bp * dt
	var drain: float = Tuning.normal_boost_drain() * dt
	var ac: float = me.profile.eff_air_control()
	var t := 0.0
	while t < RECOVER_SIM_T:
		var g: Vector2 = GravityField.get_gravity_at(p)
		var to: Vector2 = land - p
		if to.length() < RECOVER_ARRIVE:
			return 0
		var a := _recover_heading(p, v, to.normalized())
		if fuel > 4.0:
			v += g * Tuning.boost_gravity_scale * dt
			var along: float = v.dot(a)
			if along < cap:
				v += a * minf(acc, cap - along)
			var sp: float = v.length()
			if Tuning.boost_grip_rate > 0.0 and sp < Tuning.boost_grip_speed_max:
				var vperp: Vector2 = v - a * v.dot(a)
				var vp: float = vperp.length()
				if vp > 0.001:
					var dv: Vector2 = -vperp / vp * minf(minf(Tuning.boost_grip_rate * vp, Tuning.boost_grip_decel_max) * dt, vp)
					var up: Vector2 = -g.normalized() if g.length_squared() > 0.01 else Vector2.UP
					if v.dot(up) > 0.0 and dv.dot(up) < 0.0:
						dv -= up * dv.dot(up)
					v += dv
			fuel -= drain
		else:
			v += g * dt
			v.x = move_toward(v.x, signf(a.x) * Tuning.air_drift_max_speed * ac, Tuning.air_drift_accel * ac * dt)
		v = v.limit_length(Tuning.max_speed)
		var hit := _sim_step(p, v, g)
		if hit == 1:
			return 0
		if hit == 2:
			v = v.bounce(_sim_normal) * 0.6   # head-bang on an underside: no refuel, knocked back down
		else:
			p += v * dt
		if not b.has_point(p):
			return 1 if fuel > 4.0 else 2
		t += dt
	return 0

## WK-127: the recovery thrust heading. About to cross a blast line (the same 0.6 s look-ahead _in_danger
## uses) -> thrust straight against the velocity: braking is what saves you, and the old heading (at the
## landing point, deflected by the feeler-steer because the platform below read as an obstacle) let goats
## bounced off the_ascent's top trampoline coast into the sky lid with a full tank. Only when NOTHING solid
## lies between me and that line along my velocity: a wall / ceiling / court side catches me first (sports
## courts, the_ascent's bumper walls), and braking at those turned sports bots into wall-hoverers.
## Otherwise -> `to_land`.
func _recover_heading(p: Vector2, v: Vector2, to_land: Vector2) -> Vector2:
	var sp: float = v.length()
	if sp > 1.0 and not _enclosed() and not _bounds().grow(-80.0).has_point(p + v * 0.6):
		if _surface_along(p, v / sp, sp * 0.6 + 120.0).is_empty():
			return -v / sp
	return to_land

## One predictor step: 0 = clear, 1 = touched a refuelling surface (floor / side / bumper), 2 = an underside
## (normal along the local pull — Player refunds no fuel there, see Player._on_bounced).
func _sim_step(p: Vector2, v: Vector2, g: Vector2) -> int:
	var q := PhysicsRayQueryParameters2D.create(p, p + v * WHIFF_SIM_DT, Player.MASK_SURFACES)
	q.exclude = [me.get_rid()]
	var hit := me.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 0
	var n: Vector2 = hit["normal"]
	_sim_normal = n
	var gd: Vector2 = g.normalized() if g.length_squared() > 0.01 else Vector2.DOWN
	return 2 if n.dot(gd) > 0.5 else 1

## No x-column with ground below in scan range. Unreachable on flat levels (there is always ground
## somewhere in the band — legacy returned stage_center there); REACHABLE in an orbital arena's
## neutral corridor (twin_moons: global-down space between the wells, floors are the moons/perches).
## Head for the nearest spawn point — spawns always sit on real floor (moon poles / perches) — so a
## corridor knock-out recovers toward a landable surface instead of an abstract rect center.
func _fallback_land(pos: Vector2) -> Vector2:
	if not gravity_fix_enabled:
		return _stage_center() + Vector2(0, -120)   # A/B: legacy fallback
	var candidates: Array = arena._spawns if ("_spawns" in arena) else []
	var best := Vector2.ZERO
	var bd := INF
	for s in candidates:
		var sp: Vector2 = s
		var d: float = sp.distance_to(pos)
		if d < bd:
			bd = d
			best = sp
	if bd < INF:
		return best - _gdown(best) * VOID_LAND_MARGIN
	return _stage_center() + Vector2(0, -120)   # legacy fallback (no spawns known)

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

## World-y of the nearest bounce surface directly ABOVE (x, from_y), or -INF if none within reach.
## The UPWARD analogue of _ground_y_below — the overhead-obstruction sense (owner head-bang fix).
## Ray-probe, so it is GEOMETRY-generic (no hardcoded coords — works on every level).
func _ceiling_y_above(x: float, from_y: float) -> float:
	if me == null or not is_instance_valid(me):
		return -INF
	var space := me.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, from_y), Vector2(x, from_y - ASCENT_PROBE), Player.MASK_SURFACES)
	q.exclude = [me.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else -INF

## Scan horizontally (stepping in `dir`) for the world-x where the overhead platform ENDS (no ceiling
## within probe at that column), or NAN if none before `limit_x`. Finds a platform edge to route around.
func _clear_x_past_ceiling(from_x: float, from_y: float, dir: float, limit_x: float) -> float:
	var x := from_x
	for _i in range(ASCENT_EDGE_MAX):
		x += dir * ASCENT_EDGE_STEP
		if (dir > 0.0 and x > limit_x) or (dir < 0.0 and x < limit_x):
			return NAN
		if _ceiling_y_above(x, from_y) == -INF:
			return x
	return NAN

## An overhead-edge column is safe to detour toward only if it does NOT dump us into an UNREACHABLE
## void (preserve void-avoidance): ground below the column, or an over-void column still reachable on
## the current tank. Never routes a bot into open void it can't cross.
func _edge_ok(tx: float, pos: Vector2) -> bool:
	if not _over_void(Vector2(tx, pos.y)):
		return true
	return _can_reach(absf(tx - pos.x))

## Obstacle-aware ASCENT (owner head-bang fix): when the bot boosts UP toward a goal above but a solid
## platform overhead blocks the climb, steer LATERALLY toward the nearest CLEAR edge of that platform
## first (prefer the side toward the goal via aim.x, else the nearer edge), clear the lip, THEN climb —
## "up" sometimes means "sideways then up." Returns the (possibly redirected) aim. Void-safe: an edge
## over unreachable void is skipped; if the bot is boxed in on both sides it falls through to _steer.
func _ascent_detour(aim: Vector2) -> Vector2:
	if not ascent_fix_enabled:
		return aim   # A/B: fix disabled -> reproduce the head-bang for a BEFORE measurement
	if aim.y > ASCENT_AIM_UP or me == null or not is_instance_valid(me):
		return aim   # not meaningfully ascending
	var pos: Vector2 = me.global_position
	if _radial(_gdown(pos)):
		# radial frame: "up" isn't -y and there's no rect platform grid to edge-route around the
		# orbital arenas' round bodies — _steer's feeler fan handles local avoidance there.
		return aim
	var head_y := pos.y - 40.0
	if _ceiling_y_above(pos.x, head_y) == -INF:
		return aim   # open sky above -> a real climb, no obstruction to route around
	var lo: float = _bounds().position.x + 40.0
	var hi: float = _bounds().end.x - 40.0
	var left_x := _clear_x_past_ceiling(pos.x, head_y, -1.0, lo)
	var right_x := _clear_x_past_ceiling(pos.x, head_y, 1.0, hi)
	var cands: Array = []
	if not is_nan(left_x):
		var lx: float = maxf(lo, left_x - ASCENT_EDGE_MARGIN)
		if _edge_ok(lx, pos):
			cands.append({"x": lx, "dx": absf(lx - pos.x), "side": -1.0})
	if not is_nan(right_x):
		var rx: float = minf(hi, right_x + ASCENT_EDGE_MARGIN)
		if _edge_ok(rx, pos):
			cands.append({"x": rx, "dx": absf(rx - pos.x), "side": 1.0})
	if cands.is_empty():
		return aim   # boxed in / both edges dump into unreachable void -> _steer + danger-recover handle it
	# prefer the side toward the goal (aim.x); else the nearer reachable edge
	var goal_side := signf(aim.x)
	var chosen = null
	if goal_side != 0.0:
		for c in cands:
			if c.side == goal_side:
				chosen = c
	if chosen == null:
		for c in cands:
			if chosen == null or c.dx < chosen.dx:
				chosen = c
	# steer PURELY LATERAL toward the edge (NO up component) so gravity keeps us UNDER the lip and we
	# don't creep back into the underside while traversing. Once past the edge the ceiling probe reads
	# clear, the detour disengages, and the next-frame goal aim climbs. Boost stays on (set by caller).
	_mh_detours += 1
	return Vector2(chosen.side, 0.0)

# ---------------------------------------------------------------- motion-health telemetry (QA feed)

## Per-frame motion-health update (process gate). Measures the previous frame's committed intent vs
## the resulting motion: (a) STUCK = intending to move toward a goal but ~0 net displacement over ~1s;
## (c) BLOCKED-ASCENT = wants altitude (aiming up + boosting) but Y not decreasing. (b) underside-bounce
## is counted event-driven in _on_surface_bounced. These make "looks dumb" a NUMBER, caught forever.
func _update_motion_health(dt: float, boost: bool, aim: Vector2) -> void:
	if me == null or not is_instance_valid(me):
		return
	var pos: Vector2 = me.global_position
	var intending: bool = boost and aim != Vector2.ZERO
	# (a) STUCK / no-progress over a ~1s sliding window
	_mh_clock += dt
	_mh_samples.append({"t": _mh_clock, "pos": pos, "move": intending})
	while _mh_samples.size() > 1 and _mh_clock - float(_mh_samples[0]["t"]) > MH_STUCK_WINDOW:
		_mh_samples.pop_front()
	var span: float = _mh_clock - float(_mh_samples[0]["t"])
	var stuck_now := false
	var disp_now := -1.0   # WK-161: window displacement (dump)
	if span >= MH_STUCK_WINDOW * 0.9:
		var disp: float = pos.distance_to(_mh_samples[0]["pos"])
		disp_now = disp   # WK-161
		var moving := 0.0
		for s in _mh_samples:
			if s["move"]:
				moving += 1.0
		var move_frac: float = moving / float(_mh_samples.size())
		stuck_now = move_frac > 0.6 and disp < MH_STUCK_DISP
	if stuck_now:
		if not _mh_in_stuck:
			_mh_in_stuck = true
			_mh_stuck_episodes += 1
			_wk161_record("stuck", _wk161_last_p, _wk161_last_n, _wk161_last_face, disp_now)   # WK-161
		_mh_stuck_secs += dt
	else:
		_mh_in_stuck = false
	# (c) BLOCKED-ASCENT: aiming up + boosting, but the highest point reached isn't improving.
	# "Up" is against the LOCAL gravity frame; in a flat arena down=(0,1) so aim.dot(down)==aim.y and
	# the progress dot == the old ref_y - pos.y test — algebraically identical to the legacy code.
	var down := _gdown(pos)
	var ascending: bool = boost and aim.dot(down) < ASCENT_AIM_UP
	if ascending:
		if not _mh_asc_active:
			_mh_asc_active = true
			_mh_asc_ref_pos = pos
			_mh_asc_t = 0.0
			_mh_blocked_now = false
		else:
			_mh_asc_t += dt
			if (_mh_asc_ref_pos - pos).dot(down) > MH_ASCENT_PROGRESS:
				_mh_asc_ref_pos = pos   # real upward progress -> not blocked, restart the stall clock
				_mh_asc_t = 0.0
				_mh_blocked_now = false
			elif _mh_asc_t >= MH_ASCENT_STALL:
				if not _mh_blocked_now:
					_mh_blocked_now = true
					_mh_blocked_ascent_episodes += 1
				_mh_blocked_ascent_secs += dt
	else:
		_mh_asc_active = false
		_mh_blocked_now = false

# ---------------------------------------------------------------- WK-135 BR-135 (bots never thrust-pin a bumper)

## WK-135: face key of a bumper contact, the same scheme as Player._wk128_face_key (rect: collider + snapped normal; round:
## collider). `n` arrives already axis-snapped (rect) / radial (round) from Player._resolve_bounces.
func _wk135_face_key(surface: Object, n: Vector2) -> String:  # WK-135
	if surface == null:  # WK-135
		return "~"  # WK-135
	if surface.has_meta("round"):  # WK-135
		return str(surface.get_instance_id())  # WK-135
	return "%d:%d:%d" % [surface.get_instance_id(), roundi(n.x), roundi(n.y)]  # WK-135

## WK-135 BR-135b: count contacts with ONE bumper face made while thrusting into it; at Tuning.bot_pin_contacts within
## bot_pin_window, release boost for one reaction tick and exclude the face for bot_pin_exclude_s (re-plan right after).
func _wk135_pin_contact(surface: Node2D, n: Vector2, contact: Vector2) -> void:  # WK-135
	var key := _wk135_face_key(surface, n)  # WK-135
	if key != _pin_key:  # WK-135
		_pin_key = key  # WK-135
		_pin_hits.clear()  # WK-135
	var a: Vector2 = _intent.aim  # this frame's emitted stick (the thrust direction)  # WK-135
	if not me.is_boosting() or a.length() < 0.1 or a.normalized().dot(n) >= Tuning.bot_pin_into_dot:  # WK-135
		return  # WK-135
	_pin_hits.append(_pin_clock)  # WK-135
	while not _pin_hits.is_empty() and _pin_clock - float(_pin_hits[0]) > Tuning.bot_pin_window:  # WK-135
		_pin_hits.pop_front()  # WK-135
	if _pin_hits.size() < Tuning.bot_pin_contacts:  # WK-135
		return  # WK-135
	_pin_hits.clear()  # WK-135
	if Tuning.wk161_radial_pin_skip and (surface.has_meta("round") or _wk161_in_well(contact)):   # WK-161: inside a radial
		_wk161_well_skips += 1   # well: no face exclusion, no slide steering (BR-135-OFF brain); optionally the release only  # WK-161
		me.wk135_count("wk161_well_skips")   # WK-161
		if Tuning.wk161_radial_keep_release:   # WK-161
			_pin_release_t = profile.reaction_time   # WK-161
			me.wk135_count("wk135_pin_breaks")   # WK-161: a release still counts as a break (comparable to the A/B)
		return   # WK-161
	_pin_release_t = profile.reaction_time  # WK-135
	_react = _pin_release_t   # re-plan the moment the release ends, with the face excluded  # WK-135
	_pin_ex_t = Tuning.bot_pin_exclude_s  # WK-135
	_pin_ex_key = key  # WK-135
	_pin_ex_round = surface.has_meta("round")  # WK-135
	_pin_ex_n = n.normalized()  # WK-135
	_pin_ex_p = contact  # WK-135
	_pin_ex_c = surface.global_position  # WK-135
	_pin_ex_r = contact.distance_to(_pin_ex_c)  # WK-135
	var gup: Vector2 = -_gdown(contact)  # WK-135
	_pin_ex_wall = not _pin_ex_round and absf(_pin_ex_n.dot(gup)) <= Tuning.bumper_floor_dot  # WK-135
	_pin_ex_body = weakref(surface)  # WK-135
	_pin_ex_half_t = -1.0  # WK-135
	for ch in surface.get_children():  # WK-135: rect extent of the face (LevelLoader / prop bumpers: one RectangleShape2D)
		if ch is CollisionShape2D and (ch as CollisionShape2D).shape is RectangleShape2D:  # WK-135
			var sz: Vector2 = ((ch as CollisionShape2D).shape as RectangleShape2D).size  # WK-135
			var tt := Vector2(-_pin_ex_n.y, _pin_ex_n.x)  # WK-135
			_pin_ex_off = (ch as CollisionShape2D).position  # WK-135
			_pin_ex_half_t = 0.5 * (absf(tt.x) * sz.x + absf(tt.y) * sz.y)  # WK-135
			_pin_ex_half_n = 0.5 * (absf(_pin_ex_n.x) * sz.x + absf(_pin_ex_n.y) * sz.y)  # WK-135
			break  # WK-135
	me.wk135_count("wk135_pin_breaks")   # telemetry -> round_stats.motion_health.wk128  # WK-135

## WK-135: outward normal of the excluded face at my position + my distance off it; Vector3(nx, ny, dist), dist = INF when
## no face is excluded or I am beside / behind it (its plane, but past the post's length).
func _wk135_ex_frame() -> Vector3:  # WK-135
	if _pin_ex_t <= 0.0 or not wk135_no_pin or me == null or not is_instance_valid(me):  # WK-135
		return Vector3(0.0, 0.0, INF)  # WK-135
	var pos: Vector2 = me.global_position  # WK-135
	if Tuning.wk161_radial_pin_skip and _wk161_in_well(pos):   # WK-161: an exclusion set outside a well never steers inside one
		return Vector3(0.0, 0.0, INF)   # WK-161
	if _pin_ex_round:  # WK-135
		var rel := pos - _pin_ex_c  # WK-135
		var rn := rel.normalized() if rel.length() > 0.01 else _pin_ex_n  # WK-135
		return Vector3(rn.x, rn.y, rel.length() - _pin_ex_r)  # WK-135
	var tt := Vector2(-_pin_ex_n.y, _pin_ex_n.x)  # WK-135
	var body: Node2D = (_pin_ex_body.get_ref() as Node2D) if _pin_ex_body != null else null  # WK-135
	if _pin_ex_half_t >= 0.0 and body != null:  # WK-135: the real face segment (past its end = round the corner = free)
		var d := pos - (body.global_position + _pin_ex_off)  # WK-135
		if absf(d.dot(tt)) > _pin_ex_half_t + me._radius + 16.0:  # WK-135
			return Vector3(0.0, 0.0, INF)  # WK-135
		var fd: float = d.dot(_pin_ex_n) - _pin_ex_half_n - me._radius  # WK-135
		if fd < -20.0:  # WK-135
			return Vector3(0.0, 0.0, INF)  # WK-135
		return Vector3(_pin_ex_n.x, _pin_ex_n.y, fd)  # WK-135
	var off := pos - _pin_ex_p  # WK-135: unknown shape -> the contact plane, near the contact only
	var dist: float = off.dot(_pin_ex_n)  # WK-135
	if dist < -60.0 or absf(off.dot(tt)) > 200.0:  # WK-135
		return Vector3(0.0, 0.0, INF)  # WK-135
	return Vector3(_pin_ex_n.x, _pin_ex_n.y, dist)  # WK-135

## WK-135: does thrusting along `dir` push into the excluded face (close enough to matter)?
func _wk135_into_excluded(dir: Vector2) -> bool:  # WK-135
	var f := _wk135_ex_frame()  # WK-135
	if f.z > Tuning.bot_pin_avoid_px or dir == Vector2.ZERO:  # WK-135
		return false  # WK-135
	return dir.normalized().dot(Vector2(f.x, f.y)) < Tuning.bot_pin_into_dot  # WK-135

## WK-135 BR-135b/c: while a face is excluded, a boost aim with any component into it (within bot_pin_avoid_px of the face
## segment) slides along it with a little outward lean instead. WALL faces always slide against gravity (over a post, not
## under it into the void); floor/ceiling faces keep the aim's own along-face side (round core: the orbit sense when the
## aim is straight in). Past the face's end the frame reads free, so the bot rounds the corner and resumes its line.
func _pin_avoid(aim: Vector2) -> Vector2:  # WK-135
	if aim == Vector2.ZERO:  # WK-135
		return aim  # WK-135
	var f := _wk135_ex_frame()  # WK-135
	if f.z > Tuning.bot_pin_avoid_px:  # WK-135
		return aim  # WK-135
	var n := Vector2(f.x, f.y)  # WK-135
	var a := aim.normalized()  # WK-135
	if a.dot(n) >= 0.0:  # WK-135
		return aim  # WK-135
	var t := Vector2(-n.y, n.x)  # WK-135
	var s: float = signf(a.dot(t))  # WK-135
	if _pin_ex_wall:  # WK-135
		s = signf(t.dot(-_gdown()))  # WK-135
	elif absf(a.dot(t)) < 0.2:  # WK-135
		s = signf(me.velocity.dot(t)) if _pin_ex_round else signf(t.dot(-_gdown()))  # WK-135
	if s == 0.0:  # WK-135
		s = 1.0  # WK-135
	_pin_avoiding = true  # WK-135
	me.wk135_count("wk135_pin_avoid_frames")  # WK-135
	return (t * s + n * 0.35).normalized() * minf(aim.length(), 1.0)  # WK-135

## WK-135 BR-135a: a radial refuel-dive hit can pay under the C rules: any non-bumper surface, a round core, or a FLOOR-class
## bumper face (n . up > Tuning.bumper_floor_dot at the hit) — and never the face the pin breaker excluded.
func _wk135_refuel_ok(hit: Dictionary) -> bool:  # WK-135
	var col: Object = hit.get("collider")  # WK-135
	if col == null or not col.has_meta("bumper"):  # WK-135
		return true  # WK-135
	var rnd: bool = col.has_meta("round")  # WK-135
	var hn: Vector2 = hit.get("normal", Vector2.UP)  # WK-135
	var n := hn if rnd else (Vector2(signf(hn.x), 0.0) if absf(hn.x) >= absf(hn.y) else Vector2(0.0, signf(hn.y)))  # WK-135
	if _pin_ex_t > 0.0 and _wk135_face_key(col, n) == _pin_ex_key:  # WK-135
		return false  # WK-135
	if rnd:  # WK-135
		return true  # WK-135
	return n.dot(-_gdown(hit.get("position", me.global_position))) > Tuning.bumper_floor_dot  # WK-135

# ---------------------------------------------------------------- WK-161 (BR-135 in radial wells + per-episode dump)

## WK-161: is `p` inside a radial gravity well (any registered GravitySource radius)? Flat arenas have none -> false.
func _wk161_in_well(p: Vector2) -> bool:  # WK-161
	return bool(_wk161_core(p).get("in", false))  # WK-161

## WK-161: gravity wells at `p`: {"in": inside any source radius, "d": px from the nearest round body surface (centre if none)}.
func _wk161_core(p: Vector2) -> Dictionary:  # WK-161
	var srcs: Array = GravityField.get("_sources") if GravityField.get("_sources") != null else []  # WK-161
	var best := INF  # WK-161
	var inside := false  # WK-161
	for src in srcs:  # WK-161
		if not is_instance_valid(src) or not (src is Node2D):  # WK-161
			continue  # WK-161
		var d: float = p.distance_to((src as Node2D).global_position) - float(src.get("body_r"))  # WK-161
		best = minf(best, d)  # WK-161
		if src.has_method("contains") and bool(src.contains(p)):  # WK-161: inside ANY well (two-moon orbit arenas)
			inside = true  # WK-161
	return {"in": inside, "d": best}  # WK-161

## WK-161: class of a contact face for the dump: core (round collider) / floor / wall / ceiling (local gravity) / surface
## (non-bumper tier). Bumper rect faces use Tuning.bumper_floor_dot like Player._wk135_face_class.
func _wk161_face(surface: Object, n: Vector2, at: Vector2) -> String:  # WK-161
	if surface == null or not is_instance_valid(surface):  # WK-161
		return "?"  # WK-161
	if surface.has_meta("round"):  # WK-161
		return "core" if surface.has_meta("bumper") else "round"  # WK-161
	var up: Vector2 = -_gdown(at)  # WK-161
	var d: float = n.dot(up)  # WK-161
	var cls := "floor" if d > Tuning.bumper_floor_dot else ("ceiling" if d < -0.5 else "wall")  # WK-161
	return ("bumper_" + cls) if surface.has_meta("bumper") else cls  # WK-161

## WK-161: every surface contact: remember it (stuck records carry the last one) and run the bot-side pin detector
## (Player's bumper_pin_episodes rule, any thrust) so each pin EPISODE gets one dump record.
func _wk161_contact(surface: Object, n: Vector2, contact: Vector2) -> void:  # WK-161
	if me == null or not is_instance_valid(me):  # WK-161
		return  # WK-161
	var face := _wk161_face(surface, n, contact)  # WK-161
	_wk161_last_t = _mh_clock  # WK-161
	_wk161_last_p = contact  # WK-161
	_wk161_last_n = n  # WK-161
	_wk161_last_face = face  # WK-161
	if surface == null or not is_instance_valid(surface) or not surface.has_meta("bumper"):  # WK-161
		return  # WK-161
	var key := _wk135_face_key(surface, n)  # WK-161
	if key != _wk161_pin_key:  # WK-161
		_wk161_pin_key = key  # WK-161
		_wk161_pin_times.clear()  # WK-161
		_wk161_in_pin = false  # WK-161
	_wk161_pin_times.append(_mh_clock)  # WK-161
	while not _wk161_pin_times.is_empty() and _mh_clock - float(_wk161_pin_times[0]) > Player.PIN_WINDOW:  # WK-161
		_wk161_pin_times.pop_front()  # WK-161
	if _wk161_pin_times.size() >= Player.PIN_CONTACTS:  # WK-161
		if not _wk161_in_pin:  # WK-161
			_wk161_in_pin = true  # WK-161
			_wk161_pin_eps += 1  # WK-161
			_wk161_record("pin", contact, n, face, -1.0)  # WK-161
	else:  # WK-161
		_wk161_in_pin = false  # WK-161

## WK-161: append one episode record (capped). Thrust = the emitted stick + whether the jetpack is lit; aim_n = aim . contact
## normal (< -0.5 = thrusting into it, the BR-135b test); bh = black-hole powerup drag (Player._pulled); well/core_d = the
## radial well; brk = pin-breaker state at that moment. `disp` = stuck window displacement (-1 for pins).
func _wk161_record(kind: String, contact: Vector2, n: Vector2, face: String, disp: float) -> void:  # WK-161
	if _wk161_dump.size() >= Tuning.wk161_dump_max or me == null or not is_instance_valid(me):  # WK-161
		return  # WK-161
	var pos: Vector2 = me.global_position  # WK-161
	var a: Vector2 = _intent.aim  # WK-161
	var core := _wk161_core(pos)  # WK-161
	var down := _gdown(pos)  # WK-161
	var rec := {  # WK-161
		"kind": kind, "t": snappedf(_mh_clock, 0.01),  # WK-161
		"pos": [roundi(pos.x), roundi(pos.y)], "vel": [roundi(me.velocity.x), roundi(me.velocity.y)],  # WK-161
		"aim": [snappedf(a.x, 0.01), snappedf(a.y, 0.01)], "boost": me.is_boosting(), "fuel": snappedf(me.fuel, 0.1),  # WK-161
		"hitstun": me.in_hitstun(), "path": _wk161_path, "refuel_dive": _refuel_dive,  # WK-161
		"bh": float(me.get("_pulled")) > 0.0, "well": bool(core["in"]),  # WK-161
		"core_d": roundi(float(core["d"])) if float(core["d"]) < INF else -1,  # WK-161
		"radial": _radial(down), "down": [snappedf(down.x, 0.01), snappedf(down.y, 0.01)],  # WK-161
		"brk": {"ex": _pin_ex_t > 0.0, "rel": _pin_release_t > 0.0, "avoid": _pin_avoiding,  # WK-161
			"skip_on": Tuning.wk161_radial_pin_skip, "on": wk135_no_pin},  # WK-161
	}  # WK-161
	if _wk161_last_t > -INF:  # WK-161
		rec["contact"] = [roundi(contact.x), roundi(contact.y)]  # WK-161
		rec["n"] = [snappedf(n.x, 0.01), snappedf(n.y, 0.01)]  # WK-161
		rec["face"] = face  # WK-161
		rec["contact_age"] = snappedf(_mh_clock - _wk161_last_t, 0.01)  # WK-161
		rec["aim_n"] = snappedf(a.normalized().dot(n.normalized()), 0.01) if a.length() > 0.1 and n != Vector2.ZERO else 0.0  # WK-161
	if disp >= 0.0:  # WK-161
		rec["disp"] = roundi(disp)  # WK-161
	_wk161_dump.append(rec)  # WK-161

## INV-12 subscriber: a bounce whose (axis-snapped) contact normal points DOWN (n.y > 0) is a hit on a
## platform UNDERSIDE — a head-bang. Read-only telemetry; never touches sim state.
func _on_surface_bounced(_surface, player, normal: Vector2, _contact) -> void:
	if player != me:
		return
	_wk161_contact(_surface, normal, _contact)   # WK-161 per-episode dump feed (telemetry only)
	if wk135_no_pin and is_instance_valid(_surface) and _surface is Node2D and _surface.has_meta("bumper"):   # WK-135 BR-135b
		_wk135_pin_contact(_surface as Node2D, normal, _contact as Vector2)   # WK-135
	# gravity-frame "underside": the normal points ALONG the local pull (flat: normal.y > 0.5, identical)
	var down := _gdown()
	if normal.dot(down) > 0.5:
		_mh_underside += 1
		# self-propelled = I was thrusting UPWARD into it (the dumb-AI head-bang), NOT knocked into it
		if _cached_boost and _cached_aim.dot(down) < -0.10:
			_mh_underside_boosted += 1
		if wk95_brain_enabled and me.is_boosting() and not _radial(down):
			var pos: Vector2 = me.global_position
			var lo: float = _bounds().position.x + 40.0
			var hi: float = _bounds().end.x - 40.0
			var lx := _clear_x_past_ceiling(pos.x, pos.y - 40.0, -1.0, lo)
			var rx := _clear_x_past_ceiling(pos.x, pos.y - 40.0, 1.0, hi)
			var side := 0.0
			if is_nan(lx) and is_nan(rx):
				side = -signf(me.velocity.x) if absf(me.velocity.x) > 1.0 else 1.0
			elif is_nan(lx):
				side = 1.0
			elif is_nan(rx):
				side = -1.0
			else:
				side = -1.0 if absf(lx - pos.x) < absf(rx - pos.x) else 1.0
			_bang_dir = Vector2(side, 0.0)
			_bang_t = 0.45

## Live motion-health snapshot (queryable via gbplay eval and snapshotted into round_stats per stage).
func motion_health() -> Dictionary:
	return {
		"stuck_episodes": _mh_stuck_episodes,
		"stuck_secs": snappedf(_mh_stuck_secs, 0.01),
		"underside_bounces": _mh_underside,
		"underside_boosted": _mh_underside_boosted,
		"blocked_ascent_episodes": _mh_blocked_ascent_episodes,
		"blocked_ascent_secs": snappedf(_mh_blocked_ascent_secs, 0.01),
		"blocked_ascent": _mh_blocked_now,
		"detours": _mh_detours,
		# WK-128 §7.4/§8: fuel-integrity feed (Player.wk128_stats(): presses, bills, refunds by class, blocked
		# refunds, nopay_contacts, dribble_episodes, income/spend, P-a1 counter) + bot time below the refuel floor
		"time_below_refuel_floor": snappedf(_mh_below_floor_s, 0.01),
		"wk128": me.wk128_stats() if me != null and is_instance_valid(me) else {},
		"wk161_pin_episodes": _wk161_pin_eps,   # WK-161: bot-side pin episodes (any thrust; cf. wk128.bumper_pin_episodes)
		"wk161_well_skips": _wk161_well_skips,   # WK-161
		"wk161_dump": _wk161_dump.duplicate(true),   # WK-161: per-episode records (stuck / pin)
	}

## Reset per stage (called from PartyMatch._bounce_go) so numbers are per-stage.
func reset_motion_health() -> void:
	_mh_samples.clear()
	_mh_clock = 0.0
	_mh_in_stuck = false
	_mh_stuck_episodes = 0
	_mh_stuck_secs = 0.0
	_mh_underside = 0
	_mh_underside_boosted = 0
	_mh_asc_active = false
	_mh_asc_t = 0.0
	_mh_blocked_now = false
	_mh_blocked_ascent_episodes = 0
	_mh_blocked_ascent_secs = 0.0
	_mh_detours = 0
	_mh_below_floor_s = 0.0
	_pin_key = ""   # WK-135: a new stage carries no pin run, release or exclusion
	_pin_hits.clear()   # WK-135
	_pin_release_t = 0.0   # WK-135
	_pin_ex_t = 0.0   # WK-135
	_wk161_dump.clear()   # WK-161
	_wk161_pin_key = ""   # WK-161
	_wk161_pin_times.clear()   # WK-161
	_wk161_in_pin = false   # WK-161
	_wk161_pin_eps = 0   # WK-161
	_wk161_well_skips = 0   # WK-161
	_wk161_last_t = -INF   # WK-161
	_wk161_last_face = ""   # WK-161
	if me != null and is_instance_valid(me):
		me.reset_wk128_stats()   # WK-128: per-stage fuel-integrity telemetry
