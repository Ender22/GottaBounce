extends Node
## GameConfig autoload (v1_frontend_shell §2.1). The globally-reachable holder for the current
## MatchConfig, so the shell and the match — which live in different scene trees across the launch
## scene-change — can hand off setup without threading a reference through change_scene.
##
## NOTE (CLAUDE.md autoload gotcha): autoloads instantiate class_name scripts via load(), not the
## class_name constructor, to stay robust to global-class-cache init order. The field is annotated
## MatchConfig for callers; the instance is built with load().
##
## The spec (§2.1) names the field `match`, but `match` is a reserved GDScript keyword (the pattern-
## match statement) and cannot be an identifier — it is a parse error. Field is `match_config`.

const MATCH_CONFIG_PATH := "res://src/core/MatchConfig.gd"

var match_config: MatchConfig = null

func _ready() -> void:
	if match_config == null:
		reset_to_defaults()

## Restore a fresh default MatchConfig (RESTART / cold boot). Defaults reproduce today's boot (§2.2).
func reset_to_defaults() -> void:
	match_config = load(MATCH_CONFIG_PATH).new()
