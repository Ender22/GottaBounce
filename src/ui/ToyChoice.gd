extends Control
## WK-44 Options segmented choice row (SCREEN SHAKE OFF / LOW / FULL). Same ToyRow well + chocolate TextDark label as
## ToySlider / ToyToggle, and its segments fill the shared 536 px control column (the aligned grid). The chosen
## segment is the toggle's ON green with white outlined type; the others are cream pills with a chocolate rim.
## Focus (CC-5.1) = the ToyRowFocus well swap, like every Options row. Left / Right step (clamped: the edge gives
## the deny shake + low click, CC-5.2 / CC-9.2); A cycles to the next value (wraps).

signal changed(index: int)

const GREEN := Color(0.329412, 0.788235, 0.290196, 1)   # = ToyToggle ON
const CREAM := Color(1.0, 0.968627, 0.921569, 1)

@onready var _well: PanelContainer = $Well
@onready var _label: Label = $HBox/Label
@onready var _segs: Array = [$HBox/Segs/Seg0, $HBox/Segs/Seg1, $HBox/Segs/Seg2]

var index := 0
var count := 3
var accent := Color("#ff5fa8")
var focus_active := false    # QA readout

func setup(title: String, labels: Array, start: int, ac: Color) -> void:
	_label.text = title
	count = mini(labels.size(), _segs.size())
	for i in range(_segs.size()):
		var seg: PanelContainer = _segs[i]
		seg.visible = i < count
		if i < count:
			(seg.get_node("Label") as Label).text = str(labels[i])
	index = clampi(start, 0, count - 1)
	accent = ac
	_refresh(false)

func set_accent(ac: Color) -> void:
	accent = ac

func set_focus_active(active: bool) -> void:
	focus_active = active
	_well.theme_type_variation = &"ToyRowFocus" if active else &"ToyRow"

func step(d: int) -> void:
	var ni := clampi(index + d, 0, count - 1)
	if ni == index:
		MenuFX.reject_shake(_segs[index])
		AudioManager.play_sfx("ui_click", {"pitch": 0.6, "volume_db": -6.0})
		return
	_select(ni)

func cycle() -> void:
	_select((index + 1) % count)

func _select(i: int) -> void:
	index = i
	_refresh(true)
	AudioManager.play_sfx("ui_click")
	changed.emit(index)

func _refresh(anim: bool) -> void:
	for i in range(count):
		var seg: PanelContainer = _segs[i]
		var on: bool = i == index
		var sb := StyleBoxFlat.new()
		sb.bg_color = GREEN if on else CREAM
		sb.border_color = MenuFX.CHOCO
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(24)
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		seg.add_theme_stylebox_override("panel", sb)
		var lab: Label = seg.get_node("Label")
		lab.add_theme_color_override("font_color", Color.WHITE if on else MenuFX.CHOCO)
		lab.add_theme_color_override("font_outline_color", MenuFX.CHOCO)
		lab.add_theme_constant_override("outline_size", 8 if on else 0)
	if anim and index < _segs.size():
		var s: Control = _segs[index]
		s.pivot_offset = s.size * 0.5
		MenuFX.value_pop(s, 1.1)

func _gui_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		step(-1)
		accept_event()
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		step(1)
		accept_event()
	elif e.is_action_pressed("ui_accept") or e.is_action_pressed("menu_accept"):
		cycle()
		accept_event()
