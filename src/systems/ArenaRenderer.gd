class_name ArenaRenderer
extends Node2D
## "Glossy Toybox" arena painter (docs/briefs/arena_rendering.md). Owns ALL platform / wall /
## background painting; LevelLoader builds colliders from JSON (authoritative, untouched) and
## delegates every visual to this node. Display-only: art snaps to canonical heights and bleeds
## past colliders on purpose; the collider top edge is always the surface line the mat sits on.
##
## Assets are resolved by path with graceful skip-if-missing (push_warning once, never a flat
## debug fill), so late-arriving art slots in on the next load with zero code change.

# --- asset paths (data-driven: drop the file in, it gets used on next level load) ---
const BODY_TEX := "res://assets/world/grass/body_std.png"
const HERO_TEX := "res://assets/world/grass/platform_wide.png"
const SKY_TEX := "res://assets/bg/sky_grass_day.png"
const HILLS_TEX := "res://assets/bg/hills_far.png"
const CLOUD_TEXES: Array[String] = ["res://assets/bg/cloud_a.png", "res://assets/bg/cloud_b.png"]
const PROP_TEXES: Array[String] = ["res://assets/bg/bush_round.png", "res://assets/bg/fence_wood.png"]
const BUMPER_POST_TEX := "res://assets/world/bumper_post.png"
const TUFT_TEXES: Array[String] = [
	"res://assets/world/grass/decal_tuft_a.png", "res://assets/world/grass/decal_tuft_b.png"]
const FLOWER_TEX := "res://assets/world/grass/decal_flower_white.png"

# --- tier readability table (brief §2): color + mat per tier; bumper is the only grey ---
const TIERS := {
	"marshmallow": { "mat": "res://assets/world/tiers/mat_marshmallow.png",
		"primary": Color("#FFF6EC"), "support": Color("#FFC9DD") },
	"bubblegum": { "mat": "res://assets/world/tiers/mat_bubblegum.png",
		"primary": Color("#FF4FA3"), "support": Color("#FF8AC5") },
	"trampoline": { "mat": "res://assets/world/tiers/mat_trampoline.png",
		"primary": Color("#2F6BD8"), "support": Color("#FFD23F") },
	"spring": { "mat": "res://assets/world/tiers/mat_spring.png",
		"primary": Color("#FF6A2A"), "support": Color("#D9DEE7") },
	"bumper": { "mat": "",
		"primary": Color("#98A1AF"), "support": Color("#F4F6F9") },
}

const SHADOW_COLOR := Color(0.118, 0.169, 0.251)   # #1E2B40
const AERIAL := Color(0.88, 0.94, 1.02)            # layers 2-4 recede toward the sky (§3)

# --- geometry constants (brief §1-2) ---
const MAT_H := 28.0            # mat world height on bodied platforms
const MAT_RISE := 8.0          # mat rises above the collider top (toys have thickness)
const SLAB_MAX_H := 48.0       # h <= 48 -> mat only, no body
const SLAB_MAT_BLEED := 12.0   # mat-only slabs: mat height = collider height + this
const BODY_BLEED_TOP := 12.0   # grass fringe above the collider top (~10-14 px)
const BODY_BLEED_SIDE := 8.0   # caps past the collider sides
const WALL_FACE_BLEED := 8.0   # wall art past the collider on its face sides
const MAX_VIEW := Vector2(4800.0, 2700.0)   # view size at max zoom-out (+margin)

var _layers: Array = []      # parallax: { node, factor: float, base: Vector2 }
var _anchor := Vector2.ZERO  # camera anchor (play-rect center): layers sit at base when cam is here
var _clouds: Array = []      # { node, speed, min_x, max_x }
var _twinkles: Array = []    # { node, speed, phase, max_a }
var _springs: Array = []     # { pivot, next_t } idle shimmer (springs only — motion must mean something)
var _surfaces := {}          # StaticBody2D -> { tier, art, mat, w, top, last_ms } for bounce FX
var _warned := {}
var _t := 0.0

func _ready() -> void:
	EventBus.surface_bounced.connect(_on_surface_bounced)

## Build the full background stack from the level JSON. Call once, before platforms are painted.
func setup(json: Dictionary) -> void:
	var b: Dictionary = json.get("bounds", {})
	var brect := Rect2(-1000, -1000, 2000, 2000)
	if not b.is_empty():
		brect = Rect2(float(b["left"]), float(b["top"]),
			float(b["right"]) - float(b["left"]), float(b["bottom"]) - float(b["top"]))
	# play rect + floor line (top of the widest platform) derived from the platform list
	var play := Rect2()
	var floor_y := brect.position.y + brect.size.y * 0.7
	var widest := 0.0
	var first := true
	for p in json.get("platforms", []):
		var r := Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"]))
		play = r if first else play.merge(r)
		first = false
		if r.size.x > widest:
			widest = r.size.x
			floor_y = r.position.y
	_anchor = play.get_center() if not first else brect.get_center()
	_build_background(json, brect, floor_y)

# ============================== BACKGROUND (brief §3) ==============================

func _build_background(json: Dictionary, brect: Rect2, floor_y: float) -> void:
	# Layer 0 — code sky gradient, world-static safety net covering everything (visible only past
	# art edges / extreme zoom-out).
	var pad := 2600.0
	var grad_rect := brect.grow(pad)
	var sky_top := Color(str(json.get("sky_top", "#3a6ea5")))
	var sky_bot := Color(str(json.get("sky_bottom", "#bfe3ff")))
	var g := Polygon2D.new()
	g.polygon = PackedVector2Array([grad_rect.position, Vector2(grad_rect.end.x, grad_rect.position.y),
		grad_rect.end, Vector2(grad_rect.position.x, grad_rect.end.y)])
	g.vertex_colors = PackedColorArray([sky_top, sky_top, sky_bot, sky_bot])
	g.z_index = -100
	add_child(g)

	# Layer 1 — sky painting, parallax 0.05, scaled to cover the view at max zoom-out + 10%.
	if ResourceLoader.exists(SKY_TEX):
		var tex: Texture2D = load(SKY_TEX)
		var need := MAX_VIEW * 1.1
		var sc := maxf(need.x / tex.get_width(), need.y / tex.get_height())
		var node := Node2D.new()
		node.z_index = -95
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.scale = Vector2(sc, sc)
		node.add_child(sp)
		# the painting's own hills sit at its bottom: park them a bit below the arena floor line,
		# and extend the painting's bottom row color further down so no gradient seam can show
		var sky_h := tex.get_height() * sc
		var base := Vector2(_anchor.x, floor_y + 420.0 - sky_h * 0.5)
		_extend_below(node, tex, Vector2(0.0, floor_y + 400.0), tex.get_width() * sc, brect.end.y + pad)
		_add_layer(node, 0.05, base)
	else:
		_warn_once("sky", "ArenaRenderer: missing " + SKY_TEX + " — sky gradient only")

	# Layer 2 — far hills strip, parallax 0.18, tiled horizontally with feathered-edge crossfade
	# (the source has hard side edges), aerial-modulated, no outlines.
	if ResourceLoader.exists(HILLS_TEX):
		var raw: Texture2D = load(HILLS_TEX)
		var tex := _feathered_texture(raw, 0.08)
		var sc := 500.0 / float(tex.get_height())
		var tile_w := tex.get_width() * sc
		var step := tile_w * 0.92   # overlap the feathered zones so they crossfade
		var node := Node2D.new()
		node.z_index = -90
		node.modulate = AERIAL
		var span := MAX_VIEW.x + brect.size.x * 0.2
		var n := int(ceil(span / step)) + 1
		for i in range(n):
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.scale = Vector2(sc, sc)
			sp.position = Vector2((float(i) - float(n - 1) * 0.5) * step, 0.0)
			node.add_child(sp)
		var hills_h := tex.get_height() * sc
		# extension starts INSIDE the strip's soft bottom fade so the art blends into it
		_extend_below(node, tex, Vector2(0.0, hills_h * 0.5 - hills_h * 0.20), span + tile_w, brect.end.y + pad)
		_add_layer(node, 0.18, Vector2(_anchor.x, floor_y + 60.0 - hills_h * 0.5))
	else:
		_warn_once("hills", "ArenaRenderer: missing " + HILLS_TEX + " — far-hills layer skipped")

	# Layer 3 — drifting clouds (6-14 px/s, wrap) + 4-6 twinkling diamonds in tier support colors.
	var cloud_node := Node2D.new()
	cloud_node.z_index = -85
	cloud_node.modulate = AERIAL
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("toybox_clouds")
	var have_cloud := false
	for path in CLOUD_TEXES:
		if ResourceLoader.exists(path):
			have_cloud = true
	if have_cloud:
		var wrap_half := brect.size.x * 0.5 + MAX_VIEW.x * 0.35
		for i in range(3):
			var path: String = CLOUD_TEXES[i % CLOUD_TEXES.size()]
			if not ResourceLoader.exists(path):
				path = CLOUD_TEXES[(i + 1) % CLOUD_TEXES.size()]
			if not ResourceLoader.exists(path):
				continue
			var sp := Sprite2D.new()
			sp.texture = load(path)
			var sc := rng.randf_range(0.35, 0.7)
			sp.scale = Vector2(sc, sc)
			sp.position = Vector2(rng.randf_range(-wrap_half, wrap_half),
				floor_y - rng.randf_range(520.0, 980.0))
			cloud_node.add_child(sp)
			_clouds.append({ "node": sp, "speed": rng.randf_range(6.0, 14.0) * (1.0 if i % 2 == 0 else -1.0),
				"min_x": -wrap_half, "max_x": wrap_half })
	else:
		_warn_once("clouds", "ArenaRenderer: no bg/cloud_*.png yet — cloud drifters skipped")
	# twinkles are cheap code diamonds — always on (the sky painting already carries confetti)
	var support: Array = [TIERS["marshmallow"]["support"], TIERS["bubblegum"]["support"],
		TIERS["trampoline"]["support"], TIERS["spring"]["support"]]
	for i in range(5):
		var d := Polygon2D.new()
		var s := rng.randf_range(7.0, 13.0)
		d.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s * 0.4, 0), Vector2(0, s), Vector2(-s * 0.4, 0)])
		var col: Color = support[i % support.size()]
		col.a = 0.0
		d.color = col
		d.position = Vector2(rng.randf_range(-brect.size.x * 0.4, brect.size.x * 0.4),
			floor_y - rng.randf_range(350.0, 1000.0))
		cloud_node.add_child(d)
		_twinkles.append({ "node": d, "speed": rng.randf_range(0.5, 1.1),
			"phase": rng.randf_range(0.0, TAU), "max_a": 0.35 })
	_add_layer(cloud_node, 0.30, Vector2(_anchor.x, 0.0))

	# Layer 4 — mid props (bushes / fences) scattered along the floor line, parallax 0.55.
	var have_prop := false
	for path in PROP_TEXES:
		if ResourceLoader.exists(path):
			have_prop = true
	if have_prop:
		var node := Node2D.new()
		node.z_index = -80
		node.modulate = AERIAL
		var prng := RandomNumberGenerator.new()
		prng.seed = hash("toybox_props")
		var count := 4
		for i in range(count):
			var path: String = PROP_TEXES[i % PROP_TEXES.size()]
			if not ResourceLoader.exists(path):
				path = PROP_TEXES[(i + 1) % PROP_TEXES.size()]
			if not ResourceLoader.exists(path):
				continue
			var tex: Texture2D = load(path)
			var sp := Sprite2D.new()
			sp.texture = tex
			var sc := prng.randf_range(0.28, 0.42)
			sp.scale = Vector2(sc, sc)
			var x := lerpf(-brect.size.x * 0.42, brect.size.x * 0.42, (float(i) + prng.randf_range(0.2, 0.8)) / float(count))
			sp.position = Vector2(x, -tex.get_height() * sc * 0.42)
			node.add_child(sp)
		_add_layer(node, 0.55, Vector2(_anchor.x, floor_y + 24.0))
	else:
		_warn_once("props", "ArenaRenderer: no bg mid props yet (bush_round/fence_wood) — layer 4 skipped")

## Extend a layer's art downward with its own solid-bottom color so the gradient can never show
## through under a painted horizon (a color extension of the art, not a debug fill). Scans up past
## any soft alpha fade to a genuinely solid row, and darkens slightly toward the bottom for depth.
func _extend_below(layer: Node2D, tex: Texture2D, top_center: Vector2, width: float, world_bottom: float) -> void:
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	var xstep := maxi(1, int(img.get_width() / 24.0))
	var col := Color(0, 0, 0, 0)
	var y := img.get_height() - 2
	while y > img.get_height() / 2:
		var acc := Color(0, 0, 0, 0)
		var solid := 0
		var total := 0
		var x := xstep / 2
		while x < img.get_width():
			var c := img.get_pixel(x, y)
			total += 1
			if c.a > 0.85:
				acc += c
				solid += 1
			x += xstep
		if total > 0 and float(solid) / float(total) >= 0.7:
			col = Color(acc.r / solid, acc.g / solid, acc.b / solid, 1.0)
			break
		y -= 4
	if col.a == 0.0:
		return
	var h := maxf(200.0, world_bottom - top_center.y)
	var deep := col.darkened(0.16)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-width * 0.5, 0), Vector2(width * 0.5, 0),
		Vector2(width * 0.5, h), Vector2(-width * 0.5, h)])
	poly.vertex_colors = PackedColorArray([col, col, deep, deep])
	poly.position = top_center
	poly.z_index = -1
	poly.show_behind_parent = true
	layer.add_child(poly)

## Copy of a texture with the left/right edges alpha-feathered, for seamless horizontal tiling
## of soft background strips (brief §4 item 11: overlap with alpha feather in code).
func _feathered_texture(tex: Texture2D, feather_frac: float) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var f := maxi(2, int(w * feather_frac))
	for x in range(f):
		var k := float(x) / float(f)
		for yy in range(h):
			var c := img.get_pixel(x, yy)
			c.a *= k
			img.set_pixel(x, yy, c)
			var c2 := img.get_pixel(w - 1 - x, yy)
			c2.a *= k
			img.set_pixel(w - 1 - x, yy, c2)
	return ImageTexture.create_from_image(img)

func _add_layer(node: Node2D, factor: float, base: Vector2) -> void:
	node.position = base
	add_child(node)
	_layers.append({ "node": node, "factor": factor, "base": base })

func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var d: Vector2 = cam.global_position - _anchor
		for L in _layers:
			var node: Node2D = L["node"]
			if is_instance_valid(node):
				node.position = (L["base"] as Vector2) + d * (1.0 - float(L["factor"]))
	for c in _clouds:
		var sp: Node2D = c["node"]
		if not is_instance_valid(sp):
			continue
		sp.position.x += float(c["speed"]) * delta
		if sp.position.x > float(c["max_x"]):
			sp.position.x = float(c["min_x"])
		elif sp.position.x < float(c["min_x"]):
			sp.position.x = float(c["max_x"])
	for tw in _twinkles:
		var d2: Polygon2D = tw["node"]
		if is_instance_valid(d2):
			var a := 0.5 + 0.5 * sin(_t * TAU * float(tw["speed"]) * 0.2 + float(tw["phase"]))
			d2.color.a = a * a * float(tw["max_a"])
	# idle spring shimmer: ±1px vertical blip every few seconds (springs only)
	for s in _springs:
		if _t >= float(s["next_t"]):
			s["next_t"] = _t + randf_range(3.0, 5.0)
			var pivot: Node2D = s["pivot"]
			if is_instance_valid(pivot):
				var twn := pivot.create_tween()
				twn.tween_property(pivot, "position:y", pivot.position.y - 1.0, 0.08)
				twn.tween_property(pivot, "position:y", pivot.position.y + 1.0, 0.12)
				twn.tween_property(pivot, "position:y", pivot.position.y, 0.15)

# ============================== PLATFORMS (brief §1-2) ==============================

## Paint one platform's art into its StaticBody2D. Up to three stacked pieces: body (theme),
## tier mat (readability contract), decals (kill tiling repetition). Collider untouched.
func paint_platform(p: Dictionary, body: StaticBody2D) -> void:
	var w: float = p["w"]
	var h: float = p["h"]
	var tier := str(p.get("tier", "marshmallow"))
	var top := -h * 0.5
	var root := Node2D.new()
	root.name = "Art"
	body.add_child(root)

	# shadow first (anchor trick §3): rounded rect, never squashed by bounce FX
	var sh := _rounded_rect_poly(w - 8.0, h, h / 3.0, Color(SHADOW_COLOR, 0.25))
	sh.position = Vector2(0.0, 12.0)
	root.add_child(sh)

	var art := Node2D.new()   # squashable container (bounce FX scales this)
	root.add_child(art)

	if tier == "bumper":
		_paint_bumper(art, w, h)
		_surfaces[body] = { "tier": tier, "art": art, "mat": null, "w": w, "top": top, "last_ms": -9999 }
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2(float(p["x"]), float(p["y"])))   # stable frame-to-frame + across clients

	var mat_h: float
	var mat_top: float
	if h > SLAB_MAX_H:
		# themed 3-slice body, art height snapped to canonical H64/H128 (vertical stretch is banned)
		var art_h := _canonical_height(h) + BODY_BLEED_TOP
		var art_w := w + BODY_BLEED_SIDE * 2.0
		var body_art := _platform_body(art_w, art_h)
		if body_art != null:
			body_art.position = Vector2(0.0, top - BODY_BLEED_TOP + art_h * 0.5)
			art.add_child(body_art)
		_scatter_back_tufts(art, w, top, rng)   # behind the mat, tips peeking above it
		mat_h = MAT_H
		mat_top = top - MAT_RISE
	else:
		# thin slab: the mat alone IS the platform (a 36px grass smear reads as nothing)
		mat_h = h + SLAB_MAT_BLEED
		mat_top = top - MAT_RISE

	# tier mat spans the FULL collider width — it IS the bounce surface (§2)
	var m := _mat_texture(tier)
	var pivot := Node2D.new()   # scale pivot at the mat's bottom so pulses squash onto the body
	pivot.position = Vector2(0.0, mat_top + mat_h)
	art.add_child(pivot)
	if m["tex"] != null:
		var mat := ThreeSlice.build(m["tex"], w, mat_h, 0.18, false, m["tint"])
		mat.position = Vector2(0.0, -mat_h * 0.5)
		pivot.add_child(mat)

	_scatter_end_decals(art, w, mat_top, rng)   # tufts hugging the mat's outer corners + flowers
	if tier == "spring":
		_springs.append({ "pivot": pivot, "next_t": _t + randf_range(2.0, 5.0) })
	_surfaces[body] = { "tier": tier, "art": art, "mat": pivot, "w": w, "top": top, "last_ms": -9999 }

func _canonical_height(h: float) -> float:
	return 64.0 if absf(h - 64.0) <= absf(h - 128.0) else 128.0

## Themed body art: whole-sprite hero if some source is within ±20% aspect, else 3-slice grass body.
func _platform_body(art_w: float, art_h: float) -> Node2D:
	for path in [HERO_TEX, BODY_TEX]:
		if not ResourceLoader.exists(path):
			continue
		var whole := ThreeSlice.build_whole(load(path), art_w, art_h)
		if whole != null:
			return whole
	if ResourceLoader.exists(BODY_TEX):
		return ThreeSlice.build(load(BODY_TEX), art_w, art_h, 0.22)
	_warn_once("body", "ArenaRenderer: missing " + BODY_TEX + " — platform bodies mat-only")
	return null

## Mat texture for a tier. Fallbacks: missing tier mat -> marshmallow mat tinted with the tier
## primary; all mats missing -> grass body strip tinted (never a flat polygon).
func _mat_texture(tier: String) -> Dictionary:
	var info: Dictionary = TIERS.get(tier, TIERS["marshmallow"])
	var path := str(info["mat"])
	if path != "" and ResourceLoader.exists(path):
		return { "tex": load(path), "tint": Color.WHITE }
	var fb := str(TIERS["marshmallow"]["mat"])
	if ResourceLoader.exists(fb):
		_warn_once("mat_" + tier, "ArenaRenderer: missing %s — marshmallow mat tinted %s" % [path, tier])
		return { "tex": load(fb), "tint": info["primary"] }
	_warn_once("mats", "ArenaRenderer: ALL tier mats missing — tinted grass strip stand-in")
	if ResourceLoader.exists(BODY_TEX):
		return { "tex": load(BODY_TEX), "tint": info["primary"] }
	return { "tex": null, "tint": Color.WHITE }

## Bumpers bounce on all faces: the whole body is the bumper asset (no mat). Vertical walls use
## the post 3-sliced VERTICALLY (never a rotated horizontal platform).
func _paint_bumper(art: Node2D, w: float, h: float) -> void:
	var vertical := h >= w
	if ResourceLoader.exists(BUMPER_POST_TEX) and vertical:
		art.add_child(ThreeSlice.build(load(BUMPER_POST_TEX), w + WALL_FACE_BLEED * 2.0, h + 8.0, 0.22, true))
		return
	# Temporary stand-in until world/bumper_post.png lands: marshmallow mat strip tinted bumper-grey.
	var fb := str(TIERS["marshmallow"]["mat"])
	if ResourceLoader.exists(fb):
		_warn_once("bumper", "ArenaRenderer: missing " + BUMPER_POST_TEX + " — grey mat strip stand-in")
		var strip := ThreeSlice.build(load(fb), maxf(w, h) + 8.0, minf(w, h) + WALL_FACE_BLEED * 2.0,
			0.18, false, TIERS["bumper"]["primary"])
		if vertical:
			strip.rotation = -PI * 0.5
		art.add_child(strip)
		return
	if ResourceLoader.exists(BODY_TEX):
		_warn_once("bumper2", "ArenaRenderer: no bumper art at all — tinted grass strip stand-in")
		var strip2 := ThreeSlice.build(load(BODY_TEX), maxf(w, h) + 8.0, minf(w, h) + WALL_FACE_BLEED * 2.0,
			0.22, false, TIERS["bumper"]["primary"])
		if vertical:
			strip2.rotation = -PI * 0.5
		art.add_child(strip2)

# --- decals (seeded scatter; seed = hash of platform x,y so it's stable) ---

func _tuft_textures() -> Array:
	var out: Array = []
	for path in TUFT_TEXES:
		if ResourceLoader.exists(path):
			out.append(load(path))
	return out

## Back-edge tufts: drawn under the mat (child order), positioned so tips peek above it.
func _scatter_back_tufts(art: Node2D, w: float, top: float, rng: RandomNumberGenerator) -> void:
	var tufts := _tuft_textures()
	if tufts.is_empty():
		_warn_once("tufts", "ArenaRenderer: no grass decal tufts yet — scatter skipped")
		return
	var n := int(w / 140.0)
	for i in range(n):
		var tex: Texture2D = tufts[rng.randi_range(0, tufts.size() - 1)]
		var size := rng.randf_range(42.0, 68.0)
		var sc := size / float(tex.get_width())
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.scale = Vector2(sc, sc)
		sp.position = Vector2(rng.randf_range(-w * 0.5 + 36.0, w * 0.5 - 36.0),
			top - MAT_RISE - tex.get_height() * sc * 0.28)
		art.add_child(sp)

## End decals over the mat corners (~20% of cap width in) + flowers at cap ends only (max 2).
func _scatter_end_decals(art: Node2D, w: float, mat_top: float, rng: RandomNumberGenerator) -> void:
	var tufts := _tuft_textures()
	if not tufts.is_empty():
		for side in [-1.0, 1.0]:
			var tex: Texture2D = tufts[rng.randi_range(0, tufts.size() - 1)]
			var size := rng.randf_range(40.0, 56.0)
			var sc := size / float(tex.get_width())
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.scale = Vector2(sc, sc)
			sp.position = Vector2(side * (w * 0.5 - rng.randf_range(4.0, 14.0)),
				mat_top + rng.randf_range(2.0, 8.0))
			art.add_child(sp)
	if ResourceLoader.exists(FLOWER_TEX):
		var flowers := mini(2, int(w / 400.0))
		var ftex: Texture2D = load(FLOWER_TEX)
		for i in range(flowers):
			var side := -1.0 if i == 0 else 1.0
			var size := rng.randf_range(36.0, 50.0)
			var sc := size / float(ftex.get_width())
			var sp := Sprite2D.new()
			sp.texture = ftex
			sp.scale = Vector2(sc, sc)
			sp.position = Vector2(side * (w * 0.5 - rng.randf_range(28.0, 60.0)),
				mat_top - ftex.get_height() * sc * 0.30)
			art.add_child(sp)
	else:
		_warn_once("flower", "ArenaRenderer: no decal_flower_white yet — flowers skipped")

# ============================== BOUNCE FX (brief §2, code FX) ==============================

func _on_surface_bounced(surface: Object, _player: Node, n: Vector2, contact: Vector2) -> void:
	var info: Dictionary = _surfaces.get(surface, {})
	if info.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(info["last_ms"]) < 100:
		return   # throttle: resting contact would flood tweens
	info["last_ms"] = now
	var tier := str(info["tier"])
	var primary: Color = TIERS.get(tier, TIERS["marshmallow"])["primary"]
	var art: Node2D = info["art"]
	if tier == "bumper":
		if is_instance_valid(art):
			var sq := Vector2(1.06, 0.92) if absf(n.y) >= absf(n.x) else Vector2(0.92, 1.06)
			art.position = -n * 10.0
			art.scale = sq
			var tw: Tween = art.create_tween().set_parallel(true)
			tw.tween_property(art, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(art, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_ring_flash(contact, primary)
		return
	# whole-body soft squash (grass reacts too, gently)
	if is_instance_valid(art):
		art.scale = Vector2(1.04, 0.95)
		var tw2: Tween = art.create_tween()
		tw2.tween_property(art, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# mat squash-stretch pulse, per tier
	var pivot: Node2D = info["mat"]
	if is_instance_valid(pivot):
		match tier:
			"marshmallow":   # slow deep squash + tiny white puff
				pivot.scale = Vector2(1.12, 0.7)
				var tm: Tween = pivot.create_tween()
				tm.tween_property(pivot, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				_puff(contact)
			"spring":        # overshoot stretch + metallic glint
				pivot.scale = Vector2(0.94, 1.25)
				var ts: Tween = pivot.create_tween()
				ts.tween_property(pivot, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				_glint(contact)
			_:               # standard pulse: y 0.8 -> 1.05 -> 1.0, 0.12s
				pivot.scale = Vector2(1.06, 0.8)
				var tp: Tween = pivot.create_tween()
				tp.tween_property(pivot, "scale", Vector2(0.98, 1.05), 0.07)
				tp.tween_property(pivot, "scale", Vector2.ONE, 0.05)
	_ring_flash(contact, primary)

## Tier-colored expanding ring flash (primary hex, additive, 0.2s).
func _ring_flash(contact: Vector2, col: Color) -> void:
	var ring := Line2D.new()
	ring.closed = true
	var pts := PackedVector2Array()
	for i in range(32):
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)))
	ring.points = pts
	ring.width = 0.16
	ring.default_color = Color(col, 0.9)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = m
	ring.z_index = 6
	ring.scale = Vector2(22.0, 16.0)
	add_child(ring)
	ring.global_position = contact
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(95.0, 62.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "default_color:a", 0.0, 0.2)
	tw.chain().tween_callback(ring.queue_free)

## Marshmallow: tiny white puff particles.
func _puff(contact: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 9
	p.lifetime = 0.35
	p.direction = Vector2.UP
	p.spread = 65.0
	p.gravity = Vector2(0, 350)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 190.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.98, 0.95, 0.85))
	grad.set_color(1, Color(1.0, 0.92, 0.9, 0.0))
	p.color_ramp = grad
	p.z_index = 6
	add_child(p)
	p.global_position = contact
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)

## Spring: quick metallic glint sparkle.
func _glint(contact: Vector2) -> void:
	var d := Polygon2D.new()
	d.polygon = PackedVector2Array([Vector2(0, -14), Vector2(5, 0), Vector2(0, 14), Vector2(-5, 0)])
	d.color = Color(1.0, 1.0, 1.0, 0.95)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	d.material = m
	d.z_index = 6
	d.scale = Vector2(0.4, 0.4)
	add_child(d)
	d.global_position = contact + Vector2(randf_range(-30.0, 30.0), -6.0)
	var tw := d.create_tween().set_parallel(true)
	tw.tween_property(d, "scale", Vector2(1.4, 1.4), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "rotation", 0.8, 0.15)
	tw.tween_property(d, "color:a", 0.0, 0.15)
	tw.chain().tween_callback(d.queue_free)

# ============================== helpers ==============================

func _rounded_rect_poly(w: float, h: float, r: float, col: Color) -> Polygon2D:
	r = clampf(r, 2.0, minf(w, h) * 0.5)
	var pts := PackedVector2Array()
	var centers := [Vector2(w * 0.5 - r, -h * 0.5 + r), Vector2(w * 0.5 - r, h * 0.5 - r),
		Vector2(-w * 0.5 + r, h * 0.5 - r), Vector2(-w * 0.5 + r, -h * 0.5 + r)]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in range(4):
		for i in range(7):
			var a: float = starts[c] + (PI * 0.5) * (float(i) / 6.0)
			pts.append((centers[c] as Vector2) + Vector2(cos(a), sin(a)) * r)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = col
	return poly

func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(msg)
