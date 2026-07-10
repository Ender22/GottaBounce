extends MenuScreen
## CharacterSelect — THE showcase (frontend_ux_spec §2.3). Split stage: the picked hero bounces big on
## a color spotlight with a bold name banner + blurb (left); a 2x3 hero grid glowing in each hero's
## colour (right); a match-settings stepper strip under the grid. Character-swap toss/bounce on every
## focus move, Random slot, lock-in with check stamp + goat-roar callout, P1 pick-cursor flag.
##
## Consumes per-character slots (§2.3.1) so it renders from data and never hardcodes a hero — today the
## portrait/beauty_pose are the six real idle sprites; when painted art lands only the texture swaps.

const CARD := preload("res://scenes/ui/MenuCard.tscn")
const STEPPER := preload("res://scenes/ui/Stepper.tscn")
const SPRITE := "res://assets/characters/bouncer_%s_idle.png"

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
const P1_COLOR := Color("#ff5fa8")

@onready var _grid: GridContainer = $Grid
@onready var _strip_row: HBoxContainer = $SettingsTray/StripRow
@onready var _spotlight: Panel = $Stage/Spotlight
@onready var _pose: TextureRect = $Stage/Pose
@onready var _banner: Panel = $Stage/NameBanner
@onready var _name: Label = $Stage/NameBanner/HeroName
@onready var _blurb: Label = $Stage/Blurb
@onready var _back: Button = $Header/BackBtn
@onready var _ready_prompt: Label = $ReadyPrompt
@onready var _p1flag: Control = $P1Flag
@onready var _flair_stepper: Control = $Stage/FlairStepper
@onready var _ko_chip: Label = $Stage/KOChip/ChipLabel

var _cards: Array[Button] = []
var _steppers: Array = []
var _flair_vals: Array = []        # stepper vals: "" (NONE), unlocked ids, "__locked" tease sentinel
var _pending_flair := ""           # consume-once celebration id (taken in _ready, fired in enter())
var _trials := false      # TRIALS is solo (no bot/kills/lives strip; lock-in launches the run directly)
var _gauntlet := false    # GAUNTLET is solo too (waves spawn dynamically; lock-in launches directly)
var _sports := false      # SPORTS is a team preset (1v1: 1 human + 1 bot; single mode-owned arena)
var _current := 0
var _locked := false
var _pose_rest := Vector2.ZERO
var _idle_tween: Tween
var _spinning := false

func _ready() -> void:
	_trials = GameConfig.match_config != null and GameConfig.match_config.mode_id == &"trials"
	_gauntlet = GameConfig.match_config != null and GameConfig.match_config.mode_id == &"gauntlet"
	_sports = GameConfig.match_config != null and GameConfig.match_config.mode_id == &"sports"
	# build the 2x3 hero grid
	for i in range(HEROES.size()):
		var h: Dictionary = HEROES[i]
		var card: Button = CARD.instantiate()
		card.custom_minimum_size = Vector2(250, 250)
		_grid.add_child(card)
		var tex: Texture2D = _tex(h["skin"])
		card.set_card({
			"name": h["name"], "tag": "", "color": h["color"], "art": tex,
		})
		card.set_meta("hero", h)
		register(card, 1.14)
		card.focus_entered.connect(_on_hero_focus.bind(i))
		_cards.append(card)
	wire_grid(_cards, 3)

	# match-settings strip. TRIALS is solo (1 human, no bots, no kill target) — HIDE the strip and skip
	# its focus wiring; a hero lock-in launches the run directly (see _go_arena). BRAWL keeps the strip.
	register(_back, 1.05)
	if _trials or _gauntlet or _sports:
		var tray := get_node_or_null("SettingsTray")
		if tray != null:
			(tray as CanvasItem).visible = false
	else:
		var cfg: MatchConfig = GameConfig.match_config
		_add_stepper("HUMANS", ["1", "2", "3", "4"], [1, 2, 3, 4], cfg.human_count - 1, _on_humans)
		_add_stepper("BOTS", ["0", "1", "2", "3", "4", "5", "6", "7"], [0, 1, 2, 3, 4, 5, 6, 7], cfg.bot_count, _on_bots)
		# "MIX" (was "Mixed") keeps the 40px value inside the stepper's width budget (audit P3 type pass)
		_add_stepper("BOT SKILL", ["MIX", "1", "2", "3", "4", "5"], [0, 1, 2, 3, 4, 5], cfg.bot_difficulty, _on_skill)
		_add_stepper("KILLS", ["5", "7", "8", "10"], [5, 7, 8, 10], _index_of([5, 7, 8, 10], cfg.kills_to_win, 3), _on_kills)
		_add_stepper("LIVES", ["1", "2", "3"], [1, 2, 3], _index_of([1, 2, 3], cfg.lives_per_player, 0), _on_lives)
		wire_col(_steppers)
		# grid<->strip: Down from bottom row -> first stepper, Up from first stepper -> grid
		for i in range(3, _cards.size()):
			_cards[i].focus_neighbor_bottom = _cards[i].get_path_to(_steppers[0])
		_steppers[0].focus_neighbor_top = _steppers[0].get_path_to(_cards[3])

	# v11 FLAIR track (§5.4): stepper + KO-tally chip live on the STAGE, so they exist in ALL modes
	# (the SettingsTray hides for Trials/Gauntlet/Sports; the stage never does). Consume the pending
	# unlock NOW; enter() fires the one-shot celebration after the stagger (ArenaSelect pattern §5.5).
	_setup_flair()
	_pending_flair = Settings.take_pending_flair_unlock()

	# P1 pick-cursor flag colour
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = P1_COLOR
	fsb.border_color = MenuFX.CHOCO
	fsb.set_border_width_all(3)
	fsb.set_corner_radius_all(10)
	_p1flag.add_theme_stylebox_override("panel", fsb)
	# seed the stage styleboxes so nothing flashes grey before the first hero applies
	_set_glow_color(Color(P1_COLOR.r, P1_COLOR.g, P1_COLOR.b, 0.5))
	_set_banner_color(P1_COLOR)

	_setup_stage()

func first_focus() -> Control:
	return _cards[0]

func stagger_items() -> Array:
	return _cards

func accent_for(c: Control) -> Color:
	if c.has_meta("hero"):
		return (c.get_meta("hero") as Dictionary).get("color", P1_COLOR)
	return P1_COLOR

func activate(c: Control) -> void:
	if c == _back:
		on_back()
		return
	if not c.has_meta("hero"):
		return
	if _locked:
		_go_arena()
	else:
		_lock_in(c)

func on_back() -> void:
	if _locked:
		_unlock()
	elif shell != null:
		shell.go_back()

# ------------------------------------------------------------------ stage
func _setup_stage() -> void:
	await get_tree().process_frame
	_pose_rest = _pose.position
	_apply_hero(0, false)
	_start_idle()
	# seat the P1 pick-cursor flag on the first hero at entry (it then follows focus)
	if is_instance_valid(_p1flag) and _cards.size() > 0:
		if _p1flag.get_parent() != null:
			_p1flag.get_parent().remove_child(_p1flag)
		_cards[0].add_child(_p1flag)
		_p1flag.position = Vector2(8, 8)
		_p1flag.visible = true

func _on_hero_focus(i: int) -> void:
	if i == _current:
		return
	if _locked:
		_unlock()
	_apply_hero(i, true)
	if i < _cards.size():
		(_cards[i] as Object).call("notice_bounce")
	# move the P1 pick-cursor flag onto the hovered card
	if is_instance_valid(_p1flag):
		if _p1flag.get_parent() != null:
			_p1flag.get_parent().remove_child(_p1flag)
		_cards[i].add_child(_p1flag)
		_p1flag.position = Vector2(8, 8)
		_p1flag.visible = true

func _apply_hero(i: int, animate: bool) -> void:
	_current = i
	var h: Dictionary = HEROES[i]
	var col: Color = h["color"]
	_set_banner_name(str(h["name"]))
	_blurb.text = str(h["blurb"])
	_recolor_stage(col)
	var tex: Texture2D = _tex(h["skin"])
	if not animate:
		_pose.texture = tex
		return
	# character-swap: whip the old pose out, bounce the new one in (§5)
	_kill_idle()
	var out := _pose.create_tween()
	out.set_parallel(true)
	out.tween_property(_pose, "position:x", _pose_rest.x + 90.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(_pose, "rotation", deg_to_rad(-12.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(_pose, "modulate:a", 0.0, 0.14)
	out.chain().tween_callback(func() -> void:
		_pose.texture = tex
		_pose.position = _pose_rest + Vector2(90, 0)
		_pose.rotation = 0.0
		_pose.scale = Vector2(0.7, 0.7)
		var ip := _pose.create_tween()
		ip.set_parallel(true)
		ip.tween_property(_pose, "position", _pose_rest, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ip.tween_property(_pose, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ip.tween_property(_pose, "modulate:a", 1.0, 0.18)
		ip.chain().tween_callback(_start_idle))

func _recolor_stage(col: Color) -> void:
	# spotlight glow + name-banner colour cross-fade
	var from_glow: Color = _glow_color()
	var tg := _spotlight.create_tween()
	tg.tween_method(_set_glow_color, from_glow, Color(col.r, col.g, col.b, 0.5), 0.2)
	var from_ban: Color = _banner_color()
	var tb := _banner.create_tween()
	tb.tween_method(_set_banner_color, from_ban, col, 0.2)

func _glow_color() -> Color:
	var sb := _spotlight.get_theme_stylebox("panel")
	return (sb as StyleBoxFlat).shadow_color if sb is StyleBoxFlat else Color(1, 0.37, 0.66, 0.5)

func _set_glow_color(c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c.r, c.g, c.b, 0.10)
	sb.set_corner_radius_all(260)
	sb.shadow_color = c
	sb.shadow_size = 90
	_spotlight.add_theme_stylebox_override("panel", sb)

func _banner_color() -> Color:
	var sb := _banner.get_theme_stylebox("panel")
	return (sb as StyleBoxFlat).bg_color if sb is StyleBoxFlat else Color("#ff5fa8")

func _set_banner_color(c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = MenuFX.CHOCO
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(16)
	_banner.add_theme_stylebox_override("panel", sb)

func _start_idle() -> void:
	_kill_idle()
	if not is_instance_valid(_pose):
		return
	_pose.pivot_offset = _pose.size * 0.5
	_idle_tween = _pose.create_tween().set_loops()
	_idle_tween.tween_property(_pose, "scale", Vector2(0.96, 1.06), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(_pose, "scale", Vector2(1.06, 0.94), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _kill_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()

# ------------------------------------------------------------------ lock / random
func _lock_in(card: Button) -> void:
	_locked = true
	var h: Dictionary = card.get_meta("hero")
	var cfg: MatchConfig = GameConfig.match_config
	var skins := cfg.skin_ids
	while skins.size() < 1:
		skins.append("pink")
	skins[0] = str(h["skin"])
	cfg.skin_ids = skins
	cfg.character_ids = PackedStringArray(["bouncer"])
	(card as Object).call("show_check", true)
	AudioManager.play_sfx("super_fire", {"volume_db": -4.0})   # the goat-roar callout (§3.4)
	# pose jump on stage
	_kill_idle()
	var t := _pose.create_tween()
	t.tween_property(_pose, "position:y", _pose_rest.y - 60.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_pose, "position:y", _pose_rest.y, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(_start_idle)
	_ready_prompt.visible = true
	_ready_prompt.modulate.a = 0.0
	var tp := _ready_prompt.create_tween()
	tp.tween_property(_ready_prompt, "modulate:a", 1.0, 0.2)

func _unlock() -> void:
	_locked = false
	_ready_prompt.visible = false
	if _current < _cards.size():
		(_cards[_current] as Object).call("show_check", false)

func _go_arena() -> void:
	if shell == null:
		return
	if _trials:
		# TRIALS skips ArenaSelect (courses are the mode's own authored set) and launches straight in.
		var cfg: MatchConfig = GameConfig.match_config
		cfg.mode_id = &"trials"
		cfg.human_count = 1
		cfg.bot_count = 0
		shell.launch_match()
	elif _gauntlet:
		# GAUNTLET skips ArenaSelect (single mode-owned arena) and launches straight in: solo, no config-
		# time bots (waves spawn dynamically), and lives_per_player re-read as the DEFENDER LIFE POOL (4).
		var cfg: MatchConfig = GameConfig.match_config
		cfg.mode_id = &"gauntlet"
		cfg.human_count = 1
		cfg.bot_count = 0
		cfg.lives_per_player = 4
		shell.launch_match()
	elif _sports:
		# SPORTS: set the team preset here (1v1: 1 human + 1 bot = even total 2), then go to the
		# court select (ArenaSelect in sports guise, one COURTS shelf) which assigns arena_mode +
		# single_arena_path (a court ID; SportsMode resolves it) and launches. SportsMode overrides
		# skins by team colorway + forces the runner economy inert; the goal cap comes from
		# Tuning.sports_goal_target (split from kills_to_win).
		var cfg: MatchConfig = GameConfig.match_config
		cfg.mode_id = &"sports"
		cfg.human_count = 1
		cfg.bot_count = 1
		shell.go_forward("arena")
	else:
		shell.go_forward("arena")

func _unhandled_input(e: InputEvent) -> void:
	super._unhandled_input(e)
	if not _entered or _spinning:
		return
	if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_R:
		_random_pick()

func _random_pick() -> void:
	_spinning = true
	var steps := 10 + randi() % 6
	for s in range(steps):
		var idx := randi() % _cards.size()
		_cards[idx].grab_focus()
		AudioManager.play_sfx("ui_click", {"pitch": 1.4, "volume_db": -14.0})
		await get_tree().create_timer(0.045 + 0.006 * s).timeout
	_spinning = false
	if _current < _cards.size():
		(_cards[_current] as Object).call("notice_bounce")

# ------------------------------------------------------------------ steppers
func _add_stepper(title: String, labels: Array, vals: Array, idx: int, cb: Callable) -> void:
	var st := STEPPER.instantiate()
	_strip_row.add_child(st)
	st.configure(title, labels, vals, idx)
	st.changed.connect(cb)
	register(st, 1.06)
	_steppers.append(st)

func _on_humans(_i: int, v: Variant) -> void:
	GameConfig.match_config.human_count = int(v)
	_enforce_counts(true)

func _on_bots(_i: int, v: Variant) -> void:
	GameConfig.match_config.bot_count = int(v)
	_enforce_counts(false)

func _on_skill(_i: int, v: Variant) -> void:
	GameConfig.match_config.bot_difficulty = int(v)

func _on_kills(_i: int, v: Variant) -> void:
	GameConfig.match_config.kills_to_win = int(v)

func _on_lives(_i: int, v: Variant) -> void:
	GameConfig.match_config.lives_per_player = int(v)

## Invariant 2 <= humans+bots <= 8 (§1.3). Nudge bots to satisfy it and reflect in the stepper.
func _enforce_counts(humans_changed: bool) -> void:
	var cfg: MatchConfig = GameConfig.match_config
	var total := cfg.human_count + cfg.bot_count
	if total < 2:
		cfg.bot_count += (2 - total)
	elif total > 8:
		cfg.bot_count -= (total - 8)
	cfg.bot_count = clampi(cfg.bot_count, 0, 7)
	if humans_changed:
		_steppers[1].set_index(cfg.bot_count)   # BOTS stepper vals == index

# ------------------------------------------------------------------ v11 flair (spec §5.4/§5.5)

## Build the FLAIR stepper entries from the DERIVED unlocked set: NONE, every unlocked item by name,
## plus ONE locked tease ("<NAME> — <N> MORE KOs", non-equippable). Also fills the KO-tally chip and
## wires focus (Down from the grid's left column / Down from BACK; Right back into the grid).
func _setup_flair() -> void:
	var labels: Array = ["NONE"]
	_flair_vals = [""]
	for it in Settings.flair_items():
		var fid := str((it as Dictionary).get("id", ""))
		if Settings.is_flair_unlocked(fid):
			labels.append(str((it as Dictionary).get("name", fid)))
			_flair_vals.append(fid)
	var nxt: Dictionary = Settings.next_locked_flair()
	if not nxt.is_empty():
		labels.append("%s — %d MORE KOs" % [str(nxt.get("name", "")), int(nxt.get("threshold", 0)) - Settings.total_kills])
		_flair_vals.append("__locked")
	var idx: int = maxi(0, _flair_vals.find(Settings.equipped_flair))
	(_flair_stepper as Object).call("configure", "FLAIR", labels, _flair_vals, idx)
	(_flair_stepper as Object).connect("changed", _on_flair)
	register(_flair_stepper, 1.06)
	# long item names: compact the value label so the stepper stays inside the stage column
	var v := _flair_stepper.get_node_or_null("VBox/Row/Value")
	if v is Label:
		(v as Label).add_theme_font_size_override("font_size", 24)
		(v as Label).custom_minimum_size = Vector2(330, 0)
		(v as Label).clip_text = true
	_refresh_ko_chip()
	# focus wiring: the stage stepper hangs off BACK and the grid's left column
	_flair_stepper.focus_neighbor_top = _flair_stepper.get_path_to(_back)
	_back.focus_neighbor_bottom = _back.get_path_to(_flair_stepper)
	if _cards.size() > 0:
		_flair_stepper.focus_neighbor_right = _flair_stepper.get_path_to(_cards[0])
		_cards[0].focus_neighbor_left = _cards[0].get_path_to(_flair_stepper)
	if _cards.size() > 3:
		_cards[3].focus_neighbor_left = _cards[3].get_path_to(_flair_stepper)

func _on_flair(_i: int, v: Variant) -> void:
	if str(v) == "__locked":
		return   # tease entry is non-equippable — the previous equipped value stays (C9)
	Settings.set_equipped_flair(str(v))
	# live minimum preview (§5.4): TITLE items render on the name banner immediately
	_set_banner_name(str(HEROES[_current]["name"]))

## KO-tally chip (§5.4): "★ N KOs — NEXT FLAIR AT M", or the completed state past the ladder cap.
func _refresh_ko_chip() -> void:
	var nxt: Dictionary = Settings.next_locked_flair()
	if nxt.is_empty():
		_ko_chip.text = "%d KOs — ALL FLAIR EARNED" % Settings.total_kills
	else:
		_ko_chip.text = "%d KOs — NEXT FLAIR AT %d" % [Settings.total_kills, int(nxt.get("threshold", 0))]

## Name banner text = hero name (+ " — <TITLE>" when a TITLE flair is equipped; smaller face so the
## long suffix fits the banner). This is the slice's live-preview minimum bar (§5.4).
func _set_banner_name(hero_name: String) -> void:
	var fl: Dictionary = Settings.equipped_flair_item()
	if str(fl.get("channel", "")) == "title":
		var fp: Dictionary = fl.get("params", {})
		_name.text = "%s — %s" % [hero_name, str(fp.get("suffix", ""))]
		_name.add_theme_font_size_override("font_size", 40)
	else:
		_name.text = hero_name
		_name.add_theme_font_size_override("font_size", 76)

## One-shot flair-unlock celebration on entry (§5.5 — the exact ArenaSelect grammar): banner flash +
## focus-snap/pop on the FLAIR stepper + the win-fanfare sting. The pending flag was consumed in
## _ready (take_pending_flair_unlock), so re-entering is silent.
func enter() -> void:
	super.enter()
	if _pending_flair != "":
		_play_flair_celebration(_pending_flair)
		_pending_flair = ""

func _play_flair_celebration(fid: String) -> void:
	var banner := get_node_or_null("UnlockBanner")
	var display := str(Settings.flair_item(fid).get("name", fid)).to_upper()
	# delay until the entry stagger has mostly landed, then celebrate
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		AudioManager.play_sfx("ui_click", {"pitch": 1.5, "pitch_var": 0.0, "volume_db": 0.0})
		EventBus.match_won.emit(0)   # reuse the win fanfare sting (presentation only)
		if banner is Label:
			(banner as Label).text = "FLAIR UNLOCKED\n%s" % display
			banner.visible = true
			banner.modulate.a = 0.0
			banner.pivot_offset = banner.size * 0.5
			banner.scale = Vector2(0.7, 0.7)
			var tb := banner.create_tween()
			tb.set_parallel(true)
			tb.tween_property(banner, "modulate:a", 1.0, 0.25)
			tb.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tb.chain().tween_interval(1.4)
			tb.chain().tween_property(banner, "modulate:a", 0.0, 0.4)
			tb.chain().tween_callback(func() -> void: banner.visible = false)
		if is_instance_valid(_flair_stepper):
			_flair_stepper.grab_focus()
			_flair_stepper.pivot_offset = _flair_stepper.size * 0.5
			var tc := _flair_stepper.create_tween()
			tc.tween_property(_flair_stepper, "scale", Vector2(1.14, 1.14), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tc.tween_property(_flair_stepper, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))

# ------------------------------------------------------------------ helpers
func _tex(skin: Variant) -> Texture2D:
	var p: String = SPRITE % str(skin)
	return load(p) if ResourceLoader.exists(p) else null

func _index_of(arr: Array, v: Variant, fallback: int) -> int:
	var idx := arr.find(v)
	return idx if idx >= 0 else fallback
