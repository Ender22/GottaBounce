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

## Emitted when the player activates a match-end row button (id from the spec fed to show_match_buttons).
signal match_button_pressed(id)

const POP_IN := 0.15
const POP_OUT := 0.2
const MAX_PIPS := 4
const PIP_DONE := Color(1.0, 0.86, 0.3, 1.0)   # gold lock when a pip is complete (over the skin fill)
const MATCH_BTN_MIN := Vector2(300, 84)

var _runner   # PartyMatch (untyped so mode/state member access is dynamic — no runner class edit)
var _center_tw: Tween
var _top_tw: Tween
var _skin_colors: Array = []   # per-participant skin color (from setup), drives the pip fill

@onready var _home_panel: PanelContainer = $Root/HomePanel
@onready var _home_label: Label = $Root/HomePanel/HomeBox/HomeLabel
@onready var _sub_label: Label = $Root/HomePanel/HomeBox/SubLabel
@onready var _pips_row: HBoxContainer = $Root/HomePanel/HomeBox/PipsRow
@onready var _fuel_fill: Panel = $Root/FuelWrap/FuelBg/FuelFill
@onready var _fuel_bg: Panel = $Root/FuelWrap/FuelBg

@onready var _center_box: VBoxContainer = $Root/CenterC/CenterBox
@onready var _center_text: Label = $Root/CenterC/CenterBox/CenterText
@onready var _center_sub: Label = $Root/CenterC/CenterBox/CenterSub
@onready var _center_prompt: Label = $Root/CenterC/CenterBox/CenterPrompt
@onready var _top_label: Label = $Root/TopBand/TopCenter/TopBanner
@onready var _match_panel: PanelContainer = $Root/CenterC/MatchPanel
@onready var _match_box: VBoxContainer = $Root/CenterC/MatchPanel/MatchBox
@onready var _match_text: Label = $Root/CenterC/MatchPanel/MatchBox/MatchText
@onready var _match_sub: Label = $Root/CenterC/MatchPanel/MatchBox/MatchSub

# --- match-end focus button row (VictoryScreen focus model, mirrored) ---
var _match_btns: Array = []       # [Button] left->right; last = the safe menu_back target
var _match_focus := 0
var _match_armed := false
var _match_pulse: Tween
var _match_row: HBoxContainer = null

var _pips: Array = []   # [{root: Panel, fill: Panel}]

func _ready() -> void:
	_runner = get_parent()
	for i in range(MAX_PIPS):
		var root: Panel = _pips_row.get_node("Pip%d" % i)
		var fill: Panel = root.get_node("Fill")
		root.add_theme_stylebox_override("panel", _pip_bg_style())
		fill.add_theme_stylebox_override("panel", _pip_fill_style(Color.WHITE))
		root.visible = false
		_pips.append({"root": root, "fill": fill})

func _pip_bg_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.07, 0.85)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.231373, 0.141176, 0.105882, 1.0)
	sb.set_corner_radius_all(29)
	return sb

func _pip_fill_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(25)
	return sb

# ------------------------------------------------------------------ runner-called HUD surface
func setup(_players: Array, colors: Array, _skins: Array) -> void:
	_skin_colors = colors.duplicate()

func reset_scores() -> void:
	pass   # no score pips in TRIALS

func set_dead(_i: int, _dead: bool) -> void:
	pass   # a fall is a weightless respawn, not a death card

func animate_scores(_new_scores: Array) -> void:
	pass   # no score pips in TRIALS

# ------------------------------------------------------------------ live readouts
func _process(_delta: float) -> void:
	if _match_armed:
		_match_input()
	if _runner == null:
		return
	var mode = _runner._mode
	if mode == null:
		return
	var otype := "REACH_GOAL"
	if mode.has_method("objective_type"):
		otype = str(mode.objective_type())
	var n := _update_home(mode, otype)
	_update_sub(mode, otype)
	_update_fuel()
	# SOLO (owner 2026-07-17: a permanent "GO" is not a HUD element): the home tracker and its pip
	# are hidden — the panel carries only the course hint, and vanishes entirely when there is none.
	_sub_label.visible = _sub_label.text != ""
	_home_panel.visible = n > 1 or _sub_label.text != ""

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

## Per-type neutral secondary readout — never a clock, never a score. A course-authored HINT line
## (owner 2026-07-16 tutorials) takes the slot when present.
func _update_sub(mode, otype: String) -> void:
	if mode.has_method("hint") and str(mode.hint()) != "":
		_sub_label.text = str(mode.hint())
		return
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
	var ratio := 0.0
	var players: Array = _runner.players
	if players.size() > 0 and is_instance_valid(players[0]):
		ratio = float(players[0].get_fuel_ratio())
	var pad := 6.0
	var fw: float = maxf(0.0, _fuel_bg.size.x - pad * 2.0)
	var fh: float = maxf(0.0, _fuel_bg.size.y - pad * 2.0)
	_fuel_fill.position = Vector2(pad, pad)
	_fuel_fill.size = Vector2(fw * clampf(ratio, 0.0, 1.0), fh)

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

# ------------------------------------------------------------------ MATCH END (set summary panel)
func show_match_end(text: String, color: Color, subline: String) -> void:
	hide_center()
	_clear_match_buttons()
	_match_text.text = text
	_match_text.add_theme_color_override("font_color", color)
	_match_sub.text = subline
	var sb := _match_panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var sb2: StyleBoxFlat = (sb as StyleBoxFlat).duplicate()
		sb2.border_color = color
		_match_panel.add_theme_stylebox_override("panel", sb2)
	_match_panel.visible = true
	_match_panel.modulate.a = 1.0
	_match_panel.reset_size()
	_match_panel.pivot_offset = _match_panel.size * 0.5
	_match_panel.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(_match_panel, "scale", Vector2.ONE, POP_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------ MATCH END button row (VictoryScreen bar)
## Build a real focusable button row inside the MatchPanel — the actionable end-state, NOT a caption.
## specs = [{ "text": String, "id": StringName }, ...]; first button takes default focus + the primary
## style, the LAST button is the safe menu_back target. Mirrors VictoryScreen's focus juice exactly.
## PartyMatch calls this once, after its PROMPT_GUARD arm lock, and wires match_button_pressed.
func show_match_buttons(specs: Array) -> void:
	_clear_match_buttons()
	_match_focus = 0
	_match_armed = false
	for i in range(specs.size()):
		var spec: Dictionary = specs[i]
		var b := Button.new()
		b.text = "  %s  " % str(spec.get("text", ""))
		b.focus_mode = Control.FOCUS_NONE   # manual focus (VictoryScreen model) — no built-in nav
		b.custom_minimum_size = MATCH_BTN_MIN
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.theme_type_variation = &"ShellBtnPrimary" if i == 0 else &"ShellBtn"
		b.set_meta("id", spec.get("id", &""))
		var idx := i
		b.pressed.connect(func() -> void:
			if _match_armed:
				_activate_match(idx))
		_match_row.add_child(b)
		_match_btns.append(b)
	await get_tree().process_frame
	if _match_row == null:
		return
	for b: Button in _match_btns:
		b.pivot_offset = b.size * 0.5
	_match_row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_match_row, "modulate:a", 1.0, 0.2)
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

func _arm_match() -> void:
	_match_armed = true
	_set_match_focus(0)

func _match_input() -> void:
	if _match_btns.is_empty():
		return
	if Input.is_action_just_pressed(&"ui_left"):
		_set_match_focus((_match_focus + _match_btns.size() - 1) % _match_btns.size())
	elif Input.is_action_just_pressed(&"ui_right"):
		_set_match_focus((_match_focus + 1) % _match_btns.size())
	elif Input.is_action_just_pressed(&"menu_accept") or Input.is_action_just_pressed(&"ui_accept"):
		_activate_match(_match_focus)
	elif Input.is_action_just_pressed(&"menu_back"):
		# first back = focus the safe QUIT option (last); second back = take it (VictoryScreen rule)
		var qi := _match_btns.size() - 1
		if _match_focus == qi:
			_activate_match(qi)
		else:
			_set_match_focus(qi)

func _set_match_focus(i: int) -> void:
	_match_focus = i
	if _match_pulse != null and _match_pulse.is_valid():
		_match_pulse.kill()
	for j in range(_match_btns.size()):
		var b: Button = _match_btns[j]
		var focused: bool = j == i
		b.modulate.a = 1.0 if focused else 0.85
		var tw := create_tween()
		tw.tween_property(b, "scale", Vector2(1.12, 1.12) if focused else Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fb: Button = _match_btns[i]
	_match_pulse = create_tween()
	_match_pulse.set_loops()
	_match_pulse.tween_property(fb, "scale", Vector2(1.075, 1.075), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_match_pulse.tween_property(fb, "scale", Vector2(1.12, 1.12), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _activate_match(i: int) -> void:
	if not _match_armed or i < 0 or i >= _match_btns.size():
		return
	_match_armed = false   # one activation per row life — repeated accepts can't double-fire
	AudioManager.play_sfx("ui_click")
	match_button_pressed.emit(_match_btns[i].get_meta("id"))

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
