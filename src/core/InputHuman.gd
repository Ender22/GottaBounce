class_name InputHuman
extends RefCounted
## Reads the project INPUT ACTION MAP into an InputIntent (INV-8). Never polls raw keycodes —
## bindings (keyboard + gamepad) live in project.godot [input], so devices are swappable without
## code changes. Edge-detects use_powerup/flap so they fire once per press.
##
## Actions consumed: move_left/right/up/down (aim), boost (held), super (press → AIM state,
## release / 2s cap → full blast — the un-charged super, lethality spec §1), use_powerup (edge).
##
## LOCAL MULTIPLAYER (couch play): each human polls a per-device CLONE of the base actions
## ("boost__d1" = boost events re-scoped to joypad 1). Clones are generated at runtime from the
## authored [input] bindings — we only re-scope the device filter, never invent bindings, so
## INV-8 holds and rebinding in project.godot still flows to every player.
## WK-04 (CC-3.1): every human is driven by EXACTLY ONE device — for_device("kb" | "pad:N"). The legacy
## any-device instance (InputHuman.new(): keyboard + every pad) is used ONLY for a lone human with no
## assigned device (cold boot straight into Arena.tscn / QA harness). Nobody shares the keyboard.

const DEV_ANY := -1     # legacy single-human: base actions as-authored (keyboard + every pad)
const DEV_NONE := -2    # no joypad (keyboard-only when keyboard=true; reads NOTHING when keyboard=false)

## The device this provider listens to (InputRouter key): "kb", "pad:N", "" = legacy any-device,
## "none" = unbound (reads nothing). QA reads it via eval; WK-28 (disconnect takeover) will rebind it.
var device_key: String = ""

var _a_left: StringName = &"move_left"
var _a_right: StringName = &"move_right"
var _a_up: StringName = &"move_up"
var _a_down: StringName = &"move_down"
var _a_boost: StringName = &"boost"
var _a_super: StringName = &"super"
var _a_pow: StringName = &"use_powerup"

var _intent := InputIntent.new()
var _prev_pow := false
# Menu -> gameplay swallow (CC-5.7 / audit C-19): while true, that action reads as NOT held until it has
# been seen released once. Armed by swallow_until_release() (PartyMatch.on_pause_resumed).
var _swallow_boost := false
var _swallow_super := false
var _swallow_pow := false

func _init(device: int = DEV_ANY, keyboard: bool = true) -> void:
	if device == DEV_ANY and keyboard:
		return   # legacy: poll the base actions untouched
	_a_left = _ensure_action(&"move_left", device, keyboard)
	_a_right = _ensure_action(&"move_right", device, keyboard)
	_a_up = _ensure_action(&"move_up", device, keyboard)
	_a_down = _ensure_action(&"move_down", device, keyboard)
	_a_boost = _ensure_action(&"boost", device, keyboard)
	_a_super = _ensure_action(&"super", device, keyboard)
	_a_pow = _ensure_action(&"use_powerup", device, keyboard)

## Exactly-one-device provider (WK-04 / audit C-05): "kb" -> keyboard events only (no pad, ever);
## "pad:N" -> joypad N only (no keyboard). Any other key -> an UNBOUND provider that reads nothing (a
## config bug — warned — never silently any-device). Keys come from InputRouter.device_key(event).
static func for_device(key: String) -> InputHuman:
	var h: InputHuman
	if key == "kb":
		h = InputHuman.new(DEV_NONE, true)
	elif key.begins_with("pad:") and key.substr(4).is_valid_int():
		h = InputHuman.new(key.substr(4).to_int(), false)
	else:
		push_warning("InputHuman.for_device: unknown device key '%s' -> unbound provider" % key)
		h = InputHuman.new(DEV_NONE, false)
		h.device_key = "none"
		return h
	h.device_key = key
	return h

## Clone `base`'s events into a per-device action (created once, reused across matches). Joypad
## events get device re-scoped; keyboard events are included only for the keyboard-owning slot.
static func _ensure_action(base: StringName, device: int, keyboard: bool) -> StringName:
	var scoped := StringName("%s__d%d%s" % [base, device, "_kb" if keyboard else ""])
	if InputMap.has_action(scoped):
		return scoped
	InputMap.add_action(scoped, InputMap.action_get_deadzone(base))
	for ev in InputMap.action_get_events(base):
		if ev is InputEventKey:
			if keyboard:
				InputMap.action_add_event(scoped, ev)
		elif device >= 0:
			var pe: InputEvent = ev.duplicate()
			pe.device = device
			InputMap.action_add_event(scoped, pe)
	return scoped

## Ignore boost / super / powerup until each has been RELEASED once (CC-5.7 / audit C-19). Called when a
## menu hands control back to gameplay (pause RESUME): the A that confirmed RESUME must not boost, the
## B / Start that closed the menu must not fire a powerup. Aim (stick) is never swallowed.
## Super is hold-to-aim / release-to-fire: if this goat was ALREADY aiming when the match paused (the
## last pre-pause poll had super held), keep that hold continuous — swallowing it would read as a
## release and fire the super the instant the sim resumes.
func swallow_until_release() -> void:
	_swallow_boost = true
	_swallow_pow = true
	_swallow_super = not _intent.super_hold

func poll() -> InputIntent:
	var it := _intent
	# get_vector applies the actions' deadzone with circular mapping — analog-stick friendly.
	var aim := Input.get_vector(_a_left, _a_right, _a_up, _a_down)
	if aim.length() > 1.0:
		aim = aim.normalized()
	var pow_held := Input.is_action_pressed(_a_pow)
	var boost_held := Input.is_action_pressed(_a_boost)
	var super_held := Input.is_action_pressed(_a_super)
	# release-gate (C-19): a swallowed action stays "up" until its button is physically released once
	if _swallow_pow:
		if pow_held:
			pow_held = false
		else:
			_swallow_pow = false
	if _swallow_boost:
		if boost_held:
			boost_held = false
		else:
			_swallow_boost = false
	if _swallow_super:
		if super_held:
			super_held = false
		else:
			_swallow_super = false

	it.aim = aim
	it.boost = boost_held
	it.super_hold = super_held   # held = aiming, release = fire
	it.use_powerup = pow_held and not _prev_pow
	it.flap = pow_held and not _prev_pow
	_prev_pow = pow_held
	return it
