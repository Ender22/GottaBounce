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
##   $DeviceWatch (WK-28b)               child node: in-match DisconnectOverlay + connect / disconnect toasts
##   cursor_shown / cursor_allowed()     WK-39 mouse-cursor policy (CC-2.4 / CC-12.2), see "cursor" below
##   is_repeat(e) / is_synthetic(e)      WK-46 menu auto-repeat (CC-5.3), see "menu repeat" below

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
	get_tree().root.window_input.connect(_menu_note)     # WK-46: once per event (holds / the stick latch accumulate)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# WK-28b: what a hot-plug MEANS on screen (in-match disconnect overlay, connect toasts) lives in DeviceWatch, a
	# child node loaded by path (autoload gotcha: no class refs). Added first so it hears device_lost before any
	# scene does (the lobby's own handler leaves the join registry).
	var watch: Node = load("res://src/ui/DeviceWatch.gd").new()
	watch.name = "DeviceWatch"
	add_child(watch)

func _input(e: InputEvent) -> void:
	_note(e)
	_menu_filter(e)   # WK-46: an autoload's _input runs AFTER every scene node's _input and BEFORE GUI focus navigation

func _process(_dt: float) -> void:
	# live match play: hidden no matter what the mouse does (it can't do anything there)
	if cursor_shown and not cursor_allowed():
		_set_cursor(false)
	_menu_tick()   # WK-46

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

# ---------------------------------------------------------------------------------- menu repeat (WK-46)
## CC-5.3: a held D-pad / left stick / arrow-or-WASD key repeats after Tuning.wk46_repeat_delay, then every
## Tuning.wk46_repeat_rate, on every FOCUS-driven menu (title, mode select, arena select, Options, pause, the disconnect
## overlay). Godot's own focus navigation never repeats a pad, and the keyboard rode the OS key echo (its own delay and
## rate, and it wrapped). How:
##  * Holds are tracked per device from Window.window_input (so a scene's set_input_as_handled can't starve a release).
##    One held direction per device; the newest press wins; releasing that button / key / stick ends it.
##  * A repeat is a COPY of the held press (same class, same device, so the pause-owner gate and the CC-3.3 shared-menu
##    filter judge it exactly like the real press), tagged with meta SYNTH_META = "repeat". The left stick is turned
##    into the action map's D-pad button for that direction (press + release pair) both for its first step and for
##    repeats, and its raw motion is kept away from the focus system while a Control has focus: one step per push
##    (hysteresis lobby_stick_press / lobby_stick_release, dominant axis on diagonals), never a burst of steps.
##  * Auto-repeat never wraps (Tuning.wk46_repeat_wraps): a repeat whose focus neighbour lies BEHIND the focused
##    control (the wire_col / wire_row wrap link) is turned into a no-op for that one event. Widgets that clamp
##    (sliders, steppers, shelf ends) skip their deny shake on a repeat (is_repeat), so holding at an end is quiet.
##  * Only while a Control holds GUI focus. No focus = live play or the Herd Lobby (its own per-device repeat): nothing
##    is sent and due holds are dropped (a hold never carries across a screen change, CC-5.7).
const SYNTH_META := &"gb_menu_synth"   # "press" (stick first step) | "repeat" | "release" (stick D-pad release)
const REPEAT_DIR_META := &"gb_menu_dir"
var menu_repeat_count := 0     # QA: repeats sent
var menu_repeat_blocked := 0   # QA: repeats that would have wrapped and were held at the end instead
var menu_stick_steps := 0      # QA: stick first-steps sent (one per push)
var _mholds: Dictionary = {}   # device key -> {"dir": Vector2i, "src": "k<code>" | "b<idx>" | "stick", "ev": InputEvent, "pad": int, "t": msec}
var _mstick: Dictionary = {}   # device key -> {"x": float, "y": float, "dir": Vector2i}

## True for a WK-46 auto-repeat event (a held direction, not a fresh press). Screens that clamp / deny use it.
func is_repeat(e: InputEvent) -> bool:
	return e != null and str(e.get_meta(SYNTH_META, "")) == "repeat"

## True for any event WK-46 synthesised (repeat, stick first step, stick release). Screens with their own repeat
## (the Herd Lobby) ignore these.
func is_synthetic(e: InputEvent) -> bool:
	return e != null and e.has_meta(SYNTH_META)

func _menu_focus() -> Control:
	var vp := get_viewport()
	return vp.gui_get_focus_owner() if vp != null else null

## Direction of a press from the action map (ui_* or move_*, like every menu handler). echo = also accept OS echoes.
func _menu_dir(e: InputEvent, echo := false) -> Vector2i:
	if e.is_action_pressed("ui_left", echo) or e.is_action_pressed("move_left", echo):
		return Vector2i(-1, 0)
	if e.is_action_pressed("ui_right", echo) or e.is_action_pressed("move_right", echo):
		return Vector2i(1, 0)
	if e.is_action_pressed("ui_up", echo) or e.is_action_pressed("move_up", echo):
		return Vector2i(0, -1)
	if e.is_action_pressed("ui_down", echo) or e.is_action_pressed("move_down", echo):
		return Vector2i(0, 1)
	return Vector2i.ZERO

func _menu_src(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		return "k%d" % (k.physical_keycode if k.physical_keycode != 0 else k.keycode)
	if e is InputEventJoypadButton:
		return "b%d" % (e as InputEventJoypadButton).button_index
	return ""

func _menu_note(e: InputEvent) -> void:
	if not Tuning.wk46_menu_repeat or is_synthetic(e):
		return
	var key := device_key(e)
	if key == "":
		return
	if e is InputEventJoypadMotion:
		_menu_stick(key, e as InputEventJoypadMotion)
		return
	if e is InputEventKey and (e as InputEventKey).echo:
		return
	var src := _menu_src(e)
	if src == "":
		return
	if e.is_pressed():
		var d := _menu_dir(e)
		if d != Vector2i.ZERO:
			_mholds[key] = {"dir": d, "src": src, "ev": e, "pad": -1,
				"t": Time.get_ticks_msec() + int(Tuning.wk46_repeat_delay * 1000.0)}
	elif _mholds.has(key) and str((_mholds[key] as Dictionary)["src"]) == src:
		_mholds.erase(key)

## Left stick -> one digital direction per push (hysteresis, dominant axis). Same strengths as the lobby / MenuInputGate.
func _menu_stick(key: String, e: InputEventJoypadMotion) -> void:
	var horiz := e.is_action("move_left") or e.is_action("move_right")
	if not horiz and not (e.is_action("move_up") or e.is_action("move_down")):
		return
	var st: Dictionary = _mstick.get(key, {"x": 0.0, "y": 0.0, "dir": Vector2i.ZERO})
	if horiz:
		st["x"] = e.get_action_strength("move_right") - e.get_action_strength("move_left")
	else:
		st["y"] = e.get_action_strength("move_down") - e.get_action_strength("move_up")
	_mstick[key] = st
	var x: float = st["x"]
	var y: float = st["y"]
	var cur: Vector2i = st["dir"]
	if cur != Vector2i.ZERO:
		var v: float = x if cur.x != 0 else y
		var cs: int = cur.x if cur.x != 0 else cur.y
		if absf(v) < Tuning.lobby_stick_release or (v > 0.0) != (cs > 0):
			st["dir"] = Vector2i.ZERO
			cur = Vector2i.ZERO
			if _mholds.has(key) and str((_mholds[key] as Dictionary)["src"]) == "stick":
				_mholds.erase(key)
	if cur == Vector2i.ZERO and maxf(absf(x), absf(y)) >= Tuning.lobby_stick_press:
		var d := Vector2i(1 if x > 0.0 else -1, 0) if absf(x) >= absf(y) else Vector2i(0, 1 if y > 0.0 else -1)
		st["dir"] = d
		_mholds[key] = {"dir": d, "src": "stick", "ev": null, "pad": e.device,
			"t": Time.get_ticks_msec() + int(Tuning.wk46_repeat_delay * 1000.0)}
		if _menu_focus() != null:
			menu_stick_steps += 1
			_send_dpad(e.device, d, "press")

## The action map's joypad button for a ui_* direction, on `pad` (the stick's stand-in press).
func _dpad_event(pad: int, d: Vector2i, pressed: bool) -> InputEventJoypadButton:
	var act := "ui_right" if d.x > 0 else ("ui_left" if d.x < 0 else ("ui_down" if d.y > 0 else "ui_up"))
	for ev in InputMap.action_get_events(act):
		if ev is InputEventJoypadButton:
			var b := (ev as InputEventJoypadButton).duplicate() as InputEventJoypadButton
			b.device = pad
			b.pressed = pressed
			return b
	return null

func _send_dpad(pad: int, d: Vector2i, kind: String) -> void:
	var p := _dpad_event(pad, d, true)
	var r := _dpad_event(pad, d, false)
	if p == null or r == null:
		return
	p.set_meta(SYNTH_META, kind)
	p.set_meta(REPEAT_DIR_META, d)
	r.set_meta(SYNTH_META, "release")
	Input.parse_input_event(p)
	Input.parse_input_event(r)   # never leave a D-pad button "held" in Input's state

func _menu_tick() -> void:
	if _mholds.is_empty():
		return
	var now := Time.get_ticks_msec()
	var focus := _menu_focus()
	var rate := int(Tuning.wk46_repeat_rate * 1000.0)
	for key in _mholds.keys():
		var h: Dictionary = _mholds[key]
		if now < int(h["t"]):
			continue
		if focus == null or not Tuning.wk46_menu_repeat:
			_mholds.erase(key)   # no focus-driven menu (live play / lobby / mid screen change): this hold is done
			continue
		# a hitch never fires a burst of catch-up repeats
		h["t"] = maxi(int(h["t"]) + rate, now + rate / 2)
		menu_repeat_count += 1
		var d: Vector2i = h["dir"]
		if str(h["src"]) == "stick":
			_send_dpad(int(h["pad"]), d, "repeat")
			continue
		var src_ev: InputEvent = h["ev"]
		if src_ev == null:
			continue
		var ev := src_ev.duplicate() as InputEvent
		ev.set_meta(SYNTH_META, "repeat")
		ev.set_meta(REPEAT_DIR_META, d)
		Input.parse_input_event(ev)

## Pre-GUI filter (runs from _input, after every scene node's _input): while a Control has focus, raw left-stick
## motion and OS key echoes on a direction never reach focus navigation (the stand-in presses / repeats above replace
## them), and an auto-repeat that would wrap is held at the end of the list.
func _menu_filter(e: InputEvent) -> void:
	if not Tuning.wk46_menu_repeat:
		return
	var f := _menu_focus()
	if f == null:
		return
	if e is InputEventJoypadMotion:
		if e.is_action("move_left") or e.is_action("move_right") or e.is_action("move_up") or e.is_action("move_down") \
				or e.is_action("ui_left") or e.is_action("ui_right") or e.is_action("ui_up") or e.is_action("ui_down"):
			get_viewport().set_input_as_handled()
		return
	if e is InputEventKey and (e as InputEventKey).echo and _menu_dir(e, true) != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		return
	if is_repeat(e) and not Tuning.wk46_repeat_wraps:
		var d: Vector2i = e.get_meta(REPEAT_DIR_META, Vector2i.ZERO)
		_hold_at_end(f, d)

## If the focus neighbour in `d` lies behind `f` (a wrap link), point that neighbour at `f` itself for this one event
## (Godot treats a self neighbour as "stay": no focus change, no move blip), restored at the end of the frame. The
## focused control's own _gui_input still gets the event first (a slider keeps stepping).
func _hold_at_end(f: Control, d: Vector2i) -> void:
	if d == Vector2i.ZERO:
		return
	var side: Side = SIDE_RIGHT if d.x > 0 else (SIDE_LEFT if d.x < 0 else (SIDE_BOTTOM if d.y > 0 else SIDE_TOP))
	var n: Control = f.find_valid_focus_neighbor(side)
	if n == null or n == f:
		return
	var fc := f.get_global_rect().get_center()
	var nc := n.get_global_rect().get_center()
	var wraps := (d.x > 0 and nc.x < fc.x - 1.0) or (d.x < 0 and nc.x > fc.x + 1.0) \
			or (d.y > 0 and nc.y < fc.y - 1.0) or (d.y < 0 and nc.y > fc.y + 1.0)
	if not wraps:
		return
	var props: Array[StringName] = [&"focus_neighbor_left", &"focus_neighbor_top", &"focus_neighbor_right", &"focus_neighbor_bottom"]
	var prop: StringName = props[side]
	var old: NodePath = f.get(prop)
	f.set(prop, f.get_path_to(f))
	menu_repeat_blocked += 1
	_restore_neighbor.call_deferred(f, prop, old)

func _restore_neighbor(f: Control, prop: StringName, old: NodePath) -> void:
	if is_instance_valid(f):
		f.set(prop, old)
