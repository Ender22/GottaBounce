class_name GravitySource
extends Node2D
## RADIAL GRAVITY WELL (owner 2026-07-18: "start off orbiting a black hole… orbiting 2 moons") —
## fills the P8 gravity_source seam that GravityField/BounceResolver/Player were built against:
## inside `radius`, local gravity points at this node's center with CONSTANT magnitude `g`
## (readable orbits, never 1/r^2 chaos); outside, GravityField falls back to global down.
## Player body orientation (_down_angle), bounce math (BounceResolver takes the local g), the Ball
## and StormBall all query the field already — this node just registers itself.
##
## Optional parts, all data-driven:
##  - body_r > 0    : a ROUND planetoid bounce surface (StaticBody2D + circle collider) with the
##                    given `tier`. Carries meta "round" so the player's contact code keeps the TRUE
##                    radial normal instead of axis-snapping (axis-snap is for rect platforms).
##  - lethal_core_r : an instakill core (black hole event horizon) via the EXISTING Hazard path —
##                    the same kill pipeline as spikes/crusher (fence: no new death rules).
##  - visual        : "black_hole" (dark core + rotating accretion rings — hazard-family
##                    self-render, like Bomb/Crusher) | "moon" (cratered planetoid; ART-DEBT: a
##                    bespoke moon sprite is queued — assets/objects/moon.png is picked up
##                    automatically when it lands) | "none".
##
## {"type":"gravity_source","x","y","radius":1400,"g":1300,"body_r":0,"tier":"trampoline",
##  "lethal_core_r":0,"visual":"none"} — x,y = CENTER.

const LAYER_SURFACES := 1 << 2
const LAYER_HAZARDS := 1 << 3
const MOON_TEX_PATH := "res://assets/objects/moon.png"           # bespoke sprite (art pass 2026-07-18)
const BH_TEX_PATH := "res://assets/objects/black_hole.png"       # bespoke swirl sprite (same pass)

var radius: float = 1400.0
var g: float = 1300.0
var body_r: float = 0.0
var tier := "trampoline"
var lethal_core_r: float = 0.0
var visual := "none"

var _t := 0.0
var _moon_tex: Texture2D = null
var _bh_tex: Texture2D = null

func setup_from_json(o: Dictionary) -> void:
	position = Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))
	radius = maxf(100.0, float(o.get("radius", 1400.0)))
	g = float(o.get("g", 1300.0))
	body_r = float(o.get("body_r", 0.0))
	tier = str(o.get("tier", "trampoline"))
	lethal_core_r = float(o.get("lethal_core_r", 0.0))
	visual = str(o.get("visual", "none"))

# --- the GravityField contract (queried every physics frame) ---
func contains(pos: Vector2) -> bool:
	return pos.distance_squared_to(global_position) <= radius * radius

func gravity_at(pos: Vector2) -> Vector2:
	var d := global_position - pos
	if d.length_squared() < 1.0:
		return Vector2.ZERO   # exactly at the center: no defined "down"
	return d.normalized() * g

func _ready() -> void:
	GravityField.register(self)
	z_index = 18   # under players/props, over backdrop
	if ResourceLoader.exists(MOON_TEX_PATH):
		_moon_tex = load(MOON_TEX_PATH)
	if ResourceLoader.exists(BH_TEX_PATH):
		_bh_tex = load(BH_TEX_PATH)
	if body_r > 0.0:
		var body := StaticBody2D.new()
		body.collision_layer = LAYER_SURFACES
		body.collision_mask = 0
		if tier == "bumper":
			body.set_meta("bumper", true)
		else:
			body.set_meta("bounce_tier_height", Tuning.bounce_height_for(StringName(tier)))
		body.set_meta("round", true)   # keep the true radial contact normal (no axis-snap)
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = body_r
		cs.shape = c
		body.add_child(cs)
		add_child(body)
	if lethal_core_r > 0.0:
		var core := Hazard.new()   # existing instakill path (same as spikes) — no new death rules
		core.collision_layer = LAYER_HAZARDS
		core.set_meta("hazard", true)
		var hcs := CollisionShape2D.new()
		var hc := CircleShape2D.new()
		hc.radius = lethal_core_r
		hcs.shape = hc
		core.add_child(hcs)
		add_child(core)

func _exit_tree() -> void:
	GravityField.unregister(self)

func _physics_process(delta: float) -> void:
	_t += delta
	if visual != "none":
		queue_redraw()

# ------------------------------------------------------------------ display
func _draw() -> void:
	match visual:
		"black_hole":
			_draw_black_hole()
		"moon":
			_draw_moon()

## Hazard-family self-render (Bomb/Crusher precedent): the event horizon must read as LETHAL —
## dark core, hot accretion rings rotating opposite ways, and a faint field ring showing the
## gravity extent (telegraphy: you can SEE where the pull begins).
func _draw_black_hole() -> void:
	var core_r := maxf(lethal_core_r, 60.0)
	# faint field-extent ring (the "you are now orbiting" line)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(0.62, 0.45, 1.0, 0.10), 8.0, true)
	if body_r > 0.0:
		core_r = body_r   # the visual core matches the actual event-horizon collider
	# bespoke swirl sprite (owner: no code-drawn planets) — slow pinwheel spin; the sprite's dark
	# core is sized to sit on the collider circle, the painted swirl extends beyond it.
	if _bh_tex != null:
		var d := core_r * 4.4
		draw_set_transform(Vector2.ZERO, _t * 0.5, Vector2.ONE)
		draw_texture_rect(_bh_tex, Rect2(Vector2(-d * 0.5, -d * 0.5), Vector2(d, d)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var spx := Vector2.from_angle(_t * 2.3) * core_r * (1.9 - 0.5 * fmod(_t * 0.7, 1.0))
		draw_circle(spx, 6.0, Color(1.0, 0.9, 0.6, 0.8))
		return
	# outer glow
	for i in range(4):
		var k := 1.0 - float(i) / 4.0
		draw_circle(Vector2.ZERO, core_r * (2.2 - 0.3 * i), Color(0.35, 0.15, 0.6, 0.10 + 0.05 * k))
	# rotating accretion arcs (two counter-rotating hot rings)
	var a1 := _t * 1.7
	var a2 := -_t * 1.1
	draw_arc(Vector2.ZERO, core_r * 1.55, a1, a1 + TAU * 0.62, 48, Color(0.85, 0.55, 1.0, 0.85), 10.0, true)
	draw_arc(Vector2.ZERO, core_r * 1.25, a2, a2 + TAU * 0.5, 40, Color(1.0, 0.75, 0.35, 0.9), 8.0, true)
	# the hole: chocolate rim (touchable = outlined, and this one touches YOU) + true-black core
	draw_circle(Vector2.ZERO, core_r * 1.08, Color(0.231373, 0.141176, 0.105882, 1.0))
	draw_circle(Vector2.ZERO, core_r, Color(0.02, 0.01, 0.05, 1.0))
	# infalling sparkle (juice)
	var sp := Vector2.from_angle(_t * 2.3) * core_r * (1.9 - 0.5 * fmod(_t * 0.7, 1.0))
	draw_circle(sp, 6.0, Color(1.0, 0.9, 0.6, 0.8))

## Planetoid render: bespoke sprite when it lands; until then a glossy toy moon — pale body,
## chocolate outline, three craters, top-left shine (Glossy Toybox lighting).
func _draw_moon() -> void:
	if body_r <= 0.0:
		return
	# faint field-extent ring
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(0.7, 0.85, 1.0, 0.10), 8.0, true)
	if _moon_tex != null:
		var d := body_r * 2.08
		draw_texture_rect(_moon_tex, Rect2(Vector2(-d * 0.5, -d * 0.5), Vector2(d, d)), false)
		return
	draw_circle(Vector2.ZERO, body_r + 7.0, Color(0.231373, 0.141176, 0.105882, 1.0))   # outline
	draw_circle(Vector2.ZERO, body_r, Color(0.82, 0.84, 0.90, 1.0))                     # body
	draw_circle(Vector2(-body_r * 0.35, -body_r * 0.4), body_r * 0.28, Color(1.0, 1.0, 1.0, 0.55))  # shine
	for cr in [[0.3, 0.25, 0.16], [-0.15, 0.45, 0.11], [0.5, -0.2, 0.09]]:
		var cp := Vector2(body_r * cr[0], body_r * cr[1])
		draw_circle(cp, body_r * cr[2], Color(0.62, 0.65, 0.74, 1.0))
		draw_arc(cp, body_r * cr[2], 0.0, TAU, 24, Color(0.5, 0.52, 0.62, 0.8), 3.0, true)
