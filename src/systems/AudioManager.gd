extends Node
## AudioManager (INV-12 presentation subscriber). The single owner of sound in GottaBounce:
## a pooled bank of AudioStreamPlayers for SFX (so overlapping hits don't cut each other), a
## looping jetpack-thrust voice, and a music voice. It NEVER calls into gameplay — it only
## SUBSCRIBES to EventBus / KillPipeline signals and reads state read-only. Autoloaded as
## `AudioManager` (below EventBus/KillPipeline/PowerupSystem, which it depends on).
##
## Buses (res://default_bus_layout.tres): Master -> Music, SFX, Stingers. SFX players route to "SFX",
## music/thrust as noted. WK-163: the payoffs (KO pop + sting + ring-out whoosh, goal sax + crowd, match-win cheer) play
## on "Stingers" (own light limiter, NO SFX compressor) via play_sfx opts.bus, so the shared compressor stops flattening
## them against the bed. No class_name (autoload rule); entity types are duck-typed, never
## referenced by class_name at parse time.
##
## Event map lives in owner directive docs/feedback/owner_2026-07-04_arena_variety.md §2.

# --- event -> candidate stream paths (arrays = pick one at random for variation) ---
const SFX := {
	# WK-132: spring_short.ogg = spring.mp3 cut to 0.42 s (fade 0.24-0.42 s; the source rings 0.95 s down to -85 dB
	# and at ~19 bounces/s on Singularity those tails held 7-14 of the 14 voices)
	"bounce":            ["res://assets/sfx/spring_short.ogg", "res://assets/sfx/balloon_pop.mp3"],
	"smash":             ["res://assets/sfx/impact1.mp3", "res://assets/sfx/impact2.mp3", "res://assets/sfx/impact3.mp3"],
	"smash_heavy":       ["res://assets/sfx/slam_tight.ogg"],
	"super_fire":        ["res://assets/sfx/explosion_boss.mp3"],   # owner pick 2026-07-18 (was combo_bigRoar)
	"death":             ["res://assets/sfx/mm_quickdie.mp3"],
	# WK-163: 0.55 s hard broadband crack + falling "vanish" sweep layered OVER the KO pop (mm_quickdie fades in over 0.4 s and
	# has no attack of its own). Built from crunch.mp3 + Kenney CC0 sfx_disappear/sfx_throw by tools/audio/render_ko_sting.py.
	"ko_sting":          ["res://assets/sfx/ko_sting.ogg"],
	"death_whoosh":      ["res://assets/sfx/woosh.mp3"],
	"damage_1":          ["res://assets/sfx/enemyHurt_01.mp3"],
	"damage_2":          ["res://assets/sfx/enemyHurt_02.mp3"],
	"heal":              ["res://assets/sfx/pickup_health.mp3"],
	"powerup_pickup":    ["res://assets/sfx/pickup_bubble.mp3"],
	"powerup_activate":  ["res://assets/sfx/pullOutItem.mp3"],
	"countdown":         ["res://assets/sfx/countdown_beep.mp3"],
	"countdown_final":   ["res://assets/sfx/countdown_beep_final.mp3"],
	"go":                ["res://assets/sfx/game_start.mp3"],
	"first_blood":       ["res://assets/sfx/awYeah.mp3"],
	"two_left":          ["res://assets/sfx/combo_preBreak.mp3"],
	"match_win":         ["res://assets/sfx/rewardCheer.mp3"],
	"ui_click":          ["res://assets/sfx/btnClick_Start.mp3"],
	"explode":           ["res://assets/sfx/explosion_01.mp3"],
	# --- SPORTS (WK-105 / SP-01). Kenney CC0 + owner library; provenance in assets/sfx/LICENSES.md ---
	"ball_hit":          ["res://assets/sfx/kenney_impactPunch_medium_000.ogg", "res://assets/sfx/kenney_impactPunch_medium_001.ogg",
	                      "res://assets/sfx/kenney_impactPunch_medium_002.ogg", "res://assets/sfx/kenney_impactPunch_medium_003.ogg",
	                      "res://assets/sfx/kenney_impactPunch_medium_004.ogg"],
	"ball_body":         ["res://assets/sfx/kenney_impactSoft_heavy_000.ogg", "res://assets/sfx/kenney_impactSoft_heavy_001.ogg"],
	"ball_power":        ["res://assets/sfx/kenney_impactPunch_heavy_000.ogg", "res://assets/sfx/kenney_impactPunch_heavy_002.ogg",
	                      "res://assets/sfx/kenney_impactPunch_heavy_004.ogg"],
	"goal_red":          ["res://assets/sfx/kenney_jingles_SAX02.ogg"],   # rising sax run: RED's goal
	"goal_blue":         ["res://assets/sfx/kenney_jingles_SAX10.ogg"],   # rising sax run: BLUE's goal
	"goal_crowd":        ["res://assets/sfx/rewardCheer.mp3"],
	"own_goal":          ["res://assets/sfx/kenney_jingles_SAX07.ogg"],   # descending wah-wah-waaah
	"own_goal_groan":    ["res://assets/sfx/awNo.mp3"],
	"sports_fall":       ["res://assets/sfx/lower.mp3"],                  # slide-whistle whoop down a hole
	"tile_crack":        ["res://assets/sfx/kenney_impactPlank_medium_000.ogg", "res://assets/sfx/kenney_impactPlank_medium_001.ogg",
	                      "res://assets/sfx/kenney_impactPlank_medium_002.ogg"],   # WK-121 Dropshot tile hit 1
	"tile_break":        ["res://assets/sfx/crunch.mp3"],                 # WK-121 Dropshot tile hit 2 (hole opens)
	"tile_break_body":   ["res://assets/sfx/kenney_impactWood_medium_000.ogg", "res://assets/sfx/kenney_impactWood_medium_001.ogg"],
	# --- WK-53 bleat / taunt: one freesound CC0 goat per hero (provenance in assets/sfx/LICENSES.md). Keys are
	# "bleat_<hero>" (living) / "bleat_ghost_<hero>" (ghost variant: band-limited + vibrato + echo baked in). ---
	"bleat_butch":       ["res://assets/sfx/bleat_butch.ogg"],
	"bleat_billy":       ["res://assets/sfx/bleat_billy.ogg"],
	"bleat_vex":         ["res://assets/sfx/bleat_vex.ogg"],
	"bleat_ziggy":       ["res://assets/sfx/bleat_ziggy.ogg"],
	"bleat_pogo":        ["res://assets/sfx/bleat_pogo.ogg"],
	"bleat_puff":        ["res://assets/sfx/bleat_puff.ogg"],
	"bleat_ghost_butch": ["res://assets/sfx/bleat_ghost_butch.ogg"],
	"bleat_ghost_billy": ["res://assets/sfx/bleat_ghost_billy.ogg"],
	"bleat_ghost_vex":   ["res://assets/sfx/bleat_ghost_vex.ogg"],
	"bleat_ghost_ziggy": ["res://assets/sfx/bleat_ghost_ziggy.ogg"],
	"bleat_ghost_pogo":  ["res://assets/sfx/bleat_ghost_pogo.ogg"],
	"bleat_ghost_puff":  ["res://assets/sfx/bleat_ghost_puff.ogg"],
	# --- WK-26 super-aim wind-up: the owner's lower.mp3 slide whistle, tonal part reversed + stretched to the 2 s fuse
	# (a rising 250 Hz -> 1.2 kHz "fweeeep" that tops out at the auto-fire). Provenance in assets/sfx/LICENSES.md. ---
	"super_aim":         ["res://assets/sfx/super_aim.ogg"],
	# --- WK-131 Rocketball kickoff gates (brief docs/briefs/kickoff_gate_2026-11-15.md §11; provenance in LICENSES.md) ---
	# gate_clonk: hollow wood-block knock (Kenney impactWood, ~230 Hz body, pitched up into 250-400 Hz) + a quiet low spring
	# "boing" tail layered in _on_kickoff_gate_hit. gate_whine: the wind-up ratchet is TICKS (one per warning swing peak,
	# 3 -> 8 per s, emitted by the gate so sound and brightness lock) - a toy click, pitch rising. whistle_double: referee pea
	# whistle "TWEET-TWEET" derived from the owner's slide-whistle recording (lower.mp3). crowd_ooh: NO crowd "ooh" exists in
	# the library and audio is never downloaded -> silent placeholder until the sound-designer sources a CC0 one (WK-131b).
	"gate_clonk":        ["res://assets/sfx/kenney_impactWood_medium_000.ogg", "res://assets/sfx/kenney_impactWood_medium_001.ogg"],
	"gate_boing":        ["res://assets/sfx/spring_short.ogg"],
	"gate_whine":        ["res://assets/sfx/btnClick_Start.mp3"],
	"whistle_double":    ["res://assets/sfx/whistle_double.ogg"],
	"crowd_ooh":         [],
	# --- WK-20e spawn-truce dry click (spec wk20d §4.2): a super press the truce dropped. Kenney impactPlank crack (CC0,
	# already licensed for tile_crack; 40 ms, ~2.2 kHz) pitched up + quiet = a small dry "tk", not a menu click. ---
	"super_locked":      ["res://assets/sfx/kenney_impactPlank_medium_000.ogg", "res://assets/sfx/kenney_impactPlank_medium_001.ogg",
	                      "res://assets/sfx/kenney_impactPlank_medium_002.ogg"],   # WK-20e
	# --- WK-116 PRESSURE NETS (spec docs/specs/wk116_long_rally_2026-11-15.md §5; provenance in LICENSES.md). ka-CHUNK = a pitched-up
	# wood knock ("ka") then a low heavy punch ("CHUNK") 70 ms later (+ slam on step 2); OOOH = the goal crowd slowed. The murmur bed
	# and the clap-chant loops are derived from rewardCheer.mp3 / Kenney impactPlank (tools/audio/render_wk116_crowd.py). ---
	"pressure_ka":       ["res://assets/sfx/kenney_impactWood_medium_000.ogg", "res://assets/sfx/kenney_impactWood_medium_001.ogg"],
	"pressure_chunk":    ["res://assets/sfx/kenney_impactPunch_heavy_000.ogg", "res://assets/sfx/kenney_impactPunch_heavy_002.ogg",
	                      "res://assets/sfx/kenney_impactPunch_heavy_004.ogg"],
	"pressure_slam":     ["res://assets/sfx/slam_tight.ogg"],
	"pressure_ooh":      ["res://assets/sfx/rewardCheer.mp3"],
}

# --- WK-53 bleat voice per goat skin (PlayerIdentity names). Six different goats (adult / buck / kid recordings)
# plus a per-hero pitch so no two heroes share a voice; db trims level-match the files by ear-proxy (active RMS).
const BLEAT_BY_SKIN := {
	"blue":   {"hero": "butch", "pitch": 0.90, "db": 0.0},    # BUTCH: deepest, sustained adult "MAAAH"
	"orange": {"hero": "billy", "pitch": 1.00, "db": 0.0},    # BILLY: adult with a goaty tremolo
	"purple": {"hero": "vex",   "pitch": 1.00, "db": 1.0},    # VEX: pulsed buck "meh-eh-eh"
	"green":  {"hero": "ziggy", "pitch": 0.95, "db": 0.0},    # ZIGGY: clean, nasal "meeeh"
	"pink":   {"hero": "pogo",  "pitch": 1.00, "db": 1.0},    # POGO: kid
	"yellow": {"hero": "puff",  "pitch": 1.08, "db": 2.0},    # PUFF: smallest, highest kid
}
const BLEAT_FALLBACK_ORDER := ["pogo", "butch", "ziggy", "puff", "vex", "billy"]   # unknown skin -> by player idx
const BLEAT_DB := -1.0            # WK-79b (was -4; SFX makeup +4 removed): living taunt, under a smash and the KO pop (+1), over the bed
const BLEAT_GHOST_DB := -4.0      # WK-79b (was -6): the dead are a seasoning, over the thrust loop (-12), under a KO pop
const BLEAT_GHOST_PITCH := 1.1892 # +3 semitones (spec wk37a §9 "ghostly variant")
const BLEAT_PITCH_VAR := 0.03     # small per-press spread so repeats aren't a machine-gun of one sample
const BLEAT_MAX_VOICES := 3       # global cap on simultaneous bleats (4 spamming ghosts can't starve the pool)
const MUSIC_GAMEPLAY := [
	"res://assets/music/gameplay_1.mp3", "res://assets/music/gameplay_2.mp3",
	"res://assets/music/gameplay_3.mp3", "res://assets/music/gameplay_4.mp3",
]
const MUSIC_SCOREBOARD := "res://assets/music/scoreboard.mp3"
const MUSIC_MENU := "res://assets/music/title.wav"
const THRUST_STREAM := "res://assets/sfx/coke_blast.mp3"   # owner pick 2026-07-18 (was fireLoop); looped jetpack voice

const POOL_SIZE := 14

# --- WK-132 voice priority. Each one-shot gets a tier; a full pool steals the LOWEST tier, oldest voice first.
#   0 FILLER   - bounces, hazard whooshes: capped at FILLER_MAX_VOICES, so >= 9 voices always stay for the rest
#   1 NORMAL   - damage, pickups, countdown, UI, ball touches, tile cracks (default)
#   2 PRIORITY - the verbs + payoffs: smash, KO, super, explode, goal, bleat, stingers. Only ever cut by a
#                priority sound, and only when 9+ priority sounds already ring (counted in prio_cut_prio).
# `protect` (goal stingers) ranks above every tier: stolen only if the whole pool is protected.
const TIER_FILLER := 0
const TIER_NORMAL := 1
const TIER_PRIORITY := 2
const FILLER_MAX_VOICES := 5
const PRIORITY_SFX := {
	"smash": true, "smash_heavy": true, "super_fire": true, "death": true, "death_whoosh": true, "explode": true,
	"ko_sting": true,   # WK-163
	"go": true, "first_blood": true, "two_left": true, "match_win": true,
	"goal_red": true, "goal_blue": true, "goal_crowd": true, "own_goal": true, "own_goal_groan": true,
	"ball_power": true, "sports_fall": true, "tile_break": true,
	"whistle_double": true,   # WK-131: the gates-open whistle is a payoff beat
	"pressure_ka": true, "pressure_chunk": true, "pressure_slam": true, "pressure_ooh": true,   # WK-116: escalation beats
}
const FILLER_SFX := {"bounce": true}
# Per-sound voice caps: past the cap the sound recycles its OWN oldest voice. "countdown" doubles as the Bomb.gd
# telegraph beep (4 -> 14 Hz, 0.22-0.32 s each): Everything Yard fired 556 in 89 s and held the pool at 14/14 for
# 85 of 1574 samples. The match 3-2-1 (1 Hz) never reaches the cap.
const SFX_VOICE_CAP := {"countdown": 3, "super_aim": 3}   # WK-26: <= 3 wind-ups at once (a 4th recycles the oldest)
# WK-79b (was -7; audit docs/audit/2026-11-15_audio_measure.md §2): the one looped jetpack voice was 38-65 % of all combat
# sound, 5-9 dB over the music, masking bounce/KO/aim in 0.5-1.5 kHz. With the SFX makeup gone this is -9 dB effective.
const THRUST_ON_DB := -12.0
const THRUST_OFF_DB := -60.0
const THRUST_FADE := 10.0        # db/sec toward target

# --- WK-163 stinger bus + KO duck (audit docs/audit/2026-11-15_audio_measure.md, WK-79c + WK-163 sections). Payoff levels are set for the
# Stingers bus (0 dB, 40 Hz HPF, HardLimiter -3 dB, no compressor): on the old SFX path the compressor took 3-7 dB off a KO.
const STINGER_BUS := "Stingers"
const KO_STING_DB := -2.0        # file peak -1.1 -> -3.1, at the stinger limiter ceiling; carries the KO's first 0.4 s
const KO_POP_DB := 1.0           # mm_quickdie (file peak -5.6 -> -4.6): ~2 dB over its old in-mix level (-0.6..-1.7 vs file at +5
                                 # on SFX) so the 0.4-1 s KO tail still clears a hot bed (WK-79c2 beds ran -14.5..-17.5 LUFS)
const KO_WHOOSH_DB := -3.0       # ring-out woosh (file peak -1.0): old SFX +1 read ~-3.5 after bus + compressor
const GOAL_SAX_DB := 5.0         # was +9 on SFX (~+3.5 effective after -2.5 bus and ~3 dB of compression)
const GOAL_CROWD_DB := -2.0      # was +2 on SFX (~-1.5 effective). At 0 its 3 s tail + the next "3" beep hit -1.95 dBFS in COUNTDOWN
const MATCH_WIN_DB := -1.0       # rewardCheer (file peak -2.8)
const KO_DUCK_DB := -4.0         # SFX bus "KODuck" Amplify (bed: bounces, thrust, aim, smashes) under a brawl KO
const KO_DUCK_ATTACK := 0.015    # s to reach KO_DUCK_DB
const KO_DUCK_HOLD := 0.3        # s held
const KO_DUCK_RELEASE := 0.25    # s back to 0 dB
var ko_ducks := 0                # QA: KO ducks triggered
var _stinger_bus := "SFX"        # resolved in _ready (falls back to SFX if the layout has no Stingers bus)
var _duck_fx: AudioEffectAmplify = null
var _duck_t := -1.0              # s since the duck began (-1 = idle)

var _cache := {}                 # path -> AudioStream (lazy loaded once)
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _thrust: AudioStreamPlayer
var _thrust_db := THRUST_OFF_DB

# QA counters (readable via gbplay eval — audio has no visual proof headless)
var sfx_fired := 0
var last_sfx := ""
var thrust_active := false
var sfx_counts := {}             # event key -> times played (QA: sports evidence logs counts by type)
var ball_strikes_seen := 0       # every EventBus.ball_struck received (heard or rate-limited)
var ball_strikes_heard := 0      # strikes that produced a sound
var sfx_dropped := 0             # sounds skipped: every voice held a higher tier (or protected) sound
var prio_dropped := 0            # WK-132: PRIORITY sounds that got no voice at all (must stay 0)
var prio_cut_prio := 0           # WK-132: PRIORITY sounds that had to cut another ringing PRIORITY sound (must stay 0)
var steals := {}                 # WK-132 QA: "new_tier>old_tier" -> count of voice steals
var sfx_capped := 0             # WK-132 QA: sounds that recycled their own oldest voice (SFX_VOICE_CAP)
var filler_capped := 0           # WK-132 QA: filler sounds that recycled the oldest filler voice (cap reached)
var bleats_seen := 0             # WK-53: every EventBus.bleated received
var bleats_heard := 0            # bleats that produced a sound (rest = rate limit / voice cap / pool full)
var bleat_log: Array = []        # last 32 heard: {ms, idx, ghost, key, pitch} (QA via gbplay eval)
var _bleat_hist := {}            # "idx:ghost" -> [ms of recent heard bleats] (per-player rate limit)
# WK-26 super-aim wind-up: one voice per aiming goat, faded out the moment its aim ends (fire / cancel / KO / freeze).
const SUPER_AIM_DB := -2.0       # WK-79b (was -8: measured 1.8 dB UNDER the thrust bed, masked); over the thrust loop and the music bed
const SUPER_AIM_FADE := 0.05     # s fade-out when the aim ends (no click; the blast / smash covers it anyway)
var super_aims_seen := 0         # QA: every EventBus.super_aim_started received
var super_aims_heard := 0        # QA: wind-ups that got a voice
var _aim_voices := {}            # player instance id -> {"p": Player, "v": AudioStreamPlayer, "tag": String, "fade": bool}

# --- SPORTS mix / rate-limit (WK-105). Touch loudness rides the |delta-v| the touch gave the ball. ---
# Measured (2v2 L3 bots, 77 touches): |delta-v| min 342 / median 2237 / max 3872 — a touch that REVERSES
# a fast ball reads ~2x its exit speed, so the range spans to ~2x the cap; median lands mid-scale.
const BALL_IMPACT_LO := 800.0    # px/s -> soft tap (a nudge / dribble carry)
const BALL_IMPACT_HI := 3800.0   # px/s -> full thwack (a fast ball sent straight back)
const BALL_DB_SOFT := -12.0      # WK-79b (was -15): soft tap sits at / under the music bed
const BALL_DB_HARD := -1.0       # WK-79b (was -5): a full thwack sits level with bounces
const BALL_DB_POWER := 0.0       # WK-79b (was -1): power shot, file peak -1 dBFS -> lands at the limiter ceiling, not over it
const BALL_GAP_SOFT := 0.04      # min s between touch sounds: merges only true flams (two goats on the
                                 # ball in the same few ticks); Ball's per-player 0.12 s touch cd bounds a
                                 # dribble, and BALL_REPEAT_DUCK keeps a dribble/scrum under the mix
const BALL_GAP_HARD := 0.03      # a hard hit may follow quickly (a real second strike)
const BALL_REPEAT_WINDOW := 0.3  # a touch within this of the last heard one is a dribble/scrum ...
const BALL_REPEAT_DUCK := -5.0   # ... and is ducked so it never machine-guns over the mix
const BOUNCE_MIN_GAP := 0.04     # global floor between bounce sounds (s)
const BOUNCE_DB_SPORTS := -4.0   # WK-79b (was -8): bounce level in sports, 4 dB under brawl so the ball stays the hero
const BOUNCE_DB_BRAWL := 0.0     # WK-79b (was a hardcoded -4): the core verb measured 2.7 dB under the thrust bed
const BOUNCE_SOUND_MIN_SPEED := 250.0   # WK-132: px/s exit speed below which a contact may be resting jitter ...
const BOUNCE_ONSET_GAP := 0.15          # ... and is silent unless that goat was contact-free this long (a landing)
var bounce_micro_skipped := 0    # WK-132 QA: jitter contacts silenced
var _contact_last_t := {}        # player instance id -> clock (s) of its last surface_bounced
var _bounce_last_t := -10.0
var _ball_last_t := -10.0        # clock (s) of the last heard touch
var _ball_last_amt := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # sounds still fire while the game is paused / hitstop
	# SFX voice pool
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	# looping jetpack thrust voice (volume-driven; always "playing" the loop)
	_thrust = AudioStreamPlayer.new()
	_thrust.bus = "SFX"
	_thrust.volume_db = THRUST_OFF_DB
	var ts := _stream(THRUST_STREAM)
	if ts != null:
		if ts is AudioStreamMP3:
			ts.loop = true
		_thrust.stream = ts
	add_child(_thrust)
	if _thrust.stream != null:
		_thrust.play()
	# music voice
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	# WK-163: stinger bus + the SFX-bus duck effect (both from default_bus_layout.tres; absent -> harmless no-ops)
	if AudioServer.get_bus_index(STINGER_BUS) >= 0:
		_stinger_bus = STINGER_BUS
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		for i in range(AudioServer.get_bus_effect_count(sfx_idx)):
			var fx := AudioServer.get_bus_effect(sfx_idx, i)
			if fx is AudioEffectAmplify:
				_duck_fx = fx
				_duck_fx.volume_db = 0.0
				break

	# --- subscribe (INV-12): sim emits, we react ---
	EventBus.surface_bounced.connect(_on_surface_bounced)
	EventBus.smashed.connect(_on_smashed)
	EventBus.super_boosted.connect(_on_super_boosted)
	EventBus.exploded.connect(_on_exploded)
	EventBus.powerup_used.connect(_on_powerup_used)
	EventBus.powerup_picked.connect(_on_powerup_picked)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_healed.connect(_on_player_healed)
	EventBus.countdown_tick.connect(_on_countdown_tick)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.match_started.connect(_on_match_started)
	EventBus.match_won.connect(_on_match_won)
	EventBus.first_blood.connect(_on_first_blood)
	EventBus.two_left.connect(_on_two_left)
	EventBus.hazard_whoosh.connect(_on_hazard_whoosh)   # WK-96 pendulum pass
	EventBus.ball_struck.connect(_on_ball_struck)       # WK-105 sports ball touch
	EventBus.goal_scored.connect(_on_goal_scored)       # WK-105 goal/point stinger (WK-106 signal)
	EventBus.drop_tile_hit.connect(_on_drop_tile_hit)   # WK-121 Dropshot tile crack / break
	EventBus.bleated.connect(_on_bleated)               # WK-53 ghost bleat + WK-53b living taunt (LivingCues emits)
	EventBus.super_aim_started.connect(_on_super_aim_started)   # WK-26 super-aim wind-up
	EventBus.kickoff_gate_hit.connect(_on_kickoff_gate_hit)     # WK-131 gate clonk (+ ooh)
	EventBus.kickoff_gates_open.connect(_on_kickoff_gates_open) # WK-131 double whistle
	EventBus.kickoff_gate_dropped.connect(_on_kickoff_gate_dropped)   # WK-131 stage-intro drop-in clonk
	EventBus.kickoff_gate_tick.connect(_on_kickoff_gate_tick)   # WK-131 warning wind-up ticks
	EventBus.super_lock_pressed.connect(_on_super_lock_pressed)   # WK-20e spawn-truce dry click
	EventBus.sports_pressure.connect(_on_sports_pressure)   # WK-116 pressure nets (bed swell, ka-CHUNK, clap-chant)
	KillPipeline.killed.connect(_on_killed)

# --------------------------------------------------------------------- core play API

## Fire a one-shot SFX by event key. opts: {pitch: float, pitch_var: float, volume_db: float,
## path: String (force a specific stream), protect: bool (WK-105: never voice-stolen while playing), bus: String (WK-163;
## default "SFX" - payoffs pass the resolved stinger bus),
## tier: int (WK-132 override; default from PRIORITY_SFX / FILLER_SFX / "bleat_*", else NORMAL), tag: String (QA)}.
func play_sfx(name: String, opts: Dictionary = {}) -> void:
	var path: String = str(opts.get("path", ""))
	if path == "":
		var paths: Array = SFX.get(name, [])
		if paths.is_empty():
			return
		path = str(paths[randi() % paths.size()])
	var stream := _stream(path)
	if stream == null:
		return
	var tier: int = int(opts.get("tier", _tier_of(name)))
	var pl: AudioStreamPlayer = null
	if SFX_VOICE_CAP.has(name) and voices_named(name) >= int(SFX_VOICE_CAP[name]):
		pl = _oldest_named(name)
		if pl != null:
			sfx_capped += 1
	if pl == null:
		pl = _voice_for(tier)
	if pl == null:
		sfx_dropped += 1
		if tier >= TIER_PRIORITY:
			prio_dropped += 1
		return
	pl.set_meta("protect", bool(opts.get("protect", false)))
	pl.set_meta("tag", str(opts.get("tag", "")))
	pl.set_meta("tier", tier)
	pl.set_meta("t0", Time.get_ticks_usec())
	pl.set_meta("sfx", name)
	pl.stream = stream
	pl.bus = str(opts.get("bus", "SFX"))   # WK-163: pooled voices are shared, so every play sets its bus
	var pitch: float = float(opts.get("pitch", 1.0))
	var pvar: float = float(opts.get("pitch_var", 0.06))
	pl.pitch_scale = clampf(pitch + randf_range(-pvar, pvar), 0.4, 2.5)
	pl.volume_db = float(opts.get("volume_db", 0.0))
	pl.play()
	sfx_fired += 1
	last_sfx = name
	sfx_counts[name] = int(sfx_counts.get(name, 0)) + 1

func _tier_of(name: String) -> int:
	if PRIORITY_SFX.has(name) or name.begins_with("bleat_"):
		return TIER_PRIORITY
	if FILLER_SFX.has(name):
		return TIER_FILLER
	return TIER_NORMAL

## Effective rank of a ringing voice for stealing: its tier, or 3 if protected (goal stingers / crowd).
func _rank(p: AudioStreamPlayer) -> int:
	if bool(p.get_meta("protect", false)):
		return TIER_PRIORITY + 1
	return int(p.get_meta("tier", TIER_NORMAL))

## WK-132 voice allocation. Filler past its cap recycles its own oldest voice; otherwise a free voice; otherwise
## steal the lowest-rank, oldest ringing voice whose rank <= the new sound's tier. A PRIORITY sound that can only
## find PRIORITY / protected voices still plays (counted in prio_cut_prio); lower tiers are dropped instead.
func _voice_for(tier: int) -> AudioStreamPlayer:
	if tier <= TIER_FILLER and voices_tier(TIER_FILLER) >= FILLER_MAX_VOICES:
		var old := _oldest(TIER_FILLER, TIER_FILLER)
		if old != null:
			filler_capped += 1
			return old
	for i in range(_pool.size()):
		var idx := (_next + i) % _pool.size()
		if not _pool[idx].playing:
			_next = (idx + 1) % _pool.size()
			return _pool[idx]
	for r in range(TIER_FILLER, tier + 1):
		var v := _oldest(r, r)
		if v != null:
			var k := "%d>%d" % [tier, r]
			steals[k] = int(steals.get(k, 0)) + 1
			if r >= TIER_PRIORITY:
				prio_cut_prio += 1
			return v
	if tier >= TIER_PRIORITY:
		prio_cut_prio += 1
		return _oldest(TIER_FILLER, TIER_PRIORITY + 1)
	return null

## Oldest ringing voice whose rank is in [lo, hi], or null.
func _oldest(lo: int, hi: int) -> AudioStreamPlayer:
	var best: AudioStreamPlayer = null
	var best_t := 0
	for p in _pool:
		if not p.playing:
			continue
		var r := _rank(p)
		if r < lo or r > hi:
			continue
		var t: int = int(p.get_meta("t0", 0))
		if best == null or t < best_t:
			best = p
			best_t = t
	return best

func voices_named(sfx: String) -> int:
	var n := 0
	for p in _pool:
		if p.playing and str(p.get_meta("sfx", "")) == sfx:
			n += 1
	return n

func _oldest_named(sfx: String) -> AudioStreamPlayer:
	var best: AudioStreamPlayer = null
	var best_t := 0
	for p in _pool:
		if p.playing and str(p.get_meta("sfx", "")) == sfx and not bool(p.get_meta("protect", false)):
			var t: int = int(p.get_meta("t0", 0))
			if best == null or t < best_t:
				best = p
				best_t = t
	return best

## Voices currently ringing at exactly this tier (protected voices excluded).
func voices_tier(tier: int) -> int:
	var n := 0
	for p in _pool:
		if p.playing and _rank(p) == tier:
			n += 1
	return n

## Voices currently playing a sound fired with opts.tag == tag.
func voices_tagged(tag: String) -> int:
	var n := 0
	for p in _pool:
		if p.playing and str(p.get_meta("tag", "")) == tag:
			n += 1
	return n

## QA (gbplay eval): what every voice is ringing right now, as "sfx/tier".
func voice_snapshot() -> Array:
	var out: Array = []
	for p in _pool:
		if p.playing:
			out.append("%s/%d" % [str(p.get_meta("sfx", "?")), _rank(p)])
	return out

func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	if s == null:
		push_warning("AudioManager: missing audio '%s'" % path)
	_cache[path] = s
	return s

# --------------------------------------------------------------------- music

func play_music(path: String, loop := true, db := 0.0) -> void:
	var s := _stream(path)
	if s == null:
		return
	if s is AudioStreamMP3:
		s.loop = loop
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop and int(s.loop_end) <= 0:
			# imported WAVs ship loop_end=0 — LOOP_FORWARD then wraps at sample 0 and playback dies
			# instantly (found live: title.wav went silent). Loop the whole sample.
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
	_music.stream = s
	_music.volume_db = db
	_music.play()

## Menu/title theme (owner 2026-07-17: "trials music stops and home screen music starts").
## ShellRoot calls this on every landing — cold boot AND every quit-to-menu (both change_scene back
## to ShellRoot) — so gameplay music never leaks into the front-end. No-op if already playing it,
## so in-shell navigation never restarts the track.
func play_menu_music() -> void:
	var s := _stream(MUSIC_MENU)
	if s != null and _music.stream == s and _music.playing:
		return
	play_music(MUSIC_MENU, true, -4.0)

# --------------------------------------------------------------------- signal handlers

func _on_surface_bounced(surface, player, _normal, _contact) -> void:
	# WK-132: resting-contact jitter is not a bounce. surface_bounced fires EVERY physics tick while a goat rests on
	# a surface: Singularity pinned all four goats to the core bumper (~100 events/s at 38-95 px/s exit speed) and a
	# Rocketball court logged 2427 events in 30 s, 91 % under 250 px/s (median 6). Real bounces (Grassy Expanse,
	# 107 sampled) leave at >= 783 px/s. A slow contact sounds only as the ONSET of a contact (a landing): the
	# same goat must have been contact-free for BOUNCE_ONSET_GAP s; continuous slow contact stays silent.
	if player != null and is_instance_valid(player) and "velocity" in player:
		var pid: int = player.get_instance_id()
		var tnow: float = Time.get_ticks_msec() / 1000.0
		var last_c: float = float(_contact_last_t.get(pid, -10.0))
		_contact_last_t[pid] = tnow
		if (player.velocity as Vector2).length() < BOUNCE_SOUND_MIN_SPEED and tnow - last_c < BOUNCE_ONSET_GAP:
			bounce_micro_skipped += 1
			return
	# per-tier pitch: taller-tier surfaces read lower/bigger, small tiers ping higher (spec §2 nice-to-have)
	var pitch := 1.0
	if surface != null and is_instance_valid(surface):
		if surface.has_meta("bounce_tier_height"):
			var h: float = float(surface.get_meta("bounce_tier_height"))
			var ref: float = maxf(Tuning.bounce_height_trampoline, 1.0)
			pitch = clampf(sqrt(ref / maxf(h, 1.0)), 0.8, 1.35)
		elif surface.has_meta("bumper"):
			pitch = 1.25   # bumpers ping bright
	# WK-105 mix: bounces fire ~18/s with 4 goats on a sports court (2219 in a 120 s Dropshot) and stacked
	# the master over 0 dB; a 40 ms global floor merges same-instant multi-goat hits, and in SPORTS the
	# bounce sits 4 dB lower so the BALL touch is the hero sound there.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _bounce_last_t < BOUNCE_MIN_GAP:
		return
	_bounce_last_t = now
	var db: float = BOUNCE_DB_SPORTS if _sports_active() else BOUNCE_DB_BRAWL   # WK-79b
	play_sfx("bounce", {"pitch": pitch, "pitch_var": 0.08, "volume_db": db, "tag": "bounce"})

func _on_smashed(_attacker, _victim, impulse) -> void:
	# volume scaled by hit solidity (impulse magnitude vs a full super blast)
	var t := clampf(impulse.length() / maxf(Tuning.super_boost_impulse_full, 1.0), 0.0, 1.0)
	# WK-79c (was -10..+2): a ring-out KO lands < 1 s after the heavy smash that caused it, and the smash (up to +2,
	# ~-12 dBFS RMS) out-shouted the KO pop (+1, ~-17) -> KO rise only +2.8/+3.2 LU. Smash tops out at -1 now; the KO leads.
	var db := lerpf(-12.0, -1.0, t)
	if t > 0.6:
		play_sfx("smash_heavy", {"volume_db": db, "pitch_var": 0.05})
	else:
		play_sfx("smash", {"volume_db": db, "pitch": 1.05, "pitch_var": 0.1})

## WK-96: a low, quiet whoosh as a pendulum ball sweeps through the bottom of its arc — only when the
## ball is on screen (three pendulums off-camera must not drone).
func _on_hazard_whoosh(_hazard, pos, _speed) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var sp: Vector2 = vp.get_canvas_transform() * (pos as Vector2)
	if not vp.get_visible_rect().grow(120.0).has_point(sp):
		return
	play_sfx("death_whoosh", {"volume_db": -15.0, "pitch": 0.62, "pitch_var": 0.05, "tier": TIER_FILLER})   # WK-132 ambience

func _on_super_boosted(_player) -> void:
	# WK-79b: explosion_boss is 74 % 20-60 Hz at -6 dBFS RMS; at -2 dB it ducked the whole SFX bus ~5 dB for 2.8 s and
	# read < 2 LU on a TV. Rumble tail down to -10 (peaks under the WK-79c -6 dB compressor threshold) + an interim mid "crack" layer
	# from the owner's slam.mp3 pitched down (distinct from smash_heavy at 1.0) until a real crack is sourced (audit S-1).
	play_sfx("super_fire", {"volume_db": -10.0, "pitch_var": 0.08})
	play_sfx("super_fire", {"path": "res://assets/sfx/slam_tight.ogg", "volume_db": -5.0, "pitch": 0.8, "pitch_var": 0.05})   # WK-79c (was -3): 17/20 supers hit the limiter

func _on_exploded(_center, _radius) -> void:
	play_sfx("explode", {"volume_db": 0.0})

func _on_powerup_used(_player, _id) -> void:
	play_sfx("powerup_activate", {"volume_db": -2.0})

func _on_powerup_picked(_player, _id) -> void:
	play_sfx("powerup_pickup", {"volume_db": -3.0})

func _on_player_damaged(_player, level) -> void:
	if int(level) >= 2:
		play_sfx("damage_2", {"volume_db": -3.0})
	else:
		play_sfx("damage_1", {"volume_db": -4.0})

func _on_player_healed(_player) -> void:
	play_sfx("heal", {"volume_db": -5.0})

func _on_countdown_tick(n) -> void:
	if int(n) <= 1:
		play_sfx("countdown_final", {"volume_db": -2.0})
	else:
		play_sfx("countdown", {"volume_db": -4.0})

func _on_combat_started() -> void:
	play_sfx("go", {"volume_db": 3.0})   # WK-79c (was 0; file peak -4.9 -> -1.9): GO read like a countdown beep (+1.0 LU rise)

func _on_match_started() -> void:
	_contact_last_t.clear()
	play_music(MUSIC_GAMEPLAY[randi() % MUSIC_GAMEPLAY.size()], true, 0.0)

func _on_match_won(_widx) -> void:
	play_sfx("match_win", {"volume_db": MATCH_WIN_DB, "bus": _stinger_bus})   # WK-163 (was 0 on SFX)
	play_music(MUSIC_SCOREBOARD, true, 0.0)

## WK-163: FIRST BLOOD / TWO LEFT land on the same tick as a KO, so on the SFX bus the KO duck ate 4 dB of them. Moved to the
## Stingers bus at their old absolute level (was -1 / -2 on SFX: -2.5 bus, ~1 dB compression on the TWO LEFT peak).
func _on_first_blood(_ai) -> void:
	play_sfx("first_blood", {"volume_db": -3.5, "bus": _stinger_bus})   # WK-163

func _on_two_left() -> void:
	play_sfx("two_left", {"volume_db": -5.5, "bus": _stinger_bus})   # WK-163

func _on_killed(victim, cause, _attacker) -> void:
	# SPORTS (WK-105): nobody "dies" in sports. A goat that drops out of the court (a Dropshot hole, a
	# rare knock out of bounds) gets the comedic slide-whistle whoop, never the brawl death sting. An
	# in-bounds hazard KO there keeps a quieter death pop until WK-112 turns hazards into stuns.
	if _sports_active():
		if _out_of_court(victim):
			play_sfx("sports_fall", {"volume_db": -4.0, "pitch_var": 0.08})
		else:
			play_sfx("death", {"volume_db": -8.0, "pitch_var": 0.1})
		return
	# off-screen / ring-out kills get the whoosh-out; other causes just the death pop
	# WK-79b (both were -3): the KO measured only +2.9 dB over the thrust bed; +1 keeps its absolute level with the
	# SFX makeup removed while the bed falls ~9 dB
	# WK-163: all three on the Stingers bus (past the SFX compressor that took 3-7 dB off the pop); the sting supplies the
	# hard attack, the pop the tail; the SFX bed ducks KO_DUCK_DB for ~0.3 s underneath.
	if str(cause) == "ring_out":
		play_sfx("death_whoosh", {"volume_db": KO_WHOOSH_DB, "bus": _stinger_bus})   # WK-163 (was +1 on SFX)
	play_sfx("ko_sting", {"volume_db": KO_STING_DB, "pitch_var": 0.04, "bus": _stinger_bus})   # WK-163
	play_sfx("death", {"volume_db": KO_POP_DB, "pitch_var": 0.1, "bus": _stinger_bus})   # WK-163 (was +5 on SFX)
	_start_ko_duck()   # WK-163

# --------------------------------------------------------------------- sports (WK-105 / SP-01)

## Ball touch: one "thwock" per accepted strike, pitch DOWN + volume UP with impact (soft tap = bright
## and quiet, hard hit = deep and loud), a small random pitch spread, a low body thump layered on hard
## hits, and a distinct heavier hit on the power shot. Rate-limited: a soft touch inside the gap after
## the last heard touch is swallowed unless it is clearly harder (dribbles never machine-gun).
func _on_ball_struck(_ball, _player, impact, is_power) -> void:
	ball_strikes_seen += 1
	var t: float = clampf(inverse_lerp(BALL_IMPACT_LO, BALL_IMPACT_HI, float(impact)), 0.0, 1.0)
	var now: float = Time.get_ticks_msec() / 1000.0
	var gap: float = lerpf(BALL_GAP_SOFT, BALL_GAP_HARD, t)
	var since: float = now - _ball_last_t
	if not bool(is_power) and since < gap and t < _ball_last_amt + 0.25:
		return
	var duck: float = BALL_REPEAT_DUCK * (1.0 - t) if since < BALL_REPEAT_WINDOW else 0.0
	_ball_last_t = now
	_ball_last_amt = t
	ball_strikes_heard += 1
	if bool(is_power):
		play_sfx("ball_power", {"volume_db": BALL_DB_POWER, "pitch": 0.92, "pitch_var": 0.05})
		play_sfx("ball_body", {"volume_db": -6.0, "pitch": 0.9, "pitch_var": 0.04})
		return
	play_sfx("ball_hit", {"volume_db": lerpf(BALL_DB_SOFT, BALL_DB_HARD, t) + duck,
		"pitch": lerpf(1.3, 0.92, t), "pitch_var": 0.06})
	if t > 0.55:
		# sub-heavy layer (~110 Hz centroid): kept low, it eats master headroom invisibly
		play_sfx("ball_body", {"volume_db": lerpf(-16.0, -9.0, (t - 0.55) / 0.45), "pitch_var": 0.05})

## Goal / point (EventBus.goal_scored, WK-106: emitted once per goal at STAGE_END entry, the tick the
## latched goal_zone is polled). team = the team AWARDED the goal. Each team has its own rising sax run +
## the crowd + a net-bulge thump; an OWN GOAL (soccer only, SportsMode's credit) gets the descending
## wah-wah + an "aww no" + a muted crowd instead. Dropshot points never arrive as own goals.
func _on_goal_scored(team, _scorer, own_goal) -> void:
	last_goal_own = bool(own_goal)
	if bool(own_goal):
		play_sfx("own_goal", {"volume_db": 4.0, "pitch_var": 0.0, "protect": true})
		play_sfx("own_goal_groan", {"volume_db": -9.0, "pitch_var": 0.04, "protect": true})
		play_sfx("goal_crowd", {"volume_db": -9.0, "pitch": 0.85, "pitch_var": 0.0, "protect": true})
		return
	# WK-79c (was +4): removing the SFX makeup cost the stinger 4 dB net (point rise +5.2 -> +3.7 LU); file peak -10 -> -3
	# WK-163: sax + crowd on the Stingers bus (was +9 / +2 on SFX, flattened by its compressor: goal rise +5.3 LU)
	play_sfx("goal_red" if int(team) == 0 else "goal_blue", {"volume_db": GOAL_SAX_DB, "pitch_var": 0.0, "protect": true,
		"bus": _stinger_bus})
	play_sfx("goal_crowd", {"volume_db": GOAL_CROWD_DB, "pitch_var": 0.03, "protect": true, "bus": _stinger_bus})
	play_sfx("ball_body", {"volume_db": -5.0, "pitch": 0.8, "pitch_var": 0.0})   # net-bulge thump

var last_goal_own := false       # QA: was the most recent voiced goal an own goal

## WK-121 Dropshot floor tiles: hit 1 = a dry crack (bright, quiet - it lands on top of the ball's own
## floor bounce), hit 2 = a gritty crunch + low knock as the hole opens (the warning that a point is coming).
func _on_drop_tile_hit(_tile, broken) -> void:
	if bool(broken):
		play_sfx("tile_break", {"volume_db": -4.0, "pitch": 0.95, "pitch_var": 0.06})
		play_sfx("tile_break_body", {"volume_db": -8.0, "pitch": 0.9, "pitch_var": 0.05})
	else:
		play_sfx("tile_crack", {"volume_db": -6.0, "pitch": 1.5, "pitch_var": 0.08})   # WK-79b (was -9 / 1.15: 170 Hz centroid, buried)

## WK-53 bleat / taunt (EventBus.bleated). Each hero has its own goat; a ghost plays the ghost variant +3 st.
## Rate limit per player (same numbers as the ghost spec: one per ghost_bleat_min_interval, <= ghost_bleat_max_per_s
## in any second) + a global cap of BLEAT_MAX_VOICES live bleats; bleats are PRIORITY tier (WK-132: they
## steal filler / normal voices, never another priority sound unless the pool is all priority).
## Wall-clock based, so it also holds on the ScoreScreen / while paused.
func _on_bleated(player_idx, ghost) -> void:
	bleats_seen += 1
	var idx: int = int(player_idx)
	var is_ghost: bool = bool(ghost)
	var now: int = Time.get_ticks_msec()
	var hist: Array = (_bleat_hist.get(idx, []) as Array).filter(func(t) -> bool: return now - int(t) < 1000)
	if not hist.is_empty() and float(now - int(hist.back())) / 1000.0 < Tuning.ghost_bleat_min_interval:
		_bleat_hist[idx] = hist
		return
	if hist.size() >= Tuning.ghost_bleat_max_per_s:
		_bleat_hist[idx] = hist
		return
	if voices_tagged("bleat") >= BLEAT_MAX_VOICES:
		return
	var v: Dictionary = _bleat_voice(idx)
	var key: String = ("bleat_ghost_" if is_ghost else "bleat_") + str(v["hero"])
	var pitch: float = float(v["pitch"]) * (BLEAT_GHOST_PITCH if is_ghost else 1.0)
	var db: float = (BLEAT_GHOST_DB if is_ghost else BLEAT_DB) + float(v["db"])
	var before := sfx_fired
	play_sfx(key, {"pitch": pitch, "pitch_var": BLEAT_PITCH_VAR, "volume_db": db, "tag": "bleat"})
	if sfx_fired == before:
		return   # pool full (or file missing): dropped, not counted against the rate limit
	hist.append(now)
	_bleat_hist[idx] = hist
	bleats_heard += 1
	bleat_log.append({"ms": now, "idx": idx, "ghost": is_ghost, "key": key, "pitch": snappedf(pitch, 0.001)})
	if bleat_log.size() > 32:
		bleat_log.pop_front()

## The bleating player's hero voice: their worn skin (living Player, else their GhostGoat), else a stable pick by idx.
func _bleat_voice(idx: int) -> Dictionary:
	var skin := ""
	var scene := get_tree().current_scene
	if scene != null and "players" in scene:
		var ps: Array = scene.players
		if idx >= 0 and idx < ps.size() and is_instance_valid(ps[idx]) and "skin" in ps[idx]:
			skin = str(ps[idx].skin)
	if skin == "" and scene != null and scene.has_method("ghost_director"):
		var gd = scene.ghost_director()
		if gd != null and gd.has_method("ghost_for"):
			var g = gd.ghost_for(idx)
			if g != null and "skin" in g:
				skin = str(g.skin)
	if BLEAT_BY_SKIN.has(skin):
		return BLEAT_BY_SKIN[skin]
	return {"hero": BLEAT_FALLBACK_ORDER[posmod(idx, BLEAT_FALLBACK_ORDER.size())], "pitch": 1.0, "db": 0.0}

# --------------------------------------------------------------------- WK-20e spawn-truce dry click
var super_locks_seen := 0        # QA: every EventBus.super_lock_pressed received  # WK-20e
var super_locks_heard := 0       # QA: clicks actually played (rest = the per-goat gap)  # WK-20e
var _lock_click_last := {}       # player instance id -> ms of its last click  # WK-20e

## WK-20e: a super press was dropped by the spawn truce (or the R4 re-arm gate) -> one soft dry click, rate-limited per goat.
func _on_super_lock_pressed(player) -> void:
	super_locks_seen += 1
	if player == null or not is_instance_valid(player):
		return
	var id: int = player.get_instance_id()
	var now: int = Time.get_ticks_msec()
	if now - int(_lock_click_last.get(id, -100000)) < int(Tuning.super_lock_click_gap * 1000.0):
		return
	_lock_click_last[id] = now
	play_sfx("super_locked", {"volume_db": Tuning.super_lock_click_db, "pitch": Tuning.super_lock_click_pitch,
		"pitch_var": 0.04, "tag": "super_locked:%d" % id})
	super_locks_heard += 1

## WK-26: a goat entered super AIM -> the rising wind-up, held only while that aim lasts (_tick_aim_voices fades it).
func _on_super_aim_started(player) -> void:
	super_aims_seen += 1
	if player == null or not is_instance_valid(player):
		return
	var id: int = player.get_instance_id()
	_release_aim_voice(id)   # never two wind-ups for one goat
	var tag := "super_aim:%d" % id
	var before := sfx_fired
	play_sfx("super_aim", {"volume_db": SUPER_AIM_DB, "pitch_var": 0.0, "tag": tag})
	if sfx_fired == before:
		return
	for v in _pool:
		if v.playing and str(v.get_meta("tag", "")) == tag:
			_aim_voices[id] = {"p": player, "v": v, "tag": tag, "fade": false}
			super_aims_heard += 1
			break

func _tick_aim_voices(delta: float) -> void:
	if _aim_voices.is_empty():
		return
	var paused: bool = get_tree().paused
	for id in _aim_voices.keys():
		var e: Dictionary = _aim_voices[id]
		var v: AudioStreamPlayer = e["v"]
		if not v.playing or str(v.get_meta("tag", "")) != str(e["tag"]):
			_aim_voices.erase(id)   # finished (the 2 s cap) or its voice was recycled
			continue
		var p = e["p"]
		var holding: bool = is_instance_valid(p) and not p.is_dead() and p.is_super_aiming() 			and not bool(p.get("frozen")) and not paused
		if holding and not bool(e["fade"]):
			continue
		e["fade"] = true
		v.volume_db -= 40.0 * delta / SUPER_AIM_FADE
		if v.volume_db <= SUPER_AIM_DB - 40.0:
			_release_aim_voice(id)

func _release_aim_voice(id: int) -> void:
	if not _aim_voices.has(id):
		return
	var e: Dictionary = _aim_voices[id]
	var v: AudioStreamPlayer = e["v"]
	if v.playing and str(v.get_meta("tag", "")) == str(e["tag"]):
		v.stop()
		v.set_meta("tag", "")
	_aim_voices.erase(id)

# --------------------------------------------------------------------- WK-131 kickoff gates

const GATE_CLONK_BASE_PITCH := 1.25   # lifts the ~230 Hz wood knock into the brief's 250-400 Hz body (x 0.9-1.15 by speed)
const GATE_CLONK_DB_SOFT := -12.0
const GATE_CLONK_DB_HARD := -3.0      # under a power shot (-1), over a soft ball tap
const GATE_CLONK_GAP := 0.08          # s: a ball pinned on the gate re-contacting can't machine-gun the clonk
const GATE_OOH_GAP := 1.5             # s rate limit on the crowd ooh (brief §11)
const GATE_TICK_DB := -9.0
const GATE_WHISTLE_DB := -2.0         # WK-79b (was 0: file peak -1.4 sat at the limiter): loudest gate cue, under the goal stinger (+4)
var gate_clonks := 0                  # QA counters (audio has no visual proof)
var gate_oohs_wanted := 0             # hard hits that WANT the ooh (silent until a crowd_ooh asset exists)
var gate_ticks := 0
var gate_whistles := 0
var gate_whistle_ms := -1             # Time.get_ticks_msec() of the last whistle (QA: lines up with the open)
var _gate_clonk_last := -10.0
var _gate_ooh_last := -10.0

## A ball clonked off a closed kickoff gate: hollow knock pitched and scaled by impact speed, a quiet rubbery boing tail,
## and (>= Tuning.sports_gate_ooh_speed) the crowd ooh. No hit-stop, no shake: it is a block, not a goal.
func _on_kickoff_gate_hit(_team, speed) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var v: float = float(speed)
	if now - _gate_clonk_last >= GATE_CLONK_GAP:
		_gate_clonk_last = now
		var t: float = clampf(inverse_lerp(Tuning.sports_gate_fx_min_speed, 2400.0, v), 0.0, 1.0)
		play_sfx("gate_clonk", {"volume_db": lerpf(GATE_CLONK_DB_SOFT, GATE_CLONK_DB_HARD, t),
			"pitch": GATE_CLONK_BASE_PITCH * lerpf(1.15, 0.9, t), "pitch_var": 0.03})
		play_sfx("gate_boing", {"volume_db": lerpf(-22.0, -15.0, t), "pitch": 0.72, "pitch_var": 0.04, "tier": TIER_FILLER})
		gate_clonks += 1
	if v >= Tuning.sports_gate_ooh_speed and now - _gate_ooh_last >= GATE_OOH_GAP:
		_gate_ooh_last = now
		gate_oohs_wanted += 1
		play_sfx("crowd_ooh", {"volume_db": -8.0, "pitch_var": 0.03})   # no-op until an asset is listed

func _on_kickoff_gates_open() -> void:
	play_sfx("whistle_double", {"volume_db": GATE_WHISTLE_DB, "pitch_var": 0.0})
	play_sfx("gate_whine", {"volume_db": GATE_TICK_DB + 3.0, "pitch": 1.6, "pitch_var": 0.0})   # the ratchet's final click on T
	gate_whistles += 1
	gate_whistle_ms = Time.get_ticks_msec()

func _on_kickoff_gate_dropped() -> void:
	play_sfx("gate_clonk", {"volume_db": -8.0, "pitch": GATE_CLONK_BASE_PITCH * 1.2, "pitch_var": 0.02})

func _on_kickoff_gate_tick(n) -> void:
	gate_ticks += 1
	play_sfx("gate_whine", {"volume_db": GATE_TICK_DB, "pitch": minf(1.0 + 0.12 * float(n), 1.5), "pitch_var": 0.0})

# --------------------------------------------------------------------- WK-116 pressure nets

const PRESSURE_BED_STREAM := "res://assets/sfx/crowd_murmur_loop.ogg"
const PRESSURE_CHANT_STREAM := "res://assets/sfx/crowd_clap_loop.ogg"
const PRESSURE_OFF_DB := -60.0
const PRESSURE_BED_IN_RATE := 60.0     # dB/s: the bed's first fade-in from silence to Tuning.sports_pressure_bed_db_lo
const PRESSURE_CHANT_IN_S := 0.4       # s the chant takes to fade in at step 2
const PRESSURE_CHUNK_DELAY := 0.07     # s between the "ka" and the "CHUNK"
const PRESSURE_MOUTH_STAGGER := 0.035  # s between the two mouths' ka-CHUNKs (one per mouth, thicker than one)
var pressure_events: Array = []        # QA: every EventBus.sports_pressure step received this session
var _pressure_bed: AudioStreamPlayer = null
var _pressure_chant: AudioStreamPlayer = null
var _bed_db := PRESSURE_OFF_DB
var _bed_goal := PRESSURE_OFF_DB       # where the bed is heading
var _bed_rate := 0.0                   # dB/s toward _bed_goal
var _bed_next := PRESSURE_OFF_DB       # second leg (the +6 dB swell) after the fade-in reaches bed_db_lo
var _bed_next_rate := 0.0
var _chant_db := PRESSURE_OFF_DB
var _chant_goal := PRESSURE_OFF_DB
var _chant_rate := 0.0

func _pressure_loop(path: String) -> AudioStreamPlayer:
	var pl := AudioStreamPlayer.new()
	pl.bus = "SFX"
	pl.volume_db = PRESSURE_OFF_DB
	var st := _stream(path)
	if st != null:
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		pl.stream = st
	add_child(pl)
	return pl

## step 0 anticipation: the murmur bed fades in, then swells +6 dB over warn_s. 1: ka-CHUNK per mouth + crowd OOOH. 2: heavier
## ka-CHUNK per mouth + the clap-chant loop (until the goal). -1: bed + chant fade out (the goal roar takes over).
func _on_sports_pressure(step) -> void:
	var st: int = int(step)
	pressure_events.append(st)
	if _pressure_bed == null:
		_pressure_bed = _pressure_loop(PRESSURE_BED_STREAM)
		_pressure_chant = _pressure_loop(PRESSURE_CHANT_STREAM)
	var lo: float = Tuning.sports_pressure_bed_db_lo
	var hi: float = Tuning.sports_pressure_bed_db_hi
	match st:
		0:
			_bed_start(lo, PRESSURE_BED_IN_RATE)
			_bed_next = hi
			_bed_next_rate = absf(hi - lo) / maxf(Tuning.sports_pressure_warn_s, 0.05)
		1, 2:
			if _bed_goal < hi - 0.01 and _bed_next < hi - 0.01:   # the anticipation was skipped (warn 0): straight to the swell level
				_bed_start(hi, PRESSURE_BED_IN_RATE)
			var heavy: bool = st == 2
			_pressure_clunk(heavy, 0.0)
			_pressure_clunk(heavy, PRESSURE_MOUTH_STAGGER)
			if not heavy:
				play_sfx("pressure_ooh", {"volume_db": Tuning.sports_pressure_ooh_db, "pitch": 0.74, "pitch_var": 0.02})
			else:
				if _pressure_chant != null and _pressure_chant.stream != null:
					if not _pressure_chant.playing:
						_chant_db = PRESSURE_OFF_DB
						_pressure_chant.volume_db = _chant_db
						_pressure_chant.play()
					_chant_goal = Tuning.sports_pressure_chant_db
					_chant_rate = absf(_chant_goal - PRESSURE_OFF_DB) / PRESSURE_CHANT_IN_S
		-1:
			var fo: float = maxf(Tuning.sports_pressure_fade_out_s, 0.01)
			_bed_goal = PRESSURE_OFF_DB
			_bed_rate = absf(_bed_db - PRESSURE_OFF_DB) / fo
			_bed_next = PRESSURE_OFF_DB
			_bed_next_rate = 0.0
			_chant_goal = PRESSURE_OFF_DB
			_chant_rate = absf(_chant_db - PRESSURE_OFF_DB) / fo

func _bed_start(goal: float, rate: float) -> void:
	if _pressure_bed == null or _pressure_bed.stream == null:
		return
	if not _pressure_bed.playing:
		_bed_db = PRESSURE_OFF_DB
		_pressure_bed.volume_db = _bed_db
		_pressure_bed.play()
	_bed_goal = goal
	_bed_rate = rate
	_bed_next = goal
	_bed_next_rate = 0.0

## One mouth's two-hit mechanical ka-CHUNK (step 2: lower, +3 dB, with a slam under the CHUNK).
func _pressure_clunk(heavy: bool, delay: float) -> void:
	var db: float = Tuning.sports_pressure_clunk_db + (3.0 if heavy else 0.0)
	var ka := func() -> void:
		play_sfx("pressure_ka", {"volume_db": db - 3.0, "pitch": 1.25 if heavy else 1.5, "pitch_var": 0.04})
	var chunk := func() -> void:
		play_sfx("pressure_chunk", {"volume_db": db, "pitch": 0.62 if heavy else 0.78, "pitch_var": 0.03})
		if heavy:
			play_sfx("pressure_slam", {"volume_db": db - 5.0, "pitch": 0.7, "pitch_var": 0.03})
	if delay <= 0.0:
		ka.call()
	else:
		get_tree().create_timer(delay).timeout.connect(ka)
	get_tree().create_timer(delay + PRESSURE_CHUNK_DELAY).timeout.connect(chunk)

## Volume legs + pause: the loops pause with the game (this node always processes, so they are paused by hand).
func _tick_pressure_loops(delta: float) -> void:
	if _pressure_bed == null:
		return
	var paused: bool = get_tree().paused
	for pl in [_pressure_bed, _pressure_chant]:
		if pl != null and (pl.playing or pl.stream_paused):   # a paused player reports playing == false
			pl.stream_paused = paused
	if paused:
		return
	_bed_db = move_toward(_bed_db, _bed_goal, _bed_rate * delta)
	if is_equal_approx(_bed_db, _bed_goal) and _bed_next != _bed_goal:
		_bed_goal = _bed_next
		_bed_rate = _bed_next_rate
	_pressure_bed.volume_db = _bed_db
	if _bed_db <= PRESSURE_OFF_DB + 0.01 and _bed_goal <= PRESSURE_OFF_DB and _pressure_bed.playing:
		_pressure_bed.stop()
	_chant_db = move_toward(_chant_db, _chant_goal, _chant_rate * delta)
	_pressure_chant.volume_db = _chant_db
	if _chant_db <= PRESSURE_OFF_DB + 0.01 and _chant_goal <= PRESSURE_OFF_DB and _pressure_chant.playing:
		_pressure_chant.stop()

func _sports_active() -> bool:
	return not get_tree().get_nodes_in_group("sports_ball").is_empty()

## True when the victim is outside the running match's court bounds (fell through a hole / knocked out).
func _out_of_court(victim) -> bool:
	if victim == null or not is_instance_valid(victim) or not (victim is Node2D):
		return true
	var scene := get_tree().current_scene
	if scene == null or not ("bounds" in scene):
		return true
	var b: Rect2 = scene.bounds
	return not b.has_point((victim as Node2D).global_position)

# --------------------------------------------------------------------- thrust loop (read-only poll)

## WK-163: duck the SFX bed (bounces, thrust, aim, smashes) under a KO via the SFX bus "KODuck" Amplify effect. Not the bus
## volume: Settings owns that (slider). A KO during a duck restarts the hold from the current level (no snap to 0 dB).
func _start_ko_duck() -> void:
	if _duck_fx == null:
		return
	ko_ducks += 1
	var cur: float = _duck_fx.volume_db
	# re-enter the attack ramp at the point matching the current level so a re-trigger never jumps up
	_duck_t = KO_DUCK_ATTACK * clampf(cur / KO_DUCK_DB, 0.0, 1.0)

func _tick_ko_duck(delta: float) -> void:
	if _duck_fx == null or _duck_t < 0.0:
		return
	# real time: hit-stop / KO slow-mo scale delta (Juice sets Engine.time_scale), the duck must not stretch with it
	_duck_t += delta / maxf(Engine.time_scale, 0.05)
	var d: float
	if _duck_t < KO_DUCK_ATTACK:
		d = KO_DUCK_DB * _duck_t / KO_DUCK_ATTACK
	elif _duck_t < KO_DUCK_ATTACK + KO_DUCK_HOLD:
		d = KO_DUCK_DB
	elif _duck_t < KO_DUCK_ATTACK + KO_DUCK_HOLD + KO_DUCK_RELEASE:
		d = KO_DUCK_DB * (1.0 - (_duck_t - KO_DUCK_ATTACK - KO_DUCK_HOLD) / KO_DUCK_RELEASE)
	else:
		d = 0.0
		_duck_t = -1.0
	_duck_fx.volume_db = d

func _process(delta: float) -> void:
	_tick_ko_duck(delta)   # WK-163
	_tick_aim_voices(delta)   # WK-26
	_tick_pressure_loops(delta)   # WK-116
	var want := _any_boosting()
	thrust_active = want
	var target := THRUST_ON_DB if want else THRUST_OFF_DB
	_thrust_db = move_toward(_thrust_db, target, THRUST_FADE * 60.0 * delta)
	if _thrust != null:
		_thrust.volume_db = _thrust_db

func _any_boosting() -> bool:
	var scene := get_tree().current_scene
	if scene == null or not ("players" in scene):
		return false
	for p in scene.players:
		# WK-79b: a frozen goat (intro pop-in, countdown, STAGE_END, KO freeze) keeps _boosting_now latched while it holds
		# boost - the drone ran through every goal celebration + countdown after stage 1 (audit §2). Frozen = silent.
		if is_instance_valid(p) and p.has_method("is_boosting") and p.has_method("is_dead") \
				and not p.is_dead() and not bool(p.get("frozen")) and p.is_boosting():
			return true
	return false
