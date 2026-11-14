extends CanvasLayer
## PauseMenu overlay (frontend_ux_spec §2.6). Instanced by PartyMatch on the `pause` action (pad Start /
## keyboard Esc, P) during a live match; freezes the sim (get_tree().paused). RESUME / RESTART / OPTIONS /
## QUIT TO MENU. Processes while paused (PROCESS_MODE_ALWAYS). Options is hosted in-place (shell-less)
## and returns here on back.
## Couch rules (COUCH_CONVENTIONS CC-1.5 / CC-7.3): the device that pressed pause OWNS the menu — other
## devices' key/pad events are dropped in _input before focus nav sees them. A confirms the focused item;
## Start (`pause`) or B (`menu_back`) = RESUME. Resuming tells PartyMatch to swallow held gameplay buttons
## until release (C-19), so the resume press never boosts / fires a powerup.

const OPTIONS := preload("res://scenes/ui/Options.tscn")

@onready var _menu: Control = $Menu
@onready var _panel: PanelContainer = $Menu/Panel
@onready var _resume: Button = $Menu/Panel/VBox/ResumeBtn
@onready var _restart: Button = $Menu/Panel/VBox/RestartBtn
@onready var _options_btn: Button = $Menu/Panel/VBox/OptionsBtn
@onready var _quit: Button = $Menu/Panel/VBox/QuitBtn

var match_ref
var _options: Control = null
# Device that opened the pause ("kb" / "pad:N", see PartyMatch._device_key). "" = no owner, any device
# drives the menu (also the fallback if the owner's pad disconnects while paused).
var _owner_key := ""
# Destructive-action confirm (ui_audit_2026-07-10 §1.6#2): first press of RESTART / QUIT TO MENU arms
# the button ("REALLY?"), second press within the window executes; 1.5s or a focus move disarms.
const CONFIRM_WINDOW := 1.5
var _armed: Button = null
var _arm_gen := 0

func setup(m, owner_key: String = "") -> void:
	match_ref = m
	_owner_key = owner_key
	if _owner_key.begins_with("pad:") and not Input.joy_connection_changed.is_connected(_on_joy_changed):
		Input.joy_connection_changed.connect(_on_joy_changed)

## Owner's pad died mid-pause → release ownership so the menu can't become a dead end.
## TODO(C-07): the DisconnectOverlay replaces this fallback.
func _on_joy_changed(device: int, connected: bool) -> void:
	if not connected and _owner_key == "pad:%d" % device:
		_owner_key = ""

## Pause-owner gate (CC-1.5). _input runs before GUI focus navigation, so marking a non-owner event
## handled here stops it moving focus, pressing buttons, or resuming. Mouse events are never gated.
func _input(e: InputEvent) -> void:
	if _owner_key == "":
		return
	var k := ""
	if e is InputEventKey:
		k = "kb"
	elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
		k = "pad:%d" % e.device
	if k != "" and k != _owner_key:
		get_viewport().set_input_as_handled()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in [_resume, _restart, _options_btn, _quit]:
		_reg(b)
	_wire_col([_resume, _restart, _options_btn, _quit])
	# panel drop-pop (same juice as the HUD banners)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.85, 0.85)
	_menu.modulate.a = 0.0
	var t := _panel.create_tween()
	t.set_parallel(true)
	t.tween_property(_menu, "modulate:a", 1.0, 0.15)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	call_deferred("_grab", _resume)

func _reg(b: Button) -> void:
	b.set_meta("focus_scale", 1.08)
	b.focus_entered.connect(func() -> void:
		MenuFX.focus_in(b)
		AudioManager.play_sfx("ui_click", {"pitch": 1.26, "volume_db": -12.0}))
	b.focus_exited.connect(func() -> void:
		MenuFX.focus_out(b)
		if _armed == b:
			_disarm())
	b.mouse_entered.connect(func() -> void:
		if not b.has_focus():
			b.grab_focus())
	b.pressed.connect(_on_pressed.bind(b))

func _grab(b: Control) -> void:
	if is_instance_valid(b):
		b.grab_focus()

func _on_pressed(b: Button) -> void:
	AudioManager.play_sfx("ui_click")
	MenuFX.press_pop(b)
	if b == _resume:
		_do_resume()
	elif b == _restart:
		if _confirmed(b):
			_do_restart()
	elif b == _options_btn:
		_open_options()
	elif b == _quit:
		if _confirmed(b):
			_do_quit()

## Two-press guard for match-ending actions. Returns true only on the confirming (second) press.
func _confirmed(b: Button) -> bool:
	if _armed == b:
		_disarm()
		return true
	_disarm()
	_armed = b
	_arm_gen += 1
	var gen := _arm_gen
	if not b.has_meta("orig_text"):
		b.set_meta("orig_text", b.text)
	b.text = "REALLY?"
	MenuFX.reject_shake(b)
	# SceneTreeTimer with process_always=true ticks while the sim is paused
	get_tree().create_timer(CONFIRM_WINDOW, true).timeout.connect(func() -> void:
		if _arm_gen == gen and _armed == b:
			_disarm())
	return false

func _disarm() -> void:
	if _armed != null and is_instance_valid(_armed) and _armed.has_meta("orig_text"):
		_armed.text = str(_armed.get_meta("orig_text"))
	_armed = null

func _do_resume() -> void:
	get_tree().paused = false
	# C-19: held A/B/Start must not act in gameplay on the first unpaused tick
	if match_ref != null and is_instance_valid(match_ref) and match_ref.has_method("on_pause_resumed"):
		match_ref.on_pause_resumed()
	queue_free()

func _do_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _do_quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/ShellRoot.tscn")

func _open_options() -> void:
	if _options != null:
		return
	_options = OPTIONS.instantiate()
	add_child(_options)
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.process_mode = Node.PROCESS_MODE_ALWAYS
	_options.setup(null)
	_options.back_requested.connect(_close_options)
	_menu.visible = false
	if _options.has_method("enter"):
		_options.enter()

func _close_options() -> void:
	if _options != null:
		_options.queue_free()
		_options = null
	_menu.visible = true
	call_deferred("_grab", _resume)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_echo():
		return
	if _options != null:
		# Options owns B/Esc (back one level, MenuScreen). Start (or P) resumes straight from Options;
		# Esc is on both `pause` and `menu_back`, so it stays "back" here.
		if e.is_action_pressed("pause") and not e.is_action_pressed("menu_back"):
			get_viewport().set_input_as_handled()
			_close_options()
			AudioManager.play_sfx("ui_click", {"pitch": 0.72, "volume_db": -4.0})
			_do_resume()
		return
	if e.is_action_pressed("menu_back") or e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx("ui_click", {"pitch": 0.72, "volume_db": -4.0})
		_do_resume()

func _wire_col(list: Array) -> void:
	var n := list.size()
	for i in range(n):
		var c: Control = list[i]
		var up: Control = list[(i - 1 + n) % n]
		var dn: Control = list[(i + 1) % n]
		c.focus_neighbor_top = c.get_path_to(up)
		c.focus_neighbor_bottom = c.get_path_to(dn)
		c.focus_previous = c.get_path_to(up)
		c.focus_next = c.get_path_to(dn)
