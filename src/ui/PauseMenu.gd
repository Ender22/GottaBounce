extends CanvasLayer
## PauseMenu overlay (frontend_ux_spec §2.6 · COUCH_CONVENTIONS CC-1.5 / CC-6.1 / CC-7.x). Instanced by
## PartyMatch on the `pause` action (pad Start / keyboard Esc, P) during a live match; freezes the sim
## (get_tree().paused). Processes while paused (PROCESS_MODE_ALWAYS).
##
## Look (WK-09, kit-ified in WK-34: ToyPanel / ToyRibbon / ToyDisc / ToyPill / ToyChip / ToyRule theme types — the
## same Toybox panel kit as Options and the ScoreScreen): the lobby's cream plate + chocolate rim, with an OWNER BAND in the pausing player's goat
## colour — their goat portrait in a cream medallion and "PAUSED · P2" — then a context line (mode · arena ·
## target) and compact score chips. Focus = a full style swap to the owner's colour (CC-5.1: RESUME is NOT
## permanently "primary"-styled any more).
##
## Content (CC-7.1): RESUME · RESTART (hold) · CONTROLS · OPTIONS · CHANGE SETUP (hold) · QUIT TO MENU (hold).
## Destructive items are HoldButtons (0.9 s, radial fill in the owner colour, early release drains) — the
## banned double-press "REALLY?" swap is gone (C-18 / R-09).
##
## Couch rules (CC-1.5 / CC-7.3): the device that pressed pause OWNS the menu — other devices' key/pad events
## are dropped in _input before focus nav sees them. A confirms the focused item; Start (`pause`) or B
## (`menu_back`) = RESUME. Resuming tells PartyMatch to swallow held gameplay buttons until release (C-19).
## Options is hosted in-place; backing out of it restores focus to OPTIONS (WK-80a). WK-33: CONTROLS hosts the shared
## ControlsScreen the same way (owner's glyphs + colour; B returns to CONTROLS, Start resumes straight from it).

const OPTIONS := preload("res://scenes/ui/Options.tscn")
const CONTROLS := preload("res://scenes/ui/ControlsScreen.tscn")   # WK-33
const PORTRAIT := "res://assets/ui/portraits/portrait_%s.png"
const NEUTRAL := Color("#ffd23f")   # header colour when the pausing device drives no human

@onready var _root: Control = $Root
@onready var _menu: Control = $Root/Menu
@onready var _panel: PanelContainer = $Root/Menu/Panel
@onready var _band: PanelContainer = $Root/Menu/Panel/VBox/OwnerBand
@onready var _medallion: Control = $Root/Menu/Panel/VBox/OwnerBand/Header/Medallion
@onready var _portrait: TextureRect = $Root/Menu/Panel/VBox/OwnerBand/Header/Medallion/Portrait
@onready var _dot: Label = $Root/Menu/Panel/VBox/OwnerBand/Header/Dot
@onready var _owner_pill: PanelContainer = $Root/Menu/Panel/VBox/OwnerBand/Header/OwnerPill
@onready var _owner_label: Label = $Root/Menu/Panel/VBox/OwnerBand/Header/OwnerPill/OwnerLabel
@onready var _context: Label = $Root/Menu/Panel/VBox/Context
@onready var _scores: HBoxContainer = $Root/Menu/Panel/VBox/Scores
@onready var _chip_tpl: PanelContainer = $Root/Menu/Panel/VBox/Scores/ChipTemplate
@onready var _resume: Button = $Root/Menu/Panel/VBox/Buttons/ResumeBtn
@onready var _restart: HoldButton = $Root/Menu/Panel/VBox/Buttons/RestartBtn
@onready var _controls_btn: Button = $Root/Menu/Panel/VBox/Buttons/ControlsBtn   # WK-33
@onready var _options_btn: Button = $Root/Menu/Panel/VBox/Buttons/OptionsBtn
@onready var _setup_btn: HoldButton = $Root/Menu/Panel/VBox/Buttons/SetupBtn
@onready var _quit: HoldButton = $Root/Menu/Panel/VBox/Buttons/QuitBtn
@onready var _hints: HBoxContainer = $Root/Menu/Panel/VBox/HintBox

var match_ref
var _options: Control = null
var _controls: Control = null   # WK-33: the hosted ControlsScreen (null = closed)
# Device that opened the pause ("kb" / "pad:N", InputRouter.device_key). "" = no owner, any device
# drives the menu (also the fallback if the owner's pad disconnects while paused).
var _owner_key := ""
var _owner_color := NEUTRAL
# QA readouts (eval): who the header says paused, and what fired.
var owner_label := 0                 # P# shown in the header (0 = no owner pill)
var suspended := false               # WK-28b: a DisconnectOverlay is on top (set_suspended)
var _lost_owner_key := ""            # WK-28b: the owner's pad while it is disconnected ("" = owner not lost)
var _focus_before: Control = null    # WK-28b: focus to restore when un-suspended
var last_action := ""                # "resume" / "restart" / "setup" / "quit" / "options" / "controls"

func setup(m, owner_key: String = "") -> void:
	match_ref = m
	_owner_key = owner_key
	if InputRouter.is_pad(_owner_key) and not InputRouter.device_lost.is_connected(_on_device_lost):
		InputRouter.device_lost.connect(_on_device_lost)
	if is_node_ready():
		_apply_owner()
	# WK-34: the paused arena reads as one clean plate — the corner HUD cards and the controls legend hide for the
	# whole pause (the legend's chips used to peek out under the plate's bottom edge). _do_resume restores them;
	# restart / quit / change setup leave the scene, so nothing to restore there.
	if match_ref != null and is_instance_valid(match_ref) and match_ref.has_method("set_match_overlays_hidden"):
		match_ref.set_match_overlays_hidden(true)

## Owner's pad died mid-pause → release ownership so the menu can't become a dead end. Router signal, so
## InputRouter.simulate_device_lost() exercises the same path. WK-28b: DeviceWatch also opens the DisconnectOverlay on
## top (this menu is suspended under it); the header turns neutral "PAUSED" while the owner is gone, and
## on_seat_rebound() hands ownership to whichever device then drives the owner's seat.
func _on_device_lost(key: String) -> void:
	if key == _owner_key:
		_lost_owner_key = key   # WK-28b
		_owner_key = ""
		_apply_owner()

## WK-28b: the DisconnectOverlay gave the lost owner's seat a device again (the same pad, or a take-over).
func on_seat_rebound(old_key: String, new_key: String) -> void:
	if _lost_owner_key == "" or old_key != _lost_owner_key:
		return
	_lost_owner_key = ""
	_owner_key = new_key
	if InputRouter.is_pad(_owner_key) and not InputRouter.device_lost.is_connected(_on_device_lost):
		InputRouter.device_lost.connect(_on_device_lost)
	_apply_owner()

## WK-28b: a DisconnectOverlay sits on top. Suspended = hidden and inert (no owner gate, no resume); un-suspending
## restores the focus it had, so the pauser finds their menu exactly as they left it.
func set_suspended(on: bool) -> void:
	if on == suspended:
		return
	suspended = on
	visible = not on
	if on:
		var f := get_viewport().gui_get_focus_owner()
		_focus_before = f if f != null and is_ancestor_of(f) else null
		if f != null and is_ancestor_of(f):
			f.release_focus()
	else:
		var back: Control = _focus_before if _focus_before != null and is_instance_valid(_focus_before) else _resume
		_focus_before = null
		call_deferred("_grab", back)

## Pause-owner gate (CC-1.5). _input runs before GUI focus navigation, so marking a non-owner event
## handled here stops it moving focus, pressing / holding buttons, or resuming. Mouse is never gated.
func _input(e: InputEvent) -> void:
	if suspended or _owner_key == "":   # WK-28b: the DisconnectOverlay on top decides every event
		return
	var k: String = InputRouter.device_key(e)
	if k != "" and k != _owner_key:
		get_viewport().set_input_as_handled()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var col: Array = [_resume, _restart, _controls_btn, _options_btn, _setup_btn, _quit]
	for b in col:
		_reg(b)
	_wire_col(col)
	_restart.confirmed.connect(_do_restart)
	_setup_btn.confirmed.connect(_do_change_setup)
	_quit.confirmed.connect(_do_quit)
	_apply_owner()
	# panel drop-pop (same juice as the HUD banners)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.85, 0.85)
	_menu.modulate.a = 0.0
	var t := _panel.create_tween()
	t.set_parallel(true)
	t.tween_property(_menu, "modulate:a", 1.0, 0.15)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	call_deferred("_grab", _resume)

# ------------------------------------------------------------------ owner header + context (CC-7.2)

func _apply_owner() -> void:
	var info: Dictionary = {}
	# WK-28b (audit L6): while the owner's pad is disconnected the header is plain "PAUSED", not the P1 fallback
	if match_ref != null and is_instance_valid(match_ref) and match_ref.has_method("pause_owner_info") and not (_owner_key == "" and _lost_owner_key != ""):
		info = match_ref.pause_owner_info(_owner_key)
	owner_label = int(info.get("label", 0))
	_owner_color = info.get("color", NEUTRAL)
	var band_sb: StyleBoxFlat = (_band.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	band_sb.bg_color = _owner_color
	_band.add_theme_stylebox_override("panel", band_sb)
	var has_owner: bool = owner_label > 0
	_dot.visible = has_owner
	_owner_pill.visible = has_owner
	_owner_label.text = "P%d" % owner_label
	_owner_label.add_theme_color_override("font_color", _owner_color)
	var skin := str(info.get("skin", ""))
	var tex_path := PORTRAIT % PlayerIdentity.name_for_skin(skin).to_lower()
	_medallion.visible = has_owner and skin != "" and ResourceLoader.exists(tex_path)
	if _medallion.visible:
		_portrait.texture = load(tex_path)
	for b: Button in [_restart, _setup_btn, _quit]:
		(b as HoldButton).ring_color = _owner_color
	_apply_context()
	_refresh_hints()
	# a button focused before the owner was known gets re-tinted
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f is Button and _is_menu_button(f):
		_style_focus(f as Button, true)

func _apply_context() -> void:
	var ctx: Dictionary = {}
	if match_ref != null and is_instance_valid(match_ref) and match_ref.has_method("pause_context"):
		ctx = match_ref.pause_context()
	_context.text = str(ctx.get("line", ""))
	_context.visible = _context.text != ""
	for c in _scores.get_children():
		if c != _chip_tpl:
			c.queue_free()
	var chips: Array = ctx.get("chips", [])
	for ch in chips:
		var d: Dictionary = ch
		var chip: PanelContainer = _chip_tpl.duplicate()
		chip.visible = true
		_scores.add_child(chip)   # in the tree first: the ToyChip theme style only resolves inside the themed Root
		var sb: StyleBoxFlat = (chip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		sb.bg_color = d.get("color", NEUTRAL)
		chip.add_theme_stylebox_override("panel", sb)
		(chip.get_node("Label") as Label).text = str(d.get("text", ""))
	_scores.visible = not chips.is_empty()

## Hint strip in the OWNER's device glyphs (CC-1.6: a prompt that belongs to one player uses their device).
## A HoldButton in focus turns "Select" into "Hold".
func _refresh_hints() -> void:
	if _hints == null:
		return
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var hold: bool = f is HoldButton and _is_menu_button(f)
	var verb := "Hold to confirm" if hold else "Select"
	var h: PackedStringArray
	if _owner_key == InputRouter.KB:
		h = PackedStringArray(["key:ENTER|" + verb, "key:ESC|Resume"])
	else:
		h = PackedStringArray(["A|" + verb, "B/START|Resume"])
	_hints.call("set_hints", h)

# ------------------------------------------------------------------ focus

func _is_menu_button(c: Control) -> bool:
	return c == _resume or c == _restart or c == _controls_btn or c == _options_btn or c == _setup_btn or c == _quit

func _reg(b: Button) -> void:
	b.set_meta("focus_scale", 1.08)
	b.focus_entered.connect(func() -> void:
		MenuFX.focus_in(b)
		_style_focus(b, true)
		_refresh_hints()
		AudioManager.play_sfx("ui_click", {"pitch": 1.26, "volume_db": -12.0}))
	b.focus_exited.connect(func() -> void:
		MenuFX.focus_out(b)
		_style_focus(b, false))
	b.mouse_entered.connect(func() -> void:
		if InputRouter.cursor_shown and not b.has_focus():   # WK-39: hover focuses only with a shown cursor
			b.grab_focus())
	if not (b is HoldButton):
		b.pressed.connect(_on_pressed.bind(b))

## CC-5.1 focus = full style swap: owner-colour fill, white label with a chocolate outline. Unfocused = the
## cream ShellBtn. (HoldButtons keep their cream cap on the left so the radial fill reads on any colour.)
func _style_focus(b: Button, on: bool) -> void:
	for s in ["normal", "hover", "focus", "pressed"]:
		b.remove_theme_stylebox_override(s)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_outline_color"]:
		b.remove_theme_color_override(c)
	b.remove_theme_constant_override("outline_size")
	if not on:
		return
	var base: StyleBox = b.get_theme_stylebox("hover")
	if base is StyleBoxFlat:
		var sb: StyleBoxFlat = (base as StyleBoxFlat).duplicate()
		sb.bg_color = _owner_color
		for s in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(s, sb)
		var pr: StyleBoxFlat = sb.duplicate()
		pr.bg_color = _owner_color.darkened(0.12)
		b.add_theme_stylebox_override("pressed", pr)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_outline_color", MenuFX.CHOCO)
	b.add_theme_constant_override("outline_size", 12)

func _grab(b: Control) -> void:
	if is_instance_valid(b):
		b.grab_focus()

func _on_pressed(b: Button) -> void:
	AudioManager.play_sfx("ui_click")
	MenuFX.press_pop(b)
	if b == _resume:
		_do_resume()
	elif b == _options_btn:
		_open_options()
	elif b == _controls_btn:
		_open_controls()

# ------------------------------------------------------------------ actions

func _do_resume() -> void:
	last_action = "resume"
	get_tree().paused = false
	if match_ref != null and is_instance_valid(match_ref):
		if match_ref.has_method("set_match_overlays_hidden"):
			match_ref.set_match_overlays_hidden(false)
		# C-19: held A/B/Start must not act in gameplay on the first unpaused tick
		if match_ref.has_method("on_pause_resumed"):
			match_ref.on_pause_resumed()
	queue_free()

func _do_restart() -> void:
	last_action = "restart"
	get_tree().paused = false
	get_tree().reload_current_scene()

## WK-07 / CC-4.7: CHANGE SETUP from Pause lands in the Herd Lobby with the same players, devices and goats
## (nobody READY) — ShellRoot consumes resume_setup exactly like the Victory screen's CHANGE SETUP.
func _do_change_setup() -> void:
	last_action = "setup"
	get_tree().paused = false
	GameConfig.resume_setup = true
	get_tree().change_scene_to_file("res://scenes/ui/ShellRoot.tscn")

func _do_quit() -> void:
	last_action = "quit"
	get_tree().paused = false
	GameConfig.quit_to_modes = true   # WK-144: lands on mode select, lobby cleared
	get_tree().change_scene_to_file("res://scenes/ui/ShellRoot.tscn")

func _open_options() -> void:
	if _options != null:
		return
	last_action = "options"
	_options = OPTIONS.instantiate()
	add_child(_options)
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.process_mode = Node.PROCESS_MODE_ALWAYS
	_options.setup(null)
	if _options.has_method("set_pause_host"):
		# WK-80(c): "START Resume" in its hint bar, owner's glyphs. WK-34: its header ribbon wears the owner colour.
		_options.set_pause_host(_owner_key, _owner_color)
	_options.back_requested.connect(_close_options)
	_menu.visible = false
	# WK-80(f): the HUD corner cards / legend are already hidden for the whole pause (WK-34, setup())
	if _options.has_method("enter"):
		_options.enter()

func _close_options() -> void:
	if _options != null:
		_options.queue_free()
		_options = null
	_menu.visible = true
	call_deferred("_grab", _options_btn)   # WK-80(a): back out of a submenu -> focus the item that opened it

## WK-33: CONTROLS opens the shared ControlsScreen in place (Options' hosting pattern): owner glyphs + colour,
## B (handled by the screen) returns here with focus back on CONTROLS (CC-5.6), Start resumes straight from it.
func _open_controls() -> void:
	if _controls != null:
		return
	last_action = "controls"
	_controls = CONTROLS.instantiate()
	_controls.process_mode = Node.PROCESS_MODE_ALWAYS
	_controls.set_host(_owner_key, _owner_color, true)
	add_child(_controls)
	_controls.back_requested.connect(_close_controls)
	_menu.visible = false
	_controls.enter()

func _close_controls() -> void:
	if _controls != null:
		_controls.queue_free()
		_controls = null
	_menu.visible = true
	call_deferred("_grab", _controls_btn)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_echo() or suspended:   # WK-28b
		return
	if _controls != null:
		# the ControlsScreen owns B/Esc (back one level); Start (or P) resumes straight from it
		if e.is_action_pressed("pause") and not e.is_action_pressed("menu_back"):
			get_viewport().set_input_as_handled()
			_close_controls()
			AudioManager.play_sfx("ui_click", {"pitch": 0.72, "volume_db": -4.0})
			_do_resume()
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
