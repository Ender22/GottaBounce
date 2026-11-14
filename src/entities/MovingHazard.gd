class_name MovingHazard
extends Area2D
## Kinematic moving hazard (docs/specs/v1_moving_hazard.md §1; WK-96 owner fixes 2026-11-14).
##   `pendulum` — a heavy wrecking ball on a chain swinging through an arc from a bolted anchor.
##   `sweep`    — a bar/ball sliding between two endpoints.
##
## WK-96 (owner: "big swinging pendulums ... went right through a player and didnt smash them" +
## "not very cool looking motion, they look very stiff and like poor quality"):
##  - CONTACT: a pendulum ball moving at >= Tuning.pendulum_smash_min_speed SMASHES (Player.
##    receive_hazard_smash: knockback + hitstun + tumble, no sting / no damage / no credit). Below the
##    gate (apex hang) it stays the soft shove. Detection is SWEPT (capsule prev->current ball pos, direct
##    space query every physics tick) so it can never skip a body or lag a tick behind the area overlap
##    list. Per-victim re-hit gate Tuning.pendulum_rehit_cd. JSON "contact": "smash" | "shove" overrides
##    the default (pendulum = smash, sweep = shove — the owner report was about pendulums).
##  - MOTION: a gravity-pendulum swing (theta = A * shape(-cos(2*pi*u))): continuous everywhere, fastest
##    at the bottom, decelerating into a soft HANG at each apex (the old shape froze dead-flat at each
##    apex for 24% of the period, then lurched — the "stiff" read). period_s / arc_deg / phase / dwell_frac
##    stay in level JSON (INV-7); dwell_frac now sets how long the apex hang lingers.
##  - LOOK: chain links from a bolted anchor plate, ball sprite rotates WITH the arm (eyelet always points
##    at the pivot), soft drop shadow, motion smear + ghosts at speed, squash/recoil on a smash, one quiet
##    whoosh per fast pass (EventBus.hazard_whoosh -> AudioManager). Telegraph arc kept (faint).
## A/B: MovingHazard.legacy_motion = true reproduces the pre-WK-96 motion + look + shove-only contact
## (for BEFORE recordings only — RecordBoot arg hazard_legacy=1).

static var legacy_motion := false

const LAYER_MOVING_HAZARD := 1 << 4    # 16 — layer 5, distinct from instakill LAYER_HAZARDS (1<<3)
const MASK_PLAYERS := 1 << 0

# --- Glossy Toybox wrecking-ball sprite. Image is 689x772: the SPHERE fills the bottom (diameter == the
# image width) and the top ~83px is the eyelet. Sphere CENTRE in image coords = (344.5, 427.5); the eyelet
# ring centre sits at ~y=55. ---
const WBALL_TEX: Texture2D = preload("res://assets/hazards/wrecking_ball.png")
const WBALL_TEX_W := 689.0
const WBALL_TEX_H := 772.0
const WBALL_SPHERE_DIAM := 689.0
const WBALL_SPHERE_CX := 344.5
const WBALL_SPHERE_CY := 427.5
const WBALL_EYELET_CY := 55.0
const WBALL_OVERSCALE := 1.05

# Glossy Toybox palette for the code-drawn chain/anchor (matches the sprite's chocolate outline + steel)
const C_OUTLINE := Color(0.231373, 0.141176, 0.105882, 1.0)
const C_STEEL := Color(0.30, 0.32, 0.37)
const C_STEEL_DK := Color(0.17, 0.18, 0.21)
const C_STEEL_HI := Color(0.72, 0.75, 0.82)
const CHAIN_LINK := 40.0               # px per chain link along the arm

# --- motion params (from JSON; all data, no Tuning) ---
var kind: String = "pendulum"
var contact_mode: String = "smash"
var pivot: Vector2 = Vector2.ZERO
var arm_len: float = 620.0
var arc_rad: float = deg_to_rad(150.0)
var period_s: float = 3.4
var phase: float = 0.0
var dwell_frac: float = 0.22
var radius: float = 90.0
var p0: Vector2 = Vector2.ZERO
var p1: Vector2 = Vector2.ZERO

var _t: float = 0.0
var _theta: float = 0.0
var _ball_pos: Vector2 = Vector2.ZERO
var _prev_ball_pos: Vector2 = Vector2.ZERO
var _ball_vel: Vector2 = Vector2.ZERO
var _shape: CollisionShape2D
var _query: PhysicsShapeQueryParameters2D
var _circle: CircleShape2D
var _capsule: CapsuleShape2D
var _last_hit := {}        # victim instance_id -> _t of the last smash (re-hit gate)
var _inside := {}          # victim instance_id -> true while inside the swept volume (contact episodes)
var _ep := {}              # victim instance_id -> {speed_max, result} for the current episode
var _trail: Array = []     # recent ball positions (newest last) for the motion smear
var _squash_t := 0.0
var _squash_n := Vector2.RIGHT
var _was_fast := false

# --- QA counters (read via gbplay eval / the MatchRecorder) ---
var qa_contacts := 0           # contact episodes (a body entering the swept ball volume)
var qa_fast_contacts := 0      # ...of which the ball was at/above the smash speed gate at some point
var qa_smashes := 0            # smashes landed
var qa_shoves := 0             # shove applications (apex grazes / shove-mode)
var qa_immune := 0             # fast contacts that hit an immune body (Star / spawn protect / Counter)
var qa_log: Array = []         # finished episodes {t, who, speed_max, result}

func setup_from_json(o: Dictionary) -> void:
	kind = str(o.get("kind", "pendulum"))
	contact_mode = str(o.get("contact", "smash" if kind == "pendulum" else "shove"))
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
	position = Vector2.ZERO   # node at world origin: local == global
	collision_layer = LAYER_MOVING_HAZARD
	collision_mask = MASK_PLAYERS
	monitoring = legacy_motion   # the swept direct query replaces the overlap list (legacy keeps it)
	set_meta("moving_hazard", true)
	_shape = CollisionShape2D.new()
	_circle = CircleShape2D.new()
	_circle.radius = radius
	_shape.shape = _circle
	add_child(_shape)
	_capsule = CapsuleShape2D.new()
	_capsule.radius = radius
	_query = PhysicsShapeQueryParameters2D.new()
	_query.collision_mask = MASK_PLAYERS
	_query.collide_with_areas = false
	_query.collide_with_bodies = true
	_ball_pos = _compute_ball(0.0)
	_prev_ball_pos = _ball_pos
	_shape.position = _ball_pos
	z_index = 40   # over platforms/void, under HUD

# ------------------------------------------------------------------ motion
## Swing value in [-1, 1] at time t (deterministic phase clock).
func _osc(t: float) -> float:
	if legacy_motion:
		return _osc_legacy(t)
	var u := fposmod(t / period_s + phase, 1.0)
	# gravity pendulum: c = -cos(2*pi*u) is the small-angle solution (-1 apex at u=0, +1 at u=0.5).
	# sin(pi/2 * c) flattens the apex to 4th order (the ball LINGERS at the top, like a large-amplitude
	# pendulum) while keeping the bottom the fastest point; dwell_frac 0.24 (the shipped levels) = full hang.
	var c := -cos(TAU * u)
	var hang := clampf(dwell_frac / 0.24, 0.0, 1.0)
	return lerpf(c, sin(PI * 0.5 * c), hang)

## Pre-WK-96 shape (A/B only): two smootherstep swings joined by a dead-flat DWELL at each apex.
func _osc_legacy(t: float) -> float:
	var u := fposmod(t / period_s + phase, 1.0)
	var d := dwell_frac
	var swing := (1.0 - 2.0 * d) * 0.5
	if swing <= 0.0001:
		return 0.0
	if u < swing:
		return lerpf(-1.0, 1.0, _smoother(u / swing))
	elif u < swing + d:
		return 1.0
	elif u < 2.0 * swing + d:
		return lerpf(1.0, -1.0, _smoother((u - swing - d) / swing))
	else:
		return -1.0

static func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

func _compute_ball(t: float) -> Vector2:
	var s := _osc(t)
	if kind == "sweep":
		return p0.lerp(p1, (s + 1.0) * 0.5)
	# pendulum: theta = deviation from straight-down; ball hangs below the pivot.
	_theta = s * (arc_rad * 0.5)
	return pivot + arm_len * Vector2(sin(_theta), cos(_theta))

## QA helpers (MatchRecorder pendulum_test): the ball centre at hazard-clock time `t` (pure — restores
## the cached arm angle), the hazard clock, and the current ball speed.
func ball_pos_at(t: float) -> Vector2:
	var keep := _theta
	var p := _compute_ball(t)
	_theta = keep
	return p

func qa_clock() -> float:
	return _t

func ball_speed() -> float:
	return _ball_vel.length()

func _physics_process(delta: float) -> void:
	_t += delta
	_prev_ball_pos = _ball_pos
	_ball_pos = _compute_ball(_t)
	if delta > 0.0:
		_ball_vel = (_ball_pos - _prev_ball_pos) / delta
	_shape.position = _ball_pos
	_squash_t = maxf(0.0, _squash_t - delta)
	_trail.append(_ball_pos)
	while _trail.size() > maxi(2, Tuning.pendulum_trail_len):
		_trail.pop_front()
	var speed := _ball_vel.length()
	var fast := speed >= Tuning.pendulum_whoosh_speed
	if fast and not _was_fast and not legacy_motion:
		EventBus.hazard_whoosh.emit(self, _ball_pos, speed)
	_was_fast = fast
	queue_redraw()
	if legacy_motion:
		_shove_overlapping_legacy()
	else:
		_contact_swept()

# ------------------------------------------------------------------ contact (WK-96)
## Bodies inside the ball's swept volume THIS tick (capsule from the previous to the current ball centre).
func _swept_hits() -> Array:
	var seg := _ball_pos - _prev_ball_pos
	var L := seg.length()
	if L < 2.0:
		_query.shape = _circle
		_query.transform = Transform2D(0.0, _ball_pos)
	else:
		_capsule.radius = radius
		_capsule.height = L + 2.0 * radius
		_query.shape = _capsule
		_query.transform = Transform2D(seg.angle() - PI * 0.5, (_ball_pos + _prev_ball_pos) * 0.5)
	var out: Array = []
	for r in get_world_2d().direct_space_state.intersect_shape(_query, 8):
		var b = r.get("collider")
		if b != null and is_instance_valid(b) and b.has_method("receive_shove") and not out.has(b):
			out.append(b)
	return out

func _contact_swept() -> void:
	var now_in := {}
	var speed := _ball_vel.length()
	for body in _swept_hits():
		if body.has_method("is_dead") and body.is_dead():
			continue
		if ("frozen" in body and body.frozen) or not body.visible:
			continue   # suspended (intro / countdown / KO freeze) or not yet popped in: not in play
		var id: int = body.get_instance_id()
		now_in[id] = true
		if not _inside.has(id):
			qa_contacts += 1
			_ep[id] = {"t": _t, "who": str(body.name), "speed_max": 0.0, "result": "shove", "fast": false}
		var ep: Dictionary = _ep.get(id, {})
		ep["speed_max"] = maxf(float(ep.get("speed_max", 0.0)), speed)
		if contact_mode == "smash" and speed >= Tuning.pendulum_smash_min_speed:
			if not bool(ep.get("fast", false)):
				ep["fast"] = true
				qa_fast_contacts += 1
			var n: Vector2 = body.global_position - _ball_pos
			n = n.normalized() if n.length() > 1.0 else _ball_vel.normalized()
			if _t < float(_last_hit.get(id, -1000.0)) + Tuning.pendulum_rehit_cd:
				# this swing already smashed them — no machine-gun re-hit, but never let the ball slide
				# through them either (it accelerates out of a near-apex hit and can catch up)
				if body.has_method("hazard_push_out"):
					body.hazard_push_out(n, maxf(0.0, _ball_vel.dot(n)) + Tuning.pendulum_sep_margin)
				if str(ep.get("result", "")) == "shove":
					ep["result"] = "gated"
				_ep[id] = ep
				continue
			var vdir := _ball_vel / maxf(speed, 0.001)
			var dir := (n + vdir * Tuning.pendulum_smash_carry).normalized()
			var mag := clampf(speed * Tuning.pendulum_smash_scale,
				Tuning.pendulum_smash_impulse_min, Tuning.pendulum_smash_impulse_max)
			var min_vn := maxf(0.0, _ball_vel.dot(n)) + Tuning.pendulum_sep_margin
			var spin := Tuning.pendulum_spin * (1.0 if vdir.cross(n) >= 0.0 else -1.0)
			_last_hit[id] = _t
			var landed := false
			if body.has_method("receive_hazard_smash"):
				landed = body.receive_hazard_smash(dir * mag, n, min_vn, spin)
			if landed:
				qa_smashes += 1
				ep["result"] = "smash"
				_squash_t = Tuning.pendulum_hit_squash_time
				_squash_n = n
			else:
				qa_immune += 1
				if str(ep.get("result", "")) != "smash":
					ep["result"] = "immune"
		else:
			# apex graze / shove-mode: the soft shove (rate-limited by the victim's own _shove_cd)
			var pv: Vector2 = body.velocity if "velocity" in body else Vector2.ZERO
			var rel: float = (_ball_vel - pv).length()
			var sdir := _ball_vel
			if sdir.length() < 40.0:
				sdir = body.global_position - _ball_pos
			body.receive_shove(sdir, rel, self)
			qa_shoves += 1
		_ep[id] = ep
	# close finished episodes
	for id in _inside.keys():
		if not now_in.has(id) and _ep.has(id):
			qa_log.append(_ep[id])
			if qa_log.size() > 200:
				qa_log.pop_front()
			_ep.erase(id)
	_inside = now_in

## Pre-WK-96 contact (A/B only): overlap-list SHOVE, never a smash.
func _shove_overlapping_legacy() -> void:
	for body in get_overlapping_bodies():
		if not is_instance_valid(body) or not body.has_method("receive_shove"):
			continue
		var pv: Vector2 = body.velocity if "velocity" in body else Vector2.ZERO
		var rel: float = (_ball_vel - pv).length()
		var dir := _ball_vel
		if dir.length() < 40.0:
			dir = body.global_position - _ball_pos
		body.receive_shove(dir, rel, self)
		qa_shoves += 1

# ------------------------------------------------------------------ telegraphy + look (INV-12: display only)
func _draw() -> void:
	if legacy_motion:
		_draw_legacy()
		return
	var danger := Color(0.86, 0.16, 0.16, 0.16)   # matte hazard-red guide (void-rim palette)
	if kind == "sweep":
		draw_line(p0, p1, danger, 22.0)
		draw_line(p0, p1, C_OUTLINE, 10.0)
		draw_line(p0, p1, C_STEEL, 5.0)
		_draw_motion_smear()
		_draw_ball(_ball_pos, 0.0)
		return
	# swept danger-arc (faint telegraph: where the ball will be)
	var pts := PackedVector2Array()
	var n := 32
	for i in range(n + 1):
		var th := lerpf(-arc_rad * 0.5, arc_rad * 0.5, float(i) / float(n))
		pts.append(pivot + arm_len * Vector2(sin(th), cos(th)))
	draw_polyline(pts, danger, 24.0, true)
	var to_pivot := (pivot - _ball_pos).normalized()
	var s := (2.0 * radius * WBALL_OVERSCALE) / WBALL_SPHERE_DIAM
	var eyelet := _ball_pos + to_pivot * ((WBALL_SPHERE_CY - WBALL_EYELET_CY) * s)
	_draw_motion_smear()
	_draw_chain(pivot, eyelet)
	_draw_anchor(pivot)
	_draw_ball(_ball_pos, -_theta)

## Chain: alternating face-on rings and edge-on bars from the anchor hub down to the ball's eyelet.
func _draw_chain(a: Vector2, b: Vector2) -> void:
	var v := b - a
	var L := v.length()
	if L < 4.0:
		return
	var dir := v / L
	var count := maxi(2, int(round(L / CHAIN_LINK)))
	var step := L / float(count)
	var ang := dir.angle()
	var perp := dir.orthogonal()
	for i in range(count):
		var c := a + dir * (step * (float(i) + 0.5))
		if i % 2 == 0:
			# face-on oval ring (long axis along the chain)
			draw_set_transform(c, ang, Vector2(1.0, 0.56))
			draw_arc(Vector2.ZERO, step * 0.66, 0.0, TAU, 22, C_OUTLINE, 11.0, true)
			draw_arc(Vector2.ZERO, step * 0.66, 0.0, TAU, 22, C_STEEL, 6.0, true)
			draw_arc(Vector2.ZERO, step * 0.66, PI * 1.1, PI * 1.6, 8, C_STEEL_HI, 2.5, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			# edge-on link (a short thick bar)
			var h := dir * (step * 0.62)
			draw_line(c - h, c + h, C_OUTLINE, 13.0, true)
			draw_line(c - h, c + h, C_STEEL_DK, 7.5, true)
			draw_line(c - h - perp * 1.5, c + h - perp * 1.5, C_STEEL_HI, 2.0, true)

## Bolted anchor plate + pin hub at the pivot (reads as the mount the chain hangs from).
func _draw_anchor(c: Vector2) -> void:
	var plate := PackedVector2Array([c + Vector2(-58, -40), c + Vector2(58, -40), c + Vector2(38, 18), c + Vector2(-38, 18)])
	var outline := PackedVector2Array([c + Vector2(-66, -46), c + Vector2(66, -46), c + Vector2(43, 24), c + Vector2(-43, 24)])
	draw_colored_polygon(outline, C_OUTLINE)
	draw_colored_polygon(plate, C_STEEL)
	draw_line(c + Vector2(-54, -36), c + Vector2(54, -36), C_STEEL_HI, 3.0, true)
	for bx in [-38.0, 38.0]:
		var bp: Vector2 = c + Vector2(bx, -22)
		draw_circle(bp, 8.0, C_OUTLINE)
		draw_circle(bp, 5.5, C_STEEL_HI)
		draw_circle(bp + Vector2(1, 1), 2.5, C_STEEL_DK)
	draw_circle(c, 22.0, C_OUTLINE)
	draw_circle(c, 17.0, C_STEEL_HI)
	draw_circle(c, 12.0, C_STEEL)
	draw_circle(c, 5.0, C_STEEL_DK)

## Motion smear + two ghost balls behind the ball while it moves fast (peak-speed read).
func _draw_motion_smear() -> void:
	var speed := _ball_vel.length()
	if speed < Tuning.pendulum_trail_speed or _trail.size() < 3:
		return
	var k := clampf((speed - Tuning.pendulum_trail_speed) / maxf(1.0, Tuning.pendulum_trail_speed), 0.0, 1.0)
	var pts := PackedVector2Array(_trail)
	var cols := PackedColorArray()
	for i in range(pts.size()):
		var f := float(i) / float(pts.size() - 1)
		cols.append(Color(0.85, 0.88, 0.95, 0.30 * k * f * f))
	draw_polyline_colors(pts, cols, radius * 1.7, true)
	var rot := -_theta if kind == "pendulum" else 0.0
	var gi1: int = int(pts.size() * 0.25)
	var gi2: int = int(pts.size() * 0.6)
	_draw_ball(pts[gi1], rot, Color(1, 1, 1, 0.14 * k), false)
	_draw_ball(pts[gi2], rot, Color(1, 1, 1, 0.24 * k), false)

## The ball sprite: sphere centred on `c`, rotated with the arm (eyelet toward the pivot), drop shadow,
## and a squash/recoil along the last hit normal for a beat after a smash.
func _draw_ball(c: Vector2, rot: float, tint := Color.WHITE, main := true) -> void:
	var s := (2.0 * radius * WBALL_OVERSCALE) / WBALL_SPHERE_DIAM
	var size := Vector2(WBALL_TEX_W * s, WBALL_TEX_H * s)
	var off := Vector2(-WBALL_SPHERE_CX * s, -WBALL_SPHERE_CY * s)   # sphere centre -> local origin
	if main:
		# soft drop shadow (heft): offset down-right, never rotated
		draw_circle(c + Vector2(10, 14), radius * 1.02, Color(0.08, 0.05, 0.10, 0.22))
	var xf := Transform2D(rot, c)
	if main and _squash_t > 0.0:
		var a := _squash_t / maxf(0.001, Tuning.pendulum_hit_squash_time)
		var sq := 0.22 * a * a
		var na := _squash_n.angle()
		var squash := Transform2D(na, Vector2.ZERO) * Transform2D(0.0, Vector2(1.0 - sq, 1.0 + sq * 0.6), 0.0, Vector2.ZERO) * Transform2D(-na, Vector2.ZERO)
		xf = Transform2D(0.0, c - _squash_n * (radius * sq * 0.5)) * squash * Transform2D(rot, Vector2.ZERO)
	draw_set_transform_matrix(xf)
	draw_texture_rect(WBALL_TEX, Rect2(off, size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Pre-WK-96 look (A/B only).
func _draw_legacy() -> void:
	var steel := Color(0.16, 0.17, 0.20)
	var steel_hi := Color(0.34, 0.36, 0.42)
	var danger := Color(0.86, 0.16, 0.16, 0.22)
	if kind == "sweep":
		draw_line(p0, p1, danger, 22.0)
		draw_line(p0, p1, steel.darkened(0.2), 6.0)
		_draw_ball_legacy(_ball_pos)
		return
	var pts := PackedVector2Array()
	var n := 28
	for i in range(n + 1):
		var th := lerpf(-arc_rad * 0.5, arc_rad * 0.5, float(i) / float(n))
		pts.append(pivot + arm_len * Vector2(sin(th), cos(th)))
	draw_polyline(pts, danger, 26.0)
	draw_circle(pivot, 26.0, steel)
	draw_circle(pivot, 26.0, steel_hi)
	draw_circle(pivot, 18.0, steel)
	draw_line(pivot, _ball_pos, steel_hi, 14.0)
	draw_line(pivot, _ball_pos, steel, 8.0)
	_draw_ball_legacy(_ball_pos)

func _draw_ball_legacy(c: Vector2) -> void:
	var s := (2.0 * radius * WBALL_OVERSCALE) / WBALL_SPHERE_DIAM
	var top_left := Vector2(c.x - WBALL_SPHERE_CX * s, c.y - WBALL_SPHERE_CY * s)
	draw_texture_rect(WBALL_TEX, Rect2(top_left, Vector2(WBALL_TEX_W * s, WBALL_TEX_H * s)), false)
