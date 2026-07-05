extends Node
## Settings autoload (v1_frontend_shell §4). Options persistence to user://settings.cfg (ConfigFile)
## + apply-on-boot to the AudioServer buses and the window mode. No UI here — this is the API the
## Options screen calls later. Changes are write-through (live apply + save; no "apply" button).
##
## Keys: section [audio] master/music/sfx (float 0.0..1.0); section [video] fullscreen (bool).
## Defaults (file absent): volumes 1.0, fullscreen false.
##
## VOLUME MAPPING — deviation from spec §4.3 (reported): §4.3 says db = linear_to_db(v) with the
## premise "100% = 0 dB = unchanged from today". That premise is false for the Music bus, which is
## baked at -8 dB in default_bus_layout.tres. The literal formula would slam Music to 0 dB on boot
## (+8 dB louder than today) — violating the spec's OWN overriding non-negotiable that the default
## boot behave byte-for-byte identically to today. So each bus's designed baseline dB (captured once
## at boot) is the "100%" reference: db = baseline + linear_to_db(v), floored to silence below ~1%.
## For Master/SFX (baseline 0 dB) this is identical to §4.3; only Music (baseline -8 dB) differs, and
## only to PRESERVE today's mix. The linear 0..1 value is what gets stored, per §4.3.

const PATH := "user://settings.cfg"
const SILENCE_DB := -80.0
const BUSES := {"master": "Master", "music": "Music", "sfx": "SFX"}

var master: float = 1.0
var music: float = 1.0
var sfx: float = 1.0
var fullscreen: bool = false

var _baseline_db: Dictionary = {}   # bus name -> designed baseline dB from the layout (100% reference)

func _ready() -> void:
	_capture_baselines()
	_load()
	_apply_all()

## Snapshot each bus's layout dB BEFORE we ever write to it, so 100% maps to today's mix.
func _capture_baselines() -> void:
	for key in BUSES:
		var bus_name: String = BUSES[key]
		var idx := AudioServer.get_bus_index(bus_name)
		_baseline_db[bus_name] = AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0

# ------------------------------------------------------------------- public API (Options screen)

func set_master(v: float) -> void:
	master = clampf(v, 0.0, 1.0)
	_apply_bus("master")
	_save()

func set_music(v: float) -> void:
	music = clampf(v, 0.0, 1.0)
	_apply_bus("music")
	_save()

func set_sfx(v: float) -> void:
	sfx = clampf(v, 0.0, 1.0)
	_apply_bus("sfx")
	_save()

func set_fullscreen(b: bool) -> void:
	fullscreen = b
	_apply_fullscreen()
	_save()

# ------------------------------------------------------------------- apply

func _apply_all() -> void:
	_apply_bus("master")
	_apply_bus("music")
	_apply_bus("sfx")
	_apply_fullscreen()

func _apply_bus(key: String) -> void:
	var bus_name: String = BUSES[key]
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var v: float = get(key)
	var baseline: float = _baseline_db.get(bus_name, 0.0)
	var db: float = SILENCE_DB if v <= 0.01 else baseline + linear_to_db(v)
	AudioServer.set_bus_volume_db(idx, db)

func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

# ------------------------------------------------------------------- persistence

func _load() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err != OK:
		_save()   # first run — write defaults so the file exists
		return
	master = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	sfx = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)
