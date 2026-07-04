# Spec: v1a — SUPER WHIFF SAFETY (the last self-ringout mode on islands_void)

> **Owner:** Lead Game Designer. **Status:** PRE-SPEC / options analysis — RECOMMENDS one lever.
> **Conditional on CD VERDICT #5.** If #5 rules FIX on the residual whiff self-ringout, build the
> RECOMMENDED option (§6). If #5 rules SHIP, keep this as the record of why (a) was defensible.
> **v1a — 2026-07-04.** Companion to `docs/specs/v1_level_circuit.md` §6 (the fence) and the
> `docs/briefs/cd_verdict4_2026-07-04_islands_audio.md` FIX list P1(1). Does NOT author level JSON
> and does NOT write GDScript — hands the gameplay-programmer a crisp build spec for the recommended
> lever and lets them own feasibility.

---

## 0. The measured problem (scope — read before proposing anything)

Two in-engine passes, after the two prior fixes landed:
1. **Geometry pass (islands_void v3):** islands widened 520–640px → uniform **960px**, gaps tightened
   680 → 580px (still > 527 spring drift = flight-required). This gave a landing pad + mid-island
   runway, so a **connected** smash-off now leaves the attacker safe (`smash_self_retain = 0.1` bleeds
   the attacker to 10% momentum on a landed hit → you stop, they fly). The connected-hit self-ringout
   is FIXED.
2. **Bot void-avoidance pass:** `killer = -1` (uncredited self-fall) share down ~64% → ~25%.

**The ONE remaining self-ringout mode: the WHIFFED super.** A fully-committed
`Tuning.super_boost_impulse_full = 2800` fired with **no connection** near a void rim arcs DOWN under
the next island and self-ringouts the attacker. Rate **~0.8–1.0 / stage** on islands_void. It is shared
by humans (a human whiffing a super near the rim rings out too), and it is the product of three things
multiplying:
- **Full impulse** (2800, near the `max_speed = 3000` cap) fired flat-ish near a rim.
- **Narrow-island ballistic geometry** — the super is a projectile: velocity 2800 + `gravity 1600`.
  Worked sag under gravity only (`sag = ½·g·(d/2800)²`):
  - over one 580px gap: t≈0.207s → **~34px** sag (nothing).
  - over one 960px island + gap (1540px): t≈0.55s → **~242px** sag.
  - at the smash-license horizon (`super_active_time = 0.45s` ≈ 1260px): **~162px** sag.
  Island tops differ by ~140–180px, so within ~1–1.5 islands of forward travel the flat super has
  already sagged **below the next island's top edge** and sails UNDER it into the gap/void beyond.
- **Fire-time aim jitter** — bots (`aim_error` 0.06–0.50 rad) and humans mis-aim slightly voidward at
  the moment of fire; near a rim, a few degrees down = a trajectory that never catches a surface.

**Why it doesn't self-correct:** the super **drains the tank to 0** (`_fire_super` sets `fuel = 0.0`;
drain-all is the closed identity). So a whiffing attacker sailing over the void has **no fuel to boost
back** and **no surface under them to bounce off + refuel** → they cross the bottom bound and ring out
**with no kill credit** (the death happens AFTER the 0.45s missile window, so it isn't even a
near-connect). This is the exact "my own kill move is a self-destruct button" failure CD #4 named.

## 1. The tension you must not break (the reason this is hard)

The super is ALSO the **cross-map TRAVERSAL tool** (v1_level_circuit §1 Rule C, GAME_ESSENCE verb 2):
- full forward carry is **INTENTIONAL** when flying across the widest gaps or reaching a distant throne;
- a **connected** hit already bleeds the attacker's momentum (`smash_self_retain = 0.1`) — that path is
  fixed and must stay fixed;
- a **whiff / pure-traversal** super keeps **full carry BY DESIGN** — you cannot globally shrink it
  without gutting traversal reach, the throne climb, and the cannon fantasy.

So the fix must **distinguish a whiff sailing toward open void / off-map (arrest)** from **a super
carrying you toward a real landing surface (keep every pixel of carry)** — and must not touch the
connected-kill launch at all.

**FENCE (v1_level_circuit §6, tuning skill DO-NOT-TOUCH):** `super_boost_impulse_full`, `max_speed`,
`smash_self_retain`, the hitstun triad, and "never re-introduce super power scaling" are closed
decisions. Any lever touching them = change-control gate + owner sign-off, not a quiet edit.

---

## 2. Player fantasy (what "good" feels like after the fix)

> "I fire my super. If I connect, I smash you off the screen and stick my landing. If I aim to fly
> across the map, I sail exactly where I pointed. If I whiff a smash near the edge, I come up short and
> **land hard on the nearest island, embarrassed but alive** — the way TowerFall lets a missed dash
> drop you onto the ledge, not off the map. If I flat-out yolo my super into open sky over a bottomless
> gap with nothing to catch me — I gambled, and I die. That's on me."

The fantasy is **committal-but-readable**. A whiff should cost you tempo and position, not silently
teleport you off the map by a mechanic (sub-island sag) the player cannot see or predict.

---

## 3. Options analysis (each: what · risk to grassy_expanse + feel · ownership · gate)

### (a) ACCEPT as fair committal risk — NO CHANGE
- **What:** rule the whiff self-ringout an intended committal cost. A super near the rim = you gambled
  your whole tank on a kill and missed; the void is the price.
- **For:** cheapest possible; touches nothing; preserves grassy_expanse and traversal byte-for-byte;
  committal weapons are on-genre (TowerFall arrows, Duck Game guns commit you). Now that it is the LONE
  remaining mode at only ~0.8–1.0/stage (down from prior dominance), "ship it" is more defensible than
  it was at verdict #4.
- **Against (why it is still weak):** the death is **unreadable and uncredited** — the sub-island sag
  is invisible, so it reads as *jank* ("I pressed my kill button and flew off the map by myself"),
  not as *drama* ("I gambled and missed"). CD #4 already ruled uncredited self-suicide the death mode
  that **dilutes the KILL fantasy**; a self-kill from your OWN kill move is the worst instance of it.
  And fire-time aim jitter means it is partly not-the-player's-fault. ~1/stage across a 10-kill match
  is a lot of "nothing happened, I just died."
- **Ownership:** game-designer + CD call. **No Tuning change. No gate.**
- **Verdict:** a REAL option (list it honestly), but it leaves the exact fantasy hole CD #4 opened.

### (b) Arena-relative super impulse (scale by island/arena size or a per-level factor)
- **What:** the owner-blessed *escalation* direction (DECISIONS #4: "escalate to an arena-relative
  super ONLY if geometry can't fix it"). Make `super_boost_impulse_full` scale per-arena.
- **Why it is DISFAVORED for THIS mode (mechanical, not just political):**
  1. **Geometry already did its job** — it fixed the *connected* overshoot the owner's escalation was
     aimed at. The residual is a *ballistic-sag whiff*, a different failure.
  2. **Scaling is ill-suited to a ballistic arc.** LOWER impulse = slower horizontal = *more* sag per
     unit distance = drops into the NEAR gap sooner (worse whiff, not better). HIGHER impulse = flatter
     = clears more islands but overshoots the far bound (the old connected failure). Neither direction
     cleanly removes the sag-into-void without hitting the other wall.
  3. It **reduces the very things we must preserve** — a smaller super on islands cuts traversal reach,
     the throne climb, AND the connected-kill launch magnitude. Explicitly out of bounds per the task
     constraints.
  4. It **fractures super consistency** across arenas (the super feels different per level = muscle-
     memory regression against the TowerFall-consistency bar), OR, if done as a global constant change,
     it **directly hits grassy_expanse** (CD-blessed as-is, verdict #3).
- **Ownership:** touches `super_boost_impulse_full` (**DNT**). Global constant → **change-control gate +
  owner sign-off**. Per-level factor → a new level-JSON field (level-data) **plus** code to read it,
  and still a fenced-constant semantics change → change-control.
- **Verdict:** keep it as the sanctioned last-resort the owner named, but it is both fenced and
  mechanically wrong for the sag-whiff. Do not reach for it before (c).

### (c) Whiff-vs-connect asymmetry — EDGE-AWARE WHIFF ARREST  ← **RECOMMENDED**
- **What:** a super that does NOT connect and whose ballistic path is **projected to exit a blast bound
  without first landing on a surface** auto-arrests its forward carry, converting the flat sail into a
  steeper drop that lands the attacker on the nearest island. A super whose path **DOES reach a landing
  surface** (traversal / throne climb) keeps **every pixel of carry**. A super fired into **open void
  with no surface under the arc at all** (pure yolo) is NOT saved — you still die (committal preserved).
- **Why it is the surgical fit:**
  - It targets the exact discriminator the tension demands: *surface-ahead-in-the-arc* = traversal
    (keep) vs *bound-cross-with-no-surface* = whiff (arrest).
  - It does **NOT touch** `super_boost_impulse_full`, `max_speed`, or `smash_self_retain` — the fenced
    cannon stays 2800; the connected-kill launch is untouched (see the missile-window guard, §6).
  - **Grassy_expanse is safe-to-positive:** a grassy super aimed across the central pit lands on the
    far floor → path intersects a platform → **no arrest** (its blessed feel is unchanged). The only
    grassy trajectory that would arrest is a super whiffed *off the side edge* — which was an uncredited
    self-ringout there too, so arrest is neutral-to-positive and never touches a *connecting* super
    (those resolve inside the missile window).
  - It fixes **both** humans and bots (the human whiff and the bot whiff are the same trajectory).
- **Risk:** adds a mechanic + a cheap per-frame ballistic look-ahead; must be robust so it never fires
  mid-flight on a super that is still a live missile (guarded by `_super_recent`), and never arrests a
  legitimate long-carry traversal (guarded by the surface-ahead test). Small feel risk that a player who
  *deliberately* yolos a super at a far island and comes up short now lands safe instead of dying — this
  is a BUFF to player forgiveness, judged acceptable (it removes a jank death, keeps the pure-open-void
  yolo lethal).
- **Ownership:** a **NEW mechanic** — game-designer specs (this doc), **gameplay-programmer builds and
  owns feasibility** of the ballistic look-ahead. Adds **NEW** Tuning constants (not a DNT change) via
  the tuning-skill add-a-constant runbook. **No change-control gate on the fenced super constant.**

### (d) Edge-aware aim-error clamp (reduce fire-time voidward jitter near a rim) — COMPLEMENTARY
- **What:** near a rim, bias/clamp the fire-time aim so a whiff sags onto the island, not the void.
- **For humans:** REJECTED as a primary fix — clamping a human's aim takes control away from the player
  (feel violation; a human is allowed to aim into the void). Does not fix the human whiff.
- **For bots:** a legitimate cheap adjunct — a `BotProfile` pass so bots near a rim bias aim slightly
  inward/upward before firing (their `aim_error` is the jitter source). This is pure bot-AI polish.
- **Ownership:** game-designer, `src/core/BotProfile.gd` / `InputBot.gd` dials — **code, no
  DNT-constant touch, no gate.** Insufficient alone (bots only, partial); recommend as an OPTIONAL
  stack on top of (c), not instead of it.

---

## 4. RECOMMENDATION

**Build (c) — edge-aware whiff arrest.** Optionally stack (d) as cheap bot polish afterward.

It is the only lever that fixes BOTH humans and bots, preserves traversal reach, the throne climb, the
connected-kill launch, and the recovery gamble, leaves the fenced `super_boost_impulse_full = 2800`
untouched (so grassy_expanse stays byte-for-byte on the constant), and directly targets the measured
post-window sag-into-void. It matches the owner's intent (fix the flagship without gutting the super)
better than (b) — which the owner themselves gated as last-resort and which is mechanically ill-suited
to a ballistic-sag failure.

---

## 5. Tuning targets (numbers + rationale) for the recommended lever

New constants (game-designer-owned; add per the tuning skill add-a-constant runbook; NONE are on the
DNT list). Starting values are hypotheses to live-tune (`gbplay eval`), not gospel:

| New constant | Start | Unit | Rationale |
|---|---|---|---|
| `super_whiff_lookahead` | 1.0 | s | Ballistic look-ahead horizon. Must cover the fall to the bottom bound from a whiff apex (~700px recovery sky ÷ ~gravity fall ≈ 0.9s). Cap ~1.2s so it stays cheap. |
| `super_whiff_arrest_drain` | 3200 | px/s² | Horizontal-carry bleed rate once a whiff is detected. Sized so a ~2500px/s forward carry collapses toward a near-vertical drop in ~0.5–0.8s — long enough to read as "coming up short," short enough to catch the near island before the far bound. Live-tune against the land-on-island criterion. |
| `super_whiff_land_tolerance` | 90 | px | Vertical slop for "the arc lands on this platform top" in the look-ahead sampler (≈ 0.8·H). Prevents fl\-arc grazes from counting/failing on a single-pixel edge. |

**Rationale anchor (FEEL):** the super is a projectile under `gravity 1600`; the whole failure is the
`sag = ½·g·t²` term (§0). The arrest works ON that term (bleed horizontal → shorten t-to-ground → land
sooner) rather than on the impulse magnitude, which is why it needs NO change to the 2800 constant.
The missile window is `super_active_time = 0.45s`; the arrest is GATED to only act AFTER it (§6), so a
connecting/near-connecting super is never shortened. The `fuel = 0` gate (§6) is exact: only a
drain-all super leaves you at 0 fuel airborne, so the arrest fires precisely in the "spent my tank,
can't recover" situation and never on a fuelled boosted arc, a Ring-of-Fire launch, or Unlimited Boost.

---

## 6. Build spec for the gameplay-programmer (design intent + acceptance tests; you own the mechanism)

**State/hooks already present** (`src/entities/Player.gd`): `_super_recent` (missile window countdown,
set to `super_active_time` in `_fire_super` at line 461), `fuel`, `velocity`, gravity `g`,
`is_super_active()`. Platform geometry + `bounds` live at the arena/`PartyMatch` level
(`_classify_blast_edge` at `PartyMatch.gd:514` already reads `bounds` and `_stage_rect`) — the player
will need read access to the platform tops + bounds (a lightweight arena query, programmer's call on
the seam).

**Trigger predicate (ALL true, evaluated per physics frame while airborne):**
1. `fuel <= 0.0` — this is the drain-all super's fingerprint; excludes fuelled boosted arcs, Ring-of-
   Fire launches (line 864, fuel not drained), and Unlimited Boost (fuel_locked). *(Edge case: if
   Ring-of-Fire self-ringouts ever show up in data, revisit widening the gate — not in scope now.)*
2. `_super_recent <= 0.0` — the 0.45s smash-license missile window is OVER. A super that is still a
   live missile is NEVER touched, so the connected/near-connected kill is fully preserved.
3. `is_super_active() == false` (redundant with 2, assert both).
4. No smash landed this super (a landed smash already bled you to `smash_self_retain`; if you connected
   you are not whiffing).

**Whiff test (the discriminator — programmer owns the exact sampler):** project the current *ballistic*
path (velocity + gravity, NO input) forward `super_whiff_lookahead` seconds, sampling ~every 0.05s:
- If any sample lands on / passes within `super_whiff_land_tolerance` above a platform top **before**
  crossing any bound → **LANDS** (traversal / throne / near-island). **Do nothing** — full carry kept.
- Else if a sample crosses a blast bound → **WHIFF-RINGOUT**. Engage arrest.
- (Because ballistic paths under gravity only descend, "surface reached first" is a clean, order-correct
  discriminator — a far surface at/above fire height is only reached if it's actually in range; an
  under-aimed short super never reaches it and correctly reads as a whiff.)

**Arrest control law (intent; programmer picks the exact curve):** bleed the horizontal component of
`velocity` toward 0 at `super_whiff_arrest_drain` px/s² so the flat sail becomes a steeper drop that
lands the attacker on the nearest island beneath/ahead of the current arc. Do NOT touch the vertical
component beyond letting gravity work (no upward save — the player still *drops*, they just don't *sail
off*). If the arc passes over NO platform at all within the look-ahead (pure open-void yolo), the arrest
still bleeds horizontal but there is nothing to catch them → they die (committal preserved; this is
correct and intended). Re-evaluate the predicate each frame; release the arrest the instant a sample
shows a surface will be reached (so a mid-arrest bounce that re-opens options isn't over-braked).

**Edge cases to handle:**
- **Powerup speed_mult:** the fire multiplies by `speed_mult`; the look-ahead uses live `velocity`, so
  it is automatically correct.
- **Slow-Mo active:** the look-ahead must use REAL velocity (`pre_v`), matching the existing bounce-math
  handling at `Player.gd:440-444`.
- **Bumper in the arc:** if the projected path would hit a bumper (reflector) before a bound, treat as
  "may recover" — do NOT arrest (the ricochet + `fuel_per_bumper` refund is a legit save; this is the
  §2.3a wall-return fantasy). Programmer may treat bumpers as surfaces-that-cancel-the-whiff.
- **Wings / flap powerup active:** `wings_flaps > 0` means the player CAN recover airborne → skip the
  arrest (they have a recovery tool despite 0 fuel).

**Do NOT:** touch `super_boost_impulse_full`, `max_speed`, `smash_self_retain`, the hitstun triad, or
reintroduce fuel/hold power scaling. Do NOT arrest inside the missile window. Do NOT apply any upward
force (no floaty save — this is a *shorten the sail*, not a *cancel the fall*).

---

## 7. Measurable success criteria (QA verifies by driving islands_void + grassy_expanse)

Baseline first: capture the pre-change islands_void whiff self-ringout rate and credited-kill rate over
>= 12 four-bot idle-P1 stages so the deltas below are measured, not asserted.

- **WS1 — whiff self-ringout DOWN (the target):** over >= 12 four-bot stages on islands_void, uncredited
  self-ringouts attributable to a whiffed super drop from ~0.8–1.0/stage to **<= 0.25/stage** (a >= 70%
  reduction, matching the bot void-avoidance precedent). Overall `killer = -1` share continues its
  downward trend.
- **WS2 — connected-kill rate NOT reduced:** credited smash-off kills/stage stays **>= 95%** of the
  measured pre-change baseline (the arrest never fires inside the missile window, so this must hold; a
  drop signals the guard is mis-firing).
- **WS3 — traversal reach preserved:** a horizontal super fired from island A toward the far side still
  carries the attacker the SAME distance (lands on the same target island C/D) as pre-change in a
  no-arrest case (path reaches a surface). A deliberate cross-map traversal super reaches its target
  island **unchanged**.
- **WS4 — throne climb preserved:** a super fired up-right from island A toward spring throne F still
  reaches F **>= 9/10** (F is a surface in the arc → no arrest). Same for B → throne E.
- **WS5 — whiff lands on an island (the fix working):** a super fired ~horizontally from island B's rim
  toward C that does NOT connect lands the attacker on SOME island (A/B/C/D) **>= 8/10** instead of
  sailing into the void.
- **WS6 — committal preserved (pure yolo still dies):** a super fired into OPEN void where NO island lies
  under the ballistic arc still rings the attacker out **>= 9/10** (you don't get a free save for firing
  at nothing).
- **WS7 — recovery gamble intact:** the islands_void S5/K4 mid-stage healthy full-fuel fly-back
  criterion still passes at its current bar (arrest is fuel==0-only, so a knocked *fuelled* player is
  never touched).
- **WS8 — grassy_expanse NOT regressed:** re-run grassy's CD-verdict-#3 blessed metrics; a super aimed
  across the central pit toward the far floor is NOT arrested (path reaches a platform) — confirm no
  change to grassy's kill rate or pacing within noise. If any grassy metric regresses, the surface-ahead
  predicate is wrong — fix the predicate, do NOT weaken the arrest for islands.
- **WS9 — no new stall / feel wart:** match-to-`match_target_score` median stays <= its current value
  (the arrest must not make supers feel mushy or add a hang; a whiff should read as a hard drop, not a
  float). Spot-check burst screenshots: an arrested whiff visibly drops onto an island, no mid-air
  hover.

---

## 8. Ownership + gate summary (one table for the Director)

| Option | Owner / skill | Tuning change? | Gate |
|---|---|---|---|
| (a) accept | game-designer + CD | none | none (a ruling) |
| (b) arena-relative impulse | game-designer + owner | **`super_boost_impulse_full` (DNT)** or new per-level field | **change-control + owner sign-off** |
| **(c) whiff arrest (REC)** | game-designer spec + **gameplay-programmer** build | **NEW** consts only (§5) — not DNT | add-a-constant runbook; no fenced-constant gate |
| (d) bot aim clamp | game-designer | none (BotProfile dials) | none |

**Fence reaffirmed:** the recommended fix adds a mechanic + new constants and touches NO fenced feel
constant. `super_boost_impulse_full = 2800`, `max_speed`, `smash_self_retain`, and the hitstun triad
stay exactly as blessed. The super is still full-power, drain-all, un-charged, and full-carry on every
traversal and every connect — it just no longer sails you off the map when you whiff near a rim.
