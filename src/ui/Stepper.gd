extends Control
## Two-state stepper chip (owner ruling 2026-07-17, round 3 — "do like other games"): the tray is a
## HORIZONTAL strip you browse with LEFT/RIGHT; a chip shows "TITLE / [ value ]". Press A on a chip
## to EDIT: the brackets drop, the < > chevrons appear, LEFT/RIGHT now steps the value; A (or B)
## CONFIRMS and returns to browsing, so left/right freely reaches the next setting again.
##
## BROWSE focus = gold ring on the plate. EDIT = accent-filled plate + visible chevrons + value pop.
## A clamped edge in EDIT does the red micro-shake + low tick. Focus loss force-exits EDIT. B while
## editing is consumed (confirm), so it can never back out of the whole screen mid-edit.

signal changed(index: int, value: Variant)

const CHOCO := Color(0.231373, 0.141176, 0.105882)

@onready var _vbox: VBoxContainer = $VBox
@onready var _title: Label = $VBox/Title
@onready var _well: PanelContainer = $VBox/Row/ValueWell
@onready var _value: Label = $VBox/Row/ValueWell/Value
@onready var _minus: Button = $VBox/Row/Minus
@onready var _plus: Button = $VBox/Row/Plus

var labels: Array = []
var vals: Array = []
var index := 0
var accent: Color = Color("#ffd23f")   # focus/edit accent (owning screen may set per-stepper)
var editing := false

var _plate: Panel
var _sb_idle: StyleBoxFlat
var _sb_focus: StyleBoxFlat
var _sb_edit: StyleBoxFlat
var _sb_well: StyleBoxFlat        # inset value slot (the "this is a value" UI, not ASCII brackets)
var _sb_well_edit: StyleBoxFlat   # lit slot while editing

## Content-fit width: the root is a plain Control, so it must surface its VBox's minimum size for
## the owning HBox to lay chips out side by side.
func _get_minimum_size() -> Vector2:
	var v := get_node_or_null("VBox")
	if v == null:
		return Vector2(0, 96)
	var m: Vector2 = (v as Control).get_combined_minimum_size()
	return Vector2(m.x + 20.0, maxf(m.y + 12.0, 96.0))

func _ready() -> void:
	_vbox.minimum_size_changed.connect(update_minimum_size)
	# plates built here (not the theme) so the stepper is self-contained. Idle = dark glass chip
	# (readable over bright toy art); browse-focus = gold ring; edit = accent-filled + border.
	_sb_idle = StyleBoxFlat.new()
	_sb_idle.bg_color = Color(0.12, 0.09, 0.07, 0.42)
	_sb_idle.set_border_width_all(2)
	_sb_idle.border_color = Color(1.0, 1.0, 1.0, 0.10)
	_sb_idle.set_corner_radius_all(14)
	_sb_focus = _sb_idle.duplicate()
	_sb_focus.bg_color = Color(1.0, 1.0, 1.0, 0.10)
	_sb_focus.set_border_width_all(4)
	_sb_focus.border_color = accent
	_sb_edit = _sb_focus.duplicate()
	_sb_edit.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
	_sb_edit.set_border_width_all(5)
	_plate = Panel.new()
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override("panel", _sb_idle)
	add_child(_plate)
	move_child(_plate, 0)
	# the value sits in an inset WELL (owner round 3: real UI, not "[ 1 ]" text): a dark rounded
	# slot with a chocolate rim that reads as "a value lives here"; editing lights its rim gold.
	_sb_well = StyleBoxFlat.new()
	_sb_well.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	_sb_well.set_border_width_all(2)
	_sb_well.border_color = Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.9)
	_sb_well.set_corner_radius_all(10)
	_sb_well.content_margin_left = 10.0
	_sb_well.content_margin_right = 10.0
	_sb_well_edit = _sb_well.duplicate()
	_sb_well_edit.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	_sb_well_edit.set_border_width_all(3)
	_sb_well_edit.border_color = accent
	_well.add_theme_stylebox_override("panel", _sb_well)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_on_focus_out)
	_apply_state()

func _on_focus_out() -> void:
	editing = false   # leaving the chip always confirms
	_apply_state()

## One visual truth for the three states (idle / browse-focus / edit).
func _apply_state() -> void:
	if _plate == null:
		return
	_sb_focus.border_color = accent
	_sb_edit.border_color = accent
	_sb_edit.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
	if editing:
		_plate.add_theme_stylebox_override("panel", _sb_edit)
	elif has_focus():
		_plate.add_theme_stylebox_override("panel", _sb_focus)
	else:
		_plate.add_theme_stylebox_override("panel", _sb_idle)
	# chevrons exist only while EDITING (the "now it's editable" tell); the value well's rim
	# lights gold in edit so the slot itself reads as active.
	_minus.visible = editing
	_plus.visible = editing
	if _well != null and _sb_well != null:
		_sb_well_edit.border_color = accent
		_well.add_theme_stylebox_override("panel", _sb_well_edit if editing else _sb_well)
	_refresh()

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
	_value.text = str(labels[index]) if not labels.is_empty() else ""

func _set_editing(on: bool) -> void:
	editing = on
	_apply_state()
	if on:
		MenuFX.value_pop(_value)
	AudioManager.play_sfx("ui_click", {"pitch": 1.35 if on else 1.0, "volume_db": -6.0})

func _gui_input(e: InputEvent) -> void:
	# mouse: clicking the chip toggles edit (chevron Buttons handle their own clicks while visible)
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		_set_editing(not editing)
		accept_event()
		return
	if editing:
		if e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
			step(-1)
			accept_event()
		elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
			step(1)
			accept_event()
		elif e.is_action_pressed("ui_accept") or e.is_action_pressed("menu_accept") \
				or e.is_action_pressed("ui_cancel") or e.is_action_pressed("menu_back"):
			_set_editing(false)   # A confirms / B confirms — B must NOT back out of the screen
			accept_event()
		elif e.is_action_pressed("ui_up") or e.is_action_pressed("ui_down"):
			accept_event()   # no focus wandering mid-edit
	else:
		if e.is_action_pressed("ui_accept") or e.is_action_pressed("menu_accept"):
			_set_editing(true)
			accept_event()
		# left/right NOT consumed while browsing -> focus flows to the neighbouring setting
