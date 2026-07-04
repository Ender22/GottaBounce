# Spec: v2 KILL SHAPE — make the EDGES the blast zone, demote the central pit

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD. **v2 — 2026-07-04.**
>
> **This is a cross-cutting AMENDMENT** (studio convention: amend by new file — v1_kill_economy is
> itself one) driven by the creative-director's second fantasy-fit pass
> (`docs/briefs/cd_verdict2_2026-07-04_killshape.md`, verdict FIX). It AMENDS:
> - `docs/specs/v0_kill_zone_recovery.md` **§13** (edge-relative band — corrects WHY it never fired),
>   **§14** (level-relative bounds — corrects the `bounds_side_frac` root cause), and the **D6/D8**
>   criteria; and
> - `docs/specs/v1_kill_economy_at_scale.md` **§5** (S2/S5/S6 recalibration) and adds the kill-SHAPE
>   composition criterion the prior specs never asserted.
>
> **The fence is UNCHANGED and reaffirmed:** no round timer / laser SD; no HP bar / meter; no standable
> ground; no change to the hitstun triad, drain-all super, `max_speed` (3000),
> `super_boost_impulse_full` (2800), `smash_impulse_max` (2200), hit-solidity, `dmg_launch_mult`, or the
> §2.3a dry-reflect RULE; no power scaling; no movement-feel constants (`tangential_retention`,
> `air_drift_*`). **Every fix here is GEOMETRY (runway/pit/bumpers), one heal-window value, and credit
> attribution — never lethality launch physics, never movement feel.** The mid-stage recovery gamble
> (S5 ≥ 8/10) is a HARD invariant: it must survive this change.
>
> **Director constraint (2026-07-04):** the walkable arena footprint stays at the owner's ~3760px
> (grassy_expanse). Camera readability at 3760 is solved separately (`docs/briefs/camera_2x_policy.md`:
> action-cluster framing + 0.60 zoom floor + off-screen edge indicators — the latter directly serves
> the edge-blast read). **This spec does NOT shrink the walkable width.** The side blast lines it moves
> live in the RUNWAY, OUTSIDE the walkable extent; the pit narrowing is interior. Footprint unchanged.

---

## The finding (creative-director, measured)

`off_stage_kills = 0`; ~100% of 176 out-of-bounds deaths are at the BOTTOM/central pit; ZERO side or
top blast kills. The founding fantasy — "smash rivals OFF THE SCREEN" (GAME_ESSENCE) — is inert; a
platformer death-pit does all the killing. 28% of deaths are uncredited self-falls (dead air in a
kill-race). Root causes: the ±960px side runway is WIDER than the lethal band, the side bumper posts
reflect launches back in, the super never spikes a near-edge player out, and so the central pit became
the path of least resistance and the dominant killer.

## The reconciliation (both are owner intents — resolve via a GRADIENT, not a uniform runway)

- (a) **WIDE runway = a MID-STAGE knock is survivable, you fly back** — the recovery gamble.
- (b) **EDGE-relative kills = a dead-on hit NEAR the edge sends you OFF the screen** — the fantasy.

These are not in conflict once you see the gradient is over **POSITION**, not over a single runway
number. A wide FLOOR keeps mid-stage players far from the blast (survivable). A runway sized to the
**lethal band** keeps the walkable OUTER edge inside blast range (near-edge = dead). The bug was that
960px pushed the lethal boundary OUTSIDE the walkable area entirely, so NO position on the level was
ever lethal at the side. Fix: pull the side blast line back INTO band range and stop reflecting the
launch — the edges then do most of the killing, the pit becomes a minority traversal hazard.

---

## Ruling 1 — MAKE THE EDGES THE PRIMARY BLAST ZONE (geometry, fence-safe, no launch-physics change)

### 1a — WHY the edge-relative band (v0kzr §13) never fired — the root cause

The near-edge band is **fixed by launch physics**: `band ≈ exit_speed × hitstun_max − fuelled_recovery`.
For Lv0 healthy full-fuel that is **~700–900px** (v0kzr §13 table). But the runway on grassy is **960px**,
and — worse — v0kzr §14 derives the runway as `bounds_side_frac (0.52) × walkable_width`, which SCALES
UP with level width while the band stays FIXED. So on any wide level the runway outgrows the band and
**the walkable edge sits OUTSIDE the lethal band — no player standing on the level is ever inside it.**
The band table's own numbers prove it: on grassy the walkable edge (x0) is 960px from the blast, past
even the Lv0-starved (~1100 would reach) and inside NOTHING for a fuelled healthy player. The physics
were correct; the geometry put every player out of blast range. Then the **bumper posts** reflected
whatever launch did head outward, back in.

**This is NOT fixed by a new near-edge amplifier or an "if near edge, kill" special case** (v0kzr §13
forbids that — edge-relative lethality must stay emergent). It is fixed by moving the blast line into
band range and removing the reflector.

### 1b — Shrink the side runway to band size and STOP scaling it with width (v0kzr §14 correction)

The runway must be sized to the **launch band**, not to level width. Correct the derivation constants:

| Tuning constant | old (v0kzr §14) | **new (this spec)** | rationale |
|---|---|---|---|
| `bounds_side_frac` | 0.52 | **0.15** | small width component only — the runway must track the FIXED band, not blow out on wide levels. |
| `bounds_side_min` | 700.0 | **480.0** | floor; the tightest runway a small arena gets (still ≥ a survivable mid-stage arc). |
| `bounds_side_max` | 1400.0 | **720.0** | cap; the runway never exceeds the top of the Lv0 band (~900) minus margin, so the walkable edge is ALWAYS inside blast range on every circuit level. |

- **Grassy (walkable width 3760):** `clamp(0.15 × 3760, 480, 720) = 564` → side runway **≈ 560px**.
  Left blast `0 − 560 = −560`; right blast `3760 + 560 = 4320`. (Was −960 / 4720.)
- **Dev_arena (width 1792):** `clamp(0.15×1792, 480, 720) = 480` (floor). Was ~932 — dev inherits the
  same fix (its edge never killed either); re-validate dev with the new runway.
- **A very wide level (5000):** clamps to 720 — still inside band range. The edge blast fires on EVERY
  circuit level, which the 0.52-frac derivation structurally prevented.

This honours the owner's §4 "scale runway with width" *intent* (a width term remains) while fixing the
physics: the band is fixed, so the runway is bounded to it.

**Verification on grassy (560px runway, left floor x0–1400+; blast x−560):**
- **Near-edge (x0), healthy full fuel, dead-on outward (2200):** hitstun-travel ≈ 2200 × 0.55 ≈ 1210px
  → reaches ≈ x−1210, past the x−560 blast → **rings out ≥ 8/10.** The super now spikes a near-edge
  player off-screen — purely from the geometry; no launch change. (Point 1's "super doesn't spike"
  is solved here.)
- **Mid-stage (floor center x≈700–800), healthy full fuel, same hit toward the wall:** ≈ 1300–1360px
  from the blast > the ~900 band → **arcs back, survives ≥ 8/10 (S5 held, recovery gamble intact).**
- **Mid-stage, Lv1 damaged (×1.33 → ~2926 → ~1600px travel):** from x800 reaches ≈ x−800, past the
  x−560 blast → **rings out.** "Hit a damaged rival → they fly further → off screen" now fires from
  mid-stage — this is the engine of the edge-kill majority (v0kzr D6c).

The gradient is now real: knocked from mid-stage while healthy = survivable comeback; knocked while
near the edge, OR while damaged, OR while starved = gone off the side.

### 1c — the SIDE BUMPER POSTS: remove them from the blast edge (they negate the fix)

The grassy posts `{x:0,w:56}` and `{x:3704,w:56}` sit at the extreme walkable edges (x0 / x3760) and
span the floor-combat band (y620–1000). They **reflect a side-directed launch back IN before it reaches
the runway** — the single biggest reason `off_stage_kills = 0`. A reflective surface AT the blast edge
is antithetical to the side being a blast zone.

**RULE (game-designer):** **no reflective surface (bumper) within the near-edge band (~560px, = the
runway) of any side blast line.** The blast edge must be OPEN air so a launch exits.

**Geometry (level-designer's call, within the rule):** REMOVE the two edge bumper posts. If the
bumper-rebound fantasy (`miss → wall-rebound → return-shot`, §2.3a, fuel refund) is wanted, RELOCATE
bumpers to INTERIOR positions (e.g. flanking the pit) where they add mid-stage rebound play without
guarding the blast line. The §2.3a dry-reflect RULE is untouched — only the POSITION of the posts
changes; any interior bumper still reflects dry, hitstun-by-time. This does not reopen the fence.

### 1d — TOP blast stays rare (do NOT loosen the top margin)

`bounds_top_margin = 2650` (v1 §1) deliberately makes upward self-supers arc back (it killed the
uncredited self-destruct). Leave it. Top ring-outs stay rare-but-real (a Lv2-capped vertical smash near
the throne). **SIDE is the primary blast; TOP is a bonus.** The composition criterion (§5) is
dominated by the sides — do not chase top kills by reopening §1's margin.

---

## Ruling 2 — DEMOTE THE CENTRAL PIT to a minority traversal hazard

The pit must remain a **flight-required traversal feature** (GAME_ESSENCE verb 2 — falling in with
zero boost stays certain; the CD confirmed this works) but stop being the DOMINANT killer.

**Kill-economy intent (game-designer):** central-pit (bottom) deaths ≤ **30%** of credited kills; the
side/top blast is the majority (§5, S-shape). The pit is where a whiffed boost-hop or a knock-in ends
you — not the default death.

**Geometry (handed to level-designer — you own the exact layout):**
1. **Narrow the pit** from 960px to **~560px** (e.g. left floor x0→1600, right floor x2160→3760, gap
   x1600–2160). This keeps flight REQUIRED (560 > the ~395px zero-boost trampoline drift, so you must
   boost) while making the pit a hop-able hazard, not a giant maw. It also WIDENS the floors, giving a
   genuine mid-stage safe zone (≥ band from the side walls) that S5 needs, and pushes more combat to
   the floor edges where side kills happen.
2. **Make the pit READABLE as a lethal void** (the CD's biggest FELT problem — it reads as safe green,
   like a bug). Visible chasm / darkness / depth cue — art-director + level-designer. Not my remit; the
   kill-economy rule is only "the pit must LOOK deadly so a fall reads as a designed death, not a bug."
3. **Re-run the movement-tool-per-gap flight-required analysis** at the new 560px width (GAME_ESSENCE
   per-role obligation).
4. Bottom bound is unchanged (walkable bottom y1128 + `bounds_bottom_margin` 670 = 1798).

---

## Ruling 3 — PIT-FALL / RING-OUT CREDIT ATTRIBUTION (shrink the 28% uncredited)

28% of deaths are uncredited self-falls. Two causes: (a) a knock-in whose failed-recovery arc into the
pit takes longer than the 4.0s `kill_credit_window`, so the launcher's credit expires → mis-logged as
a self-fall; (b) genuine no-attacker whiffed-hop falls.

**Ruling (game-designer value; gameplay-programmer implements):**
- **Ring-out deaths get an EXTENDED credit window of `kill_credit_window_ringout = 6.0s`** (vs the 4.0s
  standard for other deaths). Rationale: a failed-recovery arc toward a pit/side blast can take 3–5s
  (the launch + doomed boost attempts); 4.0s expires mid-arc. 6.0 captures the full arc. This is
  exactly the `kill_credit_window_max = 6.0` already sanctioned in v0kzr §10/RULING 3 — applied to
  ring-outs by cause. Last-touch (any qualifying hit) within 6.0s of a ring-out → credited to that
  attacker.
- **Reconcile v0kzr §1b (frozen re-scoring): OVERRIDE it for the credited case, KEEP it for the
  genuine self-fall.** A ring-out WITHIN 6.0s of a qualifying hit is a CREDITED kill (not a −1
  self-penalty). A ring-out with NO qualifying hit in the 6.0s window remains an uncredited self-fall
  = −1 to your own total, floored at 0 (the anti-grief / comedy rule §1b, correct for a genuine whiff).
  So §1b is not reopened — it is scoped to the true no-attacker case.
- **The dominant lever for the ≤10% target is Rulings 1+2, not the window.** Once EDGES are the
  majority of kills (all attacker-driven, credited) and the pit is a ≤30% minority with ~2/3 of its
  deaths being credited knock-ins, the uncredited SHARE of TOTAL deaths falls to ≤10% arithmetically.
  The 6.0s window is what converts the failed-recovery arcs from "self-fall" to "credited."

---

## Ruling 4 — S6 FLEE-TO-HEAL: reconcile the 8s window vs sub-8s stages, recalibrate the bar

The 8s heal window vs ~2–7s 1v1 stages means flee-to-heal completes ~2% (target was ≥25%). It is
structurally near-impossible at 1-life 1v1 pace; it lives in the 3–4-player MELEE (stages ~22s combat,
S1) where a damaged player who is not the current focus can slip away and heal.

**Rulings (game-designer values):**
1. **Shorten `dmg_heal_time` 8.0 → 6.0s.** A 6s window fits inside a median-to-long melee stage while
   still giving the chaser a real 6s to land the follow-up (the escalation is not gutted — chase is the
   healthy half; this rebalances toward the broken flee half). **FLAGGED for owner visibility:** 8s was
   an explicit owner number; 6s is the sanctioned reconciliation (the brief lists "shorter heal window"
   as a lever). If QA shows the melee-only recalibration alone reaches the recalibrated bar, 8s may be
   kept — but ship 6.0 first.
2. **REJECT a flee speed-edge.** It would touch movement feel (the frozen product core). Rely on the
   window + the §2c RETREAT behavior + the recalibrated bar instead.
3. **Recalibrate the S6 bar to what is structurally reachable.** ≥ 25% → **≥ 15% of Lv1-damage events
   heal to Lv0 without dying, measured aggregate — with the understanding that ~all of these occur in
   the 3–4-player phase and ~0 in 1v1 (accepted).** PLUS the behavioral gate: a wounded bot is observed
   FLYING to a distant platform and holding to heal (§2c RETREAT, screenshot/eval). 15% proves the
   dynamic is alive without pretending 1v1 flee-to-heal is achievable.

---

## §5 — Success criteria (measured on grassy, then the circuit) — the kill SHAPE is the headline

Harness: `python tools/gbplay.py` eval + burst screenshots, ≥ 24 4-bot idle-P1 stages on grassy;
re-run on the ~10-level circuit. Requires the new `kills[].blast_edge` field (§6). These ADD to /
recalibrate v1 §5 and v0kzr §15.

**The kill SHAPE (the headline — new)**
- **K1 — edges do most of the killing.** Of credited kills, **≥ 60%** are SIDE or TOP blast (victim
  crossed a side or top bound; `kills[].blast_edge ∈ {left,right,top}`), with SIDE the dominant
  sub-share. Central-pit (bottom) deaths **≤ 30%** of kills. (CD baseline: 0% edge / ~100% pit.)
- **K2 — near-edge dead-on kills.** A healthy full-fuel victim placed at the outer walkable edge
  (grassy: x0±50 / x3760∓50, i.e. inside the 560px runway band), hit dead-on OUTWARD → exits the side
  bound ≤ 2.5s **≥ 8/10.**
- **K3 — uncredited share low.** Uncredited self-ring-outs (no qualifying hit within 6.0s of the
  ring-out) **≤ 10%** of all deaths; upward self-super deaths **≤ 5%** (v1 S2 held).

**Fantasy-fit invariants (must HOLD with the fix)**
- **K4 — mid-stage healthy survives a single hit (S5, HARD invariant).** A healthy full-fuel player at
  a floor center (≥ the band from the nearest SIDE wall), struck by ONE qualifying hit directed toward
  that side wall → arcs back in bounds, not eliminated, **≥ 8/10.** < 8/10 = back off the runway (720
  first, then wider) — NEVER touch lethality.
- **K5 — damaged-mid-stage rings out (edge economy engine, v0kzr D6c).** A Lv1 full-fuel victim at a
  floor center, hit outward, no counter → rings out **≥ 5/10** (vs K4's ≤ 2/10 for Lv0). Proves "hit a
  damaged rival → off screen" fires from mid-stage.
- **K6 — fuelled fly-back preserved (gamble, v0kzr D6e).** A near-edge full-fuel victim WITH a scripted
  snap counter-super inward within 0.3s of stun-end survives **≥ 4/10** (fuelled recovery is still
  real even near the edge).

**Pacing & flee (recalibrated)**
- **K7 — match resolves.** 4-bot idle-P1 match to `match_target_kills = 10` ≤ **6 min** median; > 8 min
  = HARD FAIL (v1 S4). First-elim median ≤ 12s (v1 S1) — if the tighter runway makes stages TOO fast
  (first-elim median < ~5s or K4 fails), widen the runway (720 → …) FIRST, never lethality.
- **K8 — flee-to-heal reaches the recalibrated bar.** ≥ **15%** of Lv1-damage events heal to Lv0
  without dying (aggregate), + a wounded bot OBSERVED flying to safe ground to heal (§2c). Flee must
  not become permanent evasion (v1 §2c caps + K7 closeout are the paired guard).

**Flight-required traversal (unchanged intent, re-verified at the narrower pit)**
- **K9 — horizontal flight required.** Zero-boost (fuel pinned) direction-hold from one floor does NOT
  reach the far floor across the ~560px pit (≥ 9/10 falls in). A crossing logs ≥ 1 boost activation.

---

## §6 — Ownership split & build order

**Game-designer-owned (rulings + values, this spec):**
- Runway derivation correction: `bounds_side_frac 0.15`, `bounds_side_min 480`, `bounds_side_max 720`;
  grassy side runway 560 (§1b).
- The "no reflector within the near-edge band" RULE (§1c); top margin left untouched (§1d).
- Kill-economy intent: edges ≥ 60%, pit ≤ 30% (§2); pit ~560px width target (flight-required) as
  intent handed to level-designer.
- `kill_credit_window_ringout = 6.0` + the §1b reconciliation (credit-if-within-window, else −1
  self-floor) (§3).
- `dmg_heal_time 8 → 6` (flagged); S6 recalibration to ≥ 15% + behavioral gate (§4).
- All success criteria K1–K9 (§5).

**Handed to LEVEL-DESIGNER (geometry — walkable footprint stays 3760):**
- REMOVE / relocate the two edge bumper posts (`{x:0,w:56}`, `{x:3704,w:56}`); no bumper within 560px
  of a side blast; relocate to interior if bumper play is wanted.
- NARROW the central pit 960 → ~560px (widen the floors inward), keeping flight required; make it read
  as a lethal void (with art-director); re-run the per-gap flight-required analysis.
- Grassy `bounds`: DROP the explicit side override and let derivation run (gives left ≈ −564 / right ≈
  4324), OR set `left:-560, right:4320` explicitly. Keep `top:-2510`, `bottom:1798`.

**Handed to GAMEPLAY-PROGRAMMER (attribution + implementation):**
- Apply the three derivation constants + `kill_credit_window_ringout` + `dmg_heal_time`.
- **Ring-out-specific credit window** (last-touch within 6.0s) + the §1b reconciliation logic in the
  ring-out path (`PartyMatch._deferred`/`Player.kill`/`KillPipeline`).
- **NEW instrumentation `kills[].blast_edge ∈ {left,right,top,bottom,none}`** — which bound the victim
  crossed at death (needed to MEASURE K1). Derive from the victim's last-frame position vs `bounds`.

**Handed to ART-DIRECTOR (flag, not this spec):** pit void readability (§2.2); off-screen edge
indicators for side blasts (camera_2x_policy) — the edge kill must READ even as the victim leaves frame.

**Recommended build order (depth-first; each gates the next measurement):**
1. **§1b runway constants + grassy side bounds + §1c remove edge bumpers.** This alone makes the side
   blast physically reachable — measure K1/K2 immediately (expect edges to start firing).
2. **§2 pit narrow + readability** (level-designer). Demotes the pit; widens floors for K4's safe zone.
3. **§6 `blast_edge` instrumentation + §3 ring-out credit window.** Enables K1/K3 measurement + fixes
   uncredited.
4. **§4 `dmg_heal_time 6` + S6 recalibration.**
5. **Full re-QA on grassy (K1–K9), then re-run on the ~10-level circuit** (the real validation surface).

**Fence reaffirmed:** every fix is geometry, one heal-window value, and credit attribution. NO change
to any launch-physics lethality constant (`smash_*`, `dmg_launch_mult`, `hitstun_*`, `max_speed`,
`super_boost_impulse_full`), NO movement-feel constant, NO round timer, NO HP bar, NO standable ground,
NO near-edge amplifier special-case (edge lethality stays emergent, v0kzr §13). The walkable arena
footprint stays ~3760px (Director constraint).
