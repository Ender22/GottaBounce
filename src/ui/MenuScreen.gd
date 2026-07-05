class_name MenuScreen
extends Control
## Base for every shell screen (frontend_ux_spec §1). Owns the shared: focusable registration +
## focus/press juice, footer/header assemble-on-enter, content stagger, back handling, and the ui
## audio. Concrete screens override the small hook methods and wire their own focus-neighbour map.
##
## Focus MOVEMENT itself is Godot's built-in focus system (arrows / D-pad / left-stick all map to the
## ui_* actions): each screen sets focus_neighbour_* for wrap-around. ACTIVATION rides Button.pressed
## (Enter / gamepad-A both fire ui_accept). BACK is menu_back, handled here.

const CHOCO := Color(0.231373, 0.141176, 0.105882)

var shell   # ShellRoot (set via setup); null when a screen is hosted outside the shell (Options in pause)
var _entered := false
var _focusables: Array[Control] = []

func setup(shell_ref) -> void:
	shell = shell_ref

# ------------------------------------------------------------------ hooks (override per screen)
func first_focus() -> Control:
	return null

func stagger_items() -> Array:
	return []

func header_node() -> Control:
	return get_node_or_null("Header")

func footer_node() -> Control:
	return get_node_or_null("Footer")

## Accent (glow/border) colour for a focused control. Screens override for hero/mode/arena colours.
func accent_for(_c: Control) -> Color:
	return MenuFX.ACCENT_PINK

## Called when a registered Button is activated (Enter / A / click). Override per screen.
func activate(_c: Control) -> void:
	pass

## menu_back on this screen. Default = walk back one screen in the shell.
func on_back() -> void:
	if shell != null:
		shell.go_back()

# ------------------------------------------------------------------ focus registration
func register(c: Control, focus_scale := 1.08) -> void:
	if c == null:
		return
	c.focus_mode = Control.FOCUS_ALL
	c.set_meta("focus_scale", focus_scale)
	c.focus_entered.connect(_on_focus_in.bind(c))
	c.focus_exited.connect(_on_focus_out.bind(c))
	c.mouse_entered.connect(_on_hover.bind(c))
	if c is Button:
		(c as Button).pressed.connect(_on_pressed.bind(c))
	_focusables.append(c)

func _on_hover(c: Control) -> void:
	if c.focus_mode != Control.FOCUS_NONE and not c.has_focus():
		c.grab_focus()

func _on_focus_in(c: Control) -> void:
	MenuFX.focus_in(c)
	_recolor_focus(c, accent_for(c))
	if _entered:
		_play_move()

func _on_focus_out(c: Control) -> void:
	MenuFX.focus_out(c)
	_recolor_focus(c, accent_for(c), true)

## Cards carry a "Glow" + "FocusBorder" child painted with the accent; buttons have none (no-op).
func _recolor_focus(c: Control, accent: Color, out := false) -> void:
	var border := c.get_node_or_null("FocusBorder")
	var glow := c.get_node_or_null("Glow")
	if border == null and glow == null:
		return
	if border is Panel:
		var sb := (border as Panel).get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var sb2: StyleBoxFlat = (sb as StyleBoxFlat).duplicate()
			sb2.border_color = accent
			sb2.shadow_color = Color(accent.r, accent.g, accent.b, 0.45)
			(border as Panel).add_theme_stylebox_override("panel", sb2)
		var tb := (border as Panel).create_tween()
		tb.tween_property(border, "modulate:a", 0.0 if out else 1.0, 0.15)
	if glow is Panel:
		var gs := (glow as Panel).get_theme_stylebox("panel")
		if gs is StyleBoxFlat:
			var gs2: StyleBoxFlat = (gs as StyleBoxFlat).duplicate()
			gs2.shadow_color = Color(accent.r, accent.g, accent.b, 0.4)
			(glow as Panel).add_theme_stylebox_override("panel", gs2)
		var tg := (glow as Panel).create_tween()
		tg.tween_property(glow, "modulate:a", 0.0 if out else 1.0, 0.18)

func _on_pressed(c: Control) -> void:
	AudioManager.play_sfx("ui_click")
	MenuFX.press_pop(c)
	activate(c)

func _play_move() -> void:
	# lighter focus-move blip: pitch the click up ~4 semitones, quieter (spec §0 audio)
	AudioManager.play_sfx("ui_click", {"pitch": 1.26, "pitch_var": 0.0, "volume_db": -12.0})

# ------------------------------------------------------------------ enter animation
func enter() -> void:
	var items := stagger_items()
	for i in range(items.size()):
		var it: Control = items[i]
		if not is_instance_valid(it):
			continue
		it.pivot_offset = it.size * 0.5
		it.scale = Vector2(0.6, 0.6)
		it.modulate.a = 0.0
		var t := it.create_tween()
		t.set_parallel(true)
		t.tween_property(it, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.05 * i)
		t.tween_property(it, "modulate:a", 1.0, 0.24).set_delay(0.05 * i)
	var h := header_node()
	if h != null:
		_slide_in(h, Vector2(0, -60))
	var f := footer_node()
	if f != null:
		_slide_in(f, Vector2(0, 60))
	_entered = true
	call_deferred("_grab_first")

func _grab_first() -> void:
	var ff := first_focus()
	if ff != null and is_instance_valid(ff):
		ff.grab_focus()

# ------------------------------------------------------------------ focus-neighbour wiring (wrap)
func wire_col(list: Array) -> void:
	var n := list.size()
	for i in range(n):
		var c: Control = list[i]
		var up: Control = list[(i - 1 + n) % n]
		var dn: Control = list[(i + 1) % n]
		c.focus_neighbor_top = c.get_path_to(up)
		c.focus_neighbor_bottom = c.get_path_to(dn)
		c.focus_previous = c.get_path_to(up)
		c.focus_next = c.get_path_to(dn)

func wire_row(list: Array) -> void:
	var n := list.size()
	for i in range(n):
		var c: Control = list[i]
		var lf: Control = list[(i - 1 + n) % n]
		var rt: Control = list[(i + 1) % n]
		c.focus_neighbor_left = c.get_path_to(lf)
		c.focus_neighbor_right = c.get_path_to(rt)
		c.focus_previous = c.get_path_to(lf)
		c.focus_next = c.get_path_to(rt)

## Grid wiring with horizontal wrap per row and vertical clamp between rows (row-major `list`).
func wire_grid(list: Array, cols: int) -> void:
	var n := list.size()
	if cols <= 0:
		return
	var rows := int(ceil(float(n) / float(cols)))
	for i in range(n):
		var c: Control = list[i]
		var r := i / cols
		var col := i % cols
		var row_start := r * cols
		var row_len: int = mini(cols, n - row_start)
		var lf: Control = list[row_start + (col - 1 + row_len) % row_len]
		var rt: Control = list[row_start + (col + 1) % row_len]
		c.focus_neighbor_left = c.get_path_to(lf)
		c.focus_neighbor_right = c.get_path_to(rt)
		var up_i := ((r - 1 + rows) % rows) * cols + col
		while up_i >= n:
			up_i -= cols
		var dn_i := ((r + 1) % rows) * cols + col
		while dn_i >= n:
			dn_i -= cols
		c.focus_neighbor_top = c.get_path_to(list[up_i])
		c.focus_neighbor_bottom = c.get_path_to(list[dn_i])

func _slide_in(n: Control, from_offset: Vector2) -> void:
	var rest := n.position
	n.position = rest + from_offset
	n.modulate.a = 0.0
	var t := n.create_tween()
	t.set_parallel(true)
	t.tween_property(n, "position", rest, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.04)
	t.tween_property(n, "modulate:a", 1.0, 0.20).set_delay(0.04)

# ------------------------------------------------------------------ back input
func _unhandled_input(e: InputEvent) -> void:
	if not _entered:
		return
	if e.is_action_pressed("menu_back"):
		accept_event()
		AudioManager.play_sfx("ui_click", {"pitch": 0.72, "pitch_var": 0.0, "volume_db": -4.0})
		on_back()
