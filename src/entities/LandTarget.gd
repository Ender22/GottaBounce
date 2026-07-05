class_name LandTarget
extends Area2D
## TRIALS PRECISION_LAND pad (docs/specs/v7_trials_challenge_types.md §1.3). A GoalGate-latch clone with
## ONE extra gate: it latches `landed` only if the overlapping player arrives SLOWER than `land_speed_max`
## (a soft-landing check) — a too-fast touch does NOT latch (you must re-approach; that is the skill, not
## a death). Read via the group "trials_target"; TrialsMode.is_stage_over clears the course when every
## member is landed. Reads no Tuning constant. Drawn as a small bullseye pad that turns green when landed.
##
## {"type":"land_target","x","y","w","h","land_speed_max":<px/s>} — x,y = CENTER.

const MASK_PLAYERS := 1 << 0

var w: float = 120.0
var h: float = 40.0
var land_speed_max: float = 260.0
var landed: bool = false
var _t: float = 0.0
var _flash: float = 0.0
var _too_fast_flash: float = 0.0

func setup_from_json(o: Dictionary) -> void:
	w = float(o.get("w", 120.0))
	h = float(o.get("h", 40.0))
	land_speed_max = maxf(1.0, float(o.get("land_speed_max", 260.0)))
	position = Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))

func _ready() -> void:
	add_to_group("trials_target")
	collision_layer = 0
	collision_mask = MASK_PLAYERS
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	add_child(cs)
	z_index = 44
	body_entered.connect(_on_body_entered)

## Latch only on a SOFT landing: the overlapping player's speed must be under land_speed_max. A too-fast
## touch flashes a red reject and leaves the pad un-latched (re-approach slower).
func _on_body_entered(body: Node) -> void:
	if landed or not (body is Player):
		return
	var spd: float = 0.0
	if "velocity" in body:
		spd = (body.velocity as Vector2).length()
	if spd <= land_speed_max:
		landed = true
		_flash = 1.0
	else:
		_too_fast_flash = 1.0

func _physics_process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.5)
	if _too_fast_flash > 0.0:
		_too_fast_flash = maxf(0.0, _too_fast_flash - delta * 2.5)
	queue_redraw()

# ------------------------------------------------------------------ display (bullseye pad)
func _draw() -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	var rect := Rect2(Vector2(-hw, -hh), Vector2(w, h))
	var base := Color(0.85, 0.72, 0.30) if not landed else Color(0.30, 0.90, 0.50)
	var pulse := 1.0 + 0.05 * sin(_t * 4.0)
	if landed:
		draw_rect(rect.grow(10.0), Color(0.30, 0.95, 0.50, 0.30 + 0.30 * _flash), true)
	elif _too_fast_flash > 0.0:
		draw_rect(rect.grow(10.0), Color(0.95, 0.25, 0.25, 0.45 * _too_fast_flash), true)
	draw_rect(rect, Color(0.12, 0.09, 0.07, 0.92), true)
	draw_rect(Rect2(Vector2(-hw * pulse, -hh), Vector2(w * pulse, h)), Color(base.r, base.g, base.b, 0.9), false, 6.0)
	# center bullseye dot + crosshair (a "land HERE" read)
	draw_circle(Vector2.ZERO, hh * 0.5, base)
	draw_line(Vector2(-hw * 0.7, 0), Vector2(hw * 0.7, 0), Color(base.r, base.g, base.b, 0.5), 3.0)
