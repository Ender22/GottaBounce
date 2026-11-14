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
## Controller-only: always renders the drawn pad glyph (no keyboard variant — WK-01). Adds 0.0s to pacing.
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

@onready var _strip: HBoxContainer = $Root/Strip
@onready var _goal_row: HBoxContainer = $Root/GoalRow
@onready var _goal_chip: PanelContainer = $Root/GoalRow/GoalChip
@onready var _goal_label: Label = $Root/GoalRow/GoalChip/GoalLabel

var _combat := false
var _fade_t := -1.0
var _dying := false
var _chip_nodes: Array = []   # [{panel, action}]
var _move_chip: PanelContainer = null

func _ready() -> void:
	visible = false

## verbs: GameMode.legend_verbs() ids in display order. goal: one-line rule for the gold chip ("" = no chip).
func present(verbs: Array = DEFAULT_VERBS, goal: String = "") -> void:
	visible = true
	_combat = false
	_dying = false
	_fade_t = -1.0
	_strip.modulate.a = 1.0
	_goal_row.modulate.a = 1.0
	for c in _strip.get_children():
		c.queue_free()
	_chip_nodes.clear()
	_move_chip = null
	for v in verbs:
		var key := str(v)
		if not VERBS.has(key):
			continue
		var spec: Dictionary = VERBS[key]
		var chip: PanelContainer = CHIP_SCENE.instantiate()
		var glyph: PadGlyph = chip.get_node("Box/Glyph")
		glyph.setup(str(spec["pad"]))
		(chip.get_node("Box/Label") as Label).text = str(spec["label"])
		_strip.add_child(chip)
		_chip_nodes.append({"panel": chip, "action": str(spec["action"])})
		if key == "move":
			_move_chip = chip
	_goal_label.text = goal
	_goal_row.visible = goal != ""
	# staggered left->right pop-in (house stagger 0.12); the goal chip lands first — the WHY before the HOW
	await get_tree().process_frame
	if not visible:
		return
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
	tw.parallel().tween_property(_goal_row, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void: visible = false)
