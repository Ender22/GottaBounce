extends Node
## WK-93 per-frame match logger (dev tool). Installed on the scene-tree ROOT by RecordBoot so it survives
## the change into the match scene. Read-only toward the sim except: (a) it swaps every seat to an InputBot
## at the levels given (incl. the human seat 0), (b) the optional pendulum_test QA fixture teleports a
## player into a pendulum's path. Writes tools/out/rec/<name>/data.json:
##   {meta, combat_frame, frames:[{f, t, st, p:[{i,l,x,y,sx,sy,vx,vy,a,sa,stun,dead,fuel}]}],
##    aim_windows:[{who,lvl,f0,f1,ticks,max_step_deg,mean_step_deg,sweep_deg,cap_deg_tick,fired,path_deg}],
##    events:[{f,t,type,...}], hazards:[{name,kind,contact_mode,contacts,fast_contacts,smashes,shoves,immune,log}]}
## f = Engine.get_frames_drawn() at sample time == the Movie Maker frame index (frame%08d.png) — the
## stamp label prints the same number into the image so alignment can be checked by eye.
## sx/sy are WINDOW pixel coordinates (what the PNG shows), a = aim angle in degrees (super-aim arrow while
## aiming, else the last stick aim), sa = super-aiming.

var cfg: Dictionary = {}

var _scene: Node = null
var _hooked := false
var _frames: Array = []
var _events: Array = []
var _aim_windows: Array = []
var _aim_open := {}            # player idx -> {who,lvl,f0,ticks,prev,steps:[],path:[]}
var _combat_frame := -1
var _combat_time := 0.0
var _game_t := 0.0
var _combat_acc := 0.0         # seconds spent in COMBAT / SUDDEN_DEATH (the `seconds` budget)
var _done := false
var _hazards: Array = []
var _pt_left := 0
var _pt_next := 0.0
var _pt_pending: Array = []    # {victim, hazard, smashes_before, deadline, f}
var _out_dir := ""
var _elim_stage := -1          # WK-37 QA fixture: stage index the `eliminate` seats were last knocked out in
var _elim_t := 0.0
var _shot_stage := -1          # WK-159 QA fixture: stage index the `ball_shot` last fired in
var _shot_t := 0.0             # WK-159
var _ball_track: Array = []    # WK-159: [{f, t, st, x, y, in, scored}] while the fixture is on

@onready var _stamp: Label = $Stamp/Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out_dir = ProjectSettings.globalize_path("res://tools/out/rec/%s" % str(cfg.get("name", "rec")))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var gdi := ProjectSettings.globalize_path("res://tools/out/rec/.gdignore")
	if not FileAccess.file_exists(gdi):
		var fi := FileAccess.open(gdi, FileAccess.WRITE)
		if fi != null:
			fi.close()
	_pt_left = int(cfg.get("pendulum_test", 0))
	$Stamp.visible = bool(cfg.get("stamp", true))

func _hook(cs: Node) -> void:
	_scene = cs
	_hooked = true
	var levels: Array = cfg.get("levels", [3, 3, 3, 3])
	var players: Array = cs.get("players")
	for i in range(players.size()):
		var p = players[i]
		var lvl: int = int(levels[i]) if i < levels.size() else 3
		if (cfg.get("lock_press", []) as Array).has(i):   # WK-20e QA fixture: super presses during the spawn blink
			p.set_provider(LockPressBot.new(p, cs, lvl))
		else:
			p.set_provider(InputBot.new(p, cs, lvl))
		if p.is_in_group("human"):
			p.remove_from_group("human")
	EventBus.super_fired.connect(_on_super_fired)
	EventBus.smashed.connect(_on_smashed)
	EventBus.hazard_shoved.connect(_on_hazard_shoved)
	KillPipeline.killed.connect(_on_killed)
	if not EventBus.bleated.is_connected(_on_bleated):
		EventBus.bleated.connect(_on_bleated)
	if not EventBus.super_lock_pressed.is_connected(_on_super_lock_pressed):   # WK-20e
		EventBus.super_lock_pressed.connect(_on_super_lock_pressed)
	_collect_hazards(cs)

func _collect_hazards(n: Node) -> void:
	for c in n.get_children():
		if c is MovingHazard and not _hazards.has(c):
			_hazards.append(c)
			c.tree_exiting.connect(_snapshot_hazard.bind(c))
		_collect_hazards(c)

## Keep a freed hazard's QA counters (stage rotation frees the level between stages).
var _hz_done: Array = []
func _snapshot_hazard(h) -> void:
	if is_instance_valid(h):
		_hz_done.append(_hz_row(h))

func _retire_hazards() -> void:
	_hazards = _hazards.filter(func(h) -> bool: return is_instance_valid(h))

func _hz_row(h) -> Dictionary:
	return {"name": str(h.name), "kind": h.kind, "contact_mode": h.contact_mode,
		"contacts": h.qa_contacts, "fast_contacts": h.qa_fast_contacts, "smashes": h.qa_smashes,
		"shoves": h.qa_shoves, "immune": h.qa_immune, "log": h.qa_log}

func _process(delta: float) -> void:
	if _done:
		return
	var cs := get_tree().current_scene
	if cs == null or not ("players" in cs):
		return
	if not _hooked or cs != _scene:
		_hazards.clear()
		_hook(cs)
	var players: Array = cs.get("players")
	if players.is_empty():
		return
	_game_t += delta
	var st: String = str(cs.get("state"))
	if _combat_frame < 0 and st == "COMBAT":
		_combat_frame = Engine.get_frames_drawn()
		_combat_time = _game_t
		_pt_next = _game_t + 1.5
		_ev("combat_start", {})
	var alive_hz: Array = _hazards.filter(func(h) -> bool: return is_instance_valid(h))
	if alive_hz.size() != _hazards.size() or _hazards.is_empty():
		_retire_hazards()
		_collect_hazards(cs)   # stage rotation rebuilt the level
	_sample(players, st)
	if _stamp.visible:
		_stamp.text = "REC f%d  t%.2fs  %s" % [Engine.get_frames_drawn(), _game_t, st]
	if st == "COMBAT" or st == "SUDDEN_DEATH":
		_combat_acc += delta
	if _combat_frame >= 0:
		_tick_pendulum_test(players)
		_tick_eliminate(st)
		_tick_ball_shot(st)   # WK-159
		if _combat_acc >= float(cfg.get("seconds", 20.0)):
			_finish()

func _physics_process(_delta: float) -> void:
	if _done or not _hooked or _scene == null or not is_instance_valid(_scene):
		return
	var players: Array = _scene.get("players")
	var levels: Array = cfg.get("levels", [])
	for i in range(players.size()):
		var p = players[i]
		if not is_instance_valid(p):
			continue
		var aiming: bool = p.is_super_aiming()
		if aiming:
			var ang: float = p.get_super_aim_dir().angle()
			if not _aim_open.has(i):
				_aim_open[i] = {"who": i, "lvl": int(levels[i]) if i < levels.size() else 3,
					"f0": Engine.get_frames_drawn(), "ticks": 0, "prev": ang, "steps": [], "path": [rad_to_deg(ang)],
					"start": ang}
			else:
				var w: Dictionary = _aim_open[i]
				var step: float = absf(angle_difference(float(w["prev"]), ang))
				(w["steps"] as Array).append(step)
				(w["path"] as Array).append(rad_to_deg(ang))
				w["prev"] = ang
				w["ticks"] = int(w["ticks"]) + 1
		elif _aim_open.has(i):
			_close_aim(i, p)
	# pendulum_test resolution (did the dropped player get smashed?)
	for e in _pt_pending.duplicate():
		var hz = e["hazard"]
		if not is_instance_valid(hz):
			_pt_pending.erase(e)
			continue
		if int(hz.qa_smashes) > int(e["smashes_before"]) or _game_t >= float(e["deadline"]):
			var ok: bool = int(hz.qa_smashes) > int(e["smashes_before"])
			_ev("pendulum_test_result", {"victim": e["victim"], "smashed": ok, "dropped_f": e["f"]})
			_pt_pending.erase(e)

func _close_aim(i: int, p) -> void:
	var w: Dictionary = _aim_open[i]
	_aim_open.erase(i)
	var steps: Array = w["steps"]
	var mx := 0.0
	var sum := 0.0
	for s in steps:
		mx = maxf(mx, float(s))
		sum += float(s)
	var lvl: int = int(w["lvl"])
	var rates: Array = Tuning.bot_aim_turn_rate
	var cap_tick: float = float(rates[clampi(lvl - 1, 0, rates.size() - 1)]) / float(Engine.physics_ticks_per_second)
	_aim_windows.append({
		"who": int(w["who"]), "lvl": lvl, "f0": int(w["f0"]), "f1": Engine.get_frames_drawn(),
		"ticks": int(w["ticks"]), "max_step_deg": rad_to_deg(mx),
		"mean_step_deg": rad_to_deg(sum / maxf(1.0, float(steps.size()))),
		"sweep_deg": rad_to_deg(absf(angle_difference(float(w["start"]), float(w["prev"])))),
		"cap_deg_tick": rad_to_deg(cap_tick),
		"fired": is_instance_valid(p) and not p.is_dead(),
		"path_deg": w["path"],
	})

func _sample(players: Array, st: String) -> void:
	var vp := get_viewport()
	var fin: Transform2D = vp.get_final_transform()
	var levels: Array = cfg.get("levels", [])
	var rows: Array = []
	for i in range(players.size()):
		var p = players[i]
		if not is_instance_valid(p):
			continue
		var scr: Vector2 = fin * p.get_global_transform_with_canvas().origin
		var aiming: bool = p.is_super_aiming()
		var aim: Vector2 = p.get_super_aim_dir() if aiming else p.get("_last_aim")
		rows.append({
			"i": i, "l": int(levels[i]) if i < levels.size() else 0,
			"x": snappedf(p.global_position.x, 0.1), "y": snappedf(p.global_position.y, 0.1),
			"sx": snappedf(scr.x, 0.1), "sy": snappedf(scr.y, 0.1),
			"vx": snappedf(p.velocity.x, 0.1), "vy": snappedf(p.velocity.y, 0.1),
			"a": snappedf(rad_to_deg(aim.angle()), 0.01), "sa": aiming,
			"stun": float(p.get("_stun_timer")) > 0.0, "dead": p.is_dead(),
			"fuel": snappedf(float(p.fuel), 0.1), "vis": p.visible,
			"b": p.is_boosting(), "sup": p.is_super_active(),   # WK-95: boost vs super state per goat
		})
	var hz: Array = []
	for h in _hazards:
		if is_instance_valid(h):
			var bp: Vector2 = h.ball_pos_at(h.qa_clock())
			var hs: Vector2 = fin * (h.get_global_transform_with_canvas() * bp)
			hz.append({"sx": snappedf(hs.x, 0.1), "sy": snappedf(hs.y, 0.1), "v": snappedf(h.ball_speed(), 1.0)})
	# WK-37 ghost goats: per-frame ghost + cloud rows (empty when GHOSTS OFF).
	var gh: Array = []
	var cl: Array = []
	var gd = _scene.get("_ghost_dir") if _scene != null and is_instance_valid(_scene) else null
	if gd != null and is_instance_valid(gd):
		for gi in gd.ghosts.keys():
			var g = gd.ghost_for(int(gi))
			if g == null:
				continue
			var gs: Vector2 = fin * g.get_global_transform_with_canvas().origin
			gh.append({"i": int(gi), "x": snappedf(g.global_position.x, 0.1), "y": snappedf(g.global_position.y, 0.1),
				"sx": snappedf(gs.x, 0.1), "sy": snappedf(gs.y, 0.1), "a": snappedf(g.ghost_alpha_now(), 0.01),
				"ready": gd.puff_ready(g), "frozen": g.frozen})
		for c in gd.clouds:
			if is_instance_valid(c):
				var cs: Vector2 = fin * c.get_global_transform_with_canvas().origin
				cl.append({"o": int(c.owner_idx), "ph": str(c.phase), "sx": snappedf(cs.x, 0.1), "sy": snappedf(cs.y, 0.1),
					"t": snappedf(float(c.t), 0.001)})
	_frames.append({"f": Engine.get_frames_drawn(), "t": snappedf(_game_t, 0.001), "st": st, "p": rows, "hz": hz,
		"gh": gh, "cl": cl})

## QA fixture (WK-96): when a pendulum is ~0.12 s from passing the low part of its arc at speed, drop a
## living, un-stunned player exactly where the ball will be, velocity zeroed. The ball should SMASH them.
func _tick_pendulum_test(players: Array) -> void:
	if _pt_left <= 0 or _game_t < _pt_next or _hazards.is_empty() or str(_scene.get("state")) != "COMBAT":
		return
	for h in _hazards:
		if not is_instance_valid(h) or str(h.kind) != "pendulum":
			continue
		var lead := 0.12
		var t: float = h.qa_clock()
		var future: Vector2 = h.ball_pos_at(t + lead)
		var bottom: Vector2 = h.pivot + Vector2(0.0, h.arm_len)
		var a_now: Vector2 = h.ball_pos_at(t)
		var a_next: Vector2 = h.ball_pos_at(t + lead + 0.01)
		var spd: float = (a_next - future).length() / 0.01
		if future.distance_to(bottom) > h.arm_len * 0.35 or spd < Tuning.pendulum_smash_min_speed * 2.0:
			continue
		if a_now.distance_to(future) < 40.0:
			continue
		var victim = null
		for p in players:
			if is_instance_valid(p) and not p.is_dead() and p.visible and float(p.get("_stun_timer")) <= 0.0 \
					and float(p.get("_spawn_protect")) <= 0.0 and not p.invincible:
				victim = p
				break
		if victim == null:
			return
		victim.global_position = future
		victim.velocity = Vector2.ZERO
		_pt_pending.append({"victim": players.find(victim), "hazard": h, "smashes_before": int(h.qa_smashes),
			"deadline": _game_t + 0.6, "f": Engine.get_frames_drawn()})
		_ev("pendulum_test_drop", {"victim": players.find(victim), "hazard": str(h.name),
			"ball_speed_at_contact": snappedf(spd, 1.0)})
		_pt_left -= 1
		_pt_next = _game_t + 2.4
		return

## WK-37 QA fixture (`eliminate=0,1`): 1.5 s into every stage's COMBAT, ring out those seats (their last life) so the
## recording shows ghosts + 2 living goats. Kill credit stays whatever the sim says (usually none = a self-KO).
func _tick_eliminate(st: String) -> void:
	var seats: Array = cfg.get("eliminate", [])
	if seats.is_empty() or st != "COMBAT":
		_elim_t = 0.0
		return
	var si: int = int(_scene.get("stage_index"))
	if si == _elim_stage:
		return
	_elim_t += get_process_delta_time()
	if _elim_t < 1.5:
		return
	_elim_stage = si
	var players: Array = _scene.get("players")
	for k in seats:
		var i := int(k)
		if i >= 0 and i < players.size() and is_instance_valid(players[i]) and not players[i].is_dead():
			players[i].kill(&"ring_out", null)
	_ev("eliminate_fixture", {"seats": seats})

## WK-159 QA fixture (`ball_shot=x,y,vx,vy`): 1.0 s into every stage's COMBAT, freeze the goats and fire the ball from world
## (x, y) at (vx, vy) (PhysicsServer2D state: a RigidBody2D position written from outside is overwritten next step). While the
## fixture is on, every frame logs the ball + whether its centre is inside the goal zone rect + the zone latch.
func _tick_ball_shot(st: String) -> void:
	var shot: Array = cfg.get("ball_shot", [])
	if shot.size() < 4:
		return
	var b: Node2D = get_tree().get_first_node_in_group("sports_ball") as Node2D
	var z: Node2D = get_tree().get_first_node_in_group("goal_zone") as Node2D
	if b != null and z != null:
		var rel: Vector2 = b.global_position - z.global_position
		var inside: bool = absf(rel.x) <= float(z.get("w")) * 0.5 and absf(rel.y) <= float(z.get("h")) * 0.5
		_ball_track.append({"f": Engine.get_frames_drawn(), "t": snappedf(_game_t, 0.001), "st": st,
			"x": snappedf(b.global_position.x, 0.1), "y": snappedf(b.global_position.y, 0.1), "in": inside,
			"scored": bool(z.get("scored"))})
	if st != "COMBAT":
		_shot_t = 0.0
		return
	var si: int = int(_scene.get("stage_index"))
	if si == _shot_stage or b == null or not (b is RigidBody2D):
		return
	for p in (_scene.get("players") as Array):
		if is_instance_valid(p):
			p.frozen = true
	_shot_t += get_process_delta_time()
	if _shot_t < 1.0:
		return
	_shot_stage = si
	var rid: RID = (b as RigidBody2D).get_rid()
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, Vector2(float(shot[0]), float(shot[1]))))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(float(shot[2]), float(shot[3])))
	_ev("ball_shot_fixture", {"shot": shot, "stage": si})

## WK-20e: a super press dropped by the spawn truce (the padlock + dry click fire on this event).
func _on_super_lock_pressed(player) -> void:
	var prot: float = float(player.spawn_protect_left()) if is_instance_valid(player) else -1.0
	_ev("super_lock_pressed", {"who": _idx(player), "protect_left": snappedf(prot, 0.001)})

## WK-20e QA fixture bot (`lock_press=` seats): the normal InputBot, plus a super HOLD 0.15-0.55 s into each spawn blink and a
## 0.06 s TAP at 0.80 s, i.e. two presses the Brawl spawn truce drops (badge held, then the tap hold). Outside the blink it is
## exactly the InputBot.
class LockPressBot extends InputBot:
	func poll() -> InputIntent:
		var it: InputIntent = super.poll()
		if me != null and is_instance_valid(me) and not me.is_dead():
			var left: float = me.spawn_protect_left()
			if left > 0.0:
				var age: float = Player.SPAWN_PROTECT_TIME - left
				if (age > 0.15 and age < 0.55) or (age > 0.80 and age < 0.86):
					it.super_hold = true
		return it

func _ev(type: String, d: Dictionary) -> void:
	d["type"] = type
	d["f"] = Engine.get_frames_drawn()
	d["t"] = snappedf(_game_t, 0.001)
	_events.append(d)

func _idx(p) -> int:
	if _scene == null or not is_instance_valid(_scene):
		return -1
	return (_scene.get("players") as Array).find(p)

func _on_super_fired(player, fuel_at_fire, aim_time, auto_fired) -> void:
	var d := {"who": _idx(player), "fuel": fuel_at_fire, "aim_time": snappedf(float(aim_time), 0.001),
		"auto": auto_fired}
	# WK-95: copy the PartyMatch §8.1 classification (purpose_bot + geo_class) of this super, if recorded
	if _scene != null and is_instance_valid(_scene) and "_cur_stats" in _scene:
		var cs: Dictionary = _scene.get("_cur_stats")
		var fired: Array = cs.get("supers_fired", [])
		if not fired.is_empty() and int((fired.back() as Dictionary).get("who", -2)) == int(d["who"]):
			var r: Dictionary = fired.back()
			d["purpose"] = r.get("purpose_bot")
			d["geo"] = r.get("geo_class", "")
	_ev("super_fired", d)

func _on_smashed(attacker, victim, impulse) -> void:
	_ev("smashed", {"attacker": _idx(attacker) if attacker != null else -1, "victim": _idx(victim),
		"impulse": snappedf((impulse as Vector2).length(), 1.0), "hazard": attacker == null})

func _on_hazard_shoved(player, _dir, magnitude) -> void:
	_ev("hazard_shoved", {"who": _idx(player), "push": snappedf(float(magnitude), 1.0)})

func _on_bleated(idx, ghost) -> void:
	_ev("bleated", {"who": int(idx), "ghost": bool(ghost)})

func _on_killed(victim, cause, attacker) -> void:
	_ev("killed", {"victim": _idx(victim), "cause": str(cause), "attacker": _idx(attacker) if attacker != null else -1})

## WK-95: the PartyMatch round_stats QA feed (finished stages + the in-flight one), JSON-safe.
func _round_stats_json() -> Array:
	if _scene == null or not is_instance_valid(_scene) or not ("round_stats" in _scene):
		return []
	var out: Array = (_scene.get("round_stats") as Array).duplicate(true)
	var cur: Dictionary = _scene.get("_cur_stats") if "_cur_stats" in _scene else {}
	if not cur.is_empty():
		var c: Dictionary = cur.duplicate(true)
		c["length_s"] = float(_scene.get("round_clock"))
		c["in_flight"] = true
		out.append(c)
	return JSON.parse_string(JSON.stringify(out))

func _finish() -> void:
	_done = true
	if _scene != null and is_instance_valid(_scene):
		var players: Array = _scene.get("players")
		for i in _aim_open.keys():
			_close_aim(int(i), players[int(i)] if int(i) < players.size() else null)
	var hz: Array = _hz_done.duplicate()
	for h in _hazards:
		if is_instance_valid(h):
			hz.append(_hz_row(h))
	var out := {
		"meta": cfg.merged({"godot": Engine.get_version_info().get("string", ""),
			"physics_tps": Engine.physics_ticks_per_second, "movie_path": Engine.get_write_movie_path(),
			"win_w": get_window().size.x, "win_h": get_window().size.y, "combat_seconds": _combat_acc, "level": str(_scene.get("level_name")) if _scene else ""}),
		"combat_frame": _combat_frame, "frames": _frames, "aim_windows": _aim_windows, "events": _events,
		"hazards": hz,
		"round_stats": _round_stats_json(),
		"ball_track": _ball_track,   # WK-159 (empty unless ball_shot=)
	}
	var f := FileAccess.open(_out_dir.path_join("data.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out))
		f.close()
	print("[MatchRecorder] wrote %s (%d frames, %d aim windows, %d events)" % [
		_out_dir.path_join("data.json"), _frames.size(), _aim_windows.size(), _events.size()])
	get_tree().quit()
