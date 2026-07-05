extends CanvasLayer
## TRIALS HUD (docs/specs/v3_content_plan.md B.3). Built from TrialsHUD.tscn + assets/ui/theme.tres
## (Glossy Toybox — chunky rounded panels, chocolate outlines, oversized type; no OS-default widgets).
## Replaces MatchHUD for the TRIALS mode: a big ticking RUN TIMER, the medal thresholds + provisional
## medal, best time, fall/attempt counter, and a fuel gauge. NO player cards, NO score pips, NO bots.
##
## It fills the SAME method surface PartyMatch calls on a HUD (setup / reset_scores / hide_center /
## set_dead / show_center / animate_scores / show_top / show_match_end / show_match_prompt) so the
## runner drives it unchanged; the score-oriented ones are no-ops. Live readouts poll the runner + the
## active TrialsMode via get_parent() (the runner) each frame.

const POP_IN := 0.15
const POP_OUT := 0.2

var _runner   # PartyMatch (untyped so mode/state member access is dynamic — no runner class edit)
var _center_tw: Tween
var _top_tw: Tween

@onready var _time_label: Label = $Root/TimerPanel/TimerBox/TimeLabel
@onready var _medal_label: Label = $Root/TimerPanel/TimerBox/StatsRow/MedalLabel
@onready var _thresholds_label: Label = $Root/TimerPanel/TimerBox/StatsRow/ThreshLabel
@onready var _best_label: Label = $Root/TimerPanel/TimerBox/StatsRow/BestLabel
@onready var _falls_label: Label = $Root/TimerPanel/TimerBox/StatsRow/FallsLabel
@onready var _fuel_fill: Panel = $Root/FuelWrap/FuelBg/FuelFill
@onready var _fuel_bg: Panel = $Root/FuelWrap/FuelBg

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

# ------------------------------------------------------------------ runner-called HUD surface
func setup(_players: Array, _colors: Array, _skins: Array) -> void:
	pass   # TRIALS has no per-player cards; live readouts poll the runner in _process

func reset_scores() -> void:
	pass   # no score pips in TRIALS

func set_dead(_i: int, _dead: bool) -> void:
	pass   # a fall is a respawn, not a death card

func animate_scores(_new_scores: Array) -> void:
	pass   # no score pips in TRIALS

# ------------------------------------------------------------------ live readouts
func _process(_delta: float) -> void:
	if _runner == null:
		return
	var mode = _runner._mode
	if mode == null:
		return
	var t: float = float(mode.current_time(_runner))
	_time_label.text = "%.2f" % t
	var medal: String = str(mode.medal_for(t))
	_medal_label.text = "—" if medal == "none" else medal.to_upper()
	_medal_label.add_theme_color_override("font_color", mode.medal_color(medal))
	var mt: Dictionary = mode.medal_times()
	if mt.is_empty():
		_thresholds_label.text = ""
	else:
		_thresholds_label.text = "G %.1f   S %.1f   B %.1f" % [
			float(mt.get("gold", 0.0)), float(mt.get("silver", 0.0)), float(mt.get("bronze", 0.0))]
	var best: float = float(mode.best_time())
	_best_label.text = "BEST %.2f" % best if best > 0.0 else "BEST --"
	_falls_label.text = "FALLS %d" % int(mode.attempts)
	# fuel gauge from the lone human
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

# ------------------------------------------------------------------ TOP banner (transient — unused by TRIALS but part of the surface)
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
