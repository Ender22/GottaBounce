extends Control
## Options toy pill toggle (frontend_ux_spec §2.5 / visual_brief §5): a rounded pill, cream knob slides
## left(OFF)/right(ON) with a BACK pop; ON fills P3 green, OFF fills faint chocolate. Never a checkbox.

signal changed(on: bool)

const GREEN := Color(0.329412, 0.788235, 0.290196, 1)
const OFF_FILL := Color(0.231373, 0.141176, 0.105882, 0.25)

@onready var _bar: ColorRect = $AccentBar
@onready var _label: Label = $HBox/Label
@onready var _track: Panel = $HBox/Pill/Track
@onready var _knob: Panel = $HBox/Pill/Track/Knob

var on := false
var accent := Color("#ff5fa8")

func setup(title: String, b: bool, ac: Color) -> void:
	_label.text = title
	on = b
	accent = ac
	call_deferred("_refresh", false)

func set_focus_active(active: bool) -> void:
	_bar.color = Color(accent.r, accent.g, accent.b, 1.0 if active else 0.0)

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
	var sb := StyleBoxFlat.new()
	sb.bg_color = GREEN if on else OFF_FILL
	sb.border_color = MenuFX.CHOCO
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(20)
	_track.add_theme_stylebox_override("panel", sb)
	var kx: float = 36.0 if on else 4.0
	if anim:
		var t := _knob.create_tween()
		t.tween_property(_knob, "position:x", kx, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
