extends CanvasLayer
## WK-53b + WK-26 living-goat cues. Presentation only (INV-12): subscribes to EventBus / polls the runner read-only,
## never feeds back into the sim. PartyMatch adds one per match on CanvasLayer 2 (with the ghost words: above the pips
## (1) / chevrons (0), below the KO blast (5) and the HUD (10)).
##
##  * WK-53b TAUNT. EventBus.living_taunt(player) (Player: intent.taunt edge, pad Y / keyboard J) -> the per-player rate
##    limit the ghosts use (Tuning.ghost_bleat_min_interval, <= ghost_bleat_max_per_s in any second) -> a "BAAA!"
##    WordBurst in the goat's colour at Tuning.living_word_alpha (it keeps clear of the other living goats and every
##    identity pip, and never prints on the HUD centre banner) -> EventBus.bleated(idx, false), which AudioManager
##    turns into the hero's bleat. This node is the living-bleat EMITTER (the EventBus.bleated contract: the emitter
##    draws the word). Bots never set intent.taunt, so they stay silent.
##  * WK-26 TARGET "!". While a goat holds super AIM (live combat only), the FIRST opponent along its aim ray, within
##    Tuning.super_aim_target_corridor px of the ray and <= Tuning.super_aim_target_range px ahead, gets a "!" bubble in
##    the AIMER's colour beside its head (on the side facing the aimer). Re-evaluated every rendered frame from
##    get_super_aim_dir(), so it follows the aim the moment the ray crosses a goat. Teammates (sports) never get one.
##    Off-screen targets get none (the edge chevron is the cue); a bubble that would touch the centre banner hides.
##  * WK-20e TRUCE PADLOCK. EventBus.super_lock_pressed(player) (Player: a fresh super press dropped by the Brawl spawn truce /
##    R4 re-arm gate) -> a SuperLockBadge (gate padlock) beside that goat's head, re-popped on every dropped press. It stays
##    while the button is held (+ Tuning.super_lock_badge_hold after a tap) and disappears the frame the lock ends.

const WORD_SCENE := preload("res://scenes/ui/WordBurst.tscn")
const BANG_SCENE := preload("res://scenes/ui/TargetBang.tscn")
const LOCK_SCENE := preload("res://scenes/ui/SuperLockBadge.tscn")   # WK-20e
const LIVE_STATES := ["COMBAT", "SUDDEN_DEATH"]

var _match                    # PartyMatch (read-only)
var _taunt_hist := {}         # player idx -> [ms of recent SHOWN taunts]
var _bangs := {}              # aimer player idx -> TargetBang node
var _locks := {}              # WK-20e: player idx -> SuperLockBadge node
var _lock_hold := {}          # WK-20e: player idx -> s the badge may still stay after its last dropped press (tap hold; real-delta clock)

# QA (gbplay eval)
var taunts_seen := 0          # every living_taunt received
var taunts_shown := 0         # taunts that passed the rate limit (word drawn + bleated emitted)
var target_log: Array = []    # last 64 target changes: {ms, frame, aimer, target} (target -1 = cleared)
var lock_presses_seen := 0    # WK-20e: every super_lock_pressed received
var lock_log: Array = []      # WK-20e: last 32 badge events {ms, frame, idx, ev: "pop" / "hide"}

func setup(match_ref) -> void:
	_match = match_ref
	EventBus.living_taunt.connect(_on_living_taunt)
	EventBus.super_lock_pressed.connect(_on_super_lock_pressed)   # WK-20e

func _exit_tree() -> void:
	if EventBus.living_taunt.is_connected(_on_living_taunt):
		EventBus.living_taunt.disconnect(_on_living_taunt)
	if EventBus.super_lock_pressed.is_connected(_on_super_lock_pressed):   # WK-20e
		EventBus.super_lock_pressed.disconnect(_on_super_lock_pressed)

# ------------------------------------------------------------------ WK-53b taunt

func _on_living_taunt(player) -> void:
	taunts_seen += 1
	if _match == null or not is_instance_valid(player) or player.is_dead():
		return
	var idx: int = (_match.players as Array).find(player)
	if idx < 0:
		return
	var now: int = Time.get_ticks_msec()
	var hist: Array = (_taunt_hist.get(idx, []) as Array).filter(func(t) -> bool: return now - int(t) < 1000)
	if not hist.is_empty() and float(now - int(hist.back())) / 1000.0 < Tuning.ghost_bleat_min_interval:
		_taunt_hist[idx] = hist
		return
	if hist.size() >= Tuning.ghost_bleat_max_per_s:
		_taunt_hist[idx] = hist
		return
	hist.append(now)
	_taunt_hist[idx] = hist
	taunts_shown += 1
	var cam = _match.get("_camera")
	if cam != null and is_instance_valid(cam):
		var w = WORD_SCENE.instantiate()
		add_child(w)
		w.present(player, cam, _match.player_color(idx), Tuning.living_word_alpha, _word_avoid_rects.bind(player),
			_banner_rects)
		w.source_idx = idx
	EventBus.bleated.emit(idx, false)   # AudioManager: bleat_<hero> (its own rate limit is the same numbers)

## Keep-clear rects (canvas px) for a living "BAAA!": every OTHER living goat's body + every visible identity pip.
func _word_avoid_rects(bleater) -> Array:
	var out: Array = []
	var cam = _match.get("_camera") if _match != null else null
	if cam == null or not is_instance_valid(cam):
		return out
	for p in _match.players:
		if p == bleater or not is_instance_valid(p) or p.is_dead() or not p.is_visible_in_tree():
			continue
		var sp: Vector2 = _to_screen(p.global_position, cam)
		var h: float = _radius_of(p) * maxf(cam.zoom.x, 0.01) * 1.35 + 10.0
		out.append(Rect2(sp - Vector2(h, h), Vector2(h, h) * 2.0))
	var pips = _match.get("_pips")
	if pips != null and is_instance_valid(pips) and "_pips" in pips:
		for pip in pips._pips:
			if is_instance_valid(pip) and pip.visible and pip.has_method("tab_width") and pip.has_method("pip_height"):
				var hw: float = float(pip.tab_width()) * 0.5 + 4.0
				var ph: float = float(pip.pip_height())
				out.append(Rect2(pip.position.x - hw, pip.position.y - ph, hw * 2.0, ph * 2.0))
	return out

## The HUD centre banner as a HARD keep-out (the CD2-06 / WK-41 one-overlay rule ghost words follow).
func _banner_rects() -> Array:
	var pips = _match.get("_pips") if _match != null else null
	if pips == null or not is_instance_valid(pips) or not pips.has_method("_banner_rect"):
		return []
	var r: Rect2 = pips._banner_rect()
	return [r] if r.has_area() else []

# ------------------------------------------------------------------ WK-20e truce padlock

func _on_super_lock_pressed(player) -> void:
	lock_presses_seen += 1
	if _match == null or not is_instance_valid(player) or player.is_dead():
		return
	var idx: int = (_match.players as Array).find(player)
	if idx < 0:
		return
	_lock_hold[idx] = Tuning.super_lock_badge_hold
	var b = _locks.get(idx)
	if b == null or not is_instance_valid(b):
		b = LOCK_SCENE.instantiate()
		b.visible = false
		add_child(b)
		b.setup(idx)
		_locks[idx] = b
	b.pop()
	_log_lock(idx, "pop")

## QA: player idx -> true for every padlock on screen right now.
func lock_state() -> Dictionary:
	var out := {}
	for i in _locks:
		var b = _locks[i]
		if is_instance_valid(b) and b.visible:
			out[i] = true
	return out

## Per frame: a badge shows while its goat is still locked AND (the press is held OR the tap hold runs). Beside the head on
## the side AWAY from the aim (the greyed arrow points along the aim), flipped if it would leave the screen.
func _update_locks(live: bool, cam, players: Array, vp: Vector2, rdelta: float) -> void:
	for i in _locks.keys():
		var b = _locks[i]
		if b == null or not is_instance_valid(b):
			_locks.erase(i)
			continue
		var p = players[i] if int(i) < players.size() else null
		var hold: float = float(_lock_hold.get(i, 0.0))
		_lock_hold[i] = maxf(0.0, hold - rdelta)
		var on: bool = (live and p != null and is_instance_valid(p) and not p.is_dead() and p.is_visible_in_tree()
				and p.super_arm_locked() and (p.is_super_held() or hold > 0.0))
		if not on:
			if b.visible:
				b.visible = false
				_log_lock(int(i), "hide")
			continue
		var z: float = maxf(cam.zoom.x, 0.01)
		var centre: Vector2 = _to_screen(p.global_position, cam)
		var r: float = _radius_of(p) * z
		var half: Vector2 = b.half_size()
		var aim: Vector2 = p.get_aim() if p.has_method("get_aim") else Vector2.UP
		var side: float = -1.0 if aim.x > 0.2 else 1.0
		var pos: Vector2 = centre + Vector2(side * (r * 0.85 + half.x + 6.0), -(r * 0.85 + 2.0))
		if pos.x + half.x > vp.x - 8.0 or pos.x - half.x < 8.0:
			pos.x = centre.x - side * (r * 0.85 + half.x + 6.0)
		pos.y = maxf(pos.y, half.y + 8.0)
		b.place(pos, rdelta)
		b.visible = true

func _log_lock(idx: int, ev: String) -> void:
	lock_log.append({"ms": Time.get_ticks_msec(), "frame": Engine.get_process_frames(), "idx": idx, "ev": ev})
	if lock_log.size() > 32:
		lock_log.pop_front()

# ------------------------------------------------------------------ WK-26 target "!"

## The goat `aimer`'s super is aimed at right now (first opponent along the ray inside the corridor), or null.
## The goat already marked keeps its "!" out to Tuning.super_aim_target_keep x the corridor / range (hysteresis: a goat
## skimming the corridor edge must not strobe the bubble on and off).
func aim_target(aimer):
	if _match == null or not is_instance_valid(aimer) or aimer.is_dead() or not aimer.is_super_aiming():
		return null
	var d: Vector2 = aimer.get_super_aim_dir()
	if d.length() < 0.001:
		return null
	d = d.normalized()
	var players: Array = _match.players
	var ai: int = players.find(aimer)
	var o: Vector2 = aimer.global_position
	var cur_b = _bangs.get(ai)
	var cur: int = int(cur_b.target_idx) if cur_b != null and is_instance_valid(cur_b) and cur_b.visible else -1
	var best = null
	var best_t := INF
	for qi in range(players.size()):
		var q = players[qi]
		if q == aimer or not is_instance_valid(q) or q.is_dead() or not q.is_visible_in_tree():
			continue
		if _same_team(ai, qi):
			continue
		var rel: Vector2 = q.global_position - o
		var t: float = rel.dot(d)
		var keep: float = Tuning.super_aim_target_keep if qi == cur else 1.0
		if t <= 0.0 or t > Tuning.super_aim_target_range * keep:
			continue
		if absf(rel.cross(d)) > Tuning.super_aim_target_corridor * keep:
			continue
		if t < best_t:
			best_t = t
			best = q
	return best

func _same_team(a: int, b: int) -> bool:
	var mode = _match.get("_mode")
	if mode == null:
		return false
	var teams: Variant = mode.get("_teams")
	if not (teams is Array):
		return false
	var ta: Array = teams
	return a >= 0 and b >= 0 and a < ta.size() and b < ta.size() and int(ta[a]) == int(ta[b])

## QA: {aimer idx: target idx} for every "!" on screen right now.
func bang_state() -> Dictionary:
	var out := {}
	for ai in _bangs:
		var b = _bangs[ai]
		if is_instance_valid(b) and b.visible:
			out[ai] = b.target_idx
	return out

func _process(delta: float) -> void:
	if _match == null or not is_instance_valid(_match):
		return
	var rdelta: float = minf(delta / maxf(Engine.time_scale, 0.05), 0.05)   # hit-stop must not freeze the throb
	var cam = _match.get("_camera")
	var live: bool = LIVE_STATES.has(str(_match.state)) and cam != null and is_instance_valid(cam)
	var players: Array = _match.players
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var inset: float = PartyMatch.CAM_OFFSCREEN_INSET
	var frame := Rect2(Vector2(inset, inset), vp - Vector2(inset * 2.0, inset * 2.0))
	var banners: Array = _banner_rects() if live else []
	var placed: Array = []   # "!" rects already placed this frame (a later bubble keeps clear of them)
	var bodies := {}         # player idx -> screen rect of each living goat (the bubble keeps clear of goats)
	if live:
		var zz: float = maxf(cam.zoom.x, 0.01)
		for pi in range(players.size()):
			var pp = players[pi]
			if is_instance_valid(pp) and not pp.is_dead() and pp.is_visible_in_tree():
				var hh: float = _radius_of(pp) * zz * 1.1 + 6.0
				bodies[pi] = Rect2(_to_screen(pp.global_position, cam) - Vector2(hh, hh), Vector2(hh, hh) * 2.0)
	_update_locks(live, cam, players, vp, rdelta)   # WK-20e
	for ai in range(players.size()):
		var aimer = players[ai]
		var tgt = aim_target(aimer) if live else null
		var ti: int = players.find(tgt) if tgt != null else -1
		var b = _bangs.get(ai)
		if ti < 0:
			if b != null and is_instance_valid(b) and b.visible:
				b.visible = false
				_log_target(ai, -1)
			continue
		if b == null or not is_instance_valid(b):
			b = BANG_SCENE.instantiate()
			add_child(b)
			b.setup(_match.player_color(ai), ai)
			_bangs[ai] = b
		if not b.visible or b.target_idx != ti:
			_log_target(ai, ti)
		b.retarget(ti)
		var z: float = maxf(cam.zoom.x, 0.01)
		var centre: Vector2 = _to_screen(tgt.global_position, cam)
		if not frame.has_point(centre):
			b.visible = false   # off-screen: the edge chevron is the cue
			continue
		var r: float = _radius_of(tgt) * z
		var half: Vector2 = b.half_size()
		# Slots around the target's head, in preference order: the side facing the aimer, the other side, above the
		# identity pip. WK-26 rec fix: pick the first slot that touches no other goat (the AIMER above all — a "!" on
		# the aimer reads as the wrong goat) and no other "!" this frame; keep the current slot while it stays clear
		# (no side-hopping). A slot on the centre banner never wins; if every slot does, the "!" hides that frame.
		var face_left: bool = aimer.global_position.x < tgt.global_position.x
		var fs: float = -1.0 if face_left else 1.0
		var slots: Array = [
			centre + Vector2(fs * (r * 0.85 + 56.0), -(r * 0.85 + 30.0)),
			centre + Vector2(-fs * (r * 0.85 + 56.0), -(r * 0.85 + 30.0)),
			centre + Vector2(0.0, -(r * Tuning.pip_head_clearance + 70.0 + half.y)),
		]
		var lefts: Array = [face_left, not face_left, false]
		var scores: Array = []
		for k in range(slots.size()):
			var c: Vector2 = slots[k]
			var me := Rect2(c - half, half * 2.0)
			var sc := 0.0
			for pi in bodies:
				if int(pi) != ti:
					sc += me.intersection(bodies[pi] as Rect2).get_area()
			for pr in placed:
				sc += me.intersection(pr as Rect2).get_area()
			if c.x - half.x < 8.0 or c.x + half.x > vp.x - 8.0 or c.y - half.y < 8.0:
				sc += 1.0e5   # would leave the screen
			for br in banners:
				if me.intersects(br as Rect2):
					sc += 1.0e7   # never on the centre banner
			scores.append(sc)
		var slot: int = -1
		if b.target_idx == ti and b.slot >= 0 and b.slot < slots.size() and float(scores[b.slot]) <= 0.0:
			slot = b.slot
		else:
			var best_sc := INF
			for k in range(slots.size()):
				if float(scores[k]) < best_sc - 0.5:
					best_sc = float(scores[k])
					slot = k
		if float(scores[slot]) >= 1.0e7:
			b.visible = false   # one overlay at a time: every slot touches the centre banner
			continue
		b.slot = slot
		var pos: Vector2 = slots[slot]
		var left: bool = lefts[slot]
		pos.y = maxf(pos.y, half.y + 8.0)
		placed.append(Rect2(pos - half, half * 2.0))
		var at: Variant = aimer.get("_sb_aim_t")
		var fuse: float = clampf((float(at) if at != null else 0.0) / maxf(Tuning.super_aim_max, 0.01), 0.0, 1.0)
		b.place(pos, left, fuse, rdelta)
		b.visible = true
	# goats that left the roster
	for ai in _bangs.keys():
		if int(ai) >= players.size() and is_instance_valid(_bangs[ai]):
			_bangs[ai].visible = false

func _log_target(aimer: int, target: int) -> void:
	target_log.append({"ms": Time.get_ticks_msec(), "frame": Engine.get_process_frames(), "aimer": aimer,
		"target": target})
	if target_log.size() > 64:
		target_log.pop_front()

# ------------------------------------------------------------------ helpers

func _to_screen(world: Vector2, cam) -> Vector2:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return (world - cam.get_screen_center_position()) * cam.zoom.x + vp * 0.5

func _radius_of(p) -> float:
	var rv: Variant = p.get("_radius")
	return float(rv) if rv != null else 44.0
