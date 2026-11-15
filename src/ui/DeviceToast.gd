extends CanvasLayer
## WK-28b connect / disconnect toasts (audit R-32 · COUCH_CONVENTIONS CC-3.4 / CC-3.5). A small stack of cream
## pills at the top centre of the screen: [P# chip in the player's colour] [device / button glyph] [text]. Owned by
## DeviceWatch (a child of the InputRouter autoload), so a toast survives scene changes and shows over menus, the
## lobby, a live match and the pause / disconnect overlays alike. Processes while the tree is paused.
## Look lives in scenes/ui/DeviceToast.tscn (one hidden Template, duplicated per toast). Timings in Tuning
## (device_toast_hold / _fade / _max).

@onready var _stack: VBoxContainer = $Root/Stack
@onready var _tpl: PanelContainer = $Root/Stack/Template

## QA feed (eval): every toast shown, newest last: {text, tag, icon, msec}.
var shown_log: Array = []

## Show one toast. `tag` = "" for no P# chip; `icon` = any PadGlyph id ("pad", "A", "kb", ...), "" = none.
func show_toast(text: String, tag: String = "", tag_color: Color = Color("#ffd23f"), icon: String = "pad") -> void:
	if _stack == null:
		return
	var t: PanelContainer = _tpl.duplicate()
	t.visible = true
	t.modulate.a = 0.0
	_stack.add_child(t)
	(t.get_node("Row/Text") as Label).text = text
	var chip := t.get_node("Row/Tag") as PanelContainer
	chip.visible = tag != ""
	if tag != "":
		(chip.get_node("Label") as Label).text = tag
		var sb: StyleBoxFlat = (chip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		sb.bg_color = tag_color
		chip.add_theme_stylebox_override("panel", sb)
	var ic: Control = t.get_node("Row/Icon")
	ic.visible = icon != ""
	if icon != "":
		ic.call("setup", icon)
	shown_log.append({"text": text, "tag": tag, "icon": icon, "msec": Time.get_ticks_msec()})
	if shown_log.size() > 24:
		shown_log.pop_front()
	# too many at once: the oldest leaves early
	var live: Array = _live()
	while live.size() > maxi(1, Tuning.device_toast_max):
		_dismiss(live.pop_front() as Control, 0.1)
	_animate_in(t)

func _live() -> Array:
	var out: Array = []
	for c in _stack.get_children():
		if c != _tpl and not c.has_meta("leaving"):
			out.append(c)
	return out

func _animate_in(t: PanelContainer) -> void:
	await get_tree().process_frame   # one layout pass so the pivot is the real centre
	if not is_instance_valid(t):
		return
	t.pivot_offset = t.size * 0.5
	t.scale = Vector2(0.8, 0.8)
	var fade: float = maxf(0.01, Tuning.device_toast_fade)
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, fade)
	tw.parallel().tween_property(t, "scale", Vector2.ONE, fade).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, Tuning.device_toast_hold))
	tw.tween_callback(_dismiss.bind(t, fade))
	t.set_meta("tween", tw)

func _dismiss(t: Control, fade: float) -> void:
	if not is_instance_valid(t) or t.has_meta("leaving"):
		return
	t.set_meta("leaving", true)
	if t.has_meta("tween"):
		var old: Tween = t.get_meta("tween")
		if old != null and old.is_valid():
			old.kill()
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 0.0, fade)
	tw.tween_callback(t.queue_free)
