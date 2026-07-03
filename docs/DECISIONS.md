# Decision Log

One line per significant/irreversible decision. Newest first.

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
