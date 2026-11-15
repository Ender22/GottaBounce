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
const GOLDEN_ICON := "res://assets/powerups/icon_golden_tank.png"   # WK-169c: hue-masked recolour of icon_unlimited_boost.png

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

	if golden:   # WK-169c §2.4: halo (behind decks + goats) and orbiting sparkles; visual only, the collider is untouched
		var halo := GoldenHalo.new()   # WK-169c
		halo.bubble_scale = Tuning.showdown_drop_scale   # WK-169c
		add_child(halo)   # WK-169c

	var gloss := BubbleGloss.new()
	gloss.golden = golden   # WK-169
	add_child(gloss)

	var icon := Sprite2D.new()
	var path := "res://assets/powerups/icon_%s.png" % id
	var icon_px: float = ICON_PX   # WK-169c
	if golden and ResourceLoader.exists(GOLDEN_ICON):   # WK-169c: the gold jerrycan, 64 world px (the bubble node is scaled)
		path = GOLDEN_ICON   # WK-169c
		icon_px = Tuning.showdown_drop_icon_px / maxf(Tuning.showdown_drop_scale, 0.01)   # WK-169c
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		icon.texture = tex
		var m: float = maxf(float(tex.get_width()), float(tex.get_height()))
		icon.scale = Vector2.ONE * (icon_px / maxf(m, 1.0))   # WK-169c (was ICON_PX)
	add_child(icon)
	if golden:   # WK-169c: the white glint sweeps over body + icon
		var gl := GoldenGlint.new()   # WK-169c
		add_child(gl)   # WK-169c

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
	PowerupSystem.grant_golden_tank(best, golden_dur, Tuning.showdown_drop_arm_s)   # WK-169 (WK-169c: GOLD SURGE arm, 0 = today)
	if on_collect.is_valid():   # WK-169
		on_collect.call(best)   # WK-169
	_burst(true)   # WK-169 (WK-169c: gold-tinted, 1.5x)
	queue_free()   # WK-169

## Sudden-death cutoff: live bubbles pop without granting anything (spec §4).
func pop() -> void:
	if _collected:
		return
	_collected = true
	_burst(golden)   # WK-169c: a golden bubble pops gold
	queue_free()

## WK-169c §2.8 (b): a golden drop claimed this bubble's spawner. A gold-tinted "upgrade" pop, no grant, no sound of its own.
func upgrade_pop() -> void:   # WK-169c
	if _collected:   # WK-169c
		return   # WK-169c
	_collected = true   # WK-169c
	_burst(true)   # WK-169c
	queue_free()   # WK-169c

func _burst(gold := false) -> void:   # WK-169c: gold = the golden collect / upgrade pop (hue 0, gold -> white, 1.5x)
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
	if gold:   # WK-169c: gold -> white, no hue spread, 1.5x count; normal blend (additive gold washes out on bright skies)
		p.amount = 39   # WK-169c
		p.hue_variation_min = 0.0   # WK-169c
		p.hue_variation_max = 0.0   # WK-169c
		grad.set_color(0, Color(1.0, 0.78, 0.16, 1.0))   # WK-169c
		grad.set_color(1, Color(1.0, 1.0, 0.95, 0.0))   # WK-169c
		grad.add_point(0.5, Color(1.0, 0.92, 0.5, 1.0))   # WK-169c
	p.color_ramp = grad
	if not gold:   # WK-169c
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
	var _z := -1.0   # WK-169c: camera zoom the umber stroke was drawn for
	func _process(_delta: float) -> void:   # WK-169c: only the golden stroke tracks the zoom (normal bubbles never redraw)
		if not golden:   # WK-169c
			set_process(false)   # WK-169c
			return   # WK-169c
		var cam := get_viewport().get_camera_2d()   # WK-169c
		var z: float = maxf(cam.zoom.x, 0.05) if cam != null else 1.0   # WK-169c
		if absf(z - _z) > 0.002:   # WK-169c
			_z = z   # WK-169c
			queue_redraw()   # WK-169c
	func _draw() -> void:
		var r := PowerupBubble.RADIUS
		if golden:   # WK-169 L1 read (WK-169c §2.4: visual body = collider x showdown_drop_body_mult, warmer body, 6 px rim)
			r = PowerupBubble.RADIUS * Tuning.showdown_drop_body_mult   # WK-169c: 54 world px at scale 1.2 (collider stays 43.2)
			draw_circle(Vector2.ZERO, r + 10.0, Color(1.0, 0.82, 0.25, 0.22))   # WK-169: soft outer glow
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.80, 0.24, 0.62))   # WK-169 (WK-169c: alpha 0.45 -> 0.62)
			draw_arc(Vector2.ZERO, r - 7.0, 0.0, TAU, 48, Color(1.0, 0.95, 0.7, 0.35), 8.0)   # WK-169
			draw_arc(Vector2.ZERO, r - 2.0, 0.0, TAU, 56, Color(1.0, 0.93, 0.55, 1.0), 6.0)   # WK-169 (WK-169c: rim 4.5 -> 6 px)
			draw_arc(Vector2.ZERO, r + 2.5, 0.0, TAU, 56, Color(0.231, 0.141, 0.106, 0.85), 3.0)   # WK-169: chocolate outline (3 px)
			var sc: float = maxf(Tuning.showdown_drop_scale, 0.01)   # WK-169c: the bubble node's settled scale (never the pop-in tween's)
			var sw: float = Tuning.showdown_drop_stroke_px / (maxf(_z, 0.05) * sc)   # WK-169c: ~2 SCREEN px at every zoom
			draw_arc(Vector2.ZERO, r + 4.0 + sw * 0.5, 0.0, TAU, 72, Color(0.36, 0.2, 0.07, 1.0), sw, true)   # WK-169c: umber stroke (T-G3)
			draw_arc(Vector2.ZERO, r - 11.0, PI * 1.05, PI * 1.45, 20, Color(1, 1, 1, 0.95), 6.0)   # WK-169
			draw_circle(Vector2(-r * 0.38, -r * 0.44), 5.5, Color(1, 1, 1, 0.95))   # WK-169
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

## WK-169c §2.4: the golden bubble's halo - a soft radial gold glow (no outline: light, not body) whose DIAMETER is
## max(showdown_drop_halo_px SCREEN px, showdown_drop_halo_body_mult x the visual body), so it reads at the widest void zoom
## (the screen floor) and still clears the body at close zooms. The glow draws at an absolute z just above the backdrop dim and
## below decks / goats, so it can never tint a goat. Six star sparkles orbit its edge (one rev per showdown_drop_sparkle_rev_s).
class GoldenHalo:   # WK-169c
	extends Node2D
	var bubble_scale := 1.2
	var _t := 0.0
	var _z := -1.0
	var _glow: Node2D = null
	var _stars: Array = []
	static var _tex: GradientTexture2D = null
	func _ready() -> void:
		_glow = Node2D.new()
		_glow.name = "Glow"
		_glow.z_as_relative = false
		_glow.z_index = -2   # above the dim plate (-79) and the backdrop, below decks (-1 / 0) and every goat
		_glow.draw.connect(_draw_glow)
		add_child(_glow)
		if ResourceLoader.exists(PowerupBubble.SPARKLE_TEX):
			var tex: Texture2D = load(PowerupBubble.SPARKLE_TEX)
			for i in range(6):
				var sp := Sprite2D.new()
				sp.texture = tex
				sp.modulate = Color(1.0, 0.9, 0.45, 0.95)
				add_child(sp)
				_stars.append(sp)
		_place(0.0)
	## World diameter of the halo at camera zoom z (the T-G1 read).
	static func diameter_world(z: float) -> float:
		var body_d: float = 2.0 * PowerupBubble.RADIUS * Tuning.showdown_drop_body_mult * Tuning.showdown_drop_scale
		return maxf(Tuning.showdown_drop_halo_px / maxf(z, 0.05), Tuning.showdown_drop_halo_body_mult * body_d)
	func _process(delta: float) -> void:
		_place(delta)
	func _place(delta: float) -> void:
		_t += delta
		var cam := get_viewport().get_camera_2d()
		var z: float = maxf(cam.zoom.x, 0.05) if cam != null else 1.0
		if absf(z - _z) > 0.001:
			_z = z
			_glow.queue_redraw()
		var r: float = diameter_world(z) * 0.5 / maxf(bubble_scale, 0.01)   # local units (the bubble node is scaled)
		var star_px: float = 26.0 / z / maxf(bubble_scale, 0.01)   # ~26 screen px stars
		var rev: float = maxf(Tuning.showdown_drop_sparkle_rev_s, 0.1)
		for i in range(_stars.size()):
			var sp: Sprite2D = _stars[i]
			var a: float = TAU * (_t / rev + float(i) / float(_stars.size()))
			sp.position = Vector2(cos(a), sin(a)) * r * 0.9
			var tw: float = 0.75 + 0.25 * sin(_t * 5.0 + float(i) * 1.7)   # twinkle
			var m: float = maxf(float(sp.texture.get_width()), 1.0)
			sp.scale = Vector2.ONE * (star_px / m) * tw
			sp.rotation = a * 0.5
	func _draw_glow() -> void:
		if _tex == null:
			var g := Gradient.new()
			g.set_color(0, Color(1.0, 0.80, 0.20, 0.9))   # saturated warm gold: reads as light on pale sky AND on dark void
			g.set_color(1, Color(1.0, 0.66, 0.08, 0.0))
			g.add_point(0.35, Color(1.0, 0.76, 0.16, 0.62))
			g.add_point(0.65, Color(1.0, 0.70, 0.12, 0.3))
			g.add_point(0.85, Color(1.0, 0.68, 0.1, 0.1))   # a long soft tail: light, not a disc edge
			_tex = GradientTexture2D.new()
			_tex.gradient = g
			_tex.fill = GradientTexture2D.FILL_RADIAL
			_tex.fill_from = Vector2(0.5, 0.5)
			_tex.fill_to = Vector2(1.0, 0.5)
			_tex.width = 256
			_tex.height = 256
		var r: float = diameter_world(maxf(_z, 0.05)) * 0.5 / maxf(bubble_scale, 0.01)
		_glow.draw_texture_rect(_tex, Rect2(-r, -r, r * 2.0, r * 2.0), false)

## WK-169c §2.4: a white glint sweeping diagonally across the golden body every showdown_drop_glint_s (motion draws the eye).
class GoldenGlint:   # WK-169c
	extends Node2D
	const SWEEP_S := 0.36   # s the band takes to cross the body
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var period: float = maxf(Tuning.showdown_drop_glint_s, SWEEP_S + 0.05)
		var ph: float = fmod(_t, period)
		if ph > SWEEP_S:
			return
		var r: float = PowerupBubble.RADIUS * Tuning.showdown_drop_body_mult - 4.0
		var u: float = ph / SWEEP_S   # 0 -> 1
		var axis := Vector2(1, 1).normalized()   # the band travels top-left -> bottom-right
		var perp := Vector2(1, -1).normalized()
		var s: float = lerpf(-r, r, u)
		var half: float = sqrt(maxf(0.0, r * r - s * s))
		var a: float = sin(u * PI)   # fades in / out at the rim
		var c: Vector2 = axis * s
		draw_line(c - perp * half, c + perp * half, Color(1, 1, 1, 0.55 * a), 12.0, true)
		var s2: float = s - 16.0
		if absf(s2) < r:
			var h2: float = sqrt(maxf(0.0, r * r - s2 * s2))
			draw_line(axis * s2 - perp * h2, axis * s2 + perp * h2, Color(1, 1, 1, 0.3 * a), 5.0, true)
