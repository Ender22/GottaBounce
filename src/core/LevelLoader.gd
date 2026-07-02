class_name LevelLoader
## Loads a JSON level (INV-7) into a scene under `parent`. v0 uses a 'platforms' convenience layer
## (rectangles + tier); the full palette/grid (GAME_DESIGN §15) is formalized later. Bounce surfaces
## carry their tier via metadata so the body-agnostic BounceResolver (INV-2) can read them.
## Returns { "spawns": Array[Vector2], "bounds": Rect2 }.
##
## Visuals: ALL platform / wall / background painting is delegated to ArenaRenderer ("Glossy
## Toybox", docs/briefs/arena_rendering.md). JSON stays authoritative for gameplay — colliders are
## built here exactly as authored; the renderer only draws art around them. Out-of-scope object
## types (powerups, props, bombs, structures, gravity sources, movers) are stubbed: push_warning + skip.

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

	# The renderer owns every pixel: background stack first, then per-platform art below.
	var renderer := ArenaRenderer.new()
	renderer.name = "ArenaRenderer"
	parent.add_child(renderer)
	renderer.setup(json)

	var play_rect := Rect2()
	var first := true
	for p in json.get("platforms", []):
		_build_platform(p, parent, renderer)
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

static func _build_platform(p: Dictionary, parent: Node2D, renderer: ArenaRenderer) -> void:
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
	if tier == "bumper":
		body.set_meta("bumper", true)
	else:
		body.set_meta("bounce_tier_height", Tuning.bounce_height_for(StringName(tier)))
	parent.add_child(body)
	renderer.paint_platform(p, body)   # display-only; collider above is authoritative

## Sky/background painting lives in ArenaRenderer (7-layer parallax stack per the art brief).

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
