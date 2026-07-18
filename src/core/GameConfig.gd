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

## CHANGE SETUP deep-link (match_ceremony brief §3): the VictoryScreen sets this before returning
## to the shell; ShellRoot._ready consumes it (one-shot) and lands on CharacterSelect with the
## current match_config intact — players keep their picks, that is the point of the button.
var resume_setup := false

func _ready() -> void:
	if match_config == null:
		reset_to_defaults()

## Restore a fresh default MatchConfig (RESTART / cold boot). Defaults reproduce today's boot (§2.2).
func reset_to_defaults() -> void:
	match_config = load(MATCH_CONFIG_PATH).new()
