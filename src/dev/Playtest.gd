extends Node
## Headless playtest probe (dev tool). Runs the dev arena (Arena.tscn) with scripted/null input and
## logs physics + match state, so an AI/dev can measure feel and catch bugs (runaway speed,
## tunneling, bot suicide loops) without a human at the keyboard.
##
## Run:  Godot --headless --path <proj> res://scenes/Playtest.tscn -- <mode> <seconds>
##   mode = observe : P1 does NOTHING (watch the bot; P1 just bounces in place)
##   mode = hover   : P1 scripted jetpack traversal (measures speed/gravity feel)
##   mode = duel    : P1 scripted simple fighter vs bot
##   mode = botwar  : P1 replaced by a level-4 bot (bot-vs-bot combat)
## Prints a summary block and quits.
## (v0 port: campaign / loadcheck modes return with their systems.)

const FLOOR_TUNNEL_Y := 1860.0   # below the arena's bottom blast line; an ALIVE player here = real tunneling
                                 # (the void/pit above this is legit Smash-style recovery space)

var _main: Node2D
var _t := 0.0
var _dur := 20.0
var _mode := "observe"
var _log_t := 0.0
var _ringouts := {}          # player_index -> count
var _kills := {}             # attacker_index -> count
var _max_speed := {}         # player_index -> float
var _bounces := 0
var _tunnel_frames := 0
var _max_speed_seen := 0.0
var _installed := false

# Scripted input provider: list of phases [secs, aim:Vector2, boost:bool, super:bool]
class ScriptProvider:
	extends RefCounted
	var phases: Array = []
	var _t := 0.0
	var _intent := InputIntent.new()
	func _init(p: Array) -> void:
		phases = p
	func poll() -> InputIntent:
		# advance by the real physics tick (the old 1/60 hardcode ran phases 2x fast at 120 tps)
		_t += 1.0 / float(Engine.physics_ticks_per_second)
		var acc := 0.0
		var cur = phases[phases.size() - 1] if phases.size() > 0 else [999.0, Vector2.ZERO, false, false]
		for ph in phases:
			acc += ph[0]
			if _t <= acc:
				cur = ph
				break
		_intent.aim = cur[1]
		_intent.boost = cur[2]
		_intent.super_boost = cur[3]
		_intent.use_powerup = false
		_intent.flap = false
		return _intent

func _ready() -> void:
	var uargs := OS.get_cmdline_user_args()
	if uargs.size() > 0:
		_mode = str(uargs[0])
	if uargs.size() > 1:
		_dur = float(uargs[1])
	KillPipeline.killed.connect(_on_killed)
	EventBus.bounced.connect(func(_b): _bounces += 1)
	var main_scene = load("res://scenes/Arena.tscn")
	_main = main_scene.instantiate()
	add_child(_main)
	print("[PLAYTEST] mode=%s dur=%.0fs" % [_mode, _dur])

func _install_scripted() -> void:
	if _installed or _main == null:
		return
	var players: Array = _main.players
	if players.size() == 0:
		return
	_installed = true
	if _mode == "hover":
		# fly right across the arena, then up, then hover, then left
		var seq := [
			[3.0, Vector2.RIGHT, true, false],
			[2.0, Vector2(0.6, -0.8).normalized(), true, false],
			[3.0, Vector2.UP, true, false],
			[3.0, Vector2.LEFT, true, false],
			[9.0, Vector2.ZERO, false, false],
		]
		players[0].set_provider(ScriptProvider.new(seq))
	elif _mode == "botwar":
		# make P0 a bot too, so we watch bot-vs-bot combat (do they fight or suicide?)
		players[0].set_provider(InputBot.new(players[0], _main, 4))
	elif _mode == "duel":
		# crude chaser: aim toward arena center-ish and boost in pulses
		var seq := [
			[1.0, Vector2.UP, true, false],
			[1.0, Vector2.RIGHT, true, false],
			[1.0, Vector2.LEFT, false, false],
		]
		players[0].set_provider(ScriptProvider.new(seq))

func _physics_process(delta: float) -> void:
	if _main == null:
		return
	_install_scripted()
	_t += delta
	var players: Array = _main.players
	for i in range(players.size()):
		var p = players[i]
		if not is_instance_valid(p):
			continue
		var spd: float = p.velocity.length()
		_max_speed[i] = maxf(_max_speed.get(i, 0.0), spd)
		_max_speed_seen = maxf(_max_speed_seen, spd)
		if not p.is_dead() and p.global_position.y > FLOOR_TUNNEL_Y:
			_tunnel_frames += 1

	_log_t += delta
	if _log_t >= 1.0:
		_log_t = 0.0
		var parts: Array = []
		for i in range(players.size()):
			var p = players[i]
			if not is_instance_valid(p):
				parts.append("P%d:gone" % i)
				continue
			parts.append("P%d pos(%.0f,%.0f) spd%.0f fuel%.0f%s" % [
				i, p.global_position.x, p.global_position.y, p.velocity.length(),
				p.fuel, " DEAD" if p.is_dead() else ""])
		print("[t=%5.1f] %s | bounces=%d" % [_t, " | ".join(parts), _bounces])

	if _t >= _dur:
		_summary()
		get_tree().quit()

func _on_killed(victim, cause, attacker) -> void:
	var players: Array = _main.players
	var vi: int = players.find(victim)
	if attacker != null and attacker != victim:
		var ai: int = players.find(attacker)
		if ai >= 0:
			_kills[ai] = _kills.get(ai, 0) + 1
		print("   >> KILL: P%d killed P%d (%s)" % [ai, vi, str(cause)])
	else:
		_ringouts[vi] = _ringouts.get(vi, 0) + 1
		print("   >> RINGOUT/SUICIDE: P%d (%s)" % [vi, str(cause)])

func _summary() -> void:
	print("\n========== PLAYTEST SUMMARY (mode=%s, %.0fs) ==========" % [_mode, _dur])
	print("max speed seen (any player): %.0f px/s" % _max_speed_seen)
	print("tunnel frames (alive player below floor): %d" % _tunnel_frames)
	print("total bounces: %d" % _bounces)
	print("per-player max speed: %s" % str(_max_speed))
	print("ringouts/suicides: %s" % str(_ringouts))
	print("kills: %s" % str(_kills))
	print("=======================================================\n")
