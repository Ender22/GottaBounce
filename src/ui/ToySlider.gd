extends Control
## Options toy slider row (frontend_ux_spec §2.5 / visual_brief §5). WK-34 Toybox panel kit A: the row sits in a
## ToyRow well on the cream plate (chocolate TextDark label + value), the track is a light chocolate-rimmed well
## (ToyBarTrack) with an accent-colour fill and a cream knob. Focus (CC-5.1) = a full well swap to ToyRowFocus
## (gold fill + 6 px gold rim) + the row's 1.04 scale (MenuScreen.register) + the knob growing 1.15x.
## Left/Right nudge 5% with a knob-bounce; clamped edge micro-shakes. Never an OS slider.

signal changed(value: float)

const FILL_INSET := 5.0      # px: fill sits inside the track's 3 px rim with a 2 px gap
const KNOB := 44.0

@onready var _well: PanelContainer = $Well
@onready var _label: Label = $HBox/Label
@onready var _area: Control = $HBox/SliderArea
@onready var _track: Panel = $HBox/SliderArea/Track
@onready var _fill: Panel = $HBox/SliderArea/Fill
@onready var _knob: Panel = $HBox/SliderArea/Knob
@onready var _value: Label = $HBox/Value

var value := 1.0
var accent := Color("#ff5fa8")
var focus_active := false    # QA readout

func setup(title: String, v: float, ac: Color) -> void:
	_label.text = title
	value = clampf(v, 0.0, 1.0)
	set_accent(ac)
	if not _area.resized.is_connected(_refresh):
		_area.resized.connect(_refresh)
	call_deferred("_refresh")

func set_accent(ac: Color) -> void:
	accent = ac
	_fill.self_modulate = accent

func set_focus_active(on: bool) -> void:
	focus_active = on
	_well.theme_type_variation = &"ToyRowFocus" if on else &"ToyRow"
	_knob.pivot_offset = _knob.size * 0.5
	var t := _knob.create_tween()
	t.tween_property(_knob, "scale", Vector2(1.15, 1.15) if on else Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## WK-46: quiet = an auto-repeat of a held direction; at the end of the range it stops without the deny shake.
func step(d: int, quiet := false) -> void:
	var nv := clampf(value + d * 0.05, 0.0, 1.0)
	if is_equal_approx(nv, value):
		if quiet:
			return
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
	_track.position = Vector2(0, cy - 14)
	_track.size = Vector2(w, 28)
	var inner: float = w - FILL_INSET * 2.0
	_fill.position = Vector2(FILL_INSET, cy - 9)
	_fill.size = Vector2(maxf(18.0, inner * value), 18)
	_fill.visible = value > 0.0
	_knob.size = Vector2(KNOB, KNOB)
	_knob.pivot_offset = _knob.size * 0.5
	_knob.position = Vector2(clampf(w * value - KNOB * 0.5, -6.0, w - KNOB + 6.0), cy - KNOB * 0.5)
	_value.text = "%d%%" % int(round(value * 100.0))

func _gui_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		step(-1, InputRouter.is_repeat(e))   # WK-46
		accept_event()
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		step(1, InputRouter.is_repeat(e))   # WK-46
		accept_event()
