extends Node2D
## WK-37 ghost PUFF CLOUD (docs/specs/wk37a_ghost_goats_2026-11-14.md §2.3, art brief §2/E6-E9).
## Phases: TELEGRAPH (dotted owner-colour outline inflates, NON-solid) -> SOLID (marshmallow-tier bounce surface, sinks)
## -> FADE (non-solid) -> freed. Removed at Tuning.ghost_puff_telegraph + life + fade after the press.
##
## NOT a physics body on any layer (deliberate — the containment rules): a collider on the surface layer (3) would be
## hit by props (balls/bombs/debris) and seen by every bot raycast (_over_void / landing logic). Instead this node
## resolves contact itself, once per physics tick AFTER the players moved (process_physics_priority), and only for:
##   * a living, un-frozen player in NEUTRAL control -> the standard surface contract: BounceResolver.resolve() with
##     the marshmallow tier (x the player's bounce_mult / apex profile, + directional influence) and Player._on_bounced()
##     (tier-scaled refuel; the underside guard means a bonk refunds nothing) — the same calls Player._resolve_bounces
##     makes for a level platform;
##   * a super_active body -> passes straight through, velocity untouched, the cloud POPS (K-4);
##   * a hitstunned body -> passes straight through, untouched, the cloud POPS (K-4, dry-reflect doctrine);
##   * a player already overlapping when it turns solid -> ignored by this cloud until fully separated.
## Nothing else (balls, bombs, bubbles, debris, other clouds) can ever touch it. It never writes last_attacker.

const PUFF_TEX := preload("res://assets/fx/ghost_puff.png")
const STROKE_TEX := preload("res://assets/fx/ghost_puff_stroke.png")
const DASH_TEX := preload("res://assets/fx/ghost_puff_dash.png")
const PUFF_SHADER := preload("res://assets/shaders/ghost_puff.gdshader")
const TINT_SHADER := preload("res://assets/shaders/fx_tint.gdshader")
const RING_TEX := preload("res://assets/fx/ko_blast_ring.png")
const SOFT_TEX := preload("res://assets/fx/puff_soft.png")
const ART_CONTENT_W := 1024.0   # ghost_puff.png content width (canvas 1216, 96 px pad each side; derived layers share it)
const SIDE_TOL := 10.0          # px: how far a body may already be inside an edge and still count as coming from that side
# WK-37c BLOCKED marker (Tuning WK-37d block: ghost_blocked_*): a puff press whose cloud would overlap a platform
# shows this cloud's dotted outline at full size, red, blinking + a "no" head-shake, then it's gone. Never solid.

var runner                      # PartyMatch (read-only + the players' standard bounce calls)
var director                    # GhostDirector (contact / pop callbacks)
var owner_idx := -1
var color := Color.WHITE
var size := Vector2(180, 64)
var t := 0.0                    # s since the press
var phase := "telegraph"        # telegraph | solid | fade | gone
var popped_by := ""             # "" | super | stun | hush | bounds | stage
var record: Dictionary = {}     # the director's telemetry row for this puff (contacts appended here)
var blocked := false            # WK-37c: presentation-only "blocked here" marker (set before add_child)

var _body: Sprite2D
var _stroke: Sprite2D
var _dash: Sprite2D
var _vis: Node2D
var _ignore := {}               # player -> true: overlapping when it turned solid (ignored until separated)
var _prev := {}                 # player -> last tick position (side classification)
var _wobble := 0.0

func setup(runner_ref, director_ref, idx: int, col: Color) -> void:
	runner = runner_ref
	director = director_ref
	owner_idx = idx
	color = col
	size = Tuning.ghost_puff_size

func _ready() -> void:
	process_physics_priority = 10   # after every Player has moved this tick
	var k: float = size.x / ART_CONTENT_W
	_vis = Node2D.new()
	add_child(_vis)
	_stroke = Sprite2D.new()
	_stroke.texture = STROKE_TEX
	_stroke.scale = Vector2(k, k)
	_stroke.self_modulate = color
	_vis.add_child(_stroke)
	_body = Sprite2D.new()
	_body.texture = PUFF_TEX
	_body.scale = Vector2(k, k)
	var m := ShaderMaterial.new()
	m.shader = PUFF_SHADER
	_body.material = m
	_body.self_modulate = Color(color.r, color.g, color.b, 0.85)
	_vis.add_child(_body)
	_dash = Sprite2D.new()
	_dash.texture = DASH_TEX
	_dash.scale = Vector2(k, k)
	_dash.self_modulate = color
	add_child(_dash)
	_stroke.visible = false
	_body.visible = false
	if blocked:
		phase = "blocked"
		_dash.scale = Vector2(k, k)
		return
	_apply_phase_visuals(0.0)

func rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)

func is_solid() -> bool:
	return phase == "solid"

func _physics_process(delta: float) -> void:
	if phase == "gone":
		return
	t += delta
	if phase == "blocked":
		_tick_blocked()
		return
	var tel: float = Tuning.ghost_puff_telegraph
	var life: float = Tuning.ghost_puff_life
	var fade: float = Tuning.ghost_puff_fade
	if phase == "telegraph" and t >= tel:
		phase = "solid"
		_on_solidify()
	if phase == "solid" and t >= tel + life:
		phase = "fade"
	if phase == "fade" and t >= tel + life + fade:
		_remove()
		return
	if phase == "solid" or phase == "fade":
		global_position.y += Tuning.ghost_puff_sink_speed * delta
		if runner != null and not (runner.bounds as Rect2).has_point(global_position):
			pop("bounds")
			return
	if phase == "solid":
		_resolve_contacts()
	_remember_positions()
	_apply_phase_visuals(delta)

func _living() -> Array:
	var out: Array = []
	if runner == null:
		return out
	for p in runner.players:
		if is_instance_valid(p) and not p.is_dead() and not p.frozen and p.visible:
			out.append(p)
	return out

func _radius_of(p) -> float:
	var rv: Variant = p.get("_radius")
	return float(rv) if rv != null else 44.0

func _overlaps(p, r: Rect2) -> bool:
	var pos: Vector2 = p.global_position
	var cp := Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))
	return cp.distance_to(pos) < _radius_of(p)

func _on_solidify() -> void:
	var r := rect()
	for p in _living():
		if _overlaps(p, r):
			_ignore[p] = true   # rule 5: no spawn-inside pop/teleport; ignored until separated

func _remember_positions() -> void:
	for p in _living():
		_prev[p] = p.global_position

## One contact resolution per tick (players already moved this tick — priority 10).
func _resolve_contacts() -> void:
	var r := rect()
	for p in _living():
		var over: bool = _overlaps(p, r)
		if _ignore.has(p):
			if not over:
				_ignore.erase(p)
			continue
		if not over:
			continue
		# K-4: the decisive moments of a KO belong to the living — a super or a stunned body pops the cloud untouched.
		if p.is_super_active():
			pop("super")
			return
		if p.in_hitstun():
			pop("stun")
			return
		_bounce(p, r)

## Neutral contact: the standard surface contract (what Player._resolve_bounces does for a tier platform).
func _bounce(p, r: Rect2) -> void:
	var rad: float = _radius_of(p)
	var prev: Vector2 = _prev.get(p, p.global_position)
	var n: Vector2
	var side := ""
	if prev.y + rad <= r.position.y + SIDE_TOL:
		n = Vector2.UP
		side = "top"
	elif prev.y - rad >= r.end.y - SIDE_TOL:
		n = Vector2.DOWN
		side = "under"
	else:
		n = Vector2.LEFT if prev.x < r.get_center().x else Vector2.RIGHT
		side = "side"
	# relative to the sinking cloud: only a body moving INTO the face bounces (a body leaving after a bounce is skipped)
	var v_rel: Vector2 = p.velocity - Vector2(0.0, Tuning.ghost_puff_sink_speed)
	if v_rel.dot(n) >= 0.0:
		return
	var contact: Vector2 = p.global_position
	match side:
		"top":
			p.global_position.y = r.position.y - rad
			contact = Vector2(p.global_position.x, r.position.y)
		"under":
			p.global_position.y = r.end.y + rad
			contact = Vector2(p.global_position.x, r.end.y)
		_:
			p.global_position.x = (r.position.x - rad) if n.x < 0.0 else (r.end.x + rad)
			contact = Vector2(r.position.x if n.x < 0.0 else r.end.x, p.global_position.y)
	var fuel_before: float = float(p.fuel)
	var bm: float = float(p.get("bounce_mult")) if p.get("bounce_mult") != null else 1.0
	var tier_h: float = Tuning.bounce_height_for(Tuning.ghost_puff_tier) * bm
	var apex: float = p.profile.eff_bounce_apex() if p.get("profile") != null else 1.0
	var g: Vector2 = GravityField.get_gravity_at(p.global_position)
	var boost_held: bool = p.is_boosting()
	p.velocity = BounceResolver.resolve(p.velocity, n, tier_h * apex, g.length(), boost_held)
	# directional influence (the standard contract): the stick along the surface steers the launch
	var aim_in: Vector2 = p.get_aim() if bool(p.get("_aim_active")) else Vector2.ZERO
	var tangent := Vector2(-n.y, n.x)
	p.velocity += tangent * aim_in.dot(tangent) * Tuning.bounce_di
	var launch_speed: float = maxf(0.0, p.velocity.dot(n))
	var refund: float = Tuning.fuel_per_bounce * sqrt(tier_h / Tuning.bounce_height_trampoline) if Tuning.ghost_puff_refuels else 0.0
	if director != null:
		director.begin_cloud_bounce()
	p._on_bounced(boost_held, refund, launch_speed, contact, n)
	if director != null:
		director.end_cloud_bounce()
		director.on_cloud_contact(self, p, side, fuel_before)
	_wobble = 0.15

func _apply_phase_visuals(delta: float) -> void:
	var tel: float = Tuning.ghost_puff_telegraph
	match phase:
		"telegraph":
			var k: float = clampf(t / maxf(tel, 0.01), 0.0, 1.0)
			var s: float = lerpf(0.55, 1.0, _ease_out_back(k))
			_dash.visible = true
			_dash.scale = Vector2.ONE * (size.x / ART_CONTENT_W) * s
			_dash.modulate.a = lerpf(0.6, 1.0, 0.5 + 0.5 * sin(t * TAU * 6.0))
			_stroke.visible = false
			_body.visible = false
		"solid", "fade":
			_dash.visible = false
			_stroke.visible = true
			_body.visible = true
			var since: float = t - tel
			var pop_s: float = lerpf(1.08, 1.0, clampf(since / 0.08, 0.0, 1.0))
			var sy := 1.0
			if _wobble > 0.0:
				_wobble = maxf(0.0, _wobble - delta)
				sy = lerpf(1.0, 0.85, _wobble / 0.15)
			_vis.scale = Vector2(pop_s, pop_s * sy)
			if phase == "fade":
				var f: float = clampf((t - tel - Tuning.ghost_puff_life) / maxf(Tuning.ghost_puff_fade, 0.01), 0.0, 1.0)
				_vis.modulate.a = 1.0 - f

## Blocked marker: blink + decaying head-shake, then free. No contacts, no director callbacks, no telemetry.
func _tick_blocked() -> void:
	if t >= Tuning.ghost_blocked_time:
		phase = "gone"
		queue_free()
		return
	var k: float = 1.0 - t / Tuning.ghost_blocked_time
	_dash.position.x = sin(t * TAU * Tuning.ghost_blocked_shake_hz) * Tuning.ghost_blocked_shake_px * k
	_dash.modulate.a = (1.0 if fmod(t * Tuning.ghost_blocked_blink_hz, 1.0) < 0.6 else 0.35) * clampf(k * 3.0, 0.0, 1.0)

func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

## Pop: super / stun pass-through, hush, kill bounds, stage end. Owner-coloured ring + puffs; ZERO camera shake (§4.5).
func pop(reason: String) -> void:
	if phase == "gone":
		return
	popped_by = reason
	if reason != "stage":
		_pop_fx()
	_remove()

func _remove() -> void:
	if phase == "gone":
		return
	phase = "gone"
	if director != null:
		director.on_cloud_removed(self)
	queue_free()

func _pop_fx() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = TINT_SHADER
	var ring := Sprite2D.new()
	ring.texture = RING_TEX
	ring.material = mat
	ring.self_modulate = color
	ring.global_position = global_position
	ring.scale = Vector2.ONE * 0.12
	parent.add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * 0.36, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(ring.queue_free)
	var p := CPUParticles2D.new()
	p.texture = SOFT_TEX
	p.material = mat
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 8
	p.lifetime = 0.45
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.damping_min = 200.0
	p.damping_max = 320.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.6
	p.color = Color(color.r, color.g, color.b, 0.9)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
