extends CanvasLayer
## GAUNTLET HUD (docs/specs/v4_gauntlet_mode.md §3.2). Built from GauntletHUD.tscn + assets/ui/theme.tres
## (chunky rounded panels, chocolate outlines, oversized type; no OS-default widgets). Shows the WAVE
## number / of M, ENEMIES REMAINING, and the shared DEFENDER LIVES as chunky heart pips. NO per-bot
## cards (sidesteps the dynamic-roster HUD churn entirely).
##
## It fills the SAME method surface PartyMatch calls on a HUD (setup / reset_scores / hide_center /
## set_dead / show_center / animate_scores / show_top / show_match_end / show_match_prompt) so the runner
## drives it unchanged; the score-oriented ones are no-ops. Live readouts poll the runner + the active
## GauntletMode via get_parent() (the runner) each frame.

const POP_IN := 0.15
const POP_OUT := 0.2
const MAX_PIPS := 10   # visible defender-life pips; a larger pool folds into a "+N" numeral

var _runner   # PartyMatch (untyped so mode/state member access is dynamic — no runner class edit)
var _center_tw: Tween
var _top_tw: Tween
var _pips: Array = []
var _announce_wave := -1

@onready var _wave_label: Label = $Root/WavePanel/WaveBox/WaveLabel
@onready var _of_label: Label = $Root/WavePanel/WaveBox/StatsRow/OfLabel
@onready var _enemies_label: Label = $Root/WavePanel/WaveBox/StatsRow/EnemiesLabel
@onready var _lives_caption: Label = $Root/LivesWrap/LivesBox/Caption
@onready var _pip_row: HBoxContainer = $Root/LivesWrap/LivesBox/PipRow
@onready var _pip_extra: Label = $Root/LivesWrap/LivesBox/PipRow/ExtraLabel
@onready var _announce: Label = $Root/AnnounceC/Announce

@onready var _center_box: VBoxContainer = $Root/CenterC/CenterBox
@onready var _center_text: Label = $Root/CenterC/CenterBox/CenterText
@onready var _center_sub: Label = $Root/CenterC/CenterBox/CenterSub
@onready var _center_prompt: Label = $Root/CenterC/CenterBox/CenterPrompt
@onready var _top_label: Label = $Root/TopBand/TopCenter/TopBanner
@onready var _match_panel: PanelContainer = $Root/CenterC/MatchPanel
@onready var _match_text: Label = $Root/CenterC/MatchPanel/MatchBox/MatchText
@onready var _match_sub: Label = $Root/CenterC/MatchPanel/MatchBox/MatchSub
@onready var _match_prompt: Label = $Root/CenterC/MatchPanel/MatchBox/MatchPrompt

func _ready() -> void:
	_runner = get_parent()
	_build_pips()

# ------------------------------------------------------------------ runner-called HUD surface
func setup(_players: Array, _colors: Array, _skins: Array) -> void:
	pass   # GAUNTLET has no per-player cards; live readouts poll the runner in _process

func reset_scores() -> void:
	pass   # no score pips in GAUNTLET

func set_dead(_i: int, _dead: bool) -> void:
	pass   # a bot elimination / human respawn is not a persistent death card

func animate_scores(_new_scores: Array) -> void:
	pass   # no score pips in GAUNTLET

# ------------------------------------------------------------------ live readouts
func _process(_delta: float) -> void:
	if _runner == null:
		return
	var mode = _runner._mode
	if mode == null:
		return
	var wave: int = int(mode.current_wave(_runner))
	var total: int = int(mode.wave_count())
	_wave_label.text = "WAVE %d" % wave
	_of_label.text = "OF %d" % total
	_enemies_label.text = "%d LEFT" % int(mode.enemies_remaining(_runner))
	_update_pips(int(mode.defender_lives))
	# WAVE N intro announce during STAGE_INTRO/COUNTDOWN (the re-arming beat) — pops once per wave
	var st: String = str(_runner.state)
	var show_announce: bool = st == "STAGE_INTRO" or st == "COUNTDOWN"
	if show_announce and _announce_wave != wave:
		_announce_wave = wave
		_announce.text = "WAVE %d" % wave
		_pop_announce()
	elif not show_announce and st != "STAGE_INTRO" and st != "COUNTDOWN":
		if st == "COMBAT" or st == "MATCH_END":
			_announce_wave = -1

# ------------------------------------------------------------------ defender-life pips
func _build_pips() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#ff4b6a")
	sb.border_color = Color(0.231373, 0.141176, 0.105882, 1)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	for i in range(MAX_PIPS):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(40, 40)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override("panel", sb)
		_pip_row.add_child(pip)
		_pip_row.move_child(pip, i)   # keep pips before the ExtraLabel
		_pips.append(pip)

func _update_pips(lives: int) -> void:
	for i in range(_pips.size()):
		_pips[i].visible = i < lives
	if lives > MAX_PIPS:
		_pip_extra.visible = true
		_pip_extra.text = "+%d" % (lives - MAX_PIPS)
	else:
		_pip_extra.visible = false

func _pop_announce() -> void:
	_announce.visible = true
	_announce.modulate.a = 1.0
	_announce.reset_size()
	_announce.pivot_offset = _announce.size * 0.5
	_announce.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(_announce, "scale", Vector2.ONE, POP_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(_announce, "modulate:a", 0.0, POP_OUT)
	tw.tween_callback(func() -> void: _announce.visible = false)

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

# ------------------------------------------------------------------ MATCH END (victory / defeat panel)
func show_match_end(text: String, color: Color, subline: String) -> void:
	hide_center()
	_match_text.text = text
	_match_text.add_theme_color_override("font_color", color)
	_match_sub.text = subline
	_match_prompt.visible = false
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

func show_match_prompt(text: String) -> void:
	_match_prompt.text = text
	_match_prompt.visible = true

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
