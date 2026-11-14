# Weekend Loop — unattended polish run (started 2026-11-14)

The owner played the build and called it "a shitty prototype with a lot of weird things, nonsense
controls (B opens pause on Xbox) ... 2 users using 2 controllers totally cant select their character
like a normal game". He is NOT involved: this run is about what the AI studio can do on its own.
Goal: turn GottaBounce into a proper, conventional, fun couch party game. Re-read this file at the
start of every loop tick (it survives context compaction; your memory of earlier ticks may not).

## Ground rules
- Branch `weekend/polish` only. Never switch branches, push, rebase, reset --hard, or clean
  (deny rules in `.claude/settings.json` enforce most of this). The owner's
  `PLAY GOTTABOUNCE.bat` plays whatever is checked out, so the working tree must always be playable:
  never end a tick with a broken parse gate or a half-applied change uncommitted.
- Deny rules match the WHOLE command text: a commit message mentioning "push", "clean" or
  "reset --hard" after `git` gets the commit denied. Reword the message.
- Commit ONLY the files you changed, by explicit path (`git add -A` is forbidden — parallel agents).
- LESSONS: append anything non-obvious you learn to `docs/WEEKEND_LESSONS.md` the moment you learn it (context
  can be lost at any time). Read it on fresh context right after this file.
- Bookkeeping helper: `python tools/wk_mark.py done <hash> "<line>" WK-NN ...` (or `tried "<reason>" WK-NN`).
- After each commit: update `docs/STATUS.md` (top block "WEEKEND POLISH RUN") + tick the item in
  `docs/BACKLOG.md`. Commit both.
- Respect `CLAUDE.md` non-negotiables, `Tuning.gd` DO-NOT-TOUCH list (skill
  `gottabounce-change-control`), INV contract (skill `gottabounce-architecture-contract`).
- One rendered game PER PORT (WK-130). Each agent picks its own port — 9100 + agent slot (9101,
  9102, ...) — and passes it everywhere: `run_game.ps1 -Port N`, `gbplay.py --port N`,
  `stop_game.ps1 -Port N` (or `GB_PORT=N`). Never run no-arg `stop_game.ps1` / `run_game.ps1 -KillAll`
  while other agents run — they kill every Godot. Recordings bind no port (`--gb-port=0`). Take
  perf/feel timings with no other rendered game running (CPU sharing).

## One tick
1. `git status` + `git log -3` — if a previous tick left uncommitted work, finish/validate it or
   revert just those files (`git restore <path>`), never leave it dangling.
2. Open `docs/BACKLOG.md`; take the highest-priority unchecked item (or 2-3 small related ones).
   Skip items marked BLOCKED (needs owner/money/external) — note why.
3. Build: delegate to `gameplay-programmer` (or level-designer / art pipeline) with a self-contained
   brief, or do it directly if small. Programmer runs the parse gate.
4. Verify RENDERED: `qa-playtester` (or self) drives the real game — keyboard AND simulated pads
   (`gbplay.py raw '{"command":"gamepad",...}'`), screenshots LOOKED at, saved to
   `tools/out/wk/<item-id>_*.png`. UI changes also get a `ui-ux-designer` Ship/Fix/Reject verdict
   against `docs/COUCH_CONVENTIONS.md`; visual art changes get `art-director`.
   **Motion / feel / bot-behaviour / hazard-motion changes ALSO need a WK-93 recording**
   (`powershell -File tools/record_match.ps1 -Name <item-id>_<what> ...`, fixed-fps Movie Maker, see the
   run-and-playtest skill "Match recordings") with its contact sheet / aim report LOOKED at — stills
   and outcome stats miss motion pathologies. Before/after recordings when the change alters motion.
5. Only on a pass: commit with message `weekend: <ID> <summary>`, update STATUS + BACKLOG.
   On a fail: fix once or twice; if still failing, revert the item's files, mark it
   `[~] attempted — <why>` in BACKLOG, move on. Never loop forever on one item.
5b. Disk hygiene after each commit: delete the item's raw recording frames (keep sheets/reports/data.json) and any
   scratchpad project copy it made (check `df -h /c /d`; keep >= 20 GB free on both).
6. Every ~6 items (or when the backlog's top is exhausted): a fresh `creative-director` cold
   playthrough of the integrated build; new findings go to BACKLOG via `producer` re-rank. Every
   ~12 items: a `soak-test` bot-match run for crashes/leaks.

## Priorities (producer keeps BACKLOG ranked by these)
P0 broken normal couch play (controls nonsense, can't join/select, dead ends, crashes) >
P1 obviously amateur vs Smash/Duck Game/TowerFall > P2 polish/juice > P3 nice-to-have.
Depth over width: make the core brawl + front-end flow genuinely good before new content/modes.
