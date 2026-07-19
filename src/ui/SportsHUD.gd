extends CanvasLayer
## SPORTS HUD (docs/specs/v5_sports_mode.md §5, chip rework per owner list 2026-07-18 item 1).
## Built from SportsHUD.tscn + assets/ui/theme.tres. The score readout is ONE compact color-coded
## pill TOP-CENTER — red number | dash | blue number with a tiny "TO N" cap line — replacing the two
## huge side panels that ate the screen. Navy chip, chocolate outline, chunky type (theme grammar).
## Full-screen team-colored flash + "GOAL!"/"POINT!" (mode goal_word) on last_scoring_team change.
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

var _runner   # PartyMatch (untyped so mode/state member access is dynamic — no runner class edit)
var _center_tw: Tween
var _top_tw: Tween
var _flash_tw: Tween
var _shown_scoring := -2   # last last_scoring_team we flashed for (-2 = uninitialized)

@onready var _red_score: Label = $Root/ScoreChip/ChipBox/Scores/RedScore
@onready var _blue_score: Label = $Root/ScoreChip/ChipBox/Scores/BlueScore
@onready var _cap: Label = $Root/ScoreChip/ChipBox/CapLabel
@onready var _flash: ColorRect = $Root/GoalFlash
@onready var _flash_label: Label = $Root/GoalFlashLabel

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

func _ready() -> void:
	_runner = get_parent()
	_flash.visible = false
	_flash_label.visible = false
	_red_score.add_theme_color_override("font_color", RED)
	_blue_score.add_theme_color_override("font_color", BLUE)

# ------------------------------------------------------------------ runner-called HUD surface
func setup(_players: Array, _colors: Array, _skins: Array) -> void:
	pass   # SPORTS shows TEAM scores (polled), not per-player cards

func reset_scores() -> void:
	_shown_scoring = -2
	_red_score.text = "0"
	_blue_score.text = "0"

func set_dead(_i: int, _dead: bool) -> void:
	pass   # players never die in SPORTS (respawn); no death card

func animate_scores(_new_scores: Array) -> void:
	pass   # kill-race scores are unused in SPORTS; team scores poll the mode

# ------------------------------------------------------------------ live readouts
func _process(_delta: float) -> void:
	if _match_armed:
		_match_input()
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
	# GOAL flash on a scoring-team change
	var last: int = int(mode.last_scoring_team())
	if last != _shown_scoring:
		if last >= 0 and _shown_scoring != -2:
			_goal_flash(last)
		_shown_scoring = last

func _goal_flash(team: int) -> void:
	var col: Color = RED if team == 0 else BLUE
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_flash.color = Color(col.r, col.g, col.b, 0.0)
	_flash.visible = true
	var word := "GOAL!"
	if _runner != null and _runner._mode != null and _runner._mode.has_method("goal_word"):
		word = str(_runner._mode.goal_word())
	_flash_label.text = word
	_flash_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_flash_label.visible = true
	_flash_label.modulate.a = 1.0
	_flash_label.reset_size()
	_flash_label.pivot_offset = _flash_label.size * 0.5
	_flash_label.scale = Vector2(0.4, 0.4)
	_flash_tw = create_tween()
	_flash_tw.set_parallel(true)
	_flash_tw.tween_property(_flash, "color:a", 0.45, 0.10)
	_flash_tw.tween_property(_flash_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tw.chain().tween_interval(0.5)
	_flash_tw.chain().tween_property(_flash, "color:a", 0.0, 0.3)
	_flash_tw.parallel().tween_property(_flash_label, "modulate:a", 0.0, 0.3)
	_flash_tw.chain().tween_callback(func() -> void:
		_flash.visible = false
		_flash_label.visible = false)

# ------------------------------------------------------------------ CENTER banner (countdown / GOAL freeze)
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

# ------------------------------------------------------------------ MATCH END (team-wins panel)
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
