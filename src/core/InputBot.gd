class_name InputBot
extends RefCounted
## Human-sim bot (INV-8): emits InputIntent like a human, no cheating. Difficulty via a BotProfile
## (P10) — aim error, reaction time, recovery skill, aggression. Decisions refresh on reaction_time.
##
## Survival-first AI: it predicts where its momentum is carrying it and recovers BEFORE leaving the
## arena, instead of blindly boosting toward center after it's already too late. Low recovery_skill
## bots still flail (the funny low-level behaviour), high-skill bots recover cleanly and hunt hard.

var me: Player
var arena
var profile: BotProfile
var _intent := InputIntent.new()
var _super_cd := 0.0
var _pu_cd := 0.0
var _react := 0.0
var _cached_aim := Vector2.ZERO
var _cached_boost := false
var _cached_super := false
var _sb_hold := 0.0          # how long the bot keeps charging its super-boost before releasing

func _init(player: Player, arena_ref, level := 3) -> void:
	me = player
	arena = arena_ref
	profile = BotProfile.for_level(level)

func poll() -> InputIntent:
	var it := _intent
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	it.super_boost = false
	it.use_powerup = false
	it.flap = false
	_super_cd = maxf(0.0, _super_cd - dt)
	_sb_hold = maxf(0.0, _sb_hold - dt)
	_react -= dt
	if me == null or not is_instance_valid(me) or me.is_dead():
		it.aim = Vector2.ZERO
		it.boost = false
		it.super_hold = false
		return it
	# Recovery is re-evaluated EVERY frame (not just on reaction_time): bailing out of a fall is
	# reflexive, and waiting up to reaction_time to react is what sends bots off the map.
	if _danger_recover(it):
		it.super_hold = false
		return it
	if _react <= 0.0:
		_react = profile.reaction_time
		_decide()
	it.aim = _cached_aim
	it.boost = _cached_boost
	# Chargeable super-boost: a decision to super starts a short hold (charge), released automatically.
	if _cached_super and _sb_hold <= 0.0:
		_sb_hold = randf_range(0.45, 1.1)
		_cached_super = false
	it.super_hold = _sb_hold > 0.0
	if it.super_hold:
		it.boost = false   # don't normal-boost while charging
	# use a held powerup — eagerness scales with aggression (party bots, INV-8)
	_pu_cd = maxf(0.0, _pu_cd - dt)
	if me.held_powerup != "" and _pu_cd <= 0.0 and randf() < 0.05 * (0.5 + profile.aggression):
		it.use_powerup = true
		_pu_cd = 0.6
	# Wings active: occasionally tap a flap to fly while boosting.
	if me.wings_flaps > 0 and it.boost and randf() < 0.15:
		it.flap = true
	# Steer the thrust around walls/platforms so the bot stops boosting straight into geometry.
	if it.boost or it.super_hold:
		it.aim = _steer(it.aim)
	return it

func _bounds() -> Rect2:
	return arena.bounds

func _stage() -> Rect2:
	if arena.has_method("stage_rect"):
		return arena.stage_rect()
	var b := _bounds()
	return b

func _stage_center() -> Vector2:
	if arena.has_method("stage_center"):
		return arena.stage_center()
	return _stage().get_center()

## Reflexive survival: if knocked off the stage or about to leave the arena, boost back toward the
## platforms (Smash-style recovery). Returns true if it took over control this frame.
func _danger_recover(it: InputIntent) -> bool:
	var b := _bounds()
	var pos := me.global_position
	var vel: Vector2 = me.velocity
	var future := pos + vel * 0.6
	var outside_soon := not b.grow(-80.0).has_point(future)
	var off_stage := not _stage().grow(440.0).has_point(pos)
	if not (outside_soon or off_stage):
		return false
	# steer back toward the stage (aim slightly above its center so we land on top, not under it)
	var target := _stage_center() + Vector2(0, -120)
	var dir := (target - pos)
	if dir.length() < 1.0:
		return false
	dir = dir.normalized()
	# low recovery_skill: panic flail (the funny death). high skill: clean, hard recovery.
	if randf() > profile.recovery_skill:
		dir = dir.rotated(randf_range(-0.8, 0.8))
	else:
		dir = _steer(dir)
	it.aim = dir
	it.boost = me.fuel > 4.0
	it.super_boost = false
	it.super_hold = false
	it.use_powerup = false
	if me.wings_flaps > 0:
		it.flap = randf() < 0.5
	_cached_aim = dir
	_cached_boost = it.boost
	return true

func _decide() -> void:
	var pos := me.global_position
	# Stay near the stage: only hunt when standing on/near the platforms, so bots don't chase into
	# the blast zone. The recovery handler takes over once they're knocked off.
	var on_stage := _stage().grow(360.0).has_point(pos)
	var target = arena.nearest_opponent(me)
	if target != null and is_instance_valid(target) and on_stage:
		var tp: Vector2 = target.global_position
		var d: Vector2 = tp - pos
		var dist := d.length()
		_cached_aim = _jitter(d.normalized())
		# only commit if the target is also near the stage (don't get baited into the void)
		var target_near := _stage().grow(520.0).has_point(tp)
		var hunt := randf() < profile.aggression and target_near
		_cached_boost = hunt and dist > 220.0 and me.fuel > 25.0
		_cached_super = hunt and dist < 280.0 and me.fuel > 55.0 and _super_cd <= 0.0
		if _cached_super:
			_super_cd = lerpf(2.2, 1.0, profile.aggression)
	else:
		# no target / off-stage drift: ease back toward the stage
		var to_stage := (_stage_center() - pos)
		_cached_aim = _jitter(to_stage.normalized()) if to_stage.length() > 160.0 else Vector2.ZERO
		_cached_boost = me.fuel > 35.0 and to_stage.length() > 360.0
		_cached_super = false

func _jitter(dir: Vector2) -> Vector2:
	return dir.rotated(randf_range(-profile.aim_error, profile.aim_error))


## Lightweight obstacle avoidance (the bots had NONE — they boosted straight into walls). Probe
## feeler rays fanning out from the desired heading and return the nearest CLEAR one, so the bot
## steers around surfaces instead of slamming into them. Surfaces only (props are still smashable).
func _steer(desired: Vector2) -> Vector2:
	if desired == Vector2.ZERO or me == null or not is_instance_valid(me):
		return desired
	var space := me.get_world_2d().direct_space_state
	var from: Vector2 = me.global_position
	var probe := 240.0
	for ang in [0.0, 0.35, -0.35, 0.75, -0.75, 1.2, -1.2, 1.7, -1.7]:
		var d := desired.rotated(ang)
		var q := PhysicsRayQueryParameters2D.create(from, from + d * probe, Player.MASK_SURFACES)
		q.exclude = [me.get_rid()]
		if space.intersect_ray(q).is_empty():
			return d
	return desired
