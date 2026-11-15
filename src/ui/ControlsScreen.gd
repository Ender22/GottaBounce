extends Control
## WK-33 CONTROLS screen (COUCH_CONVENTIONS CC-11.1 / CC-7.1, UX4-01). ONE shared scene, opened from the PauseMenu
## (between RESTART and OPTIONS) and from Options (its top row) — shell-hosted or pause-hosted alike. The host adds it
## as a child, hides its own plate, and frees it on `back_requested` (B / Esc, or the mouse-only BACK chip, CC-5.5).
##
## Shows the FULL move set with the REAL bindings of both devices side by side: a CONTROLLER column and a KEYBOARD
## column, both read from project.godot's InputMap at runtime (joypad button_index -> the Xbox glyph, key event ->
## a key cap), so a rebind can never leave this screen lying, and there is no second hand-written copy of the map.
## A friend on the keyboard and a pad player read the same page; the column of the device that is looking (the
## pause owner's, else the shared/last device) gets the gold header. The descriptions name that device's button
## ("HOLD X TO AIM, RELEASE TO FIRE" / "HOLD K TO AIM, ...").
##
## Look: the Glossy Toybox cream plate (ToyPanel + ToyRibbon header in the host's accent, ToyRow wells, a gold ToyChip
## tips line), text >= 28 px (CC-8.1). Nothing on it is focusable: it is a read-only page; B backs exactly one level
## (CC-5.4) to whatever opened it. Pause ownership (CC-1.5) is inherited: the PauseMenu's _input gate drops other
## devices' events before they reach us.

signal back_requested

const ROW := preload("res://scenes/ui/ControlsRow.tscn")
const ToyKit := preload("res://src/ui/ToyKit.gd")
const ACCENT := Color("#ff5fa8")
const HEAD_IDLE := Color(0.231373, 0.141176, 0.105882, 0.07)   # the ToyRow well tint (inactive column header)
## The full move set in teaching order. `action` = the project.godot action whose bindings the row shows ("move" reads
## the four move_* actions). `{btn}` in a description = the looking device's button for that action. Copy only.
const MOVES := [
	{"action": "move", "verb": "MOVE", "desc": "STEER YOUR FLIGHT, AIM YOUR SUPER"},
	{"action": "boost", "verb": "FLY", "desc": "HOLD {btn} TO FLY  ·  EVERY BOUNCE REFUELS"},
	{"action": "super", "verb": "SUPER-SMASH", "desc": "HOLD {btn} TO AIM, RELEASE TO FIRE"},
	{"action": "use_powerup", "verb": "POWERUP", "desc": "USE THE POWERUP YOU CARRY"},
	{"action": "taunt", "verb": "TAUNT", "desc": "BAAA!"},
	{"action": "pause", "verb": "PAUSE", "desc": "PAUSE THE MATCH"},
]
const MOVE_ACTIONS := ["move_up", "move_left", "move_down", "move_right"]
## Xbox-layout joypad button_index -> PadGlyph id (the COUCH_CONVENTIONS §1.1 table). A display table, not bindings.
const PAD_BUTTONS := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "VIEW", 6: "START", 9: "LB", 10: "RB"}
## OS key names that are too long for a key cap.
const KEY_SHORT := {"ESCAPE": "ESC", "BACKSPACE": "BKSP", "KP ENTER": "NUM ENTER", "SHIFT": "SHIFT", "CTRL": "CTRL"}

@onready var _panel: PanelContainer = $Panel
@onready var _ribbon: PanelContainer = $Panel/VBox/Ribbon
@onready var _back_chip: Button = $Panel/VBox/Ribbon/Row/BackChip
@onready var _back_glyph: PadGlyph = $Panel/VBox/Ribbon/Row/BackChip/Inner/Glyph
@onready var _pad_head: PanelContainer = $Panel/VBox/HeadPad/Head/PadHead
@onready var _kb_head: PanelContainer = $Panel/VBox/HeadPad/Head/KbHead
@onready var _rows_box: VBoxContainer = $Panel/VBox/Rows
@onready var _hints: HBoxContainer = $Panel/VBox/FooterRow/HintBox

var _owner_key := ""        # pause owner's device ("kb" / "pad:N"); "" = shell-hosted (shared / last device)
var _pause_hosted := false
var _accent := ACCENT
var _rows: Array = []       # [{row, spec}]
var _open := false
# QA readouts (eval)
var active_kind := ""       # "pad" / "kb" / "mixed": whose column is highlighted
var bindings := {}          # action -> {"pad": glyph id, "kb": glyph id}

func _ready() -> void:
	for spec in MOVES:
		var row: PanelContainer = ROW.instantiate()
		_rows_box.add_child(row)
		_rows.append({"row": row, "spec": spec})
	_back_chip.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", {"pitch": 0.72, "pitch_var": 0.0, "volume_db": -4.0})
		_close())
	InputRouter.last_device_changed.connect(_on_last_device)   # bound method: auto-disconnects when freed
	InputRouter.joined_changed.connect(_refresh)
	_apply_accent()
	_refresh()

## Host hook. owner_key = the pause owner's device ("" when Options in the shell opened us); accent = the host
## ribbon's colour (the pause owner's goat colour, or the shell pink).
func set_host(owner_key: String, accent: Color, pause_hosted: bool) -> void:
	_owner_key = owner_key
	_pause_hosted = pause_hosted
	_accent = accent
	if is_node_ready():
		_apply_accent()
		_refresh()

## Plate drop-pop (the Options / Pause juice).
func enter() -> void:
	_open = true
	_panel.pivot_offset = _panel.get_combined_minimum_size() * 0.5
	_panel.scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_last_device(_k: String) -> void:
	if _owner_key == "":
		_refresh()

# ------------------------------------------------------------------ bindings (read from the InputMap)

static func _events(action: String) -> Array:
	if not InputMap.has_action(action):
		return []
	return InputMap.action_get_events(action)

## PadGlyph id of the first joypad binding of `action` ("A", "START", ...; "stick" for an axis / the move set).
static func pad_glyph_for(action: String) -> String:
	if action == "move":
		return "stick"
	for e in _events(action):
		if e is InputEventJoypadButton:
			var idx: int = (e as InputEventJoypadButton).button_index
			if PAD_BUTTONS.has(idx):
				return str(PAD_BUTTONS[idx])
	for e in _events(action):
		if e is InputEventJoypadMotion:
			return "stick"
	return ""

## Key-cap text of the first keyboard binding of `action` ("SPACE", "K", "ESC"); the move set joins its four keys
## ("WASD"). Falls back to PadGlyph's gameplay keyboard map when an action has no key event.
static func key_name_for(action: String) -> String:
	if action == "move":
		var s := ""
		for a in MOVE_ACTIONS:
			var k: String = key_name_for(a)
			if k == "" or k.length() > 1:
				return PadGlyph.for_kind("stick", "kb", "play").trim_prefix("key:")
			s += k
		return s
	for e in _events(action):
		if e is InputEventKey:
			var ke := e as InputEventKey
			var code: Key = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
			var n: String = OS.get_keycode_string(code).to_upper()
			return str(KEY_SHORT.get(n, n))
	var pg: String = pad_glyph_for(action)
	var twin: String = PadGlyph.for_kind(pg, "kb", "play")
	return twin.trim_prefix("key:") if twin.begins_with("key:") else ""

## Whose column is highlighted: the pause owner's device, else the shared prompt rule (CC-1.6).
func _kind() -> String:
	if _owner_key != "":
		return "kb" if _owner_key == InputRouter.KB else "pad"
	return PadGlyph.shared_kind()

## Footer / back-chip glyphs: the owner's device when pause-hosted, else the last device used (Options' rule).
func _is_kb() -> bool:
	if _owner_key != "":
		return _owner_key == InputRouter.KB
	return InputRouter.last_device_kind == "kb"

func _refresh() -> void:
	active_kind = _kind()
	bindings.clear()
	var kb_looks: bool = active_kind == "kb"
	for r in _rows:
		var row: PanelContainer = r["row"]
		var spec: Dictionary = r["spec"]
		var action: String = str(spec["action"])
		var pad: String = pad_glyph_for(action)
		var key: String = key_name_for(action)
		bindings[action] = {"pad": pad, "kb": "key:" + key if key != "" else ""}
		(row.get_node("HBox/Verb") as Label).text = str(spec["verb"])
		var btn: String = key if kb_looks else pad
		(row.get_node("HBox/Desc") as Label).text = str(spec["desc"]).replace("{btn}", btn)
		var pg: PadGlyph = row.get_node("HBox/PadCell/Glyph")
		var kg: PadGlyph = row.get_node("HBox/KbCell/Glyph")
		pg.visible = pad != ""
		if pad != "":
			pg.setup(pad)
		kg.visible = key != ""
		if key != "":
			kg.setup("key:" + key)
	ToyKit.fill_panel(_pad_head, ToyKit.GOLD if active_kind != "kb" else HEAD_IDLE)
	ToyKit.fill_panel(_kb_head, ToyKit.GOLD if active_kind != "pad" else HEAD_IDLE)
	var kb: bool = _is_kb()
	_back_glyph.setup("key:ESC" if kb else "B")
	var h: PackedStringArray
	if kb:
		h = PackedStringArray(["key:ESC|Back"])
		if _pause_hosted:
			h.append("key:P|Resume")
	else:
		h = PackedStringArray(["B|Back"])
		if _pause_hosted:
			h.append("START|Resume")
	_hints.call("set_hints", h)

func _apply_accent() -> void:
	ToyKit.fill_panel(_ribbon, _accent)

# ------------------------------------------------------------------ back (CC-5.4: exactly one level)

func _unhandled_input(e: InputEvent) -> void:
	if not _open or e.is_echo():
		return
	if e.is_action_pressed("menu_back"):
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx("ui_click", {"pitch": 0.72, "pitch_var": 0.0, "volume_db": -4.0})
		_close()

func _close() -> void:
	if not _open:
		return
	_open = false
	back_requested.emit()
