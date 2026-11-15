extends Control
## One identity pip (BACKLOG WK-10 · audit C-09 / R-05 / R-17 · COUCH_CONVENTIONS CC-8.3): a small rounded
## tab with a speech-bubble pointer, positioned by PlayerPips at the goat's head. Origin = the pointer TIP.
##   human: "P3" (lobby label) on a tab filled with the goat's colour, chocolate outline, white type.
##   CPU:   its NAME ("VEX", CC-8.5 — the same word the HUD card and banners use) in the goat's colour, with a
##          small cream "CPU" sub-tag under it, on a dark chocolate tab with a goat-colour rim (reads "not a
##          person" at a glance while keeping the one-player-one-colour rule). Shown during the stage intro only.
## Built from PlayerPip.tscn + theme.tres (PlayerPip / PlayerPipLabel variations); only the per-player
## colour is applied here.
## WK-119 (UX4-09 / CC-8.3) SPORTS team dress, via set_team(): the tab sits inside a TEAM-colour rim (TeamRim, own
## chocolate outline) with a wider CAP on the team's home side, left for RED, right for BLUE, the same sides as the
## score chip's halves and the nets. The cap is the colour-blind-safe cue: teammates' tags lean the same way. The
## tail turns team colour. A CPU's sports tag is one row ("ZIGGY CPU": goat-colour NAME + small cream "CPU") on the
## dark plate with a chocolate border, so it is the same height as a human's P# pip.

const TAB_BOTTOM := -12.0      # y of the tab's bottom edge (the pointer hangs below it to the origin)
const CHOCO := Color(0.231373, 0.141176, 0.105882, 1.0)
const CPU_BG := Color(0.231373, 0.141176, 0.105882, 0.94)

@onready var _tab: PanelContainer = $Tab
@onready var _label: Label = $Tab/Box/Label
@onready var _sub: Label = $Tab/Box/Sub
@onready var _pointer: Polygon2D = $Pointer
@onready var _fill: Polygon2D = $Fill
@onready var _rim: Panel = $TeamRim
@onready var _box: BoxContainer = $Tab/Box

var _flipped := false
var _pop_tw: Tween
var _team := -1                # WK-119: -1 = no team dress (Brawl / Trials); 0 = RED (cap left), 1 = BLUE (cap right)
var _team_color := Color.WHITE

## text = the fighter's NAME (PartyMatch.player_name). sub = small second line ("" = none; CPUs pass "CPU").
func setup(text: String, color: Color, cpu: bool, sub: String = "") -> void:
	_label.text = text
	_sub.text = sub
	_sub.visible = sub != ""
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
	if _team >= 0:
		# WK-119: the team rim carries the team; the tab keeps the goat colour (identity) inside a chocolate border
		sb.border_color = CHOCO
		_pointer.color = CHOCO
		_fill.color = _team_color
	_tab.add_theme_stylebox_override("panel", sb)
	# WK-119: a CPU's sports tag is ONE row (NAME + small CPU), sized like a human pip; elsewhere the sub stacks
	_box.vertical = not (_team >= 0 and cpu)
	_box.add_theme_constant_override("separation", Tuning.sports_pip_cpu_gap if not _box.vertical else -8)
	_layout()

## WK-119: dress this pip for a sports team (team -1 = undress). Call BEFORE setup(), which applies the team colours.
func set_team(team: int, team_color: Color) -> void:
	_team = team
	_team_color = team_color
	_rim.visible = team >= 0
	if team >= 0:
		var sb: StyleBoxFlat = (_rim.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		sb.bg_color = team_color
		_rim.add_theme_stylebox_override("panel", sb)

func team() -> int:
	return _team

## Total height above (or below, when flipped) the origin, for the top-of-screen flip test.
func pip_height() -> float:
	if _team >= 0:
		return _rim.size.y - TAB_BOTTOM
	return _tab.size.y - TAB_BOTTOM

func tab_width() -> float:
	if _team >= 0:
		return _rim.size.x
	return _tab.size.x

## WK-119: the pip's drawn rect relative to its origin (the pointer tip), rim included — for keep-out tests.
func local_rect() -> Rect2:
	var r: Rect2 = _rim.get_rect() if _team >= 0 else _tab.get_rect()
	return Rect2(r.position * scale, r.size * scale).merge(Rect2(Vector2(-12.0, -4.0) * scale, Vector2(24.0, 8.0) * scale))

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
	if _team >= 0:
		# WK-119: rim = tab grown by sports_pip_rim_px, plus sports_pip_cap_px more on the home side; the WHOLE rim is
		# centred on the pointer and its outer edge sits where the tab's edge used to (the tail hangs off the rim).
		var rim: float = Tuning.sports_pip_rim_px
		var cap: float = Tuning.sports_pip_cap_px
		var rsz := Vector2(sz.x + rim * 2.0 + cap, sz.y + rim * 2.0)
		_rim.size = rsz
		var rx: float = -rsz.x * 0.5
		_rim.position = Vector2(rx, -TAB_BOTTOM) if _flipped else Vector2(rx, TAB_BOTTOM - rsz.y)
		var tx: float = rx + rim + (cap if _team == 0 else 0.0)
		_tab.position = Vector2(tx, _rim.position.y + rim)
		return
	if _flipped:
		_tab.position = Vector2(-sz.x * 0.5, -TAB_BOTTOM)
	else:
		_tab.position = Vector2(-sz.x * 0.5, TAB_BOTTOM - sz.y)
