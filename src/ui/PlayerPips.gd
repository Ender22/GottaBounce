extends Control
## Identity pips over every fighter (BACKLOG WK-10 · audit C-09 / R-05 / R-17 · COUCH_CONVENTIONS CC-8.3).
## Six goats share one silhouette, so across a room you lose yourself; Smash's answer is a persistent P#
## pointer. Rules:
##   - HUMANS: a "P#" pip (lobby label, PartyMatch.player_tag) in the goat's colour, ALWAYS on while alive.
##     Full alpha through the intro + Tuning.pip_intro_linger into COMBAT, then fades to Tuning.pip_idle_alpha
##     (~70 %, never gone). Any (re)spawn puts it back at full alpha for Tuning.pip_full_hold.
##   - BOTS: a "CPU" tag during the stage intro only, faded out with the old name-tag timing.
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

func setup(match_ref) -> void:
	_match = match_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## QA readout (gbplay eval): per-player {tag, visible, alpha, pos, font_px}.
func debug_state() -> Array:
	var out: Array = []
	for i in range(_pips.size()):
		var pip = _pips[i]
		out.append({"tag": pip.get_node("Tab/Label").text, "visible": pip.visible,
			"alpha": snappedf(pip.modulate.a, 0.01), "pos": pip.position,
			"font_px": pip.get_node("Tab/Label").get_theme_font_size("font_size")})
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
	_owners = players.duplicate()
	for i in range(players.size()):
		var pip = PIP_SCENE.instantiate()
		add_child(pip)
		pip.setup(_match.player_tag(i), _match.player_color(i), not _match.is_human_player(i))
		pip.visible = false
		_pips.append(pip)
		_shown.append(false)
		_hold.append(0.0)

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
	for i in range(_pips.size()):
		var pip = _pips[i]
		var p = _owners[i]
		var alive: bool = active and is_instance_valid(p) and not p.is_dead() and p.is_visible_in_tree()
		if not alive:
			pip.visible = false
			_shown[i] = false
			continue
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
		pip.position = sp.round()
		pip.modulate.a = a
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
