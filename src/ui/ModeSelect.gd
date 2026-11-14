extends MenuScreen
## ModeSelect — "CHOOSE YOUR GAME" (frontend_ux_spec §2.2). Three live cards: BRAWL / TRIALS /
## SPORTS. (GAUNTLET removed by owner ruling 2026-07-16 — see DECISIONS.md.) A future "soon" card
## renders as a gorgeous COMING-SOON card (ribbon + wiggle + toast), never a disabled-grey dead end.

const CARD := preload("res://scenes/ui/MenuCard.tscn")

# Owner 2026-07-19: SPORTS split into two top-level cards — ROCKETBALL (soccer) + DROPSHOT (volleyball) —
# and reordered to TRIALS, BRAWL, ROCKETBALL, DROPSHOT. Both sports cards run SportsMode (PartyMatch
# registry); the mode id locks the sport and filters the court select.
const MODES := [
	{"id": "trials", "name": "TRIALS", "tag": "Fly the line. Land it, and you're home.",
		"color": Color("#4aa8ff"), "glyph": "T", "soon": false},
	{"id": "brawl", "name": "BRAWL", "tag": "Last one flying wins.",
		"color": Color("#ff5fa8"), "glyph": "B", "soon": false},
	{"id": "rocketball", "name": "ROCKETBALL", "tag": "Headbutt the ball, not each other. (Okay, each other too.)",
		"color": Color("#ff7a2d"), "glyph": "R", "soon": false},
	{"id": "dropshot", "name": "DROPSHOT", "tag": "Spike it over. Don't let it drop.",
		"color": Color("#22b3c9"), "glyph": "D", "soon": false},
]

# Glossy-Toybox action dioramas per mode (frontend_visual_polish.md §1c). Drops into the MenuCard
# Art slot; set_art() auto-hides the placeholder Glyph letter. ROCKETBALL reuses the soccer diorama;
# DROPSHOT has its own (existence-guarded: a missing card falls back to the glyph letter).
const MODE_ART := {
	"brawl": preload("res://assets/ui/modes/mode_brawl.png"),
	"trials": preload("res://assets/ui/modes/mode_trials.png"),
	"rocketball": preload("res://assets/ui/modes/mode_sports.png"),
	"dropshot": preload("res://assets/ui/modes/mode_dropshot.png"),
}

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
		if MODE_ART.has(m["id"]):
			data["art"] = MODE_ART[m["id"]]
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
	# WK-80(a) / CC-5.6: arriving BACK (B out of the lobby, incl. after Pause -> CHANGE SETUP, where the shell
	# has no remembered focus) lands on the mode you came from, never on TRIALS by default. Fresh forward
	# entry keeps today's default (WK-13 owns the forward default).
	if shell != null and not bool(shell.get("nav_forward")) and GameConfig.match_config != null:
		var cur := str(GameConfig.match_config.mode_id)
		for c in _cards:
			if str((c.get_meta("mode", {}) as Dictionary).get("id", "")) == cur:
				return c
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
	# CC-4.8: the device that confirmed the mode card is auto-joined as P1 by the Herd Lobby.
	GameConfig.lobby_autojoin_key = InputRouter.last_device_key
	shell.go_forward("lobby")

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
