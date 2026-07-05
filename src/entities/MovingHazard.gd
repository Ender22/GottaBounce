class_name MovingHazard
extends Area2D
## Kinematic moving SHOVE-hazard (docs/specs/v1_moving_hazard.md §1). Modelled on Hazard.gd
## (Area2D detector, senses players) BUT its contact path is Player.receive_shove — NEVER kill,
## NEVER the smash branch. It funnels players toward the void; the void kills, the hazard does not.
##
## Motion is a DETERMINISTIC phase clock driven by the physics time (no physics ODE, no randomness):
##   `pendulum` — a heavy ball on a rigid arm swinging through an arc, slowing to a DWELL at each apex
##                (the readable "clear beat" — cross when the ball hangs), fastest at the arc bottom.
##   `sweep`    — a bar sliding between two endpoints, dwelling briefly at each end.
## All motion params come from level JSON (INV-7); NO Tuning constant is touched. The shove magnitude
## is the arm's contact-point speed, so a full-swing clip flings hard (clamped to soft_bump_max) and an
## apex graze barely nudges — the arm's readable speed IS its readable threat (§1.2, self-telegraphing).
##
## Collision (§1.3): a NEW distinct layer bit (layer 5 = kinematic shovers), so a "hazard" is never
## ambiguously lethal-vs-shove — the instakill Hazard.gd keeps layer 4. Senses players only (mask 1).
## Overlap-only (the de-risked ship): the player body can clip the visual but still gets flung; solid
## collision is an optional polish follow-up (§1.3 tradeoff).

const LAYER_MOVING_HAZARD := 1 << 4    # 16 — layer 5, distinct from instakill LAYER_HAZARDS (1<<3)
const MASK_PLAYERS := 1 << 0

# --- Glossy Toybox wrecking-ball sprite (pays down the no-code-drawn-assets debt; owner-flagged; same
# pattern as the hammer/bomb/crusher/falling_debris wiring). A charcoal iron SPHERE with a rivet ring +
# a small eyelet loop on top. Image is 689x772: the SPHERE fills the bottom (diameter == the 689px image
# width) and the top ~83px is the decorative eyelet. Sphere CENTRE in image coords = (W/2, H - W/2) =
# (344.5, 427.5) (verified from the alpha silhouette). The code-drawn ball BODY is replaced by this
# sprite via draw_texture_rect, scaled so the visible sphere == 2*radius (small OVERSCALE so the metal
# always covers the shove-body — fair reads) and the sphere centre pinned to `_ball_pos`. The eyelet
# sticks straight up, which reads as the arm's attachment for the pendulum. The swept danger-arc, the
# anchor mount and the rigid arm stay as code telegraph. ---
const WBALL_TEX: Texture2D = preload("res://assets/hazards/wrecking_ball.png")
const WBALL_TEX_W := 689.0
const WBALL_TEX_H := 772.0
const WBALL_SPHERE_DIAM := 689.0       # sphere diameter in image px (== image width)
const WBALL_SPHERE_CX := 344.5         # sphere centre x in image px (W/2)
const WBALL_SPHERE_CY := 427.5         # sphere centre y in image px (H - diam/2; eyelet above)
const WBALL_OVERSCALE := 1.05          # metal slightly overhangs the shove-body radius (fair reads)

# --- motion params (from JSON; all data, no Tuning) ---
var kind: String = "pendulum"
var pivot: Vector2 = Vector2.ZERO
var arm_len: float = 620.0
var arc_rad: float = deg_to_rad(150.0)   # full arc; swing spans -arc/2 .. +arc/2 from straight-down
var period_s: float = 3.4
var phase: float = 0.0                   # 0..1 phase offset (two hazards can run offset rhythms)
var dwell_frac: float = 0.22             # fraction of the period spent hanging at EACH apex (clear beat)
var radius: float = 90.0                 # the shove-body (ball) size
# sweep-only
var p0: Vector2 = Vector2.ZERO
var p1: Vector2 = Vector2.ZERO

var _t: float = 0.0
var _ball_pos: Vector2 = Vector2.ZERO
var _prev_ball_pos: Vector2 = Vector2.ZERO
var _ball_vel: Vector2 = Vector2.ZERO
var _shape: CollisionShape2D

func setup_from_json(o: Dictionary) -> void:
	kind = str(o.get("kind", "pendulum"))
	radius = float(o.get("radius", 90.0))
	period_s = maxf(0.2, float(o.get("period_s", 3.4)))
	phase = float(o.get("phase", 0.0))
	dwell_frac = clampf(float(o.get("dwell_frac", 0.22)), 0.0, 0.45)
	if kind == "sweep":
		var a = o.get("p0", {"x": 0.0, "y": 0.0})
		var b = o.get("p1", {"x": 0.0, "y": 0.0})
		p0 = Vector2(float(a.get("x", 0.0)), float(a.get("y", 0.0)))
		p1 = Vector2(float(b.get("x", 0.0)), float(b.get("y", 0.0)))
	else:
		var pv = o.get("pivot", {"x": 0.0, "y": 0.0})
		pivot = Vector2(float(pv.get("x", 0.0)), float(pv.get("y", 0.0)))
		arm_len = float(o.get("arm_len", 620.0))
		arc_rad = deg_to_rad(float(o.get("arc_deg", 150.0)))

func _ready() -> void:
	# node at world origin: local == global, so _draw / shape positions are all in world coords.
	position = Vector2.ZERO
	collision_layer = LAYER_MOVING_HAZARD
	collision_mask = MASK_PLAYERS
	monitoring = true
	set_meta("moving_hazard", true)
	_shape = CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = radius
	_shape.shape = circ
	add_child(_shape)
	_ball_pos = _compute_ball(0.0)
	_prev_ball_pos = _ball_pos
	_shape.position = _ball_pos
	z_index = 40   # over platforms/void, under HUD

## Shaped oscillator in [0,1] phase: two smootherstep swings + a flat DWELL at each extreme.
## Returns a value in [-1, 1]; smootherstep endpoints have ZERO derivative, so it joins the flat
## dwell with no velocity discontinuity (natural apex slow-down, C1-continuous, deterministic).
func _osc(t: float) -> float:
	var u := fposmod(t / period_s + phase, 1.0)
	var d := dwell_frac
	var swing := (1.0 - 2.0 * d) * 0.5   # each of the two swings is this fraction of the period
	if swing <= 0.0001:
		return 0.0
	if u < swing:
		return lerpf(-1.0, 1.0, _smoother(u / swing))          # swing A -> B
	elif u < swing + d:
		return 1.0                                              # DWELL at +apex (clear beat)
	elif u < 2.0 * swing + d:
		return lerpf(1.0, -1.0, _smoother((u - swing - d) / swing))  # swing B -> A
	else:
		return -1.0                                             # DWELL at -apex (clear beat)

static func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

func _compute_ball(t: float) -> Vector2:
	var s := _osc(t)
	if kind == "sweep":
		# s in [-1,1] -> [0,1] along the rail p0..p1
		return p0.lerp(p1, (s + 1.0) * 0.5)
	# pendulum: theta = deviation from straight-down; ball hangs below the pivot.
	var theta := s * (arc_rad * 0.5)
	return pivot + arm_len * Vector2(sin(theta), cos(theta))

func _physics_process(delta: float) -> void:
	_t += delta
	_prev_ball_pos = _ball_pos
	_ball_pos = _compute_ball(_t)
	# contact-point velocity from the driven path (finite difference) — ~0 at the apex dwell,
	# max at the arc bottom. This IS the shove magnitude term, so danger is self-telegraphing.
	if delta > 0.0:
		_ball_vel = (_ball_pos - _prev_ball_pos) / delta
	_shape.position = _ball_pos
	queue_redraw()
	_shove_overlapping()

func _shove_overlapping() -> void:
	for body in get_overlapping_bodies():
		if not is_instance_valid(body) or not body.has_method("receive_shove"):
			continue
		# rel = |arm contact velocity - player velocity| — the exact term _soft_separate uses.
		var pv: Vector2 = body.velocity if "velocity" in body else Vector2.ZERO
		var rel: float = (_ball_vel - pv).length()
		# fling the way the arm swings; near the apex (vel ~0) fall back to a radial push off the ball
		# so a rare apex-contact still separates rather than shoving in a null direction.
		var dir := _ball_vel
		if dir.length() < 40.0:
			dir = body.global_position - _ball_pos
		body.receive_shove(dir, rel, self)

# ------------------------------------------------------------------ telegraphy (INV-12: display only)
func _draw() -> void:
	var steel := Color(0.16, 0.17, 0.20)
	var steel_hi := Color(0.34, 0.36, 0.42)
	var danger := Color(0.86, 0.16, 0.16, 0.22)   # matte hazard-red guide (void-rim palette)
	if kind == "sweep":
		# the rail + a faint danger stripe along the swept lane
		draw_line(p0, p1, danger, 22.0)
		draw_line(p0, p1, steel.darkened(0.2), 6.0)
		_draw_ball(_ball_pos)
		return
	# pendulum: the swept danger-arc (faint), the anchor mount, the rigid arm, the ball.
	var pts := PackedVector2Array()
	var n := 28
	for i in range(n + 1):
		var th := lerpf(-arc_rad * 0.5, arc_rad * 0.5, float(i) / float(n))
		pts.append(pivot + arm_len * Vector2(sin(th), cos(th)))
	draw_polyline(pts, danger, 26.0)
	# anchor mount (a chunky bracket at the pivot)
	draw_circle(pivot, 26.0, steel)
	draw_circle(pivot, 26.0, steel_hi)
	draw_circle(pivot, 18.0, steel)
	# rigid arm
	draw_line(pivot, _ball_pos, steel_hi, 14.0)
	draw_line(pivot, _ball_pos, steel, 8.0)
	_draw_ball(_ball_pos)

# The ball BODY is now the wrecking_ball sprite: its metal SPHERE (image bottom, diameter
# WBALL_SPHERE_DIAM) is centred on `c` with a visible diameter of 2*radius*OVERSCALE, and the eyelet
# sticks up ABOVE it (reading as the arm's attachment). The full image is stretched into a rect via
# draw_texture_rect; the top-left is derived so the sphere-centre image point lands exactly on `c`.
func _draw_ball(c: Vector2) -> void:
	var s := (2.0 * radius * WBALL_OVERSCALE) / WBALL_SPHERE_DIAM
	var top_left := Vector2(c.x - WBALL_SPHERE_CX * s, c.y - WBALL_SPHERE_CY * s)
	draw_texture_rect(WBALL_TEX, Rect2(top_left, Vector2(WBALL_TEX_W * s, WBALL_TEX_H * s)), false)
