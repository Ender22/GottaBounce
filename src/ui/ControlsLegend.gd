extends CanvasLayer
## FIRST-STAGE CONTROLS LEGEND (match_ceremony brief §2 · WK-15 · COUCH_CONVENTIONS CC-11.1). Cream chips —
## e.g. MOVE / FLY / SUPER SMASH / POWERUP / PAUSE — with drawn PadGlyph buttons, bottom-center, on stage 1
## of EVERY mode (was Brawl-only). The mode picks the verbs (GameMode.legend_verbs: Sports/Trials drop
## POWERUP — their maps spawn none). Modes with no stage intro card (Sports/Trials) also get a gold GOAL chip
## above the strip with their one-line rule (GameMode.goal_line: "HEADBUTT THE BALL INTO THEIR GOAL · FIRST
## TO 6", "FLY INTO THE GOLD RING"); BRAWL states its rule on the intro card instead.
## Rides the intro/countdown quiet time, holds 4s into COMBAT, then fades.
## Charm beat: pressing a listed button press-bounces its chip (the strip answers you).
## Early-out: the first use_powerup press in combat fades it immediately (lesson learned).
## WK-29 (CC-1.6): device-aware. Pad couch -> pad glyphs; keyboard only -> its key caps (WASD / SPACE / K / L / ESC);
## a mixed couch sees both twins on every chip ("A / SPACE"), because the legend teaches every player at once.
## Adds 0.0s to pacing.
## Chips are LegendChip.tscn instances (UI is .tscn + theme, CLAUDE.md); only text/glyph are set here.

const CHIP_SCENE := preload("res://scenes/ui/LegendChip.tscn")
const COMBAT_LINGER := 4.0
const FADE_TIME := 0.4
# verb id -> chip: label / gameplay action (for the press-bounce) / pad glyph
const VERBS := {
	"move": {"label": "MOVE", "action": "", "pad": "stick"},
	"fly": {"label": "FLY", "action": "boost", "pad": "A"},
	"super": {"label": "SUPER SMASH", "action": "super", "pad": "X"},
	"powerup": {"label": "POWERUP", "action": "use_powerup", "pad": "B"},
	# Start/Menu pauses — never B (COUCH_CONVENTIONS CC-1.1, audit C-01). No press-bounce: pressing it
	# pauses the tree, so the strip can't answer anyway.
	"pause": {"label": "PAUSE", "action": "", "pad": "START"},
}
const DEFAULT_VERBS := ["move", "fly", "super", "powerup", "pause"]
## WK-113 (SP-22): in sports the super does two jobs; the chip says both (a smash on a rival clears the keeper).
const SPORTS_SUPER_LABEL := "SUPER-SMASH THE BALL (POWER SHOT) OR A RIVAL (CLEAR THEM)"

@onready var _strip: HBoxContainer = $Root/Strip
@onready var _strip2: HBoxContainer = $Root/Strip2   # WK-29: overflow row (mixed-couch twin glyphs widen the chips)
@onready var _goal_row: HBoxContainer = $Root/GoalRow
@onready var _goal_chip: PanelContainer = $Root/GoalRow/GoalChip
@onready var _goal_label: Label = $Root/GoalRow/GoalChip/GoalLabel

var _combat := false
var _fade_t := -1.0
var _dying := false
var _chip_nodes: Array = []   # [{panel, action}]
var _move_chip: PanelContainer = null
var _super_chip: PanelContainer = null   # WK-29: the widest chip, moved to Strip2 when one row overflows

var _goal_offsets := Vector2.ZERO   # WK-29: the scene's GoalRow offset_top/bottom (a bottom-dock overflow lifts it)

func _ready() -> void:
	visible = false
	_goal_offsets = Vector2(_goal_row.offset_top, _goal_row.offset_bottom)

## verbs: GameMode.legend_verbs() ids in display order. goal: one-line rule for the gold chip ("" = no chip).
func present(verbs: Array = DEFAULT_VERBS, goal: String = "") -> void:
	visible = true
	_combat = false
	_dying = false
	_fade_t = -1.0
	_strip.modulate.a = 1.0
	_strip2.modulate.a = 1.0
	_goal_row.modulate.a = 1.0
	var sports: bool = _is_sports()   # WK-113
	for c in _strip.get_children():
		c.queue_free()
	for c in _strip2.get_children():
		c.queue_free()
	_strip2.visible = false
	if not _is_sports():   # WK-29: undo a previous present's bottom-dock overflow lift (REMATCH re-presents)
		_goal_row.offset_top = _goal_offsets.x
		_goal_row.offset_bottom = _goal_offsets.y
	_chip_nodes.clear()
	_move_chip = null
	_super_chip = null
	for v in verbs:
		var key := str(v)
		if not VERBS.has(key):
			continue
		var spec: Dictionary = VERBS[key]
		var chip: PanelContainer = CHIP_SCENE.instantiate()
		var glyph: PadGlyph = chip.get_node("Box/Glyph")
		var gspec: Array = PadGlyph.shared_spec(str(spec["pad"]), "play", true)   # WK-29
		glyph.setup(str(gspec[0]))
		if gspec.size() > 1:
			(chip.get_node("Box/Glyph2") as PadGlyph).setup(str(gspec[1]))
			(chip.get_node("Box/Glyph2") as Control).visible = true
			(chip.get_node("Box/Slash") as Control).visible = true
		var label: String = str(spec["label"])
		if sports and key == "super":
			label = SPORTS_SUPER_LABEL   # WK-113
		(chip.get_node("Box/Label") as Label).text = label
		_strip.add_child(chip)
		_chip_nodes.append({"panel": chip, "action": str(spec["action"])})
		if key == "move":
			_move_chip = chip
		elif key == "super":
			_super_chip = chip
	_goal_label.text = goal
	_goal_row.visible = goal != ""
	if sports:
		_dock_top()   # WK-113
	# staggered left->right pop-in (house stagger 0.12); the goal chip lands first — the WHY before the HOW
	await get_tree().process_frame
	if not visible:
		return
	_fit_rows(sports)   # WK-29
	var pops: Array = []
	if _goal_row.visible:
		pops.append(_goal_chip)
	for c in _chip_nodes:
		pops.append(c["panel"])
	for i in range(pops.size()):
		var p: Control = pops[i]
		p.pivot_offset = p.size * 0.5
		p.scale = Vector2(0.3, 0.3)
		p.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.12 * float(i) + 0.01)
		tw.tween_property(p, "modulate:a", 1.0, 0.10)
		tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## WK-113 (SP-11): sports play ON the floor (Dropshot's tiles crack there, Rocketball's ball rolls there), so the
## sports legend docks top-centre under the score bug instead of on the bottom edge: gold rule first, chips under it.
func _is_sports() -> bool:
	var cfg: MatchConfig = GameConfig.match_config
	return cfg != null and SportsMode.is_sports_mode(cfg.mode_id)

func _dock_top() -> void:
	var y: float = Tuning.sports_legend_top
	if _goal_row.visible:
		_place_top(_goal_row, y, Tuning.sports_legend_goal_h)
		y += Tuning.sports_legend_goal_h + Tuning.sports_legend_gap
	_place_top(_strip, y, Tuning.sports_legend_strip_h)
	if _strip2.visible:
		y += Tuning.sports_legend_strip_h + Tuning.sports_legend_gap
		_place_top(_strip2, y, Tuning.sports_legend_strip_h)

## WK-29: a mixed couch doubles every chip's glyph ("A / SPACE"). If the one strip no longer fits the screen with
## Tuning.legend_edge_margin (top dock) / legend_bottom_edge_margin (bottom dock, clear of the corner HUD cards)
## either side, the SUPER chip (the widest, esp. the sports smash line) drops to a second
## row instead of shrinking the 28 px text (CC-8.1). Top dock: the row goes under the strip. Bottom dock: the
## strip stays on the bottom edge, the extra row sits above it and the goal chip moves up one row.
func _fit_rows(sports: bool) -> void:
	if _super_chip == null or not is_instance_valid(_super_chip):
		return
	var vw: float = _strip.get_viewport_rect().size.x
	# bottom dock shares its band with the bottom HUD corner cards, so it keeps a wider margin than the top dock
	var margin: float = Tuning.legend_edge_margin if sports else Tuning.legend_bottom_edge_margin
	if _strip.get_combined_minimum_size().x <= vw - 2.0 * margin:
		return
	_strip.remove_child(_super_chip)
	_strip2.add_child(_super_chip)
	_strip2.visible = true
	if sports:
		_dock_top()
		return
	var step: float = Tuning.sports_legend_strip_h + Tuning.sports_legend_gap
	_strip2.offset_top = _strip.offset_top - step
	_strip2.offset_bottom = _strip.offset_bottom - step
	_goal_row.offset_top -= step
	_goal_row.offset_bottom -= step

func _place_top(c: Control, y: float, h: float) -> void:
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.grow_vertical = Control.GROW_DIRECTION_END
	c.offset_top = y
	c.offset_bottom = y + h

## Called from PartyMatch._bounce_go(): start the 4s combat linger, then fade.
func on_combat_started() -> void:
	if not visible:
		return
	_combat = true
	_fade_t = COMBAT_LINGER

func _process(delta: float) -> void:
	if not visible or _dying:
		return
	# press-bounce: the strip answers the buttons it teaches
	for c in _chip_nodes:
		var act: String = c["action"]
		if act != "" and Input.is_action_just_pressed(act):
			_bounce_chip(c["panel"])
			# early-out: powerup pressed during combat = lesson learned, strip leaves now
			if _combat and act == "use_powerup":
				_fade_out()
				return
	if _move_chip != null and (Input.is_action_just_pressed(&"move_left") or Input.is_action_just_pressed(&"move_right")):
		_bounce_chip(_move_chip)
	if _fade_t > 0.0:
		_fade_t -= delta
		if _fade_t <= 0.0:
			_fade_out()

func _bounce_chip(p: PanelContainer) -> void:
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2(0.88, 0.88), 0.06)
	tw.tween_property(p, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fade_out() -> void:
	_dying = true
	var tw := create_tween()
	tw.tween_property(_strip, "modulate:a", 0.0, FADE_TIME)
	tw.parallel().tween_property(_strip2, "modulate:a", 0.0, FADE_TIME)
	tw.parallel().tween_property(_goal_row, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void: visible = false)
