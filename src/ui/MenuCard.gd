extends Button
## Reusable selectable tile (frontend_ux_spec §1.2 primitive 2) used by ModeSelect /
## ArenaSelect. A flat Button wearing the MenuCard styleboxes (press + focus for free), with a colored
## key-art plate (gradient), a sprite/art slot, a big name, an optional tagline, a focus glow + accent
## border driven by MenuScreen, an optional "SOON" ribbon, and a lock-in check stamp.
##
## The screen registers this control and paints the accent on focus; the card just exposes setters so a
## screen builds a whole row/grid by instancing this scene per data entry (never Button.new() walls).

@onready var _plate: Panel = $Content/VBox/Plate
@onready var _grad: TextureRect = $Content/VBox/Plate/Grad
@onready var _art: TextureRect = $Content/VBox/Plate/Art
@onready var _glyph: Label = $Content/VBox/Plate/Glyph
@onready var _name: Label = $Content/VBox/NameStrip/Labels/NameLabel
@onready var _tag: Label = $Content/VBox/NameStrip/Labels/TagLabel
@onready var _ribbon: Control = $Ribbon
@onready var _check: Control = $Check   # WK-92(4): PadGlyph "check" drawn at 150 px (the font has no tick)
@onready var _badge: PanelContainer = $Content/VBox/Plate/Badge

# Difficulty-star icons (frontend_ui_audit_2026-07-10 §3.7 — kills the ASCII "*.." row).
# Existence-guarded: missing icons degrade to the plain text suffix, never to ASCII glyphs.
const STAR_FULL := "res://assets/ui/icons/star_full.png"
const STAR_EMPTY := "res://assets/ui/icons/star_empty.png"
const MIN_FONT := 28   # WK-18 / CC-8.1: nothing a player reads drops below 28 px at 1080p

var accent := Color("#ff5fa8")
var is_soon := false
var _star_row: HBoxContainer = null

func set_card(data: Dictionary) -> void:
	accent = data.get("color", accent)
	if data.has("name_variation"):
		_name.theme_type_variation = data["name_variation"]
	set_name_text(str(data.get("name", "")))
	set_tag_text(str(data.get("tag", "")))
	if data.has("glyph"):
		set_glyph(str(data["glyph"]))
	if data.has("art") and data["art"] != null:
		set_art(data["art"])
	set_plate_color(accent)
	if bool(data.get("soon", false)):
		set_soon(true)

func set_name_text(t: String) -> void:
	_name.text = t
	# Auto-shrink long titles (e.g. ROCKETBALL) so they never spill past the card edges. Base size stays
	# for short names. Measured against the CARD width (the label itself grows to its text, so it can't
	# report overflow). Fit on deferred (after first layout) and on any later card resize.
	_name.remove_theme_font_size_override("font_size")
	if not resized.is_connected(_fit_name_font):
		resized.connect(_fit_name_font)
	call_deferred("_fit_name_font")

func _fit_name_font() -> void:
	if not is_instance_valid(_name):
		return
	var base: int = _name.get_theme_font_size("font_size")
	var f: Font = _name.get_theme_font("font")
	if f == null or base <= 0:
		return
	var avail: float = size.x - 44.0   # card interior minus horizontal padding
	if avail <= 1.0:
		return
	# measure at the BASE size (ignore any prior override) so the fit is idempotent across re-layouts
	var w: float = f.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_CENTER, -1, base).x
	if w > avail:
		# floor = the CC-8.1 couch floor (WK-18); NameLabel autowraps, so a name that still doesn't fit at 28
		# takes a second line instead of shrinking below it
		_name.add_theme_font_size_override("font_size", maxi(MIN_FONT, int(floor(base * avail / w))))
	else:
		_name.remove_theme_font_size_override("font_size")

func set_tag_text(t: String) -> void:
	_tag.text = t
	_tag.visible = t != ""

## WK-13: the name strip's CONTENT height (labels + strip padding), ignoring any min height set below. A row of
## cards reads this after layout and pins every strip to the tallest one, so every art plate is the same height
## (the Plate expands into whatever the strip leaves, so a 3-line tagline used to shrink its card's art).
func name_strip_content_height() -> float:
	var strip: PanelContainer = $Content/VBox/NameStrip
	var pad := 0.0
	var sb := strip.get_theme_stylebox("panel")
	if sb != null:
		pad = sb.get_minimum_size().y
	return ($Content/VBox/NameStrip/Labels as Control).get_combined_minimum_size().y + pad

func set_name_strip_min_height(h: float) -> void:
	($Content/VBox/NameStrip as Control).custom_minimum_size.y = h

func set_glyph(t: String) -> void:
	_glyph.text = t
	_glyph.visible = t != ""

func set_art(tex: Texture2D) -> void:
	_art.texture = tex
	_art.visible = tex != null
	_glyph.visible = false

## Difficulty/meta row (§3.3 Shelf-A card line 2): real star icons (filled/hollow out of `total`)
## + a small suffix label ("4 ARENAS"). Replaces the TagLabel line for unlocked circuit cards.
## Rebuilt on each call (cards set it once at build time).
func set_star_row(filled: int, total: int, suffix: String, icon_px := 26) -> void:
	if _star_row != null:
		_star_row.queue_free()
	_star_row = HBoxContainer.new()
	_star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_star_row.add_theme_constant_override("separation", 6)
	$Content/VBox/NameStrip/Labels.add_child(_star_row)
	if ResourceLoader.exists(STAR_FULL) and ResourceLoader.exists(STAR_EMPTY):
		for i in range(total):
			var star := TextureRect.new()
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			star.custom_minimum_size = Vector2(icon_px, icon_px)
			star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star.texture = load(STAR_FULL if i < filled else STAR_EMPTY) as Texture2D
			_star_row.add_child(star)
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.theme_type_variation = &"CardTag"
	lbl.add_theme_font_size_override("font_size", maxi(icon_px, MIN_FONT))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.text = ("  " if total > 0 else "") + suffix
	_star_row.add_child(lbl)

## Optional tier badge chip, top-left of the art plate (§3.8 — SPORTS court select tiers).
## Hidden when unset so existing Brawl/Mode cards are untouched.
func set_badge(text: String, color: Color) -> void:
	_badge.visible = text != ""
	if text == "":
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = MenuFX.CHOCO
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	_badge.add_theme_stylebox_override("panel", sb)
	($Content/VBox/Plate/Badge/BadgeLabel as Label).text = text

## Colored key-art plate — a top-bright -> bottom-dark vertical gradient (never a flat block, §2.2).
func set_plate_color(c: Color) -> void:
	accent = c
	var grad := Gradient.new()
	grad.set_color(0, c.lightened(0.22))
	grad.set_color(1, c.darkened(0.28))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 128
	gt.height = 128
	_grad.texture = gt
	# plate keeps a chocolate outline + rounded corners
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = MenuFX.CHOCO
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	_plate.add_theme_stylebox_override("panel", sb)

## RANDOM tile: a multi-colour rainbow gradient plate so it reads as the fun default, distinct from
## any single arena's themed tile (frontend_ux_spec §2.4). Keeps the chocolate outline + rounded corners.
func set_plate_rainbow() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	grad.colors = PackedColorArray([
		Color("#ff5fa8"), Color("#ff7a2d"), Color("#ffc93f"),
		Color("#54c94a"), Color("#4aa8ff"), Color("#a15fff"),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 128
	gt.height = 128
	_grad.texture = gt
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = MenuFX.CHOCO
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	_plate.add_theme_stylebox_override("panel", sb)

## COMING-SOON: chocolate ribbon sash + desaturate the inner content (still colored, not greyed dead).
func set_soon(on: bool) -> void:
	is_soon = on
	_ribbon.visible = on
	if on:
		$Content.modulate = Color(0.62, 0.60, 0.58, 1.0)

## LOCKED (unlock-progression, v6 §4.3): reuse the SOON ribbon + desaturate treatment but stamp it
## "LOCKED" -- greyed, not selectable (the screen's activate() no-ops on a locked card). Same
## established look as the coming-soon tiles so the locked state reads instantly without new art.
func set_locked(on: bool) -> void:
	is_soon = on   # reuse the ribbon-visible flag path (screens read this to gate activation if desired)
	_ribbon.visible = on
	var lbl := _ribbon.get_node_or_null("Sash/SoonLabel")
	if lbl is Label:
		(lbl as Label).text = "LOCKED" if on else "SOON"
	if on:
		$Content.modulate = Color(0.5, 0.49, 0.55, 1.0)

func show_check(on: bool) -> void:
	_check.visible = on
	if on:
		_check.pivot_offset = _check.size * 0.5
		_check.scale = Vector2.ZERO
		var t := _check.create_tween()
		t.tween_property(_check, "scale", Vector2(1.3, 1.3), 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_check, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A small "notice me" bounce played on the art when this card becomes the hovered pick.
func notice_bounce() -> void:
	if _art.texture == null:
		return
	_art.pivot_offset = _art.size * 0.5
	var t := _art.create_tween()
	t.tween_property(_art, "scale", Vector2(1.12, 0.9), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_art, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
