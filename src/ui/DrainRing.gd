extends RefCounted
## WK-154: the ONE draining-ring look shared by the Rocketball kickoff gate badge (KickoffGate, WK-131) and the Brawl spawn
## padlock (SuperLockBadge, WK-20e). "Padlock + gold ring = opens when the ring empties": a chocolate-backed track, and a
## gold band with chocolate outline + round caps that drains clockwise from 12 o'clock (frac 1 = full, 0 = empty).
## No class_name (callers preload this script): the drawing code that used to live in KickoffGate._draw_ring, unchanged.

const CHOC := Color("#3B241B")
const RING_GOLD := Color("#FFC93C")
const RING_DRAINED_A := 0.45        # the drained part of the ring = chocolate backing at this alpha

## Draw onto `ci` (inside its _draw / draw signal) centred at `c`: centreline radius `r`, gold band `band`, chocolate outline
## `outline` each side. `frac` = remaining share (drains clockwise from 12 o'clock), `bright` = 0..1 white swing (the gate's
## warning). `alpha` fades the whole ring.
static func draw(ci: CanvasItem, c: Vector2, r: float, band: float, outline: float, frac: float, bright: float = 0.0,
		alpha: float = 1.0) -> void:
	var outer: float = band + 2.0 * outline
	var choc: Color = CHOC.lerp(Color.WHITE, bright * 0.5)
	var gold: Color = RING_GOLD.lerp(Color.WHITE, bright)
	choc.a *= alpha
	gold.a *= alpha
	ci.draw_arc(c, r, 0.0, TAU, 64, Color(choc, RING_DRAINED_A * alpha), outer, true)
	if frac <= 0.001:
		return
	var a1: float = -PI * 0.5 + TAU
	var a0: float = a1 - TAU * minf(frac, 1.0)
	var segs: int = maxi(4, int(64.0 * minf(frac, 1.0)))
	var p0: Vector2 = c + Vector2.from_angle(a0) * r
	var p1: Vector2 = c + Vector2.from_angle(a1) * r
	ci.draw_arc(c, r, a0, a1, segs, choc, outer, true)
	ci.draw_circle(p0, outer * 0.5, choc, true, -1.0, true)
	ci.draw_circle(p1, outer * 0.5, choc, true, -1.0, true)
	ci.draw_arc(c, r, a0, a1, segs, gold, band, true)
	ci.draw_circle(p0, band * 0.5, gold, true, -1.0, true)
	ci.draw_circle(p1, band * 0.5, gold, true, -1.0, true)
