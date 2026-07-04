extends Control
## Off-screen player edge chevrons (docs/briefs/camera_2x_policy.md §3). The action-cluster camera
## deliberately lets a spread/fleeing player leave the frame to keep combat readable; this overlay
## guarantees no LIVING player ever vanishes without a cue. Any living player outside the visible
## rect (+ inset) gets a chunky, player-colored chevron pinned at the screen edge pointing to them.
## Glossy Toybox styling: bold chocolate outline + glossy highlight, matching the HUD cards.
##
## Code-drawn (dynamic count + rotation) but lives under a CanvasLayer, per the brief. Reads the
## live camera transform so the chevrons track as the frame follows/zooms.

const OUTLINE := Color(0.231373, 0.141176, 0.105882, 1.0)   # theme.tres chocolate
const CHEVRON := 60.0            # arrow length (px), Glossy Toybox chunky
const OUTLINE_W := 5.0

var _match                       # PartyMatch (read-only): players, _camera, state, colors
var _colors: Array = []

func setup(match_ref, colors: Array) -> void:
	_match = match_ref
	_colors = colors
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _match == null or not is_instance_valid(_match):
		return
	if _match.state != "COMBAT" and _match.state != "SUDDEN_DEATH":
		return
	var cam = _match._camera
	if cam == null or not is_instance_valid(cam):
		return
	var vp := get_viewport_rect().size
	var cam_center: Vector2 = cam.get_screen_center_position()
	var z: float = cam.zoom.x
	var inset: float = PartyMatch.CAM_OFFSCREEN_INSET
	var frame := Rect2(Vector2(inset, inset), vp - Vector2(inset * 2.0, inset * 2.0))
	var players: Array = _match.players
	for i in range(players.size()):
		var p = players[i]
		if not is_instance_valid(p) or p.is_dead():
			continue
		var sp: Vector2 = (p.global_position - cam_center) * z + vp * 0.5
		if frame.has_point(sp):
			continue   # on-screen — no chevron needed
		var edge: Vector2 = sp.clamp(frame.position, frame.end)
		var dir: Vector2 = sp - edge
		if dir.length() < 0.001:
			dir = sp - vp * 0.5
		if dir.length() < 0.001:
			dir = Vector2.RIGHT
		var col: Color = _colors[i] if i < _colors.size() else Color.WHITE
		_draw_chevron(edge, dir.normalized(), col)

## A rounded, glossy arrowhead pointing along `dir`, filled `col` with a thick chocolate outline.
func _draw_chevron(at: Vector2, dir: Vector2, col: Color) -> void:
	var s := CHEVRON
	# local arrow (tip toward +x): tip, upper wing, inner notch, lower wing
	var local := PackedVector2Array([
		Vector2(s * 0.55, 0.0),
		Vector2(-s * 0.40, -s * 0.48),
		Vector2(-s * 0.12, 0.0),
		Vector2(-s * 0.40, s * 0.48),
	])
	var tf := Transform2D(dir.angle(), at)
	var pts := PackedVector2Array()
	for pt in local:
		pts.append(tf * pt)
	draw_colored_polygon(pts, col)
	# glossy top highlight (upper half, additive-ish light tint)
	var hi := PackedVector2Array([pts[0], pts[1], pts[2]])
	draw_colored_polygon(hi, Color(1.0, 1.0, 1.0, 0.22))
	# bold chocolate outline
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, OUTLINE, OUTLINE_W, true)
