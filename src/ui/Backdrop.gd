extends Control
## The living title backdrop (visual_brief §1 / frontend_ux_spec §2.1). The SAME grassy-sky art drifts
## behind every shell screen (sub-screens drop their own scrim on top) so the world is never frozen:
## a slow Ken-Burns on the art + the six-goat Herd bobbing/drifting/sway-squashing at different depths.
## Pure presentation (no widgets) so building it in code is fine.

const BG_PATH := "res://assets/ui/title_bg.png"
const SPRITE_DIR := "res://assets/characters/bouncer_%s_idle.png"

# per-bobber: skin, center (design-space 1920x1080), box size, depth alpha
const BOBBERS := [
	{"skin": "green",  "pos": Vector2(300, 430),  "box": 150.0, "a": 0.82},
	{"skin": "purple", "pos": Vector2(980, 250),  "box": 120.0, "a": 0.72},
	{"skin": "yellow", "pos": Vector2(1650, 400), "box": 160.0, "a": 0.85},
	{"skin": "orange", "pos": Vector2(1180, 560), "box": 170.0, "a": 0.9},
	{"skin": "pink",   "pos": Vector2(470, 800),  "box": 300.0, "a": 1.0},
	{"skin": "blue",   "pos": Vector2(1440, 800), "box": 300.0, "a": 1.0},
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_bg()
	for b in BOBBERS:
		_build_bobber(b)

func _build_bg() -> void:
	var bg := TextureRect.new()
	bg.name = "BG"
	if ResourceLoader.exists(BG_PATH):
		bg.texture = load(BG_PATH)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	await get_tree().process_frame
	bg.pivot_offset = bg.size * 0.5
	bg.scale = Vector2(1.02, 1.02)
	var t := bg.create_tween().set_loops()
	t.tween_property(bg, "scale", Vector2(1.08, 1.08), 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(bg, "scale", Vector2(1.02, 1.02), 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_bobber(b: Dictionary) -> void:
	var path: String = SPRITE_DIR % str(b["skin"])
	if not ResourceLoader.exists(path):
		return
	var box: float = float(b["box"])
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.custom_minimum_size = Vector2(box, box)
	tr.size = Vector2(box, box)
	var pos: Vector2 = b["pos"]
	tr.position = pos - Vector2(box, box) * 0.5
	tr.pivot_offset = Vector2(box, box) * 0.5
	tr.modulate = Color(1, 1, 1, float(b["a"]))
	add_child(tr)

	var rest_y := tr.position.y
	var rest_x := tr.position.x
	var bob := randf_range(1.6, 2.4)
	var amp := randf_range(11.0, 16.0)
	# vertical bob
	var ty := tr.create_tween().set_loops()
	ty.tween_property(tr, "position:y", rest_y - amp, bob * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ty.tween_property(tr, "position:y", rest_y + amp, bob * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# squash/stretch synced to the bob (tall at top, wide at bottom) — bounce identity on a still png
	var ts := tr.create_tween().set_loops()
	ts.tween_property(tr, "scale", Vector2(0.96, 1.06), bob * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ts.tween_property(tr, "scale", Vector2(1.06, 0.94), bob * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# slow horizontal drift
	var drift := randf_range(28.0, 46.0)
	var tx := tr.create_tween().set_loops()
	tx.tween_property(tr, "position:x", rest_x - drift, randf_range(4.5, 7.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tx.tween_property(tr, "position:x", rest_x + drift, randf_range(4.5, 7.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# gentle sway
	var tr2 := tr.create_tween().set_loops()
	tr2.tween_property(tr, "rotation", deg_to_rad(3.0), randf_range(2.4, 3.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tr2.tween_property(tr, "rotation", deg_to_rad(-3.0), randf_range(2.4, 3.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
