extends Node2D
## WK-37 GHOST GOATS director (docs/specs/wk37a_ghost_goats_2026-11-14.md). Owned by PartyMatch, created ONLY for a
## BRAWL match whose MatchConfig.ghosts != OFF — with GHOSTS OFF this node never exists, so OFF is byte-for-byte the
## pre-WK-37 game. Added to the arena right after the level root (before the Players), so by tree order clouds and
## ghosts draw ABOVE platforms and BELOW every living goat (spec §5 draw order).
##
## Responsibilities:
##   * elimination -> a GhostGoat ghost_spawn_delay (REAL s, > double_ko_window) later, at the death position clamped
##     into the camera view; cancelled if the stage ended / the player was revived (double-KO SD) meanwhile (T7);
##   * per tick: drive each ghost (its provider = the human's own InputHuman, or a GhostBot), clamp it to the view
##     (ghosts follow the camera, NEVER the reverse — spec §4), alpha near living goats, puff-ready orbit;
##   * PUFF rules: arm delay, cooldown, cap, one live cloud, hush (K-5 MATCH POINT / K-6 SUDDEN DEATH), BAA ONLY = dud,
##     spawn blocked by static geometry -> nudged up <= ghost_puff_nudge_max else dud (no charge spent);
##   * BLEAT: shared rate limit, "BAAA!" word puff (ghost variant), EventBus.bleated hook for WK-53's sample;
##   * K-2 HAUNTED bookkeeping: per-player last cloud contact vs last surface bounce (PartyMatch asks is_haunted());
##   * HUD: ghost head + cooldown ring on the corner card, the 3 s ghost legend, hush grey + "SHH";
##   * telemetry (spec §8.2) written into the stage's round_stats record by finalize_stats().
## Presentation-only toward the sim EXCEPT the cloud's standard surface bounce on neutral living players.

const GHOST_SCRIPT := preload("res://src/entities/GhostGoat.gd")
const PUFF_SCRIPT := preload("res://src/entities/GhostPuff.gd")
const GHOST_BOT_SCRIPT := preload("res://src/core/GhostBot.gd")
const WORD_SCENE := preload("res://scenes/ui/WordBurst.tscn")
const LEGEND_SCENE := preload("res://scenes/ui/GhostLegend.tscn")
const HUSH_TEXT := "MATCH POINT · GHOSTS HUSH"
# --- WK-37c (consts here while WK-128 owns Tuning.gd; move to the Tuning ghost block later) ---
# T11 stacking: the old push faded to 0 AT bot_ghost_spacing (and a 0.05 dead-zone cut it at ~190 px), so two bot
# ghosts settled ~190 px apart = a fail every frame. The push now reaches past the target and the hover / spawn
# picks keep a margin over it.
const SEP_RADIUS_MULT := 1.4          # separation push active out to spacing x this (280 px)
const PICK_SPACING_MULT := 1.3        # hover spots / spawn spots keep spacing x this (260 px) from other ghosts
const SPAWN_SPREAD_STEP := 130.0      # px: spawn spread search ring step (8 directions x 5 rings)
# Dud feedback: a ghost whose cloud is blocked by a platform sees the would-be cloud outline flash red + shake.
const BLOCKED_COLOR := Color("#ff4a3d")

var runner                        # PartyMatch
var mode: int = 0                 # MatchConfig.Ghosts.ON / BAA_ONLY
var ghosts := {}                  # player idx -> GhostGoat
var clouds: Array = []            # live GhostPuff nodes
var _pending: Array = []          # [{idx, left (real s), pos, t_elim}]
var _cloud_layer: Node2D
var _ghost_layer: Node2D
var _ui: CanvasLayer              # word bursts + ghost legends (screen space, below the HUD)
var _clock := 0.0                 # scaled combat clock (charges/cooldowns)
var _hushed := false
var _hush_shown := false
var _in_cloud_bounce := false
var _last_cloud_t := {}           # player idx -> round_clock of the last cloud contact
var _last_bounce_t := {}          # player idx -> round_clock of the last NON-cloud surface bounce
var _bleat_log := {}              # player idx -> [real ms of recent bleats]
var _bot_targets := {}            # ghost -> pending target Player (bot placement QA)
var _contacts_open: Array = []    # [{rec, player, t}] contacts awaiting their survived_3s verdict
# stage telemetry
var _st := {}
var _ghost_rows := {}             # idx -> row dict (spec §8.2 `ghosts[]`)
var _pairs_frames := 0
var _pairs_ok := 0
var blocked_fx_count := 0         # QA: blocked-puff markers shown (WK-37c)

func setup(runner_ref, ghosts_mode: int) -> void:
	runner = runner_ref
	mode = ghosts_mode
	name = "GhostDirector"
	_cloud_layer = Node2D.new()
	_cloud_layer.name = "Clouds"
	add_child(_cloud_layer)
	_ghost_layer = Node2D.new()
	_ghost_layer.name = "Ghosts"
	add_child(_ghost_layer)
	_ui = CanvasLayer.new()
	_ui.layer = 2   # above the pips (1) / chevrons (0), below the KO blast (5) and the HUD (10)
	add_child(_ui)
	EventBus.bounced.connect(_on_bounced)
	KillPipeline.killed.connect(_on_any_killed)

## WK-37c (WK-34 follow-up): the pause plate hides the HUD cards + controls legend for the whole pause
## (PartyMatch.set_match_overlays_hidden). The ghost layer's screen-space overlays (the "GHOST! FLOAT · PUFF · BAA"
## legend by a card, any frozen "BAAA!" bubble) follow suit. SceneTree.process_frame still fires while paused, so this
## needs no PROCESS_MODE_ALWAYS node; the overlays' own tweens are paused with the tree and resume where they were.
func _ready() -> void:
	if not get_tree().process_frame.is_connected(_sync_pause_overlays):
		get_tree().process_frame.connect(_sync_pause_overlays)

func _sync_pause_overlays() -> void:
	if _ui != null and is_instance_valid(_ui):
		var show: bool = not get_tree().paused
		if _ui.visible != show:
			_ui.visible = show

func _exit_tree() -> void:
	if get_tree() != null and get_tree().process_frame.is_connected(_sync_pause_overlays):
		get_tree().process_frame.disconnect(_sync_pause_overlays)
	if EventBus.bounced.is_connected(_on_bounced):
		EventBus.bounced.disconnect(_on_bounced)
	if KillPipeline.killed.is_connected(_on_any_killed):
		KillPipeline.killed.disconnect(_on_any_killed)
	for g in ghosts.values():
		if is_instance_valid(g) and g.provider != null and g.provider.has_method("dispose"):
			g.provider.dispose()

# ------------------------------------------------------------------ public API (PartyMatch / UI / QA)

func clock() -> float:
	return _clock

func is_hushed() -> bool:
	return _hushed

func puffs_enabled() -> bool:
	return mode == MatchConfig.Ghosts.ON

func ghost_for(i: int):
	var g = ghosts.get(i, null)
	return g if g != null and is_instance_valid(g) else null

func living_players() -> Array:
	var out: Array = []
	for p in runner.players:
		if is_instance_valid(p) and not p.is_dead():
			out.append(p)
	return out

## A ghost's puff is ready: ON, not hushed, armed + cooled down, under the cap, no live cloud of its own.
func puff_ready(g) -> bool:
	if g == null or not puffs_enabled() or _hushed or g.frozen:
		return false
	if g.puffs_used >= Tuning.ghost_puff_max_per_stage:
		return false
	if g.live_cloud != null and is_instance_valid(g.live_cloud):
		return false
	return _clock >= g.next_puff_t

## Bot planning: the puff will be ready within `lead` s (same rules as puff_ready, cooldown allowed to run out).
func puff_ready_within(g, lead: float) -> bool:
	if g == null or not puffs_enabled() or _hushed or g.frozen:
		return false
	if g.puffs_used >= Tuning.ghost_puff_max_per_stage:
		return false
	if g.live_cloud != null and is_instance_valid(g.live_cloud):
		return false
	return _clock + lead >= g.next_puff_t

## 0..1 cooldown progress for the HUD ring (1 = ready).
func puff_progress(g) -> float:
	if g == null or g.puffs_used >= Tuning.ghost_puff_max_per_stage:
		return 0.0
	if puff_ready(g):
		return 1.0
	var span: float = Tuning.ghost_puff_arm_delay if g.puffs_used == 0 else _cooldown_for(g)
	return clampf(1.0 - (g.next_puff_t - _clock) / maxf(span, 0.01), 0.0, 1.0)

## Human ghosts: ghost_puff_cooldown (7 s). Bot ghosts: / bot_ghost_puff_rate_mult (14 s, spec §6).
func _cooldown_for(g) -> float:
	if g != null and not g.human:
		return Tuning.ghost_puff_cooldown / maxf(Tuning.bot_ghost_puff_rate_mult, 0.01)
	return Tuning.ghost_puff_cooldown

## Called from PartyMatch._on_killed when a player loses their LAST life in BRAWL COMBAT/SUDDEN_DEATH.
func on_eliminated(idx: int, victim) -> void:
	if idx < 0 or not is_instance_valid(victim):
		return
	_pending.append({"idx": idx, "left": Tuning.ghost_spawn_delay, "pos": victim.global_position,
		"t_elim": float(runner.round_clock)})
	var row := _row(idx)
	row["t_elim"] = float(runner.round_clock)

## K-2: a death with NO credited attacker whose last surface contact in the last ghost_puff_fence_s was a cloud.
func is_haunted(idx: int) -> bool:
	var tc: float = float(_last_cloud_t.get(idx, -INF))
	if tc == -INF:
		return false
	var now: float = float(runner.round_clock)
	if now - tc > Tuning.ghost_puff_fence_s:
		return false
	return tc >= float(_last_bounce_t.get(idx, -INF))

## s since this player's last cloud contact (9999 if none) — the per-death `dt_last_cloud_contact`.
func dt_last_cloud_contact(idx: int) -> float:
	var tc: float = float(_last_cloud_t.get(idx, -INF))
	return 9999.0 if tc == -INF else float(runner.round_clock) - tc

## _bounce_go: open this stage's telemetry.
func on_combat_start(cur_stats: Dictionary) -> void:
	_clock = 0.0
	_hush_shown = false
	_hushed = false
	_st = {"ghosts_mode": ["ON", "BAA_ONLY", "OFF"][clampi(mode, 0, 2)], "hush_entered_t": -1.0,
		"clouds_spawned": 0, "clouds_popped_by_super": 0, "clouds_popped_by_stun": 0, "clouds_popped_by_hush": 0}
	_ghost_rows.clear()
	_pairs_frames = 0
	_pairs_ok = 0
	_last_cloud_t.clear()
	_last_bounce_t.clear()
	if cur_stats != null:
		for k in _st.keys():
			cur_stats[k] = _st[k]

## STAGE_END / MATCH_END: freeze + fade every ghost with the KO freeze, pop pending spawns, sink clouds out quietly.
func on_stage_end() -> void:
	_pending.clear()
	for g in ghosts.values():
		if is_instance_valid(g):
			g.frozen = true
			g.set_orbit_visible(false)
	for c in clouds.duplicate():
		if is_instance_valid(c):
			c.pop("stage")

## Write this stage's ghost telemetry into its round_stats record (called just before PartyMatch appends it).
func finalize_stats(cur_stats: Dictionary) -> void:
	if cur_stats == null or cur_stats.is_empty():
		return
	for e in _contacts_open:
		(e["rec"] as Dictionary)["survived_3s"] = true   # alive at stage end
	_contacts_open.clear()
	var rows: Array = []
	for idx in _ghost_rows.keys():
		var r: Dictionary = _ghost_rows[idx]
		if float(r.get("t_spawn", -1.0)) < 0.0:
			continue   # eliminated by the stage-ending KO (or revived into SD): never became a ghost
		var g = ghost_for(int(idx))
		if g != null:
			r["max_offscreen_frames"] = int(g.stats.get("offscreen_frames", 0))
		if float(r.get("t_spawn", -1.0)) >= 0.0:
			r["controllable_s"] = float(runner.round_clock) - float(r["t_spawn"])
		rows.append(r)
	cur_stats["ghosts"] = rows
	for k in _st.keys():
		cur_stats[k] = _st[k]
	cur_stats["ghost_pairs"] = {"frames": _pairs_frames, "ok_frames": _pairs_ok}
	cur_stats["ghost_motion"] = ghost_motion()

## Remove every ghost + cloud (new stage / rematch / scene exit). The card skull reset is PartyMatch's set_dead(false).
func clear_all() -> void:
	_pending.clear()
	for c in clouds.duplicate():
		if is_instance_valid(c):
			c.pop("stage")
	clouds.clear()
	for i in ghosts.keys():
		var g = ghosts[i]
		if is_instance_valid(g):
			if g.provider != null and g.provider.has_method("dispose"):
				g.provider.dispose()
			g.queue_free()
		if runner._hud != null and runner._hud.has_method("set_ghost"):
			runner._hud.set_ghost(int(i), false, false)
	ghosts.clear()
	_bot_targets.clear()
	_contacts_open.clear()
	for c in _ui.get_children():
		c.queue_free()
	_hushed = false

## Remove one player's ghost now (MATCH_END: a winner on points while dead is respawned for the bow).
func remove_ghost(i: int) -> void:
	var g = ghosts.get(i, null)
	ghosts.erase(i)
	_pending = _pending.filter(func(e) -> bool: return int(e["idx"]) != i)
	if g != null and is_instance_valid(g):
		if g.live_cloud != null and is_instance_valid(g.live_cloud):
			g.live_cloud.pop("stage")
		if g.provider != null and g.provider.has_method("dispose"):
			g.provider.dispose()
		g.queue_free()
	if runner._hud != null and runner._hud.has_method("set_ghost"):
		runner._hud.set_ghost(i, false, false)

## QA (spec §6 ghost_motion): stuck bot ghosts (zero displacement > ghost_stuck_secs away from a hover spot).
func ghost_motion() -> Array:
	var out: Array = []
	for i in ghosts.keys():
		var g = ghost_for(int(i))
		if g == null:
			continue
		out.append({"player": int(i), "bot": not g.human, "stuck_episodes": int(g.stats.get("stuck_episodes", 0))})
	return out

# ------------------------------------------------------------------ view helpers (camera -> world)

## Current camera zoom (1.0 without a camera) — GhostGoat's wide-camera readability compensation reads it.
func cam_zoom() -> float:
	var cam = runner._camera if runner != null else null
	if cam == null or not is_instance_valid(cam):
		return 1.0
	return maxf(cam.zoom.x, 0.01)

## The camera's visible world rect (actual, smoothed camera — what the player sees).
func view_rect() -> Rect2:
	var cam = runner._camera
	if cam == null or not is_instance_valid(cam):
		return Rect2()
	var vp: Vector2 = get_viewport_rect().size
	var z: float = maxf(cam.zoom.x, 0.01)
	var half: Vector2 = vp / (2.0 * z)
	return Rect2(cam.get_screen_center_position() - half, half * 2.0)

## The view rect inset by ghost_view_inset SCREEN px (converted by the current zoom).
func view_inset_rect() -> Rect2:
	var r := view_rect()
	var cam = runner._camera
	var z: float = maxf(cam.zoom.x, 0.01) if cam != null and is_instance_valid(cam) else 1.0
	var ins: float = Tuning.ghost_view_inset / z
	return r.grow(-ins)

func clamp_to_view(p: Vector2) -> Vector2:
	var r := view_inset_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return p
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))

## Spacing (with margin) a hover / spawn spot keeps from other ghosts and their hover spots.
func pick_spacing() -> float:
	return Tuning.bot_ghost_spacing * PICK_SPACING_MULT

func nearest_other_ghost_dist(me, p: Vector2) -> float:
	var best := INF
	for g in ghosts.values():
		if g == me or not is_instance_valid(g):
			continue
		best = minf(best, p.distance_to(g.global_position))
		var b = g.provider
		if b != null and "hover" in b and (b.hover as Vector2) != Vector2.ZERO:
			best = minf(best, p.distance_to(b.hover))
	return best

## Soft separation steer (bots): away from any ghost closer than bot_ghost_spacing x SEP_RADIUS_MULT (the push still
## has bite AT the spacing target, so the equilibrium sits above it). A push into the view-inset edge the ghost is pinned
## against slides along that edge instead (two ghosts swept by a panning camera onto one edge used to stay stacked).
func separation_push(me) -> Vector2:
	var push := Vector2.ZERO
	var rad: float = Tuning.bot_ghost_spacing * SEP_RADIUS_MULT
	for g in ghosts.values():
		if g == me or not is_instance_valid(g):
			continue
		var d: Vector2 = me.global_position - g.global_position
		var l: float = d.length()
		if l < 1.0:
			d = Vector2.from_angle(float(me.idx) * 2.4)   # exactly stacked (same death spot): a per-player tie-break
			l = 1.0
		if l < rad:
			push += (d / l) * (1.0 - l / rad)
	if push.length() < 0.001:
		return push
	var r := view_inset_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return push
	var p: Vector2 = me.global_position
	var out := push
	var tie: float = 1.0 if int(me.idx) % 2 == 0 else -1.0
	if (p.x <= r.position.x + 2.0 and out.x < 0.0) or (p.x >= r.end.x - 2.0 and out.x > 0.0):
		var sy: float = signf(out.y) if absf(out.y) > 0.05 else tie
		if (p.y <= r.position.y + 2.0 and sy < 0.0) or (p.y >= r.end.y - 2.0 and sy > 0.0):
			sy = -sy   # corner: slide the other way
		out = Vector2(0.0, out.y + sy * absf(out.x))
	elif (p.y <= r.position.y + 2.0 and out.y < 0.0) or (p.y >= r.end.y - 2.0 and out.y > 0.0):
		var sx: float = signf(out.x) if absf(out.x) > 0.05 else tie
		if (p.x <= r.position.x + 2.0 and sx < 0.0) or (p.x >= r.end.x - 2.0 and sx > 0.0):
			sx = -sx
		out = Vector2(out.x + sx * absf(out.y), 0.0)
	return out

## Spawn spot: the death position clamped into the view inset, spread to >= spacing x PICK_SPACING_MULT from every
## other ghost (two players rung out at one spot, or swept onto the same edge point by the clamp, used to start
## stacked). Smallest displacement wins; falls back to the roomiest candidate. Always inside the inset (T1).
func _spread_spawn(me, want: Vector2) -> Vector2:
	var need: float = pick_spacing()
	var best := want
	var best_d: float = nearest_other_ghost_dist(me, want)
	if best_d >= need:
		return want
	for ring in range(1, 6):
		for k in range(8):
			var dir := Vector2.from_angle(float(k) * TAU / 8.0 + float(ring) * 0.39)
			var cand: Vector2 = clamp_to_view(want + dir * SPAWN_SPREAD_STEP * float(ring))
			var d: float = nearest_other_ghost_dist(me, cand)
			if d >= need:
				return cand
			if d > best_d:
				best_d = d
				best = cand
	return best

func note_bot_target(g, target) -> void:
	_bot_targets[g] = target

# ------------------------------------------------------------------ tick

func _physics_process(delta: float) -> void:
	if runner == null:
		return
	var st: String = str(runner.state)
	var fight: bool = st == "COMBAT" or st == "SUDDEN_DEATH"
	var rdelta: float = delta / maxf(Engine.time_scale, 0.05)
	if fight:
		_clock += delta
		_update_hush()
		_tick_pending(rdelta)
	var view := view_inset_rect()
	var living := living_players()
	for i in ghosts.keys():
		var g = ghost_for(int(i))
		if g == null:
			continue
		var before: Vector2 = g.global_position
		var e: Dictionary = g.tick(delta, view)
		if not fight:
			continue
		var row := _row(int(i))
		if bool(e["active"]):
			row["input_active_s"] = float(row.get("input_active_s", 0.0)) + delta
			g.stats["last_active_t"] = _clock
		elif _clock - float(g.stats.get("last_active_t", -INF)) <= 0.5:
			row["input_active_s"] = float(row.get("input_active_s", 0.0)) + delta
		row["ghost_s"] = float(row.get("ghost_s", 0.0)) + delta
		if _hushed:
			row["hushed_s"] = float(row.get("hushed_s", 0.0)) + delta
		if float(row.get("t_first_move", -1.0)) < 0.0 and before.distance_to(g.global_position) > 0.5 and bool(e["active"]):
			row["t_first_move"] = float(runner.round_clock)
		_stuck_check(g, before, delta)
		if bool(e["puff"]):
			_try_puff(g)
		if bool(e["bleat"]):
			_try_bleat(g)
		# alpha: recede near a fight
		var near := false
		for p in living:
			if (p.global_position as Vector2).distance_to(g.global_position) <= Tuning.ghost_near_radius:
				near = true
				break
		g.set_alpha_target(Tuning.ghost_alpha_near if near else Tuning.ghost_alpha)
		g.set_orbit_visible(puff_ready(g))
	if fight:
		_sample_pairs()
		_update_hud()
		_resolve_contacts_open()

## Render-frame QA: frames a ghost centre spent outside the real viewport (spec T3: must be 0).
func _process(_delta: float) -> void:
	if runner == null:
		return
	var st: String = str(runner.state)
	if st != "COMBAT" and st != "SUDDEN_DEATH":
		return
	var r := view_rect()
	for g in ghosts.values():
		if is_instance_valid(g) and not g.frozen and r.size.x > 0.0 and not r.has_point(g.global_position):
			g.stats["offscreen_frames"] = int(g.stats.get("offscreen_frames", 0)) + 1

func _tick_pending(rdelta: float) -> void:
	for e in _pending.duplicate():
		e["left"] = float(e["left"]) - rdelta
		if float(e["left"]) > 0.0:
			continue
		_pending.erase(e)
		var i: int = int(e["idx"])
		if i < 0 or i >= runner.players.size():
			continue
		var p = runner.players[i]
		# still eliminated? (a double-KO SD revive puts both back in the fight — never a ghost for them, T7)
		if not is_instance_valid(p) or not p.is_dead() or int(runner.lives_left[i]) > 0 or ghosts.has(i):
			continue
		_spawn_ghost(i, p, e["pos"])

func _spawn_ghost(i: int, p, death_pos: Vector2) -> void:
	var g = GHOST_SCRIPT.new()
	var human: bool = runner.is_human_player(i)
	var prov
	if human:
		prov = p.provider   # same player index, same device (INV-8)
	g.setup(i, str(p.skin), runner.player_color(i), human, prov, self)
	_ghost_layer.add_child(g)
	g.global_position = _spread_spawn(g, clamp_to_view(death_pos))
	if not human:
		g.provider = GHOST_BOT_SCRIPT.new(g, self, runner, death_pos)
	g.next_puff_t = _clock + Tuning.ghost_puff_arm_delay
	g.stats = {"offscreen_frames": 0, "stuck_episodes": 0, "still_t": 0.0}
	ghosts[i] = g
	var row := _row(i)
	row["human"] = human
	row["t_spawn"] = float(runner.round_clock)
	row["spawn_pos"] = g.global_position
	row["spawn_in_view"] = view_inset_rect().grow(1.0).has_point(g.global_position)
	if runner._hud != null and runner._hud.has_method("set_ghost"):
		runner._hud.set_ghost(i, true, puffs_enabled())
	if human:
		_show_legend(i)

func _row(i: int) -> Dictionary:
	if not _ghost_rows.has(i):
		_ghost_rows[i] = {"idx": i, "human": runner.is_human_player(i), "t_elim": -1.0, "t_spawn": -1.0,
			"t_first_move": -1.0, "ghost_s": 0.0, "controllable_s": 0.0, "input_active_s": 0.0, "puffs": [],
			"duds": 0, "bleats": 0, "hushed_s": 0.0, "max_offscreen_frames": 0}
	return _ghost_rows[i]

# ------------------------------------------------------------------ hush (K-5 / K-6)

func _update_hush() -> void:
	var h := false
	if str(runner.state) == "SUDDEN_DEATH":
		h = true
	elif Tuning.ghost_hush_at_match_point:
		h = _match_point_live()
	if h and not _hushed:
		if float(_st.get("hush_entered_t", -1.0)) < 0.0:
			_st["hush_entered_t"] = float(runner.round_clock)
		# live clouds pop within ghost_puff_hush_pop (immediately here)
		for c in clouds.duplicate():
			if is_instance_valid(c):
				_st["clouds_popped_by_hush"] = int(_st.get("clouds_popped_by_hush", 0)) + 1
				c.pop("hush")
	_hushed = h
	if _hushed and not _hush_shown and not ghosts.is_empty() and str(runner.state) == "COMBAT" and puffs_enabled():
		_hush_shown = true
		if runner._hud != null:
			runner._hud.show_top(HUSH_TEXT, Color("#9aa0a8"), 1.4)

## Does any NOT-ELIMINATED player's next credited KO win the match (BrawlMode.match_winner with a hypothetical +1)?
func _match_point_live() -> bool:
	var saved: Array = runner.scores
	var hit := false
	for i in range(runner.players.size()):
		if int(runner.lives_left[i]) <= 0:
			continue
		var hypo: Array = saved.duplicate()
		hypo[i] = int(hypo[i]) + 1
		runner.scores = hypo
		var w: int = runner._mode.match_winner(runner)
		runner.scores = saved
		if w == i:
			hit = true
			break
	runner.scores = saved
	return hit

# ------------------------------------------------------------------ puff

func _try_puff(g) -> void:
	var row := _row(int(g.idx))
	if not puff_ready(g):
		if _hushed and puffs_enabled():
			(row["puffs"] as Array).append({"t": float(runner.round_clock), "pos": g.global_position, "hushed_dud": true,
				"contacts": []})
		row["duds"] = int(row.get("duds", 0)) + 1
		g.dud_fx()
		return
	var want: Vector2 = g.global_position + Tuning.ghost_puff_spawn_offset
	var center: Variant = _cloud_spawn_center(want)
	if center == null:
		row["duds"] = int(row.get("duds", 0)) + 1
		row["blocked_duds"] = int(row.get("blocked_duds", 0)) + 1
		g.dud_fx()
		_blocked_fx(g, want)
		return
	var c = PUFF_SCRIPT.new()
	c.setup(runner, self, int(g.idx), g.color)
	_cloud_layer.add_child(c)
	c.global_position = center
	clouds.append(c)
	g.live_cloud = c
	g.puffs_used += 1
	g.next_puff_t = _clock + _cooldown_for(g)
	var tgt = _bot_targets.get(g, null)
	_bot_targets.erase(g)
	var rec := {"t": float(runner.round_clock), "pos": center, "hushed_dud": false, "contacts": [],
		"target": runner.players.find(tgt) if tgt != null and is_instance_valid(tgt) else -1}
	(row["puffs"] as Array).append(rec)
	c.record = rec
	_st["clouds_spawned"] = int(_st.get("clouds_spawned", 0)) + 1

## Cloud centre: inside (visible rect ∩ camera_bounds) and clear of static geometry; nudged up <= ghost_puff_nudge_max.
## null = dud (no charge spent).
func _cloud_spawn_center(want: Vector2) -> Variant:
	var half: Vector2 = Tuning.ghost_puff_size * 0.5
	var allowed: Rect2 = view_rect().intersection(runner.camera_bounds as Rect2)
	allowed = allowed.grow_individual(-half.x, -half.y, -half.x, -half.y)
	if allowed.size.x < 0.0 or allowed.size.y < 0.0:
		return null
	var c := Vector2(clampf(want.x, allowed.position.x, allowed.end.x), clampf(want.y, allowed.position.y, allowed.end.y))
	var shape := RectangleShape2D.new()
	shape.size = Tuning.ghost_puff_size
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.collision_mask = Player.MASK_SURFACES
	q.collide_with_areas = false
	var space := get_world_2d().direct_space_state
	var step := 20.0
	var dy := 0.0
	while dy <= Tuning.ghost_puff_nudge_max + 0.1:
		var p := c - Vector2(0.0, dy)
		if p.y < allowed.position.y - 0.1:
			break
		q.transform = Transform2D(0.0, p)
		if space.intersect_shape(q, 1).is_empty():
			return p
		dy += step
	return null

## WK-37c dud feedback: the cloud outline the ghost asked for flashes red and shakes "no" right where it would have gone
## (over the platform that blocks it), so the dud reads as "blocked here", not "broken". Never solid, no charge spent,
## not in `clouds` (no contacts, no telemetry, no director callbacks).
func _blocked_fx(g, want: Vector2) -> void:
	var c = PUFF_SCRIPT.new()
	c.setup(runner, null, int(g.idx), BLOCKED_COLOR)
	c.blocked = true
	_cloud_layer.add_child(c)
	var r := view_rect()
	var half: Vector2 = Tuning.ghost_puff_size * 0.5
	if r.size.x > 2.0 * half.x and r.size.y > 2.0 * half.y:
		want = Vector2(clampf(want.x, r.position.x + half.x, r.end.x - half.x),
			clampf(want.y, r.position.y + half.y, r.end.y - half.y))
	c.global_position = want
	blocked_fx_count += 1

## QA ONLY (gbplay eval / headless harness): spawn a cloud for player `owner_idx` at `pos`, bypassing the ghost
## charge rules (the cloud itself follows every contact rule). Never called by gameplay code.
func debug_spawn_cloud(owner_idx: int, pos: Vector2):
	var c = PUFF_SCRIPT.new()
	c.setup(runner, self, owner_idx, runner.player_color(owner_idx))
	_cloud_layer.add_child(c)
	c.global_position = pos
	clouds.append(c)
	c.record = {"t": float(runner.round_clock), "pos": pos, "hushed_dud": false, "contacts": [], "target": -1, "debug": true}
	return c

## GhostPuff callbacks.
func begin_cloud_bounce() -> void:
	_in_cloud_bounce = true

func end_cloud_bounce() -> void:
	_in_cloud_bounce = false

func on_cloud_contact(c, p, side: String, fuel_before: float) -> void:
	var pi: int = runner.players.find(p)
	if pi < 0:
		return
	_last_cloud_t[pi] = float(runner.round_clock)
	var e := {"player": pi, "t": float(runner.round_clock), "side": side, "fuel_before": snappedf(fuel_before, 0.1),
		"survived_3s": null}
	if c.record is Dictionary and not (c.record as Dictionary).is_empty():
		((c.record as Dictionary)["contacts"] as Array).append(e)
	_contacts_open.append({"rec": e, "player": p, "t": float(runner.round_clock)})

func on_cloud_removed(c) -> void:
	clouds.erase(c)
	if c.popped_by == "super":
		_st["clouds_popped_by_super"] = int(_st.get("clouds_popped_by_super", 0)) + 1
	elif c.popped_by == "stun":
		_st["clouds_popped_by_stun"] = int(_st.get("clouds_popped_by_stun", 0)) + 1
	if c.record is Dictionary and not (c.record as Dictionary).is_empty():
		(c.record as Dictionary)["popped_by"] = c.popped_by
	var g = ghost_for(c.owner_idx)
	if g != null and g.live_cloud == c:
		g.live_cloud = null

func _on_bounced(body) -> void:
	if _in_cloud_bounce or runner == null:
		return
	var i: int = runner.players.find(body)
	if i >= 0:
		_last_bounce_t[i] = float(runner.round_clock)

func _on_any_killed(victim, _cause, _attacker) -> void:
	for e in _contacts_open.duplicate():
		if e["player"] == victim:
			(e["rec"] as Dictionary)["survived_3s"] = float(runner.round_clock) - float(e["t"]) >= 3.0
			_contacts_open.erase(e)

func _resolve_contacts_open() -> void:
	var now: float = float(runner.round_clock)
	for e in _contacts_open.duplicate():
		if now - float(e["t"]) >= 3.0:
			(e["rec"] as Dictionary)["survived_3s"] = true
			_contacts_open.erase(e)

# ------------------------------------------------------------------ bleat

func _try_bleat(g) -> void:
	var now := Time.get_ticks_msec()
	var hist: Array = _bleat_log.get(g.idx, [])
	hist = hist.filter(func(t) -> bool: return now - int(t) < 1000)
	if not hist.is_empty() and float(now - int(hist.back())) / 1000.0 < Tuning.ghost_bleat_min_interval:
		return
	if hist.size() >= Tuning.ghost_bleat_max_per_s:
		return
	hist.append(now)
	_bleat_log[g.idx] = hist
	var row := _row(int(g.idx))
	row["bleats"] = int(row.get("bleats", 0)) + 1
	var w = WORD_SCENE.instantiate()
	_ui.add_child(w)
	w.present(g, runner._camera, g.color, Tuning.ghost_word_alpha, living_screen_rects)
	# WK-53a: AudioManager listens and plays the ghost-variant bleat sample (assets/sfx/bleat_ghost_<hero>.ogg).
	EventBus.bleated.emit(int(g.idx), true)

## WK-37c: living goats' rects in canvas (1080p logical) px, for the "BAAA!" bubble to steer clear of (it draws on a
## CanvasLayer above every goat, so it must never sit on a living one).
func living_screen_rects() -> Array:
	var out: Array = []
	var cam = runner._camera if runner != null else null
	if cam == null or not is_instance_valid(cam):
		return out
	var z: float = maxf(cam.zoom.x, 0.01)
	var vp: Vector2 = get_viewport_rect().size
	var cc: Vector2 = cam.get_screen_center_position()
	for p in living_players():
		var sp: Vector2 = ((p.global_position as Vector2) - cc) * z + vp * 0.5
		var rad: Variant = p.get("_radius")
		var h: float = (float(rad) if rad != null else 44.0) * z * 1.35 + 10.0   # body + horns/flame, + a little air
		out.append(Rect2(sp - Vector2(h, h), Vector2(h, h) * 2.0))
	return out

# ------------------------------------------------------------------ HUD + legend

func _update_hud() -> void:
	var hud = runner._hud
	if hud == null or not hud.has_method("set_ghost_ring"):
		return
	for i in ghosts.keys():
		var g = ghost_for(int(i))
		if g == null:
			continue
		hud.set_ghost_ring(int(i), puff_progress(g), _hushed, g.puffs_used >= Tuning.ghost_puff_max_per_stage)

func _show_legend(i: int) -> void:
	var hud = runner._hud
	if hud == null or not hud.has_method("card_rect"):
		return
	var lg = LEGEND_SCENE.instantiate()
	_ui.add_child(lg)
	var key: String = ""
	var keys = runner.get("human_device_keys")
	if keys != null and i < (keys as PackedStringArray).size():
		key = str((keys as PackedStringArray)[i])
	lg.present(runner.player_color(i), key == "kb", puffs_enabled(), hud.card_rect(i), Tuning.ghost_legend_time)

# ------------------------------------------------------------------ QA samplers

func _stuck_check(g, before: Vector2, delta: float) -> void:
	if g.human:
		return
	var b = g.provider
	var at_spot: bool = b != null and b.has_method("at_hover") and b.at_hover()
	if before.distance_to(g.global_position) < 0.05 and not at_spot:
		g.stats["still_t"] = float(g.stats.get("still_t", 0.0)) + delta
		if float(g.stats["still_t"]) >= Tuning.ghost_stuck_secs and not bool(g.stats.get("stuck_flag", false)):
			g.stats["stuck_flag"] = true
			g.stats["stuck_episodes"] = int(g.stats.get("stuck_episodes", 0)) + 1
	else:
		g.stats["still_t"] = 0.0
		g.stats["stuck_flag"] = false

func _sample_pairs() -> void:
	var gs: Array = []
	for g in ghosts.values():
		if is_instance_valid(g) and not g.frozen:
			gs.append(g)
	if gs.size() < 2:
		return
	for a in range(gs.size()):
		for b in range(a + 1, gs.size()):
			_pairs_frames += 1
			if (gs[a].global_position as Vector2).distance_to(gs[b].global_position) >= Tuning.bot_ghost_spacing:
				_pairs_ok += 1
