extends Node2D
## WK-37 GHOST GOAT (docs/specs/wk37a_ghost_goats_2026-11-14.md §2, art brief docs/briefs/ghost_goats_2026-11-14.md).
## A presentation-plus-input entity owned by the GhostDirector — NEVER a Player, never in PartyMatch.players, on no
## physics layer, never a target for bots / super aim / chevrons, never framed by the camera (spec §2.1 / §4).
##
## Reads ONE InputIntent provider (INV-8): the eliminated human's own InputHuman (same device), or a GhostBot.
##   stick          FLOAT (no gravity, no collision): accel to ghost_max_speed, damp when released
##   FLY held       hurry x ghost_hurry_mult
##   SUPER / POWERUP press   PUFF (the director decides: ready / dud)
##   TAUNT press    BLEAT (the director rate-limits; "BAAA!" word puff; WK-53 owns the sample)
## The logical position (global_position) is bob-free; the bob is a visual offset on the body only (T2 compares it).
## Each frame the director clamps the position into the camera's visible rect (inset) — ghosts follow the camera.

const GHOST_SHADER := preload("res://assets/shaders/ghost.gdshader")
const PUFF_SHADER := preload("res://assets/shaders/ghost_puff.gdshader")
const TAIL_TEX := preload("res://assets/fx/ghost_tail.png")
const PUFF_TEX := preload("res://assets/fx/ghost_puff.png")
const SOFT_TEX := preload("res://assets/fx/puff_soft.png")
const BALL_FRAC := 0.66               # Player.SPRITE_BALL_FRAC: round body = 66 % of the idle texture width
const BALL_CENTER := Vector2(0.57, 0.51)   # Player.SPRITE_BALL_CENTER (fraction of the texture)
const BODY_RADIUS := 44.0             # Player.BODY_RADIUS
const FACING_DEADZONE := 0.15         # s velocity.x must hold a new sign before the ghost turns (brief §2)
const TAIL_FOLLOW := 8.0              # /s spring-follow of the tail lean (reads as cloth, not a rigid stick)
# --- WK-37c wide-camera readability (consts here while WK-128 owns Tuning.gd; move to the Tuning ghost block later) ---
# The rim is a screen-space OUTLINE band (ghost.gdshader flat_mode) instead of a x1.08 copy: constant px at any zoom.
const RIM_QUAD_PAD := 1.30            # rim quad vs the art (idle art is trimmed to its edges; room for the band)
const RIM_PX := 2.5                   # pale band, px at 1080p (brief §2: "~2-3 screen px all round")
const RIM_PX_WIDE := 3.5              # ... on the widest camera
const RIM_GAIN := 2.0                 # band alpha = root alpha x this (0.40 -> 0.80): the edge is the findable part
const DEEP_PX := 1.0                  # thin outer line in the ghost's deep hue, px at 1080p (contrast on bright skies)
const DEEP_GAIN := 0.8                # its alpha vs the band
# Wide-camera compensation: zero at zoom >= WIDE_ZOOM_FULL (the brief's reference 0.46, so T9's 0.40 / 0.25 hold
# there), full at WIDE_ZOOM_MAX and below. Ghosts stay below living goats on every channel (alpha < 0.6, scale < 1).
const WIDE_ZOOM_FULL := 0.46
const WIDE_EASE := 2.0                # /s the wide factor eases at (0 -> 1 over 0.5 s)
const MAX_VIS_STEP := 1.0 / 30.0      # s: cap on the real-time step the visuals advance per frame (see _process)
const WIDE_ZOOM_MAX := 0.30
const WIDE_ALPHA_MULT := 1.3          # 0.40 -> 0.52 / 0.25 -> 0.325 at the widest
const WIDE_SCALE := 0.95              # ghost body scale at the widest (living = 1.0; ghost_scale 0.85 otherwise)
const FLATTEN := 0.40                 # body colour pulled toward the flat ghost hue (quiets the baked jetpack/detail)
const FLATTEN_WIDE := 0.65            # ... on the widest camera (a ~25 px ghost reads as one clean colour shape)
const OFF_HUE_FLATTEN := 0.85         # saturated off-hue pixels (the baked jetpack) pulled to the ghost hue
const FILL_SAT := 0.3                 # flat-fill target -> this far toward the SATURATED living colour (a 40 % fill
const FILL_SAT_WIDE := 0.75           # over a complementary backdrop greys out; hue = identity, brief §3.1) ... widest

var idx := -1
var skin := "pink"
var color := Color.WHITE
var human := false
var provider                          # InputHuman (the eliminated human's device) or GhostBot
var director
var vel := Vector2.ZERO
var frozen := false                   # STAGE_END: hold still and fade with the KO freeze
var age := 0.0                        # s since the ghost appeared (scaled game time)
var idle_t := 0.0                     # s since the last stick/button input (pip rule)
var moved_after_idle := 0.0           # s left of the pip's full-alpha "I moved again" bump

# puff charge bookkeeping (the director decides; the ghost only carries the numbers)
var next_puff_t := 0.0                # director clock when the next puff arms
var puffs_used := 0
var live_cloud = null

# telemetry (spec §8.2)
var stats := {}

var _vis: Node2D                      # alpha root (modulate.a = ghost_alpha / ghost_alpha_near)
var _body_root: Node2D                # bob + facing + scale
var _tail_pivot: Node2D
var _tail: Sprite2D
var _rim: Sprite2D
var _body: Sprite2D
var _orbit: Sprite2D
var _facing := 1
var _facing_pending_t := 0.0
var _tail_rot := 0.0
var _phase := 0.0
var _prev_super := false
var _alpha := 0.0
var _alpha_target := 0.40
var _hidden_orbit := true
var _wide_applied := -1.0
var _wide := 0.0

func setup(i: int, skin_id: String, col: Color, is_human: bool, prov, dir) -> void:
	idx = i
	skin = skin_id
	color = col
	human = is_human
	provider = prov
	director = dir
	_phase = randf() * TAU

func _ready() -> void:
	_vis = Node2D.new()
	add_child(_vis)
	_body_root = Node2D.new()
	_vis.add_child(_body_root)
	var tex_path := "res://assets/characters/bouncer_%s_idle.png" % skin
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else load("res://assets/characters/bouncer_pink_idle.png")
	var k: float = (2.0 * BODY_RADIUS) / (BALL_FRAC * float(tex.get_width()))
	var off: Vector2 = (Vector2(0.5, 0.5) - BALL_CENTER) * Vector2(tex.get_size())
	var ghost_body_col: Color = _ghostify(color)
	var rim_col: Color = color.lerp(Color.WHITE, 0.70)
	var deep_col: Color = Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 1.0)
	# tail (E4) — behind everything, rooted under the hem at body centre + (0, 0.30 x body h)
	_tail_pivot = Node2D.new()
	_tail_pivot.position = Vector2(0.0, 0.30 * 2.0 * BODY_RADIUS)
	_body_root.add_child(_tail_pivot)
	_tail = Sprite2D.new()
	_tail.texture = TAIL_TEX
	var tail_h: float = 0.7 * 2.0 * BODY_RADIUS
	var tk: float = tail_h / float(TAIL_TEX.get_height())
	_tail.scale = Vector2(tk, tk)
	_tail.offset = Vector2(0.0, float(TAIL_TEX.get_height()) * 0.5 - 40.0)   # node origin = the dome top
	_tail.material = _mat(rim_col, deep_col, false, false, true, 0.04)
	_tail_pivot.add_child(_tail)
	# rim / halo layer (E2): same texture, flat rim colour, x1.08, same hem cut
	_rim = Sprite2D.new()
	_rim.texture = tex
	_rim.offset = off / RIM_QUAD_PAD           # padded quad, content remapped back onto the body (shader quad_pad)
	_rim.scale = Vector2(k, k) * RIM_QUAD_PAD
	_rim.material = _mat(rim_col, deep_col, true, true, false, 0.0)
	var rm := _rim.material as ShaderMaterial
	rm.set_shader_parameter("quad_pad", RIM_QUAD_PAD)
	rm.set_shader_parameter("rim_gain", RIM_GAIN)
	rm.set_shader_parameter("deep_gain", DEEP_GAIN)
	_apply_rim_px(0.0)
	_body_root.add_child(_rim)
	# body (E1/E3): the goat through ghost.gdshader
	_body = Sprite2D.new()
	_body.texture = tex
	_body.offset = off
	_body.scale = Vector2(k, k)
	_body.material = _mat(rim_col, deep_col, false, true, false, 0.0)
	(_body.material as ShaderMaterial).set_shader_parameter("off_hue_flatten", OFF_HUE_FLATTEN)
	_body_root.add_child(_body)
	(_body.material as ShaderMaterial).set_shader_parameter("skin_col", ghost_body_col)
	_apply_rim_px(0.0)
	# puff-ready mini cloud (E8) — outside the alpha root so it stays readable (it IS the "you can puff" cue)
	_orbit = Sprite2D.new()
	_orbit.texture = PUFF_TEX
	var ok: float = Tuning.ghost_orbit_size / 1024.0
	_orbit.scale = Vector2(ok, ok)
	var om := ShaderMaterial.new()
	om.shader = PUFF_SHADER
	_orbit.material = om
	_orbit.self_modulate = Color(color.r, color.g, color.b, 0.9)
	_orbit.visible = false
	add_child(_orbit)
	_alpha = 0.0
	_vis.modulate.a = 0.0
	scale = Vector2.ZERO
	# pop-in (E11): rises out of the KO blast, controllable from the first frame
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 1.12, Tuning.ghost_pop_in_time * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, Tuning.ghost_pop_in_time * 0.3)
	_spawn_puffs(Color(1, 1, 1, 0.8), 10, 1.0)
	_body_root.scale = Vector2.ONE * Tuning.ghost_scale
	_wide = wide_factor()   # start at the current camera's compensation (eased from here on)

func _mat(rim_col: Color, deep_col: Color, flat: bool, hem: bool, grey: bool, wave: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GHOST_SHADER
	m.set_shader_parameter("skin_col", color)
	m.set_shader_parameter("rim_col", rim_col)
	m.set_shader_parameter("deep_col", deep_col)
	m.set_shader_parameter("flat_mode", flat)
	m.set_shader_parameter("hem_on", hem)
	m.set_shader_parameter("grey_art", grey)
	m.set_shader_parameter("wave_amp", wave)
	m.set_shader_parameter("phase", _phase)
	return m

## Brief §3.1 body target: saturation x0.85 then 20 % toward white (used for the tintable tail).
func _ghostify(c: Color) -> Color:
	var l: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var g := Color(l, l, l).lerp(c, 0.85)
	return g.lerp(Color.WHITE, 0.20)

## WK-37c: 0 at zoom >= WIDE_ZOOM_FULL .. 1 at WIDE_ZOOM_MAX (how much wide-camera compensation applies).
func wide_factor() -> float:
	var z: float = WIDE_ZOOM_FULL
	if director != null and director.has_method("cam_zoom"):
		z = float(director.cam_zoom())
	return clampf((WIDE_ZOOM_FULL - z) / (WIDE_ZOOM_FULL - WIDE_ZOOM_MAX), 0.0, 1.0)

## Rim band + deep line widths in FRAMEBUFFER px (fwidth works in real pixels; the design px are 1080p logical).
func _apply_rim_px(w: float) -> void:
	if _rim == null:
		return
	var win := get_window()
	var fb_k: float = float(win.size.y) / 1080.0 if win != null and win.size.y > 0 else 1.0
	var rm := _rim.material as ShaderMaterial
	rm.set_shader_parameter("rim_px", lerpf(RIM_PX, RIM_PX_WIDE, w) * fb_k)
	rm.set_shader_parameter("deep_px", DEEP_PX * fb_k)
	if _body != null:
		var bm := _body.material as ShaderMaterial
		bm.set_shader_parameter("flatten", lerpf(FLATTEN, FLATTEN_WIDE, w))
		bm.set_shader_parameter("skin_col", _ghostify(color).lerp(color, lerpf(FILL_SAT, FILL_SAT_WIDE, w)))

## QA (spec T9): the alpha the ghost is drawn at (root modulate.a).
func ghost_alpha_now() -> float:
	return _vis.modulate.a if _vis != null else 0.0

## Bob-free logical position (T2) — global_position IS bob-free; exposed for clarity.
func logical_position() -> Vector2:
	return global_position

## Per-tick: input -> motion. Called by the director (it owns the clock, hush, view clamp). Returns the intent edges
## {puff: bool, bleat: bool, active: bool} so the director can apply the rules.
func tick(delta: float, view: Rect2) -> Dictionary:
	var out := {"puff": false, "bleat": false, "active": false}
	age += delta
	var intent: InputIntent = provider.poll() if provider != null else InputIntent.new()
	if frozen:
		_prev_super = intent.super_hold
		vel = Vector2.ZERO
		return out
	var aim: Vector2 = intent.aim
	if aim.length() > 1.0:
		aim = aim.normalized()
	var stick: bool = aim.length() > 0.2
	var max_v: float = Tuning.ghost_max_speed * (Tuning.ghost_hurry_mult if intent.boost else 1.0)
	if aim.length() > 0.001:
		vel = vel.move_toward(aim * max_v, Tuning.ghost_accel * delta)
	else:
		vel *= exp(-Tuning.ghost_damp * delta)
		if vel.length() < 2.0:
			vel = Vector2.ZERO
	global_position += vel * delta
	clamp_to(view)
	var super_edge: bool = intent.super_hold and not _prev_super
	_prev_super = intent.super_hold
	out["puff"] = super_edge or intent.use_powerup
	out["bleat"] = intent.taunt
	out["active"] = stick or intent.boost or intent.super_hold or intent.use_powerup or intent.taunt
	if out["active"]:
		if idle_t >= Tuning.ghost_pip_idle_after:
			moved_after_idle = Tuning.ghost_pip_full_time
		idle_t = 0.0
	else:
		idle_t += delta
	moved_after_idle = maxf(0.0, moved_after_idle - delta)
	return out

## Keep the ghost centre inside `view` (already inset by the director). Never moves the camera (spec §4.3).
func clamp_to(view: Rect2) -> void:
	if view.size.x <= 0.0 or view.size.y <= 0.0:
		return
	var p := global_position
	var c := Vector2(clampf(p.x, view.position.x, view.end.x), clampf(p.y, view.position.y, view.end.y))
	if c != p:
		global_position = c
		if c.x != p.x:
			vel.x = 0.0
		if c.y != p.y:
			vel.y = 0.0

## Alpha target: 0.40, 0.25 near a living goat; eased (never snaps).
func set_alpha_target(a: float) -> void:
	_alpha_target = a

func set_orbit_visible(on: bool) -> void:
	_hidden_orbit = not on

## Visuals every rendered frame (bob, facing, tail lag, alpha ease, orbit).
func _process(delta: float) -> void:
	var d: float = delta / maxf(Engine.time_scale, 0.05) if Engine.time_scale < 1.0 else delta
	# WK-37c: un-scaling by a near-zero time_scale (KO slow-mo / hit-stop) made d a huge step = one-frame alpha snaps
	# (0.42 -> 0.09 at STAGE_END, 0 -> 0.40 pop-ins in the WK-93 recordings; brief R2). Cap the real step per frame.
	d = minf(d, MAX_VIS_STEP)
	var a_goal: float = 0.0 if frozen else _alpha_target
	if frozen:
		_alpha = move_toward(_alpha, 0.0, d / maxf(Tuning.round_end_freeze * 0.6, 0.1) * Tuning.ghost_alpha)
	else:
		var rate: float = absf(Tuning.ghost_alpha - Tuning.ghost_alpha_near) / maxf(Tuning.ghost_alpha_ease, 0.01)
		if _alpha < Tuning.ghost_alpha_near and a_goal >= Tuning.ghost_alpha_near:
			rate = Tuning.ghost_alpha / maxf(Tuning.ghost_pop_in_time, 0.05)   # pop-in fade
		_alpha = move_toward(_alpha, a_goal, rate * d)
	_wide = move_toward(_wide, wide_factor(), WIDE_EASE * d)   # eased: a zoom jump (stage start) never snaps alpha
	var wide: float = _wide
	_vis.modulate.a = _alpha * lerpf(1.0, WIDE_ALPHA_MULT, wide)
	if absf(wide - _wide_applied) > 0.01:
		_wide_applied = wide
		_apply_rim_px(wide)
	# bob (visual only, the body root) — glide + bob, never squash, never bounce
	var bob: float = 0.0 if frozen else sin(age * TAU * Tuning.ghost_bob_hz + _phase) * Tuning.ghost_bob_amp
	_body_root.position = Vector2(0.0, bob)
	# facing follows velocity.x with a deadzone (no flicker)
	var want: int = _facing
	if absf(vel.x) > 20.0:
		want = 1 if vel.x > 0.0 else -1
	if want != _facing:
		_facing_pending_t += d
		if _facing_pending_t >= FACING_DEADZONE:
			_facing = want
			_facing_pending_t = 0.0
	else:
		_facing_pending_t = 0.0
	_body_root.scale = Vector2(float(_facing), 1.0) * lerpf(Tuning.ghost_scale, maxf(WIDE_SCALE, Tuning.ghost_scale), wide)
	# tail: leans opposite velocity.x (in world terms) + a sway at the bob rate, spring-followed (lags the bob)
	var lean: float = deg_to_rad(Tuning.ghost_tail_lean_deg) * clampf(vel.x / maxf(Tuning.ghost_max_speed, 1.0), -1.0, 1.0)
	var sway: float = deg_to_rad(Tuning.ghost_tail_sway_deg) * sin(age * TAU * Tuning.ghost_bob_hz + _phase - 0.9)
	var target: float = (lean + sway) * float(_facing)   # body_root is mirrored by facing
	_tail_rot = lerpf(_tail_rot, target, 1.0 - exp(-TAIL_FOLLOW * d))
	_tail_pivot.rotation = _tail_rot
	_tail.scale.x = -absf(_tail.scale.x)   # the art curls right: mirror so the hook trails behind the facing
	# puff-ready mini cloud orbits the ghost
	_orbit.visible = not _hidden_orbit and not frozen
	if _orbit.visible:
		var ang: float = age * TAU / maxf(Tuning.ghost_orbit_period, 0.1)
		_orbit.position = Vector2(cos(ang), sin(ang) * 0.55) * Tuning.ghost_orbit_radius + Vector2(0.0, bob)
		_orbit.z_index = 0 if sin(ang) > 0.0 else -1

## Small soft-puff burst (pop-in E11 / dud "fft" wisp E10).
func _spawn_puffs(col: Color, n: int, size_k: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = SOFT_TEX
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = 0.45
	p.spread = 180.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 60.0 * size_k
	p.initial_velocity_max = 160.0 * size_k
	p.damping_min = 120.0
	p.damping_max = 200.0
	p.scale_amount_min = 0.25 * size_k
	p.scale_amount_max = 0.45 * size_k
	p.color = col
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(p)
	p.global_position = global_position
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## Dud press: a tiny grey "fft" wisp, no sound, no charge spent (spec §2.3).
func dud_fx() -> void:
	_spawn_puffs(Color("#c4cad3", 0.6), 3, 0.6)
