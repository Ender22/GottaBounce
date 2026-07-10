class_name GoalGate
extends Area2D
## TRIALS goal trigger (docs/specs/v3_content_plan.md PART B.3; v10 completion model). An Area2D on the
## players mask that senses each player reaching the course goal. v10: instead of a single shared
## `reached` latch (which ended the stage on the FIRST player), the gate records the STICKY SET of the
## distinct Player bodies that have entered — `home` keyed by instance id, never cleared. TrialsMode's
## REACH_GOAL gate is now "EVERY living participant has entered SOME goal_gate" (all-must-finish), read
## via has_player(); the derived `reached` (= ≥1 player home) is kept ONLY for the green "reached" visual.
##
## Display-only ring (Pillar 5 readability): one high-contrast pulsing gold/green ring at course zoom.
## No collider on the world (it never blocks the player); it only detects. No Tuning constant is read.

const MASK_PLAYERS := 1 << 0   # senses Player bodies (Player collision_layer includes bit 0), like MovingHazard

var w: float = 240.0
var h: float = 320.0
var home: Dictionary = {}       # instance_id -> Player, STICKY (never cleared): the set that has entered
var reached: bool = false       # DERIVED: not home.is_empty() — drives the green glow only, gates nothing
var _t: float = 0.0
var _flash: float = 0.0

## True once player p has entered this gate (sticky). The mode ANDs this across all participants.
func has_player(p) -> bool:
	return p != null and home.has(p.get_instance_id())

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

## Latch by OVERLAP POLL, only while the match is in COMBAT — never via body_entered. A body_entered
## latch recorded STALE pre-combat positions: during the runner's stage-load -> respawn window the
## previous course's finishers still sit at their OLD world coords, which can overlap THIS course's
## fresh gate (observed live: campaign course_03's goal lies inside course_04's gate rect, so
## course_04 auto-cleared the instant combat began). Polling during COMBAT also latches a player who
## is already inside the gate when combat starts (body_entered would never re-fire for them).
func _poll_home() -> void:
	var runner := get_tree().current_scene
	if runner == null or str(runner.get("state")) != "COMBAT":
		return
	for body in get_overlapping_bodies():
		# The physics server's overlap list is ONE STEP STALE after a teleport (observed live: a dead
		# body inside the gate latched on its respawn frame — is_dead() already false, overlap list
		# still showing the corpse's old position). Require the CURRENT position to be inside the gate
		# rect too: "entered the gate" = your center is in the ring, alive, during combat.
		if body is Player and not body.is_dead() and _inside(body.global_position):
			var id := body.get_instance_id()
			if not home.has(id):
				home[id] = body   # sticky: a player that later falls & respawns STAYS home (v10 §1.2)
				_flash = 1.0
			reached = true        # derived ≥1-home flag for the green glow (never gates the stage now)

func _inside(p: Vector2) -> bool:
	var d := p - global_position
	return absf(d.x) <= w * 0.5 and absf(d.y) <= h * 0.5

func _physics_process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.5)
	_poll_home()
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
