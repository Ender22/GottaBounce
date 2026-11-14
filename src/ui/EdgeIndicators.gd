extends Control
## Off-screen MAGNIFIER BUBBLES (BACKLOG WK-36 · audit D-05 / R-30; replaces the camera_2x_policy §3 chevrons).
## The owner camera rules (docs/feedback/owner_2026-07-10_camera_rules.md) let a goat beyond the level's camera
## bounds leave the frame — and that is exactly where the recovery (the owner's favourite moment) happens. Smash's
## answer, without moving the camera: every LIVING goat outside the frame is shown live in a bubble pinned to the
## screen edge in its direction:
##   - cream window with a live copy of the goat's CURRENT sprite frame (pose swap, facing, tumble/gravity
##     rotation, squash/stretch, hit flash / damage flush / Star rainbow — whatever the body is wearing right now)
##     plus a soft exhaust puff while its jetpack fires;
##   - goat-colour identity rim (PartyMatch.player_color, WK-08) inside a chocolate outline;
##   - fuel ring = get_fuel_ratio() (clockwise from 12 o'clock; red + pulsing when low, cyan under Unlimited Boost);
##   - pointer nub (the old chevron, folded in) whose tip aims at the goat's TRUE screen position;
##   - flashing aim arrow (fuse-coloured, like the in-world arrow) while is_super_aiming();
##   - size by distance past the frame: just off-screen = biggest, far out = smallest (never below min).
## Visibility (rendered QA): a bubble appears only once the goat's body is FULLY past the viewport edge (never on top
## of a half-visible goat) and drops only after bubble_hide_delay back in view (no flicker while grazing the edge).
## PlayerPips hides the pip while is_bubbled(), so a goat never shows both. A KO-blast victim gets no bubble (it is
## dead anyway; the recent-blast check also covers any respawn edge case).
##
## Presentation only (INV-12): polls the runner + reads the body's sprite nodes, writes nothing, never touches the
## camera. Sprite COPY (no SubViewport) for perf (WK-91): a handful of draw calls per visible bubble and NO redraw
## at all when no goat is off-screen. Code-drawn (dynamic count / rotation) under its own CanvasLayer (layer 0,
## below the pips, the KO blast and the HUD). px sizes in Tuning (bubble_*), authored at 1080p.

const OUTLINE := Color(0.231373, 0.141176, 0.105882, 1.0)   # theme.tres chocolate
const CREAM := Color(1.0, 0.968627, 0.921569, 1.0)          # theme cream (LobbySlot / chips)
const SHADOW := Color(0.117647, 0.066667, 0.035294, 0.3)     # theme card drop shadow
const GLOSS := Color(1.0, 1.0, 1.0, 0.45)
const PUFF_TEX := preload("res://assets/fx/puff_soft.png")
const ARC_PTS := 49              # full-circle arc resolution (chord error < 0.2 px at 150 px)
const BALL_ART_RADIUS := 1.1     # Player art: the round body is drawn 2.2 x _radius wide (Player._ready)
const FIRE_OUTER := Color(1.0, 0.55, 0.15, 0.9)
const FIRE_INNER := Color(1.0, 0.93, 0.62, 0.95)
const FIRE_CYAN := Color(0.35, 0.85, 1.0, 0.9)
const AIM_COLD := Color(1.0, 0.95, 0.35)   # Player fuse ramp (super aim arrow / ring)
const AIM_HOT := Color(1.0, 0.32, 0.12)

var _match                       # PartyMatch (read-only): players, _camera, state, player_color(i), _ko_blast
var _colors: Array = []          # setup-time fallback colours (player_color is read live when available)
## QA feed (gbplay eval `debug_state()`): this frame's bubbles, far -> near (draw order).
var bubbles: Array = []
var _seen: Dictionary = {}       # Player instance id -> usec its bubble appeared (real-time pop-in clock)
var _gone: Dictionary = {}       # Player instance id -> usec its bubble dropped (re-pop grace)
var _bubbled: Dictionary = {}    # Player instance id -> true while it has a bubble THIS frame (PlayerPips reads it)
var _last_out: Dictionary = {}   # Player instance id -> usec it was last fully out of view (hide-delay clock)
var _drawn_last := false

func setup(match_ref, colors: Array) -> void:
	_match = match_ref
	_colors = colors
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_dt: float) -> void:
	bubbles = _layout(Time.get_ticks_usec())
	var any: bool = not bubbles.is_empty()
	if any or _drawn_last:
		queue_redraw()   # perf: nothing off-screen -> no per-frame redraw at all
	_drawn_last = any

## Does this goat have a bubble this frame? PlayerPips hides the pip while it does (one cue at a time, including
## the bubble_hide_delay tail after the goat comes back into view).
func is_bubbled(p) -> bool:
	return p != null and is_instance_valid(p) and _bubbled.has(p.get_instance_id())

## QA readout: per visible bubble {player, edge, centre, radius, past_world, fuel, aiming, aim_dir, frame}.
func debug_state() -> Array:
	var out: Array = []
	for b in bubbles:
		var c: Vector2 = b["c"]
		var ad: Vector2 = b["aim"]
		out.append({"player": int(b["i"]), "edge": str(b["edge"]), "centre": [roundf(c.x), roundf(c.y)],
			"radius": snappedf(float(b["r"]) * float(b["pop"]), 0.1), "past_world": roundf(float(b["past"])),
			"fuel": snappedf(float(b["fuel"]), 0.001), "aiming": bool(b["aiming"]),
			"aim_dir": [snappedf(ad.x, 0.01), snappedf(ad.y, 0.01)], "frame": Engine.get_process_frames()})
	return out

# ------------------------------------------------------------------------------------------------ layout

func _layout(now_us: int) -> Array:
	var out: Array = []
	if _match == null or not is_instance_valid(_match) or (_match.state != "COMBAT" and _match.state != "SUDDEN_DEATH") 			or _match._camera == null or not is_instance_valid(_match._camera):
		_seen.clear()
		_gone.clear()
		_bubbled.clear()
		_last_out.clear()
		return out
	var cam = _match._camera
	var vp: Vector2 = get_viewport_rect().size
	var k: float = vp.y / Tuning.bubble_ref_height
	var cam_center: Vector2 = cam.get_screen_center_position()
	var z: float = cam.zoom.x
	# A bubble APPEARS only once the goat's body is fully past the viewport edge (a 150 px bubble must never sit on
	# top of a half-visible goat) and DROPS only after the goat has been back in view for bubble_hide_delay (no
	# flicker while it grazes the edge). PlayerPips hides the pip while is_bubbled(); between the pip frame
	# (inset 40) and "fully out" the goat itself is the cue.
	var view := Rect2(Vector2.ZERO, vp)
	var hide_us: int = int(Tuning.bubble_hide_delay * 1000000.0)
	var players: Array = _match.players
	var live: Dictionary = {}
	for i in range(players.size()):
		var p = players[i]
		if not is_instance_valid(p) or p.is_dead() or not p.is_visible_in_tree():
			continue
		var sp: Vector2 = (p.global_position - cam_center) * z + vp * 0.5
		var id: int = p.get_instance_id()
		var rv: Variant = p.get("_radius")
		var body_px: float = BALL_ART_RADIUS * (float(rv) if rv != null else 44.0) * z + 4.0
		if not view.grow(body_px).has_point(sp):
			_last_out[id] = now_us
		elif not _bubbled.has(id) or now_us - int(_last_out.get(id, 0)) > hide_us:
			continue   # (back) in view: the goat itself / its pip is the cue
		if _ko_blasting(i):
			continue
		live[id] = true
		if not _seen.has(id):
			# a goat that bobbed back in and straight out again (within the grace) shows at full size, no re-pop
			var back: bool = _gone.has(id) and float(now_us - int(_gone[id])) / 1000000.0 < Tuning.bubble_repop_grace
			_seen[id] = now_us - (int(Tuning.bubble_pop_time * 1000000.0) if back else 0)
		_gone.erase(id)
		var past: float = (sp - sp.clamp(Vector2.ZERO, vp)).length() / maxf(z, 0.01)
		var r: float = radius_for(past, k)
		var pop: float = pop_scale(float(now_us - int(_seen[id])) / 1000000.0)
		var edge: String = pick_edge(sp, vp)
		var aiming: bool = p.is_super_aiming()
		var ad: Vector2 = p.get_super_aim_dir() if aiming else Vector2.ZERO
		out.append({"i": i, "p": p, "sp": sp, "edge": edge, "r": r, "pop": pop, "past": past,
			"c": pin(sp, vp, edge, r, k), "fuel": p.get_fuel_ratio(), "locked": bool(p.get("fuel_locked")),
			"aiming": aiming, "aim": ad})
	for id in _seen.keys():
		if not live.has(id):
			_seen.erase(id)   # back on screen: the next exit pops in again (after the grace)
			_gone[id] = now_us
	_bubbled = live
	separate(out, vp, k)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["r"]) < float(b["r"]))
	return out

## The KO blast owns a victim's edge for its lifetime: no bubble for that player meanwhile.
func _ko_blasting(i: int) -> bool:
	var kb = _match.get("_ko_blast")
	if kb == null or not is_instance_valid(kb):
		return false
	var arr: Variant = kb.get("blasts")
	if not (arr is Array):
		return false
	var now_ms: int = Time.get_ticks_msec()
	var span: int = int(Tuning.ko_blast_duration * 1000.0) + 50
	for e in (arr as Array):
		if e is Dictionary and int(e.get("victim", -1)) == i and now_ms - int(e.get("msec", 0)) < span:
			return true
	return false

## Bubble radius (screen px) for a goat `past_world` world px outside the viewport: closer = bigger.
static func radius_for(past_world: float, k: float) -> float:
	var t: float = clampf(past_world / maxf(Tuning.bubble_far_world_px, 1.0), 0.0, 1.0)
	return lerpf(Tuning.bubble_radius_max_px, Tuning.bubble_radius_min_px, t) * k

## Pop-in scale at `t` s after the bubble appeared (back-out overshoot, then exactly 1).
static func pop_scale(t: float) -> float:
	var d: float = maxf(Tuning.bubble_pop_time, 0.001)
	if t >= d:
		return 1.0
	var u: float = clampf(t / d, 0.0, 1.0) - 1.0
	var e: float = 1.0 + 2.70158 * u * u * u + 1.70158 * u * u
	return lerpf(0.55, 1.0, e)

## Which screen edge the bubble pins to: the edge with the largest overshoot (KOEdgeBlast.classify's rule).
static func pick_edge(sp: Vector2, vp: Vector2) -> String:
	var out_l: float = -sp.x
	var out_r: float = sp.x - vp.x
	var out_t: float = -sp.y
	var out_b: float = sp.y - vp.y
	var m: float = maxf(maxf(out_l, out_r), maxf(out_t, out_b))
	if m == out_t:
		return "top"
	if m == out_b:
		return "bottom"
	if m == out_l:
		return "left"
	return "right"

## Bubble centre for a goat at screen point `sp` on `edge`: rim `bubble_edge_gap_px` inside that edge, the
## along-edge coordinate follows the goat but stays clear of the HUD corner cards (corner keep-outs).
static func pin(sp: Vector2, vp: Vector2, edge: String, r: float, k: float) -> Vector2:
	var d: float = r + Tuning.bubble_edge_gap_px * k
	var kx: float = Tuning.bubble_corner_keepout_x_px * k + r
	var ky: float = Tuning.bubble_corner_keepout_y_px * k + r
	match edge:
		"top":
			return Vector2(_span_clamp(sp.x, kx, vp.x - kx), d)
		"bottom":
			return Vector2(_span_clamp(sp.x, kx, vp.x - kx), vp.y - d)
		"left":
			return Vector2(d, _span_clamp(sp.y, ky, vp.y - ky))
	return Vector2(vp.x - d, _span_clamp(sp.y, ky, vp.y - ky))

static func _span_clamp(v: float, lo: float, hi: float) -> float:
	if lo > hi:
		return (lo + hi) * 0.5   # tiny viewport: centre of the edge
	return clampf(v, lo, hi)

## Push overlapping bubbles apart along their edge (a few relaxation passes; each stays pinned to its edge).
static func separate(list: Array, vp: Vector2, k: float) -> void:
	for _pass in range(4):
		var moved := false
		for a in range(list.size()):
			for b in range(a + 1, list.size()):
				var ba: Dictionary = list[a]
				var bb: Dictionary = list[b]
				var ca: Vector2 = ba["c"]
				var cb: Vector2 = bb["c"]
				var need: float = float(ba["r"]) + float(bb["r"]) + Tuning.bubble_separation_px * k
				var dlt: Vector2 = cb - ca
				var dist: float = dlt.length()
				if dist >= need:
					continue
				var dir: Vector2 = dlt / dist if dist > 0.001 else _tangent(str(ba["edge"]))
				if str(ba["edge"]) == str(bb["edge"]):
					# same edge: push along the edge in the GOATS' order, so bubble order always matches goat order
					# (rendered QA: 3 goats clustered off the top came out shuffled by player index)
					var tg: Vector2 = _tangent(str(ba["edge"]))
					var sa: Vector2 = ba["sp"]
					var sb: Vector2 = bb["sp"]
					var order: float = (sb - sa).dot(tg)
					dir = tg if order > 0.0 else (-tg if order < 0.0 else (tg if dlt.dot(tg) >= 0.0 else -tg))
				var push: float = (need - dist) * 0.5
				ba["c"] = pin(ca - dir * push, vp, str(ba["edge"]), float(ba["r"]), k)
				bb["c"] = pin(cb + dir * push, vp, str(bb["edge"]), float(bb["r"]), k)
				moved = true
		if not moved:
			return

static func _tangent(edge: String) -> Vector2:
	return Vector2.RIGHT if edge == "top" or edge == "bottom" else Vector2.DOWN

# ------------------------------------------------------------------------------------------------ drawing

func _draw() -> void:
	if bubbles.is_empty() or _match == null or not is_instance_valid(_match):
		return
	var k: float = get_viewport_rect().size.y / Tuning.bubble_ref_height
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	for b in bubbles:
		if is_instance_valid(b["p"]):
			_draw_bubble(b, k, t)

func _draw_bubble(b: Dictionary, k: float, t: float) -> void:
	var p = b["p"]
	var i: int = b["i"]
	var col: Color = _colors[i] if i < _colors.size() else Color.WHITE
	if _match.has_method("player_color"):
		col = _match.player_color(i)   # WK-08: the skin actually worn
	var c: Vector2 = b["c"]
	var r: float = float(b["r"]) * float(b["pop"])
	var rs: float = r / maxf(Tuning.bubble_radius_max_px * k, 0.001)   # uniform scale: bands shrink with the bubble
	var ow: float = Tuning.bubble_outline_px * k * rs
	var rim: float = Tuning.bubble_rim_px * k * rs
	var gap: float = Tuning.bubble_band_gap_px * k * rs
	var fw: float = Tuning.bubble_fuel_px * k * rs
	var inner: float = r - (ow + rim + gap + fw + gap)   # cream window radius
	var sp: Vector2 = b["sp"]
	var dir: Vector2 = sp - c
	dir = dir.normalized() if dir.length() > 0.001 else Vector2.UP
	var a0: float = dir.angle()   # arc seams sit under the pointer join

	# 1) soft drop shadow + pointer nub (the old chevron; its base hides under the frame band)
	draw_circle(c + Vector2(0.0, 4.0 * k * rs), r + 1.0, SHADOW)
	var tip: Vector2 = c + dir * (r + Tuning.bubble_pointer_px * k * rs)
	var perp: Vector2 = dir.orthogonal()
	var nub := PackedVector2Array([tip, c + dir * (r * 0.80) + perp * (r * 0.42), c + dir * (r * 0.80) - perp * (r * 0.42)])
	draw_colored_polygon(nub, col)
	draw_colored_polygon(PackedVector2Array([nub[0], nub[1], (nub[1] + nub[2]) * 0.5]), Color(1.0, 1.0, 1.0, 0.22))
	var nub_loop := nub.duplicate()
	nub_loop.append(nub[0])
	draw_polyline(nub_loop, OUTLINE, ow, true)

	# 2) cream window + the live goat (drawn BEFORE the frame bands so any jetpack overhang tucks under them)
	draw_circle(c, inner + 1.0, CREAM)
	_draw_goat(p, c, inner, t, bool(b["locked"]))

	# 3) chocolate frame band, goat-colour rim, fuel ring
	draw_arc(c, (inner + r) * 0.5, a0, a0 + TAU, ARC_PTS, OUTLINE, r - inner, true)
	var rim_r: float = r - ow - rim * 0.5
	draw_arc(c, rim_r, a0, a0 + TAU, ARC_PTS, col, rim, true)
	draw_arc(c, rim_r, deg_to_rad(200.0), deg_to_rad(252.0), 12, GLOSS, maxf(1.5, rim * 0.35), true)
	var fuel_r: float = r - ow - rim - gap - fw * 0.5
	draw_arc(c, fuel_r, a0, a0 + TAU, ARC_PTS, Tuning.bubble_fuel_track, fw, true)
	var fuel: float = clampf(float(b["fuel"]), 0.0, 1.0)
	if fuel > 0.005:
		var fcol: Color = fuel_color_for(col)
		if bool(b["locked"]):
			fcol = Tuning.bubble_fuel_locked_color
		elif fuel < Tuning.bubble_fuel_low:
			var pulse: float = 0.5 + 0.5 * sin(t * TAU * Tuning.bubble_fuel_low_hz)
			fcol = Tuning.bubble_fuel_low_color.lerp(Color.WHITE, 0.35 * pulse)
		var n: int = maxi(3, int(ceil(float(ARC_PTS) * fuel)) + 1)
		draw_arc(c, fuel_r, -PI * 0.5, -PI * 0.5 + TAU * fuel, n, fcol, fw, true)

	# 4) super-aim arrow (flashing, fuse-coloured), on top of everything — reads within the frame aim starts
	if bool(b["aiming"]):
		var ad: Vector2 = b["aim"]
		ad = ad.normalized() if ad.length() > 0.001 else Vector2.UP
		var at: Variant = p.get("_sb_aim_t")
		var fuse: float = clampf((float(at) if at != null else 0.0) / maxf(Tuning.super_aim_max, 0.01), 0.0, 1.0)
		var flash: float = 0.5 + 0.5 * sin(t * TAU * Tuning.bubble_aim_flash_hz)
		_draw_aim_arrow(c, ad, r, AIM_COLD.lerp(AIM_HOT, fuse).lerp(Color.WHITE, 0.55 * flash), ow)

## Normal fuel-arc colour for a goat whose rim is `rim`: jetpack gold, unless the rim is itself gold-ish (yellow /
## orange skins — rendered QA: rim + fuel merged into one band), then the cream-white alternate.
static func fuel_color_for(rim: Color) -> Color:
	var gold: Color = Tuning.bubble_fuel_color
	var dh: float = absf(rim.h - gold.h)
	dh = minf(dh, 1.0 - dh)
	if rim.s > 0.35 and dh < Tuning.bubble_fuel_hue_clash:
		return Tuning.bubble_fuel_alt_color
	return gold

## A copy of the goat's current sprite frame: same texture/pose, facing, body rotation (tumble / gravity) and
## squash as the in-world body, scaled so its BALL fills bubble_goat_fill of the window. Plus the damage flush
## overlay and a soft exhaust puff at the nozzle while the jetpack fires.
func _draw_goat(p, c: Vector2, inner: float, t: float, locked: bool) -> void:
	var spr: Sprite2D = p.get("_sprite") as Sprite2D
	var body: Node2D = p.get("_body") as Node2D
	var flip: Node2D = p.get("_skin_flip") as Node2D
	if spr == null or spr.texture == null or body == null or flip == null:
		return
	var rv: Variant = p.get("_radius")
	var pr: float = float(rv) if rv != null else 44.0
	var kg: float = inner * Tuning.bubble_goat_fill / maxf(BALL_ART_RADIUS * pr, 1.0)
	var alpha: float = (p as CanvasItem).modulate.a   # spawn-protection blink
	# exhaust puff (behind the goat): fire.position is the nozzle in player-local, un-rotated space
	var fire: CPUParticles2D = p.get("_fire") as CPUParticles2D
	if fire != null and fire.emitting:
		var fdir: Vector2 = fire.direction.normalized() if fire.direction.length() > 0.001 else Vector2.DOWN
		var fpos: Vector2 = c + (fire.position + fdir * 26.0) * kg
		var fsz: float = inner * 0.62 * clampf(fire.scale.x, 0.7, 1.8) * (0.9 + 0.1 * sin(t * 40.0))
		var outer_col: Color = (FIRE_CYAN if locked else FIRE_OUTER) * fire.modulate
		draw_texture_rect(PUFF_TEX, Rect2(fpos - Vector2(fsz, fsz) * 0.5, Vector2(fsz, fsz)), false,
			Color(outer_col.r, outer_col.g, outer_col.b, outer_col.a * alpha))
		var isz: float = fsz * 0.5
		var ipos: Vector2 = fpos - fdir * fsz * 0.12
		draw_texture_rect(PUFF_TEX, Rect2(ipos - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false,
			Color(FIRE_INNER.r, FIRE_INNER.g, FIRE_INNER.b, FIRE_INNER.a * alpha))
	var base := Transform2D(0.0, Vector2(kg, kg), 0.0, c) * body.transform * flip.transform
	var tint: Color = spr.self_modulate
	tint.a *= alpha
	draw_set_transform_matrix(base * spr.transform)
	draw_texture(spr.texture, spr.offset - spr.texture.get_size() * 0.5, tint)
	var ov: Sprite2D = p.get("_dmg_overlay") as Sprite2D
	if ov != null and ov.visible and ov.texture != null:
		var otint: Color = ov.modulate
		otint.a *= alpha
		draw_set_transform_matrix(base * ov.transform)
		draw_texture(ov.texture, ov.offset - ov.texture.get_size() * 0.5, otint)
	draw_set_transform_matrix(Transform2D())

## Chunky arrow from inside the window out past the rim along `ad`, chocolate outline.
func _draw_aim_arrow(c: Vector2, ad: Vector2, r: float, col: Color, ow: float) -> void:
	var tip: float = Tuning.bubble_aim_tip * r
	var tail: float = 0.22 * r
	var hb: float = tip - 0.34 * r   # head base
	var sw: float = 0.10 * r         # shaft half-width
	var hw: float = 0.26 * r         # head half-width
	var local := PackedVector2Array([Vector2(tail, -sw), Vector2(hb, -sw), Vector2(hb, -hw), Vector2(tip, 0.0),
		Vector2(hb, hw), Vector2(hb, sw), Vector2(tail, sw)])
	var tf := Transform2D(ad.angle(), c)
	var pts := PackedVector2Array()
	for pt in local:
		pts.append(tf * pt)
	draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, OUTLINE, ow, true)
