extends RefCounted
## WK-37 BOT GHOST driver (docs/specs/wk37a_ghost_goats_2026-11-14.md §6). A charming heckler, never a CPU kingmaker.
## Produces the SAME InputIntent a human ghost's InputHuman does (INV-8) — the GhostGoat cannot tell them apart.
##   FLOAT  hover spot bot_ghost_hover_dist from the living centroid, on the side the bot died, inside the view inset;
##          re-picked every bot_ghost_repick_min..max s; >= bot_ghost_spacing from other ghosts; drift at
##          bot_ghost_drift_mult x speed, never hurry.
##   BLEAT  ambient Poisson (mean bot_ghost_bleat_mean_interval) + reactive (p = bot_ghost_react_bleat_p, 0.3-0.8 s
##          after any KO). The director's shared rate limit still applies.
##   PUFF   effective cooldown = ghost_puff_cooldown / bot_ghost_puff_rate_mult (14 s; first puff uniform in
##          [arm, arm + that]). Target = UNIFORM RANDOM living player (no leader / human focus). Placement 250-350 px
##          ahead of the target's velocity at its height +-100. Never during a hush.
## No difficulty: identical at L1-L5 (a smarter heckler is not a feature). Separate file on purpose: InputBot.gd is the
## FIGHTING brain (and is owned by another work item); ghosts never touch it.
## Kept free of class_name (loaded by path from GhostDirector — no class-cache dependency).

# WK-37c/d (Tuning WK-37d block): bot_ghost_chase_sep_weight = separation weight while chasing a puff placement
# (1.5 let two bots chasing one target settle ~90 px apart). Bleat cadence: ambient intervals are
# bot_ghost_bleat_min_gap + Exp(mean - min_gap), so the ambient mean stays bot_ghost_bleat_mean_interval with no
# near-double bleats; ANY bleat restarts the ambient clock (a reaction replaces, never adds); a reaction inside the
# min gap is skipped (a KO burst is one bleat, not a chorus).

var ghost                    # GhostGoat
var director                 # GhostDirector
var runner                   # PartyMatch
var death_pos := Vector2.ZERO

var hover := Vector2.ZERO    # current hover spot (QA: ghost_motion "at a hover spot")
var _repick_t := 0.0
var _bleat_t := 0.0          # s until the next ambient bleat
var _react_t := -1.0         # s until a scheduled reactive bleat (-1 = none)
var _puff_due := 0.0         # director clock when this bot next WANTS to puff
var _chasing := false
var _chase_t := 0.0
var _target = null           # Player being puffed at
var _place_dy := 0.0
var _lead := 300.0
var _press := false          # one-tick puff press (edge)
var _intent := InputIntent.new()
var _rng := RandomNumberGenerator.new()
var _bleat_now := false
var _since_bleat := 999.0    # s since this ghost's last bleat

func _init(g, dir, run, died_at: Vector2) -> void:
	ghost = g
	director = dir
	runner = run
	death_pos = died_at
	_rng.randomize()
	_bleat_t = _exp_interval()
	var eff: float = Tuning.ghost_puff_cooldown / maxf(Tuning.bot_ghost_puff_rate_mult, 0.01)
	_puff_due = director.clock() + Tuning.ghost_puff_arm_delay + _rng.randf_range(0.0, eff)
	if KillPipeline.killed.is_connected(_on_killed) == false:
		KillPipeline.killed.connect(_on_killed)

func dispose() -> void:
	if KillPipeline.killed.is_connected(_on_killed):
		KillPipeline.killed.disconnect(_on_killed)

func _exp_interval() -> float:
	var tail: float = maxf(0.1, Tuning.bot_ghost_bleat_mean_interval - Tuning.bot_ghost_bleat_min_gap)
	return Tuning.bot_ghost_bleat_min_gap + -log(maxf(1e-4, _rng.randf())) * tail

func _on_killed(_victim, _cause, _attacker) -> void:
	if ghost == null or not is_instance_valid(ghost) or ghost.frozen or _react_t >= 0.0:
		return
	if _rng.randf() < Tuning.bot_ghost_react_bleat_p:
		_react_t = _rng.randf_range(0.3, 0.8)

func poll() -> InputIntent:
	var it := _intent
	it.aim = Vector2.ZERO
	it.boost = false
	it.super_hold = false
	it.use_powerup = false
	it.flap = false
	it.taunt = false
	if ghost == null or not is_instance_valid(ghost) or ghost.frozen:
		return it
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	# --- bleats ---
	_since_bleat += dt
	_bleat_t -= dt
	if _bleat_t <= 0.0:
		it.taunt = true
	if _react_t >= 0.0:
		_react_t -= dt
		if _react_t < 0.0 and _since_bleat >= Tuning.bot_ghost_bleat_min_gap:
			it.taunt = true
	if it.taunt:
		_since_bleat = 0.0
		_bleat_t = _exp_interval()   # any bleat restarts the ambient clock (a reaction replaces, never adds)
	# --- puff decision ---
	var living: Array = director.living_players()
	# start flying to the placement a little BEFORE the cooldown ends, so the chase doesn't stretch the 14 s cycle
	if not _chasing and director.clock() >= _puff_due and director.puff_ready_within(ghost, Tuning.bot_ghost_puff_lead_time) \
			and not living.is_empty():
		_chasing = true
		_chase_t = 0.0
		_target = living[_rng.randi_range(0, living.size() - 1)]   # UNIFORM — no leader / human focus
		_lead = _rng.randf_range(Tuning.bot_ghost_puff_lead_min, Tuning.bot_ghost_puff_lead_max)
		_place_dy = _rng.randf_range(-Tuning.bot_ghost_puff_dy, Tuning.bot_ghost_puff_dy)
	if _chasing:
		_chase_t += dt
		if director.is_hushed() or not is_instance_valid(_target) or _target.is_dead() or _chase_t > Tuning.bot_ghost_puff_give_up:
			_chasing = false
			_puff_due = director.clock() + 2.0   # try again shortly (a hush / dead target is not a spent puff)
		else:
			var tv: Vector2 = _target.velocity
			var dir: Vector2 = tv.normalized() if tv.length() > 40.0 else Vector2(signf(ghost.global_position.x - _target.global_position.x), 0.0)
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var place: Vector2 = _target.global_position + dir * _lead + Vector2(0.0, _place_dy)
			var goal: Vector2 = place - Tuning.ghost_puff_spawn_offset
			goal = director.clamp_to_view(goal)
			var to: Vector2 = goal - ghost.global_position
			# press when on the spot, or — the target keeps moving — when roughly there and the chase has run a while
			var close: bool = to.length() < Tuning.bot_ghost_puff_press_dist \
				or (_chase_t > Tuning.bot_ghost_puff_give_up * 0.5 and to.length() < Tuning.bot_ghost_puff_press_dist * 2.5)
			if close and director.puff_ready(ghost):
				it.use_powerup = true   # the same press a human makes (B)
				_target_used(_target)
				_chasing = false
				var eff: float = Tuning.ghost_puff_cooldown / maxf(Tuning.bot_ghost_puff_rate_mult, 0.01)
				_puff_due = director.clock() + eff - Tuning.bot_ghost_puff_lead_time
			elif close:
				it.aim = director.separation_push(ghost).limit_length(1.0)   # on the spot early: wait (but never stack)
			else:
				# full float speed toward the placement (no hurry); two ghosts chasing one target still keep apart
				it.aim = (to.normalized() + director.separation_push(ghost) * Tuning.bot_ghost_chase_sep_weight).limit_length(1.0)
			return it
	# --- float to a hover spot ---
	_repick_t -= dt
	if _repick_t <= 0.0 or hover == Vector2.ZERO:
		_repick_t = _rng.randf_range(Tuning.bot_ghost_repick_min, Tuning.bot_ghost_repick_max)
		hover = _pick_hover(living)
	var sep: Vector2 = director.separation_push(ghost)
	var to_h: Vector2 = hover - ghost.global_position
	var steer := Vector2.ZERO
	if to_h.length() > 40.0:
		steer = to_h.normalized() * minf(1.0, to_h.length() / 160.0)
	if sep.length() > 0.05:
		# crowded (< bot_ghost_spacing): spreading out beats reaching the spot, at full float speed (never hurry)
		steer = (steer * 0.3 + sep * 3.0).limit_length(1.0)
		if nearest_hover_conflict():
			_repick_t = 0.0                 # our spot sits on another ghost: pick a new one next tick
		it.aim = steer
		return it
	if steer.length() > 1.0:
		steer = steer.normalized()
	it.aim = steer * Tuning.bot_ghost_drift_mult
	return it

func _target_used(t) -> void:
	director.note_bot_target(ghost, t)

## Hover spot: bot_ghost_hover_dist from the living centroid toward where this bot died (+-40 deg jitter), clamped into
## the view inset, at least director.pick_spacing() from every other ghost (best of 16 tries).
func _pick_hover(living: Array) -> Vector2:
	var c := Vector2.ZERO
	if living.is_empty():
		c = ghost.global_position
	else:
		for p in living:
			c += (p.global_position as Vector2)
		c /= float(living.size())
	var base: Vector2 = death_pos - c
	if base.length() < 1.0:
		base = Vector2(1.0 if _rng.randf() < 0.5 else -1.0, -0.3)
	base = base.normalized()
	var best := Vector2.ZERO
	var best_d := -1.0
	for k in range(16):
		# first 8 tries hug the side we died on (+-40 deg); then anywhere around the fight (the view clamp can
		# squash every same-side candidate onto one edge point)
		var ang: float = _rng.randf_range(-0.7, 0.7) if k < 8 else _rng.randf_range(-PI, PI)
		var cand: Vector2 = director.clamp_to_view(c + base.rotated(ang) * Tuning.bot_ghost_hover_dist)
		var d: float = director.nearest_other_ghost_dist(ghost, cand)
		if d >= director.pick_spacing():   # spacing + margin: a spot AT 200 px is a fail the moment anyone drifts
			return cand
		if d > best_d:
			best_d = d
			best = cand
	return best

## Our hover spot is within bot_ghost_spacing of another ghost (or its spot).
func nearest_hover_conflict() -> bool:
	return director.nearest_other_ghost_dist(ghost, hover) < director.pick_spacing()

## QA: is the ghost resting at its hover spot (stuck detection ignores a ghost that has arrived)?
func at_hover() -> bool:
	return ghost != null and is_instance_valid(ghost) and ghost.global_position.distance_to(hover) < 60.0
