class_name PartyMatch
extends Node2D
## The real Party match (docs/specs/v1_party_killrace.md — kill-race rework of v0_round_loop.md).
## Boots straight into 1 human (P1, pink) + 3 bots (levels 2/3/4 — punchline / fair fight / menace).
##
## Stage drumbeat: rotate to the next level -> staggered pop-in intro w/ name tags ->
## "3-2-1-BOUNCE!" -> lives-based combat (default 1 life) -> a stage ends when <=1 player is
## not-eliminated (last-one-standing; NO round clock, NO timer) -> 1.8s KO freeze + "Pn SURVIVES!"
## banner -> next stage (new level), or MATCH_END when a player reaches match_target_kills with a
## strict lead. Sudden death fires ONLY on a simultaneous double-KO (last two lose their last life
## within double_ko_window) -> both revive at center spawns pre-damaged Lv2 for a timer-free 1v1.
##
## Scoring: score = CUMULATIVE KILLS across stages (never reset per stage). +1 per credited kill
## (4.0s last-attacker credit, beyond-the-grave counts); suicide = -1 to your own total floored at 0.
## Match ends on the winning KILL (immediate freeze + punch-zoom). NO survival point.
##
## QA contract (killrace §8, read via gbplay eval): state / stage_index (round_index alias) /
## scores (cumulative kills) / level_index / level_name / bounds / lives_left / round_stats
## (per-stage {stage_index, level_name, length_s, end_cause, entered_sd, kills[], survivor_had_contact,
## supers_fired[], smashes[]}). Arena contract (InputBot/Playtest): players / scores / bounds /
## nearest_opponent() / stage_rect() / stage_center() / idle_hunt_target().

# Level pool for the shuffle-bag rotation (killrace §6). v0 ships one file; slice D adds more and
# the bag then avoids immediate repeats. With a 1-level pool rotation degenerates to a replay.
# Circuit (owner: test/play on a rotating pool of ~10 spaced-out levels; docs/feedback/
# owner_2026-07-03_arena_size.md + owner_2026-07-04_arena_variety.md). islands_void is the
# FLAGSHIP / primary (islands-over-a-void, bottom-void = the dominant kill shape, flight-required);
# grassy_expanse (central-pit variant, 2x, flight-required) is kept as a secondary pool entry.
# dev_arena is the too-tight "mini" and stays OUT of the pool. More levels land as the circuit grows.
const LEVEL_POOL: Array[String] = [
	"res://levels/islands_void.json",
	"res://levels/grassy_expanse.json",
]
const NUM_BOTS := 3
# Character skins: P1 is always pink; bots take blue/green/yellow in order.
const BOT_SKINS: Array[String] = ["blue", "green", "yellow"]
const PLAYER_COLORS: Array[Color] = [
	Color("#ff5fa8"), Color("#4aa8ff"), Color("#54c94a"), Color("#ffc93f")]
const HUD_SCENE := preload("res://scenes/ui/MatchHUD.tscn")
const NAME_TAG_SCENE := preload("res://scenes/ui/NameTag.tscn")

# --- Camera 2x policy (docs/briefs/camera_2x_policy.md) ---
# Action-cluster framing + readability-floored zoom on the wide grassy_expanse. The old fit-to-global-
# spread over-zoomed to ~0.42 (bouncers ~30px) during 4-player combat, killing Pillar-5 readability.
const CAM_MIN_ZOOM := 0.60     # normal-combat readability floor (was 0.37). Body >= ~63px @1080p:
                               # color ID, face, and crimson damage-pulse rim all read.
const CAM_LAUNCH_MIN_ZOOM := 0.42  # kill-cam exception: allowed ONLY while a living player is in
                               # high knockback heading outward (see LAUNCH_SPEED_FOR_CAM). Eases
                               # back up to CAM_MIN_ZOOM over LAUNCH_EASE_BACK once knockback settles.
const CAM_LEAD_TIME := 0.32    # kill-zone spec §6.4: frame ahead of each flier's velocity so a fast
                               # (capped 2200) launch + its approaching blast line stay on-screen.
const CAM_LEAD_CAP := 700.0    # px: cap each player's velocity-lead contribution so the lead is a
                               # nudge, not a spread-forcer — the readability floor wins.
const CAM_MAX_ZOOM := 0.92     # never zoom in tighter than this
const LAUNCH_SPEED_FOR_CAM := 1300.0  # px/s outward -> engages the launch-cam floor
const LAUNCH_EASE_BACK := 0.4  # s to ease the launch floor back to CAM_MIN_ZOOM
const SUPER_BIAS_MIN_ZOOM := 0.70  # zoom-target floor while a super is charging (aim-fuse legibility)
const SUPER_BIAS_WEIGHT := 2.5     # centroid weight on the charging caster (frame the aim)
const CAM_OFFSCREEN_INSET := 40.0  # px: a living player outside visible rect+inset gets an edge chevron
const COMBAT_ACTIVE_WINDOW := 1.2  # s since dealing/taking a hit or firing/charging a super to count
                               # for the action-cluster centroid bias
const CAM_MARGIN := Vector2(420.0, 340.0)  # breathing room added around the framed cluster
const MATCH_END_ZOOM := 1.1    # winner punch-zoom (FEEL §7)
const BOUNCE_HOLD := 0.4       # "BOUNCE!" banner hold (spec §1)
const NAME_TAG_LINGER := 1.0   # name tags fade this long into COMBAT
const NAME_TAG_FADE := 0.4
const SD_REVIVE_LOCK := 0.8    # "SUDDEN DEATH!" revive banner hold, inputs locked (spec §5)
const PROMPT_GUARD := 1.0      # MATCH_END input guard before REMATCH/QUIT arms (spec §1)
const GOLD := Color("#ffd23f")
const DANGER := Color("#ff4b3a")

# --- QA contract (killrace §8) ---
var state := "BOOT"
var stage_index := 0
var round_index := 0             # alias of stage_index (QA/tools may read either)
var round_clock := 0.0           # stat-only combat clock; gates NOTHING (no timer SD anymore)
var scores: Array = []           # CUMULATIVE kills per player, never reset between stages
var lives_left: Array = []       # per-player remaining lives this stage (0 = eliminated)
var level_index := -1            # index into LEVEL_POOL of the current stage's level
var level_name := ""             # display name of the current stage's level (rotation QA readout)
var _kill_shape := "central_pit" # v2a addendum §4b: current level's kill-shape class (QA target select)
var last_death_msec := 0         # ticks_msec of the most recent death (turnaround measurement)
var combat_start_msec := 0       # ticks_msec of the last "BOUNCE!" physics unlock
var round_stats: Array = []      # per-stage QA record: {stage_index, level_name, kill_shape, length_s, end_cause,
                                 # entered_sd, kills[{killer,victim,off_stage,t}], survivor_had_contact,
                                 # supers_fired[...], smashes[...]}
var _cur_stats: Dictionary = {}  # the stage currently being recorded

# --- arena contract (InputBot / Playtest) ---
var players: Array = []
var bounds: Rect2

var _spawns: Array = []
var _pu_points: Array = []       # powerup_spawner positions from the level JSON
var _pu_director                 # PowerupSpawnDirector (spec v1_powerups §4 pacing)
var _stage_rect := Rect2(0, 0, 1920, 320)
var _camera: CameraController
var _juice: Juice
var _level_root: Node2D
var _hud
var _had_contact: Array = []     # per-player: dealt/received >=1 smash this stage (stats)
var _smash_off_stage: Array = [] # per-player: was the LAST smash they received taken off-stage?
var _combat_active_t: Array = [] # per-player: seconds left in the combat-active window (camera bias)
var _launch_ease_t := 0.0        # >0 while the launch-cam floor is engaged / easing back
var _edge_indicators             # EdgeIndicators overlay (off-screen player chevrons)

# level rotation (shuffle-bag)
var _bag: Array = []
var _last_level_path := ""

# stage/match bookkeeping
var _state_t := 0.0
var _popped := 0
var _cd_beat := -1
var _sd_lock := 0.0              # sudden-death revive input lock countdown
var _end_check := -1.0          # pending stage-decision timer (double-KO window)
var _recent_dead: Array = []    # simultaneous-elimination group (double-KO SD, spec §5)
var _last_death_clock := 0.0
var _revived_this_stage := false # one sudden-death revive max per stage (no recursion)
var _stage_deltas: Array = []   # applied kill deltas this stage (for the STAGE_END sub-line)
var _stage_start_alive := 0
var _stage_winner := -1
var _two_left_fired := false
var _first_blood_fired := false  # once per MATCH (spec §4)
var _match_point_announced := {} # player idx -> true, fires once per player per match
var _pending_match_point: Array = []
var _tiebreaker_next := false
var _match_winner := -1
var _prompt_shown := false
var _name_tags: Array = []

func _ready() -> void:
	bounds = Rect2(-120, -120, 2160, 1380)
	_level_root = Node2D.new()
	add_child(_level_root)
	_reset_bag()
	_load_stage(LEVEL_POOL[0])   # a level exists before the camera/HUD reference _stage_rect

	_camera = CameraController.new()
	_camera.position = _stage_rect.get_center()
	_camera.dynamic = true   # Smash-style: follow the action, zoom to keep everyone on screen
	_camera.follow_speed = 8.0   # kill-zone spec §6.4: tighter follow so a fresh launch doesn't outrun the frame
	add_child(_camera)
	_camera.snap_to(_stage_rect.get_center(), CAM_MAX_ZOOM)
	_juice = Juice.new()
	add_child(_juice)
	_juice.setup(_camera)
	KillPipeline.killed.connect(_on_killed)
	EventBus.smashed.connect(_on_smashed)          # contact flags + off-stage bookkeeping
	EventBus.smash_landed.connect(_on_smash_landed)  # hit-solidity QA feed (kill-zone spec §8)
	EventBus.super_fired.connect(_on_super_fired)  # round_stats QA feed (lethality §8)

	# powerup spawn pacing (docs/specs/v1_powerups.md §4)
	_pu_director = PowerupSpawnDirector.new()
	add_child(_pu_director)
	_pu_director.setup(self, _pu_points)

	# P1 human + 3 bots (spec §4: mixed 2/3/4 lineup from Tuning.bot_levels)
	_spawn_player(0, true)
	for b in range(NUM_BOTS):
		_spawn_player(1 + b, false)

	# corner HUD cards visible immediately (spec §1 BOOT)
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.setup(players, PLAYER_COLORS, _skins())

	# off-screen player edge chevrons (camera_2x_policy §3): own CanvasLayer, BELOW the HUD (layer 0
	# vs the HUD's default layer 1) so corner cards stay on top of any edge indicator.
	var edge_cl := CanvasLayer.new()
	edge_cl.layer = 0
	add_child(edge_cl)
	_edge_indicators = load("res://src/ui/EdgeIndicators.gd").new()
	edge_cl.add_child(_edge_indicators)
	_edge_indicators.setup(self, PLAYER_COLORS)

	_start_match()

func _spawn_player(i: int, human: bool) -> void:
	var p := Player.new()
	p.skin = "pink" if human else BOT_SKINS[(i - 1) % BOT_SKINS.size()]
	add_child(p)
	p.global_position = _spawn_at(i)
	players.append(p)
	scores.append(0)
	lives_left.append(Tuning.lives_per_player)
	if human:
		p.set_provider(InputHuman.new())
		p.add_to_group("human")
	else:
		var lvl: int = Tuning.bot_levels[(i - 1) % Tuning.bot_levels.size()]
		p.set_provider(InputBot.new(p, self, lvl))

func _skins() -> Array:
	var out: Array = ["pink"]
	for b in range(NUM_BOTS):
		out.append(BOT_SKINS[b % BOT_SKINS.size()])
	return out

# ------------------------------------------------------------------- level rotation (§6)

func _reset_bag() -> void:
	_bag = LEVEL_POOL.duplicate()
	_bag.shuffle()

## Draw the next level from the shuffle-bag; reshuffle when empty, avoiding an immediate repeat when
## the pool has >=2 entries. With a 1-level pool this returns that level every time (graceful replay).
func _next_level_path() -> String:
	if _bag.is_empty():
		_reset_bag()
		if LEVEL_POOL.size() >= 2 and _bag.size() > 1 and str(_bag[0]) == _last_level_path:
			_bag.append(_bag.pop_front())
	var path: String = str(_bag.pop_front())
	_last_level_path = path
	return path

func _load_stage(path: String) -> void:
	for c in _level_root.get_children():
		c.queue_free()
	var data := LevelLoader.load_level(path, _level_root)
	_spawns = data.get("spawns", [])
	_pu_points = data.get("powerup_spawners", [])
	bounds = data.get("bounds", Rect2(-120, -120, 2160, 1380))
	_stage_rect = data.get("play_rect", Rect2(bounds.get_center() - Vector2(900, 160), Vector2(1800, 320)))
	level_index = maxi(0, LEVEL_POOL.find(path))
	level_name = str(data.get("name", path.get_file().get_basename()))
	_kill_shape = str(data.get("kill_shape", "central_pit"))   # v2a §4b#1: QA target class

# ------------------------------------------------------------------- state machine

func _physics_process(delta: float) -> void:
	# UI/flow beats run on REAL time: hitstop scales `delta`, and the pillar-4 turnaround
	# contract (last death -> next BOUNCE <= 4.5s) is measured on the wall clock.
	var rdelta := delta / maxf(Engine.time_scale, 0.05)
	match state:
		"STAGE_INTRO":
			_tick_intro(rdelta)
		"COUNTDOWN":
			_tick_countdown(rdelta)
		"COMBAT", "SUDDEN_DEATH":
			_tick_combat(delta, rdelta)
		"STAGE_END":
			_tick_stage_end(rdelta)
		"MATCH_END":
			_tick_match_end(rdelta)
	if state != "MATCH_END":
		_update_camera()

## BOOT/rematch entry: zero everything match-scoped, then straight into the first STAGE_INTRO (spec §1).
func _start_match() -> void:
	state = "MATCH_START"
	for i in range(scores.size()):
		scores[i] = 0
	stage_index = 0
	round_index = 0
	round_stats.clear()
	_cur_stats = {}
	_first_blood_fired = false
	_match_point_announced.clear()
	_pending_match_point.clear()
	_tiebreaker_next = false
	_match_winner = -1
	_reset_bag()               # fresh shuffle-bag each match (spec §6)
	_hud.reset_scores()
	EventBus.match_started.emit()   # audio: (re)start gameplay music
	_begin_stage()

## STAGE_INTRO: rotate to the next level FIRST (spec §3/§6), then the pop-in — everyone suspended &
## invisible at the new level's spawns, popped in one at a time with name tags.
func _begin_stage() -> void:
	stage_index += 1
	round_index = stage_index
	round_clock = 0.0
	_state_t = 0.0
	_popped = 0
	_cd_beat = -1
	_sd_lock = 0.0
	_end_check = -1.0
	_recent_dead.clear()
	_revived_this_stage = false
	_two_left_fired = false
	_stage_winner = -1
	_stage_deltas.clear()
	_had_contact.clear()
	_smash_off_stage.clear()
	# rotate the level BEFORE the pop-in so the establishing shot frames the new level (§6)
	_load_stage(_next_level_path())
	if _camera != null:
		_camera.snap_to(_stage_rect.get_center(), CAM_MAX_ZOOM)
	_hud.hide_center()
	_clear_name_tags()
	for i in range(players.size()):
		var p = players[i]
		_stage_deltas.append(0)
		_had_contact.append(false)
		_smash_off_stage.append(false)
		lives_left[i] = Tuning.lives_per_player
		p.respawn(_spawn_at(i))
		p.frozen = true
		p.visible = false
		_hud.set_dead(i, false)
	_stage_start_alive = players.size()
	state = "STAGE_INTRO"
	if _tiebreaker_next:
		_tiebreaker_next = false
		_hud.show_center("TIEBREAKER!", GOLD, 1.0)

func _tick_intro(delta: float) -> void:
	_state_t += delta
	while _popped < players.size() and _state_t >= Tuning.intro_pop_stagger * float(_popped):
		_pop_in(_popped)
		_popped += 1
	# last pop at (n-1)*stagger, plus one more stagger as a beat = ~1.4s total (spec §1)
	if _popped >= players.size() and _state_t >= Tuning.intro_pop_stagger * float(players.size()):
		_start_countdown()

func _pop_in(i: int) -> void:
	var p = players[i]
	p.visible = true
	p.play_pop_in()
	_spawn_star_burst(p.global_position)
	var tag := NAME_TAG_SCENE.instantiate()
	p.add_child(tag)
	tag.position = Vector2(0, -112)
	tag.setup("P%d" % (i + 1), PLAYER_COLORS[i])
	_name_tags.append(tag)

func _start_countdown() -> void:
	state = "COUNTDOWN"
	_state_t = 0.0
	_cd_beat = -1
	if _pending_match_point.size() > 0:   # announced at the next stage's countdown (spec §4)
		var names: Array[String] = []
		for i in _pending_match_point:
			names.append("P%d" % (int(i) + 1))
		var c: Color = PLAYER_COLORS[int(_pending_match_point[0])] if _pending_match_point.size() == 1 else Color.WHITE
		_hud.show_top("MATCH POINT — " + " & ".join(names), c, 1.2)
		_pending_match_point.clear()

func _tick_countdown(delta: float) -> void:
	_state_t += delta
	var beat := int(_state_t / Tuning.countdown_beat)
	if beat != _cd_beat and beat <= 2:
		_cd_beat = beat
		_hud.show_center(str(3 - beat), Color.WHITE, Tuning.countdown_beat)
		EventBus.countdown_tick.emit(3 - beat)   # audio: 3 / 2 / 1 beep
	if _state_t >= Tuning.countdown_beat * 3.0:
		_bounce_go()

## "BOUNCE!": physics + input enable for everyone on the same frame — the starting gun (spec §1).
func _bounce_go() -> void:
	state = "COMBAT"
	round_clock = 0.0
	combat_start_msec = Time.get_ticks_msec()
	_cur_stats = {
		"stage_index": stage_index, "level_name": level_name,
		"kill_shape": _kill_shape,   # v2a §4b#1: QA aggregator selects K1 vs K1'/DC1/AS1 from THIS
		"length_s": 0.0, "end_cause": "none", "entered_sd": false,
		"kills": [], "survivor_had_contact": false, "supers_fired": [],
		"smashes": [],   # kill-zone spec §8: hit-solidity distribution + recovery correlation feed
	}
	for p in players:
		p.frozen = false
		p.fuel = Tuning.fuel_max   # every stage starts on a full tank
	if _pu_director != null:
		_pu_director.reset()       # first telegraph pu_first_spawn after BOUNCE! (spec §4)
	_hud.show_center("BOUNCE!", GOLD, BOUNCE_HOLD)
	EventBus.combat_started.emit()   # audio: "BOUNCE!" starting gun
	get_tree().create_timer(NAME_TAG_LINGER).timeout.connect(_fade_name_tags)

func _tick_combat(delta: float, rdelta: float) -> void:
	round_clock += delta   # stat only; gates nothing
	# sudden-death revive lock: banner holds, both revived players suspended (spec §5)
	if _sd_lock > 0.0:
		_sd_lock -= rdelta
		if _sd_lock <= 0.0:
			for p in _alive_players():
				p.frozen = false
		return
	# idle-hunt bookkeeping (lethality §3.2 rule 3): ticks only during combat; the Player
	# resets its own counter on boost/super input
	for p in players:
		if is_instance_valid(p) and not p.is_dead():
			p.secs_since_input += delta
	# ring-out at bounds (all deaths route through KillPipeline)
	for p in players:
		if is_instance_valid(p) and not p.is_dead() and not bounds.has_point(p.global_position):
			p.kill(&"ring_out", null)
	# deferred stage decision: wait double_ko_window after a death that left <=1 not-eliminated
	if _end_check >= 0.0:
		_end_check -= rdelta
		if _end_check <= 0.0:
			_end_check = -1.0
			_decide_stage_end(true)

# ------------------------------------------------------------------- deaths & scoring

## Contact bookkeeping (stats): a `smashed` event flags BOTH sides (shoves never emit it), and
## records whether the victim took the hit off-stage (test 15 edge-kill correlation).
func _on_smashed(attacker, victim, _impulse) -> void:
	if state != "COMBAT" and state != "SUDDEN_DEATH":
		return
	var ai := players.find(attacker)
	var vi := players.find(victim)
	_mark_combat_active(ai)   # camera action-cluster bias (camera_2x_policy §2)
	_mark_combat_active(vi)
	if ai >= 0 and ai < _had_contact.size():
		_had_contact[ai] = true
	if vi >= 0 and vi < _had_contact.size():
		_had_contact[vi] = true
		if is_instance_valid(victim):
			_smash_off_stage[vi] = not _stage_rect.grow(120.0).has_point(victim.global_position)

func _on_super_fired(player, fuel_at_fire, aim_time, auto_fired) -> void:
	_mark_combat_active(players.find(player))   # camera action-cluster bias (camera_2x_policy §2)
	if _cur_stats.is_empty() or (state != "COMBAT" and state != "SUDDEN_DEATH"):
		return
	var who := players.find(player)
	var fired: Array = _cur_stats["supers_fired"]
	fired.append({
		"who": who, "fuel_at_fire": fuel_at_fire, "aim_time": aim_time, "auto_fired": auto_fired,
		"t": round_clock,
	})

## Hit-solidity QA feed (kill-zone spec §8): one entry per qualifying smash. Read-only QA data.
func _on_smash_landed(attacker, victim, info: Dictionary) -> void:
	if _cur_stats.is_empty() or (state != "COMBAT" and state != "SUDDEN_DEATH"):
		return
	var smashes: Array = _cur_stats["smashes"]
	smashes.append({
		"t": round_clock,
		"attacker": players.find(attacker) if attacker != null else -1,
		"victim": players.find(victim) if victim != null else -1,
		"solidity": info.get("solidity", 0.0),
		"launch_scale": info.get("launch_scale", 0.0),
		"launch_speed": info.get("launch_speed", 0.0),
		"angle_deg": info.get("angle_deg", 0.0),
		"by_super": info.get("by_super", false),
		"victim_fuel_after": info.get("victim_fuel_after", 0.0),
		"starved": info.get("starved", false),
		"spin": info.get("spin", 0.0),
		"victim_damage_level": info.get("victim_damage_level", 0),
		"launch_mult": info.get("launch_mult", 1.0),
		"sting_applied": info.get("sting_applied", 0.0),
	})

func _on_killed(victim, cause, attacker) -> void:
	var idx := players.find(victim)
	if idx < 0:
		return
	last_death_msec = Time.get_ticks_msec()
	if state != "COMBAT" and state != "SUDDEN_DEATH":
		return
	# stage_stats kill record: off_stage = the killing smash connected while the victim was off-stage
	if not _cur_stats.is_empty():
		var ki: int = players.find(attacker) if attacker != null else -1
		var kills: Array = _cur_stats["kills"]
		kills.append({
			"killer": ki, "victim": idx,
			"off_stage": _smash_off_stage[idx] if idx < _smash_off_stage.size() else false,
			"blast_edge": _classify_blast_edge(victim),   # v2_kill_shape §6: which bound the victim crossed (K1)
			"t": round_clock,
		})
		_cur_stats["end_cause"] = str(cause)   # the stage-deciding death overwrites last
	# kill credit vs suicide (spec §2). Every cause counts; dead attackers still score
	# ("beyond the grave"); being killed is never -1. Score is CUMULATIVE kills.
	var ai: int = players.find(attacker) if attacker != null else -1
	if ai >= 0 and ai != idx:
		scores[ai] = int(scores[ai]) + 1
		_stage_deltas[ai] = int(_stage_deltas[ai]) + 1
		if not _first_blood_fired:
			_first_blood_fired = true
			_hud.show_top("FIRST BLOOD!", PLAYER_COLORS[ai], 1.0)
			EventBus.first_blood.emit(ai)   # audio: announcer
	elif int(scores[idx]) > 0:   # suicide: -1 to your own kill total, floored at 0 (spec §2)
		scores[idx] = int(scores[idx]) - 1
		_stage_deltas[idx] = int(_stage_deltas[idx]) - 1
	# kill-race feedback: pips track cumulative kills and pop the INSTANT a kill is credited (spec §4)
	_hud.animate_scores(scores.duplicate())
	# MATCH-END on the winning KILL (spec §2): the final kill IS the hero moment — freeze here,
	# do not wait for STAGE_END. Requires a strict single leader at >= target.
	var widx := _match_over_leader()
	if widx >= 0:
		_enter_match_end(widx)
		return
	# lives / elimination (spec §3)
	lives_left[idx] = int(lives_left[idx]) - 1
	var eliminated: bool = int(lives_left[idx]) <= 0
	if not eliminated:
		_respawn_after_death(idx)   # configurable multi-life path (non-default)
	else:
		_hud.set_dead(idx, true)
		# simultaneous-ELIMINATION grouping for the double-KO SD (spec §5)
		if _recent_dead.size() > 0 and (round_clock - _last_death_clock) <= Tuning.double_ko_window:
			_recent_dead.append(victim)
		else:
			_recent_dead = [victim]
		_last_death_clock = round_clock
	var ne := _not_eliminated_count()
	if ne == 2 and not _two_left_fired and _stage_start_alive >= 3:
		_two_left_fired = true
		_hud.show_top("TWO LEFT!", Color.WHITE, 1.0)
		EventBus.two_left.emit()   # audio: tension announcer
	if ne == 0:
		_end_check = -1.0
		_decide_stage_end(false)   # nobody left — decide immediately (double-KO SD or NOBODY SURVIVES)
	elif ne == 1:
		_end_check = Tuning.double_ko_window   # the survivor might still be mid-double-KO

## v2_kill_shape §6: classify which blast line the victim crossed at death, for the kill-SHAPE
## measurement (K1: edges >= 60% / pit <= 30%). Derived from the victim's last-frame position vs
## `bounds`. A bottom crossing INSIDE the walkable x-span is the central "pit"; a bottom crossing
## outside it is a true "bottom" blast. A death still inside bounds (e.g. a hazard) is "none".
func _classify_blast_edge(victim) -> String:
	if not is_instance_valid(victim):
		return "none"
	var pos: Vector2 = victim.global_position
	var out_left: float = bounds.position.x - pos.x
	var out_right: float = pos.x - bounds.end.x
	var out_top: float = bounds.position.y - pos.y
	var out_bottom: float = pos.y - bounds.end.y
	var m: float = maxf(maxf(out_left, out_right), maxf(out_top, out_bottom))
	if m <= 0.0:
		return "none"   # still inside bounds — not a ring-out (hazard / other cause)
	if m == out_bottom:
		# bottom crossing: the central pit if the victim is within the walkable x-span, else a true blast
		if pos.x >= _stage_rect.position.x and pos.x <= _stage_rect.end.x:
			# v2a §4b#2 cosmetic relabel: on a void-is-floor arena the void IS the whole floor, so a
			# bottom-inside-span fall is the intended off-screen kill, NOT a demoted mid-map hole. Report
			# it as "void" so raw stats never conflate it with central_pit's "pit". Label only — the kill
			# economy/credit is unchanged; central_pit stays byte-for-byte "pit".
			if _kill_shape == "void_is_floor":
				return "void"
			return "pit"
		return "bottom"
	if m == out_top:
		return "top"
	if m == out_left:
		return "left"
	return "right"

## The single leader at >= match_target_kills, or -1 if no one leads at target (spec §2 strict lead).
func _match_over_leader() -> int:
	var mx := -1
	var leaders := 0
	var widx := -1
	for i in range(scores.size()):
		var s := int(scores[i])
		if s > mx:
			mx = s
			leaders = 1
			widx = i
		elif s == mx:
			leaders += 1
	if mx >= Tuning.match_target_kills and leaders == 1:
		return widx
	return -1

## Configurable multi-life respawn (spec §3 — dormant at lives_per_player = 1). Respawns at a spawn
## point after respawn_delay with the existing _spawn_protect invuln and a fresh (healed) damage level.
func _respawn_after_death(i: int) -> void:
	var p = players[i]
	get_tree().create_timer(Tuning.respawn_delay).timeout.connect(func() -> void:
		if not is_instance_valid(p):
			return
		if state != "COMBAT" and state != "SUDDEN_DEATH":
			return
		if int(lives_left[i]) <= 0:
			return
		p.respawn(_spawn_at(i))
		_hud.set_dead(i, false))

## `deferred` = we already sat out the double-KO window since the last death; credit that wait
## against the freeze so the pillar-4 turnaround contract (death -> next BOUNCE <= 4.5s) holds.
func _decide_stage_end(deferred: bool) -> void:
	var ne := _not_eliminated_players()
	if ne.size() >= 2:
		return
	# double-KO: the tied (just-eliminated) players revive ONCE into sudden death (spec §5)
	if ne.size() == 0 and _recent_dead.size() >= 2 and not _revived_this_stage:
		_sudden_death_revive()
		return
	_stage_winner = players.find(ne[0]) if ne.size() == 1 else -1
	# NO survival point in a kill-race (spec §2/§3): the eliminating kill already scored; survival
	# is a celebration beat only. The banner still names the survivor.
	_enter_stage_end(deferred)

## Sudden death — the ONLY SD (spec §5): revive both tied players at the two spawn points nearest
## stage center, full fuel, pre-damaged Lv2 (fast pulse) so the first clean near-edge hit resolves
## the 1v1. No lasers, no timer — the damage system IS the clock. One revive max per stage.
func _sudden_death_revive() -> void:
	_revived_this_stage = true
	state = "SUDDEN_DEATH"
	if not _cur_stats.is_empty():
		_cur_stats["entered_sd"] = true
	var center_spawns := _spawns_by_center()
	var k := 0
	for v in _recent_dead:
		var i := players.find(v)
		if i < 0 or not is_instance_valid(v):
			continue
		var pos: Vector2 = center_spawns[k % center_spawns.size()] if center_spawns.size() > 0 else _spawn_at(i)
		k += 1
		v.respawn(pos)
		lives_left[i] = 1        # both are back in the fight for the 1v1
		v.seed_damage(2)         # pre-damaged Lv2: first clean near-edge hit sends the loser out (§5)
		v.frozen = true          # suspended while the banner holds — no 3-2-1, keep it panicky
		_hud.set_dead(i, false)
	_recent_dead.clear()
	_sd_lock = SD_REVIVE_LOCK
	_hud.show_center("SUDDEN DEATH!", DANGER, SD_REVIVE_LOCK)

## The two spawn points nearest stage center, for double-KO revives (spec §5).
func _spawns_by_center() -> Array:
	var out: Array = _spawns.duplicate()
	var c := _stage_rect.get_center()
	out.sort_custom(func(a, b): return a.distance_to(c) < b.distance_to(c))
	return out

# ------------------------------------------------------------------- stage end / match end

## KO freeze-frame: gameplay halts, banner + pips already animated in real time (spec §1).
func _enter_stage_end(deferred := false) -> void:
	state = "STAGE_END"
	# the double-KO wait already elapsed since the last death — it counts as freeze time
	_state_t = Tuning.double_ko_window if deferred else 0.0
	# finalize the round_stats record
	if not _cur_stats.is_empty():
		_cur_stats["length_s"] = round_clock
		_cur_stats["survivor_had_contact"] = _stage_winner >= 0 \
			and _stage_winner < _had_contact.size() and _had_contact[_stage_winner]
		round_stats.append(_cur_stats)
		_cur_stats = {}
	# powerup stage-end sweep (spec §2): all active effects, held slots, and field objects
	# (balls / rings / bubbles / telegraphs) are cleared — every stage starts clean
	if _pu_director != null:
		_pu_director.stop()
	PowerupSystem.round_sweep()
	for p in players:
		if is_instance_valid(p) and not p.is_dead():
			p.frozen = true
	var txt := "NOBODY SURVIVES"
	var col := Color.WHITE
	if _stage_winner >= 0:
		txt = "P%d SURVIVES!" % (_stage_winner + 1)
		col = PLAYER_COLORS[_stage_winner]
	_hud.show_center(txt, col, Tuning.round_end_freeze - 0.35, _deltas_line())
	_hud.animate_scores(scores.duplicate())

func _tick_stage_end(delta: float) -> void:
	_state_t += delta
	if _state_t < Tuning.round_end_freeze:
		return
	# Safety match-end check (spec §2): normally the match already ended on the winning kill; this
	# only catches a strict leader that appeared without a live match-end check (defensive).
	var widx := _match_over_leader()
	if widx >= 0:
		_enter_match_end(widx)
		return
	# a tie at >= target (double-KO crediting two to target in the window) does NOT end — play on
	var mx := -1
	for s in scores:
		mx = maxi(mx, int(s))
	if mx >= Tuning.match_target_kills:
		_tiebreaker_next = true
	# MATCH POINT: first time a player hits target-1 kills (spec §4)
	for i in range(scores.size()):
		if int(scores[i]) >= Tuning.match_target_kills - 1 and not _match_point_announced.has(i):
			_match_point_announced[i] = true
			_pending_match_point.append(i)
	_begin_stage()

func _enter_match_end(widx: int) -> void:
	state = "MATCH_END"
	_state_t = 0.0
	_match_winner = widx
	_prompt_shown = false
	# finalize any in-flight stage record so QA can read the winning stage
	if not _cur_stats.is_empty():
		_cur_stats["length_s"] = round_clock
		round_stats.append(_cur_stats)
		_cur_stats = {}
	var w = players[widx]
	if is_instance_valid(w):
		if w.is_dead():   # won on points while dead — bring them back for the bow
			w.respawn(_spawn_at(widx))
			w.frozen = true
			_hud.set_dead(widx, false)
		w.play_win_pop()
		_camera.set_frame(w.global_position, MATCH_END_ZOOM)   # punch-zoom (FEEL §7)
	EventBus.match_won.emit(widx)   # audio: win fanfare + scoreboard music
	_hud.show_match_end("P%d WINS THE MATCH!" % (widx + 1), PLAYER_COLORS[widx], _scoreline())

func _tick_match_end(delta: float) -> void:
	_state_t += delta
	if _state_t < PROMPT_GUARD:   # 1s input guard so nobody skips the screen by accident
		return
	if not _prompt_shown:
		_prompt_shown = true
		_hud.show_match_prompt("A / ENTER — REMATCH      B / ESC — QUIT")
	if Input.is_action_just_pressed(&"menu_accept"):
		_start_match()
	elif Input.is_action_just_pressed(&"menu_back"):
		get_tree().quit()

func _deltas_line() -> String:
	var parts: Array[String] = []
	for i in range(_stage_deltas.size()):
		var d: int = _stage_deltas[i]
		if d != 0:
			parts.append("P%d %+d" % [i + 1, d])
	return "  ·  ".join(parts)

func _scoreline() -> String:
	var parts: Array[String] = []
	for i in range(scores.size()):
		parts.append("P%d %d" % [i + 1, int(scores[i])])
	return "   ·   ".join(parts)

# ------------------------------------------------------------------- helpers

func _alive_players() -> Array:
	var out: Array = []
	for p in players:
		if is_instance_valid(p) and not p.is_dead():
			out.append(p)
	return out

func _alive_count() -> int:
	return _alive_players().size()

## Players still in the stage: lives remaining > 0 (currently alive OR waiting on a multi-life
## respawn). Eliminated = 0 lives. Stage-end/SD logic reads THIS, not dead-this-instant (spec §3).
func _not_eliminated_players() -> Array:
	var out: Array = []
	for i in range(players.size()):
		if int(lives_left[i]) > 0 and is_instance_valid(players[i]):
			out.append(players[i])
	return out

func _not_eliminated_count() -> int:
	return _not_eliminated_players().size()

func _clear_name_tags() -> void:
	for t in _name_tags:
		if is_instance_valid(t):
			t.queue_free()
	_name_tags.clear()

func _fade_name_tags() -> void:
	for t in _name_tags:
		if is_instance_valid(t):
			t.fade_out(NAME_TAG_FADE)
	_name_tags.clear()

## Small white/gold star pop at each intro pop-in (spec §1).
func _spawn_star_burst(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.45
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 420.0
	p.damping_min = 300.0
	p.damping_max = 500.0
	p.scale_amount_min = 2.4
	p.scale_amount_max = 4.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.98, 0.8, 1.0))
	grad.set_color(1, Color(1.0, 0.85, 0.3, 0.0))
	p.color_ramp = grad
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## Refresh a player's combat-active window (dealt/took a hit, fired a super). camera_2x_policy §2.
func _mark_combat_active(idx: int) -> void:
	if idx < 0:
		return
	while _combat_active_t.size() <= idx:
		_combat_active_t.append(0.0)
	_combat_active_t[idx] = COMBAT_ACTIVE_WINDOW

## Camera 2x policy (docs/briefs/camera_2x_policy.md): frame the ACTION CLUSTER (combat-active
## centroid, fallback all-living), NOT the global stage spread. Readability-floored zoom (0.60),
## with a transient launch-cam exception (0.42) and a tighten-toward-the-caster super-aim bias.
func _update_camera() -> void:
	if _camera == null:
		return
	var dt := get_physics_process_delta_time()
	while _combat_active_t.size() < players.size():
		_combat_active_t.append(0.0)

	# living fighters this tick (is_dead()==false covers hitstun/recovery)
	var living: Array = []
	for i in range(players.size()):
		var p = players[i]
		if is_instance_valid(p) and not p.is_dead():
			living.append(p)
			# a player charging/aiming a super counts as combat-active continuously
			if p.is_super_aiming():
				_combat_active_t[i] = COMBAT_ACTIVE_WINDOW
		if _combat_active_t[i] > 0.0:
			_combat_active_t[i] = maxf(0.0, _combat_active_t[i] - dt)
	if living.is_empty():
		return   # nothing to frame — hold the last frame

	# super-aim caster (protects the aim-fuse ring via a framing bias, not a global floor)
	var aimer = null
	for p in living:
		if p.is_super_aiming():
			aimer = p
			break

	# launch-cam floor: engaged while a living player is in high knockback heading OUTWARD toward
	# a blast line; eases back to CAM_MIN_ZOOM over LAUNCH_EASE_BACK.
	var launching := false
	var bcenter := bounds.get_center()
	for p in living:
		var v: Vector2 = p.velocity
		if v.length() > LAUNCH_SPEED_FOR_CAM and v.dot(p.global_position - bcenter) > 0.0:
			launching = true
			break
	if launching:
		_launch_ease_t = LAUNCH_EASE_BACK
	elif _launch_ease_t > 0.0:
		_launch_ease_t = maxf(0.0, _launch_ease_t - dt)

	# --- choose the framing cluster ---
	var cluster: Array
	if aimer != null:
		# super bias: frame caster + nearest living opponent tightly (§4)
		cluster = [aimer]
		var opp = nearest_opponent(aimer)
		if is_instance_valid(opp) and not opp.is_dead():
			cluster.append(opp)
	else:
		# combat-active cluster (dealt/took a hit or aiming in the last COMBAT_ACTIVE_WINDOW s);
		# fallback to all living when the fight is momentarily quiet (§2).
		cluster = []
		for p in living:
			var idx := players.find(p)
			if idx >= 0 and _combat_active_t[idx] > 0.0:
				cluster.append(p)
		if cluster.is_empty():
			cluster = living

	# weighted centroid (heavy weight on the super caster so the aim reads)
	var centroid := Vector2.ZERO
	var wsum := 0.0
	for p in cluster:
		var w := SUPER_BIAS_WEIGHT if (aimer != null and p == aimer) else 1.0
		centroid += p.global_position * w
		wsum += w
	centroid /= maxf(wsum, 0.001)

	# half-extent needed to fit the cluster (+ capped velocity lead) symmetrically about the centroid
	var ext := Vector2.ZERO
	for p in cluster:
		ext = ext.max((p.global_position - centroid).abs())
		var lead: Vector2 = p.velocity.limit_length(CAM_LEAD_CAP) * CAM_LEAD_TIME
		var lp: Vector2 = p.global_position + lead
		lp.x = clampf(lp.x, bounds.position.x, bounds.end.x)   # frame the wall, not the void beyond
		lp.y = clampf(lp.y, bounds.position.y, bounds.end.y)
		ext = ext.max((lp - centroid).abs())
	ext += CAM_MARGIN

	# zoom to fit, then clamp to the effective floor .. max
	var z := minf(1920.0 / maxf(2.0 * ext.x, 1.0), 1080.0 / maxf(2.0 * ext.y, 1.0))
	var lo := CAM_MIN_ZOOM
	if _launch_ease_t > 0.0:
		# ease from the launch floor (0.42) back up to the normal floor (0.60)
		var f := _launch_ease_t / LAUNCH_EASE_BACK
		lo = lerpf(CAM_MIN_ZOOM, CAM_LAUNCH_MIN_ZOOM, f)
	elif aimer != null:
		lo = maxf(lo, SUPER_BIAS_MIN_ZOOM)   # aim-fuse legibility (launch-cam takes precedence if active)
	z = clampf(z, lo, CAM_MAX_ZOOM)

	# clamp the frame center so the visible rect stays inside bounds (never reveal the void)
	var half := Vector2(1920.0, 1080.0) / (2.0 * z)
	var cx: float = centroid.x
	var cy: float = centroid.y
	if bounds.size.x > 2.0 * half.x:
		cx = clampf(cx, bounds.position.x + half.x, bounds.end.x - half.x)
	else:
		cx = bcenter.x
	if bounds.size.y > 2.0 * half.y:
		cy = clampf(cy, bounds.position.y + half.y, bounds.end.y - half.y)
	else:
		cy = bcenter.y
	_camera.set_frame(Vector2(cx, cy), z)

func stage_center() -> Vector2:
	return _stage_rect.get_center()

func stage_rect() -> Rect2:
	return _stage_rect

## Idle-hunt (lethality §3.2 rule 3): past idle_hunt_after seconds without boost/super input,
## the NEAREST living bot overrides its targeting to the idler until they press something.
## Returns the idler `bot` should hunt, or null. Passive bouncing is camping (Pillar 2).
func idle_hunt_target(bot):
	if state != "COMBAT" and state != "SUDDEN_DEATH":
		return null
	var best = null
	var best_d := INF
	for p in players:
		if p == bot or not is_instance_valid(p) or p.is_dead():
			continue
		if p.secs_since_input < Tuning.idle_hunt_after:
			continue
		# is `bot` the nearest living bot to this idler?
		var nearest_bot = null
		var nb_d := INF
		for q in players:
			if q == p or not is_instance_valid(q) or q.is_dead() or q.is_in_group("human"):
				continue
			var dq: float = q.global_position.distance_to(p.global_position)
			if dq < nb_d:
				nb_d = dq
				nearest_bot = q
		if nearest_bot == bot and nb_d < best_d:
			best_d = nb_d
			best = p
	return best

func nearest_opponent(me) -> Player:
	var best: Player = null
	var best_d := INF
	for p in players:
		if p == me or not is_instance_valid(p) or p.is_dead():
			continue
		var d: float = me.global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best

func _spawn_at(i: int) -> Vector2:
	if _spawns.size() > 0:
		var base: Vector2 = _spawns[i % _spawns.size()]
		var ring := i / _spawns.size()
		return base + Vector2(0.0, -60.0 * float(ring))
	return Vector2(960.0, 300.0)
