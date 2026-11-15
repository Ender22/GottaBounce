class_name MenuScreen
extends Control
## Base for every shell screen (frontend_ux_spec §1). Owns the shared: focusable registration +
## focus/press juice, footer/header assemble-on-enter, content stagger, back handling, and the ui
## audio. Concrete screens override the small hook methods and wire their own focus-neighbour map.
##
## Focus MOVEMENT itself is Godot's built-in focus system (arrows / WASD / D-pad / left-stick all map to the
## ui_* actions; WASD added in project.godot by WK-151, CC-2.1): each screen sets focus_neighbour_* for wrap-around. ACTIVATION rides Button.pressed
## (Enter / gamepad-A both fire ui_accept). BACK is menu_back, handled here.

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const FocusRow := preload("res://src/ui/FocusRow.gd")   # WK-14: the focused shell button is the only primary one

var shell   # ShellRoot (set via setup); null when a screen is hosted outside the shell (Options in pause)
var _entered := false
var _focusables: Array[Control] = []
## WK-80(a) / CC-5.6: index into _focusables to focus on entry instead of first_focus() — ShellRoot sets it
## when coming BACK to this screen, so B lands on the item the player left from (OPTIONS, the mode card...).
var restore_focus_index := -1

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
	# WK-14 (CC-5.1): plain shell buttons swap to the primary style ONLY while focused (no permanently green PLAY)
	if FocusRow.owns(c):
		c.set_meta("focus_swap", true)
		FocusRow.style(c as Button, c.has_focus())
	c.focus_entered.connect(_on_focus_in.bind(c))
	c.focus_exited.connect(_on_focus_out.bind(c))
	c.mouse_entered.connect(_on_hover.bind(c))
	if not InputRouter.cursor_changed.is_connected(_on_cursor_changed):
		# deferred: the viewport updates its hovered control after the router sees the motion
		InputRouter.cursor_changed.connect(_on_cursor_changed, CONNECT_DEFERRED)   # bound method: auto-disconnects when freed
	if c is Button:
		(c as Button).pressed.connect(_on_pressed.bind(c))
	_focusables.append(c)

func _on_hover(c: Control) -> void:
	# WK-39 (CC-2.4): hover focuses only while the cursor is shown (i.e. after real mouse motion) — a resting,
	# hidden cursor under a sliding-in screen never steals the pad / keyboard default focus
	if not InputRouter.cursor_shown:
		return
	if c.focus_mode != Control.FOCUS_NONE and not c.has_focus():
		c.grab_focus()

## WK-39: the cursor just came back (real mouse motion). If it is already resting on one of our focusables, that one
## takes focus now (mouse_entered fired while the cursor was still hidden and was ignored).
func _on_cursor_changed(shown: bool) -> void:
	if not shown or not is_inside_tree() or not is_visible_in_tree():
		return
	var h: Control = get_viewport().gui_get_hovered_control()
	while h != null and h != self:
		if _focusables.has(h):
			_on_hover(h)
			return
		h = h.get_parent() as Control

func _on_focus_in(c: Control) -> void:
	if c.has_meta("focus_swap"):
		FocusRow.style(c as Button, true)
	MenuFX.focus_in(c)
	_recolor_focus(c, accent_for(c))
	if _entered:
		_play_move()

func _on_focus_out(c: Control) -> void:
	if c.has_meta("focus_swap"):
		FocusRow.style(c as Button, false)
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
	# Header/footer bands are hard no-content zones (ui_audit_2026-07-10 P2): raise the chrome to the
	# top of the draw order so screen content can never occlude the title or the control hints.
	_fit_safe_area()   # WK-83: before the slide-in captures the rest positions
	var h := header_node()
	if h != null:
		h.move_to_front()
		_slide_in(h, Vector2(0, -60))
	var f := footer_node()
	if f != null:
		f.move_to_front()
		_slide_in(f, Vector2(0, 60))
	_entered = true
	call_deferred("_grab_first")

## WK-83 (UX4-04, TV overscan): keep the header chips and the footer hints inside the action-safe band
## (Tuning.tv_safe_margin of the screen height, top and bottom: y 54..1026 at 1080p). Measures what each band
## actually draws (its direct children: chips by rect, text and hint rows by their centred minimum height) and
## nudges the whole Header down / Footer up by the overshoot, so the BACK chip and the title stay aligned. A no-op
## for a screen that already fits (re-entry is idempotent) and for screens without a Header / Footer (Options).
func _fit_safe_area() -> void:
	var m: float = size.y * Tuning.tv_safe_margin
	var h := header_node()
	if h != null and h.visible:
		var top: float = _ink_span(h).x
		if top < m:
			h.offset_top += m - top
			h.offset_bottom += m - top
		_fit_corner_chips(h)   # WK-149
	var f := footer_node()
	if f != null and f.visible:
		var bot: float = _ink_span(f).y
		if bot > size.y - m and bot < size.y + 200.0:
			f.offset_top -= bot - (size.y - m)
			f.offset_bottom -= bot - (size.y - m)

## WK-149 (lobby ux verdict follow-up, TV overscan): the header's CORNER chips (BACK, the mode chip) sit inside the
## action-safe band horizontally too (Tuning.tv_safe_margin_x of the width: x 96..1824 at 1920). Per chip, not the
## whole band: the vertical fit moves the band, but a corner chip only moves sideways. Labels and anything wider
## than half the screen (the centred title) are not corner chips and stay put. Idempotent on re-entry.
func _fit_corner_chips(band: Control) -> void:
	var mx: float = size.x * Tuning.tv_safe_margin_x
	for c in band.get_children():
		var cc := c as Control
		if cc == null or not cc.visible or cc is Label or cc.size.x > size.x * 0.5:
			continue
		var x0: float = band.position.x + cc.position.x
		var d := 0.0
		if x0 < mx:
			d = mx - x0
		elif x0 + cc.size.x > size.x - mx:
			d = (size.x - mx) - (x0 + cc.size.x)
		if d != 0.0:
			cc.offset_left += d
			cc.offset_right += d

## Vertical span (top, bottom) in this screen's space of what `band`'s visible direct children draw.
func _ink_span(band: Control) -> Vector2:
	var top := INF
	var bot := -INF
	for c in band.get_children():
		var cc := c as Control
		if cc == null or not cc.visible:
			continue
		var y0: float = band.position.y + cc.position.y
		var hgt: float = cc.size.y
		if cc is Label or cc is Container:
			# text and hint rows draw their content vertically centred in a taller band. A label's glyphs (caps +
			# outline) are ~0.75 em per line, not its full line box.
			var mh: float = cc.get_combined_minimum_size().y
			if cc is Label:
				var lbl := cc as Label
				var lines: int = maxi(1, lbl.get_line_count())
				mh = lbl.get_theme_font_size("font_size") * 0.75 * lines + lbl.get_theme_constant("outline_size")
			mh = minf(mh, hgt)
			y0 += (hgt - mh) * 0.5
			hgt = mh
		top = minf(top, y0)
		bot = maxf(bot, y0 + hgt)
	return Vector2(top, bot)

## Registration index of the currently focused control (-1 if focus is elsewhere). ShellRoot remembers it.
func focus_index() -> int:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return _focusables.find(f) if f != null else -1

func _grab_first() -> void:
	if restore_focus_index >= 0 and restore_focus_index < _focusables.size():
		var rc: Control = _focusables[restore_focus_index]
		restore_focus_index = -1
		if is_instance_valid(rc) and rc.is_visible_in_tree() and rc.focus_mode != Control.FOCUS_NONE:
			rc.grab_focus()
			return
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
