# Spec: v0 Kill Zone & the Recovery Gamble — hit-solidity, runway, and the failed-recovery death

> **Owner:** Lead Game Designer. **Status:** READY FOR RE-BUILD+RE-QA. **v2 — 2026-07-03.**
> **This is an amendment to `docs/specs/v0_combat_lethality.md`.** It SUPERSEDES that spec's §2.1
> smash-impulse formula and §2.4 blast-zone bounds, and it EXTENDS §9 with new tests (22–30). It is
> a standalone file (the parent spec has no §2.5 slot and is not being rewritten in place); read it
> as the parent's §2.5. **It HOLDS v0 lethality sign-off** — the 29-round v2.1 QA was measured
> against geometry the owner says is wrong (`docs/feedback/owner_2026-07-03_kill_zone.md`), so
> re-run the FULL §9 plus the tests here after this build.
>
> **v2 REVISION (2026-07-03, post-QA of build c6229c4).** The v1 §3 **GATE** solidity model
> (`launch_scale = (s − smash_solidity_min)/(1 − smash_solidity_min)`, launch = 0 below the floor)
> **is SUPERSEDED.** QA at the new geometry proved the mechanic (a 45° dead-center smash arcs back
> alive-in-bounds; launch scaled monotonically with solidity) BUT pacing regressed hard: at
> `smash_solidity_min=0.25` sudden-death fired in **83%** of rounds and only **~1 qualifying smash
> per 13 rounds** was recorded; lowering the floor to 0.1 only reached ~50% SD and ~2 smashes/8
> rounds. ROOT CAUSE (STATUS session 4): `s = dot(velocity_dir, line-of-centers)` is LOW for most
> real hits in a bouncy game — attackers rarely travel straight through the victim's center at the
> contact frame (velocity carries big vertical/tangential components from bouncing). The GATE
> therefore zeroed the launch of ~all real hits → kills vanished → rounds dragged to the SD laser.
> Lowering the floor was a partial patch, not a fix; the GATE itself was the problem. **§3 is now a
> BASELINE + BONUS model:** every ELIGIBLE smash launches a guaranteed baseline (a landed smash
> always does something → kills stay frequent), and solidity adds a BONUS on top toward the cap (a
> dead-center hit "really sends them flying" and stings full; a glance launches only the baseline and
> arcs back — survivable). The bounds are pulled **partway back** in tandem (§4). `smash_solidity_min`
> is REMOVED from the model.
>
> Sources: `docs/feedback/owner_2026-07-03_kill_zone.md` (feedback + diagnosis + the hit-solidity
> Addendum), `docs/feedback/owner_2026-07-02_movement_feel.md` (the thesis), `docs/STATUS.md`
> session-4 QA block (the regression that drove v2), `src/core/Tuning.gd`, `src/entities/Player.gd`
> (`_handle_smashes`/`receive_smash`), `src/systems/CameraController.gd`, `src/modes/PartyMatch.gd`,
> `levels/dev_arena.json`.
>
> **DO-NOT-TOUCH (load-bearing for this fix):** §4.6 hitstun triad
> (`hitstun_base`/`hitstun_per_impulse`/`hitstun_max`), §2.3a bumper/tier DRY-REFLECT ("hitstun ends
> by TIME, never by touching a surface"), the drain-all super, `super_boost_impulse_full` (2800),
> `max_speed` (3000), the closed no-power-scaling decision, the `smash_impulse_max` cap (2200), no
> HP / damage-meter, no humanoid / damage-accum. See the fence (§7).

---

## 1. The kill model (in words — the target feel)

The lethal tool is the SMASH (a fired super, or a licensed flying stunned body — parent §2.1). A
smash should launch the victim on a **readable arc**. Every landed smash launches a **baseline** (it
always does something — you connected, they go flying a bit), and **how solidly you hit sets how much
FARTHER** — a dead-center hit sends them flying hard, a glance launches only the baseline. From that
launch there are exactly two ways to die, and both are *earned*:

1. **The clean super into the void.** You aim your OWN super off the top or out a side with no
   runway left and self-destruct — full-power `super_boost_impulse_full` (2800) on yourself, the
   commitment gag (Pillars 3/4). This kill must stay.
2. **The failed recovery.** You get smashed toward a blast line and *try to fly back* — and fail
   because (a) the sting starved your tank below `super_boost_min_fuel` so you have **no escape
   super**, (b) you snap-aimed the counter too slow / in a bad direction, or (c) a **second hit**
   caught you mid-recovery, or (d) you were already close to the wall and the launch simply carried
   you across. The death is a story about a botched comeback.

Everything else is a **scare, not a death**:

- A **glancing** smash (clipped head/feet, off-center) spins the victim and launches them at the
  **baseline** only — from mid-stage it arcs back into the fight; only near a wall or starved does it
  ring out. Glancing hits are the survivable knocks.
- A **dead-center** smash launches at the full cap. It is lethal *when aimed into a void, when it
  starves the victim, or from a committed near-wall position*; a center hit straight up from
  mid-stage still arcs back down (short of the ceiling — §4). So "center = the hit that CAN kill and
  sends them flying hardest," not "center = always kills."
- A **SHOVE** (parent §2.3) never launches lethally — honest physics, always answerable.

This is the movement-feel thesis applied to death: the recovery arc is a movement-skill expression,
and the two skills are **aiming for solidity (attacker) and aim+timing under fuel pressure (victim)**.

---

## 2. What parent-§2.4 got right, and what it over-tightened (reconciliation)

**§2.4 was correct that:** kills must be frequent and *earned by action*, not by lasers (QA #1:
55–60% laser-decided "traffic accidents"); a cap-speed smash near a wall SHOULD kill; the bumper
must not hand out free saves (§2.3a — kept, unchanged, and MORE important now, see §7).

**§2.4 over-tightened on the one axis it mis-diagnosed:** it treated *bounds* as the only lethality
knob and left the **smash launch a single uncapped, solidity-blind impulse**. With
`impulse = 500 + attacker_speed × 1.35`, a super impacting at ~2500 → ~3875 impulse → the victim's
`velocity = (velocity + impulse)` hits the `max_speed` (3000) cap on *every* clean smash, head-on or
grazing alike. A victim launched at 3000 travels 1650px during the 0.55s max hitstun alone — more
than §2.4's ~660px runway — so the recovery arc was *physically impossible regardless of skill*, and
there was **no difference between a skilled center hit and a lucky graze**. §2.4 then tightened
bounds on top of that, compounding it.

The v1 fix over-corrected the OTHER way: it made launch scale with solidity but as a **hard gate**
(launch = 0 below `smash_solidity_min`). Because real bouncy-motion hits are mostly low-solidity, the
gate zeroed ~all launches → kills vanished → SD dominated (83%). **The right shape is a floor, not a
gate:** every eligible smash launches a baseline (frequency restored), solidity adds the bonus toward
the cap (the skill spectrum survives). Paired with a runway that is widened but pulled PARTWAY back
from v1 (§4) and the **sting** (fuel starve) as the executioner (§5), this reconciles both feedbacks:
knocks arc and are recoverable, but kills stay frequent because a landed smash always launches, solid
hits starve, and near-wall/committed positions still ring out.

---

## 3. Lever A (PRIMARY) — HIT SOLIDITY as a BASELINE + BONUS (SUPERSEDES the v1 gate)

Owner Addendum: *"How solidly you hit scales launch. Dead-center → flying (a kill). Glancing
head/feet → spin (torque) without launching far (a survivable knock that arcs back). Build it on the
CURRENT sphere collider via the impact parameter."* — reconciled here with the QA reality that most
real hits are low-solidity: solidity sets the BONUS above a guaranteed baseline, it does not gate the
launch to zero.

### 3.1 The solidity value (computable on the current sphere collider — no new geometry)

In `_handle_smashes`, attacker is `self`, victim is `b`. Both are circle colliders, so the
line-of-centers IS the contact normal:

```
n            = (b.global_position - global_position).normalized()   # contact normal, attacker→victim
vdir         = velocity.normalized()                                # attacker's travel direction
solidity s   = clampf(vdir.dot(n), 0.0, 1.0)                         # 1.0 = dead-on center, 0 = pure graze
```

`s = 1.0` means the attacker is driving straight through the victim's center (head-on); `s → 0` means
the attacker is skimming the victim's edge (a clipped head/feet graze). This is the classic
circle-collision **impact parameter**, and it needs nothing but the sphere colliders we already have.
`s` is **unchanged** from v1 — only how it maps to launch/sting/spin changes.

### 3.2 Solidity is a BONUS above a guaranteed BASELINE launch

```
raw_impulse   = smash_impulse_base + my_speed * smash_impulse_from_attacker   # the PHYSICAL ceiling (as today)
launch_scale  = smash_launch_floor + (1.0 - smash_launch_floor) * s           # in [smash_launch_floor .. 1.0]
impulse_mag   = minf(raw_impulse, smash_impulse_max * launch_scale)           # baseline -> cap, never above physical
impulse       = velocity.normalized() * impulse_mag                           # launch dir unchanged (along travel)
# spin: the LESS solid the hit, the more the momentum becomes torque — the comedic tumble "you got clipped"
spin_sign     = signf(vdir.cross(n))
angular_kick  = smash_spin_max * (1.0 - s) * spin_sign                        # rad/s, applied to the victim sprite
```

The launch magnitude is `smash_impulse_max × launch_scale`, clamped down by the attacker's physical
`raw_impulse` so a slow smash can never launch harder than its own momentum. `launch_scale` runs from
`smash_launch_floor` (a pure graze, s=0) to `1.0` (dead-center, s=1). **There is no zero-launch case
and no floor gate.** With `smash_launch_floor = 0.6` and `smash_impulse_max = 2200`:

- **Launch is a spectrum with a floor:** s=0.0 (graze) → `0.60 × 2200 ≈ 1320`; s=0.2 → ~1408;
  s=0.5 → ~1760; s=0.7 → ~1936; s=1.0 → **2200 (capped)**. Every eligible smash launches ≥ ~1320
  (a real, readable knock — restores kill frequency), and a dead-center hit "really sends them
  flying" at the cap. Linear between.
- **Sting (parent §2.2) scales with SOLIDITY directly** — NOT with `launch_scale` (whose floor would
  starve everyone). New rule: `sting = smash_sting_fuel * s`, applied only when
  `impulse_mag ≥ smash_sting_min_impulse` (1500). At `smash_launch_floor = 0.6` the baseline launch
  (~1320) sits *below* 1500, so a **graze stings nothing** (survivable, no secret starve-kill); the
  gate is crossed only around **s ≳ 0.21** (`impulse_mag ≥ 1500`), and from there sting rises with s.
  A moderate super hit (s=0.3) stings `30 × 0.3 = 9`; a dead-center super stings the full **30** → the
  sting-starve kill (path 2) is intact for *solid* hits, gone for glances. (Keeping the 1500 impulse
  gate also preserves the parent's weapon-type distinction — Star @900 / Counter @1400 still never
  sting, unchanged.)
- **Hitstun is UNCHANGED and needs no new constant:** it already reads `impulse.length()`
  (parent §2.1, `Player.receive_smash` line ~703). Feed it the solidity-scaled `impulse_mag` and a
  graze naturally produces shorter hitstun (impulse ~1320 → ~0.48s), a center hit the max (impulse
  2200 → 0.55s cap). We do NOT touch `hitstun_*`.
- **Spin/torque now scales with `(1 − s)`** (not `1 − launch_scale`, which no longer reaches its
  bounds cleanly): a pure graze (s→0) tumbles the victim at `smash_spin_max`, a dead-center hit
  (s→1) barely spins. This is the *readability signal*: "that was a glance, they're fine (and
  spinning)" vs "that was solid, they're gone (clean launch)." Decays over the hitstun window.
  Programmer feasibility note unchanged: if the sprite pivot can't rotate yet, ship launch-solidity
  first, spin as a fast-follow — not a blocker.

### 3.3 New / changed constants (Tuning.gd)

| Constant | Value | Rationale |
|---|---|---|
| **`smash_launch_floor`** (NEW) | **0.6** | Fraction of the cap that EVERY eligible smash launches regardless of solidity (baseline ≈ 1320 impulse). Set to 0.6 (not 0.5) to bias toward the failure we are fixing — too few kills / 83% SD — better to start slightly hot on kills and back off. This is the FIRST tuning knob: raise → 0.65/0.7 if kills stay rare; lower → 0.5/0.45 if rounds one-shot or recovery never happens. Kept below the sting gate (0.6×2200=1320 < 1500) so grazes don't starve. |
| **`smash_solidity_min`** | **REMOVED** | v1 GATE constant. Superseded by `smash_launch_floor`. Delete the var (or leave dead + unreferenced); it no longer appears in the launch formula. |
| **`smash_spin_max`** | **12.0** (rad/s) | Full-graze tumble speed; now ∝ `(1 − s)`. Cosmetic-plus-readability; feel-only. |
| `smash_impulse_from_attacker` | **1.1** (already applied) | Coefficient sets only the physical `raw_impulse` ceiling; the cap governs above it. Lower to 0.9 if solid chains feel too lethal; never up. |
| `smash_impulse_base` | **unchanged** (500) | |
| `smash_impulse_max` | **unchanged** (2200) | Hard cap on `impulse_mag`; the dead-center ceiling. DO-NOT-TOUCH. |
| `smash_sting_fuel` | **unchanged** (30) | Full sting at s=1; scales down with s. Second knob UP (→36) only if kills stay rare after `smash_launch_floor`. |
| `smash_sting_min_impulse` | **unchanged** (1500) | Sting gate; also preserves Star/Counter no-sting. |

### 3.4 Why baseline+bonus is the right shape (not the gate, not a flat cap)

A flat cap alone makes every clean hit identical at 2200 — attacker skill vanishes. A hard gate (v1)
makes ~every real hit launch **zero** — kills vanish (the 83% SD regression). **Baseline + bonus keeps
both**: a landed smash always threatens (kills frequent, Pillar 4 snappy rounds), AND a good player
who *aims for the center* converts a knock into a big launch + full sting + a likely kill (Pillar 1
high ceiling), while a rushed/clipped attacker only gets the baseline + spin (survivable). That is the
recovery-gamble spectrum the owner asked for, with a floor under it so it never collapses to "landed
hits do nothing."

---

## 4. Lever B — the runway (bounds; `levels/dev_arena.json`, supersedes §2.4 AND v1 §4)

Platform spans x∈[64,1856]; "runway" = distance from platform edge to blast line. **v1 widened too
far given kills were already rare** (STATUS: 83% SD). v2 pulls the bounds **partway back** — still far
wider than §2.4's lethal geometry (which killed the recovery gamble), but tightened from v1 so the
baseline launch + sting can convert to kills near the walls. Sizing target: a **dead-center** capped
smash (2200) must have *just* enough room to be recoverable-with-skill from mid-stage, and be lethal
from a committed near-wall position; the common low-solidity baseline launch arcs back from mid-stage.

| Bound | §2.4 | v1 (§2.5) | **v2 (this spec)** | Rationale |
|---|---|---|---|---|
| `left` | −620 | −1100 | **−900** | ~964px runway from x=64. A capped-center 45°-outward smash (2200) burns horizontal 1556×0.55 ≈ **856px** during max hitstun — nearly the whole runway, so from a near-wall position it rings out (lethal center) but from mid-stage there is room to arc/counter. A baseline graze (~1320, horiz ~933 over ~0.48s ≈ 448px) arcs back from anywhere but the wall edge. |
| `right` | 2520 | 3000 | **2760** | Symmetric (~904px runway from x=1856). |
| `top` | −950 | −1200 | **−1150** | Straight-up *capped-center* smash from mid-stage (y≈700): rise = 2200²/3200 ≈ 1512 → apex y≈**−812** → clears −1150 by ~338px, arcs back (owner's direct ask, test 25). From the high spring platform (y≈380): apex ≈−1132 → still clears −1150. A *self-fired* vertical super (2800) from the floor (y≈980): apex ≈**−1470** → exceeds −1150 → **self-destruct void kill preserved** (path 1), with ≥320px margin from every launch position. |
| `bottom` | 1780 | 1780 | **unchanged** | Floor spans the stage. |

These sides are ~280px wider than §2.4 (−620/2520) but ~200px tighter than v1 (−1100/3000); top is
50px tighter than v1. Deliberate: v1 was measured too-wide-and-kills-rare; v2 restores kill pressure
near the walls while the baseline launch (§3) + sting (§5) keep kills frequent overall. Laser walls
spawn at the new bounds (parent §5). Tighten order in the fence (§7): `smash_launch_floor` up FIRST,
then bounds tighter, then sting.

---

## 5. Lever C (SECONDARY safety) — global impulse cap, + why the sting is the executioner

- **`smash_impulse_max` = 2200.0** (hard cap on `impulse_mag`, applied via `smash_impulse_max ×
  launch_scale` in §3.2, *before* the `max_speed` limit, in both the player and prop branches of
  `_handle_smashes`, ~lines 619/641). A perfect dead-center super is clamped to 2200 so even the best
  hit stays inside the runway math in §4. This is the ceiling; solidity shapes baseline→cap below it.
- **The sting is the kill-rate backstop, not the wall.** With baseline+bonus+cap+runway, a *fueled*
  victim usually survives a single mid-solidity smash from mid-stage. Kills stay frequent because
  (a) EVERY landed smash launches ≥ baseline (~1320) so near-wall/committed positions ring out, and
  (b) a **solid** hit (s high) stings up to the full 30 fuel → a mid-tank victim (≤34) is starved
  below `super_boost_min_fuel` (5) → **no counter exists** → the launch carries them out on a clean
  arc. Wider walls than §2.4, but the kill rate is held by *baseline launch + starvation on solid
  hits*, not wall proximity alone. If kills go too rare after this build, first knob is
  `smash_launch_floor` UP, then bounds tighter, then `smash_sting_fuel` 30→36 — NEVER hitstun, NEVER
  power scaling (§7).

### 5.1 Lever D — drain-all super as the recovery COST: KEEP, unchanged (not too punishing)

After a successful counter-super the victim is at **0 fuel** and must bounce to re-arm. This is the
*correct* cost: it is exactly what makes "second hit mid-recovery" (path 3) and sting-starve (path 2)
lethal. A victim who survives one smash has spent everything and is vulnerable flying back in — that
IS the failed-recovery drama. Do NOT add a flat-cost or partial-drain escape super (re-introduces
hoarding, Pillar 2, and removes the second-hit window). `super_boost_min_fuel` stays 5.0;
`fuel_per_bounce`/`fuel_per_bumper` stay 20.

---

## 6. CAMERA — gameplay-programmer dependency (BLOCKING for the feel to read)

A wider play space breaks the current framing (`PartyMatch._update_camera` + `CameraController`,
`CAM_MIN_ZOOM = 0.42`). The recovery arc happens near the blast lines; if the camera cannot follow a
knocked-but-alive player out there, the whole gamble happens **off-screen**. Requirements (verify in
test 29):

1. **Follow knocked-but-alive players.** `_update_camera` already frames all `not p.is_dead()`
   players — confirm a player in hitstun / mid-recovery (alive, `_dead == false`) is NOT excluded.
2. **Keep the approaching blast line on-screen.** During a recovery arc, both the launched blob AND
   the blast line it heads toward must be visible so the player can read "how much runway is left."
3. **Zoom-out headroom.** v2 bounds span **3660px wide × 2930px tall** (−900..2760, −1150..1780) —
   smaller than v1's 4100×2980 but still beyond the current frame. At `CAM_MIN_ZOOM = 0.42` a 1080p
   viewport shows 2571px tall < 2930 needed. Programmer's call: (a) lower `CAM_MIN_ZOOM` to ~**0.37**
   (shows ~2919px tall — verify blob readability at that scale, Pillar 5), OR (b) bias the frame
   toward the fastest-moving / knocked player + the nearest wall instead of fitting everyone. Either
   is fine if it satisfies (1)+(2).
4. **Follow lag on a fast launch.** `follow_speed = 6.0` with fixed `margin = (420,340)` may let a
   fresh capped (2200) launch outrun the frame. Confirm it stays in-frame (raise `follow_speed`,
   widen the leading margin in the launch direction, or lead the velocity).

NEW gameplay-programmer dependency; changes no Tuning feel constant. Ship bounds+impulse+camera
together, or the burst-screenshot tests (25/26/29) show recovery in a black off-screen void.

---

## 7. Fence — what NOT to do

- **Do NOT raise hitstun** (`hitstun_base`/`per_impulse`/`max`). §4.6 triad protected. If recovery
  fails too often: lower `smash_launch_floor` or `smash_impulse_from_attacker`, never hitstun.
- **Do NOT re-introduce super power scaling** (`docs/DECISIONS.md` 2026-07-02, closed).
- **Do NOT lower `super_boost_impulse_full` (2800) or `max_speed` (3000).** The self-super void kill
  (path 1) needs the 2800 self-super to out-rise the 2200 smash cap past the −1150 ceiling.
- **Do NOT re-introduce a launch GATE / zero-launch floor** (the v1 model). Every eligible smash MUST
  launch ≥ baseline; that is the whole v2 fix. `smash_launch_floor` never goes to 0.
- **Do NOT widen bounds so far kills vanish.** If post-build laser% > 25% (t11 regresses), FIRST raise
  `smash_launch_floor`, THEN tighten bounds toward −800/2660/−1100, THEN raise `smash_sting_fuel`.
- **Do NOT reopen §2.3a** (bumper/tier dry-reflect). Hitstun ends by TIME, never by touching a
  surface. MORE load-bearing now: wider bounds mean more bumper→wall gaps a stunned flier crosses.
- **Do NOT remove the drain-all super or add a cheap escape** (§5.1).
- **Do NOT add standable ground, health bars, air-brakes, or any camping affordance** (Pillars).

### 7.1 Explicitly deferred / scoped-OUT (owner Addendum)

- **Taller / rectangular humanoid character with literal head/center/feet hit regions — NOT SPECCED.**
  It reopens the deliberate sphere-blob decisions (AI-generatability, circle-collider match). A
  SEPARATE gated art+collider bet, noted here as a **future option only**. The impact-parameter
  solidity in §3 delivers the head/center/feet *spectrum* on the current sphere with zero new art.
- **Smash-style persistent damage accumulation — SCOPED OUT (resolved: the transient "damaged/
  vulnerable" red-pulse state is ADOPTED as the NEXT slice, built ON proven hit-solidity — owner
  Addendum, `owner_2026-07-03_kill_zone.md`). NOT part of this build.** Persistent-% HP is REJECTED
  (conflicts with no-HP identity, competes with fuel). Do not build the reeling/vulnerable state in
  this pass — it depends on solidity being proven in-engine first (depth-first).

---

## 8. Instrumentation — round_stats additions (programmer dependency)

To measure the solidity distribution and "survived a knock / attempted recovery," extend
`round_stats` (parent §8; read-only QA feeds, not feel constants):

- **`smashes[]`** (NEW), **one entry per ELIGIBLE `receive_smash`** (eligibility unchanged: super-
  active/stunned attacker + rel ≥ 900 + faster than victim — since baseline+bonus means EVERY eligible
  hit now launches ≥ baseline, log all of them; the v1 `launch_scale > 0` condition is now always
  true, so gate logging on eligibility, not on launch magnitude): `{ t (round_clock s), attacker,
  victim, solidity (s, §3.1), launch_scale, launch_speed (victim |velocity| the frame after),
  angle_deg (impulse dir, 0°=+x, −90°=up), by_super (attacker.super_active), victim_fuel_after
  (post-sting), starved (victim_fuel_after < super_boost_min_fuel), spin (angular_kick applied) }`.
- **Add `t` (round_clock s)** to the existing `kills[]` and `supers_fired[]` entries — the enabler
  for correlation metrics.
- QA then computes: a smash is **survived** if the victim is alive 2.5s after its `t` AND x inside
  `[left, right]` at that time; a **recovery was attempted** if that victim has a `supers_fired[]`
  entry with `t` within 1.0s after the smash `t`.

The single most important regression guard is now **smash FREQUENCY** (the v1 build recorded ~1 smash
per 13 rounds). QA must confirm smashes are logged at the eligible-hit rate again (test 28d).

If instrumentation slips, the deterministic eval+burst-screenshot tests (22–26, 29) still gate the
build without the aggregate.

---

## 9. Success criteria (additions to parent §9 — re-run the WHOLE of §9 too)

Harness as parent §9. "Deterministic case" = eval-placed idle victim, scripted single smash, burst
screenshots at 0.2s for 3s + eval of victim `is_dead()`, `global_position`, `fuel`, angular velocity.
"Idle-P1 aggregate" = standard lineup, P1 untouched, **≥24 rounds** (v1 samples of 6–8 were too thin
to read pacing), reading `smashes[]`.

**Hit-solidity (the new baseline+bonus lever)**
22. **Solidity scales launch ABOVE A FLOOR (deterministic sweep).** Script the same super into a
    victim placed to yield `s ≈ {1.0, 0.7, 0.4, 0.1}` (offset victim center off the attacker's travel
    line). Measured `launch_speed` must be **monotonic** in `s`, **never zero**, and match
    `smash_impulse_max × (0.6 + 0.4·s)` within ±10%: s=1.0 → ~2200 (capped); s=0.7 → ~1936; s=0.4 →
    ~1672; s=0.1 (near-graze) → ~1408 (a REAL launch, NOT ≤ a shove) + visible spin (victim angular
    velocity > 4 rad/s). A zero-launch or gated result at low s FAILS (that was the v1 bug).
23. **Glancing hits are survivable everywhere; center hits can kill.** Deterministic:
    a. A glancing smash (`s ≈ 0.15`) on a full-fuel **mid-stage** victim → victim alive at 3s AND x
       inside bounds in **≥9/10**, from any launch angle (baseline ~1320 arcs back from mid-stage — a
       glance never rings out from mid-stage).
    b. A dead-center smash (`s ≥ 0.9`) aimed 45°-outward on a victim placed 800px from the near wall,
       starved to 4 fuel → rings out ≤2.5s in **≥8/10**.
24. **Sting scales with solidity (glances don't secretly starve).** Deterministic + eval: a glancing
    hit (`s ≈ 0.15`, impulse ~1320 < 1500 gate) drops victim fuel by **0** (≤ 2 tolerance); a
    dead-center hit (`s ≥ 0.9`) drops it by **≥ 27** (≥ 0.9 × `smash_sting_fuel`, ±2).

**The recovery gamble (kill paths)**
25. **Straight-up center smash arcs back (owner's direct ask).** Deterministic: full-fuel mid-stage
    victim, dead-center super within ±20° of straight up → alive at 3.0s AND apex y stays below (>)
    `top` (−1150) in **≥8/10** (must NOT ring out off the top).
26. **45°-outward recovery gamble (fails if EITHER part fails):**
    a. *Survivable mid-solidity knock:* full-fuel **mid-stage** victim, a MID hit (`s ≈ 0.5`, impulse
       ~1760) 45°-outward → arcs back and survives WITHOUT any counter (alive 3s, x inside bounds) in
       **≥7/10**; AND the SAME mid hit on a victim placed 900px from the near wall, with a scripted
       inbound counter-super within 0.30s of stun end → survives in **≥5/10** (skill extends the
       envelope).
    b. *Lethal committed center:* dead-center (`s ≥ 0.9`) 45°-outward smash, victim placed 900px from
       the near wall, starved to 4 fuel (no counter possible) → rings out ≤2.5s in **≥8/10**; AND the
       SAME hit on a full-fuel victim that fires NO counter → rings out in **≥7/10**.
27. **Self-super void kill preserved (path 1).** Deterministic: a player fires their OWN super
    straight up from mid/high stage → self-destructs off `top` (−1150) ≤2.5s in **≥8/10**.

**Aggregate — solidity distribution, the baseline floor, and the sting-as-executioner**
28. Across the idle-P1 sample (≥24 rounds):
    a. **Distribution exists (not all center):** `smashes[].solidity` spans a real range — ≥30% of
       landed smashes have `s < 0.5` (glances happen) AND ≥15% have `s ≥ 0.8` (solid hits happen). A
       degenerate all-1.0 or all-0 distribution FAILS.
    b. **Baseline floor holds (the v1-regression guard):** `min(smashes[].launch_speed) ≥ 1000` — NO
       zero/near-zero-launch smashes (the v1 gate produced ~0-launch hits; the fix must show a real
       floor across the whole sample).
    c. **Sting, not wall, kills:** of `smashes[]` with `starved == true`, **≥60%** are NOT survived;
       of those with victim fuel ≥ `super_boost_min_fuel` after, **≥40%** ARE survived (re-enter
       bounds within 3s). Both bands must hold.
    d. **Smashes are frequent again (THE regression this build fixes):** the sample records a **median
       ≥ 1.5 qualifying smashes per round** (v1 recorded ~1 per 13 rounds / ~2 per 8 rounds — an order
       of magnitude too few). Below ~1/round → the baseline is not landing; FAIL.
    e. **Recovery is attempted, not luck:** in ≥50% of surviving non-starved smashes the victim fired
       a recovery super within 1.0s of the smash `t`.

**Camera**
29. **Recovery stays on-screen (§6).** Deterministic: script a 45°-outward center smash carrying the
    victim to within 200px of a blast line; burst screenshots show the victim's blob AND that blast
    line both on-frame for the ENTIRE flight (**10/10** frames). Also: at the widest player spread in
    the aggregate sample, no living player is off-frame.

**Pacing guardrails that MUST NOT regress (re-run from parent §9, same targets)**
30. t10 kills carry ≥70% (`end_cause != laser`, `<20s`); t11 SD ≤25%; t12 median combat 10–22s;
    t13 L4 > L2 (0/5 L2 wins); t15a ≥2 off-stage kills/10. **This is the headline reconciliation:** at
    v2 (baseline 0.6 + bounds −900/2760/−1150 + sting-starve + self-super) the target is
    **≥70% kill-decided / ≤25% SD** — the baseline launch restores frequency (fixing the 17%/83%
    regression) while the pulled-back bounds keep near-wall kills live. If t10/t11 regress, apply the
    fence (§7) tightening order: `smash_launch_floor` UP → bounds tighter (toward −800/2660/−1100) →
    `smash_sting_fuel` UP (30→36). Never hitstun. If SD collapses < 10% / rounds one-shot / recovery
    never attempted (test 26a/28e fail), `smash_launch_floor` DOWN (→0.5) and/or bounds back toward
    −1000/2860.

---

## 10. New/changed constants — one block (implementation checklist)

```
# Tuning.gd — NEW (hit-solidity baseline+bonus, Lever A)
smash_launch_floor          = 0.6      # baseline fraction of the cap EVERY eligible smash launches
                                       #   (baseline impulse = 0.6 * 2200 = 1320). FIRST tuning knob.

# Tuning.gd — REMOVED (v1 gate, superseded)
smash_solidity_min          = <delete> # was 0.25 — no longer in the launch formula

# Tuning.gd — UNCHANGED but load-bearing here
smash_spin_max              = 12.0     # now applied prop. to (1 - s), not (1 - launch_scale)
smash_impulse_max           = 2200.0   # hard cap on impulse magnitude (DO-NOT-TOUCH)
smash_impulse_from_attacker = 1.1      # sets raw_impulse ceiling only; lower to 0.9 if too lethal, never up
smash_impulse_base          = 500.0
smash_sting_fuel            = 30.0     # full sting at s=1; scales down with s
smash_sting_min_impulse     = 1500.0   # sting gate (also keeps Star/Counter no-sting)

# Player.gd — _handle_smashes (both player ~619 and prop ~641 branches):
#   s            = clampf(velocity.normalized().dot((b.global_position - global_position).normalized()), 0, 1)
#   raw_impulse  = smash_impulse_base + my_speed * smash_impulse_from_attacker
#   launch_scale = smash_launch_floor + (1.0 - smash_launch_floor) * s
#   impulse_mag  = minf(raw_impulse, smash_impulse_max * launch_scale)      # baseline -> cap, never above physical
#   impulse      = velocity.normalized() * impulse_mag                      # direction unchanged
#   angular_kick = smash_spin_max * (1.0 - s) * signf(velocity.normalized().cross(n))   # -> victim spin (LESS solid = more spin)
# Player.gd — receive_smash: sting scales with SOLIDITY (pass s in), gated on impulse:
#   sting = smash_sting_fuel * s,  applied only when impulse_mag >= smash_sting_min_impulse
#   hitstun UNCHANGED (already reads impulse.length() = impulse_mag) — feed it the scaled impulse, touch no constant

# levels/dev_arena.json — bounds (supersedes §2.4 AND v1; pulled PARTWAY back from v1)
left  -620 -> -900 (was -1100) · right 2520 -> 2760 (was 3000) · top -950 -> -1150 (was -1200) · bottom unchanged

# CameraController / PartyMatch — §6 dependency (no Tuning constant):
#   CAM_MIN_ZOOM 0.42 -> ~0.37 (or targeted framing); keep knocked-alive players + approaching wall visible

# round_stats — §8 additions: smashes[] logged per ELIGIBLE hit (with solidity/launch_scale/launch_speed/
#   starved/spin/t), + t on kills[]/supers_fired[]. Frequency is the key regression guard (test 28d).

# DO-NOT-TOUCH: hitstun_base/per_impulse/max, smash_self_retain, max_speed, super_boost_impulse_full,
#   smash_impulse_max (2200), drain-all super, fuel_per_bounce/fuel_per_bumper, §2.3a dry-reflect,
#   no-power-scaling decision, no HP/damage-meter, no humanoid/damage-accum.
```
