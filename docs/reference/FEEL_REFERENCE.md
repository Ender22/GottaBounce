# GottaBounce — Feel Reference & Starting Tuning Values

> **Status:** Living tuning doc. **Last updated:** 2026-06-27.
> **Companion to** `GAME_DESIGN.md` (what the game is) — this doc is *how it should feel*, with
> concrete numbers to start from.

## 0. How to read this doc (read first)

The owner's premise is correct: **the generic layer of 2D game feel is a solved, documented
problem.** Good bounce/jump/impact feel comes from well-known acceleration curves, "juice"
techniques, and forgiveness mechanics — all published (sources in §10). This doc translates those
into GottaBounce's specific mechanics and gives **starting numbers**.

**Three rules for using these numbers:**
1. **They are hypotheses, not gospel.** They're calibrated to be *in the right ballpark* so run #1
   isn't garbage — the playtest is a tuning loop (`GAME_DESIGN.md` §12). Expect to change them.
2. **Tune ONE variable at a time**, then play. Changing five at once tells you nothing.
3. **Record what felt good back into this doc** (overwrite the start value, note the date). This file
   becomes the project's source of truth for feel.

**The ONE thing that is NOT solved by prior art:** the novel *bounce-powered-fuel economy* and the
*super-boost overcommit risk* (§4–5 below). No shipped game has exactly this loop, so those numbers
are genuine discovery, not copying. Everything else (bounce arcs, air control, juice) is calibration.

## 1. Conventions & reference scale (so the numbers mean something)

- **Engine:** Godot 4, `CharacterBody2D` with **hand-authored velocity** (NOT `RigidBody2D`
  restitution) — we set bounce velocity explicitly for exact arcade control (`GAME_DESIGN.md` §13).
- **Units:** pixels & seconds. Y is **down** (Godot default), so "up" velocities are negative.
- **Reference scale:** character visual height **H ≈ 110 px** (the 128px placeholder sprites),
  fixed single-screen design space **1920×1080**. *All px values below scale with H* — if you change
  the world scale, scale the px numbers by the same factor. Where possible values are also given in
  **character-heights** or **seconds** (scale-independent — prefer these as the "real" target).
- **Frame rate:** assume 60 fps for frame counts; use `delta`-based physics so it's framerate-independent.
- **Gravity is a FIELD, not a constant (architecture rule — `GAME_DESIGN.md` §4.8).** Even though v0
  only uses global down-gravity, query it as a vector at the character's position
  (`get_gravity_at(pos) -> Vector2`), never hardcode `Vector2(0, gravity)`. This lets post-v0
  gravity-generating surfaces (planetoids, gravity walls) drop in with no rewrite. All "down"-relative
  math below (bounce launch, min-bounce, drift) is really **along the local gravity vector**.

## 2. The Bounce — passive base layer (`GAME_DESIGN.md` §4.1)

Bounce is **hand-authored**: on contact with a bounce surface, set the velocity component **into**
the surface to a launch speed derived from the tier's target height; reflect/preserve the tangential
component. This gives exact per-tier control and supports **angled & curved surfaces** (reflect the
velocity vector about the surface normal — see §2.4).

### 2.1 Gravity & bounce heights
Pick gravity from the desired *feel* of the lowest bounce, then derive launch velocities.
`launch_speed = sqrt(2 * gravity * target_height)`; `time_to_apex = launch_speed / gravity`.

| Var | Start value | In feel terms | Notes |
|---|---|---|---|
| `gravity` | **2600 px/s²** | tier-1 apex in ~0.35 s | snappy/arcade; raise = punchier, heavier |
| `bounce_height_marshmallow` (tier 1) | **160 px** (~1.5 H) | low, quick rhythm | baseline = 1 |
| `bounce_height_bubblegum` (tier 2) | **320 px** (~3 H) | — | ~2× tier 1 |
| `bounce_height_trampoline` (tier 3) | **640 px** (~6 H) | big air | ~4× |
| `bounce_height_spring` (tier 4) | **1280 px** (~12 H) | launches near/off top of screen | ~8×; intended chaos — consider a cap |
| `min_bounce_height` | **48 px** (~0.4 H) | always kicks back up | **enforces no-stand rule (§Pillar 2)** even from near-rest |

> Heights follow the design doc's 1/2/4/8 telegraphed tiers. Engine converts height→velocity, so the
> JSON level format keeps storing relative `bounceHeight` (`GAME_DESIGN.md` §15).

### 2.2 Momentum through the bounce (decided: NOT vertical-only — `GAME_DESIGN.md`)
- **Tangential (horizontal on a flat floor) velocity is preserved** across a bounce, with light
  damping `tangential_retention = 0.98` (so you keep your run/drift momentum — Duck-Game-y, not pogo).
- **Normal (into-surface) velocity** is replaced by the tier launch speed (not multiplied), so a
  player arriving fast doesn't bounce absurdly higher than the tier — keeps tiers readable. *(Tuning
  option: add a small `+arrival_speed * 0.15` bonus if "slamming down for a big bounce" feels good.)*

### 2.3 Air drift (slight steering, NOT flight)
| Var | Start | Feel |
|---|---|---|
| `air_drift_accel` | **700 px/s²** | gentle nudge |
| `air_drift_max_speed` | **190 px/s** (~1.7 H/s) | fine-tune landing spot only |
Real directional power is the jetpack (§3), not drift.

### 2.4 Angled & curved surfaces (the circle-arena level, etc.)
Reflect the incoming velocity about the **surface normal**: `v' = v - (1+e)*(v·n)*n`, with
**restitution `e` per tier** (e≈1.0 for elastic bumper walls; for bounce tiers, set the post-reflect
*normal* speed to the tier launch speed instead, so walls/ceilings still impart the tier's energy).
`bumper_restitution = 1.0` (walls preserve speed, pure ricochet). This is what makes "the whole level
is bouncy, including round surfaces" work. **The level format needs arc/segment colliders, not just a
tile grid** — flagged for Fable.

## 3. The Jetpack — active control (`GAME_DESIGN.md` §4.2–4.3)

### 3.1 Fuel
| Var | Start | Feel |
|---|---|---|
| `fuel_max` | **100** units | full tank |
| `tank_seconds` | **3.5 s** | ⇒ `normal_boost_drain ≈ 28.6 units/s` |
| `fuel_per_bounce` | **20** units (flat) | ~5 bounces to refill from empty | 
| (tuning) height-proportional refill? | off | spring refuels more than marshmallow — try if banking feels flat |
- **No refill while airborne/stunned** — only contact with a bounce surface adds fuel. This is the
  economy's heart and the recovery-gamble engine (`GAME_DESIGN.md` §4.6). Protect it.

### 3.2 Normal boost (sustained, steerable)
| Var | Start | Feel |
|---|---|---|
| `normal_boost_accel` | **4200 px/s²** | > gravity, so you can climb & recover |
| `normal_boost_max_speed` | **650 px/s** | terminal under sustained thrust |
| `boost_rampup` | **0.06 s** to full thrust | tiny ramp avoids on/off jerk |
Aimed in any direction via the left stick (§6).

### 3.3 Super boost (dump fuel, violent — the offense)
| Var | Start | Feel |
|---|---|---|
| `super_boost_impulse_full` | **1400 px/s** instant | full-tank launch |
| impulse scaling | **linear with fuel fraction** | `impulse = 1400 * (fuel/fuel_max)` |
| `super_boost_duration` | **0.30 s** burst (drains all fuel) | per design |
| `super_boost_min_fuel` | **15** units to fire | below this it's a weak nudge, not a launch |
- **Self-destruct math (the comedy/skill knob):** full impulse 1400 px/s aimed at the far blast zone
  should *over*-cross it — i.e. over-committing flings you off the opposite side. Verify: a full
  super-boost from mid-stage should travel > half the 1920 width before gravity/drag arrest it. Tune
  `super_boost_impulse_full` until "boost too hard = death" is real but avoidable.

### 3.4 Boost-Bounce Supercharge — the bounce-jump flow tech (`GAME_DESIGN.md` §4.7)
When **Normal Boost is active during a surface contact**, fire a brief supercharge: amplify boost
thrust *and* the bounce launch for a short window. Implementation: on bounce contact, check if boost
is held (or pressed within `input_buffer`); if so, open the window and multiply.
| Var | Start | Feel |
|---|---|---|
| `supercharge_window` | **0.20 s** | the "pop" lasts a beat after a boosted bounce |
| `supercharge_thrust_mult` | **1.6 ×** `normal_boost_accel` during window | the trampoline-tap kick |
| `supercharge_bounce_mult` | **1.4 ×** tier launch speed | boost-into-surface = harder kickback |
| (tuning) `supercharge_fuel_discount` | **0** (off) | optional: boosted-bounce costs slightly less fuel, rewarding flow |
- **Both behaviors fall out of this one rule:** tap-as-you-leave (boost held through launch) and
  boost-into-surface (boost held into contact) both open the window → bigger launch.
- **Chain flow:** consecutive well-timed supercharges should visibly build speed/height (Sonic-spring
  feel). Watch that it doesn't trivially fling players off the top — cap with `air_drift`/gravity or a
  per-chain falloff if it gets degenerate. Tune live.

## 4. Knockback, Hitstun & Recovery (`GAME_DESIGN.md` §4.6)

| Var | Start | Feel |
|---|---|---|
| `smash_impulse_base` | **600 px/s** | minimum launch on any super-boost hit |
| `smash_impulse_from_attacker` | **1.1 ×** attacker's impact speed | harder hit = bigger launch |
| `hitstun_base` | **0.15 s** | always feel the hit |
| `hitstun_per_impulse` | **0.00025 s per px/s** | scales with launch power |
| `hitstun_max` | **0.55 s** (cap) | **recovery window always exists** — ring-out comes from velocity, not from being frozen |
| `bounce_out_of_stun` | off (tuning) | does bouncing while stunned cancel stun? try both |
- During stun: no input, play `hit` sprite + **code tumble** (spin, §5.3).

### 4.1 Explosions (bombs & blasts — `GAME_DESIGN.md` §6)
A radial impulse applied to **everything in range — players AND props** (one shared
`apply_radial_impulse(center, radius, impulse)`), flung **away from center, stronger closer in**.
| Var | Start | Feel |
|---|---|---|
| `explosion_radius` | **280 px** (~2.5 H) | per-bomb override allowed |
| `explosion_impulse_center` | **1600 px/s** | at the epicenter |
| falloff | **linear**: `impulse * (1 - dist/radius)` | simple & readable; try smoothstep |
| on players | apply impulse + **hitstun** like a smash (§4) | you get launched + briefly helpless |
| on props | impulse → velocity = **impulse / mass** | heavy balls shrug it off, light stuff flies (correct momentum) |
| `explosion_lethal_core` | **0 px (off)** | optional point-blank instakill radius — TBD |
| `chain_detonate_delay` | **0.08 s** | a bomb caught in a blast detonates after this → visible cascade |
| juice | **Heavy** screen shake (+0.9 trauma, §5.2) + `hitstop ≈ 0.06 s` + big particle flash | scale with radius |
- **Your own exhaust-lit bomb blasts you too** if you're in range — risk/reward, on-theme with the
  super-boost self-destruct comedy.
- Chain reactions (bomb → bomb, blast → heavy ball → player) are the point; don't suppress them.

## 5. Impact Juice — the "feel heavy" layer (`GAME_DESIGN.md` §10)

> **Rule of Three:** every meaningful action gets feedback in **≥3 channels — Visual + Audio +
> Kinesthetic** (shake/rumble/hitstop). A bounce = squash + sfx + tiny dip. A smash = flash + boom +
> shake + hitstop + rumble. *(GameAnalytics / "Juice it or lose it".)*

### 5.1 Hitstop / global slow-mo (the owner's "tiny everyone-slowmo on impact")
On a super-boost smash, briefly drop `Engine.time_scale` for everyone, then ease back. Classic impact
trick: **3–7 frames** of freeze/slow sells weight.
| Var | Start | Feel |
|---|---|---|
| `hitstop_timescale` | **0.05** (near-freeze) | the heavy "thunk" |
| `hitstop_duration` | **0.07 s** (~4 frames) | at frozen scale |
| `hitstop_recover` | **0.12 s** ease back to 1.0 | smooth, not a snap |
> Scale by hit strength: light chain-bumps get ~0.03 s, full-tank smashes get ~0.10 s.

### 5.2 Screen shake (trauma model — Squirrel Eiserloh)
Use a **trauma** scalar `[0,1]`; `shake = max_offset * trauma²` (and angle * trauma²); decay trauma
linearly. Squared trauma keeps small events subtle and big ones violent.
| Event | add trauma | max_offset | decay |
|---|---|---|---|
| ring-out nearby / hard land | **+0.25** (Light) | — | — |
| normal smash (Medium) | **+0.5** | `shake_max_offset = 22 px` | `trauma_decay = 1.4 /s` |
| full-tank super smash (Heavy) | **+0.9** | — | — |
Keep it short and snappy; never nauseating. Pair with a 1-frame white **hit-flash** on the victim.

### 5.3 Squash & stretch (CODE via node scale — no frames needed)
| Event | scale | back to (1,1) | curve |
|---|---|---|---|
| land on bounce surface | **(1.25, 0.75)** squash | over **0.12 s** | ease-out |
| at launch / rising fast | **(0.85, 1.18)** stretch along velocity | continuous w/ speed | — |
| super-boost fire | **(0.7, 1.4)** hard stretch | over 0.18 s | ease-out |
| got hit / tumble | spin `±540°/s`, keep `hit` pose | until stun ends | — |
| win | hop + **(1.3,1.3)→(1,1)** pop ×2 | 0.3 s | bounce ease |
Orient stretch along the velocity vector. This is where most of the "alive" feeling comes from and it
costs zero art (`GAME_DESIGN.md` §10, §4.6).

### 5.4 Exhaust & particle feedback
- Normal boost: steady flame (`particles/flame_0X`) + thin smoke trail at the nozzle, emitting
  **opposite** thrust. Scale emission rate with thrust.
- Super boost: one-shot violent burst (`muzzle_0X` + `spark_0X`), bigger than normal.
- Bounce: small dust puff at contact point (`smoke_0X`).
- Gamepad rumble per §5.5 (the kinesthetic channel).

### 5.5 Controller rumble (decided — `GAME_DESIGN.md` §10)
Godot: `Input.start_joy_vibration(device, weak, strong, duration)`. `weak` = high-freq buzz,
`strong` = low-freq thump. Tune to feel, starting points:
| Event | weak / strong | duration | feel |
|---|---|---|---|
| Normal Boost (while held) | **0.15 / 0.05** | continuous while boosting | **soft** purr |
| Bounce (on surface contact) | **0.2 / 0.35** | **0.08 s** | **medium** thump; scale w/ bounce tier |
| Super Boost fire | **0.6 / 0.9** | **0.18 s** | **hard & powerful** |
| Impact (hit, or being hit) | **0.9 / 0.8** | **0.10 s** | **heavy & quick** snap; pair w/ hitstop §5.1 |
> Boosted-bounce supercharge (§3.4) = stack the boost purr + a stronger bounce thump for extra
> kinesthetic payoff. Keep an accessibility toggle to disable rumble.

## 6. Controls & aim (controller-only for v0 — decided)

| Var | Start | Notes |
|---|---|---|
| aim | **left stick → jetpack angle** | show on-screen direction arrow when stick past deadzone |
| `stick_deadzone` | **0.22** | below = no aim change, hide arrow |
| normal boost | **A (hold)** | sustained thrust |
| super boost ("heavy boost") | **RT (right trigger)** | dumps fuel in aimed dir |
| use powerup | **Y and RB (both mapped)** | activate held powerup; for Wings, repeated taps = flap |
| `input_buffer` | **6 frames (~100 ms)** | buffer boost/super presses so contact-timed inputs register |
| (tuning) `super_boost_aim_assist` | **±0 ° (off)** | small magnetism toward nearest rival can help readability/comedy — try ±8° |
> **Aim frame (recommended, matters for gravity fields §4.8):** keep aim **screen-relative** — left
> stick up = thrust toward the top of the screen, *always*, even when local gravity rotates. The
> on-screen arrow is the source of truth. Let the character *body* rotate to local-down (juice), but
> don't rotate the controls — that's how players stay un-disoriented in a planetoid arena.
>
> Coyote-time (Celeste's 5-frame post-ledge grace) is mostly **N/A** here — you're always bouncing,
> never standing on a ledge. But **input buffering matters a lot**: a super-boost pressed a few frames
> before you hit a surface should fire the downward-bounce launch cleanly.

## 7. Camera

**Party Mode (decided: fixed single-screen — Duck Game / TowerFall).** No follow, no scroll — the
**whole arena is on screen at once**. The only camera motion is **shake** (§5.2) and an optional tiny
**punch-zoom** on a ring-out kill (`zoom 1.0→1.03→1.0` over 0.2 s). Design stages to fit the
1920×1080 play space with the blast zone just outside it (`GAME_DESIGN.md` §15 `bounds`).

**Campaign Mode (decided: hybrid scrolling — `GAME_DESIGN.md` §7 Mode 2).** Camera **scrolls
left→right** following the player(s) in Part 1 (exploration) and Part 3 (escape), and **locks** to a
fixed single-screen frame for the Part 2 arena fight (which then behaves like a Party stage:
Smash-style ring-out + shake/zoom).
- **Architecture:** the camera must support both a **follow/scroll mode** and a **locked mode**, switchable per level-section. Co-op scrolling needs a rule for two players (e.g. camera frames both; a player who falls too far behind the left edge dies / is pulled).
- **Death sources differ by section:** scrolling sections kill via **pits, hazards, and falling behind** the scroll; the locked arena uses **ring-out blast zones** like Party. The blast-zone/death system needs both behaviors.

## 8. The complete `@export` tuning block (give Fable this as one Resource)

Expose ALL of the above in a single Godot tuning resource (`.tres`) or autoload so the playtest can
hot-edit feel without touching code (`GAME_DESIGN.md` §12):

```
gravity, bounce_height_[marshmallow|bubblegum|trampoline|spring], min_bounce_height,
tangential_retention, bumper_restitution, air_drift_accel, air_drift_max_speed,
fuel_max, tank_seconds, fuel_per_bounce, normal_boost_accel, normal_boost_max_speed, boost_rampup,
super_boost_impulse_full, super_boost_duration, super_boost_min_fuel,
supercharge_window, supercharge_thrust_mult, supercharge_bounce_mult, supercharge_fuel_discount,
smash_impulse_base, smash_impulse_from_attacker, hitstun_base, hitstun_per_impulse, hitstun_max,
hitstop_timescale, hitstop_duration, hitstop_recover,
shake_max_offset, trauma_decay, (squash/stretch amounts & durations),
rumble_[boost|bounce|super|impact]_(weak/strong/duration),
stick_deadzone, input_buffer, super_boost_aim_assist
```

## 9. First-playtest tuning order (don't tune everything at once)
1. **Bounce alone** — gravity + tier heights + min-bounce until the *passive* rhythm feels good with
   no jetpack. (Is just bouncing around pleasant?)
2. **Air drift** — just enough to place yourself, not fly.
3. **Normal boost** — can you climb, steer, and recover to a platform? Tune accel/max.
   - then **boost-bounce supercharge** (§3.4) — does tapping boost on a bounce feel like a rewarding trampoline-pop? Tune window/multipliers; check chaining doesn't fling players off the top.
4. **Fuel economy** — does banking-by-bouncing vs spending feel tense and fair? (the novel part)
5. **Super boost + self-destruct** — satisfying launch, and is overshooting-into-oblivion funny?
6. **Knockback + hitstun + recovery** — the smash → stun → fuel-gated recovery gamble.
7. **Juice last** — hitstop, shake, squash, particles. Add only after mechanics feel right (juice
   should *amplify* good feel, never *fake* it).

## 10. Sources (game-feel reference)
- Celeste player physics & forgiveness (coyote time = 5 frames, etc.) — DeepWiki: NoelFB/Celeste,
  https://deepwiki.com/NoelFB/Celeste/2.3-player-movement-and-physics ; Maddy Thorson's published
  Celeste constants are the canonical reference for snappy-platformer values (scale to our H).
- "Juice it or Lose it" (Grapefrukt) — squash/stretch, shake, the juice toolkit —
  https://gamejuice.co.uk/resources/juice-it-or-lose-it
- "Squeezing more juice out of your game design" (GameAnalytics) — hitstop 3–5 frames, Rule of Three —
  https://www.gameanalytics.com/blog/squeezing-more-juice-out-of-your-game-design
- Screen shake **trauma model** (Squirrel Eiserloh, "Math for Game Programmers: Juicing Your Cameras")
  — shake ∝ trauma²; the standard approach.
- More Mountains "Feel" docs — shake/hitstop preset profiles (Light/Medium/Heavy) —
  https://feel-docs.moremountains.com/screen-shakes.html
- Game Maker's Toolkit, "Secrets of Game Feel and Juice" — general principles (video).
