# Decision Log

One line per significant/irreversible decision. Newest first.

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
