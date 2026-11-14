extends CanvasLayer
## SPORTS HUD (docs/specs/v5_sports_mode.md §5, chip rework per owner list 2026-07-18 item 1).
## Built from SportsHUD.tscn + assets/ui/theme.tres. The score readout is ONE compact color-coded
## pill TOP-CENTER — red number | dash | blue number with a tiny "TO N" cap line — replacing the two
## huge side panels that ate the screen. Navy chip, chocolate outline, chunky type (theme grammar).
## WK-106 / WK-16: ONE goal banner. On EVERY goal (EventBus.goal_scored) the HUD fires a full-screen
## team-coloured flash (tint only — no second headline) and pops the scoring team's chip digit; the banner
## itself is the runner's centre banner (SportsMode.stage_end_banner: "GOAL!" / "OWN GOAL!" + scorer line),
## whose scorer line this HUD tints in the credited player's team colour.
## It fills the SAME method surface PartyMatch calls on a HUD (setup / reset_scores / hide_center
## / set_dead / show_center / animate_scores / show_top / show_match_end / show_match_buttons) so the
## runner drives it unchanged; the per-player-pip ones are no-ops. Team scores poll runner._mode each frame.

## Emitted when the player activates a match-end row button (id from the spec fed to show_match_buttons).
signal match_button_pressed(id)

const POP_IN := 0.15
const POP_OUT := 0.2
const RED := Color("#ff4b6a")
const BLUE := Color("#3fa9ff")
const MATCH_BTN_MIN := Vector2(300, 84)
# WK-111 (SP-09): the sports end screen. show_match_end presents it (when the mode has match_stats) instead of the
# old centre panel; it owns the REMATCH / CHANGE SETUP / QUIT row and its input from then on.
const VICTORY_SCENE := preload("res://scenes/ui/SportsVictory.tscn")
const VICTORY_DELAY := 0.9     # = PartyMatch.VICTORY_DELAY: the in-world winning-team frame breathes first

var _runner   # PartyMatch (untyped so mode/state member access is dynamic — no runner class edit)
var _center_tw: Tween
var _top_tw: Tween
var _flash_tw: Tween
var _pop_tw: Tween
var _goal_sub_color: Variant = null   # WK-106: scorer-line colour for the NEXT show_center (set by goal_scored)
var _goal_banner_next := false        # WK-124: the NEXT show_center is the goal banner (set by goal_scored)
var _goal_banner_live := false        # WK-124: the goal banner is up and rides over the kickoff reset

@onready var _red_score: Label = $Root/ScoreChip/ChipBox/Scores/RedScore
@onready var _blue_score: Label = $Root/ScoreChip/ChipBox/Scores/BlueScore
@onready var _cap: Label = $Root/ScoreChip/ChipBox/CapLabel
@onready var _flash: ColorRect = $Root/GoalFlash

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
var _gate: MenuInputGate
var _match_pulse: Tween
var _match_row: HBoxContainer = null
var _victory: CanvasLayer = null       # WK-111 SportsVictory (lazy)
var _victory_on := false               # WK-111: the end screen owns MATCH_END (set at show_match_end)
@onready var _chip: Control = $Root/ScoreChip

func _ready() -> void:
	_runner = get_parent()
	# WK-11 (CC-10.2 / CC-3.3): the REMATCH row only takes FRESH presses from JOINED devices, >= 1.0 s
	# after the match-end panel appears (opened in show_match_end).
	_gate = MenuInputGate.new()
	_gate.name = "InputGate"
	add_child(_gate)
	_gate.verb.connect(_on_match_verb)
	_flash.visible = false
	_red_score.add_theme_color_override("font_color", RED)
	_blue_score.add_theme_color_override("font_color", BLUE)
	# WK-106: THE goal event (one per goal, same-team repeats included) drives the flash + score pop.
	if not EventBus.goal_scored.is_connected(_on_goal_scored):
		EventBus.goal_scored.connect(_on_goal_scored)

# ------------------------------------------------------------------ runner-called HUD surface
func setup(_players: Array, _colors: Array, _skins: Array) -> void:
	pass   # SPORTS shows TEAM scores (polled), not per-player cards

func reset_scores() -> void:
	_dismiss_victory()   # WK-111: a REMATCH re-runs _start_match -> reset_scores
	_goal_sub_color = null
	_goal_banner_next = false
	_red_score.text = "0"
	_blue_score.text = "0"

func set_dead(_i: int, _dead: bool) -> void:
	pass   # players never die in SPORTS (respawn); no death card

func animate_scores(_new_scores: Array) -> void:
	pass   # kill-race scores are unused in SPORTS; team scores poll the mode

# ------------------------------------------------------------------ live readouts
func _process(_delta: float) -> void:
	if _runner == null:
		return
	var mode = _runner._mode
	if mode == null or not mode.has_method("team_scores"):
		return
	var scores: Array = mode.team_scores()
	var cap: int = int(mode.goal_cap())
	if scores.size() >= 2:
		_red_score.text = str(int(scores[0]))
		_blue_score.text = str(int(scores[1]))
	_cap.text = "TO %d" % cap

## WK-106: every goal -> team flash + chip pop, and remember the scorer-line colour for the banner the runner
## shows right after (stage_end_banner emits this synchronously, then PartyMatch calls show_center).
## Own goal: the line names the conceding player, so it is tinted in THEIR team's colour.
func _on_goal_scored(team: int, scorer, own_goal: bool) -> void:
	var t: int = clampi(team, 0, 1)
	var credited_team: int = (1 - t) if own_goal else t
	_goal_sub_color = RED if credited_team == 0 else BLUE
	if scorer == null:
		_goal_sub_color = RED if t == 0 else BLUE
	_goal_banner_next = true
	_goal_flash(t)
	_score_pop(t)

func _goal_flash(team: int) -> void:
	var col: Color = RED if team == 0 else BLUE
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_flash.color = Color(col.r, col.g, col.b, 0.0)
	_flash.visible = true
	_flash_tw = create_tween()
	_flash_tw.tween_property(_flash, "color:a", 0.45, 0.10)
	_flash_tw.tween_interval(0.5)
	_flash_tw.tween_property(_flash, "color:a", 0.0, 0.3)
	_flash_tw.tween_callback(func() -> void: _flash.visible = false)

## WK-16 "score tick": the scoring team's chip digit punches up (scale + white flash) and settles.
func _score_pop(team: int) -> void:
	var lbl: Label = _red_score if team == 0 else _blue_score
	var other: Label = _blue_score if team == 0 else _red_score
	if _runner != null and _runner._mode != null and _runner._mode.has_method("team_scores"):
		var sc: Array = _runner._mode.team_scores()
		if sc.size() >= 2:
			_red_score.text = str(int(sc[0]))
			_blue_score.text = str(int(sc[1]))
	if _pop_tw != null and _pop_tw.is_valid():
		_pop_tw.kill()
	other.scale = Vector2.ONE
	other.modulate = Color.WHITE
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2(1.9, 1.9)
	lbl.modulate = Color(2.2, 2.2, 2.2, 1.0)
	_pop_tw = create_tween()
	_pop_tw.set_parallel(true)
	_pop_tw.tween_property(lbl, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pop_tw.tween_property(lbl, "modulate", Color.WHITE, 0.5)

# ------------------------------------------------------------------ CENTER banner (countdown / GOAL freeze)
func show_center(text: String, color: Color, hold: float, sub := "") -> void:
	# WK-124: the goal banner (the show_center right after goal_scored) stays up across the goal freeze AND the
	# kickoff pop-in, popping out as the countdown's "3" replaces it. The runner's hold only covers the (now
	# shorter) freeze; the readable time grows from 1.4 s to 1.6 s while the restart shrinks.
	_goal_banner_live = _goal_banner_next
	_goal_banner_next = false
	var mode = _runner._mode if _runner != null else null
	if _goal_banner_live and hold >= 0.0 and mode != null and mode.has_method("goal_banner_span"):
		var span: float = float(mode.goal_banner_span(_runner))
		hold = maxf(hold, span - POP_IN - POP_OUT)
	_center_prompt.visible = false
	_center_text.text = text
	_center_text.add_theme_color_override("font_color", color)
	_center_sub.text = sub
	_center_sub.visible = sub != ""
	# WK-106: the goal banner's scorer line in the credited player's team colour (consumed once); every
	# other centre line (countdown, BOUNCE!) stays the theme's white.
	if _goal_sub_color != null and sub != "":
		_center_sub.add_theme_color_override("font_color", _goal_sub_color)
	else:
		_center_sub.remove_theme_color_override("font_color")
	_goal_sub_color = null
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
		_center_tw.tween_callback(_hide_center_now)

## The runner hides the centre banner when it loads the next kickoff (PartyMatch._begin_stage, called while the
## state is still STAGE_END). WK-124: the goal banner deliberately overlaps that reset, so that one call is ignored
## while it is up; its own tween (or the "3" beat / match-end panel) takes it down.
func hide_center() -> void:
	if _goal_banner_live and _runner != null and str(_runner.state) == "STAGE_END":
		return
	_hide_center_now()

func _hide_center_now() -> void:
	_goal_banner_live = false
	if _center_tw != null and _center_tw.is_valid():
		_center_tw.kill()
	_center_box.visible = false
	_center_box.modulate.a = 1.0
	_center_box.scale = Vector2.ONE
	_center_prompt.visible = false
	_match_panel.visible = false

# ------------------------------------------------------------------ MATCH END (team-wins panel)
func show_match_end(text: String, color: Color, subline: String) -> void:
	hide_center()
	var mode = _runner._mode if _runner != null else null
	if mode != null and mode.has_method("match_stats"):
		_show_victory(mode)
		return
	_clear_match_buttons()
	_gate.open()   # the end screen "appears" now: presses must begin after this and the row arms >= 1.0 s later
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

## WK-111 (SP-09): frame the winning team in the world (SportsMode.present_match_end replaces the runner's 1.1
## punch-zoom target and pops every winner), then after VICTORY_DELAY present the SportsVictory end screen with
## SportsMode.match_stats. Its three signals map onto the runner's existing match_button_pressed ids.
func _show_victory(mode) -> void:
	_victory_on = true
	_clear_match_buttons()
	if mode.has_method("present_match_end"):
		mode.present_match_end(_runner)
	if _victory == null:
		_victory = VICTORY_SCENE.instantiate()
		add_child(_victory)
		_victory.rematch_pressed.connect(func() -> void:
			_dismiss_victory()
			match_button_pressed.emit(&"rematch"))
		_victory.setup_pressed.connect(func() -> void: match_button_pressed.emit(&"setup"))
		_victory.menu_pressed.connect(func() -> void: match_button_pressed.emit(&"menu"))
	var tw := create_tween()
	tw.tween_interval(VICTORY_DELAY)
	tw.tween_callback(func() -> void:
		if not _victory_on or _runner == null or str(_runner.state) != "MATCH_END":
			return
		_chip.visible = false   # the tray's score plate carries the final score
		_victory.present(mode.match_stats(_runner)))

func _dismiss_victory() -> void:
	_victory_on = false
	_chip.visible = true
	if _victory != null and _victory.is_live():
		_victory.dismiss()

## QA (gbplay eval): the live SportsVictory, or null.
func victory_screen():
	return _victory

# ------------------------------------------------------------------ MATCH END button row (VictoryScreen bar)
## Build a real focusable button row inside the MatchPanel — the actionable end-state, NOT a caption.
## specs = [{ "text": String, "id": StringName }, ...]; first button takes default focus + the primary
## style, the LAST button is the safe menu_back target. Mirrors VictoryScreen's focus juice exactly.
## PartyMatch calls this once, after its PROMPT_GUARD arm lock, and wires match_button_pressed.
func show_match_buttons(specs: Array) -> void:
	if _victory_on:
		return   # WK-111: the SportsVictory row is the match-end row (its own gate arms it)
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

# ------------------------------------------------------------------ TOP banner (transient)
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
