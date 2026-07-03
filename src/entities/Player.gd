class_name Player
extends CharacterBody2D
## The creature. P1 bounce · P2 jetpack/fuel/super-boost · P3 smash knockback + hitstun + death.
## Consumes an InputIntent provider (INV-8). Smashable/Killable via shared contracts.
##
## Visuals: bouncer character sprites (assets/characters/bouncer_<skin>_idle.png), facing flip,
## code squash/stretch + squash-pose swap on bounce, contact shadow, textureless exhaust.
## The physics below is the hard-won tuned core: ported unchanged.

const LAYER_PLAYERS := 1 << 0
const MASK_SURFACES := 1 << 2
const BODY_RADIUS := 44.0
const TUMBLE_SPEED := 9.4            # rad/s spin while stunned (~540 deg/s)

var provider
var fuel: float
var _last_aim := Vector2.UP
var _supercharge_timer := 0.0
var _stun_timer := 0.0
var _spin_vel := 0.0            # hit-solidity tumble (kill-zone spec §3.2): angular_kick from a smash,
                               # applied to _body while stunned, decays over the hitstun window.
var _smash_cd := 0.0
var _shove_cd := 0.0           # rate-limits the mutual body-check push (spec §2.3)
var _dead := false
var _flash_timer := 0.0
var _squash_timer := 0.0
var _spawn_protect := 0.0      # brief post-respawn invulnerability (anti spawn-smash)
var _deform_cd := 0.0          # throttles the cosmetic surface squash (not the bounce itself)
const SPAWN_PROTECT_TIME := 1.3

# powerup state (docs/specs/v1_powerups.md) — set/cleared by PowerupSystem.
var held_powerup := ""       # one held slot (spec §2)
var active_powerup := ""     # QA hook (spec §2): id of the running timed effect
var powerup_time_left := 0.0 # QA hook: seconds left on active_powerup
var fuel_locked := false     # Unlimited Boost: fuel pinned at max
var invincible := false      # Star: zero impulse/hitstun from players
var contact_launch := false  # Star: any body contact launches the other player
var counter_active := false  # Counter Shield: live parry window
var bounce_mult := 1.0       # Mega Bounce
var rainbow := false         # Star telegraphy: rainbow hue-cycle tint
var silhouette := false      # Black Hole telegraphy: silhouette-dark body
var channel_broken := false  # Black Hole: smashed mid-channel (cancelled, no fuel refill)
var speed_mult := 1.0        # per-match modifier (e.g. Double-Speed Boost)
var slow_factor := 1.0       # Slow-Mo powerup (deferred; others slowed)
var wings_flaps := 0         # Wings powerup (deferred; flap count remaining)
var _channel_timer := 0.0    # Black Hole channel
var _pulled := 0.0           # being pulled by a black hole right now (drift auto-brake off)
var _aim_active := false     # stick past deadzone this frame (Ring of Fire launch direction)
var _super_recent := 0.0     # super_active window: just fired a super (smash license, spec §2.1;
                             # also the deliberate-attack flag vs Black Hole channelers)
var _stunned_by = null       # who put me in the CURRENT hitstun (Player or null). Pairwise smash
                             # immunity: my stunned flying body is a weapon against everyone EXCEPT
                             # my stunner (never a free counter-smash back at them), and THEY get
                             # the kill credit for anyone my body hits. Cleared when hitstun ends.
var _boosting_now := false
# --- un-charged super boost v2 (lethality spec §1): press = AIM hover, release/2s = full blast ---
var _sb_aiming := false      # in the AIM state right now
var _sb_aim_t := 0.0         # seconds spent aiming (auto-fire at Tuning.super_aim_max)
var _sb_aim_dir := Vector2.UP  # last-stick aim during THIS aim window (never steered = straight up)
var _sb_lockout := 0.0       # refire lockout countdown (buffer-spam guard)
var _sb_buffer := 0.0        # buffered super press during hitstun (fires aim on first free frame)
var _sb_was_held := false
var _boost_was_held := false
var secs_since_input := 0.0  # idle-hunt bookkeeping (spec §3.2 rule 3): reset on boost/super input,
                             # ticked by the match mode during COMBAT only
const WINGS_FLAP_IMPULSE := 540.0
var _down_angle := PI * 0.5    # local-gravity direction angle (for body orientation, P8)
var last_attacker = null       # for kill credit (P9); cleared after a couple seconds
var skin := "pink"             # character sprite color (set by the mode before add_child)
var _attacker_timer := 0.0
# --- Damage system (kill-zone recovery spec v3 §12 — replaces the compounding sting) ---
var damage_level: int = 0          # §12.1: transient reeling state 0 (healthy) / 1 / 2. Caps at 2, heals
                                   # FULLY to 0 (never partial) after dmg_heal_time with no qualifying hit.
var _dmg_heal_t: float = 0.0       # §12.1/12.5: heal countdown; a qualifying hit re-arms it to dmg_heal_time.
var _last_sting_applied := 0.0     # §8 QA feed: the fuel the last qualifying sting actually drained

func damage_launch_mult() -> float:
	# §12.3: victim's pre-hit launch multiplier (x1.0 / x1.33 / x1.66), indexed by damage_level.
	return Tuning.dmg_launch_mult[damage_level]

# --- character sprite constants (art brief: eyeballed in-game vs the 44px collider) ---
const SPRITE_BALL_FRAC := 0.66      # the round body is ~66% of the idle texture width (rest = jetpack)
const SPRITE_BALL_CENTER := Vector2(0.57, 0.51)   # ball center as a fraction of the texture
const SQUASH_SWAP_TIME := 0.12      # pink swaps to its squash pose for this long on bounce
const SHADOW_MAX_HEIGHT := 120.0    # contact shadow fades out above this height (art brief §3)

func is_boosting() -> bool:
	return _boosting_now

func get_aim() -> Vector2:
	return _last_aim

func is_super_aiming() -> bool:
	return _sb_aiming

func get_super_aim_dir() -> Vector2:
	return _sb_aim_dir

func is_super_active() -> bool:
	return _super_recent > 0.0

func in_hitstun() -> bool:
	return _stun_timer > 0.0

var _body: Node2D                  # body root (squash/tumble applies here)
var _skin_flip: Node2D             # facing flip (scale.x = ±1), separate from squash scale
var _sprite: Sprite2D              # character sprite (idle / squash pose)
var _idle_tex: Texture2D
var _squash_tex: Texture2D         # squash pose (pink only for now; null = scale-squash only)
var _sprite_scale := 1.0
var _using_squash := false
var _facing := 1
var _shadow: Polygon2D             # contact shadow ellipse (top_level, sits on the surface below)
var _anim_t := 0.0
var _fire: CPUParticles2D
var _smoke: CPUParticles2D
var _fire_grad_normal: Gradient        # stock orange exhaust ramp
var _fire_grad_cyan: Gradient          # Unlimited Boost: cyan afterburner (spec 3.2)
var _fire_cyan_now := false            # transition latch (lifetime writes restart the emitter)
var _arrow: Polygon2D
var _charge_ring: Line2D
var _ring_bg: Line2D               # dark backing ring under the fuse ring (contrast on any bg, §1.4)
var _hit_area: Area2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = LAYER_PLAYERS
	collision_mask = MASK_SURFACES
	add_to_group("impulsable")   # explosions can fling players (INV-3)
	add_to_group("players")      # powerups (slow-mo / black hole) act on the group
	fuel = Tuning.fuel_max

	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	cs.shape = circle
	add_child(cs)

	# Contact shadow: soft ellipse on the surface below (top_level so it never rotates/squashes
	# with the body). Added first so everything else draws over it. Art brief §3 — do not skip.
	_shadow = Polygon2D.new()
	_shadow.top_level = true
	var spts := PackedVector2Array()
	for i in range(24):
		var a := TAU * (float(i) / 24.0)
		spts.append(Vector2(cos(a) * BODY_RADIUS * 1.35, sin(a) * BODY_RADIUS * 0.36))
	_shadow.polygon = spts
	_shadow.color = Color(0.118, 0.169, 0.251, 0.30)   # #1E2B40
	_shadow.visible = false
	add_child(_shadow)

	# Jetpack exhaust: smoke behind, fire in front. Both world-space so they trail behind movement.
	# (The jetpack itself is baked into the character sprite.)
	_smoke = _make_exhaust(false)
	add_child(_smoke)
	_fire = _make_exhaust(true)
	add_child(_fire)
	_fire_grad_normal = _fire.color_ramp
	_fire_grad_cyan = Gradient.new()
	_fire_grad_cyan.set_color(0, Color(0.6, 1.0, 1.0, 1.0))
	_fire_grad_cyan.add_point(0.3, Color(0.05, 0.65, 1.0, 1.0))
	_fire_grad_cyan.set_color(1, Color(0.0, 0.2, 0.9, 0.0))

	# Character sprite: per-skin idle texture; pink also carries a squash pose for bounces.
	# Scaled so the round body reads ~2.2x the collider radius wide (art bleeds past physics —
	# toys are fluffy). Facing lives on its own node so squash scale and flip never fight.
	_body = Node2D.new()
	add_child(_body)
	_skin_flip = Node2D.new()
	_body.add_child(_skin_flip)
	var idle_path := "res://assets/characters/bouncer_%s_idle.png" % skin
	if not ResourceLoader.exists(idle_path):
		push_warning("Player: missing sprite " + idle_path + " — falling back to pink")
		idle_path = "res://assets/characters/bouncer_pink_idle.png"
	_idle_tex = load(idle_path)
	var squash_path := "res://assets/characters/bouncer_%s_squash.png" % skin
	if ResourceLoader.exists(squash_path):
		_squash_tex = load(squash_path)
	_sprite = Sprite2D.new()
	_sprite_scale = (2.2 * BODY_RADIUS) / (_idle_tex.get_width() * SPRITE_BALL_FRAC)
	_apply_idle_sprite()
	_skin_flip.add_child(_sprite)

	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([Vector2(0, -8), Vector2(0, 8), Vector2(22, 0)])
	_arrow.color = Color(1, 1, 1, 0.85)
	_arrow.visible = false
	add_child(_arrow)
	# Fuse ring readability (§1.4 + QA fix): dark backing ring first (draws under), bright fuse
	# ring on top. Widths are set per-frame in SCREEN px (divided by camera zoom) so the aim
	# state reads from across the couch at any gameplay zoom.
	_ring_bg = Line2D.new()
	_ring_bg.default_color = Color(0.07, 0.07, 0.12, 0.85)
	_ring_bg.visible = false
	_ring_bg.z_index = 4
	add_child(_ring_bg)
	_charge_ring = Line2D.new()
	_charge_ring.width = 7.0
	_charge_ring.visible = false
	_charge_ring.z_index = 5
	add_child(_charge_ring)

	# Smash-detection area: detects other player bodies (layer 1).
	_hit_area = Area2D.new()
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = LAYER_PLAYERS | (1 << 1)   # detect players + props
	var hcs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = BODY_RADIUS + 6.0
	hcs.shape = hc
	_hit_area.add_child(hcs)
	add_child(_hit_area)

func _apply_idle_sprite() -> void:
	_sprite.texture = _idle_tex
	_sprite.scale = Vector2.ONE * _sprite_scale
	# offset so the BALL (not the texture rect) is centered on the collider
	_sprite.offset = Vector2((0.5 - SPRITE_BALL_CENTER.x) * _idle_tex.get_width(),
		(0.5 - SPRITE_BALL_CENTER.y) * _idle_tex.get_height())

func _apply_squash_sprite() -> void:
	_sprite.texture = _squash_tex
	# match the idle pose's world width; sit the flattened blob low, against the surface
	var k := (_idle_tex.get_width() * _sprite_scale) / float(_squash_tex.get_width())
	_sprite.scale = Vector2.ONE * k
	var world_h := _squash_tex.get_height() * k
	_sprite.offset = Vector2(-0.05 * _squash_tex.get_width(),
		(BODY_RADIUS - world_h * 0.5) / k)

func _make_exhaust(is_fire: bool) -> CPUParticles2D:
	# Textureless in v0 (default square particles, scaled small) — texture wiring returns with art.
	var p := CPUParticles2D.new()
	p.emitting = false
	p.local_coords = false           # particles stay in world → real trailing exhaust
	p.spread = 16.0
	p.direction = Vector2.DOWN       # updated each frame to -aim
	p.gravity = Vector2.ZERO
	var grad := Gradient.new()
	var grow := Curve.new()
	if is_fire:
		p.amount = 30
		p.lifetime = 0.32
		p.initial_velocity_min = 260.0
		p.initial_velocity_max = 520.0
		p.damping_min = 300.0
		p.damping_max = 600.0
		p.scale_amount_min = 2.2
		p.scale_amount_max = 4.0
		grad.set_color(0, Color(1.0, 1.0, 0.75, 1.0))
		grad.add_point(0.35, Color(1.0, 0.72, 0.15, 1.0))
		grad.set_color(1, Color(0.95, 0.25, 0.05, 0.0))
		grow.add_point(Vector2(0.0, 1.0)); grow.add_point(Vector2(1.0, 0.15))   # fire shrinks
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD       # glowing fire
		p.material = m
	else:
		p.amount = 18
		p.lifetime = 0.7
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 240.0
		p.damping_min = 120.0
		p.damping_max = 260.0
		p.scale_amount_min = 2.8
		p.scale_amount_max = 5.2
		grad.set_color(0, Color(0.7, 0.7, 0.72, 0.45))
		grad.set_color(1, Color(0.35, 0.35, 0.38, 0.0))
		grow.add_point(Vector2(0.0, 0.5)); grow.add_point(Vector2(1.0, 1.0))    # smoke billows
	p.color_ramp = grad
	p.scale_amount_curve = grow
	return p

func set_provider(p) -> void:
	provider = p

func get_fuel_ratio() -> float:
	return clampf(fuel / Tuning.fuel_max, 0.0, 1.0)

func is_dead() -> bool:
	return _dead

var frozen := false       # suspended: intro pop-in, countdown, sudden-death revive, KO freeze

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if frozen:
		velocity = Vector2.ZERO
		if _fire: _fire.emitting = false
		if _smoke: _smoke.emitting = false
		_frozen_preaim()
		return
	_smash_cd = maxf(0.0, _smash_cd - delta)
	_shove_cd = maxf(0.0, _shove_cd - delta)
	_super_recent = maxf(0.0, _super_recent - delta)
	_pulled = maxf(0.0, _pulled - delta)
	_spawn_protect = maxf(0.0, _spawn_protect - delta)
	_deform_cd = maxf(0.0, _deform_cd - delta)
	_attacker_timer = maxf(0.0, _attacker_timer - delta)
	if _attacker_timer <= 0.0:
		last_attacker = null
	# Damage heal (v3 §12.5): a damaged player heals FULLY to Lv0 after dmg_heal_time with no
	# qualifying hit. No partial step-down (never 2->1) — it drops straight to 0. Any qualifying
	# smash re-arms the full timer in receive_smash.
	if damage_level > 0:
		_dmg_heal_t = maxf(0.0, _dmg_heal_t - delta)
		if _dmg_heal_t <= 0.0:
			damage_level = 0

	# Black Hole channel (spec 3.6): hover frozen (velocity zeroed, gravity off, input locked)
	# and pull all other players in-zone at a CONSTANT accel — readable, not 1/r^2. The pull is
	# weaker than normal_boost_accel, so a fueled player fights out by burning their tank.
	if _channel_timer > 0.0:
		_channel_timer -= delta
		velocity = Vector2.ZERO
		for o in get_tree().get_nodes_in_group("players"):
			if o == self or not is_instance_valid(o) or o.is_dead():
				continue
			var pull: Vector2 = global_position - o.global_position
			if pull.length() < Tuning.pu_black_hole_radius:
				o.velocity += pull.normalized() * Tuning.pu_black_hole_pull * delta
				o._pulled = 0.1   # dragged bodies don't auto-brake (drift) — boost still fights out
		_update_visual(_last_aim, false, false, false, delta)
		return

	_sb_lockout = maxf(0.0, _sb_lockout - delta)
	_sb_buffer = maxf(0.0, _sb_buffer - delta)
	var intent: InputIntent = provider.poll() if provider != null else InputIntent.new()
	var stunned := _stun_timer > 0.0
	var just_activated := intent.use_powerup
	if stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_stunned_by = null   # hitstun over: pairwise smash immunity / chain credit end with it
			_spin_vel = 0.0      # tumble ends with the stun (kill-zone spec §3.2)
		# Buffered super press during hitstun (spec §1 edge case): remember it for input_buffer
		# so it fires the AIM state on the first free frame — the recovery gamble input.
		# (_sb_was_held reads false through a stun — the zeroed intent below keeps it false —
		# so a held button re-buffers every frame and press-edges fire on the first free frame.)
		if intent.super_hold and not _sb_was_held:
			_sb_buffer = Tuning.input_buffer
		intent = InputIntent.new()   # no control while stunned (FEEL §4.6)
	elif intent.use_powerup:
		PowerupSystem.try_use(self)   # never during hitstun (intent zeroed above) or dead (spec §2)
	if intent.boost or intent.super_hold:
		secs_since_input = 0.0       # idle-hunt tracking (spec §3.2 rule 3)

	var g := GravityField.get_gravity_at(global_position)
	_down_angle = g.angle()

	# Default thrust is straight UP (jetpack nozzle points down) whenever the stick is centered, so
	# holding boost with no direction always lifts you straight up — easy recovery.
	var aiming := intent.aim.length() > 0.001
	var aim_dir := intent.aim.normalized() if aiming else Vector2.UP
	_aim_active = aiming
	if aiming:
		_last_aim = aim_dir

	# --- Un-charged super boost (lethality spec §1): press = AIM, release / 2s cap = full blast ---
	var sh: bool = intent.super_hold
	# Chain buffer (QA fix): a super press/hold while blocked by the refire lockout — or by the
	# empty tank right after firing — is never eaten. It re-buffers every held frame (mirroring
	# the hitstun buffer above), so the next AIM starts automatically on the first legal frame:
	# fast super->bounce->super chains don't require a frame-perfect release + re-press.
	if sh and not _sb_aiming and (_sb_lockout > 0.0 or fuel < Tuning.super_boost_min_fuel):
		_sb_buffer = Tuning.input_buffer
	var want_aim: bool = (sh and not _sb_was_held) or (_sb_buffer > 0.0 and not stunned)
	if want_aim and not _sb_aiming and _sb_lockout <= 0.0 and _channel_timer <= 0.0 \
			and fuel >= Tuning.super_boost_min_fuel:
		_sb_aiming = true
		_sb_aim_t = 0.0
		_sb_aim_dir = aim_dir if aiming else Vector2.UP   # never steered = straight up (the funny default)
		_sb_buffer = 0.0
		velocity *= Tuning.super_aim_velocity_keep   # NOT a brake (§1.3) — decay below is honest
	if _sb_aiming:
		_sb_aim_t += delta
		if aiming:
			_sb_aim_dir = aim_dir   # the stick steers the aim arrow
		# proportional decay toward a hover; no thrust, no drift, no fuel drain while aiming
		velocity *= maxf(0.0, 1.0 - Tuning.super_aim_damp * delta)
		if (not sh) or _sb_aim_t >= Tuning.super_aim_max:
			_fire_super(_sb_aim_t >= Tuning.super_aim_max)
	_sb_was_held = sh

	# gravity — floaty while aiming (§1.1), full otherwise
	velocity += g * (Tuning.super_aim_gravity if _sb_aiming else 1.0) * delta

	var boosting := intent.boost and fuel > 0.0 and not _sb_aiming   # no normal thrust while aiming
	_boosting_now = boosting
	# Starting a fresh boost cuts momentum, so a tap of boost lets you reclaim control of your path.
	if boosting and not _boost_was_held:
		velocity *= Tuning.boost_enter_keep
	_boost_was_held = boosting
	if boosting:
		var mult := Tuning.supercharge_thrust_mult if _supercharge_timer > 0.0 else 1.0
		# Sustained thrust has a TERMINAL speed (FEEL §3.2). Only push until the velocity component
		# along the aim reaches that cap — so holding boost can't ramp you to the global ceiling.
		# Bounces and super-boost are exempt (they set velocity directly and can exceed it).
		var thrust_cap := Tuning.normal_boost_max_speed * mult * speed_mult
		var along := velocity.dot(aim_dir)
		if along < thrust_cap:
			var add := Tuning.normal_boost_accel * mult * speed_mult * delta
			add = minf(add, thrust_cap - along)   # don't overshoot the terminal speed
			velocity += aim_dir * add
		if not fuel_locked:
			fuel = maxf(0.0, fuel - Tuning.normal_boost_drain() * delta)
	elif not _sb_aiming and _pulled <= 0.0:
		# (skipped while black-hole-pulled: the auto-brake toward vx=0 would fight the pull)
		var target_x := Tuning.air_drift_max_speed * clampf(intent.aim.x, -1.0, 1.0)
		velocity.x = move_toward(velocity.x, target_x, Tuning.air_drift_accel * delta)

	# Wings: flap to fly (powerup) — active airborne, INV-11 OK
	if wings_flaps > 0 and intent.flap and not just_activated:
		var fdir := aim_dir if aiming else Vector2.UP
		velocity += fdir * WINGS_FLAP_IMPULSE
		wings_flaps -= 1

	_supercharge_timer = maxf(0.0, _supercharge_timer - delta)

	# Global safety cap: prevents elastic-wall+boost runaway and high-speed escapes through geometry.
	velocity = velocity.limit_length(Tuning.max_speed)

	var pre_v := velocity
	if slow_factor < 1.0:
		velocity = pre_v * slow_factor   # Slow-Mo: move slower, keep real velocity for bounce math
	move_and_slide()
	if slow_factor < 1.0:
		velocity = pre_v
	_resolve_bounces(g, intent.boost, intent.aim)
	_handle_smashes()
	# Re-cap after bounce/smash resolution (a bounce adds launch speed on top of tangential).
	velocity = velocity.limit_length(Tuning.max_speed)
	_update_visual(aim_dir, boosting, aiming, stunned, delta)

## Fire the super (lethality spec §1.1): full power at ANY fuel >= min — the tank level never
## scales the launch. Dumps the whole tank (every super chain routes through a bounce), opens the
## super_active smash-license window, and starts the refire lockout.
func _fire_super(auto_fired: bool) -> void:
	var fuel_at_fire := fuel
	var aim_time := _sb_aim_t
	velocity += _sb_aim_dir * Tuning.super_boost_impulse_full * speed_mult
	fuel = 0.0                    # drain-all identity (§1.2); Unlimited Boost refills via fuel_locked
	_sb_aiming = false
	_sb_aim_t = 0.0
	_super_recent = Tuning.super_active_time
	_sb_lockout = Tuning.pu_unlimited_super_lockout if fuel_locked else Tuning.super_refire_lockout
	EventBus.super_boosted.emit(self)
	EventBus.super_fired.emit(self, fuel_at_fire, aim_time, auto_fired)

## Suspension pre-aim (spec §1 COUNTDOWN): while frozen there is no physics, thrust, drift or fuel
## drain — but the stick still rotates the jetpack arrow so you can pre-aim the opening bounce.
## Deliberately never touches _body.scale: the intro pop-in / win-pop tweens own it while frozen.
func _frozen_preaim() -> void:
	var intent: InputIntent = provider.poll() if provider != null else InputIntent.new()
	var aiming := intent.aim.length() > 0.001
	if aiming:
		_last_aim = intent.aim.normalized()
		if absf(_last_aim.x) > 0.15:
			_facing = 1 if _last_aim.x > 0.0 else -1
			if _skin_flip:
				_skin_flip.scale.x = float(_facing)
	if _arrow:
		_arrow.visible = aiming
		if aiming:
			_arrow.color = Color(1, 1, 1, 0.85)
			_arrow.scale = Vector2.ONE
			_arrow.position = _last_aim * 70.0
			_arrow.rotation = _last_aim.angle()
	if _charge_ring:
		_charge_ring.visible = false
	if _ring_bg:
		_ring_bg.visible = false

## ROUND_INTRO pop-in: scale 0 -> 1.15 -> 1.0 (FEEL §5.3 energy). Runs while frozen, so nothing
## else writes _body.scale until the countdown unlocks.
func play_pop_in() -> void:
	if _body == null:
		return
	_body.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector2(1.15, 1.15), 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "scale", Vector2.ONE, 0.08)

## MATCH_END winner celebration: the win pop (scale 1.3 -> 1.0, twice — FEEL §5.3).
func play_win_pop() -> void:
	if _body == null:
		return
	var tw := create_tween()
	for i in range(2):
		tw.tween_property(_body, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_body, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _resolve_bounces(g: Vector2, boost_held: bool, aim_in: Vector2 = Vector2.ZERO) -> void:
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider = col.get_collider()
		if collider == null:
			continue
		# All level surfaces are axis-aligned rectangles, so snap the contact normal to its dominant
		# axis. This stops glancing edge/corner hits from launching you diagonally — a flat floor
		# always bounces you straight up (keeping your existing horizontal momentum).
		var n := _axis_snap(col.get_normal())
		if collider.has_meta("bounce_tier_height"):
			var tier_h: float = collider.get_meta("bounce_tier_height") * bounce_mult
			velocity = BounceResolver.resolve(velocity, n, tier_h, g.length(), boost_held)
			# Directional influence: holding a direction along the surface as you bounce nudges the
			# launch that way, so you can steer your arc (e.g. press right on a floor -> up-and-right).
			var tangent := Vector2(-n.y, n.x)
			velocity += tangent * aim_in.dot(tangent) * Tuning.bounce_di
			var launch_speed: float = maxf(0.0, velocity.dot(n))
			_squash_surface(collider, n, col.get_position())
			EventBus.surface_bounced.emit(collider, self, n, col.get_position())   # tier mat FX
			_on_bounced(boost_held, Tuning.fuel_per_bounce * sqrt(tier_h / Tuning.bounce_height_trampoline), launch_speed, col.get_position())
			return
		elif collider.has_meta("bumper"):
			velocity = BounceResolver.resolve_bumper(velocity, n)
			var rebound_speed: float = maxf(0.0, velocity.dot(n))
			_squash_surface(collider, n, col.get_position())
			EventBus.surface_bounced.emit(collider, self, n, col.get_position())
			# Bumpers refund fuel too (QA fix): a dry rebound made the spec's miss -> wall-rebound
			# -> return-shot chain impossible. Same refuel/telegraphy path as tier bounces.
			_on_bounced(boost_held, Tuning.fuel_per_bumper, rebound_speed, col.get_position())
			return

## Trampoline "give". For squishy pads, only the tiles near the contact dent in (with a falloff),
## so it ripples locally instead of the whole platform moving. Walls just do a whole-visual squash.
## Cosmetic only — never touches the collision shape. (v0: no per-tile visuals yet, so everything
## takes the whole-visual squash path via the "vis" meta.)
func _squash_surface(collider, n: Vector2, contact: Vector2) -> void:
	if _deform_cd > 0.0:
		return            # throttle: avoids a flood of tweens while resting on a surface
	_deform_cd = 0.14
	if collider.has_meta("tiles"):
		var tiles: Array = collider.get_meta("tiles")
		var radius := 170.0
		var flat_y := absf(n.y) >= absf(n.x)
		for t in tiles:
			if not is_instance_valid(t):
				continue
			var s: float = 1.0 - clampf(t.global_position.distance_to(contact) / radius, 0.0, 1.0)
			if s <= 0.01:
				continue
			var base: Vector2 = t.get_meta("base_scale")
			var home: Vector2 = t.get_meta("home")
			var sq := Vector2(1.0 + 0.22 * s, 1.0 - 0.34 * s) if flat_y else Vector2(1.0 - 0.34 * s, 1.0 + 0.22 * s)
			t.scale = base * sq
			t.position = home + (-n) * 18.0 * s
			var tw: Tween = t.create_tween()
			tw.set_parallel(true)
			tw.tween_property(t, "scale", base, 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(t, "position", home, 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		return
	if collider.has_meta("vis"):
		var vis = collider.get_meta("vis")
		if not is_instance_valid(vis):
			return
		var sq := Vector2(1.06, 0.9) if absf(n.y) >= absf(n.x) else Vector2(0.9, 1.06)
		vis.position = -n * 12.0
		vis.scale = sq
		var tw: Tween = vis.create_tween()
		tw.set_parallel(true)
		tw.tween_property(vis, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(vis, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _axis_snap(n: Vector2) -> Vector2:
	if absf(n.x) >= absf(n.y):
		return Vector2(signf(n.x), 0.0)
	return Vector2(0.0, signf(n.y))

func _on_bounced(boost_held: bool, fuel_refund: float = Tuning.fuel_per_bounce, launch_speed: float = 0.0, contact: Vector2 = global_position) -> void:
	# v2.1 ruling (spec §2.3a): hitstun ends by TIME, never by touching a surface.
	# If opponent-inflicted hitstun is active on contact, this is a DRY REFLECT — the physical
	# bounce/ricochet still resolves upstream (BounceResolver), squash FX and the juicy-bounce
	# event still fire, but there is NO fuel refund and hitstun is NOT cleared here (it keeps
	# ticking down on its own clock in _physics_process). Neutral/self-triggered contact (includes
	# the owner's wall-return shot, which by construction never involves hitstun) is unchanged.
	if _stun_timer <= 0.0:
		fuel = minf(Tuning.fuel_max, fuel + fuel_refund)
		if boost_held:
			_supercharge_timer = Tuning.supercharge_window
		_stun_timer = 0.0
		_stunned_by = null
	_squash_timer = 0.12
	EventBus.bounced.emit(self)
	EventBus.bounced_juicy.emit(self, launch_speed, contact)

func _handle_smashes() -> void:
	var my_speed := velocity.length()
	for b in _hit_area.get_overlapping_bodies():
		if b == self or not is_instance_valid(b):
			continue
		var is_player: bool = b is Player
		if is_player and b.is_dead():
			continue
		# Counter Shield (spec 3.4): ANY body contact during the live window counter-launches
		# the toucher — including Star holders (the timed parry is the one answer to Star).
		if counter_active and is_player and _smash_cd <= 0.0 and b._spawn_protect <= 0.0:
			var cdir := (b.global_position - global_position).normalized()
			if cdir == Vector2.ZERO:
				cdir = Vector2.UP
			if b.counter_active:
				# two live shields: comedy BOING — both knocked apart, no hitstun
				b.velocity = cdir * 700.0
				velocity = -cdir * 700.0
			else:
				b.receive_counter_launch(cdir * Tuning.pu_counter_reflect_impulse, self)
			_smash_cd = 0.3
			return
		# Star (contact_launch, spec 3.3): ANY contact flings the other player, regardless of speed.
		if contact_launch and is_player and _smash_cd <= 0.0:
			if b.contact_launch:
				_soft_separate(b)   # two Stars: mutual clang, no impulse to either (spec 3.3)
				continue
			var imp := (b.global_position - global_position).normalized() * Tuning.pu_star_contact_impulse
			b.receive_smash(imp, self)
			EventBus.smashed.emit(self, b, imp)
			_smash_cd = 0.3
			return
		if is_player:
			# Black Hole (spec 3.6/P6): bodies DRAGGED into a channeler crash and stack — they are
			# not attacks. Only deliberate propulsion (boosting / a fresh super) or storm balls
			# break the channel; ball hits and eval'd smashes route via receive_smash directly.
			if b.is_channeling() and not (_boosting_now or _super_recent > 0.0):
				_soft_separate(b)
				continue
			# Two-tier contact (lethality spec §2.1). SMASH iff:
			#   (I am a fired super OR a flying stunned body)   -- the smash license
			#   AND relative closing speed >= smash_impact_min   -- anti-graze safety gate
			#   AND I am the faster body                         -- tiebreak, no double-apply
			# Everything else is a SHOVE (§2.3): honest physics, no hitstun.
			# Pairwise immunity (QA critical fix): a stunned flying body is a weapon against
			# everyone EXCEPT its own stunner. Without this, every landed super was suicide —
			# the victim exits at cap while the attacker keeps smash_self_retain (10%), so the
			# victim's own out-flying body counter-smashed the attacker the very next frame.
			# B smashing C still works (Pillar 3 chains protected).
			var eligible: bool = _super_recent > 0.0 or (_stun_timer > 0.0 and b != _stunned_by)
			var rel: float = (velocity - b.velocity).length()
			if eligible and _smash_cd <= 0.0 and rel >= Tuning.smash_impact_min and (my_speed > b.velocity.length() or (is_equal_approx(my_speed, b.velocity.length()) and get_instance_id() < b.get_instance_id())):
				# Hit solidity (kill-zone recovery spec §3.1/§3.2): both are circle colliders, so the
				# line-of-centers IS the contact normal. s = how head-on the hit is (1=center, 0=graze).
				# Launch scales with s; the momentum not spent launching becomes comedic spin.
				var n := (b.global_position - global_position).normalized()
				var vdir := velocity.normalized()
				var s: float = clampf(vdir.dot(n), 0.0, 1.0)
				var raw_impulse: float = Tuning.smash_impulse_base + my_speed * Tuning.smash_impulse_from_attacker  # physical ceiling
				var launch_scale: float = Tuning.smash_launch_floor + (1.0 - Tuning.smash_launch_floor) * s  # baseline..cap (v2, no gate)
				var impulse_mag: float = minf(raw_impulse, Tuning.smash_impulse_max * launch_scale)   # baseline -> cap, never above physical
				# v3 §12.3: read the victim's PRE-HIT damage level (before receive_smash escalates it) and
				# multiply the launch AFTER the smash_impulse_max clamp, BEFORE the max_speed limit in
				# receive_smash. Lv0 x1.0 / Lv1 x1.33 / Lv2 x1.66 -> a Lv2 center hit (2200*1.66=3652)
				# is then clamped to max_speed (3000) by receive_smash. The ONLY sanctioned exceedance of 2200.
				var victim_dmg_level: int = b.damage_level
				impulse_mag *= b.damage_launch_mult()
				var impulse := vdir * impulse_mag   # launch direction unchanged (along attacker travel)
				var angular_kick: float = Tuning.smash_spin_max * (1.0 - s) * signf(vdir.cross(n))
				b.receive_smash(impulse, self, s, angular_kick)
				# Cancel most of your own momentum: you stop on impact rather than riding them off the edge.
				velocity *= Tuning.smash_self_retain
				# Chain-body credit (QA fix): when a stunned flying BODY smashes someone, the
				# kill/score/round_stats credit belongs to the LAUNCHER who smashed the body —
				# an uncontrolled projectile can't farm points. (Pairwise immunity in
				# receive_smash still keys off the physical body: b's stunner is `self`.)
				var attacker_for_credit: Player = self
				if _super_recent <= 0.0 and _stun_timer > 0.0 \
						and _stunned_by != null and is_instance_valid(_stunned_by):
					attacker_for_credit = _stunned_by
					b.credit_attacker(attacker_for_credit)
				EventBus.smashed.emit(attacker_for_credit, b, impulse)
				# Hit-solidity QA feed (kill-zone spec §8): one entry per qualifying smash.
				# launch_speed read AFTER receive_smash (victim velocity already includes the impulse).
				if launch_scale > 0.0 or impulse_mag >= Tuning.smash_sting_min_impulse:
					EventBus.smash_landed.emit(attacker_for_credit, b, {
						"solidity": s,
						"launch_scale": launch_scale,
						"launch_speed": b.velocity.length(),
						"angle_deg": rad_to_deg(impulse.angle()),
						"by_super": _super_recent > 0.0,
						"victim_fuel_after": b.fuel,
						"starved": b.fuel < Tuning.super_boost_min_fuel,
						"spin": angular_kick,
						"victim_damage_level": victim_dmg_level,     # v3 §8/§12: victim's PRE-HIT damage level (0/1/2)
						"launch_mult": Tuning.dmg_launch_mult[victim_dmg_level],  # v3: the 1.0/1.33/1.66 applied
						"sting_applied": b._last_sting_applied,      # §8: fuel actually drained by the sting
					})
				_smash_cd = 0.3
				return
			else:
				_soft_separate(b)
		else:
			# props (ball / crate / support): plain speed gate — a fast heavy ball doesn't need a
			# super license, it IS one (spec §2.1)
			if _smash_cd <= 0.0 and my_speed >= Tuning.smash_impact_min and b.has_method("receive_smash"):
				# Hit solidity (kill-zone recovery spec §3.1/§3.2) — same treatment in the prop branch.
				var n := (b.global_position - global_position).normalized()
				var vdir := velocity.normalized()
				var s: float = clampf(vdir.dot(n), 0.0, 1.0)
				var raw_impulse: float = Tuning.smash_impulse_base + my_speed * Tuning.smash_impulse_from_attacker  # physical ceiling
				var launch_scale: float = Tuning.smash_launch_floor + (1.0 - Tuning.smash_launch_floor) * s  # baseline..cap (v2, no gate)
				var impulse_mag: float = minf(raw_impulse, Tuning.smash_impulse_max * launch_scale)   # baseline -> cap, never above physical
				# v3 §12.3: launch multiplier by victim's pre-hit damage level. Props have no damage_level
				# (never escalate), so this is x1.0 for them; guarded so a future damageable prop composes.
				if b.has_method("damage_launch_mult"):
					impulse_mag *= b.damage_launch_mult()
				var impulse := vdir * impulse_mag
				var angular_kick: float = Tuning.smash_spin_max * (1.0 - s) * signf(vdir.cross(n))
				b.receive_smash(impulse, self, s, angular_kick)
				_smash_cd = 0.3
				return

## The SHOVE (lethality spec §2.3): momentum-scaled body-check along the separation axis.
## Visible, positional, NO hitstun/sting — the victim keeps full control and can boost back.
## Applied to self each frame it triggers; the other player mirrors it in their own frame, so the
## push is mutual. Rate-limited (_shove_cd) so an overlap doesn't machine-gun kicks.
func _soft_separate(other) -> void:
	if _shove_cd > 0.0:
		return
	var d: Vector2 = global_position - other.global_position
	var dist: float = d.length()
	if dist <= 0.01:
		return
	var rel: float = (velocity - other.velocity).length()
	var push := clampf(rel * Tuning.soft_bump_scale, Tuning.soft_bump_min, Tuning.soft_bump_max)
	velocity += (d / dist) * push
	_shove_cd = 0.3
	# Body-check credit (§2.3): a shove that carries someone over the line must credit the
	# checker, not read as a suicide. Standard kill_credit_window via credit_attacker.
	if rel >= Tuning.shove_credit_min_rel and other is Player \
			and other._spawn_protect <= 0.0 and not other.invincible:
		other.credit_attacker(self)

func receive_smash(impulse: Vector2, attacker, s: float = 1.0, angular_kick: float = 0.0) -> void:
	if _dead:
		return
	if counter_active:
		# Counter Shield (spec 3.4): the parry — the attacker is counter-launched instead,
		# the holder takes ZERO impulse/stun. Beats Star (bypasses invincibility).
		if attacker != null and is_instance_valid(attacker) and attacker is Player and not attacker.is_dead():
			var dir: Vector2 = (attacker.global_position - global_position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.UP
			if attacker.counter_active:
				# two live shields colliding: both knocked apart, no hitstun (comedy BOING)
				attacker.velocity = dir * 700.0
				velocity = -dir * 700.0
			else:
				attacker.receive_counter_launch(dir * Tuning.pu_counter_reflect_impulse, self)
		return
	if invincible or _spawn_protect > 0.0:
		return   # Star / fresh-spawn: take zero knockback, zero hitstun, zero sting
	if _channel_timer > 0.0:
		# Black Hole: any hit during the channel cancels it — no fuel refill (spec 3.6)
		_channel_timer = 0.0
		channel_broken = true
	# Smash sting (lethality spec §2.2): qualifying hits chunk the victim's tank BEFORE hitstun.
	# Dropping below super_boost_min_fuel starves the escape super — sting -> starve -> kill.
	# Kill-zone spec v2 §3.2: sting scales with SOLIDITY s (not launch_scale, whose 0.6 floor would
	# starve everyone). Gated on impulse >= smash_sting_min_impulse: a baseline graze (~1320 < 1500)
	# stings NOTHING; sting rises with s from s~=0.21 up; a dead-center hit (s=1) stings the full amount.
	# v3 §12: the ISOLATED sting (smash_sting_fuel * s) is UNCHANGED — the compounding multiplier is gone,
	# replaced by the damage system below. Grazes (below the gate) sting 0 (the glance-0 property holds).
	if impulse.length() >= Tuning.smash_sting_min_impulse and not fuel_locked:
		var sting: float = Tuning.smash_sting_fuel * s
		fuel = maxf(0.0, fuel - sting)
		_last_sting_applied = sting
	else:
		_last_sting_applied = 0.0
	# v3 §12.2: damage escalation on a QUALIFYING smash (same 1500 gate as the sting — glances don't
	# escalate). Increment damage_level (caps at 2) and re-arm the full 8s heal timer. The launch
	# multiplier was already read from the PRE-HIT level in _handle_smashes, so the hit that takes you
	# to Lv1 launches x1.0 and the hit received WHILE at Lv1 launches x1.33.
	if impulse.length() >= Tuning.smash_sting_min_impulse:
		damage_level = mini(damage_level + 1, 2)
		_dmg_heal_t = Tuning.dmg_heal_time
	# Smashed while aiming (spec §1.1): aim CANCELS, (stung) fuel retained, no super fires.
	cancel_super_aim()
	velocity = (velocity + impulse).limit_length(Tuning.max_speed)
	if attacker != null and attacker is Player:
		last_attacker = attacker
		_attacker_timer = Tuning.kill_credit_window
	# pairwise smash immunity: while THIS hitstun lasts, my flying body never smashes my stunner
	# back, and any smash my body lands is credited to them (chain launcher credit)
	_stunned_by = attacker if (attacker != null and attacker is Player) else null
	var st := Tuning.hitstun_base + impulse.length() * Tuning.hitstun_per_impulse
	_stun_timer = minf(st, Tuning.hitstun_max)
	_spin_vel = angular_kick   # kill-zone spec §3.2: the clip-spin readability signal
	_flash_timer = 0.12

## Counter Shield launch (spec 3.4): velocity REPLACED (arrive at 2800, leave at 1400) +
## standard hitstun. Bypasses Star invincibility — the one answer to the rare power.
## Kill credit goes to the shield holder (it's their attack).
func receive_counter_launch(impulse: Vector2, holder) -> void:
	if _dead or _spawn_protect > 0.0:
		return
	if _channel_timer > 0.0:
		_channel_timer = 0.0
		channel_broken = true
	# sting line applies here too — Counter reflect (1400) sits below it BY DATA (spec §2.2)
	if impulse.length() >= Tuning.smash_sting_min_impulse and not fuel_locked:
		fuel = maxf(0.0, fuel - Tuning.smash_sting_fuel)
	cancel_super_aim()   # it stuns: any hitstun-applying hit cancels an in-progress aim
	velocity = impulse.limit_length(Tuning.max_speed)
	if holder != null and holder is Player:
		last_attacker = holder
		_attacker_timer = Tuning.kill_credit_window
	_stunned_by = holder if (holder != null and holder is Player) else null   # pairwise immunity
	var st := Tuning.hitstun_base + impulse.length() * Tuning.hitstun_per_impulse
	_stun_timer = minf(st, Tuning.hitstun_max)
	_flash_timer = 0.12
	EventBus.smashed.emit(holder, self, impulse)

## Ring of Fire kill credit (spec 3.7): a ring launch that carries someone out scores the owner.
func credit_attacker(attacker) -> void:
	if attacker != null and attacker != self and attacker is Player:
		last_attacker = attacker
		_attacker_timer = Tuning.kill_credit_window

func flash() -> void:
	_flash_timer = 0.12

func apply_impulse_vector(v: Vector2) -> void:
	# Impulsable (INV-3) — explosions etc. Star is knockback-immune; a live Counter Shield
	# blocks explosion knockback on the holder (spec 3.3/3.4). Hazards still instakill.
	if _dead or invincible or counter_active:
		return
	# Explosion sting (lethality §2.2): impulse arrives with linear falloff (Forces.gd), so the
	# threshold means only near-epicenter blasts starve fuel — bombs should scare people.
	if v.length() >= Tuning.smash_sting_min_impulse and _spawn_protect <= 0.0 and not fuel_locked:
		fuel = maxf(0.0, fuel - Tuning.smash_sting_fuel)
	velocity = (velocity + v).limit_length(Tuning.max_speed)

func force_super_boost() -> void:
	# Ring of Fire (spec 3.7): instant full-power super-boost — current aim if the stick is past
	# deadzone, else current velocity direction, else straight up. Full control kept (no hitstun),
	# actual fuel untouched; any in-progress aim is consumed/replaced. Fully consistent with the
	# un-charged model: every super is full power (lethality §1.5 edge cases).
	if _dead:
		return
	cancel_super_aim()
	var dir := Vector2.UP
	if _aim_active:
		dir = _last_aim
	elif velocity.length() > 40.0:
		dir = velocity.normalized()
	velocity = dir * Tuning.super_boost_impulse_full
	_super_recent = Tuning.super_active_time   # a ring launch is a super — smash license + channel-break
	EventBus.super_boosted.emit(self)

func cancel_super_aim() -> void:
	# cancel an in-progress super AIM, fuel retained (smashed mid-aim / Black Hole / Ring of Fire)
	_sb_aiming = false
	_sb_aim_t = 0.0

func start_channel(dur: float) -> void:
	# Black Hole
	if not _dead:
		_channel_timer = dur

func is_channeling() -> bool:
	return _channel_timer > 0.0

func reset_powerup_state() -> void:
	slow_factor = 1.0
	wings_flaps = 0
	_channel_timer = 0.0
	channel_broken = false
	rainbow = false
	silhouette = false

func kill(cause: StringName, attacker = null) -> void:
	if attacker == null:
		attacker = last_attacker   # knocked into a hazard / off the map = the smasher's kill
	KillPipeline.kill(self, cause, attacker)

func mark_dead() -> void:
	_dead = true
	visible = false
	if _hit_area:
		_hit_area.monitoring = false

func respawn(pos: Vector2) -> void:
	_dead = false
	visible = true
	modulate.a = 1.0                # clear any mid-blink alpha from the previous life
	if _shadow:
		_shadow.visible = false     # top_level shadow: hide until physics places it fresh
	if _hit_area:
		_hit_area.monitoring = true
	global_position = pos
	velocity = Vector2.ZERO
	fuel = Tuning.fuel_max
	_stun_timer = 0.0
	_stunned_by = null
	_spin_vel = 0.0
	last_attacker = null            # a new life never owes kill credit to the old one
	_attacker_timer = 0.0
	damage_level = 0                # v3 §12.5: a fresh life is always healthy (no carried damage)
	_dmg_heal_t = 0.0
	_last_sting_applied = 0.0
	_sb_aiming = false
	_sb_aim_t = 0.0
	_sb_aim_dir = Vector2.UP
	_sb_lockout = 0.0
	_sb_buffer = 0.0
	_sb_was_held = false
	_boost_was_held = false
	secs_since_input = 0.0
	_spawn_protect = SPAWN_PROTECT_TIME
	# clear powerup state (PowerupSystem's death sweep also runs; this covers round respawns)
	held_powerup = ""
	active_powerup = ""
	powerup_time_left = 0.0
	fuel_locked = false
	invincible = false
	contact_launch = false
	counter_active = false
	bounce_mult = 1.0
	rainbow = false
	silhouette = false
	channel_broken = false
	slow_factor = 1.0
	wings_flaps = 0
	_channel_timer = 0.0
	if _body:
		_body.rotation = 0.0

func _update_visual(aim_dir: Vector2, boosting: bool, aiming: bool, stunned: bool, delta: float) -> void:
	# spawn-protection blink (whole creature)
	modulate.a = (0.35 + 0.65 * absf(sin(_spawn_protect * 22.0))) if _spawn_protect > 0.0 else 1.0
	_anim_t += delta
	if _body:
		if stunned:
			# Hit-solidity tumble (kill-zone spec §3.2): a solid launch barely spins (angular_kick~0,
			# fall back to the base tumble); a graze spins fast (angular_kick up to smash_spin_max).
			# Decays across the hitstun window so it reads as a settling clip, not a permanent whirl.
			if absf(_spin_vel) > 0.01:
				_body.rotation += _spin_vel * delta
				_spin_vel = move_toward(_spin_vel, 0.0, Tuning.smash_spin_max * delta / maxf(Tuning.hitstun_max, 0.01))
			else:
				_body.rotation += TUMBLE_SPEED * delta
		else:
			# orient feet toward local gravity (P8); plain down = upright
			_body.rotation = lerp_angle(_body.rotation, _down_angle - PI * 0.5, 0.25)
		# facing flips with aim (or, drifting, with velocity). Native art faces RIGHT.
		if aiming and absf(aim_dir.x) > 0.15:
			_facing = 1 if aim_dir.x > 0.0 else -1
		elif absf(velocity.x) > 60.0:
			_facing = 1 if velocity.x > 0.0 else -1
		if _skin_flip:
			_skin_flip.scale.x = float(_facing)
		# squash on bounce / stretch while rising (code-driven, FEEL §5.3 + art brief)
		var sx := 1.0
		var sy := 1.0
		# subtle grounded breathe while idle (kept under the bounce-squash multiply below)
		if not boosting and not stunned and not _sb_aiming:
			sy *= 1.0 + 0.02 * sin(_anim_t * 3.0)
		if _squash_timer > 0.0:
			_squash_timer = maxf(0.0, _squash_timer - delta)
			var t := _squash_timer / SQUASH_SWAP_TIME
			# Mega Bounce telegraphy (spec 3.1): squash 1.4x the normal deltas
			var amp := 1.4 if bounce_mult > 1.0 else 1.0
			sx *= lerpf(1.0, 1.0 + 0.25 * amp, t)
			sy *= lerpf(1.0, 1.0 - 0.25 * amp, t)
		else:
			var rise := clampf(-velocity.y / 1100.0, 0.0, 1.0)   # fast ascent = slight stretch
			sx *= lerpf(1.0, 0.9, rise)
			sy *= lerpf(1.0, 1.12, rise)
		_body.scale = Vector2(sx, sy)
		# squash-pose swap on bounce (skins with a squash texture, currently pink)
		if _sprite:
			var want_squash := _squash_timer > 0.0 and _squash_tex != null
			if want_squash != _using_squash:
				_using_squash = want_squash
				if want_squash:
					_apply_squash_sprite()
				else:
					_apply_idle_sprite()
			# hit flash (FEEL §5.2) > Star rainbow (spec 3.3) > Black Hole silhouette (spec 3.6)
			if _flash_timer > 0.0:
				_flash_timer = maxf(0.0, _flash_timer - delta)
				_sprite.self_modulate = Color(2.6, 2.6, 2.6)
			elif rainbow:
				_sprite.self_modulate = Color.from_hsv(fmod(_anim_t * 6.0, 1.0), 0.62, 1.0)  # 6 cycles/s
			elif silhouette:
				_sprite.self_modulate = Color(0.2, 0.13, 0.28)
			elif damage_level == 1:
				# v3: Lv1 reeling — gentle red throb, g 0.85<->0.55 at dmg_pulse_slow_hz. On-body, no HUD.
				var g1: float = 0.70 + 0.15 * sin(_anim_t * TAU * Tuning.dmg_pulse_slow_hz)
				_sprite.self_modulate = Color(1.0, g1, g1)
			elif damage_level == 2:
				# v3: Lv2 reeling — deeper, faster throb, g 0.75<->0.30 at dmg_pulse_fast_hz.
				var g2: float = 0.525 + 0.225 * sin(_anim_t * TAU * Tuning.dmg_pulse_fast_hz)
				_sprite.self_modulate = Color(1.0, g2, g2)
			else:
				_sprite.self_modulate = Color.WHITE
	_update_contact_shadow()
	# telegraphy (lethality §1.4): the ring is a 2s FUSE (fills toward auto-fire, yellow -> red),
	# the arrow shows the aim at full size from frame 1 (power never scales), exhaust revs up.
	var fuse := clampf(_sb_aim_t / Tuning.super_aim_max, 0.0, 1.0) if _sb_aiming else 0.0
	if _fire:
		var nozzle := -aim_dir * 44.0
		var thrust_dir := -aim_dir
		if _sb_aiming:
			# Engines revving up: smoke billows out the nozzle and a flame grows as the fuse burns,
			# telegraphing the blast. Direction is out the nozzle, opposite where you'll launch.
			_fire.emitting = true
			_smoke.emitting = true
			_fire.position = -_sb_aim_dir * 44.0
			_smoke.position = -_sb_aim_dir * 44.0
			_fire.direction = -_sb_aim_dir
			_smoke.direction = -_sb_aim_dir
			var rev := 0.4 + 0.9 * fuse
			_fire.initial_velocity_max = 300.0 * rev
			_fire.scale = Vector2(rev, rev)
			_smoke.scale = Vector2(1.0 + fuse, 1.0 + fuse)
		else:
			_fire.emitting = boosting
			_smoke.emitting = boosting
			_fire.position = nozzle
			_smoke.position = nozzle
			_fire.direction = thrust_dir
			_smoke.direction = thrust_dir
			# supercharged thrust = bigger, faster fire
			var boost_amt := 1.6 if _supercharge_timer > 0.0 else 1.0
			# Unlimited Boost (spec 3.2): flame turns cyan, doubles in size, longer afterburner —
			# the "get away from that person" read. Only touch lifetime/ramp on the TRANSITION:
			# setting CPUParticles2D.lifetime restarts emission, so a per-frame write kills the flame.
			if fuel_locked != _fire_cyan_now:
				_fire_cyan_now = fuel_locked
				_fire.color_ramp = _fire_grad_cyan if fuel_locked else _fire_grad_normal
				_fire.lifetime = 0.55 if fuel_locked else 0.32
			if fuel_locked:
				boost_amt *= 2.0
			_fire.initial_velocity_max = 520.0 * boost_amt
			_fire.scale = Vector2(boost_amt, boost_amt)
			_smoke.scale = Vector2.ONE
	if _arrow:
		var show_arrow := (aiming or _sb_aiming) and not stunned
		_arrow.visible = show_arrow
		if show_arrow:
			if _sb_aiming:
				# full size from frame 1 — the arrow shows WHERE, the ring shows WHEN (§1.4)
				_arrow.color = Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.2, 0.1), fuse)
				_arrow.scale = Vector2.ONE * 1.9
				_arrow.position = _sb_aim_dir * 165.0
				_arrow.rotation = _sb_aim_dir.angle()
			else:
				_arrow.color = Color(1, 1, 1, 0.85)
				_arrow.scale = Vector2.ONE
				_arrow.position = aim_dir * 70.0
				_arrow.rotation = aim_dir.angle()
	if _charge_ring:
		if _sb_aiming:
			# the ring fills over super_aim_max: ring appearing = a blast within 2s (§1.4).
			# Readability (QA fix): constant SCREEN-space line width (world width = screen px /
			# camera zoom), a dark backing ring for contrast, and a minimum visible arc from
			# frame 1 — at gameplay zoom (0.4-0.9) the old 7px line was ~3px on screen.
			var cam := get_viewport().get_camera_2d()
			var inv_zoom: float = (1.0 / cam.zoom.x) if (cam != null and cam.zoom.x > 0.001) else 1.0
			_charge_ring.visible = true
			_charge_ring.width = Tuning.super_ring_screen_width * inv_zoom
			var ang := maxf(fuse, Tuning.super_ring_min_arc) * TAU
			var pts := PackedVector2Array()
			for i in range(29):
				var aa := -PI * 0.5 + ang * (float(i) / 28.0)
				pts.append(Vector2(cos(aa), sin(aa)) * (BODY_RADIUS + 16.0))
			_charge_ring.points = pts
			_charge_ring.default_color = Color(1.0, 0.95, 0.25).lerp(Color(1.0, 0.16, 0.05), fuse)
			if _ring_bg:
				_ring_bg.visible = true
				_ring_bg.width = (Tuning.super_ring_screen_width + Tuning.super_ring_outline_extra) * inv_zoom
				_ring_bg.points = pts
		else:
			_charge_ring.visible = false
			if _ring_bg:
				_ring_bg.visible = false

## Soft ellipse contact shadow on the surface below (art brief §3): anchors the toy to the set and
## helps players judge landings. Fades 30%->0% across the last SHADOW_MAX_HEIGHT px of height.
func _update_contact_shadow() -> void:
	if _shadow == null:
		return
	var space := get_world_2d().direct_space_state
	var from := global_position
	var to := from + Vector2(0.0, SHADOW_MAX_HEIGHT + BODY_RADIUS + 4.0)
	var q := PhysicsRayQueryParameters2D.create(from, to, MASK_SURFACES)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		_shadow.visible = false
		return
	var height: float = maxf(0.0, (hit["position"].y - from.y) - BODY_RADIUS)
	var k := clampf(1.0 - height / SHADOW_MAX_HEIGHT, 0.0, 1.0)
	if k <= 0.02 or _dead:
		_shadow.visible = false
		return
	_shadow.visible = true
	_shadow.global_position = hit["position"] + Vector2(0.0, 3.0)
	_shadow.rotation = 0.0
	_shadow.scale = Vector2.ONE * lerpf(0.55, 1.0, k)
	_shadow.color.a = 0.30 * k
