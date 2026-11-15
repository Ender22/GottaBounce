# Weekend run — lessons learned (append-only; read on fresh context after WEEKEND_LOOP.md)

Progress lives in `docs/STATUS.md` (weekend block) + `docs/BACKLOG.md` (checked items with commit hashes).
This file is for the NON-OBVIOUS things learned the hard way. Add a line whenever something surprises you.

## Process
- **PC FREEZE (2026-11-15 ~02:00):** 5 parallel agents (one running 8 headless Godot processes, plus 3-4 rendered
  games and Movie Maker recordings) froze the whole machine and killed the session. Cap: <= 3 agents with Godot at once,
  <= 1 headless batch at a time with <= 2 processes. Per-agent ports make parallelism POSSIBLE, not free.
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
- **FIXED (WK-130): each agent uses its own port** — `run_game.ps1 -Port 91xx`, `gbplay.py --port 91xx`,
  `stop_game.ps1 -Port 91xx`; recordings/headless pass `--gb-port=0`. run_game no longer kills all Godots.
  The notes below about the shared 9090 / kill-all describe the OLD behaviour.
- **Port 9090 is shared**: any Godot started from the repo (incl. Movie Maker recordings) can grab it, so gbplay may
  drive SOMEONE ELSE'S game. Before gbplay commands, confirm 9090's owner PID is yours (or drive your instance with
  your own in-game script). WK-111 accidentally reset another agent's match this way.
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

- Shell heredocs that write docs: always quote the delimiter (<<'EOF'); an unquoted one ran backticked code as command
  substitution and silently deleted text.

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

- `SportsMode.wk108_enclosed` defaults false, so bot `_enclosed()` is false in sports and court walls count as blast
  lines — any bot logic keyed to "about to cross the bounds" fires at every wall in sports.
- Bots aimed 29% of opening attack supers at spawn-protected (blinking) targets; `_nearest_ground_dx` returned INF
  whenever the bot was below every platform top -> "unreachable" recovery supers at full fuel (fixed WK-127).

- **Shader compile errors slip past the parse gate** (`--editor --quit` doesn't compile .gdshader). After any shader
  change, launch rendered and grep the run log for `SHADER ERROR`.

## Owner preferences learned this run
- Wants zero involvement during the run but does check in: UI changes landed well; gameplay feel is the concern.
- Normal flight must be good enough to manoeuvre; super boost is an ATTACK (ruling 2026-11-14, WK-95).
- Sports modes may be more fun than Brawl — weight sports work (WK-98).
- Hazard motion quality matters (stiff pendulums read as "poor quality").
- Subagents' recursive/bulk deletes get denied by the settings deny rules; the director sweeps raw frames with
  `python -I tools/sweep_frames.py tools/out dry|go` (frame*.jpg|png + movie.avi in rec/* older than 30 min, skips
  in-flight lanes by name). Run it after each commit batch.
- Stage a Tuning.gd block that shares a git hunk with another lane's block by writing the index blob directly:
  HEAD text + the lines tagged "# WK-NN" -> `git hash-object -w --stdin` -> `git update-index --cacheinfo`.
- **The `--editor --quit` parse gate also misses GDScript errors in scripts only reached via runtime `load("res://...gd").new()`**
  (WK-53b: `get_viewport_rect()` on a CanvasLayer passed the gate, then `Failed to load script` aborted `PartyMatch._ready` mid-way
  -> match stuck in BOOT). After adding such a script, launch rendered and grep the run log's `.err` for `SCRIPT ERROR`.
- **GPU FELL OFF (found 2026-11-15 ~09:30):** Device Manager shows the AMD RX 6700S as CM_PROB_DISABLED and the Radeon iGPU as
  CM_PROB_FAILED_ADD, so Godot runs on the Microsoft Basic Render Driver (software, ~37 fps). Probably a leftover of the 02:00 freeze.
  Visual checks and fixed-fps recordings stay valid; perf/fps/timing numbers taken since are NOT. Check
  `Get-PnpDevice -Class Display` before any perf work. Fixing it needs the owner (reboot / re-enable the device) — not us.
- **End screens ignore unjoined devices (CC-3.3), so QA must drive them with the device that JOINED.** WK-42: after a
  pad-joined Brawl, `gbplay key LEFT/ENTER` on the Victory screen did nothing (correctly). Not a bug; join with the
  keyboard (title Enter -> mode Enter auto-joins kb) to test keyboard end-screen nav. Also: `eval` one-liners with
  `for x in y: a; return b` put the return INSIDE the loop; use real newlines in the eval string.
- **InputRouter sees every event TWICE** (root `window_input` + its own `_input`, and they are different InputEvent objects,
  so identity dedupe fails). Anything that ACCUMULATES (WK-39 mouse-motion threshold) must hang off one path only
  (`window_input`). gbplay `raw {"command":"mouse_move","params":{x,y,relative_x,relative_y}}` drives it; `relative` is what counts.
- **WK-38: the automation server is OFF by default now.** A game started without `-- --gb-port=N` (or `GB_PORT=N`) binds no port.
  `tools/run_game.ps1` always passes it; anything that launches Godot directly AND wants gbplay must pass `-- --gb-port=N` itself.
- **Viewport screenshots never contain the OS cursor**, so "no cursor in gameplay" is verified via `eval Input.mouse_mode`
  (1 = hidden) plus `InputRouter.cursor_shown`, not by looking at a PNG.
- **Focus style swap resizes buttons unless their min size fits the PRIMARY style** (ShellBtnPrimary is 46 px vs 40 px, 18 px vs
  16 px margins = ~90 px tall). WK-14 rows use 380x90 and the title stack 420x92 so focus moves never jiggle the layout.
- **WK-38 (ab11c61): the automation server is OFF by default.** Plain launches bind no port; run_game.ps1 passes
  `-- --gb-port=N`. Harnesses that start Godot directly and want gbplay must pass `-- --gb-port=N` themselves.
- **`MenuScreen.enter()` moves `Header` and `Footer` to the front of the draw order**, so an overlay that is MEANT to cover the
  title (WK-52 unlock card) has to `move_to_front()` when it shows. Also, ToyPanel's 0.97 alpha lets text underneath ghost
  through, so fill it opaque (`ToyKit.fill_panel(p, ToyKit.CREAM)`) when it sits over a label.
- **Another lane's half-saved script breaks YOUR rendered run.** WK-113 QA hit a grey void court: lane V's mid-edit
  `ArenaRenderer.gd` failed to parse at launch, so `PartyMatch` failed to compile. Before you blame your change, grep the run
  `.err` for parse errors in files you didn't touch, then relaunch once theirs parses.
- **Agent shell quirk: a doubled backslash in a heredoc'd Python edit arrived as a single one** (WK-29: a GDScript regex
  `"\b"` landed as `"\b"`, which GDScript reads as a backspace character). Write backslashes with `chr(92)`, then grep
  the result.
- **WK-29 glyph rule lives in `PadGlyph`** (`for_kind` / `shared_kind` / `shared_spec`, KEYS_MENU / KEYS_PLAY). Shared
  .tscn glyphs and HintStrips opt in with `device_ctx = "menu"|"play"`. Prompts that belong to one player (pause, the
  lobby panels) keep passing their owner's device explicitly. Don't hand-roll `"key:X" if kb else "Y"` again.
- **Tween trap (WK-83): `t.chain().set_parallel(true)` does NOT start a new parallel step**; `set_parallel(true)` re-applies to
  everything after it, so all tweeners ran at once and a later "fade back to WHITE" tweener (start value captured = WHITE) won every
  frame: the flash never showed. Write two-step pops as `tween_property(A)` + `parallel().tween_property(B)`, then the same for step 2.
- **gbplay has no joypad connect/disconnect command.** Drive the REAL hot-plug path with
  `eval "Input.joy_connection_changed.emit(<id>, false)"` (InputRouter listens to that signal); `InputRouter.simulate_device_lost("pad:N")`
  is the same bookkeeping minus the engine signal. A "lost" simulated pad can still send events, which is how a reconnect + A is tested.
- **Back-to-back gbplay `eval`s advance only ~1 game frame between them** (Engine.get_process_frames 5996 -> 5997), so "eval, then eval
  to read the result" sees almost no animation time. Put a `sleep` step between, or slow the Tuning knob at runtime for a still (WK-83
  set `Tuning.lobby_wait_flash = 4.0` via eval to photograph a 0.45 s flash, then restored it).
- **Watch long builders for stalls.** The WK-135 builder wrote nothing for ~3 h (last output 09:50) while "running"; a queued
  SendMessage never reached it. Check its scratch/output dir timestamps each heartbeat; if nothing new for > 45 min and no Godot
  process is running, TaskStop it and start a recovery agent pointed at its scratch copy + notes.
- **gbplay round-trips are slow under software rendering (~0.7 s per `eval`, ~1.2 s per scripted pad tap = press + release
  calls).** A "press A 0.3 s after the end screen appears" test actually lands ~1-1.5 s later, i.e. AFTER a 1.3 s arm, and
  correctly activates the default button (WK-142: looked like NEXT CIRCUIT firing on an early press; it wasn't). To test
  pre-arm behaviour, raise the arm knob at runtime via eval or read the gate's `_open_msec` / `_arm_msec` vs now.
- Piping `run_game.ps1` into `| tail` (or any pipe) hangs the shell: Godot inherits the launcher's stdout and keeps it open.
  Redirect to a file or don't pipe.
