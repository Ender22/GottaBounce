# frame_recorder.gd - per-frame hitch recorder for the RENDERED game (WK-91, 2026-11-14).
# Polling (`gbplay perf`, perf_gate.py) misses spikes; this records EVERY main-loop iteration.
# NOTE: Performance TIME_PROCESS ("frame_time" in gbplay perf) is NOT the last frame's process time: Godot
# reports the MAX over the last ~1 s and it includes the render/swap wait. Use dt/phys/draw below instead.
#
# PRE-FLIGHT: the display must be AWAKE. With the screen off (Windows Modern Standby, AC display timeout
# 15 min on the studio laptop) DWM throttles presents to ~30 Hz with ~500 ms stalls every 1-2 s -> a
# perfectly healthy build reads 16 FPS. Signature: draw ~31-33 ms while gpu+rcpu < 2 ms. Check:
#   powershell "Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-Kernel-Power';Id=506,507} -MaxEvents 1"
#   (last Id 506 = in Modern Standby / display off -> numbers invalid; 507 = awake)
#
# Install (game running via tools/run_game.ps1), then start/dump through gbplay eval:
#   var s = GDScript.new(); s.source_code = FileAccess.get_file_as_string("<abs path to this file>")
#   s.reload(); var n = Node.new(); n.set_script(s); n.name = "WK91Rec"; get_tree().root.add_child(n); n.start()
#   ... later: return get_tree().root.get_node("WK91Rec").dump("<abs path>.json")   # returns the summary
# Per frame: dt (process-to-process wall ms), steps (physics ticks this frame), phys (wall ms first->last
# physics tick), draw (frame_pre_draw->frame_post_draw incl. swap/vsync wait), gpu/rcpu (viewport measured
# render time), dc (draw calls), nodes. Frames > 50 ms are also logged with state + level_name.
extends Node
# WK-91 per-frame recorder. Installed via gbplay eval; writes JSON to a file on dump().
# Segments per main-loop iteration:
#   phys_ms   : first physics tick start -> last physics tick end (wall, this iteration)
#   proc_ms   : Performance TIME_PROCESS (whole SceneTree process)
#   draw_ms   : frame_pre_draw -> frame_post_draw (RenderingServer draw incl. swap/vsync)
#   dt_ms     : process-start to process-start wall delta
var t_prev_proc: int = 0
var t_pre_draw: int = 0
var t_post_draw: int = 0
var t_phys_first: int = -1
var t_phys_last_end: int = 0
var phys_steps: int = 0
var frames: Array = []
var hitches: Array = []
var n33: int = 0
var n100: int = 0
var max_dt: float = 0.0
var recording: bool = false
var t_start: int = 0
var last_draw_ms: float = 0.0
var gap_ms: float = 0.0
var end_node: Node
var vp_rid: RID
var states: Dictionary = {}
var focus_frames: int = 0

class EndMarker extends Node:
	var rec: Node
	func _physics_process(_d: float) -> void:
		rec.t_phys_last_end = Time.get_ticks_usec()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100000
	process_physics_priority = -100000
	end_node = EndMarker.new()
	end_node.rec = self
	end_node.process_mode = Node.PROCESS_MODE_ALWAYS
	end_node.process_physics_priority = 100000
	add_child(end_node)
	RenderingServer.frame_pre_draw.connect(_on_pre)
	RenderingServer.frame_post_draw.connect(_on_post)
	vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)

func start() -> void:
	frames.clear(); hitches.clear(); states.clear(); focus_frames = 0; n33 = 0; n100 = 0; max_dt = 0.0
	t_prev_proc = 0; recording = true; t_start = Time.get_ticks_usec()

func _on_pre() -> void:
	t_pre_draw = Time.get_ticks_usec()

func _on_post() -> void:
	t_post_draw = Time.get_ticks_usec()
	last_draw_ms = (t_post_draw - t_pre_draw) / 1000.0

func _physics_process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	if t_phys_first < 0:
		t_phys_first = now
	phys_steps += 1

func _state() -> String:
	var cs := get_tree().current_scene
	if cs == null:
		return "?"
	var st: Variant = cs.get("state")
	var s := str(cs.name)
	if st != null:
		s += ":" + str(st)
	return s

func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	if recording and t_prev_proc > 0:
		var dt := (now - t_prev_proc) / 1000.0
		var phys := 0.0
		if t_phys_first >= 0:
			phys = (t_phys_last_end - t_phys_first) / 1000.0
		# time from last post_draw to first physics tick (or to process if no physics)
		var pre_gap := 0.0
		var anchor := t_phys_first if t_phys_first >= 0 else now
		pre_gap = (anchor - t_post_draw) / 1000.0
		var f := {
			"t": snappedf((now - t_start) / 1e6, 0.001),
			"dt": snappedf(dt, 0.01),
			"steps": phys_steps,
			"phys": snappedf(phys, 0.01),
			"tphys": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
			"tproc": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
			"draw": snappedf(last_draw_ms, 0.01),
			"gap": snappedf(pre_gap, 0.01),
			"gpu": snappedf(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), 0.01),
			"rcpu": snappedf(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid), 0.01),
			"dc": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"ts": snappedf(Engine.time_scale, 0.01),
		}
		frames.append(f)
		var stn := _state()
		states[stn] = int(states.get(stn, 0)) + 1
		if get_window().has_focus():
			focus_frames += 1
		if dt > max_dt:
			max_dt = dt
		if dt > 33.0:
			n33 += 1
		if dt > 50.0:
			if dt > 100.0:
				n100 += 1
			var h := f.duplicate()
			h["state"] = _state()
			h["level"] = str(get_tree().current_scene.get("level_name"))
			hitches.append(h)
	t_prev_proc = now
	t_phys_first = -1
	phys_steps = 0

func summary() -> Dictionary:
	var dts: Array = []
	for f in frames:
		dts.append(f["dt"])
	dts.sort()
	var n := dts.size()
	var tot := 0.0
	for d in dts:
		tot += d
	var med: float = dts[n / 2] if n > 0 else 0.0
	return {"frames": n, "secs": snappedf(tot / 1000.0, 0.01), "avg_fps": snappedf(n / max(tot / 1000.0, 0.001), 0.1),
		"median_dt": med, "p95_dt": dts[int(n * 0.95)] if n > 0 else 0.0, "max_dt": max_dt, "n33": n33, "n100": n100,
		"states": states, "focus_frames": focus_frames, "vsync": DisplayServer.window_get_vsync_mode(), "win": str(get_window().size), "mode": get_window().mode, "hitch_t": hitches.map(func(h): return h["t"])}

func dump(path: String) -> Dictionary:
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(JSON.stringify({"summary": summary(), "hitches": hitches, "frames": frames}))
	fa.close()
	return summary()
