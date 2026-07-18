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

# --- Glossy Toybox sports-ball sprite (no-code-drawn-assets paydown; same pattern as the hammer/bomb/
# crusher/wrecking-ball wirings). A white glossy ball with a baked-in gold equator seam. Image 669x642;
# the circular body (chocolate outline) spans ~665px across (opaque bbox 665x637, centred on the image
# centre ~334,320). Rendered by the BallGloss child Node2D via draw_texture_rect centred on the origin,
# scaled so the ball DIAMETER == 2*BALL_RADIUS. The ball is a RigidBody2D with rotation UNLOCKED, so the
# child inherits the body's spin and the seam visibly ROLLS (desired) — no per-frame rotate needed. ---
const BALL_TEX: Texture2D = preload("res://assets/objects/ball.png")
const BALL_TEX_DIAM := 665.0         # circular-body diameter in image px (opaque bbox width)

# --- variant config (owner 2026-07-18 item 5, DROPSHOT): per-instance overrides, defaulted to the
# soccer constants above. SportsMode sets these via configure_dropshot() BEFORE add_child (so _ready
# builds shapes at the right size). The DROPSHOT values live in Tuning (owner-directed) — the soccer
# ball keeps reading the mode-owned constants above, byte-for-byte.
var radius: float = BALL_RADIUS
var restitution: float = BALL_RESTITUTION
var gravity_mult: float = 1.0        # fraction of field gravity (DROPSHOT floaty beach ball < 1)
var max_speed: float = BALL_MAX_SPEED
var tint: Color = Color.WHITE       # BallGloss modulate (DROPSHOT = warm beach tint)

var _sense_area: Area2D
var _touch_cd: Dictionary = {}       # player instance_id -> seconds of cooldown remaining

## DROPSHOT beach-ball preset (owner item 5): floatier, bouncier, bigger, slower cap. Call BEFORE
## add_child. All values from Tuning (append-only block, 2026-07-18).
func configure_dropshot() -> void:
	radius = Tuning.dropshot_ball_radius
	restitution = Tuning.dropshot_ball_restitution
	gravity_mult = Tuning.dropshot_ball_gravity_mult
	max_speed = Tuning.dropshot_ball_max_speed
	tint = Color(1.0, 0.88, 0.62)   # sunny beach-ball warm-up (art variant is a follow-up)

func _ready() -> void:
	add_to_group("sports_ball")
	collision_layer = LAYER_BALL
	collision_mask = MASK_SURFACES
	gravity_scale = 0.0                              # gravity comes from the field (INV-1), like StormBall/Player
	mass = BALL_MASS
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY    # a fast ball never tunnels a wall / goal mouth
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
	state.linear_velocity += g * gravity_mult * state.step
	state.linear_velocity = state.linear_velocity.limit_length(max_speed)

func _physics_process(delta: float) -> void:
	# tick down per-player contact cooldowns
	for k in _touch_cd.keys():
		var t: float = float(_touch_cd[k]) - delta
		if t <= 0.0:
			_touch_cd.erase(k)
		else:
			_touch_cd[k] = t

	# for every overlapping LIVE player not on cooldown, impart force to OURSELF (never to the player)
	for b in _sense_area.get_overlapping_bodies():
		if not (b is Player) or b.is_dead():
			continue
		var pid := b.get_instance_id()
		if _touch_cd.has(pid):
			continue
		_drive_from(b)
		_touch_cd[pid] = BALL_TOUCH_CD

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
	linear_velocity += strike_dir * mag / maxf(mass, 0.01)
	linear_velocity = linear_velocity.limit_length(max_speed)

## The ONE mode-owned hazard->ball entry point (v8_sports_courts.md §3.1). A hazard (bomb blast,
## hammer whack, debris drop, crusher eject) calls this to punt the ball; it is the SAME impulse form
## `_drive_from` uses internally (`velocity += impulse / mass`, then re-cap to BALL_MAX_SPEED = 2400),
## which is the FEEL_REFERENCE §4.1 "explosion on props" math verbatim. Keeping ALL ball-force logic
## here behind one method means hazards never reach into ball-physics constants — they just call this.
## The 2400 cap guarantees even a point-blank blast stays chaseable (a hazard can't fling the ball
## into an untrackable blur). NOT a Tuning feel constant — mode-owned, alongside the drive constants.
func receive_hazard_impulse(impulse: Vector2) -> void:
	linear_velocity += impulse / maxf(mass, 0.01)
	linear_velocity = linear_velocity.limit_length(max_speed)

## Glossy team-neutral hero ball: the ball.png sprite drawn centred on the origin. As a child Node2D it
## inherits the RigidBody's transform, so the baked gold seam ROLLS with the ball's physics spin.
## Sized off the parent Ball's INSTANCE radius (soccer 60 / dropshot beach 84).
class BallGloss:
	extends Node2D
	func _draw() -> void:
		var r: float = Ball.BALL_RADIUS
		var host := get_parent()
		if host is Ball:
			r = (host as Ball).radius
		var scale_u := (2.0 * r) / Ball.BALL_TEX_DIAM
		var tw := float(Ball.BALL_TEX.get_width()) * scale_u
		var th := float(Ball.BALL_TEX.get_height()) * scale_u
		# centred on the origin (image centre ~= ball-circle centre); the transform handles the roll.
		draw_texture_rect(Ball.BALL_TEX, Rect2(Vector2(-tw * 0.5, -th * 0.5), Vector2(tw, th)), false)
