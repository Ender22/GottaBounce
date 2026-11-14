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
## to the shell; ShellRoot._ready consumes it (one-shot) and lands in the Herd Lobby with the
## current match_config intact — players keep their picks, that is the point of the button.
var resume_setup := false

## Herd Lobby state (audit §E.2), persisted across shell <-> match until the title screen clears it.
## lobby = 4 slot dicts {state "EMPTY"|"PICKING"|"READY", device "kb"/"pad:N"/"", goat int, flair String}
## (empty Array = no lobby yet). lobby_cpus = the BRAWL CPU *preference* (the tray shows
## min(pref, MAX_FIGHTERS - humans), so a full lobby stays full as humans come and go — WK-02 rule).
## lobby_sports_total = SPORTS format seats (2 = 1V1, 4 = 2V2), -1 = derive from match_config.
var lobby: Array = []
var lobby_cpus := -1
var lobby_sports_total := -1
## CC-4.8: the device that confirmed the mode card (ModeSelect writes it); the lobby consumes it once
## and auto-joins it as P1 if the lobby is empty.
var lobby_autojoin_key := ""

func _ready() -> void:
	if match_config == null:
		reset_to_defaults()

## Restore a fresh default MatchConfig (RESTART / cold boot). Defaults reproduce today's boot (§2.2).
func reset_to_defaults() -> void:
	match_config = load(MATCH_CONFIG_PATH).new()

## QUIT TO TITLE (CC-4.7): forget who joined. Also clears the InputRouter join registry so shared menus
## go back to "any device drives" (CC-3.3).
func clear_lobby() -> void:
	lobby = []
	lobby_cpus = -1
	lobby_sports_total = -1
	lobby_autojoin_key = ""
	InputRouter.clear_joined()

## CHANGE SETUP lands in the lobby with goats + devices kept but nobody READY (WK-07 / CC-4.7).
func lobby_unready() -> void:
	for s in lobby:
		if typeof(s) == TYPE_DICTIONARY and str((s as Dictionary).get("state", "")) == "READY":
			(s as Dictionary)["state"] = "PICKING"
