extends Control
## WK-169c §2.3 SHOWDOWN gold card frame (scenes/ui/ShowdownCardFrame.tscn). PlayerCard instances it LAZILY on the first
## set_showdown_frame(true) (the GhostCardBadge pattern, WK-37 T8), so with the showdown OFF the card's node tree is the pre-169c
## one. It sits OUTSIDE the card (theme variations ShowdownFrame = gold 5 px + soft gold glow, ShowdownFrameKeyline = 2 px chocolate
## keyline outside it) and draws BEHIND the card (show_behind_parent, first child), so the crimson danger border stays inside and the
## HURT!/DANGER! sticker, the stock tab, the +1 chip and the held slot all draw over it. No text, no timer, no step number.
## Motion: pop-in 1.15 -> 1.0 (0.2 s, TRANS_BACK), one border pulse per step, 0.2 s fade-out; the holder's frame plays a diagonal
## white-gold glint sweep every Tuning.showdown_frame_glint_s. All tweens run in real time (KO slow-mo must not stretch them).

const GLINT_SWEEP := 0.32        # s the glint band takes to cross the frame
const GLINT_COLOR := Color(1.0, 0.97, 0.82)
const RING_INSET := -3.5         # px: the middle of the gold border (expand 6, border 5)
const RING_RADIUS := 19.5        # px: card radius 16 + 3.5

@onready var _gold: Panel = $Gold
@onready var _glint: Control = $Glint

var shown := false               # QA: the frame is up (or fading in)
var holder := false              # QA: the glint is running
var _tw: Tween
var _pulse_tw: Tween
var _glint_t := 0.0

func _ready() -> void:
	_glint.draw.connect(_draw_glint)
	_glint.visible = false
	visible = false
	modulate.a = 0.0

## Pop the frame in (entry).
func pop_in() -> void:
	shown = true
	visible = true
	pivot_offset = size * 0.5
	if _tw != null and _tw.is_valid():
		_tw.kill()
	modulate.a = 1.0
	scale = Vector2(1.15, 1.15)
	_tw = create_tween().set_ignore_time_scale(true)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## One border pulse (alpha 1.0 -> 0.6 -> 1.0 over 0.3 s) per showdown step.
func pulse() -> void:
	if not shown:
		return
	if _pulse_tw != null and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_gold.modulate.a = 1.0
	_pulse_tw = create_tween().set_ignore_time_scale(true)
	_pulse_tw.tween_property(_gold, "modulate:a", 0.6, 0.15)
	_pulse_tw.tween_property(_gold, "modulate:a", 1.0, 0.15)

## Fade out (exit) and hide.
func fade_out() -> void:
	set_holder(false)
	if not shown:
		return
	shown = false
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_ignore_time_scale(true)
	_tw.tween_property(self, "modulate:a", 0.0, maxf(Tuning.showdown_frame_fade_s, 0.01))
	_tw.tween_callback(hide)

## The golden-tank holder's glint (polled every frame by MatchHUD: starts / stops within one frame of the tank).
func set_holder(on: bool) -> void:
	on = on and shown
	if on == holder:
		return
	holder = on
	_glint_t = 0.0
	_glint.visible = on
	_glint.queue_redraw()

func _process(delta: float) -> void:
	if not holder:
		return
	_glint_t += delta / maxf(Engine.time_scale, 0.05)
	_glint.queue_redraw()

## A white-gold highlight riding the gold ring where a diagonal band crosses it (top-left -> bottom-right).
func _draw_glint() -> void:
	if not holder:
		return
	var period: float = maxf(Tuning.showdown_frame_glint_s, GLINT_SWEEP + 0.05)
	var ph: float = fmod(_glint_t, period)
	if ph > GLINT_SWEEP:
		return
	var pts: PackedVector2Array = _ring_points()
	var d := Vector2(1, 1).normalized()
	var lo := INF
	var hi := -INF
	for p in pts:
		lo = minf(lo, p.dot(d))
		hi = maxf(hi, p.dot(d))
	var u: float = ph / GLINT_SWEEP
	var band: float = lerpf(lo - 30.0, hi + 30.0, u)
	var w: float = 26.0
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var t: float = ((a + b) * 0.5).dot(d)
		var k: float = exp(-pow((t - band) / w, 2.0))
		if k < 0.03:
			continue
		_glint.draw_line(a, b, Color(GLINT_COLOR.r, GLINT_COLOR.g, GLINT_COLOR.b, 0.95 * k), 6.0, true)   # on the Glint node (its draw signal)

## Sample the gold ring's centre line (a rounded rect RING_INSET outside the card) as a closed polyline.
func _ring_points() -> PackedVector2Array:
	var r := Rect2(Vector2.ZERO, size).grow(-RING_INSET)
	var rad: float = minf(RING_RADIUS, minf(r.size.x, r.size.y) * 0.5)
	var out := PackedVector2Array()
	var corners := [
		[Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[Vector2(r.position.x + rad, r.position.y + rad), PI],
	]
	for c in corners:
		var ctr: Vector2 = c[0]
		var a0: float = c[1]
		for k in range(9):
			var a: float = a0 + PI * 0.5 * float(k) / 8.0
			out.append(ctr + Vector2(cos(a), sin(a)) * rad)
	# densify the straight edges so the band reads as a moving highlight, not a jump
	var dense := PackedVector2Array()
	for i in range(out.size()):
		var a: Vector2 = out[i]
		var b: Vector2 = out[(i + 1) % out.size()]
		var n: int = maxi(1, int(a.distance_to(b) / 8.0))
		for j in range(n):
			dense.append(a.lerp(b, float(j) / float(n)))
	return dense
