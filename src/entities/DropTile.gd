class_name DropTile
extends StaticBody2D
## DROPSHOT destructible floor tile (owner list 2026-07-18 item 5). A bounce-tier SURFACE (identical
## bounce contract to a normal platform — BounceResolver reads its tier meta) that only the BALL can
## damage: the FIRST ball hit CRACKS it (visible dent/crack state), the SECOND ball hit BREAKS it
## open (collider off -> a hole in the court floor). The ball falling through a hole is the POINT
## (detected by the hidden under-floor GoalZone strips, standard volleyball scoring: the side whose
## half lost the ball concedes). Players NEVER damage tiles (the sensor masks the BALL layer only)
## and a hole is never directly lethal — a player who drops through simply falls to the bounds
## bottom, dies the ordinary ring-out, and is respawned on their own side (SportsMode's
## respawn_position seam; SPORTS lives are 99 so this is a cost-free reset, per the owner ruling
## "holes are lethal-free gaps; falling player respawns at their side spawn").
##
## RALLY FLOW: fresh tiles per POINT — a point ends the stage, the arena JSON reloads, and every
## tile is rebuilt intact (the SPORTS stage-per-point pattern; no persistence needed).
##
## Detection is a combat-gated Area2D POLL (the stale-latch doctrine: no body_entered latch), with a
## per-tile cooldown + a minimum ball speed so one bounce = one hit and a resting ball never grinds
## a tile down. OWNER RULE (2026-07-18 clarification, verbatim: "the ball needs to bounce when it
## destroys the floor, not destroy + fall through at the same time"): EVERY tile contact is a normal
## bounce, INCLUDING the breaking hit. A hit is therefore only counted once the ball is moving UP
## (post-bounce) — hit 1 = bounce + crack, hit 2 = bounce + the hole opens as the ball departs; the
## point comes only when the ball LATER descends into the already-open hole and passes through. A
## descending ball can never trigger a break, so break-and-fall-through on one contact is impossible.
## Self-rendering (the DestructibleBlock pattern): sand-panel body + chocolate outline, crack overlay
## when dented, shard burst on each state change.
##
## {"type":"drop_tile","x","y","w","h"[,"tier":"trampoline"]} — x,y = TOP-LEFT (platform convention).

const LAYER_SURFACES := 1 << 2   # 4 — bounce_surfaces (matches LevelLoader platforms)
const MASK_BALL := 1 << 6        # senses ONLY the Ball layer (players can never damage a tile)
const HIT_SPEED_MIN := 240.0     # ball must arrive with real pace (a resting ball never erodes a tile)
const HIT_COOLDOWN := 0.45       # s between counted hits (one bounce = one hit, no per-frame grind)

# Beach-court palette (Glossy Toybox grammar: cream body, chocolate outline)
const SAND := Color("#f0d9a8")
const SAND_HI := Color("#fbeccb")
const SAND_LO := Color("#d9b97e")
const CHOCO := Color(0.231373, 0.141176, 0.105882)
const CRACK := Color(0.25, 0.16, 0.10, 0.85)

enum { INTACT, CRACKED, BROKEN }

var w: float = 185.0
var h: float = 100.0
var tier: String = "trampoline"

var state: int = INTACT
var _live: bool = false          # combat gate (tiles never erode during intro/countdown)
var _cd: float = 0.0
var _shape: CollisionShape2D
var _area: Area2D
var _rng := RandomNumberGenerator.new()
var _crack_seed: int = 0

func setup_from_json(o: Dictionary) -> void:
	w = float(o.get("w", 185.0))
	h = float(o.get("h", 100.0))
	tier = str(o.get("tier", "trampoline"))
	# position = rect CENTER (platform convention: JSON x/y are top-left)
	position = Vector2(float(o.get("x", 0.0)) + w * 0.5, float(o.get("y", 0.0)) + h * 0.5)

func _ready() -> void:
	_crack_seed = hash(position)
	add_to_group("drop_tile")
	collision_layer = LAYER_SURFACES
	collision_mask = 0
	# bounce contract — identical to LevelLoader._build_platform
	if tier == "bumper":
		set_meta("bumper", true)
	else:
		set_meta("bounce_tier_height", Tuning.bounce_height_for(StringName(tier)))
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	_shape.shape = rect
	add_child(_shape)
	# ball-sensing area, slightly taller than the tile so a bounce contact overlaps for a frame or two
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = MASK_BALL
	_area.monitoring = true
	var acs := CollisionShape2D.new()
	var arect := RectangleShape2D.new()
	arect.size = Vector2(w + 8.0, h + 28.0)
	acs.shape = arect
	_area.add_child(acs)
	add_child(_area)
	z_index = 5
	if not EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.connect(_on_combat_started)
	if not EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.connect(_on_combat_ended)

func _on_combat_started() -> void:
	_live = true

func _on_combat_ended() -> void:
	_live = false

func _physics_process(delta: float) -> void:
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - delta)
	if state == BROKEN or not _live or _cd > 0.0:
		return
	for b in _area.get_overlapping_bodies():
		if not (b is Ball):
			continue
		# OWNER RULE: count the hit only on the REBOUND — the ball must be moving UP (away from the
		# floor tile) with real pace, i.e. the physics bounce has ALREADY happened. The breaking hit
		# still bounces the ball; the hole opens as it departs. A descending/resting ball never
		# damages a tile (and so can never break-and-fall-through in one contact).
		if (b as Ball).linear_velocity.y > -HIT_SPEED_MIN:
			continue
		_take_hit()
		break

func _take_hit() -> void:
	_cd = HIT_COOLDOWN
	if state == INTACT:
		state = CRACKED
		_spawn_shards(10)
	elif state == CRACKED:
		state = BROKEN
		# the hole opens THIS frame: the ball (and anyone standing here) falls through.
		_shape.set_deferred("disabled", true)
		_area.set_deferred("monitoring", false)
		_spawn_shards(22)
	EventBus.drop_tile_hit.emit(self, state == BROKEN)   # WK-121 crack / break sound hook
	queue_redraw()

## Sand-shard puff on crack/break (the DestructibleBlock shard grammar; pure VFX, never lethal).
func _spawn_shards(count: int) -> void:
	var host := get_parent()
	if host == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.6
	p.position = global_position
	p.direction = Vector2.UP
	p.spread = 80.0
	p.gravity = Vector2(0, 1600)
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 520.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(w * 0.5, h * 0.3)
	var grad := Gradient.new()
	grad.set_color(0, SAND_HI)
	grad.set_color(1, Color(SAND_LO.r, SAND_LO.g, SAND_LO.b, 0.0))
	p.color_ramp = grad
	p.z_index = 6
	host.add_child(p)
	host.get_tree().create_timer(1.0).timeout.connect(p.queue_free)

# ------------------------------------------------------------------ display (INV-12: display only)
func _draw() -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	if state == BROKEN:
		# the HOLE: dark drop shaft + jagged broken lips on both edges so the gap reads at pitch zoom
		draw_rect(Rect2(Vector2(-hw, -hh), Vector2(w, h)), Color(0.08, 0.06, 0.05, 0.55))
		_rng.seed = _crack_seed
		for s in [-1.0, 1.0]:
			var side: float = s
			var x: float = side * hw
			var pts := PackedVector2Array()
			pts.append(Vector2(x, -hh))
			for k in range(3):
				pts.append(Vector2(x - side * _rng.randf_range(6.0, 22.0), -hh + h * (0.25 + 0.25 * float(k))))
			pts.append(Vector2(x, hh))
			draw_polyline(pts, CHOCO, 4.0)
		return
	# body: sand panel, chocolate outline, gloss stripe (Glossy Toybox)
	var body := Rect2(Vector2(-hw, -hh), Vector2(w, h))
	draw_rect(body, SAND if state == INTACT else SAND_LO, true)
	draw_rect(Rect2(Vector2(-hw, -hh), Vector2(w, 10.0)), SAND_HI, true)
	draw_rect(body, CHOCO, false, 5.0)
	if state == CRACKED:
		# dent shadow + deterministic crack web (the "hit it again and it opens" tell)
		draw_circle(Vector2(0, -hh * 0.2), minf(hw, hh) * 0.55, Color(0.0, 0.0, 0.0, 0.10))
		_rng.seed = _crack_seed
		for i in range(5):
			var a := _rng.randf_range(0.0, TAU)
			var reach := minf(hw, hh) * _rng.randf_range(0.7, 1.15)
			var start := Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-10, 2))
			var mid := start + Vector2(cos(a), sin(a)) * reach * 0.55 + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-8, 8))
			var end := start + Vector2(cos(a), sin(a)) * reach
			draw_polyline(PackedVector2Array([start, mid, end]), CRACK, 3.0)
