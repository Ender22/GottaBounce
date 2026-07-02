# Spec: v1 Movement Courses — the feel instrument

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD (courses 1–3; course 4 after props
> pass; course 5 deferred). **Last updated:** 2026-07-02.
> **Build priority: immediately after `v0_combat_lethality.md` v2 ships its QA pass** — before new
> arenas, before the art fix list, before audio. Rationale below. Source of the method:
> `docs/feedback/owner_2026-07-02_movement_feel.md` (owner thesis: movement feel IS the product;
> bar: TowerFall Ascension). Also: `docs/VISION.md`, `docs/reference/FEEL_REFERENCE.md`,
> `src/core/Tuning.gd`, `docs/specs/v0_combat_lethality.md` v2 (the un-charged super these courses
> exercise).

## The player fantasy

**"I just did something HARD and it felt amazing."** No enemies, no score — just you, the jetpack,
and a course that looks impossible until the movement clicks. Threading five tiny platforms on
fumes. Ping-ponging supers up a chimney too tall to fly. Riding banked bounce-momentum across half
a screen of nothing. When a course run feels great, the movement is right; when it feels like
fighting the controls, a Tuning constant is wrong — and now we know *which one*.

## Why this is the next build (the method)

The owner's thesis: the game lives or dies on movement feel, and the way to tune feel is to build
courses where **the accomplishment itself is the reward**, then tune movement around what makes
the courses feel great. This gives the studio three things at once:

1. **A tuning instrument.** Every feel constant in `Tuning.gd` gets a course that isolates it.
   Change a constant → rerun the course → the difference is *felt and measured*, not guessed.
   (FEEL_REFERENCE rule: tune ONE variable at a time — courses make that discipline physical.)
2. **A QA harness for combat changes.** The Chimney (course 2) is the acceptance test for the
   un-charged super (lethality spec §9.2 explicitly calls it). Any future movement change reruns
   the course battery as a regression suite.
3. **Permanent content.** These are not throwaway: they become the Campaign challenge gauntlets
   (VISION scope) and the onboarding path (GDD §7 circuits "teach one mechanic at a time"). Build
   once, use three times.

**Teaching progression (owner's own caveat, honored):** courses introduce ONE mechanic each and
are ordered so every course only requires mechanics taught by earlier ones: (1) normal boost +
fuel economy → (2) the super, chained → (3) bounce momentum + supercharge (uses boost from 1) →
(4) super as a precision weapon → (5) sustained ball control, multiplayer. A player — or a QA
script — that can't clear course N has no business being graded on course N+1.

## Pillar check

No standable ground anywhere (all platforms are bounce tiers — INV-11 min-bounce still applies on
the tiny pads). No camping (courses are timed; the only rest state is death/reset). Readability:
course goals are a single high-contrast ring/gate, one per course. Death is cheap: falling out
resets to the start gate in <1.5s, attempt counter ticks, no other penalty.

---

## 1. Course infrastructure (one small mode, no new systems)

- **`CourseMode`** scene: loads a course JSON (standard level format + the two objects below),
  spawns **one player** (P1, human or eval-driven), shows a minimal HUD: **run timer** (visible —
  unlike Party, time IS the score here), fuel gauge, attempt counter, par time.
- **New level objects** (JSON `objects[]`, per GDD §15 conventions):
  - `{ "type": "start_gate", "x", "y" }` — spawn + reset point; timer starts on first input.
  - `{ "type": "goal_ring", "x", "y", "radius": 90 }` — touch = course clear; freeze + time
    banner (reuse Party banner system) + `R`/button to retry.
- **Reset rule:** crossing `bounds` = instant reset to start_gate (no death animation longer than
  ~0.5s — Pillar 4, and iteration speed is the point). Fuel refilled on reset.
- **Camera:** courses 1 and 3 exceed one screen — they use the **already-decided Campaign
  follow/scroll camera mode** (FEEL_REFERENCE §7: "the camera must support both"). No new camera
  behavior is being designed here; courses 2/4/5 fit a locked frame.
- **QA hooks (eval):** `course_stats = {time_s, attempts, fuel_min_seen, bounces, supers_fired[],
  reached_checkpoints[]}`. Checkpoints are invisible markers (platform indices / height lines)
  purely for telemetry — no gameplay effect.
- **Levels live in** `levels/courses/course_XX_name.json`. All numbers below are initial-authoring
  values; **the course-build loop is allowed to move geometry** (that's tuning) but must re-verify
  the pass/fail script pair afterward.

---

## 2. The courses

### Course 1 — "Tank Run" (fuel-management long-haul) — teaches: normal boost + the fuel economy

Owner sketch #1. A horizontally-stretched run (~7000px wide) of **six tiny trampoline-tier
platforms (128px wide each)**, A→B by jetpack, barely enough fuel per leg.

- **Layout:** platform gaps ramp **700 / 800 / 900 / 1000 px**, final gap **1600px** (super
  required — the "final leg requires a super boost" beat from the owner sketch; final platform
  sits 250px lower so the super's gravity arc lands it). Start with full tank (100).
- **The math it's tuned around:** flat-out boosting covers ~20–26 px per fuel unit
  (`normal_boost_max_speed` 760, drain 28.6/s), so a 900px gap costs ~40 fuel while a platform
  touch refunds 20 (`fuel_per_bounce`) — you MUST double-bounce on pads (bank +40) and fly clean
  arcs, and boost-timed launches (`supercharge_*`) cut each leg's cost ~25%. Greedy flying runs
  dry around platform 4 by design.
- **What it measures:** does the bank-vs-spend economy feel *tense and fair* (the one genuinely
  novel, unsolved feel problem — FEEL_REFERENCE §0)? Is pulsed boosting more satisfying than
  hosing?
- **Constants exercised:** `tank_seconds`, `fuel_per_bounce`, `normal_boost_accel/max_speed`,
  `boost_enter_keep`, `supercharge_window/thrust_mult`, `air_drift_*`, `bounce_di`.
- **Pass/fail (QA-scriptable):**
  - F1: "greedy" script (continuous boost aimed at next platform) fails before platform 5 —
    if it clears, the economy has no teeth: raise gap sizes, don't nerf the tank first.
  - P1: "managed" script (double-bounce each pad, arc hops, supercharge launches, super on the
    final gap) clears with `fuel_min_seen > 0`.
  - P2: human-feel check — QA (driving via gbplay) clears in ≤10 attempts; par time **60s**;
    every failed run's telemetry shows fuel exhaustion (their fault), not an unreachable gap.

### Course 2 — "The Chimney" (super wall-climb) — teaches: the un-charged super, chained

Owner sketch #2 and **the acceptance test of the lethality-spec super redesign**. Two vertical
walls of trampoline-tier tiles, **4000px tall**, interior gap **420px**, goal ring at the top.
Far too tall to fly: a full tank of sustained up-boost tops out ≈ 3100px (760 px/s × 3.5s + bounce
apex + coast).

- **The intended technique:** super up-diagonally (~60°) into wall A → wall bounce redirects you
  (+20 fuel ≥ `super_boost_min_fuel` 5 → re-armed) → snap-aim (the aim-freeze damps your climb at
  `super_aim_damp` 2.5/s, so hesitation literally costs altitude — aim FAST is the skill) → super
  into wall B → repeat. Left-right-left-right to the top.
- **What it measures:** the entire new super loop — is chaining rhythmic and empowering? Is the
  2s aim cap generous or claustrophobic? Does drain-all + bounce-refund feel like a combo system
  or a chore?
- **Constants exercised:** `super_boost_impulse_full`, `super_boost_min_fuel`, `super_aim_max/
  damp/gravity/velocity_keep`, `super_refire_lockout`, `fuel_per_bounce`, `tangential_retention`
  (vertical speed kept through wall bounces), `max_speed`.
- **Pass/fail:**
  - F1: normal-boost-only script from the base tops out at **≤65% of course height** (verifies
    "too tall to fly" stays true if boost constants change).
  - P1: alternating-super script reaches the goal in **≤6 supers and ≤15s**, every super firing
    at full launch speed (±5%) regardless of fuel at fire (cross-check lethality §9.1–9.2).
  - P2: human-feel check — QA clears in ≤10 attempts; a *deliberate* 2s hang in aim mid-climb
    causes visible altitude loss and auto-fire (the anti-hover rule is felt, not just coded).

### Course 3 — "Bank Shot" (momentum banking) — teaches: bounce momentum + supercharge chains

Owner sketch #4. A **launch pit** (spring-tier floor, bumper side walls) at one end; a **goal ring
2800px away horizontally**, 200px above the pit lip, with NOTHING in between (one 128px emergency
pad at the 1400px midpoint, 400px below the line — touching it is telemetry-flagged as the
"assist" route).

- **The intended technique:** cold-start flight falls ~500px short by design. You must build:
  boost-timed spring bounces (`supercharge_bounce_mult` 1.4 × spring launch ≈ 1736 px/s) + DI +
  bumper ricochets to bank tangential speed **≥1400 px/s**, then exit the pit and convert the
  banked momentum + a full tank into distance.
- **What it measures:** does building momentum feel like Tony-Hawk flow (FEEL_REFERENCE §3.4
  "chain flow")? Is `tangential_retention` 0.98 enough to make banking readable across 3+
  bounces? Does `max_speed` 3000 clamp ever flatten the fun?
- **Constants exercised:** `tangential_retention`, `supercharge_window/bounce_mult/thrust_mult`,
  `bounce_di`, `bounce_height_spring`, `bumper_restitution`, `max_speed`.
- **Pass/fail:**
  - F1: cold-start script (lip, full tank, straight boost) lands **≥400px short** of the ring.
  - P1: chain script (3+ supercharged spring bounces, exit speed ≥1400 px/s, then boost) reaches
    the ring; exit speed logged.
  - P2: human-feel check — the moment of release (leaving the pit with banked speed) is graded
    as the run's high point in QA's feel notes; ≤12 attempts to clear; par **45s**.

### Course 4 — "Hole in One" (precision smash) — teaches: the super as a surgical weapon
*(build after courses 1–3; needs the ball prop + hoop trigger)*

Owner sketch #3, and the seed of the sports modes. A **soccer ball prop suspended mid-air**
(storm-ball physics body at rest, respawns 2s after leaving play) 600px from a spring platform; a
**hoop** (two post sprites + a 140px trigger gap) **900px beyond it, 30° above** the ball line.
Super-smash the ball through the hoop.

- **What it measures:** prop-smash feel (impulse transfer, does the ball GO where the hit says),
  aim precision under the 2s window, readability of hit angles.
- **Constants exercised:** `smash_impulse_base/from_attacker` (props), `smash_impact_min` (prop
  gate), ball mass/restitution, `super_active_time` (window must comfortably cover a 600px
  approach: 600px at 2800 ≈ 0.21s < 0.45 ✓).
- **Pass/fail:** P1: scripted super at the correct angle sends the ball through the hoop ≥7/10
  (ball speed after smash ≥2000 px/s); F1: a normal-boost ram moves the ball but cannot score
  from the spawn distance (shove-tier push only). P2: human clears 3 hoop positions (flat, 30°,
  lob over a post) in ≤15 attempts total.

### Course 5 — "Over the Net" (volleyball relay) — teaches: sustained ball control, together
*(DEFERRED — design sketch only; needs multi-agent play + the course-4 ball)*

Owner sketch #5: a ball + 2–4 players spread far apart, bumping it up and over a net wall,
N successful crossings to clear. This is deliberately last: it depends on course-4 ball feel and
is really the **prototype for the sports mode seeds** (`docs/DECISIONS.md` 2026-07-02) — when we
build it, we're building the volleyball mode's core loop and should spec it as such. Do not build
before courses 1–4 prove the ball and the movement.

---

## 3. Constant → course coverage map (the instrument's dial)

| Tuning area | Isolating course |
|---|---|
| Fuel economy (`tank_seconds`, `fuel_per_bounce`) | 1 |
| Normal boost (`normal_boost_*`, `boost_enter_keep`) | 1 |
| Supercharge tech (`supercharge_*`) | 1 (cost saving), 3 (launch building) |
| Un-charged super (`super_*` — all of it) | 2 (chaining), 4 (precision) |
| Momentum (`tangential_retention`, `max_speed`, `bumper_restitution`) | 3 |
| Bounce tiers & DI (`bounce_height_*`, `bounce_di`) | 1, 3 |
| Prop smash (`smash_*` on props) | 4 |

Tuning workflow (binding, per FEEL_REFERENCE §0): change ONE constant via gbplay eval → rerun the
affected course's script pair + one human-driven run → record the verdict back into
FEEL_REFERENCE. A constant change that breaks another course's F-script is a regression, not a
tune.

## 4. Success criteria for THIS spec (QA-verifiable)

1. Courses 1–3 load, run, reset, and clear via their P-scripts; all three F-scripts fail as
   specified (the fail cases are load-bearing — they prove the course tests something).
2. `course_stats` exposed via eval with all fields live; reset-to-start ≤1.5s from bounds-cross.
3. Timer/par/attempts HUD present, built as .tscn + Theme (no debug widgets); goal ring readable
   in a screenshot from full-course zoom.
4. A full battery run (3 courses × P+F scripts) completes headless-driven in ≤10 min wall clock —
   cheap enough to run after every movement-touching commit.
5. Feel verdicts filed: QA plays each course 5+ human-driven runs and answers, in writing, the
   course's "what it measures" question + the TowerFall bar question ("did I feel capable and
   cool, and were failures my fault?"). These verdicts, not the scripts, are what the designer
   tunes against.

## Out of scope

Course-select UI/menu (boot flag or eval-load is fine for now), medals/unlock economy (belongs to
the progression spec later), courses 4–5 build (spec'd above, gated), leaderboards, any new
camera behavior, ghost replays (want later — note for backlog).
