# STATUS — current state & next steps

> The single always-current handoff doc. Update after EVERY commit. A fresh context reads this first.

**Last updated:** 2026-07-02 session 3 (mid-session). Everything below is committed (git log = the history).

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

## Session 3 progress (LATEST at bottom)
- [x] **OWNER DESIGN DIRECTIVE received & recorded** → `docs/feedback/owner_2026-07-02_movement_feel.md`.
  Thesis: movement/combat FEEL is the product (TowerFall bar). Un-charged super hypothesis,
  super = the kill move, movement courses as tuning instrument, goat theming seed, sports modes.
  Every future gameplay spec review reconciles against this doc.
- [x] **Lethality spec amended to v2 pre-build** (game-designer): super redesigned UN-CHARGED
  (aim-hover ≤2s, full 2800 power at any fuel ≥5, drain-all → every chain routes through a
  bounce), two-tier SHOVE/SMASH contact (smash license = super-active OR stunned bodies), bot
  refuel-rhythm replaces bank-then-strike. 21 QA criteria. Also NEW
  `docs/specs/v1_movement_courses.md` (5 courses, Chimney = super acceptance test) + DECISIONS
  entries (goat identity = candidate, needs art-director eval vs Glossy Toybox blobs).
- [x] **Lethality v2 IMPLEMENTED** (gameplay-programmer; committed 03894ac). Parse gate clean;
  rendered smoke PASS (aim ring/arrow, drain-all fuel bar, SD warning/trackers, match-end panel
  — screenshots tools/out/lethality_*.png). round_stats live: 8-round bot match = 7 ring-out /
  1 laser (12.5% SD vs <25% target). 12 spec interpretations listed in agent report for designer
  review. Watch items: fuse-ring frame-1 arc minimal, resting-overlap shove jitter, bot
  self-destruct rate off the lowered ceiling.
- [x] **QA pass 1 on lethality v2 + fix round (committed 587d0a1)**. QA found a CRITICAL
  inverted-kill bug: the smashed victim (stunned = licensed smasher) counter-smashed its own
  attacker next frame — landing a super was suicide (attacker died 9/9, victim survived 10/10,
  chains 0/3, idle P1 won a match). Fixed via `_stunned_by` pairwise smash immunity + 4 more:
  chain kill credit goes to the launcher (not the flying body), super press buffers through
  refire lockout AND empty tank, bumpers refund fuel_per_bumper=20 (owner's wall-return-shot),
  fuse ring now screen-space width + outline + min arc (readable at zoom 0.443). Fix-round
  verification: victim ring-out 6/6 @1.12s w/ attacker surviving, B→C chain credit 4/4, 4-round
  bot match all ring_out / 1 SD / idle P1 scored 0. Watch: bumper hit clears hitstun (side
  effect — may suppress kills near side bumpers); buffer-through-empty-tank semantics + fuel_per_bumper
  need designer sign-off.
- [x] **Art-director goat-identity evaluation: ADOPT-STAGED** (docs/briefs/art_goat_identity_eval.md
  + DECISIONS entry). Horns = readable weapon-tip for the head-first super fantasy; fits Glossy
  Toybox as a decoration pass (~8 regens + a new aim-pose sprite needed anyway). HOLD until
  movement courses validate super-as-kill-move is the fun; reject if bounce-chaining carries the
  fun instead. Required pre-ship test: horn readability at far zoom (~25-30px bouncers). Goat
  scream SFX = separable, cheap, gate only on super_fired event (already exists in EventBus).
- [x] **QA RE-VERIFICATION COMPLETE — verdict: NOT clean-ship yet.** (Salvage of the interrupted
  run + fresh samples; report in agent transcript, evidence tools/out/qa5_*.png/.json.)
  The pacing.json anomaly was the dead agent's mis-hooked recorder, NOT a regression (fresh
  round 1 = 54 supers fired). CORE HINGE PASSES: 6a kill fuel-starved 9/10, 6b full-tank
  counter-escape 10/10 (control: no counter = dies 6/6), test 9 chain credit to launcher 6/6.
  Pacing: test 10 borderline PASS (72.7% kill-decided <20s), test 12 PASS (median 15.0s).
  FOUR FAILS, likely ONE root cause: **bumpers unconditionally clear hitstun + refuel on
  contact** (`_on_bounced()`, Player.gd ~550) — a smashed victim hitting a bumper (~660px
  inboard of the kill line) is always saved, so edge kills are un-earn-able. → test 15 FAIL
  (1 off-stage kill in 23 rounds vs ≥3/10), test 11 FAIL (SD 27-33% vs ≤25%), test 13 partial
  FAIL (L2 won 1/5 idle matches), test 14 partial FAIL (idle P1 scored 3 once, cap ≤2; but
  smashed-<8s clause = 96.7% strong PASS). Feel: fuse ring readable, chain buffer immediate;
  wall-return-shot human capture inconclusive (test-session artifact) — needs one clean pass.
  NEXT: designer ruling on bumper-recovery semantics (same mechanic powers the owner's
  wall-return shot — QA suggests gating refuel/stun-clear on NOT being in opponent-inflicted
  hitstun), then programmer fix, then targeted re-run of tests 11/13/14/15 + wall-return feel.
- [x] **Designer ruling shipped — spec bumped to v2.1** (committed ea0c133, new §2.3a + DECISIONS
  entry). THE RULE: hitstun ends by TIME, never by surface contact. While `_stun_timer > 0`,
  any bounce (tier or bumper, one uniform rule) is a DRY REFLECT: physics resolves + FX/signals
  fire, but zero fuel refund and NO stun clear. Not-stunned behavior unchanged (wall-return
  shot never involves hitstun, so it's preserved by construction). fuel_per_bumper stays 20.0;
  buffered-super-through-empty-tank kept as-built (can't fire off a dry reflect — no fuel).
  Bumper-reflected stunned body stays a licensed smasher (earned pinball chaos; `_stunned_by`
  immunity already protects the launcher). New §9 tests: 6c dry-reflect kill retained ≥8/10,
  6d wall-return shot fires ≥9/10. Fallback knob if dry reflect feels silent: bigger FX/SFX,
  NEVER reopen the refund/clear gate. **Programmer fix = immediate next task.**

## NEXT STEPS in priority order
1. **Full QA pass on lethality v2**: the 21 criteria in spec §9 (esp. test 6 BOTH directions —
   kill ≥8/10 fuel-starved / survive ≥5/10 full-tank counter; L4>L2 5-match; forced double-KO
   revive timing; 60fps regression) + powerup C1 comedy check + powerup edge cases still untested
   (two counter shields colliding, counter vs storm balls, two-star clang) + 3-match feel
   judgment vs the owner thesis. Fix findings.
2. **Build movement courses 1–3** (docs/specs/v1_movement_courses.md) — the feel-tuning
   instrument; Chimney validates the un-charged super. Level-designer + gameplay-programmer.
3. **Art-director evaluation: goat identity candidate** (see DECISIONS + owner feedback doc) —
   crazy goats w/ horns + goat scream on super vs the shipped Glossy Toybox blobs. Art fix list
   (small): (a) far-zoom floor mat thin; (b) trampoline-floor "rope" up close;
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
