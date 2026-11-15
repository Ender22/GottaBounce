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
## WK-141 (UX4-10): short enough that the sports strip fits ONE row (was the 54-char "SUPER-SMASH THE BALL (POWER
## SHOT) OR A RIVAL (CLEAR THEM)", which forced a second row deep into the court).
const SPORTS_SUPER_LABEL := "SUPER-SMASH BALL OR RIVAL"

@onready var _strip: HBoxContainer = $Root/Strip
@onready var _strip2: HBoxContainer = $Root/Strip2   # WK-29: overflow row (mixed-couch twin glyphs widen the chips)
@onready var _goal_row: HBoxContainer = $Root/GoalRow
@onready var _goal_chip: PanelContainer = $Root/GoalRow/GoalChip
@onready var _goal_label: Label = $Root/GoalRow/GoalChip/GoalLabel
@onready var _root: Control = $Root   # WK-141: held transparent until the rows are laid out

var _combat := false
var _fade_t := -1.0
var _dying := false
var _chip_nodes: Array = []   # [{panel, action}]
var _move_chip: PanelContainer = null
var _super_chip: PanelContainer = null   # WK-29: the widest chip, moved to Strip2 when one row overflows

var _goal_offsets := Vector2.ZERO   # WK-29: the scene's GoalRow offset_top/bottom (a bottom-dock overflow lifts it)
var _sports := false                # WK-141: this present() is the top-docked sports legend
var _ball_hooked: Object = null     # WK-141: the sports ball whose first live touch dims the legend
var _touch_dimmed := false
var _gen := 0                       # WK-141: present() generation (a REMATCH re-present cancels a pending layout)
var _goal_retired := false          # WK-147: a HUD panel carries the instruction, so the gold goal chip stepped aside
var _popped := false                # WK-156: the staggered pop-in has finished (it owns each chip's alpha until then)
var _goat_dim: Dictionary = {}      # WK-156: chip instance id -> 0..1 "a goat is under this chip" dim

func _ready() -> void:
	visible = false
	_goal_offsets = Vector2(_goal_row.offset_top, _goal_row.offset_bottom)

## verbs: GameMode.legend_verbs() ids in display order. goal: one-line rule for the gold chip ("" = no chip).
func present(verbs: Array = DEFAULT_VERBS, goal: String = "") -> void:
	visible = true
	_gen += 1
	var gen := _gen
	# WK-141 (UX4-11): nothing shows until the rows are fitted. The chips are added at full size this frame and only
	# measured next frame, so the one-row strip used to flash over the corner HUD cards before WK-29 reflowed it.
	_root.modulate.a = 0.0
	_combat = false
	_dying = false
	_fade_t = -1.0
	_strip.modulate.a = 1.0
	_strip2.modulate.a = 1.0
	_goal_row.modulate.a = 1.0
	_goal_retired = false   # WK-147
	_popped = false   # WK-156
	_goat_dim.clear()   # WK-156
	var sports: bool = _is_sports()   # WK-113
	_sports = sports
	_touch_dimmed = false
	_ball_hooked = null
	if sports and not EventBus.goal_scored.is_connected(_on_goal_scored):
		EventBus.goal_scored.connect(_on_goal_scored)   # WK-141: the first goal removes the legend
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
	if not visible or gen != _gen:
		return
	_fit_rows(sports)   # WK-29
	# WK-141: every chip starts the pop at alpha 0 BEFORE the layer is revealed, so the first visible frame is
	# already the final layout (nothing pops in at full size and then reflows)
	if _goal_row.visible:
		_goal_chip.modulate.a = 0.0
	for c in _chip_nodes:
		(c["panel"] as Control).modulate.a = 0.0
	_root.modulate.a = 1.0
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
		if i == pops.size() - 1:
			tw.tween_callback(func() -> void:   # WK-156: from here the goat-overlap dim may drive chip alpha
				if gen == _gen:
					_popped = true)

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
	if _sports and not _touch_dimmed:
		_hook_ball()   # WK-141
	if _popped and Tuning.legend_goat_dim:
		_dim_under_goats(delta)   # WK-156
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

## WK-156 (CD4-06): the legend is a CanvasLayer over the world, so a goat (or its tag) flying up into it was drawn UNDER
## the chips (Rocketball's kickoff toss sends goats straight into the top-docked band). Every chip (and the gold rule
## chip) that a living goat's body or its identity tag overlaps fades to Tuning.legend_goat_overlap_alpha and comes back
## when the goat leaves (hysteresis: a dimmed chip tests a wider rect). Per chip, so the rest of the strip stays readable.
## Multiplies on top of the row / layer alphas (fade-out, WK-141 touch dim), never fights them.
func _dim_under_goats(delta: float) -> void:
	var keep: Array = _goat_rects()
	var chips: Array = []
	for c in _chip_nodes:
		chips.append(c["panel"])
	if _goal_row.visible:
		chips.append(_goal_chip)
	var step: float = delta / maxf(Tuning.legend_goat_overlap_fade, 0.01)
	for ch in chips:
		var chip := ch as Control
		if chip == null or not is_instance_valid(chip) or not chip.is_visible_in_tree():
			continue
		var id: int = chip.get_instance_id()
		var d: float = float(_goat_dim.get(id, 0.0))
		var pad: float = Tuning.legend_goat_pad_px + (Tuning.legend_goat_hysteresis_px if d > 0.5 else 0.0)
		var r: Rect2 = chip.get_global_rect().grow(pad)
		var hit := false
		for k in keep:
			if r.intersects(k as Rect2):
				hit = true
				break
		d = move_toward(d, 1.0 if hit else 0.0, step)
		_goat_dim[id] = d
		chip.modulate.a = lerpf(1.0, Tuning.legend_goat_overlap_alpha, d)

## WK-156: screen rects of every living goat (body x 1.15 for horns / jet flame) and every visible identity tag.
func _goat_rects() -> Array:
	var out: Array = []
	var m: Node = get_parent()
	if m == null:
		return out
	var players: Variant = m.get("players")
	if players is Array:
		for p in (players as Array):
			if not (p is Node2D) or not is_instance_valid(p) or not (p as Node2D).is_visible_in_tree():
				continue
			if p.has_method("is_dead") and bool(p.call("is_dead")):
				continue
			var xf: Transform2D = (p as Node2D).get_global_transform_with_canvas()
			var rv: Variant = p.get("_radius")
			var rr: float = (float(rv) if rv != null else 44.0) * 1.15 * xf.get_scale().x
			out.append(Rect2(xf.origin - Vector2(rr, rr), Vector2(rr, rr) * 2.0))
	var pips: Variant = m.get("_pips")
	if pips is Control and is_instance_valid(pips):
		for pip in (pips as Control).get_children():
			if pip is Control and (pip as Control).visible and (pip as Control).modulate.a > 0.05 \
					and pip.has_method("local_rect"):
				var lr: Rect2 = pip.call("local_rect")   # already x the pip's scale
				out.append(Rect2((pip as Control).position + lr.position, lr.size))
	return out

func _bounce_chip(p: PanelContainer) -> void:
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2(0.88, 0.88), 0.06)
	tw.tween_property(p, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## WK-141 (UX4-10): the sports legend sits in the court's top band, where the ball flies. The first live touch dims
## it to Tuning.sports_legend_touch_alpha (still readable, no longer a wall); the first goal removes it. The ball
## re-spawns every kickoff, so the hook re-finds it by group ("sports_ball") instead of holding a reference.
func _hook_ball() -> void:
	if _ball_hooked != null and is_instance_valid(_ball_hooked):
		return
	var b: Node = get_tree().get_first_node_in_group("sports_ball")
	if b == null or not b.has_signal("touched"):
		return
	_ball_hooked = b
	b.connect("touched", _on_ball_touched, CONNECT_ONE_SHOT)

func _on_ball_touched(_p: Variant = null, _is_power: Variant = null) -> void:
	if _touch_dimmed or _dying or not visible:
		return
	_touch_dimmed = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", Tuning.sports_legend_touch_alpha, Tuning.sports_legend_touch_fade)

func _on_goal_scored(_team: Variant = null, _scorer: Variant = null, _own: Variant = null) -> void:
	if _sports and visible and not _dying:
		_fade_out()

## WK-147 (UX4-24): ONE goal surface. A mode HUD that already carries the instruction (the Trials objective panel's
## course hint, "HOLD A / SPACE - FLY UP TO THE RING") retires the gold chip ("FLY INTO THE GOLD RING"): gone at once
## if it has not popped in yet, otherwise a FADE_TIME fade. The controls strip keeps its own timing. Idempotent.
func retire_goal() -> void:
	if _goal_retired or not visible or _dying or not _goal_row.visible:
		return
	_goal_retired = true
	if _root.modulate.a < 0.05 or _goal_chip.modulate.a < 0.5:
		_goal_row.visible = false
		return
	var tw := create_tween()
	tw.tween_property(_goal_row, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void: _goal_row.visible = false)

func goal_retired() -> bool:
	return _goal_retired

## WK-131 (spec §4.4 H6): the mode swaps the gold rule row's copy mid-legend (Rocketball stage 1: "GOALS OPEN 3 SECONDS
## AFTER KICK OFF" -> "GOALS OPEN!" at the open -> the normal rule). `pop` re-runs the chip's press-bounce. No-op once the
## legend has gone, been retired, or has no goal row.
func set_goal_text(text: String, pop: bool = false) -> void:   # WK-131
	if not visible or _dying or _goal_retired or not _goal_row.visible:
		return
	_goal_label.text = text
	if pop:
		_goal_chip.pivot_offset = _goal_chip.size * 0.5
		var tw := create_tween()
		tw.tween_property(_goal_chip, "scale", Vector2(1.12, 1.12), 0.07)
		tw.tween_property(_goal_chip, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## eval-readable (QA): the legend's effective alpha (layer x rows).
func shown_alpha() -> float:
	return _root.modulate.a * _strip.modulate.a if visible else 0.0

func _fade_out() -> void:
	_dying = true
	var tw := create_tween()
	tw.tween_property(_strip, "modulate:a", 0.0, FADE_TIME)
	tw.parallel().tween_property(_strip2, "modulate:a", 0.0, FADE_TIME)
	tw.parallel().tween_property(_goal_row, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void: visible = false)
