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

# --- WK-111 (SP-09) match stats for the sports end screen (SportsVictory). Per player index:
#   {goals, assists, own_goals, saves, touches, power}. Fed by Ball.touched (touches / power hits / saves) and the
#   WK-106 credit in stage_end_banner (goals / assists / own goals). Reset per match in configure(). ---
# SAVE (soccer only): a defender's touch on a ball that was a real shot at their own goal (moving at it >= the
# keeper's shot speed, inside the cone, arriving within STAT_SAVE_TIME) that the touch turned away. A save is taken
# back if that team concedes within STAT_SAVE_REVOKE s of ball time (it went in anyway). Mode-owned stat
# classification, like the bot geometry above — not player feel.
const STAT_SAVE_SPEED := 550.0         # = BOT_KEEPER_SHOT_SPEED: px/s toward the goal that makes it a shot
const STAT_SAVE_TIME := 1.6            # = BOT_KEEPER_SHOT_TIME: would reach the goal within this many seconds
const STAT_SAVE_CONE_DEG := 28.0       # the shot's heading is within this of the line to the goal centre
const STAT_SAVE_KEEP := 0.4            # after the touch the ball keeps < this fraction of its goalward speed...
const STAT_SAVE_REVOKE := 1.0          # ...and the team does not concede within this many s (ball clock)
# MVP = the best rating on the WINNING team (Rocket League convention). Points per stat:
const MVP_POINTS := {"goals": 100, "assists": 50, "saves": 50, "power": 10, "touches": 2, "own_goals": -30}
# Match-end framing of the winning team (end-of-match presentation only, not the in-play court camera).
const END_FRAME_PAD := Vector2(560.0, 420.0)   # world px of room around the winners' bounding box (each side x2)
const END_FRAME_MAX_ZOOM := 0.92               # never tighter than the arena zoom ceiling (SP-09: zoom <= 0.92)
var _pstats: Dictionary = {}           # player index -> stat dict (see _ps)
var _stage_touches: int = 0            # live touches this stage (rally length)
var _longest_rally: Dictionary = {}    # {secs, touches} of the longest goal-ending rally, {} before the first goal
var _last_save: Dictionary = {}        # {idx, t} of this stage's latest save (revoked on a quick concede)

# --- WK-131 KICKOFF GATES (docs/specs/wk131_kickoff_rule_2026-11-15.md §8). Tuning.sports_kickoff_rule: 0 = legacy (no gate
# node is ever made: byte-identical kickoff), 1 = GATES (open at Tuning.sports_gate_open_s of live ball), 2 = LIVE BALL (open
# when both teams have touched, or at Tuning.sports_live_fallback_s). Soccer courts only (Dropshot's serve is PROTECT). ---
const KICKOFF_GATE_SCENE := preload("res://scenes/entities/KickoffGate.tscn")   # WK-131
const GATE_RULE_ROW := "GOALS OPEN %s SECONDS AFTER KICK OFF"   # WK-131 H6: the stage-1 gold rule row until the first open
const GATE_OPEN_STICKER := "GOALS OPEN!"                        # WK-131: stage-1 open sticker (rides the same gold row)
const GATE_STICKER_S := 0.7                                     # WK-131: s the sticker holds before the row's normal copy
var _gates: Array = []                 # WK-131: this stage's KickoffGate nodes (freed with the level)
var _gate_rule: int = 0                # WK-131: the rule latched at stage start (arms switch only between stages)
var _ko_first_touch_t: float = -1.0    # WK-131 H3: ball clock of this stage's first live touch
var _ko_teams_touched: Array = [false, false]   # WK-131 H3
var _ko_gate_hits: int = 0             # WK-131: closed-gate contacts this stage (>= fx speed)
var _ko_gate_speeds: Array = []        # WK-131
var _ko_open_t: float = -1.0           # WK-131: ball clock of the open (-1 while closed / no gates)
var _ko_armed_t: float = -1.0          # WK-131: rule 2: ball clock when both teams had touched
var _ko_spit: bool = false             # WK-131
var _ko_runner = null                  # WK-131: the runner (stage-1 rule-row swap at the open)

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

# --- WK-108 (WK-98 SP-06) bot roles. Mode-owned WHERE-to-go geometry like the blocks above (not player feel). ---
# (a) ROUTE AROUND THE BALL: a chaser on the WRONG side of the ball (between it and the enemy goal) used to fly
#     straight at the strike point behind the ball -- through the ball, shoving it toward its own goal (CPU own
#     goals). If that straight line passes within BOT_AVOID_CLEAR_MULT x (ball + body radius) of the ball, it
#     flies a waypoint beside the ball first (over the top unless the ceiling is close), and only commits to the
#     strike point once the line is clear.
const BOT_AVOID_CLEAR_MULT := 1.6      # clearance = this x (ball radius + body radius) (SP-06 proposal)
const BOT_BODY_RADIUS := 44.0          # Player.BODY_RADIUS at size 1.0 (the standard goat)
const BOT_AVOID_ORBIT_MULT := 1.8      # orbit radius = clearance x this (wide: a bot re-plans only every reaction tick)
const BOT_AVOID_STEP_DEG := 55.0       # each orbit waypoint is this far round from my current bearing
const BOT_BALL_LEAD := 0.3             # s: the line-up also keeps clear of the ball's position this far ahead (a bot
                                       # re-plans only every reaction tick, and a cleared ball covers ~300 px in that)
# TRACK BACK: a wrong-side chaser whose ball is heading for its own goal does not chase it from behind (that is how
# almost every CPU own goal happened: 20 of 24 in a THE BOX A/B were wrong-side chasers flying at their own goal).
# It races goal-side ABOVE the ball's line instead, then clears from in front of the goal.
const BOT_TRACKBACK_SPEED := 300.0     # ball speed toward my goal (px/s) that triggers the track-back
const BOT_TRACKBACK_FRAC := 0.35       # target: this fraction from my goal mouth toward the ball...
const BOT_TRACKBACK_UP := 240.0        # ...raised this far above the ball's line
const BOT_CEILING_CLEAR := 170.0       # never route / hold a target closer than this under the court ceiling
# (b) KEEPER: a supporter (rank >= 1) keeps goal while the ball is in its own third or a shot is coming at its
#     goal, holding the goal-mouth centre (inside the court) and challenging only inside BOT_KEEPER_CHALLENGE.
const BOT_KEEPER_THIRD := 0.34         # "own third" = ball within this fraction of the goal-to-goal axis
const BOT_KEEPER_CHALLENGE := 400.0    # keeper leaves the mouth to clear a ball this close to it
const BOT_KEEPER_SHOT_SPEED := 550.0   # ball speed TOWARD my goal (px/s) that counts as an incoming shot...
const BOT_KEEPER_SHOT_TIME := 1.6      # ...if it would reach the goal line within this many seconds
const BOT_KICKOFF_KEEP_S := 3.0        # for this long after GO the supporter drops into goal (one chases the
                                       # kickoff, one keeps: WK-104 measured 22-26 % of goals inside 4 s of GO)
# WK-131 (H5): with KICKOFF GATES (rule 1) the goal can't be scored before the open, so the supporter keeps goal over
# [open - BOT_GATE_RETURN_LEAD_S, open + BOT_GATE_KEEP_AFTER_S] instead (the cover point ~466 px from the mouth takes ~0.6 s
# at 800 px/s, plus a ~0.2 s re-plan). Mode-owned bot timing, not player feel (spec §7).
const BOT_GATE_RETURN_LEAD_S := 0.8    # WK-131
const BOT_GATE_KEEP_AFTER_S := 1.0     # WK-131
# (c) CROSS (L4+ only): with the ball in the attacking half, an L4+ supporter makes a run to the far post; the
#     chaser, lined up behind the ball, crosses to it (aims through the ball at the teammate) when the teammate
#     is nearer the enemy goal, roughly goalward of the ball, and no opponent is within BOT_CROSS_MARK_DIST of it.
const BOT_CROSS_MIN_LEVEL := 4
const BOT_CROSS_RUN_FRAC := 0.5        # attacking half: ball past this fraction of the axis
const BOT_CROSS_POST_BACK := 420.0     # far-post run point: this far in front of the enemy goal mouth...
const BOT_CROSS_POST_UP := 260.0       # ...and this far above it (goal mouths sit above the floor)
const BOT_CROSS_MARK_DIST := 320.0     # a teammate with an opponent this close is "marked" (no cross)
const BOT_CROSS_GOALWARD := 0.2        # cross only if (ball->teammate) . (ball->goal) >= this (never back-pass)
# A/B regression switch (default ON): OFF = the pre-WK-108 sports bots (straight-line strike point, cover point
# only, no cross). gbplay eval: SportsMode.wk108_bots = false
static var wk108_bots := true
# The "mode-aware danger" half (InputBot drops its out-of-arena look-ahead in courts, adds a ceiling guard, and
# targets are clamped under the ceiling). DEFAULT OFF BY MEASUREMENT (WK-108, 32 soccer runs x 240 s each way):
# it did not lower stuck/min (43.2 on vs 42.5 off; 36.7 pre-WK-108) and raised underside bounces 57 -> 71/min
# (boosted 18 -> 33). Kickoff-goal and own-goal gains come from the roles above, not from this. Kept for re-test.
static var wk108_enclosed := false

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
	_pstats = {}           # WK-111: fresh stat sheet each match (a rematch re-runs configure)
	_longest_rally = {}
	_stage_touches = 0
	_last_save = {}
	_gates = []   # WK-131
	_ko_runner = null   # WK-131

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
	# WK-111: per-stage rally counters + the touch feed for the end-screen stats
	_stage_touches = 0
	_last_save = {}
	if is_instance_valid(_ball):
		_ball.touched.connect(_on_ball_touched.bind(runner))
	_spawn_kickoff_gates(runner)   # WK-131 H1

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
		_start_kickoff_gates()   # WK-131 H2
		return
	var serve_team: int = _last_scoring_team if _last_scoring_team >= 0 else int(runner.stage_index) % 2
	var side: float = -1.0 if serve_team == 0 else 1.0   # team 0 defends the LEFT half, team 1 the RIGHT
	# go_live = unfreeze + accept touches (SP-02); hang off (normal beach-ball float) -> the serve is unchanged
	_ball.go_live(Vector2(side * DROPSHOT_SERVE_SPEED_X, DROPSHOT_SERVE_SPEED_DOWN), 1.0, 0.0)

## WK-124: the goal freeze (Tuning.sports_goal_freeze). The match-winning goal keeps the full round_end_freeze
## (nothing restarts after it, so it costs no restart time). match_winner() is live here: the runner asks while in
## STAGE_END, after stage_end_banner() has already counted the goal.
func stage_end_freeze(runner) -> float:
	if match_winner(runner) >= 0:
		return Tuning.round_end_freeze
	return Tuning.sports_goal_freeze

## WK-124: every kickoff pop-in fits in Tuning.sports_intro_pop_window (2v2 pops 0.1 s apart, 1v1 keeps 0.2 s),
## so a 2v2 restart is no longer than a 1v1's.
func intro_pop_stagger(runner) -> float:
	var n: int = maxi(1, int(runner.players.size()))
	return minf(Tuning.intro_pop_stagger, Tuning.sports_intro_pop_window / float(n))

## WK-124: seconds from the goal (STAGE_END entry) to the first countdown beat = the goal freeze + the pop-in. The
## SportsHUD holds the goal banner across this whole span, so it overlaps the kickoff reset and leaves on the "3".
func goal_banner_span(runner) -> float:
	return stage_end_freeze(runner) + intro_pop_stagger(runner) * float(int(runner.players.size()))

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
		_record_goal_stats(scoring)   # WK-111
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
	out["ball_t"] = _latched_ball_t(runner, goal_t)   # WK-131 H4: GoalZone.scored_ball_t (primary kickoff clock)
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

# ------------------------------------------------------------------ WK-131 KICKOFF GATES (spec §4 / §8)

## True when this match's court gets kickoff gates (soccer + a non-zero rule). Rule 0 never builds a gate node.
func _gates_rule_on() -> bool:
	return _sport == "soccer" and int(Tuning.sports_kickoff_rule) != 0

## H6: "GOALS OPEN 3 SECONDS AFTER KICK OFF" (the number from Tuning, never hard-coded).
func _gate_rule_row() -> String:
	var s: float = Tuning.sports_gate_open_s if int(Tuning.sports_kickoff_rule) != 2 else Tuning.sports_live_fallback_s
	var num: String = str(int(s)) if is_equal_approx(s, roundf(s)) else ("%.1f" % s)
	return GATE_RULE_ROW % num

## H1 (on_stage_ready): one CLOSED gate per goal_zone, the latch gated until it opens. Also resets this stage's kickoff stats.
func _spawn_kickoff_gates(runner) -> void:
	_gates = []
	_gate_rule = int(Tuning.sports_kickoff_rule) if _gates_rule_on() else 0
	_ko_first_touch_t = -1.0
	_ko_teams_touched = [false, false]
	_ko_gate_hits = 0
	_ko_gate_speeds = []
	_ko_open_t = -1.0
	_ko_armed_t = -1.0
	_ko_spit = false
	_ko_runner = runner
	if _gate_rule == 0:
		return
	var lead := true
	for z in runner.get_tree().get_nodes_in_group("goal_zone"):
		if not is_instance_valid(z) or (z as Node).is_queued_for_deletion() or str(z.get("style")) == "hidden":
			continue
		var g: Node2D = KICKOFF_GATE_SCENE.instantiate() as Node2D
		runner._level_root.add_child(g)   # after the zones -> drawn over the cage frame at the same z; freed with the level
		g.call("setup", z, lead)
		lead = false
		z.call("set_gated", true)
		g.connect("hit", _on_gate_hit)
		g.connect("opened", _on_gate_opened)
		_gates.append(g)

## H2 (on_combat_start, after go_live): the gates run on the ball's live clock.
func _start_kickoff_gates() -> void:
	if _gates.is_empty() or not is_instance_valid(_ball):
		return
	var t: float = Tuning.sports_gate_open_s if _gate_rule == 1 else Tuning.sports_live_fallback_s
	for g in _gates:
		if is_instance_valid(g):
			g.call("start", _ball, t)

## H3 (_on_ball_touched): first-touch time + teams touched; rule 2 opens the gates once BOTH teams have touched.
func _kickoff_touch(team: int) -> void:
	if not is_instance_valid(_ball):
		return
	if _ko_first_touch_t < 0.0:
		_ko_first_touch_t = _ball.ball_clock()
	if team >= 0 and team < 2:
		_ko_teams_touched[team] = true
	if _gate_rule == 2 and _ko_open_t < 0.0 and _ko_armed_t < 0.0 and bool(_ko_teams_touched[0]) and bool(_ko_teams_touched[1]):
		_ko_armed_t = _ball.ball_clock()
		for g in _gates:
			if is_instance_valid(g):
				g.call("open_now")

func _on_gate_hit(speed) -> void:
	_ko_gate_hits += 1
	_ko_gate_speeds.append(snappedf(float(speed), 1.0))

## First gate open of the stage: record it; on match stage 1 the gold rule row flips to the sticker, then its normal copy.
func _on_gate_opened(spit) -> void:
	if bool(spit):
		_ko_spit = true
	if _ko_open_t >= 0.0:
		return
	_ko_open_t = _ball.ball_clock() if is_instance_valid(_ball) else 0.0
	var runner = _ko_runner
	if runner == null or not is_instance_valid(runner) or int(runner.stage_index) != 1:
		return
	var legend = runner.get("_legend")
	if legend == null or not is_instance_valid(legend) or not legend.has_method("set_goal_text"):
		return
	legend.call("set_goal_text", GATE_OPEN_STICKER, true)
	var stage: int = int(runner.stage_index)
	runner.get_tree().create_timer(GATE_STICKER_S, false).timeout.connect(func() -> void:
		if is_instance_valid(runner) and int(runner.stage_index) == stage and is_instance_valid(legend):
			legend.call("set_goal_text", _goal_line_normal(), false))

## H5: ball-clock seconds until the gates open (negative = seconds since they opened); INF when this stage has no gates
## or the clock has not started (pre-GO counts from the scheduled time).
func gates_open_in() -> float:
	if _gates.is_empty() or not is_instance_valid(_ball):
		return INF
	var t: float = _ball.ball_clock()
	if _ko_open_t >= 0.0:
		return _ko_open_t - t
	var g = _gates[0]
	if not is_instance_valid(g):
		return INF
	var sched: float = float(g.call("scheduled_open"))
	if sched == INF:
		sched = Tuning.sports_gate_open_s if _gate_rule == 1 else Tuning.sports_live_fallback_s
	return sched - t

## H4 (QA, spec §5.3): this stage's kickoff numbers. first_touch_t / gates_open_t / armed_t are ball-clock seconds
## (-1 = not happened); gate_hits = closed-gate contacts >= Tuning.sports_gate_fx_min_speed; spit = a resting ball was popped.
func kickoff_stats() -> Dictionary:
	return {"rule": _gate_rule, "first_touch_t": _ko_first_touch_t, "gate_hits": _ko_gate_hits,
		"gate_hit_speeds": _ko_gate_speeds.duplicate(), "gates_open_t": _ko_open_t, "armed_t": _ko_armed_t,
		"spit": _ko_spit, "teams_touched": _ko_teams_touched.duplicate()}

## H4: the latched zone's ball clock at the latch (GoalZone.scored_ball_t), else the ball clock now.
func _latched_ball_t(runner, fallback: float) -> float:
	for z in runner.get_tree().get_nodes_in_group("goal_zone"):
		if bool(z.get("scored")):
			var bt: Variant = z.get("scored_ball_t")
			if bt != null and float(bt) >= 0.0:
				return float(bt)
	return fallback

# ------------------------------------------------------------------ WK-111 (SP-09) match stats + end framing

## The stat dict of player `idx` (created on first use).
func _ps(idx: int) -> Dictionary:
	if not _pstats.has(idx):
		_pstats[idx] = {"goals": 0, "assists": 0, "own_goals": 0, "saves": 0, "touches": 0, "power": 0}
	return _pstats[idx]

## Ball.touched feed (bound with the runner in on_stage_ready): touches, power hits, saves.
func _on_ball_touched(p, is_power, runner) -> void:
	if runner == null or not is_instance_valid(runner):
		return
	var idx: int = runner.players.find(p)
	if idx < 0 or idx >= _teams.size():
		return
	var s := _ps(idx)
	s["touches"] = int(s["touches"]) + 1
	if bool(is_power):
		s["power"] = int(s["power"]) + 1
	_stage_touches += 1
	_kickoff_touch(int(_teams[idx]))   # WK-131 H3
	if _sport != "soccer" or not is_instance_valid(_ball):
		return
	var tl: Array = _ball.touch_log()
	if tl.is_empty():
		return
	var e: Dictionary = tl.back()
	if _is_save(runner, e, int(_teams[idx])):
		s["saves"] = int(s["saves"]) + 1
		_last_save = {"idx": idx, "t": float(e.get("t", 0.0))}

## WK-111 save rule (see STAT_SAVE_*): the ball was a shot at `team`'s own goal and this touch turned it away.
func _is_save(runner, e: Dictionary, team: int) -> bool:
	var g: Vector2 = _own_goal_center(runner, team)
	if g == Vector2.INF:
		return false
	var pos: Vector2 = e.get("pos", g)
	var vin: Vector2 = e.get("vin", Vector2.ZERO)
	var vout: Vector2 = e.get("vout", Vector2.ZERO)
	var d: Vector2 = g - pos
	var dist: float = d.length()
	if dist < 1.0:
		return false
	var dir: Vector2 = d / dist
	var tin: float = vin.dot(dir)
	if tin < STAT_SAVE_SPEED or dist / tin > STAT_SAVE_TIME:
		return false
	var cone: float = deg_to_rad(STAT_SAVE_CONE_DEG)
	if absf(vin.angle_to(d)) > cone:
		return false
	return vout.dot(dir) < tin * STAT_SAVE_KEEP or absf(vout.angle_to(d)) > cone

## WK-111: book the goal just credited by _credit_goal (goals / assists / own goals), the rally, and revoke a save
## the conceding team made moments before it went in anyway.
func _record_goal_stats(scoring: int) -> void:
	var si: int = int(_last_goal.get("scorer_idx", -1))
	if si >= 0:
		var s := _ps(si)
		if bool(_last_goal.get("own_goal", false)):
			s["own_goals"] = int(s["own_goals"]) + 1
		else:
			s["goals"] = int(s["goals"]) + 1
	var ai: int = int(_last_goal.get("assist_idx", -1))
	if ai >= 0:
		var a := _ps(ai)
		a["assists"] = int(a["assists"]) + 1
	var goal_t: float = _ball.ball_clock() if is_instance_valid(_ball) else 0.0
	if not _last_save.is_empty():
		var sv: int = int(_last_save["idx"])
		if sv < _teams.size() and int(_teams[sv]) == 1 - scoring \
				and goal_t - float(_last_save["t"]) <= STAT_SAVE_REVOKE:
			var ss := _ps(sv)
			ss["saves"] = maxi(0, int(ss["saves"]) - 1)
		_last_save = {}
	if _longest_rally.is_empty() or goal_t > float(_longest_rally["secs"]):
		_longest_rally = {"secs": goal_t, "touches": _stage_touches}

## WK-111 rating behind the MVP pick (MVP_POINTS).
func _rating(s: Dictionary) -> int:
	var r := 0
	for k in MVP_POINTS.keys():
		r += int(s.get(k, 0)) * int(MVP_POINTS[k])
	return r

## The winning team (0/1) by score; -1 while level (only meaningful at MATCH_END).
func winning_team() -> int:
	if int(_team_scores[0]) == int(_team_scores[1]):
		return -1
	return 0 if int(_team_scores[0]) > int(_team_scores[1]) else 1

## WK-111: everything the sports end screen shows. One row per player:
##   {idx, team, name, sub, color, skin, human, goals, assists, own_goals, saves, touches, power, rating}
## mvp = player index of the best rating on the winning team (ties: more goals, then lower index); -1 if none.
## longest_rally = {secs, touches} ({} if no goal). winning_goal = the last goal's credit (WK-106 _last_goal).
func match_stats(runner) -> Dictionary:
	var win: int = winning_team()
	var rows: Array = []
	var mvp: int = -1
	var mvp_r: int = -2147483647
	var mvp_g: int = -1
	for i in range(mini(runner.players.size(), _teams.size())):
		var p = runner.players[i]
		var s: Dictionary = _ps(i).duplicate()
		s["idx"] = i
		s["team"] = int(_teams[i])
		s["name"] = str(runner.player_name(i))
		s["sub"] = str(runner.player_subtag(i))
		s["color"] = runner.player_color(i)
		s["skin"] = str(p.skin) if is_instance_valid(p) else str(TEAM_SKINS[int(_teams[i])][0])
		s["human"] = bool(runner.is_human_player(i))
		s["rating"] = _rating(s)
		rows.append(s)
		if int(_teams[i]) == win:
			var r: int = int(s["rating"])
			var g: int = int(s["goals"])
			if r > mvp_r or (r == mvp_r and g > mvp_g):
				mvp = i
				mvp_r = r
				mvp_g = g
	return {
		"sport": _sport,
		"mode_name": display_name(),
		"scores": [int(_team_scores[0]), int(_team_scores[1])],
		"win_team": win,
		"team_names": TEAM_NAMES.duplicate(),
		"team_colors": TEAM_COLORS.duplicate(),
		"rows": rows,
		"mvp": mvp,
		"longest_rally": _longest_rally.duplicate(),
		"winning_goal": _last_goal.duplicate(),
		"goal_word": goal_word(),
	}

## WK-111 (SP-09): match-end presentation in the world. Frames the WINNING TEAM (bounding box of its goats + pad,
## zoom <= END_FRAME_MAX_ZOOM, the view clamped inside the court so it never shows void) instead of the runner's
## 1.1 punch-zoom on one representative goat (which landed on goal pillars / void), and every winner does the win
## pop (the runner only pops the representative). Called by SportsHUD.show_match_end, right after the runner's own
## punch-zoom set_frame — this replaces that target. Returns the frame {center, zoom} ({} if nothing to frame).
func present_match_end(runner) -> Dictionary:
	var win: int = winning_team()
	if win < 0:
		return {}
	var box := Rect2()
	var have := false
	var rep: int = _teams.find(win)   # the runner already popped this one (match_winner's first-of-team rule)
	for i in range(mini(runner.players.size(), _teams.size())):
		if int(_teams[i]) != win:
			continue
		var p = runner.players[i]
		if not is_instance_valid(p) or p.is_dead():
			continue
		if i != rep and p.has_method("play_win_pop"):
			p.play_win_pop()
		var at: Vector2 = p.global_position
		if have:
			box = box.expand(at)
		else:
			box = Rect2(at, Vector2.ZERO)
			have = true
	if not have:
		return {}
	# clamp inside the painted court (the level's play rect), not runner.bounds: bounds runs past the court art into
	# the enclosed-drum housing, so a bounds-clamped frame on a corner winner showed that flat void (Dropshot beach)
	var b: Rect2 = runner.bounds
	var sr: Variant = runner.get("_stage_rect")
	if sr is Rect2 and (sr as Rect2).size.x > 1.0 and (sr as Rect2).size.y > 1.0:
		b = sr
	var want: Rect2 = box.grow_individual(END_FRAME_PAD.x, END_FRAME_PAD.y, END_FRAME_PAD.x, END_FRAME_PAD.y)
	# floor = the zoom at which the view just COVERS the court on both axes (so no void either way)
	var cover_z: float = maxf(1920.0 / maxf(b.size.x, 1.0), 1080.0 / maxf(b.size.y, 1.0))
	var z: float = minf(1920.0 / maxf(want.size.x, 1.0), 1080.0 / maxf(want.size.y, 1.0))
	z = clampf(z, minf(cover_z, END_FRAME_MAX_ZOOM), END_FRAME_MAX_ZOOM)
	var half := Vector2(960.0, 540.0) / z
	var c: Vector2 = want.get_center()
	c.x = b.get_center().x if half.x * 2.0 >= b.size.x else clampf(c.x, b.position.x + half.x, b.end.x - half.x)
	c.y = b.get_center().y if half.y * 2.0 >= b.size.y else clampf(c.y, b.position.y + half.y, b.end.y - half.y)
	if runner.get("_camera") != null:
		runner._camera.set_frame(c, z)
	return {"center": c, "zoom": z}

## WK-15 (CC-11.1 / D-13): the stage-1 goal chip above the controls legend — the sport's one-line rule.
func goal_line(runner) -> String:
	if _sport == "dropshot":
		return "SPIKE IT OVER THE NET  ·  DON'T LET IT DROP  ·  FIRST TO %d" % _goal_cap
	if _gates_rule_on() and runner != null and int(runner.stage_index) == 1:   # WK-131 H6: stage 1 teaches the gates
		return _gate_rule_row()
	return _goal_line_normal()

func _goal_line_normal() -> String:
	return "HEADBUTT THE BALL INTO THEIR GOAL  ·  FIRST TO %d" % _goal_cap

## The score exclamation ("GOAL!" for soccer, "POINT!" for DROPSHOT). Read by the HUD flash too.
func goal_word() -> String:
	return "POINT!" if _sport == "dropshot" else "GOAL!"

## Bot SPORTS objective (the load-bearing fix): steer the bot to a point that lets it hit the BALL
## toward its ENEMY goal. Approach the ball from the side AWAY from the enemy goal; once basically on
## the ball, aim THROUGH it toward the goal so the boosting contact drives it goalward. Returns a world
## Vector2 the bot flies to via its existing movement, or null (no ball yet) -> bot uses its default path.
func bot_objective(runner, bot_player) -> Variant:
	var target: Variant = _bot_objective_raw(runner, bot_player)
	if wk108_bots and wk108_enclosed and target is Vector2:
		return _below_ceiling(runner, target)
	return target

## WK-108: never send a bot to a point tucked under the court ceiling or a mid-court block: probe up from the
## target and keep it BOT_CEILING_CLEAR below the first surface (the ball can sit up there; the bot waits under it).
func _below_ceiling(runner, p: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(p, p + Vector2.UP * BOT_CEILING_CLEAR, Player.MASK_SURFACES)
	var hit: Dictionary = runner.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return p
	return Vector2(p.x, maxf(p.y, (hit["position"] as Vector2).y + BOT_CEILING_CLEAR))

func _bot_objective_raw(runner, bot_player) -> Variant:
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
	var level: int = _bot_level(bot_player)
	if rank > 0:
		# WK-108 (b) keeper / (c) far-post run; otherwise the PROTECTED goal-side cover point (SUPPORT_HOLD_FRAC)
		if wk108_bots and _sport == "soccer":
			var keep: Variant = _keeper_point(runner, my_team, bot_player, ball_pos)
			if keep is Vector2:
				return keep
			if level >= BOT_CROSS_MIN_LEVEL:
				var run: Variant = _cross_run_point(runner, my_team, ball_pos)
				if run is Vector2:
					return run
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
		# WK-108 (c): an L4+ chaser lined up behind the ball crosses to an unmarked teammate nearer the goal
		if wk108_bots and _sport == "soccer" and level >= BOT_CROSS_MIN_LEVEL:
			var mate: Variant = _cross_target(runner, idx, my_team, ball_pos, enemy_goal)
			if mate is Vector2:
				return ball_pos + ((mate as Vector2) - ball_pos).normalized() * BOT_DRIVE_THROUGH
		return ball_pos + to_goal * BOT_DRIVE_THROUGH
	# WK-108 (a): never fly THROUGH the ball to reach the strike point behind it
	if not wk108_bots:
		return behind
	if _sport == "soccer" and not behind_ball:
		var back: Variant = _trackback_point(runner, my_team, ball_pos)
		if back is Vector2:
			return _avoid_ball_waypoint(runner, bot_player.global_position, ball_pos, back, to_goal)
	return _avoid_ball_waypoint(runner, bot_player.global_position, ball_pos, behind, to_goal)

## WK-108 (a): if the straight line from `me_pos` to `strike` passes within the clearance of the ball, return a
## waypoint beside the ball (perpendicular to the ball->goal line, over the top unless the ceiling is too close),
## else `strike`. Re-evaluated every bot decision, so the bot commits to `strike` the moment the line is clear.
func _avoid_ball_waypoint(runner, me_pos: Vector2, ball_pos: Vector2, strike: Vector2, to_goal: Vector2) -> Vector2:
	var br: float = (_ball.radius if is_instance_valid(_ball) else Ball.BALL_RADIUS)
	var clear: float = BOT_AVOID_CLEAR_MULT * (br + BOT_BODY_RADIUS)
	# the ball keeps moving between my decisions: keep clear of where it IS and where it WILL BE, orbit the latter
	var pred: Vector2 = ball_pos + (_ball.linear_velocity if is_instance_valid(_ball) else Vector2.ZERO) * BOT_BALL_LEAD
	if _dist_to_segment(ball_pos, me_pos, strike) >= clear and _dist_to_segment(pred, me_pos, strike) >= clear:
		return strike
	ball_pos = pred
	# ORBIT the ball: step around a circle of radius clear*BOT_AVOID_ORBIT_MULT from my current bearing toward the
	# strike side, going over the top (unless the ceiling is too close), BOT_AVOID_STEP_DEG at a time. Each step's
	# chord stays outside the ball, so the line-up flight never touches it (a straight perpendicular waypoint
	# still clipped it: 13 of 19 own goals in a THE BOX A/B came from wrong-side chasers).
	var r: float = clear * BOT_AVOID_ORBIT_MULT
	var court: Rect2 = runner.bounds.grow(-BOT_CEILING_CLEAR)
	var a_me: float = (me_pos - ball_pos).angle()
	var a_to: float = (-to_goal).angle()
	var diff: float = wrapf(a_to - a_me, -PI, PI)
	var top_ok: bool = ball_pos.y - r >= court.position.y
	# the two ways round: +diff (short) or the long way; pick the one that passes over the top when allowed
	var mid_short: Vector2 = Vector2.from_angle(a_me + diff * 0.5)
	var dir_sign: float = signf(diff) if diff != 0.0 else 1.0
	if top_ok and mid_short.y > 0.0:
		dir_sign = -dir_sign       # the short way goes underneath: go round the top instead
	elif not top_ok and mid_short.y < 0.0:
		dir_sign = -dir_sign       # no room over the top: go underneath
	var step: float = deg_to_rad(BOT_AVOID_STEP_DEG)
	var wp: Vector2 = ball_pos + Vector2.from_angle(a_me + dir_sign * step) * r
	return Vector2(clampf(wp.x, court.position.x, court.end.x), clampf(wp.y, court.position.y, court.end.y))

## WK-108 track-back: if the ball is running at my goal, a goal-side point above its line (else null).
func _trackback_point(runner, my_team: int, ball_pos: Vector2) -> Variant:
	var own_goal: Vector2 = _own_goal_center(runner, my_team)
	if own_goal == Vector2.INF or not is_instance_valid(_ball):
		return null
	var to_own: Vector2 = own_goal - ball_pos
	if to_own.length() < 1.0 or _ball.linear_velocity.dot(to_own.normalized()) < BOT_TRACKBACK_SPEED:
		return null
	var box: Rect2 = runner.bounds.grow(-BOT_CEILING_CLEAR)
	var mouth := Vector2(clampf(own_goal.x, box.position.x, box.end.x), clampf(own_goal.y, box.position.y, box.end.y))
	var p: Vector2 = mouth.lerp(ball_pos, BOT_TRACKBACK_FRAC) + Vector2.UP * BOT_TRACKBACK_UP
	return Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y))

static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

## WK-108 (b): the keeper hold / challenge point for a supporter, or null when the ball is not threatening.
## Threat = the ball inside my own third, or moving at my goal fast enough to reach it within the shot time.
func _keeper_point(runner, my_team: int, bot_player, ball_pos: Vector2) -> Variant:
	var own_goal: Vector2 = _own_goal_center(runner, my_team)
	var enemy_goal: Vector2 = _enemy_goal_center(runner, my_team)
	if own_goal == Vector2.INF or enemy_goal == Vector2.INF:
		return null
	var axis: float = enemy_goal.x - own_goal.x
	if absf(axis) < 1.0:
		return null
	var frac: float = (ball_pos.x - own_goal.x) / axis
	var bv: Vector2 = _ball.linear_velocity if is_instance_valid(_ball) else Vector2.ZERO
	var toward: float = -bv.x * signf(axis)                 # ball speed toward MY goal line
	var shot: bool = toward >= BOT_KEEPER_SHOT_SPEED and (ball_pos.x - own_goal.x) * signf(axis) / toward <= BOT_KEEPER_SHOT_TIME
	var kickoff: bool = float(runner.round_clock) < BOT_KICKOFF_KEEP_S
	if _gate_rule == 1 and not _gates.is_empty():   # WK-131 H5: keep goal around the open, not the (unscorable) first 3 s
		var open_in: float = gates_open_in()
		kickoff = open_in <= BOT_GATE_RETURN_LEAD_S and open_in >= -BOT_GATE_KEEP_AFTER_S
	if frac > BOT_KEEPER_THIRD and not shot and not kickoff:
		return null
	var box: Rect2 = runner.bounds.grow(-SUPPORT_COURT_MARGIN)
	var mouth := Vector2(clampf(own_goal.x, box.position.x, box.end.x), clampf(own_goal.y, box.position.y, box.end.y))
	if ball_pos.distance_to(mouth) <= BOT_KEEPER_CHALLENGE:
		# challenge: clear it AWAY from my goal (we come from the goal side, so driving through pushes it out)
		var away: Vector2 = (ball_pos - own_goal).normalized()
		return ball_pos + away * BOT_DRIVE_THROUGH
	if shot:
		# put the body on the ball's line, between it and the mouth
		return mouth.lerp(ball_pos, 0.25)
	return mouth

## WK-108 (c): an L4+ supporter's far-post run while the ball is in the attacking half (else null).
func _cross_run_point(runner, my_team: int, ball_pos: Vector2) -> Variant:
	var own_goal: Vector2 = _own_goal_center(runner, my_team)
	var enemy_goal: Vector2 = _enemy_goal_center(runner, my_team)
	if own_goal == Vector2.INF or enemy_goal == Vector2.INF:
		return null
	var axis: float = enemy_goal.x - own_goal.x
	if absf(axis) < 1.0 or (ball_pos.x - own_goal.x) / axis < BOT_CROSS_RUN_FRAC:
		return null
	var p: Vector2 = enemy_goal + Vector2(-signf(axis) * BOT_CROSS_POST_BACK, -BOT_CROSS_POST_UP)
	var box: Rect2 = runner.bounds.grow(-BOT_CEILING_CLEAR)
	return Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y))

## WK-108 (c): the position of a teammate worth crossing to (nearer the enemy goal than the ball, goalward of it,
## unmarked), or null.
func _cross_target(runner, idx: int, my_team: int, ball_pos: Vector2, enemy_goal: Vector2) -> Variant:
	var to_goal: Vector2 = (enemy_goal - ball_pos).normalized()
	var ball_gd: float = ball_pos.distance_to(enemy_goal)
	for j in range(runner.players.size()):
		if j == idx or j >= _teams.size() or int(_teams[j]) != my_team:
			continue
		var m = runner.players[j]
		if not is_instance_valid(m) or m.is_dead():
			continue
		var mp: Vector2 = m.global_position
		if mp.distance_to(enemy_goal) >= ball_gd - 150.0:
			continue
		if (mp - ball_pos).normalized().dot(to_goal) < BOT_CROSS_GOALWARD:
			continue
		var marked := false
		for k in range(runner.players.size()):
			if k >= _teams.size() or int(_teams[k]) == my_team:
				continue
			var o = runner.players[k]
			if is_instance_valid(o) and not o.is_dead() and o.global_position.distance_to(mp) < BOT_CROSS_MARK_DIST:
				marked = true
				break
		if not marked:
			return mp
	return null

## The bot level of a player's InputBot provider (3 if unknown / human).
func _bot_level(p) -> int:
	if p == null or not is_instance_valid(p) or p.provider == null or not ("level" in p.provider):
		return 3
	return int(p.provider.level)

## WK-108: SPORTS courts are ENCLOSED (walls + ceiling stop you): InputBot must not read "about to fly out of
## the arena" as danger here (it U-turned bots at every wall: the sports stuck loops), and it keeps its flight
## under the ceiling instead. Holes in a Dropshot floor are still real void (InputBot keeps that check).
func bot_enclosed_court() -> bool:
	return wk108_bots and wk108_enclosed

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
	var cover: Vector2 = own_goal.lerp(ball_pos, SUPPORT_HOLD_FRAC)   # PROTECTED (WK-98 §2)
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
