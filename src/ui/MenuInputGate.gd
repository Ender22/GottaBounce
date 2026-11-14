class_name MenuInputGate
extends Node
## Shared end-screen input gate (WK-11 · audit C-14 · COUCH_CONVENTIONS CC-10.2 / CC-3.3 / CC-5.7).
## Replaces "poll Input.is_action_just_pressed from any device" on the end screens (VictoryScreen, the
## Sports/Trials REMATCH rows, the between-stage ScoreScreen skip). Three rules, one place:
##   1. FRESH PRESSES ONLY — a press counts only if it BEGAN after open(). Event-driven (a held button
##      sends no new press event), plus a per-button "down" set: anything held at open() is marked stale
##      and must be seen RELEASED before that button can count again (guards duplicate press events).
##   2. ARM DELAY — verbs are emitted only once `arm_delay` seconds have passed since open(). Presses
##      before that go to `early` (Victory fast-forwards on it) and never act. `delay_arm()` pushes the
##      arm time out (fast-forward lands visuals, then the row still waits — it never arms instantly).
##   3. JOINED DEVICES ONLY — InputRouter.may_drive_shared(e): once a lobby exists, unjoined pads/keyboard
##      are ignored entirely (CC-3.3). Before the first join any device drives (cold boot / QA harness).
## Verbs: "left" "right" "up" "down" (D-pad / arrows / WASD / left stick with hysteresis) · "accept" · "back".
## The gate never consumes events (gameplay is frozen behind every end screen); it only reports them.

signal verb(name: String, key: String)    # armed, fresh, allowed press
signal early(name: String, key: String)   # fresh, allowed press BEFORE arming (never acts on its own)

var _open := false
var _open_msec := 0
var _arm_msec := 0
var _down := {}      # "<device>|<button>" -> true while physically held (tracked even while closed)
var _stale := {}     # buttons held at open(): ignored until released once
var _stick := {}     # "<device>|h|v" -> -1/0/1 latched stick direction (hysteresis)

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().root.window_input.is_connected(_on_window_input):
		return
	# Window.window_input fires for EVERY event before scene propagation (InputRouter uses the same hook),
	# so the held-button bookkeeping can't be starved by another node's set_input_as_handled (PauseMenu's
	# owner gate eats non-owner releases) — a missed release would make that button's next press "dead".
	get_tree().root.window_input.connect(_on_window_input)

func _exit_tree() -> void:
	var root := get_tree().root if get_tree() != null else null
	if root != null and root.window_input.is_connected(_on_window_input):
		root.window_input.disconnect(_on_window_input)

## Start gating: the screen just appeared. `arm_delay` < 0 -> Tuning.end_screen_arm.
func open(arm_delay: float = -1.0) -> void:
	var d: float = Tuning.end_screen_arm if arm_delay < 0.0 else arm_delay
	_open = true
	_open_msec = Time.get_ticks_msec()
	_arm_msec = _open_msec + int(d * 1000.0)
	_stale = _down.duplicate()
	for k in _stick.keys():
		if int(_stick[k]) != 0:
			_stale[k] = true

func close() -> void:
	_open = false

func is_open() -> bool:
	return _open

func is_armed() -> bool:
	return _open and Time.get_ticks_msec() >= _arm_msec

## Seconds since open() (0 when closed).
func elapsed() -> float:
	return float(Time.get_ticks_msec() - _open_msec) / 1000.0 if _open else 0.0

## Push the arm moment to at least `secs` from now (Victory fast-forward: never arms instantly).
func delay_arm(secs: float) -> void:
	_arm_msec = maxi(_arm_msec, Time.get_ticks_msec() + int(secs * 1000.0))

## Arm immediately (QA / tests only).
func force_arm() -> void:
	_arm_msec = Time.get_ticks_msec()

## True if a mouse click on a gated button may act now (mouse has no device filter, CC-2.4).
func mouse_may_act() -> bool:
	return is_armed()

func _on_window_input(e: InputEvent) -> void:
	var key: String = InputRouter.device_key(e)
	if key == "":
		return
	if e is InputEventJoypadMotion:
		_on_stick(key, e as InputEventJoypadMotion)
		return
	if e is InputEventKey and (e as InputEventKey).echo:
		return
	var bid := _button_id(key, e)
	if bid == "":
		return
	if not e.is_pressed():
		_down.erase(bid)
		_stale.erase(bid)
		return
	if _down.has(bid):
		return   # duplicate press event without a release: not a fresh press
	_down[bid] = true
	if not _open or _stale.has(bid):
		return
	if not InputRouter.may_drive_shared(e):
		return   # CC-3.3: an unjoined device can't drive a shared menu once a lobby exists
	var v := _verb_of(e)
	if v != "":
		_emit(v, key)

func _emit(v: String, key: String) -> void:
	if is_armed():
		verb.emit(v, key)
	else:
		early.emit(v, key)

func _button_id(key: String, e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return "%s|k%d" % [key, code]
	if e is InputEventJoypadButton:
		return "%s|b%d" % [key, (e as InputEventJoypadButton).button_index]
	return ""

## Action map -> verb (never raw keycodes). Directions first so a D-pad press is never "accept".
func _verb_of(e: InputEvent) -> String:
	if e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		return "left"
	if e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		return "right"
	if e.is_action_pressed("ui_up") or e.is_action_pressed("move_up"):
		return "up"
	if e.is_action_pressed("ui_down") or e.is_action_pressed("move_down"):
		return "down"
	if e.is_action_pressed("menu_accept") or e.is_action_pressed("ui_accept"):
		return "accept"
	if e.is_action_pressed("menu_back"):
		return "back"
	return ""

## Left stick as a digital direction with the lobby's hysteresis (press >= lobby_stick_press, release
## below lobby_stick_release), per device + axis. A stick held at open() must return to centre first.
func _on_stick(key: String, e: InputEventJoypadMotion) -> void:
	var axis := ""
	var v := 0.0
	if e.is_action("move_left") or e.is_action("move_right"):
		axis = "h"
		v = e.get_action_strength("move_right") - e.get_action_strength("move_left")
	elif e.is_action("move_up") or e.is_action("move_down"):
		axis = "v"
		v = e.get_action_strength("move_down") - e.get_action_strength("move_up")
	else:
		return
	var k := key + "|" + axis
	var cur: int = int(_stick.get(k, 0))
	var a := absf(v)
	var sgn: int = 1 if v > 0.0 else -1
	if cur != 0 and (a < Tuning.lobby_stick_release or sgn != cur):
		_stick[k] = 0
		_stale.erase(k)
		cur = 0
	if cur == 0 and a >= Tuning.lobby_stick_press:
		_stick[k] = sgn
		if not _open or _stale.has(k) or not InputRouter.may_drive_shared(e):
			return
		if axis == "h":
			_emit("right" if sgn > 0 else "left", key)
		else:
			_emit("down" if sgn > 0 else "up", key)
