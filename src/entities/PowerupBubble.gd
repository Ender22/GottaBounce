class_name PowerupBubble
extends Area2D
## A floating glossy powerup bubble (spec §2 pickup model): 72px diameter, bobs ±8px on a 1.2s
## sine, shows the SPECIFIC powerup's icon (~48px) so players race for the one they want.
## Collect on touch → confetti pop + PowerupSystem.grant. Uncollected bubbles never despawn
## (a standing dare); sudden death pops them via pop().
## Set `id` before add_child. Code-drawn glossy soap-bubble (Glossy Toybox — never a flat circle).

const RADIUS := 36.0
const BOB_PX := 8.0
const BOB_PERIOD := 1.2
const ICON_PX := 48.0
const SPARKLE_TEX := "res://assets/fx/star_sparkle.png"

var id := "star"
var _t := 0.0
var _base_y := 0.0
var _collected := false

func _ready() -> void:
	add_to_group("pu_field")
	add_to_group("pu_bubble")
	collision_layer = 0
	collision_mask = 1 << 0   # players
	monitoring = true
	body_entered.connect(_on_body_entered)
	z_index = 11
	_base_y = position.y

	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	cs.shape = c
	add_child(cs)

	var gloss := BubbleGloss.new()
	add_child(gloss)

	var icon := Sprite2D.new()
	var path := "res://assets/powerups/icon_%s.png" % id
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		icon.texture = tex
		var m: float = maxf(float(tex.get_width()), float(tex.get_height()))
		icon.scale = Vector2.ONE * (ICON_PX / maxf(m, 1.0))
	add_child(icon)

	# materialize pop (arrives at the end of the sparkle telegraph)
	scale = Vector2(0.1, 0.1)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * TAU / BOB_PERIOD) * BOB_PX

func _on_body_entered(body) -> void:
	if _collected:
		return
	if body is Player and not body.is_dead() and not body.frozen:
		_collected = true
		PowerupSystem.grant(body, id)
		_burst()
		queue_free()

## Sudden-death cutoff: live bubbles pop without granting anything (spec §4).
func pop() -> void:
	if _collected:
		return
	_collected = true
	_burst()
	queue_free()

func _burst() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 26
	p.lifetime = 0.55
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2(0, 500)
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 480.0
	p.scale_amount_min = 2.2
	p.scale_amount_max = 4.0
	if ResourceLoader.exists(SPARKLE_TEX):
		p.texture = load(SPARKLE_TEX)
		p.scale_amount_min = 0.18
		p.scale_amount_max = 0.34
	p.hue_variation_min = -0.4
	p.hue_variation_max = 0.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	grad.set_color(1, Color(0.7, 0.9, 1.0, 0.0))
	p.color_ramp = grad
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	parent.add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## Code-drawn glossy soap bubble: translucent pastel fill, bright rim, top-left highlight arc,
## small shine dot — reads "grab me" at any zoom.
class BubbleGloss:
	extends Node2D
	func _draw() -> void:
		var r := PowerupBubble.RADIUS
		# soft translucent body with a faint sky tint
		draw_circle(Vector2.ZERO, r, Color(0.78, 0.92, 1.0, 0.22))
		# inner glow band
		draw_arc(Vector2.ZERO, r - 6.0, 0.0, TAU, 48, Color(1, 1, 1, 0.14), 8.0)
		# crisp rim
		draw_arc(Vector2.ZERO, r - 1.5, 0.0, TAU, 56, Color(1, 1, 1, 0.85), 3.5)
		# chocolate outline just outside the rim (Toybox read against any background)
		draw_arc(Vector2.ZERO, r + 1.5, 0.0, TAU, 56, Color(0.231, 0.141, 0.106, 0.5), 2.5)
		# glossy top-left highlight arc + shine dot
		draw_arc(Vector2.ZERO, r - 9.0, PI * 1.05, PI * 1.45, 20, Color(1, 1, 1, 0.9), 5.0)
		draw_circle(Vector2(-r * 0.38, -r * 0.44), 4.5, Color(1, 1, 1, 0.95))
