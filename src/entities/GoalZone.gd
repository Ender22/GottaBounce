class_name GoalZone
extends Area2D
## SPORTS goal trigger (docs/specs/v5_sports_mode.md §3). Mirrors GoalGate (the TRIALS trigger): a
## display-only Area2D that latches on overlap and is read via a group. Differences: it senses the
## BALL layer (not players), it is TEAM-TAGGED, and it draws a team-colored goal mouth / net.
##
## {"type":"goal_zone","x","y","w","h","team":<int>} — x,y = CENTER, w,h = the tall goal-mouth trigger.
## `team` = the DEFENDING team (whose goal this is), so a ball entering it scores for the OTHER team
## (soccer convention). SportsMode.is_stage_over scans group "goal_zone" for any latched `scored`.

const MASK_BALL := 1 << 6   # senses ONLY the Ball layer (Ball.LAYER_BALL)

# team colorways (readability, Pillar 5): warm = team 0 (RED), cool = team 1 (BLUE)
const TEAM_COLORS := [Color("#ff4b6a"), Color("#3fa9ff")]

var w: float = 200.0
var h: float = 320.0
var team: int = 0
var scored: bool = false
var _t: float = 0.0
var _flash: float = 0.0

func setup_from_json(o: Dictionary) -> void:
	w = float(o.get("w", 200.0))
	h = float(o.get("h", 320.0))
	team = int(o.get("team", 0))
	position = Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))

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
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if scored:
		return
	if body is Ball:
		scored = true
		_flash = 1.0

func _physics_process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.5)
	queue_redraw()

func _team_color() -> Color:
	return TEAM_COLORS[team % TEAM_COLORS.size()]

# ------------------------------------------------------------------ display (goal mouth / net)
func _draw() -> void:
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
