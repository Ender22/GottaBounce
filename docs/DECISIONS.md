# Decision Log

One line per significant/irreversible decision. Newest first.

- **2026-07-04** MOVING-HAZARD FEATURE APPROVED (stretch, additive — `docs/specs/v1_moving_hazard.md`)
  for the `wrecking_yard` 11th level. A KINEMATIC pendulum shove-hazard that reuses the existing SHOVE
  path (`receive_shove`/`_soft_separate`, clamped ≤ soft_bump_max 700) with **NO hitstun/sting/damage**
  — so a shoved player keeps control + can recover (a hitstun-hazard would be an unrecoverable void
  instakill, violating the through-line + recovery gamble). Credits NOBODY directly: reuses the 6s
  ring-out window (tag-then-void = credited; pure hazard shove = correct uncredited self-fall; no
  invented environment scorer, INV-9). New level-JSON `moving_hazard` object type + `Player.receive_shove`
  + `EventBus.hazard_shoved` + a round_stats field — all ADDITIVE, touches NO fenced constant (change-
  control gate satisfied; the §2 credit audit is the artifact). De-risked build order: shove-contact
  path → static shove-plate fallback → pendulum+telegraphy → LEVEL_POOL last. A static elastic-bumper
  version is DO-NOT-SHIP (bumper_gauntlet clone) — defer the level rather than pollute the rotation.
- **2026-07-04** CD VERDICT #6 = **SHIP** — the COMPLETE build is couch-ready. Milestone: the core game
  is feature-complete + shipping-quality. All four fantasy verbs confirmed hands-on (flight REQUIRED:
  fuel=0 falls in / boost survives; super-smash reads via charge+aim+blast VFX; credited kills 76%,
  up from #5's 59%; motion clean — stuck 1.48s/15 stages, head-banging gone, exploit fix holds). Audio,
  VFX telegraphy, 10 themed distinct-kill-shape levels, match-end/rematch, powerups all land. 3
  NON-BLOCKING last steps: (1) match pacing under all-bot 1-life melee is fast (5-8s stages, lots of
  inter-stage ceremony) — sanity-check with human pace + confirm 10-cumulative/1-life is the sweet spot
  (top "one more round" tuning risk, not a break); (2) the 4 sunny-blue levels want a stronger visual
  signature beyond sky tint (reserved generated-tileset option); (3) verify the stage-end delta banner
  never shows an all-negative survivor -1 in clean play (likely a force-load artifact). Record:
  `docs/briefs/cd_verdict6_2026-07-04_complete_build.md`.
- **2026-07-04** PROCESS GAP CLOSED (owner-flagged) — bots head-banged platform undersides (dumb
  motion) and it shipped uncaught because ALL bot validation measured OUTCOMES (kill%/off-screen%),
  never MOTION quality; stats hide motion, screenshots are stills, bots never complain. GAME_ESSENCE
  warned of this exact blind spot but we only wrote the warning, never a gate. DECISION: validate
  felt/motion quality as NUMBERS — add a permanent bot-motion-health probe (stuck/no-progress episodes,
  downward-normal underside-bounce count, blocked-ascent flag) to the QA feed, and make "watch bot
  MOTION + report locomotion pathologies" an explicit QA obligation (not just outcome stats). Fix the
  pathing (obstacle-aware ascent) AND build the detector so this class is caught automatically.
  Memory: [[gottabounce-validate-motion-not-just-outcomes]].
- **2026-07-04** 10-LEVEL VARIED CIRCUIT COMPLETE (v1_level_circuit.md) — islands_void, grassy_expanse,
  drop_chamber (enclosed_hole drum), the_spine (ridge), twin_chasms (two-void), the_cliff (asymmetric),
  atoll (radial well), spires (verticality), bumper_gauntlet (interior pinball), the_ascent (dual
  vertical blast). Each in-engine validated + distinct kill-shape/feel over the shared off-screen-kill
  through-line. Reusable render infra added: per-level `kill_shape` + `backdrop` (enclosed/open_sky)
  modes. wrecking_yard (moving hazards) deferred to a stretch 11th level. THEN: theming pass + circuit QA.
- **2026-07-04** CD VERDICT #5 = **SHIP** — islands_void flagship kill-fantasy gap CLOSED (credited
  kills 59% vs 41% uncredited, flipped from verdict #4's ~25/75; 79% of kills go off-the-bottom into
  the void; real hands-on smash-off lands + attacker survives; knocked-off bots actively recover).
  RULINGS: (1) the WHIFFED super is **ACCEPTABLE committal risk** (only a down-aimed-near-rim whiff
  self-ringouts; flat/up whiffs carry safely; genre-standard, ~1/stage) → the whiff-arrest fix
  `v1a_super_whiff_safety.md` is OPTIONAL BACKLOG, not built; the fenced `super_boost_impulse_full`
  stays untouched. (2) The CAMERA follow-cluster-with-readability-floor concept is CORRECT (owner ask;
  damped pan, no hard cuts) — keep it; refine follow-TARGETING only (weight local human in-frame +
  cluster hysteresis + no empty-geometry framing), non-blocking. GREEN LIGHT to build the 9-level
  circuit on this template. Follow-ups the circuit inherits: P1 void render is zoom-dependent (extend
  dark fill/AO under inner islands before ×10); P2 ring-out credit-window inflation (idle-survivor
  artifact). Full record: `docs/briefs/cd_verdict5_2026-07-04_islands_fixed.md`.
- **2026-07-04** CD VERDICT #4 = FIX on the integrated flagship (islands_void + audio). Concept
  validated (fly REQUIRED, void reads lethal, recovery real, audio is a real finished-game layer),
  but the KILL FANTASY fails: ~75% of deaths were uncredited self-suicides (killer=-1), not credited
  smash-offs. Root cause found — **the super impulse (2800, tuned for the 2×-WIDE grassy arena)
  OVERSHOOTS the narrow 520-640px islands and self-ringouts the ATTACKER**; the kill move doubles as
  a self-destruct near the void. DECISION: fix flagship BEFORE building the circuit (all 9 new levels
  would inherit the seam). Fix approach — GEOMETRY FIRST (widen islands to give the super forward-carry
  runway; keep gaps flight-required), MEASURE killer=-1 share, and escalate to an arena-relative super
  ONLY if geometry can't fix it (the drain-all super constant stays fenced unless data forces it).
  Also P2: `_classify_blast_edge` was blind to void-floor kills (bucketed them "pit"), so component QA
  passed while integration failed — being fixed via a per-level kill_shape field. Record:
  `docs/briefs/cd_verdict4_2026-07-04_islands_audio.md`, `docs/specs/v2a_kill_shape_void_floor_addendum.md`.
- **2026-07-04** ARENA DIRECTION DECIDED (owner) — **islands-over-a-void is the PRIMARY/default kill
  shape** (edges/void = off-screen kills = the "smash rivals off the screen" fantasy; resolves the
  central-pit-dominance finding — 3 independent analyses converged, CD verdict #3). BUT levels are
  NOT a monoculture: **different levels can have different STYLES/gimmicks**, as long as the kill
  identity stays "knock people off/through into a blast void." Owner's concrete seed: a chaotic level
  fought **inside a CYLINDER with a hole in the bottom you try to knock people through**. So: the
  ~10-level circuit = varied styles/themes/gimmicks over a shared off-screen-kill through-line; the
  current central-pit `grassy_expanse` survives as ONE variant ("chase/big map"), not the flagship.
  Full record: `docs/feedback/owner_2026-07-04_arena_variety.md`. Build: a new islands-over-void
  flagship arena → then varied circuit levels.
- **2026-07-04** AUDIO GREENLIT + SOURCING DECIDED (owner). Wire an AudioManager/SFX-bus architecture
  and add SFX (bounce/boost/smash/impact/ring-out/super/powerup/UI/announcer) + music. Sourcing:
  **reuse from the existing SFX library at `D:\Dropbox\MyGames\SamuraiRobot2.0\assets\sounds\fx`
  (207 files)** for anything that fits, **find CC0/online packs or GENERATE** the rest. Music library
  already in-repo (`assets/music/`: 7 mp3 + title.wav from session 1). Record:
  `docs/feedback/owner_2026-07-04_arena_variety.md` (audio section). The absent audio is the loudest
  remaining "not a finished game" gap (CD passes) — high-priority once the arena flagship lands.
- **2026-07-03** STUDIO PROCESS UPGRADE (owner-prompted, after the too-tight-arena miss slipped
  every role): root cause = the studio verifies COMPONENTS against SPECS but no role reasons from
  the game's ESSENCE about whether the INTEGRATED experience delivers the fantasy; briefs stated the
  game's facts but never made "is the core fantasy happening?" a required check (e.g. the level-
  designer brief never said "flight must be required to traverse", and pointed at a non-existent
  docs/ARCHITECTURE.md). Fixes: (1) NEW `docs/GAME_ESSENCE.md` — required reading for all roles,
  turns the fantasy into per-role fantasy-fit OBLIGATIONS + a first-principles "played as a human,
  is the core fantasy happening?" checklist; (2) NEW role `creative-director` (player advocate) — the
  holistic critic of the integrated build, the structural stand-in for the absent human playtester;
  (3) STUDIO.md loop gains a mandatory fantasy-fit pass; (4) level-designer brief now REQUIRES a
  movement-tool-per-gap analysis proving flight is required (+ schema-ref bug fixed). Standing
  lesson: bots don't complain, specs describe mechanisms, specialists optimize slices — guard the
  integrated experience explicitly.
- **2026-07-03** GOAT/RAM IDENTITY UN-GATED — now a GAMEPLAY lever, not just cosmetic (owner). The
  earlier "adopt-staged, wait until the super-fantasy validates" gate (art_goat_identity_eval) is
  MET (hit-solidity + recovery gamble built), AND the owner added a new gameplay argument: a taller/
  rectangular (ram) body vs the current short ball changes WHERE on the body you get hit → richer
  hit-solidity sweet-spot variety (head/center/feet become literal, vs the circle's velocity-only
  solidity). That its gameplay implication went unexplored is itself an instance of the process miss
  above. Decision: PROTOTYPE the taller/ram shape as a real gameplay experiment (non-circular
  collider + solidity adapted to vertical hit-position + placeholder taller sprite), playtest the
  solidity variety. Scope honestly: collider-shape change touches physics + art, so it's a deliberate
  slice, not a toss-in. Sequence: alongside/after the circuit + combat re-QA.
- **2026-07-03** MATCH/COMBAT REDESIGN (owner directive, resolves the recovery-gamble-vs-pacing
  fork) — full record `docs/feedback/owner_2026-07-03_lives_damage_killrace.md`. (1) **No round
  timer; LIVES-based, default 1** — stages end by elimination, Duck-Game-fast churn. (2) **SUDDEN
  DEATH removed as a timer/laser mechanic; SD is ONLY a simultaneous double-KO** (2 players lose
  last life within 0.5s). (3) **MATCH = Duck-Game kill-race to 10–15 kills across FREQUENTLY-
  ROTATING levels** (replaces first-to-10-rounds-on-one-arena). (4) **DAMAGE SYSTEM adopted with
  exact params** (supersedes the compounding sting + sets the earlier "transient vulnerable state"
  decision's values): Lv1 after 1 hit (slow red pulse, 8s heal) → +33% launch; Lv2 if hit while
  Lv1 (fast pulse, resets 8s) → +66% launch. (5) **Edge-relative lethality:** dead-on hit near the
  level edge kills; mid-stage doesn't; damaged players fly further → out; fuelled players fly back.
  (6) **Kill zone level-relative** (scales with level width). DISSOLVES the SD-rate tension → the
  ≤25%/≤40% SD target + test-31 are MOOT. KEEPER: hit-solidity launch, credit fix, edge kills,
  runway (now level-relative). Reopen only with owner input. Spec pass routed to game-designer.
- **2026-07-03** COMBAT PACING BAR RECALIBRATED for the recovery-gamble design (spec
  v0_kill_zone_recovery.md §5.2/§9/§11). QA proved the recovery gamble (owner's survivable-knock
  ask) structurally pins SD ~50% and the launch-magnitude lever is refuted for pacing. Ruling:
  (1) SD target ≤25% → **≤40%** + kill-decided ≥60%, GATED by new test 31 (SD rounds must be
  active climaxes: median supers ≥12, ≤27s — stalls still fail). Rationale: ≤25% was set for the
  pre-recovery knocks-kill model; the owner reversed that premise, so longer rounds are intended
  and SD-as-lasers-closing is a climax not a failure — but guarded against stalls. (2) The STING
  becomes the executioner via COMPOUNDING follow-ups (30/52.5/75 at s=1 within 1.5s), NOT the
  refuted flat sting-up; isolated sting/glance-0 unchanged so the gamble holds. (3) kill_credit_
  window 2.5→4.0 (persist through launch state; cap 6.0) — scoring fix for mis-attributed
  failed-recovery kills. Launch-floor is a FEEL knob, never a pacing lever. This is the studio
  choosing "let recovery drama breathe + guarantee SD rounds are exciting" over "tight fast rounds",
  in line with the owner's movement-feel thesis. Reopen if owner wants tight pacing over the gamble.
- **2026-07-03** DAMAGE MODEL DECIDED — transient "damaged/vulnerable" STATE, not persistent %.
  Owner picked the reeling-window form: a character pulses RED when damaged (read on the body, not
  a HUD meter) and SLOWLY HEALS; while damaged it is more launchable → run-and-chase dynamics
  (finish the wounded before they heal / flee to survive). Persistent Smash-style accumulation
  REJECTED (conflicts with no-HP identity, competes with fuel, whittling meta). Guardrails: stays
  transient + heals FULLY + non-stacking (must not become the rejected HP model); watch flee-to-
  heal vs Pillar 2. THE open dial = heal duration (~1–2s juggle window vs ~4–8s flee/chase state;
  owner leans long). SEQUENCING: next slice AFTER `v0_kill_zone_recovery.md` lands+validates (it's
  built on the hit-solidity mechanic now in build) — depth-first, do not spec against an unproven
  base. Full record: `docs/feedback/owner_2026-07-03_kill_zone.md` Idea B resolution.
- **2026-07-03** KILL ZONE TOO TIGHT — OWNER FEEDBACK, lethality sign-off HELD, spec §2.4 reopened
  (`docs/feedback/owner_2026-07-03_kill_zone.md`). Owner watched gameplay: a single hard knock
  (even straight up) kills instead of arcing back; angled knocks are never survivable-with-fly-back;
  the recovery gamble is missing. Diagnosis: super (2800) overshoots top bound (−950) by 500–800px,
  and smashes — licensed only to super-speed attackers, scaled ×1.35 — land at ~3000–4000 impulse,
  one-shotting at any angle (bounds-widening alone can't fix). Fix model: kills = FAILED RECOVERY,
  not tight walls (wider bounds + softer/capped smash impulse + camera follow; lasers stay backstop).
  Reconcile vs §2.4 (tightened bounds to fix kill-rarity — don't blind-revert). Re-run lethality QA
  after: the 29-round metrics were measured against geometry the owner says is wrong.
- **2026-07-03** t15 RULING APPLIED → spec v2.2 (`docs/briefs/edge_guard_t15_ruling.md`). Edge-guard
  criterion split: t15a (idle-P1 floor ≥2/10, ships — PASS 2.07) + t15b (all-L4/human ≥3/10,
  follow-up in feel campaign, non-blocking). ≥3/10 was mis-set for the idle-P1 / L2-L3-L4 field;
  both tuning levers to reach it regress pacing. Not goalpost-moving — the skill bar is preserved,
  relocated to the harness where edge-guarding actually lives.
- **2026-07-03** §2.3a DRY-REFLECT FIX COMMITTED + `smash_sting_fuel` 30→40 REJECTED. QA
  (idle-P1, spec §9 harness, 29-round aggregate) confirmed the fix is a net win: kill-decided 72%
  (PASS), median 16.0s (PASS), SD 28% (marginal — one round over ≤25%), edge kills 2.07/10 (up
  ~5× from the pre-fix 1/23, short of ≥3/10). A prediction-first `smash_sting_fuel` 30→40
  experiment fixed edge kills (3.64/10) but regressed SD to 41% and kill-decided to 59% —
  **refuting the spec §2.4 "edge-lethality cascades into lower SD" assumption.** Not adopted.
  Diagnosis: SD rounds resolve with all 3 kills (not stalemates) but slowly (22.5s vs 12.9s), so
  the residual gap is late super→kill conversion. Next lever for t15 is the bot `edge_guard`
  dial, NOT a physics constant. Lethality v2.1 = fix landed, full 21-criteria sign-off still open.
- **2026-07-03** BOT `edge_guard`-UP REJECTED (2nd t15 experiment). Raising edge_guard (L2 0→0.3,
  L3 0.3→0.6, L4 0.7→0.9) to lift off-stage kills did the opposite: t15 → 1.58/10 (down), SD 58%,
  kill-decided 42% — over-committed edge-guarders whiff and drag rounds. Reverted, not adopted.
  With BOTH natural levers (sting, edge_guard) now refuted, closing t15 (edge-guarding 2.07 vs
  ≥3/10) is escalated to the game-designer as a bar-calibration / mechanic question — no more
  blind knob-turning (methodology: stop when the obvious mechanisms are exhausted).
- **2026-07-03** OPERATOR SKILL LIBRARY added under `.claude/skills/` (16 skills) as the studio's
  onboarding/runbook layer for cheaper future sessions. Authored parallel, 3-way reviewed, fixed.
  Non-load-bearing on gameplay; documents ground truth as of HEAD and routes all change through
  the existing change-control doctrine (no new gates, no routing around STATUS/DECISIONS).

- **2026-07-03** BUMPER/BOUNCE RECOVERY GATE RULED (v2.1 fix to combat lethality, closes QA
  re-verification FAILs 11/13/14/15): governing principle **"hitstun ends by TIME, never by
  touching a surface."** Root cause was fix-round 587d0a1 making `_on_bounced()` unconditionally
  refund fuel + clear hitstun on every bounce, so a bumper 660px inboard of the kill line
  auto-saved every edge-bound smash victim. Ruling: if a player is currently in
  opponent-inflicted hitstun (`_stun_timer > 0.0`) at the moment of surface contact, the contact
  is a **dry reflect** — the physical bounce/ricochet still resolves (no clipping), but fuel is
  NOT refunded and hitstun is NOT cleared; it expires on its own clock as before. Neutral
  (non-stunned) contact is unchanged, which is what preserves the owner's wall-return shot intact
  (that move never involves hitstun by construction). `fuel_per_bumper` stays 20.0 — not raised,
  not lowered; only the stunned-case gate was the bug. A bumper-reflected stunned body remains a
  licensed smasher per the existing §2.1 rule and `_stunned_by` pairwise immunity already prevents
  it from re-hitting its own launcher — accepted as intentional Pillar-3 pinball chaos, now
  earned rather than free. The buffered-super-through-empty-tank behavior was reviewed and kept
  as-built (it re-arms every held frame within `input_buffer`, cannot fire off a dry reflect since
  a dry reflect produces no fuel — not an exploit). Applies uniformly to both bumper and tier
  bounces (no per-surface special case). Spec: `docs/specs/v0_combat_lethality.md` §2.3a (v2.1).
  New QA criteria 6c (dry-reflect kill retained) / 6d (wall-return shot still fires) lock this in.
- **2026-07-03** GOAT IDENTITY EVAL COMPLETE — verdict **Adopt-staged**: horns are a cheap,
  on-brand, minimal-delta upgrade (add horns to existing blob ref sheet, no anatomy/style pivot)
  that strengthens the super-boost-as-kill-move fantasy and readability, BUT gated until the
  un-charged lethality mechanic + movement courses validate the super-fantasy is actually fun
  (do not spend art budget theming an unvalidated mechanic). Fold horn art into the aim-pose art
  pass that lethality needs to commission anyway (currently no distinct aim sprite — see
  lethality_aim.png). Goat scream SFX is separable/cheap, gate only on a super-fire event existing
  in code. Full brief: docs/briefs/art_goat_identity_eval.md.
- **2026-07-02** SUPER BOOST REDESIGNED (owner movement-feel directive, evaluated & adopted):
  **un-charged** — full power at any fuel ≥ `super_boost_min_fuel` (5), always dumps the whole
  tank, ≤2s aim-hover then auto-fire, no cancel. Supersedes GDD §4.3 "super strength scales with
  remaining fuel" AND the charge-hold implementation (`super_charge_*` removed). Rationale: the
  charge model double-taxed the game's only kill move (bank fuel AND stand still), causing the
  hoarding/whiffing QA saw; un-charged enables super-chaining, wall-climbs, dodge-counter supers.
  Drain-all (not flat cost) so every chain routes through a bounce — surfaces are the combo
  system. Spec: `docs/specs/v0_combat_lethality.md` v2. Reopen only with movement-course evidence.
- **2026-07-02** CONTACT MODEL = TWO TIERS (owner directive, adopted with one amendment):
  momentum-scaled SHOVE (no hitstun; kill credit on strong shoves) vs SMASH (hitstun + launch +
  sting) — smash license limited to **super-active attackers and stunned flying bodies** (the
  amendment: smashed bodies stay projectiles so Pillar-3 chain-reaction comedy survives).
  v1 lethality spec's light-smash tier (boost-rams cause hitstun) is dead. Recovery-window triad
  (GDD §4.6) unchanged and re-tested both directions in spec §9.6.
- **2026-07-02** MOVEMENT COURSES adopted as the movement-feel TUNING INSTRUMENT (owner method;
  bar = TowerFall): 5 challenge courses, one mechanic each, script-verifiable pass/fail + human
  feel verdicts; they double as combat-change regression suite and future campaign/onboarding
  content. Spec: `docs/specs/v1_movement_courses.md`. Build slot: immediately after lethality v2
  ships QA — before new arenas/art/audio.
- **2026-07-02** THEMING SEED RECORDED — "crazy goats": horns = the super-smash identity, goat
  scream on super fire (owner seed). Status: **candidate identity only** — art director must
  evaluate against the established Glossy Toybox blob direction (VISION.md) before ANY asset or
  audio work; blobs were chosen partly for AI-generatability, so the evaluation must cover that
  too. No art now.
- **2026-07-02** MODE SEEDS RECORDED — sports modes (Rocket-League-ish soccer, volleyball/
  dropshot) grow out of movement courses 4–5 ball prototypes (owner seed). Backlog, post-core;
  course 5 is explicitly the volleyball-mode prototype when it gets built.
- **2026-07-02** Keep the core premise (bounce+jetpack party brawler, Duck Game × Smash) and the
  6 GDD pillars; the old game's failure was execution, not design.
- **2026-07-02** Art direction = "Glossy Toybox" (see VISION.md): blob Bouncers, toy-world arenas,
  matching the v1 generated title screen. Chosen for appeal AND reliable AI generatability.
- **2026-07-02** Engine: Godot 4.7 / GDScript (installed, proven, tooling exists). Renderer:
  gl_compatibility. Physics at 120 ticks/s.
- **2026-07-02** Rebuild in fresh repo; port proven seams from old project selectively rather than
  forking it wholesale (old repo stays untouched as reference).
- **2026-07-02** Validation = rendered playtest via in-game TCP server (port 9090) + gbplay.py
  client + vision review of screenshots. The human owner is NOT in the loop.
- **2026-07-02** Levels stay JSON-driven (geometry+theme separated); UI must be .tscn+Theme;
  input goes through a proper action map (old project polled raw keys — rebuilt).
