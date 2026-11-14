---
name: ux-review
description: >-
  Gamepad-first rendered review of a GottaBounce menu, screen, or HUD against
  docs/COUCH_CONVENTIONS.md and the ui-ux-designer screen checklist. Drives the real screen with
  raw pad events AND keyboard, captures every state, and returns Ship / Fix / Reject with
  backlog-ready findings. Load when asked to "review/grade a screen", "check the menus with a pad",
  "is this screen couch-ready", or before any menu/HUD slice is called done. Do NOT load for
  designing a new screen (that is the ui-ux-designer's UX spec), for in-match feel or
  combat QA (qa-playtester / gottabounce-validation-and-qa), or for a deep accessibility audit
  (accessibility-specialist).
---

# UX review (rendered, gamepad-first)

Reviews the BUILT screen, never the .tscn or a spec alone. Owner: ui-ux-designer (approval
authority). Anyone may run it to produce evidence; only the ui-ux-designer's verdict ships a screen.

## 0. Inputs
- The rules: `docs/COUCH_CONVENTIONS.md` (shared couch/gamepad conventions). If it is missing,
  say so in the report and grade against the "Screen checklist" in
  `.claude/agents/ui-ux-designer.md` alone.
- The screen's UX spec in `docs/specs/` or `docs/briefs/` if one exists (grade against it), the
  owner's UI feedback (`docs/feedback/owner_2026-07-10_ui_audit.md` and newer), `assets/ui/theme.tres`.

## 1. Launch (one game at a time)
Only ONE rendered game can run (port 9090). Check for stray Godot processes, then
`powershell -File tools/run_game.ps1 [res://scenes/...]` with `dangerouslyDisableSandbox: true`.
ALWAYS finish with `powershell -File tools/stop_game.ps1`.

## 2. Drive it with a pad first
Use the Bash tool for raw JSON (PowerShell mangles the quotes). Press = value 1 then release =
value 0; `device` 0-3 = P1-P4.
```
python tools/gbplay.py raw '{"command":"gamepad","params":{"type":"button","index":0,"value":1,"device":0}}'
python tools/gbplay.py raw '{"command":"gamepad","params":{"type":"button","index":0,"value":0,"device":0}}'
```
Buttons: A=0 B=1 X=2 Y=3 Back=4 Start=6 LB=9 RB=10 DpadUp=11 Down=12 Left=13 Right=14.
Left stick: `"type":"axis","index":0` (X) / `1` (Y), value -1..1, then return it to 0.
Then repeat the key paths with keyboard (`python tools/gbplay.py key ...`). Screenshot after every
input that should change focus or state (`gbplay screenshot tools/out/uxr_<screen>_<n>.png`) and
use `burst` for transitions. READ every PNG.

## 3. What to exercise
- Every focusable element reachable by d-pad, by stick, and by keyboard; focus order sensible.
- A confirms, B backs out one level, Start behaves as the conventions say — on every screen.
- Second/third/fourth pad (`device` 1-3): join, navigate, ready; who owns which cursor is obvious.
- States: empty slots, locked items (press them — is there feedback?), unlock celebration, 1P vs
  4P, disconnect mid-screen if the screen supports pads joining.
- Input during transitions: press A/B mid-animation — honored, buffered, or eaten? (eaten = Fix).
- After every transition exactly one element is visibly focused.
- Readability: shoot at 1280x720 (x1.5 for 1080p sizes); critical text clear of the outer ~5%.
- Feedback: each press has visible response; confirm via `play_sfx` call sites in the screen's
  script that it also has a sound.

## 4. Verdict
```
## UX review - <screen> - <date> - <commit>
Verdict: Ship | Fix | Reject
Conventions: <which COUCH_CONVENTIONS rules checked; any NOT ASSESSED and why>
Findings:
1. <what> - evidence tools/out/uxr_... - rule broken - fix - P0-P3 / S-M-L - owner
Press counts: boot->first bounce = N, match end->rematch = N
```
Ship only when nothing P0/P1 remains. A rule you could not exercise is NOT ASSESSED, never a pass.
Hand the findings list to the `bug-triage` skill / producer for `docs/BACKLOG.md`.
