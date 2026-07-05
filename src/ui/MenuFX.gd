class_name MenuFX
extends RefCounted
## Shared focus / press / transition juice for the whole shell (frontend_ux_spec §1.3 / §4 tween
## table). Every screen and component drives its motion through these static helpers so the shell
## feels made of one rubber. Tweens are bound to their Control and stored in node metas so the idle
## wobble/rotate loops can be killed cleanly on focus-out. Never linear — overshoot then settle.

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const ACCENT_PINK := Color("#ff5fa8")

## Focus-IN: springy scale-up (BACK/OUT 0.18) then start the idle wobble + micro-rotate loops.
static func focus_in(c: Control) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	_kill(c, "fx_pop")
	_kill(c, "fx_wob")
	_kill(c, "fx_rot")
	var fs: float = float(c.get_meta("focus_scale", 1.08))
	var pop := c.create_tween()
	pop.tween_property(c, "scale", Vector2(fs, fs), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_callback(_start_wobble.bind(c, fs))
	c.set_meta("fx_pop", pop)

static func _start_wobble(c: Control, fs: float) -> void:
	if not is_instance_valid(c) or not c.has_focus():
		return
	var wob := c.create_tween().set_loops()
	wob.tween_property(c, "scale", Vector2(fs * 1.02, fs * 1.02), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wob.tween_property(c, "scale", Vector2(fs * 0.98, fs * 0.98), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	c.set_meta("fx_wob", wob)
	var rot := c.create_tween().set_loops()
	rot.tween_property(c, "rotation", deg_to_rad(1.0), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rot.tween_property(c, "rotation", deg_to_rad(-1.0), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	c.set_meta("fx_rot", rot)

## Focus-OUT: snap back to rest (QUAD/IN 0.12) — snappier than focus-in so the new item wins the eye.
static func focus_out(c: Control) -> void:
	if not is_instance_valid(c):
		return
	_kill(c, "fx_pop")
	_kill(c, "fx_wob")
	_kill(c, "fx_rot")
	var t := c.create_tween()
	t.set_parallel(true)
	t.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(c, "rotation", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## PRESS/confirm: quick squash then elastic overshoot back to focused rest.
static func press_pop(c: Control) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	_kill(c, "fx_wob")
	_kill(c, "fx_rot")
	var fs: float = float(c.get_meta("focus_scale", 1.08))
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2(0.92, 0.92), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(c, "scale", Vector2(fs * 1.06, fs * 1.06), 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2(fs, fs), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_start_wobble.bind(c, fs))

## A short reject wobble (clamped stepper / locked mode card): ±3 degrees, twice.
static func reject_shake(c: Control) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var t := c.create_tween()
	t.tween_property(c, "rotation", deg_to_rad(3.0), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "rotation", deg_to_rad(-3.0), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "rotation", deg_to_rad(2.0), 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "rotation", 0.0, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A short value pop (stepper number / slider knob): 1.0 -> 1.2 -> 1.0.
static func value_pop(c: Control, peak := 1.2) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2(peak, peak), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func _kill(c: Control, key: String) -> void:
	if c.has_meta(key):
		var t: Variant = c.get_meta(key)
		if t is Tween and (t as Tween).is_valid():
			(t as Tween).kill()
		c.remove_meta(key)
