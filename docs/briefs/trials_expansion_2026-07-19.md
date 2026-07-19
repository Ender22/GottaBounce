# TRIALS Course Expansion — Circuits 2-5 to 8 Courses Each

> Design brief (ideation/audit phase). Author: Level Designer. Date: 2026-07-19.
> **This doc contains NO level JSON.** It is the spec that feeds the level-designer/programmer
> (build the JSON-ONLY courses) and the art director (new-asset list — spoiler: there is none).
> Read order for the builder: `docs/GAME_ESSENCE.md` (flight-required rule), this doc, then the
> cited existing course JSONs as templates.

## Scope
Bring TRIALS circuits 2-5 up to **8 courses each** with a proper teach-then-build curve.

| Circuit | id | Now | Add | Final |
|---|---|---|---|---|
| NEEDLE & KEY | navigation | 5 | +3 | 8 |
| GOAL RUSH | soccer | 4 | +4 | 8 |
| THE PHYSICS LAB | physics | 4 | +4 | 8 |
| ORBIT | orbit | 3 | +5 | 8 |

**Total new courses: 16. Implementation tally: 16 JSON-ONLY, 0 NEEDS-CODE, 0 NEEDS-ART.**
(Two courses carry an engine RISK flag that could escalate to a small NEEDS-CODE tweak — see Risks.)

---

## Shared reference — the numbers every flight-required proof uses
From `src/core/Tuning.gd` (reference scale, gravity y-down):

- **gravity** 1600 px/s^2. Player diameter ~88-92px.
- **Bounce apex by tier:** marshmallow 120 / bubblegum 180 / trampoline 270 / **spring 480**.
  `bumper` = a wall tier: bounces (restitution 0.86) but **refunds NO fuel** and is not a launch pad.
- **Zero-boost passive-bounce horizontal reach** (apex + air-drift 340px/s): ~**395px** off a
  trampoline, ~**527px** off a spring. Any gap wider than this is **not bounce-crossable** → flight
  required. This is the load-bearing number for the movement-tool-per-gap proof.
- **Normal boost:** cap 760 px/s, drain 28.6 fuel/s, ~26.6px of powered flight per fuel, **one full
  tank (100) ≈ 2660px** of level flight. Boost can NEVER reach the smash gate (INV-1).
- **Fuel refund:** +20 per bounce-surface touch (trampoline/spring/marshmallow); bumper walls give 0.
- **Super:** impulse 2800 → apex ~2450px above launch; dumps the whole tank; `super_active` 0.45s.
  A super drive on the ball is capped at x2 (ball speed cap 2400).
- **Smash gate** 900 px/s closing speed. A **253px free-fall hits exactly 900** (dive math:
  `sqrt(2*1600*fall)`). Below 900 nothing smashes a `break_on:"smash"` block.
- **Cannon** default impulse 2600; muzzle offset = barrel_len(190)+40 = 230px along the barrel.
- **Ball drive** (Ball._drive_from): `dv = (500 + 0.9*player_speed)/mass 0.6` along the away/travel
  blend; restitution 0.85; floor 500 → min 833 px/s on any touch; ball radius 60.

### Object / mechanic palette available (LevelLoader.gd — all reusable, no code needed)
platforms(tier) · void(display+kill line at bounds bottom) · spikes(instakill) ·
**moving_hazard**(pendulum/sweep SHOVE, never kills; players only, not the ball) ·
**spinning_hammer**(LETHAL rotor) · **crusher**(LETHAL) · **falling_debris**(LETHAL) ·
**bomb**(LETHAL radial blast; punts ball via receive_hazard_impulse; does NOT damage blocks) ·
**destructible_block**(break_on hit≥300px/s or smash=super/≥900px/s; tier; hp) ·
**moving_platform**(SOLID carrier deck; vehicle skin; tier/w/h/center/axis_deg/amplitude/period_s/
phase/dwell_frac; never lethal) · **cannon**(rideable; angle_min/max/period_s/impulse/hold_s) ·
**key**(r,door) + **key_door**(w,h,door; solid bumper barrier, opens when all its keys collected) ·
**gravity_source**(radius,g,body_r,tier,visual moon|black_hole,optional lethal_core_r) ·
**ball** spawn + **goal_zone**(team) + **drop_tile**(ball-only breakable floor) ·
**pickup**(r; COLLECT_ALL) · **land_target**(w,h,land_speed_max; PRECISION_LAND) ·
**start_gate** / **goal_gate**(w,h; reach-to-win).
Objectives: reach-goal (no objective block) · PHYSICS_PUZZLE(win:ball_in_goal, reset_settle_s) ·
DESTROY_ALL · COLLECT_ALL · SURVIVE(survive_seconds) · PRECISION_LAND(land_speed_max, sequence).

---

# Circuit 2 — NEEDLE & KEY (navigation)

**Teaches:** hard precision navigation — thread tiny holes with controlled flight, climb bumper
walls on refuel ledges, land precise refuels across long voids, fetch keys to open doors.

## Audit (current 5)
| # | Course | What it does | Diff |
|---|---|---|---|
| 1 | n2_wall_climb | Boost up two 2200px bumper chimneys; interior trampoline ledges are the only fuel (walls refund nothing). | 3 |
| 2 | n2_needle_thread | Fly through 3 full-height walls, each a single mouth escalating 240→200→160px. | 3 |
| 3 | n2_refuel_ridge | 6280px void crossing; six tiny 120px pads are the ONLY fuel — land all or fall short. | 4 |
| 4 | n2_locksmith | First key/door: detour up a chimney for one key, unlock the goal door. | 3 |
| 5 | n2_master_vault | Capstone: two keys / two doors, forcing climb-then-thread order. | 5 |

**Arc problem:** no gentle opener. Course 1 is already a difficulty-3 double chimney; threading and
climbing are never shown in isolation first. Fix: add a dead-simple threading teach at the front,
reorder so the two "verbs" (thread, climb) precede their hard combinations, and add a clever timed
twist before the capstone.

## Proposed order (8)
| Slot | Course | Status | Diff | Tag |
|---|---|---|---|---|
| 1 | n2_pinhole | **NEW** | 1 | JSON-ONLY |
| 2 | n2_needle_thread | keep | 2 | — |
| 3 | n2_wall_climb | keep | 2 | — |
| 4 | n2_slalom | **NEW** | 3 | JSON-ONLY |
| 5 | n2_refuel_ridge | keep | 3 | — |
| 6 | n2_locksmith | keep | 3 | — |
| 7 | n2_shifting_needle | **NEW** | 4 | JSON-ONLY (RISK) |
| 8 | n2_master_vault | keep | 5 | — |

### NEW — n2_pinhole.json — "One Clean Thread" — diff 1 — [JSON-ONLY]
- **Hook:** a single generous porthole in one wall — learn to fly through a hole.
- **Teaches (isolated):** the whole circuit's core verb — line up, feather boost, commit through an
  aperture — with ZERO stacking. One wall, one wide mouth, no keys, no long void.
- **Layout:** start pad (trampoline) left at y=1000. One full-height bumper wall at x≈1300 (y −800..1300)
  with a single **300px** mouth (74px→104px clearance per side vs 92px player) centered at the boost
  altitude, y≈650. Goal pad + goal_gate on the right at x≈2200. Void under everything.
- **Flight-required:** mouth center sits ~350px above the start pad top (>trampoline apex 270) and the
  pad-edge→wall-exit span is ~500px (>395 drift) → must be FLOWN through, cannot be bounced. Miss →
  void → free respawn.

### NEW — n2_slalom.json — "S-Bend" — diff 3 — [JSON-ONLY]
- **Hook:** three needles staggered to alternating sides — thread a zig-zag without over-steering.
- **Teaches (combine):** threading (from #1/#2) + **air-drift momentum control** — each mouth is
  offset left/right of the last, so you must kill sideways speed and re-aim between holes instead of
  flying one straight line.
- **Layout:** four bumper walls at x≈900/1700/2500/3300, mouths ~200px, centered at alternating
  heights/offsets (mouth1 high-left y≈500, mouth2 low-right y≈900, mouth3 high-left y≈450). Small
  trampoline refuel pad between walls 2 and 3 (a mid-run bank stop). Goal right. Void below.
- **Flight-required:** each inter-wall span is 600-700px (>527 spring drift) and the vertical
  offset between consecutive mouths is 350-450px (>trampoline apex), so a passive bounce can never
  line up the next hole — controlled boost + drift each segment. Mirrors n2_needle_thread's proven
  wall geometry; only the offsets are new.

### NEW — n2_shifting_needle.json — "Moving Target" — diff 4 — [JSON-ONLY (RISK)]
- **Hook:** the needle's gap slides open and shut — thread it on the beat, then grab the key behind it.
- **Teaches (combine + twist):** threading + **timing** + key/door. A `moving_platform` (a tall thin
  **bumper-tier** deck, `axis_deg:0`, oscillating horizontally on a ~3.5s period) rides in front of a
  fixed wall gap; when the deck is at one end of its travel the aperture is open, when centered it
  seals. You wait for the open phase and fly through. One `key` hangs just past the moving gap;
  `key_door` seals the goal.
- **Layout:** start pad left. Fixed bumper wall x≈1400 with a 320px static opening y≈550..870; a
  moving_platform bumper deck (w≈160, h≈360) oscillates ±180px across that opening (period 3.5s,
  dwell 0.15) → the effective mouth pulses ~160px→open. Key at x≈1650 (past the gap). key_door "d1"
  spanning void-line→past-ceiling at x≈2400. Goal pad right. Void below; falls = free respawn, keys
  stay collected.
- **Flight-required:** the gap-to-goal legs (600-700px) exceed spring drift; the wall itself can only
  be crossed through the aperture. The *timing* is the new axis. Fall/mistime = free respawn.
- **RISK (see Risks section):** uses `moving_platform` as a **moving WALL** (side-collision, bumper
  tier) rather than a top-ride deck. If MovingPlatform.gd doesn't cleanly honor bumper tier / side
  bounces, this needs a tiny programmer tweak (→ NEEDS-CODE). Fallback that is 100% JSON-ONLY: replace
  the moving wall with a fixed 160px needle mouth (a static Master-Vault-grade squeeze) + key + door,
  losing only the timing twist.

**Circuit 2 tally:** 3 JSON-ONLY (1 with RISK), 0 NEEDS-CODE, 0 NEEDS-ART.

---

# Circuit 3 — GOAL RUSH (soccer)

**Teaches:** the player-driven shoulder-drive — fly INTO the ball, `Ball._drive_from` imparts
velocity along the away/travel blend. Skills ladder: power → angle/loft → carom/bank → thread →
break-in → timing.

## Audit (current 4)
| # | Course | What it does | Diff |
|---|---|---|---|
| 1 | s3_tap_in | Flat drive into an open ground goal across a small deck gap. TEACH the drive. | 1 |
| 2 | s3_top_corner | Goal mounted HIGH; strike the ball's underside to loft it (~45°). TEACH angle. | 2 |
| 3 | s3_wall_pass | Goal sealed behind a blocker + crossbar; only entry is over-the-wall bank off the back. | 3 |
| 4 | s3_hazard_striker | Flat strike but the lane is guarded by twin offset fuse bombs — fire in the quiet window. | 4 |

**Arc problem:** solid teach→angle→bank→timing, but only 4 courses and it jumps from a single bank
(3) to a bomb gauntlet (4) with no power lesson and no exploration of the ball-vs-object palette
(drop_tile, bumper fields) the engine already supports. Fix: insert power early, then a thread and a
carom-chain, then a novel drop-through, keeping the bomb gauntlet as capstone.

## Proposed order (8)
| Slot | Course | Status | Diff | Tag |
|---|---|---|---|---|
| 1 | s3_tap_in | keep | 1 | — |
| 2 | s3_top_corner | keep | 2 | — |
| 3 | s3_long_ball | **NEW** | 2 | JSON-ONLY |
| 4 | s3_wall_pass | keep | 3 | — |
| 5 | s3_keyhole | **NEW** | 3 | JSON-ONLY |
| 6 | s3_pinball_alley | **NEW** | 4 | JSON-ONLY |
| 7 | s3_trapdoor | **NEW** | 4 | JSON-ONLY (RISK) |
| 8 | s3_hazard_striker | keep | 5 | — |

### NEW — s3_long_ball.json — "The Long Ball" — diff 2 — [JSON-ONLY]
- **Hook:** the goal is a whole pitch away — you have to REALLY hit it.
- **Teaches (isolated):** POWER. A flat, wide pitch where the goal sits far enough (and behind a
  small mid-pitch lip) that a lazy touch (833px/s floor) dies short in a void gap; only a
  full-boost drive (~1973px/s) — or a super-drive (x2 cap 2400) — carries the ball the distance.
  Introduces the super as the power club before angle-heavy courses.
- **Layout:** long marshmallow deck; ball rests left-center; a 200px void gap ~2/3 across (the
  "no-slow-dribble" guard); open ground goal_zone far right against a bumper backstop. No hazards.
- **Flight-required (player):** the player must fly to the ball and commit a full-boost approach
  (the whole point). A weak hit falls in the gap → auto-reset (reset_settle_s 2.8), unlimited tries.

### NEW — s3_keyhole.json — "Keyhole" — diff 3 — [JSON-ONLY]
- **Hook:** thread the BALL through a slot barely bigger than it — Needle & Key comes to the pitch.
- **Teaches (combine):** power + precise aim. A boxed goal sits behind a bumper wall with a single
  ~180px keyhole slot (ball radius 60). Drive too high, too low or too hard-off-angle and the ball
  smacks bumper and rebounds; a clean, well-aimed medium drive threads it into the pocket. Cross-
  pollinates the navigation circuit's "thread the needle" fantasy onto the ball.
- **Layout:** deck, ball left. A tall bumper wall x≈1500 with a 180px horizontal slot at the ball's
  natural flat-drive height (y≈980); goal_zone in a small bumper pocket behind it (x≈1700-2000). Void
  below. A too-fast super-drive caroms off the slot lip (self-limiting), so normal boost is the tool.
- **Flight-required (player):** fly into the ball with a controlled ~flat drive; misses rebound or
  fall out → auto-reset.

### NEW — s3_pinball_alley.json — "Pinball Alley" — diff 4 — [JSON-ONLY]
- **Hook:** the goal is tucked in a corner you can only reach off two bumpers — read the ricochet.
- **Teaches (escalate wall_pass):** multi-carom reading. A short field of 2-3 static bumper
  reflectors funnels a driven ball around a hard corner into an offset goal; the direct line is
  walled off, so the intended solve is a deliberate double-bank (restitution 0.85 keeps it lively).
- **Layout:** ball left; a bumper baffle blocks the direct line; an angled bumper high-right and a
  bumper back wall form a two-cushion path into a goal_zone in the bottom-right pocket. Void below the
  approach so a flubbed drive dies. Pure static geometry — zero engine risk.
- **Flight-required (player):** committed boost drive to supply the energy for two live caroms; a
  soft touch loses too much to restitution and stalls → reset.

### NEW — s3_trapdoor.json — "Trapdoor" — diff 4 — [JSON-ONLY (RISK)]
- **Hook:** the goal is UNDER the floor — smash the ball through a trapdoor to score.
- **Teaches (novel):** the DROPSHOT ball-vs-`drop_tile` interaction, repurposed for trials. A
  `drop_tile` floor tile caps a goal_zone below it; first ball hit cracks the tile, second breaks it
  open, and a third drives the ball down through the hole into the buried goal. Teaches repeated
  controlled downward strikes (dive the ball onto the tile) — a vertical scoring verb.
- **Layout:** deck with the ball on it; a drop_tile set into the deck at x≈1400 with a hidden
  goal_zone strip directly beneath (mirrors the DROPSHOT under-floor pattern in `levels/sports/`).
  Player must fly ABOVE the ball and drive it downward onto the tile repeatedly. Bumper rails keep the
  ball over the tile. Void at the far edges only.
- **Flight-required (player):** downward drives require flying up and over the ball each time (the
  vertical-strike skill), not a flat push.
- **RISK:** `drop_tile` + trials `goal_zone`/PHYSICS_PUZZLE is the SPORTS plumbing reused in a solo
  trials context — shipped and supported by LevelLoader but this exact combination is unvalidated.
  Needs a rendered playtest to confirm the tile cracks on ball contact and the under-floor goal
  latches `ball_in_goal`. If not, fall back to a pure bumper-pocket goal (drop the drop_tile). Still
  JSON-ONLY either way; the flag is a validation ask, not a code ask.

**Circuit 3 tally:** 4 JSON-ONLY (1 with RISK), 0 NEEDS-CODE, 0 NEEDS-ART.

---

# Circuit 4 — THE PHYSICS LAB (physics)

**Teaches:** two intertwined threads — RIDE rideable cannons (fixed → oscillating → chained) and
BREAK destructibles (hit → dive/smash → super), then combine (be the projectile / dive through a
roof). Bombs gate routes (they never damage blocks).

## Audit (current 4)
| # | Course | What it does | Diff |
|---|---|---|---|
| 1 | p4_cannon_school | Two FIXED cannons chain the player across a huge void. TEACH the ride. | 1 |
| 2 | p4_demolition_day | DESTROY_ALL 10 crates across THREE sub-puzzles (chain-dive tower, sealed box, high shelf). | 3 |
| 3 | p4_swing_shot | An OSCILLATING cannon; when you load decides where you land (thread a tower, hit a needle pad). | 3 |
| 4 | p4_chain_reaction | Capstone: ride a cannon over a bomb field, dive through a crate roof into a sealed goal. | 5 |

**Arc problem:** course 1→2 is a cliff — demolition_day teaches THREE break-mechanics at once with
no prior isolated "break one crate" lesson (violates "teach one thing"). And the cannon thread has
only school→swing→chain. Fix: add an isolated break teach and an isolated chain-dive teach BEFORE
demolition_day, and a second oscillating-cannon step + a cannon-as-wrecking-ball step before the
capstone.

## Proposed order (8)
| Slot | Course | Status | Diff | Tag |
|---|---|---|---|---|
| 1 | p4_cannon_school | keep | 1 | — |
| 2 | p4_first_break | **NEW** | 2 | JSON-ONLY |
| 3 | p4_demolition_drop | **NEW** | 2 | JSON-ONLY |
| 4 | p4_demolition_day | keep | 3 | — |
| 5 | p4_swing_shot | keep | 3 | — |
| 6 | p4_double_barrel | **NEW** | 4 | JSON-ONLY |
| 7 | p4_breach | **NEW** | 4 | JSON-ONLY |
| 8 | p4_chain_reaction | keep | 5 | — |

### NEW — p4_first_break.json — "First Break" — diff 2 — [JSON-ONLY]
- **Hook:** one crate blocks the door — dive on it or super it.
- **Teaches (isolated):** the destructible + the two smash verbs, alone. A single `break_on:"smash"`
  hp1 crate plugs a gap on the only path to the goal. Plain boost (760) can't touch it (INV-1); the
  player learns that a **253px+ dive** (=900px/s) or a **super** is the demolition charge. This is the
  missing prerequisite for demolition_day.
- **Layout:** start pad → short void hop → a smash crate wedged in a bumper gateway at head height →
  goal pad beyond. A small perch above the crate lets you climb ~300px and free-fall onto it (dive),
  or aim a super. Break it, fly through, reach goal. Void below.
- **Flight-required:** the perch-to-crate is a boost climb (>trampoline apex); the break itself is a
  flight verb (dive = a controlled flight exit, or super). Fall = free respawn; crate stays broken.

### NEW — p4_demolition_drop.json — "Chain Dive" — diff 2 — [JSON-ONLY]
- **Hook:** a stacked column of crates — dive in and let each break-bounce feed the next.
- **Teaches (isolated):** the chain-dive rhythm — demolition_day's sub-puzzle A extracted into its
  own course so the rhythm is learned before it's one of three things. A vertical stack of
  trampoline-tier smash crates; dive onto the top one, it bounces you (apex 270) as it cracks, the
  re-fall hits the next at ~930px/s, and the stack eats itself top-down, opening a chute to the goal
  below.
- **Layout:** two permanent bumper side-walls form a shaft over a void; a 4-5 high column of
  `break_on:"smash"` hp1 crates fills the shaft; goal_gate at the bottom of the shaft, reachable only
  once the column is cleared. Climb above (boost), dive, ride the rhythm down. A downward super is the
  panic alternative (super_active 0.45s registers on each block's independent hit_cd).
- **Flight-required:** climb to the top is boost (>apex); the descent is a dive chain; recovery from
  a missed bounce is boost-or-void (free respawn, crates stay broken in-run).

### NEW — p4_double_barrel.json — "Double Barrel" — diff 4 — [JSON-ONLY]
- **Hook:** two swinging cannons back-to-back — read both sweeps.
- **Teaches (escalate swing_shot):** sequential timed cannons. After swing_shot teaches one
  oscillating barrel, this chains TWO: load cannon A on the right phase to land in a mid catch-basin,
  immediately re-load cannon B (its own sweep, different period so they don't sync) to thread a wall
  and hit the goal plateau. No new mechanic — just doubled timing pressure.
- **Layout:** copy swing_shot's proven ballistics. Cannon A (oscillating −80..−25, period 2.8s) →
  catch basin (marshmallow, wide, generous). Cannon B (oscillating, period ~3.1s so the two phases
  drift) → over a bumper tower → goal plateau. Void everywhere between. Explicit bounds sized for the
  arcs (top clears the max-phase apex, per swing_shot's −2100).
- **Flight-required:** two ~3000px void spans crossed only by the rides; loading each cannon off its
  basin is a boost climb. Every miss = free respawn.

### NEW — p4_breach.json — "Wrecking Ball" — diff 4 — [JSON-ONLY]
- **Hook:** BE the cannonball — get fired into a wall to smash it open.
- **Teaches (combine, capstone prep):** cannon + break together. A fixed cannon fires the player at
  cannon speed (2600 > 900 smash gate) straight into a `break_on:"smash"` wall that seals the route;
  YOU are the demolition charge. This isolates chain_reaction's key idea (impact-as-tool) before the
  full capstone stacks bombs on top.
- **Layout:** start pad → load a fixed cannon aimed at a smash-crate wall across a void (the wall
  caps a corridor to the goal). The cannon arc drives you through the wall on contact (contact speed
  ≥2600 breaks hp1); you fly through the breach and land on the goal pad beyond. Provide a second
  smash block or two so it reads as "smashing a hole," and a bumper backstop so an over-shoot
  rebounds rather than voids. Void below.
- **Flight-required:** the void is cannon-only; loading the cannon is a boost climb; the breach needs
  a smash-grade impact (cannon or super — boost alone can't). Fall = free respawn; wall stays broken.

**Circuit 4 tally:** 4 JSON-ONLY, 0 NEEDS-CODE, 0 NEEDS-ART.

---

# Circuit 5 — ORBIT (orbit / gravity)

**Teaches:** `gravity_source` radial wells — a planet is a floor in every direction; use wells
instead of fighting them; hop between worlds. Skills ladder: planet-is-floor → orbit navigation →
escape a well → slingshot → respect a lethal core → chain slings → world-hop → grand tour.

## Audit (current 3)
| # | Course | What it does | Diff |
|---|---|---|---|
| 1 | g6_moonwalk | One moon (body_r 200, field 1000); goal below the south pole — bounce AROUND the planet. TEACH planet-is-floor. | 1 |
| 2 | g6_slingshot | A black-hole well between start and a far-rim goal — dive in, whip around the bumper core, release on the outswing. | 3 |
| 3 | g6_binary_run | Two moons diagonal with a neutral global-down gap — hop worlds to a goal past the second. | 4 |

**Arc problem:** only 3 courses and a big jump from a static single moon (1) to a slingshot (3) with
no intermediate "navigate a full orbit" or "escape the well" lesson, and the lethal-core option
(`lethal_core_r`) — the obvious gravity danger — is never used. Fix: add an orbit-collect and an
escape-velocity teach in the low tier, a lethal-core and a chained-sling in the mid/high tier, and a
three-world grand-tour capstone.

## Proposed order (8)
| Slot | Course | Status | Diff | Tag |
|---|---|---|---|---|
| 1 | g6_moonwalk | keep | 1 | — |
| 2 | g6_orbit_ring | **NEW** | 2 | JSON-ONLY |
| 3 | g6_liftoff | **NEW** | 3 | JSON-ONLY |
| 4 | g6_slingshot | keep | 3 | — |
| 5 | g6_dead_star | **NEW** | 4 | JSON-ONLY |
| 6 | g6_gravity_chain | **NEW** | 4 | JSON-ONLY |
| 7 | g6_binary_run | keep | 4 | — |
| 8 | g6_solar_tour | **NEW** | 5 | JSON-ONLY |

### NEW — g6_orbit_ring.json — "Full Moon" — diff 2 — [JSON-ONLY]
- **Hook:** tokens ring the whole planet — orbit all the way around.
- **Teaches (build on moonwalk):** sustained radial navigation. COLLECT_ALL with 6-8 `pickup` tokens
  spaced evenly around a single moon at just above surface height; grab them all by bouncing/flying a
  full loop around the planetoid (each surface touch refunds +20), then reach the goal. Turns
  moonwalk's one-arc lesson into a full-orbit habit.
- **Layout:** one moon (body_r 200, field r 1000, g 1300, visual moon) centered in frame; 6 tokens at
  the compass points ~120px off the surface; start_gate on the north pole; goal_gate at the south
  pole (reach after collecting — or make the last token the finish). Bounds frame the whole field.
- **Flight-required:** tokens on the field's far side are unreachable by any single bounce — you must
  ride the curved floor around (radial gravity keeps you attached; casual bounces stay inside r1000:
  200+270 << 1000). A fall out of the field drops to global-down → free respawn.

### NEW — g6_liftoff.json — "Liftoff" — diff 3 — [JSON-ONLY]
- **Hook:** the goal is in orbit ABOVE the moon — boost hard enough to escape the pull.
- **Teaches (isolated):** escape velocity / boosting AGAINST radial gravity. The goal sits on a small
  platform just OUTSIDE the field radius above the pole; a casual bounce (apex 270, inside r1000)
  always falls back — only a sustained boost climb breaks out of the well to reach it.
- **Layout:** one moon (body_r 200, field r 900, g 1350). start_gate on the surface; a small
  trampoline landing pad + goal_gate at ~y such that it sits ~150px beyond the field edge straight
  above the pole. The player must boost radially outward through the field boundary and touch down /
  fly through the gate. A miss falls back to the moon (safe) or past it into global-down (respawn).
- **Flight-required:** the escape distance (surface→goal) exceeds spring apex and requires sustained
  thrust against the pull (boost_gravity_scale 0.8 while thrusting gives the climb authority) — the
  purest "flight required, not bounce" gate in the circuit.

### NEW — g6_dead_star.json — "Dead Star" — diff 4 — [JSON-ONLY]
- **Hook:** a black hole with a killing core — sling past it without falling in.
- **Teaches (add danger to slingshot):** respect-the-core. A black-hole well with a `lethal_core_r`
  (a real kill radius at its center, via the existing Hazard path) sits across the route; the pull
  drags you toward death, so you must enter with enough tangential speed/angle to whip PAST the core,
  not into it. Slingshot's assist, now with a consequence.
- **Layout:** start pad (outside the field, left); a black-hole gravity_source (field r 1200, g 1100,
  body_r 80, `lethal_core_r` ~130, visual black_hole) mid-route; goal ring on the far rim. The safe
  line is a wide sling arc; a timid straight dive spirals into the lethal core → free respawn.
- **Flight-required:** the ~2400px crossing exceeds one tank's naive flight, so you must USE the well
  (sling) — but now the well can kill. Enter fast/tangential (boost to build the entry vector), ride
  the curve, release on the outswing. Miss into the core or short of the rim = free respawn.
- **Note:** `lethal_core_r` is a supported gravity_source field (LevelLoader P8 seam, owner
  2026-07-18) but has not shipped in a trials course yet — validate the kill radius reads clearly
  (the black_hole visual should telegraph the danger zone). Still JSON-ONLY.

### NEW — g6_gravity_chain.json — "Gravity Chain" — diff 4 — [JSON-ONLY]
- **Hook:** two wells in a row — sling out of one straight into the next.
- **Teaches (escalate slingshot):** chained slings / momentum handoff. Two black-hole wells spaced so
  the outswing of the first feeds the entry of the second; you carry momentum well to well without a
  footing in between, releasing boost only to tune each arc. A pure "use the wells, don't fight them"
  flow course.
- **Layout:** start pad left; black hole A (field r 1000, g 1050, bumper core) → neutral gap → black
  hole B (field r 1000, g 1050) → goal ring on B's far rim. Cores are bumper (non-lethal, like
  slingshot) to keep this a flow puzzle, not a death puzzle (that's dead_star's job). Bounds frame
  both fields.
- **Flight-required:** each ~1800-2000px leg is well-assisted; a straight-line boost across both
  (≈3600px) exceeds one tank, so the slings are structurally required. Falls out the bottom = free
  respawn.

### NEW — g6_solar_tour.json — "Grand Tour" — diff 5 — [JSON-ONLY]
- **Hook:** three worlds, one lethal, one hop, one ring — the whole gravity toolbox.
- **Teaches (capstone / combine):** everything — land-on (moon), sling-past-danger (black hole with
  lethal core), and world-hop (binary_run's gap). A three-body route: bounce around Moon A to build a
  line, sling past a lethal-core black hole B (dead_star's verb), then hop the neutral gap into Moon
  C's field (binary_run's verb) and exit to the goal ring on C's far side.
- **Layout:** Moon A (moon, r800 field) lower-left with start_gate on its pole; black hole B (field
  r1100, lethal_core_r ~120) upper-middle across a gap; Moon C (moon, r800) right with the goal_gate
  past its far rim. Neutral global-down gaps between each. Bounds frame all three.
- **Flight-required:** every world-to-world leg exceeds bounce reach and one is a lethal sling; the
  route cannot be completed without well-assisted flight, escape boosts, and a led gap-hop (global
  down pulls mid-flight — lead the jump). The synthesis of all seven prior courses. Falls = free
  respawn at Moon A.

**Circuit 5 tally:** 5 JSON-ONLY, 0 NEEDS-CODE, 0 NEEDS-ART.

---

# Cross-cutting: new-art and new-mechanic asks (for the next phase)

- **New ART asks: 0.** Every new course reuses shipped themes/backdrops (grass meadow, open_sky +
  space_nebula for orbit, overcast_quarry/industrial for hazards) and shipped object visuals (moon /
  black_hole gravity visuals, cannon, crate, ball, key/door, moving_platform vehicle skin, tokens).
  Nothing here requires a new sprite or backdrop.
- **New MECHANIC (code) asks: 0 required.** All 16 are buildable from the existing LevelLoader
  palette. TWO courses carry an engine RISK that *could* turn into a small tweak if validation fails
  (both have JSON-ONLY fallbacks):
  1. **n2_shifting_needle** — `moving_platform` used as a moving WALL (side collision / bumper tier).
     If MovingPlatform.gd doesn't behave as a solid moving wall, needs a minor "moving wall" tweak
     (honor bumper tier + side bounce). Fallback: fixed 160px needle + key/door (drops the timing
     twist), fully JSON-ONLY.
  2. **s3_trapdoor** — `drop_tile` + trials `goal_zone`/PHYSICS_PUZZLE (SPORTS plumbing reused solo).
     Needs a rendered playtest to confirm ball-cracks-tile and under-floor goal latches. Fallback:
     bumper-pocket goal (drop the drop_tile), fully JSON-ONLY.

# Risks / opens for the builder
- **Explicit bounds required on every course** (all of these span far past a single screen). Copy the
  derivation habit from the existing courses: top must clear a straight-up super apex from the highest
  reachable footing (~2450px), sides ±700 past geometry, bottom keeps the void line as the killer.
- **Flight-required proof is mandatory per course** before ship (GAME_ESSENCE): every listed gap must
  exceed 527px (spring drift) or 270px vertical (trampoline apex). The sketches are sized to that; the
  builder must re-check exact coordinates and record the movement-tool-per-gap analysis in each JSON's
  `design_intent`, matching the existing courses' rigor.
- **Orbit COLLECT_ALL (orbit_ring)** pairs `pickup` + `gravity_source` for the first time — validate
  tokens render/collect correctly inside a radial field at full-arena zoom.
- **`lethal_core_r` (dead_star, solar_tour)** has not shipped in trials — validate the kill core reads
  as dangerous (telegraphed by the black_hole visual) so a death feels fair, not random.
- **Difficulty pass:** the 1-5 targets are per-circuit relative. After building, a driven-player pass
  (not just a surviving bot) should confirm no cliff between consecutive slots and that each new
  course's ONE new idea is legible before the next stacks on it.
