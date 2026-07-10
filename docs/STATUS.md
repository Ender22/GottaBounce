# STATUS — current state & next steps

> The single always-current handoff doc. Update after EVERY commit. A fresh context reads this first.
> Durable history/rationale lives in `docs/DECISIONS.md`, `docs/specs/`, `docs/briefs/`,
> `docs/feedback/` — this file is a lean current-state snapshot, not a session log.

**Last updated:** 2026-07-10 — **SHIP-class four-mode party brawler** (creative-director full-game verdict:
purchasable, cohesive, core fantasy lands, no regressions — `docs/feedback/cd_2026-07-06_fullgame.md`).
**2026-07-10 session:** the v10 TRIALS BINARY-COMPLETION rewrite (Pico-Park model, owner-directed) is BUILT + QA'd +
COMMITTED — no clock/medal/par anywhere; all-must-finish multi-player-parallel for REACH_GOAL+SURVIVE; solo for the 4
object-mutation types; 13 course JSONs migrated. Full v10 §7 QA battery PASSED (solo campaign parity, N=2/N=3
all-home, sticky latch, wait-for-dead, per-player SURVIVE). TWO real GoalGate bugs found+fixed during QA (stale
pre-combat latch that auto-cleared course_04; one-step-stale overlap latch on respawn) — see DECISIONS 2026-07-10.
The "movement-bot medal tuning" backlog task is DELETED (no medals to tune). CharacterSelect beauty-pose brief written
(`docs/briefs/character_select_busts.md`, Pogo+Butch first) — generation pass pending. THE FOUNDRY Brawl circuit
(4 arenas, level-designer) is IN FLIGHT — validation next. Only remaining owner-gate = audio mix listen.

## Where we are (the game today)
A goat/ram party brawler — "Duck Game × Smash Bros, no guns" — with a full front-end and four modes,
all on a pluggable `GameMode` seam:
- **BRAWL** — the core versus kill-race (bounce→fly→smash→recover, un-charged super, off-screen kills,
  lives, cumulative-kills-to-N, level rotation, SD-on-double-KO). The proven fantasy.
- **TRIALS** — Pico-Park BINARY completion (v10): no clock/medal/par; 5-course campaign + 8-course varied battery;
  fall = free respawn; multi-player-parallel (all-must-finish) on REACH_GOAL/SURVIVE, solo object-mutation types.
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
  1. **v6 mechanics — DONE (ALL 6, validated + committed):** spinning_hammer, destructible_block
     (+ COLLAPSING ARENA meltdown_box), crusher, falling_debris, bomb/landmine (+ `Ball.receive_hazard_impulse`),
     **moving_platform** (commit dfb8dd3 — `MovingPlatform.gd` AnimatableBody2D solid deck, sticky rider-carry since
     Player is MOTION_MODE_FLOATING; re-validated 2026-07-06: sub-pixel carry stability, no jitter/tunnel; test bed
     `levels/platform_test.json`). Reusable plumbing: contact->kill Area2D, phase-clock+dwell oscillator, self-render
     telegraphy, LevelLoader wiring, destructible `group`-count contract. No hard mechanic remains.
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
  - **TITLE — DONE.** Bobbers were ALREADY built (Backdrop.gd, Phase 1 — the brief's "never built" was wrong; agent
    correctly did NOT duplicate). Fixed the one real bug: purple Vex was parked behind the logo → moved to clear sky, all
    6 Herd now visible. Rendered-verified gorgeous (tools/out/title_fixed_2.png). LOGO: current yellow/cyan wordmark reads
    fine + bobbers give mascot presence → §4c goat-on-logo DEFERRED (ChatGPT text-gen is unreliable; poor risk/reward now).
  - **ModeSelect — DONE.** All 4 `ui/modes/mode_{brawl,trials,gauntlet,sports}.png` dioramas generated + WIRED into the cards
    (MODE_ART preload dict + data["art"]; set_art hides the Glyph). Four mini box-covers. Rendered-verified (modeselect_check.png).
  - **ArenaSelect — DONE.** `tools/ThumbBaker.gd/.tscn` bakes each arena via ArenaRenderer → `assets/ui/thumbs/<id>.png` (19
    baked + a RANDOM collage); ArenaSelect loads them into card Art slots (existence-guarded `load()`, KEEP_ASPECT_COVERED) +
    RANDOM tile toned down. Fixed the circuit-card text overflow (name+tag split) + LOCKED-ribbon/header collision (grid band
    shifted down). Rendered-verified (arenaselect_fixed.png) — a real visual map-select. RE-BAKE: `<exe> --path . res://tools/ThumbBaker.tscn` then `--editor --quit` to reimport.
  - **CORE UI-POLISH SLICE = COMPLETE** (title/ModeSelect/ArenaSelect all Mario-Kart-tier; CharacterSelect already solid).
    Remaining nice-to-haves (deferred, non-blocking): CharacterSelect beauty-pose busts (§2c, start Pogo+Butch); goat-on-logo
    (§4c — current wordmark reads fine + bobbers give mascot presence; ChatGPT text-gen unreliable, poor risk/reward unattended).

## NEXT PHASE — content waves (owner-requested variety)
- **Sports pitches — DONE (8 total).** Added `the_bowl` (calm funnel), `minefield` (symmetric landmines), `the_crusher`
  (center horizontal crusher, ejects ball vertically) + `Crusher._eject_ball`. All strict mirror-symmetric, bot-match validated,
  wired into sports_courts.json (unlock gates use REAL circuits). WATCH: minefield leaned BLUE 5/5 but all margins 1-2 goals
  (~58%, under the 65% bar) — reads as first-touch variance; re-sample if it recurs.
- **Trials battery — DONE (8 courses).** `varied` grown 5→8: +t_cart_convoy (COLLECT, void+cart+refuel), +t_twin_hammers
  (SURVIVE hard), +t_bank_shot (PHYSICS bank-shot capstone). Difficulty-ramped, each validated completable in-engine.
  **v10 (2026-07-10): medals/par REMOVED from all courses — binary completion; the medal-tuning task no longer exists.**
- **CREATIVE-DIRECTOR full-game verdict — DONE (`docs/feedback/cd_2026-07-06_fullgame.md`): SHIP-class, no rethink, no
  regressions.** Purchasable-looking cohesive party brawler; BRAWL delivers the full fantasy; motion health clean. Punch-list
  applied (see below).
- **CD PUNCH-LIST — APPLIED + committed:** (1) progression unlock-chain integrity guard (Settings.gd — recursive prefix guard +
  self-healing sanitize; the "High Wire open while Scrapworks locked" impossible state is dead); (2) repaired the dirty DEV save
  (music was 0% → our playtests ran MUTED; now defaults music=1.0 + clean progression); (3) Sports match length 10→6 goals
  (`Tuning.sports_goal_target`, split from Brawl's knob); (4) audio verified FIRING (music + SFX). 

## ⚠ NEEDS OWNER (flagged, NOT auto-changed)
- **BRAWL kill target — RESOLVED 2026-07-06: owner locked 10.** CD/QA had recommended ~7, but owner's ruling: Brawl is the
  4-player party mode (Duck Game/TowerFall lineage); with 4 players kills bank fast across last-one-standing rounds, so 10 keeps
  matches from ending too soon. Do NOT re-litigate. Knob `Tuning.match_target_kills` (separate from Sports).
- **Audio MIX quality** — a HUMAN must LISTEN. Audio is wired + firing (verified), but no one has judged levels/loop/punch (our
  playtests were accidentally muted until tonight's save repair). AI can't hear this.

## OWNER FEEDBACK 2026-07-10 (drives current priorities)
- **UI audits (owner-flagged):** full audit DONE (`docs/briefs/frontend_ui_audit_2026-07-10.md`) — MainMenu SHIP;
  ModeSelect/CharacterSelect/Options/Pause FIX; ArenaSelect was REJECT → **REBUILT + designer-approved SHIP
  (committed):** two-shelf scrolling layout (WAYS TO PLAY 460x340 / ARENAS 380x280 rails), scroll-to-focused,
  clip bands (header/footer occlusion structurally impossible), ModeContext chip (ArenaSelect + CharacterSelect),
  LB/RB+PgUp/PgDn 3-card jumps, real star icons, per-shelf remembered focus. ShelfRail is reusable — it IS the
  future Sports court-select container — and now IS the Sports court select (see backlog DONE entry). AUDIT
  FOLLOW-UPS CLOSED 2026-07-10: court thumbnails baked (ThumbBaker courts pass, court_<id> namespace);
  HintStrip contrast pass (P2, cream chips shell-wide + footer no-content enforcement); CharacterSelect
  safe-area/type (P3, 64px tray inset + 28/40px stepper type); Options tick-gutter + centered panel;
  PauseMenu hint strip (inside the panel footer — designer caught the first placement overlapping a HUD corner)
  + two-press REALLY? confirm on QUIT/RESTART. Designer re-grade: PASS all items after the relocation.
  STILL OPEN: circuit CREST art + de-clocked mode_trials.png diorama (art pipeline); ToyToggle knob scale
  (P5-minor); CharacterSelect stepper focus treatment (designer F-class follow-up: nothing visibly reads as
  focused while focus is in the settings strip).
- **CAMERA (repeated ~5x, owner rules now the acceptance spec):** `docs/feedback/owner_2026-07-10_camera_rules.md`.
  **REWORKED TO THE RULES + committed (see DECISIONS 2026-07-10):** camera_bounds = platform AABB +200; target =
  clamped midpoint of extreme players (cluster/weights/velocity-lead machinery deleted); zoom fits everyone (no
  readability floor); zoom-in cap shows >=75% of the level. Motion-evidence QA: 0 off-screen violations in 679
  combat player-samples across worst-case-spread + live 4-bot matches on grassy_expanse and foundry_press_row;
  0 fast pan reversals; clustered zoom cap exact. **AWAITING OWNER EYES — do not call this fixed until he says so.**
  Knobs if he wants adjustment: Tuning.cam_bounds_pad (200), Tuning.cam_close_fraction (0.75), CAM_MARGIN.

## NEXT-UP BACKLOG (autonomous-safe; fresh-session ready)
- CD minor items — DONE: minefield elevated mines now fire (proximity mines detect the ball; Bomb._ball_within, sports-scoped);
  Gauntlet solo lives was a non-issue (already 4 via CharacterSelect — CD saw a dev-launch default).
- ~~Trials medal-time tuning~~ **DELETED by v10** (binary completion — no medals exist to tune).
- ~~Sports court-select UI~~ **DONE + committed 2026-07-10.** ArenaSelect is mode-aware: SPORTS shows "PICK YOUR
  COURT" — one ShelfRail of all 8 courts (tier-sorted, TIER badges, locked ribbons w/ readable unlock hints:
  circuit/matches/wins), launch passes the court ID so SportsMode._resolve_court stays the unlock authority.
  CharacterSelect SPORTS flow now routes through it (1v1 preset kept). Real-input flow verified end-to-end
  (ModeSelect→hero lock-in→court→live 1v1 on Center Pitch); brawl two-shelf regression clean. FOLLOW-UPS:
  bake court thumbnails (7 courts on gradient fallback — extend ThumbBaker to sports courts); ui-ux spot-grade
  of the court screen (built to the approved audit §3.8 grammar).
- ~~THE FOUNDRY circuit validation~~ **DONE + committed 2026-07-10.** 4 arenas bot-match validated (press_row/
  smelter/crucible/meltdown), wired into circuits.json (unlock: win High Wire; Mayhem Mile now gates on Foundry) +
  ArenaSelect color + baked thumbs. TWO spawn-layout bugs fixed during QA: press_row's middle-island spawns sat in
  the crusher lanes (bots died <0.2s EVERY round — deterministic; spawns moved to outer islands) and smelter's 4th
  spawn sat inside the horizontal crusher lane + its right island is fully inside the hammer sweep (primary spawns
  now on the left island, swept spawns demoted to indices 4-5 per the hammer_arena precedent — 4P matches open with
  everyone on island A, flagged for level-designer). Pacing after fixes: press_row hot (~5s rounds, WATCH), smelter
  3.5-15.5s, crucible 8-16s + even scores (best of set), meltdown 6-10s on its ~10s collapse TTL. Also: Hazard.gd
  (spikes) now gates lethality on combat_started like every other hazard (dormant path — no level ships spikes);
  TRIALS ModeSelect tagline de-clocked ("Fly the line. Land it, and you're home.").
- Trials polish follow-ups (from v10 QA): per-COURSE pause restart (today RESTART = whole set); C-CAM watch — author
  multi-player parallel courses screen-scale-aware (>1-screen spread renders far players as edge arrows).
- CharacterSelect beauty-pose busts (§2c, Pogo+Butch first — nice-to-have, screen ships on idles).
- More Brawl circuits + the 3 seed arenas; always-on-hazard pre-combat lethality guard; goat-on-logo (deferred, text-gen flaky).
- **CONTENT INITIATIVE = LARGELY COMPLETE** (all 6 gimmick mechanics incl. moving_platform now done). Remaining BACKLOG
  (clearly scoped, none blocking): fuller batteries (the_bowl/minefield/the_crusher Sports pitches,
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
