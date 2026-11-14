# BACKLOG — weekend polish run (owner: producer)

Ranked top-to-bottom. Seeded 2026-11-14 from the three audits in `docs/audit/2026-11-14_*` (C-xx controls/front-end,
R-xx rendered playthrough, D-xx game design) and the owner's verdict: *"kinda fun but... a shitty prototype with a lot
of weird things, nonsense controls (like b opens the pause menu on an xbox controller...) and the character select
totally doesnt make sense, 2 users using 2 controllers totally cant select their character like a normal game"*.
Standard: `docs/COUCH_CONVENTIONS.md` (CC-x.y). Procedure: `docs/WEEKEND_LOOP.md`. Rulings: `docs/DECISIONS.md` 2026-11-14.

## How to use (every loop tick)
1. Take the **first unchecked item** in the Next 10 (or 2-3 small related S items). Skip `BLOCKED`. Respect `Deps`.
2. Build -> verify RENDERED per its `Accept` line (keyboard AND simulated pads on >= 2 device ids) -> screenshots
   to `tools/out/wk/<ID>_*.png`, LOOKED at. UI items also need a ui-ux-designer Ship verdict vs COUCH_CONVENTIONS.
3. Mark the heading: `[x] ... — <commit hash>` on a pass; `[~] attempted — <one-line reason>` after 2 failed fix
   rounds (revert the item's files, move on). Never mark `[x]` on a builder's word: the Accept check must pass.
4. Items tagged **OWNER-RULED** touch an owner feel/rule decision (DECISIONS ruling (c)): the owner's value stays;
   only what *feeds* it may change, and the change gets a DECISIONS entry in the same commit.
5. Size L never gets pulled: it is already split below. If an item turns out bigger than its size, split it here
   first. Producer re-ranks after every creative-director cold playthrough (~every 6 items).

Legend: `[ ]` open · `[~]` attempted · `[x]` done · Size S = one pass, 1-2 files · M = one full slice · L = split it.

## In flight (do NOT reassign)
- **In progress, game slot (owner check-in 2026-11-14):** WK-93 match recorder · WK-94 bot super-aim smoothing ·
  WK-96 pendulum hits + pendulum motion quality · WK-97 black-hole z-order. Working tree carries their uncommitted edits
  (InputBot, Player, Tuning, MovingHazard, GravitySource, PartyMatch, MatchRecorder/RecordBoot, record_match.ps1).
- **Built, awaiting rendered verification:** WK-15 legend/rule line + WK-88 naming rule + WK-92 font follow-ups (one
  gameplay-programmer) · WK-36 off-screen magnifier bubbles (another gameplay-programmer). Close each only on its Accept line.
- **Spec done, build queued:** WK-95 (`docs/specs/wk95_flight_responsiveness_2026-11-14.md`, de7fd96) — split into 95a-95d
  below; 95a cannot start until WK-93 is done AND WK-94 is merged.
- **Watch out:** WK-94, WK-95 and WK-96 all touch `InputBot.gd` / `Player.gd` / `Tuning.gd` / `PartyMatch.gd`. Commit WK-93/94/96/97
  before any WK-95 code lands; never let two of them share an uncommitted file at verification time.
- **Measurement validity:** perf/timing/feel numbers count only with the display awake (~120 fps). See WEEKEND_LESSONS
  "DISPLAY OFF = BOGUS PERF DATA" and WK-100.

## Next 10 (producer re-rank 2026-11-14 #3, after the owner check-in + WK-91 close)
Ranking logic: owner feedback outranks studio opinion. The owner's five bug/feel asks are P0 and four are already in the
game slot; the fifth (WK-95, OWNER RULING on flight vs super) is #1 once they land. The owner also says sports "may be more
fun than brawl", so sports gets real weight: the WK-98 deep-dive is #2 and the two known sports P1s (WK-27 team lobby,
WK-16 one scoring banner) are pulled up from on-deck/band into #3-4 instead of waiting for WK-98 to rediscover them. Then the
brawl "who wins and why" chain (WK-20a, now valid with the screen on, measured on the post-WK-95 flight; then WK-25), then
WK-CD2, then the rest by couch impact. WK-95 was mis-sized as M (telemetry + flight + bot brain + 4 sweeps + CD sign-off =
several slices): split into WK-95a-d, pulled in order.

1. WK-95 [P0][M x4] OWNER RULING: flight you can steer, super = attack — pull 95a -> 95b -> 95c -> 95d in order — game-designer spec done; gameplay-programmer + qa-playtester + creative-director (deps WK-93 done, WK-94 merged)
2. WK-98 [P1][M] Sports deep-dive: creative-director + game-designer rendered session -> ranked sports findings — creative-director + game-designer (after WK-95b so ball strikes are judged on the new flight)
3. WK-27 [P1][M] Herd Lobby slice 4: Sports — picking the goat picks the team — gameplay-programmer + ui-ux-designer (code-only build may run in parallel with WK-95; game slot only to verify)
4. WK-16 [P1][S] Sports: one goal/point banner, not two stacked headlines — ui-ux-designer
5. WK-20a [P1][M] Who wins and why: knockback side effects + self-KO −1 rule, human-style drivers, on the post-WK-95 build -> game-designer rulings (WK-20b/20c S builds follow immediately if ruled) — qa-playtester + game-designer
6. WK-25 [P1][M] KO credit pop (+1 killer / −1 OOPS per the WK-20a ruling) + ScoreScreen kill list — gameplay-programmer + ui-ux-designer (deps WK-20a ruling, WK-20c if ruled, WK-89)
7. WK-CD2 [P1][M] Creative-director cold playthrough #2 (flight + super, sports, KO readability, scoring) — creative-director
8. WK-90 [P1][S] Hit-stop duration: RE-MEASURE at 120 fps with the screen on, then game-designer ruling, then fix — game-designer -> gameplay-programmer
9. WK-26 [P1][S] Super-aim wind-up sound + "!" over the targeted goat (the super is now THE attack: its telegraph matters more) — gameplay-programmer + sound-designer (after WK-94)
10. WK-87 [P2][S] Trials objective panel never covers the goal ring (every new player, lesson 1) — ui-ux-designer

On deck (11+, in order): WK-13 BRAWL default focus on ModeSelect (S) · WK-37a ghost-goat spec (S, game-designer, no game slot:
run in parallel any time) · WK-31 HUD danger state + stocks when LIVES > 1 (M) · WK-99 fuel-gauge super-ready notch (S, after
WK-95b) · WK-100 display-off pre-flight in run/perf/record tools (S, tooling, no game slot; never mid-QA) · WK-28 controller
disconnect (M) · WK-19 rumble only to the concerned pad (S) · WK-53 quack/taunt (S, needs a CC0 bleat) · WK-32a hero
wire-or-cosmetic decision (S, after WK-20a/b and WK-95) · WK-14 singular focus (S) · WK-29 device-aware glyph component (M) ·
WK-65/66 sports court art (M each; re-judge rank from WK-98's findings, may jump) · WK-35 panel kit B incl. sports scoreboard (M).
WK-89 runs inside the WK-20a session; it is not pulled on its own.

---

### [x] WK-80 [P1][S] QA nits from WK-01 verification (focus restore, glyph unity, stray errors) — 5926f10
- Source: qa-playtester WK-01 pass 2026-11-14. Owner: gameplay-programmer + ui-ux-designer.
- (a) Backing out of a submenu must restore focus to the item that opened it: PauseMenu `_close_options` focuses
  RESUME (should be OPTIONS); MainMenu back-from-Options lands on PLAY; ModeSelect returns focus to TRIALS after
  B from CharacterSelect (should be the mode you came from) — players accidentally enter the wrong thing.
- (b) One START glyph style: legend uses charcoal pill, PauseMenu hint bar a cream "START" keycap — unify.
- (c) Options opened from pause should show "START Resume" in its hint bar; label pause-top B as "Resume".
- (d) `PowerupSystem.gd:255` "invalid previously freed instance" x10 from round_sweep at stage change — fix.
- (e) Painted backdrop doesn't reach screen edges (pale strips L/B on Daisy Ring, L/R on meadow).
- (f) Options: focus bar overlaps the "M" of MASTER VOLUME; from pause, Options BACK + hint bar overlap HUD cards.
- Accept: each sub-item screenshot-verified in tools/out/wk/WK-80_*.png; no PowerupSystem errors across 3 stages.
- Status: done 5926f10. WK-CD1 re-check: (a) focus restore works for pause -> OPTIONS -> back and lobby -> mode select.

## OWNER CHECK-IN 2026-11-14 (docs/feedback/owner_2026-11-14_checkin.md) — owner feedback jumps its band

### [x] WK-93 [P0][S] Match video recorder: 20 s at fixed fps, frame-by-frame analysis as standard motion evidence — 9a2ee3f
- Area: tooling · Owner: gameplay-programmer (tooling) · Source: owner_2026-11-14_checkin.md (ask 1)
- Owner: "do you ever record a video of like 20 seconds of a match then analyze it frame by frame?"
- Do: `tools/record_match.ps1` (+ doc in run-and-playtest skill): Godot Movie Maker (`--write-movie out/frame.png
  --fixed-fps 30 --quit-after N`) on a scripted match config (MatchConfig via a tiny boot scene/CLI arg), frames to
  `tools/out/rec/<name>/`, plus a contact-sheet + per-player trajectory/angle overlay script. Movie Maker renders every
  frame regardless of machine FPS, so frame analysis is valid even on a throttled machine (timing numbers are not).
- Accept: a 20 s 4-bot brawl recording exists with contact sheets; WEEKEND_LOOP + qa-playtester require it for any
  motion/feel/bot change.
- Status: in-progress (game slot; uncommitted `src/dev/MatchRecorder.gd`, `RecordBoot.gd`, `scenes/dev/`, `tools/record_match.ps1`,
  `tools/rec_sheet.py`; WEEKEND_LOOP step 4 already references it). Gates WK-94/95/96 evidence.

### [x] WK-94 [P0][S] Bot super-aim spins like crazy — must sweep like a human — 9a2ee3f
- Area: brawl (bots) · Owner: gameplay-programmer · Source: owner_2026-11-14_checkin.md (ask 2)
- Owner: "the aiming mechanic looks crazy when the bots use it, it spins like nuts". Lead: game-designer found L1
  "panic" aim noise is re-rolled EVERY frame (docs/specs/wk20a_measurement_2026-11-14.md §2.2 point 3).
- Do: bot aim = smoothed target angle with max angular speed (Tuning), noise as slow drift not per-frame jitter;
  verify with WK-93 recording (aim angle per frame plot: no flips > N deg/frame).
- Accept: recording of 3 bot supers per difficulty shows smooth, readable wind-up; max angular step under cap.
- Status: in-progress (game slot; `InputBot.gd` edits uncommitted). Its merge is the start gate for WK-95a's baseline.

### [ ] WK-95 [P0][M x4] OWNER RULING: normal flight responsive enough to manoeuvre; super boost = attack, not traversal
- Area: brawl (feel + bots), also sports + trials side effects · Source: owner_2026-11-14_checkin.md (ask 3) · **OWNER-RULED**
  (the owner's ruling is the target; DECISIONS entry in the build commit)
- Owner: "the bots need to rely too much on the super boost because the normal flying isnt responsive enough to
  maneuver around nicely, we should make that more responsive/effective and consider super boost more just like the
  way to attack others rather than the way to get around."
- Spec: DONE — `docs/specs/wk95_flight_responsiveness_2026-11-14.md` (de7fd96): steering grip + directional boost keep,
  accel 5400 / cap 800 (INV-1 holds), `super_boost_min_fuel` 5 -> 10, bots fly to travel and super only in an attack window
  or as last-resort recovery. No protected constant touched (spec §3.5). Pre-registered predictions §7, fallback ladders §9.
- **Re-sized (producer 2026-11-14):** the spec is four slices (telemetry/baseline, flight, bot brain, sweeps + sign-off),
  not one M. Pull in order; each lands playable on its own.
- **BASELINE ORDER (hard rule):** the "before" evidence — WK-93 recordings (spec §8.5 G: islands_void, grassy_expanse, atoll)
  AND the bot super-for-traversal telemetry (§8.1 `geo_class`, super-as-movement share) plus the §8.2-8.5 baselines — must be
  captured on a build where **WK-94 is merged and no WK-95 Tuning/Player/InputBot change has landed**. Not before WK-94
  (the aim fix changes bot super behaviour and would pollute the baseline), not after 95b. If 95b lands first by mistake,
  use the spec §3.6 A/B switches at runtime (accel 4600 / cap 760 / min fuel 5) and hash `Tuning.gd` before/after.
  Screen on (WK-100 / WEEKEND_LESSONS) for any timing number.
- WK-95a [P0][M] Telemetry + baseline capture — gameplay-programmer (§8.1 telemetry in PartyMatch, no behaviour change) +
  qa-playtester (baseline). Deps: WK-93 done, WK-94 merged. Accept: §8.1 fields present in `supers_fired[]` and per-player
  stats (eval); baseline numbers saved to `tools/out/wk/WK-95_baseline.json` (B1-B6 40-stage batch, M1-M9, PadHopper C1/C3,
  sports E, pacing D) + 3 "before" WK-93 recordings with contact sheets, LOOKED at.
- WK-95b [P0][M] Flight: steering grip, directional boost keep, accel/cap, super min fuel — gameplay-programmer. Deps: 95a.
  Files: `Tuning.gd`, `Player.gd`. Accept: M1-M9 pass (spec §8.2); DECISIONS entry; one "after" recording looked at.
- WK-95c [P0][M] Bot brain: fly to travel; super only in an attack window (range + LOS) or last-resort recovery — gameplay-programmer.
  Deps: 95b. File: `InputBot.gd` (after WK-94 is committed). Accept: B1-B6 (spec §8.3) on the 40-stage batch vs the 95a baseline.
- WK-95d [P0][M] Side-effect gates + sign-off — qa-playtester + level-designer + creative-director. Deps: 95b, 95c. Accept: PadHopper
  C1-C4, KO pacing D, sports E (owner's fun-flagged mode: mandatory), Trials sweep F (0 newly impossible courses), after-recordings G,
  creative-director feel check §10 SHIP. On a miss, walk the §9 ladder one knob at a time; Phase 2 `super_hit_refund` only if C4 fails.
- Status: spec done de7fd96; build queued (95a blocked on WK-93 + WK-94).

### [x] WK-96 [P0][M] Pendulums: pass through players without smashing them AND motion looks stiff/poor quality — 9a2ee3f
- Area: brawl (hazards) · Owner: gameplay-programmer (+ art-director on the look) · Source: owner_2026-11-14_checkin.md (ask 4 + follow-up)
- Owner: "big swinging pendulums ... went right through a player and didnt smash them". Find the pendulum hazard
  (grep pendulum in src/ + levels), check collision layers/masks, tunnelling at speed (continuous CD / shape cast),
  and hit-gating (cooldown/invuln). Owner follow-up: "not very cool looking motion, they look very stiff and like poor
  quality" -> real pendulum swing (slow at apex, fast at bottom), visible anchor/arm, heft, whoosh/trail.
- Accept: WK-93 recording of 5 pendulum contacts -> 5 smashes; contact sheet of one swing bunches at apexes.
- Status: in-progress (game slot; `MovingHazard.gd` +397 lines uncommitted, also `Player.gd`/`Tuning.gd`/`AudioManager.gd`).

### [x] WK-97 [P0][S] Black hole level: player sprites render behind the black hole — 9a2ee3f
- Area: brawl (render order) · Owner: gameplay-programmer · Source: owner_2026-11-14_checkin.md (ask 5)
- Owner: "on like a black hole level, all the player sprites were behind the black hole". Fix z_index/z_as_relative or
  CanvasLayer ordering of the black_hole sprite (GravitySource) so players/FX draw in front.
- Accept: screenshot on Singularity with players passing over the black hole.
- Status: in-progress (game slot; `GravitySource.gd` edit uncommitted).

### [ ] WK-98 [P1][M] Sports deep-dive: owner reports Rocketball/Dropshot may be more fun than Brawl
- Area: sports · Owner: creative-director + game-designer (rendered session), then producer re-rank · Source: owner_2026-11-14_checkin.md (ask 6)
- Owner: "i've had some feedback that the sport modes are quite fun, maybe more fun than the brawl, so lets ensure we focus
  efforts there too".
- Deps: WK-95b merged (spec §6.3: the flight change alters header strength and aim — judge the ball on the new flight).
  Does not wait for 95c/95d. Uses the game slot.
- Do: one rendered session, human-style input on kb + 2 simulated pads. Rocketball 2v2 and 1v1, Dropshot 2v2, at least 4
  Rocketball courts + all 3 Dropshot courts, with a WK-93 recording of one Rocketball and one Dropshot match.
  - creative-director: judge against GAME_ESSENCE as a couch group would. Why is it fun? What feels rough?
  - game-designer: name the feel to PROTECT: ball drive (`BALL_DRIVE_GAIN` is still a Ball.gd const, INV-6), scoring rules,
    serve. Also name what to change.
  - Cover: ball feel + readability, goal/point feedback (WK-16), team pick (WK-27), bots' team play, court variety and art
    (WK-65/66), match flow and end screen, sports scoreboard (WK-35).
- Accept: findings doc in `docs/audit/` with screenshots/recording frames under `tools/out/wk98/`. Every finding becomes a
  bug-triage entry (next free WK id) with evidence, or is merged into WK-16/27/35/65/66 with a keep/raise/drop note.
  Producer re-ranks sports items into the Next 10 before the next pull.
- Status: open (planned as Next-10 #2)

### [ ] WK-99 [P2][S] Fuel gauge shows a super-ready notch (threshold now 10 %)
- Area: HUD · Owner: ui-ux-designer · Source: game-designer WK-95 spec §6.4 · Deps: WK-95b (threshold value)
- Impact: with `super_boost_min_fuel` 10 (was 5), "can I super?" stops being trivially yes; the PlayerCard gauge and the off-screen
  bubble fuel ring (WK-36) don't show the line. Couch players learn the attack's cost from the HUD instead of a dud press.
- Accept (rendered): eval fuel 9 / 11 on P1 -> the notch reads below/above in a PlayerCard crop and a WK-36 bubble crop; ui-ux Ship.
- Status: open

### [ ] WK-100 [P2][S] Tooling: display-off pre-flight in run_game.ps1, perf_gate.py and record_match.ps1
- Area: tooling · Owner: gameplay-programmer (tooling) · Source: performance-analyst docs/audit/2026-11-14_perf_wk91.md rec 1(a)(b)
- Evidence: a whole afternoon of WK-91/WK-21/WK-90 timing data (12:08-15:50) was taken with the display off. Modern Standby caps
  presentation at ~30 Hz with ~500 ms stalls (Kernel-Power 506/507). It cost a P0 investigation and blocked the WK-21 budget.
- Impact: not player-facing. Every timing/feel verdict in the loop depends on it (WK-20a, WK-90, WK-95a baseline). The director's
  keep-awake script is a session workaround, not a guard.
- Do: read the latest Kernel-Power 506/507 event. If the last one is 506, print "DISPLAY OFF - timings invalid". Also flag runs whose
  median `draw` is 25 ms or more while GPU + render-CPU time is under 3 ms. Touches `run_game.ps1`: never land it while a QA session
  holds the game. Rec 1(c), setting the AC display timeout to Never, is owner machine setup: BLOCKED (owner), not studio work.
- Accept: with the display forced off (or a stubbed 506 event), each tool prints the warning; with the display on, run_game + a gbplay
  screenshot still work unchanged.
- Status: open


## P0 — broken normal couch play (controls, joining/selecting, roster)

> **SYSTEMIC — input/device model** (C-01..C-07, C-10, C-14, R-01, R-02, R-03, R-32): one global action map, one
> shared focus cursor, devices by `get_connected_joypads()` order. Fix is the InputRouter + Herd Lobby chain
> (WK-03 -> WK-07), not more per-screen patches. Any new input bug: check whether the router already owns it.

### [x] WK-01 [P0][S] Pause = Start/Esc/P only; B never pauses; pause owner gating; swallow-until-release on resume — 933a77a
- Sources: C-01, C-02 (action-map part: `pause`, `menu_start`, `menu_view`, `menu_random`+R), C-19, R-01; partial C-06 (owner device gating only)
- Area: brawl/trials/sports (all live matches) · Owner: gameplay-programmer · Deps: none
- Evidence: tools/out/cd_audit/20_padB_midmatch.png, 55_padB_with_powerup.png; PartyMatch.gd:986-991 (pre-fix)
- Files (uncommitted, in working tree): project.godot, PartyMatch.gd, PauseMenu.gd/.tscn, InputHuman.gd, ControlsLegend.gd, PadGlyph.gd, CharacterSelect.gd
- Accept (rendered): mid-match pad B with `held_powerup` set -> `paused=false` and powerup activates; pad Start -> PAUSED;
  Esc -> PAUSED; P -> PAUSED; pad1 opens pause, pad0 A/stick ignored, pad1 A resumes; A-resume -> goat does not boost
  on the first 10 frames; B-resume -> no powerup fires; super held through pause is not fired by resume; legend shows
  START glyph. Screens `tools/out/wk/WK-01_*.png`.
- Status: done 933a77a (QA 8/8 rendered)

### [x] WK-02 [P0][S] Roster cap = 4 fighters; HUMANS up lowers BOTS; HUD hides unused cards — 933a77a
- Sources: R-03, C-15 (hide part + out-of-bounds `skins[i]`), D-17 (cap part — see Deferred for 6-8 players)
- Area: menus/HUD · Owner: gameplay-programmer · Deps: none
- Evidence: tools/out/cd_audit/11_humans2.png, 17_launch_1.5s.png, 25_victory_settled.png ("BILLY P5" wins); MatchHUD.gd:32-34 (VERIFY error)
- Do: `MatchConfig.MAX_FIGHTERS = 4` (= HUD corners); current CharacterSelect: raising HUMANS lowers BOTS so total <= 4,
  BOTS max = 4 − humans; PartyMatch clamps `bot_count` defensively; MatchHUD hides cards i >= players.size(). The
  stepper coupling is throwaway once WK-06 lands; the cap constant is not (lobby CPU tray reads it — this
  overrides the audit's "CPUs 0..8−humans").
- Accept (rendered): default Brawl = 1H+3CPU, 4 cards; HUMANS->2 shows BOTS 2 -> match has 4 fighters, no P5 tag; 1H+1CPU
  Brawl shows exactly 2 HUD cards, no ghost "P1" cards, no script error in the log; BOTS cannot exceed 4−humans.
- Status: done 933a77a (stepper coupling since replaced by the lobby CPU tray, fe2a99c)

### [x] WK-03 [P0][M] InputRouter autoload + device keys + simulated pads testable from gbplay — 1191757
- Sources: C-05 (infrastructure), C-06/C-07/C-10/C-26 (enablers), audit §E.8
- Area: tooling/menus · Owner: gameplay-programmer · Deps: WK-01
- Do: `src/core/InputRouter.gd` (autoload via `load()`): `device_key(e)` (`kb` / `pad:N` by EVENT CLASS, CC-3.2),
  `last_device_key`, `last_device_kind`, `joined` registry + `is_joined()`, `device_lost/device_found` signals from
  `joy_connection_changed`, `rumble(key, …)` stub, and **test hooks** `simulate_device_lost(key)/found(key)` for QA.
  Keys off events seen, never enumeration (simulated pads are not in `get_connected_joypads()`). Replace
  `PartyMatch._device_key` / PauseMenu's inline copy with the router. Parse gate (new class_name).
- Accept (rendered): via gbplay, keyboard + `gamepad` device 0/1/2 presses -> `eval InputRouter.last_device_key` reads
  `kb`, `pad:0`, `pad:1`, `pad:2` in turn; keyboard after pad 0 is `kb` (not `pad:0`); `simulate_device_lost("pad:1")`
  emits the signal (eval a counter). WK-01 pause gating still passes (regression).
- Status: done 1191757

### [x] WK-04 [P0][M] Each human is driven by exactly one device (`InputHuman.for_device`) — 1191757
- Sources: C-05, C-04 (match half), R-02 (match half)
- Area: brawl/trials/sports · Owner: gameplay-programmer · Deps: WK-03
- Evidence: InputHuman.gd:45-56 (enumeration order, overflow humans share keyboard, P1 = pad0 + keyboard)
- Do: `MatchConfig.human_devices: PackedStringArray` + `human_labels: PackedInt32Array`; `InputHuman.for_device(key)`
  scopes to exactly that device; PartyMatch spawn uses it when `human_devices.size() > i`; legacy any-device path
  ONLY when `human_devices` is empty (cold boot / QA harness); delete the "share the keyboard" overflow.
- Accept (rendered): set `human_devices=["kb","pad:0","pad:1"]` via eval + 3 humans, start Brawl; drive each device in turn
  and `eval` positions: keyboard moves only P1, pad0 only P2, pad1 only P3 (0 cross-moves over 3 trials each);
  cold-boot Arena.tscn still drives P1 from any device.
- Status: done 1191757 (0 cross-moves, rendered)

### [x] WK-05 [P0][M] Herd Lobby slice 1: press A/Enter to join, per-player panels, independent goat cycling — fe2a99c
- Sources: C-03, C-04, C-34 ("CHOOSE YOUR GOAT"), C-21 (lobby per-device repeat), R-02, R-24, D-28 (join intent), CC-4.1/4.2/4.8
- Area: menus · Owner: ui-ux-designer (layout/motion) + gameplay-programmer · Deps: WK-03
- Do: audit §E.2 data model (`GameConfig.lobby`), §E.3 EMPTY<->PICKING, §E.4 join/cycle/leave rows, §E.9 layout (4 panels,
  roster ribbon, header, footer), §E.10 join/cycle motion; `_input` routing by device, all panel controls
  `focus_mode=NONE`; per-device D-pad/LS repeat (0.40/0.09 s, hysteresis 0.5/0.3); auto-join the device that
  confirmed the mode card. Build as `scenes/ui/HerdLobby.tscn` + `LobbySlot.tscn`, **not yet routed** (old
  CharacterSelect stays live so the tree remains playable) — WK-06 swaps the route.
- Accept (rendered, launch the scene directly): E.13 steps 1-3 — Enter -> P1 [kb] PICKING; pad0 A -> P2 joins; pad1 A -> P3 joins;
  all three cycle simultaneously and each panel shows a different goat, no panel moved by another device; B on a
  PICKING slot -> EMPTY. Screens `tools/out/wk/WK-05_*.png`; ui-ux-designer verdict vs CC-4.x, CC-5.1, CC-8.1.
- Status: done fe2a99c (ui-ux verdict FIX -> must-fixes shipped as WK-81 f1a9fdd)

### [x] WK-06 [P0][M] Herd Lobby slice 2: lock/ready, exclusive goats, READY banner, Start proceeds, devices carry into the match — fe2a99c
- Sources: C-03, C-04, C-17 (delete shared tray focus), R-02, R-24, CC-4.3/4.4/4.5, E.5, E.6 (Trials variant)
- Area: menus · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-04, WK-05, WK-02
- Do: PICKING<->READY, taken goats skipped + P-badge on roster medallion, same-frame lock tie -> lower slot wins + deny
  shake; READY banner (>= 0.35 s before proceed counts); BRAWL CPU tray on LB/RB · Q/E (0..4−humans) + solo hint "RB ADD
  A CPU, OR GRAB A FRIEND"; hold-B 1.0 s exit with ring; proceed compacts slots -> `human_count/human_devices/
  human_labels/skin_ids`. Trials variant (no CPU tray, "READY TO FLY!"). Sports keeps today's humans-first split
  until WK-27. Route ModeSelect -> HerdLobby; delete HUMANS/BOTS steppers, SettingsTray, `_pick_idx/_picked/_locked`,
  P1Flag, accept_override hack, ReadyPrompt. KILLS/LIVES/SKILL use MatchConfig defaults until WK-07.
- Accept (rendered): E.13 steps 4, 5, 7 — P3 cannot land on P2's locked BUTCH (medallion wiggles); B un-readies then leaves;
  banner appears only when all joined are READY; pad1 Start -> ArenaSelect -> match where pad0 drives only P2's goat,
  pad1 only P3's, keyboard only P1's (eval positions); solo: Mode -> A (lock) -> A/Start (go) = 2 presses; 1H+0CPU
  shows the amber hint, never a dead end; Trials + Rocketball still launch. Screens `tools/out/wk/WK-06_*.png`.
- Status: done fe2a99c (old CharacterSelect deleted; route swapped)

### [x] WK-81 [P0][S] Herd Lobby review must-fixes (ui-ux-designer verdict FIX, docs/audit/2026-11-14_lobby_review.md) — f1a9fdd
- Owner: gameplay-programmer (lobby builder) · Deps: WK-06 · Do together with WK-07.
- (1) ModeContextChip sizes to text, grows leftward (ROCKETBALL overflows); (2) shared glyph rule per amended CC-1.6;
  (3) pad type label (XBOX/PLAYSTATION/GAMEPAD) not Godot device id, rumble on join, panel pulse on idle press;
  (4) empty slot = dark well, not see-through glass; (5) flair row: icon not word, 28 px text, short names, arrow gap;
  (6) lift "PRESS A TO JOIN" above the READY banner; (7) fade arrows on READY panels; (8) GO press during banner
  guard gets a tick + banner pop. Bug: Start launches while another player has RULES open — block GO while open.
- Accept: re-review by ui-ux-designer from fresh 1920x1080 captures + a motion burst; Ship verdict.
- Status: done f1a9fdd (also closes lobby review L1 and L13). Review "later" items L2-L12 folded below — see Coverage index.

### [x] WK-07 [P0][M] Herd Lobby slice 3: RULES panel, lobby survives round trips, CHANGE SETUP, per-mode rule memory — f1a9fdd
- Sources: C-17, C-25 (Stepper B reverts), C-29, R-13, R-16, R-26, CC-4.6/4.7, CC-10.3, E.7
- Area: menus · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-06
- Do: View/Tab opens RULES modal owned by the opener (BRAWL: CPUs, CPU SKILL, KOs TO WIN, LIVES; SPORTS: FORMAT,
  CPU SKILL), "P2 IS SETTING RULES" chip for others; always-visible rules summary bar; Stepper: A commits, B reverts;
  remembered rule set **per mode**; `GameConfig.lobby` persists Back-from-ArenaSelect (all READY), CHANGE SETUP
  (PICKING with goats + devices), REMATCH; add CHANGE SETUP to Pause; QUIT TO TITLE clears.
- Accept (rendered): E.13 step 6 (back from ArenaSelect -> all three still READY on the same devices); pad0 Tab/View opens RULES,
  pad1 input ignored inside it; edit KOs 10->7 then B -> reverts to 10; play Rocketball then open Brawl -> CPUs still
  3 (no leak); Pause -> CHANGE SETUP lands in the lobby with picks kept. Screens `tools/out/wk/WK-07_*.png`.
- Status: done f1a9fdd (rendered at 1920x1080; RULES = Duck-Game panel flip per lobby review spec, not a modal)

---

## P1 — obviously amateur next to Smash / Duck Game / TowerFall

> **SYSTEMIC — identity** (C-08, C-09, R-04, R-05, R-17, D-03, D-06): colour, tag and CPU labelling are driven by slot,
> not by the goat. WK-08 lands the shared `player_color()` first; every later identity item reads it.
> **SYSTEMIC — two visual languages** (R-11, R-22, R-28, R-12): in-match panels are dark-navy dev-look; WK-34/35 own it.

### [x] WK-86 [P1][S] Powerup spawners follow the loaded stage (every mode has used Islands Void's three points since July) — 4d5d356
- Area: brawl | sports | trials · Owner: gameplay-programmer (fix) + game-designer (no-spawner intent) · Source: creative-director WK-CD1 (CD1-01)
- Evidence: eval in a live Rocketball match: `_pu_director.points = [(480,900),(2810,600),(5100,780)]` (= `levels/islands_void.json`)
  while `_pu_points = []`; live bubbles at (480,908) and (5100,777). Same points in Dropshot ((2810,607), outside its 0..2800 court)
  and Trials ((480,902)). Frames: `tools/out/cd1/rb_edge_crop.png`, `36_crop_edge.png` (bubble outside Rocketball's right wall),
  `sheet_ds.png` f000/f001, `47_trials_flying.png` + `48_trials_after.png` (`ball_storm` on a bush in Trials lesson 1, P2 grabbed it).
- Impact: every match in every mode. Brawl's 94 hand-placed spawner layouts have never fired; x=5100 is beyond most blast lines.
  Sports/Trials get bubbles they were never designed for. Not a weekend regression (code dates from a8de63c / 9fafa66).
- Root cause: `PartyMatch._ready()` loads `LEVEL_POOL[0]` as a placeholder, `_pu_director.setup(self, _pu_points)` captures that
  array; every later `_load_stage()` rebinds `_pu_points` to a NEW array the director never sees.
- Do: push the stage's points into the director on every `_load_stage()` (or have the director read them in `reset()`).
  game-designer confirms "no spawners = no powerups" for sports courts and Trials courses.
- Accept (rendered): after a stage change in Brawl, eval `_pu_director.points` equals that arena JSON's `powerup_spawners` on 3
  arenas, with a bubble screenshot at an arena-specific point; Rocketball, Dropshot and Trials lesson 1 show 0 bubbles over 60 s
  (or the game-designer's ruling); no bubble outside the camera bounds. The 94-arena re-check rides on WK-57.
- Status: done 4d5d356. WK-CD2 re-judges it as item (4) (powerups only at each arena's own points).

### [x] WK-08 [P1][S] One player = one colour = their goat's colour, everywhere — 4e7caf6
- Sources: C-08, R-04, D-03 (design audit rated P0)
- Area: HUD/brawl · Owner: gameplay-programmer · Deps: none
- Evidence: tools/out/cd_audit/17_launch_1.5s.png, d23_brawl_play/f016_SCOREBOARD.png, d23_contact1.png ("P5 SURVIVES!" purple), 25_victory_settled.png
- Do: shared SKIN_COLORS table (CharacterSelect.gd:17-30 values) in `PlayerIdentity.gd`/CharacterProfiles;
  `PartyMatch.player_color(i)` from `players[i].skin`; replace every `PLAYER_COLORS[i]` read (HUD rims, tags, banners,
  FIRST BLOOD, match point, EdgeIndicators chevrons, ScoreScreen, VictoryScreen). Sports team skins follow automatically.
- Accept (rendered): P1=BUTCH(blue), P2=POGO(pink) + 2 CPU: name tag at pop-in, an off-screen chevron, a stage banner, the
  ScoreScreen row and the Victory row are blue for P1 and pink for P2 (5 screenshots).
- Status: done 4e7caf6

### [x] WK-CD1 [P1][M] Creative-director cold playthrough of the integrated build (recurring) — done, doc docs/audit/2026-11-14_cd1_playthrough.md
- Source: WEEKEND_LOOP step 6 (every ~6 items; 10 done since seeding) · Owner: creative-director, then producer re-rank
- Area: all · Deps: WK-09, WK-11, WK-12 landed (WK-80 if it lands first) · uses the game slot
- Do: fresh-eyes run vs GAME_ESSENCE: Title -> Herd Lobby with kb + 2 simulated pads -> RULES flip -> Brawl match to Victory ->
  REMATCH -> CHANGE SETUP; one Trials and one Rocketball launch. Report new findings as R/D-style entries with screenshots
  in `tools/out/wk/CD1_*.png`; explicitly re-judge the lobby (WK-05..07/81) and identity (WK-08/10) as a player would.
- Accept: findings file in `docs/feedback/cd_2026-11-14_weekend1.md` (or similar) + producer re-rank committed before Next-10 item 1 is pulled.
  Next instance WK-CD2 after Next-10 item 6.
- Status: done, doc docs/audit/2026-11-14_cd1_playthrough.md (the doc itself is in ccf1ed1; this re-rank is not committed yet).
  Verdict: front end / couch input SHIP (owner's pause-on-B and 2-pad character-select complaints verified FIXED on 3 devices),
  Brawl in motion FIX. No regressions. New findings CD1-01..06 -> WK-86, WK-20a (expanded), WK-87, WK-88, WK-17, WK-89.
  Re-judged: WK-82, WK-21/41, WK-37, WK-85, WK-43 (notes added on each).

### [ ] WK-CD2 [P1][M] Creative-director cold playthrough #2 (recurring)
- Source: WEEKEND_LOOP step 6 · Owner: creative-director, then producer re-rank · Area: all · uses the game slot
- Deps (re-rank 2026-11-14 #3): WK-95d signed off, WK-98 findings ranked, WK-20a ruling + WK-25 landed. (Old deps WK-86/24/23/82/21/41 are
  all done.)
- Do: the same 3-device cold run as WK-CD1 (pad + kb + pad, full default Brawl to Victory, REMATCH, one 3-lives stage, one
  Trials + one Rocketball + one Dropshot launch). Re-judge specifically: (1) can you tell who KO'd whom from the screen alone
  (WK-23/24); (2) does the score economy still let a CPU beat three humans (WK-20a ruling + any WK-20c change); (3) measured
  STAGE_END -> next COMBAT time against the WK-21/41 budget; (4) powerups appear only where each arena placed them (WK-86);
  (5) normal flight steers and the super reads as an attack, for humans and bots (WK-95, owner ruling); (6) pendulums smash and
  swing with weight, players draw over the black hole (WK-96/97); (7) one Rocketball + one Dropshot match judged against the
  WK-98 findings. Use WK-93 recordings for (1), (5) and (6).
- Accept: findings doc in `docs/audit/` with screenshots under `tools/out/cd2/` + producer re-rank before Next-10 item 8 is pulled.
  Next instance WK-CD3 ~6 items later.
- Status: open (Next-10 #7)

### [x] WK-82 [P1][S] Lobby hold-B exits only from a B press that changed nothing; 6 px ring — 4d5d356
- Source: ui-ux-designer lobby review L8 (docs/audit/2026-11-14_lobby_review.md); producer code re-check 2026-11-14
- Area: menus · Owner: gameplay-programmer · Deps: none
- Evidence: HerdLobby.gd:509-540 (`_on_back_press` arms `_hold_b` on EVERY B, including the press that un-readies or leaves
  a slot; `_tick_hold_b` exits for everyone at 1.0 s). Code-verified, rendered repro not yet captured.
- Impact: a READY player who holds B to un-ready (a natural "wait, change goat" gesture) ejects all 4 players from the lobby.
  Couch-visible, front-end flow, the exact "nonsense controls" class the owner complained about.
- Do: count the hold only from a B press that did not change any slot state (a device with no slot, i.e. never joined or
  already left); a press that un-readies or leaves never arms the ring, even if held. Ring stroke 6 px (now ~3 px) per CC-8.1.
- Accept (rendered, 3 joined): READY P2 holds pad B 2 s -> P2 un-readies, lobby stays, no ring; P2 releases and holds B again
  from PICKING -> leaves the slot only, no ring; P2 (now slotless) presses and holds B 1.0 s -> ring fills (6 px) -> exits; a
  B tap with nobody joined still backs straight out. Screens `tools/out/wk/WK-82_*.png`.
- WK-CD1 re-judge (`tools/out/cd1/39_lobby_after_B.png` -> `40_after_holdB.png`): a device that has ALREADY LEFT can still hold B
  1.5 s and throw a still-PICKING player back to mode select (lobby `[EMPTY, pad:1 PICKING, EMPTY, EMPTY]`). CD proposed counting
  hold-B only from a joined device, or only when no other slot is joined.
- Decision (director 2026-11-14): KEEP the Smash convention — a slotless device holding B 1.0 s exits the lobby for everyone
  (Smash Ultimate behaves this way). The CD's case above is **accepted risk, not a bug**; do not add it to the Accept line.
  The fix stays scoped to presses that un-ready or leave never arming the ring.
- Status: done 4d5d356

### [x] WK-09 [P1][S] Pause finish: hold-to-confirm RESTART/QUIT, "PAUSED · P2" header with goat head, context line — 5926f10
- Sources: C-18, R-09, C-20 (header/context; CONTROLS entry lands with WK-33), C-06 (header part), CC-6.1, CC-7.2
- Area: menus · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-01, WK-08 (colour); owner->player label via WK-04 (fallback kb->P1)
- Evidence: tools/out/cd_audit/29_quit_confirm.png, 30_after_quit.png, 31_back_at_menu.png (QUIT never fired; `_arm_gen` advances on press AND release)
- Do: `HoldButton` component (0.9 s, radial fill in owner colour, rising ticks, early release drains); replace the
  "REALLY?" double-press; header "PAUSED · P#" + portrait in owner colour; sub-line mode · arena · score.
- Accept (rendered): hold A 1.0 s on QUIT -> menu; release at 0.5 s -> still paused, ring drained; mashing A x6 never quits;
  pad1 pauses -> header reads P2/P3 per label in that goat's colour. Screens `tools/out/wk/WK-09_*.png`.
- Status: done 5926f10. WK-CD1 re-check: tap does nothing, 1.3 s hold confirms; PAUSED · P1 with goat head (`tools/out/cd1/22_pause_p1.png`, `24_restart_tap.png`).

### [x] WK-10 [P1][S] Persistent P# pip over every human; bots tagged CPU — 4e7caf6
- Sources: C-09, R-17, R-05 (pointer part), C-15 (label part), CC-8.3
- Area: HUD/brawl · Owner: gameplay-programmer · Deps: WK-08; uses `human_labels` from WK-04 when present
- Evidence: tools/out/cd_audit/21_after_resume.png (no tags after intro), 45_rocketball_1s.png (bot tagged "P2"), d56_contact.png
- Accept (rendered): 2H+2CPU Brawl at 10 s into combat: both humans show a 28-32 px "P#" pip in goat colour (~70 % alpha),
  full alpha 1 s after respawn; bots show "CPU" during intro only; HUD cards for bots read "CPU", never "P3".
- Status: done 4e7caf6 (also closes lobby review L11)

### [x] WK-11 [P1][S] End-screen input gate (fresh presses only, arm >= 1.0 s) + shared menus ignore unjoined devices — 5926f10
- Sources: C-14, C-06 (shell part), CC-3.3, CC-10.2; resolves D-09 "FLY skips" conflict (a FLY press only counts if it began after the screen appeared)
- Area: menus · Owner: gameplay-programmer · Deps: WK-03 (joined filter needs WK-06 for real data)
- Evidence: VictoryScreen.gd:234-235/311 (fast-forward arms instantly), PartyMatch.gd:74/849-850 (code, VERIFY rendered)
- Accept (rendered): hold pad A through the winning KO -> Victory does not REMATCH and ScoreScreen tally is not skipped;
  a fresh A after 1.0 s works; an unjoined pad2 cannot press REMATCH once a lobby exists.
- Status: done 5926f10. WK-CD1 re-check: unjoined pad 2 A ignored on Victory, P3 A started the rematch.

### [x] WK-12 [P1][S] First impression: every brawl arena gets a painted backdrop (Grassy Expanse first) — 4ba5d88
- Sources: R-08 (+ STATUS "grass arenas without a backdrop_painting show a plain sky")
- Area: art/brawl · Owner: level-designer · Deps: none
- Evidence: tools/out/cd_audit/17_launch_1.5s.png, 18_launch_3s.png, 26_rematch_1.5s.png vs 22_now.png
- Accept (rendered): screenshot Grassy Expanse at BOUNCE! shows the meadow painting, not flat grey-blue; grep confirms
  every brawl level JSON has `backdrop_painting`; spot-render 5 previously-bare arenas.
- Status: done 4ba5d88. WK-CD1: "better than described" — meadow sky on Grassy Expanse (`tools/out/cd1/12_launch_3.png`).

### [ ] WK-13 [P1][S] Mode select: BRAWL default focus, equal card heights, player-count chips
- Sources: R-18, D-29, C-35 · **OWNER-RULED**: card ORDER is owner-set (TRIALS, BRAWL, …) — keep it, change focus only
- Area: menus · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/03_modeselect.png; WK-CD1 2026-11-14: still defaults to TRIALS (carried over unchanged)
- Accept (rendered): fresh save -> ModeSelect focus on BRAWL; after playing Trials, focus = last-played; all 4 card art panels
  same height; chips read e.g. "2-4 VERSUS", "1-4 CO-OP", "1V1 / 2V2"; Trials has a "SOLO / CO-OP" sub-label.
- Status: open

### [ ] WK-14 [P1][S] Focus is singular: style swaps on focus, no permanently "primary" button
- Sources: C-13, R-21, CC-5.1
- Area: menus · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/30_after_quit.png (QUIT focused, RESUME still green)
- Accept (rendered): screenshots with focus on the LAST button of Title, Pause, Victory, Sports end row, Trials end row: exactly
  one element looks focused in each (shared `FocusRow` helper replaces the three `_set_focus` copies).
- Status: open

### [ ] WK-15 [P1][S] Teach the goal: controls legend on every mode's stage 1, rule line, honest BRAWL tagline
- Sources: C-12 (legend part), D-13a, D-04 (messaging part), CC-11.1
- Area: HUD · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-01 (legend glyphs)
- Do: legend out of the `wants_scoreboard()` gate, mode chips (Sports "HEADBUTT the ball", Trials "LAND on the pad");
  stage-1 StageIntroCard rule line "SMASH 'EM OFF-SCREEN · FIRST TO 10 KOs"; BRAWL tagline -> "Smash 'em off-screen.
  First to 10 KOs."; stage banner leads with KOs, survivor as sub-line.
- Accept (rendered): stage-1 screenshots of Brawl, Trials, Rocketball, Dropshot each show the legend; Brawl intro shows the rule line.
- Status: built — awaiting rendered verification (gameplay-programmer, same pass as WK-88/WK-92; uncommitted ControlsLegend,
  StageIntroCard, ModeSelect edits). Close only on the 4-mode stage-1 screenshots.

### [ ] WK-16 [P1][S] Sports: one goal/point banner, not two stacked headlines
- Sources: R-12
- Area: sports · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/46_rocketball_3.5s.png, d53_contact.png
- Accept (rendered): goal in Rocketball and point in Dropshot each show one scoring-team-coloured burst + score tick, nothing clipped by posts.
- Raised 2026-11-14 (owner check-in: sports may be more fun than brawl) into Next-10 #4. WK-98 may add to it; do not wait for WK-98.
- Status: open

### [x] WK-17 [P1][S] Bundle a real display font (OFL) — NOT blocked (DECISIONS ruling b) — 5672f04
- Sources: C-32, R-10, CC-12.3, STATUS "real FONT", lobby review L10
- Area: art/menus · Owner: ui-ux-designer (pick) + art pipeline (import) · Deps: none
- Do: OFL rounded heavy face (Fredoka / Baloo 2 ExtraBold / Lilita One) + licence file in `assets/fonts/`; theme default
  font replaces the SystemFont chain; check MenuCard auto-shrink and long labels.
- Merged CD1-05 (creative-director WK-CD1, P3/S): Herd Lobby small text (flavour lines, NONE/flair row, rules summary bar) uses a
  dark-brown outline on dark-brown text (`outline_size` 4-12 in `LobbySlot.tscn`) that fills in the counters of e/a/g and reads
  muddy at couch distance (`tools/out/cd1/05_crop_lobbytext.png`); the lobby is also a second type style beside the system-font menus.
  Drop the outline on dark-on-light body text (or use a light outline) when the bundled face lands — no fake-bold outlines.
- Accept (rendered): Title, Lobby/CharacterSelect, Pause, ScoreScreen, Victory screenshots all render the bundled face; no text overflow;
  a 1080p lobby crop of a flavour line + the rules summary bar shows open letter counters (no same-colour outline).
- Status: done 5672f04 (Lilita One display + Fredoka body via theme; ui-ux grade follow-ups -> WK-92)

### [ ] WK-18 [P1][S] 28 px floor for anything a player reads
- Sources: C-27, R-10 (micro-text), R-25 (KO chip legibility), CC-8.1, lobby review L6
- Area: menus/HUD · Owner: ui-ux-designer · Deps: WK-17
- Also (L6): lobby roster-medallion P-badges ~21 px -> 30x44 chip, 28 px white text on chocolate; a locked medallion
  desaturates to 0.6 and shows the MenuCard check ("taken" reads from the sofa).
- Accept (rendered): theme tokens CardTag/CardName/HintStrip/ControlsLegend/FLAIR >= 28 px; screenshots of the 5 affected screens
  at 1080p show no overflow; KO meta chip readable; lobby with 2 locked goats shows 28 px badges + desaturated medallions.
- Status: open

### [ ] WK-19 [P1][S] Rumble goes only to the concerned player's pad
- Sources: C-10, R-32 (rumble part), CC-3.6
- Area: brawl · Owner: gameplay-programmer · Deps: WK-04 (player -> device)
- Accept: eval-log `start_joy_vibration` calls during 10 smashes in a 2-pad match: only the victim's/attacker's device id appears.
  (Rumble can't be seen; the call log is the evidence.) Options toggle lands in WK-44.
- Status: open

### [ ] WK-20a [P1][M] Who wins and why: measure the +25 % knockback side effects AND the self-KO −1 rule, then game-designer rulings (no code change)
- Sources: D-18, R-07 (early KOs), DECISIONS 2026-07-19 watch item · split from WK-20 (producer 2026-11-14: measure before building)
  · **scope expansion 2026-11-14 (director): CD1-02 folded in** — was [S], now [M] (two questions, two driver types)
- Area: brawl · Owner: qa-playtester (measure) + game-designer (rulings) · Deps: none · uses the game slot — serialize with builders
- Evidence: tools/out/cd_audit/b19_contact.png (2 deaths within ~6 s), d56_brawl_fast/log.json (P1 dead ~4 s in) — audit inference, not yet measured.
  CD1-02 (`round_stats`, 11-stage default Brawl, 192 s combat; `tools/out/cd1/m1/`, `sheet_m1_c.png`, `20_victory_4.png`): three
  human-style drivers lost to one CPU L2 **10-4-2-1**; humans died 27x, **9 self-falls (33 %)**, CPU 6 deaths / **0 self-falls**;
  credited KOs -> final score P1 5->2, P2 2->1, P3 7->4, CPU 10->10; two humans sat at 0 for ~8 stages. Driver != human (CD's caveat).
- Impact: "I KO'd five people, I have 2 points, and the robot won" — the owner's "weird prototype" feeling, every default couch night.
- Do (knockback, unchanged): graze s<=0.15 on Lv0 -> log damage_level, `_last_sting_applied`, hitstun; centre hit same; median
  time-to-first-death and Lv0 non-edge-smash survival rate (victim fuel >= 20) over 20-40 bot stages.
- Do (self-KO, new): repeat the default setup (3 humans + CPU SKILL MIX) with **human-style drivers, not only bots** (bots never
  self-fall, so a bot-only batch will say this is fine); report per-player self-fall share, credited KOs vs final score, CPU win
  rate. First run one 3-lives stage and compare `round_stats.kills` against `scores` deltas (WK-89 repro) so the numbers are trusted.
- Ruling: the self-KO −1 is a **studio spec rule** (spec §2 "suicide = −1"), NOT an owner ruling (the owner's 2026-07-03 directive
  sets KILLS/LIVES/no-timer and is silent on the penalty) — the game-designer decides. Options from the CD: (a) self-KO costs
  nothing by default, "SELF-KO −1" as a RULES toggle; (b) no penalty until a player has scored once; (c) with 2+ humans, CPU SKILL
  MIX resolves to L1-L2 only; or keep as-is with evidence.
- Accept: numbers in `tools/out/wk/WK-20a_measure.json` (both batches) + a contact sheet of 3 recoveries; game-designer writes both
  rulings in DECISIONS: knockback "no fix needed" (WK-20b -> Won't do) or the exact WK-20b gate; self-KO keep (WK-20c -> Won't do)
  or the exact WK-20c change.
- Re-ranked 2026-11-14 (Next-10 #5): measure on the **post-WK-95 build** (95b + 95c merged). WK-95 changes flight, fall-arrest and bot
  super use, so self-fall shares and KO pacing measured before it would be stale on arrival. Screen on (fps ~120) for every number;
  earlier timing data from 12:08-15:50 is void (perf audit). Protocol: docs/specs/wk20a_measurement_2026-11-14.md (ee95d72).
  The WK-95 PadHopper and the wk20a HumanSim share driver code: reuse it, do not fork it.
- Status: open (Next-10 #5; game slot)

### [ ] WK-20c [P1][S] (conditional on WK-20a) Apply the game-designer's self-KO / CPU-mix ruling
- Source: CD1-02 via WK-20a · Area: brawl · Owner: gameplay-programmer · Deps: WK-20a ruling · WK-25's −1 OOPS pop follows the result
- Accept: re-run the WK-20a human-style batch: the ruled behaviour holds (eval `scores` deltas on self-falls) and the RULES toggle,
  if any, persists per mode (WK-07 memory); DECISIONS entry in the same commit.
- Status: open (BLOCKED until WK-20a ruling)

### [ ] WK-20b [P1][S] (conditional on WK-20a) Gate sting/escalation/hitstun at Lv0 on the pre-multiplier impulse
- Sources: D-18 · **OWNER-RULED**: `dmg_launch_mult` array and hitstun triad constants do NOT change; only the impulse fed to the
  sting/escalation gate and hitstun at Lv0 (pre-multiplier) may. DECISIONS entry in the same commit (ruling c).
- Area: brawl · Owner: gameplay-programmer + qa-playtester · Deps: WK-20a ruling
- Accept: graze on Lv0 -> damage_level 0, `_last_sting_applied` 0, hitstun ~0.48 s; centre hit unchanged; >= 50 % of Lv0
  non-edge smashes on victims with fuel >= 20 survived over 40 stages; lethality battery §9 re-run; rendered contact sheet of 3 recoveries.
- Status: open (BLOCKED until WK-20a ruling)

### [x] WK-21 [P1][S] Between-stage budget, half 1: adaptive ScoreScreen hold (2.0 s normal, 3.4 s on lead change / match point) — 43b6abc
- Sources: D-09, R-07 (dead time), **WK-CD1 re-judge (worse than described)** · **OWNER-RULED**: ScoreScreen stays (owner 2026-07-16);
  `SCORE_HOLD` is the sanctioned knob; `round_end_freeze` and countdown untouched
- Area: brawl · Owner: gameplay-programmer · Deps: WK-11 (done) · Pull together with WK-41 (half 2)
- Evidence (WK-CD1): STAGE_END -> next COMBAT took **~9-13 s every stage** (banner -> SCOREBOARD -> STAGE_INTRO -> COUNTDOWN) against
  a median **15 s** of combat (11 stages: 35, 3, 12, 15, 21, 11, 17, 15, 24, 31, 7 s) = **35-40 % of a default match is interstitial**,
  before eliminated players' watching time. The tuned constants (freeze 1.4 + SCORE_HOLD 3.4 + 4 intro pops ~0.8 + countdown 1.05)
  sum to ~6.6 s, so 3-6 s per stage is unaccounted for — find it first.
- Do: log a per-phase timestamp breakdown (STAGE_END, SCOREBOARD, STAGE_INTRO, COUNTDOWN, COMBAT) before changing anything; then
  the adaptive hold + FLY skip via the WK-11 gate.
- Accept (shared with WK-41, CD budget): median STAGE_END -> next COMBAT over 20 non-dramatic stages **<= 6 s**, lead-change /
  match-point stages **<= 8 s**, with the ScoreScreen holding 3.4 s on a lead change (eval timestamps + per-phase table + screenshots).
  If the budget cannot be met without touching `round_end_freeze` or the countdown, stop and take it to the game-designer —
  those are owner-ruled.
- Status: done 43b6abc (designed 4.8 s normal / 6.2 s lead change). The wall-clock budget was "blocked on WK-91" only
  because of display-off data: with the screen on, the perf audit measured 4.78 / 6.18 s, wall = tick (PASS,
  docs/audit/2026-11-14_perf_wk91.md). Option A (UI timers on the real clock) is retired, not needed.

### [x] WK-41 [P1][S] Between-stage budget, half 2: overlays run in sequence; one prompt (countdown ring OR A); SELF-KO label — 43b6abc
- Sources: R-27 (overlap + prompt; names go to WK-59, −1 label pairs with WK-25) · **raised P2 -> P1 2026-11-14** (WK-CD1 downtime
  measurement, director decision: dead time is ~35-40 % of a match; see WK-21 evidence)
- Area: brawl/HUD · Owner: ui-ux-designer · Deps: none · Pull together with WK-21
- Evidence: tools/out/cd_audit/d24_brawl_to_end/f003_STAGE_INTRO.png, d56_brawl_fast/f008_STAGE_INTRO.png; WK-CD1 cadence (WK-21)
- Do: also look at the STAGE_INTRO card on every stage — CD names it "the other half" of the dead time. The intro card must keep
  adding 0.0 s and never gate state (ceremony brief); trimming the stage-2+ intro window is in scope, the 3-2-1 beat is not.
- Accept (rendered): STAGE_END -> SCOREBOARD -> STAGE_INTRO burst shows no frame with two overlays at once; together with WK-21 the
  between-stage budget (<= 6 s normal, <= 8 s lead change) passes.
- Status: done 43b6abc (one overlay at a time; budget PASS with WK-21, see above)

### [x] WK-22 [P1][S] KO blast sprite strip (art) — 5a999db
- Sources: D-01 (art half)
- Area: art · Owner: art pipeline (art-director brief) · Deps: none
- Accept: `assets/fx/ko_blast_*.png` strip, transparent, toybox style, approved by art-director on a rendered test frame.
- Status: done 5a999db

### [x] WK-23 [P1][M] Screen-edge KO blast in the victim's colour (the punchline becomes visible) — 4d5d356
- Sources: D-01 (design audit rated P0), R-31 (KO blast-line part) · **OWNER-RULED**: camera rules untouched — presentation only
- Area: brawl · Owner: gameplay-programmer · Deps: WK-22, WK-08
- Do: `KOEdgeBlast` CanvasLayer on `KillPipeline.killed`; project death point onto viewport edge (EdgeIndicators math);
  top = star-KO twinkle, sides/bottom = column; <= 0.6 s, edge-anchored, never in the middle 60 %.
- Accept (rendered): 20 forced ring-outs across 3 arenas, all 4 edges, burst screenshots at +0.05 s and +0.3 s: 20/20 show a
  victim-coloured blast at the nearest edge.
- WK-CD1: still the #1 fantasy gap — "across 11 stages I could rarely tell who killed whom from the screen"; at 0.46-0.62 zoom a KO
  is a speck leaving the frame.
- Status: done 4d5d356. WK-CD2 re-judges "can you tell who KO'd whom" (item 1).

### [x] WK-24 [P1][S] Hits carry the attacker's colour (impact burst, knockback streak, last-touch ring) — 4d5d356
- Sources: D-06, D-02 (part 2 last-touch tag)
- Area: brawl · Owner: gameplay-programmer · Deps: WK-08
- Accept (rendered): frame-grab 10 smashes: burst/streak hue = attacker colour 10/10; victim in credit window shows a thin
  attacker-coloured ring; streak value >= 0.8 (launch read kept).
- Status: done 4d5d356 (streak = attacker colour per DECISIONS e2394c1)

### [ ] WK-25 [P1][M] KO credit pop (+1 flies to killer's card, −1 OOPS on self-fall) + ScoreScreen kill list
- Sources: D-02 (parts 1+3), R-27 (unlabelled "−1"), R-06 (score-visibility half) · **OWNER-RULED**: no persistent combat score — the pop is transient (<= 1.5 s)
- Area: brawl/HUD · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-23, WK-08, **WK-20a self-KO ruling** (+ WK-20c if
  ruled; the −1 OOPS half changes or disappears with the rule) and WK-89 if confirmed (the kill list reads `round_stats`)
- WK-CD1: "points appear and disappear between overlays"; nothing on screen shows the −1 subtraction (CD1-02).
- Accept (rendered): 4-bot match, 30 deaths: every credited kill shows a killer-coloured +1 reaching the right card within 1.0 s,
  every uncredited death shows −1/+0 on the victim card (eval `scores` before/after, 0 mismatches); ScoreScreen lists
  "P2 ▶ P3" / "P4 SELF-KO −1".
- Status: open (Next-10 #6; blocked on the WK-20a ruling)

### [ ] WK-26 [P1][S] Super-aim wind-up sound + "!" over the targeted goat
- Sources: D-07
- Area: brawl/audio · Owner: gameplay-programmer + sound-designer · Deps: none (bleat layer waits for WK-53 asset)
- Accept: `EventBus.super_aim_started` fires; `AudioManager.last_sfx == "super_aim"` on aim entry; 10 scripted aims -> "!" on
  the correct target >= 9/10 within 2 frames (rendered screenshots of 3).
- Re-ranked 2026-11-14 into Next-10 #9: the WK-95 owner ruling makes the super THE attack, so its telegraph carries more weight.
  Build after WK-94 commits (the "!" must follow the smoothed aim target, not the old per-frame jitter).
- Status: open

### [ ] WK-27 [P1][M] Herd Lobby slice 4: Sports — picking the goat picks the team
- Sources: C-16 (sports half), C-31, R-14 (sports half), E.6, lobby review L2 (17a/17b: ZIGGY/PUFF still selectable in ROCKETBALL)
- Area: menus/sports · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-07 (done)
- Do: carousel = POGO/BILLY (RED), BUTCH/VEX (BLUE), team ribbon, full-team goats skipped; `MatchConfig.team_ids`;
  `SportsMode.spawn_plan` honours team_ids + human skins (keep even-total clamp, bot mirroring); CPUs fill seats.
- Accept (rendered): 2 humans pick POGO + VEX with 2 CPUs -> 2v2 with one human per team; the picked goat skins appear in
  the match (no repaint); 2 humans both RED -> 2 humans vs 2 CPUs.
- Raised 2026-11-14 (owner check-in, WK-98 sports weight) into Next-10 #3. The build is code-only (HerdLobby/LobbySlot, MatchConfig,
  `SportsMode.spawn_plan`): it may be built in parallel with WK-95 and only needs the game slot to verify. `SportsMode.gd` has small
  uncommitted in-flight edits (6 lines) — coordinate with their owner before touching it.
- Status: open

### [ ] WK-28 [P1][M] Controller disconnect: auto-pause overlay in match, DISCONNECTED slot in lobby, connect toasts
- Sources: C-07, R-32 (toasts/disconnect), CC-3.4/3.5, lobby review L3 (06_19: a lost pad frees its slot instantly — a cable wiggle wipes a pick)
- Area: brawl/menus · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-03, WK-06 (both done) — pullable
- Lobby half (L3): greyed bust, 10 s RECONNECT ring, "(A) ON ANY CONTROLLER TO TAKE OVER"; an open RULES flip closes keeping values.
- Accept (rendered, via `InputRouter.simulate_device_lost`): mid-match pad1 lost -> "P3 CONTROLLER DISCONNECTED" overlay in
  P3's colour; pad1 A resumes; unjoined pad2 A takes over P3; RESUME WITHOUT P3 works; in lobby the slot shows
  RECONNECT ring 10 s then EMPTY. Screens `tools/out/wk/WK-28_*.png`.
- Status: open

### [ ] WK-29 [P1][M] One device-aware glyph component (pad circles/pills, key caps) used everywhere
- Sources: C-23, R-23, C-11 (glyph half), CC-1.6/1.7, lobby review L12 (ModeSelect/ArenaSelect 10a/11a: old key caps + ASCII "< >" beside the lobby's glyph chips)
- Area: menus/HUD · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-03 (done)
- Note: the lobby already has PadGlyph chips + the amended CC-1.6 shared-glyph rule (WK-81 f1a9fdd) — generalise THAT component, don't build a second one.
- Accept (rendered): HintStrip, ControlsLegend, lobby panels, Trials hints show Xbox glyphs after pad input and key caps after
  keyboard input (screenshot pairs); no ASCII "(A)" or "< >" left (grep); Trials no longer says "HOLD A / SPACE".
- Status: open

### [ ] WK-30 [P1][S] Keyboard parity in menus (WASD nav, Q/E pages, prompts tell the truth)
- Sources: C-11 (bindings half), CC-2.1 (R/Tab/Enter already added in WK-01)
- Area: menus · Owner: gameplay-programmer · Deps: WK-01
- Accept (rendered): ModeSelect/ArenaSelect/Options fully navigable with WASD only; Q/E page the shelf; every footer prompt
  works on keyboard.
- Status: open

### [ ] WK-31 [P1][M] HUD card shows danger: damage-level state, labelled fuel, stocks when LIVES > 1
- Sources: R-06 (damage/lives half) · **OWNER-RULED**: no persistent KO score on cards (see Deferred)
- Area: HUD · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-08
- Accept (rendered): eval damage_level 0/1/2 on P1 -> card shows three distinct states; fuel bar has an icon; LIVES 3 shows 3 pips.
- WK-CD1: on a LIVES 3 stage no stock count is shown anywhere (`tools/out/cd1/sheet_m4.png`).
- Status: open

### [ ] WK-32 [P1][M] Make the goat pick real: wire CharacterProfiles OR declare cosmetic and rewrite blurbs
- Sources: D-10, C-16 (roster half), R-14 (roster half) · feel-adjacent: re-run the v2 feel-delta battery if wired
- Area: brawl · Owner: game-designer (decision) + gameplay-programmer · Deps: WK-20a (+ WK-20b if ruled) — lethality baseline first
- Split when pulled: WK-32a decision (S, game-designer, DECISIONS entry) -> WK-32b wire + battery OR blurb rewrite (S/M).
- Accept: wired -> `players[i].profile` matches pick for 4 slots and no hero's self-fall rate > 1.5x Standard over 40 stages,
  stat pips visible in the lobby (screenshot); cosmetic -> blurbs rewritten as personality, DECISIONS entry.
- Status: open

### [ ] WK-33 [P1][M] CONTROLS screen (full move set, device glyphs) reachable from Pause and Options
- Sources: C-12 (screen half), C-20 (CONTROLS entry), R-22 (controls view), CC-11.1, CC-7.1
- Area: menus · Owner: ui-ux-designer · Deps: WK-29, WK-09
- Accept (rendered): Pause -> CONTROLS and Options -> CONTROLS open the same scene; shows "hold X to aim, release to fire",
  B returns one level; pad and keyboard glyph variants screenshotted.
- Status: open

### [ ] WK-34 [P1][M] Toybox panel kit A: Pause, in-match Options, ScoreScreen
- Sources: R-11, R-22 (pause BACK overlaps P1 card, v0.1 overlaps P4)
- Area: menus/art · Owner: ui-ux-designer · Deps: WK-17
- Accept (rendered): the three screens use the cream/chocolate frame + header ribbon + shell buttons; no dark-navy plate;
  nothing overlaps HUD cards. art-director/ui-ux verdict.
- Status: open

### [ ] WK-35 [P1][M] Toybox panel kit B: Victory final score, Trials objective banner, Sports scoreboard
- Sources: R-11
- Area: menus/art · Owner: ui-ux-designer · Deps: WK-34
- Accept (rendered): same kit on the three screens (screenshots); ui-ux verdict Ship; the restyled Trials objective panel keeps the
  WK-87 placement (never over the goal ring).
- Status: open

### [ ] WK-36 [P1][M] Off-screen magnifier bubbles (watch the recovery live)
- Sources: D-05, R-30 · **OWNER-RULED**: camera framing untouched (owner rules 2026-07-10) — EdgeIndicators upgrade only
- Area: brawl/HUD · Owner: gameplay-programmer · Deps: WK-08
- Accept (rendered): player knocked 1500 px above top platform -> edge bubble with goat sprite + fuel ring within 10 % of
  `get_fuel_ratio()`; aim arrow shows within 1 frame of super aim off-screen.
- Status: built — awaiting rendered verification (second gameplay-programmer; uncommitted `EdgeIndicators.gd` +351 lines).
  Motion HUD: verify with a WK-93 recording of one off-screen recovery as well as the Accept stills.

### [ ] WK-37 [P1][M] Ghost goats: eliminated players float, quack and get one non-lethal heckle per stage
- Sources: D-08, R-07 (spectating half)
- Split: **WK-37a [S] spec** (game-designer, `docs/specs/` entry with the QA criteria below; no game slot — can run in parallel
  any time) -> **WK-37b [M] build** (gameplay-programmer). `scope-check` on the spec (new system).
- Area: brawl · Owner: game-designer (spec) + gameplay-programmer · Deps: WK-04 (done); quack needs WK-53; GHOSTS option lives on the RULES panel back (WK-07 done)
- Accept (rendered): eliminated human's ghost moves from their device within 1.0 s; 40 % alpha, no flame; excluded from camera;
  heckle puff never credits a kill over 20 stages; option GHOSTS ON/OFF in RULES.
- WK-CD1 re-judge (matters more than described): a group that raises LIVES to 3 "to play longer" waits LONGER — P3 eliminated
  ~30 s in, then watched a 1v1 for over a minute (`tools/out/cd1/sheet_m4.png`). Keeps WK-37a high on deck.
- Status: open

---

### [ ] WK-90 [P1][S] (RE-MEASURE with screen on first) Hit-stop fires after ~3 frames regardless of duration (Godot 4.7 timer arg quirk) — design call first
- Source: WK-23/24 programmer, 2026-11-14. `Juice._hitstop` uses `create_timer(t, true, false, true)`, which in 4.7 fires
  after ~3 frames whatever `t` is (reproduced outside eval). Designed 30-100 ms freeze + 120 ms ease-out actually lasts a
  few frames: ~0.1 s at 120 FPS, ~0.75 s at 16 FPS — so hit feel is FRAME-RATE DEPENDENT today.
- Owner: game-designer ruling (feel was tuned around the bug) -> gameplay-programmer. Hitstun triad untouched.
- Do: measure actual freeze duration at 30/60/120 FPS; designer decides target (designed values vs. tuned-in feel);
  fix the timer call so duration is real-time and FPS-independent.
- Accept: freeze duration within ±10 ms of the Tuning value at 30 and 60 FPS (eval timestamps); qa feel note.
- Re-measure note (perf audit rec 2): the "0.75 s at 16 FPS" figure came from the display-off state. At a real 120 fps the freeze is
  ~0.1 s, so couch impact today is smaller than filed; the `create_timer` argument question still stands. Step 1 is the measurement
  (screen on, 30/60/120 fps caps); no code change until the game-designer rules on those numbers. Hit-feel must stay stable through
  WK-95, so measure on the post-95b build.
- Area: brawl (feel) · Source: gameplay-programmer 2026-11-14 + performance-analyst perf_wk91 rec 2
- Status: open (Next-10 #8; evidence pending re-measure)

### [x] WK-91 [P0][M] Performance: 16-30 FPS at 1920x1080 on the studio machine (~90 draw calls) — da8337b
- Source: WK-23/24 programmer, 2026-11-14 (not caused by the new FX). A couch party game must hold 60.
- RAISED TO P0 (WK-21 rendered pass): ~12-20 frames of 500-620 ms every ~15 s even mid-combat with no eval
  traffic, same at 720p and 1080p (not fill-rate), machine CPU 9%, headless peaks 45-87 ms. Hitches freeze
  physics-tick timers (8 ticks/frame cap) -> between-stage flow 1-2 s over budget, hit-stop FPS-dependent (WK-90).
  Evidence tools/out/wk/WK-21_timing_*.json. Fallback if unfixable: WK-21 option A (UI timers on real clock).
- Owner: performance-analyst (measure + attribute) -> gameplay-programmer.
- Do: `gbplay perf` + frame-time capture on 3 arenas at 1280x720 vs 1920x1080; isolate GPU vs CPU (shader-heavy
  backdrops? particle counts? physics?); check renderer setting (Forward+/Mobile/Compatibility) and vsync; A/B the top 3
  suspects. Recommend fixes with evidence.
- Accept: report with attribution; follow-up fix item(s) filed; target >= 55 fps average at 1080p on this machine.
- Status: done da8337b — CLOSED AS ENVIRONMENT, not a game bug. Display-off Modern Standby throttled the window to ~30 Hz with
  ~500 ms present stalls; with the screen on the build holds 119.6 fps at 1080p (median 8.33 ms, p95 9.17 ms). The real cost found
  on the way (stage load 50-271 ms on theme change) was fixed in the same commit (ArenaRenderer texture cache, now 4-34 ms).
  Report: docs/audit/2026-11-14_perf_wk91.md. Follow-ups filed: WK-100 (pre-flight), WK-101 (residual load spike), WK-102 (hygiene);
  WK-90 re-measure noted. The "fallback option A" above is retired.


### [ ] WK-92 [P2][S] Font follow-ups from WK-17 grade
- Source: ui-ux-designer WK-17 verdict (tools/out/wk/WK-17_*). Owner: gameplay-programmer.
- (1) Victory winner name: chocolate ribbon behind it like StageIntroCard (yellow Puff over gold rays is weakest);
  (2) MATCH POINT top banner overlaps the leaving StageIntroCard ribbon ~0.2 s — delay show_top until intro exit;
  (3) Rocketball card "(Okay" sidebearing — drop parentheses; (4) the ✓ on menu cards still uses a system font —
  swap for PadGlyph's drawn check. Small-text floor items stay in WK-18.
- Accept: screenshots of Victory (Puff winner), MATCH POINT stage intro, ModeSelect.
- Status: built — awaiting rendered verification (gameplay-programmer, with WK-15/WK-88; uncommitted VictoryScreen/MenuCard/PadGlyph edits).


### [ ] WK-103 [P2][S] Pendulum follow-ups: Trials pendulum courses now smash; art-director grade; boost-arrow flick
- Source: WK-96 builder. Pendulums smash in ALL modes incl. Trials (course_04_pendulum_pass, swing_mines, wrecking_yard
  — untested; levels can opt out with "contact": "shove"). Peak speed 3800 -> 2650 px/s (feel unjudged). Bot normal-boost
  arrow still flicks >30 deg on 7-13% of frames (folded into WK-95 build brief). Art-director grade of the new swing
  (tools/out/rec/wk96_pendulum_after/swing_60-162_sheet.png).
- Accept: Trials pendulum courses completable (recording), art-director Ship.


## P2 — visible polish gaps

### [ ] WK-85 [P2][S] Tall arenas: backdrop painting stretches into a murky smear; tall themed platforms gap
- Source: WK-12 spot render (tools/out/wk/WK-12_the_summit.png, WK-12_twin_towers.png). Owner: gameplay-programmer + art.
- the_summit / sky_ladder_brawl (2100+ px tall): space_nebula scaled to cover reads as flat dark navy. Options: tile/parallax
  the painting vertically, or a starfield layer for tall space arenas. Themed bodies only draw a 64/128 px strip, so
  96 px+ platforms show an art-less band (perch_line, gauntlet_ridge, zenith, Scrapworks bolt_yard/the_ascent);
  twin_towers pinned to grass as a stopgap. Make themed bodies fill full collider height (as grass earth does).
- WK-CD1 re-judge (broader than "tall arenas"): the FIRST Trials course shows it too — the bottom ~35 % of the screen is a flat
  mint-green fill under the painted hills, goats fly through what reads as an unpainted void (`tools/out/cd1/46_trials_go.png`,
  `48_trials_after.png`). First impression of Trials. If the Trials backdrop needs its own fix, split it off as a separate S.
- Accept: the_summit + twin_towers + zenith screenshots read as a painted sky with fully skinned platforms; Flight School lesson 1
  shows no flat fill band below the painting.
- Status: open

### [ ] WK-87 [P2][S] Trials objective panel never covers the goal ring
- Area: trials/HUD · Owner: ui-ux-designer · Source: creative-director WK-CD1 (CD1-03)
- Evidence: `tools/out/cd1/48_trials_after.png` — Flight School lesson 1 "FIRST FLIGHT": the dark "1 of 2 HOME" panel sits top-centre,
  exactly where the ring ends up once the camera re-frames; only a green arc of the target shows.
- Impact: the very first Trials instruction is "fly up to the ring" and the ring is hidden. Every new player, lesson 1.
- Do: move the panel to a corner, or collapse it to a small chip after ~3 s (or reserve a top band via the `camera_focus_points`
  seam — camera rules are owner-ruled, so prefer the HUD move). WK-35 restyles the same panel later and must keep this placement.
- Accept (rendered): Flight School lesson 1 at BOUNCE+0 s and +4 s with 1 and 2 players: the goal ring is fully visible in both.
- Status: open (Next-10 #10)

### [ ] WK-88 [P2][S] One naming rule for every fighter in match text (CPU vs VEX vs "VEX — CPU")
- Area: HUD/brawl · Owner: ui-ux-designer (rule) + gameplay-programmer · Source: creative-director WK-CD1 (CD1-04, CD rated P3;
  producer rates P2: a couch group asks "who is Vex?") · extends the identity systemic (WK-08/WK-10, both done)
- Evidence: `tools/out/cd1/m1/f005_STAGE_END.png`, `m1/f029_STAGE_END.png`, `20_victory_4.png` — bot card/pip say CPU, banners say
  "VEX SURVIVES!" / "P1 +1 · P2 +1 · VEX +1", Victory says "VEX — CPU"; humans are "P1" in banners but "BUTCH P1" on Victory.
- Do: pick one rule for HUD, pips, banners, ScoreScreen and Victory (e.g. humans "P#" everywhere; CPUs "CPU" + goat colour, or
  "VEX (CPU)" everywhere). WK-76's "bot tag shows hero name" must follow whatever is chosen; Victory contrast stays in WK-42.
- Accept (rendered): 2H+2CPU Brawl: HUD card, stage banner, ScoreScreen row and Victory row name each fighter the same way (4 screenshots).
- Status: built — awaiting rendered verification (gameplay-programmer, with WK-15/WK-92). Needs the 4 screenshots + ui-ux rule note.

### [ ] WK-89 [P2][S] `round_stats` may under-record kills when LIVES > 1 (instrumentation — unverified, seen once)
- Area: tooling/brawl · Owner: qa-playtester (repro) -> gameplay-programmer (fix if confirmed) · Source: creative-director WK-CD1 (CD1-06)
- Evidence (unverified): Grassy Expanse, LIVES 3, 63.5 s game time, final scores 2-0-5-1, but `round_stats[0].kills` held ONE entry
  (P1's self-fall at t=1). Seen once, not root-caused.
- Impact: not player-facing today, but WK-20a, WK-25 (ScoreScreen kill list), WK-55 and WK-57 all decide from `round_stats`; any
  non-default LIVES measurement would be wrong.
- Do: the repro runs at the start of the WK-20a session (one 3-lives stage, `kills` vs `scores` deltas). Confirmed -> fix; not
  reproduced in 3 stages -> Won't do with the numbers.
- Accept: 3 LIVES-3 stages where `round_stats.kills` count equals the sum of credited + self-fall score events (eval log).
- Status: open (unverified)

### [ ] WK-38 [P2][S] Gate the 9090 automation server behind `--gb-dev` AND update run_game.ps1 in the SAME commit; version label only on title + Options
- Sources: C-28, CC-12.1, CC-8.4 · **WARNING**: landing the gate without `run_game.ps1` passing `-- --gb-dev` breaks gbplay and every later rendered QA — one commit, verify both
- Area: tooling · Owner: gameplay-programmer · Deps: none (do not interleave with a running QA session)
- Accept: `PLAY GOTTABOUNCE.bat` run -> nothing listening on 9090 (`netstat`); `tools/run_game.ps1` -> "Interaction server UP on 9090"
  and a gbplay screenshot succeeds; "v0.1" absent from ModeSelect/Lobby/ArenaSelect screenshots.
- Status: open

### [ ] WK-39 [P2][S] Hide the mouse cursor on pad/keyboard input and always in gameplay; hover focuses only after real motion
- Sources: C-26, CC-2.4, CC-12.2
- Area: menus · Owner: gameplay-programmer · Deps: WK-03
- Accept (rendered): screenshot mid-match shows no cursor; resting cursor over a sliding-in screen does not steal pad focus.
- Status: open

### [ ] WK-40 [P2][S] "B BACK" is a glyph chip, not a focus stop; fix ModeSelect back wiring
- Sources: C-24, CC-5.5, CC-5.2
- Area: menus · Owner: ui-ux-designer · Deps: WK-29 (glyph)
- Accept (rendered): pad focus never lands on a back button on ModeSelect/ArenaSelect/Options; mouse click on the chip goes back.
- Status: open

### [ ] WK-42 [P2][S] Victory screen: hide combat HUD, consistent button copy/size, readable CPU name
- Sources: R-28
- Area: menus · Owner: ui-ux-designer · Deps: WK-14
- Evidence: tools/out/cd_audit/25_victory_settled.png
- Accept (rendered): no HUD corner cards on Victory; buttons equal width, "QUIT TO MENU" copy; winner name contrast >= 4.5:1.
- WK-CD1: "VEX — CPU" in purple over the yellow burst is hard to read (`tools/out/cd1/20_victory_4.png`) — contrast stays here; the
  naming rule is WK-88. QUIT TO MENU still lands on the title and clears the lobby (R-26): the label must match the destination.
- Status: open

### [ ] WK-43 [P2][S] Trials co-op polish: offset spawns, "GO!" not "FIGHT!", banner backplates, longer first lesson
- Sources: R-29
- Area: trials · Owner: level-designer + ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/39_trials_1s.png, 38_trials_circuits.png, 41_contact.png
- Accept (rendered): 2P course 1 spawns visibly apart; circuit confirm reads "GO!"; COURSE CLEAR has an outline/backplate; course 1 takes >= 4 s of flying for a human-style drive.
- WK-CD1: the Trials circuit-select footer also says "(A) FIGHT!" in the co-op mode (`tools/out/cd1/44_trials_select.png`) — front-end copy is in scope.
- Status: open

### [ ] WK-44 [P2][M] Options rebuild: aligned grid, RUMBLE toggle, SCREEN SHAKE (OFF/LOW/FULL), CONTROLS entry
- Sources: C-30, R-22, C-10 (toggle), R-32 (rumble option)
- Area: menus · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-19, WK-33
- Accept (rendered): rows aligned at the same x; toggles persist across relaunch (eval Settings); SCREEN SHAKE OFF -> zero trauma on a smash (eval).
- Status: open

### [ ] WK-45 [P2][S] Distinct UI sounds (move/confirm/back/deny/join x4/ready/all-ready/hold-tick)
- Sources: C-22, CC-9.1, lobby review L4 (lobby uses re-pitched powerup/super/click placeholders)
- Area: audio · Owner: sound-designer · Deps: none · Note: CC0 audio is already allowed (DECISIONS 2026-11-14 ruling b2; licence note in `assets/sfx/LICENSES.md`)
- Lobby set (L4): `ui_join` (slot-pitched), `ui_ready`, `ui_all_ready` banner sting, `ui_deny`, `ui_hold_tick`, `ui_card_flip`
  (RULES flip); the per-goat bleat on lock reuses the WK-53 bleat when it exists.
- Accept: each UI event sets a distinct `AudioManager.last_sfx` id (eval across ModeSelect/Lobby/Pause); join pitch rises P1->P4.
- Status: open

### [ ] WK-46 [P2][M] Menu nav repeat on held D-pad/stick + explicit LS axes on `ui_*`
- Sources: C-21 (global half; lobby half in WK-05), CC-5.3
- Area: menus · Owner: gameplay-programmer · Deps: WK-03
- Accept (rendered): holding pad right on ArenaSelect moves >= 5 cards in 1 s after 0.40 s delay; LS navigates with hysteresis (no double-steps).
- Status: open

### [ ] WK-47 [P2][S] Identity-colour rim on each goat body
- Sources: R-05 (rim part), R-04 (Smash-ring alternative) — sunset arena PUFF/BILLY confusion
- Area: brawl/art · Owner: gameplay-programmer + art-director · Deps: WK-08
- Accept (rendered): sunset arena with PUFF + BILLY: rims distinguishable at gameplay zoom (art-director verdict).
- Status: open

### [ ] WK-48 [P2][S] Dry-tank tell: jetpack sputters when fuel < super minimum
- Sources: D-19
- Area: brawl · Owner: gameplay-programmer · Deps: none
- Accept (rendered): eval fuel=3 -> sputter emitter visible; fuel=50 -> not.
- Status: open

### [ ] WK-49 [P2][S] Powerup name pop on pickup + a distinct activation sound per powerup
- Sources: D-20a
- Area: brawl/audio · Owner: gameplay-programmer + sound-designer · Deps: WK-08
- Accept: each of the 7 powerups sets a distinct `last_sfx`; pickup shows "STAR!" etc. in holder colour (3 screenshots).
- Status: open

### [ ] WK-50 [P2][S] Supercharge feedback (distinct spring SFX + gold ring burst)
- Sources: D-25a
- Area: brawl · Owner: gameplay-programmer · Deps: none
- Accept: supercharged bounce emits a distinct SFX id and a visible ring (burst screenshot).
- Status: open

### [ ] WK-51 [P2][M] Super contact reads as THE hit (bigger impact burst + screen flash)
- Sources: R-31 · **OWNER-RULED**: no camera punch-in (owner camera rules); hitstop duration is a feel constant — leave it unless game-designer rules
- Area: brawl · Owner: gameplay-programmer + art-director · Deps: WK-23, WK-24
- Accept (rendered): contact sheet of 5 super hits at gameplay zoom: impact readable from a downscaled 640x360 frame (CD verdict).
- Status: open

### [ ] WK-52 [P2][S] KO meta counts human KOs only and moves off the shared lobby; unlock toast becomes a banner card
- Sources: R-25, R-24 (toast part)
- Area: menus · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-06
- Note: the lobby half may be moot — HerdLobby.gd has no KO-meta chip (the old CharacterSelect was deleted). QA re-check; the human-only count + toast-card halves stay.
- Accept: all-bot match -> counter unchanged (eval); lobby shows no KO chip; unlock toast renders as a card with icon.
- Status: open

### [ ] WK-53 [P2][S] Taunt / quack (goat bleat per hero) — needs a bleat sample
- Sources: D-15 · Binding: pad Y [3] / keyboard per CC-2.2 (Y is unused in gameplay per CC-1.1)
- Area: brawl/audio · Owner: sound-designer + gameplay-programmer · Deps: none · Note: no bleat in assets/sfx; source a CC0 one (ruling b2). The bleat is shared with WK-45 (lobby lock) and WK-37 (ghost quack)
- Accept: taunt -> `last_sfx` starts "bleat_" within 1 frame in COMBAT and on ScoreScreen; 10 presses/s -> <= 3 sounds; "BAAA!" puff in colour (screenshot).
- Status: open

### [ ] WK-54 [P2][S] Rotating tips + per-player legend that holds until each human has used FLY and SUPER (cap 12 s)
- Sources: D-13b, D-13c, D-25b
- Area: HUD · Owner: ui-ux-designer · Deps: WK-15, WK-29
- Accept (rendered): fresh save, 2 humans: legend persists until both used FLY + SUPER (logged) or 12 s; tips suppressed after 3 matches.
- Status: open

### [ ] WK-55 [P2][M] Post-match awards from `round_stats` (HEADBANGER, KAMIKAZE, SNIPER, …)
- Sources: D-14
- Area: menus · Owner: game-designer + gameplay-programmer · Deps: WK-35, WK-11 (awards animate after arm, never delay REMATCH)
- Accept: every finished 4-player match shows 3 award cards whose stats match `round_stats` (eval spot-check 5 matches, screenshots).
- Status: open

### [ ] WK-56 [P2][S] Stall breaker by escalation (faster powerups at 20 s, golden bubble at 30 s)
- Sources: D-23, R-07 (sudden-death alternative) · **OWNER-RULED**: no timer may END a stage (owner 2026-07-03) — this only offers
- Area: brawl · Owner: gameplay-programmer · Deps: none
- Accept: scripted 1v1 no smashes 30 s -> golden bubble spawns at 30-31 s; stage-end causes unchanged.
- Status: open

### [ ] WK-57 [P2][M] Arena scorecard tool (10 bot stages per arena -> stage length, credited share, self-falls, min zoom)
- Sources: D-16a, R-05 (min camera zoom per arena = the lever that feeds the owner camera rule)
- Area: tooling · Owner: qa-playtester / tooling · Deps: WK-20a/b (lethality baseline)
- Accept: `tools/out/arena_scorecard.json` covers all 94 arenas with every metric populated.
- Status: open

### [ ] WK-58 [P2][M] Arena quality tiers + cull/retune pass
- Sources: D-16b, STATUS "~55 fresh arenas want a fun pass"
- Area: brawl/levels · Owner: level-designer · Deps: WK-57
- Accept: each circuit pool keeps >= 12 arenas passing (credited share >= 45 %, median stage <= 25 s); top picks get a human-style QA drive.
- Status: open

### [ ] WK-59 [P2][M] Arena hook line + player-facing names on the StageIntroCard
- Sources: D-16c, R-27 (dev-ish names "ISLANDS VOID", "GRASSY EXPANSE")
- Area: levels/HUD · Owner: level-designer · Deps: none
- Accept: 100 % of arena JSONs have a non-empty `hook`; stage intro screenshot shows name + hook.
- Status: open

### [ ] WK-60 [P2][S] ArenaSelect copy and layout fixes ("WAYS TO PLAY", "1 / 6", RANDOM card copy, empty lower half)
- Sources: R-20 (copy/layout half)
- Area: menus · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/14_arena_select.png, 15_arena_select_right.png
- Accept (rendered): screenshot shows corrected copy, no dead half-screen; ui-ux verdict.
- Status: open

### [ ] WK-61 [P2][M] Pick a single stage inside a circuit (circuits stay as playlists)
- Sources: R-20 (stage-pick half) · run `scope-check` first (adds a flow)
- Area: menus · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-60, WK-59
- Accept (rendered): choose circuit -> STAGE grid -> pick one arena -> match loads that arena; RANDOM ROTATION still works.
- Status: open

### [ ] WK-62 [P2][S] Team Brawl spec (2v2, co-op vs CPU, friendly fire) — spec only
- Sources: D-11 · touches the smash licence -> spec with QA criteria first; `scope-check` (new system)
- Area: brawl · Owner: game-designer · Deps: WK-07
- Accept: `docs/specs/` entry with QA criteria (0 teammate smashes with FF off, stage ends when one team left, team totals).
- Status: open

### [ ] WK-63 [P2][M] Team Brawl build
- Sources: D-11
- Area: brawl/menus · Owner: gameplay-programmer · Deps: WK-62, WK-27 (team UI pattern)
- Accept: spec criteria pass in a rendered 2v2 + a 2-humans-vs-2-CPU run (eval `round_stats`).
- Status: open

### [ ] WK-64 [P2][M] Scoring rule option KO RACE / SURVIVOR / HYBRID in RULES
- Sources: D-04 (rule half) · **OWNER-RULED**: default stays KO RACE; HYBRID-as-default is only a recorded candidate
- Area: brawl · Owner: gameplay-programmer · Deps: WK-07
- Accept: SURVIVOR -> survivor with 0 KOs gets +1 (eval); KO RACE byte-identical over a 10-stage parity run.
- Status: open

### [ ] WK-65 [P2][M] Painted court-select cards (Rocketball + Dropshot, 11 courts)
- Sources: R-15 (cards half) · art generation
- Area: art/sports · Owner: art pipeline + art-director · Deps: none
- Evidence: tools/out/cd_audit/44_rocketball_courts.png, 50_dropshot_4s.png
- Accept (rendered): court select screenshots show illustrated cards matching Brawl/Trials quality; art-director approval.
- Status: open

### [ ] WK-66 [P2][M] Court in-game art: tiled crackable Dropshot floor, goal net sprite, a real beach, frame-filling stadium
- Sources: R-15 (in-game half) · art generation
- Area: art/sports · Owner: art pipeline + level-designer · Deps: WK-65 (shared style)
- Evidence: tools/out/cd_audit/45_rocketball_1s.png, 51_dropshot_start.png, 52_dropshot_4s.png
- Accept (rendered): SUNSET BEACH shows a beach; floor tiles visibly crack; goals have a framed net; no letterbox frame.
- Status: open

### [ ] WK-83 [P2][S] Lobby: "who are we waiting on" nudge + title-safe layout
- Source: ui-ux-designer lobby review L7 + L9 · Area: menus · Owner: gameplay-programmer (lobby builder) · Deps: none
- Evidence: L9 code-verified 2026-11-14 — HerdLobby.tscn Header/BackBtn offset_top 22, Footer offset_bottom 1066 (1080 space). L7 is a missing cue (spec).
- Do: (L7) a READY player pressing A/Start before the banner nudges every still-PICKING panel (8 px, 0.12 s) and flashes its
  status bar (the RULES-open nudge already exists — reuse `nudge`); (L9) header chips start at y >= 40, footer bottom <= 1030.
- Accept (rendered 1920x1080): burst shows PICKING panels nudge on a READY player's early Start; header/footer inside the 5 % safe area.
- Status: open

### [ ] WK-84 [P2][S] READY banner polish (the flattest element at the screen's peak moment)
- Source: ui-ux-designer lobby review L5 · Area: menus/art · Owner: ui-ux-designer (+ art-director verdict) · Deps: none (font pass WK-17 first is nicer, not required)
- Do: 6 px chocolate top/bottom border, white 0.22 gloss stripe over the top 30 %, GO glyph 60 px tall (now ~40 px beside 76 px text).
  Painted ribbon art (E.11) is optional and cut this weekend (see Deferred).
- Accept (rendered 1080p): banner capture beside the review's 18b; ui-ux Ship verdict.
- Status: open

---

## P3 — nice-to-have

### [ ] WK-67 [P3][M] Second keyboard player (KB-R scheme, `kb2` device key)
- Sources: C-33, CC-2.2 · Owner: gameplay-programmer · Deps: WK-06
- Accept (rendered): kb and kb2 join separate lobby slots and drive separate goats (eval positions).

### [ ] WK-68 [P3][S] Hold-View score glance + trigger alternate bindings (RT boost, RB super)
- Sources: C-36 · **OWNER-RULED**: on-demand only, never a persistent combat score · Owner: gameplay-programmer · Deps: WK-35
- Accept (rendered): holding View shows the corner score overlay, release hides; RT boosts.

### [ ] WK-69 [P3][S] Per-slot FLAIR row in each lobby panel (everyone can wear unlocks)
- Sources: D-30, E.4 FLAIR row · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-06
- Accept (rendered): P2 equips GOLDEN JETSTREAM and their streak is gold in-match; Sports suppression kept.
- Status: **likely already built** (fe2a99c/f1a9fdd: per-slot FlairRow, `MatchConfig.flair_ids`, PartyMatch.gd:293). Needs a QA
  re-check against the Accept line to close — do not close on the code read.

### [ ] WK-70 [P3][S] Session tally across rematches ("TONIGHT'S CHAMPION")
- Sources: D-22 · Owner: gameplay-programmer · Deps: WK-07
- Accept: 3 rematches won by blue -> 3 trophies on blue on Victory; relaunch clears.

### [ ] WK-71 [P3][S] ITEMS switch (OFF/LOW/NORMAL/HIGH) in RULES
- Sources: D-20b · Owner: gameplay-programmer · Deps: WK-07
- Accept: ITEMS OFF -> 0 bubbles over 10 stages (eval).

### [ ] WK-72 [P3][M] Bot powerup brain v1 (detour to nearby bubbles, shield vs aimed super)
- Sources: D-20c, D-26 (part) · Owner: gameplay-programmer · Deps: WK-26 (aim signal)
- Accept: L4 bots collect >= 40 % of bubbles in all-bot matches; motion-health clean.

### [ ] WK-73 [P3][M] Match variants (MOON GRAVITY, TINY GOATS, …) as per-match Tuning overrides
- Sources: D-12 · **OWNER-RULED**: hard deny-list (hitstun triad, super impulse, fuel_per_bumper, dmg_launch_mult); `scope-check` (new system)
- Owner: game-designer + gameplay-programmer · Deps: WK-07
- Accept: MOON GRAVITY -> `Tuning.gravity == 960`, quit restores 1600; loader rejects a JSON naming `hitstun_base`.

### [ ] WK-74 [P3][S] Handicap (STURDY) + optional CROWN BOUNTY
- Sources: D-21 · scoring option, default off · Owner: gameplay-programmer · Deps: WK-07
- Accept: STURDY -> `eff_knockback_taken() == 0.90`; bounty KO adds 2 (eval).

### [ ] WK-75 [P3][M] Head-on super CLASH
- Sources: D-24 · touches the smash licence -> spec first · Owner: game-designer + gameplay-programmer · Deps: WK-20a/b
- Accept: 10/10 scripted head-on super pairs CLASH with damage_level unchanged; lethality criteria 6 a-d still pass.

### [ ] WK-76 [P3][M] Bot personalities (per-bot skill, hero playstyle bias, hero names)
- Sources: D-26 · Owner: gameplay-programmer · Deps: WK-07
- Accept: L4 beats L2 >= 70 % over 10 all-bot matches; bot tag shows hero name.

### [ ] WK-77 [P3][M] Expression overlays (DIZZY/PANIC/SMUG) x6 + pending super-aim pose x6
- Sources: D-27, STATUS "super-aim pose x6" · art generation · Owner: art pipeline + art-director · Deps: none
- Accept (rendered): frame grabs show DIZZY during hitstun on all 6 skins.

### [ ] WK-78 [P3][M] BRAWL SCHOOL trials circuit (teaches smash-to-ring-out, stomp, finishing)
- Sources: D-25c · new content -> `scope-check` · Owner: level-designer · Deps: WK-15
- Accept: 4 courses complete via injected human-style input; rendered screenshots.

### [ ] WK-79 [P3][S] Audio mix pass (loudness numbers, menu vs hit weight)
- Sources: R-33 · Owner: sound-designer · Deps: WK-45
- **BLOCKED (partial):** the subjective "does it sound good" judgment needs a human ear; do the numeric loudness/headroom part only.
- Accept: per-bus loudness report; no SFX clipping; music ducks under KO stings (eval bus levels).

### [ ] WK-101 [P3][M] Residual stage-load spike (62-72 ms) at STAGE_INTRO
- Area: perf · Owner: gameplay-programmer · Source: performance-analyst docs/audit/2026-11-14_perf_wk91.md rec 4
- Evidence: 180 s recorder on the fixed build: 6 frames over 33 ms, 0 over 100 ms; worst 62-72 ms at STAGE_INTRO (Twin Moons,
  Singularity). In-tree `_load_stage` costs 17-54 ms, plus respawn + HUD work in the same tick.
- Impact: low. The spike hides behind the stage intro card, and the game otherwise holds 120 fps. It would matter on a slower couch PC.
- Do: build the next level off-tree during SCOREBOARD and swap it in at STAGE_INTRO, or spread the load over 2-3 ticks.
- Accept: same 180 s recorder run, screen on: 0 frames over 33 ms at STAGE_INTRO across 15 stages including Singularity.
- Status: open

### [ ] WK-102 [P3][S] Perf hygiene: static `_warn_once`, diagnostics skill frame_time note, golden draw-call count
- Area: tooling · Owner: gameplay-programmer (tooling) · Source: performance-analyst docs/audit/2026-11-14_perf_wk91.md recs 5 + 6
- Evidence: `_warn_once` is per renderer instance, so every stage load prints the missing-tuft / missing-flower `push_warning` with a full
  backtrace (17x in one session). The diagnostics skill §2 says `frame_time` is the last frame's process time; Godot actually reports the
  max over ~1 s including the render/swap wait (it read 511 ms on 35 ms frames). The golden draw-call count is still 28; current arenas
  draw ~75-80.
- Impact: not player-facing. Log noise hides real errors in QA stderr; the wrong `frame_time` reading misled the WK-91 hunt.
- Accept: a 15-stage run prints each missing-decal warning at most once; skill §2 corrected; golden updated to the measured value.
- Status: open

---

## Done (recent)
- WK-01 Start/Esc/P pause, B never pauses, owner gating, no leak on resume — 933a77a (QA 8/8)
- WK-02 4-fighter cap, HUD hides unused cards — 933a77a
- WK-03 InputRouter autoload + QA device hooks — 1191757
- WK-04 one device per human (0 cross-moves) — 1191757
- WK-05/06 Herd Lobby join/pick/ready, routed; old CharacterSelect deleted — fe2a99c
- WK-08 goat colour everywhere — 4e7caf6 · WK-10 P# pips, CPU tags (closes L11) — 4e7caf6
- WK-81 lobby review must-fixes F1-F8 + GO blocked while RULES open (closes L1, L13) — f1a9fdd
- WK-07 RULES panel flip, per-mode rule memory, lobby persistence, CHANGE SETUP in Pause — f1a9fdd (beyond spec: lobby
  persistence across round trips and per-mode rules memory shipped in the same slice)
- WK-22 KO blast art, 4 tintable layers — 5a999db
- WK-09 pause finish · WK-11 end-screen input gate · WK-80 QA nits — 5926f10 (all three re-checked rendered in WK-CD1)
- WK-12 painted backdrop on every brawl arena — 4ba5d88
- WK-CD1 creative-director cold playthrough — done, doc docs/audit/2026-11-14_cd1_playthrough.md (owner's two complaints verified fixed; no regressions)
- WK-23 screen-edge KO blast · WK-24 attacker-colour hits · WK-82 lobby hold-B fix · WK-86 per-stage powerup spawners — 4d5d356
- WK-17 bundled OFL fonts (Lilita One + Fredoka), no dark-on-dark outlines on small text — 5672f04 (follow-ups WK-92)
- WK-21 adaptive score hold + WK-41 one overlay at a time — 43b6abc (budget 4.78 / 6.18 s with the screen on, perf_wk91 audit)
- WK-91 perf "16-30 FPS" closed as environment (display-off Modern Standby), 119.6 fps at 1080p; texture cache fix — da8337b

## Deferred / Cut (this weekend) — every finding not covered by an item above
- **R-07 (default 3 stocks / sudden-death squeeze)** — owner rulings: LIVES default 1, KILLS 10, no timer sudden-death. Mitigated by WK-20a/20b/21/37/56; LIVES stays selectable in RULES (WK-07).
- **R-05 (raise the minimum zoom)** — owner camera rules 2026-07-10. Mitigated by WK-10 (pip), WK-47 (rim), WK-36 (bubbles), WK-57/58 (cull arenas that force tiny zoom).
- **R-30 (soft ceiling / top bound)** — changes bounds/framing under owner camera rules; WK-36 magnifier instead.
- **R-31 (camera punch-in on super hit)** — owner camera rules; the rest of R-31 is WK-51.
- **R-18 (put BRAWL first in the row)** — owner set the ModeSelect order; default focus moves to BRAWL instead (WK-13).
- **R-19 (unlock all circuits in versus)** — owner ruling 2026-07-16 (`FREE_CIRCUITS = 3`, 4+ locked). Reopen only on owner reversal.
- **R-06 (in-combat KO tally / leader crown on cards)** — owner ruling 2026-07-16 (no persistent combat score). Transient credit pop = WK-25; damage/lives = WK-31.
- **D-17 / C-15 (6-8 player HUD + 2 more skins)** — capped at 4 fighters for the whole run (DECISIONS 2026-11-14 ruling b3; WK-02).
  The lobby has shipped, but the cap is a standing ruling, not a lobby dependency: needs 2 new skins (art) + compact HUD +
  ScoreScreen row sizing. Revisit only after the weekend run.
- **D-28 (warm-up pen behind the lobby)** — L, new system. WK-05..07 have shipped; WK-CD1 did not ask for it (lobby rated "the best
  screen in the game"), so it stays deferred.
- **WK-CD1 / WK-82 "a slotless device can still eject everyone"** — accepted risk by director decision 2026-11-14 (Smash convention);
  recorded under WK-82 so nobody re-files it as a bug.
- **WK-20b (Lv0 sting/hitstun gate)** — conditional: moves to Won't do if the WK-20a measurement + game-designer ruling say the
  +25 % knockback did not break grazes/recovery.
- **Lobby review L5 painted ribbon art (E.11)** — optional art generation; cut this weekend. The code-side banner polish is WK-84.
- **Lobby review builder deviations accepted by ui-ux** — READY stamp over the portrait (keep, -6°); interim re-pitched lobby
  sounds until WK-45. Not cuts, recorded so nobody re-opens them.
- **D-31 (new powerups)** — widening; after WK-49/71/72 make the existing 7 read.
- **D-04 (HYBRID scoring as default)** — needs owner reversal; recorded as a candidate only (option ships in WK-64).
- **D-29 (freeze sports widening)** — adopted as policy, no item.
- **R-28 (winner podium with 2nd-4th poses)** — nice-to-have, needs pose art; cut this weekend.
- **R-22 (Video / Language tabs)** — no localisation planned; fullscreen already exists; cut.
- **C-16 note to CD (blurbs promise traits)** — handled by the WK-32 decision.

## Coverage index (source -> item)
C-01 01 · C-02 01 (usage in 05-07) · C-03 05,06 · C-04 05,06,04 · C-05 03,04 · C-06 01,09,11 · C-07 28 · C-08 08 · C-09 10 ·
C-10 19,44 · C-11 29,30 · C-12 15,33 · C-13 14 · C-14 11 · C-15 02 (+Deferred) · C-16 27,32 · C-17 06,07 · C-18 09 · C-19 01 ·
C-20 09,33 · C-21 05,46 · C-22 45 · C-23 29 · C-24 40 · C-25 07 · C-26 39 · C-27 18 · C-28 38 · C-29 07 · C-30 44 · C-31 27 ·
C-32 17 · C-33 67 · C-34 05 · C-35 13 · C-36 68
R-01 01 · R-02 05,06,04 · R-03 02 · R-04 08,47 · R-05 10,47 (+Deferred) · R-06 25,31 (+Deferred) · R-07 20,21,37,56 (+Deferred) ·
R-08 12 · R-09 09 · R-10 17,18 · R-11 34,35 · R-12 16 · R-13 07 · R-14 27,32 · R-15 65,66 · R-16 07 · R-17 10 · R-18 13 (+Deferred) ·
R-19 Deferred · R-20 60,61 · R-21 14 · R-22 34,44 (+Deferred) · R-23 29 · R-24 05,06,52 · R-25 18,52 · R-26 07 · R-27 41,25,59 ·
R-28 42 (+Deferred) · R-29 43 · R-30 36 (+Deferred) · R-31 23,51 (+Deferred) · R-32 19,28,44 · R-33 79
D-01 22,23 · D-02 24,25 · D-03 08 · D-04 15,64 (+Deferred) · D-05 36 · D-06 24 · D-07 26 · D-08 37 · D-09 21,11 · D-10 32 ·
D-11 62,63 · D-12 73 · D-13 15,54 · D-14 55 · D-15 53 · D-16 57,58,59 · D-17 02 (+Deferred) · D-18 20a,20b · D-19 48 · D-20 49,71,72 ·
D-21 74 · D-22 70 · D-23 56 · D-24 75 · D-25 50,54,78 · D-26 76,72 · D-27 77 · D-28 05 (+Deferred) · D-29 13 · D-30 69 · D-31 Deferred
(D-18 is now 20a,20b; D-08 is 37a,37b; D-10 is 32a,32b when pulled)
Lobby review (2026-11-14_lobby_review.md): F1-F8 81 (done) · L1 07/81 (done) · L2 27 · L3 28 · L4 45 (+53 bleat) · L5 84 (+Deferred art) ·
L6 18 · L7 83 · L8 82 · L9 83 · L10 17 · L11 10 (done) · L12 29 · L13 81 (done)
WK-CD1 (2026-11-14_cd1_playthrough.md): CD1-01 86 · CD1-02 20a (scope expansion), 20c, 25 · CD1-03 87 (+35) · CD1-04 88 (+42, 76) ·
CD1-05 17 (+18) · CD1-06 89 (repro inside 20a) · re-judged: 82 (accepted risk), 21 + 41 (budget, 41 raised to P1), 37, 31, 85, 43, 23, 42 (R-26 label)
Owner check-in (owner_2026-11-14_checkin.md): ask 1 93 · ask 2 94 · ask 3 95 (a-d; spec §6.4 -> 99) · ask 4 + pendulum-motion follow-up 96 ·
ask 5 97 · ask 6 98 (+ raised 27, 16; 65/66/35 re-judged by 98) · "record lessons" -> docs/WEEKEND_LESSONS.md (no item)
Perf audit (2026-11-14_perf_wk91.md): rec 1(a)(b) 100 · rec 1(c) owner machine setup, BLOCKED (owner), no item · rec 2 90 (re-measure note) ·
rec 3 retired WK-21 option A (notes on 21, 91) · rec 4 101 · recs 5 + 6 102 · rec 7 no renderer change (no item)
