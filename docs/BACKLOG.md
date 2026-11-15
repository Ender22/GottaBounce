# BACKLOG — weekend polish run (owner: producer)

Ranked top-to-bottom. Seeded 2026-11-14 from the three audits in `docs/audit/2026-11-14_*` (C-xx controls/front-end,
R-xx rendered playthrough, D-xx game design) and the owner's verdict: *"kinda fun but... a shitty prototype with a lot
of weird things, nonsense controls (like b opens the pause menu on an xbox controller...) and the character select
totally doesnt make sense, 2 users using 2 controllers totally cant select their character like a normal game"*.
Standard: `docs/COUCH_CONVENTIONS.md` (CC-x.y). Procedure: `docs/WEEKEND_LOOP.md`. Rulings: `docs/DECISIONS.md` 2026-11-14.

## How to use (every loop tick)
1. Take the **first unchecked item** in the Next 10 (or 2-3 small related S items). Skip `BLOCKED`. Respect `Deps`.
   Parallel agents (WK-130 ports): each agent takes the first open item in a **lane** nobody else holds. Same-lane items run in order.
2. Build -> verify RENDERED per its `Accept` line (keyboard AND simulated pads on >= 2 device ids) -> screenshots
   to `tools/out/wk/<ID>_*.png`, LOOKED at. UI items also need a ui-ux-designer Ship verdict vs COUCH_CONVENTIONS.
3. Mark the heading: `[x] ... — <commit hash>` on a pass; `[~] attempted — <one-line reason>` after 2 failed fix
   rounds (revert the item's files, move on). Never mark `[x]` on a builder's word: the Accept check must pass.
4. Items tagged **OWNER-RULED** touch an owner feel/rule decision (DECISIONS ruling (c)): the owner's value stays;
   only what *feeds* it may change, and the change gets a DECISIONS entry in the same commit.
5. Size L never gets pulled: it is already split below. If an item turns out bigger than its size, split it here
   first. Producer re-ranks after every creative-director cold playthrough (~every 6 items).

Legend: `[ ]` open · `[~]` attempted · `[x]` done · `[>]` merged into another item · Size S = one pass, 1-2 files · M = one full slice · L = split it.

## In flight (do NOT reassign)
- **Lane P, in progress:** WK-135 bumper build (gameplay-programmer, 3 phases per `docs/specs/wk135_bumper_min_bounce_2026-11-15.md`, in a
  SCRATCH COPY that applies to the repo at the end; port 9105). Phase 3 turns the WK-128 (b) refund gates ON and adds the sports
  ball-touch refund (WK-135c). It also closes WK-133 and WK-134 (merged, see their entries).
- **Lane V, ready:** WK-66b art brief landed (d0a2da7: no new art, reuse the WK-66a goal cage in objective gold). The build can start now.
- **Environment (2026-11-15): both GPUs are in an error state, so the game renders in SOFTWARE (~37-52 fps) until the owner reboots.**
  Visuals, screenshots, WK-93 recordings and game-time counters (`phase_log.tick_s`, `round_stats`) are valid. Wall-clock perf, frame
  time and feel-timing numbers are NOT. Items that need them are marked **BLOCKED (GPU)**: WK-90, WK-101 (and WK-109 behind WK-90).
  A/B arms must all run in the same session, so the environment is identical across arms. Do not compare a new arm to CD3's
  absolute numbers.
- **Shared-file map (who owns a hot file until their item commits):**
  - Held by **WK-135 (lane P) until it commits:** `Player.gd`, `InputBot.gd`, `BounceResolver.gd`, `SportsMode.gd` (S1/S3 ball-touch
    refund), `PartyMatch.gd` (§8 per-stage telemetry), plus its own `Tuning.gd` block. Anything else that touches these files either says
    "after WK-135" or builds in a scratch copy and lands with staged hunks (`python tools/stage_hunks.py`).
  - After WK-135: `Player.gd` -> lane P (WK-136, then WK-20e if the ruled lever is the missed-super floor). `InputBot.gd` and
    `SportsMode.gd` -> lane S (WK-131, then WK-108b; later WK-127b, WK-110, WK-112, WK-113). `PartyMatch.gd` -> free (WK-53c later).
  - `ModeSelect.gd`, `MatchHUD.gd`, the Victory screen: lane U (WK-13, then WK-42). WK-99 and WK-31 (`PlayerCard.gd`, `MatchHUD.gd`) wait
    for lane U to release `MatchHUD.gd`.
  - `GoalZone.gd`, `SportsNetArt.gd`, `ArenaRenderer.gd`, `levels/courses/*.json`: lane V (WK-66b, then WK-85a).
  - `Ball.gd`: lane S's measurement chain (WK-109). WK-135 reads it but does not edit it (spec §6 E10).
  - `HerdLobby.gd`, `LobbySlot.gd`, `GameConfig.gd`: lane L (WK-120 + WK-125, then WK-52's toast half).
  - Brawl level JSON (`levels/<arena>.json`, `levels/circuits.json`): lane D (WK-20d measures in a scratch copy; WK-20e edits the JSON
    only if the ruled lever is the blast margin).
  - `Ghost*.gd`, `ghost*.gdshader`: lane G (WK-37f, on deck).
  - `Tuning.gd` and `EventBus.gd`: every lane appends to them. Put your constants or signals in their own block, and commit only your
    hunks (`python tools/stage_hunks.py`, lesson dbc09c9).
- **Concurrency cap (WEEKEND_LOOP):** at most **3 agents running Godot at once**, and at most **1 headless batch with at most 2
  processes**. Code-only, design-only and art-generation work doesn't count. WK-135's 40-stage Singularity batch has the headless slot
  first. WK-108b's 32-run batch and any WK-20d batch queue behind it.
- **Ports (WK-130):** one rendered game per agent, each on its own port (9101+). Never use no-arg `stop_game.ps1` or `run_game.ps1 -KillAll`
  while other lanes are running.
- **Measurement validity:** count game time only (`phase_log.tick_s` / `round_stats`), never wall clock across a screenshot burst (one
  1080p `gbplay screenshot` stalls the game ~1.25 s, CD2-05). Judge motion from WK-93 recordings. Perf and timing numbers additionally
  need the display awake and a SOLO window (no other rendered game) on a working GPU; right now none of those numbers can be taken (see
  Environment).

## Next 10 (producer re-rank 2026-11-15 #7: after WK-CD3; Brawl pacing first, sports right behind)
**Done since re-rank #6** (all headings ticked, all in "Done (recent)"):
- WK-CD3 (ee892a5)
- WK-37c (ee46c22), WK-37d (b76d36f), WK-37e (6c0d612): ghost slice finished. CD3's T15 felt pass found no FIX trigger.
- WK-128 bill-only (3e1a5b0). CD3 G1-G5 verdict: SHIP, with one S fix (now WK-136).
- WK-66a nets (2bd049c)
- WK-53b living taunt + WK-26 super-aim wind-up (4ca9472)
- WK-34 (8051d4f), WK-35 (9498e0f), WK-122 (e3e11d5), WK-132 (7764470)

**Closed or merged this pass:** WK-126 Won't do (CD3 §6: the loops read as a close dogfight at follow zoom; aim report clean).
WK-133 and WK-134 merged into WK-135 (its spec §7.6 closes both, with acceptance folded into §9 A/B).

**Filed this pass:** WK-20d (CD3-01 measurement ladder), WK-20e (apply WK-20d's lever; conditional), WK-136 (CD3-04a near-empty
re-light), WK-37f (CD3-08 ghost behind terrain), WK-85a (CD3-06 split out of WK-85). Merged: CD3-02 + CD3-05 into WK-131,
CD3-03 into WK-108b, CD3-04b into WK-99, CD3-07 into WK-52, CD3-09 into WK-117 + WK-65.

**Ranking logic:**
- No P0 is open.
- **Brawl pacing ranks #1, even though the owner leans sports.** CD3 rates sports "SHIP-adjacent and the showcase": two Rocketball
  matches (6-2, 6-5) and a Dropshot (6-4) were again the best minutes, the end card landed, and the restart is 2.67 s. Brawl is the
  default mode, it is the first card a naive group picks, and WEEKEND_LOOP says to make the core brawl genuinely good before anything
  else. CD3 names its pacing the single biggest remaining problem: 8.4 s median stages, the first death at 2.8 s, 33-49 % of human
  deaths with no hit at all, and ~38 % of a Brawl spent in interstitials. WK-20d's measurement phase edits no repo files, so it starts now
  despite WK-135 holding `Player.gd`.
- **Sports gets #2, #4, #8 and #10.** WK-131 is a GO (16-26 % kickoff goals, every one by a human seat) and is S. It is the last thing CD2 and CD3
  both name between sports and SHIP. WK-108b carries CD3-03 (a CPU teammate's own goal decided a match). Weighting sports for the
  owner means these two finish before any new sports content (WK-110, WK-115 stay on deck). WK-120 (#10) fixes the 2-human lobby falling
  back to 1V1 with no CPUs.
- **WK-136 is #3.** It is S, it fixes a regression our own WK-128 introduced in a core verb (10 of 130 presses were a 25 ms dead button,
  and 4 of those preceded the presser's death), and it feeds the same self-KO number WK-20d chases. Raised from CD3's P2 to P1:
  "missing feedback on a core action". It rides lane P straight after WK-135, which owns the same fuel ledger.
- Cheap couch-visible fixes CD3 re-confirmed (WK-13, WK-42) fill the third Godot slot while lane S waits for WK-135 to commit.
- Sports count: 4 of the 10 (WK-131, WK-108b, WK-109, WK-120), plus WK-66b, which uses the sports goal kit in Trials.
- WK-66b is P1 (Trials goals still draw the debug-looking code grid) and its brief just landed with no new art, so it is ready.
- **WK-109 (#8) is un-blocked by a split.** Its cap/floor A/B is measured in game time (touch-speed histograms), which is valid under
  software rendering, and `Ball.gd` is free. Only its hit-stop garnish needs WK-90. Sports runs as one measurement chain: WK-131, then
  WK-109 or WK-108b, so no two sports A/Bs confound each other.
- **Blocked:** WK-90 and WK-101 need valid timing numbers (GPU, see Environment).
- Rank is priority order. **Lane** is concurrency: items in different lanes edit disjoint files. Same-lane items run in order. With
  WK-135 holding one Godot slot, two more Godot agents can run: lane D takes the second slot, lane S the third, and lane U, V or L
  borrow the third slot whenever lane S is code-only or waiting.

| # | Item | Size | Lane | Owner | Files it edits | Can start |
|---|------|------|------|-------|----------------|-----------|
| 1 | WK-20d Brawl pacing ladder on MEADOW MILE with human-style seats: median stage >= 12 s, human self-KO <= 25 %, super-kill share kept (CD3-01) | P1/M | D | game-designer (+ qa-playtester driving HumanSim) | none in the repo (scratch copy + eval overrides; CD3 drivers from `tools/out/cd3/*.gd.txt`); writes `docs/audit/` results + DECISIONS ruling | **now** |
| 2 | WK-131 Rocketball kickoff rule: <= 10 % of goals within 4 s of GO with human-style seats (GO from CD3-02; re-measure rallies per CD3-05) | P1/S | S | game-designer -> gameplay-programmer | `SportsMode.gd`, own `Tuning.gd` block | A/B design **now** in a scratch copy; commit **after WK-135** (`SportsMode.gd`) or staged hunks |
| 3 | WK-136 A near-empty re-light always delivers >= ~0.1 s of thrust (CD3-04a) | P1/S | P | gameplay-programmer (+ game-designer for invariant #14) | `Tuning.gd` (`boost_relight_min_left`) and/or `Player.gd` | **after WK-135** (same lane, same fuel ledger) |
| 4 | WK-108b Sports bots round 2 + CD3-03: no CPU own goal decides a match; keeper stickiness; fast-ball re-plan; goal-mouth crowding | P1/M | S | gameplay-programmer | `InputBot.gd`, `SportsMode.gd`, own `Tuning.gd` block | **after WK-131** in lane S (and after WK-135 for `InputBot.gd`) |
| 5 | WK-13 Mode select: BRAWL default focus, equal card heights, player-count chips | P1/S | U | ui-ux-designer | `ModeSelect.gd` (+ its `.tscn`, `MenuCard.gd` if the heights need it) | **now** |
| 6 | WK-66b TRIALS ball goals use the Rocketball cage in objective gold (brief d0a2da7) | P1/M | V | gameplay-programmer + level-designer, art-director grade | `GoalZone.gd`, `SportsNetArt.gd`, `levels/courses/{s3_*,t_ball_cannon,t_bank_shot}.json` | **now** |
| 7 | WK-20e Apply WK-20d's winning lever (conditional on its ruling) | P1/S-M | D or P | level-designer (JSON) or gameplay-programmer (`Player.gd`) | by lever: blast margin -> `levels/{islands_void,twin_chasms,hill_and_dale}.json` (lane D); missed-super floor -> `Player.gd` + `Tuning.gd` (lane P, after WK-136) | after the WK-20d ruling |
| 8 | WK-109 Power shot dynamic range: split the ball cap, trim the touch floor (cap/floor/trail/pop half; the hit-stop garnish waits for WK-90) | P1/S, sports | S (measurement chain) | game-designer (A/B) -> gameplay-programmer | `Ball.gd` (+ a `Tuning.gd`/mode block); NOT `Juice.gd` | after WK-131's A/B. Runs before WK-108b if WK-135 still holds `InputBot.gd`; never measures at the same time as WK-108b |
| 9 | WK-42 Victory screen: hide the combat HUD cards, consistent button copy and size, readable CPU name (CD3 re-confirmed) | P2/S | U | ui-ux-designer | `MatchHUD.gd` (visibility), Victory screen script/scene | after WK-13 |
| 10 | WK-120 + WK-125 Sports FORMAT 2V2 default with 2+ humans + lobby auto-joins the confirming device (one lobby pass) | P2/S+S, sports | L | ui-ux-designer (+ gameplay-programmer) | `HerdLobby.gd`, `LobbySlot.gd`, `GameConfig.gd` | **now** (if a Godot slot is free) |

**Concurrency plan (cap: 3 Godot agents, 1 headless batch of <= 2 processes):**
- **Slot 1:** lane P: WK-135 (running), then WK-136, then WK-20e if the lever is the fuel floor.
- **Slot 2:** lane D: WK-20d's rendered HumanSim arms. Run all arms plus a fresh baseline in one session (software rendering, so all arms
  must share the same environment).
- **Slot 3, rotating:** lane S's WK-131 A/B while it needs a rendered game. While lane S is code-only or waiting for WK-135 to commit,
  hand the slot to lane U (WK-13, then WK-42), lane V (WK-66b, then WK-85a) or lane L (WK-120 + WK-125), in that order. WK-109's A/B
  (lane S chain, `Ball.gd`) uses lane S's slot.
- **Headless:** WK-135's Singularity batch first, then WK-108b's 32-run batch. Never two batches at once.
- **Art generation** (none is needed for the Next 10; WK-65 is on deck) runs outside the cap.
- **Next cold playthrough:** WK-CD4 after ~6 more deliverables, or right after WK-20e lands, whichever comes first. It must re-judge
  Brawl pacing with the same 3-device HumanSim route on MEADOW MILE, the WK-131 kickoff number, the nets (CD3's snapshot predates
  WK-66a, so WK-66c's contingency is still unjudged) and WK-136's re-light feel.

**On deck (11+, in order; lane in brackets):**
1. WK-85a Trials void reads as a lethal drop: lesson 1 fill band + lesson 4 floating props (CD3-06) (P2/S) [V, after WK-66b:
   `ArenaRenderer.gd`, `levels/courses/tut_01_first_flight.json`, `tut_04_fuel_run.json`]
2. WK-99 fuel super-ready notch + CD3-04b billed-chunk flash (M) [H: `PlayerCard.gd`, `SportsHUD.gd`; after WK-42 releases `MatchHUD.gd`
   and after WK-135 + WK-136 settle the fuel economy]
3. WK-110 MATCH POINT / GOLDEN GOAL + GOALS stepper (M) [S, after WK-108b]
4. WK-31 HUD danger state + stocks (M) [H, with or after WK-99]
5. WK-127b the_ascent top-tier hopping + CD3's hover watch (S) [S, `InputBot.gd`, after WK-108b]
6. WK-116 rally tail (S, measurement only: LONG HAUL sample alongside WK-131's post-rule measurement; the Dropshot watch is cleared)
7. WK-117 sports words + CD3-09 copy ("FIRST TO 6 POINTS" on Dropshot, no "A FIGHT!") (S) [U after WK-42; the kickoff word may need
   `SportsMode.gd`: stage hunks]
8. WK-52 unlock toast becomes a banner card + CD3-07 (S) [L, after WK-120 + WK-125]
9. ~~WK-14~~ done ab11c61 — singular focus (S) [U]
10. WK-37f ghosts never hide behind terrain (P3/S) [G]
11. WK-113 sports legend off the floor (S)
12. WK-112 sports hazards stun (S) [S]
13. WK-114 court unlock gates (S, JSON, with or after WK-112)
14. WK-54 per-player legend (S)
15. WK-123b HOME parking in code (S; unverified outside Flight School; needs a 2P co-op QA check on a shared-column course first)
16. WK-129 super-only crates (S)
17. WK-103 pendulum follow-ups (S)
18. WK-28 controller disconnect (M)
19. WK-19 rumble per pad (S)
20. WK-32a hero decision (S)
21. WK-29 glyph component (M)
22. WK-65 court cards + Dropshot mode card + CD3-09 thumbnails (M, art generation)
23. WK-85 tall-arena tiling (the remainder after WK-85a)
24. WK-57 arena scorecard tool (M; would feed a WK-20d follow-up across all 94 arenas)
25. BLOCKED (GPU): WK-90 hit-stop re-measure (then WK-109's hit-stop garnish); WK-101 stage-load spike

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
- Status: done 9a2ee3f (recording-verified). Used as motion evidence by WK-94/95/96/98.

### [x] WK-94 [P0][S] Bot super-aim spins like crazy — must sweep like a human — 9a2ee3f
- Area: brawl (bots) · Owner: gameplay-programmer · Source: owner_2026-11-14_checkin.md (ask 2)
- Owner: "the aiming mechanic looks crazy when the bots use it, it spins like nuts". Lead: game-designer found L1
  "panic" aim noise is re-rolled EVERY frame (docs/specs/wk20a_measurement_2026-11-14.md §2.2 point 3).
- Do: bot aim = smoothed target angle with max angular speed (Tuning), noise as slow drift not per-frame jitter;
  verify with WK-93 recording (aim angle per frame plot: no flips > N deg/frame).
- Accept: recording of 3 bot supers per difficulty shows smooth, readable wind-up; max angular step under cap.
- Status: done 9a2ee3f. WK-98 confirmed it in sports: 5 recordings, aim capped at 2.63°/tick, 0 jumps over 15° (§6.7).

### [x] WK-123 [P1][M] Flight School must teach the super; co-op HOME goats stop blocking partners; Refuel Ridge gap — 7fe4ce4
- Area: trials · Owner: level-designer (JSON) + game-designer (lesson intent) + gameplay-programmer (HOME parking, if it needs code)
- Source: creative-director WK-CD2 (CD2-01 P1/S-M, CD2-02 P2/S) + WK-95f (d) · owner WK-95 ruling follow-through ("super = the attack")
- Evidence (CD2-01): a FLY-only point-and-go pilot clears `tut_02_super_shot` in 1.72 s with 31 % fuel left (`tools/out/cd2/47_t2_flyonly.png`,
  "1 of 2 HOME"); `tut_03_sky_ladder` clears on FLY alone from a bounce apex in 3.3 s (from a standing start it falls ~600 px short). The
  `tut_03` design_intent premise (cap 760, tank dies 1000 px short) is stale since WK-95 (cap 800, bounce speed kept along the thrust).
- Evidence (CD2-02): co-op `tut_02`/`tut_03`: twice in three lessons a HOME P1 falling back down the shared column reversed P2's super from
  −2,339 / −3,000 px/s to +518 / +696 px/s within 0.3 s; with P1 moved aside the same input cleared lesson 3 in 1.2 s. Both players spawn at
  the same x (WK-43 covers spawn offsets only).
- Impact: the game's only super tutorial ends with the player never having fired one, so newcomers learn the super is optional (CD2 §2 Q2);
  in co-op a perfect super dies on the partner. Every new player, first minutes of Trials.
- Do: (a) each of `tut_02`-`tut_04` fails when you use only the verb it is not teaching. Preferred: teach the super as a HIT (smash a crate /
  DestructibleBlock / target off a ledge), or a ring past a gap only the 0.45 s / 1,260 px burst crosses; else lift `tut_03`'s ring above the
  post-WK-95 flight ceiling INCLUDING a bounce start. Refresh the design_intent text. (b) Once HOME, a goat parks in or behind the ring: frozen,
  non-colliding, celebrating (also shows who is done); fallback: no player-vs-player contact in Trials. (c) WK-95f (d): +80 px merged gap on
  `n2_refuel_ridge` per the WK-95 spec.
- Re-sized (producer): three S pieces in one Trials pass = M. If (a) needs a new target entity, or (b) needs Player/TrialsMode code, split (b)
  out as WK-123b [S] for the gameplay-programmer rather than stall (a)'s JSON.
- Accept (rendered): the FLY-only pilot FAILS `tut_02`, `tut_03` (from a bounce apex AND from standing) and `tut_04`; the same lessons clear
  with a human-style driver that uses X; 2P co-op lesson 3 recording: P1 HOME is parked and P2's super reaches the ring; Refuel Ridge
  recording shows the skip-one-pad gap demands a refuel; lesson screenshots under `tools/out/wk/WK-123_*.png`, LOOKED at.
- Status: done 7fe4ce4 (JSON only). Fly-only falls 629-1617 px short on `tut_02`/`tut_03`, and fly-up-then-super clears. A 4-lane layout
  fixes co-op blocking (CD2-02) in Flight School. Lesson 4 and the Refuel Ridge gaps were widened.
  Follow-ups:
  - WK-123b: code-side HOME parking for the other co-op courses.
  - WK-128: the scripted pilot found a fuel-tapping leak and an infinite wall refuel.
  - WK-129: super-only crates, so a dive can't fake the super beat.

  WK-CD3 re-judges it with a newcomer driver.

### [>] WK-95f [P2][S] WK-95 leftovers: ORBIT/cannon/s3 Trials sweep under the new flight — merged into WK-128 §9 Trials sweep (re-rank #6)
- From WK-95e (a362ad4): Trials ORBIT set (g6), cannon courses and s3 soccer trials unchecked under the new flight. Sports bot stuck
  ~29/min (pre 23) moved into WK-108. (d) Refuel Ridge gap moved into WK-123 (2026-11-14 re-rank #5). (e) feel sign-off: DONE by WK-CD2,
  verdict SHIP for flight (`docs/audit/2026-11-14_cd2_playthrough.md` §2).
- CD2 add: the sweep's Accept also checks "flight-only fails" wherever a course is meant to teach or require the super (Flight School
  itself is WK-123).
- Accept: recordings of the at-risk Trials courses completed by a boost-only driver (0 newly impossible), and any super-gated course still
  fails without X.
- Status: merged into WK-128 (re-rank #6, dedupe). The WK-128 spec's at-risk table (§9) already lists g6 ORBIT (8 courses), the p4 cannon
  set + `t_ball_cannon` and `s3_*`, and it reruns them after the fuel change. WK-128's Accept now carries this item's check too: "any
  super-gated course still fails without X". Close this with WK-128's recordings. If WK-128 is marked `[~]`, reopen this as its own S.

### [x] WK-95e [P1][M] WK-95 follow-ups: bot stuck/underside regressions, HOT ruling, creative-director feel sign-off — a362ad4
- Source: WK-95 build report (commit 4135884). Owner: gameplay-programmer (bots) + game-designer (ruling) + creative-director.
- Status: done a362ad4 (HOT rule ON per director ruling; traversal supers 9.8 %). Feel sign-off (e): WK-CD2 SHIP for flight. The residual
  sports stuck/min (~29 vs 23) moved into WK-108.
- (a) Bot motion regressions vs before: stuck episodes/stage 1.87 -> 2.59 (+38%), underside bounces 3.37 -> 3.83; sports
  stuck/min 23 -> 33. Fix in the bot brain, verify with a 160-stage batch + recordings (target <= 1.1x before).
- (b) game-designer ruling on `InputBot.wk95_hot_stopdist` (HOT recovery requires a full brake can't stop before the
  blast line): gets traversal supers 13.0% -> 9.4% (meets <=10%) but underside bounces 6.03/stage. Ship only with (a).
- (c) Recovery share of bot supers 32.9% (target <=20%); L2 boost/air time 30.5% (target >=35%).
- (d) Refuel Ridge skip-one-pad line (+80 px merged gap per spec) — level-designer; ORBIT set + cannon + s3 trials unchecked.
- (e) Creative-director feel check (spec's 6 questions) on the integrated build — fold into WK-CD2.
- Accept: (a) batch numbers within 1.1x; (b) ruling logged in DECISIONS; (d) Trials sweep recording evidence.

### [x] WK-95 [P0][M x4] OWNER RULING: normal flight responsive enough to manoeuvre; super boost = attack, not traversal — 4135884
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
- Status: done 4135884 (M1-M9 pass; bot traversal supers 27.6 -> 13 %). Follow-ups in WK-95e. WK-CD2 verdict: SHIP for flight, humans
  and bots (point-and-hold crossed 1,640 px in 2.0 s; bots 37-63 % alive time on normal boost, ~90 % of supers are attacks). Tutorial
  hole -> WK-123.

### [x] WK-96 [P0][M] Pendulums: pass through players without smashing them AND motion looks stiff/poor quality — 9a2ee3f
- Area: brawl (hazards) · Owner: gameplay-programmer (+ art-director on the look) · Source: owner_2026-11-14_checkin.md (ask 4 + follow-up)
- Owner: "big swinging pendulums ... went right through a player and didnt smash them". Find the pendulum hazard
  (grep pendulum in src/ + levels), check collision layers/masks, tunnelling at speed (continuous CD / shape cast),
  and hit-gating (cooldown/invuln). Owner follow-up: "not very cool looking motion, they look very stiff and like poor
  quality" -> real pendulum swing (slow at apex, fast at bottom), visible anchor/arm, heft, whoosh/trail.
- Accept: WK-93 recording of 5 pendulum contacts -> 5 smashes; contact sheet of one swing bunches at apexes.
- Status: done 9a2ee3f (recording-verified). Follow-ups in WK-103.

### [x] WK-97 [P0][S] Black hole level: player sprites render behind the black hole — 9a2ee3f
- Area: brawl (render order) · Owner: gameplay-programmer · Source: owner_2026-11-14_checkin.md (ask 5)
- Owner: "on like a black hole level, all the player sprites were behind the black hole". Fix z_index/z_as_relative or
  CanvasLayer ordering of the black_hole sprite (GravitySource) so players/FX draw in front.
- Accept: screenshot on Singularity with players passing over the black hole.
- Status: done 9a2ee3f.

### [x] WK-98 [P1][M] Sports deep-dive: owner reports Rocketball/Dropshot may be more fun than Brawl — 32c5eb7
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
- Status: done 32c5eb7. Doc `docs/audit/2026-11-14_sports_deepdive.md` (verdict FIX, not RETHINK; SP-01..22, evidence under
  `tools/out/sports/` and `tools/out/rec/wk98_*`). Triaged by producer 2026-11-14 #4: every SP finding is a WK entry or merged; see the
  SPORTS section below and the Coverage index.

### [ ] WK-99 [P2][M] Fuel gauge shows a super-ready notch (threshold now 10 %) — brawl cards AND a sports fuel readout
- Area: HUD | sports · Owner: ui-ux-designer (+ gameplay-programmer for the sports widget) · Source: game-designer WK-95 spec §6.4 +
  WK-98 SP-14 (merged) · Deps: WK-95 (done, threshold 10)
- Impact: with `super_boost_min_fuel` 10 (was 5), "can I super?" stops being trivially yes; the PlayerCard gauge and the off-screen
  bubble fuel ring (WK-36) don't show the line. Couch players learn the attack's cost from the HUD instead of a dud press.
- SP-14 (sports): there is no fuel readout at all in sports (`SportsHUD.setup` is `pass`, no PlayerCards). LONG HAUL median fuel was
  16-20 % (M3, `tools/out/sports/m3_rb1v1cpu_longhaul/`), so players run dry with no warning. Add a small team-coloured fuel arc under
  each goat in sports (player-attached) with the same notch, or slim bottom-corner chips. Re-sized S -> M: the sports widget is new.
  Re-judge urgency against WK-98 §6.5 (post-WK-95 fuel numbers) before building the sports half; the brawl half can ship alone.
- Accept (rendered): eval fuel 9 / 11 on P1 -> the notch reads below/above in a PlayerCard crop and a WK-36 bubble crop; a Rocketball
  frame shows every goat's fuel with the notch unlit below the threshold; ui-ux Ship.
- Merged CD3-04b (re-rank #7): when a re-light is billed (WK-128), flash the billed chunk on the fuel gauge, so "tapping costs fuel" is
  taught by the HUD (WK-CD3 §5 G5: nothing on screen says it today). **Accept addition:** a burst of a billed re-light shows the chunk
  flash on the PlayerCard gauge.
- Status: open (on deck #2 after re-rank #7). After WK-135 + WK-136 settle the fuel economy, and after lane U's WK-42 releases `MatchHUD.gd`.

### [x] WK-100 [P2][S] Tooling: display-off pre-flight in run_game.ps1, perf_gate.py and record_match.ps1 — 843c6c2
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
- Status: done 843c6c2 (warning in run/record/perf tools). WK-CD2 ran with `gbplay perf` reporting display on, valid, 120-121 fps.


## SPORTS — WK-98 deep-dive (docs/audit/2026-11-14_sports_deepdive.md) — owner ask 6: "maybe more fun than the brawl", items jump their band

> **PROTECT (WK-98 §2, do not regress):** fixed whole-court framing · 99 lives + instant respawn · stage-per-point reset · goal mouths
> above the floor (flight required) · CCD on the ball · true-entry goal detection (centre-in-rect) · the Dropshot serve rule (frozen
> above the net, served at the last scorer, alternating by stage parity on the opener) · crack-then-break tiles with "bounce on the
> breaking hit" · beach ball float (gravity 0.35, restitution 0.93, cap 1900) · the touch floor (a nudge always moves the ball) · bot
> supporter/cover logic (`SUPPORT_HOLD_FRAC`) · WK-27 colourway teams (cross-team hues ≥ 90° apart) · the 2.8 s goal-to-kickoff restart
> (**WK-CD2: currently 3.27 s game time, soft regression -> WK-124**).
> Every sports item's Accept implicitly includes "PROTECT list unchanged".
> **POST-WK-95 RE-CHECKS (WK-98 §6):** WK-98 judged the uncommitted WK-95 tree. Each consumer re-measures its own number on the current
> build first, with the WK-98 harness (`tools/out/sports/logs/human.py` + `monitor.gd`, M2 BOX 2v2 + M4 BEACH 2v2): kickoff goals < 4 s
> (31 %) -> WK-104 · near-cap touch share (24-33 %) and power-shot share (1.5 %) -> WK-109 · attacker-last-touch share (48 %) and super /
> smash rate -> WK-108 · fuel (LONG HAUL 16-20 %) -> WK-99 · Dropshot rally length (10.7 / 14.5 s) and bot aim (2.63°/tick) -> WK-CD2 (7).
> Screen on for every timing number.

### [x] WK-104 [P1][M] Sports: ball frozen until GO (SP-02 bug) + kickoff lottery fix (SP-05) — 5f34080
- Area: sports · Owner: gameplay-programmer (+ game-designer ruling for (b)) · Source: WK-98 SP-02 + SP-05 (creative-director 2026-11-14)
- Evidence: (a) 4 of ~56 kickoffs logged a touch in STAGE_INTRO/COUNTDOWN; M6 stage 9: a stale-overlap touch drifted the ball to BLUE's
  spawn and BLUE scored an own goal 0.3 s after GO (`tools/out/sports/logs/m6.json` t 64.49 -> 66.64; M1 `logs/m1b.json` t 166.7/167.8).
  Cause: only Dropshot freezes its ball pre-serve; `Ball._physics_process` reads last step's `get_overlapping_bodies()` in every state.
  (b) 19/62 human-seat Rocketball goals (31 %) within 4 s of GO, 5/10 on BOX and BOWL; `tools/out/sports/evidence/sp_kickoff_goal_1p3s_sheet.png`
  (goal 1.3 s after GO); elevated 2v2 spawns are always nearer the ball, and CPUs usually hold them (`m2_rb2v2_box/play_143.png`).
- Impact: every Rocketball kickoff. Free goals feel unfair, and short rallies cut the mode's best loop. Fairness is the #2 WK-98 issue.
- Do: (a) freeze the soccer ball through STAGE_INTRO/COUNTDOWN, unfreeze in `on_combat_start` (mirror Dropshot), gate `Ball._drive_from`
  on a mode-set `live` flag, skip touches on the first physics frame after spawn. (b) re-measure kickoff goals on the current build
  first (§6.1: WK-95 made touches stronger), then A/B the CD's options; recommended "ref drop" (ball held at ~25 % court height, small
  random toss on GO) + keeper/midfield formation (spawns equidistant to the ball). Keep the 2.8 s restart. game-designer rules, DECISIONS entry.
- Accept: (a) 30 rendered bot kickoffs: 0 touches outside COMBAT, ball at GO = spawn ±1 px. (b) 40 rendered kickoffs (bots L3 + one
  human-style driver): goals within 4 s of GO ≤ 10 %; median CENTER PITCH rally 8-20 s; WK-93 recording of 3 kickoffs looked at.
- Commit (a) as soon as it passes. Do not hold the bug fix for the (b) ruling.
- Status: done 5f34080 for (a) (frozen until GO, verified again by WK-CD2) and the fair kickoff toss. (b)'s Accept is NOT met: the commit
  reported 22-26 % kickoff goals and blamed bot pathing; WK-CD2 (CD2-03) measured **3 of 10 goals within 3 s of GO, all by human-style
  seats** (`tools/out/cd2/rb/phase.json`, `rb/r016`-`r020`), so bot routing alone will not fix it. The (b) Accept moves into WK-108 (b2).

### [x] WK-105 [P1][M] Sports: ball strike, goal, tile and hole-fall sounds + hit reaction (SP-01) — 5f34080
- Area: sports | audio · Owner: sound-designer + gameplay-programmer · Source: WK-98 SP-01
- Evidence: 0 SFX on 88 ball touches in M3; no SFX within 0.6 s of any goal or point in any match; `AudioManager.SFX` has no ball, goal,
  crowd, whistle or tile keys; `Ball.gd` has no FX; Dropshot hole falls play the brawl `death` sting (8x in M4).
  `tools/out/sports/evidence/sp_goal_moment_center.jpg` (a goal = a silent tint plus text).
- Impact: every touch and every goal in the mode the owner flagged as most fun. The biggest felt gap in WK-98.
- Do: `EventBus.ball_struck(player, speed, is_power)` + `goal_scored(team, scorer, own)` (WK-106 consumes `goal_scored`). Build order,
  each step playable: (1) strike "thwock" pitched by after-speed + 2-3 frame squash + team-colour impact ring; (2) goal horn + crowd +
  net burst + trauma 0.4; (3) Dropshot crack / break crunch, point whistle + crowd; (4) sports hole fall = cartoon "whoop", no `death`,
  no KO blast; (5) rate-limited wall "tonk". CC0 sources, mix under the music. Power-shot hit-stop goes through `Juice._hitstop`: do not
  hand-roll a second timer (WK-90 owns the timer bug).
- Accept: rendered Rocketball + Dropshot match: a sports SFX within 1 frame of ≥ 95 % of touches; horn + crowd within 0.1 s of every
  goal/point; `death` never fires in a sports mode; a WK-93 recording frame shows squash + impact ring on a strike.
- Status: done 5f34080 (hole-fall puff, tile crack/break sounds and the master limiter followed in WK-121 a1ada05). Audio not judged by ear
  in WK-CD2.

### [x] WK-106 [P1][M] Sports: one goal banner naming the scorer or OWN GOAL, flash on every goal, team-coloured mouth flash, score pop (SP-03; supersedes WK-16) — 5f34080
- Area: sports | HUD · Owner: ui-ux-designer + gameplay-programmer · Source: WK-98 SP-03 + R-12 (WK-16, merged here)
- Evidence: 32/62 Rocketball goals (52 %) last touched by the conceding team, never said on screen; banner is always
  `GOAL!   RED n — m BLUE`. Bug: `SportsHUD._process` flashes only when `last_scoring_team` changes, so a team's second goal in a row has no
  flash (`tools/out/sports/evidence/sp_goal_no_flash_same_team.png` vs `sp_goal_double_headline.png`, the WK-16 stacked headlines). Goal
  mouth highlight is green for both teams (`sp_goal_moment_center.jpg`). `animate_scores` is a no-op. WK-16's original evidence:
  `tools/out/cd_audit/46_rocketball_3.5s.png`, `d53_contact.png`.
- Impact: "who scored?" on half of all goals. Own goals are the mode's comedy beat once the game admits to them.
- Do: touch credit in the mode (last touch per team; same-team touch within 3 s = assist). ONE banner per goal/point:
  `POGO SCORES!` + small `assist BILLY`, or `OWN GOAL! — BUTCH` with a "boing" sting. Names follow the WK-88 naming rule. Flash keyed off
  a goal counter. Mouth flash in the scoring team's colour. Score-digit pop. Expose per-player credit for WK-111 (end-screen stats).
- Accept (rendered): 5 goals in a row incl. same-team repeats and one own goal: each shows exactly one banner naming the scorer or
  "OWN GOAL", the flash fires on all 5, mouth flash in team colour; one Dropshot point shows the same single banner, nothing clipped by posts.
- Status: done 5f34080. WK-CD2: the GOAL! / POINT! banner names scorer + assist with a full-screen team flash (`tools/out/cd2/rb/r016`,
  `ds/d017`). Side effect to watch: its banner hold is the likely cause of the +0.47 s restart regression (WK-124).

### [x] WK-107 [P1][S] LONG HAUL crops both goals: shrink the court so it fits at the 0.60 sports floor (SP-04) — 834ecda
- Area: sports | levels · Owner: level-designer (JSON) + gameplay-programmer (load-time check) · Source: WK-98 SP-04
- Evidence: `levels/sports/long_haul.json` bounds 3600x1900. Sports framing = `runner.bounds` (`SportsMode.camera_framing`), clamped to
  `PartyMatch.CAM_MIN_ZOOM` 0.60 -> view 3200x1800, so ~200 px is cut each side AND ~50 px top/bottom (fit is 0.533 wide, 0.568 tall).
  `tools/out/sports/evidence/sp_longhaul_goal_cropped.png`, `m3_rb1v1cpu_longhaul/play_372.png`, `rec/wk98_rb_longhaul_2v2/sheet.png`.
  LONG HAUL is in the default `calm_ladder` rotation. Worst pacing too (61 s and 82 s rallies next to 2.3 s kickoff goals).
- Impact: both goals half off-screen on a default-rotation court; a ball in the net is half invisible.
- Camera ruling check (producer): the owner camera rules (`owner_2026-07-10_camera_rules.md`, DECISIONS 2026-07-10) set NO zoom-out floor
  ("zoom fits every clamped position"); the 0.60 clamp is a leftover of the rejected readability-floor lineage and now only feeds sports
  fixed framing. Lowering it for sports would not break the owner's rule (today's crop arguably does). Even so, prefer the geometry fix:
  no camera code touched (repeated owner pain area), goats stay ≥ 0.60 readable, and the smaller court shortens the grind.
- Do: shrink LONG HAUL to bounds ≤ 3200 x ≤ 1800 (NOTE: SP-04's "≤ 3350" is wrong: 1920/0.60 = 3200, and the 1900 height also crops),
  keep strict mirror symmetry and the flight gate (re-run the level-designer flight-required check). Add a load-time warning (or
  `tools/` validation) for any court whose fit zoom is below `CAM_MIN_ZOOM`; all other 10 courts pass by arithmetic (CORAL COVE 0.619).
  Fallback only if the level-designer says the shrink kills the court: derive the sports floor from bounds, with a DECISIONS entry and
  a goat-readability screenshot at ~0.53.
- Accept: LONG HAUL screenshot at 1920x1080 shows both goal back-walls and the ceiling/floor fully inside the frame; flight check passes;
  the load-time check prints nothing for all 11 courts.
- Status: done 834ecda (re-cut to 3200x1800, both goals on screen at 0.60, JSON only). The flat surround now visible at 0.60 -> WK-122.

### [x] WK-108 [P1][M] (+ sports bot stuck ~29/min vs 23 pre-WK-95: make bot 'danger'/out-of-arena look-ahead mode-aware in enclosed courts; keep supporter/ball targets below the ceiling) Sports bots: route around the ball, keep goal, (L4+) cross (SP-06) — ee80867
- Area: sports (bots) · Owner: gameplay-programmer (`InputBot` / `SportsMode.bot_objective`) · Source: WK-98 SP-06
- Evidence: a wrong-side bot flies straight at `behind = ball - to_goal*150`, through the ball, shoving it toward its own goal (CPU own
  goals M2 idx 2/3, M7b 6/8 own goals); supporters hold `own_goal.lerp(ball, 0.42)`, in front of the mouth, not in it: someone within
  500 px of the own goal only 52-60 % of own-half time (M2); no deliberate pass seen in any touch sequence.
- Impact: CPU teammates score on you; no defence to beat. 2v2 with a friend against CPUs is the most social format in the game.
- Do: (a) ball-avoid waypoint (offset perpendicular to ball->goal by ~1.6x(ball + body radius), prefer over the top; commit to `behind`
  only once the segment clears the ball); (b) keeper role for rank ≥ 1 with the ball in the own third (hold goal-mouth centre, challenge
  inside 400 px); (c) optional L4-5 cross. Keep `SUPPORT_HOLD_FRAC` behaviour (PROTECT). Re-measure §6.2/6.3 first.
- Deps: WK-95e landed (shares `InputBot.gd`); WK-104 landed (kickoff formation changes positions). Both done.
- **(b2) CD2-03 folded in (re-rank #5, director): kickoff goals with human-style players.** Evidence: CENTER PITCH 2v2 (3 human-sim + 1 CPU),
  10 goals, rallies 8.3, 4.3, 14.0, 15.4, 12.2, **2.9, 1.75, 1.9**, 9.3, 10.5 s game time; 3 of 10 within 3 s of GO, all scored by human seats
  (`tools/out/cd2/rb/phase.json`, `rb/r016`-`r020`). Median rally 8.8 s is in band. So this is a kickoff RULE / formation problem, not bot
  pathing. Do: game-designer A/B on the current build, measured with HUMAN-STYLE drivers (the CD2 HumanSim pattern, posting real per-device
  events), not only bots: the deep-dive's (c) keeper + midfield formation, or "first touch can't score" (ball dead until it crosses the centre
  line, or a goal within 1.5 s of GO is disallowed). DECISIONS entry. Commit (b2) separately from the routing work (own hunks).
- Accept: 10 bot-only 2v2 WK-93 recordings: CPU own goals ≤ 15 % of goals; supporter within 300 px of the goal mouth ≥ 70 % of
  own-third time; motion health (stuck/min) no worse than the post-WK-95e number (~29/min; pre-WK-95 23). **(b2):** 40 rendered kickoffs
  with at least two human-style seats: goals within 4 s of GO ≤ 10 % (game time from `phase_log.tick_s`, no screenshot bursts, see CD2-05);
  median CENTER PITCH rally 8-20 s; restart time unchanged or better (WK-124).
- Status: done ee80867 (routing, track-back, keeper role, L4+ cross; behind `SportsMode.wk108_bots`). The director closed it on a **partial**
  Accept. 32-run L3 batch (`tools/out/wk/WK-108_sports_bots.json`):
  - Own goals 24.9 -> 21.5 % (target ≤ 15 %, not met).
  - Kickoff goals (< 4 s) 32.3 -> 24.8 %, CENTER 29.5 -> 16.3 %, bots only.
  - LONG HAUL own goals 34.1 -> 14.8 %.
  - Keeper presence 12 % (target 70 %, not met).
  - Stuck/min 36.7 -> 42.5 (worse).

  Where the unmet parts went:
  - Bot half -> WK-108b.
  - The (b2) kickoff RULE with human-style seats was never run -> WK-131 (re-rank #6).

### [ ] WK-109 [P1][S] Power shot gets real dynamic range: split the ball cap, trim the touch floor (SP-07)
- Area: sports (feel) · Owner: game-designer (A/B ruling) -> gameplay-programmer · Source: WK-98 SP-07 · feel-protect: A/B before shipping;
  ball constants are mode-owned (INV-6)
- Evidence: super touches 1.5 % of Rocketball touches, after-speed 2400 (the cap) = only 1.3-1.5x the median normal touch (1630-1830);
  24-33 % of ordinary touches land within 100 px/s of the cap (`500 + 0.9 x ~900` / mass 0.6 ≈ 2000). No soft touch, no cannon moment.
- Impact: the super is meant to be THE move (GAME_ESSENCE; owner WK-95 ruling "super = attack"); in sports it is barely different.
- Do: re-measure §6.1/6.4 on the current build first. Then A/B: normal cap 2400, power-shot cap ~3200 only while `is_super_active()`
  (CCD stays on); `BALL_TOUCH_IMPULSE` 500 -> 350 keeping `BALL_DRIVE_GAIN` 0.9; streak trail + hit-stop (WK-105 signal) + "POWER SHOT!" pop.
- Deps: WK-105 (`ball_struck` signal, strike FX), WK-90 (hit-stop timer is real).
- Accept: touch-speed histogram < 10 % of normal touches near the cap; power shots visibly exceed it; median normal touch 1300-1600 px/s;
  DECISIONS entry; creative-director replay confirms a super header reads as THE big moment. Touch floor still moves the ball (PROTECT).
- Status: open. **Split at re-rank #7:** the cap / floor / streak trail / "POWER SHOT!" pop half runs now (Next-10 #8). It is measured in
  game time (touch-speed histograms), which is valid under software rendering, and `Ball.gd` is free (WK-135 reads it, doesn't edit it).
  The hit-stop garnish waits for WK-90, which is BLOCKED (GPU); it is not part of this pass's Accept. Lane S's measurement chain: after
  WK-131's A/B, and never measured at the same time as WK-108b. Files: `Ball.gd` + a mode-owned constants block (no `Juice.gd`).

### [ ] WK-110 [P2][M] Sports tension: MATCH POINT / GOLDEN GOAL banners + GOALS rule stepper (SP-08)
- Area: sports | menus · Owner: game-designer + gameplay-programmer + ui-ux-designer · Source: WK-98 SP-08
- Evidence: M3 went 3-5 -> 6-5 through an 82 s rally at 5-5 with nothing on screen; the brawl MATCH POINT path (WK-41) is kill-driven
  and never fires in sports; RULES has only FORMAT + CPU SKILL (`tools/out/sports/09_rules.png`); `Tuning.sports_goal_target = 6`
  hard-coded (spec recommended 5 for 1v1, 7 for 2v2).
- Do (two halves, either can ship first): (a) MATCH POINT top banner at cap-1 via `_mp_banner`/`show_top`, GOLDEN GOAL on a cap-1 tie
  (+ crowd swell from WK-105); (b) `GOALS` stepper 3/5/7/10 in SPORTS rules (`GameConfig.rules_for`), per-mode memory (WK-07). WIN BY 2 optional.
- Accept: rules screenshot with the GOALS row; at 5-4 and 5-5 (cap 6) screenshots show "MATCH POINT — RED" and "GOLDEN GOAL".
- Status: open. On deck #2 after re-rank #6: lane S after WK-131 (`SportsMode.gd`); its RULES half touches `LobbySlot` / `GameConfig`.
  CD2 sports-showcase gap #3; it is the last showcase item after the power shot.

### [x] WK-111 [P1][M] Sports end screen: frame the winning team, panel to the lower third, per-player stat strip + MVP (SP-09) — b4eb885
- Area: sports | menus · Owner: ui-ux-designer + gameplay-programmer · Source: WK-98 SP-09
- Evidence: `tools/out/sports/evidence/sp_end_zoom_into_wall.png` (LONG HAUL: `MATCH_END_ZOOM` 1.1 punch on the representative winner =
  goal pillars + void, winners hidden behind the panel); `m6_rb2v2_bowl/end.png` (same on the bowl ledges); panel says only
  "RED WINS! / RED 6 — 4 BLUE".
- Do: for sports, frame the winning team bounds-clamped (zoom ≤ 0.92) + team-colour confetti; panel in the lower third; stat strip from
  WK-106 credit (goals, assists, own goals, power shots) + one MVP chip. End-of-match presentation only, not the in-play camera.
  REMATCH / CHANGE SETUP already work (keep).
- Deps: WK-106 (credit data) — done 5f34080.
- Raised P2 -> P1 (re-rank #5): WK-CD2 names it a creative-director fantasy gap, one of two things between sports and SHIP ("a
  winning-team celebration with stats"); the punch-zoom still lands on a wall. The owner flagged sports as the fun mode (WK-98).
- Accept: Rocketball and Dropshot end screenshots show the winning goats, no void, a stat row per player.
- Status: done b4eb885. Rendered evidence: `tools/out/wk/WK-111_rb2v2_*.png` and `WK-111_ds1v1_*.png`. The winning team celebrates in team
  colours. Per-player table: goals / assists / saves / touches / own goals, or Dropshot points / spikes. Also MVP, longest rally, winning
  goal, and a fresh-press button row. The couch read is re-judged in WK-CD3.

### [ ] WK-112 [P2][S] Sports hazards knock and stun instead of killing; bombs off the kickoff lines (SP-10)
- Area: sports | levels · Owner: game-designer (ruling) + level-designer · Source: WK-98 SP-10
- Evidence: SCRAPHEAP recording: 12 `killed` in 30 s, players dead 4-18 % of COMBAT time; first goal 1.5 s after GO among bombs
  (`tools/out/sports/evidence/sp_scrapheap_sheet.png`); CRUSHER: 6/8 goals own goals (the crusher swats the ball back).
- Do: a sports seam (`SportsMode.on_hazard_contact` or a mode flag) so hazard kill becomes launch + stun; move bomb spawns off kickoff
  lines; chaos courts stay an opt-in rotation (`chaos_night`), default rotation stays calm. Brawl hazard behaviour byte-identical.
- Accept: SCRAPHEAP 30 s bot recording: dead fraction < 3 % per player; no goal in the first 3 s across 10 kickoffs; a brawl pendulum /
  bomb arena still kills (regression check).
- Status: open (on deck)

### [ ] WK-113 [P2][S] Sports legend off the scoring surface + a sports smash line (SP-11 + SP-22)
- Area: sports | HUD · Owner: ui-ux-designer · Source: WK-98 SP-11 (WK-15 follow-up) + SP-22 (merged)
- Evidence: `tools/out/sports/evidence/sp_ds_legend_covers_floor.jpg` (Dropshot rally 1: rule line + chips sit on the floor tiles, cracks
  hidden); Rocketball the same over the floor/trampoline (`tools/out/sports/07_rb_intro.png`). SP-22: smashes happen (16 in M4's 110 s) but
  the legend says only SUPER SMASH; nothing teaches that clearing the keeper opens the net.
- Do: in sports, dock the legend top-centre under the score bug, or fade it at the first ball touch or after 4 s, whichever first. Sports
  legend line: "SUPER-SMASH the ball (power shot) or a rival (clear them)".
- Accept: Dropshot frame at +2 s shows every floor tile unobstructed; stage-1 Rocketball screenshot shows the sports smash line.
- Status: open (on deck)

### [ ] WK-114 [P2][S] Sports courts unlock from sports play, not Brawl circuits (SP-12a)
- Area: sports | levels · Owner: level-designer (JSON only) · Source: WK-98 SP-12
- Evidence: `levels/sports_courts.json` gates HAMMER YARD behind `circuit:scrapworks` and MINEFIELD behind `circuit:mayhem_mile`;
  `Settings.is_court_unlocked` returned false for both on the WK-98 save. A sports-first group can never reach them.
- Do: change both gates to `sports_matches:N` / `sports_wins:N`, slotted into the existing tier order (BOWL `sports_matches:2`, CRUSHER
  `sports_wins:2`, SCRAPHEAP `sports_wins:3`). WK-112 should land first or together: these are hazard courts.
- Accept: eval on a fresh save after N sports matches: both courts unlocked; court-select screenshot shows them open.
- Status: open (on deck)

### [ ] WK-115 [P3][M] Three geometry-first Rocketball courts: PINBALL, SKY GOALS, TWIN NETS (SP-12b)
- Area: sports | levels · Owner: level-designer + game-designer · Source: WK-98 SP-12 · **widening (new content): `scope-check` first**
- Evidence: 5 of 8 Rocketball courts are the same 2800x1600 box with the same goal_zone; only the hazard or 2 mid bumpers differ.
- Impact: court variety is shallow, but the existing courts are fine to play. Depth-first: this sits below the sports polish above
  (producer lowered CD's P2 to P3).
- Accept: each new court passes the flight-required check and the WK-107 fit check; one 2v2 bot recording per court, rally median 6-20 s.
- Status: open

### [ ] WK-116 [P2][S] Rally long tail on big courts (60-80 s grinds): measure after WK-104 + WK-107, then rule (SP-15)
- Area: sports (rules) · Owner: game-designer · Source: WK-98 SP-15
- Evidence: M3 LONG HAUL rallies 27.8, 61.3, 8.1, 19.4, 2.6, 8.5, 2.3, 2.4, 31.7, 12.8, 81.8 s; M1 CENTER had 31 s and 43 s; ball median
  y 1349 on LONG HAUL (hugs the floor). Match length 5.5 min (M3) vs 75 s (M6).
- Do: WK-104 removes the short tail and WK-107 shrinks LONG HAUL; re-measure first. Only if 45 s+ rallies remain: rule on a "sudden
  pressure" goal-mouth growth after 30 s without a goal (visible net extension + crowd chant), a springier sports floor, or LONG HAUL
  mid-field bumpers. DECISIONS entry. Otherwise Won't do with the numbers.
- Accept: 10 CENTER + LONG HAUL rallies, none over 45 s, median 8-20 s.
- WK-CD2 data: CENTER PITCH 2v2 rallies max 15.4 s, median 8.8 s (game time). **Dropshot watch (CD2 soft regression):** median rally 14.5 s
  (range 9-26 s, 11 points, SUNSET BEACH 2v2) vs the deep-dive's 10.7 s on the same court, the effect WK-98 §6.6 predicted from easier
  hovering under the ball. Monitor only: act (game-designer ruling) if the Dropshot median crosses ~20 s. Re-check in the same measurement.
- Status: open (unblocked: WK-104 5f34080 + WK-107 834ecda landed; measure LONG HAUL post re-cut + Dropshot before ruling). Re-rank #6:
  measurement only, no files, so it can run in any free lane. WK-CD3 re-judge (6) takes the Dropshot median. If CD3 also logs LONG HAUL
  rallies under 45 s, close this as Won't do with CD3's numbers.
- WK-CD3 (re-rank #7): **Dropshot watch cleared**: median 9.2 s polled / 9.8 s phase (range 3.6-25.7 s, 2v2), far under the ~20 s act
  line. CENTER PITCH median 5.7-7.0 s (short, not long: that is CD3-05, now in WK-131). CD3 took **no LONG HAUL sample**, so this stays
  open for one measurement: take it in WK-131's post-rule run, then close as Won't do or rule.

### [ ] WK-117 [P3][S] Sports words, not brawl words: "KICK OFF!" / "SERVE!" / "PLAY!" (SP-16)
- Area: sports | menus · Owner: ui-ux-designer · Source: WK-98 SP-16
- Evidence: "BOUNCE!" at Rocketball kickoff (`tools/out/sports/m2_rb2v2_box/play_143.png`), "A FIGHT!" on court select (`06_courtselect.png`).
- Do: mode `display_name`-keyed strings. Do together with WK-43's copy half: Trials circuit select also says "FIGHT!" (same footer).
- Accept: kickoff, serve and court-select screenshots.
- Merged CD3-09 copy half (re-rank #7): the Dropshot lobby rules strip says "FIRST TO 6 GOALS" (`tools/out/cd3/ds_01_lobby.png`); it
  should say POINTS. Court select still says "A FIGHT!" (`rb_04_court.png`). Accept addition: a Dropshot lobby screenshot reading POINTS.
- Status: open (on deck, lane U after WK-42; the kickoff word may sit in `SportsMode.gd`: staged hunks while lane S holds it)

### [ ] WK-118 [P3][S] (unverified) Short stick flicks may be ignored by the lobby carousel (SP-19)
- Area: menus · Owner: qa-playtester (re-check) -> ui-ux-designer · Source: WK-98 SP-19
- Evidence (unverified): two 120 ms pad-0 stick taps did not change the goat, 350 ms holds did (`tools/out/sports/03_lobby_p2.png` vs
  `04_lobby_p2b.png`). Likely a harness artefact: the axis was injected with no intermediate values.
- Do: re-test with a ramped axis injection (0 -> 1 over ~3 frames, held 80-150 ms). Build nothing unless it reproduces.
- Accept: a ramped 100 ms flick changes the goat on the first press, or Won't do with the result.
- Status: open (unverified)

### [ ] WK-119 [P3][S] Sports: keep a small team-coloured CPU pip on bots during play (SP-20)
- Area: sports | HUD · Owner: ui-ux-designer · Source: WK-98 SP-20 (WK-10-adjacent)
- Evidence: `tools/out/sports/m6_rb2v2_bowl/goal_03_2-2.png`: only P1/P2 pips show; in 2v2, "which blue is my CPU teammate?" is colour only.
- Accept: 2H+2CPU Rocketball screenshot 10 s into play shows a CPU pip on both bots, team-coloured, sized like the P# pips.
- Status: open

### [x] WK-120 [P2][S] Sports FORMAT defaults to 2V2 when 2+ humans join; optional "PARTY PICK" ribbon on Dropshot (SP-21) — bbe6996
- Area: sports | menus · Owner: ui-ux-designer · Source: WK-98 SP-21
- Evidence: Dropshot rallies stayed 6-22 s with 9-26 touches and no kickoff lottery across M4/M5 + 2 recordings (best rally quality in
  the game); 2v2 with friends vs CPUs is the most social format (WK-98 §2.7).
- Producer ruling: the card ORDER is owner-set (TRIALS, BRAWL, ROCKETBALL, DROPSHOT; see WK-13), so SP-21's reorder is Won't do. In
  scope: the Dropshot FORMAT default (Rocketball too is a ui-ux call; a FORMAT the players already set for that mode wins, per WK-07
  per-mode memory) and an optional ribbon, also a ui-ux call.
- Accept: 2 humans join a fresh Dropshot lobby -> FORMAT reads 2V2 (screenshot); a remembered 1V1 is kept.
- WK-CD2 confirmed in play: with two humans the sports lobby fell back to 1V1, CPUs NONE (`tools/out/cd2/27_after_holdB.png`); a third
  joiner flipped it to 2V2.
- Status: open. Next-10 #10 after re-rank #7, paired with WK-125 as one lobby pass (`HerdLobby.gd` / `LobbySlot` / `GameConfig`), lane L.
  Both are S, couch-visible, and touch the owner's original complaint surface.

### [x] WK-121 [P2][S] Master limiter (peaks ≤ −1 dBFS, were +10.4) + sports hole falls get a sand puff, not the KO freeze + Dropshot tile crack/break sounds — a1ada05
- Area: audio | sports · Owner: sound-designer + gameplay-programmer · Source: WEEKEND_LESSONS "master bus clips" + WK-105 follow-ups
- Files: `default_bus_layout.tres`, `Juice.gd`, `AudioManager.gd`, `EventBus.gd`, `Ball.gd`, `DropTile.gd`, CC0 Kenney impact samples
  (`assets/sfx/LICENSES.md`).
- Note: filed retroactively by the producer (re-rank #5); the work landed before a backlog entry existed. Closed on the commit plus the
  builder's peak measurement; WK-CD2 did not judge audio by ear. The numeric half of WK-79 (no SFX clipping) is partly covered by it:
  re-check, don't redo.
- Status: done a1ada05

### [x] WK-124 [P1][S] Sports goal-to-kickoff restart back to ≤ 2.8 s game time (PROTECT-list regression) — 540f863
- Area: sports · Owner: gameplay-programmer (+ ui-ux-designer: the scorer banner must still read) · Source: creative-director WK-CD2 §4 soft regression
- Evidence: Rocketball goal -> next GO = **3.27 s game time** (STAGE_END 1.41 + INTRO 0.81 + COUNTDOWN 1.06), from `tools/out/cd2/rb/phase.json`
  `phase_log.tick_s` (game time, not the screenshot-stalled wall clock). WK-98 PROTECT says 2.8 s. +0.47 s, probably the WK-106 banner hold.
- Impact: every goal and every point in the owner's fun mode: ~10 restarts per match, ~5 s of extra waiting each match. Small per goal, but
  the PROTECT list exists so the loop stays snappy.
- Do: find where the +0.47 s comes from in the phase log before changing anything. Prefer overlapping the WK-106 banner with STAGE_INTRO, or
  trimming the sports STAGE_END hold, over shortening the countdown. Sports-only path; brawl phase timings byte-identical.
- Deps: land after WK-108 (both touch `SportsMode.gd`) or stage hunks per item.
- Accept: 10 goals (Rocketball) + 5 points (Dropshot), game-time phase log: median goal -> GO ≤ 2.8 s; a burst shows the scorer banner fully
  readable (name + assist) before it leaves; brawl STAGE_END -> COMBAT unchanged (4.8 / 6.2 s designed).
- Status: done 540f863. Goal -> GO is now 2.67 s game time: a sports-only 1.2 s freeze and a fixed 0.4 s pop-in window. The goal banner
  rides over the reset and stays readable for 1.6 s. The PROTECT-list restart line is met again. WK-CD3 re-checks it in game time.

### [ ] WK-131 [P1][S] Rocketball kickoff goals ≤ 10 % with human-style seats: a kickoff RULE, not bot pathing (CD2-03 carry-over)
- Area: sports (rules) · Owner: game-designer (A/B + DECISIONS entry) -> gameplay-programmer
- Source: creative-director WK-CD2 CD2-03. Producer re-home, re-rank #6: this is WK-104 (b)'s Accept, which was folded into WK-108 as (b2).
  WK-108 closed (ee80867) without running it.
- Evidence:
  - CD2: 3 of 10 CENTER PITCH goals came within 3 s of GO, all scored by human-style seats. Rallies 2.9 / 1.75 / 1.9 s
    (`tools/out/cd2/rb/phase.json`, `rb/r016`-`r020`).
  - WK-108's bot-only 32-run batch: kickoff goals (< 4 s) 32.3 -> 24.8 %, CENTER 29.5 -> 16.3 % (`tools/out/wk/WK-108_sports_bots.json`).
  - No human-seat A/B has been run since.
- Impact: free goals in the owner's fun mode, on every kickoff. CD2 named two things between sports and SHIP: kickoff fairness and the
  end-screen celebration. The end screen is done (WK-111), so this is the last one.
- Do:
  1. Read WK-CD3's human-seat number first (CD3 re-judge 4). If goals within 4 s of GO are ≤ 10 %, close this as Won't do with the numbers.
  2. Otherwise, A/B with human-style drivers on the current build: the CD2 HumanSim pattern, real per-device events, game time only. Test
     "first touch can't score" (a goal within 1.5 s of GO is disallowed, or the ball is dead until it crosses the centre line) against the
     deep-dive's keeper + midfield formation.
  3. Write the DECISIONS entry. Brawl stays untouched.
- Deps: WK-CD3's measurement. Lane S runs it after WK-108b (both edit `SportsMode.gd`); otherwise stage hunks.
- Accept:
  - 40 rendered kickoffs with ≥ 2 human-style seats: goals within 4 s of GO ≤ 10 %, game time from `phase_log.tick_s`.
  - Median CENTER PITCH rally 8-20 s.
  - Goal -> GO restart still ≤ 2.8 s (now 2.67 s, WK-124).
  - PROTECT list unchanged.
  - A WK-93 recording of 3 kickoffs, looked at.
- Status: open. **GO (re-rank #7).** WK-CD3 §4 (CD3-02): with human-style seats, 5 of 19 goals (26 %, round-clock lower bound) or 3 of
  19 (16 %, whole-COMBAT upper bound) came within 4 s of GO, and every one was scored by a human seat or a human's team, so bot pathing is
  not the cause. Both bounds are above the 10 % line, so step 1 is done and step 2 starts. CD3 also measured the restart at 2.67 s on all 26
  restarts (PROTECT met).
  - Merged CD3-05: the CENTER PITCH rally median dropped to 5.7 s (polled) / 7.0 s (phase), below the 8-20 s band; most of the drop is the
    kickoff goals. Re-measure the median after the rule and only act (new item) if it is still under 8 s. Take WK-116's LONG HAUL sample in
    the same run.
  - Files: `SportsMode.gd` + an own `Tuning.gd` block. `SportsMode.gd` is held by WK-135 (S1/S3 ball-touch refund) until it commits: run
    the A/B in a scratch copy now, commit after WK-135 or with staged hunks. Next-10 #2, lane S (first in the sports measurement chain).


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
- Status: done 4d5d356. WK-CD2 verified: no bubbles in sports or Trials; Brawl bubbles inside each arena's own layout.

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

### [x] WK-CD2 [P1][M] Creative-director cold playthrough #2 (recurring) — aa78b3e
- Source: WEEKEND_LOOP step 6 · Owner: creative-director, then producer re-rank · Area: all · uses the game slot
- Deps (re-rank 2026-11-14 #4): WK-95e landed (its feel sign-off (e) folds into this run), WK-104/105/106 landed, WK-20a ruling written.
  WK-25 is NO LONGER a dep (CD2 is overdue: 19 items since WK-CD1). Item (1) is judged with WK-23/24 and says whether WK-25 is still
  needed as designed. WK-98 findings are ranked (done).
- Do: the same 3-device cold run as WK-CD1 (pad + kb + pad, full default Brawl to Victory, REMATCH, one 3-lives stage, one
  Trials + one Rocketball + one Dropshot launch). Re-judge specifically: (1) can you tell who KO'd whom from the screen alone
  (WK-23/24); (2) does the score economy still let a CPU beat three humans (WK-20a ruling + any WK-20c change); (3) measured
  STAGE_END -> next COMBAT time against the WK-21/41 budget; (4) powerups appear only where each arena placed them (WK-86);
  (5) normal flight steers and the super reads as an attack, for humans and bots (WK-95, owner ruling); (6) pendulums smash and
  swing with weight, players draw over the black hole (WK-96/97); (7) one Rocketball + one Dropshot match judged against the
  WK-98 findings: kickoffs (WK-104), goal sound + banner (WK-105/106), the PROTECT list, and the WK-98 §6.6/6.7 re-checks (Dropshot
  rally length vs 10.7 / 14.5 s; bot aim smoothness). Use WK-93 recordings for (1), (5), (6) and (7).
- Accept: findings doc in `docs/audit/` with screenshots under `tools/out/cd2/` + producer re-rank before Next-10 item 8 is pulled.
  Next instance WK-CD3 ~6 items later.
- Status: done aa78b3e, doc `docs/audit/2026-11-14_cd2_playthrough.md`, evidence `tools/out/cd2/`, recordings `tools/out/rec/cd2_*`.
  Verdict FIX, much closer than CD1: flight SHIP (WK-95/95e(e) closed), front end + couch input SHIP, sports one kickoff fix + an end screen
  from SHIP, Brawl FIX on pacing and score economy (WK-20a is the critical path). Owner check-in asks WK-94/95/96/97 verified FIXED, WK-98
  agreed. No functional regressions. New findings: CD2-01 -> WK-123 · CD2-02 -> WK-123 · CD2-03 -> WK-108 (b2) · CD2-04 -> WK-125 ·
  CD2-05 -> tooling lesson (Measurement validity note above; no game item) · CD2-06 -> WK-35. Soft regressions: restart 3.27 s -> WK-124;
  Dropshot rally 14.5 s -> watch in WK-116. Watch item: bot orbit loops -> WK-126 (unverified). Re-judged: 20a, 21/41, 25, 37, 85, 86, 87,
  88, 42, 13, 120 (notes on each). Producer re-rank #5 done (this file).

### [x] WK-CD3 [P1][M] Creative-director cold playthrough #3 (recurring) — ee892a5
- Source: WEEKEND_LOOP step 6 · Owner: creative-director, then producer re-rank · Area: all
- Uses its own port (WK-130) and plays a **pinned snapshot**: `git archive <start hash>` into its scratchpad. Record the hash in the doc and
  delete the snapshot afterwards (disk hygiene). That way parallel lanes can keep committing without their working-tree edits leaking into
  a CD3 relaunch.
- When: Next-10 #1 after re-rank #6. It is overdue: 14 deliverables have landed since CD2 (the loop cadence is ~6).
  - Start the moment WK-128 commits. It is S and in flight, and its spec §9 CD feel check folds in here. If WK-128 ends `[~]`, start anyway.
  - Do not wait for WK-53. If the bleat commits before CD3's Brawl session, judge ghost T15 Q5 with sound. Otherwise mark Q5
    "pending WK-53" in the doc.
- Re-judge specifically (same 3-device cold route as CD2):
  1. **Brawl pacing after WK-127 + WK-20c + WK-25.** Compare against CD2: stage length (CD2 human-sim median 11.6 s; WK-127 bot batch
     8.4 -> 13.8 s), first-death time, CPU share (CD2 10-6-4-2) and dead-frame share (CD2 P1 48 %). Can you read every score change on
     screen from the +1 / OOPS pop? Self-KO now costs 0 by default: does the winner match who fought best?
  2. **Ghost goats (WK-37b).** The spec's T15 felt pass (`docs/specs/wk37a_ghost_goats_2026-11-14.md`), plus T12/T13 human-sim if time
    allows. Is the dead half of the evening now fun? Are the ghosts clutter, or too faint on wide cameras (feeds WK-37c)? Take the T14
    frame-time number only in a SOLO window, otherwise skip it.
  3. **Flight School (WK-123).** Can a newcomer clear lessons 2-4 without firing a super? Is co-op lane blocking gone (decides whether
     WK-123b is still needed)? WK-128's fuel feel check (tapping and wall farming closed; does flight still feel generous?).
  4. **Rocketball kickoff goals with ≥ 2 human-style seats**, in game time. This is the go/no-go number for WK-131. Also: restart time
     (WK-124, 2.67 s), CPU-teammate own goals (WK-108b baseline), the sports end screen (WK-111).
  5. **Dropshot rally median** (WK-116 watch: CD2 14.5 s, act above ~20 s). Add a LONG HAUL rally sample if time allows.
  6. **Bots:** orbit loops at --follow zoom (WK-126, unverified) and the_ascent top-tier hopping (WK-127b).
  7. **Look baseline:** gap #4 as it stands, for WK-34 / WK-122 / WK-66a / WK-85. Navy panels, mint fill, sports letterbox, nets.
- Numbers: game time only (`phase_log.tick_s` / `round_stats`), never wall clock across screenshot bursts (CD2-05). Motion from WK-93
  recordings.
- Accept: findings doc in `docs/audit/` with screenshots under `tools/out/cd3/`, every finding mapped to a WK id or merged, then producer
  re-rank #7.
- Status: done ee892a5. Verdict FIX, close to SHIP (front end SHIP, sports SHIP-adjacent, Flight School SHIP, ghosts deliver). Biggest
  gap: Brawl pacing on MEADOW MILE. CD3-01..09 triaged at re-rank #7 (see the Coverage index). Next: WK-CD4.

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

### [x] WK-13 [P1][S] Mode select: BRAWL default focus, equal card heights, player-count chips — b2ac978
- Sources: R-18, D-29, C-35 · **OWNER-RULED**: card ORDER is owner-set (TRIALS, BRAWL, …) — keep it, change focus only
- Area: menus · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/03_modeselect.png; WK-CD1 2026-11-14: still defaults to TRIALS (carried over unchanged); WK-CD2: still TRIALS;
  WK-CD3: still TRIALS (`tools/out/cd3/02_after_play.png`)
- Accept (rendered): fresh save -> ModeSelect focus on BRAWL; after playing Trials, focus = last-played; all 4 card art panels
  same height; chips read e.g. "2-4 VERSUS", "1-4 CO-OP", "1V1 / 2V2"; Trials has a "SOLO / CO-OP" sub-label.
- Status: open. Next-10 #5, lane U (`ModeSelect.gd` + scene). Starts now.

### [x] WK-14 [P1][S] Focus is singular: style swaps on focus, no permanently "primary" button — ab11c61
- Sources: C-13, R-21, CC-5.1
- Area: menus · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/30_after_quit.png (QUIT focused, RESUME still green)
- Accept (rendered): screenshots with focus on the LAST button of Title, Pause, Victory, Sports end row, Trials end row: exactly
  one element looks focused in each (shared `FocusRow` helper replaces the three `_set_focus` copies).
- Status: open

### [x] WK-15 [P1][S] Teach the goal: controls legend on every mode's stage 1, rule line, honest BRAWL tagline — a4955e7
- Sources: C-12 (legend part), D-13a, D-04 (messaging part), CC-11.1
- Area: HUD · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-01 (legend glyphs)
- Do: legend out of the `wants_scoreboard()` gate, mode chips (Sports "HEADBUTT the ball", Trials "LAND on the pad");
  stage-1 StageIntroCard rule line "SMASH 'EM OFF-SCREEN · FIRST TO 10 KOs"; BRAWL tagline -> "Smash 'em off-screen.
  First to 10 KOs."; stage banner leads with KOs, survivor as sub-line.
- Accept (rendered): stage-1 screenshots of Brawl, Trials, Rocketball, Dropshot each show the legend; Brawl intro shows the rule line.
- Status: done a4955e7 (4-mode stage-1 screenshots). Sports follow-up: the legend sits on the scoring surface -> WK-113 (WK-98 SP-11).

### [>] WK-16 [P1][S] Sports: one goal/point banner, not two stacked headlines — merged into WK-106
- Sources: R-12 · Evidence (carried into WK-106): tools/out/cd_audit/46_rocketball_3.5s.png, d53_contact.png
- Status: superseded by WK-106 (WK-98 SP-03 raised its scope S -> M: scorer / OWN GOAL credit, flash on every goal, team-coloured
  mouth flash, score pop). Its Accept line lives in WK-106. Do not pull WK-16 separately.

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

### [x] WK-18 [P1][S] 28 px floor for anything a player reads — 2aa8f87
- Sources: C-27, R-10 (micro-text), R-25 (KO chip legibility), CC-8.1, lobby review L6
- Area: menus/HUD · Owner: ui-ux-designer · Deps: WK-17
- Also (L6): lobby roster-medallion P-badges ~21 px -> 30x44 chip, 28 px white text on chocolate; a locked medallion
  desaturates to 0.6 and shows the MenuCard check ("taken" reads from the sofa).
- Accept (rendered): theme tokens CardTag/CardName/HintStrip/ControlsLegend/FLAIR >= 28 px; screenshots of the 5 affected screens
  at 1080p show no overflow; KO meta chip readable; lobby with 2 locked goats shows 28 px badges + desaturated medallions.
- Re-rank #5: pulled into the Next 10 as the cheap (S) half of CD2 gap #5 "couch readability of state". Deps (WK-17) done. Include the sports
  score bug's "TO 6" (~14 px, SP-18) if it is a token change; the full scoreboard restyle stays in WK-35. WK-31 (stocks/danger on the card)
  is the M follow-up, on deck.
- Status: done 2aa8f87. Theme type-scale plus per-node fixes put every player-facing text at ≥ 28 px at 1080p, with no overflow. Lobby L6
  shipped too: a locked medallion desaturates and shows the drawn check.

### [ ] WK-19 [P1][S] Rumble goes only to the concerned player's pad
- Sources: C-10, R-32 (rumble part), CC-3.6
- Area: brawl · Owner: gameplay-programmer · Deps: WK-04 (player -> device)
- Accept: eval-log `start_joy_vibration` calls during 10 smashes in a 2-pad match: only the victim's/attacker's device id appears.
  (Rumble can't be seen; the call log is the evidence.) Options toggle lands in WK-44.
- Status: open

### [x] WK-20a [P1][M] Who wins and why: measure the +25 % knockback side effects AND the self-KO −1 rule, then game-designer rulings (no code change) — 2721c7c
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
- Re-ranked 2026-11-14 #4 (Next-10 #6): WK-95 has landed (4135884), but WK-95e (a) is still changing the bot brain (stuck/underside
  regressions). CPU behaviour feeds the self-fall and KO numbers, so start the measurement after WK-95e (a) lands, not before.
- **WK-CD2 data (post-WK-95e build, `tools/out/cd2/m1/stats.json`, `log.json`; 3 human-sim + 1 CPU L2, 12 stages):** the CPU won again,
  **10-6-4-2**, but self-KO −1 is no longer the main cause: humans self-fell **6 of 33 deaths (18 %, CD1 33 %)**. The CPU simply out-fought
  them: **13 credited KOs vs 4 / 8 / 5**, and died 6 times vs the humans' 10-12. Stages got SHORTER: median **11.6 s** (CD1 15 s, about
  −23 %; WK-95 predicted +0-15 %), 4 of 12 under 10 s; Islands Void had 4 KOs at 2.0-3.0 s; the 3-LIVES pendulum stage burned 11 of 12
  lives in one stage. Between-stage time is ~30 % of a match because stages shrank (WK-21/41 budget itself is met). Human-sim P1 was dead
  **48 % of all combat frames**.
- **Outcome list expanded (CD2):** add **stage length** (median, share under 10 s) and **first-death time** to the measured outcomes, next to
  CPU win share, credited KOs vs score and self-fall share. Drivers must be human-style (CD2 HumanSim pattern) as well as bots.
- **Ruling guard (producer):** CD2 calls the owner's +25 % knockback (`dmg_launch_mult`, DECISIONS 2026-07-19) "the knob to test first".
  Measuring it is fine. Changing the array is OWNER-RULED (ruling (c)): the owner's value stays and only what feeds it may change (WK-20b's
  Lv0 gate, LIVES/score rules, CPU mix, arena-level knobs). If the data says the array itself is the problem, the game-designer writes that
  up as a recommendation for the owner and the studio works the feeding knobs meanwhile. Do not silently revert it.
- Status: done 2721c7c (results `docs/audit/2026-11-14_wk20a_results.md`), rulings fecb4a9 (DECISIONS 2026-11-14):
  - (1) Self-KO = row Ra: costs 0 by default, with a SELF-KO -1 RULES toggle. Under -1, 27-32 % of matches show ranking inversions -> WK-20c.
  - (2) WK-20b Won't do: graze effects are real but outcome-neutral. The owner's knockback array is untouched.
  - (3) WK-89 Won't do.
  - (4) CPU dominance is fighting, not scoring. Bots self-KO 36 % of deaths -> WK-127.

### [x] WK-20c [P1][S] (conditional on WK-20a) Apply the game-designer's self-KO / CPU-mix ruling — 6f4f51b
- Source: CD1-02 via WK-20a · Area: brawl · Owner: gameplay-programmer · Deps: WK-20a ruling · WK-25's −1 OOPS pop follows the result
- Accept: re-run the WK-20a human-style batch: the ruled behaviour holds (eval `scores` deltas on self-falls) and the RULES toggle,
  if any, persists per mode (WK-07 memory); DECISIONS entry in the same commit.
- Re-rank #5 (Next-10 #4, shared slot with WK-20b): CD2 shows the CPU wins on credited KOs, not self-falls, so the CPU-mix half (option c)
  may matter more than the −1 half. Whatever the ruling says, the Accept adds: median stage length and CPU win share on the human-style
  batch move toward the ruling's target (numbers in the commit). If the ruling picks a pacing change, size it then: it may not be S.
- Status: done 6f4f51b. Self-KO costs 0 by default (ruling Ra), with a SELF-KO -1 RULES toggle (Brawl, per-mode memory). OOPS! shows on
  the banner and ScoreScreen. Screens: `tools/out/wk/WK-20c_rules_off_1080p.png` and `_on_1080p.png`. Pacing and the CPU share went to
  WK-127 (done) and are re-judged in WK-CD3 (1).

### [ ] WK-20d [P1][M] Brawl pacing on MEADOW MILE: a one-variable ladder for stage length and the human self-KO share (CD3-01)
- Area: brawl (pacing) · Owner: game-designer (+ qa-playtester driving HumanSim seats) · Source: creative-director WK-CD3 CD3-01
  (`docs/audit/2026-11-15_cd3_playthrough.md` §1, "the single biggest remaining problem")
- Evidence (27 stages, bill ON, 3 HumanSim seats + CPU L2, MEADOW MILE, default rules; `tools/out/cd3/m1/stats.json`, `m2/stats.json`,
  A/B `m3off/stats.json`):
  - Median stage 8.4 s (mean 9.4; 4 of 27 under 5 s). CD2 was 11.6 s on a different arena mix.
  - First death median 2.8 s.
  - Human self-KO share of deaths 33 % (m1), 49 % (m2), 48 % with the WK-128 bill OFF (so WK-128 is not the cause). None of them had a
    prior smash on the victim. Example: two pads off the left edge at 1.1-2.6 s on Clover Steps, Sunny Shoulders and Two Hills.
  - Interstitials are 5.0 s game time per stage, so ~38 % of a Brawl is between stages.
  - Super = the last smash on 70 % of credited KOs (35 of 50): keep this.
  - The bot-only batch (WK-127) says 13.8 s, so the gap is the human-style seats: a newcomer flies at someone, supers, misses and is gone.
    The super drains the whole tank (`Player._fire_super`, `fuel = 0.0`), so a miss next to a void is a self-KO.
- Impact: every Brawl stage for every group, in the default mode on the first arena card. The fantasy arc (fight, get launched, claw back,
  super-smash) rarely has room to happen. Ghosts made the dead time playable; this is the living fight.
- Do (measure and rule; no repo code in this item):
  1. Run CD3's drivers (`tools/out/cd3/*.gd.txt`, HumanSim3) from a scratch copy, with each arm applied by eval
     override or a scratch-only JSON edit. Re-run a fresh baseline in the SAME session (software rendering, see In flight: never compare
     an arm against CD3's absolute numbers). Game time only.
  2. One variable per arm, >= 20 stages each, on MEADOW MILE:
     - (a) a wider blast margin on MEADOW MILE's void arenas (Islands Void, Twin Chasms, Hill and Dale). Level data only, so it is the
       cheapest arm to ship.
     - (b) a fuel floor after a missed super (e.g. the super leaves 15 fuel when it hits nothing within its 0.45 s window). This bends the
       drain-all identity (`Player.gd` §1.2, owner's 2026-07-02 un-charged super): run the `gottabounce-change-control` check, and it
       needs a DECISIONS entry if shipped. It mirrors the existing `finisher_refuel_floor` (15) on a hit.
     - (c) **diagnostic only:** the knockback array back to 1.0x. `dmg_launch_mult` is **OWNER-RULED** (DECISIONS 2026-07-19; ruling (c)),
       so this arm cannot ship in the owner's absence. It tells us how much of the problem the +25 % causes. WK-20a's bot arms found it
       outcome-neutral on stage length, so expect a small effect.
     - The designer may add an arm (e.g. the MEADOW MILE stage order) if the data points there. Pre-register the predictions.
  3. Write the results to `docs/audit/` and a DECISIONS ruling that names the lever(s) WK-20e ships, or Won't do with numbers.
- Target: median stage >= 12 s and human self-KO <= 25 % of deaths, super-kill share >= 60 %, winner = most credited KOs (unchanged).
  Side note from CD3: a stage where everyone self-falls pays nobody (1 of 27). No item unless WK-20d sees it more often.
- Accept: results doc + DECISIONS entry; every arm has >= 20 stages with the baseline from the same session; a WK-93 recording of the
  chosen arm on Islands Void, looked at.
- Scope-check: DO, split. It deepens the core (SUPER-SMASH, RECOVER), every couch group notices, and the build half is WK-20e.
- Status: open. Next-10 #1, lane D. Starts now: it edits no repo files, so WK-135's hold on `Player.gd` doesn't block it.

### [ ] WK-20e [P1][S] (conditional on WK-20d) Ship the ruled pacing lever
- Area: brawl · Owner: level-designer (blast margin, JSON) or gameplay-programmer (missed-super floor, `Player.gd` + `Tuning.gd`)
- Source: WK-20d ruling · Deps: WK-20d; for the `Player.gd` lever, after WK-135 and WK-136 (lane P)
- Files: blast margin -> `levels/islands_void.json`, `twin_chasms.json`, `hill_and_dale.json` (lane D). Missed-super floor -> `Player.gd`
  (`_fire_super`) + a `Tuning.gd` block (lane P).
- Accept: re-run the WK-20d arm on the real build (HumanSim, same session as a baseline): the numbers hold within noise; rendered
  screenshots of each changed arena show the camera still frames everyone (owner camera rules); DECISIONS entry in the same commit.
  If the lever turns out bigger than S, split it here first.
- Status: open (waits for the WK-20d ruling)

### [~] WK-20b [P1][S] (conditional on WK-20a) Gate sting/escalation/hitstun at Lv0 on the pre-multiplier impulse — attempted: WON'T DO per WK-20a ruling (DECISIONS 2026-11-14): outcome-neutral
- Sources: D-18 · **OWNER-RULED**: `dmg_launch_mult` array and hitstun triad constants do NOT change; only the impulse fed to the
  sting/escalation gate and hitstun at Lv0 (pre-multiplier) may. DECISIONS entry in the same commit (ruling c).
- Area: brawl · Owner: gameplay-programmer + qa-playtester · Deps: WK-20a ruling
- Accept: graze on Lv0 -> damage_level 0, `_last_sting_applied` 0, hitstun ~0.48 s; centre hit unchanged; >= 50 % of Lv0
  non-edge smashes on victims with fuel >= 20 survived over 40 stages; lethality battery §9 re-run; rendered contact sheet of 3 recoveries.
- Status: wontfix (WK-20a ruling 2, fecb4a9): outcome-neutral. Lv0 survival is 63 vs 55 % and the sign flips between arms. Stages are not
  longer in arm B. Do not pull.

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
  WK-CD2: budget met in game time (~4.1-4.5 s per stage). But stages shrank to a median 11.6 s, so interstitials are still ~30 % of a match.
  The remaining fix is stage length (WK-20a), not more overlay trimming: do not reopen this item for it.

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
- Status: done 4d5d356. WK-CD2 re-judge: delivered, "now the best fix in Brawl". In `tools/out/cd2/rec_ko_f426-452.png` a blue impact +
  blue streak (P2 smashes PUFF) and a pink edge blast (P1's death) tell who KO'd whom from the screen alone.

### [x] WK-24 [P1][S] Hits carry the attacker's colour (impact burst, knockback streak, last-touch ring) — 4d5d356
- Sources: D-06, D-02 (part 2 last-touch tag)
- Area: brawl · Owner: gameplay-programmer · Deps: WK-08
- Accept (rendered): frame-grab 10 smashes: burst/streak hue = attacker colour 10/10; victim in credit window shows a thin
  attacker-coloured ring; streak value >= 0.8 (launch read kept).
- Status: done 4d5d356 (streak = attacker colour per DECISIONS e2394c1)

### [x] WK-25 [P1][M] KO credit pop (+1 flies to killer's card, −1 OOPS on self-fall) + ScoreScreen kill list — 2eef67e
- Sources: D-02 (parts 1+3), R-27 (unlabelled "−1"), R-06 (score-visibility half) · **OWNER-RULED**: no persistent combat score — the pop is transient (<= 1.5 s)
- Area: brawl/HUD · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-23, WK-08, **WK-20a self-KO ruling** (+ WK-20c if
  ruled; the −1 OOPS half changes or disappears with the rule) and WK-89 if confirmed (the kill list reads `round_stats`)
- WK-CD1: "points appear and disappear between overlays"; nothing on screen shows the −1 subtraction (CD1-02).
- Accept (rendered): 4-bot match, 30 deaths: every credited kill shows a killer-coloured +1 reaching the right card within 1.0 s,
  every uncredited death shows −1/+0 on the victim card (eval `scores` before/after, 0 mismatches); ScoreScreen lists
  "P2 ▶ P3" / "P4 SELF-KO −1".
- WK-CD2: still worth doing, "as a cherry on top" now that WK-23/24 read: the score still changes only on the scoreboard, and a self-fall's
  −1 is still invisible.
- Status: done 2eef67e. A +1 flies from the edge blast to the killer's card. A self-fall shows OOPS!, or -1 under the SELF-KO -1 rule.
  ScoreScreen gets a kill list. The couch read ("can you see every score change?") is WK-CD3 re-judge (1).

### [x] WK-26 [P1][S] Super-aim wind-up sound + "!" over the targeted goat — 4ca9472
- Sources: D-07
- Area: brawl/audio · Owner: gameplay-programmer + sound-designer · Deps: none (bleat layer waits for WK-53 asset)
- Accept: `EventBus.super_aim_started` fires; `AudioManager.last_sfx == "super_aim"` on aim entry; 10 scripted aims -> "!" on
  the correct target >= 9/10 within 2 frames (rendered screenshots of 3).
- Re-ranked 2026-11-14 into Next-10 #9: the WK-95 owner ruling makes the super THE attack, so its telegraph carries more weight.
  Build after WK-94 commits (the "!" must follow the smoothed aim target, not the old per-frame jitter).
- WK-CD2 gap #5: "a super wind-up has no audio or '!' on the target". Bot aim is now a slow, readable sweep (WK-94 verified), so the "!"
  will track cleanly.
- Status: open. Next-10 #9 after re-rank #6, lane A after WK-53, since both edit `AudioManager.gd`. It also needs `Player.gd` (aim entry),
  so it waits for WK-128's commit. New `EventBus.super_aim_started`: append it in its own block. The "!" is a new small scene.

### [x] WK-27 [P1][M] Herd Lobby slice 4: Sports — picking the goat picks the team — a4955e7
- Sources: C-16 (sports half), C-31, R-14 (sports half), E.6, lobby review L2 (17a/17b: ZIGGY/PUFF still selectable in ROCKETBALL)
- Area: menus/sports · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-07 (done)
- Do: carousel = POGO/BILLY (RED), BUTCH/VEX (BLUE), team ribbon, full-team goats skipped; `MatchConfig.team_ids`;
  `SportsMode.spawn_plan` honours team_ids + human skins (keep even-total clamp, bot mirroring); CPUs fill seats.
- Accept (rendered): 2 humans pick POGO + VEX with 2 CPUs -> 2v2 with one human per team; the picked goat skins appear in
  the match (no repaint); 2 humans both RED -> 2 humans vs 2 CPUs.
- Raised 2026-11-14 (owner check-in, WK-98 sports weight) into Next-10 #3. The build is code-only (HerdLobby/LobbySlot, MatchConfig,
  `SportsMode.spawn_plan`): it may be built in parallel with WK-95 and only needs the game slot to verify. `SportsMode.gd` has small
  uncommitted in-flight edits (6 lines) — coordinate with their owner before touching it.
- Status: done a4955e7. WK-98 §4 verified it in play: picking the goat picks the team, 2V2 auto-fills a CPU per side in the team's spare
  colourway, CHANGE SETUP keeps teams, RULES ownership works on pad (`tools/out/sports/03-10_*.png`).

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
- WK-CD2 gap #5: the HUD card still shows only fuel, no stocks, no danger level. The M follow-up to WK-18 (done 2aa8f87).
- Status: open. On deck #3 after re-rank #6. Its files (`PlayerCard.tscn`, `MatchHUD.gd`) are disjoint from WK-34, so it can open its own
  lane the moment one is free.

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

### [x] WK-34 [P1][M] Toybox panel kit A: Pause, in-match Options, ScoreScreen — 8051d4f
- Sources: R-11, R-22 (pause BACK overlaps P1 card, v0.1 overlaps P4)
- Area: menus/art · Owner: ui-ux-designer · Deps: WK-17
- Accept (rendered): the three screens use the cream/chocolate frame + header ribbon + shell buttons; no dark-navy plate;
  nothing overlaps HUD cards. art-director/ui-ux verdict.
- WK-CD2 gap #4 "one finished look": navy dev panels are still the scoreboard, final score, Options, Trials objective and sports end card;
  with the front end at Mario-Kart quality they now stand out more. Kit A is the first half; WK-35 follows on deck.
- Note (re-rank #6): ScoreScreen gained the WK-25 kill list and the WK-20c OOPS! line. The kit restyle must keep both readable at 28 px
  (WK-18).
- Status: open. Next-10 #7 after re-rank #6, lane U: PauseMenu, Options, ScoreScreen and `theme.tres`. No other lane edits these.

### [x] WK-35 [P1][M] Toybox panel kit B: Victory final score, Trials objective banner, Sports scoreboard — 9498e0f
- Sources: R-11, WK-98 SP-18 (merged)
- Area: menus/art · Owner: ui-ux-designer · Deps: WK-34
- SP-18: the sports score bug is ~210x80 px at 1080p and "TO 6" ~14 px tall (`tools/out/sports/07_rb_intro.png`), with no team names
  or crests. The kit-B sports scoreboard gets team-colour halves, RED/BLUE labels or goat crests, and keeps WK-106's score-digit pop.
  Producer note: if WK-34 stalls while sports stays the owner focus, split the sports scoreboard out as its own S/M item rather than
  wait on the whole kit.
- **Merged CD2-06 (creative-director WK-CD2, P3/S; separable, can ship alone):** at Brawl STAGE_END the surviving player's P# pip draws on
  top of the banner sub-line "P1 +1 · P2 +1 · P3 +1 · P1 SURVIVED" (`tools/out/cd2/m1/h012_STAGE_END.png`). Hide pips during the STAGE_END
  banner, or put the banner on a layer above them (WK-41's one-overlay-at-a-time ordering). Identity overlay ordering, so it rides with the
  banner restyle here.
- Accept (rendered): same kit on the three screens (screenshots); ui-ux verdict Ship; the restyled Trials objective panel keeps the
  WK-87 placement (never over the goal ring); the sports scoreboard text meets the 28 px floor (WK-18); a STAGE_END frame with a surviving
  human shows no pip over the banner text (CD2-06).
- Status: open (kept P1 by WK-98 §4). On deck #4 after re-rank #6, lane U after WK-34.

### [x] WK-36 [P1][M] Off-screen magnifier bubbles (watch the recovery live) — a4955e7
- Sources: D-05, R-30 · **OWNER-RULED**: camera framing untouched (owner rules 2026-07-10) — EdgeIndicators upgrade only
- Area: brawl/HUD · Owner: gameplay-programmer · Deps: WK-08
- Accept (rendered): player knocked 1500 px above top platform -> edge bubble with goat sprite + fuel ring within 10 % of
  `get_fuel_ratio()`; aim arrow shows within 1 frame of super aim off-screen.
- Status: done a4955e7 (verified, a4bc89c STATUS note).

### [x] WK-37 [P1][M] Ghost goats: eliminated players float, quack and get one non-lethal heckle per stage — 1186bcf (37a spec 28ddce0, art 53389a8)
- Sources: D-08, R-07 (spectating half)
- Split: **WK-37a [S] spec** (game-designer, `docs/specs/` entry with the QA criteria below; no game slot — can run in parallel
  any time) -> **WK-37b [M] build** (gameplay-programmer). `scope-check` on the spec (new system).
- Area: brawl · Owner: game-designer (spec) + gameplay-programmer · Deps: WK-04 (done); quack needs WK-53; GHOSTS option lives on the RULES panel back (WK-07 done)
- Accept (rendered): eliminated human's ghost moves from their device within 1.0 s; 40 % alpha, no flame; excluded from camera;
  heckle puff never credits a kill over 20 stages; option GHOSTS ON/OFF in RULES.
- WK-CD1 re-judge (matters more than described): a group that raises LIVES to 3 "to play longer" waits LONGER — P3 eliminated
  ~30 s in, then watched a 1v1 for over a minute (`tools/out/cd1/sheet_m4.png`). Keeps WK-37a high on deck.
- WK-CD2 re-judge (matters more): human-sim P1 was dead **48 % of all combat frames** across the match (4,378 dead vs 4,671 alive,
  `tools/out/cd2/m1/`). With 6-12 s stages, "watch the others" is half the evening for a weaker player. CD2 gap #1 pairs it with WK-20a.
- Re-rank #5: WK-37a (spec, S, no game slot) enters the Next 10 at #6 and can run in parallel with WK-20a. The spec should read the WK-20a
  numbers once they exist (a pacing ruling that lengthens stages changes how much ghost time there is). WK-37b build stays on deck behind it.
- Status: done 1186bcf. Spec 28ddce0, art brief fccf8dc, art 53389a8, DECISIONS db1f064.
  - Tests T1-T8 pass: camera moved 0.0 px; 20/20 ghost-caused deaths uncredited.
  - RULES: GHOSTS ON / BAA ONLY / OFF.
  - Open: T11 bot-ghost spacing fails, and the art-director pass is pending -> WK-37c. The bleat sample -> WK-53 (the `EventBus.bleated`
    hook is ready). T12-T15 -> WK-CD3 re-judge (2).

---

### [ ] WK-90 [P1][S] BLOCKED (GPU) (RE-MEASURE with screen on first) Hit-stop fires after ~3 frames regardless of duration (Godot 4.7 timer arg quirk) — design call first
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
- Status: open. Next-10 #8 after re-rank #6, lane T. Evidence is pending the re-measure.
  - Step 1 (the 30/60/120 fps freeze measurement) needs a **SOLO window**: no other rendered game running (WK-130 CPU sharing), screen on.
    Schedule it after CD3's session.
  - Step 2 is the game-designer ruling. Step 3 is the `Juice.gd` fix (WK-121 last touched that file).
  - Gates the WK-109 power-shot hit-stop, which follows in the same lane.
  - **BLOCKED (GPU), re-rank #7:** both GPUs are in an error state and the game renders in software (~37-52 fps) until the owner reboots.
    No valid 30/60/120 fps measurement is possible. Unblock when `gbplay perf` shows ~120 fps again with the screen on. Only WK-109's
    hit-stop garnish waits on this; WK-109's cap/floor half was split out and runs now.

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


### [x] WK-92 [P2][S] Font follow-ups from WK-17 grade — a4955e7
- Source: ui-ux-designer WK-17 verdict (tools/out/wk/WK-17_*). Owner: gameplay-programmer.
- (1) Victory winner name: chocolate ribbon behind it like StageIntroCard (yellow Puff over gold rays is weakest);
  (2) MATCH POINT top banner overlaps the leaving StageIntroCard ribbon ~0.2 s — delay show_top until intro exit;
  (3) Rocketball card "(Okay" sidebearing — drop parentheses; (4) the ✓ on menu cards still uses a system font —
  swap for PadGlyph's drawn check. Small-text floor items stay in WK-18.
- Accept: screenshots of Victory (Puff winner), MATCH POINT stage intro, ModeSelect.
- Status: done a4955e7.


### [ ] WK-103 [P2][S] Pendulum follow-ups: Trials pendulum courses now smash; art-director grade; boost-arrow flick
- Source: WK-96 builder. Pendulums smash in ALL modes incl. Trials (course_04_pendulum_pass, swing_mines, wrecking_yard
  — untested; levels can opt out with "contact": "shove"). Peak speed 3800 -> 2650 px/s (feel unjudged). Bot normal-boost
  arrow still flicks >30 deg on 7-13% of frames (folded into WK-95 build brief). Art-director grade of the new swing
  (tools/out/rec/wk96_pendulum_after/swing_60-162_sheet.png).
- WK-CD2: the swing reads well (29 contacts -> 11 smashes on Pendulum Heights, `tools/out/rec/cd2_brawl_pendulum/sheet.png`). Cosmetic
  add for the art-director grade: the chain hangs from a cloud (no visible anchor).
- Accept: Trials pendulum courses completable (recording), art-director Ship (incl. a visible anchor).
- Status: open (on deck after re-rank #6). Check WK-128's §9 Trials sweep first: if it drives `course_04_pendulum_pass` / `swing_mines` /
  `wrecking_yard`, the completability half is covered and only the art-director grade + anchor remain.


### [x] WK-122 [P2][S] Sports courts: area outside the sealed court is a flat blue border + doubled pillar columns — e3e11d5
- Source: WK-107 render (tools/out/wk107/after_f150_kickoff_both_goals.jpg). At zoom 0.60 the view = bounds, so the
  unpainted Zone-A surround (known since session 9) shows as a flat blue frame and a second outer pillar column on
  each side. Paint/extend the stadium interior to the bounds or drop the outer columns. Owner: art pipeline + level.
- WK-CD2 gap #4: sports courts read as "a dark stadium in a flat letterbox". This is the cheap (S) half; the painted stadium / real beach
  is WK-66.
- Accept: screenshot of LONG HAUL + CENTER PITCH with no flat-colour border.
- Area: sports | art · Owner: art pipeline + level-designer (+ art-director grade) · Source: WK-107 render + WK-CD2 gap #4
- Raised on rank, not band (re-rank #6): sports items jump their band (owner ask 6). The letterbox shows on every frame of every sports
  match, because at 0.60 the view = bounds. CD2 says pull it before WK-66.
- Status: open. Next-10 #6 after re-rank #6, lane V (`ArenaRenderer.gd` sports draw path, `levels/sports/*.json`). WK-66a follows in the
  same lane.


### [x] WK-127 [P1][M] Bots self-KO 36% of deaths; 59% of 4-bot stages lose a fighter before 3 s — 25e2c86
- Source: WK-20a results (2721c7c) §11. Causes: (a) bots fire an attack super in the first second (53% of stages) and fly
  off after missing; (b) `recovery_unreachable` supers fire at 50-97 fuel — `_nearest_ground_dx` mis-measures on spires /
  the_ascent (74 cases followed by self-KO within 3 s = 9% of all deaths). Likeliest source of CD2's short stages.
  Minor: `smash_landed` fires for hits on spawn-protected players. Owner: gameplay-programmer (bot brain).
- Accept: 320-stage batch: bot self-KO share <= 20%, first-death-before-3 s <= 20% of stages, median stage length up;
  recordings show no opening suicide supers.
- Status: done 25e2c86. 320-stage batches (`tools/out/wk/WK-127_measure.json`):
  - Bot self-KO share 37.8 -> 17.8 %.
  - Stages with a first death before 3 s: 56.6 -> 9.7 %.
  - Median stage 8.4 -> 13.8 s.
  - Traversal supers 9.3 % (owner target held).
  - Credited KOs per 320 stages 631 -> 810.

  `smash_landed` no longer fires on spawn-protected victims. Open: stuck/min 1.4x -> WK-127b. Human-sim stage length is re-judged in
  WK-CD3 (1).


### [x] WK-128 [P1][S] Fuel exploits: fly-TAPPING keeps ~750 px/s at a fraction of the fuel; wall-touch refuel is infinite — 3e1a5b0
- Source: WK-123 level-designer (scripted pilot). (a) Fuel drains only on frames fly is held, but tapping keeps ~750 px/s —
  a tapping pilot cleared Flight School 2 with 40-47% fuel left / lesson 3 with 31-38% (beats every fuel-limited Trials
  course). Fix: drain by thrust actually applied, or a minimum burn per press. (b) Pressing into a platform side while
  flying refunds +20 per touch several times a second (`fuel_per_bumper`/wall refund) = infinite fuel by any wall;
  add a per-surface cooldown. Both touch the fuel economy — game-designer ruling + prediction first (skill
  gottabounce-analysis-toolkit), then gameplay-programmer. Re-check Trials completability + brawl recovery after.
- Accept: tapping pilot no better than holding (fuel per metre within 10%); wall-hugging can't exceed +20 per 1 s;
  WK-123 recordings still pass; brawl recovery telemetry unchanged within noise.
- Area: brawl | trials (fuel economy) · Owner: game-designer (spec done) -> gameplay-programmer
- Spec: `docs/specs/wk128_fuel_exploits_2026-11-14.md` (5a246e0).
  - Relight bill for tapping (capped at 0.20 s).
  - A surface pays once per real bounce.
  - Bumpers pay only on hard hits (≥ 900 px/s).
  - Bot refuel-dive change (§7.4, required).
  - No protected constants touched.
- Accept addition (re-rank #6, from WK-95f, merged): the §9 Trials sweep (g6 ORBIT, p4 cannon set, `s3_*`) also checks that every
  super-gated course still fails without X.
- Files: `Tuning.gd`, `Player.gd` (uncommitted in the tree now), `InputBot.gd` (§7.4). Its §9 CD feel check folds into WK-CD3.
- Status: in-progress (gameplay-programmer). WK-CD3 starts when this commits. `Player.gd` stays reserved for it until then (WK-26, the
  WK-37c hook, the living-goat half of WK-53).

### [ ] WK-129 [P2][S] `break_on: "super"` crates (super-only destructible) + Flight School "smash the crate" beat
- Source: WK-123. Crates break on any 900 px/s impact, so plain flight/dive breaks them. Add a super-only mode to
  DestructibleBlock and use it in lesson 2 per CD2's suggestion. Accept: recording — dive fails, super breaks it.
- Area: trials · Owner: gameplay-programmer (`DestructibleBlock`) + level-designer (`tut_02` JSON)
- Impact: teaches the super as a HIT (CD2-01's preferred fix). WK-123 already makes fly-only fail, so this is quality, not a hole.
- Status: open (on deck)

### [ ] WK-123b [P2][S] Finished (HOME) Trials players park/ghost so they never block partners (code-side CD2-02 fix)
- Area: trials · Owner: gameplay-programmer (`TrialsMode` / `Player`) · Source: WK-123 (7fe4ce4). The 4-lane JSON layout fixed Flight
  School. Other co-op courses still share columns.
- Evidence: CD2-02 (a HOME P1 reversed P2's super from −2,339 to +518 px/s; `tools/out/cd2/`). Not yet reproduced outside Flight School:
  **unverified** for the other courses.
- Do: WK-CD3 re-judge (3) says whether co-op blocking still shows anywhere. If not, this goes to Won't do. If it does, a HOME goat parks
  (frozen, non-colliding, celebrating) or loses player-vs-player contact in Trials.
- Accept: a 2P co-op recording on a shared-column course: P1 HOME is parked and P2's super reaches the ring.
- WK-CD3 §3: "structurally addressed" in Flight School (four rings 600 px apart, one lane each), but CD3 ran it solo, so co-op blocking is
  **not verified** anywhere.
- Status: open (unverified). Before any build: a qa-playtester 2P co-op check on one shared-column course (e.g. `s3_tap_in` or
  `n2_slalom`). No blocking seen -> Won't do with the frames.


### [ ] WK-108b [P1][M] Sports bots round 2: keeper stickiness, fast-ball re-plan, goal-mouth crowding, BOWL own goals
- Also check (lane L, WK-120 run): CPUs seen flying across the net into the other half in a 2V2 Dropshot match
  (`tools/out/wk/WK-120_10*.png`) — confirm whether Dropshot bots respect their side.
- Source: WK-108 report (ee80867, tools/out/wk/WK-108_sports_bots.json). 70-80% of remaining own goals = chaser on the
  wrong side of the ball flying back toward its own goal (re-plan every 0.28 s at L3 while the ball moves ~300 px).
  Keeper presence 12% vs 70% target — keeper becomes chaser the moment it challenges (make roles sticky / hysteresis).
  THE BOX after-recording ~4.5 s: three goats in one goal mouth while the ball rolls mid-floor (role/target bug).
  THE BOWL own goals 21.5 -> 26.3%. Stuck/min 36.7 -> 42.5 — inspect episodes (likely wide loops).
- Accept: 32-run batch own goals <= 15%, keeper presence >= 50%, no goal-mouth stacking in recordings, stuck <= before.
- Area: sports (bots) · Owner: gameplay-programmer · Files: `InputBot.gd`, `SportsMode.gd` (+ a `Tuning.gd` block)
- Impact: CPU teammates still score on you (own goals 21.5 % of goals), and there's no keeper to beat. 2v2 with a friend against CPUs is the
  most social format in the owner's fun mode.
- Keep the PROTECT list, including `SUPPORT_HOLD_FRAC` supporter logic and the 2.67 s restart.
- Merged CD3-03 (re-rank #7): `tools/out/cd3/rb/end.png` reads "WINNING GOAL · OWN GOAL BY ZIGGY". The CPU teammate scored 2 own goals in
  an 8-goal match (2 of 19 goals across two CD3 matches, 10.5 %). Losing on your bot partner's own goal is the most "this game is dumb"
  moment at a couch. **Accept addition:** in the batch, 0 CPU own goals in the final 2 points of any match, OR a goal-mouth clear rule (a
  bot inside its own goal third never strikes the ball toward its own goal; it clears wide), checked in a WK-93 recording.
- Status: open. Next-10 #4 after re-rank #7, lane S, after WK-131. Files `InputBot.gd` + `SportsMode.gd`: both are held by WK-135 until it
  commits. Diagnosis can start any time; code lands after WK-135. Its 32-run batch queues behind WK-135's batch for the headless slot.
  Never measure at the same time as WK-109 (one sports variable at a time).


### [ ] WK-127b [P2][S] Bot stuck 1.4x after WK-127: hopping on the_ascent's top trampoline chasing targets below
- Source: WK-127 (tools/out/wk/WK-127_measure.json). Bots that used to die in the sky lid now brake and hop in place on
  the top tier. Needs a "way down past the top trampoline" route. Blocked-ascent rise is mostly the detector counting
  legit fall-arrests — consider excluding braking arrests from `_mh_blocked_ascent`. Accept: stuck <= 1.1x pre-WK-127.
- Area: brawl (bots) · Owner: gameplay-programmer · File: `InputBot.gd`
- WK-CD3 did not check the_ascent. Folded in from WK-126 (closed): in `tools/out/cd3/rec_ghost_islands/follow3.png` f520-f548 one bot
  hovers almost in place for ~1 s while its target is above it. Watch for it in the same pass.
- Status: open (on deck after re-rank #7). Lane S (`InputBot.gd`) after WK-108b.


### [x] WK-37c [P1][S] Ghost goats follow-ups: bot-ghost stacking, art-director look pass, faintness on wide cameras — ee46c22
- Source: WK-37b (1186bcf). T11 FAIL: two bots eliminated at the same spot start stacked (200 px spacing 72-93% vs 90%).
  T9/T10: art-director grade per docs/briefs/ghost_goats_2026-11-14.md R1-R8 — ghosts are faint specks on the wide
  islands_void camera (tools/out/wk37_ghosts_live.png); faded jetpack until bespoke ghost art. BAAA! bubble can sit over
  a living goat. Ghost over a platform can't puff (dud wisp only). Public Player.apply_surface_bounce() hook.
  T12-T15 (human-sim kingmaker, frame time, felt pass) -> next CD playthrough.
- Accept: T11 spacing >= 90%; art-director Ship; ghosts identifiable in a 4-player recording at zoom 0.46.
- Area: brawl (ghosts) · Owner: gameplay-programmer + art-director
- Files: `GhostDirector.gd`, `GhostGoat.gd`, `GhostPuff.gd`, `GhostBot.gd`, `ghost*.gdshader`, ghost `Tuning.gd` block. The public
  `Player.apply_surface_bounce()` hook touches `Player.gd`: do that sub-item after WK-128 commits, or leave it for last.
- Coordination: WK-53 (lane A) must NOT edit `GhostDirector.gd`. It listens to `EventBus.bleated`. This item owns the ghost files.
- If WK-CD3's T15 felt pass reports ghosts as clutter or too faint, fold its tuning into this item (spec fallback: `ghost_alpha` 0.40 -> 0.32,
  then `ghost_near_radius`).
- Status: open. Next-10 #3 after re-rank #6, lane G. Depth-first: this finishes the ghost slice that just shipped.


### [x] WK-53b [P2][S] Living-goat taunt (Player.gd hook) + ScoreScreen taunts — 4ca9472
- Source: WK-53a. Hook: Player._physics_process right after `var intent = provider.poll()` (~l.548), before stun
  clears it: `if intent.taunt and not _dead: EventBus.bleated.emit(<player index>, false)`. AudioManager handles living
  bleats + rate limit. ScoreScreen taunts need PartyMatch to poll each human's taunt during STAGE_END/SCOREBOARD.
  After WK-128 releases Player.gd.
- Status: done 4ca9472 (living taunt: J / pad Y, BAAA! in goat colour + bleat, rate-limited, bots silent; rendered + recording).
  The ScoreScreen taunts and the bleat-on-fire moved to WK-53c.

### [x] WK-132 [P1][S] Bounce SFX hog the voice pool (~19/s, 7-14 of 14 voices, 0.95 s ring) and silence other sounds — 7764470
- Source: WK-53a sound-designer. Cap concurrent bounce voices (~5) and/or shorten the bounce tail; smash/KO/bleat must
  never be starved. Owner: sound-designer. Accept: busy-arena run (vortex/pinball) — 0 dropped priority sounds.


### [>] WK-133 [P1][M] Singularity: all four bots get pinned to the black-hole core bumper and the stage stalls — merged into WK-135
- Source: WK-132 sound-designer (screenshot: 4 bots squashed on the core, ~100 surface_bounced/s at 38-95 px/s).
  Gameplay bug (bot recovery vs radial gravity + bounce core from 93b5357). Owner: gameplay-programmer (bots/gravity).
  Accept: 40-stage Singularity batch — no stage with all bots stationary > 3 s; recording shows normal fighting.
- Status: merged into WK-135 (re-rank #7). The WK-135 spec §7.6 closes it with WK-135a + BR-135 + C4; its Accept is folded into §9 B.
  Close it with WK-135's commit hash once §9 B passes.

### [>] WK-134 [P2][S] `surface_bounced` fires every physics tick of resting contact (not just real impacts) — merged into WK-135
- Source: WK-132. Audio now filters it, but every other listener (FX, telemetry, fuel?) gets the flood — emit only on
  impacts above a speed threshold or on contact-begin. Check fuel refund + Juice don't depend on the flood (WK-128!).
- Status: merged into WK-135 (re-rank #7). Spec §7.6: no emit threshold; close it when §9 A shows <= 12 `surface_bounced` per
  goat-second in every probe and refunds no longer depend on contact rate.


### [x] WK-37d [P2][S] Ghost identity + islands_void faintness + art-director regrade — b76d36f
- Source: WK-37c. R3: which bot ghost is which fails (no P#/name pip on bot ghosts; horns too small at ~30 px) — add a
  small name/P# tag to ghosts in the owner colour. islands_void: ghosts faint on the bright field (design call: base
  opacity or apply the wide-camera boost earlier than zoom 0.46). P1 pip sits on a living goat when its ghost is just
  below (PlayerPips). Art-director regrade with tools/out/wk37c_R1_sheet.png etc. Move ghost consts into Tuning.


### [ ] WK-135 [P1][M] Bumpers are standable (bodies come to rest on them — INV-11 violation, WK-128 spec finding E17)
- Source: WK-128 build (tools/out/wk/WK-128_*). Bodies rest on bumper tops (move <0.01 px/s); resting contact repeats
  every tick. With refund gates ON this hard-locked stages (0-fuel bot pinned on Singularity's bumper core forever); it
  is also the root of WK-133 (bots pinned to the core) and the surface_bounced flood (WK-134). Fix: minimum bounce
  speed on bumpers (physics change — game-designer prediction first; protected bounce constants untouched). Unblocks
  WK-128 part (b) (once-per-real-bounce refund + bumper hard-hit gate, built but OFF) and the sports economy ruling
  (sports ran on ~146 bumper refunds per bot-minute from grinding walls/ceilings).
- Accept: A9 probe — nothing rests on a bumper; Singularity 40-stage batch with no hangs; then re-run WK-128 part (b).
- Spec: `docs/specs/wk135_bumper_min_bounce_2026-11-15.md` (6e5d936). Phases: 135a kick floor; 135b face classes + BR-135 bot pin
  breaker + liveness valve; phase 3 = WK-128b refund gates ON + 135c sports ball-touch refund. Closes WK-133 and WK-134 (merged).
- Files: `BounceResolver.gd`, `Player.gd`, `InputBot.gd`, `SportsMode.gd`, `PartyMatch.gd`, `Tuning.gd` (no level JSON).
- Status: in-progress (lane P, gameplay-programmer, scratch copy, port 9105). It holds the files above until it commits (see In flight).
  WK-CD4 re-judges the refund side's feel (CD3 G3/G5 ran with the gates OFF).


### [ ] WK-136 [P1][S] A near-empty re-light always delivers at least ~0.1 s of thrust (WK-128 regression, CD3-04a)
- Area: brawl | trials (fuel feel) · Owner: gameplay-programmer (+ game-designer: invariant #14) · Source: creative-director WK-CD3
  CD3-04 (§5 G2). CD3 filed P2. The producer raised it to P1: it is missing feedback on a core action (FLY) at the worst possible moment.
- Evidence: in m1, 10 of 130 human boost presses (7.7 %) were billed down to `boost_relight_min_left` (1.0, leaving 0.76 after the same
  tick's drain). They delivered 3-5 thrust ticks (25-42 ms), where the pre-WK-128 counterfactual is 7-23 ticks. 4 of those 10 presses
  were followed by the presser's death within 3 s. 38 of 39 billed re-lights happened below 20 % fuel. With a healthy tank the bill is
  invisible (G1/G2 arrival times match bill ON and OFF to within 0.1 s).
- Impact: "the gauge shows a sliver, you press, and nothing happens", in recoveries and scrambles. It also feeds WK-20d's self-KO share.
- Do: cap the bill so a re-light always delivers >= ~0.1 s: raise `boost_relight_min_left` to ~3.0, or bill `min(bill, 0.5 x fuel)`.
  Feathering the last 10 % of a tank is worth almost nothing as an exploit. Re-check invariant #14 in `Tuning.gd`. Keep tapping dead with
  a healthy tank (WK-128 Accept). The HUD half (flash the billed chunk) is CD3-04b, merged into WK-99.
- Files: `Tuning.gd` (WK-128 block) and/or `Player.gd`. Lane P, after WK-135, which owns the same fuel ledger and changes the refund side.
- Accept: CD3's relight tracker (HumanSim) on the real build: 0 billed re-lights under 12 thrust ticks (0.1 s at 120 tps); the TapPilot
  A/B from CD3 (`tools/out/cd3/tap_ab.json`) still shows tapping costing more than holding; Flight School tut_02/03 feather still fails.
- Status: open. Next-10 #3, lane P after WK-135.

### [x] WK-66b [P1][M] TRIALS goal zones still draw the old code grid — 19d924a
- Source: WK-66a art grade (docs/audit/2026-11-15_wk66a_artgrade.md follow-up 2). Ten TRIALS courses use `goal_zone` with free-standing
  goals up to 700x620; WK-66a only builds the cage where the zone has `net_mouth_x`/`net_back_x`. Needs a free-standing goal layout
  (or a different "finish" visual) — art-director brief first. Lane V (ArenaRenderer/GoalZone).
- Area: trials | art · Owner: gameplay-programmer + level-designer, art-director grades from in-game screenshots (brief §9)
- Brief: `docs/briefs/trials_goal_2026-11-15.md` (d0a2da7). No new art: the Rocketball goal cage from WK-66a in a neutral objective gold,
  stretched to any rectangle. These are "ball goes here" goals (`objective.win = "ball_in_goal"`), so a finish ring would be wrong
  ("ring = you go here", GoalGate).
- Files: `GoalZone.gd`, `SportsNetArt.gd`, `levels/courses/{s3_*,t_ball_cannon,t_bank_shot}.json` (optional display-edge fields).
- Accept: the brief's §9 tests, art-director Ship.
- Status: open. Next-10 #6, lane V. Ready now (the brief has landed).


## P2 — visible polish gaps

### [x] WK-130 [P2][S] Per-agent automation port: parallel rendered games without hijacking or killing each other — 1a91a55
- Area: tooling · Owner: gameplay-programmer (tooling)
- Source: WEEKEND_LESSONS "Port 9090 is shared" (WK-111 accidentally reset another agent's match, 775338e) and "`stop_game.ps1` kills EVERY
  Godot process".
- Impact: not player-facing. It removes the single-game-slot bottleneck: builders verify in parallel instead of queueing, which is why
  re-rank #6 is organised in lanes.
- Did:
  - `--gb-port` / `GB_PORT` in the interaction server (0 = off).
  - `gbplay.py --port`.
  - `run_game.ps1 -Port` no longer kills every Godot (`-KillAll` is opt-in). `stop_game.ps1 -Port`.
  - Recordings bind no port.
  - Loop rule: ports 9101+ per agent slot (WEEKEND_LOOP). Lesson 1a657e3. The run-and-playtest skill is updated.
- Status: done 1a91a55. The producer filed this entry retroactively in re-rank #6 and closed it on the commit + loop/skill docs. Evidence
  check: the first multi-lane session. If two agents collide on a port or a run kills another lane's game, reopen.

### [ ] WK-85a [P2][S] Trials void reads as a lethal drop: Flight School lesson 1 fill band + lesson 4 floating props (CD3-06; split from WK-85)
- Area: trials | art · Owner: art pipeline + level-designer, art-director grade · Source: creative-director WK-CD3 CD3-06, plus the band
  CD1 and CD2 flagged under WK-85 (split out at re-rank #7 so the S that matters is pullable on its own)
- Evidence: `tools/out/cd3/fs_07_t4.png`: the bottom half of lesson 4 is flat pale green, with bushes and fences floating at pad height
  and no ground under them. The lesson says "touch every pad", but nothing says "falling = start over"; a newcomer reads green as grass.
  Lesson 1: `tools/out/cd1/46_trials_go.png`, `48_trials_after.png` (bottom ~35 % flat mint fill). Islands Void's Brawl band was lifted by
  WK-37d and is no longer the urgent half.
- Do: paint a readable drop under Trials courses (cliff edge, haze, a sky gradient below), and anchor or remove the floating props in
  `tut_04_fuel_run.json`.
- Files: `ArenaRenderer.gd`, `levels/courses/tut_01_first_flight.json`, `tut_04_fuel_run.json` (lane V, after WK-66b).
- Accept: lesson 1 and lesson 4 screenshots at 1080p show no flat fill band and no prop floating over nothing; a blind read says "you can
  fall here"; art-director Ship.
- Status: open (on deck #1, lane V after WK-66b)

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
- WK-CD2: still visible. The bottom third of Trials lesson 1 AND of Islands Void (a default Brawl arena) is flat mint fill. Part of CD2 gap #4.
  Split suggestion stands: the Trials/Islands Void fill band is the S worth pulling first; the tall-arena tiling can follow.
- WK-CD3: Islands Void's lift (WK-37d) helps in Brawl. Flight School lesson 4 is half flat-mint void with props floating over it (CD3-06).
- Status: open. **Split at re-rank #7:** the Trials fill band (lessons 1 and 4, CD3-06) is now WK-85a (P2/S, on deck #1, lane V). This
  entry keeps the tall-arena tiling and the tall themed platforms (on deck, after WK-85a).

### [x] WK-87 [P2][S] Trials objective panel never covers the goal ring — 843c6c2
- Area: trials/HUD · Owner: ui-ux-designer · Source: creative-director WK-CD1 (CD1-03)
- Evidence: `tools/out/cd1/48_trials_after.png` — Flight School lesson 1 "FIRST FLIGHT": the dark "1 of 2 HOME" panel sits top-centre,
  exactly where the ring ends up once the camera re-frames; only a green arc of the target shows.
- Impact: the very first Trials instruction is "fly up to the ring" and the ring is hidden. Every new player, lesson 1.
- Do: move the panel to a corner, or collapse it to a small chip after ~3 s (or reserve a top band via the `camera_focus_points`
  seam — camera rules are owner-ruled, so prefer the HUD move). WK-35 restyles the same panel later and must keep this placement.
- Accept (rendered): Flight School lesson 1 at BOUNCE+0 s and +4 s with 1 and 2 players: the goal ring is fully visible in both.
- Status: done 843c6c2. WK-CD2 verified: ring top-right, panel top-centre (`tools/out/cd2/43_t1_go.png`).

### [x] WK-88 [P2][S] One naming rule for every fighter in match text (CPU vs VEX vs "VEX — CPU") — a4955e7
- Area: HUD/brawl · Owner: ui-ux-designer (rule) + gameplay-programmer · Source: creative-director WK-CD1 (CD1-04, CD rated P3;
  producer rates P2: a couch group asks "who is Vex?") · extends the identity systemic (WK-08/WK-10, both done)
- Evidence: `tools/out/cd1/m1/f005_STAGE_END.png`, `m1/f029_STAGE_END.png`, `20_victory_4.png` — bot card/pip say CPU, banners say
  "VEX SURVIVES!" / "P1 +1 · P2 +1 · VEX +1", Victory says "VEX — CPU"; humans are "P1" in banners but "BUTCH P1" on Victory.
- Do: pick one rule for HUD, pips, banners, ScoreScreen and Victory (e.g. humans "P#" everywhere; CPUs "CPU" + goat colour, or
  "VEX (CPU)" everywhere). WK-76's "bot tag shows hero name" must follow whatever is chosen; Victory contrast stays in WK-42.
- Accept (rendered): 2H+2CPU Brawl: HUD card, stage banner, ScoreScreen row and Victory row name each fighter the same way (4 screenshots).
- Status: done a4955e7. Also governs the WK-106 scorer / OWN GOAL banner names. WK-CD2 verified: "PUFF" / "PUFF CPU" consistent across
  banners, pause chips and the victory plate (`tools/out/cd2/10_victory_b.png`).

### [~] WK-89 [P2][S] `round_stats` may under-record kills when LIVES > 1 (instrumentation — unverified, seen once) — attempted: WON'T DO: round_stats keeps multi-life kills (WK-20a step 0)
- Area: tooling/brawl · Owner: qa-playtester (repro) -> gameplay-programmer (fix if confirmed) · Source: creative-director WK-CD1 (CD1-06)
- Evidence (unverified): Grassy Expanse, LIVES 3, 63.5 s game time, final scores 2-0-5-1, but `round_stats[0].kills` held ONE entry
  (P1's self-fall at t=1). Seen once, not root-caused.
- Impact: not player-facing today, but WK-20a, WK-25 (ScoreScreen kill list), WK-55 and WK-57 all decide from `round_stats`; any
  non-default LIVES measurement would be wrong.
- Do: the repro runs at the start of the WK-20a session (one 3-lives stage, `kills` vs `scores` deltas). Confirmed -> fix; not
  reproduced in 3 stages -> Won't do with the numbers.
- Accept: 3 LIVES-3 stages where `round_stats.kills` count equals the sum of credited + self-fall score events (eval log).
- Status: wontfix (WK-20a step 0, ruling 3, fecb4a9). `round_stats` keeps multi-life kills; CD1 read it mid-stage.

### [x] WK-38 [P2][S] Gate the 9090 automation server behind `--gb-dev` AND update run_game.ps1 in the SAME commit; version label only on title + Options — ab11c61
- Sources: C-28, CC-12.1, CC-8.4 · **WARNING**: landing the gate without `run_game.ps1` passing `-- --gb-dev` breaks gbplay and every later rendered QA — one commit, verify both
- Area: tooling · Owner: gameplay-programmer · Deps: none (do not interleave with a running QA session)
- Accept: `PLAY GOTTABOUNCE.bat` run -> nothing listening on 9090 (`netstat`); `tools/run_game.ps1` -> "Interaction server UP on 9090"
  and a gbplay screenshot succeeds; "v0.1" absent from ModeSelect/Lobby/ArenaSelect screenshots.
- Re-scope note (re-rank #6): WK-130 (1a91a55) added `--gb-port` / `GB_PORT` with 0 = off. The gate may now shrink to "the player build
  defaults to port 0 unless `run_game.ps1` passes one". Re-read the WK-130 server code when this is pulled, and keep the "same commit as
  run_game" rule.
- Status: open

### [x] WK-39 [P2][S] Hide the mouse cursor on pad/keyboard input and always in gameplay; hover focuses only after real motion — ab11c61
- Sources: C-26, CC-2.4, CC-12.2
- Area: menus · Owner: gameplay-programmer · Deps: WK-03
- Accept (rendered): screenshot mid-match shows no cursor; resting cursor over a sliding-in screen does not steal pad focus.
- Status: open

### [x] WK-40 [P2][S] "B BACK" is a glyph chip, not a focus stop; fix ModeSelect back wiring — ab11c61
- Sources: C-24, CC-5.5, CC-5.2
- Area: menus · Owner: ui-ux-designer · Deps: WK-29 (glyph)
- Accept (rendered): pad focus never lands on a back button on ModeSelect/ArenaSelect/Options; mouse click on the chip goes back.
- Status: open

### [x] WK-42 [P2][S] Victory screen: hide combat HUD, consistent button copy/size, readable CPU name — b2ac978
- Sources: R-28
- Area: menus · Owner: ui-ux-designer · Deps: WK-14
- Evidence: tools/out/cd_audit/25_victory_settled.png
- Accept (rendered): no HUD corner cards on Victory; buttons equal width, "QUIT TO MENU" copy; winner name contrast >= 4.5:1.
- WK-CD1: "VEX — CPU" in purple over the yellow burst is hard to read (`tools/out/cd1/20_victory_4.png`) — contrast stays here; the
  naming rule is WK-88. QUIT TO MENU still lands on the title and clears the lobby (R-26): the label must match the destination.
- WK-CD2: the combat HUD cards are still visible behind the victory screen (`tools/out/cd2/10_victory_b.png`); naming is now consistent (WK-88).
- WK-CD3: still visible behind both victory screens (`tools/out/cd3/m1/13_MATCH_END_late.png`, `m2_end.png`).
- Status: open. Next-10 #9, lane U after WK-13. The button-style half may lean on WK-14; ship the HUD-hide half regardless.

### [ ] WK-43 [P2][S] Trials co-op polish: offset spawns, "GO!" not "FIGHT!", banner backplates, longer first lesson
- Sources: R-29
- Area: trials · Owner: level-designer + ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/39_trials_1s.png, 38_trials_circuits.png, 41_contact.png
- Accept (rendered): 2P course 1 spawns visibly apart; circuit confirm reads "GO!"; COURSE CLEAR has an outline/backplate; course 1 takes >= 4 s of flying for a human-style drive.
- WK-CD1: the Trials circuit-select footer also says "(A) FIGHT!" in the co-op mode (`tools/out/cd1/44_trials_select.png`) — front-end copy is in scope.
- The sports court select has the same "FIGHT!" footer (WK-117, WK-98 SP-16): do the footer copy for both modes in one pass.
- WK-CD2: the co-op blocking bug (CD2-02, same-column spawns + HOME goats colliding) went to WK-123 with the director's assignment, not
  here. If WK-123 parks HOME goats, the offset-spawn half here is still wanted (it is about the start, not the finish). Coordinate: WK-123
  edits the same Flight School JSON.
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
- Merged CD3-07 (re-rank #7): `tools/out/cd3/rb_01_lobby.png`: "FLAIR UNLOCKED BUBBLEGUM JETSTREAM" in outline text with no panel, across
  the P2 and P3 names, and it doesn't say whose unlock it is. It clears in ~2 s. Accept addition: the card names (or colours) its owner
  and never covers a lobby slot's name.
- Status: open (on deck, lane L after WK-120 + WK-125: same `HerdLobby.gd`)

### [x] WK-53 [P1][S] Taunt / bleat sample — (a) ghost bleats done 2fa94cd; (b) living taunt pending: (ghost bleat now, living-goat taunt after WK-128) — raised P2 -> P1 at re-rank #6 — 4ca9472
- Sources: D-15 · Binding: pad Y [3] / keyboard per CC-2.2 (Y is unused in gameplay per CC-1.1)
- Area: brawl/audio · Owner: sound-designer + gameplay-programmer · Deps: none · Note: no bleat in assets/sfx; source a CC0 one (ruling b2). The bleat is shared with WK-45 (lobby lock) and WK-37 (ghost quack)
- Accept: taunt -> `last_sfx` starts "bleat_" within 1 frame in COMBAT and on ScoreScreen; 10 presses/s -> <= 3 sounds; "BAAA!" puff in colour (screenshot).
- Raised P2 -> P1 (re-rank #6, depth-first): WK-37b shipped ghost goats with a SILENT bleat. The `taunt` action (pad Y / J),
  `InputIntent.taunt`, the rate limit and `EventBus.bleated(player_idx, ghost)` all exist; only the sample is missing. The ghost spec
  says "T15 Q5 can't pass until WK-53 lands" (`docs/specs/wk37a_ghost_goats_2026-11-14.md`). The dead are ~half a weaker player's
  evening (CD2: 48 % of combat frames), so this finishes CD2 gap #1.
- Split inside the item:
  - (a) **Now:** source a CC0 bleat per hero (ruling b2; licence in `assets/sfx/LICENSES.md`). `AudioManager` plays it on
    `EventBus.bleated`. Do not edit `GhostDirector.gd` (lane G owns it).
  - (b) **After WK-128 commits:** the living-goat taunt reads `intent.taunt` (`Player.gd`, or a `PartyMatch` listener) and emits
    `bleated(idx, false)`. Commit (a) alone if (b) is still waiting.
- Accept addition for (a): a GHOSTS ON stage, ghost presses Y -> `last_sfx` starts "bleat_" within 1 frame, rate limit holds.
- Status: open. Next-10 #2 after re-rank #6, lane A (`AudioManager.gd`, `assets/sfx/`). WK-26 follows in the same lane.

### [ ] WK-54 [P2][S] Rotating tips + per-player legend that holds until each human has used FLY and SUPER (cap 12 s)
- Sources: D-13b, D-13c, D-25b
- Area: HUD · Owner: ui-ux-designer · Deps: WK-15, WK-29
- Accept (rendered): fresh save, 2 humans: legend persists until both used FLY + SUPER (logged) or 12 s; tips suppressed after 3 matches.
- WK-CD2 gap #2 "teach the game it now is" lists it after WK-123: once Flight School forces the super, this carries the lesson into Brawl.
- Status: open (on deck)

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
- Evidence: tools/out/cd_audit/44_rocketball_courts.png, 50_dropshot_4s.png; WK-98 §4: all 8 Rocketball thumbs are the same dark
  stadium (`tools/out/sports/06_courtselect.png`).
- Merged WK-98 SP-17 (P3/S): the DROPSHOT **mode card** art is a goat spiking a beach ball into a soccer goal frame (contradicts "don't
  let it drop"), and its title sits ~30 px below its neighbours (`tools/out/sports/01_modeselect.png`). Re-cut with a net + sand (or edit
  the image) and align the title baseline. Separable S piece: can ship before the court cards.
- Accept (rendered): court select screenshots show illustrated cards matching Brawl/Trials quality; ModeSelect shows a Dropshot card
  with a net, title baseline level with its neighbours; art-director approval.
- WK-CD3 (CD3-09 cards half, merged re-rank #7): court-select thumbnails are still the old dark-stadium previews with half-empty cards
  (`tools/out/cd3/rb_04_court.png`).
- Status: open (kept P2 by WK-98 §4; on deck)

### [x] WK-66a [P1][M] Nets read as nets: Dropshot net panel (DOME's moving net visible) + Rocketball goal net sprite (WK-98 SP-13) — 2bd049c
- Area: art | sports · Owner: art pipeline + art-director (grade) + level-designer · Source: WK-98 SP-13, split out of WK-66 and raised
  to P1 (WK-98 §4). Re-sized: CD filed S, but it needs art generation, a draw hook over the existing bumper collider and an art-director
  grade, so M.
- Evidence: `tools/out/rec/wk98_ds_dome_2v2/frame00000436.jpg` (DOME net = dark steel column on the dark stadium, lost at couch
  distance); BEACH / CORAL COVE nets are a 30 px stack of white balls that reads as a pole; Rocketball goal mouths have no net
  (`tools/out/sports/evidence/sp_goal_moment_center.jpg`).
- Impact: the net is the one piece of geometry every Dropshot shot is about.
- Do: themed net sprite (mesh panel + bright top cord + posts) drawn over the existing collider (collision unchanged, PROTECT); DOME gets a
  moving-state cue (glow when the under-gap opens). Does not wait for WK-65 (readability, not style).
- Accept: art-director grade on a DOME frame and a BEACH frame at 1080p: the net is readable at couch distance; Rocketball goal shows a net.
- Status: open. Next-10 #10 after re-rank #6, lane V after WK-122 (`ArenaRenderer.gd`). The art generation (ChatGPT, style-ref'd) can start
  while WK-122 is still in the lane; only the draw-hook code waits.

### [ ] WK-66 [P2][M] Court in-game art: tiled crackable Dropshot floor, a real beach, frame-filling stadium (nets split to WK-66a)
- Sources: R-15 (in-game half) · art generation
- Area: art/sports · Owner: art pipeline + level-designer · Deps: WK-65 (shared style), WK-66a (net style)
- Evidence: tools/out/cd_audit/45_rocketball_1s.png, 51_dropshot_start.png, 52_dropshot_4s.png; WK-98 SP-12: every court uses the same
  dark stadium backdrop.
- Accept (rendered): SUNSET BEACH shows a beach; floor tiles visibly crack; no letterbox frame.
- WK-CD2 gap #4: still "a dark stadium in a flat letterbox, and SUNSET BEACH has no beach". The letterbox half is WK-122 (S, pull first).
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

### [x] WK-125 [P2][S] Lobby auto-joins the device that confirmed the mode, even when other players carried over — bbe6996
- Area: menus · Owner: gameplay-programmer (lobby builder) · Source: creative-director WK-CD2 (CD2-04, CD rated P3; producer P2: it is the
  owner's own complaint surface, "2 users using 2 controllers totally cant select their character")
- Evidence: from an empty lobby the confirming pad becomes P1 automatically. After P1 backed out of the Rocketball lobby (P2, P3 still joined)
  and confirmed DROPSHOT, P1's pad was NOT seated: its slot read "PRESS A TO JOIN" while the other two showed READY
  (`tools/out/cd2/30_ds_lobby.png`).
- Impact: one extra press plus a "why am I not in?" moment on every CHANGE SETUP / hold-B round trip into another mode.
- Do: on lobby entry, auto-join the confirming device if it is not already seated, whatever else carried over (WK-05's rule, applied always).
- Accept (rendered): P1 holds B out of a Rocketball lobby with P2 + P3 joined, confirms DROPSHOT on its pad: lobby shows P1 seated PICKING
  next to P2/P3; empty-lobby auto-join still works; a device that is already seated is not duplicated.
- Status: open. On deck #7 after re-rank #6, with WK-120 (one lobby pass, lane L).

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
- WK-CD2 gap #2: "then consider a short BRAWL SCHOOL, because nothing teaches the actual Brawl win condition". The CD says "consider", after
  WK-123. It stays P3 (widening, new content, depth-first). Revisit at WK-CD3 once Flight School teaches the super.
- Accept: 4 courses complete via injected human-style input; rendered screenshots.

### [ ] WK-79 [P3][S] Audio mix pass (loudness numbers, menu vs hit weight)
- Sources: R-33 · Owner: sound-designer · Deps: WK-45
- **BLOCKED (partial):** the subjective "does it sound good" judgment needs a human ear; do the numeric loudness/headroom part only.
- Accept: per-bus loudness report; no SFX clipping; music ducks under KO stings (eval bus levels).

### [ ] WK-101 [P3][M] BLOCKED (GPU) Residual stage-load spike (62-72 ms) at STAGE_INTRO
- Area: perf · Owner: gameplay-programmer · Source: performance-analyst docs/audit/2026-11-14_perf_wk91.md rec 4
- Evidence: 180 s recorder on the fixed build: 6 frames over 33 ms, 0 over 100 ms; worst 62-72 ms at STAGE_INTRO (Twin Moons,
  Singularity). In-tree `_load_stage` costs 17-54 ms, plus respawn + HUD work in the same tick.
- Impact: low. The spike hides behind the stage intro card, and the game otherwise holds 120 fps. It would matter on a slower couch PC.
- Do: build the next level off-tree during SCOREBOARD and swap it in at STAGE_INTRO, or spread the load over 2-3 ticks.
- Accept: same 180 s recorder run, screen on: 0 frames over 33 ms at STAGE_INTRO across 15 stages including Singularity.
- Status: open. BLOCKED (GPU) since re-rank #7: frame-time numbers are invalid under software rendering until the owner reboots.

### [ ] WK-102 [P3][S] Perf hygiene: static `_warn_once`, diagnostics skill frame_time note, golden draw-call count
- Area: tooling · Owner: gameplay-programmer (tooling) · Source: performance-analyst docs/audit/2026-11-14_perf_wk91.md recs 5 + 6
- Evidence: `_warn_once` is per renderer instance, so every stage load prints the missing-tuft / missing-flower `push_warning` with a full
  backtrace (17x in one session). The diagnostics skill §2 says `frame_time` is the last frame's process time; Godot actually reports the
  max over ~1 s including the render/swap wait (it read 511 ms on 35 ms frames). The golden draw-call count is still 28; current arenas
  draw ~75-80.
- Impact: not player-facing. Log noise hides real errors in QA stderr; the wrong `frame_time` reading misled the WK-91 hunt.
- Accept: a 15-stage run prints each missing-decal warning at most once; skill §2 corrected; golden updated to the measured value.
- Status: open

### [ ] WK-37f [P3][S] Ghosts never hide behind terrain (CD3-08)
- Area: brawl (ghosts) · Owner: gameplay-programmer (+ art-director glance) · Source: creative-director WK-CD3 CD3-08
- Evidence: `tools/out/cd3/m1/03_ghost1_s1.png`: the P2 ghost is parked under the main floor; the platform art hides its body and only its
  tag peeks out below. CD3's driver steered it there, but a real player will too.
- Do: draw ghosts above terrain (z-order), or push them out of solid geometry the way the bot-ghost spacing does.
- Files: `GhostGoat.gd` / `GhostDirector.gd` (lane G).
- Accept: a ghost steered into a platform renders on top (or is pushed clear) in a rendered screenshot; ghost spacing and tags unchanged.
- Status: open (on deck, lane G)

### [ ] WK-66c [P3][S] Dropshot net: taller-tape re-art (contingency)
- Also from WK-66b: Trials solved glow barely visible (raise `trials_goal_glow_pad` to several hundred); background parallax
  fences show through the gold-goal mesh (pocket shade 0.16 too light); Ball Cannon goal starts off-screen (camera).
- Source: WK-66a F5 blind read: best guess "volleyball net" but "reads more like a lattice pole at 480 px; I got net from the setting".
  Only do it if WK-CD3 or a later cold read calls it a pole/tower: re-art D1 frame with a ~26 wpx tape (brief §3), or raise
  `net_tape_scale` to 1.6 first. Also capture one WK-27 colourway frame for test 7.
- Status: open (contingency). WK-CD3 played a snapshot (ac7b4f0) from before the nets landed, so it did not judge them. Carry to WK-CD4.

### [ ] WK-53c [P3][S] Taunts on ScoreScreen/stage-end + bleat layered on super fire (sound-designer call)
- Source: WK-53b/WK-26 build report. PartyMatch must poll humans' taunt during stage-end/scoreboard; D-07's bleat-on-fire was
  skipped (supers are frequent; may drown the taunt). Also: wind-up keeps normal pitch through hit-stop slow-mo; "!" banner-hide
  never triggered in the recording (unproven); BAAA! stays where shouted and can overlap a fast-moving shouter.
- Files: `PartyMatch.gd` (held by WK-135 until it commits), `AudioManager.gd`, `ScoreScreen`.
- Status: open (P3). WK-CD3 could not judge audio by ear. After WK-135 (`PartyMatch.gd`).

### [~] WK-126 [P3][S] (unverified) Bots trace tight loop-de-loops around a moving target instead of overshooting and lining up again — attempted: WON'T DO per WK-CD3 §6 (reads as a close dogfight at follow zoom)
- Area: brawl (bots) · Owner: qa-playtester (re-check) -> gameplay-programmer · Source: creative-director WK-CD2 §2 Q5 (watch item)
- Evidence (unverified in motion): tight orange loops around the target on `tools/out/rec/cd2_bots_islands/traj.png`. Not yet seen at
  gameplay zoom; may read as buzzing flies, or not at all.
- Do: in the next bot recording (WK-108's or WK-CD3's), watch at --follow zoom. Build nothing unless the loops read badly at gameplay zoom.
- Accept: a --follow recording judged; either a filed fix with a loop-count metric, or Won't do with the frames.
- Status: wontfix (re-rank #7). WK-CD3 §6 judged it at follow zoom: `tools/out/cd3/rec_ghost_islands/traj.png` still shows the curls, but
  `follow3.png` f460-f510 reads as a close dogfight around a bush with supers landing, not buzzing flies. Aim stays smooth (14 windows,
  0 over the cap, 0 jumps over 15°, `aim_report.png`). The one watch (a bot hovering ~1 s under its target, f520-f548) moved to WK-127b.

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
- WK-93 match recorder · WK-94 smooth bot aim · WK-96 pendulums smash + real swing · WK-97 black hole behind players — 9a2ee3f
- WK-15 every-mode legend + rule line · WK-88 one name per fighter · WK-92 font follow-ups · WK-36 off-screen bubbles · WK-27 sports
  team lobby (re-verified in play by WK-98) — a4955e7
- WK-95 OWNER RULING: steerable normal flight, super = attack, bots fly to travel (M1-M9 pass) — 4135884 (follow-ups WK-95e)
- WK-98 sports deep-dive (verdict FIX; SP-01..22 triaged into WK-104..120, WK-66a and merges) — 32c5eb7
- WK-87 Trials panel avoids the goal (re-verified by WK-CD2) · WK-100 display-off warnings — 843c6c2
- WK-104 ball frozen until GO + fair toss ((b) kickoff Accept unmet, moved to WK-108 b2) · WK-105 sports sounds + hit reaction · WK-106 scorer
  / OWN GOAL / assist banner — 5f34080
- WK-95e bot regressions fixed + HOT rule ON (director ruling; traversal supers 9.8 %) — a362ad4
- WK-121 master limiter (≤ −1 dBFS) + sports hole-fall sand puff + Dropshot tile sounds — a1ada05
- WK-107 LONG HAUL re-cut to 3200x1800, both goals on screen — 834ecda
- WK-CD2 creative-director cold playthrough #2 (verdict FIX, much closer; flight SHIP; CD2-01..06 triaged) — aa78b3e
- WK-18 28 px floor for every player-facing text + lobby L6 medallions — 2aa8f87
- WK-20a who-wins measurement — 2721c7c; rulings — fecb4a9 (self-KO = Ra; WK-20b + WK-89 Won't do; new bot item WK-127)
- WK-20c self-KO costs 0 by default + SELF-KO -1 RULES toggle + OOPS! — 6f4f51b
- WK-123 Flight School lessons 2-3 need the super, 4-lane co-op, Refuel Ridge gap — 7fe4ce4 (follow-ups WK-123b, WK-128, WK-129)
- WK-108 sports bots route-around / track-back / keeper / cross — ee80867 (partial Accept; WK-108b, WK-131)
- WK-25 KO credit pop + ScoreScreen kill list — 2eef67e
- WK-124 sports goal -> GO restart 3.27 -> 2.67 s — 540f863
- WK-127 bots stop self-KOing (37.8 -> 17.8 %), median bot stage 8.4 -> 13.8 s — 25e2c86 (follow-up WK-127b)
- WK-111 sports victory screen: team celebration, per-player stats, MVP — b4eb885
- WK-37 ghost goats: spec 28ddce0, art 53389a8, build 1186bcf (follow-ups WK-37c, WK-53 bleat)
- WK-130 per-agent automation ports (parallel rendered games) — 1a91a55
- WK-122 sports courts painted edge-to-edge (CD3: letterbox gone on CENTER PITCH) — e3e11d5
- WK-34 panel kit A — 8051d4f · WK-35 panel kit B + WK-34 review fixes (CD3: navy panels gone from every screen it saw) — 9498e0f
- WK-132 bounce SFX voice-pool cap — 7764470
- WK-37c ghost follow-ups — ee46c22 · WK-37d ghost identity tags + islands_void lift — b76d36f · WK-37e ghost tags in the human style —
  6c0d612 (CD3 T15 felt pass: no FIX trigger)
- WK-128 relight bill ON, refund gates OFF pending WK-135 — 3e1a5b0 (CD3 §5: SHIP; near-empty fix WK-136)
- WK-66a sports nets: Rocketball goal cages + Dropshot net — 2bd049c (Dropshot net contingency WK-66c; Trials goals WK-66b)
- WK-53b living-goat taunt + WK-26 super-aim wind-up sound and target "!" — 4ca9472 (follow-ups WK-53c)
- WK-CD3 creative-director cold playthrough #3 (verdict FIX, close to SHIP; CD3-01..09 triaged at re-rank #7) — ee892a5

## Deferred / Cut (this weekend) — every finding not covered by an item above
- **WK-126 (bot orbit loops)** — WON'T DO (re-rank #7, WK-CD3 §6): reads as a close dogfight at follow zoom, aim report clean. The
  ~1 s hover watch moved to WK-127b.
- **WK-133 / WK-134** — merged into WK-135 (its spec §7.6 closes both; acceptance in §9 A/B).
- **CD3-01 knockback 1.0x arm** — diagnostic only inside WK-20d: `dmg_launch_mult` is OWNER-RULED (DECISIONS 2026-07-19) and cannot ship
  in the owner's absence. If it alone hits the target, record it as an owner question.
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
- **WK-20b (Lv0 sting/hitstun gate)** — WON'T DO (WK-20a ruling 2, fecb4a9): the +25 % knockback's graze effects are outcome-neutral.
  The owner's array is untouched.
- **WK-89 (`round_stats` multi-life kills)** — WON'T DO (WK-20a ruling 3, fecb4a9): not reproduced; CD1 read it mid-stage.
- **WK-95f (Trials sweep under the new flight)** — merged into WK-128's §9 Trials sweep (re-rank #6). Reopen as its own S only if WK-128 ends `[~]`.
- **Lobby review L5 painted ribbon art (E.11)** — optional art generation; cut this weekend. The code-side banner polish is WK-84.
- **Lobby review builder deviations accepted by ui-ux** — READY stamp over the portrait (keep, -6°); interim re-pitched lobby
  sounds until WK-45. Not cuts, recorded so nobody re-opens them.
- **D-31 (new powerups)** — widening; after WK-49/71/72 make the existing 7 read.
- **D-04 (HYBRID scoring as default)** — needs owner reversal; recorded as a candidate only (option ships in WK-64).
- **D-29 (freeze sports widening)** — adopted as policy, no item.
- **R-28 (winner podium with 2nd-4th poses)** — nice-to-have, needs pose art; cut this weekend.
- **R-22 (Video / Language tabs)** — no localisation planned; fullscreen already exists; cut.
- **C-16 note to CD (blurbs promise traits)** — handled by the WK-32 decision.
- **WK-98 SP-21 reorder the mode cards (DROPSHOT before ROCKETBALL)** — the card ORDER is owner-set (WK-13, STATUS 2026-07-19 menu
  rework). Won't do unless the owner reverses; the FORMAT default and optional ribbon ship in WK-120.
- **WK-98 SP-04 lower the sports camera floor** — not forbidden by the owner camera rules (they set no zoom-out floor), but the
  geometry fix (WK-107) is preferred; the lower floor is WK-107's documented fallback only.
- **WK-CD2 CD2-05 (a 1080p `gbplay screenshot` stalls the game ~1.25 s)** — a tooling lesson, not a game item (director 2026-11-14).
  Recorded in this file's "Measurement validity" note; the director adds it to WEEKEND_LESSONS beside the existing `save_png` ~900 ms
  note. The optional `gbplay screenshot --half` flag is not filed; file it only if a QA pass is blocked by the stall.

## Coverage index (source -> item)
C-01 01 · C-02 01 (usage in 05-07) · C-03 05,06 · C-04 05,06,04 · C-05 03,04 · C-06 01,09,11 · C-07 28 · C-08 08 · C-09 10 ·
C-10 19,44 · C-11 29,30 · C-12 15,33 · C-13 14 · C-14 11 · C-15 02 (+Deferred) · C-16 27,32 · C-17 06,07 · C-18 09 · C-19 01 ·
C-20 09,33 · C-21 05,46 · C-22 45 · C-23 29 · C-24 40 · C-25 07 · C-26 39 · C-27 18 · C-28 38 · C-29 07 · C-30 44 · C-31 27 ·
C-32 17 · C-33 67 · C-34 05 · C-35 13 · C-36 68
R-01 01 · R-02 05,06,04 · R-03 02 · R-04 08,47 · R-05 10,47 (+Deferred) · R-06 25,31 (+Deferred) · R-07 20,21,37,56 (+Deferred) ·
R-08 12 · R-09 09 · R-10 17,18 · R-11 34,35 · R-12 16 -> 106 · R-13 07 · R-14 27,32 · R-15 65,66 · R-16 07 · R-17 10 · R-18 13 (+Deferred) ·
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
WK-98 sports deep-dive (2026-11-14_sports_deepdive.md): SP-01 105 · SP-02 104(a) · SP-03 106 (supersedes 16) · SP-04 107 · SP-05 104(b) ·
SP-06 108 · SP-07 109 · SP-08 110 · SP-09 111 · SP-10 112 · SP-11 113 · SP-12 114 (gates), 115 (new courts), 116 (LONG HAUL bumpers lever) ·
SP-13 66a (split from 66, raised P1) · SP-14 99 (extended to sports) · SP-15 116 · SP-16 117 (+43 footer) · SP-17 65 · SP-18 35 · SP-19 118 ·
SP-20 119 · SP-21 120 (+Deferred: card reorder) · SP-22 113 · §2 PROTECT list + §6 post-WK-95 re-checks -> SPORTS section header ·
§4 keep/raise: 16 -> 106, 27 verified done, 35 kept P1, 65 kept P2, 66 nets raised (66a), 99 extended, 86 kept closed
WK-CD2 (2026-11-14_cd2_playthrough.md): CD2-01 123 · CD2-02 123 (+43 note) · CD2-03 108 (b2; reopens 104(b)) · CD2-04 125 · CD2-05 Deferred
(tooling lesson) · CD2-06 35 · §2 Q5 bot loops 126 (unverified) · §1 pendulum chain-on-cloud 103 · soft regressions: restart 3.27 s 124,
Dropshot rally 14.5 s 116 (watch) · re-judged: 20a (CPU share, stage length, first-death time), 21/41 (budget met; stage length is the fix),
23 (delivered), 25 (still wanted), 37 (48 % dead frames), 85, 86, 87, 88, 42, 13, 120, 95/95e(e) (flight SHIP), 95f (d) -> 123 · §5 gaps:
1 -> 20a/20c/20b/37, 2 -> 123/54/78, 3 -> 108/124/111/109/110, 4 -> 34/35/85/66/66a/122, 5 -> 18/31/25/26/47
Producer-filed without a source doc: WK-121 (retroactive entry for a1ada05) · WK-130 (retroactive entry for 1a91a55)
WK-20a results (2026-11-14_wk20a_results.md) + rulings fecb4a9: self-KO Ra -> 20c (done) · knockback side effects -> 20b Won't do ·
round_stats -> 89 Won't do · bot self-KO / early deaths -> 127 (done) -> 127b
WK-CD3 (2026-11-15_cd3_playthrough.md): CD3-01 20d (+ 20e build) · CD3-02 131 (GO) · CD3-03 108b (Accept addition) · CD3-04 (a) 136,
(b) 99 · CD3-05 131 (rally re-measure; LONG HAUL sample 116) · CD3-06 85a (split from 85) · CD3-07 52 · CD3-08 37f · CD3-09 117 (copy),
65 (cards) · re-judged: 126 Won't do, 123b (unverified co-op), 116 (Dropshot watch cleared), 13, 42, 37 T15 (no FIX), 128 §9 G (SHIP),
nets not judged (snapshot predates 66a -> 66c to CD4)
Builder follow-ups since re-rank #6: WK-66a -> 66b, 66c · WK-53b/WK-26 -> 53c · WK-128 -> 135 (spec; absorbs 133, 134, 128b)
Builder follow-ups since re-rank #5: WK-123 -> 123b, 128 (+ 95f merged in), 129 · WK-108 -> 108b (bots), 131 (kickoff rule, CD2-03 carry-over) ·
WK-107 -> 122 · WK-127 -> 127b · WK-37b -> 37c, 53 (raised P1) · WK-130 -> 38 re-scope note
