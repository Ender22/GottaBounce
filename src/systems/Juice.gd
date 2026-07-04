class_name Juice
extends Node
## Presentation layer (INV-12): subscribes to events and adds shake / hitstop / rumble / flash.
## Owns no sim state. FEEL §5.
##
## v0 port note: particle textures + ring/flash sprites are not ported yet (art pipeline later) —
## bursts use textureless particles (scaled up to stay visible); texture-only effects are skipped
## via the ResourceLoader.exists guards. SaveSystem isn't ported: shake/rumble default ON.

var _camera: CameraController
var _in_hitstop := false

func setup(cam: CameraController) -> void:
	_camera = cam
	EventBus.smashed.connect(_on_smashed)
	EventBus.bounced_juicy.connect(_on_bounced)
	EventBus.super_boosted.connect(_on_super)
	EventBus.exploded.connect(_on_exploded)
	EventBus.hazard_shoved.connect(_on_hazard_shoved)
	KillPipeline.killed.connect(_on_killed)

func _on_exploded(center, radius) -> void:
	_shake(0.9)   # Heavy (FEEL §4.1)
	_rumble(1.0, 0.9, 0.18)
	_hitstop(0.9)
	_shockwave(center, radius)

## Moving-hazard SHOVE (v1_moving_hazard §1.4.4): a chunky metallic impact puff + light shake,
## DISTINCT from a smash — no death burst, no hitstun jetstream. Reads as "I got bumped, not smashed."
func _on_hazard_shoved(player, dir, magnitude) -> void:
	if player == null or not is_instance_valid(player):
		return
	var t := clampf(magnitude / Tuning.soft_bump_max, 0.0, 1.0)
	_shake(lerpf(0.12, 0.34, t))            # softer than a smash's 0.55
	_rumble(0.25 * t, 0.5 * t, 0.10)
	_shove_puff(player.global_position, dir, t)

## Metallic clang puff kicked along the shove direction (reuses the _dust_puff pattern, steel-tinted).
func _shove_puff(pos: Vector2, dir: Vector2, t: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.35
	p.spread = 42.0
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector2.UP
	p.gravity = Vector2(0, 500)
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 160.0 + 420.0 * t
	p.scale_amount_min = 2.2
	p.scale_amount_max = 4.2
	if ResourceLoader.exists(SPARK_TEX):
		p.texture = load(SPARK_TEX)
		p.scale_amount_min = 0.2
		p.scale_amount_max = 0.4
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.9, 0.7, 0.85))   # warm metallic spark
	grad.set_color(1, Color(0.6, 0.6, 0.66, 0.0))
	p.color_ramp = grad
	scene.add_child(p)
	scene.get_tree().create_timer(0.8).timeout.connect(p.queue_free)

func _on_smashed(_attacker, victim, impulse) -> void:
	_shake(0.55)
	if victim != null and is_instance_valid(victim) and victim.has_method("flash"):
		victim.flash()
	_rumble(0.9, 0.8, 0.10)
	_hitstop(clampf(impulse.length() / Tuning.super_boost_impulse_full, 0.0, 1.0))

## Bounce juice: shake + (on big launches) a light rumble + a small dust puff at the contact point,
## all scaled by how hard you launched off the surface.
func _on_bounced(body, launch_speed, contact_point) -> void:
	var t := clampf(launch_speed / 1240.0, 0.0, 1.0)   # 1240 ~= spring-tier launch
	_shake(lerpf(0.08, 0.3, t))
	if t > 0.25:
		_rumble(0.3 * t, 0.5 * t, 0.08)
	_dust_puff(contact_point, t)

## Cheap one-shot grey-white dust kick at a bounce contact (reuses the _death_burst pattern).
func _dust_puff(pos: Vector2, t: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 10
	p.lifetime = 0.4
	p.spread = 70.0
	p.direction = Vector2.UP            # kick up/outward away from the ground
	p.gravity = Vector2(0, 600)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 90.0 + 260.0 * t
	p.scale_amount_min = 2.0            # textureless in v0: scaled up from sprite-based 0.18/0.34
	p.scale_amount_max = 3.6
	if ResourceLoader.exists(SPARK_TEX):
		p.texture = load(SPARK_TEX)
		p.scale_amount_min = 0.18
		p.scale_amount_max = 0.34
	var grad := Gradient.new()
	grad.set_color(0, Color(0.92, 0.92, 0.95, 0.7))
	grad.set_color(1, Color(0.75, 0.76, 0.8, 0.0))
	p.color_ramp = grad
	scene.add_child(p)
	scene.get_tree().create_timer(0.8).timeout.connect(p.queue_free)

func _on_super(player) -> void:
	_shake(0.7)
	_rumble(1.0, 0.95, 0.25)
	_hitstop(0.7)
	if player != null and is_instance_valid(player):
		var aim := Vector2.UP
		if player.has_method("get_aim"):
			aim = player.get_aim()
		_super_blast(player.global_position, aim)

const FIRE_TEX := "res://assets/particles/fire_01.png"
const MUZZLE_TEX := "res://assets/particles/muzzle_01.png"

## Big violent kick when a fighter super-boosts: a fire cone blasting out the back + a flash + ring.
func _super_blast(pos: Vector2, aim: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var back: Vector2 = -aim                       # exhaust shoots opposite travel
	var nozzle: Vector2 = pos + back * 34.0
	# fire cone
	var p := CPUParticles2D.new()
	p.global_position = nozzle
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 64                       # §4-P2: bolder than the §1 boost tongue — a one-shot cannon
	p.lifetime = 0.5
	p.direction = back
	p.spread = 34.0                     # tighter -> reads as a violent directional JET, not a puff
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 620.0
	p.initial_velocity_max = 1250.0
	p.damping_min = 400.0
	p.damping_max = 900.0
	p.scale_amount_min = 4.0            # textureless in v0: scaled up from sprite-based 0.45/0.9
	p.scale_amount_max = 8.0
	if ResourceLoader.exists(FIRE_TEX):
		p.texture = load(FIRE_TEX)
		p.scale_amount_min = 0.45
		p.scale_amount_max = 0.9
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.85, 1.0))
	grad.add_point(0.35, Color(1.0, 0.65, 0.15, 1.0))
	grad.set_color(1, Color(0.95, 0.25, 0.05, 0.0))
	p.color_ramp = grad
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	scene.add_child(p)
	scene.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	# bright muzzle flash at the nozzle (texture-only effect — returns with art)
	var flash_tex := MUZZLE_TEX if ResourceLoader.exists(MUZZLE_TEX) else FIRE_TEX
	if ResourceLoader.exists(flash_tex):
		var fl := Sprite2D.new()
		fl.texture = load(flash_tex)
		fl.global_position = nozzle
		fl.rotation = back.angle()
		fl.modulate = Color(1.0, 0.95, 0.7, 1.0)
		var fm := CanvasItemMaterial.new()
		fm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		fl.material = fm
		fl.scale = Vector2(0.6, 0.6)
		scene.add_child(fl)
		var tw := fl.create_tween().set_parallel(true)
		tw.tween_property(fl, "scale", Vector2(2.4, 1.8), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(fl, "modulate:a", 0.0, 0.22)
		tw.chain().tween_callback(fl.queue_free)
	# shockwave ring at the body (texture-only effect — returns with art)
	if ResourceLoader.exists(RING_TEX):
		var ring := Sprite2D.new()
		ring.texture = load(RING_TEX)
		ring.global_position = pos
		ring.modulate = Color(1.0, 0.9, 0.6, 0.85)
		var rm := CanvasItemMaterial.new()
		rm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ring.material = rm
		ring.scale = Vector2(0.25, 0.25)
		scene.add_child(ring)
		var tw2 := ring.create_tween().set_parallel(true)
		tw2.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_property(ring, "modulate:a", 0.0, 0.32)
		tw2.chain().tween_callback(ring.queue_free)

const SPARK_TEX := "res://assets/particles/spark_01.png"
const RING_TEX := "res://assets/particles/light_01.png"

func _on_killed(victim, _cause, _attacker) -> void:
	_shake(0.7)
	_rumble(1.0, 0.9, 0.18)
	_hitstop(1.0)
	if victim != null and is_instance_valid(victim):
		_death_burst(victim.global_position)

## Smash-Bros-style blast at the spot a fighter died.
func _death_burst(pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	# radial sparks
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 40
	p.lifetime = 0.6
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2(0, 900)
	p.initial_velocity_min = 320.0
	p.initial_velocity_max = 820.0
	p.scale_amount_min = 2.6            # textureless in v0: scaled up from sprite-based 0.3/0.6
	p.scale_amount_max = 5.2
	if ResourceLoader.exists(SPARK_TEX):
		p.texture = load(SPARK_TEX)
		p.scale_amount_min = 0.3
		p.scale_amount_max = 0.6
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.7, 1.0))
	grad.add_point(0.4, Color(1.0, 0.6, 0.15, 1.0))
	grad.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	p.color_ramp = grad
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	scene.add_child(p)
	# expanding shockwave ring (texture-only effect — returns with art)
	if ResourceLoader.exists(RING_TEX):
		var ring := Sprite2D.new()
		ring.texture = load(RING_TEX)
		ring.global_position = pos
		ring.modulate = Color(1.0, 0.95, 0.7, 0.9)
		var rm := CanvasItemMaterial.new()
		rm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ring.material = rm
		ring.scale = Vector2(0.3, 0.3)
		scene.add_child(ring)
		var tw := ring.create_tween().set_parallel(true)
		tw.tween_property(ring, "scale", Vector2(5.0, 5.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(ring.queue_free)
	# clean up the particles after they finish
	var t := scene.get_tree().create_timer(1.2)
	t.timeout.connect(p.queue_free)

func _shake(amt: float) -> void:
	# v0: SaveSystem/settings not ported yet — shake always on.
	if _camera:
		_camera.add_trauma(amt)

func _rumble(weak: float, strong: float, dur: float) -> void:
	# v0: SaveSystem/settings not ported yet — rumble always on.
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, weak, strong, dur)

func _hitstop(strength: float = 0.5) -> void:
	if _in_hitstop:
		return
	_in_hitstop = true
	strength = clampf(strength, 0.0, 1.0)
	var frozen_ts := lerpf(0.12, 0.04, strength)   # lighter hits freeze less deep
	var dur := lerpf(0.03, 0.10, strength)
	Engine.time_scale = frozen_ts
	# real-time timer (ignore_time_scale) so the freeze lasts a real beat (FEEL §5.1)
	await get_tree().create_timer(dur, true, false, true).timeout
	# ease back to full speed over hitstop_recover via chained REAL-TIME timers
	# (a Tween would run on scaled time and stall during the freeze).
	for i in range(3):
		Engine.time_scale = lerpf(frozen_ts, 1.0, float(i + 1) / 3.0)
		await get_tree().create_timer(Tuning.hitstop_recover / 3.0, true, false, true).timeout
	Engine.time_scale = 1.0
	_in_hitstop = false

func _exit_tree() -> void:
	# Defensive: if this Juice is freed mid-hitstop (e.g. scene change during the await),
	# make sure we don't leave the whole game stuck in slow-mo.
	Engine.time_scale = 1.0


## Visible expanding blast ring sized to the real impulse radius, so explosions / boss attacks are
## telegraphed on screen instead of being invisible knockback. (Texture-only — returns with art.)
func _shockwave(center: Vector2, radius: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not ResourceLoader.exists(RING_TEX):
		return
	var tex: Texture2D = load(RING_TEX)
	var ring := Sprite2D.new()
	ring.texture = tex
	ring.global_position = center
	ring.modulate = Color(1.0, 0.45, 0.25, 0.9)
	var cmat := CanvasItemMaterial.new()
	cmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = cmat
	var target := (radius + radius) / maxf(1.0, float(tex.get_width()))
	ring.scale = Vector2(target, target) * 0.25
	scene.add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(target, target), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(ring.queue_free)
