class_name GameMode
extends RefCounted
## The mode seam (v1_frontend_shell §3). PartyMatch stays the RUNNER (state machine, camera, spawning
## mechanics, HUD host, juice, sudden-death plumbing); a GameMode answers only the decision points a
## second mode would fill differently. PartyMatch instantiates the mode from GameConfig.mode_id via a
## tiny registry and calls it at the seams below. Every method takes the runner (the PartyMatch
## instance) so the mode reads live state through the existing QA contract (players, scores,
## lives_left, bounds, round_stats, ...).
##
## Param name is `runner` (not `match`) because `match` is a reserved GDScript keyword.
##
## BrawlMode is the first (and Phase-1 only) implementation — a verbatim extraction of today's inlined
## PartyMatch rules. See §3.4 for how a hypothetical Gauntlet/Survival mode fills the SAME interface
## with zero runner rewrites.

# --- identity / presentation ---
func id() -> StringName:
	return &""

func display_name() -> String:
	return ""

func hud_scene() -> PackedScene:
	return null

# --- match setup ---
## Read config into the runner: match target/lives, and build the level sequence
## (RANDOM_ALL -> shuffle-bag of the pool; SINGLE -> the single arena).
func configure(_runner, _config: MatchConfig) -> void:
	pass

## Per-slot spawn descriptors: [{human:bool, skin:String, character:String, bot_level:int,
## seed_damage:int, team:int}]. BRAWL: humans then bots.
func spawn_plan(_runner, _config: MatchConfig) -> Array:
	return []

# --- stage lifecycle (called by the runner's state machine at its existing decision points) ---
func next_level_path(_runner) -> String:
	return ""

func is_stage_over(_runner) -> bool:
	return false

## Additive seam (v3_content_plan B.2, TRIALS): when true, the runner polls is_stage_over() EVERY
## combat frame and ends the stage the instant it returns true (a goal reached WITHOUT a death). BRAWL
## leaves this false — its stage end stays death-driven through is_stage_over in _decide_stage_end, so
## this poll is a no-op for BRAWL (C7 parity). A non-kill-race mode overrides it to true.
func polls_goal() -> bool:
	return false

## Additive seam (v4_gauntlet): descriptors for bots to spawn AT THE START of the stage about to begin
## (runner.stage_index). Lets a mode swap its bot roster PER STAGE (GAUNTLET waves). BRAWL/TRIALS return
## [] -> the runner skips the whole block -> byte-for-byte parity (C7). Same descriptor shape as spawn_plan.
func wave_spawn_plan(_runner) -> Array:
	return []

## Scoring hook applied on every death. BRAWL: +1 credited kill / -1 self-fall floored at 0.
func on_kill(_runner, _killer_idx: int, _victim_idx: int, _cause) -> void:
	pass

## The match winner's player index, or -1 if the match is not over. BRAWL: strict leader >= target.
func match_winner(_runner) -> int:
	return -1

## {text, color} for the stage-end banner (e.g. "P2 SURVIVES!").
func stage_end_banner(_runner) -> Dictionary:
	return {}

## {text, color, subline} for the match-end banner (e.g. "P1 WINS THE MATCH!").
func match_end_banner(_runner) -> Dictionary:
	return {}
