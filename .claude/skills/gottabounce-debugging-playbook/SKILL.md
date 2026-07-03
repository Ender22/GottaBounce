---
name: gottabounce-debugging-playbook
description: Symptom-to-fix triage for GottaBounce failures. Load when something is BROKEN or WEIRD - game won't launch, port 9090 dead or connecting to the wrong project, gbplay hangs / "Server busy" / eval returns null, black or wrong screenshots, Parse Error / "hides a native class" after adding class_name, UI dragging with the camera, game stuck in slow motion, kills not registering, wrong player credited, particles vanishing, missing-art warnings, .ps1 parse failures. Do NOT load for normal operation of the game (see skill gottabounce-run-and-playtest), measurement/metrics (gottabounce-diagnostics-and-tooling), machine setup (gottabounce-build-and-env), or the full history behind an incident (gottabounce-failure-archaeology).
---

# GottaBounce debugging playbook

**What this covers:** every known failure mode of this project with a one-line story
(which past incident taught us this), the exact discriminating command to confirm the
cause, and the fix. Use it when a symptom appears; run the discriminator BEFORE guessing.

**When NOT to use this:** launching/driving the game normally → skill
`gottabounce-run-and-playtest`. Extracting match metrics → `gottabounce-diagnostics-and-tooling`.
Fresh machine setup / Windows shell doctrine → `gottabounce-build-and-env`. The full narrative
of any incident named below → `gottabounce-failure-archaeology`. What evidence counts for a
verdict → `gottabounce-validation-and-qa`.

Jargon used below, defined once:
- **parse gate** — running the Godot editor headless once (`--editor --quit`) so it parses ALL
  scripts and rebuilds the global class cache; output is grepped for errors. A crash gate, never a sign-off.
- **hitstun** — the timed helpless state after being smashed (`_stun_timer` in `src/entities/Player.gd`).
- **smash license** — the eligibility predicate for a lethal hit: attacker recently fired a super
  OR is a flying stunned body, AND closing speed >= `Tuning.smash_impact_min`.
- **zombie process** — a leftover Godot instance from a previous run; it hogs CPU and holds port 9090.

All file paths are repo-relative from `D:\Dropbox\MyGames\GottaBounce - FablePause`.
All tuning values and statuses below are as of 2026-07-03.

## Master triage table

| # | Symptom | Likely cause | Jump to |
|---|---------|-------------|---------|
| 1 | Game won't launch / port 9090 unreachable | Zombie Godot process, or launch failed | §1 |
| 2 | gbplay talks to a game, but behavior/scene is alien | You are driving the WRONG PROJECT (old repo also serves 9090) | §2 |
| 3 | gbplay hangs, times out, or returns "Server busy" | Single-flight lock held by a stuck command | §3 |
| 4 | `eval` returns `"result": null` | Code has no `return` statement | §4 |
| 5 | `eval` says "Failed to compile GDScript" | Indentation/syntax inside the wrapped snippet | §4 |
| 6 | Screenshot black/empty or errors | Game launched headless, not windowed | §5 |
| 7 | Screenshot shows the wrong scene | Scene arg not passed / change_scene not done | §5 |
| 8 | Parse Error / "not declared" after adding a `class_name` | Stale global class cache | §6 |
| 9 | "hides a native class" error | Project class named after a Godot built-in | §6 |
| 10 | Autoload errors "identifier not declared" for a project class | Autoloads can't resolve `class_name` at parse time | §6 |
| 11 | HUD/UI drifts or shakes with the camera | UI not under a `CanvasLayer` | §7 |
| 12 | Whole game stuck in slow motion | `Engine.time_scale` left below 1.0 (Juice hitstop) | §8 |
| 13 | Timed things run ~2x too fast/slow | A `1/60` tick hardcode at 120 physics tps | §9 |
| 14 | Jetpack flame / particles vanish when a property changes | `CPUParticles2D.lifetime` write restarts the emitter | §10 |
| 15 | Kills not registering at all | Smash license/threshold unreachable | §11 |
| 16 | Landing a super kills the ATTACKER | `_stunned_by` pairwise immunity broken/regressed | §11 |
| 17 | Idle player farms points / wrong kill credit | Chain-credit reassignment broken | §11 |
| 18 | Edge kills near bumpers never land; sudden-death % too high | Bumper-save: stunned victim refueled/un-stunned on bumper contact | §12 |
| 19 | Console warnings about missing art / layers skipped | Graceful skip-if-missing: the warning names the exact path | §13 |
| 20 | Sprite has baked FAKE checkerboard "transparency" | Generation artifact | §13 |
| 21 | .ps1 script fails to parse / garbage characters | Non-ASCII (em-dash) in a PowerShell file | §14 |
| 22 | `NativeCommandError` when running Godot from PowerShell | `2>&1` on a native exe in PowerShell 5.1 | §14 |
| 23 | A key stays held forever in-game | `key_hold` sent, release never sent | §3 |
| 24 | Scary "Unreferenced static string" / "Pages in use at exit" on kill | Normal shutdown noise from force-killed Godot | §14 |

---

## §1. Game won't launch / port 9090 dead

**Story:** zombie Godot processes hogging CPU and port 9090 have wasted whole sessions
(CLAUDE.md non-negotiable: "ALWAYS stop stray Godot processes if runs act slow").

Discriminate:
```powershell
Get-Process | Where-Object { $_.ProcessName -like 'Godot*' }
```
- **Processes listed but you didn't start them this run** → zombies. Fix:
  ```powershell
  powershell -File tools/stop_game.ps1
  ```
  (kills every `Godot*` process; safe anytime). Note `tools/run_game.ps1` already does this
  kill itself before launching (`tools/run_game.ps1:11`), so a plain relaunch also clears zombies.
- **No process and run_game.ps1 printed `WARNING: server not reachable after 20s`** → the game
  crashed or failed at boot. Read the launch logs:
  ```powershell
  Get-Content "$env:TEMP\gottabounce_run.log" -Tail 40
  Get-Content "$env:TEMP\gottabounce_run.log.err" -Tail 40
  ```
  A script error at boot usually means you skipped the parse gate — go to §6.
- **Server up but a second driving agent/session exists** → port 9090 is exclusive; exactly ONE
  game instance and ONE driver at a time. Never run two game-driving agents in parallel.

## §2. Connected to 9090, but it's the WRONG project

**Story:** the OLD project at `D:\Dropbox\MyGames\GottaBounce` (sibling directory) runs an
identical TCP server on the same port (verified: its `src/dev/mcp_interaction_server.gd` also
declares `PORT: int = 9090`). A mis-quoted `--path` (PowerShell `Start-Process` does not quote
args; both paths contain no/`- ` spaces differently) can silently launch the wrong game, and
gbplay will happily drive it.

Discriminate (run BOTH after every launch you didn't do via `tools/run_game.ps1`):
```powershell
python tools/gbplay.py eval "return get_tree().current_scene.scene_file_path"
python tools/gbplay.py eval "return ProjectSettings.globalize_path('res://')"
```
Expected: `res://scenes/Arena.tscn` (this repo's main scene, `project.godot:7`) and a path
ending in `GottaBounce - FablePause/` (note the ` - FablePause` suffix). Anything else = wrong
project. Fix: `tools/stop_game.ps1`, then relaunch with `powershell -File tools/run_game.ps1`
(it derives the project path from its own location, so it cannot pick the wrong repo).

## §3. gbplay hangs, times out, or replies "Server busy"

**Story:** the in-game server (`src/dev/mcp_interaction_server.gd`) is single-flight: a `_busy`
flag rejects every command while one is processing, with a 30s watchdog that force-resets a
stuck flag (`BUSY_TIMEOUT: float = 30.0`, lines 12-13 and 33-39). The gbplay client gives up
at 35s (`TIMEOUT = 35.0`, `tools/gbplay.py:34`).

- **`{"error": "Server busy processing another command. Try again."}`** → a previous command
  (usually an `eval` awaiting something that never fires) still holds the lock. Wait ~30s for
  the watchdog, retry. If it repeats forever, the game loop itself is wedged: `tools/stop_game.ps1`
  and relaunch.
- **Client hangs then `socket.timeout` at ~35s** → same cause seen from the other side, OR the
  game window is not pumping frames (crashed render thread). Screenshot to discriminate (§5);
  if screenshot also dies, restart the game.
- **Reconnecting does not clear busy**: a new client connection replaces the old one but does
  NOT reset `_busy` (only a detected disconnect or the watchdog does). Don't hammer retries —
  wait out the 30s.
- **Stuck held key (symptom 23):** `hold`/`hold-action` in gbplay sends `key_hold`, sleeps
  client-side, then sends `key_release` (`tools/gbplay.py:105-112`). If the client dies mid-hold,
  the game keeps the key pressed indefinitely. Fix without restart:
  ```powershell
  python tools/gbplay.py raw '{"command":"key_release","params":{"key":"RIGHT"}}'
  python tools/gbplay.py raw '{"command":"key_release","params":{"action":"boost"}}'
  ```

Full command anatomy and the wire protocol → skill `gottabounce-run-and-playtest`.

## §4. eval returns null / won't compile

**Story:** eval code is wrapped inside a generated `func _run():` body
(`mcp_interaction_server.gd:541-577`); a function with no `return` returns null.

- **`"result": null`** → you forgot `return`. Wrong: `eval "Tuning.fuel_per_bounce"`.
  Right: `eval "return Tuning.fuel_per_bounce"`. Multi-statement one-liners work with GDScript
  semicolons: `eval "Engine.time_scale = 1.0; return Engine.time_scale"`.
- **`"Failed to compile GDScript (error 1). Check syntax."`** → the wrapper indents every line
  of your code with one TAB (`_indent_code`). If your snippet has its own nested blocks, indent
  them with TABS, not spaces — mixed tab/space indentation is a GDScript parse error
  (`verified: static` — from reading the wrapper; not live-tested).
- `await` works inside eval (the wrapper awaits `_run()`), but anything awaiting a signal that
  never fires will hold the busy lock → §3.

## §5. Black, empty, or wrong-scene screenshots

**Story:** gbplay's screenshot grabs the live viewport texture
(`mcp_interaction_server.gd:346-360`); a headless game has nothing to grab. gbplay's own
docstring: "The game must be running WINDOWED (not headless)".

- **Screenshot errors or returns garbage** → game was started with `--headless`. Headless is
  ONLY the no-crash gate (parse gate, Playtest harness). For anything visual, launch windowed:
  `powershell -File tools/run_game.ps1` (1280x720 window at 50,50 — screenshots are 1280x720).
- **Right game, wrong scene** → run_game.ps1 boots the main scene `res://scenes/Arena.tscn`
  unless you pass a scene arg: `powershell -File tools/run_game.ps1 res://scenes/Playtest.tscn`.
  Or switch live: `python tools/gbplay.py scene res://scenes/Arena.tscn`. Confirm with the §2
  one-liner.
- **Also confirm you're not on the wrong PROJECT** → §2.

## §6. Parse errors, class_name, and the stale class cache

**Story (old project, cost real time — docs/reference/LESSONS_LEARNED.md):** three distinct traps.

Run the parse gate after ANY `class_name` add/rename/delete (use the Bash tool, not PowerShell — see §14):
```bash
"/c/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe" --headless --path . --editor --quit 2>&1 | grep -E "Parse Error|hides a native|Failed to load script|not declared"
```
Empty output = clean. (Command form per CLAUDE.md; needs `dangerouslyDisableSandbox: true`.
NEVER run this while a windowed game is up — one Godot instance at a time.)

- **"not declared in the current scope" for a class you just added** → stale global class cache
  (`.godot/global_script_class_cache.cfg`). The `--editor --quit` run above IS the fix — it
  rebuilds the cache. Per-scene loads miss this; always use the full editor parse.
- **"hides a native class"** → your `class_name` collides with a Godot built-in (`Container`,
  `Timer`, `Tween`...). Rename with a project prefix (old project: `Container` → `PropContainer`).
- **Autoload can't resolve a `class_name` / `is SomeClass` fails in an autoload** → autoloads
  cannot reliably resolve `class_name` globals at parse time. Reference scripts via
  `load()`/`preload()` inside autoloads, or test with `is Node` + groups. This repo's own server
  script has no class_name for exactly this reason (`mcp_interaction_server.gd:5`).
- **Variant-typed expression errors** → annotate: `var x: bool = ...` (CLAUDE.md gotcha).

## §7. UI drifts, shakes, or scrolls with the camera

**Story (old project):** HUD elements placed in the world tree get dragged by the `Camera2D`
(shake/scroll). Fix: all UI lives under a `CanvasLayer` (CLAUDE.md non-negotiable; MatchHUD
already does). Discriminate: `python tools/gbplay.py tree` and check the offending Control's
ancestry for a CanvasLayer.

## §8. Game stuck in slow motion

**Story:** the Juice hitstop effect sets `Engine.time_scale` down to 0.04-0.12 and eases back
(`src/systems/Juice.gd:229-245`). If the awaiting coroutine dies mid-freeze the game stays
slow. A defensive reset exists on scene teardown (`Juice.gd:247-250`) but not for every path.

Discriminate / fix live:
```powershell
python tools/gbplay.py eval "return Engine.time_scale"
python tools/gbplay.py raw '{"command":"time_scale","params":{"time_scale":1.0}}'
```
Note: PartyMatch round timing divides by `Engine.time_scale` for real-time bookkeeping
(`src/modes/PartyMatch.gd:159`), so a stuck scale distorts feel but not the match clock math.

## §9. Timers/phases run ~2x wrong (tick-rate hardcodes)

**Story:** this project runs physics at **120 ticks/s**. The old Playtest ScriptProvider
hardcoded `1/60` per tick and ran its phases 2x fast; fixed to
`1.0 / float(Engine.physics_ticks_per_second)` (`src/dev/Playtest.gd:39-40`; same pattern in
`src/core/InputBot.gd:44`). If any scripted duration, cooldown, or per-tick integration is ~2x
off, grep for the hardcode:
```bash
grep -rnE "1\.0 ?/ ?60|0\.01666" src/
```
Fix: use `Engine.physics_ticks_per_second` (or `delta`). Never assume 60.

## §10. Particles vanish when touched per-frame

**Story (found during powerup validation, commit cdd925d):** writing
`CPUParticles2D.lifetime` RESTARTS the emitter — a per-frame write kills the flame entirely.
The Unlimited-Boost cyan flame uses a transition latch: only touch `lifetime`/`color_ramp`
when the state actually changes (see `_fire_cyan_now` in `src/entities/Player.gd`).
Fix pattern: guard property writes with `if new_state != _latched_state:`.

## §11. Combat: kills not registering / inverted kills / wrong credit

The three historic lethality bugs. One-line stories here; full narratives + QA numbers →
skill `gottabounce-failure-archaeology`. Mechanics theory → `game-feel-reference`.

**A. No kills at all (the founding bug).** Session-2 QA: `smash_impact_min` (then 800) >
`normal_boost_max_speed` (760) — the kill gate was mathematically unreachable by boost-rams.
As of 2026-07-03 the design is intentional two-tier: plain boost (max 760) must NOT smash;
only a super (`super_boost_impulse_full = 2800`) or a flying stunned body reaches
`smash_impact_min = 900` (`src/core/Tuning.gd:42,50,80`). Eligibility predicate:
`src/entities/Player.gd:616`. If kills vanish after a tuning change, re-run the reachability
audit (method → skill `gottabounce-analysis-toolkit`):
```powershell
python tools/gbplay.py eval "return [Tuning.smash_impact_min, Tuning.normal_boost_max_speed, Tuning.super_boost_impulse_full]"
```

**B. Landing a super kills the ATTACKER (inverted kill, CRITICAL, fixed 587d0a1).** The stunned
victim was itself a licensed smasher and counter-smashed its attacker next frame (attacker died
9/9). Fix: `_stunned_by` pairwise smash immunity — a stunned body can smash anyone EXCEPT the
player who stunned it (`Player.gd:49`, predicate at `:616`, cleared at `:315`). If this
regresses, check those lines first.

**C. Idle player farms points (fixed 587d0a1).** Chain-body kills credited the flying body, so
an idle P1 scored 12. Fix: credit reassigns to the launcher via `_stunned_by`
(`Player.gd:629-630`). Verified then: idle P1 → 0.

## §12. Edge kills never land near bumpers / sudden-death rate too high

**Story (short):** bumpers unconditionally refunded fuel AND cleared hitstun on contact, so a
smashed victim hitting a side bumper was always saved (QA: 1 off-stage kill in 23 rounds, SD
27-33% vs <=25% target). Designer ruling (spec v2.1, commit ea0c133): **hitstun ends by TIME,
never by surface contact** — the fix adds a `_stun_timer <= 0.0` guard inside `_on_bounced()`.
Full incident narrative → skill `gottabounce-failure-archaeology` (Incident 10). **This state is
VOLATILE:** as of 2026-07-03 the fix was staged uncommitted in the working tree; the moment the
pending `src/entities/Player.gd` change commits, this bug flips to fixed — re-verify against
current state before relying on this section.

Discriminate whether the fix is present in your checkout. The signal is a `_stun_timer <= 0.0`
guard **inside `_on_bounced()`** — a bare grep also hits an unrelated pre-existing decrement at
~line 314, so scope it to the function:
```bash
grep -n -A12 "func _on_bounced" src/entities/Player.gd | grep "_stun_timer <= 0.0"
git log --oneline -1 -- src/entities/Player.gd   # still 587d0a1 = fix uncommitted
```
If the guard is present (hit at ~line 557): the dry-reflect rule is in; re-run spec §9 tests
6c/6d/11/13/14/15 before claiming fixed (criteria discipline → skill
`gottabounce-validation-and-qa`). If absent: do NOT "fix" it ad-hoc — implement exactly spec
`docs/specs/v0_combat_lethality.md` §2.3a. NEVER reopen the refund/stun-clear-on-bumper gate;
the sanctioned fallback for "dry reflect feels silent" is bigger FX/SFX only (DECISIONS
2026-07-03 entry).

## §13. Art symptoms

One-line coverage; the deep home is skill `gottabounce-art-pipeline`.

- **Console warnings about missing textures / "layer skipped"** → by design: renderers skip
  missing assets gracefully with a one-shot warning that NAMES the expected path
  (`src/systems/ArenaRenderer.gd:632` `_warn_once`; `src/core/LevelLoader.gd:56-58` for
  unported level-object types; `src/entities/Player.gd:162` falls back to pink). Fix = read
  the warning text, place/generate the asset at that exact path. STATUS notes decal warnings
  should be gone — if they reappear, the path differs (check `assets/world/grass/decals/`, `assets/bg/`).
- **Fake checkerboard "transparency" baked into a generation** →
  `python tools/art.py check <file>` catches it; `python tools/art.py keyout in.png out.png --tol 40`
  fixes (verified against `tools/art.py` usage text).
- **Asset looks like the PREVIOUS generation** → a missed ChatGPT download click silently
  reuses the last file (corrupted hills_far once). Verify Downloads timestamp before intake.
  → skill `gottabounce-art-pipeline`.

## §14. Windows shell symptoms

One-line coverage; deep home is skill `gottabounce-build-and-env`.

- **.ps1 fails to parse / mojibake** → non-ASCII (em-dashes, smart quotes) in the script.
  Keep every .ps1 ASCII-only (docs/STATUS.md watch list).
- **`NativeCommandError` running Godot from PowerShell** → PowerShell 5.1 wraps native-exe
  stderr under `2>&1` into error records. Use the Bash tool for Godot runs (§6 shows the form).
- **Godot launches the wrong thing via `Start-Process`** → it does not quote args; the project
  path contains spaces. Prefer `tools/run_game.ps1`, which handles quoting (`run_game.ps1:15`).
- **"Unreferenced static string to 0" / "Pages in use at exit" after force-killing Godot** →
  shutdown artifacts, not bugs (docs/reference/LESSONS_LEARNED.md). Ignore.
- **Godot launches blocked by sandbox** → shell calls launching Godot need
  `dangerouslyDisableSandbox: true` (CLAUDE.md).

## When you find a NEW failure mode

Fix it through normal change control (→ skill `gottabounce-change-control`), record it in
docs/STATUS.md "Watch out for", and add a row + section here so the next session doesn't
rediscover it.

## Provenance and maintenance

Authored 2026-07-03 against commit `0e315b9` (working tree had one uncommitted `Player.gd`
edit — the §12 dry-reflect fix in flight). Every command was verified **statically** (by
reading the scripts/servers they invoke — no game or Godot process was launched per authoring
constraints). All gbplay invocations, the parse-gate command, and expected eval outputs are
therefore `verified: static`; incident QA numbers are quoted from docs/STATUS.md and commit
messages, not re-measured.

Sources read in full or in relevant part: `tools/gbplay.py`, `tools/run_game.ps1`,
`tools/stop_game.ps1`, `src/dev/mcp_interaction_server.gd`, `src/systems/Juice.gd`,
`src/entities/Player.gd` (state/credit/bounce sections), `src/core/Tuning.gd` (cited vars),
`src/dev/Playtest.gd`, `src/core/InputBot.gd`, `src/systems/ArenaRenderer.gd`,
`src/core/LevelLoader.gd`, `project.godot`, `tools/art.py` usage text, CLAUDE.md,
`docs/STATUS.md`, `docs/reference/LESSONS_LEARNED.md`, git log/show for cdd925d, 587d0a1,
03894ac, ea0c133; old project's `src/dev/mcp_interaction_server.gd` (port check only).

Drift-prone facts — re-verify with one-liners before trusting:

| Fact | Re-verify |
|------|-----------|
| §12 dry-reflect fix committed? | `git log --oneline -1 -- src/entities/Player.gd` (587d0a1 = uncommitted) and `grep -n -A12 "func _on_bounced" src/entities/Player.gd \| grep "_stun_timer <= 0.0"` (scope to the func — a bare grep also hits the unrelated decrement at ~line 314) |
| Smash thresholds (900 / 760 / 2800) | `grep -nE "smash_impact_min|normal_boost_max|super_boost_impulse_full" src/core/Tuning.gd` |
| Server port + busy timeout (9090 / 30s) | `grep -nE "PORT: int|BUSY_TIMEOUT" src/dev/mcp_interaction_server.gd` |
| gbplay client timeout (35s) | `grep -n "TIMEOUT = " tools/gbplay.py` |
| Old project still serving 9090 | `grep -n "9090" "D:\Dropbox\MyGames\GottaBounce\src\dev\mcp_interaction_server.gd"` |
| Main scene + autoload list | `grep -nA8 "autoload" project.godot` |
| Godot exe path | CLAUDE.md "How to run & validate" |
| Physics tick rate (120) | `grep -n "physics_ticks_per_second" project.godot` (verified 2026-07-03: `project.godot:84` = 120) |

UNVERIFIED / static-only items:
- §4 tab-indentation requirement inside eval: reasoned from `_indent_code`, never live-tested.
- All "expected output" claims for gbplay/eval commands: `verified: static`.
