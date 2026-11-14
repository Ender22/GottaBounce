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
@onready var _match_panel: PanelContainer = $Root/CenterC/MatchPanel
@onready var _match_text: Label = $Root/CenterC/MatchPanel/MatchBox/MatchText
@onready var _match_sub: Label = $Root/CenterC/MatchPanel/MatchBox/MatchSub
@onready var _pops = $Root/CreditPops   # WK-25 KOCreditPop.gd (last child of Root: drawn over the cards)

func setup(players: Array, colors: Array, skins: Array) -> void:
	_players = players
	_cards = [$Root/Card0, $Root/Card1, $Root/Card2, $Root/Card3]
	# WK-02: one card per REAL fighter; corners with no player are hidden (no ghost "P1" cards, and
	# no out-of-bounds colors[i]/skins[i] read when fewer than 4 fight). The roster cap
	# (MatchConfig.MAX_FIGHTERS == 4 == corner count) guarantees a 5th card is never needed.
	for i in range(_cards.size()):
		var used: bool = i < players.size()
		_cards[i].visible = used
		if used:
			var col: Color = colors[i] if i < colors.size() else Color.WHITE
			var skin: String = str(skins[i]) if i < skins.size() else "pink"
			_cards[i].setup(i, col, skin)

## WK-10/WK-88 (CC-8.5): per-card NAME from PartyMatch.player_names() ("P3" / "VEX") + optional sub-tags
## from player_subtags() (goat name / "CPU").
func set_labels(labels: Array, subs: Array = []) -> void:
	for i in range(mini(labels.size(), _cards.size())):
		_cards[i].set_label(str(labels[i]), str(subs[i]) if i < subs.size() else "")

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

## WK-37 ghost goats: card i shows the ghost head (+ the puff ring when `ring`). Off = back to the skull/alive look via
## set_dead. Presentation only (GhostDirector calls these).
func set_ghost(i: int, on: bool, ring: bool) -> void:
	if i >= 0 and i < _cards.size() and _cards[i].has_method("set_ghost"):
		_cards[i].set_ghost(on, ring)

func set_ghost_ring(i: int, frac: float, hushed: bool, spent: bool) -> void:
	if i >= 0 and i < _cards.size() and _cards[i].has_method("set_ghost_ring"):
		_cards[i].set_ghost_ring(frac, hushed, spent)

## WK-37: card i's screen rect (the ghost legend sits beside it). Empty Rect2 for an unused corner.
func card_rect(i: int) -> Rect2:
	if i >= 0 and i < _cards.size() and _cards[i].visible:
		return (_cards[i] as Control).get_global_rect()
	return Rect2()

func reset_scores() -> void:
	for c in _cards:
		c.set_score(0)
		c.set_dead(false)
	if _pops != null:
		_pops.clear()

## WK-25 KO credit pop (audit D-02): a transient "+1" / "OOPS!" / "−1" chip that flies from the KO edge blast into
## card `card_idx` (killer for "+1", victim otherwise). kind: "plus" | "oops" | "minus". loc =
## KOEdgeBlast.locate(victim). Shows the CHANGE only, never a total (owner 2026-07-16: no persistent combat score).
func credit_pop(card_idx: int, kind: String, text: String, color: Color, loc: Dictionary, meta: Dictionary = {}) -> void:
	if _pops == null or card_idx < 0 or card_idx >= _cards.size() or not _cards[card_idx].visible:
		return
	var m := meta.duplicate()
	m["card"] = card_idx
	_pops.pop(kind, _cards[card_idx], text, color, loc, m)

## QA: the credit-pop log (KOCreditPop.pops) — gbplay eval reads this.
func credit_pops() -> Array:
	return _pops.pops if _pops != null else []

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
	_match_panel.visible = false

## MATCH_END (lethality spec §7): banner + scoreline on the chunky backing panel
## (MatchPanel in MatchHUD.tscn, MatchEndPanel theme variation) — legible over ANY frozen chaos.
## BRAWL routes match-end to VictoryScreen (with real focusable buttons); this panel is the
## Sports/Trials backing that PartyMatch tops with show_match_buttons.
## The panel outline takes the winner's color.
func show_match_end(text: String, color: Color, scoreline: String) -> void:
	hide_center()
	_match_text.text = text
	_match_text.add_theme_color_override("font_color", color)
	_match_sub.text = scoreline
	var sb := _match_panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var sb2: StyleBoxFlat = sb.duplicate()
		sb2.border_color = color
		_match_panel.add_theme_stylebox_override("panel", sb2)
	_match_panel.visible = true
	_match_panel.modulate.a = 1.0
	_match_panel.reset_size()
	_match_panel.pivot_offset = _match_panel.size * 0.5
	_match_panel.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(_match_panel, "scale", Vector2.ONE, POP_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

## WK-41: the stage is over — drop any in-flight / queued top-band announcer line (TWO LEFT!, FIRST BLOOD!) so it
## never sits on top of the STAGE_END banner or leaks into the score screen. Called only on the BRAWL ceremony path.
func clear_top() -> void:
	if _top_tw != null and _top_tw.is_valid():
		_top_tw.kill()
	_top_queue.clear()
	_top_label.visible = false
	_top_busy = false

## QA overlay audit (WK-41): is a banner actually on screen this frame?
func center_showing() -> bool:
	return _center_box.visible and _center_box.modulate.a > 0.02

func top_showing() -> bool:
	return _top_label.visible and _top_label.modulate.a > 0.02

func _top_done() -> void:
	_top_label.visible = false
	_top_busy = false
	if _top_queue.size() > 0:
		var next: Array = _top_queue.pop_front()
		_run_top(next[0], next[1], next[2])
