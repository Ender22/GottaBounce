extends CanvasLayer
## STAGE INTRO CARD (match_ceremony brief §1). "STAGE 3" chocolate ribbon + big arena name +
## gold underline, riding ON TOP of the existing STAGE_INTRO pop-in/countdown window. It NEVER
## gates state (adding time here is a design REJECT — the no-added-time rule IS the skip):
## PartyMatch presents it at _begin_stage() and exits it on the first countdown beat.
## Suppressed for sudden-death revives / tiebreakers by the caller (those own the drama).
## WK-15 (D-04/D-13): on stage 1 the caller passes the mode's one-line rule ("SMASH 'EM OFF-SCREEN · FIRST
## TO 10 KOs") — it lands under the gold underline. Other stages pass "" and the line stays hidden.

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const GOLD := Color("#ffd23f")
const DANGER := Color("#ff4b3a")
const REST_Y := 100.0          # card top at rest (vertical center of the block ≈ y 190)

@onready var _card: VBoxContainer = $Root/Card
@onready var _ribbon: PanelContainer = $Root/Card/RibbonSlot/Ribbon
@onready var _ribbon_label: Label = $Root/Card/RibbonSlot/Ribbon/RibbonLabel
@onready var _name_label: Label = $Root/Card/NameL
@onready var _underline: Panel = $Root/Card/UnderlineSlot/Underline
@onready var _rule_label: Label = $Root/Card/RuleL

var _tw: Tween
var _bob: Tween

func _ready() -> void:
	visible = false

func present(stage_num: int, arena_name: String, match_point: bool, rule: String = "") -> void:
	visible = true
	_kill_tweens()
	_ribbon_label.text = ("STAGE %d — MATCH POINT" % stage_num) if match_point else ("STAGE %d" % stage_num)
	var sb: StyleBoxFlat = _ribbon.get_theme_stylebox("panel").duplicate()
	sb.bg_color = DANGER if match_point else CHOCO
	_ribbon.add_theme_stylebox_override("panel", sb)
	var nm := arena_name.to_upper()
	_name_label.text = nm
	# long-name autoshrink (never two lines): 84 -> floor 56 (brief §1 degraded states)
	var fs := 84
	if nm.length() > 22:
		fs = 56
	elif nm.length() > 16:
		fs = 68
	_name_label.add_theme_font_size_override("font_size", fs)
	_rule_label.text = rule
	_rule_label.visible = rule != ""
	_rule_label.modulate.a = 0.0
	_card.modulate.a = 0.0
	_name_label.scale = Vector2(0.6, 0.6)
	_underline.scale = Vector2(0.0, 1.0)
	await get_tree().process_frame   # let the VBox lay out the new name text
	if not visible:
		return   # exited during the layout frame
	_underline.custom_minimum_size.x = clampf(_name_label.size.x * 0.6, 120.0, 900.0)
	await get_tree().process_frame   # second frame: underline width applied before pivots
	if not visible:
		return
	_card.position.y = REST_Y - 120.0
	_name_label.pivot_offset = _name_label.size * 0.5
	_underline.pivot_offset = _underline.size * 0.5
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(_card, "position:y", REST_Y, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	_tw.tween_property(_name_label, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.10)
	_tw.tween_property(_underline, "scale:x", 1.0, 0.22).set_ease(Tween.EASE_OUT).set_delay(0.32)
	_tw.tween_property(_rule_label, "modulate:a", 1.0, 0.16).set_delay(0.42)
	_tw.chain().tween_callback(_start_bob)
	AudioManager.play_sfx("ui_click")

func _start_bob() -> void:
	if not visible:
		return
	_bob = create_tween()
	_bob.set_loops()
	_bob.tween_property(_card, "position:y", REST_Y + 3.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(_card, "position:y", REST_Y - 3.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Pop-out on the first countdown beat: scale up + fade + upward drift, then hide.
func exit() -> void:
	if not visible:
		return
	_kill_tweens()
	_card.pivot_offset = _card.size * 0.5
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(_card, "scale", Vector2(1.15, 1.15), 0.20)
	_tw.tween_property(_card, "modulate:a", 0.0, 0.20)
	_tw.tween_property(_card, "position:y", _card.position.y - 30.0, 0.20)
	_tw.chain().tween_callback(func() -> void:
		visible = false
		_card.scale = Vector2.ONE)

## True while the card is actually on screen (QA overlay audit + WK-41 sequencing: PartyMatch holds the
## MATCH POINT top banner until this goes false, so the two never share the top of the screen).
func is_showing() -> bool:
	return visible and _card.modulate.a > 0.02

func _kill_tweens() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if _bob != null and _bob.is_valid():
		_bob.kill()
