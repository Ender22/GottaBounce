extends CanvasLayer
## VICTORY CEREMONY (match_ceremony brief §3). Brawl-only match-end screen replacing the old
## text panel: winner's charge-pose bust slams in over gold rays + confetti, "WINNER!" in gold,
## final standings in the ScoreScreen race-bar language, then a focused REMATCH / CHANGE SETUP /
## QUIT TO MENU prompt row. Interactive at ARM_TIME; accept before that FAST-FORWARDS every tween to its
## end state (never a black cut). PartyMatch presents it ~0.9s after the winning kill so the
## in-world punch-zoom breathes first; the screen owns all input while live and reports the
## player's choice through the three signals below. Data-driven (present(...)) so Sports can
## adopt it in a later slice. Terminal screen — the ≤3.4s between-stage pacing does not bind.
##
## WK-35 Toybox panel kit B: the FINAL SCORE tray is the ScoreScreen's cream ToyPanel (gold ToyRibbon header, ToyRow
## wells, ToyBarTrack race bars, chocolate numbers) and the identity grammar is WK-34 F1's (goat-colour ToyIdPill
## names; the winner's name ribbon is a goat-colour ToyNameRibbon). The winner's row is a gold ToyRowWinner well.
## Chocolate scrim (no navy). Confetti / focus-row juice come from ToyKit (shared with SportsVictory).
##
## WK-139 (UX4-06): one end-screen button kit with SportsVictory and the Trials end — unfocused buttons are the full-
## opacity cream ShellBtn (FocusRow, Tuning.end_btn_unfocused_alpha; they used to fade to a "disabled" grey over the
## scrim), and a shared glyph footer under the row ("A Select · B Quit", HintStrip device_ctx "menu": pad glyphs when
## a pad is joined, key caps when only the keyboard is, CC-1.6) makes the B -> QUIT shortcut (CC-10.1) discoverable.

signal rematch_pressed
signal setup_pressed
signal menu_pressed

const ToyKit := preload("res://src/ui/ToyKit.gd")
const FocusRow := preload("res://src/ui/FocusRow.gd")   # WK-14: one focus look (CC-5.1)
const GOLD := Color("#ffd23f")
const CHOCO := Color(0.231373, 0.141176, 0.105882)
const ARM_TIME := 1.1          # s from present() to interactive (absolute ~2.0 from the kill)
const BAR_PAD := 6.0
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
# WK-92(1): the winner's name sits on a ribbon (yellow PUFF straight over the gold rays was unreadable). WK-35: the
# ribbon is a goat-colour FILL with white type (kit F1 grammar). WK-88 (CC-8.5): NAME big + the small sub-tag.
@onready var _name_l: Control = $Root/NameL
@onready var _name_ribbon: PanelContainer = $Root/NameL/Ribbon
@onready var _name_text: Label = $Root/NameL/Ribbon/Box/NameText
@onready var _name_sub: Label = $Root/NameL/Ribbon/Box/SubText
@onready var _tray: PanelContainer = $Root/TrayArea/TrayCenter/Tray
@onready var _sub: Label = $Root/TrayArea/TrayCenter/Tray/Box/Sub
@onready var _rows_box: VBoxContainer = $Root/TrayArea/TrayCenter/Tray/Box/Rows
@onready var _template: PanelContainer = $Root/TrayArea/TrayCenter/Tray/Box/Rows/RowTemplate
@onready var _prompts: VBoxContainer = $Root/PromptArea   # WK-139: the button row + its glyph footer fade as one
@onready var _btns: Array = [$Root/PromptArea/Prompts/BtnRematch, $Root/PromptArea/Prompts/BtnSetup,
	$Root/PromptArea/Prompts/BtnMenu]

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
var _ff_done := false
# WK-11 (CC-10.2 / CC-3.3): fresh presses only, arm >= Tuning.end_screen_arm, joined devices only.
var _gate: MenuInputGate

func _ready() -> void:
	visible = false
	_gate = MenuInputGate.new()
	_gate.name = "InputGate"
	add_child(_gate)
	_gate.verb.connect(_on_verb)
	_gate.early.connect(_on_early)
	for i in range(_btns.size()):
		var idx := i
		(_btns[i] as Button).pressed.connect(func() -> void:
			if _armed:
				_activate(idx))

## winner: {skin:String, pn:int, label:int, name:String, sub:String, color:Color, human:bool}.
## rows: [{pn, name:String, sub:String, label:int, color:Color, skin, score:int, human:bool}]. pn = 1-based
## player index (row identity / winner match); name/sub = CC-8.5 identity (WK-88): "P3"+"POGO" / "VEX"+"CPU".
## (any order — sorted desc here). target: kills-to-win for the race bars.
func present(winner: Dictionary, rows: Array, target: int) -> void:
	visible = true
	_live = true
	_set_match_overlays_hidden(true)   # WK-42 (R-28): no combat HUD cards behind the ceremony
	_armed = false
	_ff_done = false
	_t = 0.0
	_focus = 0
	# the row arms when the prompts finish fading in, and never before Tuning.end_screen_arm (C-14)
	_gate.open(maxf(Tuning.end_screen_arm, ARM_TIME + 0.15))
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
	var wcol: Color = winner.get("color", Color.WHITE)
	# WK-35: white name + sub-tag on a goat-colour ribbon (colour is the fill, never the stroke)
	ToyKit.id_pill(_name_ribbon, _name_text, str(winner.get("name", "P%d" % int(winner.get("pn", 1)))), wcol)
	_name_sub.text = str(winner.get("sub", ""))
	_name_sub.visible = _name_sub.text != ""
	_sub.text = "FIRST TO %d KOs" % maxi(1, target)
	if ResourceLoader.exists(RAYS_PATH):
		_rays.texture = load(RAYS_PATH)
	else:
		_rays.texture = ToyKit.fallback_glow()
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
		ToyKit.burst(_fx, Vector2(220, 90), 55.0, CONFETTI_COLORS)
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
		ToyKit.burst(_fx, Vector2(1700, 90), 125.0, CONFETTI_COLORS))
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
	ToyKit.drizzle(_fx, CONFETTI_COLORS, 26)

# ------------------------------------------------------------------ rows (ScoreScreen recipe)

func _build_row(r: Dictionary, target: int, is_winner: bool) -> Dictionary:
	var row: PanelContainer = _template.duplicate()
	row.visible = true
	if is_winner:
		row.theme_type_variation = &"ToyRowWinner"   # WK-35: gold well, chocolate rim
	_rows_box.add_child(row)
	var color: Color = r["color"]
	var head: TextureRect = row.get_node("RowBox/Head")
	var head_path := "res://assets/characters/bouncer_%s_idle.png" % str(r["skin"])
	if ResourceLoader.exists(head_path):
		head.texture = load(head_path)
	# WK-88 (CC-8.5): "P3" / "VEX" — WK-35: the WK-34 F1 identity pill
	ToyKit.id_pill(row.get_node("RowBox/NameBox/NamePill"), row.get_node("RowBox/NameBox/NamePill/PName"),
		str(r.get("name", "P%d" % int(r["pn"]))), color)
	var sub_l: Label = row.get_node("RowBox/NameBox/PSub")
	sub_l.text = str(r.get("sub", ""))                        # small tag: goat name / "CPU"
	sub_l.visible = sub_l.text != ""
	var fill: Panel = row.get_node("RowBox/BarSlot/BarFill")
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = color
	fill_sb.set_corner_radius_all(8)
	fill.add_theme_stylebox_override("panel", fill_sb)
	var score_l: Label = row.get_node("RowBox/Score")
	score_l.text = "0"
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
	if not _armed and _gate.is_armed():
		_arm()

## Pre-arm press (fresh, joined device): accept FAST-FORWARDS the choreography — it never arms the row.
func _on_early(v: String, _key: String) -> void:
	if _live and not _armed and v == "accept" and _t > 0.05 and not _ff_done:
		_fast_forward()

## Armed, fresh press from a device allowed to drive this shared screen.
func _on_verb(v: String, _key: String) -> void:
	if not _live or not _armed:
		return
	match v:
		"left":
			_set_focus((_focus + _btns.size() - 1) % _btns.size())
		"right":
			_set_focus((_focus + 1) % _btns.size())
		"accept":
			_activate(_focus)
		"back":
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
	_pulse = FocusRow.row(self, _btns, i, _pulse)   # "press me" breath on the focused button

func _activate(i: int) -> void:
	AudioManager.play_sfx("ui_click")
	match i:
		0: rematch_pressed.emit()
		1: setup_pressed.emit()
		2: menu_pressed.emit()

## Accept during the choreography: land every element instantly (never a black cut). WK-11: it does NOT
## arm the row — the gate still waits (>= Tuning.end_screen_ff_rearm after this, >= end_screen_arm overall).
func _fast_forward() -> void:
	_ff_done = true
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
	_gate.delay_arm(Tuning.end_screen_ff_rearm)

func dismiss() -> void:
	if _live:
		_set_match_overlays_hidden(false)   # WK-42: REMATCH brings the corner cards back for the new match
	_live = false
	_armed = false
	_gate.close()
	for tw in _tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	for c in _fx.get_children():
		c.queue_free()
	visible = false

## WK-42 (R-28 / CC-8.4): the corner HUD cards (and the controls legend) hide while the ceremony is up — they showed
## through the scrim and the button row butted into the P3/P4 cards. Reuses the match's presentation-only overlay
## toggle (WK-80(f), INV-12; the same one Pause -> Options uses — pause is closed in MATCH_END, so they never nest).
func _set_match_overlays_hidden(hidden: bool) -> void:
	var host := get_parent()
	if host != null and host.has_method("set_match_overlays_hidden"):
		host.set_match_overlays_hidden(hidden)

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
