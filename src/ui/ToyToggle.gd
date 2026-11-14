extends Control
## Options toy pill toggle (frontend_ux_spec §2.5 / visual_brief §5): a rounded pill, cream knob slides
## left(OFF)/right(ON) with a BACK pop; ON fills P3 green, OFF a warm grey. Never a checkbox.
## WK-34 Toybox panel kit A: same ToyRow well + chocolate TextDark label as ToySlider, a 36 px ON/OFF word beside
## the pill (the state reads without decoding the knob side), focus = the ToyRowFocus well swap (CC-5.1).

signal changed(on: bool)

const GREEN := Color(0.329412, 0.788235, 0.290196, 1)
## OFF track: a visible warm-grey pill — the 4 px chocolate border + cream knob read against it on the cream plate.
const OFF_FILL := Color(0.792157, 0.768627, 0.729412, 1)
const KNOB_OFF_X := 6.0
const KNOB_ON_X := 50.0

@onready var _well: PanelContainer = $Well
@onready var _label: Label = $HBox/Label
@onready var _state: Label = $HBox/State
@onready var _track: Panel = $HBox/Pill/Track
@onready var _knob: Panel = $HBox/Pill/Track/Knob

var on := false
var accent := Color("#ff5fa8")
var focus_active := false    # QA readout

func setup(title: String, b: bool, ac: Color) -> void:
	_label.text = title
	on = b
	accent = ac
	call_deferred("_refresh", false)

func set_accent(ac: Color) -> void:
	accent = ac

func set_focus_active(active: bool) -> void:
	focus_active = active
	_well.theme_type_variation = &"ToyRowFocus" if active else &"ToyRow"

func toggle() -> void:
	on = not on
	_refresh(true)
	AudioManager.play_sfx("ui_click")
	changed.emit(on)

func set_on(v: bool) -> void:
	if v == on:
		return
	toggle()

func _refresh(anim: bool) -> void:
	var base: StyleBox = _track.get_theme_stylebox("panel")
	var sb: StyleBoxFlat = (base as StyleBoxFlat).duplicate() if base is StyleBoxFlat else StyleBoxFlat.new()
	sb.bg_color = GREEN if on else OFF_FILL
	sb.border_color = MenuFX.CHOCO
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(26)
	_track.add_theme_stylebox_override("panel", sb)
	_state.text = "ON" if on else "OFF"
	var kx: float = KNOB_ON_X if on else KNOB_OFF_X
	if anim:
		var t := _knob.create_tween()
		t.tween_property(_knob, "position:x", kx, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		MenuFX.value_pop(_state, 1.15)
	else:
		_knob.position.x = kx

func _gui_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		set_on(false)
		accept_event()
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		set_on(true)
		accept_event()
	elif e.is_action_pressed("ui_accept") or e.is_action_pressed("menu_accept"):
		toggle()
		accept_event()
