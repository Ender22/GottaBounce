extends CanvasLayer
## WK-23 — Smash-style SCREEN-EDGE KO BLAST in the victim's colour (audit D-01, the punchline made visible).
## Art: docs/briefs/ko_blast_2026-11-14.md — four greyscale layers (core / column / ring / star) tinted to the
## victim's identity colour (PartyMatch.player_color, WK-08) through the shared fx_tint gradient-map shader.
##
## Presentation ONLY (INV-12): subscribes to KillPipeline.killed, reads the camera transform, writes nothing
## in the sim and NEVER moves the camera (owner camera rules 2026-07-10 — the blast is pinned to the edge in
## screen space, not a camera move). Ring-outs happen outside the camera bounds by construction, so the
## death point is projected onto the viewport (EdgeIndicators math) and the blast fires from the edge the
## victim left through, pointing back INTO the screen:
##   left / right / bottom -> core starburst + shockwave ring + jagged plume column
##   top                   -> core starburst + shockwave ring + star-KO twinkle
## A death that is still ON screen (an in-view hazard) gets no edge blast — Juice's in-world burst covers it.
##
## Real-time: a hitch-proof clock (see _process) ignores Engine.time_scale, so the KO hit-stop never stretches it
## (<= ko_blast_duration) and a long KO frame never skips it.
## Size discipline: px sizes are authored at 1080p and scale with viewport height; the column depth is capped
## by ko_blast_column_depth_frac of the axis so nothing reaches the middle 60% (MatchHUD prime directive).
## Code-built nodes (dynamic count, rotation) on a CanvasLayer, like EdgeIndicators — no UI widgets here.
## No class_name: loaded by path from PartyMatch (no class-cache dependency).

const CORE_TEX := preload("res://assets/fx/ko_blast_core.png")
const COLUMN_TEX := preload("res://assets/fx/ko_blast_column.png")
const RING_TEX := preload("res://assets/fx/ko_blast_ring.png")
const STAR_TEX := preload("res://assets/fx/ko_blast_star.png")
const TINT_SHADER := preload("res://assets/shaders/fx_tint.gdshader")
const QA_LOG_MAX := 32

var _match                       # PartyMatch (read-only): players, _camera, player_color(i), ko_blast_enabled()
var _mat: ShaderMaterial
## QA feed (gbplay eval): one dict per blast fired — {victim, edge, anchor:[x,y], color:"#rrggbb", msec}.
var blasts: Array = []
var blast_count := 0

func setup(match_ref) -> void:
	_match = match_ref
	_mat = ShaderMaterial.new()
	_mat.shader = TINT_SHADER
	if not KillPipeline.killed.is_connected(_on_killed):
		KillPipeline.killed.connect(_on_killed)

func _exit_tree() -> void:
	if KillPipeline.killed.is_connected(_on_killed):
		KillPipeline.killed.disconnect(_on_killed)

func _on_killed(victim, _cause, _attacker) -> void:
	if _match == null or not is_instance_valid(_match) or victim == null or not is_instance_valid(victim):
		return
	if _match.has_method("ko_blast_enabled") and not _match.ko_blast_enabled():
		return
	var cam = _match._camera
	if cam == null or not is_instance_valid(cam):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var z: float = cam.zoom.x
	var sp: Vector2 = (victim.global_position - cam.get_screen_center_position()) * z + vp * 0.5
	var k: float = vp.y / Tuning.ko_blast_ref_height
	var margins := Vector2(Tuning.ko_blast_edge_margin_x_px, Tuning.ko_blast_edge_margin_y_px) * k
	var info: Dictionary = classify(sp, vp, margins, Tuning.ko_blast_edge_band_px * k)
	if info.is_empty():
		return   # died well inside the frame: the in-world death burst is visible already
	var idx: int = _match.players.find(victim)
	var col: Color = _match.player_color(idx) if idx >= 0 else Color.WHITE
	if idx < 0 and victim.has_method("identity_color"):
		col = victim.identity_color()
	fire(info, col)
	blast_count += 1
	var anchor: Vector2 = info["anchor"]
	blasts.append({"victim": idx, "edge": str(info["edge"]), "anchor": [anchor.x, anchor.y],
		"color": "#" + col.to_html(false), "msec": Time.get_ticks_msec()})
	if blasts.size() > QA_LOG_MAX:
		blasts.remove_at(0)

## Which viewport edge a screen-space death point `sp` left through, or {} when it is well inside the frame.
## A point within `band` px of an edge counts as leaving through it (the kill line can sit just inside the
## frame on zoomed-out void-floor arenas). Picks the edge with the largest overshoot (EdgeIndicators-style
## clamp, one edge chosen); the along-edge coordinate stays `margin.x` (top/bottom) / `margin.y` (sides) px
## from the corners, clear of the HUD corner cards.
## Returns {edge, anchor, inward}; the anchor is always ON the true viewport edge.
static func classify(sp: Vector2, vp: Vector2, margin: Vector2, band: float = 0.0) -> Dictionary:
	var out_l: float = band - sp.x
	var out_r: float = sp.x - (vp.x - band)
	var out_t: float = band - sp.y
	var out_b: float = sp.y - (vp.y - band)
	var m: float = maxf(maxf(out_l, out_r), maxf(out_t, out_b))
	if m <= 0.0:
		return {}
	var mx: float = minf(margin.x, vp.x * 0.5)
	var my: float = minf(margin.y, vp.y * 0.5)
	if m == out_t:
		return {"edge": "top", "anchor": Vector2(clampf(sp.x, mx, vp.x - mx), 0.0), "inward": Vector2.DOWN}
	if m == out_b:
		return {"edge": "bottom", "anchor": Vector2(clampf(sp.x, mx, vp.x - mx), vp.y), "inward": Vector2.UP}
	if m == out_l:
		return {"edge": "left", "anchor": Vector2(0.0, clampf(sp.y, my, vp.y - my)), "inward": Vector2.RIGHT}
	return {"edge": "right", "anchor": Vector2(vp.x, clampf(sp.y, my, vp.y - my)), "inward": Vector2.LEFT}

## Build one blast. Local frame: origin = the edge point, local -Y = INTO the screen (so the column art,
## authored plume-up with its foot at the bottom edge, maps directly). Animation runs in _process.
func fire(info: Dictionary, col: Color) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k: float = vp.y / Tuning.ko_blast_ref_height
	var edge: String = str(info["edge"])
	var inward: Vector2 = info["inward"]
	var root := Node2D.new()
	root.position = info["anchor"]
	root.rotation = inward.angle() + PI * 0.5
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(root)
	var b := {"root": root, "t": 0.0, "dur": maxf(0.2, Tuning.ko_blast_duration), "fresh": true}
	# 1) shockwave ring (drawn first = behind)
	b["ring"] = _layer(root, RING_TEX, col)
	b["ring_base"] = Tuning.ko_blast_ring_px * k / float(RING_TEX.get_width())
	# 2) plume column (sides / bottom): foot on the edge, fires inward
	if edge != "top":
		var column := _layer(root, COLUMN_TEX, col)
		column.offset = Vector2(0.0, -COLUMN_TEX.get_height() * 0.5)   # origin = the plume's foot
		var axis_len: float = vp.x if (edge == "left" or edge == "right") else vp.y
		var depth: float = minf(Tuning.ko_blast_column_depth_px * k, Tuning.ko_blast_column_depth_frac * axis_len)
		b["column"] = column
		b["col_sx"] = Tuning.ko_blast_column_width_px * k / float(COLUMN_TEX.get_width())
		b["col_sy"] = depth / float(COLUMN_TEX.get_height())
	# 3) core starburst — centre nudged 0.12 * size inward: at the 1.15 pop peak it still ends ~208 px in
	#    (< 216 = 20% of 1080), so it never reaches the middle 60%
	var core := _layer(root, CORE_TEX, col)
	core.position = Vector2(0.0, -Tuning.ko_blast_core_px * k * 0.12)
	core.rotation = randf_range(-0.26, 0.26)
	b["core"] = core
	b["core_base"] = Tuning.ko_blast_core_px * k / float(CORE_TEX.get_width())
	# 4) star-KO twinkle (top edge), upright on screen regardless of the root frame
	if edge == "top":
		# lighter than the core so the twinkle reads ON the same-hued starburst (rendered QA: same tint merged)
		var star := _layer(root, STAR_TEX, col.lerp(Color.WHITE, Tuning.ko_blast_star_white))
		star.position = Vector2(0.0, -Tuning.ko_blast_star_inset_px * k)
		b["star"] = star
		b["star_base"] = Tuning.ko_blast_star_px * k / float(STAR_TEX.get_width())
		b["star_rot0"] = -root.rotation
	_live.append(b)
	_apply(b)   # frame 0 pose (pop start) is drawn on the KO frame itself

## Hitch-proof clock (rendered QA): real time, IGNORING Engine.time_scale (the KO hit-stop never stretches
## it), but each frame's step is clamped to MAX_STEP and the clock only starts on the first frame AFTER the
## KO — so a long KO frame (stage-end work, a load hitch) can never skip the blast straight to its fade.
## Pauses with the tree (CanvasLayer inherits); a resume step is clamped too.
const MAX_STEP := 0.1   # 10 fps floor: low-FPS machines still play it at ~real speed (1/30 stretched it at 16 fps)
var _live: Array = []
var _last_us := 0

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt: float = clampf(float(now - _last_us) / 1000000.0, 0.0, MAX_STEP)
	_last_us = now
	for i in range(_live.size() - 1, -1, -1):
		var b: Dictionary = _live[i]
		if not is_instance_valid(b["root"]):
			_live.remove_at(i)
			continue
		if bool(b["fresh"]):
			b["fresh"] = false   # the KO frame's own duration never counts
		else:
			b["t"] = float(b["t"]) + dt
		if float(b["t"]) >= float(b["dur"]) + 0.05:
			(b["root"] as Node).queue_free()
			_live.remove_at(i)
			continue
		_apply(b)

## Pose every layer at blast time t (the brief's per-layer motion, <= dur).
func _apply(b: Dictionary) -> void:
	var t: float = b["t"]
	var d: float = b["dur"]
	var ring: Sprite2D = b["ring"]
	var rb: float = b["ring_base"]
	ring.scale = Vector2.ONE * rb * lerpf(0.3, 1.6, _out_quad(t / (d * 0.75)))
	ring.modulate.a = 1.0 - _clamp01((t - d * 0.3) / (d * 0.45))
	if b.has("column"):
		var column: Sprite2D = b["column"]
		var sx: float = b["col_sx"]
		var sy: float = b["col_sy"]
		column.scale = Vector2(sx * lerpf(1.0, 0.45, _in_quad((t - d * 0.3) / (d * 0.6))), sy * _out_back(t / 0.08))
		column.modulate.a = 1.0 - _clamp01((t - d * 0.45) / (d * 0.45))
	var core: Sprite2D = b["core"]
	var cb: float = b["core_base"]
	var cs: float
	if t < 0.07:
		cs = lerpf(0.4, 1.15, _out_quad(t / 0.07))
	elif t < 0.15:
		cs = lerpf(1.15, 1.0, smoothstep(0.0, 1.0, (t - 0.07) / 0.08))
	else:
		cs = 1.0
	core.scale = Vector2.ONE * cb * cs
	core.modulate.a = 1.0 - _in_quad((t - maxf(0.15, d * 0.5)) / (d * 0.4))
	if b.has("star"):
		var star: Sprite2D = b["star"]
		var sb: float = b["star_base"]
		var ss: float
		if t < 0.09:
			ss = 1.3 * _out_back(t / 0.09)
		elif t < 0.17:
			ss = lerpf(1.3, 0.9, (t - 0.09) / 0.08)
		elif t < 0.25:
			ss = lerpf(0.9, 1.15, (t - 0.17) / 0.08)
		else:
			ss = lerpf(1.15, 0.6, _in_quad((t - 0.25) / maxf(0.05, d - 0.25)))
		star.scale = Vector2.ONE * sb * ss
		star.rotation = float(b["star_rot0"]) + TAU * 1.25 * _out_quad(t / d)
		star.modulate.a = 1.0 - _clamp01((t - d * 0.65) / (d * 0.35))

static func _clamp01(x: float) -> float:
	return clampf(x, 0.0, 1.0)

static func _out_quad(x: float) -> float:
	var u := _clamp01(x)
	return 1.0 - (1.0 - u) * (1.0 - u)

static func _in_quad(x: float) -> float:
	var u := _clamp01(x)
	return u * u

static func _out_back(x: float) -> float:
	var u := _clamp01(x) - 1.0
	return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u

func _layer(root: Node2D, tex: Texture2D, col: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.material = _mat
	s.self_modulate = col
	root.add_child(s)
	return s
