extends Node
## InputRouter autoload (WK-03 · audit 2026-11-14_controls_frontend §E.8 · COUCH_CONVENTIONS CC-3.x).
## The ONE place that answers "which physical device sent this?" and "which devices are in the game?".
##
## DEVICE KEYS (CC-3.2): "kb" for the keyboard, "pad:<id>" for a joypad, worked out from the EVENT CLASS.
## Godot reports keyboard events as device 0 — the same number as joypad 0 — so the device number alone
## cannot tell them apart. Mouse events have NO key ("") so they never own / join / get gated.
##
## EVENTS SEEN, NEVER ENUMERATION (CC-3.1): nothing here reads Input.get_connected_joypads(). That list
## includes Steam Input / DS4Windows virtual + phantom devices (wrong order, dead P2), and gbplay's
## simulated pads (Input.parse_input_event) never appear in it at all. A device exists for us once it has
## SENT something.
##
## NOTE (CLAUDE.md autoload gotcha): no class_name — an autoload may not share its name with a global
## class. Registered in project.godot by path; every other script reaches it as the `InputRouter` global.
##
## API for the Herd Lobby (WK-05..07) and later items:
##   device_key(e) -> String            "kb" | "pad:N" | ""  (mouse/other)
##   last_device_key / last_device_kind  most recent ACTIVE device ("kb"/"pad:N", "kb"/"pad"); mouse
##                                       buttons count as "kb" here (a mouse user is a keyboard user)
##   seen_devices() -> PackedStringArray every device that has sent input, first-seen order
##   joined (key -> slot int), join(key, slot), leave(key), clear_joined(), is_joined(key), slot_of(key),
##   key_for_slot(slot), has_lobby(), may_drive_shared(e)   — the join registry. The lobby is the writer;
##                                       it also writes MatchConfig.human_devices / human_labels on proceed.
##   signals device_lost(key) / device_found(key) (from Input.joy_connection_changed), last_device_changed,
##   joined_changed
##   rumble(key, weak, strong, dur)      vibrate exactly one device (no-op for "kb" / ""; WK-44: off when Options RUMBLE is off)
##   rumble_player(player, ...)          WK-44: vibrate the device driving that human Player (bots: no-op)
##   simulate_device_lost(key) / simulate_device_found(key)   QA hooks — same code path as a real unplug
##   cursor_shown / cursor_allowed()     WK-39 mouse-cursor policy (CC-2.4 / CC-12.2), see "cursor" below

signal device_lost(key: String)
signal device_found(key: String)
signal last_device_changed(key: String)
signal joined_changed()
signal cursor_changed(shown: bool)   # WK-39

const KB := "kb"
const PAD_PREFIX := "pad:"

var last_device_key: String = ""     # "" until the first keyboard / pad input
var last_device_kind: String = ""    # "kb" | "pad" | ""
var joined: Dictionary = {}          # device key -> slot index (0 = P1). Written by the lobby (WK-05+).

# QA feeds (eval-readable): counters + small logs. Cheap, always on.
var lost_count := 0
var found_count := 0
var rumble_log: Array = []           # [{key, weak, strong, dur, msec}] newest last, capped at RUMBLE_LOG_MAX
var rumble_suppressed := 0           # WK-44: rumble() calls dropped because Options RUMBLE is OFF
const RUMBLE_LOG_MAX := 32

var _seen: PackedStringArray = PackedStringArray()   # first-seen order; a lost pad leaves, re-added on input

## WK-39 (CC-2.4 / CC-12.2, audit C-26): the OS cursor is hidden by any keyboard / pad input, comes back only on
## real mouse motion (> Tuning.cursor_show_motion px), and is ALWAYS hidden during live match play (any match
## state but MATCH_END, while the tree is not paused). MenuScreen / PauseMenu hover-to-focus only acts while it
## is shown, so a resting cursor under a sliding-in screen can't steal the pad's default focus.
var cursor_shown := true
var _motion_acc := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep tracking while the tree is paused (PauseMenu)
	# Window.window_input fires for EVERY event before scene propagation, so tracking is immune to any
	# node's set_input_as_handled() (PauseMenu's owner gate eats non-owner events in _input). _input below
	# is a belt-and-braces duplicate; _note() is idempotent.
	get_tree().root.window_input.connect(_note)
	get_tree().root.window_input.connect(_cursor_note)   # WK-39: once per event (NOT also from _input — motion accumulates)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _input(e: InputEvent) -> void:
	_note(e)

func _process(_dt: float) -> void:
	# live match play: hidden no matter what the mouse does (it can't do anything there)
	if cursor_shown and not cursor_allowed():
		_set_cursor(false)

# ---------------------------------------------------------------------------------------------- cursor

## False during live match play (a PartyMatch scene in any state but MATCH_END, tree not paused). Menus, the
## pause menu and the end screens allow the cursor. Duck-typed (no class refs from an autoload — CLAUDE.md).
func cursor_allowed() -> bool:
	if get_tree().paused:
		return true
	var sc := get_tree().current_scene
	if sc == null or not sc.has_method("set_match_overlays_hidden"):
		return true
	var st: String = str(sc.get("state"))
	return st == "MATCH_END"

func _set_cursor(on: bool) -> void:
	_motion_acc = 0.0
	if on == cursor_shown and Input.mouse_mode == (Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_HIDDEN):
		return
	var changed := on != cursor_shown
	cursor_shown = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_HIDDEN
	if changed:
		cursor_changed.emit(on)

func _cursor_note(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		if cursor_shown:
			return
		_motion_acc += (e as InputEventMouseMotion).relative.length()
		if _motion_acc > Tuning.cursor_show_motion and cursor_allowed():
			_set_cursor(true)
	elif e is InputEventMouseButton:
		if e.is_pressed() and not cursor_shown and cursor_allowed():
			_set_cursor(true)
	elif e is InputEventKey or e is InputEventJoypadButton:
		if e.is_pressed() and cursor_shown:
			_set_cursor(false)
	elif e is InputEventJoypadMotion:
		if cursor_shown and absf((e as InputEventJoypadMotion).axis_value) >= Tuning.input_activity_axis:
			_set_cursor(false)

# ---------------------------------------------------------------------------------------------- keys

## Device identity of an event, from its CLASS (CC-3.2). "" for mouse / touch / actions / anything else.
func device_key(e: InputEvent) -> String:
	if e is InputEventKey:
		return KB
	if e is InputEventJoypadButton or e is InputEventJoypadMotion:
		return PAD_PREFIX + str(e.device)
	return ""

static func kind_of(key: String) -> String:
	if key == KB:
		return "kb"
	if key.begins_with(PAD_PREFIX):
		return "pad"
	return ""

static func is_pad(key: String) -> bool:
	return key.begins_with(PAD_PREFIX) and key.substr(PAD_PREFIX.length()).is_valid_int()

## Joypad device id of a "pad:N" key, -1 for anything else.
static func pad_id(key: String) -> int:
	if not is_pad(key):
		return -1
	return key.substr(PAD_PREFIX.length()).to_int()

static func pad_key(id: int) -> String:
	return PAD_PREFIX + str(id)

## Devices that have sent input since boot (lost pads drop out until they send again), first-seen order.
func seen_devices() -> PackedStringArray:
	return _seen.duplicate()

# --------------------------------------------------------------------------------------- tracking

func _note(e: InputEvent) -> void:
	var key := device_key(e)
	if key == "":
		if e is InputEventMouseButton and e.is_pressed():
			key = KB   # activity only: a clicking player is a keyboard+mouse player (glyphs, auto-join)
		else:
			return
	elif e is InputEventJoypadMotion:
		var axis_v: float = (e as InputEventJoypadMotion).axis_value
		if absf(axis_v) < Tuning.input_activity_axis:
			return   # resting-stick drift is not "using this pad"
	elif not e.is_pressed():
		return   # key / button releases don't announce a device (and can arrive after a pad is lost)
	if not _seen.has(key):
		_seen.append(key)
	if key != last_device_key:
		last_device_key = key
		last_device_kind = kind_of(key)
		last_device_changed.emit(key)

# ------------------------------------------------------------------------------- join registry

## Register `key` as the device driving lobby slot `slot` (0 = P1). A key holds at most one slot and a
## slot at most one key: any previous holder of either is replaced. Returns false for an empty/mouse key.
func join(key: String, slot: int) -> bool:
	if kind_of(key) == "" or slot < 0:
		return false
	for k in joined.keys():
		if int(joined[k]) == slot and str(k) != key:
			joined.erase(k)
	joined[key] = slot
	joined_changed.emit()
	return true

func leave(key: String) -> void:
	if joined.erase(key):
		joined_changed.emit()

func clear_joined() -> void:
	if not joined.is_empty():
		joined.clear()
		joined_changed.emit()

func is_joined(key: String) -> bool:
	return joined.has(key)

## Slot index for a joined device, -1 if not joined.
func slot_of(key: String) -> int:
	return int(joined.get(key, -1))

## Device key holding `slot`, "" if the slot is free.
func key_for_slot(slot: int) -> String:
	for k in joined.keys():
		if int(joined[k]) == slot:
			return str(k)
	return ""

## True once anyone has joined (CC-3.3: from then on, unjoined pads can't drive shared menus).
func has_lobby() -> bool:
	return not joined.is_empty()

## CC-3.3 filter for shared menus (ArenaSelect, end screens — WK-11): before the first join any device
## drives; after it, only joined devices. Mouse / keyless events always pass (CC-2.4 mouse is optional).
func may_drive_shared(e: InputEvent) -> bool:
	if joined.is_empty():
		return true
	var key := device_key(e)
	return key == "" or joined.has(key)

## Interim device plan for N humans when MatchConfig.human_devices is EMPTY (WK-04; until the Herd Lobby
## writes human_devices). Exactly one device per human, never shared, never enumeration: pads that have
## SENT input (first-seen order) first, then the keyboard if it has been used, then guessed pad ids
## ("pad:0", "pad:1", ... not already taken) for anyone left over. Callers only use this for N >= 2.
func default_devices(n: int) -> PackedStringArray:
	var out := PackedStringArray()
	for k in _seen:
		if out.size() < n and is_pad(k):
			out.append(k)
	if out.size() < n and _seen.has(KB):
		out.append(KB)
	var guess := 0
	while out.size() < n:
		var gk := pad_key(guess)
		if not out.has(gk):
			out.append(gk)
		guess += 1
	return out

# ------------------------------------------------------------------------------------ hot-plug

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_emit_found(pad_key(device))
	else:
		_emit_lost(pad_key(device))

func _emit_lost(key: String) -> void:
	var i := _seen.find(key)
	if i >= 0:
		_seen.remove_at(i)
	lost_count += 1
	device_lost.emit(key)

func _emit_found(key: String) -> void:
	# CC-3.5: a newly connected pad does nothing until it presses something, so it is NOT added to
	# _seen here — only announced.
	found_count += 1
	device_found.emit(key)

## QA hook: behave exactly as if `key`'s pad was unplugged (same bookkeeping + signal as a real one).
func simulate_device_lost(key: String) -> void:
	_emit_lost(key)

## QA hook: behave exactly as if `key`'s pad was plugged (back) in.
func simulate_device_found(key: String) -> void:
	_emit_found(key)

# --------------------------------------------------------------------------------------- rumble

## Vibrate exactly one device (CC-3.6). Keyboard / mouse / unknown keys are a no-op. Returns true if a pad
## was told to rumble. WK-44: the Options RUMBLE toggle (Settings.rumble) gates every call here.
func rumble(key: String, weak: float, strong: float, dur: float) -> bool:
	var id := pad_id(key)
	if id < 0:
		return false
	if not Settings.rumble:   # WK-44
		rumble_suppressed += 1
		return false
	Input.start_joy_vibration(id, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), dur)
	rumble_log.append({"key": key, "weak": weak, "strong": strong, "dur": dur, "msec": Time.get_ticks_msec()})
	if rumble_log.size() > RUMBLE_LOG_MAX:
		rumble_log.pop_front()
	return true

## WK-44 (CC-3.6): rumble the device that drives `player` — a human Player whose provider carries a device_key.
## Bots / non-players are a no-op. A legacy any-device human (provider device_key "", cold boot straight into a
## match) rumbles every pad that has sent input. Gated by Settings.rumble through rumble().
func rumble_player(player, weak: float, strong: float, dur: float) -> void:
	if player == null or not is_instance_valid(player) or not ("provider" in player):
		return
	var prov = player.provider
	if prov == null or not ("device_key" in prov):
		return
	var key: String = str(prov.device_key)
	if key == "":
		for k in _seen:
			if is_pad(k):
				rumble(k, weak, strong, dur)
		return
	rumble(key, weak, strong, dur)
