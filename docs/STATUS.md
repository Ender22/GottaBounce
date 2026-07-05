# STATUS — current state & next steps

> The single always-current handoff doc. Update after EVERY commit. A fresh context reads this first.
> Durable history/rationale lives in `docs/DECISIONS.md`, `docs/specs/`, `docs/briefs/`,
> `docs/feedback/` — this file is a lean current-state snapshot, not a session log.

**Last updated:** 2026-07-05 — the game is now a **cohesive FOUR-MODE party brawler** (up from a single
hardcoded match at the start of the day). Everything below "What exists" is committed + validated. An
owner-driven **content-expansion initiative** (wild gimmick levels + more circuits/courts/pitches +
unlock progression, across all modes) is DESIGNED and about to enter the BUILD phase — see IN-FLIGHT.

## Where we are (the game today)
A goat/ram party brawler — "Duck Game × Smash Bros, no guns" — with a full front-end and four modes,
all on a pluggable `GameMode` seam:
- **BRAWL** — the core versus kill-race (bounce→fly→smash→recover, un-charged super, off-screen kills,
  lives, cumulative-kills-to-N, level rotation, SD-on-double-KO). The proven fantasy.
- **TRIALS** — solo time-attack, 5-course campaign, reach-goal/beat-par, fall=respawn+penalty, medals.
- **GAUNTLET** — solo/co-op survival vs escalating bot waves, shared defender-life pool, score=highest wave.
- **SPORTS** — 2-team bounce-ball into goals (Ball entity, GoalZone, team scoring).
Cast = **the Herd**: 6 goat/ram heroes (Pogo/Butch/Ziggy/Puff/Vex/Billy) that PLAY differently (feel
deltas). Content = 11 arenas in 3 circuits. Front-end = title/mode/character/arena/options/pause.

## What exists (committed + validated)
- **Front-end shell** (Phase 1, UI/UX verdict SHIP): `ShellRoot` screen-stack → MainMenu/ModeSelect/
  CharacterSelect/ArenaSelect/Options/PauseMenu; one springy gamepad-first menu system (`src/ui/*`,
  `scenes/ui/*`, `assets/ui/theme.tres`). Boot = `res://scenes/ui/ShellRoot.tscn`.
- **Config + mode framework:** `GameConfig` autoload + `MatchConfig` resource; `Settings` autoload
  (user://settings.cfg, applies buses+window on boot). `GameMode` seam (`src/modes/GameMode.gd`) with
  additive null-default hooks — `polls_goal`, `wave_spawn_plan`, `on_stage_ready`, `bot_objective`,
  `camera_framing`. `PartyMatch` = generic runner reading GameConfig + delegating to `_mode`.
- **Modes:** `BrawlMode` (versus loop extracted; the baseline — BRAWL is byte-for-byte the old game),
  `TrialsMode` (+ `GoalGate`, `levels/course_sets.json`, `levels/courses/*.json`, `TrialsHUD`),
  `GauntletMode` (+ `levels/gauntlet_waves.json`, `GauntletHUD`, `_despawn_bots`), `SportsMode`
  (+ `Ball`, `GoalZone`, `SportsHUD`, `levels/sports_court.json`). All mutually regression-clean.
- **Roster:** `assets/characters/bouncer_{pink,blue,green,yellow,purple,orange}_idle.png` = the 6 goats;
  `CharacterProfile`/`CharacterProfiles` per-character feel deltas (data, base Tuning UNTOUCHED, Billy=Standard).
- **Circuits:** `levels/circuits.json` — Meadow Mile / Scrapworks / High Wire over the 11 arenas.
- **Combat/feel/bots/audio/arena render:** the original validated core (un-charged super, SHOVE/SMASH
  solidity, damage system, edge-relative kills, ring-out credit; InputBot L2-L4 human-sim; AudioManager;
  Glossy Toybox `ArenaRenderer`). Camera frames ALL living players (2026-07-05 oscillation fix).
- **Studio:** roles in `.claude/agents/` incl. **ui-ux-designer** (front-end approval), creative-director
  (fantasy-fit), art-director, game-designer, level-designer, gameplay-programmer, qa-playtester.

## Read order on fresh context
`docs/STATUS.md` (this) → `docs/ROADMAP.md` → `docs/GAME_ESSENCE.md` → `docs/VISION.md` →
`docs/DECISIONS.md` (newest-first — the 2026-07-05 entries cover the whole rebuild + rulings) → the
mode/content specs: `docs/specs/v1_frontend_shell.md`, `v2_character_feel_deltas.md`, `v3_content_plan.md`,
`v4_gauntlet_mode.md`, `v5_sports_mode.md`, **`v6_party_gimmicks_circuits.md`, `v7_trials_challenge_types.md`,
`v8_sports_courts.md`, `v9_idea_bank.md`** (the content initiative) → `docs/briefs/character_theme_bible.md`
+ `character_art_bible.md` → `docs/PIPELINE.md`. Memory: [[gottabounce-session4-scope-correction]],
[[gottabounce-chatgpt-image-paste]].

## IN-FLIGHT — RESUME HERE (content-expansion initiative)
**Design is DONE (5 committed specs); BUILD is the constraint (one rendered test / game instance at a
time).** The plans all fan out from ONE shared foundation — build the gimmick MECHANICS once, reuse across
Brawl circuits + Trials challenge-types + Sports pitches.

- **Specs ready to build from:** `v6` (lethal gimmick mechanics ranked: spinning_hammer→crusher→
  falling_debris→bomb→destructible_block→moving_platform + collapsing-arena archetype; 4 new circuits
  Foundry/Midway/Convoy/Meltdown w/ 20-authored-10-drawn rotation; mastery-first unlock progression).
  `v7` (Trials objective types: Survive/Destroy-all/Physics-puzzle/Collect/Precision via optional course
  `objective` block, absent=REACH_GOAL back-compat, zero new runner hooks; 8 example courses).
  `v8` (8 Sports pitches calm→chaos, strict mirror-symmetry, `Ball.receive_hazard_impulse` hook).
  `v9` (level-designer's creative idea bank — ice/low-friction, jump-in cannons, + original inventions;
  landing shortly). Hazard doctrine = LETHAL w/ telegraphy+fairness+credit (DECISIONS 2026-07-05).
- **BUILD SEQUENCE (do in this order):**
  1. **v6 Wave A mechanics** — spinning_hammer FIRST (reuses MovingHazard motion + the `Hazard.kill()`
     path spikes use), then crusher, falling_debris; then destructible_block + bomb; moving_platform LAST
     (hard — solid moving collider). Each: new LevelLoader object type + entity + telegraph VFX; validate
     rendered (M-DODGEABLE ≥8/10, no unavoidable instakill, symmetric, geometry-integrity).
  2. Fan out: BRAWL gimmick circuits (v6), Trials challenge types (v7 framework+parity FIRST, then one
     course per type as its mechanic lands), Sports pitches (v8 — the_box/long_haul/the_bowl authorable NOW
     with no new mechanic; hazard pitches block on their mechanic).
  3. Unlock progression (v6 §unlock: Settings [progression]; ArenaSelect locked cards + celebration).
- **PENDING QA to re-check after builds:** Sports fair (neither team >65%, both goals) — the bot-fairness
  fix was in flight this session; CONFIRM it committed (git log for "Sports: bot ball-awareness" and a
  follow-up fairness fix) and that a bot match is fair before building Sports pitches on top.

## Prior polish/quality backlog (behind the content initiative)
Trials medal-time tighten (movement-bot/human run — CD flag), all-six goat readability gate (spawn 6 in a
match), Vex corkscrew horns + goat squash/charge + super-charge poses (art pass #2, use the paste-edit
technique [[gottabounce-chatgpt-image-paste]]), goat-themed logo/key-art, arena thumbnails + mode-card
icons (CD #7 "tech-demo" tells), plain-button focus accent-border, Gauntlet G-BOTFOCUS + victory-drive,
Sports 2v2/co-op presets + end-zoom empty-net, Gauntlet banner overlap, confirm gamepad-A activates shell.
Do NOT build Puzzle mode #5 yet (CD #7: deepen the 4). match_target_kills=10 (owner-set; QA suggested 7-8).

## Watch out for (hard-won)
- **RENDERED BUILDS ARE SERIALIZED:** only ONE game instance (port 9090) — never run two game-driving
  agents at once. Boot now goes through the shell (MainMenu); to test a match directly launch
  `res://scenes/Arena.tscn` (default GameConfig=brawl), or set `GameConfig.match_config.mode_id` via eval
  then `get_tree().change_scene_to_file(...)`. `get_tree().current_scene` on the shell = MainMenu, NOT the match.
- **gbplay `eval`:** context is a Node (has `get_tree()`), NOT the match — reach the match via
  `get_tree().current_scene`. Multi-line evals run (side effects) but return null; single-expression evals
  return values. A `for` loop with `; return` same-line pulls return into the loop.
- **Background agents can zombie** holding port 9090 → next run acts slow/wrong. Kill strays
  (`tools/stop_game.ps1` + taskkill); always launch via `tools/run_game.ps1`; verify scene path.
- **The "crash ~12 stages" + "fps 79→28" were BOTH REFUTED (2026-07-04)** — do not chase; zombie procs +
  unfocused-window throttling. Physics is fixed 120Hz decoupled from render.
- **ChatGPT art:** attach references via clipboard Ctrl+V (STA PowerShell SetImage); edit-outputs need
  `art.py keyout --tol 45`; download via the share-modal Download button. See [[gottabounce-chatgpt-image-paste]].
- Windows/PowerShell/Godot: ASCII-only .ps1; `dangerouslyDisableSandbox:true` on Godot shell calls; console
  exe `C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`; a mis-quoted --path can launch
  the OLD sibling project (also serves 9090 — verify scene path). (CLAUDE.md has the full list.)
