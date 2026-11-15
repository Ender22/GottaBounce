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
##
## SPORTS (WK-27, audit §E.6): picking the goat picks the team. The carousel offers only the four team
## colourways (SportsMode.TEAM_SKINS: RED = POGO / BILLY, BLUE = BUTCH / ZIGGY), each panel wears a RED/BLUE
## ribbon, a full team's goats are skipped (1V1 = 1 seat a side, 2V2 = 2), the CPU tray previews the exact
## team-fill CPUs, and proceed writes MatchConfig.team_ids so the match spawns the picked goats on their teams.

const MEDAL := preload("res://scenes/ui/RosterMedallion.tscn")
const PORTRAIT := "res://assets/ui/portraits/portrait_%s.png"
const SPRITE := "res://assets/characters/bouncer_%s_idle.png"

## The six goats, in roster-ribbon order. Colour + display name come from PlayerIdentity (WK-08: the ONE
## goat identity table) via _hero(); only lobby-specific data (portrait id, blurb) lives here.
const HEROES := [
	{"id": "pogo", "skin": "pink", "blurb": "Can't stop boinging. Won't stop boinging."},
	{"id": "butch", "skin": "blue", "blurb": "Come at me. I've been stretching."},
	{"id": "ziggy", "skin": "green", "blurb": "Watch THIS recovery."},
	{"id": "puff", "skin": "yellow", "blurb": "WHEEEE— wait which way?"},
	{"id": "vex", "skin": "purple", "blurb": "You may bow now."},
	{"id": "billy", "skin": "orange", "blurb": "Back in MY day the mountain was TALLER."},
]
const MAX_SLOTS := 4
const ToyKit := preload("res://src/ui/ToyKit.gd")   # WK-52: unlock card palette
const S_EMPTY := "EMPTY"
const S_PICKING := "PICKING"
const S_READY := "READY"
const S_DISC := "DISCONNECTED"   # WK-28a (CC-3.5): the seat's pad was unplugged; goat + colour held for the grace window
const JOIN_PITCH := [1.0, 1.12, 1.26, 1.41]   # E.10: ui_join pitched by slot

@onready var _slot_views: Array = [$Slots/Slot1, $Slots/Slot2, $Slots/Slot3, $Slots/Slot4]
@onready var _roster: HBoxContainer = $Roster
@onready var _backdrop: Control = $StandaloneBackdrop
@onready var _back_btn: Button = $Header/BackBtn
@onready var _back_glyph: Control = $Header/BackBtn/Row/BackGlyph
@onready var _back_label: Label = $Header/BackBtn/Row/BackLabel
@onready var _back_row: Control = $Header/BackBtn/Row
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
@onready var _edit_chip: Label = $RulesRow/RulesBar/Row/EditChip
@onready var _go_slash: Label = $ReadyBanner/Band/Row/GoSlash
@onready var _go_wrap: Control = $ReadyBanner/Band/Row/GoWrap
@onready var _go_wrap2: Control = $ReadyBanner/Band/Row/GoWrap2
@onready var _go_glyph2: Control = $ReadyBanner/Band/Row/GoWrap2/GoGlyph2
# WK-52 / CD3-07: the flair unlock is a cream banner card that drops into the header band (never over a slot).
@onready var _unlock_card: Control = $UnlockCard
@onready var _unlock_panel: PanelContainer = $UnlockCard/Center/Card
@onready var _unlock_icon: Panel = $UnlockCard/Center/Card/Row/Icon
@onready var _unlock_swatch: Control = $UnlockCard/Center/Card/Row/Icon/Swatch   # WK-145: the flair itself, on a tiny goat
@onready var _unlock_name: Label = $UnlockCard/Center/Card/Row/Text/Name
@onready var _unlock_owner: Label = $UnlockCard/Center/Card/Row/Text/Owner
@onready var _f_join: Control = $Footer/HintRow/GJoin/Glyph
@onready var _f_back: Control = $Footer/HintRow/GBack/Glyph
@onready var _f_random: Control = $Footer/HintRow/GRandom/Glyph
@onready var _red_group: Control = $Roster/RedGroup
@onready var _blue_group: Control = $Roster/BlueGroup
@onready var _team_vs: Control = $Roster/TeamVs
@onready var _cpu_minus: Control = $CpuRow/CpuTray/Row/Minus
@onready var _cpu_plus: Control = $CpuRow/CpuTray/Row/Plus

## Slot state (audit §E.2): {state, device, goat, flair, row}. The lobby is the ONLY writer; InputRouter's
## join registry mirrors it. Eval-readable for QA (`slots`, `banner_up`, `cpus()`).
## WK-28a: a DISCONNECTED slot also carries {prev: the state it had when its pad was lost, until: msec deadline};
## its "device" is the lost pad (so that pad gets its old state back if it reconnects and presses A in time).
var slots: Array = []
var banner_up := false
var hint_up := false
var _mode := "brawl"          # "brawl" | "sports" | "trials"
var _cpu_pref := 3            # BRAWL CPU preference; the tray shows cpus() = min(pref, 4 - humans)
var _sports_total := 0        # SPORTS FORMAT seats: 2 = 1V1, 4 = 2V2 (set in RULES); 0 = AUTO (WK-120, _sports_format)
var _medals: Array = []
var _flair_vals: Array = []   # "" (NONE), unlocked ids, "__locked" tease
var _flair_labels: Array = []
var _tex_cache := {}
var _pending_flair := ""
var _pool: Array = []         # WK-27: goat indices this mode's carousel offers, in carousel order
var _hint_default := ""       # the amber hint's authored text (BRAWL "need a CPU"); SPORTS swaps in "team full"

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
var _rules_owner := ""        # device key holding the RULES panel ("" = closed). Eval-readable.
var _rules_slot := -1
var _rules_row_i := 0
var _rules_defs: Array = []
var _rules_snapshot: Dictionary = {}
var _rules_key := ""          # GameConfig.mode_rules key for this mode ("" = TRIALS, no rules)
var _edit_tw: Tween

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
	_build_pool()
	# roster ribbon: one medallion per goat (instanced from the scene — data-driven, not a widget wall).
	# _medals stays indexed by goat; SPORTS regroups the pool's four into the RED / BLUE team plates.
	for g in range(HEROES.size()):
		var m: Control = MEDAL.instantiate()
		_roster.add_child(m)
		(m as Object).call("setup", g, _hero(g)["color"], _portrait(g))
		_medals.append(m)
	if _mode == "sports":
		_group_sports_roster()
	for i in range(MAX_SLOTS):
		var sil_g: int = int(_pool[i % _pool.size()])
		(_slot_views[i] as Object).call("setup_slot", i, _idle_tex(str((HEROES[sil_g] as Dictionary)["skin"])))
		(_slot_views[i] as Object).call("set_sports_layout", _mode == "sports")
	_hint_default = _hint_text.text
	_build_flair_vals()
	# WK-52: flair is never worn in SPORTS (no FLAIR row), so a sports lobby leaves the one-shot celebration
	# pending for the next lobby that can actually equip it.
	if _mode != "sports":
		_pending_flair = Settings.take_pending_flair_unlock()
	_back_btn.pressed.connect(_exit)
	# CC-1.6 (amended): shared glyphs follow the JOINED devices; the last device only matters while nobody
	# has joined — so this signal never re-skins the chrome mid-lobby (no flicker when 4 people mash).
	InputRouter.last_device_changed.connect(func(_k: String) -> void:
		if _joined_count() == 0:
			_refresh_glyphs())
	InputRouter.device_lost.connect(_on_device_lost)
	_load_rules()
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
	# roster ribbon pops in; panels animate themselves (join motion) so they aren't staggered
	if _mode == "sports":
		return [_red_group, _team_vs, _blue_group]   # WK-27: the two team plates + VS, not hidden medallions
	return _medals

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
## READY (CC-4.7). Then CC-4.8 / WK-125: auto-join the device that confirmed the mode card if it isn't seated.
func _restore_lobby() -> void:
	var forward := true
	if shell != null and "nav_forward" in shell:
		forward = bool(shell.nav_forward)
	InputRouter.clear_joined()
	var saved: Array = GameConfig.lobby
	var any_gone := false   # WK-166
	if saved.size() == MAX_SLOTS:
		for i in range(MAX_SLOTS):
			var d: Variant = saved[i]
			if typeof(d) != TYPE_DICTIONARY:
				continue
			var sd: Dictionary = d
			var st := str(sd.get("state", S_EMPTY))
			var dev := str(sd.get("device", ""))
			if (st != S_PICKING and st != S_READY) or InputRouter.kind_of(dev) == "":
				continue
			if forward and st == S_READY:
				st = S_PICKING
			slots[i] = {"state": st, "device": dev, "goat": clampi(int(sd.get("goat", 0)), 0, HEROES.size() - 1),
				"flair": str(sd.get("flair", "")), "row": 0}
			# WK-166 (F1, CC-3.5): a seat whose pad died mid-match (RESUME WITHOUT -> CHANGE SETUP) and has not come
			# back must not return as a live seat: nobody but that pad could clear it, so READY TO FIGHT never came.
			# It returns DISCONNECTED with a fresh grace window, exactly like a live lobby disconnect (goat + colour
			# kept, any free device's A takes it over, EMPTY when the window runs out), and is NOT in the join registry.
			if _pad_gone(dev):
				slots[i]["prev"] = st
				slots[i]["state"] = S_DISC
				slots[i]["until"] = Time.get_ticks_msec() + int(Tuning.lobby_disconnect_grace * 1000.0)
				any_gone = true
				continue
			InputRouter.join(dev, i)
	# WK-27: a goat this mode doesn't offer (VEX kept from a BRAWL lobby, now in ROCKETBALL) re-seats on the
	# balanced default, un-readied (never a silently invalid READY).
	for i in range(MAX_SLOTS):
		if slots[i]["state"] == S_EMPTY:
			continue
		if not _pool.has(int(slots[i]["goat"])):
			if slots[i]["state"] == S_DISC:
				slots[i]["prev"] = S_PICKING   # WK-166: the held seat stays DISCONNECTED, on a goat this mode offers
			else:
				slots[i]["state"] = S_PICKING
			slots[i]["goat"] = _default_goat(i)
	for i in range(MAX_SLOTS):
		var s: Dictionary = slots[i]
		if s["state"] == S_EMPTY:
			(_slot_views[i] as Object).call("show_empty", true, false)
		elif s["state"] == S_DISC:
			# WK-166: restored DISCONNECTED (no join motion, no shake: the screen is sliding in)
			(_slot_views[i] as Object).call("show_disconnected_seat", str(s["device"]), _hero(int(s["goat"])),
				_portrait(int(s["goat"])), not _kb_joined())
			(_slot_views[i] as Object).call("set_disc_remaining", 1.0, ceili(Tuning.lobby_disconnect_grace))
		else:
			(_slot_views[i] as Object).call("show_join", str(s["device"]), _hero(int(s["goat"])), _portrait(int(s["goat"])))
			(_slot_views[i] as Object).call("set_ready", s["state"] == S_READY, false)
			_push_flair_view(i)
			(_slot_views[i] as Object).call("set_row", 0)
	# WK-125: the confirming device joins whatever carried over (P2 + P3 still seated after P1 held B out and
	# picked another mode) — lowest free slot, so P1's old seat. Never a duplicate, never a full-lobby deny.
	var auto_key: String = GameConfig.lobby_autojoin_key
	GameConfig.lobby_autojoin_key = ""
	if InputRouter.kind_of(auto_key) != "" and _slot_of(auto_key) < 0 and _joined_count() < MAX_SLOTS:
		_join(auto_key, false, false)   # WK-166: the mode-card confirm takes an EMPTY seat, not a DISCONNECTED one
	# WK-166: the gone pad's seat is not carried to the next screen / mode (that is how it followed into ROCKETBALL)
	if any_gone:
		_persist()

## WK-166 (F1): a pad seat whose pad was lost and has not been heard from since (InputRouter/DeviceWatch).
## Never enumerates joypads (CC-3.1: gbplay / Steam Input pads are not in get_connected_joypads()).
func _pad_gone(dev: String) -> bool:
	if not InputRouter.is_pad(dev):
		return false
	var watch: Node = InputRouter.get_node_or_null("DeviceWatch")
	return watch != null and watch.has_method("is_gone") and bool(watch.call("is_gone", dev))

func _persist() -> void:
	var out: Array = []
	for s in slots:
		if s["state"] == S_DISC:
			out.append(_empty_slot())   # WK-28a: a seat whose pad is gone is not carried to the next screen
			continue
		out.append({"state": s["state"], "device": s["device"], "goat": s["goat"], "flair": s["flair"]})
	GameConfig.lobby = out
	GameConfig.set_rules(_rules_key, _current_rules())

## WK-07 per-mode rule memory: this mode's remembered set (or defaults) -> the live config. A mode never
## sees another mode's values (Rocketball's 1-bot fill can't leak into Brawl's CPU count).
func _load_rules() -> void:
	var cfg: MatchConfig = GameConfig.match_config
	_rules_key = GameConfig.rules_key(cfg.mode_id) if cfg != null else "brawl"
	if _rules_key == "" or cfg == null:
		return
	var r: Dictionary = GameConfig.rules_for(_rules_key)
	cfg.bot_difficulty = int(r.get("bot_difficulty", 0))
	if _mode == "sports":
		_sports_total = int(r.get("sports_total", 0))
		cfg.pressure_nets = int(r.get("pressure_nets", 1))   # WK-116: PRESSURE NETS default ON (Dropshot never reads it)
	else:
		_cpu_pref = int(r.get("cpus", 3))
		cfg.kills_to_win = int(r.get("kills_to_win", 10))
		cfg.lives_per_player = int(r.get("lives_per_player", 1))
		cfg.self_ko_penalty = int(r.get("self_ko_penalty", 0))   # WK-20c: Ra default OFF
		cfg.ghosts = int(r.get("ghosts", MatchConfig.Ghosts.ON))   # WK-37: ghost goats default ON

func _current_rules() -> Dictionary:
	var cfg: MatchConfig = GameConfig.match_config
	if _mode == "sports":
		var sr: Dictionary = {"sports_total": _sports_total, "bot_difficulty": cfg.bot_difficulty}
		if _pressure_row_mode():
			sr["pressure_nets"] = cfg.pressure_nets   # WK-116
		return sr
	return {"cpus": _cpu_pref, "bot_difficulty": cfg.bot_difficulty, "kills_to_win": cfg.kills_to_win,
		"lives_per_player": cfg.lives_per_player, "self_ko_penalty": cfg.self_ko_penalty, "ghosts": cfg.ghosts}

func _hero(g: int) -> Dictionary:
	var h: Dictionary = (HEROES[g] as Dictionary).duplicate()
	var sk := str(h["skin"])
	h["name"] = PlayerIdentity.name_for_skin(sk)
	h["color"] = PlayerIdentity.color_for_skin(sk)
	var t: int = _goat_team(g)
	if t >= 0:
		h["team"] = t
		h["team_name"] = SportsMode.TEAM_NAMES[t]
		h["team_color"] = SportsMode.TEAM_COLORS[t]
	return h

# ------------------------------------------------------------------ SPORTS teams (WK-27, audit §E.6)
## The carousel pool: every goat in BRAWL / TRIALS; in SPORTS the team colourways in team order
## (RED: POGO, BILLY · BLUE: BUTCH, ZIGGY) straight from SportsMode.TEAM_SKINS, the one mapping.
func _build_pool() -> void:
	_pool = []
	if _mode == "sports":
		for t in range(SportsMode.TEAM_SKINS.size()):
			for sk in (SportsMode.TEAM_SKINS[t] as Array):
				var g: int = _goat_for_skin(str(sk))
				if g >= 0:
					_pool.append(g)
	if _pool.is_empty():
		for g in range(HEROES.size()):
			_pool.append(g)

func _goat_for_skin(sk: String) -> int:
	for g in range(HEROES.size()):
		if str((HEROES[g] as Dictionary)["skin"]) == sk:
			return g
	return -1

## Team of goat `g` in this lobby: 0 RED / 1 BLUE in SPORTS, -1 elsewhere (and for non-sports goats).
func _goat_team(g: int) -> int:
	if _mode != "sports" or g < 0 or g >= HEROES.size():
		return -1
	return SportsMode.team_for_skin(str((HEROES[g] as Dictionary)["skin"]))

## Eval-readable (QA): the team slot `i` is on, -1 if EMPTY / not sports.
func slot_team(i: int) -> int:
	if i < 0 or i >= MAX_SLOTS or slots[i]["state"] == S_EMPTY:
		return -1
	return _goat_team(int(slots[i]["goat"]))

## The FORMAT in effect (2 = 1V1, 4 = 2V2). WK-120: until a player sets FORMAT in RULES (_sports_total 0 = AUTO)
## it follows the couch: 2+ joined humans (Tuning.sports_auto_2v2_humans) -> 2V2 with a CPU each side, a lone
## human -> 1V1. A FORMAT the players set for this mode (WK-07 memory) always wins.
func _sports_format() -> int:
	if _sports_total > 0:
		return _sports_total
	return 4 if _joined_count() >= Tuning.sports_auto_2v2_humans else 2

## Seats in the match: the FORMAT; 3-4 joined humans force 2V2 (E.6).
func _sports_seats_total() -> int:
	var fmt: int = _sports_format()
	return fmt if _joined_count() <= fmt else 4

func _team_seats() -> int:
	return _sports_seats_total() / 2

## READY humans on team `t`, not counting slot `except_si`.
func _team_ready_count(t: int, except_si: int) -> int:
	var n := 0
	for i in range(MAX_SLOTS):
		if i != except_si and _holds_lock(i) and _goat_team(int(slots[i]["goat"])) == t:
			n += 1
	return n

## SPORTS: goat `g`'s team already has every seat LOCKED by other humans (E.6 "goats of a full team are
## skipped for the remaining players"). Like goat exclusivity, only READY players hold a seat — two PICKING
## players may browse the same team; the first to lock wins it.
func _team_full_for(g: int, si: int) -> bool:
	var t: int = _goat_team(g)
	return t >= 0 and _team_ready_count(t, si) >= _team_seats()

## Slot `si` can't land on / lock goat `g`: another human locked it, or (SPORTS) its team is full.
func _blocked(g: int, si: int) -> bool:
	return _locked_by_other(g, si) >= 0 or _team_full_for(g, si)

## The goat a slot starts on (E.4: first goat no other joined human is on). SPORTS first balances: start on
## the team with FEWER joined humans (tie -> RED), never on a blocked goat — so two friends who just mash A
## land on opposite sides, the Rocket League / Strikers default. Teammates are one cycle away.
func _default_goat(si: int) -> int:
	var used: Array = []
	var per_team: Array = [0, 0]
	for i in range(MAX_SLOTS):
		if i == si or slots[i]["state"] == S_EMPTY:
			continue
		var og: int = int(slots[i]["goat"])
		used.append(og)
		var ot: int = _goat_team(og)
		if ot >= 0:
			per_team[ot] = int(per_team[ot]) + 1
	var order: Array = []
	if _mode == "sports":
		var first: int = 1 if int(per_team[1]) < int(per_team[0]) else 0
		for want in [first, 1 - first]:
			for g in _pool:
				if _goat_team(int(g)) == want:
					order.append(g)
	else:
		order = _pool.duplicate()
	for g in order:
		if not used.has(g) and not _blocked(int(g), si):
			return int(g)
	for g in order:
		if not _blocked(int(g), si):
			return int(g)
	return int(order[0]) if not order.is_empty() else 0

## The roster ribbon in SPORTS: [RED  POGO BILLY]  VS  [BUTCH ZIGGY  BLUE]; VEX / PUFF medallions hidden.
func _group_sports_roster() -> void:
	_red_group.visible = true
	_blue_group.visible = true
	_team_vs.visible = true
	var red_row: Node = _red_group.get_node("Row")
	var blue_row: Node = _blue_group.get_node("Row")
	for g in range(_medals.size()):
		var m: Control = _medals[g]
		var t: int = _goat_team(g)
		if t < 0 or not _pool.has(g):
			m.visible = false
			continue
		_roster.remove_child(m)
		(red_row if t == 0 else blue_row).add_child(m)
	blue_row.move_child(blue_row.get_node("TeamName"), -1)   # mirror: the BLUE name sits on the outside edge

## The CPUs a SPORTS match will spawn for the current picks (SportsMode.team_fill — the same rule spawn_plan
## runs, so the tray never lies). Joined humans count in slot order with their goat's team. Eval-readable.
func sports_fill() -> Array:
	var skins: Array = []
	var teams: Array = []
	for s in slots:
		if s["state"] == S_EMPTY:
			continue
		skins.append(str((HEROES[int(s["goat"])] as Dictionary)["skin"]))
		teams.append(_goat_team(int(s["goat"])))
	return SportsMode.team_fill(skins, teams, _sports_seats_total(), GameConfig.match_config.bot_difficulty)

## The team that has more joined humans than seats (-1 = none). Only reachable by a format change or a
## leave shrinking the seats under READY players; roster_state turns it into the amber hint.
func _overfull_team() -> int:
	var seats: int = _team_seats()
	for t in range(2):
		var n := 0
		for s in slots:
			if s["state"] != S_EMPTY and _goat_team(int(s["goat"])) == t:
				n += 1
		if n > seats:
			return t
	return -1

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
	var si := _slot_of(key)
	# RULES panel (WK-07): only its owner drives it; other devices keep playing their own panels underneath
	if _rules_owner != "":
		if key == _rules_owner:
			if dir != Vector2i.ZERO:
				_press_dir(key, dir, "dig")
			elif verb in ["accept", "view", "start"]:
				_close_rules(false)      # A / View = DONE (keep)
			elif verb == "back":
				_close_rules(true)       # B = UNDO (restore the snapshot); never starts the hold-exit
			elif si >= 0:
				(_slot_views[si] as Object).call("ping")
			return
		if verb == "view":
			_deny_rules_taken(key)
			return
	if dir != Vector2i.ZERO:
		_press_dir(key, dir, "dig")
		return
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
				_ping(si)
		"back":
			_on_back_press(key, si)
		"random":
			if si >= 0:
				if slots[si]["state"] == S_PICKING and not _spinning[si]:
					_random_pick(si)
				else:
					_ping(si)
		"cpu_prev", "cpu_next":
			if si >= 0:
				if _mode == "brawl":
					_cpu_step(-1 if verb == "cpu_prev" else 1)
				else:
					_ping(si)
		"view":
			if si >= 0:
				_open_rules(key, si)
		_:
			if si >= 0:
				_ping(si)   # a face button / key with no meaning here: "that's me" (WK-81 F3)

## WK-81 F3 "that's me": a joined device's press that did nothing pulses its own panel header + P-badge.
func _ping(si: int) -> void:
	if si >= 0:
		(_slot_views[si] as Object).call("ping")

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
	_tick_disc(now)

# ================================================================== slot actions
func _slot_of(key: String) -> int:
	for i in range(MAX_SLOTS):
		if slots[i]["state"] != S_EMPTY and slots[i]["state"] != S_DISC and slots[i]["device"] == key:
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
func _join(key: String, sound: bool, takeover_first: bool = true) -> void:
	if _launching:
		return
	# WK-28a (CC-3.5): "the first unassigned device to press A takes it over" — a DISCONNECTED seat beats an EMPTY
	# one. The lost pad itself gets its own seat back first if several are waiting.
	# WK-166: `takeover_first` false (the CC-4.8 auto-join of the mode-card confirmer) prefers an EMPTY seat; a held
	# DISCONNECTED seat is only taken when the lobby has no EMPTY one left (or it is that pad's own seat).
	var di := _disc_slot_for(key)
	if di >= 0 and (takeover_first or str(slots[di]["device"]) == key or not _has_empty()):
		_reclaim(di, key)
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
	var fl := ""
	if si == 0 and Settings.equipped_flair != "" and _flair_vals.has(Settings.equipped_flair):
		fl = Settings.equipped_flair   # P-slot 0's flair persists to Settings (E.2)
	slots[si] = {"state": S_PICKING, "device": key, "goat": 0, "flair": fl, "row": 0}
	var g: int = _default_goat(si)   # computed with this slot joined, so SPORTS seats count it (3rd human -> 2V2)
	slots[si]["goat"] = g
	InputRouter.join(key, si)
	_clear_device_input(key)
	var v: Object = _slot_views[si]
	v.call("show_join", key, _hero(g), _portrait(g))
	_push_flair_view(si)
	v.call("set_row", 0)
	if sound:
		AudioManager.play_sfx("powerup_pickup", {"pitch": JOIN_PITCH[si], "pitch_var": 0.0, "volume_db": -4.0})
	InputRouter.rumble(key, 0.4, 0.6, 0.18)   # WK-81 F3: the pad in YOUR hands buzzes — "that panel is mine"
	_after_change()

func _has_empty() -> bool:   # WK-166
	for s in slots:
		if s["state"] == S_EMPTY:
			return true
	return false

func _leave(si: int) -> void:
	var dev := str(slots[si]["device"])
	_stop_spin(si)
	slots[si] = _empty_slot()
	InputRouter.leave(dev)
	_clear_device_input(dev)
	(_slot_views[si] as Object).call("show_empty", not _kb_joined(), true)
	AudioManager.play_sfx("ui_click", {"pitch": 0.6, "pitch_var": 0.0, "volume_db": -4.0})
	_after_change()

# ------------------------------------------------------------------ DISCONNECTED seats (WK-28a, CC-3.5)
## The DISCONNECTED seat `key` should take over: its own old seat if it has one, else the lowest one. -1 = none.
func _disc_slot_for(key: String) -> int:
	var first := -1
	for i in range(MAX_SLOTS):
		if slots[i]["state"] != S_DISC:
			continue
		if str(slots[i]["device"]) == key:
			return i
		if first < 0:
			first = i
	return first

## Seat `si` lost its pad: keep goat, colour, flair and P-number for Tuning.lobby_disconnect_grace seconds.
func _disconnect(si: int) -> void:
	var s: Dictionary = slots[si]
	var dev := str(s["device"])
	_stop_spin(si)
	_lock_queue.erase(si)
	s.erase("flair_view")
	s["prev"] = s["state"]
	s["state"] = S_DISC
	s["until"] = Time.get_ticks_msec() + int(Tuning.lobby_disconnect_grace * 1000.0)
	InputRouter.leave(dev)
	_clear_device_input(dev)
	_hold_b.erase(dev)
	(_slot_views[si] as Object).call("show_disconnected", not _kb_joined())
	(_slot_views[si] as Object).call("set_disc_remaining", 1.0, ceili(Tuning.lobby_disconnect_grace))
	_deny_sound()
	_after_change()

## `key` takes over DISCONNECTED seat `si`. The pad that was lost gets its old state back (READY stays READY, if the
## goat is still free); any other device takes the goat and colour but starts PICKING (a new pair of hands decides).
func _reclaim(si: int, key: String) -> void:
	var s: Dictionary = slots[si]
	var same: bool = str(s["device"]) == key
	var back_ready: bool = same and str(s.get("prev", "")) == S_READY
	var g: int = int(s["goat"])
	slots[si] = {"state": S_PICKING, "device": key, "goat": g, "flair": str(s.get("flair", "")), "row": 0}
	if back_ready and not _blocked(g, si):
		slots[si]["state"] = S_READY
	InputRouter.join(key, si)
	_clear_device_input(key)
	var v: Object = _slot_views[si]
	v.call("show_join", key, _hero(g), _portrait(g))
	v.call("set_ready", slots[si]["state"] == S_READY, false)
	_push_flair_view(si)
	v.call("set_row", 0)
	AudioManager.play_sfx("powerup_pickup", {"pitch": JOIN_PITCH[si], "pitch_var": 0.0, "volume_db": -4.0})
	InputRouter.rumble(key, 0.4, 0.6, 0.18)
	_after_change()

## Grace window over: the seat empties (goat released), exactly as if the player had backed out.
func _expire_disc(si: int) -> void:
	slots[si] = _empty_slot()
	(_slot_views[si] as Object).call("show_empty", not _kb_joined(), true)
	AudioManager.play_sfx("ui_click", {"pitch": 0.6, "pitch_var": 0.0, "volume_db": -4.0})
	_after_change()

func _tick_disc(now: int) -> void:
	for i in range(MAX_SLOTS):
		if slots[i]["state"] != S_DISC:
			continue
		var left_ms: int = int(slots[i]["until"]) - now
		if left_ms <= 0:
			_expire_disc(i)
			continue
		var frac: float = float(left_ms) / (Tuning.lobby_disconnect_grace * 1000.0)
		(_slot_views[i] as Object).call("set_disc_remaining", frac, ceili(float(left_ms) / 1000.0))

## Eval-readable (QA): seconds left on a DISCONNECTED seat, -1 if the slot is not DISCONNECTED.
func disc_left(i: int) -> float:
	if i < 0 or i >= MAX_SLOTS or slots[i]["state"] != S_DISC:
		return -1.0
	return maxf(0.0, float(int(slots[i]["until"]) - Time.get_ticks_msec()) / 1000.0)

func _on_accept(si: int) -> void:
	var s: Dictionary = slots[si]
	if s["state"] == S_PICKING:
		if _spinning[si]:
			_soft_tick()   # WK-81 F8: never silently eaten
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
		if _blocked(g, si) or not _pool.has(g):   # WK-27: a full team refuses the lock like a taken goat
			(_slot_views[si] as Object).call("deny")
			(_medals[g] as Object).call("wiggle")
			_deny_sound()
			continue
		s["state"] = S_READY
		(_slot_views[si] as Object).call("set_ready", true, true)
		AudioManager.play_sfx("super_fire", {"volume_db": -20.0, "pitch": 1.25, "pitch_var": 0.05})   # WK-79c (was -12): -8 dB like the WK-79b super blast
	_after_change()

## B: READY -> PICKING -> EMPTY (CC-4.3). Only a B press that changed NOTHING (a device with no slot)
## arms the hold-to-exit ring (WK-82): holding B to un-ready or leave must never eject the whole lobby.
## A tap with nobody joined backs straight out; with people joined, leaving needs the hold (CC-6.2).
func _on_back_press(key: String, si: int) -> void:
	_hold_b.erase(key)
	_hold_ticks = 0
	if si < 0:
		_hold_b[key] = Time.get_ticks_msec()
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
		_ping(si)   # READY / spinning: the stick does nothing, so it says "that's you"
		return
	if axis == "v":
		if _mode == "sports":
			_ping(si)   # WK-27: no FLAIR row in SPORTS (flair is never worn there) — the stick only picks goats
			return
		var nr: int = clampi(int(s["row"]) + dir, 0, 1)
		if nr != int(s["row"]):
			s["row"] = nr
			(_slot_views[si] as Object).call("set_row", nr)
			_move_sound()
		else:
			_ping(si)
		return
	if int(s["row"]) == 0:
		_cycle_goat(si, dir)
	else:
		_cycle_flair(si, dir)

## Cycle (wraps), skipping goats LOCKED by another human; each skipped goat's medallion wiggles. Two
## PICKING players may browse the same goat (E.4).
func _cycle_goat(si: int, dir: int) -> void:
	var s: Dictionary = slots[si]
	var pos: int = maxi(0, _pool.find(int(s["goat"])))
	var g: int = int(s["goat"])
	for _n in range(_pool.size()):
		pos = posmod(pos + dir, _pool.size())
		var c: int = int(_pool[pos])
		if _blocked(c, si):   # WK-27: SPORTS also skips a full team's goats
			(_medals[c] as Object).call("wiggle")
			continue
		g = c
		break
	if g == int(s["goat"]):
		return
	s["goat"] = g
	(_slot_views[si] as Object).call("show_goat", _hero(g), _portrait(g), dir)
	_move_sound()
	_after_change()

func _locked_by_other(g: int, si: int) -> int:
	for i in range(MAX_SLOTS):
		if i != si and _holds_lock(i) and int(slots[i]["goat"]) == g:
			return i
	return -1

## Slot `i` holds its goat locked: READY, or DISCONNECTED from READY (WK-28a — a cable wiggle never frees a pick).
func _holds_lock(i: int) -> bool:
	var st: String = str(slots[i]["state"])
	return st == S_READY or (st == S_DISC and str(slots[i].get("prev", "")) == S_READY)

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
			(_slot_views[si] as Object).call("show_goat", _hero(g), _portrait(g), 1)
			AudioManager.play_sfx("ui_click", {"pitch": 1.1, "pitch_var": 0.0, "volume_db": -4.0})
		_after_change())
	_spin_tw[si] = tw

func _spin_step(si: int) -> void:
	var free: Array = []
	for g in _pool:
		if int(g) != int(slots[si]["goat"]) and not _blocked(int(g), si):
			free.append(int(g))
	if free.is_empty():
		return
	var g: int = free[randi() % free.size()]
	slots[si]["goat"] = g
	(_slot_views[si] as Object).call("show_goat", _hero(g), _portrait(g), 1)
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
			# WK-81 F5: the data-authored short label (flair.json "short", <= 14 chars, fits at 28 px)
			var nm := str((it as Dictionary).get("name", fid)).trim_prefix("TITLE: ")
			_flair_labels.append(str((it as Dictionary).get("short", nm)))
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
## "" = not ready · "need_cpu" = 1 READY human, 0 CPUs in BRAWL (amber hint) · "team_full" = SPORTS team
## over its seats (amber hint) · "valid" = banner.
func roster_state() -> String:
	if _rules_owner != "":
		return ""   # WK-07: nobody launches while someone is editing the rules (banner + hint slide out)
	var joined := 0
	for s in slots:
		if s["state"] == S_EMPTY:
			continue
		if s["state"] != S_READY:
			return ""   # PICKING, or WK-28a DISCONNECTED (its grace window holds the launch)
		joined += 1
	if joined == 0:
		return ""
	if _mode == "brawl" and joined + cpus() < 2:
		return "need_cpu"
	if _mode == "sports" and _overfull_team() >= 0:
		return "team_full"   # E.5 SPORTS rule: no team's seats overfilled (amber hint names the team)
	return "valid"

func _try_proceed() -> void:
	if _rules_owner != "":
		# WK-81 bug fix: a READY player's A/Start while someone has RULES open used to LAUNCH the match.
		# Now: soft deny + the owner's flipped panel nudges ("they're the hold-up").
		_soft_tick()
		_deny_sound()
		if _rules_slot >= 0:
			(_slot_views[_rules_slot] as Object).call("nudge")
		return
	if not banner_up:
		_soft_tick()
		_nudge_waiting()
		return
	if Time.get_ticks_msec() - _banner_since < int(Tuning.lobby_banner_guard * 1000.0):
		# E.5 double-tap guard (banner up >= 0.35 s) — WK-81 F8: answer the press, never eat it silently
		_soft_tick()
		_pop_banner()
		return
	_proceed()

## WK-83 (lobby review L7): a READY player pressed GO before the banner — every panel we are still waiting on
## (PICKING, or WK-28a DISCONNECTED) nudges and flashes its status bar; with nobody left to wait on (the amber
## "add a CPU" / "team full" band is up) the band pops instead.
func _nudge_waiting() -> void:
	var any := false
	for i in range(MAX_SLOTS):
		var st: String = str(slots[i]["state"])
		if st == S_PICKING or st == S_DISC:
			(_slot_views[i] as Object).call("waiting_flash")
			any = true
	if not any and hint_up:
		var row: Control = _hint_banner.get_node("Band")
		row.pivot_offset = row.size * 0.5
		MenuFX.value_pop(row, 1.05)

func _pop_banner() -> void:
	if _breathe_tw != null and _breathe_tw.is_valid():
		_breathe_tw.kill()
	_banner_row.pivot_offset = _banner_row.size * 0.5
	var t := _banner_row.create_tween()
	t.tween_property(_banner_row, "scale", Vector2(1.06, 1.06), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_banner_row, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		if banner_up:
			_start_banner_breathe())

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
	var teams := PackedInt32Array()
	for i in range(MAX_SLOTS):
		var s: Dictionary = slots[i]
		if s["state"] == S_EMPTY or s["state"] == S_DISC:
			continue
		if _mode == "sports":
			teams.append(maxi(0, _goat_team(int(s["goat"]))))
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
	cfg.team_ids = teams   # WK-27: SPORTS teams from the goat colourways; empty in every other mode
	match _mode:
		"brawl":
			cfg.bot_count = cpus()
		"sports":
			cfg.bot_count = maxi(0, _sports_seats_total() - cfg.human_count)
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

# ------------------------------------------------------------------ RULES (WK-07 flip panel)
## View / Tab from a joined device flips THAT device's panel over: the rules live on its back (lobby review
## "RULES PANEL", Duck Game style), so nobody else's panel is hidden and ownership is unambiguous.
## Up/Down = row, Left/Right = change the value LIVE (rules bar updates for everyone). A / View = DONE (keep),
## B = UNDO (restore the snapshot taken on open, then flip back). One panel at a time; while it is open the
## roster is not valid (banner + hint slide out) and GO is refused with a nudge on the owner's panel.
func _open_rules(key: String, si: int) -> void:
	if _mode == "trials" or _spinning[si]:
		_deny_device(key)
		return
	if _mode == "brawl":
		_rules_defs = [
			{"title": "CPUs", "field": "cpus"},
			{"title": "CPU SKILL", "labels": ["MIX", "1", "2", "3", "4", "5"], "vals": [0, 1, 2, 3, 4, 5], "field": "bot_difficulty"},
			{"title": "KOs TO WIN", "labels": ["5", "7", "8", "10"], "vals": [5, 7, 8, 10], "field": "kills_to_win"},
			{"title": "LIVES", "labels": ["1", "2", "3"], "vals": [1, 2, 3], "field": "lives_per_player"},
			# WK-20c (DECISIONS 2026-11-14, ruling Ra): self-KO costs 0 by default; ON = the old -1 (floored at 0)
			{"title": "SELF-KO −1", "labels": ["OFF", "ON"], "vals": [0, 1], "field": "self_ko_penalty"},
			# WK-37 ghost goats (spec §8.1): eliminated players float + bleat (+ puff cloud when ON). Labels say BAA, not QUACK.
			{"title": "GHOSTS", "labels": ["ON", "BAA ONLY", "OFF"], "vals": [0, 1, 2], "field": "ghosts"},
		]
	else:
		_rules_defs = [
			{"title": "FORMAT", "labels": ["1V1", "2V2"], "vals": [2, 4], "field": "sports_total"},
			{"title": "CPU SKILL", "labels": ["MIX", "1", "2", "3", "4", "5"], "vals": [0, 1, 2, 3, 4, 5], "field": "bot_difficulty"},
		]
		if _pressure_row_mode():
			# WK-116 (spec §5, shipped 2026-11-16): long rallies widen both goal mouths. Rocketball only; default ON.
			_rules_defs.append({"title": "PRESSURE NETS", "labels": ["ON", "OFF"], "vals": [1, 0], "field": "pressure_nets"})
	_rules_owner = key
	_rules_slot = si
	_rules_row_i = 0
	_rules_snapshot = _current_rules()
	_clear_device_input(key)
	_stop_spin(si)
	var d: Dictionary = _rules_view_data()
	d["kb"] = key == "kb"
	d["icon"] = _mode_icon()
	(_slot_views[si] as Object).call("show_rules", d)
	_edit_chip.text = "EDITING · P%d" % (si + 1)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _hero(int(slots[si]["goat"]))["color"]
	sb.border_color = MenuFX.CHOCO
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	_edit_chip.add_theme_stylebox_override("normal", sb)
	_edit_chip.visible = true
	_edit_chip.pivot_offset = _edit_chip.size * 0.5
	if _edit_tw != null and _edit_tw.is_valid():
		_edit_tw.kill()
	_edit_tw = _edit_chip.create_tween().set_loops()
	_edit_tw.tween_property(_edit_chip, "scale", Vector2(1.05, 1.05), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_edit_tw.tween_property(_edit_chip, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	AudioManager.play_sfx("ui_click", {"pitch": 1.2, "pitch_var": 0.0, "volume_db": -4.0})   # interim ui_card_flip
	_after_change()

## DONE keeps the live values; UNDO (`undo`) restores the snapshot, shaking the rows it rolls back.
func _close_rules(undo: bool) -> void:
	if _rules_owner == "":
		return
	var rolled: Array = []
	if undo:
		var now: Dictionary = _current_rules()
		for i in range(_rules_defs.size()):
			var f := str((_rules_defs[i] as Dictionary)["field"])
			if now.get(f) != _rules_snapshot.get(f):
				rolled.append(i)
		_apply_rules(_rules_snapshot)
		if _rules_slot >= 0:
			(_slot_views[_rules_slot] as Object).call("refresh_rules", _rules_view_data(), -1, 0)
	if _rules_slot >= 0:
		(_slot_views[_rules_slot] as Object).call("hide_rules", rolled)
	_clear_device_input(_rules_owner)
	_rules_owner = ""
	_rules_slot = -1
	_edit_chip.visible = false
	if _edit_tw != null and _edit_tw.is_valid():
		_edit_tw.kill()
	AudioManager.play_sfx("ui_click", {"pitch": 0.72 if undo else 1.0, "pitch_var": 0.0, "volume_db": -4.0})
	_after_change()   # roster recomputed: a valid roster slides the banner in fresh (0.35 s guard restarts)

func _apply_rules(r: Dictionary) -> void:
	var cfg: MatchConfig = GameConfig.match_config
	cfg.bot_difficulty = int(r.get("bot_difficulty", cfg.bot_difficulty))
	if _mode == "sports":
		_sports_total = int(r.get("sports_total", _sports_total))
		cfg.pressure_nets = int(r.get("pressure_nets", cfg.pressure_nets))   # WK-116
	else:
		_cpu_pref = int(r.get("cpus", _cpu_pref))
		cfg.kills_to_win = int(r.get("kills_to_win", cfg.kills_to_win))
		cfg.lives_per_player = int(r.get("lives_per_player", cfg.lives_per_player))
		cfg.self_ko_penalty = int(r.get("self_ko_penalty", cfg.self_ko_penalty))
		cfg.ghosts = int(r.get("ghosts", cfg.ghosts))

## Current value of a rule row + its legal values/labels (CPUs range follows the humans, WK-02 cap).
func _rule_def_values(def: Dictionary) -> Array:
	var f := str(def["field"])
	if f == "cpus":
		var hi: int = MatchConfig.max_bots_for(maxi(1, _joined_count()))
		var vals: Array = []
		var labels: Array = []
		for n in range(0, hi + 1):
			vals.append(n)
			labels.append(str(n))
		return [vals, labels, cpus()]
	if f == "sports_total":
		return [def["vals"], def["labels"], _sports_seats_total()]
	return [def["vals"], def["labels"], int(GameConfig.match_config.get(f))]

func _rules_view_data() -> Dictionary:
	var rows: Array = []
	for def in _rules_defs:
		var dv: Array = _rule_def_values(def)
		var vals: Array = dv[0]
		var idx: int = maxi(0, vals.find(dv[2]))
		var locked: bool = str((def as Dictionary)["field"]) == "sports_total" and _joined_count() > 2
		rows.append({"title": (def as Dictionary)["title"], "label": str((dv[1] as Array)[idx]), "locked": locked})
	return {"rows": rows, "focus": _rules_row_i}

func _rules_step(axis: String, dir: int) -> void:
	var view: Object = _slot_views[_rules_slot]
	if axis == "v":
		_rules_row_i = posmod(_rules_row_i + dir, _rules_defs.size())
		_move_sound()
		view.call("refresh_rules", _rules_view_data(), -1, 0)
		return
	var def: Dictionary = _rules_defs[_rules_row_i]
	var dv: Array = _rule_def_values(def)
	var vals: Array = dv[0]
	var idx: int = maxi(0, vals.find(dv[2]))
	var ni: int = idx + dir
	var locked: bool = str(def["field"]) == "sports_total" and _joined_count() > 2
	if ni < 0 or ni >= vals.size() or locked:
		view.call("shake_rule", _rules_row_i)
		_deny_sound()
		return
	var f := str(def["field"])
	var r: Dictionary = _current_rules()
	r[f] = int(vals[ni])
	_apply_rules(r)
	view.call("refresh_rules", _rules_view_data(), _rules_row_i, dir)
	AudioManager.play_sfx("ui_click", {"pitch": 1.15, "pitch_var": 0.0, "volume_db": -6.0})
	_refresh_rules_bar()
	_refresh_cpu_tray()
	_refresh_taken()   # WK-27: 2V2 -> 1V1 can fill a team under a browsing player ("RED IS FULL" chip)
	_rules_text.pivot_offset = _rules_text.size * 0.5
	MenuFX.value_pop(_rules_text, 1.06)
	_persist()

## Another device asked for RULES while they're open: deny shake on its own panel + "P1 HAS THE RULES".
func _deny_rules_taken(key: String) -> void:
	var si := _slot_of(key)
	_deny_sound()
	if si >= 0:
		(_slot_views[si] as Object).call("deny")
		(_slot_views[si] as Object).call("flash_chip", "P%d HAS THE RULES" % (_rules_slot + 1), 1.2)

## WK-116: the PRESSURE NETS row exists for the soccer sport only (Rocketball + the legacy mixed "sports" card), and only
## while the studio master switch Tuning.sports_pressure_rule is on (rule 0 = no row: there would be nothing to toggle).
func _pressure_row_mode() -> bool:
	var cfg: MatchConfig = GameConfig.match_config
	return _mode == "sports" and cfg != null and SportsMode.sport_for_mode(cfg.mode_id) != "dropshot" 		and int(Tuning.sports_pressure_rule) != 0

func _mode_icon() -> Texture2D:
	var cfg: MatchConfig = GameConfig.match_config
	var mid := str(cfg.mode_id) if cfg != null else "brawl"
	var art := "sports" if mid == "rocketball" else mid
	var p := "res://assets/ui/modes/mode_%s.png" % art
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

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
		var txt := ""
		if s["state"] == S_PICKING:
			var by: int = _locked_by_other(int(s["goat"]), i)
			if by >= 0:
				txt = "TAKEN BY P%d" % (by + 1)
			elif _team_full_for(int(s["goat"]), i):
				txt = "%s IS FULL" % SportsMode.TEAM_NAMES[_goat_team(int(s["goat"]))]
		(_slot_views[i] as Object).call("set_taken_text", txt)

func _refresh_medals() -> void:
	for g in range(_medals.size()):
		var who: Array = []
		for i in range(MAX_SLOTS):
			if _holds_lock(i) and int(slots[i]["goat"]) == g:
				who.append(i)
		(_medals[g] as Object).call("set_locked_by", who)

## "ENTER = KEYBOARD" key-cap hint: only while the keyboard is unjoined, and only on the panel it would
## join (the lowest EMPTY slot) — once, not repeated on every empty panel.
func _refresh_empty_hints() -> void:
	var kb_free: bool = not _kb_joined()
	var first_empty := true
	var has_disc := false
	for i in range(MAX_SLOTS):
		if slots[i]["state"] == S_DISC:
			has_disc = true
			(_slot_views[i] as Object).call("set_disc_takeover", kb_free)
	for i in range(MAX_SLOTS):
		if slots[i]["state"] == S_EMPTY:
			# WK-28a: while a seat is DISCONNECTED the keyboard's Enter takes it over, so no KEYBOARD join hint here
			(_slot_views[i] as Object).call("set_kb_hint", kb_free and first_empty and not has_disc)
			first_empty = false

func _kb_joined() -> bool:
	return _slot_of("kb") >= 0

func _refresh_cpu_tray() -> void:
	_cpu_row.visible = _mode != "trials"
	if _mode == "sports":
		_refresh_sports_tray()
		return
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

## WK-27 SPORTS tray: a read-only preview of the CPUs that will fill each team's empty seats (no LB/RB —
## the seat count comes from FORMAT in RULES). Each chip rims in its team colour.
func _refresh_sports_tray() -> void:
	for n in [_lb_glyph, _rb_glyph, _cpu_minus, _cpu_plus]:
		(n as Control).visible = false
	var fill: Array = sports_fill()
	for b in range(_cpu_chips.size()):
		var chip: Control = _cpu_chips[b]
		chip.visible = b < fill.size()
		if b >= fill.size():
			continue
		var d: Dictionary = fill[b]
		(chip.get_node("Box/Head") as TextureRect).texture = _idle_tex(str(d["skin"]))
		(chip.get_node("Box/Tag") as Label).text = "CPU L%d" % int(d["bot_level"])
		var base: StyleBoxFlat = chip.get_theme_stylebox("panel") as StyleBoxFlat
		var sb: StyleBoxFlat = base.duplicate() as StyleBoxFlat if base != null else StyleBoxFlat.new()
		var tc: Color = SportsMode.TEAM_COLORS[int(d["team"])]
		sb.bg_color = Color(tc.r, tc.g, tc.b, 0.22)
		sb.border_color = tc
		sb.set_border_width_all(4)
		chip.add_theme_stylebox_override("panel", sb)
	_cpu_none.visible = fill.is_empty()

func _refresh_rules_bar() -> void:
	_rules_row.visible = _mode != "trials"
	var cfg: MatchConfig = GameConfig.match_config
	var skill: String = "MIX" if cfg.bot_difficulty == 0 else str(cfg.bot_difficulty)
	if _mode == "brawl":
		_rules_text.text = "FIRST TO %d KOs  ·  %d %s  ·  CPU SKILL %s" % [cfg.kills_to_win, cfg.lives_per_player,
			"LIFE" if cfg.lives_per_player == 1 else "LIVES", skill]
		if cfg.self_ko_penalty > 0:
			_rules_text.text += "  ·  SELF-KO −%d" % cfg.self_ko_penalty   # WK-20c: only the non-default rule shows
		if cfg.ghosts == MatchConfig.Ghosts.BAA_ONLY:
			_rules_text.text += "  ·  GHOSTS BAA ONLY"   # WK-37: only a non-default ghost rule shows
		elif cfg.ghosts == MatchConfig.Ghosts.OFF:
			_rules_text.text += "  ·  NO GHOSTS"
	elif _mode == "sports":
		var total: int = _sports_seats_total()
		# WK-117 / CD3-09: Dropshot scores POINTS, not goals (SportsMode.goal_word "POINT!").
		var unit: String = "POINTS" if SportsMode.sport_for_mode(cfg.mode_id) == "dropshot" else "GOALS"
		_rules_text.text = "%s  ·  FIRST TO %d %s  ·  CPU SKILL %s" % ["1V1" if total == 2 else "2V2", Tuning.sports_goal_target, unit, skill]
		if _pressure_row_mode() and cfg.pressure_nets == 0:
			_rules_text.text += "  ·  NO PRESSURE NETS"   # WK-116: only the non-default rule shows (like NO GHOSTS)

## Banner (E.5): valid roster -> "READY TO FIGHT!" slides in from the left (TRANS_BACK) and breathes;
## BRAWL 1 human + 0 CPUs -> the amber hint instead. Never both, never a silent dead end.
func _refresh_banner(animate: bool) -> void:
	var st := roster_state()
	var want_banner: bool = st == "valid"
	var want_hint: bool = st == "need_cpu" or st == "team_full"
	if want_hint:
		# WK-27: the amber band also names an overfilled SPORTS team (no glyph — the fix is a goat change)
		var full: int = _overfull_team() if st == "team_full" else -1
		_hint_glyph.visible = full < 0
		_hint_text.text = _hint_default if full < 0 else "%s IS FULL · SOMEONE SWITCH TO %s" % [
			SportsMode.TEAM_NAMES[full], SportsMode.TEAM_NAMES[1 - full]]
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
	# WK-81 F6: a band crossing the panel bottoms lifts every EMPTY panel's "PRESS A TO JOIN" above it
	for i in range(MAX_SLOTS):
		if slots[i]["state"] == S_EMPTY:
			(_slot_views[i] as Object).call("set_join_lift", banner_up or hint_up)

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
	if _mode == "sports":
		(get_node("Footer/HintRow/GFlair/Label") as Label).text = "GOAT = TEAM"   # no FLAIR row in SPORTS

## Shared-chrome glyphs — CC-1.6 as amended by the lobby review (WK-81 F2):
##  - any JOINED pad -> pad glyphs; only the keyboard joined -> key caps; nobody joined -> the last device.
##  - the GO prompt (banner + footer) shows BOTH when pads and the keyboard are both joined: [START] / [ENTER].
##  - the amber hint (exactly one human) uses THAT human's device glyph.
## Recomputed only on join / leave / device loss (and on last-device change while nobody is joined), never on
## every input — so the chrome never flickers while four people mash. Panels always show their OWN device.
func shared_glyph_kind() -> String:
	var any_pad := false
	var any_kb := false
	for s in slots:
		if s["state"] == S_EMPTY or s["state"] == S_DISC:
			continue
		if str(s["device"]) == "kb":
			any_kb = true
		else:
			any_pad = true
	if any_pad:
		return "pad"
	if any_kb:
		return "kb"
	return "kb" if InputRouter.last_device_kind == "kb" else "pad"

func _mixed_devices() -> bool:
	var any_pad := false
	var any_kb := false
	for s in slots:
		if s["state"] == S_EMPTY or s["state"] == S_DISC:
			continue
		if str(s["device"]) == "kb":
			any_kb = true
		else:
			any_pad = true
	return any_pad and any_kb

func _refresh_glyphs() -> void:
	var kb: bool = shared_glyph_kind() == "kb"
	var mixed: bool = _mixed_devices()
	(_f_join as Object).call("setup", "key:ENTER" if kb else "A")
	(_f_back as Object).call("setup", "key:ESC" if kb else "B")
	(_f_random as Object).call("setup", "key:R" if kb else "Y")
	(_back_glyph as Object).call("setup", "key:ESC" if kb else "B")
	(_lb_glyph as Object).call("setup", "key:Q" if kb else "LB")
	(_rb_glyph as Object).call("setup", "key:E" if kb else "RB")
	(_view_glyph as Object).call("setup", "key:TAB" if kb else "VIEW")
	# WK-166 (G1, CC-1.6): the four chrome chips get the same "/" twin as the footer on a mixed couch:
	# [B] / [ESC] NOT JOINED? HOLD TO EXIT · [LB] / [Q] ... [RB] / [E] · [VIEW] / [TAB] RULES.
	var sports_tray: bool = _mode == "sports"   # SPORTS has no LB / RB (seat count comes from FORMAT)
	for pair in [["Header/BackBtn/Row/BackSlash", "Header/BackBtn/Row/BackGlyph2", true],
			["CpuRow/CpuTray/Row/LBSlash", "CpuRow/CpuTray/Row/LBGlyph2", not sports_tray],
			["CpuRow/CpuTray/Row/RBSlash", "CpuRow/CpuTray/Row/RBGlyph2", not sports_tray],
			["RulesRow/RulesBar/Row/ViewSlash", "RulesRow/RulesBar/Row/ViewGlyph2", true]]:
		var on: bool = mixed and bool(pair[2])
		(get_node(str(pair[0])) as Control).visible = on
		(get_node(str(pair[1])) as Control).visible = on
	_refresh_back_chip()
	(get_node("Footer/HintRow/GFlair/Glyph") as Object).call("setup", "arrows" if kb else "stick")   # WK-29: no stick on a keyboard
	# WK-157 (CD4-07a, CC-1.6 / CC-1.7): with a pad AND the keyboard seated, the footer was pad-only (A / B / Y / stick),
	# so the keyboard player had no footer prompt at all while ArenaSelect already said "A / ENTER". A mixed couch now
	# sees both twins on every footer chip: [A] / [ENTER] JOIN / READY · [B] / [ESC] BACK OUT · [Y] / [R] RANDOM ·
	# (+) / [< >] GOAT / FLAIR. Static (join / leave only), so nothing flickers while four people mash.
	var twins := {"GJoin": "key:ENTER", "GBack": "key:ESC", "GRandom": "key:R", "GFlair": "arrows"}
	for gn in twins:
		var g2: Control = get_node("Footer/HintRow/%s/Glyph2" % gn) as Control
		var sl: Control = get_node("Footer/HintRow/%s/Slash" % gn) as Control
		g2.visible = mixed
		sl.visible = mixed
		if mixed:
			(g2 as Object).call("setup", str(twins[gn]))
	(_go_glyph as Object).call("setup", "key:ENTER" if kb else "START")
	# dual GO prompt for a mixed couch (WK-138: GO lives only on the banner, never in the footer)
	_go_slash.visible = mixed
	_go_wrap2.visible = mixed
	if mixed:
		(_go_glyph as Object).call("setup", "START")
		(_go_glyph2 as Object).call("setup", "key:ENTER")
	# the banner glyphs are drawn 1.5x inside plain wrappers (containers reset child scale): size the wraps
	_go_wrap.custom_minimum_size = (_go_glyph as Control).custom_minimum_size * 1.5
	_go_wrap2.custom_minimum_size = (_go_glyph2 as Control).custom_minimum_size * 1.5
	# amber hint: the lone human's own device
	var lone := ""
	for s in slots:
		if s["state"] != S_EMPTY and s["state"] != S_DISC:
			lone = str(s["device"]) if lone == "" else "many"
	var hint_kb: bool = lone == "kb" or (lone == "" and kb)
	(_hint_glyph as Object).call("setup", "key:E" if hint_kb else "RB")

## WK-138 (UX4-05 / UX4-03, CC-1.7): the top-left chip is the lobby's ONE exit prompt and must be true for whoever
## reads it. Nobody joined: a tap backs out ("BACK"). Anyone joined: only a device that is NOT seated arms the
## hold-to-exit (WK-82 — a seated B un-readies / backs out instead), so the chip says exactly that.
func _refresh_back_chip() -> void:
	var anyone: bool = _joined_count() > 0   # DISCONNECTED seats count as joined (their grace window holds the lobby)
	_back_label.text = "NOT JOINED? HOLD TO EXIT" if anyone else "BACK"
	# WK-166: the mixed-couch "B / ESC" twin widens the chip toward the title; 28 px (CC-8.1 floor) + tighter gaps keep
	# a clear margin before "CHOOSE YOUR GOAT"
	var twin: bool = (get_node("Header/BackBtn/Row/BackGlyph2") as Control).visible
	_back_label.add_theme_font_size_override("font_size", (28 if twin else 30) if anyone else 36)
	_back_row.add_theme_constant_override("separation", 8 if twin else 12)
	_fit_back_chip()
	call_deferred("_fit_back_chip")   # WK-166: re-fit after the row's min size settles (twin glyph shown / hidden)
	# ux lobby verdict Fix 2: an empty lobby has ONE exit prompt (the chip's "B BACK") and only the verb that works
	# there (JOIN). BACK OUT / RANDOM / GOAT-FLAIR come back with the first seat.
	(get_node("Footer/HintRow/GJoin/Label") as Label).text = "JOIN / READY" if anyone else "JOIN"
	for n in ["GBack", "GRandom", "GFlair"]:
		(get_node("Footer/HintRow/" + n) as Control).visible = anyone

func _fit_back_chip() -> void:
	var pad: float = 32.0 if (get_node("Header/BackBtn/Row/BackGlyph2") as Control).visible else 44.0   # WK-166
	var w: float = maxf(220.0, _back_row.get_combined_minimum_size().x + pad)
	_back_btn.size.x = w

# ================================================================== misc
func _on_device_lost(key: String) -> void:
	# WK-28a (CC-3.5): an unplugged pad's seat goes DISCONNECTED (goat + colour kept, grace countdown) instead of
	# emptying; the pad itself, or any unseated device pressing A / Enter, takes it back over.
	if _rules_owner == key:
		_close_rules(false)   # owner pad gone: the RULES flip closes KEEPING the values
	var si := _slot_of(key)
	if si >= 0:
		_disconnect(si)

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
## WK-52 / CD3-07: a cream ToyPanel banner card (gold NEW FLAIR! chip, the item in a disc of its own colour, and
## who owns it) drops from the top into the header band. It covers the title for ~3 s, never a slot's name.
## The flair ladder is banked from every human's KOs and every slot's FLAIR row can wear it, so the owner
## line names the whole herd.
func _play_flair_celebration(fid: String) -> void:
	var item: Dictionary = Settings.flair_item(fid)
	var display := str(item.get("name", fid)).to_upper()
	get_tree().create_timer(Tuning.unlock_card_delay).timeout.connect(func() -> void:
		if not is_instance_valid(_unlock_card):
			return
		AudioManager.play_sfx("ui_click", {"pitch": 1.5, "pitch_var": 0.0, "volume_db": 0.0})
		EventBus.match_won.emit(0)   # reuse the win fanfare sting (presentation only)
		_unlock_name.text = display
		_unlock_owner.text = "THE HERD'S %d KOs EARNED IT  ·  EVERY PLAYER CAN WEAR IT" % int(item.get("threshold", 0))
		# WK-145 (UX4-26): the disc shows the flair itself, worn by a tiny goat (P1's, or the first seated goat), over
		# a twilight sky (Tuning.unlock_icon_sky) so the glowing streak / flame / pop / ribbon reads; the generic star is gone.
		var base: StyleBox = _unlock_icon.get_theme_stylebox("panel")
		if base is StyleBoxFlat:
			var sb: StyleBoxFlat = (base as StyleBoxFlat).duplicate()
			sb.bg_color = Tuning.unlock_icon_sky
			_unlock_icon.add_theme_stylebox_override("panel", sb)
		(_unlock_swatch as Object).call("setup", item, _portrait(_unlock_goat()))
		ToyKit.fill_panel(_unlock_panel, ToyKit.CREAM)   # opaque: the plate's 0.97 alpha let the title ghost through
		_unlock_card.visible = true
		_unlock_card.modulate.a = 1.0
		_unlock_card.move_to_front()   # MenuScreen.enter raised the Header; the card is the one thing allowed over it
		var rest_y: float = 10.0   # the scene's offset_top
		_unlock_card.position.y = -_unlock_card.size.y
		var tb := _unlock_card.create_tween()
		tb.tween_property(_unlock_card, "position:y", rest_y, Tuning.unlock_card_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tb.tween_interval(Tuning.unlock_card_hold)
		tb.tween_property(_unlock_card, "position:y", -_unlock_card.size.y, Tuning.unlock_card_out).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tb.tween_callback(func() -> void:
			_unlock_card.visible = false
			_unlock_card.position.y = rest_y))

## WK-145: whose goat models the new flair on the unlock card: the first seated slot's goat, else the first goat.
func _unlock_goat() -> int:
	for s in slots:
		if s["state"] != S_EMPTY:
			return int(s["goat"])
	return 0
