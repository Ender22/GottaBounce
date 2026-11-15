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
## WK-144 (UX4-13 / CC-4.7): QUIT TO MENU (Pause, the Brawl / Sports Victory screens, the Trials end) sets this
## right before returning to the shell; ShellRoot._ready consumes it (one-shot) and lands on MODE SELECT with the
## lobby cleared (a returning group skips the title + PLAY). Cold boot and every other shell entry are unchanged.
var quit_to_modes := false

## Herd Lobby state (audit §E.2), persisted across shell <-> match until the title screen clears it.
## lobby = 4 slot dicts {state "EMPTY"|"PICKING"|"READY", device "kb"/"pad:N"/"", goat int, flair String}
## (empty Array = no lobby yet).
var lobby: Array = []
## WK-07 per-mode rule memory (CC-4.6 / R-26): mode key ("brawl", "rocketball", "dropshot", ...) -> rule
## dict. BRAWL {cpus, bot_difficulty, kills_to_win, lives_per_player, self_ko_penalty (WK-20c)}; SPORTS
## {sports_total, bot_difficulty}. sports_total 0 = AUTO FORMAT (WK-120: follows the humans joined until a
## player sets FORMAT in RULES; then the explicit 2 = 1V1 / 4 = 2V2 is remembered and wins).
## `cpus` is the CPU *preference* (the lobby shows min(pref, MAX_FIGHTERS - humans), so a full lobby stays
## full as humans come and go — WK-02). Survives QUIT TO TITLE on purpose (rules are a preference, the
## lobby is a session). A mode never reads another mode's entry, so Rocketball's 1 bot can't leak into Brawl.
var mode_rules: Dictionary = {}
## CC-4.8: the device that confirmed the mode card (ModeSelect writes it); the lobby consumes it once
## and auto-joins it (lowest free slot, P1 in an empty lobby) unless it is already seated — WK-125: also
## when other players carried over from the last lobby.
var lobby_autojoin_key := ""
## CD4-01: Brawl rotation session decks (BrawlMode, Tuning.circuit_session_deck). key ("circuit:<id>" /
## "random") -> {"deck": Array of res:// paths still to play, "last": last path played, "decks": decks built}.
## Never cleared in-process on purpose: a REMATCH or the next play of a circuit continues where the last
## match stopped, so a session sees every arena before any repeats.  # CD4-01
var circuit_decks: Dictionary = {}   # CD4-01

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
	lobby_autojoin_key = ""
	InputRouter.clear_joined()

## CHANGE SETUP lands in the lobby with goats + devices kept but nobody READY (WK-07 / CC-4.7).
func lobby_unready() -> void:
	for s in lobby:
		if typeof(s) == TYPE_DICTIONARY and str((s as Dictionary).get("state", "")) == "READY":
			(s as Dictionary)["state"] = "PICKING"

## Rule key for a mode id: TRIALS has no rules (""), every other mode keeps its own set.
static func rules_key(mode_id: StringName) -> String:
	return "" if mode_id == &"trials" else str(mode_id)

## The remembered rules for `key`, with defaults for anything never set (fresh copy — callers write back
## through set_rules()).
func rules_for(key: String) -> Dictionary:
	# sports family ids mirror SportsMode.is_sports_mode (no class_name refs from an autoload — CLAUDE.md)
	var sports: bool = key in ["sports", "rocketball", "dropshot"]
	var d: Dictionary = {"bot_difficulty": 0}
	if sports:
		d["sports_total"] = 0   # WK-120: 0 = AUTO (1 human -> 1V1, 2+ -> 2V2); 2 / 4 = a FORMAT the players set
		d["goals_to_win"] = int(Tuning.sports_goal_target)   # WK-110: RULES GOALS / POINTS, default = today's cap (6)
		if key != "dropshot":
			d["pressure_nets"] = 1   # WK-116: RULES "PRESSURE NETS" ON by default (soccer courts only)
	else:
		d["cpus"] = 3
		d["kills_to_win"] = 10
		d["lives_per_player"] = 1
		d["self_ko_penalty"] = 0   # WK-20c: Ra default (self-KO costs 0); 1 = RULES "SELF-KO −1" ON
		d["ghosts"] = 0            # WK-37: MatchConfig.Ghosts.ON (0) / BAA_ONLY (1) / OFF (2)
	var saved: Variant = mode_rules.get(key, {})
	if typeof(saved) == TYPE_DICTIONARY:
		for k in (saved as Dictionary).keys():
			d[k] = (saved as Dictionary)[k]
	return d

func set_rules(key: String, rules: Dictionary) -> void:
	if key != "":
		mode_rules[key] = rules.duplicate()
