extends Control
## Between-stage COUNTDOWN RING (WK-41 · rendered audit R-27: "show either a countdown ring or an (A) prompt,
## not both"). The ScoreScreen auto-advances, so its one prompt is this ring. It drains as the hold runs out, and
## the next stage lands when it is empty. A cream face with a chocolate "next" chevron sits inside a gold arc on a
## chocolate track. That is the same visual language as PadGlyph's hold ring (gold over translucent chocolate),
## so it reads as part of the glyph kit. Pure _draw, zero art files (PadGlyph / NameTag precedent).
## Passive: PartyMatch sets `remaining` every tick from the authoritative SCOREBOARD timer (ScoreScreen.set_countdown).

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const CREAM := Color(1.0, 1.0, 1.0, 0.97)
const GOLD := Color("#ffd23f")
const FACE_R := 18.0
const RING_GAP := 8.0          # face rim -> ring centreline
const TRACK_W := 9.0
const ARC_W := 6.0

@export var remaining := 1.0:  # 1 = whole hold left (full ring), 0 = advancing now (empty)
	set(v):
		remaining = clampf(v, 0.0, 1.0)
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := (FACE_R + RING_GAP + TRACK_W * 0.5 + 2.0) * 2.0
	custom_minimum_size = Vector2(d, d)

func _draw() -> void:
	var c := size * 0.5
	var rr := FACE_R + RING_GAP
	# track + draining gold arc (clockwise from 12 o'clock, like the PadGlyph hold ring)
	draw_arc(c, rr, 0.0, TAU, 48, Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.55), TRACK_W, true)
	if remaining > 0.0:
		draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * remaining, 48, GOLD, ARC_W, true)
	# cream face, chocolate rim, chocolate "next" chevron (a play triangle, nudged right for optical centring)
	draw_circle(c, FACE_R, CREAM)
	draw_arc(c, FACE_R, 0.0, TAU, 40, CHOCO, 3.0, true)
	var o := c + Vector2(2.0, 0.0)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-6.0, -8.0), o + Vector2(8.0, 0.0), o + Vector2(-6.0, 8.0)]), CHOCO)
