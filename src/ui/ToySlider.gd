extends Control
## Options toy slider row (frontend_ux_spec §2.5 / visual_brief §5): chunky chocolate-outlined track +
## white fill + a big knob, with a numeric %. Whole-row focus (accent left bar + fill/knob turn accent
## + knob scales). Left/Right nudge 5% with a knob-bounce; clamped edge micro-shakes. Never an OS slider.

signal changed(value: float)

@onready var _bar: ColorRect = $AccentBar
@onready var _label: Label = $HBox/Label
@onready var _area: Control = $HBox/SliderArea
@onready var _track: Panel = $HBox/SliderArea/Track
@onready var _fill: Panel = $HBox/SliderArea/Fill
@onready var _knob: Panel = $HBox/SliderArea/Knob
@onready var _value: Label = $HBox/Value

var value := 1.0
var accent := Color("#ff5fa8")

func setup(title: String, v: float, ac: Color) -> void:
	_label.text = title
	value = clampf(v, 0.0, 1.0)
	accent = ac
	if not _area.resized.is_connected(_refresh):
		_area.resized.connect(_refresh)
	call_deferred("_refresh")

func set_focus_active(on: bool) -> void:
	_bar.color = Color(accent.r, accent.g, accent.b, 1.0 if on else 0.0)
	_fill.self_modulate = accent if on else Color.WHITE
	_knob.self_modulate = accent if on else Color.WHITE
	_knob.pivot_offset = _knob.size * 0.5
	var t := _knob.create_tween()
	t.tween_property(_knob, "scale", Vector2(1.15, 1.15) if on else Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func step(d: int) -> void:
	var nv := clampf(value + d * 0.05, 0.0, 1.0)
	if is_equal_approx(nv, value):
		MenuFX.reject_shake(_knob)
		AudioManager.play_sfx("ui_click", {"pitch": 0.6, "volume_db": -6.0})
		return
	value = nv
	_refresh()
	MenuFX.value_pop(_knob, 1.15)
	AudioManager.play_sfx("ui_click")
	changed.emit(value)

func _refresh() -> void:
	var w: float = _area.size.x
	var h: float = _area.size.y
	var cy: float = h * 0.5
	_track.position = Vector2(0, cy - 8)
	_track.size = Vector2(w, 16)
	_fill.position = Vector2(0, cy - 8)
	_fill.size = Vector2(maxf(16.0, w * value), 16)
	_knob.size = Vector2(36, 36)
	_knob.position = Vector2(clampf(w * value - 18, -6, w - 30), cy - 18)
	_value.text = "%d%%" % int(round(value * 100.0))

func _gui_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		step(-1)
		accept_event()
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		step(1)
		accept_event()
