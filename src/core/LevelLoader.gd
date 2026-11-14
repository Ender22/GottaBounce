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
	var result := { "spawns": [], "bounds": Rect2(), "powerup_spawners": [] }
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

	# Void rects gathered FIRST so paint_platform can suppress cheerful decals at a death edge
	# (pit_void_rendering.md §6.3) — a daisy blooming at the lip of a lethal pit is an auto-Fix.
	var void_rects: Array = []
	for o in json.get("objects", []):
		if str(o.get("type", "")) == "void":
			void_rects.append(Rect2(float(o["x"]), float(o["y"]), float(o.get("w", 0.0)), float(o.get("h", 0.0))))

	var play_rect := Rect2()
	var first := true
	var platform_rects: Array = []   # for paint_void: draws canyon walls/AO at inner-island cliffs
	for p in json.get("platforms", []):
		_build_platform(p, parent, renderer, void_rects)
		var r := Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"]))
		platform_rects.append(r)
		play_rect = r if first else play_rect.merge(r)
		first = false
	result["play_rect"] = play_rect

	for o in json.get("objects", []):
		var otype := str(o.get("type", ""))
		match otype:
			"player_spawn":
				result["spawns"].append(Vector2(o["x"], o["y"]))
			"void":
				# pit_void_rendering.md: display-only lethal-void renderer, NO collider (the kill stays
				# the bounds-bottom line). Painted AFTER platforms so their dirt bleed overhangs the seam.
				# Platform rects let the renderer extend the chasm treatment (dark riser + canyon walls +
				# under-lip AO) into the gaps BETWEEN floating islands, not just at the void's outer edges.
				renderer.paint_void(o, platform_rects)
			"spikes":
				_build_spikes(o, parent)
			"moving_hazard":
				# v1_moving_hazard.md §1 + WK-96: a kinematic moving hazard (pendulum/sweep). Its own layer
				# (layer 5). A fast pendulum ball SMASHES (Player.receive_hazard_smash: knockback + hitstun,
				# no sting/credit); slow apex grazes and sweeps shove (JSON "contact" overrides). NEVER kills.
				_build_moving_hazard(o, parent)
			"spinning_hammer":
				# v6_party_gimmicks_circuits.md §2.1: a LETHAL rotor-blade hazard. Modelled on the
				# MovingHazard phase-clock motion but its head instakills on contact via the EXISTING
				# kill pipeline (kill(&"ring_out")) — the SAME path spikes/Hazard.gd use, NOT a shove.
				_build_spinning_hammer(o, parent)
			"destructible_block":
				# v6_party_gimmicks_circuits.md §2.5 + §2.8: a bounce-tier SURFACE with HP / a timed
				# erosion trigger that BREAKS and disappears (telegraphed cracks + shudder first), so
				# footing is lost. NOT a hazard — the void/fall is the killer (§2.0 credit unchanged).
				# The COLLAPSING ARENA (meltdown_box.json) is a full floor of these on a timed cascade.
				_build_destructible_block(o, parent)
			"crusher":
				# v6_party_gimmicks_circuits.md §2.2: a LETHAL crush-hazard. Two steel heads (or a head
				# + a fixed anvil) slam together on a telegraphed rhythm and crush-kill anyone caught in
				# their path at impact, then retract to a clear open gap. Lethal via the EXISTING kill
				# pipeline (kill(&"ring_out")) — the SAME path spikes/spinning_hammer use, NOT a shove.
				_build_crusher(o, parent)
			"falling_debris":
				# v6_party_gimmicks_circuits.md §2.3: a LETHAL debris spawner. Drops giant balls from the
				# top on a cadence; each chunk is telegraphed by a growing ground shadow BEFORE it falls,
				# is lethal on contact via the EXISTING kill pipeline (kill(&"ring_out")), and despawns on
				# landing / off-screen. Same lethal-contact + phase-clock plumbing as spinning_hammer.
				_build_falling_debris(o, parent)
			"bomb":
				# v6_party_gimmicks_circuits.md §2.4 + v8_sports_courts.md §3.2: a LETHAL radial-blast
				# hazard (fuse bomb / proximity landmine). On detonation it instakills bodies in its inner
				# kill radius via the EXISTING kill pipeline (kill(&"ring_out") — NOT a shove) and applies
				# a radial KNOCKBACK to players/props (Forces, the shipped explosion form) + a PUNT to the
				# sports Ball (Ball.receive_hazard_impulse). Telegraphed fuse/blink + warning ring; recurs.
				_build_bomb(o, parent)
			"moving_platform":
				# v6_party_gimmicks_circuits.md §2.6: a SOLID MOVING SURFACE that CARRIES riders — the one
				# new physics system (a moving solid collider). An AnimatableBody2D deck translating on a
				# deterministic phase-clock path; players standing on it ride ALONG via a thin top-sensor
				# sticky carry (Player is MOTION_MODE_FLOATING, so Godot's grounded-only platform-follow is
				# a no-op — the v6 sticky fallback is the shipped path). NOT a hazard (never kills); a rider
				# carried off-stage dies via the existing void kill (credit unchanged). Skinnable as a
				# "vehicle" (owner's "fight on top of moving futuristic cars"). Touches physics -> the
				# change-control artifact is MovingPlatform.gd (mirrors the moving_hazard collision add).
				_build_moving_platform(o, parent)
			"start_gate":
				# v3_content_plan B.3 (TRIALS): the run's spawn + respawn point. Reuses the existing
				# spawn path — appended as a spawn so _spawn_at(0) / the multi-life respawn use it.
				result["spawns"].append(Vector2(o["x"], o["y"]))
			"goal_gate":
				# v3_content_plan B.3 (TRIALS): the course goal trigger. Area2D on the players mask;
				# first overlap latches `reached` and (group "goal_gate") ends the stage via
				# TrialsMode.is_stage_over. Same detector pattern as MovingHazard/void areas.
				var gg := GoalGate.new()
				gg.setup_from_json(o)
				parent.add_child(gg)
			"goal_zone":
				# v5_sports_mode.md §3 (SPORTS): the team-tagged goal-mouth trigger. Area2D on the BALL
				# layer; first overlap latches `scored` and (group "goal_zone") ends the stage via
				# SportsMode.is_stage_over. Mirrors the goal_gate case above.
				var gz := GoalZone.new()
				gz.setup_from_json(o)
				parent.add_child(gz)
			"drop_tile":
				# owner 2026-07-18 (DROPSHOT, v5 item 5): a ball-only destructible floor tile — first
				# ball hit cracks it, second breaks it open (a hole; the ball falling through = the
				# point, via the hidden under-floor goal_zone strips). Players never damage tiles.
				var dt := DropTile.new()
				dt.setup_from_json(o)
				parent.add_child(dt)
			"key":
				# owner 2026-07-16 (Trials circuit 2): a key token — Pickup-latch clone in group
				# "trials_key"; a matching key_door opens when every key with its `door` id is collected.
				var kt := KeyToken.new()
				kt.setup_from_json(o)
				parent.add_child(kt)
			"key_door":
				# owner 2026-07-16: a SOLID bumper-tier barrier that opens once its keys are collected.
				# Never lethal — the void stays the killer (hazard doctrine fence).
				var kd := KeyDoor.new()
				kd.setup_from_json(o)
				parent.add_child(kd)
			"cannon":
				# owner 2026-07-16 (Trials circuit 4): rideable cannon — fly in, the oscillating barrel
				# auto-fires you along its aim. Plain velocity launch (no smash license / fuel change).
				var cn := Cannon.new()
				cn.setup_from_json(o)
				parent.add_child(cn)
			"pickup":
				# v7_trials_challenge_types.md §1.3 (COLLECT_ALL): a floating token Area2D that latches
				# `collected` on player overlap and joins group "trials_pickup". Thin GoalGate-latch clone.
				var pk := Pickup.new()
				pk.setup_from_json(o)
				parent.add_child(pk)
			"land_target":
				# v7_trials_challenge_types.md §1.3 (PRECISION_LAND): a soft-landing pad Area2D that latches
				# `landed` only below land_speed_max and joins group "trials_target". GoalGate-latch clone.
				var lt := LandTarget.new()
				lt.setup_from_json(o)
				parent.add_child(lt)
			"ball":
				# v7_trials_challenge_types.md §2.4 (PHYSICS_PUZZLE): a spawn POINT only. The Ball itself is
				# (re)spawned here by TrialsMode.on_stage_ready (the SPORTS ball-spawn pattern) so it can be
				# auto-reset on a missed shot; LevelLoader just skips the marker cleanly.
				pass
			"powerup_spawner":
				# spawn POINT only (v1 powerups): pacing/placement live in PowerupSpawnDirector
				result["powerup_spawners"].append(Vector2(o["x"], o["y"]))
			"gravity_source":
				# P8 seam FILLED (owner 2026-07-18): a radial gravity well — constant-magnitude pull
				# toward its center inside `radius`; optional round planetoid bounce body (`body_r` +
				# `tier`), lethal core (`lethal_core_r`, existing Hazard path), and black_hole/moon
				# visual. GravityField/BounceResolver/Player were already field-correct (INV-1).
				var gs := GravitySource.new()
				gs.setup_from_json(o)
				parent.add_child(gs)
			"physics_prop", "container", "physics_structure", \
			"fan":
				# v0: these entity types are not ported yet — skip cleanly so old levels still load.
				push_warning("LevelLoader: '%s' not ported in v0 — skipped (%s)" % [otype, path])
			_:
				push_warning("LevelLoader: unknown object type '%s' in %s" % [otype, path])

	# Bounds (kill-zone recovery spec v3 §14): DERIVED from play_rect (walkable extent) by default;
	# an explicit "bounds" block in the JSON is an OPTIONAL OVERRIDE for hand-tuned levels.
	if json.has("bounds"):
		var b = json["bounds"]
		result["bounds"] = Rect2(b["left"], b["top"], b["right"] - b["left"], b["bottom"] - b["top"])
	else:
		result["bounds"] = _derive_bounds(play_rect)
	result["objects_raw"] = json.get("objects", [])   # so modes can read custom objects (campaign etc.)
	result["name"] = str(json.get("name", path.get_file().get_basename()))  # v1 rotation QA readout
	# Kill-shape class (v2a addendum §4b#1): declares HOW this arena is meant to kill so QA auto-selects
	# the right K1 target per class (central_pit vs void_is_floor/dual_blast/enclosed_hole). Data only —
	# does NOT change lethality; drives the QA metric interpretation + blast-edge label readability.
	# Default (absent) = "central_pit" for back-compat with grassy/dev levels.
	result["kill_shape"] = str(json.get("kill_shape", "central_pit"))
	# Backdrop mode (docs/briefs/enclosed_interior_backdrop.md): data-only surround/backfield treatment,
	# consumed by ArenaRenderer.setup(json) above. Orthogonal to kill_shape. Absent = "meadow" (current
	# parallax behavior); "enclosed" = sealed-drum interior. Surfaced here for symmetry / mode readouts.
	result["backdrop"] = str(json.get("backdrop", "meadow"))
	# Open-sky atmospherics (docs/briefs/circuit_theming_plan.md §3.2): OPTIONAL, all default to
	# current/off, consumed by ArenaRenderer only in the "open_sky" backdrop. Surfaced here as data
	# readouts (like backdrop/kill_shape) for mode readouts / QA; they do not affect gameplay.
	result["clouds"] = bool(json.get("clouds", true))
	result["horizon_glow"] = json.get("horizon_glow", false)
	result["stars"] = bool(json.get("stars", false))
	return result

## Derive blast-line bounds from the walkable AABB (kill-zone recovery spec v3 §14). Side margin
## scales with walkable width (clamped); top/bottom are fixed. Returns Rect2(left, top, w, h).
static func _derive_bounds(walkable: Rect2) -> Rect2:
	var side := clampf(Tuning.bounds_side_frac * walkable.size.x, Tuning.bounds_side_min, Tuning.bounds_side_max)
	var left := walkable.position.x - side
	var right := walkable.end.x + side
	var top := walkable.position.y - Tuning.bounds_top_margin
	var bottom := walkable.end.y + Tuning.bounds_bottom_margin
	return Rect2(left, top, right - left, bottom - top)

static func _rect_polygon(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)
	])

static func _build_platform(p: Dictionary, parent: Node2D, renderer: ArenaRenderer, void_rects: Array = []) -> void:
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
	renderer.paint_platform(p, body, void_rects)   # display-only; collider above is authoritative

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

## v1_moving_hazard.md §1: build the kinematic shove-hazard from JSON. It self-renders (arm/ball/arc)
## and self-moves on a deterministic phase clock; LevelLoader only constructs + configures it.
static func _build_moving_hazard(o: Dictionary, parent: Node2D) -> void:
	var h := MovingHazard.new()
	h.setup_from_json(o)
	parent.add_child(h)

## v6_party_gimmicks_circuits.md §2.1: build the LETHAL spinning-hammer from JSON. It self-renders
## (arm/blade/swept-arc telegraphy) and self-moves on a deterministic phase clock; its head kills any
## player it touches via the existing kill pipeline (NO new death impulse; fence per §2.0/§7).
static func _build_spinning_hammer(o: Dictionary, parent: Node2D) -> void:
	var h := SpinningHammer.new()
	h.setup_from_json(o)
	parent.add_child(h)

## v6_party_gimmicks_circuits.md §2.5/§2.8: build a destructible_block from JSON. It self-renders
## (steel body + tier mat + crack/shudder telegraphy) and self-clocks its timed erosion off
## EventBus.combat_started; on break it disables its collider (footing lost) and vanishes. Its bounce
## contract is IDENTICAL to a normal platform (tier meta), so BounceResolver reads it unchanged.
static func _build_destructible_block(o: Dictionary, parent: Node2D) -> void:
	var b := DestructibleBlock.new()
	b.setup_from_json(o)
	parent.add_child(b)

## v6_party_gimmicks_circuits.md §2.2: build the LETHAL crusher from JSON. Two heads (or head + anvil)
## on a deterministic phase clock; the heads self-render (steel + hazard-stripe faces + windup shudder)
## and instakill any player they overlap via the existing kill pipeline (NO new death impulse; fence
## per §2.0/§7). Sibling of _build_spinning_hammer.
static func _build_crusher(o: Dictionary, parent: Node2D) -> void:
	var c := Crusher.new()
	c.setup_from_json(o)
	parent.add_child(c)

## v6_party_gimmicks_circuits.md §2.3: build the LETHAL falling-debris spawner from JSON. It drops
## chunks on a cadence, telegraphs each with a ground shadow, self-renders the shadows + chunks, and
## instakills on chunk contact via the existing kill pipeline (NO new death impulse; fence per §2.0/§7).
static func _build_falling_debris(o: Dictionary, parent: Node2D) -> void:
	var d := FallingDebris.new()
	d.setup_from_json(o)
	parent.add_child(d)

## v6_party_gimmicks_circuits.md §2.4 + v8_sports_courts.md §3.2: build a LETHAL bomb/landmine from JSON.
## It self-renders (casing + fuse blink + expanding warning ring showing the exact lethal radius) and
## self-clocks; on detonation it instakills bodies in its inner kill radius via the existing kill
## pipeline (NO new death impulse) and applies a radial KNOCKBACK to players/props (Forces) + a PUNT to
## the sports Ball (receive_hazard_impulse). Sibling of _build_spinning_hammer / _build_crusher.
static func _build_bomb(o: Dictionary, parent: Node2D) -> void:
	var b := Bomb.new()
	b.setup_from_json(o)
	parent.add_child(b)

## v6_party_gimmicks_circuits.md §2.6: build a moving_platform from JSON. An AnimatableBody2D deck on
## LAYER_SURFACES that translates on a deterministic phase-clock path (endpoints or center+axis+amp),
## self-renders (deck or vehicle skin + a static path rail), and CARRIES riders via a thin top-sensor
## sticky delta (Player is MOTION_MODE_FLOATING, so grounded platform-follow is a no-op). NOT a hazard
## — the void/fall stays the killer; NO fenced constant touched. Sibling of _build_moving_hazard.
static func _build_moving_platform(o: Dictionary, parent: Node2D) -> void:
	var m := MovingPlatform.new()
	m.setup_from_json(o)
	parent.add_child(m)
