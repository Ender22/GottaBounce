class_name CameraController
extends Camera2D
## Camera. Default: locked (only trauma shake). Party sets `dynamic = true` and feeds a frame each
## tick via set_frame(center, zoom) — it lerps toward that so it follows the action and zooms out to
## keep everyone on screen (Smash-style). Campaign/Training keep dynamic = false and drive position
## directly. Shake is applied on top via `offset` regardless of mode.

var dynamic := false
var follow_speed := 6.0
var _target_pos := Vector2(960, 540)
var _target_zoom := 1.0
var _cur_zoom := 1.0
var _trauma := 0.0

func _ready() -> void:
	make_current()
	_cur_zoom = zoom.x
	_target_pos = position

func set_frame(center: Vector2, z: float) -> void:
	_target_pos = center
	_target_zoom = z

func snap_to(center: Vector2, z: float) -> void:
	_target_pos = center
	_target_zoom = z
	_cur_zoom = z
	position = center
	zoom = Vector2(z, z)

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if dynamic:
		var t := clampf(follow_speed * delta, 0.0, 1.0)
		position = position.lerp(_target_pos, t)
		_cur_zoom = lerpf(_cur_zoom, _target_zoom, t)
		zoom = Vector2(_cur_zoom, _cur_zoom)
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - Tuning.trauma_decay * delta)
		var amt := _trauma * _trauma
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * Tuning.shake_max_offset * amt
	else:
		offset = Vector2.ZERO
