extends Node
## ShellRoot — the front-end boot node (v1_frontend_shell §1.2 "Boot").
##
## PHASE-1 INTERIM: the styled shell screens (MainMenu -> ModeSelect -> CharacterSelect ->
## ArenaSelect, Options, PauseMenu) are being designed by the UI/UX designer and will be built to that
## spec afterward. Until they exist, ShellRoot proves the config-driven, mode-driven boot path
## end-to-end: it seeds GameConfig with defaults and boots STRAIGHT into a BRAWL match. A fresh/default
## MatchConfig reproduces today's boot exactly (1 pink human + 3 bots, full-pool rotation, first-to-10).
##
## TODO(Phase 1 UI): replace this straight-to-match boot with the MainMenu screen. The selection flow
## writes GameConfig.match_config as choices are made, and ArenaSelect CONFIRM performs the same scene
## change to Arena.tscn that _boot_match() does below.

const MATCH_SCENE := "res://scenes/Arena.tscn"

func _ready() -> void:
	GameConfig.reset_to_defaults()
	# defer the scene change so this node is fully in the tree first
	call_deferred("_boot_match")

func _boot_match() -> void:
	get_tree().change_scene_to_file(MATCH_SCENE)
