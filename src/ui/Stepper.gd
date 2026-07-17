extends Control
## Compact stepper (frontend_ux_spec §2.3.4): a title + a [ <  VALUE  > ] row with two chip buttons.
## Left/Right (D-pad/stick/arrows) or the chips step the value with a knob-bounce; a clamped edge does
## a red micro-shake instead. Focusable as a whole; the owning screen connects `changed`.
##
## FOCUS TREATMENT (owner 2026-07-16: the settings tray read as "terrible" and pad focus was
## INVISIBLE on it — accepts died silently): every stepper now carries its own plate; the focused
## stepper lights up (accent border + brightened chips + value pop) so a controller user always sees
## where they are. Accept on a focused stepper emits `accepted` (the owning screen decides — e.g.
## CharacterSelect hops focus back to the hero grid, or launches when all humans are locked).

signal changed(index: int, value: Variant)
signal accepted

const CHOCO := Color(0.231373, 0.141176, 0.105882)

@onready var _vbox: VBoxContainer = $VBox
@onready var _title: Label = $VBox/Title
@onready var _value: Label = $VBox/Row/Value
@onready var _minus: Button = $VBox/Row/Minus
@onready var _plus: Button = $VBox/Row/Plus

var labels: Array = []
var vals: Array = []
var index := 0
var accent: Color = Color("#ffd23f")   # focus accent (owning screen may set per-stepper)

var _plate: Panel
var _sb_idle: StyleBoxFlat
var _sb_focus: StyleBoxFlat

## Content-fit width (audit P3 type pass): the root is a plain Control, so it must surface its VBox's
## minimum size for the owning HBox to lay steppers out side by side.
func _get_minimum_size() -> Vector2:
	var v := get_node_or_null("VBox")
	if v == null:
		return Vector2(0, 104)
	var m: Vector2 = (v as Control).get_combined_minimum_size()
	return Vector2(m.x + 20.0, maxf(m.y + 12.0, 104.0))

func _ready() -> void:
	_vbox.minimum_size_changed.connect(update_minimum_size)
	# focus plate: built here (not the theme) so the stepper is self-contained; idle = a quiet
	# rounded chip that makes the control READ as a control, focus = accent ring + lift.
	_sb_idle = StyleBoxFlat.new()
	_sb_idle.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	_sb_idle.set_border_width_all(2)
	_sb_idle.border_color = Color(1.0, 1.0, 1.0, 0.10)
	_sb_idle.set_corner_radius_all(14)
	_sb_focus = StyleBoxFlat.new()
	_sb_focus.bg_color = Color(1.0, 1.0, 1.0, 0.14)
	_sb_focus.set_border_width_all(4)
	_sb_focus.border_color = accent
	_sb_focus.set_corner_radius_all(14)
	_plate = Panel.new()
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override("panel", _sb_idle)
	add_child(_plate)
	move_child(_plate, 0)
	focus_entered.connect(_on_focus_in)
	focus_exited.connect(_on_focus_out)

func _on_focus_in() -> void:
	_sb_focus.border_color = accent
	_plate.add_theme_stylebox_override("panel", _sb_focus)
	_minus.modulate = Color(1.25, 1.25, 1.25)
	_plus.modulate = Color(1.25, 1.25, 1.25)
	MenuFX.value_pop(_value)

func _on_focus_out() -> void:
	_plate.add_theme_stylebox_override("panel", _sb_idle)
	_minus.modulate = Color.WHITE
	_plus.modulate = Color.WHITE

func configure(title: String, labels_: Array, vals_: Array, start_index: int) -> void:
	labels = labels_
	vals = vals_
	index = clampi(start_index, 0, labels.size() - 1)
	_title.text = title
	_refresh()
	if not _minus.pressed.is_connected(_on_minus):
		_minus.pressed.connect(_on_minus)
		_plus.pressed.connect(_on_plus)

func value() -> Variant:
	return vals[index]

func set_index(i: int) -> void:
	index = clampi(i, 0, labels.size() - 1)
	_refresh()

func _on_minus() -> void:
	step(-1)

func _on_plus() -> void:
	step(1)

func step(d: int) -> void:
	var ni := clampi(index + d, 0, labels.size() - 1)
	if ni == index:
		MenuFX.reject_shake(self)
		AudioManager.play_sfx("ui_click", {"pitch": 0.6, "volume_db": -6.0})
		return
	index = ni
	_refresh()
	MenuFX.value_pop(_value)
	AudioManager.play_sfx("ui_click")
	changed.emit(index, value())

func _refresh() -> void:
	_value.text = str(labels[index])

func _gui_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		step(-1)
		accept_event()
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		step(1)
		accept_event()
	elif e.is_action_pressed("ui_accept") or e.is_action_pressed("menu_accept"):
		# A on a stepper must never die silently (couch playtest 2026-07-16): hand the press to the
		# owning screen (hop back to the pick grid / launch when everyone is locked).
		accepted.emit()
		accept_event()
