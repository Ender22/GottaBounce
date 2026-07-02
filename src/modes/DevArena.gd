class_name DevArena
extends Node2D
## Minimal dev match (v0 throwaway glue on keeper seams — ARCHITECTURE §3): loads one JSON level,
## spawns 1 human (P1, action-map input) + 3 bots, wires CameraController + Juice + KillPipeline,
## and respawns the dead at a spawn point after a short delay. NO menus, NO scoring yet.
## Exposes the arena contract InputBot + Playtest rely on: players / scores / bounds /
## nearest_opponent() / stage_rect() / stage_center().

const LEVEL_PATH := "res://levels/dev_arena.json"
const RESPAWN_DELAY := 1.0
const BOT_LEVEL := 3
const NUM_BOTS := 3
# Character skins: P1 is always pink; bots take blue/green/yellow in order.
const BOT_SKINS: Array[String] = ["blue", "green", "yellow"]

var bounds: Rect2
var players: Array = []
var scores: Array = []   # v0: no scoring yet — zeros, kept so Playtest/bots see the contract

var _spawns: Array = []
var _stage_rect := Rect2(0, 0, 1920, 320)
var _camera: CameraController
var _juice: Juice
var _level_root: Node2D
const CAM_MIN_ZOOM := 0.42   # most zoomed-out (big blast zone visible)
const CAM_MAX_ZOOM := 0.92   # never zoom in tighter than this

func _ready() -> void:
	bounds = Rect2(-120, -120, 2160, 1380)
	_level_root = Node2D.new()
	add_child(_level_root)
	_load_stage(LEVEL_PATH)

	_camera = CameraController.new()
	_camera.position = _stage_rect.get_center()
	_camera.dynamic = true   # Smash-style: follow the action and zoom to keep everyone on screen
	add_child(_camera)
	_camera.snap_to(_stage_rect.get_center(), CAM_MAX_ZOOM)
	_juice = Juice.new()
	add_child(_juice)
	_juice.setup(_camera)
	KillPipeline.killed.connect(_on_killed)

	# P1 human + bots
	_spawn_player(0, true)
	for b in range(NUM_BOTS):
		_spawn_player(1 + b, false)

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
		p.set_provider(InputBot.new(p, self, BOT_LEVEL))

func _load_stage(path: String) -> void:
	for c in _level_root.get_children():
		c.queue_free()
	var data := LevelLoader.load_level(path, _level_root)
	_spawns = data.get("spawns", [])
	bounds = data.get("bounds", Rect2(-120, -120, 2160, 1380))
	_stage_rect = data.get("play_rect", Rect2(bounds.get_center() - Vector2(900, 160), Vector2(1800, 320)))

func _physics_process(_delta: float) -> void:
	_update_camera()
	for p in players:
		if is_instance_valid(p) and not p.is_dead():
			if not bounds.has_point(p.global_position):
				p.kill(&"ring_out", null)

## Frame the stage + all living fighters, zooming out as they spread (Smash-style).
func _update_camera() -> void:
	if _camera == null:
		return
	var mn := _stage_rect.position
	var mx := _stage_rect.end
	for p in players:
		if is_instance_valid(p) and not p.is_dead():
			mn = mn.min(p.global_position)
			mx = mx.max(p.global_position)
	var margin := Vector2(420.0, 340.0)
	mn -= margin
	mx += margin
	var size := mx - mn
	var z := minf(1920.0 / maxf(size.x, 1.0), 1080.0 / maxf(size.y, 1.0))
	z = clampf(z, CAM_MIN_ZOOM, CAM_MAX_ZOOM)
	_camera.set_frame((mn + mx) * 0.5, z)

func _on_killed(victim, _cause, _attacker) -> void:
	var idx := players.find(victim)
	if idx < 0:
		return
	# simple dev respawn: back at your spawn point after a beat (no lives / scoring yet)
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(func() -> void:
		if is_instance_valid(victim) and victim.is_dead():
			victim.respawn(_spawn_at(idx))
	)

func stage_center() -> Vector2:
	return _stage_rect.get_center()

func stage_rect() -> Rect2:
	return _stage_rect

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
