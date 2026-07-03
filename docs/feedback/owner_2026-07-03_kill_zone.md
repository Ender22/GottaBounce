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
