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
	EventBus.ball_struck.connect(_on_ball_struck)   # WK-105 sports strike juice

## WK-105 (SP-01): only the POWER SHOT (super-active / hitstun striker) gets a hit-stop beat (~60 ms at
## strength 0.45 via the shared _hitstop curve), a light camera kick and a rumble tap — normal touches
## stay fluid (the ball's own squash/flash/sparks carry them). WK-90 re-measures the hitstop curve.
func _on_ball_struck(_ball, _player, _impact, is_power) -> void:
	if not bool(is_power):
		return
	_hitstop(0.45)
	_shake(0.3)
	_rumble(0.6, 0.5, 0.12)

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

func _on_smashed(attacker, victim, impulse) -> void:
	_shake(0.55)
	if victim != null and is_instance_valid(victim) and victim.has_method("flash"):
		victim.flash()
	_rumble(0.9, 0.8, 0.10)
	_hitstop(clampf(impulse.length() / Tuning.super_boost_impulse_full, 0.0, 1.0))
	# WK-24 (D-06): the impact burst wears the ATTACKER's identity colour. `attacker` here is already the
	# CREDITED one (Player emits smashed with attacker_for_credit: chain hits = the launcher).
	if victim != null and is_instance_valid(victim):
		var dir: Vector2 = impulse.normalized() if impulse.length() > 0.01 else Vector2.UP
		var z: float = _camera.zoom.x if (_camera != null and _camera.zoom.x > 0.001) else 1.0
		var back: float = Player.BODY_RADIUS + Tuning.hit_burst_offset * Tuning.hit_burst_screen_px / z
		_hit_burst(victim.global_position - dir * back, dir, _identity_color(attacker))

const KO_CORE_TEX := "res://assets/fx/ko_blast_core.png"
const FX_TINT_SHADER := "res://assets/shaders/fx_tint.gdshader"
var _fx_tint_mat: ShaderMaterial = null

## Identity colour of a fighter (WK-08 player_color via Player.identity_color), white when unknown.
func _identity_color(p) -> Color:
	if p != null and is_instance_valid(p) and p.has_method("identity_color"):
		var c: Color = p.identity_color()
		return c
	return Color.WHITE

## Shared gradient-map tint material (fx_tint.gdshader): colour = the sprite's self_modulate.
func _tint_material() -> ShaderMaterial:
	if _fx_tint_mat == null and ResourceLoader.exists(FX_TINT_SHADER):
		_fx_tint_mat = ShaderMaterial.new()
		_fx_tint_mat.shader = load(FX_TINT_SHADER)
	return _fx_tint_mat

## WK-24 impact burst: a chunky toybox starburst (the KO-blast core art, small) + a spray of sparks along
## the launch, both in the attacker's colour. Sized in SCREEN px (world = px / zoom) so it reads at every
## gameplay zoom. The starburst runs on the REAL clock (rendered QA: a hit-stop-held burst sat on top of
## the victim); the sparks stay on scaled time so the freeze still holds a spray.
func _hit_burst(pos: Vector2, dir: Vector2, col: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var z: float = _camera.zoom.x if (_camera != null and _camera.zoom.x > 0.001) else 1.0
	# sparks: attacker-coloured, sprayed along the impulse (normal blend keeps the hue honest)
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.z_index = 10
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(1, Tuning.hit_burst_sparks)
	p.lifetime = 0.35
	p.direction = dir
	p.spread = 55.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = Tuning.hit_burst_spark_speed * 0.4
	p.initial_velocity_max = Tuning.hit_burst_spark_speed
	p.damping_min = 900.0
	p.damping_max = 1600.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	if ResourceLoader.exists(SPARK_TEX):
		p.texture = load(SPARK_TEX)
		p.scale_amount_min = 0.35
		p.scale_amount_max = 0.7
	var bright: Color = col.lerp(Color.WHITE, 0.25)
	var grad := Gradient.new()
	grad.set_color(0, Color(bright.r, bright.g, bright.b, 1.0))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = grad
	scene.add_child(p)
	scene.get_tree().create_timer(0.9).timeout.connect(p.queue_free)
	# starburst (tinted greyscale art)
	if not ResourceLoader.exists(KO_CORE_TEX):
		return
	var tex: Texture2D = load(KO_CORE_TEX)
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.material = _tint_material()
	s.self_modulate = col
	s.global_position = pos
	s.rotation = randf_range(-0.35, 0.35)
	s.z_index = 11
	var k: float = Tuning.hit_burst_screen_px / maxf(1.0, float(tex.get_width())) / z
	s.scale = Vector2.ONE * k * 0.5
	scene.add_child(s)
	var t: float = maxf(0.05, Tuning.hit_burst_time)
	var tw := s.create_tween().set_ignore_time_scale(true)
	tw.tween_property(s, "scale", Vector2.ONE * k * 1.1, t * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ONE * k * 0.9, t * 0.7)
	tw.parallel().tween_property(s, "modulate:a", 0.0, t * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)

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
	# WK-121: SPORTS is a no-death mode (99 lives, instant respawn). A goat dropping through a Dropshot hole
	# / out of the court is a comedic beat, not a KO: no KO hit-stop (it froze the shared ball for everyone
	# on every hole fall), no Smash death blast, just a light camera tick + a sand "drop" puff at the hole.
	# An in-court hazard KO there keeps the burst with a light freeze until WK-112 turns hazards into stuns.
	if _sports_active():
		if _out_of_court(victim):
			_shake(0.12)
			_rumble(0.3, 0.0, 0.08)
			if victim != null and is_instance_valid(victim):
				_drop_puff(victim, _identity_color(victim))
			return
		_shake(0.4)
		_hitstop(0.3)
		if victim != null and is_instance_valid(victim):
			_death_burst(victim.global_position)
		return
	_shake(0.7)
	_rumble(1.0, 0.9, 0.18)
	_hitstop(1.0)
	if victim != null and is_instance_valid(victim):
		# v11 KO-POP flair: your own death burst in your equipped palette (P1-only; {} = stock)
		var fl: Dictionary = {}
		if victim.has_method("flair_ko_pop"):
			fl = victim.flair_ko_pop()
		_death_burst(victim.global_position, fl)

func _sports_active() -> bool:
	return not get_tree().get_nodes_in_group("sports_ball").is_empty()

## True when the victim left the running match's court bounds (fell through a hole / knocked out).
func _out_of_court(victim) -> bool:
	if victim == null or not is_instance_valid(victim) or not (victim is Node2D):
		return true
	var scene := get_tree().current_scene
	if scene == null or not ("bounds" in scene):
		return true
	var b: Rect2 = scene.bounds
	return not b.has_point((victim as Node2D).global_position)

## WK-121 sports "drop" puff: sand dust kicked UP out of the hole the goat fell through, plus a few specks in
## the goat's colour so you can tell WHO dropped. No ring, no star burst, no freeze. The kill fires at the
## bounds bottom (below the drawn court), so the puff is placed on the FLOOR LINE: the nearest Dropshot tile
## row's y (holes are missing tiles), else just inside the bounds. Sizes are world px at the whole-court zoom
## (~0.4), so they read at couch distance.
func _drop_puff(victim, col: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pos: Vector2 = (victim as Node2D).global_position
	if "bounds" in scene:
		var b: Rect2 = scene.bounds
		pos = Vector2(clampf(pos.x, b.position.x + 40.0, b.end.x - 40.0), minf(pos.y, b.end.y - 60.0))
	var best := INF
	for t in get_tree().get_nodes_in_group("drop_tile"):
		var d: float = absf((t as Node2D).global_position.x - pos.x)
		if d < best:
			best = d
			pos.y = (t as Node2D).global_position.y
	for layer in range(2):
		var p := CPUParticles2D.new()
		p.global_position = pos
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = 22 if layer == 0 else 10
		p.lifetime = 0.7 if layer == 0 else 0.55
		p.direction = Vector2.UP
		p.spread = 28.0 if layer == 0 else 40.0
		p.gravity = Vector2(0, 1100)
		p.initial_velocity_min = 380.0
		p.initial_velocity_max = 980.0 if layer == 0 else 760.0
		p.damping_min = 40.0
		p.damping_max = 120.0
		p.scale_amount_min = 14.0 if layer == 0 else 8.0
		p.scale_amount_max = 28.0 if layer == 0 else 14.0
		var grad := Gradient.new()
		if layer == 0:
			grad.set_color(0, Color(0.98, 0.92, 0.74, 0.95))   # sand (the Dropshot tile colour)
			grad.set_color(1, Color(0.85, 0.74, 0.52, 0.0))
		else:
			grad.set_color(0, Color(col.r, col.g, col.b, 1.0))
			grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
		p.color_ramp = grad
		p.z_index = 45
		scene.add_child(p)
		scene.get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## Smash-Bros-style blast at the spot a fighter died. `flair` (v11 §3) may swap the spark PALETTE
## (gradient stops + optional hue spread) — count/velocity/gravity/ring stay stock (cosmetic-only).
func _death_burst(pos: Vector2, flair: Dictionary = {}) -> void:
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
	# v11 flair palette override (gradient stops + hue spread are the ONLY deltas)
	var fparams: Dictionary = flair.get("params", {}) if not flair.is_empty() else {}
	var fstops: Array = fparams.get("stops", [])
	if fstops.size() >= 3:
		grad = Gradient.new()
		grad.set_color(0, _flair_stop(fstops[0]))
		grad.set_color(1, _flair_stop(fstops[2]))
		grad.add_point(0.4, _flair_stop(fstops[1]))
		var hv := absf(float(fparams.get("hue_variation", 0.0)))
		if hv > 0.0:
			p.hue_variation_min = -hv
			p.hue_variation_max = hv
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

## Parse a flair.json RGBA stop ([r,g,b,a]) into a Color; malformed -> white (never crash on data).
func _flair_stop(v: Variant) -> Color:
	var arr: Array = v if v is Array else []
	if arr.size() < 4:
		return Color.WHITE
	return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))

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
