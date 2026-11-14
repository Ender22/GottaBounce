extends MenuScreen
## THE HERD LOBBY — per-controller character select (BACKLOG WK-05/WK-06 · audit 2026-11-14 §E ·
## COUCH_CONVENTIONS CC-4.x). Replaces the old one-cursor / turn-based CharacterSelect.
##
## Every device (keyboard, each pad) presses A / Enter to JOIN its own panel, cycles its own goat with its
## own stick, locks (READY) independently and simultaneously. When everyone joined is READY (and the
## roster is valid for the mode) the "READY TO FIGHT!" banner slides in and any READY player presses
## A / Start to go on to ArenaSelect. The devices people joined with are written to MatchConfig, so each
## goat in the match is driven only by the device that picked it (WK-04 InputHuman.for_device).
##
## Input model (E.12): NO viewport focus. `_input` maps each event to its device with
## InputRouter.device_key(), routes it to that device's slot only, and marks it handled so Godot's
## built-in focus never sees it. Per-device D-pad / stick repeat with stick hysteresis (Tuning.lobby_*).
## Slot index = P-number (slot 0 = P1); a P3 in a lobby with an empty P2 is compacted to human index 1
## on proceed but keeps the "P3" label (MatchConfig.human_labels).

const MEDAL := preload("res://scenes/ui/RosterMedallion.tscn")
const PORTRAIT := "res://assets/ui/portraits/portrait_%s.png"
const SPRITE := "res://assets/characters/bouncer_%s_idle.png"

## The six goats (moved here from the deleted CharacterSelect). Order = roster ribbon order.
const HEROES := [
	{"id": "pogo", "name": "POGO", "skin": "pink", "color": Color("#ff5fa8"),
		"blurb": "Can't stop boinging. Won't stop boinging."},
	{"id": "butch", "name": "BUTCH", "skin": "blue", "color": Color("#4aa8ff"),
		"blurb": "Come at me. I've been stretching."},
	{"id": "ziggy", "name": "ZIGGY", "skin": "green", "color": Color("#54c94a"),
		"blurb": "Watch THIS recovery."},
	{"id": "puff", "name": "PUFF", "skin": "yellow", "color": Color("#ffc93f"),
		"blurb": "WHEEEE— wait which way?"},
	{"id": "vex", "name": "VEX", "skin": "purple", "color": Color("#a15fff"),
		"blurb": "You may bow now."},
	{"id": "billy", "name": "BILLY", "skin": "orange", "color": Color("#ff7a2d"),
		"blurb": "Back in MY day the mountain was TALLER."},
]
const MAX_SLOTS := 4
const S_EMPTY := "EMPTY"
const S_PICKING := "PICKING"
const S_READY := "READY"
const JOIN_PITCH := [1.0, 1.12, 1.26, 1.41]   # E.10: ui_join pitched by slot

@onready var _slot_views: Array = [$Slots/Slot1, $Slots/Slot2, $Slots/Slot3, $Slots/Slot4]
@onready var _roster: HBoxContainer = $Roster
@onready var _backdrop: Control = $StandaloneBackdrop
@onready var _back_btn: Button = $Header/BackBtn
@onready var _back_glyph: Control = $Header/BackBtn/Row/BackGlyph
@onready var _title: Label = $Header/Title
@onready var _banner: Control = $ReadyBanner
@onready var _banner_band: Panel = $ReadyBanner/Band
@onready var _banner_row: Control = $ReadyBanner/Band/Row
@onready var _banner_text: Label = $ReadyBanner/Band/Row/Text
@onready var _go_glyph: Control = $ReadyBanner/Band/Row/GoWrap/GoGlyph
@onready var _hint_banner: Control = $HintBanner
@onready var _hint_glyph: Control = $HintBanner/Band/Row/HintGlyph
@onready var _hint_text: Label = $HintBanner/Band/Row/HintText
@onready var _cpu_row: Control = $CpuRow
@onready var _cpu_tray: Control = $CpuRow/CpuTray
@onready var _cpu_chips: Array = [$CpuRow/CpuTray/Row/Cpu1, $CpuRow/CpuTray/Row/Cpu2, $CpuRow/CpuTray/Row/Cpu3]
@onready var _cpu_none: Label = $CpuRow/CpuTray/Row/NoCpu
@onready var _lb_glyph: Control = $CpuRow/CpuTray/Row/LBGlyph
@onready var _rb_glyph: Control = $CpuRow/CpuTray/Row/RBGlyph
@onready var _rules_row: Control = $RulesRow
@onready var _rules_text: Label = $RulesRow/RulesBar/Row/RulesText
@onready var _view_glyph: Control = $RulesRow/RulesBar/Row/ViewGlyph
@onready var _rules_modal: Control = $RulesModal
@onready var _rules_card: Control = $RulesModal/Card
@onready var _rules_title: Label = $RulesModal/Card/VBox/Title
@onready var _rules_rows: Array = [$RulesModal/Card/VBox/Row1, $RulesModal/Card/VBox/Row2, $RulesModal/Card/VBox/Row3]
@onready var _rules_done_glyph: Control = $RulesModal/Card/VBox/Hint/DoneGlyph
@onready var _unlock_banner: Label = $UnlockBanner
@onready var _f_join: Control = $Footer/HintRow/GJoin/Glyph
@onready var _f_back: Control = $Footer/HintRow/GBack/Glyph
@onready var _f_random: Control = $Footer/HintRow/GRandom/Glyph
@onready var _f_go: Control = $Footer/HintRow/GGo/Glyph
@onready var _f_hold: Control = $Footer/HintRow/GHold/Glyph

## Slot state (audit §E.2): {state, device, goat, flair, row}. The lobby is the ONLY writer; InputRouter's
## join registry mirrors it. Eval-readable for QA (`slots`, `banner_up`, `cpus()`).
var slots: Array = []
var banner_up := false
var hint_up := false
var _mode := "brawl"          # "brawl" | "sports" | "trials"
var _cpu_pref := 3            # BRAWL CPU preference; the tray shows cpus() = min(pref, 4 - humans)
var _sports_total := 2        # SPORTS format seats: 2 = 1V1, 4 = 2V2
var _medals: Array = []
var _flair_vals: Array = []   # "" (NONE), unlocked ids, "__locked" tease
var _flair_labels: Array = []
var _tex_cache := {}
var _pending_flair := ""

# input bookkeeping (all per device key)
var _holds := {}              # "<key>|h" / "<key>|v" -> {dir, src, t}  (repeat timers, msec)
var _stick := {}              # "<key>|h" / "<key>|v" -> -1/0/1 (hysteresis latch)
var _hold_b := {}             # key -> press msec (hold-B exit)
var _hold_ticks := 0
var _lock_queue: Array = []   # slot indices that pressed lock THIS frame (tie-break: lower slot wins)
var _spinning: Array = [false, false, false, false]
var _spin_tw: Array = [null, null, null, null]
var _banner_since := 0
var _banner_tw: Tween
var _hint_tw: Tween
var _breathe_tw: Tween
var _enter_msec := 0
var _launching := false
var _leaving := false
var _rules_owner := ""
var _rules_row_i := 0
var _rules_defs: Array = []

# ================================================================== lifecycle
func _ready() -> void:
	var cfg: MatchConfig = GameConfig.match_config
	if cfg != null and cfg.mode_id == &"trials":
		_mode = "trials"
	elif cfg != null and SportsMode.is_sports_mode(cfg.mode_id):
		_mode = "sports"
	else:
		_mode = "brawl"
	for i in range(MAX_SLOTS):
		slots.append(_empty_slot())
	# roster ribbon: one medallion per goat (instanced from the scene — data-driven, not a widget wall)
	for g in range(HEROES.size()):
		var m: Control = MEDAL.instantiate()
		_roster.add_child(m)
		var h: Dictionary = HEROES[g]
		(m as Object).call("setup", g, h["color"], _portrait(g))
		_medals.append(m)
	for i in range(MAX_SLOTS):
		(_slot_views[i] as Object).call("setup_slot", i, _idle_tex(str((HEROES[i] as Dictionary)["skin"])))
	_build_flair_vals()
	_pending_flair = Settings.take_pending_flair_unlock()
	_back_btn.pressed.connect(_exit)
	InputRouter.last_device_changed.connect(func(_k: String) -> void: _refresh_glyphs())
	InputRouter.device_lost.connect(_on_device_lost)
	# CPU / format seeds: lobby memory first, else the match config (CHANGE SETUP keeps them)
	if GameConfig.lobby_cpus >= 0:
		_cpu_pref = GameConfig.lobby_cpus
	elif cfg != null:
		_cpu_pref = clampi(cfg.bot_count, 0, MatchConfig.MAX_FIGHTERS - 1)
	if GameConfig.lobby_sports_total > 0:
		_sports_total = GameConfig.lobby_sports_total
	elif cfg != null:
		_sports_total = 4 if (cfg.human_count + cfg.bot_count) >= 4 else 2
	_apply_mode_chrome()
	# launched directly (QA: WK-05 "launch the scene directly") — no shell will call setup()/enter()
	call_deferred("_standalone_boot")

func setup(shell_ref) -> void:
	super.setup(shell_ref)
	_backdrop.visible = false

func _standalone_boot() -> void:
	if shell != null or _entered:
		return
	_backdrop.visible = true
	enter()

func first_focus() -> Control:
	return null   # no viewport focus on this screen (E.12)

func stagger_items() -> Array:
	return _medals   # roster ribbon pops in; panels animate themselves (join motion) so they aren't staggered

func enter() -> void:
	get_viewport().gui_release_focus()
	_restore_lobby()
	super.enter()
	_enter_msec = Time.get_ticks_msec()
	_refresh_all(false)
	if _pending_flair != "":
		_play_flair_celebration(_pending_flair)
		_pending_flair = ""

## Lobby memory (GameConfig.lobby, E.2): restore who is joined, on which device, with which goat. Coming
## FORWARD from ModeSelect un-readies everyone (new mode, new decision); coming BACK from ArenaSelect keeps
## READY (CC-4.7). Then CC-4.8: if nobody is joined, auto-join the device that confirmed the mode card.
func _restore_lobby() -> void:
	var forward := true
	if shell != null and "nav_forward" in shell:
		forward = bool(shell.nav_forward)
	InputRouter.clear_joined()
	var saved: Array = GameConfig.lobby
	if saved.size() == MAX_SLOTS:
		for i in range(MAX_SLOTS):
			var d: Variant = saved[i]
			if typeof(d) != TYPE_DICTIONARY:
				continue
			var sd: Dictionary = d
			var st := str(sd.get("state", S_EMPTY))
			var dev := str(sd.get("device", ""))
			if st == S_EMPTY or InputRouter.kind_of(dev) == "":
				continue
			if forward and st == S_READY:
				st = S_PICKING
			slots[i] = {"state": st, "device": dev, "goat": clampi(int(sd.get("goat", 0)), 0, HEROES.size() - 1),
				"flair": str(sd.get("flair", "")), "row": 0}
			InputRouter.join(dev, i)
	for i in range(MAX_SLOTS):
		var s: Dictionary = slots[i]
		if s["state"] == S_EMPTY:
			(_slot_views[i] as Object).call("show_empty", true, false)
		else:
			(_slot_views[i] as Object).call("show_join", str(s["device"]), HEROES[int(s["goat"])], _portrait(int(s["goat"])))
			(_slot_views[i] as Object).call("set_ready", s["state"] == S_READY, false)
			_push_flair_view(i)
			(_slot_views[i] as Object).call("set_row", 0)
	var auto_key: String = GameConfig.lobby_autojoin_key
	GameConfig.lobby_autojoin_key = ""
	if _joined_count() == 0 and InputRouter.kind_of(auto_key) != "":
		_join(auto_key, false)

func _persist() -> void:
	var out: Array = []
	for s in slots:
		out.append({"state": s["state"], "device": s["device"], "goat": s["goat"], "flair": s["flair"]})
	GameConfig.lobby = out
	GameConfig.lobby_cpus = _cpu_pref
	GameConfig.lobby_sports_total = _sports_total

func _empty_slot() -> Dictionary:
	return {"state": S_EMPTY, "device": "", "goat": 0, "flair": "", "row": 0}

# ================================================================== input routing (E.4 / E.12)
func _input(e: InputEvent) -> void:
	var key: String = InputRouter.device_key(e)
	if key == "":
		return   # mouse: the BACK button stays clickable; nothing else listens to the mouse
	get_viewport().set_input_as_handled()   # the lobby owns every key / pad event (no focus graph)
	if not _entered or _launching or _leaving:
		return
	if e is InputEventKey and (e as InputEventKey).echo:
		return   # we run our own per-device repeat
	if Time.get_ticks_msec() - _enter_msec < int(Tuning.lobby_entry_grace * 1000.0):
		return
	if e is InputEventJoypadMotion:
		_on_stick(key, e as InputEventJoypadMotion)
		return
	if not e.is_pressed():
		_on_release(key, e)
		return
	_on_press(key, e)

## One verb per pressed button event, from the ACTION MAP (never raw keycodes).
func _verb(e: InputEvent) -> String:
	if e is InputEventJoypadButton and e.is_action_pressed("menu_start"):
		return "start"
	if e.is_action_pressed("menu_accept") or e.is_action_pressed("ui_accept"):
		return "accept"
	if e.is_action_pressed("menu_back"):
		return "back"
	if e.is_action_pressed("menu_random"):
		return "random"
	if e.is_action_pressed("menu_page_prev"):
		return "cpu_prev"
	if e.is_action_pressed("menu_page_next"):
		return "cpu_next"
	if e.is_action_pressed("menu_view"):
		return "view"
	return ""

## D-pad / arrows / WASD as a digital direction (stick motion is handled separately with hysteresis).
func _digital_dir(e: InputEvent, pressed: bool) -> Vector2i:
	var f := func(a: String) -> bool:
		return e.is_action_pressed(a) if pressed else e.is_action_released(a)
	if f.call("ui_left") or f.call("move_left"):
		return Vector2i(-1, 0)
	if f.call("ui_right") or f.call("move_right"):
		return Vector2i(1, 0)
	if f.call("ui_up") or f.call("move_up"):
		return Vector2i(0, -1)
	if f.call("ui_down") or f.call("move_down"):
		return Vector2i(0, 1)
	return Vector2i.ZERO

func _on_press(key: String, e: InputEvent) -> void:
	var dir: Vector2i = _digital_dir(e, true)
	var verb := "" if dir != Vector2i.ZERO else _verb(e)
	# RULES modal (E.7): only its owner drives it; other devices keep playing their own panels
	if _rules_owner != "":
		if key == _rules_owner:
			if dir != Vector2i.ZERO:
				_press_dir(key, dir, "dig")
			elif verb in ["back", "view", "accept", "start"]:
				_close_rules()
			return
		if verb == "view":
			_deny_device(key)
			return
	if dir != Vector2i.ZERO:
		_press_dir(key, dir, "dig")
		return
	var si := _slot_of(key)
	match verb:
		"accept":
			if si < 0:
				_join(key, true)
			else:
				_on_accept(si)
		"start":
			if si < 0:
				_join(key, true)
			elif slots[si]["state"] == S_READY:
				_try_proceed()
			else:
				_soft_tick()
		"back":
			_on_back_press(key, si)
		"random":
			if si >= 0:
				_random_pick(si)
		"cpu_prev":
			if si >= 0:
				_cpu_step(-1)
		"cpu_next":
			if si >= 0:
				_cpu_step(1)
		"view":
			if si >= 0:
				_open_rules(key, si)

func _on_release(key: String, e: InputEvent) -> void:
	if e.is_action_released("menu_back"):
		_hold_b.erase(key)
	var d: Vector2i = _digital_dir(e, false)
	if d != Vector2i.ZERO:
		_release_dir(key, "h" if d.x != 0 else "v", "dig")

## Left stick with hysteresis (press >= lobby_stick_press, release < lobby_stick_release), per device.
func _on_stick(key: String, e: InputEventJoypadMotion) -> void:
	if e.is_action("move_left") or e.is_action("move_right"):
		_stick_axis(key, "h", e.get_action_strength("move_right") - e.get_action_strength("move_left"))
	elif e.is_action("move_up") or e.is_action("move_down"):
		_stick_axis(key, "v", e.get_action_strength("move_down") - e.get_action_strength("move_up"))

func _stick_axis(key: String, axis: String, v: float) -> void:
	var k := key + "|" + axis
	var cur: int = int(_stick.get(k, 0))
	var a := absf(v)
	var sgn: int = 1 if v > 0.0 else -1
	if cur != 0 and (a < Tuning.lobby_stick_release or sgn != cur):
		_stick[k] = 0
		_release_dir(key, axis, "stick")
		cur = 0
	if cur == 0 and a >= Tuning.lobby_stick_press:
		_stick[k] = sgn
		_press_dir(key, Vector2i(sgn, 0) if axis == "h" else Vector2i(0, sgn), "stick")

func _press_dir(key: String, d: Vector2i, src: String) -> void:
	var axis := "h" if d.x != 0 else "v"
	var dv: int = d.x if d.x != 0 else d.y
	_holds[key + "|" + axis] = {"key": key, "axis": axis, "dir": dv, "src": src,
		"t": Time.get_ticks_msec() + int(Tuning.lobby_repeat_delay * 1000.0)}
	_step_dir(key, axis, dv)

func _release_dir(key: String, axis: String, src: String) -> void:
	var k := key + "|" + axis
	if _holds.has(k) and str((_holds[k] as Dictionary)["src"]) == src:
		_holds.erase(k)

func _process(_delta: float) -> void:
	if not _entered:
		return
	var now := Time.get_ticks_msec()
	# per-device direction repeat (C-21 lobby half)
	for k in _holds.keys():
		var h: Dictionary = _holds[k]
		if now >= int(h["t"]):
			h["t"] = int(h["t"]) + int(Tuning.lobby_repeat_rate * 1000.0)
			_step_dir(str(h["key"]), str(h["axis"]), int(h["dir"]))
	# same-frame lock ties resolve here, after every event of the frame was routed
	if not _lock_queue.is_empty():
		_resolve_locks()
	_tick_hold_b(now)

# ================================================================== slot actions
func _slot_of(key: String) -> int:
	for i in range(MAX_SLOTS):
		if slots[i]["state"] != S_EMPTY and slots[i]["device"] == key:
			return i
	return -1

func _joined_count() -> int:
	var n := 0
	for s in slots:
		if s["state"] != S_EMPTY:
			n += 1
	return n

## EMPTY -> PICKING for an unassigned device: lowest EMPTY slot; goat = first goat no other joined human
## is on (E.4). Full lobby = deny.
func _join(key: String, sound: bool) -> void:
	if _launching:
		return
	var si := -1
	for i in range(MAX_SLOTS):
		if slots[i]["state"] == S_EMPTY:
			si = i
			break
	if si < 0:
		_deny_sound()
		MenuFX.reject_shake($Slots)
		return
	var used: Array = []
	for i in range(MAX_SLOTS):
		if slots[i]["state"] != S_EMPTY:
			used.append(int(slots[i]["goat"]))
	var g := 0
	for c in range(HEROES.size()):
		if not used.has(c):
			g = c
			break
	var fl := ""
	if si == 0 and Settings.equipped_flair != "" and _flair_vals.has(Settings.equipped_flair):
		fl = Settings.equipped_flair   # P-slot 0's flair persists to Settings (E.2)
	slots[si] = {"state": S_PICKING, "device": key, "goat": g, "flair": fl, "row": 0}
	InputRouter.join(key, si)
	_clear_device_input(key)
	var v: Object = _slot_views[si]
	v.call("show_join", key, HEROES[g], _portrait(g))
	_push_flair_view(si)
	v.call("set_row", 0)
	if sound:
		AudioManager.play_sfx("powerup_pickup", {"pitch": JOIN_PITCH[si], "pitch_var": 0.0, "volume_db": -4.0})
	_after_change()

func _leave(si: int) -> void:
	var dev := str(slots[si]["device"])
	_stop_spin(si)
	slots[si] = _empty_slot()
	InputRouter.leave(dev)
	_clear_device_input(dev)
	(_slot_views[si] as Object).call("show_empty", not _kb_joined(), true)
	AudioManager.play_sfx("ui_click", {"pitch": 0.6, "pitch_var": 0.0, "volume_db": -4.0})
	_after_change()

func _on_accept(si: int) -> void:
	var s: Dictionary = slots[si]
	if s["state"] == S_PICKING:
		if _spinning[si]:
			return
		if not _lock_queue.has(si):
			_lock_queue.append(si)
	elif s["state"] == S_READY:
		_try_proceed()

## PICKING -> READY for every slot that pressed lock this frame. Lower slot first, so if two humans lock
## the same goat in the same frame the lower slot wins and the other gets the deny shake (E.4).
func _resolve_locks() -> void:
	var q: Array = _lock_queue.duplicate()
	_lock_queue.clear()
	q.sort()
	for si in q:
		var s: Dictionary = slots[si]
		if s["state"] != S_PICKING:
			continue
		var g: int = int(s["goat"])
		if _locked_by_other(g, si) >= 0:
			(_slot_views[si] as Object).call("deny")
			(_medals[g] as Object).call("wiggle")
			_deny_sound()
			continue
		s["state"] = S_READY
		(_slot_views[si] as Object).call("set_ready", true, true)
		AudioManager.play_sfx("super_fire", {"volume_db": -12.0, "pitch": 1.25, "pitch_var": 0.05})
	_after_change()

## B: READY -> PICKING -> EMPTY (CC-4.3). Every B press also starts the hold-to-exit ring. A tap with
## nobody joined backs straight out; with people joined, leaving needs the hold (CC-6.2).
func _on_back_press(key: String, si: int) -> void:
	_hold_b[key] = Time.get_ticks_msec()
	_hold_ticks = 0
	if si >= 0:
		var s: Dictionary = slots[si]
		if s["state"] == S_READY:
			s["state"] = S_PICKING
			(_slot_views[si] as Object).call("set_ready", false, true)
			AudioManager.play_sfx("ui_click", {"pitch": 0.72, "pitch_var": 0.0, "volume_db": -4.0})
			_after_change()
		else:
			_leave(si)
	elif _joined_count() == 0:
		_exit()

func _tick_hold_b(now: int) -> void:
	var best := 0.0
	for k in _hold_b.keys():
		best = maxf(best, float(now - int(_hold_b[k])) / (Tuning.lobby_hold_exit * 1000.0))
	var shown: float = best if best * Tuning.lobby_hold_exit >= Tuning.lobby_hold_ring_show else 0.0
	_back_glyph.set("ring", shown)
	_f_hold.set("ring", shown)
	if shown > 0.0:
		var ticks: int = int(best / 0.2)
		if ticks > _hold_ticks:
			_hold_ticks = ticks
			AudioManager.play_sfx("ui_click", {"pitch": 0.9 + 0.12 * ticks, "pitch_var": 0.0, "volume_db": -10.0})
	if best >= 1.0:
		_hold_b.clear()
		_exit()

func _step_dir(key: String, axis: String, dir: int) -> void:
	if _rules_owner != "" and key == _rules_owner:
		_rules_step(axis, dir)
		return
	var si := _slot_of(key)
	if si < 0:
		return
	var s: Dictionary = slots[si]
	if s["state"] != S_PICKING or _spinning[si]:
		return
	if axis == "v":
		var nr: int = clampi(int(s["row"]) + dir, 0, 1)
		if nr != int(s["row"]):
			s["row"] = nr
			(_slot_views[si] as Object).call("set_row", nr)
			_move_sound()
		return
	if int(s["row"]) == 0:
		_cycle_goat(si, dir)
	else:
		_cycle_flair(si, dir)

## Cycle (wraps), skipping goats LOCKED by another human; each skipped goat's medallion wiggles. Two
## PICKING players may browse the same goat (E.4).
func _cycle_goat(si: int, dir: int) -> void:
	var s: Dictionary = slots[si]
	var g: int = int(s["goat"])
	for _n in range(HEROES.size()):
		g = posmod(g + dir, HEROES.size())
		if _locked_by_other(g, si) >= 0:
			(_medals[g] as Object).call("wiggle")
			continue
		break
	if g == int(s["goat"]):
		return
	s["goat"] = g
	(_slot_views[si] as Object).call("show_goat", HEROES[g], _portrait(g), dir)
	_move_sound()
	_after_change()

func _locked_by_other(g: int, si: int) -> int:
	for i in range(MAX_SLOTS):
		if i != si and slots[i]["state"] == S_READY and int(slots[i]["goat"]) == g:
			return i
	return -1

## Y / R: the portrait spins through the free goats for lobby_random_spin s and lands; stays PICKING.
func _random_pick(si: int) -> void:
	var s: Dictionary = slots[si]
	if s["state"] != S_PICKING or _spinning[si]:
		return
	_spinning[si] = true
	var steps := 8
	var dt: float = Tuning.lobby_random_spin / float(steps)
	var tw := create_tween()
	for n in range(steps):
		tw.tween_callback(_spin_step.bind(si))
		tw.tween_interval(dt)
	tw.tween_callback(func() -> void:
		_spinning[si] = false
		if slots[si]["state"] == S_PICKING:
			var g: int = int(slots[si]["goat"])
			(_slot_views[si] as Object).call("show_goat", HEROES[g], _portrait(g), 1)
			AudioManager.play_sfx("ui_click", {"pitch": 1.1, "pitch_var": 0.0, "volume_db": -4.0})
		_after_change())
	_spin_tw[si] = tw

func _spin_step(si: int) -> void:
	var free: Array = []
	for g in range(HEROES.size()):
		if g != int(slots[si]["goat"]) and _locked_by_other(g, si) < 0:
			free.append(g)
	if free.is_empty():
		return
	var g: int = free[randi() % free.size()]
	slots[si]["goat"] = g
	(_slot_views[si] as Object).call("show_goat", HEROES[g], _portrait(g), 1)
	AudioManager.play_sfx("ui_click", {"pitch": 1.4, "pitch_var": 0.0, "volume_db": -14.0})

func _stop_spin(si: int) -> void:
	var tw: Variant = _spin_tw[si]
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	_spin_tw[si] = null
	_spinning[si] = false

# ------------------------------------------------------------------ flair row (E.4 FLAIR row)
func _build_flair_vals() -> void:
	_flair_vals = [""]
	_flair_labels = ["NONE"]
	for it in Settings.flair_items():
		var fid := str((it as Dictionary).get("id", ""))
		if Settings.is_flair_unlocked(fid):
			_flair_vals.append(fid)
			# "TITLE: PEAK MENACE" -> "PEAK MENACE" (the row already says FLAIR; keeps it readable at 26px)
			_flair_labels.append(str((it as Dictionary).get("name", fid)).trim_prefix("TITLE: "))
	var nxt: Dictionary = Settings.next_locked_flair()
	if not nxt.is_empty():
		_flair_vals.append("__locked")
		_flair_labels.append("NEXT AT %d KOs" % int(nxt.get("threshold", 0)))   # locked tease, greyed

func _cycle_flair(si: int, dir: int) -> void:
	var s: Dictionary = slots[si]
	var idx: int = maxi(0, _flair_vals.find(str(s.get("flair_view", s["flair"]))))
	idx = posmod(idx + dir, _flair_vals.size())
	var v := str(_flair_vals[idx])
	s["flair_view"] = v
	if v != "__locked":
		s["flair"] = v   # the locked tease is visible but never equippable
		if si == 0:
			Settings.set_equipped_flair(v)
	(_slot_views[si] as Object).call("flair_nudge", dir)
	_push_flair_view(si)
	_move_sound()
	_persist()

func _push_flair_view(si: int) -> void:
	var s: Dictionary = slots[si]
	var v := str(s.get("flair_view", s["flair"]))
	var idx: int = maxi(0, _flair_vals.find(v))
	(_slot_views[si] as Object).call("set_flair", str(_flair_labels[idx]), v == "__locked")

# ------------------------------------------------------------------ CPUs (BRAWL, E.4 LB/RB)
## CPUs actually in the match: the preference clamped to the 4-fighter cap (WK-02). A lobby the player
## filled stays full as humans join and leave.
func cpus() -> int:
	var humans: int = maxi(1, _joined_count())
	return clampi(_cpu_pref, 0, MatchConfig.max_bots_for(humans))

func _cpu_step(d: int) -> void:
	if _mode != "brawl":
		return
	var n: int = cpus() + d
	if n < 0 or n > MatchConfig.max_bots_for(maxi(1, _joined_count())):
		MenuFX.reject_shake(_cpu_tray)
		_deny_sound()
		return
	_cpu_pref = n
	MenuFX.value_pop(_rb_glyph if d > 0 else _lb_glyph, 1.2)
	AudioManager.play_sfx("ui_click", {"pitch": 1.2 if d > 0 else 0.9, "pitch_var": 0.0, "volume_db": -6.0})
	_after_change()

## The skins the CPUs will wear — the exact BrawlMode._bot_skin rule (first SKIN_ROSTER skin no human
## or earlier bot uses), so the tray previews the real match.
func _cpu_skins(n: int) -> Array:
	var used: Array = []
	for s in slots:
		if s["state"] != S_EMPTY:
			used.append(str((HEROES[int(s["goat"])] as Dictionary)["skin"]))
	var out: Array = []
	for _b in range(n):
		var pick := ""
		for sk in BrawlMode.SKIN_ROSTER:
			if not used.has(sk):
				pick = sk
				break
		if pick == "":
			pick = BrawlMode.SKIN_ROSTER[0]
		used.append(pick)
		out.append(pick)
	return out

# ------------------------------------------------------------------ proceed (E.5)
## "" = not ready · "need_cpu" = 1 READY human, 0 CPUs in BRAWL (amber hint) · "valid" = banner.
func roster_state() -> String:
	var joined := 0
	for s in slots:
		if s["state"] == S_EMPTY:
			continue
		if s["state"] != S_READY:
			return ""
		joined += 1
	if joined == 0:
		return ""
	if _mode == "brawl" and joined + cpus() < 2:
		return "need_cpu"
	return "valid"

func _try_proceed() -> void:
	if not banner_up:
		_soft_tick()
		return
	if Time.get_ticks_msec() - _banner_since < int(Tuning.lobby_banner_guard * 1000.0):
		return   # E.5 double-tap guard: the banner must be up >= 0.35 s
	_proceed()

## Compact joined slots in slot order into MatchConfig (E.2) and move on to ArenaSelect.
func _proceed() -> void:
	if _launching:
		return
	var cfg: MatchConfig = GameConfig.match_config
	var devs := PackedStringArray()
	var labels := PackedInt32Array()
	var skins := PackedStringArray()
	var chars := PackedStringArray()
	var flairs := PackedStringArray()
	for i in range(MAX_SLOTS):
		var s: Dictionary = slots[i]
		if s["state"] == S_EMPTY:
			continue
		devs.append(str(s["device"]))
		labels.append(i + 1)
		skins.append(str((HEROES[int(s["goat"])] as Dictionary)["skin"]))
		chars.append("bouncer")
		flairs.append(str(s["flair"]))
	cfg.human_count = devs.size()
	cfg.human_devices = devs
	cfg.human_labels = labels
	cfg.skin_ids = skins
	cfg.character_ids = chars
	cfg.flair_ids = flairs
	match _mode:
		"brawl":
			cfg.bot_count = cpus()
		"sports":
			var total: int = _sports_total if cfg.human_count <= _sports_total else 4
			cfg.bot_count = maxi(0, total - cfg.human_count)
		_:
			cfg.bot_count = 0
	_persist()
	_launching = true
	AudioManager.play_sfx("ui_click", {"pitch": 1.3, "pitch_var": 0.0, "volume_db": 0.0})
	if shell != null:
		shell.go_forward("arena")

func _exit() -> void:
	if _leaving or _launching:
		return
	_leaving = true
	_persist()
	AudioManager.play_sfx("ui_click", {"pitch": 0.72, "pitch_var": 0.0, "volume_db": -4.0})
	if shell != null:
		shell.go_back()
	else:
		_leaving = false   # standalone QA launch: nowhere to go back to

# ------------------------------------------------------------------ RULES (minimal E.7 — WK-07 finishes)
## View / Tab from a joined device opens a small RULES card owned by that device: Up/Down picks a row,
## Left/Right changes it (commits immediately), B / View / A closes. This keeps CPU SKILL / KOs / LIVES
## (Brawl) and FORMAT (Sports) settable now that the old stepper tray is gone. WK-07 replaces it with the
## full Stepper modal (A commits / B reverts, per-mode memory, "P2 IS SETTING RULES" chip).
func _open_rules(key: String, si: int) -> void:
	if _mode == "trials":
		_deny_device(key)
		return
	var cfg: MatchConfig = GameConfig.match_config
	if _mode == "brawl":
		_rules_defs = [
			{"title": "CPU SKILL", "labels": ["MIX", "1", "2", "3", "4", "5"], "vals": [0, 1, 2, 3, 4, 5], "field": "bot_difficulty"},
			{"title": "KOs TO WIN", "labels": ["5", "7", "8", "10"], "vals": [5, 7, 8, 10], "field": "kills_to_win"},
			{"title": "LIVES", "labels": ["1", "2", "3"], "vals": [1, 2, 3], "field": "lives_per_player"},
		]
	else:
		_rules_defs = [
			{"title": "FORMAT", "labels": ["1V1", "2V2"], "vals": [2, 4], "field": "_sports_total"},
			{"title": "CPU SKILL", "labels": ["MIX", "1", "2", "3", "4", "5"], "vals": [0, 1, 2, 3, 4, 5], "field": "bot_difficulty"},
		]
	_rules_owner = key
	_rules_row_i = 0
	_clear_device_input(key)
	_rules_title.text = "RULES · P%d" % (si + 1)
	(_rules_done_glyph as Object).call("setup", "key:ESC" if key == "kb" else "B")
	_refresh_rules_modal()
	_rules_modal.visible = true
	_rules_card.scale = Vector2(0.85, 0.85)
	_rules_card.modulate.a = 0.0
	var t := _rules_card.create_tween()
	t.set_parallel(true)
	t.tween_property(_rules_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_rules_card, "modulate:a", 1.0, 0.15)
	AudioManager.play_sfx("ui_click", {"pitch": 1.2, "pitch_var": 0.0, "volume_db": -4.0})

func _close_rules() -> void:
	_clear_device_input(_rules_owner)
	_rules_owner = ""
	_rules_modal.visible = false
	AudioManager.play_sfx("ui_click", {"pitch": 0.9, "pitch_var": 0.0, "volume_db": -4.0})
	_after_change()

func _rule_value(def: Dictionary) -> int:
	var f := str(def["field"])
	if f == "_sports_total":
		return _sports_total if _joined_count() <= 2 else 4
	return int(GameConfig.match_config.get(f))

func _rules_step(axis: String, dir: int) -> void:
	if axis == "v":
		_rules_row_i = posmod(_rules_row_i + dir, _rules_defs.size())
		_move_sound()
		_refresh_rules_modal()
		return
	var def: Dictionary = _rules_defs[_rules_row_i]
	var vals: Array = def["vals"]
	var idx: int = maxi(0, vals.find(_rule_value(def)))
	var ni: int = idx + dir
	var row: Control = _rules_rows[_rules_row_i]
	var locked_format: bool = str(def["field"]) == "_sports_total" and _joined_count() > 2
	if ni < 0 or ni >= vals.size() or locked_format:
		MenuFX.reject_shake(row)
		_deny_sound()
		return
	var f := str(def["field"])
	if f == "_sports_total":
		_sports_total = int(vals[ni])
	else:
		GameConfig.match_config.set(f, int(vals[ni]))
	((row.get_node("ChevR") if dir > 0 else row.get_node("ChevL")) as Object).call("nudge")
	AudioManager.play_sfx("ui_click", {"pitch": 1.15, "pitch_var": 0.0, "volume_db": -6.0})
	_refresh_rules_modal()
	MenuFX.value_pop(row.get_node("Value") as Control, 1.2)
	_refresh_rules_bar()
	_persist()

func _refresh_rules_modal() -> void:
	for i in range(_rules_rows.size()):
		var row: Panel = _rules_rows[i]
		row.visible = i < _rules_defs.size()
		if not row.visible:
			continue
		var def: Dictionary = _rules_defs[i]
		(row.get_node("Title") as Label).text = str(def["title"])
		var vals: Array = def["vals"]
		var idx: int = maxi(0, vals.find(_rule_value(def)))
		(row.get_node("Value") as Label).text = str((def["labels"] as Array)[idx])
		var on: bool = i == _rules_row_i
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.82, 0.25, 0.18) if on else Color(1, 1, 1, 0.06)
		sb.border_color = Color("#ffd23f") if on else Color(1, 1, 1, 0.12)
		sb.set_border_width_all(5 if on else 3)
		sb.set_corner_radius_all(16)
		row.add_theme_stylebox_override("panel", sb)
		(row.get_node("ChevL") as Control).visible = on
		(row.get_node("ChevR") as Control).visible = on

# ================================================================== refresh / presentation
func _after_change() -> void:
	_refresh_all(true)
	_persist()

func _refresh_all(animate: bool) -> void:
	_refresh_taken()
	_refresh_medals()
	_refresh_cpu_tray()
	_refresh_rules_bar()
	_refresh_empty_hints()
	_refresh_glyphs()
	_refresh_banner(animate)

func _refresh_taken() -> void:
	for i in range(MAX_SLOTS):
		var s: Dictionary = slots[i]
		var by := -1
		if s["state"] == S_PICKING:
			by = _locked_by_other(int(s["goat"]), i)
		(_slot_views[i] as Object).call("set_taken_by", by + 1 if by >= 0 else 0)

func _refresh_medals() -> void:
	for g in range(_medals.size()):
		var who: Array = []
		for i in range(MAX_SLOTS):
			if slots[i]["state"] == S_READY and int(slots[i]["goat"]) == g:
				who.append(i)
		(_medals[g] as Object).call("set_locked_by", who)

## "ENTER = KEYBOARD" key-cap hint: only while the keyboard is unjoined, and only on the panel it would
## join (the lowest EMPTY slot) — once, not repeated on every empty panel.
func _refresh_empty_hints() -> void:
	var kb_free: bool = not _kb_joined()
	var first_empty := true
	for i in range(MAX_SLOTS):
		if slots[i]["state"] == S_EMPTY:
			var v: Control = _slot_views[i]
			(v.get_node("JoinPrompt/KbHint") as Control).visible = kb_free and first_empty
			first_empty = false

func _kb_joined() -> bool:
	return _slot_of("kb") >= 0

func _refresh_cpu_tray() -> void:
	_cpu_row.visible = _mode == "brawl"
	if _mode != "brawl":
		return
	var n: int = cpus()
	var skins: Array = _cpu_skins(n)
	var cfg: MatchConfig = GameConfig.match_config
	for b in range(_cpu_chips.size()):
		var chip: Control = _cpu_chips[b]
		chip.visible = b < n
		if b < n:
			(chip.get_node("Box/Head") as TextureRect).texture = _idle_tex(str(skins[b]))
			var lvl: int = Tuning.bot_levels[b % Tuning.bot_levels.size()] if cfg.bot_difficulty == 0 else clampi(cfg.bot_difficulty, 1, 5)
			(chip.get_node("Box/Tag") as Label).text = "CPU L%d" % lvl
	_cpu_none.visible = n == 0

func _refresh_rules_bar() -> void:
	_rules_row.visible = _mode != "trials"
	var cfg: MatchConfig = GameConfig.match_config
	var skill: String = "MIX" if cfg.bot_difficulty == 0 else str(cfg.bot_difficulty)
	if _mode == "brawl":
		_rules_text.text = "FIRST TO %d KOs  ·  %d %s  ·  CPU SKILL %s" % [cfg.kills_to_win, cfg.lives_per_player,
			"LIFE" if cfg.lives_per_player == 1 else "LIVES", skill]
	elif _mode == "sports":
		var total: int = _sports_total if _joined_count() <= _sports_total else 4
		_rules_text.text = "%s  ·  FIRST TO %d GOALS  ·  CPU SKILL %s" % ["1V1" if total == 2 else "2V2", Tuning.sports_goal_target, skill]

## Banner (E.5): valid roster -> "READY TO FIGHT!" slides in from the left (TRANS_BACK) and breathes;
## BRAWL 1 human + 0 CPUs -> the amber hint instead. Never both, never a silent dead end.
func _refresh_banner(animate: bool) -> void:
	var st := roster_state()
	var want_banner: bool = st == "valid"
	var want_hint: bool = st == "need_cpu"
	if want_banner != banner_up:
		banner_up = want_banner
		if banner_up:
			_banner_since = Time.get_ticks_msec()
			_slide_band(_banner, true, animate, "_banner_tw")
			_start_banner_breathe()
			AudioManager.play_sfx("go", {"volume_db": -8.0, "pitch": 1.1})
		else:
			_slide_band(_banner, false, animate, "_banner_tw")
	if want_hint != hint_up:
		hint_up = want_hint
		_slide_band(_hint_banner, hint_up, animate, "_hint_tw")

func _slide_band(node: Control, show: bool, animate: bool, tw_name: String) -> void:
	var old: Variant = get(tw_name)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	if show:
		node.visible = true
		node.move_to_front()
		if animate:
			node.position.x = -1920.0
			var t := node.create_tween()
			t.tween_property(node, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			set(tw_name, t)
		else:
			node.position.x = 0.0
	else:
		if animate and node.visible:
			var t2 := node.create_tween()
			t2.tween_property(node, "position:x", 1920.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t2.tween_callback(func() -> void: node.visible = false)
			set(tw_name, t2)
		else:
			node.visible = false

func _start_banner_breathe() -> void:
	if _breathe_tw != null and _breathe_tw.is_valid():
		return
	_banner_row.pivot_offset = _banner_row.size * 0.5
	_breathe_tw = _banner_row.create_tween().set_loops()
	_breathe_tw.tween_property(_banner_row, "scale", Vector2(1.04, 1.04), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe_tw.tween_property(_banner_row, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _apply_mode_chrome() -> void:
	match _mode:
		"trials":
			_banner_text.text = "READY TO FLY!"
		"sports":
			_banner_text.text = "READY TO PLAY!"
		_:
			_banner_text.text = "READY TO FIGHT!"
	(get_node("Footer/HintRow/GJoin/Label") as Label).text = "JOIN / READY"

## Device-aware glyphs (CC-1.6): pad glyphs after pad input, key caps after keyboard input. Panels always
## show their OWN device's glyphs (LobbySlot); this handles the shared chrome.
func _refresh_glyphs() -> void:
	var kb: bool = InputRouter.last_device_kind == "kb"
	(_f_join as Object).call("setup", "key:ENTER" if kb else "A")
	(_f_back as Object).call("setup", "key:ESC" if kb else "B")
	(_f_random as Object).call("setup", "key:R" if kb else "Y")
	(_f_go as Object).call("setup", "key:ENTER" if kb else "START")
	(_f_hold as Object).call("setup", "key:ESC" if kb else "B")
	(_back_glyph as Object).call("setup", "key:ESC" if kb else "B")
	(_lb_glyph as Object).call("setup", "key:Q" if kb else "LB")
	(_rb_glyph as Object).call("setup", "key:E" if kb else "RB")
	(_hint_glyph as Object).call("setup", "key:E" if kb else "RB")
	(_view_glyph as Object).call("setup", "key:TAB" if kb else "VIEW")
	(_go_glyph as Object).call("setup", "key:ENTER" if kb else "START")

# ================================================================== misc
func _on_device_lost(key: String) -> void:
	# Interim until WK-28's DISCONNECTED slot (10 s reconnect ring): an unplugged pad frees its slot so
	# the lobby never holds a ghost player.
	var si := _slot_of(key)
	if si >= 0:
		_leave(si)
	if _rules_owner == key:
		_close_rules()

func _clear_device_input(key: String) -> void:
	_holds.erase(key + "|h")
	_holds.erase(key + "|v")

func _deny_device(key: String) -> void:
	var si := _slot_of(key)
	if si >= 0:
		(_slot_views[si] as Object).call("deny")
	_deny_sound()

func _deny_sound() -> void:
	AudioManager.play_sfx("ui_click", {"pitch": 0.55, "pitch_var": 0.0, "volume_db": -4.0})

func _soft_tick() -> void:
	AudioManager.play_sfx("ui_click", {"pitch": 0.8, "pitch_var": 0.0, "volume_db": -14.0})

func _move_sound() -> void:
	AudioManager.play_sfx("ui_click", {"pitch": 1.26, "pitch_var": 0.0, "volume_db": -12.0})

func _portrait(g: int) -> Texture2D:
	var h: Dictionary = HEROES[g]
	var p: String = PORTRAIT % str(h["id"])
	if not _tex_cache.has(p):
		_tex_cache[p] = load(p) if ResourceLoader.exists(p) else _idle_tex(str(h["skin"]))
	return _tex_cache[p]

func _idle_tex(skin: String) -> Texture2D:
	var p: String = SPRITE % skin
	if not _tex_cache.has(p):
		_tex_cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _tex_cache[p]

## One-shot flair-unlock celebration on entry (v11 §5.5 grammar, carried over from CharacterSelect).
func _play_flair_celebration(fid: String) -> void:
	var display := str(Settings.flair_item(fid).get("name", fid)).to_upper()
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if not is_instance_valid(_unlock_banner):
			return
		AudioManager.play_sfx("ui_click", {"pitch": 1.5, "pitch_var": 0.0, "volume_db": 0.0})
		EventBus.match_won.emit(0)   # reuse the win fanfare sting (presentation only)
		_unlock_banner.text = "FLAIR UNLOCKED\n%s" % display
		_unlock_banner.visible = true
		_unlock_banner.modulate.a = 0.0
		_unlock_banner.pivot_offset = _unlock_banner.size * 0.5
		_unlock_banner.scale = Vector2(0.7, 0.7)
		var tb := _unlock_banner.create_tween()
		tb.set_parallel(true)
		tb.tween_property(_unlock_banner, "modulate:a", 1.0, 0.25)
		tb.tween_property(_unlock_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tb.chain().tween_interval(1.4)
		tb.chain().tween_property(_unlock_banner, "modulate:a", 0.0, 0.4)
		tb.chain().tween_callback(func() -> void: _unlock_banner.visible = false))
