extends Node2D
## WK-131 "NOT YET!" pop (brief §6.3 item 4): a cream Lilita One word with a 6 wpx chocolate outline after a small closed
## padlock glyph (the gate badge at 30 wpx), spawned in WORLD space by KickoffGate when the ball clonks off a closed gate.
## It sits court-side of the gate and above the contact point (never over the ball; z 39 under the ball's 40).
## Motion: scale 0.6 -> 1.15 -> 1.0 in 0.12 s, rise 30 wpx, hold, gone by 0.6 s. Presentation only.

const GLYPH_WPX := 30.0
const GAP := 8.0
const POP_T := 0.12
const RISE := 30.0
const LIFE := 0.6
const FADE := 0.16
const CAP_RATIO := 0.70             # Lilita One cap height / font size (34 wpx caps -> ~49 px font)

@onready var _box: Node2D = $Box
@onready var _lock: Sprite2D = $Box/Lock
@onready var _label: Label = $Box/Label

## `at` = the pop's inner edge point (court side of the gate), `md` = +1 grows to the right, -1 to the left.
## WK-155: optional `glyph` (default the closed padlock), `cap_wpx` (default Tuning.sports_gate_pop_wpx) and `life`
## (default LIFE) so the gate's OPEN! call reuses this pop with the open padlock, bigger and held longer.
func present(at: Vector2, md: float, text: String, glyph: Texture2D = null, cap_wpx: float = -1.0, life: float = -1.0) -> void:
	_label.text = text
	if glyph != null:
		_lock.texture = glyph
	var cap: float = cap_wpx if cap_wpx > 0.0 else Tuning.sports_gate_pop_wpx
	var life_s: float = maxf(life, FADE + POP_T) if life > 0.0 else LIFE
	var glyph_wpx: float = GLYPH_WPX * cap / Tuning.sports_gate_pop_wpx
	var ls: LabelSettings = _label.label_settings
	if ls != null:
		ls = ls.duplicate() as LabelSettings   # the scene's LabelSettings is shared by every pop instance
		ls.font_size = int(round(cap / CAP_RATIO))
		_label.label_settings = ls
	_label.reset_size()
	var lsz: Vector2 = _label.get_minimum_size()
	_label.size = lsz
	_lock.scale = Vector2.ONE * (glyph_wpx / float(_lock.texture.get_width()))
	var total: float = glyph_wpx + GAP + lsz.x
	# content laid out left -> right, centred on the box origin
	_lock.position = Vector2(-total * 0.5 + glyph_wpx * 0.5, 0.0)
	_label.position = Vector2(-total * 0.5 + glyph_wpx + GAP, -lsz.y * 0.5)
	global_position = Vector2(at.x + md * total * 0.5, at.y)
	_box.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_box, "scale", Vector2(1.15, 1.15), POP_T * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_box, "scale", Vector2.ONE, POP_T * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var tr := create_tween()
	tr.tween_property(_box, "position:y", -RISE, life_s - FADE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tf := create_tween()
	tf.tween_interval(life_s - FADE)
	tf.tween_property(self, "modulate:a", 0.0, FADE)
	tf.tween_callback(queue_free)
