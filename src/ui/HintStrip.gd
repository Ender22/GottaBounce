extends HBoxContainer
## Footer control-hint strip (frontend_ux_spec §1.4) built from an exported list of "GLYPH|Label" pairs.
## WK-80(b) / CC-1.6: every glyph is drawn by the ONE glyph component (PadGlyph) — Xbox-coloured A/B/X/Y
## circles, the charcoal START/VIEW/LB/RB pills, the stick glyph, and "key:<TEXT>" cream key caps — so the
## footer chips match the ControlsLegend and the Herd Lobby exactly (the old cream text-chip "START" keycap is
## gone). Token rules:
##   "A" "B" "X" "Y" "START" "VIEW" "LB" "RB" "stick" "key:ENTER" ...   one PadGlyph
##   "< >"                                                               the stick glyph (left/right = adjust)
##   "B/START"                                                           several glyphs joined by a "/" (lobby style)
## Pure presentation.

@export var hints: PackedStringArray = PackedStringArray()
@export var green_first := false   # legacy (ArenaSelect "A FIGHT!"): the A glyph is already green
@export var dark_text := false     # chocolate labels with no outline (for strips sitting on a cream plate)
## WK-29 (CC-1.6): "" = draw the specs literally (PauseMenu / Options pass their owner's own device glyphs).
## "menu" / "play" = the specs are PAD glyphs of a SHARED footer: they follow PadGlyph.shared_kind() (key caps
## when only the keyboard is in, pad glyphs otherwise; a mixed couch sees both on every prompt, WK-31)
## and re-skin on join / leave / last-device changes.
@export var device_ctx := ""

var _kind := ""   # WK-29: the shared kind the strip was last built for

func _ready() -> void:
	add_theme_constant_override("separation", 24)
	if device_ctx != "":
		InputRouter.joined_changed.connect(_on_devices)
		InputRouter.last_device_changed.connect(_on_last_device)
	rebuild()

func _on_last_device(_k: String) -> void:
	_on_devices()

func _on_devices() -> void:
	if PadGlyph.shared_kind() != _kind:
		rebuild()

func set_hints(h: PackedStringArray) -> void:
	hints = h
	if is_inside_tree():
		rebuild()

func rebuild() -> void:
	if device_ctx != "":
		_kind = PadGlyph.shared_kind()
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for i in range(hints.size()):
		var parts: PackedStringArray = String(hints[i]).split("|")
		var glyph_spec: String = parts[0] if parts.size() > 0 else "?"
		var label: String = parts[1] if parts.size() > 1 else ""
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 8)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(group)
		var toks: PackedStringArray = _tokens(glyph_spec)
		if device_ctx != "":
			toks = _device_tokens(toks)
		for t in range(toks.size()):
			if t > 0:
				group.add_child(_text_label("/"))
			var g := PadGlyph.new()
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			g.setup(toks[t])
			group.add_child(g)
		if label != "":
			group.add_child(_text_label(label))

## WK-29: map pad glyph ids to the shared device's glyphs. WK-31 (extends WK-157 to every shared footer, CC-1.6): on a
## mixed keyboard + pad couch EVERY prompt shows both twins ("B / ESC BACK"), not only the A / START confirm prompt.
func _device_tokens(toks: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for t in toks:
		for g in PadGlyph.shared_spec(t, device_ctx, true):
			if not out.has(str(g)):
				out.append(str(g))
	return out

## Split a glyph spec into PadGlyph ids ("< >" is the stick; "B/START" is two glyphs).
func _tokens(spec: String) -> PackedStringArray:
	if spec == "< >" or spec == "<>":
		return PackedStringArray(["stick"])
	if spec.begins_with("key:"):
		return PackedStringArray([spec])   # a key cap's text may itself contain "/"
	return spec.split("/", false)

func _text_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.theme_type_variation = &"Hint"
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if dark_text:
		lbl.add_theme_color_override("font_color", MenuFX.CHOCO)
		lbl.add_theme_constant_override("outline_size", 0)
	lbl.text = text
	return lbl
