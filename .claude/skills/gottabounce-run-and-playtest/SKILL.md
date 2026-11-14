---
name: gottabounce-run-and-playtest
description: >-
  Operate the GottaBounce game: launch it rendered with tools/run_game.ps1, drive it with
  python tools/gbplay.py (screenshot / key / hold-action / eval / burst / script), run the
  headless Playtest harness, run the parse gate, stop cleanly, and name output artifacts in
  tools/out/. Load this whenever you need to run, screenshot, drive, or observe the game, or
  when gbplay/port-9090/run_game commands are involved. Do NOT use it for deciding what counts
  as QA evidence (see gottabounce-validation-and-qa), for metric-extraction scripts and
  interpretation targets (see gottabounce-diagnostics-and-tooling), or for machine setup from
  scratch (see gottabounce-build-and-env).
---

# Running and driving the game

**What this covers:** exact command anatomy for operating GottaBounce — `tools/run_game.ps1`,
`tools/stop_game.ps1`, every `tools/gbplay.py` subcommand, the TCP wire protocol, the headless
`Playtest.tscn` harness, the parse gate as an operating command, and `tools/out/` artifact naming.

**When NOT to use this:**
- What evidence counts / 4-layer validation doctrine → skill `gottabounce-validation-and-qa`
- Pulling match metrics (round_stats, perf targets, interpretation) → skill `gottabounce-diagnostics-and-tooling`
- Symptom→fix triage when something misbehaves → skill `gottabounce-debugging-playbook`
- Installing Godot/Python/Chrome, Windows shell traps in depth → skill `gottabounce-build-and-env`

All facts below verified against the repo on 2026-07-03 (static reads only — see Provenance).

## The 60-second loop (copy-paste)

```powershell
powershell -File tools/run_game.ps1                       # launch Arena.tscn windowed, wait for port 9090
python tools/gbplay.py screenshot tools/out/check.png     # capture — then actually LOOK at the PNG
python tools/gbplay.py hold-action boost --ms 800         # drive input
python tools/gbplay.py eval "return Tuning.gravity"       # inspect any live value (note: 'return' required)
powershell -File tools/stop_game.ps1                      # ALWAYS stop when done
```

Run from the repo root: `D:\Dropbox\MyGames\GottaBounce - FablePause` (path contains spaces — quote it).
Any shell call that launches Godot needs `dangerouslyDisableSandbox: true`. Prefer the Bash tool for
direct Godot invocations (PowerShell 5.1 wraps native stderr in NativeCommandError — details in
skill `gottabounce-build-and-env`).

## run_game.ps1 — what it actually does

Source: `tools/run_game.ps1`. Usage: `powershell -File tools/run_game.ps1 [scene] [-Wait]`

Step by step (verified against the script, 2026-07-03):
1. Kills **every** process named `Godot*` (zombie hygiene — this also kills the sibling old
   project's game if it is running).
2. Sleeps 300 ms.
3. `Start-Process` on `C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe` with
   args: `--path "<repo>" --resolution 1280x720 --position 50,50 [scene]`. The optional `[scene]`
   is a `res://` path, e.g. `res://scenes/SmokeTest.tscn`; with no scene it boots the main scene
   `res://scenes/Arena.tscn` (per `project.godot`).
4. Redirects stdout to `$env:TEMP\gottabounce_run.log` and stderr to
   `$env:TEMP\gottabounce_run.log.err`. Read these when the game misbehaves at launch.
5. Polls TCP 127.0.0.1:9090 for up to 20 s. Prints `Interaction server UP on 9090` on success —
   on timeout it only prints a WARNING and **does not fail**; the process may still be running
   broken. Check the log file before retrying.
6. `-Wait` blocks until the game process exits (rarely wanted; omit it).

The game window is **windowed 1280x720**, positioned at 50,50. The project's design viewport is
1920x1080 (`project.godot`, stretch mode `canvas_items`) — see "Resolution note" below.

## stop_game.ps1 — always run it

Source: `tools/stop_game.ps1` — one line: force-stops all `Godot*` processes. Safe to run anytime.
It is also the zombie-killer: stray Godot instances hog CPU, hold port 9090, and make later runs
act slow or connect to a stale window. If runs feel slow or gbplay talks to the "wrong" game:
stop everything, relaunch.

## The one-instance rule

- Port 9090 is exclusive: exactly ONE game instance at a time.
- The server accepts one TCP client; a new connection kicks the previous one.
- Commands are single-flight: while one runs, others get
  `{"error": "Server busy processing another command. Try again."}`. A stuck busy flag
  force-resets after 30 s (server-side watchdog in `src/dev/mcp_interaction_server.gd`).
- Therefore: **never run two game-driving agents/sessions in parallel.**

### The wrong-project trap (check this when anything looks off)

The old project at `D:\Dropbox\MyGames\GottaBounce` ALSO ships an MCP server on port 9090
(verified: its `src/dev/mcp_interaction_server.gd` listens on 9090). A mis-quoted `--path` (this
repo's path has spaces; `Start-Process` does not quote args for you) can silently launch the WRONG
project, and gbplay will happily drive it. First move whenever behavior seems alien:

```powershell
python tools/gbplay.py eval "return get_tree().current_scene.scene_file_path"
```

Expect `res://scenes/Arena.tscn` (or the scene you launched). Anything else → `stop_game.ps1`,
relaunch via `run_game.ps1` (which quotes `--path` correctly).

## gbplay.py — full command table

Source: `tools/gbplay.py` (stdlib-only Python; Python 3.13 on PATH). The game must be running
**windowed** (not headless) with the `McpInteractionServer` autoload (it is in the default
autoload list). Every command prints the JSON response to stdout, **truncated to 4000 chars**;
exit code 1 if the response contains an `"error"` key. Client socket timeout: 35 s.

| Command | Exact form | What it does |
|---|---|---|
| screenshot | `python tools/gbplay.py screenshot tools/out/x.png` | Captures viewport → PNG at `x.png` (creates dirs). Response echoes width/height/bytes. Default path `screenshot.png` if omitted. |
| key | `python tools/gbplay.py key SPACE` | Taps a keyboard key (press, auto-release next frame). |
| hold | `python tools/gbplay.py hold D --ms 500` | Holds a key for `--ms` (client sleeps; min 50 ms), then releases. |
| action | `python tools/gbplay.py action boost` | Taps an input-map action (press, ~50 ms, release). |
| hold-action | `python tools/gbplay.py hold-action boost --ms 800` | Holds an input-map action for `--ms` (min 50 ms). |
| eval | `python tools/gbplay.py eval "return Tuning.gravity"` | Runs arbitrary GDScript in the live game; see "eval specifics". |
| scene | `python tools/gbplay.py scene res://scenes/SmokeTest.tscn` | `change_scene_to_file` — switch scene without relaunching. |
| tree | `python tools/gbplay.py tree` | Full scene-tree summary (name + class, recursive). Output is large — expect the 4000-char truncation. |
| ui | `python tools/gbplay.py ui` | Visible Control nodes with position/size/text (Label/Button/LineEdit/RichTextLabel text included). |
| perf | `python tools/gbplay.py perf` | fps, frame times, memory, object/node counts, draw calls. Interpretation targets → skill `gottabounce-diagnostics-and-tooling`. |
| click | `python tools/gbplay.py click 640 360` | Mouse click at window coords (x y floats; left button). |
| raw | `python tools/gbplay.py raw '{"command":"gamepad","params":{...}}'` | Send any wire command directly (full command list in `src/dev/mcp_interaction_server.gd` — ~100 commands incl. `get_property`, `set_property`, `call_method`, `pause`, `time_scale`, `await_signal`, `wait`). |
| script | `python tools/gbplay.py script probe.jsonl` | Run a newline-JSON command sequence; see ".jsonl scripts". |
| burst | `python tools/gbplay.py burst tools/out/seq 10 --interval 0.5` | N screenshots into `<dir>/frame_000.png` … at `--interval` seconds (default 0.5). This is "watching gameplay": read 3-6 frames as a sequence and judge motion. |

Known doc wart: gbplay's own docstring shows `action jump` as an example — there is **no `jump`
action** in this project's input map. Real actions are below.

### Input actions (project.godot, 2026-07-03)

| Action | Keyboard (physical) | Gamepad |
|---|---|---|
| `move_left` / `move_right` / `move_up` / `move_down` | A / D / W / S | left stick |
| `boost` | SPACE | button 0 (A) |
| `super` | K | button 2 (X) |
| `use_powerup` | L | button 1 (B) |
| `menu_accept` | ENTER | button 0 |
| `menu_back` | ESCAPE | button 1 |

Prefer `action`/`hold-action` (survives keybind changes). `key`/`hold` accept letters, digits,
`SPACE`, `ENTER`, `ESC`, `TAB`, arrows `UP/DOWN/LEFT/RIGHT`, `SHIFT/CTRL/ALT`, `F1`–`F12`
(full map in `_init_key_map()`); other single characters fall through as unicode.

### eval specifics (the sharp edges)

- Your code is wrapped as the body of a function (`_run()`), so **you must `return` a value** or
  the result is `null`. `eval "Tuning.gravity"` → null; `eval "return Tuning.gravity"` → 1600.
- Autoloads are global identifiers: `Tuning`, `EventBus`, `KillPipeline`, `PowerupSystem`,
  `GravityField`. Do NOT write `$Tuning` — that is node-path syntax and will not resolve here,
  AND in a double-quoted PowerShell string `$Tuning` interpolates to empty. (docs/PIPELINE.md's
  example `eval "return $Tuning.gravity"` is broken for both reasons — known doc drift.) In
  PowerShell use single quotes: `python tools/gbplay.py eval 'return Tuning.gravity'`.
- Live-tuning works (multi-statement via GDScript semicolons):
  `python tools/gbplay.py eval "Tuning.gravity = 1500.0; return Tuning.gravity"` — verified:
  static (wrapper accepts arbitrary GDScript; not live-run-checked). Persist wins back to
  `src/core/Tuning.gd` afterward — see skill `gottabounce-tuning-and-flags`.
- Multi-line code is fine: each line of your string is indented into the wrapper.
- `await` is supported (the wrapper awaits `_run()`), e.g.
  `eval "await get_tree().create_timer(2.0).timeout; return 1"`.
- Compile errors come back as `Failed to compile GDScript (error N). Check syntax.` — usually
  quoting damage from the shell.
- Results are JSON-converted: Vector2 → `{x,y}`, Node → `{_type,class,name,path}`, arrays/dicts
  recursively. Remember stdout truncates at 4000 chars — dump big data to a file inside eval
  (GDScript `FileAccess`) or narrow the query.
- eval (and the whole server) runs with `PROCESS_MODE_ALWAYS`, so it works while the game is paused.

### .jsonl scripts (repeatable input sequences)

`python tools/gbplay.py script <file>.jsonl` — one JSON object per line, `#` lines and blanks
skipped. Each line is a raw wire command, plus two client-side pseudo-commands:

```jsonl
# hold boost 1s, screenshot, wait, release-style sequence
{"command": "key_hold", "params": {"action": "boost"}}
{"command": "sleep", "params": {"seconds": 1.0}}
{"command": "screenshot_to", "params": {"path": "tools/out/probe_mid.png"}}
{"command": "key_release", "params": {"action": "boost"}}
{"command": "eval", "params": {"code": "return get_tree().current_scene.state"}}
```

- `sleep` sleeps client-side (`params.seconds`, default 1).
- `screenshot_to` captures to `params.path`.
- Output: `{"success": true, "steps": N, "results": [...]}` (truncated at 4000 chars like all output).
- This is the mechanism for pre-registered, repeatable feel probes; the ready-made probe scripts
  and their interpretation live in skill `gottabounce-diagnostics-and-tooling`.

### Wire protocol (5 lines)

1. TCP 127.0.0.1:9090, served by autoload `src/dev/mcp_interaction_server.gd` inside the game.
2. Request = one line of JSON + `\n`: `{"command": "...", "params": {...}}`. Response = one line of JSON.
3. One client at a time; a new connection disconnects the old.
4. Single-flight: concurrent commands get a busy error; server busy-watchdog resets after 30 s.
5. gbplay is a thin stdlib client over this — anything gbplay can't express, send via `raw`.

## Headless Playtest harness (numbers without rendering)

Source: `src/dev/Playtest.gd` (scene `res://scenes/Playtest.tscn`). It instances Arena.tscn,
installs scripted/bot input on P0, logs physics + kills once per second, prints a summary, quits.
Run via the Bash tool (paths quoted; `dangerouslyDisableSandbox: true`):

```bash
"C:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe" --headless \
  --path "D:/Dropbox/MyGames/GottaBounce - FablePause" res://scenes/Playtest.tscn -- botwar 60
```

Everything after `--` is `<mode> <seconds>` (defaults: `observe` 20).

| Mode | P0 input | Measures |
|---|---|---|
| `observe` | nothing (bounces in place) | bot behavior in isolation |
| `hover` | scripted jetpack traversal (right → diagonal-up → up → left → idle) | speed/gravity feel numbers |
| `duel` | crude scripted fighter (up/right/left pulses) | simple combat probe |
| `botwar` | replaced by a level-4 `InputBot` | bot-vs-bot combat: do they fight or suicide? |

Output: per-second lines `[t= 12.0] P0 pos(x,y) spd fuel [DEAD] | ... | bounces=N`, kill lines
(`>> KILL: P2 killed P3 (ring_out)` / `>> RINGOUT/SUICIDE: ...`), then a
`========== PLAYTEST SUMMARY ==========` block: max speed seen, tunnel frames, total bounces,
per-player max speed, ringouts/suicides, kills.

**Tunnel detection:** `FLOOR_TUNNEL_Y := 1860.0` — an ALIVE player below that y is real
tunneling (physics bug); the void above it is legit Smash-style recovery space. Any nonzero
`tunnel frames` is a finding.

Notes: the headless run still starts the 9090 server, so the one-instance rule applies to
Playtest runs too. The harness self-quits after `<seconds>`. Its `ScriptProvider` advances by
`1.0 / Engine.physics_ticks_per_second` (120 tps here) — the old 1/60 hardcode that ran scripts
2x fast is already fixed; story in skill `gottabounce-debugging-playbook`. What the summary
numbers must look like to PASS → skill `gottabounce-validation-and-qa`.

## Match recordings (WK-93) — frame-by-frame motion evidence

Owner (2026-11-14): "do you ever record a video of like 20 seconds of a match then analyze it frame by
frame?" — now standard evidence for any motion / feel / bot / hazard-motion change (WEEKEND_LOOP tick 4).

```powershell
powershell -File tools/record_match.ps1 -Name wk93_brawl20 -Arena pendulum_heights -Levels 3,3,3,3 -Seconds 20 -Seed 11
```

- **Godot Movie Maker** (`--write-movie ... --fixed-fps 30 --quit-after N`): every frame is rendered at a
  fixed 1/30 s game step regardless of machine speed (immune to WK-91 throttling / hitches), so frame k is
  exactly t = k/30 s of game time. Wall time is slower than real time (AVI ~1-2x, PNG ~8x realtime).
- **Boot path:** `res://scenes/dev/RecordBoot.tscn` (`src/dev/RecordBoot.gd`) reads `key=value` user args
  (after `--`): `name mode arena levels seconds seed aim_legacy hazard_legacy pendulum_test stamp`, writes
  `GameConfig.match_config` (SINGLE arena, kills_to_win 99), installs `MatchRecorder` (scenes/dev/
  MatchRecorder.tscn) on the ROOT, then changes scene to Arena.tscn. The recorder swaps EVERY seat (incl.
  human seat 0) to an `InputBot` at `levels`, quits after `seconds` of COMBAT/SUDDEN_DEATH time.
- **Script params:** `-Mode brawl|rocketball|dropshot|trials -Arena <level name> -Levels 1,3,5,2 -Seconds 20
  -Fps 30 -Seed N -AimLegacy -HazardLegacy -PendulumTest N -Every 10 -Format avi|png -KeepPng -NoStamp -Force`.
  `-AimLegacy` / `-HazardLegacy` flip the WK-94 / WK-96 A/B statics (InputBot.aim_sweep_enabled,
  MovingHazard.legacy_motion) for BEFORE recordings in the same build. `-PendulumTest N` is a QA fixture:
  N times it drops a living player exactly where a pendulum ball will be ~0.12 s later (contact check).
- **Output** `tools/out/rec/<Name>/` (folder has a `.gdignore` so the editor never imports frames):
  `frameNNNNNNNN.jpg` (AVI default; split from Movie Maker's MJPEG `movie.avi`), `data.json`, `sheet.png`
  (every Nth frame from COMBAT start, labelled `f# t state`), `sheet_overlay.png` (per-player marker +
  trail + aim line, thick white = super aim, red ring = pendulum ball), `aim_report.png` (each super-aim
  window: aim angle per physics tick + per-tick step vs the Tuning cap), `godot.log(.err)`, and a printed
  report (aim windows by bot level, hazard contacts/smashes, event counts, pendulum_test hits).
- **data.json:** `frames[{f,t,st,p[{i,l,x,y,sx,sy,vx,vy,a,sa,stun,dead,fuel,vis}],hz[{sx,sy,v}]}]` once per
  rendered frame (`f` == movie frame index == the number on the small REC stamp at the bottom of each
  frame; `sx/sy` are window px — rec_sheet rescales to the frame size), `aim_windows[]` (per-physics-tick
  super-aim path + max step), `events[]` (super_fired, smashed incl. hazard smashes, hazard_shoved,
  killed, pendulum_test_*), `hazards[]` (MovingHazard QA counters + per-contact log).
- **More analysis:** `python tools/rec_sheet.py tools/out/rec/<Name> --range 300:420 --every 1 --prefix swing`
  (dense sheet of a span), `--strobe 300:402` (one frame with every frame's pendulum-ball position as a dot:
  spacing = speed), `--report`. Read individual frames with the Read tool — LOOK at them.
- **One-instance rule applies:** the recording instance binds 9090 too. The script aborts if any Godot
  process is running (never `stop_game.ps1` another agent's game); `-Force` overrides.
- Movie Maker renders at the project viewport size (1920x1080) regardless of `--resolution`.

## SmokeTest scene

`res://scenes/SmokeTest.tscn` (`src/dev/SmokeTest.gd`): a deliberately ugly ball-on-floor scene
proving the whole loop end-to-end — rendering, input injection (WASD force, `boost` = upward
kick), physics, and the TCP server. Its label live-prints ball position/velocity and the last
inputs, so a screenshot after `hold-action boost` proves input actually reached the game. Use it
when you suspect the loop itself, not the game. (It is exempt from the "no debug rectangles"
rule — it is a harness, not game content.)

```powershell
powershell -File tools/run_game.ps1 res://scenes/SmokeTest.tscn
python tools/gbplay.py hold-action boost --ms 300
python tools/gbplay.py screenshot tools/out/smoke_check.png
powershell -File tools/stop_game.ps1
```

## Parse gate (operating command)

Run after ANY `class_name` change or new script (rebuilds the global class cache); it is a
no-crash gate ONLY, never a sign-off (doctrine → skill `gottabounce-validation-and-qa`):

```bash
"C:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe" --headless \
  --path "D:/Dropbox/MyGames/GottaBounce - FablePause" --editor --quit
```

Then grep the output for: `Parse Error`, `hides a native`, `Failed to load script`,
`not declared` (terms from CLAUDE.md). Clean grep = gate passed.

## Scene targets

| Scene | Root | Use |
|---|---|---|
| `res://scenes/Arena.tscn` | Node2D + `src/modes/PartyMatch.gd` | THE game (main scene; default boot) |
| `res://scenes/Playtest.tscn` | Node + `src/dev/Playtest.gd` | headless metrics harness |
| `res://scenes/SmokeTest.tscn` | Node2D + `src/dev/SmokeTest.gd` | loop-integrity smoke test |

Boot another scene: pass it to `run_game.ps1` (arg 1) or hot-switch a running game with
`python tools/gbplay.py scene res://scenes/X.tscn`. UI scenes live under `scenes/ui/`.

## Artifact conventions — tools/out/

`tools/out/` is the screenshot/log dumping ground; it is gitignored (along with `*.log`), and
Godot writes harmless `.import` sidecars next to PNGs because tools/out sits inside the project.
Naming taxonomy observed in the existing corpus (2026-07-03) — follow it:

| Prefix / pattern | Meaning |
|---|---|
| `smoke_*` | smoke-test loop checks |
| `rl_*` | round-loop QA pass |
| `pu_*` | powerup QA (`pu_f1_*` fix-verification, `pu_p3_*` powerup #3, …) |
| `c<N>_*` | screenshot evidence for numbered QA criterion N of the active spec |
| `qa3_* / qa4_* / qa5_*` | QA pass number; sub-tags like `qa3_chain_1_fired_down.png` narrate a sequence |
| `watch_<STATE>_<a>_<b>.png` | match-watch checkpoint at PartyMatch state STATE (e.g. `watch_ROUND_END_10_9.png`) |
| `lethality_* / fix_*` | lethality-v2 evidence / post-fix re-checks |
| `*_raw.png` | raw AI art generation pre-processing (art pipeline — see skill `gottabounce-art-pipeline`) |
| `<name>/frame_NNN.png` | burst directories (`qa4_bumper_seq/`, `cyan_burst/`, …) from `gbplay burst` |
| `qa3_match2_log.json` | eval-dumped kill log; shape: `{"result": {"kills": [{attacker, victim, cause, clock, round, state}], "rounds": [{round, deltas, scores_after, end_state}]}}` |

Rule of thumb: name = `<workstream or criterion>_<what the frame shows>.png`, so a reviewer can
audit evidence without opening the session transcript. Screenshots are evidence only if someone
actually reads them — see skill `gottabounce-validation-and-qa`.

## Resolution note

Screenshots capture the **window** backbuffer, not the design viewport: with `run_game.ps1`'s
`--resolution 1280x720`, PNGs come out 1280x720 while the game's design resolution is 1920x1080
(stretch mode `canvas_items` scales content). Verified statically: existing QA PNGs measure
1280x720 (one early `smoke_1.png` predating the resolution flag is 1920x1080). Consequence: any
"is it readable at N px" judgment on a screenshot is at 2/3 design scale — on-screen sizes in
briefs assume 1920x1080.

## Quick symptom pointers

| Symptom | First move | Deep triage |
|---|---|---|
| Port 9090 dead / connection refused | `stop_game.ps1`, check `$env:TEMP\gottabounce_run.log[.err]`, relaunch | skill `gottabounce-debugging-playbook` |
| Behavior looks like a different game | wrong-project check one-liner (above) | skill `gottabounce-debugging-playbook` |
| `Server busy` responses | wait ≤30 s (watchdog), don't parallel-drive | this file, one-instance rule |
| eval returns null | you forgot `return`, or PowerShell ate a `$` | eval specifics above |
| Runs act slow / stale window | zombie Godot processes → `stop_game.ps1` | skill `gottabounce-debugging-playbook` |

## Provenance and maintenance

Verified 2026-07-03 by direct reads of: `tools/run_game.ps1`, `tools/stop_game.ps1`,
`tools/gbplay.py` (in full), `src/dev/mcp_interaction_server.gd` (protocol + command dispatch +
eval wrapper), `src/dev/Playtest.gd`, `src/dev/SmokeTest.gd`, `project.godot` (main scene,
autoloads, input map, viewport, 120 tps), `scenes/*.tscn`, `docs/PIPELINE.md`, `.gitignore`,
`tools/out/` directory listing, `tools/out/qa3_match2_log.json`, and PNG dimensions via Pillow.
**No live run was performed** (port 9090 rule) — all command behavior is `verified: static`
(read from the scripts/server source), including: eval semicolon multi-statement, `scene`
hot-switching, `.jsonl` execution, burst timing, and the busy-watchdog reset.

Re-verification one-liners for drift-prone facts:
- run_game args/log paths: `Read tools/run_game.ps1` (17 lines of logic; re-read on any change)
- gbplay command set: `python tools/gbplay.py --help` or `Read tools/gbplay.py` (~160 lines)
- Input actions: `Grep -n '^\w+=\{' project.godot` (or read the `[input]` section)
- Main scene: `Grep 'run/main_scene' project.godot` → expect `res://scenes/Arena.tscn`
- Playtest modes/floor line: `Grep -n 'FLOOR_TUNNEL_Y|_mode ==' src/dev/Playtest.gd`
- Server port/watchdog: `Grep -n 'PORT|BUSY_TIMEOUT' src/dev/mcp_interaction_server.gd`
- Wrong-project trap still real: `Test-Path "D:\Dropbox\MyGames\GottaBounce\src\dev\mcp_interaction_server.gd"`
- Live scene check (needs running game): `python tools/gbplay.py eval "return get_tree().current_scene.scene_file_path"`

Known doc drift flagged here: docs/PIPELINE.md's eval example `"return $Tuning.gravity"`
(PowerShell interpolation + `$` node-path syntax — use `Tuning.gravity`); gbplay docstring's
`action jump` example (no such action). Left UNVERIFIED (live-run only): exact screenshot
latency, whether `--resolution` is honored on all display configs, watchdog timing under load.
