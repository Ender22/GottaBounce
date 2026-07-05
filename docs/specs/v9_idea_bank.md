# v9 — CREATIVE IDEA BANK (level-designer wellspring)

> **Owner:** Level Designer. **Status:** LIVING CATALOG (authoring waves draw from this; add ideas over time).
> **v1 — 2026-07-05.**
>
> **What this is:** an opinionated pool of ORIGINAL mechanic + level ideas beyond what v6/v7 already
> catalogue, to feed the content push across all four modes (BRAWL gimmick levels / TRIALS challenges /
> SPORTS pitches). This is a menu, not a build order — the game-designer/programmer own feasibility + specs;
> the level-designer composes the cheap ones into JSON immediately and flags the new-code ones.
>
> **Required reading already run:** `docs/GAME_ESSENCE.md` (bounce→fly→smash; flight REQUIRED; death is a
> punchline; movement IS the product), `docs/VISION.md` (6 pillars), `docs/DECISIONS.md` (2026-07-05 LETHAL
> hazard doctrine: telegraphy + fairness + credit, NO invented environment scorer — INV-9), `docs/specs/v6_
> party_gimmicks_circuits.md` (the mechanics ALREADY catalogued — do NOT re-list), `docs/specs/v7_trials_
> challenge_types.md` (Trials objective types), `src/core/LevelLoader.gd` (object types), `src/core/Tuning.gd`.
>
> **NON-GOAL:** this doc does NOT re-catalogue the v6 Batch-1/Batch-2 mechanics (spinning_hammer, crusher,
> falling_debris, bomb, destructible_block, moving_platform, collapsing-arena, auto_paddle, closing_walls,
> collapsing_floor, fan/wind, rising_lava). Everything below is NEW ground or a genuinely different twist.

---

## 0. THE BAR EVERY IDEA IS JUDGED AGAINST

Ground-truth movement numbers (from `Tuning.gd`) every idea's "flight-required" and telegraphy claim is
sized against:
- **Spring apex ≈ 480px** (biggest passive bounce). Trampoline ≈ 270, bubblegum ≈ 180, marshmallow ≈ 120.
- **Normal boost:** max ≈ 760 px/s thrust — a ~0.4-0.6s boost crosses a few hundred px. Air-drift max 340 px/s.
- **Super:** impulse 2800, self-super straight-up rise ≈ 2450px, always dumps the whole tank, ≤2s aim.
- **Gravity 1600 px/s²; fuel 3.5s tank; fuel refills only on a bounce/bumper (+20).**

So: a horizontal gap > ~480px or an upper platform > ~480px above footing **demands boost**; the biggest
leaps demand super. Every idea here is designed to still obey **flight REQUIRED** (Rule #1) — none of them
should ever create a bounce-only reach or a new safe camp (Pillar 2), and every lethal one obeys the v6
doctrine (LETHAL by default + telegraphy + fairness + credit, no `environment` scorer).

**Legend.** Fun: **HIGH/MED**. Build: **LOW** (JSON compose of shipped/v6 pieces, no code) · **MED** (new
JSON object type reusing a proven path) · **HIGH** (genuinely new physics/system). "Doctrine" = lethal-hazard
ruling where relevant (shove vs kill / credit / telegraphy). Owner seeds flagged **[OWNER]**.

---

## 1. NEW SURFACE PROPERTIES

| # | Name | Hook (why it's fun/funny) | Modes | Fun | Build | Notes / doctrine |
|---|---|---|---|---|---|---|
| S1 | **Slick / Ice** **[OWNER]** | Near-zero tangential friction — you bounce and *keep sliding*; nobody can stop, every landing is a comedy skid into the void. | Brawl / Trials / Sports | HIGH | MED | Per-surface `tangential_retention→~1.0` + `bounce_di` cut override on a bounce tier. NOT a hazard (surface). Flight still required across gaps; ice governs the *bounce moment* + horizontal drift on footing. Guard Pillar 2: ice is never a camp (you can't stand still on it). |
| S2 | **Gluepad / Tar** | Opposite of ice: landing sticks you for a beat — you must *boost* to peel off, wasting fuel; a rival can punish the stuck frame. | Brawl / Trials | MED | MED | Momentary velocity kill + auto-release after ~0.4s (Pillar 2: MUST auto-release, never a hard camp/trap). Great paired with a hazard sweeping past. Surface, no kill. |
| S3 | **Charge-Trampoline** | Every consecutive bounce launches HIGHER than the last (a pumping spring) — greed vs control, over-pump and you rocket off-screen. | Brawl / Trials | HIGH | MED | A tier whose height scales with recent-bounce count, decaying if you leave. Self-limiting via `max_speed`. Fun = the escalating "uh-oh." Flight-required unaffected. |
| S4 | **Rocket Tier (mega-spring)** | A spring so strong it *overshoots* — a single touch flings you near the top blast line; you must boost to arrest before you self-ring-out. | Brawl / Trials | MED | LOW | Just a new bounce tier (~700-800px) in `Tuning` + JSON tier name. Cheapest possible new surface. Doctrine: self-overshoot = uncredited self-fall (INV-9). |
| S5 | **One-Way Membrane** | A surface you fall *through* from above but *bounce on* from below (or vice-versa) — pop up through the floor, get bounced back if you try to descend. | Brawl / Trials | MED | MED | Directional bounce (normal-sign gate). Enables layered vertical arenas where you punch up but can't drop back — funnels fights. |
| S6 | **Angled Bank Ramp** | A tilted bounce face that redirects your arc sideways — bank a bounce off a 45° wedge to slingshot across a gap or curve a super. | Brawl / Trials / Sports | HIGH | MED | Needs a rotated/polygon collider (loader is axis-aligned rects today). High skill-ceiling movement toy; also the cheapest way to make Sports bank-shots. |
| S7 | **Magnet Floor (anti-jetpack)** | A ferrous surface that *pulls you down* — your jetpack fights extra gravity over it; escaping the pull is the challenge. | Brawl / Trials | MED | MED | Localized downward force volume over a surface. Subverts flight (jetpack feels heavy) without disabling it. |
| S8 | **Treadmill Row** | A bounce surface that also conveys you sideways — land to reposition, or fight the drift; two facing treadmills = a shove-you-together pit. | Brawl / Sports | MED | MED | (v6 listed "conveyor" as a brainstorm-only idea, never built — this is the concrete twist: paired opposing treadmills that funnel bodies into a smash zone.) |

## 2. NEW HAZARDS (all LETHAL-by-default per v6 doctrine unless flagged)

| # | Name | Hook | Modes | Fun | Build | Doctrine ruling |
|---|---|---|---|---|---|---|
| H1 | **Buzzsaw Rail** | A circular saw that TRANSLATES along a visible track (not a rotor pivot) — the dodge is a moving *line* you leap over/under as it passes, then again on the return. | Brawl / Trials / Gauntlet | HIGH | LOW | Lethal `moving_hazard` on a linear path (reuses MovingHazard motion + `Hazard.kill`). Telegraph: the rail + a windup screech; clear window = when the saw is at the far end. Credit: dodge-fail = self-fall; knocked-in = credited. Cheapest new lethal hazard. |
| H2 | **Sweep Laser / Lighthouse Beam** | A rotating lethal beam sweeps the arena like a lighthouse — you sprint ahead of the sweep or duck behind cover. | Brawl / Trials | HIGH | MED | Rotor-line hazard (`moving_hazard kind:"beam"`, lethal). Telegraph: charging glow + a slow, readable rotation with a clear arc behind the beam. Reject if the beam ever covers 100% at once. |
| H3 | **Flame Vents** | Wall/floor nozzles that jet lethal fire on a drum-beat rhythm — hop the lane the instant a vent gutters out. | Brawl / Trials / Gauntlet | HIGH | LOW-MED | `Hazard` on a phase clock (on/off column). Telegraph: pilot-light flicker + a hiss before ignition; the *off* beat is the safe window. Perfectly Duck-Game. Credit: standard §2.0#4. |
| H4 | **Piston Spikes** | Spikes that thrust out of an otherwise-safe bounce surface on a rhythm — the floor itself bites; bounce on it only between thrusts. | Brawl / Trials | MED | MED | A bounce tier that periodically becomes a lethal `Hazard` (spike-out) then safe again. Telegraph: retract-rumble + the spikes rising. Turns "safe footing" into a timing gate. |
| H5 | **Lock-On Turret** | A turret that TRACKS the nearest player with a red laser-sight for ~1s, then fires one lethal shot down the line — break the sight-line or move. | Brawl / Trials / Gauntlet | HIGH | MED | Telegraph IS the lock (a growing sight-line). Fairness: the lock is slow + line-of-sight breakable + symmetric (it retargets, never favors a side). Credit: if it kills you = self-fall; a rival who shoved you into the line within 6s = credited. FLAG: must NOT invent an `environment` scorer. |
| H6 | **Void-Drain / Gravity Well** | A fixed pull-node hovering over the void that drags everyone toward the kill line — your jetpack becomes a tug-of-war against being sucked off-screen. | Brawl / Trials | HIGH | MED | Reuses the shipped `pu_black_hole` pull physics (`pull < normal_boost_accel`, so escapable by boosting) as a LEVEL object over the void. The purest "flight vs off-screen death" subversion. Doctrine: pulls but does not itself kill — the VOID kills (existing bounds). Credit: normal ring-out window. |
| H7 | **Meteor / Comet** | A big telegraphed diagonal projectile screams across the arena on a slant — read the streak, be somewhere else. | Brawl / Trials / Gauntlet | MED | LOW | Diagonal-path variant of v6 falling_debris (`moving_hazard kind:"drop"` on a slant). Telegraph: an incoming streak + warning line. |
| H8 | **Electric Fence Grid** | Segments of an electric barrier toggle on/off in a marching pattern — thread the gaps, the safe cell is always moving. | Brawl / Trials | MED | LOW-MED | Array of `Hazard` cells on staggered phase clocks. Telegraph: buzz + spark before each cell arms. Pillar 2: the safe cell moves every beat (never a static camp). |
| H9 | **Whirlpool (void suction ring)** | Above the kill line sits a swirling suction ring — get knocked low and it *reels you in* unless you boost out; makes the bottom edge feel alive and hungry. | Brawl | MED | MED | Directional-swirl force volume near the bottom bound. Escapable by boost (< boost accel). Amplifies the recovery gamble. |

## 3. NEW INTERACTIVE OBJECTS

| # | Name | Hook | Modes | Fun | Build | Doctrine / notes |
|---|---|---|---|---|---|---|
| I1 | **Jump-In Cannon** **[OWNER]** | Fly into the barrel → it auto-aims (you steer) and BLASTS you out as a human cannonball; you're a lethal projectile the whole flight — line up a rival and you smash them off-screen on arrival. | Brawl / Trials / Sports | HIGH | MED | Enter = brief loaded state (aim like the super) → fires you at a big fixed impulse (super-class). While flying = smash-eligible (reuses the stunned-flying-body smash license). THE showcase of fly+smash. Credit: a cannon-launched smash credits the launched player normally. FLAG: reuse the existing kill/smash path — add no new impulse constant beyond the cannon's launch. |
| I2 | **Portal Pair (Teleporter)** | Enter one ring, pop out the other **with your momentum preserved** — wrap across the arena, appear behind a rival mid-super, or juke a hazard by vanishing. | Brawl / Trials / Sports | HIGH | MED | Two linked Area2Ds; on entry, teleport + preserve velocity vector (+ brief re-entry lockout so you don't loop). (v6 CUT teleporter for effort — but it is the single biggest *chaos/surprise* generator; worth the MED cost.) Non-lethal. |
| I3 | **Slingshot / Charge-Pad** | A pad you land on and HOLD to draw back a rubber-band aim, release to fling yourself along your chosen vector — a player-triggered, aimable super that costs no fuel. | Brawl / Trials | HIGH | LOW-MED | Player-triggered directional launch (distinct from v6's auto-firing `auto_paddle`, which fires on a clock at whoever's on it). Skill = the aim. Non-lethal launch. |
| I4 | **Cannon → Portal combo** | A cannon whose muzzle points INTO a portal — get shot across the map and out the far side; pure traversal spectacle. | Brawl / Trials | MED | LOW (once I1+I2 exist) | Free composition of I1 + I2. No new code. |
| I5 | **Grab-Prop / Throwable** | Pick up a loose physics prop (a barrel, a bomb) and hurl it — throw a live bomb at a camper, or chuck a crate to knock a rival off. | Brawl | HIGH | HIGH | Genuine carry/throw system (grab, hold, release-with-velocity). Big comedy + weaponizes the environment. Heavy; defer unless prioritized. Thrown-bomb kill = credited to thrower via the 6s window. |
| I6 | **Trapdoor Lever** | A switch a player smacks that drops a floor section out from under EVERYONE standing on it — a griefing tool, pure schadenfreude. | Brawl | MED | MED | Hit-triggered `destructible`/collapse of a linked floor group. Telegraph: the linked floor flashes when the lever is armed. Everyone sees it coming; symmetric (anyone can hit it). |
| I7 | **Bounce Dome (force bubble)** | A round bumper you orbit and ricochet around — bank off the curve to redirect, or trap a rival pinballing inside a cluster of them. | Brawl / Sports | MED | MED | Circular bumper collider (bumpers exist; a *round* one is the new bit). Great pinball geometry + Sports ball-redirector. |
| I8 | **Catapult Seesaw** | A physics see-saw: land hard on the up-end and it FLINGS whatever's on the down-end (a rival, the ball) into the air — mutual-destruction comedy. | Brawl / Sports | HIGH | HIGH | Tilting/pivot physics body carrying riders (v6 deferred seesaw for effort). The purest "emergent physics comedy" (Pillar 3) toy, but genuinely new physics. Defer with moving_platform-class effort. |

## 4. NEW FIELD / ZONE VOLUMES (change the rules of a region)

| # | Name | Hook | Modes | Fun | Build | Notes |
|---|---|---|---|---|---|---|
| Z1 | **Low-Gravity / Moon Zone** | A volume where gravity is halved — arcs go huge and floaty, flight dominates, everything hangs in slow majestic chaos. | Brawl / Trials / Sports | HIGH | LOW-MED | Gravity-scale multiplier volume. The most on-fantasy zone (flight becomes the whole game). Cheap: a per-body gravity scale while overlapping. Flight-required *amplified*. |
| Z2 | **Heavy / High-Gravity Zone** | Opposite: gravity spikes, your jetpack barely lifts — a lethal lower region you must claw out of before the void takes you. | Brawl / Trials | MED | LOW-MED | Same volume, scale > 1. Pairs beautifully with a void below (the recovery gamble on hard mode). |
| Z3 | **Gravity-Flip Chamber** | Gravity periodically INVERTS for the whole arena — floor and ceiling both kill, and every flip re-throws everyone across the room. | Brawl / Trials | HIGH | MED | Timed global gravity sign-flip + a lethal top bound during "up" phases. Telegraph: a klaxon + a 1s warning tilt before each flip. Symmetric (everyone flips together — fair like the collapsing arena). |
| Z4 | **Rotating Wind Cross** | A wind zone whose push DIRECTION rotates around the clock — the shove that helped you last beat now blows you toward the void. | Brawl / Sports | MED | LOW-MED | Rotating variant of v6 `fan/wind` (which is fixed-direction). Non-lethal utility; readable via streamed particles showing the current heading. |
| Z5 | **Slow-Mo Bubble** | A volume where time drags — dodge a hazard in bullet-time, or watch a super crawl toward its target. | Brawl / Trials | MED | MED | Localized time-scale (`pu_slow_mo` constants already exist as a deferred powerup — reuse as a zone). Spectacle + readability aid; guard against feeling like a stall. |

---

## 5. TRIAGE SUMMARY — cheap-compose NOW vs needs-code

**Author-immediately (LOW / pure JSON compose of shipped or Batch-1 pieces — no new code):**
- **S4 Rocket Tier** (one Tuning tier + tier name), **H1 Buzzsaw Rail** & **H7 Meteor** (lethal `moving_hazard`
  motion variants), **H3 Flame Vents** / **H8 Electric Fence** (`Hazard` on a phase clock), **I4 Cannon→Portal**
  (once I1+I2 land). These are the fastest wins — they reuse the proven `Hazard`/`MovingHazard`/tier paths.

**Small new object type reusing a proven path (MED — spec it, then author):**
- **S1 Ice / S2 Gluepad / S3 Charge-Tramp** (per-surface friction/height override), **S5 One-Way Membrane**,
  **S7 Magnet Floor**, **S8 Treadmill**, **H2 Sweep Laser**, **H4 Piston Spikes**, **H5 Lock-On Turret**,
  **H6 Void-Drain** (reuses shipped black-hole physics), **H9 Whirlpool**, **I1 Jump-In Cannon**, **I2 Portal**,
  **I3 Slingshot**, **I6 Trapdoor**, **I7 Bounce Dome**, **Z1-Z5 zones** (force/gravity/time-scale volumes).

**Genuinely new physics (HIGH — defer behind moving_platform-class effort):**
- **S6 Angled Bank Ramp** (rotated colliders), **I5 Grab/Throw** (carry system), **I8 Catapult Seesaw**
  (rider-carrying pivot body).

**Doctrine flags to watch (auto-reject risks per §2.0):** H5 Lock-On Turret must NOT become an invented
`environment` scorer (a turret-kill with no attacker = uncredited self-fall). I1 Cannon and I3 Slingshot must
reuse the existing launch/smash pipeline and add NO new death/hitstun impulse. Every lethal idea needs a
telegraph + a returning safe beat + symmetry, or it is rejected.

---

## 6. TOP 8 STANDOUTS (build these next, beyond v6 Batch 1)

Ranked by delight × fantasy-fit × buildability. Ice and Jump-In-Cannon evaluated honestly, not auto-included.

1. **I1 Jump-In Cannon [OWNER] — MED.** *Why:* it is the single best expression of the core fantasy in one
   object — you literally BECOME the super-smash. Fly in, aim, blast out as a lethal projectile into a rival.
   Reuses the smash license + kill path (no fenced constant). Feeds all three modes (brawl kills, trials
   relays, cannon-soccer). Highest fun-per-risk on the board.
2. **I2 Portal Pair — MED.** *Why:* the biggest *surprise/chaos* generator we don't have — appear behind a
   rival mid-super, juke a hazard by vanishing, wrap the arena. v6 cut it on effort, but the payoff (emergent
   comedy, Pillar 3) is enormous and it composes with everything (I4 cannon→portal is then free).
3. **Z1 Low-Gravity Moon Zone — LOW-MED.** *Why:* the most on-fantasy zone possible — it makes flight the
   entire game (huge floaty arcs, hang-time smashes). Cheapest zone to build (a gravity-scale volume) and it
   directly amplifies Rule #1. A whole "Moonshot" arena falls out of it (§7).
4. **Z3 Gravity-Flip Chamber — MED.** *Why:* a genuinely novel headline mechanic — periodic inversion with
   BOTH bounds lethal re-throws the whole match and creates a shared, fair, telegraphed panic (like the
   collapsing arena, everyone flips together). Nothing else in the roster feels like it.
5. **S1 Ice / Slick [OWNER] — MED.** *Why (honest):* real chaos/comedy value — nobody can stop, every landing
   is a skid toward the void, and it sharpens the recovery gamble. Caveat: it governs the *bounce/landing*
   moment, not traversal, so an ice arena must still gate reach with real gaps (flight stays required); it is
   a flavor multiplier, not a traversal mechanic. Cheap-ish per-surface override. Worth building.
6. **H6 Void-Drain / Gravity Well — MED.** *Why:* the purest subversion of the fantasy — a fixed pull dragging
   you toward off-screen death, turning your jetpack into a tug-of-war with the void. Reuses shipped
   black-hole physics (escapable by boost). Makes the edge feel *hungry*.
7. **I3 Slingshot / Charge-Pad — LOW-MED.** *Why:* a player-*aimed*, fuel-free launch — pure movement skill
   expression (distinct from v6's clock-fired auto_paddle). Low floor (land and fling), high ceiling (aim the
   perfect cross-map arc into a smash). Great Trials-course spine.
8. **H1 Buzzsaw Rail — LOW.** *Why:* the cheapest genuinely-new lethal hazard (a *translating* line vs the
   hammer's *rotating* one), giving a fresh dodge axis for almost no code. A reliable, readable staple for
   Trials survive-courses and Gauntlet late waves.

*Near-misses:* H5 Lock-On Turret (great, but doctrine-sensitive), S3 Charge-Trampoline (fun escalator),
I8 Catapult Seesaw (best comedy toy but HIGH effort — build after moving_platform).

---

## 7. COMPLETE LEVEL / COURSE / PITCH CONCEPTS

Each is a ~10s set-piece an author can build, with the flight-required note (Rule #1) and mode.

### 7.1 `slip_n_smash` — ALL-ICE BRAWL ARENA (S1)
Islands-over-void where **every surface is Slick (S1)**. Nobody stops moving; a smash sends the victim
skidding off the far lip. Gaps between islands are ~560px+ (boost-required to cross — ice doesn't help you
fly). **Hook:** total loss of footing control — the funniest recovery scrambles in the game. **Flight check:**
inter-island gaps > spring apex (480) → boost required; the biggest island-to-island leap > boost reach →
super. Ice only affects the landing skid, never the reach. **Kill shape:** `void_is_floor`.

### 7.2 `the_big_top` — CANNON-DUEL BRAWL ARENA (I1)
A ring of **Jump-In Cannons (I1)** around a central void, small landing pads between them. You blast from
cannon to cannon as a human cannonball; mid-flight collisions are smashes. **Hook:** the arena is a circus
act — everyone is a projectile, kills happen in mid-air crossfire. **Flight check:** pads are spaced so you
CANNOT bounce between them — the cannon (or a boosted arc) is the only traversal, and the cannon flight is
itself the smash. **Kill shape:** `void_is_floor`. *(Also the seed for the `cannon_soccer` pitch, §7.6.)*

### 7.3 `topsy` — GRAVITY-FLIP BRAWL CHAMBER (Z3)
An enclosed drum with bounce surfaces on floor AND ceiling; **gravity inverts every ~4-5s (Z3)** with a 1s
klaxon warning. During "up" phases the top bound is lethal. **Hook:** every flip re-throws all 4-8 players
across the room — a rhythmic, shared panic; you fight to be aimed at a surface, not the kill line, when it
flips. **Flight check:** the flip constantly re-separates players across a tall drum → boost required to
re-close distance each phase. **Kill shape:** `dual_blast` (both vertical bounds live, phase-dependent).

### 7.4 `moonshot` — LOW-GRAVITY BRAWL ARENA (Z1)
A wide arena blanketed by a **Low-Gravity zone (Z1)** — half gravity everywhere. Arcs are enormous, supers
hang forever, recoveries are balletic. **Hook:** slow-motion majestic chaos; a smashed body sails a long,
readable, hilarious arc off-screen. **Flight check:** platform spacing tuned for the FLOATY arc — gaps are
wide (~800px+) because everyone travels further, so boost/super are still the only way across (a passive
low-g bounce peaks higher but still can't clear the authored gaps). **Kill shape:** `void_is_floor`.

### 7.5 `wormhole_ward` — PORTAL BRAWL ARENA (I2)
A compact arena where the four edges are **Portal Pairs (I2)** — fly off the left, appear on the right with
momentum; a diagonal pair wraps top-to-bottom. **Hook:** no true edges — the map is a torus of ambushes; a
missed super wraps back around and might hit YOU. **Flight check:** the interior gaps are boost-required;
portals add wrap-chaos on top, they don't remove the flight demand. **Kill shape:** a small central
`void_is_floor` well (the ONLY exit is down the middle — portals wrap the sides, so kills funnel inward).

### 7.6 `cannon_soccer` — SPORTS PITCH (I1 + I7)
2-team bounce-ball on a pitch where the ball can only be moved far by **firing it (or yourself) from a
Jump-In Cannon (I1)**, with **Bounce Domes (I7)** as symmetric mid-field redirectors. **Hook:** Rocket-League
energy — you cannon yourself into the ball for a screamer, or bank it off a dome into the net. **Fairness
(Sports doctrine):** cannons + domes are perfectly symmetric and away from the goal mouths; no lethal
hazards. **Flight check:** the pitch is wide enough that reaching the ball requires flight, per the shipped
sports-court geometry rule.

### 7.7 `cannonball_run` — TRIALS RELAY COURSE (I1 + I3, PRECISION/REACH_GOAL)
A `REACH_GOAL` gauntlet chaining **Jump-In Cannons (I1)** and **Slingshot pads (I3)** across a void: land the
cannon exit precisely enough to hit the next pad, chain launches to the goal. **Hook:** a flow-state launch
relay — one clean aimed chain beats gold; a fumbled exit costs a fall. **Flight check:** the launches ARE the
traversal (no bounce-only route exists between pads). Medal = time.

### 7.8 `the_lighthouse_vigil` — TRIALS SURVIVE COURSE (H2)
A single small pad ringed by the void, with a **Sweep Laser / lighthouse beam (H2)** rotating overhead;
`SURVIVE` 20s by boost-hopping to stay in the beam's trailing shadow. **Hook:** a hypnotic, readable rhythm —
one greedy beat and the sweep catches you. **Flight check / Pillar 2:** the safe shadow is always MOVING, so
you must fly each beat — no idle tile (S-CAMP gate from v7). **Doctrine:** beam-kill with no attacker =
uncredited self-fall; clear arc behind the beam every rotation (never 100% coverage).

---

## 8. HOW TO USE THIS DOC
- **Level authors:** the LOW/compose ideas (§5) can be built into JSON the moment their reused path exists —
  start there for immediate content. The MED/HIGH ideas need a game-designer spec + programmer buy-in first
  (route through change-control if they touch physics).
- **Game designer:** promote a §6 standout into a proper mechanic spec (v6-style: doctrine + measurable
  gates) when a wave is ready for it. The §7 concepts are ready-to-author once their mechanics land.
- **Keep it living:** add new ideas below the existing tables; when an idea graduates to a spec, note its
  spec path beside it. Do not delete rejected ideas — record WHY (the cut list is design memory).
