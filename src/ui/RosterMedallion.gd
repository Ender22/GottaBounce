extends Control
## Herd Lobby roster ribbon medallion (audit §E.9 row 2): one goat in its colour plate. Shows a P-badge
## for every human who has LOCKED (READY) this goat, wiggles when a cycling player skips it because it
## is taken (E.10 "skip a taken goat"). View only — the lobby drives it.

const CHOCO := Color(0.231373, 0.141176, 0.105882)

@onready var _plate: Panel = $Plate
@onready var _art: TextureRect = $Art
@onready var _badges: Array = [$Badges/B1, $Badges/B2, $Badges/B3, $Badges/B4]

var goat_index := 0
var _shown: Array = [false, false, false, false]

func setup(idx: int, color: Color, tex: Texture2D) -> void:
	goat_index = idx
	_art.texture = tex
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = CHOCO
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0.12, 0.07, 0.05, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 4)
	_plate.add_theme_stylebox_override("panel", sb)

## Which P-slots (0-based) have this goat LOCKED. A newly-added badge pops in.
func set_locked_by(slots: Array) -> void:
	var any := false
	for i in range(4):
		var on: bool = slots.has(i)
		var b: Label = _badges[i]
		b.visible = on
		if on:
			any = true
			if not _shown[i]:
				b.pivot_offset = b.custom_minimum_size * 0.5
				b.scale = Vector2(1.6, 1.6)
				var t := b.create_tween()
				t.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_shown[i] = on
	# a locked goat greys slightly so "taken" reads at a glance from the couch
	_art.modulate = Color(0.75, 0.75, 0.75, 1.0) if any else Color.WHITE

func wiggle() -> void:
	MenuFX.reject_shake(self)
