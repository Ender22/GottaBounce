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
##
## WK-60b (UX4-12, the Mario Kart cup-select bar): the TOP half is a PREVIEW of the focused card — big framed key
## art (circuit / trials crest; the mode painting + a small court-map inset for courts; a fan of every circuit crest
## for RANDOM ROTATION), its name, a difficulty / size line in words ("EASY · 20 ARENAS"), a one-line hook, and
## rule / roster / status chips (LOCKED with the unlock condition, CLEARED for won Brawl circuits). The ONE shelf
## sits in the lower half. WK-65: courts show their own painted badge (card: zoomed onto the interior; preview: the whole
## badge, no map inset) and RANDOM ROTATION its painted crest; the mode painting + inset and the crest fan are now only the
## existence-guarded fallbacks. WK-60: one shelf pattern in all three variants (no "WAYS TO PLAY" label, no bare "i / n"
## counter; the preview kicker says "CIRCUIT 2 OF 5"), and the footer never offers A on a LOCKED card.

const CARD := preload("res://scenes/ui/MenuCard.tscn")
const ToyKit := preload("res://src/ui/ToyKit.gd")
const CIRCUITS_PATH := "res://levels/circuits.json"
const COURTS_PATH := "res://levels/sports_courts.json"
# Baked wide arena thumbnails (frontend_visual_polish.md §3b), produced offline by
# tools/ThumbBaker.tscn. Loaded (not preloaded) + existence-guarded so a missing bake just falls
# back to the themed gradient tile. "_random" is the RANDOM card's shuffle collage.
const THUMB_DIR := "res://assets/ui/thumbs"
# Circuit crest emblems (frontend_ui_audit §3.7). Existence-guarded: missing crest -> the themed
# gradient plate + circuit name (the audit's sanctioned fallback).
const CREST_DIR := "res://assets/ui/circuits"
# WK-65: painted court badges (1280x800, shared toy-stadium frame; docs/briefs/court_cards_2026-11-15.md). Loaded +
# existence-guarded; a missing badge falls back to the ThumbBaker bake under THUMB_DIR (card) / the mode painting (preview).
const COURT_BADGE_DIR := "res://assets/ui/courts"
# WK-65 (UX4-12): the painted Brawl RANDOM ROTATION crest (gold-shield crest family). Missing -> rainbow plate + "?" / crest fan.
const RANDOM_CREST := "res://assets/ui/circuits/crest_random.png"

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
const GO_WORD_BRAWL := "FIGHT!"
const GO_WORD_SPORTS := "PLAY!"   # WK-117: court-select confirm word (brawl keeps FIGHT!)
const GO_WORD_TRIALS := "GO!"     # WK-117 / WK-43: trials circuit-select confirm word

# WK-60b: difficulty / tier spelled out in words (UX4-12: "EASY · 20 ARENAS", not bare stars).
const DIFF_WORDS := {1: "EASY", 2: "MEDIUM", 3: "HARD", 4: "WILD"}
const TIER_WORDS := {1: "CALM", 2: "TRICKY", 3: "RISKY", 4: "WILD", 5: "CHAOS"}
const HAZARD_WORDS := {"spinning_hammer": "SPINNING HAMMER", "bomb": "LANDMINES", "crusher": "CRUSHER"}
const HAZARD_SHORT := {"spinning_hammer": "HAMMER", "bomb": "MINES", "crusher": "CRUSHER"}
# WK-60b: hero art for a COURT preview when its WK-65 painted badge is missing (the baked court thumbs are the dark
# stadium strip, which UX4-12 bans at hero size; it rides along as a small "court map" inset instead).
const LOCKED_CHIP := Color("#ddd6ea")   # WK-60b preview LOCKED pill fill (pale lilac = the locked-card tint family)
const COURT_HERO := {"soccer": "res://assets/ui/modes/mode_sports.png", "dropshot": "res://assets/ui/modes/mode_dropshot.png"}

# WK-60 (R-20): "A new peak every round." read like a typo. RANDOM_ALL plays the classic arena pool (ARENAS below
# mirrors PartyMatch.LEVEL_POOL) as a shuffle bag.
const RANDOM := {"path": "", "name": "RANDOM ROTATION", "tag": "%d ARENAS, SHUFFLED",
	"hook": "Every classic arena in one shuffled bag. A surprise every round.",
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
# WK-60b preview region (scenes/ui/ArenaSelect.tscn "Preview")
@onready var _preview: Control = $Preview
@onready var _pv_grad: TextureRect = $Preview/Row/ArtFrame/Grad
@onready var _pv_rays: TextureRect = $Preview/Row/ArtFrame/Rays
@onready var _pv_art: TextureRect = $Preview/Row/ArtFrame/Art
@onready var _pv_fan: Control = $Preview/Row/ArtFrame/Fan
@onready var _pv_inset: Control = $Preview/Row/ArtFrame/Inset
@onready var _pv_map: TextureRect = $Preview/Row/ArtFrame/Inset/Map
@onready var _pv_veil: Control = $Preview/Row/ArtFrame/Veil
@onready var _pv_kicker: Label = $Preview/Row/Info/Kicker
@onready var _pv_name: Label = $Preview/Row/Info/Name
@onready var _pv_desc: Label = $Preview/Row/Info/Desc
@onready var _pv_hook: Label = $Preview/Row/Info/Hook
@onready var _pv_rule: PanelContainer = $Preview/Row/Info/Chips/RuleChip
@onready var _pv_roster: PanelContainer = $Preview/Row/Info/Chips/RosterChip
@onready var _pv_status: PanelContainer = $Preview/Row/Info/Chips/StatusChip
@onready var _pv_status_icon: Control = $Preview/Row/Info/Chips/StatusChip/Row/Icon
@onready var _pv_status_label: Label = $Preview/Row/Info/Chips/StatusChip/Row/Label

var _a_cards: Array[Button] = []
var _b_cards: Array[Button] = []
var _a_idx := 0   # remembered focus per shelf (§3.5 up/down restores it)
var _b_idx := 0
var _circuit_ids: Array[String] = []   # brawl circuits in circuits.json order (RANDOM's crest fan)
var _hints_key := ""                   # WK-60: footer hint set currently shown (rebuild only on change)
var _pop_tween: Tween

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
		var shuffled: bool = draw_count > 0 and pool.size() > 0
		var count: int = draw_count if shuffled else levels.size()
		var unlocked: bool = Settings.is_circuit_unlocked(str(cid))
		var cleared: bool = Settings.circuits_cleared.has(str(cid))
		_circuit_ids.append(str(cid))
		var lock: Dictionary = {} if unlocked else _lock_hint(str(cid))
		out.append({
			"circuit_id": str(cid),
			"name": display,
			"tag": str(lock.get("short", "")),
			"lock_footer": str(lock.get("footer", "")),
			"hook": str(ed.get("tagline", "")),
			"difficulty": diff,
			"arena_count": count,
			"pool_size": pool.size() if shuffled else levels.size(),
			"shuffled": shuffled,
			"color": CIRCUIT_COLORS.get(str(cid), MenuFX.ACCENT_PINK),
			"circuit": true,
			"locked": not unlocked,
			"cleared": cleared and unlocked,
		})
	return out

## Phrase the unlock condition for a locked circuit card (v6 §4.3): the pity path once the
## predecessor has been played at least once, else the mastery (win) hint.
## WK-60: {"short": card / preview chip line, "footer": the footer prompt that replaces "A FIGHT!" (UX4-12)}.
func _lock_hint(cid: String) -> Dictionary:
	var pred := Settings.unlock_predecessor(cid)
	var pred_name := str(_circuit_display.get(pred, pred)).to_upper()
	var remaining := Settings.pity_matches_remaining(cid)
	if remaining < Settings.UNLOCK_PITY_MATCHES and remaining > 0:
		var es := "" if remaining == 1 else "ES"
		return {"short": "%d MORE MATCH%s" % [remaining, es],
			"footer": "LOCKED · play %s %d more time%s" % [pred_name, remaining, "" if remaining == 1 else "s"]}
	return {"short": "WIN %s" % pred_name, "footer": "LOCKED · win %s" % pred_name}

## Art for a card, or null (falls back to the themed gradient plate). RANDOM gets the shuffle
## collage; an arena gets its bake; a circuit gets its crest emblem (when the asset lands).
func _thumb_for(a: Dictionary) -> Texture2D:
	var path := ""
	if bool(a.get("court", false)):
		# court: court_<id> namespace (ThumbBaker bakes courts under it — the court id "minefield"
		# collides with the brawl arena of the same name). Missing -> gradient plate.
		# WK-65: the painted badge first, then the bake (do NOT write painted art into THUMB_DIR: a re-bake clobbers it).
		var badge := _court_badge(a)
		if badge != null:
			return badge
		path = "%s/court_%s.png" % [THUMB_DIR, str(a.get("court_id", ""))]
	elif bool(a.get("circuit", false)):
		path = "%s/crest_%s.png" % [CREST_DIR, str(a.get("circuit_id", ""))]
	elif bool(a.get("trials_set", false)):
		path = "%s/crest_trials_%s.png" % [CREST_DIR, str(a.get("set_id", ""))]
	elif bool(a.get("random", false)):
		# WK-65: the painted RANDOM ROTATION crest. The old _random.png bake (dark three-screenshot strip) is banned
		# by UX4-35, so a missing crest returns null (rainbow plate + spinning "?" / the crest fan).
		path = RANDOM_CREST
	else:
		var id := str(a.get("path", "")).get_file().get_basename()
		if id == "":
			return null
		path = "%s/%s.png" % [THUMB_DIR, id]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

## WK-65: a court's painted badge (assets/ui/courts/court_<id>.png), or null.
func _court_badge(a: Dictionary) -> Texture2D:
	return _load_tex("%s/court_%s.png" % [COURT_BADGE_DIR, str(a.get("court_id", ""))])

## WK-65: the shelf card's view of a court badge. The frame's opening came out ~2.13:1 (brief planned 1.90), so a plain
## cover crop shows a cut-off top rim + the bottom rim around a small interior. Tuning.court_card_zoom crops toward the
## badge centre first (an AtlasTexture region; the card's COVERED stretch then trims it to the slot), so the slot lands
## on the painted interior + thin red / blue side rims, as the brief's §2 table intends. 1.0 = the plain cover crop.
func _court_card_tex(badge: Texture2D) -> Texture2D:
	var z: float = Tuning.court_card_zoom
	if z <= 1.0:
		return badge
	var full := Vector2(badge.get_width(), badge.get_height())
	var sz := full / z
	var at := AtlasTexture.new()
	at.atlas = badge
	at.region = Rect2((full - sz) * 0.5 + Vector2(0.0, Tuning.court_card_dy * full.y), sz)
	at.filter_clip = true
	return at

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
	# WK-40 (CC-5.5): BACK is a "B BACK" glyph chip, mouse-clickable, never a pad focus stop (B / Esc go back).
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", {"pitch": 0.72, "pitch_var": 0.0, "volume_db": -4.0})
		on_back())
	_rewire_cross()
	# WK-117 (SP-16) + WK-43 copy half: the confirm prompt speaks the mode's language (sports PLAY!, trials GO!);
	# BRAWL keeps the scene's "A FIGHT!".
	# WK-60: the footer follows focus (a LOCKED card swaps A for the unlock condition), see _update_footer.
	_update_footer({})
	_start_rays()
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
	# ONE shelf in the lower half (WK-60b; the .tscn places it under the preview); no arena pool shelf.
	_shelf_b.visible = false
	# circuits in circuits.json order, then RANDOM ROTATION last.
	var shelf_a_data: Array = _load_circuit_cards()
	var rnd: Dictionary = RANDOM.duplicate()
	rnd["tag"] = str(RANDOM["tag"]) % ARENAS.size()
	shelf_a_data.append(rnd)
	_setup_shelf("CIRCUITS")
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
	var courts := _load_court_cards()
	_setup_shelf("COURTS")
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
	var sets := _load_trials_cards()
	_setup_shelf("CIRCUITS")
	for a in sets:
		_a_cards.append(_make_card(a, _shelf_a, 0))
	(_shelf_a as Object).call("set_counter", 0, _a_cards.size())
	_shelf_a.connect("wheel_moved", _on_wheel.bind(0))
	_wire_rail(_a_cards)

## WK-60 (UX4-25): ONE shelf pattern for all three variants. The screen title already names what the shelf holds
## and the preview kicker says where you are ("CIRCUIT 2 OF 5"), so the shelf's own label and bare "i / n" counter
## (R-20: "WAYS TO PLAY" / "1 / 6" read oddly; "COURTS 8" vs "CIRCUITS 6" disagreed) are hidden the same way
## everywhere. The label text is still set so a future multi-shelf layout reads consistently.
func _setup_shelf(label: String) -> void:
	(_shelf_a as Object).call("set_label", label)
	(_shelf_a as Object).call("set_separation", 36)
	for n in ["ShelfLabel", "Counter"]:
		var c := _shelf_a.get_node_or_null(n)
		if c is CanvasItem:
			(c as CanvasItem).visible = false

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
			"tag": "",   # WK-60b: the tagline moved to the preview hook; the card keeps name + stars + count
			"hook": str(ed.get("tagline", "")),
			"color": Color(str(ed.get("color", "#4aa8ff"))),
			"trials_set": true,
			"difficulty": n,
			"arena_count": have,
			"card_focus_y": float(ed.get("card_focus_y", 0.5)),   # WK-158: crest focal height for the shelf-card crop
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
		var lock: Dictionary = {} if unlocked else _court_lock_hint(str(cd.get("unlock", "always")))
		# WK-60b: the card's second line is the court in words (UX4-64: the lower half used to be blank)
		var line := "%s · %s" % [str(TIER_WORDS.get(tier, "")), _hazard_words(str(cd.get("hazard", "")))]
		out.append({
			"court_id": cid,
			"path": str(cd.get("path", "")),
			"name": str(cd.get("display_name", cid)),
			"tag": line if unlocked else str(lock.get("short", "LOCKED")),
			"desc": line,
			"lock_footer": str(lock.get("footer", "")),
			"hook": str(cd.get("blurb", "")),
			"sport": court_sport,
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
## "circuit:<id>" -> WIN <NAME> · "sports_matches:N" -> PLAY N SPORTS MATCHES ·
## "sports_wins:N" -> WIN N SPORTS MATCHES. Unknown rule -> generic (Settings treats it as open anyway).
## WK-60: {"short": card / preview chip line, "footer": the footer prompt that replaces "A PLAY!"}.
func _court_lock_hint(rule: String) -> Dictionary:
	var kind := rule.get_slice(":", 0)
	var arg := rule.get_slice(":", 1) if rule.contains(":") else ""
	match kind:
		"circuit":
			var cn := _circuit_name(arg).to_upper()
			return {"short": "WIN %s" % cn, "footer": "LOCKED · win the BRAWL circuit %s" % cn}
		"sports_matches":
			var n := maxi(1, int(arg))
			var es := "" if n == 1 else "ES"
			return {"short": "PLAY %d SPORTS MATCH%s" % [n, es], "footer": "LOCKED · play %d sports match%s" % [n, es.to_lower()]}
		"sports_wins":
			var nw := maxi(1, int(arg))
			var es2 := "" if nw == 1 else "ES"
			return {"short": "WIN %d SPORTS MATCH%s" % [nw, es2], "footer": "LOCKED · win %d sports match%s" % [nw, es2.to_lower()]}
		_:
			return {"short": "LOCKED", "footer": "LOCKED"}

## WK-60b: a court's hazard field in words ("" -> NO HAZARDS; one -> its full name; several -> short names joined).
func _hazard_words(h: String) -> String:
	if h == "":
		return "NO HAZARDS"
	var parts := h.split("+", false)
	if parts.size() == 1:
		return str(HAZARD_WORDS.get(parts[0], parts[0].to_upper().replace("_", " ")))
	var words := PackedStringArray()
	for p in parts:
		words.append(str(HAZARD_SHORT.get(p, p.to_upper().replace("_", " "))))
	return " + ".join(words)

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

## WK-158 (CD4-07b): COVERED always crops around the art's CENTRE, so a portrait crest whose subject sits high (FLIGHT
## SCHOOL: the goat in the ring is at ~1/3 height) lost its goat to the plate's top edge. Swap in an AtlasTexture region with
## the plate's aspect centred on `fy` (0 = top, 1 = bottom; clamped inside the art); refits whenever the plate resizes.
func _focus_crop(art: TextureRect, tex: Texture2D, fy: float) -> void:
	var fit := func() -> void:
		var sz: Vector2 = art.size
		if sz.x < 2.0 or sz.y < 2.0 or tex == null:
			return
		var tw: float = float(tex.get_width())
		var th: float = float(tex.get_height())
		var rw: float = minf(tw, th * sz.x / sz.y)
		var rh: float = minf(th, tw * sz.y / sz.x)
		var y0: float = clampf(fy * th - rh * 0.5, 0.0, th - rh)
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((tw - rw) * 0.5, y0, rw, rh)
		art.texture = at
	art.resized.connect(fit)
	fit.call()

## Instance + dress one MenuCard for a shelf (sizes per §3.3; internals of MenuCard unchanged).
func _make_card(a: Dictionary, shelf: Control, shelf_id: int) -> Button:
	var big := shelf_id == 0
	var card: Button = CARD.instantiate()
	# WK-60b: the shelf sits under the preview now, so its cards are a size down (Tuning.arena_select_card_size)
	card.custom_minimum_size = Tuning.arena_select_card_size if big else SHELF_B_CARD
	(shelf as Object).call("add_card", card)
	# WK-60 (R-20 / UX4-35): the RANDOM card no longer wears the old dark three-screenshot strip (_random.png).
	# WK-65: it wears the painted RANDOM ROTATION crest (via _thumb_for); rainbow plate + spinning "?" if that is missing.
	# A court card shows its painted badge zoomed onto the interior (_court_card_tex).
	var thumb: Texture2D = _thumb_for(a)
	if thumb != null and bool(a.get("court", false)) and _court_badge(a) != null:
		thumb = _court_card_tex(thumb)
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
			var fy: float = float(a.get("card_focus_y", 0.5))
			if not is_equal_approx(fy, 0.5):
				_focus_crop(art as TextureRect, thumb, fy)   # WK-158
	# fixed name band so 1- and 2-line names align card-to-card (§3.3): Shelf A 100px / Shelf B 80px
	# (inner Labels min height; the strip's own padding tops it up).
	# WK-60b: every shelf card is name + ONE line (stars + count / the court in words / the unlock condition), so
	# one fixed band height lines every art plate up.
	var labels := card.get_node_or_null("Content/VBox/NameStrip/Labels")
	if labels is Control:
		(labels as Control).custom_minimum_size = Vector2(0, 78 if big else 64)
	var nm := card.get_node_or_null("Content/VBox/NameStrip/Labels/NameLabel")
	if nm is Label:
		(nm as Label).add_theme_font_size_override("font_size", 36 if big else 34)
	var tag := card.get_node_or_null("Content/VBox/NameStrip/Labels/TagLabel")
	if tag is Label:
		(tag as Label).add_theme_font_size_override("font_size", 28)   # WK-18 couch floor (CC-8.1)
	# unlocked circuit line 2: real star icons + arena count (§3.7 — no ASCII stars)
	if bool(a.get("circuit", false)) and not bool(a.get("locked", false)):
		(card as Object).call("set_star_row", int(a.get("difficulty", 1)), 3,
			"%d ARENAS" % int(a.get("arena_count", 0)))
	# WK-60b (UX4-25): a WON Brawl circuit shows it on the card (gold CLEARED chip, top-left of the art plate)
	if bool(a.get("cleared", false)) and card.has_method("set_badge"):
		card.set_badge("CLEARED", ToyKit.GOLD.darkened(0.25))
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
	# RANDOM: the painted crest (WK-65); if missing, rainbow + spinning "?" fallback.
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

## Up/down across shelves lands on the other shelf's REMEMBERED card (two shelves wrap: a short vertical list,
## CC-5.2). WK-40: BACK is no longer in the chain — a single shelf points up/down at SELF and _on_card_gui answers
## with a deny tick + shake. Re-run whenever a remembered index changes (cheap, <20 cards).
func _rewire_cross() -> void:
	if _a_cards.is_empty():
		return   # data failed to load; B is the only way out (never crash)
	if _b_cards.is_empty():
		for c in _a_cards:
			c.focus_neighbor_top = c.get_path_to(c)
			c.focus_neighbor_bottom = c.get_path_to(c)
		return
	var a_mem: Control = _a_cards[_a_idx]
	var b_mem: Control = _b_cards[_b_idx]
	for c in _a_cards:
		c.focus_neighbor_top = c.get_path_to(b_mem)
		c.focus_neighbor_bottom = c.get_path_to(b_mem)
	for c in _b_cards:
		c.focus_neighbor_top = c.get_path_to(a_mem)
		c.focus_neighbor_bottom = c.get_path_to(a_mem)

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
	var a: Dictionary = card.get_meta("arena", {})
	_show_preview(a, idx)
	_update_footer(a)

# ------------------------------------------------------------------ WK-60b preview region
## Fill the top-half preview from the focused card's data: framed key art, kicker, name, words line, hook, chips.
func _show_preview(a: Dictionary, idx: int) -> void:
	var accent: Color = a.get("color", MenuFX.ACCENT_PINK)
	var locked := bool(a.get("locked", false))
	_pv_grad.texture = _plate_gradient(accent)
	# --- art: crest / court badge / RANDOM crest (WK-65); fallbacks: mode painting + map inset / RANDOM's crest fan
	var is_random := bool(a.get("random", false))
	var is_court := bool(a.get("court", false))
	var art: Texture2D = null
	var badge: Texture2D = _court_badge(a) if is_court else null
	if is_court:
		# WK-65: the court's own painted badge; the mode painting only when the badge is missing
		art = badge if badge != null else _load_tex(str(COURT_HERO.get(str(a.get("sport", "soccer")), COURT_HERO["soccer"])))
	else:
		art = _thumb_for(a)   # circuit / trials crest; RANDOM -> crest_random.png (WK-65)
	var use_fan := is_random and art == null   # crest fan = the RANDOM fallback only
	_pv_art.texture = art
	_pv_art.visible = art != null and not use_fan
	_pv_fan.visible = use_fan
	if use_fan:
		_fill_fan()
	# WK-65 (brief §7): the dark court-map inset only rides along the mode-painting fallback. Over a painted badge it
	# would cover the badge's lower right and bring back the dark strip UX4-12 banned.
	var map: Texture2D = _thumb_for(a) if is_court and badge == null else null
	_pv_map.texture = map
	_pv_inset.visible = map != null
	var tint: Color = Tuning.arena_preview_locked_tint if locked else Color.WHITE
	for n in [_pv_art, _pv_fan, _pv_inset, _pv_grad]:
		(n as CanvasItem).modulate = tint
	_pv_rays.self_modulate = tint   # modulate.a carries Tuning.arena_preview_rays_alpha
	_pv_veil.visible = locked
	# --- text
	var total := _a_cards.size()
	if bool(a.get("circuit", false)):
		total = _circuit_ids.size()
	_pv_kicker.text = _kicker(a, idx, total)
	_pv_name.text = str(a.get("name", "")).to_upper()
	_pv_desc.text = _desc_line(a)
	_pv_hook.text = str(a.get("hook", ""))
	_fill_chips(a, accent)
	_pop_art()

func _kicker(a: Dictionary, idx: int, total: int) -> String:
	if bool(a.get("random", false)):
		return "WILDCARD"
	if bool(a.get("court", false)):
		return "COURT %d OF %d" % [idx + 1, total]
	return "CIRCUIT %d OF %d" % [idx + 1, total]

## The difficulty / size line in WORDS (UX4-12): "EASY  ·  20 ARENAS", "HARD  ·  12 OF 16 ARENAS, SHUFFLED",
## "CALM  ·  NO HAZARDS", "MEDIUM  ·  8 COURSES".
func _desc_line(a: Dictionary) -> String:
	if bool(a.get("random", false)):
		return "SURPRISE  ·  %d ARENAS, SHUFFLED" % ARENAS.size()
	if bool(a.get("court", false)):
		return str(a.get("desc", "")).replace(" · ", "  ·  ")
	var diff: int = clampi(int(a.get("difficulty", 1)), 1, 4)
	if bool(a.get("trials_set", false)):
		diff = clampi(diff, 1, 3)   # same 3-star scale the card shows
		return "%s  ·  %d COURSES" % [str(DIFF_WORDS[diff]), int(a.get("arena_count", 0))]
	if bool(a.get("shuffled", false)):
		return "%s  ·  %d OF %d ARENAS, SHUFFLED" % [str(DIFF_WORDS[diff]), int(a.get("arena_count", 0)),
			int(a.get("pool_size", 0))]
	return "%s  ·  %d ARENAS" % [str(DIFF_WORDS[diff]), int(a.get("arena_count", 0))]

## Rule chip (accent fill), roster chip (cream pill) and status chip (LOCKED choco / CLEARED gold).
func _fill_chips(a: Dictionary, accent: Color) -> void:
	var cfg: MatchConfig = GameConfig.match_config
	var humans: int = cfg.human_count if cfg != null else 1
	var bots: int = cfg.bot_count if cfg != null else 0
	var roster := "%d PLAYER%s" % [humans, "" if humans == 1 else "S"]
	if bots > 0:
		roster += " + %d CPU%s" % [bots, "" if bots == 1 else "s"]
	var rule := ""
	if _sports:
		# DROPSHOT scores POINTS (SportsMode.goal_word "POINT!"); ROCKETBALL scores GOALS
		var sport := SportsMode.sport_for_mode(cfg.mode_id) if cfg != null else ""
		rule = "FIRST TO %d %s" % [Tuning.sports_goal_target, "POINTS" if sport == "dropshot" else "GOALS"]
		var seats := humans + bots
		var side := int(seats / 2.0)
		roster = ("%dV%d  ·  " % [side, side] if seats >= 2 else "") + roster
	elif _trials:
		rule = "FINISH EVERY COURSE"
		roster = "SOLO" if humans <= 1 else "CO-OP  ·  %d PLAYERS" % humans
	else:
		rule = "FIRST TO %d KOs" % (cfg.kills_to_win if cfg != null else 10)
	(_pv_rule.get_node("Label") as Label).text = rule
	ToyKit.fill_panel(_pv_rule, accent.darkened(0.12))
	(_pv_roster.get_node("Label") as Label).text = roster
	var locked := bool(a.get("locked", false))
	var cleared := bool(a.get("cleared", false))
	_pv_roster.visible = not locked   # the unlock condition needs the room more than the roster does
	_pv_status.visible = locked or cleared
	# LOCKED = a pale lilac pill with chocolate type (the padlock glyph is drawn chocolate + cream, so it needs a light
	# fill); CLEARED = the gold chip with white type + the green tick.
	_pv_status.remove_theme_stylebox_override("panel")
	_pv_status_label.remove_theme_color_override("font_color")
	if locked:
		_pv_status.theme_type_variation = &"ToyPill"
		_pv_status_label.theme_type_variation = &"TextDark"
		_pv_status_icon.call("setup", "lock")
		_pv_status_label.text = "LOCKED  ·  %s" % str(a.get("tag", ""))
		ToyKit.fill_panel(_pv_status, LOCKED_CHIP)
	elif cleared:
		_pv_status.theme_type_variation = &"ToyChip"
		_pv_status_label.theme_type_variation = &"ToyChipLabel"
		_pv_status_icon.call("setup", "check")
		_pv_status_label.text = "CLEARED"
		ToyKit.fill_panel(_pv_status, ToyKit.GOLD.darkened(0.25))

## RANDOM ROTATION's fallback hero when crest_random.png is missing (WK-65): a fan of every circuit crest.
func _fill_fan() -> void:
	var crests: Array[Texture2D] = []
	for cid in _circuit_ids:
		var t := _load_tex("%s/crest_%s.png" % [CREST_DIR, cid])
		if t != null:
			crests.append(t)
	for i in range(5):
		var tr := _pv_fan.get_node_or_null("Crest%d" % i) as TextureRect
		if tr == null:
			continue
		tr.texture = crests[i % crests.size()] if not crests.is_empty() else null
		tr.visible = tr.texture != null

## Focus moved: a short pop on the art so the change reads (Tuning.arena_preview_*).
func _pop_art() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	var tgt: Control = _pv_fan if _pv_fan.visible else _pv_art
	tgt.pivot_offset = tgt.size * 0.5
	var dur: float = maxf(0.01, Tuning.arena_preview_swap_time)
	tgt.scale = Vector2.ONE * Tuning.arena_preview_art_pop
	_pv_name.modulate.a = 0.35
	_pop_tween = create_tween().set_parallel(true)
	_pop_tween.tween_property(tgt, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(_pv_name, "modulate:a", 1.0, dur)

func _start_rays() -> void:
	_pv_rays.modulate.a = Tuning.arena_preview_rays_alpha
	if Tuning.arena_preview_rays_spin <= 0.0:
		return
	var t := _pv_rays.create_tween().set_loops()
	t.tween_property(_pv_rays, "rotation", TAU, 360.0 / Tuning.arena_preview_rays_spin).from(0.0)

func _plate_gradient(c: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, c.lightened(0.18))
	grad.set_color(1, c.darkened(0.38))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 64
	gt.height = 64
	return gt

func _load_tex(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

## WK-60 (UX4-12 / CC-1.7): the footer names what A really does on the focused card. A LOCKED card shows the unlock
## condition with a padlock instead of "A FIGHT!" (pressing is refused there). Rebuilt only when the set changes.
func _update_footer(a: Dictionary) -> void:
	var hb := get_node_or_null("Footer/HintBox")
	if hb == null or not hb.has_method("set_hints"):
		return
	var first := "A|%s" % (GO_WORD_SPORTS if _sports else (GO_WORD_TRIALS if _trials else GO_WORD_BRAWL))
	if bool(a.get("locked", false)):
		# text only: no A glyph (A is refused here), and the padlock glyph is chocolate-on-scrim invisible
		first = "|%s" % str(a.get("lock_footer", "LOCKED"))
	if first == _hints_key:
		return
	_hints_key = first
	hb.call("set_hints", PackedStringArray([first, "B|Back", "< >|Choose"]))

## Edge press feedback + mouse wheel on a hovered card. Key/pad events reach the focused card's
## gui_input before viewport focus-nav; wheel events are swallowed by the Button so they're
## re-routed from here (the shelf background handles wheel in gaps via wheel_moved).
func _on_card_gui(e: InputEvent, card: Button) -> void:
	var shelf_id := int(card.get_meta("shelf", 0))
	var cards: Array[Button] = _a_cards if shelf_id == 0 else _b_cards
	var idx := int(card.get_meta("idx", 0))
	if (e.is_action_pressed("ui_up") or e.is_action_pressed("ui_down")) and _b_cards.is_empty():
		AudioManager.play_sfx("ui_click", {"pitch": 0.55, "pitch_var": 0.0, "volume_db": -6.0})   # WK-40: no shelf to go to
		MenuFX.reject_shake(card)
	elif e.is_action_pressed("ui_left") and idx == 0:
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
		return null   # WK-40: nothing focusable; B backs out
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
	# WK-60b: the preview drops in with the header (it is content, so it stays under the header/footer bands)
	var rest := _preview.position
	_preview.position = rest + Vector2(0, -24)
	_preview.modulate.a = 0.0
	var tp := _preview.create_tween().set_parallel(true)
	tp.tween_property(_preview, "position", rest, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.06)
	tp.tween_property(_preview, "modulate:a", 1.0, 0.22).set_delay(0.06)
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
