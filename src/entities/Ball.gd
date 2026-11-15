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
	state.linear_velocity = state.linear_velocity.limit_length(max_speed)
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

## For every overlapping LIVE player not on cooldown, impart force to OURSELF (never to the player).
func _drive_from_overlaps() -> void:
	for b in _sense_area.get_overlapping_bodies():
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
	touched.emit(p, p.is_super_active() or p.in_hitstun())

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
	var mag: float = BALL_TOUCH_IMPULSE + BALL_DRIVE_GAIN * pvel.length()
	if p.is_super_active() or p.in_hitstun():
		mag *= BALL_SMASH_MULT   # the power shot: a fired-super / knocked-flying body
	# StormBall's receive_smash form (impulse / mass), then re-cap.
	var v_before: Vector2 = linear_velocity
	linear_velocity += strike_dir * mag / maxf(mass, 0.01)
	linear_velocity = linear_velocity.limit_length(max_speed)
	# WK-105 (SP-01): announce the strike (audio/juice subscribe) + local hit reaction. Presentation only.
	var is_power: bool = p.is_super_active() or p.in_hitstun()
	var impact: float = (linear_velocity - v_before).length()
	last_striker_team = SportsMode.team_for_skin(str(p.skin))
	_hit_reaction(strike_dir, impact, is_power, p)
	EventBus.ball_struck.emit(self, p, impact, is_power)

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
	linear_velocity += impulse / maxf(mass, 0.01)
	linear_velocity = linear_velocity.limit_length(max_speed)

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
