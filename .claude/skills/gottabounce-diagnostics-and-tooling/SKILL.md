---
name: gottabounce-diagnostics-and-tooling
description: How to MEASURE GottaBounce instead of eyeballing it — pull fps/draw-call numbers (gbplay perf), extract the PartyMatch round_stats QA feed via eval (SD rate, end-cause histogram, median round length, supers-fired, off-stage kills, turnaround), run burst screenshot sequences for motion analysis, read the headless Playtest summary, and use the shipped match_stats.py / perf_gate.py / feel_probe.jsonl scripts with interpretation targets. Load when asked to "measure", "get the numbers", "check SD rate / pacing / fps", "pull round_stats", or grade a match against the lethality spec. Do NOT load for launching/driving the game itself (see gottabounce-run-and-playtest) or for what counts as QA evidence and sign-off (see gottabounce-validation-and-qa).
---

# GottaBounce diagnostics and tooling — measure, don't eyeball

**What this covers:** the project's measurement instruments and how to read their output —
`gbplay perf`, the PartyMatch `round_stats` QA contract, burst screenshots, the headless Playtest
summary, `EventBus.super_fired` telemetry, structure asserts, and three ready-made scripts shipped
in this skill's `scripts/` directory.
**When NOT to use this:** launching/stopping/driving the game and gbplay command anatomy →
skill `gottabounce-run-and-playtest`. Evidence doctrine and what a QA verdict requires →
skill `gottabounce-validation-and-qa`. Constant values and how to change them →
skill `gottabounce-tuning-and-flags`. Symptom-first triage ("it's broken, why?") →
skill `gottabounce-debugging-playbook`.

## 0. Preconditions (one paragraph — deep version in gottabounce-run-and-playtest)

Every instrument below except the headless Playtest needs the game ALREADY running **windowed**
(`powershell -File tools/run_game.ps1`), serving TCP `127.0.0.1:9090`. One instance only; the
server is single-flight (one command at a time, 30s stuck-busy watchdog). The OLD project at
`D:\Dropbox\MyGames\GottaBounce` also serves 9090 — before trusting any number, confirm you are
measuring THIS project:

```
python tools/gbplay.py eval "return get_tree().current_scene.scene_file_path"
```

Expected: `res://scenes/Arena.tscn` (the main scene, whose root runs `src/modes/PartyMatch.gd`).
Run all commands from the repo root. Definition used throughout: **eval** = the gbplay command
that executes arbitrary GDScript inside the running game; your code is wrapped in a function body,
so **it must `return` a value or you get `"result": null`**. Multi-line code and `await` are
supported; semicolons separate statements on one line.

## 1. Instrument index

| # | Instrument | Measures | One-liner |
|---|---|---|---|
| 1 | `gbplay perf` | fps, frame time, memory, node/draw counts | `python tools/gbplay.py perf` |
| 2 | `round_stats` via eval | pacing, lethality, kill attribution, super usage | `python tools/gbplay.py eval "return get_tree().current_scene.round_stats"` |
| 3 | `gbplay burst` | motion over time (screenshot sequence) | `python tools/gbplay.py burst tools/out/my_burst 10 --interval 0.5` |
| 4 | Headless Playtest | physics sanity: speeds, bounces, tunneling, kills | see §5 |
| 5 | `EventBus.super_fired` | live super-usage telemetry | see §6 |
| 6 | `gbplay tree` / `ui` | scene structure / visible UI asserts | `python tools/gbplay.py tree` |
| 7 | Shipped scripts | 1+2 automated with PASS/FAIL grading | see §7 |

## 2. Performance: `gbplay perf`

`python tools/gbplay.py perf` returns (fields verified against
`src/dev/mcp_interaction_server.gd` `_cmd_get_performance`):

| Field | Godot monitor | How to read it |
|---|---|---|
| `fps` | TIME_FPS | Golden reference (measured, docs/STATUS.md): **79–80 fps** on the shipped arena. Criterion (lethality spec §9 test 21): **avg ≥55 fps, no hitch >100 ms** during a smash-heavy round. |
| `frame_time` | TIME_PROCESS | LAST frame's process time in **seconds** (~0.012 at 80 fps). One sample >0.1 = a caught hitch. Polling can MISS hitches between samples — never claim "no hitches" from perf polling alone. |
| `physics_frame_time` | TIME_PHYSICS_PROCESS | Physics tick cost. The project runs 120 physics ticks/s, so budget is ~8.3 ms. |
| `memory_static` / `memory_static_max` | MEMORY_STATIC(_MAX) | Bytes. Watch for growth across rounds (leak). |
| `object_count` / `object_node_count` | OBJECT(_NODE)_COUNT | Steady growth round-over-round = something isn't freed (SD walls, particles, name tags all `queue_free`). |
| `object_orphan_node_count` | OBJECT_ORPHAN_NODE_COUNT | Orphans that never enter the tree; growth = leak. |
| `render_total_objects` / `render_total_draw_calls` | RENDER_* | Golden: **28 draw calls**. A jump means leaked FX/canvas items. |

Golden numbers are historical measurements recorded in docs/STATUS.md (sessions 1–2, 2026-07-02);
re-measure rather than assuming they still hold.

## 3. The PartyMatch QA contract (`round_stats`) — THE feel-metrics source

`src/modes/PartyMatch.gd` (root script of `scenes/Arena.tscn`) exposes read-only state for QA
(spec: v0_round_loop §5 + v0_combat_lethality §8). Access everything through
`get_tree().current_scene`:

### 3.1 Top-level fields (verified against PartyMatch.gd, 2026-07-03)

| Field | Type | Meaning |
|---|---|---|
| `state` | String | `"BOOT"`, `"MATCH_START"`, `"ROUND_INTRO"`, `"COUNTDOWN"`, `"COMBAT"`, `"SUDDEN_DEATH"`, `"ROUND_END"`, `"MATCH_END"` |
| `round_index` | int | 1-based, increments at ROUND_INTRO |
| `round_clock` | float | hidden combat clock in s (drives sudden death at `Tuning.sudden_death_time` = 20.0; never rendered) |
| `scores` | Array | current match score per player index (P1 = 0) |
| `last_death_msec` | int | `Time.get_ticks_msec()` of the most recent death |
| `combat_start_msec` | int | ticks_msec of the last "BOUNCE!" physics unlock |
| `round_stats` | Array | one Dictionary per **completed** round (appended at ROUND_END; the in-progress round is NOT in it) |
| `players` | Array | Player nodes; `players[0]` is P1 (per-player fields: `fuel`, `velocity`, `is_dead()`, `secs_since_input`, `_stun_timer`, `_stunned_by`) |

### 3.2 `round_stats` entry schema (the live shape — verified in code)

```
{ "length_s": float,            # round_clock at the deciding death
  "end_cause": String,          # cause of the round-deciding (last) death: "ring_out" | "laser" | "hazard"
  "entered_sd": bool,           # round reached SUDDEN_DEATH (timer or double-KO revive)
  "kills": [ { "killer": int,   # player index, or -1 = no attacker credit (suicide/unattributed)
               "victim": int,
               "off_stage": bool } ],   # victim's LAST received smash landed off-stage (edge-guard metric)
  "survivor_had_contact": bool, # sole survivor dealt/received >=1 smash (survival-gate audit)
  "supers_fired": [ { "who": int, "fuel_at_fire": float,
                      "aim_time": float, "auto_fired": bool } ] }
```

**Do not confuse this with `tools/out/qa3_match2_log.json`** — that file has kills shaped
`{attacker, cause, clock, round, state, victim}` because it came from a CUSTOM recorder a session-2 QA
agent installed via eval. The live built-in shape is the block above.

### 3.3 Pulling it

```
python tools/gbplay.py eval "return get_tree().current_scene.round_stats"
python tools/gbplay.py eval "return get_tree().current_scene.round_stats.size()"
python tools/gbplay.py eval "var cs = get_tree().current_scene; return {\"state\": cs.state, \"scores\": cs.scores, \"round\": cs.round_index}"
```

Gotchas (all verified in code):
- **gbplay truncates its printed output to 4000 characters** (`gbplay.py` `out()`), so a full
  match's `round_stats` dump WILL be cut in the terminal. The server sends the full JSON — use
  `scripts/match_stats.py` (§7), which reads the socket directly and writes the raw array to a file.
- **`round_stats` is cleared on rematch** (`_start_match()`), and each entry is appended only at
  ROUND_END — poll `.size()`, don't assume.
- A match ends at 10 points with a strict lead and then SITS at MATCH_END waiting for input;
  `round_stats` survives until someone triggers a rematch. An idle-P1 bot match typically yields
  a full sample unattended, then parks.

### 3.4 Interpretation guide (targets from docs/specs/v0_combat_lethality.md §9, v2.1)

| Metric | How to compute | Target | Spec test |
|---|---|---|---|
| SD rate | % rounds with `entered_sd == true` | **≤25%** (12.5% measured in the 8-round implementation smoke, 2026-07-03; regressed to 27–33% under the bumper-save bug — see §3.5) | 11 |
| Kill-decided | % rounds with `end_cause != "laser"` AND `entered_sd == false` AND `length_s < 20` | **≥70%** | 10 |
| Round length | median `length_s` | **10–22 s**; every round ≤26 s combat clock | 12 |
| Edge-guarding | count of kills with `off_stage == true` | **≥3 per 10-round sample** | 15 |
| Super usage | `supers_fired.size()` per round | no numeric target; **0 supers in most rounds is a red flag** — historically that pattern was a mis-hooked recorder, not a game regression (a fresh sample showed 54 supers in one round, docs/STATUS.md) | — |
| Kill attribution | share of kills with `killer == -1` | no target; -1 = suicide/no-credit. All-`-1` samples are suspect — cross-check with a burst | — |
| Turnaround | `(combat_start_msec - last_death_msec) / 1000.0`, sampled early in the NEXT round's COMBAT (before its first death overwrites `last_death_msec`) | **≤4.5 s** (measured 4.28–4.29 s, docs/STATUS.md) | 21 |

Turnaround one-liner (run just after a new "BOUNCE!"):

```
python tools/gbplay.py eval "var cs = get_tree().current_scene; return (cs.combat_start_msec - cs.last_death_msec) / 1000.0"
```

### 3.5 State of play, 2026-07-03 — read before grading

Lethality v2 is implemented (03894ac) + fix round (587d0a1) but **NOT signed off**: core hinge
PASSES (kill 9/10, counter-escape 10/10, chain credit 6/6, kill-decided 72.7%, median 15.0 s), but
the bumper-save bug (spec v2.1 §2.3a "dry reflect" ruling) skewed tests 11/13/14/15. Full incident
→ skill `gottabounce-failure-archaeology` (Incident 10). **Grading impact — this state is
VOLATILE:** as of 2026-07-03 the programmer fix was still pending at HEAD 0e315b9 (staged
uncommitted), so until it lands and tests 11/13/14/15 (+ new 6c/6d) re-run, expect SD ≈27–33% and
off-stage kills ≈0 in your samples and do NOT read those as fresh regressions. Re-verify current
state via `git log --oneline -1 -- src/entities/Player.gd` and docs/STATUS.md before grading.

## 4. Burst screenshots — motion analysis

```
python tools/gbplay.py burst tools/out/<name>_burst 12 --interval 0.5
```

Writes `frame_000.png … frame_011.png` into the directory. Interval guidance: `--interval` is the
sleep BETWEEN captures; each capture also costs a full request round-trip (the server waits one
process frame, encodes a PNG, base64s it), so effective spacing is longer than the nominal value —
treat frame timestamps as approximate (verified: static). Pick:

- **0.2–0.3** — combat beats: super aim → fire → victim flight → ring-out (a full smash sequence
  is ~1–2.5 s).
- **0.5** (default) — round flow: countdown, SD walls closing (`laser_close_time` = 6.0 s spans
  ~12 frames), turnaround.
- **1.0+** — match-level pacing / soak checks.

LOOK at the frames (Read tool renders PNGs). Existing burst artifacts follow the
`tools/out/<name>/frame_NNN.png` convention (e.g. `tools/out/qa5_fight/`). Naming taxonomy →
skill gottabounce-run-and-playtest.

## 5. Headless Playtest summary

The only instrument that runs WITHOUT the windowed game (never run both at once — and per studio
rules, launching any Godot process needs `dangerouslyDisableSandbox: true`; command anatomy →
skill gottabounce-run-and-playtest):

```
C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe --headless --path . res://scenes/Playtest.tscn -- botwar 60
```

Modes (`src/dev/Playtest.gd`): `observe` (P1 does nothing), `hover` (scripted jetpack traversal —
speed/gravity feel), `duel` (scripted P1 vs bots), `botwar` (P1 replaced by an L4 bot). Second arg
= seconds. It boots Arena.tscn inside itself, logs one line per second
(`[t= 12.0] P0 pos(...) spd... fuel... | bounces=N` plus `>> KILL:` / `>> RINGOUT/SUICIDE:` lines),
then prints:

```
========== PLAYTEST SUMMARY (mode=..., 60s) ==========
max speed seen (any player): ... px/s      <- must be <= Tuning.max_speed (3000); above = physics runaway
tunnel frames (alive player below floor): 0 <- ALIVE player below y=1860 (FLOOR_TUNNEL_Y); nonzero = real tunneling
total bounces: ...                          <- ~0 = physics dead / everyone stuck
per-player max speed: {...}
ringouts/suicides: {player_index: count}    <- unattributed deaths
kills: {attacker_index: count}              <- credited kills
```

Use it for cheap physics regression probes (tick-rate bugs, runaway speed, bot suicide loops) —
it is NOT a feel verdict and NOT a substitute for the rendered stack (doctrine →
skill gottabounce-validation-and-qa).

## 6. `EventBus.super_fired` — live super telemetry

Signal (verified `src/systems/EventBus.gd`):
`super_fired(player, fuel_at_fire, aim_time, auto_fired)`. PartyMatch already subscribes and
records it into `round_stats.supers_fired` — prefer reading that (§3). Hook it live only to
discriminate "supers aren't firing" (game) from "supers aren't being recorded" (recorder) — the
exact ambiguity that stalled a QA agent in session 3. Install a counter (verified: static):

```
python tools/gbplay.py eval "var n = Node.new(); n.name = \"SuperCounter\"; n.set_meta(\"count\", 0); get_tree().root.add_child(n); EventBus.super_fired.connect(func(_p, _f, _a, _auto): n.set_meta(\"count\", int(n.get_meta(\"count\")) + 1)); return \"installed\""
python tools/gbplay.py eval "return get_tree().root.get_node(\"SuperCounter\").get_meta(\"count\")"
```

Counter rising while `supers_fired` stays empty = recorder/hook problem, not a game problem.
Remove with `... eval "get_tree().root.get_node(\"SuperCounter\").queue_free(); return true"`.

## 7. Shipped scripts (`scripts/` in this skill — all `verified: static`, never yet live-run)

| Script | What it does | Run |
|---|---|---|
| `match_stats.py` | Polls `round_stats.size()` until N rounds complete (or MATCH_END/timeout), fetches the full array over its own socket (no 4000-char truncation), prints the §3.4 table with PASS/FAIL verdicts vs spec §9 tests 10/11/12 and reports the test-15 off-stage-kill count (raw number + a `>=3 per 10-round sample` reference label, no PASS/FAIL verdict — grade it manually), writes raw JSON to `tools/out/match_stats_raw.json`. `--once` grades whatever exists now. | `python .claude/skills/gottabounce-diagnostics-and-tooling/scripts/match_stats.py --min-rounds 10` |
| `perf_gate.py` | N perf samples → avg/min fps, worst sampled frame time, draw-call and orphan-node watch, PASS/FAIL vs test 21 (avg ≥55). Honest about the hitch-sampling blind spot. | `python .claude/skills/gottabounce-diagnostics-and-tooling/scripts/perf_gate.py --samples 60 --interval 0.5` |
| `feel_probe.jsonl` | Fixed P1 input timeline (boost run → super aim → fire → settle) with screenshots at fixed points + a final fuel/speed eval. Rerun after a tuning change and diff the frames. Preconditions: COMBAT state, P1 alive, fuel ≥5. | `python tools/gbplay.py script .claude/skills/gottabounce-diagnostics-and-tooling/scripts/feel_probe.jsonl` |

Shared failure modes: connection refused → game not running (start it, see
gottabounce-run-and-playtest); `Server busy` → another client mid-command (scripts retry; never
run two drivers in parallel); `n == -1` / null results → current scene isn't PartyMatch or you're
talking to the OLD project on 9090 (check the printed scene path). Both .py scripts are stdlib-only
and run from the repo root.

## 8. Symptom → measurement (which number to pull first)

| You suspect | Measure | Healthy looks like (2026-07-03) |
|---|---|---|
| "rounds feel laser-decided / stally" | `match_stats.py` SD% + end-cause histogram | SD ≤25%, kill-decided ≥70% (but see §3.5 while the v2.1 fix is pending) |
| "kills aren't landing" | `round_stats.kills` per round + a 0.25s burst of one fight | ≥1 kill most rounds, killers ≠ -1; burst shows victim flight + ring-out |
| "supers never happen" | §6 live counter vs `supers_fired` | counter and recorder agree; dozens per round in bot matches |
| "edge kills impossible" | `off_stage` kill count | ≥3 per 10 rounds (KNOWN FAIL until v2.1 fix lands) |
| "game got slow / leaks" | `perf_gate.py` across several rounds | avg ≥55 fps, draw calls ~28 flat, orphans flat |
| "physics regressed" (tick rate, runaway) | headless Playtest `botwar 60` | max speed ≤3000, tunnel frames 0, bounces climbing |
| "round transitions drag" | turnaround one-liner (§3.4) | ≤4.5 s (measured 4.28–4.29 s) |
| "HUD/scene broke structurally" | `gbplay tree` / `gbplay ui` | expected nodes present; `ui` lists visible Controls with text + rects |

## Provenance and maintenance

Verified 2026-07-03 by reading the repo at HEAD `0e315b9` (no live runs — port 9090 was reserved;
everything an execution would prove is marked `verified: static`):

- gbplay command surface, 4000-char print truncation, script/.jsonl format, burst naming —
  `tools/gbplay.py` (read in full). Re-verify: `python tools/gbplay.py --help` or reread the file.
- Server protocol, single-flight busy flag + 30 s watchdog, eval wrapper (`return` requirement),
  perf fields — `src/dev/mcp_interaction_server.gd`. Re-verify perf fields:
  `Grep "_cmd_get_performance" -A 15 src/dev/mcp_interaction_server.gd`.
- `round_stats` schema + all top-level QA fields — `src/modes/PartyMatch.gd` (read in full).
  Re-verify shape: `Grep "supers_fired" src/modes/PartyMatch.gd` and the `_cur_stats` init in
  `_bounce_go()`. Drift-prone: any PartyMatch refactor.
- Targets/tests 10/11/12/15/21 and the v2.1 §2.3a ruling — `docs/specs/v0_combat_lethality.md`
  (v2.1, 2026-07-03). Re-verify: `Grep "SUDDEN_DEATH" docs/specs/v0_combat_lethality.md`.
- Golden numbers (79–80 fps, 28 draw calls, turnaround 4.28–4.29 s, 12.5% SD smoke, QA
  re-verification verdict + pending programmer fix) — `docs/STATUS.md`. **Most drift-prone facts
  in this skill**; re-verify by rereading STATUS before quoting any of them.
- Playtest modes/summary/FLOOR_TUNNEL_Y=1860 — `src/dev/Playtest.gd`. Signals —
  `src/systems/EventBus.gd`. Constants quoted (sudden_death_time 20.0, laser_close_time 6.0,
  max_speed 3000, super_boost_min_fuel 5.0) — `src/core/Tuning.gd`; live truth:
  `python tools/gbplay.py eval "return Tuning.sudden_death_time"`.
- Input action names (boost/super/move_*) — `project.godot` `[input]`.

UNVERIFIED / static-only items:
- All three shipped scripts have never executed against a live game (`verified: static`); the
  Director should live-spot-check `match_stats.py` first.
- Effective burst frame spacing (capture overhead) — inferred from code, not timed.
- The eval install-a-counter snippet in §6 — syntax-checked by eye only.
- STATUS.md cites `tools/out/qa5_*.json` as re-verification evidence; only `qa5_*.png` and the
  `qa5_fight/` burst exist in `tools/out/` — the JSON is absent (2026-07-03). The only kill-log
  JSON present is the legacy-shaped `qa3_match2_log.json`.
