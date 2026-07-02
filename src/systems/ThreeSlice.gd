class_name ThreeSlice
## 3-slice sprite builder (art brief docs/briefs/arena_rendering.md §1).
## Caps NEVER stretch non-uniformly (uniform scale = target across-height / source height).
## The center is TILED, not stretched: N center copies share one horizontal correction factor,
## clamped to 0.85-1.20 per tile (never past 1.25 — add a tile instead). When the target is
## narrower than one comfortable tile, the quiet center slice is CROPPED (region), never squashed.
## Never mirror-flips tiles (all art is lit top-left).
## Returns a Node2D whose origin is the CENTER of the target rect.

const CORR_MIN := 0.85
const CORR_MAX := 1.20

static func build(tex: Texture2D, target_w: float, target_h: float, cap_frac: float,
		vertical: bool = false, tint: Color = Color.WHITE) -> Node2D:
	var root := Node2D.new()
	if tex == null or target_w <= 0.0 or target_h <= 0.0:
		return root
	var src: Vector2 = tex.get_size()
	var along_src: float = src.y if vertical else src.x
	var across_src: float = src.x if vertical else src.y
	var along_tgt: float = target_h if vertical else target_w
	var across_tgt: float = target_w if vertical else target_h
	var s := across_tgt / across_src          # uniform cap scale (across axis is authoritative)
	var cap_src := along_src * cap_frac
	var cap_len := cap_src * s

	# Segments: { off: src offset along, len: src length, k: along correction, pos: world pos along }.
	# Center tiles are listed FIRST and caps LAST so caps draw on top and hide the tile-run edges.
	var tiles: Array = []
	var caps: Array = []
	if along_tgt <= 2.0 * cap_len + 0.5:
		# Too narrow for two full caps: crop the caps' inner edges; outer organic edges stay intact.
		var half_src := (along_tgt * 0.5) / s
		caps.append({ "off": 0.0, "len": half_src, "k": 1.0, "pos": 0.0 })
		caps.append({ "off": along_src - half_src, "len": half_src, "k": 1.0, "pos": along_tgt * 0.5 })
	else:
		caps.append({ "off": 0.0, "len": cap_src, "k": 1.0, "pos": 0.0 })
		caps.append({ "off": along_src - cap_src, "len": cap_src, "k": 1.0, "pos": along_tgt - cap_len })
		var center_src := along_src - 2.0 * cap_src
		var tile := center_src * s
		# run the tiles 2px under each cap so the caps cover the run's cut edges
		var overlap := minf(2.0, cap_len * 0.25)
		var span := (along_tgt - 2.0 * cap_len) + 2.0 * overlap
		var pos := cap_len - overlap
		var n := maxi(1, roundi(span / tile))
		var k := span / (float(n) * tile)
		if k > CORR_MAX:
			n += 1
			k = span / (float(n) * tile)
		if k >= CORR_MIN and k <= CORR_MAX:
			for i in range(n):
				tiles.append({ "off": cap_src, "len": center_src, "k": k, "pos": pos })
				pos += tile * k
		else:
			# Narrower than one comfortable tile: full tiles at 1.0 + one CROPPED partial from the
			# middle of the (deliberately quiet) center slice. Cropping is not stretching.
			var n_full := int(span / tile)
			for i in range(n_full):
				tiles.append({ "off": cap_src, "len": center_src, "k": 1.0, "pos": pos })
				pos += tile
			var rem := span - float(n_full) * tile
			if rem > 0.5:
				var rem_src := rem / s
				tiles.append({ "off": cap_src + (center_src - rem_src) * 0.5, "len": rem_src, "k": 1.0, "pos": pos })

	for seg in tiles + caps:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.region_enabled = true
		sp.modulate = tint
		if vertical:
			sp.region_rect = Rect2(0.0, seg["off"], src.x, seg["len"])
			sp.position = Vector2(-target_w * 0.5, -target_h * 0.5 + seg["pos"])
			sp.scale = Vector2(s, s * seg["k"])
		else:
			sp.region_rect = Rect2(seg["off"], 0.0, seg["len"], src.y)
			sp.position = Vector2(-target_w * 0.5 + seg["pos"], -target_h * 0.5)
			sp.scale = Vector2(s * seg["k"], s)
		root.add_child(sp)
	return root

## Whole-sprite draw (the ±20% aspect exception, §1): uniform scale by height with a ≤10%
## non-uniform width fudge. Returns null if the fudge can't cover the target width.
static func build_whole(tex: Texture2D, target_w: float, target_h: float) -> Node2D:
	if tex == null:
		return null
	var src: Vector2 = tex.get_size()
	var native := src.x / src.y
	var want := target_w / target_h
	if absf(want / native - 1.0) > 0.20:
		return null
	var sy := target_h / src.y
	var sx := clampf(target_w / src.x, sy * 0.9, sy * 1.1)
	var root := Node2D.new()
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.scale = Vector2(sx, sy)
	root.add_child(sp)
	return root
