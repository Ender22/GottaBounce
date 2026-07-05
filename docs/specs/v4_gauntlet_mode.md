# v4 — GAUNTLET Mode (survival vs escalating waves) — the SECOND new GameMode

> **Spec owner:** Lead Game Designer. **Scope:** the third mode overall (after BRAWL and TRIALS),
> the first PvE *survival* mode. Built conservatively on the proven `GameMode` seam, REUSING Player,
> InputBot (existing levels 1–5), the shipped arenas, the kill pipeline, and the multi-life respawn.
> **Read alongside:** `docs/GAME_ESSENCE.md` (the fantasy-fit gate), `docs/VISION.md` (pillars —
> inviolable), `docs/specs/v3_content_plan.md` PART B (the TRIALS contract this mirrors), and the
> code seams: `src/modes/GameMode.gd`, `src/modes/BrawlMode.gd`, `src/modes/TrialsMode.gd`,
> `src/modes/PartyMatch.gd` (the runner), `src/core/InputBot.gd`, `src/core/BotProfile.gd`,
> `src/core/MatchConfig.gd`.
>
> **Fence:** GAUNTLET touches **NO** feel/lethality constant in `src/core/Tuning.gd`. Every new number
> (defender life pool, wave counts, bot levels, the concurrency cap) is mode-owned DATA or reuses
> existing `BotProfile` tiers. Any change that would edit a fenced constant is out of scope — escalate.
>
> **The win in one line:** *waves of the bots we already have, on the arenas we already have, scored by
> survival.* The only genuinely-new runner capability is a **dynamic per-wave bot roster** (bots that
> spawn/despawn BETWEEN waves), which no existing seam expresses. This spec adds exactly **one** additive
> runner hook for it (`wave_spawn_plan()`), in the same minimal spirit as the single `polls_goal()` hook
> TRIALS added — a no-op for BRAWL and TRIALS, so both keep byte-for-byte parity.

---

## 0. Player fantasy + core-verb exercise (GAME_ESSENCE obligation)

**Fantasy:** *"They keep coming, and I keep flying."* You are the last flier holding an arena against
a rising tide of jetpack attackers. You don't turtle — you **fly into them and smash them off the
edge**, weave your recovery out of a three-bot pile-on, refuel on the bounce, and do it again as the
tide gets bigger and meaner. It is BRAWL's verbs turned into a **solo/co-op endurance stage** with a
climbing pressure curve and a "how far did we get?" score.

**Core verbs exercised** (all four, under escalating pressure):
1. **BOUNCE** — you never settle; refuel-on-bounce rhythm is survival.
2. **FLY/BOOST** — the arenas are the shipped flight-required ones; you cross gaps to engage/disengage.
3. **SUPER-SMASH** — the *primary clear tool*: knock attackers into the void. Waves are cleared by
   **smashing**, not out-attrition-ing. (This is the anti-bullet-hell, anti-turtle lever — see §4.)
4. **RECOVER** — being knocked toward the edge by a swarm and clawing back IS the moment-to-moment
   tension; the recovery gamble happens constantly.

**Fantasy-fit gate (must pass, not just the green criteria):** a wave must be cleared by a defender who
is *airborne and smashing*, not one hiding in a corner while bots ring each other out. §4 + §5 make
that a MEASURED number (G9, G-BOTFOCUS), not an eyeball.

**Pillar check:** Low-floor/high-ceiling (survive early waves by flailing, master late waves) ✔; Constant
motion — no standable ground on any shipped arena, idle-hunt already swarms a camper ✔; Emergent comedy
— multi-bot ragdoll pile-ups ✔; Death is cheap — respawn-on-death from a shared pool ✔; Readable chaos —
concurrency capped (§3) so a storm stays trackable ✔; Personality — reuses all juice ✔. **No pillar is
bent.** No standable safe perch is introduced (would violate Pillar 2 and trivialize the mode).

---

## 1. Core loop

```
   MODE SELECT ──► GAUNTLET
        │
        ▼
   WAVE 1  ──(STAGE_INTRO pop-in + "WAVE 1" + 3-2-1-BOUNCE!)──►  COMBAT
        │                                                          │
        │   defenders fly/smash; bots hunt the defenders           │
        │   attacker down ──► enemies-remaining --                 │
        │                                                          ▼
        │                                              all wave bots eliminated?
        │                                       ┌──────────── yes ─────────────┐
        │                                       ▼                              │
        │                             "WAVE N CLEARED!" freeze (breather)      │
        │                                       │                              │
        │              was that the FINAL wave? ─┴─ no ──► WAVE N+1 (more/tougher bots)
        │                                       │
        │                                      yes
        │                                       ▼
        │                              VICTORY — "ALL WAVES CLEARED"
        ▼
   a defender goes down with the shared life pool EMPTY  ──►  DEFEAT — "OVERWHELMED AT WAVE N"
                                                              (score = highest wave reached)
```

### 1.1 Wave composition (count + scaling)
Waves are **DATA** (`levels/gauntlet_waves.json`, §3), mirroring `circuits.json` / `course_sets.json`.
A wave is an explicit list of **bot levels** (reusing `BotProfile.for_level`, 1..5), so `count` and
per-bot difficulty are both authored. Recommended v1 "campaign" ramp (8 waves, a curated arc, NOT
endless — a finite gauntlet has a designable climax, is testable, and matches VISION's "challenge
gauntlets + bosses" retention framing; endless is a v2 modifier):

| Wave | Bots (levels) | Concurrent | Role in the arc |
|------|---------------|-----------|-----------------|
| 1 | `[1,1]` | 2 | On-ramp: two flailing L1 fodder — learn to smash-clear. |
| 2 | `[2,2,1]` | 3 | First real pressure; still comedic. |
| 3 | `[2,3,2]` | 3 | An L3 that actually leads its shots appears. |
| 4 | `[3,3,2,2]` | 4 | Count bump — now you must manage a crowd. |
| 5 | `[3,4,3,2]` | 4 | First L4 (edge-guard + dodge-super) — a genuine threat. |
| 6 | `[4,3,3,3,2]` | 5 | Concurrency ceiling (see §3 cap) — peak crowd. |
| 7 | `[4,4,3,3,3]` | 5 | Two L4s coordinate the finish. |
| 8 | `[5,4,4,4]` | 4 | **Elite finale:** fewer but scary (one L5 menace). |

**Scaling shape:** count ramps 2→5 then *tightens* for the finale (fewer, deadlier) so wave 8 reads as a
boss beat, not just "more". Levels ramp 1→5. Concurrency never exceeds **5 bots** (§3). The ramp is
monotonic in threat, not strictly in count — the finale trades count for quality (a movement/skill test,
not a swarm-attrition wall).

### 1.2 Wave clear condition
**All of the wave's bot attackers are eliminated** (each attacker has effectively 1 life — see §2
`on_kill`). Detected by the mode's `is_stage_over()` = *no not-eliminated bots remain*, polled every
combat frame via `polls_goal()` (so it also fires cleanly in co-op where 2+ humans survive the last
bot — the exact case the death-driven path can't catch; see §2).

### 1.3 Between-wave beat (breather + banner) — 100% reused runner machinery
A wave IS a runner **stage**. Clearing a wave runs the existing state flow with ZERO new runner beats:
- **STAGE_END** freeze (`Tuning.round_end_freeze`) with a `stage_end_banner()` = `"WAVE N CLEARED!"` —
  the breather.
- **STAGE_INTRO** staggered pop-in with name tags (free presentation for the new wave's bots) +
  **COUNTDOWN** "3 · 2 · 1 · BOUNCE!" — the re-arming beat.
- The big **"WAVE N"** announcement is drawn by GauntletHUD (it reads `mode.current_wave()` and
  `runner.state`, shows the banner during STAGE_INTRO/COUNTDOWN) — **no new runner hook** for it.

So the "brief breather + WAVE N banner" is entirely the STAGE_END→STAGE_INTRO→COUNTDOWN path already in
`PartyMatch`. GAUNTLET adds no new lifecycle state.

### 1.4 Lose condition + life economy (DECISION)
**Recommended: a shared, run-scoped DEFENDER LIFE POOL owned by the mode** (the TRIALS pattern: the
runner keeps humans respawning via a high `lives_per_player`; the mode owns the real economy).

- `defender_lives` starts at **N** (default **4** solo; = `MatchConfig.lives_per_player`, reused — §2).
- Each **human death**: if `defender_lives > 0`, spend one (`-= 1`) and the runner respawns the human
  (its runner-level `lives_left` stays high, so `_respawn_after_death` fires — B.4 path). Run continues.
- The death that occurs when `defender_lives == 0` is **fatal → DEFEAT.** Match ends, banner
  `"OVERWHELMED AT WAVE N"`, **score = highest wave reached (N)**.
- **Co-op = SHARED pool** (any human death decrements it; a fatal death ends the run for the team). This
  is a classic shared-fate co-op economy and creates revive-pressure. (Per-player pools = a v2 flag.)
- Lives do **NOT** refill between waves (the pool is the run's attrition budget — the escalating-pressure
  point). The runner's per-stage `lives_left` reset (`_begin_stage` sets `lives_left[i]=lives_per_player`)
  is harmless because the human's runner-level lives are a dummy-high number; the MODE's `defender_lives`
  is the real, persistent economy and is never reset between waves.

**Why survival-scored, not kill-scored:** the score is *waves survived* (N). Kills are not the point;
you can clear a wave with few personal kills (bots also ring each other out — §4). Survival framing keeps
the fantasy on "hold the line as long as you can," and gives the clean, brag-able "we reached WAVE 7"
number. (Total kills MAY be shown as a flourish sub-stat, but the SCORE is the wave number.)

---

## 2. The `GameMode` contract — `GauntletMode extends GameMode`

`src/modes/GauntletMode.gd` (`class_name GauntletMode extends GameMode`), registered in
`PartyMatch.MODE_REGISTRY` as `&"gauntlet": preload("res://src/modes/GauntletMode.gd")` alongside
`brawl`/`trials`. It fills the **same seam methods** — no `PartyMatch` rewrite beyond the ONE additive
hook in §2.1.

| Seam method | GauntletMode behavior |
|---|---|
| `id()` | `&"gauntlet"` |
| `display_name()` | `"GAUNTLET"` |
| `hud_scene()` | new `scenes/ui/GauntletHUD.tscn` (§3). NOT `MatchHUD` (no per-bot kill pips). |
| `configure(runner, config)` | Idempotent (called in `_ready` AND on rematch in `_start_match`). Read the defender pool from config: `defender_lives = maxi(0, config.lives_per_player)` (reuses the field; default 4). Then set the runner's dummy-high lives so the RUNNER never eliminates a defender: `runner.lives_per_player = 99`; `runner.match_target_kills = 999999` (a stray `on_kill` can never trip a kill-race end). Load the wave plan: `_waves = _load_wave_set(config)` (default set `"campaign"`, PROOF fallback if the file is unusable — like TRIALS). Resolve the arena: `_arena_path = config.single_arena_path if non-empty else DEFAULT_ARENA` (`res://levels/islands_void.json` — the flagship, forgiving-recovery, flight-required). Reset run state: `_run_over=false; _victory=false`. |
| `spawn_plan(runner, config)` | **Humans ONLY** (no bots at configure-time — waves spawn dynamically, §2.1). One descriptor per local human (`human:true, team:0, seed_damage:0`, skin/character from config). v1 = 1 human (solo); co-op = `config.human_count` humans, same plan (see §2.2 recommendation). |
| `next_level_path(runner)` | The arena for the wave that's about to begin. v1: return `_arena_path` every wave (**single arena** — see §2.3). Called once per wave in `_begin_stage`. |
| **`wave_spawn_plan(runner)`** | **THE NEW HOOK (§2.1).** Returns the bot spawn descriptors for the wave whose number is `runner.stage_index` (1-based). Reads `_waves[stage_index-1]`; one descriptor per listed level: `{human:false, bot_level:<lvl>, skin:<cycled>, character:"bouncer", seed_damage:0, team:1}`. Out of range (past the last wave) → `[]` (defensive; the match has already ended in victory by then). |
| `polls_goal()` | **`true`.** The wave-clear (all bots down) can leave 2+ humans alive (co-op) — a state the death-driven `_decide_stage_end` path never reaches (it only arms when not-eliminated count hits ≤1). Polling ends the stage the instant the last bot dies, for any human count. (BRAWL leaves this `false`.) |
| `on_kill(runner, killer_idx, victim_idx, cause)` | Runs BEFORE the runner's own life-decrement (`PartyMatch._on_killed` calls the mode first, line ~523, then decrements at line ~537) — this ordering is load-bearing. **Bot victim:** `runner.lives_left[victim_idx] = 1` so the runner's `-= 1` makes it `0` → the bot is **eliminated** for the wave (regardless of the dummy-high `lives_per_player`). **Human victim** (`runner.players[victim_idx].is_in_group("human")`): if `defender_lives > 0` then `defender_lives -= 1` (runner will respawn it); else `_run_over = true` (DEFEAT — resolved by `match_winner` this same death, before the runner's elimination/sudden-death logic runs). Never mutates `runner.scores`. |
| `match_winner(runner)` | `if _run_over: return 0` (DEFEAT — ends the match immediately on the fatal human death, BEFORE the double-KO sudden-death path can misfire). Else, **VICTORY** when the final wave is cleared: `if runner.state == "STAGE_END" and runner.stage_index >= _waves.size() and _bots_alive(runner) == 0: _victory = true; return 0`. Else `-1`. (The `STAGE_END` guard means a mid-combat `on_kill` call never declares premature victory; victory resolves at the final wave's stage-end freeze.) |
| `stage_end_banner(runner)` | `{text: "WAVE %d CLEARED!" % runner.stage_index, color: GOLD}`. |
| `match_end_banner(runner)` | Victory: `{text: "ALL WAVES CLEARED!", color: GOLD, subline: "SIEGE REPELLED — %d WAVES" % _waves.size()}`. Defeat: `{text: "OVERWHELMED", color: DANGER, subline: "REACHED WAVE %d" % _highest_wave}` (`_highest_wave` = the wave in progress when the run ended). |

**Helpers (mode-internal, read the existing QA contract):**
- `_bots_alive(runner) -> int` — count of `runner.players[i]` not in group `"human"` with
  `runner.lives_left[i] > 0` and `is_instance_valid`. (Same predicate family as `_not_eliminated_count`.)
- `current_wave() -> int` / `enemies_remaining(runner) -> int` (= `_bots_alive`) / `defender_lives` —
  read by GauntletHUD each frame.

**Explicitly reused runner plumbing (unchanged):** STAGE_INTRO pop-in + name tags, COUNTDOWN,
camera/framing (the action-cluster camera already frames a crowd), the level loader + `pit_void_rendering`,
juice, the multi-life respawn path (`_respawn_after_death`, B.4), the powerup director (leave it — a few
powerups mid-siege are on-brand; or disable via zero powerup_spawners in the arena JSON, no new toggle).
**Sudden death never triggers** in normal flow: a wave clear leaves ≥1 human not-eliminated (so
`_decide_stage_end`'s `ne.size()==0 && _recent_dead>=2` SD branch can't fire on a clear), and a fatal
human death ends the MATCH via `match_winner` before the SD branch is reached. **No fenced Tuning
constant is read or written.**

### 2.1 The ONE new additive runner hook: `wave_spawn_plan()` (the dynamic wave-spawn mechanism)

**The problem it solves:** `spawn_plan()` is called ONCE in `_ready` and builds a FIXED roster. Waves
need a DIFFERENT bot set each wave (more, tougher, spawned fresh). No existing seam expresses this.

**The hook (additive, base returns `[]` → BRAWL/TRIALS are no-ops → parity preserved):**

```
# src/modes/GameMode.gd  (new seam, documented like polls_goal)
## Additive seam (v4_gauntlet): descriptors for bots to spawn AT THE START of the stage about to begin
## (runner.stage_index). Lets a mode swap its bot roster PER STAGE (GAUNTLET waves). BRAWL/TRIALS return
## [] -> the runner skips the whole block -> byte-for-byte parity (C7). Same descriptor shape as spawn_plan.
func wave_spawn_plan(_runner) -> Array:
    return []
```

**Runner wiring — one insertion in `PartyMatch._begin_stage()`, immediately after `_load_stage(...)`
(line ~323) and BEFORE the per-player respawn/pop-in loop** (so the new bots are picked up by the loop
and get respawn + pop-in + name tags for free):

```
# NEW (additive). BRAWL/TRIALS return [] -> this block never runs -> parity.
var wave: Array = _mode.wave_spawn_plan(self)
if not wave.is_empty():
    _despawn_bots()                       # remove last wave's (now-dead) bots, compact parallel arrays
    for desc in wave:
        _spawn_player(players.size(), desc)   # REUSE the exact runner spawn path (INV: humans-first invariant holds)
```

**`_despawn_bots()` — new runner helper** (frees non-human players and compacts the parallel arrays;
safe here because it runs between stages with nothing in flight):

```
func _despawn_bots() -> void:
    for i in range(players.size() - 1, -1, -1):
        var p = players[i]
        if is_instance_valid(p) and not p.is_in_group("human"):
            p.queue_free()
            players.remove_at(i); scores.remove_at(i); lives_left.remove_at(i)
    # trim the lazily-grown camera arrays so stale trailing entries can't outlive the roster
    _combat_active_t.resize(players.size()); _cluster_linger_t.resize(players.size())
```

**Why this is minimal + safe:**
- **Humans keep stable indices** `0..human_count-1` (they're in group `"human"`, never despawned;
  bots are always appended after them). So `on_kill`'s human/bot test and the defender pool are stable.
- **The players array never grows unbounded**: dead bots are despawned before each new wave, so
  `players.size()` = `human_count + current_wave_count ≤ human_count + 5` (§3 cap) ≤ 7, within the
  8-player invariant and `PLAYER_COLORS`(8) range.
- **`_spawn_player` is reused verbatim** — the mode does NOT reach into spawn internals; it only
  supplies descriptors, exactly like `spawn_plan`.
- **BRAWL & TRIALS return `[]`** → `_despawn_bots` never runs, no bot is ever removed, roster is
  identical to today → **C7 + the TRIALS T-suite pass unchanged** (verify in G8).

This is the *only* runner change GAUNTLET requires. Everything else is pure seam fill. It is deliberately
one hook + one helper, in the spirit of TRIALS' single `polls_goal()` addition. The programmer owns
feasibility of the array-compaction + camera-array trim; flag back if any live-state assumption bites.

### 2.2 Co-op-from-the-start vs solo-first — RECOMMENDATION

**Recommendation: design the mode CO-OP-CAPABLE from day one, but QA/ship SOLO as the depth-first slice.**

Rationale: co-op costs the mode *almost nothing* because the runner already spawns N humans
(`spawn_plan` returns `human_count` humans, `_spawn_player` loop handles them) and `polls_goal()` already
covers the multi-human wave-clear case. The shared `defender_lives` pool is human-count-agnostic. So a
**solo-only** design would actually be MORE work (a special-case wave-clear path we'd rip out for co-op).
Building co-op-ready and validating solo first is the cheaper, lower-risk order. Ship gate: solo passes
G1–G12; co-op flip = a couch controller smoke test (two `InputHuman` slots) confirming shared-pool +
multi-human wave-clear, no new mode code.

### 2.3 Single arena vs rotation — RECOMMENDATION

**Recommendation: SINGLE arena per run for v1** (`next_level_path` returns `_arena_path` every wave),
default `islands_void` (flagship: wide forgiving islands, deep void = fast smash-kills, flight-required).
Reasons: (a) a fixed arena lets the defender build spatial mastery while the *waves* escalate — the fair,
skill-expressing pressure curve, not a disorienting new-map-every-wave attrition; (b) a void-is-floor
arena makes SMASHING the fast clear tool (anti-attrition, §4); (c) zero rotation logic. **Milestone
rotation** (a new arena every ~3 waves as a "new front") is a clean v2 add — `next_level_path` already
returns per-wave, so it's a data change (a per-wave `arena` field in `gauntlet_waves.json`), no new hook.

---

## 3. New pieces (the whole list)

1. **`src/modes/GauntletMode.gd`** — the seam class above. Registry entry in `PartyMatch.MODE_REGISTRY`.
2. **`scenes/ui/GauntletHUD.tscn` + `src/ui/GauntletHUD.gd`** — built as `.tscn` + `theme.tres` (per
   CLAUDE.md; NO OS-default widgets). Displays, all read live from `runner._mode`:
   - **WAVE N / of M** (big, top-center), and a **"WAVE N"** intro banner shown during STAGE_INTRO/COUNTDOWN.
   - **ENEMIES REMAINING** (a count + optional pips), = `mode.enemies_remaining(runner)`.
   - **DEFENDER LIVES** as chunky hearts = `mode.defender_lives` (+ the current life). Co-op: shared row.
   - On MATCH_END: reuse the runner's `show_match_end` banner path (victory/defeat text from the mode).
   - It does **NOT** enumerate per-bot cards (sidesteps the dynamic-roster/HUD-churn problem entirely).
3. **`levels/gauntlet_waves.json`** — the wave DATA (mirrors `circuits.json` / `course_sets.json`):
   ```
   { "sets": {
       "campaign": { "display_name": "SIEGE", "arena": "res://levels/islands_void.json",
         "waves": [
           { "levels": [1,1] },
           { "levels": [2,2,1] },
           { "levels": [2,3,2] },
           { "levels": [3,3,2,2] },
           { "levels": [3,4,3,2] },
           { "levels": [4,3,3,3,2] },
           { "levels": [4,4,3,3,3] },
           { "levels": [5,4,4,4] }
         ] } } }
   ```
   `_load_wave_set` returns a PROOF fallback (e.g. `[[1,1],[2,2]]` on the default arena) if the file is
   missing/malformed, so the mode is ALWAYS runnable (the TRIALS pattern). Optional per-wave `arena`
   override reserved for the v2 milestone-rotation.
4. **`MatchConfig`** — **no new field needed for v1.** Reuse: `mode_id = &"gauntlet"`, `human_count`
   (1 solo / 2+ co-op), `single_arena_path` (arena override, else default), and **`lives_per_player`
   re-read as the defender pool** (its literal meaning). Wave-set selection defaults to `"campaign"`;
   multiple selectable sets = a v2 field. ModeSelect gains a **GAUNTLET card** (enable/add per the
   frontend-shell grid), routing to a minimal launch (solo, campaign) — mirror the TRIALS card wiring.
5. **Bots — NO new behavior for v1.** Reuse `InputBot` + `BotProfile` levels 1–5 verbatim. Bots already
   hunt/aim/smash/recover and `idle_hunt` already swarms an idle defender. `arena.nearest_opponent`
   includes humans, so attackers target defenders naturally. **The one behavior RISK to validate** (not
   pre-solve): bots also treat *other bots* as opponents (free-for-all targeting), so a wave can partly
   clear via bot-on-bot ringouts — emergent comedy (Pillar 3) and it keeps waves from being a bullet-hell,
   but it could make clears feel unearned / too easy. This is turned into a NUMBER (G-BOTFOCUS): if the
   fraction of wave-bot deaths credited to a defender is too low, the MINIMAL fix is a targeting **bias**
   toward human opponents in `InputBot._pick_target` (a weight, not a new behavior, no feel constant).
   Do NOT add it preemptively — measure first (GAME_ESSENCE: "build a gate, not a warning").

---

## 4. Movement-showcase guardrails (NOT a bullet-hell, NOT a war of attrition)

The task's central risk: this must be the movement fantasy under pressure, not turtling or dodging shots.
Design levers, all reusing shipped systems:
- **Smash IS the clear tool.** Void-is-floor arena + the existing super-smash means you clear a wave by
  *flying into attackers and knocking them off* — the SUPER-SMASH verb, not chip-damage attrition.
- **Concurrency cap = 5 bots** (+ ≤2 humans ≤ 7 total) keeps the storm readable (Pillar 5) and beatable
  by maneuver, not just survivable by hiding.
- **No standable ground / no safe perch** (inherited from every shipped arena) — you can't turtle; the
  bounce/refuel rhythm forces motion. Idle-hunt swarms a camper (Pillar 2, free).
- **Fuel economy** forces the fly→refuel loop; you can't hover-camp a corner.
- **Finite, quality-tightening ramp** (wave 8 = fewer, deadlier) makes the climax a *skill/movement* test,
  not a swarm-attrition wall.
- **Defender pool + fast void-kills** keep runs short and punchy (death is cheap, waves resolve in
  seconds-to-tens-of-seconds), not a grind.

**Fenced feel constants touched: NONE.** All levers are geometry (existing arenas), existing bot dials,
and mode-owned counts.

---

## 5. Scaling/balance + validation plan (QA drives rendered; movement-first)

Difficulty ramps by (a) **bot COUNT** (2→5) and (b) **bot LEVEL** (`BotProfile` 1→5), per
`gauntlet_waves.json`. All validation reuses `round_stats` (`kills[]` with `blast_edge`/`off_stage`,
`smashes[]`, `supers_fired[]`, `motion_health[]`), the live `bot_motion_health()` probe, and gbplay
`eval`/`screenshot`/`key`/`hold-action`.

**Measurable success criteria:**
- **G1 Reachability:** ModeSelect → GAUNTLET launches to live play; GauntletHUD shows `WAVE 1`,
  `enemies == wave-1 count (2)`, defender lives == configured N. (`eval` on `state`, mode fields; screenshot.)
- **G2 Dynamic wave spawn (the new hook):** at wave-1 COMBAT, `players.size() == human_count + 2`, and the
  two bots' `bot_level` match the plan (`[1,1]`). Proves `wave_spawn_plan` spawned bots at stage-begin,
  NOT at configure-time. (`eval` on `players.size()` + per-bot level.)
- **G3 Wave clear + advance + compaction:** drive/observe wave-1 bots eliminated → `state` → `STAGE_END`
  with `"WAVE 1 CLEARED!"` → wave 2 begins with `players.size() == human_count + 3` and **no leftover
  dead wave-1 bots** (the array was compacted by `_despawn_bots`). (`eval` across the transition.)
- **G4 Escalation is real:** for each wave N, the live bot roster count + levels equal
  `gauntlet_waves.json` wave N (monotonic-in-threat). (`eval` per wave.)
- **G5 Defeat + score:** set `lives_per_player = 0` (pool empty), drive/allow a human death → immediate
  `MATCH_END`, banner `"OVERWHELMED"` + `"REACHED WAVE 1"`. **`entered_sd == false` for every stage**
  (sudden death never fires). (`eval` on `state`, banner, `round_stats[*].entered_sd`.)
- **G6 Victory:** clear all 8 waves → `MATCH_END`, `"ALL WAVES CLEARED!"`, victory sub-line. (Long
  driven/scripted run or a shortened proof wave-set for the harness.)
- **G7 Respawn-not-eliminate (B.4 reuse):** with pool > 0, a driven human void-fall → the human respawns
  at a spawn within `respawn_delay`, `defender_lives` decremented by exactly 1, run continues (`state`
  stays in-wave). N non-fatal falls never end the run early. (`eval` on `defender_lives` + `state`.)
- **G8 Seam parity — no runner rewrite:** BRAWL passes `v1_frontend_shell` **C7** verbatim AND the TRIALS
  T-suite passes, after GauntletMode + the `wave_spawn_plan` hook land (both return `[]` → `_despawn_bots`
  never runs). Parse gate clean (`--headless --editor --quit`; no Parse Error / hides-a-native /
  Failed-to-load).
- **G9 Movement-showcase (FANTASY gate — GAME_ESSENCE):** over a driven wave with a competent human line,
  the defender's **airborne fraction is high**, wave-bot deaths are dominantly **smash/super-driven**
  (`round_stats.smashes` non-trivial; killed bots' `blast_edge` ∈ {`void`,`bottom`} = knocked off), and
  the human driver shows **zero motion pathology** (`motion_health`: no `stuck_episodes`, no
  `underside_bounces` head-banging, `blocked_ascent_episodes == 0`). **A wave cleared by a human camping a
  corner is a FAIL even if it clears.**
- **G-BOTFOCUS (bot-targeting risk, §3.5):** fraction of wave-bot deaths credited to a defender
  (`kills[].killer` is a human index) ≥ **0.6** across a driven run. Below that → waves clear too much via
  bot-on-bot; apply the minimal `_pick_target` human bias and re-measure. (`eval` on `round_stats.kills`.)
- **G10 Readability / no-widget (Pillar 5):** concurrent living entities ≤ `human_count + 5`; at gameplay
  zoom every bouncer reads (color/face); GauntletHUD uses `theme.tres` (no OS-default labels/bars).
  (Screenshots at peak-crowd wave 6.)
- **G11 Fair + not attrition:** a competent solo driver reaches **≥ wave 3** on the default pool; each wave
  resolves in **bounded time** (`round_stats[*].length_s` < ~45s — bots don't infinitely flee; they
  hunt/attack); the finale (wave 8) is beatable, not a coin-flip wall. (Driven runs + `length_s`.)
- **G12 No fenced constant:** `git diff src/core/Tuning.gd` is empty after the feature lands.

**De-risked build order (depth-first):**
1. **Prove the `wave_spawn_plan` hook + `_despawn_bots`** with a throwaway 2-wave set and BRAWL bots — drive
   a wave to clear, confirm despawn+respawn of a NEW roster next wave, and re-run **C7** for parity (G2,
   G3, G8). This is the only unknown — surface it first.
2. **`GauntletMode` seam class + registry** (defender pool, on_kill bot-elimination + human-respawn,
   polls_goal, is_stage_over, match_winner victory/defeat, banners). Prove a full solo run: waves advance,
   defeat + victory both end the match cleanly, SD never fires (G5, G6, G7).
3. **`GauntletHUD.tscn`** (wave / enemies / lives) to theme (G1, G10).
4. **`gauntlet_waves.json` "campaign"** + `_load_wave_set` fallback; author the 8-wave ramp (G4, G11).
5. **ModeSelect card + rendered playtest + CD fantasy-fit verdict** — must FEEL like "they keep coming and
   I keep flying," pass G9 (airborne + smash-clear + clean motion) and G-BOTFOCUS, not just green criteria.
6. **Co-op flip** — a two-human couch smoke test (§2.2); then backlog: endless modifier, milestone arena
   rotation, per-player pools, boss waves, a defender-target bias if G-BOTFOCUS demanded it.

---

## Summary (the asks answered)

- **Core loop:** finite escalating waves (data-driven counts + `BotProfile` levels 1→5) on one arena;
  clear a wave by eliminating all its attacker bots (smash them off the void); STAGE_END/INTRO/COUNTDOWN
  supply the free breather + "WAVE N" beat; **shared, run-scoped defender life pool** (mode-owned, TRIALS
  pattern); DEFEAT when a defender goes down with the pool empty → "REACHED WAVE N" (score = waves);
  VICTORY on clearing the final wave.
- **GameMode contract:** all seam methods mapped (§2). The **dynamic wave-spawn mechanism** = **one new
  additive hook, `wave_spawn_plan(runner) -> Array`** (base `[]`), consumed in `_begin_stage` right after
  `_load_stage`, reusing `_spawn_player` verbatim + a `_despawn_bots` compaction helper. BRAWL/TRIALS
  return `[]` → the block never runs → **byte-for-byte parity** (C7 + T-suite). `polls_goal()=true` handles
  multi-human wave-clear; `on_kill` (which runs *before* the runner's life-decrement) eliminates bots and
  spends the human pool; `match_winner` ends the match on victory (final wave cleared) or defeat (fatal
  human death), sidestepping sudden death.
- **New pieces:** `GauntletMode.gd`, `GauntletHUD.tscn/.gd`, `levels/gauntlet_waves.json`, a ModeSelect
  card. **No new MatchConfig field** (reuse `lives_per_player` as the defender pool, `single_arena_path`
  as the arena). **No new bot behavior** (reuse levels 1–5; one measured risk = free-for-all targeting,
  with a minimal `_pick_target` human-bias held in reserve).
- **Recommendations:** **co-op-capable from the start, validate solo first** (co-op is nearly free; solo-
  only would cost more). **Single arena per run for v1** (mastery + fast smash-clears), milestone rotation
  as a v2 data change.
- **Fenced feel constants touched: NONE** (flagged explicitly; G12 verifies).
