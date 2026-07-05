class_name GoalGate
extends Area2D
## TRIALS goal trigger (docs/specs/v3_content_plan.md PART B.3). An Area2D on the players mask that
## senses the human reaching the course goal; the FIRST overlap latches `reached` and (via group
## "goal_gate") lets TrialsMode.is_stage_over() end the stage on goal-touch — NOT last-one-standing.
##
## Display-only ring (Pillar 5 readability): one high-contrast pulsing gold/green ring at course zoom.
## No collider on the world (it never blocks the player); it only detects. No Tuning constant is read.

const MASK_PLAYERS := 1 << 0   # senses Player bodies (Player collision_layer includes bit 0), like MovingHazard

var w: float = 240.0
var h: float = 320.0
var reached: bool = false
var _t: float = 0.0
var _flash: float = 0.0

func setup_from_json(o: Dictionary) -> void:
	# x,y = CENTER of the gate (spec B.3 goal_gate {x,y,w,h}); w,h = the rectangular trigger size.
	w = float(o.get("w", 240.0))
	h = float(o.get("h", 320.0))
	position = Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))

func _ready() -> void:
	add_to_group("goal_gate")
	collision_layer = 0
	collision_mask = MASK_PLAYERS
	monitoring = true
	set_meta("goal_gate", true)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	add_child(cs)
	z_index = 45   # over platforms/void, under HUD
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if reached:
		return
	if body is Player:
		reached = true
		_flash = 1.0

func _physics_process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.5)
	queue_redraw()

# ------------------------------------------------------------------ telegraphy (display only)
func _draw() -> void:
	var pulse := 1.0 + 0.06 * sin(_t * 4.0)
	var r := minf(w, h) * 0.40 * pulse
	var gold := Color(1.0, 0.82, 0.25, 0.95)
	var green := Color(0.30, 0.95, 0.50, 0.9)
	var dark := Color(0.12, 0.09, 0.07, 0.92)
	if reached:
		gold = green
		var glow: float = 0.35 + 0.3 * _flash
		draw_circle(Vector2.ZERO, r + 26.0, Color(0.3, 0.95, 0.5, glow))
	# faint filled disc so the goal reads as a "portal" even at wide course zoom
	draw_circle(Vector2.ZERO, r, Color(gold.r, gold.g, gold.b, 0.14))
	# dark backing ring (contrast on any sky) then the bright fuse ring
	draw_arc(Vector2.ZERO, r + 9.0, 0.0, TAU, 72, dark, 24.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, gold, 14.0, true)
	draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 72, green, 8.0, true)
	# a downward chevron in the ring center pointing to the landing pad (readable "here")
	var ch := r * 0.34
	var pts := PackedVector2Array([Vector2(-ch, -ch * 0.4), Vector2(0, ch * 0.6), Vector2(ch, -ch * 0.4)])
	draw_polyline(pts, gold, 8.0, true)
