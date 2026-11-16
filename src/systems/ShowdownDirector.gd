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
const WORD_SCENE := preload("res://scenes/ui/WordBurst.tscn")   # WK-169c: the "GOLDEN TANK!" word pop (WK-53 shout-burst)

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
# WK-169c
var _claimed := false            # WK-169c: this director holds a claim on the regular spawn director's point
var _tel_glow: Node2D = null     # WK-169c: the telegraph's ground-glow ring
var _last_collect_t := -1.0      # WK-169c: round_clock of this stage's latest golden collect (kill t_since_grab)
var _trails := {}                # WK-169c: player idx -> the holder's star trail (CPUParticles2D)
var wk169c_words := 0            # WK-169c QA: "GOLDEN TANK!" pops shown
# WK-191 (spec wk190_dead_share §5): SD inherits the SHOWDOWN (Tuning.sd_showdown) + the SD / banner telemetry (§5.5, every arm)
var _sd_rec := {}                # WK-191: this stage's `sd` record ({} until an SD revive)
var _sd_unlock_t := -1.0         # WK-191: round_clock of the SD unlock (revive lock ended); -1 = no SD fight running
var _sd_entered := false         # WK-191: the SD SHOWDOWN already entered this SD (one entry per SD)
var _in_sd_showdown := false     # WK-191: the running showdown is the SD one (drop / tank records tagged "phase": "sd")
var _sd_boost := {}              # WK-191: revived idx -> boost seconds after the SD unlock (BS)
var _sd_words0 := 0              # WK-191: wk169c_words at the SD showdown entry ("GOLDEN TANK!" pops per entry)
var _banners: Array = []         # WK-191: [{text, t_on, t_off}] for "SUDDEN DEATH!" / "SHOWDOWN!" (T-191c, BX)
var _ban_open := {}              # WK-191: text -> its open record in _banners
var _bx_frames := 0              # WK-191: physics frames with both banners on screen (must be 0)
const WK191_BANNERS := ["SUDDEN DEATH!", "SHOWDOWN!"]   # WK-191

func setup(runner_ref) -> void:
	runner = runner_ref
	name = "ShowdownDirector"
	EventBus.smashed.connect(_on_smashed)
	EventBus.super_fired.connect(_on_super_fired)
	EventBus.smash_landed.connect(_on_smash_landed)
	EventBus.bounced.connect(_on_bounced)

func _exit_tree() -> void:
	if active:   # WK-169c: the match was freed mid-showdown (quit / restart): release the hush + frames at once
		active = false   # WK-169c
		EventBus.showdown_exited.emit("abort")   # WK-169c
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
	_last_collect_t = -1.0   # WK-169c
	_sd_rec = {}   # WK-191
	_sd_unlock_t = -1.0   # WK-191
	_sd_entered = false   # WK-191
	_in_sd_showdown = false   # WK-191
	_sd_boost = {}   # WK-191
	_sd_words0 = 0   # WK-191
	_banners = []   # WK-191
	_ban_open = {}   # WK-191
	_bx_frames = 0   # WK-191
	_t_elim.clear()
	_ne_after.clear()
	_last_smash.clear()
	_tail = {"smashes": 0, "supers": 0, "bounces": {}, "boost_s": {}}
	_wk169 = {"ghost_credited": 0, "beyond_grave_credited": 0, "ghost_assisted_credited": 0, "km4_match_deciding_ghost": 0,
		"haunted": 0}
	_stats = {"t_enter": -1.0, "steps_t": [], "drops": [], "tank": [], "ended_by": "", "golden_pickups": 0,
		"max_step": 0, "first_collector": -1, "arm_s": Tuning.showdown_drop_arm_s} if lever_on() else {}   # WK-169c: + first_collector, arm_s
	for p in runner.players:
		if is_instance_valid(p):
			p.wk169_launch_mult = 1.0

## PartyMatch._on_killed, right after the kill record got its credit fields and BEFORE lives are decremented.
func annotate_kill(rec: Dictionary, victim_idx: int, killer_idx: int) -> void:
	if rec.is_empty():
		return
	var ne_before: int = runner._not_eliminated_count()
	rec["phase"] = ("2S" if active else "2") if ne_before == 2 else str(ne_before)
	if str(runner.state) == "SUDDEN_DEATH":   # WK-191 §5.5: an SD kill ("SDS" = inside the SD showdown)
		rec["phase"] = "SDS" if active else "SD"   # WK-191
	rec["showdown_step"] = step if active else 0
	rec["golden_killer"] = killer_idx >= 0 and _holder.has(killer_idx)
	rec["golden_victim"] = _holder.has(victim_idx)
	rec["t_since_grab"] = snappedf(float(runner.round_clock) - _last_collect_t, 0.0001) if _last_collect_t >= 0.0 else -1.0   # WK-169c
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
	_exit_showdown("sd")   # WK-169c: the hush releases at once (SD has its own identity)
	_sd_rec = {"t_revive": snappedf(float(runner.round_clock), 0.0001), "t_unlock": -1.0, "t_end": -1.0, "t_first_end": -1.0,   # WK-191
		"ended_by": "", "sd_showdown_t": -1.0, "revived": revived.duplicate(), "drops": [], "tank": [], "boost_s": {},   # WK-191
		"words": 0, "sd_showdown": Tuning.sd_showdown, "sd_showdown_delay": Tuning.sd_showdown_delay}   # WK-191
	_sd_unlock_t = -1.0   # WK-191
	if Tuning.sd_showdown and revived.size() == 2:   # WK-191: the SD showdown's pair = the revived pair (OFF: fighters untouched)
		fighters = revived.duplicate()   # WK-191

## WK-191: PartyMatch._tick_combat, the frame the SD revive lock ends (both revived goats unfrozen): the SD fight clock starts.
func on_sd_unlock() -> void:   # WK-191
	_sd_unlock_t = float(runner.round_clock)   # WK-191
	if not _sd_rec.is_empty():   # WK-191
		_sd_rec["t_unlock"] = snappedf(_sd_unlock_t, 0.0001)   # WK-191

## WK-191: per physics tick from PartyMatch._tick_combat in SUDDEN_DEATH (after the revive lock). Telemetry in every arm; the SD
## SHOWDOWN (spec §5.1) only with Tuning.sd_showdown. OFF = nothing but the SD boost counter (no gameplay effect).
func tick_sd(delta: float) -> void:   # WK-191
	if _sd_unlock_t < 0.0:   # WK-191
		return   # WK-191
	var now: float = float(runner.round_clock)   # WK-191
	for i in _sd_rec.get("revived", []):   # WK-191: BS (the FLY verb in the SD)
		var p = runner.players[int(i)] if int(i) < runner.players.size() else null   # WK-191
		if is_instance_valid(p) and not p.is_dead() and p.is_boosting():   # WK-191
			_sd_boost[int(i)] = float(_sd_boost.get(int(i), 0.0)) + delta   # WK-191
	if not Tuning.sd_showdown or not lever_on():   # WK-191: OFF = today
		return   # WK-191
	_track_tanks(now)   # WK-191
	if not active:   # WK-191
		if not _sd_entered and int(runner._stage_start_alive) >= 3 and _sd_pair_alive() \
				and now - _sd_unlock_t >= Tuning.sd_showdown_delay - 0.0001:   # WK-191 §5.1 (1)-(5)
			_sd_entered = true   # WK-191
			_in_sd_showdown = true   # WK-191
			_sd_words0 = wk169c_words   # WK-191
			_sd_rec["sd_showdown_t"] = snappedf(now, 0.0001)   # WK-191
			_enter_showdown(now)   # WK-191: the shipped showdown, unchanged (step 1, drop at entry, band, ka-CHUNK, hush, rims)
		return   # WK-191
	if step < Tuning.showdown_max_steps and now >= _next_step_t - 0.0001:   # WK-191 (= tick)
		_set_step(step + 1, now)   # WK-191
	if Tuning.showdown_drop:   # WK-191
		_tick_drop(now)   # WK-191

func _sd_pair_alive() -> bool:   # WK-191
	var rv: Array = _sd_rec.get("revived", [])   # WK-191
	if rv.size() != 2:   # WK-191
		return false   # WK-191
	for i in rv:   # WK-191
		var p = runner.players[int(i)] if int(i) < runner.players.size() else null   # WK-191
		if not is_instance_valid(p) or p.is_dead():   # WK-191
			return false   # WK-191
	return true   # WK-191

## WK-191 §5.5 banner log: per physics tick in COMBAT / SUDDEN_DEATH. Reads the HUD's centre + top band (read-only) and logs the
## on-screen spans of "SUDDEN DEATH!" and "SHOWDOWN!" plus the frames both are on (BX, must be 0).
func poll_banners() -> void:   # WK-191
	var hud = runner._hud if runner != null else null   # WK-191
	if hud == null or not is_instance_valid(hud):   # WK-191
		return   # WK-191
	var on := {}   # WK-191
	if hud.has_method("center_showing") and hud.center_showing():   # WK-191
		var ct = hud.get("_center_text")   # WK-191
		if ct != null:   # WK-191
			on[str(ct.text)] = true   # WK-191
	if hud.has_method("top_showing") and hud.top_showing():   # WK-191
		var tl = hud.get("_top_label")   # WK-191
		if tl != null:   # WK-191
			on[str(tl.text)] = true   # WK-191
	var now: float = snappedf(float(runner.round_clock), 0.0001)   # WK-191
	for txt in WK191_BANNERS:   # WK-191
		if on.has(txt) and not _ban_open.has(txt):   # WK-191
			var r := {"text": txt, "t_on": now, "t_off": -1.0}   # WK-191
			_banners.append(r)   # WK-191
			_ban_open[txt] = r   # WK-191
		elif not on.has(txt) and _ban_open.has(txt):   # WK-191
			(_ban_open[txt] as Dictionary)["t_off"] = now   # WK-191
			_ban_open.erase(txt)   # WK-191
	if on.has("SUDDEN DEATH!") and on.has("SHOWDOWN!"):   # WK-191
		_bx_frames += 1   # WK-191

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
	_wk191_finalize(cur_stats, length)   # WK-191

## WK-191 §5.5: the banner log + this stage's `sd` record (any arm; the director only exists with showdown telemetry on).
func _wk191_finalize(cur_stats: Dictionary, length: float) -> void:   # WK-191
	for txt in _ban_open.keys():   # WK-191: still on at the stage end
		(_ban_open[txt] as Dictionary)["t_off"] = snappedf(length, 0.0001)   # WK-191
	_ban_open.clear()   # WK-191
	cur_stats["banners"] = _banners.duplicate(true)   # WK-191
	cur_stats["banner_bx_frames"] = _bx_frames   # WK-191
	if _sd_rec.is_empty():   # WK-191
		return   # WK-191
	var sdk: Array = []   # WK-191: the kills inside the SD (phase SD / SDS)
	for k in cur_stats.get("kills", []):   # WK-191
		var ph: String = str((k as Dictionary).get("phase", ""))   # WK-191
		if ph == "SD" or ph == "SDS":   # WK-191
			sdk.append(k)   # WK-191
	if not sdk.is_empty():   # WK-191
		var first: Dictionary = sdk[0]   # WK-191
		var last: Dictionary = sdk[sdk.size() - 1]   # WK-191
		_sd_rec["t_first_end"] = snappedf(float(first.get("t", -1.0)), 0.0001)   # WK-191
		_sd_rec["t_end"] = snappedf(float(last.get("t", -1.0)), 0.0001)   # WK-191
		if sdk.size() >= 2:   # WK-191: a second double KO (no survivor)
			_sd_rec["ended_by"] = "double"   # WK-191
		elif bool(last.get("credited", false)):   # WK-191
			_sd_rec["ended_by"] = "credited"   # WK-191
		elif bool(last.get("haunted", false)):   # WK-191
			_sd_rec["ended_by"] = "haunted"   # WK-191
		else:   # WK-191
			_sd_rec["ended_by"] = "self"   # WK-191
	_sd_rec["sd_kills"] = sdk.size()   # WK-191
	var bs := {}   # WK-191
	for i in _sd_boost.keys():   # WK-191
		bs[str(i)] = snappedf(float(_sd_boost[i]), 0.001)   # WK-191
	_sd_rec["boost_s"] = bs   # WK-191
	_sd_rec["words"] = wk169c_words - _sd_words0 if _sd_entered else 0   # WK-191: "GOLDEN TANK!" pops in the SD showdown
	_sd_rec["max_step"] = step if _in_sd_showdown else 0   # WK-191
	cur_stats["sd"] = _sd_rec.duplicate(true)   # WK-191

## Visual + lever teardown (stage end, match end, SD, new stage). Field objects also go with PowerupSystem.round_sweep.
func clear() -> void:
	_exit_showdown("stage_end")   # WK-169c: eased hush release (only announced when a showdown was running)

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
	if not _in_sd_showdown or float(_stats.get("t_enter", -1.0)) < 0.0:   # WK-191: an SD re-entry keeps the COMBAT entry time
		_stats["t_enter"] = snappedf(now, 0.0001)
	_next_drop_t = now   # the first golden drop telegraphs at entry
	if runner._hud != null:
		runner._hud.show_top("SHOWDOWN!", GOLD, Tuning.showdown_banner_time)
	_build_dim()
	for i in fighters:
		_add_rim(int(i))
	EventBus.showdown_entered.emit(fighters.duplicate())   # WK-169c: hush + ka-CHUNK (audio), gold card frames (HUD)
	_wk169c_entry_rumble()   # WK-169c
	_set_step(1, now)

func _set_step(s: int, now: float) -> void:
	step = s
	(_stats["steps_t"] as Array).append(snappedf(now, 0.0001))
	_stats["max_step"] = maxi(int(_stats.get("max_step", 0)), s)   # WK-191: an SD re-entry restarts at step 1 (same as s when monotonic)
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
	EventBus.showdown_step.emit(s)   # WK-169c: LPF step + CHUNK (audio), frame pulse (HUD)
	if s > 1:
		for r in _rims.values():
			if is_instance_valid(r):
				r.pulse()

func _exit_showdown(reason: String = "stage_end") -> void:   # WK-169c: reason for the hush release
	var was_active: bool = active   # WK-169c
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
	_release_claim()   # WK-169c
	for i in _trails.keys():   # WK-169c
		_set_holder_fx(int(i), false)   # WK-169c
	if was_active:   # WK-169c
		EventBus.showdown_exited.emit(reason)   # WK-169c
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
	if _in_sd_showdown:   # WK-191 §5.5: an SD drop (same record, also listed in the stage's `sd` record)
		_tel_rec["phase"] = "sd"   # WK-191
		(_sd_rec["drops"] as Array).append(_tel_rec)   # WK-191
	_claim(_tel_pos)   # WK-169c §2.8 (b): regular bubbles on this point upgrade-pop; the regular director avoids it
	EventBus.golden_telegraph.emit(_tel_pos)   # WK-169c: the "ding-ding"
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
	var glow := GroundGlow.new()   # WK-169c §2.4.6: the spot reads before the bubble exists
	glow.global_position = _tel_pos   # WK-169c
	glow.fade_s = Tuning.showdown_drop_telegraph   # WK-169c
	glow.add_to_group("pu_field")   # WK-169c
	runner.add_child(glow)   # WK-169c
	_tel_glow = glow   # WK-169c

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
		if int(_stats.get("first_collector", -1)) < 0:   # WK-169c telemetry
			_stats["first_collector"] = idx   # WK-169c
		_last_collect_t = float(runner.round_clock)   # WK-169c
		_release_claim()   # WK-169c
		_open_tank(idx)
		_wk169c_collect_fx(pl, idx)   # WK-169c: "GOLDEN TANK!" + holder rumble
	b.on_expire = func() -> void:
		rec["popped"] = true
		_release_claim()   # WK-169c
		EventBus.golden_popped.emit(pos)   # WK-169c
	b.position = pos
	runner.add_child(b)
	_bubble = b
	EventBus.golden_live.emit(pos)   # WK-169c

func _cancel_telegraph() -> void:
	if _tel_node != null and is_instance_valid(_tel_node):
		_tel_node.queue_free()
	_tel_node = null
	_tel_pos = Vector2.INF
	if _tel_glow != null and is_instance_valid(_tel_glow):   # WK-169c
		_tel_glow.queue_free()   # WK-169c
	_tel_glow = null   # WK-169c

func _open_tank(idx: int) -> void:
	if idx < 0:
		return
	if _holder.has(idx):
		return   # a refresh: the same tank record keeps running
	var t := {"idx": idx, "t_on": snappedf(float(runner.round_clock), 0.0001), "t_off": -1.0, "supers": 0, "smashes": 0,
		"arm_s": Tuning.showdown_drop_arm_s, "t_first_super": -1.0, "t_first_smash": -1.0}   # WK-169c: GOLD SURGE telemetry (s after t_on)
	(_stats["tank"] as Array).append(t)
	if _in_sd_showdown:   # WK-191 §5.5
		t["phase"] = "sd"   # WK-191
		(_sd_rec["tank"] as Array).append(t)   # WK-191
	_holder[idx] = t
	_set_holder_fx(idx, true)   # WK-169c: holder rim x1.5 + shimmer + star trail

## Close tank records whose golden effect ended (expiry, death, sweep); feeds the drop's tank lock.
func _track_tanks(now: float) -> void:
	for idx in _holder.keys():
		var p = runner.players[idx] if idx < runner.players.size() else null
		if p == null or not is_instance_valid(p) or p.is_dead() or not PowerupSystem.golden_tank_active(p):
			(_holder[idx] as Dictionary)["t_off"] = snappedf(now, 0.0001)
			_holder.erase(idx)
			_last_tank_end_t = now
			_set_holder_fx(int(idx), false)   # WK-169c

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
		_first_t(_holder[ai], "t_first_smash")   # WK-169c

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
		_first_t(_holder[i], "t_first_super")   # WK-169c

## WK-169c: stamp a tank record's first-event time (s after its t_on) once.
func _first_t(rec: Dictionary, key: String) -> void:   # WK-169c
	if float(rec.get(key, -1.0)) < 0.0:   # WK-169c
		rec[key] = snappedf(float(runner.round_clock) - float(rec.get("t_on", 0.0)), 0.0001)   # WK-169c

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

# ------------------------------------------------------------------ WK-169c presentation + claim

## WK-169c §2.8 (b): claim the golden point on the regular powerup director (it upgrade-pops a bubble there and avoids the point).
func _claim(pos: Vector2) -> void:   # WK-169c
	var d = runner.get("_pu_director") if runner != null else null   # WK-169c
	if d != null and is_instance_valid(d) and d.has_method("claim_point"):   # WK-169c
		d.claim_point(pos, Tuning.showdown_drop_claim_r)   # WK-169c
		_claimed = true   # WK-169c

func _release_claim() -> void:   # WK-169c
	if not _claimed:   # WK-169c
		return   # WK-169c
	_claimed = false   # WK-169c
	var d = runner.get("_pu_director") if runner != null else null   # WK-169c
	if d != null and is_instance_valid(d) and d.has_method("release_claim"):   # WK-169c
		d.release_claim()   # WK-169c

## WK-169c §2.2 kinesthetic: entry = fighters 0.2 / 0.3 for 0.15 s, eliminated (ghost) seats 0.1 / 0 for 0.1 s. Human pads only
## (InputRouter.rumble_player ignores bots and honours the Options RUMBLE switch).
func _wk169c_entry_rumble() -> void:   # WK-169c
	for i in range(runner.players.size()):   # WK-169c
		var p = runner.players[i]   # WK-169c
		if not is_instance_valid(p):   # WK-169c
			continue   # WK-169c
		if fighters.has(i):   # WK-169c
			InputRouter.rumble_player(p, 0.2, 0.3, 0.15)   # WK-169c
		elif int(runner.lives_left[i]) <= 0:   # WK-169c
			InputRouter.rumble_player(p, 0.1, 0.0, 0.1)   # WK-169c

## WK-169c §2.4.7 + §2.2: the collect beat - a "GOLDEN TANK!" word pop in the goat's colour at the goat, holder pad 0.5 / 0.6.
func _wk169c_collect_fx(pl, idx: int) -> void:   # WK-169c
	if pl == null or not is_instance_valid(pl):   # WK-169c
		return   # WK-169c
	InputRouter.rumble_player(pl, 0.5, 0.6, 0.15)   # WK-169c
	var layer = runner.get_node_or_null("LivingCues")   # WK-169c: the word layer (CanvasLayer 2, with the BAAA! words)
	var cam = runner.get("_camera")   # WK-169c
	if layer == null or cam == null or not is_instance_valid(cam):   # WK-169c
		return   # WK-169c
	var w = WORD_SCENE.instantiate()   # WK-169c
	layer.add_child(w)   # WK-169c
	var col: Color = runner.player_color(idx) if runner.has_method("player_color") else GOLD   # WK-169c
	w.present(pl, cam, col, 1.0)   # WK-169c
	var txt: Label = w.get_node_or_null("Pivot/Text")   # WK-169c
	if txt != null:   # WK-169c
		txt.text = "GOLDEN TANK!"   # WK-169c
		txt.add_theme_font_size_override("font_size", 30)   # WK-169c: fits the shout-burst (40 px fits only BAAA!)
		txt.add_theme_color_override("font_color", Color("#fff6d8"))   # WK-169c
	var burst: Sprite2D = w.get_node_or_null("Pivot/Burst")   # WK-169c
	if burst != null:   # WK-169c
		burst.scale = Vector2(0.3, 0.23)   # WK-169c: a wider burst for the longer word
	wk169c_words += 1   # WK-169c

## WK-169c §2.4 in-world holder read: while a golden tank runs the holder's rim is x showdown_holder_rim_mult with a slow shimmer
## and blinks 3x in the tank's last 1.0 s; a thin star_sparkle trail streams from the jetpack. The non-holder keeps the plain rim.
func _set_holder_fx(idx: int, on: bool) -> void:   # WK-169c
	var r = _rims.get(idx)   # WK-169c
	if r != null and is_instance_valid(r):   # WK-169c
		r.holder = on   # WK-169c
	var tr = _trails.get(idx)   # WK-169c
	if not on:   # WK-169c
		if tr != null and is_instance_valid(tr):   # WK-169c
			(tr as CPUParticles2D).emitting = false   # WK-169c: the live sparkles finish their life, then it goes
			get_tree().create_timer(0.6).timeout.connect((tr as Node).queue_free)   # WK-169c
		_trails.erase(idx)   # WK-169c
		return   # WK-169c
	if tr != null and is_instance_valid(tr):   # WK-169c
		return   # WK-169c
	if idx < 0 or idx >= runner.players.size() or not is_instance_valid(runner.players[idx]):   # WK-169c
		return   # WK-169c
	var p = runner.players[idx]   # WK-169c
	var t := CPUParticles2D.new()   # WK-169c
	t.name = "GoldenTrail"   # WK-169c
	t.local_coords = false   # WK-169c: world-space, sheds along the flight path
	t.amount = 4   # WK-169c: 4 / 0.5 s = showdown_holder_trail_rate 8 per s
	t.lifetime = maxf(0.1, 4.0 / maxf(Tuning.showdown_holder_trail_rate, 1.0))   # WK-169c
	t.position = Vector2(0, 30)   # WK-169c: from the jetpack, under the body
	t.direction = Vector2.DOWN   # WK-169c
	t.spread = 35.0   # WK-169c
	t.gravity = Vector2.ZERO   # WK-169c
	t.initial_velocity_min = 30.0   # WK-169c
	t.initial_velocity_max = 70.0   # WK-169c
	if ResourceLoader.exists(SPARKLE_TEX):   # WK-169c
		t.texture = load(SPARKLE_TEX)   # WK-169c
		t.scale_amount_min = 0.16   # WK-169c
		t.scale_amount_max = 0.26   # WK-169c
	var g := Gradient.new()   # WK-169c
	g.set_color(0, Color(1.0, 0.86, 0.3, 1.0))   # WK-169c
	g.set_color(1, Color(1.0, 0.95, 0.6, 0.0))   # WK-169c
	t.color_ramp = g   # WK-169c: normal blend (additive gold washes out on bright skies)
	t.emitting = true   # WK-169c
	p.add_child(t)   # WK-169c
	_trails[idx] = t   # WK-169c

## WK-169c QA (gbplay eval): what the polish layer is showing right now.
func wk169c_state() -> Dictionary:   # WK-169c
	var holders: Array = []   # WK-169c
	for i in _rims.keys():   # WK-169c
		if is_instance_valid(_rims[i]) and bool(_rims[i].holder):   # WK-169c
			holders.append(int(i))   # WK-169c
	return {"active": active, "step": step, "claimed": _claimed, "tel_glow": _tel_glow != null and is_instance_valid(_tel_glow),   # WK-169c
		"holder_rims": holders, "trails": _trails.keys(), "words": wk169c_words, "last_collect_t": _last_collect_t}   # WK-169c

## WK-169c §2.4.6: the golden telegraph's ground-glow ring at the fair point - the halo's sizing rule (screen floor / body multiple),
## fading in over the telegraph, drawn below decks and goats. Freed with the telegraph.
class GroundGlow:   # WK-169c
	extends Node2D
	var fade_s := 1.0
	var _t := 0.0
	func _ready() -> void:
		z_as_relative = false
		z_index = -2
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var cam := get_viewport().get_camera_2d()
		var z: float = maxf(cam.zoom.x, 0.05) if cam != null else 1.0
		var r: float = PowerupBubble.GoldenHalo.diameter_world(z) * 0.5
		var a: float = clampf(_t / maxf(fade_s, 0.05), 0.0, 1.0)
		for k in range(6):   # soft filled glow (stacked discs, densest at the centre)
			var f: float = 1.0 - float(k) / 6.0
			draw_circle(Vector2.ZERO, r * f, Color(1.0, 0.74, 0.14, 0.11 * a))
		draw_arc(Vector2.ZERO, r * 0.9, 0.0, TAU, 72, Color(1.0, 0.8, 0.2, 0.95 * a), 6.0 / z, true)
		draw_arc(Vector2.ZERO, r * 0.9 + 4.0 / z, 0.0, TAU, 72, Color(0.231, 0.141, 0.106, 0.45 * a), 2.0 / z, true)

## Gold rim light behind a fighter: a soft gold halo plus a crisp gold ring with a thin chocolate keyline (Toybox read on
## pale and dark backdrops alike). Sized in SCREEN px (divided by the camera zoom), so it reads at every play zoom.
class RimLight:
	extends Node2D
	var radius := 44.0
	var holder := false   # WK-169c: golden-tank holder read (x showdown_holder_rim_mult, shimmer, last-second blink)
	var _pulse := 0.0
	var _t := 0.0   # WK-169c
	var _z := -1.0
	func _ready() -> void:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	func pulse() -> void:
		_pulse = 1.0
	func _process(delta: float) -> void:
		var cam := get_viewport().get_camera_2d()
		var z: float = maxf(cam.zoom.x, 0.05) if cam != null else 1.0
		_t += delta   # WK-169c
		if _pulse > 0.0:
			_pulse = maxf(0.0, _pulse - delta * 2.5)
			queue_redraw()
		elif holder:   # WK-169c: the shimmer animates every frame
			queue_redraw()   # WK-169c
		elif absf(z - _z) > 0.002:
			queue_redraw()
		_z = z
	func _draw() -> void:
		var z: float = maxf(_z, 0.05)
		var c: Color = Tuning.showdown_rim_color
		var a: float = minf(1.0, Tuning.showdown_rim_alpha * (1.0 + 0.6 * _pulse))
		var w: float = Tuning.showdown_rim_px * (1.0 + 0.5 * _pulse) / z
		if holder:   # WK-169c: wider ring, alpha shimmer 0.75 <-> 1.0 over 0.8 s, 3 blinks in the tank's last 1.0 s
			w *= Tuning.showdown_holder_rim_mult   # WK-169c
			a = 0.875 + 0.125 * sin(_t * TAU / 0.8)   # WK-169c
			var p = get_parent()   # WK-169c
			var left: float = float(p.get("powerup_time_left")) if p != null and p.get("powerup_time_left") != null else 9.0   # WK-169c
			if left > 0.0 and left < 1.0 and fmod(left, 1.0 / 3.0) < 1.0 / 6.0:   # WK-169c: off-phase of each blink
				a = 0.2   # WK-169c
		var gap: float = Tuning.showdown_rim_gap_px / z
		var halo: float = Tuning.showdown_rim_halo_px / z
		var rr: float = radius * Tuning.showdown_rim_radius_mult + gap + w * 0.5
		draw_arc(Vector2.ZERO, rr + w * 0.5 + halo * 0.5, 0.0, TAU, 64, Color(c.r, c.g, c.b, a * 0.25), halo, true)   # soft outer glow (no fill over the body)
		draw_arc(Vector2.ZERO, rr + w * 0.5 + 1.0 / z, 0.0, TAU, 64, Color(0.231, 0.141, 0.106, a * 0.75), 2.0 / z, true)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 64, Color(c.r, c.g, c.b, a), w, true)
