# GottaBounce (Fable rebuild) — Studio Operating Manual

Frantic 2D physics party brawler: **Duck Game × Smash Bros, no guns** — every surface bounces,
jetpacks are movement AND weapon, last one flying wins. Godot 4.7 / GDScript. Steam-quality bar.

**This is an AI-run studio.** The human owner installs tools/auth only — he does NOT playtest or
review. All validation is ours. See `docs/STUDIO.md` for roles, `docs/STATUS.md` for current state.

## Read order on fresh context
1. `docs/STATUS.md` — where we are, what's next (ALWAYS current — see enforcement below)
2. `docs/VISION.md` — game identity, pillars, art direction
3. `docs/GAME_ESSENCE.md` — what the game IS + the fantasy-fit check EVERY role must run (guards
   against building spec-correct components that aren't the game we're making)
4. `docs/PIPELINE.md` — how we validate, generate art, test
5. `docs/reference/ARCHITECTURE.md` — code seams (old project; INV list) · `docs/reference/` — the old
   project's docs (good design, failed execution). NOTE: there is no top-level `docs/ARCHITECTURE.md`.

## Non-negotiables (violating these killed the last attempt)
- **Depth-first.** One slice to genuinely-good before widening. Never claim "done" for "compiles."
- **Headless = no-crash gate only.** Real validation = run the game rendered, screenshot it, LOOK at
  the screenshots, drive input, watch behavior. `tools/run_game.ps1` + `python tools/gbplay.py`.
- **Look like a real game from day one.** No debug rectangles, no OS-default widgets, no SVG-circle
  "art". If an asset doesn't exist yet, generate it properly (see `docs/PIPELINE.md` art pipeline).
- **All feel constants in `src/core/Tuning.gd`.** Levels are data (JSON), never hardcoded.
- **UI is built as .tscn scenes + Theme resource**, never imperative `Button.new()` walls.
- **After every commit: update `docs/STATUS.md`** (enforced by post-commit hook reminder).

## How to run & validate
- Godot console exe: `C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`
  (needs `dangerouslyDisableSandbox: true` on shell calls).
- Parse gate (run after ANY class_name change): `<exe> --headless --path . --editor --quit`
  then grep for `Parse Error|hides a native|Failed to load script|not declared`.
- Rendered playtest: `powershell -File tools/run_game.ps1 [res://scenes/X.tscn]` then
  `python tools/gbplay.py screenshot tools/out/shot.png` / `key` / `hold-action` / `eval` / `tree`.
  Stop with `tools/stop_game.ps1`. ALWAYS stop stray Godot processes if runs act slow.
- Godot 4 gotchas: no `class_name` matching native classes; autoloads use `load()` not class_name
  types; rebuild class cache (`--editor --quit`) after adding class_name scripts; UI under
  `CanvasLayer`; annotate types on Variant-derived expressions (`var x: bool = ...`).

## Structure
`src/` core|entities|systems|modes|ui|dev · `scenes/` · `levels/` (JSON) · `assets/` ·
`tools/` (gbplay.py driver, run/stop scripts, art tools) · `docs/` (living) · `docs/reference/` (old).
