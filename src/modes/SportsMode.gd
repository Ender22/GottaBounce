class_name SportsMode
extends GameMode
## SPORTS (docs/specs/v5_sports_mode.md) — the fourth GameMode. Two teams knock a big bouncy BALL into
## the enemy GOAL; first team to N goals wins. It is the movement game with the KILL replaced by the
## GOAL: fly/bounce/smash to move the BALL, not to kill. Players NEVER die (lives forced high -> instant
## respawn, the TRIALS/GAUNTLET pattern; no elimination, no sudden death). A goal = a runner STAGE
## (reuse STAGE_END -> kickoff, exactly as GAUNTLET maps a wave and TRIALS a course).
##
## Fills the SAME seam methods as BRAWL/TRIALS/GAUNTLET. The ONLY new runner capability is the additive
## on_stage_ready() hook (spec §4.1), which (re)spawns the Ball at centre + snaps teams to their ends
## each kickoff. No fenced Tuning constant is read or written (the field-gravity READ the Ball does is
## the same read StormBall/Player already do). All ball physics/drive constants are mode-owned on Ball.gd.

const HUD_SCENE := preload("res://scenes/ui/SportsHUD.tscn")
const BALL_SCRIPT := preload("res://src/entities/Ball.gd")
const DEFAULT_ARENA := "res://levels/sports_court.json"
# The court-set library (v8_sports_courts.md §4). Mirrors circuits.json: SportsMode reads it to
# resolve a court SELECTION (a court id, a rotate-set ref, or a direct path) into the arena path,
# preserving the CD #7 fallback (any unresolved/locked/missing -> DEFAULT_ARENA, never a crash).
const COURT_SET_PATH := "res://levels/sports_courts.json"

# team presentation (matches GoalZone.TEAM_COLORS)
const TEAM_NAMES := ["RED", "BLUE"]
const TEAM_COLORS := [Color("#ff4b6a"), Color("#3fa9ff")]
# team colorway skins (spec §4: warm = team 0, cool = team 1) so teammates read as one side
const TEAM_SKINS := [["pink", "orange"], ["blue", "purple"]]

# --- mode-owned state (spec §4) ---
var _team_scores: Array = [0, 0]
var _teams: Array = []                 # index -> team (0/1), built in spawn_plan (plan[i] -> player i)
var _goal_cap: int = 6                  # fallback; the live cap is set in configure() from Tuning.sports_goal_target
var _arena_path: String = DEFAULT_ARENA
var _last_scoring_team: int = -1
var _last_scored_stage: int = -1       # idempotency guard: increment at most once per stage

var _ball: Ball = null                 # the live stage ball (freed + re-created each kickoff)
var _court_set_cache: Dictionary = {}  # parsed sports_courts.json (lazy; {by_id, default_path, rotate})

# --- bot-objective geometry (mode-owned, NOT fenced player-feel Tuning — this is WHERE to go, the
# bot's existing movement/boost carries it there). To hit the ball toward the ENEMY goal a bot must
# contact it from the side AWAY from that goal, so it flies to a point behind the ball; once basically
# on the ball it aims THROUGH it toward the goal (a boosting/super/hitstun contact = a power shot). ---
const BOT_APPROACH_OFFSET := 150.0     # how far BEHIND the ball (away from enemy goal) the strike point sits
const BOT_ON_BALL_DIST := 240.0        # within this of the ball -> stop lining up, drive THROUGH it goalward
const BOT_DRIVE_THROUGH := 220.0       # how far PAST the ball (toward goal) to aim when driving through

# --- identity / presentation ---
func id() -> StringName:
	return &"sports"

func display_name() -> String:
	return "SPORTS"

func hud_scene() -> PackedScene:
	return HUD_SCENE

## The runner polls is_stage_over() every combat frame and ends the stage on a goal — no death required
## (the SAME hook TRIALS/GAUNTLET flip; BRAWL stays false -> C7 parity).
func polls_goal() -> bool:
	return true

# --- match setup ---
## Force the runner's own economy inert so it NEVER eliminates or ends on a kill-race (TRIALS/GAUNTLET
## pattern): high lives -> any rare out-of-bounds is an instant respawn; huge kill target -> a stray
## on_kill can never trip the kill-race end. The goal cap is Tuning.sports_goal_target — SPLIT from the
## shared config.kills_to_win knob so Sports pacing (~6 goals) is independent of the OWNER-SET BRAWL kill
## target (10). SPORTS has no in-UI target stepper (its settings tray is hidden), so this is the only
## source of the goal cap. Idempotent.
func configure(runner, config: MatchConfig) -> void:
	runner.lives_per_player = 99
	runner.match_target_kills = 999999
	_goal_cap = maxi(1, Tuning.sports_goal_target)
	# Defensive arena resolution (CD robustness fix): SPORTS is an ENCLOSED-court mode; if it ever loads a
	# non-enclosed / missing level the ball falls through the world forever. Default to the sports court
	# whenever the configured path is empty, whitespace, or points at a file that does not exist.
	var want: String = str(config.single_arena_path).strip_edges() if config != null else ""
	_arena_path = _resolve_court(want)
	_team_scores = [0, 0]
	_last_scoring_team = -1
	_last_scored_stage = -1

## Resolve a court SELECTION to an arena PATH via the court-set (v8_sports_courts.md §4.2), keeping the
## CD #7 robustness fallback: SPORTS is an ENCLOSED-court mode, so ANY unresolved / locked / missing
## selection resolves to the default court (never a crash, never the ball-through-world bug). Accepts,
## in priority order: (1) "" -> the set's default court; (2) "<anything>#key" -> a random UNLOCKED
## member of that rotate_set (§4.2 rotate flow); (3) a known court ID from sports_courts.json (if
## unlocked + its file exists); (4) a direct res:// path to an existing file (the ArenaSelect flow).
func _resolve_court(want: String) -> String:
	var set_data := _load_court_set()
	var default_path: String = str(set_data.get("default_path", DEFAULT_ARENA))
	if want == "":
		return default_path
	if want.contains("#"):
		var pick := _pick_from_rotate(set_data, want.get_slice("#", 1))
		return pick if pick != "" else default_path
	var by_id: Dictionary = set_data.get("by_id", {})
	if by_id.has(want):
		var c: Dictionary = by_id[want]
		if _court_unlocked(str(c.get("id", want))):
			var p := str(c.get("path", ""))
			if p != "" and FileAccess.file_exists(p):
				return p
		return default_path
	if FileAccess.file_exists(want):
		return want
	return default_path

## Parse + cache sports_courts.json into {by_id: {id->court dict}, default_path, rotate: {key->[ids]}}.
## Absent / malformed file -> a safe stub whose default_path is DEFAULT_ARENA (back-compat).
func _load_court_set() -> Dictionary:
	if not _court_set_cache.is_empty():
		return _court_set_cache
	var out := {"by_id": {}, "default_path": DEFAULT_ARENA, "rotate": {}}
	if FileAccess.file_exists(COURT_SET_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COURT_SET_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			var d := parsed as Dictionary
			var by_id := {}
			var courts: Variant = d.get("courts", [])
			if typeof(courts) == TYPE_ARRAY:
				for c in (courts as Array):
					if typeof(c) == TYPE_DICTIONARY and str((c as Dictionary).get("id", "")) != "":
						by_id[str((c as Dictionary)["id"])] = c
			out["by_id"] = by_id
			var dc := str(d.get("default_court", ""))
			if by_id.has(dc):
				out["default_path"] = str((by_id[dc] as Dictionary).get("path", DEFAULT_ARENA))
			var rot: Variant = d.get("rotate_sets", {})
			if typeof(rot) == TYPE_DICTIONARY:
				out["rotate"] = rot
	_court_set_cache = out
	return out

## Random UNLOCKED court path from a rotate_set (§4.2). "" if the key is unknown or every member is
## locked / missing (caller falls back to the default court).
func _pick_from_rotate(set_data: Dictionary, key: String) -> String:
	var rot: Dictionary = set_data.get("rotate", {})
	if not rot.has(key) or typeof(rot[key]) != TYPE_ARRAY:
		return ""
	var by_id: Dictionary = set_data.get("by_id", {})
	var pool: Array = []
	for cid in (rot[key] as Array):
		var s := str(cid)
		if by_id.has(s) and _court_unlocked(s):
			var p := str((by_id[s] as Dictionary).get("path", ""))
			if p != "" and FileAccess.file_exists(p):
				pool.append(p)
	if pool.is_empty():
		return ""
	return str(pool[randi() % pool.size()])

## Unlock gate (§4.3), delegated to Settings.is_court_unlocked (the v6 progression tie-in). Defaults
## OPEN if the API is absent so selection never hard-locks in an odd build state.
func _court_unlocked(court_id: String) -> bool:
	if Settings != null and Settings.has_method("is_court_unlocked"):
		return bool(Settings.is_court_unlocked(court_id))
	return true

## Humans first, then bots, clamped to an EVEN total >= 2 (spec §1; clamp + log, never crash). Build
## _teams in the SAME order the runner spawns (plan[i] -> player i), splitting the roster in half. Each
## descriptor sets `team` (reused field) + a team colorway skin so teammates read as one side.
func spawn_plan(_runner, config: MatchConfig) -> Array:
	var humans: int = maxi(0, config.human_count)
	var bots: int = maxi(0, config.bot_count)
	var total: int = humans + bots
	if total < 2:
		bots += (2 - total)
		total = humans + bots
	if total % 2 == 1:
		# clamp to the nearest even total: drop a bot if we can, else add one (can't drop a human)
		if bots > 0:
			bots -= 1
		else:
			bots += 1
		total = humans + bots
		push_warning("SportsMode: odd team total -> clamped to even (%d humans + %d bots = %d)" % [humans, bots, total])
	var half: int = total / 2
	_teams = []
	var out: Array = []
	for i in range(total):
		var team: int = 0 if i < half else 1
		_teams.append(team)
		var within: int = i if team == 0 else i - half
		var skin: String = TEAM_SKINS[team][within % TEAM_SKINS[team].size()]
		var is_human: bool = i < humans
		var lvl: int = 0
		if not is_human:
			# Skill BALANCE across teams (fairness fix): index the mixed bot-level rotation by the
			# player's WITHIN-team slot, not the global bot sequence. This makes the k-th bot on team 0
			# and the k-th bot on team 1 draw the SAME level, so bot-vs-bot teams are skill-mirrored. The
			# old (i - humans) sequence handed the whole second half (always team 1) the higher levels
			# (e.g. the L4 menace), a per-team skill edge to BLUE on top of the geometry bias.
			lvl = clampi(config.bot_difficulty, 1, 5) if config.bot_difficulty > 0 else Tuning.bot_levels[within % Tuning.bot_levels.size()]
		out.append({
			"human": is_human, "skin": skin, "character": config.character_for(i),
			"bot_level": lvl, "seed_damage": 0, "team": team,
		})
	return out

# --- stage lifecycle ---
## The single sports arena every stage (GAUNTLET's single-arena pattern). Each stage IS one point; the
## arena reloads -> fresh goal zones + kickoff for free.
func next_level_path(_runner) -> String:
	return _arena_path

## THE ONE NEW HOOK (spec §4.1). Called at the tail of _begin_stage after players are placed: free any
## prior ball, (re)spawn the Ball at arena centre, and snap teams to their mirrored ends.
func on_stage_ready(runner) -> void:
	_place_teams(runner)
	_spawn_ball(runner)

## True when any goal_zone in the group has latched `scored` (a ball crossed a goal line). NOT
## last-one-standing; a smash/knockback never satisfies this.
func is_stage_over(runner) -> bool:
	for z in runner.get_tree().get_nodes_in_group("goal_zone"):
		if z.scored:
			return true
	return false

## No team scoring, no elimination side-effect. A "kill" here is a rare out-of-bounds knock; the runner
## already respawns it (high lives). SPORTS leaves runner.scores all-zero (no kill-race).
func on_kill(_runner, _killer_idx: int, _victim_idx: int, _cause) -> void:
	pass

## A representative player index of the team that reached _goal_cap with a strict lead, else -1. Guarded
## to the STAGE_END freeze (the cap is evaluated after a goal ends the stage) so a mid-play poll can
## never declare a premature win (the GAUNTLET victory-guard pattern).
func match_winner(runner) -> int:
	if str(runner.state) != "STAGE_END":
		return -1
	var win_team: int = -1
	if int(_team_scores[0]) >= _goal_cap and int(_team_scores[0]) > int(_team_scores[1]):
		win_team = 0
	elif int(_team_scores[1]) >= _goal_cap and int(_team_scores[1]) > int(_team_scores[0]):
		win_team = 1
	if win_team < 0:
		return -1
	for i in range(_teams.size()):
		if int(_teams[i]) == win_team:
			return i
	return -1

## Read the latched goal_zone -> scoring team = the OTHER team; increment _team_scores ONCE here
## (idempotent per stage via _last_scored_stage). Returns the GOAL! banner in the scoring team's color.
func stage_end_banner(runner) -> Dictionary:
	var defending: int = _latched_defending_team(runner)
	var scoring: int = 1 - defending if defending >= 0 else _last_scoring_team
	if scoring < 0:
		scoring = 0
	if int(runner.stage_index) != _last_scored_stage:
		_last_scored_stage = int(runner.stage_index)
		_team_scores[scoring] = int(_team_scores[scoring]) + 1
		_last_scoring_team = scoring
	return {"text": "GOAL!   RED %d — %d BLUE" % [int(_team_scores[0]), int(_team_scores[1])],
		"color": TEAM_COLORS[scoring]}

## Bot SPORTS objective (the load-bearing fix): steer the bot to a point that lets it hit the BALL
## toward its ENEMY goal. Approach the ball from the side AWAY from the enemy goal; once basically on
## the ball, aim THROUGH it toward the goal so the boosting contact drives it goalward. Returns a world
## Vector2 the bot flies to via its existing movement, or null (no ball yet) -> bot uses its default path.
func bot_objective(runner, bot_player) -> Variant:
	if not is_instance_valid(_ball):
		return null
	var idx: int = runner.players.find(bot_player)
	if idx < 0 or idx >= _teams.size():
		return null
	var my_team: int = int(_teams[idx])
	var enemy_goal: Vector2 = _enemy_goal_center(runner, my_team)
	if enemy_goal == Vector2.INF:
		return null
	var ball_pos: Vector2 = _ball.global_position
	var to_goal: Vector2 = enemy_goal - ball_pos
	if to_goal.length() < 1.0:
		return ball_pos
	to_goal = to_goal.normalized()
	# The strike point behind the ball, on the side AWAY from the enemy goal.
	var behind: Vector2 = ball_pos - to_goal * BOT_APPROACH_OFFSET
	# Only DRIVE THROUGH when we are BOTH close AND actually behind the ball (on the away-from-goal
	# side): from_ball . (-to_goal) > 0 means the ball lies between us and the goal, so pushing through
	# it sends it goalward. This is the "earned goal" gate — a bot that is beside/in front of the ball
	# (within BOT_ON_BALL_DIST but on the wrong side) no longer swipes it sideways ("drift"); it first
	# flies to `behind` to line the shot up, then drives through. Symmetric for both teams.
	var from_ball: Vector2 = bot_player.global_position - ball_pos
	var close: bool = bot_player.global_position.distance_to(ball_pos) < BOT_ON_BALL_DIST
	var behind_ball: bool = from_ball.dot(-to_goal) > 0.0
	if close and behind_ball:
		return ball_pos + to_goal * BOT_DRIVE_THROUGH
	return behind

## Frame the WHOLE court so both goal mouths + the ball stay on screen through a rally. Returns the
## full arena bounds (the enclosed court): it always contains both goal zones and the ball, so the
## shared camera fits a FIXED extent instead of chasing the player cluster (which let the ball/goals
## drift off-frame). BRAWL/others return null -> the default cluster framing is UNCHANGED.
func camera_framing(runner) -> Variant:
	return runner.bounds

## The world-centre of the goal_zone whose DEFENDING team is NOT `my_team` (the goal the bot attacks),
## or Vector2.INF if none is found.
func _enemy_goal_center(runner, my_team: int) -> Vector2:
	for z in runner.get_tree().get_nodes_in_group("goal_zone"):
		if int(z.team) != my_team:
			return z.global_position
	return Vector2.INF

func match_end_banner(_runner) -> Dictionary:
	var win_team: int = 0 if int(_team_scores[0]) > int(_team_scores[1]) else 1
	return {"text": "%s WINS!" % TEAM_NAMES[win_team], "color": TEAM_COLORS[win_team],
		"subline": "RED %d — %d BLUE" % [int(_team_scores[0]), int(_team_scores[1])]}

# --- HUD read helpers (SportsHUD polls these via runner._mode each frame) ---
func team_scores() -> Array:
	return _team_scores

func goal_cap() -> int:
	return _goal_cap

func last_scoring_team() -> int:
	return _last_scoring_team

func team_name(t: int) -> String:
	return TEAM_NAMES[t % TEAM_NAMES.size()]

func team_color(t: int) -> Color:
	return TEAM_COLORS[t % TEAM_COLORS.size()]

# --- internals ---
## Which team's goal was crossed (the DEFENDING team of the latched zone), or -1 if none latched.
func _latched_defending_team(runner) -> int:
	for z in runner.get_tree().get_nodes_in_group("goal_zone"):
		if z.scored:
			return int(z.team)
	return -1

## (Re)spawn the persistent stage Ball at arena centre. Frees any prior ball defensively (the previous
## one was already queued for free when _load_stage cleared _level_root). Added under _level_root so it
## is torn down automatically on the next stage reload.
func _spawn_ball(runner) -> void:
	if is_instance_valid(_ball):
		_ball.queue_free()
	_ball = BALL_SCRIPT.new()
	runner._level_root.add_child(_ball)
	_ball.global_position = _kickoff_center(runner)
	_ball.linear_velocity = Vector2.ZERO

## Snap each player to a mirrored end by team: team 0 -> the LEFT spawns, team 1 -> the RIGHT spawns.
## The runner's _spawn_at uses a fixed spawns[i % n] mapping that CANNOT satisfy both 1v1 and 2v2 team
## sides at once, so the team-aware placement is done here (spec §1 "both teams spawn at mirrored ends").
func _place_teams(runner) -> void:
	var spawns: Array = runner._spawns.duplicate()
	if spawns.size() < 2 or _teams.is_empty():
		return
	spawns.sort_custom(func(a, b): return a.x < b.x)
	var left_i: int = 0
	var right_i: int = spawns.size() - 1
	for i in range(runner.players.size()):
		var p = runner.players[i]
		if not is_instance_valid(p):
			continue
		var team: int = int(_teams[i]) if i < _teams.size() else (0 if i < runner.players.size() / 2 else 1)
		var pos: Vector2
		if team == 0:
			pos = spawns[left_i % spawns.size()]
			left_i += 1
		else:
			pos = spawns[maxi(0, right_i) % spawns.size()]
			right_i -= 1
		p.global_position = pos
		if p.has_method("respawn"):
			p.velocity = Vector2.ZERO

## Kickoff centre: the middle of the pitch. Uses bounds centre X (symmetric court) and the stage-rect
## centre Y (mid-air over the bouncy floor) so the ball falls onto the floor and bounces = constant motion.
func _kickoff_center(runner) -> Vector2:
	var b: Rect2 = runner.bounds
	var sr: Rect2 = runner._stage_rect
	return Vector2(b.get_center().x, sr.get_center().y)
