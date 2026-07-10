extends MenuScreen
## ArenaSelect — "PICK YOUR PEAK" (frontend_ux_spec §2.4). A 4x3 grid: RANDOM ROTATION first (default,
## the fun default) + the 11 pool arenas. A directly confirms+launches (footer "(A) FIGHT!"). Arena
## thumbnails are intentional colored gradient tiles (real thumbnails are a Phase-2 slot swap).
##
## NOTE (deviation, flagged): every pool level's JSON `theme` is "grass", so tinting cards to the theme
## colour would make 11 identical green tiles. To keep the grid readable/varied I assign a per-arena
## accent from a spread palette. When per-arena thumbnails/theme colours land they drop into the slot.

const CARD := preload("res://scenes/ui/MenuCard.tscn")
const CIRCUITS_PATH := "res://levels/circuits.json"
# Baked wide arena thumbnails (frontend_visual_polish.md §3b), one per arena id, produced offline by
# tools/ThumbBaker.tscn. Loaded (not preloaded) + existence-guarded so a missing bake just falls back
# to the themed gradient tile — never a parse failure. "_random" is the RANDOM card's shuffle collage.
const THUMB_DIR := "res://assets/ui/thumbs"

# Per-circuit accent (circuits.json carries no colour; keep the spread-palette convention). Keyed by
# circuit id so a new circuit just needs an entry here (else falls back to the RANDOM pink).
const CIRCUIT_COLORS := {
	"meadow_mile": Color("#54c94a"),   # bright meadow green (on-ramp)
	"scrapworks": Color("#a15fff"),    # arcade violet (industrial)
	"high_wire": Color("#4ad0a8"),     # high teal (exposure)
	"the_foundry": Color("#ff8a2a"),   # molten orange (foundry gimmick circuit)
	"mayhem_mile": Color("#ff5a4a"),   # danger red (wild gimmick circuit)
}
# circuit id -> display name, filled while loading cards (used to phrase locked-card unlock hints).
var _circuit_display: Dictionary = {}
var _pending_celebrate := ""

const RANDOM := {"path": "", "name": "RANDOM ROTATION", "tag": "A new peak every round.",
	"color": Color("#ff5fa8"), "glyph": "?", "random": true}

const ARENAS := [
	{"path": "res://levels/islands_void.json", "name": "Islands Void", "color": Color("#4aa8ff")},
	{"path": "res://levels/grassy_expanse.json", "name": "Grassy Expanse", "color": Color("#54c94a")},
	{"path": "res://levels/drop_chamber.json", "name": "Drop Chamber", "color": Color("#a15fff")},
	{"path": "res://levels/the_spine.json", "name": "The Spine", "color": Color("#ff7a2d")},
	{"path": "res://levels/twin_chasms.json", "name": "Twin Chasms", "color": Color("#2fd0c0")},
	{"path": "res://levels/the_cliff.json", "name": "The Cliff", "color": Color("#ffc93f")},
	{"path": "res://levels/atoll.json", "name": "Atoll", "color": Color("#4ad0a8")},
	{"path": "res://levels/spires.json", "name": "Spires", "color": Color("#ff5fa8")},
	{"path": "res://levels/bumper_gauntlet.json", "name": "Bumper Gauntlet", "color": Color("#ff5a4a")},
	{"path": "res://levels/the_ascent.json", "name": "The Ascent", "color": Color("#7a9cff")},
	{"path": "res://levels/wrecking_yard.json", "name": "Wrecking Yard", "color": Color("#c9a24a")},
]

@onready var _grid: GridContainer = $Grid
@onready var _back: Button = $Header/BackBtn

var _cards: Array[Button] = []

## Load levels/circuits.json into an ordered Array of card-data dicts (marked "circuit": true).
## Returns [] on any failure so the screen still shows RANDOM + arenas (never crashes).
func _load_circuit_cards() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(CIRCUITS_PATH):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CIRCUITS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var circuits: Variant = (parsed as Dictionary).get("circuits", {})
	if typeof(circuits) != TYPE_DICTIONARY:
		return out
	for cid in (circuits as Dictionary).keys():
		var entry: Variant = (circuits as Dictionary)[cid]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ed: Dictionary = entry as Dictionary
		var diff: int = int(ed.get("difficulty", 1))
		var display := str(ed.get("display_name", cid))
		_circuit_display[str(cid)] = display
		# arenas-per-play: a random-draw circuit plays `draw_count` of its pool; an ordered circuit
		# plays its whole `levels` list.
		var draw_count: int = int(ed.get("draw_count", 0))
		var pool: Array = ed.get("pool", [])
		var levels: Array = ed.get("levels", [])
		var count: int = draw_count if (draw_count > 0 and pool.size() > 0) else levels.size()
		var stars := ""
		for s in range(3):
			stars += "*" if s < diff else "."
		var unlocked: bool = Settings.is_circuit_unlocked(str(cid))
		# The circuit NAME reads as the name; the arenas-count (unlocked) or the unlock hint (locked)
		# goes into the smaller TAG/subtitle slot so a long "WIN X TO UNLOCK" wraps inside the card
		# instead of overflowing the name band (frontend card grammar: name + optional tagline).
		var tag_text: String
		if unlocked:
			tag_text = "%s  %d arenas" % [stars, count]
		else:
			tag_text = _lock_hint(str(cid))
		out.append({
			"circuit_id": str(cid),
			"name": display,
			"tag": tag_text,
			"color": CIRCUIT_COLORS.get(str(cid), MenuFX.ACCENT_PINK),
			"circuit": true,
			"locked": not unlocked,
		})
	return out

## Phrase the unlock condition for a locked circuit card (v6 §4.3): the pity path once the predecessor
## has been played at least once, else the mastery (win) hint. Uppercase to match the card name band.
func _lock_hint(cid: String) -> String:
	var pred := Settings.unlock_predecessor(cid)
	var pred_name := str(_circuit_display.get(pred, pred)).to_upper()
	var remaining := Settings.pity_matches_remaining(cid)
	if remaining < Settings.UNLOCK_PITY_MATCHES and remaining > 0:
		return "%d MORE MATCH%s TO UNLOCK" % [remaining, "" if remaining == 1 else "ES"]
	return "WIN %s TO UNLOCK" % pred_name

## Baked thumbnail for a card, or null (falls back to the themed gradient tile). Circuit cards get
## none (they play a rotation, not one arena); RANDOM gets the shuffle collage; an arena gets its bake.
func _thumb_for(a: Dictionary) -> Texture2D:
	if bool(a.get("circuit", false)):
		return null
	var id := "_random" if bool(a.get("random", false)) else str(a.get("path", "")).get_file().get_basename()
	if id == "":
		return null
	var path := "%s/%s.png" % [THUMB_DIR, id]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _ready() -> void:
	var all: Array = _load_circuit_cards()
	all.append(RANDOM)
	all.append_array(ARENAS)
	for a in all:
		var card: Button = CARD.instantiate()
		card.custom_minimum_size = Vector2(340, 210)
		_grid.add_child(card)
		# Baked arena thumbnail (or the RANDOM shuffle collage) -> the card Art slot, mirroring the
		# ModeSelect MODE_ART pattern (set_art auto-hides the placeholder glyph). Circuits have no
		# per-arena thumb (they play a rotation); they keep the themed gradient plate.
		var thumb := _thumb_for(a)
		# No taglines on arena tiles (only RANDOM had one, and it clipped on the short card) — the
		# name band is reserved for 2 lines so 1- and 2-line names align to the same tile height.
		card.set_card({
			"name": a["name"], "tag": a.get("tag", ""), "color": a["color"],
			"glyph": a.get("glyph", ""), "art": thumb,
		})
		if thumb != null:
			# opaque map-select thumbnails COVER the plate (full-bleed, cropped) rather than the
			# transparent-diorama KEEP_ASPECT_CENTERED the scene defaults to; the themed accent border +
			# gradient still frame it via the plate's chocolate outline + 10px inset (§3b).
			var art := card.get_node_or_null("Content/VBox/Plate/Art")
			if art is TextureRect:
				(art as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var plate := card.get_node_or_null("Content/VBox/Plate")
		if plate is Control:
			(plate as Control).custom_minimum_size = Vector2(0, 60)
		var nm := card.get_node_or_null("Content/VBox/NameStrip/Labels/NameLabel")
		if nm is Control:
			(nm as Control).custom_minimum_size = Vector2(0, 84)   # fixed 2-line name band
		card.set_meta("arena", a)
		register(card, 1.12)
		_cards.append(card)
		if bool(a.get("locked", false)) and card.has_method("set_locked"):
			card.set_locked(true)
		# RANDOM (§3b hierarchy fix): the old rainbow gradient + spinning "?" was the flashiest tile on
		# the screen, out-shining the real arenas. It now wears a calm 3-arena shuffle collage (baked as
		# _random.png). If that collage is missing, fall back to the rainbow so it never reads as blank.
		if bool(a.get("random", false)) and thumb == null:
			card.set_plate_rainbow()
			_spin_glyph(card)
	# one-shot unlock celebration (consume the pending flag now; play it after the entry stagger)
	_pending_celebrate = Settings.take_pending_unlock()
	wire_grid(_cards, 4)
	register(_back, 1.05)
	_cards[_cards.size() - 1].focus_neighbor_bottom = _cards[_cards.size() - 1].get_path_to(_back)
	_back.focus_neighbor_top = _back.get_path_to(_cards[0])

func first_focus() -> Control:
	return _cards[0]

func stagger_items() -> Array:
	return _cards

func accent_for(c: Control) -> Color:
	if c.has_meta("arena"):
		return (c.get_meta("arena") as Dictionary).get("color", MenuFX.ACCENT_PINK)
	return MenuFX.ACCENT_PINK

func activate(c: Control) -> void:
	if c == _back:
		on_back()
		return
	var a: Dictionary = c.get_meta("arena", {})
	# locked circuit: no launch -- a denied buzz + a small shake, then bail (v6 §4.3)
	if bool(a.get("locked", false)):
		AudioManager.play_sfx("ui_click", {"pitch": 0.55, "pitch_var": 0.0, "volume_db": -3.0})
		_deny_shake(c)
		return
	var cfg: MatchConfig = GameConfig.match_config
	if bool(a.get("circuit", false)):
		cfg.arena_mode = MatchConfig.ArenaMode.CIRCUIT
		cfg.circuit_id = StringName(str(a["circuit_id"]))
		cfg.single_arena_path = ""
	elif bool(a.get("random", false)):
		cfg.arena_mode = MatchConfig.ArenaMode.RANDOM_ALL
		cfg.single_arena_path = ""
		cfg.circuit_id = &""
	else:
		cfg.arena_mode = MatchConfig.ArenaMode.SINGLE
		cfg.single_arena_path = str(a["path"])
		cfg.circuit_id = &""
	if shell != null:
		shell.launch_match()

## After the shared entry stagger, fire the one-shot unlock celebration if one is pending (v6 §4.3).
func enter() -> void:
	super.enter()
	if _pending_celebrate != "":
		_play_unlock_celebration(_pending_celebrate)
		_pending_celebrate = ""

## One-shot "you earned it" moment: a banner flash + a pop/focus-snap on the just-unlocked card, with
## the win announcer sting. The pending flag was already consumed (take_pending_unlock) so it fires once.
func _play_unlock_celebration(cid: String) -> void:
	var banner := get_node_or_null("UnlockBanner")
	var display := str(_circuit_display.get(cid, cid)).to_upper()
	# find the (now-unlocked) card for this circuit
	var target: Button = null
	for card in _cards:
		var a: Dictionary = card.get_meta("arena", {})
		if bool(a.get("circuit", false)) and str(a.get("circuit_id", "")) == cid:
			target = card
			break
	# delay until the stagger has mostly landed, then celebrate
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		AudioManager.play_sfx("ui_click", {"pitch": 1.5, "pitch_var": 0.0, "volume_db": 0.0})
		EventBus.match_won.emit(0)   # reuse the win fanfare sting (presentation only)
		if banner is Label:
			(banner as Label).text = "CIRCUIT UNLOCKED\n%s" % display
			banner.visible = true
			banner.modulate.a = 0.0
			banner.pivot_offset = banner.size * 0.5
			banner.scale = Vector2(0.7, 0.7)
			var tb := banner.create_tween()
			tb.set_parallel(true)
			tb.tween_property(banner, "modulate:a", 1.0, 0.25)
			tb.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tb.chain().tween_interval(1.4)
			tb.chain().tween_property(banner, "modulate:a", 0.0, 0.4)
			tb.chain().tween_callback(func() -> void: banner.visible = false)
		if is_instance_valid(target):
			target.grab_focus()
			target.pivot_offset = target.size * 0.5
			var tc := target.create_tween()
			tc.tween_property(target, "scale", Vector2(1.22, 1.22), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tc.tween_property(target, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))

## Locked-card denied feedback: a quick horizontal shake (no launch).
func _deny_shake(c: Control) -> void:
	var rest := c.position
	var t := c.create_tween()
	t.tween_property(c, "position:x", rest.x - 10.0, 0.05)
	t.tween_property(c, "position:x", rest.x + 10.0, 0.06)
	t.tween_property(c, "position:x", rest.x, 0.05)

func _spin_glyph(card: Button) -> void:
	var glyph := card.get_node_or_null("Content/VBox/Plate/Glyph")
	if glyph == null:
		return
	glyph.pivot_offset = glyph.size * 0.5
	var t := glyph.create_tween().set_loops()
	t.tween_property(glyph, "rotation", TAU, 4.0).from(0.0).set_trans(Tween.TRANS_LINEAR)
