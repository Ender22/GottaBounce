class_name BrawlMode
extends GameMode
## BRAWL — the first (Phase-1 only) GameMode: a VERBATIM extraction of today's inlined PartyMatch
## rules (v1_frontend_shell §3.3). "Move, don't change" — every method returns exactly what the
## corresponding runner code did before the seam existed. Parity is proven by C7.
##
## Rules: last-one-flying stages, CUMULATIVE kill-race to `kills_to_win` with a strict lead, +1 per
## credited kill / -1 self-fall floored at 0. Level rotation = a shuffle-bag over the arena pool
## (RANDOM_ALL) or a fixed single arena (SINGLE). Sudden-death plumbing stays in the runner.

const HUD_SCENE := preload("res://scenes/ui/MatchHUD.tscn")

# shuffle-bag level rotation (moved verbatim from PartyMatch._reset_bag/_next_level_path)
var _pool: Array = []
var _bag: Array = []
var _last_level_path := ""

# --- identity / presentation ---
func id() -> StringName:
	return &"brawl"

func display_name() -> String:
	return "BRAWL"

func hud_scene() -> PackedScene:
	return HUD_SCENE

# --- match setup ---
func configure(runner, config: MatchConfig) -> void:
	# read config into the runner (defaults reproduce Tuning.match_target_kills / lives_per_player)
	runner.match_target_kills = config.kills_to_win
	runner.lives_per_player = config.lives_per_player
	# build the level sequence: SINGLE -> one arena; RANDOM_ALL (default) -> the whole pool
	if config.arena_mode == MatchConfig.ArenaMode.SINGLE and str(config.single_arena_path) != "":
		_pool = [config.single_arena_path]
	else:
		_pool = runner.LEVEL_POOL.duplicate()
	_reset_bag()

## Per-slot descriptors: humans first, then bots (today's spawn order). Skin/character indexed by
## player from the config; bot level = Tuning.bot_levels rotation when difficulty 0 (today), else fixed.
func spawn_plan(_runner, config: MatchConfig) -> Array:
	var out: Array = []
	for i in range(config.human_count):
		out.append({
			"human": true, "skin": config.skin_for(i), "character": config.character_for(i),
			"bot_level": 0, "seed_damage": 0, "team": 0,
		})
	for b in range(config.bot_count):
		var i := config.human_count + b
		var lvl: int
		if config.bot_difficulty == 0:
			lvl = Tuning.bot_levels[b % Tuning.bot_levels.size()]   # today's mixed [2,3,4] rotation
		else:
			lvl = clampi(config.bot_difficulty, 1, 5)               # fixed level for all bots (§2.3)
		out.append({
			"human": false, "skin": config.skin_for(i), "character": config.character_for(i),
			"bot_level": lvl, "seed_damage": 0, "team": 0,
		})
	return out

# --- stage lifecycle ---

func _reset_bag() -> void:
	_bag = _pool.duplicate()
	_bag.shuffle()

## Draw the next level from the shuffle-bag; reshuffle when empty, avoiding an immediate repeat when
## the pool has >=2 entries. A 1-entry pool (SINGLE) returns that level every time (no rotation).
func next_level_path(_runner) -> String:
	if _bag.is_empty():
		_reset_bag()
		if _pool.size() >= 2 and _bag.size() > 1 and str(_bag[0]) == _last_level_path:
			_bag.append(_bag.pop_front())
	var path: String = str(_bag.pop_front())
	_last_level_path = path
	return path

## BRAWL: a stage is over when <= 1 player is not-eliminated (last-one-standing).
func is_stage_over(runner) -> bool:
	return runner._not_eliminated_count() <= 1

## Scoring (today's _on_killed math): +1 credited kill / -1 self-fall floored at 0. CUMULATIVE.
func on_kill(runner, killer_idx: int, victim_idx: int, _cause) -> void:
	if killer_idx >= 0 and killer_idx != victim_idx:
		runner.scores[killer_idx] = int(runner.scores[killer_idx]) + 1
		runner._stage_deltas[killer_idx] = int(runner._stage_deltas[killer_idx]) + 1
	elif int(runner.scores[victim_idx]) > 0:   # suicide: -1 to your own total, floored at 0
		runner.scores[victim_idx] = int(runner.scores[victim_idx]) - 1
		runner._stage_deltas[victim_idx] = int(runner._stage_deltas[victim_idx]) - 1

## The single leader at >= kills_to_win, or -1 (today's _match_over_leader, strict-lead rule).
func match_winner(runner) -> int:
	var mx := -1
	var leaders := 0
	var widx := -1
	for i in range(runner.scores.size()):
		var s := int(runner.scores[i])
		if s > mx:
			mx = s
			leaders = 1
			widx = i
		elif s == mx:
			leaders += 1
	if mx >= runner.match_target_kills and leaders == 1:
		return widx
	return -1

func stage_end_banner(runner) -> Dictionary:
	if runner._stage_winner >= 0:
		return {"text": "P%d SURVIVES!" % (runner._stage_winner + 1),
			"color": runner.PLAYER_COLORS[runner._stage_winner]}
	return {"text": "NOBODY SURVIVES", "color": Color.WHITE}

func match_end_banner(runner) -> Dictionary:
	var widx: int = runner._match_winner
	return {"text": "P%d WINS THE MATCH!" % (widx + 1),
		"color": runner.PLAYER_COLORS[widx], "subline": runner._scoreline()}
