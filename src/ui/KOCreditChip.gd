extends PanelContainer
## WK-25 KO credit chip — one "+1" / "OOPS!" / "−1" pill (scenes/ui/KOCreditChip.tscn, CreditChip theme variation).
## The pill body takes the identity colour (killer for "+1", victim for "OOPS!" / "−1"); the chocolate outline and
## the white outlined text come from assets/ui/theme.tres. Animated by KOCreditPop.gd; this script only dresses it.

@onready var _label: Label = $Label

## Text + identity colour. Returns the chip's natural size (it is free-positioned, not in a container).
func dress(text: String, color: Color) -> Vector2:
	_label.text = text
	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	sb.bg_color = color
	add_theme_stylebox_override("panel", sb)
	size = get_combined_minimum_size()
	pivot_offset = size * 0.5
	return size
