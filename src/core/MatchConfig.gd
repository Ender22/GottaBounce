class_name MatchConfig
extends Resource
## The serializable match setup (v1_frontend_shell §2). The shell mutates one of these (held by the
## GameConfig autoload) as the player makes choices; PartyMatch reads it in _ready(). A fresh instance
## (never touched by the shell) reproduces TODAY's hardcoded boot exactly: 1 pink human + 3 bots
## (blue/green/yellow, mixed L2/3/4), full-pool shuffle rotation, first-to-10, 1 life.

enum ArenaMode { RANDOM_ALL = 0, SINGLE = 1, CIRCUIT = 2 }  # CIRCUIT reserved for Phase 3 (unused now)

@export var mode_id: StringName = &"brawl"                  # which GameMode to run (§3 registry key)
@export var human_count: int = 1                            # local humans (players 0..human_count-1)
@export var bot_count: int = 3                              # bots; invariant 2 <= humans+bots <= 8
@export var bot_difficulty: int = 0                         # 0 = mixed (Tuning.bot_levels rotation); 1..5 = fixed level
@export var character_ids: PackedStringArray = PackedStringArray(["bouncer"])   # per-player character; missing -> "bouncer"
@export var skin_ids: PackedStringArray = PackedStringArray(["pink", "blue", "green", "yellow"])  # per-player color skin
@export var arena_mode: int = ArenaMode.RANDOM_ALL          # RANDOM_ALL = shuffle-bag over the pool; SINGLE = one arena
@export var single_arena_path: String = ""                 # used only when arena_mode == SINGLE
@export var kills_to_win: int = 10                          # overrides Tuning.match_target_kills for the match
@export var lives_per_player: int = 1                       # overrides Tuning.lives_per_player for the match

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
