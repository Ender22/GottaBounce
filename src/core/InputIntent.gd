class_name InputIntent
extends RefCounted
## Abstract player intent (INV-8). Humans AND bots produce this; gameplay reads ONLY this,
## never raw devices. Keeps humans/bots interchangeable.

var aim: Vector2 = Vector2.ZERO   # desired thrust direction, screen-relative, length 0..1
var boost: bool = false           # normal boost held
var super_hold: bool = false      # super HELD: press = enter AIM, release (or 2s cap) = fire
var use_powerup: bool = false     # use powerup pressed (edge)
var flap: bool = false            # wings flap pressed (edge)
var taunt: bool = false           # taunt / bleat pressed (edge) — pad Y [3] / keyboard J (WK-37b; WK-53 adds the sample)

func clear_edges() -> void:
	# call after consuming one-frame presses
	use_powerup = false
	flap = false
	taunt = false
