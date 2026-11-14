class_name MatchConfig
extends Resource
## The serializable match setup (v1_frontend_shell §2). The shell mutates one of these (held by the
## GameConfig autoload) as the player makes choices; PartyMatch reads it in _ready(). A fresh instance
## (never touched by the shell) reproduces TODAY's hardcoded boot exactly: 1 pink human + 3 bots
## (blue/green/yellow, mixed L2/3/4), full-pool shuffle rotation, first-to-10, 1 life.

enum ArenaMode { RANDOM_ALL = 0, SINGLE = 1, CIRCUIT = 2 }  # CIRCUIT reserved for Phase 3 (unused now)

## Hard roster cap: total fighters (humans + bots) in ANY match. = the 4 MatchHUD corner cards
## (DECISIONS 2026-11-14 ruling b3; BACKLOG WK-02). The future lobby CPU tray reads this too.
const MAX_FIGHTERS := 4

@export var mode_id: StringName = &"brawl"                  # which GameMode to run (§3 registry key)
@export var human_count: int = 1                            # local humans (players 0..human_count-1)
@export var bot_count: int = 3                              # bots; invariant humans+bots <= MAX_FIGHTERS
## WK-04 (CC-3.1): the ONE device driving each human, by human index ("kb" / "pad:N", InputRouter keys).
## Written by the lobby on proceed (compacted in slot order). EMPTY = legacy: 1 human -> any device (cold
## boot / QA harness); 2+ humans -> InputRouter.default_devices() (interim, until the Herd Lobby ships).
@export var human_devices: PackedStringArray = PackedStringArray()
## WK-04 (audit §E.2): the lobby slot NUMBER each human shows ("P3" even if compacted to human index 1).
## Empty / short -> index + 1. Name tags / HUD read label_for(i), never the raw index (WK-10).
@export var human_labels: PackedInt32Array = PackedInt32Array()
@export var bot_difficulty: int = 0                         # 0 = mixed (Tuning.bot_levels rotation); 1..5 = fixed level
@export var character_ids: PackedStringArray = PackedStringArray(["bouncer"])   # per-player character; missing -> "bouncer"
@export var skin_ids: PackedStringArray = PackedStringArray(["pink", "blue", "green", "yellow"])  # per-player color skin
@export var arena_mode: int = ArenaMode.RANDOM_ALL          # RANDOM_ALL = shuffle-bag over the pool; SINGLE = one arena
@export var single_arena_path: String = ""                 # used only when arena_mode == SINGLE
@export var circuit_id: StringName = &""                   # used only when arena_mode == CIRCUIT; key into levels/circuits.json
@export var kills_to_win: int = 10                          # overrides Tuning.match_target_kills for the match
@export var lives_per_player: int = 1                       # overrides Tuning.lives_per_player for the match

## Most bots allowed alongside `humans` humans (BOTS stepper max / lobby CPU tray max).
static func max_bots_for(humans: int) -> int:
	return maxi(0, MAX_FIGHTERS - clampi(humans, 1, MAX_FIGHTERS))

## Defensive roster clamp (WK-02): 1 <= humans <= MAX_FIGHTERS, 0 <= bots <= MAX_FIGHTERS - humans.
## Trims BOTS first (humans are never dropped). Returns true if anything changed. Does NOT enforce a
## minimum total (Trials is legitimately 1 human + 0 bots); the Brawl screen owns its own >= 2 rule.
func clamp_roster() -> bool:
	var h: int = clampi(human_count, 1, MAX_FIGHTERS)
	var b: int = clampi(bot_count, 0, max_bots_for(h))
	var changed: bool = h != human_count or b != bot_count
	human_count = h
	bot_count = b
	return changed

## Device key assigned to human `i` by the lobby, "" if none (see human_devices).
func device_for(i: int) -> String:
	if i >= 0 and i < human_devices.size():
		return str(human_devices[i])
	return ""

## P-number shown for human `i` (lobby slot + 1 semantics: 1 = "P1"). Falls back to i + 1.
func label_for(i: int) -> int:
	if i >= 0 and i < human_labels.size() and human_labels[i] > 0:
		return human_labels[i]
	return i + 1

## Character id for a player slot, falling back to "bouncer" for any index the roster doesn't cover.
func character_for(i: int) -> String:
	if i >= 0 and i < character_ids.size() and str(character_ids[i]) != "":
		return str(character_ids[i])
	return "bouncer"

## Skin id for a player slot, falling back to the last defined skin (never empty).
func skin_for(i: int) -> String:
	if i >= 0 and i < skin_ids.size() and str(skin_ids[i]) != "":
		return str(skin_ids[i])
	if skin_ids.size() > 0:
		return str(skin_ids[skin_ids.size() - 1])
	return "pink"
