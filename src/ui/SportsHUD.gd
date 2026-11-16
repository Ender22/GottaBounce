extends CanvasLayer
## SPORTS HUD (docs/specs/v5_sports_mode.md §5, chip rework per owner list 2026-07-18 item 1).
## Built from SportsHUD.tscn + assets/ui/theme.tres. The score readout is ONE compact color-coded
## pill TOP-CENTER — red number | dash | blue number with a tiny "TO N" cap line — replacing the two
## huge side panels that ate the screen. WK-35 (SP-18, kit B): a cream ToyHudPlate holding two team-colour halves
## ([RED 3] TO 6 [2 BLUE]) — colour is the FILL, white digits + team names with the chocolate outline, the cap in
## chocolate at 30 px (the old ~14 px "TO 6" broke the 28 px floor). The scoring half flashes on the WK-106 pop.
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
const FocusRow := preload("res://src/ui/FocusRow.gd")
const RED := Color("#ff4b6a")
const BLUE := Color("#3fa9ff")
const MATCH_BTN_MIN := Vector2(380, 90)   # WK-14/WK-42: fits the focused (primary, 46 px) label, so a focus move never resizes the row
# WK-111 (SP-09): the sports end screen. show_match_end presents it (when the mode has match_stats) instead of the
# old centre panel; it owns the REMATCH / CHANGE SETUP / QUIT row and its input from then on.
const VICTORY_SCENE := preload("res://scenes/ui/SportsVictory.tscn")
const VICTORY_DELAY := 0.9     # = PartyMatch.VICTORY_DELAY: the in-world winning-team frame breathes first
const ToyKit := preload("res://src/ui/ToyKit.gd")
const FUEL_ARC := preload("res://src/ui/SportsFuelArc.gd")   # WK-183 per-goat fuel arc

var _runner   # PartyMatch (untyped so mode/state member access is dynamic — no runner class edit)
var _center_tw: Tween
var _top_tw: Tween
var _flash_tw: Tween
var _pop_tw: Tween
var _goal_sub_color: Variant = null   # WK-106: scorer-line colour for the NEXT show_center (set by goal_scored)
var _goal_banner_next := false        # WK-124: the NEXT show_center is the goal banner (set by goal_scored)
var _goal_banner_live := false        # WK-124: the goal banner is up and rides over the kickoff reset

@onready var _red_score: Label = $Root/ScoreChip/ChipBox/RedHalf/Box/RedScore
@onready var _blue_score: Label = $Root/ScoreChip/ChipBox/BlueHalf/Box/BlueScore
@onready var _red_half: PanelContainer = $Root/ScoreChip/ChipBox/RedHalf
@onready var _blue_half: PanelContainer = $Root/ScoreChip/ChipBox/BlueHalf
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
# --- WK-110 (SP-08) kickoff tension plate (cream ToyHudPlate in the top band): MATCH POINT + team pill / GOLDEN GOAL + sub-line ---
@onready var _tension_plate: PanelContainer = $Root/TopBand/TopCenter/TensionPlate   # WK-110
@onready var _tension_title: Label = $Root/TopBand/TopCenter/TensionPlate/TensionBox/TensionRow/TensionTitle   # WK-110
@onready var _tension_pill: PanelContainer = $Root/TopBand/TopCenter/TensionPlate/TensionBox/TensionRow/TensionPill   # WK-110
@onready var _tension_team: Label = $Root/TopBand/TopCenter/TensionPlate/TensionBox/TensionRow/TensionPill/TensionTeam   # WK-110
@onready var _tension_sub: Label = $Root/TopBand/TopCenter/TensionPlate/TensionBox/TensionSub   # WK-110
var _tension_tw: Tween = null          # WK-110
var _tension_stage := -1               # WK-110: stage_index whose countdown already asked (one call per kickoff)
var tension_log: Array = []            # WK-110 QA: [{stage, kind, title, team, scores, msec}] per plate shown this match

func _ready() -> void:
	_runner = get_parent()
	# WK-11 (CC-10.2 / CC-3.3): the REMATCH row only takes FRESH presses from JOINED devices, >= 1.0 s
	# after the match-end panel appears (opened in show_match_end).
	_gate = MenuInputGate.new()
	_gate.name = "InputGate"
	add_child(_gate)
	_gate.verb.connect(_on_match_verb)
	_flash.visible = false
	ToyKit.fill_panel(_red_half, RED)     # WK-35: team colour is the half's fill; digits stay white
	ToyKit.fill_panel(_blue_half, BLUE)
	# WK-106: THE goal event (one per goal, same-team repeats included) drives the flash + score pop.
	if not EventBus.goal_scored.is_connected(_on_goal_scored):
		EventBus.goal_scored.connect(_on_goal_scored)

# ------------------------------------------------------------------ runner-called HUD surface
func setup(players: Array, _colors: Array, _skins: Array) -> void:
	# SPORTS shows TEAM scores (polled), not per-player cards.
	# WK-183: ...but every goat carries its own fuel arc (team colour, WK-99 super notch, refund tick) in the world.
	if Tuning.wk183_arc_on:   # WK-183
		var runner: Node = _runner if _runner != null else get_parent()   # WK-183
		var layer: Node2D = runner.get_node_or_null("WK183FuelArcs") as Node2D   # WK-183
		if layer == null:   # WK-183: ONE shared arc layer, after the level and BEFORE the first goat in the runner's tree
			layer = Node2D.new()   # WK-183
			layer.name = "WK183FuelArcs"   # WK-183
			runner.add_child(layer)   # WK-183
			var first := runner.get_child_count()   # WK-183
			for p in players:   # WK-183
				if p != null and is_instance_valid(p) and (p as Node).get_parent() == runner:   # WK-183
					first = mini(first, (p as Node).get_index())   # WK-183
			runner.move_child(layer, mini(first, runner.get_child_count() - 1))   # WK-183
		for i in range(players.size()):   # WK-183
			var p = players[i]   # WK-183
			if p == null or not is_instance_valid(p) or FUEL_ARC.of(p) != null:   # WK-183
				continue   # WK-183
			var arc: Node2D = FUEL_ARC.new()   # WK-183
			arc.setup(p, runner, i)   # WK-183
			arc.attach(layer)   # WK-183: under every goat body (tree order), over the floor

## WK-183 QA readout (gbplay eval): every goat's fuel arc state.
func fuel_arc_state() -> Array:   # WK-183
	var out: Array = []   # WK-183
	var ps: Variant = _runner.get("players") if _runner != null else null   # WK-183
	if ps is Array:   # WK-183
		for p in (ps as Array):   # WK-183
			var arc = FUEL_ARC.of(p)   # WK-183
			out.append(arc.debug_state() if arc != null else {})   # WK-183
	return out   # WK-183

func reset_scores() -> void:
	_dismiss_victory()   # WK-111: a REMATCH re-runs _start_match -> reset_scores
	_goal_sub_color = null
	_goal_banner_next = false
	_tension_stage = -1   # WK-110: a REMATCH starts again at stage 1
	tension_log = []   # WK-110
	_hide_tension_now()   # WK-110
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
	_poll_tension(mode)   # WK-110

## WK-110 (SP-08): once per kickoff, the moment the countdown starts (the goal banner pops out on that "3"), ask the mode
## whether this kickoff is MATCH POINT / GOLDEN GOAL and pop the plate. Stage 1 never qualifies (cap >= 2 needs a goal first).
func _poll_tension(mode) -> void:   # WK-110
	if not Tuning.wk110_tension_banner or not mode.has_method("tension_banner"):
		return
	var st: String = str(_runner.state)
	var si: int = int(_runner.stage_index)
	if st == "STAGE_END" and _tension_plate.visible:
		_hide_tension_now()   # a goal inside the plate's tail: the goal banner owns the screen
	if st != "COUNTDOWN" or si == _tension_stage:
		return
	_tension_stage = si
	var b: Dictionary = mode.tension_banner()
	if not b.is_empty():
		show_tension(b)

## WK-110: pop the tension plate. b = SportsMode.tension_banner(): {kind, team, title, sub, team_name?, color?}.
func show_tension(b: Dictionary) -> void:   # WK-110
	var golden: bool = str(b.get("kind", "")) == "golden_goal"
	_tension_title.text = str(b.get("title", ""))
	if golden:
		_tension_title.add_theme_color_override("font_color", Tuning.wk110_golden_color)
	else:
		_tension_title.remove_theme_color_override("font_color")   # BannerTop white + chocolate outline
	_tension_pill.visible = not golden and str(b.get("team_name", "")) != ""
	if _tension_pill.visible:
		ToyKit.id_pill(_tension_pill, _tension_team, str(b["team_name"]), b.get("color", Color.WHITE))
	_tension_sub.text = str(b.get("sub", ""))
	_tension_sub.visible = _tension_sub.text != ""
	if _top_tw != null and _top_tw.is_valid():   # one top-band banner at a time (a stray word would sit under the plate)
		_top_tw.kill()
	_top_label.visible = false
	_tension_plate.visible = true
	_tension_plate.modulate.a = 1.0
	_tension_plate.reset_size()
	await get_tree().process_frame   # the container sizes the plate this frame; pivot on the real size
	if not _tension_plate.visible:
		return
	_tension_plate.pivot_offset = _tension_plate.size * 0.5
	_tension_plate.scale = Vector2(0.3, 0.3)
	if _tension_tw != null and _tension_tw.is_valid():
		_tension_tw.kill()
	_tension_tw = create_tween()
	_tension_tw.tween_property(_tension_plate, "scale", Vector2.ONE, POP_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tension_tw.tween_interval(Tuning.wk110_banner_hold)
	_tension_tw.tween_property(_tension_plate, "modulate:a", 0.0, POP_OUT)
	_tension_tw.parallel().tween_property(_tension_plate, "scale", Vector2(1.08, 1.08), POP_OUT)
	_tension_tw.tween_callback(_hide_tension_now)
	var sc: Array = _runner._mode.team_scores() if _runner != null and _runner._mode != null else []
	tension_log.append({"stage": int(_runner.stage_index) if _runner != null else -1, "kind": str(b.get("kind", "")),
		"title": _tension_title.text, "team": int(b.get("team", -1)), "scores": sc.duplicate(), "msec": Time.get_ticks_msec()})
	EventBus.sports_tension.emit(str(b.get("kind", "")))

func _hide_tension_now() -> void:   # WK-110
	if _tension_tw != null and _tension_tw.is_valid():
		_tension_tw.kill()
	_tension_plate.visible = false
	_tension_plate.modulate.a = 1.0
	_tension_plate.scale = Vector2.ONE

## WK-110 QA: true while the tension plate is up.
func tension_showing() -> bool:   # WK-110
	return _tension_plate.visible

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
	# WK-66a AD follow-up 1: a short low wash (was 0.45 alpha for 0.9 s) so the goal-net bulge, frame flash and
	# confetti stay visible. Total = in + hold + out <= 0.25 s, peak alpha <= 0.25 (Tuning WK-66a block).
	_flash_tw.tween_property(_flash, "color:a", Tuning.goal_hud_flash_alpha, Tuning.goal_hud_flash_in)   # WK-66a
	_flash_tw.tween_interval(Tuning.goal_hud_flash_hold)   # WK-66a
	_flash_tw.tween_property(_flash, "color:a", 0.0, Tuning.goal_hud_flash_out)   # WK-66a
	_flash_tw.tween_callback(func() -> void: _flash.visible = false)

## WK-16 "score tick": the scoring team's chip digit punches up (scale + white flash) and settles.
func _score_pop(team: int) -> void:
	var lbl: Label = _red_score if team == 0 else _blue_score
	var other: Label = _blue_score if team == 0 else _red_score
	var half: Control = _red_half if team == 0 else _blue_half
	var other_half: Control = _blue_half if team == 0 else _red_half
	if _runner != null and _runner._mode != null and _runner._mode.has_method("team_scores"):
		var sc: Array = _runner._mode.team_scores()
		if sc.size() >= 2:
			_red_score.text = str(int(sc[0]))
			_blue_score.text = str(int(sc[1]))
	if _pop_tw != null and _pop_tw.is_valid():
		_pop_tw.kill()
	other.scale = Vector2.ONE
	other.modulate = Color.WHITE
	other_half.modulate = Color.WHITE
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2(1.9, 1.9)
	lbl.modulate = Color(2.2, 2.2, 2.2, 1.0)
	half.modulate = Color(1.7, 1.7, 1.7, 1.0)   # the team-colour half flares (white digits can't brighten)
	_pop_tw = create_tween()
	_pop_tw.set_parallel(true)
	_pop_tw.tween_property(lbl, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pop_tw.tween_property(lbl, "modulate", Color.WHITE, 0.5)
	_pop_tw.tween_property(half, "modulate", Color.WHITE, 0.5)

## WK-117 (SP-16): the kickoff call per sport, keyed by the mode's display_name (unknown sport -> "PLAY!").
const KICKOFF_WORDS := {"ROCKETBALL": "KICK OFF!", "DROPSHOT": "SERVE!"}

func kickoff_word() -> String:
	var mode = _runner._mode if _runner != null else null
	var dn: String = str(mode.display_name()) if mode != null and mode.has_method("display_name") else ""
	return str(KICKOFF_WORDS.get(dn, "PLAY!"))

# ------------------------------------------------------------------ CENTER banner (countdown / GOAL freeze)
func show_center(text: String, color: Color, hold: float, sub := "") -> void:
	# WK-117 (SP-16): the runner's shared starting gun "BOUNCE!" is a brawl word; sports call their own kickoff.
	if text == "BOUNCE!":
		text = kickoff_word()
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
	_hide_tension_now()   # WK-110
	var mode = _runner._mode if _runner != null else null
	if mode != null and mode.has_method("match_stats"):
		_show_victory(mode)
		return
	_clear_match_buttons()
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
## specs = [{ "text": String, "id": StringName }, ...]; first button takes default focus (the primary
## style follows focus, WK-14), the LAST button is the safe menu_back target. Mirrors VictoryScreen's focus juice exactly.
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
	_match_pulse = FocusRow.row(self, _match_btns, i, _match_pulse)   # WK-14: shared focus look (CC-5.1)

func _activate_match(i: int) -> void:
	if not _match_armed or i < 0 or i >= _match_btns.size():
		return
	_match_armed = false   # one activation per row life — repeated accepts can't double-fire
	AudioManager.play_sfx("ui_click")
	match_button_pressed.emit(_match_btns[i].get_meta("id"))

# ------------------------------------------------------------------ TOP banner (transient)
func show_top(text: String, color: Color, hold: float, font_size: int = 0) -> void:
	_top_label.text = text
	_top_label.add_theme_color_override("font_color", color)
	if font_size > 0:   # WK-116: MAX PRESSURE! rides the same slot, bigger
		_top_label.add_theme_font_size_override("font_size", font_size)
	else:
		_top_label.remove_theme_font_size_override("font_size")
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

## WK-116 PRESSURE NETS word burst ("PRESSURE!" gold / "MAX PRESSURE!" red-gold, bigger): the top-centre banner slot (y 190-300 at
## 1080p, above both goal mouths on every court). Banner stacking (spec §5): if another top banner is up (a future WK-110 MATCH
## POINT / GOLDEN GOAL), the word waits for it to leave plus Tuning.sports_pressure_word_stack_wait, so two never overlap.
var pressure_words: Array = []   # WK-116 QA: words shown this match (text)
func show_pressure_word(text: String, color: Color, hold: float, font_size: int = 0) -> void:   # WK-116
	var waited: float = 0.0
	while ((_top_label.visible and _top_label.text != text) or _tension_plate.visible) and waited < 3.0:   # WK-110: the plate counts
		await get_tree().create_timer(0.1, false).timeout
		waited += 0.1
	if waited > 0.0:
		await get_tree().create_timer(Tuning.sports_pressure_word_stack_wait, false).timeout
	pressure_words.append(text)
	show_top(text, color, hold, font_size)
