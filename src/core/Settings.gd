extends Node
## Settings autoload (v1_frontend_shell §4). Options persistence to user://settings.cfg (ConfigFile)
## + apply-on-boot to the AudioServer buses and the window mode. No UI here — this is the API the
## Options screen calls later. Changes are write-through (live apply + save; no "apply" button).
##
## Keys: section [audio] master/music/sfx (float 0.0..1.0); section [video] fullscreen (bool).
## Defaults (file absent): volumes 1.0, fullscreen false.
##
## VOLUME MAPPING — deviation from spec §4.3 (reported): §4.3 says db = linear_to_db(v) with the
## premise "100% = 0 dB = unchanged from today". That premise is false for the Music bus, which is
## baked at -8 dB in default_bus_layout.tres. The literal formula would slam Music to 0 dB on boot
## (+8 dB louder than today) — violating the spec's OWN overriding non-negotiable that the default
## boot behave byte-for-byte identically to today. So each bus's designed baseline dB (captured once
## at boot) is the "100%" reference: db = baseline + linear_to_db(v), floored to silence below ~1%.
## For Master/SFX (baseline 0 dB) this is identical to §4.3; only Music (baseline -8 dB) differs, and
## only to PRESERVE today's mix. The linear 0..1 value is what gets stored, per §4.3.

const PATH := "user://settings.cfg"
const SILENCE_DB := -80.0
const BUSES := {"master": "Master", "music": "Music", "sfx": "SFX"}

# --- UNLOCK PROGRESSION (v6_party_gimmicks_circuits.md §4) ---
# Retention layer: circuits unlock as you play. The unlock chain ORDER lives in circuits.json
# (top-level "order") so progression reads DATA, not a hardcoded chain. Trigger = mastery-first with a
# pity fallback: circuit N+1 unlocks when circuit N is WON, OR after UNLOCK_PITY_MATCHES plays of N
# (whichever first). The base (first-in-order) circuit is always unlocked. BRAWL-only; other modes and
# the SINGLE/RANDOM sandbox never gate.
const CIRCUITS_PATH := "res://levels/circuits.json"
const UNLOCK_PITY_MATCHES := 3

# --- SPORTS court unlock (v8_sports_courts.md §4.3) --- Sports courts unlock through the SAME
# [progression] block. A court's "unlock" rule (from sports_courts.json) is one of: "always"; a
# cross-mode "circuit:<id>" (cleared BRAWL circuit -> reuses circuits_cleared); "sports_matches:N";
# or "sports_wins:N" (the marquee chaos-finale gate). Sports counters are Sports-specific so BRAWL
# play never unlocks a Sports court and vice-versa.
const SPORTS_COURTS_PATH := "res://levels/sports_courts.json"
var _sports_court_rules: Dictionary = {}   # cached court_id -> unlock rule string

var master: float = 1.0
var music: float = 1.0
var sfx: float = 1.0
var fullscreen: bool = false

# progression state (persisted in [progression])
var matches_played: int = 0
var matches_won: int = 0
var total_kills: int = 0
var sports_matches: int = 0     # Sports matches finished (any result) — "sports_matches:N" unlock gate
var sports_wins: int = 0        # Sports matches WON by a human — "sports_wins:N" unlock gate
var circuits_cleared: PackedStringArray = PackedStringArray()   # ids of circuits WON (mastery set)
var pending_unlock: String = ""                                 # one id to celebrate next ArenaSelect (consume-once)
var _circuit_plays: Dictionary = {}                             # circuit_id -> matches played on it (pity path)
var _circuit_order: Array = []                                  # cached unlock chain from circuits.json

var _baseline_db: Dictionary = {}   # bus name -> designed baseline dB from the layout (100% reference)

func _ready() -> void:
	_capture_baselines()
	_load()
	_apply_all()

## Snapshot each bus's layout dB BEFORE we ever write to it, so 100% maps to today's mix.
func _capture_baselines() -> void:
	for key in BUSES:
		var bus_name: String = BUSES[key]
		var idx := AudioServer.get_bus_index(bus_name)
		_baseline_db[bus_name] = AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0

# ------------------------------------------------------------------- public API (Options screen)

func set_master(v: float) -> void:
	master = clampf(v, 0.0, 1.0)
	_apply_bus("master")
	_save()

func set_music(v: float) -> void:
	music = clampf(v, 0.0, 1.0)
	_apply_bus("music")
	_save()

func set_sfx(v: float) -> void:
	sfx = clampf(v, 0.0, 1.0)
	_apply_bus("sfx")
	_save()

func set_fullscreen(b: bool) -> void:
	fullscreen = b
	_apply_fullscreen()
	_save()

# ------------------------------------------------------------------- apply

func _apply_all() -> void:
	_apply_bus("master")
	_apply_bus("music")
	_apply_bus("sfx")
	_apply_fullscreen()

func _apply_bus(key: String) -> void:
	var bus_name: String = BUSES[key]
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var v: float = get(key)
	var baseline: float = _baseline_db.get(bus_name, 0.0)
	var db: float = SILENCE_DB if v <= 0.01 else baseline + linear_to_db(v)
	AudioServer.set_bus_volume_db(idx, db)

func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

# ------------------------------------------------------------------- persistence

func _load() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err != OK:
		_save()   # first run — write defaults so the file exists
		return
	master = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	sfx = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	matches_played = int(cfg.get_value("progression", "matches_played", 0))
	matches_won = int(cfg.get_value("progression", "matches_won", 0))
	total_kills = int(cfg.get_value("progression", "total_kills", 0))
	sports_matches = int(cfg.get_value("progression", "sports_matches", 0))
	sports_wins = int(cfg.get_value("progression", "sports_wins", 0))
	circuits_cleared = _split_csv(str(cfg.get_value("progression", "circuits_cleared", "")))
	_circuit_plays = _parse_plays(str(cfg.get_value("progression", "circuit_plays", "")))
	pending_unlock = str(cfg.get_value("progression", "pending_unlock", ""))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("progression", "matches_played", matches_played)
	cfg.set_value("progression", "matches_won", matches_won)
	cfg.set_value("progression", "total_kills", total_kills)
	cfg.set_value("progression", "sports_matches", sports_matches)
	cfg.set_value("progression", "sports_wins", sports_wins)
	cfg.set_value("progression", "circuits_cleared", ",".join(circuits_cleared))
	cfg.set_value("progression", "circuit_plays", _plays_to_str())
	cfg.set_value("progression", "pending_unlock", pending_unlock)
	cfg.save(PATH)

# ------------------------------------------------------------------- progression API (v6 §4)

## Record a finished CIRCUIT match (call at MATCH_END, BRAWL circuit matches only -- v6 §4.2).
## Bumps counters + per-circuit play count; a WIN adds the circuit to the mastery set. If the result
## newly unlocks a circuit, sets `pending_unlock` (the one-shot ArenaSelect celebration). Write-through.
func record_match_result(circuit_id: String, won: bool, kills_this_match: int) -> void:
	var before := _unlocked_set()
	matches_played += 1
	total_kills += maxi(0, kills_this_match)
	if circuit_id != "":
		_circuit_plays[circuit_id] = int(_circuit_plays.get(circuit_id, 0)) + 1
	if won:
		matches_won += 1
		if circuit_id != "" and not circuits_cleared.has(circuit_id):
			circuits_cleared.append(circuit_id)
	# detect a newly-unlocked circuit (diff the derived unlocked-set before vs after)
	for cid in _unlocked_set():
		if not before.has(cid):
			pending_unlock = str(cid)
			break
	_save()

## True if a circuit is playable: the base (first-in-order) is always unlocked; any other is unlocked
## once its PREDECESSOR in the chain is WON (in circuits_cleared) OR played UNLOCK_PITY_MATCHES times.
## A circuit not present in the order chain is treated as ungated (true) -- SINGLE/RANDOM never call this.
func is_circuit_unlocked(circuit_id: String) -> bool:
	var order := _get_circuit_order()
	var idx := order.find(circuit_id)
	if idx <= 0:
		return true   # base circuit (index 0) or not in the chain -> ungated
	var pred := str(order[idx - 1])
	if circuits_cleared.has(pred):
		return true
	return int(_circuit_plays.get(pred, 0)) >= UNLOCK_PITY_MATCHES

## Return + clear the one-shot pending unlock (drives the ArenaSelect celebration). Empty if none.
func take_pending_unlock() -> String:
	var p := pending_unlock
	if p != "":
		pending_unlock = ""
		_save()
	return p

## The circuit that must be cleared/played to unlock `circuit_id` (its predecessor), or "" if none.
func unlock_predecessor(circuit_id: String) -> String:
	var order := _get_circuit_order()
	var idx := order.find(circuit_id)
	if idx <= 0:
		return ""
	return str(order[idx - 1])

## How many more plays of the predecessor until the pity path unlocks `circuit_id` (>=1), or 0.
func pity_matches_remaining(circuit_id: String) -> int:
	var pred := unlock_predecessor(circuit_id)
	if pred == "":
		return 0
	return maxi(0, UNLOCK_PITY_MATCHES - int(_circuit_plays.get(pred, 0)))

# ------------------------------------------------------------------- SPORTS progression (v8 §4.3)

## Record a finished SPORTS match (call at MATCH_END, Sports mode only — PartyMatch._record_sports_
## progression). Bumps the Sports match counter; a HUMAN win also bumps the Sports-wins counter (the
## chaos-finale gate). Write-through. BRAWL/TRIALS/GAUNTLET never call this.
func record_sports_result(human_won: bool) -> void:
	sports_matches += 1
	if human_won:
		sports_wins += 1
	_save()

## True if a Sports court is playable (v8 §4.3). Reads the court's "unlock" rule from
## sports_courts.json: "always" (or absent/unknown court) -> open; "circuit:<id>" -> that BRAWL
## circuit is in circuits_cleared; "sports_matches:N" -> sports_matches >= N; "sports_wins:N" ->
## sports_wins >= N. An unrecognised rule defaults OPEN (never hard-lock in an odd data state).
func is_court_unlocked(court_id: String) -> bool:
	var rule := _court_unlock_rule(court_id)
	if rule == "" or rule == "always":
		return true
	var parts := rule.split(":")
	var kind := str(parts[0])
	var arg := str(parts[1]) if parts.size() > 1 else ""
	match kind:
		"circuit":
			return circuits_cleared.has(arg)
		"sports_matches":
			return sports_matches >= int(arg)
		"sports_wins":
			return sports_wins >= int(arg)
		_:
			return true

## The unlock-rule string for a court id from sports_courts.json (cached), or "" if the file/court is
## absent (treated as always-open by is_court_unlocked).
func _court_unlock_rule(court_id: String) -> String:
	if _sports_court_rules.is_empty() and FileAccess.file_exists(SPORTS_COURTS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPORTS_COURTS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			var courts: Variant = (parsed as Dictionary).get("courts", [])
			if typeof(courts) == TYPE_ARRAY:
				for c in (courts as Array):
					if typeof(c) == TYPE_DICTIONARY:
						var cid := str((c as Dictionary).get("id", ""))
						if cid != "":
							_sports_court_rules[cid] = str((c as Dictionary).get("unlock", "always"))
	return str(_sports_court_rules.get(court_id, ""))

# ------------------------------------------------------------------- progression helpers

## Cached unlock chain from circuits.json top-level "order" (data-driven; no hardcoded chain).
func _get_circuit_order() -> Array:
	if not _circuit_order.is_empty():
		return _circuit_order
	if FileAccess.file_exists(CIRCUITS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CIRCUITS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			var o: Variant = (parsed as Dictionary).get("order", [])
			if typeof(o) == TYPE_ARRAY:
				for c in (o as Array):
					_circuit_order.append(str(c))
	return _circuit_order

## The set of currently-unlocked circuit ids (derived over the order chain), for unlock-diffing.
func _unlocked_set() -> Array:
	var out: Array = []
	for cid in _get_circuit_order():
		if is_circuit_unlocked(str(cid)):
			out.append(str(cid))
	return out

func _split_csv(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part in s.split(",", false):
		var t := str(part).strip_edges()
		if t != "":
			out.append(t)
	return out

## Serialize the per-circuit play counts as "id:count,id:count".
func _plays_to_str() -> String:
	var parts: Array[String] = []
	for k in _circuit_plays.keys():
		parts.append("%s:%d" % [str(k), int(_circuit_plays[k])])
	return ",".join(parts)

func _parse_plays(s: String) -> Dictionary:
	var out: Dictionary = {}
	for part in s.split(",", false):
		var kv := str(part).split(":")
		if kv.size() == 2 and str(kv[0]).strip_edges() != "":
			out[str(kv[0]).strip_edges()] = int(str(kv[1]))
	return out
