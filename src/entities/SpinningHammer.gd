class_name SpinningHammer
extends Area2D
## LETHAL rotor-blade hazard (docs/specs/v6_party_gimmicks_circuits.md §2.1). A giant hammer arm
## sweeps a telegraphed arc on a fixed rhythm; the HEAD instakills any player it touches via the
## SAME pipeline `spikes`/Hazard.gd use (`body.kill(&"ring_out")`) — NOT a shove. This is the first
## LETHAL gimmick and establishes the plumbing the other lethal hazards (crusher, falling_debris,
## bomb) reuse: deterministic phase-clock motion + telegraphy + the existing kill/credit path.
##
## DOCTRINE (§2.0):
##   (1) LETHAL by default — contact routes to kill(&"ring_out"); no new death impulse/hitstun.
##   (2) TELEGRAPHY — a single bold blade on a slow readable rotation (period_s ~4-5), a hazard-red
##       swept-arc guide, and a DWELL at each apex (the "clear beat"). The blade's readable speed IS
##       its readable threat. Sweeps < 360deg so a >= ~120deg / ~1s clear window always returns.
##   (3) FAIRNESS — the clear window returns every period; the hub is placed so no player spawns
##       under the blade and refuge always exists (level-design constraint, not code).
##   (4) CREDIT (INV-9) — the hammer is NOT a Player, so it NEVER sets last_attacker. A kill with no
##       attacker resolves as an uncredited self-fall (killer = -1); a rival who knocked/tagged the
##       victim within kill_credit_window_ringout (6.0s) is credited by the EXISTING ring-out window
##       (kill(&"ring_out") -> Player.kill's last-attacker fallback). No invented environment scorer.
##
## Motion is a DETERMINISTIC phase clock (no physics ODE, no randomness), reusing the proven
## MovingHazard oscillator shape: two smootherstep swings joined by a flat DWELL at each apex
## (C1-continuous, natural apex slow-down). All params come from level JSON (INV-7); NO Tuning
## constant is touched — the kill pipeline is reused as-is (fence per §2.0 / §7).
##
## Collision: on LAYER_HAZARDS (layer 4, the instakill layer — the same Hazard.gd lives on), sensing
## players + props. Overlap-only (the de-risked ship): the body can clip the visual but the overlap
## kills; solid collision is an optional polish follow-up.

const LAYER_HAZARDS := 1 << 3          # 8 — layer 4, the instakill hazard layer (Hazard.gd's layer)
const MASK_TARGETS := (1 << 0) | (1 << 1)   # players (1) + enemies/props (2), matching Hazard.gd

# --- Glossy Toybox mallet sprite (pays down the no-code-drawn-assets debt; owner-flagged). A glossy
# steel mallet: rectangular HEAD (yellow/black hazard band) up top, chocolate handle below. The image
# is 650x724; the HEAD CENTER sits at image (325,155), so offsetting by (0, +207) from the texture
# centre (325,362) lands the head centre on the node origin — which is the sprite's rotation pivot and
# is placed at the lethal head each frame. The HANDLE runs from the head centre down to image y=690
# (535px), so at MALLET_SCALE the handle bottom is (535*scale) back toward the hub. Scaled so the head
# reads ~2.4x the lethal radius (glossy art slightly overhangs its hitbox). ---
const HAMMER_TEX: Texture2D = preload("res://assets/hazards/hammer.png")
const MALLET_SCALE := 0.30             # uniform (undistorted) scale: head width ~171px vs radius 70
const MALLET_HEAD_OFFSET_Y := 207.0    # texture-centre -> head-centre shift (px, pre-scale)
const MALLET_HANDLE_LEN_PX := 535.0    # head-centre -> handle-bottom distance in the image (px)
var _mallet: Sprite2D

# --- motion params (from JSON; all data, no Tuning) ---
var pivot: Vector2 = Vector2.ZERO
var arm_len: float = 590.0
var arc_rad: float = deg_to_rad(150.0)   # full swept arc; the blade spans base +/- arc/2
var base_rad: float = 0.0                # center orientation of the sweep (0 = straight DOWN)
var period_s: float = 4.5                # a full there-and-back cycle (owner: "jump every ~5s")
var phase: float = 0.0                   # 0..1 phase offset (two hammers can run offset rhythms)
var dwell_frac: float = 0.24             # fraction of the period hanging at EACH apex (the clear beat)
var radius: float = 70.0                 # the lethal head (the blade mass) collision radius
var head_len: float = 150.0              # visual blade length along the arm
var head_w: float = 96.0                 # visual blade width across the arm

# --- mode-owned ball-whack (v8_sports_courts.md §3.2). The rotor senses the sports Ball by DISTANCE
# to the blade head (group "sports_ball"), NOT via its collision mask (which stays players+props for
# the kill path), so no mask change is needed and BRAWL levels — where the group is empty — are a pure
# no-op. One clean whack per pass via a per-contact cooldown (the _touch_cd shape). The ball is never
# killed (it has no kill()); the hammer only calls the one mode-owned Ball hook. ---
const BALL_WHACK_CD := 0.4             # seconds between ball whacks (one clean strike per sweep)
var _ball_cd: float = 0.0

var _t: float = 0.0
var _head_pos: Vector2 = Vector2.ZERO
var _prev_head_pos: Vector2 = Vector2.ZERO
var _head_speed: float = 0.0
var _shape: CollisionShape2D
# LETHAL-only-while-combat-is-live gate (shared hazard doctrine). The blade MOVES + telegraphs from
# the moment it spawns so players read the rhythm during the intro/countdown, but the KILL is
# suppressed until EventBus.combat_started ("BOUNCE!") and re-suppressed on EventBus.combat_ended
# (STAGE_END / MATCH_END) — so a player frozen at spawn under the arc during the pre-match phases is
# never killed (and thus never left stuck-dead by PartyMatch._on_killed's outside-COMBAT return).
var _lethal: bool = false

func setup_from_json(o: Dictionary) -> void:
	radius = float(o.get("radius", 70.0))
	head_len = float(o.get("head_len", radius * 2.1))
	head_w = float(o.get("head_w", radius * 1.4))
	period_s = maxf(0.2, float(o.get("period_s", 4.5)))
	phase = float(o.get("phase", 0.0))
	dwell_frac = clampf(float(o.get("dwell_frac", 0.24)), 0.0, 0.45)
	var pv = o.get("pivot", {"x": 0.0, "y": 0.0})
	pivot = Vector2(float(pv.get("x", 0.0)), float(pv.get("y", 0.0)))
	arm_len = float(o.get("arm_len", 590.0))
	arc_rad = deg_to_rad(float(o.get("arc_deg", 150.0)))
	base_rad = deg_to_rad(float(o.get("base_deg", 0.0)))

func _ready() -> void:
	# node at world origin: local == global, so _draw / shape positions are all in world coords.
	position = Vector2.ZERO
	collision_layer = LAYER_HAZARDS
	collision_mask = MASK_TARGETS
	monitoring = true
	set_meta("hazard", true)
	set_meta("spinning_hammer", true)
	_shape = CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = radius
	_shape.shape = circ
	add_child(_shape)
	_head_pos = _compute_head(0.0)
	_prev_head_pos = _head_pos
	_shape.position = _head_pos
	z_index = 40   # over platforms/void, under HUD
	# the mallet sprite: head centre pinned to the node origin (the rotation pivot), scaled undistorted,
	# added AFTER _draw so it renders on top of the code-drawn swept-arc telegraph. Head leads the swing.
	_mallet = Sprite2D.new()
	_mallet.texture = HAMMER_TEX
	_mallet.centered = true
	_mallet.offset = Vector2(0.0, MALLET_HEAD_OFFSET_Y)
	_mallet.scale = Vector2(MALLET_SCALE, MALLET_SCALE)
	add_child(_mallet)
	_update_mallet()
	# lethal gate: enable on the starting gun, disable when the stage's combat closes.
	if not EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.connect(_on_combat_started)
	if not EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.connect(_on_combat_ended)

func _on_combat_started() -> void:
	_lethal = true

func _on_combat_ended() -> void:
	_lethal = false

## Shaped oscillator in [0,1] phase: two smootherstep swings + a flat DWELL at each extreme (the
## clear beat). Returns [-1, 1]; smootherstep endpoints have ZERO derivative, so it joins the flat
## dwell with no velocity discontinuity (natural apex slow-down, deterministic). Same shape the
## validated MovingHazard uses.
func _osc(t: float) -> float:
	var u := fposmod(t / period_s + phase, 1.0)
	var d := dwell_frac
	var swing := (1.0 - 2.0 * d) * 0.5   # each of the two swings is this fraction of the period
	if swing <= 0.0001:
		return 0.0
	if u < swing:
		return lerpf(-1.0, 1.0, _smoother(u / swing))                 # swing A -> B
	elif u < swing + d:
		return 1.0                                                    # DWELL at +apex (clear beat)
	elif u < 2.0 * swing + d:
		return lerpf(1.0, -1.0, _smoother((u - swing - d) / swing))   # swing B -> A
	else:
		return -1.0                                                   # DWELL at -apex (clear beat)

static func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

func _compute_head(t: float) -> Vector2:
	var s := _osc(t)
	var angle := base_rad + s * (arc_rad * 0.5)
	# angle measured from straight-DOWN (base 0), so the blade hangs below the hub and sweeps sideways.
	return pivot + arm_len * Vector2(sin(angle), cos(angle))

func _physics_process(delta: float) -> void:
	_t += delta
	_prev_head_pos = _head_pos
	_head_pos = _compute_head(_t)
	if delta > 0.0:
		_head_speed = (_head_pos - _prev_head_pos).length() / delta
	_shape.position = _head_pos
	_update_mallet()
	if _ball_cd > 0.0:
		_ball_cd = maxf(0.0, _ball_cd - delta)
	queue_redraw()
	_kill_overlapping()
	_whack_ball()

## LETHAL contact — the whole mechanic. Any live Killable body overlapping the head dies via the
## EXISTING kill pipeline with cause &"ring_out" (§2.0#1): no new impulse, no shove, no hitstun. The
## &"ring_out" cause inherits the 6.0s ring-out credit window, so a rival who knocked the victim in
## within the window is credited and an untouched victim is an uncredited self-fall (§2.0#4). The
## hammer NEVER passes itself as attacker (it is not a Player -> no invented environment scorer).
func _kill_overlapping() -> void:
	if not _lethal:
		return   # pre-combat / post-stage: the blade still sweeps + telegraphs, but never kills.
	for body in get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if body.has_method("is_dead") and body.is_dead():
			continue
		if body.has_method("kill"):
			body.kill(&"ring_out", null)

## Ball-whack (v8_sports_courts.md §3.2): when the blade head sweeps over the sports Ball, punt it
## along the blade's SWING direction (blended slightly outward from the pivot so a ball at an apex
## dwell — where swing speed is ~0 — still flies off), at Ball.BALL_HAMMER_IMPULSE. One whack per
## BALL_WHACK_CD so a lingering ball isn't machine-gunned. Impulse capped to BALL_MAX_SPEED by the
## hook, so the whack reads as a cannon-strike yet stays chaseable (Pillar 5). Mode-owned: touches no
## ball-physics constant, only the one ball entry point.
func _whack_ball() -> void:
	if _ball_cd > 0.0:
		return
	var reach := radius + Ball.BALL_RADIUS
	for b in get_tree().get_nodes_in_group("sports_ball"):
		if not is_instance_valid(b) or not b.has_method("receive_hazard_impulse"):
			continue
		if (b.global_position - _head_pos).length() > reach:
			continue
		var swing: Vector2 = _head_pos - _prev_head_pos
		var radial: Vector2 = _head_pos - pivot
		var dir: Vector2 = radial.normalized() if radial.length() > 1.0 else Vector2.DOWN
		if swing.length() > 1.0:
			dir = (swing.normalized() * 0.75 + dir * 0.25).normalized()
		b.receive_hazard_impulse(dir * Ball.BALL_HAMMER_IMPULSE)
		_ball_cd = BALL_WHACK_CD
		break

# Orient + place the mallet sprite so its head centre rides the lethal head and its head LEADS the
# swing (the striped face points outward along the arm). local -Y (image "up", the head tip) is aimed
# down the arm direction, so rotation = along.angle() + PI/2 (verified: base swing => rotation PI).
func _update_mallet() -> void:
	if _mallet == null:
		return
	var along := (_head_pos - pivot)
	if along.length() < 1.0:
		along = Vector2.DOWN
	along = along.normalized()
	_mallet.position = _head_pos
	_mallet.rotation = along.angle() + PI * 0.5

# ------------------------------------------------------------------ telegraphy (INV-12: display only)
# The striped HEAD + handle are now the hammer.png sprite (child, drawn in _update_mallet). _draw keeps
# only the transient swept-arc TELEGRAPH (allowed VFX) plus the slim mounting arm + hub that connect the
# hub to the mallet's handle (structural, since the sprite handle does not reach all the way to the pivot
# at head-matched scale — see the report note).
func _draw() -> void:
	var steel := Color(0.16, 0.17, 0.20)
	var steel_hi := Color(0.34, 0.36, 0.42)
	var danger := Color(0.86, 0.16, 0.16, 0.20)   # matte hazard-red swept-arc guide (void-rim palette)
	# 1) the swept danger-arc (faint, wide) — reads WHERE the blade travels before it arrives.
	var pts := PackedVector2Array()
	var n := 32
	for i in range(n + 1):
		var th := base_rad + lerpf(-arc_rad * 0.5, arc_rad * 0.5, float(i) / float(n))
		pts.append(pivot + arm_len * Vector2(sin(th), cos(th)))
	draw_polyline(pts, danger, 34.0)
	# 2) the slim mounting arm from the hub to where the mallet sprite's handle begins.
	var along := (_head_pos - pivot)
	if along.length() < 1.0:
		along = Vector2.DOWN
	along = along.normalized()
	var handle_bottom := _head_pos - along * (MALLET_HANDLE_LEN_PX * MALLET_SCALE)
	draw_line(pivot, handle_bottom, steel_hi, 16.0)
	draw_line(pivot, handle_bottom, steel, 9.0)
	# 3) the hub mount (a chunky bracket at the pivot).
	draw_circle(pivot, 30.0, steel)
	draw_circle(pivot, 20.0, steel_hi)
