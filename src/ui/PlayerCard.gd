extends Panel
## One corner HUD card: identity (head + P#) + fuel gauge. Glossy Toybox treatment: pastel card
## body tinted to the player skin, vivid fuel in the full skin color, dark-chocolate outlines from
## assets/ui/theme.tres. Dead-this-round = dim + skull over the head icon.
## SCORE PIPS REMOVED (owner 2026-07-16): the score display is now the between-stage ScoreScreen
## (Duck Game/TowerFall pattern) — combat carries no persistent score readout.

const FUEL_PAD := 3.0           # fill inset inside the gauge background

var _color := Color.WHITE
var _fuel_was_full := true
var _was_locked := false

@onready var _name_label: Label = $Margin/VBox/IdentityRow/NameLabel
@onready var _head: TextureRect = $Margin/VBox/IdentityRow/HeadSlot/Head
@onready var _skull: Control = $Margin/VBox/IdentityRow/HeadSlot/Skull
@onready var _fuel_bg: Panel = $Margin/VBox/FuelSlot/FuelBG
@onready var _fuel_fill: Panel = $Margin/VBox/FuelSlot/FuelFill
@onready var _pu_icon: TextureRect = $Margin/VBox/IdentityRow/PowerupSlot

var _pu_id := ""

func setup(idx: int, color: Color, skin: String) -> void:
	_color = color
	_name_label.text = "P%d" % (idx + 1)
	# card body: player color knocked toward white so the vivid pips/fuel pop against it
	var card_sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	var pastel := color.lerp(Color.WHITE, 0.58)
	pastel.a = 0.95
	card_sb.bg_color = pastel
	add_theme_stylebox_override("panel", card_sb)
	var head_path := "res://assets/characters/bouncer_%s_idle.png" % skin
	if ResourceLoader.exists(head_path):
		_head.texture = load(head_path)
	_fuel_fill.self_modulate = color

## Fuel gauge, mapped 0..1 (GDD §10 glanceable). Flashes bright when a full tank is banked —
## the super-boost-ready tell. `locked` = Unlimited Boost: the gauge glows solid (spec 3.2).
func set_fuel(r: float, locked := false) -> void:
	r = clampf(r, 0.0, 1.0)
	var w: float = maxf(0.0, _fuel_bg.size.x - FUEL_PAD * 2.0)
	_fuel_fill.size = Vector2(w * r, maxf(0.0, _fuel_bg.size.y - FUEL_PAD * 2.0))
	_fuel_fill.visible = r > 0.02
	if locked:
		_fuel_fill.self_modulate = Color(1.2, 2.4, 2.8)   # solid cyan glow
		_was_locked = true
		_fuel_was_full = true
		return
	if _was_locked:
		_was_locked = false
		_fuel_fill.self_modulate = _color   # drop the glow the moment the pin ends
	var full := r >= 0.999
	if full and not _fuel_was_full:
		_fuel_fill.self_modulate = Color(2.2, 2.2, 2.2)
		var tw := create_tween()
		tw.tween_property(_fuel_fill, "self_modulate", _color, 0.35)
	_fuel_was_full = full

## Held-powerup icon slot (spec §2: pickup shows on the corner HUD card).
func set_powerup(id: String) -> void:
	if id == _pu_id:
		return
	_pu_id = id
	if id == "":
		_pu_icon.visible = false
		return
	var path := "res://assets/powerups/icon_%s.png" % id
	if ResourceLoader.exists(path):
		_pu_icon.texture = load(path)
	_pu_icon.visible = true
	_pu_icon.pivot_offset = _pu_icon.custom_minimum_size * 0.5
	_pu_icon.scale = Vector2(1.5, 1.5)
	var tw := create_tween()
	tw.tween_property(_pu_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Score-display API kept as NO-OPS (MatchHUD still calls these on every kill/reset): the pips are
## gone (owner 2026-07-16) — the between-stage ScoreScreen is the score display now.
func set_score(_n: int) -> void:
	pass

func animate_score(_n: int) -> void:
	pass

## Dead this round: dim to ~40% + skull over the head icon until next ROUND_INTRO (spec §3).
func set_dead(dead: bool) -> void:
	_skull.visible = dead
	modulate = Color(0.55, 0.55, 0.55, 0.8) if dead else Color.WHITE
