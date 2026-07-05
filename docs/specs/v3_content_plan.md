# v3 Content Plan — Themed Circuits (Phase 3) + First New Mode (Phase 4)

> **Spec owner:** Lead Game Designer. **Scope:** the content-breadth push toward the TowerFall
> Ascension / Duck Game bar (`docs/ROADMAP.md` Phases 3–4). Two parts:
> **A)** group the 11 shipped arenas into named circuits + name the schema change + seed new arenas;
> **B)** pick and fully spec the first new game mode.
> **Read alongside:** `docs/GAME_ESSENCE.md` (the fantasy-fit gate every part must pass),
> `docs/VISION.md` (pillars — inviolable), `docs/specs/v1_frontend_shell.md` (the `GameMode` seam +
> `MatchConfig`), `docs/specs/v1_movement_courses.md` (the course design this mode productizes),
> `docs/reference/FEEL_REFERENCE.md` (feel numbers). **No code here** — a build-ready design contract.
>
> **Fence:** nothing in this plan touches a feel/lethality constant in `src/core/Tuning.gd`. Circuits
> are pure data grouping; the new arenas are geometry + reused primitives; the new mode is a seam
> implementation + new presentation/entity pieces. Any change here that would edit a fenced Tuning
> constant is out of scope and must be escalated, not silently done.

---

# PART A — Phase 3: Themed Circuits

## A.0 What a circuit is (the design contract)

A **circuit** is a curated, *ordered* rotation of arenas with a shared visual/tonal identity and a
deliberate **difficulty arc** (gentle → punishing), exactly like TowerFall's arena sets. Where
`RANDOM_ALL` shuffles the whole pool with no shape or theme discipline, a circuit is authored: you
know the first arena welcomes new players and the last one is the wringer. Circuits are how a couch
group says "let's play the *easy* set" vs "run the gauntlet," and how the game teaches its kill-shape
vocabulary in a sane order.

All 11 arenas currently share the JSON `theme: "grass"` but each has a **distinct sky palette and a
distinct kill-shape** (the real differentiator). The circuits below are grouped by **kill-shape
family + mechanical demand + recovery difficulty**, not by the (uniform) theme tag.

Difficulty here means, concretely: **how forgiving is recovery** (landing runway width, recovery-sky
depth), **how much timing/mechanic overhead** sits on top of the base fly-across-gaps loop, and
**how self-fall-prone** the geometry is (per each arena's own QA notes on uncredited self-falls).

## A.1 The three circuits

### Circuit 1 — **MEADOW MILE**  (the on-ramp · fundamentals · ★☆☆)
*Bright, open, horizontal daylight arenas that teach the pure loop: fly across a gap, smash a rival
off the edge, recover with fuel. Forgiving landing runway everywhere. This is the "just start"
circuit and the default for new groups.*

| # | Arena | Kill-shape | Why it's here / arc role |
|---|---|---|---|
| 1 | `grassy_expanse` | `central_pit` | **Gentlest teacher.** The only arena with a solid standable-width floor and the *edges* as the primary blast; the central pit is a demoted minority hazard. New players learn "get knocked off the side = death" with a big safe mid-zone to breathe. Muted grey-blue morning. |
| 2 | `islands_void` | `void_is_floor` | **The flagship.** Even, mirror-balanced archipelago of four wide 960px islands over one void — forgiving landing pads, clear gaps. Teaches "the void under everything is the floor" without punishing whiffs. Cyan day sky. |
| 3 | `the_cliff` | `void_is_floor` | **First asymmetry.** A wide safe mesa on the left vs a scatter of pads over void on the right — introduces committing outward over the maw to contest a prize, with the mesa as a fallback. Bright morning. |
| 4 | `twin_chasms` | `void_is_floor` (twin) | **Circuit capstone.** Two chasms + a hot-seat centre island: knocks send you LEFT or RIGHT, deaths split across two maws. Ramps tension without new mechanics. Golden-dusk palette closes the "day arc." |

**Kill-shape variety:** central-pit → symmetric archipelago → asymmetric mesa/scatter → multi-void.
Four *distinct spatial reads*, all in the "fly the gaps, smash off the edge" family. **Visual arc:**
grey morning → cyan day → bright morning → golden dusk (a loose day-cycle, a nice couch touch).

### Circuit 2 — **THE SCRAPWORKS**  (the trick-shop · mechanics & hazards · ★★☆)
*Every arena here layers a NEW interaction on top of the base loop: elastic reflectors, an enclosed
inverse arena, moving hazards, a lethal ceiling. Darker, industrial, arcade-neon tones. This is the
"we know how to fly, now mess with us" circuit.*

| # | Arena | Kill-shape | Why it's here / arc role |
|---|---|---|---|
| 1 | `bumper_gauntlet` | `void_is_floor` + bumpers | **Gentlest mechanic entry.** Wide islands (forgiving) studded with free-standing elastic bumpers — teaches "nothing flies straight; a missed super can carom into a kill" while recovery stays easy. Arcade violet. |
| 2 | `drop_chamber` | `enclosed_hole` | **The inverse.** An enclosed bumper drum where the *edges save you* and the *centre hole kills* — the deliberate opposite of every void arena. Bumpers make it forgiving while the brain re-learns the polarity. Dark drum interior. |
| 3 | `wrecking_yard` | `void_is_floor` + moving hazard | **Timing layer.** Two anti-phase pendulum wrecking balls over the two crossing gaps: cross on the clear beat or get flung into the void. Adds rhythm/timing to the flight loop. Smoggy industrial. |
| 4 | `the_ascent` | `dual_blast` | **Circuit capstone.** The only up-OR-down arena: climb a walled shaft toward a LOW lethal lid over a void, bumper walls remove the side escape. Hardest mechanic (a whole new lethal axis). Dark shaft. |

**Kill-shape variety:** the widest spread in the game — bumper-studded void, enclosed-hole, moving-
hazard void, and the unique dual-blast. Each teaches a *different rule*, not a different room.

### Circuit 3 — **THE HIGH WIRE**  (the gauntlet · exposure & mastery · ★★★)
*The most exposed, most vertical, hardest-recovery arenas. Minimal safe runway, deep voids, punishing
whiffs. This is the "prove you've mastered fly + recover" circuit — for players who've cleared the
first two. High-sky palettes, everything hangs over the abyss.*

| # | Arena | Kill-shape | Why it's here / arc role |
|---|---|---|---|
| 1 | `atoll` | `void_is_floor` (radial) | **Entry to mastery tier.** The only RADIAL layout — a ring of platforms around a central well; fight *around* the crater and knock rivals in or off the outer rim. Medium-hard: wrapping traversal demands confident boosting. Teal. |
| 2 | `the_spine` | `void_is_floor` (thin ridge) | **Max exposure.** One thin ridge over a void on all sides, two perches at the very brink. Almost no safe interior — the recovery gamble IS the whole level. Deep-blue high sky. |
| 3 | `spires` | `void_is_floor` (extreme vertical) | **The wringer / final boss arena.** Six sky-pillar tops in a sawtooth of heights over the deepest void; every move is a committed diagonal boost, self-falls are highest by design. The hardest arena in the game closes the circuit. |

**Kill-shape variety:** radial-in/out → linear thin-ridge → extreme-vertical sky-pillars. All
`void_is_floor` but spatially maximally distinct (radial vs line vs vertical field) — the family's
three hardest expressions.

**Why 4/4/3 and not 6/5:** three circuits give three legible identities and three clean difficulty
arcs (couch players pick by vibe + spice level). Two big sets would blur the teaching order. If the
roster later grows, `bumper_gauntlet`↔`atoll` are the two arenas that could move a tier without
breaking their circuit's arc (both are "medium" swing picks).

## A.2 Schema change to support `CIRCUIT` as an arena mode (minimal)

The plumbing is 90% done: `MatchConfig.ArenaMode` **already reserves `CIRCUIT = 2`** and
`BrawlMode.configure()` already branches on `arena_mode` to build `_pool`. Three tiny additions
complete it — **no runner rewrite, no new system:**

1. **One new `MatchConfig` field** (`src/core/MatchConfig.gd`):
   `@export var circuit_id: StringName = &""` — which circuit to run when `arena_mode == CIRCUIT`.
   (Mirrors how `single_arena_path` qualifies `SINGLE`.)

2. **Circuits as DATA, not code** (per CLAUDE.md "levels are data, never hardcoded"):
   a new file **`levels/circuits.json`** — an ordered manifest:
   ```
   {
     "meadow_mile":  { "display_name": "MEADOW MILE",  "difficulty": 1,
       "levels": ["grassy_expanse","islands_void","the_cliff","twin_chasms"] },
     "scrapworks":   { "display_name": "THE SCRAPWORKS", "difficulty": 2,
       "levels": ["bumper_gauntlet","drop_chamber","wrecking_yard","the_ascent"] },
     "high_wire":    { "display_name": "THE HIGH WIRE",  "difficulty": 3,
       "levels": ["atoll","the_spine","spires"] }
   }
   ```
   (Level ids resolve to `res://levels/<id>.json` the same way `LEVEL_POOL` entries do today.)

3. **`BrawlMode.configure()` gains one branch** (design intent — programmer implements):
   when `config.arena_mode == CIRCUIT`, load `circuits.json`, look up `config.circuit_id`, and set
   `_pool` to that ordered `levels` list. **Crucially, a circuit plays its arenas in AUTHORED ORDER,
   looping** — NOT the shuffle-bag `RANDOM_ALL`/`SINGLE` use — so the difficulty arc is actually
   experienced. Minimal way to express this without touching the state machine: add a private
   `_ordered: bool` (true for CIRCUIT) and an index; `next_level_path()` draws sequentially and wraps
   when `_ordered`, else keeps today's shuffle-bag behavior. This lives entirely inside `BrawlMode`
   (or any future mode) — the runner is untouched. Unknown/empty `circuit_id` → fall back to
   `RANDOM_ALL` and log (never crash).

**ArenaSelect wiring** (`scenes/ui/ArenaSelect.tscn`, per `v1_frontend_shell.md` §1.1): the grid
today shows "RANDOM ROTATION" + 11 arena cards. Add **three circuit cards at the front of the grid**
(one per `circuits.json` entry, showing `display_name` + a ★ difficulty rating + its member count).
Selecting a circuit card writes `arena_mode = CIRCUIT` + `circuit_id = <key>`; the existing arena
cards keep writing `SINGLE` + `single_arena_path`; "RANDOM ROTATION" keeps writing `RANDOM_ALL`. No
new screen, no new nav — just more cards in the existing grid. Default focus can shift to the first
circuit card (MEADOW MILE) so the recommended on-ramp is one press away, with RANDOM ROTATION still
present for the "surprise us" group.

**QA success criteria (Phase 3):**
- **CIR1** Selecting MEADOW MILE and launching plays `grassy_expanse → islands_void → the_cliff →
  twin_chasms` in that exact order across stages (gbplay `eval` on `level_name` per stage), looping
  to `grassy_expanse` on stage 5 — proves ordered, not shuffled.
- **CIR2** Each circuit card sets `arena_mode == CIRCUIT` and the correct `circuit_id` (eval on
  `GameConfig.match`), and a full match runs to `MATCH_END` with no crash across all three circuits.
- **CIR3** Parity untouched: `RANDOM_ALL` (default) and `SINGLE` behave byte-for-byte as before
  (`v1_frontend_shell` C7 still passes); an empty/unknown `circuit_id` falls back to `RANDOM_ALL`.
- **CIR4** Every arena in every circuit still passes its own kill-shape criterion (K1'/DC1/AS1/etc.)
  — circuits are grouping only; they do not alter arena behavior.

## A.3 Three new arenas to round out the circuits (concept + kill-shape only)

Not full layouts — seeds for the level designer. Each **reuses an already-proven primitive** (so the
programmer owns zero new feasibility) and fills a specific gap in its circuit.

1. **THE PADDOCK** → *MEADOW MILE, slot it FIRST (before grassy_expanse) as the true tutorial arena.*
   **Kill-shape:** `void_is_floor` (symmetric twin-island). **Concept:** two wide, low, mirror-image
   trampoline islands over a single central void with one modest flight-required gap and low bounce
   shoulders on the outer edges. The gentlest possible "fly one gap, smash them off, recover"
   statement — ideal 1v1 and first-timer arena. **Reuses:** the flagship islands-over-void geometry +
   `pit_void_rendering`; nothing new. *Gap fills:* MEADOW MILE currently opens on `grassy_expanse`'s
   solid floor; THE PADDOCK adds an even softer *void-floor* primer so the void-is-floor idea is
   introduced with maximum forgiveness.

2. **THE GRINDER** → *THE SCRAPWORKS, slot between wrecking_yard and the_ascent.*
   **Kill-shape:** `enclosed_hole` (drop_chamber's class) **+ moving hazard.** **Concept:** an
   enclosed bumper drum like `drop_chamber` (edges + lid save, centre hole kills) but with a single
   MovingHazard sweeping *laterally* across the floor shelves, nudging players toward the central
   mouth on a readable beat. Marries the circuit's two signatures (enclosure + timing) into one
   escalation. **Reuses:** `drop_chamber`'s bumper-wall/lid enclosure + `wrecking_yard`'s
   `MovingHazard` directional shover (both shipped, both fenced-safe: shove ≤ 700px/s, no hitstun,
   never a killer id). Nothing new. *Gap fills:* gives SCRAPWORKS a second enclosed arena and a second
   moving-parts arena without repeating either exactly.

3. **THE GYRE** → *THE HIGH WIRE, slot between atoll and the_spine.*
   **Kill-shape:** `void_is_floor` (radial + vertical). **Concept:** a radial ring like `atoll` but
   with the rim platforms set at a **sawtooth of heights** (atoll × spires) — you wrap AND climb
   around a central well, every neighbour a diagonal boost up-or-down-and-across. Adds verticality to
   the radial read. **Reuses:** the islands-over-void static geometry + `pit_void_rendering` (exactly
   `atoll`/`spires`' primitive). Nothing new. *Gap fills:* HIGH WIRE has 3 arenas; THE GYRE brings it
   to 4 (matching the other circuits) and bridges atoll's radial and spires' verticality.

(All three are **geometry + reused-primitive** authoring tasks that must pass a movement-tool-per-gap
flight-required proof and their kill-shape QA before shipping, per `GAME_ESSENCE.md` and
`v1_level_circuit.md` §6. No feel constant is touched.)

---

# PART B — Phase 4: First New Game Mode

## B.0 Evaluation of the four candidates

Scored on the three axes the task defines. Scale: ★☆☆ weak → ★★★ strong.

| Candidate | (1) Showcases the MOVEMENT (the product) | (2) Feasibility (reuse Player/bots/arenas/seam, minimal NEW mechanics) | (3) Genuinely-new play added |
|---|---|---|---|
| **Trials / Time-Attack** | **★★★** Pure, isolated movement mastery — bounce/fly/recover with *zero combat noise*; the super becomes a traversal tool. It is *nothing but* the product. | **★★★** Reuses Player + arenas-as-courses + the seam. NO bots (the risky/expensive part) and NO new physics or combat balance. New pieces are tiny: a goal gate, a timer HUD, medal thresholds. Prior art already spec'd (`v1_movement_courses.md`). | **★★☆** A solo self-vs-clock mastery loop (medals, ghosts later) — a genuinely different *framing* and retention/practice layer, though it adds framing more than new mechanics. |
| **Gauntlet / Survival vs waves** | **★★☆** Full fly+smash combat, on-theme — but it *re-uses BRAWL's verbs* rather than showing movement in a new light; it's "BRAWL vs bots" flavored. | **★★☆** Reuses everything, but needs a WAVE director, difficulty scaling, wave pacing, and possibly co-op input — the balance-heavy, bot-fun-as-*enemies* work is the expensive, risky part. | **★★★** Solo/co-op PvE is the VISION retention layer and highly replayable — but it's the biggest, riskiest build. |
| **Sports / bounce-ball** | **★★★** Movement is the whole game (position to strike the ball) — "movement as the entire loop." | **★☆☆** Needs a BALL entity with its own physics + player↔ball smash-transfer tuning + goals/scoring/reset + teams. That ball-interaction physics is the most genuinely-NEW mechanic set and the most tuning risk (course 4 in `v1_movement_courses.md` is only its seed). | **★★★** Totally new, very high replay — but highest new-mechanic cost. |
| **Puzzle / clear-the-room** | **★☆☆** Single-screen "solve it" risks *contradicting* the fantasy — "distances require flight" (GAME_ESSENCE) and "constant motion, no camping" (Pillar 2) fight a stand-and-think room. | **★★☆** Needs bespoke puzzle entities (targets/switches/breakables) + per-room win logic + lots of hand-authored rooms. | **★★☆** New play, but **tonally OFF** — a slow puzzle is the weakest fantasy fit for a frantic bouncer. |

## B.1 Recommendation: **TRIALS / TIME-ATTACK — build this first.**

Trials wins on axes 1 + 2 decisively and is the lowest-risk way to prove the seam scales to a
*radically different ruleset*. **Justification (one paragraph):** the owner's north star is that
*movement feel IS the product* — Trials is the only mode that is **nothing but** movement feel, with
combat, bots, and balance stripped away so the bounce→fly→recover core is the entire experience and
the entire reward ("I just did something HARD and it felt amazing"). It reuses the shipped Player and
the existing arenas-as-courses, needs **zero new physics and zero combat-balance work** (the parts
that carry real risk), touches **no fenced Tuning constant**, and is already 80% designed in
`v1_movement_courses.md` (five courses, pass/fail scripts, and the exact feel-instrument rationale) —
this spec productizes that draft behind the Phase-1 `GameMode` seam. It also proves the seam handles a
win-condition (**reach a goal before the clock / beat par**) with *no kill-race and no last-one-
standing*, which is the strongest possible demonstration that BRAWL isn't secretly hardcoded into the
runner. As a bonus it becomes a **permanent movement-feel regression harness** (rerun the course
battery after any movement-touching commit) and the onboarding/practice layer — build once, use three
times. Sports and Gauntlet are better *second/third* modes (Sports reuses Trials' eventual ball prop;
Gauntlet reuses Trials' proof that PvE win-conditions work through the seam); Puzzle is deprioritized
on fantasy-fit grounds.

## B.2 `TrialsMode` — the `GameMode` contract implementation

`src/modes/TrialsMode.gd` (`class_name TrialsMode extends GameMode`), registered as
`{"trials": TrialsMode}` in the runner's mode registry alongside `{"brawl": BrawlMode}`. It fills the
**same 11 seam methods** BRAWL does — **no `PartyMatch` rewrite**. Player fantasy, pillar check, and
the course roster are inherited from `v1_movement_courses.md`; this section is the seam mapping.

| Seam method | TrialsMode behavior |
|---|---|
| `id()` | `&"trials"` |
| `display_name()` | `"TRIALS"` |
| `hud_scene()` | a **new `scenes/ui/TrialsHUD.tscn`** (see B.3) — big run timer, current-course medal pips, par/best split, fuel gauge, attempt counter. NOT `MatchHUD`. |
| `configure(runner, config)` | Solo tuning: set `runner.lives_per_player` **high (e.g. 99)** so a void-fall is a *respawn*, not a match loss (reuses the runner's existing `respawn_delay`/multi-life respawn — see B.4). Set the "target" so the runner never ends the match on kill-count. Build the course sequence: reuse the **CIRCUIT ordered-pool mechanism from Part A** (a Trials "course set" is an ordered `circuits.json`-style list of course level ids) — `_pool` = the ordered course list, `_ordered = true`, played once (no loop: the match ends after the last course, see `match_winner`). |
| `spawn_plan(runner, config)` | **Humans only, NO bots.** One descriptor per local human (`human: true, team: 0, seed_damage: 0`, skin/character from config); `bot_count` forced to 0. v1 = 1 human (solo). A 2–4 human "hot-seat race / shared-screen race" is a v2 flag, same spawn_plan with more humans. |
| `next_level_path(runner)` | Return the next course in authored order (the ordered draw from `configure`'s `_pool`). When the last course is consumed, the match is over (handled via `match_winner`); return `""` or the final course path — the runner will not advance past a satisfied `match_winner`. |
| `is_stage_over(runner)` | **TRUE when the human touches the course GOAL gate** (course cleared) — NOT last-one-standing. (Optional hardcore variant: also true if a per-course fail-cap timer is exceeded; v1 omits the cap — you retry until you clear, matching `v1_movement_courses.md`'s "only rest state is death/reset.") A void-fall does NOT satisfy this (it triggers a respawn, B.4). |
| `on_kill(runner, killer, victim, cause)` | **No kill-race scoring.** A "death" here = the human fell out of bounds. TrialsMode records a **time penalty** onto its own run clock (design value: **+2.0s per fall**, rationale below) and increments an attempt counter; it does NOT mutate `runner.scores`. (killer is always -1 / self — there are no rivals.) |
| `match_winner(runner)` | Return **player 0** once the LAST course's goal has been cleared (the whole set is complete → match ends cleanly). Return **-1** while courses remain. For the v2 multi-human race: return the human with the lowest **total** time when all have finished / a leader is decided. |
| `stage_end_banner(runner)` | `{text: "COURSE CLEAR!  %.1fs — %s" % [course_time, medal], color: medal_color}` — the per-course result + medal earned (GOLD/SILVER/BRONZE/—). |
| `match_end_banner(runner)` | `{text: "TRIALS COMPLETE!", color: gold, subline: "Total %.1fs   %dx GOLD  %dx SILVER" % [...]}` — the set summary. |

**Explicitly reused runner plumbing (unchanged):** STAGE_INTRO/COUNTDOWN pop-in, camera, the level
loader + `pit_void_rendering`, squash/stretch + juice, name tags (single tag), the powerup director
(disabled for Trials via zero powerup spawners in course JSON — no new toggle needed), and the
multi-life respawn path (B.4). Sudden-death never triggers (its double-KO condition can't occur with
one non-combat player). **No fenced Tuning constant is read or written.**

## B.3 New pieces this mode needs (the whole list)

**Entities / level objects** (JSON `objects[]`, extends the loader — align with `v1_movement_courses.md` §1):
- `{ "type": "goal_gate", "x", "y", "w", "h" }` — an `Area2D` sensing the player on its own layer;
  overlap → sets a runner-readable flag `runner.trials_goal_reached = true` that `is_stage_over`
  polls. (Same pattern as `MovingHazard`/`void` areas — no new system.)
- `{ "type": "start_gate", "x", "y" }` — the spawn + respawn point; the run timer starts on the
  human's first input (reuse the existing input-detection the idle_hunt clock already uses).
- **(v2, deferred)** `{ "type": "checkpoint", "x", "y", "w", "h" }` — moves the respawn point mid-
  course; and `{ "type": "collectible_ring" }` to force a movement line. v1 respawns at start (B.4).

**Level data / new fields** on course JSONs (`levels/courses/course_XX_name.json`):
- `"mode": "trials"` (informational), plus the `goal_gate` + `start_gate` objects above.
- `"medal_times": { "gold": <s>, "silver": <s>, "bronze": <s> }` — the run-time thresholds.
- Courses are **new authored level files**, NOT the brawl arenas (a course is a directed A→B movement
  challenge — Tank Run / Chimney / Bank Shot from `v1_movement_courses.md` — not a symmetric arena).
  Ship courses 1–3 first (they need no ball prop); courses 4–5 are the Sports-mode seed, deferred.
- **NOTE on FEEL_REFERENCE numbers:** `v1_movement_courses.md` was authored against the *old*
  FEEL_REFERENCE start values (e.g. trampoline apex 640, super 1400). The SHIPPED `Tuning.gd` differs
  (trampoline apex **270**, spring **480**, `normal_boost_max_speed` **760**, `super_boost_impulse_full`
  **2800**, `air_drift_max` **340**). **Re-derive each course's gaps/heights/medal_times against the
  CURRENT constants** before authoring — e.g. a normal boost crosses ~580–680px in ≈0.9s (the value
  every shipped arena is tuned to), so course legs should be sized off that, and a straight-up full
  super rises ~2450px (`2800²/(2·1600)`), which sets the Chimney's "too tall to fly" height. The
  courses are the *feel instrument* (`v1_movement_courses.md` §2–3); their numbers are geometry, not
  fenced feel constants.

**UI:**
- `scenes/ui/TrialsHUD.tscn` + `src/ui/TrialsHUD.gd` (built as .tscn + `theme.tres`, per CLAUDE.md):
  big centered run timer, medal pips for the course set, current/par/best split line, fuel gauge,
  attempt counter, and a "RETRY (R)" affordance on the clear/fail banner.
- **ModeSelect:** the **TRIALS card already exists as a "COMING SOON" placeholder** (`v1_frontend_shell`
  §1.1) — enable it. Selecting it routes to a **Trials course-select** that reuses the ArenaSelect
  grid layout (Part A) to list course *sets* (and, later, per-course best times + earned medals).
- Registry entry `{"trials": TrialsMode}`; a `MatchConfig` used by Trials sets `mode_id = &"trials"`,
  `human_count = 1`, `bot_count = 0`, `arena_mode = CIRCUIT` with a Trials course-set id, and
  `lives_per_player` high.

**Runner-side (confirm, do not rewrite):** the ONE thing TrialsMode leans on that isn't a pure seam
call is the **multi-life respawn** — see B.4.

## B.4 The one integration point to de-risk first (respawn-on-fall)

Trials needs "fall out of bounds → respawn and keep going," not "eliminated." This is **already in the
runner**: `Tuning.respawn_delay = 1.0` exists and is documented as "only used when
`lives_per_player > 1`" — i.e. the runner respawns a player who dies with lives remaining. TrialsMode
sets `lives_per_player` high, so each fall consumes a life and the runner respawns the single human
(at the spawn point) while `is_stage_over` stays false (goal not yet reached). **Reuse this path;
build nothing new for v1.** The two things the programmer must *confirm* (not build) up front, because
they're the only assumptions that could bite:
1. The multi-life respawn fires **independently of `is_stage_over`** (a lone living player who dies
   with lives left is re-spawned rather than the stage ending) — verify with a driven fall.
2. Respawn uses the **`start_gate`/`player_spawn`** position, and refills fuel on respawn (Trials
   wants a clean retry). If it doesn't refill, that's a one-line respawn addition, still not a rewrite.
If either assumption is false, the fix is a *small* additive hook (a `mode.on_player_out()` seam
returning "respawn" vs "eliminate"), NOT a runner rewrite — flag it, don't work around it. **Build
this integration slice FIRST** (B.6 step 1) so any surprise surfaces before course authoring.

## B.5 Measurable success criteria (QA drives rendered; movement-first)

- **T1 Reachability:** From the shell, ModeSelect→TRIALS→course-select→a course launches to live play
  with the TrialsHUD timer visible at ~0 (gbplay screenshot + `eval` on `state`).
- **T2 Win-condition through the seam:** Touching the `goal_gate` fires `is_stage_over`, freezes the
  clock, and shows COURSE CLEAR + a medal; driving a known-good line clears course 1 within its
  authored **gold** time (`eval` on the course-clear time). Proves a non-kill-race win-con works.
- **T3 Flight-required (the FANTASY gate — GAME_ESSENCE):** each course is **impossible without
  boosting** — a zero-boost / fuel-pinned driven attempt fails to reach the goal (falls short/out)
  ≥9/10, and every real clear logs ≥1 boost activation. (Reuses each course's F-script from
  `v1_movement_courses.md`; the F-scripts are load-bearing — they prove the course tests movement.)
- **T4 Death→respawn, not match-end:** a driven void-fall respawns the human at start, adds the +2.0s
  penalty to the run clock and ticks the attempt counter, and the run **continues**; N falls in a row
  never end the match early (`eval` on attempt count + `state` still in play).
- **T5 No combat / solo:** `players.size() == human_count` (no bots), `runner.scores` untouched by
  play, sudden-death never triggers, no kill banner ever shows.
- **T6 Medals:** driving three quality tiers of a line yields bronze / silver / gold correctly per the
  course's `medal_times`.
- **T7 Seam parity — no runner rewrite:** BRAWL still passes `v1_frontend_shell` **C7** verbatim after
  TrialsMode lands (Trials added ONLY via the registry + the new mode class + new HUD/entities). Parse
  gate clean (`--headless --editor --quit`, no Parse Error / hides-a-native / Failed-to-load).
- **T8 Motion-health (per GAME_ESSENCE — validate MOTION, not just the clear):** a driven full course
  shows a high continuous **airborne fraction** (a course is nothing but bounce/fly/recover) and
  **zero locomotion pathologies** in the motion probe (no `stuck_episodes`, no `underside_bounces`
  head-banging, no jitter) — a clear that only happened via a motion pathology is a FAIL even if T2
  passes.
- **T9 Battery cheapness (regression-harness value):** the courses-1–3 P+F script battery runs
  headless-driven in ≤10 min wall-clock, so it can gate every future movement-touching commit.
- **T10 No-widget / looks-like-the-game:** TrialsHUD screenshots use `theme.tres` (no OS-default
  labels/bars), goal gate is a single high-contrast readable ring/gate at full-course zoom (Pillar 5).

## B.6 De-risked build order (depth-first)

1. **Prove the respawn integration (B.4) with BRAWL data + one throwaway course** before anything
   else — set `lives_per_player` high on a single-player config, drive a fall, confirm respawn-not-
   elimination. This is the only unknown; surface it first. (T4 skeleton.)
2. **`TrialsMode` seam class + registry entry** with a HARDCODED single course; make `is_stage_over`
   fire on a temporary goal condition and `match_winner` end the match. Prove the seam runs a non-
   kill-race match end-to-end. Re-run BRAWL **C7** to prove parity (T7).
3. **`goal_gate` + `start_gate` level objects** in the loader; wire the real goal flag + run timer.
   (T2.)
4. **`TrialsHUD.tscn`** (timer / fuel / attempts / medal pips) built to theme. (T1, T10.)
5. **Author courses 1–3** (`Tank Run` / `Chimney` / `Bank Shot` from `v1_movement_courses.md`),
   **re-derived against CURRENT Tuning** (B.3 note), with `medal_times` and P/F scripts. (T2, T3, T6,
   T9.)
6. **Course-select** (enable the ModeSelect card + reuse the ArenaSelect grid for course sets), then a
   **rendered playtest + CD fantasy-fit verdict** — the mode must feel like *"I did something HARD and
   it felt amazing"* (`v1_movement_courses.md` fantasy) and pass the T8 motion-health read, not just
   the green criteria.
7. **Backlog (post-v1):** checkpoints + ghost replays, the multi-human race variant, medal/unlock
   economy (Phase 5), and courses 4–5 — which are the **Sports-mode seed** (the ball prop). Building
   course 4 IS starting the second new mode; spec it as such when we get there.

---

## Summary (the asks answered)

- **Circuit groupings:** **MEADOW MILE** (`grassy_expanse`, `islands_void`, `the_cliff`,
  `twin_chasms` — fundamentals, ★☆☆) · **THE SCRAPWORKS** (`bumper_gauntlet`, `drop_chamber`,
  `wrecking_yard`, `the_ascent` — mechanics/hazards, ★★☆) · **THE HIGH WIRE** (`atoll`, `the_spine`,
  `spires` — exposure/mastery, ★★★).
- **Schema change:** add `MatchConfig.circuit_id`, a data-driven `levels/circuits.json`, and one
  ordered-pool branch in `BrawlMode.configure()`/`next_level_path()` (CIRCUIT plays authored order,
  looping). ArenaSelect gains three circuit cards. No runner rewrite.
- **New arenas:** THE PADDOCK (Meadow Mile, symmetric twin-island `void_is_floor`), THE GRINDER
  (Scrapworks, `enclosed_hole` + moving hazard), THE GYRE (High Wire, radial-vertical `void_is_floor`)
  — each reuses a shipped primitive.
- **First new mode:** **TRIALS / TIME-ATTACK** — strongest on movement-showcase + feasibility, lowest
  risk, proves the seam with a non-kill-race win-condition, and is the mode that is *nothing but* the
  product. Contract mapped across all 11 seam methods; new pieces = `goal_gate`/`start_gate` objects,
  `TrialsHUD.tscn`, course JSONs with `medal_times`, and a registry entry. One integration point to
  de-risk first: respawn-on-fall via the existing multi-life path. No fenced feel constant is touched.
