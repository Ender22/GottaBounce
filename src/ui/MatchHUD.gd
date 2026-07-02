extends CanvasLayer
## Match HUD (spec §3): the four corner cards (identity + 2x5 score pips + fuel bar) and the
## two-position banner system. Built from MatchHUD.tscn + assets/ui/theme.tres (Glossy Toybox:
## chunky rounded cards, chocolate outlines, oversized type — never OS-default widgets).
##
## Prime directive (Pillar 5): no persistent pixels inside the middle 60% x 60% of the screen.
## CENTER banners are only shown while gameplay is frozen / pre-round; TOP-BAND banners are the
## transient mid-combat announcer (FIRST BLOOD / TWO LEFT / SUDDEN DEATH / MATCH POINT).

const POP_IN := 0.15    # banner pop-in (spec §3)
const POP_OUT := 0.2    # banner pop-out
const TOP_QUEUE_MAX := 2

var _players: Array = []
var _cards: Array = []
var _center_tw: Tween
var _top_tw: Tween
var _top_queue: Array = []
var _top_busy := false

@onready var _center_box: VBoxContainer = $Root/CenterC/CenterBox
@onready var _center_text: Label = $Root/CenterC/CenterBox/CenterText
@onready var _center_sub: Label = $Root/CenterC/CenterBox/CenterSub
@onready var _center_prompt: Label = $Root/CenterC/CenterBox/CenterPrompt
@onready var _top_label: Label = $Root/TopBand/TopCenter/TopBanner

func setup(players: Array, colors: Array, skins: Array) -> void:
	_players = players
	_cards = [$Root/Card0, $Root/Card1, $Root/Card2, $Root/Card3]
	for i in range(_cards.size()):
		_cards[i].setup(i, colors[i], skins[i])

func _process(_delta: float) -> void:
	# fuel gauges + held-powerup icons track the players live (v0 spec §3 / v1_powerups §2)
	for i in range(mini(_players.size(), _cards.size())):
		var p = _players[i]
		if is_instance_valid(p):
			_cards[i].set_fuel(p.get_fuel_ratio(), p.fuel_locked)
			_cards[i].set_powerup(p.held_powerup)

func set_dead(i: int, dead: bool) -> void:
	if i >= 0 and i < _cards.size():
		_cards[i].set_dead(dead)

func reset_scores() -> void:
	for c in _cards:
		c.set_score(0)
		c.set_dead(false)

## ROUND_END: every card animates its pips toward the new truth, tick-tick (spec §1).
func animate_scores(new_scores: Array) -> void:
	for i in range(mini(new_scores.size(), _cards.size())):
		_cards[i].animate_score(int(new_scores[i]))

## CENTER banner (allowed only while frozen / pre-round). hold < 0 = sticky (MATCH_END).
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

func show_match_end(text: String, color: Color, scoreline: String) -> void:
	show_center(text, color, -1.0, scoreline)

func show_match_prompt(text: String) -> void:
	_center_prompt.text = text
	_center_prompt.visible = true

## TOP-BAND banner (upper 15%, mid-combat — never blocks the fight). One at a time; later
## banners queue (max 2, oldest dropped — spec §3).
func show_top(text: String, color: Color, hold: float) -> void:
	if _top_busy:
		if _top_queue.size() >= TOP_QUEUE_MAX:
			_top_queue.pop_front()
		_top_queue.append([text, color, hold])
		return
	_run_top(text, color, hold)

func _run_top(text: String, color: Color, hold: float) -> void:
	_top_busy = true
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
	_top_tw.parallel().tween_property(_top_label, "scale", Vector2(1.2, 1.2), POP_OUT)
	_top_tw.tween_callback(_top_done)

func _top_done() -> void:
	_top_label.visible = false
	_top_busy = false
	if _top_queue.size() > 0:
		var next: Array = _top_queue.pop_front()
		_run_top(next[0], next[1], next[2])
