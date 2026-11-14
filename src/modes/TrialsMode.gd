class_name TrialsMode
extends GameMode
## TRIALS (docs/specs/v10_trials_completion_model.md — Pico-Park-style BINARY completion). The first
## NON-kill-race GameMode: no bots, no combat scoring, NO clock / par / medal / best-time / penalty.
## A course is either COMPLETE or not. A fall out of bounds RESPAWNS the player with ZERO penalty (it
## never eliminates — lives_per_player = 99). The course COMPLETES the instant EVERY living participant
## has, on their own, satisfied the objective (all-must-finish). `done` is a STICKY per-player latch — a
## finished player who then falls does NOT un-complete the course (§1.2). Clearing the last course ends
## the match.
##
## v10 supersedes v7's TIME/MEDAL/PAR layer (all stripped) but PRESERVES v7's objective-type framework:
## the optional top-level "objective" block, the six types, and the absent-block => REACH_GOAL hinge.
## REACH_GOAL + SURVIVE run full multi-player-parallel (each player flies their own line); the four
## object-mutation types (DESTROY_ALL/PHYSICS_PUZZLE/COLLECT_ALL/PRECISION_LAND) ship SOLO (§1.3) but
## still work single-player. Zero new runner hooks — the runner already polls is_stage_over() every
## combat frame (polls_goal() is true) and spawn_plan already spawns human_count players.

const HUD_SCENE := preload("res://scenes/ui/TrialsHUD.tscn")
const BALL_SCRIPT := preload("res://src/entities/Ball.gd")

# --- OBJECTIVE TYPES (docs/specs/v7_trials_challenge_types.md framework; v10 completion model) ---
# A course declares its win condition via an optional top-level "objective" block; ABSENT => REACH_GOAL.
const OBJ_REACH := "REACH_GOAL"
const OBJ_SURVIVE := "SURVIVE"
const OBJ_DESTROY := "DESTROY_ALL"
const OBJ_PUZZLE := "PHYSICS_PUZZLE"
const OBJ_COLLECT := "COLLECT_ALL"
const OBJ_PRECISION := "PRECISION_LAND"
const OBJ_TYPES := [OBJ_REACH, OBJ_SURVIVE, OBJ_DESTROY, OBJ_PUZZLE, OBJ_COLLECT, OBJ_PRECISION]

# PHYSICS_PUZZLE ball-state thresholds (mode-owned, NOT Tuning feel constants — a puzzle detail).
const BALL_REST_SPEED := 90.0     # below this the ball counts as "at rest" (a missed shot -> settle timer)
const BALL_LAUNCH_SPEED := 220.0  # above this the ball counts as "launched" (a blast punted it; arm reset)

# The authored course SET (ordered, played ONCE — no loop; the match ends after the last course).
const COURSE_SETS_PATH := "res://levels/course_sets.json"
const DEFAULT_SET_ID := "campaign"
const PROOF_SET: Array[String] = ["res://levels/courses/course_01_tank_run.json"]

var _course_set: Array = []
var _course_idx := 0                 # index of the NEXT course to serve (advanced in next_level_path)
var _cur_path := ""                  # the course currently loaded
var _cur_objective: Dictionary = {}     # the current course's "objective" block ({} => REACH_GOAL)
var _cur_hint := ""                  # optional top-level "hint" string — the tutorial teaching line
                                     # (owner 2026-07-16 circuit-1 tutorials); TrialsHUD shows it

# --- per-type live state (reset each course in next_level_path) ---
# SURVIVE: per-player. Each participant i has a survival base (_survive_base[i]); while dead it is pinned
# to round_clock so elapsed holds at 0 (a death is a weightless RETRY). Once elapsed >= target, the
# per-player _survived[i] latch is set STICKY (a later death never un-completes it). Gate = all survived.
var _survive_base: Array = []        # Array[float], indexed by participant
var _survived: Array = []            # Array[bool], sticky per participant
# DESTROY_ALL: how many destructibles the course started with (guards a 0-block instant-clear).
var _blocks_total := 0
# PHYSICS_PUZZLE: auto-reset bookkeeping so the ball can never be lost (unlimited attempts, no score).
var _ball = null                     # the spawned Ball; untyped so RigidBody2D props read
var _ball_spawn := Vector2.ZERO      # the "ball" object's spawn point (read from course JSON)
var _ball_launched := false          # has a blast punted the ball since the last (re)spawn?
var _settle_t := 0.0                 # seconds the ball has been at rest / out of bounds since launch
var _last_poll_clock := 0.0          # round_clock at the previous is_stage_over poll (for a dt estimate)
# COLLECT_ALL / PRECISION_LAND: totals captured at stage start (guard a 0-member vacuous clear).
var _pickups_total := 0
var _targets_total := 0

# --- identity / presentation ---
func id() -> StringName:
	return &"trials"

func display_name() -> String:
	return "TRIALS"

func hud_scene() -> PackedScene:
	return HUD_SCENE

## Additive seam: TRIALS ends a stage by satisfying the objective (no death), so the runner polls each frame.
func polls_goal() -> bool:
	return true

# --- match setup ---
func configure(runner, _config: MatchConfig) -> void:
	# HIGH lives so a fall consumes a life and the runner RESPAWNS the player (B.4 reuse of the existing
	# multi-life respawn path) instead of eliminating -> ending the stage. Never a kill-race. (KEEP — v10.)
	runner.lives_per_player = 99
	runner.match_target_kills = 999999   # so a stray on_kill can never trip the kill-race match end
	var set_id := DEFAULT_SET_ID
	if _config != null and str(_config.circuit_id) != "":
		set_id = str(_config.circuit_id)
	_course_set = _load_course_set(set_id)
	_course_idx = 0
	_cur_path = ""
	_cur_objective = {}

## Humans only, NO bots. v10: spawns human_count players — this IS the multi-player spawn (REACH_GOAL /
## SURVIVE run all-must-finish; the object-mutation types are single-player-recommended, §1.3).
func spawn_plan(_runner, config: MatchConfig) -> Array:
	var out: Array = []
	var n: int = clampi(config.human_count, 1, MatchConfig.MAX_FIGHTERS)   # WK-02 roster cap
	for i in range(n):
		out.append({
			"human": true, "skin": config.skin_for(i), "character": config.character_for(i),
			"bot_level": 0, "seed_damage": 0, "team": 0,
		})
	return out

# --- stage lifecycle ---

## The next course in authored order, played once. Caches the objective block ({} => REACH_GOAL) and
## resets all per-type live state so a fresh course never inherits the previous course's state. (A fresh
## GoalGate is built by _load_stage, so per-player `home` sets reset automatically.)
func next_level_path(_runner) -> String:
	if _course_set.is_empty():
		return ""
	_cur_path = str(_course_set[_course_idx % _course_set.size()])
	_course_idx += 1
	_cur_objective = _read_objective(_cur_path)
	_cur_hint = _read_hint(_cur_path)
	_survive_base = []
	_survived = []
	_blocks_total = 0
	_ball = null
	_ball_spawn = _read_ball_spawn(_cur_path)
	_ball_launched = false
	_settle_t = 0.0
	_last_poll_clock = 0.0
	_pickups_total = 0
	_targets_total = 0
	return _cur_path

## The stage-over test, DISPATCHED on the course's objective type (v10 §1.2). Binary completion: the
## course is over when EVERY living participant has satisfied the objective (all-must-finish). REACH_GOAL
## and SURVIVE aggregate per-player; the four object-mutation types keep v7's global clear (solo, §1.3).
func is_stage_over(runner) -> bool:
	match _objective_type():
		OBJ_SURVIVE:
			return _survive_cleared(runner)
		OBJ_REACH:
			return _reach_cleared(runner)
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
			return _reach_cleared(runner)

## v10: a fall is a pure RESPAWN with ZERO penalty for every type. SURVIVE additionally resets only the
## VICTIM's own survival clock (a weightless retry) — using _victim_idx, never assuming player 0. No time,
## score, or medal is ever mutated. (A player already `_survived` is sticky and is NOT reset.)
func on_kill(runner, _killer_idx: int, victim_idx: int, _cause) -> void:
	if _objective_type() == OBJ_SURVIVE:
		if victim_idx >= 0 and victim_idx < _survive_base.size() and not bool(_survived[victim_idx]):
			_survive_base[victim_idx] = float(runner.round_clock)

## Newly overridden seam (already exists on GameMode; SPORTS uses it). Per-type stage-start setup:
## PHYSICS_PUZZLE spawns the Ball; DESTROY_ALL/COLLECT_ALL/PRECISION_LAND capture group totals; SURVIVE
## sizes its per-player arrays to the spawned participants. REACH_GOAL falls through to a no-op.
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
		OBJ_SURVIVE:
			_init_survive(runner)
		_:
			pass

## Player 0 once the LAST course's objective is complete (the whole set is done). -1 while courses remain
## OR the current course is not yet complete (so a fall never trips a false match end). With the all-home
## gate this fires only when EVERY participant is done.
func match_winner(runner) -> int:
	if _course_idx >= _course_set.size() and is_stage_over(runner):
		return 0
	return -1

## Per-course clear banner — BINARY, no number/medal (v10 §5). One line per type.
func stage_end_banner(_runner) -> Dictionary:
	var text := "COURSE CLEAR!"
	match _objective_type():
		OBJ_SURVIVE:
			text = "EVERYONE SURVIVED!"
		OBJ_DESTROY:
			text = "ALL CLEAR!"
		OBJ_PUZZLE:
			text = "SOLVED!"
		OBJ_COLLECT:
			text = "ALL COLLECTED!"
		OBJ_PRECISION:
			text = "ALL LANDED!"
	return {"text": text, "color": Color("#ffd23f")}

## The set summary — BINARY (v10 §5): no total time, no medal tallies.
func match_end_banner(_runner) -> Dictionary:
	return {"text": "TRIALS COMPLETE!", "color": Color("#ffd23f"), "subline": "All courses cleared."}

# --- HUD read surface (TrialsHUD polls these via runner._mode) ---

## The current course's objective type; ABSENT/unknown => REACH_GOAL (the back-compat resolution).
func objective_type() -> String:
	return _objective_type()

## The current course's tutorial hint line ("" = none). TrialsHUD gives it the sub-readout slot.
func hint() -> String:
	return _cur_hint

func _objective_type() -> String:
	var t := str(_cur_objective.get("type", OBJ_REACH)).to_upper()
	return t if t in OBJ_TYPES else OBJ_REACH

## Every currently-valid player slot the course spawned (v10 "participant"). TRIALS never eliminates, so
## this stays the full spawned set for the whole course (a mid-respawn player is still a participant).
func _participants(runner) -> Array:
	var out: Array = []
	for p in runner.players:
		if is_instance_valid(p):
			out.append(p)
	return out

func participant_count(runner) -> int:
	return _participants(runner).size()

## Whether participant i is `done` for the current objective (drives the per-player HOME pip). REACH =
## a goal_gate has_player(i); SURVIVE = _survived[i]; the solo object-mutation types = the global clear
## (the whole world condition, applied to the one player).
func player_done(runner, i: int) -> bool:
	if i < 0 or i >= runner.players.size():
		return false
	var p = runner.players[i]
	if not is_instance_valid(p):
		return false
	match _objective_type():
		OBJ_SURVIVE:
			return i < _survived.size() and bool(_survived[i])
		OBJ_REACH:
			return _player_home(runner, p)
		_:
			return is_stage_over(runner)   # solo types: the shared world condition is the done state

## Count of participants currently `done` (for the "n of N HOME" tracker).
func home_count(runner) -> int:
	var c := 0
	for i in range(runner.players.size()):
		if is_instance_valid(runner.players[i]) and player_done(runner, i):
			c += 1
	return c

# SURVIVE per-player progress (0..1) toward the survive target — drives the HUD progress ring.
func survive_target() -> float:
	return float(_cur_objective.get("survive_seconds", 20.0))

func survive_ratio(runner, i: int) -> float:
	if i < 0 or i >= _survive_base.size():
		return 0.0
	if i < _survived.size() and bool(_survived[i]):
		return 1.0
	var tgt := survive_target()
	if tgt <= 0.0:
		return 1.0
	return clampf((float(runner.round_clock) - float(_survive_base[i])) / tgt, 0.0, 1.0)

# Neutral live readouts (no clock, no score).
func blocks_remaining(runner) -> int:
	return runner.get_tree().get_nodes_in_group("destructible").size()

func tokens_total() -> int:
	return _pickups_total

func tokens_collected(runner) -> int:
	return _flagged_count(runner, "trials_pickup", "collected")

func pads_total() -> int:
	return _targets_total

func pads_landed(runner) -> int:
	return _flagged_count(runner, "trials_target", "landed")

## Camera focus points (owner 2026-07-19): the default player-cluster camera zoomed so tight the
## player couldn't SEE the trial goal ("I don't know where to send the ball"). For the point-target
## objective types, the goal joins the frame: REACH_GOAL -> every goal_gate; PHYSICS_PUZZLE -> every
## goal_zone + the live ball; PRECISION_LAND -> every un-landed pad. DESTROY_ALL / COLLECT_ALL /
## SURVIVE stay default (their objectives are scattered across the whole course — framing them all
## would just be a permanent full-course zoom-out).
func camera_focus_points(runner) -> Array:
	var pts: Array = []
	match _objective_type():
		OBJ_REACH:
			for g in runner.get_tree().get_nodes_in_group("goal_gate"):
				pts.append((g as Node2D).global_position)
		OBJ_PUZZLE:
			for z in runner.get_tree().get_nodes_in_group("goal_zone"):
				pts.append((z as Node2D).global_position)
			if is_instance_valid(_ball):
				pts.append((_ball as Node2D).global_position)
		OBJ_PRECISION:
			for t in runner.get_tree().get_nodes_in_group("trials_target"):
				if not bool(t.get("landed")):
					pts.append((t as Node2D).global_position)
		_:
			pass
	return pts

# --- per-type clear tests ---

## True once player p has entered ANY goal_gate (sticky, per-player).
func _player_home(runner, p) -> bool:
	for g in runner.get_tree().get_nodes_in_group("goal_gate"):
		if g.has_method("has_player") and g.has_player(p):
			return true
	return false

## REACH_GOAL: complete when EVERY living participant has entered some goal_gate (all-must-finish, v10
## §2.1). Guards participants > 0 (no players => never complete).
func _reach_cleared(runner) -> bool:
	var parts := _participants(runner)
	if parts.is_empty():
		return false
	for p in parts:
		if not _player_home(runner, p):
			return false
	return true

## Size + zero the per-player SURVIVE arrays to the current participant count.
func _init_survive(runner) -> void:
	var n: int = runner.players.size()
	_survive_base = []
	_survived = []
	for _i in range(n):
		_survive_base.append(float(runner.round_clock))
		_survived.append(false)

## SURVIVE: per-player sticky survival (v10 §2.2). Each frame, for each participant i not yet survived:
## while dead (respawning) pin the base to round_clock so elapsed holds at 0 (a weightless retry); once
## elapsed >= target, latch _survived[i] STICKY. Complete when EVERY participant has survived.
func _survive_cleared(runner) -> bool:
	if _survive_base.is_empty():
		_init_survive(runner)
	var tgt := survive_target()
	var any := false
	var all := true
	for i in range(runner.players.size()):
		var p = runner.players[i] if i < runner.players.size() else null
		if not is_instance_valid(p):
			continue
		any = true
		if i >= _survived.size():
			all = false
			continue
		if bool(_survived[i]):
			continue
		if p.has_method("is_dead") and p.is_dead():
			_survive_base[i] = float(runner.round_clock)   # pin: progress holds at 0 while dead
			all = false
		elif (float(runner.round_clock) - float(_survive_base[i])) >= tgt:
			_survived[i] = true                            # sticky latch
		else:
			all = false
	return any and all

## PHYSICS_PUZZLE: cleared when any goal_zone latched `scored` (the SPORTS latch, verbatim). Otherwise
## runs the auto-reset bookkeeping so the ball can never be permanently lost — after a blast LAUNCHES it,
## if it then rests / leaves bounds without scoring for reset_settle_s, respawn it (unlimited attempts,
## no score). (v10 §2.4 — even more valuable without a clock: there is literally unlimited solve time.)
func _puzzle_cleared(runner) -> bool:
	for z in runner.get_tree().get_nodes_in_group("goal_zone"):
		if z.scored:
			return true
	var dt: float = maxf(0.0, float(runner.round_clock) - _last_poll_clock)
	_last_poll_clock = float(runner.round_clock)
	if is_instance_valid(_ball):
		var spd: float = (_ball.linear_velocity as Vector2).length()
		var settle_target: float = float(_cur_objective.get("reset_settle_s", 2.5))
		var oob: bool = not runner.bounds.grow(200.0).has_point(_ball.global_position)
		if oob:
			_settle_t += dt
			if _settle_t >= settle_target:
				_reset_puzzle(runner)
		elif spd >= BALL_LAUNCH_SPEED:
			_ball_launched = true
			_settle_t = 0.0
		elif _ball_launched and spd < BALL_REST_SPEED:
			_settle_t += dt
			if _settle_t >= settle_target:
				_reset_puzzle(runner)
		else:
			_settle_t = 0.0
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

func _flagged_count(runner, group: String, flag: String) -> int:
	var c := 0
	for n in runner.get_tree().get_nodes_in_group(group):
		if bool(n.get(flag)):
			c += 1
	return c

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

## Read the optional top-level "hint" teaching line from a course JSON ("" on any failure).
func _read_hint(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	return str((parsed as Dictionary).get("hint", ""))

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
