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
# team colorway skins (spec §4: warm = team 0, cool = team 1) so teammates read as one side.
# WK-27: this is ALSO the Herd Lobby's sports roster — RED = POGO (pink) / BILLY (orange), BLUE = BUTCH
# (blue) / ZIGGY (green); VEX / PUFF are not offered in Sports. Picking the goat picks the team.
# BLUE was BUTCH / VEX until the WK-27 rendered check: VEX's sprite is magenta (~hue 300) and read as POGO's
# pink at couch distance, so a BLUE VEX looked like a RED player. Green keeps every cross-team pair >= 90deg
# apart in hue (DECISIONS 2026-11-14 "Sports team colourways").
const TEAM_SKINS := [["pink", "orange"], ["blue", "green"]]

# --- mode-owned state (spec §4) ---
var _team_scores: Array = [0, 0]
var _teams: Array = []                 # index -> team (0/1), built in spawn_plan (plan[i] -> player i)
var _goal_cap: int = 6                  # fallback; the live cap is set in configure() from Tuning.sports_goal_target
var _arena_path: String = DEFAULT_ARENA
var _last_scoring_team: int = -1
var _last_scored_stage: int = -1       # idempotency guard: increment at most once per stage

var _ball: Ball = null                 # the live stage ball (freed + re-created each kickoff)
var _court_set_cache: Dictionary = {}  # parsed sports_courts.json (lazy; {by_id, default_path, rotate})

# --- WK-104 (SP-05) fair kickoff formation, read from the court JSON's optional top-level "kickoff" block:
#   "kickoff": { "ball": {"x","y"}, "slots_1v1": [{"x","y"}], "slots_2v2": [{"x","y"}, {"x","y"}] }
# Slots are TEAM 0's (LEFT) spots; team 1 is mirrored about ball.x, so the two teams are symmetric by
# construction. Every slot is authored at the SAME distance from the ball (checked at load), so no seat —
# human or CPU — starts closer. Within a team, seats rotate through the slots by stage parity. Courts with no
# block keep the legacy spawn placement + centre ball (still ghosted until GO, SP-02). Soccer only. ---
var _kickoff: Dictionary = {}          # {ball: Vector2, slots: {1: [Vector2], 2: [Vector2, Vector2]}} or {}

# --- WK-106 (SP-03) goal credit: built once per goal in stage_end_banner, read by the HUD/banner. ---
var _last_goal: Dictionary = {}        # {team, scorer_idx, own_goal, assist_idx, scorer_name, assist_name, count}
var _goal_count: int = 0               # goals this match (HUD flash/pop keys off goal_scored, this is QA)

# --- SPORT VARIANT (owner 2026-07-18 item 5, DROPSHOT) ---
# The court JSON declares its sport via a top-level "sport" field ("soccer" default | "dropshot").
# DROPSHOT = volleyball-like: floaty beach ball (Ball.configure_dropshot), a solid centre NET wall
# (authored as a bumper platform in the court JSON), a ball-only destructible DROP_TILE floor, and
# hidden under-floor goal_zone strips — the ball breaking through YOUR half's floor = the OTHER
# team's point (standard volleyball concede). Everything else (teams, kickoff-per-stage, goal cap,
# HUD chip, camera court-fit) is the same SportsMode machinery — no PartyMatch fork.
var _sport: String = "soccer"

# --- bot-objective geometry (mode-owned, NOT fenced player-feel Tuning — this is WHERE to go, the
# bot's existing movement/boost carries it there). To hit the ball toward the ENEMY goal a bot must
# contact it from the side AWAY from that goal, so it flies to a point behind the ball; once basically
# on the ball it aims THROUGH it toward the goal (a boosting/super/hitstun contact = a power shot). ---
const BOT_APPROACH_OFFSET := 150.0     # how far BEHIND the ball (away from enemy goal) the strike point sits
const BOT_ON_BALL_DIST := 240.0        # within this of the ball -> stop lining up, drive THROUGH it goalward
const BOT_DRIVE_THROUGH := 220.0       # how far PAST the ball (toward goal) to aim when driving through

# --- team-play geometry (bot ball-crowding fix 2026-07-19): ONLY the teammate nearest the ball chases
# it; the rest hold a goal-side COVER position so a team never stacks two bodies on one ball (which read
# as one blob fighting itself). Also mode-owned WHERE-to-go, not fenced feel. ---
const SUPPORT_HOLD_FRAC := 0.42        # supporter sits this fraction from OWN goal toward the ball (goal-side cover)
const SUPPORT_SPREAD := 240.0          # lateral offset per extra supporter so multiple supporters don't stack
const SUPPORT_COURT_MARGIN := 170.0    # keep the cover point this far inside the court walls

# --- DROPSHOT serve geometry (owner 2026-07-19): after each point the ball waits FROZEN in the middle,
# above the net, then on GO launches toward the team that scored last (pressure to make the first touch). ---
const DROPSHOT_SERVE_HEIGHT_FRAC := 0.34   # serve-point Y as a fraction of bounds height (top gap, above the net)
const DROPSHOT_SERVE_SPEED_X := 620.0      # horizontal serve speed toward the last scorer's half
const DROPSHOT_SERVE_SPEED_DOWN := 240.0   # gentle downward arc so the floaty ball descends onto that half

# --- identity / presentation ---
# The SPORTS machinery backs THREE top-level mode cards (owner 2026-07-19 split): "rocketball" (the
# soccer sport) and "dropshot" (the volleyball sport) are separate CHOOSE YOUR GAME entries, plus the
# legacy "sports" id (kept for back-compat / any old deep-link). All three run this same SportsMode; the
# COURT determines the physics (_read_sport off the JSON), the MODE id determines menu filtering + labels.
const MODE_KEYS: Array[StringName] = [&"sports", &"rocketball", &"dropshot"]
var _mode_key: StringName = &"sports"

## True if this mode_id is one of the SPORTS-family cards (used wherever code special-cased == &"sports").
static func is_sports_mode(mid: StringName) -> bool:
	return mid == &"sports" or mid == &"rocketball" or mid == &"dropshot"

## Which SPORT a mode card locks to: rocketball -> soccer, dropshot -> dropshot, legacy sports -> "" (mixed,
## no filter). Used by the court-select to show only the matching courts.
static func sport_for_mode(mid: StringName) -> String:
	match mid:
		&"rocketball": return "soccer"
		&"dropshot": return "dropshot"
		_: return ""

## WK-27: which team a goat colourway belongs to (TEAM_SKINS is the ONE mapping). -1 = not a sports goat.
static func team_for_skin(skin: String) -> int:
	for t in range(TEAM_SKINS.size()):
		if (TEAM_SKINS[t] as Array).has(skin):
			return t
	return -1

## WK-27 team fill: the ONE rule both the Herd Lobby's CPU preview and spawn_plan use, so the lobby shows
## exactly the CPUs the match spawns. `human_skins` / `human_teams` are per human (already validated),
## `total` is the even seat count (2 = 1V1, 4 = 2V2). Returns [{team, skin, bot_level}] in spawn order
## (RED's CPUs, then BLUE's). Each team's empty seats take that team's UNUSED colourway; the k-th CPU on
## RED and the k-th CPU on BLUE draw the same level (bot-level mirroring, the 2026-07-19 fairness fix).
static func team_fill(human_skins: Array, human_teams: Array, total: int, bot_difficulty: int) -> Array:
	var seats: int = maxi(1, total / 2)
	var levels: Array = Tuning.bot_levels
	var out: Array = []
	for t in range(TEAM_SKINS.size()):
		var used: Array = []
		var n: int = 0
		for h in range(mini(human_skins.size(), human_teams.size())):
			if int(human_teams[h]) == t:
				n += 1
				used.append(str(human_skins[h]))
		var pool: Array = []
		for sk in (TEAM_SKINS[t] as Array):
			if not used.has(sk):
				pool.append(sk)
		if pool.is_empty():
			pool = (TEAM_SKINS[t] as Array).duplicate()
		for k in range(maxi(0, seats - n)):
			var lvl: int = clampi(bot_difficulty, 1, 5) if bot_difficulty > 0 else int(levels[k % levels.size()])
			out.append({"team": t, "skin": str(pool[k % pool.size()]), "bot_level": lvl})
	return out

func id() -> StringName:
	return _mode_key

func display_name() -> String:
	match _mode_key:
		&"rocketball": return "ROCKETBALL"
		&"dropshot": return "DROPSHOT"
		_: return "SPORTS"

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
	if config != null and config.mode_id in MODE_KEYS:
		_mode_key = config.mode_id
	# Defensive arena resolution (CD robustness fix): SPORTS is an ENCLOSED-court mode; if it ever loads a
	# non-enclosed / missing level the ball falls through the world forever. Default to the sports court
	# whenever the configured path is empty, whitespace, or points at a file that does not exist.
	var want: String = str(config.single_arena_path).strip_edges() if config != null else ""
	_arena_path = _resolve_court(want)
	_sport = _read_sport(_arena_path)
	_kickoff = _read_kickoff(_arena_path) if _sport == "soccer" else {}
	_team_scores = [0, 0]
	_last_scoring_team = -1
	_last_scored_stage = -1
	_last_goal = {}
	_goal_count = 0

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

## The court's SPORT ("soccer" | "dropshot") from its level JSON's top-level "sport" field.
## Absent / unreadable -> "soccer" (every pre-DROPSHOT court is a soccer court, zero migration).
func _read_sport(path: String) -> String:
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			return str((parsed as Dictionary).get("sport", "soccer"))
	return "soccer"

## WK-104: parse the court's optional "kickoff" block (see _kickoff). Returns {} when absent/malformed so the
## legacy placement runs. Warns (never fails) if a court's slots are not equidistant from the ball — the
## fairness contract the formation exists for.
func _read_kickoff(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var k: Variant = (parsed as Dictionary).get("kickoff", null)
	if typeof(k) != TYPE_DICTIONARY:
		return {}
	var kd := k as Dictionary
	var bv: Variant = kd.get("ball", null)
	if typeof(bv) != TYPE_DICTIONARY:
		return {}
	var ball := Vector2(float((bv as Dictionary).get("x", 0.0)), float((bv as Dictionary).get("y", 0.0)))
	var slots := {}
	for n in [1, 2]:
		var raw: Variant = kd.get("slots_%dv%d" % [n, n], null)
		if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < n:
			continue
		var arr: Array = []
		for s in (raw as Array):
			if typeof(s) == TYPE_DICTIONARY:
				arr.append(Vector2(float((s as Dictionary).get("x", 0.0)), float((s as Dictionary).get("y", 0.0))))
		if arr.size() < n:
			continue
		var d0: float = (arr[0] as Vector2).distance_to(ball)
		for v in arr:
			if absf((v as Vector2).distance_to(ball) - d0) > 4.0:
				push_warning("SportsMode: %s kickoff slots_%dv%d are not equidistant from the ball (%.0f vs %.0f px)" \
					% [path, n, n, (v as Vector2).distance_to(ball), d0])
		slots[n] = arr
	return {"ball": ball, "slots": slots}

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
## _teams in the SAME order the runner spawns (plan[i] -> player i). Each descriptor sets `team`.
## WK-27: when the Herd Lobby wrote MatchConfig.team_ids, each human plays on the team their goat picked,
## WEARING that goat (no repaint), and CPUs fill each team's empty seats (_team_plan). Otherwise (cold boot,
## QA harness, recorder) the legacy rule: split the roster in half and repaint team colourway skins.
func spawn_plan(_runner, config: MatchConfig) -> Array:
	# WK-02 roster cap: clamp BEFORE the even-split math so teams stay balanced (an odd total <= 3 rounds
	# up to <= 4, so the even clamp below can never exceed MatchConfig.MAX_FIGHTERS).
	var humans: int = clampi(config.human_count, 0, MatchConfig.MAX_FIGHTERS)
	var bots: int = clampi(config.bot_count, 0, MatchConfig.MAX_FIGHTERS - humans)
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
	if humans > 0 and config.team_ids.size() >= humans:
		return _team_plan(config, humans, total)
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

## WK-27 lobby-driven plan: humans keep their slot order (the runner maps plan[h] -> human device h), each on
## MatchConfig.team_ids[h] in their picked goat; then team_fill's CPUs. Defensive against a config the lobby
## would never write: an overfilled team first grows the format (<= MAX_FIGHTERS), then moves its highest
## humans across; a skin that isn't one of the team's colourways (or is a teammate's) becomes an unused one.
func _team_plan(config: MatchConfig, humans: int, total: int) -> Array:
	var teams: Array = []
	var skins: Array = []
	var count: Array = [0, 0]
	for h in range(humans):
		var t: int = clampi(config.team_for(h), 0, 1)
		teams.append(t)
		skins.append(config.skin_for(h))
		count[t] = int(count[t]) + 1
	var need: int = 2 * maxi(int(count[0]), int(count[1]))
	if need > total:
		total = mini(need, MatchConfig.MAX_FIGHTERS)
		push_warning("SportsMode: lobby teams %s overfill the format -> %d seats" % [str(teams), total])
	var seats: int = total / 2
	for t in range(2):
		while int(count[t]) > seats:
			for h in range(humans - 1, -1, -1):
				if int(teams[h]) == t:
					teams[h] = 1 - t
					count[t] = int(count[t]) - 1
					count[1 - t] = int(count[1 - t]) + 1
					push_warning("SportsMode: human %d moved to %s (team over capacity)" % [h, TEAM_NAMES[1 - t]])
					break
	for h in range(humans):
		var t: int = int(teams[h])
		var clash: bool = false
		for o in range(h):
			if int(teams[o]) == t and str(skins[o]) == str(skins[h]):
				clash = true
		if team_for_skin(str(skins[h])) == t and not clash:
			continue
		for c in (TEAM_SKINS[t] as Array):
			var taken: bool = false
			for o in range(humans):
				if o != h and int(teams[o]) == t and str(skins[o]) == str(c):
					taken = true
			if not taken:
				skins[h] = str(c)
				break
		if team_for_skin(str(skins[h])) != t:
			skins[h] = str((TEAM_SKINS[t] as Array)[0])
	_teams = []
	var out: Array = []
	for h in range(humans):
		_teams.append(int(teams[h]))
		out.append({"human": true, "skin": str(skins[h]), "character": config.character_for(h),
			"bot_level": 0, "seed_damage": 0, "team": int(teams[h])})
	var fill: Array = team_fill(skins, teams, total, config.bot_difficulty)
	for b in range(fill.size()):
		var d: Dictionary = fill[b]
		_teams.append(int(d["team"]))
		out.append({"human": false, "skin": str(d["skin"]), "character": config.character_for(humans + b),
			"bot_level": int(d["bot_level"]), "seed_damage": 0, "team": int(d["team"])})
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

## GO! (dropshot only): unfreeze the ball held above the net and serve it toward the LAST SCORER's half,
## so the team that just scored must make the first touch (owner 2026-07-19 pressure inversion). Before
## the first point (no scorer) the side alternates by stage parity so neither team owns the opener.
## ROCKETBALL (WK-104 SP-02/SP-05): the ghosted kickoff ball goes live on GO with the ref-drop release —
## an upward toss (random in Tuning.sports_kickoff_toss_min..max, no sideways bias) and gravity scaled by
## sports_kickoff_hang_gravity until the first touch, so both teams converge on a contested ball.
func on_combat_start(runner) -> void:
	if not is_instance_valid(_ball):
		return
	if _sport != "dropshot":
		var toss: float = randf_range(minf(Tuning.sports_kickoff_toss_min, Tuning.sports_kickoff_toss_max),
			maxf(Tuning.sports_kickoff_toss_min, Tuning.sports_kickoff_toss_max))
		_ball.go_live(Vector2(0.0, -toss), Tuning.sports_kickoff_hang_gravity, Tuning.sports_kickoff_hang_s)
		return
	var serve_team: int = _last_scoring_team if _last_scoring_team >= 0 else int(runner.stage_index) % 2
	var side: float = -1.0 if serve_team == 0 else 1.0   # team 0 defends the LEFT half, team 1 the RIGHT
	# go_live = unfreeze + accept touches (SP-02); hang off (normal beach-ball float) -> the serve is unchanged
	_ball.go_live(Vector2(side * DROPSHOT_SERVE_SPEED_X, DROPSHOT_SERVE_SPEED_DOWN), 1.0, 0.0)

## DROPSHOT serve point: dead-centre of the court, up in the top gap ABOVE the net peak (owner 2026-07-19).
func _dropshot_serve_point(runner) -> Vector2:
	var b: Rect2 = runner.bounds
	return Vector2(b.get_center().x, b.position.y + b.size.y * DROPSHOT_SERVE_HEIGHT_FRAC)

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
## (idempotent per stage via _last_scored_stage), credit the goal (WK-106) and emit THE goal event
## (EventBus.goal_scored — audio/juice/HUD hook it). Returns the ONE goal banner (WK-16): headline
## "GOAL!" / "OWN GOAL!" / "POINT!" + a scorer line, all in the awarded team's colour. The score itself
## is the HUD chip (it pops on the goal), so the banner no longer repeats "RED n — m BLUE".
func stage_end_banner(runner) -> Dictionary:
	var defending: int = _latched_defending_team(runner)
	var scoring: int = 1 - defending if defending >= 0 else _last_scoring_team
	if scoring < 0:
		scoring = 0
	if int(runner.stage_index) != _last_scored_stage:
		_last_scored_stage = int(runner.stage_index)
		_team_scores[scoring] = int(_team_scores[scoring]) + 1
		_last_scoring_team = scoring
		_goal_count += 1
		_last_goal = _credit_goal(runner, scoring)
		var scorer = null
		var si: int = int(_last_goal["scorer_idx"])
		if si >= 0 and si < runner.players.size() and is_instance_valid(runner.players[si]):
			scorer = runner.players[si]
		EventBus.goal_scored.emit(scoring, scorer, bool(_last_goal["own_goal"]))
	return {"text": _goal_headline(), "color": TEAM_COLORS[scoring], "subline": _goal_subline()}

## WK-106 (SP-03) goal credit from Ball.touch_log (live touches only). Rocket League / FIFA convention:
##  * the scoring team's LAST TOUCHER scores — even when a defender touched it after (a block, a failed save,
##    a deflection, or a stale touch the ball wandered in from);
##  * OWN GOAL (soccer only) is reserved for a defender CLEARLY putting it in: their last touch came within
##    Tuning.sports_own_goal_window of the goal, ADDED >= sports_own_goal_push px/s toward their own goal, and no
##    attacker touched it in the sports_deflect_window before (else it is that attacker's deflected shot);
##  * nobody on the scoring team touched it and it is not an own goal -> a team goal (scorer -1).
## DROPSHOT: the point goes to the scoring team's last toucher (a failed save is never an "own goal").
## ASSIST (not on own goals): the touch just before the scorer's final run of touches, if it is a different
## teammate within Tuning.sports_assist_window of that run (an opponent touch in between = no assist).
func _credit_goal(runner, scoring: int) -> Dictionary:
	var out := {"team": scoring, "scorer_idx": -1, "own_goal": false, "assist_idx": -1,
		"scorer_name": "", "assist_name": "", "count": _goal_count}
	var tlog: Array = _ball.touch_log() if is_instance_valid(_ball) else []
	var goal_t: float = _ball.ball_clock() if is_instance_valid(_ball) else 0.0
	# the scoring team's most recent touch (the default scorer) and the very last touch overall
	var att: int = -1
	var last: int = -1
	for i in range(tlog.size() - 1, -1, -1):
		var ti: int = _touch_idx(runner, tlog[i])
		if ti < 0:
			continue
		if last < 0:
			last = i
		if int(_teams[ti]) == scoring:
			att = i
			break
	if _sport != "dropshot" and last >= 0 and last != att and _is_own_goal_touch(runner, tlog, last, att, goal_t, scoring):
		out["scorer_idx"] = _touch_idx(runner, tlog[last])
		out["own_goal"] = true
	elif att >= 0:
		out["scorer_idx"] = _touch_idx(runner, tlog[att])
		var si: int = int(out["scorer_idx"])
		var run_t: float = float((tlog[att] as Dictionary)["t"])
		var j: int = att
		while j >= 0 and _touch_idx(runner, tlog[j]) == si:
			run_t = float((tlog[j] as Dictionary)["t"])
			j -= 1
		if j >= 0:
			var aj: int = _touch_idx(runner, tlog[j])
			if aj >= 0 and aj != si and int(_teams[aj]) == scoring 					and run_t - float((tlog[j] as Dictionary)["t"]) <= Tuning.sports_assist_window:
				out["assist_idx"] = aj
	if int(out["scorer_idx"]) >= 0:
		out["scorer_name"] = str(runner.player_name(int(out["scorer_idx"])))
	if int(out["assist_idx"]) >= 0:
		out["assist_name"] = str(runner.player_name(int(out["assist_idx"])))
	return out

## WK-106: did the defender's touch tlog[last] clearly put the ball in? (see _credit_goal). `att` = index of the
## scoring team's latest touch (-1 none). Goalward = toward the conceding team's own goal from the ball's spot.
func _is_own_goal_touch(runner, tlog: Array, last: int, att: int, goal_t: float, scoring: int) -> bool:
	var e: Dictionary = tlog[last]
	var t: float = float(e.get("t", 0.0))
	if goal_t - t > Tuning.sports_own_goal_window:
		return false   # a stale touch the ball wandered in from — not "putting it in"
	if att >= 0 and t - float((tlog[att] as Dictionary).get("t", -1e9)) <= Tuning.sports_deflect_window:
		return false   # a deflection of an attacker's shot -> the shooter's goal
	var own_goal_pos: Vector2 = _own_goal_center(runner, 1 - scoring)
	if own_goal_pos == Vector2.INF:
		return true
	var pos: Vector2 = e.get("pos", own_goal_pos)
	var dir: Vector2 = (own_goal_pos - pos).normalized()
	var vin: Vector2 = e.get("vin", Vector2.ZERO)
	var vout: Vector2 = e.get("vout", Vector2.ZERO)
	return (vout - vin).dot(dir) >= Tuning.sports_own_goal_push

## Player index of a touch-log entry (-1 if the player is gone or has no team).
func _touch_idx(runner, entry: Variant) -> int:
	if typeof(entry) != TYPE_DICTIONARY:
		return -1
	var p = (entry as Dictionary).get("p", null)
	if p == null or not is_instance_valid(p):
		return -1
	var idx: int = runner.players.find(p)
	return idx if idx >= 0 and idx < _teams.size() else -1

## The goal banner headline (WK-106): "OWN GOAL!" on a soccer own goal, else the sport's goal word.
func _goal_headline() -> String:
	if bool(_last_goal.get("own_goal", false)):
		return "OWN GOAL!"
	return goal_word()

## The goal banner's one scorer line (WK-88 names: humans "P#", CPUs by goat name):
##   "P1 SCORES!  ·  ASSIST VEX"  |  own goal: "BUTCH SCORES FOR RED!"  |  nobody touched it: "RED SCORES!"
func _goal_subline() -> String:
	var team: int = int(_last_goal.get("team", 0))
	var who: String = str(_last_goal.get("scorer_name", ""))
	if who == "":
		return "%s SCORES!" % TEAM_NAMES[team]
	if bool(_last_goal.get("own_goal", false)):
		return "%s SCORES FOR %s!" % [who, TEAM_NAMES[team]]
	var line := "%s SCORES!" % who
	var assist: String = str(_last_goal.get("assist_name", ""))
	if assist != "":
		line += "  ·  ASSIST %s" % assist
	return line

## WK-106: the last goal's credit (see _credit_goal) — {} before the first goal. HUD / QA read this.
func last_goal() -> Dictionary:
	return _last_goal

func goal_count() -> int:
	return _goal_count

## WK-15 (CC-11.1 / D-13): the stage-1 goal chip above the controls legend — the sport's one-line rule.
func goal_line(_runner) -> String:
	if _sport == "dropshot":
		return "SPIKE IT OVER THE NET  ·  DON'T LET IT DROP  ·  FIRST TO %d" % _goal_cap
	return "HEADBUTT THE BALL INTO THEIR GOAL  ·  FIRST TO %d" % _goal_cap

## The score exclamation ("GOAL!" for soccer, "POINT!" for DROPSHOT). Read by the HUD flash too.
func goal_word() -> String:
	return "POINT!" if _sport == "dropshot" else "GOAL!"

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
	# TEAM PLAY (crowding fix): only the teammate NEAREST the ball chases it; supporters hold a goal-side
	# cover point on their own half. Rank counts human teammates too (distance-to-ball, index tiebreak),
	# so a bot yields the ball to a nearer human instead of piling on.
	var rank: int = _ball_chase_rank(runner, idx, my_team, ball_pos)
	if rank > 0:
		return _support_point(runner, my_team, ball_pos, rank)
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

## The world-centre of MY team's goal (the one this team defends), or Vector2.INF if none.
func _own_goal_center(runner, my_team: int) -> Vector2:
	for z in runner.get_tree().get_nodes_in_group("goal_zone"):
		if int(z.team) == my_team:
			return z.global_position
	return Vector2.INF

## How many of this bot's living teammates are CLOSER to the ball than it is (distance, index tiebreak).
## 0 == this bot is the designated ball-chaser; >0 == a supporter (holds a cover position instead of
## crowding the ball). Human teammates are counted, so a bot defers the ball to a nearer human.
func _ball_chase_rank(runner, idx: int, my_team: int, ball_pos: Vector2) -> int:
	var mine = runner.players[idx]
	if not is_instance_valid(mine):
		return 0
	var my_d: float = mine.global_position.distance_to(ball_pos)
	var rank := 0
	for j in range(runner.players.size()):
		if j == idx or j >= _teams.size() or int(_teams[j]) != my_team:
			continue
		var p = runner.players[j]
		if not is_instance_valid(p) or p.is_dead():
			continue
		var jd: float = p.global_position.distance_to(ball_pos)
		if jd < my_d or (jd == my_d and j < idx):
			rank += 1
	return rank

## A supporter's hold point: goal-side of the ball on this team's own half (ready to intercept a return),
## laterally spread by rank so multiple supporters don't stack, clamped inside the court walls.
func _support_point(runner, my_team: int, ball_pos: Vector2, rank: int) -> Vector2:
	var own_goal: Vector2 = _own_goal_center(runner, my_team)
	if own_goal == Vector2.INF:
		own_goal = runner.bounds.get_center()
	var cover: Vector2 = own_goal.lerp(ball_pos, SUPPORT_HOLD_FRAC)
	var axis: Vector2 = ball_pos - own_goal
	if axis.length() > 1.0:
		var perp := Vector2(-axis.y, axis.x).normalized()
		var side: float = 1.0 if (rank % 2 == 1) else -1.0
		var mag: float = float((rank + 1) / 2) * SUPPORT_SPREAD
		cover += perp * side * mag
	var box: Rect2 = runner.bounds.grow(-SUPPORT_COURT_MARGIN)
	return box.get_center() if box.size.x <= 0.0 else Vector2(
		clampf(cover.x, box.position.x, box.end.x),
		clampf(cover.y, box.position.y, box.end.y))

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
	if _sport == "dropshot":
		_ball.configure_dropshot()   # floaty beach ball (Tuning dropshot_* block) — set BEFORE add_child
	runner._level_root.add_child(_ball)
	_ball.linear_velocity = Vector2.ZERO
	if _sport == "dropshot":
		# DROPSHOT (owner 2026-07-19): the ball waits in the MIDDLE, ABOVE the net, FROZEN through the
		# countdown; on GO (on_combat_start) it launches toward the team that scored last, so the pressure
		# to make the first touch is on the scorers.
		_ball.global_position = _dropshot_serve_point(runner)
	elif not _kickoff.is_empty():
		_ball.global_position = _kickoff["ball"]   # WK-104: the court's authored kickoff spot
	else:
		_ball.global_position = _kickoff_center(runner)
	# WK-104 (SP-02): GHOSTED until GO in EVERY sport — frozen (no fall/drift through the intro) and not live
	# (ignores player overlaps + hazard punts). on_combat_start -> Ball.go_live releases it.
	_ball.freeze = true
	_ball.live = false

## Snap each player to a mirrored end by team: team 0 -> the LEFT spawns, team 1 -> the RIGHT spawns.
## The runner's _spawn_at uses a fixed spawns[i % n] mapping that CANNOT satisfy both 1v1 and 2v2 team
## sides at once, so the team-aware placement is done here (spec §1 "both teams spawn at mirrored ends").
func _place_teams(runner) -> void:
	if _place_kickoff_formation(runner):
		return
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

## WK-104 (SP-05) fair kickoff: place each team on the court's authored kickoff slots (team 0 as authored,
## team 1 mirrored about the ball's x), all equidistant from the ball. Seats rotate through their team's
## slots by stage parity so nobody owns a slot. False (legacy placement runs) when the court has no block or
## a team's size has no slot set (e.g. a defensive 3v3 overfill).
func _place_kickoff_formation(runner) -> bool:
	if _kickoff.is_empty() or _teams.is_empty():
		return false
	var count: Array = [0, 0]
	for i in range(mini(runner.players.size(), _teams.size())):
		count[int(_teams[i])] = int(count[int(_teams[i])]) + 1
	var slots: Dictionary = _kickoff["slots"]
	for t in range(2):
		if int(count[t]) > 0 and not slots.has(int(count[t])):
			return false
	var ball: Vector2 = _kickoff["ball"]
	var within: Array = [0, 0]
	for i in range(mini(runner.players.size(), _teams.size())):
		var p = runner.players[i]
		if not is_instance_valid(p):
			continue
		var t: int = int(_teams[i])
		var arr: Array = slots[int(count[t])]
		var pos: Vector2 = arr[(int(within[t]) + int(runner.stage_index)) % arr.size()]
		within[t] = int(within[t]) + 1
		if t == 1:
			pos.x = 2.0 * ball.x - pos.x   # mirror: symmetric by construction
		p.global_position = pos
		p.velocity = Vector2.ZERO
	return true

## Kickoff centre: the middle of the pitch. Uses bounds centre X (symmetric court) and the stage-rect
## centre Y (mid-air over the bouncy floor) so the ball falls onto the floor and bounces = constant motion.
## DROPSHOT (owner item 5): the centre is the NET — the SERVE drops the ball onto one half instead.
## Serve flow (spec'd here): the team that CONCEDED the last point receives (they get first touch,
## volleyball serve-receive); before the first point the serve alternates by stage parity so neither
## side owns the opener. Offset = dropshot_serve_offset_frac of the court width from centre.
func _kickoff_center(runner) -> Vector2:
	var b: Rect2 = runner.bounds
	var sr: Rect2 = runner._stage_rect
	var x: float = b.get_center().x
	if _sport == "dropshot":
		var receive_team: int = 1 - _last_scoring_team if _last_scoring_team >= 0 else int(runner.stage_index) % 2
		var side: float = -1.0 if receive_team == 0 else 1.0   # team 0 = LEFT half, team 1 = RIGHT half
		x += side * b.size.x * Tuning.dropshot_serve_offset_frac
	return Vector2(x, sr.get_center().y)

## Mid-rally respawn on the player's TEAM side (owner item 3 — the runner's default _spawn_at(i) is
## index-cyclic and can drop a RED defender at a BLUE-side spawn in 2v2/DROPSHOT hole-falls). Mirrors
## _place_teams: sorted-by-x spawns; team 0 takes from the LEFT end, team 1 from the RIGHT, indexed
## by the player's within-team slot. null (no spawns/teams) -> runner default.
func respawn_position(runner, idx: int) -> Variant:
	if idx < 0 or idx >= _teams.size():
		return null
	var spawns: Array = runner._spawns.duplicate()
	if spawns.size() < 2:
		return null
	spawns.sort_custom(func(a, b): return a.x < b.x)
	var team: int = int(_teams[idx])
	var within: int = 0
	for i in range(idx):
		if int(_teams[i]) == team:
			within += 1
	if team == 0:
		return spawns[within % spawns.size()]
	return spawns[maxi(0, spawns.size() - 1 - (within % spawns.size()))]
