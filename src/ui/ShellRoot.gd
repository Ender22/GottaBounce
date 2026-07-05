extends Node
## ShellRoot — the persistent front-end (v1_frontend_shell §1.2; frontend_ux_spec §1.5). Boots on
## MainMenu and swaps ONE screen child at a time under a shared living backdrop, with the springy
## forward/back transition grammar. Selections write GameConfig.match_config; ArenaSelect CONFIRM
## fires the match-start iris and the real scene change to Arena.tscn. Returning from a match (Pause
## Quit-to-Menu / match-end QUIT) change_scene's back to this scene, landing on MainMenu again.

const DESIGN := Vector2(1920, 1080)
const MATCH_SCENE := "res://scenes/Arena.tscn"
const SCREENS := {
	"main": preload("res://scenes/ui/MainMenu.tscn"),
	"mode": preload("res://scenes/ui/ModeSelect.tscn"),
	"character": preload("res://scenes/ui/CharacterSelect.tscn"),
	"arena": preload("res://scenes/ui/ArenaSelect.tscn"),
	"options": preload("res://scenes/ui/Options.tscn"),
}

@onready var _screen_layer: CanvasLayer = $ScreenLayer
@onready var _overlay: CanvasLayer = $OverlayLayer

var _cur: Control = null
var _cur_key := ""
var _stack: Array[String] = []
var _busy := false

func _ready() -> void:
	# a fresh config on cold boot so an untouched flow reproduces today's default boot (C7)
	if GameConfig.match_config == null:
		GameConfig.reset_to_defaults()
	_show("main", true)

# ------------------------------------------------------------------ navigation API (screens call these)
func go_forward(key: String) -> void:
	if _busy or not SCREENS.has(key):
		return
	_stack.append(_cur_key)
	_show(key, true)

func go_back() -> void:
	if _busy or _stack.is_empty():
		return
	var key: String = _stack.pop_back()
	_show(key, false)

# ------------------------------------------------------------------ screen swap + transition
func _show(key: String, forward: bool) -> void:
	_busy = true
	var old := _cur
	var screen: Control = (SCREENS[key] as PackedScene).instantiate()
	_screen_layer.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.pivot_offset = DESIGN * 0.5
	if screen.has_method("setup"):
		screen.setup(self)
	screen.scale = Vector2(1.06, 1.06) if forward else Vector2(0.95, 0.95)
	screen.modulate.a = 0.0
	_cur = screen
	_cur_key = key

	var tin := screen.create_tween()
	tin.set_parallel(true)
	tin.tween_property(screen, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tin.tween_property(screen, "modulate:a", 1.0, 0.24)
	if screen.has_method("enter"):
		screen.enter()

	if old != null and is_instance_valid(old):
		old.pivot_offset = DESIGN * 0.5
		var s_out := Vector2(0.95, 0.95) if forward else Vector2(1.06, 1.06)
		var tout := old.create_tween()
		tout.set_parallel(true)
		tout.tween_property(old, "scale", s_out, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tout.tween_property(old, "modulate:a", 0.0, 0.18)
		tout.chain().tween_callback(old.queue_free)

	get_tree().create_timer(0.30).timeout.connect(func() -> void: _busy = false)

# ------------------------------------------------------------------ match launch (ArenaSelect CONFIRM)
func launch_match() -> void:
	if _busy:
		return
	_busy = true
	_iris_then(func() -> void: get_tree().change_scene_to_file(MATCH_SCENE))

## Match-start iris: a chocolate-outlined cream circle scales up from screen center to cover, then
## performs the real scene change under cover (frontend_ux_spec §1.5).
func _iris_then(cb: Callable) -> void:
	var iris := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.98)
	sb.border_color = MenuFX.CHOCO
	sb.set_border_width_all(10)
	sb.set_corner_radius_all(300)
	iris.add_theme_stylebox_override("panel", sb)
	iris.size = Vector2(600, 600)
	iris.position = DESIGN * 0.5 - Vector2(300, 300)
	iris.pivot_offset = Vector2(300, 300)
	iris.scale = Vector2(0.0, 0.0)
	_overlay.add_child(iris)
	var t := iris.create_tween()
	t.tween_property(iris, "scale", Vector2(6.0, 6.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(cb)
