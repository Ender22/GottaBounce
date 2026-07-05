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
  1. **v6 mechanics — DONE (5 lethal hazards, all validated + committed):** spinning_hammer, destructible_block
     (+ COLLAPSING ARENA meltdown_box), crusher, falling_debris, bomb/landmine (+ `Ball.receive_hazard_impulse`).
     Reusable plumbing: contact->kill Area2D, phase-clock+dwell oscillator, self-render telegraphy, LevelLoader
     wiring, destructible `group`-count contract. STILL TODO: **moving_platform** (the one hard mechanic —
     solid moving collider; deferred so it doesn't gate the fun).
  2. **BRAWL circuit — DONE:** MAYHEM MILE (`mayhem_mile`, 12-pool draw-6 tier-sorted). Random-draw rotation
     + UNLOCK PROGRESSION DONE (Settings [progression], mastery+pity, ArenaSelect locked cards + celebration).
  3. **Fan-out DONE across all 3 modes:** TRIALS challenge types (6 types + proof courses, `varied` set) +
     SPORTS pitches (5 courts calm->chaos + court-set + unlock gates) both built + validated. Sports
     bot-fairness fix committed (mirror-symmetric court + per-team skill balance).
- **ART-DEBT PAYDOWN (owner "no code-drawn/SVG assets" rule) — DONE (Task #7 complete).** ALL code-drawn object
  bodies replaced with generated Glossy Toybox sprites (transient telegraph/VFX + gameplay-contract overlays stay
  code). Committed+wired+rendered-validated: `hazards/hammer.png` (SpinningHammer), `bomb.png` (Bomb/landmine),
  `crusher.png` (Crusher heads), `wrecking_ball.png` (FallingDebris chunks + MovingHazard pendulum), `flatbed_cart.png`
  (MovingPlatform vehicle deck), `objects/ball.png` (Ball.gd — rolls via RigidBody transform), `objects/crate.png`
  (DestructibleBlock.gd — 2D grid-tiled off shorter edge so crates stay square on wide floors AND tall walls; tier
  bounce-mat strip kept on top), `objects/token.png` (Pickup.gd). NO code-drawn object body remains — only intended
  telegraph/VFX (RingOfFire/StormBall/GoalZone glow/LandTarget reticle/PowerupBubble shell).
- **UI-POLISH SLICE (owner "gorgeous, Mario-Kart bar" priority) — STARTED.** Brief done: `docs/briefs/frontend_visual_polish.md`
  (finding: the shell is a CORRECT UI wearing placeholder skins; the whole gap is ~1 logo + 4 mode dioramas + baked arena
  thumbnails [a tool, ~0 art] + up to 6 char portraits + a free title bobber-wiring pass — all drop into slots the shell
  already animates). Priority order: TITLE → ModeSelect → ArenaSelect → CharacterSelect.
  - **ModeSelect dioramas (art):** `ui/modes/mode_brawl.png` (horn clash) + `ui/modes/mode_trials.png` (ring rocket)
    DONE+committed. **mode_gauntlet + mode_sports DEFERRED** — ChatGPT image-gen hung 3+min on both 2026-07-05 night
    (draft prompts queued in the ChatGPT tabs); retry+harvest, then wire all 4 into `MenuCard` Art slot (hide the Glyph).
  - **TITLE bobbers (free wiring) — IN FLIGHT:** gameplay-programmer wiring the 6 existing goat idle sprites as parallax
    bobbers on MainMenu per brief §4b (Pogo+Butch front flanking buttons, 4 smaller behind; independent y-bob/drift/sway).
  - **NOT YET DONE (next up):** wire the 2 (→4) mode dioramas into ModeSelect cards; baked arena-thumbnail TOOL (§3b —
    render each level via ArenaRenderer to `assets/ui/thumbs/*`, drop into ArenaSelect cards — fixes the worst screen for ~0 art);
    goat logo (art, brief §4c — mascot-on-wordmark; text-gen is unreliable, consider emblem+engine-text); char beauty poses.
- **CONTENT INITIATIVE = LARGELY COMPLETE.** Remaining BACKLOG (clearly scoped, none blocking): moving_platform
  (the one hard solid-collider mechanic); fuller batteries (the_bowl/minefield/the_crusher Sports pitches,
  v7's full 8 Trials courses, more Brawl circuits + the 3 seed arenas); always-on-hazard pre-combat lethality
  fix (gate on combat_started / raise spawns under blades); Sports court-select UI (plumbing selects by
  court_id today); cumulative-kill cosmetic unlock track (counter exists); CD#7 polish (menu arena-thumbnails
  + mode-card icons, Trials medal-time tuning via a movement bot, plain-button focus accent-border); goat
  squash/charge + super-charge poses (art pass #2, paste-edit technique); goat logo; all-six readability gate.
- **PROCESS WATCH:** a build agent stalled TWICE in a "launch bg sweep -> end turn waiting" loop without
  harvesting; the lead took over + validated with a BOUNDED bot-match sample. If an agent does this, take over.

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
