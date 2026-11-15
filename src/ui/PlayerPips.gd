extends Control
## Identity pips over every fighter (BACKLOG WK-10 · audit C-09 / R-05 / R-17 · COUCH_CONVENTIONS CC-8.3).
## Six goats share one silhouette, so across a room you lose yourself; Smash's answer is a persistent P#
## pointer. Rules:
##   - HUMANS: a "P#" pip (lobby label, PartyMatch.player_tag) in the goat's colour, ALWAYS on while alive.
##     Full alpha through the intro + Tuning.pip_intro_linger into COMBAT, then fades to Tuning.pip_idle_alpha
##     (~70 %, never gone). Any (re)spawn puts it back at full alpha for Tuning.pip_full_hold.
##   - BOTS: their NAME ("VEX") + a small "CPU" sub-tag (CC-8.5), during the stage intro only, faded out with
##     the old name-tag timing. Humans keep the one-token "P#" pip (persistent, so it stays minimal).
##   - Off-screen goats get no pip (the EdgeIndicators chevron is the cue); a goat near the top edge gets
##     its pip flipped below it so it never leaves the screen.
##
## Screen space under a CanvasLayer (constant ~30 px type at every camera zoom; immune to the body's
## tumble rotation / spawn-blink modulate). Pure presentation: polls the runner, never feeds back.

const PIP_SCENE := preload("res://scenes/ui/PlayerPip.tscn")
const SHOW_STATES := ["STAGE_INTRO", "COUNTDOWN", "COMBAT", "SUDDEN_DEATH", "STAGE_END", "MATCH_END"]
const TOP_MARGIN := 6.0         # flip below the goat when the pip would cross this many px from the top

var _match                      # PartyMatch (read-only)
var _owners: Array = []         # Player per pip (roster snapshot; rebuilt if the roster changes)
var _pips: Array = []
var _shown: Array = []          # was the pip's goat alive+visible last frame (edge -> pop + full hold)
var _hold: Array = []           # s of full-alpha hold left (+ the fade tail), humans only
var _ghost_mode: Array = []     # WK-37d: pip currently dressed as a ghost tag (scale / z / sub-font)
var _ghost_flip: Array = []     # WK-37d: ghost tag hangs below its ghost (hysteresis: kept while it stays clear)
var _ghost_tag_rects: Array = [] # WK-37e: ghost tags already placed THIS frame (later tags keep clear of them)

func setup(match_ref) -> void:
	_match = match_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## QA readout (gbplay eval): per-player {tag, visible, alpha, pos, font_px}.
func debug_state() -> Array:
	var out: Array = []
	for i in range(_pips.size()):
		var pip = _pips[i]
		out.append({"tag": pip.get_node("Tab/Box/Label").text, "sub": pip.get_node("Tab/Box/Sub").text,
			"visible": pip.visible, "alpha": snappedf(pip.modulate.a, 0.01), "pos": pip.position,
			"font_px": pip.get_node("Tab/Box/Label").get_theme_font_size("font_size")})
	return out

func _sync_roster() -> void:
	var players: Array = _match.players
	var same: bool = players.size() == _owners.size()
	if same:
		for i in range(players.size()):
			if players[i] != _owners[i]:
				same = false
				break
	if same:
		return
	for pip in _pips:
		if is_instance_valid(pip):
			pip.queue_free()
	_pips.clear()
	_shown.clear()
	_hold.clear()
	_ghost_mode.clear()
	_ghost_flip.clear()
	_owners = players.duplicate()
	for i in range(players.size()):
		var pip = PIP_SCENE.instantiate()
		add_child(pip)
		var cpu: bool = not _match.is_human_player(i)
		# WK-88 (CC-8.5): the NAME everywhere; only the CPU intro pip carries the sub-tag
		pip.setup(_match.player_name(i), _match.player_color(i), cpu, "CPU" if cpu else "")
		pip.visible = false
		_pips.append(pip)
		_shown.append(false)
		_hold.append(0.0)
		_ghost_mode.append(false)
		_ghost_flip.append(false)

func _process(delta: float) -> void:
	if _match == null or not is_instance_valid(_match):
		return
	_sync_roster()
	var rdelta: float = delta / maxf(Engine.time_scale, 0.05)   # hitstop must not stretch the hold
	var st: String = str(_match.state)
	var cam = _match._camera
	var active: bool = SHOW_STATES.has(st) and cam != null and is_instance_valid(cam)
	var vic = _match.get("_victory")
	if vic != null and is_instance_valid(vic) and vic.visible:
		active = false   # the VictoryScreen ceremony owns the screen (no pip ghosts through its scrim)
	var vp: Vector2 = get_viewport_rect().size
	# ONE cue at a time: the same frame EdgeIndicators uses. Goat centre inside it -> pip; outside -> chevron.
	var inset: float = PartyMatch.CAM_OFFSCREEN_INSET
	var frame := Rect2(Vector2(inset, inset), vp - Vector2(inset * 2.0, inset * 2.0))
	var cam_center: Vector2 = cam.get_screen_center_position() if active else Vector2.ZERO
	var z: float = cam.zoom.x if active else 1.0
	var since_go: float = float(Time.get_ticks_msec() - int(_match.combat_start_msec)) / 1000.0
	var intro: bool = st == "STAGE_INTRO" or st == "COUNTDOWN"
	var fight: bool = st == "COMBAT" or st == "SUDDEN_DEATH"
	# WK-35 / CD2-06: the STAGE_END banner ("P1 +1 · P2 +1 · P1 SURVIVED") owns its rect — a surviving goat's pip that
	# would sit on it is hidden (WK-41 one-overlay-at-a-time; the pip comes back once the banner pops out).
	var banner: Rect2 = _banner_rect() if active and st == "STAGE_END" else Rect2()
	_ghost_tag_rects.clear()
	for i in range(_pips.size()):
		var pip = _pips[i]
		var p = _owners[i]
		var alive: bool = active and is_instance_valid(p) and not p.is_dead() and p.is_visible_in_tree()
		if not alive:
			_shown[i] = false
			# WK-37 / WK-37d (R3 identity): EVERY ghost carries its tag — "P#" for a human, NAME + "CPU" for a bot (the
			# WK-88 naming / WK-10 pip style) — dressed smaller + fainter than a living pip and drawn behind them:
			# ghost_pip_full_alpha for ghost_pip_full_time after it appears and whenever it moves again after
			# ghost_pip_idle_after s idle, otherwise ghost_pip_dim_alpha; placed so it never sits on a living goat.
			var g = _ghost_of(i) if active and fight else null
			if g != null and not g.frozen:
				_set_ghost_mode(i, pip, true)
				_place_ghost_pip(i, pip, g, cam_center, z, vp, frame)
			else:
				pip.visible = false
			continue
		_set_ghost_mode(i, pip, false)
		var human: bool = _match.is_human_player(i)
		if not _shown[i]:
			_shown[i] = true
			_hold[i] = Tuning.pip_full_hold + Tuning.pip_fade
			pip.pop()
		_hold[i] = maxf(0.0, float(_hold[i]) - rdelta)
		var a: float = _alpha(human, intro, fight, since_go, float(_hold[i]))
		if a <= 0.01:
			pip.visible = false
			continue
		var centre: Vector2 = (p.global_position - cam_center) * z + vp * 0.5
		if not frame.has_point(centre):
			pip.visible = false   # off-screen: the edge chevron is the cue
			continue
		var edge_ind = _match.get("_edge_indicators")   # WK-36: bubbled goats (incl. its hysteresis band) get no pip
		if edge_ind != null and is_instance_valid(edge_ind) and edge_ind.has_method("is_bubbled") and edge_ind.is_bubbled(p):
			pip.visible = false
			continue
		var rv: Variant = p.get("_radius")
		var r: float = float(rv) if rv != null else 44.0
		var lift: float = r * Tuning.pip_head_clearance
		var sp: Vector2 = (p.global_position + Vector2(0.0, -lift) - cam_center) * z + vp * 0.5 \
			- Vector2(0.0, Tuning.pip_screen_gap)
		var flip: bool = sp.y - pip.pip_height() < TOP_MARGIN
		if flip:
			sp = (p.global_position + Vector2(0.0, lift) - cam_center) * z + vp * 0.5 \
				+ Vector2(0.0, Tuning.pip_screen_gap)
		pip.set_flipped(flip)
		var half_w: float = pip.tab_width() * 0.5 + 4.0
		sp.x = clampf(sp.x, half_w, vp.x - half_w)   # a goat hugging a side edge keeps its whole pip on screen
		if banner.has_area():
			var ph: float = pip.pip_height()
			if banner.intersects(Rect2(sp.x - half_w, sp.y - ph, half_w * 2.0, ph * 2.0)):
				pip.visible = false   # CD2-06: never draw an identity pip over the stage-end banner text
				continue
		pip.position = sp.round()
		pip.modulate.a = a
		pip.visible = true

## WK-35 / CD2-06: the HUD's live centre banner in screen space (every mode HUD has Root/CenterC/CenterBox), padded;
## an empty Rect2 when no banner is up.
func _banner_rect() -> Rect2:
	var hud = _match.get("_hud")
	if hud == null or not is_instance_valid(hud) or not (hud is Node):
		return Rect2()
	var box := (hud as Node).get_node_or_null("Root/CenterC/CenterBox") as Control
	if box == null or not box.is_visible_in_tree() or box.modulate.a < 0.05:
		return Rect2()
	return box.get_global_rect().grow(14.0)

## WK-37: the GhostDirector's ghost for player i (null when ghosts are OFF / none).
func _ghost_of(i: int):
	var gd = _match.get("_ghost_dir")
	if gd == null or not is_instance_valid(gd):
		return null
	return gd.ghost_for(i)

## WK-37d: dress / undress a pip as a ghost tag. Smaller = ghost_pip_scale (the 30 px label lands on the 28 px WK-18
## floor; the CPU sub-line is bumped 28 -> 30 first so it lands on 28 too); behind every living pip (z -1).
func _set_ghost_mode(i: int, pip, on: bool) -> void:
	if bool(_ghost_mode[i]) == on:
		if on:
			pip.scale = Vector2.ONE * Tuning.ghost_pip_scale
		return
	_ghost_mode[i] = on
	var sub := pip.get_node("Tab/Box/Sub") as Label
	var tw = pip.get("_pop_tw")
	if tw != null and (tw as Tween).is_valid():
		(tw as Tween).kill()
	# WK-37e (art grade 2026-11-15 FIX 1): a ghost tag is ALWAYS the human tag style — goat-colour fill, cream theme type +
	# outline, chocolate pointer, NAME only. The CPU dark plate + "CPU" line made a dead bot the most-labelled thing on
	# screen (and chocolate = alive/touchable, brief §0). Undress re-runs the normal setup, so the living CPU intro pip is
	# byte-for-byte unchanged. The CPU line is hidden on ghosts, so no sub-font bump is needed (label 30 x 0.9333 = 28 px).
	var cpu: bool = not _match.is_human_player(i)
	var label := pip.get_node("Tab/Box/Label") as Label
	(pip.get_node("Tab") as Control).remove_theme_stylebox_override("panel")
	label.remove_theme_color_override("font_color")
	sub.add_theme_font_size_override("font_size", 28)
	if on:
		pip.setup(_match.player_name(i), _match.player_color(i), false, "")
		pip.z_index = -1
		pip.scale = Vector2.ONE * Tuning.ghost_pip_scale
		pip.modulate.a = 0.0
		_ghost_flip[i] = false
	else:
		pip.setup(_match.player_name(i), _match.player_color(i), cpu, "CPU" if cpu else "")
		pip.z_index = 0
		pip.scale = Vector2.ONE
	pip.call_deferred("_layout")

## Living goats' keep-out rects in screen px: body (+ horns / flame) and the head zone where their own pip sits.
func _living_rects(cam_center: Vector2, z: float, vp: Vector2) -> Array:
	var out: Array = []
	for p in _match.players:
		if not is_instance_valid(p) or p.is_dead() or not p.is_visible_in_tree():
			continue
		var c: Vector2 = (p.global_position - cam_center) * z + vp * 0.5
		var rv: Variant = p.get("_radius")
		var h: float = (float(rv) if rv != null else 44.0) * z * 1.35 + 8.0
		out.append(Rect2(c.x - h, c.y - h - 56.0, h * 2.0, h * 2.0 + 56.0))
	return out

func _overlap_area(r: Rect2, rects: Array) -> float:
	var a := 0.0
	for o in rects:
		a += r.intersection(o as Rect2).get_area()
	return a

func _place_ghost_pip(i: int, pip, g, cam_center: Vector2, z: float, vp: Vector2, frame: Rect2) -> void:
	var centre: Vector2 = (g.global_position - cam_center) * z + vp * 0.5
	if not frame.has_point(centre):
		pip.visible = false
		return
	var full: bool = g.age < Tuning.ghost_pip_full_time or g.moved_after_idle > 0.0
	var a: float = Tuning.ghost_pip_full_alpha if full else Tuning.ghost_pip_dim_alpha
	var lift: float = 44.0 * Tuning.ghost_scale * Tuning.pip_head_clearance
	var k: float = Tuning.ghost_pip_scale
	var w: float = pip.tab_width() * k
	var h: float = pip.pip_height() * k
	var above: Vector2 = (g.global_position + Vector2(0.0, -lift) - cam_center) * z + vp * 0.5 - Vector2(0.0, Tuning.pip_screen_gap)
	var below: Vector2 = (g.global_position + Vector2(0.0, lift) - cam_center) * z + vp * 0.5 + Vector2(0.0, Tuning.pip_screen_gap)
	above.x = clampf(above.x, w * 0.5 + 4.0, vp.x - w * 0.5 - 4.0)
	below.x = above.x
	var r_up := Rect2(above.x - w * 0.5, above.y - h, w, h)
	var r_dn := Rect2(below.x - w * 0.5, below.y, w, h)
	var rects: Array = _living_rects(cam_center, z, vp) + _ghost_tag_rects   # WK-37e FIX 3: tags never stack
	var o_up: float = _overlap_area(r_up, rects) if above.y - h >= TOP_MARGIN else INF
	var o_dn: float = _overlap_area(r_dn, rects) if below.y + h <= vp.y - TOP_MARGIN else INF
	# hysteresis: keep the current side while it is clear; otherwise take the clear side; otherwise the lesser overlap,
	# faded to ghost_pip_near_alpha (it never covers a living goat at a readable alpha)
	var flip: bool = bool(_ghost_flip[i])
	var o_cur: float = o_dn if flip else o_up
	var o_alt: float = o_up if flip else o_dn
	if o_cur > 0.0 and o_alt < o_cur:
		flip = not flip
	var o_pick: float = o_dn if flip else o_up
	if o_pick > 0.0:
		a = minf(a, Tuning.ghost_pip_near_alpha)
	_ghost_flip[i] = flip
	# WK-37d + CD2-06: the HUD centre banner ("TWO LEFT!", "FIRST BLOOD", the stage-end line) owns its rect in ANY
	# state — a ghost tag (lower priority than a living pip) under it is hidden, not drawn through the banner text.
	var bn: Rect2 = _banner_rect()
	if bn.has_area() and bn.intersects(r_dn if flip else r_up):
		pip.visible = false
		return
	# WK-37e FIX 2: while this ghost's own "BAAA!" word is up, its tag fades out (the owner-tinted burst carries identity
	# for its 0.7 s) and fades back with the same step when the word ends — no double text through the bubble.
	var gd = _match.get("_ghost_dir")
	if gd != null and is_instance_valid(gd) and gd.has_method("word_active") and gd.word_active(i):
		a = 0.0
	if a > 0.0:
		_ghost_tag_rects.append(r_dn if flip else r_up)   # FIX 3: later tags keep clear (a faded tag claims no room)
	pip.set_flipped(flip)
	pip.position = (below if flip else above).round()
	pip.modulate.a = move_toward(pip.modulate.a if pip.visible else 0.0, a, 0.08)
	pip.visible = true

## Alpha for one pip this frame. Humans never drop below pip_idle_alpha; bots fade to 0 after the intro.
func _alpha(human: bool, intro: bool, fight: bool, since_go: float, hold: float) -> float:
	var settled: float = Tuning.pip_idle_alpha if human else 0.0
	var base: float = settled
	if intro:
		base = 1.0
	elif fight:
		var k: float = clampf((since_go - Tuning.pip_intro_linger) / maxf(Tuning.pip_fade, 0.01), 0.0, 1.0)
		base = lerpf(1.0, settled, k)
	if not human:
		return base
	var h: float = clampf(hold / maxf(Tuning.pip_fade, 0.01), 0.0, 1.0)
	return maxf(base, lerpf(Tuning.pip_idle_alpha, 1.0, h))
