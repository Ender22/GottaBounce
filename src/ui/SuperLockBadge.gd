extends Control
## WK-20e SPAWN-TRUCE PADLOCK (spec docs/specs/wk20d_brawl_pacing_2026-11-15.md §4.2: "the aim arrow shows locked (greyed,
## with a small padlock glyph) and a soft dry click plays"). The Glossy Toybox gate padlock badge
## (assets/world/sports/gate_badge_locked.png: gold lock on a cream disc with a chocolate rim, so it reads by SHAPE, not by
## colour) hung beside the head of a Brawl goat whose super press was just dropped because it is still blinking.
## Screen space (LivingCues' CanvasLayer): constant size at any camera zoom, and it does not blink with the goat.
## Every dropped press re-pops it with a short "denied" wiggle. Presentation only: LivingCues owns placement / visibility.
##
## WK-154 (CD4-04): it said "locked" but not for how long. It now wears the Rocketball kickoff gate's DRAINING RING (the same
## DrainRing.gd drawing): padlock + gold ring = opens when the ring empties. The ring drains over the goat's remaining
## spawn protection; at the unlock the padlock swaps to the OPEN padlock, pops and flies up as it fades (the gate badge's
## open beat), so the badge ends on "go", not just disappears. The ring does not rock with the "no-no" wiggle.

const DRAIN_RING := preload("res://src/ui/DrainRing.gd")             # WK-154
const TEX_LOCKED: Texture2D = preload("res://assets/world/sports/gate_badge_locked.png")   # WK-154
const TEX_OPEN: Texture2D = preload("res://assets/world/sports/gate_badge_open.png")       # WK-154
const POP_TIME := 0.12        # s scale 0.3 -> 1.0 (back-eased) on each dropped press
const WIGGLE_TIME := 0.24     # s the "no-no" rock decays over
const WIGGLE_DEG := 16.0      # peak rock angle
const WIGGLE_HZ := 9.0        # rock rate
const OPEN_POP_T := 0.06      # WK-154: s the open padlock scales 1.0 -> OPEN_POP_SCALE (the gate's BADGE_POP_T)
const OPEN_POP_SCALE := 1.3   # WK-154: (the gate's BADGE_POP_SCALE)

@onready var _pivot: Control = $Pivot
@onready var _lock: Sprite2D = $Pivot/Lock
@onready var _ring: Node2D = $Ring   # WK-154

var player_idx := -1          # QA: whose super is locked
var pops := 0                 # QA: dropped presses this badge has shown
var ring_frac := -1.0         # QA (WK-154): ring share left (1 full .. 0 empty); < 0 = no ring (an untimed lock)
var opening := false          # QA (WK-154): the unlock beat is playing
var _pop := 1.0               # 0..1 pop-in progress
var _wig := 1.0               # 0..1 wiggle progress
var _open_t := -1.0           # WK-154: s since the unlock beat began (< 0 = not opening)
var _ring_mode := false       # WK-154: this lock is timed (ring sizes apply, also through the open beat)

func _ready() -> void:
	_ring.draw.connect(_draw_ring)   # WK-154

func setup(idx: int) -> void:
	player_idx = idx
	_apply_size()

## A dropped press: restart the pop + wiggle so a mash reads as repeated "no", not a static icon.
func pop() -> void:
	pops += 1
	_pop = 0.0
	_wig = 0.0
	_open_t = -1.0
	opening = false
	_lock.texture = TEX_LOCKED
	modulate.a = 1.0
	_apply_size()

## WK-154: ring share left (1 = full, 0 = empty) of the timed spawn-truce lock; < 0 hides the ring (untimed lock).
func set_ring(frac: float) -> void:
	ring_frac = clampf(frac, 0.0, 1.0) if frac >= 0.0 else -1.0
	var mode: bool = ring_frac >= 0.0
	_ring.visible = mode and not opening   # the gate hides its ring at the open too
	if mode != _ring_mode:
		_ring_mode = mode
		_apply_size()
	_ring.queue_redraw()

## WK-154: the lock lifted: OPEN padlock, pop 1.0 -> 1.3, fly up while fading over Tuning.super_lock_open_time.
func start_open() -> void:
	if opening:
		return
	opening = true
	_open_t = 0.0
	_lock.texture = TEX_OPEN
	_ring.visible = false
	_apply_size()

## WK-154: the unlock beat has finished (LivingCues hides the badge).
func open_done() -> bool:
	return opening and _open_t >= Tuning.super_lock_open_time

## Half-size (canvas px) for keep-out checks / placement (the ring's outer edge while the ring shows).
func half_size() -> Vector2:
	var h: float = _badge_px() * 0.5
	if _ring_mode:
		h = maxf(h, Tuning.super_lock_ring_r + Tuning.super_lock_ring_band * 0.5 + Tuning.super_lock_ring_outline)
	return Vector2(h, h)

func place(screen_pos: Vector2, delta: float) -> void:
	position = screen_pos.round()
	_pop = minf(1.0, _pop + delta / POP_TIME)
	_wig = minf(1.0, _wig + delta / WIGGLE_TIME)
	var s: float = 0.3 + 0.7 * _ease_back(_pop)
	var fly := 0.0
	if opening:
		_open_t += delta
		var ot: float = maxf(Tuning.super_lock_open_time, OPEN_POP_T + 0.01)
		if _open_t < OPEN_POP_T:
			s = lerpf(1.0, OPEN_POP_SCALE, _open_t / OPEN_POP_T)
		else:
			var v: float = clampf((_open_t - OPEN_POP_T) / (ot - OPEN_POP_T), 0.0, 1.0)
			s = OPEN_POP_SCALE
			fly = -Tuning.super_lock_open_fly * (1.0 - (1.0 - v) * (1.0 - v))
			modulate.a = 1.0 - v
	_pivot.scale = Vector2.ONE * s
	_pivot.position = Vector2(0.0, fly)
	_ring.scale = Vector2.ONE * (0.3 + 0.7 * _ease_back(_pop))
	var decay: float = 1.0 - _wig
	_pivot.rotation = 0.0 if opening else deg_to_rad(WIGGLE_DEG) * decay * decay * sin(_wig * WIGGLE_TIME * TAU * WIGGLE_HZ)

func _draw_ring() -> void:   # WK-154: the gate's ring look, sized for a screen-space HUD badge
	if ring_frac < 0.0:
		return
	DRAIN_RING.draw(_ring, Vector2.ZERO, Tuning.super_lock_ring_r, Tuning.super_lock_ring_band, Tuning.super_lock_ring_outline,
		ring_frac)

## The padlock disc size: Tuning.super_lock_ring_badge_px inside the ring (WK-154), else the WK-20e size.
func _badge_px() -> float:
	if Tuning.super_lock_ring_badge_px > 0.0 and _ring_mode:
		return Tuning.super_lock_ring_badge_px
	return Tuning.super_lock_badge_px

func _apply_size() -> void:
	if _lock != null and _lock.texture != null:
		_lock.scale = Vector2.ONE * (_badge_px() / float(_lock.texture.get_width()))

func _ease_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var u := t - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u
