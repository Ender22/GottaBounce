class_name GauntletMode
extends GameMode
## GAUNTLET — survival vs escalating waves of bots (docs/specs/v4_gauntlet_mode.md). The third mode
## (after BRAWL / TRIALS) and the first PvE survival mode. REUSES Player, InputBot (levels 1-5), the
## shipped arenas, the kill pipeline, and the runner's multi-life respawn. A wave IS a runner STAGE:
## STAGE_END/INTRO/COUNTDOWN supply the free "WAVE N CLEARED!" breather + re-arm beat.
##
## The score is WAVES SURVIVED (the highest wave reached), not kills. Clearing a wave = eliminating all
## its attacker bots (smash them off the void). A shared, run-scoped DEFENDER LIFE POOL (mode-owned, the
## TRIALS pattern: the runner keeps humans respawning via a dummy-high lives_per_player; the mode owns
## the real economy). DEFEAT when a defender goes down with the pool empty; VICTORY on clearing the
## final wave. No fenced Tuning constant is read or written.
##
## The dynamic per-wave bot roster is the ONE genuinely-new runner capability: wave_spawn_plan() (the
## single additive hook), consumed in PartyMatch._begin_stage(), reusing _spawn_player + _despawn_bots.

const HUD_SCENE := preload("res://scenes/ui/GauntletHUD.tscn")

# Wave DATA (mirrors circuits.json / course_sets.json). PROOF fallback keeps the mode ALWAYS runnable.
const WAVE_SETS_PATH := "res://levels/gauntlet_waves.json"
const DEFAULT_SET_ID := "campaign"
const DEFAULT_ARENA := "res://levels/islands_void.json"
# a tiny always-runnable fallback (2 waves) if the data file is missing/malformed (TRIALS pattern)
const PROOF_WAVES: Array = [[1, 1], [2, 2]]

const GOLD := Color("#ffd23f")
const DANGER := Color("#ff4b3a")
# bot skin cycle (cosmetic identity only; PLAYER_COLORS in the runner drives the on-field hue by index)
const BOT_SKINS := ["blue", "green", "yellow", "purple", "orange"]

# the wave roster: Array of Array-of-int (bot levels per wave)
var _waves: Array = []
var _arena_path := DEFAULT_ARENA

# the run-scoped defender life POOL (the real economy; NOT reset between waves)
var defender_lives := 4

# run state
var _run_over := false            # a fatal human death (pool empty) -> DEFEAT
var _victory := false             # final wave cleared -> VICTORY
var _highest_wave := 1            # the wave in progress when the run ended (score / defeat sub-line)

# --- identity / presentation ---
func id() -> StringName:
	return &"gauntlet"

func display_name() -> String:
	return "GAUNTLET"

func hud_scene() -> PackedScene:
	return HUD_SCENE

## The wave-clear can leave 2+ humans alive (co-op) — a state the death-driven _decide_stage_end path
## never reaches. Polling ends the stage the instant the last bot dies, for any human count.
func polls_goal() -> bool:
	return true

# --- match setup ---
## Idempotent (called in _ready AND on rematch in _start_match). Reads the defender pool from the reused
## lives_per_player field, forces the runner's own life/kill economy to dummy-high so it never eliminates
## a defender or trips a kill-race end, loads the wave plan, resolves the arena, resets run state.
func configure(runner, config: MatchConfig) -> void:
	defender_lives = maxi(0, config.lives_per_player)
	# the RUNNER must never eliminate a defender or end on a kill-race (the MODE owns the economy)
	runner.lives_per_player = 99
	runner.match_target_kills = 999999
	_waves = _load_wave_set(config)
	_arena_path = str(config.single_arena_path) if str(config.single_arena_path) != "" else DEFAULT_ARENA
	_run_over = false
	_victory = false
	_highest_wave = 1

## Humans ONLY at configure-time (no bots — waves spawn dynamically via wave_spawn_plan). v1 = 1 human
## (solo); co-op = config.human_count humans, same plan.
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
## Single arena for v1 (mastery + fast smash-clears): the same arena every wave.
func next_level_path(_runner) -> String:
	return _arena_path

## THE NEW HOOK: bot descriptors for the wave about to begin (runner.stage_index, 1-based). Out of range
## (past the last wave) -> [] (defensive; the match has already ended in victory by then).
func wave_spawn_plan(runner) -> Array:
	var w: int = int(runner.stage_index)
	if w < 1 or w > _waves.size():
		return []
	var out: Array = []
	var levels: Array = _waves[w - 1]
	for k in range(levels.size()):
		var lvl: int = clampi(int(levels[k]), 1, 5)
		out.append({
			"human": false, "skin": BOT_SKINS[k % BOT_SKINS.size()], "character": "bouncer",
			"bot_level": lvl, "seed_damage": 0, "team": 1,
		})
	return out

## A wave is over when no not-eliminated bots remain (all attackers smashed off). Polled every combat
## frame via polls_goal().
func is_stage_over(runner) -> bool:
	return _bots_alive(runner) == 0

## Runs BEFORE the runner's own life-decrement (PartyMatch._on_killed calls the mode first, then
## decrements). Bot victim -> force its runner life to 1 so the -=1 eliminates it FOR THE WAVE (regardless
## of the dummy-high lives_per_player). Human victim -> spend a defender life (runner respawns it), or, if
## the pool is empty, mark the run over (DEFEAT, resolved by match_winner THIS death). Never touches scores.
func on_kill(runner, _killer_idx: int, victim_idx: int, _cause) -> void:
	if victim_idx < 0 or victim_idx >= runner.players.size():
		return
	var victim = runner.players[victim_idx]
	if is_instance_valid(victim) and victim.is_in_group("human"):
		if defender_lives > 0:
			defender_lives -= 1        # runner will respawn (its dummy-high lives_left keeps the human in)
		else:
			_run_over = true           # fatal — DEFEAT resolves in match_winner before the runner's SD path
			_highest_wave = int(runner.stage_index)
	else:
		runner.lives_left[victim_idx] = 1   # -> the runner's -=1 makes it 0 -> eliminated for the wave

## DEFEAT on the fatal human death (returns 0 immediately, before the double-KO SD path can misfire).
## Else VICTORY when the FINAL wave is cleared, guarded to the STAGE_END freeze so a mid-combat on_kill
## can never declare premature victory. Else -1 (match not over).
func match_winner(runner) -> int:
	if _run_over:
		return 0
	if runner.state == "STAGE_END" and int(runner.stage_index) >= _waves.size() and _bots_alive(runner) == 0:
		_victory = true
		return 0
	return -1

func stage_end_banner(runner) -> Dictionary:
	return {"text": "WAVE %d CLEARED!" % int(runner.stage_index), "color": GOLD}

func match_end_banner(_runner) -> Dictionary:
	if _victory:
		return {"text": "ALL WAVES CLEARED!", "color": GOLD,
			"subline": "SIEGE REPELLED — %d WAVES" % _waves.size()}
	return {"text": "OVERWHELMED", "color": DANGER, "subline": "REACHED WAVE %d" % _highest_wave}

# --- HUD read helpers (GauntletHUD polls these via runner._mode each frame) ---

## Count of live attacker bots (not in group "human", lives_left > 0, valid). Same predicate family as
## the runner's _not_eliminated_count.
func _bots_alive(runner) -> int:
	var n := 0
	for i in range(runner.players.size()):
		var p = runner.players[i]
		if is_instance_valid(p) and not p.is_in_group("human") and int(runner.lives_left[i]) > 0:
			n += 1
	return n

func current_wave(runner) -> int:
	return maxi(1, int(runner.stage_index))

func enemies_remaining(runner) -> int:
	return _bots_alive(runner)

func wave_count() -> int:
	return _waves.size()

# --- internals ---
## Load the wave set (ordered Array of level-lists) + arena from gauntlet_waves.json by set id. Falls
## back to PROOF_WAVES on any failure so the mode is ALWAYS runnable (the TRIALS pattern).
func _load_wave_set(config: MatchConfig) -> Array:
	var set_id := DEFAULT_SET_ID
	if FileAccess.file_exists(WAVE_SETS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WAVE_SETS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			var sets: Variant = (parsed as Dictionary).get("sets", {})
			if typeof(sets) == TYPE_DICTIONARY and (sets as Dictionary).has(set_id):
				var entry: Variant = (sets as Dictionary)[set_id]
				if typeof(entry) == TYPE_DICTIONARY:
					# arena override (else the default) — only when config didn't specify one
					if str(config.single_arena_path) == "":
						var a: Variant = (entry as Dictionary).get("arena", "")
						if str(a) != "" and FileAccess.file_exists(str(a)):
							_arena_path = str(a)
					var waves: Variant = (entry as Dictionary).get("waves", [])
					if typeof(waves) == TYPE_ARRAY:
						var out: Array = []
						for w in (waves as Array):
							if typeof(w) == TYPE_DICTIONARY:
								var lv: Variant = (w as Dictionary).get("levels", [])
								if typeof(lv) == TYPE_ARRAY and not (lv as Array).is_empty():
									var row: Array = []
									for x in (lv as Array):
										row.append(clampi(int(x), 1, 5))
									out.append(row)
						if not out.is_empty():
							return out
	push_warning("GauntletMode: gauntlet_waves.json unusable for set '" + set_id + "' — using proof waves")
	return PROOF_WAVES.duplicate(true)
