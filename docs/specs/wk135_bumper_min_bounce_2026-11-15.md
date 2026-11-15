# WK-135: Bumpers kick, they never cradle (bumper minimum rebound + floor-face refunds + liveness) (2026-11-15)

**Owner:** game-designer (spec + rulings) · **Builds it:** gameplay-programmer · **Verifies:** qa-playtester + creative-director
**Backlog:** WK-135 [P1][M]. This spec is also the root fix for WK-133 (Singularity core pin) and WK-134 (`surface_bounced`
flood). It unblocks WK-128 part (b) and gives the sports economy ruling.
**Source:** WK-128 build (E17 finding). Evidence: `tools/out/wk/WK-128_mech_spec.json` and `WK-128_mech_altB.json` (A9),
`WK-128_brawl_summary.json` (B0/B2/BB0-BB2), `WK-128_sports_summary.json` (S0-S2), `WK-128_probe_results.txt`.
**Inputs read:** VISION · GAME_DESIGN (Pillar 2, §4.1 min-bounce, §15 bumper tiles) · FEEL_REFERENCE §1, §2.1, §2.4 ·
WK-128 spec (§2.2, §4.2 F1-F7, §6 E17, §10 Alt B, §11) · `BounceResolver.gd` · `Player.gd` (`_physics_process`,
`_resolve_bounces`, `_on_bounced`, `_wk128_contact_pays`, `refund_rearm_pending`) · `Tuning.gd` (bounce + WK-128 blocks) ·
`InputBot.gd` (`_decide` refuel dive, `_land_target`, BR-128) · `GravitySource.gd` · `LevelLoader._build_platform` ·
`Ball.gd` · `levels/singularity.json`, `black_hole_brawl.json`, `sports_court.json` · skills architecture-contract
(INV list), game-feel-reference §3-4, tuning-and-flags (DNT + invariants), analysis-toolkit (recipes 1, 2, 4, 6).
**All numbers are pen-and-paper (verified: static).** Values: g = 1600 (flat), Singularity well g = 1000, 120 tps,
`bumper_restitution` 0.86, boost accel 5400, supercharge thrust x1.6 = 8640, drain 28.57 fuel/s. No game was run for
this spec. QA confirms the numbers in §9.

---

## 0. Summary

1. **Root cause.** Tier faces *replace* your outgoing normal speed with a launch height, floored at `min_bounce_height`
   (48 px, about 392 px/s). That floor is how INV-11 is enforced. Bumper faces instead *scale* your incoming speed
   (`reflect x 0.86`) and have **no floor**. Multiplying by a restitution below 1 is geometric decay. Under gravity, a
   body on a bumper top bounces lower and lower in a converging series (Zeno). At 120 tps it reaches a fixed point where
   one tick of gravity (13.3 px/s) is returned as 11.5 px/s. The body sits still (A9: last-second y range 0.003 px) and
   re-contacts every 1-4 ticks. Bumpers used to be elastic (FEEL_REFERENCE e = 1.0), and an elastic floor never
   decays. When restitution was lowered to 0.86 to kill the boost-wall speed pump, nobody added the floor. Bumpers were
   imagined as walls and ceilings. But a rect bumper has a top, and a round bumper core is *all* top.
2. **Fix, physics (WK-135a).** Every bumper contact leaves at **at least `sqrt(2 x |g_local| x 48)` along the face
   normal** (392 px/s on flat levels, 310 px/s in Singularity's well), and never below a 250 px/s absolute floor.
   Above the floor, the ricochet is byte-for-byte today's `x 0.86`. So supers, launches and the wall-return shot are
   untouched. A resting goat becomes a goat hopping 48 px every 0.49 s, the same INV-11 hop a tier gives.
3. **Fix, economy (WK-135b).** Bumper faces are classified by gravity at the contact. A **floor-class** face (top of a
   block, any face of a round core) pays like a tier floor: once per real bounce, no speed gate. **Wall-class** faces
   keep WK-128's hard-hit gate (≥ 900). Ceilings pay nothing, as today. A new **liveness valve**
   (`refund_rearm_timeout` 1.5 s) guarantees that no face stays unarmed forever. That valve is what un-hangs a 0-fuel
   goat on the Singularity core.
4. **Fix, bots (BR-135, required).** Bots never thrust-pin a bumper. The WK-133 pin is a refuel dive aimed into the
   core while boosting, and a minimum rebound alone only turns it into a 10 px buzz.
5. **Unblocks WK-128 (b):** `refund_rearm_frac` 0.9, `refund_rearm_min_px` 60, `refund_rearm_bumper_px` 200 and
   `bumper_refund_min_speed` 900 (wall-class only) turn ON. Alt B's `bumper_refund_cooldown` stays OFF.
6. **Sports ruling:** sports **keeps a refund source, and it is the BALL, not the walls**. Each accepted live touch
   pays +20, at most once per player per 1.0 s (≤ 20 fuel/s, below the 28.6/s drain, so it can't be farmed). No
   surface refund rule forks per mode.
7. **Protected constants untouched:** `bumper_restitution`, `min_bounce_height`, `fuel_per_bounce`, `fuel_per_bumper`,
   `max_speed`, the hitstun triad and the smash gate.

---

## 1. Player fantasy and pillar check

**Fantasy:** *"Bumpers are pinball pop-bumpers. Touch one and it spits you off. BOING."* A bumper is never a ledge to
park on, never a wall to lean on for fuel, and never a black hole you get glued to. Slam it hard and it pays you
back. Land on top of one and it bounces you like any floor.

**Core verbs (GAME_ESSENCE):**
- **BOUNCE (protected, fixed):** every surface now kicks.
- **FLY (protected):** no thrust change.
- **SUPER-SMASH (protected):** ricochets above 456 px/s incoming are unchanged (0.86 x 456 = 392).
- **RECOVER:** bumper tops become honest refuel floors again (per real bounce). That is slightly *more* generous than
  WK-128 as specced and less than what ships today.

**Pillars:**
- **P2 Constant motion: fixed.** Today you can stand on a bumper. Fix 1 makes that impossible. Fix 3 removes the
  stranded state, a 0-fuel goat stuck on a bumper with nothing it can do.
- **P5 Readable chaos:** a 48 px hop is ~22 screen px at zoom 0.46, which reads as "bouncing". A 0.003 px rest or a
  10 px buzz reads as "stuck/glitched". The pin screenshot in WK-133 is exactly this readability failure.
- **P3 Physics comedy:** the core becomes a lively pinball hub, as its JSON design intent promises, instead of a
  graveyard where four goats lie squashed.
- **INV-11 wording** (architecture contract): *"No standable ground / no turtling. Surfaces never let you settle."*
  Today the min-bounce floor lives only in `BounceResolver.resolve()` (tier path). This spec puts the same guarantee
  on the bumper path, so INV-11 holds for **every** surface type.

---

## 2. Root cause (detail)

### 2.1 The two resolvers

| | `resolve()` (tier) | `resolve_bumper()` (bumper) |
|---|---|---|
| Outgoing normal speed | **replaced:** `sqrt(2·g·max(h_tier, 48))` | **scaled:** `0.86 x incoming` |
| Floor | `min_bounce_height` 48 px (INV-11, BounceResolver.gd:17) | **none** |
| Gravity-aware | yes (`gravity_mag` param) | no |
| Behaviour as incoming → 0 | still launches at ≥ 392 px/s | outgoing → 0, so the body settles |

### 2.2 How fast a body settles today

Settling time for a body dropped from height h onto a bumper top, with e = 0.86 and t0 = sqrt(2h/g):
`T = t0 x (1 + e)/(1 − e) = 13.3 x t0`.
- Drop of 100 px at g = 1600: t0 = 0.35 s, so it is at rest in ~4.7 s.
- Drop of 30 px: ~2.6 s.
- A goat that slides onto a top with almost no normal speed rests in < 1 s.
- Measured (A9, flat bumper top, no input): at rest, last-1 s y range **0.003 px**, 157 contacts. That is 157 refunds
  with gates OFF.

### 2.3 Thrust-pinning (WK-133's actual mechanism)

On Singularity, `InputBot._decide()` sends a bot that is below its refuel floor along the local pull, and in that well
the pull leads to the bumper core. The bot boosts whenever it moves away from the surface (`velocity·rdir < −60`).
Each tick: thrust (45 px/s per tick) plus pull pushes the bot in, the core reflects ×0.86, it moves out, and it boosts
back in. The result is a contact on almost every tick at 38-95 px/s, which matches the WK-132 screenshot (~100
`surface_bounced`/s at 38-95 px/s). **This is not resting. It is active pinning,** and a minimum rebound alone only
turns it into a buzz: 310-392 px/s out, back in after `2v/(5400 + 1000)` ≈ 0.1-0.12 s, a 8-12 px excursion, ~9 contacts/s.
So BR-135 (§5) is required to fix WK-133. WK-135a alone is not enough.

### 2.4 Why it hard-locked WK-128 (b)

With the gate ON, a goat that reaches 0 fuel on the core stays there forever:
1. The core never pays: impacts are below the 900 F2 gate, and its face is unarmed (F1, 200 px).
2. It can't fly (`boosting` needs fuel > 0).
3. Air drift can't climb out of a 1000 px/s² well.

Stages never ended. The gate-ON brawl runs show the same signature:

| Run | Gate | Median stage | Credited KO/min | Time below refuel floor |
|---|---|---|---|---|
| B0 | OFF | 12.9 s | 10.03 | 50% of alive time |
| B2 | ON (48 stages recorded) | 17.5 s | 6.83 | 65% |
| BB1 (bumper arenas) | ON | — | 8.03 (vs BB0's 9.53) | — |
| BB2 (bumper arenas) | Alt B | 20.5 s | 6.23 | — |

This pattern fits goats stranded at low fuel on bumpers. It is not proven to be the cause. §9 B/D re-measure it.

### 2.5 Every source of resting contact (for WK-134)

1. Rest on a bumper top or core (passive). Fixed by §4.1.
2. Thrust-pin against a bumper (active). §4.1 turns it into a ≤ 12/s buzz. BR-135 removes the bot cases.
3. Tier faces can't rest (they launch at ≥ 392). A thrust-dribble on a tier is ~4.5 contacts/s, a real bounce each
   time.

So WK-134's flood is a symptom of WK-135, not a separate signal bug (§7.6).

---

## 3. Options considered

| Option | Verdict | Why |
|---|---|---|
| Raise `bumper_restitution` back to 1.0 | REJECT | Reopens the boost-wall speed pump (invariant #9). Rest also still happens at tick resolution with e = 1 under thrust-pin |
| Reuse `min_bounce_height` inside `resolve_bumper` | REJECT (as a shared constant) | Same number, but it couples a tier constant to the bumper path. Give the bumper floor its own constant (default = the same 48) |
| **Kick floor:** outgoing normal ≥ `sqrt(2·|g|·h_kick)`, ≥ 250 absolute | **CHOSEN** | The INV-11 hop on every bumper. Gravity-field correct (INV-1). Inactive above 456 px/s incoming, so ricochet play is untouched |
| A big floor (≥ marshmallow 120 px, 620 px/s) | REJECT | Turns bumper tops into trampolines and blurs tier readability. Walls would shove drifting players at 620 |
| A small floor (16 px, 226 px/s) | REJECT | 7 screen px at zoom 0.46 reads as jitter or rest. Fails P5 |
| An emit threshold on `surface_bounced` (WK-134's literal ask) | REJECT as the fix | It hides the symptom and leaves the goat standing |
| Make the Singularity core a tier (spring) | REJECT | Loses the ricochet identity: supers and launched victims would be absorbed instead of caroming (the JSON intent: "violent pinball hub") |
| Per-level `min_rebound` "kicker" on the core | DEFER | Unnecessary once floor-class faces pay and the liveness valve exists. Record it as a level-design tool for later |
| Floor-class bumper faces refund nothing ever | REJECT | Recreates the stranded 0-fuel goat on round cores. No payout path exists inside a well |
| **Floor-class bumper faces pay under tier rules (F1, no F2)** | **CHOSEN** | Gravity powers that bounce, not your thrust, so the WK-128 pump argument (§3, "a bumper only reflects your own speed") doesn't apply. Strictly less than what ships today |
| **Liveness valve: a face re-arms after `refund_rearm_timeout`** | **CHOSEN** | One rule guarantees no permanent lock on any face type. Income ≤ 13.3/s, below natural trampoline income (17.2/s) and below drain |
| Sports: Alt B wall cap (one bumper refund per 1.0 s) | REJECT | Still a wall pump (≤ 20/s), and it rewards wall-hover keepers next to their own goal (a P2 camp). Measured goals −31% anyway |
| Sports: a per-mode surface refund rule | REJECT | Forks the economy core (INV-13 spirit, WK-128 §10 "never a per-mode refund rule") |
| **Sports: ball-touch refuel** | **CHOSEN** | Fuel comes from engaging the objective. It's an object source like a Trials refuel pad or Unlimited Boost, not a fork of surface rules |

---

## 4. The change

### 4.1 Kick floor (WK-135a, physics). Rules K1-K6

- **K1:** `BounceResolver.resolve_bumper(velocity, normal, gravity_mag)` gains the `gravity_mag` parameter, mirroring
  `resolve()` (INV-1, INV-2: the resolver stays body-agnostic). Steps:
  1. `out = velocity.bounce(n) x bumper_restitution` (unchanged).
  2. `v_kick = max(sqrt(2 x gravity_mag x bumper_min_rebound_height), bumper_min_rebound_floor)`.
  3. If `out·n < v_kick`, then `out += n x (v_kick − out·n)`. Only the normal component is raised; the tangential
     component keeps its ×0.86.
- **K2:** the kick floor applies to **every** bumper face (floor, wall, ceiling, round core) and every body state
  (neutral, stunned, super-aiming, black-hole-pulled). Physics is state-agnostic, just as `resolve()` is.
- **K3:** for round colliders the normal is the true radial (already the case, since `"round"` meta skips axis-snap).
  The floor acts along the radial.
- **K4:** if `bumper_min_rebound_height` is 0 the floor is OFF (A/B switch), and the bumper path is byte-for-byte
  today's.
- **K5:** the tier path (`resolve()`) is not touched.
- **K6:** the caller (`Player._resolve_bounces`, bumper branch) passes `g.length()`. `rebound_speed` is read **after**
  the floor (it feeds `bounced_juicy` and the F1 launch height).

**Predictions (K):**
| Case | Today | After |
|---|---|---|
| Drop onto a flat bumper top, no input | rests (≤ 5 s) | hops forever, apex **48 ± 4 px**, period **0.49 s**, ≤ 2.2 contacts/s |
| Drop onto the Singularity core (g 1000), no input | rests | hops, altitude **48 ± 4 px**, period 0.62 s |
| Drift into a bumper wall at 340 (no boost) | leaves at 292 | leaves at **392 ± 5** (normal), returns after ~0.6 s |
| Hold boost into a bumper wall (A6 straight) | ~100 contacts/s | **≤ 12 contacts/s**, excursion 9-14 px (supercharged 8640 → 11/s; plain 5400 → 7/s) |
| Boost up into a bumper ceiling, slow | reflect ×0.86 | pushed down at ≥ 392. Same no-refund bonk, but it can't pin |
| Any contact with incoming ≥ 456 px/s (supers, launches, wall-return shot) | ×0.86 | **unchanged** (floor inactive) |

### 4.2 Face classes and refunds (WK-135b, economy). Rules C1-C6

- **C1 Classification**, at the contact, using the gravity at the contact point (the same vector `_on_bounced` already
  computes): `up = −g_dir`.
  - `n·up > bumper_floor_dot` (0.5) → **FLOOR**
  - `n·up < −0.5` → **CEILING** (the existing underside rule: no refund, unchanged)
  - otherwise → **WALL**
  - Round cores in their own well are always FLOOR (the radial normal opposes the radial pull).
- **C2 Floor-class bumper faces pay under the TIER rules** (WK-128 F1 with the build's re-base on blocked contacts):
  - Re-arm distance `E = max(refund_rearm_min_px, refund_rearm_frac x h_launch)`, where `h_launch` comes from the
    post-floor `rebound_speed`.
  - No F2 speed gate.
  - The amount stays `fuel_per_bumper` (20).
  - Consequence: a real fall onto a bumper top pays on each bounce until the decaying ricochet drops below ~67 px
    (60 / 0.9). Kick-floor hops (48 px) never re-arm by distance (#13 / new #15).
- **C3 Wall-class bumper faces keep WK-128 exactly:** F2 (`bumper_refund_min_speed` 900 incoming) + F1 (200 px).
- **C4 Liveness valve (all paying faces, tier and bumper, every class):** a face that paid ≥ `refund_rearm_timeout`
  (1.5 s) ago re-arms, however little you moved.
  - This is the only time-based rule. It is a safety valve, not an income source: ≤ 20 / 1.5 = 13.3 fuel/s.
  - Natural trampoline bouncing earns 17.2/s and drain is 28.6/s, so the valve never beats bouncing or holding.
  - Wall-class bumper faces still need F2, so the valve never makes a cruise-speed wall pay.
- **C5 Unchanged:** F3 (supers always armed), F4 (stunned dry reflect / underside: no pay and no arm effect), F5
  (supercharge thrust only on paying contacts), F7 (amounts), and the relight bill (part a, already ON).
- **C6 `refund_rearm_pending()`** follows the same arm state, so bots see C2/C4.

**Predictions (C), gates ON:**
| Case | WK-128 spec (gate ON, no WK-135) | After |
|---|---|---|
| 0-fuel goat resting on the Singularity core | stranded forever (stage hang) | hops; **fuel ≥ 10 within 2.0 s** (valve 1.5 s + one hop); a bot leaves the core within 6 s |
| Fall 300 px onto a flat bumper top, no input | 0-1 refunds, then rest | refunds on bounces at 300, 222, 164, 121, 90, 67 px → **5-6 refunds (100-120 fuel)**, then 48 px hops paying once per 1.5 s |
| Thrust-dribble on a bumper top | rest/buzz, 0 pay | ≤ 1 refund per 1.5 s (≤ 13.3/s) while dribble costs 20-28/s → net < 0 |
| Wall hug, bumper (A6) | 0-1 refunds | 0-1 refunds (F2), net −28.6/s |
| Wall hug, tier side (A6) | ≤ +20 per 1 s | ≤ +20 per 1.5 s |
| Wall-return shot (6d) | ≥ 9/10 | ≥ 9/10 (supers ≥ 900, F3) |

### 4.3 Sports refund source (WK-135c). Rules S1-S4

- **S1:** each **accepted live touch** (`Ball.touched`, which already exists, respects the ball's 0.12 s touch
  cooldown and is only emitted while `live`) grants the toucher `sports_touch_fuel` (20). There is a per-player cooldown
  of `sports_touch_fuel_cd` (1.0 s).
- **S2:** the grant goes through **one Player entry point**, e.g. `grant_fuel(amount, source: StringName)`. The source
  is tagged for telemetry (`refunds_ball`). It respects the stun gate: a touch while in opponent-inflicted hitstun pays
  nothing, matching the dry-reflect doctrine. It does not touch supercharge, the relight state or arm state.
- **S3:** SportsMode owns the wiring (it already listens to `Ball.touched` for stats). TRIALS puzzle balls don't grant
  fuel (they aren't SportsMode).
- **S4:** surface refunds in sports follow exactly the C rules, like every other mode.
  - On `sports_court`, the side walls are WALL class (F2), the ceiling is CEILING (nothing), and the two mid-bumper
    tops are FLOOR (pay per real bounce).
  - Floors are trampoline tier, as today.

**Why the ball (ruling):** sports is the movement game with the kill replaced by the goal. In S0 the bots effectively
had unlimited flight from wall-grinding: ~3400 fuel/bot-minute of income against a 1714/min maximum spend. The
owner's fun flag was earned under that accidental regime. We keep high flight time, but we pay it out for touching the
objective, so the fuel ding means "you played the ball". A wall-pump would reward the keeper who hovers beside their
own goal wall, which is a P2 camp. Farm check: ≤ 20/s, below the 28.6/s drain, and the only way to farm it is to keep
hitting the ball, which *is* the game.

**Amendment to WK-128 §10/§12 (recorded):** the "never a per-mode refund rule" ban still holds for **surface** refund
rules. Mode **objects** may grant fuel through `grant_fuel`, the same category as Trials refuel pads and powerups.

### 4.4 Constants (`Tuning.gd`: extend the WK-128 "Fuel integrity" block plus the bounce block)

| Constant | Value | Rationale |
|---|---|---|
| `bumper_min_rebound_height` | **48.0 px** | = the tier min-bounce hop, so INV-11 means the same thing on every surface: ~0.44 H, ~22 screen px at zoom 0.46, a 0.49 s rhythm at g 1600. Its own constant so `min_bounce_height` stays untouched. **0 = OFF** |
| `bumper_min_rebound_floor` | **250 px/s** | Absolute floor for weak or zero fields (= `soft_bump_min`, "never slower than the softest shove"). Inactive wherever g ≥ 651 (all authored fields today) |
| `bumper_floor_dot` | **0.5** | Same threshold as the existing underside test (`_on_bounced`, `> 0.5`), so the three classes partition cleanly |
| `refund_rearm_timeout` | **1.5 s** | Liveness valve. ≤ 13.3 fuel/s < natural trampoline 17.2/s < drain 28.6/s. Above every natural bounce period except spring (1.55 s, which re-arms by distance first). **0 = OFF** |
| `bumper_floor_pays_as_tier` | **true** | A/B switch for C2 (false = floor-class bumpers use the wall rules) |
| `sports_touch_fuel` | **20.0** | = one trampoline bounce. Invariant #2 holds: one touch re-arms a super |
| `sports_touch_fuel_cd` | **1.0 s** | Caps the source at 20/s < drain 28.6. **0 fuel = OFF** |

**WK-128 (b) values turned ON by this item:** `refund_rearm_frac` 0 → **0.9**, `refund_rearm_min_px` 0 → **60**,
`refund_rearm_bumper_px` 0 → **200**, `bumper_refund_min_speed` 0 → **900** (now wall-class only),
`bumper_refund_cooldown` stays **0** (Alt B not adopted). `boost_relight_*` is already ON and unchanged.

### 4.5 Invariants (append to the Tuning comment and to skill tuning-and-flags)

- **#15** `bumper_min_rebound_height` (48) < `refund_rearm_min_px` (60): kick-floor hops never pay twice by distance,
  only through the valve.
- **#16** `fuel_per_bumper / refund_rearm_timeout` (13.3) and `fuel_per_bounce / refund_rearm_timeout` (13.3) are
  both < natural trampoline income (20 / 1.16 = 17.2) < `normal_boost_drain()` (28.6). The valve is never better than
  bouncing. Re-check if the timeout, refund amounts, gravity or trampoline height change.
- **#17** `sports_touch_fuel / sports_touch_fuel_cd` (20) < `normal_boost_drain()` (28.6).
- **#9** `bumper_restitution` < 1 (unchanged, still holds). The kick floor adds energy only below 456 px/s incoming, so
  it is bounded at 392 px/s and can never pump speed.
- **#12** unchanged (`bumper_refund_min_speed` 900 > 896), now scoped to wall-class faces.

### 4.6 A/B switches (gbplay eval, RAM-only)

- `Tuning.bumper_min_rebound_height = 0.0`: today's ricochet with no floor.
- `Tuning.bumper_floor_pays_as_tier = false`: floor-class bumpers use the wall rules (the WK-128 spec as written).
- `Tuning.refund_rearm_timeout = 0.0`: no liveness valve.
- `Tuning.sports_touch_fuel = 0.0`: no ball refuel.
- `InputBot.wk135_no_pin = false`: BR-135 off (baseline).

### 4.7 Protected constants (recipe 1)

| Item | Status |
|---|---|
| `bumper_restitution` 0.86, `min_bounce_height` 48, tier heights, `tangential_retention`, `bounce_di` | **untouched** |
| `fuel_per_bounce` / `fuel_per_bumper` 20 (DNT), `tank_seconds`, `fuel_max` | **untouched** |
| `max_speed`, super impulse/min fuel/lockout, hitstun triad, `smash_impact_min`, `smash_self_retain` | **untouched** |
| Smash license, dry reflect (F4), underside rule | **untouched** |
| Ball physics (`Ball.gd` PhysicsMaterial 0.85, mode-owned) | **untouched** (§6 E10) |

---

## 5. Bots (BR-135, required; `InputBot.gd`)

- **BR-135a, refuel target class:** a refuel dive (flat and radial) targets a face that can pay (C rules): any tier
  floor, a floor-class bumper top, or a round core. Wall-class bumper faces are never refuel targets. On Singularity
  that leaves the core and the outer faces of the shells. The core is legal **only** as a bounce: BR-128 (ride a paying
  bounce to its apex) applies unchanged.
- **BR-135b, pin breaker:** if the bot has made ≥ `bot_pin_contacts` (4) contacts with the **same bumper face** within
  0.5 s while thrusting into it (`aim·n < −0.5`), it releases boost for one reaction tick and re-plans with that face
  excluded as a target for 1.0 s. Constants go in the Tuning bot block.
- **BR-135c, radial landing:** `_land_target` (radial branch) hovers `VOID_LAND_MARGIN` above the surface along the
  pull. When that surface is a bumper core, the bot must not hold thrust into it. Reuse BR-135b.
- **Motion-health counters** (`round_stats` / `bot_motion_health()`):
  - `bumper_pin_episodes`: ≥ 6 contacts with one bumper face within 1.0 s.
  - `rest_episodes`: speed < 20 px/s for ≥ 0.5 s while touching any surface. This is a pathology and must be **0**.
  - `stationary_all_bots_s`: the longest window in which every living bot moved < 60 px.

---

## 6. Edge cases

- **E1 Stunned / ragdoll bodies:** the kick floor applies (K2: physics is state-agnostic). Still a dry reflect: no
  refund, hitstun not cleared, no arm/relight effect (F4). A tumbling victim on a bumper top now hops instead of
  settling during its ≤ 0.55 s stun. Victims launched toward edges arrive far above 456 px/s, so the floor is inactive
  and kill pacing is unaffected. Prediction: post-smash survival ±2 pp.
- **E2 Super aim-hover on a bumper:** kicked at ≥ 392, then damped by `super_aim_damp` 2.5/s. The 2 s cap still
  auto-fires. Nothing can hover-rest.
- **E3 Black Hole channel:** the channeler zeroes velocity and early-returns (never contacts), as today. A brief active
  airborne power is allowed (INV-11 scope note). Pulled victims against a bumper buzz: out at 392, back after
  `2 x 392 / (2600 + g)` ≈ 0.19 s, 18 px excursion. That's E8 in WK-128, intended.
- **E4 Round cores (Singularity, black_hole_brawl body_r 120, moon cores with tier "bumper"):** the floor acts along
  the true radial (K3). The face is floor-class (C1), with altitude re-arm (WK-128 F1 round rule). A 0-fuel goat is
  freed by C4 within ~2 s.
- **E5 Moving bumpers** (MovingPlatform, DropTile, DestructibleBlock, KeyDoor bumper meta): absolute velocity, as the
  tier path does today. A bumper rising under a goat at ≤ 200 px/s can't out-run a 392 kick, so no carry. A bumper
  moving faster than 392 toward a goat pushes it the way it does today, and the next contact kicks.
- **E6 Corners (bumper top + bumper wall):** two contacts in one tick; `_resolve_bounces` returns after the first, as
  today. The corner case is that the first-reported face gets the kick, then the next tick resolves the other. QA
  watches for corner wedging (`rest_episodes` covers it).
- **E7 Bumper ceilings over tier floors (low tunnels):** the ceiling kick floor plus the tier min-bounce make a fast
  ping-pong. Same as WK-128 E9: the tier pays once per real bounce, the ceiling never pays, so you must fly out (P2).
- **E8 Zero-g pockets:** the 250 px/s absolute floor applies. A body only reaches a zero-g wall by moving, so this is
  only a guard.
- **E9 Thrust-pin by a human:** allowed physically (an ≤ 12/s buzz that drains the tank, pays 0 on walls and ≤ 13.3/s
  on tops). It's readable and self-punishing. No input override for humans.
- **E10 The sports/trials Ball:** a RigidBody with its own PhysicsMaterial. It doesn't use `resolve_bumper` and isn't
  covered by INV-11 (a ball rolling on a floor is gameplay). Players don't collide with it. A goat kicked off a wall at
  392 toward a ball gives a touch impulse of 500 + 0.9 x 392 = 853. That's slightly livelier wall play. **Finding,
  routed:** the ball may come to rest on a mid-bumper top (`sports_court` x1000/x1660, 140 px wide vs radius 60). QA
  reports `ball_rest_on_bumper` episodes. If > 0, the level-designer crowns those blocks. Don't change ball physics.
- **E11 Head-bounce and ghosts:** unchanged. GhostPuff calls `_on_bounced` with a null collider, so it's a legacy pay
  path that C rules don't affect.
- **E12 Radial-well air drift (pre-existing, finding):** air drift brakes screen-x toward the stick target at
  1300 px/s². That beats Singularity's 1000 px/s² horizontal pull, so a neutral-stick goat on the core's equator
  doesn't feel the pull sideways. This isn't caused by WK-135 but affects bot motion there. Route to gameplay-programmer
  as a gravity-relative drift question (INV-1 hygiene). Out of scope.
- **E13 Respawn:** clears arm memory and timeout clocks (WK-128 E2).
- **E14 Trials bumper-top ledges:** floor-class tops now pay per real bounce (with gates ON). Today they pay on *every*
  contact, so no course gains fuel relative to the shipped game. Courses whose intent says "walls refund nothing" are
  about walls, which C3 keeps dry at cruise speed.

---

## 7. Side effects

### 7.1 Brawl recovery and KO pacing
- **Kick floor (gates OFF):** fewer bumper contacts per pin/grind episode, so bumper refunds per bot-stage fall from
  11.5 (B0) by **−40% to −80%**. Bots still have plenty of fuel (B0 income 802/min vs spend 686/min). KO/min within
  ±5%.
- **Full package (gates ON):** compared with the gate-ON runs, stranded goats are gone, so median stage length goes back
  toward B0 (**12.9 s ±15%**) and credited KO/min toward **0.90-1.15x B0** (B2 was 0.68x). Bumper refunds per
  bot-stage: **−70% to −90% vs B0** (tops still pay, walls only on slams). Recovery is a little harder than today on
  bumper walls (F2) and unchanged on bumper tops.

### 7.2 Trials

| Risk | Courses | What changes | Check |
|---|---|---|---|
| MED | n2_wall_climb (chimney, bumper walls) | Plain-flight zigzag gets a 392 kick per graze, more lateral bounce in a 420 px chimney. Gates ON: 0 wall refunds (WK-128 intent) | PadHopper interior ≥ 4/5; drive the zigzag once and report the climb |
| MED | n2_slalom, n2_needle_thread, n2_pinhole, n2_shifting_needle, n2_master_vault, n2_locksmith | Slow brushes of bumper mouths kick out at 392 (may push a pilot off-line) | PadHopper ≥ 4/5; drive each once |
| MED | Courses with bumper **tops** under the route | Tops pay per real bounce (less than today) | Greedy-fail scripts still fail; list every bumper top ≥ 140 px wide on a fuel-limited course |
| MED | g6 ORBIT set (bumper cores, if any) | Core hop + C4 | Drive once; A13 still 100% |
| LOW | p4 cannon set, t_ball_cannon, s3_* | Cannon/ball speeds are far above the floor | Drive once |
| LOW | t_cart_convoy, pendulum/hammer courses (moving bumpers, E5) | | Drive once |

**0 newly impossible courses** is the bar. The geometry is the knob, never the floor value.

### 7.3 Sports (mandatory, §9 E)
- **Kick floor:** wall-grinding bots spend more time off the wall. With gates OFF, fuel stays saturated.
- **Full package:** refund sources become floor (trampoline, ~25/bot-min), mid-bumper tops (C2), hard wall slams, and
  ball touches. Estimate: tier + bumper ≈ 36/bot-min (S1 levels) x 20 = 720, plus touches ~18 paying/bot-min x 20 =
  360. Total ≈ **1080 fuel/bot-min, about a 63% flight duty** (S0 was saturated at ~100%; S1 was ~42%).
- **Prediction (honest risk):** goals/min **0.85-1.0x S0**, touches/min 0.9-1.05x, starved share ≤ 1.3x. The fallback
  ladder (§10) is pre-registered because this one is at risk.
- Own-goal share: unchanged ±3 pp (BR-135 doesn't touch sports roles; WK-108b owns that).

### 7.4 Bots everywhere
- BR-135 changes refuel targeting on bumper arenas: bots stop diving at wall-class faces.
- Predict `stuck_episodes` ≤ 1.1x B0, `bumper_pin_episodes` ≤ 0.1 per bot-stage, `rest_episodes` = 0,
  `dribble_episodes` ≤ 0.2 per stage (WK-128 D5; B0 had 2.9 per stage, mostly bumper contacts at rest).

### 7.5 Presentation
- Bumper squash/FX (`_squash_surface`, `_deform_cd` 0.14 throttle) now fire on hops, ~2/s on a top. Juice
  `bounced_juicy` now carries `rebound_speed` ≥ 310-392 on kicks. That gives a small dust puff per hop, which is
  correct: it *is* a bounce.
- Audio: the WK-132 jitter filter can stay as a belt. It should almost never trigger now.
- §7.5 of WK-128 (the refuel tick on paying contacts) matters more now. Ask ui-ux-designer + sound-designer to include
  ball-touch refuels in the same "ding".

### 7.6 WK-133 / WK-134 disposition
- **WK-133:** closed by WK-135a + BR-135 + C4. Its acceptance is folded into §9 B.
- **WK-134:** do **not** add an emit threshold. Every remaining contact is a visible bounce, and FX should fire on it.
  Close WK-134 when §9 A shows ≤ 12 `surface_bounced` per goat-second in every probe (rest, thrust-pin, Singularity),
  and confirm that fuel refunds no longer depend on contact rate (C rules plus WK-128 F1).

---

## 8. Telemetry the build must add

**Per player per stage:**
- `bumper_kicks` (contacts where K1 raised the rebound)
- `refunds_bumper_floor`, `refunds_bumper_wall`
- `refunds_timeout_rearm` (C4 payouts)
- `refunds_ball` (S1)
- `rest_episodes`, `bumper_pin_episodes`
- `surface_contacts_per_s_max` (1 s window)

**Per stage:** `stationary_all_bots_s`, `ball_rest_on_bumper` (sports).

**Debug:** `qa_valve_over_natural`, which counts intervals where C4 income exceeded 13.4/s. Must be 0 (#16).

---

## 9. Acceptance tests

**Run order (phased, so each lever is measured alone):**
1. **Phase 1 = WK-135a** (kick floor, gates OFF): A, B-off.
2. **Phase 2 = WK-135b + BR-135** (classes + valve, gates still OFF): A-C rows, B-off.
3. **Phase 3 = WK-128b ON + WK-135c**: everything.

Baselines come from the same build through the §4.6 switches. Hash `Tuning.gd` before and after. Scripted probes run
the WK-123/WK-128 way (scratch project copy, never in the repo).

### A. Mechanism (≥ 5 runs each, median)

| ID | Test | Pass |
|---|---|---|
| A9 | Drop from 300 px onto a bumper top, no input, 10 s: `sports_court` mid block (x1000), `long_haul` block, `singularity` core, `black_hole_brawl` core | `rest_episodes` = 0; last-1 s position range ≥ 40 px (flat y / core altitude); steady hop apex **48 ± 6 px**; contacts ≤ 3/s |
| A9b | Gates ON: a goat at 0 fuel placed on the Singularity core, no input | fuel ≥ 10 within **≤ 2.0 s**; with an L3 bot brain it leaves r > 400 within **6 s**, 10/10 |
| A9c | Gates ON: drop from 300 px onto a flat bumper top, no input, 10 s | 5-6 distance refunds, then ≤ 1 per 1.5 s; `qa_valve_over_natural` = 0 |
| A15 | Hold boost into a bumper wall (straight and 45°) and into the Singularity core, 5 s | contacts ≤ **12/s**; excursion ≥ 8 px; refunds as WK-128 A6 (gates ON: 0-1 on walls) |
| A16 | Ricochet unchanged above the floor: shots into a bumper at 600 / 1000 / 2000 / 2800 px/s, 0° and 45° | outgoing = 0.86 x incoming ± 1% (floor inactive) |
| A17 | Drift into a bumper wall at 340, no boost | leaves at 392 ± 5 normal |
| A18 | Stunned victim (scripted smash) onto a bumper top at low speed | hops (no rest); 0 refunds; hitstun not cleared early (WK-128 A11 6c still passes) |
| A19 | WK-128 A6, A7, A8, A10, A11 (incl. 6d ≥ 9/10), A12, A13, A14 with gates ON | same pass bars as the WK-128 spec, except A6 tier side becomes "≤ +20 in any 1.5 s window" |
| A20 | Sports: touch the ball 10x at 0.5 s spacing | refunds_ball = 5 (1.0 s cooldown); stunned touch pays 0 |

### B. Singularity (closes WK-133) + core arenas
- **Setup:** 40 stages of 4-bot brawl (L3/L2/L3/L4, LIVES 1) on singularity, plus 20 on black_hole_brawl. Run with
  gates OFF (Phase 1 + 2) and gates ON (Phase 3).
- **Pass:**
  - **0 hangs**: every stage ends, and no stage's combat exceeds the arena's max combat clock + 5 s.
  - `stationary_all_bots_s` < 3 s in every stage.
  - `bumper_pin_episodes` ≤ 0.1 per bot-stage.
  - `rest_episodes` = 0.
  - Credited KO/min within 0.85-1.15x of B0's singularity slice.
- **Recording:** 30 s on singularity with a contact sheet. LOOK at it: no goat sits or buzzes on the core for more than
  1 s, and the bots visibly fight.

### C. Bumper-arena batch
- 40 + 40 stages on pinball_pit, hay_bales, bumper_gauntlet, sky_ladder_brawl and high_pasture (BB0 baseline vs
  Phase 3).
- **Pass:** WK-128 D1-D5 against BB0 (KO/min 0.90-1.15x, median stage ±15%, self-KO ≤ +3 pp, post-smash survival
  ±5 pp, stuck ≤ 1.1x); `rest_episodes` = 0.

### D. Full brawl rotation (the WK-128 (b) re-run)
- 160 stages (B0 baseline vs Phase 3), shared shuffle seed.
- **Pass:** WK-128 D1-D8, plus `rest_episodes` = 0, `dribble_episodes` ≤ 0.2 per stage, `time_below_refuel_floor`
  ≤ 1.6x B0.

### E. Sports (mandatory)
- 2v2 L3 all-bot, 10 rocketball + 6 dropshot (S0 baseline vs Phase 3). Also run Phase 3 with
  `sports_touch_fuel = 0` to isolate the ball source.
- **Pass:** goals/min ≥ **0.9x S0** (rocketball ≥ 4.82, dropshot ≥ 3.67); touches/min ≥ 0.9x; starved share ≤ 1.25x;
  own-goal share ≤ S0 + 3 pp; stuck/min ≤ S0; `ball_rest_on_bumper` reported.

### F. WK-128 re-run
- The full WK-128 §9 B (WK-123 regression), C (Trials sweep, 0 newly impossible) and F (recordings) with gates ON.

### G. Creative-director feel check (SHIP or a numbered FIX list)
1. Do bumper tops feel like "BOING" (lively) or like annoying jitter?
2. Do walls feel pushy when you drift into them slowly?
3. Does the Singularity core read as a pinball hub you can bounce off and escape?
4. In sports, does "hit the ball, get fuel" feel natural, and is anyone starved?
5. Has anything that used to be a ricochet started to feel different? It shouldn't.

Any "no" is a FIX, whatever the numbers say.

---

## 10. Fallback ladders (pre-registered; one step at a time)

| Symptom | Knob 1 | Knob 2 | Forbidden |
|---|---|---|---|
| Hops read as jitter (CD G1) or walls feel pushy (G2) | `bumper_min_rebound_height` 48 → 36 (339 px/s; still > #15's 60 bound, still ~17 screen px) | Scope the floor to floor/ceiling classes only (walls ricochet without a floor; thrust-pin on walls returns as ~100/s, so BR-135 must hold) | `bumper_restitution` changes; removing the floor from floor-class faces |
| A singularity hang remains (B) | BR-135b `bot_pin_contacts` 4 → 3 | `refund_rearm_timeout` 1.5 → 1.0 (#16: 20/s > 17.2, so this needs a designer re-ruling first) | Lethal core; per-level economy flags |
| Sports E fails on goals or starvation | `sports_touch_fuel_cd` 1.0 → 0.7 (≤ 28.6/s, at the drain; re-rule #17 to ≤) | Court geometry: convert the lower side-wall segments (floor to goal mouth) to bubblegum tier (level-designer; E11 lint holds, facing walls 2220 px apart) | Turning the bumper gate off per mode; `fuel_per_bumper` value; Alt B in sports only |
| Brawl D1 KO/min > 1.15x | WK-128 Alt B (its §10) | — | Hitstun triad, super impulse |
| Brawl D1 < 0.90x with no hangs | `bumper_floor_pays_as_tier` stays true; check F2 recovery losses (refunds_blocked_speed on recovering goats) | `bumper_refund_min_speed` 900 → 0 for wall-class + `refund_rearm_bumper_px` 400 (= Alt B minus the cooldown) | `fuel_per_bumper` |
| Trials course newly impossible | Geometry (level-designer) | — | Floor value, refund amounts |

---

## 11. Change control

- **Class:**
  - A physics change (bumper path only; tier path and every protected constant untouched)
  - An economy-rule change (face classes, liveness valve, gates ON)
  - One new object fuel source (sports)
  - One bot-brain change

  The full loop applies: spec → build (3 phases) → rendered QA (§9) → CD (§9 G) → Director commit + STATUS.
- **Files for the programmer:**
  - `BounceResolver.gd`: `resolve_bumper(velocity, normal, gravity_mag)` with K1.
  - `Player.gd`:
    - bumper branch of `_resolve_bounces`: pass `g.length()`, read `rebound_speed` after the floor;
    - `_wk128_contact_pays`: C1 classification, C2 floor-class tier rules, C3 F2 scoped to wall-class, C4 timeout;
    - `grant_fuel()` (S2);
    - telemetry (§8).
  - `InputBot.gd`: BR-135a-c, `wk135_no_pin`, motion-health counters.
  - `SportsMode.gd`: S1/S3 wiring on `Ball.touched`.
  - `Tuning.gd`: §4.4 constants, the WK-128 (b) values ON, invariants #15-#17 in comments; update the block header that
    says "ALL OFF pending WK-135".
  - `PartyMatch.gd`: §8 per-stage telemetry.
  - **No level JSON change** in this item.
- **Docs after commit:**
  - Architecture contract INV-11 row: "min-bounce floor in `resolve()` AND kick floor in `resolve_bumper()` + liveness
    valve".
  - game-feel-reference §3: bumper kick floor.
  - analysis-toolkit recipe 6: add the face-class column; this answers its "standing watch question".
  - tuning-and-flags: new constants + #15-#17.
  - Level JSON bumper doctrine text (WK-128 §7.6) becomes: "bumpers kick you off; tops refuel per bounce; walls refuel
    only on slams".
- **DECISIONS entry (draft for the Director):**
  > **2026-11-15 BUMPERS KICK, NEVER CRADLE (WK-135).** INV-11 now holds on every surface. Bumper contacts leave at
  > least `sqrt(2·|g|·48)` along the normal (392 px/s flat), with the ×0.86 ricochet unchanged above that, so nothing
  > can rest on or be glued to a bumper. Bumper faces are classed by local gravity. TOPS (and round cores) refuel like
  > floors, once per real bounce. WALLS refuel only on ≥ 900 px/s slams. CEILINGS never refuel. A face that paid
  > 1.5 s ago always re-arms (liveness: no goat can be stranded at 0 fuel; ≤ 13.3 fuel/s, below natural bouncing).
  > WK-128 (b) gates ON (re-arm 0.9/60/200, wall hard-hit 900; Alt B cooldown not adopted). Sports keeps a refund
  > source: the BALL (+20 per accepted touch, ≤ 1 per player per s), never the walls. No per-mode surface refund rule.
  > `bumper_restitution`, `min_bounce_height` and the refund amounts are unchanged. Reopen if CD rules the hops jittery
  > (ladder: 48 → 36) or sports goals stay < 0.9x after the ladder.
- **Findings routed (not WK-135 scope):**
  1. Screen-x air drift cancels horizontal radial pull in wells where g < 1300 (E12). Gameplay-programmer, INV-1
     hygiene question.
  2. The ball may rest on sports mid-bumper tops (E10). Level-designer, after QA reports.
  3. Per-surface "kicker" `min_rebound` in level JSON (pinball pop-bumper) is a future level-design tool, deferred.
  4. The refuel "ding" now covers ball touches (§7.5). ui-ux-designer + sound-designer.

## 12. Out of scope
- Tier bounce math and every protected constant.
- Ball physics.
- Per-level economy overrides.
- The radial air-drift question (finding 1).
- WK-108b sports roles.
- WK-127b.
