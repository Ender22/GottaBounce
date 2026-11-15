extends Node2D
## WK-109 "POWER SHOT!" pop (spec docs/specs/wk109_power_shot_2026-11-15.md §3.2). Spawned by Ball._wk109_pop at the strike
## point + 90 wpx up, on a world-following CanvasLayer (the gate OPEN! call's layer: over the name tags, under the HUD).
## The word: Lilita One in the STRIKER'S team colour with a chocolate outline, cap height Tuning.wk109_pop_cap_wpx, flanked by
## two cream star sparkles (the gate-hit star sprite). Life 0.6 s: pop + rise 0.1, hold 0.3, fade 0.2. A goal or the end of
## live play cuts it short (the GOAL banner owns that moment). Kept inside the visible view so it is never clipped near the
## ceiling / court edge. Presentation only.  # WK-109

const CAP_RATIO := 0.70             # Lilita One cap height / font size (KickoffGatePop's measure)
const STAR_RATIO := 0.9             # star sparkle size / cap height
const STAR_GAP := 10.0              # wpx between a star and the word
const T_RISE := 0.1
const T_HOLD := 0.3
const T_FADE := 0.2
const T_CUT := 0.1
const RISE := 24.0                  # wpx the word drifts up during the rise
const EDGE_MARGIN := 16.0           # wpx kept clear of the visible view edge

@onready var _box: Node2D = $Box
@onready var _label: Label = $Box/Label
@onready var _star_l: Sprite2D = $Box/StarL
@onready var _star_r: Sprite2D = $Box/StarR

var _cut := false

func _ready() -> void:
	EventBus.goal_scored.connect(_on_goal_scored)
	EventBus.combat_ended.connect(cut)

## `at` = the word's centre in world px, `col` = the striker's team colour, `cap_wpx` = cap height in world px.
func present(at: Vector2, col: Color, cap_wpx: float) -> void:
	var ls: LabelSettings = _label.label_settings
	if ls != null:
		ls = ls.duplicate() as LabelSettings   # the scene's LabelSettings is shared by every pop instance
		ls.font_size = int(round(cap_wpx / CAP_RATIO))
		ls.font_color = col
		ls.outline_size = int(round(ls.font_size * 0.24))
		_label.label_settings = ls
	_label.reset_size()
	var lsz: Vector2 = _label.get_minimum_size()
	_label.size = lsz
	_label.position = -lsz * 0.5
	var star_wpx: float = cap_wpx * STAR_RATIO
	for st in [_star_l, _star_r]:
		var sp: Sprite2D = st
		sp.scale = Vector2.ONE * (star_wpx / float(maxi(1, sp.texture.get_width())))
	_star_l.position = Vector2(-lsz.x * 0.5 - STAR_GAP - star_wpx * 0.5, -cap_wpx * 0.15)
	_star_r.position = Vector2(lsz.x * 0.5 + STAR_GAP + star_wpx * 0.5, -cap_wpx * 0.15)
	var half: Vector2 = Vector2(lsz.x * 0.5 + STAR_GAP + star_wpx, lsz.y * 0.5) + Vector2.ONE * EDGE_MARGIN
	global_position = _clamp_to_view(at, half)
	_box.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_box, "scale", Vector2(1.15, 1.15), T_RISE * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_box, "scale", Vector2.ONE, T_RISE * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var tr := create_tween()
	tr.tween_property(_box, "position:y", -RISE, T_RISE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tf := create_tween()
	tf.tween_interval(T_RISE + T_HOLD)
	tf.tween_property(self, "modulate:a", 0.0, T_FADE)
	tf.tween_callback(queue_free)

## Keep the whole word on screen: the visible world rect is the viewport through the inverse canvas (camera) transform.
func _clamp_to_view(at: Vector2, half: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return at
	var r: Rect2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var p := at
	if r.size.x > half.x * 2.0:
		p.x = clampf(p.x, r.position.x + half.x, r.end.x - half.x)
	if r.size.y > half.y * 2.0 + RISE:
		p.y = clampf(p.y, r.position.y + half.y + RISE, r.end.y - half.y)
	return p

func _on_goal_scored(_team, _scorer, _own_goal) -> void:
	cut()

## Cut short (a goal / STAGE_END): a quick fade, then gone.
func cut() -> void:
	if _cut or not is_inside_tree():
		return
	_cut = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, T_CUT)
	t.tween_callback(queue_free)
