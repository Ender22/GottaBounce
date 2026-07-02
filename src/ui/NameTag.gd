extends Node2D
## World-space name tag shown above a Bouncer's head during ROUND_INTRO/COUNTDOWN (spec §1):
## P1..P4 in the player's skin color, chunky chocolate-outlined type. Pops in with the spawn,
## stays through the countdown, fades out 1.0s into COMBAT (PartyMatch calls fade_out).

@onready var _label: Label = $Label

func setup(text: String, color: Color) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08)

func fade_out(dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, dur)
	tw.tween_callback(queue_free)
