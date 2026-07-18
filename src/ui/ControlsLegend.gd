extends CanvasLayer
## FIRST-STAGE CONTROLS LEGEND (match_ceremony brief §2). Four cream chips — MOVE / FLY /
## SUPER SMASH / POWERUP — with drawn PadGlyph buttons, bottom-center, on stage 1 of every
## Brawl match. Rides the intro/countdown quiet time, holds 4s into COMBAT, then fades.
## Charm beat: pressing a listed button press-bounces its chip (the strip answers you).
## Early-out: the first use_powerup press in combat fades it immediately (lesson learned).
## Keyboard variant auto-selected when no pad is connected. Adds 0.0s to match pacing.

const COMBAT_LINGER := 4.0
const FADE_TIME := 0.4
# chip: label / gameplay action (for the press-bounce) / pad glyph / keyboard glyph
const CHIPS := [
	{"label": "MOVE", "action": "", "pad": "stick", "kb": "WASD"},
	{"label": "FLY", "action": "boost", "pad": "A", "kb": "SPACE"},
	{"label": "SUPER SMASH", "action": "super", "pad": "X", "kb": "K"},
	{"label": "POWERUP", "action": "use_powerup", "pad": "B", "kb": "L"},
]

@onready var _strip: HBoxContainer = $Root/Strip

var _combat := false
var _fade_t := -1.0
var _dying := false
var _chip_nodes: Array = []   # [{panel, action}]

func _ready() -> void:
	visible = false

func present() -> void:
	visible = true
	_combat = false
	_dying = false
	_fade_t = -1.0
	_strip.modulate.a = 1.0
	for c in _strip.get_children():
		c.queue_free()
	_chip_nodes.clear()
	var pad: bool = Input.get_connected_joypads().size() > 0
	# cream chip plate (HintStrip language). NOTE: StepChip is a Button variation — a PanelContainer
	# ignores it silently, so the stylebox is set directly.
	var chip_sb := StyleBoxFlat.new()
	chip_sb.bg_color = Color(1, 1, 1, 0.94)
	chip_sb.border_color = Color(0.231373, 0.141176, 0.105882)
	chip_sb.set_border_width_all(3)
	chip_sb.set_corner_radius_all(18)
	chip_sb.set_content_margin_all(10.0)
	chip_sb.content_margin_left = 14.0
	chip_sb.content_margin_right = 16.0
	for spec in CHIPS:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", chip_sb)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		chip.add_child(box)
		var glyph := PadGlyph.new()
		glyph.setup(str(spec["pad"]) if pad else str(spec["kb"]))
		box.add_child(glyph)
		var lbl := Label.new()
		lbl.theme_type_variation = &"CardTag"
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.text = str(spec["label"])
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(lbl)
		_strip.add_child(chip)
		_chip_nodes.append({"panel": chip, "action": str(spec["action"])})
	# staggered left->right pop-in (house stagger 0.12)
	await get_tree().process_frame
	if not visible:
		return
	for i in range(_chip_nodes.size()):
		var p: PanelContainer = _chip_nodes[i]["panel"]
		p.pivot_offset = p.size * 0.5
		p.scale = Vector2(0.3, 0.3)
		p.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.12 * float(i) + 0.01)
		tw.tween_property(p, "modulate:a", 1.0, 0.10)
		tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Called from PartyMatch._bounce_go(): start the 4s combat linger, then fade.
func on_combat_started() -> void:
	if not visible:
		return
	_combat = true
	_fade_t = COMBAT_LINGER

func _process(delta: float) -> void:
	if not visible or _dying:
		return
	# press-bounce: the strip answers the buttons it teaches
	for c in _chip_nodes:
		var act: String = c["action"]
		if act != "" and Input.is_action_just_pressed(act):
			_bounce_chip(c["panel"])
			# early-out: powerup pressed during combat = lesson learned, strip leaves now
			if _combat and act == "use_powerup":
				_fade_out()
				return
	if Input.is_action_just_pressed(&"move_left") or Input.is_action_just_pressed(&"move_right"):
		_bounce_chip(_chip_nodes[0]["panel"])
	if _fade_t > 0.0:
		_fade_t -= delta
		if _fade_t <= 0.0:
			_fade_out()

func _bounce_chip(p: PanelContainer) -> void:
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2(0.88, 0.88), 0.06)
	tw.tween_property(p, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fade_out() -> void:
	_dying = true
	var tw := create_tween()
	tw.tween_property(_strip, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void: visible = false)
