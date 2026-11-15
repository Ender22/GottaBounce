extends Node2D
## WK-66a sports nets (docs/briefs/sports_nets_2026-11-15.md). DISPLAY ONLY: never touches a collider, the
## goal latch or the ball. Loaded by path (no class_name): ArenaRenderer / MovingPlatform / GoalZone do
## `preload("res://src/systems/SportsNetArt.gd").new()` then call setup_dropshot() or setup_goal().
##
## DROPSHOT net (BEACH / CORAL COVE / DOME): a toy volleyball set squeezed front-on. Vertical 3-slice frame
## (net_dropshot_frame.png: knobs + fat top tape, slim posts, hem + feet) over the shared rope mesh tile.
## Parented to the net collider (static bumper column or the DOME MovingPlatform) with the origin at the
## collider centre. z 4 absolute (under DropTile 5, so the floor hides the feet); nothing is drawn below the
## floor line (clip_y, from the drop tiles under the net). DOME: when the under-gap >= dome_gap_glow_min the
## hem lights up (additive cyan hem + floor light pool), fading over dome_gap_fade.
##
## GOAL net (Rocketball): side-view cage mounted in the wall gap. Back layer (mesh + team veil z -2, frame
## z -1) sits under the wall art (z 0) so the wall caps and back post overlap the tube ends; a cords-only
## front veil (z 42) sits over the ball (z 40). Built by GoalZone with the origin at the zone centre.
##
## Motion: one shader (assets/shaders/net_mesh.gdshader) on the mesh only; frames stay rigid.
##   on_contact(world_pos, speed, is_player) -> ripple (ball via Ball's contact report, goats via
##   EventBus.surface_bounced in ArenaRenderer). Goal score -> bulge (polls the zone's existing latch).

const MESH_TEX: Texture2D = preload("res://assets/world/sports/net_mesh.png")
const DROP_FRAME_TEX: Texture2D = preload("res://assets/world/sports/net_dropshot_frame.png")
const GOAL_FRAME_TEX: Texture2D = preload("res://assets/world/sports/goal_frame.png")
const PUFF_TEX: Texture2D = preload("res://assets/fx/puff_soft.png")
const MESH_SHADER: Shader = preload("res://assets/shaders/net_mesh.gdshader")
const FRAME_SHADER: Shader = preload("res://assets/shaders/net_frame.gdshader")

# --- art facts measured at intake (assets/CATALOG.md rows; source px of the committed PNGs) ---
const DROP_CAP_FRAC := 0.23          # top cap holds knobs + tape, bottom cap holds hem + feet
const DROP_TAPE_TOP_SRC := 83.0      # tape top outline row
const DROP_TAPE_MID_SRC := 117.0     # tape centre row (mesh starts here, hidden under the tape)
const DROP_TAPE_BOTTOM_SRC := 150.0  # tape bottom outline row (centre-column alpha ends here; AD F1)
const DROP_HEM_MID_FROM_BOTTOM := 38.0     # hem centre row, measured up from the image bottom
const DROP_HEM_BOTTOM_FROM_BOTTOM := 24.0  # hem bottom outline row, measured up from the image bottom
const DROP_HEM_TOP_FROM_BOTTOM := 52.0     # hem top outline row, measured up from the image bottom
const DROP_POST_C_SRC := 123.5       # post centre offset from the frame centre (src px)
const GOAL_CAP_FRAC := 0.13          # elbows / caps end at ~11 % top and bottom
const GOAL_TUBE_C_SRC := 91.0        # top/bottom tube centre row, from the image top/bottom edge
const GOAL_BACK_C_SRC := 76.0        # back tube centre column, from the image left edge
const MAX_RIPPLES := 4
const Z_DROPSHOT := 4
const Z_DOME_GLOW := 6
const Z_GOAL_MESH := -2
const Z_GOAL_FRAME := -1
const Z_GOAL_FRONT := 42

## A quad that only exists to carry the mesh shader (the shader samples the tile itself).
class MeshQuad:
	extends Node2D
	var rect: Rect2 = Rect2()
	func _draw() -> void:
		draw_rect(rect, Color.WHITE, true)

var kind: String = ""                 # "dropshot" | "goal"
var team: int = 0
var zone: Node = null                 # GOAL: the GoalZone whose `scored` latch drives the bulge
var _frame: Node2D
var _frame_mat: ShaderMaterial
var _tape: Sprite2D                   # AD F1: the enlarged knobs+tape band (replaces the hidden top cap)
var _tape_y: float = 0.0
var _mesh: MeshQuad
var _mesh_mat: ShaderMaterial
var _front: MeshQuad
var _front_mat: ShaderMaterial
var _interior: Rect2 = Rect2()        # local frame interior (mesh mask)
var _ripples: Array = []              # [{ "y": local y, "age": s, "amp": signed px }]
var _ripple_cd: float = 0.0
var _dip_t: float = -1.0
var _bulge_t: float = -1.0
var _bulge_c: Vector2 = Vector2.ZERO
var _bulge_dir: Vector2 = Vector2.LEFT
var _flash_t: float = -1.0
var _was_scored: bool = false
var _team_col: Color = Color.WHITE
var _frame_rect_local: Rect2 = Rect2()   # GOAL: frame bounds (near-miss contact filter)
# DROPSHOT geometry (local, origin = collider centre)
var _cw: float = 30.0
var _ch: float = 490.0
var _hem_y: float = 0.0               # local y of the hem centre
var _floor_y: float = INF             # world y of the floor top under the net (from the drop tiles)
var _floor_tries: int = 0             # the tiles may join the tree after the net: retry for a few frames
var _glow_a: float = 0.0
var _glow_t: float = 0.0
var _hem_glow: Node2D
var _pool: Sprite2D

# ============================================================== DROPSHOT

## Dropshot volleyball set for a `cw` x `ch` collider centred on this node. `tint` = per-court modulate.
func setup_dropshot(cw: float, ch: float, tint: Color) -> void:
	kind = "dropshot"
	_cw = cw
	_ch = ch
	z_as_relative = false
	z_index = Z_DROPSHOT
	var draw_w: float = Tuning.net_dropshot_draw_w
	var src: Vector2 = DROP_FRAME_TEX.get_size()
	var s: float = draw_w / src.x
	var tape_top: float = -ch * 0.5 - Tuning.net_tape_rise
	var img_top: float = tape_top - DROP_TAPE_TOP_SRC * s
	var img_bot: float = ch * 0.5 + DROP_HEM_BOTTOM_FROM_BOTTOM * s   # hem bottom edge on the collider bottom (floor line)
	var vis_h: float = img_bot - img_top
	_hem_y = img_bot - DROP_HEM_MID_FROM_BOTTOM * s
	var post_x: float = DROP_POST_C_SRC * s
	var mesh_top: float = img_top + DROP_TAPE_MID_SRC * s
	_interior = Rect2(-post_x, mesh_top, 2.0 * post_x, _hem_y - mesh_top)

	_mesh_mat = _make_mesh_mat(Color(1.0, 1.0, 1.0, Tuning.net_veil_alpha), 1.0)
	_mesh_mat.set_shader_parameter("tile_wpx", Tuning.net_dropshot_tile_wpx)   # AD F2: finer than the goals (no 2-diamond truss)
	_mesh = _make_quad(_mesh_mat, Z_DROPSHOT)
	_mesh.modulate = tint
	add_child(_mesh)

	_frame_mat = ShaderMaterial.new()
	_frame_mat.shader = FRAME_SHADER
	_frame_mat.set_shader_parameter("tint_mode", 0)
	_frame = ThreeSlice.build(DROP_FRAME_TEX, draw_w, vis_h, DROP_CAP_FRAC, true, tint)
	_frame.position = Vector2(0.0, (img_top + img_bot) * 0.5)
	_apply_frame_mat(_frame)
	add_child(_frame)
	# AD F1 (docs/audit/2026-11-15_wk66a_artgrade.md): the art's tape is ~60 % of the briefed height, so the
	# knobs+tape band is redrawn net_tape_scale x bigger (UNIFORM scale, never a stretch) as its own sprite,
	# anchored on the tape centre row, and the 3-slice top cap is hidden (the body tiles already run 2 px under
	# it). The wide "T" is what makes the column read as a net, not a mast. Top cap = the second-to-last
	# segment (ThreeSlice lists tiles first, then top cap, bottom cap).
	var n: int = _frame.get_child_count()
	if n >= 2:
		var top_cap: Sprite2D = _frame.get_child(n - 2) as Sprite2D
		if top_cap != null:
			top_cap.visible = false
	var band_h: float = DROP_TAPE_BOTTOM_SRC + 2.0
	var k: float = s * Tuning.net_tape_scale
	_tape = Sprite2D.new()
	_tape.texture = DROP_FRAME_TEX
	_tape.region_enabled = true
	_tape.region_rect = Rect2(0.0, 0.0, src.x, band_h)
	_tape.scale = Vector2(k, k)
	_tape.material = _frame_mat      # court tint + DOME floor clip
	_tape.modulate = tint
	_tape_y = (img_top + DROP_TAPE_MID_SRC * s) - (DROP_TAPE_MID_SRC - band_h * 0.5) * k
	_tape.position = Vector2(0.0, _tape_y)
	add_child(_tape)                 # after _frame -> draws on top

	# DOME gap cue: cyan-lit hem (the hem rows of the frame art, re-drawn tinted) + additive halo + floor pool.
	_hem_glow = Node2D.new()
	_hem_glow.z_as_relative = false
	_hem_glow.z_index = Z_DOME_GLOW
	_hem_glow.position = Vector2(0.0, _hem_y)
	_hem_glow.modulate = Color(Tuning.dome_gap_glow_color, 0.0)
	_hem_glow.visible = false
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo := Sprite2D.new()
	halo.texture = PUFF_TEX
	halo.material = add_mat
	halo.scale = Vector2((draw_w + 110.0) / PUFF_TEX.get_width(), 70.0 / PUFF_TEX.get_height())
	_hem_glow.add_child(halo)
	var hem := Sprite2D.new()
	hem.texture = DROP_FRAME_TEX
	hem.region_enabled = true
	var hem_top_src: float = src.y - DROP_HEM_TOP_FROM_BOTTOM - 4.0
	var hem_h_src: float = (DROP_HEM_TOP_FROM_BOTTOM - DROP_HEM_BOTTOM_FROM_BOTTOM) + 8.0
	hem.region_rect = Rect2(0.0, hem_top_src, src.x, hem_h_src)
	hem.scale = Vector2(s, s)
	hem.position = Vector2(0.0, (hem_top_src + hem_h_src * 0.5 - (src.y - DROP_HEM_MID_FROM_BOTTOM)) * s)
	# the hem itself turns cyan (fx_tint-style gradient map: outline + gloss survive); additive on a white
	# hem would add nothing visible
	var hem_mat := ShaderMaterial.new()
	hem_mat.shader = FRAME_SHADER
	hem_mat.set_shader_parameter("tint_mode", 1)
	hem.material = hem_mat
	_hem_glow.add_child(hem)
	add_child(_hem_glow)
	_pool = Sprite2D.new()
	_pool.texture = PUFF_TEX
	_pool.top_level = true
	_pool.z_as_relative = false
	_pool.z_index = Z_DOME_GLOW
	_pool.material = null            # AD F3: NORMAL blend (additive cyan on beige tiles added ~nothing); halo stays additive
	_pool.scale = Tuning.dome_gap_pool_size / PUFF_TEX.get_size()
	_pool.modulate = Color(Tuning.dome_gap_glow_color, 0.0)
	_pool.visible = false
	add_child(_pool)
	_find_floor.call_deferred()

## Floor top under the net = the highest drop-tile top overlapping the net's x (tiles are built after the
## net in the court JSON, hence deferred). No tiles -> no clip and no gap cue.
func _find_floor() -> void:
	if not is_inside_tree():
		return
	var gx: float = global_position.x
	var half: float = Tuning.net_dropshot_draw_w * 0.5
	var best: float = INF
	for t in get_tree().get_nodes_in_group("drop_tile"):
		var n2: Node2D = t as Node2D
		if n2 == null:
			continue
		var tw: float = float(n2.get("w"))
		var th: float = float(n2.get("h"))
		if absf(n2.global_position.x - gx) <= tw * 0.5 + half:
			best = minf(best, n2.global_position.y - th * 0.5)
	_floor_y = best
	var cy: float = best if best < INF else 1.0e9
	_mesh_mat.set_shader_parameter("clip_y", cy)
	_frame_mat.set_shader_parameter("clip_y", cy)

# ============================================================== GOAL

## Rocketball cage for GoalZone `gz` (this node sits at the zone centre). `mouth_x` / `back_x` are WORLD x
## of the court-side wall face and the back post inner face; `mouth_dir` = +1 mouth faces right (team 0).
func setup_goal(gz: Node, zone_h: float, mouth_x: float, back_x: float, mouth_dir: float, team_col: Color) -> void:
	kind = "goal"
	zone = gz
	_team_col = team_col
	var origin_x: float = (gz as Node2D).global_position.x
	var md: float = 1.0 if mouth_dir >= 0.0 else -1.0
	var outer_back: float = back_x - md * Tuning.goal_frame_back_tuck - origin_x
	var outer_mouth: float = mouth_x + md * Tuning.goal_frame_mouth_bleed - origin_x
	var frame_w: float = absf(outer_mouth - outer_back)
	var src: Vector2 = GOAL_FRAME_TEX.get_size()
	var s: float = frame_w / src.x
	var frame_h: float = zone_h + 2.0 * GOAL_TUBE_C_SRC * s   # tube centres land on the mouth edges
	var cx: float = (outer_back + outer_mouth) * 0.5
	_frame_rect_local = Rect2(minf(outer_back, outer_mouth), -frame_h * 0.5, frame_w, frame_h)
	var back_c: float = outer_back + md * GOAL_BACK_C_SRC * s
	var mx: float = mouth_x - origin_x
	_interior = Rect2(minf(back_c, mx), -zone_h * 0.5, absf(mx - back_c), zone_h)
	_bulge_dir = Vector2(-md, 0.0)

	var mesh_col: Color = team_col.lerp(Color.WHITE, Tuning.goal_mesh_white_mix)
	mesh_col.a = Tuning.goal_mesh_alpha
	_mesh_mat = _make_mesh_mat(Color(team_col, Tuning.goal_veil_alpha), 0.0)
	_mesh = _make_quad(_mesh_mat, Z_GOAL_MESH)
	_mesh.modulate = mesh_col
	add_child(_mesh)
	_front_mat = _make_mesh_mat(Color(team_col, 0.0), 0.0)
	_front = _make_quad(_front_mat, Z_GOAL_FRONT)
	_front.modulate = Color(mesh_col, Tuning.goal_front_veil_alpha)
	add_child(_front)

	_frame_mat = ShaderMaterial.new()
	_frame_mat.shader = FRAME_SHADER
	_frame_mat.set_shader_parameter("tint_mode", 1)
	_frame = ThreeSlice.build(GOAL_FRAME_TEX, frame_w, frame_h, GOAL_CAP_FRAC, true)
	_frame.position = Vector2(cx, 0.0)
	if md < 0.0:
		_frame.scale = Vector2(-1.0, 1.0)   # team 1: mirrored (art lit from directly above)
	_frame.z_as_relative = false
	_frame.z_index = Z_GOAL_FRAME
	_frame.modulate = team_col
	_apply_frame_mat(_frame)
	add_child(_frame)
	_tag_goal_colliders.call_deferred()

## Near-miss feed: tag the bumper colliders the cage is mounted in (back post, wall column caps) so the
## ball's contact report reaches this net. Meta only — the colliders are untouched.
func _tag_goal_colliders() -> void:
	if not is_inside_tree() or zone == null:
		return
	var host: Node = (zone as Node).get_parent()
	if host == null:
		return
	var fr := Rect2(to_global(_frame_rect_local.position), _frame_rect_local.size).grow(10.0)
	for c in host.get_children():
		var body: StaticBody2D = c as StaticBody2D
		if body == null or not body.has_meta("bumper") or body.has_meta("net_fx"):
			continue
		for sc in body.get_children():
			var cs: CollisionShape2D = sc as CollisionShape2D
			if cs == null or not (cs.shape is RectangleShape2D):
				continue
			var sz: Vector2 = (cs.shape as RectangleShape2D).size
			var r := Rect2(body.global_position + cs.position - sz * 0.5, sz)
			if r.intersects(fr):
				body.set_meta("net_fx", self)
			break

# ============================================================== shared

func _make_mesh_mat(veil: Color, pin_x: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MESH_SHADER
	m.set_shader_parameter("mesh_tex", MESH_TEX)
	m.set_shader_parameter("interior", Vector4(_interior.position.x, _interior.position.y, _interior.size.x, _interior.size.y))
	m.set_shader_parameter("tile_origin", Vector2(_interior.get_center().x, _interior.position.y))
	m.set_shader_parameter("tile_wpx", Tuning.net_mesh_tile_wpx)
	m.set_shader_parameter("veil", Vector4(veil.r, veil.g, veil.b, veil.a))
	m.set_shader_parameter("pin_x", pin_x)
	m.set_shader_parameter("ripple_time", Tuning.net_ripple_time)
	m.set_shader_parameter("ripple_travel", Tuning.net_ripple_travel)
	m.set_shader_parameter("ripple_wavelength", Tuning.net_ripple_wavelength)
	m.set_shader_parameter("ripple_falloff", Tuning.net_ripple_falloff)
	m.set_shader_parameter("bulge", Vector4(0.0, 0.0, 0.0, Tuning.goal_bulge_radius * 0.5))
	m.set_shader_parameter("bulge_dir", Vector2.LEFT)
	m.set_shader_parameter("ripples", _ripple_uniform())
	return m

func _make_quad(mat: ShaderMaterial, z: int) -> MeshQuad:
	var q := MeshQuad.new()
	var pad: float = maxf(Tuning.goal_bulge_peak, Tuning.net_ripple_amp_px) + 4.0
	q.rect = _interior.grow(pad)
	q.material = mat
	q.z_as_relative = false
	q.z_index = z
	q.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return q

func _apply_frame_mat(root: Node2D) -> void:
	for c in root.get_children():
		var ci: CanvasItem = c as CanvasItem
		if ci != null:
			ci.material = _frame_mat

func _ripple_uniform() -> Array:
	var out: Array = []
	for i in range(MAX_RIPPLES):
		if i < _ripples.size():
			var r: Dictionary = _ripples[i]
			out.append(Vector4(float(r["y"]), float(r["age"]), float(r["amp"]), 0.0))
		else:
			out.append(Vector4(0.0, 99.0, 0.0, 0.0))
	return out

## Contact feed. Ball: Ball._wk66a_net_contacts (collider meta "net_fx"). Goats: ArenaRenderer
## _on_surface_bounced. Returns true when the net consumed it (the caller skips its bumper FX).
func on_contact(world_pos: Vector2, speed: float, is_player: bool) -> bool:
	if kind == "goal" and is_player:
		return false                       # goals ripple from the ball only; goats keep the wall FX
	if kind == "goal":
		var fr := Rect2(to_global(_frame_rect_local.position), _frame_rect_local.size).grow(24.0)
		if not fr.has_point(world_pos):
			return false                   # a hit far along the wall column is not a near miss
	if speed < Tuning.net_ripple_min_speed or _ripple_cd > 0.0:
		return kind == "dropshot"
	_ripple_cd = Tuning.net_ripple_cooldown
	var lp: Vector2 = to_local(world_pos)
	var frac: float = clampf(speed / maxf(Tuning.net_ripple_speed_ref, 1.0), Tuning.net_ripple_amp_min_frac, 1.0)
	var amp: float = frac * Tuning.net_ripple_amp_px
	if is_player:
		amp *= Tuning.net_ripple_player_mult
	if kind == "goal":
		amp *= Tuning.net_ripple_goal_mult
	# push AWAY from the side that was hit (a ball from the left bows the net right)
	var side: float = -1.0 if lp.x > _interior.get_center().x else 1.0
	if kind == "goal":
		side = _bulge_dir.x
	_ripples.append({ "y": clampf(lp.y, _interior.position.y, _interior.end.y), "age": 0.0, "amp": amp * side })
	while _ripples.size() > MAX_RIPPLES:
		_ripples.pop_front()
	if kind == "dropshot" and lp.y < -_ch * 0.5 + Tuning.net_tape_zone_px:
		_dip_t = 0.0
	return true

## Ball contact entry point (deferred from Ball._integrate_forces).
func on_ball_contact(world_pos: Vector2, speed: float) -> void:
	on_contact(world_pos, speed, false)

func _process(delta: float) -> void:
	if _mesh_mat == null:
		return
	_ripple_cd = maxf(0.0, _ripple_cd - delta)
	var live: Array = []
	for r in _ripples:
		r["age"] = float(r["age"]) + delta
		if float(r["age"]) < Tuning.net_ripple_time:
			live.append(r)
	var had: bool = not _ripples.is_empty()
	_ripples = live
	if had:
		var ru: Array = _ripple_uniform()
		_mesh_mat.set_shader_parameter("ripples", ru)
		if _front_mat != null:
			_front_mat.set_shader_parameter("ripples", ru)
	if kind == "dropshot":
		_tick_dropshot(delta)
	else:
		_tick_goal(delta)

func _tick_dropshot(delta: float) -> void:
	# top-tape dip: a 3 px frame OFFSET for 0.1 s (never a stretch)
	if _tape != null:
		if _dip_t >= 0.0:
			_dip_t += delta
			var k: float = 1.0 - clampf(_dip_t / maxf(Tuning.net_tape_dip_time, 0.001), 0.0, 1.0)
			_tape.position.y = _tape_y + Tuning.net_tape_dip_px * k
			if _dip_t >= Tuning.net_tape_dip_time:
				_dip_t = -1.0
				_tape.position.y = _tape_y
	# DOME gap cue: gap between the collider bottom and the floor top
	if _floor_y == INF:
		if _floor_tries < 60:
			_floor_tries += 1
			_find_floor()
		return
	var gap: float = _floor_y - (global_position.y + _ch * 0.5)
	var want: float = 1.0 if gap >= Tuning.dome_gap_glow_min else 0.0
	var step: float = delta / maxf(Tuning.dome_gap_fade, 0.001)
	_glow_a = move_toward(_glow_a, want, step)
	var on: bool = _glow_a > 0.001
	_hem_glow.visible = on
	_pool.visible = on
	if not on:
		_glow_t = 0.0
		return
	_glow_t += delta
	var pulse: float = 0.5 + 0.5 * sin(_glow_t * TAU * Tuning.dome_gap_glow_hz)
	var a: float = lerpf(Tuning.dome_gap_glow_a_min, Tuning.dome_gap_glow_a_max, pulse) * _glow_a
	_hem_glow.modulate = Color(Tuning.dome_gap_glow_color, a)
	_pool.modulate = Color(Tuning.dome_gap_glow_color, Tuning.dome_gap_pool_alpha * _glow_a)
	_pool.global_position = Vector2(global_position.x, _floor_y + Tuning.dome_gap_pool_size.y * Tuning.dome_gap_pool_drop)

func _tick_goal(delta: float) -> void:
	# goal score: the zone's EXISTING centre-in-rect latch (read only) -> bulge at the ball + frame flash
	var sc: bool = zone != null and is_instance_valid(zone) and bool(zone.get("scored"))
	if sc and not _was_scored:
		_flash_t = 0.0
		_bulge_t = 0.0
		var at: Vector2 = global_position
		var best: float = INF
		for b in get_tree().get_nodes_in_group("sports_ball"):
			var bn: Node2D = b as Node2D
			if bn == null:
				continue
			var d: float = bn.global_position.distance_to(global_position)
			if d < best:
				best = d
				at = bn.global_position
		var lp: Vector2 = to_local(at)
		_bulge_c = Vector2(clampf(lp.x, _interior.position.x, _interior.end.x),
			clampf(lp.y, _interior.position.y, _interior.end.y))
	_was_scored = sc
	if _bulge_t >= 0.0:
		_bulge_t += delta
		var amp: float = 0.0
		if _bulge_t < Tuning.goal_bulge_time:
			var w: float = TAU * Tuning.goal_bulge_freq_hz
			# damped spring released from rest by the ball's push: rises fast, 2 visible wobbles, settles
			var peak_t: float = atan(w / maxf(Tuning.goal_bulge_decay, 0.001)) / w
			var norm: float = exp(-Tuning.goal_bulge_decay * peak_t) * sin(w * peak_t)
			amp = Tuning.goal_bulge_peak * exp(-Tuning.goal_bulge_decay * _bulge_t) * sin(w * _bulge_t) / maxf(norm, 0.001)
		else:
			_bulge_t = -1.0
		var bu := Vector4(_bulge_c.x, _bulge_c.y, amp, Tuning.goal_bulge_radius * 0.5)
		_mesh_mat.set_shader_parameter("bulge", bu)
		_mesh_mat.set_shader_parameter("bulge_dir", _bulge_dir)
		_front_mat.set_shader_parameter("bulge", bu)
		_front_mat.set_shader_parameter("bulge_dir", _bulge_dir)
	if _flash_t >= 0.0:
		_flash_t += delta
		var hold: float = Tuning.goal_flash_hold
		var k: float = 0.0 if _flash_t <= hold else clampf((_flash_t - hold) / maxf(Tuning.goal_flash_fade, 0.001), 0.0, 1.0)
		_frame.modulate = Color.WHITE.lerp(_team_col, k)
		if k >= 1.0:
			_flash_t = -1.0
