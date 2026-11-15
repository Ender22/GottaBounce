extends MenuScreen
## MainMenu / title (frontend_ux_spec §2.1). Logo breathe + drop-in over the living backdrop (no
## scrim — the art carries the title), a springy PLAY/OPTIONS/QUIT stack, and a QUIT confirm dialog.
##
## WK-140 (UX4-14): the quit dialog is the Glossy Toybox cream plate (ToyPanel filled OPAQUE so PLAY can't ghost through
## the 0.97-alpha plate, gold ToyRibbon header, chocolate scrim) with A/B glyph hints inside the card. STAY keeps the
## default focus (CC-6.1) and goes green when focused; QUIT is the danger button: red label while unfocused, red fill
## while focused (one focused button at a time, CC-5.1). The dialog moves to the front when it opens (MenuScreen.enter
## raises the Footer above it otherwise).

const ToyKit := preload("res://src/ui/ToyKit.gd")   # WK-140

@onready var _logo: TextureRect = $Logo
@onready var _play: Button = $ButtonStack/PlayBtn
@onready var _options: Button = $ButtonStack/OptionsBtn
@onready var _quit: Button = $ButtonStack/QuitBtn
@onready var _dialog: Control = $QuitDialog
@onready var _stay: Button = $QuitDialog/Panel/VBox/StayBtn
@onready var _do_quit: Button = $QuitDialog/Panel/VBox/QuitBtn
@onready var _dialog_panel: PanelContainer = $QuitDialog/Panel   # WK-140

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
	# WK-140: opaque cream plate (nothing behind shows through) + the QUIT danger styling
	ToyKit.fill_panel(_dialog_panel, ToyKit.CREAM)
	_do_quit.focus_entered.connect(_style_quit.bind(true))    # after MenuScreen's own focus swap (registered first)
	_do_quit.focus_exited.connect(_style_quit.bind(false))
	_style_quit(false)
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
	_dialog.move_to_front()       # WK-140: above the Footer (MenuScreen.enter raised it) and the title stack
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

## WK-140: QUIT reads as the danger option. Unfocused: the cream ShellBtn with a red label. Focused: the primary
## (focused) button shape filled red instead of green, white label. Overrides only — MenuScreen's WK-14 swap of the
## theme variation still decides the shape/size.
func _style_quit(focused: bool) -> void:
	for st in ["normal", "hover", "focus", "pressed"]:
		_do_quit.remove_theme_stylebox_override(st)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		_do_quit.remove_theme_color_override(c)
	if not focused:
		for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			_do_quit.add_theme_color_override(c, ToyKit.DANGER.darkened(0.12))
		return
	var base: StyleBox = _do_quit.get_theme_stylebox("hover")
	if base is StyleBoxFlat:
		var sb: StyleBoxFlat = (base as StyleBoxFlat).duplicate()
		sb.bg_color = ToyKit.DANGER
		for st in ["normal", "hover", "focus"]:
			_do_quit.add_theme_stylebox_override(st, sb)
		var pr: StyleBoxFlat = sb.duplicate()
		pr.bg_color = ToyKit.DANGER.darkened(0.12)
		_do_quit.add_theme_stylebox_override("pressed", pr)

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
