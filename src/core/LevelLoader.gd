class_name LevelLoader
## Loads a JSON level (INV-7) into a scene under `parent`. v0 uses a 'platforms' convenience layer
## (rectangles + tier); the full palette/grid (GAME_DESIGN §15) is formalized later. Bounce surfaces
## carry their tier via metadata so the body-agnostic BounceResolver (INV-2) can read them.
## Returns { "spawns": Array[Vector2], "bounds": Rect2 }.
##
## v0 port note: platform visuals are clean code-drawn Polygon2D blocks (no TileRenderer / placeholder
## textures yet — real art wiring returns with the art pipeline). Out-of-scope object types
## (powerups, props, bombs, structures, gravity sources, movers) are stubbed: push_warning + skip.

const TIER_COLORS := {
	"marshmallow": Color(0.96, 0.86, 0.90),
	"bubblegum":   Color(0.95, 0.55, 0.75),
	"trampoline":  Color(0.40, 0.70, 1.00),
	"spring":      Color(0.45, 0.85, 0.55),
	"bumper":      Color(0.55, 0.58, 0.65),
}

# Collision layers (ARCHITECTURE §P7): 1 players, 2 props, 3 bounce_surfaces, 4 hazards
const LAYER_SURFACES := 1 << 2   # 4
const LAYER_HAZARDS := 1 << 3    # 8

static func load_level(path: String, parent: Node2D) -> Dictionary:
	var result := { "spawns": [], "bounds": Rect2() }
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("LevelLoader: cannot open " + path)
		return result
	var json = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(json) != TYPE_DICTIONARY:
		push_error("LevelLoader: invalid JSON in " + path)
		return result

	_build_background(json, parent)
	var play_rect := Rect2()
	var first := true
	for p in json.get("platforms", []):
		_build_platform(p, parent)
		var r := Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"]))
		play_rect = r if first else play_rect.merge(r)
		first = false
	result["play_rect"] = play_rect

	for o in json.get("objects", []):
		var otype := str(o.get("type", ""))
		match otype:
			"player_spawn":
				result["spawns"].append(Vector2(o["x"], o["y"]))
			"spikes":
				_build_spikes(o, parent)
			"powerup_spawner", "physics_prop", "bomb", "container", "physics_structure", \
			"gravity_source", "moving_platform", "crusher", "fan":
				# v0: these entity types are not ported yet — skip cleanly so old levels still load.
				push_warning("LevelLoader: '%s' not ported in v0 — skipped (%s)" % [otype, path])
			_:
				push_warning("LevelLoader: unknown object type '%s' in %s" % [otype, path])

	if json.has("bounds"):
		var b = json["bounds"]
		result["bounds"] = Rect2(b["left"], b["top"], b["right"] - b["left"], b["bottom"] - b["top"])
	result["objects_raw"] = json.get("objects", [])   # so modes can read custom objects (campaign etc.)
	return result

static func _rect_polygon(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)
	])

static func _build_platform(p: Dictionary, parent: Node2D) -> void:
	var w: float = p["w"]
	var h: float = p["h"]
	var tier := str(p.get("tier", "marshmallow"))
	var body := StaticBody2D.new()
	body.position = Vector2(p["x"] + w * 0.5, p["y"] + h * 0.5)
	body.collision_layer = LAYER_SURFACES
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	body.add_child(cs)
	# Visual parented under a scalable node so a bounce can squash it without moving the collision
	# shape. v0: clean flat-color block + darker border cap (TileRenderer art wiring returns later).
	var vis := Node2D.new()
	body.add_child(vis)
	body.set_meta("vis", vis)
	var col: Color = TIER_COLORS.get(tier, TIER_COLORS["marshmallow"])
	var block := Polygon2D.new()
	block.polygon = _rect_polygon(w, h)
	block.color = col.darkened(0.35)
	vis.add_child(block)
	if tier == "bumper":
		body.set_meta("bumper", true)
		block.color = col   # walls: solid stone-grey, clearly not a bounce pad
	else:
		body.set_meta("bounce_tier_height", Tuning.bounce_height_for(StringName(tier)))
		# bright bounce-cap strip on the top face so pads read as bouncy
		var cap := Polygon2D.new()
		var cap_h: float = minf(18.0, h * 0.35)
		cap.polygon = PackedVector2Array([
			Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
			Vector2(w * 0.5, -h * 0.5 + cap_h), Vector2(-w * 0.5, -h * 0.5 + cap_h)
		])
		cap.color = col
		vis.add_child(cap)
	parent.add_child(body)

## Sky: deep color up high -> light at the horizon. Pure code-drawn gradient (no textures in v0);
## covers a padded area so a zoomed-out camera never reveals void.
static func _build_background(json: Dictionary, parent: Node2D) -> void:
	if not json.has("bounds"):
		return
	var b = json["bounds"]
	var pad := 2200.0
	var left: float = float(b["left"]) - pad
	var top: float = float(b["top"]) - pad
	var right: float = float(b["right"]) + pad
	var bottom: float = float(b["bottom"]) + pad
	var play_top: float = float(b["top"])
	var play_bottom: float = float(b["bottom"])
	var bg := Node2D.new()
	bg.z_index = -100
	var sky_top := str(json.get("sky_top", "#3a6ea5"))
	var sky_bot := str(json.get("sky_bottom", "#bfe3ff"))
	# base fill over the whole padded area
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)])
	fill.color = Color(sky_bot)
	bg.add_child(fill)
	# deep top color above the visible band
	var g_top := play_top - 300.0
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, g_top), Vector2(left, g_top)])
	cap.color = Color(sky_top)
	bg.add_child(cap)
	# vertical gradient mapped to the VISIBLE play height: deep sky up top, warm at the horizon
	var grad := Polygon2D.new()
	grad.polygon = PackedVector2Array([Vector2(left, g_top), Vector2(right, g_top), Vector2(right, play_bottom), Vector2(left, play_bottom)])
	grad.vertex_colors = PackedColorArray([Color(sky_top), Color(sky_top), Color(sky_bot), Color(sky_bot)])
	bg.add_child(grad)
	parent.add_child(bg)

static func _build_spikes(o: Dictionary, parent: Node2D) -> void:
	var w: float = o.get("w", 64)
	var h: float = o.get("h", 32)
	var area := Hazard.new()   # instakill (sets its own mask + connects body_entered)
	area.position = Vector2(o["x"] + w * 0.5, o["y"] + h * 0.5)
	area.collision_layer = LAYER_HAZARDS
	area.set_meta("hazard", true)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	area.add_child(cs)
	var vis := Polygon2D.new()
	vis.polygon = _rect_polygon(w, h)
	vis.color = Color(0.90, 0.20, 0.20)
	area.add_child(vis)
	parent.add_child(area)
