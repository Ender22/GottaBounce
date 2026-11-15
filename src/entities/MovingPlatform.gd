class_name MovingPlatform
extends AnimatableBody2D
## A SOLID MOVING SURFACE that CARRIES riders (docs/specs/v6_party_gimmicks_circuits.md §2.6). Footing
## that translates on a deterministic phase-clock path (linear oscillation between two endpoints or a
## center+axis+amplitude swing) and takes players standing on it ALONG WITH IT. Skinnable as a
## "vehicle" (the owner's "fight on top of moving futuristic cars"). This is the one genuinely-new
## physics system in Batch 1 (a solid moving collider), scheduled LAST with an explicit fallback.
##
## NOT a hazard — it never contact-kills. It is pure GEOMETRY; the LETHALITY stays the void/fall (a
## rider carried off-stage into the bottom blast line dies via the EXISTING void kill, credited by the
## existing 6.0s ring-out window — an untagged carry-off = uncredited self-fall, a knock-in = credited).
## This entity NEVER sets last_attacker and invents NO scorer (INV-9). NO Tuning/lethality/feel
## constant is touched (fence per §2.0/§7). Motion touches physics (a moving solid collider) — the
## change-control artifact is this file (mirrors the moving_hazard collision-table add).
##
## ---------------------------------------------------------------------------------------------------
## CARRY STRATEGY (the hard part; §2.6 IDEAL = AnimatableBody2D, FALLBACK = sticky).
##   Player is a CharacterBody2D in MOTION_MODE_FLOATING (Player.gd _ready). Godot 4's automatic
##   platform-follow (move_and_slide inheriting platform velocity via platform_floor_layers) fires
##   ONLY in MOTION_MODE_GROUNDED — a FLOATING controller has no "floor" and inherits nothing. So the
##   pure-AnimatableBody auto-carry does NOT apply to this game's player. We therefore use a HYBRID:
##     (1) The deck IS an AnimatableBody2D (sync_to_physics) on LAYER_SURFACES, so the player's
##         move_and_slide collides with it EXACTLY like a normal StaticBody platform — it can rest on
##         it, bounce on it (if a tier is authored), and never tunnels through. Solid collision for free.
##     (2) A thin TOP Area2D senses riders (players whose feet are on the deck). Each physics frame we
##         add the platform's per-frame delta (dx AND dy) to every rider's global_position — the v6
##         STICKY carry. Because rider and deck move by the SAME delta, their RELATIVE position is
##         preserved: no new penetration is created, so move_and_slide never fights the carry (no
##         jitter, no double-push) and the rider rides smoothly, stays on, and is not left behind.
##   Chosen because FLOATING mode makes the "clean AnimatableBody ride" path a no-op; the sticky delta
##   is deterministic and frame-order-independent (zero relative motion either way). See the build
##   report for the measured result.
## ---------------------------------------------------------------------------------------------------

const LAYER_SURFACES := 1 << 2       # 4 — bounce_surfaces layer (matches LevelLoader._build_platform)
const LAYER_PLAYERS := 1 << 0        # 1 — the top sensor senses player bodies
const RIDER_REACH := 118.0           # top sensor band height above the deck (~ a resting player's body)

# --- Glossy Toybox flatbed-cart sprite (pays down the no-code-drawn-assets debt; owner-flagged; same
# pattern as the hammer/bomb/crusher wiring). A rideable toy cart: a flat metal STANDING DECK across the
# top, an orange hazard-striped body, and 4 chunky wheels below. Image is 1143x412; the metal deck plate
# spans the full image width and its TOP FACE sits at image y~0 (verified from the alpha silhouette:
# full-width deck band across the top rows). The code-drawn "hover-car" vehicle BODY is replaced by this
# sprite via draw_texture_rect, scaled so the deck spans the collider width `w` and the image TOP aligns
# with the deck collider's TOP edge (local -hh, the standing surface); the striped body + wheels hang
# below the collider. The bounce-deck variant (_draw_deck) is UNCHANGED. ---
const CART_TEX: Texture2D = preload("res://assets/hazards/flatbed_cart.png")
const CART_TEX_W := 1143.0
const CART_TEX_H := 412.0

# --- geometry / motion params (from JSON; all data, no Tuning) ---
var w: float = 420.0
var h: float = 48.0
var tier: String = ""                # "" / "firm" / "none" = a solid non-bounce deck (the ridable vehicle);
                                     # a real tier (marshmallow/bubblegum/...) makes it a MOVING trampoline.
var vehicle: bool = false            # render as a car/craft (the owner's "fight on top of moving cars")

# path: EITHER two endpoints p0..p1, OR center + axis(deg) + amplitude (a symmetric swing about center).
var use_endpoints: bool = false
var p0: Vector2 = Vector2.ZERO
var p1: Vector2 = Vector2.ZERO
var center: Vector2 = Vector2.ZERO
var axis_rad: float = 0.0            # 0 = horizontal (+x), PI/2 = vertical (+y). Swing is center +/- amp*axis.
var amplitude: float = 300.0
var period_s: float = 4.0            # a full there-and-back cycle
var phase: float = 0.0               # 0..1 phase offset (convoy platforms can run offset rhythms)
var dwell_frac: float = 0.12         # fraction of the period paused at EACH endpoint (a beat to hop off/on)

# --- palette (self-render) ---
const STEEL := Color(0.22, 0.24, 0.30)
const STEEL_HI := Color(0.40, 0.44, 0.52)
const STEEL_LO := Color(0.12, 0.13, 0.18)
const DECK := Color(0.30, 0.33, 0.40)
const RAIL := Color(0.62, 0.66, 0.74)
const NEON := Color(0.20, 0.85, 1.0)     # vehicle running-light accent

var _t: float = 0.0
var _pos: Vector2 = Vector2.ZERO
var _prev_pos: Vector2 = Vector2.ZERO
var _shape: CollisionShape2D
var _top_sensor: Area2D
var _rail: Line2D
# WK-66a: "skin": "net" = the DOME's moving Dropshot net. The collider/motion/carry are unchanged; the steel
# deck + path rail are replaced by the shared volleyball-set net art (src/systems/SportsNetArt.gd).  # WK-66a
const NET_ART := preload("res://src/systems/SportsNetArt.gd")   # WK-66a
var skin: String = ""            # WK-66a
var net_tint: Color = Color.WHITE   # WK-66a

func setup_from_json(o: Dictionary) -> void:
	w = float(o.get("w", 420.0))
	h = float(o.get("h", 48.0))
	tier = str(o.get("tier", ""))
	vehicle = bool(o.get("vehicle", false))
	skin = str(o.get("skin", ""))   # WK-66a
	net_tint = Color(str(o.get("net_tint", Tuning.net_tint_default.to_html(false))))   # WK-66a
	period_s = maxf(0.3, float(o.get("period_s", 4.0)))
	phase = float(o.get("phase", 0.0))
	dwell_frac = clampf(float(o.get("dwell_frac", 0.12)), 0.0, 0.45)
	if o.has("p0") and o.has("p1"):
		use_endpoints = true
		var a = o.get("p0", {"x": 0.0, "y": 0.0})
		var b = o.get("p1", {"x": 0.0, "y": 0.0})
		p0 = Vector2(float(a.get("x", 0.0)), float(a.get("y", 0.0)))
		p1 = Vector2(float(b.get("x", 0.0)), float(b.get("y", 0.0)))
	else:
		use_endpoints = false
		# center defaults to the authored x/y (top-left) + half-size, matching _build_platform framing.
		var cx := float(o.get("x", 0.0)) + w * 0.5
		var cy := float(o.get("y", 0.0)) + h * 0.5
		if o.has("center"):
			var c = o["center"]
			cx = float(c.get("x", cx))
			cy = float(c.get("y", cy))
		center = Vector2(cx, cy)
		axis_rad = deg_to_rad(float(o.get("axis_deg", 0.0)))
		amplitude = float(o.get("amplitude", 300.0))

func _ready() -> void:
	sync_to_physics = true            # kinematic mover: set the transform in _physics_process (default)
	collision_layer = LAYER_SURFACES
	collision_mask = 0
	set_meta("moving_platform", true)
	# Bounce contract — identical to LevelLoader._build_platform. A firm deck (default) gets NEITHER
	# bumper nor tier meta, so _resolve_bounces ignores it and the player simply RESTS on it (a ridable
	# vehicle). An authored tier makes it a moving trampoline (BounceResolver reads the meta unchanged).
	if tier == "bumper":
		set_meta("bumper", true)
	elif tier != "" and tier != "firm" and tier != "none":
		set_meta("bounce_tier_height", Tuning.bounce_height_for(StringName(tier)))
	elif Tuning.moving_deck_min_bounce:   # WK-20e (INV-11): a tier-less deck is never standable -> min-bounce hop + its refund.
		# 48 px keeps the rider's centre inside the RIDER_REACH band, so the sticky carry below still holds it. The deck
		# keeps its firm look (no gold mat strip: _draw_* test "firm_hop", not bounce_tier_height). Audit wk20d_r1 bug 1.  # WK-20e
		set_meta("bounce_tier_height", Tuning.min_bounce_height)   # WK-20e
		set_meta("firm_hop", true)   # WK-20e

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	_shape.shape = rect
	add_child(_shape)

	# Top rider-sensor: a thin band sitting ON the deck top, sensing player bodies (layer 1). It does
	# not collide (layer 0); it only reports who is standing on the deck for the sticky carry.
	_top_sensor = Area2D.new()
	_top_sensor.collision_layer = 0
	_top_sensor.collision_mask = LAYER_PLAYERS
	_top_sensor.monitoring = true
	var scs := CollisionShape2D.new()
	var srect := RectangleShape2D.new()
	srect.size = Vector2(w + 8.0, RIDER_REACH)
	scs.shape = srect
	# band centered just above the deck: from deck top upward by RIDER_REACH.
	scs.position = Vector2(0.0, -h * 0.5 - RIDER_REACH * 0.5)
	_top_sensor.add_child(scs)
	add_child(_top_sensor)

	# Faint path rail (telegraphy §2.6: "visible rails; the vehicle reads its own trajectory"). Drawn
	# in WORLD coords via a top_level Line2D so it stays put while the deck slides along it.
	_rail = Line2D.new()
	_rail.top_level = true
	_rail.width = 6.0
	_rail.default_color = Color(STEEL_HI.r, STEEL_HI.g, STEEL_HI.b, 0.28)
	_rail.z_index = 2
	var ends := _path_endpoints()
	_rail.points = PackedVector2Array([ends[0], ends[1]])
	add_child(_rail)
	if skin == "net":   # WK-66a: no steel rod / rail line through the see-through net
		_rail.visible = false
		var art: Node2D = NET_ART.new()
		art.name = "NetArt"
		add_child(art)
		art.call("setup_dropshot", w, h, net_tint)
		set_meta("net_fx", art)   # ripple feed (Ball contact report + ArenaRenderer surface_bounced)

	_pos = _compute_pos(0.0)
	_prev_pos = _pos
	global_position = _pos
	z_index = 6   # over the void render, under HUD / players (players are higher)

## Shaped oscillator in [0,1] phase: two smootherstep swings + a flat DWELL at each endpoint (the beat
## to hop on/off). Returns [-1, 1]; smootherstep endpoints have ZERO derivative, so the motion eases to
## a stop at each end with no velocity discontinuity (C1-continuous, deterministic). Same shape the
## validated MovingHazard / SpinningHammer oscillators use.
func _osc(t: float) -> float:
	var u := fposmod(t / period_s + phase, 1.0)
	var d := dwell_frac
	var swing := (1.0 - 2.0 * d) * 0.5
	if swing <= 0.0001:
		return 0.0
	if u < swing:
		return lerpf(-1.0, 1.0, _smoother(u / swing))
	elif u < swing + d:
		return 1.0
	elif u < 2.0 * swing + d:
		return lerpf(1.0, -1.0, _smoother((u - swing - d) / swing))
	else:
		return -1.0

static func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

func _path_endpoints() -> Array:
	if use_endpoints:
		return [p0, p1]
	var dir := Vector2(cos(axis_rad), sin(axis_rad))
	return [center - dir * amplitude, center + dir * amplitude]

func _compute_pos(t: float) -> Vector2:
	var s := _osc(t)   # [-1, 1]
	if use_endpoints:
		return p0.lerp(p1, (s + 1.0) * 0.5)
	var dir := Vector2(cos(axis_rad), sin(axis_rad))
	return center + dir * (amplitude * s)

func _physics_process(delta: float) -> void:
	_t += delta
	_prev_pos = _pos
	_pos = _compute_pos(_t)
	global_position = _pos
	var d := _pos - _prev_pos
	if d != Vector2.ZERO:
		_carry_riders(d)

## STICKY carry (§2.6 fallback, the shipped path): move every rider on the deck by the platform's
## per-frame delta. Rider and deck advance by the SAME delta, so their relative position is preserved
## — no penetration is introduced and the player's own move_and_slide never fights the carry. A player
## in a shallow bounce / resting is inside the top band and rides; one flung up past the band flies
## free (physics owns them again). Dead players and Star/invincible-irrelevant here — carry is pure
## kinematics, no impulse, no kill, no credit.
func _carry_riders(d: Vector2) -> void:
	for body in _top_sensor.get_overlapping_bodies():
		if not is_instance_valid(body) or not (body is Player):
			continue
		if body.has_method("is_dead") and body.is_dead():
			continue
		# only carry a body that is truly ON TOP (its center is above the deck top), never one clipping
		# the band from the side/below — guards against a passer-by getting yanked.
		if body.global_position.y > global_position.y - h * 0.5 + 8.0:
			continue
		body.global_position += d

# ------------------------------------------------------------------ telegraphy (INV-12: display only)
func _draw() -> void:
	if skin == "net":   # WK-66a: the net art child draws it
		return
	if vehicle:
		_draw_vehicle()
	else:
		_draw_deck()

func _draw_deck() -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	# drop shadow
	draw_rect(Rect2(Vector2(-hw, -hh + 8.0), Vector2(w, h)), Color(0.04, 0.06, 0.10, 0.30))
	# steel body (bevelled: light top strip, dark bottom)
	draw_rect(Rect2(Vector2(-hw, -hh), Vector2(w, h)), STEEL)
	draw_rect(Rect2(Vector2(-hw, hh - h * 0.4), Vector2(w, h * 0.4)), STEEL_LO)
	# deck plate (top surface line the player stands on)
	draw_rect(Rect2(Vector2(-hw, -hh), Vector2(w, 12.0)), DECK)
	draw_rect(Rect2(Vector2(-hw, -hh), Vector2(w, 4.0)), RAIL)
	# tier-colored bounce mat, if this deck is a moving trampoline (readability of its bounce identity)
	if (has_meta("bounce_tier_height") and not has_meta("firm_hop")) or has_meta("bumper"):   # WK-20e: not on a firm hop deck
		draw_rect(Rect2(Vector2(-hw, -hh), Vector2(w, 6.0)), Color(1.0, 0.85, 0.2))
	# side rails / bolts (industrial read)
	for cx in [-hw + 14.0, hw - 14.0]:
		draw_circle(Vector2(cx, -hh + 8.0), 4.0, STEEL_HI)
		draw_circle(Vector2(cx, hh - 8.0), 4.0, STEEL_HI)
	draw_rect(Rect2(Vector2(-hw, -hh), Vector2(w, h)), STEEL_HI, false, 2.0)

func _draw_vehicle() -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	# The vehicle BODY is now the flatbed_cart sprite. The COLLIDER is the flat top deck; the striped
	# body + wheels bleed below it. drop shadow kept as a grounding VFX.
	draw_rect(Rect2(Vector2(-hw, -hh + 10.0), Vector2(w, h + 40.0)), Color(0.03, 0.05, 0.09, 0.30))
	# BODY: deck spans the collider width `w`; image TOP (the metal deck plate's top face) aligns with
	# the deck collider's TOP edge (-hh, the standing surface). Wheels/body hang below.
	var s := w / CART_TEX_W
	draw_texture_rect(CART_TEX, Rect2(Vector2(-hw, -hh), Vector2(w, CART_TEX_H * s)), false)
	# tier-colored bounce mat, if this deck is authored as a moving trampoline (unchanged identity read)
	if (has_meta("bounce_tier_height") and not has_meta("firm_hop")) or has_meta("bumper"):   # WK-20e: not on a firm hop deck
		draw_rect(Rect2(Vector2(-hw, -hh), Vector2(w, 6.0)), Color(1.0, 0.85, 0.2))
