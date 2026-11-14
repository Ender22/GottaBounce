extends MenuScreen
## ArenaSelect — "PICK YOUR PEAK", the Shelf model (frontend_ui_audit_2026-07-10 §3; owner-mandated
## rebuild). Two horizontally-scrolling shelves: SHELF A "WAYS TO PLAY" (RANDOM ROTATION first —
## the fun default — then the circuits, big 460x340 cards) and SHELF B "ARENAS" (the single-arena
## pool, 380x280 cards). Each shelf is a clipping ShelfRail whose rail the code translates on X so
## the focused card is ALWAYS fully on-screen (scroll-to-focused §3.6) and can structurally never
## occlude the header or footer. Scales to any circuit/arena count — the layout doesn't care.
##
## NOTE (deviation, flagged): every pool level's JSON `theme` is "grass", so tinting cards to the
## theme colour would make identical green tiles. Per-arena accents come from a spread palette;
## baked thumbs/crests drop into the art slot when they exist (existence-guarded).

const CARD := preload("res://scenes/ui/MenuCard.tscn")
const CIRCUITS_PATH := "res://levels/circuits.json"
const COURTS_PATH := "res://levels/sports_courts.json"
# Baked wide arena thumbnails (frontend_visual_polish.md §3b), produced offline by
# tools/ThumbBaker.tscn. Loaded (not preloaded) + existence-guarded so a missing bake just falls
# back to the themed gradient tile. "_random" is the RANDOM card's shuffle collage.
const THUMB_DIR := "res://assets/ui/thumbs"
# Circuit crest emblems (frontend_ui_audit §3.7). Existence-guarded: missing crest -> the themed
# gradient plate + circuit name (the audit's sanctioned fallback).
const CREST_DIR := "res://assets/ui/circuits"

const SHELF_A_CARD := Vector2(460, 340)   # §3.3 Shelf A: ways to play
const SHELF_B_CARD := Vector2(380, 280)   # §3.3 Shelf B: single arenas
const FOCUS_SCALE := 1.10                 # §3.6 (down from 1.12: keeps scaled edges in the band)
const PAGE_JUMP := 3                      # §3.5 LB/RB + PageUp/PageDown jump

# Per-circuit accent (circuits.json carries no colour; spread-palette convention). A new circuit
# just needs an entry here (else falls back to the RANDOM pink).
const CIRCUIT_COLORS := {
	"meadow_mile": Color("#54c94a"),   # bright meadow green (on-ramp)
	"scrapworks": Color("#a15fff"),    # arcade violet (industrial)
	"high_wire": Color("#4ad0a8"),     # high teal (exposure)
	"the_foundry": Color("#ff8a2a"),   # molten orange (foundry gimmick circuit)
	"mayhem_mile": Color("#ff5a4a"),   # danger red (wild gimmick circuit)
}
# SPORTS court select (frontend_ui_audit §3.8): same scene, ONE shelf. Tier badge accents,
# calm (1) -> chaos (5); a new tier just needs an entry here (else falls back to the RANDOM pink).
const TIER_COLORS := {
	1: Color("#54c94a"),   # calm green
	2: Color("#4ad0a8"),   # teal
	3: Color("#ff8a2a"),   # hazard orange
	4: Color("#a15fff"),   # violet
	5: Color("#ff5a4a"),   # chaos red
}

# circuit id -> display name, filled while loading cards (used to phrase locked-card unlock hints).
var _circuit_display: Dictionary = {}
var _pending_celebrate := ""
var _sports := false   # SPORTS flow: one COURTS shelf instead of circuits/arenas (§3.8)
var _trials := false   # TRIALS flow (owner 2026-07-16): one CIRCUITS shelf of course sets

const COURSE_SETS_PATH := "res://levels/course_sets.json"

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
	{"path": "res://levels/singularity.json", "name": "Singularity", "color": Color("#a15fff")},
	{"path": "res://levels/twin_moons.json", "name": "Twin Moons", "color": Color("#7a9cff")},
]

@onready var _shelf_a: Control = $ShelfA
@onready var _shelf_b: Control = $ShelfB
@onready var _back: Button = $Header/BackBtn

var _a_cards: Array[Button] = []
var _b_cards: Array[Button] = []
var _a_idx := 0   # remembered focus per shelf (§3.5 up/down restores it)
var _b_idx := 0

# ------------------------------------------------------------------ data loading (unchanged logic)
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
		var unlocked: bool = Settings.is_circuit_unlocked(str(cid))
		out.append({
			"circuit_id": str(cid),
			"name": display,
			"tag": "" if unlocked else _lock_hint(str(cid)),
			"difficulty": diff,
			"arena_count": count,
			"color": CIRCUIT_COLORS.get(str(cid), MenuFX.ACCENT_PINK),
			"circuit": true,
			"locked": not unlocked,
		})
	return out

## Phrase the unlock condition for a locked circuit card (v6 §4.3): the pity path once the
## predecessor has been played at least once, else the mastery (win) hint.
func _lock_hint(cid: String) -> String:
	var pred := Settings.unlock_predecessor(cid)
	var pred_name := str(_circuit_display.get(pred, pred)).to_upper()
	var remaining := Settings.pity_matches_remaining(cid)
	if remaining < Settings.UNLOCK_PITY_MATCHES and remaining > 0:
		return "%d MORE MATCH%s TO UNLOCK" % [remaining, "" if remaining == 1 else "ES"]
	return "WIN %s TO UNLOCK" % pred_name

## Art for a card, or null (falls back to the themed gradient plate). RANDOM gets the shuffle
## collage; an arena gets its bake; a circuit gets its crest emblem (when the asset lands).
func _thumb_for(a: Dictionary) -> Texture2D:
	var path := ""
	if bool(a.get("court", false)):
		# court: court_<id> namespace (ThumbBaker bakes courts under it — the court id "minefield"
		# collides with the brawl arena of the same name). Missing -> gradient plate.
		path = "%s/court_%s.png" % [THUMB_DIR, str(a.get("court_id", ""))]
	elif bool(a.get("circuit", false)):
		path = "%s/crest_%s.png" % [CREST_DIR, str(a.get("circuit_id", ""))]
	elif bool(a.get("trials_set", false)):
		path = "%s/crest_trials_%s.png" % [CREST_DIR, str(a.get("set_id", ""))]
	else:
		var id := "_random" if bool(a.get("random", false)) else str(a.get("path", "")).get_file().get_basename()
		if id == "":
			return null
		path = "%s/%s.png" % [THUMB_DIR, id]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# ------------------------------------------------------------------ build
func _ready() -> void:
	_sports = GameConfig.match_config != null and SportsMode.is_sports_mode(GameConfig.match_config.mode_id)
	_trials = GameConfig.match_config != null and GameConfig.match_config.mode_id == &"trials"
	if _sports:
		_build_sports()
	elif _trials:
		_build_trials()
	else:
		_build_brawl()
	register(_back, 1.05)
	_rewire_cross()
	# one-shot unlock celebration (consume the pending flag now; play it after the entry stagger).
	# BRAWL only: the celebration is a circuit moment and consuming the flag here would eat it.
	if not _sports and not _trials:
		_pending_celebrate = Settings.take_pending_unlock()

func _build_brawl() -> void:
	# Owner 2026-07-19: BRAWL now picks a CIRCUIT only — the single-arena shelf is gone, and RANDOM
	# ROTATION moved to the END (it's the fallback, not the default). Title reads CHOOSE BATTLEGROUND.
	var title := get_node_or_null("Header/Title")
	if title is Label:
		(title as Label).text = "CHOOSE BATTLEGROUND"
	# ONE centered shelf (matches the sports/trials layout); no arena pool shelf.
	_shelf_b.visible = false
	_shelf_a.offset_top = 326.0
	_shelf_a.offset_bottom = 761.0
	# circuits in circuits.json order, then RANDOM ROTATION last.
	var shelf_a_data: Array = _load_circuit_cards()
	shelf_a_data.append(RANDOM)
	(_shelf_a as Object).call("set_label", "WAYS TO PLAY")
	(_shelf_a as Object).call("set_separation", 36)
	for a in shelf_a_data:
		_a_cards.append(_make_card(a, _shelf_a, 0))
	(_shelf_a as Object).call("set_counter", 0, _a_cards.size())
	_shelf_a.connect("wheel_moved", _on_wheel.bind(0))

	# focus wiring: left/right along the shelf, no wrap (§3.5 — ends point to self so Godot never
	# auto-picks a spatial neighbour; the edge press becomes a rail nudge, see _on_card_gui).
	_wire_rail(_a_cards)

## SPORTS court select (§3.8): the SAME scene, retitled "PICK YOUR COURT", with ONE shelf
## ("COURTS", Shelf-A-size cards, centered vertically in the content band). Everything comes
## from levels/sports_courts.json — a 9th court appears with zero code change.
func _build_sports() -> void:
	var title := get_node_or_null("Header/Title")
	if title is Label:
		(title as Label).text = "PICK YOUR COURT"
	_shelf_b.visible = false
	# center the lone shelf in the content band (150..938, shelf band is 435 tall — §3.8)
	_shelf_a.offset_top = 326.0
	_shelf_a.offset_bottom = 761.0
	var courts := _load_court_cards()
	(_shelf_a as Object).call("set_label", "COURTS  %d" % courts.size())
	(_shelf_a as Object).call("set_separation", 36)
	for a in courts:
		_a_cards.append(_make_card(a, _shelf_a, 0))
	(_shelf_a as Object).call("set_counter", 0, _a_cards.size())
	_shelf_a.connect("wheel_moved", _on_wheel.bind(0))
	_wire_rail(_a_cards)

## TRIALS circuit select (owner 2026-07-16): the SAME scene, retitled "PICK YOUR CIRCUIT", ONE shelf
## of course-set cards from levels/course_sets.json (order array; a 6th circuit = zero code change).
## Mirrors _build_sports exactly. No lock gates — every trials circuit is open (owner: gate later
## only if playtests want it).
func _build_trials() -> void:
	var title := get_node_or_null("Header/Title")
	if title is Label:
		(title as Label).text = "PICK YOUR CIRCUIT"
	_shelf_b.visible = false
	_shelf_a.offset_top = 326.0
	_shelf_a.offset_bottom = 761.0
	var sets := _load_trials_cards()
	(_shelf_a as Object).call("set_label", "CIRCUITS  %d" % sets.size())
	(_shelf_a as Object).call("set_separation", 36)
	for a in sets:
		_a_cards.append(_make_card(a, _shelf_a, 0))
	(_shelf_a as Object).call("set_counter", 0, _a_cards.size())
	_shelf_a.connect("wheel_moved", _on_wheel.bind(0))
	_wire_rail(_a_cards)

## Load levels/course_sets.json into an ordered Array of card-data dicts (marked "trials_set": true).
## Returns [] on any failure (BACK-only screen, never crashes; TrialsMode's proof-course fallback
## still protects the launch path).
func _load_trials_cards() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(COURSE_SETS_PATH):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COURSE_SETS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var sets: Variant = (parsed as Dictionary).get("sets", {})
	if typeof(sets) != TYPE_DICTIONARY:
		return out
	var order: Variant = (parsed as Dictionary).get("order", (sets as Dictionary).keys())
	var n := 0
	for sid in (order as Array):
		var entry: Variant = (sets as Dictionary).get(str(sid), null)
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ed: Dictionary = entry as Dictionary
		n += 1
		var courses: Array = ed.get("courses", [])
		# count only courses whose file exists (agents/authoring in flight never inflate the card)
		var have := 0
		for c in courses:
			if FileAccess.file_exists(str(c)):
				have += 1
		out.append({
			"set_id": str(sid),
			"name": str(ed.get("display_name", sid)),
			"tag": str(ed.get("tagline", "")),
			"color": Color(str(ed.get("color", "#4aa8ff"))),
			"trials_set": true,
			"difficulty": n,
			"arena_count": have,
		})
	return out

## Load levels/sports_courts.json into an ordered Array of card-data dicts (marked "court": true),
## tier order calm->chaos (stable within a tier). Returns [] on any failure (screen shows BACK only,
## never crashes; SportsMode's own default_court guard still protects the launch path).
func _load_court_cards() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(COURTS_PATH):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COURTS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var courts: Variant = (parsed as Dictionary).get("courts", [])
	if typeof(courts) != TYPE_ARRAY:
		return out
	# Owner 2026-07-19 split: ROCKETBALL shows only "soccer" courts, DROPSHOT only "dropshot" courts;
	# the legacy "sports" id (or an unknown) returns "" -> no filter (every court). A court with no
	# "sport" field defaults to soccer (matches the pre-split library where only dropshot was tagged).
	var want_sport := ""
	if GameConfig.match_config != null:
		want_sport = SportsMode.sport_for_mode(GameConfig.match_config.mode_id)
	for c in (courts as Array):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var cd: Dictionary = c as Dictionary
		var cid := str(cd.get("id", ""))
		if cid == "":
			continue
		var court_sport := str(cd.get("sport", "soccer"))
		if want_sport != "" and court_sport != want_sport:
			continue
		var tier: int = int(cd.get("tier", 1))
		var unlocked: bool = Settings.is_court_unlocked(cid)
		out.append({
			"court_id": cid,
			"path": str(cd.get("path", "")),
			"name": str(cd.get("display_name", cid)),
			"tag": "" if unlocked else _court_lock_hint(str(cd.get("unlock", "always"))),
			"tier": tier,
			"color": TIER_COLORS.get(tier, MenuFX.ACCENT_PINK),
			"court": true,
			"locked": not unlocked,
		})
	# tier order (JSON is authored calm->chaos already; sort keeps a future out-of-order entry honest)
	var indexed: Array = []
	for i in range(out.size()):
		indexed.append([int((out[i] as Dictionary)["tier"]), i, out[i]])
	indexed.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var sorted_out: Array = []
	for e in indexed:
		sorted_out.append(e[2])
	return sorted_out

## Phrase a court's unlock rule for the locked-card hint band (v8 §4.3 gates, human words):
## "circuit:<id>" -> WIN <NAME> CIRCUIT · "sports_matches:N" -> PLAY N SPORTS MATCHES ·
## "sports_wins:N" -> WIN N SPORTS MATCHES. Unknown rule -> generic (Settings treats it as open anyway).
func _court_lock_hint(rule: String) -> String:
	var kind := rule.get_slice(":", 0)
	var arg := rule.get_slice(":", 1) if rule.contains(":") else ""
	match kind:
		"circuit":
			return "WIN %s CIRCUIT" % _circuit_name(arg).to_upper()
		"sports_matches":
			var n := maxi(1, int(arg))
			return "PLAY %d SPORTS MATCH%s" % [n, "" if n == 1 else "ES"]
		"sports_wins":
			var nw := maxi(1, int(arg))
			return "WIN %d SPORTS MATCH%s" % [nw, "" if nw == 1 else "ES"]
		_:
			return "LOCKED"

## Circuit display name for hint phrasing (lazy-loads circuits.json once; sports flow never runs
## _load_circuit_cards which normally fills _circuit_display).
func _circuit_name(cid: String) -> String:
	if _circuit_display.is_empty() and FileAccess.file_exists(CIRCUITS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CIRCUITS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			var circuits: Variant = (parsed as Dictionary).get("circuits", {})
			if typeof(circuits) == TYPE_DICTIONARY:
				for k in (circuits as Dictionary).keys():
					var e: Variant = (circuits as Dictionary)[k]
					if typeof(e) == TYPE_DICTIONARY:
						_circuit_display[str(k)] = str((e as Dictionary).get("display_name", k))
	return str(_circuit_display.get(cid, cid))

## Instance + dress one MenuCard for a shelf (sizes per §3.3; internals of MenuCard unchanged).
func _make_card(a: Dictionary, shelf: Control, shelf_id: int) -> Button:
	var big := shelf_id == 0
	var card: Button = CARD.instantiate()
	card.custom_minimum_size = SHELF_A_CARD if big else SHELF_B_CARD
	(shelf as Object).call("add_card", card)
	var thumb := _thumb_for(a)
	card.set_card({
		"name": a["name"], "tag": a.get("tag", ""), "color": a["color"],
		"glyph": a.get("glyph", ""), "art": thumb,
	})
	if thumb != null:
		# opaque thumbs/crests COVER the plate (full-bleed, cropped) rather than the transparent-
		# diorama KEEP_ASPECT_CENTERED default; the accent gradient + chocolate outline still frame it.
		var art := card.get_node_or_null("Content/VBox/Plate/Art")
		if art is TextureRect:
			(art as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# fixed name band so 1- and 2-line names align card-to-card (§3.3): Shelf A 100px / Shelf B 80px
	# (inner Labels min height; the strip's own padding tops it up).
	var labels := card.get_node_or_null("Content/VBox/NameStrip/Labels")
	if labels is Control:
		(labels as Control).custom_minimum_size = Vector2(0, 92 if big else 64)
	var nm := card.get_node_or_null("Content/VBox/NameStrip/Labels/NameLabel")
	if nm is Label:
		(nm as Label).add_theme_font_size_override("font_size", 40 if big else 34)
	var tag := card.get_node_or_null("Content/VBox/NameStrip/Labels/TagLabel")
	if tag is Label:
		(tag as Label).add_theme_font_size_override("font_size", 28)   # WK-18 couch floor (CC-8.1)
	# unlocked circuit line 2: real star icons + arena count (§3.7 — no ASCII stars)
	if bool(a.get("circuit", false)) and not bool(a.get("locked", false)):
		(card as Object).call("set_star_row", int(a.get("difficulty", 1)), 3,
			"%d ARENAS" % int(a.get("arena_count", 0)))
	# SPORTS court: tier badge chip, top-left of the art plate (§3.8; hidden slot on non-court cards)
	if bool(a.get("court", false)) and card.has_method("set_badge"):
		card.set_badge("TIER %d" % int(a.get("tier", 1)),
			TIER_COLORS.get(int(a.get("tier", 1)), MenuFX.ACCENT_PINK))
	# TRIALS circuit: ordinal badge + course count (owner 2026-07-16 circuit select)
	if bool(a.get("trials_set", false)):
		if card.has_method("set_badge"):
			card.set_badge("CIRCUIT %d" % int(a.get("difficulty", 1)), a.get("color", MenuFX.ACCENT_PINK))
		(card as Object).call("set_star_row", mini(int(a.get("difficulty", 1)), 3), 3,
			"%d COURSES" % int(a.get("arena_count", 0)))
	card.set_meta("arena", a)
	card.set_meta("shelf", shelf_id)
	card.set_meta("idx", _a_cards.size() if shelf_id == 0 else _b_cards.size())
	register(card, FOCUS_SCALE)
	card.focus_entered.connect(_on_card_focus.bind(card))
	card.focus_exited.connect(func() -> void: card.z_index = 0)
	card.gui_input.connect(_on_card_gui.bind(card))
	if bool(a.get("locked", false)) and card.has_method("set_locked"):
		card.set_locked(true)
	# RANDOM: shuffle collage (baked as _random.png); if missing, rainbow + spinning "?" fallback.
	if bool(a.get("random", false)) and thumb == null:
		card.set_plate_rainbow()
		_spin_glyph(card)
	return card

# ------------------------------------------------------------------ focus / navigation (§3.5)
## Left/right within the rail; ends point to SELF (no wrap, no cross-shelf auto-jump).
func _wire_rail(cards: Array[Button]) -> void:
	var n := cards.size()
	for i in range(n):
		var c: Button = cards[i]
		var lf: Control = cards[i - 1] if i > 0 else c
		var rt: Control = cards[i + 1] if i < n - 1 else c
		c.focus_neighbor_left = c.get_path_to(lf)
		c.focus_neighbor_right = c.get_path_to(rt)
		c.focus_previous = c.get_path_to(lf)
		c.focus_next = c.get_path_to(rt)

## Up/down across shelves lands on each shelf's REMEMBERED card; Back is reachable above Shelf A
## and below Shelf B. Re-run whenever a remembered index changes (cheap, <20 cards).
func _rewire_cross() -> void:
	if _a_cards.is_empty():
		return   # data failed to load; BACK is the only focusable (never crash)
	if _b_cards.is_empty():
		# single-shelf (SPORTS §3.8): up AND down from the shelf reach BACK
		var mem: Control = _a_cards[_a_idx]
		for c in _a_cards:
			c.focus_neighbor_top = c.get_path_to(_back)
			c.focus_neighbor_bottom = c.get_path_to(_back)
		_back.focus_neighbor_bottom = _back.get_path_to(mem)
		_back.focus_neighbor_top = _back.get_path_to(mem)
		return
	var a_mem: Control = _a_cards[_a_idx]
	var b_mem: Control = _b_cards[_b_idx]
	for c in _a_cards:
		c.focus_neighbor_top = c.get_path_to(_back)
		c.focus_neighbor_bottom = c.get_path_to(b_mem)
	for c in _b_cards:
		c.focus_neighbor_top = c.get_path_to(a_mem)
		c.focus_neighbor_bottom = c.get_path_to(_back)
	_back.focus_neighbor_bottom = _back.get_path_to(a_mem)
	_back.focus_neighbor_top = _back.get_path_to(b_mem)

func _on_card_focus(card: Button) -> void:
	card.z_index = 1   # focused card raises above rail neighbours (§3.6)
	var shelf_id := int(card.get_meta("shelf", 0))
	var idx := int(card.get_meta("idx", 0))
	if shelf_id == 0:
		_a_idx = idx
		(_shelf_a as Object).call("set_counter", idx, _a_cards.size())
	else:
		_b_idx = idx
		(_shelf_b as Object).call("set_counter", idx, _b_cards.size())
	(_shelf_a as Object).call("set_shelf_focused", shelf_id == 0)
	(_shelf_b as Object).call("set_shelf_focused", shelf_id == 1)
	(_shelf_a if shelf_id == 0 else _shelf_b).call("scroll_to", card)
	_rewire_cross()

## Edge press feedback + mouse wheel on a hovered card. Key/pad events reach the focused card's
## gui_input before viewport focus-nav; wheel events are swallowed by the Button so they're
## re-routed from here (the shelf background handles wheel in gaps via wheel_moved).
func _on_card_gui(e: InputEvent, card: Button) -> void:
	var shelf_id := int(card.get_meta("shelf", 0))
	var cards: Array[Button] = _a_cards if shelf_id == 0 else _b_cards
	var idx := int(card.get_meta("idx", 0))
	if e.is_action_pressed("ui_left") and idx == 0:
		_edge_deny(shelf_id, -1)
	elif e.is_action_pressed("ui_right") and idx == cards.size() - 1:
		_edge_deny(shelf_id, 1)
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var btn := (e as InputEventMouseButton).button_index
		if btn == MOUSE_BUTTON_WHEEL_DOWN:
			_step_shelf(shelf_id, 1)
		elif btn == MOUSE_BUTTON_WHEEL_UP:
			_step_shelf(shelf_id, -1)

## End of shelf: 6px rail nudge + the low deny tick at -6dB (§3.5).
func _edge_deny(shelf_id: int, dir: int) -> void:
	(_shelf_a if shelf_id == 0 else _shelf_b).call("edge_nudge", dir)
	AudioManager.play_sfx("ui_click", {"pitch": 0.55, "pitch_var": 0.0, "volume_db": -6.0})

func _on_wheel(dir: int, shelf_id: int) -> void:
	_step_shelf(shelf_id, dir)

func _step_shelf(shelf_id: int, delta: int) -> void:
	var cards: Array[Button] = _a_cards if shelf_id == 0 else _b_cards
	var cur := _a_idx if shelf_id == 0 else _b_idx
	var to := clampi(cur + delta, 0, cards.size() - 1)
	if to == cur:
		_edge_deny(shelf_id, signi(delta))
		return
	cards[to].grab_focus()

## LB/RB + PageUp/PageDown: jump 3 cards along the CURRENT shelf (the 30+ arena answer, §3.5).
## WK-11 / CC-3.3: once a lobby exists, devices that never joined can't drive this shared screen (focus nav,
## FIGHT!, page jumps, back). _input runs before GUI focus navigation, so eating the event here stops it all.
## Mouse / keyless events always pass (CC-2.4).
func _input(e: InputEvent) -> void:
	if not InputRouter.may_drive_shared(e):
		get_viewport().set_input_as_handled()

func _unhandled_input(e: InputEvent) -> void:
	super._unhandled_input(e)
	if not _entered:
		return
	if e.is_action_pressed("menu_page_next"):
		accept_event()
		_page_jump(PAGE_JUMP)
	elif e.is_action_pressed("menu_page_prev"):
		accept_event()
		_page_jump(-PAGE_JUMP)

func _page_jump(delta: int) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var shelf_id := 0
	if focused != null and focused.has_meta("shelf"):
		shelf_id = int(focused.get_meta("shelf"))
	elif focused == _back:
		return
	_step_shelf(shelf_id, delta)

# ------------------------------------------------------------------ MenuScreen hooks
func first_focus() -> Control:
	if _a_cards.is_empty():
		return _back
	return _a_cards[0]   # RANDOM ROTATION (brawl) / first tier-1 court (sports)

func stagger_items() -> Array:
	# entry stagger per shelf left-to-right, Shelf A first (§3.6)
	var all: Array = []
	all.append_array(_a_cards)
	all.append_array(_b_cards)
	return all

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
	if bool(a.get("trials_set", false)):
		# TRIALS: the set id rides circuit_id (TrialsMode._load_course_set's key); launch directly.
		cfg.arena_mode = MatchConfig.ArenaMode.CIRCUIT
		cfg.circuit_id = StringName(str(a["set_id"]))
		cfg.single_arena_path = ""
		if shell != null:
			shell.launch_match()
		return
	if bool(a.get("court", false)):
		# SPORTS: pass the court ID (not the path) — SportsMode._resolve_court stays the single
		# source of truth for unlock/missing-file fallback (the CD #7 ball-through-world guard).
		cfg.arena_mode = MatchConfig.ArenaMode.SINGLE
		cfg.single_arena_path = str(a["court_id"])
		cfg.circuit_id = &""
	elif bool(a.get("circuit", false)):
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

## One-shot "you earned it" moment: a banner flash + a pop/focus-snap on the just-unlocked card,
## with the win announcer sting. The card is scrolled to center first (§3.6) so the celebration is
## never off-screen. The pending flag was already consumed (take_pending_unlock) so it fires once.
func _play_unlock_celebration(cid: String) -> void:
	var banner := get_node_or_null("UnlockBanner")
	var display := str(_circuit_display.get(cid, cid)).to_upper()
	# find the (now-unlocked) card for this circuit (Shelf A holds the circuits)
	var target: Button = null
	for card in _a_cards:
		var a: Dictionary = card.get_meta("arena", {})
		if bool(a.get("circuit", false)) and str(a.get("circuit_id", "")) == cid:
			target = card
			break
	# delay until the stagger has mostly landed, then celebrate
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		AudioManager.play_sfx("ui_click", {"pitch": 1.5, "pitch_var": 0.0, "volume_db": 0.0})
		EventBus.match_won.emit(0)   # reuse the win fanfare sting (presentation only)
		if is_instance_valid(target):
			(_shelf_a as Object).call("scroll_to", target)
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
			tc.tween_property(target, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
