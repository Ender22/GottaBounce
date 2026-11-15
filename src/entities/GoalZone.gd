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

func _ready() -> void:
	add_to_group("goal_zone")
	collision_layer = 0
	collision_mask = MASK_BALL
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	add_child(cs)
	z_index = 44   # over platforms/void, under HUD
	if not EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.connect(_on_combat_started)
	if not EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.connect(_on_combat_ended)
	_build_net_art()   # WK-66a

## WK-66a: the Rocketball cage (side-view goal mounted in the wall gap). Only left/right mouths get art; a
## hidden concede strip (DROPSHOT floor) or an up/down mouth draws nothing. Opt-in: the zone needs net_mouth_x
## and/or net_back_x. A missing one defaults (mouth plane 20 px inside the zone's mouth-side edge; net depth
## Tuning.goal_net_depth_default).
func _build_net_art() -> void:   # WK-66a
	if style == "hidden" or (is_nan(net_mouth_x) and is_nan(net_back_x)):
		return   # no net data -> legacy draw (TRIALS goals)
	var md: float = _mouth_dir().x
	if absf(md) < 0.5:
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

func _on_combat_started() -> void:
	_live = true

func _on_combat_ended() -> void:
	_live = false

func _physics_process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.5)
	# TRUE-ENTRY poll (owner item 4): latch only when a ball's CENTRE is inside the net interior.
	if not scored and _live:
		for b in get_tree().get_nodes_in_group("sports_ball"):
			if not is_instance_valid(b):
				continue
			var rel: Vector2 = (b as Node2D).global_position - global_position
			if absf(rel.x) <= w * 0.5 and absf(rel.y) <= h * 0.5:
				scored = true
				_flash = 1.0
				_score_burst((b as Node2D).global_position)
				break
	queue_redraw()

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
		var c0: Color = scoring_col if layer == 0 else GOLD
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
# WK-66a: a goal_zone with net data (net_mouth_x / net_back_x: the Rocketball courts) draws the SportsNetArt
# cage instead (child "NetArt"; score reaction = its bulge + white frame flash off the `scored` latch). Goals
# WITHOUT net data (the TRIALS s3_/t_ courses: free-standing, up to 700x620, mouth not against a wall) keep
# this legacy draw unchanged until they get their own cage layout (out of WK-66a scope).
func _draw() -> void:
	if style == "hidden" or _net_art != null:   # WK-66a
		return   # DROPSHOT concede strip: invisible (the broken floor tile is the visible mouth)
	var col := _team_color()
	var dark := Color(0.10, 0.08, 0.07, 0.95)
	var pulse := 1.0 + 0.05 * sin(_t * 3.5)
	var hw := w * 0.5 * pulse
	var hh := h * 0.5
	var rect := Rect2(Vector2(-hw, -hh), Vector2(2.0 * hw, 2.0 * hh))
	# scored: bright green flood behind the net
	if scored:
		var glow: float = 0.35 + 0.35 * _flash
		draw_rect(rect.grow(28.0), Color(0.30, 0.95, 0.50, glow), true)
	# faint team-colored fill so the mouth reads as a goal at pitch zoom
	draw_rect(rect, Color(col.r, col.g, col.b, 0.16), true)
	# dark backing frame then a bright team-colored rim
	draw_rect(rect, dark, false, 14.0)
	draw_rect(rect, col, false, 8.0)
	# a simple net grid (readable "goal")
	var net := Color(col.r, col.g, col.b, 0.45)
	var cols := 4
	for i in range(1, cols):
		var x := -hw + 2.0 * hw * float(i) / float(cols)
		draw_line(Vector2(x, -hh), Vector2(x, hh), net, 3.0)
	var rows := 6
	for j in range(1, rows):
		var y := -hh + 2.0 * hh * float(j) / float(rows)
		draw_line(Vector2(-hw, y), Vector2(hw, y), net, 3.0)
