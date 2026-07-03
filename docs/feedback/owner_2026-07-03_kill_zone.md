# Owner feedback — 2026-07-03 — Kill zone is too tight; the recovery gamble is missing

> High-authority design input from the owner (Devin), from watching real gameplay. Same standing
> as `owner_2026-07-02_movement_feel.md`. Directly reopens `docs/specs/v0_combat_lethality.md`
> §2.4 (blast-zone tightening). Every lethality/bounds decision must reconcile against this.

## The observation (verbatim-adjacent)

Watching the game, the kill zone is obviously too tight to the level. Right now a player gets
knocked hard **once** — even straight up — and they **die**, rather than falling back down into
the fight. And I never see a player get knocked at, say, a **45° angle** (which likely *shouldn't*
kill them) then **attempt to fly back** — they're always just dead.

## What the owner is asking for (the fun he wants)

The **recovery gamble** is the fun: get knocked, arc out toward the edge, and *fight your way
back* with the jetpack — a movement-skill expression (this IS the movement-feel thesis applied to
death). Deaths should be **earned by failed recovery**, not by a wall being 600px away. Only a
truly decisive hit (a clean super into the void, or a knock you can't recover from) should kill;
an angled knock should be a survivable scare you can claw back from.

## First-principles diagnosis (why he's right; g = 1600, y-down)

- The un-charged super adds ~2800 to velocity. Straight up, that rises `v²/2g = 2800²/3200 ≈
  2450px`. From the floor (y≈980) the apex is y≈−1470; from mid-air (y≈700) it's y≈−1750. **The
  top bound is −950** → a full super overshoots the ceiling by 500–800px and rings out on the way
  up, mid-flight, with no chance to arc back.
- At 45°, a 2800 super rises only ~1225px (vertical component² / 2g) — it WOULD arc back — but it
  also carries ~1980px/s horizontally toward a **side bound only ~660px past the platform edge**
  (right = 2520, platform ends x=1856). It crosses the side wall before gravity brings it down.
  → this is exactly the "45° knock that's always just dead" the owner describes.
- Net: both the top (−950) and side (−620/2520) bounds are too close relative to the launch
  impulses, so there is no runway for the recovery arc. The §2.4 tightening (top −1350→−950,
  sides −1000/2900 → −620/2520) went too far for the feel the owner wants.

## The tension to reconcile (do NOT just revert §2.4)

§2.4 tightened the bounds because kills were too rare — lasers decided ~55–60% of rounds ("kills
feel like traffic accidents", QA #1). Simply widening back risks re-introducing that. The
resolution the owner's framing points to: **kills should come from FAILED RECOVERY, not tight
walls.** Give real runway (wider bounds, esp. top + sides) so knocks arc and players attempt a
fly-back; keep kills frequent by making recovery a genuine gamble that often fails — fuel cost
(drain-all super already leaves you low), a second knock, or a bad angle. Lasers stay the backstop.

## Implications

- **Holds the lethality v2.1 sign-off.** The 29-round QA metrics (kill-decided 72%, SD 28%) were
  measured against the geometry the owner says is wrong — signing off now would certify the wrong
  feel. The metrics were measuring pacing correctly but blind to the recovery-gamble dimension.
- This is a game-designer reconciliation (bounds vs §2.4 kill-rarity) + an in-engine tuning search
  (find the widest bounds that keep kills earned-and-frequent), then re-run the lethality QA.
- Candidate levers, in tension: blast `bounds` (top + sides), launch impulse (`super_boost_impulse_full`,
  `smash_impulse_*`), air drift / fuel-for-recovery. Bounds first (it's the owner's direct point);
  the others only if widening alone makes kills too rare.

## Addendum — 2026-07-03 — two follow-up ideas (UNDER EVALUATION, not decided)

Owner proposed two mechanisms for the survivable-knock / recovery-gamble problem. Recorded with
the Studio Director's assessment; neither is adopted yet.

### Idea A — hit solidity (LEAN ADOPT, feeds the kill-zone rebalance)
"How far you smash someone depends on how solidly you hit them" — a dead-center hit sends them
flying (a kill), a glancing hit to the head/feet spins them without launching far.
- **Assessment: strong, and it is the skill-expressive version of the survivable-knock spectrum
  the rebalance needs.** Precision is rewarded (Pillar 1 high ceiling); glancing hits become the
  survivable knocks that arc back (the owner's ask); it composes with wider bounds instead of
  competing with a flat impulse cap.
- **Decouple the mechanic from the character shape.** The mechanic works on the CURRENT sphere
  collider via the impact parameter: `solidity = dot(attacker_velocity_dir, contact_normal)` —
  1.0 = head-on/center (full impulse), → 0 = graze (little impulse + spin torque). No art change,
  buildable now. The owner's "taller rectangular humanoid goat" would make head/center/feet
  LITERAL readable regions (more intuitive) BUT reopens two deliberate decisions — sphere blobs
  chosen for AI-generatability AND circle-collider-matches-art (VISION.md) — and adds non-circle
  collider complexity. Treat the humanoid shape as a SEPARATE gated bet (like the goat horns);
  prototype the impact-parameter version first.
- **Action:** folded into the kill-zone rebalance spec as the primary survivable-knock mechanism.

### Idea B — Smash-Bros-style damage accumulation (OPEN — Director recommends AGAINST the persistent version)
"Maybe damage builds up over time, flinging you further the more you've been knocked around" —
owner explicitly "not sure yet."
- **Attractive:** naturally creates the recovery-gamble arc (early hits survivable, late lethal)
  + comeback tension.
- **Conflicts with identity (why the Director is cautious):** (1) the project explicitly chose
  NO HP / death cheap-and-instant (DECISIONS + INV-9: only bosses have HP) — a persistent per-
  player damage meter is that model returning; (2) FUEL is already the accumulating meter that
  matters — a second meter competes for attention + HUD in a "readable chaos" game; (3) pushes
  toward longer whittling rounds (rack up %, then finish) = Smash's rhythm, against the 10–30s
  snappy "one more round" / constant-motion identity (Pillars 2, 4).
- **Identity-preserving alternative the Director recommends instead:** a short **reeling window** —
  just after being knocked you are briefly (~1–2s, fast decay) more launchable, enabling juggle
  combos WITHIN an exchange (Pillar 3 comedy, real ceiling) without a match-long meter. Composes
  with Idea A: glancing hit → spin/reel → follow-up center hit finishes.
- **Action:** scoped OUT of the kill-zone spec as an explicit open decision for the owner. Not
  built. If pursued, prefer the reeling-window form over persistent %.

### Idea B — RESOLVED 2026-07-03: transient "damaged/vulnerable" state ADOPTED (direction); persistent-% REJECTED
Owner picked the reeling-window form and evolved it: a character **pulses red when damaged and
slowly heals**; while damaged it is more launchable; this creates **run-and-chase mechanics**
(chase the wounded to finish before they heal / flee to survive and heal).
- **Why this is the right shape:** the red pulse is read ON THE BODY (Pillar 6 personality +
  Pillar 5 readable chaos) — NOT a HUD % bar competing with the fuel gauge. It stays transient and
  FULLY HEALS, so it does not become the rejected accumulating-HP model. Chasing/fleeing is
  movement skill (owner thesis) and is motion, not camping (Pillar 2 OK). Composes with hit-
  solidity (a knocked+damaged victim is doubly vulnerable → the finisher).
- **THE dial that decides what this is — heal duration / "slowly":**
  - ~1–2s fast decay = a tight JUGGLE window (combo enabler within one exchange; smallest, safest).
  - ~4–8s = the FLEE/CHASE STATE the owner is describing (bigger upside, bigger surface).
  The owner's "running and chasing" language points at the longer end; the spec must pick and tune it.
- **Guardrails for the eventual spec (keep it from drifting into the HP model we rejected):**
  (1) transient + heals FULLY to baseline; (2) does NOT stack unboundedly (cap the vulnerability);
  (3) "flee to heal" must not become disengagement/stalling — heal slow enough to matter, but in a
  4-player pit fleeing one attacker runs you into others; watch vs Pillar 2 (constant motion, no
  stall). (4) launchability boost must not trivialize the recovery gamble the kill-zone build sets up.
- **Action / SEQUENCING (Director):** this is the NEXT slice AFTER the kill-zone recovery rebalance
  (`v0_kill_zone_recovery.md`) lands AND validates — it is built ON the hit-solidity mechanic that
  is only now being implemented. Depth-first (the rule that sank the last attempt): do NOT spec/
  build against an unproven foundation. Recorded as the decided next direction; game-designer specs
  the "vulnerable/reeling state" once solidity is proven in-engine. NOT part of the current build.
