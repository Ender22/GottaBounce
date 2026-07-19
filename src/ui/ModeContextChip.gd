extends PanelContainer
## ModeContextChip — shared header chip answering "what am I configuring?" (frontend_ui_audit
## 2026-07-10 §3.4; owner defect class A). A cream rounded chip: [mode diorama mini 56x56] + the
## mode name in the mode's accent color. Reads GameConfig.match_config.mode_id at _ready so the
## same instance drops into ArenaSelect, CharacterSelect, and the future SPORTS court select.

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
