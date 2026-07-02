extends Node2D
## Sudden-death closing laser walls (spec §1 SUDDEN_DEATH): two full-height vertical instakill
## planes starting at the left/right blast-zone edges, converging on stage center at constant
## speed so they fully meet in Tuning.laser_close_time. Kill players ONLY (they pass through
## level geometry, v0) — every touch is `cause = "laser"`, so kill-credit rules apply as normal
## (smashing someone into the wall is a kill). Rendered as thick pulsing glow beams: readability
## over prettiness — they must scream "do not touch". No script class_name on purpose (loaded
## via preload from PartyMatch; avoids a class-cache rebuild dependency).

const BODY_R := 44.0   # Player.BODY_RADIUS — die on beam TOUCH, not center-cross

var paused := false    # true during the sudden-death revive lock and the ROUND_END freeze

var _left_x := 0.0
var _right_x := 0.0
var _center_x := 0.0
var _start_l := 0.0
var _start_r := 0.0
var _speed_l := 0.0
var _speed_r := 0.0
var _top := 0.0
var _bottom := 0.0
var _t := 0.0
var _left_lines: Array = []
var _right_lines: Array = []

func setup(b: Rect2, center_x: float, close_time: float) -> void:
	_top = b.position.y
	_bottom = b.end.y
	_left_x = b.position.x
	_right_x = b.end.x
	_start_l = _left_x
	_start_r = _right_x
	_center_x = center_x
	var ct := maxf(close_time, 0.01)
	_speed_l = (center_x - _left_x) / ct
	_speed_r = (_right_x - center_x) / ct
	z_index = 60
	_left_lines = _make_beam()
	_right_lines = _make_beam()
	_update_lines()

## Layered beam: wide additive glow, hot orange body, white-hot core.
func _make_beam() -> Array:
	var specs: Array = [
		[52.0, Color(1.0, 0.25, 0.15, 0.30)],
		[22.0, Color(1.0, 0.35, 0.10, 0.85)],
		[7.0, Color(1.0, 0.95, 0.85, 1.0)],
	]
	var lines: Array = []
	for s in specs:
		var l := Line2D.new()
		l.width = s[0]
		l.default_color = s[1]
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		l.material = m
		add_child(l)
		lines.append(l)
	return lines

func _process(delta: float) -> void:
	_t += delta
	_update_lines()   # the danger pulse keeps animating even while paused

## Driven by PartyMatch during COMBAT/SUDDEN_DEATH ticks (not self-driven, so freezes are exact).
func tick(delta: float, players_arr: Array) -> void:
	if not paused:
		_left_x = minf(_left_x + _speed_l * delta, _center_x)
		_right_x = maxf(_right_x - _speed_r * delta, _center_x)
	for p in players_arr:
		if is_instance_valid(p) and not p.is_dead():
			var x: float = p.global_position.x
			if x - BODY_R <= _left_x or x + BODY_R >= _right_x:
				p.kill(&"laser", null)   # null -> Player.kill credits last_attacker if in window

func left_x() -> float:
	return _left_x

func right_x() -> float:
	return _right_x

## Double-KO revive path (lethality spec §5): walls spawn already `frac` closed so they're
## instantly on-camera. If a wall is already further closed (timer SD -> double-KO), keep it:
## frac = max(current, frac). Remaining close time shrinks accordingly (speeds unchanged).
func ensure_closed_frac(frac: float) -> void:
	var l := lerpf(_start_l, _center_x, frac)
	var r := lerpf(_start_r, _center_x, frac)
	_left_x = maxf(_left_x, l)
	_right_x = minf(_right_x, r)
	_update_lines()

func _update_lines() -> void:
	var pulse := 1.0 + 0.18 * sin(_t * 14.0)
	var widths: Array = [52.0 * pulse, 22.0, 7.0 * (2.0 - pulse)]
	for i in range(_left_lines.size()):
		var lp := PackedVector2Array([Vector2(_left_x, _top), Vector2(_left_x, _bottom)])
		var rp := PackedVector2Array([Vector2(_right_x, _top), Vector2(_right_x, _bottom)])
		_left_lines[i].points = lp
		_left_lines[i].width = widths[i]
		_right_lines[i].points = rp
		_right_lines[i].width = widths[i]
