class_name StormBall
extends RigidBody2D
## One Ball Storm bouncy ball (spec 3.5): radius 15, restitution 0.9, mass 0.4. Ricochets off
## all surfaces/bumpers; the first player it touches takes pu_ball_hit_impulse along the ball's
## velocity + standard hitstun, then the ball pops (one hit per ball). Unused balls star-spark
## out at pu_ball_lifetime. Owner grace pu_ball_owner_grace (a REBOUND self-hit is the comedy).
## Star holders pop balls harmlessly; a live Counter Shield reflects them at 1.5x speed.
## Kill credit routes through receive_smash(…, thrower) → last_attacker.
## Glossy Toybox look: code-drawn orange ball with chocolate outline + shine dot.

const BALL_RADIUS := 15.0
const LAYER_PROPS := 1 << 1
const SPARKLE_TEX := "res://assets/fx/star_sparkle.png"

var thrower = null
var _age := 0.0
var _popped := false
var _reflect_cd := 0.0
var _hit_area: Area2D

func _ready() -> void:
	add_to_group("pu_field")
	add_to_group("pu_ball")
	add_to_group("impulsable")
	collision_layer = LAYER_PROPS
	collision_mask = (1 << 2) | LAYER_PROPS   # surfaces + other balls (pachinko!)
	gravity_scale = 0.0                        # gravity from the field (INV-1)
	mass = 0.4
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.9
	pm.friction = 0.1
	physics_material_override = pm

	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = BALL_RADIUS
	cs.shape = c
	add_child(cs)

	add_child(BallGloss.new())

	_hit_area = Area2D.new()
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = 1 << 0   # players
	var hcs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = BALL_RADIUS + 6.0
	hcs.shape = hc
	_hit_area.add_child(hcs)
	add_child(_hit_area)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var g := GravityField.get_gravity_at(global_position)
	state.linear_velocity += g * state.step
	state.linear_velocity = state.linear_velocity.limit_length(Tuning.max_speed)

func _physics_process(delta: float) -> void:
	if _popped:
		return
	_age += delta
	_reflect_cd = maxf(0.0, _reflect_cd - delta)
	if _age >= Tuning.pu_ball_lifetime:
		pop()   # never hit anyone — star-spark out (spec 3.5)
		return
	for b in _hit_area.get_overlapping_bodies():
		if not (b is Player) or b.is_dead():
			continue
		if b == thrower and _age < Tuning.pu_ball_owner_grace:
			continue   # owner grace: no guaranteed instant self-hit
		if b.counter_active:
			# Counter Shield reflects the ball at 1.5x speed, holder unharmed (spec 3.4)
			if _reflect_cd <= 0.0:
				var away: Vector2 = (global_position - b.global_position).normalized()
				if away == Vector2.ZERO:
					away = Vector2.UP
				linear_velocity = away * maxf(linear_velocity.length(), 300.0) * 1.5
				_reflect_cd = 0.25
			continue
		if b.invincible:
			pop()   # Star holders pop balls on contact harmlessly (spec 3.5)
			return
		var dir: Vector2 = linear_velocity.normalized()
		if dir == Vector2.ZERO:
			dir = (b.global_position - global_position).normalized()
		b.receive_smash(dir * Tuning.pu_ball_hit_impulse, thrower)
		pop()
		return

func pop() -> void:
	if _popped:
		return
	_popped = true
	var parent := get_parent()
	if parent != null:
		var p := CPUParticles2D.new()
		p.global_position = global_position
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 8
		p.lifetime = 0.35
		p.spread = 180.0
		p.direction = Vector2.UP
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 300.0
		p.scale_amount_min = 1.8
		p.scale_amount_max = 3.0
		if ResourceLoader.exists(SPARKLE_TEX):
			p.texture = load(SPARKLE_TEX)
			p.scale_amount_min = 0.14
			p.scale_amount_max = 0.26
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
		grad.set_color(1, Color(1.0, 0.5, 0.15, 0.0))
		p.color_ramp = grad
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = m
		parent.add_child(p)
		get_tree().create_timer(0.8).timeout.connect(p.queue_free)
	queue_free()

func apply_impulse_vector(v: Vector2) -> void:
	linear_velocity += v / maxf(mass, 0.01)

func receive_smash(impulse: Vector2, _attacker) -> void:
	linear_velocity += impulse / maxf(mass, 0.01)

## Glossy orange bouncy ball: chocolate outline, vivid body, rim shade, white shine dot.
class BallGloss:
	extends Node2D
	func _draw() -> void:
		var r := StormBall.BALL_RADIUS
		draw_circle(Vector2.ZERO, r + 2.5, Color(0.231, 0.141, 0.106))          # chocolate outline
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.56, 0.15))                     # orange body
		draw_arc(Vector2.ZERO, r - 3.0, PI * 0.15, PI * 0.85, 18, Color(0.82, 0.38, 0.08, 0.8), 4.0)  # bottom shade
		draw_circle(Vector2(-r * 0.35, -r * 0.38), r * 0.26, Color(1, 1, 1, 0.95))                    # shine dot
