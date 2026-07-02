extends CanvasLayer
## Sudden-death edge visibility (lethality spec §6). Two full-height translucent laser-red
## columns on a CanvasLayer (scene: scenes/ui/SDWarning.tscn — two ColorRects, no shader):
##  - WARNING mode (from round_clock = sudden_death_time - sd_warning_lead): columns pulse at
##    2Hz (alpha 0.15 <-> 0.45) pinned to the screen's left/right edges — the pre-authorized
##    "3s warning flicker".
##  - TRACKER mode (SD live): each column clamps to the screen edge while its laser wall is
##    off-screen and snaps onto the wall's real x when it enters frame — players always know
##    where death is. Revive path: no lead pulse, trackers on.
## Freed (not halted) by the match mode on ROUND_END entry (spec §7).

const PULSE_HZ := 2.0
const ALPHA_LO := 0.15
const ALPHA_HI := 0.45
const COL_W := 24.0

var _tracking := false
var _lasers = null    # LaserWalls (duck-typed: left_x()/right_x())
var _t := 0.0

@onready var _root: Control = $Root
@onready var _left: ColorRect = $Root/LeftCol
@onready var _right: ColorRect = $Root/RightCol

func start_warning() -> void:
	_tracking = false
	_lasers = null

func start_tracking(lasers) -> void:
	_tracking = true
	_lasers = lasers

func _process(delta: float) -> void:
	_t += delta
	var a := lerpf(ALPHA_LO, ALPHA_HI, 0.5 + 0.5 * sin(_t * TAU * PULSE_HZ))
	var c: Color = _left.color
	c.a = a
	_left.color = c
	_right.color = c
	var vw: float = _root.size.x
	if _tracking and _lasers != null and is_instance_valid(_lasers):
		# world -> screen via the live camera canvas transform; clamp keeps the tracker pinned
		# to the edge until the wall enters frame, then it snaps onto the wall's real x
		var xf: Transform2D = get_viewport().get_canvas_transform()
		var lx: float = (xf * Vector2(_lasers.left_x(), 0.0)).x
		var rx: float = (xf * Vector2(_lasers.right_x(), 0.0)).x
		_left.position.x = clampf(lx - COL_W * 0.5, 0.0, vw - COL_W)
		_right.position.x = clampf(rx - COL_W * 0.5, 0.0, vw - COL_W)
	else:
		_left.position.x = 0.0
		_right.position.x = vw - COL_W
