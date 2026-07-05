extends Button
## Reusable selectable tile (frontend_ux_spec §1.2 primitive 2) used by ModeSelect / CharacterSelect /
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
@onready var _name: Label = $Content/VBox/NameLabel
@onready var _tag: Label = $Content/VBox/TagLabel
@onready var _ribbon: Control = $Ribbon
@onready var _check: Label = $Check

var accent := Color("#ff5fa8")
var is_soon := false

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

func set_tag_text(t: String) -> void:
	_tag.text = t
	_tag.visible = t != ""

func set_glyph(t: String) -> void:
	_glyph.text = t
	_glyph.visible = t != ""

func set_art(tex: Texture2D) -> void:
	_art.texture = tex
	_art.visible = tex != null
	_glyph.visible = false

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

## COMING-SOON: chocolate ribbon sash + desaturate the inner content (still colored, not greyed dead).
func set_soon(on: bool) -> void:
	is_soon = on
	_ribbon.visible = on
	if on:
		$Content.modulate = Color(0.62, 0.60, 0.58, 1.0)

func show_check(on: bool) -> void:
	_check.visible = on
	if on:
		_check.add_theme_color_override("font_color", accent)
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
