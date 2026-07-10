# Spec: v10 — TRIALS COMPLETION MODEL (Pico-Park-style: binary, no clock, multi-player-parallel)

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD. **Version 1 — 2026-07-06.**
>
> **v1 changelog (2026-07-06):** Owner directive redirects TRIALS away from time-attack toward a
> Pico-Park-style **binary completion** model. This spec **SUPERSEDES the TIME / MEDAL / PAR layer of
> `docs/specs/v7_trials_challenge_types.md`** (its §1.2 medal rows, §2 per-type medal criteria, §4.1
> medal-schema fields, §5 medal-sanity gates) and **ADDS a multi-player-parallel completion layer**. It
> **PRESERVES v7's objective-type framework** unchanged in shape: the `objective` block, the six types
> (REACH_GOAL / SURVIVE / DESTROY_ALL / PHYSICS_PUZZLE / COLLECT_ALL / PRECISION_LAND), the
> absent-block ⇒ REACH_GOAL back-compat hinge, and the "all variety lives inside the mode, zero new
> runner hooks" architecture. Only the scoring/timer layer changes, plus the completion gate.
>
> **Responds to (owner, verbatim):** *"For the trials, I'd rather it be more like Pico Park — either you
> can complete the trial, or you can't, with NO time pressure. Time pressure usually moves things from
> fun to stressful, especially if co-op is involved."* And the scope ruling: *"For now let them all work
> with a single player, but allow multiple players to complete them at the same time, with ALL players
> needing to reach the end — but NO specific co-op mechanics."*
>
> **Required reading already run:** `docs/STATUS.md` (Trials is currently solo TIME-ATTACK with
> medals/par — that is what this replaces), `docs/specs/v7_trials_challenge_types.md` (the objective-type
> framework this preserves), `src/modes/TrialsMode.gd` + `src/ui/TrialsHUD.gd` (exact medal/par/timer
> logic to strip — cited by line/method below), `src/modes/PartyMatch.gd` (the runner: `spawn_plan`,
> per-frame `is_stage_over` poll, `_respawn_after_death`, `_spawn_at`, `match_winner`), `src/entities/
> GoalGate.gd` (the single-`reached` latch that must become per-player), `levels/course_sets.json` +
> `levels/courses/*.json`, `docs/GAME_ESSENCE.md` (fantasy-fit), analysis toolkit recipe 1 (reachability).
>
> **This doc is DESIGN + the completion rules + the multi-player rules + a precise strip/add checklist for
> the gameplay-programmer + the JSON migration + measurable QA criteria.** The programmer owns feasibility;
> I do not write GDScript.

---

## The player fantasy

**"I can see the whole course. There's no clock breathing down my neck — just the line, the jump, and
the landing. I try it, I fall, I try it again, and when it finally clicks I'm HOME. And if my friend is
running it next to me, we both fly our own line and the door doesn't open until we're BOTH home."**

TRIALS is the calm, mastery-focused counterpoint to BRAWL's chaos. It is still the movement product —
you FLY the line, you RECOVER from a fall, you commit to a jump — but the win state is *understanding the
course*, not shaving hundredths. Removing the clock removes the one thing that turns "I'm learning this"
into "I'm failing this," which is exactly the stress the owner wants gone, especially with a buddy on the
couch.

---

## Why v10 (design rationale — read before arguing with the model)

1. **A clock fights the fantasy of mastery-through-repetition.** Falling is the core learning loop of a
   movement game; a timer that punishes every fall reframes learning as losing. Pico Park's genius is that
   "you either did it or you didn't" makes retrying weightless. Binary completion = weightless retry.
2. **Time pressure + shared screen = stress multiplier.** The owner's specific worry. With no clock, two
   players on one course is relaxed parallel play, not a race that punishes the slower player.
3. **Every objective type survives the clock's removal** (see §6) — the clock was always a *scoring* layer
   bolted on top, never the win condition. REACH_GOAL was already "touch the gate"; the medal was garnish.
   So this is a **subtractive** change to the win logic, not a redesign of what the courses ARE.
4. **The pillars are respected, not bent:**
   - *Pillar 2 (constant motion, no camping):* a **finished** player waiting at the goal is NOT a
     pillar-2 violation — there is no score to farm and no opponent to stall (TRIALS has no combat). The
     anti-camping pillar guards adversarial stalling; a Pico-Park "done, waiting for you" pose is the
     intended feel. The *unfinished* players are still under the course's motion pressure (SURVIVE's
     moving safe-spot, the void between pads) exactly as v7 specified.
   - *Pillar 5 (readability):* the HUD gets SIMPLER (a home-count + per-player pips replace a timer +
     medal thresholds + best-time). A naive viewer reads "2 of 3 HOME" instantly.
   - *Flight-required (GAME_ESSENCE Rule A):* unchanged — every course still requires the jetpack to
     traverse/win; this spec touches only win-detection and scoring, never geometry or fuel.

---

## 1. THE COMPLETION MODEL (the whole ruling in one place)

### 1.1 Binary. No clock. No medal. No par.

- A course is either **COMPLETE** or **not**. There is **no timer**, **no par time**, **no medal times**,
  **no best-time**, **no attempt/fall penalty**, **no score**.
- `round_clock` may keep ticking as an internal engine stat (it "gates nothing" per PartyMatch line 103) —
  but it is **never displayed, scored, or compared**. Nothing the player sees references time.
- A fall = **respawn at the start point, with zero penalty** (no clock to charge, no score to dock). This
  is the correct no-pressure behavior: falling costs only the seconds it takes to fly back to where you
  were, which is inherent, not punitive.

### 1.2 The completion gate: EVERY LIVING PLAYER must finish

**The course completes the instant every living participant has, on their own, satisfied the course's
objective.** Formally, `is_stage_over()` returns true iff:

```
participants.size() > 0  AND  for every participant p: done(p) == true
```

- **"participant"** = every player slot the course spawned that still exists (`is_instance_valid`). TRIALS
  never eliminates (see §3), so in practice this is **all N spawned players for the whole course**. A
  player who is mid-respawn (dead, waiting for the respawn timer) is STILL a participant — the course does
  **not** complete until they too are `done`. There is no edge where a dead player is skipped.
- **`done(p)`** is defined per objective type (§2). It is a **sticky per-player latch**: once a player is
  `done`, they STAY `done` for the rest of the course even if they subsequently fall and respawn. This is
  deliberate — it (a) implements the Pico-Park "I finished, I'm waiting at the door" feel, (b) kills a
  griefing/softlock class where a finished player falling could un-complete the course for everyone.
- **Single-player is the degenerate case:** with N = 1, "every participant done" ≡ "the one player is
  done" ≡ today's behavior (touch the goal → stage over). REACH_GOAL courses therefore remain functionally
  identical for the solo campaign (see the R-PARITY gate, §7).

### 1.3 What "reach the end" means, and the honest multiplayer scope

The owner's completion condition is *"ALL players needing to reach the end"* with *"NO specific co-op
mechanics … each player plays the same course independently."* Honoring **both** halves forces a design
ruling, because the six objective types split cleanly on whether independent parallel play is even
possible with a **shared** world:

| Objective type | Per-player-native? | Multiplayer status (this ship) |
|---|---|---|
| REACH_GOAL | YES — each player touches the gate themselves | **Full parallel-independent** |
| SURVIVE | YES — each player must personally survive the duration | **Full parallel-independent** |
| COLLECT_ALL | NO — tokens are shared, latch once | **SOLO for this ship** (see ruling) |
| DESTROY_ALL | NO — blocks break once | **SOLO for this ship** |
| PHYSICS_PUZZLE | NO — one ball, one goal | **SOLO for this ship** |
| PRECISION_LAND | NO — targets latch once | **SOLO for this ship** |

**RULING (the faithful reconciliation of the owner's two constraints):** the multi-player-parallel
completion model ships **fully for REACH_GOAL and SURVIVE** — the two types whose success is intrinsically
*per-player* and works over a shared world with **no forced cooperation and no interference**. The four
**object-mutation types remain single-player** for this ship, because their world state is a single shared
set of objects:
- Making them multiplayer with **shared** objects would create either **forced cooperation** (players
  split the tokens/blocks between them) or **mutual interference** (one player smashes the block another
  was lining up; two bodies jostle the same puzzle ball) — **both violate the owner's explicit "independent,
  no co-op mechanics."**
- Making them multiplayer *cleanly* would require **per-player instanced objects** (each player gets their
  own token set / block field / ball), which is a larger feature than this pass.
- All six types **still "work with a single player"** — the owner's stated baseline requirement — so
  nothing is lost; the object-mutation types are simply flagged single-player-recommended in course
  metadata (§4) and the multiplayer extension is a named future pass (§5).

This is the exact "push back to honor the pillars" call the design role owns: I am honoring the
*independence + no-co-op* constraint, which is the binding one. Flag it for the owner as a conscious scope
line, not an omission.

### 1.4 Fall / respawn behavior (confirmed against the no-pressure model)

- A fall out of bounds (ring-out) **respawns** the player at the start point after `Tuning.respawn_delay`
  via the runner's existing `_respawn_after_death` path (already wired; `lives_per_player = 99` keeps the
  player from ever being eliminated). **No time penalty, no score penalty, no life shown** — there is
  nothing to penalize.
- This is the correct no-pressure behavior: the only cost of a fall is flying back, which is intrinsic.
- SURVIVE keeps v7's "a death resets *that player's* survival clock" (§2.2) — but that is now framed as a
  neutral retry, not a scored death. No death counter is shown as a score; if shown at all it is a neutral
  "retries" readout with no bearing on completion.

---

## 2. `done(p)` PER OBJECTIVE TYPE

All types keep v7's clear-detection *mechanism* (group scans, latches, timers) — only the aggregation
changes from "any / global" to "**every living player**," and all medal/time comparisons are deleted.

### 2.1 REACH_GOAL — done(p) = p has touched a goal_gate (sticky)
- **Change from v7:** the clear test was "**any** node in group `goal_gate` has `reached == true`" (ends
  on the FIRST player). It becomes: **every** participant p has, at some point, entered a goal_gate.
- **Implementation:** GoalGate stops latching a single shared `reached` bool and instead records the set
  of distinct Player bodies that have entered (sticky). The mode's gate = every participant is in the
  union of all goal_gates' entered-sets. (`reached` may remain as a derived "≥1 player home" flag purely
  for the gate's green visual state — see §4 GoalGate change.)
- **Multiplayer:** full — each player flies their own line to the same gate; the door opens when the last
  one arrives. No interference (multiple bodies can occupy the gate area).

### 2.2 SURVIVE — done(p) = p has been continuously alive ≥ `survive_seconds` (sticky)
- **Change from v7:** the single `_survive_base` clock keyed to `players[0]` becomes a **per-player**
  base `_survive_base[i]` and a per-player sticky `_survived[i]`. Each frame: if participant i is dead
  (respawning), pin `_survive_base[i] = round_clock` (their clock holds at 0, exactly v7's single-player
  pin). If alive and `round_clock - _survive_base[i] >= survive_seconds`, latch `_survived[i] = true`.
- **Gate:** every participant has `_survived[i] == true`.
- **No death scoring:** a death resets only *that* player's survival clock (retry). No medal, no death
  medal map. Deaths may show as a neutral per-player "retries" readout (optional, cosmetic).
- **Multiplayer:** full — all players share the hazard rhythm but each survives on their own; a player
  who dies just re-starts their own clock, and the course completes when everyone has banked a clean run.
  A player who has banked their survival is `done` and may wait (no pillar-2 issue — no combat, no score).

### 2.3 DESTROY_ALL — SOLO. done = all destructibles broken
- **Change from v7:** drop `score_by`, `medal_times`, `medal_falls`. Clear = group `destructible` empty
  (guarded by `_blocks_total > 0`), exactly v7's mechanism. Fall = respawn, no penalty, no fall counter as
  a metric (a neutral live "blocks left" count is the only readout).
- **Multiplayer:** SOLO this ship (§1.3). If >1 player is present the mode MAY fall back to the global
  "all blocks broken" test (shared/accidental-coop) — but courses of this type are authored/flagged
  single-player-recommended, so this fallback is defensive, not a designed experience.

### 2.4 PHYSICS_PUZZLE — SOLO. done = ball in goal
- **Change from v7:** drop `score_by`, `medal_attempts`, and the `_puzzle_attempts` **score** (the attempt
  count is no longer a scored metric — auto-reset still happens, but "attempts" is not shown as a score;
  at most a neutral "resets" tick). Clear = any `goal_zone.scored` (v7 mechanism, verbatim). `reset_settle_s`
  and the auto-reset stay FUNCTIONAL (they prevent a dead-ball softlock) — this is even more valuable
  without a clock, because there is now literally unlimited time to solve it.
- **Multiplayer:** SOLO this ship (one ball, one goal; two bodies would interfere — §1.3).

### 2.5 COLLECT_ALL — SOLO. done = all pickups collected
- **Change from v7:** drop `medal_times`. Clear = every `trials_pickup.collected` (v7 mechanism). Fall =
  respawn, no penalty. Readout = neutral "tokens N/M."
- **Multiplayer:** SOLO this ship (shared tokens ⇒ forced work-splitting = co-op — §1.3).

### 2.6 PRECISION_LAND — SOLO. done = all targets soft-landed
- **Change from v7:** drop `medal_times` / `medal_attempts`. Clear = every `trials_target.landed` (v7
  mechanism). The `land_speed_max` soft-landing gate and `sequence` flag stay FUNCTIONAL (they are the
  skill, not scoring). Fall = respawn, no penalty.
- **Multiplayer:** SOLO this ship (shared targets latch once — §1.3).

---

## 3. "LIVING" / PARTICIPANT EDGE CASES (the reachability + fairness lens)

Ran analysis-toolkit recipe 1 (reachability) on the new gate. Findings:

1. **A dead (respawning) player never softlocks completion, and is never skipped.** The player node is not
   freed on death (`_respawn_after_death` repositions it), so it stays a valid participant. It is not
   `done` while dead (goal not touched / survival clock pinned to 0), so the gate correctly waits for it.
   Once it respawns and finishes, the course completes. No "ghost participant" edge.
2. **A finished player who then falls does NOT un-complete the course** — `done` is sticky (§1.2). This
   closes the griefing/softlock class where a bored winner keeps falling into the void to reset the gate.
3. **A player who NEVER finishes ⇒ the course cannot complete (a potential human softlock).** This is a
   *social* state on a shared couch, not a geometry softlock — but it must have an escape:
   - **Hard gate (unchanged from v7):** every course must be **single-player-completable** (the reachability
     / flight-required analysis per GAME_ESSENCE). So no *geometry* can strand a player.
   - **Escape hatch:** the **pause menu must offer "Restart Course" and "Quit to Menu"** (verify these
     exist / wire them). There is deliberately **no auto-fail and no time-out** — auto-fail would
     reintroduce exactly the pressure the owner removed. A stuck player restarts or quits; no timer ever
     forces the issue.
4. **Camera framing with a large player spread.** The runner frames all living players
   (`P1_CAM_WEIGHT`, "frames ALL living players"). On a long parallel course with players far apart, the
   camera zooms out, which can hurt readability of individual lines. **Watch item, not a blocker** for
   REACH_GOAL/SURVIVE (SURVIVE courses are single-screen kill-boxes → no spread; REACH_GOAL parallel
   courses should be authored screen-scale-aware). Note it; measure in the C-CAM gate (§7).
5. **Spawn stacking:** a course has ONE `start_gate` ⇒ one spawn point; `_spawn_at(i)` stacks players
   60px vertically per ring (already implemented). For N ≤ ~4 this reads fine (they bounce apart on the
   first frame). Acceptable; no new spawn plumbing required. (Optional future: multiple `start_gate`s.)

---

## 4. WHAT REPLACES THE HUD

Strip from `TrialsHUD.gd`: the big RUN TIMER, medal label, medal thresholds (`G/S/B`), BEST time, the
fall/penalty framing. **The HUD gets simpler, not busier** (pillar 5).

New TRIALS HUD center readout, per type:

- **All types — the hero readout is the HOME/COMPLETION tracker:** a **"n of N HOME"** count plus **one
  pip per participant, colored to that player's skin**, that lights (fills / checks) when that player is
  `done`. For N = 1 this is a single pip — a clean "GO" → "HOME!" indicator, no numbers.
- **REACH_GOAL:** the home tracker only (no timer). Optional small "fly to the goal" hint pre-first-touch.
- **SURVIVE:** per-player survival **progress bars/rings** counting UP toward `survive_seconds` (a player's
  ring fills; on their death it snaps back to 0; when full it locks to a "safe/done" check). No death
  score; an optional neutral "retries" tick per player.
- **DESTROY_ALL (solo):** live **"BLOCKS n"** count → 0, plus the home pip. No timer, no falls score.
- **PHYSICS_PUZZLE (solo):** a **"BALL → GOAL"** prompt + the home pip; optional neutral "resets" tick. No
  attempt score.
- **COLLECT_ALL (solo):** **"TOKENS n / m"** + home pip. No timer.
- **PRECISION_LAND (solo):** **"PADS n / m"** + home pip. No timer.
- **Keep:** the fuel gauge (unchanged) and the CENTER banner / MATCH-END panel machinery (text changes
  only — see §5 banners).

---

## 5. MEDAL / PAR / COSMETIC-STAR DISPOSITION

- **Medals, par times, medal_times, best-time: REMOVED.** Not hidden — removed from the model, the code
  reads, the HUD, and (as vestigial fields) the course JSON (§4-migration below). The `MEDAL_COLORS` map,
  `medal_for`, `medal_times`, `_result_medal`, `_medal_le_int`, `best_time`, `_best_times` all go (§ checklist).
- **Banners become binary:**
  - Per-course clear: **"COURSE CLEAR!"** (drop `%.1fs — MEDAL`). For SURVIVE: **"EVERYONE SURVIVED!"**;
    DESTROY: **"ALL CLEAR!"**; PUZZLE: **"SOLVED!"**; COLLECT: **"ALL COLLECTED!"**; PRECISION:
    **"ALL LANDED!"** — no numbers, no medal.
  - Set end: **"TRIALS COMPLETE!"** (drop the `Total %.1fs  Nx GOLD…` subline; either no subline or a
    neutral **"All courses cleared."**).
- **Cosmetic completion stars — FUTURE PASS, NOT this ship (keep the shipped model strictly binary).**
  Once binary completion is proven fun, *optional, purely-cosmetic* non-time challenge stars are worth a
  pass — e.g. a **"no-deaths"** star (cleared without a single respawn), an **"all-tokens"** star on a
  REACH_GOAL course that also has bonus pickups, a SURVIVE **"flawless"** star. **Rules if/when added:**
  they must be (a) NON-time (never a clock), (b) purely cosmetic (never gate progression/unlocks), (c)
  never shown as pressure during the run (award on the clear banner only). Do **not** build these now —
  they are noted so the door stays open, not to expand this ship.

---

## 6. OBJECTIVE TYPES WITHOUT A CLOCK — every one survives

No objective type dies with the clock; only the scoring layer that sat on top is removed. Confirmed
per type:

| Type | v7 scored by | v10 binary win | Adapts cleanly? |
|---|---|---|---|
| REACH_GOAL | time (par) | touch the goal | YES — the medal was always garnish on a binary touch |
| SURVIVE | deaths (medal_survive) | outlast `survive_seconds` (retries free) | YES — purest form; deaths become weightless retries |
| DESTROY_ALL | time or falls | break every block | YES — "smash all" was always the real condition |
| PHYSICS_PUZZLE | attempts | ball in goal | YES — *improved*: unlimited attempts removes solve-pressure; auto-reset stays as anti-softlock |
| COLLECT_ALL | time (routing) | grab every token | YES — loses only "fastest route"; still a full traversal/collection challenge |
| PRECISION_LAND | time/attempts | soft-land every pad | YES — the `land_speed_max` skill gate is intact; only the clock garnish is gone |

**The one thing genuinely lost:** the *replay-for-a-better-time* loop (leaderboard-y COLLECT routing,
time-shaving REACH_GOAL). That loss is the owner's explicit intent ("time pressure moves things from fun to
stressful"). The replay motive becomes "clear the harder later courses" + (future) cosmetic stars, not the
clock.

---

## 7. SUCCESS CRITERIA (QA-verifiable by driving the game)

Grouped. Each is measurable by a QA agent driving the game (single- and multi-player) and reading state
via `eval`. No number references a clock as a win/lose gate anywhere.

**Binary-model / regression:**
- **R-PARITY (solo REACH_GOAL):** each shipped `campaign` course (no `objective` block) still completes on
  the single player touching the goal, and completing the last course ends the match. **No timer, no medal,
  no par, no best-time appears anywhere on the HUD or banners.** Drive `campaign` start→finish: all 5
  complete; each shows "COURSE CLEAR!" (no number/medal); set end shows "TRIALS COMPLETE!" (no total/tally).
- **R-NOCLOCK:** grep + drive — no code path reads/writes/displays a medal, par, `medal_times`, best-time,
  or a time-penalty. `current_time`/`run_penalty`/`FALL_PENALTY` and all medal helpers are gone (or provably
  dead). The HUD shows no time value.
- **R-FALL:** a fall respawns the player at the start with **zero** observable penalty (no counter ticks a
  score, no time added, no life removed from view); the player can fall arbitrarily many times and still
  complete.

**Multi-player-parallel completion (REACH_GOAL + SURVIVE):**
- **M-ALLHOME (REACH_GOAL, N=2 and N=3):** with N players spawned, the course does **NOT** complete when
  the FIRST player reaches the goal; the HUD shows "1 of N HOME" and the run continues. It completes the
  instant the LAST player reaches the goal ("N of N HOME" → COURSE CLEAR). Verify at N=2 and N=3.
- **M-STICKY:** a player who reaches the goal, then falls into the void and respawns, **stays counted
  HOME** (their pip stays lit); the course still completes when the others arrive. It never regresses to a
  lower home-count.
- **M-WAITFORDEAD:** while one player is mid-respawn (dead), the course does **not** complete even if all
  others are home; it completes only after the respawned player also reaches the goal.
- **M-SURVIVE (SURVIVE, N=2):** the course completes only when **both** players have each banked a full
  `survive_seconds` alive; one player's death resets **only that player's** progress bar (the other's is
  untouched); a player who has banked survival is shown "safe/done" and their death afterward does not
  un-complete (sticky).
- **M-NOCOOP:** confirm no shared button / boost / co-op-only mechanic exists on any multiplayer course;
  the two players never *need* to interact to complete (each flies their own independent line).

**Solo object-mutation types (unchanged mechanics, medal layer stripped):**
- **S-TYPES:** each of DESTROY_ALL / PHYSICS_PUZZLE / COLLECT_ALL / PRECISION_LAND completes solo on its
  world condition (blocks empty / ball in goal / all tokens / all pads), shows the correct neutral readout
  (BLOCKS→0, BALL→GOAL, TOKENS n/m, PADS n/m), and shows **no** timer/attempt/medal. PHYSICS auto-reset
  still re-spawns a lost ball (unlimited attempts, never softlocks). These courses are flagged
  single-player-recommended (§4-migration).

**Pillar / fairness:**
- **P2-CAMP:** SURVIVE still forces motion — no static hazard-free tile lets an *unfinished* player idle
  out the duration (v7 S-CAMP, unchanged). A *finished* player waiting at the goal is expected and NOT a
  violation (no score, no combat).
- **P-SOFTLOCK:** every course is single-player-completable (reachability/flight-required analysis holds);
  the pause menu offers **Restart Course** + **Quit** so a stuck human in multiplayer always has an escape;
  there is **no auto-fail / no time-out**.
- **C-CAM (watch item):** on a multiplayer REACH_GOAL course, a large spread between players zooms the
  camera out — report whether individual lines stay readable at gameplay zoom (N=2, players at opposite
  ends). Not a blocker unless readability fails.
- **C-READ:** a naive viewer names the win rule of each course in one sentence, and reads the HOME tracker
  ("2 of 3 home") instantly.

---

## 8. IMPLEMENTATION CHECKLIST FOR THE GAMEPLAY-PROGRAMMER

Exact files and edits. **Preserve v7's objective-type dispatch skeleton;** this is subtractive (rip out
scoring) + one gate generalization (any→all) + per-player SURVIVE/GoalGate state. **Zero new runner hooks**
(same as v7 — the runner already polls `is_stage_over` every combat frame and `spawn_plan` already spawns
`human_count` players).

### 8.1 `src/entities/GoalGate.gd` — per-player home tracking
- **ADD** a sticky set of the distinct Player bodies that have entered, e.g. `var home := {}` keyed by the
  Player's instance id (or a small `Array[Player]`). In `_on_body_entered`, when `body is Player`, record
  it (idempotent; never clears).
- **KEEP** a derived `reached` (= `not home.is_empty()`) so `_draw`'s green "reached" glow still works
  (lights once ≥1 player is home). Do NOT gate the stage on this bool anymore — the mode reads `home`.
- **ADD** a helper the mode can call, e.g. `func has_player(p) -> bool` (is p in `home`).

### 8.2 `src/modes/TrialsMode.gd`

**STRIP (delete — the medal/par/time layer):**
- `FALL_PENALTY`, `run_penalty`, `attempts` (as a scored/penalty counter — a neutral "blocks/tokens left"
  is computed live from groups, not from `attempts`).
- `_cur_medal_times`, `_read_medal_times`, `medal_for`, `medal_times`, `medal_color`, `MEDAL_COLORS`.
- `_result_medal` / `result_medal` / `_medal_le_int`, `_best_times`, `best_time`.
- `current_time` (or demote to an unexported internal stat never displayed).
- In `on_kill`: remove the `run_penalty += FALL_PENALTY; attempts += 1` branch — a fall is now a pure
  respawn for ALL types (SURVIVE keeps its per-player clock reset, below).
- In `stage_end_banner`: remove all time/medal/attempt/fall text; emit the binary banners (§5).
- In `match_end_banner`: remove `total` time and gold/silver/bronze tallies; emit "TRIALS COMPLETE!" +
  optional neutral subline.
- `_course_results` medal/time fields (keep only what a neutral set-end summary needs, or drop entirely).

**CHANGE (generalize the gate any→all-living):**
- Add a `_participants(runner) -> Array` helper = every `runner.players[i]` that `is_instance_valid`.
- **REACH_GOAL** in `is_stage_over`: replace the "any `goal_gate.reached`" scan with **"every participant
  is `home` in some goal_gate"** (use GoalGate.has_player). Guard `participants.size() > 0`.
- **SURVIVE:** replace the single `_survive_base`/`_resets` with **per-player** arrays `_survive_base:
  PackedFloat32Array` (or `Array`) and `_survived: Array[bool]`, sized to the participant count in
  `next_level_path`/`on_stage_ready`. Per frame in the SURVIVE branch: for each participant i — if dead,
  pin `_survive_base[i] = round_clock`; else if `round_clock - _survive_base[i] >= survive_target()` set
  `_survived[i] = true`. `is_stage_over` (SURVIVE) = every participant `_survived[i]`. `on_kill` for
  SURVIVE resets only the *victim's* base (`_survive_base[victim_idx] = round_clock`) — note `on_kill`
  already receives `_victim_idx`; use it instead of assuming player 0.
- **DESTROY_ALL / PHYSICS_PUZZLE / COLLECT_ALL / PRECISION_LAND:** keep v7's global clear test unchanged
  (these are solo — §1.3). No per-player aggregation needed. Just delete their medal/score reads.

**ADD (HUD-read surface for the new HUD, §4):**
- `home_count(runner) -> int` and `participant_count(runner) -> int` (for "n of N HOME").
- `player_done(runner, i) -> bool` (drives the per-player pip; per-type: REACH = goal has_player;
  SURVIVE = `_survived[i]`; solo types = the global clear applied to the single player).
- SURVIVE per-player progress: `survive_ratio(runner, i) -> float` (`(round_clock - _survive_base[i]) /
  survive_target()`, clamped).
- Keep the existing neutral live readouts (`blocks_remaining`, tokens/pads counts) but rename/repurpose
  any "attempts/deaths as score" to neutral counters.

**KEEP UNCHANGED:** `configure` (99 lives, 999999 kill target — the no-elimination + no-kill-race guards
are still exactly right), `spawn_plan` (already spawns `human_count` players — this is the multi-player
spawn; nothing to add), `polls_goal`, `on_stage_ready` (still spawns the puzzle ball / captures group
totals), `match_winner` (returns 0 when the last course's `is_stage_over` is true — still correct; with
the all-home gate it fires only when everyone's home), the objective-block read + dispatch skeleton,
`_load_course_set`.

### 8.3 `src/ui/TrialsHUD.gd`
- **STRIP:** the run-timer readout, medal label, threshold label (`G/S/B`), best label, and the
  fall/penalty framing (`_show_timer`'s time + medal, `_show_survive`'s deaths-as-medal, `_show_destroy`
  /`_show_puzzle` time + medal). Remove `_set_medal` and all `medal_*` calls into the mode.
- **ADD:** the HOME tracker — a "n of N HOME" label + one skin-colored pip per participant (light when
  `mode.player_done(runner, i)`). This is the primary readout for every type.
- **PER-TYPE secondary readout (neutral, no clock):** SURVIVE = per-player progress rings/bars from
  `survive_ratio`; DESTROY = "BLOCKS n"; PUZZLE = "BALL → GOAL"; COLLECT = "TOKENS n/m"; PRECISION =
  "PADS n/m". REACH_GOAL = home tracker only.
- **KEEP:** the fuel gauge, `show_center`/`hide_center`/`show_match_end`/`show_match_prompt` machinery
  (only the text they receive changes).

### 8.4 Pause menu (verify, don't necessarily build)
- Confirm the pause menu (`src/ui/PauseMenu` per STATUS) offers **Restart Course** and **Quit to Menu**
  while in a TRIALS match (the P-SOFTLOCK escape hatch, §3). If a course-restart is missing, add it — it
  is the only "give up" path, since there is deliberately no auto-fail/time-out.

---

## 9. JSON MIGRATION (`levels/courses/*.json` + `levels/course_sets.json`)

The level-designer (or a one-time migration) updates course data. All changes are **field removals of now-
vestigial keys** + one metadata add. **Read-order safety:** since the code stops reading the removed keys,
leaving them in would be harmless-but-misleading; remove them so the data doesn't lie.

**Remove (vestigial — no longer read):**
- Top-level **`medal_times`** from every course (all 5 campaign + the varied set). The
  reachability/flight-required design intent in each course's `design_intent` string may KEEP its prose,
  but any medal-time sentence should be trimmed or marked historical.
- Inside `objective` blocks: **`medal_survive`**, **`medal_falls`**, **`medal_attempts`**, and
  **`score_by`** (all scoring-layer fields).

**Keep (still functional):**
- `objective.type` (the win condition selector).
- `objective.survive_seconds` (SURVIVE duration — functional target).
- `objective.reset_settle_s` (PHYSICS auto-reset delay — functional anti-softlock).
- `objective.land_speed_max`, `objective.sequence` (PRECISION skill gates — functional).
- All geometry / objects (platforms, void, start_gate, goal_gate, hazards, ball, pickups, targets).

**Add (metadata for the multiplayer scope, §1.3):**
- An optional **`"multiplayer": "parallel"`** vs **`"multiplayer": "solo"`** tag per course (or infer from
  `objective.type`: REACH_GOAL + SURVIVE ⇒ parallel; the four object-mutation types ⇒ solo). Prefer
  inferring from type in code (no new field) unless a designer wants to force a REACH_GOAL course solo.
  If character-select / setup should hide multi-player for solo-only courses, this tag (or the inferred
  rule) drives it. **This is the only additive data concept**; everything else is removal.

**`course_sets.json`:** update the `varied` set's `_comment` (it currently says "PROVISIONAL medal
thresholds — flagged for a movement-bot tuning pass" — that whole medal-tuning task is now **deleted**, not
pending). No structural change to the sets.

---

## 10. OUT OF SCOPE / FUTURE

- **Per-player instanced objects** to bring COLLECT_ALL / DESTROY_ALL / PHYSICS_PUZZLE / PRECISION_LAND
  into full multiplayer-independent play (each player their own token set / block field / ball). Named
  future pass; not this ship (§1.3).
- **Cosmetic completion stars** (no-deaths / all-tokens / flawless) — future, must stay NON-time + purely
  cosmetic + never a run-time pressure (§5).
- **Multiple `start_gate`s** for spread-out multiplayer spawns (current single-gate stack is fine for
  N ≤ ~4, §3.5).
- **Movement-bot medal tuning** (the old STATUS backlog item) — **DELETED**, not deferred: there are no
  medals to tune.
- **DO NOT** re-introduce a timer, par, medal, best-time, score, or an auto-fail/time-out under any tuning
  pressure — those are the exact things the owner removed. If courses feel too easy/hard, the knob is
  *course geometry / hazard rhythm*, never a clock.
