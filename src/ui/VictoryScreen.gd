extends CanvasLayer
## VICTORY CEREMONY (match_ceremony brief §3). Brawl-only match-end screen replacing the old
## text panel: winner's charge-pose bust slams in over gold rays + confetti, "WINNER!" in gold,
## final standings in the ScoreScreen race-bar language, then a focused REMATCH / CHANGE SETUP /
## MENU prompt row. Interactive at ARM_TIME; accept before that FAST-FORWARDS every tween to its
## end state (never a black cut). PartyMatch presents it ~0.9s after the winning kill so the
## in-world punch-zoom breathes first; the screen owns all input while live and reports the
## player's choice through the three signals below. Data-driven (present(...)) so Sports can
## adopt it in a later slice. Terminal screen — the ≤3.4s between-stage pacing does not bind.

signal rematch_pressed
signal setup_pressed
signal menu_pressed

const GOLD := Color("#ffd23f")
const CHOCO := Color(0.231373, 0.141176, 0.105882)
const ARM_TIME := 1.1          # s from present() to interactive (absolute ~2.0 from the kill)
const BAR_PAD := 3.0
const ROW_STAGGER := 0.12
const FILL_TIME := 0.5
const RAYS_PATH := "res://assets/ui/victory_rays.png"
const CONFETTI_COLORS: Array[Color] = [
	Color("#ff5fa8"), Color("#4aa8ff"), Color("#54c94a"), Color("#ffc93f"),
	Color("#b06bff"), Color("#ffd23f"),
]

@onready var _root: Control = $Root
@onready var _scrim: ColorRect = $Root/Scrim
@onready var _fx: Node2D = $Root/FX
@onready var _rays: TextureRect = $Root/Rays
@onready var _shadow: TextureRect = $Root/Shadow
@onready var _bust: TextureRect = $Root/Bust
@onready var _winner_l: Label = $Root/WinnerL
@onready var _name_l: Label = $Root/NameL
@onready var _tray: PanelContainer = $Root/TrayArea/TrayCenter/Tray
@onready var _rows_box: VBoxContainer = $Root/TrayArea/TrayCenter/Tray/Box/Rows
@onready var _template: PanelContainer = $Root/TrayArea/TrayCenter/Tray/Box/Rows/RowTemplate
@onready var _prompts: HBoxContainer = $Root/Prompts
@onready var _btns: Array = [$Root/Prompts/BtnRematch, $Root/Prompts/BtnSetup, $Root/Prompts/BtnMenu]

var _live := false
var _armed := false
var _t := 0.0
var _focus := 0
var _tweens: Array = []
var _built: Array = []         # row handles from _build_row (for the fill pass + fast-forward)
var _bar_ends: Array = []      # [{fill, w, score_l, to}] for fast-forward
var _bust_rest_y := 320.0
var _tray_rest_x := 0.0
var _pulse: Tween

func _ready() -> void:
	visible = false
	for i in range(_btns.size()):
		var idx := i
		(_btns[i] as Button).pressed.connect(func() -> void:
			if _armed:
				_activate(idx))

## winner: {skin:String, pn:int, label:int, tag:String, color:Color, human:bool}.
## rows: [{pn, tag:String, label:int, color:Color, skin, score:int, human:bool}]. pn = 1-based player index
## (row identity / winner match); tag/label = displayed identity (WK-10: "P3" lobby label / "CPU").
## (any order — sorted desc here). target: kills-to-win for the race bars.
func present(winner: Dictionary, rows: Array, target: int) -> void:
	visible = true
	_live = true
	_armed = false
	_t = 0.0
	_focus = 0
	_tweens.clear()
	_bar_ends.clear()
	# --- winner altar content ---
	var skin := str(winner.get("skin", "pink"))
	# idle = the upright big-grin pose (the charge art is a horizontal dash — graded in-game as
	# "crashed", not "mugging"; idle mugs)
	var tex_path := "res://assets/characters/bouncer_%s_idle.png" % skin
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/characters/bouncer_%s_charge.png" % skin
	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path)
		_bust.texture = tex
		_shadow.texture = tex
	var wname := PlayerIdentity.name_for_skin(skin)
	# WK-10: the human's lobby label ("PLAYER 3" even with an empty P2 slot), never the raw slot index
	var wlabel: int = int(winner.get("label", winner.get("pn", 1)))
	var sub := ("PLAYER %d" % wlabel) if bool(winner.get("human", true)) else "CPU"
	_name_l.text = "%s — %s" % [wname, sub]
	_name_l.add_theme_color_override("font_color", winner.get("color", Color.WHITE))
	if ResourceLoader.exists(RAYS_PATH):
		_rays.texture = load(RAYS_PATH)
	else:
		_rays.texture = _fallback_glow()
	# --- standings rows (sorted desc; winner row gold-rimmed) ---
	for c in _rows_box.get_children():
		if c != _template:
			c.queue_free()
	var sorted := rows.duplicate()
	sorted.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	_built.clear()
	for r in sorted:
		_built.append(_build_row(r, target, int(r["pn"]) == int(winner.get("pn", -1))))
	# --- start states (end states are the scene's rest values) ---
	_scrim.modulate.a = 0.0
	for n: Control in [_rays, _shadow, _bust, _winner_l, _name_l, _tray, _prompts]:
		n.modulate.a = 0.0
	_winner_l.scale = Vector2(0.3, 0.3)
	_name_l.scale = Vector2(0.3, 0.3)
	_bust_rest_y = _bust.position.y
	_bust.position.y = _bust_rest_y + 260.0
	_shadow.position.y = _bust.position.y + 10.0
	await get_tree().process_frame   # tray/prompts layout before slide offsets + bar widths
	if not _live:
		return
	_tray_rest_x = _tray.position.x
	_tray.position.x = _tray_rest_x + 320.0
	for b: Button in _btns:
		b.pivot_offset = b.size * 0.5
	# --- choreography (brief §3 table; t=0 here is ~0.9s after the kill) ---
	var sc := create_tween()
	_tweens.append(sc)
	sc.tween_property(_scrim, "modulate:a", 1.0, 0.25)   # scene color carries the 0.6 scrim alpha
	var slam := create_tween()
	_tweens.append(slam)
	slam.tween_interval(0.10)
	slam.tween_callback(func() -> void:
		AudioManager.play_sfx("smash_heavy")
		_burst(Vector2(220, 90), 55.0)
		_rays_spin())
	slam.tween_property(_bust, "modulate:a", 1.0, 0.08)
	slam.parallel().tween_property(_shadow, "modulate:a", 0.85, 0.08)
	slam.parallel().tween_property(_bust, "position:y", _bust_rest_y, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.parallel().tween_property(_shadow, "position:y", _bust_rest_y + 10.0, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.parallel().tween_property(_rays, "modulate:a", 1.0, 0.35)
	# squash-settle after landing
	slam.tween_property(_bust, "scale", Vector2(1.08, 0.90), 0.08)
	slam.tween_property(_bust, "scale", Vector2(0.96, 1.05), 0.06)
	slam.tween_property(_bust, "scale", Vector2.ONE, 0.06)
	slam.tween_callback(_bust_bob)
	var wl := create_tween()
	_tweens.append(wl)
	wl.tween_interval(0.25)
	wl.tween_callback(func() -> void:
		AudioManager.play_sfx("ui_click")
		_burst(Vector2(1700, 90), 125.0))
	wl.tween_property(_winner_l, "modulate:a", 1.0, 0.10)
	wl.parallel().tween_property(_winner_l, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var nl := create_tween()
	_tweens.append(nl)
	nl.tween_interval(0.40)
	nl.tween_property(_name_l, "modulate:a", 1.0, 0.10)
	nl.parallel().tween_property(_name_l, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tr := create_tween()
	_tweens.append(tr)
	tr.tween_interval(0.55)
	tr.tween_property(_tray, "modulate:a", 1.0, 0.15)
	tr.parallel().tween_property(_tray, "position:x", _tray_rest_x, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tr.tween_callback(func() -> void: _animate_rows(_built))
	var pr := create_tween()
	_tweens.append(pr)
	pr.tween_interval(ARM_TIME)
	pr.tween_property(_prompts, "modulate:a", 1.0, 0.15)
	_drizzle()

# ------------------------------------------------------------------ rows (ScoreScreen recipe)

func _build_row(r: Dictionary, target: int, is_winner: bool) -> Dictionary:
	var row: PanelContainer = _template.duplicate()
	row.visible = true
	if is_winner:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.12)
		sb.border_color = GOLD
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(6.0)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		row.add_theme_stylebox_override("panel", sb)
	_rows_box.add_child(row)
	var color: Color = r["color"]
	var head: TextureRect = row.get_node("RowBox/Head")
	var head_path := "res://assets/characters/bouncer_%s_idle.png" % str(r["skin"])
	if ResourceLoader.exists(head_path):
		head.texture = load(head_path)
	var name_l: Label = row.get_node("RowBox/PName")
	var who := PlayerIdentity.name_for_skin(str(r["skin"]))
	name_l.text = "%s  %s" % [who, str(r.get("tag", "P%d" % int(r["pn"])))]   # WK-10: "P3" / "CPU"
	name_l.add_theme_color_override("font_color", color)
	var fill: Panel = row.get_node("RowBox/BarSlot/BarFill")
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = color
	fill_sb.set_corner_radius_all(7)
	fill.add_theme_stylebox_override("panel", fill_sb)
	var score_l: Label = row.get_node("RowBox/Score")
	score_l.text = "0"
	if is_winner:
		score_l.add_theme_color_override("font_color", GOLD)
	return {"row": row, "fill": fill, "score_l": score_l, "to": int(r["score"]), "target": maxi(1, target)}

func _animate_rows(built: Array) -> void:
	for i in range(built.size()):
		var h: Dictionary = built[i]
		var slot: Control = (h["row"] as Control).get_node("RowBox/BarSlot")
		var inner_w: float = maxf(0.0, slot.size.x - BAR_PAD * 2.0)
		var inner_h: float = maxf(0.0, slot.size.y - BAR_PAD * 2.0)
		var fill: Panel = h["fill"]
		var w_to: float = inner_w * clampf(float(h["to"]) / float(h["target"]), 0.0, 1.0)
		fill.position = Vector2(BAR_PAD, BAR_PAD)
		fill.size = Vector2(0.0, inner_h)
		_bar_ends.append({"fill": fill, "w": w_to, "score_l": h["score_l"], "to": int(h["to"])})
		var score_l: Label = h["score_l"]
		var to_v: int = int(h["to"])
		var tw := create_tween()
		_tweens.append(tw)
		tw.tween_interval(float(i) * ROW_STAGGER + 0.01)
		tw.tween_property(fill, "size:x", w_to, FILL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(v: float) -> void: score_l.text = str(int(round(v))),
			0.0, float(to_v), FILL_TIME)

# ------------------------------------------------------------------ input

func _process(delta: float) -> void:
	if not _live:
		return
	_t += delta
	if not _armed:
		if _t >= ARM_TIME + 0.15:
			_arm()
		elif _t > 0.05 and (Input.is_action_just_pressed(&"menu_accept") or Input.is_action_just_pressed(&"ui_accept")):
			_fast_forward()
		return
	if Input.is_action_just_pressed(&"ui_left"):
		_set_focus((_focus + _btns.size() - 1) % _btns.size())
	elif Input.is_action_just_pressed(&"ui_right"):
		_set_focus((_focus + 1) % _btns.size())
	elif Input.is_action_just_pressed(&"menu_accept") or Input.is_action_just_pressed(&"ui_accept"):
		_activate(_focus)
	elif Input.is_action_just_pressed(&"menu_back"):
		# first back = focus the safe MENU option; second back = take it (brief §3 input map)
		if _focus == 2:
			_activate(2)
		else:
			_set_focus(2)

func _arm() -> void:
	_armed = true
	_set_focus(0)

func _set_focus(i: int) -> void:
	_focus = i
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	for j in range(_btns.size()):
		var b: Button = _btns[j]
		var focused: bool = j == i
		b.modulate.a = 1.0 if focused else 0.85
		var tw := create_tween()
		tw.tween_property(b, "scale", Vector2(1.12, 1.12) if focused else Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# "press me" idle breath on the focused button
	var fb: Button = _btns[i]
	_pulse = create_tween()
	_pulse.set_loops()
	_pulse.tween_property(fb, "scale", Vector2(1.075, 1.075), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(fb, "scale", Vector2(1.12, 1.12), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _activate(i: int) -> void:
	AudioManager.play_sfx("ui_click")
	match i:
		0: rematch_pressed.emit()
		1: setup_pressed.emit()
		2: menu_pressed.emit()

## Accept during the choreography: land every element instantly (never a black cut), arm input.
func _fast_forward() -> void:
	for tw in _tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()
	_scrim.modulate.a = 1.0
	for n: Control in [_rays, _bust, _winner_l, _name_l, _tray, _prompts]:
		n.modulate.a = 1.0
	_shadow.modulate.a = 0.85
	_bust.position.y = _bust_rest_y
	_shadow.position.y = _bust_rest_y + 10.0
	_bust.scale = Vector2.ONE
	_winner_l.scale = Vector2.ONE
	_name_l.scale = Vector2.ONE
	_tray.position.x = _tray_rest_x
	if _bar_ends.is_empty():
		# skipped before the tray callback ran the fill pass — land the bars directly
		for h in _built:
			var slot: Control = (h["row"] as Control).get_node("RowBox/BarSlot")
			var inner_w: float = maxf(0.0, slot.size.x - BAR_PAD * 2.0)
			var inner_h: float = maxf(0.0, slot.size.y - BAR_PAD * 2.0)
			var fill: Panel = h["fill"]
			fill.position = Vector2(BAR_PAD, BAR_PAD)
			fill.size = Vector2(inner_w * clampf(float(h["to"]) / float(h["target"]), 0.0, 1.0), inner_h)
			(h["score_l"] as Label).text = str(int(h["to"]))
	else:
		for h in _bar_ends:
			(h["fill"] as Panel).size.x = h["w"]
			(h["score_l"] as Label).text = str(int(h["to"]))
	_bust_bob()
	_rays_spin()
	_arm()

func dismiss() -> void:
	_live = false
	for tw in _tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	for c in _fx.get_children():
		c.queue_free()
	visible = false

# ------------------------------------------------------------------ flourish helpers

func _bust_bob() -> void:
	var tw := create_tween()
	_tweens.append(tw)
	tw.set_loops()
	tw.tween_property(_bust, "scale", Vector2(1.03, 1.03), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_bust, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _rays_spin() -> void:
	if _rays.rotation != 0.0:
		return
	var tw := create_tween()
	_tweens.append(tw)
	tw.set_loops()
	tw.tween_property(_rays, "rotation", TAU, 24.0)

## Fallback when victory_rays.png hasn't been generated yet: soft radial gold glow (brief §4).
func _fallback_glow() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.86, 0.35, 0.55))
	g.set_color(1, Color(1.0, 0.86, 0.35, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 512
	t.height = 512
	return t

func _burst(pos: Vector2, angle_deg: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 120
	p.lifetime = 2.2
	p.direction = Vector2.from_angle(deg_to_rad(angle_deg))
	p.spread = 35.0
	p.gravity = Vector2(0, 400)
	p.initial_velocity_min = 500.0
	p.initial_velocity_max = 1100.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 10.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	_tint_confetti(p)
	p.emitting = true
	_fx.add_child(p)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())

## Lazy top-edge confetti drizzle while the screen lives (brief §3).
func _drizzle() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(960, -20)
	p.amount = 26
	p.lifetime = 3.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(960, 4)
	p.direction = Vector2.DOWN
	p.spread = 12.0
	p.gravity = Vector2(0, 240)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 5.0
	p.scale_amount_max = 8.0
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	_tint_confetti(p)
	p.emitting = true
	_fx.add_child(p)

func _tint_confetti(p: CPUParticles2D) -> void:
	var g := Gradient.new()
	g.set_color(0, CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()])
	g.set_color(1, CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()])
	p.color_ramp = g
