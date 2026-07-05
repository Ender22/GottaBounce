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

var _cards: Array[Button] = []
var _steppers: Array = []
var _trials := false      # TRIALS is solo (no bot/kills/lives strip; lock-in launches the run directly)
var _gauntlet := false    # GAUNTLET is solo too (waves spawn dynamically; lock-in launches directly)
var _current := 0
var _locked := false
var _pose_rest := Vector2.ZERO
var _idle_tween: Tween
var _spinning := false

func _ready() -> void:
	_trials = GameConfig.match_config != null and GameConfig.match_config.mode_id == &"trials"
	_gauntlet = GameConfig.match_config != null and GameConfig.match_config.mode_id == &"gauntlet"
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
	if _trials or _gauntlet:
		var tray := get_node_or_null("SettingsTray")
		if tray != null:
			(tray as CanvasItem).visible = false
	else:
		var cfg: MatchConfig = GameConfig.match_config
		_add_stepper("HUMANS", ["1", "2", "3", "4"], [1, 2, 3, 4], cfg.human_count - 1, _on_humans)
		_add_stepper("BOTS", ["0", "1", "2", "3", "4", "5", "6", "7"], [0, 1, 2, 3, 4, 5, 6, 7], cfg.bot_count, _on_bots)
		_add_stepper("BOT SKILL", ["Mixed", "1", "2", "3", "4", "5"], [0, 1, 2, 3, 4, 5], cfg.bot_difficulty, _on_skill)
		_add_stepper("KILLS", ["5", "7", "8", "10"], [5, 7, 8, 10], _index_of([5, 7, 8, 10], cfg.kills_to_win, 3), _on_kills)
		_add_stepper("LIVES", ["1", "2", "3"], [1, 2, 3], _index_of([1, 2, 3], cfg.lives_per_player, 0), _on_lives)
		wire_col(_steppers)
		# grid<->strip: Down from bottom row -> first stepper, Up from first stepper -> grid
		for i in range(3, _cards.size()):
			_cards[i].focus_neighbor_bottom = _cards[i].get_path_to(_steppers[0])
		_steppers[0].focus_neighbor_top = _steppers[0].get_path_to(_cards[3])

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
	_name.text = str(h["name"])
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

# ------------------------------------------------------------------ helpers
func _tex(skin: Variant) -> Texture2D:
	var p: String = SPRITE % str(skin)
	return load(p) if ResourceLoader.exists(p) else null

func _index_of(arr: Array, v: Variant, fallback: int) -> int:
	var idx := arr.find(v)
	return idx if idx >= 0 else fallback
