# WK-CD3: Creative Director cold playthrough #3 (2026-11-15)

**Build:** pinned snapshot of `weekend/polish` @ **ac7b4f0** (`git archive` into my scratchpad, plus a copy of the import cache). It includes WK-128 bill-only (3e1a5b0) and WK-37d (b76d36f). It excludes the uncommitted WK-66a net code and the WK-135 scratch work. The snapshot is deleted.

**Port / display:** rendered at 1920x1080 on port 9106. Another agent's Movie Maker recording and a 2-process headless batch ran at the same time, so the game ran at **47-52 fps** (`gbplay perf` flagged it invalid). **No perf or timing claim below uses wall clock.** Every duration is game time: `phase_log.tick_s`, `round_stats.length_s`, `round_clock`, or a WK-93 recording.

**Route:** a naive couch group of three on separate devices: **pad 1 (P1), pad 0 (P2), keyboard (P3)**, plus one CPU (L2).
- title → mode select → Herd Lobby (join / pick / lock) → arena select (first card: MEADOW MILE) → full **Brawl** to 10 → REMATCH → another full Brawl → a third Brawl as an A/B (WK-128 bill OFF from stage 5) → MENU.
- **Rocketball** 2v2 CENTER PITCH (RED: P1 + P3 pads; BLUE: P2 keyboard + CPU ZIGGY) → REMATCH → QUIT TO MENU.
- **Dropshot** 2v2, same seats.
- **Trials → FLIGHT SCHOOL** lessons 1-4, solo.

**Drivers (not repo code; copies in `tools/out/cd3/*.gd.txt`):**
- **HumanSim3:** the CD2 human-style driver. It posts real pad and key events per device and re-plans every 0.14-0.30 s with aim noise; the keyboard is quantised to 8 directions. It chases, holds FLY to travel, supers in range, and recovers toward ground.
  - New: a **ghost layer**. When its goat is a ghost it floats toward a living goat, puffs when in range and charged, and bleats every 1.2-4 s.
  - New: a **relight tracker**. It logs every billed re-light, the fuel left after the bill, and the thrust ticks actually delivered.
- **TapPilot:** points the pad at a target and presses FLY in an on/off rhythm.
- **SuperPilot:** "fly up, then tap X at N % fuel", the way the Flight School hint reads.

**Recording (WK-93):** `tools/out/rec/…` built from the snapshot, then copied to `tools/out/cd3/rec_ghost_islands/`. It is 30 s, 4 bots L2/L3/L3/L4 on islands_void, with ghosts ON and seat 0 eliminated each stage. Outputs: `sheet.png`, `traj.png`, `aim_report.png`, and follow-zoom sheets `follow2.png`, `follow3.png`, `follow0_ghost.png`. Raw frames are deleted.

**Limits:**
- The driver is not a human. It is reckless near edges, and the super drains the whole tank (`Player._fire_super`: `fuel = 0.0`), so a missed super near a blast line is usually a self-KO. Treat its balance numbers as a stress case for newcomers, not as a skill-matched result.
- I could not judge audio by ear.
- I did not re-test the pause flows (CD2 verified them).

---

## Verdict

**Is it a fun, conventional couch party game now? Mostly yes. This is the first build I would hand to four friends without apologising for the front end.**

- **Front end: SHIP.** You join, pick and ready on your own device, and picking a goat picks your team in sports. The lobby remembers your goats between modes. REMATCH works from any pad, and the match flow uses one cream look throughout.
- **Sports: SHIP-adjacent and the showcase.** Two Rocketball matches (6-2, 6-5) and one Dropshot (6-4) were the best minutes again. The new end card gives the payoff CD2 asked for: RED WINS!, an MVP, a stats table, the longest rally and the winning goal.
- **Flight School: SHIP.** It finally teaches the super. You cannot skip it by holding FLY.
- **Ghosts: they deliver.** The dead have something to do within 0.6 s.

**Overall: FIX, close to SHIP.**

**The single biggest remaining problem is Brawl pacing on the default circuit.**
- The median stage lasts **8.4 s**. The first goat dies at **2.8 s** (median).
- **33-49 % of human deaths involve no hit at all.** The goat simply leaves the stage.
- Between-stage time is about **5 s per stage**, so roughly 38 % of a Brawl is interstitials.
- Ghosts turned the dead time from idle into play. But the core arc of the fantasy (fight, get launched, claw back, super-smash) rarely has room to happen before the stage is over.
- The brawl is readable, fair and frantic. It is not yet a place where comebacks happen.

---

## Re-judge numbers (WK-CD3 list)

### 1. Brawl pacing (WK-127 + WK-20c + WK-25)

27 stages with the bill ON (m1 + m2) on MEADOW MILE, 3 HumanSim seats + CPU L2. Logs: `tools/out/cd3/m1/stats.json`, `m2/stats.json`; the A/B is `m3off/stats.json`.

| Measure | CD2 | **CD3** |
|---|---|---|
| Median stage length | 11.6 s | **8.4 s** (mean 9.4; 4 of 27 under 5 s) |
| First death (median) | about 2-3 s on Islands Void | **2.8 s** (m1 3.0, m2 2.5) |
| CPU share of the win | CPU won 10-6-4-2 | m1 **10-7-4-3** (human P1 won, CPU last); m2 **CPU won 10** (8-8-0); m3 human won, CPU 5. Competitive, not dominant |
| Human self-KO share of deaths | 18 % | **33 % (m1), 49 % (m2)**. Every one had no prior smash on the victim. A/B with the bill OFF: **48 %**, so WK-128 is not the cause |
| Dead-frame share, humans | P1 48 % | median ~25 %; the worst seat per match 44 % (keyboard, m1) and 58 % (m2 P1: 0 KOs, 9 OOPS) |
| Super as the kill | n/a | **70 %** of credited KOs had a super as the last smash (35 of 50) |
| Interstitial per stage | ~4.1-4.5 s | **5.0 s** game time (INTRO 0.8 + COUNTDOWN 1.06 + STAGE_END ~0.9 + SCOREBOARD ~2.5) |

- **Can you read every score change?** **Yes.** A +1 burst appears at the blast point in the attacker's colour, and OOPS! appears on the victim's HUD card. The stage-end line reads "P1 +1 · P2 OOPS! · VEX +1 · VEX SURVIVED", and the score screen repeats it with +1 / OOPS chips and a kill-list row (`m1/04_STAGE_END_s1.png`, `m1/05_SCOREBOARD_s1.png`, `m1/10_SCOREBOARD_s2.png`).
- **Does the winner match who fought best?** **Yes, in all three matches.** Self-KOs cost 0, so the score is exactly credited KOs. m1 P1 had 10 credited, m2 the CPU had 10, m3 P3 had 10.
- **Side effect:** a stage where everyone self-falls pays nobody. In m1 stage 2 all three humans flew off at 4.5-6.0 s and the CPU survived for 0 points, a 6 s stage that changed nothing. It happened only once in 27 stages.

### 2. Ghost goats: T15 felt pass

Three human ghosts across 42 stages, plus bot ghosts in the recording.

| T15 question | Answer | Evidence |
|---|---|---|
| 1. Within 2 s of dying, did I have something to do? | **Yes.** The ghost is controllable **0.02-0.59 s** after the KO. A device-correct legend appears by your card: "GHOST! ✚ FLOAT · X PUFF · Y BAA" on pads, "WASD · K · J" on keyboard. | `m1/stats.json` ghost rows (`t_spawn - t_elim`); `m1/02_ghost0_s1.png`, `m1/08_ghost2_s2.png` |
| 2. Did I ever lose track of which goat was alive? | **No, with one soft spot.** Ghosts are translucent and desaturated, the tag is faded, and the HUD card shows a ghost icon. At follow zoom (0.35-0.4) a ghost reads instantly as "not playing" next to opaque living goats. The soft spot: a ghost tag parked inside a live scrum makes a cluster of three tags (P3 ghost over P1/P2 in `m3off/03_ghost1_s5.png`). | `rec_ghost_islands/follow2.png`, `follow3.png` |
| 3. Did a ghost ever decide a KO in a way that felt cheap? | **No.** There were **0 haunted KOs** in 42 stages, and every cloud contact before a death was the victim landing on top. | `round_stats.kills[].haunted` |
| 4. Did the puff ever save someone? | **Yes, four times.** A fuel-dry goat caught by a cloud survived each time. In m2 stage 7 the CPU bounced 0 → 11 → 19 → 28 fuel on one cloud and lived, which was a "the ghost saved my enemy" moment. | `m2/stats.json`, `m3off/stats.json` puff contacts |
| 5. Is the bleat funny or noise? | **Not judged by ear.** Visually the "BAAA!" burst is readable and well placed above the ghost (`rec_ghost_islands/follow2.png` f340-f355, `sheet.png` f254-f266). Rate: 50 game-side bleats in m2 from three ghosts with the 2 s gap. | needs a human ear |

**T15 result: no FIX trigger.** Q1 is yes, and Q2 and Q3 are no. **Is the dead half of the evening fun now?** It is busy, and the cloud is a real lever. The m2 P1 seat spent 58 % of the match as a ghost and still had 9 puffs and 28 bleats. Minor: CD3-08 (a ghost can vanish behind terrain).

### 3. Flight School (WK-123)

Solo, pad 1, SuperPilot / TapPilot. Screenshots: `tools/out/cd3/fs_03_t1.png` through `fs_07_t4.png`.

| Lesson | Hold FLY only | The hinted verb |
|---|---|---|
| 1 First Flight | HOME (1,330-1,660 px in 1.65 s) | n/a |
| 2 Super Shot | **Fails, 949 px short** | "fly up, tap X" at 35 % fuel: **HOME first try** |
| 3 Sky Ladder | **Fails, 1,481 px short** | super at 60 %: **fails, 663 px short**. Super at 15 %: **HOME**. The lesson really teaches "spend the tank, then super" |
| 4 Fuel Run | **Fails** (best 2,592 px from goal, then falls and respawns) | pads required, as designed |

- **Can a newcomer clear lessons 2-4 without firing a super?** **No.** CD2-01 is closed.
- **Co-op lane blocking:** lessons 2-3 now have four rings 600 px apart, so each player has a lane. I ran these solo, so I have **not verified blocking in co-op play**. WK-123b stays a judgement call for the producer; it looks structurally addressed.
- **WK-128 in Flight School:** see §5 below.

### 4. Rocketball (≥ 2 human-style seats), WK-131 go/no-go

19 goals in two matches. Logs: `tools/out/cd3/rb/points.json`, `rb2/points.json`, `*/stats.json`.

- **Goals within 4 s of GO: 5/19 = 26 %** using the round clock polled at the goal (a lower bound), or **3/19 = 16 %** using the whole COMBAT phase including the goal beat (an upper bound).
  - **Every one was scored by a human seat or a human's team:** P1 ×3, P2 ×1, and one BLUE team goal.
  - **WK-131 is GO.** Both bounds are above its 10 % close line.
- **Restart (WK-124): 2.67 s game time on every one of 26 restarts** (STAGE_END 1.21 + INTRO 0.40 + COUNTDOWN 1.06). The PROTECT line is met.
- **CPU-teammate own goals (WK-108b): 2/19 (10.5 %), both in match 1.** One was **the match-winning goal**: the end card reads "WINNING GOAL · OWN GOAL BY ZIGGY" (`rb/end.png`). The human keyboard seat added 2 own goals of its own (driver).
- **Sports end screen (WK-111): SHIP.** It shows RED WINS!, both winners' portraits, MVP, and per-player GOALS / ASSISTS / SAVES / TOUCHES / OWN GOALS, plus the longest rally and the winning goal (`rb/end.png`, `ds/end.png`).
- **Rally median 5.7 s (polled) / 7.0 s (phase)**, down from CD2's 8.8 s and below the 8-20 s band. See CD3-05.

### 5. Dropshot rally median (WK-116 watch)

- 10 points, RED 6-4. **Median 9.2 s** (polled) / **9.8 s** (phase), with a range of 3.6-25.7 s. CD2 was 14.5 s. **That is far under the ~20 s act line, so no action on WK-116.**
- Restart is 2.67 s. Logs: `tools/out/cd3/ds/`.
- I took no LONG HAUL sample (time).

### 6. Bots

- **Orbit loops (WK-126):** `rec_ghost_islands/traj.png` still shows tight orange curls in the right-hand cluster. At follow zoom (`follow3.png` f460-f510) the curls read as a **close dogfight around a bush with supers landing**, not as buzzing flies. Aim stays smooth: 14 windows, 0 over the cap, 0 jumps over 15° (`aim_report.png`). **I recommend closing WK-126 as "reads fine at gameplay zoom".**
  - Watch: around f520-f548 one bot hovers almost in place for about 1 s while its target is above it.
- **the_ascent top-tier hopping (WK-127b):** not checked this pass.

### 7. Look baseline

- **Navy panels: gone from everything I saw.** The scoreboard, final score, sports end card, lobby and court select are all in the cream kit. Pause and Options were not opened.
- **Combat HUD cards are still visible behind both victory screens** (WK-42 still open): `m1/13_MATCH_END_late.png`, `m2_end.png`.
- **Mint fill:**
  - Flight School lesson 4 is half flat-mint "void", with bushes and fences floating in mid-air (CD3-06).
  - Islands Void's lift (WK-37d) helps in Brawl.
- **Sports letterbox: gone** on CENTER PITCH. The painted stadium runs edge to edge (`rb/goal_2.png`).
- **Court-select thumbnails are still the old dark-stadium previews** with a half-empty card (WK-65).
- **Nets: placeholder grid rectangles** (in progress, WK-66a; not filed).
- **Mode select still focuses TRIALS first** (WK-13 still open): `02_after_play.png`.

---

## WK-128 §9 feel check (spec §9 G)

Method:
- **A/B on the same build** via `Tuning.boost_relight_bill_max` 0.20 vs 0.0. Five TapPilot cadences flew 1,330 px across Flight School lesson 1 from a standing start (`tools/out/cd3/tap_ab.json`), then again from 30 % and 18 % fuel.
- **In-match relight tracker:** 130 human boost presses and 39 billed re-lights across m1.

| # | Question | Answer |
|---|---|---|
| G1 | Does flying feel exactly as before ("I point, I go there")? | **Yes.** A hold arrives in **1.65 s both ways** (fuel left 53.6 vs 53.3). A "corrector" (hold, with 0.12 s releases to re-aim) arrives in 1.82 vs 1.81 s. |
| G2 | Is the brake tap still snappy, and does a re-light ever feel like a dead button? | **With a healthy tank, never.** Every press at every cadence delivered thrust, and arrival times match bill ON and OFF to within 0.1 s. The cost only shows on the gauge: a newcomer tapping 0.25/0.35 ends with **44 % fuel vs 67 %** without the bill, a fast tapper with **41 % vs 74 %**, and a hold with 54 %. **In the last ~10 % of the tank it does go dead.** See the bullets below. |
| G3 | Do walls still feel like part of the toybox? | **Unchanged.** The refund gates shipped OFF, and wall refunds still occur (2-5 per human per match in m1). |
| G4 | In sports, are players starved or grounded more than before? | **No sign.** Rocketball touches are 49-56 per human per match and Dropshot 74-86. Rallies got shorter, not stalled. I did not A/B sports. |
| G5 | Does "bounce to refuel" read more clearly than before? | **No change.** The refund side is OFF. The bill makes "tap less, bounce more" true, but nothing on screen says so (CD3-04). |

**G2, the near-empty case:**
- **38 of 39** billed re-lights happened below 20 % fuel, in scrambles and recoveries.
- **10 of 130 presses (7.7 %)** were billed down to the floor (`boost_relight_min_left` 1.0, which leaves 0.76 after the same tick's drain). They delivered **3-5 thrust ticks (25-42 ms)**, where the pre-WK-128 counterfactual is 7-23 ticks.
- **4 of those 10 sputters were followed by the presser's death within 3 s.**
- A 25 ms burst is not "a sputter, never a dead button" (the Tuning comment). On a couch it is a dead button, at the worst possible moment: the gauge shows a sliver, you press, and nothing happens.

**Verdict: SHIP WK-128, with one S-sized FIX (CD3-04).** It does not change Brawl pacing: the A/B had a human self-KO share of 48 % OFF vs 33-49 % ON.

---

## Findings (numbered; P / size; owner; WK mapping)

### CD3-01 [P1][M] Brawl stages are 8 s blowouts on the default circuit, and ~40 % of human deaths are self-inflicted
- **Where:** BRAWL → MEADOW MILE (the first arena card, which a naive group takes) with default rules (1 life, first to 10).
- **Evidence:**
  - Median stage 8.4 s, first death 2.8 s, 4 of 27 stages under 5 s.
  - Human self-KOs were 33 % / 49 % / 48 % of deaths across three matches. Examples: Clover Steps, Sunny Shoulders and Two Hills had two pads off the left edge at 1.1-2.6 s (`m2/stats.json`).
  - Interstitials are 5.0 s per stage. CD2 was 11.6 s and 18 % with the same driver on a different arena mix.
- **Why it matters:** the fantasy is "fight, get launched, claw back, smash". With a 2.8 s first death and drain-all supers next to voids, the newcomer's arc is "fly at someone, super, miss, gone". Ghosts make that bearable, but the living fight is short.
- **Direction (game-designer, measured with HumanSim seats rather than bots):**
  - Run a one-variable ladder on stage length and the self-KO share:
    1. the owner's +25 % knockback (2026-07-19) back to 1.0×, as a test;
    2. a fuel floor after a missed super (e.g. the super leaves 15 fuel when it hits nothing within its 0.45 s window);
    3. a wider blast margin on MEADOW MILE's void arenas (Islands Void, Twin Chasms, Hill and Dale).
  - Target: median stage ≥ 12 s and human self-KO ≤ 25 % without hurting the 70 % super-kill share. This is a new WK-20d (WK-57's arena scorecard tool would feed it).
- **Size:** M.

### CD3-02 [P1][S] Rocketball kickoff goals are 16-26 % within 4 s of GO with human seats: WK-131 GO
- Evidence and numbers are in re-judge §4. All 5 early goals came from human seats or a human's team, so bot pathing is not the cause. **Merge into WK-131** and start it.

### CD3-03 [P1][M] A CPU teammate's own goal decided a Rocketball match
- `rb/end.png`: "WINNING GOAL · OWN GOAL BY ZIGGY". The CPU scored 2 own goals in an 8-goal match (2/19 over two matches).
- At the couch, losing on your bot partner's own goal is the most "this game is dumb" moment possible.
- **Merge into WK-108b.** Add an Accept line: "0 CPU own goals in the final 2 points" or a goal-mouth clear rule.

### CD3-04 [P2][S] WK-128: a near-empty re-light is a 25 ms dead button, and the bill is invisible
- **Evidence:** §5 G2. 10/130 human presses gave 3-5 ticks; 4 preceded the presser's death within 3 s.
- **Direction (gameplay-programmer + ui-ux-designer):**
  - (a) Cap the bill so a re-light always delivers at least ~0.1 s. Either raise `boost_relight_min_left` to about 3.0, or bill `min(bill, 0.5 x fuel)`. Feathering the last 10 % of a tank is worth almost nothing as an exploit.
  - (b) Flash the billed chunk on the fuel gauge when a re-light is billed, so "tapping costs fuel" is taught by the HUD. This pairs with WK-99's gauge work.
- Re-check invariant #14 if (a) changes the floor. **New item.**

### CD3-05 [P2][S] Rocketball rallies got short (median 5.7-7.0 s, below the 8-20 s band)
- CD2 was 8.8 s. Most of the drop is the kickoff goals (CD3-02). **Fold into WK-131's measurement:** re-measure the median after the kickoff rule, and only act if it is still under 8 s.

### CD3-06 [P2][S] Flight School lesson 4's lethal void reads as a safe mint meadow
- `fs_07_t4.png`: the bottom half is flat pale green, with bushes and fences floating at pad height and no ground under them.
- The lesson says "touch every pad", but nothing says "falling = start over". A newcomer reads green as grass.
- **Merge into WK-85** (same mint-fill family CD2 flagged). Paint a readable drop (cliff edge, haze, a sky gradient below) and anchor or remove the floating props.

### CD3-07 [P3][S] The flair-unlock toast lands on top of the lobby cards
- `rb_01_lobby.png`: "FLAIR UNLOCKED BUBBLEGUM JETSTREAM" in outline text, with no panel, across the P2 and P3 names, and it doesn't say whose unlock it is. It clears in about 2 s.
- **Merge into WK-52** (the "unlock toast becomes a banner card" item already exists).

### CD3-08 [P3][S] A ghost can disappear behind terrain
- `m1/03_ghost1_s1.png`: the P2 ghost is parked under the main floor, with its body hidden by the platform art and only its tag peeking out below. (My driver steered it there, but a real player will too.)
- **Direction:** draw ghosts above terrain, or push them out of solid geometry like the bot-ghost spacing does. New small item for the ghost lane, which can fold in with the art grade's CPU-plate fix.

### CD3-09 [P3][S] Sports copy and cards
- The Dropshot lobby rules strip says "FIRST TO 6 GOALS" (`ds_01_lobby.png`). It should say points.
- The court select still shows "A FIGHT!" with old dark-stadium thumbnails and half-empty cards (`rb_04_court.png`).
- **Merge into WK-117** (sports words) and **WK-65** (painted court cards).

### Re-confirmed open (no new finding)
- **WK-13:** TRIALS is still the default focus.
- **WK-42:** HUD cards show behind the victory screens.
- **WK-126:** recommend close (§6).
- **WK-123b:** structurally addressed, co-op unverified.

---

## Fantasy-fit check

| Check | Answer |
|---|---|
| Airborne and using the jetpack? | **Yes.** Humans were airborne 100 % of alive time and boosting 20-33 % of it. Sports is all flight. |
| Do distances require boost or super? | **Yes.** Flight School now proves it per lesson, and Brawl arenas have real gaps. |
| Is the super the decisive kill move? | **Yes.** 70 % of credited Brawl KOs, and the attacker-coloured +1 burst makes it legible. |
| Constant motion, no camping? | **Yes.** Nobody settles. If anything there is too little calm. |
| Looks and feels like the references in motion? | **Sports: yes,** Rocket League by way of TowerFall. **Brawl: Duck Game-short stages, without Duck Game's 1-second restart.** 8 s of fight, then 5 s of interstitial. |
| Would a first-time group want "one more round"? | **For sports, yes.** Close scores (6-5, 6-4), a payoff card and a 2.67 s restart make REMATCH the obvious press. **For Brawl, probably** while ghosts are new; the pacing (CD3-01) decides whether that lasts past the third match. |

## Producer re-rank suggestion
1. **WK-131** (GO, from CD3-02).
2. **CD3-01 as WK-20d:** Brawl stage length with human seats. This is the critical path for "a proper fun game".
3. **WK-108b** with the CD3-03 Accept line.
4. **CD3-04** (S, can ride with WK-135, which touches the same fuel ledger).
5. Then the P2/P3 merges.
