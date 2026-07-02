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
const IMPACT_MIN := 800.0            # min RELATIVE closing speed for a body hit to count as a smash
                                     # (below this, players just softly bounce apart — no knockback)
const TUMBLE_SPEED := 9.4            # rad/s spin while stunned (~540 deg/s)

var provider
var fuel: float
var _last_aim := Vector2.UP
var _supercharge_timer := 0.0
var _stun_timer := 0.0
var _smash_cd := 0.0
var _dead := false
var _flash_timer := 0.0
var _squash_timer := 0.0
var _spawn_protect := 0.0      # brief post-respawn invulnerability (anti spawn-smash)
var _deform_cd := 0.0          # throttles the cosmetic surface squash (not the bounce itself)
const SPAWN_PROTECT_TIME := 1.3

# powerup state (P6) — set/cleared by PowerupSystem (v0: powerups not ported yet; the fields stay
# so InputBot and the smash/knockback code keep their contracts).
var held_powerup := ""
var fuel_locked := false
var invincible := false
var contact_launch := false
var counter_active := false
var bounce_mult := 1.0
var speed_mult := 1.0        # per-match modifier (e.g. Double-Speed Boost)
var slow_factor := 1.0       # Slow-Mo powerup (others slowed)
var wings_flaps := 0         # Wings powerup (flap count remaining)
var _channel_timer := 0.0    # Black Hole channel
var _boosting_now := false
var _sb_charging := false    # chargeable super-boost: currently charging
var _sb_charge := 0.0        # 0..1 charge level
var _sb_was_held := false
var _boost_was_held := false
const WINGS_FLAP_IMPULSE := 540.0
const BLACK_HOLE_PULL := 950.0
const BLACK_HOLE_RADIUS := 720.0
var _down_angle := PI * 0.5    # local-gravity direction angle (for body orientation, P8)
var last_attacker = null       # for kill credit (P9); cleared after a couple seconds
var skin := "pink"             # character sprite color (set by the mode before add_child)
var _attacker_timer := 0.0

# --- character sprite constants (art brief: eyeballed in-game vs the 44px collider) ---
const SPRITE_BALL_FRAC := 0.66      # the round body is ~66% of the idle texture width (rest = jetpack)
const SPRITE_BALL_CENTER := Vector2(0.57, 0.51)   # ball center as a fraction of the texture
const SQUASH_SWAP_TIME := 0.12      # pink swaps to its squash pose for this long on bounce
const SHADOW_MAX_HEIGHT := 120.0    # contact shadow fades out above this height (art brief §3)

func is_boosting() -> bool:
	return _boosting_now

func get_aim() -> Vector2:
	return _last_aim

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
var _arrow: Polygon2D
var _charge_ring: Line2D
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
	_spawn_protect = maxf(0.0, _spawn_protect - delta)
	_deform_cd = maxf(0.0, _deform_cd - delta)
	_attacker_timer = maxf(0.0, _attacker_timer - delta)
	if _attacker_timer <= 0.0:
		last_attacker = null

	# Black Hole channel: hover briefly and pull everyone else in (brief active state, INV-11 OK)
	if _channel_timer > 0.0:
		_channel_timer -= delta
		velocity = Vector2.ZERO
		for o in get_tree().get_nodes_in_group("players"):
			if o == self or not is_instance_valid(o) or o.is_dead():
				continue
			var pull: Vector2 = global_position - o.global_position
			if pull.length() < BLACK_HOLE_RADIUS:
				o.velocity += pull.normalized() * BLACK_HOLE_PULL * delta
		_update_visual(_last_aim, false, false, false, delta)
		return

	var intent: InputIntent = provider.poll() if provider != null else InputIntent.new()
	var stunned := _stun_timer > 0.0
	var just_activated := intent.use_powerup
	if stunned:
		_stun_timer -= delta
		intent = InputIntent.new()   # no control while stunned (FEEL §4.6)
	elif intent.use_powerup:
		pass   # v0: powerups not ported yet (PowerupSystem.try_use(self))

	var g := GravityField.get_gravity_at(global_position)
	_down_angle = g.angle()
	velocity += g * delta

	# Default thrust is straight UP (jetpack nozzle points down) whenever the stick is centered, so
	# holding boost with no direction always lifts you straight up — easy recovery.
	var aiming := intent.aim.length() > 0.001
	var aim_dir := intent.aim.normalized() if aiming else Vector2.UP
	if aiming:
		_last_aim = aim_dir

	# --- Chargeable super-boost: press to nearly freeze + aim, hold to charge, release to blast ---
	var sh: bool = intent.super_hold
	if sh and not _sb_was_held and not _sb_charging and fuel >= Tuning.super_boost_min_fuel:
		_sb_charging = true
		_sb_charge = 0.0
		velocity *= Tuning.super_charge_freeze        # near-freeze the instant you start charging
	if _sb_charging:
		if sh:
			_sb_charge = minf(1.0, _sb_charge + delta / Tuning.super_charge_time)
			# Glide while aiming: ease the speed proportionally (never to a dead stop) so you keep
			# drifting slightly as you line up the blast, instead of freezing in place.
			velocity *= maxf(0.0, 1.0 - Tuning.super_charge_glide_damp * delta)
		else:
			var frac: float = lerpf(Tuning.super_charge_min_frac, 1.0, _sb_charge)
			velocity += aim_dir * Tuning.super_boost_impulse_full * frac * clampf(fuel / Tuning.fuel_max, 0.0, 1.0) * speed_mult
			fuel = 0.0
			_sb_charging = false
			EventBus.super_boosted.emit(self)
	_sb_was_held = sh

	var boosting := intent.boost and fuel > 0.0 and not _sb_charging   # no normal thrust while charging
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
	elif not _sb_charging:
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
			_on_bounced(boost_held, tier_h, launch_speed, col.get_position())
			return
		elif collider.has_meta("bumper"):
			velocity = BounceResolver.resolve_bumper(velocity, n)
			_squash_surface(collider, n, col.get_position())
			EventBus.surface_bounced.emit(collider, self, n, col.get_position())
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

func _on_bounced(boost_held: bool, tier_height: float = Tuning.bounce_height_trampoline, launch_speed: float = 0.0, contact: Vector2 = global_position) -> void:
	fuel = minf(Tuning.fuel_max, fuel + Tuning.fuel_per_bounce * sqrt(tier_height / Tuning.bounce_height_trampoline))
	if boost_held:
		_supercharge_timer = Tuning.supercharge_window
	# Bouncing is your recovery: contacting a surface clears hitstun so you snap back to control.
	# A bounce never CAUSES the hit state — it only ever ends it.
	_stun_timer = 0.0
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
		# Star (contact_launch): ANY contact flings another player, regardless of speed.
		if contact_launch and is_player and _smash_cd <= 0.0:
			var imp := (b.global_position - global_position).normalized() * (Tuning.smash_impulse_base + 400.0)
			b.receive_smash(imp, self)
			EventBus.smashed.emit(self, b, imp)
			_smash_cd = 0.3
			return
		if is_player:
			# A real hit needs a hard CLOSING speed AND we must be the faster body (no double-apply).
			# Otherwise the two just softly bounce apart — normal contact, no knockback/hitstun.
			var rel: float = (velocity - b.velocity).length()
			if _smash_cd <= 0.0 and rel >= IMPACT_MIN and (my_speed > b.velocity.length() or (is_equal_approx(my_speed, b.velocity.length()) and get_instance_id() < b.get_instance_id())):
				var impulse := velocity.normalized() * (Tuning.smash_impulse_base + my_speed * Tuning.smash_impulse_from_attacker)
				b.receive_smash(impulse, self)
				# Cancel most of your own momentum: you stop on impact rather than riding them off the edge.
				velocity *= Tuning.smash_self_retain
				EventBus.smashed.emit(self, b, impulse)
				_smash_cd = 0.3
				return
			else:
				_soft_separate(b)
		else:
			# props (ball / crate / support): push them on a solid hit
			if _smash_cd <= 0.0 and my_speed >= IMPACT_MIN and b.has_method("receive_smash"):
				var impulse := velocity.normalized() * (Tuning.smash_impulse_base + my_speed * Tuning.smash_impulse_from_attacker)
				b.receive_smash(impulse, self)
				_smash_cd = 0.3
				return

## Gentle mutual push so overlapping players slide apart instead of registering as hits.
## Applied only to self each frame; the other player mirrors it, so separation is smooth.
func _soft_separate(other) -> void:
	var d: Vector2 = global_position - other.global_position
	var dist: float = d.length()
	var min_d := BODY_RADIUS * 2.0
	if dist > 0.01 and dist < min_d:
		velocity += (d / dist) * 300.0 * ((min_d - dist) / min_d)

func receive_smash(impulse: Vector2, attacker) -> void:
	if _dead:
		return
	if invincible or _spawn_protect > 0.0:
		return   # Star / fresh-spawn: take zero knockback
	if counter_active and attacker != null and is_instance_valid(attacker) and attacker.has_method("apply_impulse_vector"):
		# Counter Shield: reflect — fling the attacker away instead.
		var dir: Vector2 = (attacker.global_position - global_position).normalized()
		attacker.apply_impulse_vector(dir * impulse.length())
		return
	velocity = (velocity + impulse).limit_length(Tuning.max_speed)
	if attacker != null and attacker is Player:
		last_attacker = attacker
		_attacker_timer = Tuning.kill_credit_window
	var st := Tuning.hitstun_base + impulse.length() * Tuning.hitstun_per_impulse
	_stun_timer = minf(st, Tuning.hitstun_max)
	_flash_timer = 0.12

func flash() -> void:
	_flash_timer = 0.12

func apply_impulse_vector(v: Vector2) -> void:
	# Impulsable (INV-3) — used by explosions later.
	if not _dead:
		velocity = (velocity + v).limit_length(Tuning.max_speed)

func force_super_boost() -> void:
	# Ring of Fire: trigger a full-power super-boost in the current aim, regardless of fuel.
	if _dead:
		return
	velocity = _last_aim * Tuning.super_boost_impulse_full
	EventBus.super_boosted.emit(self)

func start_channel(dur: float) -> void:
	# Black Hole
	if not _dead:
		_channel_timer = dur

func reset_powerup_state() -> void:
	slow_factor = 1.0
	wings_flaps = 0
	_channel_timer = 0.0

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
	last_attacker = null            # a new life never owes kill credit to the old one
	_attacker_timer = 0.0
	_sb_charging = false
	_sb_charge = 0.0
	_sb_was_held = false
	_boost_was_held = false
	_spawn_protect = SPAWN_PROTECT_TIME
	# clear powerup state
	held_powerup = ""
	fuel_locked = false
	invincible = false
	contact_launch = false
	counter_active = false
	bounce_mult = 1.0
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
		if not boosting and not stunned and not _sb_charging:
			sy *= 1.0 + 0.02 * sin(_anim_t * 3.0)
		if _squash_timer > 0.0:
			_squash_timer = maxf(0.0, _squash_timer - delta)
			var t := _squash_timer / SQUASH_SWAP_TIME
			sx *= lerpf(1.0, 1.25, t)
			sy *= lerpf(1.0, 0.75, t)
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
			# hit flash (FEEL §5.2)
			if _flash_timer > 0.0:
				_flash_timer = maxf(0.0, _flash_timer - delta)
				_sprite.self_modulate = Color(2.6, 2.6, 2.6)
			else:
				_sprite.self_modulate = Color.WHITE
	_update_contact_shadow()
	if _fire:
		var nozzle := -aim_dir * 44.0
		var thrust_dir := -aim_dir
		if _sb_charging:
			# Engines revving up: smoke billows out the nozzle and a small flame grows as you charge,
			# telegraphing the blast. Direction is -aim (out the nozzle, opposite where you'll launch).
			_fire.emitting = true
			_smoke.emitting = true
			_fire.position = nozzle
			_smoke.position = nozzle
			_fire.direction = thrust_dir
			_smoke.direction = thrust_dir
			var rev := 0.4 + 0.9 * _sb_charge
			_fire.initial_velocity_max = 300.0 * rev
			_fire.scale = Vector2(rev, rev)
			_smoke.scale = Vector2(1.0 + _sb_charge, 1.0 + _sb_charge)
		else:
			_fire.emitting = boosting
			_smoke.emitting = boosting
			_fire.position = nozzle
			_smoke.position = nozzle
			_fire.direction = thrust_dir
			_smoke.direction = thrust_dir
			# supercharged thrust = bigger, faster fire
			var boost_amt := 1.6 if _supercharge_timer > 0.0 else 1.0
			_fire.initial_velocity_max = 520.0 * boost_amt
			_fire.scale = Vector2(boost_amt, boost_amt)
			_smoke.scale = Vector2.ONE
	if _arrow:
		var show_arrow := (aiming or _sb_charging) and not stunned
		_arrow.visible = show_arrow
		if show_arrow:
			if _sb_charging:
				_arrow.color = Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.2, 0.1), _sb_charge)
				_arrow.scale = Vector2.ONE * (1.0 + 0.9 * _sb_charge)
				_arrow.position = aim_dir * (70.0 + 95.0 * _sb_charge)
			else:
				_arrow.color = Color(1, 1, 1, 0.85)
				_arrow.scale = Vector2.ONE
				_arrow.position = aim_dir * 70.0
			_arrow.rotation = aim_dir.angle()
	if _charge_ring:
		if _sb_charging:
			_charge_ring.visible = true
			var ang := _sb_charge * TAU
			var pts := PackedVector2Array()
			for i in range(29):
				var aa := -PI * 0.5 + ang * (float(i) / 28.0)
				pts.append(Vector2(cos(aa), sin(aa)) * (BODY_RADIUS + 16.0))
			_charge_ring.points = pts
			_charge_ring.default_color = Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.25, 0.1), _sb_charge)
		else:
			_charge_ring.visible = false

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
