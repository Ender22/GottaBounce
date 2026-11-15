extends Node2D
## WK-169 SHOWDOWN director (docs/specs/wk169_spectator_time_2026-11-16.md §5-§9; 169b-prep prototype). Owned by PartyMatch,
## created ONLY when Tuning.showdown_enabled or Tuning.showdown_telemetry is on (BRAWL only) — with both OFF this node never
## exists and round_stats carries no showdown / spectator / wk169 keys (= today).
##
## SHOWDOWN starts when a BRAWL stage that started with >= 3 fighters has had exactly 2 not-eliminated fighters for
## Tuning.showdown_delay s of COMBAT (game time; so at least one spectator / ghost is watching). It escalates in steps (entry,
## then every showdown_step_s, up to showdown_max_steps) and then HOLDS. It NEVER ends anything: the stage still ends only by
## elimination, sudden death stays the double-KO case (the showdown clears on SD entry), the camera is never touched.
##
## Levers, each behind its own switch (all default OFF):
##   L1 showdown_drop        — a golden tank bubble at the fair spawner (minimax of the two fighters' distances) every
##                             showdown_drop_interval s; touch = Unlimited Boost for showdown_drop_dur s (auto-activated).
##   L2 showdown_ghost_boost — GhostDirector.set_showdown: puff cooldown x0.5, cap +3 per step (hushes still override).
##   L3 showdown_rowdy       — Player.wk169_launch_mult = showdown_bounce_mult_per_step ^ step on tier bounces.
## Presentation (prototype): "SHOWDOWN!" top band, a static backdrop dim (world plate at showdown_dim_z: above the backdrop
## stack, below void paint / decks / ghosts / goats) and a gold rim light on the two fighters.
## Telemetry (spec §9 + the brief): two_alive_t, showdown {...}, spectator {...}, wk169 {...} per stage; summary() per match.

const BUBBLE_PATH := "res://src/entities/PowerupBubble.gd"
const SPARKLE_TEX := "res://assets/fx/star_sparkle.png"
const GOLD := Color("#ffd23f")

var runner                       # PartyMatch
var active := false              # in SHOWDOWN right now
var step := 0                    # 1..showdown_max_steps while active
var two_alive_t := -1.0          # round_clock when the stage went to 2 not-eliminated fighters (-1 = not yet)
var fighters: Array = []         # the two fighters' player indices (set at two_alive_t)
var _t_enter := -1.0
var _next_step_t := INF
var _next_drop_t := INF
var _live_wait_t := -1.0         # round_clock a due drop started waiting for a respawning fighter
var _tel_node: CPUParticles2D = null
var _tel_end_t := -1.0
var _tel_pos := Vector2.INF
var _tel_rec: Dictionary = {}
var _bubble = null               # the live golden bubble (one at a time)
var _last_tank_end_t := -INF
var _holder := {}                # player idx -> its open tank record (golden tank running)
var _dim: Polygon2D = null
var _dim_tw: Tween = null
var _rims := {}                  # player idx -> RimLight
var _sd := false                 # the stage went to SUDDEN_DEATH after the showdown started
# per-stage telemetry
var _stats := {}                 # the `showdown` record (showdown_enabled only)
var _t_elim := {}                # player idx -> round_clock of its elimination (cleared on an SD revive)
var _ne_after := {}              # player idx -> not-eliminated count right after its elimination
var _last_smash := {}            # victim idx -> {attacker idx: round_clock} of received smashes
var _tail := {}                  # tail counters (2-alive phase)
var _wk169 := {}                 # credit-integrity counters

func setup(runner_ref) -> void:
	runner = runner_ref
	name = "ShowdownDirector"
	EventBus.smashed.connect(_on_smashed)
	EventBus.super_fired.connect(_on_super_fired)
	EventBus.smash_landed.connect(_on_smash_landed)
	EventBus.bounced.connect(_on_bounced)

func _exit_tree() -> void:
	for pair in [[EventBus.smashed, _on_smashed], [EventBus.super_fired, _on_super_fired],
			[EventBus.smash_landed, _on_smash_landed], [EventBus.bounced, _on_bounced]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])

func lever_on() -> bool:
	return Tuning.showdown_enabled

# ------------------------------------------------------------------ PartyMatch hooks

## _bounce_go: a fresh stage record.
func on_combat_start(_cur_stats: Dictionary) -> void:
	clear()
	two_alive_t = -1.0
	fighters.clear()
	_t_enter = -1.0
	_next_step_t = INF
	_next_drop_t = INF
	_live_wait_t = -1.0
	_last_tank_end_t = -INF
	_holder.clear()
	_sd = false
	_t_elim.clear()
	_ne_after.clear()
	_last_smash.clear()
	_tail = {"smashes": 0, "supers": 0, "bounces": {}, "boost_s": {}}
	_wk169 = {"ghost_credited": 0, "beyond_grave_credited": 0, "ghost_assisted_credited": 0, "km4_match_deciding_ghost": 0,
		"haunted": 0}
	_stats = {"t_enter": -1.0, "steps_t": [], "drops": [], "tank": [], "ended_by": "", "golden_pickups": 0,
		"max_step": 0} if lever_on() else {}
	for p in runner.players:
		if is_instance_valid(p):
			p.wk169_launch_mult = 1.0

## PartyMatch._on_killed, right after the kill record got its credit fields and BEFORE lives are decremented.
func annotate_kill(rec: Dictionary, victim_idx: int, killer_idx: int) -> void:
	if rec.is_empty():
		return
	var ne_before: int = runner._not_eliminated_count()
	rec["phase"] = ("2S" if active else "2") if ne_before == 2 else str(ne_before)
	rec["showdown_step"] = step if active else 0
	rec["golden_killer"] = killer_idx >= 0 and _holder.has(killer_idx)
	rec["golden_victim"] = _holder.has(victim_idx)
	var credited: bool = bool(rec.get("credited", false))
	if bool(rec.get("haunted", false)):
		_wk169["haunted"] = int(_wk169["haunted"]) + 1
	if credited and killer_idx >= 0:
		# ghost-CREDITED (DQ-3 hard zero): the credited smash landed AFTER the killer was eliminated (a ghost hit someone)
		var te: float = float(_t_elim.get(killer_idx, -1.0))
		var ts: float = float((_last_smash.get(victim_idx, {}) as Dictionary).get(killer_idx, -INF))
		if te >= 0.0 and ts > te:
			_wk169["ghost_credited"] = int(_wk169["ghost_credited"]) + 1
			rec["ghost_credited"] = true
		elif te >= 0.0:
			_wk169["beyond_grave_credited"] = int(_wk169["beyond_grave_credited"]) + 1   # info: smash before the killer died
		# ghost-ASSISTED (KM-1, banded): the victim's last cloud contact came after its last received smash, <= fence
		var dtc: float = float(rec.get("dt_last_cloud_contact", 9999.0))
		var last_rx: float = -INF
		for k in (_last_smash.get(victim_idx, {}) as Dictionary).values():
			last_rx = maxf(last_rx, float(k))
		if dtc <= Tuning.ghost_puff_fence_s and float(runner.round_clock) - dtc > last_rx:
			_wk169["ghost_assisted_credited"] = int(_wk169["ghost_assisted_credited"]) + 1
			rec["ghost_assisted"] = true

## PartyMatch._on_killed, after the lives decrement (eliminated only) and the not-eliminated count.
func on_elimination(victim_idx: int, ne_after: int) -> void:
	_t_elim[victim_idx] = float(runner.round_clock)
	_ne_after[victim_idx] = ne_after
	if ne_after == 2 and two_alive_t < 0.0 and int(runner._stage_start_alive) >= 3 and runner._attribution_mode() \
			and str(runner.state) == "COMBAT":
		two_alive_t = float(runner.round_clock)
		fighters.clear()
		for i in range(runner.players.size()):
			if int(runner.lives_left[i]) > 0:
				fighters.append(i)

## PartyMatch match-end on the winning kill: KM-4 (match-deciding ghost involvement) check on the deciding KO.
func on_match_winning_kill(rec: Dictionary) -> void:
	if rec.is_empty():
		return
	if float(rec.get("dt_last_cloud_contact", 9999.0)) <= Tuning.ghost_puff_fence_s or bool(rec.get("haunted", false)):
		_wk169["km4_match_deciding_ghost"] = int(_wk169["km4_match_deciding_ghost"]) + 1
		rec["km4"] = true

## PartyMatch._sudden_death_revive (before the revived list is cleared): the showdown clears instantly (spec §5.3).
func on_sudden_death(revived: Array) -> void:
	for i in revived:
		_t_elim.erase(int(i))
		_ne_after.erase(int(i))
	if active:
		_sd = true
	_exit_showdown()

## Per physics tick from PartyMatch._tick_combat (COMBAT only, outside the SD revive lock).
func tick(delta: float) -> void:
	var now: float = float(runner.round_clock)
	_track_tanks(now)
	if two_alive_t >= 0.0:
		for i in fighters:
			var p = runner.players[i] if i < runner.players.size() else null
			if is_instance_valid(p) and not p.is_dead() and p.is_boosting():
				var bs: Dictionary = _tail["boost_s"]
				bs[i] = float(bs.get(i, 0.0)) + delta
	if not lever_on() or str(runner.state) != "COMBAT":
		return
	if not active:
		if two_alive_t >= 0.0 and runner._not_eliminated_count() == 2 and now - two_alive_t >= Tuning.showdown_delay - 0.0001:
			_enter_showdown(now)
		return
	if step < Tuning.showdown_max_steps and now >= _next_step_t - 0.0001:
		_set_step(step + 1, now)
	if Tuning.showdown_drop:
		_tick_drop(now)

## STAGE_END / MATCH_END: write this stage's telemetry into its record (before PartyMatch appends it).
func finalize_stats(cur_stats: Dictionary) -> void:
	if cur_stats == null or cur_stats.is_empty():
		return
	var length: float = float(runner.round_clock)
	cur_stats["two_alive_t"] = two_alive_t
	# spectator time per seat (spec §1.1: length_s - t_death, COMBAT + SD game time) + the human waits (S3)
	var seats: Array = []
	var waits: Array = []
	var human_dead := 0.0
	var long_waits := 0
	for i in range(runner.players.size()):
		var human: bool = runner.is_human_player(i)
		var te: float = float(_t_elim.get(i, -1.0))
		var dead_s: float = maxf(0.0, length - te) if te >= 0.0 else 0.0
		var wait_counted: bool = te >= 0.0 and int(_ne_after.get(i, 0)) >= 2   # a death that did not end the stage
		seats.append({"idx": i, "human": human, "t_elim": te, "dead_s": snappedf(dead_s, 0.001),
			"share": snappedf(dead_s / length, 0.0001) if length > 0.0 else 0.0, "wait": wait_counted})
		if human:
			human_dead += dead_s
			if wait_counted:
				waits.append(snappedf(dead_s, 0.001))
				if dead_s > Tuning.showdown_long_wait_s:
					long_waits += 1
	cur_stats["spectator"] = {"seats": seats, "human_dead_s": snappedf(human_dead, 0.001), "human_waits": waits,
		"long_waits": long_waits, "long_wait_s": Tuning.showdown_long_wait_s}
	# tail counters (2-alive phase)
	var bounces: Dictionary = _tail.get("bounces", {})
	var boost: Dictionary = _tail.get("boost_s", {})
	var per: Array = []
	for i in fighters:
		per.append({"idx": i, "bounces": int(bounces.get(i, 0)), "boost_s": snappedf(float(boost.get(i, 0.0)), 0.001)})
	cur_stats["tail"] = {"t2_s": snappedf(length - two_alive_t, 0.001) if two_alive_t >= 0.0 else -1.0,
		"smashes": int(_tail.get("smashes", 0)), "supers": int(_tail.get("supers", 0)), "fighters": per}
	# ghosts + credit integrity
	var puffs := 0
	var puffs_sd := 0
	for r in cur_stats.get("ghosts", []):
		for pf in (r as Dictionary).get("puffs", []):
			if not bool((pf as Dictionary).get("hushed_dud", false)):
				puffs += 1
		puffs_sd += int((r as Dictionary).get("puffs_in_showdown", 0))
	var w: Dictionary = _wk169.duplicate()
	w["ghost_puffs"] = puffs
	w["ghost_puffs_in_showdown"] = puffs_sd
	cur_stats["wk169"] = w
	if lever_on():
		for i in _holder.keys():
			(_holder[i] as Dictionary)["t_off"] = length   # still running at the stage end
		_holder.clear()
		if _t_enter >= 0.0:
			var kills: Array = cur_stats.get("kills", [])
			var last: Dictionary = kills[kills.size() - 1] if not kills.is_empty() else {}
			if _sd:
				_stats["ended_by"] = "sd"
			elif last.is_empty():
				_stats["ended_by"] = "none"
			elif bool(last.get("credited", false)):
				_stats["ended_by"] = "credited"
			elif bool(last.get("haunted", false)):
				_stats["ended_by"] = "haunted"
			else:
				_stats["ended_by"] = "self"
		cur_stats["showdown"] = _stats.duplicate(true)

## Visual + lever teardown (stage end, match end, SD, new stage). Field objects also go with PowerupSystem.round_sweep.
func clear() -> void:
	_exit_showdown()

## Bot query (InputBot golden-seek layer): the telegraphing / live golden bubble position, or Vector2.INF.
func golden_target() -> Vector2:
	if _bubble != null and is_instance_valid(_bubble) and not _bubble.is_queued_for_deletion():
		return _bubble.global_position
	if _tel_node != null and is_instance_valid(_tel_node):
		return _tel_pos
	return Vector2.INF

## QA: per-match roll-up of the round_stats this node wrote (spectator seconds per seat, share, long waits, showdown
## entries / steps, golden pickups, ghost puffs, ghost-credited KOs).
func summary(stats: Array) -> Dictionary:
	var spec_s := {}
	var combat_s := 0.0
	var long_waits := 0
	var waits := 0
	var entries := 0
	var steps := 0
	var pickups := 0
	var drops := 0
	var puffs := 0
	var puffs_sd := 0
	var ghost_credited := 0
	var km4 := 0
	var assisted := 0
	for st in stats:
		var d: Dictionary = st
		combat_s += float(d.get("length_s", 0.0))
		var sp: Dictionary = d.get("spectator", {})
		for s in sp.get("seats", []):
			var k: int = int((s as Dictionary)["idx"])
			spec_s[k] = float(spec_s.get(k, 0.0)) + float((s as Dictionary)["dead_s"])
		long_waits += int(sp.get("long_waits", 0))
		waits += (sp.get("human_waits", []) as Array).size()
		var sd: Dictionary = d.get("showdown", {})
		if float(sd.get("t_enter", -1.0)) >= 0.0:
			entries += 1
			steps += (sd.get("steps_t", []) as Array).size()
		pickups += int(sd.get("golden_pickups", 0))
		drops += (sd.get("drops", []) as Array).size()
		var w: Dictionary = d.get("wk169", {})
		puffs += int(w.get("ghost_puffs", 0))
		puffs_sd += int(w.get("ghost_puffs_in_showdown", 0))
		ghost_credited += int(w.get("ghost_credited", 0))
		km4 += int(w.get("km4_match_deciding_ghost", 0))
		assisted += int(w.get("ghost_assisted_credited", 0))
	var seats: Array = []
	for i in range(runner.players.size()):
		var s: float = float(spec_s.get(i, 0.0))
		seats.append({"idx": i, "human": runner.is_human_player(i), "spectator_s": snappedf(s, 0.01),
			"share": snappedf(s / combat_s, 0.0001) if combat_s > 0.0 else 0.0})
	return {"stages": stats.size(), "combat_s": snappedf(combat_s, 0.01), "seats": seats, "human_waits": waits,
		"long_waits": long_waits, "showdown_entries": entries, "showdown_steps": steps, "golden_drops": drops,
		"golden_pickups": pickups, "ghost_puffs": puffs, "ghost_puffs_in_showdown": puffs_sd,
		"ghost_credited": ghost_credited, "km4_match_deciding_ghost": km4, "ghost_assisted_credited": assisted}

# ------------------------------------------------------------------ state

func _enter_showdown(now: float) -> void:
	active = true
	_t_enter = now
	_stats["t_enter"] = snappedf(now, 0.0001)
	_next_drop_t = now   # the first golden drop telegraphs at entry
	if runner._hud != null:
		runner._hud.show_top("SHOWDOWN!", GOLD, Tuning.showdown_banner_time)
	_build_dim()
	for i in fighters:
		_add_rim(int(i))
	_set_step(1, now)

func _set_step(s: int, now: float) -> void:
	step = s
	(_stats["steps_t"] as Array).append(snappedf(now, 0.0001))
	_stats["max_step"] = s
	_next_step_t = now + Tuning.showdown_step_s
	# L2 (GhostDirector holds cooldown + cap; it ignores the call when showdown_ghost_boost is OFF except telemetry)
	var gd = runner.get("_ghost_dir")
	if gd != null and is_instance_valid(gd):
		gd.set_showdown(true, s)
	# L3
	var m: float = pow(Tuning.showdown_bounce_mult_per_step, float(s)) if Tuning.showdown_rowdy else 1.0
	for p in runner.players:
		if is_instance_valid(p):
			p.wk169_launch_mult = m
	# presentation: the dim deepens (static per step), the rims pulse once
	_set_dim(minf(Tuning.showdown_dim + Tuning.showdown_dim_step * float(s - 1), Tuning.showdown_dim_max), s == 1)
	if s > 1:
		for r in _rims.values():
			if is_instance_valid(r):
				r.pulse()

func _exit_showdown() -> void:
	active = false
	step = 0
	_next_step_t = INF
	_next_drop_t = INF
	var gd = runner.get("_ghost_dir") if runner != null else null
	if gd != null and is_instance_valid(gd):
		gd.set_showdown(false, 0)
	if runner != null:
		for p in runner.players:
			if is_instance_valid(p):
				p.wk169_launch_mult = 1.0
	_cancel_telegraph()
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.pop()
	_bubble = null
	if _dim != null and is_instance_valid(_dim):
		_dim.queue_free()
	_dim = null
	for r in _rims.values():
		if is_instance_valid(r):
			r.queue_free()
	_rims.clear()

# ------------------------------------------------------------------ L1 golden drop

func _tick_drop(now: float) -> void:
	if _tel_node != null:
		if now >= _tel_end_t - 0.0001:
			_spawn_golden(now)
		return
	if now < _next_drop_t - 0.0001:
		return
	if _bubble != null and is_instance_valid(_bubble) and not _bubble.is_queued_for_deletion():
		return   # one golden bubble at a time
	if not _holder.is_empty() or now - _last_tank_end_t < Tuning.showdown_drop_tank_lock:
		return   # tank lock: no drop while a golden tank runs, nor for tank_lock s after it ended
	var all_live := true
	for i in fighters:
		var p = runner.players[i]
		if not is_instance_valid(p) or p.is_dead():
			all_live = false
	if not all_live:
		if _live_wait_t < 0.0:
			_live_wait_t = now
		if now - _live_wait_t < Tuning.showdown_drop_live_wait:
			return
	_live_wait_t = -1.0
	_start_telegraph(now)

## The fair point (spec §6.1): among the in-view spawners (view inset showdown_drop_view_inset screen px; none -> all), the
## one minimising max(d_A, d_B); ties -> nearest the camera centre.
func fair_point() -> Dictionary:
	var pts: Array = runner.get("_pu_points") if runner.get("_pu_points") != null else []
	if pts.is_empty() or fighters.size() < 2:
		return {}
	var a = runner.players[fighters[0]]
	var b = runner.players[fighters[1]]
	if not is_instance_valid(a) or not is_instance_valid(b):
		return {}
	var view := _view_rect()
	var cam_c: Vector2 = view.get_center()
	var z: float = _cam_zoom()
	var inset: Rect2 = view.grow(-Tuning.showdown_drop_view_inset / z)
	var cand: Array = []
	for p in pts:
		if inset.size.x > 0.0 and inset.size.y > 0.0 and inset.has_point(p):
			cand.append(p)
	var from_n: int = cand.size()
	if cand.is_empty():
		cand = pts
	var best := Vector2.INF
	var best_m := INF
	var best_c := INF
	for p in cand:
		var pv: Vector2 = p
		var m: float = maxf(pv.distance_to(a.global_position), pv.distance_to(b.global_position))
		var c: float = pv.distance_to(cam_c)
		if m < best_m - 0.5 or (absf(m - best_m) <= 0.5 and c < best_c):
			best_m = m
			best_c = c
			best = pv
	return {"pos": best, "d_a": best.distance_to(a.global_position), "d_b": best.distance_to(b.global_position),
		"in_view_n": from_n, "n": pts.size()}

func _start_telegraph(now: float) -> void:
	var fp: Dictionary = fair_point()
	_next_drop_t = now + Tuning.showdown_drop_interval
	if fp.is_empty():
		return   # an arena with no powerup_spawner points: no golden drops (logged as zero drops)
	_tel_pos = fp["pos"]
	_tel_rec = {"t_tel": snappedf(now, 0.0001), "t_live": -1.0, "pos": [snappedf(_tel_pos.x, 0.1), snappedf(_tel_pos.y, 0.1)],
		"d_a": snappedf(float(fp["d_a"]), 0.1), "d_b": snappedf(float(fp["d_b"]), 0.1), "picked_from_n": int(fp["in_view_n"]),
		"points_n": int(fp["n"]), "collected_by": -1, "t_collect": -1.0, "popped": false, "step": step}
	(_stats["drops"] as Array).append(_tel_rec)
	var p := CPUParticles2D.new()
	p.global_position = _tel_pos
	p.emitting = true
	p.amount = 40
	p.lifetime = 0.45
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 150.0 * Tuning.showdown_drop_tel_radius
	p.direction = Vector2.ZERO
	p.spread = 0.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.radial_accel_min = -1900.0
	p.radial_accel_max = -2600.0
	if ResourceLoader.exists(SPARKLE_TEX):
		p.texture = load(SPARKLE_TEX)
		p.scale_amount_min = 0.2
		p.scale_amount_max = 0.38
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.72, 0.1, 0.0))
	grad.add_point(0.35, Color(1.0, 0.76, 0.12, 1.0))
	grad.set_color(1, Color(1.0, 0.86, 0.3, 1.0))
	p.color_ramp = grad   # normal blend: additive gold went white on bright skies (rendered 2026-11-16)
	p.add_to_group("pu_field")
	p.z_index = 11
	runner.add_child(p)
	_tel_node = p
	_tel_end_t = now + Tuning.showdown_drop_telegraph

func _spawn_golden(now: float) -> void:
	var pos: Vector2 = _tel_pos   # read before _cancel_telegraph() resets it
	_cancel_telegraph()
	var b = load(BUBBLE_PATH).new()
	b.id = "unlimited_boost"
	b.golden = true
	b.golden_dur = Tuning.showdown_drop_dur
	b.life = Tuning.showdown_drop_life
	var rec: Dictionary = _tel_rec
	rec["t_live"] = snappedf(now, 0.0001)
	b.on_collect = func(pl) -> void:
		var idx: int = runner.players.find(pl)
		rec["collected_by"] = idx
		rec["t_collect"] = snappedf(float(runner.round_clock), 0.0001)
		_stats["golden_pickups"] = int(_stats.get("golden_pickups", 0)) + 1
		_open_tank(idx)
	b.on_expire = func() -> void:
		rec["popped"] = true
	b.position = pos
	runner.add_child(b)
	_bubble = b

func _cancel_telegraph() -> void:
	if _tel_node != null and is_instance_valid(_tel_node):
		_tel_node.queue_free()
	_tel_node = null
	_tel_pos = Vector2.INF

func _open_tank(idx: int) -> void:
	if idx < 0:
		return
	if _holder.has(idx):
		return   # a refresh: the same tank record keeps running
	var t := {"idx": idx, "t_on": snappedf(float(runner.round_clock), 0.0001), "t_off": -1.0, "supers": 0, "smashes": 0}
	(_stats["tank"] as Array).append(t)
	_holder[idx] = t

## Close tank records whose golden effect ended (expiry, death, sweep); feeds the drop's tank lock.
func _track_tanks(now: float) -> void:
	for idx in _holder.keys():
		var p = runner.players[idx] if idx < runner.players.size() else null
		if p == null or not is_instance_valid(p) or p.is_dead() or not PowerupSystem.golden_tank_active(p):
			(_holder[idx] as Dictionary)["t_off"] = snappedf(now, 0.0001)
			_holder.erase(idx)
			_last_tank_end_t = now

# ------------------------------------------------------------------ telemetry feeds

func _on_smashed(attacker, victim, _impulse) -> void:
	if runner == null:
		return
	var vi: int = runner.players.find(victim)
	var ai: int = runner.players.find(attacker) if attacker != null else -1
	if vi < 0 or ai < 0:
		return
	if not _last_smash.has(vi):
		_last_smash[vi] = {}
	(_last_smash[vi] as Dictionary)[ai] = float(runner.round_clock)

func _on_smash_landed(attacker, _victim, _info) -> void:
	if runner == null or two_alive_t < 0.0:
		return
	var st: String = str(runner.state)
	if st != "COMBAT" and st != "SUDDEN_DEATH":
		return
	_tail["smashes"] = int(_tail.get("smashes", 0)) + 1
	var ai: int = runner.players.find(attacker) if attacker != null else -1
	if _holder.has(ai):
		(_holder[ai] as Dictionary)["smashes"] = int((_holder[ai] as Dictionary)["smashes"]) + 1

func _on_super_fired(player, _f, _a, _af) -> void:
	if runner == null or two_alive_t < 0.0:
		return
	var st: String = str(runner.state)
	if st != "COMBAT" and st != "SUDDEN_DEATH":
		return
	_tail["supers"] = int(_tail.get("supers", 0)) + 1
	var i: int = runner.players.find(player)
	if _holder.has(i):
		(_holder[i] as Dictionary)["supers"] = int((_holder[i] as Dictionary)["supers"]) + 1

func _on_bounced(body) -> void:
	if runner == null or two_alive_t < 0.0:
		return
	var i: int = runner.players.find(body)
	if i < 0 or not fighters.has(i):
		return
	var bc: Dictionary = _tail["bounces"]
	bc[i] = int(bc.get(i, 0)) + 1

# ------------------------------------------------------------------ presentation

## The camera's visible world rect (what the player sees). Read-only: the showdown never moves the camera (G12).
func _view_rect() -> Rect2:
	var cam = runner.get("_camera")
	if cam == null or not is_instance_valid(cam):
		return Rect2()
	var vp: Vector2 = get_viewport_rect().size
	var z: float = maxf((cam as Camera2D).zoom.x, 0.01)
	var half: Vector2 = vp / (2.0 * z)
	return Rect2((cam as Camera2D).get_screen_center_position() - half, half * 2.0)

func _cam_zoom() -> float:
	var cam = runner.get("_camera")
	if cam == null or not is_instance_valid(cam):
		return 1.0
	return maxf((cam as Camera2D).zoom.x, 0.01)

## Static backdrop dim: one huge world plate (no edge ever on screen, no motion) drawn above the backdrop stack
## (z -100..-80) and below the void paint, decks, ghosts and goats. Black at alpha d == a multiply by (1 - d).
func _build_dim() -> void:
	if _dim != null and is_instance_valid(_dim):
		return
	var r: Rect2 = (runner.bounds as Rect2).grow(20000.0)
	_dim = Polygon2D.new()
	_dim.name = "ShowdownDim"
	_dim.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	_dim.color = Color(0, 0, 0, 0)
	_dim.z_index = Tuning.showdown_dim_z
	runner.add_child(_dim)

func _set_dim(d: float, ease_in: bool) -> void:
	if _dim == null or not is_instance_valid(_dim):
		return
	if _dim_tw != null and _dim_tw.is_valid():
		_dim_tw.kill()
	_dim_tw = _dim.create_tween()
	_dim_tw.tween_property(_dim, "color:a", d, Tuning.showdown_dim_ease if ease_in else 0.4)

func _add_rim(i: int) -> void:
	if _rims.has(i) or i < 0 or i >= runner.players.size():
		return
	var p = runner.players[i]
	if not is_instance_valid(p):
		return
	var r := RimLight.new()
	var rad: Variant = p.get("_radius")
	r.radius = float(rad) if rad != null else 44.0
	p.add_child(r)
	p.move_child(r, 0)   # first child: drawn behind the body (same z)
	_rims[i] = r

## Gold rim light behind a fighter: a soft gold halo plus a crisp gold ring with a thin chocolate keyline (Toybox read on
## pale and dark backdrops alike). Sized in SCREEN px (divided by the camera zoom), so it reads at every play zoom.
class RimLight:
	extends Node2D
	var radius := 44.0
	var _pulse := 0.0
	var _z := -1.0
	func _ready() -> void:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	func pulse() -> void:
		_pulse = 1.0
	func _process(delta: float) -> void:
		var cam := get_viewport().get_camera_2d()
		var z: float = maxf(cam.zoom.x, 0.05) if cam != null else 1.0
		if _pulse > 0.0:
			_pulse = maxf(0.0, _pulse - delta * 2.5)
			queue_redraw()
		elif absf(z - _z) > 0.002:
			queue_redraw()
		_z = z
	func _draw() -> void:
		var z: float = maxf(_z, 0.05)
		var c: Color = Tuning.showdown_rim_color
		var a: float = minf(1.0, Tuning.showdown_rim_alpha * (1.0 + 0.6 * _pulse))
		var w: float = Tuning.showdown_rim_px * (1.0 + 0.5 * _pulse) / z
		var gap: float = Tuning.showdown_rim_gap_px / z
		var halo: float = Tuning.showdown_rim_halo_px / z
		var rr: float = radius * Tuning.showdown_rim_radius_mult + gap + w * 0.5
		draw_arc(Vector2.ZERO, rr + w * 0.5 + halo * 0.5, 0.0, TAU, 64, Color(c.r, c.g, c.b, a * 0.25), halo, true)   # soft outer glow (no fill over the body)
		draw_arc(Vector2.ZERO, rr + w * 0.5 + 1.0 / z, 0.0, TAU, 64, Color(0.231, 0.141, 0.106, a * 0.75), 2.0 / z, true)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 64, Color(c.r, c.g, c.b, a), w, true)
