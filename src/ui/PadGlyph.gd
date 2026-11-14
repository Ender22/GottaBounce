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

@export var glyph := ""                    # set in .tscn; "" = wait for setup()
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

func _ready() -> void:
	if _label == null:
		setup(glyph if glyph != "" else _glyph)

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
