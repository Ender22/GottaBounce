extends Node
## Powerup framework (docs/specs/v1_powerups.md §2). One held slot per player; activate via
## InputIntent.use_powerup (Player calls try_use). Owns: activation, timed active effects,
## per-powerup telegraphy nodes (over-head held icon, star rainbow trail, shield bubble,
## black-hole vortex, mega contact rings), and the death / round-end sweeps.
## Autoloaded as `PowerupSystem`. QA hooks (spec §2): grant(player, id), try_use(player),
## plus eval-readable player.active_powerup / player.powerup_time_left.
##
## Field objects (balls / rings / bubbles / telegraphs) all join group "pu_field" so the
## ROUND_END sweep can clear the arena in one pass. Autoload rule: entity scripts are load()ed
## at runtime, never referenced by class_name at parse time.

const SHIPPED := ["mega_bounce", "unlimited_boost", "star", "counter_shield", "ball_storm",
	"black_hole", "ring_of_fire"]
# Drop weights (spec §4): rarer = smaller.
const WEIGHTS := {
	"star": 1, "black_hole": 2, "unlimited_boost": 2, "mega_bounce": 3,
	"ring_of_fire": 3, "ball_storm": 4, "counter_shield": 4,
}
const BALL_PATH := "res://src/entities/StormBall.gd"
const RING_PATH := "res://src/entities/RingOfFire.gd"
const ICON_PATH := "res://assets/powerups/icon_%s.png"
const SPARKLE_TEX := "res://assets/fx/star_sparkle.png"
const PUFF_TEX := "res://assets/fx/puff_soft.png"
const HELD_ICON_Y := -136.0     # over-head held icon anchor (target-painting, spec §2)
const HELD_ICON_PX := 32.0
const CHOCOLATE := Color(0.231, 0.141, 0.106)

# player -> { "id": String, "t": float, "nodes": Array[Node] } — one timed active effect each
var _active := {}
# player -> over-head held-icon Node2D
var _held_icons := {}

func _ready() -> void:
	KillPipeline.killed.connect(_on_killed)
	EventBus.bounced_juicy.connect(_on_bounced_juicy)

# ------------------------------------------------------------------ grant / use (QA hooks)

## Put `id` in the player's held slot (pickup touch AND eval both route here). Swap rule
## (spec §2): the old held powerup poofs — puff + falling-icon gag, never dropped as a pickup.
func grant(player, id: String) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return
	if not SHIPPED.has(id):
		push_warning("PowerupSystem: unknown powerup id '%s'" % id)
		return
	if player.held_powerup != "" and player.held_powerup != id:
		_swap_poof(player, player.held_powerup)
	player.held_powerup = id
	_refresh_held_icon(player)

func try_use(player) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return
	var id: String = player.held_powerup
	if id == "":
		return
	player.held_powerup = ""
	_refresh_held_icon(player)
	_activate(id, player)

# ------------------------------------------------------------------ activation

func _activate(id: String, player) -> void:
	EventBus.powerup_used.emit(player, id)
	# Re-activating the SAME active effect restarts its timer, no doubling (spec §2).
	if _active.has(player) and _active[player]["id"] == id:
		_active[player]["t"] = _duration(id)
		player.powerup_time_left = _active[player]["t"]
		if id == "black_hole":   # restart = re-channel
			player.channel_broken = false
			player.start_channel(Tuning.pu_black_hole_dur)
		return
	# A different effect while one is active: the old one ends, the new one takes the slot.
	if _active.has(player):
		_end_effect(player, false)
	match id:
		"mega_bounce":
			player.bounce_mult = Tuning.pu_mega_bounce_mult
			_begin_effect(player, id, [_make_trail(player, false)])
		"unlimited_boost":
			player.fuel_locked = true
			player.fuel = Tuning.fuel_max
			_begin_effect(player, id, [])
		"star":
			player.invincible = true
			player.contact_launch = true
			player.rainbow = true
			_begin_effect(player, id, [_make_trail(player, true)])
		"counter_shield":
			player.counter_active = true
			var bubble := ShieldBubble.new()
			player.add_child(bubble)
			_begin_effect(player, id, [bubble])
		"black_hole":
			player.cancel_super_charge()   # channeling replaces the charge, fuel retained (spec 3.6)
			player.channel_broken = false
			player.silhouette = true
			player.start_channel(Tuning.pu_black_hole_dur)
			var vortex := Vortex.new()
			player.add_child(vortex)
			var streaks := _make_inward_streaks()
			player.add_child(streaks)
			_begin_effect(player, id, [vortex, streaks])
		"ball_storm":
			_burst_balls(player)   # instant — the 16 balls ARE the effect (no active state)
		"ring_of_fire":
			_plant_ring(player)    # instant — the planted ring is the field object

func _duration(id: String) -> float:
	match id:
		"mega_bounce": return Tuning.pu_mega_bounce_dur
		"unlimited_boost": return Tuning.pu_unlimited_boost_dur
		"star": return Tuning.pu_star_dur
		"counter_shield": return Tuning.pu_counter_dur
		"black_hole": return Tuning.pu_black_hole_dur
	return 0.0

func _begin_effect(player, id: String, nodes: Array) -> void:
	_active[player] = { "id": id, "t": _duration(id), "nodes": nodes }
	player.active_powerup = id
	player.powerup_time_left = _duration(id)

func _physics_process(delta: float) -> void:
	for player in _active.keys():
		if not is_instance_valid(player):
			_active.erase(player)
			continue
		var st: Dictionary = _active[player]
		st["t"] -= delta
		player.powerup_time_left = maxf(0.0, st["t"])
		var id: String = st["id"]
		if id == "unlimited_boost":
			player.fuel = Tuning.fuel_max   # pinned at max (super dumps refill instantly)
		if id == "black_hole" and player.channel_broken:
			_end_effect(player, false)      # smashed mid-channel: cancelled, NO fuel refill
			continue
		if st["t"] <= 0.0:
			_end_effect(player, true)

## Tear down one active effect. `expired` = it ran its full course (vs death/cancel/sweep).
func _end_effect(player, expired: bool) -> void:
	if not _active.has(player):
		return
	var st: Dictionary = _active[player]
	_active.erase(player)
	var id: String = st["id"]
	if is_instance_valid(player):
		match id:
			"mega_bounce":
				player.bounce_mult = 1.0
			"unlimited_boost":
				player.fuel_locked = false
			"star":
				player.invincible = false
				player.contact_launch = false
				player.rainbow = false
			"counter_shield":
				player.counter_active = false
			"black_hole":
				player.silhouette = false
				if expired and not player.channel_broken:
					player.fuel = Tuning.fuel_max   # the hole "feeds" you (spec 3.6 payoff)
				player.start_channel(0.0)
		player.active_powerup = ""
		player.powerup_time_left = 0.0
	for n in st["nodes"]:
		if not is_instance_valid(n):
			continue
		if expired and n is ShieldBubble:
			n.shrink_pop()   # fades with a shrink-pop at expiry (spec 3.4)
		else:
			n.queue_free()

# ------------------------------------------------------------------ sweeps (death / round end)

## Death clears everything immediately (spec §2 — no Star sparkles on a corpse).
func _on_killed(victim, _cause, _attacker) -> void:
	# duck-typed (autoloads never reference class_name types at parse time)
	if victim == null or not is_instance_valid(victim) or not ("held_powerup" in victim):
		return
	_end_effect(victim, false)
	victim.held_powerup = ""
	_refresh_held_icon(victim)

## ROUND_END sweep (spec §2): all active effects end, held slots empty, field objects gone.
func round_sweep() -> void:
	for player in _active.keys().duplicate():
		_end_effect(player, false)
	for player in _held_icons.keys().duplicate():
		if is_instance_valid(player):
			player.held_powerup = ""
		_refresh_held_icon(player)
	for n in get_tree().get_nodes_in_group("pu_field"):
		n.queue_free()

## Sudden death (spec §2/§4): rings are cleared when the lasers activate; active effects and
## in-flight balls keep running (a Star finale is hilarious). Bubbles are popped by the director.
func clear_rings() -> void:
	for n in get_tree().get_nodes_in_group("pu_ring"):
		n.queue_free()

# ------------------------------------------------------------------ drop table

func roll_id(exclude: String = "") -> String:
	var pool: Array = []
	for id in SHIPPED:
		if id != exclude:
			pool.append(id)
	var total := 0
	for id in pool:
		total += int(WEIGHTS.get(id, 3))
	var roll := randf() * float(total)
	var cum := 0.0
	for id in pool:
		cum += float(WEIGHTS.get(id, 3))
		if roll < cum:
			return id
	var last: String = pool[pool.size() - 1]
	return last

# ------------------------------------------------------------------ ball storm / ring of fire

func _burst_balls(player) -> void:
	var parent: Node = player.get_parent()
	if parent == null:
		return
	var ball_script := load(BALL_PATH)
	for i in range(Tuning.pu_ball_count):
		var ball = ball_script.new()
		ball.thrower = player
		parent.add_child(ball)
		ball.global_position = player.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		ball.linear_velocity = Vector2(randf_range(-320, 320), randf_range(-420, -120))
	# confetti-cannon flash + big rumble (spec 3.5 — the burst IS the telegraph)
	_confetti(player.get_parent(), player.global_position, 40)
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, 0.8, 0.9, 0.25)

func _plant_ring(player) -> void:
	var parent: Node = player.get_parent()
	if parent == null:
		return
	var ring = load(RING_PATH).new()
	ring.owner_player = player
	parent.add_child(ring)
	ring.global_position = player.global_position

# ------------------------------------------------------------------ telegraphy visuals

## Over-head held icon (32px, bobbing): deliberate target-painting (spec §2).
func _refresh_held_icon(player) -> void:
	var icon: Node2D = _held_icons.get(player)
	if icon != null and is_instance_valid(icon):
		icon.queue_free()
	_held_icons.erase(player)
	if player == null or not is_instance_valid(player) or player.held_powerup == "":
		return
	var root := Node2D.new()
	root.position = Vector2(0, HELD_ICON_Y)
	var spr := _icon_sprite(player.held_powerup, HELD_ICON_PX)
	root.add_child(spr)
	player.add_child(root)
	_held_icons[player] = root
	root.scale = Vector2(0.2, 0.2)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bob := root.create_tween().set_loops()
	bob.tween_property(root, "position:y", HELD_ICON_Y - 8.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(root, "position:y", HELD_ICON_Y + 8.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _icon_sprite(id: String, target_px: float) -> Sprite2D:
	var spr := Sprite2D.new()
	var path := ICON_PATH % id
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		spr.texture = tex
		var m: float = maxf(float(tex.get_width()), float(tex.get_height()))
		spr.scale = Vector2.ONE * (target_px / maxf(m, 1.0))
	return spr

## Swap gag (spec §2): the replaced icon puffs and tumbles off the holder's head.
func _swap_poof(player, old_id: String) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var spr := _icon_sprite(old_id, HELD_ICON_PX)
	spr.global_position = player.global_position + Vector2(0, HELD_ICON_Y)
	spr.z_index = 20
	scene.add_child(spr)
	var tw := spr.create_tween().set_parallel(true)
	tw.tween_property(spr, "global_position", spr.global_position + Vector2(randf_range(-50, 50), 170.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(spr, "rotation", randf_range(-3.0, 3.0), 0.55)
	tw.tween_property(spr, "modulate:a", 0.0, 0.55)
	tw.chain().tween_callback(spr.queue_free)
	_puff(scene, spr.global_position)

func _puff(parent: Node, pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 8
	p.lifetime = 0.4
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.4
	if ResourceLoader.exists(PUFF_TEX):
		p.texture = load(PUFF_TEX)
		p.scale_amount_min = 0.2
		p.scale_amount_max = 0.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.8))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = grad
	parent.add_child(p)
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)

## Confetti burst (bubble pop / ball storm flash).
func _confetti(parent: Node, pos: Vector2, amount: int) -> void:
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.6
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2(0, 700)
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 560.0
	p.scale_amount_min = 2.2
	p.scale_amount_max = 4.0
	if ResourceLoader.exists(SPARKLE_TEX):
		p.texture = load(SPARKLE_TEX)
		p.scale_amount_min = 0.16
		p.scale_amount_max = 0.3
	p.color = Color(1, 1, 1)
	p.hue_variation_min = -0.5
	p.hue_variation_max = 0.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	grad.set_color(1, Color(1.0, 0.7, 0.9, 0.0))
	p.color_ramp = grad
	parent.add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## Mega Bounce: thick white ring-shockwave at every bounce contact (spec 3.1).
func _on_bounced_juicy(body, _launch_speed, contact) -> void:
	if _active.has(body) and _active[body]["id"] == "mega_bounce":
		var scene := get_tree().current_scene
		if scene == null:
			return
		var ring := ExpandRing.new()
		ring.global_position = contact
		scene.add_child(ring)

## Shedding trail while an aura effect is live (star sparkles / mega's faint arc puffs).
func _make_trail(player, star: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.local_coords = false   # world-space: sheds a real trail along the flight arc
	p.emitting = true
	p.amount = 22 if star else 12
	p.lifetime = 0.55
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 80.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 34.0
	var grad := Gradient.new()
	if star:
		if ResourceLoader.exists(SPARKLE_TEX):
			p.texture = load(SPARKLE_TEX)
			p.scale_amount_min = 0.18
			p.scale_amount_max = 0.4
		else:
			p.scale_amount_min = 2.4
			p.scale_amount_max = 4.2
		grad.set_color(0, Color(1.0, 0.92, 0.35, 1.0))
		grad.set_color(1, Color(1.0, 0.75, 0.2, 0.0))
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = m
	else:
		if ResourceLoader.exists(PUFF_TEX):
			p.texture = load(PUFF_TEX)
			p.scale_amount_min = 0.14
			p.scale_amount_max = 0.26
		else:
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.2
		grad.set_color(0, Color(1, 1, 1, 0.45))
		grad.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = grad
	player.add_child(p)
	return p

## Black Hole: curved pull-streak particles flowing inward from all directions (spec 3.6).
func _make_inward_streaks() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.amount = 46
	p.lifetime = 0.55
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 300.0
	p.direction = Vector2.ZERO
	p.spread = 0.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.radial_accel_min = -2600.0
	p.radial_accel_max = -3400.0
	if ResourceLoader.exists(SPARKLE_TEX):
		p.texture = load(SPARKLE_TEX)
		p.scale_amount_min = 0.14
		p.scale_amount_max = 0.3
	else:
		p.scale_amount_min = 2.0
		p.scale_amount_max = 3.4
	var grad := Gradient.new()
	grad.set_color(0, Color(0.75, 0.5, 1.0, 0.0))
	grad.add_point(0.3, Color(0.8, 0.55, 1.0, 0.9))
	grad.set_color(1, Color(1.0, 0.95, 1.0, 1.0))
	p.color_ramp = grad
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	return p

# ------------------------------------------------------------------ inner visual classes

## Thick white expanding ring (Mega Bounce contact shockwave).
class ExpandRing:
	extends Node2D
	func _ready() -> void:
		z_index = 12
		scale = Vector2(0.3, 0.3)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2(2.6, 2.6), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(queue_free)
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 52.0, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 11.0)
		draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 5.0)

## Counter Shield: glossy hex-bubble ring around the whole character for the 2s window,
## with a bright 0.15s activation flash (spec 3.4).
class ShieldBubble:
	extends Node2D
	const R := 72.0
	const SKY := Color(0.45, 0.78, 1.0)
	var _t := 0.0
	func _ready() -> void:
		z_index = 14
		modulate = Color(3.0, 3.0, 3.0, 1.0)   # activation flash — one readable "abort!" frame
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15)
	func _process(delta: float) -> void:
		_t += delta
		scale = Vector2.ONE * (1.0 + 0.04 * sin(_t * 9.0))
		rotation += delta * 0.6
		queue_redraw()
	func _draw() -> void:
		var hex := PackedVector2Array()
		for i in range(7):
			var a := TAU * float(i) / 6.0 - PI / 2.0
			hex.append(Vector2(cos(a), sin(a)) * R)
		draw_colored_polygon(hex, Color(SKY.r, SKY.g, SKY.b, 0.16))
		draw_polyline(hex, Color(SKY.r, SKY.g, SKY.b, 0.95), 6.0, true)
		draw_arc(Vector2.ZERO, R * 0.92, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 2.5)
		# white spark glint at the rim
		draw_circle(Vector2(-R * 0.55, -R * 0.55), 6.0, Color(1, 1, 1, 0.95))
	func shrink_pop() -> void:
		set_process(false)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "modulate:a", 0.0, 0.16)
		tw.chain().tween_callback(queue_free)

## Black Hole: swirling purple vortex disc centered on the channeler (spec 3.6).
class Vortex:
	extends Node2D
	func _ready() -> void:
		z_index = 13
		scale = Vector2(0.2, 0.2)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	func _process(delta: float) -> void:
		rotation -= delta * 5.5
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 58.0, Color(0.12, 0.05, 0.2, 0.75))
		draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 48, Color(0.85, 0.6, 1.0, 0.9), 5.0)   # accretion ring
		# three spiral arms (partial arcs at stepped radii read as a swirl while rotating)
		for i in range(3):
			var off := TAU * float(i) / 3.0
			draw_arc(Vector2.ZERO, 22.0 + 12.0 * float(i), off, off + 2.4, 20, Color(0.7, 0.45, 1.0, 0.8), 4.5)
