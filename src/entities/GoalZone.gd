class_name GoalZone
extends Area2D
## SPORTS goal trigger (docs/specs/v5_sports_mode.md §3 + owner list 2026-07-18 item 4). Mirrors
## GoalGate (the TRIALS trigger): latches on a ball entry and is read via a group. Differences:
## it senses the BALL, it is TEAM-TAGGED, and it draws a team-colored goal mouth / net.
##
## DETECTION (owner item 4): a goal requires the ball to be TRULY INSIDE the net — the BALL'S
## CENTRE must be inside the zone rect (past the goal-mouth plane), not merely a ball edge clipping
## a corner of the trigger. Implemented as a per-frame CENTRE-IN-RECT poll over group "sports_ball"
## (the stale-latch doctrine: no body_entered latch that can fire from stage-load overlap sweeps),
## gated to live combat via EventBus.combat_started/ended.
##
## SCORE EXPLOSION (owner item 4): on the latch, a one-shot burst of team-colored + gold star
## confetti (CPUParticles2D, additive — the PartyMatch._spawn_star_burst look) fires OUT of the net
## mouth from the ball's entry point.
##
## {"type":"goal_zone","x","y","w","h","team":<int>[,"mouth":"left|right|up|down"][,"style":"hidden"]}
## x,y = CENTER, w,h = the net-interior trigger rect. `team` = the DEFENDING team (whose goal this
## is), so a ball entering it scores for the OTHER team. `mouth` = which way the goal mouth faces
## (burst direction; default derived from team: 0 defends LEFT -> mouth faces right, 1 -> left).
## `style: "hidden"` skips the drawn net (DROPSHOT's under-floor concede strips are invisible — the
## broken floor tile IS the visible mouth there).

const MASK_BALL := 1 << 6   # senses ONLY the Ball layer (Ball.LAYER_BALL) — kept for tool overlays

# team colorways (readability, Pillar 5): warm = team 0 (RED), cool = team 1 (BLUE)
const TEAM_COLORS := [Color("#ff4b6a"), Color("#3fa9ff")]
const GOLD := Color(1.0, 0.85, 0.3)

var w: float = 200.0
var h: float = 320.0
var team: int = 0
var mouth: String = ""      # "left"|"right"|"up"|"down"; "" -> derived from team
var style: String = ""      # "" = drawn goal; "hidden" = invisible concede strip (DROPSHOT floor)
var scored: bool = false
var _t: float = 0.0
var _flash: float = 0.0
var _live: bool = false     # combat gate: latch only during live play (stale-latch doctrine)
# WK-66a net art (docs/briefs/sports_nets_2026-11-15.md 3b): with net data the drawn cage replaces the old _draw.
# net_mouth_x = world x of the court-side wall face (mouth plane), net_back_x = world x of the back post's
# inner face. Display only; the trigger rect above stays w x h.  # WK-66a
const NET_ART := preload("res://src/systems/SportsNetArt.gd")   # WK-66a
var net_mouth_x: float = NAN   # WK-66a
var net_back_x: float = NAN    # WK-66a
var _net_art: Node2D = null    # WK-66a
# WK-66b (docs/briefs/trials_goal_2026-11-15.md): TRIALS ball goals draw the gold cage. Optional display-only top /
# bottom tube lines (the snapped roof / crossbar face, or floor top - sink); the trigger rect never changes.  # WK-66b
var net_top_y: float = NAN     # WK-66b
var net_bottom_y: float = NAN  # WK-66b
# WK-131 kickoff gates (docs/specs/wk131_kickoff_rule_2026-11-15.md §4.3 / §5.3): while a KickoffGate covers this mouth the
# zone does not latch (the backup behind the collider; reuses the _live stale-latch gate). scored_ball_t = the ball's live clock
# (Ball.ball_clock()) at the latch, the primary kickoff-goal clock for QA. Both inert when no gate exists.  # WK-131
var _gated: bool = false       # WK-131
var scored_ball_t: float = -1.0   # WK-131
# WK-116 PRESSURE NETS (docs/specs/wk116_long_rally_2026-11-15.md §4.1 / §7): PressureNets grows the rect vertically with the
# retracting posts (x-extent unchanged). Defence in depth: a ball whose centre is inside the rect only BECAUSE the rect grew
# (outside before, inside after, same tick) must leave and re-enter before it can latch (pressure_instant_goals counts these;
# must stay 0 by geometry: the new strip was solid post). All inert until set_mouth_span() is called.  # WK-116
var _shape_rect: RectangleShape2D = null   # WK-116
var _fresh_block: Array = []               # WK-116: balls that must leave the rect before they can latch
var pressure_instant_goals: int = 0        # WK-116 (QA)
# WK-159 (CD4-08): a TRIALS cage is display-only (no roof / floor colliders), so a fast ball latched SOLVED! and then
# ricocheted off the back wall straight back out over the cage top. On the latch a `style: "trials"` zone CATCHES the
# ball: speed cut to Tuning.trials_net_catch_keep, gravity off, then a damped spring toward the cage centre for
# Tuning.trials_net_catch_s. Sports zones (any other style) never run this, so the sports latch is unchanged.  # WK-159
var _catch_ball: RigidBody2D = null   # WK-159
var _catch_t: float = 0.0             # WK-159: s of catch left
var _catch_grav: float = 1.0          # WK-159: the ball's gravity_mult before the catch (restored after)

func setup_from_json(o: Dictionary) -> void:
	w = float(o.get("w", 200.0))
	h = float(o.get("h", 320.0))
	team = int(o.get("team", 0))
	mouth = str(o.get("mouth", ""))
	style = str(o.get("style", ""))
	position = Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))
	if o.has("net_mouth_x"):   # WK-66a
		net_mouth_x = float(o["net_mouth_x"])   # WK-66a
	if o.has("net_back_x"):   # WK-66a
		net_back_x = float(o["net_back_x"])   # WK-66a
	if o.has("net_top_y"):   # WK-66b
		net_top_y = float(o["net_top_y"])   # WK-66b
	if o.has("net_bottom_y"):   # WK-66b
		net_bottom_y = float(o["net_bottom_y"])   # WK-66b

func _ready() -> void:
	add_to_group("goal_zone")
	collision_layer = 0
	collision_mask = MASK_BALL
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	_shape_rect = rect   # WK-116
	add_child(cs)
	z_index = 44   # over platforms/void, under HUD
	if not EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.connect(_on_combat_started)
	if not EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.connect(_on_combat_ended)
	_build_net_art()   # WK-66a

## WK-66a: the Rocketball cage (side-view goal mounted in the wall gap): a non-trials zone WITH net data
## (net_mouth_x and/or net_back_x; a missing one defaults: mouth plane 20 px inside the zone's mouth-side edge, net
## depth Tuning.goal_net_depth_default). WK-66b: `style: "trials"` OR any visible zone without net data gets the
## TRIALS gold cage at its display edges (default = the zone edges). A hidden concede strip draws nothing. There is no
## other draw path: the old rect / grid / pulse / green-flood _draw is deleted (unreachable by construction).
func _build_net_art() -> void:   # WK-66a
	if style == "hidden":
		return
	var md: float = _mouth_dir().x
	if absf(md) < 0.5:
		push_warning("GoalZone: up/down mouth has no cage art yet (WK-66b section 3a) - nothing drawn")
		return
	if style == "trials" or (is_nan(net_mouth_x) and is_nan(net_back_x)):   # WK-66b
		_build_trials_net_art(md)
		return
	var mx: float = net_mouth_x
	if is_nan(mx):
		mx = global_position.x + md * (w * 0.5 - 20.0)
	var bx: float = net_back_x
	if is_nan(bx):
		bx = mx - md * Tuning.goal_net_depth_default
	_net_art = NET_ART.new()
	_net_art.name = "NetArt"
	add_child(_net_art)
	_net_art.call("setup_goal", self, h, mx, bx, md, _team_color())

## WK-66b: the trials cage. Display edges default to the zone edges; a JSON net_back_x is a wall face the back tube
## tucks behind (the brief's snap rule, written by the level-designer, never auto-detected).
func _build_trials_net_art(md: float) -> void:   # WK-66b
	var gp: Vector2 = global_position
	var mx: float = net_mouth_x if not is_nan(net_mouth_x) else gp.x + md * w * 0.5
	var snapped: bool = not is_nan(net_back_x)
	var bx: float = net_back_x if snapped else gp.x - md * w * 0.5
	var ty: float = net_top_y if not is_nan(net_top_y) else gp.y - h * 0.5
	var by: float = net_bottom_y if not is_nan(net_bottom_y) else gp.y + h * 0.5
	_net_art = NET_ART.new()
	_net_art.name = "NetArt"
	add_child(_net_art)
	_net_art.call("setup_trials_goal", self, mx, bx, snapped, ty, by, md)

## WK-131: KickoffGate closes / opens the latch (true from the stage load until the gate opens).
func set_gated(on: bool) -> void:   # WK-131
	_gated = on   # WK-131

func is_gated() -> bool:   # WK-131
	return _gated   # WK-131

## WK-116: resize the trigger to the WORLD mouth span [top, bottom] (x unchanged) and resize the cage art with it. A ball that is
## inside only because the rect grew is fresh-entry blocked (see _fresh_block).
func set_mouth_span(top: float, bottom: float) -> void:   # WK-116
	var nh: float = maxf(1.0, bottom - top)
	var ny: float = (top + bottom) * 0.5
	if is_equal_approx(nh, h) and is_equal_approx(ny, global_position.y):
		return
	var old_pos: Vector2 = global_position
	var old_h: float = h
	for b in get_tree().get_nodes_in_group("sports_ball"):
		if not is_instance_valid(b) or _fresh_block.has(b):
			continue
		var bp: Vector2 = (b as Node2D).global_position
		var was_in: bool = absf(bp.x - old_pos.x) <= w * 0.5 and absf(bp.y - old_pos.y) <= old_h * 0.5
		var now_in: bool = absf(bp.x - old_pos.x) <= w * 0.5 and absf(bp.y - ny) <= nh * 0.5
		if now_in and not was_in:
			_fresh_block.append(b)
			pressure_instant_goals += 1
	h = nh
	global_position = Vector2(old_pos.x, ny)
	if _shape_rect != null:
		_shape_rect.size = Vector2(w, h)
	if _net_art != null and is_instance_valid(_net_art) and _net_art.has_method("resize_goal"):
		_net_art.call("resize_goal", h)

## WK-116: the trim overlay colour on the cage tubes (alpha = strength; 0 = none). No-op without Rocketball cage art.
func set_pressure_trim(col: Color) -> void:   # WK-116
	if _net_art != null and is_instance_valid(_net_art) and _net_art.has_method("set_trim"):
		_net_art.call("set_trim", col)

func _on_combat_started() -> void:
	_live = true

func _on_combat_ended() -> void:
	_live = false

func _physics_process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.5)
	# TRUE-ENTRY poll (owner item 4): latch only when a ball's CENTRE is inside the net interior.
	if not scored and _live and not _gated:   # WK-131: backup latch check (spec) - a closed gate's collider is the primary stop
		for b in get_tree().get_nodes_in_group("sports_ball"):
			if not is_instance_valid(b):
				continue
			var rel: Vector2 = (b as Node2D).global_position - global_position
			var inside: bool = absf(rel.x) <= w * 0.5 and absf(rel.y) <= h * 0.5
			if not _fresh_block.is_empty() and _fresh_block.has(b):   # WK-116: must leave, then enter again
				if not inside:
					_fresh_block.erase(b)
				continue
			if inside:
				scored = true
				if b.has_method("ball_clock"):   # WK-131
					scored_ball_t = float(b.call("ball_clock"))   # WK-131
				_flash = 1.0
				_score_burst((b as Node2D).global_position)
				if style == "trials" and Tuning.trials_net_catch and b is RigidBody2D:   # WK-159
					_start_catch(b as RigidBody2D)   # WK-159
				break
	if _catch_ball != null:   # WK-159
		_tick_catch(delta)   # WK-159
	queue_redraw()

## WK-159: begin the net catch on ball `b` (trials cages only; called once, at the latch).
func _start_catch(b: RigidBody2D) -> void:   # WK-159
	_catch_ball = b
	_catch_t = Tuning.trials_net_catch_s
	var gm: Variant = b.get("gravity_mult")
	_catch_grav = float(gm) if gm != null else 1.0
	if gm != null:
		b.set("gravity_mult", _catch_grav * Tuning.trials_net_catch_gravity)
	b.linear_velocity = b.linear_velocity * Tuning.trials_net_catch_keep

## WK-159: one physics tick of the catch. The net is a soft box = the zone rect shrunk by the ball radius: velocity decays
## at trials_net_catch_damp /s; a component carrying the ball out through a side flips inward at trials_net_catch_wall_keep
## (a dead net bounce), and a ball already past a side is eased back in at trials_net_catch_push /s. With the reduced gravity
## it sinks to the net's bottom (or the floor) and stays, instead of escaping the display-only cage. Velocity only, never
## a teleport (a RigidBody2D's position written from outside is overwritten by the next physics step).
func _tick_catch(delta: float) -> void:   # WK-159
	if not is_instance_valid(_catch_ball):
		_catch_ball = null
		return
	_catch_t -= delta
	if _catch_t <= 0.0:
		if _catch_ball.get("gravity_mult") != null:
			_catch_ball.set("gravity_mult", _catch_grav)
		_catch_ball = null
		return
	var rv: Variant = _catch_ball.get("radius")
	var r: float = minf(float(rv) if rv != null else 60.0, minf(w, h) * 0.5 - 1.0)
	var lo: Vector2 = global_position - Vector2(w, h) * 0.5 + Vector2(r, r)
	var hi: Vector2 = global_position + Vector2(w, h) * 0.5 - Vector2(r, r)
	var p: Vector2 = _catch_ball.global_position
	var v: Vector2 = _catch_ball.linear_velocity * exp(-Tuning.trials_net_catch_damp * delta)
	var keep: float = Tuning.trials_net_catch_wall_keep
	var push: float = Tuning.trials_net_catch_push
	if p.x < lo.x and v.x < (lo.x - p.x) * push:
		v.x = maxf(absf(v.x) * keep, (lo.x - p.x) * push)
	elif p.x > hi.x and v.x > (hi.x - p.x) * push:
		v.x = minf(-absf(v.x) * keep, (hi.x - p.x) * push)
	if p.y < lo.y and v.y < (lo.y - p.y) * push:
		v.y = maxf(absf(v.y) * keep, (lo.y - p.y) * push)
	elif p.y > hi.y and v.y > (hi.y - p.y) * push:
		v.y = minf(-absf(v.y) * keep, (hi.y - p.y) * push)
	_catch_ball.linear_velocity = v

func _team_color() -> Color:
	return TEAM_COLORS[team % TEAM_COLORS.size()]

## Which way the goal mouth faces (world direction the score burst shoots OUT along).
func _mouth_dir() -> Vector2:
	match mouth:
		"left":  return Vector2.LEFT
		"right": return Vector2.RIGHT
		"up":    return Vector2.UP
		"down":  return Vector2.DOWN
	# default: team 0 defends the LEFT goal (mouth faces court centre = right), team 1 mirrored.
	return Vector2.RIGHT if team == 0 else Vector2.LEFT

## SCORE EXPLOSION (owner item 4): confetti/star burst OUT of the net mouth. Two one-shot additive
## CPUParticles2D emitters at the ball's entry point — the SCORING team's color + a gold sparkle
## layer (the _spawn_star_burst grammar). Parented to our parent so it outlives a zone teardown.
func _score_burst(at: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var out := _mouth_dir()
	var scoring_col: Color = TEAM_COLORS[(1 - team) % TEAM_COLORS.size()]
	var sparkle_col: Color = GOLD
	if style == "trials":   # WK-66b: no teams in Trials -> objective gold + white (out of the explicit mouth)
		scoring_col = Tuning.trials_goal_color
		sparkle_col = Color.WHITE
	for layer in range(2):
		var p := CPUParticles2D.new()
		p.global_position = at
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 40 if layer == 0 else 28
		p.lifetime = 1.15
		p.direction = out
		p.spread = 52.0
		p.gravity = Vector2(0, 900)
		p.initial_velocity_min = 520.0
		p.initial_velocity_max = 1350.0
		p.damping_min = 60.0
		p.damping_max = 160.0
		p.scale_amount_min = 6.0 if layer == 0 else 4.0
		p.scale_amount_max = 12.0 if layer == 0 else 8.0
		var grad := Gradient.new()
		var c0: Color = scoring_col if layer == 0 else sparkle_col   # WK-66b (was GOLD)
		# white-hot birth so the additive burst punches through the HUD's team-color flash
		grad.add_point(0.25, Color(c0.r, c0.g, c0.b, 1.0))
		grad.set_color(0, Color(1.0, 1.0, 0.95, 1.0))
		grad.set_color(2, Color(GOLD.r, GOLD.g, GOLD.b, 0.0))
		p.color_ramp = grad
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = m
		p.z_index = 60
		host.add_child(p)
		host.get_tree().create_timer(1.6).timeout.connect(p.queue_free)

# ------------------------------------------------------------------ display (goal mouth / net)
# WK-66b: GoalZone draws nothing itself. Every visible goal is a SportsNetArt child ("NetArt"): the Rocketball cage
# (WK-66a) or the Trials gold cage (WK-66b). The legacy rect / line-grid / width-pulse / green-flood _draw was deleted.
