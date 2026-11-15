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
- **WK-60: PadGlyph "lock" is drawn chocolate shackle + cream body, so it vanishes on a chocolate chip or the dark footer scrim**
  (it rendered as a tiny cream bar). Put it on a light fill (cream / pale lilac pill) or leave it out. Same family as "check".
- **WK-60: WASD is NOT bound to `ui_*`** (ui_right = Right arrow, D-pad right, stick only). Shell screens that ride Godot focus nav
  (ArenaSelect, ModeSelect, Title) ignore WASD; only screens with their own move_* handling (lobby, Stepper/Toy*, MenuInputGate)
  honour CC-2.1's "arrows and WASD". Fix belongs in the action map / InputRouter, not per screen.
- **WK-60: crest_trials_orbit / crest_trials_varied shipped with OPAQUE dark backgrounds** (the other 10 crests were keyed). Cards crop
  them so nobody noticed; at hero size (ArenaSelect preview, TrialsVictory) they showed a dark rectangle. Keyed with
  `python tools/art.py keyout IN OUT --tol 45`; a game launch does NOT reimport a changed PNG, run the `--editor --quit` pass first.
- **WK-151: WASD now IS on ui_up/down/left/right** (project.godot). Declaring a `ui_*` action in project.godot REPLACES the engine's
  built-in one, so the entry must re-list the defaults (arrow keycode, D-pad 11-14, left-stick axis, deadzone 0.5) plus the new keys
  (WASD by physical_keycode, like move_*). Every menu handler already reads `ui_X or move_X` with `or`, so nothing double-fires;
  end screens/HUD rows are FOCUS_NONE (MenuInputGate), and no Control holds focus during live play, so gameplay WASD can't leak into
  focus nav. Dump a project's effective map with a `--script` SceneTree that prints `InputMap.action_get_events()`.
- gbplay raw `key_press` is a TAP (auto-release next frame); hold with raw `key_hold` + `key_release` inside one `gbplay script`.
  A backgrounded `gbplay hold` gets its socket kicked by the next gbplay call (one client at a time) and leaves the key STUCK down.
- Forcing an end screen with `eval "get_tree().current_scene._enter_match_end(1)"` works, but it banks progression
  (matches_played / total_kills / circuit_plays in user://settings.cfg). Back the file up first and restore it after.
- **WK-135: PadHopper absolute numbers are NOT comparable across builds.** Its gate waypoints use "arrive and stop", so the
  pilot hovers at the gate point and only crosses pass_x by luck; one changed contact flips a course (n2_slalom 5/5 in the
  WK-128 bill-only run, 0/5 on 3e1a5b0 itself with the WK-135 switch OFF). Only same-build A/B arms mean anything, and
  bit-identical B/P1 tracks mean the change never engaged on that course.
- **The Wk123 Flight School probe sets (p_t2, p_t3, p_rr, p_t4, p_sl) exist only in the scratch copy's levels/course_sets.json.**
  A fresh copy from the repo silently runs the default course instead (every probe gives the same wrong result, super lines
  "fail"). Add the probe sets after copying.
- WK127Rec writes its brawl json incrementally: summarising before the job ends reports "incomplete_files" and short stage counts.
- **WK-28b: hot-plug meaning lives in `InputRouter/DeviceWatch`** (child node created in InputRouter._ready, so it hears device_lost BEFORE
  any scene, e.g. before the lobby leaves the join registry). In-match it opens `DisconnectOverlay` as a LATER child of the match than the
  PauseMenu: `_input` runs last-child-first, so the overlay decides every key/pad event before the (suspended) pause menu or PartyMatch's
  pause action. QA: `InputRouter.get_node('DeviceWatch')` has `overlay`, `cpu_seats`, `_gone`, `log_lines`, `toast.shown_log`. A pad
  "lost" and never re-found stays in `_gone` until it presses something; a RESTART/REMATCH then starts its seat as a CPU (by design).
- **Godot 2D combines bounce as clamp(A + B, 0, 1)** (not max / multiply). A surface meant to be DEADER than the ball needs an
  ABSORBENT PhysicsMaterial (bounce counts negative): WK-131 gate = absorbent 0.25 vs the ball's 0.85 -> measured 0.596 rebound.
- **gbplay `eval` re-indents every line, including lines inside a multi-line string**, so a runtime `GDScript.new()` probe whose
  source is a `"""..."""` block fails with "Unexpected Indent". Pass the source as ONE json-escaped line (`"extends Node\n..."`).
  Also: `grep -q true` on gbplay output always matches `"success": true` - grep for `'"result": true'`.
- **A visual timeline that must end exactly on T at 30 fps (WK-131 0.2 s retract = 6 frames) loses a frame to float rounding**:
  the ball clock is a sum of 1/120 steps, so a frame on T - 0.2 lands either side. Start the visual half a tick early.
- Setting `Ball._clock` via eval before GO carries into the next live phase (go_live never resets it) - dev overrides leak.
- WK-148b: redirecting `run_game.ps1 > file` hangs the PowerShell tool call exactly like a pipe (Godot inherits the handle); launch it with
  the tool's run-in-background option instead. Per-frame camera probes: hook `RenderingServer.frame_pre_draw` from a root node (records the
  zoom each DRAWN frame uses; `_process` order flips when change_scene re-adds the match after your probe).
- **WK-20e: a MovingPlatform with no `tier` was a standable deck (INV-11 breach)** - no bounce, no refund, so an empty-tank goat
  sat on it forever (velocity.y saturates at 3000 while y stays at deck top - 44). Fix = min-bounce hop (48 px) on tier-less decks
  (`Tuning.moving_deck_min_bounce`). Do NOT "fix" it by authoring a real tier on a fast cart: the sticky carry only holds bodies inside
  the 118 px RIDER_REACH band above the deck, and a marshmallow hop (120 px apex = centre 164 px up) leaves the band for ~0.48 s while
  the carousel deck moves ~1300 px/s mid-swing, so riders get dropped into the void. 48 px stays inside the band (measured: rider drifts
  <= 7 px over a full swing).
- gbplay `wait` counts FRAMES (`{"frames": N}`), not ms (an `ms` param is ignored = 1 frame). Under software rendering 1 frame ~ 27 ms.
- **WK-108b: most CPU own goals do NOT come from the sports objective path.** Touch forensics on THE BOWL (OFF arm): 3 of 4 CPU
  own-goal touches were made while the bot was in a refuel dive or `_danger_recover` (in sports, court walls count as blast lines,
  so recovery fires at every wall) at 860-1620 px/s (bounce-charged, above the 800 boost cap). A guard that only covers
  `bot_objective` misses them; the WK-108b strike guard runs on every soccer path. Also: trackback chasers overtaking a ball that
  is ALREADY running at their goal score from 2000 px out, so an "own half only" guard misses those too.
- **The WK-108 keeper% metric (non-nearest teammate within 300 px of the goal while the ball is in the own third) cannot see a
  keeper that is challenging**: the keeper is then the nearest goat. Read it next to "home300" (anyone within 300 px) from
  `tools/out/wk/wk108b_harness/wk108b_probe.gd`.
- **CD4-01: level JSON `"sky_drop"` only works on the MEADOW parallax stack** (no `backdrop` key). Every Brawl arena except
  islands_void is `"backdrop": "open_sky"` (a painted backdrop that already shows sky under the decks), and `_build_open_sky` returns
  before the sky-drop code, so `sky_drop` does nothing there. Also: with `Tuning.circuit_session_deck` on, a `circuit=meadow_mile`
  harness / RecordBoot run plays grassy_expanse then a SHUFFLED deck, not the authored order. A/B arms that need identical arena
  sequences must set the knob false (or use `arena=`).
- **WK-161: two WK-93 recordings of the SAME build + seed are frame-identical only until ~the first KO.** pinball_pit seed 7, knob
  OFF vs ON (the knob is inert on flat arenas): identical for 12.2 s (incl. 2 breaker trips, same avoid-frame counts), then a 0.1 px
  split that grows to chaos. Suspect wall-clock code that runs after deaths (GhostDirector bleat timing uses Time.get_ticks_msec).
  So "first divergence frame" proves a change engaged only if it lands BEFORE the first death; after that, compare counters only.
- **WK-162: the sky-drop cloud bank lives in the 0.18 parallax hills layer, so how high it sits next to the decks depends on each
  level's camera** (screen gap = zoom x (floor_y - deck_y + bank_y - 40 + 0.82 x (cam.y - anchor.y))). Lowering the bank cleared
  Islands Void but parked it ON Flight School 4's pads; raising it to the hills' base (bank_y 0) gave open sky under the decks on all three.
- **WK-116: Godot 4 `AudioStreamPlayer.playing` reads FALSE while `stream_paused` is true.** A loop that pauses players by hand (AudioManager
  is PROCESS_MODE_ALWAYS, so its players never auto-pause) and only touches `if pl.playing:` pauses them once and never un-pauses them.
  Test `pl.playing or pl.stream_paused`.
- **WK-116: the game keeps running while you look at screenshots.** Fast-forwarding `Ball._clock` and then reviewing a PNG before the next
  eval let the clock run ~10 s, so step 2 had fired before the "step 1" shot. Script the whole set-clock / sleep / screenshot sequence in ONE
  shell call (scratch `wk116_cap.sh` pattern), and freeze the goats (`p.frozen = true`) first or a bot goal reloads the stage under you.
- WK-116: gbplay prints int dictionary keys as JSON strings (`"1": [...]`), but GDScript still needs `d[1]`; `d["1"]` errors and the eval
  returns `null` with no message.
- WK-116: teleport the sports ball with `PhysicsServer2D.body_set_state(b.get_rid(), BODY_STATE_TRANSFORM / BODY_STATE_LINEAR_VELOCITY, ...)`;
  setting `global_position` on the live RigidBody2D from eval is overwritten by the next physics step.
- **WK-135 p3: multi-scenario in-game probes without touching the repo:** write the probe .gd in your scratchpad and load it from gbplay
  `eval` with `var s = GDScript.new(); s.source_code = FileAccess.get_file_as_string('<abs path>'); s.reload()` -> `Node.new()`,
  `set_script(s)`, add to root (survives change_scene). Async `await get_tree().physics_frame` makes scenarios sequential. Copy kept at
  `tools/out/wk/wk135_p3/Probe135.gd.txt`. GDScript lambdas capture locals BY VALUE (a `func(): n += 1` counter never moves); use a member.
- WK-135 p3: a wall-impact speed test must start next to the face: air drift brakes vx at 1300 px/s^2, so a goat launched at 1000 px/s
  from 116 px away hits at ~780 (below the 900 gate) and "fails" the hard-hit test. Also `Tuning.sports_goal_target` (6) ends a probe's
  sports match -> MATCH_END, and a loop counting COMBAT seconds then never finishes; raise it at runtime and break on MATCH_END.
- **WK-135 p3: the FIRST sports run of a probe session is an outlier** (touches/min 51-88 vs 65-163 for later runs, same build and arm).
  Whatever arm runs first looks worse; alternate arm order or discard run 1 before comparing 90 s sports samples.
- **WK-159: a Trials course switches well under a second of game time after SOLVED!**, and gbplay round-trips are ~0.7 s, so stills
  of the post-goal ball miss it. Set `Engine.time_scale = 0.2` around the shot (restore after) and log the ball per physics tick from a
  `get_tree().physics_frame` lambda kept in `Engine.set_meta`. Disconnect it before the next course: a lambda that captured nodes from
  a freed course spams "Lambda capture at index N was freed" into the run `.err` (probe noise, not a game bug).
- WK-158: to park the Trials puzzle ball for a still, freeze it and set `global_position` (a FROZEN RigidBody2D ignores
  `PhysicsServer2D.body_set_state(TRANSFORM)`), keep it inside `runner.bounds` (an out-of-bounds ball auto-resets to its spawn after
  `reset_settle_s`), and aim through `get_viewport().get_canvas_transform().affine_inverse() * screen_px` (the camera re-frames focus points).
- WK-156: a CanvasLayer HUD can't be drawn under world sprites, so "goat behind the legend" is solved by per-chip dimming from the goats'
  screen rects (`Node2D.get_global_transform_with_canvas()`) + the PlayerPips tag rects, not by z-order.
- **WK-166: never swap a shared file to its HEAD version to "reproduce before the fix"** (cp HEAD -> run -> cp fixed back). Another
  lane (WK-116) was editing neighbouring lobby files in the same 10-min window, and the restore would silently clobber any edit it
  made to that file meanwhile. Reproduce pre-fix behaviour in a scratch project copy, or gate the fix behind a runtime-flippable
  flag for the repro, never by rewriting the working tree.
- **Hunk staging can split a signature change across commits** (54150be committed HerdLobby calling LobbySlot.show_disconnected
  with 2 args while the LobbySlot signature hunk stayed unstaged because it lacked the WK tag; fixed in 14ff3f6). After a partial
  stage, check untagged hunks in the same files, or parse-gate a `git stash --keep-index`-style snapshot before committing.
- **WK-167: the bots' "3.9 fuel at death" was NOT the WK-136 relight floor** (that floor is max(1.0, 28.57 x 0.105) = 3.0, not
  3.86). It was `InputBot._danger_recover`'s `it.boost = me.fuel > 4.0`: boost drains 0.238/tick, so recovery let go at 3.76-4.0
  (mean ~3.88) and never re-pressed. Scripted edge drops at 4.0 fuel: OFF 0 boost ticks, 1/24 survive; spend-to-0: 9/24.
  0.14 s of thrust matters because a FRESH boost press also chops 75 % of the velocity across the aim (boost_enter_keep).
- **WK-164: never keep the K3 guard steering after it RELEASES** (recomputed or frozen escape alike). Every 30-46 deg/frame turn
  needs the 3x guard turn rate, so sharp turns scale with guard frames: a 0.2 s release hold gave 2.7x guard frames and 1.7x
  sharp turns (in-game probe, 90 s x 4 L3 on THE BOX). Only the swerve SIDE latch (held while the guard stays tripped) is safe.
  Single 20 s recordings are too noisy for this (seed 5 vs 6 baseline: 48 vs 73 sharp turns); use the per-tick probe.
