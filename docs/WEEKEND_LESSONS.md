# Weekend run — lessons learned (append-only; read on fresh context after WEEKEND_LOOP.md)

Progress lives in `docs/STATUS.md` (weekend block) + `docs/BACKLOG.md` (checked items with commit hashes).
This file is for the NON-OBVIOUS things learned the hard way. Add a line whenever something surprises you.

## Process
- **Validate motion with real recordings, not stills/bursts.** Owner spotted bot super-aim spinning wildly from a
  20 s watch; our screenshot bursts never caught it. Use the WK-93 Movie Maker recorder (fixed fps, every frame)
  for any motion / feel / bot / hazard change and look at the contact sheet frame by frame.
- **Audit against genre conventions, not our own specs.** The B=pause and shared-cursor character select both
  "passed" their specs. `docs/COUCH_CONVENTIONS.md` is now the bar for every screen/control.
- **Parallelise by game slot.** Only one rendered game at a time (port 9090). Pattern that worked: one agent holds
  the game; others build code-only + parse gate and report "ready for rendered verification"; director
  messages them when the slot frees. Headless scene tests go in a scratchpad copy with McpInteractionServer removed.
- **`tools/run_game.ps1` ALSO force-kills every Godot process on start** (and stop_game.ps1 does too). With Movie
  Maker recordings running in parallel, launch Godot directly with run_game's args and stop by PID.
- **Parallel builders share files** (PartyMatch/SportsMode): a verified batch can't be committed while another
  builder's unverified hunks sit in the same file. Note the pending state in STATUS; commit both together.
- **Partial commits of mixed files: `python tools/stage_hunks.py <file> --exclude|--include REGEX [--list]`** stages
  only matching hunks (git add -p is interactive and unavailable). Pipe patches as BYTES on Windows.
- **`tools/stop_game.ps1` kills EVERY Godot process** (incl. other agents' headless runs). Check before using.
- **Deny rules match whole command text**: a commit message containing "reset --hard"/"push"/"clean" after `git`
  is denied. Reword.
- **Commit only your files by explicit path**; two agents' edits can share a file (PartyMatch) — commit them
  together after both verify, or sequence the agents.
- **Never edit docs/BACKLOG.md while a producer agent is re-ranking it** — it rewrites the whole file; IDs collided
  (two WK-99s). Producer runs alone on BACKLOG, director marks items only between producer runs.
- **Continue builders via SendMessage** (keeps their context) for follow-up slices — far cheaper than re-briefing.

- **DISK HYGIENE.** Raw recording frames (tools/out/rec/*/frameNNNNNNNN.jpg|png, ~45k files / 6.9 GB in one day,
  synced by Dropbox) and agents' scratchpad project copies (~2.2 GB each, 25 GB total) filled C: to 0 bytes and D: to
  4.5 GB, breaking batches mid-run. After an item commits, delete its raw frames (keep sheets/reports/data.json) and
  its scratch project copy. Check for junctions before any recursive delete of a scratch copy.

## Engine / game facts discovered
- **DISPLAY OFF = BOGUS PERF DATA.** When the laptop screen sleeps (15-min AC timeout) Windows Modern Standby caps a
  windowed game to ~30 Hz with ~500 ms present() stalls, then can freeze it entirely. All "16 FPS / 0.5 s hitch" data
  from 12:08-15:50 was this. The game really runs ~120 fps at 1080p. The director now runs a keep-awake script
  (SetThreadExecutionState, scratchpad/keepawake.ps1, background task) for the session. Before trusting any perf or
  timing number, confirm the screen was on (fps ~120). Physics-tick timers stretch under real hitches (8 ticks/frame).
- `create_timer(t, true, false, true)` in Godot 4.7 fires after ~3 frames regardless of t -> hit-stop is
  frame-rate dependent (WK-90).
- gbplay's simulated pads do NOT appear in `get_connected_joypads()` -> key devices off input EVENTS
  (InputRouter does this; device keys "kb" / "pad:N").
- `PartyMatch._ready` loaded islands_void.json as a placeholder and the powerup director kept its spawn points
  for every mode (fixed WK-86) — beware placeholder loads leaking state.
- Bots almost never self-KO (frame-perfect recovery, raycast + fuel math, L1 aim noise re-rolled per frame cancels
  out) — so bot-only matches hide the human self-fall problem; use human-sim drivers (WK-20a spec).
- A 1080p `gbplay screenshot` freezes the game ~1.25 s (CD2-05) — any wall-clock timing taken alongside screenshots is
  inflated; measure in game time or with Movie Maker recordings.
- Godot screenshot via eval without awaiting `RenderingServer.frame_post_draw` returns a stale frame; `save_png`
  stalls ~900 ms (pollutes timing measurements).
- Wide fonts: Lilita One is ~24% narrower than the old Segoe UI Black fallback; the ✓ glyph is not in it.

- Master bus clips (peaks +4.8 dB) from stacked bounce SFX + super blast — pre-existing; needs a master limiter
  (sound-designer WK-105 report).
- Raw last-touch goal credit makes ~50-75% of sports goals OWN GOALs (defenders deflect shots) — use a deflection
  rule crediting the shooter.

## Owner preferences learned this run
- Wants zero involvement during the run but does check in: UI changes landed well; gameplay feel is the concern.
- Normal flight must be good enough to manoeuvre; super boost is an ATTACK (ruling 2026-11-14, WK-95).
- Sports modes may be more fun than Brawl — weight sports work (WK-98).
- Hazard motion quality matters (stiff pendulums read as "poor quality").
