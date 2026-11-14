# WK-95: Flight you can steer. Normal flight is how you get around; the super is how you hit people (2026-11-14)

**Owner:** game-designer (spec + rulings) · **Builds it:** gameplay-programmer · **Verifies:** qa-playtester + creative-director
**Backlog:** WK-95 [P0][M]. Depends on WK-93 (match recorder) for baseline evidence. Sequence it after WK-94 (bot aim
smoothing), because both edit `InputBot.gd`.
**Owner ruling (verbatim, 2026-11-14 check-in):** *"the bots need to rely too much on the super boost because the normal
flying isnt responsive enough to maneuver around nicely, we should make that more responsive/effective and consider super
boost more just like the way to attack others rather than the way to get around."* The check-in record says this ruling
**supersedes earlier "fuel economy / super as movement" assumptions where they conflict**.
**Inputs read:** owner_2026-11-14_checkin · owner_2026-07-02_movement_feel · VISION · GAME_ESSENCE · DECISIONS (2026-07-02
un-charged super, 2026-07-03 dry-reflect + sting rejection, 2026-07-16 boost gravity, 2026-07-19 knockback, 2026-11-14
autonomy) · `Tuning.gd` · `Player.gd` (`_physics_process` boost/aim block, `_fire_super`, `_on_bounced`) · `InputBot.gd`
(`poll`, `_decide`, `_danger_recover`, `_tick_aiming`, `_in_danger`, `_can_reach`, `_super_safe`) · `BotProfile.gd` ·
`CharacterProfile(s).gd` · `Ball.gd` (`_drive_from`) · `PartyMatch.gd` (`_on_super_fired`) · FEEL_REFERENCE §0/§2.3/§3 ·
skills tuning-and-flags / game-feel-reference / analysis-toolkit / change-control · Trials course JSONs.
All numbers are **pen-and-paper (verified: static)** from live `Tuning.gd` values: g = 1600, thrust gravity 0.8·g = 1280,
120 tps, Standard profile, flat gravity. QA confirms them in §8.

---

## 0. Summary

1. **Diagnosis.** Today the jetpack only pushes along the stick, up to a speed cap. Nothing controls velocity at right angles
   to the stick. So a held boost can't hold a line: gravity's sideways share builds without limit (a 45° hold reaches
   1180 px/s after 1 s), a 90° turn never finishes while you thrust, and aiming straight at a level target lands you
   **~520 px low** over a 620 px gap. The super goes exactly where you point and travels 1260 px in 0.45 s, for as little as
   5 fuel. It is the only precise way to move, so bots and players use it to get around. The bot brain makes it worse in
   three ways. It supers on fumes when in danger (`fuel <= 12`). It fires from finisher range (~1000 px) without a
   line-of-sight check. And it aims straight at targets, which today's flight can't actually hit.
2. **The change.** Add a **steering grip**: while you thrust, velocity at right angles to the stick bleeds away, with
   guards so the grip never removes bounce lift, never adds speed, and never touches big launches. A fresh boost now keeps
   the speed you already have **in the direction you're pointing**. Thrust goes to 5400 accel and an 800 cap (INV-1 still
   holds). Result: level flight at 815 px/s, a 0.34 s 90° turn, and a point-and-arrive miss of ~115 px.
3. **Super = attack.** `super_boost_min_fuel` goes from 5 to 10, which removes the fumes-super taxi. Impulse, drain-all,
   un-charged power and lockout are unchanged (reasons in §4.1). Bot rules: fly to travel. Super only inside an attack
   window (in range, line of sight clear) or as a **last-resort** recovery (launched too hot, or unreachable by flight).
4. **Protected constants: none touched.** Hitstun triad, kill target, camera rules, `dmg_launch_mult`, super impulse,
   `max_speed`, `fuel_per_bounce/bumper`, `smash_self_retain` all stay. `super_boost_min_fuel` sits on the left side of
   invariants #2 and #7. Both still hold (§3.5).
5. **Acceptance.** Mechanism criteria M1–M9 (QA can drive them), bot super-as-movement share ≤ 10% (from a measured
   baseline), PadHopper completes the normal-flight courses ≥ 4/5, KO pacing within guardrails, sports and Trials sweeps, a
   creative-director feel check, and before/after WK-93 recordings.

---

## 1. Player fantasy and core verbs

**Fantasy:** *"I point, I fly there."* You're a jetpack goat who carves around islands, banks into a turn, skims a gap and
hits the pad you aimed at. You do it on the jetpack, because the jetpack is good. The super is the **shot**. You see a rival
lined up, you freeze for the fuse, and you go horns-first. When everyone in the room sees a super ring, it means someone is
about to get hit, not someone commuting across the map.

**Core verbs exercised (GAME_ESSENCE):**
- **FLY (primary).** Flight becomes the default way to move, and the spec measures that it is (§8 B5, C1).
- **SUPER-SMASH (repositioned).** The super becomes a deliberate attack. Its use share for travel is measured (§8 B1).
- **BOUNCE (protected).** Bounce height, tiers, drift and DI are untouched. Grip rules G2 and G5 keep the boost-bounce lift
  and the supercharge chain-flow (FEEL_REFERENCE §3.4).
- **RECOVER (affected).** Steerable flight makes recovery easier. That's honest, but it is a pacing risk. It has guardrails
  and a fallback ladder (§6.5, §9).

**Pillar check.** Low floor improves: pointing at where you want to go works. The ceiling stays: turn timing, glide angle,
fuel lines and super timing. Constant motion isn't touched; no hover-camping is possible because the tank, drain and refuel
rules are unchanged. Readable chaos improves: fewer stray super rings means a super ring reads as a threat.

---

## 2. Diagnosis: why normal flight under-delivers today

### 2.1 What the code does (Player.gd `_physics_process`, boost branch)
While boosting:
- Gravity is scaled to 0.8 (1280 px/s²).
- If `velocity·aim < 760`, velocity gains `aim × min(4600·dt, 760 − velocity·aim)`.

That is all. Three things follow:
- **(a) No authority at right angles to the stick.** The component of velocity perpendicular to the aim is never damped. Air
  drift (the only other steering) is switched off while boosting.
- **(b) Every fresh boost multiplies all velocity by 0.25.** That's `boost_enter_keep`, applied to every direction,
  including the way you want to go.
- **(c) Speed has no ceiling off the vertical.** The 760 cap only limits the along-aim part.

### 2.2 The numbers today

| Situation (Standard profile) | Today | Why |
|---|---|---|
| Time to cap from rest, horizontal / straight up | 0.165 s / 0.229 s | 760/4600; 760/(4600−1280) |
| **Hold a 45° boost for 1 s** | **1180 px/s and still accelerating.** Gravity's 905 px/s² perpendicular share is never opposed | v = 760·a + 905·t·p |
| Level flight | **Impossible** away from straight up. No steady state exists | (a) |
| Aim straight at a same-height pad 620 px away | Arrives **~520 px low** (falls 0.5·1280·0.9²) | (a) |
| Fastest same-height 600 px crossing | ~0.78 s, but only with an unintuitive **27.5° aim**. Arrives at **1100 px/s while descending**, so it overshoots small pads | parabola solve |
| **90° turn while thrusting** (moving right at cap, aim up) | **Never completes.** 0% of the 760 sideways speed is shed. You drift ~380 px per 0.5 s. To turn you must release (and fall) or counter-aim | (a) |
| 180° turn (cap to −0.9·cap) | 0.31 s, 63 px overshoot | 1444/4600 |
| Bounce, then press boost upward | Trampoline launch 930 up drops to **232** px/s, then re-accelerates. Boosting feels like a brake | (b) |
| Fuel per px, normal flight | ~26 px/fuel at best (760/28.6) | drain 28.6/s |
| INV-1 in motion | Holds on paper (cap 760 < 900). In motion, a held 45° boost passes 900 px/s at 0.53 s. Only the smash *license* prevents a smash | (c) |

### 2.3 What the super gives that flight doesn't
1. **It goes where you point.** 2800 px/s dwarfs gravity: after 0.45 s it has bent only ~7°.
2. **It's cheap at low fuel.** A super at 5 fuel moves you 1260 px in its 0.45 s active window, about 250 px per fuel,
   roughly **10× flight's ~26**. A fumes super is the cheapest movement in the game.
3. **It has a built-in air brake.** The AIM state decays velocity at 2.5/s with 0.25 gravity. That makes it the only
   stop-and-reposition tool. Flight's only brake is the blunt 75% entry chop.
4. **It's fast.** 1260 px in 0.45 s, against ~1.6 s of flight.
5. **For a bot it's a one-step solution:** point at the spot and release. Flight needs a closed-loop controller the bot
   doesn't have.

### 2.4 Where bot supers come from (InputBot.gd, by function)
- **`_danger_recover`.** Supers when in danger AND (`fuel <= 12` OR outward speed > 1400 OR stranded). The **`fuel <= 12`
  clause is the fumes-super taxi**. Bots fly down to their `refuel_floor` (15–35), drift near voids, trip the anticipatory
  check in `_in_danger`, and super with 5–12 fuel even when a boost would reach. "Stranded" uses
  `CROSS_FUEL_PER_PX = 0.045`, which was sized for today's lossy arcs.
- **`_decide`, hunt branch.** Supers when `dist < attack_range` (240–520 px). **There is no line-of-sight check.** Supers
  fired through platforms bounce off geometry and read as travel.
- **`_decide`, finisher branch.** `_eff_attack_range` grows ×1.4 × the width factor (up to 1.6). For L4 on a wide arena
  that's 460 × 2.24 ≈ **1030 px**, which turns the super into a gap-closer.
- **Flight aim.** Bots aim straight at targets (`_jitter(d.normalized())`). Under today's flight that lands hundreds of px
  low, so the approach stalls until the super is in range.
- **`_check_dodge`.** Dodge supers (L4/L5). Legitimate combat; counted separately.

**Root causes, ranked:** (R1) no cross-axis authority, which is the "not responsive" the owner sees. (R2) The fresh-boost
chop eats momentum you want. (R3) The fumes super is the best fuel-to-distance trade. (R4) Bot recovery and finisher rules
spend the super as travel. (R5) Bots aim flight like a super.
**Fixing physics alone won't satisfy the ruling (bots), and fixing bots alone won't either (humans still feel R1/R2). Both
ship.**

**Arena context:** brawl gaps are 520–800 px; most are 580–680 (islands_void 520/580, foundry family 680, atoll 800).
Trials pad gaps are 600–700, with 1400 px super finales. The flight-required threshold is bounce reach: 527 px off a
spring. Air drift and bounce settings are untouched, so **no arena loses flight-required** (§6.2).

---

## 3. The change, Phase 1: flight

### 3.1 Steering grip (new mechanic; the core fix)
While **thrusting**, after the existing gravity and thrust steps, apply grip to v⊥, the component of velocity perpendicular
to the thrust direction `a`:

- **G1. Grip.** Shrink v⊥ toward 0 with deceleration `min(boost_grip_rate × |v⊥|, boost_grip_decel_max)`. Never overshoot
  past 0. This is the same decay shape as `super_aim_damp`, with a ceiling.
- **G2. Grip never takes away height.** If the body is rising (`v·up > 0`, local gravity frame), remove the downward
  component from the grip's Δv. Bounce launches and supercharged lift survive in full, but sideways drift still dies. Some
  cases:
  - Aim horizontal after a bounce: you get the whole bounce, then glide.
  - Aim up-right while flying up-left: the leftward drift is killed and the climb is kept.
  - Gravity sag while climbing diagonally: corrected, because that Δv points up.
- **G3. Grip never adds speed.** If `|v + Δv| > |v|`, scale Δv down until it doesn't. No energy pump exists.
- **G4. Grip needs steering input.** It is off when the stick is centred. A neutral boost stays pure lift (thrust straight
  up) and keeps your sideways momentum, which preserves the owner's "hold boost, no direction = easy recovery" rule.
- **G5. Big launches belong to physics.** Grip is off while `|v| > boost_grip_speed_max` (1300). Supers (2800), smash
  launches (≤ 3000) and supercharged spring launches (≈1736) are untouched. The jetpack only steers speeds it could have
  produced itself.
- **Grip is also off** while super-aiming (no thrust there anyway), in hitstun (intent is zeroed), frozen, dead, or
  black-hole-pulled (`_pulled > 0`, the same exemption air drift already has). That keeps the Black Hole's pull meaningful
  and invariant 4's intent intact.

Applies to the supercharged window (the thrust multiplier is unchanged) and to all character profiles (no new profile
lever).

### 3.2 A fresh boost keeps forward momentum (refinement of `boost_enter_keep`)
Today: `velocity *= 0.25` on every fresh press. New, with `boost_enter_keep_directional = true`:
- `v_fwd = max(0, v·a)`
- `v_rest = v − v_fwd·a`
- `v = v_fwd·a + v_rest × boost_enter_keep`

`boost_enter_keep` stays **0.25**. Effects:
- Bounce, then boost upward: speed **stays 930** instead of dropping to 232.
- Momentum banking (owner course #4) survives: point with your momentum to keep it.
- **The brake tap still works:** aim against or across your motion and you still lose 75%.
- **Recovery model unchanged.** A smashed victim who boosts on their first free frame while aiming *back toward the stage*
  has a negative `v·a`, so they're chopped to 25% exactly as today. See §5, E2: that chop is load-bearing for KO pacing.

### 3.3 Thrust numbers
- `normal_boost_accel` **4600 → 5400.** Snappier start and reversal. Invariant 4 holds: 2600 < 5400.
- `normal_boost_max_speed` **760 → 800.** That's +5% pace and the most INV-1 allows: 800 × BOOST_MAX 1.12 = **896 < 900**.

Rationale (FEEL_REFERENCE §3.2: "accel > gravity, so you can climb & recover"; Celeste lineage: responsiveness lives in
acceleration and turnaround, not top speed). **Top speed rises only 5% on purpose.** The fix is control, not speed. Speed
would also feed header power, shove credit and camera pan rates.

### 3.4 Before/after math (Standard profile; how each was derived)

| Metric | Today | **WK-95 (prediction)** | Derivation |
|---|---|---|---|
| Time to cap, horizontal from rest | 0.165 s | **0.148 s** | 800/5400 |
| Time to cap, straight up from rest | 0.229 s | **0.194 s** | 800/(5400−1280) |
| Level flight | impossible | **aim 11.1° up, 815 px/s, holds altitude** | steady state: k·v⊥ = 1280·cosθ, so v⊥ = 160·cosθ; vy = 0 gives sinθ = 0.193 |
| Glide sag, stick dead horizontal | grows at 1280 px/s² (640 px lost in 1 s) | **steady 160 px/s (~115 px lost in 0.85 s)** | 1280/8 |
| **Point-at-target miss**, 620 px same-height gap | ~520 px low | **~115 px low** | 160·(t − 0.125), t ≈ 0.85 s |
| **Time to cross a 600 px gap at level** | ~0.78 s at a 27.5° aim, arriving 1100 px/s descending | **~0.83 s at 11°, arriving 815 px/s level** | 600/815 + 0.09 s ramp |
| Fuel for that crossing | ~22 | ~24 | 28.6/s × t |
| **90° turn** (shed 90% of 800 sideways while thrusting) | never (0%) | **0.34 s, ~130 px overshoot** | linear at 3000 px/s² to 375, then e^(−8t) to 80 |
| **180° turn** (cap to −0.9·cap) | 0.31 s / 63 px overshoot | **0.28 s / 59 px** | 1520/5400; v²/2a |
| Speed after a 1 s 45° hold | 1180 px/s, climbing | **808 px/s, steady** | √(800² + (905/8)²) |
| Full-tank straight-up climb | ~2750 px | **~2920 px** | ramp + 800 × 3.3 s + 800²/2g |
| Full-tank level range | n/a (best arc: 1805 px for 48 fuel, ending at 1700 px/s) | **~2800 px**, controlled | 815 × 3.5 s − ramp |
| Fuel per px, level flight | n/a | 0.035 fuel/px (28.5 px/fuel) | 28.57/815 |
| Speed right after bounce + boost-up press | 232 px/s | **930 px/s** | §3.2 |
| Trampoline boost-bounce aimed horizontal (supercharged 1302 up): apex | 662 px | **662 px (G2)** | 1302²/(2·1280) |
| Unboosted trampoline hang | 1.16 s | 1.16 s | untouched |
| Super: 0.45 s carry / straight-up rise | 1260 px / 2450 px | unchanged | untouched |

Grip constants and why these values:
- **`boost_grip_rate = 8.0 /s`.** Time constant 0.125 s. The level-flight sag of 160 px/s keeps weight readable, so it
  doesn't feel "on rails". The 0.34 s turn is crisp but you can still see the arc (the "arc of a boost" in GAME_ESSENCE).
  Live band: 6–12.
- **`boost_grip_decel_max = 3000 px/s²`.** Comfortably above the largest gravity share the grip ever fights (1280), so
  glide always holds. Below `normal_boost_accel`, so steering never out-brakes reverse thrust. Live band: 2000–4000.
- **`boost_grip_speed_max = 1300 px/s`.** Above any self-made flight speed (supercharged cap 800 × 1.6 = 1280). Below
  supers, smash launches and supercharged springs (1736).

### 3.5 Protected constants and invariants audit (analysis-toolkit recipe 1)

| Item | Status after WK-95 |
|---|---|
| Hitstun triad 0.15 / 0.00025 / 0.55 (DNT) | **untouched** |
| `dmg_launch_mult` [1.25, 1.66, 2.08] (owner) · `match_target_kills` 10 (owner) · camera rules / `cam_*` (owner) | **untouched** |
| `super_boost_impulse_full` 2800 · `max_speed` 3000 · `smash_self_retain` 0.1 (DNT) | **untouched** |
| `fuel_per_bounce` / `fuel_per_bumper` 20 (DNT) · `tank_seconds` 3.5 · gravity · tiers · `air_drift_*` · `bounce_di` | **untouched** |
| Super power scaling (closed 2026-07-02) | **not reintroduced.** Un-charged, drain-all, 2 s aim cap all kept |
| INV-1 `normal_boost_max_speed × BOOST_MAX < smash_impact_min` | 800 × 1.12 = 896 < 900 ✓ (at the limit; update the comments in `CharacterProfile.BOOST_MAX` and Player.gd). **Improves in motion:** steady flight is bounded near 808–816 px/s instead of running to 1180+. Known pre-existing exception: the supercharge cap (1280; it was 1216) is above 900, as before; the license guards it |
| #2 `fuel_per_bounce ≥ 2 × super_boost_min_fuel` | 20 ≥ 20 ✓ (**now at equality.** Never raise min fuel again without a `fuel_per_bounce` ruling) |
| #3 `fuel_per_bumper ≥ super_boost_min_fuel` | 20 ≥ 10 ✓ |
| #4 `pu_black_hole_pull < normal_boost_accel` | 2600 < 5400 ✓ (and grip is off while pulled) |
| #7 sting-starve (a mid-tank 34 minus one sting 30 lands below min) | 4 < 10 ✓. The starve band widens to 34–39 fuel: a small lethality *gain* that partly offsets the recovery gain |
| #11 `super_refire_lockout + input_buffer ≤ 0.35` | 0.25 + 0.10 ✓ (lockout untouched) |
| `finisher_refuel_floor` must stay above min fuel (its own comment) | 10 → **15** |

**Conclusion:** the ruling does **not** require touching any protected constant. The only ruled-on assumption it overturns
is the 2026-07-02 owner hypothesis that a super "works with even 5% fuel… super with the last 5% to go further" (min fuel 5
becomes 10). The 2026-11-14 ruling explicitly authorizes that ("supersedes… super as movement assumptions"). It needs a
DECISIONS entry (§11).

### 3.6 Live-tune order and A/B switches (FEEL_REFERENCE §0 rule 2: one variable at a time)
The programmer builds everything behind switches so QA can isolate each lever with `gbplay eval`:
- `Tuning.boost_grip_rate = 0.0` disables the grip (today's behaviour).
- `Tuning.boost_enter_keep_directional = false` restores today's chop.
- `InputBot.wk95_brain_enabled` (static, default ON) gives the old brain when OFF, mirroring `ascent_fix_enabled`.

Tune in this order, measuring after each:
1. Grip: M2, M4, M5.
2. Directional entry: M6, M8.
3. Accel/cap: M1, M3.
4. Min fuel.
5. Bot brain: B1–B6.

---

## 4. Super = attack

### 4.1 What changes and what deliberately doesn't

| Lever | Decision | Why |
|---|---|---|
| **`super_boost_min_fuel`** | **5 → 10** | Removes the 5–9.9 fumes band, which is the cheapest taxi (§2.3 item 2). A super now always costs at least 0.35 s of flight, and after this change flight is worth having. One bounce still re-arms (20 ≥ 10), so the wall-return second try, super chains and the Wall Climb survive |
| Drain-all | **keep** | It already makes a full-tank super a big commitment (3.5 s of steerable flight). Once flight is good, that opportunity cost becomes real without a new rule |
| `super_refire_lockout` 0.25 | **keep** | A cooldown taxes attack and traversal equally. It would kill the owner's favourite expressions: miss, wall, immediate second super; dodge-counter supers. It would also break invariant #11 |
| Charge / aim (`super_aim_max` 2.0, damp, gravity) | **keep** | The un-charged model is a closed decision. The fuse is the dodge telegraph ("telegraphy is sacred"). WK-94 owns aim *motion* |
| `super_boost_impulse_full`, `super_active_time` | **keep** | DNT / the kill feel the owner just strengthened |

**Pushback recorded:** I reject a punitive cost or cooldown (a 25-fuel minimum, a 1 s lockout, impulse cuts). Each one
breaks an invariant, a Trials course or an owner-loved skill expression, and none of them separates *attack* from
*traversal*. The separation comes from flight being good and the bot brain being disciplined. Min fuel 10 is the one cheap
nudge.

### 4.2 Emergency recovery stays possible
With ≥ 10 fuel you can always recovery-super, at full 2800, as today (that's the gamble, and L1 comedy self-destructs stay
in). What's gone is the 5–9 fuel recovery super. A sting that leaves a victim at 5–9 now starves them, which offsets part of
the recovery gain from better flight (§6.5).

### 4.3 Phase 2 (pre-registered, conditional; NOT built in Phase 1): `super_hit_refund`
A landed super smash refunds **30 fuel** to the attacker. That's once per super fire, first smash only, attacker
`super_active`, victim not spawn-protected. The pitch: "land it and you're back in the air." Hit means you keep flying;
whiff means you're empty. It becomes the economy's own way of saying the super is for hitting.

It ships **only if**, after Phase 1:
- (a) HumanSim super-as-movement share is above 20% (§8 C4), or
- (b) the creative-director check answers "no" to Q2 (§10).

Economy audit: the only source is a landed hit on another player, so it can't be farmed. The DECISIONS entry must name the
condition.

### 4.4 Bot brain rules (`InputBot.gd`; difficulty dials unchanged, INV-8 no cheating)
- **BR-1. Travel by flight.** Hunt approach, refuel dive, retreat, sports objective, chase-the-wounded and drift-home use
  boost only. These states already set `_cached_super = false`; the recorder asserts it (B3).
- **BR-2. Gravity-compensated flight aim.** When boosting toward a goal, aim above the target line by the steady sag angle
  `atan(boost_gravity_scale·g·cosθ / boost_grip_rate / thrust_cap)`. That's ≈11° at level and 0 straight up or down.
  Derive it from Tuning; don't hardcode it. `_jitter` and WK-94's low-frequency noise apply on top.
- **BR-3. Offensive super only inside an ATTACK WINDOW** (hunt or finisher). All of these must hold:
  1. The led target is within `min(_eff_attack_range(), super_reach)`, where
     `super_reach = super_boost_impulse_full × super_active_time × 0.85` ≈ **1070 px**. This caps the finisher's
     ~1030–1165 px.
  2. **Line of sight:** a ray from me to the led intercept hits no `MASK_SURFACES`.
  3. Fuel ≥ max(refuel floor, `super_boost_min_fuel`).
  4. `_super_safe` (unchanged).

  If the window fails, fly (BR-1, BR-2). Never super to close distance.
- **BR-4. Recovery super = last resort.** In danger AND fuel ≥ min AND one of:
  - **HOT:** outward speed > 1400 (unchanged).
  - **UNREACHABLE:** `_can_reach(land_dist)` is false with the updated constants.

  **Delete the `fuel <= 12` clause.** Low fuel alone is never a reason; low fuel plus reachable means boost. Recovery aim
  quality (`recovery_skill`) is unchanged, so L1 still flails comically, but only when it had to gamble.
- **BR-5. Dodge super unchanged** (L4 0.5 / L5 0.8, finisher cap 0.15). It's a combat reaction, tagged `dodge`.
- **BR-6. Constants:**
  - `CROSS_FUEL_PER_PX` 0.045 → **0.042** (new physics 0.035 plus the same ~20% margin as today).
  - `CROSS_FUEL_RESERVE` 10 → **15** (must stay above the new min fuel).
  - `SUPER_CARRY` unchanged.
- **BR-7. Purpose tags.** Every bot super records a purpose: `attack`, `finisher_attack`, `dodge`, `recovery_hot` or
  `recovery_unreachable`. PartyMatch copies it into the `supers_fired` record (§8.1). The programmer chooses the plumbing.

---

## 5. Edge cases

- **E1. Hitstun:** no input, so no thrust and no grip. Hitstun still ends only by TIME (dry-reflect doctrine untouched).
- **E2. First boost after hitstun.** Today it silently chops knockback to 25%, which is part of the *current* recovery
  model. WK-95 keeps that for any victim aiming back or across (negative or zero `v·a`). A victim aiming *with* their
  launch keeps it, which is their choice and usually fatal. **Finding, routed separately (not WK-95 scope):** the chop
  quietly undercuts "ring-outs come from momentum" (GDD §4.6). Lethality owners should review it in WK-57. Don't change it
  here.
- **E3. Boosting right after a super:** fuel is 0 (drain-all), so you can't boost. Under Unlimited Boost (`fuel_locked`),
  |v| = 2800 > 1300, so G5 leaves the super arc alone. The directional keep no longer chops a same-direction boost, so the
  super isn't extended; it just isn't killed.
- **E4. Neutral stick + boost:** straight-up lift, no grip (G4). Sideways momentum is kept, exactly as today.
- **E5. Keyboard (8-way aim, first-class since 2026-11-14):** level flight needs 11°. Right-only glides at −160 px/s
  (~115 px drop per 600 px), up-right climbs. Acceptable and readable. Note it in COUCH_CONVENTIONS if players ask.
- **E6. Radial gravity (Orbit set, atoll, singularity):** grip and G2 use local gravity. **Boosting radially outward now
  damps your tangential orbital speed,** so orbits and slingshots read as "go where I point". That's a real behaviour
  change; see §6.1 (HIGH risk).
- **E7. Black Hole:** grip off while pulled. Escape is unchanged except for higher accel (5400 vs 4600; the pull is 2600).
- **E8. Wings / Mega Bounce / supercharge chains:** Wings is separate input, unaffected. Mega Bounce and supercharge lift
  are kept by G2 and G5. Chain flow (FEEL §3.4) is intact.
- **E9. Head-bounce / shove:** unchanged rules. Fewer runaway speeds means fewer surprise shove-credit events
  (rel ≥ 500 still happens head-on).
- **E10. Underside/ceiling:** grip has no effect on bounce resolution. The no-refund rule on undersides is unchanged.
- **E11. Moving / cannon launches** (p4 cannons, carts): a cannon launch above 1300 px/s is immune (G5). Once slower, a
  boosting player steers it (intended).
- **E12. Profiles:** Ziggy (boost 1.08) gets cap 864 and accel 5832, steady ≤ ~880 < 900. Puff and Vex air control only
  affect drift (unchanged).

---

## 6. Side effects to re-check

### 6.1 Trials courses at risk (level-designer + QA; geometry is the knob, never the tank)

| Risk | Course(s) | What may change | Check |
|---|---|---|---|
| **HIGH** | **ORBIT set: g6_moonwalk, g6_orbit_ring, g6_liftoff, g6_slingshot, g6_dead_star, g6_gravity_chain, g6_binary_run, g6_solar_tour** | Boosting damps tangential orbital velocity (E6). Slingshot and orbit-ring lines may lose carry | Drive all 8 by hand. Any that become harder or easier enough to break their lesson get a geometry fix. A per-course `grip` override is NOT allowed (one physics) |
| **MED** | course_02_fuel_line | (1) The greedy-continuous-boost run (designed to fail ~pad 4) may now succeed, because legs are cheaper (~24 vs ~27 fuel) and bounce-keep adds carry. (2) The 1400 px "super-only" finale becomes clearable with ≥ ~50 banked fuel at level flight. (3) Arriving at the finale with 5–9 fuel can no longer super | Run greedy F1 and banked-boost scripts. Ruling: a boost-clearable finale is **acceptable** under the owner ruling. If the fuel lesson loses its teeth, widen gaps by 60–100 px. If (3) bites, move the last refuel pad closer |
| MED | n2_refuel_ridge | The miss-a-pad proof margin shrinks from ~−25 to ~−12 fuel (it still fails) | Run the skip-one-pad script. If it clears, add 80 px to the merged gap |
| MED | p4_cannon_school, p4_double_barrel, t_ball_cannon | Boosting during a cannon flight below 1300 px/s steers it (E11) | Drive each once |
| LOW (easier) | tut_01, tut_03, tut_04, course_01, course_03, course_04, course_05, n2_slalom, n2_needle_thread, n2_pinhole, n2_wall_climb | Precision hops get easier; the n2_wall_climb one-tank alt line gains ~8 fuel of margin; The Climb's "too tall for one super" is unchanged | Confirm each still exercises its lesson (not trivial) |
| LOW | tut_02_super_shot | A plain-boost climb to 2000 was already possible (now ~2920 range). The "fires at ANY fuel ≥ 5" line in design_intent is stale; retries still refuel 20 ≥ 10 | Docs only |
| LOW | s3_* (soccer trials) | Headers are slightly weaker but straighter (§6.3) | s3_long_ball and s3_top_corner driven once |

Every course JSON `design_intent` quotes 760 px/s and 26.6 px/fuel. That's docs-only staleness; the level-designer
refreshes it in a later pass.

### 6.2 Brawl arenas: flight-required
The proof rests on bounce reach: air drift 340 and DI 260 give ~395 px off a trampoline and ~527 off a spring, against
gaps of 520–800. **Both are untouched, so every arena stays flight-required.** The boost-entry keep doesn't change
zero-boost reach. Nothing to re-prove. QA spot-checks islands_void and atoll with zero-boost bounces.

### 6.3 Sports
`Ball._drive_from` strikes with `500 + 0.9 × |v_player|`, ×2 when super-active or in hitstun.
- Today's runaway flight (1100–1700 px/s) makes some normal headers hit near the 2400 cap.
- New steady flight (~815) gives ~2050 px/s ball speed: **normal headers a bit weaker but much more aimable**, because
  strike direction blends the player's travel direction, which is now straight.
- The super stays the power shot, which matches the ruling exactly.
- Sports bots (objective path, boost-only) benefit directly.

Prediction in §7. Knob if headers feel limp: `BALL_DRIVE_GAIN` 0.9 → 1.05. It's a Ball.gd const, a known INV-6 wrinkle;
migrate it to Tuning if touched. Sports is the owner's fun-flagged mode (WK-98), so §8 E is mandatory, not optional.

### 6.4 Fuel HUD
Drain rate is unchanged (28.6/s), so gauges need no change. **Readability opportunity (UI follow-up, not blocking):** a
notch at the super-ready threshold (now 10%) on the PlayerCard gauge and the bubble fuel ring. "Can I super?" becomes
visible, which matters more now that the threshold isn't trivially low. Route it to ui-ux-designer as a WK-1xx item.

### 6.5 KO pacing (the big one)
Better flight helps victims: they arrest falls while gliding toward an island, and turns are controllable. On void maps
(where ~79% of kills go off the bottom), **predict credited KOs per combat-minute −5% to −15%**. Partial offsets: the
starve band widens (min fuel 10), the fumes recovery super is gone, and bots' supers are better targeted (higher
conversion). Guardrails and the pre-registered ladder are in §9. **Never hitstun, never `dmg_launch_mult`, never super
impulse, never kill target.**

### 6.6 Other
- **Camera:** speeds are bounded, so pans get calmer. No camera constant touched.
- **Motion health:** the grip should *reduce* boosted underside head-bangs (no runaway). Watch for new bot oscillation
  around targets (B6).
- **Powerups:** Unlimited Boost gets stronger (8 s of steerable flight). Watch it; the knob is `pu_unlimited_boost_dur`.

---

## 7. Pre-registered predictions (written before any data)

| ID | Prediction |
|---|---|
| P1 | M1–M6 land within ±10% of §3.4 |
| P2 | Bot super-as-movement share (§8.1): **baseline 30–50%, after ≤ 10%** (point estimate 5%) |
| P3 | Supers per bot per combat-minute drop 30–50%. Offensive-super smash conversion rises 5–10 pp |
| P4 | Bot boost share of airborne time rises from a measured baseline to ≥ 35% |
| P5 | PadHopper (super disabled) baseline fails ≥ 1 of course_05 / n2_slalom / course_03 at < 4/5. After WK-95, all normal-flight courses ≥ 4/5 |
| P6 | Credited KOs per combat-minute −5% to −15%. Median stage length +0–15%. Bot self-KO share ±3 pp |
| P7 | Sports: touches per minute +10–20%; median normal-touch ball exit speed −5% to −15%; goals per minute within ±10% |
| P8 | Motion health: `underside_boosted` and `stuck_episodes` ≤ baseline (expected down) |
| P9 | Creative director: "flight feels like a pilot, the super feels like a shot". FIX items, if any, on grip strength, not structure |

---

## 8. Acceptance criteria (QA-verifiable)

**Baseline first.** Capture every "before" number on the build with WK-94 merged and WK-95 not. If WK-95 is already
built, use the A/B switches in §3.6 plus accel 4600 / cap 760 / min fuel 5 at runtime. Persist nothing; hash `Tuning.gd`
before and after.

### 8.1 Telemetry the build must add (PartyMatch, QA feed)
- **`supers_fired[]` record grows** with: `pos`, `vel`, `aim_dir`, `purpose_bot` (BR-7, or null for humans), and
  `landed` (true if this super's `super_active` window produced a `smash_landed`). Also `geo_class`, computed at fire time:
  - **ATTACK:** an opponent within 1260 px and within 0.6 rad of `aim_dir`.
  - **DODGE:** an opponent is super-aiming within 500 px, within 0.5 rad of me.
  - **RECOVERY_NEEDED:** in danger (over void, outside `stage.grow(440)`, or smashed ≤ 1.5 s ago) AND (outward speed
    > 1400 OR no landing surface reachable at `fuel / 0.042` px).
  - **RECOVERY_UNNEEDED:** in danger but a landing surface is flight-reachable.
  - **TRAVERSAL:** none of the above.

  **Super-as-movement share = (RECOVERY_UNNEEDED + TRAVERSAL) / all supers.**
- **Per player per stage:** `air_time`, `boost_time`, `boost_path_px`, `super_path_px` (path during `super_active` plus
  0.5 s).

### 8.2 Mechanism (gbplay eval; Standard profile; dev or Trials geometry; ≥ 5 trials each, report the median)

| ID | Test | Pass |
|---|---|---|
| M1 | From rest, hold boost horizontal / straight up | time to 0.95·cap ≤ 0.16 s / ≤ 0.21 s |
| M2 | Moving right at cap, switch aim straight up | ≥ 90% of horizontal speed shed within **0.40 s**; overshoot ≤ 160 px (baseline: record, expected ~0% shed) |
| M3 | Moving right at cap, aim left | vx ≤ −0.9·cap within 0.31 s |
| M4 | course_01 leg 1 (620 px): from the pad-1 lip, hold boost aimed at the pad-2 centre | vertical miss ≤ **150 px**; arrival speed ≤ 900 (baseline ~520 px low: record) |
| M5 | Aim 11° up for 1.0 s after reaching cap | \|Δy\| ≤ 60 px; horizontal speed 790–840 |
| M6 | Trampoline bounce with boost held, aim horizontal | apex within ±5% of 662 px (G2). With aim up, post-press speed ≥ 0.9 × launch (§3.2) |
| M7 | 60 s fuzz (random aim and boost, no bounces, supers or smashes) | flight speed while boosting ≤ 1.05 × √(cap² + 160²) (≈ 857 px/s for the standard goat); no frame where grip raised \|v\| (debug counter = 0) |
| M8 | Victim smashed at 3000 away from stage, boosts back on the first free frame | speed after that frame ≤ 800 (25% chop preserved, E2) |
| M9 | Black Hole pull escape time (fueled, aim away) | within ±10% of baseline × 4600/5400 |

### 8.3 Bots (4-bot brawl L3/L2/L3/L4, LIVES 1, powerups default, **40 stages before + 40 after**, shared arena shuffle seed)

| ID | Pass |
|---|---|
| B1 | Super-as-movement share **≤ 10%** after, AND ≥ 60% relative drop from baseline (Wilson CI reported) |
| B2 | 100% of `recovery_*` bot supers satisfy BR-4 at fire time (log audit). Recovery supers are ≤ 20% of bot supers |
| B3 | 100% of `attack` / `finisher_attack` supers had LOS clear and target ≤ 1070 px. 0 supers from refuel, retreat or objective states |
| B4 | Offensive smash conversion ≥ baseline − 3 pp |
| B5 | Boost time / air time ≥ 35% per bot (fantasy check: airborne *and* using the jetpack) |
| B6 | `stuck_episodes`, `underside_boosted`, `blocked_ascent` per stage ≤ baseline × 1.1 |

### 8.4 Human-sim
- **C1. PadHopper** (ephemeral provider, `.txt` source under `tools/out/wk/`, same rules as the wk20a HumanSim). Contract:
  - Targets the next pad in course order and aims per BR-2.
  - Aim wobble ±0.15 rad, re-rolled every 0.35 s.
  - 0.22 s reaction lag; releases boost 0.05 s late; **super disabled**.

  Pass: **≥ 4/5** completions on tut_01, tut_03, tut_04, course_01, course_03, course_04, course_05, n2_slalom,
  n2_refuel_ridge, n2_wall_climb (interior route). Report baseline vs after.
- **C2.** course_02_fuel_line: with super allowed ≥ 4/5. Also report whether boost-only clears the finale (informational;
  the level-designer rules).
- **C3.** Tank Run 620 px legs: median leg time ≤ **0.95 s** (predicted 0.85). Median fuel per leg ≤ 27.
- **C4.** HumanSim-regular brawl (wk20a §6.2 preset, 3 HumanSim + 1 CPU L2, 16 stages): HumanSim super-as-movement share
  ≤ 20%. This is the Phase 2 trigger (§4.3).

### 8.5 Pacing, sports, Trials, evidence
- **D. KO pacing** (the §8.3 batch):
  - credited KOs per combat-minute ≥ **0.85×** baseline
  - median stage length ≤ **1.2×** baseline
  - bot self-KO share not up > 5 pp
  - report A9 one-shot share (2026-07-19 watch item)
- **E. Sports** (2v2 L3 all-bot, 10 rocketball + 6 dropshot matches, before and after):
  - goals per minute ≥ 0.9× baseline
  - median normal-touch ball exit speed ≥ 0.85× baseline
  - ball-crowding and motion health no worse than the 2026-07-19 QA numbers
- **F. Trials sweep:** every course in `course_sets.json` is loaded and completed once by QA (super allowed). **0 newly
  impossible courses.** The ORBIT set is hand-driven with a written note per course.
- **G. WK-93 recordings, before and after**, 20 s of a 4-bot brawl on islands_void, grassy_expanse and one radial arena
  (atoll). Each comes with:
  - a contact sheet
  - a per-frame overlay (boost vs super vs aim state per goat)
  - a trajectory plot

  **Look at them** (validate motion, not outcomes): bots must visibly carve turns and glide gaps, with super rings
  clustering around rival contacts, not around empty sky.

---

## 9. Fallback ladders (pre-registered; use in order, one step at a time, re-measure after each)

| Symptom | Knob 1 | Knob 2 | Forbidden |
|---|---|---|---|
| KO pacing fails D (kills too rare / stages too long) | `boost_grip_decel_max` 3000 → 2000 (slower fall-arrest; turn becomes ~0.42 s) | `smash_sting_fuel` 30 → 40. The 2026-07-03 rejection was on the laser-SD rate, and the laser-SD timer no longer exists (DECISIONS 2026-07-03 match redesign) | hitstun triad, `dmg_launch_mult`, super impulse, kill target, `boost_enter_keep` value |
| Flight feels on rails / weightless (CD) | `boost_grip_rate` 8 → 6 (sag 213 px/s, turn ~0.4 s) | `boost_grip_speed_max` 1300 → 1000 | tank or gravity changes |
| Turns still feel slow (M2 fail or CD) | `boost_grip_rate` 8 → 10 | `boost_grip_decel_max` 3000 → 3600 | raising `normal_boost_max_speed` past 800 (INV-1) |
| B1 not met | brain: tighten BR-3 (cone ≤ 0.5 rad on the led solution) | Phase 2 `super_hit_refund` 30 | super cost / cooldown hikes |
| Trials fuel lessons trivialised | geometry: widen gaps 60–100 px | move refuel pads | `tank_seconds`, `fuel_per_bounce` |
| Sports headers limp (E fail) | `BALL_DRIVE_GAIN` 0.9 → 1.05 | — | boost cap |

---

## 10. Creative-director feel check (required sign-off: SHIP or a numbered FIX list)

Play it rendered with human-style input (pad), watch the WK-93 before/after sheets, and answer in plain language:
1. **Does flying feel like "I point, I go there"?** Can you thread a 600 px gap onto a small pad on the first or second try?
2. **Is the super now an event:** a shot you watch for and dodge, not the commute?
3. **Does the bounce still feel like the bounce?** Full lift, supercharge pop, never "flattened".
4. **Did recovering get boring** (too safe), or is the scared-then-saved beat still a gamble?
5. **Do bots look like competent pilots** (carving, gliding, committing supers at rivals), not super-spamming pinballs?
6. TowerFall bar: does movement make you feel *capable*?

Any "no" is a FIX, regardless of green numbers (GAME_ESSENCE).

---

## 11. Change control

- **Class:** a mechanic change (grip, directional entry keep, bot brain) plus tuning (accel, cap, min fuel, finisher
  floor). Full loop: this spec → build → rendered QA (§8) → CD (§10) → Director commit plus STATUS.
- **Files (for the programmer):**
  - `Tuning.gd`: the new block "Flight steering (WK-95)" with `boost_grip_rate`, `boost_grip_decel_max`,
    `boost_grip_speed_max` and `boost_enter_keep_directional`, plus the changed values and their comments. Document the
    inequalities in both comments: min fuel against `fuel_per_bounce` (equality); cap × BOOST_MAX < 900.
  - `Player.gd`: the boost branch of `_physics_process`, plus the stale "760 × 1.12 = 851" comment.
  - `CharacterProfile.gd`: the BOOST_MAX comment.
  - `InputBot.gd`: `_decide`, `_danger_recover`, purpose tags, constants, gravity-compensated aim, the
    `wk95_brain_enabled` switch.
  - `PartyMatch.gd`: telemetry (§8.1).
  - No level JSON or Ball.gd change in Phase 1.
- **DECISIONS entry (draft for the Director):**
  > **2026-11-14 FLIGHT = TRAVERSAL, SUPER = ATTACK (owner ruling, WK-95).** Normal boost gains a steering grip
  > (perpendicular-velocity damping while thrusting; never removes climb, never adds speed, off above 1300 px/s and while
  > black-hole-pulled). A fresh boost keeps forward momentum. Accel 4600→5400, cap 760→800 (INV-1: 896 < 900).
  > `super_boost_min_fuel` 5→10, superseding the 2026-07-02 "even 5%" clause of the un-charged-super hypothesis. The
  > un-charged, drain-all, constant-impulse super, the lockout and the aim stay. Bots travel by flight; they super only in
  > an attack window (range ≤ 1070, LOS) or as a last-resort recovery (hot launch / unreachable). Protected constants
  > untouched. Reopen if: KO pacing fails after both §9 knobs; an owner reversal; or the CD rules flight "on rails" after
  > grip-rate 6.
- **Findings routed (not WK-95 scope):**
  1. The post-hitstun boost chop (E2) is a hidden pillar of the recovery model. Route to the WK-57 lethality review.
  2. A fuel-gauge super-ready notch (§6.4) goes to ui-ux-designer.
  3. Trials `design_intent` numbers go stale (§6.1) and need a level-designer docs refresh.
  4. Ball.gd feel constants sit outside Tuning (INV-6).

## 12. Out of scope
Air drift and bounce tuning; super impulse, aim or telegraph (WK-94 owns aim motion); lethality constants; camera; new
character levers; any per-level physics override.
