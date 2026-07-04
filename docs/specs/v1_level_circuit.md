# Spec: v1 LEVEL CIRCUIT — a ~11-level VARIED circuit over the off-screen-kill through-line

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD (handed to level-designer + art-director).
> **v1 — 2026-07-04.** Fulfils STATUS NEXT-STEP #2 and the owner directive
> `docs/feedback/owner_2026-07-04_arena_variety.md` §1 ("islands-over-void ADOPTED, but levels VARY").
>
> **Template:** `levels/islands_void.json` (the FLAGSHIP — already built + validated). Every new level
> copies its structure: `theme`, `design_intent` (with the MANDATORY movement-tool-per-gap analysis),
> `sky_*`, `bounds`, `platforms[]` (tier-tagged), `objects[]` (void / spawns / powerup_spawners).
>
> **Scope of this doc:** MECHANICS + measurable targets per level, the flight-required proof intent,
> the kill-SHAPE identity, and build order. **NOT the level JSON** — the level-designer authors geometry
> within these constraints and re-runs the per-gap analysis at the real coordinates.

---

## 0. The through-line (inviolable — the shared identity every level keeps)

Owner directive: the kill identity is **"knock rivals OFF / THROUGH into a blast void → off the
screen."** Everything below VARIES the *shape* of that void and the *feel* of the arena, but every
level satisfies all of:

1. **Off-screen kill is the dominant death.** Deaths happen by crossing a bounds line (a void fall or a
   side/top blast), never by a mid-arena hazard alone. (Moving hazards SHOVE you toward a void; they do
   not themselves kill — see §L-D.)
2. **Flight is REQUIRED to traverse** (GAME_ESSENCE verb 2). Proven per level by the movement-tool-
   per-gap analysis in §1. A level playable without boosting is REJECTED.
3. **No standable safety / no camping** (Pillar 2). Every surface is a bounce tier; idle_hunt
   (`Tuning.idle_hunt_after = 4.0`) punishes stalling; no tier is a rest spot.
4. **The void READS as death** (art-director, `pit_void_rendering` treatment): dark bottomless gradient,
   receding canyon/dirt walls, matte hazard-red rim + chevrons, falling motes. Never safe green.
5. **The recovery gamble survives** (v0kzr S5 / v2 K4): a mid-stage healthy full-fuel player knocked
   toward a void has enough open sky + fuel to boost back. Near-edge / damaged / starved = gone.

**Variety is over the void SHAPE + arena feel, not over the identity.** The nine new levels below
deliberately span: horizontal archipelago (flagship), enclosed vertical floor-hole, multi-void,
exposed spine, moving-hazard funnel, vertical dual-blast, asymmetric, radial ring, and interior-bumper
pinball. Together they exercise verticality, enclosure, multi-void, moving hazards, and asymmetry while
never leaving the shared kill identity.

---

## 1. The FLIGHT-REQUIRED RULEBOX (cite this in every level's design_intent)

All numbers derived from `src/core/Tuning.gd` (reference scale: char H ~= 110px, gravity `1600`).

**Zero-boost horizontal reach off a bounce** (the traversal a player gets with NO fuel — air drift
only, `air_drift_max_speed = 340`):
- Off a **trampoline** (`bounce_height_trampoline = 270`): air time ~1.16s -> reach **~395px**.
- Off a **spring** (`bounce_height_spring = 480`, the highest tier): air time ~1.55s -> reach **~527px**.
- Off bubblegum (`180`) ~320px; marshmallow (`120`) ~260px.

**RULE A — horizontal gaps.** Any gap a player MUST cross to reach another surface is **>= 560px** of
open void (comfortably above the 527px max spring drift, and >> 395px trampoline). This forces a
`normal_boost` (`normal_boost_max_speed = 760` crosses a 680px gap in <1s at ~26 fuel; a bounce refunds
`fuel_per_bounce = 20`). islands_void uses **680px** — a good default. Never author a required crossing
< 540px (it becomes bounce-hoppable = flight dead).

**RULE B — elevated pads.** Any pad a player MUST reach upward sits **>= 500px above** the nearest
bounce surface's top (above `bounce_height_spring = 480` apex from below), so no bounce reaches it and a
`normal_boost` climb (`normal_boost_accel = 4600 > gravity 1600`) is required. islands_void uses **520px**.

**RULE C — the super is the cross-map play, not the baseline.** `super_boost_impulse_full = 2800` clears
any single gap and reaches distant thrones fast — but it dumps the whole tank (`fuel_max = 100`), so it
is the committed play, not routine traversal. Levels should offer at least one gap/climb where a super
is the *rewarding* option (contest a throne, cross the widest chasm) without being the *only* option.

**RULE D — recovery sky.** The vertical drop from a surface bottom to the bottom bounds line must be
**>= ~650px** of open air (islands_void: ~670-870px) so a knocked-off fuelled player can boost back
(recovery gamble). If a void is too shallow, a knock = instant unrecoverable death (kills S5/K4).

**Every level's design_intent MUST include a per-gap block** listing each required gap/climb, its px
size, the tier(s) adjacent, which reach number it beats, and the verb it forces (all should read FLY).

---

## 2. The circuit roster (target ~11: flagship + existing variant + 9 new)

| # | Level | Void SHAPE | Feel axis | Kill-shape class* |
|---|---|---|---|---|
| 1 | `islands_void` (BUILT) | one full-width bottom void, 4 islands + 2 thrones | horizontal archipelago | void_is_floor |
| 2 | `grassy_expanse` (EXISTS) | single central pit in a wide floor | big chase map | central_pit |
| 3 | `drop_chamber` (owner seed) | ONE central hole in the floor of an ENCLOSED cylinder | contained vertical chaos | enclosed_hole |
| 4 | `twin_chasms` | TWO separate voids flanking a center island | multi-void asymmetry | void_is_floor |
| 5 | `the_spine` | full void on both sides + below one long thin ridge | max exposure / edge play | void_is_floor |
| 6 | `wrecking_yard` | islands over void + a MOVING shove-hazard | moving-hazard funnel | void_is_floor |
| 7 | `the_ascent` | bottom void + a LOW ceiling (top blast live) | vertical dual-blast | dual_blast |
| 8 | `the_cliff` | one big safe mesa, scatter of tiny pads over void | asymmetric spawn tension | void_is_floor |
| 9 | `atoll` | ring of islands around a central void well | radial in/out | central_pit + ring |
| 10 | `bumper_gauntlet` | islands over void studded with interior bumpers | pinball ricochet | void_is_floor |
| 11 | `spires` | deep void, tall narrow spire-tops, big vertical gaps | extreme verticality | void_is_floor |

*Kill-shape class drives the QA metric selection — see `docs/specs/v2a_kill_shape_void_floor_addendum.md`
(the K1 edge/pit target does NOT apply uniformly; void_is_floor levels use K1'). Cite the class in each
level's `design_intent`.

---

## 3. Per-level specs

Each level: **theme/setting · void SHAPE + placement · signature gimmick/identity · tier/platform sketch
· movement-tool-per-gap intent (flight-required proof) · measurable success criteria.** Coordinates are
SKETCHES for the level-designer to finalize; the px GAPS and CLIMBS are the load-bearing constraints.

### §L-3 `drop_chamber` — the owner's CYLINDER (build this one first among the new)

- **Theme/setting:** an enclosed circular/octagonal **chamber** — glossy toybox "mixing bowl" or
  "arena drum." Bumper walls curve up the left, right, and across the CEILING (a closed lid). Reads as
  a contained pinball drum, deliberately the INVERSE of an open-sky archipelago.
- **Void SHAPE + placement:** ONE lethal hole in the CENTRE of the BOTTOM floor. The floor is a ring/
  annulus of bounce tiers with a **~640px-wide gap in the middle** open to a bottomless void below the
  bottom bound. The **sides and ceiling are NON-lethal bumpers** (`bumper_restitution = 0.86`) — you
  cannot ring out sideways or up. **The only exit is DOWN through the centre hole.** That single-exit
  framing IS the identity: you fight to knock rivals DOWN through the hole while not getting funnelled in.
- **Signature gimmick:** enclosure inverts the usual read — normally the edges kill; here the edges
  SAVE (they bounce you back in) and the CENTRE kills. Chaos comes from ricochets off the curved
  bumper lid raining players back down toward the hole. A super aimed down-into-a-clustered-rival is
  the money shot; a mis-aimed super into the lid rebounds you toward the hole (self-destruct comedy).
- **Tier/platform sketch:** two side floor-shelves (trampoline) at the bottom flanking the centre hole
  (left shelf x ~ -700..-40, right shelf x ~ 640..1300, hole x -40..640 -> ~680px). One or two mid-
  height spring pads (left/right) ~520px above the shelves for vertical play. Curved bumper wall
  segments up both sides and a bumper CEILING lid (needs arc/segment colliders — FEEL §2.4; flag to
  programmer if arc colliders aren't supported yet, fall back to a stepped polyline of bumper tiles).
- **Movement-tool-per-gap intent (flight-required proof):**
  - CROSS the centre hole shelf-to-shelf (~680px over void) > 527 spring drift -> **NORMAL BOOST
    REQUIRED**; miss = fall through the hole. Verb: FLY. (Rule A.)
  - CLIMB to a side spring pad (~520px above the shelf) > 480 spring apex -> **JETPACK CLIMB REQUIRED**.
    Verb: FLY. (Rule B.)
  - RECOVER after being knocked toward the hole: the drop from shelf level to the bottom bound is
    >= 650px of open sky under the hole -> a fuelled player boosts back up out of the hole mouth
    (recovery gamble). Verb: FLY. (Rule D.)
- **Measurable success criteria (level-designer verifies via gbplay eval + screenshots):**
  - **DC1 — single-exit:** over >= 12 four-bot stages, **>= 90%** of credited kills are bottom/void
    crossings through the centre hole; side + top (bumper) ring-outs **~= 0** (the walls are non-lethal
    by construction). (This is the extreme void_is_floor case — K1 edge/pit does NOT apply; use K1'.)
  - **DC2 — flight-required:** zero-boost (fuel pinned) direction-hold from a shelf does NOT reach the
    far shelf across the ~680px hole (**>= 9/10** fall through). A crossing logs >= 1 boost activation.
  - **DC3 — recovery gamble:** a healthy full-fuel bot knocked toward the hole from mid-shelf boosts
    back onto a shelf **>= 6/10** (S5 held); a near-hole dead-on down-smash sends them through **>= 7/10**.
  - **DC4 — enclosure reads:** screenshots confirm the bumper lid + walls read as a closed drum and the
    centre hole reads as the lethal void (dark, chevrons) — a naive viewer names "knock them down the
    hole" as the goal.

### §L-4 `twin_chasms` — multi-void asymmetry

- **Theme/setting:** a broken canyon land bridge — two big landmasses, a small contested centre island,
  split by TWO chasms.
- **Void SHAPE + placement:** TWO separate full-height voids (left chasm + right chasm) flanking a
  narrow centre island; the outer edges of the two landmasses are the side blast lines. Multi-void:
  a knock can send you into EITHER chasm depending on facing.
- **Signature gimmick:** the centre island is a small, powerup-bearing, exposed prize with a void on
  BOTH sides — holding it is high-risk (a hit either way = gone). Asymmetric landmass sizes make one
  side the "safe" farm and the other the "gauntlet."
- **Tier/platform sketch:** left landmass (wide trampoline, x ~ 0..1000), left chasm (~640px), centre
  island (bubblegum, x ~ 1640..2040 = ~400px wide, small), right chasm (~640px), right landmass
  (trampoline, x ~ 2680..3760). Optional single spring throne ~520px above the centre island.
- **Movement-tool-per-gap intent:** LEFT chasm (~640px) and RIGHT chasm (~640px) each > 527 spring
  drift -> NORMAL BOOST REQUIRED both ways (FLY). CLIMB to the centre throne (~520px) > 480 -> JETPACK
  CLIMB (FLY). The centre island is only reachable by boosting over a chasm (no bounce route).
- **Measurable success criteria:**
  - **TC1:** >= 12 stages: credited off-screen kills >= 90%; deaths split across BOTH chasms (neither
    chasm < 20% of void deaths) — proves multi-void, not a single de-facto pit.
  - **TC2 — flight-required:** zero-boost from either landmass fails to reach the centre island across
    its ~640px chasm >= 9/10.
  - **TC3 — centre-island tension:** a bot holding the centre island with a rival adjacent is rung out
    (either chasm) within one exchange >= 6/10 (the prize is a hot seat, not a safe perch).

### §L-5 `the_spine` — max exposure ridge

- **Theme/setting:** a single high sky-ridge / rope bridge over an abyss on all sides.
- **Void SHAPE + placement:** ONE long thin platform spine; void on BOTH long sides AND below. The
  entire play surface is within the near-edge band of a side blast — everywhere is "the edge."
- **Signature gimmick:** almost no safe interior. Every hit is a potential ring-out; the recovery
  gamble is the whole game here (fuelled fly-back along the ridge). This is the level where the
  edge-kill fantasy is at its purest — a deliberate counterweight to the enclosed drop_chamber.
- **Tier/platform sketch:** a central ridge (trampoline, ~1600px long, thin) plus 2-3 small detached
  stepping pads (bubblegum/spring) set >= 560px out over the void so reaching them is a boost commit.
  Bounds side margins are the standard derived runway (`bounds_side_frac 0.15`, min 480), so the ridge
  ends sit just inside blast range.
- **Movement-tool-per-gap intent:** reaching any detached stepping pad (>= 560px out over void) >
  527 -> NORMAL BOOST REQUIRED (FLY). A player knocked off either long side has ~650px+ of sky to fly
  back to the ridge (Rule D). Falling off the ridge END is a side/void ring-out.
- **Measurable success criteria:**
  - **SP1:** >= 12 stages: because the whole surface is near-edge, credited off-screen kills >= 90%;
    near-edge dead-on hits ring out >= 8/10 (this level should show the HIGHEST kill-per-exchange rate).
  - **SP2 — recovery still real:** a mid-ridge healthy full-fuel player knocked outward flies back
    >= 5/10 (slightly lower than the ~8/10 elsewhere is acceptable and intended — this is the exposed
    level — but it must not be 0/10; if < 4/10, widen the ridge, never touch lethality).
  - **SP3 — flight-required:** stepping-pad reach needs a boost >= 9/10 (zero-boost falls short).

### §L-6 `wrecking_yard` — moving-hazard funnel

- **Theme/setting:** an industrial toybox scrapyard — islands over a void with a swinging wrecking ball
  / sweeping bumper arm.
- **Void SHAPE + placement:** islands-over-void (like the flagship) but with a **moving SHOVE hazard**
  — a pendulum bumper or a horizontally-sweeping bar that SHOVES (never itself kills) players off
  islands into the void. The void is the killer; the hazard is the delivery mechanism.
- **Signature gimmick:** the moving hazard adds a rhythm/timing layer — cross the gap when the arm is
  clear, or use the arm's shove to fling a rival off. First moving-part level.
- **FEASIBILITY FLAG (gameplay-programmer):** moving platforms / kinematic hazards may not exist in the
  engine yet (current levels are static geometry). The hazard must (a) impart a SHOVE impulse on contact
  (reuse the soft-bump path, `soft_bump_*` in Tuning — momentum push, no hitstun, no direct kill
  credit unless it launches into a void within the ring-out credit window), and (b) be a bumper-class
  reflector, not a bounce tier. **Design owns the fun; programmer owns whether moving colliders ship
  this milestone.** If moving parts slip, ship `wrecking_yard` as a static-hazard variant (fixed
  bumper posts flanking gaps) and add motion later.
- **Tier/platform sketch:** 3-4 islands (trampoline/bubblegum) over one void with 680px gaps (as
  flagship), a pendulum bumper anchored above the central gap sweeping through the crossing lane.
- **Movement-tool-per-gap intent:** the 680px gaps require NORMAL BOOST (FLY) exactly as the flagship;
  the moving hazard makes the timing of that boost matter (cross on the clear beat). Climb to any
  elevated pad >= 500px -> JETPACK CLIMB (FLY).
- **Measurable success criteria:**
  - **WY1:** >= 12 stages: credited off-screen kills >= 88%; a measurable share (>= 15%) of void deaths
    occur within ~1.5s of a hazard contact (the hazard is demonstrably funnelling kills, not decorative).
  - **WY2 — hazard shoves, doesn't kill:** the hazard alone (no player attacker) produces ZERO direct
    kill credit; a hazard-shove that lands a victim in the void within the ring-out credit window is
    an uncredited self-fall (correct) OR credited to the last player attacker if within window.
  - **WY3 — flight-required:** the 680px gaps need a boost >= 9/10 (as flagship).

### §L-7 `the_ascent` — vertical dual-blast (bottom void + LOW ceiling)

- **Theme/setting:** a vertical tower climb — stacked tiers rising toward a low sky lid.
- **Void SHAPE + placement:** bottom void (fall = death, standard) PLUS a **deliberately LOW top bound**
  so a hard upward smash rings a player out the TOP. The identity is a DUAL vertical blast: knock down
  into the void OR up through the roof.
- **Signature gimmick:** the only level that intentionally makes TOP kills common (v2 §1d keeps top
  rare on EVERYWHERE ELSE — this is the sanctioned exception, via a per-level bounds override, NOT a
  global `bounds_top_margin` change). Verticality is the whole feel: stacked tiers, up-and-down combat.
- **BOUNDS OVERRIDE (flag to game-designer/programmer):** this level sets an EXPLICIT `bounds.top`
  lower than the derived `bounds_top_margin = 2650` would give — e.g. top bound only ~600-800px above
  the highest spring pad, so a full super or a Lv2-multiplied upward smash from a high tier exits the
  top. Every OTHER level keeps the derived top (rare top kills). This override lives in the level JSON
  `bounds` block (an explicit `bounds` is already a sanctioned per-level override, see Tuning §
  "Level-relative bounds"). Do NOT lower it so far that a routine spring bounce exits the top.
- **Tier/platform sketch:** 3-4 vertically-stacked tiers, each >= 500px above the last (spring/tramp),
  offset horizontally so climbing requires boosting up-and-over (not a straight column). Bottom void
  under the lowest tier. Low top lid.
- **Movement-tool-per-gap intent:** each tier-to-tier CLIMB (>= 500px, offset) > 480 spring apex ->
  JETPACK CLIMB REQUIRED (FLY); the offset means you also drift horizontally = a boosted arc, not a
  bounce. Falling off any tier drops through the tiers into the bottom void unless you boost to catch a
  lower tier (recovery gamble, vertical flavour).
- **Measurable success criteria:**
  - **AS1 — dual blast:** >= 12 stages: TOP blast kills **>= 20%** of credited kills (this is the ONE
    level where top is common) AND bottom/void kills present; combined off-screen >= 90%. (Metric note:
    this level uses the `dual_blast` class — K1 is reinterpreted, top is expected-high here.)
  - **AS2 — top override is intentional, not a bug:** a full super fired straight up from the top tier
    exits the top bound (rings out) >= 7/10; a routine spring bounce from the top tier does NOT exit the
    top (< 1/10) — proves the lid is tuned to punish committed launches, not normal bouncing.
  - **AS3 — flight-required:** zero-boost cannot climb tier-to-tier >= 9/10 (bounce apex < the 500px
    offset gap).

### §L-8 `the_cliff` — asymmetric spawn tension

- **Theme/setting:** a lopsided landscape — one large safe mesa on the left, a scatter of tiny
  stepping-pads over a wide void on the right leading to a small far ledge.
- **Void SHAPE + placement:** the void occupies the entire right two-thirds; the left mesa is the only
  large surface. Asymmetry: the map is not mirror-symmetric, so positions confer different risk.
- **Signature gimmick:** the mesa is a tempting near-safe farm, but idle_hunt + the far powerup/throne
  pulls players out over the void scatter where kills happen. Asymmetric spawns create natural
  aggressor/defender dynamics. Tests that the circuit isn't all symmetric layouts.
- **Tier/platform sketch:** left mesa (wide trampoline, x ~ 0..1400), then 2-3 small pads (bubblegum/
  spring, each ~360px wide) separated by 560-680px void gaps stepping right to a small far ledge
  (x ~ 3400..3760) bearing a powerup. A spring throne ~520px above one of the mid pads.
- **Movement-tool-per-gap intent:** every hop across the right scatter is a 560-680px void gap > 527 ->
  NORMAL BOOST REQUIRED (FLY); the far ledge is only reachable by chaining boosted hops. The mesa edge
  into the first gap is a side/void blast line. Climb to the throne >= 500px -> JETPACK CLIMB (FLY).
- **Measurable success criteria:**
  - **CL1:** >= 12 stages: credited off-screen kills >= 90%; a meaningful share of combat (>= 30% of
    kills) occurs on the right scatter (not all clustered on the safe mesa) — proves the asymmetry
    pulls players into the void field.
  - **CL2 — no mesa camping:** no bot survives on the mesa without moving for > `idle_hunt_after` (4s)
    without being hunted; mesa is not a stall haven.
  - **CL3 — flight-required:** the right-scatter gaps need boost >= 9/10.

### §L-9 `atoll` — radial ring around a central void well

- **Theme/setting:** a coral-atoll / crater rim — a RING of islands encircling a central void well.
- **Void SHAPE + placement:** a **central circular void** (a well/crater) with islands arranged around
  its rim; the OUTER edges of the ring are also blast lines. Radial: knocks go INWARD (into the central
  well) or OUTWARD (off the ring). This is a central_pit-class shape (the well is central) but arranged
  radially rather than as a single linear gap — a distinct feel from grassy_expanse.
- **Signature gimmick:** circular arrangement means combat wraps around the rim; the central well is a
  shared maw all rim-islands overlook. A super across the well is a dramatic diameter-spanning play.
- **Tier/platform sketch:** 4-6 rim islands (mixed tiers) arranged in a ring, each separated from its
  neighbours by ~600px void gaps and from the centre by the well. A central throne pad may hover over
  the well (boost-only, >= 500px above the rim, contested). Bounds enclose the ring; the central well
  falls to the bottom bound.
- **Movement-tool-per-gap intent:** rim-island to rim-island (~600px void gap) > 527 -> NORMAL BOOST
  (FLY); the central throne (>= 500px above rim, over the well) -> JETPACK CLIMB, and an under-shot
  climb drops into the well (FLY + SUPER earns it). No bounce route around the ring.
- **Measurable success criteria:**
  - **AT1:** >= 12 stages: credited off-screen kills >= 90%; deaths occur BOTH into the central well
    AND off the outer rim (neither < 20% of void deaths) — proves the radial in/out shape.
  - **AT2 — flight-required:** rim gaps and the throne climb need boost >= 9/10.
  - **AT3 — well reads:** the central well reads as a lethal maw (screenshots); a naive viewer names
    "knock them into the middle" as a goal.

### §L-10 `bumper_gauntlet` — interior-bumper pinball over void

- **Theme/setting:** a pinball-table toybox — islands over a void studded with glossy interior bumpers.
- **Void SHAPE + placement:** islands-over-void (flagship shape) but with several INTERIOR bumper posts
  (well away from the blast lines, per v2 §1c: no reflector within the ~560px near-edge band of any
  blast line) that ricochet players around. The void below is the killer; the bumpers add chaotic
  rebound trajectories that fling players toward it.
- **Signature gimmick:** realises the §2.3a "miss -> wall-rebound -> return-shot" fantasy at map scale.
  A super that misses a rival can carom off a bumper into an unexpected kill; the fuel refund on bumper
  contact (`fuel_per_bumper = 20`) sustains long ricochet chains. Emergent physics comedy (Pillar 3).
- **Tier/platform sketch:** 3-4 islands over 680px void gaps (flagship spacing), with 3-5 interior
  bumper posts/discs placed mid-island or flanking interior gaps (NOT within 560px of the outer side
  blast lines). Mix bumper shapes for varied carom angles.
- **Movement-tool-per-gap intent:** 680px gaps -> NORMAL BOOST REQUIRED (FLY) as flagship. Bumpers are
  reflectors (not standable, not a traversal aid that removes the boost need) — you still must boost to
  cross gaps; bumpers only reshape airborne trajectories. Any elevated pad >= 500px -> JETPACK CLIMB.
- **Measurable success criteria:**
  - **BG1:** >= 12 stages: credited off-screen kills >= 88%; a measurable share of kills (>= 15%)
    involve a bumper rebound in the victim's final trajectory (carom-into-void) — proves the pinball
    identity is live, not decorative.
  - **BG2 — bumpers don't guard the blast:** no interior bumper sits within 560px of a side blast line
    (v2 §1c rule) — verified from geometry; edge/void kills still fire normally.
  - **BG3 — flight-required:** the 680px gaps need boost >= 9/10 (bumpers don't create a bounce path
    across a gap).

### §L-11 `spires` — extreme verticality, spire-tops over a deep void

- **Theme/setting:** a field of tall stone spires / sky-pillars with tiny tops, over a very deep void.
- **Void SHAPE + placement:** a deep full-width void; the only surfaces are small spire-TOPS at varied
  HEIGHTS separated by both wide horizontal gaps AND large vertical offsets. The void dominates the
  frame — surfaces are islands in a sea of sky.
- **Signature gimmick:** the most vertical, most exposed traversal in the circuit — reaching the next
  spire is a diagonal boosted arc (up-and-over or down-and-across), never a bounce. Tiny tops mean
  landing is a skill test; overshoot = into the void. Verticality as the whole feel.
- **Tier/platform sketch:** 5-7 small spire-tops (spring/trampoline, ~280-360px wide each), placed with
  560-720px horizontal gaps AND >= 400-600px vertical offsets between neighbours, over a deep void
  (recovery sky >= 800px). Optional single high central spire (throne) >= 520px above all others.
- **Movement-tool-per-gap intent:** every spire-to-spire move combines a >= 560px horizontal gap
  (> 527 spring drift) with a vertical offset >= 400px -> the diagonal distance far exceeds any bounce
  arc -> NORMAL BOOST REQUIRED, often a well-aimed arc (FLY). The central high spire (>= 520px above)
  -> JETPACK CLIMB / SUPER (FLY). Zero-boost from any spire falls into the void (no reachable neighbour).
- **Measurable success criteria:**
  - **SPR1:** >= 12 stages: credited off-screen kills >= 92% (the most void-dominant level); uncredited
    self-falls must still stay <= 12% (tiny tops raise whiff-falls slightly; if > 15%, enlarge tops).
  - **SPR2 — flight-required (strongest):** zero-boost from ANY spire reaches NO neighbour >= 10/10
    (falls into void every time). Every spire-to-spire crossing logs >= 1 boost activation.
  - **SPR3 — recovery sky:** a healthy full-fuel player knocked off a spire boosts back to A spire
    (any) >= 5/10 (deep void keeps it a real gamble but not hopeless).

---

## 4. Circuit-wide success criteria (run on the rotation, not just per level)

Harness: `python tools/gbplay.py` eval + burst screenshots; >= 24 four-bot idle-P1 stages across the
FULL rotation (shuffle-bag). These sit ABOVE the per-level criteria.

- **C1 — identity holds everywhere:** across ALL levels, aggregate **credited off-screen kills >= 88%**
  of deaths; **uncredited self-falls <= 12%** aggregate (v2 K3 = 10% on central-pit; the void-floor
  levels run a touch higher due to whiff-falls — see the metric addendum). NO level is an outlier where
  deaths happen by something OTHER than crossing a bound.
- **C2 — flight-required everywhere:** every level passes its per-level flight-required criterion
  (>= 9/10 zero-boost fails the required crossing). A level that can be traversed without boosting is
  REJECTED and pulled from the pool (GAME_ESSENCE).
- **C3 — variety is real (felt):** a QA/CD pass names each level's DISTINCT feel in one sentence without
  prompting (enclosure / multi-void / exposed / moving / vertical-dual / asymmetric / radial / pinball /
  spires) — if two levels feel interchangeable, redesign one.
- **C4 — pacing holds on rotation:** 4-bot match to `match_target_kills = 10` resolves <= 6 min median
  across the rotation (v2 K7); no single level stalls (a level whose median stage length > 2x the
  rotation median gets re-tuned).
- **C5 — recovery gamble survives on every level** (v2 K4 / S5): each level's mid-stage healthy-knock
  fly-back criterion passes (>= 5/10 minimum; >= 8/10 on the roomy levels). This is the HARD invariant —
  a level that can't preserve it gets its geometry (recovery sky / floor width) widened, NEVER its
  lethality touched.
- **C6 — metric interpretation:** QA applies the RIGHT kill-shape target per level's declared class
  (central_pit -> v2 K1 edges>=60%/pit<=30%; void_is_floor / enclosed_hole / dual_blast -> K1' per
  `docs/specs/v2a_kill_shape_void_floor_addendum.md`). Do NOT flag a high pit/bottom share on a
  void_is_floor level as a regression — that is the fantasy working as designed.

---

## 5. Suggested build order (depth-first; validate each before widening)

1. **`drop_chamber` (the owner seed) FIRST.** It is the most novel (enclosure inverts the read) and the
   owner explicitly seeded it — proving it works de-risks the whole "variety over a through-line" thesis.
   Also the cleanest test of the metric addendum (a 100%-pit level that is CORRECT). Ship + QA (DC1-DC4)
   before touching others.
2. **`the_spine`** — the purest edge-exposure level; it is the counterweight to drop_chamber's enclosure
   and cheap to build (one ridge + a few pads). Validates the recovery gamble under max exposure (SP2).
3. **`twin_chasms`** — introduces multi-void; simple geometry, validates the "deaths split across voids"
   metric (TC1) and the reclassification for two-void shapes.
4. **`the_cliff`** + **`atoll`** — asymmetry and radial arrangement; both reuse the islands-over-void
   physics with novel LAYOUTS (low engine risk, high feel variety).
5. **`spires`** — extreme verticality; reuses static geometry, tests the strongest flight-required bar
   (SPR2) and the whiff-fall ceiling (SPR1).
6. **`bumper_gauntlet`** — interior bumpers already exist (§2.3a dry-reflect); places them at map scale.
7. **`the_ascent`** — requires the per-level top-bounds override; validate AS2 carefully (top kills
   intentional, not a bug) before adding to the pool.
8. **`wrecking_yard` LAST** — it depends on the moving-hazard feature which may not ship this milestone.
   Build the static-hazard fallback first; add motion when the programmer lands kinematic hazards.
9. **Add levels to `LEVEL_POOL` incrementally** as each passes its per-level criteria; run the C1-C6
   circuit-wide QA once ~6+ levels are in the pool, then again at the full ~11. Do NOT dump all 9 in at
   once — a broken level poisons the rotation QA (depth-first, CLAUDE.md non-negotiable).

---

## 6. Ownership split

- **Level-designer:** authors each level's JSON geometry within the §1 rulebox; re-runs the per-gap
  flight-required analysis at real coordinates; verifies the per-level measurable criteria via gbplay;
  declares each level's kill-shape class in `design_intent`.
- **Art-director:** the void-readability treatment per theme (§0.4); confirms each level reads as its
  distinct identity in motion at gameplay zoom (C3).
- **Gameplay-programmer (flagged, not blocking most levels):** (a) moving/kinematic SHOVE hazards for
  `wrecking_yard` (§L-6 — may slip; static fallback ships first); (b) arc/segment bumper colliders for
  `drop_chamber`'s curved lid (§L-3 — polyline fallback); (c) the per-level top-bounds override path is
  already supported (explicit `bounds` block) — confirm `the_ascent`'s low top loads correctly.
- **Game-designer (me):** the kill-shape metric reinterpretation per class lives in
  `docs/specs/v2a_kill_shape_void_floor_addendum.md` (companion to this spec) — QA cites it for C6.

**Fence reaffirmed:** every level is GEOMETRY + theme. NO change to any lethality constant, movement-feel
constant, the drain-all super, hitstun triad, or `max_speed`. No round timer, no HP bar, no standable
ground, no camping. The `the_ascent` top-bounds override is a per-level JSON `bounds` value (already a
sanctioned override), NOT a change to the global `bounds_top_margin`.
