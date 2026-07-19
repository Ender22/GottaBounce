class_name PadGlyph
extends Control
## Drawn controller-button glyph chip (match_ceremony brief §0). A 44px circle per Xbox color
## convention (A green / B red / X blue / Y yellow), white letter with chocolate outline; the
## stick variant is a cream circle with a chocolate cross. Controller-only: A/B/X/Y + "stick" are
## the only glyphs (no keyboard chip). Pure _draw + one Label — ZERO art files, like NameTag.
## Reused by ControlsLegend (and future prompt rows).

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const CREAM := Color(1.0, 1.0, 1.0, 0.97)
const FACE_COLORS := {
	"A": Color("#54c94a"), "B": Color("#ff4b3a"), "X": Color("#4aa8ff"), "Y": Color("#ffc93f"),
}
const SIZE := 44.0

var _glyph := "A"      # "A"/"B"/"X"/"Y" | "stick"
var _label: Label = null

func setup(glyph: String) -> void:
	_glyph = glyph
	var is_pad_letter: bool = FACE_COLORS.has(_glyph)
	if _label == null:
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_label)
	if is_pad_letter:
		_label.text = _glyph
		_label.add_theme_font_size_override("font_size", 26)
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_color_override("font_outline_color", CHOCO)
		_label.add_theme_constant_override("outline_size", 6)
	else:
		# "stick" (or any non-letter): the cross is drawn in _draw, no label text
		_label.text = ""
	custom_minimum_size = Vector2(SIZE, SIZE)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := SIZE * 0.5 - 2.0
	if FACE_COLORS.has(_glyph):
		draw_circle(c, r, FACE_COLORS[_glyph])
		draw_arc(c, r, 0.0, TAU, 40, CHOCO, 4.0, true)
	else:
		# "stick" (the only non-letter glyph): cream circle with a chocolate ⊕ cross (the "move" read)
		draw_circle(c, r, CREAM)
		draw_arc(c, r, 0.0, TAU, 40, CHOCO, 4.0, true)
		var a := r * 0.52
		draw_line(c - Vector2(a, 0), c + Vector2(a, 0), CHOCO, 5.0)
		draw_line(c - Vector2(0, a), c + Vector2(0, a), CHOCO, 5.0)
