extends MenuScreen
## Options — toy sliders + pill toggle wired to the Settings autoload (frontend_ux_spec §2.5). Live +
## write-through (no apply button). Reachable from MainMenu (stacked in the shell) AND from PauseMenu
## (hosted standalone: shell is null, so back emits `back_requested` for the host to handle).
##
## WK-34 Toybox panel kit A: one centred cream ToyPanel (the lobby / pause plate) with a ToyRibbon header —
## pink in the shell, the pause owner's goat colour when hosted by the PauseMenu — rows in ToyRow wells
## (focus = ToyRowFocus gold well + 1.04 scale), and the footer hint strip inside the plate. The old focusable
## "< BACK" button is now a non-focusable glyph chip in the ribbon (CC-5.5: B goes back, the chip is only for
## the mouse), and the navy plate, the screen-corner BACK and the screen-corner "v0.1" (which sat over the P1 / P4
## HUD cards, R-22) are gone: nothing is drawn outside the plate.

signal back_requested

const SLIDER := preload("res://scenes/ui/ToySlider.tscn")
const TOGGLE := preload("res://scenes/ui/ToyToggle.tscn")
const ACCENT := Color("#ff5fa8")

@onready var _panel: PanelContainer = $Panel
@onready var _ribbon: PanelContainer = $Panel/VBox/Ribbon
@onready var _rows_box: VBoxContainer = $Panel/VBox/Rows
@onready var _back_chip: Button = $Panel/VBox/Ribbon/Row/BackChip
@onready var _back_glyph: Control = $Panel/VBox/Ribbon/Row/BackChip/Inner/Glyph
@onready var _hints: HBoxContainer = $Panel/VBox/FooterRow/HintBox

var _rows: Array = []
var _accent := ACCENT
var _pause_owner := ""      # "" = shell-hosted; else the pause owner's device key
var _hosted := false

func _ready() -> void:
	var master = _add_slider("MASTER VOLUME", Settings.master)
	master.changed.connect(func(v: float) -> void: Settings.set_master(v))
	var music = _add_slider("MUSIC VOLUME", Settings.music)
	music.changed.connect(func(v: float) -> void: Settings.set_music(v))
	var sfx = _add_slider("SFX VOLUME", Settings.sfx)
	sfx.changed.connect(func(v: float) -> void: Settings.set_sfx(v))
	var fs = _add_toggle("FULLSCREEN", Settings.fullscreen)
	fs.changed.connect(func(v: bool) -> void: Settings.set_fullscreen(v))
	wire_col(_rows)   # 4 rows, wrap top<->bottom; Back is B (CC-5.5), never in the focus chain
	_back_chip.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", {"pitch": 0.72, "pitch_var": 0.0, "volume_db": -4.0})
		on_back())
	_apply_accent()
	_refresh_glyphs()
	# shell-hosted: the front end's glyphs follow the last device (a pad pressed mid-screen swaps the key caps)
	InputRouter.last_device_changed.connect(_on_last_device)   # a bound method: auto-disconnects when we are freed

func _on_last_device(_k: String) -> void:
	if not _hosted:
		_refresh_glyphs()

func first_focus() -> Control:
	return _rows[0]

## WK-80(c): hosted by the PauseMenu. The pause's chocolate scrim already dims the frozen arena (its HUD is
## hidden for the whole pause), so drop our own scrim, and say how to get straight back to the match in the
## pause owner's glyphs: pad Start resumes; on the keyboard Esc is Back and P resumes (PauseMenu).
## WK-34: the ribbon + focused fills wear the pause owner's colour (the plate the player just left had it).
func set_pause_host(owner_key: String, owner_color: Color = ACCENT) -> void:
	_hosted = true
	_pause_owner = owner_key
	_accent = owner_color
	var scrim := get_node_or_null("Scrim") as ColorRect
	if scrim != null:
		scrim.color.a = 0.0
	_apply_accent()
	_refresh_glyphs()

func _is_kb() -> bool:
	if _hosted:
		return _pause_owner == InputRouter.KB
	return InputRouter.last_device_kind == "kb"

## Glyphs follow the owner's device when pause-hosted (CC-1.6 personal prompt), else the last-used device
## (the front end before anyone has joined).
func _refresh_glyphs() -> void:
	var kb := _is_kb()
	_back_glyph.call("setup", "key:ESC" if kb else "B")
	var h: PackedStringArray
	if kb:
		h = PackedStringArray(["key:A/D|Adjust"])
		if _hosted:
			h.append("key:P|Resume")
	else:
		h = PackedStringArray(["< >|Adjust"])
		if _hosted:
			h.append("START|Resume")
	_hints.call("set_hints", h)

func _apply_accent() -> void:
	var sb: StyleBox = _ribbon.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var rb: StyleBoxFlat = (sb as StyleBoxFlat).duplicate()
		rb.bg_color = _accent
		_ribbon.add_theme_stylebox_override("panel", rb)
	for r in _rows:
		if r.has_method("set_accent"):
			r.set_accent(_accent)

func accent_for(_c: Control) -> Color:
	return _accent

func stagger_items() -> Array:
	return _rows

## Plate drop-pop (the PauseMenu's juice), then the rows stagger in (MenuScreen.enter).
func enter() -> void:
	_panel.pivot_offset = _panel.get_combined_minimum_size() * 0.5   # layout may not have run yet
	_panel.scale = Vector2(0.9, 0.9)
	var t := _panel.create_tween()
	t.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	super.enter()

func on_back() -> void:
	if shell != null:
		shell.go_back()
	else:
		back_requested.emit()

func _add_slider(title: String, v: float):
	var s := SLIDER.instantiate()
	_rows_box.add_child(s)
	s.setup(title, v, _accent)
	register(s, 1.04)
	s.focus_entered.connect(func() -> void: s.set_focus_active(true))
	s.focus_exited.connect(func() -> void: s.set_focus_active(false))
	_rows.append(s)
	return s

func _add_toggle(title: String, b: bool):
	var t := TOGGLE.instantiate()
	_rows_box.add_child(t)
	t.setup(title, b, _accent)
	register(t, 1.04)
	t.focus_entered.connect(func() -> void: t.set_focus_active(true))
	t.focus_exited.connect(func() -> void: t.set_focus_active(false))
	_rows.append(t)
	return t
