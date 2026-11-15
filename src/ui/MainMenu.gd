extends MenuScreen
## MainMenu / title (frontend_ux_spec §2.1). Logo breathe + drop-in over the living backdrop (no
## scrim — the art carries the title), a springy PLAY/OPTIONS/QUIT stack, and a QUIT confirm dialog.

@onready var _logo: TextureRect = $Logo
@onready var _play: Button = $ButtonStack/PlayBtn
@onready var _options: Button = $ButtonStack/OptionsBtn
@onready var _quit: Button = $ButtonStack/QuitBtn
@onready var _dialog: Control = $QuitDialog
@onready var _stay: Button = $QuitDialog/Panel/VBox/StayBtn
@onready var _do_quit: Button = $QuitDialog/Panel/VBox/QuitBtn

var _dialog_open := false

func _ready() -> void:
	register(_play, 1.08)
	register(_options, 1.08)
	register(_quit, 1.08)
	register(_stay, 1.08)
	register(_do_quit, 1.08)
	# vertical wrap PLAY <-> OPTIONS <-> QUIT
	wire_col([_play, _options, _quit])
	wire_col([_stay, _do_quit])
	# WK-14 (CC-5.1 / CC-5.2): the quit dialog is modal — left / right inside it stay put (they used to leak focus to
	# the title buttons behind the scrim, leaving a "focused" button under the dialog)
	for b: Control in [_stay, _do_quit]:
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
	_animate_logo()

func first_focus() -> Control:
	return _play

func stagger_items() -> Array:
	return [_quit, _options, _play]   # bottom-up cascade (§2.1)

func header_node() -> Control:
	return null

func footer_node() -> Control:
	return $Footer

func on_back() -> void:
	if _dialog_open:
		_close_dialog()
	# else: MainMenu back is a no-op (spec §2.1)

func activate(c: Control) -> void:
	if c == _play:
		shell.go_forward("mode")
	elif c == _options:
		shell.go_forward("options")
	elif c == _quit:
		_open_dialog()
	elif c == _stay:
		_close_dialog()
	elif c == _do_quit:
		get_tree().quit()

func _open_dialog() -> void:
	_dialog_open = true
	_set_stack_focusable(false)   # modal: nothing behind the dialog can take focus (keys, pad or hover)
	_dialog.visible = true
	_dialog.modulate.a = 0.0
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.85, 0.85)
	var t := _dialog.create_tween()
	t.set_parallel(true)
	t.tween_property(_dialog, "modulate:a", 1.0, 0.15)
	t.tween_property(_dialog, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	call_deferred("_focus_node", _stay)

func _close_dialog() -> void:
	_dialog_open = false
	_set_stack_focusable(true)
	var t := _dialog.create_tween()
	t.tween_property(_dialog, "modulate:a", 0.0, 0.1)
	t.tween_callback(func() -> void: _dialog.visible = false)
	call_deferred("_focus_node", _quit)

func _set_stack_focusable(on: bool) -> void:
	for b: Control in [_play, _options, _quit]:
		b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE

func _focus_node(n: Control) -> void:
	if is_instance_valid(n):
		n.grab_focus()

func _animate_logo() -> void:
	if _logo.texture == null:
		return
	await get_tree().process_frame
	_logo.pivot_offset = _logo.size * 0.5
	# drop-in
	var rest := _logo.position
	_logo.position = rest + Vector2(0, -40)
	_logo.scale = Vector2(0.6, 0.6)
	var drop := _logo.create_tween()
	drop.set_parallel(true)
	drop.tween_property(_logo, "position", rest, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_property(_logo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.chain().tween_callback(_logo_breathe)

func _logo_breathe() -> void:
	if not is_instance_valid(_logo):
		return
	var tb := _logo.create_tween().set_loops()
	tb.tween_property(_logo, "scale", Vector2(1.03, 1.03), 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tb.tween_property(_logo, "scale", Vector2.ONE, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var trot := _logo.create_tween().set_loops()
	trot.tween_property(_logo, "rotation", deg_to_rad(1.5), 3.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	trot.tween_property(_logo, "rotation", deg_to_rad(-1.5), 3.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
