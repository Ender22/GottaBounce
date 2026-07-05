extends MenuScreen
## ModeSelect — "CHOOSE YOUR GAME" (frontend_ux_spec §2.2). BRAWL is the one live card; Trials /
## Gauntlet / Sports are gorgeous COMING-SOON cards (ribbon + still-colored + playful locked wiggle
## and a "Coming soon!" toast), never disabled-grey dead ends.

const CARD := preload("res://scenes/ui/MenuCard.tscn")

const MODES := [
	{"id": "brawl", "name": "BRAWL", "tag": "Last one flying wins.",
		"color": Color("#ff5fa8"), "glyph": "B", "soon": false},
	{"id": "trials", "name": "TRIALS", "tag": "Beat the clock. Just you and the jetpack.",
		"color": Color("#4aa8ff"), "glyph": "T", "soon": false},
	{"id": "gauntlet", "name": "GAUNTLET", "tag": "Hold the line. They keep coming, you keep flying.",
		"color": Color("#a15fff"), "glyph": "G", "soon": false},
	{"id": "sports", "name": "SPORTS", "tag": "Headbutt the ball, not each other. (Okay, each other too.)",
		"color": Color("#ff7a2d"), "glyph": "S", "soon": false},
]

@onready var _row: HBoxContainer = $CardRow
@onready var _back: Button = $Header/BackBtn
@onready var _toast: Label = $Toast

var _cards: Array[Button] = []

func _ready() -> void:
	for m in MODES:
		var card: Button = CARD.instantiate()
		card.custom_minimum_size = Vector2(380, 520)
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(card)
		var data := (m as Dictionary).duplicate()
		data["name_variation"] = &"ModeTitle"
		card.set_card(data)
		card.set_meta("mode", m)
		register(card, 1.14)
		_cards.append(card)
	register(_back, 1.05)
	wire_row(_cards)
	# Back is reachable last: right from the final card lands on Back, left from Back to last card
	_cards[_cards.size() - 1].focus_neighbor_bottom = _cards[_cards.size() - 1].get_path_to(_back)
	_back.focus_neighbor_top = _back.get_path_to(_cards[0])

func first_focus() -> Control:
	return _cards[0]

func stagger_items() -> Array:
	return _cards

func accent_for(c: Control) -> Color:
	if c.has_meta("mode"):
		return (c.get_meta("mode") as Dictionary).get("color", MenuFX.ACCENT_PINK)
	return MenuFX.ACCENT_PINK

func activate(c: Control) -> void:
	if c == _back:
		on_back()
		return
	var m: Dictionary = c.get_meta("mode", {})
	if bool(m.get("soon", false)):
		MenuFX.reject_shake(c)
		AudioManager.play_sfx("ui_click", {"pitch": 0.6, "volume_db": -6.0})
		_show_toast("Coming soon!")
		return
	GameConfig.match_config.mode_id = StringName(str(m.get("id", "brawl")))
	shell.go_forward("character")

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.pivot_offset = _toast.size * 0.5
	_toast.scale = Vector2(0.8, 0.8)
	var t := _toast.create_tween()
	t.set_parallel(true)
	t.tween_property(_toast, "modulate:a", 1.0, 0.12)
	t.tween_property(_toast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(1.0)
	t.chain().tween_property(_toast, "modulate:a", 0.0, 0.25)
