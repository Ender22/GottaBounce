class_name Ball
extends RigidBody2D
## SPORTS ball (docs/specs/v5_sports_mode.md §2). A near-clone of StormBall's physics DONOR:
## a RigidBody2D that takes field gravity in _integrate_forces, caps to a max speed, ricochets off
## surfaces via a PhysicsMaterial(bounce), and owns a player-sensing Area2D. The powerup-WEAPON
## behavior is STRIPPED: no lifetime, no pop, no hitstun, no receive_smash-on-players. The ball is
## NOT a weapon — it never calls player.receive_smash. It only ever drives ITSELF from a contacting
## player's velocity (the dribble/strike read). Persistent for the stage; re-created fresh each kickoff
## by SportsMode.on_stage_ready.
##
## ALL ball-force constants are MODE-OWNED and live HERE (not in Tuning.gd) — deliberately separate
## from the fenced player-feel constants (the field-gravity READ is the only Tuning touch, read-only,
## the same read StormBall/Player already do).

# --- mode-owned physics + drive constants (spec §2 — NOT Tuning feel constants) ---
const BALL_RADIUS := 60.0
const BALL_MASS := 0.6
const BALL_RESTITUTION := 0.85
const BALL_FRICTION := 0.1
const BALL_MAX_SPEED := 2400.0
const BALL_TOUCH_IMPULSE := 500.0    # floor: even a gentle nudge visibly moves the ball
const BALL_DRIVE_GAIN := 0.9         # + this * player speed (fly faster -> hit harder)
const BALL_SMASH_MULT := 2.0         # x this on a super-active / hitstun body (the power shot)
const BALL_TOUCH_CD := 0.12          # per-player contact cooldown (one clean strike per touch)

# --- mode-owned HAZARD->ball impulse magnitudes (v8_sports_courts.md §3.1). NOT Tuning feel consts:
# read by the hazards that punt the ball (hammer whack, debris drop) via receive_hazard_impulse. The
# bomb blast reuses Tuning.explosion_impulse_center (FEEL §4.1) directly. All are re-capped to
# BALL_MAX_SPEED (2400) so even a full whack stays chaseable. ---
const BALL_HAMMER_IMPULSE := 1200.0  # rotor whack: 1200/0.6 = ~2000 px/s from rest (power-shot band)
const BALL_DEBRIS_IMPULSE := 900.0   # dropped-weight punt: ~1500 px/s (firm knock, below a hammer whack)

const LAYER_BALL := 1 << 6           # the ball's OWN, otherwise-unused bit (players neither sense nor collide)
const MASK_SURFACES := 1 << 2        # bounces off every platform / bumper wall / floor / ceiling
const MASK_PLAYERS := 1 << 0         # the sensing area detects Player bodies
const MASK_KICKOFF_GATE := 1 << 7    # WK-131: the ball-only kickoff gates (KickoffGate.LAYER_GATE); players never mask it

# --- Glossy Toybox sports-ball sprite (no-code-drawn-assets paydown; same pattern as the hammer/bomb/
# crusher/wrecking-ball wirings). A white glossy ball with a baked-in gold equator seam. Image 669x642;
# the circular body (chocolate outline) spans ~665px across (opaque bbox 665x637, centred on the image
# centre ~334,320). Rendered by the BallGloss child Node2D via draw_texture_rect centred on the origin,
# scaled so the ball DIAMETER == 2*BALL_RADIUS. The ball is a RigidBody2D with rotation UNLOCKED, so the
# child inherits the body's spin and the seam visibly ROLLS (desired) — no per-frame rotate needed. ---
const BALL_TEX: Texture2D = preload("res://assets/objects/ball.png")
const BALL_TEX_DIAM := 665.0         # circular-body diameter in image px (opaque bbox width)
# DROPSHOT bespoke sprite (owner item 5 follow-up): a classic red/white/blue/yellow beach ball,
# replacing the warm-tinted soccer ball. Image 709x689; circular body spans ~705px (opaque bbox).
const BEACH_TEX: Texture2D = preload("res://assets/objects/ball_beach.png")
const BEACH_TEX_DIAM := 705.0        # circular-body diameter in image px (opaque bbox width)

# --- variant config (owner 2026-07-18 item 5, DROPSHOT): per-instance overrides, defaulted to the
# soccer constants above. SportsMode sets these via configure_dropshot() BEFORE add_child (so _ready
# builds shapes at the right size). The DROPSHOT values live in Tuning (owner-directed) — the soccer
# ball keeps reading the mode-owned constants above, byte-for-byte.
var radius: float = BALL_RADIUS
var restitution: float = BALL_RESTITUTION
var gravity_mult: float = 1.0        # fraction of field gravity (DROPSHOT floaty beach ball < 1)
var max_speed: float = BALL_MAX_SPEED
var tint: Color = Color.WHITE       # BallGloss modulate (soccer = white; DROPSHOT uses the bespoke sprite untinted)
var use_beach_tex: bool = false     # DROPSHOT draws BEACH_TEX (bespoke beach ball) instead of BALL_TEX

# --- WK-104 (SP-02/SP-05) kickoff gate + touch credit. `live` defaults TRUE so TRIALS puzzle balls are
# untouched; SportsMode spawns its ball GHOSTED (live = false + frozen) through STAGE_INTRO/COUNTDOWN and
# calls go_live() on GO. A ghosted ball ignores every player overlap (the overlap list on a stage-reload
# frame still holds players at their previous-point positions) and every hazard punt. ---
signal touched(player, is_power)     # one per ACCEPTED live touch (credit feed; SportsMode listens)
const TOUCH_LOG_MAX := 12            # recent touches kept for scorer / assist credit
var live: bool = true
var _clock: float = 0.0              # ball-local physics clock (s) — touch-log timestamps
var _touch_log: Array = []           # [{ "p", "t", "vin", "vout", "pos" }] oldest -> newest, live touches only
var _hang_t: float = -1.0            # >= 0: kickoff hang active for this many more seconds (gravity scaled)
var _hang_mult: float = 1.0          # gravity fraction while hanging (Tuning.sports_kickoff_hang_gravity)

var _sense_area: Area2D
var _touch_cd: Dictionary = {}       # player instance_id -> seconds of cooldown remaining

# --- WK-105 (SP-01) strike juice: presentation-only state (never feeds back into physics) ---
const HIT_FX_TIME := 0.14            # squash + flash decay (s) — ~8 frames at 60 fps so a strike frame reads
const HIT_FX_SPEED_LO := 800.0       # |delta-v| (px/s) mapped to 0 (a nudge) ...
const HIT_FX_SPEED_HI := 3800.0      # ... and to 1 (a fast ball sent straight back; = AudioManager's map)
var last_striker_team: int = -1      # team (SportsMode.team_for_skin) of the latest striker; -1 unknown
var _gloss: Node2D
var _hit_fx: float = 0.0             # 1 -> 0 over HIT_FX_TIME after a strike
var _hit_amt: float = 0.0            # 0..1 strike strength (scales squash/flash)
var _hit_dir: Vector2 = Vector2.RIGHT  # WORLD strike direction (squash axis)
# WK-66a net ripple feed (presentation only): contact REPORTING (contact_monitor) never changes the solve.
var _wk66a_prev_speed: float = 0.0     # WK-66a
var _wk66a_touching: Array = []        # WK-66a colliders with meta "net_fx" in contact last step

# --- WK-109 power shot dynamic range (docs/specs/wk109_power_shot_2026-11-15.md). Runs ONLY on a ball whose wk109_on was set  # WK-109
# by SportsMode at spawn (the soccer ball, when Tuning.wk109_power_shot); Trials puzzle balls and the Dropshot beach ball keep  # WK-109
# the legacy path byte-for-byte. Tiers: SOFT / DRIVE = one formula (softer floor + a tanh knee under the normal cap); POWER =  # WK-109
# a super-active striker at >= smash_impact_min not in hitstun -> exit exactly wk109_power_speed and a short raised-cap window.  # WK-109
const WK109_POP_SCENE_PATH := "res://scenes/entities/PowerShotPop.tscn"  # WK-109
const WK109_SOFT_MAX := 1200.0         # px/s QA tier label only (exit < this = "soft"); not a feel constant  # WK-109
var wk109_on: bool = false             # set by SportsMode._spawn_ball BEFORE add_child (soccer + Tuning.wk109_power_shot)  # WK-109
var qa_trail_on: bool = false          # QA (spec M4): the streak's logical state this tick (window active AND speed > trail_min)  # WK-109
var wk109_last_tier: String = ""       # QA: "soft" / "drive" / "power" of the latest accepted touch (ON only)  # WK-109
var wk109_power_n: int = 0             # QA: POWER touches on this ball  # WK-109
var wk109_blunt_n: int = 0             # QA: power windows ended by a non-power touch  # WK-109
var wk109_pops: int = 0                # QA: POWER SHOT! pops this ball spawned  # WK-109
var _wk109_pw_t: float = -1.0          # s since the POWER touch (-1 = no power window)  # WK-109
var _wk109_last_power: bool = false    # the latest _drive_from's tier was POWER (feeds Ball.touched)  # WK-109
var _wk109_trail: Node2D = null        # top-level streak node (two Line2Ds), created on the first power shot  # WK-109
var _wk109_trail_a: float = 0.0        # streak alpha (1 while on, fades over wk109_trail_fade_s, 0 on a blunt)  # WK-109
var _wk109_hist: Array = []            # recent ball positions, newest last (streak path; follows bank shots)  # WK-109
static var _wk109_pop_tick: int = -1000000   # Engine physics frame of the last pop (match-wide cooldown, game time)  # WK-109
static var _wk109_pop_ref: WeakRef = null    # the pop on screen (at most one)  # WK-109

## DROPSHOT beach-ball preset (owner item 5): floatier, bouncier, bigger, slower cap. Call BEFORE
## add_child. All values from Tuning (append-only block, 2026-07-18).
func configure_dropshot() -> void:
	radius = Tuning.dropshot_ball_radius
	restitution = Tuning.dropshot_ball_restitution
	gravity_mult = Tuning.dropshot_ball_gravity_mult
	max_speed = Tuning.dropshot_ball_max_speed
	tint = Color.WHITE              # the bespoke beach-ball sprite carries its own colours (no warm-up needed)
	use_beach_tex = true

func _ready() -> void:
	add_to_group("sports_ball")
	collision_layer = LAYER_BALL
	collision_mask = MASK_SURFACES | MASK_KICKOFF_GATE   # WK-131 (no body sits on the gate bit unless a gate exists)
	gravity_scale = 0.0                              # gravity comes from the field (INV-1), like StormBall/Player
	mass = BALL_MASS
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY    # a fast ball never tunnels a wall / goal mouth
	contact_monitor = true          # WK-66a: report contacts so a net / goal frame can ripple (no physics change)
	max_contacts_reported = 4       # WK-66a
	z_index = 40
	var pm := PhysicsMaterial.new()
	pm.bounce = restitution
	pm.friction = BALL_FRICTION
	physics_material_override = pm

	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)

	var gloss := BallGloss.new()
	gloss.modulate = tint
	add_child(gloss)
	_gloss = gloss

	# player-sensing Area2D (mask players only): drives the ball from bodies it overlaps.
	_sense_area = Area2D.new()
	_sense_area.collision_layer = 0
	_sense_area.collision_mask = MASK_PLAYERS
	var hcs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = radius + 8.0
	hcs.shape = hc
	_sense_area.add_child(hcs)
	add_child(_sense_area)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# field gravity (READ-ONLY Tuning.gravity, exactly StormBall's read) + a hard max-speed cap so even a
	# power shot stays chaseable (below the player max_speed of 3000). gravity_mult = the DROPSHOT float.
	var g := GravityField.get_gravity_at(global_position)
	var gm: float = gravity_mult * (_hang_mult if _hang_t >= 0.0 else 1.0)   # WK-104 kickoff hang
	state.linear_velocity += g * gm * state.step
	state.linear_velocity = state.linear_velocity.limit_length(_wk109_cap())   # WK-109 (= max_speed unless a power window runs)
	_wk66a_net_contacts(state)   # WK-66a

## WK-66a: a NEW contact with a net-tagged collider (Dropshot net, goal back post / wall caps) tells its
## SportsNetArt where and how hard it was hit (speed = the faster of last step / now, i.e. pre-bounce).
## Read-only on the physics state; the art call is deferred out of the physics callback.
func _wk66a_net_contacts(state: PhysicsDirectBodyState2D) -> void:   # WK-66a
	var now: Array = []
	for i in range(state.get_contact_count()):
		var c: Object = state.get_contact_collider_object(i)
		if c == null or not c.has_meta("net_fx") or now.has(c):
			continue
		now.append(c)
		if not _wk66a_touching.has(c):
			var fx: Object = c.get_meta("net_fx")
			if is_instance_valid(fx):
				var spd: float = maxf(_wk66a_prev_speed, state.linear_velocity.length())
				fx.call_deferred("on_ball_contact", state.get_contact_collider_position(i), spd)
	_wk66a_touching = now
	_wk66a_prev_speed = state.linear_velocity.length()

func _physics_process(delta: float) -> void:
	# tick down per-player contact cooldowns
	for k in _touch_cd.keys():
		var t: float = float(_touch_cd[k]) - delta
		if t <= 0.0:
			_touch_cd.erase(k)
		else:
			_touch_cd[k] = t

	# WK-104 (SP-02): a ghosted ball (pre-GO) never reads overlaps — no stale reload-frame touches.
	if live:
		_clock += delta
		if _hang_t >= 0.0:
			_hang_t -= delta
			if _hang_t < 0.0:
				_hang_t = -1.0   # hang expired untouched -> normal gravity
		_drive_from_overlaps()
		if wk109_on:  # WK-109
			_wk109_tick(delta)  # WK-109

## For every overlapping LIVE player not on cooldown, impart force to OURSELF (never to the player).
func _drive_from_overlaps() -> void:
	var bodies: Array = _sense_area.get_overlapping_bodies()  # WK-109 (was iterated inline)
	if wk109_on:  # WK-109 edge case 1: POWER touches go LAST, so a same-tick normal touch never blunts the shot being struck
		var normal: Array = []  # WK-109
		var power: Array = []  # WK-109
		for b in bodies:  # WK-109
			if b is Player and not b.is_dead() and _wk109_is_power(b):  # WK-109
				power.append(b)  # WK-109
			else:  # WK-109
				normal.append(b)  # WK-109
		bodies = normal + power  # WK-109
	for b: Node2D in bodies:  # WK-109 (typed: the list is now an untyped Array)
		if not (b is Player) or b.is_dead():
			continue
		var pid := b.get_instance_id()
		if _touch_cd.has(pid):
			continue
		var vin: Vector2 = linear_velocity
		_drive_from(b)
		_touch_cd[pid] = BALL_TOUCH_CD
		_log_touch(b, vin)

## WK-104: record an accepted live touch (scorer/assist credit) and end any kickoff hang.
func _log_touch(p: Player, vin: Vector2) -> void:
	_hang_t = -1.0
	# vin/vout = ball velocity before/after the touch: SportsMode reads them to tell a DEFLECTION (direction
	# barely changed -> the shooter keeps the credit) from a defender genuinely redirecting it (WK-106).
	_touch_log.append({"p": p, "t": _clock, "vin": vin, "vout": linear_velocity, "pos": global_position})
	if _touch_log.size() > TOUCH_LOG_MAX:
		_touch_log.pop_front()
	touched.emit(p, _wk109_last_power if wk109_on else (p.is_super_active() or p.in_hitstun()))  # WK-109 (ON: POWER only)

## WK-104: recent live touches, oldest -> newest ([{ "p": Player, "t": float, "vin"/"vout"/"pos": Vector2 }]).
func touch_log() -> Array:
	return _touch_log

func ball_clock() -> float:
	return _clock

## WK-104 (SP-02/SP-05): GO. Unfreeze, accept touches, and start the kickoff: `vel` is the release velocity
## (the ref-drop toss), and gravity runs at `hang_gravity` x normal until the first touch or `hang_s` elapses.
func go_live(vel: Vector2, hang_gravity: float, hang_s: float) -> void:
	live = true
	freeze = false
	linear_velocity = vel
	_hang_mult = hang_gravity
	_hang_t = hang_s if hang_s > 0.0 else -1.0

## Drive the ball from a contacting player's velocity (spec §2). Direction = away-from-body blended
## toward the player's travel line (the carry/dribble read); magnitude = touch floor + speed gain,
## doubled on a super-active or knocked-flying (hitstun) body (the power shot). NEVER touches the player.
func _drive_from(p: Player) -> void:
	var away: Vector2 = (global_position - p.global_position)
	if away.length() < 0.001:
		away = Vector2.UP
	away = away.normalized()
	var pvel: Vector2 = p.velocity
	var pdir: Vector2 = pvel.normalized() if pvel.length() > 1.0 else away
	var strike_dir: Vector2 = (0.5 * away + 0.5 * pdir).normalized()
	if strike_dir.length() < 0.001:
		strike_dir = away
	var touch_imp: float = Tuning.wk109_touch_impulse if wk109_on else BALL_TOUCH_IMPULSE  # WK-109 (ON: softer floor)
	var mag: float = touch_imp + BALL_DRIVE_GAIN * pvel.length()  # WK-109
	if p.is_super_active() or p.in_hitstun():
		mag *= BALL_SMASH_MULT   # the power shot: a fired-super / knocked-flying body
	# StormBall's receive_smash form (impulse / mass), then re-cap.
	var v_before: Vector2 = linear_velocity
	linear_velocity += strike_dir * mag / maxf(mass, 0.01)
	var is_power: bool  # WK-109
	if wk109_on:  # WK-109: POWER = constant exit + window; anything else = knee + normal cap (and blunts a window)
		is_power = _wk109_is_power(p)  # WK-109
		linear_velocity = _wk109_exit(linear_velocity, is_power)  # WK-109
		_wk109_last_power = is_power  # WK-109
	else:  # WK-109
		linear_velocity = linear_velocity.limit_length(max_speed)
		is_power = p.is_super_active() or p.in_hitstun()  # WK-109 (declared above)
	# WK-105 (SP-01): announce the strike (audio/juice subscribe) + local hit reaction. Presentation only.
	var impact: float = (linear_velocity - v_before).length()
	last_striker_team = SportsMode.team_for_skin(str(p.skin))
	_hit_reaction(strike_dir, impact, is_power, p)
	EventBus.ball_struck.emit(self, p, impact, is_power)
	if wk109_on and is_power:  # WK-109
		_wk109_pop(global_position)  # WK-109

## WK-105 (SP-01) hit reaction, proportional to the strike: a squash along the strike axis + a white
## flash on the ball (BallGloss), and a small additive spark puff at the contact point in the striker's
## team colour (gold-white and bigger on a power shot). Pure presentation; never touches physics.
func _hit_reaction(dir: Vector2, impact: float, is_power: bool, p: Player) -> void:
	var t: float = clampf(inverse_lerp(HIT_FX_SPEED_LO, HIT_FX_SPEED_HI, impact), 0.0, 1.0)
	if is_power:
		t = maxf(t, 0.85)
	_hit_amt = maxf(t, _hit_amt * _hit_fx)   # a strike never visibly weakens a still-decaying bigger one
	_hit_fx = 1.0
	_hit_dir = dir
	var host := get_parent()
	if host == null:
		return
	var team: int = last_striker_team
	var col: Color = Color(1.0, 0.95, 0.8)
	if team >= 0 and team < SportsMode.TEAM_COLORS.size():
		col = SportsMode.TEAM_COLORS[team]
	var sp := CPUParticles2D.new()
	sp.global_position = global_position - dir * radius * 0.85
	sp.emitting = true
	sp.one_shot = true
	sp.explosiveness = 1.0
	sp.amount = 26 if is_power else int(lerpf(5.0, 16.0, t))
	sp.lifetime = 0.42 if is_power else 0.3
	sp.direction = -dir                      # sparks spray back off the struck face
	sp.spread = 70.0
	sp.gravity = Vector2.ZERO
	sp.initial_velocity_min = lerpf(180.0, 420.0, t)
	sp.initial_velocity_max = lerpf(380.0, 900.0, t) * (1.3 if is_power else 1.0)
	sp.damping_min = 400.0
	sp.damping_max = 900.0
	sp.scale_amount_min = 8.0 if is_power else 5.0     # world px at the ~0.4 whole-court zoom (WK-121: x2,
	sp.scale_amount_max = 20.0 if is_power else lerpf(9.0, 15.0, t)   # the WK-105 sizes were 1-3 screen px)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.95, 1.0))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	if is_power:
		grad.add_point(0.35, Color(1.0, 0.85, 0.3, 1.0))
	sp.color_ramp = grad
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sp.material = m
	sp.z_index = 41
	host.add_child(sp)
	host.get_tree().create_timer(0.7).timeout.connect(sp.queue_free)

func _process(delta: float) -> void:
	if _hit_fx > 0.0:
		_hit_fx = maxf(0.0, _hit_fx - delta / HIT_FX_TIME)
		if _gloss != null:
			_gloss.queue_redraw()
	if wk109_on:  # WK-109
		_wk109_trail_update(delta)  # WK-109

## The ONE mode-owned hazard->ball entry point (v8_sports_courts.md §3.1). A hazard (bomb blast,
## hammer whack, debris drop, crusher eject) calls this to punt the ball; it is the SAME impulse form
## `_drive_from` uses internally (`velocity += impulse / mass`, then re-cap to BALL_MAX_SPEED = 2400),
## which is the FEEL_REFERENCE §4.1 "explosion on props" math verbatim. Keeping ALL ball-force logic
## here behind one method means hazards never reach into ball-physics constants — they just call this.
## The 2400 cap guarantees even a point-blank blast stays chaseable (a hazard can't fling the ball
## into an untrackable blur). NOT a Tuning feel constant — mode-owned, alongside the drive constants.
func receive_hazard_impulse(impulse: Vector2) -> void:
	if not live:
		return   # WK-104: a ghosted kickoff ball can't be punted before GO
	_hang_t = -1.0   # a hazard punt ends the kickoff hang like a touch does
	if wk109_on and _wk109_pw_t >= 0.0:  # WK-109 edge case 6: back to the normal cap BEFORE the punt (a hammer never flings to 2800)
		_wk109_end_window(true)  # WK-109
	linear_velocity += impulse / maxf(mass, 0.01)
	linear_velocity = linear_velocity.limit_length(max_speed)

# ------------------------------------------------------------------ WK-109 power shot (ON only)  # WK-109

## WK-109 spec §2.3: the POWER condition = the same eligibility a super needs to smash in Brawl (INV-1): super active,  # WK-109
## flying at >= smash_impact_min, and NOT a hitstun victim (a tumbling goat keeps x2 but goes through the knee + cap).  # WK-109
func _wk109_is_power(p: Player) -> bool:  # WK-109
	return p.is_super_active() and not p.in_hitstun() and p.velocity.length() >= Tuning.smash_impact_min  # WK-109

## WK-109 §2.2/§2.3: the exit velocity for v = v_in + dv. POWER -> the same direction at exactly wk109_power_speed and a  # WK-109
## fresh power window. Otherwise a non-power touch: blunts any running window, then the tanh soft knee (monotonic, identity  # WK-109
## below the knee, direction unchanged) and the normal cap.  # WK-109
func _wk109_exit(v: Vector2, power: bool) -> Vector2:  # WK-109
	var raw: float = v.length()  # WK-109
	if power:  # WK-109
		_wk109_pw_t = 0.0  # WK-109
		wk109_power_n += 1  # WK-109
		wk109_last_tier = "power"  # WK-109
		var dir: Vector2 = v / raw if raw > 0.001 else Vector2.RIGHT  # WK-109 (dv from a super striker is > 4000: never ~0)
		return dir * Tuning.wk109_power_speed  # WK-109
	if _wk109_pw_t >= 0.0:  # WK-109: any non-power player touch blunts the shot (the streak dies on this frame)
		_wk109_end_window(true)  # WK-109
		wk109_blunt_n += 1  # WK-109
	var cap: float = max_speed  # WK-109
	var knee: float = Tuning.wk109_touch_knee  # WK-109
	var out: float = raw  # WK-109
	if knee > 0.0 and knee < cap and raw > knee:  # WK-109
		out = knee + (cap - knee) * tanh((raw - knee) / (cap - knee))  # WK-109
	out = minf(out, cap)  # WK-109
	wk109_last_tier = "soft" if out < WK109_SOFT_MAX else "drive"  # WK-109
	if raw <= 0.001:  # WK-109
		return v  # WK-109
	return v * (out / raw)  # WK-109

## WK-109: the speed cap right now. max_speed (today's cap) unless a power window runs: wk109_power_speed for the hold,  # WK-109
## then a smoothstep ease back to max_speed over the decay (a gentle slow-down, never a snap).  # WK-109
func _wk109_cap() -> float:  # WK-109
	if not wk109_on or _wk109_pw_t < 0.0:  # WK-109
		return max_speed  # WK-109
	var top: float = maxf(max_speed, Tuning.wk109_power_speed)  # WK-109
	var hold: float = Tuning.wk109_power_hold_s  # WK-109
	if _wk109_pw_t <= hold:  # WK-109
		return top  # WK-109
	var k: float = (_wk109_pw_t - hold) / maxf(Tuning.wk109_power_decay_s, 0.001)  # WK-109
	if k >= 1.0:  # WK-109
		return max_speed  # WK-109
	return lerpf(top, max_speed, smoothstep(0.0, 1.0, k))  # WK-109

## WK-109: advance the power window (ball physics clock) and the streak's logical state. The window survives surface  # WK-109
## bounces; it ends after hold + decay, on a non-power touch / hazard punt (see callers), and at STAGE_END.  # WK-109
func _wk109_tick(delta: float) -> void:  # WK-109
	if _wk109_pw_t >= 0.0:  # WK-109
		_wk109_pw_t += delta  # WK-109
		var st: String = _wk109_scene_state()  # WK-109
		if st == "STAGE_END" or st == "MATCH_END" or st == "SCOREBOARD":  # WK-109
			_wk109_end_window(true)  # WK-109
		elif _wk109_pw_t >= Tuning.wk109_power_hold_s + Tuning.wk109_power_decay_s:  # WK-109
			_wk109_end_window(false)  # WK-109 (natural end: the streak, if still on, fades)
	qa_trail_on = _wk109_pw_t >= 0.0 and linear_velocity.length() > Tuning.wk109_trail_min_speed  # WK-109

func _wk109_scene_state() -> String:  # WK-109
	if not is_inside_tree():  # WK-109
		return ""  # WK-109
	var sc: Node = get_tree().current_scene  # WK-109
	if sc == null:  # WK-109
		return ""  # WK-109
	var st: Variant = sc.get("state")  # WK-109
	return str(st) if st != null else ""  # WK-109

## WK-109: close the power window. kill_trail = a blunt (touch / hazard / stage end): the streak vanishes on this frame.  # WK-109
func _wk109_end_window(kill_trail: bool) -> void:  # WK-109
	_wk109_pw_t = -1.0  # WK-109
	qa_trail_on = false  # WK-109
	if kill_trail:  # WK-109
		_wk109_trail_a = 0.0  # WK-109
		_wk109_hist.clear()  # WK-109
		if is_instance_valid(_wk109_trail):  # WK-109
			_wk109_trail.visible = false  # WK-109

## WK-109 §3.1 streak: a tapered ribbon behind the ball along its recent path (so a banked shot bends with it). Length =  # WK-109
## speed x wk109_trail_len_s, width 0.9 x the ball diameter -> 0, white core, the striker's team colour at the edge  # WK-109
## (DECISIONS WK-24). Drawn at absolute z -1: over the court backdrop, UNDER the goats (z 0) and the ball (z 40).  # WK-109
func _wk109_trail_update(delta: float) -> void:  # WK-109
	if qa_trail_on:  # WK-109
		_wk109_trail_a = 1.0  # WK-109
	elif _wk109_trail_a > 0.0:  # WK-109
		_wk109_trail_a = maxf(0.0, _wk109_trail_a - delta / maxf(Tuning.wk109_trail_fade_s, 0.001))  # WK-109
	if _wk109_trail_a <= 0.0:  # WK-109
		_wk109_hist.clear()  # WK-109
		if is_instance_valid(_wk109_trail):  # WK-109
			_wk109_trail.visible = false  # WK-109
		return  # WK-109
	if not is_instance_valid(_wk109_trail):  # WK-109
		_wk109_trail = _wk109_make_trail()  # WK-109
	var head: Vector2 = global_position  # WK-109
	if _wk109_hist.is_empty() or (_wk109_hist.back() as Vector2).distance_to(head) > 1.0:  # WK-109
		_wk109_hist.append(head)  # WK-109
	var spd: float = maxf(linear_velocity.length(), Tuning.wk109_trail_min_speed)  # WK-109
	var want: float = spd * Tuning.wk109_trail_len_s  # WK-109
	# walk back from the ball along the recorded path until the streak is `want` long  # WK-109
	var pts: PackedVector2Array = PackedVector2Array([head])  # WK-109
	var got: float = 0.0  # WK-109
	var i: int = _wk109_hist.size() - 2  # WK-109
	while i >= 0 and got < want:  # WK-109
		var a: Vector2 = pts[pts.size() - 1]  # WK-109
		var b: Vector2 = _wk109_hist[i]  # WK-109
		var seg: float = a.distance_to(b)  # WK-109
		if got + seg >= want:  # WK-109
			pts.append(a.lerp(b, (want - got) / maxf(seg, 0.001)))  # WK-109
			got = want  # WK-109
		else:  # WK-109
			pts.append(b)  # WK-109
			got += seg  # WK-109
		i -= 1  # WK-109
	if i >= 0:  # WK-109
		_wk109_hist = _wk109_hist.slice(i)  # WK-109 keep one point past the tail
	if got < want:  # WK-109: a fresh shot has no history yet -> extend straight back along the travel line
		var back: Vector2 = -linear_velocity.normalized() if linear_velocity.length() > 1.0 else Vector2.LEFT  # WK-109
		pts.append(pts[pts.size() - 1] + back * (want - got))  # WK-109
	var col: Color = Color(1.0, 0.95, 0.8)  # WK-109
	if last_striker_team >= 0 and last_striker_team < SportsMode.TEAM_COLORS.size():  # WK-109
		col = SportsMode.TEAM_COLORS[last_striker_team]  # WK-109
	var edge: Line2D = _wk109_trail.get_node("Edge")  # WK-109
	var core: Line2D = _wk109_trail.get_node("Core")  # WK-109
	var w: float = 0.9 * 2.0 * radius  # WK-109
	edge.width = w  # WK-109
	core.width = w * 0.6  # WK-109
	edge.points = pts  # WK-109
	core.points = pts  # WK-109
	edge.gradient.colors = PackedColorArray([Color(col.r, col.g, col.b, 1.0), Color(col.r, col.g, col.b, 0.85),  # WK-109: solid team-colour
		Color(col.r, col.g, col.b, 0.0)])  # WK-109 edge, fading out over the last third (offsets 0 / 0.65 / 1 set at creation)
	_wk109_trail.modulate = Color(1, 1, 1, _wk109_trail_a)  # WK-109
	_wk109_trail.visible = true  # WK-109

func _wk109_make_trail() -> Node2D:  # WK-109
	var n := Node2D.new()  # WK-109
	n.name = "WK109Trail"  # WK-109
	n.top_level = true  # WK-109: points are world coordinates
	n.z_as_relative = false  # WK-109
	n.z_index = -1  # WK-109: under the goats (0), over the court backdrop
	for nm in ["Edge", "Core"]:  # WK-109
		var ln := Line2D.new()  # WK-109
		ln.name = nm  # WK-109
		ln.joint_mode = Line2D.LINE_JOINT_ROUND  # WK-109
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND  # WK-109
		ln.antialiased = true  # WK-109
		var wc := Curve.new()  # WK-109: 1 at the ball -> 0 at the tail, held full for longer (a linear taper read as a thin cone)
		wc.add_point(Vector2(0.0, 1.0))  # WK-109
		wc.add_point(Vector2(0.6, 0.72))  # WK-109
		wc.add_point(Vector2(1.0, 0.0))  # WK-109
		ln.width_curve = wc  # WK-109
		var g := Gradient.new()  # WK-109: 3 stops (head, body, tail); Edge's team colour is written per frame
		if nm == "Edge":  # WK-109
			g.offsets = PackedFloat32Array([0.0, 0.65, 1.0])  # WK-109
			g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)])  # WK-109
		else:  # WK-109: solid white core to 55 %, gone by 85 % (the tail reads team colour)
			g.offsets = PackedFloat32Array([0.0, 0.55, 0.85])  # WK-109
			g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.0)])  # WK-109
		ln.gradient = g  # WK-109
		n.add_child(ln)  # WK-109
	add_child(n)  # WK-109 (freed with the ball)
	return n  # WK-109

## WK-109 §3.2 "POWER SHOT!" pop at the strike point: one on screen at most, a match-wide cooldown in physics frames (game  # WK-109
## time), never outside live play. World-following CanvasLayer (the OPEN! call's layer) so a striker's name tag can't cover it.  # WK-109
func _wk109_pop(at: Vector2) -> void:  # WK-109
	var st: String = _wk109_scene_state()  # WK-109
	if st != "COMBAT" and st != "SUDDEN_DEATH" and st != "":  # WK-109
		return  # WK-109
	var now: int = Engine.get_physics_frames()  # WK-109
	if now - _wk109_pop_tick < int(Tuning.wk109_pop_cooldown_s * float(Engine.physics_ticks_per_second)):  # WK-109
		return  # WK-109
	var host: Node = get_parent()  # WK-109
	if host == null:  # WK-109
		return  # WK-109
	var ps: PackedScene = load(WK109_POP_SCENE_PATH) as PackedScene  # WK-109
	if ps == null:  # WK-109
		return  # WK-109
	if _wk109_pop_ref != null:  # WK-109: at most one on screen
		var old: Object = _wk109_pop_ref.get_ref()  # WK-109
		if old != null and is_instance_valid(old):  # WK-109
			(old as Node).queue_free()  # WK-109
	_wk109_pop_tick = now  # WK-109
	var layer := CanvasLayer.new()  # WK-109
	layer.name = "PowerShotPopLayer"  # WK-109
	layer.layer = Tuning.sports_gate_open_call_layer  # WK-109: over the name tags, under the HUD / goal banner
	layer.follow_viewport_enabled = true  # WK-109
	host.add_child(layer)  # WK-109
	var pop: Node2D = ps.instantiate() as Node2D  # WK-109
	layer.add_child(pop)  # WK-109
	pop.tree_exited.connect(layer.queue_free)  # WK-109
	var col: Color = Color(1.0, 0.95, 0.8)  # WK-109
	if last_striker_team >= 0 and last_striker_team < SportsMode.TEAM_COLORS.size():  # WK-109
		col = SportsMode.TEAM_COLORS[last_striker_team]  # WK-109
	pop.call("present", at + Vector2(0.0, -90.0), col, Tuning.wk109_pop_cap_wpx)  # WK-109
	_wk109_pop_ref = weakref(pop)  # WK-109
	wk109_pops += 1  # WK-109

## Glossy team-neutral hero ball: the ball.png sprite drawn centred on the origin. As a child Node2D it
## inherits the RigidBody's transform, so the baked gold seam ROLLS with the ball's physics spin.
## Sized off the parent Ball's INSTANCE radius (soccer 60 / dropshot beach 84).
class BallGloss:
	extends Node2D
	func _draw() -> void:
		var r: float = Ball.BALL_RADIUS
		var beach := false
		var host := get_parent()
		if host is Ball:
			r = (host as Ball).radius
			beach = (host as Ball).use_beach_tex
		var tex: Texture2D = Ball.BEACH_TEX if beach else Ball.BALL_TEX
		var diam: float = Ball.BEACH_TEX_DIAM if beach else Ball.BALL_TEX_DIAM
		var scale_u := (2.0 * r) / diam
		var tw := float(tex.get_width()) * scale_u
		var th := float(tex.get_height()) * scale_u
		# WK-105 strike squash: compress along the WORLD strike axis (converted to this rolling node's
		# local frame), stretch across it; eased out over HIT_FX_TIME. Identity when idle.
		var fx: float = 0.0
		var amt: float = 0.0
		if host is Ball:
			fx = (host as Ball)._hit_fx
			amt = (host as Ball)._hit_amt
		if fx > 0.0:
			var k: float = fx * fx * (0.10 + 0.22 * amt)
			var a: float = (host as Ball)._hit_dir.angle() - (host as Ball).global_rotation
			var rot := Transform2D(a, Vector2.ZERO)
			var sq := Transform2D(0.0, Vector2(1.0 - k, 1.0 + k * 0.6), 0.0, Vector2.ZERO)
			draw_set_transform_matrix(rot * sq * rot.affine_inverse())
		# centred on the origin (image centre ~= ball-circle centre); the transform handles the roll.
		draw_texture_rect(tex, Rect2(Vector2(-tw * 0.5, -th * 0.5), Vector2(tw, th)), false)
		if fx > 0.0:
			# white impact flash over the ball body, brighter on harder strikes
			draw_circle(Vector2.ZERO, r * 0.98, Color(1.0, 1.0, 1.0, fx * (0.25 + 0.45 * amt)))
			draw_set_transform_matrix(Transform2D.IDENTITY)
