---
name: gottabounce-build-and-env
description: Recreate or repair the GottaBounce dev environment from scratch on a Windows machine — Godot 4.7 console exe, Python 3.13 + Pillow, Chrome for art generation, the godot MCP server, repo path constraints, .gitignore conventions, and every Windows/PowerShell trap (quoting, ASCII .ps1, no &&, sandbox flag, NativeCommandError). Load this when setting up a new machine, when a tool "used to work" and now fails at the OS/shell layer, when Godot won't launch or launches the WRONG project, or when a fresh session needs the first-hour verification runbook. Do NOT load this for driving a running game (see skill gottabounce-run-and-playtest) or for symptom-by-symptom debugging of game behavior (see skill gottabounce-debugging-playbook).
---

# GottaBounce — build & environment setup (Windows)

**What this covers:** everything between "bare Windows machine" and "the validation loop
runs": installed tools with exact paths, repo-location constraints, the twin-project
port-9090 trap, .gitignore conventions, Windows/PowerShell shell traps, Claude-harness
setup notes, and a first-hour verification runbook.
**When NOT to use this:** operating the running game (commands, artifact conventions) →
skill `gottabounce-run-and-playtest`. Triage of in-game failures → skill
`gottabounce-debugging-playbook`. What counts as valid evidence → skill
`gottabounce-validation-and-qa`.

All volatile facts below are as of **2026-07-03**.

## 1. Machine prerequisites

| Tool | Exact location / version (2026-07-03) | Used for | Install note |
|------|----------------------------------------|----------|--------------|
| Godot 4.7 stable (console build) | `C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe` | Running the game, parse gate | The folder itself is named `Godot_v4.7-stable_win64.exe` — it is a DIRECTORY containing both `Godot_v4.7-stable_win64.exe` (windowed) and the `_console.exe`. Use the console exe. |
| Python 3.13 | `python` on PATH (3.13.7 verified) | `tools/gbplay.py` (game driver), `tools/art.py` (asset intake) | Any 3.13.x. |
| Pillow | 12.1.1 verified via `python -c "import PIL"` | `tools/art.py` only | `pip install pillow` — this is the ONLY third-party Python dependency. `tools/gbplay.py` is stdlib-only (argparse/base64/json/os/socket/sys/time). There is deliberately no `requirements.txt`. |
| Node.js | v22.19.0 on PATH | Runs the `godot` MCP server (`.mcp.json`) | Only needed if you use the MCP server (optional — see §6). |
| Google Chrome | any current | Art generation via ChatGPT (browser automation) | Chrome must be RUNNING before starting art generation — the browser extension connects only while Chrome is open (docs/STATUS.md "Watch out for"). Deep art workflow → skill `gottabounce-art-pipeline`. |
| Claude Code harness | project launchers `claude-here.bat` / `claude-here-resume.bat` in repo root | AI-studio sessions | See §7. |

**Why the console build of Godot:** `tools/run_game.ps1` redirects the process's
standard output/error to `%TEMP%\gottabounce_run.log` / `.log.err`. On Windows only the
`_console` build writes engine output to stdout; the plain exe detaches, so the logs
would be empty. (verified: static — run_game.ps1 lines 14–19 depend on redirected stdout.)

There is **no CI** (no `.github/`), no build server, and no export pipeline yet
(`export_presets.cfg` is gitignored). All validation is local and manual — see skill
`gottabounce-validation-and-qa` for the doctrine.

## 2. Repo location constraints — the twin-project 9090 trap

Two facts combine into the nastiest environment trap on this machine:

1. **The repo path contains spaces**: `D:\Dropbox\MyGames\GottaBounce - FablePause`.
2. **A sibling OLD project exists at `D:\Dropbox\MyGames\GottaBounce`** (the failed
   first attempt — kept untouched as reference). Its `src/dev/mcp_interaction_server.gd`
   ALSO declares `const PORT: int = 9090`.

Consequence: PowerShell's `Start-Process -ArgumentList` does NOT quote arguments for
you. If you hand-launch Godot with an unquoted `--path D:\Dropbox\MyGames\GottaBounce - FablePause`,
the argument is split at the first space, Godot resolves the path prefix
`D:\Dropbox\MyGames\GottaBounce` — the WRONG project — and it boots, listens on 9090,
and answers `gbplay.py` commands. Everything "works" while you drive the wrong game.

Defenses:
- `tools/run_game.ps1` already embeds quotes: `$argList = @("--path", "`"$proj`"", ...)`.
  Always launch through it, never hand-rolled `Start-Process`.
- After any launch, verify which project answered
  (command anatomy → skill `gottabounce-run-and-playtest`):
  ```
  python tools/gbplay.py eval "return get_tree().current_scene.scene_file_path"
  ```
  Expect a scene from THIS project (default `res://scenes/Arena.tscn`). (verified: static)
- **Exactly one game instance at a time.** Port 9090 is exclusive; `run_game.ps1` kills
  every `Godot*` process before launching, and `tools/stop_game.ps1` does the same as
  the universal cleanup. Never run two game-driving agents in parallel.

Do not move or rename the repo without auditing: `.mcp.json` (absolute `GODOT_PATH` and
server path), the `claude-here*.bat` launchers (they `cd /d "%~dp0"`), and any script
that assumes the current path.

## 3. From-scratch setup runbook

1. Install Godot 4.7 stable Windows x64 so the console exe sits at
   `C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe` (or place it
   elsewhere and update `.mcp.json` `GODOT_PATH` plus the `$godot` variable in
   `tools/run_game.ps1`; the studio-standard path is the one above and CLAUDE.md cites it).
2. Install Python 3.13 on PATH, then `pip install pillow`.
3. Clone/sync the repo to `D:\Dropbox\MyGames\GottaBounce - FablePause`.
4. Optional (MCP): install Node, and ensure `D:/Dropbox/MyGames/godot-mcp/build/index.js`
   exists (a separate checkout of godot-mcp, built to `build/`). Verified present 2026-07-03.
5. Optional (art): install Chrome; leave it running before any art-generation session.
6. Start Claude Code from the repo root (double-click `claude-here.bat`, or `claude` in
   a shell already cd'd there) — sessions must start in the project dir so CLAUDE.md,
   `.mcp.json`, and `.claude/` (agents, skills) are picked up.
7. Run the first-hour verification runbook (§4).

## 4. First-hour verification runbook

Run these in order on any new/repaired machine. Steps 2–4 are launch-and-look — labeled
`verified: static` because this skill's author confirmed the commands against the
scripts/source, not by a live run.

**Step 1 — parse gate (headless, no window, safe anytime):**
```bash
"/c/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe" --headless --path . --editor --quit 2>&1 | grep -E "Parse Error|hides a native|Failed to load script|not declared"
```
Run from the repo root, via the **Bash tool** (not PowerShell — see trap T4 in §5).
Empty grep output = pass. This also rebuilds Godot's global class cache. The parse gate
is a no-crash gate ONLY — it never counts as validation (skill
`gottabounce-validation-and-qa`). Shell calls that launch Godot need
`dangerouslyDisableSandbox: true` (CLAUDE.md).

**Step 2 — rendered smoke test** (verified: static):
```powershell
powershell -File tools/run_game.ps1 res://scenes/SmokeTest.tscn
```
`scenes/SmokeTest.tscn` (`src/dev/SmokeTest.gd`) is purpose-built to prove rendering,
physics, input injection, and the TCP interaction server end-to-end. Expect the script
to print `Started PID <n>; log: ...` then `Interaction server UP on 9090` within 20s.
If instead you get `WARNING: server not reachable after 20s`, read
`%TEMP%\gottabounce_run.log` and `.log.err`.

**Step 3 — screenshot + look at it** (verified: static):
```powershell
python tools/gbplay.py screenshot tools/out/env_check.png
```
Then actually open/Read the PNG. Expect the "SMOKE TEST — validation loop online" label
on a dark blue background. Screenshots come out at the 1280x720 window size even though
the project viewport is 1920x1080 (`project.godot` [display]; `run_game.ps1` passes
`--resolution 1280x720 --position 50,50`).

**Step 4 — wrong-project check + stop** (verified: static):
```powershell
python tools/gbplay.py eval "return get_tree().current_scene.scene_file_path"
powershell -File tools/stop_game.ps1
```
Expect `res://scenes/SmokeTest.tscn`. ALWAYS stop when done — stray Godot processes hog
CPU and steal port 9090.

Everything beyond this (driving input, bursts, scripts, Playtest harness) → skill
`gottabounce-run-and-playtest`.

## 5. Windows / PowerShell traps

The interactive shell is **PowerShell 5.1**. Each trap below has cost this studio real
time (sources: CLAUDE.md gotchas, docs/STATUS.md "Watch out for", tools/*.ps1).

| # | Trap | Symptom | Fix |
|---|------|---------|-----|
| T1 | PowerShell 5.1 has no `&&` / `\|\|` | `The token '&&' is not a valid statement separator` parser error | Use `;` or `if ($?) { ... }`, or run the chain in the Bash tool. |
| T2 | Non-ASCII characters in `.ps1` files (em-dashes, smart quotes) | Script fails to parse or mangles strings when read back | Keep all `.ps1` files ASCII-only (docs/STATUS.md). |
| T3 | `Start-Process -ArgumentList` does not quote args | Silently launches the WRONG project (old GottaBounce also serves 9090) — see §2 | Embed quotes as `run_game.ps1` does: `"`"$path`""`; always launch via `tools/run_game.ps1`. |
| T4 | `2>&1` on a native exe in PowerShell 5.1 wraps stderr lines in ErrorRecords | `NativeCommandError` noise; `$?` false despite exit code 0 | Run Godot commands (parse gate etc.) through the **Bash tool**, where `2>&1` behaves normally. |
| T5 | Sandboxed shell blocks Godot launch | Godot never starts / permission failure from harness shell calls | Pass `dangerouslyDisableSandbox: true` on any shell call that launches Godot (CLAUDE.md). |
| T6 | Zombie Godot processes | Slow runs, port 9090 taken, stale windows | `powershell -File tools/stop_game.ps1` (kills every `Godot*` process). `run_game.ps1` also does this before each launch. |
| T7 | Godot editor imports every PNG it sees — including screenshots | `tools/out/*.png.import` sidecar files appear (148 of them as of 2026-07-03) | Harmless. `tools/out/` is gitignored; never commit them, never "clean them up" as a task. |

## 6. MCP server "godot" (.mcp.json)

The repo checks in `.mcp.json`:

```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": ["D:/Dropbox/MyGames/godot-mcp/build/index.js"],
      "env": {
        "GODOT_PATH": "C:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe",
        "DEBUG": "false"
      }
    }
  }
}
```

- It runs a separate godot-mcp checkout at `D:/Dropbox/MyGames/godot-mcp` (built
  `build/index.js` verified present 2026-07-03) and points `GODOT_PATH` at the console exe.
- It is AVAILABLE but not the proven path: every documented studio workflow
  (docs/PIPELINE.md, docs/STATUS.md) uses `tools/run_game.ps1` + `python tools/gbplay.py`.
  Prefer those; treat the MCP tools as secondary. The MCP server launching its own Godot
  would collide with the one-instance/9090 rule (§2) — never mix the two in one session.

## 7. Claude-harness notes

- **Launchers**: `claude-here.bat` / `claude-here-resume.bat` in the repo root `cd /d`
  into the repo and start `claude --dangerously-skip-permissions` (resume variant adds
  `--resume`). They exist so sessions always start in the project dir.
- **Project subagents** in `.claude/agents/` (art-director, game-designer,
  gameplay-programmer, level-designer, qa-playtester) **register only after a session
  reload**. In a session where they haven't registered, run the role as a
  general-purpose agent with the role file's text quoted (docs/STATUS.md).
- The dev-driver TCP server is the autoload `src/dev/mcp_interaction_server.gd`
  (listens 127.0.0.1:9090) — it ships in the main autoload list in `project.godot`, so
  ANY launch of the game exposes it. Architecture implications → skill
  `gottabounce-architecture-contract`.

## 8. .gitignore conventions

Exact contents as of 2026-07-03:

```
# Godot
.godot/
*.tmp
export_presets.cfg

# OS / editor
Thumbs.db
Desktop.ini
*.swp

# Tool output (screenshots, playtest logs)
tools/out/
*.log
tools/__pycache__/
```

Rationale per entry:
- `.godot/` — Godot's import cache; machine-local, regenerated by the parse gate.
- `export_presets.cfg` — export config stays local until a real export pipeline exists.
- `tools/out/` — all screenshots/playtest artifacts are evidence, not source; they (and
  their `.png.import` sidecars, trap T7) never get committed.
- `*.log` — includes stray Godot logs.
- `tools/__pycache__/` — added in commit dfcb968 AFTER commit cdd925d accidentally
  committed `tools/__pycache__/gbplay.cpython-313.pyc` (dfcb968 also removed the .pyc).
  Note the pattern is `tools/__pycache__/` specifically, not a global `__pycache__/` —
  a Python file added outside `tools/` would need its own entry.

Repo hygiene facts: single linear `master` branch, no CI, small commits, never
`--no-verify`; the `.git/hooks/post-commit` hook only PRINTS a reminder ("STUDIO RULE:
update docs/STATUS.md to reflect this commit") — it enforces nothing. Change discipline
→ skill `gottabounce-change-control`.

## 9. Godot environment facts (quick card)

| Fact | Value | Source |
|------|-------|--------|
| Engine | Godot 4.7 stable, features `("4.7", "GL Compatibility")` | project.godot |
| Renderer | `gl_compatibility` (desktop and mobile keys) | project.godot |
| Viewport | 1920x1080, stretch mode `canvas_items` (window runs 1280x720 via run_game.ps1) | project.godot, tools/run_game.ps1 |
| Physics | 120 ticks/s (`common/physics_ticks_per_second=120`) — never hardcode 1/60 | project.godot |
| Main scene | `res://scenes/Arena.tscn` | project.godot |
| Autoload order | Tuning, GravityField, EventBus, KillPipeline, PowerupSystem, McpInteractionServer | project.godot (why order matters → skill `gottabounce-architecture-contract`) |
| Input actions | move_left/right/up/down, boost (Space), super (K), use_powerup (L), menu_accept/back | project.godot [input] |

Godot 4 language gotchas (stale class cache, class_name vs native, autoload `load()`,
CanvasLayer UI) are triaged in skill `gottabounce-debugging-playbook`; CLAUDE.md carries
the canonical short list.

## Provenance and maintenance

Verified 2026-07-03 by direct read of: `project.godot`, `.mcp.json`, `.gitignore`,
`tools/run_game.ps1`, `tools/stop_game.ps1`, `tools/gbplay.py` (header + imports),
`tools/art.py` (header + PIL import), `src/dev/SmokeTest.gd`,
`src/dev/mcp_interaction_server.gd` (PORT constant), `.git/hooks/post-commit`,
`claude-here.bat` / `claude-here-resume.bat`, `docs/PIPELINE.md`, `docs/STATUS.md`,
CLAUDE.md, `git show dfcb968` / `cdd925d` (the .pyc accident), plus filesystem checks:
Godot exe dir listing, `python --version` (3.13.7), `PIL.__version__` (12.1.1),
`node --version` (v22.19.0), old project's `src/dev/mcp_interaction_server.gd`
(`const PORT: int = 9090`), `D:/Dropbox/MyGames/godot-mcp/build/index.js` exists,
absence of `.github/` and `requirements.txt`, 148 `.import` sidecars in `tools/out/`.

No live game run was performed for this skill; the first-hour runbook steps 2–4 and the
wrong-project one-liner are `verified: static` (commands cross-checked against the
scripts and gbplay.py source only).

Re-verification one-liners for drift-prone facts:
- Godot exe still there: `ls "/c/Godot_v4.7-stable_win64.exe/"` (Bash)
- Python/Pillow/Node versions: `python --version; python -c "import PIL; print(PIL.__version__)"; node --version`
- MCP server path + GODOT_PATH: `cat .mcp.json`
- .gitignore drift: `git diff HEAD -- .gitignore` and `cat .gitignore`
- run_game.ps1 quoting/resolution/port-wait unchanged: `grep -n "argList\|9090\|resolution" tools/run_game.ps1`
- Autoloads / tick rate / main scene: `grep -n "autoload\|physics_ticks\|main_scene" -A7 project.godot`
- Old-project 9090 trap still live: `grep -n "PORT" "/d/Dropbox/MyGames/GottaBounce/src/dev/mcp_interaction_server.gd"`
- Post-commit hook text: `cat .git/hooks/post-commit`

UNVERIFIED / static-only items:
- "Console build required for stdout" — standard Godot-on-Windows behavior; inferred
  from run_game.ps1's stdout redirection, not re-proven on this machine.
- Chrome-must-be-running and the art-extension behavior — quoted from docs/STATUS.md,
  not exercised.
- Agent-registration-needs-session-reload — quoted from docs/STATUS.md, not re-tested.
- MCP "godot" server functionality — only the file path and config were checked; the
  server was never started (would risk a second Godot instance).
