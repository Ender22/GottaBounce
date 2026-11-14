extends Control
## WK-37 / WK-53 "BAAA!" WORD PUFF (art brief E14): the shared tintable shout-burst (assets/fx/word_burst.png, fx_tint in
## the bleater's colour) with "BAAA!" in Lilita One (cream fill, chocolate outline, 40 px — over the 28 px floor).
## Screen space (a CanvasLayer) so the type never shrinks with the camera zoom. Anchored to the world point it was
## shouted from, rises Tuning.ghost_word_rise screen px over Tuning.ghost_word_life, wobbles +-8 deg at 6 Hz, decaying.
## The ghost variant draws at Tuning.ghost_word_alpha (60 %). Presentation only.

const WOBBLE_DEG := 8.0
const WOBBLE_HZ := 6.0
const ABOVE_PX := 64.0     # screen px above the source point

@onready var _pivot: Control = $Pivot
@onready var _burst: Sprite2D = $Pivot/Burst   # Sprite2D: fx_tint reads self_modulate through vertex COLOR (a TextureRect did not)

var _cam = null
var _world := Vector2.ZERO
var _t := 0.0
var _alpha := 1.0

func present(source: Node2D, cam, color: Color, alpha: float) -> void:
	_cam = cam
	_world = source.global_position
	_alpha = alpha
	_burst.self_modulate = color
	modulate.a = alpha
	_place()
	_pivot.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(_pivot, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _place() -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var vp: Vector2 = get_viewport_rect().size
	var z: float = _cam.zoom.x
	var sp: Vector2 = (_world - _cam.get_screen_center_position()) * z + vp * 0.5
	var life: float = maxf(Tuning.ghost_word_life, 0.05)
	sp.y -= ABOVE_PX + Tuning.ghost_word_rise * clampf(_t / life, 0.0, 1.0)
	sp.x = clampf(sp.x, 110.0, vp.x - 110.0)
	sp.y = clampf(sp.y, 90.0, vp.y - 90.0)
	position = sp.round()

func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.05)
	var life: float = maxf(Tuning.ghost_word_life, 0.05)
	_place()
	var decay: float = 1.0 - clampf(_t / life, 0.0, 1.0)
	_pivot.rotation = deg_to_rad(WOBBLE_DEG) * sin(_t * TAU * WOBBLE_HZ) * decay
	var fade_from: float = life * 0.7
	if _t > fade_from:
		modulate.a = _alpha * (1.0 - clampf((_t - fade_from) / (life - fade_from), 0.0, 1.0))
	if _t >= life:
		queue_free()
