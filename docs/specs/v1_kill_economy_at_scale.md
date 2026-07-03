# Spec: v1 Kill Economy AT SCALE — making the core verbs fire on the 2x arena (grassy_expanse)

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD. **v1 — 2026-07-03.**
>
> **This is a cross-cutting AMENDMENT** to two shipped specs, driven by the creative-director's first
> fantasy-fit pass (`docs/briefs/cd_verdict_2026-07-03_flagship.md`, verdict FIX). It AMENDS:
> - `docs/specs/v0_kill_zone_recovery.md` **§14** (level-relative bounds — the top margin) and **§15**
>   (self-super void-kill criterion D7), and
> - `docs/specs/v1_party_killrace.md` **§5.5** (finisher closeout) and **§5.6** (chase-the-wounded),
>   and adds the FLEE half of the owner's chase/flee dynamic
>   (`docs/feedback/owner_2026-07-03_lives_damage_killrace.md` addendum).
>
> **Root cause (Director note, CD verdict):** combat + bounds were tuned and validated on the
> ~1792px-walkable dev_arena and **do not SCALE** to the ~3760px-walkable flagship (grassy_expanse,
> owner_2026-07-03_arena_size). Four failures share this one root; this spec fixes the kill-economy
> subset (§1–§4). Camera-at-scale and audio are separate owners (CD §4 / audio brief).
>
> **Authority sources:** `docs/GAME_ESSENCE.md` (the fantasy — the core verbs must be EXERCISED, not
> merely present), `docs/feedback/owner_2026-07-03_arena_size.md` (2x arena, ~10-level circuit),
> `docs/feedback/owner_2026-07-03_lives_damage_killrace.md` (edge-relative kills + damage + flee-to-heal).
>
> **The fence is UNCHANGED** (v0kzr §7): no round timer / laser SD, no HP bar, no standable ground, no
> hitstun/power-scaling changes, and — added here — **no touching the movement-feel constants
> (`tangential_retention`, `air_drift_*`, `max_speed`, `super_boost_impulse_full`)**: movement feel IS
> the product. Every fix below is GEOMETRY or BOT BEHAVIOR — never lethality, never movement feel.

---

## The problem (creative-director, measured on grassy_expanse, 4-bot)

Kills barely land; a stage ran 60+s unresolved. The deaths that DID happen were **uncredited
self-destructs** — bodies fired supers upward, flew off the top bound (−1560), died, scores stayed
`[0,0,0,0]`. The 2 finalists parked ~2400px apart and never engaged (the dev-arena finisher's 4.9s
closeout does not scale to a 3760px arena). No super-smash kill / edge kill / damage escalation was
observable in real play. **The core verb — super-smash as THE kill — is not being exercised.**

Four rulings (§1–§4) + scale-aware success criteria (§5).

---

## §1 — Vertical bounds at scale: kill the uncredited upward self-destruct

### Diagnosis (the margin math)

A self-fired super is `super_boost_impulse_full = 2800`. Straight-up rise before apex =
`2800² / (2 · gravity=1600)` = **2450px**. The derived top bound is `walkable.top − bounds_top_margin`,
and `bounds_top_margin = 1700` (Tuning). On grassy the highest platform is the spring THRONE at y140,
so `walkable.top = 140` and `top = −1560`. The headroom above the throne is only **1700px < the 2450px
self-super rise** → a super fired straight up from ANY platform at (or near) the walkable top clears
the ceiling and self-destructs:

| Launch platform | y | self-super apex (y − 2450) | vs top −1560 |
|---|---|---|---|
| Floor (trampoline) | 1000 | −1450 | arcs back (short by 110px) |
| Shoulder (bubblegum) | 430 | −2020 | **off the top → suicide** |
| Throne (spring) | 140 | −2310 | **off the top → suicide** |

On the SMALL dev_arena the top (−1150) was only ~1690px above its floor (y980) and the self-destruct
was a rare INTENTIONAL committed mistake (you had to aim straight up from the floor with no reason). At
2x scale, with elevated combat pads, a *routine* upward super — a recovery, an offensive shot at a
higher opponent — auto-suicides. That is the uncredited death ending stages at `[0,0,0,0]`.

### RULING 1a — the top margin must EXCEED the self-super rise (scale-safe, whole circuit)

`bounds_top_margin` is a single global constant applied to EVERY circuit level via derivation. Set it so
a straight-up self-super from the HIGHEST platform arcs back with clearance, on any level:

```
bounds_top_margin : 1700  ->  2650     # = self_super_rise (2450) + 200px clearance
```

- **Grassy derived/override top** = `throne y140 − 2650 = −2510`. Set grassy's explicit `bounds.top`
  to **−2510** (grassy carries an explicit `bounds` block; update it to match).
  - Verify: self-super up from throne → apex −2310, clears −2510 by **200px** ✓; from shoulder →
    −2020, clears by 490px ✓; from floor → −1450, clears by 1060px ✓. **No routine upward super
    self-destructs off the top, from any platform.**
  - A Lv2 (capped `max_speed` 3000) *credited* smash straight up: rise = 3000²/3200 = 2812px. From the
    throne → apex −2672 < −2510 → rings out (a rare, CREDITED top kill — correct, kept). From the floor
    → apex −1812 → arcs back. So top ring-outs become rare and mostly credited — exactly the intended
    edge economy (most kills are side/near-edge or damaged, v0kzr §13/D8).

- **Path 1 (the intentional self-super into the void) is PRESERVED via the SIDES, not the top.** The
  side runway is 960px (grassy) < the self-super horizontal reach (~2450px at 2800 impulse), so firing
  your own super at a near wall with a drained tank (drain-all super) still self-destructs — the comedy
  commitment gag survives. It simply moves from "straight up" (which was the bug) to "into a wall with
  no runway" (the honest committed mistake). This is the CORRECT scaling: on a tall arena, up is not a
  void; the sides are.

### RULING 1b — should an upward-super death score −1 (suicide) or 0 (neutral)?

**KEEP the existing rule: a self-ring-out with no credited attacker = −1 to your own kill total,
floored at 0** (`PartyMatch._on_killed`, already implemented). This is correct anti-grief (discourages
ledge-diving to deny a kill) and the L2 comedy punchline. The CD saw `[0,0,0,0]` only because the
scores were already at the 0 floor (neutral). **But re-scoring is the wrong lever** — the fix is
1a, which PREVENTS the upward self-destruct from happening at all. After 1a, this rule applies only to
the honest side ledge-dive case, where −1 is the right answer. No code change to attribution.

### Ownership
- **Game-designer (this ruling).** Value → `Tuning.bounds_top_margin` (gameplay-programmer, one line).
- **Level-designer:** update `levels/grassy_expanse.json` `bounds.top` to −2510 (and re-derive `bottom`
  after §4 removes the spring-pit platform — see §4). Sides (±960) and the derivation of bottom margin
  are UNCHANGED.
- **Camera dependency (flag, art-director + gameplay-programmer):** the taller top headroom is mostly
  EMPTY sky. The follow-cam MUST frame LIVING PLAYERS + the approaching blast line (v0kzr §6), NEVER
  fit the full bounds — the empty ceiling must not force a zoom-out. This composes with the CD's §4
  camera-shrink finding; do not fit-to-bounds.

---

## §2 — Endgame stall at 2x scale: finisher must CLOSE across the arena, + the FLEE half

### Diagnosis

The §5.5 finisher fixed the dev closeout (4.9s median) by raising *commitment* dials, but it relies on
the normal hunt-boost (`_cached_boost = dist > attack_range·0.8`) to close, and that boost is
repeatedly INTERRUPTED by the refuel dive: `_decide`'s refuel branch dives to
`Vector2(clampf(pos.x, …), sr.end.y)` — **straight down at the bot's CURRENT x**, which does not
advance the chase. On dev_arena (~900px separations) a couple of refuel cycles still closed the gap; on
grassy (~2400px separations) the boost-refuel oscillation nets little forward progress and the finalists
"park." Closeout time scales ~linearly with separation: the validated dev max of 21s at ~900px implies
~55s+ at 2400px — past the 30s HARD FAIL, effectively "never" in practice.

The math says the fix is trivial once the orbit is removed: at `normal_boost_max_speed = 760`, a
continuous beeline closes 2400px in ~3.2s. The stall is 100% refuel-orbit + no scale-aware pursuit.

### RULING 2a — finisher PURSUE: beeline + opponent-biased refuel (never retreat from the lone target)

While `_finisher` (≤ `finisher_opponents_left` living opponents) AND the lone opponent is outside
`_eff_attack_range()`, the bot enters an explicit PURSUE behavior:

1. **Beeline.** Boost directly at the opponent's live position (re-aimed each reaction tick), NOT toward
   stage center. Remove the `on_stage` diversion for finisher — a finisher bot with a valid lone
   opponent always pursues it directly (reflexive `_danger_recover` still preempts — safety first).
2. **Refuel-in-transit only.** When `me.fuel < _eff_refuel_floor()` (finisher floor 10), the refuel
   dive's x-target is **biased toward the opponent**: dive to the bounce surface that lies BETWEEN the
   bot and the opponent (`target.x = clampf(move_toward(pos.x, opponent.x, big), sr.left+100,
   sr.right-100)`), so every refuel bounce ALSO advances the chase. A finisher bot NEVER retreats away
   from its lone opponent to refuel.
3. **Commit persists** the whole approach (`finisher_commit_time_floor` already 1.5).

### RULING 2b — scale the finisher AIM-entry range with arena width

So the bot arms its super from proportionally further on a huge map (closes-then-blasts like a human,
instead of needing to get pixel-close), add a width factor to the finisher attack-range only:

```
# NEW Tuning
finisher_range_width_ref : 3660.0    # dev_arena blast-bounds width (left -900 .. right 2760)
finisher_range_width_max : 1.6       # cap on the width multiplier

# _eff_attack_range() while _finisher:
#   attack_range * finisher_attack_range_mult * clampf(bounds.size.x / finisher_range_width_ref, 1.0, finisher_range_width_max)
```

- Grassy bounds width = 4720 − (−960) = 5680 → factor `clampf(5680/3660, 1, 1.6) = 1.55`.
  Finisher AIM-entry range = 340 (L3) × 1.4 × 1.55 = **738px** (vs 476 on dev). The width factor
  clamps to 1.0 on the small arena (byte-identical to shipped §5.5 there — no dev regression).

### RULING 2c — the FLEE half: a wounded bot RETREATS to safe ground to heal (owner addendum)

The studio built the CHASE half (§5.6) but never the FLEE half. Add a bounded RETREAT state so
`chase-the-wounded` and `flee-to-heal` both exist — and, critically, so the flee is a GAMBLE, not
permanent evasion.

- **New per-difficulty dial `flee_skill`** (BotProfile, alongside `wounded_focus`): L1 **0.0** /
  L2 **0.15** / L3 **0.5** / L4 **0.8** / L5 **0.9**. Probability, on a reaction tick where the trigger
  holds, that the bot chooses RETREAT. (L1/L2 barely flee — they brawl on, comedy preserved.)
- **Trigger (primary):** `damage_level >= 1` AND no strong attack opportunity (no wounded prey inside
  the §3 chase radius AND not already committed to a finishing AIM) AND `_dmg_heal_t > 2.0` (worth
  fleeing — enough heal window left to matter).
- **Behavior:** pick the SAFE PLATFORM that maximizes `distance_to(nearest_opponent)` and is off the
  current fight, reachable by boost; fly there via boost (this USES FLIGHT to navigate — on-fantasy for
  the 2x arena, owner addendum); hold/heal until `_dmg_heal_t` elapses, a strong opportunity appears,
  or the anti-camp cap fires.
- **Anti-permanent-evasion (the load-bearing part — the chaser MUST close decisively at scale):**
  - Outside finisher: RETREAT is capped at `flee_max = 8.0s` (= the heal window) then force re-engage —
    a wounded bot cannot flee forever (Pillar 2).
  - In finisher (2 left): RETREAT is capped at `finisher_flee_max = 3.0s`; after 3s the wounded finalist
    MUST turn and fight (drop RETREAT). Combined with the healthy finalist's PURSUE (2a) closing at
    ~760px/s, this guarantees the closeout resolves — the fleer either reaches safe ground and stops
    (chaser closes onto a fixed point) or keeps running and is cornered against a wall (bounded arena).
    Flee is a gamble to survive the 8s, never a stalemate.
  - RETREAT breaks IMMEDIATELY on a kill opportunity (opponent within `_eff_attack_range()` and starved
    / near an edge) and on idle-hunt (§3.2 anti-camp override always wins).
- **Lull trigger (owner's option b) — FLAGGED, not primary.** A "retreat during a lull" in a
  no-standable-ground game where stages end in seconds risks reading as camping. Ship the DAMAGED
  trigger first (it directly serves crit-21 flee-to-heal and the chase/flee fantasy). A lull-retreat may
  be added later for L4/L5 only, strictly bounded and broken by idle-hunt at 4s — prototype after the
  damaged case is validated.

```
# NEW Tuning (flee-to-heal, §2c)
flee_max          : 8.0    # s cap on RETREAT outside finisher (= heal window; then force re-engage)
finisher_flee_max : 3.0    # s cap on RETREAT in the 2-left endgame (guarantees the closeout resolves)
# + per-difficulty BotProfile dial flee_skill: L1 0.0 / L2 0.15 / L3 0.5 / L4 0.8 / L5 0.9
```

### Ownership
- **Game-designer:** the intent, dials, and anti-evasion caps above.
- **Gameplay-programmer:** owns feasibility/pathing — the beeline vs `_steer`, the opponent-biased
  refuel target, the RETREAT state machine and safe-platform selection. No new arena contract (reads
  existing `arena.players[i]` + `damage_level` + `bounds`). Verify `_in_danger` is not falsely tripped
  while boosting over the widened pit (bot stays within the walkable AABB x-range near the floor).

---

## §3 — Melee kills-don't-land at scale: scale the chase-the-wounded radius with arena width

### Diagnosis

`chase-the-wounded` (§5.6) acquires/commits within `_eff_attack_range() * wounded_focus_range_mult`.
Shipped: `wounded_focus_range_mult = 1.5`, so L3 = 340 × 1.5 = **510px**. On a 3760px-walkable arena,
3–4 players spread 1500–2400px apart → a wounded opponent is almost never inside 510px → chase-the-
wounded barely fires → scattered hits never stack inside the 8s window → damage never escalates to Lv2
→ kills don't land. The 1.5-mult and the lowered `wounded_focus` probabilities (L3 0.45) were a
SMALL-ARENA bloodbath backoff (crit-21) and do not scale.

### RULING 3 — the chase radius scales with arena width (floored on attack-range)

```
# effective wounded-chase radius (used by _most_wounded_in_range AND the COMMIT clause):
reach = clampf( maxf(_eff_attack_range() * wounded_focus_range_mult,
                     Tuning.wounded_focus_frac * bounds.size.x),
                0.0, Tuning.wounded_focus_range_max )

# NEW Tuning
wounded_focus_frac      : 0.35     # fraction of blast-bounds width a bot will chase a wounded target across
wounded_focus_range_max : 2600.0   # camera/sanity cap
# wounded_focus_range_mult (1.5) KEPT as the small-arena floor term
```

- Grassy (width 5680): `0.35 × 5680 = 1988px` → chase radius **1988px** (vs the 510px attack-range
  term). A bot now pursues a fleeing wounded rival across most of the arena — the flight-required chase
  the 2x arena demands.
- Dev (width 3660): `0.35 × 3660 = 1281px` → still width-scaled; the mult term (510) is the floor for
  tiny levels only.

### wounded_focus starting values on the WIDE arena

The shipped `wounded_focus` (L2 0.35 / L3 0.45 / L4 0.6) were backed off for the small-arena bloodbath.
The wide arena has FEWER natural contacts, so restore the original §5.6 table as the WIDE-arena starting
point and let QA (crit 21) set the final value:

| Level | shipped | **wide-arena start** |
|---|---|---|
| L2 | 0.35 | 0.35 (keep) |
| L3 | 0.45 | **0.6** |
| L4 | 0.6 | **0.85** |

**Backoff knob (crit-21 bloodbath):** lower `wounded_focus_frac` (0.35 → 0.25) and/or the
`wounded_focus` probabilities — NEVER a lethality constant (`dmg_heal_time` / `dmg_launch_mult`
/ `smash_*` stay frozen; that is the whole point of the surgical targeting lever, §5.6). This CANNOT
regress the healthy-player recovery gamble (crit 20) because it only re-weights targeting toward
players already past their first hit.

### Ownership
- **Game-designer:** the width-scaled radius formula, constants, and starting `wounded_focus` values.
- **Gameplay-programmer:** apply the `reach` formula in `_most_wounded_in_range()` and the COMMIT clause
  (`_pick_target`, InputBot.gd ~274/315). Tiny additive change.

---

## §4 — Horizontal traversal must REQUIRE flight (level geometry)

### Diagnosis

Holding ONLY the direction key (zero boost, fuel pinned 100) crossed the whole 3760px map because the
**mid-pit spring platform (x1520–2240, y1300, w720) BRIDGES the 720px pit** between the two trampoline
floors (left x0–1520, right x2240–3760). Drift-reach math on the CURRENT constants (do NOT change them):

- A **trampoline** bounce (270px) hangtime ≈ `2·√(2·270/1600)` = 1.16s → drift at `air_drift_max_speed`
  340 = **~395px** per bounce.
- A **spring** bounce (480px) hangtime ≈ 1.55s → drift **~527px** (the level's own `design_intent`
  cites 527). Plus 0.98 tangential retention carries prior momentum.

The 720px pit exceeds a trampoline-bounce drift (395px) — so WITHOUT the bridge you fall in. But the
w720 spring platform spanning the pit lets you bounce mid-pit and continue (527px spring drift) →
zero-boost crossing. The bridge defeats the arena's own flight-required intent (GAME_ESSENCE core verb
2: "traversal must REQUIRE flight").

### RULING 4 — remove the bridge and widen the pit past drift+coast reach

**Do NOT touch `tangential_retention` (0.98) or `air_drift_*`** — those are movement-feel constants
(Pillar 1); nerfing them to fix one gap would degrade the whole game's feel. Fix the GEOMETRY:

1. **Remove the mid-pit spring platform** `{x:1520, y:1300, w:720, tier:spring}` (the bridge).
2. **Widen the central pit to ~960px.** Trim the inner edges of the two trampoline floors so the gap
   between them is ≥960px (e.g. left floor ends at x1400, right floor starts at x2360 → 960px gap;
   or move them apart symmetrically). 960px exceeds BOTH the zero-boost drift reach (395px) AND a
   boost-then-coast reach (~850px at retained 745px/s over a 1.16s trampoline hangtime) → **sustained
   boost / flight is mandatory to cross** (a single sustained normal boost at 760px/s crosses 960px in
   ~1.3s — flight required, but not punishing).
3. **Optional — preserve the spring GEYSER as risk/reward, NOT a bridge.** If the geyser fantasy is
   wanted, re-add a NARROW spring pad (w ≤ 240) sunk DEEP in the pit (y ≥ 1500, well below the floor
   line y1000) so: (a) reaching it means dropping below the floor (a committed detour, not a walkway),
   and (b) each side gap from the pad edge to the nearest floor edge is ≥ 560px (> the 527px spring
   drift) so springing off it cannot bridge to either floor. This needs a wider pit (≈240 + 2×560 =
   ~1360px) — acceptable, or omit the geyser and keep the clean 960px gap. **Recommend: ship the clean
   960px gap first (simplest, guaranteed flight-required); add the deep narrow geyser as polish.**
4. **Re-set bounds after the geometry change:** removing the spring-pit platform raises `walkable.bottom`
   from y1364 to the trampoline floor bottom y1128 → derived `bottom = 1128 + bounds_bottom_margin(670)
   = 1798`. Update grassy's explicit `bounds.bottom` to **1798** (or drop the explicit block and let
   derivation run — the throne still governs `top` per §1). `top` = −2510 (§1). Sides ±960 unchanged.

### Ownership
- **Game-designer:** rules the fix (remove bridge, widen to ≥960, keep drift constants).
- **Level-designer:** owns the exact re-layout (floor edges, optional deep geyser, spawn/powerup
  repositioning if the pit move orphans a spawn) and MUST re-run the movement-tool-per-gap analysis
  (GAME_ESSENCE per-role obligation): prove every gap > drift+coast reach and every upper pad >
  spring-apex, i.e. flight is required both horizontally and vertically.

---

## §5 — Success criteria, measured ON THE PROPER ARENA (grassy_expanse, 4-bot)

> These REPLACE the dev-arena stage/closeout targets (killrace §8 crit 11/15/17/18/19 and v0kzr D6/D7)
> **for the flagship arena**. All are provisional until re-run on the **~10-level circuit** (owner:
> pacing/feel must be measured across the real rotation, not one arena). The dev targets remain valid
> for the "mini" variant. Harness = `python tools/gbplay.py` eval + burst screenshots, ≥24 4-bot
> idle-P1 stages on grassy unless noted.

**Kill economy fires (the make-or-break)**
- **S1 — kills land.** Median first-elimination (BOUNCE → first elim) **≤ 12s**, p90 **≤ 22s**; a
  first-elim > 35s is a HARD FAIL. Whole-stage COMBAT median **≤ 22s**, p90 **≤ 35s**. Median **≥ 2
  credited kills/stage**. ZERO stages end with zero credited kills (the `[0,0,0,0]` regression guard).
  *(Wider targets than dev's 8–18s: 2x traversal legitimately lengthens stages. If S4 fails because of
  this, escalate the target-vs-feel fork — §5.6 doctrine — do NOT crank lethality.)*
- **S2 — uncredited self-destruct share is LOW.** Across the aggregate, uncredited self-ring-outs
  (`attacker == −1`, cause `ring_out`, not launched-by-another within the credit window) **≤ 10%** of
  all deaths; upward self-destructs specifically (self-super, apex above the top band) **≤ 5%**. This is
  the §1 verification — the CD baseline was ~100% of the deaths that stage.
- **S3 — 1v1 closeout AT 2x scale.** From `TWO LEFT!` to the deciding death on grassy: median **≤ 8s**,
  p90 **≤ 15s**; single > 20s = soft flag; > 30s = HARD FAIL. Same targets as the dev crit 15, now on
  the wide arena — this is the §2 verification (the ~2400px-park regression guard).
- **S4 — full match to 10.** 4-bot idle-P1 match to `match_target_kills = 10` completes in **≤ 6 min**
  median (≥3 matches); > 8 min = HARD FAIL. *(Relaxed from the dev 2.5–5 min for 2x traversal; if it
  cannot hit 5 min without failing S5/S6, present the owner the values fork — longer match, fewer target
  kills, or tighter geometry — per §5.6, never a lethality crank.)*

**Fantasy-fit guardrails (must hold WITH the fixes)**
- **S5 — healthy survives a single mid hit (crit 20, on grassy geometry).** A healthy (`damage_level==0`),
  full-fuel player struck by ONE qualifying MID-STAGE hit (placed at a floor center, ≥ the §13 band from
  any side wall) arcs back in bounds, not eliminated, **≥ 8/10** scripted trials. Wounded-focus width-
  scaling (§3) must not regress this (it only re-weights targeting). < 8/10 = the escalation trigger.
- **S6 — flee-to-heal stays real (crit 21) AND is observable.** **≥ 25%** of Lv1-damage events heal
  back to Lv0 without the player dying. PLUS a behavioral check: a wounded bot is observed FLYING to a
  distant platform and holding to heal (RETREAT, §2c — screenshot/eval). Flee must NOT become permanent
  evasion — S3 (closeout resolves) is the paired guard.

**Flight-required traversal (§4)**
- **S7 — horizontal flight required.** A bot/human holding ONLY the direction key (zero boost, fuel
  pinned) starting on one floor does NOT reach the far floor — it falls into the pit / out of bounds
  (≥ 9/10). A successful floor-to-floor crossing logs ≥ 1 boost activation + measurable fuel drain
  (sustained flight was used). *(Vertical flight-required — natural bounce apex short of the upper pads
  — already LANDED per the CD; do not touch.)*

**Vertical bounds (§1) — AMENDS v0kzr D7**
- **S8 — upward self-super now ARCS BACK (the inverse of old D7).** A self-super fired straight up from
  the FLOOR or a SHOULDER pad on grassy → alive 3s AND apex above the top bound (arcs back) **≥ 8/10**.
  Path 1 spot-check: a self-super into a near SIDE wall with a drained tank still self-destructs
  ≤ 2.5s (the intentional void-kill, now side-relative); a self-super straight up from the THRONE still
  self-destructs (rare, intentional). D7's old "straight-up self-destructs off top ≥8/10" is RETIRED for
  levels whose top margin ≥ self-super rise (all circuit levels under §1).

---

## §6 — Ownership summary & recommended build order

**Game-designer-owned (rulings + values, this spec):** §1 top-margin math + the −1-suicide affirmation;
§2 finisher-pursuit intent + flee dials + anti-evasion caps; §3 chase-radius width formula + starting
`wounded_focus`; §4 the traversal fix (remove bridge, widen ≥960, freeze drift constants); §5 criteria.

**Handed to gameplay-programmer (feasibility/implementation):** `bounds_top_margin` constant (§1);
finisher beeline + opponent-biased refuel + width-scaled range + RETREAT state machine + safe-platform
selection (§2); the width-scaled `reach` in `_most_wounded_in_range`/COMMIT (§3); the new BotProfile
dial `flee_skill` and new Tuning constants. No new arena contract field.

**Handed to level-designer:** grassy_expanse.json — `bounds.top = −2510`, `bounds.bottom = 1798`,
remove the spring-pit bridge, widen the pit to ≥960px, optional deep narrow geyser, re-run the
movement-tool-per-gap flight-required analysis (§4).

**Handed to art-director + gameplay-programmer (flag, not this spec):** the camera at 2x scale (CD §4) —
frame players + approaching wall, never fit-to-bounds; the taller §1 headroom must not force zoom-out.

**Recommended build order (depth-first; each gates the next measurement):**
1. **§1 top-margin** (one Tuning constant + grassy JSON top). Trivial; do FIRST — it stops the
   uncredited upward self-destructs that pollute EVERY other measurement (you cannot trust S1/S3/S4
   until deaths are credited).
2. **§4 geometry** (level-designer: remove bridge, widen pit, re-set bottom). Needed so all combat/
   pacing is measured on the REAL representative layout, not the bridged one.
3. **§2a/§2b finisher PURSUE + width-range** (the critical stall fix). Re-run S3 — the closeout must
   resolve at 2x before anything else is trustworthy.
4. **§3 chase-radius width scaling** + restored `wounded_focus`. Re-run S1/S5/S6 — melee kills land
   without a bloodbath.
5. **§2c flee-to-heal RETREAT** (the largest new behavior; the FLEE half). Re-run S6 (flee real +
   observable) and re-confirm S3 (flee did not become evasion).
6. **Full re-QA on grassy** (S1–S8), THEN author the ~9 remaining circuit levels to this template and
   **re-run all of S1–S8 on the ~10-level circuit** (owner: the real validation surface).

**Fence reaffirmed:** every fix here is geometry or bot behavior. NO change to any lethality constant
(`smash_*`, `dmg_*`, `hitstun_*`), NO change to movement-feel constants (`tangential_retention`,
`air_drift_*`, `max_speed`, `super_boost_impulse_full`), NO round timer, NO HP bar, NO standable ground.
