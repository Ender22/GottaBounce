extends Control
## WK-26 "!" TARGET WARNING (audit D-07): a small shout-burst (the shared tintable assets/fx/word_burst.png, fx_tint in
## the AIMER's colour) with a cream "!" in Lilita One, hung beside the head of the goat a super is aimed at. The burst's
## tail points at the head (flipped when the bubble sits on the left). Screen space (LivingCues' CanvasLayer), so it
## never shrinks with the camera zoom. It pops in, then throbs faster as the aimer's 2 s fuse burns down.
## Presentation only: LivingCues owns placement / visibility every frame.

const POP_TIME := 0.12
const THROB_HZ_MIN := 3.0    # throb rate at aim entry ...
const THROB_HZ_MAX := 9.0    # ... and at the auto-fire cap
const THROB_AMP := 0.10      # +-10 % scale

@onready var _pivot: Control = $Pivot
@onready var _burst: Sprite2D = $Pivot/Burst

var aimer_idx := -1          # QA: whose super this warns about
var target_idx := -1         # QA: the goat it hangs over
var slot := -1               # LivingCues placement slot (0 facing side, 1 other side, 2 above the pip); sticky per target
var _phase := 0.0
var _pop := 0.0              # 0..1 pop-in progress (restarts when the target changes)

func setup(color: Color, aimer: int) -> void:
	aimer_idx = aimer
	_burst.self_modulate = color

## Re-aim at a new target: restart the pop so a switch reads as a new warning, not a slide.
func retarget(idx: int) -> void:
	if idx != target_idx:
		target_idx = idx
		slot = -1
		_pop = 0.0

## left = the bubble sits LEFT of the head (tail must point down-right).
func place(screen_pos: Vector2, left: bool, fuse: float, delta: float) -> void:
	position = screen_pos.round()
	_burst.flip_h = left
	_pop = minf(1.0, _pop + delta / POP_TIME)
	_phase += delta * TAU * lerpf(THROB_HZ_MIN, THROB_HZ_MAX, clampf(fuse, 0.0, 1.0))
	var pop_s: float = 0.3 + 0.7 * _ease_back(_pop)
	var s: float = pop_s * (1.0 + THROB_AMP * sin(_phase) * _pop)
	_pivot.scale = Vector2(s, s)

## Half-size (canvas px) of the bubble, for keep-out checks.
func half_size() -> Vector2:
	return Vector2(44.0, 38.0)

func _ease_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var u := t - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u
