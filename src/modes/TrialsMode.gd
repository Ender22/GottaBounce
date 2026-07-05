class_name TrialsMode
extends GameMode
## TRIALS / TIME-ATTACK (docs/specs/v3_content_plan.md PART B; productizes v1_movement_courses.md).
## The first NON-kill-race GameMode: solo, no bots, no combat scoring. Run an authored course A->B;
## the timer runs; a fall out of bounds RESPAWNS the player (+2.0s penalty), it does NOT eliminate;
## touching the GOAL gate clears the stage and awards a medal; clearing the last course ends the match.
##
## Proves the GameMode seam scales to a radically different ruleset WITHOUT a PartyMatch rewrite: it
## fills the same seam methods BRAWL does, reuses the runner's multi-life respawn (B.4) via a high
## lives count, and adds exactly ONE additive seam — polls_goal() — so the runner ends a stage on
## goal-touch instead of last-one-standing. No fenced Tuning constant is read or written.

const HUD_SCENE := preload("res://scenes/ui/TrialsHUD.tscn")
const BALL_SCRIPT := preload("res://src/entities/Ball.gd")

# +2.0s per out-of-bounds fall (design value, spec B.2). NOT a Tuning FEEL constant — it is the mode's
# own run-clock penalty (the run clock is the score here), so it lives with the mode, per the fence.
const FALL_PENALTY := 2.0

# --- OBJECTIVE TYPES (docs/specs/v7_trials_challenge_types.md) ---
# A course declares its win condition via an optional top-level "objective" block; ABSENT => REACH_GOAL
# (byte-identical to the 5 shipped courses — the back-compat hinge, §1.1). Every type reuses the SAME
# per-frame is_stage_over() poll (polls_goal() is already true) + a group scan / timer check — NO new
# runner hook. on_stage_ready() (which already exists on the seam) is newly overridden only to spawn the
# PHYSICS_PUZZLE Ball. NO fenced Tuning constant is read or written.
const OBJ_REACH := "REACH_GOAL"
const OBJ_SURVIVE := "SURVIVE"
const OBJ_DESTROY := "DESTROY_ALL"
const OBJ_PUZZLE := "PHYSICS_PUZZLE"
const OBJ_COLLECT := "COLLECT_ALL"
const OBJ_PRECISION := "PRECISION_LAND"
const OBJ_TYPES := [OBJ_REACH, OBJ_SURVIVE, OBJ_DESTROY, OBJ_PUZZLE, OBJ_COLLECT, OBJ_PRECISION]

# PHYSICS_PUZZLE ball-state thresholds (mode-owned, NOT Tuning feel constants — a puzzle scoring detail).
const BALL_REST_SPEED := 90.0     # below this the ball counts as "at rest" (a missed shot -> settle timer)
const BALL_LAUNCH_SPEED := 220.0  # above this the ball counts as "launched" (a blast punted it; arm reset)

# The authored course SET (ordered, played ONCE — no loop; the match ends after the last course).
# Data-driven: the ordered course list is read from levels/course_sets.json (mirrors circuits.json) so
# the level-designer authors/reorders courses as DATA. PROOF_SET is the safe fallback if the data file
# is missing/malformed or a set is empty (the mode always has at least one runnable course).
const COURSE_SETS_PATH := "res://levels/course_sets.json"
const DEFAULT_SET_ID := "campaign"
const PROOF_SET: Array[String] = ["res://levels/courses/course_01_tank_run.json"]

const MEDAL_COLORS := {
	"gold": Color("#ffd23f"), "silver": Color("#cbd6df"),
	"bronze": Color("#d68b4c"), "none": Color("#f0f0f0"),
}

var _course_set: Array = []
var _course_idx := 0                 # index of the NEXT course to serve (advanced in next_level_path)
var _cur_path := ""                  # the course currently loaded
var _cur_medal_times: Dictionary = {}   # {gold,silver,bronze} of the current course
var _cur_objective: Dictionary = {}     # the current course's "objective" block ({} => REACH_GOAL)

# per-course run state (reset each course in next_level_path)
var run_penalty := 0.0               # accumulated time penalty on the current course (falls)
var attempts := 0                    # falls on the current course (the "attempt"/falls counter, HUD)

# --- per-type live state (reset each course in next_level_path) ---
# SURVIVE: the survival clock is (round_clock - _survive_base); a death resets _survive_base to the
# current round_clock (progress -> 0, a RETRY not a +2s penalty) and ticks _resets (the death metric).
var _survive_base := 0.0
var _resets := 0
# DESTROY_ALL: how many destructibles the course started with (guards a 0-block instant-clear).
var _blocks_total := 0
# PHYSICS_PUZZLE: the puzzle is scored in attempts (1 = solved first blast); each auto-reset ticks it.
var _puzzle_attempts := 1
var _ball = null                     # the spawned Ball (PHYSICS_PUZZLE); untyped so RigidBody2D props read
var _ball_spawn := Vector2.ZERO      # the "ball" object's spawn point (read from course JSON)
var _ball_launched := false          # has a blast punted the ball since the last (re)spawn?
var _settle_t := 0.0                 # seconds the ball has been at rest / out of bounds since launch
var _last_poll_clock := 0.0          # round_clock at the previous is_stage_over poll (for a dt estimate)
# COLLECT_ALL / PRECISION_LAND: totals captured at stage start (guard a 0-member vacuous clear).
var _pickups_total := 0
var _targets_total := 0

# set-scoped bookkeeping
var _best_times: Dictionary = {}     # course path -> best cleared time this session (HUD "BEST")
var _course_results: Array = []      # [{path, time, medal}] per cleared course (match-end summary)

# --- identity / presentation ---
func id() -> StringName:
	return &"trials"

func display_name() -> String:
	return "TRIALS"

func hud_scene() -> PackedScene:
	return HUD_SCENE

## Additive seam: TRIALS ends a stage by reaching a goal (no death), so the runner must poll each frame.
func polls_goal() -> bool:
	return true

# --- match setup ---
func configure(runner, _config: MatchConfig) -> void:
	# HIGH lives so a fall consumes a life and the runner RESPAWNS the lone human (B.4 reuse of the
	# existing multi-life respawn path) instead of eliminating -> ending the stage. Never a kill-race.
	runner.lives_per_player = 99
	runner.match_target_kills = 999999   # so a stray on_kill can never trip the kill-race match end
	# The course SET is selectable via config.circuit_id (reserved set/circuit key; SportsMode reuses
	# single_arena_path the same way). Empty/unknown => DEFAULT_SET_ID "campaign" (byte-identical default:
	# a fresh MatchConfig has circuit_id = &"" so the shipped campaign is served exactly as before).
	var set_id := DEFAULT_SET_ID
	if _config != null and str(_config.circuit_id) != "":
		set_id = str(_config.circuit_id)
	_course_set = _load_course_set(set_id)
	_course_idx = 0
	_cur_path = ""
	_cur_medal_times = {}
	_cur_objective = {}
	run_penalty = 0.0
	attempts = 0
	_course_results.clear()

## Humans only, NO bots (B.2). v1 = 1 human (solo); the multi-human hot-seat race is a v2 flag.
func spawn_plan(_runner, config: MatchConfig) -> Array:
	var out: Array = []
	var n: int = maxi(1, config.human_count)
	for i in range(n):
		out.append({
			"human": true, "skin": config.skin_for(i), "character": config.character_for(i),
			"bot_level": 0, "seed_damage": 0, "team": 0,
		})
	return out

# --- stage lifecycle ---

## The next course in authored order, played once. Resets the per-course run clock penalty + attempt
## counter and caches the course's medal thresholds. (A fresh GoalGate is built by _load_stage, so the
## goal flag resets automatically — is_stage_over reads the live gate, not a latched mode flag.)
func next_level_path(_runner) -> String:
	if _course_set.is_empty():
		return ""
	_cur_path = str(_course_set[_course_idx % _course_set.size()])
	_course_idx += 1
	run_penalty = 0.0
	attempts = 0
	_cur_medal_times = _read_medal_times(_cur_path)
	# NEW (v7): cache the objective block ({} => REACH_GOAL) + reset all per-type live state so a fresh
	# course never inherits the previous course's survive clock / attempts / block count.
	_cur_objective = _read_objective(_cur_path)
	_survive_base = 0.0
	_resets = 0
	_blocks_total = 0
	_puzzle_attempts = 1
	_ball = null
	_ball_spawn = _read_ball_spawn(_cur_path)
	_ball_launched = false
	_settle_t = 0.0
	_last_poll_clock = 0.0
	_pickups_total = 0
	_targets_total = 0
	return _cur_path

## The stage-over test, DISPATCHED on the course's objective type (v7 §1.2). Each branch reads LIVE
## scene state via a group scan / timer check — the SAME per-frame poll REACH_GOAL always used (the
## runner polls this every combat frame because polls_goal() is true). ABSENT objective => REACH_GOAL,
## verbatim, so the 5 shipped courses are byte-identical.
func is_stage_over(runner) -> bool:
	match _objective_type():
		OBJ_SURVIVE:
			return _survive_cleared(runner)
		OBJ_DESTROY:
			# all destructibles broken: the umbrella group "destructible" empties (guard the 0-block case).
			return _blocks_total > 0 and runner.get_tree().get_nodes_in_group("destructible").is_empty()
		OBJ_PUZZLE:
			return _puzzle_cleared(runner)
		OBJ_COLLECT:
			return _all_flagged(runner, "trials_pickup", "collected", _pickups_total)
		OBJ_PRECISION:
			return _all_flagged(runner, "trials_target", "landed", _targets_total)
		_:
			# REACH_GOAL (default + every shipped course): any goal_gate latched `reached`. (verbatim)
			for g in runner.get_tree().get_nodes_in_group("goal_gate"):
				if g.reached:
					return true
			return false

## No kill-race scoring. A "death" here = a fall out of bounds (killer is always self / -1). DISPATCHED
## on objective type (v7 §1.2): REACH_GOAL / DESTROY_ALL / COLLECT / PRECISION add a +2s time penalty
## and tick the fall counter (today's behavior). SURVIVE resets the survival clock (progress -> 0) and
## ticks the death metric — the death IS the cost, no +2s. PHYSICS_PUZZLE: a player fall is a pure
## respawn (the BALL, not the player, is the scorer). Never mutates runner.scores.
func on_kill(runner, _killer_idx: int, _victim_idx: int, _cause) -> void:
	match _objective_type():
		OBJ_SURVIVE:
			_survive_base = float(runner.round_clock)   # a death restarts the survival clock at 0
			_resets += 1
		OBJ_PUZZLE:
			pass   # a fall just respawns the player; scoring is the ball reaching the goal
		_:
			run_penalty += FALL_PENALTY
			attempts += 1

## Newly overridden seam (already exists on GameMode; SPORTS uses it). Per-type stage-start setup:
## PHYSICS_PUZZLE spawns the Ball at its spawn point (reuse of the SPORTS ball-spawn pattern);
## DESTROY_ALL / COLLECT_ALL / PRECISION_LAND capture their group totals (so a clear needs at least one
## member broken/collected/landed). REACH_GOAL + SURVIVE fall through to a no-op => parity.
func on_stage_ready(runner) -> void:
	match _objective_type():
		OBJ_PUZZLE:
			_spawn_puzzle_ball(runner)
		OBJ_DESTROY:
			_blocks_total = runner.get_tree().get_nodes_in_group("destructible").size()
		OBJ_COLLECT:
			_pickups_total = runner.get_tree().get_nodes_in_group("trials_pickup").size()
		OBJ_PRECISION:
			_targets_total = runner.get_tree().get_nodes_in_group("trials_target").size()
		_:
			pass

## Player 0 once the LAST course's goal has been cleared (the whole set is complete). -1 while courses
## remain OR the current course's goal is not yet reached (so a fall never trips a false match end).
func match_winner(runner) -> int:
	if _course_idx >= _course_set.size() and is_stage_over(runner):
		return 0
	return -1

## Per-course result banner: the per-type result + medal earned (v7 §1.2). (Also records the result for
## BEST + the match-end summary.) The medal is computed by _result_medal() — time-scored types compare
## seconds vs medal_times (<=, today's logic), SURVIVE compares deaths vs medal_survive (<=), DESTROY_ALL
## falls-mode compares falls vs medal_falls, PHYSICS_PUZZLE compares attempts vs medal_attempts.
func stage_end_banner(runner) -> Dictionary:
	var t := current_time(runner)
	var medal := _result_medal(runner)
	var prev: float = float(_best_times.get(_cur_path, INF))
	if t < prev:
		_best_times[_cur_path] = t
	_course_results.append({"path": _cur_path, "time": t, "medal": medal})
	var label := medal.to_upper() if medal != "none" else "CLEAR"
	var text := "COURSE CLEAR!  %.1fs  —  %s" % [t, label]
	match _objective_type():
		OBJ_SURVIVE:
			var secs := float(_cur_objective.get("survive_seconds", 20.0))
			text = "SURVIVED %.0fs!  —  %s  (%d death%s)" % [secs, label, _resets, _plural(_resets)]
		OBJ_DESTROY:
			if str(_cur_objective.get("score_by", "time")) == "falls":
				text = "CLEARED!  %d fall%s  —  %s" % [attempts, _plural(attempts), label]
			else:
				text = "CLEARED!  %.1fs  —  %s" % [t, label]
		OBJ_PUZZLE:
			text = "SOLVED!  %d attempt%s  —  %s" % [_puzzle_attempts, _plural(_puzzle_attempts), label]
	return {"text": text, "color": MEDAL_COLORS.get(medal, Color.WHITE)}

static func _plural(n: int) -> String:
	return "" if n == 1 else "s"

## The set summary (spec B.2): total time across courses + medal tallies.
func match_end_banner(_runner) -> Dictionary:
	var total := 0.0
	var golds := 0
	var silvers := 0
	var bronzes := 0
	for r in _course_results:
		total += float(r["time"])
		match str(r["medal"]):
			"gold": golds += 1
			"silver": silvers += 1
			"bronze": bronzes += 1
	return {"text": "TRIALS COMPLETE!", "color": MEDAL_COLORS["gold"],
		"subline": "Total %.1fs    %dx GOLD   %dx SILVER   %dx BRONZE" % [total, golds, silvers, bronzes]}

# --- HUD read helpers (TrialsHUD polls these via runner._mode) ---

## Current run time = combat clock (runner.round_clock ticks only during COMBAT, resets per course)
## + accumulated fall penalties. Frozen automatically at goal-touch (round_clock stops in STAGE_END).
func current_time(runner) -> float:
	return maxf(0.0, float(runner.round_clock)) + run_penalty

func medal_for(t: float) -> String:
	if _cur_medal_times.is_empty():
		return "none"
	if t <= float(_cur_medal_times.get("gold", 0.0)):
		return "gold"
	if t <= float(_cur_medal_times.get("silver", 0.0)):
		return "silver"
	if t <= float(_cur_medal_times.get("bronze", 0.0)):
		return "bronze"
	return "none"

func medal_times() -> Dictionary:
	return _cur_medal_times

func medal_color(medal: String) -> Color:
	return MEDAL_COLORS.get(medal, Color.WHITE)

func best_time() -> float:
	return float(_best_times.get(_cur_path, 0.0))

# --- v7 objective-type surface (read by TrialsHUD to swap its center readout per type) ---

## The current course's objective type; ABSENT/unknown => REACH_GOAL (the back-compat resolution).
func objective_type() -> String:
	return _objective_type()

func _objective_type() -> String:
	var t := str(_cur_objective.get("type", OBJ_REACH)).to_upper()
	return t if t in OBJ_TYPES else OBJ_REACH

## The provisional medal for the CURRENT run state, by type (fewer deaths/attempts = better; <= compare).
func result_medal(runner) -> String:
	return _result_medal(runner)

func _result_medal(runner) -> String:
	match _objective_type():
		OBJ_SURVIVE:
			return _medal_le_int(_resets, _cur_objective.get("medal_survive", {}))
		OBJ_PUZZLE:
			if str(_cur_objective.get("score_by", "attempts")) == "time":
				return medal_for(current_time(runner))
			return _medal_le_int(_puzzle_attempts, _cur_objective.get("medal_attempts", {}))
		OBJ_DESTROY:
			if str(_cur_objective.get("score_by", "time")) == "falls":
				return _medal_le_int(attempts, _cur_objective.get("medal_falls", {}))
			return medal_for(current_time(runner))
		_:
			return medal_for(current_time(runner))

## Lower-is-better integer medal (deaths / falls / attempts), <= compare — mirrors medal_for's shape.
func _medal_le_int(v: int, m: Dictionary) -> String:
	if typeof(m) != TYPE_DICTIONARY or m.is_empty():
		return "none"
	if v <= int(m.get("gold", -1)):
		return "gold"
	if v <= int(m.get("silver", -1)):
		return "silver"
	if v <= int(m.get("bronze", -1)):
		return "bronze"
	return "none"

# HUD readouts (SURVIVE clock, DESTROY_ALL blocks-left, PHYSICS_PUZZLE attempts).
func survive_target() -> float:
	return float(_cur_objective.get("survive_seconds", 20.0))

func survive_elapsed(runner) -> float:
	return maxf(0.0, float(runner.round_clock) - _survive_base)

func survive_deaths() -> int:
	return _resets

func blocks_remaining(runner) -> int:
	return runner.get_tree().get_nodes_in_group("destructible").size()

func puzzle_attempts() -> int:
	return _puzzle_attempts

# --- per-type clear tests ---

## SURVIVE: cleared once the survival clock reaches the target with no death since the last reset. While
## the lone human is dead (respawn delay) the base is PINNED to round_clock so elapsed stays 0 — a death
## returns progress to 0 and it re-counts from the respawn, never a partial-credit clear (v7 §2.2).
func _survive_cleared(runner) -> bool:
	var p = runner.players[0] if runner.players.size() > 0 else null
	if p == null or not is_instance_valid(p) or (p.has_method("is_dead") and p.is_dead()):
		_survive_base = float(runner.round_clock)
		return false
	return (float(runner.round_clock) - _survive_base) >= survive_target()

## PHYSICS_PUZZLE: cleared when any goal_zone latched `scored` (the Ball crossed it — the SPORTS latch,
## verbatim). Otherwise runs the auto-reset bookkeeping: once a blast LAUNCHES the ball, if it then comes
## to rest or leaves bounds WITHOUT scoring for reset_settle_s, respawn it + tick _attempts (v7 §2.4), so
## the ball can never be permanently lost and "attempts" is a clean countable metric.
func _puzzle_cleared(runner) -> bool:
	for z in runner.get_tree().get_nodes_in_group("goal_zone"):
		if z.scored:
			return true
	var dt: float = maxf(0.0, float(runner.round_clock) - _last_poll_clock)
	_last_poll_clock = float(runner.round_clock)
	if is_instance_valid(_ball):
		var spd: float = (_ball.linear_velocity as Vector2).length()
		var settle_target: float = float(_cur_objective.get("reset_settle_s", 2.5))
		# OOB is checked FIRST, independent of speed: a ball that flies off the map keeps moving fast
		# forever (never "rests"), so a speed-gated reset would never fire for a lost shot — the auto-reset
		# has to catch the out-of-bounds case on its own.
		var oob: bool = not runner.bounds.grow(200.0).has_point(_ball.global_position)
		if oob:
			_settle_t += dt
			if _settle_t >= settle_target:
				_reset_puzzle(runner)
		elif spd >= BALL_LAUNCH_SPEED:
			_ball_launched = true       # a blast punted it: arm the "settle -> reset" watch
			_settle_t = 0.0
		elif _ball_launched and spd < BALL_REST_SPEED:
			_settle_t += dt             # launched then came to rest in bounds without scoring: a miss
			if _settle_t >= settle_target:
				_reset_puzzle(runner)
		else:
			_settle_t = 0.0             # resting pre-launch (at spawn) — do not reset before the blast
	return false

## COLLECT_ALL / PRECISION_LAND: cleared when EVERY member of the group has its latch flag set (and the
## course started with at least one — `total` guards the vacuous 0-member clear).
func _all_flagged(runner, group: String, flag: String, total: int) -> bool:
	if total <= 0:
		return false
	for n in runner.get_tree().get_nodes_in_group(group):
		if not bool(n.get(flag)):
			return false
	return true

# --- PHYSICS_PUZZLE ball plumbing (reuse of the SPORTS Ball + spawn pattern) ---
func _spawn_puzzle_ball(runner) -> void:
	if is_instance_valid(_ball):
		_ball.queue_free()
	_ball = BALL_SCRIPT.new()
	runner._level_root.add_child(_ball)
	_ball.global_position = _ball_spawn
	_ball.linear_velocity = Vector2.ZERO
	_ball_launched = false
	_settle_t = 0.0

func _reset_puzzle(runner) -> void:
	if is_instance_valid(_ball):
		_ball.global_position = _ball_spawn
		_ball.linear_velocity = Vector2.ZERO
	else:
		_spawn_puzzle_ball(runner)
	_ball_launched = false
	_settle_t = 0.0
	_puzzle_attempts += 1

# --- internals ---

## Read the top-level "objective" block from a course JSON. Returns {} on any failure => REACH_GOAL.
func _read_objective(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var ob: Variant = (parsed as Dictionary).get("objective", {})
	return ob if typeof(ob) == TYPE_DICTIONARY else {}

## Read the PHYSICS_PUZZLE "ball" object's spawn point (x,y) from a course JSON, else Vector2.ZERO.
func _read_ball_spawn(path: String) -> Vector2:
	if not FileAccess.file_exists(path):
		return Vector2.ZERO
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return Vector2.ZERO
	for o in (parsed as Dictionary).get("objects", []):
		if typeof(o) == TYPE_DICTIONARY and str((o as Dictionary).get("type", "")) == "ball":
			return Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))
	return Vector2.ZERO

## Load an ordered course list from levels/course_sets.json by set id. Keeps only course paths whose
## file exists. Falls back to PROOF_SET on any failure so the mode is ALWAYS runnable.
func _load_course_set(set_id: String) -> Array:
	if FileAccess.file_exists(COURSE_SETS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COURSE_SETS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			var sets: Variant = (parsed as Dictionary).get("sets", {})
			if typeof(sets) == TYPE_DICTIONARY and (sets as Dictionary).has(set_id):
				var entry: Variant = (sets as Dictionary)[set_id]
				var courses: Variant = (entry as Dictionary).get("courses", []) if typeof(entry) == TYPE_DICTIONARY else []
				if typeof(courses) == TYPE_ARRAY:
					var out: Array = []
					for c in (courses as Array):
						var p := str(c)
						if FileAccess.file_exists(p):
							out.append(p)
						else:
							push_warning("TrialsMode: course missing, skipped: " + p)
					if not out.is_empty():
						return out
	push_warning("TrialsMode: course_sets.json unusable for set '" + set_id + "' — using proof course")
	return PROOF_SET.duplicate()

## Read {gold,silver,bronze} from a course JSON. Returns {} on any failure (HUD shows no medal, never crashes).
func _read_medal_times(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var mt: Variant = (parsed as Dictionary).get("medal_times", {})
	return mt if typeof(mt) == TYPE_DICTIONARY else {}
