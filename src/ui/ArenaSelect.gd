extends MenuScreen
## ArenaSelect — "PICK YOUR PEAK" (frontend_ux_spec §2.4). A 4x3 grid: RANDOM ROTATION first (default,
## the fun default) + the 11 pool arenas. A directly confirms+launches (footer "(A) FIGHT!"). Arena
## thumbnails are intentional colored gradient tiles (real thumbnails are a Phase-2 slot swap).
##
## NOTE (deviation, flagged): every pool level's JSON `theme` is "grass", so tinting cards to the theme
## colour would make 11 identical green tiles. To keep the grid readable/varied I assign a per-arena
## accent from a spread palette. When per-arena thumbnails/theme colours land they drop into the slot.

const CARD := preload("res://scenes/ui/MenuCard.tscn")

const RANDOM := {"path": "", "name": "RANDOM ROTATION", "tag": "A new peak every round.",
	"color": Color("#ff5fa8"), "glyph": "?", "random": true}

const ARENAS := [
	{"path": "res://levels/islands_void.json", "name": "Islands Void", "color": Color("#4aa8ff")},
	{"path": "res://levels/grassy_expanse.json", "name": "Grassy Expanse", "color": Color("#54c94a")},
	{"path": "res://levels/drop_chamber.json", "name": "Drop Chamber", "color": Color("#a15fff")},
	{"path": "res://levels/the_spine.json", "name": "The Spine", "color": Color("#ff7a2d")},
	{"path": "res://levels/twin_chasms.json", "name": "Twin Chasms", "color": Color("#2fd0c0")},
	{"path": "res://levels/the_cliff.json", "name": "The Cliff", "color": Color("#ffc93f")},
	{"path": "res://levels/atoll.json", "name": "Atoll", "color": Color("#4ad0a8")},
	{"path": "res://levels/spires.json", "name": "Spires", "color": Color("#ff5fa8")},
	{"path": "res://levels/bumper_gauntlet.json", "name": "Bumper Gauntlet", "color": Color("#ff5a4a")},
	{"path": "res://levels/the_ascent.json", "name": "The Ascent", "color": Color("#7a9cff")},
	{"path": "res://levels/wrecking_yard.json", "name": "Wrecking Yard", "color": Color("#c9a24a")},
]

@onready var _grid: GridContainer = $Grid
@onready var _back: Button = $Header/BackBtn

var _cards: Array[Button] = []

func _ready() -> void:
	var all: Array = [RANDOM]
	all.append_array(ARENAS)
	for a in all:
		var card: Button = CARD.instantiate()
		card.custom_minimum_size = Vector2(340, 210)
		_grid.add_child(card)
		card.set_card({
			"name": a["name"], "tag": a.get("tag", ""), "color": a["color"],
			"glyph": a.get("glyph", ""),
		})
		card.set_meta("arena", a)
		register(card, 1.12)
		_cards.append(card)
		if bool(a.get("random", false)):
			_spin_glyph(card)
	wire_grid(_cards, 4)
	register(_back, 1.05)
	_cards[_cards.size() - 1].focus_neighbor_bottom = _cards[_cards.size() - 1].get_path_to(_back)
	_back.focus_neighbor_top = _back.get_path_to(_cards[0])

func first_focus() -> Control:
	return _cards[0]

func stagger_items() -> Array:
	return _cards

func accent_for(c: Control) -> Color:
	if c.has_meta("arena"):
		return (c.get_meta("arena") as Dictionary).get("color", MenuFX.ACCENT_PINK)
	return MenuFX.ACCENT_PINK

func activate(c: Control) -> void:
	if c == _back:
		on_back()
		return
	var a: Dictionary = c.get_meta("arena", {})
	var cfg: MatchConfig = GameConfig.match_config
	if bool(a.get("random", false)):
		cfg.arena_mode = MatchConfig.ArenaMode.RANDOM_ALL
		cfg.single_arena_path = ""
	else:
		cfg.arena_mode = MatchConfig.ArenaMode.SINGLE
		cfg.single_arena_path = str(a["path"])
	if shell != null:
		shell.launch_match()

func _spin_glyph(card: Button) -> void:
	var glyph := card.get_node_or_null("Content/VBox/Plate/Glyph")
	if glyph == null:
		return
	glyph.pivot_offset = glyph.size * 0.5
	var t := glyph.create_tween().set_loops()
	t.tween_property(glyph, "rotation", TAU, 4.0).from(0.0).set_trans(Tween.TRANS_LINEAR)
