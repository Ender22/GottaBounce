extends Node2D
## WK-116 PRESSURE NETS (docs/specs/wk116_long_rally_2026-11-15.md). Rocketball's long-rally escalation: after
## Tuning.sports_pressure_t1_s of live ball with no goal both goal mouths widen by grow1_frac ("PRESSURE!"), after t2 by
## grow2_frac ("MAX PRESSURE!") and the crowd clap-chants until somebody scores.
##
## LIFETIME: SportsMode.on_stage_ready makes ONE of these per soccer stage when Tuning.sports_pressure_rule != 0 (rule 0 never
## makes the node: byte-identical game). It lives on the level root, so the next kickoff's stage reload frees it together with
## the moved posts and rebuilds base-size mouths: no reset code, no extra time, the 2.667 s restart and the WK-131 kickoff gates
## are untouched by construction. No class_name (SportsMode preloads it and calls it duck-typed).
##
## CLOCK: Ball.ball_clock() (live ball, game time: freezes with hit-stop / pause / the disconnect overlay). Inert before
## t1 - warn; while any kickoff gate is still closed nothing happens either (defence in depth for the t1 - warn > gate invariant).
##
## GEOMETRY (spec §4.1, found from the goal_zone data, no court JSON tags needed): per mouth the UPPER and LOWER post columns
## (bumper bodies whose court-side face is the mouth plane and whose ends touch the mouth edges) RETRACT away from the mouth:
## each body is translated into its ceiling / floor housing (collider + art move together; the art is cropped at the housing
## face so nothing pokes out). Retraction only turns solid post into air, so it never pushes a goat or the ball. The BACK POST
## collider extends at the step tick to span the new mouth +- sports_pressure_back_margin (the WK-122 pocket stays sealed; that
## space is unreachable behind the post column) and its art telescopes out with the slide. The GoalZone rect grows with the posts
## (x unchanged) and the cage art follows. Constraints per court (spec §4.3): the bottom edge never drops below the floor-bouncer
## apex centre (growth moves to the top edge), a post never retracts shorter than sports_pressure_min_post_px, and an optional
## court JSON "pressure_max_grow_px" caps the total growth.

const CHOCO := Color("#3B241B")
const SQUASH_TOL := 12.0                 # px of penetration a fast ball / goat contact normally shows (measured 3 px) is not a squash

var rule: int = 1
var step: int = -1                       # -1 inert, 0 anticipation, 1 PRESSURE!, 2 MAX PRESSURE!
var step_t: Array = [-1.0, -1.0, -1.0]  # ball clock of the warn / step 1 / step 2 tick
var over: bool = false                   # a goal latched (or the rule disabled itself): nothing changes any more
var disabled_reason: String = ""         # set when a court's mouths could not be mapped (the rule stays off, symmetric)
var leak_ticks: int = 0                  # QA (G3): body centres behind a mouth plane but outside the live mouth band
var squash_ticks: int = 0                # QA (M4): body centre DEEP inside a moved post (> SQUASH_TOL px: a crush, not contact)
var log_lines: Array = []                # QA

var _runner = null
var _mode = null
var _ball: Node = null
var _override_px: float = -1.0
var _mouths: Array = []                  # see _map_mouth
var _slide_t0: float = -1.0
var _chev_age: float = -1.0
var _chev_step: int = 0
var _emitted_over: bool = false

## Bind to the stage (call after add_child, after the ball + gates exist). `override_px` = court JSON "pressure_max_grow_px" (-1 none).
func setup(runner, mode, ball: Node, override_px: float) -> void:
	_runner = runner
	_mode = mode
	_ball = ball
	_override_px = override_px
	z_as_relative = false
	z_index = 39                          # chevrons: over goats, under the ball (40)
	if Tuning.sports_pressure_t1_s - Tuning.sports_pressure_warn_s <= Tuning.sports_gate_open_s:
		push_warning("WK-116: t1 - warn (%.2f) <= sports_gate_open_s (%.2f): pressure waits for the gates" \
			% [Tuning.sports_pressure_t1_s - Tuning.sports_pressure_warn_s, Tuning.sports_gate_open_s])
	if Tuning.sports_pressure_t2_s <= Tuning.sports_pressure_t1_s:
		push_warning("WK-116: t2 <= t1 - step 2 fires on the same tick as step 1")
	var host: Node = runner._level_root
	for z in get_tree().get_nodes_in_group("goal_zone"):
		if not is_instance_valid(z) or (z as Node).is_queued_for_deletion() or (z as Node).get_parent() != host:
			continue
		if str(z.get("style")) == "hidden":
			continue
		var m: Dictionary = _map_mouth(z, host)
		if m.is_empty():
			disabled_reason = "unmapped mouth (team %d)" % int(z.get("team"))
			push_warning("WK-116: %s - PRESSURE NETS off this stage" % disabled_reason)
			_mouths = []
			over = true
			return
		_mouths.append(m)
	if _mouths.size() != 2:
		disabled_reason = "%d mouths" % _mouths.size()
		push_warning("WK-116: %s - PRESSURE NETS off this stage" % disabled_reason)
		_mouths = []
		over = true

# ------------------------------------------------------------------ geometry mapping

func _rect_of(body: StaticBody2D) -> Rect2:
	for c in body.get_children():
		var cs: CollisionShape2D = c as CollisionShape2D
		if cs != null and cs.shape is RectangleShape2D:
			var sz: Vector2 = (cs.shape as RectangleShape2D).size
			return Rect2(body.global_position + cs.position - sz * 0.5, sz)
	return Rect2()

func _map_mouth(z: Node, host: Node) -> Dictionary:
	var zn: Node2D = z as Node2D
	var mdir: Vector2 = z.call("_mouth_dir")
	if absf(mdir.x) < 0.5:
		return {}
	var md: float = 1.0 if mdir.x > 0.0 else -1.0
	var w: float = float(z.get("w"))
	var h: float = float(z.get("h"))
	var top: float = zn.global_position.y - h * 0.5
	var bottom: float = zn.global_position.y + h * 0.5
	var mx: float = float(z.get("net_mouth_x"))
	if is_nan(mx):
		mx = zn.global_position.x + md * (w * 0.5 - 20.0)   # = GoalZone's cage default
	var bx: float = float(z.get("net_back_x"))
	if is_nan(bx):
		bx = mx - md * Tuning.goal_net_depth_default
	var upper: StaticBody2D = null
	var lower: StaticBody2D = null
	var back: StaticBody2D = null
	var floor_top: float = INF
	var floor_h: float = 0.0
	var probe_x: float = mx + md * (Tuning.sports_pressure_apex_body_r + 16.0)
	for c in host.get_children():
		var body: StaticBody2D = c as StaticBody2D
		if body == null or body.is_queued_for_deletion():
			continue
		var r: Rect2 = _rect_of(body)
		if r.size == Vector2.ZERO:
			continue
		if body.has_meta("bumper"):
			var face: float = r.end.x if md > 0.0 else r.position.x
			if absf(face - mx) <= 3.0:
				if absf(r.end.y - top) <= 3.0:
					upper = body
				elif absf(r.position.y - bottom) <= 3.0:
					lower = body
			elif absf(face - bx) <= 3.0 and r.position.y <= top + 1.0 and r.end.y >= bottom - 1.0:
				back = body
		elif body.has_meta("bounce_tier_height") and probe_x >= r.position.x and probe_x <= r.end.x and r.position.y > bottom:
			if r.position.y < floor_top:
				floor_top = r.position.y
				floor_h = float(body.get_meta("bounce_tier_height"))
	if upper == null or lower == null or back == null:
		push_warning("WK-116: team %d mouth: upper=%s lower=%s back=%s" % [int(z.get("team")), upper != null, lower != null, back != null])
		return {}
	var ur: Rect2 = _rect_of(upper)
	var lr: Rect2 = _rect_of(lower)
	var apex: float = INF
	if floor_top < INF:
		apex = floor_top - Tuning.sports_pressure_apex_body_r - floor_h
	var max_up: float = maxf(0.0, (top - ur.position.y) - Tuning.sports_pressure_min_post_px)
	var max_down: float = maxf(0.0, (lr.end.y - bottom) - Tuning.sports_pressure_min_post_px)
	if apex < INF:
		max_down = minf(max_down, maxf(0.0, apex - bottom))
	var m := {
		"zone": z, "team": int(z.get("team")), "md": md, "mx": mx, "top0": top, "bottom0": bottom, "h0": h,
		"apex": apex, "max_up": max_up, "max_down": max_down,
		"upper": _capture_post(upper), "lower": _capture_post(lower), "back": _capture_back(back),
		"cur_up": 0.0, "cur_down": 0.0, "from_up": 0.0, "from_down": 0.0, "to_up": 0.0, "to_down": 0.0,
		"targets": {},
	}
	for s in [1, 2]:
		var frac: float = Tuning.sports_pressure_grow1_frac if s == 1 else Tuning.sports_pressure_grow2_frac
		m["targets"][s] = _split_growth(h * maxf(0.0, frac), max_up, max_down)
	return m

## Total growth g -> [up, down]: symmetric, the bottom edge capped by max_down (floor-bouncer apex / post length), the rest to
## the top edge (capped by max_up), and back again if the top is capped. Court JSON pressure_max_grow_px caps g.
func _split_growth(g: float, max_up: float, max_down: float) -> Array:
	if _override_px >= 0.0:
		g = minf(g, _override_px)
	var down: float = minf(g * 0.5, max_down)
	var up: float = minf(g - down, max_up)
	down = minf(g - up, max_down)
	return [up, down]

func _capture_post(body: StaticBody2D) -> Dictionary:
	var d := {"body": body, "pos0": body.position, "rect0": _rect_of(body), "sprites": [], "shadow": null, "shadow_pts": PackedVector2Array()}
	var root: Node = body.get_node_or_null("Art")
	if root == null:
		return d
	for n in root.find_children("*", "Sprite2D", true, false):
		var sp: Sprite2D = n as Sprite2D
		var off: float = body.to_local(sp.get_parent().global_position).y
		d["sprites"].append({"sp": sp, "y": sp.position.y + off, "off": off, "reg": sp.region_rect, "sy": sp.scale.y})
	if root.get_child_count() > 0 and root.get_child(0) is Polygon2D:
		var sh: Polygon2D = root.get_child(0) as Polygon2D
		d["shadow"] = sh
		d["shadow_pts"] = sh.polygon
	return d

func _capture_back(body: StaticBody2D) -> Dictionary:
	var cs: CollisionShape2D = null
	for c in body.get_children():
		if c is CollisionShape2D:
			cs = c as CollisionShape2D
			break
	var d := {"body": body, "cs": cs, "cs_pos0": cs.position if cs != null else Vector2.ZERO,
		"size0": (cs.shape as RectangleShape2D).size if cs != null and cs.shape is RectangleShape2D else Vector2.ZERO,
		"rect0": _rect_of(body), "dups": []}
	return d

# ------------------------------------------------------------------ rule tick

func _physics_process(_delta: float) -> void:
	if over or _ball == null or not is_instance_valid(_ball):
		return
	for m in _mouths:
		if is_instance_valid(m["zone"]) and bool((m["zone"] as Node).get("scored")):
			_finish("goal")
			return
	var t: float = float(_ball.call("ball_clock"))
	var want: int = _step_for(t)
	if want > step and _gates_open():
		for s in range(step + 1, want + 1):
			_enter_step(s, t)
	if _slide_t0 >= 0.0:
		var u: float = clampf((t - _slide_t0) / maxf(Tuning.sports_pressure_slide_s, 0.001), 0.0, 1.0)
		var e: float = 1.0 - (1.0 - u) * (1.0 - u)   # ease-out
		for m in _mouths:
			_apply(m, lerpf(float(m["from_up"]), float(m["to_up"]), e), lerpf(float(m["from_down"]), float(m["to_down"]), e))
		if u >= 1.0:
			_slide_t0 = -1.0
	if step >= 1:
		_probe()

func _step_for(t: float) -> int:
	if t >= Tuning.sports_pressure_t2_s:
		return 2
	if t >= Tuning.sports_pressure_t1_s:
		return 1
	if t >= Tuning.sports_pressure_t1_s - Tuning.sports_pressure_warn_s:
		return 0
	return -1

## Defence in depth: never while a WK-131 kickoff gate is still closed (INF = this stage has no gates).
func _gates_open() -> bool:
	if _mode == null or not _mode.has_method("gates_open_in"):
		return true
	var g: float = float(_mode.call("gates_open_in"))
	return g == INF or g <= 0.0

func _enter_step(s: int, t: float) -> void:
	step = s
	step_t[s] = t
	log_lines.append("step %d at ball_t %.3f" % [s, t])
	EventBus.sports_pressure.emit(s)
	if s == 0:
		return
	for m in _mouths:
		var tg: Array = (m["targets"] as Dictionary)[s]
		m["from_up"] = m["cur_up"]
		m["from_down"] = m["cur_down"]
		m["to_up"] = float(tg[0])
		m["to_down"] = float(tg[1])
		_extend_back_collider(m, float(tg[0]), float(tg[1]))
	_slide_t0 = t
	_chev_age = 0.0
	_chev_step = s
	_feedback(s)

## The goal latched: freeze everything where it is (the stage reload resets it) and release the crowd loops.
func _finish(why: String) -> void:
	over = true
	log_lines.append("over (%s)" % why)
	if step >= 0 and not _emitted_over:
		_emitted_over = true
		EventBus.sports_pressure.emit(-1)

func _exit_tree() -> void:
	if step >= 0 and not _emitted_over:
		_emitted_over = true
		EventBus.sports_pressure.emit(-1)

# ------------------------------------------------------------------ geometry application

## Mouth grown by `up` (top edge raised) and `down` (bottom edge lowered) from base.
func _apply(m: Dictionary, up: float, down: float) -> void:
	m["cur_up"] = up
	m["cur_down"] = down
	var top: float = float(m["top0"]) - up
	var bottom: float = float(m["bottom0"]) + down
	_move_post(m["upper"], -up, true)
	_move_post(m["lower"], down, false)
	if is_instance_valid(m["zone"]):
		(m["zone"] as Node).call("set_mouth_span", top, bottom)
	_telescope_back(m, top, bottom)

## Translate a post body by `dy` (into its housing) and crop its art at the housing face (body-local clip line), keeping the
## art's original end overhang (sports_pressure_art_bleed) so the joint with the ceiling / floor looks as before.
func _move_post(pd: Dictionary, dy: float, upper: bool) -> void:
	var body: StaticBody2D = pd["body"]
	if not is_instance_valid(body):
		return
	body.position = (pd["pos0"] as Vector2) + Vector2(0.0, dy)
	var d: float = absf(dy)
	var h0: float = (pd["rect0"] as Rect2).size.y
	var bleed: float = Tuning.sports_pressure_art_bleed
	var c: float = (d - h0 * 0.5 - bleed) if upper else (h0 * 0.5 + bleed - d)
	for e in pd["sprites"]:
		var sp: Sprite2D = e["sp"]
		if not is_instance_valid(sp):
			continue
		var reg: Rect2 = e["reg"]
		var sy: float = float(e["sy"])
		var y0: float = float(e["y"])
		var y1: float = y0 + reg.size.y * sy
		var off: float = float(e["off"])
		if d <= 0.0:
			sp.visible = true
			sp.region_rect = reg
			sp.position.y = y0 - off
			continue
		if upper:
			if y1 <= c:
				sp.visible = false
			elif y0 < c:
				var cut: float = (c - y0) / sy
				sp.visible = true
				sp.region_rect = Rect2(reg.position.x, reg.position.y + cut, reg.size.x, reg.size.y - cut)
				sp.position.y = c - off
			else:
				sp.visible = true
				sp.region_rect = reg
				sp.position.y = y0 - off
		else:
			if y0 >= c:
				sp.visible = false
			elif y1 > c:
				sp.visible = true
				sp.region_rect = Rect2(reg.position.x, reg.position.y, reg.size.x, (c - y0) / sy)
				sp.position.y = y0 - off
			else:
				sp.visible = true
				sp.region_rect = reg
				sp.position.y = y0 - off
	var sh: Polygon2D = pd["shadow"]
	if sh != null and is_instance_valid(sh):
		var pts: PackedVector2Array = pd["shadow_pts"]
		if d > 0.0:
			var out := PackedVector2Array()
			var cl: float = c - sh.position.y
			for p in pts:
				out.append(Vector2(p.x, maxf(p.y, cl) if upper else minf(p.y, cl)))
			sh.polygon = out
		else:
			sh.polygon = pts

## Back post COLLIDER: extended at the step tick to the final span (new mouth +- margin, never shorter than authored). The space
## it grows into is behind the post column, reachable only through the 60 px slot (narrower than any goat or the ball).
func _extend_back_collider(m: Dictionary, up: float, down: float) -> void:
	var bd: Dictionary = m["back"]
	var cs: CollisionShape2D = bd["cs"]
	if cs == null or not is_instance_valid(cs) or not (cs.shape is RectangleShape2D):
		return
	var r0: Rect2 = bd["rect0"]
	var mg: float = Tuning.sports_pressure_back_margin
	var t: float = minf(r0.position.y, float(m["top0"]) - up - mg)
	var b: float = maxf(r0.end.y, float(m["bottom0"]) + down + mg)
	var body: StaticBody2D = bd["body"]
	(cs.shape as RectangleShape2D).size = Vector2(r0.size.x, b - t)
	cs.position = Vector2((bd["cs_pos0"] as Vector2).x, (t + b) * 0.5 - body.global_position.y)

## Back post ART telescopes: two copies of its own art slide out from behind it (drawn first = behind), so the column reads as a
## telescoping post that always spans the live mouth +- margin.
func _telescope_back(m: Dictionary, top: float, bottom: float) -> void:
	var bd: Dictionary = m["back"]
	var body: StaticBody2D = bd["body"]
	if not is_instance_valid(body):
		return
	var r0: Rect2 = bd["rect0"]
	var mg: float = Tuning.sports_pressure_back_margin
	var ext_up: float = maxf(0.0, r0.position.y - (top - mg))
	var ext_down: float = maxf(0.0, (bottom + mg) - r0.end.y)
	var dups: Array = bd["dups"]
	if dups.is_empty():
		if ext_up <= 0.0 and ext_down <= 0.0:
			return
		var art: Node2D = body.get_node_or_null("Art") as Node2D
		if art == null:
			return
		for i in range(2):
			var dup: Node2D = art.duplicate() as Node2D
			dup.name = "PressureTele%d" % i
			if dup.get_child_count() > 0 and dup.get_child(0) is Polygon2D:
				(dup.get_child(0) as Polygon2D).visible = false   # one shadow only (no stacked alpha)
			body.add_child(dup)
			body.move_child(dup, art.get_index())   # before the original art: drawn behind it
			dups.append(dup)
	(dups[0] as Node2D).position.y = -ext_up
	(dups[1] as Node2D).position.y = ext_down

# ------------------------------------------------------------------ QA probes (M4 squash, G3 leak)

func _probe() -> void:
	var bodies: Array = []
	if _runner != null:
		for p in _runner.players:
			if is_instance_valid(p) and not (p.has_method("is_dead") and p.is_dead()):
				var pr: Variant = p.get("_radius")
				bodies.append([p, float(pr) if pr != null else 44.0])
	for b in get_tree().get_nodes_in_group("sports_ball"):
		if is_instance_valid(b):
			var br: Variant = b.get("radius")
			bodies.append([b, float(br) if br != null else 60.0])
	for m in _mouths:
		var top: float = float(m["top0"]) - float(m["cur_up"])
		var bottom: float = float(m["bottom0"]) + float(m["cur_down"])
		var md: float = float(m["md"])
		var mx: float = float(m["mx"])
		var posts: Array = []
		for key in ["upper", "lower"]:
			var body: StaticBody2D = (m[key] as Dictionary)["body"]
			if is_instance_valid(body):
				posts.append(_rect_of(body))
		for e in bodies:
			var pos: Vector2 = (e[0] as Node2D).global_position
			var r: float = float(e[1])
			if (pos.x - mx) * md < -1.0 and (pos.y < top - 1.0 or pos.y > bottom + 1.0):
				leak_ticks += 1
				if leak_ticks <= 20:
					log_lines.append("leak: %s at %s (team %d mouth %.0f..%.0f)" % [(e[0] as Node).name, pos, int(m["team"]), top, bottom])
			for pr2 in posts:
				var rr: Rect2 = pr2
				var q := Vector2(clampf(pos.x, rr.position.x, rr.end.x), clampf(pos.y, rr.position.y, rr.end.y))
				if q.distance_to(pos) < r - SQUASH_TOL:
					squash_ticks += 1
					if squash_ticks <= 20:
						log_lines.append("squash: %s at %s" % [(e[0] as Node).name, pos])

# ------------------------------------------------------------------ feedback (spec §5)

func _feedback(s: int) -> void:
	var hud = _runner.get("_hud") if _runner != null else null
	if hud != null and is_instance_valid(hud) and hud.has_method("show_pressure_word"):
		if s == 1:
			hud.call("show_pressure_word", "PRESSURE!", Tuning.sports_pressure_word1_color, Tuning.sports_pressure_word_hold, 0)
		else:
			hud.call("show_pressure_word", "MAX PRESSURE!", Tuning.sports_pressure_word2_color, Tuning.sports_pressure_word_hold,
				Tuning.sports_pressure_word2_size)
	var juice = _runner.get("_juice") if _runner != null else null
	if juice != null and is_instance_valid(juice) and juice.has_method("_shake"):
		juice.call("_shake", Tuning.sports_pressure_shake)   # x Options SCREEN SHAKE (OFF = none)
	_rumble_all()
	get_tree().create_timer(Tuning.sports_pressure_rumble_gap, false).timeout.connect(_rumble_all)

func _rumble_all() -> void:
	if not is_inside_tree():
		return
	for p in get_tree().get_nodes_in_group("human"):
		InputRouter.rumble_player(p, Tuning.sports_pressure_rumble_weak, Tuning.sports_pressure_rumble_strong,
			Tuning.sports_pressure_rumble_dur)

func _clock() -> float:
	if _ball != null and is_instance_valid(_ball):
		return float(_ball.call("ball_clock"))
	return 0.0

func _process(delta: float) -> void:
	if _mouths.is_empty() or step < 0:
		return
	var t: float = _clock()
	var trim := Color(1.0, 1.0, 1.0, 0.0)
	var heat := Color(1.0, 1.0, 1.0, 0.0)
	var a: float = Tuning.sports_pressure_trim_alpha
	if step == 0:
		var tau: float = maxf(0.0, t - float(step_t[0]))
		var p: float = 0.5 - 0.5 * cos(TAU * Tuning.sports_pressure_warn_hz * tau)
		trim = Tuning.sports_pressure_trim_warn_a.lerp(Tuning.sports_pressure_trim_warn_b, p)
		trim.a = a * clampf(tau / 0.4, 0.0, 1.0)
	elif step == 1:
		trim = Tuning.sports_pressure_trim_warn_b
		trim.a = a
	else:
		var tau2: float = maxf(0.0, t - float(step_t[2]))
		var p2: float = 0.5 - 0.5 * cos(TAU * Tuning.sports_pressure_hot_hz * tau2)
		trim = Tuning.sports_pressure_trim_hot_a.lerp(Tuning.sports_pressure_trim_hot_b, 0.45 * p2)
		trim.a = a * lerpf(0.8, 1.0, p2)
		var flick: float = 0.5 + 0.5 * sin(TAU * 7.3 * tau2) * sin(TAU * 2.1 * tau2 + 1.0)
		heat = Tuning.sports_pressure_trim_hot_b
		heat.a = Tuning.sports_pressure_heat_alpha * lerpf(0.55, 1.0, flick) * clampf(tau2 / 0.3, 0.0, 1.0)
	for m in _mouths:
		var z: Node = m["zone"]
		if not is_instance_valid(z):
			continue
		z.call("set_pressure_trim", trim)
		var art: Node = z.get_node_or_null("NetArt")
		if art != null and art.has_method("set_heat"):
			art.call("set_heat", heat)
	if _chev_age >= 0.0:
		_chev_age += delta
		if _chev_age > Tuning.sports_pressure_chevron_s:
			_chev_age = -1.0
		queue_redraw()

## Up / down chevrons on each post just outside the mouth edges, flashing for sports_pressure_chevron_s (house chevron look:
## colour fill, chocolate rim, soft drop shadow - src/ui/Chevron.gd).
func _draw() -> void:
	if _chev_age < 0.0:
		return
	var life: float = Tuning.sports_pressure_chevron_s
	var blink: float = 1.0 if fmod(_chev_age * 6.0, 1.0) < 0.6 else 0.45
	var fade: float = clampf((life - _chev_age) / 0.25, 0.0, 1.0)
	var fill: Color = Tuning.sports_pressure_trim_warn_b if _chev_step == 1 else Tuning.sports_pressure_trim_hot_a
	fill.a = blink * fade
	var cw: float = Tuning.sports_pressure_chevron_wpx
	var drift: float = 26.0 * clampf(_chev_age / life, 0.0, 1.0)
	for m in _mouths:
		var ur: Rect2 = (m["upper"] as Dictionary)["rect0"]
		var cx: float = ur.get_center().x
		var top: float = float(m["top0"]) - float(m["cur_up"])
		var bottom: float = float(m["bottom0"]) + float(m["cur_down"])
		for k in range(2):
			var gap: float = 52.0 + float(k) * cw * 0.55 + drift
			_chevron(Vector2(cx, top - gap), -1.0, cw, fill)
			_chevron(Vector2(cx, bottom + gap), 1.0, cw, fill)

func _chevron(c: Vector2, dir_y: float, cw: float, fill: Color) -> void:
	var hh: float = cw * 0.30                 # half height
	var th: float = cw * 0.26                 # arm thickness (vertical)
	var tip := Vector2(c.x, c.y + dir_y * hh)
	var pts := PackedVector2Array([
		Vector2(c.x - cw * 0.5, c.y - dir_y * hh), tip, Vector2(c.x + cw * 0.5, c.y - dir_y * hh),
		Vector2(c.x + cw * 0.5, c.y - dir_y * hh + dir_y * th), Vector2(c.x, tip.y + dir_y * th),
		Vector2(c.x - cw * 0.5, c.y - dir_y * hh + dir_y * th)])
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0.0, 5.0))
	draw_colored_polygon(sh, Color(0.0, 0.0, 0.0, 0.25 * fill.a))
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Color(CHOCO, fill.a), 5.0, true)

# ------------------------------------------------------------------ QA

## Spec §10.1 / §11 telemetry: step reached, step tick times, probes, live + target mouth spans per goal.
func stats() -> Dictionary:
	var ms: Array = []
	var inst: int = 0
	for m in _mouths:
		var z: Node = m["zone"]
		if is_instance_valid(z):
			inst += int(z.get("pressure_instant_goals"))
		ms.append({"team": m["team"], "top": float(m["top0"]) - float(m["cur_up"]),
			"bottom": float(m["bottom0"]) + float(m["cur_down"]), "h": float(m["h0"]) + float(m["cur_up"]) + float(m["cur_down"]),
			"h0": m["h0"], "apex": m["apex"], "max_up": m["max_up"], "max_down": m["max_down"],
			"targets": m["targets"]})
	return {"rule": rule, "step": step, "warn_t": step_t[0], "step1_t": step_t[1], "step2_t": step_t[2], "over": over,
		"disabled": disabled_reason, "leak_ticks": leak_ticks, "squash_ticks": squash_ticks, "instant_goals": inst,
		"mouths": ms, "log": log_lines.duplicate()}
