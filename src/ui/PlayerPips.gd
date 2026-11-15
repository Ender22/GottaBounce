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
##   - WK-119 (UX4-09) SPORTS: every tag wears its TEAM (PlayerPip.set_team: team-colour rim + a cap on the team's
##     home side, colour-blind-safe), and a bot's "ZIGGY CPU" tag stays the whole match (settles to
##     Tuning.sports_cpu_pip_alpha like a human's pip) instead of fading after the intro. Brawl / Trials unchanged.
##   - WK-146 (UX4-23): no tag (living or ghost) is drawn over a HUD corner card: it flips to the clear side of its
##     goat, else it is clamped out of the card rect (the edge-clamp rule, with the card as the edge).
##   - WK-147 (UX4-24): a living pip that would sit under an off-screen bubble flips below its goat (else hides).
##   - WK-150: living tags avoid each other (bunched sports goats): a tag overlapping one placed earlier this frame takes
##     the other side of its goat when that side is legal + clear, else dims behind; side changes are held (hysteresis).
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
var _teams: Array = []          # WK-119: team per pip (-1 = no team dress: Brawl / Trials)
var _avoid_flip: Array = []     # WK-146/147: pip flipped below its goat to clear a card / bubble (hysteresis)
var _cards_now: Array = []      # WK-146: this frame's HUD card keep-out rects (screen px)
var _bubbles_now: Array = []    # WK-147: this frame's off-screen bubbles [{c, r}] (screen px)
var _living_tag_rects: Array = [] # WK-150: living tags already placed THIS frame (later living tags keep clear of them)
var _tag_avoid: Array = []      # WK-150: tag moved to the other side of its goat to clear an earlier tag (hysteresis)
var _tag_hold: Array = []       # WK-150: s left before this tag may change side again
var _tag_dim: Array = []        # WK-150: 0..1 dim (could not clear an earlier tag on either side)

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
			"font_px": pip.get_node("Tab/Box/Label").get_theme_font_size("font_size"),
			"team": pip.team(), "tag_avoid": bool(_tag_avoid[i]) if i < _tag_avoid.size() else false,
			"tag_dim": snappedf(float(_tag_dim[i]), 0.01) if i < _tag_dim.size() else 0.0, "rect": Rect2(pip.position + pip.local_rect().position, pip.local_rect().size)})
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
	_teams.clear()
	_avoid_flip.clear()
	_tag_avoid.clear()
	_tag_hold.clear()
	_tag_dim.clear()
	_owners = players.duplicate()
	for i in range(players.size()):
		var pip = PIP_SCENE.instantiate()
		add_child(pip)
		var cpu: bool = not _match.is_human_player(i)
		var team: int = _team_of(i)
		if team >= 0:
			pip.set_team(team, SportsMode.TEAM_COLORS[team % SportsMode.TEAM_COLORS.size()])   # WK-119
		# WK-88 (CC-8.5): the NAME everywhere; only the CPU intro pip carries the sub-tag
		pip.setup(_match.player_name(i), _match.player_color(i), cpu, "CPU" if cpu else "")
		pip.visible = false
		_pips.append(pip)
		_shown.append(false)
		_hold.append(0.0)
		_ghost_mode.append(false)
		_ghost_flip.append(false)
		_teams.append(team)
		_avoid_flip.append(false)
		_tag_avoid.append(false)
		_tag_hold.append(0.0)
		_tag_dim.append(0.0)

## WK-119: player i's sports team (0 RED / 1 BLUE), or -1 outside sports / with the team dress switched off.
## SportsMode._teams is the spawn-order truth; the goat's team colourway (TEAM_SKINS) is the fallback.
func _team_of(i: int) -> int:
	if not Tuning.sports_pip_team_dress:
		return -1
	var cfg = _match.get("_config")
	if cfg == null or not SportsMode.is_sports_mode(cfg.mode_id):
		return -1
	var mode = _match.get("_mode")
	if mode != null:
		var ts: Variant = mode.get("_teams")
		if ts is Array and i < (ts as Array).size():
			return int((ts as Array)[i])
	var p = _match.players[i]
	return SportsMode.team_for_skin(str(p.skin)) if is_instance_valid(p) else -1

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
	_living_tag_rects.clear()   # WK-150
	_cards_now = _card_rects() if active else []       # WK-146
	_bubbles_now = _bubble_list() if active else []    # WK-147
	for i in range(_pips.size()):
		var pip = _pips[i]
		var p = _owners[i]
		var alive: bool = active and is_instance_valid(p) and not p.is_dead() and p.is_visible_in_tree()
		if not alive:
			_shown[i] = false
			_tag_avoid[i] = false   # WK-150: a respawned goat's tag starts on its preferred side
			_tag_dim[i] = 0.0
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
		# WK-119: a sports CPU's tag stays all match, held + settled like a human's pip
		var persist: bool = human or (int(_teams[i]) >= 0 and Tuning.sports_cpu_pip_persist)
		if not _shown[i]:
			_shown[i] = true
			_hold[i] = Tuning.pip_full_hold + Tuning.pip_fade
			pip.pop()
		_hold[i] = maxf(0.0, float(_hold[i]) - rdelta)
		var a: float = _alpha(persist, intro, fight, since_go, float(_hold[i]),
			Tuning.pip_idle_alpha if human else Tuning.sports_cpu_pip_alpha)
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
		var dn: Vector2 = (p.global_position + Vector2(0.0, lift) - cam_center) * z + vp * 0.5 \
			+ Vector2(0.0, Tuning.pip_screen_gap)
		var half_w: float = pip.tab_width() * 0.5 + 4.0
		sp.x = clampf(sp.x, half_w, vp.x - half_w)   # a goat hugging a side edge keeps its whole pip on screen
		dn.x = sp.x
		var ph0: float = pip.pip_height()
		var flip: bool = sp.y - ph0 < TOP_MARGIN
		# WK-146 / WK-147: above the head under a HUD card or an off-screen bubble -> hang below the goat when that side
		# is clear (kept while the top side stays blocked, so it never flickers on the boundary)
		if not flip and dn.y + ph0 <= vp.y - TOP_MARGIN:
			var up_r := Rect2(Vector2(sp.x, sp.y) + _tag_rel(pip, false, 1.0).position, _tag_rel(pip, false, 1.0).size)
			var dn_r := Rect2(Vector2(dn.x, dn.y) + _tag_rel(pip, true, 1.0).position, _tag_rel(pip, true, 1.0).size)
			var grow: float = Tuning.pip_avoid_hysteresis_px if bool(_avoid_flip[i]) else 0.0
			flip = _blocked(up_r.grow(grow)) and not _blocked(dn_r)
			_avoid_flip[i] = flip
		else:
			_avoid_flip[i] = false
		# WK-150: living tags keep clear of the living tags placed EARLIER this frame (lower roster index places first and
		# keeps its spot, so humans win over CPUs). The preferred side (above, or the side the edge / card / bubble rules
		# picked) overlapping one -> the other side of the goat, if that side is allowed by those same rules and is clear;
		# neither -> stay and dim behind. Hysteresis: a switched tag keeps its side for pip_tag_hold s and only returns
		# once the preferred side clears by pip_tag_hysteresis_px.
		var pos_b: Vector2 = _carded(pip, dn if flip else sp, flip, vp)
		var avoiding := false
		var overlap := 0.0
		_tag_hold[i] = maxf(0.0, float(_tag_hold[i]) - rdelta)
		if Tuning.pip_tag_avoid:
			var pos_a: Vector2 = _carded(pip, sp if flip else dn, not flip, vp)
			var rel_b: Rect2 = _tag_rel(pip, flip, 1.0)
			var rel_a: Rect2 = _tag_rel(pip, not flip, 1.0)
			var r_b := Rect2(pos_b + rel_b.position, rel_b.size)
			var r_a := Rect2(pos_a + rel_a.position, rel_a.size)
			var alt_fits: bool = (sp.y - ph0 >= TOP_MARGIN) if flip else (dn.y + ph0 <= vp.y - TOP_MARGIN)
			var raw_a: Vector2 = sp if flip else dn
			var alt_ok: bool = alt_fits and not _blocked(Rect2(raw_a + rel_a.position, rel_a.size)) and not _blocked(r_a)
			var g: float = Tuning.pip_tag_gap
			var o_b: float = _overlap_area(r_b.grow(g), _living_tag_rects)
			var o_a: float = _overlap_area(r_a.grow(g), _living_tag_rects) if alt_ok else INF
			var was: bool = bool(_tag_avoid[i])
			avoiding = was and alt_ok   # the other side became illegal (edge / card / bubble) -> back now
			var hy: float = g + Tuning.pip_tag_hysteresis_px
			if float(_tag_hold[i]) <= 0.0:
				if avoiding:
					if _overlap_area(r_b.grow(hy), _living_tag_rects) <= 0.0 or o_a > o_b:
						avoiding = false
				elif o_b > 0.0 and o_a <= 0.0:
					avoiding = true
			elif _overlap_area(r_a if avoiding else r_b, _living_tag_rects) > 0.0:
				# inside the hold the tag only moves to escape a REAL overlap (goats crossed vertically), and only to a side
				# that clears by the full hysteresis margin, so the escape can't bounce straight back
				if avoiding and _overlap_area(r_b.grow(hy), _living_tag_rects) <= 0.0:
					avoiding = false
				elif not avoiding and alt_ok and _overlap_area(r_a.grow(hy), _living_tag_rects) <= 0.0:
					avoiding = true
			if avoiding != was:
				_tag_hold[i] = Tuning.pip_tag_hold
			_tag_avoid[i] = avoiding
			overlap = _overlap_area(r_a if avoiding else r_b, _living_tag_rects)
			if avoiding:
				pos_b = pos_a
		var side: bool = flip != avoiding
		sp = pos_b
		pip.set_flipped(side)
		var rel: Rect2 = _tag_rel(pip, side, 1.0)
		if not _bubbles_now.is_empty() and _hits_bubble(Rect2(sp + rel.position, rel.size)):
			pip.visible = false   # WK-147: neither side clears the bubble (one cue at a time)
			continue
		if banner.has_area():
			var ph: float = pip.pip_height()
			if banner.intersects(Rect2(sp.x - half_w, sp.y - ph, half_w * 2.0, ph * 2.0)):
				pip.visible = false   # CD2-06: never draw an identity pip over the stage-end banner text
				continue
		# WK-150: a tag that could not clear an earlier one fades to pip_tag_overlap_alpha and draws behind the living tags
		_tag_dim[i] = move_toward(float(_tag_dim[i]), 1.0 if overlap > 0.0 else 0.0, rdelta / maxf(Tuning.pip_tag_dim_fade, 0.01))
		a = lerpf(a, minf(a, Tuning.pip_tag_overlap_alpha), float(_tag_dim[i]))
		pip.z_index = -1 if float(_tag_dim[i]) > 0.5 else 0
		if a >= Tuning.pip_tag_claim_alpha:
			_living_tag_rects.append(Rect2(sp + rel.position, rel.size))   # later living tags keep clear of this one
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
	var rects: Array = _living_rects(cam_center, z, vp) + _ghost_tag_rects + _cards_now   # WK-37e FIX 3 + WK-146 cards
	var o_up: float = _overlap_area(r_up, rects) if above.y - h >= TOP_MARGIN else INF
	var o_dn: float = _overlap_area(r_dn, rects) if below.y + h <= vp.y - TOP_MARGIN else INF
	# hysteresis: keep the current side while it is clear; otherwise take the clear side; otherwise the lesser overlap,
	# faded to ghost_pip_near_alpha (it never covers a living goat at a readable alpha)
	var flip: bool = bool(_ghost_flip[i])
	var o_cur: float = o_dn if flip else o_up
	var o_alt: float = o_up if flip else o_dn
	if o_cur > 0.0 and o_alt < o_cur:
		flip = not flip
	_ghost_flip[i] = flip
	var pos: Vector2 = below if flip else above
	var rel: Rect2 = _tag_rel(pip, flip, k)
	if not _cards_now.is_empty():
		pos = _clamp_out_of_cards(pos, rel, vp)   # WK-146: an edge-clamped ghost tag never sits on a HUD card
	var r_fin := Rect2(pos + rel.position, rel.size)
	# the near-fade is judged on the FINAL (card-clamped) rect against living goats + earlier tags only: a card is
	# handled by the clamp, so a tag that cleared it stays at its readable alpha (WK-146)
	if _overlap_area(r_fin, _living_rects(cam_center, z, vp) + _ghost_tag_rects) > 0.0:
		a = minf(a, Tuning.ghost_pip_near_alpha)
	# WK-37d + CD2-06: the HUD centre banner ("TWO LEFT!", "FIRST BLOOD", the stage-end line) owns its rect in ANY
	# state — a ghost tag (lower priority than a living pip) under it is hidden, not drawn through the banner text.
	var bn: Rect2 = _banner_rect()
	if bn.has_area() and bn.intersects(r_fin):
		pip.visible = false
		return
	# WK-37e FIX 2: while this ghost's own "BAAA!" word is up, its tag fades out (the owner-tinted burst carries identity
	# for its 0.7 s) and fades back with the same step when the word ends — no double text through the bubble.
	var gd = _match.get("_ghost_dir")
	if gd != null and is_instance_valid(gd) and gd.has_method("word_active") and gd.word_active(i):
		a = 0.0
	if a > 0.0:
		_ghost_tag_rects.append(r_fin)   # FIX 3: later tags keep clear (a faded tag claims no room)
	pip.set_flipped(flip)
	pip.position = pos.round()
	pip.modulate.a = move_toward(pip.modulate.a if pip.visible else 0.0, a, 0.08)
	pip.visible = true

## Alpha for one pip this frame. Persistent pips (humans; WK-119 sports CPUs) never drop below `idle`; other bots
## fade to 0 after the intro.
func _alpha(persist: bool, intro: bool, fight: bool, since_go: float, hold: float, idle: float) -> float:
	var settled: float = idle if persist else 0.0
	var base: float = settled
	if intro:
		base = 1.0
	elif fight:
		var k: float = clampf((since_go - Tuning.pip_intro_linger) / maxf(Tuning.pip_fade, 0.01), 0.0, 1.0)
		base = lerpf(1.0, settled, k)
	if not persist:
		return base
	var h: float = clampf(hold / maxf(Tuning.pip_fade, 0.01), 0.0, 1.0)
	return maxf(base, lerpf(idle, 1.0, h))

# ------------------------------------------------------------------ WK-146 / WK-147 keep-outs

## A tag's rect relative to its origin (the pointer tip) for a side, at scale k: above = hangs up, flipped = hangs down.
func _tag_rel(pip, flipped: bool, k: float) -> Rect2:
	var w: float = pip.tab_width() * k
	var h: float = pip.pip_height() * k
	return Rect2(-w * 0.5, 0.0 if flipped else -h, w, h)

## WK-146: the HUD's visible corner cards (MatchHUD / TrialsHUD `_cards`), grown by pip_card_gap. Sports has none.
func _card_rects() -> Array:
	var out: Array = []
	var hud = _match.get("_hud")
	if hud == null or not is_instance_valid(hud):
		return out
	var cards: Variant = hud.get("_cards")
	if not (cards is Array):
		return out
	for c in (cards as Array):
		if c is Control and is_instance_valid(c) and (c as Control).is_visible_in_tree():
			out.append((c as Control).get_global_rect().grow(Tuning.pip_card_gap))
	return out

## WK-147: this frame's off-screen bubbles (EdgeIndicators) as screen circles, grown by pip_bubble_gap.
func _bubble_list() -> Array:
	var out: Array = []
	var ei = _match.get("_edge_indicators")
	if ei == null or not is_instance_valid(ei):
		return out
	var list: Variant = ei.get("bubbles")
	if not (list is Array):
		return out
	for b in (list as Array):
		if b is Dictionary:
			var bd: Dictionary = b
			out.append({"c": bd["c"], "r": float(bd["r"]) * float(bd.get("pop", 1.0)) + Tuning.pip_bubble_gap})
	return out

func _hits_bubble(r: Rect2) -> bool:
	for b in _bubbles_now:
		var c: Vector2 = b["c"]
		var q := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
		if q.distance_to(c) < float(b["r"]):
			return true
	return false

## WK-150: a living tag's origin for one side after the WK-146 card clamp (the card is one more screen edge).
func _carded(pip, origin: Vector2, flipped: bool, vp: Vector2) -> Vector2:
	if _cards_now.is_empty():
		return origin
	return _clamp_out_of_cards(origin, _tag_rel(pip, flipped, 1.0), vp)

func _blocked(r: Rect2) -> bool:
	for c in _cards_now:
		if r.intersects(c as Rect2):
			return true
	return _hits_bubble(r)

## WK-146: move a tag (origin `pos`, relative rect `rel`) out of every card it overlaps, by the shorter inward push
## (toward the screen centre, horizontal or vertical): the HUD card acts as one more screen edge.
func _clamp_out_of_cards(pos: Vector2, rel: Rect2, vp: Vector2) -> Vector2:
	for c in _cards_now:
		var cr: Rect2 = c
		var r := Rect2(pos + rel.position, rel.size)
		if not r.intersects(cr):
			continue
		var dx: float = (cr.end.x - r.position.x) if cr.get_center().x < vp.x * 0.5 else -(r.end.x - cr.position.x)
		var dy: float = (cr.end.y - r.position.y) if cr.get_center().y < vp.y * 0.5 else -(r.end.y - cr.position.y)
		if absf(dx) < absf(dy):
			pos.x += dx
		else:
			pos.y += dy
	return pos
