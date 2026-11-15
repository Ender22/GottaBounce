extends Control
## WK-31 (R-06 "labelled fuel"): the jetpack-flame glyph at the left end of a PlayerCard's fuel gauge, so the bar reads
## as FUEL at a glance (it used to be an unlabelled coloured strip). Drawn in code like PadGlyph / NameTag (Glossy
## Toybox: chocolate outline, orange body, yellow core), no art file. The flame is taller than the 16 px gauge row and
## overhangs it on purpose (a tiny icon would vanish at TV distance). `dim` greys it out (empty tank).

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const BODY := Color("#ff8a1f")
const CORE := Color("#ffd23f")
const DIM_BODY := Color("#9a8f86")
const DIM_CORE := Color("#c9c0b8")

var dim := false:
	set(v):
		if v != dim:
			dim = v
			queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

## Teardrop flame: round base of radius r centred at `c`, tip `h` above the base centre, leaning slightly right.
func _flame(c: Vector2, r: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 14
	# the base arc runs from the right shoulder (-20 deg) round the bottom to the left shoulder (200 deg)
	for k in range(steps + 1):
		var a: float = deg_to_rad(-20.0 + 220.0 * float(k) / float(steps))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	# left flank up to the tip, then the right flank back down (quadratic-ish bulge)
	var tip := c + Vector2(r * 0.25, -h)
	var l0: Vector2 = pts[pts.size() - 1]
	var r0: Vector2 = pts[0]
	for k in range(1, 6):
		var t: float = float(k) / 6.0
		var p := l0.lerp(tip, t)
		p.x -= sin(t * PI) * r * 0.22
		pts.append(p)
	pts.append(tip)
	for k in range(5, 0, -1):
		var t: float = float(k) / 6.0
		var p := r0.lerp(tip, t)
		p.x += sin(t * PI) * r * 0.12
		pts.append(p)
	return pts

func _draw() -> void:
	var h_px: float = Tuning.hud_fuel_icon_px
	var r: float = h_px * 0.30
	var c := Vector2(size.x * 0.5, size.y * 0.5 + h_px * 0.5 - r - 1.0)
	var outer := _flame(c, r, h_px - r)
	var ol := PackedVector2Array(outer)
	ol.append(outer[0])
	draw_colored_polygon(outer, DIM_BODY if dim else BODY)
	draw_polyline(ol, CHOCO, 3.0, true)
	var inner := _flame(c + Vector2(0.0, r * 0.12), r * 0.52, (h_px - r) * 0.55)
	draw_colored_polygon(inner, DIM_CORE if dim else CORE)
