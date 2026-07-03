# Decision Log

One line per significant/irreversible decision. Newest first.

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
