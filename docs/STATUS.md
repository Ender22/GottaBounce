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

## NEXT STEPS in priority order (session 2 starts here)
1. **Verify decals landed**: re-run the game — decals/tufts/flowers/bush/fence/cloud_b were
   committed AFTER the renderer agent last checked; its data-driven hooks should pick them up
   automatically. Screenshot and confirm no push_warnings remain.
2. **Implement `docs/specs/v0_round_loop.md`** (complete spec, 19 QA criteria): match state
   machine (intro pop-ins → 3-2-1-BOUNCE → combat → sudden-death lasers → round end → first-to-10),
   scoring w/ kill-credit 2.5s, corner HUD cards, banners. DevArena → PartyMatch. Then QA agent
   runs the 19 criteria via gbplay.
3. **Art-director grade of current build** — my (Director) quick grade of grade_far.png: SHIP-able
   base; Fix list: (a) far-zoom floor mat reads as thin band — consider 40px mat height or stronger
   rim contrast on the 1792px floor; (b) trampoline-floor "rope" look up close (flagged by
   programmer); (c) blue bouncer tumble rotation reads sideways — consider clamping visual rotation
   or upright-spring; (d) Juice's square particles → replace w/ soft round sprites; (e) spikes still
   flat red (unused in dev arena).
4. **Feel-tuning loop** (docs/reference/FEEL_REFERENCE.md targets): drive via gbplay eval (live
   Tuning writes), measure bounce rhythm/heights with Playtest harness, iterate. Old values were
   "controlled but not fun-verified".
5. Then: powerup port (10 exist in old code), more arenas (level-designer role + JSON), audio
   (owner music in assets/music + AudioManager port), menus (.tscn + Theme ONLY), Steam prep.

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
