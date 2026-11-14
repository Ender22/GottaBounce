extends Control
## WK-37 HUD puff-cooldown ring around the ghost head on a corner card (art brief E13 / R8): the WK-36 fuel-ring
## style — a dark chocolate backing ring + a fill arc clockwise from 12 o'clock. Fill = the ghost's puff progress
## (1 = ready, full + gold-white pop); grey #9AA0A8 while HUSHED (the card also shows "SHH"); dim when the stage cap
## is spent. Hidden in BAA ONLY (no puff). Pure _draw; presentation only.

const CHOCO := Color(0.231373, 0.141176, 0.105882, 0.85)
const HUSH := Color("#9aa0a8")
const WIDTH := 5.0          # >= 4 px (brief R8)

var frac := 0.0
var hushed := false
var spent := false
var color := Color.WHITE

func set_state(f: float, h: bool, s: bool, col: Color) -> void:
	if is_equal_approx(f, frac) and h == hushed and s == spent and col == color:
		return
	frac = clampf(f, 0.0, 1.0)
	hushed = h
	spent = s
	color = col
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r: float = maxf(size.x, size.y) * 0.5 + 6.0
	draw_arc(c, r, 0.0, TAU, 48, CHOCO, WIDTH + 3.0, true)
	if spent:
		return
	var col: Color = HUSH if hushed else (color.lerp(Color.WHITE, 0.35) if frac >= 1.0 else color)
	var f: float = 1.0 if hushed else frac
	if f > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * f, 48, col, WIDTH, true)
