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

# +2.0s per out-of-bounds fall (design value, spec B.2). NOT a Tuning FEEL constant — it is the mode's
# own run-clock penalty (the run clock is the score here), so it lives with the mode, per the fence.
const FALL_PENALTY := 2.0

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

# per-course run state (reset each course in next_level_path)
var run_penalty := 0.0               # accumulated time penalty on the current course (falls)
var attempts := 0                    # falls on the current course (the "attempt" counter, HUD)

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
	_course_set = _load_course_set(DEFAULT_SET_ID)
	_course_idx = 0
	_cur_path = ""
	_cur_medal_times = {}
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
	return _cur_path

## TRUE when the human touches the course GOAL gate (course cleared) — NOT last-one-standing. A fall
## does not satisfy this (it triggers a respawn). Reads the live GoalGate(s) via the "goal_gate" group.
func is_stage_over(runner) -> bool:
	for g in runner.get_tree().get_nodes_in_group("goal_gate"):
		if g.reached:
			return true
	return false

## No kill-race scoring. A "death" here = a fall out of bounds (killer is always self / -1). Record a
## time penalty onto the run clock + tick the attempt counter; do NOT mutate runner.scores.
func on_kill(_runner, _killer_idx: int, _victim_idx: int, _cause) -> void:
	run_penalty += FALL_PENALTY
	attempts += 1

## Player 0 once the LAST course's goal has been cleared (the whole set is complete). -1 while courses
## remain OR the current course's goal is not yet reached (so a fall never trips a false match end).
func match_winner(runner) -> int:
	if _course_idx >= _course_set.size() and is_stage_over(runner):
		return 0
	return -1

## Per-course result banner: the run time + medal earned. (Also records the result for BEST + summary.)
func stage_end_banner(runner) -> Dictionary:
	var t := current_time(runner)
	var medal := medal_for(t)
	var prev: float = float(_best_times.get(_cur_path, INF))
	if t < prev:
		_best_times[_cur_path] = t
	_course_results.append({"path": _cur_path, "time": t, "medal": medal})
	var label := medal.to_upper() if medal != "none" else "CLEAR"
	return {"text": "COURSE CLEAR!  %.1fs  —  %s" % [t, label],
		"color": MEDAL_COLORS.get(medal, Color.WHITE)}

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

# --- internals ---

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
