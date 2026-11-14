extends Node
## WK-93 match-recording boot (dev tool; launched by tools/record_match.ps1 under Godot Movie Maker).
## Reads `key=value` user args (everything after `--` on the Godot command line), writes the
## GameConfig.match_config for a scripted match, installs the persistent MatchRecorder on the root
## (survives the scene change, logs per-frame player data + events to tools/out/rec/<name>/data.json),
## then changes scene to the match (Arena.tscn). Movie Maker (--write-movie --fixed-fps) renders every
## frame at a deterministic timestep regardless of machine FPS, so the PNGs are a true frame-by-frame record.
##
## Args (all optional):
##   name=<dir>            output folder under tools/out/rec/            (default rec_<unix time>)
##   mode=brawl|rocketball|dropshot|trials                                (default brawl)
##   arena=<level name or res:// path>                                   (default: the mode's rotation)
##   levels=3,3,3,3        bot level per slot; slot 0 (the human seat) becomes a bot too (default 3,3,3,3)
##   seconds=20            seconds of COMBAT to record before quitting   (default 20)
##   seed=<int>            global RNG seed (same seed + same build = comparable before/after)
##   aim_legacy=1          InputBot.aim_sweep_enabled = false (pre-WK-94 aim, for BEFORE recordings)
##   hazard_legacy=1       MovingHazard.legacy_motion = true (pre-WK-96 pendulum, for BEFORE recordings)
##   pendulum_test=<N>     QA fixture: drop a player into a pendulum's path N times (WK-96 contact check)
##   stamp=0               hide the small REC frame/time stamp (default shown)
##   ghosts=on|baa|off     WK-37 RULES option (default on = MatchConfig default)
##   lives=<n>             lives per player (default 1)
##   eliminate=0,1         WK-37 QA fixture: ring out these seats 1.5 s into every stage (ghost recordings)

const MATCH_SCENE := "res://scenes/Arena.tscn"
const RECORDER_SCENE := "res://scenes/dev/MatchRecorder.tscn"

static func parse_args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		var eq := s.find("=")
		if eq > 0:
			d[s.substr(0, eq).strip_edges()] = s.substr(eq + 1).strip_edges()
	return d

func _ready() -> void:
	var args := parse_args()
	var name_s: String = str(args.get("name", "rec_%d" % int(Time.get_unix_time_from_system())))
	var levels: Array = []
	for t in str(args.get("levels", "3,3,3,3")).split(",", false):
		levels.append(clampi(int(t), 1, 5))
	if levels.is_empty():
		levels = [3, 3, 3, 3]
	levels.resize(mini(levels.size(), MatchConfig.MAX_FIGHTERS))
	if args.has("seed"):
		seed(int(args["seed"]))
	InputBot.aim_sweep_enabled = str(args.get("aim_legacy", "0")) != "1"
	MovingHazard.legacy_motion = str(args.get("hazard_legacy", "0")) == "1"

	GameConfig.reset_to_defaults()
	var cfg: MatchConfig = GameConfig.match_config
	cfg.mode_id = StringName(str(args.get("mode", "brawl")))
	cfg.human_count = 1                     # MatchConfig floor; the recorder swaps this seat to a bot
	cfg.bot_count = levels.size() - 1
	cfg.kills_to_win = 99                   # never end the match mid-recording
	var gm: String = str(args.get("ghosts", "on")).to_lower()
	cfg.ghosts = MatchConfig.Ghosts.OFF if gm == "off" else (MatchConfig.Ghosts.BAA_ONLY if gm == "baa" else MatchConfig.Ghosts.ON)
	cfg.lives_per_player = clampi(int(args.get("lives", "1")), 1, 3)
	var arena: String = str(args.get("arena", ""))
	if arena != "":
		if not arena.begins_with("res://"):
			arena = "res://levels/%s.json" % arena.trim_suffix(".json")
		cfg.arena_mode = MatchConfig.ArenaMode.SINGLE
		cfg.single_arena_path = arena

	var rec: Node = load(RECORDER_SCENE).instantiate()
	rec.name = "MatchRecorder"
	rec.set("cfg", {
		"name": name_s, "mode": str(cfg.mode_id), "arena": arena, "levels": levels,
		"seconds": float(args.get("seconds", "20")),
		"aim_legacy": not InputBot.aim_sweep_enabled, "hazard_legacy": MovingHazard.legacy_motion,
		"pendulum_test": int(args.get("pendulum_test", "0")), "stamp": str(args.get("stamp", "1")) != "0",
		"seed": int(args.get("seed", "-1")),
		"ghosts": gm,
		"eliminate": Array(str(args.get("eliminate", "")).split(",", false)).map(func(x): return int(x)),
	})
	get_tree().root.add_child.call_deferred(rec)
	get_tree().change_scene_to_file.call_deferred(MATCH_SCENE)
