class_name RingOfFire
extends Area2D
## Ring of Fire trap (spec 3.7): a 160px-diameter fiery ring planted at the holder's position.
## Any player inside is force-super-boosted (2800 px/s, their aim > their velocity > straight up),
## keeps full control, fuel untouched — the recovery scramble IS the content. Expires at
## pu_ring_lifetime or pu_ring_max_triggers. Owner immune for pu_ring_owner_grace, then it
## triggers them too. Per-player re-trigger cooldown pu_ring_retrigger_cd. Ring launches carry
## kill credit to the owner. Cleared at ROUND_END and when sudden-death lasers activate.
## Telegraphy: licking flame particles + embers + additive heat glow — screams "do not fly through".

const RING_RADIUS := 80.0   # 160px diameter torus
const PUFF_TEX := "res://assets/fx/puff_soft.png"

var owner_player = null
var _age := 0.0
var _triggers := 0
var _cds := {}          # player instance_id -> cooldown remaining
var _expired := false
var _glow: Node2D

func _ready() -> void:
	add_to_group("pu_field")
	add_to_group("pu_ring")
	collision_layer = 0
	collision_mask = 1 << 0   # players
	monitoring = true
	z_index = 10

	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RING_RADIUS
	cs.shape = c
	add_child(cs)

	_glow = RingGlow.new()
	add_child(_glow)
	add_child(_make_flames())
	add_child(_make_embers())

	# plant pop
	scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	if _expired:
		return
	_age += delta
	for k in _cds.keys():
		_cds[k] = float(_cds[k]) - delta
	if _age >= Tuning.pu_ring_lifetime:
		_expire()
		return
	# per-frame overlap (not body_entered) so an owner who never left still triggers post-grace
	for b in get_overlapping_bodies():
		if not (b is Player) or b.is_dead() or b.frozen:
			continue
		if b == owner_player and _age < Tuning.pu_ring_owner_grace:
			continue   # placement grace — then it triggers them too (premium comedy)
		if float(_cds.get(b.get_instance_id(), 0.0)) > 0.0:
			continue
		_trigger(b)
		if _triggers >= Tuning.pu_ring_max_triggers:
			_expire()
			return

func _trigger(victim) -> void:
	_triggers += 1
	_cds[victim.get_instance_id()] = Tuning.pu_ring_retrigger_cd
	# kill credit: a ring launch that carries someone out scores for the ring's owner (spec 3.7)
	if owner_player != null and is_instance_valid(owner_player) and victim != owner_player:
		victim.credit_attacker(owner_player)
	victim.force_super_boost()   # full-tank full-charge blast in their aim; no hitstun, fuel untouched
	# trigger flash
	var fl := create_tween()
	fl.tween_property(self, "modulate", Color(2.2, 2.2, 2.2, 1.0), 0.05)
	fl.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)

func _expire() -> void:
	if _expired:
		return
	_expired = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)

## Licking cartoon flames rising off the whole torus.
func _make_flames() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.amount = 60
	p.lifetime = 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = RING_RADIUS
	p.direction = Vector2.UP
	p.spread = 18.0
	p.gravity = Vector2(0, -350)   # flames rise
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.5
	if ResourceLoader.exists(PUFF_TEX):
		p.texture = load(PUFF_TEX)
		p.scale_amount_min = 0.22
		p.scale_amount_max = 0.44
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 1.0))
	grow.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = grow
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.5, 1.0))
	grad.add_point(0.4, Color(1.0, 0.6, 0.1, 0.95))
	grad.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	p.color_ramp = grad
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	return p

## Slow drifting embers above the ring.
func _make_embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.amount = 14
	p.lifetime = 1.1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = RING_RADIUS
	p.direction = Vector2.UP
	p.spread = 30.0
	p.gravity = Vector2(0, -240)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 2.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.8, 0.3, 1.0))
	grad.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	p.color_ramp = grad
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	return p

## Fiery torus body: NORMAL-blend cartoon fire ring (chocolate rim -> deep orange -> hot core)
## so it stays saturated orange against the bright sky instead of washing to white, plus a
## pulsing scale wobble. The flames/embers above are the additive accents.
class RingGlow:
	extends Node2D
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		var k := 1.0 + 0.03 * sin(_t * 7.0)
		scale = Vector2(k, k)
		queue_redraw()
	func _draw() -> void:
		var r := RingOfFire.RING_RADIUS
		var flick := 0.5 + 0.5 * sin(_t * 11.0)
		# chocolate outline band (Toybox read), then the fire body
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(0.28, 0.12, 0.06, 0.9), 26.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(0.95, 0.32, 0.05), 20.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 0.62, 0.08), 12.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 0.9, 0.3, 0.75 + 0.25 * flick), 5.0)
		# flame licks: chunky triangular tongues rising off the torus, flickering
		for i in range(10):
			var a := TAU * float(i) / 10.0 + sin(_t * 3.0 + float(i)) * 0.1
			var base := Vector2(cos(a), sin(a)) * r
			var h := 22.0 + 14.0 * (0.5 + 0.5 * sin(_t * 9.0 + float(i) * 1.7))
			var side := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * 9.0
			var tip := base + Vector2(0, -h)
			draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]),
				Color(1.0, 0.55 + 0.25 * flick, 0.05, 0.9))
