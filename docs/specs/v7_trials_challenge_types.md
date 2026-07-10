# Spec: v7 — TRIALS OBJECTIVE-TYPE SYSTEM (varied challenge types)

> **⚠ PARTIALLY SUPERSEDED (2026-07-06) by `docs/specs/v10_trials_completion_model.md`.** v7's
> **objective-type framework** (the `objective` block, the six types, the absent-block ⇒ REACH_GOAL
> hinge, the "all variety in the mode, zero new runner hooks" architecture, the example course battery)
> **STANDS and is the doc-of-record for those.** But v7's **TIME / MEDAL / PAR layer is DEAD** — the
> owner redirected TRIALS to a Pico-Park-style **binary, no-clock, multi-player-parallel** completion
> model. Wherever v7 below describes medals, par times, `medal_*` fields, time/attempt/fall scoring, or a
> single-player-only assumption, **v10 wins.** Read v10 first for the completion model, then v7 for the
> objective-type mechanics it preserves.

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD (staged; some types block on v6 mechanics).
> **v1 — 2026-07-05.**
>
> **Goal (owner directive):** TRIALS is one archetype today — all 5 courses are "fly A→B, touch the
> goal_gate, beat par time" (traversal time-attack). Add VARIETY that uses the v6 gimmick hazards.
> Make each course DECLARE its own win condition + how it is scored/medaled.
>
> **Required reading already run:** `src/modes/TrialsMode.gd`, `src/modes/GameMode.gd` (the seam +
> additive-hook pattern), `levels/course_sets.json` + `levels/courses/*.json`, `docs/specs/v3_content_plan.md`
> PART B, `docs/specs/v6_party_gimmicks_circuits.md` (the gimmick MECHANIC catalog), `docs/DECISIONS.md`
> 2026-07-05 (**hazards are LETHAL by default** with telegraphy + fairness + credit), `src/entities/GoalGate.gd`,
> `src/entities/GoalZone.gd`, `src/entities/Ball.gd`, `src/core/LevelLoader.gd`.
>
> **This doc is DESIGN + schema + measurable targets + build order.** The programmer owns feasibility; the
> level-designer authors JSON inside these constraints. I do not write GDScript.

---

## 0. THESIS + THE PILLAR CHECK

TRIALS is the game's thinnest mode (CD verdict #7). It is also the mode where lethal hazards fit *best*:
there is no combat and a death is a cheap `respawn (+2s)`, so a course can be **pure dodge-timing / precision
/ physics-puzzle** with no fairness cost from the versus loop. Every objective type below either (a) makes
you FLY and TIME through a lethal rhythm, (b) makes you FLY precisely, or (c) makes you USE the physics —
all of which are the movement product, not a new game.

**Pillar guards (inviolable) that constrain every type:**
- **Pillar 2 (constant motion, no camping):** no objective may be won by sitting on a safe surface waiting.
  SURVIVE parks you under a lethal hazard (you MUST move each beat); DESTROY_ALL and the collapsing variants
  erode your footing; PHYSICS_PUZZLE has no safe idle. A SURVIVE course must never contain a hazard-free
  tile you can idle on for the full timer — QA gate S-CAMP below.
- **Pillar 5 (readability over prettiness):** every lethal beat is telegraphed (reuse the v6 telegraphy
  toolkit). A course whose win/lose state a naive viewer can't name in one sentence is rejected.
- **Flight-required (GAME_ESSENCE Rule A):** every course still requires the jetpack to traverse/win — the
  new types add a *reason to fly well*, they never let you win by bouncing passively.

**The critical architecture rule:** this is **NOT a runner rewrite**. The runner (`PartyMatch`) already
polls `is_stage_over()` every combat frame because `TrialsMode.polls_goal()` returns `true`. All variety
lives inside the MODE by branching its existing seam methods on the course's declared `objective.type`. The
only seam TrialsMode *newly* overrides is `on_stage_ready()` (which already exists — SPORTS uses it — to
spawn a stage prop), used to spawn the Ball for PHYSICS_PUZZLE. **Zero new runner hooks.**

---

## 1. THE OBJECTIVE-TYPE FRAMEWORK

### 1.1 How a course declares its objective

A new optional top-level course-JSON block, `objective`:

```json
"objective": {
  "type": "SURVIVE",
  "survive_seconds": 20.0,
  "medal_survive": { "gold": 0, "silver": 1, "bronze": 3 }
}
```

- `objective.type` ∈ `REACH_GOAL | SURVIVE | DESTROY_ALL | PHYSICS_PUZZLE | COLLECT_ALL | PRECISION_LAND`.
- **Absent `objective` block ⇒ `REACH_GOAL`.** The 5 shipped courses have no `objective` field, so they
  resolve to REACH_GOAL and behave **byte-identically** (see §5 regression gate). This is the back-compat
  hinge — no shipped course changes.
- Per-type params + the per-type medal map live INSIDE the block (§2 lists them). The existing top-level
  `medal_times` stays where used (TIME-scored types read it exactly as today).

### 1.2 How TrialsMode branches (all inside existing seam methods — no runner change)

`TrialsMode` gains one cached field, `_cur_objective: Dictionary`, read in `next_level_path()` right beside
the existing `_cur_medal_times` read. Everything else is a `match _cur_objective_type()` branch inside the
methods TrialsMode ALREADY overrides:

| Seam method (already exists) | Branch added |
|---|---|
| `next_level_path(runner)` | additionally caches `_cur_objective`; resets per-type live state (`_survive_base`, `_attempts`, `_blocks_total`, etc.). |
| `is_stage_over(runner)` | dispatch on type — see the per-type "clear test" column in §2. Each test reads LIVE scene state via a group (identical pattern to today's `goal_gate` scan). |
| `on_kill(runner,...)` | REACH_GOAL/DESTROY_ALL/COLLECT/PRECISION: `+FALL_PENALTY`, `attempts += 1` (today's behavior). SURVIVE: reset the survival clock (`_survive_base = round_clock`) + `_resets += 1`. PHYSICS_PUZZLE: a player fall is just a respawn (no scoring effect; the ball, not the player, is the scorer). |
| `stage_end_banner(runner)` | compute the per-type result + medal via `medal_for_result()` (§2). |
| `on_stage_ready(runner)` | **newly overridden:** if type == PHYSICS_PUZZLE, spawn the Ball at the `ball` object's spawn point (reuse the SPORTS ball-spawn helper). Every other type: no-op (parity). |
| `current_time / medal_for` | generalized to `medal_for_result()` — TIME types compare seconds vs `medal_times` (≤, today's logic verbatim); SURVIVE compares resets vs `medal_survive` (≤); PHYSICS_PUZZLE compares attempts vs `medal_attempts` (≤). |

**Why the per-frame bookkeeping is free:** `is_stage_over()` is already called every combat frame (because
`polls_goal()` is true), so SURVIVE's clock check, DESTROY_ALL's group-count, and PHYSICS_PUZZLE's
scored-latch all live there — no new per-frame hook. `match_winner()` is UNCHANGED: it keys off
`_course_idx` + `is_stage_over()`, which returns true on ANY type's clear.

### 1.3 New level-JSON object types this system introduces

Most objects are REUSED from v6 / SPORTS. Genuinely new to author for TRIALS:

- `pickup` (COLLECT_ALL) — a small display Area2D that latches `collected` on player overlap and joins group
  `"trials_pickup"`. **Clone of `GoalGate`'s latch pattern** (senses players, latches once, drawn as a
  glossy token). Lowest-effort new entity.
- `land_target` (PRECISION_LAND) — a tiny pad Area2D that latches `landed` only if the overlapping player's
  speed is below `land_speed_max` (a "soft landing" check). Joins group `"trials_target"`. Same latch clone
  + one velocity gate.

REUSED as-is: `goal_gate`, `start_gate`, `void`, `platform` tiers (all TRIALS today); `moving_hazard`
kind:`pendulum`/`rotor`, `destructible`, `bomb`, `debris_spawner` (all v6); `ball` + `goal_zone` (SPORTS —
`goal_zone`'s `team` field is ignored in TRIALS; any latched `scored` = win).

---

## 2. THE OBJECTIVE TYPES + PER-TYPE MEDAL CRITERIA

### 2.1 REACH_GOAL (current — KEPT UNCHANGED)
- **Fantasy:** master the traversal line, shave the clock.
- **Clear test (is_stage_over):** any node in group `"goal_gate"` has `reached == true`. (verbatim today.)
- **Measured:** run time = `round_clock + run_penalty` (falls add `FALL_PENALTY = 2.0s`).
- **Medal:** top-level `medal_times {gold,silver,bronze}` (seconds, ≤). **No change** — the 5 shipped
  courses keep their exact thresholds.
- **Mechanic dependency:** none. Build in Wave 1.

### 2.2 SURVIVE (last N seconds vs a lethal hazard)
- **Fantasy (owner):** *"survive 20s while the hammer spins — perfect-timing jumps."* You are parked in a
  small kill-box with a lethal, telegraphed hazard; every beat you must boost/hop through the clear window.
- **Params:** `objective.survive_seconds` (float, the win target); `objective.medal_survive {gold,silver,
  bronze}` (int = MAX resets/deaths allowed for that medal).
- **Clear test:** `(round_clock - _survive_base) >= survive_seconds`. `_survive_base` starts at 0 and is
  reset to the current `round_clock` on every death (see on_kill) — so a death **resets survival progress to
  0** (retry) rather than penalizing time. Win = the timer reaches the target with no death since the last
  reset.
- **Lose = die → retry:** a hazard-kill or a void fall respawns the player at `start_gate`, resets the
  survival clock, and increments `_resets`. (No `+2s` penalty here — the reset IS the cost.)
- **Measured:** number of resets (deaths) before the successful survival. `clean` = 0 resets.
- **Medal (fewer deaths = better):** `gold` = clean (0 deaths, e.g. `{gold:0}`); `silver` = ≤1; `bronze` =
  cleared at all (e.g. `{bronze:3}`, or set high/unbounded for "any clear = bronze"). This directly encodes
  the owner's "clean = no-hit clears."
- **Mechanic dependency:** **v6 spinning_hammer (rotor)** — Batch-1 #1 — and/or **v6 falling_debris**. Blocks
  on those lethal hazards landing.

### 2.3 DESTROY_ALL (breakout)
- **Fantasy (owner):** *"breakout: smash all blocks on your platform without falling."* Pinball yourself off
  every destructible block, managing fuel + not over-launching into the void.
- **Params:** `objective.score_by` ∈ `"time" | "falls"` (default `"time"`). If `"time"`: reuse top-level
  `medal_times`. If `"falls"`: `objective.medal_falls {gold,silver,bronze}` (int = MAX falls).
- **Clear test:** group `"destructible"` contains **zero un-broken members** (all destructibles broken). Win
  = the last block breaks.
- **Falls:** a void fall = respawn at `start_gate` + `FALL_PENALTY` (time mode) and `attempts += 1` (the fall
  counter, used as the falls-metric). Player death only ever respawns — never ends the course.
- **Measured:** clear time (time mode) OR number of falls (falls mode).
- **Medal:** `medal_times` (≤ seconds) or `medal_falls` (≤ count).
- **Geometry-integrity (softlock guard — the key risk):** the course must never reach a state where an
  un-broken block is unreachable (no footing + no fuel route to hit it). For the "glass floor" variant where
  blocks ARE your footing, the author must guarantee a break order exists that never strands you (validated
  by QA gate D-SOFTLOCK below). If a course can strand, it is rejected until re-authored.
- **Mechanic dependency:** **v6 destructible_block** — Batch-1 #5. Blocks on it.

### 2.4 PHYSICS_PUZZLE (cause an outcome with the physics)
- **Fantasy (owner):** *"an explosion big enough to send the ball into the goal."* Trigger a bomb whose blast
  knocks the Ball into a GoalZone. Aim-by-explosion; solve in the fewest attempts.
- **Params:** `objective.win` (`"ball_in_goal"`, v1's only win); `objective.score_by` ∈ `"attempts" |
  "time"` (default `"attempts"`); `objective.medal_attempts {gold,silver,bronze}` (int = MAX attempts);
  `objective.reset_settle_s` (float, default ~2.5 — see auto-reset).
- **Objects:** a `ball` spawn point (Ball spawned by `on_stage_ready`), a `goal_zone` (team ignored),
  one or more `bomb`s, plus bumper walls / geometry for bank-shot puzzles.
- **Clear test:** any node in group `"goal_zone"` has `scored == true` (reuse the SPORTS GoalZone latch
  verbatim — it already senses the Ball layer and latches once).
- **Attempt / auto-reset:** an "attempt" = one puzzle reset. The puzzle **auto-resets** (Ball respawns at its
  spawn point, bomb(s) re-arm) if the Ball comes to rest OR leaves bounds WITHOUT scoring, after
  `reset_settle_s`; each reset does `_attempts += 1`. This prevents a dead-ball softlock and makes "attempts"
  a clean, QA-countable metric. A player fall just respawns the player (no scoring effect).
- **Measured:** attempts used (or time, if `score_by:"time"`).
- **Medal (fewer attempts = better):** `medal_attempts` e.g. `{gold:1, silver:2, bronze:5}` — gold = solve
  first try. (Or `medal_times` if time-scored.)
- **Mechanic dependency:** **v6 bomb** — Batch-1 #4. **Ball + GoalZone already shipped (SPORTS)** so ONLY
  the bomb blocks this type — note this in build order.

### 2.5 COLLECT_ALL (touch N pickups) — cheap bonus type
- **Fantasy:** a routing time-attack — grab every floating token across a void gauntlet on the fastest line.
- **Params:** top-level `medal_times` (seconds). Objects: N `pickup` tokens (group `"trials_pickup"`).
- **Clear test:** every member of group `"trials_pickup"` has `collected == true`.
- **Measured / medal:** clear time vs `medal_times` (falls add `FALL_PENALTY` as in REACH_GOAL).
- **Mechanic dependency:** none beyond the new lightweight `pickup` entity (§1.3). Cheap — build in Wave 2.

### 2.6 PRECISION_LAND (soft-land on tiny targets in sequence) — cheap bonus type
- **Fantasy:** landing mastery — kill your velocity and touch down softly on a sequence of tiny pads.
- **Params:** `objective.land_speed_max` (px/s, the "soft landing" threshold — a target only latches if you
  arrive slower); `objective.sequence` (bool — must be hit in order, default false); `medal_times` or
  `objective.medal_attempts`.
- **Clear test:** every member of group `"trials_target"` has `landed == true`.
- **Measured / medal:** time (or attempts). A too-fast touch does NOT latch (you must re-approach) — that is
  the skill, not a death.
- **Mechanic dependency:** none beyond the new `land_target` entity (§1.3). Build in Wave 2 with COLLECT_ALL.

> **STRETCH (not in v1): STAY_AIRBORNE / NO-TOUCH-SURFACE.** "Hover N seconds without touching any
> surface." Interesting (pure fuel-management, since fuel only refills on a bounce), but it fights the fuel
> economy and risks feeling like a frustration timer. Deferred until the 4 core + 2 cheap types prove out.

---

## 3. EXAMPLE COURSE BATTERY (~8 new, across the types)

The 5 shipped REACH_GOAL courses STAY (no regression). These are NEW example trials the level-designer
authors as the mechanics land; each is one line: **type · mechanic · challenge · the fun.**

1. **`t_hammer_vigil`** — SURVIVE · spinning_hammer (rotor ~4.5s period). Parked on ONE trampoline pad under
   a rotor that sweeps ~220°; survive 20s by boost-hopping through the ~1s clear window each revolution.
   *Fun: a heartbeat rhythm — one greedy beat resets you to 0.* (owner's headline request.)
2. **`t_debris_storm`** — SURVIVE · falling_debris. Survive 15s on a wide pad while telegraphed giant balls
   drop (cadence ~1.4s, shadows lead ~0.6s); read the shadows and weave. *Fun: reactive panic-dodging,
   escalating tempo.*
3. **`t_breakout_box`** — DESTROY_ALL (time) · destructible. Smash every block lining a bowl-shaped pad above
   the void without over-launching off the rim. *Fun: pinball-yourself, bank fuel, resist the greedy super.*
   (owner's breakout request.)
4. **`t_glass_floor`** — DESTROY_ALL (falls) · destructible (your footing IS the blocks). Break all blocks,
   but each break removes footing — order matters so you don't strand yourself. *Fun: a break-order puzzle
   under motion pressure.* (softlock-guard course — D-SOFTLOCK gate applies hard here.)
5. **`t_ball_cannon`** — PHYSICS_PUZZLE (attempts) · bomb + Ball + GoalZone. Detonate the bomb so its blast
   punts the resting Ball across a gap into the goal mouth; solve in one shot for gold. *Fun: aim an
   explosion, read the arc.* (owner's "explosion sends the ball into the goal" request.)
6. **`t_bank_shot`** — PHYSICS_PUZZLE (attempts) · bomb + Ball + GoalZone + bumper wall. The goal isn't on a
   direct line — the blast must carom the Ball off an angled bumper into a side pocket. *Fun: a geometry/
   bank-shot puzzle, satisfying "click" when the carom lands.*
7. **`t_token_dash`** — COLLECT_ALL · pickups over a void gauntlet. Grab all 6 floating tokens on the fastest
   flight line; tokens are placed so the optimal route is non-obvious. *Fun: route optimization + fuel
   pacing, leaderboard-y replay.*
8. **`t_pinpoint`** — PRECISION_LAND · 4 tiny targets in sequence, `land_speed_max` low. Kill your velocity
   and touch down softly on each pinhead pad in order. *Fun: the anti-chaos trial — total control mastery.*

Sequencing across a set ramps mild → wild: REACH_GOAL basics → PRECISION/COLLECT (control) → SURVIVE
(rhythm) → DESTROY_ALL (management) → PHYSICS_PUZZLE (the brain-teaser capstone).

---

## 4. SCHEMA + BUILD PLAN

### 4.1 Course JSON additions (summary)

```json
{
  "mode": "trials",
  "objective": {                    // ABSENT ⇒ REACH_GOAL (back-compat; shipped courses unchanged)
    "type": "SURVIVE",              // REACH_GOAL|SURVIVE|DESTROY_ALL|PHYSICS_PUZZLE|COLLECT_ALL|PRECISION_LAND
    "survive_seconds": 20.0,        // SURVIVE
    "medal_survive":  { "gold": 0, "silver": 1, "bronze": 3 },   // SURVIVE (max deaths)
    "score_by": "attempts",         // DESTROY_ALL:"time"|"falls" ; PHYSICS_PUZZLE:"attempts"|"time"
    "medal_falls":    { "gold": 0, "silver": 1, "bronze": 3 },   // DESTROY_ALL falls-mode
    "medal_attempts": { "gold": 1, "silver": 2, "bronze": 5 },   // PHYSICS_PUZZLE attempts-mode
    "reset_settle_s": 2.5,          // PHYSICS_PUZZLE auto-reset delay
    "land_speed_max": 260.0,        // PRECISION_LAND soft-landing threshold (px/s)
    "sequence": true                // PRECISION_LAND ordered flag
  },
  "medal_times": { "gold": 8.0, "silver": 14.0, "bronze": 25.0 } // TIME-scored types (REACH/COLLECT/PRECISION/DESTROY-time)
  // objects: add per type — moving_hazard(rotor), destructible[], bomb + ball + goal_zone, pickup[], land_target[]
}
```

### 4.2 New code (in TrialsMode) vs reused

**New in TrialsMode (all additive branches in methods it already overrides):**
- Cache `_cur_objective` in `next_level_path`; reset per-type state.
- Dispatch in `is_stage_over` (6 clear tests, each a group scan/timer check).
- Branch `on_kill` (survive-reset vs fall-penalty vs puzzle-noop).
- Generalize `medal_for` → `medal_for_result` (time / resets / attempts, all ≤-compare).
- Branch `stage_end_banner` (per-type result text).
- Override `on_stage_ready` to spawn the Ball for PHYSICS_PUZZLE (the ONE seam newly overridden — already
  exists on the seam; parity for other types).
- New HUD-read helpers: `objective_type()`, `survive_remaining(runner)`, `blocks_remaining(runner)`,
  `attempts_used()` — TrialsHUD swaps its center readout per type (countdown / block-count / attempt-count /
  timer). Small additive HUD change.

**Reused unchanged:** the runner (`PartyMatch`) — polls_goal already drives per-frame `is_stage_over`;
`GoalGate`, `void`, platform tiers; SPORTS `Ball` + `GoalZone` + the ball-spawn helper; v6 `moving_hazard`
(rotor), `destructible`, `bomb`, `debris_spawner`. **New entities:** `pickup`, `land_target` (both thin
`GoalGate`-latch clones).

**Runner hooks needed: ZERO new.** (`on_stage_ready` already exists.)

### 4.3 De-risked build order (with mechanic dependencies)

| Wave | Deliverable | Blocks on |
|---|---|---|
| **1** | **Framework + REACH_GOAL parity.** Add `objective` dispatch to TrialsMode; absent-block ⇒ REACH_GOAL. Prove the 5 shipped courses clear with **identical** times + medals. No new type authored yet. | **nothing** (pure refactor) |
| **2** | **COLLECT_ALL + PRECISION_LAND.** Build the `pickup` + `land_target` entities; author `t_token_dash` + `t_pinpoint`. Proves multi-type dispatch works with NO heavy dependency. | new `pickup`/`land_target` entities only |
| **3** | **SURVIVE.** Author `t_hammer_vigil` + `t_debris_storm`. | **v6 spinning_hammer (rotor)** + **v6 falling_debris** |
| **4** | **DESTROY_ALL.** Author `t_breakout_box` + `t_glass_floor`. | **v6 destructible_block** |
| **5** | **PHYSICS_PUZZLE.** Override `on_stage_ready` ball-spawn; author `t_ball_cannon` + `t_bank_shot`. | **v6 bomb** (Ball + GoalZone already shipped) |

Framework (Wave 1) ships first and independent, so REACH_GOAL parity is locked before any variety lands.
Waves 3-5 each block only on their one v6 mechanic — author-and-validate them as those mechanics land, in
whatever order v6 delivers them. Add the new courses to a set in `course_sets.json` (a new `"varied"` set,
or append to `campaign`) once each is validated.

---

## 5. VALIDATION (measurable; QA drives the game)

**Framework / regression (Wave 1 — hard gate):**
- **R-PARITY:** each of the 5 shipped courses (no `objective` block) resolves to REACH_GOAL and clears with
  the **same medal thresholds + same run-time behavior** as before this change. Drive the full `campaign`
  set start→finish: all 5 clear, the per-course COURSE CLEAR banner + medal fire, and the TRIALS COMPLETE
  summary (total time + medal tallies) is correct. **Zero regression.**

**Per-type gates (each type, driven live at gameplay zoom):**
- **SURVIVE — dodgeable-with-skill:** a skilled driven line survives the full `survive_seconds` in **≥8/10**
  attempts; the hazard has a clear window every period (**never 100% coverage** — zero unavoidable
  instakills); a **zero-input** driver dies within ~1 hazard period (proves the hazard is lethal AND that
  survival requires active play); a death **resets the survival clock to 0** (verify progress returns to 0
  and `_resets` increments, not a `+2s` penalty).
  - **S-CAMP (Pillar 2):** confirm there is **no hazard-free tile** where a player can idle out the whole
    timer — the safe spot must move/return each beat, forcing motion. If a static safe camp exists, reject.
- **DESTROY_ALL — no softlock, completable:** across **≥20** driven attempts, the last block is always
  reachable and the course clears within its bronze threshold; **D-SOFTLOCK:** no configuration ever strands
  the player with an un-broken block and no footing/fuel route to it (hard gate on `t_glass_floor`); breaking
  order never reaches an unwinnable state.
- **PHYSICS_PUZZLE — solvable + non-degenerate:** a known-good bomb trigger sends the Ball into the goal
  within the gold attempt count; the Ball **can never be permanently lost** (auto-reset re-spawns it +
  re-arms after `reset_settle_s`); each reset increments `_attempts`; there is **no degenerate solve** that
  bypasses the intended physics (e.g. the player can't body-carry the Ball into the goal if that trivializes
  it — verify the intended blast solution is the reasonable path).
- **COLLECT_ALL / PRECISION_LAND — reachable + flight-required:** every pickup/target is reachable only by
  flying (re-run the per-gap analysis at real coords — no passive-bounce route); the course clears within
  bronze; a PRECISION target does **not** latch on a too-fast touch (verify the `land_speed_max` gate).

**Cross-type (all):**
- **C3 readability:** a naive viewer names the win/lose rule of each course in one sentence from watching.
- **Medal sanity:** for each new course, a clean skilled run earns gold; a sloppy-but-successful run earns
  bronze; the thresholds are drive-checked (not just math), consistent with the movement Tuning.
- **Motion-health:** no stuck/head-bang/camp pathology on any course (`PartyMatch.bot_motion_health`), and
  the felt experience is reported (WATCH the motion, don't just read pass/fail — per the "validate motion,
  not just outcomes" lesson).

---

## 6. CROSS-MODE NOTE

These objective types are reusable seeds beyond TRIALS (all reuse the same group-scan / timer clear-test
pattern, so they port through the GameMode seam without a runner change):

- **BRAWL sub-modes:** SURVIVE → a "king-of-the-hazard" / last-one-flying variant (the v6 COLLAPSING ARENA is
  already this shape); DESTROY_ALL → a team race to break the most blocks; PHYSICS_PUZZLE → a co-op "get the
  ball in the goal together" party challenge.
- **GAUNTLET variants:** SURVIVE is literally a wave's win condition (survive the timer); DESTROY_ALL can be
  a wave-clear objective ("break all the crates before the next wave"). A collapsing-floor SURVIVE makes a
  late-wave intensity spike without more bots.
- **SPORTS:** PHYSICS_PUZZLE shares SPORTS' Ball + GoalZone entities outright — a "trick-shot challenge" solo
  SPORTS variant falls out for free.

Keep each as a per-mode objective declaration; the framework here (objective block + mode-side dispatch) is
the shared substrate.
