# Spec: v1 Powerups — the first shipped set

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD. **Last updated:** 2026-07-02.
> Sources of truth: `docs/VISION.md` (pillars), `docs/reference/GAME_DESIGN.md` §5,
> `docs/reference/FEEL_REFERENCE.md`. Builds on `docs/specs/v0_round_loop.md` (state machine,
> ROUND_END freeze, sudden death) and the old project's `PowerupSystem.gd` seams
> (`held_powerup`, `try_use`, Y/RB activation).
> **All numbers below reference the LIVE `src/core/Tuning.gd` values** (gravity 1600, chargeable
> super boost 2800, trampoline 270px) — not the stale FEEL_REFERENCE table.

## The player fantasy

You spot the golden star bubble materializing over the center trampoline **at the same moment
everyone else does.** Four bouncers converge, someone gets there first, goes rainbow, and the
other three SCREAM and scatter. Powerups are not stat buffs — they are **ten-second comedy
scripts the game hands to whoever is brave enough to fight for them.** Every pickup is a
public event: everyone sees it spawn, everyone sees who holds it, everyone sees the punchline.

## Design rules (from GDD §5, enforced on every entry below)

1. **Readable at a glance** — pickup icon reads at 40px; active state reads from across the
   screen without looking at the HUD.
2. **Visible/funny consequence** — every activation produces a screen-level event, never a
   silent stat change.
3. **No camping** — nothing here lets you rest, cling, or turtle. Active airborne states
   (Black Hole channel) are short and committed per the Pillar-2 scope note.
4. **No boring defense** — the one defensive pick (Counter Shield) is an *attack you time*.

---

## 1. Roster decision — 7 ship, 3+ wait

### Shipping (v1) — role spread: 2 mobility · 2 offense · 1 defense · 2 chaos/trap

| # | Powerup | Role | Why it's in (one line) |
|---|---|---|---|
| 1 | **Mega Bounce** | Mobility | The most self-telegraphing power in the game — everyone SEES you bouncing twice as high; teaches "surfaces are the game." |
| 2 | **Unlimited Boost** | Mobility/aggro | The simplest power fantasy (infinite jetpack = spam full-power supers); zero explanation needed. |
| 3 | **Star** | Offense/defense | Universally pre-learned from Mario — the instant "everyone scatter!" moment; best comedy-per-second in the set. |
| 4 | **Counter Shield** | Defense (active) | The skill pick — a 2s parry window that launches the attacker; creates legendary "he PARRIED the super" clips. |
| 5 | **Ball Storm** | Chaos | Piñata energy — 16 ricocheting balls turn the arena into a pinball machine; pure Pillar-3 emergent comedy. |
| 6 | **Black Hole** | Offense (setup) | The dramatic one — freeze, drag everyone into a cluster, deliver the super-boost punchline; high risk while channeling. |
| 7 | **Ring of Fire** | Trap/denial | Area denial with a built-in joke: victims get force-super-boosted in whatever direction they were aiming — free escape or spectacular self-destruct. |

### Waiting (deferred, with the reason to fix before they ship)

| Powerup | Why it waits |
|---|---|
| **Wings** | Flap-tapping overloads the Y/RB button family and 30 flaps of free flight stresses the bounce-fuel economy — revisit after the feel-tuning loop locks. |
| **Slow-Mo** | Slowing *other* players feels bad on the victim side and is unattributable mid-chaos ("why am I slow?"); needs careful timescale work alongside hitstop. |
| **Air Mine** | A near-invisible mid-air trap reads as "cheap" at party pace; Ring of Fire owns the trap slot with a bigger, funnier, more visible consequence. |
| Magnet, Heavy Mode, Giant/Tiny, Nitro, Overcharge, Instant Refuel, arena-wide powers | Post-v1 roster growth (GDD scope: 15–20 total); v1 proves the framework first. |

---

## 2. Shared framework (applies to all 7)

### Pickup model
- Powerups spawn as a **floating glossy bubble (72px diameter)** at a `powerup_spawner` object
  position (level JSON, §15 format — already in the schema). The bubble bobs gently
  (±8px, 1.2s sine) and contains the powerup's **icon (~48px)**, so players race for
  *specific* powerups, Duck-Game-weapon style.
- **Spawn telegraph:** 1.0s of converging sparkle particles at the spawner point *before* the
  bubble materializes — a starting gun for the scramble.
- **Collect on touch.** Bubble pops (confetti burst + `pop` SFX). The powerup is now **held**:
  a mini icon (32px) bobs above the holder's head AND appears on their corner HUD card.
  The over-head icon is deliberate target-painting — holding a star makes you the hunted.
- **One held slot.** Touching a new bubble while holding **swaps** (old one poofs — a puff +
  falling-icon gag, it is NOT dropped as a pickup). No hoarding.
- **Activate with Y or RB** (existing `use_powerup` intent). Not activatable during hitstun
  (no input during stun) or while dead. Activatable mid-super-boost-charge (exceptions noted
  per powerup).

### Universal rules & edge cases
- **Death clears everything:** dying discards the held powerup and cancels any active effect
  immediately (Star sparkles must not linger on a corpse flying off screen).
- **Hazards ignore powerups:** spikes, crushers, and sudden-death lasers instakill through
  Star, Counter Shield, everything (GDD §4.5 — no exceptions, ever). Ring-out kills everyone
  equally. Powerups change *fights*, never *death rules*.
- **ROUND_END freeze** (v0 spec §1) pauses and then **clears all active effects and field
  objects** (balls, rings, in-flight bubbles). Nothing carries across rounds. Held-but-unused
  powerups are also cleared at round end (each round starts clean — keeps the spawn race the
  opening beat of every round).
- **Sudden death:** active effects keep running (a Star finale is hilarious) but **no new
  bubbles spawn** once lasers activate — the endgame stays pure.
- **Effect stacking:** a player can hold one and have one active (grab → use → grab next).
  Re-activating the same effect while active **restarts its timer** (no doubling of
  multipliers).
- **QA hooks (required):** `PowerupSystem.grant(player, id)` (put id in held slot),
  `PowerupSystem.try_use(player)`, and an eval-readable `player.active_powerup: String` +
  `player.powerup_time_left: float` so QA asserts state instead of guessing.

---

## 3. The seven, in detail

### 3.1 Mega Bounce (mobility)
- **Mechanic:** for **`pu_mega_bounce_dur = 8.0s`**, every bounce launch (all tiers, min-bounce
  included) is multiplied by **`pu_mega_bounce_mult = 2.0`** on launch *speed*'s height target
  (trampoline 270px → 540px apex; spring 480px → 960px). Supercharge (§FEEL 3.4) stacks
  multiplicatively — that's the intended god-flow moment, and the top blast zone is the natural
  cap (a mega+spring launch flirting with the top edge is a *readable, avoidable* risk: don't
  touch springs while mega).
- **Pickup art brief:** *glossy chunky red-and-white coiled spring icon, compressed with motion
  lines, inside the standard bubble — toy-store spring, reads at 40px.*
- **Active telegraphy:** exaggerated squash & stretch (squash scale 1.4× the normal §5.3
  values), a thick white ring-shockwave at every bounce contact, and a faint bouncy-arc trail.
  You cannot miss a mega-bouncer — they're the highest thing on screen.
- **Funny moment:** the player who grabs it to "escape" and immediately mega-springs
  themselves off the top of the screen. −1.
- **Edge cases:** stacks with supercharge (yes, intended); does NOT amplify knockback received
  or smash impulses (bounce launches only); expires mid-air harmlessly (next bounce is normal);
  fuel-per-bounce unchanged (flat 20 — the mobility is the prize, not a fuel engine).

### 3.2 Unlimited Boost (mobility/aggression)
- **Mechanic:** for **`pu_unlimited_boost_dur = 8.0s`** (cut from the old 10 — rounds are
  10–30s, 10s was near-permanent), fuel is **pinned at `fuel_max`** (`fuel_locked` seam from
  old code). Normal boost never drains; every super boost fires at **full fuel fraction** (the
  charge mechanic still gates spam: `super_charge_time = 1.0s` to full power).
- **Pickup art brief:** *cyan fuel canister with a glowing infinity symbol (∞) on its face,
  small flame at the nozzle, inside the standard bubble.*
- **Active telegraphy:** jetpack flame turns **cyan and doubles in size** with a long
  afterburner trail; the holder's fuel gauge glows solid. The oversized cyan flame is the
  "get away from that person" read.
- **Funny moment:** back-to-back full-power supers — miss the first, whip around, land the
  second… or overshoot both and self-ring-out at full power.
- **Edge cases:** super boost during the effect still "dumps the tank" but it instantly
  refills (net: full-power supers gated only by charge time); effect expiring mid-boost lets
  the tank drain normally from full (no snap to empty); pin overrides bounce refill (already
  full).

### 3.3 Star (offense/defense hybrid — the rare one)
- **Mechanic:** for **`pu_star_dur = 5.0s`** (cut from 6 — 5s is 30–50% of a round), the
  holder is **knockback-immune** (smashes, ball hits, explosions apply zero impulse and zero
  hitstun to them) and **any body contact launches the other player** with impulse
  **`pu_star_contact_impulse = 900 px/s`** (1.5× `smash_impulse_base`) away from the star
  holder, with standard hitstun (§FEEL 4 formula).
- **Pickup art brief:** *classic glossy golden 5-point star with a highlight glint and tiny
  radiating sparkle dots, inside the standard bubble — the Mario read, unmistakable at 40px.*
- **Active telegraphy:** body **color-cycles through rainbow hues** (shader tint, 6 cycles/s)
  plus a shedding trail of star particles. The single most readable state in the game — as
  pre-learned as game language gets.
- **Funny moment:** three players fleeing a giggling rainbow blob into the same corner; or the
  star holder confidently chasing someone straight into a crusher (hazards don't care).
- **Edge cases:** hazards/lasers/ring-out still kill the holder (invincible to *players*, not
  to *physics or the level* — bait-into-spikes is the counterplay); **Counter Shield beats
  Star** (see 3.4 — the one answer); Black Hole pull still moves the holder (a pull is not a
  hit); contact launches count as smashes for kill credit (star ring-outs = kills for the
  holder); two Stars should never coexist (weight 1 + swap rule makes it near-impossible; if
  it happens, contacts between two stars apply no impulse to either — mutual "clang" spark).

### 3.4 Counter Shield (active defense — the skill pick)
- **Mechanic:** on activation, a shield is live for **`pu_counter_dur = 2.0s`** only. Any
  player who body-contacts or smashes the holder during the window gets **counter-launched**
  with impulse **`pu_counter_reflect_impulse = 1400 px/s`** (half a full super — a serious
  launch) + standard hitstun; the holder takes **zero** impulse/stun. Expires silently if
  nobody hits it (the whiff is the balance — you burned the pickup).
- **Pickup art brief:** *glossy sky-blue rounded shield/bubble icon with a white spark glint
  at its edge, inside the standard bubble.*
- **Active telegraphy:** a visible **glossy hex-bubble ring** around the whole character for
  exactly the 2s window, with a bright 0.15s activation flash so attackers get one readable
  frame of "abort!". Fades with a shrink-pop at expiry.
- **Funny moment:** parrying a fully-charged super boost — the attacker arrives at 2800 px/s
  and leaves at 1400 px/s in the opposite direction, straight into the blast zone.
- **Edge cases:** **beats Star** (a star holder touching a live counter shield gets fully
  counter-launched + hitstunned — the timed parry is the one answer to the rare power, and
  the resulting clip is legendary); reflects Ball Storm balls (ball bounces off at 1.5× speed,
  holder unharmed); blocks explosion *knockback* on the holder (it's knockback, and blocking
  it is a readable rule) but never blocks instakill hazards, lasers, or ring-out; two live
  counter shields colliding: both players knocked apart at 700 px/s each, no hitstun, comedy
  "BOING" spark; counter kills credit the shield holder (it's their attack).

### 3.5 Ball Storm (chaos)
- **Mechanic:** on activation, **16 bouncy balls** (radius 15px, restitution 0.9, mass 0.4 —
  the old prop payload) burst from the holder with random impulses (x: ±320, y: −120..−420
  px/s). Balls ricochet off all bounce surfaces/bumpers. Ball contact with a player applies
  **`pu_ball_hit_impulse = 500 px/s`** along the ball's velocity + standard hitstun, then the
  ball pops (one hit per ball). Balls that never hit anyone **pop with a star-spark at
  `pu_ball_lifetime = 6.0s`**.
- **Pickup art brief:** *cluster of three glossy orange bouncy balls (one big, two small)
  with white highlights, inside the standard bubble.*
- **Active telegraphy:** none needed — the effect IS the telegraph (16 orange balls
  ricocheting is a screen-level event). The 0.3s burst has a confetti-cannon flash + big
  rumble.
- **Funny moment:** releasing it in a bumper corridor and watching the arena become a pachinko
  machine — including the thrower getting clipped by their own rebound.
- **Edge cases:** balls hit **everyone including the thrower** after a **0.5s owner-grace**
  (guaranteed instant self-hit at burst is unfair; a *rebound* self-hit is comedy); ball kills
  (knock into hazard/blast zone) credit the thrower via the normal `last_attacker` window;
  balls are cleared at ROUND_END and do NOT trigger Ring of Fire; Star holders pop balls on
  contact harmlessly; performance budget: 16 balls + 4 players must hold ≥55fps (QA P5).

### 3.6 Black Hole (offense setup — the dramatic one)
- **Mechanic:** on activation the holder **freezes in the air** (velocity zeroed, gravity off,
  input locked) and channels for **`pu_black_hole_dur = 2.0s`**, projecting a radial pull:
  all other players within **`pu_black_hole_radius = 700px`** are accelerated toward the
  holder at a constant **`pu_black_hole_pull = 2600 px/s²`** (constant-in-zone per the §4.8
  gravity-field philosophy — readable, not 1/r²). `normal_boost_accel` (4600) beats the pull,
  so a fueled player can fight out — *burning the fuel they'd need afterward*. Empty tanks get
  dragged in. **At channel end the holder's tank snaps to full** (the hole "feeds" them) —
  guaranteeing the designed payoff: a point-blank full super into the cluster you just made.
- **Pickup art brief:** *deep-purple/black swirling vortex disc with a thin bright accretion
  ring and 2–3 small sparks being sucked in, inside the standard bubble.*
- **Active telegraphy:** impossible to miss — holder goes silhouette-dark with a swirling
  purple vortex shader centered on them, curved pull-streak particles flow inward from all
  directions, and the screen vignettes slightly for the 2s.
- **Funny moment:** the channel ends, three victims are stacked in a ball at arm's length,
  and the holder fumbles the super boost aim and launches themselves instead.
- **Edge cases:** **channeling is the risk** — the holder is NOT invulnerable: any smash/ball
  hit during the channel **cancels it** (no fuel refill, normal knockback applies); activating
  during a super-boost charge cancels the charge (fuel retained); hazards can't reach a
  mid-air channeler but pulled *victims* dragged into spikes die normally (kill credited to
  the channeler — glorious); the pull affects **players only** in v1 (props post-v1); if the
  2s channel would outlast ROUND_END, the freeze simply clears it; the 2s hover is the
  sanctioned Pillar-2 exception (GDD §2 scope note) — short, committed, punishable.

### 3.7 Ring of Fire (trap / area denial)
- **Mechanic:** on activation, a **fiery ring (160px diameter torus)** is planted at the
  holder's current position and persists **`pu_ring_lifetime = 8.0s`** or
  **`pu_ring_max_triggers = 3`** triggers, whichever first. Any player passing through it is
  **force-super-boosted as if on a full tank at full charge**: instant impulse
  **`super_boost_impulse_full = 2800 px/s`** in **their current aim direction** (stick past
  deadzone), else **their current velocity direction**, else straight up. The victim keeps
  full control (no hitstun) and their actual fuel is untouched — the recovery scramble IS the
  content. Per-player re-trigger cooldown **1.5s** (no instant double-zap).
- **Pickup art brief:** *ring/donut of stylized orange-yellow cartoon flames with a dark
  center hole, a few flame licks rising off the top, inside the standard bubble.*
- **Active telegraphy:** the planted ring is its own telegraph — animated licking flames,
  ember particles, a soft heat-glow. It must scream "do not fly through this" from across the
  arena (readability over prettiness).
- **Funny moment:** a fleeing player dives through it while aiming down-left to juke — and
  gets 2800 px/s of down-left, straight through the blast zone. Self-destruct, −1, everyone
  loses it.
- **Edge cases:** the **owner is immune for a 1.0s placement grace**, then it triggers them
  too (placing a trap and forgetting it = premium comedy); a ring-of-fire launch that carries
  someone out is a **kill for the ring's owner** (route through `last_attacker` on trigger);
  triggering overrides/consumes any in-progress super-boost charge (the ring's blast replaces
  it, victim's fuel still untouched); Star holders ARE launched (it's a boost, not a
  knockback — even gods obey rocketry) but take no hitstun as normal; cleared at ROUND_END
  and when lasers activate (sudden death arena stays clean).

---

## 4. Spawn rules — pacing for 10–30s four-player rounds

The spawner must feed the chaos without turning rounds into loot runs. Rounds are short;
powerups are a *beat*, not the meal.

- **First spawn:** telegraph starts at **`pu_first_spawn = 4.0s`** after "BOUNCE!" (bubble live
  at 5.0s). The opening ~4s stays pure movement/fighting — players learn the stage first.
- **Interval:** one new telegraph every **`pu_spawn_interval = 7.0s`** after the previous
  bubble spawns (replaces the old flat 8.0 — expect ~1–2 pickups in a 15s round, ~4 max in a
  full 30s round: roughly one per player per long round).
- **Field cap:** max **`pu_max_on_field = 2`** uncollected bubbles at once; the spawner skips
  its beat while at cap (uncollected bubbles never despawn on their own — a standing dare).
- **Placement:** each spawn picks a random `powerup_spawner` object from the level JSON,
  excluding the most recently used one (no back-to-back same-spot). **Level-authoring rule:**
  spawner points sit in *contested airspace* — mid-air over central surfaces, reachable by a
  bounce or one boost, and **≥200px inside the blast-zone bounds** (grabbing a pickup must
  never be inherently suicidal; *fighting* over it can be).
- **Drop weights** (rarer = smaller; carried from old tuning): star **1**, black_hole **2**,
  unlimited_boost **2**, mega_bounce **3**, ring_of_fire **3**, ball_storm **4**,
  counter_shield **4**. Anti-repeat: never the same id twice in a row from one spawner roll.
- **Sudden death stops spawning** (lasers active → spawner off, live bubbles pop). Round end
  clears everything (§2).

---

## 5. Success criteria (QA-verifiable via gbplay: eval + screenshots + measurement)

Prereqs: `PowerupSystem.grant/try_use`, `player.active_powerup`, `player.powerup_time_left`
exposed for eval (§2 QA hooks). "p1/bot" below = eval handles from the match scene's `players`.

### Framework
- **F1 — Pickup lifecycle:** eval-force a spawn → screenshot shows sparkle telegraph, then
  (1.0±0.2s later) a bubble with a legible icon at the spawner point. Drive p1 through it →
  bubble gone, `p1.held_powerup == id`, screenshot shows the over-head icon + HUD card icon.
- **F2 — Swap rule:** with p1 holding `mega_bounce`, drive through a `star` bubble →
  `held_powerup == "star"`, old icon poofs (burst frame in screenshot), no pickup dropped.
- **F3 — Death clears:** grant + activate `star` on a bot, eval-kill it → `active_powerup == ""`
  within 0.1s, no rainbow/star particles in the next screenshot.
- **F4 — Round-end sweep:** activate `ball_storm` + plant a `ring_of_fire`, then end the round
  → after ROUND_END, zero ball nodes, zero ring nodes, all `active_powerup == ""`.
- **F5 — Stun lockout:** put p1 in hitstun (eval a smash), send `use_powerup` during stun →
  `held_powerup` unchanged.

### Spawn pacing
- **S1 — Timing:** across 3 observed rounds (bots parked via eval to stretch the round):
  first telegraph at 4.0±0.5s after COMBAT starts; subsequent spawns 7.0±0.5s apart.
- **S2 — Field cap:** leave bubbles uncollected → never more than 2 bubbles exist
  (eval node count each second for 20s).
- **S3 — Sudden death cutoff:** force `round_clock` past 20s → lasers on, live bubbles popped,
  no new telegraph for the rest of the round.
- **S4 — Placement safety:** for every spawner in every shipped level JSON, assert position is
  ≥200px inside `bounds` (static data check via eval/level parse).

### Per-powerup (grant via eval, activate, measure)
- **P1 — Mega Bounce:** park p1 bouncing on a trampoline-tier surface, record 3 apexes
  (min-y between contacts): baseline apex ≈ surface_y − 270px (±10%). Activate mega_bounce →
  next 3 apexes each ≥ surface_y − 500px (≥1.85× lift) within 6s. Effect ends by 8.5s
  (apexes return to baseline ±10%). Screenshot mid-effect shows the contact shockwave ring.
- **P2 — Unlimited Boost:** activate, hold normal boost 5s continuously → `fuel == 100` the
  whole time and p1 climbs (Δy < 0 sustained). At t=8.5s, boost 1s → fuel < 100 (drain
  restored). Screenshot shows enlarged cyan flame.
- **P3 — Star:** activate on p1; eval-drive a bot into body contact → bot |Δv| ≥ 800 px/s
  away from p1 with hitstun > 0, p1 |Δv| ≤ 50 px/s and hitstun == 0. Eval a bot smash INTO
  starred p1 → same result (attacker launched). At t=5.5s contact behaves normally.
  Screenshot mid-effect shows rainbow tint + star trail. Hazard check: push starred p1 into
  spikes → dead (cause `spikes`).
- **P4 — Counter Shield:** activate on p1, within 2.0s eval a bot smash into p1 → bot
  launched ≥ 1200 px/s + hitstunned, p1 |Δv| ≤ 50 px/s. Repeat with the hit at t=2.2s →
  normal smash lands on p1. Screenshot during window shows the hex-bubble ring.
  Star-vs-counter: starred bot touches shielded p1 → the *starred bot* is launched.
- **P5 — Ball Storm:** activate → exactly 16 ball nodes exist within 0.2s; each ball that
  contacts a player (spawn a parked bot cluster via eval) despawns after applying ≥400 px/s
  to the victim; all balls gone by t=6.5s; owner takes no hit before t=0.5s. `perf` during
  the storm with 4 players: avg ≥55fps.
- **P6 — Black Hole:** place a bot 600px from p1 with `fuel = 0` (eval), activate → p1's
  position stays within ±8px for 2.0s (frozen channel), bot's distance to p1 < 200px by
  channel end, `p1.fuel == 100` at end. Counterplay: repeat with bot at `fuel = 100`
  hold-boosting away → bot's distance never < 300px. Cancel: smash the channeler at t=1.0s
  → pull stops, no fuel refill. Screenshot mid-channel shows vortex + inward streaks.
- **P7 — Ring of Fire:** plant a ring, drive a bot through it with aim held right → bot
  vx ≥ +2200 px/s within 0.1s of crossing, bot hitstun == 0, bot fuel unchanged. Owner
  crossing at t=0.5s: nothing; at t=1.5s: launched. Ring gone after 3 triggers or at
  t=8.5s. Kill credit: a ring launch that carries a bot past `bounds` scores +1 to the
  ring's owner (eval scores). Screenshot shows the flaming ring readable at full zoom.

### Comedy check (judgment, evidence-backed — same style as v0 spec #19)
- **C1:** QA plays 3 matches with powerups on and reports: did at least one powerup-caused
  *self*-ring-out happen per match (mega-spring top-out, unlimited overshoot, or ring-of-fire
  self-launch)? Did players visibly converge on a star spawn? Were any two active effects
  ever confusable in a screenshot (must be no — Pillar 5)?

---

## 6. New/changed tuning constants (add to `Tuning.gd`)

```
# spawner
pu_first_spawn            = 4.0    # s after BOUNCE! before first telegraph
pu_spawn_interval         = 7.0    # s between spawns (replaces powerup_spawn_interval 8.0)
pu_spawn_telegraph        = 1.0    # s of sparkle before the bubble is live
pu_max_on_field           = 2

# durations (changed: star 6→5, unlimited 10→8)
pu_unlimited_boost_dur    = 8.0
pu_mega_bounce_dur        = 8.0
pu_star_dur               = 5.0
pu_counter_dur            = 2.0
pu_black_hole_dur         = 2.0
pu_ring_lifetime          = 8.0

# magnitudes
pu_mega_bounce_mult       = 2.0
pu_star_contact_impulse   = 900.0   # px/s, 1.5x smash_impulse_base
pu_counter_reflect_impulse= 1400.0  # px/s, half a full super
pu_ball_count             = 16
pu_ball_hit_impulse       = 500.0   # px/s along ball velocity
pu_ball_lifetime          = 6.0
pu_ball_owner_grace       = 0.5
pu_black_hole_radius      = 700.0
pu_black_hole_pull        = 2600.0  # px/s^2 constant-in-zone; must stay < normal_boost_accel
pu_ring_max_triggers      = 3
pu_ring_retrigger_cd      = 1.5
pu_ring_owner_grace       = 1.0
```

## 7. Explicitly out of scope for this spec

Wings / Slow-Mo / Air Mine and the rest of the GDD §5 list (post-v1 roster growth), powerup
unlock/progression gating, arena-wide powers (Super Bouncy, floor-is-lava), per-circuit
powerup pools, bot powerup-seeking behavior tuning beyond "bots may collect and use via the
existing `use_powerup` intent" (a dedicated bot-powerup-brain pass is its own future task),
and any audio (SFX slots are named in-line; the audio pass wires them later).
