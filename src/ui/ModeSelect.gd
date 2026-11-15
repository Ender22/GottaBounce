extends MenuScreen
## ModeSelect — "CHOOSE YOUR GAME" (frontend_ux_spec §2.2). Three live cards: BRAWL / TRIALS /
## SPORTS. (GAUNTLET removed by owner ruling 2026-07-16 — see DECISIONS.md.) A future "soon" card
## renders as a gorgeous COMING-SOON card (ribbon + wiggle + toast), never a disabled-grey dead end.

const CARD := preload("res://scenes/ui/MenuCard.tscn")

# Owner 2026-07-19: SPORTS split into two top-level cards — ROCKETBALL (soccer) + DROPSHOT (volleyball) —
# and reordered to TRIALS, BRAWL, ROCKETBALL, DROPSHOT. Both sports cards run SportsMode (PartyMatch
# registry); the mode id locks the sport and filters the court select.
#
# WK-13 (audit C-35 / R-18): "players" = the player-count chip on the art plate (top-left), so a group knows who
# can play before picking. Every mode seats 1-4 humans (CPUs fill BRAWL and the sports teams). TRIALS's chip
# carries its "SOLO / CO-OP" sub-label; the two sports read their formats.
const MODES := [
	{"id": "trials", "name": "TRIALS", "tag": "Fly the line. Land it, and you're home.",
		"color": Color("#4aa8ff"), "glyph": "T", "soon": false, "players": "1-4 · SOLO / CO-OP"},
	# WK-15 / audit D-04: BRAWL scores KOs, not survival — the tagline says so ("%d" = remembered KOs-to-win;
	# explicit break between the two sentences so "KOs." never orphans on the wrap)
	{"id": "brawl", "name": "BRAWL", "tag": "Smash 'em off-screen.\nFirst to %d KOs.",
		"color": Color("#ff5fa8"), "glyph": "B", "soon": false, "players": "1-4 · VERSUS"},
	{"id": "rocketball", "name": "ROCKETBALL", "tag": "Headbutt the ball, not each other. Okay, each other too.",
		"color": Color("#ff7a2d"), "glyph": "R", "soon": false, "players": "1V1 / 2V2"},
	{"id": "dropshot", "name": "DROPSHOT", "tag": "Spike it over. Don't let it drop.",
		"color": Color("#22b3c9"), "glyph": "D", "soon": false, "players": "1V1 / 2V2"},
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
		if str(data["tag"]).contains("%d"):
			data["tag"] = str(data["tag"]) % int(GameConfig.rules_for("brawl").get("kills_to_win", 10))
		if MODE_ART.has(m["id"]):
			data["art"] = MODE_ART[m["id"]]
		card.set_card(data)
		# WK-13 chip: goat-cream type on the mode colour at half brightness (>= 7.5:1 for all four accents)
		card.set_badge(str(m.get("players", "")), (m["color"] as Color).darkened(0.5))
		card.set_meta("mode", m)
		register(card, 1.14)
		_cards.append(card)
	register(_back, 1.05)
	wire_row(_cards)
	# Back is reachable last: right from the final card lands on Back, left from Back to last card
	_cards[_cards.size() - 1].focus_neighbor_bottom = _cards[_cards.size() - 1].get_path_to(_back)
	_back.focus_neighbor_top = _back.get_path_to(_cards[0])
	_equalize_card_heights.call_deferred()

## WK-13 (R-18): every card's art plate is the same height. The plate expands into what the name strip leaves,
## and the strips differ (ROCKETBALL's tagline wraps to 3 lines, BRAWL's to 2), so pin every strip to the tallest.
## Two frames: the first lays the row out, the second lets MenuCard's deferred title auto-fit settle.
func _equalize_card_heights() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var tallest := 0.0
	for c in _cards:
		tallest = maxf(tallest, float(c.name_strip_content_height()))
	for c in _cards:
		c.set_name_strip_min_height(tallest)

func first_focus() -> Control:
	# WK-13 / CC-5.6 (audit R-18, D-29): the most likely next action. Fresh boot -> BRAWL (the flagship; the card
	# ORDER stays owner-set, TRIALS first). After that -> the mode picked last this session (match_config.mode_id
	# outlives the match and QUIT TO TITLE; it only resets on a cold boot), so Trials players land back on TRIALS.
	# WK-80(a): B out of the lobby lands on the card you came from by the same rule.
	var want := "brawl"
	if GameConfig.match_config != null:
		want = str(GameConfig.match_config.mode_id)
	var brawl: Control = _cards[0]
	for c in _cards:
		var id := str((c.get_meta("mode", {}) as Dictionary).get("id", ""))
		if id == want:
			return c
		if id == "brawl":
			brawl = c
	return brawl

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
