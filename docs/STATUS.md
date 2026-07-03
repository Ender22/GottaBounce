# STATUS — current state & next steps

> The single always-current handoff doc. Update after EVERY commit. A fresh context reads this first.

**Last updated:** 2026-07-03 session 4. Everything below is committed (git log = the history).

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

## Session 4 progress (2026-07-03) — skill library + §2.3a fix committed + lethality QA verdict
- [x] **Operator skill library shipped** under `.claude/skills/` (16 skills: change-control,
  debugging-playbook, failure-archaeology, architecture-contract, game-feel-reference,
  tuning-and-flags, build-and-env, run-and-playtest, diagnostics-and-tooling, validation-and-qa,
  docs-and-writing, art-pipeline, feel-campaign, analysis-toolkit, research-frontier,
  research-methodology). Authored parallel, then 3-way reviewed (factual/doctrine/usability) —
  0 blocking, 5 important + clear-cut minors fixed. Ships 3 diagnostic scripts under
  diagnostics-and-tooling/scripts/ (match_stats.py, perf_gate.py, feel_probe.jsonl).
- [x] **§2.3a dry-reflect fix COMMITTED** (`_on_bounced` guards refund+stun-clear behind
  `if _stun_timer <= 0.0:`). Parse-clean. Was the pending programmer fix; verified good.
- [x] **Lethality QA verdict filed** (idle-P1 harness = spec §9; 29-round aggregate with the fix):
  t10 kill-decided **72% PASS**, t12 median **16.0s / max 24.5s PASS**, t11 SD **28%** (8/29 =
  one round over the ≤25% line — marginal), t15 edge-guard **2.07/10** (up ~5× from the pre-fix
  1/23, but short of ≥3/10). DIAGNOSIS: SD rounds are NOT stalemates — every round (SD and
  non-SD) resolves with all 3 kills; SD rounds are slow-burn (22.5s, 23 supers) vs normal
  (12.9s, 15 supers). So the residual pacing gap is late super→kill conversion, not fuel-starve
  stalling or bots-not-closing.
- [x] **Prediction-first experiment: `smash_sting_fuel` 30→40 REJECTED.** Predicted it would fix
  t15 AND lower SD (spec §2.4 cascade). Result (22-round idle-P1): t15 → 3.64/10 (fixed) BUT SD
  → 41% and kill-decided → 59% (both regressed). The §2.4 edge-lethality→SD cascade is REFUTED —
  deepening the sting fixes edge kills by starving victims but drags rounds. Not adopted; live
  eval only, no commit. Baselines: tools/out/idle_sting30_baseline.json, idle_sting40.json.
- [x] **Prediction-first experiment #2: bot `edge_guard` up (L2 0→0.3, L3 0.3→0.6, L4 0.7→0.9)
  REJECTED.** Predicted it would lift t15 without lengthening rounds. Result (19-round idle-P1)
  did the OPPOSITE on every axis: off-stage kills 1.58/10 (DOWN from 2.07), SD 58%, kill-decided
  42%, median 20.6s. Mechanism: aggressive edge-guarders over-commit chasing floaty off-stage
  victims, whiff supers, and drag/self-destruct — fewer clean kills, not more. Reverted (git
  checkout, no commit). Baseline: tools/out/idle_edgeguard.json.
- [x] **BOUNDED CONCLUSION:** the committed dry-reflect fix is the BEST state measured. Both
  natural levers to close the one clear gap (t15 edge-guarding 2.07 vs ≥3/10) regress pacing —
  sting-up trades t10/t11 for t15; edge_guard-up wrecks all four. t15 is not tunable to target
  via these knobs → it's now a game-designer question (recalibrate the ≥3/10 bar for the idle-P1
  / L2-L3-L4 config, or edge-guarding needs a mechanic change beyond tuning), NOT more knobs.
- [x] Fixed a skill defect found by dogfooding: feel-campaign Phase 0.4 harness said "P1=L3
  brain" — contradicts spec §9's idle-P1 harness (tests 13/14 require idle P1) and roughly
  doubled apparent SD. Corrected to idle-P1 + multi-match aggregation.

- [x] **Kill-zone rebalance BUILT + QA'd (c6229c4) — recovery gamble WORKS, but pacing regressed;
  solidity GATE model needs revision.** Smoke test: solid hits launch (capped 2200), glances spin,
  a 45° solid smash arcs back alive-in-bounds (the owner's ask — CONFIRMED). BUT idle-P1 QA at the
  new geometry: solidity_min=0.25 → 83% SD / 17% kill-decided and only **1 recorded smash in 13
  rounds**; lowering to 0.1 (live eval) → 50% SD / 50% kill-decided, still only 2 smashes/8 rounds
  (both s≈0.9). ROOT CAUSE: `solidity=dot(velocity, line-of-centers)` is low for most real bouncy-
  motion hits (attackers rarely travel straight through center at contact), so the GATE (launch=0
  below `smash_solidity_min`) neutralizes ~all real hits → kills vanish → SD dominates. Lowering the
  floor is a partial patch, not a fix. ROUTED to game-designer: revise solidity from a GATE to a
  BASELINE+BONUS model (every eligible smash launches a baseline; solidity adds a center-hit bonus
  toward the cap) so kills stay frequent AND center hits still "really send them flying" (owner) AND
  glances stay survivable. Then re-build + re-QA. Samples were thin (6–8 rounds, matches end fast/
  slow) — the re-QA needs ≥24 aggregated. HEAD left at solidity_min=0.25 (the build value); the
  curve revision will set real values.

- [x] **Kill-zone v2 (baseline+bonus, 2b7363a) BUILT + QA'd — zero-launch cliff FIXED, but pacing
  still fails; launch-floor lever REFUTED (2 cycles).** Smoke sweep perfect: s=0→1320 baseline,
  monotonic to 2200 cap, never zero; sting 0 glance / 30 center. But idle-P1 aggregate pacing
  gradient: baseline(pre-rebalance) 28% SD / 72% kill-decided / 14% suicide → v1 gate0.25 83%/17%
  → gate0.1 50%/50% → **v2 floor0.6 53% SD / 47% kill / 39% suicide** → **floor0.8 54% / 46% /
  31%**. Raising the launch floor 0.6→0.8 moved SD 53%→54% (NOTHING) — launch magnitude is not the
  bottleneck. FINDING: the recovery gamble (survivable knocks, the owner's ask) STRUCTURALLY pins
  SD ~50% — median round sits at the 20s SD line because most exchanges are non-lethal by design,
  and ~1/3 of kills are self-destructs. This is a design TENSION (recovery-gamble vs ≤25% SD
  target), not a tunable knob. Two candidate resolutions ROUTED to game-designer: (a) make the
  STING the executioner (starve solid-hit victims so failed-recovery kills fire fast — the untried
  lever, targets the right death, but trades against the gamble); (b) reconsider whether ≤25% SD is
  even the right target for a recovery-gamble design, vs accepting ~35% if SD rounds are exciting;
  PLUS (c) a likely CREDIT-WINDOW bug — long recovery arcs exceed the 2.5s kill_credit_window, so
  failed-recovery kills are mis-recorded as suicides (the 31–39% unattributed) — fix likely
  independent of the tension. Samples 13–17 rounds (thin; re-QA at ≥24). HEAD = v2 floor 0.6.

- [x] **Kill-zone v2.1 game-designer ruling FILED** (spec §5.2/§9/§11): (1) SD target RECALIBRATED
  ≤25%→**≤40%** / kill-decided ≥60%, gated by new **test 31** (SD rounds must be ACTIVE: median
  supers ≥12, resolve ≤27s — a stall still FAILS) — reconciles the target with the owner's
  survivable-knock design (SD-as-climax, not failure); (2) STING made executioner via COMPOUNDING
  (`sting_compound_window=1.5s`, `step=0.75`, `cap=2` → 30/52.5/75 at s=1) — isolated sting
  unchanged so the gamble + glance-0 hold; bites only on ACTIVE follow-ups, avoiding the refuted
  flat 30→40 drag; targets the owner's "second knock mid-recovery" death + seeds the red-pulse
  damaged state; (3) CREDIT-WINDOW fix — persist credit through launch state (interim
  `kill_credit_window` 2.5→4.0, cap 6.0) to fix the 31–39% mis-attributed suicides. Launch-floor
  stays a FEEL knob, never pacing. Predicted SD 53%→~40–45%. Build per §10, re-QA whole §9 +
  tests 22–33 at ≥24 rounds.

- [x] **Kill-zone v2.1 (compounding sting + credit fix, f27a695) QA'd — credit FIXED, pacing did
  NOT converge; ESCALATED to owner as a core-vision fork.** Credit fix WORKED: unattributed
  suicides 39%→13% (baseline ~14%). Edge kills strong: 5.3/10 (t15b passes). BUT SD 68% /
  kill-decided 32% / median 23.8s — compounding sting did NOT move SD (rarely triggers: sustained
  same-victim juggles are uncommon in a 4-body scrum). FULL GRADIENT across 6 configs: SD =
  28%(baseline) / 83%(gate.25) / 50%(gate.1) / 53%(v2 floor.6) / 54%(floor.8) / 68%(v2.1). Pacing
  is STUCK at 50–68% SD regardless of lever — the recovery gamble (survivable knocks) STRUCTURALLY
  makes rounds resolve by laser, not kills. Even the recalibrated ≤40% target is not met. This is
  now a VALUES fork on the owner's core combat vision (how lethal should hits really be — TowerFall
  "positioning avoids lethal hits" vs "most knocks survivable, recover-or-laser"), NOT a tuning
  problem. Tuning has been exhausted (6 configs); further studio knob-turning would be thrashing /
  goalpost-moving. AWAITING OWNER DIRECTION (see the fork presented 2026-07-03). What's KEEPER
  regardless: the runway (wider bounds), hit-solidity launch model, credit fix, edge kills.

- [x] **Redesign SLICE A SHIPPED (damage system, 4ebca72)** on the existing arena. Lv0/1/2 escalate
  on a qualifying smash (≥1500), 8s full-heal, reset on death; launch ×1.0/1.33/1.66 applied after
  the 2200 cap before the 3000 limit → Lv0 2200 / Lv1 2926 / Lv2 3000-capped (verified exact);
  red self_modulate pulse (1.5Hz/4Hz). Compounding sting removed. KNOWN ISSUE: `Color(1,g,g)` reads
  as red on the PINK skin but muddy on blue/green/yellow (multiply can't add red) → routed to
  art-director for a cross-skin "damaged" visual (additive overlay/rim/emblem). IN FLIGHT:
  slice B (level-relative bounds from play_rect + edge-economy validation) + the art-director pulse
  ruling (parallel; only B uses the game). Combined A+B feel-QA (mid-survive vs edge-kill vs
  Lv2-fly-further) comes when B lands. Then slice C (kill-race match mode), then D (levels).

- [x] **Redesign COMBAT CORE complete (slices A+B + pulse fix).** A: damage system (6a2ff3b←4ebca72).
  B: level-relative bounds (6a2ff3b) + edge economy VALIDATED (mid-stage hit arcs back alive; same
  hit near edge rings out; Lv2 flies ~344px further → out where Lv0 survives — the owner's kill
  economy working end-to-end). Pulse fix (f09d8b9): crimson alpha-blend overlay reads on all skins
  (pink verified crimson in-engine; blue/green/yellow peak = deterministic alpha math + art-director
  re-grade pending). IN FLIGHT: slice C (kill-race match mode). Then D (level pool).

- [x] **Redesign BUILD COMPLETE (slices A+B+C+pulse) + dead-code cleanup (3f97039).** Full-match
  watch (4-bot self-play): structure ALL WORKS — stages rotate, kills accumulate across stages
  (reached [2,7,5,6] by stage 9), lives reset per stage, last-one-standing resolves, match-end on
  winning kill, zero laser SD. **NEW PACING FINDING (depth-first gate — not genuinely-good yet):
  1v1 stage-closeouts STALL.** With lives=1 + no timer + survivable knocks, the final 2 players
  circle — stage 1 sat 2-alive for ~73s before a death. Stages resolve fine at 3-4 players (kills
  happen) but the 2→1 endgame drags; damage escalation eventually forces it but too slowly. Result:
  ~7 kills / 8 stages / ~7min → a match to 10 would run ~10-12min vs the 2.5-5min target. This is
  the recovery-gamble-vs-resolution tension resurfacing at the STAGE CLOSEOUT. Likely primarily a
  BOT issue (evasive bots circle in 1v1; humans would push) — ROUTED to game-designer: rule whether
  it's acceptable (party tension / humans push) or needs a fix (bot 1v1 aggression is the prime
  candidate; possibly damage-escalation tuning or a no-timer anti-stall for the 2-player endgame —
  NOT a round timer, per owner). Evidence: watch_match log, killrace_1v1_stall.png.

- [x] **Slice C.1 (bot finisher mode, 08041b6) — 1v1 stall FIXED.** Closeout 73s → median 4.9s /
  p90 12.8s / max 21s (criterion 15 PASS); gating correct (240 samples, finisher only at ≤1
  opponent, 3-4p byte-identical). BUT full-match still 6.6-8min vs 2.5-5 target — NEW FINDING: the
  cause is the 3-4-player MELEE (stages dwell 16-102s at ≥3 alive), NOT the closeout. The spec's
  "3-4p pacing is fine" premise is FALSIFIED. Match-length math: to-10-for-one-leader ≈ ~8 stages;
  at ~50s/stage = ~6.7min, at ~15s/stage = ~2.7min (target). So the fix is FASTER STAGES = faster
  melee. This is the survivable-knock→slow-kills tension at a THIRD layer (after round-SD and 1v1).
  Prime candidate (ON-DESIGN): bots CHASE/FOCUS the wounded (the owner's explicit run-and-chase
  dynamic) → convert the damage system into kills faster via focus-fire to Lv2, without global
  lethality changes or undoing the recovery gamble. ROUTED to game-designer to reopen the melee
  premise + rule (bot focus-fire vs kill-target/feel reconciliation). Evidence: finisher_probe2.py.

- [~] **OWNER ARENA DIRECTIVES 2026-07-03 (`docs/feedback/owner_2026-07-03_arena_size.md`) — reshape
  the QA substrate.** (1) dev_arena is too tight for real play → new PRIMARY arena ~2x wider
  (~3584px walkable), platforms spaced out. (2) More VERTICAL gap floor→upper platforms (they're
  ~270-440px now → a bounce reaches them; players bonk the ceiling and never need to FLY). Size gaps
  so normal-boost is REQUIRED to traverse + super for big leaps — the level must exercise the jetpack
  (movement-feel thesis). (3) **Run all tests on a ~10-LEVEL CIRCUIT**, not one arena — the mode
  rotates levels, so QA must too. CONSEQUENCE: all prior single-arena pacing QA (lethality, melee,
  closeout, match-length, incl. slice C.2) is PROVISIONAL, to be re-validated on the circuit.
  IN FLIGHT: level-designer authoring the 2x flagship arena (design/math only, port busy).
  PLAN (depth-first): flagship 2x arena → validate in-engine (flight-required, edge economy, feel)
  → author ~9 more varied levels to that bar (the circuit) → wire LEVEL_POOL → re-run ALL pacing/
  feel QA on the circuit rotation. The level pool (was slice D) is now a QA PREREQUISITE, promoted.

## NEXT STEPS in priority order
1. **LIVES + DAMAGE + DUCK-GAME KILL-RACE REDESIGN (owner directive 2026-07-03,
   `docs/feedback/owner_2026-07-03_lives_damage_killrace.md` + DECISIONS).** This SUPERSEDES the
   kill-zone SD-tuning saga below and DISSOLVES the SD-rate problem. Core: no round timer;
   lives-based (default 1) elimination stages; SD = simultaneous double-KO only (0.5s); match =
   race to 10–15 kills across frequently-rotating levels; damage system (Lv1 slow-pulse/+33%/8s,
   Lv2 fast-pulse/+66%/reset-8s); edge-relative kills; level-relative bounds. Spec pass ROUTED to
   game-designer (reconcile vs round_loop / lethality / kill_zone_recovery; propose depth-first
   build slices). Likely slice order: (a) combat core — damage system + edge-relative bounds +
   lives elimination round-end on the existing arena, validate the FEEL; (b) kill-race match mode
   + level rotation; (c) more levels (level-designer). KEEPER from kill-zone work: hit-solidity
   launch model, credit fix (window 4.0), edge kills. HEAD combat = v2.1 (f27a695).
   --- superseded context below (the kill-zone SD-tuning that led here) ---
1b. ~~KILL-ZONE REBALANCE~~ (SUPERSEDED by #1; kept for history). Owner watched real gameplay: the
   kill zone is too tight,
   a single hard knock (even straight up) kills instead of arcing back into the fight, and an
   angled (45°) knock is never survivable-with-a-fly-back. The recovery gamble (movement-feel
   thesis applied to death) is absent. Diagnosis (math + in-engine): the super (2800) overshoots
   the top bound (−950) by 500–800px, and — the deeper cause — SMASHES are licensed only to
   super-speed attackers and scale by `smash_impulse_from_attacker=1.35`, so landed smashes are
   ~3000–4000 impulse (harder than the super) → one-shot ring-outs at ANY angle; widening bounds
   alone can't fix that (a 3500 impulse at 45° travels ~7600px). Reopens spec §2.4 (which tightened
   bounds to fix kill-rarity — reconcile, don't blind-revert). Fix model: kills come from FAILED
   RECOVERY, not tight walls — wider bounds (top+sides) + softer/capped smash impulse so knocks are
   survivable-and-recoverable, kept frequent because recovery is a real gamble (fuel, second knock,
   bad angle); lasers stay the backstop. Also needs camera work (it currently frames the tight
   stage). **SPEC WRITTEN: `docs/specs/v0_kill_zone_recovery.md`** (reads as parent §2.5; supersedes
   §2.1 impulse formula + §2.4 bounds; adds §9 tests 22–30). Root cause sharpened: `velocity`
   `.limit_length(3000)` slams EVERY clean smash to the max_speed cap → solidity invisible, arc
   impossible. Levers: (A PRIMARY) HIT-SOLIDITY via impact parameter `s = dot(vel_dir, contact_normal)`
   scales launch+sting+spin on the current sphere collider; (B) bounds left/right −1100/3000, top
   −1200; (C) new `smash_impulse_max=2200`, `smash_impulse_from_attacker` 1.35→1.1, new
   `smash_solidity_min=0.25`, `smash_spin_max=12`. Kills come from sting-starve + self-super void,
   not walls. Camera-follow + `smashes[]` round_stats instrumentation are gameplay-programmer deps.
   BUILD next (per §10 checklist), then tuning search + re-run the whole lethality QA (the 29-round
   metrics were measured against the old geometry).
2. **THEN finish the 21-criteria lethality sign-off** (after the kill-zone re-QA): t15 is RESOLVED
   (ruling applied → spec v2.2: t15a ≥2/10 ships = PASS 2.07, t15b ≥3/10 deferred to the feel
   campaign); t11 (28% SD, one round over) rides within noise. Remaining to file: 6a/6b/6c/6d
   staged, 13/14/16/17/19/21 + powerup C1/edge checks + 3-match feel judgment. Use skill
   `gottabounce-feel-campaign` (Phase 1) — harness now correct.
2. **Build movement courses 1–3** (docs/specs/v1_movement_courses.md) — the feel-tuning
   instrument; Chimney validates the un-charged super. Level-designer + gameplay-programmer.
3. **Art-director evaluation: goat identity candidate** (see DECISIONS + owner feedback doc) —
   crazy goats w/ horns + goat scream on super vs the shipped Glossy Toybox blobs. Art fix list
   (small): (a) far-zoom floor mat thin; (b) trampoline-floor "rope" up close;
   (c) tumble rotation reads sideways; (d) wire assets/fx/puff_soft.png + star_sparkle.png into
   Juice particles; (e) real font asset to replace SystemFont stack in theme.tres; (f) art skull
   icon for PlayerCard; (g) name-tag blink inherit; (h) unlimited-boost flame telegraph pass;
   (i) black-hole vignette; **(j) OWNER-FLAGGED 2026-07-03: bush/fence props read as "floating in
   the sky, far behind the play area."** Root cause `ArenaRenderer.gd:192-218` — bush_round/fence_wood
   are "Layer 4 mid props" on 0.55 parallax at `z_index=-80` with aerial-desat modulate, anchored to
   `floor_y+24`; at 0.55 parallax they scroll at ~half camera rate so they detach from the ground and
   drift up, and behind-everything + washed-out they read as distant sky objects, not grounded set-
   dressing. The kill-zone build's wider bounds make it MORE visible. Fix = art-director rules the
   correct diorama depth (candidate: move ground props to a near-ground plane, parallax ~0.9–1.0,
   z just behind platforms, grounded on the floor line — vs the far-hills horizon), then renderer
   tweak. Small; not on the critical path (kill-zone QA is).
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
