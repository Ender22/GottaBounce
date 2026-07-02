class_name PowerupSpawnDirector
extends Node
## Powerup spawn pacing (spec §4). First telegraph pu_first_spawn after "BOUNCE!"; each later
## telegraph starts pu_spawn_interval after the previous BUBBLE went live. Field cap
## pu_max_on_field (skips its beat at cap; uncollected bubbles never despawn). Placement:
## random `powerup_spawner` point from the level JSON, never the same point back-to-back.
## Drop roll: PowerupSystem weights, never the same id twice in a row. Sudden death stops
## spawning and pops live bubbles; ROUND_END clears the whole field.
## Owned by the match mode: reset() at round start, on_sudden_death(), clear_field().

const BUBBLE_PATH := "res://src/entities/PowerupBubble.gd"
const SPARKLE_TEX := "res://assets/fx/star_sparkle.png"
const CAP_RETRY := 0.5   # s between cap re-checks once a beat has been skipped

var arena = null            # match mode: reads arena.state ("COMBAT" gates the clock)
var points: Array = []      # Vector2 spawner positions from the level JSON
var _timer := 0.0           # time until the next telegraph starts
var _stopped := true        # true outside COMBAT / after sudden death
var _last_point := -1
var _last_id := ""
var _telegraph: CPUParticles2D = null
var _telegraph_t := 0.0
var _pending_point := -1

func setup(arena_ref, spawn_points: Array) -> void:
	arena = arena_ref
	points = spawn_points
	if points.is_empty():
		push_warning("PowerupSpawnDirector: level has no powerup_spawner objects — spawning disabled")

## Round start (called at BOUNCE!): fresh clock, spawning armed.
func reset() -> void:
	_timer = Tuning.pu_first_spawn
	_stopped = points.is_empty()
	_cancel_telegraph()

## Sudden death (spec §4): spawner off, live bubbles pop, mid-telegraph spawns cancelled.
func on_sudden_death() -> void:
	_stopped = true
	_cancel_telegraph()
	for b in get_tree().get_nodes_in_group("pu_bubble"):
		if b.has_method("pop"):
			b.pop()

## ROUND_END sweep is PowerupSystem.round_sweep() (frees group pu_field); we just disarm.
func stop() -> void:
	_stopped = true
	_cancel_telegraph()

func _physics_process(delta: float) -> void:
	if _stopped or arena == null or str(arena.state) != "COMBAT":
		return
	# telegraph in progress → bubble goes live when it finishes
	if _telegraph != null:
		_telegraph_t -= delta
		if _telegraph_t <= 0.0:
			_spawn_bubble()
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if _bubble_count() >= Tuning.pu_max_on_field:
		_timer = CAP_RETRY   # at cap: skip the beat, re-check shortly (spec §4)
		return
	_start_telegraph()

func _bubble_count() -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group("pu_bubble"):
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			n += 1
	return n

## 1.0s of converging sparkles at the spawn point — the starting gun for the scramble (spec §2).
func _start_telegraph() -> void:
	_pending_point = _pick_point()
	if _pending_point < 0:
		_stopped = true
		return
	var pos: Vector2 = points[_pending_point]
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.amount = 30
	p.lifetime = 0.45
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 150.0
	p.direction = Vector2.ZERO
	p.spread = 0.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.radial_accel_min = -1500.0
	p.radial_accel_max = -2100.0
	if ResourceLoader.exists(SPARKLE_TEX):
		p.texture = load(SPARKLE_TEX)
		p.scale_amount_min = 0.16
		p.scale_amount_max = 0.3
	else:
		p.scale_amount_min = 2.0
		p.scale_amount_max = 3.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.55, 0.0))
	grad.add_point(0.35, Color(1.0, 0.92, 0.5, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 0.9, 1.0))
	p.color_ramp = grad
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	p.add_to_group("pu_field")
	p.z_index = 11
	arena.add_child(p)
	_telegraph = p
	_telegraph_t = Tuning.pu_spawn_telegraph

func _spawn_bubble() -> void:
	var pos: Vector2 = points[_pending_point]
	_last_point = _pending_point
	_cancel_telegraph()
	var id: String = PowerupSystem.roll_id(_last_id)   # anti-repeat (spec §4)
	_last_id = id
	var bubble = load(BUBBLE_PATH).new()
	bubble.id = id
	bubble.position = pos
	arena.add_child(bubble)
	# next telegraph starts pu_spawn_interval after THIS bubble went live (spec §4)
	_timer = Tuning.pu_spawn_interval

func _cancel_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null
	_pending_point = -1

## Random spawner point, excluding the most recently used one (unless there's only one).
func _pick_point() -> int:
	if points.is_empty():
		return -1
	if points.size() == 1:
		return 0
	var idx := randi() % points.size()
	while idx == _last_point:
		idx = randi() % points.size()
	return idx
