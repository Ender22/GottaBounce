extends Control
## Chunky drawn chevron (◀ / ▶) for lobby carousels — cream fill, chocolate rim, soft drop shadow.
## Replaces ASCII "< >" (WK-29 direction). Pure _draw, no art. `dir` -1 = left, +1 = right.

const CHOCO := Color(0.231373, 0.141176, 0.105882)

@export var dir := 1:
	set(v):
		dir = v
		queue_redraw()
@export var fill := Color(1.0, 0.97, 0.92, 1.0):
	set(v):
		fill = v
		queue_redraw()

## Horizontal nudge (8 px for 0.08 s) when this side is pressed (E.10 cycle motion).
func nudge() -> void:
	var rest: float = float(get_meta("rest_x", position.x))
	set_meta("rest_x", rest)
	var t := create_tween()
	t.tween_property(self, "position:x", rest + 8.0 * dir, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:x", rest, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var s := size
	var m := 6.0
	var pts: PackedVector2Array
	if dir < 0:
		pts = PackedVector2Array([Vector2(m, s.y * 0.5), Vector2(s.x - m, m), Vector2(s.x - m, s.y - m)])
	else:
		pts = PackedVector2Array([Vector2(s.x - m, s.y * 0.5), Vector2(m, m), Vector2(m, s.y - m)])
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0, 4))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.25))
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, CHOCO, 5.0, true)
