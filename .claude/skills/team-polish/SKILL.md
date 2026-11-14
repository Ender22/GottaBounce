---
name: team-polish
description: >-
  The Studio Director's orchestration recipe for one polish item end-to-end in the autonomous
  loop: pick from docs/BACKLOG.md -> builder (gameplay-programmer / level-designer / sound-designer)
  -> qa-playtester rendered verification -> the relevant gate (ui-ux-designer, art-director,
  accessibility-specialist, performance-analyst, creative-director) -> Director commits + updates
  STATUS + BACKLOG. Load at the start of each loop iteration or when unsure which roles a change
  needs. Do NOT load for triaging findings (bug-triage), deciding whether an item is worth doing
  (scope-check), or the mechanics of running the game (gottabounce-run-and-playtest).
---

# Team polish — one backlog item, done properly

Unattended. Nobody approves between phases; the gates below are the approval. One item at a
time, depth-first: do not start item N+1 until item N is committed or explicitly parked.

## 0. Pick
Top open item of `docs/BACKLOG.md` that is not blocked. L-sized or content-widening -> run
`scope-check` first and split. Mark it `in-progress`.

## 1. Build
Spawn the owning builder with a distilled brief (the item, its evidence, the files, acceptance
criteria stated as something a rendered check can show). Builders:
- code / systems / UI wiring -> `gameplay-programmer`
- level JSON -> `level-designer`
- audio wiring/mix -> `sound-designer`
- menu/HUD screen: `ui-ux-designer` writes/updates the UX spec FIRST, then `gameplay-programmer`
- new art: `art-director` brief first (`gottabounce-art-pipeline`)
Builder must pass the parse gate and a rendered smoke screenshot before returning. Return
contract: files changed, what was verified, what is untested.

## 2. Verify (rendered — never skip)
`qa-playtester` drives the real game against the acceptance criteria plus off-script abuse
(4 pads, mash, transitions). Evidence in `tools/out/`. FAIL -> back to step 1 with the evidence;
after two failed rounds on the same item, park it in BACKLOG with findings and move on.

## 3. Gate (only the gates the change touches)
| Change touches | Gate |
|---|---|
| any menu / HUD / screen | `ui-ux-designer` (skill `ux-review`) — Ship required |
| visuals, sprites, FX, backdrops | `art-director` — Ship required |
| text size, player colors, input, flashing | `accessibility-specialist` — no BLOCKING |
| particles, entity counts, new arena/circuit | `performance-analyst` — within budget |
| feel, pacing, camera, mode rules, anything a player would describe | `creative-director` fantasy-fit |
Fix verdicts loop to step 1. Independent gates run in parallel ONLY if they do not all need the
rendered game — only ONE rendered game can run at a time (port 9090). Serialize anything that
launches the game, and every role stops it (`tools/stop_game.ps1`) before the next starts.

## 4. Land (Director only)
- `git add` the specific files, commit on the current branch with a message naming the BL id.
- Update `docs/STATUS.md` (mandatory after every commit) and move the item to `## Done (recent)`
  in `docs/BACKLOG.md` with the hash. Add new findings surfaced during the work via `bug-triage`.
- Every few items, or after anything touching match flow, run `soak-test` (short form).

## Failure modes to watch
- An agent returns a fluent report but the files/screenshots it names do not exist -> treat the
  phase as failed, check `git status` / `tools/out/` yourself.
- An agent launches a background sweep and ends its turn "waiting" (has happened twice) -> take
  over with a bounded sample.
- "Compiles" or "headless passed" reported as done -> send back to step 2.
