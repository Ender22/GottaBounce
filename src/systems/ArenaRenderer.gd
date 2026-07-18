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

# --- painted backdrops (docs/briefs/painted_backdrops_2026-07-18.md) ---
# One big AI-painted sky+abyss composition per theme (no seam possible). Per painting id:
#   path        — full-bleed OPAQUE 1536x1024 painting (sky above ~horizon_frac, abyss below)
#   horizon_frac— vertical fraction of the image where the horizon sits; pinned to the arena floor_y
#   fill        — the void's 4-stop bottomless-fill ramp (mouth -> near-black), IN the painting's hue
#                 (recolors the old hardcoded sage->navy so the abyss scrim belongs to the painting)
#   wall_top/deep/strata — the receding dirt-wall triple, retinted per theme (browns/iron/indigo rock)
# Missing file -> _warn_once + today's gradient/void behavior (never a black screen). meadow_day carries
# the SHIPPED grass values verbatim (default palette) so unpainted/meadow levels never regress.
const PAINTINGS := {
	"meadow_day": {
		"path": "res://assets/bg/sky_grass_day.png", "horizon_frac": 0.58,
		"fill": ["#2B5140", "#143A46", "#0E2536", "#060E18"],
		"wall_top": "#6E4126", "wall_deep": "#241408", "wall_strata": "#2A1810" },
	"space_nebula": {
		"path": "res://assets/bg/painting_space_nebula.png", "horizon_frac": 0.58,
		"fill": ["#1A2050", "#10163C", "#0A0E28", "#05081A"],
		"wall_top": "#3A3A5E", "wall_deep": "#0B0C22", "wall_strata": "#17173A" },
	"ember_foundry": {
		"path": "res://assets/bg/painting_ember_foundry.png", "horizon_frac": 0.55,
		"fill": ["#3A241A", "#2A160E", "#1C0E08", "#120A06"],
		"wall_top": "#5A3320", "wall_deep": "#1C0E06", "wall_strata": "#2A1408" },
	"dusk_gold": {
		"path": "res://assets/bg/painting_dusk_gold.png", "horizon_frac": 0.60,
		"fill": ["#3A2740", "#2A1B2E", "#1E1220", "#160F14"],
		"wall_top": "#6E4A38", "wall_deep": "#241610", "wall_strata": "#2E1C18" },
	"overcast_quarry": {
		"path": "res://assets/bg/painting_overcast_quarry.png", "horizon_frac": 0.58,
		"fill": ["#4A463E", "#35322C", "#22201A", "#14120F"],
		"wall_top": "#6A6258", "wall_deep": "#22201A", "wall_strata": "#33302A" },
}

# --- kill-line telegraph (painted_backdrops_2026-07-18.md §3): a taut wire + slow-pulsing danger
# glow band + fewer/larger matte chevrons. Hazard red is RESERVED to this line only. ---
const HAZARD_RED := Color("#E6402C")
const KILL_RIM_PX := 3.0            # core rim thickness (was 6) — a wire, not a plank
const KILL_RIM_ALPHA := 0.85
const KILL_GLOW_BAND_PX := 36.0     # danger glow: haz -> transparent over this many world px (the main read)
const KILL_GLOW_PERIOD := 1.6       # sine pulse period (s)
const KILL_GLOW_A_MIN := 0.25
const KILL_GLOW_A_MAX := 0.55
const KILL_CHEVRON_SPACING := 260.0 # world px between chevrons (was 90)
const KILL_CHEVRON_W := 44.0        # full chevron width (was 16)
const KILL_CHEVRON_H := 26.0        # chevron height (was 11)
const KILL_CHEVRON_OUTLINE := Color("#7A1E14")

var _layers: Array = []      # parallax: { node, factor: float, base: Vector2 }
var _anchor := Vector2.ZERO  # camera anchor (play-rect center): layers sit at base when cam is here
var _clouds: Array = []      # { node, speed, min_x, max_x }
var _twinkles: Array = []    # { node, speed, phase, max_a }
var _springs: Array = []     # { pivot, next_t } idle shimmer (springs only — motion must mean something)
var _danger_glows: Array = []  # kill-line glow band sprites (slow additive alpha pulse)
var _void_palette := {}      # resolved abyss/wall colors for paint_void (from the painting manifest)
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
	var play_rect: Rect2 = play if not first else brect
	# Backdrop mode (docs/briefs/enclosed_interior_backdrop.md): absent / "meadow" / "parallax" =
	# current meadow-parallax behavior (back-compat); "enclosed" = sealed-drum interior treatment.
	# Orthogonal to kill_shape by design — keyed off its OWN field.
	var backdrop := str(json.get("backdrop", "meadow"))
	# Resolve the void/abyss recolor palette (painted_backdrops §4) BEFORE painting anything. Defaults
	# to the shipped grass values (meadow_day) so unpainted/meadow levels are byte-identical to before.
	_void_palette = _resolve_void_palette(json)
	_build_background(json, brect, floor_y, backdrop, play_rect)

## Resolve the abyss fill + dirt-wall colors paint_void uses, from the level's backdrop_painting knob.
## Missing/unknown id -> meadow_day (the shipped grass ramp) so nothing regresses.
func _resolve_void_palette(json: Dictionary) -> Dictionary:
	var id := str(json.get("backdrop_painting", ""))
	var m: Dictionary = PAINTINGS.get(id, PAINTINGS["meadow_day"])
	var fill := PackedColorArray()
	for h in m["fill"]:
		fill.append(Color(str(h)))
	var wt := Color(str(m["wall_top"]))
	return {
		"fill": fill,
		"wall_top": wt,
		"wall_deep": Color(str(m["wall_deep"])),
		"wall_strata": Color(str(m["wall_strata"])),
		"wall_hi": wt.lightened(0.22),
		"ao": fill[3],   # near-black theme hue doubles as the under-lip overhang shadow
	}

# ============================== BACKGROUND (brief §3) ==============================

func _build_background(json: Dictionary, brect: Rect2, floor_y: float, backdrop: String, play_rect: Rect2) -> void:
	var enclosed := backdrop == "enclosed"
	var open_sky := backdrop == "open_sky"

	# Layer 0 — code sky gradient, world-static safety net covering everything (visible only past
	# art edges / extreme zoom-out). In enclosed mode this becomes the Zone-A dark HOUSING that shows
	# above the lid + outside the walls (driven by sky_top/sky_bottom, unchanged path).
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

	# Enclosed backdrop (Zone B interior shell): suppress the entire meadow parallax stack below and
	# paint a dim glossy interior clipped to the play AABB instead. paint_void() still draws on top.
	if enclosed:
		_build_enclosed_interior(play_rect)
		return

	# Open-sky backdrop (docs/briefs/circuit_theming_plan.md §3.1): suppress the meadow PNG parallax
	# (Layers 1/2/4) so the Layer-0 sky_top/sky_bottom gradient above IS the whole sky; keep only the
	# cheap code atmospherics (clouds + twinkles). Same early-return pattern as enclosed — the meadow /
	# enclosed / absent paths below are never touched.
	if open_sky:
		_build_open_sky(json, brect, floor_y)
		return

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

## Enclosed backdrop (docs/briefs/enclosed_interior_backdrop.md §2/§4): a dim glossy interior shell
## clipped to the play AABB. Everything ABOVE the lid / OUTSIDE the walls stays the Zone-A surround
## (the Layer-0 gradient) for free, because this is clipped to play_rect. All code-drawn gradients
## (same toolkit as paint_void) — no assets, adapts to any axis-aligned enclosed box. World-static
## (added directly, not a parallax layer). paint_void() draws on top at z >= -8.
func _build_enclosed_interior(play_rect: Rect2) -> void:
	if play_rect.size.x <= 0.0 or play_rect.size.y <= 0.0:
		return
	# grow a touch so the shell meets the inner wall faces / lid underside with no seam
	var shell := play_rect.grow(16.0)

	# Zone B — dim mossy-teal vertical interior gradient (a hair lighter than the surround), z -92.
	var bg := Gradient.new()
	bg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	bg.colors = PackedColorArray([Color("#2C4A44"), Color("#21403C"), Color("#18332F")])
	add_child(_gradient_sprite(shell, bg, GradientTexture2D.FILL_LINEAR,
		Vector2(0, 0), Vector2(0, 1), Vector2i(4, 256), -92))

	# Gloss sheen — soft white radial highlight near the upper-centre (curved-plastic tell), z -91.
	# A wide ellipse: ~70% interior width x ~45% interior height, centred at ~30% height.
	var sheen_w := shell.size.x * 0.70
	var sheen_h := shell.size.y * 0.45
	var sheen_c := shell.get_center()
	var sheen_rect := Rect2(sheen_c.x - sheen_w * 0.5,
		shell.position.y + shell.size.y * 0.30 - sheen_h * 0.5, sheen_w, sheen_h)
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 1.0])
	sg.colors = PackedColorArray([Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.0)])
	add_child(_gradient_sprite(sheen_rect, sg, GradientTexture2D.FILL_RADIAL,
		Vector2(0.5, 0.5), Vector2(1.0, 0.5), Vector2i(256, 256), -91))

	# Vignette — radial darkening (transparent centre -> #0A1720 a0.45 in the corners), sells the
	# cylinder curvature + focuses the centre. Over the interior, z -91 (above shell, below platforms).
	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.0, 1.0])
	var vc := Color("#0A1720")
	vg.colors = PackedColorArray([Color(vc.r, vc.g, vc.b, 0.0), Color(vc.r, vc.g, vc.b, 0.45)])
	add_child(_gradient_sprite(shell, vg, GradientTexture2D.FILL_RADIAL,
		Vector2(0.5, 0.5), Vector2(1.0, 1.0), Vector2i(256, 256), -91))

## Open-sky backdrop (docs/briefs/circuit_theming_plan.md §3.1): the Layer-0 sky gradient (driven by
## sky_top/sky_bottom, painted before this call) IS the whole visible sky. This suppresses the meadow
## PNG parallax (Layer 1 sky painting, Layer 2 far hills, Layer 4 mid props) so the per-level palette
## finally reads, and keeps ONLY the cheap code atmospherics (Layer 3 clouds + twinkles). Three lean
## OPTIONAL params, all defaulting to current/off for back-compat, consumed only here:
##   clouds (bool, default true)         — false skips the drifting cloud sprites (smog / void reads).
##   horizon_glow (bool|color, off)      — a soft warm code-drawn glow band low in the sky (dusk/golden).
##   stars (bool, default off)           — denser/brighter twinkles as a starfield (twilight spires).
## World-static + parallax layers only (same toolkit as the meadow path) — zero generated art.
func _build_open_sky(json: Dictionary, brect: Rect2, floor_y: float) -> void:
	# Painted backdrop (painted_backdrops_2026-07-18.md §4): one big AI-painted sky+abyss composition,
	# scaled-to-cover, its horizon pinned to floor_y, parallax 0.05, extended below into the abyss. The
	# Layer-0 sky_top/sky_bottom gradient stays behind it as the safety net + missing-file fallback.
	var painted := _build_painting_backdrop(json, brect, floor_y)

	# Optional horizon glow — behind the atmospherics, above the Layer-0 sky gradient. Accepts a hex
	# string (custom warm color) or a bool (true = default golden amber); anything falsy = off. FORCED
	# OFF on painted levels (the glow is baked into the painting — §4).
	var hg: Variant = json.get("horizon_glow", false)
	var glow_on := false
	var glow_col := Color("#F2B15E")   # default warm golden-hour amber (used only if enabled sans hex)
	if hg is String:
		if str(hg) != "" and str(hg) != "false":
			glow_on = true
			glow_col = Color(str(hg))
	elif hg is bool:
		glow_on = hg
	if glow_on and not painted:
		_build_horizon_glow(brect, floor_y, glow_col)

	var want_clouds := bool(json.get("clouds", true))
	var stars_on := bool(json.get("stars", false))

	# Layer 3 — code atmospherics only (no meadow PNGs). Drifting clouds (unless clouds=false) +
	# twinkling diamonds (brighter/denser when stars=true so they read as a starfield). Mirrors the
	# meadow Layer-3 code so clouds/twinkles behave identically; only counts/brightness differ on stars.
	var cloud_node := Node2D.new()
	cloud_node.z_index = -85
	cloud_node.modulate = AERIAL
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("toybox_clouds")
	if want_clouds:
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

	# twinkles reuse the meadow diamond system. stars=true => more of them + brighter, white (a
	# starfield); otherwise identical to the meadow layer (5 faint tier-support diamonds).
	var support: Array = [TIERS["marshmallow"]["support"], TIERS["bubblegum"]["support"],
		TIERS["trampoline"]["support"], TIERS["spring"]["support"]]
	var twinkle_n := 18 if stars_on else 5
	var twinkle_a := 0.7 if stars_on else 0.35
	for i in range(twinkle_n):
		var d := Polygon2D.new()
		var s: float = rng.randf_range(5.0, 10.0) if stars_on else rng.randf_range(7.0, 13.0)
		d.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s * 0.4, 0), Vector2(0, s), Vector2(-s * 0.4, 0)])
		var col: Color = Color(1, 1, 1) if stars_on else support[i % support.size()]
		col.a = 0.0
		d.color = col
		d.position = Vector2(rng.randf_range(-brect.size.x * 0.45, brect.size.x * 0.45),
			floor_y - rng.randf_range(350.0, 1200.0))
		cloud_node.add_child(d)
		_twinkles.append({ "node": d, "speed": rng.randf_range(0.5, 1.1),
			"phase": rng.randf_range(0.0, TAU), "max_a": twinkle_a })
	_add_layer(cloud_node, 0.30, Vector2(_anchor.x, 0.0))

## Soft warm horizon glow band (docs/briefs/circuit_theming_plan.md §3.2) for golden-hour / dusk
## open-sky levels. Code-drawn only — a 3-stop vertical GradientTexture2D band (transparent -> warm
## -> transparent) sitting low in the frame. World-static like the Layer-0 sky gradient, painted just
## above it (z -94) and below the cloud/twinkle atmospherics. Same toolkit as paint_void / enclosed.
func _build_horizon_glow(brect: Rect2, floor_y: float, col: Color) -> void:
	var pad := 2600.0
	var band_w := brect.size.x + pad * 2.0
	var band_h := maxf(600.0, brect.size.y * 0.5)
	var band_rect := Rect2(brect.position.x - pad, floor_y - band_h * 0.65, band_w, band_h)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.0),
		Color(col.r, col.g, col.b, 0.5), Color(col.r, col.g, col.b, 0.0)])
	add_child(_gradient_sprite(band_rect, grad, GradientTexture2D.FILL_LINEAR,
		Vector2(0, 0), Vector2(0, 1), Vector2i(4, 256), -94))

## Painted backdrop (painted_backdrops_2026-07-18.md §4): load the theme's single sky+abyss painting,
## scale-to-cover the view at max zoom-out (same math as the shipped meadow Layer-1 sky), pin the
## painting's baked horizon line (horizon_frac) to the arena floor_y, park it as a parallax-0.05 layer
## behind the atmospherics, and _extend_below its own near-black bottom row into the abyss so no seam
## can show at any depth. Returns true if a painting was placed; false (missing file / no knob) leaves
## the Layer-0 gradient + code atmospherics exactly as today. Optional painting_tint hex modulates it.
func _build_painting_backdrop(json: Dictionary, brect: Rect2, floor_y: float) -> bool:
	var id := str(json.get("backdrop_painting", ""))
	if id == "" or not PAINTINGS.has(id):
		return false
	var m: Dictionary = PAINTINGS[id]
	var path := str(m["path"])
	if not ResourceLoader.exists(path):
		_warn_once("painting_" + id, "ArenaRenderer: missing painting " + path + " — gradient fallback")
		return false
	var tex: Texture2D = load(path)
	if tex == null or tex.get_width() <= 0:
		_warn_once("painting_" + id, "ArenaRenderer: unreadable painting " + path + " — gradient fallback")
		return false
	var need := MAX_VIEW * 1.1
	var sc := maxf(need.x / tex.get_width(), need.y / tex.get_height())
	var node := Node2D.new()
	node.z_index = -95
	var tint := str(json.get("painting_tint", ""))
	if tint != "":
		node.modulate = Color(tint)
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.scale = Vector2(sc, sc)
	node.add_child(sp)
	var sky_h := tex.get_height() * sc
	var hf: float = float(m.get("horizon_frac", 0.58))
	# sprite is centered: image top sits at local -sky_h/2, the horizon line at local (hf-0.5)*sky_h.
	# pin that horizon world-y to floor_y => node origin (sprite center) world-y = floor_y + (0.5-hf)*sky_h.
	var base := Vector2(_anchor.x, floor_y + (0.5 - hf) * sky_h)
	# extend the painting's own near-black bottom row from its bottom edge (local +sky_h/2) down past the
	# arena bottom, in the node's LOCAL space (world_bottom - base.y). Guarantees no gradient seam below.
	var pad := 2600.0
	_extend_below(node, tex, Vector2(0.0, sky_h * 0.5 - 4.0), tex.get_width() * sc,
		(brect.end.y + pad) - base.y)
	_add_layer(node, 0.05, base)
	return true

## Build a world-static gradient sprite covering `rect`, backed by a GradientTexture2D (same toolkit
## paint_void's fill uses). `size` is the texture resolution (small on the flat axis for linear fills).
func _gradient_sprite(rect: Rect2, grad: Gradient, fill: int, fill_from: Vector2, fill_to: Vector2,
		tex_size: Vector2i, z: int) -> Sprite2D:
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = fill
	gtex.fill_from = fill_from
	gtex.fill_to = fill_to
	gtex.width = tex_size.x
	gtex.height = tex_size.y
	var sp := Sprite2D.new()
	sp.texture = gtex
	sp.centered = false
	sp.position = rect.position
	sp.scale = Vector2(rect.size.x / float(gtex.width), rect.size.y / float(gtex.height))
	sp.z_index = z
	return sp

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
	# kill-line danger glow: slow additive alpha pulse (KILL_GLOW_A_MIN..MAX over KILL_GLOW_PERIOD),
	# the only slow pulse in the scene so its motion reads as "active hazard" over any painting.
	if not _danger_glows.is_empty():
		var mid := (KILL_GLOW_A_MAX + KILL_GLOW_A_MIN) * 0.5
		var amp := (KILL_GLOW_A_MAX - KILL_GLOW_A_MIN) * 0.5
		var ga := mid + amp * sin(_t * TAU / KILL_GLOW_PERIOD)
		for g in _danger_glows:
			if is_instance_valid(g):
				(g as Node2D).modulate.a = ga
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
func paint_platform(p: Dictionary, body: StaticBody2D, void_rects: Array = []) -> void:
	var w: float = p["w"]
	var h: float = p["h"]
	var tier := str(p.get("tier", "marshmallow"))
	var top := -h * 0.5
	# pit_void_rendering.md §6.3: a cap within ~50px of a void edge is a DEATH edge — suppress its
	# cheerful tuft+daisy so a flower never blooms at the lip of a lethal pit.
	var plat_left: float = float(p["x"])
	var plat_right: float = plat_left + w
	var suppress_left := false
	var suppress_right := false
	for vr in void_rects:
		var vrect: Rect2 = vr
		for vedge in [vrect.position.x, vrect.end.x]:
			if absf(plat_left - float(vedge)) <= 50.0:
				suppress_left = true
			if absf(plat_right - float(vedge)) <= 50.0:
				suppress_right = true
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

	_scatter_end_decals(art, w, mat_top, rng, suppress_left, suppress_right)   # tufts + flowers (skipped at a void lip)
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
## suppress_left/suppress_right skip the tuft+flower on a cap that sits at a lethal-void lip
## (pit_void_rendering.md §6.3) — no cheerful greenery at a death edge.
func _scatter_end_decals(art: Node2D, w: float, mat_top: float, rng: RandomNumberGenerator,
		suppress_left := false, suppress_right := false) -> void:
	var tufts := _tuft_textures()
	if not tufts.is_empty():
		for side in [-1.0, 1.0]:
			if (side < 0.0 and suppress_left) or (side > 0.0 and suppress_right):
				continue
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
			if (side < 0.0 and suppress_left) or (side > 0.0 and suppress_right):
				continue
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

# ============================== LETHAL VOID (pit_void_rendering.md) ==============================

## Paint a stylized cartoon lethal-void into the pit gap (pit_void_rendering.md). 100% code-drawn
## (gradients + polygons + one CPUParticles2D) — no art assets, so it adapts to any pit width/theme.
## Display-only: NO collider (the kill stays the bounds-bottom line). Four cues, back-to-front:
## bottomless cool gradient fill, receding dirt walls, under-lip AO, falling motes, then the hot
## hazard LIP accent ON TOP. z-order (§4): fill −8, walls −7, AO −6, motes −5 (all BEHIND platform
## art so the floor dirt overhangs the top seam), lip accent +1 (sits ON the edge).
func paint_void(v: Dictionary, platforms: Array = []) -> void:
	var rim_y := float(v.get("y", 1000.0))
	var left_x := float(v.get("x", 0.0))
	var w := float(v.get("w", 560.0))
	var right_x := left_x + w
	var depth := float(v.get("h", 798.0))
	var wall_px := float(v.get("wall_px", 80.0))
	if w <= 0.0 or depth <= 0.0:
		_warn_once("void", "ArenaRenderer.paint_void: void with w/h <= 0 — skipped")
		return
	var bottom_y := rim_y + depth
	var root := Node2D.new()
	root.name = "Void"
	add_child(root)

	# --- 3a. Center bottomless fill: 4-stop cool vertical gradient, rim -> near-black navy (shared
	# with the inter-island gaps so the two look identical — §3f).
	_void_fill_sprite(root, left_x, right_x, rim_y, bottom_y)
	# solid deep-color extension below the rect to bounds.bottom+margin so no seam shows at any zoom
	var deep: Color = _void_palette["fill"][3]   # theme near-black (painting hue, was hardcoded #060E18)
	var ext := Polygon2D.new()
	ext.polygon = PackedVector2Array([
		Vector2(left_x, bottom_y), Vector2(right_x, bottom_y),
		Vector2(right_x, bottom_y + 600.0), Vector2(left_x, bottom_y + 600.0)])
	ext.color = deep
	ext.z_index = -8
	root.add_child(ext)

	# --- 3b. Receding dirt walls on each pit-facing edge (volume + "it goes down") ---
	_void_wall(root, left_x, 1.0, rim_y, bottom_y, wall_px)    # left floor's inner edge, extends right
	_void_wall(root, right_x, -1.0, rim_y, bottom_y, wall_px)  # right floor's inner edge, extends left

	# --- 3c. Under-lip AO band: the overhang shadow the grass fringe casts INTO the hole ---
	var ao := Polygon2D.new()
	ao.polygon = PackedVector2Array([
		Vector2(left_x, rim_y), Vector2(right_x, rim_y),
		Vector2(right_x, rim_y + 36.0), Vector2(left_x, rim_y + 36.0)])
	var ao_c: Color = _void_palette["ao"]   # theme overhang shadow (was hardcoded #0A1A24)
	var ao_top := Color(ao_c.r, ao_c.g, ao_c.b, 0.55)
	var ao_bot := Color(ao_c.r, ao_c.g, ao_c.b, 0.0)
	ao.vertex_colors = PackedColorArray([ao_top, ao_top, ao_bot, ao_bot])
	ao.z_index = -6
	root.add_child(ao)

	# --- 3d. Falling motes: sparse slow downward drift, fade out ("things fall in and are gone") ---
	var motes := CPUParticles2D.new()
	motes.amount = 14
	motes.lifetime = 2.5
	motes.preprocess = 2.5
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(w * 0.5 - wall_px, 8.0)
	motes.position = Vector2((left_x + right_x) * 0.5, rim_y + 12.0)
	motes.direction = Vector2.DOWN
	motes.spread = 10.0
	motes.gravity = Vector2(0.0, 30.0)
	motes.initial_velocity_min = 20.0
	motes.initial_velocity_max = 60.0
	motes.scale_amount_min = 1.5
	motes.scale_amount_max = 3.0
	var mg := Gradient.new()
	mg.offsets = PackedFloat32Array([0.0, 1.0])
	mg.colors = PackedColorArray([Color(0.812, 0.902, 0.878, 0.35), Color(0.812, 0.902, 0.878, 0.0)])
	motes.color_ramp = mg
	var mm := CanvasItemMaterial.new()
	mm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = mm
	motes.z_index = -5
	root.add_child(motes)

	# --- 3e. Hazard LIP telegraph (painted_backdrops §3): a taut wire + slow-pulsing danger glow band +
	# fewer/larger matte chevrons. Hazard red is reserved to this line only. Reads "below = death" in <1s.
	_paint_kill_line(root, left_x, right_x, rim_y, wall_px)

	# --- 3f. INNER-ISLAND chasm treatment (CD #5 P1): the void rect spans the whole bottom, but 3a/3b
	# above only line the ARENA edges, so a single inter-island gap read as a thin dark strip amid green
	# hills at combat zoom. Render each gap between the floating floor islands with the SAME fill+wall
	# path the central pit uses (identical gradient + _void_wall) so it looks exactly like a central pit
	# — flush cliff walls descending from each island's underside, darkest at the center. Generic to any
	# void_is_floor level, so the whole circuit inherits a consistent chasm read at ALL zooms.
	_paint_void_gaps(root, platforms, rim_y, bottom_y, wall_px)

## The 4-stop cool bottomless-fill gradient (rim -> near-black navy), as a vertical GradientTexture2D
## sprite spanning [left_x,right_x] x [top_y,bottom_y]. Shared by the full-width void (3a) AND every
## inter-island gap (3f) so they are pixel-for-pixel the same treatment (darkest at the bottom center).
func _void_fill_sprite(root: Node2D, left_x: float, right_x: float, top_y: float, bottom_y: float) -> void:
	var w := right_x - left_x
	var h := bottom_y - top_y
	if w <= 0.0 or h <= 0.0:
		return
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
	grad.colors = _void_palette["fill"]   # theme mouth->near-black ramp (was hardcoded sage->navy)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)   # vertical
	gtex.width = 4
	gtex.height = 256
	var fill := Sprite2D.new()
	fill.texture = gtex
	fill.centered = false
	fill.position = Vector2(left_x, top_y)
	fill.scale = Vector2(w / 4.0, h / 256.0)
	fill.z_index = -8
	root.add_child(fill)

## Render each gap between adjacent floating FLOOR islands as a mini central-pit (not the elevated
## thrones). Same fill gradient + same _void_wall as the arena-edge pit, so a gap is visually identical
## to the grassy central pit: a canyon wall descends FLUSH from each island's underside and the fill is
## darkest at the center. The full-width fill (3a) already covers below the rim; here we fill from the
## island surface down so the gap reads as a pit from the walkable line, occluding the far-hills green.
func _paint_void_gaps(root: Node2D, platforms: Array, rim_y: float, bottom_y: float, wall_px: float) -> void:
	if platforms.size() < 2:
		return
	# Floor islands cluster near the LOWEST surface in the arena; elevated spring thrones sit far above.
	# Select platforms in the floor band that FLOAT over the void (whole body above the rim). Relative,
	# not an absolute magic y, so it generalizes across void levels (and excludes central-pit mainlands,
	# whose bodies extend BELOW the rim — grassy stays untouched).
	var max_top := -INF
	for r in platforms:
		max_top = maxf(max_top, (r as Rect2).position.y)
	const FLOOR_BAND := 360.0   # px below the lowest surface still counts as "floor" (excludes thrones)
	var isles: Array = []
	for r in platforms:
		var rect: Rect2 = r
		if rect.position.y >= max_top - FLOOR_BAND and rect.end.y <= rim_y + 4.0:
			isles.append(rect)
	if isles.size() < 2:
		return
	isles.sort_custom(func(a, b): return (a as Rect2).position.x < (b as Rect2).position.x)
	# BRIDGE THE FLOAT (CD #5 P1 root cause): each island floats above the SINGLE void rim (island A
	# bottom y1208 vs rim y1260), so the band between an island's dirt underside and the rim shows the
	# far-hills GREEN (the full-width fill 3a only starts at the rim). That green sliver beside the
	# cliffs is what made the walls read DETACHED. Fill each island's underside->rim band with the fill
	# MOUTH color so the dirt underside sits on continuous chasm — exactly like grassy, where rim ==
	# the mainland surface so no such band can exist. z=-8 (behind platform art; the dirt overhang
	# occludes the top edge, and this meets the full-width fill's top color at the rim with no seam).
	var mouth: Color = _void_palette["fill"][0]   # theme mouth hue (was hardcoded #2B5140)
	for r in isles:
		var isle: Rect2 = r
		if isle.end.y >= rim_y:
			continue
		var bl := isle.position.x - BODY_BLEED_SIDE   # cover the dirt art's side bleed so no green
		var br := isle.end.x + BODY_BLEED_SIDE        # sliver peeks under the overhang at the cliff
		var bridge := Polygon2D.new()
		bridge.polygon = PackedVector2Array([
			Vector2(bl, isle.end.y), Vector2(br, isle.end.y),
			Vector2(br, rim_y), Vector2(bl, rim_y)])
		bridge.color = mouth
		bridge.z_index = -8
		root.add_child(bridge)
	for i in range(isles.size() - 1):
		var a: Rect2 = isles[i]
		var b: Rect2 = isles[i + 1]
		var gl := a.end.x       # left cliff edge (island A right side)
		var gr := b.position.x  # right cliff edge (island B left side)
		if gr - gl < 24.0:
			continue
		var wp := minf(wall_px, (gr - gl) * 0.42)          # keep the two walls from overlapping in a tight gap
		# Dark bottomless fill with a SLANTED mouth that follows EACH island's own surface (islands can
		# differ in height): the fill's top-left sits at island A's surface, top-right at island B's, so
		# the fill + each wall meet the island exactly at its cliff top — flush, no dark band beside a
		# shorter island. Same sage->near-black value ramp as the central pit: lightest at the mouth,
		# darkest at the bottom center (occludes the far-hills green; overdraws the full-width fill below
		# the rim — the walls hide the x-seam at the cliffs).
		_void_gap_fill(root, gl, gr, a.position.y, b.position.y, bottom_y)
		# a canyon wall FLUSH against each island's cliff, descending from that island's surface (its
		# body occludes nothing here since the wall is outside the collider, so the wall top meets the
		# island's top corner exactly — identical to the arena-edge / central-pit walls).
		_void_wall(root, gl, 1.0, a.position.y, bottom_y, wp)    # island A right cliff, recedes toward gap
		_void_wall(root, gr, -1.0, b.position.y, bottom_y, wp)   # island B left cliff, recedes toward gap

## Slanted-mouth bottomless fill for one inter-island gap: the EXACT central-pit fill ramp (same 4
## stops #2B5140 -> #143A46 -> #0E2536 -> #060E18 at the same offsets) but built as a stack of banded
## quads whose top edges FOLLOW each island's surface (top_l at the left cliff, top_r at the right).
## This keeps the fill flush to islands of unequal height while darkening just as fast as the central
## pit (dark teal by the rim, near-black at the bottom center) — only a thin sage sliver at the mouth.
func _void_gap_fill(root: Node2D, gl: float, gr: float, top_l: float, top_r: float, bottom_y: float) -> void:
	var offs := [0.0, 0.18, 0.5, 1.0]
	var cols: PackedColorArray = _void_palette["fill"]   # theme ramp (was hardcoded sage->navy)
	for i in range(offs.size() - 1):
		var f0: float = offs[i]
		var f1: float = offs[i + 1]
		var band := Polygon2D.new()
		band.polygon = PackedVector2Array([
			Vector2(gl, lerpf(top_l, bottom_y, f0)), Vector2(gr, lerpf(top_r, bottom_y, f0)),
			Vector2(gr, lerpf(top_r, bottom_y, f1)), Vector2(gl, lerpf(top_l, bottom_y, f1))])
		band.vertex_colors = PackedColorArray([cols[i], cols[i], cols[i + 1], cols[i + 1]])
		band.z_index = -8
		root.add_child(band)

## One receding dirt wall panel (trapezoid tapered inward at the bottom to foreshorten) + strata
## lines + a top-inner-corner highlight. dir: +1 = edge on the left (wall extends right), -1 = right.
func _void_wall(root: Node2D, edge_x: float, dir: float, rim_y: float, bottom_y: float, wall_px: float) -> void:
	var taper := wall_px * 0.25
	var inner_x := edge_x + dir * wall_px            # edge adjacent to the center fill
	var bot_outer := edge_x + dir * taper            # outer edge insets toward center at the bottom
	var top_c: Color = _void_palette["wall_top"]     # lit dirt top (theme, was hardcoded #6E4126)
	var deep_c: Color = _void_palette["wall_deep"]   # deep dirt (theme, was hardcoded #241408)
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([
		Vector2(edge_x, rim_y), Vector2(inner_x, rim_y),
		Vector2(inner_x, bottom_y), Vector2(bot_outer, bottom_y)])
	wall.vertex_colors = PackedColorArray([top_c, top_c, deep_c, deep_c])
	wall.z_index = -7
	root.add_child(wall)
	# cartoon rock strata (thin darker horizontal layers)
	var strata_c: Color = _void_palette["wall_strata"]   # theme strata (was hardcoded #2A1810)
	for f in [0.32, 0.55, 0.78]:
		var sy := lerpf(rim_y, bottom_y, f)
		var outer := lerpf(edge_x, bot_outer, f)
		var line := Polygon2D.new()
		line.polygon = PackedVector2Array([
			Vector2(outer, sy), Vector2(inner_x, sy),
			Vector2(inner_x, sy + 4.0), Vector2(outer, sy + 4.0)])
		line.color = strata_c
		line.z_index = -7
		root.add_child(line)
	# 2px warm highlight on the top inner corner (catches the top-left light)
	var hi := Polygon2D.new()
	hi.polygon = PackedVector2Array([
		Vector2(edge_x, rim_y), Vector2(inner_x, rim_y),
		Vector2(inner_x, rim_y + 2.0), Vector2(edge_x, rim_y + 2.0)])
	hi.color = _void_palette["wall_hi"]   # theme top-corner highlight (was hardcoded #8A5A38)
	hi.z_index = -7
	root.add_child(hi)

## Kill-line telegraph (painted_backdrops_2026-07-18.md §3), across the void mouth [left_x,right_x] at
## rim_y. Three layers, all z +1 (on the lip, over the abyss, under the platform art):
##   1. core wire — thin matte hazard-red rim (KILL_RIM_PX @ KILL_RIM_ALPHA), a taut wire not a plank.
##   2. danger glow band (the MAIN read) — additive haz->transparent vertical gradient over
##      KILL_GLOW_BAND_PX, slow-pulsing alpha (registered in _danger_glows, animated in _process). The
##      only slow pulse in the scene, so its motion means "active hazard" over any painting.
##   3. chevrons — fewer/larger MATTE down-triangles on a dark-red outline (never additive), solid over
##      the glow. Hazard red is reserved to this whole line.
func _paint_kill_line(root: Node2D, left_x: float, right_x: float, rim_y: float, wall_px: float) -> void:
	# 2. danger glow band FIRST (lowest of the three, additive) — haz at the rim fading down to nothing.
	var glow_grad := Gradient.new()
	glow_grad.offsets = PackedFloat32Array([0.0, 1.0])
	glow_grad.colors = PackedColorArray([Color(HAZARD_RED, 1.0), Color(HAZARD_RED, 0.0)])
	var glow := _gradient_sprite(Rect2(left_x, rim_y, right_x - left_x, KILL_GLOW_BAND_PX),
		glow_grad, GradientTexture2D.FILL_LINEAR, Vector2(0, 0), Vector2(0, 1), Vector2i(4, 64), 0)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	glow.modulate.a = KILL_GLOW_A_MIN
	root.add_child(glow)
	_danger_glows.append(glow)

	# 1. core wire — thin matte hazard rim, tucked under the platform fringe.
	var rim := Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(left_x, rim_y - 1.0), Vector2(right_x, rim_y - 1.0),
		Vector2(right_x, rim_y - 1.0 + KILL_RIM_PX), Vector2(left_x, rim_y - 1.0 + KILL_RIM_PX)])
	rim.color = Color(HAZARD_RED, KILL_RIM_ALPHA)
	rim.z_index = 1
	root.add_child(rim)

	# 3. chevrons — spaced KILL_CHEVRON_SPACING across the walkable mouth, pointing INTO the pit.
	var span_l := left_x + wall_px * 0.5
	var span_r := right_x - wall_px * 0.5
	var n := maxi(1, int((span_r - span_l) / KILL_CHEVRON_SPACING))
	for i in range(n + 1):
		var cx := lerpf(span_l, span_r, float(i) / float(n))
		_void_chevron(root, cx, rim_y + 6.0)

## A down-pointing hazard chevron (matte red fill on a dark-red outline — NOT chocolate, NEVER additive).
func _void_chevron(root: Node2D, cx: float, cy: float) -> void:
	var cw := KILL_CHEVRON_W * 0.5
	var ch := KILL_CHEVRON_H
	var pad := 4.0
	var outline := Polygon2D.new()   # larger dark-red triangle behind = the warning outline
	outline.polygon = PackedVector2Array([
		Vector2(cx - cw - pad, cy - pad), Vector2(cx + cw + pad, cy - pad), Vector2(cx, cy + ch + pad)])
	outline.color = KILL_CHEVRON_OUTLINE
	outline.z_index = 1
	root.add_child(outline)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([
		Vector2(cx - cw, cy), Vector2(cx + cw, cy), Vector2(cx, cy + ch)])
	tri.color = Color(HAZARD_RED, 0.9)   # matte, alpha 0.9 — solid over the bright glow
	tri.z_index = 1
	root.add_child(tri)

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
