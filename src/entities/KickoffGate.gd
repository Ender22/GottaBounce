extends Node2D
## WK-131 ROCKETBALL KICKOFF GATE (spec docs/specs/wk131_kickoff_rule_2026-11-15.md §4, art brief
## docs/briefs/kickoff_gate_2026-11-15.md). One per soccer goal mouth, spawned CLOSED by SportsMode.on_stage_ready and
## freed with the level on the next kickoff reload. Self-contained: no class_name (SportsMode preloads the scene and
## calls it duck-typed).
##
## RULE: a ball-only collider sits in the mouth plane (its own physics layer LAYER_GATE; only Ball masks it, goats fly
## straight through: never a ledge or a lean-on wall). start(ball, T) runs the gate on the ball's live clock
## (Ball.ball_clock()); at T the collider drops on that exact physics tick, the GoalZone latch is un-gated, a ball resting
## on the gate gets the spit (Tuning.sports_gate_spit_speed outward, not a touch), and the lead gate emits
## EventBus.kickoff_gates_open. open_now() is the LIVE BALL (rule 2) early open.
##
## LOOK (brief §2-§7): a fat cream/gold candy-stripe pole (goal_frame.png's tube run through kickoff_gate.gdshader) with a
## padlock badge inside a draining gold ring. The pole's ends tuck under duplicates of the cage's own post-cap knobs
## (pixel-identical overlays, team modulate, drawn last), so the pole visibly slides UP into the top knob on the open.
## Motion: drop-in at stage intro, flex + flash + star + "NOT YET!" on a hit, warning swing/lift/scroll/shake, badge
## burst + 0.2 s retract ending exactly at T, socket thunk. Every visual state below is a function of the ball clock
## (pre-GO = 0), so a fixed-fps recording sees the same frames every time. Presentation never feeds back into physics.

signal hit(speed)          # one per new ball contact >= Tuning.sports_gate_fx_min_speed (SportsMode counts kickoff_stats)
signal opened(spit)        # the collider dropped; spit = this gate popped a resting ball

const TUBE_TEX: Texture2D = preload("res://assets/world/sports/goal_frame.png")
const BADGE_LOCKED: Texture2D = preload("res://assets/world/sports/gate_badge_locked.png")
const BADGE_OPEN: Texture2D = preload("res://assets/world/sports/gate_badge_open.png")
const STAR_TEX: Texture2D = preload("res://assets/fx/star_sparkle.png")
const BLAST_STAR_TEX: Texture2D = preload("res://assets/fx/ko_blast_star.png")
const BLAST_RING_TEX: Texture2D = preload("res://assets/fx/ko_blast_ring.png")
const PUFF_TEX: Texture2D = preload("res://assets/fx/puff_soft.png")
const FX_TINT: Shader = preload("res://assets/shaders/fx_tint.gdshader")
const POP_SCENE: PackedScene = preload("res://scenes/entities/KickoffGatePop.tscn")
const DRAIN_RING := preload("res://src/ui/DrainRing.gd")   # WK-154: the ring look, shared with the Brawl spawn padlock

const LAYER_GATE := 1 << 7          # the gate's OWN physics bit (Ball masks it; players never do)
const POP_TEXT_VALUE := "NOT YET!"  # the ONE constant for the hit pop copy (brief §6.3: "NOT YET!" says temporary; the spec had "LOCKED!")
const OPEN_TEXT_VALUE := "OPEN!"    # WK-155 (a): the open call each gate pops at the open, every kickoff (NOT YET! -> OPEN! pair)
const Z_GATE := -1                  # in front of the cage frame (-1, added after it), behind walls (0) / goats / ball (40)
const Z_FX := 39                    # hit star / pop / bursts: over goats, under the ball
# palette (brief §5)
const CREAM := Color("#FFF3D6")
const CHOC := Color("#3B241B")
const RING_GOLD := Color("#FFC93C")
const RING_DRAINED_A := 0.45        # the drained part of the ring = chocolate backing at this alpha
const RING_OUTLINE := 3.0           # wpx chocolate outline each side of the gold band
# motion constants the brief fixes (not tuning surfaces)
const DROP_DELAY := 0.15            # s after spawn (= STAGE_INTRO start) the drop-in begins
const DROP_REBOUND := 4.0           # wpx rebound off the bottom socket
const DROP_REBOUND_T := 0.12        # s the rebound takes
const BADGE_IN_T := 0.22            # s the badge scale-in (0.6 -> 1.0, back-ease overshoot) takes
const WARN_WHITE := 0.6             # peak white mix of the warning brightness swing
const WARN_LIFT_T := 0.1            # s the warning lift takes
const WARN_TREMBLE := 1.5           # wpx vertical tremble while lifted
const WARN_TREMBLE_HZ := 22.0
const BADGE_POP_T := 0.06           # s the open badge scales 1.0 -> 1.3
const BADGE_POP_SCALE := 1.3
const BADGE_FLY := 40.0             # wpx the open badge flies up while fading (gone by T + 0.1)
const RETRACT_EXTRA := 12.0         # wpx the retract overshoots so the pole's bottom end is fully above the top tube at T
const RETRACT_EVENT_S := 0.08       # rule 2 event open: 0.08 s visual retract (brief §6.5 note)
const RETRACT_LEAD := 0.004         # s the visual retract starts early (half a 120 Hz tick): the ball clock is a float sum, so a
                                    # frame landing exactly on T - 0.2 rounds either way; this keeps all 6 frames at 30 fps
const THUNK_T := 0.12               # s the top socket squash-pop takes
const THUNK_SCALE := 1.12
const HIDE_AFTER := 0.16            # s after the open the gate stops drawing (badge gone at +0.1, thunk at +0.12)
const FLEX_HALF := 0.12             # s first half-wobble of the bow (spec's "0.12 s squash"), scaled by flex_time / 0.25
const FLEX_DECAY := 5.0             # /s bow damping (second lobe ~40 %)
# source-px facts of goal_frame.png (measured at WK-131 intake): the plain back-tube run and the post-cap knobs
const TUBE_SRC := Rect2(13.0, 300.0, 126.0, 1000.0)
const KNOB_TOP_SRC := Vector2(583.0, 93.0)     # knob centre in the TOP cap piece's local src px
const KNOB_BOT_SRC := Vector2(585.0, 126.5)    # knob centre in the BOTTOM cap piece's local src px
const SOCKET_CROP_X := 500.0                   # socket overlays redraw the cap piece from this src x (the knob end)

var team: int = 0                   # the DEFENDING team of the gated goal (GoalZone.team)
var lead: bool = false              # the lead gate voices the shared cues (drop-in, wind-up ticks, open)
var _zone: Node = null
var _md: float = 1.0                # +1 = mouth faces right (team 0, left goal), -1 = faces left
var _horizontal_mouth: bool = false # up/down mouth: collider only, no art (no soccer court has one)
var _h: float = 300.0               # mouth span (zone height)
var _body: StaticBody2D
var _shape: CollisionShape2D
var _pole: Polygon2D
var _pole_mat: ShaderMaterial
var _ring: Node2D
var _badge: Sprite2D
var _badge_mat: ShaderMaterial
var _socket_top: Node2D = null      # pivot at the top knob centre (the thunk scales it)
var _socket_bot: Node2D = null
var _fx_mat: ShaderMaterial
var _veil_mat: ShaderMaterial = null   # the cage's cords-only FRONT veil (z 42): kept off the pole while it is closed
var _veil_interior: Vector4 = Vector4.ZERO
var _badge_y: float = 0.0           # WK-155 (b): local y of the badge + ring centre (Tuning.sports_gate_badge_anchor along the mouth)
var _open_popped: bool = false      # WK-155 (a): this gate's OPEN! call has fired this kickoff
var open_pops: int = 0              # QA: OPEN! calls this gate has shown

var _ball: Node = null
var _started: bool = false
var _T: float = 3.0                 # scheduled open (ball clock)
var _open_t: float = INF            # actual collider drop (ball clock)
var _retract_start: float = INF
var _retract_s: float = 0.2
var _opened: bool = false
var _event_open: bool = false       # rule 2 early open (no warning)
var _spit: bool = false
var _age: float = 0.0               # s since spawn (drop-in clock: STAGE_INTRO starts with the spawn)
var _hit_age: float = -1.0
var _hit_amp: float = 0.0           # signed wpx along x (toward the net)
var _hit_y: float = 0.0             # local contact y
var _flash_age: float = -1.0
var _pop_cd: float = 0.0
var _tick_n: int = 0
var _shake: Vector2 = Vector2.ZERO
var _burst_done: bool = false
var _thunk_done: bool = false
var _hidden: bool = false
var _dropped_cue: bool = false
var hits: int = 0                   # QA: FX-speed contacts this kickoff
var hit_speeds: Array = []          # QA

func _ready() -> void:
	_body = $Body
	_shape = $Body/Shape
	_pole = $Pole
	_pole_mat = _pole.material as ShaderMaterial
	_ring = $Ring
	_badge = $Badge
	_badge_mat = _badge.material as ShaderMaterial
	z_as_relative = false
	z_index = Z_GATE
	_ring.draw.connect(_draw_ring)
	# WK-155 (b): badge + ring draw ABOVE goats (a keeper parked in the mouth hid them) but under the ball (z 40) and FX.
	for n in [_ring, _badge]:
		(n as Node2D).z_as_relative = false
		(n as Node2D).z_index = Tuning.sports_gate_badge_z
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = FX_TINT

## Bind to GoalZone `zone` (already in the tree, cage built) and build collider + art. Call AFTER add_child.
func setup(zone: Node, is_lead: bool) -> void:
	_zone = zone
	lead = is_lead
	team = int(zone.get("team"))
	var zn: Node2D = zone as Node2D
	var w: float = float(zone.get("w"))
	_h = float(zone.get("h"))
	var mdir: Vector2 = zone.call("_mouth_dir")
	_horizontal_mouth = absf(mdir.x) < 0.5
	if _horizontal_mouth:
		# up/down mouth (spec §4.1): the gate spans the zone's WIDTH at the mouth-side edge. No cage art exists for
		# these mouths (GoalZone warns), so the gate is collider-only too.
		push_warning("KickoffGate: up/down goal mouth has no gate art - collider only")
		global_position = zn.global_position + mdir * (_h * 0.5)
		_build_body(Vector2(w, Tuning.sports_gate_thickness))
		_pole.visible = false
		_ring.visible = false
		_badge.visible = false
		return
	_md = 1.0 if mdir.x > 0.0 else -1.0
	var mx: float = float(zone.get("net_mouth_x"))
	if is_nan(mx):
		mx = zn.global_position.x + _md * w * 0.5   # spec: the zone edge on the mouth side
	global_position = Vector2(mx, zn.global_position.y)
	_build_body(Vector2(Tuning.sports_gate_thickness, _h))
	_build_pole()
	_badge.scale = Vector2.ONE * (Tuning.sports_gate_badge_wpx / float(BADGE_LOCKED.get_width()))
	# WK-155 (b): the badge slides along the mouth (+1 = bottom, the padlock on the bottom socket), clear of a keeper's
	# body (it holds the mouth centre) and of its name tag (above its head).
	var ring_outer: float = Tuning.sports_gate_ring_r + Tuning.sports_gate_ring_band * 0.5 + RING_OUTLINE
	_badge_y = clampf(Tuning.sports_gate_badge_anchor, -1.0, 1.0) * maxf(0.0, _h * 0.5 - ring_outer - Tuning.sports_gate_badge_margin)
	_ring.position = Vector2(0.0, _badge_y)
	_build_sockets()
	_mask_front_veil()
	_apply_visuals(0.0)

func _build_body(size: Vector2) -> void:
	_body.collision_layer = LAYER_GATE
	_body.collision_mask = 0
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	# Godot 2D combines bounce as clamp(ball + gate, 0, 1): an ABSORBENT gate subtracts, so the pair lands on
	# Tuning.sports_gate_bounce against the soccer ball's own restitution.
	var pm := PhysicsMaterial.new()
	var b: float = Tuning.sports_gate_bounce - Ball.BALL_RESTITUTION
	pm.absorbent = b < 0.0
	pm.bounce = absf(b)
	pm.friction = Ball.BALL_FRICTION
	_body.physics_material_override = pm
	_body.set_meta("net_fx", self)   # Ball._wk66a_net_contacts reports new contacts here (on_ball_contact)

func _build_pole() -> void:
	var half: float = Tuning.sports_gate_bar_w * 0.5
	var top: float = -_h * 0.5 - 8.0
	var bot: float = _h * 0.5 + 8.0
	var pad: float = Tuning.sports_gate_flex_amp + 4.0
	_pole.polygon = PackedVector2Array([Vector2(-half - pad, top - 2.0), Vector2(half + pad, top - 2.0),
		Vector2(half + pad, bot + 2.0), Vector2(-half - pad, bot + 2.0)])
	_pole_mat.set_shader_parameter("tube_tex", TUBE_TEX)
	_pole_mat.set_shader_parameter("tube_src", Vector4(TUBE_SRC.position.x, TUBE_SRC.position.y, TUBE_SRC.size.x, TUBE_SRC.size.y))
	_pole_mat.set_shader_parameter("tex_size", TUBE_TEX.get_size())
	_pole_mat.set_shader_parameter("bar_w", Tuning.sports_gate_bar_w)
	_pole_mat.set_shader_parameter("top_y", top)
	_pole_mat.set_shader_parameter("bot_y", bot)
	_pole_mat.set_shader_parameter("stripe_period", Tuning.sports_gate_stripe_period)
	_pole_mat.set_shader_parameter("clip_top_wy", global_position.y - _h * 0.5)
	_pole_mat.set_shader_parameter("flex", Vector4(0.0, 0.0, Tuning.sports_gate_flex_sigma, 0.0))
	# WK-155 (c): barrier stripes that contrast with the cage trim and the gold ring (were cream / honey gold).
	_pole_mat.set_shader_parameter("stripe_a", Tuning.sports_gate_stripe_a)
	_pole_mat.set_shader_parameter("stripe_b", Tuning.sports_gate_stripe_b)

## Pixel-identical duplicates of the cage's top / bottom post-cap pieces, cropped to the knob end and re-added AFTER the
## pole (brief §2 "Sockets = reuse"): same region, transform, material and team modulate. Each sits under a pivot at its
## knob centre so the open's thunk is a uniform squash-pop about the knob.
func _build_sockets() -> void:
	var art: Node = _zone.get_node_or_null("NetArt")
	if art == null:
		return
	var frame: Node2D = art.get("_frame") as Node2D
	if frame == null or frame.get_child_count() < 2:
		return
	var n: int = frame.get_child_count()
	var top_cap: Sprite2D = frame.get_child(n - 2) as Sprite2D
	var bot_cap: Sprite2D = frame.get_child(n - 1) as Sprite2D
	if top_cap == null or bot_cap == null:
		return
	_socket_top = _make_socket(top_cap, KNOB_TOP_SRC, frame)
	_socket_bot = _make_socket(bot_cap, KNOB_BOT_SRC, frame)

## The WK-66a front veil (cords over the cage interior, z 42, so a scored ball reads as inside the net) would draw its cords
## across the inner half of the pole, which sits ON the mouth plane. While the gate is closed no ball can be in the net, so
## the veil's mask stops at the pole's inner face (only the strip the pole covers changes); restored when the gate hides.
func _mask_front_veil() -> void:
	var art: Node = _zone.get_node_or_null("NetArt")
	if art == null:
		return
	var vm: ShaderMaterial = art.get("_front_mat") as ShaderMaterial
	if vm == null:
		return
	var iv: Variant = vm.get_shader_parameter("interior")
	if not (iv is Vector4):
		return
	_veil_mat = vm
	_veil_interior = iv
	var cut: float = Tuning.sports_gate_bar_w * 0.5 + 2.0
	var v: Vector4 = _veil_interior
	if _md > 0.0:
		v.z = maxf(0.0, v.z - cut)               # mouth on the right edge of the interior
	else:
		v = Vector4(v.x + cut, v.y, maxf(0.0, v.z - cut), v.w)
	_veil_mat.set_shader_parameter("interior", v)

func _restore_front_veil() -> void:
	if _veil_mat != null:
		_veil_mat.set_shader_parameter("interior", _veil_interior)
		_veil_mat = null

func _make_socket(cap: Sprite2D, knob_src: Vector2, frame: Node2D) -> Node2D:
	var pivot := Node2D.new()
	pivot.name = "Socket"
	add_child(pivot)   # last child -> drawn over the pole, ring and badge
	pivot.global_position = cap.global_transform * knob_src
	pivot.modulate = frame.modulate
	var sp: Sprite2D = cap.duplicate() as Sprite2D
	var r: Rect2 = cap.region_rect
	var crop: float = clampf(SOCKET_CROP_X - r.position.x, 0.0, r.size.x - 1.0)
	sp.region_rect = Rect2(r.position.x + crop, r.position.y, r.size.x - crop, r.size.y)
	sp.material = cap.material
	pivot.add_child(sp)
	sp.global_transform = cap.global_transform.translated_local(Vector2(crop, 0.0))
	return pivot

# ------------------------------------------------------------------ rule API (SportsMode)

## GO: run the gate on `ball`'s live clock; the collider drops at `open_s`.
func start(ball: Node, open_s: float) -> void:
	_ball = ball
	_started = true
	_T = maxf(0.0, open_s)
	_retract_s = Tuning.sports_gate_retract_s
	_retract_start = _T - _retract_s - RETRACT_LEAD

## LIVE BALL (rule 2): open NOW (no warning; 0.08 s visual retract after the collider has already dropped).
func open_now() -> void:
	if _opened or not _started:
		return
	var t: float = _clock()
	_event_open = true
	_T = t
	_retract_start = t
	_retract_s = RETRACT_EVENT_S
	_open()

func is_open() -> bool:
	return _opened

## Ball clock of the open (INF while closed), and the scheduled open while closed.
func open_time() -> float:
	return _open_t if _opened else _T

func scheduled_open() -> float:
	return _T if _started else INF

func spit_fired() -> bool:
	return _spit

func _clock() -> float:
	if _started and _ball != null and is_instance_valid(_ball):
		return float(_ball.call("ball_clock"))
	return 0.0

func _physics_process(_delta: float) -> void:
	if _started and not _opened and _clock() >= _T:
		_open()

## The open, on the exact physics tick the ball clock reaches T: collider off, zone un-gated, spit, cue.
func _open() -> void:
	_opened = true
	_open_t = _clock()
	_body.collision_layer = 0
	_shape.set_deferred("disabled", true)
	if _zone != null and is_instance_valid(_zone) and _zone.has_method("set_gated"):
		_zone.call("set_gated", false)
	_try_spit()
	if lead:
		EventBus.kickoff_gates_open.emit()
	_open_call()   # WK-155 (a)
	opened.emit(_spit)

## WK-155 (a): the open call. Each gate pops OPEN! (with the OPEN padlock glyph) court-side of its mouth at full alpha on
## EVERY kickoff, on the whistle's tick. The stage-1 legend sticker had faded to ~25 % by then and later kickoffs had no
## word at all. Same pop family as the hit's NOT YET! (KickoffGatePop), bigger and held longer.
func _open_call() -> void:
	if _open_popped or _horizontal_mouth or not Tuning.sports_gate_open_call:
		return
	_open_popped = true
	var host: Node = get_parent()
	if host == null:
		return
	# A world-space CanvasLayer (follow_viewport: same camera transform as the court) ABOVE the identity-tag layer, so a
	# keeper's name tag in the mouth can't cover the call (the tags are screen space and drew over the world pop).
	var layer := CanvasLayer.new()
	layer.name = "OpenCallLayer"
	layer.layer = Tuning.sports_gate_open_call_layer
	layer.follow_viewport_enabled = true
	host.add_child(layer)
	var pop: Node2D = POP_SCENE.instantiate() as Node2D
	layer.add_child(pop)
	pop.tree_exited.connect(layer.queue_free)
	var at := Vector2(global_position.x + _md * (Tuning.sports_gate_bar_w * 0.5 + 24.0),
		global_position.y + _h * Tuning.sports_gate_open_call_y)
	pop.call("present", at, _md, OPEN_TEXT_VALUE, BADGE_OPEN, Tuning.sports_gate_open_call_wpx, Tuning.sports_gate_open_call_life)
	open_pops += 1

## Spec §4.3: a ball whose surface is within sports_gate_spit_reach of the gate face (court side, inside the mouth
## span) gets sports_gate_spit_speed outward along the mouth normal. Not a touch: no touch log, no credit.
func _try_spit() -> void:
	if _horizontal_mouth or _ball == null or not is_instance_valid(_ball):
		return
	var b: RigidBody2D = _ball as RigidBody2D
	if b == null:
		return
	var rel: Vector2 = b.global_position - global_position
	var br: float = float(b.get("radius")) if b.get("radius") != null else Ball.BALL_RADIUS
	var along: float = rel.x * _md
	var gap: float = along - Tuning.sports_gate_thickness * 0.5 - br
	if along <= 0.0 or gap > Tuning.sports_gate_spit_reach or absf(rel.y) > _h * 0.5 + br * 0.5:
		return
	b.linear_velocity += Vector2(_md * Tuning.sports_gate_spit_speed, 0.0)
	_spit = true
	var face: Vector2 = Vector2(global_position.x + _md * Tuning.sports_gate_bar_w * 0.5, b.global_position.y)
	_fx_sprite(BLAST_RING_TEX, face, 50.0, 0.15, Vector2.ZERO, 0.6, 1.25, 1.0)

## Ball contact feed (Ball._wk66a_net_contacts via the body's "net_fx" meta, deferred). speed = pre-bounce speed.
func on_ball_contact(world_pos: Vector2, speed: float) -> void:
	if _opened or _horizontal_mouth or speed < Tuning.sports_gate_fx_min_speed:
		return
	hits += 1
	hit_speeds.append(snappedf(speed, 1.0))
	hit.emit(speed)
	EventBus.kickoff_gate_hit.emit(team, speed)
	var ly: float = clampf(to_local(world_pos).y, -_h * 0.5, _h * 0.5)
	_hit_y = ly
	_hit_amp = -_md * clampf(speed / 2000.0, 0.25, 1.0) * Tuning.sports_gate_flex_amp   # bows AWAY from the ball
	_hit_age = 0.0
	_flash_age = 0.0
	var face: Vector2 = Vector2(global_position.x + _md * Tuning.sports_gate_bar_w * 0.5, global_position.y + ly)
	_fx_sprite(STAR_TEX, face, 36.0, 0.18, Vector2.ZERO, 0.7, 1.15, 1.0)
	if _pop_cd <= 0.0:
		_pop_cd = Tuning.sports_gate_pop_cooldown
		var pop: Node2D = POP_SCENE.instantiate() as Node2D
		var host: Node = get_parent()
		if host != null:
			host.add_child(pop)
			pop.call("present", Vector2(face.x + _md * 70.0, face.y - 90.0), _md, POP_TEXT_VALUE)

# ------------------------------------------------------------------ presentation

func _process(delta: float) -> void:
	_age += delta
	_pop_cd = maxf(0.0, _pop_cd - delta)
	if _hit_age >= 0.0:
		_hit_age += delta
		if _hit_age >= Tuning.sports_gate_flex_time:
			_hit_age = -1.0
	if _flash_age >= 0.0:
		_flash_age += delta
		if _flash_age >= Tuning.sports_gate_flash_time + Tuning.sports_gate_flash_fade:
			_flash_age = -1.0
	if _horizontal_mouth or _hidden:
		return
	_apply_visuals(_clock())

## Warning phase of the swing: phi(tau) = f0 tau + (f1 - f0) tau^2 / (2 W) cycles since the warning began.
func _warn_phase(tau: float) -> float:
	var wdur: float = maxf(Tuning.sports_gate_warn_s, 0.001)
	return Tuning.sports_gate_warn_hz_from * tau + (Tuning.sports_gate_warn_hz_to - Tuning.sports_gate_warn_hz_from) * tau * tau / (2.0 * wdur)

func _apply_visuals(t: float) -> void:
	var T: float = _T
	var wdur: float = Tuning.sports_gate_warn_s
	var in_warn: bool = _started and not _event_open and t >= T - wdur and t < T
	var tau: float = clampf(t - (T - wdur), 0.0, wdur)
	var bright: float = 0.0
	var lift: float = 0.0
	var scroll: float = 0.0
	if in_warn:
		var ph: float = _warn_phase(tau)
		bright = WARN_WHITE * (0.5 - 0.5 * cos(TAU * ph))
		var peaks: int = int(floor(ph - 0.5)) + 1   # swing peaks passed (phase k + 0.5)
		while _tick_n < peaks:
			if lead:
				EventBus.kickoff_gate_tick.emit(_tick_n)
			_tick_n += 1
			_shake = Vector2.from_angle(randf() * TAU) * Tuning.sports_gate_warn_shake
		lift = Tuning.sports_gate_warn_lift * clampf(tau / WARN_LIFT_T, 0.0, 1.0)
		scroll = Tuning.sports_gate_scroll_max * tau * tau / (2.0 * maxf(wdur, 0.001))
	elif _started and not _event_open and t >= T:
		lift = Tuning.sports_gate_warn_lift
		scroll = Tuning.sports_gate_scroll_max * wdur * 0.5 + Tuning.sports_gate_scroll_max * (t - T)

	# --- pole offset (drop-in / warning lift + tremble / retract) ---
	var off: float = 0.0
	var gone: float = -(_h + 20.0 + RETRACT_EXTRA)
	var dropping: bool = false
	if Tuning.sports_gate_drop_in and not _started:
		var da: float = _age - DROP_DELAY
		var dt: float = maxf(Tuning.sports_gate_drop_time, 0.001)
		if da < 0.0:
			off = gone
			dropping = true
		elif da < dt:
			var u: float = da / dt
			off = gone * (1.0 - u) * (1.0 - u)   # ease-out
			_drop_cue()
		elif da < dt + DROP_REBOUND_T:
			off = -DROP_REBOUND * sin(PI * (da - dt) / DROP_REBOUND_T)
			_drop_cue()
		else:
			_drop_cue()
	if in_warn:
		off = -lift + WARN_TREMBLE * sin(TAU * WARN_TREMBLE_HZ * tau) * clampf(tau / WARN_LIFT_T, 0.0, 1.0)
	var rs: float = _retract_start
	if _started and t >= rs:
		var rdur: float = _retract_s if _event_open else (T - rs)   # rule 1: ends exactly at T; rule 2 event: 0.08 s after
		var u2: float = clampf((t - rs) / maxf(rdur, 0.001), 0.0, 1.0)
		off = -lift - (_h + RETRACT_EXTRA) * u2 * u2 * u2   # ease-in cubic: accelerates and snaps home
	_pole.position = Vector2(0.0, off)

	# --- flex + flash ---
	var bow: float = 0.0
	if _hit_age >= 0.0:
		var half_t: float = FLEX_HALF * Tuning.sports_gate_flex_time / 0.25
		bow = _hit_amp * sin(PI * _hit_age / maxf(half_t, 0.001)) * exp(-FLEX_DECAY * _hit_age)
	_pole_mat.set_shader_parameter("flex", Vector4(_hit_y, bow, Tuning.sports_gate_flex_sigma, 0.0))
	var flash: float = 0.0
	if _flash_age >= 0.0:
		flash = 1.0 if _flash_age < Tuning.sports_gate_flash_time \
			else 1.0 - clampf((_flash_age - Tuning.sports_gate_flash_time) / maxf(Tuning.sports_gate_flash_fade, 0.001), 0.0, 1.0)
	_pole_mat.set_shader_parameter("flash", flash)
	_pole_mat.set_shader_parameter("scroll", scroll)

	# --- badge ---
	var badge_s: float = Tuning.sports_gate_badge_wpx / float(BADGE_LOCKED.get_width())
	var bscale: float = 1.0
	var bpos: Vector2 = Vector2.ZERO
	var balpha: float = 1.0
	if Tuning.sports_gate_drop_in and not _started:
		var ba: float = _age - DROP_DELAY
		if ba < 0.0:
			balpha = 0.0
		else:
			bscale = lerpf(0.6, 1.0, _ease_out_back(clampf(ba / BADGE_IN_T, 0.0, 1.0)))
	if in_warn and t < rs:
		bpos = _shake
	if _started and t >= rs:
		var to: float = t - rs
		_badge.texture = BADGE_OPEN
		if not _burst_done:
			_burst_done = true
			_open_burst()
		if to < BADGE_POP_T:
			bscale = lerpf(1.0, BADGE_POP_SCALE, to / BADGE_POP_T)
		else:
			var v: float = clampf((to - BADGE_POP_T) / maxf((T + 0.1 - rs) - BADGE_POP_T, 0.001), 0.0, 1.0)
			bscale = BADGE_POP_SCALE
			bpos = Vector2(0.0, -BADGE_FLY * (1.0 - (1.0 - v) * (1.0 - v)))
			balpha = 1.0 - v
	_badge.scale = Vector2.ONE * badge_s * bscale
	_badge.position = Vector2(0.0, _badge_y) + bpos   # WK-155 (b)
	_badge.modulate.a = balpha
	# WK-131 blind-read follow-up: the full 0.06 s white turned the padlock white-on-white for 2-3 frames (it ghosted out).
	# The hit flash is the POLE's; the badge takes only Tuning.sports_gate_badge_flash of it (0 = none). The warning swing
	# (`bright`) is unchanged.  # WK-131
	_badge_mat.set_shader_parameter("white", maxf(bright, flash * Tuning.sports_gate_badge_flash))   # WK-131

	# --- ring (full + static pre-GO, drains clockwise from 12 o'clock over [0, T], gone at the retract) ---
	_ring.visible = not dropping and not (_started and t >= rs)
	_ring.set_meta("frac", 1.0 - clampf(t / maxf(T, 0.001), 0.0, 1.0) if _started else 1.0)
	_ring.set_meta("bright", bright)
	_ring.queue_redraw()

	# --- socket thunk at the open, then stop drawing ---
	if _opened and _socket_top != null:
		var tt: float = t - _open_t
		if not _thunk_done:
			_thunk_done = true
			# out of the cap toward the court: straight up it rose over the white wall pillar and vanished (WK-93 check)
			_fx_sprite(PUFF_TEX, _socket_top.global_position, 60.0, 0.3, Vector2(_md * 36.0, -22.0), 0.6, 1.5, 0.5)
		var k: float = 1.0 + (THUNK_SCALE - 1.0) * sin(PI * clampf(tt / THUNK_T, 0.0, 1.0))
		_socket_top.scale = Vector2(k, k)
	if _opened and t - _open_t >= HIDE_AFTER:
		_hidden = true
		visible = false
		_restore_front_veil()   # the goal is pixel-identical to WK-66a again; the next kickoff reload brings a fresh gate

func _drop_cue() -> void:
	if _dropped_cue:
		return
	_dropped_cue = true
	if lead:
		EventBus.kickoff_gate_dropped.emit()

## WK-154: the ring drawing moved to DrainRing.gd (one look for the gate and the Brawl spawn padlock); same numbers.
func _draw_ring() -> void:
	var frac: float = float(_ring.get_meta("frac", 1.0))
	var bright: float = float(_ring.get_meta("bright", 0.0))
	DRAIN_RING.draw(_ring, Vector2.ZERO, Tuning.sports_gate_ring_r, Tuning.sports_gate_ring_band, RING_OUTLINE, frac, bright)

## Badge burst at the retract start (brief §6.5): one ko_blast_star (70 wpx) + 5 star_sparkles thrown outward, cream.
func _open_burst() -> void:
	var at: Vector2 = global_position + Vector2(0.0, _badge_y)   # WK-155 (b): from where the badge is
	_fx_sprite(BLAST_STAR_TEX, at, 70.0, 0.3, Vector2.ZERO, 0.5, 1.3, 1.0)
	for i in range(5):
		var dir: Vector2 = Vector2.from_angle(-PI * 0.5 + (float(i) - 2.0) * 0.75 + randf_range(-0.2, 0.2))
		_fx_sprite(STAR_TEX, at + dir * 20.0, 28.0, 0.3, dir * 90.0, 1.0, 0.6, 1.0)

## One-shot cream FX sprite in WORLD space on the level (outlives the gate's hide): `wpx` across, scale s0 -> s1,
## drifting by `travel`, fading out over `life`. z Z_FX (over goats, under the ball).
func _fx_sprite(tex: Texture2D, at: Vector2, wpx: float, life: float, travel: Vector2, s0: float, s1: float, a0: float) -> void:
	var host: Node = get_parent()
	if host == null or tex == null:
		return
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.material = _fx_mat
	sp.self_modulate = CREAM
	sp.modulate = Color(1.0, 1.0, 1.0, a0)
	sp.z_as_relative = false
	sp.z_index = Z_FX
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	host.add_child(sp)
	sp.global_position = at
	var base: float = wpx / maxf(float(maxi(tex.get_width(), tex.get_height())), 1.0)
	sp.scale = Vector2.ONE * base * s0
	var tw := sp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sp, "scale", Vector2.ONE * base * s1, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "global_position", at + travel, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "modulate:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(sp.queue_free)

static func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
