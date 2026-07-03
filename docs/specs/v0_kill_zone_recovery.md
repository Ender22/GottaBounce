# Spec: v0 Kill Zone & the Recovery Gamble — hit-solidity, runway, and the failed-recovery death

> **v3 ADDENDUM (2026-07-03, owner directive `owner_2026-07-03_lives_damage_killrace.md`): see
> §12–§15 at the end of this file.** v3 (a) **REPLACES the compounding sting (§5.2) with the DAMAGE
> SYSTEM** (transient Lv1/Lv2 reeling state, red pulse, 8s heal, +33%/+66% launch multiplier), (b)
> makes lethality **edge-relative** and (c) makes **bounds level-relative** (derived from geometry, not
> the fixed §4 / §2.4 constants). The compounding-sting §5.2, the SD-rate rulings §11.1 / test 31, and
> the t10–t12 SD-pacing gates are **MOOT** — there is no timer SD any more; match structure moved to
> `docs/specs/v1_party_killrace.md`. The DO-NOT-TOUCH fence below is UNCHANGED and still governs. Read
> §12–§15 as the current combat-interior truth; the §3/§3.2 solidity model, §5.1 drain-all, and the
> runway *concept* (§4, now generalized to level-relative) all carry forward.
>
> **Owner:** Lead Game Designer. **Status:** READY FOR RE-BUILD+RE-QA. **v2.1 — 2026-07-03.**
> **This is an amendment to `docs/specs/v0_combat_lethality.md`.** It SUPERSEDES that spec's §2.1
> smash-impulse formula and §2.4 blast-zone bounds, and it EXTENDS §9 with new tests (22–33). It is
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
> **v2.1 REVISION (2026-07-03, post-QA of build 2b7363a — the SD-target ruling).** The v2
> baseline+bonus model was BUILT and the mechanic works (launch scales with solidity, never zero; a
> 45° solid smash arcs back alive; smoke sweep perfect). But the idle-P1 pacing aggregate would NOT
> converge to the ≤25% SD target: baseline(pre-rebalance) 28% SD / 72% kill / 14% suicide → v1
> gate0.25 83%/17% → gate0.1 50%/50% → **v2 floor0.6 53% SD / 47% kill / 39% suicide** → floor0.8
> 54%/46%/31%. Raising `smash_launch_floor` 0.6→0.8 moved SD 53%→54% (nothing) — **the
> launch-magnitude lever is REFUTED as a pacing fix (2 cycles, no movement).** FINDING (STATUS
> session 4): the recovery gamble (survivable knocks — the owner's explicit ask) STRUCTURALLY pins SD
> ~50% and the median round sits right on the 20s SD line. This is a genuine design TENSION, not a knob.
> **Three rulings (new §11), which SUPERSEDE the §9 t11/t30 ≤25% SD target and EXTEND §5 with a
> compounding sting:**
> 1. **RULING 1 — recalibrate ≤25% SD → ≤40% SD / ≥60% kill-decided** for the recovery-gamble model,
>    GATED by a new "SD rounds are active recovery climaxes, not stalls" QA check (§11.1, test 31).
> 2. **RULING 2 — the STING becomes the executioner via COMPOUNDING** (§5.2): a follow-up hit within a
>    short window bites much harder, converting "a second knock caught you mid-recovery" (path 3) into a
>    fast failed-recovery kill — WITHOUT deepening isolated-hit sting (the refuted `smash_sting_fuel`
>    30→40 experiment proved isolated depth-up DRAGS rounds). This is the lever that moves SD.
> 3. **RULING 3 — `kill_credit_window` (2.5s) is too short for the new arc lengths** (§11.2): a
>    failed-recovery kill takes >2.5s, so the launcher's credit expires and the earned kill is mis-logged
>    as a suicide (the inflated 31–39% unattributed). Credit now persists through the launch state.
> Rulings 1 and 3 are independent of the launch lever; ruling 2 is the mechanism that spends SD down
> toward the recalibrated line. **[v3: RULING 1 / test 31 / §5.2 compounding are MOOT — no timer SD.
> RULING 3 credit-persist CARRIES FORWARD. See §12.]**
>
> Sources: `docs/feedback/owner_2026-07-03_kill_zone.md` (feedback + diagnosis + the hit-solidity
> Addendum), `docs/feedback/owner_2026-07-02_movement_feel.md` (the thesis), `docs/STATUS.md`
> session-4 QA block (the regression that drove v2 + the SD gradient that drove v2.1), `src/core/Tuning.gd`,
> `src/entities/Player.gd` (`_handle_smashes`/`receive_smash`), `src/systems/CameraController.gd`,
> `src/modes/PartyMatch.gd`, `levels/dev_arena.json`.
>
> **DO-NOT-TOUCH (load-bearing for this fix):** §4.6 hitstun triad
> (`hitstun_base`/`hitstun_per_impulse`/`hitstun_max`), §2.3a bumper/tier DRY-REFLECT ("hitstun ends
> by TIME, never by touching a surface"), the drain-all super, `super_boost_impulse_full` (2800),
> `max_speed` (3000), the closed no-power-scaling decision, the `smash_impulse_max` cap (2200), no
> HP / damage-meter, no humanoid / damage-accum, `sudden_death_time` (20). See the fence (§7).

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
  flying" at the cap. Linear between. **[v3 §12: this baseline `impulse_mag` is then multiplied by
  the victim's damage-launch multiplier (×1.0/1.33/1.66) BEFORE the `max_speed` cap — the escalating
  lethality mechanism.]**
- **Sting (parent §2.2) scales with SOLIDITY directly** — NOT with `launch_scale` (whose floor would
  starve everyone). New rule: `sting = smash_sting_fuel * s`, applied only when
  `impulse_mag ≥ smash_sting_min_impulse` (1500). At `smash_launch_floor = 0.6` the baseline launch
  (~1320) sits *below* 1500, so a **graze stings nothing** (survivable, no secret starve-kill); the
  gate is crossed only around **s ≳ 0.21** (`impulse_mag ≥ 1500`), and from there sting rises with s.
  A moderate super hit (s=0.3) stings `30 × 0.3 = 9`; a dead-center super stings the full **30** → the
  sting-starve kill (path 2) is intact for *solid* hits, gone for glances. (Keeping the 1500 impulse
  gate also preserves the parent's weapon-type distinction — Star @900 / Counter @1400 still never
  sting, unchanged.) **v2.1: this ISOLATED-hit sting formula is UNCHANGED; a compounding multiplier is
  ADDED ON TOP for follow-up hits (§5.2) — that, not isolated depth, is the executioner. The
  single-knock gamble and the glances-sting-0 property are both left untouched. [v3 §12: the
  COMPOUNDING multiplier (§5.2) is REMOVED and REPLACED by the damage system; the ISOLATED sting
  `smash_sting_fuel * s` gated at 1500 STAYS unchanged — it is the fuel-starve half of the recovery
  gamble.]**
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
| **`smash_launch_floor`** (NEW) | **0.6** | Fraction of the cap that EVERY eligible smash launches regardless of solidity (baseline ≈ 1320 impulse). Set to 0.6 (not 0.5) to bias toward the failure we are fixing — too few kills / 83% SD — better to start slightly hot on kills and back off. This is the FIRST tuning knob: raise → 0.65/0.7 if kills stay rare; lower → 0.5/0.45 if rounds one-shot or recovery never happens. Kept below the sting gate (0.6×2200=1320 < 1500) so grazes don't starve. **v2.1 NOTE: two cycles proved this lever does NOT move SD (0.6→0.8 gave 53%→54%). It sets launch FEEL, not pacing; do not chase SD with it. Pacing is now the sting's job (§5.2).** |
| **`smash_solidity_min`** | **REMOVED** | v1 GATE constant. Superseded by `smash_launch_floor`. Delete the var (or leave dead + unreferenced); it no longer appears in the launch formula. |
| **`smash_spin_max`** | **12.0** (rad/s) | Full-graze tumble speed; now ∝ `(1 − s)`. Cosmetic-plus-readability; feel-only. |
| `smash_impulse_from_attacker` | **1.1** (already applied) | Coefficient sets only the physical `raw_impulse` ceiling; the cap governs above it. Lower to 0.9 if solid chains feel too lethal; never up. |
| `smash_impulse_base` | **unchanged** (500) | |
| `smash_impulse_max` | **unchanged** (2200) | Hard cap on `impulse_mag`; the dead-center ceiling. DO-NOT-TOUCH. |
| `smash_sting_fuel` | **unchanged** (30) | Full ISOLATED sting at s=1; scales down with s. **v2.1: do NOT raise to 40 (refuted — drags rounds). The compounding multiplier (§5.2) is what deepens sting on follow-ups. If still needed after §5.2, 30→36 is the ceiling.** |
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
**[v3 §14: these fixed per-arena bounds are SUPERSEDED by level-relative derivation — the margins in
§14 reproduce these exact dev_arena values, and generalize them to every level.]**

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
then bounds tighter, then sting. **v2.1 correction to that order: because launch-floor is refuted as a
pacing lever, the SD-tightening order is now sting-compound FIRST (§5.2), then bounds tighter, then
isolated `smash_sting_fuel` — never launch-floor for pacing (§11.1). [v3: pacing order is MOOT — no
timer SD. Bounds are now derived per §14.]**

---

## 5. Lever C (SECONDARY safety) — global impulse cap, + why the sting is the executioner

- **`smash_impulse_max` = 2200.0** (hard cap on `impulse_mag`, applied via `smash_impulse_max ×
  launch_scale` in §3.2, *before* the `max_speed` limit, in both the player and prop branches of
  `_handle_smashes`, ~lines 619/641). A perfect dead-center super is clamped to 2200 so even the best
  hit stays inside the runway math in §4. This is the ceiling; solidity shapes baseline→cap below it.
  **[v3 §12: the damage-launch multiplier is applied to `impulse_mag` AFTER this cap and is the ONLY
  sanctioned way to exceed 2200 — never above `max_speed` (3000), which still caps the final velocity.]**
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
`fuel_per_bounce`/`fuel_per_bumper` stay 20. **[v3: KEEPER — unchanged.]**

### 5.2 Lever C+ (v2.1, PRIMARY pacing lever) — the COMPOUNDING sting: the executioner that moves SD

> **[v3 SUPERSEDES §5.2 ENTIRELY. The compounding sting is REMOVED and replaced by the DAMAGE SYSTEM
> (§12). The `sting_compound_window/step/cap` constants and the `_sting_stack`/`_sting_window_timer`
> juggle-stack logic are deleted. The isolated sting `smash_sting_fuel * s` (gated at 1500) STAYS.
> The text below is retained for provenance only — it is no longer the mechanism.]**

**Why this exists (RULING 2).** The v2 finding is decisive: raising launch magnitude does NOTHING to
SD (0.6→0.8 floor gave 53%→54%), and the ISOLATED single-hit sting is deliberately survivable (that IS
the gamble). The kills that CLOSE rounds are failed recoveries, and the fastest, most-earned failed
recovery is **the second hit that lands while you are still scrambling from the first** (path 3, §1).
So the sting COMPOUNDS on follow-up hits — NOT on isolated ones:

```
# in receive_smash, ONLY for qualifying stings (impulse_mag >= smash_sting_min_impulse, i.e. NOT a graze):
if (round_clock - last_sting_time) <= sting_compound_window:
    compound_stack = min(compound_stack + 1, sting_compound_cap)
else:
    compound_stack = 0
sting = smash_sting_fuel * s * (1.0 + sting_compound_step * compound_stack)
last_sting_time = round_clock                # record for the next hit's window check
# a graze (below the 1500 gate) stings 0, does NOT update last_sting_time, does NOT advance the stack.
```

- **`sting_compound_window` = 1.5** (s). *(v3: removed.)*
- **`sting_compound_step` = 0.75**, **`sting_compound_cap` = 2**. *(v3: removed.)* At s=1 (solid):
  sting sequence **30 → 52.5 → 75**. The compound-stung victim was "the damaged body" the next slice
  would pulse red — **v3 makes that literal: the damage system replaces this stack with an explicit
  Lv1/Lv2 state.**

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
   is fine if it satisfies (1)+(2). **[v3 §14: with level-relative bounds, the camera must re-fit to
   each new level's derived bounds at STAGE_INTRO — already handled by re-reading `bounds`.]**
4. **Follow lag on a fast launch.** `follow_speed = 6.0` with fixed `margin = (420,340)` may let a
   fresh capped (2200) launch outrun the frame. Confirm it stays in-frame (raise `follow_speed`,
   widen the leading margin in the launch direction, or lead the velocity). **[v3: a Lv2 launch
   reaches `max_speed` (3000) — the camera must hold THAT, not just 2200. Re-verify at 3000.]**

NEW gameplay-programmer dependency; changes no Tuning feel constant. Ship bounds+impulse+camera
together, or the burst-screenshot tests (25/26/29) show recovery in a black off-screen void.

---

## 7. Fence — what NOT to do

- **Do NOT raise hitstun** (`hitstun_base`/`per_impulse`/`max`). §4.6 triad protected. If recovery
  fails too often: lower `smash_launch_floor` or `smash_impulse_from_attacker`, never hitstun.
- **Do NOT re-introduce super power scaling** (`docs/DECISIONS.md` 2026-07-02, closed).
- **Do NOT lower `super_boost_impulse_full` (2800) or `max_speed` (3000).** The self-super void kill
  (path 1) needs the 2800 self-super to out-rise the 2200 smash cap past the −1150 ceiling. **[v3: the
  damage multiplier may drive a Lv2 smash launch UP TO `max_speed`, never past it — the 3000 cap is the
  hard ceiling on all launches including damaged ones.]**
- **Do NOT re-introduce a launch GATE / zero-launch floor** (the v1 model). Every eligible smash MUST
  launch ≥ baseline; that is the whole v2 fix. `smash_launch_floor` never goes to 0.
- **Do NOT chase SD with the launch-floor** (v2.1: refuted, 2 cycles). *(v3: SD pacing is MOOT.)*
- **Do NOT lower `sudden_death_time`** *(v3: REMOVED — there is no timer SD.)*
- **Do NOT reopen §2.3a** (bumper/tier dry-reflect). Hitstun ends by TIME, never by touching a
  surface. MORE load-bearing now: wider bounds mean more bumper→wall gaps a stunned flier crosses.
- **Do NOT remove the drain-all super or add a cheap escape** (§5.1).
- **Do NOT add standable ground, health bars, air-brakes, or any camping affordance** (Pillars).
- **[v3] Do NOT make the damage state a persistent HP % or a HUD meter.** It is TRANSIENT, HEALS
  FULLY, is read ON THE BODY (red pulse), and caps at Lv2 (non-stacking beyond +66%). That is the
  agreed form (`docs/DECISIONS.md` 2026-07-03 transient-vulnerable-state).

### 7.1 Explicitly deferred / scoped-OUT (owner Addendum)

- **Taller / rectangular humanoid character with literal head/center/feet hit regions — NOT SPECCED.**
  It reopens the deliberate sphere-blob decisions (AI-generatability, circle-collider match). A
  SEPARATE gated art+collider bet, noted here as a **future option only**. The impact-parameter
  solidity in §3 delivers the head/center/feet *spectrum* on the current sphere with zero new art.
- **Smash-style persistent damage accumulation — SCOPED OUT.** Persistent-% HP is REJECTED (conflicts
  with no-HP identity, competes with fuel). **[v3: the transient Lv1/Lv2 damage state (§12) is now
  ADOPTED and specced — it is NOT persistent %; it heals fully in 8s and caps at Lv2.]**

---

## 8. Instrumentation — round_stats additions (programmer dependency)

To measure the solidity distribution and "survived a knock / attempted recovery," extend
`round_stats` (parent §8; read-only QA feeds, not feel constants):

- **`smashes[]`** (NEW), **one entry per ELIGIBLE `receive_smash`**: `{ t, attacker, victim, solidity,
  launch_scale, launch_speed (victim |velocity| the frame after), angle_deg, by_super, victim_fuel_after
  (post-sting), starved (victim_fuel_after < super_boost_min_fuel), spin }`. **[v3 §12: ADD
  `dmg_before` (victim damage_level pre-hit, 0/1/2), `dmg_after` (post-escalation), `launch_mult` (the
  1.0/1.33/1.66 applied). REMOVE `compound_stack` / `sting_applied` (compounding gone).]**
- **Add `t` (round_clock s)** to `kills[]` and `supers_fired[]`. **v2.1: also add `arc_time` to
  `kills[]`. [v3: ADD `victim_dmg_at_death` to `kills[]` — the damage level the victim died at.]**
- QA derived: a smash is **survived** if the victim is alive 2.5s later AND x inside `[left,right]`; a
  **recovery was attempted** if that victim has a `supers_fired[]` entry within 1.0s after the smash.

If instrumentation slips, the deterministic eval+burst-screenshot tests still gate the build.

---

## 9. Success criteria (additions to parent §9 — re-run the WHOLE of §9 too)

> **[v3: the PACING criteria (t10/t11/t12/t30/t31 SD-rate + active-climax) and the compounding-sting
> tests (32) are MOOT — no timer SD. The hit-solidity tests (22–29), self-super void kill (27), and
> the credit-attribution test (33, RULING 3) CARRY FORWARD. New v3 combat criteria are §15.]**

Harness as parent §9. "Deterministic case" = eval-placed idle victim, scripted single smash, burst
screenshots at 0.2s for 3s + eval of victim `is_dead()`, `global_position`, `fuel`, angular velocity.

**Hit-solidity (the baseline+bonus lever) — CARRY FORWARD**
22. **Solidity scales launch ABOVE A FLOOR (deterministic sweep).** s ≈ {1.0, 0.7, 0.4, 0.1} →
    `launch_speed` monotonic in s, never zero, matches `2200 × (0.6 + 0.4·s)` within ±10%.
23. **Glancing hits survivable everywhere; center hits can kill.** (a) glance s≈0.15 on full-fuel
    mid-stage → alive & in-bounds ≥9/10. (b) center s≥0.9 45°-outward, 800px from wall, 4 fuel →
    rings out ≤2.5s ≥8/10.
24. **Sting scales with solidity.** glance (s≈0.15) fuel −0 (±2); center (s≥0.9) fuel −≥27.

**The recovery gamble (kill paths) — CARRY FORWARD**
25. **Straight-up center smash arcs back.** full-fuel mid-stage, ±20° up → alive 3.0s AND apex below
    `top` ≥8/10.
26. **45°-outward recovery gamble.** (a) mid s≈0.5 mid-stage → survives no-counter ≥7/10. (b)
    center s≥0.9 900px-from-wall starved-to-4 → rings out ≤2.5s ≥8/10.
27. **Self-super void kill preserved (path 1).** own super straight up → self-destructs off `top`
    ≤2.5s ≥8/10.

*(Aggregate solidity-distribution 28, camera 29 — carry forward. Pacing 30/31, compounding 32 — MOOT.)*

33. **Kill attribution correct across the recovery arc (RULING 3 — CARRY FORWARD).** a solid smash
    launches a starved victim who rings out at `arc_time ≈ 3–4s` → credited to the LAUNCHER ≥9/10;
    aggregate unattributed kills ≤18%.

---

## 10. New/changed constants — one block (implementation checklist)

```
# Tuning.gd — NEW (hit-solidity baseline+bonus, Lever A) — CARRY FORWARD
smash_launch_floor          = 0.6

# Tuning.gd — v2.1 compounding sting — [v3: REMOVED, replaced by damage system §12]
sting_compound_window, sting_compound_step, sting_compound_cap   # DELETE

# Tuning.gd — CHANGED (RULING 3 credit fix) — CARRY FORWARD
kill_credit_window          = 4.0    # persist through launch state preferred; cap kill_credit_window_max = 6.0

# Tuning.gd — REMOVED
smash_solidity_min          = <delete>

# Tuning.gd — UNCHANGED but load-bearing
smash_spin_max=12.0 · smash_impulse_max=2200 · smash_impulse_from_attacker=1.1 · smash_impulse_base=500
smash_sting_fuel=30 (isolated s-scaled sting STAYS) · smash_sting_min_impulse=1500

# Player.gd — _handle_smashes: s / raw_impulse / launch_scale / impulse_mag as §3.2
#   [v3 §12: impulse_mag *= b.damage_launch_mult()  AFTER the smash_impulse_max clamp, BEFORE max_speed]
# Player.gd — receive_smash: isolated sting smash_sting_fuel*s gated at 1500 (NO compounding)
#   [v3 §12: escalate victim damage_level + reset 8s heal on qualifying hits (impulse >= 1500)]

# levels/dev_arena.json — bounds  [v3 §14: DERIVED from geometry; explicit bounds becomes an override]

# DO-NOT-TOUCH: hitstun_base/per_impulse/max, smash_self_retain, max_speed, super_boost_impulse_full,
#   smash_impulse_max (2200), drain-all super, fuel_per_bounce/fuel_per_bumper, §2.3a dry-reflect,
#   no-power-scaling, no HP/damage-meter, no humanoid/damage-accum.
```

---

## 11. v2.1 RULINGS — the SD target, and the credit-window scoring fix

> **[v3: RULING 1 (SD ≤40% recalibration) and its gate test 31 are MOOT — the timer SD is removed
> (`v1_party_killrace.md` §5). RULING 3 (credit persists through the launch state) CARRIES FORWARD —
> it is still the correct scoring shape for a failed-recovery kill in the kill-race, and t33 still
> gates it. RULING 2 (compounding sting) is SUPERSEDED by the damage system (§12).]**

*(§11.1 / §11.2 text retained above in the header changelog + §5.2 for provenance; only RULING 3's
credit-persist mechanism remains in force.)*

---

## 12. v3 — THE DAMAGE SYSTEM (replaces the compounding sting)

**Player fantasy:** you land a hit and your rival flashes red and *reels* — now they are fragile, and
the clock is on. Chase them down and the next hit sends them screaming off the edge; let them run and
in a few seconds they shrug it off and it is a fair fight again. You, freshly hit, are the one
fleeing — bounce, aim, buy time, heal. This is the flee/chase dynamic, and it is the escalating
lethality that makes "nothing kills" become "hitting a wounded rival kills."

### 12.1 State model (on `Player`)

- **`damage_level: int`** ∈ {0 (healthy), 1 (Lv1 reeling), 2 (Lv2 reeling)}. Starts 0; reset to 0 on
  `respawn()` (add to the respawn clear-block alongside the sting-stack removal).
- **`_dmg_heal_t: float`** — heal countdown. When > 0 it ticks down each physics frame; at ≤0 with
  `damage_level > 0`, drop `damage_level` straight to **0** (full heal — non-stacking, no partial
  step-down; the transient-state decision requires it heal FULLY).

### 12.2 Escalation — driven by qualifying smashes (in `receive_smash`)

Gate on the **same `impulse.length() >= smash_sting_min_impulse` (1500) qualifying condition as the
isolated sting** — a graze does NOT escalate damage (keeps glances pure scares; fence "glances/gamble
intact"). On a qualifying hit, AFTER applying the isolated sting:

```
if impulse.length() >= smash_sting_min_impulse and not invincible and _spawn_protect <= 0.0:
    if damage_level == 0:      damage_level = 1        # first hit: heal-arm at 8s, slow pulse
    elif damage_level == 1:    damage_level = 2        # hit while Lv1: escalate, fast pulse
    # (damage_level == 2 stays 2)
    _dmg_heal_t = dmg_heal_time                         # ANY qualifying hit re-arms the full 8s
```

- **Order matters (see 12.3):** the launch MULTIPLIER is read from the victim's **pre-hit**
  `damage_level` (computed in `_handle_smashes` BEFORE `receive_smash` runs), so the hit that *takes
  you to* Lv1 launches at ×1.0, and the hit you receive *while at* Lv1 launches at ×1.33. This is the
  directive's reading: "Lv1 → +33% launch" = while you are Lv1, hits on you fly +33% further.
- Star `invincible` / `_spawn_protect` early-outs already return before this point → no escalation
  (consistent with sting). SD-revived players are seeded `damage_level = 2` directly (killrace §5).

### 12.3 The launch multiplier — WHERE it goes in the formula (precise)

In `_handle_smashes`, the victim `b`'s pre-hit damage level scales `impulse_mag` **after** the
`smash_impulse_max` clamp and **before** `receive_smash` applies the `max_speed` limit:

```
# ... existing §3.2 lines ...
impulse_mag = minf(raw_impulse, smash_impulse_max * launch_scale)   # baseline -> 2200 cap (UNCHANGED)
impulse_mag *= b.damage_launch_mult()                               # v3: ×1.0 / ×1.33 / ×1.66 (pre-hit dmg)
impulse      = vdir * impulse_mag
b.receive_smash(impulse, self, s, angular_kick)                     # applies .limit_length(max_speed=3000)
```

with `func damage_launch_mult() -> float: return Tuning.dmg_launch_mult[damage_level]` and
**`dmg_launch_mult = [1.0, 1.33, 1.66]`**.

**Why here, and why it is fence-safe:**
- The base `impulse_mag` is capped at `smash_impulse_max` (2200) FIRST — solidity still shapes
  baseline→2200. The damage multiplier is the **only** sanctioned exceedance of 2200, and it is
  still hard-capped by `max_speed` (3000) on the victim's velocity. So `max_speed` and
  `smash_impulse_max` are BOTH untouched as constants; the damage state is what unlocks the headroom
  between them.
- Worked numbers (victim near rest, center hit, `impulse_mag` = 2200 before the mult):
  - **Lv0:** 2200 → exit ~2200 px/s. Arcs back from mid-stage (recovery gamble intact — the §4/§14
    runway math is exactly the validated Lv0 case).
  - **Lv1:** 2200 × 1.33 = 2926 → exit ~2926 px/s. Flies ~33% farther → from mid-stage it now
    *reaches* the near-edge band a fresh hit would not; near-edge it rings out.
  - **Lv2:** 2200 × 1.66 = 3652 → `limit_length(3000)` → exit **3000 px/s (capped)**. The maximum
    launch in the game; a near-edge or even mid-stage Lv2 victim rings out unless they still have a
    fast fuelled counter. This is the "finish the wounded" payoff.
- **Hitstun stays capped, triad untouched:** hitstun reads `impulse.length()`. A Lv2 impulse (up to
  3652) feeds the UNCHANGED formula `min(base + impulse·per_impulse, hitstun_max=0.55)` — center hits
  are already at the 0.55 cap, so damage nudges only sub-max hits up toward 0.55 and never past it. No
  hitstun CONSTANT changes; the §4.6 triad is intact. (State this in QA: hitstun ≤ 0.55 always.)
- Lower-solidity hits scale identically: a mid s=0.5 hit (impulse ~1760) on a Lv1 victim → 1760×1.33 =
  2341 → exit ~2341. So the multiplier composes cleanly with the whole solidity spectrum.
- **Scope:** the multiplier is applied ONLY in the two SMASH branches of `_handle_smashes` (player +
  prop). Powerup-specific launches (Star contact 900, Counter reflect 1400, explosion) keep their
  current behavior — they are below the 1500 gate anyway (no escalation) and are separate balance;
  amplifying them by damage is out of scope (consistent, tight). Escalation itself lives in
  `receive_smash` gated at 1500, so Star/Counter also never *cause* escalation.

### 12.4 The red-pulse visual (readability > prettiness; on the body, not a HUD meter)

Reuse the `self_modulate` chain in `Player`'s process (currently: flash > rainbow > silhouette >
white). Insert the damage pulse **below flash, above the powerup tints**? No — the Star rainbow means
`invincible` (can't be damaged) and Black-Hole silhouette is a channeler; both are rare and dominant
identity states. Priority: **hit-flash (0.12s) > Star rainbow > Black-Hole silhouette > DAMAGE PULSE >
white.** A damaged player normally shows the pulse; it only yields to those rare powerup states.

- **Lv1 — slow pulse:** `self_modulate = Color(1.0, g, g)` where `g` oscillates **0.85 ↔ 0.55** at
  **`dmg_pulse_slow_hz = 1.5`** Hz. A gentle, unmistakable "reeling" throb toward pink-red.
- **Lv2 — fast pulse:** `g` oscillates **0.75 ↔ 0.30** (deeper red) at **`dmg_pulse_fast_hz = 4.0`**
  Hz. Reads instantly as "this one is about to die."
- Must be legible at `CAM_MIN_ZOOM` (0.37) — a whole-body tint is (a small HUD bar would not be); this
  is why the state lives on the body. No new node; drive `g` from `_anim_t` like the rainbow line.

### 12.5 Reset / heal rules

- Heal fully (→0) after `dmg_heal_time = 8.0` s with no qualifying hit. Any qualifying hit re-arms the
  full 8s (both Lv1→Lv2 and a re-hit at Lv2). Directive: "heals after 8s; a hit while Lv1 resets the
  heal timer to 8s."
- Death / respawn → 0. Stage start → 0 (respawn covers it). SD revive → seeded to 2 (killrace §5).
- Shoves, bounces, powerup pickups, healing over time — none affect it except the timer. The base
  fuel-sting still fires independently on qualifying hits (it is the fuel-starve half of the gamble;
  damage is the launch-distance half).
- **Non-stacking guarantee:** `damage_level` never exceeds 2; there is no Lv3. This is the fence
  against the rejected persistent-HP model.

### 12.6 Interaction with the sting, credit, and the recovery gamble (unchanged pieces)

- **Isolated fuel-sting KEPT** (`smash_sting_fuel * s`, gated 1500). Sting starves the escape super;
  damage multiplies the launch. A solid hit on a Lv1 mid-tank victim both starves them AND launches
  them +33% → the failed-recovery kill, now with an explicit escalation the player can READ and race
  against (the 8s). This is the directive's "escalating lethality."
- **Glances (below 1500) neither sting nor escalate** — still pure scares (fence intact).
- **Kill credit / drain-all super / §2.3a dry-reflect — all unchanged.** A damaged player who fires a
  fuelled counter can still fly back (the gamble); a *starved* damaged player cannot (the kill).

---

## 13. v3 — EDGE-RELATIVE LETHALITY (emergent, not a new coded check)

The directive's "a dead-on hit near the edge kills; the same hit mid-stage does not; damaged players
fly further → out; fuelled players fly back" is **already how the physics resolve** — it is the
consequence of (launch speed × hitstun, minus fuelled recovery) vs (distance to the blast line). **It
is NOT a separate mechanic and must not be coded as one** (no "if near edge, kill" special case). The
damage multiplier (§12) and solidity (§3) set the launch; the runway (§14) sets the distance; whoever
runs out of runway before regaining control dies. The programmer owns making the physics land; the
design contract is the outcome rates in §15.

**"Near the edge" — the definition (a DESIGN/QA reference band, not a constant):**

```
edge_band_width(dmg) ≈ exit_speed(dmg) × hitstun_max − fuelled_recovery_reach
```

the distance from a blast line within which a **center** hit outward rings the victim out before they
can recover. Approximate reference values on dev_arena geometry (for QA test placement, not code):

| victim state | exit_speed (center) | ~band width (no counter) | reading |
|---|---|---|---|
| Lv0 healthy, full fuel | ~2200 | ~700–900 px | must arc back from mid-stage |
| Lv0 healthy, starved | ~2200 | ~1100 px | sting-starve kill near/inside the band |
| Lv1 reeling | ~2926 | ~1100–1300 px | "hit a damaged player → out" reaches deeper inward |
| Lv2 reeling | ~3000 (cap) | ~1300–1500 px | near-edge = dead; even mid-stage is dangerous |

- **Mid-stage** (victim > band from the nearest blast line) + Lv0 + fuelled = arcs back / flies back
  (the DEFAULT non-kill outcome the directive wants).
- **Near-edge** (within the band) OR **damaged** OR **starved** = the launch exceeds the recoverable
  reach → out. "Most kills = hit-a-damaged-player OR dead-on-near-edge" falls out of this directly.
- The band SCALES with the level because the runway does (§14) — a wide level has a wider recoverable
  reach, so the near-edge band sits proportionally further out.

QA measures the kill/survive boundary at fixed test positions (§15) rather than asserting the band
width; the band table above is the design intent those tests confirm.

---

## 14. v3 — LEVEL-RELATIVE BOUNDS (derived from geometry, not per-arena constants)

Bounds are **derived in `LevelLoader.load_level`** from `play_rect` (the merged AABB of all
platforms — the walkable extent, already computed) plus Tuning margins. Horizontally-long levels get
horizontally-further blast lines (directive §6): the side margin scales with walkable width.

```
walkable = play_rect                                                   # merged platform AABB
side     = clamp(bounds_side_frac * walkable.size.x, bounds_side_min, bounds_side_max)
bounds.left   = walkable.position.x - side
bounds.right  = walkable.end.x      + side
bounds.top    = walkable.position.y - bounds_top_margin
bounds.bottom = walkable.end.y      + bounds_bottom_margin
```

**Constants (NEW, Tuning) — chosen to REPRODUCE dev_arena's validated v2 bounds so slice B changes
nothing on the tuned level:**

| Constant | Value | Rationale / dev_arena check |
|---|---|---|
| `bounds_side_frac` | **0.52** | fraction of walkable width per side. dev_arena walkable width = 1856−64 = **1792** → side = 0.52×1792 = **932** ≈ the validated ~904–964 runway. Scales the side kill zone with level length (directive §6). |
| `bounds_side_min` | **700.0** | floor so a short level is not un-survivably tight (a tiny level would otherwise kill on any knock). |
| `bounds_side_max` | **1400.0** | cap so a very long level's runway does not exceed camera/recovery sanity. |
| `bounds_top_margin` | **1700.0** | fixed vertical headroom (super/spring physics, NOT width-dependent). dev_arena walkable top y = 540 → top = 540 − 1700 = **−1160 ≈ −1150** (self-super void kill + 2200-arc-back both preserved, §4). |
| `bounds_bottom_margin` | **670.0** | dev_arena walkable bottom y = 1108 → bottom = 1108 + 670 = **1778 ≈ 1780**. Floor ring-outs stay rare. |

- **Derivation is the DEFAULT.** An explicit `bounds` block in level JSON is now an **optional
  override** (back-compat for hand-tuned levels like dev_arena). Recommendation: **new levels OMIT
  `bounds`** and rely on derivation; dev_arena may keep or drop its explicit block (the derived values
  match within ~10px either way). `LevelLoader` returns derived bounds unless an override is present.
- Side scaling is per-side symmetric off the walkable AABB; asymmetric levels get asymmetric runways
  automatically (a platform cluster hugging the left gets a longer left runway — correct).
- Vertical margins are fixed (not width-scaled) because the vertical kill geometry is governed by the
  super/spring launch physics, which do not change with level width. If a level has an unusually high
  or low platform, `play_rect` tracks it and the top/bottom bounds move with the geometry — desired.
- Camera (§6) re-reads `bounds` at each STAGE_INTRO (killrace §6) and re-fits — no per-arena camera
  constant.

---

## 15. v3 — Success criteria (combat interior; supersedes the MOOT pacing tests)

Harness: deterministic eval placement + burst screenshots + eval of `is_dead()`, `global_position`,
`fuel`, `damage_level`, `_dmg_heal_t`. Aggregate = idle-P1, ≥24 stages, reading `smashes[]` (with v3
`dmg_before`/`dmg_after`/`launch_mult`).

**Damage state — trigger & heal (deterministic)**
D1. **Escalation ladder:** a qualifying smash (impulse ≥ 1500) on a healthy victim → `damage_level==1`,
    slow pulse visible (screenshot), `_dmg_heal_t ≈ 8` (±0.2). A second qualifying smash within 8s →
    `damage_level==2`, fast pulse, `_dmg_heal_t` reset to ≈8. A third qualifying smash → stays 2,
    timer re-armed. A glance (impulse < 1500) → `damage_level` unchanged (no escalation).
D2. **Full heal:** after a hit, wait 8.0s with no further qualifying hit → `damage_level==0`, pulse
    gone (screenshot). No partial step-down (never 2→1); it drops straight to 0.
D3. **Reset on death/respawn/SD:** killed → respawn → `damage_level==0`. SD-revived players →
    `damage_level==2` with fast pulse (killrace §5, cross-check).

**Launch multiplier (deterministic sweep)**
D4. **Multiplier magnitudes:** same scripted center super (base `impulse_mag`≈2200) into a victim at
    Lv0 / Lv1 / Lv2 → exit `launch_speed` ≈ **2200 / 2926 / 3000** (Lv2 capped by `max_speed`), within
    ±8%. `smashes[].launch_mult` reads 1.0 / 1.33 / 1.66 respectively. Hitstun ≤ 0.55 in ALL cases
    (triad intact — eval `_stun_timer` never exceeds `hitstun_max`).
D5. **Pre-hit read:** the hit that TAKES a healthy victim to Lv1 records `launch_mult==1.0` and
    `dmg_before==0`/`dmg_after==1`; the next hit records `launch_mult==1.33`/`dmg_before==1`.

**Edge-relative kill economy (deterministic + rates) — the directive §5 claims**
D6. **Mid-stage healthy survives; near-edge / damaged dies:**
    a. **T-mid:** Lv0 full-fuel victim at stage center, center hit outward, no counter → survives
       (alive 3s, in-bounds) **≥8/10**.
    b. **T-edge:** Lv0 victim placed ~150px inside the near walkable edge (inside the §13 band),
       center hit outward, starved to 4 fuel → rings out ≤2.5s **≥8/10**; same at full fuel, no
       counter → rings out **≥6/10**.
    c. **T-dmg-mid (the headline):** Lv1 full-fuel victim at stage CENTER, center hit outward, no
       counter → rings out **≥5/10** — versus T-mid's ≤2/10 for Lv0. Proves "hit a damaged player →
       they fly further → out" from mid-stage.
    d. **T-dmg2:** Lv2 victim, center hit from ~mid-inner stage → rings out **≥8/10**.
    e. **T-fly-back (gamble preserved):** T-edge full-fuel victim WITH a scripted snap counter-super
       within 0.3s of stun end, aimed inward → survives **≥4/10** (fuelled fly-back is still real).
D7. **Self-super void kill preserved:** own super straight up → self-destructs off `top` ≤2.5s ≥8/10
    (parent t27 — must still hold under level-relative top bound).

**Aggregate (≥24 idle-P1 stages)**
D8. **Kill economy composition:** of credited kills, **≥50%** have the victim at `damage_level ≥ 1`
    at death (`kills[].victim_dmg_at_death`) OR occurred with the victim inside the §13 near-edge band
    — i.e. most kills are "damaged OR near-edge," the directive's intended economy. Purely-mid-stage-
    healthy kills are the minority.
D9. **Damage churns, not sticks:** median time-at-`damage_level>0` per damaged player per stage is a
    real but transient window (players do reach Lv0 again via the 8s heal within stages that run long
    enough) — no player is pinned at Lv2 for an entire stage by design; and no Lv3 ever appears.
D10. **Attribution (RULING 3 carry-forward):** unattributed kills ≤18%; a 3–4s failed-recovery arc
     credits the launcher ≥9/10 (parent t33).

**Level-relative bounds**
D11. **Derivation reproduces dev_arena:** on dev_arena, derived `bounds` = left≈−900, right≈2760,
     top≈−1150, bottom≈1780 (±15px) via eval, whether or not the JSON override is present.
D12. **Scaling:** on a synthetic wide level (walkable width ~2600) the side runway is wider
     (0.52×2600 = 1352, clamped ≤1400) and on a narrow one (~1000) it clamps to 700 — eval `bounds`
     confirms the side margin tracks walkable width between the min/max clamps. Camera keeps all
     living players + the approaching wall on-frame at the new bounds (parent t29 at the new geometry).

**Readability & performance**
D13. **Pulse reads at zoom-out:** at `CAM_MIN_ZOOM`, a screenshot of a Lv1 and a Lv2 player shows a
     distinguishable slow vs fast red throb (burst of 4 frames over ~0.7s shows the phase difference);
     no HP bar / meter anywhere. Hit-flash still overrides the pulse for its 0.12s.
D14. **No laser/timer pixels** anywhere in combat (removed with the timer SD).
