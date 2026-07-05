extends Control
## Compact stepper (frontend_ux_spec §2.3.4): a title + a [ <  VALUE  > ] row with two chip buttons.
## Left/Right (D-pad/stick/arrows) or the chips step the value with a knob-bounce; a clamped edge does
## a red micro-shake instead. Focusable as a whole; the owning screen connects `changed`.

signal changed(index: int, value: Variant)

@onready var _title: Label = $VBox/Title
@onready var _value: Label = $VBox/Row/Value
@onready var _minus: Button = $VBox/Row/Minus
@onready var _plus: Button = $VBox/Row/Plus

var labels: Array = []
var vals: Array = []
var index := 0

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
