class_name PadGlyph
extends Control
## Drawn controller-button glyph chip (match_ceremony brief §0). A 44px circle per Xbox color
## convention (A green / B red / X blue / Y yellow), white letter with chocolate outline; the
## stick variant is a cream circle with a chocolate cross; "START" is the Xbox Start/Menu button — a
## charcoal pill with the three-line menu mark (what's printed on the pad). Pure _draw + one Label —
## ZERO art files, like NameTag.
##
## WK-05 additions (Herd Lobby, audit §E.9/E.11 "can be drawn in code"):
##   "LB" / "RB" / "VIEW"   charcoal shoulder/centre pills with the label (VIEW draws the two-window mark)
##   "key:<TEXT>"           cream key cap with chocolate text ("key:ENTER", "key:ESC", "key:Q")
##   "pad" / "kb"           device icons (a controller silhouette / a keyboard) for lobby panel headers
##   ring                   0..1 hold-progress arc drawn around the glyph (hold-B exit ring)
## WK-81/WK-07 additions: "star" (36 px gold flair icon), "check" (green READY tick), "lock" (padlock).
## WK-92: `icon_size` scales the "check" (MenuCard's 150 px lock-in stamp); every other glyph ignores it.
## Set `glyph` in a .tscn (exported) or call setup() from code (ControlsLegend does).
##
## WK-29 (CC-1.6 / CC-1.7): this is THE device-aware glyph component. Every pad glyph has a keyboard twin per
## context (KEYS_MENU for menus, KEYS_PLAY for a live match; both mirror project.godot's action map). Callers ask
## `for_kind(pad_glyph, kind, ctx)` for one player's device, or read `shared_kind()` for a shared prompt (the
## lobby rule from WK-81 generalised: any joined pad -> pad glyphs, only the keyboard joined -> key caps, pads AND
## the keyboard joined -> "mixed", nobody joined -> the last device used). A glyph placed in a .tscn can opt in with
## `device_ctx = "menu"` / `"play"`: it then re-skins itself on join / leave / last-device changes.
## New glyph "arrows": a key cap with left/right triangles (the font has no arrow characters).

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const CREAM := Color(1.0, 1.0, 1.0, 0.97)
const KEYCAP := Color(1.0, 0.97, 0.92, 1.0)
const FACE_COLORS := {
	"A": Color("#54c94a"), "B": Color("#ff4b3a"), "X": Color("#4aa8ff"), "Y": Color("#ffc93f"),
}
const SIZE := 44.0
const PILL_W := 64.0                       # START pill width (height = SIZE)
const PILL_COLOR := Color("#3b3f4a")       # Xbox charcoal for the centre buttons
const RING_COLOR := Color("#ffd23f")
const LETTER_PX := 28                      # WK-18 / CC-8.1 couch floor for every glyph letter / key name
const ARROWS_W := 76.0                     # WK-29 "arrows" key cap width

## WK-29: keyboard twins of the pad glyphs. Menus (CC-2.1 / project.godot menu_* + ui_*): Enter confirms and
## goes, Esc backs, R = Y, Tab = View, Q/E = LB/RB, arrows move focus. Gameplay (CC-2.2 scheme KB-L): WASD move,
## Space boost, K super, L powerup, J taunt, Esc pause. A glyph with no twin (e.g. "check") passes through.
const KEYS_MENU := {"A": "key:ENTER", "B": "key:ESC", "X": "key:F", "Y": "key:R", "START": "key:ENTER",
	"VIEW": "key:TAB", "LB": "key:Q", "RB": "key:E", "stick": "arrows"}
const KEYS_PLAY := {"A": "key:SPACE", "B": "key:L", "X": "key:K", "Y": "key:J", "START": "key:ESC",
	"stick": "key:WASD"}

@export var glyph := ""                    # set in .tscn; "" = wait for setup()
## WK-29: "" = draw `glyph` literally. "menu" / "play" = `glyph` is the PAD glyph of a SHARED prompt; show its
## keyboard twin whenever shared_kind() is "kb" (pads and mixed couches keep the pad glyph).
@export var device_ctx := ""
@export var icon_size := 36.0:             # "check" only: drawn diameter-ish box (36 = READY tick)
	set(v):
		icon_size = maxf(v, 8.0)
		if _label != null:
			setup(_glyph)
@export var ring := 0.0:                   # hold-progress 0..1 (0 = no ring)
	set(v):
		ring = clampf(v, 0.0, 1.0)
		queue_redraw()

var _glyph := "A"      # "A"/"B"/"X"/"Y" | "stick" | "START" | "LB"/"RB"/"VIEW" | "key:TXT" | "pad" | "kb"
var _label: Label = null
var _base := ""        # WK-29: the pad glyph a device-aware instance was authored with

func _ready() -> void:
	if _label == null:
		setup(glyph if glyph != "" else _glyph)
	if device_ctx != "":
		_base = _glyph
		var ir: Node = _router()
		if ir != null:
			ir.connect("joined_changed", _apply_device)
			ir.connect("last_device_changed", _on_last_device)
		_apply_device()

func _on_last_device(_k: String) -> void:
	_apply_device()

## WK-29: re-skin a device-aware glyph for the current shared device kind.
func _apply_device() -> void:
	if device_ctx == "" or _base == "":
		return
	var want: String = for_kind(_base, "kb" if shared_kind() == "kb" else "pad", device_ctx)
	if want != _glyph:
		setup(want)

# ------------------------------------------------------------------ WK-29 device mapping (static)

static func _router() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("InputRouter")
	return null

## The glyph id to draw for pad glyph `g` on a device of `kind` ("kb" / "pad", or a device key "kb" / "pad:N").
## ctx "menu" or "play" picks the keyboard map. Pads (and unknown kinds) get `g` unchanged.
static func for_kind(g: String, kind: String, ctx: String = "menu") -> String:
	if kind != "kb":
		return g
	var m: Dictionary = KEYS_PLAY if ctx == "play" else KEYS_MENU
	return str(m.get(g, g))

## Shared-prompt device kind (CC-1.6 as amended, WK-81's lobby rule): "pad" if only pads are joined, "kb" if only
## the keyboard is, "mixed" if both are, and the last device used ("kb" / "pad") while nobody is joined.
static func shared_kind() -> String:
	var ir: Node = _router()
	if ir == null:
		return "pad"
	var any_pad := false
	var any_kb := false
	for k in (ir.get("joined") as Dictionary).keys():
		if str(k) == "kb":
			any_kb = true
		elif str(k).begins_with("pad:"):
			any_pad = true
	if any_pad and any_kb:
		return "mixed"
	if any_pad:
		return "pad"
	if any_kb:
		return "kb"
	return "kb" if str(ir.get("last_device_kind")) == "kb" else "pad"

## Glyph spec(s) for a SHARED prompt of pad glyph `g`: one id, or "pad/kb" twins joined by "/" when the couch is
## mixed and `both_when_mixed` (CC-1.6: GO / confirm prompts, and the controls legend, teach both).
static func shared_spec(g: String, ctx: String = "menu", both_when_mixed: bool = false) -> Array:
	var k: String = shared_kind()
	if k == "kb":
		return [for_kind(g, "kb", ctx)]
	var twin: String = for_kind(g, "kb", ctx)
	if k == "mixed" and both_when_mixed and twin != g:
		return [g, twin]
	return [g]

func setup(g: String) -> void:
	_glyph = g
	glyph = g
	if _label == null:
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
	_label.remove_theme_color_override("font_outline_color")
	_label.add_theme_constant_override("outline_size", 0)
	var w := SIZE
	if FACE_COLORS.has(_glyph):
		_label.text = _glyph
		_label.add_theme_font_size_override("font_size", LETTER_PX)
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_color_override("font_outline_color", CHOCO)
		_label.add_theme_constant_override("outline_size", 6)
	elif _glyph == "LB" or _glyph == "RB":
		_label.text = _glyph
		_label.add_theme_font_size_override("font_size", LETTER_PX)
		_label.add_theme_color_override("font_color", Color.WHITE)
		w = PILL_W
	elif _glyph == "arrows":
		_label.text = ""
		w = ARROWS_W
	elif _glyph.begins_with("key:"):
		var t := _glyph.substr(4)
		_label.text = t
		_label.add_theme_font_size_override("font_size", LETTER_PX)
		_label.add_theme_color_override("font_color", CHOCO)
		# key cap width from the real text width at 28 px (+ rim/padding), so "ENTER"/"SPACE" never spill
		var tw: float = 14.0 * t.length()
		var f: Font = _label.get_theme_font("font")
		if f != null:
			tw = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_PX).x
		w = maxf(SIZE, ceilf(tw) + 24.0)
	elif _glyph == "START" or _glyph == "VIEW":
		_label.text = ""
		w = PILL_W
	elif _glyph == "pad":
		_label.text = ""
		w = 64.0
	elif _glyph == "kb":
		_label.text = ""
		w = 64.0
	elif _glyph == "star" or _glyph == "check" or _glyph == "lock":
		_label.text = ""
		w = icon_size if _glyph == "check" else 36.0
		custom_minimum_size = Vector2(w, w)
		queue_redraw()
		return
	else:
		# "stick" (or any non-letter): the cross is drawn in _draw, no label text
		_label.text = ""
	custom_minimum_size = Vector2(w, SIZE)
	queue_redraw()

func _pill(rect: Rect2, bg: Color, border: Color, bw: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(int(rect.size.y * 0.5))
	sb.anti_aliasing = true
	draw_style_box(sb, rect)

func _draw() -> void:
	var c := size * 0.5
	var r := SIZE * 0.5 - 2.0
	var w := size.x
	if FACE_COLORS.has(_glyph):
		draw_circle(c, r, FACE_COLORS[_glyph])
		draw_arc(c, r, 0.0, TAU, 40, CHOCO, 4.0, true)
	elif _glyph == "START" or _glyph == "VIEW":
		# charcoal pill + chocolate rim; START = three menu lines, VIEW = two overlapping windows
		_pill(Rect2(c - Vector2(PILL_W * 0.5, SIZE * 0.5) + Vector2(0, 2), Vector2(PILL_W, SIZE - 4)), PILL_COLOR, CHOCO, 4)
		if _glyph == "START":
			var hw := 11.0
			for dy: float in [-7.0, 0.0, 7.0]:
				draw_line(c + Vector2(-hw, dy), c + Vector2(hw, dy), Color.WHITE, 3.5, true)
		else:
			draw_rect(Rect2(c + Vector2(-11, -9), Vector2(15, 12)), Color.WHITE, false, 3.0)
			draw_rect(Rect2(c + Vector2(-4, -3), Vector2(15, 12)), Color.WHITE, false, 3.0)
	elif _glyph == "LB" or _glyph == "RB":
		# shoulder bumper: charcoal pill with a slightly flattened top edge feel (rim + inner gloss)
		_pill(Rect2(c - Vector2(PILL_W * 0.5, SIZE * 0.5) + Vector2(0, 3), Vector2(PILL_W, SIZE - 6)), PILL_COLOR, CHOCO, 4)
		draw_line(c + Vector2(-PILL_W * 0.5 + 12, -SIZE * 0.5 + 9), c + Vector2(PILL_W * 0.5 - 12, -SIZE * 0.5 + 9), Color(1, 1, 1, 0.25), 2.0, true)
	elif _glyph.begins_with("key:"):
		# key cap: cream face on a chocolate base (the 3D "key" read), chocolate rim
		var base := StyleBoxFlat.new()
		base.bg_color = CHOCO
		base.set_corner_radius_all(10)
		draw_style_box(base, Rect2(Vector2(1, 4), Vector2(w - 2, SIZE - 4)))
		var face := StyleBoxFlat.new()
		face.bg_color = KEYCAP
		face.border_color = CHOCO
		face.set_border_width_all(3)
		face.set_corner_radius_all(9)
		draw_style_box(face, Rect2(Vector2(1, 0), Vector2(w - 2, SIZE - 6)))
	elif _glyph == "arrows":
		# WK-29: the arrow keys as one cream key cap with a left and a right triangle
		var base_a := StyleBoxFlat.new()
		base_a.bg_color = CHOCO
		base_a.set_corner_radius_all(10)
		draw_style_box(base_a, Rect2(Vector2(1, 4), Vector2(w - 2, SIZE - 4)))
		var face_a := StyleBoxFlat.new()
		face_a.bg_color = KEYCAP
		face_a.border_color = CHOCO
		face_a.set_border_width_all(3)
		face_a.set_corner_radius_all(9)
		draw_style_box(face_a, Rect2(Vector2(1, 0), Vector2(w - 2, SIZE - 6)))
		var cy: float = (SIZE - 6.0) * 0.5
		var cx: float = w * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 24, cy), Vector2(cx - 8, cy - 10), Vector2(cx - 8, cy + 10)]), CHOCO)
		draw_colored_polygon(PackedVector2Array([Vector2(cx + 24, cy), Vector2(cx + 8, cy - 10), Vector2(cx + 8, cy + 10)]), CHOCO)
	elif _glyph == "pad":
		_draw_pad_icon(c)
	elif _glyph == "kb":
		_draw_kb_icon(c)
	elif _glyph == "star":
		_draw_star(c, 17.0)
	elif _glyph == "check":
		var k: float = icon_size / 36.0
		draw_circle(c, 16.0 * k, FACE_COLORS["A"])
		draw_arc(c, 16.0 * k, 0.0, TAU, 48, CHOCO, 3.0 * k, true)
		draw_polyline(PackedVector2Array([c + Vector2(-8, 0) * k, c + Vector2(-2, 7) * k, c + Vector2(9, -7) * k]),
			Color.WHITE, 4.5 * k, true)
	elif _glyph == "lock":
		draw_arc(c + Vector2(0, -3), 7.0, PI, TAU, 16, CHOCO, 4.0, true)
		draw_line(c + Vector2(-7, -3), c + Vector2(-7, 1), CHOCO, 4.0)
		draw_line(c + Vector2(7, -3), c + Vector2(7, 1), CHOCO, 4.0)
		var body := StyleBoxFlat.new()
		body.bg_color = KEYCAP
		body.border_color = CHOCO
		body.set_border_width_all(3)
		body.set_corner_radius_all(4)
		draw_style_box(body, Rect2(c + Vector2(-11, 0), Vector2(22, 15)))
	else:
		# "stick": cream circle with a chocolate ⊕ cross (the "move" read)
		draw_circle(c, r, CREAM)
		draw_arc(c, r, 0.0, TAU, 40, CHOCO, 4.0, true)
		var a := r * 0.52
		draw_line(c - Vector2(a, 0), c + Vector2(a, 0), CHOCO, 5.0)
		draw_line(c - Vector2(0, a), c + Vector2(0, a), CHOCO, 5.0)
	if ring > 0.0:
		var rr: float = maxf(w, SIZE) * 0.5 + 7.0
		draw_arc(c, rr, 0.0, TAU, 48, Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.55), 10.0, true)
		draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * ring, 48, RING_COLOR, 7.0, true)

## Controller silhouette: chocolate-rimmed cream body with two grips, a D-pad cross and four face dots.
func _draw_pad_icon(c: Vector2) -> void:
	# rounded body approximated with circles + rect (grips hang low)
	draw_circle(c + Vector2(-18, 6), 13.0, CHOCO)
	draw_circle(c + Vector2(18, 6), 13.0, CHOCO)
	draw_rect(Rect2(c + Vector2(-20, -13), Vector2(40, 22)), CHOCO)
	draw_circle(c + Vector2(-18, 6), 10.0, CREAM)
	draw_circle(c + Vector2(18, 6), 10.0, CREAM)
	draw_rect(Rect2(c + Vector2(-18, -10), Vector2(36, 18)), CREAM)
	draw_circle(c + Vector2(-20, -3), 10.0, CREAM)
	draw_circle(c + Vector2(20, -3), 10.0, CREAM)
	# D-pad
	draw_rect(Rect2(c + Vector2(-23, -5), Vector2(11, 4)), CHOCO)
	draw_rect(Rect2(c + Vector2(-19.5, -8.5), Vector2(4, 11)), CHOCO)
	# face buttons (Xbox colours)
	draw_circle(c + Vector2(19, -7), 2.8, FACE_COLORS["Y"])
	draw_circle(c + Vector2(19, 1), 2.8, FACE_COLORS["A"])
	draw_circle(c + Vector2(15, -3), 2.8, FACE_COLORS["X"])
	draw_circle(c + Vector2(23, -3), 2.8, FACE_COLORS["B"])

## Keyboard icon: chocolate-rimmed cream slab with three rows of keys and a space bar.
func _draw_kb_icon(c: Vector2) -> void:
	var slab := StyleBoxFlat.new()
	slab.bg_color = CREAM
	slab.border_color = CHOCO
	slab.set_border_width_all(3)
	slab.set_corner_radius_all(6)
	draw_style_box(slab, Rect2(c + Vector2(-29, -15), Vector2(58, 30)))
	for row in range(2):
		for col in range(6):
			draw_rect(Rect2(c + Vector2(-23 + col * 8, -10 + row * 7), Vector2(5, 4.5)), CHOCO)
	draw_rect(Rect2(c + Vector2(-14, 5), Vector2(28, 4.5)), CHOCO)

## Five-point gold star with a chocolate rim (the FLAIR icon, WK-81 F5).
func _draw_star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var rr: float = r if i % 2 == 0 else r * 0.45
		var a: float = -PI * 0.5 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Color("#ffd23f"))
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, CHOCO, 3.0, true)
