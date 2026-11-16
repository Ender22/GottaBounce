extends Node2D
## WK-183 (WK-99 SP-14, the sports half): one goat's fuel arc in SPORTS (Rocketball / Dropshot). Sports has no corner
## PlayerCards, so without this nobody can see their tank ("walls refuel once" and the ball refuel are invisible).
##
## A team-coloured arc hugging the LOWER half of the goat (centred on 6 o'clock, Tuning.wk183_span_deg wide), filling
## left -> right with get_fuel_ratio():
##   - WK-99 super-ready notch at super_boost_min_fuel / fuel_max: LIT = cream tick poking past the track, UNLIT = short
##     muted tick inside it (size + luminance, never hue: the same read as the PlayerCard gauge and the WK-36 bubble ring),
##     with the WK-99 pop when the tank crosses UP through the line.
##   - LOW (< wk183_low_ratio, = the bubble ring's low line, 0 included): the outline band swings between
##     wk183_low_rim_floor and wk183_low_rim_flash toward cream (it never returns to chocolate, so the trough reads too)
##     and the fill brightens with it. Luminance only, so a RED-team gauge still reads "low" (a red low colour would vanish into the red team
##     fill), and the empty track never brightens (a bright track read as a FULL arc in the first rendered pass).
##   - REFUND TICK: when the tank gains >= wk183_tick_min in one frame (wall / floor / bumper / ball refund, re-light refund,
##     whiff reserve: drain never rises), the gained slice flashes white, the fill pops wider and the whole arc glints,
##     and EventBus.refuel_ticked fires (AudioManager's refuel ding).
##   - Round caps on the outline, track, fill and tick slice (the PlayerCard capsule language).
##   - FULL + STEADY: fades out after wk183_full_hold_s. At kickoff all four tanks are full, so four rings would be
##     pure clutter around the ball; the arc appears the moment fuel moves (boost drain or a refund) and is always up
##     whenever the tank is below full, which is the only time the number matters.
##   - Hidden while the goat is dead / respawning, outside live combat (intro, countdown, goal banner, end screen) and
##     while it super-aims (the fuse ring owns the space around the goat then).
##
## Built by SportsHUD.setup (sports only; brawl keeps its PlayerCards). All four arcs live in ONE shared world layer
## (SportsHUD's "WK183FuelArcs" Node2D) placed in the runner's tree AFTER the level container and BEFORE the goats, at the
## goats' z (Tuning.wk183_z = 0). Same z, earlier in the tree = drawn under every goat body (and its aim arrow / fuse /
## touch rings), over the floor and walls (z 0, inside the level). The ball (z 40), the goal front frames (42) and the name
## tags (CanvasLayer) draw over it. Re-grade item 1: an arc parented to its goat (top_level) crossed a stacked teammate's
## face; an absolute z -1 layer fixed that but sank a grounded goat's arc under the floor, so the layer is ordered by tree
## instead. Inside a stack the lower goat's arc is partly covered by the other body (accepted: bodies win). It never
## rotates with the tumbling body (it is not the goat's child) and frees itself when its goat is gone. Widths are SCREEN px divided by the camera zoom
## (the Player fuse / touch-ring rule), so it reads the same at every sports zoom. Pure presentation: it polls its own
## goat's fuel (there is no fuel signal: fuel drains continuously while boosting, so a per-frame read of one float is the
## honest source) and never feeds back.

const OUTLINE := Color(0.231373, 0.141176, 0.105882, 1.0)   # theme.tres chocolate (EdgeIndicators.OUTLINE)
const CREAM := Color(1.0, 0.968627, 0.921569, 1.0)          # theme cream (EdgeIndicators.CREAM)
const LIVE_STATES := ["COMBAT", "SUDDEN_DEATH"]
const SEG_PER_RAD := 14.0        # arc points per radian (150 deg -> ~37 points)

var player                       # Player (untyped: dynamic member reads)
var _runner                      # PartyMatch (read-only: state, _mode._teams)
var _idx := -1                   # player index in the runner
var _team := -1                  # 0 RED / 1 BLUE (resolved lazily from SportsMode._teams)
var _team_color := Color.WHITE

var _alpha := 0.0                # current shown alpha (0..1, before wk183_alpha / aim)
var _full_t := 0.0               # s the tank has been full and steady
var _prev_fuel := -1.0           # last frame's fuel (-1 = no baseline: first frame / dead / respawn)
var _tick_t := 0.0               # s left on the refund tick
var _tick_from := 0.0            # ratio the gained slice starts at
var _tick_to := 0.0              # ratio it ends at
var _ratio := 1.0
var _locked := false
var _notch_lit := -1             # -1 unknown (first frame never pops), 0 unlit, 1 lit
var _notch_pop := 0.0            # s left on the notch pop
var _aiming := false
var _inv_zoom := 1.0
var _clock := 0.0                # real-time clock for the low pulse
var ticks := 0                   # QA: refund ticks fired this match

func setup(p, runner, idx: int) -> void:
	player = p
	_runner = runner
	_idx = idx
	name = "WK183FuelArc_%d" % idx
	z_index = Tuning.wk183_z
	_resolve_team()

## Add me to the shared arc layer (SportsHUD builds it: a world Node2D placed AFTER the level and BEFORE the goats in the
## runner's tree) and register me on my goat (meta "wk183_arc": PlayerPips / QA find me there).
func attach(layer: Node) -> void:
	layer.add_child(self)
	player.set_meta("wk183_arc", self)

## The arc registered on goat p (null outside sports / with arcs off).
static func of(p) -> Node:
	if p == null or not is_instance_valid(p) or not (p as Object).has_meta("wk183_arc"):
		return null
	var a: Variant = (p as Object).get_meta("wk183_arc")
	return a as Node if a is Node and is_instance_valid(a) else null

func _resolve_team() -> void:
	if _team >= 0 or _runner == null or not is_instance_valid(_runner):
		return
	var mode = _runner.get("_mode")
	if mode != null:
		var ts: Variant = mode.get("_teams")
		if ts is Array and _idx >= 0 and _idx < (ts as Array).size():
			_team = int((ts as Array)[_idx])
	if _team < 0 and player != null and is_instance_valid(player):
		_team = SportsMode.team_for_skin(str(player.skin))
	if _team >= 0:
		_team_color = SportsMode.TEAM_COLORS[_team % SportsMode.TEAM_COLORS.size()]

## QA readout (gbplay eval): what this arc shows right now.
func debug_state() -> Dictionary:
	return {"idx": _idx, "team": _team, "alpha": snappedf(_shown_alpha(), 0.01), "ratio": snappedf(_ratio, 0.001),
		"lit": _notch_lit == 1, "low": _ratio < Tuning.wk183_low_ratio, "tick": snappedf(_tick_t, 0.01),
		"ticks": ticks, "full_t": snappedf(_full_t, 0.01), "aiming": _aiming, "pulse": snappedf(_pulse(), 0.01),
		"pos": global_position, "radius_screen": snappedf(_radius_world() / _inv_zoom, 0.1)}

## Low pulse 0..1 at the current clock (0 when not low): the rim sits at floor + (flash - floor) x this.
func _pulse() -> float:
	if _ratio >= Tuning.wk183_low_ratio or _locked:
		return 0.0
	return 0.5 + 0.5 * sin(_clock * TAU * Tuning.wk183_low_hz)

func _shown_alpha() -> float:
	return _alpha * Tuning.wk183_alpha * (Tuning.wk183_aim_alpha if _aiming else 1.0)

func _radius_world() -> float:
	var rv: Variant = player.get("_radius") if player != null and is_instance_valid(player) else null
	var r: float = float(rv) if rv != null else 44.0
	return r * Tuning.wk183_radius_mult + Tuning.wk183_gap_px * _inv_zoom

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()   # the goat is gone (match torn down): so is its arc
		return
	if _runner == null or not is_instance_valid(_runner):
		return
	var rdelta: float = delta / maxf(Engine.time_scale, 0.05)   # hitstop / slow-mo must not stretch the fades
	_clock += rdelta
	_resolve_team()
	global_position = player.global_position
	var cam := get_viewport().get_camera_2d()
	_inv_zoom = (1.0 / cam.zoom.x) if (cam != null and cam.zoom.x > 0.001) else 1.0

	var dead: bool = player.is_dead() or not player.is_visible_in_tree()
	var live: bool = LIVE_STATES.has(str(_runner.get("state")))
	var fuel: float = float(player.fuel)
	_ratio = clampf(fuel / maxf(Tuning.fuel_max, 0.001), 0.0, 1.0)
	_locked = bool(player.get("fuel_locked"))
	_aiming = bool(player.is_super_aiming()) if player.has_method("is_super_aiming") else false

	# refund tick: a rise in one frame while alive and live (respawn refills / kickoff resets never tick)
	if dead or not live:
		_prev_fuel = -1.0
	else:
		if _prev_fuel >= 0.0 and fuel - _prev_fuel >= Tuning.wk183_tick_min and Tuning.wk183_tick_s > 0.0:
			_tick_from = clampf(_prev_fuel / maxf(Tuning.fuel_max, 0.001), 0.0, 1.0)
			_tick_to = _ratio
			_tick_t = Tuning.wk183_tick_s
			_full_t = 0.0   # a top-up that fills the tank still shows for the full hold
			ticks += 1
			# UX FIX 5: the refuel ding rides the SAME trigger (AudioManager throttles per goat + pitches by amount)
			EventBus.refuel_ticked.emit(player, fuel - _prev_fuel)
		_prev_fuel = fuel
	_tick_t = maxf(0.0, _tick_t - rdelta)

	# full-and-steady fade (a fuel-locked Unlimited Boost tank is pinned full: the cyan flame is that tell)
	var full: bool = _ratio >= 0.999
	if full:
		_full_t += rdelta
	else:
		_full_t = 0.0
	var want: float = 1.0
	if dead or not live or not Tuning.wk183_arc_on:
		want = 0.0
	elif full and Tuning.wk183_full_hide and _full_t > Tuning.wk183_full_hold_s and _tick_t <= 0.0:
		want = 0.0
	if want > _alpha:
		_alpha = minf(want, _alpha + rdelta / maxf(Tuning.wk183_fade_in_s, 0.001))
	else:
		_alpha = maxf(want, _alpha - rdelta / maxf(Tuning.wk183_fade_out_s, 0.001))
	if dead:
		_alpha = 0.0   # a KO'd goat's arc is gone at once (no ghost ring left at the blast line)

	# WK-99 notch state (same rule as PlayerCard._wk99_notch: a hair under the line still counts; locked = lit)
	var thr: float = _notch_ratio()
	var lit: int = 1 if _locked or _ratio >= thr - 0.0005 else 0
	if lit != _notch_lit:
		if lit == 1 and _notch_lit == 0 and Tuning.wk99_notch_pop_s > 0.0:
			_notch_pop = Tuning.wk99_notch_pop_s
		_notch_lit = lit
	_notch_pop = maxf(0.0, _notch_pop - rdelta)
	queue_redraw()

func _notch_ratio() -> float:
	return clampf(Tuning.super_boost_min_fuel / maxf(Tuning.fuel_max, 0.001), 0.0, 1.0)

## Arc angle for a fill ratio: the left end (ratio 0) is at 6 o'clock + span/2, the right end at 6 o'clock - span/2
## (Godot y-down: PI/2 is straight down, angles decrease toward the right).
func _ang(r: float) -> float:
	var half: float = deg_to_rad(Tuning.wk183_span_deg) * 0.5
	return PI * 0.5 + half - 2.0 * half * clampf(r, 0.0, 1.0)

func _seg(a0: float, a1: float, rad: float, col: Color, w: float) -> void:
	var n: int = maxi(2, int(ceil(absf(a1 - a0) * SEG_PER_RAD)) + 1)
	draw_arc(Vector2.ZERO, rad, a0, a1, n, col, w, true)

## UX FIX 2: an arc segment with ROUND ends (the PlayerCard capsule / WK-36 bubble ring language): the arc plus a disc of
## half its width at each end, same colour. Opaque colours only (a translucent colour would double up on the cap overlap).
func _cap_seg(a0: float, a1: float, rad: float, col: Color, w: float) -> void:
	if absf(a1 - a0) > 0.0001:
		_seg(a0, a1, rad, col, w)
	draw_circle(Vector2.from_angle(a0) * rad, w * 0.5, col, true, -1.0, true)
	draw_circle(Vector2.from_angle(a1) * rad, w * 0.5, col, true, -1.0, true)

## Screen px from the goat's centre to the arc band's OUTER edge (PlayerPips keeps a below-flipped tag clear of it, WK-183
## UX FIX 6a). Valid whether or not the arc is showing, so the tag never jumps when the arc fades.
func outer_radius_screen(zoom: float) -> float:
	var rv: Variant = player.get("_radius") if player != null and is_instance_valid(player) else null
	var r: float = float(rv) if rv != null else 44.0
	return r * Tuning.wk183_radius_mult * zoom + Tuning.wk183_gap_px + Tuning.wk183_width_px * 0.5 + Tuning.wk183_outline_px

func _draw() -> void:
	var a: float = _shown_alpha()
	if a <= 0.01 or player == null or not is_instance_valid(player):
		return
	var k: float = _inv_zoom
	var rad: float = _radius_world()
	var w: float = Tuning.wk183_width_px * k
	var ow: float = Tuning.wk183_outline_px * k
	var a_start: float = _ang(0.0)
	var a_end: float = _ang(1.0)
	var tick: float = clampf(_tick_t / maxf(Tuning.wk183_tick_s, 0.001), 0.0, 1.0)   # 1 at the refund, 0 when done
	var low: bool = _ratio < Tuning.wk183_low_ratio and not _locked
	var pulse: float = _pulse()

	# 1) outline band (chocolate; when low it swings floor -> peak toward cream and never returns to chocolate, UX FIX 1)
	#    + the empty track (the team colour, well darkened). Round caps on both (UX FIX 2).
	var rim: float = lerpf(Tuning.wk183_low_rim_floor, Tuning.wk183_low_rim_flash, pulse) if low else 0.0
	var oc: Color = OUTLINE.lerp(CREAM, rim)
	_cap_seg(a_start, a_end, rad, Color(oc, a), w + ow * 2.0)
	var tc: Color = _team_color.darkened(Tuning.wk183_track_darken)
	_cap_seg(a_start, a_end, rad, Color(tc, Tuning.wk183_track_alpha * a), w)

	# 2) fill (team colour; brightens with the low pulse and with the refund glint)
	var glint: float = Tuning.wk183_tick_glow * tick * tick
	var fcol: Color = _team_color.lerp(Color.WHITE, maxf(Tuning.wk183_low_fill_white * pulse, glint))
	var fw: float = w * lerpf(1.0, Tuning.wk183_tick_width_pop, tick * tick)
	if _ratio > 0.002:
		_cap_seg(a_start, _ang(_ratio), rad, Color(fcol, a), fw)   # any fuel > 0 shows at least one round drop

	# 3) refund tick: the gained slice (at least wk183_tick_min_deg wide, ending at the fill end) flashes white
	if tick > 0.0 and _tick_to > _tick_from:
		var span: float = deg_to_rad(Tuning.wk183_span_deg)
		var min_r: float = deg_to_rad(Tuning.wk183_tick_min_deg) / maxf(span, 0.001)
		var r0: float = minf(_tick_from, maxf(0.0, _tick_to - min_r))
		var scol: Color = fcol.lerp(Color.WHITE, 0.35 + 0.65 * tick)   # opaque fade into the fill (caps never double up)
		_cap_seg(_ang(r0), _ang(_tick_to), rad, Color(scol, a), fw + ow * tick)

	# 4) WK-99 super-ready notch: a radial tick across the band at the threshold
	var na: float = _ang(_notch_ratio())
	var nh: float = deg_to_rad(Tuning.wk183_notch_deg) * 0.5
	if _notch_lit == 1:
		var pop: float = 1.0
		if _notch_pop > 0.0 and Tuning.wk99_notch_pop_s > 0.0:
			var u: float = 1.0 - _notch_pop / Tuning.wk99_notch_pop_s
			pop = lerpf(Tuning.wk99_notch_pop_scale, 1.0, 1.0 - pow(1.0 - u, 3.0))
		var nl: float = (w + 2.0 * Tuning.wk183_notch_overhang_px * k) * pop
		_seg(na + nh + 0.03 * pop, na - nh - 0.03 * pop, rad, Color(OUTLINE, a), nl + ow * 2.0)
		_seg(na + nh * pop, na - nh * pop, rad, Color(CREAM, a), nl)
	else:
		# UX FIX 4: UNLIT = a chocolate groove inside the track ("absent"), never a grey sibling of the lit bar
		_seg(na + nh * 0.7, na - nh * 0.7, rad, Color(OUTLINE, a * Tuning.wk183_notch_unlit_alpha), w * 0.6)
