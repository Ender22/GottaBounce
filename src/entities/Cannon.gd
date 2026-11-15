class_name Cannon
extends Area2D
## TRIALS rideable cannon (owner 2026-07-16: "cannons you can ride in"; v9 idea-bank "jump-in
## cannons"). Fly into the barrel -> you are LOADED (held at the muzzle via the existing frozen
## suspension — zero new Player state); the barrel oscillates between angle_min..angle_max on a
## deterministic clock; after hold_s it AUTO-FIRES you along the barrel at `impulse`. The skill is
## WHEN you enter (the swing phase IS the aim), Donkey-Kong-barrel style. A cooldown stops instant
## re-capture so you can fly back in deliberately.
##
## FENCES: the launch is a plain velocity set — NO smash license (_super_recent untouched), NO fuel
## change, NO Tuning constant read beyond max_speed clamping downstream. Not a hazard; never kills.
##
## {"type":"cannon","x","y","angle_min":-80,"angle_max":-10,"period_s":2.4,"impulse":2600,
##  "hold_s":1.0,"r":70} — x,y = pivot CENTER; angles in DEGREES, screen-space (y down, so -90 = up).
## angle_min == angle_max = a FIXED barrel (pure ride, no timing read).
##
## Body = the bespoke toy-cannon sprite (assets/objects/cannon.png, 2026-07-17 art pass: glossy
## navy barrel + gold muzzle + red base). The WHOLE toy rocks around its mount to aim (the sprite's
## barrel is baked at BAKED_ANGLE; we rotate by the difference). Crusher-steel assembly remains the
## fallback if the sprite is missing.

const MASK_PLAYERS := 1 << 0
const BARREL_TEX: Texture2D = preload("res://assets/hazards/crusher.png")
const PIVOT_TEX: Texture2D = preload("res://assets/hazards/wrecking_ball.png")
const CANNON_TEX_PATH := "res://assets/objects/cannon.png"
const BAKED_ANGLE := -0.52          # ~-30 deg: the barrel angle baked into the sprite (screen space)
const PIVOT_FRAC := Vector2(0.44, 0.55)   # the mount point inside the sprite (fraction of w/h)

var angle_min := -80.0        # degrees
var angle_max := -10.0
var period_s := 2.4           # full min->max->min oscillation period
var impulse := 2600.0
var hold_s := 1.0
var r := 70.0                 # mouth capture radius
var barrel_len := 190.0

var _t := 0.0
var _rider = null             # captured Player (or null)
var _hold_t := 0.0
var _cooldown := 0.0          # per-cannon re-capture lockout after firing
var _flash := 0.0
var _tex: Texture2D = null    # bespoke cannon sprite (null -> steel-assembly fallback)

func setup_from_json(o: Dictionary) -> void:
	position = Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))
	angle_min = float(o.get("angle_min", -80.0))
	angle_max = float(o.get("angle_max", -10.0))
	period_s = maxf(0.2, float(o.get("period_s", 2.4)))
	impulse = float(o.get("impulse", 2600.0))
	hold_s = maxf(0.2, float(o.get("hold_s", 1.0)))
	r = float(o.get("r", 70.0))
	barrel_len = float(o.get("barrel_len", 190.0))

func _ready() -> void:
	add_to_group("cannon")
	if ResourceLoader.exists(CANNON_TEX_PATH):
		_tex = load(CANNON_TEX_PATH)
	collision_layer = 0
	collision_mask = MASK_PLAYERS
	monitoring = true
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = r
	cs.shape = c
	add_child(cs)
	z_index = 40
	body_entered.connect(_on_body_entered)

## Barrel angle right now (radians): a smooth sine sweep min->max->min over period_s.
func _angle() -> float:
	if is_equal_approx(angle_min, angle_max):
		return deg_to_rad(angle_min)
	var mid := (angle_min + angle_max) * 0.5
	var amp := (angle_max - angle_min) * 0.5
	return deg_to_rad(mid + amp * sin(_t * TAU / period_s))

func _barrel_dir() -> Vector2:
	return Vector2.from_angle(_angle())

func _on_body_entered(body: Node) -> void:
	if _rider != null or _cooldown > 0.0:
		return
	if body is Player and not body.is_dead() and not body.frozen:
		_capture(body)

func _capture(p) -> void:
	_rider = p
	_hold_t = 0.0
	p.frozen = true   # the existing suspension: zero velocity, no thrust/drain, pop-in tween untouched
	AudioManager.play_sfx("ui_click", {"pitch": 0.8, "volume_db": -6.0})

func _physics_process(delta: float) -> void:
	_t += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
	if _rider != null:
		if not is_instance_valid(_rider) or _rider.is_dead():
			_rider = null   # stage swap / kill while loaded: just let go
		else:
			_hold_t += delta
			# hold the rider at the muzzle (frozen: their physics is suspended, we own the position)
			_rider.global_position = global_position + _barrel_dir() * (barrel_len * 0.7)
			if _hold_t >= hold_s:
				_fire()
	queue_redraw()

func _fire() -> void:
	var p = _rider
	_rider = null
	_cooldown = 1.2
	_flash = 1.0
	if p == null or not is_instance_valid(p):
		return
	p.frozen = false
	p.global_position = global_position + _barrel_dir() * (barrel_len + 40.0)
	p.velocity = _barrel_dir() * impulse   # plain launch: no smash license, no fuel change (fence)
	if p.has_method("play_pop_in"):
		pass   # keep their scale alone — the launch stretch is the player's own streak VFX
	AudioManager.play_sfx("super_fire", {"pitch": 1.1, "volume_db": -10.0})   # WK-79c (was -2): in line with the WK-79b super blast (-10)
	EventBus.bounced_juicy.emit(p, impulse, global_position)   # camera/audio juice via existing channel

# ------------------------------------------------------------------ display
func _draw() -> void:
	var dir := _barrel_dir()
	var ang := _angle()
	# aim-arc telegraph (transient code VFX allowed): show the sweep span while idle, hot while loaded
	if not is_equal_approx(angle_min, angle_max):
		var col := Color(1.0, 0.82, 0.25, 0.5 if _rider != null else 0.22)
		draw_arc(Vector2.ZERO, barrel_len + 26.0, deg_to_rad(angle_min), deg_to_rad(angle_max), 40, col, 6.0, true)
	if _tex != null:
		# bespoke toy cannon: the whole sprite rocks around its mount by (aim - baked barrel angle)
		var th := (barrel_len + 90.0) * 1.05
		var tw := th * (float(_tex.get_width()) / maxf(1.0, float(_tex.get_height())))
		draw_set_transform(Vector2.ZERO, ang - BAKED_ANGLE, Vector2.ONE)
		draw_texture_rect(_tex, Rect2(-Vector2(tw * PIVOT_FRAC.x, th * PIVOT_FRAC.y), Vector2(tw, th)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# fallback: steel assembly (barrel = crusher sprite along the aim + pivot ball at the root)
		var bw := barrel_len
		var bh := 86.0
		draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
		draw_texture_rect(BARREL_TEX, Rect2(Vector2(-24.0, -bh * 0.5), Vector2(bw + 24.0, bh)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var ps := 120.0
		draw_texture_rect(PIVOT_TEX, Rect2(Vector2(-ps * 0.5, -ps * 0.5), Vector2(ps, ps)), false)
	# loaded fuse ring + muzzle flash (transient telegraph)
	if _rider != null:
		var k := _hold_t / hold_s
		draw_arc(Vector2.ZERO, 74.0, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color(1.0, 0.4, 0.2, 0.95), 10.0, true)
	if _flash > 0.0:
		draw_circle(dir * (barrel_len + 30.0), 46.0 * (1.0 + (1.0 - _flash)), Color(1.0, 0.8, 0.3, 0.5 * _flash))
