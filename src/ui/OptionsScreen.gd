extends MenuScreen
## Options — toy sliders + pill toggle wired to the Settings autoload (frontend_ux_spec §2.5). Live +
## write-through (no apply button). Reachable from MainMenu (stacked in the shell) AND from PauseMenu
## (hosted standalone: shell is null, so back emits `back_requested` for the host to handle).

signal back_requested

const SLIDER := preload("res://scenes/ui/ToySlider.tscn")
const TOGGLE := preload("res://scenes/ui/ToyToggle.tscn")
const ACCENT := Color("#ff5fa8")

@onready var _rows_box: VBoxContainer = $Panel/VBox
@onready var _back: Button = $Header/BackBtn

var _rows: Array = []

func _ready() -> void:
	var master = _add_slider("MASTER VOLUME", Settings.master)
	master.changed.connect(func(v: float) -> void: Settings.set_master(v))
	var music = _add_slider("MUSIC VOLUME", Settings.music)
	music.changed.connect(func(v: float) -> void: Settings.set_music(v))
	var sfx = _add_slider("SFX VOLUME", Settings.sfx)
	sfx.changed.connect(func(v: float) -> void: Settings.set_sfx(v))
	var fs = _add_toggle("FULLSCREEN", Settings.fullscreen)
	fs.changed.connect(func(v: bool) -> void: Settings.set_fullscreen(v))
	wire_col(_rows)
	register(_back, 1.05)
	_rows[_rows.size() - 1].focus_neighbor_bottom = _rows[_rows.size() - 1].get_path_to(_back)
	_back.focus_neighbor_top = _back.get_path_to(_rows[0])

func first_focus() -> Control:
	return _rows[0]

func stagger_items() -> Array:
	return _rows

func on_back() -> void:
	if shell != null:
		shell.go_back()
	else:
		back_requested.emit()

func _add_slider(title: String, v: float):
	var s := SLIDER.instantiate()
	_rows_box.add_child(s)
	s.setup(title, v, ACCENT)
	register(s, 1.04)
	s.focus_entered.connect(func() -> void: s.set_focus_active(true))
	s.focus_exited.connect(func() -> void: s.set_focus_active(false))
	_rows.append(s)
	return s

func _add_toggle(title: String, b: bool):
	var t := TOGGLE.instantiate()
	_rows_box.add_child(t)
	t.setup(title, b, ACCENT)
	register(t, 1.04)
	t.focus_entered.connect(func() -> void: t.set_focus_active(true))
	t.focus_exited.connect(func() -> void: t.set_focus_active(false))
	_rows.append(t)
	return t
