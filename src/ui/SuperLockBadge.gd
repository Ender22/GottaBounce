extends Control
## WK-20e SPAWN-TRUCE PADLOCK (spec docs/specs/wk20d_brawl_pacing_2026-11-15.md §4.2: "the aim arrow shows locked (greyed,
## with a small padlock glyph) and a soft dry click plays"). The Glossy Toybox gate padlock badge
## (assets/world/sports/gate_badge_locked.png: gold lock on a cream disc with a chocolate rim, so it reads by SHAPE, not by
## colour) hung beside the head of a Brawl goat whose super press was just dropped because it is still blinking.
## Screen space (LivingCues' CanvasLayer): constant size at any camera zoom, and it does not blink with the goat.
## Every dropped press re-pops it with a short "denied" wiggle. Presentation only: LivingCues owns placement / visibility.

const POP_TIME := 0.12        # s scale 0.3 -> 1.0 (back-eased) on each dropped press
const WIGGLE_TIME := 0.24     # s the "no-no" rock decays over
const WIGGLE_DEG := 16.0      # peak rock angle
const WIGGLE_HZ := 9.0        # rock rate

@onready var _pivot: Control = $Pivot
@onready var _lock: Sprite2D = $Pivot/Lock

var player_idx := -1          # QA: whose super is locked
var pops := 0                 # QA: dropped presses this badge has shown
var _pop := 1.0               # 0..1 pop-in progress
var _wig := 1.0               # 0..1 wiggle progress

func setup(idx: int) -> void:
	player_idx = idx
	_apply_size()

## A dropped press: restart the pop + wiggle so a mash reads as repeated "no", not a static icon.
func pop() -> void:
	pops += 1
	_pop = 0.0
	_wig = 0.0
	_apply_size()

## Half-size (canvas px) for keep-out checks / placement.
func half_size() -> Vector2:
	var h: float = Tuning.super_lock_badge_px * 0.5
	return Vector2(h, h)

func place(screen_pos: Vector2, delta: float) -> void:
	position = screen_pos.round()
	_pop = minf(1.0, _pop + delta / POP_TIME)
	_wig = minf(1.0, _wig + delta / WIGGLE_TIME)
	_pivot.scale = Vector2.ONE * (0.3 + 0.7 * _ease_back(_pop))
	var decay: float = 1.0 - _wig
	_pivot.rotation = deg_to_rad(WIGGLE_DEG) * decay * decay * sin(_wig * WIGGLE_TIME * TAU * WIGGLE_HZ)

func _apply_size() -> void:
	if _lock != null and _lock.texture != null:
		_lock.scale = Vector2.ONE * (Tuning.super_lock_badge_px / float(_lock.texture.get_width()))

func _ease_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var u := t - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u
