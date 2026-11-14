extends Panel
## One corner HUD card: identity (head + NAME + small sub-tag, CC-8.5) + fuel gauge. Glossy Toybox treatment: pastel card
## body tinted to the player skin, vivid fuel in the full skin color, dark-chocolate outlines from
## assets/ui/theme.tres. Dead-this-round = dim + skull over the head icon.
## SCORE PIPS REMOVED (owner 2026-07-16): the score display is now the between-stage ScoreScreen
## (Duck Game/TowerFall pattern) — combat carries no persistent score readout.

const FUEL_PAD := 3.0           # fill inset inside the gauge background

var _color := Color.WHITE
var _fuel_was_full := true
var _was_locked := false

@onready var _name_label: Label = $Margin/VBox/IdentityRow/NameBox/NameLabel
@onready var _sub_label: Label = $Margin/VBox/IdentityRow/NameBox/SubLabel
@onready var _head: TextureRect = $Margin/VBox/IdentityRow/HeadSlot/Head
@onready var _skull: Control = $Margin/VBox/IdentityRow/HeadSlot/Skull
@onready var _fuel_bg: Panel = $Margin/VBox/FuelSlot/FuelBG
@onready var _fuel_fill: Panel = $Margin/VBox/FuelSlot/FuelFill
@onready var _pu_icon: TextureRect = $Margin/VBox/IdentityRow/PowerupSlot
# WK-37 ghost head + puff ring + "SHH": its own scene, instanced into the head slot on the FIRST set_ghost(true) — with
# GHOSTS OFF it never exists, so the card's node tree is exactly the pre-WK-37 one (spec T8).
const GHOST_BADGE := preload("res://scenes/ui/GhostCardBadge.tscn")
var _badge: Control = null
var _ghost_icon: TextureRect = null
var _ghost_ring: Control = null
var _shh: Label = null
# WK-37: the ghost head + ring sit on a DIMMED card (modulate 0.55); counter-brighten them so the "you can still play"
# cue reads at full strength (brief R8: "reads as a ghost on a dimmed card").
const GHOST_LIFT := Color(1.75, 1.75, 1.75, 1.25)
var _ghost_on := false
var _is_dead := false

var _pu_id := ""

## `label` (WK-10/WK-88): the fighter's NAME (PartyMatch.player_name: "P3" / "VEX"). "" = legacy slot number
## (idx + 1) for any caller that does not know the roster (set_label can update it later).
func setup(idx: int, color: Color, skin: String, label: String = "") -> void:
	_color = color
	_name_label.text = label if label != "" else "P%d" % (idx + 1)
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

## WK-88 (CC-8.5): NAME on the card ("P3" / "VEX") + the small sub-tag under it (goat name / "CPU"), set by
## the HUD from PartyMatch.player_names() / player_subtags(). "" sub = name only.
func set_label(text: String, sub: String = "") -> void:
	if text != "":
		_name_label.text = text
	_sub_label.text = sub
	_sub_label.visible = sub != ""

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
	_is_dead = dead
	_skull.visible = dead
	modulate = Color(0.55, 0.55, 0.55, 0.8) if dead else Color.WHITE
	if not dead:
		set_ghost(false, false)

## WK-37 ghost goats: the skull becomes a ghost head (+ the puff cooldown ring when `ring`, i.e. GHOSTS ON; BAA ONLY has
## no ring). Only ever called while dead; set_dead(false) clears it.
func set_ghost(on: bool, ring: bool) -> void:
	if _badge == null:
		if not on:
			_ghost_on = false
			_skull.visible = _is_dead
			return
		_badge = GHOST_BADGE.instantiate()
		$Margin/VBox/IdentityRow/HeadSlot.add_child(_badge)
		_ghost_icon = _badge.get_node("Ghost")
		_ghost_ring = _badge.get_node("GhostRing")
		_shh = _badge.get_node("Shh")
	_ghost_on = on
	_ghost_icon.visible = on
	_ghost_icon.self_modulate = GHOST_LIFT
	_ghost_ring.visible = on and ring
	_ghost_ring.self_modulate = GHOST_LIFT
	_shh.visible = false
	_shh.self_modulate = GHOST_LIFT
	_skull.visible = _is_dead and not on
	if on:
		_ghost_icon.pivot_offset = _ghost_icon.size * 0.5
		_ghost_icon.scale = Vector2(0.4, 0.4)
		var tw := create_tween()
		tw.tween_property(_ghost_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## WK-37: ring fill (1 = puff ready), hushed (grey + "SHH"), spent (stage cap used).
func set_ghost_ring(frac: float, hushed: bool, spent: bool) -> void:
	if not _ghost_on:
		return
	if _ghost_ring.visible:
		_ghost_ring.call("set_state", frac, hushed, spent, _color)
		_shh.visible = hushed
