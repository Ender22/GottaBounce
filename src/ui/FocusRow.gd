extends RefCounted
## WK-14 (CC-5.1, audit C-13 / R-21): ONE focus look for every shell button. Focus is singular: the focused button
## wears ShellBtnPrimary (the green fill, white type, chocolate outline) and every other button is the cream ShellBtn.
## No button is permanently "primary" (PLAY / STAY / REMATCH used to stay green while focus sat on QUIT, so two
## buttons looked chosen from across a room).
##
## Two users:
##  - manual end-screen rows (Brawl VictoryScreen, SportsVictory, SportsHUD / TrialsHUD match-end rows): `row()`
##    replaces the three `_set_focus` copies (style swap + 1.12 spring + breath; unfocused buttons dim).
##  - MenuScreen buttons on Godot focus (title, quit dialog, ...): `style()` on focus in / out.
## Static helpers only; callers `preload` this script (no class_name: no class-cache rebuild, no native clash).
## The PauseMenu keeps its own owner-colour swap (CC-1.5 / WK-34), which already follows this rule.

const PRIMARY := &"ShellBtnPrimary"
const SECONDARY := &"ShellBtn"
const FOCUS_SCALE := 1.12
const BREATH_SCALE := 1.075
const UNFOCUSED_ALPHA := 0.8

## Is `b` a shell button this rule owns (plain ShellBtn / ShellBtnPrimary)? Cards, chips and HoldButtons are not.
static func owns(c: Control) -> bool:
	if not (c is Button):
		return false
	var v: StringName = (c as Button).theme_type_variation
	return v == PRIMARY or v == SECONDARY

## The one style rule: focused = primary, unfocused = secondary.
static func style(b: Button, focused: bool) -> void:
	b.theme_type_variation = PRIMARY if focused else SECONDARY

## Manual focus row: button `i` is focused (style swap + spring to 1.12 + a breathing pulse), the rest are the
## cream style, dimmed. Returns the new pulse tween (kill the old one through `old_pulse`).
static func row(host: Node, btns: Array, i: int, old_pulse: Tween) -> Tween:
	if old_pulse != null and old_pulse.is_valid():
		old_pulse.kill()
	for j in range(btns.size()):
		var b: Button = btns[j]
		var focused: bool = j == i
		style(b, focused)
		b.modulate.a = 1.0 if focused else UNFOCUSED_ALPHA
		var tw := host.create_tween()
		tw.tween_property(b, "scale", Vector2(FOCUS_SCALE, FOCUS_SCALE) if focused else Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if i < 0 or i >= btns.size():
		return null
	var fb: Button = btns[i]
	var pulse := host.create_tween()
	pulse.set_loops()
	pulse.tween_property(fb, "scale", Vector2(BREATH_SCALE, BREATH_SCALE), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(fb, "scale", Vector2(FOCUS_SCALE, FOCUS_SCALE), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return pulse
