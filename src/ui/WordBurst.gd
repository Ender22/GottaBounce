extends Control
## WK-37 / WK-53 "BAAA!" WORD PUFF (art brief E14): the shared tintable shout-burst (assets/fx/word_burst.png, fx_tint in
## the bleater's colour) with "BAAA!" in Lilita One (cream fill, chocolate outline, 40 px — over the 28 px floor).
## Screen space (a CanvasLayer) so the type never shrinks with the camera zoom. Anchored to the world point it was
## shouted from, rises Tuning.ghost_word_rise screen px over Tuning.ghost_word_life, wobbles +-8 deg at 6 Hz, decaying.
## The ghost variant draws at Tuning.ghost_word_alpha (60 %). Presentation only.
##
## WK-37c: the bubble draws ABOVE every goat (CanvasLayer), so it must never sit on a living one. present() takes an
## optional `avoid` Callable returning Array[Rect2] (canvas px) of things to keep clear (GhostDirector.living_screen_rects).
## It picks the first free slot around the source (above, above-left/right, sides, below), re-checks every frame (goats
## move fast) and glides to a new slot instead of jumping. No avoid callable = the old fixed "above" placement.
## WK-37e: an optional `block` Callable (Array[Rect2]) is a HARD keep-out (the HUD centre banner): slots that touch it
## lose to any slot that doesn't, and if every slot touches it the word hides that frame instead of printing on the banner.

const WOBBLE_DEG := 8.0
const WOBBLE_HZ := 6.0
const ABOVE_PX := 64.0     # screen px above the source point
const HALF := Vector2(78.0, 62.0)   # bubble's keep-clear half-size, canvas px (burst art at 0.23 ~ 177 px incl. spikes)
const SLIDE_RATE := 18.0   # /s exponential glide toward a new slot
# Slot offsets (canvas px) from the source point, in preference order. The rise is added on top of every slot.
const SLOTS := [Vector2(0, -64), Vector2(-120, -52), Vector2(120, -52), Vector2(-150, 0), Vector2(150, 0),
	Vector2(0, 96), Vector2(-120, 84), Vector2(120, 84)]

@onready var _pivot: Control = $Pivot
@onready var _burst: Sprite2D = $Pivot/Burst   # Sprite2D: fx_tint reads self_modulate through vertex COLOR (a TextureRect did not)

var _cam = null
var _world := Vector2.ZERO
var _t := 0.0
var _alpha := 1.0
var _avoid: Callable = Callable()
var _slot := 0
var _offset := Vector2(0, -ABOVE_PX)   # current (gliding) offset
var _placed := false
var overlap_frames := 0     # QA: frames the bubble overlapped an avoid rect (should stay 0 when a free slot exists)
var source_idx := -1        # WK-37e: the bleater's player index (GhostDirector.word_active)
var _block: Callable = Callable()
var blocked_frames := 0     # QA: frames hidden because every slot touched a block rect (the banner)

func present(source: Node2D, cam, color: Color, alpha: float, avoid: Callable = Callable(), block: Callable = Callable()) -> void:
	_cam = cam
	_world = source.global_position
	_alpha = alpha
	_avoid = avoid
	_block = block
	var si: Variant = source.get("idx")
	source_idx = int(si) if si != null else -1
	_burst.self_modulate = color
	modulate.a = alpha
	_place(0.0)
	_pivot.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(_pivot, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _source_screen() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	var z: float = _cam.zoom.x
	return (_world - _cam.get_screen_center_position()) * z + vp * 0.5

func _rise() -> float:
	var life: float = maxf(Tuning.ghost_word_life, 0.05)
	return Tuning.ghost_word_rise * clampf(_t / life, 0.0, 1.0)

func _clamp_screen(p: Vector2) -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	return Vector2(clampf(p.x, 110.0, vp.x - 110.0), clampf(p.y, 90.0, vp.y - 90.0))

## Overlap area of the bubble centred at `c` with the avoid rects.
func _overlap(c: Vector2, rects: Array) -> float:
	var me := Rect2(c - HALF, HALF * 2.0)
	var a := 0.0
	for r in rects:
		var x: Rect2 = me.intersection(r as Rect2)
		a += x.get_area()
	return a

func _place(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var src: Vector2 = _source_screen()
	var rise := Vector2(0.0, -_rise())
	var rects: Array = _avoid.call() if _avoid.is_valid() else []
	var blocks: Array = _block.call() if _block.is_valid() else []
	if not rects.is_empty() or not blocks.is_empty():
		var cur: Vector2 = _clamp_screen(src + (SLOTS[_slot] as Vector2) + rise)
		if _overlap(cur, rects) + _overlap(cur, blocks) > 0.0:
			var best := _slot
			var best_a := INF
			for k in range(SLOTS.size()):
				var c: Vector2 = _clamp_screen(src + (SLOTS[k] as Vector2) + rise)
				var a: float = _overlap(c, rects) + _overlap(c, blocks) * 1.0e6   # a banner touch loses to anything
				if a < best_a - 0.5:
					best_a = a
					best = k
				if a <= 0.0:
					break
			_slot = best
	var goal: Vector2 = SLOTS[_slot] as Vector2
	if not _placed or delta <= 0.0:
		_offset = goal
		_placed = true
	else:
		_offset = _offset.lerp(goal, 1.0 - exp(-SLIDE_RATE * delta))
	var sp: Vector2 = _clamp_screen(src + _offset + rise)
	if not rects.is_empty() and _overlap(sp, rects) > 0.0:
		overlap_frames += 1
	position = sp.round()
	var on_banner: bool = not blocks.is_empty() and _overlap(sp, blocks) > 0.0
	if on_banner:
		blocked_frames += 1
	visible = not on_banner   # WK-37e FIX 4: never print a ghost word on the centre banner

func _process(delta: float) -> void:
	# WK-37e: cap the un-scaled step (same as GhostGoat): delta / a near-zero time_scale (KO slow-mo / hit-stop under a
	# fixed-step recorder) aged the word 0.7 s in a frame or two — the bubble vanished early in the WK-93 recordings.
	var d: float = minf(delta / maxf(Engine.time_scale, 0.05), Tuning.ghost_max_vis_step)
	_t += d
	var life: float = maxf(Tuning.ghost_word_life, 0.05)
	_place(d)
	var decay: float = 1.0 - clampf(_t / life, 0.0, 1.0)
	_pivot.rotation = deg_to_rad(WOBBLE_DEG) * sin(_t * TAU * WOBBLE_HZ) * decay
	var fade_from: float = life * 0.7
	if _t > fade_from:
		modulate.a = _alpha * (1.0 - clampf((_t - fade_from) / (life - fade_from), 0.0, 1.0))
	if _t >= life:
		queue_free()
