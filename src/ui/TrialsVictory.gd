extends CanvasLayer
## WK-142 (UX4-08): the TRIALS end is a celebration, not a dialog. Built from TrialsVictory.tscn + theme.tres and
## presented by TrialsHUD.show_match_end. It reuses the Brawl / Sports Victory juice (ToyKit confetti bursts +
## drizzle, the spinning victory rays, the slam + squash, the FocusRow button kit, the "A Select · B Quit" HintStrip):
##  - the cleared circuit's crest (the ArenaSelect card art) slams in over the rays, "CIRCUIT CLEAR!" in gold, the
##    circuit's name on a ribbon in its own colour, and "ALL N COURSES CLEARED" (binary: no times, no medals — v10 §5);
##  - the Herd: every participant's goat drops in, bleats (EventBus.bleated -> AudioManager, the goat's own voice) and
##    keeps hopping, with its CC-8.5 NAME pill (P# + goat name);
##  - default focus is NEXT CIRCUIT: <NAME> when course_sets.json has a next circuit (Trials circuits have no lock
##    gates, so there is no unlock reveal to show), then PLAY AGAIN · CHANGE SETUP · QUIT TO MENU. The last circuit
##    hides NEXT and focuses PLAY AGAIN.
## Input = the Victory screens' model: a MenuInputGate (fresh presses, joined devices only, CC-3.3 / CC-10.2), an early
## accept fast-forwards the choreography and never arms the row, B focuses QUIT then takes it (CC-10.1).
## Navigation: NEXT sits alone on the top row; up / down move NEXT <-> PLAY AGAIN (never into QUIT), left / right on NEXT
## deny (tick + wobble, CC-5.2). On the bottom row left / right wrap. Without a NEXT, up / down deny.

signal choice(id: StringName)   # &"next" / &"rematch" / &"setup" / &"menu"

const ToyKit := preload("res://src/ui/ToyKit.gd")
const FocusRow := preload("res://src/ui/FocusRow.gd")
const GOLD := Color("#ffd23f")
const CREAM := Color(1.0, 0.968627, 0.921569)
const RAYS_PATH := "res://assets/ui/victory_rays.png"
const IDS: Array[StringName] = [&"next", &"rematch", &"setup", &"menu"]
const I_NEXT := 0
const I_AGAIN := 1
const I_MENU := 3

@onready var _root: Control = $Root
@onready var _scrim: ColorRect = $Root/Scrim
@onready var _fx: Node2D = $Root/FX
@onready var _rays: TextureRect = $Root/Rays
@onready var _crest: TextureRect = $Root/Crest
@onready var _title_l: Label = $Root/TitleL
@onready var _name_l: Control = $Root/NameL
@onready var _ribbon: PanelContainer = $Root/NameL/Ribbon
@onready var _name_text: Label = $Root/NameL/Ribbon/NameText
@onready var _sub_l: Label = $Root/SubL
@onready var _herd: HBoxContainer = $Root/HerdC/Herd
@onready var _prompts: VBoxContainer = $Root/PromptArea
@onready var _next_row: HBoxContainer = $Root/PromptArea/NextRow
@onready var _iris: Panel = $Root/Iris
@onready var _btns: Array = [$Root/PromptArea/NextRow/BtnNext, $Root/PromptArea/Prompts/BtnAgain,
	$Root/PromptArea/Prompts/BtnSetup, $Root/PromptArea/Prompts/BtnMenu]

var _live := false
var _armed := false
var _ff_done := false
var _row_ready := false        # TrialsHUD.show_match_buttons arrived (the runner's own PROMPT_GUARD passed)
var _t := 0.0
var _focus := 0
var _has_next := false
var _next_id := ""
var _tweens: Array = []
var _pulse: Tween
var _slots: Array = []         # [{bust, shadow, pill, rest_y, idx}] for the visible herd slots
var _palette: Array = [GOLD]
var _gate: MenuInputGate
var activated := ""            # QA readout: the id of the last activated button

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
			if _armed and _gate.mouse_may_act():
				_activate(idx))
	_scrim.color.a = Tuning.trials_victory_scrim_alpha

func is_live() -> bool:
	return _live

func is_armed() -> bool:
	return _armed

## QA: the focused button's id.
func focused_id() -> StringName:
	return IDS[_focus]

## The NEXT circuit id this screen offers ("" = none).
func next_id() -> String:
	return _next_id

## data = {circuit: TrialsMode.circuit_info(), next: circuit_info() or {}, goats: [{idx, name, sub, color, skin}]}.
func present(data: Dictionary) -> void:
	visible = true
	_live = true
	_armed = false
	_ff_done = false
	_row_ready = false
	_t = 0.0
	activated = ""
	_kill_tweens()
	_gate.open(maxf(Tuning.end_screen_arm, Tuning.trials_victory_arm))
	var circ: Dictionary = data.get("circuit", {})
	var nxt: Dictionary = data.get("next", {})
	var ccol: Color = circ.get("color", GOLD)
	# --- crest + rays + headline ---
	var crest_path := str(circ.get("crest", ""))
	_crest.texture = load(crest_path) as Texture2D if crest_path != "" else null
	_crest.visible = _crest.texture != null
	_rays.texture = load(RAYS_PATH) as Texture2D if ResourceLoader.exists(RAYS_PATH) else ToyKit.fallback_glow()
	_rays.rotation = 0.0
	ToyKit.id_pill(_ribbon, _name_text, str(circ.get("name", "TRIALS")), ccol)
	var n := int(circ.get("courses", 0))
	_sub_l.text = "ALL %d COURSES CLEARED" % n if n > 1 else "COURSE CLEARED"
	# --- the Herd ---
	var goats: Array = data.get("goats", [])
	_palette = [ccol, ccol.lightened(0.4), GOLD, CREAM]
	for g in goats:
		_palette.append((g as Dictionary).get("color", GOLD))
	_build_herd(goats)
	# --- the button rows ---
	_has_next = not nxt.is_empty()
	_next_id = str(nxt.get("id", "")) if _has_next else ""
	_next_row.visible = _has_next
	if _has_next:
		(_btns[I_NEXT] as Button).text = "NEXT CIRCUIT: %s" % str(nxt.get("name", "")).to_upper()
	_focus = I_NEXT if _has_next else I_AGAIN
	for b: Button in _btns:
		FocusRow.style(b, false)
		b.scale = Vector2.ONE
	# --- start states ---
	_scrim.modulate.a = 0.0
	for c: Control in [_rays, _crest, _title_l, _name_l, _sub_l, _prompts]:
		c.modulate.a = 0.0
	_title_l.scale = Vector2(0.3, 0.3)
	_name_l.scale = Vector2(0.3, 0.3)
	_crest.scale = Vector2(1.8, 1.8)
	for s in _slots:
		var sl: Dictionary = s
		(sl["bust"] as Control).modulate.a = 0.0
		(sl["shadow"] as Control).modulate.a = 0.0
		(sl["pill"] as Control).modulate.a = 0.0
	await get_tree().process_frame   # herd + prompt layout before rest positions / pivots
	if not _live:
		return
	for s in _slots:
		var sl: Dictionary = s
		sl["rest_y"] = (sl["bust"] as Control).position.y
		(sl["bust"] as Control).position.y = float(sl["rest_y"]) + 240.0
		(sl["shadow"] as Control).position.y = float(sl["rest_y"]) + 250.0
		(sl["pill"] as Control).scale = Vector2(0.3, 0.3)
	for b: Button in _btns:
		b.pivot_offset = b.size * 0.5
	# --- choreography (the Victory screens' beats) ---
	var sc := _tw()
	sc.tween_property(_scrim, "modulate:a", 1.0, 0.25)
	var slam := _tw()
	slam.tween_interval(0.10)
	slam.tween_callback(func() -> void:
		AudioManager.play_sfx("smash_heavy")
		ToyKit.burst(_fx, Vector2(140, 120), 55.0, _palette)
		ToyKit.burst(_fx, Vector2(1780, 120), 125.0, _palette)
		_rays_spin())
	slam.tween_property(_crest, "modulate:a", 1.0, 0.08)
	slam.parallel().tween_property(_crest, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.parallel().tween_property(_rays, "modulate:a", 0.9, 0.35)
	slam.tween_property(_crest, "scale", Vector2(1.08, 0.92), 0.07)
	slam.tween_property(_crest, "scale", Vector2.ONE, 0.09)
	var tl := _tw()
	tl.tween_interval(0.25)
	tl.tween_callback(func() -> void: AudioManager.play_sfx("ui_click"))
	tl.tween_property(_title_l, "modulate:a", 1.0, 0.10)
	tl.parallel().tween_property(_title_l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var nl := _tw()
	nl.tween_interval(0.40)
	nl.tween_property(_name_l, "modulate:a", 1.0, 0.10)
	nl.parallel().tween_property(_name_l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	nl.tween_property(_sub_l, "modulate:a", 1.0, 0.15)
	for i in range(_slots.size()):
		var sl: Dictionary = _slots[i]
		var bust: Control = sl["bust"]
		var shadow: Control = sl["shadow"]
		var pill: Control = sl["pill"]
		var rest: float = sl["rest_y"]
		var gi: int = int(sl["idx"])
		var drop := _tw()
		drop.tween_interval(0.55 + 0.10 * float(i))
		drop.tween_property(bust, "modulate:a", 1.0, 0.06)
		drop.parallel().tween_property(shadow, "modulate:a", 0.85, 0.06)
		drop.parallel().tween_property(bust, "position:y", rest, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drop.parallel().tween_property(shadow, "position:y", rest + 10.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drop.tween_callback(func() -> void: EventBus.bleated.emit(gi, false))   # the goat's own bleat (AudioManager)
		drop.tween_property(bust, "scale", Vector2(1.1, 0.88), 0.07)
		drop.tween_property(bust, "scale", Vector2(0.96, 1.05), 0.06)
		drop.tween_property(bust, "scale", Vector2.ONE, 0.06)
		drop.parallel().tween_property(pill, "modulate:a", 1.0, 0.10)
		drop.parallel().tween_property(pill, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drop.tween_callback(_start_hop.bind(i))
	var pr := _tw()
	pr.tween_interval(maxf(Tuning.end_screen_arm, Tuning.trials_victory_arm) - 0.15)
	pr.tween_property(_prompts, "modulate:a", 1.0, 0.15)
	ToyKit.drizzle(_fx, _palette, 30)

## TrialsHUD.show_match_buttons: the runner's PROMPT_GUARD passed; the row may arm once our own gate is armed too.
func allow_row() -> void:
	_row_ready = true

func _build_herd(goats: Array) -> void:
	_slots.clear()
	var kids := _herd.get_children()
	for i in range(kids.size()):
		var slot: Control = kids[i]
		slot.visible = i < goats.size()
		if not slot.visible:
			continue
		var g: Dictionary = goats[i]
		var skin := str(g.get("skin", "pink"))
		var path := "res://assets/characters/bouncer_%s_idle.png" % skin
		var bust: TextureRect = slot.get_node("Bust")
		var shadow: TextureRect = slot.get_node("Shadow")
		if ResourceLoader.exists(path):
			bust.texture = load(path)
			shadow.texture = bust.texture
		# CC-8.5: NAME (P#) on a goat-colour pill + the small goat-name sub-tag
		var pill: PanelContainer = slot.get_node("PillC/Pill")
		ToyKit.id_pill(pill, slot.get_node("PillC/Pill/Box/Name"), str(g.get("name", "P%d" % (i + 1))), g.get("color", GOLD))
		var sub: Label = slot.get_node("PillC/Pill/Box/Sub")
		sub.text = str(g.get("sub", ""))
		sub.visible = sub.text != ""
		sub.modulate.a = 0.85
		bust.scale = Vector2.ONE
		_slots.append({"bust": bust, "shadow": shadow, "pill": slot.get_node("PillC"), "rest_y": bust.position.y,
			"idx": int(g.get("idx", i))})

## The cheering hop (SportsVictory's): jump, land with a squash, breathe, repeat — goats out of phase.
func _start_hop(i: int) -> void:
	if not _live or i >= _slots.size():
		return
	var sl: Dictionary = _slots[i]
	var bust: Control = sl["bust"]
	var shadow: Control = sl["shadow"]
	var rest: float = sl["rest_y"]
	var h: float = Tuning.trials_victory_hop
	var tw := _tw()
	tw.set_loops()
	tw.tween_interval(0.15 + 0.22 * float(i))
	tw.tween_property(bust, "scale", Vector2(1.06, 0.92), 0.08)
	tw.tween_property(bust, "position:y", rest - h, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bust, "scale", Vector2(0.96, 1.05), 0.12)
	tw.parallel().tween_property(shadow, "modulate:a", 0.45, 0.24)
	tw.tween_property(bust, "position:y", rest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(shadow, "modulate:a", 0.85, 0.22)
	tw.parallel().tween_property(bust, "scale", Vector2.ONE, 0.22)
	tw.tween_property(bust, "scale", Vector2(1.08, 0.9), 0.06)
	tw.tween_property(bust, "scale", Vector2.ONE, 0.10)
	tw.tween_interval(maxf(0.05, 0.75 - 0.22 * float(i)))

func _rays_spin() -> void:
	if _rays.rotation != 0.0:
		return
	var tw := _tw()
	tw.set_loops()
	tw.tween_property(_rays, "rotation", TAU, 24.0).from(0.0)

func _tw() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t

func _kill_tweens() -> void:
	for tw in _tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()

# ------------------------------------------------------------------ input (Victory screen model)

func _process(delta: float) -> void:
	if not _live:
		return
	_t += delta
	if not _armed and _row_ready and _gate.is_armed() and activated == "":
		_arm()

## Pre-arm press (fresh, joined device): accept fast-forwards the choreography; it never arms the row.
func _on_early(v: String, _key: String) -> void:
	if _live and not _armed and v == "accept" and _t > 0.05 and not _ff_done:
		_fast_forward()

func _on_verb(v: String, _key: String) -> void:
	if not _live or not _armed:
		return
	var on_next: bool = _focus == I_NEXT
	match v:
		"left":
			if on_next:
				_deny()   # NEXT is alone on its row
			else:
				_set_focus(I_MENU if _focus == I_AGAIN else _focus - 1)
		"right":
			if on_next:
				_deny()
			else:
				_set_focus(I_AGAIN if _focus == I_MENU else _focus + 1)
		"up", "down":
			if not _has_next:
				_deny()   # one row: nothing above / below
			else:
				# NEXT <-> PLAY AGAIN only: down from NEXT never lands on QUIT (no focus memory into the destructive end)
				_set_focus(I_AGAIN if on_next else I_NEXT)
		"accept":
			_activate(_focus)
		"back":
			# first back = focus the safe QUIT; second back = take it (CC-10.1)
			if _focus == I_MENU:
				_activate(I_MENU)
			else:
				_set_focus(I_MENU)

## CC-5.2 / CC-9.2: a direction with nowhere to go answers with the low click + the reject wobble.
func _deny() -> void:
	AudioManager.play_sfx("ui_click", {"pitch": 0.55, "pitch_var": 0.0, "volume_db": -6.0})
	MenuFX.reject_shake(_btns[_focus])

func _arm() -> void:
	_armed = true
	_set_focus(_focus)

func _set_focus(i: int) -> void:
	if i == I_NEXT and not _has_next:
		i = I_AGAIN
	if _focus != i and _armed:
		AudioManager.play_sfx("ui_click", {"pitch": 1.25, "volume_db": -8.0})
	_focus = i
	var row: Array = _btns if _has_next else _btns.slice(1)
	var fi: int = row.find(_btns[i])
	_pulse = FocusRow.row(self, row, fi, _pulse)

## One activation per screen life (two pads pressing A in one frame can't double-fire).
func _activate(i: int) -> void:
	if not _armed:
		return
	if i == I_NEXT and not _has_next:
		return
	_armed = false
	activated = str(IDS[i])
	AudioManager.play_sfx("ui_click")
	choice.emit(IDS[i])

## Accept during the choreography: land everything instantly (never a black cut); the gate re-arms later.
func _fast_forward() -> void:
	_ff_done = true
	_kill_tweens()
	_scrim.modulate.a = 1.0
	for c: Control in [_crest, _title_l, _name_l, _sub_l, _prompts]:
		c.modulate.a = 1.0
	_rays.modulate.a = 0.9
	_crest.scale = Vector2.ONE
	_title_l.scale = Vector2.ONE
	_name_l.scale = Vector2.ONE
	for s in _slots:
		var sl: Dictionary = s
		(sl["bust"] as Control).modulate.a = 1.0
		(sl["shadow"] as Control).modulate.a = 0.85
		(sl["bust"] as Control).position.y = float(sl["rest_y"])
		(sl["shadow"] as Control).position.y = float(sl["rest_y"]) + 10.0
		(sl["bust"] as Control).scale = Vector2.ONE
		(sl["pill"] as Control).modulate.a = 1.0
		(sl["pill"] as Control).scale = Vector2.ONE
	_rays.rotation = 0.0
	_rays_spin()
	for i in range(_slots.size()):
		_start_hop(i)
	_gate.delay_arm(Tuning.end_screen_ff_rearm)

## NEXT CIRCUIT: a cream iris covers the screen (ShellRoot's match-start grammar), then `cb` runs under cover.
func cover_then(cb: Callable) -> void:
	_iris.visible = true
	_iris.scale = Vector2.ZERO
	_iris.move_to_front()
	var t := create_tween()
	t.tween_property(_iris, "scale", Vector2(6.0, 6.0), maxf(0.05, Tuning.trials_victory_next_iris)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(cb)

func dismiss() -> void:
	_live = false
	_armed = false
	_gate.close()
	_kill_tweens()
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	for c in _fx.get_children():
		c.queue_free()
	_iris.visible = false
	visible = false
