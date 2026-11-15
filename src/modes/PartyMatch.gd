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
	"res://levels/singularity.json",
	"res://levels/twin_moons.json",
]
# FALLBACK slot palette ONLY (WK-08): identity colour is player_color(i) = the colour of the goat skin
# players[i] wears (PlayerIdentity.SKIN_COLORS). This palette is read only for an unknown skin id.
const PLAYER_COLORS: Array[Color] = [
	Color("#ff5fa8"), Color("#4aa8ff"), Color("#54c94a"), Color("#ffc93f"),
	Color("#b06bff"), Color("#ff8a3f"), Color("#3fd8d0"), Color("#f0f0f0")]
# GameMode registry (v1_frontend_shell §3.2): mode_id -> mode script. PartyMatch is a regular (non-
# autoload) script, so preloading the class_name mode scripts here is safe.
const MODE_REGISTRY := {
	&"brawl": preload("res://src/modes/BrawlMode.gd"),
	&"trials": preload("res://src/modes/TrialsMode.gd"),
	&"sports": preload("res://src/modes/SportsMode.gd"),      # legacy id (back-compat)
	&"rocketball": preload("res://src/modes/SportsMode.gd"),  # the soccer sport (owner 2026-07-19 split)
	&"dropshot": preload("res://src/modes/SportsMode.gd"),    # the volleyball sport
}
# Front-end shell hooks (v1_frontend_shell §5): pause overlay + return-to-menu on quit.
const PAUSE_SCENE := preload("res://scenes/ui/PauseMenu.tscn")
const SHELL_SCENE := "res://scenes/ui/ShellRoot.tscn"
var _pause_overlay: CanvasLayer = null

# Between-stage SCORE SCREEN (owner 2026-07-16 — Duck Game/TowerFall pattern; mode opt-in via
# GameMode.wants_scoreboard, BRAWL only). Replaces the corner-card score pips as the score display.
# NOTE: this deliberately extends the death->next-BOUNCE turnaround beyond the old <=4.5s contract
# for BRAWL (owner-directed; the screen is skippable with accept after a short guard).
const SCORE_SCENE := preload("res://scenes/ui/ScoreScreen.tscn")
# WK-21 adaptive hold (audit D-09): Tuning.score_hold_normal (2.0 s) on a quiet stage, Tuning.score_hold_dramatic
# (3.4 s, the owner's original SCORE_HOLD) on a lead change / newly-reached match point / tiebreaker.
# WK-11: the skip guard is Tuning.scoreboard_skip_guard (1.2 s) through a MenuInputGate (fresh presses only);
# WK-21 adds FLY (boost) as a skip verb on that gate.
var _score_screen: CanvasLayer = null
var _score_gate: MenuInputGate = null
var _score_skip := false
var _score_leave_t := -1.0       # SCOREBOARD time the fade-out started (-1 = still holding)
var _stage_start_scores: Array = []  # scores at this stage's BOUNCE! (lead-change test for the adaptive hold)
var score_hold := 0.0            # QA: the hold chosen for the current/last score screen (s)
var score_hold_reason := ""      # QA: "normal" | "lead_change" | "match_point" | "tiebreaker"
var _mp_banner: Array = []       # WK-41: [text, color] MATCH POINT top banner waiting for the intro card to leave

# WK-21/41 between-stage instrumentation (QA, read via gbplay eval). One entry per state ENTRY:
# {state, stage, t_ms (wall), clock (flow clock), wall_s / tick_s (duration, -1 while running), frames,
#  max_frame_ms, stall_frames, stall_ms}. `tick_s` is what the state machine's timers SAW (sum of rdelta);
# `wall_s - tick_s` is wall time the timers never saw, ~= `stall_ms`: frames longer than
# max_physics_steps_per_frame / physics_ticks_per_second (8/120 = 66.7 ms) cap the physics steps, so the flow
# timers stop advancing during a hitch / capture stall while the wall clock keeps running.
# Note: a pause mid-measure shows up as one huge stall frame. between_stage_report() / between_stage_summary()
# fold the log into per-transition STAGE_END -> COMBAT rows. overlay_overlaps counts frames where 2+
# interstitial overlays were on screen together, keyed "STATE:a+b" (WK-41 accept: none in
# STAGE_END/SCOREBOARD/STAGE_INTRO).
const PHASE_LOG_MAX := 600
const BURST_STATES := ["STAGE_END", "SCOREBOARD", "STAGE_INTRO", "COUNTDOWN"]
var phase_log: Array = []
var overlay_overlaps: Dictionary = {}
var _flow_clock := 0.0
var _last_frame_usec := 0

# MATCH CEREMONY (docs/briefs/match_ceremony_2026-07-18.md — BRAWL opt-in via wants_scoreboard):
# stage intro card (rides the existing STAGE_INTRO/countdown window, adds 0.0s and NEVER gates
# state — gating _start_countdown on it is a design REJECT), first-stage controls legend, and the
# match-end VICTORY ceremony (replaces _hud.show_match_end for BRAWL; Trials/Sports keep theirs).
const INTRO_CARD_SCENE := preload("res://scenes/ui/StageIntroCard.tscn")
const LEGEND_SCENE := preload("res://scenes/ui/ControlsLegend.tscn")
const VICTORY_SCENE := preload("res://scenes/ui/VictoryScreen.tscn")
const VICTORY_DELAY := 0.9     # s after the winning kill before the ceremony (punch-zoom breathes)
const SKIN_NAMES := {
	"pink": "POGO", "blue": "BUTCH", "green": "ZIGGY",
	"yellow": "PUFF", "purple": "VEX", "orange": "BILLY",
}
var _intro_card: CanvasLayer = null
var _legend: CanvasLayer = null
var _victory: CanvasLayer = null

# --- Camera (OWNER RULES 2026-07-10 — docs/feedback/owner_2026-07-10_camera_rules.md) ---
# This SUPERSEDES the camera_2x_policy action-cluster/velocity-lead/readability-floor model (the
# owner rejected it ~5 times: players off-screen on wide spreads, frame flying left/right). Rules:
# (1) camera_bounds = platform-union AABB + Tuning.cam_bounds_pad on every side; (2) a living
# in-bounds player is on-screen 100% of frames — the zoom simply fits everyone (no readability
# floor); (3) the frame targets the MIDPOINT of the extreme players' bounds-clamped positions —
# no weights, no combat bias, no velocity lead (stable target = calm motion); (4) zoom-in cap:
# even with players clustered, at least Tuning.cam_close_fraction of the camera-bounds extent
# stays visible. CameraController's exp smoothing + asymmetric zoom damping are unchanged.
const CAM_MAX_ZOOM := 0.92     # absolute zoom-in ceiling (small arenas; the per-level cap may be lower)
const CAM_MIN_ZOOM := 0.60     # ONLY used by mode fixed-framing (SPORTS court fit) as its floor
const CAM_OFFSCREEN_INSET := 40.0  # px: a living player outside visible rect+inset gets an edge chevron
const COMBAT_ACTIVE_WINDOW := 1.2  # s combat-active memory (kept for _mark_combat_active consumers)
const CAM_MARGIN := Vector2(420.0, 340.0)  # breathing room added around the framed extremes
const MATCH_END_ZOOM := 1.1    # winner punch-zoom (FEEL §7)
const BOUNCE_HOLD := 0.4       # "BOUNCE!" banner hold (spec §1)
const SD_REVIVE_LOCK := 0.8    # "SUDDEN DEATH!" revive banner hold, inputs locked (spec §5)
const PROMPT_GUARD := 1.0      # MATCH_END input guard before REMATCH/QUIT arms (spec §1)
const GOLD := Color("#ffd23f")
const DANGER := Color("#ff4b3a")

# --- QA contract (killrace §8) ---
var state := "BOOT":
	set(v):
		if v != state:
			_log_phase(v)   # WK-21: every state entry is timestamped (wall + flow clock)
		state = v
var stage_index := 0
var round_index := 0             # alias of stage_index (QA/tools may read either)
var round_clock := 0.0           # stat-only combat clock; gates NOTHING (no timer SD anymore)
var scores: Array = []           # CUMULATIVE kills per player, never reset between stages
var raw_kills: Array = []        # v11 §5.1(2): RAW credited kills per player this match — never decremented
                                 # (self-falls adjust `scores` only). The cosmetic-ladder bank source.
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
var camera_bounds := Rect2(0, 0, 1920, 1080)  # platform AABB + cam_bounds_pad (owner camera rule 1)
var _camera: CameraController
var _juice: Juice
var _level_root: Node2D
var _hud
var _had_contact: Array = []     # per-player: dealt/received >=1 smash this stage (stats)
var _smash_off_stage: Array = [] # per-player: was the LAST smash they received taken off-stage?
var _combat_active_t: Array = [] # per-player: seconds left in the combat-active window (camera bias)
var _edge_indicators             # EdgeIndicators overlay (off-screen player chevrons)
var _ko_blast                    # KOEdgeBlast CanvasLayer (WK-23; QA: _ko_blast.blasts / blast_count)
# WK-37 ghost goats (docs/specs/wk37a_ghost_goats_2026-11-14.md): the GhostDirector, BRAWL + GHOSTS != OFF only.
# null with GHOSTS OFF (and in SPORTS/TRIALS) -> every hook below is skipped = byte-for-byte the pre-WK-37 match.
const GHOST_DIRECTOR := preload("res://src/systems/GhostDirector.gd")
var _ghost_dir = null
const OFF_STAGE_GROW := 120.0    # px: "off-stage" = outside _stage_rect grown by this (stats + WK-24 ring)

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
var _stage_kills: Array = []     # WK-25: this stage's kill records (snapshot at STAGE_END) -> ScoreScreen kill list
var _stage_self_kos: Array = []  # WK-20c: self-KOs per player this stage (BrawlMode.on_kill) -> "OOPS!" when they cost 0
## WK-20c (Ra): points a BRAWL self-KO costs (MatchConfig.self_ko_penalty via BrawlMode.configure). 0 = default.
var self_ko_penalty := 0
var _stage_start_alive := 0
var _stage_winner := -1
var _two_left_fired := false
var _first_blood_fired := false  # once per MATCH (spec §4)
var _match_point_announced := {} # player idx -> true, fires once per player per match
var _pending_match_point: Array = []
var _tiebreaker_next := false
var _match_winner := -1
var _prompt_shown := false
var _pips                        # PlayerPips overlay (WK-10: persistent P# pips over humans, CPU at intro)

func _ready() -> void:
	# resolve the config + mode FIRST (v1_frontend_shell §2/§3): a fresh/default GameConfig reproduces
	# today's boot exactly. configure() sets the match target/lives and builds the level sequence.
	_config = GameConfig.match_config
	if _config == null:
		GameConfig.reset_to_defaults()
		_config = GameConfig.match_config
	# WK-02 roster cap: no config path (stale setup, CHANGE SETUP round trip, QA eval) may field more
	# than MatchConfig.MAX_FIGHTERS (= the 4 HUD corners). Bots are trimmed first, humans never.
	if _config.clamp_roster():
		push_warning("PartyMatch: roster clamped to %d humans + %d bots (MAX_FIGHTERS=%d)" % [
			_config.human_count, _config.bot_count, MatchConfig.MAX_FIGHTERS])
	var mode_script = MODE_REGISTRY.get(_config.mode_id, MODE_REGISTRY[&"brawl"])
	_mode = mode_script.new()
	_mode.configure(self, _config)

	bounds = Rect2(-120, -120, 2160, 1380)
	_level_root = Node2D.new()
	add_child(_level_root)
	# WK-37: the ghost layer goes in right after the level root and BEFORE the players, so by tree order clouds and
	# ghosts draw above the level and below every living goat (spec §5). GHOSTS OFF / non-BRAWL: never created.
	if _ghosts_enabled():
		_ghost_dir = GHOST_DIRECTOR.new()
		_ghost_dir.setup(self, int(_config.ghosts))
		add_child(_ghost_dir)
	_load_stage(LEVEL_POOL[0])   # a level exists before the camera/HUD reference _stage_rect

	_camera = CameraController.new()
	_camera.position = _stage_rect.get_center()
	_camera.dynamic = true   # Smash-style: follow the action, zoom to keep everyone on screen
	_camera.follow_speed = 8.0   # kill-zone spec §6.4: tighter PAN follow so a fresh launch doesn't outrun the frame
	_camera.zoom_out_speed = 9.0   # widen the view fast (never clip a flier)
	_camera.zoom_in_speed = 3.0    # tighten the view slow (no snap-in-then-back "pump")
	_camera.zoom_deadzone = 0.012  # ignore sub-threshold zoom-target wiggle
	add_child(_camera)
	_snap_camera_stage_start()   # WK-148b: sports snap straight to the court framing; others unchanged
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
	if plan.size() > MatchConfig.MAX_FIGHTERS:
		# belt-and-braces (WK-02): plans list humans first, so truncation only ever drops bots
		push_warning("PartyMatch: spawn plan of %d truncated to MAX_FIGHTERS=%d" % [plan.size(), MatchConfig.MAX_FIGHTERS])
		plan.resize(MatchConfig.MAX_FIGHTERS)
	for i in range(plan.size()):
		_spawn_player(i, plan[i])

	# corner HUD cards visible immediately (spec §1 BOOT); HUD variant comes from the mode
	_hud = _mode.hud_scene().instantiate()
	add_child(_hud)
	_hud.setup(players, player_colors(), _skins())
	if _hud.has_method("set_labels"):
		# WK-10/WK-88 (CC-8.5): NAME ("P3" / goat name for a CPU) + small sub-tag (goat name / "CPU")
		_hud.set_labels(player_names(), player_subtags())
	# Sports/Trials match-end: the HUD owns a real focusable REMATCH/SETUP/QUIT row (VictoryScreen bar).
	# Connect ONCE at HUD creation so a rematch (same HUD instance) never stacks duplicate handlers.
	if _hud.has_signal("match_button_pressed"):
		_hud.match_button_pressed.connect(_on_match_button)

	# between-stage score screen (BRAWL opt-in; hidden until the first SCOREBOARD state)
	if _mode.wants_scoreboard():
		_score_screen = SCORE_SCENE.instantiate()
		_score_screen.visible = false
		add_child(_score_screen)
		# WK-11 (C-14 / CC-10.2): the tally skip takes only FRESH accepts from JOINED devices, after a guard
		_score_gate = MenuInputGate.new()
		_score_gate.name = "ScoreGate"
		_score_gate.extra_accept_actions = PackedStringArray(["boost"])   # WK-21 / D-09: FLY skips too (fresh press only)
		add_child(_score_gate)
		_score_gate.verb.connect(func(v: String, _k: String) -> void:
			if v == "accept" and state == "SCOREBOARD":
				_score_skip = true)
		# match ceremony pieces share the same BRAWL gate (brief §1/§3)
		_intro_card = INTRO_CARD_SCENE.instantiate()
		add_child(_intro_card)
		_victory = VICTORY_SCENE.instantiate()
		add_child(_victory)
		_victory.rematch_pressed.connect(func() -> void:
			_victory.dismiss()
			_start_match())
		_victory.setup_pressed.connect(func() -> void:
			GameConfig.resume_setup = true
			get_tree().change_scene_to_file(SHELL_SCENE))
		_victory.menu_pressed.connect(func() -> void:
			get_tree().change_scene_to_file(SHELL_SCENE))

	# WK-15 (CC-11.1): the stage-1 controls legend runs in EVERY mode (was BRAWL-only behind wants_scoreboard).
	# The mode supplies its verbs + one-line goal (GameMode.legend_verbs / goal_line).
	_legend = LEGEND_SCENE.instantiate()
	add_child(_legend)

	# off-screen player edge chevrons (camera_2x_policy §3): own CanvasLayer, BELOW the HUD (layer 0
	# vs the HUD's default layer 1) so corner cards stay on top of any edge indicator.
	var edge_cl := CanvasLayer.new()
	edge_cl.layer = 0
	add_child(edge_cl)
	_edge_indicators = load("res://src/ui/EdgeIndicators.gd").new()
	edge_cl.add_child(_edge_indicators)
	_edge_indicators.setup(self, player_colors())

	# WK-10 identity pips (CC-8.3): screen-space, constant size, own CanvasLayer just above the world
	# and the chevrons, below the HUD (10) / intro card (11). Polls this runner; no per-frame calls here.
	var pip_cl := CanvasLayer.new()
	pip_cl.layer = 1
	add_child(pip_cl)
	_pips = load("res://src/ui/PlayerPips.gd").new()
	pip_cl.add_child(_pips)
	_pips.setup(self)

	# WK-23 screen-edge KO blast (audit D-01): its own CanvasLayer above the chevrons/pips (0/1), below the
	# HUD (10) so corner cards stay on top. Presentation only — subscribes to KillPipeline.killed itself and
	# never touches the camera. Gated per mode by ko_blast_enabled().
	_ko_blast = load("res://src/ui/KOEdgeBlast.gd").new()
	_ko_blast.layer = 5
	add_child(_ko_blast)
	_ko_blast.setup(self)

	# WK-53b / WK-26 living-goat cues: the taunt "BAAA!" (+ the bleated emit) and the "!" over a super's target.
	# CanvasLayer 2 (with the ghost words); polls this runner read-only. Find it via get_node("LivingCues").
	var living_cues = load("res://src/ui/LivingCues.gd").new()
	living_cues.name = "LivingCues"
	living_cues.layer = 2
	add_child(living_cues)
	living_cues.setup(self)

	_start_match()

## Spawn one player from a mode spawn-plan descriptor (v1_frontend_shell §3.2):
## {human:bool, skin:String, character:String, bot_level:int, seed_damage:int, team:int}.
func _spawn_player(i: int, desc: Dictionary) -> void:
	var p := Player.new()
	p.skin = str(desc.get("skin", "pink"))
	# v2 feel deltas: resolve this slot's character profile BEFORE add_child so Player._ready() can
	# size the collider from it. Unknown/"bouncer" -> Standard (all identity) = today's feel.
	p.profile = CharacterProfiles.for_id(str(desc.get("character", "bouncer")))
	# v11 cosmetic flair (§2.3): the equipped item rides the human P1 entity ONLY, and is suppressed
	# whole-mode in SPORTS (team-read is sacred). Set before add_child so Player._ready can apply it.
	# Pure presentation — Player re-parameterizes existing VFX channels, never physics/Tuning.
	# WK-06 (audit §E.12): when the Herd Lobby wrote per-human flair_ids, each human wears their own pick
	# (locked / unknown ids resolve to none); otherwise the legacy rule — Settings.equipped_flair on human 0.
	if bool(desc.get("human", false)) and _config != null and not SportsMode.is_sports_mode(_config.mode_id):
		if not _config.flair_ids.is_empty():
			var fid: String = _config.flair_for(i)
			if fid != "" and Settings.is_flair_unlocked(fid):
				p.flair = Settings.flair_item(fid)
		elif i == 0:
			p.flair = Settings.equipped_flair_item()
	# WK-23/24 attribution presentation: the player asks this runner for identity colours (player_color)
	# and off-stage state. The last-touch ring is a kill-credit cue -> BRAWL only (not SPORTS/TRIALS).
	p.identity_resolver = self
	p.show_last_touch = _attribution_mode()
	add_child(p)
	p.global_position = _spawn_at(i)
	players.append(p)
	scores.append(0)
	raw_kills.append(0)
	lives_left.append(lives_per_player)
	var sd: int = int(desc.get("seed_damage", 0))
	if sd > 0 and p.has_method("seed_damage"):
		p.seed_damage(sd)
	if bool(desc.get("human", false)):
		# every mode's spawn plan lists humans FIRST, so slot i == human index for device assignment.
		# WK-04: exactly one device per human; "" = the legacy any-device provider (lone unassigned human).
		var dev: String = _human_device_key(i)
		p.set_provider(InputHuman.new() if dev == "" else InputHuman.for_device(dev))
		p.add_to_group("human")
	else:
		p.set_provider(InputBot.new(p, self, int(desc.get("bot_level", 2))))

## WK-04 device plan (CC-3.1), resolved ONCE per scene from the config (rematch keeps it):
##  - MatchConfig.human_devices non-empty (the lobby wrote it) -> human i = human_devices[i] exactly; a human
##    past the end of the list gets an unbound provider + warning (config bug; never a shared keyboard).
##  - empty + 1 human -> "" = legacy any-device (cold boot straight into Arena.tscn, QA harness).
##  - empty + 2+ humans (today's HUMANS stepper, until the Herd Lobby writes human_devices) ->
##    InputRouter.default_devices(): one distinct device each, from devices SEEN, never enumeration.
## Result is public (`human_device_keys`, per human index) for QA eval and the pause-owner -> P# mapping.
var human_device_keys: PackedStringArray = PackedStringArray()

func _human_device_key(i: int) -> String:
	if human_device_keys.is_empty():
		var n: int = _config.human_count if _config != null else 1
		if _config != null and not _config.human_devices.is_empty():
			for h in range(n):
				var k: String = _config.device_for(h)
				if k == "":
					push_warning("PartyMatch: human %d has no device in human_devices %s -> unbound" % [h, str(_config.human_devices)])
					k = "none"
				human_device_keys.append(k)
		elif n <= 1:
			human_device_keys.append("")
		else:
			human_device_keys = InputRouter.default_devices(n)
	if i >= 0 and i < human_device_keys.size():
		return human_device_keys[i]
	return "none"

## Human index driven by device `key` ("kb" / "pad:N"), -1 if none. A legacy any-device human (key "")
## matches every keyboard/pad key. WK-09 uses this to label the pause owner.
func human_index_for_device(key: String) -> int:
	for h in range(human_device_keys.size()):
		if human_device_keys[h] == key or (human_device_keys[h] == "" and key != ""):
			return h
	return -1

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
			raw_kills.remove_at(i)
			lives_left.remove_at(i)
			if i < _combat_active_t.size():
				_combat_active_t.remove_at(i)
	# trim any stale trailing camera entries so they can't outlive the roster
	if _combat_active_t.size() > players.size():
		_combat_active_t.resize(players.size())

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
	# CD1-01: the director must spawn at THIS level's points (it used to keep the boot placeholder's array
	# forever). Empty (sports courts / trials courses, by authoring) = no powerups this stage.
	if _pu_director != null:
		_pu_director.set_points(_pu_points)
	bounds = data.get("bounds", Rect2(-120, -120, 2160, 1380))
	_stage_rect = data.get("play_rect", Rect2(bounds.get_center() - Vector2(900, 160), Vector2(1800, 320)))
	# ALL-DESTRUCTIBLE arenas (no static platforms — e.g. collapse finales) yield an EMPTY play_rect, which
	# pins the camera at max zoom-in. Fall back to the arena bounds so the whole floor still frames (2026-07-19 QA).
	if _stage_rect.size.x <= 1.0 or _stage_rect.size.y <= 1.0:
		_stage_rect = bounds
	# OWNER CAMERA RULE 1: per-level camera bounds = the platform-union AABB padded on every side.
	# A player inside this rect is ALWAYS on-screen; outside it they're in off-screen-kill space.
	camera_bounds = _stage_rect.grow(Tuning.cam_bounds_pad)
	level_index = maxi(0, LEVEL_POOL.find(path))
	level_name = str(data.get("name", path.get_file().get_basename()))
	_kill_shape = str(data.get("kill_shape", "central_pit"))   # v2a §4b#1: QA target class

# ------------------------------------------------------------------- state machine

func _physics_process(delta: float) -> void:
	# UI/flow beats run on REAL time: hitstop scales `delta`, and the pillar-4 turnaround
	# contract (last death -> next BOUNCE <= 4.5s) is measured on the wall clock.
	var rdelta := delta / maxf(Engine.time_scale, 0.05)
	_flow_clock += rdelta   # WK-21 instrumentation: the time the flow timers actually see
	match state:
		"STAGE_INTRO":
			_tick_intro(rdelta)
		"COUNTDOWN":
			_tick_countdown(rdelta)
		"COMBAT", "SUDDEN_DEATH":
			_tick_combat(delta, rdelta)
		"STAGE_END":
			_tick_stage_end(rdelta)
		"SCOREBOARD":
			_tick_scoreboard(rdelta)
		"MATCH_END":
			_tick_match_end(rdelta)
	if state != "MATCH_END":
		_update_camera()

# ------------------------------------------------------------------- between-stage instrumentation (WK-21/41)

## State-entry hook (called from the `state` setter): close the previous phase's durations, open a new one.
func _log_phase(new_state: String) -> void:
	var now := Time.get_ticks_msec()
	if not phase_log.is_empty():
		var prev: Dictionary = phase_log[phase_log.size() - 1]
		prev["wall_s"] = float(now - int(prev["t_ms"])) / 1000.0
		prev["tick_s"] = _flow_clock - float(prev["clock"])
	phase_log.append({
		"state": new_state, "stage": stage_index, "t_ms": now, "clock": _flow_clock,
		"wall_s": -1.0, "tick_s": -1.0, "frames": 0, "max_frame_ms": 0.0, "stall_frames": 0, "stall_ms": 0.0,
	})
	if phase_log.size() > PHASE_LOG_MAX:
		phase_log.pop_front()

## Per-frame: frame-time stats into the open phase entry, and the overlay audit during the interstitial.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_usec > 0 and not phase_log.is_empty():
		var ms: float = float(now - _last_frame_usec) / 1000.0
		var e: Dictionary = phase_log[phase_log.size() - 1]
		e["frames"] = int(e["frames"]) + 1
		e["max_frame_ms"] = maxf(float(e["max_frame_ms"]), ms)
		var cap_ms: float = 1000.0 * float(Engine.max_physics_steps_per_frame) / float(Engine.physics_ticks_per_second)
		if ms > cap_ms:
			e["stall_frames"] = int(e["stall_frames"]) + 1
			e["stall_ms"] = float(e["stall_ms"]) + (ms - cap_ms)
	_last_frame_usec = now
	if state in BURST_STATES:
		_audit_overlays()

## WK-41 accept probe: which interstitial overlays are on screen THIS frame. 2+ at once -> count the frame.
func _audit_overlays() -> void:
	var on := PackedStringArray()
	if _score_screen != null and _score_screen.is_showing():
		on.append("scoreboard")
	if _intro_card != null and _intro_card.is_showing():
		on.append("intro_card")
	if _hud != null and _hud.has_method("center_showing") and _hud.center_showing():
		on.append("center_banner")
	if _hud != null and _hud.has_method("top_showing") and _hud.top_showing():
		on.append("top_banner")
	if on.size() >= 2:
		var k := "%s:%s" % [state, "+".join(on)]
		overlay_overlaps[k] = int(overlay_overlaps.get(k, 0)) + 1

## QA: fold phase_log into one row per completed STAGE_END -> COMBAT transition.
## Row: {from_stage, to_stage, wall_s, tick_s, stall_ms, since_death_s, score_hold, hold_reason, skipped,
##       phases: {STATE: {wall_s, tick_s, frames, max_frame_ms, stall_frames, stall_ms}}}.
## wall_s = STAGE_END entry -> COMBAT entry on the wall clock (the WK-21 budget number). since_death_s = last
## death -> STAGE_END (the double-KO window), reported separately because it is COMBAT time.
func between_stage_report() -> Array:
	var out: Array = []
	var cur: Dictionary = {}
	for e in phase_log:
		var st: String = str(e["state"])
		if st == "STAGE_END":
			cur = {
				"from_stage": int(e["stage"]), "to_stage": -1, "wall_s": 0.0, "tick_s": 0.0, "stall_ms": 0.0,
				"since_death_s": float(e.get("since_death_s", -1.0)), "score_hold": -1.0, "hold_reason": "",
				"skipped": false, "phases": {},
			}
		if cur.is_empty():
			continue
		if st == "COMBAT":
			cur["to_stage"] = int(e["stage"])
			out.append(cur)
			cur = {}
			continue
		if st != "STAGE_END" and st != "SCOREBOARD" and st != "STAGE_INTRO" and st != "COUNTDOWN":
			cur = {}   # MATCH_END / MATCH_START / SUDDEN_DEATH: not a between-stage transition
			continue
		if float(e["wall_s"]) < 0.0:
			break      # this phase is still running
		var phases: Dictionary = cur["phases"]
		phases[st] = {
			"wall_s": e["wall_s"], "tick_s": e["tick_s"], "frames": e["frames"],
			"max_frame_ms": e["max_frame_ms"], "stall_frames": e["stall_frames"], "stall_ms": e["stall_ms"],
		}
		cur["wall_s"] = float(cur["wall_s"]) + float(e["wall_s"])
		cur["tick_s"] = float(cur["tick_s"]) + float(e["tick_s"])
		cur["stall_ms"] = float(cur["stall_ms"]) + float(e["stall_ms"])
		if e.has("score_hold"):
			cur["score_hold"] = e["score_hold"]
			cur["hold_reason"] = e["hold_reason"]
			cur["skipped"] = e.get("skipped", false)
	return out

## QA one-liner for the WK-21 accept: medians/maxima of STAGE_END -> COMBAT split normal vs dramatic.
func between_stage_summary() -> Dictionary:
	var normal: Array = []
	var dramatic: Array = []
	for r in between_stage_report():
		if str(r["hold_reason"]) == "normal":
			normal.append(float(r["wall_s"]))
		else:
			dramatic.append(float(r["wall_s"]))
	return {
		"n_normal": normal.size(), "median_normal_s": _median(normal), "max_normal_s": _max_of(normal),
		"n_dramatic": dramatic.size(), "median_dramatic_s": _median(dramatic), "max_dramatic_s": _max_of(dramatic),
		"overlay_overlaps": overlay_overlaps.duplicate(),
	}

## QA: clear the between-stage log + overlay audit (start a clean measurement window).
func reset_flow_metrics() -> void:
	phase_log.clear()
	overlay_overlaps.clear()

func _median(a: Array) -> float:
	if a.is_empty():
		return -1.0
	var s := a.duplicate()
	s.sort()
	var n := s.size()
	var h: int = n >> 1
	return float(s[h]) if n % 2 == 1 else (float(s[h - 1]) + float(s[h])) * 0.5

func _max_of(a: Array) -> float:
	var m := -1.0
	for v in a:
		m = maxf(m, float(v))
	return m

## BOOT/rematch entry: zero everything match-scoped, then straight into the first STAGE_INTRO (spec §1).
func _start_match() -> void:
	state = "MATCH_START"
	for i in range(scores.size()):
		scores[i] = 0
	for i in range(raw_kills.size()):
		raw_kills[i] = 0   # v11: the raw bank tally is per-MATCH (a rematch starts a fresh tally)
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
	if _ghost_dir != null:
		_ghost_dir.clear_all()   # WK-37: ghosts/clouds never outlive their stage
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
	_stage_self_kos.clear()
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
			if players.size() >= MatchConfig.MAX_FIGHTERS:
				break                             # WK-02 roster cap holds for wave rosters too
			_spawn_player(players.size(), desc)   # REUSE the exact runner spawn path (humans-first invariant holds)
	if _camera != null:
		_snap_camera_stage_start()   # WK-148b
	_hud.hide_center()
	for i in range(players.size()):
		var p = players[i]
		_stage_deltas.append(0)
		_stage_self_kos.append(0)
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
	elif _intro_card != null:
		# stage intro card rides the pop-in/countdown window (0.0s added; suppressed on tiebreaker —
		# that banner owns the drama). Exits on the first countdown beat in _tick_countdown.
		# WK-15 (D-04/D-13): stage 1 states the rule under the arena name ("SMASH 'EM OFF-SCREEN · FIRST TO 10 KOs")
		var rule: String = _mode.goal_line(self) if stage_index == 1 else ""
		_intro_card.present(stage_index, level_name, _pending_match_point.size() > 0, rule)
	if _legend != null and stage_index == 1:
		# first-stage controls legend (brief §2, every mode — WK-15); fades 4s into COMBAT. Modes with no intro
		# card (Sports/Trials) carry their goal as the legend's gold chip; BRAWL's rule lives on the intro card.
		var goal: String = _mode.goal_line(self) if _intro_card == null else ""
		_legend.present(_mode.legend_verbs(), goal)

func _tick_intro(delta: float) -> void:
	_state_t += delta
	var stagger: float = _mode.intro_pop_stagger(self)   # WK-124: mode seam (default Tuning.intro_pop_stagger)
	while _popped < players.size() and _state_t >= stagger * float(_popped):
		_pop_in(_popped)
		_popped += 1
	# last pop at (n-1)*stagger, plus one more stagger as a beat = ~1.4s total (spec §1)
	if _popped >= players.size() and _state_t >= stagger * float(players.size()):
		_start_countdown()

func _pop_in(i: int) -> void:
	var p = players[i]
	p.visible = true
	p.play_pop_in()
	_spawn_star_burst(p.global_position)
	# the identity tag (human "P#" pip / bot "CPU") is the PlayerPips overlay: it pops the moment the
	# goat becomes visible here, so the pop-in beat is unchanged (WK-10 replaces the 1s NameTag).

func _start_countdown() -> void:
	state = "COUNTDOWN"
	_state_t = 0.0
	_cd_beat = -1
	_mp_banner = []
	if _pending_match_point.size() > 0:   # announced at the next stage's countdown (spec §4)
		var names: Array[String] = []
		for i in _pending_match_point:
			names.append(player_name(int(i)))
		var c: Color = player_color(int(_pending_match_point[0])) if _pending_match_point.size() == 1 else Color.WHITE
		_mp_banner = ["MATCH POINT — " + " & ".join(names), c]
		_pending_match_point.clear()
		# WK-41: the stage intro card shares the top of the screen — the banner waits for it to leave
		# (it exits on the "3" beat, ~0.2 s). No card (tiebreaker / non-BRAWL) -> shown now, as before.
		if _intro_card == null or not _intro_card.is_showing():
			_flush_match_point_banner()

func _flush_match_point_banner() -> void:
	if _mp_banner.is_empty():
		return
	var txt: String = str(_mp_banner[0])
	var col: Color = _mp_banner[1]
	_mp_banner = []
	_hud.show_top(txt, col, 1.2)

func _tick_countdown(delta: float) -> void:
	_state_t += delta
	var beat := int(_state_t / Tuning.countdown_beat)
	if beat != _cd_beat and beat <= 2:
		if beat == 0 and _intro_card != null:
			_intro_card.exit()   # card pops out on the "3" beat (brief §1)
		_cd_beat = beat
		_hud.show_center(str(3 - beat), Color.WHITE, Tuning.countdown_beat)
		EventBus.countdown_tick.emit(3 - beat)   # audio: 3 / 2 / 1 beep
	if not _mp_banner.is_empty() and (_intro_card == null or not _intro_card.is_showing()):
		_flush_match_point_banner()   # WK-41: intro card gone -> the MATCH POINT line takes the top band
	if _state_t >= Tuning.countdown_beat * 3.0:
		_bounce_go()

## "BOUNCE!": physics + input enable for everyone on the same frame — the starting gun (spec §1).
func _bounce_go() -> void:
	state = "COMBAT"
	round_clock = 0.0
	combat_start_msec = Time.get_ticks_msec()
	_stage_start_scores = scores.duplicate()   # WK-21: lead-change baseline for this stage's score screen
	_flush_match_point_banner()   # WK-41 safety: never drop the announcement if the card outlived the countdown
	_cur_stats = {
		"stage_index": stage_index, "level_name": level_name,
		"kill_shape": _kill_shape,   # v2a §4b#1: QA aggregator selects K1 vs K1'/DC1/AS1 from THIS
		"length_s": 0.0, "end_cause": "none", "entered_sd": false,
		"kills": [], "survivor_had_contact": false, "supers_fired": [],
		"smashes": [],   # kill-zone spec §8: hit-solidity distribution + recovery correlation feed
		"self_ko_penalty": self_ko_penalty,   # WK-20c: the self-KO rule this stage was scored under (0 = Ra)
	}
	if _ghost_dir != null:
		_ghost_dir.on_combat_start(_cur_stats)   # WK-37: ghosts_mode / hush / cloud counters (ON / BAA ONLY only)
	for p in players:
		p.frozen = false
		p.fuel = Tuning.fuel_max   # every stage starts on a full tank
		# reset bot motion-health so its stuck/underside/blocked-ascent numbers are per-stage
		if is_instance_valid(p) and p.provider != null and p.provider.has_method("reset_motion_health"):
			p.provider.reset_motion_health()
	_wk95_reset_flight()
	if _pu_director != null:
		_pu_director.reset()       # first telegraph pu_first_spawn after BOUNCE! (spec §4)
	_hud.show_center("BOUNCE!", GOLD, BOUNCE_HOLD)
	if _legend != null:
		_legend.on_combat_started()   # legend lingers 4s into combat, then fades (brief §2)
	EventBus.combat_started.emit()   # audio: "BOUNCE!" starting gun
	_mode.on_combat_start(self)      # DROPSHOT serves the held ball toward the last scorer on GO
	# (identity pips settle to their in-combat alpha on their own off combat_start_msec — PlayerPips)

func _tick_combat(delta: float, rdelta: float) -> void:
	round_clock += delta   # stat only; gates nothing
	_wk95_tick_flight(delta)   # WK-95 §8.1 per-player flight telemetry (read-only)
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
			_smash_off_stage[vi] = not _stage_rect.grow(OFF_STAGE_GROW).has_point(victim.global_position)

func _on_super_fired(player, fuel_at_fire, aim_time, auto_fired) -> void:
	_mark_combat_active(players.find(player))   # camera action-cluster bias (camera_2x_policy §2)
	if _cur_stats.is_empty() or (state != "COMBAT" and state != "SUDDEN_DEATH"):
		return
	var who := players.find(player)
	var fired: Array = _cur_stats["supers_fired"]
	# WK-95 §8.1: where/how/why this super went. `vel` is the PRE-impulse velocity (the signal fires after
	# Player adds the impulse). purpose_bot = the InputBot's BR-7 tag (null for humans / scripted providers).
	var aim: Vector2 = player.get_super_aim_dir() if is_instance_valid(player) else Vector2.UP
	var sm: float = float(player.get("speed_mult")) if is_instance_valid(player) else 1.0
	var pre_v: Vector2 = player.velocity - aim * Tuning.super_boost_impulse_full * sm
	var purpose: Variant = null
	if is_instance_valid(player) and player.provider != null and player.provider.has_method("super_purpose_tag"):
		purpose = player.provider.super_purpose_tag()
	var rec := {
		"who": who, "fuel_at_fire": fuel_at_fire, "aim_time": aim_time, "auto_fired": auto_fired,
		"t": round_clock,
		"pos": player.global_position, "vel": pre_v, "aim_dir": aim, "purpose_bot": purpose,
		"landed": false, "geo_class": _wk95_geo_class(player, who, pre_v, aim, float(fuel_at_fire)),
	}
	fired.append(rec)
	if who >= 0 and who < _wk95_last_super.size():
		_wk95_last_super[who] = rec
		_wk95_super_t[who] = 0.0   # opens this player's super_path_px window

# ---------------------------------------------------------------- WK-95 §8.1 telemetry (QA feed)
# Read-only toward the sim. Classifies every super at fire time (geo_class) so QA can measure the
# super-as-movement share = (RECOVERY_UNNEEDED + TRAVERSAL) / all, and logs per-player flight use per stage.
const WK95_GEO_FUEL_PER_PX := 0.042    # spec §8.1: "no landing surface reachable at fuel / 0.042 px"
const WK95_ATTACK_RANGE := 1260.0      # spec §8.1 ATTACK: opponent within this and within WK95_ATTACK_CONE of aim
const WK95_ATTACK_CONE := 0.6
const WK95_DODGE_RANGE := 500.0        # spec §8.1 DODGE: a super-aiming opponent within this, aimed within cone at me
const WK95_DODGE_CONE := 0.5
const WK95_SMASHED_RECENT := 1.5       # s: "smashed <= 1.5 s ago" counts as danger
const WK95_SUPER_PATH_TAIL := 0.5      # s after super_active that still counts as super path
var _wk95_prev_pos: Array = []
var _wk95_super_t: Array = []          # per player: s since last super fire
var _wk95_last_smashed: Array = []     # per player: round_clock of the last qualifying smash received
var _wk95_last_super: Array = []       # per player: that player's last supers_fired record (for `landed`)

func _wk95_reset_flight() -> void:
	var fl: Array = []
	_wk95_prev_pos.clear()
	_wk95_super_t.clear()
	_wk95_last_smashed.clear()
	_wk95_last_super.clear()
	for i in range(players.size()):
		var p = players[i]
		fl.append({"who": i, "air_time": 0.0, "boost_time": 0.0, "boost_path_px": 0.0, "super_path_px": 0.0})
		_wk95_prev_pos.append(p.global_position if is_instance_valid(p) else Vector2.ZERO)
		_wk95_super_t.append(INF)
		_wk95_last_smashed.append(-INF)
		_wk95_last_super.append({})
	if not _cur_stats.is_empty():
		_cur_stats["flight"] = fl

## air_time = alive, un-frozen combat time (a bouncer is airborne except contact frames); boost_time = time
## with normal thrust firing; *_path_px = distance travelled while boosting / while super-active (+0.5 s).
func _wk95_tick_flight(delta: float) -> void:
	if _cur_stats.is_empty() or not _cur_stats.has("flight"):
		return
	var fl: Array = _cur_stats["flight"]
	for i in range(mini(players.size(), mini(fl.size(), _wk95_prev_pos.size()))):
		var p = players[i]
		if not is_instance_valid(p):
			continue
		var step: float = p.global_position.distance_to(_wk95_prev_pos[i])
		_wk95_prev_pos[i] = p.global_position
		if p.is_dead() or p.frozen or step > 400.0:   # 400 px in one tick = a respawn teleport, not motion
			continue
		var row: Dictionary = fl[i]
		_wk95_super_t[i] = float(_wk95_super_t[i]) + delta
		row["air_time"] = float(row["air_time"]) + delta
		if p.is_boosting():
			row["boost_time"] = float(row["boost_time"]) + delta
			row["boost_path_px"] = float(row["boost_path_px"]) + step
		if float(_wk95_super_t[i]) <= Tuning.super_active_time + WK95_SUPER_PATH_TAIL:
			row["super_path_px"] = float(row["super_path_px"]) + step

func _wk95_ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, Player.MASK_SURFACES)
	return get_world_2d().direct_space_state.intersect_ray(q)

func _wk95_radial(pos: Vector2) -> bool:
	var g: Vector2 = GravityField.get_gravity_at(pos)
	return g.length_squared() > 0.01 and g.normalized().y < 0.9

func _wk95_down(pos: Vector2) -> Vector2:
	var g: Vector2 = GravityField.get_gravity_at(pos)
	return g.normalized() if g.length_squared() > 0.01 else Vector2.DOWN

func _wk95_over_void(pos: Vector2) -> bool:
	var down := _wk95_down(pos)
	return _wk95_ray(pos - down * 40.0, pos + down * 2200.0).is_empty()

## Nearest landing point and its flight distance (flat frame: horizontal dx to the nearest floored column,
## the same measure the bot's _can_reach uses; radial frame: straight-line to the nearest spawn).
func _wk95_land_dist(pos: Vector2) -> Dictionary:
	if not _wk95_over_void(pos):
		return {"dist": 0.0, "point": pos + _wk95_down(pos) * 200.0}
	if _wk95_radial(pos):
		var best := Vector2.INF
		for s in _spawns:
			var sp: Vector2 = s
			if best == Vector2.INF or sp.distance_to(pos) < best.distance_to(pos):
				best = sp
		return {"dist": pos.distance_to(best) if best != Vector2.INF else INF, "point": best}
	var best_dx := INF
	var best_pt := Vector2.INF
	for dir in [-1.0, 1.0]:
		var x: float = pos.x
		for _k in range(70):
			x += dir * 100.0
			if x < bounds.position.x or x > bounds.end.x:
				break
			var hit := _wk95_ray(Vector2(x, pos.y - 40.0), Vector2(x, pos.y + 2200.0))
			if not hit.is_empty():
				if absf(x - pos.x) < best_dx:
					best_dx = absf(x - pos.x)
					best_pt = hit["position"]
				break
	return {"dist": best_dx, "point": best_pt}

func _wk95_geo_class(player, who: int, pre_v: Vector2, aim: Vector2, fuel: float) -> String:
	if not is_instance_valid(player):
		return "TRAVERSAL"
	var pos: Vector2 = player.global_position
	for q in players:
		if q == player or not is_instance_valid(q) or q.is_dead():
			continue
		var d: Vector2 = q.global_position - pos
		if d.length() <= WK95_ATTACK_RANGE and absf(aim.angle_to(d)) <= WK95_ATTACK_CONE:
			return "ATTACK"
	for q in players:
		if q == player or not is_instance_valid(q) or q.is_dead() or not q.is_super_aiming():
			continue
		var to_me: Vector2 = pos - q.global_position
		if to_me.length() <= WK95_DODGE_RANGE and absf(q.get_super_aim_dir().angle_to(to_me)) <= WK95_DODGE_CONE:
			return "DODGE"
	var smashed_recent: bool = who >= 0 and who < _wk95_last_smashed.size() \
		and round_clock - float(_wk95_last_smashed[who]) <= WK95_SMASHED_RECENT
	var danger: bool = _wk95_over_void(pos) or not _stage_rect.grow(440.0).has_point(pos) or smashed_recent
	if not danger:
		return "TRAVERSAL"
	var land := _wk95_land_dist(pos)
	var lp: Vector2 = land["point"]
	var out_speed := 0.0
	if lp != Vector2.INF and lp.distance_to(pos) > 1.0:
		out_speed = -pre_v.dot((lp - pos).normalized())
	var reachable: bool = float(land["dist"]) <= fuel / WK95_GEO_FUEL_PER_PX
	return "RECOVERY_NEEDED" if (out_speed > 1400.0 or not reachable) else "RECOVERY_UNNEEDED"

## Hit-solidity QA feed (kill-zone spec §8): one entry per qualifying smash. Read-only QA data.
func _on_smash_landed(attacker, victim, info: Dictionary) -> void:
	if _cur_stats.is_empty() or (state != "COMBAT" and state != "SUDDEN_DEATH"):
		return
	# WK-95 §8.1: danger memory (smashed <= 1.5 s ago) + `landed` on the attacker's in-window super record
	var wvi: int = players.find(victim) if victim != null else -1
	if wvi >= 0 and wvi < _wk95_last_smashed.size():
		_wk95_last_smashed[wvi] = round_clock
	var wai: int = players.find(attacker) if attacker != null else -1
	if wai >= 0 and wai < _wk95_last_super.size() and bool(info.get("by_super", false)):
		var srec: Dictionary = _wk95_last_super[wai]
		if not srec.is_empty() and round_clock - float(srec.get("t", -INF)) <= Tuning.super_active_time + 0.05:
			srec["landed"] = true
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
	var rec: Dictionary = {}
	if not _cur_stats.is_empty():
		var ki: int = players.find(attacker) if attacker != null else -1
		var kills: Array = _cur_stats["kills"]
		rec = {
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
		}
		kills.append(rec)
		_cur_stats["end_cause"] = str(cause)   # the stage-deciding death overwrites last
	# kill credit vs suicide (spec §2), delegated to the mode's scoring hook. Every cause counts; dead
	# attackers still score ("beyond the grave"); being killed is never -1; a self-KO costs self_ko_penalty
	# (WK-20c: 0 by default). Score is CUMULATIVE kills.
	var ai: int = players.find(attacker) if attacker != null else -1
	var scores_before: Array = scores.duplicate()
	# WK-37 K-2 HAUNTED: no credited attacker + the victim's last surface contact (<= ghost_puff_fence_s) was a ghost
	# cloud -> the death costs nothing (no self-KO penalty, no self-KO tally) and credits nobody. Living credit stands
	# (K-3): a credited kill is never haunted. Ghosts never appear as attackers (K-1). OFF: _ghost_dir is null.
	var haunted: bool = _ghost_dir != null and not (ai >= 0 and ai != idx) and _ghost_dir.is_haunted(idx)
	if _ghost_dir != null and not rec.is_empty():
		rec["haunted"] = haunted
		rec["dt_last_cloud_contact"] = _ghost_dir.dt_last_cloud_contact(idx)
	if not haunted:
		_mode.on_kill(self, ai, idx, cause)
	# WK-25: what this KO actually did to the score (the ScoreScreen kill list + the credit pop read it)
	var credited: bool = ai >= 0 and ai != idx
	var ko_cost: int = 0 if credited else int(scores_before[idx]) - int(scores[idx])
	if not rec.is_empty():
		rec["credited"] = credited
		rec["self_ko_cost"] = ko_cost   # points the self-KO took (0 under Ra, or a -1 floored at 0)
	_credit_pop(victim, ai, idx, credited, ko_cost, scores_before, haunted)
	# FIRST BLOOD is a BRAWL kill-race moment — never in SPORTS (rocketball/dropshot), where knocking
	# a rival out of bounds is incidental, not the point (owner 2026-07-19: "killing each other is not the point").
	if ai >= 0 and ai != idx and not _first_blood_fired \
			and not (_config != null and SportsMode.is_sports_mode(_config.mode_id)) \
			and _attribution_mode():   # WK-137: BRAWL only — never Trials (co-op: a fall after a head-bounce credited the partner)
		_first_blood_fired = true
		_hud.show_top("FIRST BLOOD!", player_color(ai), 1.0)
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
		if _ghost_dir != null:
			_ghost_dir.on_eliminated(idx, victim)   # WK-37: a ghost rises ghost_spawn_delay later (cancelled by SD/stage end)
		# simultaneous-ELIMINATION grouping for the double-KO SD (spec §5)
		if _recent_dead.size() > 0 and (round_clock - _last_death_clock) <= Tuning.double_ko_window:
			_recent_dead.append(victim)
		else:
			_recent_dead = [victim]
		_last_death_clock = round_clock
	var ne := _not_eliminated_count()
	if ne == 2 and not _two_left_fired and _stage_start_alive >= 3 and _attribution_mode():   # WK-137: BRAWL only
		_two_left_fired = true
		_hud.show_top("TWO LEFT!", Color.WHITE, 1.0)
		EventBus.two_left.emit()   # audio: tension announcer
	if ne == 0:
		_end_check = -1.0
		_decide_stage_end(false)   # nobody left — decide immediately (double-KO SD or NOBODY SURVIVES)
	elif ne == 1:
		_end_check = Tuning.double_ko_window   # the survivor might still be mid-double-KO

## WK-25 KO CREDIT POP (audit D-02 part 1) — BRAWL only (the kill race; SPORTS/TRIALS have no MatchHUD pop).
## Credited: "+1" in the killer's colour into the killer's card. Uncredited: "OOPS!" (WK-20c Ra, costs 0) or "−N"
## when the SELF-KO −1 rule really took a point, in the victim's colour onto the victim's card. Transient, change
## only — never a total (owner 2026-07-16). Starts on the KO edge blast (KOEdgeBlast.locate).
func _credit_pop(victim, ai: int, idx: int, credited: bool, ko_cost: int, scores_before: Array, haunted := false) -> void:
	if not _attribution_mode() or _hud == null or not _hud.has_method("credit_pop"):
		return
	var loc: Dictionary = _ko_blast.locate(victim) if _ko_blast != null else {}
	var meta := {"killer": ai, "victim": idx, "credited": credited,
		"score_before": scores_before.duplicate(), "score_after": scores.duplicate()}
	if credited:
		_hud.credit_pop(ai, "plus", "+%d" % maxi(1, int(scores[ai]) - int(scores_before[ai])), player_color(ai), loc, meta)
	elif ko_cost > 0:
		_hud.credit_pop(idx, "minus", "−%d" % ko_cost, player_color(idx), loc, meta)
	elif haunted:
		_hud.credit_pop(idx, "oops", "HAUNTED!", player_color(idx), loc, meta)   # WK-37 K-2: costs nothing
	else:
		_hud.credit_pop(idx, "oops", "OOPS!", player_color(idx), loc, meta)

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
		# mode seam (owner 2026-07-18): SPORTS respawns on the player's TEAM side; null -> default.
		var rp: Variant = _mode.respawn_position(self, i)
		p.respawn(rp if rp is Vector2 else _spawn_at(i))
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
	EventBus.combat_ended.emit()   # lethal hazards go inert (frozen survivors are safe during the freeze)
	# the double-KO wait already elapsed since the last death — it counts as freeze time
	_state_t = Tuning.double_ko_window if deferred else 0.0
	# finalize the round_stats record
	_stage_kills = (_cur_stats.get("kills", []) as Array).duplicate(true) if not _cur_stats.is_empty() else []
	if not _cur_stats.is_empty():
		_cur_stats["length_s"] = round_clock
		_cur_stats["survivor_had_contact"] = _stage_winner >= 0 \
			and _stage_winner < _had_contact.size() and _had_contact[_stage_winner]
		_cur_stats["motion_health"] = bot_motion_health()   # process gate: per-stage locomotion pathologies
		if _ghost_dir != null:
			_ghost_dir.finalize_stats(_cur_stats)   # WK-37 §8.2 ghost telemetry
		round_stats.append(_cur_stats)
		_cur_stats = {}
	if _ghost_dir != null:
		_ghost_dir.on_stage_end()   # WK-37: ghosts hold still and fade with the KO freeze; clouds go
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
	# WK-41: fit the banner (pop-in 0.15 + hold + pop-out 0.2) into what is LEFT of the freeze, so it has fully
	# popped out when the score screen arrives. A deferred end already spent double_ko_window of the freeze, and
	# the full-length banner used to be cut mid-hold by the score screen. round_end_freeze itself is unchanged.
	var sub: String = str(banner.get("subline", _deltas_line()))   # BRAWL: KO tally + survivor (WK-15 / D-04)
	_hud.show_center(txt, col, maxf(0.05, _mode.stage_end_freeze(self) - _state_t - 0.35), sub)   # WK-124 seam
	_hud.animate_scores(scores.duplicate())
	# WK-41 (BRAWL ceremony path only): the stage is over, so drop stale top-band announcer lines (TWO LEFT!, a
	# queued FIRST BLOOD!). They would sit on top of the STAGE_END banner. The audio announcer is unaffected.
	if _score_screen != null and _hud.has_method("clear_top"):
		_hud.clear_top()
	# instrumentation: last death -> STAGE_END (the double-KO wait, spent in COMBAT) for the between-stage report
	if not phase_log.is_empty() and last_death_msec > 0:
		phase_log[phase_log.size() - 1]["since_death_s"] = float(Time.get_ticks_msec() - last_death_msec) / 1000.0

func _tick_stage_end(delta: float) -> void:
	_state_t += delta
	if _state_t < _mode.stage_end_freeze(self):   # WK-124 seam (default Tuning.round_end_freeze)
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
	# between-stage score screen (owner 2026-07-16): BRAWL detours through SCOREBOARD before the
	# next level loads; every other mode goes straight to the next stage exactly as before.
	if _score_screen != null:
		_enter_scoreboard()
	else:
		_begin_stage()

## SCOREBOARD (owner 2026-07-16): the brief Duck-Game-style tally between stages. Rows carry each
## player's cumulative kills + this stage's delta (same survivor display-floor rule as the old
## deltas banner line). WK-21: auto-advances after an ADAPTIVE hold (Tuning.score_hold_normal, or
## Tuning.score_hold_dramatic on a lead change / newly-reached match point / tiebreaker). A FRESH accept or
## FLY from a joined device skips after Tuning.scoreboard_skip_guard (WK-11 MenuInputGate; combat mashing or a
## held boost never skips it). WK-41: the fade-out runs inside the hold, and the next stage (with its intro
## card) loads only after the fade, so the two overlays never share a frame.
func _enter_scoreboard() -> void:
	if _ghost_dir != null:
		_ghost_dir.clear_all()   # WK-37: ghosts/clouds are gone before the ScoreScreen (spec §7 / T7)
	state = "SCOREBOARD"
	_state_t = 0.0
	_score_leave_t = -1.0
	score_hold_reason = _compute_hold_reason()
	score_hold = Tuning.score_hold_normal if score_hold_reason == "normal" else Tuning.score_hold_dramatic
	if not phase_log.is_empty():
		var e: Dictionary = phase_log[phase_log.size() - 1]
		e["score_hold"] = score_hold
		e["hold_reason"] = score_hold_reason
		e["skipped"] = false
	_hud.hide_center()
	if _hud.has_method("clear_top"):
		_hud.clear_top()
	var rows: Array = []
	for i in range(players.size()):
		var d: int = stage_display_delta(i)   # SD survivor display floor (parity with _deltas_line)
		rows.append({
			"pn": i + 1,
			"name": player_name(i),    # WK-88 (CC-8.5): "P3" / "VEX"
			"sub": player_subtag(i),   # small tag: goat name for a human / "CPU"
			"color": player_color(i),  # WK-08: the goat's colour
			"skin": (players[i].skin if is_instance_valid(players[i]) else "pink"),
			"score": int(scores[i]),
			"delta": d,
			"oops": stage_display_oops(i),   # WK-20c: non-scoring self-KO chip ("OOPS!") when delta is 0
		})
	_score_screen.present(rows, match_target_kills, _kill_list_entries())
	_score_screen.set_countdown(1.0)
	_score_skip = false
	if _score_gate != null:
		_score_gate.open(Tuning.scoreboard_skip_guard)

## WK-25 (audit D-02 part 3): who KO'd whom this stage, in order, for the ScoreScreen kill list. CC-8.5 names +
## identity colours + goat skins. kind: "ko" (credited), "oops" (self-KO that cost nothing, WK-20c Ra) or "minus"
## (the SELF-KO −1 rule took `cost` points).
func _kill_list_entries() -> Array:
	var out: Array = []
	for r in _stage_kills:
		var rd: Dictionary = r
		var v: int = int(rd.get("victim", -1))
		var ki: int = int(rd.get("killer", -1))
		if v < 0 or v >= players.size():
			continue
		var credited: bool = bool(rd.get("credited", ki >= 0 and ki != v))
		var e := {"v_name": player_name(v), "v_color": player_color(v), "v_skin": _skin_of(v)}
		if credited and ki >= 0 and ki < players.size():
			e["kind"] = "ko"
			e["k_name"] = player_name(ki)
			e["k_color"] = player_color(ki)
			e["k_skin"] = _skin_of(ki)
		else:
			var cost: int = int(rd.get("self_ko_cost", 0))
			e["kind"] = "minus" if cost > 0 else "oops"
			e["cost"] = cost
		out.append(e)
	return out

func _skin_of(i: int) -> String:
	return str(players[i].skin) if i >= 0 and i < players.size() and is_instance_valid(players[i]) else "pink"

## WK-21 dramatic-hold test, in priority order. "lead_change" = the leader SET (everyone tied at the top score,
## top score > 0) differs from this stage's BOUNCE! baseline, and there WAS a leader before. A first lead out of
## 0-0 is NOT a lead change; a tie for the lead, or breaking one, IS. "match_point" = someone newly reached
## target-1 this stage (the same set the next countdown announces).
func _compute_hold_reason() -> String:
	if _tiebreaker_next:
		return "tiebreaker"
	if _pending_match_point.size() > 0:
		return "match_point"
	var before: Array = _leader_set(_stage_start_scores)
	if not before.is_empty() and before != _leader_set(scores):
		return "lead_change"
	return "normal"

func _leader_set(arr: Array) -> Array:
	var best := 0
	for s in arr:
		best = maxi(best, int(s))
	var out: Array = []
	if best <= 0:
		return out
	for i in range(arr.size()):
		if int(arr[i]) == best:
			out.append(i)
	return out

func _tick_scoreboard(delta: float) -> void:
	_state_t += delta
	var fade: float = Tuning.scoreboard_fade_out
	if _score_leave_t < 0.0:
		_score_screen.set_countdown(1.0 - _state_t / maxf(score_hold - fade, 0.01))   # ring empties as the fade starts
		# auto path: start the fade `fade` before the hold ends, so the whole screen takes exactly score_hold
		if _score_skip or _state_t >= score_hold - fade:
			if _score_skip and not phase_log.is_empty():
				phase_log[phase_log.size() - 1]["skipped"] = true
			_score_skip = false
			_score_leave_t = _state_t
			if _score_gate != null:
				_score_gate.close()
			_score_screen.dismiss()
		return
	# WK-41: only after the fade has finished does the next stage load and its intro card appear
	if _state_t >= _score_leave_t + fade:
		_begin_stage()

func _enter_match_end(widx: int) -> void:
	state = "MATCH_END"
	EventBus.combat_ended.emit()   # lethal hazards go inert for the winner bow / prompt
	_state_t = 0.0
	_match_winner = widx
	_prompt_shown = false
	_record_progression(widx)   # v6 §4: unlock-progression trigger (BRAWL circuit matches only)
	_record_sports_progression(widx)   # v8 §4.3: Sports court unlock trigger (SPORTS matches only)
	_record_kill_bank()   # v11 §5.1: bank raw credited human KOs (ALL finished BRAWL matches)
	# finalize any in-flight stage record so QA can read the winning stage
	if not _cur_stats.is_empty():
		_cur_stats["length_s"] = round_clock
		_cur_stats["motion_health"] = bot_motion_health()
		if _ghost_dir != null:
			_ghost_dir.finalize_stats(_cur_stats)   # WK-37 §8.2 ghost telemetry
		round_stats.append(_cur_stats)
		_cur_stats = {}
	if _ghost_dir != null:
		_ghost_dir.on_stage_end()      # WK-37: freeze + fade; the ceremony clears them (below)
		_ghost_dir.remove_ghost(widx)  # a winner on points while dead is respawned for the bow — never two of them
	var w = players[widx]
	if is_instance_valid(w):
		if w.is_dead():   # won on points while dead — bring them back for the bow
			w.respawn(_spawn_at(widx))
			w.frozen = true
			_hud.set_dead(widx, false)
		w.play_win_pop()
		_camera.set_frame(w.global_position, MATCH_END_ZOOM)   # punch-zoom (FEEL §7)
	# freeze the field: live bots bouncing behind the victory ceremony are visual noise (graded
	# from the first rendered pass). The winner's bow pose stays; _start_match respawns everyone.
	for p in players:
		if is_instance_valid(p) and not p.is_dead():
			p.frozen = true
	EventBus.match_won.emit(widx)   # audio: win fanfare + scoreboard music
	if _victory != null:
		# VICTORY CEREMONY (brief §3): the arena beat breathes first (punch-zoom stays visible),
		# then the ceremony takes over. It owns input from here; _tick_match_end defers to it.
		var rows: Array = []
		for i in range(players.size()):
			rows.append({
				"pn": i + 1,
				"name": player_name(i),    # WK-88 (CC-8.5)
				"sub": player_subtag(i),
				"label": player_label(i),
				"color": player_color(i),
				"skin": (players[i].skin if is_instance_valid(players[i]) else "pink"),
				"score": int(scores[i]),
				"human": is_instance_valid(players[i]) and players[i].is_in_group("human"),
			})
		var winner := {
			"pn": widx + 1,
			"name": player_name(widx),
			"sub": player_subtag(widx),
			"label": player_label(widx),
			"skin": (players[widx].skin if is_instance_valid(players[widx]) else "pink"),
			"color": player_color(widx),
			"human": is_instance_valid(players[widx]) and players[widx].is_in_group("human"),
		}
		var tgt := match_target_kills
		get_tree().create_timer(VICTORY_DELAY).timeout.connect(func() -> void:
			if state == "MATCH_END" and _victory != null:
				if _ghost_dir != null:
					_ghost_dir.clear_all()   # WK-37: no ghost survives into the ceremony
				_victory.present(winner, rows, tgt))
	else:
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
	# v11 §5.1(1): kill-banking moved OUT of here (see _record_kill_bank) — this records circuit
	# mastery/pity only, exactly as before, so the CD progression guard is untouched.
	var human_won: bool = widx >= 0 and widx < _config.human_count
	Settings.record_match_result(str(_config.circuit_id), human_won)

## v11 §5.1 kill bank: at MATCH_END of EVERY finished BRAWL match (RANDOM / SINGLE / CIRCUIT alike),
## bank the human slots' RAW credited-kill tallies into Settings.total_kills (the cosmetic-flair
## currency). Raw tally, not `scores` — a self-fall can never erase a banked notch (§5.1(2)). No-op
## for every non-BRAWL mode (Sports/Gauntlet/Trials never feed the ladder, §2.1); quit/abandoned
## matches never reach MATCH_END so they bank nothing.
func _record_kill_bank() -> void:
	if _config == null or _config.mode_id != &"brawl":
		return
	var k := 0
	for i in range(mini(_config.human_count, raw_kills.size())):
		k += int(raw_kills[i])
	Settings.record_brawl_kills(k)

## v8_sports_courts.md §4.3 unlock trigger: record a finished SPORTS match into Settings progression
## (bumps sports_matches; a HUMAN win bumps sports_wins -> the chaos-finale gate). No-op for every
## non-SPORTS mode (they never touch Sports progression). Mirrors _record_progression.
func _record_sports_progression(widx: int) -> void:
	if _config == null or not SportsMode.is_sports_mode(_config.mode_id):
		return
	var human_won: bool = widx >= 0 and widx < _config.human_count
	Settings.record_sports_result(human_won)

func _tick_match_end(delta: float) -> void:
	_state_t += delta
	if _victory != null:
		return   # the VictoryScreen owns MATCH_END input (its signals drive rematch/setup/menu)
	if _state_t < PROMPT_GUARD:   # 1s input guard so nobody skips the screen by accident
		return
	if not _prompt_shown:
		_prompt_shown = true
		# Real focusable button row (VictoryScreen bar) — the HUD owns the row's input from here;
		# _on_match_button (wired once at HUD creation) turns a press into the actual action.
		_hud.show_match_buttons(_match_end_specs())

## Sports/Trials match-end button spec. TRIALS is co-op completion -> PLAY AGAIN; versus modes ->
## REMATCH. QUIT TO MENU is always LAST (the safe menu_back target). Handlers mirror VictoryScreen.
func _match_end_specs() -> Array:
	var first := {"text": "REMATCH", "id": &"rematch"}
	if _config != null and _config.mode_id == &"trials":
		first = {"text": "PLAY AGAIN", "id": &"rematch"}
	return [
		first,
		{"text": "CHANGE SETUP", "id": &"setup"},
		{"text": "QUIT TO MENU", "id": &"menu"},
	]

## Row-button activation (Sports/Trials). Reuses the exact handlers behind the old key hints:
## rematch = _start_match; setup = resume-setup + shell; menu = shell (v1_frontend_shell §9 C9).
func _on_match_button(id: StringName) -> void:
	if state != "MATCH_END":
		return
	match id:
		&"rematch":
			_start_match()
		&"setup":
			GameConfig.resume_setup = true
			get_tree().change_scene_to_file(SHELL_SCENE)
		&"menu":
			get_tree().change_scene_to_file(SHELL_SCENE)

## The `pause` action (pad Start/Menu [6] · keyboard Esc / P) during a live match opens the PauseMenu
## overlay (COUCH_CONVENTIONS CC-1.1 / audit C-01+C-02). Gameplay NEVER reads `menu_back` here: pad B is
## `use_powerup`, and B-pauses-the-game was the owner's #1 complaint. MATCH_END is handled by
## _tick_match_end (its menu_back = QUIT-to-menu), so ignore it here.
func _unhandled_input(e: InputEvent) -> void:
	if state == "MATCH_END" or state == "BOOT":
		return
	if e.is_action_pressed(&"pause") and not e.is_echo() and not is_instance_valid(_pause_overlay):
		get_viewport().set_input_as_handled()
		# owner = the device that pressed pause, keyed by event class (CC-3.2) via the router
		_open_pause(InputRouter.device_key(e))

## owner_key = the device that pressed pause; only it drives the menu (CC-1.5). "" = any device.
func _open_pause(owner_key: String = "") -> void:
	_pause_overlay = PAUSE_SCENE.instantiate()
	add_child(_pause_overlay)
	if _pause_overlay.has_method("setup"):
		_pause_overlay.setup(self, owner_key)
	get_tree().paused = true

## Called by PauseMenu right after it unpauses (RESUME / Start / B). CC-5.7 + audit C-19: the button that
## closed the menu is usually still held — every human provider ignores boost/super/powerup until that
## button has been RELEASED once, so A-resume never boosts and B-resume never fires a powerup.
func on_pause_resumed() -> void:
	for p in players:
		if is_instance_valid(p) and p.provider != null and p.provider.has_method("swallow_until_release"):
			p.provider.swallow_until_release()

## WK-09 (CC-1.5 / CC-7.2): who owns a pause opened by device `key` — {index, label, color, skin}, or {} for
## a device that drives no human (the header then reads plain "PAUSED"). Humans-first: human h = player h.
## Fallback (BACKLOG WK-09 deps): the keyboard / an unkeyed pause belongs to P1 when no human is bound to it.
func pause_owner_info(key: String) -> Dictionary:
	var h: int = human_index_for_device(key)
	if h < 0 and (key == InputRouter.KB or key == ""):
		h = 0
	if not is_human_player(h):
		return {}
	return {"index": h, "label": player_label(h), "color": player_color(h), "skin": str(players[h].skin)}

## WK-09 (CC-7.2) pause context line: "BRAWL · DAISY RING · FIRST TO 10" + compact score chips
## [{text, color}] — per-player KOs (Brawl), team goals (Sports), the stage number (Trials).
func pause_context() -> Dictionary:
	var parts: Array[String] = []
	if _mode != null and str(_mode.display_name()) != "":
		parts.append(str(_mode.display_name()))
	if level_name != "":
		parts.append(level_name.to_upper())
	var chips: Array = []
	if _mode != null and _mode.has_method("team_scores"):
		var ts: Array = _mode.team_scores()
		for t in range(ts.size()):
			chips.append({"text": "%s %d" % [str(_mode.team_name(t)), int(ts[t])], "color": _mode.team_color(t)})
	elif _config != null and _config.mode_id == &"trials":
		chips.append({"text": "STAGE %d" % maxi(1, stage_index), "color": GOLD})
	else:
		parts.append("FIRST TO %d" % match_target_kills)
		for i in range(players.size()):
			var sc: int = int(scores[i]) if i < scores.size() else 0
			chips.append({"text": "%s  %d" % [player_name(i), sc], "color": player_color(i)})   # CC-8.5 NAME
	return {"line": "  ·  ".join(parts), "chips": chips}

## WK-80(f): the pause hosts Options full-screen; the corner HUD cards / controls legend must not show
## through behind its BACK button + hint bar. Presentation only (INV-12): toggles CanvasLayer visibility.
func set_match_overlays_hidden(hidden: bool) -> void:
	for n in [_hud, _legend]:
		if n == null or not is_instance_valid(n) or not (n is CanvasLayer):
			continue
		var cl := n as CanvasLayer
		if hidden:
			cl.set_meta("vis_before_options", cl.visible)   # the legend may already have hidden itself
			cl.visible = false
		elif cl.has_meta("vis_before_options"):
			cl.visible = bool(cl.get_meta("vis_before_options"))
			cl.remove_meta("vis_before_options")

func _deltas_line() -> String:
	var parts: Array[String] = []
	for i in range(_stage_deltas.size()):
		var d: int = stage_display_delta(i)
		if d != 0:
			parts.append("%s %+d" % [player_name(i), d])
		elif stage_display_oops(i):
			parts.append("%s OOPS!" % player_name(i))   # WK-20c: a self-KO that cost nothing (Ra default)
	return "  ·  ".join(parts)

## WK-20c (Ra): true when player i self-KO'd this stage under the default rule (self-KO costs 0). Under the
## "SELF-KO -1" toggle this is always false and the line keeps today's text (a -1 floored at 0 shows nothing).
## Shown only when there is no scoring delta to show, so a KO-er who later fell off still reads "+1". The SD
## revived survivor is skipped (same display floor as stage_display_delta: "P1 SURVIVED · P1 OOPS!" reads wrong).
func stage_display_oops(i: int) -> bool:
	if self_ko_penalty > 0 or i < 0 or i >= _stage_self_kos.size():
		return false
	if int(_stage_self_kos[i]) <= 0 or stage_display_delta(i) != 0:
		return false
	return not (_revived_this_stage and i == _stage_winner)

## Player i's stage delta AS DISPLAYED. SD display fix (pacing6): on a sudden-death stage the announced
## SURVIVOR lost their last life into the double-KO and was revived, so their true net stage delta can be
## negative — a "P1 SURVIVED · P1 -1" line reads wrong. Floor the SURVIVOR's own displayed delta to >= 0 (a 0
## suppresses it from the line). DISPLAY ONLY — cumulative scores & kill-credit are untouched.
func stage_display_delta(i: int) -> int:
	if i < 0 or i >= _stage_deltas.size():
		return 0
	var d: int = _stage_deltas[i]
	if _revived_this_stage and i == _stage_winner and d < 0:
		d = 0
	return d

func _scoreline() -> String:
	var parts: Array[String] = []
	for i in range(scores.size()):
		parts.append("%s %d" % [player_name(i), int(scores[i])])
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

# ------------------------------------------------------------------- player identity (WK-08 / WK-10)

## WK-08 (CC-8.3): THE identity colour of player i = the colour of the goat skin they actually wear
## (PlayerIdentity.SKIN_COLORS). Sports team colourway skins therefore colour their wearer automatically.
## Every identity surface reads this: HUD card, pip, chevron, banners, ScoreScreen, VictoryScreen.
func player_color(i: int) -> Color:
	if i >= 0 and i < players.size() and is_instance_valid(players[i]):
		var skin: String = str(players[i].skin)
		if PlayerIdentity.has_skin(skin):
			return PlayerIdentity.color_for_skin(skin)
	if i < 0:
		return Color.WHITE
	return PLAYER_COLORS[i % PLAYER_COLORS.size()]

## WK-23/24: identity colour of a Player node (player_color of its index). A node not in `players`
## (should not happen) falls back to its skin colour.
func color_of_player(p) -> Color:
	var i := players.find(p)
	if i >= 0:
		return player_color(i)
	if p != null and is_instance_valid(p) and "skin" in p:
		return PlayerIdentity.color_for_skin(str(p.skin))
	return Color.WHITE

## WK-24: is this player off-stage (outside the platform union grown by OFF_STAGE_GROW)? Same rule as
## the round_stats off_stage flag. Read by Player's last-touch ring.
func is_off_stage(p) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	return not _stage_rect.grow(OFF_STAGE_GROW).has_point(p.global_position)

## WK-23/24: kill-credit presentation (edge KO blast + last-touch ring) runs in the BRAWL kill race only.
## SPORTS: knocking a rival out is incidental (owner 2026-07-19); TRIALS: solo courses.
func _attribution_mode() -> bool:
	return _config == null or _config.mode_id == &"brawl"

func ko_blast_enabled() -> bool:
	return _attribution_mode()

## WK-37: ghost goats run in the BRAWL kill race only (SPORTS respawns everyone, TRIALS never eliminates) and only
## when the RULES option is not OFF.
func _ghosts_enabled() -> bool:
	return _config != null and _config.mode_id == &"brawl" and int(_config.ghosts) != MatchConfig.Ghosts.OFF

## QA (gbplay eval): the GhostDirector (null when ghosts are OFF / not BRAWL).
func ghost_director():
	return _ghost_dir

## player_color for every current player, in player order (HUD / chevron setup).
func player_colors() -> Array:
	var out: Array = []
	for i in range(players.size()):
		out.append(player_color(i))
	return out

func is_human_player(i: int) -> bool:
	return i >= 0 and i < players.size() and is_instance_valid(players[i]) and players[i].is_in_group("human")

## WK-10: the lobby P-number of player i (MatchConfig.human_labels: "P3" stays P3 even if P2's slot was
## empty), or 0 for a bot. Humans-first invariant: human index h = count of humans before i.
func player_label(i: int) -> int:
	if not is_human_player(i):
		return 0
	var h := 0
	for k in range(i):
		if is_human_player(k):
			h += 1
	return _config.label_for(h) if _config != null else h + 1

## WK-10 identity KIND: "P3" for a human (lobby label), "CPU" for a bot (CC-8.3: never "P3" for a bot).
## QA / legacy only — WK-88: no player-facing surface prints this any more; display text is player_name(i)
## (+ player_subtag(i) where a second token fits). See COUCH_CONVENTIONS CC-8.5.
func player_tag(i: int) -> String:
	var n: int = player_label(i)
	return ("P%d" % n) if n > 0 else "CPU"

func player_tags() -> Array:
	var out: Array = []
	for i in range(players.size()):
		out.append(player_tag(i))
	return out

## WK-88 / COUCH_CONVENTIONS CC-8.5 — THE one name of fighter i, on EVERY surface (HUD card, pip, banners,
## MATCH POINT, delta/score lines, ScoreScreen, Victory, pause chips): humans "P3" (lobby label); a CPU is
## named by its goat ("VEX") so two CPUs stay distinguishable and the card matches the banner. Colour =
## player_color(i). "CPU" is never a name — it is the CPU's sub-tag (player_subtag).
func player_name(i: int) -> String:
	if is_human_player(i):
		return player_tag(i)
	if i >= 0 and i < players.size() and is_instance_valid(players[i]):
		return PlayerIdentity.name_for_skin(str(players[i].skin))
	return "CPU"

## CC-8.5 secondary token, printed small right after / under the name wherever a second token fits (HUD card,
## ScoreScreen row, Victory ribbon + rows, a CPU's intro pip): a human's goat name ("POGO"), or "CPU".
## Never shown alone and never instead of player_name. One-line announcer text omits it.
func player_subtag(i: int) -> String:
	if is_human_player(i):
		return PlayerIdentity.name_for_skin(str(players[i].skin))
	return "CPU"

func player_names() -> Array:
	var out: Array = []
	for i in range(players.size()):
		out.append(player_name(i))
	return out

func player_subtags() -> Array:
	var out: Array = []
	for i in range(players.size()):
		out.append(player_subtag(i))
	return out

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
		_camera.set_frame(fr.get_center(), _fixed_framing_zoom(fr))   # WK-148b: same fit, now shared with the stage-start snap
		return
	# --- OWNER RULES framing (docs/feedback/owner_2026-07-10_camera_rules.md) ---
	# The action-cluster/weights/velocity-lead machinery is GONE: the frame targets the midpoint of
	# the extreme players' bounds-clamped positions and the zoom fits every clamped position. A
	# stable, player-extremes-only target is what makes the motion calm — it moves only when the
	# extremes move, so the frame cannot "fly left and right" on membership or weight changes.

	# living fighters this tick (is_dead()==false covers hitstun/recovery)
	var living: Array = []
	for p in players:
		if is_instance_valid(p) and not p.is_dead():
			living.append(p)
	if living.is_empty():
		return   # nothing to frame — hold the last frame

	# RULE 3: each player contributes their position CLAMPED to camera_bounds — a player beyond the
	# bounds pulls the frame only as far as the bound edge (off-screen-kill space stays off-screen,
	# and their edge chevron marks them). RULE 2 follows by construction: the frame FITS every
	# clamped position, so an in-bounds player is always inside the target frame.
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in living:
		var cp: Vector2 = (p.global_position as Vector2).clamp(camera_bounds.position, camera_bounds.end)
		mn = mn.min(cp)
		mx = mx.max(cp)
	# Mode focus points (owner 2026-07-19): a mode may add world points the frame must also contain —
	# TRIALS returns the objective (goal gate / goal zone + ball / un-landed pads) so the player can
	# always see the target. Clamped like player positions; [] leaves the framing byte-for-byte.
	for fp in _mode.camera_focus_points(self):
		var cfp: Vector2 = (fp as Vector2).clamp(camera_bounds.position, camera_bounds.end)
		mn = mn.min(cfp)
		mx = mx.max(cfp)
	var centroid := (mn + mx) * 0.5          # midpoint of extremes, X and Y (rule 3)
	var ext := (mx - mn) * 0.5 + CAM_MARGIN  # breathing room (rule 4 aesthetics, not a bias)

	# RULE 2 zoom: fit every clamped position + margin. NO readability floor — the camera zooms out
	# as far as the level's own camera bounds require, and clamped positions bound how far that is.
	var z := minf(1920.0 / maxf(2.0 * ext.x, 1.0), 1080.0 / maxf(2.0 * ext.y, 1.0))
	# RULE 6 zoom-in cap: never closer than showing cam_close_fraction of the camera-bounds extent,
	# and never past the absolute CAM_MAX_ZOOM ceiling (which binds only on tiny arenas).
	var close_w: float = maxf(camera_bounds.size.x * Tuning.cam_close_fraction, 1.0)
	var close_h: float = maxf(camera_bounds.size.y * Tuning.cam_close_fraction, 1.0)
	var z_cap := minf(minf(1920.0 / close_w, 1080.0 / close_h), CAM_MAX_ZOOM)
	z = minf(z, z_cap)

	# Outer guard: keep the visible rect inside the KILL bounds (never reveal past the blast lines).
	# The clamped midpoint already keeps the target inside camera_bounds; this only binds when the
	# viewport at this zoom is wider than the kill box itself.
	var half := Vector2(1920.0, 1080.0) / (2.0 * z)
	var cx: float = centroid.x
	var cy: float = centroid.y
	if bounds.size.x > 2.0 * half.x:
		cx = clampf(cx, bounds.position.x + half.x, bounds.end.x - half.x)
	else:
		cx = bounds.get_center().x
	if bounds.size.y > 2.0 * half.y:
		cy = clampf(cy, bounds.position.y + half.y, bounds.end.y - half.y)
	else:
		cy = bounds.get_center().y
	_camera.set_frame(Vector2(cx, cy), z)

## WK-148b: the stage-start camera snap (_ready + every _begin_stage: match start, each sports goal's STAGE_INTRO,
## Pause->RESTART's reload, REMATCH). A mode with FIXED framing (SPORTS -> the court) snaps straight to the zoom/centre
## _update_camera eases to, so the first drawn frame is already the court (it used to snap to CAM_MAX_ZOOM and ease out
## for ~15 frames, which WK-148's MatchCover hid). Modes without fixed framing (BRAWL/TRIALS/GAUNTLET: camera_framing
## returns null) keep the exact old snap. Framing rules are untouched: this only changes where the smoothing starts.
func _snap_camera_stage_start() -> void:   # WK-148b
	var framing: Variant = _mode.camera_framing(self) if (_mode != null and Tuning.cam_sports_start_snap) else null   # WK-148b
	if framing is Rect2:   # WK-148b
		var fr: Rect2 = framing   # WK-148b
		_camera.snap_to(fr.get_center(), _fixed_framing_zoom(fr))   # WK-148b
	else:   # WK-148b
		_camera.snap_to(_stage_rect.get_center(), CAM_MAX_ZOOM)   # WK-148b: unchanged pre-WK-148b behaviour

## The zoom that fits a mode's fixed-framing rect to the 1920x1080 view (shared by _update_camera and the WK-148b snap).
func _fixed_framing_zoom(fr: Rect2) -> float:   # WK-148b
	var fz := minf(1920.0 / maxf(fr.size.x, 1.0), 1080.0 / maxf(fr.size.y, 1.0))   # WK-148b
	return clampf(fz, CAM_MIN_ZOOM, CAM_MAX_ZOOM)   # WK-148b

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
