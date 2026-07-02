# STATUS — current state & next steps

> The single always-current handoff doc. Update after EVERY commit. A fresh context reads this first.

**Last updated:** 2026-07-02 end of session 1. Everything below is committed (git log = the history).

## Where we are — end of session 1
The game LOOKS like a real game and RUNS. Boot `scenes/Arena.tscn` (main scene): Glossy Toybox
diorama arena (sky/hills/clouds parallax, 3-sliced grass platforms, 4 readable tier mats, bumper
posts, shadows), 4 sprite Bouncers (P1 pink + 3 bots) bouncing/boosting/smashing with squash &
stretch, ring-outs + respawn. 80fps, 28 draw calls. See `tools/out/grade_far.png`,
`toybox_close1.png` for how it looks.

## What exists (all validated, all committed)
1. **Studio**: CLAUDE.md (non-negotiables, gotchas), docs/ (VISION, STUDIO, PIPELINE, DECISIONS,
   briefs/, specs/), .claude/agents roles (register after session reload; until then run role
   briefs via general-purpose agents), post-commit STATUS hook, memory files.
2. **Validation stack (proven)**: `tools/run_game.ps1` (windowed launch, port 9090) +
   `python tools/gbplay.py` (screenshot/key/hold/eval/burst/script) + vision review; headless
   `scenes/Playtest.tscn` harness (observe/hover/duel/botwar); parse gate. Details docs/PIPELINE.md.
3. **Art pipeline (proven)**: ChatGPT via Chrome (start Chrome first!), download → `tools/art.py
   trim/keyout/check` → assets/. All prompts + gotchas in assets/CATALOG.md. ~22 bespoke assets in.
4. **Core game** (ported from old project + new): physics seams (Tuning/GravityField/Forces/
   BounceResolver), Player (bounce/jetpack/super-boost/smash), InputHuman (action map), InputBot
   5 levels, LevelLoader (JSON) + ArenaRenderer + ThreeSlice (diorama painting), Juice,
   CameraController, KillPipeline, EventBus. DevArena = current match scene (1v3, no scoring yet).

## Session 2 progress
- [x] Decals/props verified rendering (zero warnings).
- [x] **v0 round loop SHIPPED** (docs/specs/v0_round_loop.md implemented in full): PartyMatch
  state machine, scoring w/ all edge cases, MatchHUD corner cards + banner system, sudden-death
  LaserWalls, tiebreaker, rematch. Timing contract measured 4.28-4.29s death→BOUNCE. 79fps.
- [x] Powerup spec written (docs/specs/v1_powerups.md: 7 ship / 3 wait, 17 QA criteria) AND all
  7 pickup icons generated (assets/powerups/). Spike strip + fx particle sprites in.
- Screenshots: tools/out/rl_*.png (combat/round-end/sudden-death/etc).

## NEXT STEPS in priority order
1. **QA full pass** on the round loop: the 19 criteria in docs/specs/v0_round_loop.md via
   qa-playtester agent (programmer verified most technically; QA re-verifies + feel judgment +
   bug hunt). Fix what it finds.
2. **Implement docs/specs/v1_powerups.md** (icons ready in assets/powerups/): PowerupSystem +
   pickups + the 7 powerups + spawner pacing; port/adapt from old project's PowerupSystem.gd.
3. **Feel-tuning loop** (docs/reference/FEEL_REFERENCE.md targets): gbplay eval live Tuning
   writes; measure bounce rhythm/heights; old values "controlled but not fun-verified".
4. **Art fix list** (small): (a) far-zoom floor mat thin; (b) trampoline-floor "rope" up close;
   (c) tumble rotation reads sideways; (d) Juice square particles → assets/fx/puff_soft.png +
   star_sparkle.png now exist, wire them; (e) real font asset to replace SystemFont stack in
   theme.tres; (f) art skull icon for PlayerCard; (g) name-tag blink inherit.
5. Then: more arenas (level-designer, JSON), audio (assets/music + AudioManager port), title
   screen + minimal menu (.tscn + Theme ONLY), Steam prep.

## Watch out for (hard-won this session)
- Start Chrome before art generation (extension connects only when Chrome runs).
- ChatGPT image downloads: verify Downloads-folder timestamp BEFORE intake — a missed download
  click silently reuses the previous file (this corrupted hills_far once; fixed).
- Some generations bake FAKE checkerboard transparency → `art.py check` catches, `keyout --tol 40` fixes.
- `Start-Process` arg quoting, ASCII-only .ps1, Bash-for-Godot, zombie processes: see CLAUDE.md.
- Project .claude/agents subagents need a session reload to register; run as general-purpose with
  the role file quoted until then.
- The renderer agent left `push_warning` hooks for missing decals — they were generated later, so
  warnings should be gone; if not, paths differ (check assets/world/grass/decals/, assets/bg/).
