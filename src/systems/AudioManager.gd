extends Node
## AudioManager (INV-12 presentation subscriber). The single owner of sound in GottaBounce:
## a pooled bank of AudioStreamPlayers for SFX (so overlapping hits don't cut each other), a
## looping jetpack-thrust voice, and a music voice. It NEVER calls into gameplay — it only
## SUBSCRIBES to EventBus / KillPipeline signals and reads state read-only. Autoloaded as
## `AudioManager` (below EventBus/KillPipeline/PowerupSystem, which it depends on).
##
## Buses (res://default_bus_layout.tres): Master -> Music, SFX. SFX players route to "SFX",
## music/thrust as noted. No class_name (autoload rule); entity types are duck-typed, never
## referenced by class_name at parse time.
##
## Event map lives in owner directive docs/feedback/owner_2026-07-04_arena_variety.md §2.

# --- event -> candidate stream paths (arrays = pick one at random for variation) ---
const SFX := {
	"bounce":            ["res://assets/sfx/spring.mp3", "res://assets/sfx/balloon_pop.mp3"],
	"smash":             ["res://assets/sfx/impact1.mp3", "res://assets/sfx/impact2.mp3", "res://assets/sfx/impact3.mp3"],
	"smash_heavy":       ["res://assets/sfx/slam.mp3"],
	"super_fire":        ["res://assets/sfx/explosion_boss.mp3"],   # owner pick 2026-07-18 (was combo_bigRoar)
	"death":             ["res://assets/sfx/mm_quickdie.mp3"],
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
}
const MUSIC_GAMEPLAY := [
	"res://assets/music/gameplay_1.mp3", "res://assets/music/gameplay_2.mp3",
	"res://assets/music/gameplay_3.mp3", "res://assets/music/gameplay_4.mp3",
]
const MUSIC_SCOREBOARD := "res://assets/music/scoreboard.mp3"
const MUSIC_MENU := "res://assets/music/title.wav"
const THRUST_STREAM := "res://assets/sfx/coke_blast.mp3"   # owner pick 2026-07-18 (was fireLoop); looped jetpack voice

const POOL_SIZE := 14
const THRUST_ON_DB := -7.0
const THRUST_OFF_DB := -60.0
const THRUST_FADE := 10.0        # db/sec toward target

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
	KillPipeline.killed.connect(_on_killed)

# --------------------------------------------------------------------- core play API

## Fire a one-shot SFX by event key. opts: {pitch: float, pitch_var: float, volume_db: float,
## path: String (force a specific stream)}. Round-robins the pool so overlapping sounds coexist.
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
	var pl := _grab()
	pl.stream = stream
	var pitch: float = float(opts.get("pitch", 1.0))
	var pvar: float = float(opts.get("pitch_var", 0.06))
	pl.pitch_scale = clampf(pitch + randf_range(-pvar, pvar), 0.4, 2.5)
	pl.volume_db = float(opts.get("volume_db", 0.0))
	pl.play()
	sfx_fired += 1
	last_sfx = name

func _grab() -> AudioStreamPlayer:
	# prefer a free voice; otherwise steal the next in round-robin (oldest-ish)
	for i in range(_pool.size()):
		var idx := (_next + i) % _pool.size()
		if not _pool[idx].playing:
			_next = (idx + 1) % _pool.size()
			return _pool[idx]
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	return p

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

func _on_surface_bounced(surface, _player, _normal, _contact) -> void:
	# per-tier pitch: taller-tier surfaces read lower/bigger, small tiers ping higher (spec §2 nice-to-have)
	var pitch := 1.0
	if surface != null and is_instance_valid(surface):
		if surface.has_meta("bounce_tier_height"):
			var h: float = float(surface.get_meta("bounce_tier_height"))
			var ref: float = maxf(Tuning.bounce_height_trampoline, 1.0)
			pitch = clampf(sqrt(ref / maxf(h, 1.0)), 0.8, 1.35)
		elif surface.has_meta("bumper"):
			pitch = 1.25   # bumpers ping bright
	play_sfx("bounce", {"pitch": pitch, "pitch_var": 0.08, "volume_db": -4.0})

func _on_smashed(_attacker, _victim, impulse) -> void:
	# volume scaled by hit solidity (impulse magnitude vs a full super blast)
	var t := clampf(impulse.length() / maxf(Tuning.super_boost_impulse_full, 1.0), 0.0, 1.0)
	var db := lerpf(-10.0, 2.0, t)
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
	play_sfx("death_whoosh", {"volume_db": -15.0, "pitch": 0.62, "pitch_var": 0.05})

func _on_super_boosted(_player) -> void:
	play_sfx("super_fire", {"volume_db": -2.0, "pitch_var": 0.08})

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
	play_sfx("go", {"volume_db": 0.0})

func _on_match_started() -> void:
	play_music(MUSIC_GAMEPLAY[randi() % MUSIC_GAMEPLAY.size()], true, 0.0)

func _on_match_won(_widx) -> void:
	play_sfx("match_win", {"volume_db": 0.0})
	play_music(MUSIC_SCOREBOARD, true, 0.0)

func _on_first_blood(_ai) -> void:
	play_sfx("first_blood", {"volume_db": -1.0})

func _on_two_left() -> void:
	play_sfx("two_left", {"volume_db": -2.0})

func _on_killed(_victim, cause, _attacker) -> void:
	# off-screen / ring-out kills get the whoosh-out; other causes just the death pop
	if str(cause) == "ring_out":
		play_sfx("death_whoosh", {"volume_db": -3.0})
	play_sfx("death", {"volume_db": -3.0, "pitch_var": 0.1})

# --------------------------------------------------------------------- thrust loop (read-only poll)

func _process(delta: float) -> void:
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
		if is_instance_valid(p) and p.has_method("is_boosting") and p.has_method("is_dead") \
				and not p.is_dead() and p.is_boosting():
			return true
	return false
