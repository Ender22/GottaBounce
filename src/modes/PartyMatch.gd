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
## supers_fired[], smashes[], motion_health[]}). Live motion-health via bot_motion_health() (per-bot
## {stuck_episodes, stuck_secs, underside_bounces, blocked_ascent_episodes, blocked_ascent_secs,
## blocked_ascent, player}). Arena contract (InputBot/Playtest): players / scores / bounds /
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
	"res://levels/drop_chamber.json",
	"res://levels/the_spine.json",
	"res://levels/twin_chasms.json",
	"res://levels/the_cliff.json",
	"res://levels/atoll.json",
	"res://levels/spires.json",
	"res://levels/bumper_gauntlet.json",
	"res://levels/the_ascent.json",
	"res://levels/wrecking_yard.json",
]
# Player color palette, indexed by player (presentation only; skin IDENTITY comes from the config's
# skin_ids — v1_frontend_shell §2.2). P1 pink / bots blue/green/yellow reproduce today; 4 extra hues
# extend the palette to the 8-player invariant ceiling so a larger config never indexes out of range.
const PLAYER_COLORS: Array[Color] = [
	Color("#ff5fa8"), Color("#4aa8ff"), Color("#54c94a"), Color("#ffc93f"),
	Color("#b06bff"), Color("#ff8a3f"), Color("#3fd8d0"), Color("#f0f0f0")]
const NAME_TAG_SCENE := preload("res://scenes/ui/NameTag.tscn")
# GameMode registry (v1_frontend_shell §3.2): mode_id -> mode script. PartyMatch is a regular (non-
# autoload) script, so preloading the class_name mode scripts here is safe.
const MODE_REGISTRY := {
	&"brawl": preload("res://src/modes/BrawlMode.gd"),
	&"trials": preload("res://src/modes/TrialsMode.gd"),
	&"gauntlet": preload("res://src/modes/GauntletMode.gd"),
	&"sports": preload("res://src/modes/SportsMode.gd"),
}
# Front-end shell hooks (v1_frontend_shell §5): pause overlay + return-to-menu on quit.
const PAUSE_SCENE := preload("res://scenes/ui/PauseMenu.tscn")
const SHELL_SCENE := "res://scenes/ui/ShellRoot.tscn"
var _pause_overlay: CanvasLayer = null

# --- Camera 2x policy (docs/briefs/camera_2x_policy.md) ---
# Action-cluster framing + readability-floored zoom on the wide grassy_expanse. The old fit-to-global-
# spread over-zoomed to ~0.42 (bouncers ~30px) during 4-player combat, killing Pillar-5 readability.
const CAM_MIN_ZOOM := 0.60     # normal-combat readability floor (was 0.37). Body >= ~63px @1080p:
                               # color ID, face, and crimson damage-pulse rim all read. A fast
                               # flier's POSITION widens the smoothed AABB frame (no regime toggle).
const CAM_LEAD_TIME := 0.32    # velocity leads the PAN (not the zoom): nudge the frame CENTER ahead
                               # of the cluster's motion so a fast launch stays on-screen.
const CAM_LEAD_CAP := 700.0    # px: cap each player's velocity-lead contribution so the pan-ahead is
                               # a nudge, not a lurch.
const CAM_MAX_ZOOM := 0.92     # never zoom in tighter than this
const SUPER_BIAS_MIN_ZOOM := 0.70  # zoom-target floor while a super is charging (aim-fuse legibility)
const SUPER_BIAS_WEIGHT := 2.5     # centroid weight on the charging caster (frame the aim)
const CAM_OFFSCREEN_INSET := 40.0  # px: a living player outside visible rect+inset gets an edge chevron
const COMBAT_ACTIVE_WINDOW := 1.2  # s since dealing/taking a hit or firing/charging a super to count
                               # for the action-cluster centroid bias
# --- CD #5 camera follow-targeting refinement (owner-flagged; concept unchanged, targeting only) ---
const P1_CAM_WEIGHT := 0.85    # the LOCAL HUMAN (players[0]) is ALWAYS kept in the framing cluster so
                               # the human never gets dropped fully off-screen behind a chevron. Modest
                               # weight (< SUPER_BIAS_WEIGHT) so it guarantees inclusion without
                               # overriding the super-aim bias when P1 isn't the aimer.
const CAM_CLUSTER_LINGER := 0.9  # s a player LINGERS in the framing cluster after it drops out (e.g.
                               # players split into pairs) — cluster hysteresis so the centroid/extent
                               # target eases through the membership change instead of snapping.
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

# --- mode + config seam (v1_frontend_shell §2/§3) ---
var _config: MatchConfig         # this match's config (from GameConfig; defaults reproduce today)
var _mode                        # the active GameMode instance (the rules seam)
var match_target_kills: int = 10 # match-scoped kill target (set from config; default = Tuning value)
var lives_per_player: int = 1    # match-scoped lives (set from config; default = Tuning value)

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
var _cluster_linger_t: Array = []# per-player: seconds left lingering in the framing cluster (hysteresis)
var _edge_indicators             # EdgeIndicators overlay (off-screen player chevrons)

# level rotation (shuffle-bag) lives in the mode now (BrawlMode)

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
	# resolve the config + mode FIRST (v1_frontend_shell §2/§3): a fresh/default GameConfig reproduces
	# today's boot exactly. configure() sets the match target/lives and builds the level sequence.
	_config = GameConfig.match_config
	if _config == null:
		GameConfig.reset_to_defaults()
		_config = GameConfig.match_config
	var mode_script = MODE_REGISTRY.get(_config.mode_id, MODE_REGISTRY[&"brawl"])
	_mode = mode_script.new()
	_mode.configure(self, _config)

	bounds = Rect2(-120, -120, 2160, 1380)
	_level_root = Node2D.new()
	add_child(_level_root)
	_load_stage(LEVEL_POOL[0])   # a level exists before the camera/HUD reference _stage_rect

	_camera = CameraController.new()
	_camera.position = _stage_rect.get_center()
	_camera.dynamic = true   # Smash-style: follow the action, zoom to keep everyone on screen
	_camera.follow_speed = 8.0   # kill-zone spec §6.4: tighter PAN follow so a fresh launch doesn't outrun the frame
	_camera.zoom_out_speed = 9.0   # widen the view fast (never clip a flier)
	_camera.zoom_in_speed = 3.0    # tighten the view slow (no snap-in-then-back "pump")
	_camera.zoom_deadzone = 0.012  # ignore sub-threshold zoom-target wiggle
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

	# spawn per the mode's plan (BRAWL default: 1 pink human + 3 bots, mixed 2/3/4 from Tuning.bot_levels)
	var plan: Array = _mode.spawn_plan(self, _config)
	for i in range(plan.size()):
		_spawn_player(i, plan[i])

	# corner HUD cards visible immediately (spec §1 BOOT); HUD variant comes from the mode
	_hud = _mode.hud_scene().instantiate()
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

## Spawn one player from a mode spawn-plan descriptor (v1_frontend_shell §3.2):
## {human:bool, skin:String, character:String, bot_level:int, seed_damage:int, team:int}.
func _spawn_player(i: int, desc: Dictionary) -> void:
	var p := Player.new()
	p.skin = str(desc.get("skin", "pink"))
	# v2 feel deltas: resolve this slot's character profile BEFORE add_child so Player._ready() can
	# size the collider from it. Unknown/"bouncer" -> Standard (all identity) = today's feel.
	p.profile = CharacterProfiles.for_id(str(desc.get("character", "bouncer")))
	add_child(p)
	p.global_position = _spawn_at(i)
	players.append(p)
	scores.append(0)
	lives_left.append(lives_per_player)
	var sd: int = int(desc.get("seed_damage", 0))
	if sd > 0 and p.has_method("seed_damage"):
		p.seed_damage(sd)
	if bool(desc.get("human", false)):
		p.set_provider(InputHuman.new())
		p.add_to_group("human")
	else:
		p.set_provider(InputBot.new(p, self, int(desc.get("bot_level", 2))))

## v4_gauntlet: free every non-human player and compact the parallel per-player arrays so indices stay
## consistent (humans keep their stable 0..h-1 indices; bots are always appended after them). Called from
## _begin_stage BETWEEN stages (nothing in flight) for a mode whose wave_spawn_plan() is non-empty; BRAWL/
## TRIALS return [] so this NEVER runs for them (byte-for-byte parity). At call time _stage_deltas /
## _had_contact / _smash_off_stage were just cleared in _begin_stage, so only the persistent per-player
## arrays (scores, lives_left, and the lazily-grown camera arrays) need compacting here.
func _despawn_bots() -> void:
	for i in range(players.size() - 1, -1, -1):
		var p = players[i]
		if not is_instance_valid(p) or not p.is_in_group("human"):
			if is_instance_valid(p):
				p.queue_free()
			players.remove_at(i)
			scores.remove_at(i)
			lives_left.remove_at(i)
			if i < _combat_active_t.size():
				_combat_active_t.remove_at(i)
			if i < _cluster_linger_t.size():
				_cluster_linger_t.remove_at(i)
	# trim any stale trailing camera entries so they can't outlive the roster
	if _combat_active_t.size() > players.size():
		_combat_active_t.resize(players.size())
	if _cluster_linger_t.size() > players.size():
		_cluster_linger_t.resize(players.size())

## Current per-player skins (QA readout; C7 "_skins() equivalent"). Reflects the live spawn plan.
func _skins() -> Array:
	var out: Array = []
	for p in players:
		out.append(p.skin if is_instance_valid(p) else "")
	return out

# ------------------------------------------------------------------- level rotation (§6)
# The shuffle-bag rotation moved into BrawlMode.next_level_path (v1_frontend_shell §3). The runner
# just asks the mode for the next stage's level via `_mode.next_level_path(self)`.

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
	_mode.configure(self, _config)   # fresh level sequence (shuffle-bag) each match (spec §6)
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
	_load_stage(_mode.next_level_path(self))
	# NEW (v4_gauntlet, additive). A mode with a per-stage bot roster (GAUNTLET waves) swaps its bots
	# here, AFTER _load_stage and BEFORE the per-player respawn/pop-in loop below (so the new bots get
	# respawn + pop-in + name tags for free). BRAWL/TRIALS return [] -> this block never runs -> parity.
	var wave: Array = _mode.wave_spawn_plan(self)
	if not wave.is_empty():
		_despawn_bots()                       # free the previous wave's (now-dead) bots, compact parallel arrays
		for desc in wave:
			_spawn_player(players.size(), desc)   # REUSE the exact runner spawn path (humans-first invariant holds)
	if _camera != null:
		_camera.snap_to(_stage_rect.get_center(), CAM_MAX_ZOOM)
	_hud.hide_center()
	_clear_name_tags()
	for i in range(players.size()):
		var p = players[i]
		_stage_deltas.append(0)
		_had_contact.append(false)
		_smash_off_stage.append(false)
		lives_left[i] = lives_per_player
		p.respawn(_spawn_at(i))
		p.frozen = true
		p.visible = false
		_hud.set_dead(i, false)
	_stage_start_alive = players.size()
	# NEW (v5_sports, additive). After players are placed + the wave block, a mode may spawn/re-center a
	# stage-scoped PROP (SPORTS re-spawns the Ball at kickoff). BRAWL/TRIALS/GAUNTLET inherit the base
	# no-op -> this call does literally nothing for them -> byte-for-byte parity (same guarantee as
	# wave_spawn_plan). This is the ENTIRE runner delta for SPORTS: one no-op seam + this one call site.
	_mode.on_stage_ready(self)
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
		# reset bot motion-health so its stuck/underside/blocked-ascent numbers are per-stage
		if is_instance_valid(p) and p.provider != null and p.provider.has_method("reset_motion_health"):
			p.provider.reset_motion_health()
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
	# NON-KILL-RACE stage end (v3_content_plan B.2, TRIALS): a mode that polls_goal() ends the stage
	# the instant it reaches its goal (goal-touch), with NO death required. BRAWL polls_goal() is false
	# so this never runs for BRAWL (C7 parity); its stage end stays the death-driven is_stage_over check
	# inside _decide_stage_end below.
	if state == "COMBAT" and _mode.polls_goal() and _mode.is_stage_over(self):
		_decide_stage_end(false)
		return
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
			# v1_level_circuit §L-4 TC1: victim death X, so multi-void levels (twin_chasms) can measure
			# whether deaths split across BOTH chasms (left vs right of the centre island). Instrumentation
			# only — no lethality/credit change; harmless on single-void levels.
			"vx": (victim.global_position.x if is_instance_valid(victim) else 0.0),
			# v1_moving_hazard §2 (WY1): mark a death that occurred within ~1.5s of a moving-hazard
			# shove, so QA can measure hazard-driven/-assisted kills. Instrumentation only — no
			# lethality/credit change; harmless (dt is huge) on levels with no moving_hazard.
			"hazard_contact_dt_s": (victim.hazard_contact_dt_s() if is_instance_valid(victim) and victim.has_method("hazard_contact_dt_s") else 9999.0),
			"hazard_assisted": (is_instance_valid(victim) and victim.has_method("hazard_contact_dt_s") and victim.hazard_contact_dt_s() <= 1.5),
			"t": round_clock,
		})
		_cur_stats["end_cause"] = str(cause)   # the stage-deciding death overwrites last
	# kill credit vs suicide (spec §2), delegated to the mode's scoring hook. Every cause counts; dead
	# attackers still score ("beyond the grave"); being killed is never -1. Score is CUMULATIVE kills.
	var ai: int = players.find(attacker) if attacker != null else -1
	_mode.on_kill(self, ai, idx, cause)
	if ai >= 0 and ai != idx and not _first_blood_fired:
		_first_blood_fired = true
		_hud.show_top("FIRST BLOOD!", PLAYER_COLORS[ai], 1.0)
		EventBus.first_blood.emit(ai)   # audio: announcer
	# kill-race feedback: pips track cumulative kills and pop the INSTANT a kill is credited (spec §4)
	_hud.animate_scores(scores.duplicate())
	# MATCH-END on the winning KILL (spec §2): the final kill IS the hero moment — freeze here,
	# do not wait for STAGE_END. Requires a strict single leader at >= target (mode decides).
	var widx: int = _mode.match_winner(self)
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
	if not _mode.is_stage_over(self):   # BRAWL: >= 2 not-eliminated -> stage continues
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
		_cur_stats["motion_health"] = bot_motion_health()   # process gate: per-stage locomotion pathologies
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
	var banner: Dictionary = _mode.stage_end_banner(self)
	var txt: String = str(banner.get("text", "NOBODY SURVIVES"))
	var col: Color = banner.get("color", Color.WHITE)
	_hud.show_center(txt, col, Tuning.round_end_freeze - 0.35, _deltas_line())
	_hud.animate_scores(scores.duplicate())

func _tick_stage_end(delta: float) -> void:
	_state_t += delta
	if _state_t < Tuning.round_end_freeze:
		return
	# Safety match-end check (spec §2): normally the match already ended on the winning kill; this
	# only catches a strict leader that appeared without a live match-end check (defensive).
	var widx: int = _mode.match_winner(self)
	if widx >= 0:
		_enter_match_end(widx)
		return
	# a tie at >= target (double-KO crediting two to target in the window) does NOT end — play on
	var mx := -1
	for s in scores:
		mx = maxi(mx, int(s))
	if mx >= match_target_kills:
		_tiebreaker_next = true
	# MATCH POINT: first time a player hits target-1 kills (spec §4)
	for i in range(scores.size()):
		if int(scores[i]) >= match_target_kills - 1 and not _match_point_announced.has(i):
			_match_point_announced[i] = true
			_pending_match_point.append(i)
	_begin_stage()

func _enter_match_end(widx: int) -> void:
	state = "MATCH_END"
	_state_t = 0.0
	_match_winner = widx
	_prompt_shown = false
	_record_progression(widx)   # v6 §4: unlock-progression trigger (BRAWL circuit matches only)
	_record_sports_progression(widx)   # v8 §4.3: Sports court unlock trigger (SPORTS matches only)
	# finalize any in-flight stage record so QA can read the winning stage
	if not _cur_stats.is_empty():
		_cur_stats["length_s"] = round_clock
		_cur_stats["motion_health"] = bot_motion_health()
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
	var banner: Dictionary = _mode.match_end_banner(self)
	_hud.show_match_end(str(banner.get("text", "")), banner.get("color", Color.WHITE), str(banner.get("subline", "")))

## v6 §4.2 unlock trigger: record a finished BRAWL CIRCUIT match into Settings progression (win +
## per-circuit play + cumulative kills; may set pending_unlock). Guarded so it is a no-op for every
## non-circuit match (RANDOM_ALL / SINGLE) and every non-BRAWL mode -> they never touch progression.
func _record_progression(widx: int) -> void:
	if _config == null or _config.mode_id != &"brawl":
		return
	if _config.arena_mode != MatchConfig.ArenaMode.CIRCUIT or str(_config.circuit_id) == "":
		return
	# a HUMAN win = the winner slot is one of the humans-first slots (players[0..human_count-1])
	var human_won: bool = widx >= 0 and widx < _config.human_count
	var human_kills := 0
	for i in range(mini(_config.human_count, scores.size())):
		human_kills += int(scores[i])
	Settings.record_match_result(str(_config.circuit_id), human_won, human_kills)

## v8_sports_courts.md §4.3 unlock trigger: record a finished SPORTS match into Settings progression
## (bumps sports_matches; a HUMAN win bumps sports_wins -> the chaos-finale gate). No-op for every
## non-SPORTS mode (they never touch Sports progression). Mirrors _record_progression.
func _record_sports_progression(widx: int) -> void:
	if _config == null or _config.mode_id != &"sports":
		return
	var human_won: bool = widx >= 0 and widx < _config.human_count
	Settings.record_sports_result(human_won)

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
		# match-end QUIT returns to the shell MainMenu (v1_frontend_shell §9 C9), NOT app-quit
		get_tree().change_scene_to_file(SHELL_SCENE)

## menu_back during a live match opens the PauseMenu overlay (v1_frontend_shell §5 C8). MATCH_END is
## handled by _tick_match_end (its menu_back = QUIT-to-menu), so ignore it here.
func _unhandled_input(e: InputEvent) -> void:
	if state == "MATCH_END" or state == "BOOT":
		return
	if e.is_action_pressed(&"menu_back") and not is_instance_valid(_pause_overlay):
		get_viewport().set_input_as_handled()
		_open_pause()

func _open_pause() -> void:
	_pause_overlay = PAUSE_SCENE.instantiate()
	add_child(_pause_overlay)
	if _pause_overlay.has_method("setup"):
		_pause_overlay.setup(self)
	get_tree().paused = true

func _deltas_line() -> String:
	var parts: Array[String] = []
	for i in range(_stage_deltas.size()):
		var d: int = _stage_deltas[i]
		# SD display fix (pacing6): on a sudden-death stage the announced SURVIVOR lost their last life
		# into the double-KO and was revived, so their true net stage delta can be negative — a "P1
		# SURVIVES! P1 -1" banner reads wrong. Floor the SURVIVOR's own displayed delta to >=0 (a 0
		# suppresses it from the line). DISPLAY ONLY — cumulative scores & kill-credit are untouched.
		if _revived_this_stage and i == _stage_winner and d < 0:
			d = 0
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
	# MODE FIXED FRAMING (v5_sports): a mode may return a world Rect2 to frame the whole play area (SPORTS
	# -> the court, so both goals + the ball stay on screen). null -> the default cluster framing below is
	# UNCHANGED (BRAWL/TRIALS/GAUNTLET byte-for-byte). set_frame reuses the existing smoothing.
	var framing: Variant = _mode.camera_framing(self)
	if framing is Rect2:
		var fr: Rect2 = framing
		var fz := minf(1920.0 / maxf(fr.size.x, 1.0), 1080.0 / maxf(fr.size.y, 1.0))
		fz = clampf(fz, CAM_MIN_ZOOM, CAM_MAX_ZOOM)
		_camera.set_frame(fr.get_center(), fz)
		return
	var dt := get_physics_process_delta_time()
	while _combat_active_t.size() < players.size():
		_combat_active_t.append(0.0)
	while _cluster_linger_t.size() < players.size():
		_cluster_linger_t.append(0.0)

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

	# No launch-cam regime toggle anymore (killed the "breathing pump" that fired on every smash):
	# a fast flier's POSITION naturally widens the smoothed AABB frame, and the asymmetric zoom
	# (out-fast / in-slow) in CameraController absorbs the transient. The 0.60 readability floor is
	# the normal min zoom for everything.
	var bcenter := bounds.get_center()

	# --- choose the BASE framing membership this tick ---
	# The local human P1 (players[0]) is tracked separately so it can always be guaranteed into the
	# cluster (CD #5 fix a) without disturbing the super-aim path.
	var p1 = players[0] if players.size() > 0 else null
	var p1_live: bool = is_instance_valid(p1) and not p1.is_dead()

	var base: Array = []
	if aimer != null:
		# super bias: frame caster + nearest living opponent tightly (§4). Left untouched so P1
		# inclusion NEVER overrides the aim-fuse readability bias (brief a).
		base = [aimer]
		var opp = nearest_opponent(aimer)
		if is_instance_valid(opp) and not opp.is_dead():
			base.append(opp)
	else:
		# combat-active cluster (dealt/took a hit or aiming in the last COMBAT_ACTIVE_WINDOW s);
		# fallback to all living when the fight is momentarily quiet (§2).
		for p in living:
			var idx := players.find(p)
			if idx >= 0 and _combat_active_t[idx] > 0.0:
				base.append(p)
		if base.is_empty():
			base = living.duplicate()

	# cluster hysteresis (CD #5 fix b): base members refresh their linger to full; recently-framed
	# players stay in the cluster (with a fading weight) for CAM_CLUSTER_LINGER so the centroid/extent
	# target eases through a membership change (e.g. players splitting into pairs) instead of snapping.
	for p in base:
		var bi := players.find(p)
		if bi >= 0:
			_cluster_linger_t[bi] = CAM_CLUSTER_LINGER

	# --- assemble the final cluster + per-member centroid weight ---
	# Every contributor is a LIVING player position, so the weighted centroid can never land on empty
	# geometry with no player (CD #5 fix c): the frame center is always player-driven by construction.
	var cluster: Array = []
	var weights: Array = []
	for p in living:
		var pi := players.find(p)
		var linger: float = _cluster_linger_t[pi] if pi >= 0 else 0.0
		var w := 0.0
		if aimer != null and p == aimer:
			w = SUPER_BIAS_WEIGHT
		elif base.has(p):
			w = 1.0
		elif linger > 0.0:
			w = maxf(0.05, linger / CAM_CLUSTER_LINGER)   # fade a dropped member's pull out smoothly
		# guarantee the local human is always framed while living (fix a) — modest weight, and only in
		# the non-aimer path so it can't drag the frame off a super telegraph.
		if aimer == null and p == p1 and p1_live:
			w = maxf(w, P1_CAM_WEIGHT)
		if w > 0.0:
			cluster.append(p)
			weights.append(w)
	if cluster.is_empty():
		cluster = living.duplicate()
		weights.clear()
		for _p in cluster:
			weights.append(1.0)

	# decay linger for players that dropped out of the base this tick (used next tick)
	for i in range(_cluster_linger_t.size()):
		if i < players.size() and base.has(players[i]):
			continue
		_cluster_linger_t[i] = maxf(0.0, _cluster_linger_t[i] - dt)

	# Frame center + extent. Positions only (an AABB), NOT velocities — folding velocity into the zoom
	# extent made the zoom target jitter at high frequency in a bounce game; velocity leads the PAN below.
	var centroid := Vector2.ZERO
	var ext := Vector2.ZERO
	if aimer != null:
		# SUPER-AIM: keep the TIGHT weighted caster+opp framing (aim-fuse readability — brief a).
		var wsum := 0.0
		for i in range(cluster.size()):
			centroid += cluster[i].global_position * weights[i]
			wsum += weights[i]
		centroid /= maxf(wsum, 0.001)
		for p in base:
			ext = ext.max((p.global_position - centroid).abs())
	else:
		# NON-AIM: FRAME ALL LIVING PLAYERS (their full AABB). The old combat-active-cluster subset
		# drove a left/right frame oscillation — with 2 players each side it kept swapping which pair
		# it fit, shoving the other pair off-screen even though everyone was on-stage. Now the ONLY
		# things that drop a living player from view are the CAM_MIN_ZOOM readability floor (true wide
		# spread) and a genuine off-screen fly-out (edge chevron). Everyone in the playable area stays framed.
		var mn: Vector2 = living[0].global_position
		var mx: Vector2 = living[0].global_position
		for p in living:
			mn = mn.min(p.global_position)
			mx = mx.max(p.global_position)
		centroid = (mn + mx) * 0.5
		ext = (mx - mn) * 0.5
	ext += CAM_MARGIN

	# zoom to fit, then clamp to the floor .. max. The 0.60 readability floor is the normal min for
	# everything now (no launch regime): a fast flier's position simply grows `ext` -> lower z, and
	# the asymmetric out-fast damping widens the view smoothly to meet it.
	var z := minf(1920.0 / maxf(2.0 * ext.x, 1.0), 1080.0 / maxf(2.0 * ext.y, 1.0))
	var lo := CAM_MIN_ZOOM
	if aimer != null:
		lo = maxf(lo, SUPER_BIAS_MIN_ZOOM)   # aim-fuse legibility
	z = clampf(z, lo, CAM_MAX_ZOOM)

	# Fix 1: velocity leads the PAN (frame center), not the zoom. Nudge the center ahead of the
	# cluster's weighted motion so a fast launch stays on-screen without inflating the zoom target.
	# (The weighted cluster still biases the PAN toward the action even though the ZOOM now fits all
	# living — so the frame leans into the fight without ever dropping an on-stage player.)
	var vlead := Vector2.ZERO
	var vwsum := 0.0
	for i in range(cluster.size()):
		vlead += cluster[i].velocity.limit_length(CAM_LEAD_CAP) * weights[i]
		vwsum += weights[i]
	vlead = (vlead / maxf(vwsum, 0.001)) * CAM_LEAD_TIME

	# clamp the frame center so the visible rect stays inside bounds (never reveal the void)
	var half := Vector2(1920.0, 1080.0) / (2.0 * z)
	var cx: float = centroid.x + vlead.x
	var cy: float = centroid.y + vlead.y
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

## Bot MOTION-HEALTH probe (process gate 2026-07-04): surfaces per-bot locomotion pathologies so
## "looks dumb" (head-banging platform undersides, stuck-in-place, blocked ascent) becomes a NUMBER,
## not a human's eyeball. Queryable live via gbplay eval; also snapshotted into round_stats per stage.
func bot_motion_health() -> Array:
	var out: Array = []
	for i in range(players.size()):
		var p = players[i]
		if not is_instance_valid(p) or p.provider == null or not p.provider.has_method("motion_health"):
			continue
		var mh: Dictionary = p.provider.motion_health()
		mh["player"] = i
		out.append(mh)
	return out

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
