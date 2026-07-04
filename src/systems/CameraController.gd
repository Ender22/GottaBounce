class_name CameraController
extends Camera2D
## Camera. Default: locked (only trauma shake). Party sets `dynamic = true` and feeds a frame each
## tick via set_frame(center, zoom) — it lerps toward that so it follows the action and zooms out to
## keep everyone on screen (Smash-style). Campaign/Training keep dynamic = false and drive position
## directly. Shake is applied on top via `offset` regardless of mode.

var dynamic := false
# fps-independent smoothing rates (1 - exp(-k*dt); Freya Holmer). Higher k == snappier.
var follow_speed := 6.0        # pan (position) rate — symmetric
# Asymmetric zoom damping (Smash signature): widen the view (zoom value DECREASES) FAST so a
# spread never clips a flier; tighten the view (zoom value INCREASES) SLOW so transient spreads
# don't snap-in-then-back = the "breathing pump".
var zoom_out_speed := 9.0      # view widening (target zoom < current) — fast
var zoom_in_speed := 3.0       # view tightening (target zoom > current) — slow
# Zoom dead-zone: ignore sub-threshold target changes so per-frame extent wiggle can't drive the
# zoom. In Godot zoom units (0.60..0.92 range), ~0.012 ~= 2% of the working band.
var zoom_deadzone := 0.012
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
	# Dead-zone: only shift the zoom goal when the incoming target moves beyond a small band, so
	# tiny frame-to-frame extent jitter leaves the zoom target parked.
	if absf(z - _target_zoom) > zoom_deadzone:
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
		# fps-independent exponential smoothing (no overshoot): fraction = 1 - exp(-k*dt).
		var tp := 1.0 - exp(-follow_speed * delta)
		position = position.lerp(_target_pos, tp)
		# asymmetric zoom: target below current == view widening (zoom out) == fast rate.
		var kz := zoom_out_speed if _target_zoom < _cur_zoom else zoom_in_speed
		var tz := 1.0 - exp(-kz * delta)
		_cur_zoom = lerpf(_cur_zoom, _target_zoom, tz)
		zoom = Vector2(_cur_zoom, _cur_zoom)
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - Tuning.trauma_decay * delta)
		var amt := _trauma * _trauma
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * Tuning.shake_max_offset * amt
	else:
		offset = Vector2.ZERO
