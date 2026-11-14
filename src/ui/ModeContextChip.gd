extends PanelContainer
## ModeContextChip — shared header chip answering "what am I configuring?" (frontend_ui_audit
## 2026-07-10 §3.4; owner defect class A). A cream rounded chip: [mode diorama mini 56x56] + the
## mode name in the mode's accent color. Reads GameConfig.match_config.mode_id at _ready so the
## same instance drops into ArenaSelect, the Herd Lobby, and the future SPORTS court select.

const MODES := {
	&"brawl": {"name": "BRAWL", "color": Color("#ff5fa8")},
	&"trials": {"name": "TRIALS", "color": Color("#4aa8ff")},
	&"sports": {"name": "SPORTS", "color": Color("#ff7a2d")},
	# SPORTS split (owner 2026-07-19): rocketball reuses the soccer diorama (art override); dropshot has its own.
	&"rocketball": {"name": "ROCKETBALL", "color": Color("#ff7a2d"), "art": "sports"},
	&"dropshot": {"name": "DROPSHOT", "color": Color("#22b3c9")},
}
const ART_DIR := "res://assets/ui/modes"

@onready var _icon: TextureRect = $HBox/Icon
@onready var _mode_name: Label = $HBox/ModeName

func _ready() -> void:
	var mode: StringName = &"brawl"
	if GameConfig.match_config != null and GameConfig.match_config.mode_id != &"":
		mode = GameConfig.match_config.mode_id
	var info: Dictionary = MODES.get(mode, MODES[&"brawl"])
	_mode_name.text = str(info["name"])
	_mode_name.add_theme_color_override("font_color", info["color"] as Color)
	# mini = the existing mode diorama scaled down; existence-guarded (chip still reads text-only).
	# An "art" override lets a mode reuse another's diorama (rocketball -> the soccer/sports art).
	var art_key: String = str(info.get("art", mode))
	var art_path := "%s/mode_%s.png" % [ART_DIR, art_key]
	if ResourceLoader.exists(art_path):
		_icon.texture = load(art_path) as Texture2D
	else:
		_icon.visible = false
	_fit()

## WK-81 F1: the chip sizes to its content (the owning scene pins its RIGHT edge and grows it leftward,
## grow_horizontal = BEGIN) between MIN_W and MAX_W; a name that still won't fit shrinks 1 px at a time
## down to MIN_FONT, so "ROCKETBALL" / "DROPSHOT" never clip off-screen.
const MIN_W := 316.0
const MAX_W := 480.0
const MIN_FONT := 28

func _fit() -> void:
	custom_minimum_size.x = MIN_W
	var f: Font = _mode_name.get_theme_font("font")
	if f == null:
		return
	var sb := get_theme_stylebox("panel")
	var chrome: float = (sb.content_margin_left + sb.content_margin_right) if sb != null else 36.0
	if _icon.visible:
		chrome += _icon.custom_minimum_size.x + float($HBox.get_theme_constant("separation"))
	var fs: int = _mode_name.get_theme_font_size("font_size")
	while fs > MIN_FONT and chrome + f.get_string_size(_mode_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0 > MAX_W:
		fs -= 1
	_mode_name.add_theme_font_size_override("font_size", fs)
