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
# WK-169 L1 GOLDEN TANK (ShowdownDirector sets these before add_child; default = a normal bubble, untouched path)
var golden := false               # WK-169: auto-activates on touch (PowerupSystem.grant_golden_tank), never the held slot
var golden_dur := 6.0             # WK-169: Unlimited Boost seconds granted
var life := -1.0                  # WK-169: s until an uncollected golden bubble pops (< 0 = never, the normal rule)
var on_collect: Callable          # WK-169: ShowdownDirector callback (player) after a golden collect
var on_expire: Callable           # WK-169: ShowdownDirector callback () when it popped uncollected
var _golden_cands: Array = []     # WK-169: players that touched it this physics frame (closest centre wins)

func _ready() -> void:
	add_to_group("pu_field")
	if golden:   # WK-169: outside the regular director's pu_max_on_field count; ShowdownDirector pops it on SD itself
		add_to_group("pu_golden")   # WK-169
	else:
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
	gloss.golden = golden   # WK-169
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
	var s1: float = Tuning.showdown_drop_scale if golden else 1.0   # WK-169: the golden bubble is 1.2x
	scale = Vector2(0.1, 0.1) * s1
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12) * s1, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE * s1, 0.08)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * TAU / BOB_PERIOD) * BOB_PX

## WK-169: an uncollected golden bubble pops after `life` s of game time (pause / hitstop aware).
func _physics_process(delta: float) -> void:
	if not golden or _collected or life < 0.0:   # WK-169: normal bubbles never despawn
		return
	life -= delta   # WK-169
	if life <= 0.0:   # WK-169
		pop()   # WK-169
		if on_expire.is_valid():   # WK-169
			on_expire.call()   # WK-169

func _on_body_entered(body) -> void:
	if _collected:
		return
	if golden:   # WK-169: gather this frame's touches, resolve once (same-frame double touch -> the closer centre)
		if body is Player and not body.is_dead() and not body.frozen and not _golden_cands.has(body):   # WK-169
			_golden_cands.append(body)   # WK-169
			if _golden_cands.size() == 1:   # WK-169
				call_deferred("_resolve_golden")   # WK-169
		return   # WK-169
	if body is Player and not body.is_dead() and not body.frozen:
		_collected = true
		PowerupSystem.grant(body, id)
		_burst()
		queue_free()

## WK-169: pick the touching fighter with the closest centre (exact tie: a coin), grant the golden tank.
func _resolve_golden() -> void:
	if _collected:   # WK-169
		_golden_cands.clear()   # WK-169
		return   # WK-169
	var best = null   # WK-169
	var best_d := INF   # WK-169
	for p in _golden_cands:   # WK-169
		if not is_instance_valid(p) or p.is_dead() or p.frozen:   # WK-169
			continue   # WK-169
		var d: float = (p.global_position as Vector2).distance_to(global_position)   # WK-169
		if d < best_d - 0.001 or (absf(d - best_d) <= 0.001 and randf() < 0.5):   # WK-169
			best_d = d   # WK-169
			best = p   # WK-169
	_golden_cands.clear()   # WK-169
	if best == null:   # WK-169
		return   # WK-169
	_collected = true   # WK-169
	PowerupSystem.grant_golden_tank(best, golden_dur)   # WK-169
	if on_collect.is_valid():   # WK-169
		on_collect.call(best)   # WK-169
	_burst()   # WK-169
	queue_free()   # WK-169

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
	var golden := false   # WK-169
	func _draw() -> void:
		var r := PowerupBubble.RADIUS
		if golden:   # WK-169 L1 prototype read: a gold glossy bubble (the real golden-tank art is 169c)
			draw_circle(Vector2.ZERO, r + 10.0, Color(1.0, 0.82, 0.25, 0.22))   # WK-169: soft outer glow
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.84, 0.30, 0.45))   # WK-169: gold body
			draw_arc(Vector2.ZERO, r - 6.0, 0.0, TAU, 48, Color(1.0, 0.95, 0.7, 0.35), 8.0)   # WK-169
			draw_arc(Vector2.ZERO, r - 1.5, 0.0, TAU, 56, Color(1.0, 0.93, 0.55, 1.0), 4.5)   # WK-169: bright gold rim
			draw_arc(Vector2.ZERO, r + 2.0, 0.0, TAU, 56, Color(0.231, 0.141, 0.106, 0.7), 3.0)   # WK-169: chocolate outline
			draw_arc(Vector2.ZERO, r - 9.0, PI * 1.05, PI * 1.45, 20, Color(1, 1, 1, 0.95), 5.0)   # WK-169
			draw_circle(Vector2(-r * 0.38, -r * 0.44), 4.5, Color(1, 1, 1, 0.95))   # WK-169
			return   # WK-169
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
