extends HBoxContainer
## Footer control-hint strip (frontend_ux_spec §1.4). Builds cream rounded glyph chips (chocolate
## glyph on the shell's cream button family — ui_audit_2026-07-10 §1.2#2 contrast pass: the old
## translucent-chocolate chips vanished on dark grass at couch distance) each followed by a Hint
## label, from an exported list of "GLYPH|Label" pairs — NOT literal platform glyphs (a real glyph
## set is a Phase-2 nicety). Pure presentation.

const CREAM := Color(1.0, 0.97, 0.92, 0.96)

@export var hints: PackedStringArray = PackedStringArray()
@export var green_first := false   # tint the first chip green (ArenaSelect "(A) FIGHT!")

func _ready() -> void:
	add_theme_constant_override("separation", 24)
	rebuild()

func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	for i in range(hints.size()):
		var parts: PackedStringArray = String(hints[i]).split("|")
		var glyph: String = parts[0] if parts.size() > 0 else "?"
		var label: String = parts[1] if parts.size() > 1 else ""
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 8)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(group)

		var chip := Panel.new()
		var green: bool = green_first and i == 0
		# widen the chip for multi-char glyphs ("< >") so the text never spills the pill
		chip.custom_minimum_size = Vector2(40 + 14 * maxi(0, glyph.length() - 1), 40)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.329412, 0.788235, 0.290196, 0.92) if green else CREAM
		sb.border_color = MenuFX.CHOCO
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(11)
		sb.shadow_color = Color(0.12, 0.07, 0.05, 0.3)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(0, 2)
		chip.add_theme_stylebox_override("panel", sb)
		group.add_child(chip)

		var gl := Label.new()
		gl.set_anchors_preset(Control.PRESET_FULL_RECT)
		gl.anchor_right = 1.0
		gl.anchor_bottom = 1.0
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gl.add_theme_font_size_override("font_size", 22)
		if green:
			gl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			gl.add_theme_color_override("font_outline_color", MenuFX.CHOCO)
			gl.add_theme_constant_override("outline_size", 6)
		else:
			# chocolate glyph on the cream chip — highest-contrast pairing in the palette
			gl.add_theme_color_override("font_color", MenuFX.CHOCO)
			gl.add_theme_constant_override("outline_size", 0)
		gl.text = glyph
		chip.add_child(gl)

		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.theme_type_variation = &"Hint"
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.text = label
		group.add_child(lbl)
