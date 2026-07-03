# Spec: v0 Kill Zone & the Recovery Gamble — hit-solidity, runway, and the failed-recovery death

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD+TUNE. **v1 — 2026-07-03.**
> **This is an amendment to `docs/specs/v0_combat_lethality.md`.** It SUPERSEDES that spec's §2.1
> smash-impulse formula and §2.4 blast-zone bounds, and it EXTENDS §9 with new tests (22–30). It is
> a standalone file (the parent spec has no §2.5 slot and is not being rewritten in place); read it
> as the parent's §2.5. **It HOLDS v0 lethality sign-off** — the 29-round v2.1 QA was measured
> against geometry the owner says is wrong (`docs/feedback/owner_2026-07-03_kill_zone.md`), so
> re-run the FULL §9 plus the tests here after this build.
>
> Sources: `docs/feedback/owner_2026-07-03_kill_zone.md` (feedback + diagnosis + the hit-solidity
> Addendum), `docs/feedback/owner_2026-07-02_movement_feel.md` (the thesis), `docs/VISION.md`
> pillars, `src/core/Tuning.gd`, `src/entities/Player.gd` (`_handle_smashes`/`receive_smash`),
> `src/systems/CameraController.gd`, `src/modes/PartyMatch.gd`, `levels/dev_arena.json`.
>
> **DO-NOT-TOUCH (load-bearing for this fix):** §4.6 hitstun triad
> (`hitstun_base`/`hitstun_per_impulse`/`hitstun_max`), §2.3a bumper/tier DRY-REFLECT ("hitstun ends
> by TIME, never by touching a surface"), the drain-all super, `super_boost_impulse_full` (2800),
> `max_speed` (3000), the closed no-power-scaling decision. See the fence (§7).

---

## 1. The kill model (in words — the target feel)

The lethal tool is the SMASH (a fired super, or a licensed flying stunned body — parent §2.1). A
smash should launch the victim on a **readable arc whose length is set by how solidly you hit them**,
not delete them at the wall. From that launch there are exactly two ways to die, and both are
*earned*:

1. **The clean super into the void.** You aim your OWN super off the top or out a side with no
   runway left and self-destruct — full-power `super_boost_impulse_full` (2800) on yourself, the
   commitment gag (Pillars 3/4). This kill must stay.
2. **The failed recovery.** You get smashed *solidly*, arc out toward a blast line, and *try to fly
   back* — and fail because (a) the sting starved your tank below `super_boost_min_fuel` so you have
   **no escape super**, (b) you snap-aimed the counter too slow / in a bad direction, or (c) a
   **second hit** caught you mid-recovery. The death is a story about a botched comeback.

Everything else is a **scare, not a death**:

- A **glancing** smash (clipped head/feet, off-center) spins the victim and barely launches them —
  it arcs back into the fight from anywhere on the stage. Glancing hits essentially never kill.
- A **dead-center** smash launches at full impulse. It is lethal *when aimed into a void or when it
  starves the victim*; a center hit straight up from mid-stage still arcs back down (short of the
  ceiling — §4). So "center = the hit that CAN kill," not "center = always kills."
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

The fix is NOT to revert bounds. It is to (A) make launch scale with **hit solidity** so most hits
are survivable spins and only well-placed hits fly far, (B) give a modestly-widened **runway** so the
arc fits, (C) keep a **global impulse cap** only as a safety ceiling, and let the **sting** (fuel
starve) — not the wall — be the executioner. Solidity + runway + starve-to-kill reconciles both
feedbacks: bounds widen, but the kill rate is held by placement and starvation, not wall proximity.

---

## 3. Lever A (PRIMARY) — HIT SOLIDITY

Owner Addendum: *"How solidly you hit scales launch. Dead-center → flying (a kill). Glancing
head/feet → spin (torque) without launching far (a survivable knock that arcs back). Build it on the
CURRENT sphere collider via the impact parameter."*

### 3.1 The solidity value (computable on the current sphere collider — no new geometry)

In `_handle_smashes`, attacker is `self`, victim is `b`. Both are circle colliders, so the
line-of-centers IS the contact normal:

```
n            = (b.global_position - global_position).normalized()   # contact normal, attacker→victim
vdir         = velocity.normalized()                                # attacker's travel direction
solidity s   = clampf(vdir.dot(n), 0.0, 1.0)                         # 1.0 = dead-on center, 0 = pure graze
```

`s = 1.0` means the attacker is driving straight through the victim's center (head-on); `s → 0` means
the attacker is skimming the victim's edge (a clipped head/feet graze). This is exactly the classic
circle-collision **impact parameter**, and it needs nothing but the sphere colliders we already have.

### 3.2 Solidity scales the launch, the sting, and the spin

```
raw_impulse   = smash_impulse_base + my_speed * smash_impulse_from_attacker   # as today, coeff lowered (§5)
launch_scale  = clampf((s - smash_solidity_min) / (1.0 - smash_solidity_min), 0.0, 1.0)
impulse_mag   = minf(raw_impulse * launch_scale, smash_impulse_max)           # Lever C cap is the ceiling
impulse       = velocity.normalized() * impulse_mag                           # launch dir unchanged (along travel)
# spin: the momentum NOT spent launching becomes torque — the comedic tumble that reads "you got clipped"
spin_sign     = signf(vdir.cross(n))                                          # which way the clip spins them
angular_kick  = smash_spin_max * (1.0 - launch_scale) * spin_sign             # rad/s, applied to the victim sprite
```

- **Launch:** at `s ≤ smash_solidity_min` the launch is **0** (a pure SHOVE-equivalent + spin — the
  victim keeps control, arcs nowhere); at `s = 1.0` it is the full raw impulse (capped by Lever C).
  Linear between. So a 45°-off clip (`s ≈ 0.7`) launches at `(0.7−0.25)/0.75 = 0.60×`; a bad graze
  (`s ≈ 0.4`) at `0.20×`; a center hit at `1.0×`.
- **Sting (parent §2.2) scales with `launch_scale` too** — otherwise a graze would starve the tank
  (−30 fuel) and secretly kill via path 2, contradicting "glancing = survivable." New rule:
  `sting = smash_sting_fuel * launch_scale`, applied only when `impulse_mag ≥ smash_sting_min_impulse`
  (a graze whose launch is small also stings little/none). A dead-center super still stings the full
  30 → the sting-starve kill (path 2) is intact for *solid* hits, gone for glances.
- **Hitstun is UNCHANGED and needs no new constant:** it already reads `impulse.length()`
  (parent §2.1, `Player.receive_smash` line ~703). Feed it the solidity-scaled `impulse_mag` and a
  graze naturally produces short hitstun (base 0.15 → victim recovers fast), a center hit long
  hitstun. We do NOT touch `hitstun_*` — we just stop feeding it a capped-out impulse on every hit.
- **Spin/torque:** `angular_kick` rotates the victim's sprite (squash/stretch tumble). This is the
  *readability signal* that says "that was a glance, they're fine" vs "that was solid, they're gone."
  Decays over the hitstun window. See §6 (programmer feasibility: victim visual must be able to
  rotate; if the CharacterBody's sprite node can't spin, this is a small dependency, not a blocker —
  ship launch-solidity first, spin as a fast-follow if the sprite pivot needs work).

### 3.3 New constants (Tuning.gd)

| Constant | Value | Rationale |
|---|---|---|
| **`smash_solidity_min`** | **0.25** | Below this impact parameter the hit launches nothing (pure spin+shove). Widens/narrows the survivable band: LOWER it (→0.1) if kills get too rare — this is the FIRST tuning knob, before bounds or sting. |
| **`smash_spin_max`** | **12.0** (rad/s) | Full-graze tumble speed; ∝ `(1−launch_scale)`. Cosmetic-plus-readability; tune to taste, feel-only. |
| `smash_impulse_from_attacker` | 1.35 → **1.1** | Coefficient no longer sets the ceiling (Lever C does); lowered to reduce end-of-window graze randomness and give a real gradient below the cap. First knob DOWN to 0.9 if solid chains feel too lethal; never up. |
| `smash_impulse_base` | **unchanged** (500) | |

### 3.4 Why solidity is the *primary* lever (not just the cap)

A flat cap alone (Lever C) makes every clean hit identical at 2200 — survivable-or-not becomes purely
about the victim's fuel/angle, with zero attacker skill expression. Solidity restores the **skill
spectrum the recovery gamble needs**: a good player *aims for the center* to convert a hit into a
kill; a rushed or badly-angled attacker only clips and gets a spin. That is Pillar 1 (low floor,
high ceiling) expressed in the kill itself, and it is what the owner asked to be the main mechanism.

---

## 4. Lever B — the runway (bounds; `levels/dev_arena.json`, supersedes §2.4's bounds row)

Platform spans x∈[64,1856]; "runway" = distance from platform edge to blast line. Sizing target: a
**dead-center** capped smash (worst case, 2200) must have room to arc, so the runway is the safety
math even though most hits launch far shorter.

| Bound | §2.4 | §2.5 (this spec) | Rationale |
|---|---|---|---|
| `left` | −620 | **−1100** | ~1164px runway. A 45°-outward capped-center smash burns ~856px during the 0.55s hitstun (horizontal component 1556×0.55); a fueled victim who snap-counters at stun-end (~+290px) still has ~150px to reverse inbound → **survivable, barely**. A starved (no-counter) victim crosses at ~1150/1556 ≈ 0.74s → rings out. Glancing hits arc back from anywhere. |
| `right` | 2520 | **3000** | Symmetric (~1144px runway from x=1856). |
| `top` | −950 | **−1200** | Sits between the smash apex and the self-super apex. Straight-up *capped-center* smash from mid-stage (y≈700): apex y≈−812 → **clears −1200, arcs back**. From the high spring platform (y≈380): apex ≈−1132 → still clears. A *self-fired* vertical super (2800): apex ≈−1750 → **exceeds −1200 → self-destruct void kill preserved** (kill path 1). The −1200/−812 gap gives ±≥380px robustness. |
| `bottom` | 1780 | **unchanged** | Floor spans the stage. |

These sides are ~150px wider than the pre-§2.4 era (−1000/2900); deliberate, and only safe because
solidity governs most launches and the sting governs lethality (§5). Laser walls spawn at the new
bounds (parent §5). If too wide, tighten order is in the fence (§7): bounds BEFORE sting.

---

## 5. Lever C (SECONDARY safety) — global impulse cap, + why the sting is the executioner

- **`smash_impulse_max` = 2200.0** (NEW hard cap on `impulse_mag`, applied *after* solidity scaling
  and *before* the `max_speed` limit, in both the player and prop branches of `_handle_smashes`,
  ~lines 619/641). A perfect dead-center super (`raw ≈ 3250 × 1.0`) is clamped to 2200 so even the
  best hit stays inside the runway math in §4. This is a ceiling, not the spectrum — solidity does
  the shaping below it.
- **The sting is the kill-rate backstop, not the wall.** With solidity+cap+runway, a *fueled* victim
  usually survives a single smash. Kills stay frequent because a **solid** hit stings the full 30
  fuel (§3.2) → a mid-tank victim (≤34) is starved below `super_boost_min_fuel` (5) → **no counter
  exists** → the capped launch still carries them out and they ring out on a clean arc. Wider walls,
  but the kill rate is held by *starvation on solid hits*, not wall proximity. If kills go too rare
  after this build, first knob is `smash_solidity_min` down, then `smash_sting_fuel` 30→40 — NEVER
  hitstun, NEVER power scaling (§7).

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
knocked-but-alive player out there, the whole gamble happens **off-screen** and the fix is invisible.
Requirements (verify in test 29):

1. **Follow knocked-but-alive players.** `_update_camera` already frames all `not p.is_dead()`
   players — confirm a player in hitstun / mid-recovery (alive, `_dead == false`) is NOT excluded. A
   stunned flier must stay framed until they recover or ring out.
2. **Keep the approaching blast line on-screen.** During a recovery arc, both the launched blob AND
   the blast line it heads toward must be visible so the player can read "how much runway is left."
3. **Zoom-out headroom.** New bounds span 4100px wide × 2980px tall. A corner-to-corner spread needs
   ~0.36 zoom; current `CAM_MIN_ZOOM = 0.42` (max visible 4571×2571px) cannot show the full vertical
   extent. Programmer's call: (a) lower `CAM_MIN_ZOOM` to ~0.36 and verify blob readability at that
   scale (Pillar 5 — if blobs shrink too far, the fix trades one readability problem for another), OR
   (b) bias the frame toward the fastest-moving / knocked player + the nearest wall instead of fitting
   everyone. Either is fine if it satisfies (1)+(2).
4. **Follow lag on a fast launch.** `follow_speed = 6.0` with fixed `margin = (420,340)` may let a
   fresh launch outrun the frame. Confirm a capped (2200) launch stays in-frame (raise `follow_speed`,
   widen the leading margin in the launch direction, or lead the velocity).

NEW gameplay-programmer dependency; changes no Tuning feel constant. Ship bounds+impulse+camera
together, or the burst-screenshot tests (25/26/29) show recovery in a black off-screen void.

---

## 7. Fence — what NOT to do

- **Do NOT raise hitstun** (`hitstun_base`/`per_impulse`/`max`). §4.6 triad protected. If recovery
  fails too often: lower `smash_impulse_from_attacker` or `smash_impulse_max`, never hitstun.
- **Do NOT re-introduce super power scaling** (`docs/DECISIONS.md` 2026-07-02, closed).
- **Do NOT lower `super_boost_impulse_full` (2800) or `max_speed` (3000).** The self-super void kill
  (path 1) needs the 2800 self-super to out-rise the 2200 smash cap past the −1200 ceiling; collapsing
  that gap breaks the top-bound trick.
- **Do NOT widen bounds so far kills vanish.** If post-build laser% > 25% (t11 regresses), FIRST
  raise `smash_solidity_min` back up / tighten bounds toward −1000/2900, THEN raise `smash_sting_fuel`.
- **Do NOT reopen §2.3a** (bumper/tier dry-reflect). Hitstun ends by TIME, never by touching a
  surface. MORE load-bearing now: wider bounds mean more bumper→wall gaps a stunned flier crosses; a
  re-introduced free save would erase every recovery-failure kill.
- **Do NOT remove the drain-all super or add a cheap escape** (§5.1).
- **Do NOT add standable ground, health bars, air-brakes, or any camping affordance** (Pillars).

### 7.1 Explicitly deferred / scoped-OUT (owner Addendum)

- **Taller / rectangular humanoid character with literal head/center/feet hit regions — NOT SPECCED.**
  It reopens the deliberate sphere-blob decisions (AI-generatability, circle-collider match). It is a
  SEPARATE gated art+collider bet, noted here as a **future option only**. The impact-parameter
  solidity in §3 delivers the head/center/feet *spectrum* on the current sphere with zero new art —
  prototype and prove that first; the humanoid is a later ceiling-raiser, not a dependency of this fix.
- **Smash-style persistent damage accumulation — SCOPED OUT (open owner decision).** It conflicts
  with the no-HP / cheap-death identity, competes with fuel as the resource, and pushes a whittling
  meta. NOT adopted. The only identity-preserving alternative *candidate* (also NOT adopted here,
  noted for a future spec): a short **~1–2s decaying "reeling" window** after a solid hit that lets a
  follow-up land a bigger launch — enabling *juggles within one exchange* (not across a match), which
  composes naturally with hit-solidity (a solid hit opens a brief reel; a second solid hit during it
  is the kill). Flag only; do not build it in this pass.

---

## 8. Instrumentation — round_stats additions (programmer dependency)

To measure solidity distribution and "survived a knock / attempted recovery," extend `round_stats`
(parent §8; read-only QA feeds, not feel constants):

- **`smashes[]`** (NEW), one entry per qualifying `receive_smash` (`impulse_mag ≥
  smash_sting_min_impulse` OR any hit with `launch_scale > 0`): `{ t (round_clock s), attacker,
  victim, solidity (s, §3.1), launch_scale, launch_speed (victim |velocity| the frame after),
  angle_deg (impulse dir, 0°=+x, −90°=up), by_super (attacker.super_active), victim_fuel_after
  (post-sting), starved (victim_fuel_after < super_boost_min_fuel), spin (angular_kick applied) }`.
- **Add `t` (round_clock s)** to the existing `kills[]` and `supers_fired[]` entries — the enabler
  for correlation metrics (no bespoke booleans needed).
- QA then computes: a smash is **survived** if the victim is alive 2.5s after its `t` AND x inside
  `[left, right]` at that time; a **recovery was attempted** if that victim has a `supers_fired[]`
  entry with `t` within 1.0s after the smash `t`.

If instrumentation slips, the deterministic eval+burst-screenshot tests (22–26, 29) still gate the
build without the aggregate.

---

## 9. Success criteria (additions to parent §9 — re-run the WHOLE of §9 too)

Harness as parent §9. "Deterministic case" = eval-placed idle victim, scripted single smash, burst
screenshots at 0.2s for 3s + eval of victim `is_dead()`, `global_position`, `fuel`, angular velocity.
"Idle-P1 aggregate" = standard lineup, P1 untouched, ≥10 rounds, reading `smashes[]`.

**Hit-solidity (the new primary lever)**
22. **Solidity scales launch (deterministic sweep).** Script the same super into a victim placed to
    yield `s ≈ {1.0, 0.7, 0.4, 0.2}` (offset victim center off the attacker's travel line). Measured
    `launch_speed` must be monotonic in `s` and match `launch_scale` within ±10%: s=1.0 → ~2200
    (capped); s=0.7 → ~0.60× raw; s=0.4 → ~0.20× raw; s=0.2 → ~0 launch (≤ a shove) + visible spin
    (victim angular velocity > 4 rad/s).
23. **Glancing hits are survivable everywhere; center hits can kill.** Deterministic:
    a. A glancing smash (`s ≈ 0.35`) on a full-fuel mid-stage victim → victim alive at 3s AND x
       inside bounds in **≥9/10**, from any launch angle (arcs back — a glance never rings out from
       mid-stage).
    b. A dead-center smash (`s ≥ 0.9`) aimed 45°-outward on a victim placed 900px from the near wall,
       starved to 4 fuel → rings out ≤2.5s in **≥8/10**.
24. **Sting scales with solidity.** Deterministic + eval: a glancing hit (`s ≈ 0.35`) drops victim
    fuel by ≤ `0.20 × smash_sting_fuel` (≤6); a dead-center hit (`s ≥ 0.9`) drops it by the full 30
    (±2). Confirms glances don't secretly starve-kill.

**The recovery gamble (kill paths)**
25. **Straight-up center smash arcs back (owner's direct ask).** Deterministic: full-fuel mid-stage
    victim, dead-center super within ±20° of straight up → alive at 3.0s AND apex y stays below (>)
    `top` in **≥8/10** (must NOT ring out off the top).
26. **45° recovery, both directions (fails if EITHER side fails):**
    a. *Recoverable with skill:* full-fuel mid-stage victim, dead-center 45°-outward smash, scripted
       counter-super within 0.30s of stun end aimed inbound → survives (alive 3s, x inside bounds) in
       **≥5/10**.
    b. *Lethal without it:* SAME hit, victim starved to 4 fuel (no counter) → rings out ≤2.5s in
       **≥8/10**; and full-fuel victim who fires NO counter → rings out in **≥7/10**.
27. **Self-super void kill preserved (path 1).** Deterministic: a player fires their OWN super
    straight up from mid/high stage → self-destructs off `top` ≤2.5s in **≥8/10**.

**Aggregate — solidity distribution & the sting-as-executioner**
28. Across the idle-P1 sample:
    a. **Distribution exists (not all center):** `smashes[].solidity` spans a real range — ≥30% of
       landed smashes have `s < 0.5` (glances happen) AND ≥15% have `s ≥ 0.8` (skilled/solid hits
       happen). A degenerate all-1.0 or all-0 distribution FAILS (solidity isn't doing anything).
    b. **Sting, not wall, kills:** of `smashes[]` with `starved == true`, **≥60%** are NOT survived;
       of those with victim fuel ≥ `super_boost_min_fuel` after, **≥40%** ARE survived (re-enter
       bounds within 3s). Both bands must hold.
    c. **Recovery is attempted, not luck:** in ≥50% of surviving non-starved smashes the victim fired
       a recovery super within 1.0s of the smash `t`.

**Camera**
29. **Recovery stays on-screen (§6).** Deterministic: script a 45°-outward center smash carrying the
    victim to within 200px of a blast line; burst screenshots show the victim's blob AND that blast
    line both on-frame for the ENTIRE flight (**10/10** frames). Also: at the widest player spread in
    the aggregate sample, no living player is off-frame.

**Pacing guardrails that MUST NOT regress (re-run from parent §9, same targets)**
30. t10 kills carry ≥70% (`end_cause != laser`, `<20s`); t11 SD ≤25%; t12 median combat 10–22s;
    t13 L4 > L2 (0/5 L2 wins); t15a ≥2 off-stage kills/10. If t10/t11 regress, apply the fence (§7)
    tightening order: `smash_solidity_min` up → bounds tighter → `smash_sting_fuel` up. Never hitstun.

---

## 10. New/changed constants — one block (implementation checklist)

```
# Tuning.gd — NEW (hit-solidity, Lever A + C)
smash_solidity_min          = 0.25     # below this impact-parameter s, launch = 0 (pure spin+shove)
smash_spin_max              = 12.0     # rad/s full-graze tumble, applied prop. to (1-launch_scale)
smash_impulse_max           = 2200.0   # hard cap on impulse magnitude AFTER solidity, BEFORE max_speed

# Tuning.gd — CHANGED
smash_impulse_from_attacker 1.35 -> 1.1  # cap sets the ceiling now; lower coeff = gradient + less graze-random

# Player.gd — _handle_smashes (both player ~619 and prop ~641 branches):
#   s = clampf(velocity.normalized().dot((b.global_position - global_position).normalized()), 0, 1)
#   launch_scale = clampf((s - smash_solidity_min) / (1 - smash_solidity_min), 0, 1)
#   impulse_mag  = minf((smash_impulse_base + my_speed*smash_impulse_from_attacker)*launch_scale, smash_impulse_max)
#   impulse      = velocity.normalized() * impulse_mag        # direction unchanged
#   angular_kick = smash_spin_max * (1 - launch_scale) * signf(velocity.normalized().cross(n))  # -> victim spin
# Player.gd — receive_smash: sting scales with launch_scale (pass it in or recompute):
#   sting = smash_sting_fuel * launch_scale, gated on impulse_mag >= smash_sting_min_impulse
#   hitstun UNCHANGED (already reads impulse.length() = impulse_mag) — feed it the scaled impulse, touch no constant

# levels/dev_arena.json — bounds (supersedes §2.4)
left  -620 -> -1100 · right 2520 -> 3000 · top -950 -> -1200 · bottom unchanged

# CameraController / PartyMatch — §6 dependency (no Tuning constant):
#   CAM_MIN_ZOOM 0.42 -> ~0.36 (or targeted framing); keep knocked-alive players + approaching wall visible

# round_stats — §8 additions: smashes[] (with solidity/launch_scale/starved/spin/t), + t on kills[]/supers_fired[]

# DO-NOT-TOUCH: hitstun_base/per_impulse/max, smash_self_retain, max_speed, super_boost_impulse_full,
#   drain-all super, fuel_per_bounce/fuel_per_bumper, §2.3a dry-reflect, no-power-scaling decision
```
