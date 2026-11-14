extends Control
## One identity pip (BACKLOG WK-10 · audit C-09 / R-05 / R-17 · COUCH_CONVENTIONS CC-8.3): a small rounded
## tab with a speech-bubble pointer, positioned by PlayerPips at the goat's head. Origin = the pointer TIP.
##   human: "P3" (lobby label) on a tab filled with the goat's colour, chocolate outline, white type.
##   CPU:   "CPU" in the goat's colour on a dark chocolate tab with a goat-colour rim (reads "not a person"
##          at a glance while keeping the one-player-one-colour rule). Shown during the stage intro only.
## Built from PlayerPip.tscn + theme.tres (PlayerPip / PlayerPipLabel variations); only the per-player
## colour is applied here.

const TAB_BOTTOM := -12.0      # y of the tab's bottom edge (the pointer hangs below it to the origin)
const CHOCO := Color(0.231373, 0.141176, 0.105882, 1.0)
const CPU_BG := Color(0.231373, 0.141176, 0.105882, 0.94)

@onready var _tab: PanelContainer = $Tab
@onready var _label: Label = $Tab/Label
@onready var _pointer: Polygon2D = $Pointer
@onready var _fill: Polygon2D = $Fill

var _flipped := false
var _pop_tw: Tween

func setup(text: String, color: Color, cpu: bool) -> void:
	_label.text = text
	var sb: StyleBoxFlat = (_tab.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	if cpu:
		sb.bg_color = CPU_BG
		sb.border_color = color
		_label.add_theme_color_override("font_color", color)
		_pointer.color = color
		_fill.color = CPU_BG
	else:
		sb.bg_color = color
		_pointer.color = CHOCO
		_fill.color = color
	_tab.add_theme_stylebox_override("panel", sb)
	_layout()

## Total height above (or below, when flipped) the origin, for the top-of-screen flip test.
func pip_height() -> float:
	return _tab.size.y - TAB_BOTTOM

func tab_width() -> float:
	return _tab.size.x

## Flipped = the pip hangs BELOW the anchor, pointer up (goat near the top edge of the screen).
func set_flipped(f: bool) -> void:
	if f == _flipped:
		return
	_flipped = f
	_layout()

## Spawn / pop-in punch (same feel as the old NameTag pop).
func pop() -> void:
	if _pop_tw != null and _pop_tw.is_valid():
		_pop_tw.kill()
	scale = Vector2.ZERO
	_pop_tw = create_tween()
	_pop_tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tw.tween_property(self, "scale", Vector2.ONE, 0.08)

func _layout() -> void:
	var sz: Vector2 = _tab.get_combined_minimum_size()
	_tab.size = sz
	var s: float = -1.0 if _flipped else 1.0
	_pointer.scale.y = s
	_fill.scale.y = s
	if _flipped:
		_tab.position = Vector2(-sz.x * 0.5, -TAB_BOTTOM)
	else:
		_tab.position = Vector2(-sz.x * 0.5, TAB_BOTTOM - sz.y)
