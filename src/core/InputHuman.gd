class_name InputHuman
extends RefCounted
## Reads the project INPUT ACTION MAP into an InputIntent (INV-8). Never polls raw keycodes —
## bindings (keyboard + gamepad) live in project.godot [input], so devices are swappable without
## code changes. Edge-detects use_powerup/flap so they fire once per press.
##
## Actions consumed: move_left/right/up/down (aim), boost (held), super (held → charge,
## release → fire, matching the chargeable super-boost model), use_powerup (edge).
## v0 is single-human; per-device action sets (P2+ local multiplayer) come later.

var _intent := InputIntent.new()
var _prev_super := false
var _prev_pow := false

func poll() -> InputIntent:
	var it := _intent
	# get_vector applies the actions' deadzone with circular mapping — analog-stick friendly.
	var aim := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if aim.length() > 1.0:
		aim = aim.normalized()
	var super_held := Input.is_action_pressed(&"super")
	var pow_held := Input.is_action_pressed(&"use_powerup")

	it.aim = aim
	it.boost = Input.is_action_pressed(&"boost")
	it.super_hold = super_held                       # chargeable: held = charging, release = fire
	it.super_boost = super_held and not _prev_super  # legacy edge (unused)
	it.use_powerup = pow_held and not _prev_pow
	it.flap = pow_held and not _prev_pow
	_prev_super = super_held
	_prev_pow = pow_held
	return it
