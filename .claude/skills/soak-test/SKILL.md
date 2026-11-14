---
name: soak-test
description: >-
  Long unattended bot-match runs of the rendered GottaBounce build via gbplay to catch crashes,
  hangs, softlocks (match parks / state never advances), leaks (node/orphan/memory growth), fps
  decay, stuck bots, and errors that only appear after many rounds or rematches. Load before
  calling a weekend's work stable, after changes to match flow / modes / spawning / FX / pooling,
  or when a bug "only happens after a while". Do NOT load for a single-feature QA pass
  (qa-playtester), focused perf profiling of one scene (performance-analyst), or feel judgments.
---

# Soak test (bots play, we watch the numbers)

No human plays. Bots run match after match while we sample state, perf, and the log. Runs in the
foreground in bounded chunks — never "launch a background sweep and end the turn waiting".

## 1. Setup
- Only ONE rendered game can run (port 9090): stop strays first, and the soak blocks every other
  rendered task until it ends. ALWAYS `powershell -File tools/stop_game.ps1` at the end, pass or fail.
- Launch: `powershell -File tools/run_game.ps1 res://scenes/Arena.tscn` (`dangerouslyDisableSandbox:
  true`). The dev boot is 1 human + 3 bots; the idle P1 still bounces — fine for stability, but
  note it. For a 4-bot match configure via the shell flow or `MatchConfig` and record how.
- Optional speed-up: `gbplay raw` `time_scale` (record the value; fps/hitch numbers are only valid
  at 1.0). Cover more than one mode/circuit across chunks (brawl circuits, trials, sports).
- Log: the game writes `%TEMP%\gottabounce_run.log` (+ `.err`).

## 2. Baseline (T0, first round of combat)
`python tools/gbplay.py perf` -> fps, frame_time, physics_frame_time, memory_static,
object_node_count, object_orphan_node_count, render_total_draw_calls. Plus
`gbplay eval "var cs = get_tree().current_scene; return {\"state\": cs.state, \"round\": cs.round_index, \"scores\": cs.scores}"`.

## 3. Loop (each checkpoint ~every 2-5 min; chunks of <=10 min per tool call)
At every checkpoint record: perf fields, PartyMatch state/round/scores, `round_stats.size()`,
`bot_motion_health()`, a screenshot (`tools/out/soak_<n>.png` — READ it), and new ERROR/WARNING
lines in the log. Alerts:
- **Softlock:** state or round unchanged across 2 checkpoints while not at MATCH_END.
- **Match end:** drive REMATCH through the VictoryScreen as a player would (confirm input) — that
  exercises the UI path too. Fall back to `eval get_tree().current_scene._start_match()` only if
  that fails, and report that the UI path failed.
- **Leak:** node/orphan counts or memory_static trending up at the same state (compare like with
  like, e.g. each STAGE_INTRO) across 3+ checkpoints; >20% growth over T0 after warm-up.
- **Decay:** avg fps down >10% vs T0 or draw calls not returning to baseline after FX.
- **Stuck bots:** rising `stuck_secs` / `underside_bounces` in motion health.
- **Crash/hang:** gbplay timeouts or process gone -> capture the log tail, relaunch, continue.
Quick form: 10 min, one circuit. Full form: 60+ min across modes and >=3 rematches.

## 4. Report
```
## Soak - <date> - <commit> - <duration> - <modes/circuits> - time_scale <x>
Rounds: N, matches: N, rematches: N (UI path ok?)
| Metric | T0 | Last | Trend | Alert |
Crashes/hangs/softlocks: ... (log excerpt, screenshot)
Errors in log: unique lines + counts
Motion health: ...
Findings: <what> - evidence - P0-P3 / S-M-L - owner
```
Feed findings to `bug-triage`. A soak with no checkpoints recorded is NOT ASSESSED, never a pass.
