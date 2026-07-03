class_name PartyMatch
extends Node2D
## The real Party match (docs/specs/v0_round_loop.md). Boots straight into 1 human (P1, pink) +
## 3 bots (levels 2/3/4 — punchline / fair fight / menace) on one arena, first to 10.
##
## Round drumbeat: staggered pop-in intro w/ name tags -> "3-2-1-BOUNCE!" -> one-life combat ->
## sudden death (20s anti-stall lasers, or double-KO revive-once tiebreak) -> 1.8s KO freeze +
## banner + pip animation -> next round, or MATCH_END (>=10 with a strict lead) w/ rematch|quit.
## Scoring: +1 kill (2.5s last-attacker credit, beyond-the-grave counts) · +1 sole survivor ·
## -1 suicide floored at 0. NO mid-round respawn (the old DevArena dev-glue is gone).
##
## QA contract (round-loop spec §5 + lethality spec §8, read via gbplay eval): state /
## round_index / round_clock / scores / last_death_msec / combat_start_msec / round_stats
## (per-round {length_s, end_cause, entered_sd, kills[], survivor_had_contact, supers_fired[]}).
## Arena contract (InputBot/Playtest): players / scores / bounds / nearest_opponent() /
## stage_rect() / stage_center() / idle_hunt_target().

const LEVEL_PATH := "res://levels/dev_arena.json"
const NUM_BOTS := 3
# Character skins: P1 is always pink; bots take blue/green/yellow in order.
const BOT_SKINS: Array[String] = ["blue", "green", "yellow"]
const PLAYER_COLORS: Array[Color] = [
	Color("#ff5fa8"), Color("#4aa8ff"), Color("#54c94a"), Color("#ffc93f")]
const HUD_SCENE := preload("res://scenes/ui/MatchHUD.tscn")
const NAME_TAG_SCENE := preload("res://scenes/ui/NameTag.tscn")
const SD_WARNING_SCENE := preload("res://scenes/ui/SDWarning.tscn")
const LASER_WALLS := preload("res://src/entities/LaserWalls.gd")

const CAM_MIN_ZOOM := 0.36     # most zoomed-out. Kill-zone spec §6.3: the new 4100x2980 bounds need
                               # ~0.36 to show the full vertical extent (0.42 could not); verified blobs
                               # stay readable at this scale in the rendered smoke test.
const CAM_LEAD_TIME := 0.32    # kill-zone spec §6.4: frame ahead of each flier's velocity so a fast
                               # (capped 2200) launch + its approaching blast line stay on-screen.
const CAM_MAX_ZOOM := 0.92     # never zoom in tighter than this
const MATCH_END_ZOOM := 1.1    # winner punch-zoom (FEEL §7)
const BOUNCE_HOLD := 0.4       # "BOUNCE!" banner hold (spec §1)
const NAME_TAG_LINGER := 1.0   # name tags fade this long into COMBAT
const NAME_TAG_FADE := 0.4
const SD_REVIVE_LOCK := 0.8    # "SUDDEN DEATH!" revive banner hold, inputs locked (spec §1)
const PROMPT_GUARD := 1.0      # MATCH_END input guard before REMATCH/QUIT arms (spec §1)
const GOLD := Color("#ffd23f")
const DANGER := Color("#ff4b3a")

# --- QA contract (spec §5 + lethality §8) ---
var state := "BOOT"
var round_index := 0
var round_clock := 0.0           # hidden combat clock (drives sudden death; never rendered)
var scores: Array = []
var last_death_msec := 0         # ticks_msec of the most recent death (turnaround measurement)
var combat_start_msec := 0       # ticks_msec of the last "BOUNCE!" physics unlock
var round_stats: Array = []      # per-round QA record (lethality §8 + kill-zone §8): {length_s, end_cause,
                                 # entered_sd, kills[{killer,victim,off_stage,t}], survivor_had_contact,
                                 # supers_fired[{who,fuel_at_fire,aim_time,auto_fired,t}],
                                 # smashes[{t,attacker,victim,solidity,launch_scale,launch_speed,angle_deg,
                                 #          by_super,victim_fuel_after,starved,spin}]}
var _cur_stats: Dictionary = {}  # the round currently being recorded

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
var _lasers
var _sd_warning                  # SDWarning CanvasLayer (edge pulse + wall trackers, lethality §6)
var _had_contact: Array = []     # per-player: dealt/received >=1 smash this round (lethality §4)
var _smash_off_stage: Array = [] # per-player: was the LAST smash they received taken off-stage?

# round/match bookkeeping
var _state_t := 0.0
var _popped := 0
var _cd_beat := -1
var _sd_lock := 0.0              # sudden-death revive input lock countdown
var _end_check := -1.0           # pending round-decision timer (double-KO window)
var _recent_dead: Array = []     # simultaneous-death group (double-KO tiebreak, spec §2)
var _last_death_clock := 0.0
var _revived_this_round := false # one sudden-death revive max per round (no recursion)
var _round_deltas: Array = []    # applied score deltas this round (for the ROUND_END sub-line)
var _round_start_alive := 0
var _round_winner := -1
var _two_left_fired := false
var _first_blood_fired := false  # once per MATCH (spec §3)
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
	_load_stage(LEVEL_PATH)

	_camera = CameraController.new()
	_camera.position = _stage_rect.get_center()
	_camera.dynamic = true   # Smash-style: follow the action, zoom to keep everyone on screen
	_camera.follow_speed = 8.0   # kill-zone spec §6.4: was 6.0 — tighter follow so a fresh launch doesn't outrun the frame
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

	_start_match()

func _spawn_player(i: int, human: bool) -> void:
	var p := Player.new()
	p.skin = "pink" if human else BOT_SKINS[(i - 1) % BOT_SKINS.size()]
	add_child(p)
	p.global_position = _spawn_at(i)
	players.append(p)
	scores.append(0)
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

func _load_stage(path: String) -> void:
	for c in _level_root.get_children():
		c.queue_free()
	var data := LevelLoader.load_level(path, _level_root)
	_spawns = data.get("spawns", [])
	_pu_points = data.get("powerup_spawners", [])
	bounds = data.get("bounds", Rect2(-120, -120, 2160, 1380))
	_stage_rect = data.get("play_rect", Rect2(bounds.get_center() - Vector2(900, 160), Vector2(1800, 320)))

# ------------------------------------------------------------------- state machine

func _physics_process(delta: float) -> void:
	# UI/flow beats run on REAL time: hitstop scales `delta`, and the pillar-4 turnaround
	# contract (last death -> next BOUNCE <= 4.5s) is measured on the wall clock.
	var rdelta := delta / maxf(Engine.time_scale, 0.05)
	match state:
		"ROUND_INTRO":
			_tick_intro(rdelta)
		"COUNTDOWN":
			_tick_countdown(rdelta)
		"COMBAT", "SUDDEN_DEATH":
			_tick_combat(delta, rdelta)
		"ROUND_END":
			_tick_round_end(rdelta)
		"MATCH_END":
			_tick_match_end(rdelta)
	if state != "MATCH_END":
		_update_camera()

## BOOT/rematch entry: zero everything match-scoped, then straight into ROUND_INTRO (spec §1).
func _start_match() -> void:
	state = "MATCH_START"
	for i in range(scores.size()):
		scores[i] = 0
	round_index = 0
	round_stats.clear()
	_cur_stats = {}
	_first_blood_fired = false
	_match_point_announced.clear()
	_pending_match_point.clear()
	_tiebreaker_next = false
	_match_winner = -1
	_hud.reset_scores()
	_begin_round()

## ROUND_INTRO: everyone suspended + invisible at spawns, popped in one at a time (spec §1).
func _begin_round() -> void:
	round_index += 1
	round_clock = 0.0
	_state_t = 0.0
	_popped = 0
	_cd_beat = -1
	_sd_lock = 0.0
	_end_check = -1.0
	_recent_dead.clear()
	_revived_this_round = false
	_two_left_fired = false
	_round_winner = -1
	_round_deltas.clear()
	_had_contact.clear()      # survival-gate contact flags reset at ROUND_INTRO (lethality §4)
	_smash_off_stage.clear()
	_clear_lasers()
	_clear_sd_warning()
	_hud.hide_center()
	_clear_name_tags()
	for i in range(players.size()):
		var p = players[i]
		_round_deltas.append(0)
		_had_contact.append(false)
		_smash_off_stage.append(false)
		p.respawn(_spawn_at(i))
		p.frozen = true
		p.visible = false
		_hud.set_dead(i, false)
	_round_start_alive = players.size()
	state = "ROUND_INTRO"
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
	if _pending_match_point.size() > 0:   # announced at the next round's countdown (spec §3)
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
	if _state_t >= Tuning.countdown_beat * 3.0:
		_bounce_go()

## "BOUNCE!": physics + input enable for everyone on the same frame — the starting gun (spec §1).
func _bounce_go() -> void:
	state = "COMBAT"
	round_clock = 0.0
	combat_start_msec = Time.get_ticks_msec()
	_cur_stats = {
		"length_s": 0.0, "end_cause": "none", "entered_sd": false,
		"kills": [], "survivor_had_contact": false, "supers_fired": [],
		"smashes": [],   # kill-zone spec §8: hit-solidity distribution + recovery correlation feed
	}
	for p in players:
		p.frozen = false
		p.fuel = Tuning.fuel_max   # every round starts on a full tank
	if _pu_director != null:
		_pu_director.reset()       # first telegraph pu_first_spawn after BOUNCE! (spec §4)
	_hud.show_center("BOUNCE!", GOLD, BOUNCE_HOLD)
	get_tree().create_timer(NAME_TAG_LINGER).timeout.connect(_fade_name_tags)

func _tick_combat(delta: float, rdelta: float) -> void:
	round_clock += delta
	# sudden-death revive lock: banner holds, everyone suspended, lasers paused (spec §1)
	if _sd_lock > 0.0:
		_sd_lock -= rdelta
		if _sd_lock <= 0.0:
			for p in _alive_players():
				p.frozen = false
			if _lasers != null:
				_lasers.paused = false
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
	# SD warning flicker (lethality §6): pulsing edge columns from sd_warning_lead before SD
	if state == "COMBAT" and _alive_count() >= 2 \
			and round_clock >= Tuning.sudden_death_time - Tuning.sd_warning_lead:
		_show_sd_warning()
	# anti-stall: lasers activate in place, mid-combat — no freeze, no revive (spec §1)
	if state == "COMBAT" and round_clock >= Tuning.sudden_death_time and _alive_count() >= 2:
		_enter_sudden_death_timer()
	if _lasers != null:
		_lasers.tick(delta, players)
	# deferred round decision: wait double_ko_window after a death that left <=1 alive
	if _end_check >= 0.0:
		_end_check -= rdelta
		if _end_check <= 0.0:
			_end_check = -1.0
			_decide_round_end(true)

# ------------------------------------------------------------------- deaths & scoring

## Contact bookkeeping (lethality §4 + §8): a `smashed` event flags BOTH sides for the survival
## gate (shoves never emit it), and records whether the victim took the hit off-stage (test 15).
func _on_smashed(attacker, victim, _impulse) -> void:
	if state != "COMBAT" and state != "SUDDEN_DEATH":
		return
	var ai := players.find(attacker)
	var vi := players.find(victim)
	if ai >= 0 and ai < _had_contact.size():
		_had_contact[ai] = true
	if vi >= 0 and vi < _had_contact.size():
		_had_contact[vi] = true
		if is_instance_valid(victim):
			_smash_off_stage[vi] = not _stage_rect.grow(120.0).has_point(victim.global_position)

func _on_super_fired(player, fuel_at_fire, aim_time, auto_fired) -> void:
	if _cur_stats.is_empty() or (state != "COMBAT" and state != "SUDDEN_DEATH"):
		return
	var who := players.find(player)
	var fired: Array = _cur_stats["supers_fired"]
	fired.append({
		"who": who, "fuel_at_fire": fuel_at_fire, "aim_time": aim_time, "auto_fired": auto_fired,
		"t": round_clock,   # kill-zone spec §8: enables recovery-super correlation
	})

## Hit-solidity QA feed (kill-zone spec §8): one entry per qualifying smash, carrying the solidity
## distribution + starve/survival correlation inputs. Read-only QA data; no gameplay effect.
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
	})

func _on_killed(victim, cause, attacker) -> void:
	var idx := players.find(victim)
	if idx < 0:
		return
	last_death_msec = Time.get_ticks_msec()
	if state != "COMBAT" and state != "SUDDEN_DEATH":
		return
	# round_stats kill record (lethality §8): off_stage = the killing smash connected while the
	# victim was off-stage (last received smash position, tracked in _on_smashed)
	if not _cur_stats.is_empty():
		var ki: int = players.find(attacker) if attacker != null else -1
		var kills: Array = _cur_stats["kills"]
		kills.append({
			"killer": ki, "victim": idx,
			"off_stage": _smash_off_stage[idx] if idx < _smash_off_stage.size() else false,
			"t": round_clock,   # kill-zone spec §8: enables smash→kill time correlation
		})
		_cur_stats["end_cause"] = str(cause)   # the round-deciding death overwrites last
	# simultaneous-death grouping for the double-KO tiebreak (spec §2)
	if _recent_dead.size() > 0 and (round_clock - _last_death_clock) <= Tuning.double_ko_window:
		_recent_dead.append(victim)
	else:
		_recent_dead = [victim]
	_last_death_clock = round_clock
	# kill credit vs suicide (spec §2). Every cause counts; dead attackers still score
	# ("beyond the grave"); being killed is never -1.
	var ai: int = players.find(attacker) if attacker != null else -1
	if ai >= 0 and ai != idx:
		scores[ai] = int(scores[ai]) + 1
		_round_deltas[ai] = int(_round_deltas[ai]) + 1
		if not _first_blood_fired:
			_first_blood_fired = true
			_hud.show_top("FIRST BLOOD!", PLAYER_COLORS[ai], 1.0)
	elif int(scores[idx]) > 0:   # suicide: -1, floored at 0 (v0 decision)
		scores[idx] = int(scores[idx]) - 1
		_round_deltas[idx] = int(_round_deltas[idx]) - 1
	_hud.set_dead(idx, true)
	var alive := _alive_count()
	if alive == 2 and not _two_left_fired and _round_start_alive >= 3:
		_two_left_fired = true
		_hud.show_top("TWO LEFT!", Color.WHITE, 1.0)
	if alive == 0:
		_end_check = -1.0
		_decide_round_end(false)   # nobody left to die — decide immediately
	elif alive == 1:
		_end_check = Tuning.double_ko_window   # the survivor might still be mid-double-KO

## `deferred` = we already sat out the double-KO window after the last death; credit that wait
## against the freeze so the pillar-4 turnaround contract (death -> next BOUNCE <= 4.5s) holds.
func _decide_round_end(deferred: bool) -> void:
	var alive := _alive_players()
	if alive.size() >= 2:
		return
	# double-KO: the tied players (only them) revive ONCE into sudden death (spec §1/§2)
	if alive.size() == 0 and _recent_dead.size() >= 2 and not _revived_this_round:
		_sudden_death_revive()
		return
	_round_winner = players.find(alive[0]) if alive.size() == 1 else -1
	# survival point: sole survivor only (spec §2), gated on having dealt/received >=1 smash
	# this round (lethality §4) — surviving under fire scores, hiding untouched doesn't.
	# The banner still names the winner either way (deltas show +0 honestly).
	if _round_winner >= 0 and (not Tuning.survival_requires_contact or _had_contact[_round_winner]):
		scores[_round_winner] = int(scores[_round_winner]) + 1
		_round_deltas[_round_winner] = int(_round_deltas[_round_winner]) + 1
	_enter_round_end(deferred)

func _sudden_death_revive() -> void:
	_revived_this_round = true
	state = "SUDDEN_DEATH"
	if not _cur_stats.is_empty():
		_cur_stats["entered_sd"] = true
	# revive at the spawn points nearest stage center (lethality §5 — never behind a closing wall)
	var center_spawns := _spawns_by_center()
	var k := 0
	for v in _recent_dead:
		var i := players.find(v)
		if i < 0 or not is_instance_valid(v):
			continue
		var pos: Vector2 = center_spawns[k % center_spawns.size()] if center_spawns.size() > 0 else _spawn_at(i)
		k += 1
		v.respawn(pos)
		v.frozen = true   # suspended while the banner holds — no 3-2-1, keep it panicky
		_hud.set_dead(i, false)
	_recent_dead.clear()
	_activate_lasers()
	# revive pacing (lethality §5): walls spawn already laser_revive_start_frac closed —
	# instantly on-camera, decided in <=3.6s of closing. Keeps further-closed walls as-is.
	_lasers.ensure_closed_frac(Tuning.laser_revive_start_frac)
	_lasers.paused = true
	_sd_lock = SD_REVIVE_LOCK
	_hud.show_center("SUDDEN DEATH!", DANGER, SD_REVIVE_LOCK)

func _enter_sudden_death_timer() -> void:
	state = "SUDDEN_DEATH"
	if not _cur_stats.is_empty():
		_cur_stats["entered_sd"] = true
	_hud.show_top("SUDDEN DEATH!", DANGER, 1.0)
	_activate_lasers()

func _activate_lasers() -> void:
	if _lasers != null:
		return
	_lasers = LASER_WALLS.new()
	add_child(_lasers)
	_lasers.setup(bounds, _stage_rect.get_center().x, Tuning.laser_close_time)
	# warning columns become wall trackers at SD start (lethality §6); on the revive path this
	# is their first appearance (no lead pulse — the walls spawn ~on-screen)
	_show_sd_warning()
	_sd_warning.start_tracking(_lasers)
	# powerup sudden-death cutoff (spec §2/§4): spawner off, live bubbles pop, rings cleared;
	# active effects and in-flight balls keep running (a Star finale is hilarious)
	if _pu_director != null:
		_pu_director.on_sudden_death()
	PowerupSystem.clear_rings()

## The two spawn points nearest stage center, for double-KO revives (lethality §5).
func _spawns_by_center() -> Array:
	var out: Array = _spawns.duplicate()
	var c := _stage_rect.get_center()
	out.sort_custom(func(a, b): return a.distance_to(c) < b.distance_to(c))
	return out

func _show_sd_warning() -> void:
	if _sd_warning != null:
		return
	_sd_warning = SD_WARNING_SCENE.instantiate()
	add_child(_sd_warning)
	_sd_warning.start_warning()

func _clear_sd_warning() -> void:
	if _sd_warning != null:
		if is_instance_valid(_sd_warning):
			_sd_warning.queue_free()
		_sd_warning = null

# ------------------------------------------------------------------- round end / match end

## KO freeze-frame: gameplay halts, banner + pips animate in real time (spec §1).
func _enter_round_end(deferred := false) -> void:
	state = "ROUND_END"
	# the double-KO wait already elapsed since the last death — it counts as freeze time
	_state_t = Tuning.double_ko_window if deferred else 0.0
	# finalize the round_stats record (lethality §8)
	if not _cur_stats.is_empty():
		_cur_stats["length_s"] = round_clock
		_cur_stats["survivor_had_contact"] = _round_winner >= 0 \
			and _round_winner < _had_contact.size() and _had_contact[_round_winner]
		round_stats.append(_cur_stats)
		_cur_stats = {}
	# SD cleanup (lethality §7): FREE (not halt) all sudden-death nodes — walls, glow,
	# warning columns. MATCH_END must screenshot with zero laser pixels.
	_clear_lasers()
	_clear_sd_warning()
	# powerup round-end sweep (spec §2): all active effects, held slots, and field objects
	# (balls / rings / bubbles / telegraphs) are cleared — every round starts clean
	if _pu_director != null:
		_pu_director.stop()
	PowerupSystem.round_sweep()
	for p in players:
		if is_instance_valid(p) and not p.is_dead():
			p.frozen = true
	var txt := "NOBODY WINS"
	var col := Color.WHITE
	if _round_winner >= 0:
		txt = "P%d WINS THE ROUND" % (_round_winner + 1)
		col = PLAYER_COLORS[_round_winner]
	_hud.show_center(txt, col, Tuning.round_end_freeze - 0.35, _deltas_line())
	_hud.animate_scores(scores.duplicate())

func _tick_round_end(delta: float) -> void:
	_state_t += delta
	if _state_t < Tuning.round_end_freeze:
		return
	# match end iff someone is at target AND strictly leads; a tie at >=10 plays another
	# full round ("TIEBREAKER!") and re-checks — points past 10 count (spec §2)
	var mx := -1
	var leaders := 0
	for s in scores:
		if int(s) > mx:
			mx = int(s)
			leaders = 1
		elif int(s) == mx:
			leaders += 1
	if mx >= Tuning.match_target_score:
		if leaders == 1:
			_enter_match_end(scores.find(mx))
			return
		_tiebreaker_next = true
	for i in range(scores.size()):   # MATCH POINT: first time a player hits target-1 (spec §3)
		if int(scores[i]) >= Tuning.match_target_score - 1 and not _match_point_announced.has(i):
			_match_point_announced[i] = true
			_pending_match_point.append(i)
	_begin_round()

func _enter_match_end(widx: int) -> void:
	state = "MATCH_END"
	_state_t = 0.0
	_match_winner = widx
	_prompt_shown = false
	var w = players[widx]
	if is_instance_valid(w):
		if w.is_dead():   # won on points while dead — bring them back for the bow
			w.respawn(_spawn_at(widx))
			w.frozen = true
			_hud.set_dead(widx, false)
		w.play_win_pop()
		_camera.set_frame(w.global_position, MATCH_END_ZOOM)   # punch-zoom (FEEL §7)
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
	for i in range(_round_deltas.size()):
		var d: int = _round_deltas[i]
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

func _clear_lasers() -> void:
	if _lasers != null:
		if is_instance_valid(_lasers):
			_lasers.queue_free()
		_lasers = null

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

## Frame the stage + all living fighters, zooming out as they spread (Smash-style).
func _update_camera() -> void:
	if _camera == null:
		return
	var mn := _stage_rect.position
	var mx := _stage_rect.end
	# Kill-zone spec §6: frame every knocked-but-ALIVE flier (is_dead()==false covers hitstun/recovery),
	# and lead their velocity so a launched blob AND the blast line it heads toward both stay on-screen.
	for p in players:
		if is_instance_valid(p) and not p.is_dead():
			mn = mn.min(p.global_position)
			mx = mx.max(p.global_position)
			var lead: Vector2 = p.global_position + p.velocity * CAM_LEAD_TIME
			# clamp the lead to the blast bounds so we frame the wall it approaches, not empty void beyond
			lead.x = clampf(lead.x, bounds.position.x, bounds.end.x)
			lead.y = clampf(lead.y, bounds.position.y, bounds.end.y)
			mn = mn.min(lead)
			mx = mx.max(lead)
	var margin := Vector2(420.0, 340.0)
	mn -= margin
	mx += margin
	var size := mx - mn
	var z := minf(1920.0 / maxf(size.x, 1.0), 1080.0 / maxf(size.y, 1.0))
	z = clampf(z, CAM_MIN_ZOOM, CAM_MAX_ZOOM)
	_camera.set_frame((mn + mx) * 0.5, z)

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
