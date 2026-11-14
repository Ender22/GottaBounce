# WK-98 — Sports deep-dive (Rocketball + Dropshot) — creative-director pass, 2026-11-14

**Owner prompt:** "i've had some feedback that the sport modes are quite fun, maybe more fun than the brawl, so lets
ensure we focus efforts there too" (`docs/feedback/owner_2026-11-14_checkin.md`, ask 6).

**Build judged:** branch `weekend/polish` @ dbc09c9 + the **uncommitted WK-95 flight edits** in the tree (Player/InputBot/
Tuning/PartyMatch). Flight feel and bot super use are therefore the in-progress WK-95 versions; everything flight-dependent
is listed separately in §6 for re-judging after WK-95 lands.

**Verdict: FIX — the sports modes are the most "GottaBounce" thing in the build, and they're close.** The core loop
works and it's fun for structural reasons that brawl doesn't have yet (§2). The three things that hold it back are all
feedback and fairness, not the concept. (1) **Hitting the ball and scoring make no sound and barely react on screen.**
(2) **Rocketball kickoffs are a lottery.** 31 % of goals come within 4 s of GO, and a ball that's live before GO gave one
team a free goal 0.3 s in. (3) **Nobody can tell who scored.** 52 % of goals were last touched by the defending team, and
the game never says so. Dropshot is in better shape than Rocketball: its rallies settle around 10-15 s and there's no
kickoff lottery. Below are 22 findings and the top 8 moves in order.

---

## 1. What was played (method + evidence)

All sessions ran rendered at 1920x1080. My own Godot instance ran at about 120 fps (checked by eval: 119-120) and I
stopped it by PID afterwards. **The humans were simulated:** keyboard P1 plus pad 0 P2, driven by a reaction-lagged
script (about 190 ms per decision, ±14° aim jitter, holds boost to fly, lines up behind the ball, fires an aimed super
when lined up). I watched these sessions through stills. The motion judgements come from five **Movie Maker recordings**
(WK-93, fixed 30 fps, every frame), all bot-only (L3). I read dense frame sheets of the kickoffs, the goals and the
points. A physics-rate monitor node (120 Hz) logged every ball touch, state change, super, smash and SFX.

| # | Mode / court | Format | Seats | Result | Rally mean (range) | Goals <4 s after GO | "Own goals"* |
|---|---|---|---|---|---|---|---|
| M1 | Rocketball / CENTER PITCH | 1v1 | kb vs pad | 6-4 | 19.2 s (4-43) | 0/10 | 6/10 |
| M2 | Rocketball / THE BOX | 2v2 | kb+CPU vs pad+CPU | 4-6 | 5.7 s (1.7-20) | 5/10 | 6/10 |
| M3 | Rocketball / LONG HAUL | 1v1 | kb vs CPU | 6-5 | 23.5 s (2.3-82) | 3/11 | 5/11 |
| M6 | Rocketball / THE BOWL | 2v2 | kb+pad vs 2 CPU | 4-6 | 4.2 s (0.3-9.8) | 5/10 | 5/10 |
| M7a | Rocketball / MINEFIELD | 2v2 | kb+CPU vs pad+CPU | 1-5 (110 s cut) | 9.5 s | 2/6 | 2/6 |
| M7b | Rocketball / THE CRUSHER | 2v2 | kb+CPU vs pad+CPU | 2-6 | 6.6 s | 2/8 | 6/8 |
| M7c | Rocketball / HAMMER YARD | 2v2 | kb+CPU vs pad+CPU | 5-2 (110 s cut) | 8.7 s | 2/7 | 2/7 |
| M4 | Dropshot / SUNSET BEACH | 2v2 | kb+pad vs 2 CPU | 2-6 | 10.7 s (6.5-18.8) | — | — |
| M5 | Dropshot / CORAL COVE | 1v1 | kb vs pad | 6-3 | 14.5 s (8-19) | — | 2/9 |

\* "Own goal" means the last touch before the goal came from the conceding team. This includes deflections off
defenders.

**Rocketball totals (7 human-seat matches):** 62 goals. 19 (31 %) came within 4 s of GO, and 32 (52 %) were last
touched by the defenders.

**Recordings** (`tools/out/rec/<name>/`: frames, `sheet*.png`, `data.json`, `traj.png`, plus dense sheets I made):
`wk98_rb_center_2v2` (rally lengths 2.8 / 1.5 / 15.6 / 1.5 s, `kickoffgoal.png`), `wk98_rb_scrapheap_2v2` (1.5 / 5.8 s,
12 hazard deaths in 30 s), `wk98_rb_longhaul_2v2` (camera crop), `wk98_ds_beach_2v2` (22.3 / 4.3 s, `point1.png`),
`wk98_ds_dome_2v2` (5.1 / 21.3 s).

**Stills and logs:** `tools/out/sports/` (folders `m1_`..`m7_`, key frames in `evidence/`, raw monitor logs, and the
harness scripts in `logs/`).

---

## 2. Why sports is fun — likely more than brawl right now (and the PROTECT list)

These are the structural reasons I saw. Each one is something brawl currently fights against.

1. **One shared object tells everyone where to go.** The ball is the objective, so nobody wanders or hunts.
   Players were airborne 100 % of COMBAT samples, and the ball spends most of its life mid-air (median y 650-1350 on a
   1600-tall court). In GAME_ESSENCE terms that's FLY and BOUNCE all the time, with no "where is everyone?" phase.
2. **The camera never fights you.** Sports frames the whole court and never moves (`SportsMode.camera_framing`). The
   owner has complained about the camera about five times. That complaint doesn't apply here because the camera
   doesn't chase anything.
3. **Scoring is legible.** It's a team score with one number per side. There's no "who KO'd whom?" ambiguity (brawl's
   WK-20/25 problem). Even the own-goal confusion (SP-03) is cheaper to fix than KO credit.
4. **No death downtime on calm courts.** Lives are 99, respawn is instant, and the kickoff resets 2.8 s after a goal
   (measured STAGE_END to COMBAT). Players are dead 0 % of the time on CENTER PITCH (from the recording).
5. **Flight is load-bearing.** Rocketball goal mouths are 400 px above the floor (`sports_court.json`: goal y 650-950,
   floor 1350), so a rolling ball can't score. You have to fly the ball in, which is exactly the essence check
   ("distances REQUIRE flight").
6. **A low skill floor with a high-energy result.** Any touch launches the ball (floor 500 impulse, median 1650-1950
   px/s after a touch). A naive player feels useful in their first ten seconds. In brawl you can play a whole stage
   without landing a credited KO.
7. **Couch team play.** 2v2 with a friend against CPUs (WK-27 picking the goat picks the team) is the most social format
   in the game. The bots' supporter logic keeps them from swarming: both teammates were on the ball only 4-6 % of
   frames in M2.
8. **Physical comedy.** Pinball ricochets off bumper walls, a body-check that knocks someone off the ball, getting
   super-smashed into a Dropshot hole, and own goals (once the game admits to them, SP-03).
9. **Dropshot's serve and rally rules are great.** The ball waits frozen above the net and is served at the last
   scorer. Tiles crack first and break on the second hit, and the ball has to bounce before it falls through. Rallies
   stay in the 6-19 s band with 9-26 touches. This is the healthiest pacing in the game.

**PROTECT (don't regress any of these):** fixed whole-court framing · 99 lives + instant respawn · stage-per-point
reset · goal mouths above the floor (flight required) · CCD on the ball · true-entry goal detection (centre-in-rect) ·
the Dropshot serve rule (frozen above the net, served at the last scorer, alternating by stage parity on the opener) ·
crack-then-break tiles with "bounce on the breaking hit" · beach ball float (gravity 0.35, restitution 0.93, cap 1900) ·
the touch floor so a nudge always moves the ball · bot supporter/cover logic (`SUPPORT_HOLD_FRAC`) · WK-27 colourway
teams (all cross-team hue pairs ≥ 90° apart) · the 2.8 s goal-to-kickoff restart.

---

## 3. Findings (SP-01 ..)

Format: **[priority][size]**, then owner role, evidence, proposal, and an acceptance test. "Merge" means it folds into an
existing BACKLOG item rather than becoming a new WK id.

### SP-01 [P1][M] Hitting the ball and scoring a goal make NO sound and almost no visual reaction
- **Owner:** sound-designer + gameplay-programmer.
- **Evidence:**
  - The SFX log (monitor polling `AudioManager.sfx_fired`/`last_sfx` at 120 Hz) recorded **0 SFX on 88 ball touches
    in M3**. The only sounds near touches were coincidental `bounce` events.
  - **No SFX fired within 0.6 s of any goal or point**, in any match.
  - `AudioManager.SFX` has no ball, goal, crowd, whistle or tile keys. `Ball.gd` has no FX: no hit-stop, no squash, no
    flash, no trail.
  - Dropshot hole falls play the brawl **`death` sting** (8 times in M4).
  - Frame: `evidence/sp_goal_moment_center.jpg`. A goal is a silent tint plus text.
- **Proposal:** a sports juice pack, mode-owned and keyed off new `EventBus.ball_struck(player, speed, is_power)` and
  `goal_scored(team, scorer, own)` signals.
  - **(a) Ball strike:** a "thwock" SFX pitched and volumed by after-speed. 2-3 frames of ball squash along the strike
    direction. A small impact ring in the striker's team colour. Hit-stop only on power shots (60-80 ms).
  - **(b) Wall/ceiling ricochet:** a light "tonk", rate-limited.
  - **(c) Goal:** a horn plus a crowd roar. A net-bulge or burst sprite at the entry point. Camera trauma 0.4.
  - **(d) Dropshot tiles:** a crack SFX on the first hit and a break crunch on the second. Point = whistle plus crowd.
  - **(e) Hole falls in sports:** a cartoon "whoop" or splash instead of `death`, and no KO blast art.
  - Use CC0 sources (sound-designer). Keep the mix under the music.
- **Accept:** in a rendered Rocketball and Dropshot match, the monitor logs a sports SFX within 1 frame of ≥ 95 % of
  touches. Every goal/point fires horn + crowd within 0.1 s. `death` never fires in a sports mode. A WK-93 recording
  shows the squash and impact ring on a strike frame.

### SP-02 [P1][S] Bug: the Rocketball ball is live and touchable before GO, and has given away free goals
- **Owner:** gameplay-programmer.
- **Evidence:**
  - 4 of ~56 kickoffs logged a ball touch during STAGE_INTRO or COUNTDOWN. The player had velocity 0, which means a
    stale overlap at stage reload (see the cause below) or the ball drifting into a spawn.
  - **M6, stage 9:** player 1 "touched" the ball 1 physics frame into STAGE_INTRO at (1406, 808). The ball then drifted
    to x 2337 during the intro and countdown, right next to BLUE's spawn. At GO, the BLUE CPU's first contact put it
    into its own goal **0.3 s after GO** (`logs/m6.json`, t 64.49 → 66.64).
  - **M1:** two pre-GO touches, one of them during COUNTDOWN (`logs/m1b.json`, t 166.7 / 167.8).
- **Cause:** only Dropshot freezes the ball pre-serve (`SportsMode._spawn_ball`). `Ball._physics_process` drives the ball
  from `get_overlapping_bodies()` in every runner state. The overlap list is last step's physics state, so it still
  holds players at their old rally positions on the reload frame.
- **Proposal:**
  - Freeze the soccer ball through STAGE_INTRO/COUNTDOWN and unfreeze it in `on_combat_start` (mirror Dropshot).
  - Gate `Ball._drive_from` on `runner.state == "COMBAT"` via a `live` flag the mode sets.
  - Skip touches on the first physics frame after spawn.
- **Accept:** across 30 rendered kickoffs (bots), 0 touches outside COMBAT. The ball's position at GO equals its kickoff
  spawn ±1 px.

### SP-03 [P1][S] Nobody can tell who scored. Over half of goals are "own goals" and the game never says so
- **Owner:** gameplay-programmer + ui-ux-designer. Merge into **WK-16** (raise its scope).
- **Evidence:**
  - 32 of 62 Rocketball goals (52 %) were last touched by the conceding team.
  - Bots do it too: M2 CPU idx 2 and 3. They path straight through the ball when lining up (SP-06).
  - The banner always reads `GOAL!   RED n — m BLUE`. There's no scorer name, no assist, no "OWN GOAL".
  - The end screen has no per-player line.
  - **Second bug:** `SportsHUD._process` only flashes and shows the white "GOAL!" when `last_scoring_team` **changes**.
    A second consecutive goal by the same team gets no flash and only the coloured banner. Compare
    `evidence/sp_goal_no_flash_same_team.png` (2-0, banner only) with `evidence/sp_goal_double_headline.png` (6-4,
    flash + white GOAL! + banner = WK-16's two stacked headlines).
  - The goal-mouth highlight is **green** for both teams (`sp_goal_moment_center.jpg`). That reads as "success", not as
    a team colour.
- **Proposal:**
  - Track touch credit in the mode: the last touch per team plus the previous same-team touch within 3 s as the assist.
  - Show one banner per goal (this is WK-16): `POGO SCORES!` with a small `assist BILLY` line, or
    **`OWN GOAL! — BUTCH`** as a comedy beat with a "boing" sting.
  - Fire the flash on every goal (key it off a goal counter, not the scoring team).
  - Tint the goal-mouth flash with the scoring team's colour.
  - Add a score-digit pop on the HUD. `animate_scores` is currently a no-op.
- **Accept:** every goal shows exactly one banner naming the scorer or "OWN GOAL" (5 goals in a row checked by
  screenshot, including same-team repeats). The flash fires on all 5.

### SP-04 [P1][S] LONG HAUL crops both goals off-screen
- **Owner:** gameplay-programmer (camera) + level-designer.
- **Evidence:**
  - The court is 3600x1900. Court-fit zoom works out to 1920/3600 = 0.533, but it's clamped to
    `PartyMatch.CAM_MIN_ZOOM` 0.60. That makes the view 3200 wide, so about 200 world px are cut off each side.
  - The goal nets sit at the screen edge, half visible, and a ball inside the goal is half off-screen:
    `evidence/sp_longhaul_goal_cropped.png`, `m3_rb1v1cpu_longhaul/play_372.png`, `rec/wk98_rb_longhaul_2v2/sheet.png`.
  - LONG HAUL also produced the worst pacing: rallies of 61 s and 82 s, next to kickoff goals of 2.3-2.6 s.
- **Proposal:**
  - Let mode fixed-framing go below 0.60. Add a separate `CAM_MIN_ZOOM_SPORTS` of about 0.50, or derive it from bounds.
  - Or shrink LONG HAUL to ≤ 3350 wide so it fits at 0.60, and add a load-time warning when a court's fit zoom is below
    the clamp.
  - Check the other 10 courts with the same formula. BEACH is 2800 (OK), CORAL COVE 3100 (0.619, OK), DOME 2500 (OK).
- **Accept:** a LONG HAUL screenshot shows both goal back-walls fully inside the frame.

### SP-05 [P1][M] Kickoff lottery: the first touch after GO often scores directly
- **Owner:** game-designer (rule) + gameplay-programmer.
- **Evidence:**
  - 19/62 human-seat goals (31 %) came within 4 s of GO. On the small, fast courts it was 5/10 (BOX, BOWL).
  - Bot recordings were worse: CENTER 2v2 rallies of 2.8 / 1.5 / 15.6 / 1.5 s, SCRAPHEAP 1.5 s.
  - `evidence/sp_kickoff_goal_1p3s_sheet.png`: GO at t 8.20. GREEN's first touch at about 8.9 sends the ball across
    the court. Goal at 9.53 s with both RED players still in the middle of the court.
  - In 2v2 the elevated spawn is always closer to the ball than the floor spawn. Bots usually hold the elevated spawns,
    so CPUs nearly always get the first touch (`m2_rb2v2_box/play_143.png`).
  - Dropshot doesn't have this problem because its serve rule takes the first touch away from the scorers.
- **Proposal:** pick one after an A/B (game-designer ruling).
  - **(a) "Ref drop":** the ball is held frozen at about 25 % court height above centre and released on GO with a
    random small vertical toss. That buys about 0.8 s for both teams to converge.
  - **(b) The conceding team kicks off:** like Dropshot's pressure inversion, the ball spawns 25 % toward the scorers'
    half.
  - **(c) Kickoff formation:** one player per team spawns in their own goal mouth (keeper spot) and one at midfield.
    Spawns are equidistant to the ball by construction.
  - Recommend **(a)+(c)**. They keep the 2.8 s restart.
- **Accept:** 40 rendered kickoffs (bots L3 + one human driver). Goals within 4 s of GO ≤ 10 %. Median rally on
  CENTER PITCH 8-20 s.

### SP-06 [P1][M] Bots path through the ball (own goals), never keep goal, never pass
- **Owner:** gameplay-programmer (InputBot / `SportsMode.bot_objective`).
- **Evidence:**
  - `bot_objective` sends a wrong-side bot straight to `behind = ball - to_goal*150`. The straight line to that point
    passes through the ball, so the "line-up" flight shoves it toward the bot's own goal. That contributes to the CPU
    own goals (M2 idx 2/3, M7b).
  - Supporters hold `own_goal.lerp(ball, 0.42)`. When the ball is in their own third that's in front of the goal mouth,
    not in it. With the ball in its own half, a team had someone within 500 px of its own goal only 52-60 % of the
    time (M2).
  - Bots always drive at the goal. No touch sequence showed a deliberate teammate setup.
- **Proposal:**
  - **(a) Ball-avoid waypoint:** if the bot is on the wrong side, route via a point offset perpendicular to the
    ball→goal line, by about 1.6×(ball radius + body radius) and preferring "over the top". Only commit to `behind`
    once the segment clears the ball.
  - **(b) Keeper role:** if rank ≥ 1 and the ball is in the own third, hold the goal-mouth centre (clamped inside the
    court) and challenge only when the ball comes within 400 px.
  - **(c) Optional "cross":** at L4-5, if a teammate is nearer the enemy goal and unmarked, aim through the ball toward
    the teammate.
- **Accept:** in 10 bot-only 2v2 recordings, CPU own goals ≤ 15 % of goals. When a supporter exists and the ball is in
  its own third, the supporter is within 300 px of the goal mouth ≥ 70 % of the time.

### SP-07 [P1][S] The "power shot" isn't special: normal touches already hit near max speed
- **Owner:** game-designer (tuning ruling) → gameplay-programmer. Ball constants are mode-owned (INV-6). This is a
  feel-protect item, so A/B it before shipping.
- **Evidence:**
  - Super-active touches were only 1.5 % of Rocketball touches (2/96, 2/123, 4/135).
  - Their after-speed (2400, the cap) is only about 1.3-1.5× the median normal touch (1630-1830).
  - **24-33 % of ordinary touches land within 100 px/s of the 2400 cap**, because `500 + 0.9 × ~900` divided by mass
    0.6 is already about 2000. So there's no soft touch or dribble, and no "cannon" moment.
  - The spec's fantasy (v5 §0: "met the ball at full boost and rocketed it past the keeper") needs some dynamic range.
- **Proposal:**
  - Split the cap: `BALL_MAX_SPEED` 2400 for normal touches, and a power-shot cap of about 3200 (still under the
    player's 3000 max + CCD) only when `is_super_active()`.
  - Trim `BALL_TOUCH_IMPULSE` 500→350, keeping `BALL_DRIVE_GAIN` 0.9 so speed still matters.
  - Give power shots a flame/streak trail plus hit-stop (SP-01) and a "POWER SHOT!" pop.
  - Re-measure after WK-95 (§6).
- **Accept:** the touch-speed histogram shows < 10 % of normal touches near the cap. Power shots visibly exceed it.
  Median normal touch 1300-1600 px/s. A creative-director replay confirms a super header reads as THE big moment.

### SP-08 [P2][S] No tension beats: no match point, no "next goal wins", no goal-count or rule options
- **Owner:** game-designer + gameplay-programmer + ui-ux-designer.
- **Evidence:**
  - M3 went from 3-5 to 6-5 with an 82 s deciding rally at 5-5, and nothing on screen marked "NEXT GOAL WINS".
  - The brawl MATCH POINT banner path (`PartyMatch._pending_match_point`, WK-41) is kill-driven and never fires in
    sports.
  - The lobby RULES panel has only FORMAT (1V1/2V2) and CPU SKILL (`09_rules.png`).
  - The goal cap is a hard-coded `Tuning.sports_goal_target = 6`. The spec recommended N=5 for 1v1 and N=7 for 2v2.
- **Proposal:**
  - Add a `GOALS` stepper (3/5/7/10, default 5 for 1v1 and 7 for 2v2) to SPORTS rules in `GameConfig.rules_for`.
  - Show a MATCH POINT top banner from SportsMode at cap-1 by reusing `_mp_banner` and `show_top`. At a cap-1 tie, show
    "GOLDEN GOAL" plus a crowd swell (SP-01).
  - Optional rule: WIN BY 2.
- **Accept:** a rules screenshot with the GOALS row. At 5-4 and 5-5 (cap 6), screenshots show "MATCH POINT — RED" and
  "GOLDEN GOAL".

### SP-09 [P2][M] The match end has no celebration or stats, and the punch-zoom lands on a wall or the void
- **Owner:** ui-ux-designer + gameplay-programmer.
- **Evidence:**
  - `evidence/sp_end_zoom_into_wall.png` (LONG HAUL): the camera punch-zooms at 1.1 onto the representative winner
    index (`MATCH_END_ZOOM`). The frame is goal pillars plus blue letterbox void, and the winners are hidden behind the
    panel.
  - `m6_rb2v2_bowl/end.png`: the same thing on the bowl's side ledges.
  - The panel shows only "RED WINS! / RED 6 — 4 BLUE". No MVP, goals, own goals or power shots, so a couch group has
    nothing to brag about or tease over.
- **Proposal:**
  - For sports, frame the WINNING TEAM (bounds-clamped, zoom ≤ 0.92) with a confetti burst in the team colour.
  - Lift the panel to the lower third so the goats stay visible.
  - Add a per-player stat strip from SP-03's credit (goals, assists, own goals, power shots) and a single "MVP" chip.
  - REMATCH and CHANGE SETUP already work well (setup is preserved, verified).
- **Accept:** a screenshot of the end screen in Rocketball and Dropshot shows the winning goats, no void, and a stat row
  per player.

### SP-10 [P2][S] Hazards KILL in a "nobody dies" mode
- **Owner:** game-designer + level-designer.
- **Evidence:**
  - SCRAPHEAP recording: 12 `killed` events in 30 s, with players dead 4-18 % of COMBAT time (BLUE's two at 15 % and
    18 %).
  - The first goal came 1.5 s after GO while bombs were going off around spawns (`evidence/sp_scrapheap_sheet.png`).
  - M7b CRUSHER: 6/8 goals were own goals. The centre crusher swats the ball back the way it came.
- **Proposal:**
  - In sports, hazards should knock and stun, not kill. Add a mode flag so `kill_radius` becomes launch + stun, or a
    `SportsMode.on_hazard_contact` seam.
  - Move bomb positions off the kickoff lines.
  - Keep the chaos courts as the "tier 4-5" party option, but default rotation stays calm.
- **Accept:** SCRAPHEAP 30 s bot recording: dead fraction < 3 % per player, with no goal in the first 3 s across 10
  kickoffs.

### SP-11 [P2][S] Stage-1 legend and rule chip cover the scoring surface
- **Owner:** ui-ux-designer. WK-15 follow-up.
- **Evidence:**
  - `evidence/sp_ds_legend_covers_floor.jpg`: in Dropshot rally 1, "SPIKE IT OVER THE NET…" plus MOVE/FLY/SUPER
    SMASH/PAUSE chips sit right on top of the floor tiles, the thing you defend. Cracks are hidden under the chips.
  - Rocketball has the same thing over the floor and trampoline (`07_rb_intro.png`).
- **Proposal:** in sports, dock the legend at the top under the score bug, or fade it at the first ball touch or after
  4 s, whichever comes first.
- **Accept:** a Dropshot frame at +2 s shows all floor tiles unobstructed.

### SP-12 [P2][M] Court variety is shallow: 5 of 8 Rocketball courts share one geometry, and two good courts are locked behind Brawl
- **Owner:** level-designer (JSON-only) + game-designer.
- **Evidence:**
  - CENTER PITCH, HAMMER YARD, MINEFIELD, THE CRUSHER and THE SCRAPHEAP are all the same 2800x1600 box with
    goal_zone (240/2560, 140x300). Only the hazard or the 2 mid bumpers differ.
  - Every court uses the same dark stadium backdrop (WK-66).
  - `sports_courts.json` gates HAMMER YARD behind `circuit:scrapworks` and MINEFIELD behind `circuit:mayhem_mile`. A
    sports-first group can't unlock them (`Settings.is_court_unlocked` returned false for both).
  - **Ratings, best to worst:**
    - **THE BOX** (tight, sprites at 0.92 zoom, fast, readable)
    - **THE BOWL** (the stepped floor actually changes the bounces)
    - **CENTER PITCH** (solid default, small sprites)
    - **HAMMER YARD / MINEFIELD** (fun chaos once SP-10 lands)
    - **THE CRUSHER** (the crusher reflects shots, so 6/8 goals were own goals)
    - **THE SCRAPHEAP** (death spam)
    - **LONG HAUL** (broken framing, 60-80 s grinds)
  - **Dropshot:** BEACH and CORAL COVE are both great. DOME's moving net is the best idea, but the net is invisible
    (SP-13).
- **Proposal:**
  - Change the cross-mode gates to `sports_matches:N` or `sports_wins:N`.
  - Add 3 geometry-first courts:
    - **PINBALL:** angled bumper wedges beside each goal, so bank shots become a skill.
    - **SKY GOALS:** goals in the ceiling corners, so vertical flight is mandatory.
    - **TWIN NETS:** two small goals per side at different heights.
  - Make LONG HAUL fit (SP-04) and add mid-field bumpers to break up the grind.
- **Accept:** each new court passes the level-designer flight-required check. A 2v2 bot recording per court shows a
  rally median of 6-20 s.

### SP-13 [P2][S] Dropshot nets don't read as nets (DOME's is nearly invisible)
- **Owner:** art pipeline + level-designer. Merge into **WK-66** and raise the net slice to P1-S.
- **Evidence:**
  - `rec/wk98_ds_dome_2v2/frame00000436.jpg`: the DOME net is a dark steel moving-platform column on the dark
    stadium. At couch distance it's lost.
  - BEACH and CORAL COVE nets are a 30 px stack of white balls, which reads as a pole.
  - The net is the one piece of geometry every Dropshot shot is about.
- **Proposal:** a themed net sprite: a mesh panel plus a bright top cord and posts, drawn over the existing bumper
  collider. DOME's net also needs a moving-state cue (a glow when the under-gap opens).
- **Accept:** an art-director grade on a DOME frame: the net is readable at the 1080p couch distance.

### SP-14 [P2][S] No per-player fuel or super-ready readout in sports
- **Owner:** ui-ux-designer. Merge with **WK-99** (fuel super-ready notch), apply to sports.
- **Evidence:**
  - `SportsHUD.setup` is `pass`, so there are no PlayerCards and no fuel gauge anywhere in sports.
  - On LONG HAUL the median fuel was 16-20 % (M3). Players run dry with no warning, and the WK-95 super threshold
    (10 %) is invisible.
- **Proposal:** add a small fuel arc under each goat in sports (player-attached, team-coloured), with the WK-99 notch.
  Or use slim bottom-corner chips.
- **Accept:** a rendered sports frame shows each goat's fuel. When fuel is below the super threshold the notch is
  visibly unlit.

### SP-15 [P2][S] Rally length is bimodal on big courts (2 s goals and 60-80 s grinds)
- **Owner:** game-designer.
- **Evidence:**
  - M3 LONG HAUL rallies: 27.8, **61.3**, 8.1, 19.4, **2.6**, 8.5, **2.3**, **2.4**, 31.7, 12.8, **81.8** s.
  - M1 CENTER had 31 s and 43 s rallies.
  - The match length followed: M3 took about 5.5 min while M6 took about 75 s.
  - The CENTER/LONG HAUL grinds sit at the ceiling/floor bounce corners: the ball's median y was 1349 on LONG HAUL, so
    it hugs the floor.
- **Proposal:**
  - After SP-05 removes the short tail, attack the long tail. A "sudden pressure" rule: after 30 s without a goal,
    both goal mouths grow 25 % (a visible net extension with a crowd chant).
  - Also consider a slightly springier floor in sports only (the ball restitution vs floor tier).
- **Accept:** 10 CENTER and LONG HAUL rallies, none over 45 s, median 8-20 s.

### SP-16 [P3][S] Brawl words in sports: "BOUNCE!" at kickoff, "FIGHT!" on court select
- **Owner:** ui-ux-designer.
- **Evidence:** `m2_rb2v2_box/play_143.png` ("BOUNCE!"), `06_courtselect.png` ("A FIGHT!").
- **Proposal:** use "KICK OFF!" in Rocketball, "SERVE!" in Dropshot, and "PLAY!" on court select. Use mode
  `display_name`-keyed strings.
- **Accept:** screenshots.

### SP-17 [P3][S] The DROPSHOT mode card shows a soccer goal net
- **Owner:** art pipeline. Merge into **WK-65**.
- **Evidence:** `01_modeselect.png`. The DROPSHOT card art is a goat spiking a beach ball into a goal frame, which
  contradicts "don't let it drop". The card's title also sits about 30 px lower than its neighbours.
- **Proposal:** re-cut the art with a net and sand (or edit the existing image). Align the title baseline.
- **Accept:** an art-director approval.

### SP-18 [P3][S] The score bug is small for a TV and has no team names or crests
- **Owner:** ui-ux-designer. Merge into **WK-35** (sports scoreboard), keep P1 there.
- **Evidence:** the score bug is about 210x80 px at 1080p (`07_rb_intro.png`), and "TO 6" is about 14 px tall.
- **Proposal:** a WK-35 toybox panel with team-colour halves, RED/BLUE labels or goat crests, and the score-digit pop
  (SP-03).
- **Accept:** as WK-35.

### SP-19 [P3][S] (to confirm) Short stick flicks are ignored in the lobby carousel
- **Owner:** ui-ux-designer.
- **Evidence:** two 120 ms left-stick taps on pad 0 didn't change the goat. Two 350 ms holds did (`03_lobby_p2.png`
  vs `04_lobby_p2b.png`). A human flick is about 80-150 ms. This may be a harness artefact (axis events injected with
  no intermediate values), so re-test with a real pad before building anything.
- **Accept:** a real-pad flick changes the goat on the first press.

### SP-20 [P3][S] In-play CPU name tags vanish after the intro
- **Owner:** ui-ux-designer. Already WK-10-adjacent.
- **Evidence:** `m6_rb2v2_bowl/goal_03_2-2.png`. Only the P1/P2 pips show. Two of the four goats are anonymous, so in
  2v2 "which blue is my teammate CPU?" relies on colour alone.
- **Proposal:** keep a small team-coloured "CPU" pip in sports. It's cheap and helps SP-03 ("OWN GOAL — ZIGGY").
- **Accept:** a screenshot.

### SP-21 [P2][S] Dropshot is the stronger mode, but it isn't the default sports entry and has no 2v2 nudge
- **Owner:** producer + ui-ux-designer.
- **Evidence:** across M4/M5 and two recordings, Dropshot rallies stayed in 6-22 s with 9-26 touches and no kickoff
  lottery. Its rally quality was the best of any mode I played.
- **Proposal:** order the cards BRAWL · DROPSHOT · ROCKETBALL · TRIALS, or highlight Dropshot as "party pick". Default
  the Dropshot FORMAT to 2V2 when 2+ humans join.
- **Accept:** producer ruling plus a screenshot.

### SP-22 [P2][S] Super-smash into opponents is the right defensive verb, but nothing teaches it
- **Owner:** ui-ux-designer + game-designer.
- **Evidence:** smashes happen (16 in M4's 110 s, 5 in M7a), and the card copy says "Headbutt the ball, not each
  other. Okay, each other too." But the in-match legend says only SUPER SMASH, with no sports framing. A naive player
  won't learn that knocking the keeper away opens the net.
- **Proposal:** a sports-specific legend line: "X: SUPER-SMASH the ball (power shot) or a rival (clear them)".
- **Accept:** a stage-1 screenshot.

---

## 4. Existing BACKLOG items — keep / raise / drop
- **WK-16** (one goal banner): **RAISE scope**. Include SP-03 (scorer/own-goal credit, the flash fires on every goal,
  team-coloured goal-mouth flash, score pop). Stay P1, now S→M.
- **WK-27** (team lobby): **verified working in play.** Picking the goat picks the team. FORMAT 2V2 auto-fills a CPU per
  side in that team's spare colourway. CHANGE SETUP returns to the lobby with teams intact. RULES panel ownership
  works on pad (`03-10_*.png`). Keep it closed.
- **WK-35** (sports scoreboard): **keep P1** and absorb SP-18.
- **WK-65** (court cards): **keep P2**. All 8 Rocketball thumbs are the same dark stadium (`06_courtselect.png`). Add
  SP-17.
- **WK-66** (court art): **RAISE the net slice to P1-S** (SP-13). The rest stays P2.
- **WK-99** (fuel super-ready notch): **extend to sports** (SP-14).
- **WK-86** (powerups follow the stage): no sports bubbles seen. Keep it closed.

---

## 5. TOP 8 SPORTS MOVES (priority order)
1. **SP-02 Freeze the ball until GO.** It's an S-sized bug that hands out free goals. Do it first.
2. **SP-01 Ball-strike + goal juice and audio.** It's the biggest felt gap: every touch and every goal is currently
   silent.
3. **SP-03 (inside WK-16) Scorer credit, OWN GOAL callout, the flash on every goal, score pop.** This makes goals mean
   something and turns own goals into comedy.
4. **SP-05 Kickoff fix (ref drop + keeper formation).** It kills the 31 % kickoff lottery while keeping the 2.8 s
   restart.
5. **SP-04 LONG HAUL camera fit.** S-sized, and both goals are currently off-screen.
6. **SP-06 Bots: route around the ball, keep goal, (L4+) cross.** Better teammates, fewer CPU own goals, and real
   defence to beat.
7. **SP-07 Power-shot dynamic range.** It makes the super header the cannon moment the spec promises. A/B it after
   WK-95.
8. **SP-08 + SP-09 Tension and payoff.** A GOALS rule, MATCH POINT / GOLDEN GOAL banners, and an end screen that frames
   the winners with a stat strip.

Then SP-10 (no-kill hazards), SP-11 (legend placement), SP-13 (nets, in WK-66), SP-14 (fuel readout), SP-12 (courts),
SP-21 (Dropshot prominence).

---

## 6. Flight-dependent notes — re-check after WK-95 lands
I judged these on the in-progress WK-95 tree. Re-run M2 (BOX 2v2) and M4 (BEACH 2v2) with the same harness
(`tools/out/sports/logs/human.py` + `monitor.gd`) and compare.
1. **Touch strength.** Strength is `500 + 0.9 × player speed`, so WK-95's normal_boost_max_speed 760→800 and
   accel 4600→5400 make every touch stronger and get players to the ball sooner. Re-measure **near-cap touch share
   (24-33 % now)** and **kickoff goals < 4 s (31 % now)** before tuning SP-05 or SP-07.
2. **Lining up a header.** `boost_grip` (G4) and the directional `boost_enter_keep` should make it easier to stop
   behind the ball and redirect. Re-judge whether a human can deliberately aim a shot. Track the share of goals last
   touched by the attacking team (48 % now).
3. **Super as attack, not traversal.** Dropshot bots fired 15-21 super-aim windows in 35 s (`rec/wk98_ds_*`). Supers
   are the dominant body-check verb there. Re-measure super count and smash count per minute after WK-95c/d. Watch
   that sports bots don't lose their only way to clear an opponent.
4. **Power-shot share.** Super-touches are 1.5 % of Rocketball touches now. If WK-95 makes supers rarer, SP-07's
   "power shot" moment gets rarer too. Pair the two decisions.
5. **Fuel.** LONG HAUL median fuel was 16-20 % (M3), against 40-75 % elsewhere. The flight economy changes what "ran
   dry" feels like. Re-judge SP-14's urgency.
6. **Dropshot hover-under-the-ball.** With floaty ball gravity at 0.35, the WK-95 thrust/grip changes how easily a
   player can hold under a dropping ball to save it. Re-measure Dropshot rally length (10.7 s / 14.5 s now) so it
   doesn't balloon.
7. **Bot aim smoothness (WK-94).** All 5 recordings' aim windows are capped at 2.63°/tick with 0 jumps over 15°. That's
   clean already; just confirm after WK-95d.

---

## 7. Fantasy-fit check (GAME_ESSENCE) — sports
- **Airborne and using the jetpack?** Yes. Airborne 100 % of samples. Median player speed 800-1060 px/s.
- **Distances require flight?** Yes. Goals sit 400 px above the floor, the ball lives mid-air, and the courts are wider
  than a bounce. LONG HAUL is the exception: it fails on framing, not on distance.
- **Super is the decisive move?** Not yet. Super contacts are 1.5 % of touches and only about 1.4× a normal touch
  (SP-07). As a body-check it works (smashes in every 2v2).
- **Constant motion / no camping?** Yes. Dead time is 0 on calm courts and the restart is 2.8 s. Hazard courts break
  this (SP-10).
- **Looks like the reference in motion?** The rallies look like a frantic Rocket League / Windjammers hybrid in the
  recordings. The goal moment doesn't (silent tint plus text), and that's SP-01/03.
- **Would a first-timer want one more round?** Dropshot, yes. Rocketball, yes on BOX and BOWL once the kickoff lottery
  and silent goals are fixed. LONG HAUL, no.
