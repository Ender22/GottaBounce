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

## Session 2 progress (LATEST at bottom of this list)
- [x] **v1 powerups SHIPPED** (all 7 + spawn director + telegraphy + HUD slot; every spec
  criterion measured PASS; committed). Gaps: mutual-shield/star edge cases code-reviewed only,
  unlimited-boost flame telegraph modest, no black-hole vignette. C1 comedy check unrun.
- [x] **QA full round-loop pass done**: 18/19 PASS, zero crashes. KEY FINDING → combat lethality
  is the #1 fun gap (kills = "traffic accidents", lasers decide ~60% of rounds, L2 bot won a
  match, idle human scored 9). Full report in the QA agent transcript; criteria in spec.
- [x] **Combat lethality + bot intent spec written & committed**
  (docs/specs/v0_combat_lethality.md). Root cause found in code: smash_impact_min(800) >
  normal_boost_max(760) — deliberate rams can't smash. Spec has exact Tuning changes, 6 new
  BotProfile dials + L1-L5 table, smash sting (fuel erosion), survival_requires_contact,
  laser_close 10→6 + part-closed revive lasers, SD edge flicker, match-end panel, 13 QA criteria.
  **NOT YET IMPLEMENTED — this is the immediate next task.**
- [x] Decals/props verified rendering (zero warnings).
- [x] **v0 round loop SHIPPED** (docs/specs/v0_round_loop.md implemented in full): PartyMatch
  state machine, scoring w/ all edge cases, MatchHUD corner cards + banner system, sudden-death
  LaserWalls, tiebreaker, rematch. Timing contract measured 4.28-4.29s death→BOUNCE. 79fps.
- [x] Powerup spec written (docs/specs/v1_powerups.md: 7 ship / 3 wait, 17 QA criteria) AND all
  7 pickup icons generated (assets/powerups/). Spike strip + fx particle sprites in.
- Screenshots: tools/out/rl_*.png (combat/round-end/sudden-death/etc).

## NEXT STEPS in priority order
1. **Implement docs/specs/v0_combat_lethality.md** (gameplay-programmer agent; spec is complete
   and numbers-first — Tuning changes, InputBot/BotProfile overhaul, scoring guard, SD pacing/
   visibility, match-end panel; expose round_stats via eval for QA). This converts "works" into
   "fun" per QA. Touches Player/Tuning/InputBot/PartyMatch — nothing else in flight.
2. **Combined QA pass**: the 13 lethality criteria + powerup C1 comedy check + powerup edge cases
   flagged untested (two counter shields colliding, counter vs storm balls, two-star clang) +
   3-match feel judgment. Fix findings.
3. **Art fix list** (small): (a) far-zoom floor mat thin; (b) trampoline-floor "rope" up close;
   (c) tumble rotation reads sideways; (d) wire assets/fx/puff_soft.png + star_sparkle.png into
   Juice particles; (e) real font asset to replace SystemFont stack in theme.tres; (f) art skull
   icon for PlayerCard; (g) name-tag blink inherit; (h) unlimited-boost flame telegraph pass;
   (i) black-hole vignette.
4. **More arenas** (level-designer role): 3-5 grass-theme JSON arenas with distinct hooks
   (levels/dev_arena.json is the only one; schema in ARCHITECTURE/reference; spikes_strip.png
   asset exists for a hazard arena). Then a second THEME (new art set via the pipeline).
5. Then: audio (assets/music + AudioManager/MusicManager port from old project), title screen +
   minimal menu (.tscn + Theme ONLY), settings/rebinding, Steam prep (docs/reference/
   MASTER_BUILD_PLAN.md P19-P20 for the checklist).

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
