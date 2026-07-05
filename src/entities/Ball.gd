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

const LAYER_BALL := 1 << 6           # the ball's OWN, otherwise-unused bit (players neither sense nor collide)
const MASK_SURFACES := 1 << 2        # bounces off every platform / bumper wall / floor / ceiling
const MASK_PLAYERS := 1 << 0         # the sensing area detects Player bodies

var _sense_area: Area2D
var _touch_cd: Dictionary = {}       # player instance_id -> seconds of cooldown remaining

func _ready() -> void:
	add_to_group("sports_ball")
	collision_layer = LAYER_BALL
	collision_mask = MASK_SURFACES
	gravity_scale = 0.0                              # gravity comes from the field (INV-1), like StormBall/Player
	mass = BALL_MASS
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY    # a fast ball never tunnels a wall / goal mouth
	z_index = 40
	var pm := PhysicsMaterial.new()
	pm.bounce = BALL_RESTITUTION
	pm.friction = BALL_FRICTION
	physics_material_override = pm

	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = BALL_RADIUS
	cs.shape = c
	add_child(cs)

	add_child(BallGloss.new())

	# player-sensing Area2D (mask players only): drives the ball from bodies it overlaps.
	_sense_area = Area2D.new()
	_sense_area.collision_layer = 0
	_sense_area.collision_mask = MASK_PLAYERS
	var hcs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = BALL_RADIUS + 8.0
	hcs.shape = hc
	_sense_area.add_child(hcs)
	add_child(_sense_area)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# field gravity (READ-ONLY Tuning.gravity, exactly StormBall's read) + a hard max-speed cap so even a
	# power shot stays chaseable (below the player max_speed of 3000).
	var g := GravityField.get_gravity_at(global_position)
	state.linear_velocity += g * state.step
	state.linear_velocity = state.linear_velocity.limit_length(BALL_MAX_SPEED)

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
	linear_velocity = linear_velocity.limit_length(BALL_MAX_SPEED)

## The ONE mode-owned hazard->ball entry point (v8_sports_courts.md §3.1). A hazard (bomb blast,
## hammer whack, debris drop, crusher eject) calls this to punt the ball; it is the SAME impulse form
## `_drive_from` uses internally (`velocity += impulse / mass`, then re-cap to BALL_MAX_SPEED = 2400),
## which is the FEEL_REFERENCE §4.1 "explosion on props" math verbatim. Keeping ALL ball-force logic
## here behind one method means hazards never reach into ball-physics constants — they just call this.
## The 2400 cap guarantees even a point-blank blast stays chaseable (a hazard can't fling the ball
## into an untrackable blur). NOT a Tuning feel constant — mode-owned, alongside the drive constants.
func receive_hazard_impulse(impulse: Vector2) -> void:
	linear_velocity += impulse / maxf(mass, 0.01)
	linear_velocity = linear_velocity.limit_length(BALL_MAX_SPEED)

## Glossy team-neutral hero ball: chocolate outline, white body, gold seam ring, bright shine dot.
class BallGloss:
	extends Node2D
	func _draw() -> void:
		var r := Ball.BALL_RADIUS
		draw_circle(Vector2.ZERO, r + 4.0, Color(0.231, 0.141, 0.106))            # chocolate outline
		draw_circle(Vector2.ZERO, r, Color(0.97, 0.97, 0.99))                     # white body
		draw_arc(Vector2.ZERO, r - 6.0, 0.0, TAU, 40, Color(1.0, 0.82, 0.25, 0.9), 6.0)   # gold seam ring
		draw_arc(Vector2.ZERO, r - 4.0, PI * 0.15, PI * 0.85, 20, Color(0.72, 0.74, 0.82, 0.8), 5.0)  # bottom shade
		draw_circle(Vector2(-r * 0.34, -r * 0.36), r * 0.24, Color(1, 1, 1, 0.95))         # shine dot
