extends Panel
## One corner HUD card (spec §3): identity (head + P#), 2x5 score pips, fuel gauge.
## Glossy Toybox treatment: pastel card body tinted to the player skin, vivid pips/fuel in the
## full skin color, dark-chocolate outlines from assets/ui/theme.tres. The 10 pip slots ARE the
## "first to 10" teaching device. Dead-this-round = dim + skull over the head icon.

const PIP_POP_STAGGER := 0.15   # s between pip pops during ROUND_END (spec §1)
const FUEL_PAD := 3.0           # fill inset inside the gauge background

var _color := Color.WHITE
var _shown := 0                 # pips currently displayed (visual state; scores are the truth)
var _sb_full: StyleBoxFlat
var _sb_empty: StyleBoxFlat
var _fuel_was_full := true
var _pips: Array = []

@onready var _name_label: Label = $Margin/VBox/IdentityRow/NameLabel
@onready var _head: TextureRect = $Margin/VBox/IdentityRow/HeadSlot/Head
@onready var _skull: Control = $Margin/VBox/IdentityRow/HeadSlot/Skull
@onready var _fuel_bg: Panel = $Margin/VBox/FuelSlot/FuelBG
@onready var _fuel_fill: Panel = $Margin/VBox/FuelSlot/FuelFill

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
	_pips = $Margin/VBox/Pips.get_children()
	_sb_empty = _pips[0].get_theme_stylebox("panel").duplicate()
	_sb_full = _sb_empty.duplicate()
	_sb_full.bg_color = color
	for pip in _pips:
		pip.pivot_offset = pip.custom_minimum_size * 0.5
		pip.add_theme_stylebox_override("panel", _sb_empty)
	_fuel_fill.self_modulate = color
	set_score(0)

## Fuel gauge, mapped 0..1 (GDD §10 glanceable). Flashes bright when a full tank is banked —
## the super-boost-ready tell.
func set_fuel(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	var w: float = maxf(0.0, _fuel_bg.size.x - FUEL_PAD * 2.0)
	_fuel_fill.size = Vector2(w * r, maxf(0.0, _fuel_bg.size.y - FUEL_PAD * 2.0))
	_fuel_fill.visible = r > 0.02
	var full := r >= 0.999
	if full and not _fuel_was_full:
		_fuel_fill.self_modulate = Color(2.2, 2.2, 2.2)
		var tw := create_tween()
		tw.tween_property(_fuel_fill, "self_modulate", _color, 0.35)
	_fuel_was_full = full

## Instant pip state (round/match resets). Use animate_score() for the ROUND_END tick-tick.
func set_score(n: int) -> void:
	_shown = clampi(n, 0, _pips.size())
	for i in range(_pips.size()):
		var pip: Panel = _pips[i]
		pip.add_theme_stylebox_override("panel", _sb_full if i < _shown else _sb_empty)
		pip.scale = Vector2.ONE

## ROUND_END pip animation: pips pop in/out one at a time, PIP_POP_STAGGER apart (spec §1).
func animate_score(n: int) -> void:
	n = clampi(n, 0, _pips.size())
	var step := 0
	while _shown != n:
		var filling := n > _shown
		var pip_idx := _shown if filling else _shown - 1
		_schedule_pip(pip_idx, filling, PIP_POP_STAGGER * step)
		_shown += 1 if filling else -1
		step += 1

func _schedule_pip(idx: int, fill: bool, delay: float) -> void:
	if delay <= 0.0:
		_pop_pip(idx, fill)
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_pop_pip(idx, fill))

func _pop_pip(idx: int, fill: bool) -> void:
	if idx < 0 or idx >= _pips.size():
		return
	var pip: Panel = _pips[idx]
	pip.add_theme_stylebox_override("panel", _sb_full if fill else _sb_empty)
	pip.scale = Vector2(1.45, 1.45) if fill else Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(pip, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Dead this round: dim to ~40% + skull over the head icon until next ROUND_INTRO (spec §3).
func set_dead(dead: bool) -> void:
	_skull.visible = dead
	modulate = Color(0.55, 0.55, 0.55, 0.8) if dead else Color.WHITE
