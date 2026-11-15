extends CanvasLayer
## TRIALS HUD (docs/specs/v10_trials_completion_model.md §4). Built from TrialsHUD.tscn + theme.tres.
## v10 (binary completion, no clock): the hero readout is the HOME/COMPLETION tracker — a "n of N HOME"
## count plus ONE skin-colored pip per participant that fills/locks when that player is `done`. There is
## NO timer, medal, par, best-time, or fall/penalty readout anywhere (all stripped). A per-type neutral
## secondary readout (SURVIVE progress via the pip fill, DESTROY "BLOCKS n", PUZZLE "BALL -> GOAL",
## COLLECT "TOKENS n/m", PRECISION "PADS n/m") gives the win rule at a glance. The fuel gauge is kept.
##
## Fills the SAME method surface PartyMatch calls on a HUD (setup / reset_scores / hide_center / set_dead
## / show_center / animate_scores / show_top / show_match_end / show_match_buttons) so the runner drives it
## unchanged; the score-oriented ones are no-ops. Live readouts poll the runner + active TrialsMode.
##
## WK-139 (UX4-07 / UX4-06): at MATCH_END the combat HUD steps aside — the corner PlayerCards, the objective panel and
## the top banner hide behind TRIALS COMPLETE! (WK-42 did this for the Brawl Victory) and come back when the next
## stage begins (PLAY AGAIN calls hide_center). The end row shares the Victory screens' button kit and its
## "A Select · B Quit" glyph footer (MatchHints, a shared HintStrip: pad glyphs when a pad is joined, CC-1.6).
##
## WK-142 (UX4-08): the match end is now the TrialsVictory celebration (crest, CIRCUIT CLEAR!, the cheering Herd,
## default focus NEXT CIRCUIT: <NAME>). show_match_end presents it instead of the cream MatchPanel; its choices come
## back through _on_victory_choice: rematch / setup / menu go to the runner exactly as the old row did
## (match_button_pressed), NEXT sets MatchConfig.circuit_id to the next course set and reloads the match scene
## under a cream iris (same players, devices and goats — MatchConfig + the InputRouter join registry carry over).
## The MatchPanel row below stays as the fallback if the celebration scene can't load.

## Emitted when the player activates a match-end row button (id from the spec fed to show_match_buttons).
signal match_button_pressed(id)

const POP_IN := 0.15
const POP_OUT := 0.2
const FocusRow := preload("res://src/ui/FocusRow.gd")
const MATCH_SCENE := "res://scenes/Arena.tscn"   # WK-142: NEXT CIRCUIT reloads the match with the next course set
const MAX_PIPS := 4
# Per-player fuel cards (owner 2026-07-19): co-op trials must show fuel PER PLAYER, same as brawl/sports —
# not one shared centre bar. Corner-anchored PlayerCards (identity + fuel gauge; score pips already removed).
const PLAYER_CARD := preload("res://scenes/ui/PlayerCard.tscn")
const CARD_W := 240.0
const CARD_H := 100.0
const CARD_MARGIN := 24.0
const PIP_DONE := Color(1.0, 0.86, 0.3, 1.0)   # gold lock when a pip is complete (over the skin fill)
const MATCH_BTN_MIN := Vector2(380, 90)   # WK-14/WK-42: fits the focused (primary, 46 px) label, so a focus move never resizes the row
# WK-87 (CD1-03): the objective panel must NEVER sit over the camera-framed goal. TrialsMode's
# camera_focus_points() pulls the goal into the frame, so the ring tends to land at a frame EDGE - often
# top-centre, exactly where this panel used to be pinned. The panel now picks, every frame, the
# cheapest of four slots (top-centre, top band beside the P1 card, top band beside the P2 card,
# bottom-centre) scored by overlap with the goals' on-screen footprints (hard), the live controls
# legend / goal chip (hard while shown), the players (soft) and a small preference order.
const SLOT_MARGIN := 24.0            # screen edge inset (matches CARD_MARGIN)
const SLOT_CARD_GAP := 24.0          # gap between a corner PlayerCard and a top-band slot
const GOAL_FOOT_MIN := 150.0         # world half-extent around a focus point (GoalGate ring r~148)
const GOAL_CLEAR := 28.0             # extra screen-px clearance around a goal footprint
const PLAYER_FOOT := 80.0            # world half-extent of a player (soft cost: don't cover them either)
const COST_GOAL := 20.0              # per px^2 of goal overlap
const COST_LEGEND := 8.0             # per px^2 of overlap with the visible controls legend / goal chip
const COST_PLAYER := 1.0             # per px^2 of player overlap
const COST_RANK := 1500.0            # per preference rank step (top-centre first)
const SLOT_SWITCH_MARGIN := 3000.0   # a new slot must beat the current one by this much (no flip-flop)
const SLOT_DWELL := 0.15             # ...continuously for this long (s) before the panel moves
const SLOT_SLIDE_RATE := 14.0        # 1/s exponential slide toward the chosen slot (snaps on first show)

var _runner   # PartyMatch (untyped so mode/state member access is dynamic — no runner class edit)
var _center_tw: Tween
var _top_tw: Tween
var _skin_colors: Array = []   # per-participant skin color (from setup), drives the pip fill

@onready var _home_panel: PanelContainer = $Root/HomePanel
@onready var _home_label: Label = $Root/HomePanel/HomeBox/HomeLabel
@onready var _sub_label: Label = $Root/HomePanel/HomeBox/SubLabel
@onready var _pips_row: HBoxContainer = $Root/HomePanel/HomeBox/PipsRow
# WK-29: a course hint that names a button ("HOLD  A / SPACE  —  FLY UP") renders as text + the device's glyph chip
@onready var _hint_row: HBoxContainer = $Root/HomePanel/HomeBox/HintRow
@onready var _hint_pre: Label = $Root/HomePanel/HomeBox/HintRow/HintPre
@onready var _hint_glyph: PadGlyph = $Root/HomePanel/HomeBox/HintRow/HintGlyph
@onready var _hint_slash: Label = $Root/HomePanel/HomeBox/HintRow/HintSlash
@onready var _hint_glyph2: PadGlyph = $Root/HomePanel/HomeBox/HintRow/HintGlyph2
@onready var _hint_post: Label = $Root/HomePanel/HomeBox/HintRow/HintPost
var _hint_key := ""            # WK-29: hint text + device kind the glyph row was last built for
var _hint_re: RegEx = null
@onready var _fuel_wrap: Control = $Root/FuelWrap
@onready var _root: Control = $Root

@onready var _center_box: VBoxContainer = $Root/CenterC/CenterBox
@onready var _center_text: Label = $Root/CenterC/CenterBox/CenterText
@onready var _center_sub: Label = $Root/CenterC/CenterBox/CenterSub
@onready var _center_prompt: Label = $Root/CenterC/CenterBox/CenterPrompt
@onready var _top_label: Label = $Root/TopBand/TopCenter/TopBanner
@onready var _match_panel: PanelContainer = $Root/CenterC/MatchPanel
@onready var _match_box: VBoxContainer = $Root/CenterC/MatchPanel/MatchBox
@onready var _match_text: Label = $Root/CenterC/MatchPanel/MatchBox/MatchText
@onready var _match_sub: Label = $Root/CenterC/MatchPanel/MatchBox/MatchSub
@onready var _match_hints: HBoxContainer = $Root/CenterC/MatchPanel/MatchBox/MatchHints   # WK-139

# --- match-end focus button row (VictoryScreen focus model, mirrored) ---
var _match_btns: Array = []       # [Button] left->right; last = the safe menu_back target
var _match_focus := 0
var _match_armed := false
var _gate: MenuInputGate
var _match_pulse: Tween
var _match_row: HBoxContainer = null
var _end_hidden := false          # WK-139: the combat HUD is hidden behind the match-end panel
var _victory = null              # WK-142 (untyped: TrialsVictory members are dynamic): the TrialsVictory celebration (lazy)

var _pips: Array = []   # [{root: Panel, fill: Panel}]
var _cards: Array = []  # per-player PlayerCard corner cards (fuel gauges)

# WK-87 objective-panel placement state
var _slot := -1                 # current slot index (-1 = not placed yet -> snap on first show)
var _slot_want := -1            # candidate that is currently beating _slot
var _slot_want_t := 0.0         # how long it has been beating it
var _panel_was_visible := false

func _ready() -> void:
	_runner = get_parent()
	# WK-11 (CC-10.2 / CC-3.3): the REMATCH row only takes FRESH presses from JOINED devices, >= 1.0 s
	# after the match-end panel appears (opened in show_match_end).
	_gate = MenuInputGate.new()
	_gate.name = "InputGate"
	add_child(_gate)
	_gate.verb.connect(_on_match_verb)
	for i in range(MAX_PIPS):
		var root: Panel = _pips_row.get_node("Pip%d" % i)
		var fill: Panel = root.get_node("Fill")
		root.add_theme_stylebox_override("panel", _pip_bg_style())
		fill.add_theme_stylebox_override("panel", _pip_fill_style(Color.WHITE))
		root.visible = false
		_pips.append({"root": root, "fill": fill})

func _pip_bg_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.231373, 0.141176, 0.105882, 0.22)   # WK-35: light chocolate well on the cream plate
	sb.set_border_width_all(4)
	sb.border_color = Color(0.231373, 0.141176, 0.105882, 1.0)
	sb.set_corner_radius_all(15)
	return sb

func _pip_fill_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(11)
	return sb

# ------------------------------------------------------------------ runner-called HUD surface
func setup(players: Array, colors: Array, skins: Array) -> void:
	_skin_colors = colors.duplicate()
	# PER-PLAYER fuel: one corner PlayerCard per participant, replacing the single shared bar. Solo -> one
	# card top-left; co-op -> the same 4-corner layout brawl/sports use, so 2P trials reads identically.
	if is_instance_valid(_fuel_wrap):
		_fuel_wrap.visible = false
	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
	for i in range(mini(players.size(), 4)):
		var card: Control = PLAYER_CARD.instantiate()
		_root.add_child(card)
		_place_corner(card, i)
		var col: Color = colors[i] if i < colors.size() else Color.WHITE
		var skin: String = str(skins[i]) if i < skins.size() else "pink"
		card.setup(i, col, skin)
		_cards.append(card)

## WK-10/WK-88 (CC-8.5): per-card NAME from PartyMatch.player_names() ("P3") + optional sub-tags from
## player_subtags() (the goat name — Trials is humans-only).
func set_labels(labels: Array, subs: Array = []) -> void:
	for i in range(mini(labels.size(), _cards.size())):
		if is_instance_valid(_cards[i]) and _cards[i].has_method("set_label"):
			_cards[i].set_label(str(labels[i]), str(subs[i]) if i < subs.size() else "")

## Anchor a card to corner 0=top-left / 1=top-right / 2=bottom-left / 3=bottom-right (matches MatchHUD).
func _place_corner(card: Control, corner: int) -> void:
	var right: bool = corner == 1 or corner == 3
	var bottom: bool = corner == 2 or corner == 3
	card.anchor_left = 1.0 if right else 0.0
	card.anchor_right = card.anchor_left
	card.anchor_top = 1.0 if bottom else 0.0
	card.anchor_bottom = card.anchor_top
	card.offset_left = (-CARD_MARGIN - CARD_W) if right else CARD_MARGIN
	card.offset_right = card.offset_left + CARD_W
	card.offset_top = (-CARD_MARGIN - CARD_H) if bottom else CARD_MARGIN
	card.offset_bottom = card.offset_top + CARD_H

func reset_scores() -> void:
	pass   # no score pips in TRIALS

func set_dead(_i: int, _dead: bool) -> void:
	pass   # a fall is a weightless respawn, not a death card

func animate_scores(_new_scores: Array) -> void:
	pass   # no score pips in TRIALS

# ------------------------------------------------------------------ live readouts
func _process(delta: float) -> void:
	if _runner == null:
		return
	var mode = _runner._mode
	if mode == null:
		return
	if _end_hidden:
		return   # WK-139: nothing re-shows the objective panel behind TRIALS COMPLETE!
	var otype := "REACH_GOAL"
	if mode.has_method("objective_type"):
		otype = str(mode.objective_type())
	var n := _update_home(mode, otype)
	_update_sub(mode, otype)
	_update_fuel()
	# SOLO (owner 2026-07-17: a permanent "GO" is not a HUD element): the home tracker and its pip
	# are hidden — the panel carries only the course hint, and vanishes entirely when there is none.
	_sub_label.visible = _sub_label.text != ""
	_home_panel.visible = n > 1 or _sub_label.text != "" or _hint_row.visible
	if _home_panel.visible and (_sub_label.text != "" or _hint_row.visible):   # WK-147: one goal surface
		var lg = _runner.get("_legend")
		if lg != null and is_instance_valid(lg) and lg.has_method("retire_goal"):
			lg.retire_goal()   # the panel carries the instruction -> the legend's gold chip steps aside
	_place_home_panel(mode, delta)

# ------------------------------------------------------------------ WK-87 objective-panel placement
## Candidate slot rects for a panel of size `sz` in the HUD's screen space. Order = preference rank.
func _slot_rects(sz: Vector2) -> Array:
	var vs: Vector2 = _root.size
	var inner_l := SLOT_MARGIN + CARD_W + SLOT_CARD_GAP
	var inner_r := vs.x - SLOT_MARGIN - CARD_W - SLOT_CARD_GAP - sz.x
	return [
		Rect2(Vector2((vs.x - sz.x) * 0.5, SLOT_MARGIN), sz),                # 0 top-centre (classic)
		Rect2(Vector2(inner_l, SLOT_MARGIN), sz),                            # 1 top band, beside the P1 card
		Rect2(Vector2(maxf(inner_r, inner_l), SLOT_MARGIN), sz),             # 2 top band, beside the P2 card
		Rect2(Vector2((vs.x - sz.x) * 0.5, vs.y - SLOT_MARGIN - sz.y), sz),  # 3 bottom-centre
	]

## On-screen footprints of every camera-framed objective (TrialsMode.camera_focus_points - the same
## seam the camera uses), widened to the goal node's own w/h when one sits on the point.
func goal_screen_rects(mode = null) -> Array:
	var split: Array = _focus_rects_split(mode)
	return (split[0] as Array) + (split[1] as Array)

## WK-158 (CD4-07c): [goals, movers]. A focus point with a goal node sitting on it (goal_gate / goal_zone / trials_target)
## is a GOAL; one without (the PHYSICS_PUZZLE ball) is a MOVER. The ball used to cost like a goal, so a ball flight
## under the top-centre panel threw it to the top-left mid-course and back. Movers now cost Tuning.trials_panel_mover_cost
## per px^2 (0 = ignored); goals keep COST_GOAL.
func _focus_rects_split(mode = null) -> Array:
	if mode == null and _runner != null:
		mode = _runner._mode
	var out: Array = []
	var movers: Array = []
	if mode == null or not mode.has_method("camera_focus_points"):
		return [out, movers]
	var pts: Array = mode.camera_focus_points(_runner)
	if pts.is_empty():
		return [out, movers]
	var xf: Transform2D = get_viewport().get_canvas_transform()
	var zoom: float = xf.get_scale().x
	var sized: Array = []
	for grp in ["goal_gate", "goal_zone", "trials_target"]:
		for g in get_tree().get_nodes_in_group(grp):
			if g is Node2D and ("w" in g) and ("h" in g):
				sized.append(g)
	for fp in pts:
		var wp: Vector2 = fp
		var half := Vector2(GOAL_FOOT_MIN, GOAL_FOOT_MIN)
		var on_goal := false   # WK-158
		for g in sized:
			if is_instance_valid(g) and (g as Node2D).global_position.distance_to(wp) < 1.0:
				half = half.max(Vector2(float(g.w), float(g.h)) * 0.5)
				on_goal = true
		var c: Vector2 = xf * wp
		var hs: Vector2 = half * zoom + Vector2(GOAL_CLEAR, GOAL_CLEAR)
		if on_goal or not Tuning.trials_panel_split_movers:
			out.append(Rect2(c - hs, hs * 2.0))
		else:
			movers.append(Rect2(c - hs, hs * 2.0))   # WK-158
	return [out, movers]

func _player_screen_rects() -> Array:
	var out: Array = []
	var xf: Transform2D = get_viewport().get_canvas_transform()
	var hs: Vector2 = Vector2(PLAYER_FOOT, PLAYER_FOOT) * xf.get_scale().x
	for p in _runner.players:
		if is_instance_valid(p) and not p.is_dead():
			out.append(Rect2((xf * (p.global_position as Vector2)) - hs, hs * 2.0))
	return out

## Visible rects of the stage-1 controls legend + WK-15 goal chip (PartyMatch._legend), while shown.
func _legend_rects() -> Array:
	var out: Array = []
	var lg = _runner.get("_legend")
	if lg == null or not is_instance_valid(lg) or not lg.visible:
		return out
	var lroot: Control = lg.get_node_or_null("Root")
	if lroot == null:
		return out
	for c in lroot.get_children():
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).modulate.a > 0.05:
			out.append((c as Control).get_global_rect())
	return out

static func _overlap(r: Rect2, list: Array) -> float:
	var a := 0.0
	for o in list:
		var ix: Rect2 = r.intersection(o as Rect2)
		a += ix.get_area()
	return a

func _slot_cost(r: Rect2, rank: int, goals: Array, legend: Array, plrs: Array, movers: Array = []) -> float:
	return COST_GOAL * _overlap(r, goals) + COST_LEGEND * _overlap(r, legend) \
		+ COST_PLAYER * _overlap(r, plrs) + COST_RANK * float(rank) \
		+ Tuning.trials_panel_mover_cost * _overlap(r, movers)   # WK-158

func _place_home_panel(mode, delta: float) -> void:
	if not _home_panel.visible:
		_panel_was_visible = false
		return
	var sz: Vector2 = _home_panel.get_combined_minimum_size()
	_home_panel.size = sz
	var slots := _slot_rects(sz)
	var split: Array = _focus_rects_split(mode)   # WK-158: goals hard, the ball (a mover) at its own weight
	var goals: Array = split[0]
	var movers: Array = split[1]
	var legend := _legend_rects()
	var plrs := _player_screen_rects()
	var best := 0
	var best_cost := INF
	var costs: Array = []
	for i in range(slots.size()):
		var c := _slot_cost(slots[i], i, goals, legend, plrs, movers)
		costs.append(c)
		if c < best_cost:
			best_cost = c
			best = i
	var snap := not _panel_was_visible or _slot < 0
	_panel_was_visible = true
	if snap:
		_slot = best
		_slot_want = -1
	elif best != _slot and best_cost < float(costs[_slot]) - SLOT_SWITCH_MARGIN:
		if _slot_want != best:
			_slot_want = best
			_slot_want_t = 0.0
		_slot_want_t += delta
		if _slot_want_t >= SLOT_DWELL:
			_slot = best
			_slot_want = -1
	else:
		_slot_want = -1
	var target: Vector2 = (slots[_slot] as Rect2).position
	if snap:
		_home_panel.position = target
	else:
		_home_panel.position = _home_panel.position.lerp(target, 1.0 - exp(-SLOT_SLIDE_RATE * delta))

## QA read surface (gbplay eval / scratch tests): panel rect, chosen slot, goal footprints.
func objective_panel_debug() -> Dictionary:
	return {"panel": _home_panel.get_global_rect(), "visible": _home_panel.is_visible_in_tree(),
		"slot": _slot, "goals": goal_screen_rects()}

## The HOME tracker: "n of N HOME" + one skin-colored pip per participant, filled by player_done
## (or SURVIVE progress) — MULTIPLAYER ONLY (owner 2026-07-17: solo showed a permanent "GO", which
## is a countdown word, not a HUD element; solo gets no tracker at all). Returns participant count.
func _update_home(mode, otype: String) -> int:
	var n := 0
	if mode.has_method("participant_count"):
		n = int(mode.participant_count(_runner))
	var home := 0
	if mode.has_method("home_count"):
		home = int(mode.home_count(_runner))
	var solo := n <= 1
	_home_label.visible = not solo
	if not solo:
		_home_label.text = "%d of %d  HOME" % [home, n]
	for i in range(MAX_PIPS):
		var pip: Dictionary = _pips[i]
		var root: Panel = pip["root"]
		if solo or i >= n:
			root.visible = false
			continue
		root.visible = true
		var ratio := 0.0
		var done := false
		if mode.has_method("player_done"):
			done = bool(mode.player_done(_runner, i))
		if otype == "SURVIVE" and mode.has_method("survive_ratio"):
			ratio = float(mode.survive_ratio(_runner, i))
		else:
			ratio = 1.0 if done else 0.0
		_paint_pip(pip, i, ratio, done)
	return n

## Paint one pip: a skin-colored fill rising from the bottom by `ratio`; a full/done pip locks to gold.
func _paint_pip(pip: Dictionary, idx: int, ratio: float, done: bool) -> void:
	var root: Panel = pip["root"]
	var fill: Panel = pip["fill"]
	var pad := 6.0
	var sz: Vector2 = root.size
	var iw: float = maxf(0.0, sz.x - pad * 2.0)
	var ih: float = maxf(0.0, sz.y - pad * 2.0)
	var fh: float = ih * clampf(ratio, 0.0, 1.0)
	fill.position = Vector2(pad, pad + (ih - fh))
	fill.size = Vector2(iw, fh)
	var col: Color = _skin_color(idx)
	var sb := fill.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		(sb as StyleBoxFlat).bg_color = PIP_DONE if done else col

func _skin_color(idx: int) -> Color:
	if idx >= 0 and idx < _skin_colors.size():
		var c = _skin_colors[idx]
		if c is Color:
			return c
	return Color(0.29, 0.83, 0.95, 1.0)

## WK-29 (CC-1.6 / WK-29 accept "Trials no longer says HOLD A / SPACE"): course hints written with a dual button
## token ("A / SPACE", "X / K", authored in the course JSON) show the button as the ONE glyph component instead,
## in the shared device kind: pad glyph for pads, the key cap (PadGlyph.KEYS_PLAY) for keyboard only, both on a
## mixed couch. Returns false (plain text) when the hint names no button.
func _glyph_hint(h: String) -> bool:
	if _hint_re == null:
		_hint_re = RegEx.new()
		_hint_re.compile("^(.*?)\\b([ABXY]) / [A-Z]+\\b(.*)$")
	var kind: String = PadGlyph.shared_kind()
	var key := h + "|" + kind
	if key == _hint_key:
		return _hint_row.visible
	_hint_key = key
	var m: RegExMatch = _hint_re.search(h)
	if m == null:
		_hint_row.visible = false
		return false
	var spec: Array = PadGlyph.shared_spec(m.get_string(2), "play", true)
	_hint_pre.text = m.get_string(1).strip_edges()
	_hint_pre.visible = _hint_pre.text != ""
	_hint_glyph.setup(str(spec[0]))
	_hint_slash.visible = spec.size() > 1
	_hint_glyph2.visible = spec.size() > 1
	if spec.size() > 1:
		_hint_glyph2.setup(str(spec[1]))
	_hint_post.text = m.get_string(3).strip_edges()
	_hint_post.visible = _hint_post.text != ""
	_hint_row.visible = true
	return true

## Per-type neutral secondary readout — never a clock, never a score. A course-authored HINT line
## (owner 2026-07-16 tutorials) takes the slot when present.
func _update_sub(mode, otype: String) -> void:
	if mode.has_method("hint") and str(mode.hint()) != "":
		var h := str(mode.hint())
		if _glyph_hint(h):
			_sub_label.text = ""
		else:
			_hint_row.visible = false
			_sub_label.text = h
		return
	_hint_row.visible = false
	match otype:
		"SURVIVE":
			_sub_label.text = "SURVIVE %.0fs" % float(mode.survive_target()) if mode.has_method("survive_target") else "SURVIVE"
		"DESTROY_ALL":
			_sub_label.text = "BLOCKS %d" % int(mode.blocks_remaining(_runner)) if mode.has_method("blocks_remaining") else "SMASH ALL"
		"PHYSICS_PUZZLE":
			_sub_label.text = "BALL -> GOAL"
		"COLLECT_ALL":
			if mode.has_method("tokens_total"):
				_sub_label.text = "TOKENS %d / %d" % [int(mode.tokens_collected(_runner)), int(mode.tokens_total())]
			else:
				_sub_label.text = "COLLECT ALL"
		"PRECISION_LAND":
			if mode.has_method("pads_total"):
				_sub_label.text = "PADS %d / %d" % [int(mode.pads_landed(_runner)), int(mode.pads_total())]
			else:
				_sub_label.text = "SOFT-LAND ALL"
		_:
			_sub_label.text = ""   # REACH_GOAL: the home tracker alone

func _update_fuel() -> void:
	# drive each participant's corner card from their own player (per-player fuel, not one shared bar)
	var players: Array = _runner.players
	for i in range(_cards.size()):
		var card: Control = _cards[i]
		if not is_instance_valid(card):
			continue
		if i < players.size() and is_instance_valid(players[i]):
			var p = players[i]
			card.set_fuel(p.get_fuel_ratio(), p.fuel_locked)
			card.set_powerup(p.held_powerup)

# ------------------------------------------------------------------ CENTER banner (frozen / pre-round)
func show_center(text: String, color: Color, hold: float, sub := "") -> void:
	_center_prompt.visible = false
	_center_text.text = text
	_center_text.add_theme_color_override("font_color", color)
	_center_sub.text = sub
	_center_sub.visible = sub != ""
	if _center_tw != null and _center_tw.is_valid():
		_center_tw.kill()
	_center_box.visible = true
	_center_box.modulate.a = 1.0
	_center_box.reset_size()
	_center_box.pivot_offset = _center_box.size * 0.5
	_center_box.scale = Vector2(0.3, 0.3)
	_center_tw = create_tween()
	_center_tw.tween_property(_center_box, "scale", Vector2.ONE, POP_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold >= 0.0:
		_center_tw.tween_interval(hold)
		_center_tw.tween_property(_center_box, "modulate:a", 0.0, POP_OUT)
		_center_tw.parallel().tween_property(_center_box, "scale", Vector2(1.25, 1.25), POP_OUT)
		_center_tw.tween_callback(hide_center)

func hide_center() -> void:
	if _center_tw != null and _center_tw.is_valid():
		_center_tw.kill()
	_center_box.visible = false
	_center_box.modulate.a = 1.0
	_center_box.scale = Vector2.ONE
	_center_prompt.visible = false
	_match_panel.visible = false
	_match_hints.visible = false
	if _victory != null and _victory.is_live():
		_victory.dismiss()   # WK-142: PLAY AGAIN starts a new stage
	if not _goats_hidden.is_empty():
		_hide_world_goats(false)   # WK-158
	if _end_hidden:
		_set_end_hidden(false)   # WK-139: a new stage (PLAY AGAIN) brings the combat HUD back

## WK-139 (UX4-07): hide / restore the combat HUD around the match-end panel. The objective panel is re-evaluated by
## _process on the next frame once restored.
func _set_end_hidden(on: bool) -> void:
	_end_hidden = on
	for c in _cards:
		if is_instance_valid(c):
			(c as Control).visible = not on
	if on:
		_home_panel.visible = false
		_top_label.visible = false
		_panel_was_visible = false

# ------------------------------------------------------------------ MATCH END (set summary panel)
func show_match_end(text: String, color: Color, subline: String) -> void:
	hide_center()
	_set_end_hidden(true)   # WK-139
	_clear_match_buttons()
	if _present_victory():   # WK-142: the celebration replaces the cream panel
		return
	_gate.open()   # the end screen "appears" now: presses must begin after this and the row arms >= 1.0 s later
	_match_text.text = text
	_match_text.add_theme_color_override("font_color", color)
	_match_sub.text = subline   # WK-35: cream ToyPanel keeps its chocolate rim (no navy, no recoloured rim)
	_match_panel.visible = true
	_match_panel.modulate.a = 1.0
	_match_panel.reset_size()
	_match_panel.pivot_offset = _match_panel.size * 0.5
	_match_panel.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(_match_panel, "scale", Vector2.ONE, POP_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------ MATCH END button row (VictoryScreen bar)
## Build a real focusable button row inside the MatchPanel — the actionable end-state, NOT a caption.
## specs = [{ "text": String, "id": StringName }, ...]; first button takes default focus (the primary
## style follows focus, WK-14), the LAST button is the safe menu_back target. Mirrors VictoryScreen's focus juice exactly.
## PartyMatch calls this once, after its PROMPT_GUARD arm lock, and wires match_button_pressed.
func show_match_buttons(specs: Array) -> void:
	if _victory != null and _victory.is_live():
		_victory.allow_row()   # WK-142: the celebration owns the row (its NEXT / PLAY AGAIN / SETUP / QUIT)
		return
	_clear_match_buttons()
	_match_focus = 0
	_match_armed = false
	for i in range(specs.size()):
		var spec: Dictionary = specs[i]
		var b := Button.new()
		b.text = str(spec.get("text", ""))
		b.focus_mode = Control.FOCUS_NONE   # manual focus (VictoryScreen model) — no built-in nav
		b.custom_minimum_size = MATCH_BTN_MIN
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.theme_type_variation = &"ShellBtn"   # WK-14: FocusRow swaps the focused one to primary
		b.set_meta("id", spec.get("id", &""))
		var idx := i
		b.pressed.connect(func() -> void:
			if _match_armed and _gate.mouse_may_act():
				_activate_match(idx))
		_match_row.add_child(b)
		_match_btns.append(b)
	await get_tree().process_frame
	if _match_row == null:
		return
	for b: Button in _match_btns:
		b.pivot_offset = b.size * 0.5
	_match_row.modulate.a = 0.0
	_match_hints.visible = true   # WK-139: "A Select · B Quit" appears with the row it describes
	_match_hints.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_match_row, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_match_hints, "modulate:a", 1.0, 0.2)
	_arm_match()

func _clear_match_buttons() -> void:
	_match_armed = false
	if _match_pulse != null and _match_pulse.is_valid():
		_match_pulse.kill()
	if _match_row != null and is_instance_valid(_match_row):
		_match_row.queue_free()
	_match_btns.clear()
	_match_row = HBoxContainer.new()
	_match_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_match_row.add_theme_constant_override("separation", 30)
	_match_box.add_child(_match_row)
	_match_box.move_child(_match_row, _match_hints.get_index())   # WK-139: the glyph footer stays under the row

func _arm_match() -> void:
	_match_armed = true
	_set_match_focus(0)

## Gate verb (armed + fresh + joined device). The row may still be fading in; it acts once built + armed.
func _on_match_verb(v: String, _key: String) -> void:
	if not _match_armed or _match_btns.is_empty():
		return
	match v:
		"left":
			_set_match_focus((_match_focus + _match_btns.size() - 1) % _match_btns.size())
		"right":
			_set_match_focus((_match_focus + 1) % _match_btns.size())
		"accept":
			_activate_match(_match_focus)
		"back":
			# first back = focus the safe QUIT option (last); second back = take it (VictoryScreen rule)
			var qi := _match_btns.size() - 1
			if _match_focus == qi:
				_activate_match(qi)
			else:
				_set_match_focus(qi)

func _set_match_focus(i: int) -> void:
	_match_focus = i
	_match_pulse = FocusRow.row(self, _match_btns, i, _match_pulse)   # WK-14: shared focus look (CC-5.1)

func _activate_match(i: int) -> void:
	if not _match_armed or i < 0 or i >= _match_btns.size():
		return
	_match_armed = false   # one activation per row life — repeated accepts can't double-fire
	AudioManager.play_sfx("ui_click")
	if _match_btns[i].get_meta("id") == &"menu":
		GameConfig.quit_to_modes = true   # WK-144: QUIT TO MENU lands on mode select, lobby cleared
	match_button_pressed.emit(_match_btns[i].get_meta("id"))

# ------------------------------------------------------------------ WK-142 TRIALS celebration

## Build the celebration's data from the runner + TrialsMode and present it. False if it could not load.
func _present_victory() -> bool:
	if _victory == null:
		var ps: PackedScene = load("res://scenes/ui/TrialsVictory.tscn") as PackedScene
		if ps == null:
			return false
		_victory = ps.instantiate()
		add_child(_victory)
		_victory.choice.connect(_on_victory_choice)
	var mode = _runner._mode if _runner != null else null
	var sid: String = str(mode.set_id) if mode != null and "set_id" in mode else "campaign"
	var circ: Dictionary = TrialsMode.circuit_info(sid)
	if circ.is_empty():
		circ = {"id": sid, "name": "TRIALS", "color": Color("#ffd23f"), "courses": 0, "crest": ""}
	if mode != null and mode.has_method("course_count"):
		circ["courses"] = int(mode.course_count())
	var nid: String = TrialsMode.next_circuit_id(sid)
	var goats: Array = []
	var players: Array = _runner.players if _runner != null else []
	for i in range(players.size()):
		var p = players[i]
		if not is_instance_valid(p):
			continue
		goats.append({
			"idx": i,
			"name": str(_runner.player_name(i)) if _runner.has_method("player_name") else "P%d" % (i + 1),
			"sub": str(_runner.player_subtag(i)) if _runner.has_method("player_subtag") else "",
			"color": _runner.player_color(i) if _runner.has_method("player_color") else _skin_color(i),
			"skin": str(p.skin),
		})
	_victory.present({"circuit": circ, "next": TrialsMode.circuit_info(nid) if nid != "" else {}, "goats": goats})
	_hide_world_goats(true)   # WK-158
	return true

## WK-158 (CD4-07e): the frozen in-world goat sat right behind the celebration goat (the punch-zoom frames it at screen
## centre, where the Herd hops), reading as a double through the 0.8 scrim. The world goats hide while the celebration is
## up and come back on PLAY AGAIN (hide_center); NEXT / SETUP / QUIT leave the scene anyway.
var _goats_hidden: Array = []   # WK-158: the players this HUD hid

func _hide_world_goats(on: bool) -> void:
	if on:
		if not Tuning.trials_victory_hide_goats or _runner == null:
			return
		for p in _runner.players:
			if is_instance_valid(p) and (p as Node2D).visible:
				(p as Node2D).visible = false
				_goats_hidden.append(p)
		return
	for p in _goats_hidden:
		if is_instance_valid(p):
			(p as Node2D).visible = true
	_goats_hidden.clear()

## The celebration's button: NEXT is handled here (scene reload with the next course set); the other three go to the
## runner through the same signal the old row used.
func _on_victory_choice(id: StringName) -> void:
	if id == &"next":
		var nid: String = str(_victory.next_id())
		var cfg: MatchConfig = GameConfig.match_config
		if nid == "" or cfg == null:
			return
		cfg.arena_mode = MatchConfig.ArenaMode.CIRCUIT
		cfg.circuit_id = StringName(nid)
		cfg.single_arena_path = ""
		_victory.cover_then(func() -> void: get_tree().change_scene_to_file(MATCH_SCENE))
		return
	if id == &"menu":
		GameConfig.quit_to_modes = true   # WK-144
	match_button_pressed.emit(id)

## QA (gbplay eval): the live TrialsVictory, or null.
func victory():
	return _victory

# ------------------------------------------------------------------ TOP banner (transient — part of the surface)
func show_top(text: String, color: Color, hold: float) -> void:
	_top_label.text = text
	_top_label.add_theme_color_override("font_color", color)
	_top_label.visible = true
	_top_label.modulate.a = 1.0
	_top_label.reset_size()
	_top_label.pivot_offset = _top_label.size * 0.5
	_top_label.scale = Vector2(0.3, 0.3)
	if _top_tw != null and _top_tw.is_valid():
		_top_tw.kill()
	_top_tw = create_tween()
	_top_tw.tween_property(_top_label, "scale", Vector2.ONE, POP_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_top_tw.tween_interval(hold)
	_top_tw.tween_property(_top_label, "modulate:a", 0.0, POP_OUT)
	_top_tw.tween_callback(func() -> void: _top_label.visible = false)
