# WK-CD4: Creative Director cold playthrough #4 (2026-11-15)

**Build:** pinned snapshot of `weekend/polish` @ **eedaa65** (`git archive HEAD` into my scratchpad plus a copy of the import
cache; nothing removed; `--gb-port=9115` passed by `run_game.ps1`). It includes WK-20e (spawn truce + carousel fix), WK-148b,
WK-65, WK-131a gates **at 3.0 s**, WK-28a/b, WK-33, WK-139/140/142, WK-44, WK-29, WK-151 and WK-37f.
**3c35d59 (gates at 3.5 s) landed after the pin.** I re-ran Rocketball with `Tuning.sports_gate_open_s = 3.5` set at runtime
to approximate it. That approximation lacks 3c35d59's GoalZone latch tweak.

**Rig:**
- Rendered 1920x1080 on port 9115, software GPU, 26-48 fps. Every duration below is **game time**: `round_stats.length_s`,
  `phase_log.tick_s`, or the ball clock (`last_goal().ball_t`). None is wall clock.
- At the same time, another agent ran a headless batch and a rendered game on port 9116. My one WK-93 recording ran with my game
  stopped, which made 3 agents.

**Couch group:** **pad 1 = P1, pad 0 = P2 (Brawl) / P3 (sports), keyboard = P3 (Brawl) / P2 (sports)**, plus 1 CPU L2.
The humans were driven by **HumanSim4**, which is CD3's HumanSim3 unchanged plus a counter for truce-locked presses. Its source
is in `tools/out/wk/CD4_data/HumanSim4.gd.txt`. The same driver means the same biases (reckless near edges, a keyboard seat
quantised to 8 directions). Treat its numbers as a newcomer stress case, comparable to CD3's.

**Route:**
- Title → mode select (lands on BRAWL) → lobby (3 devices join, lock in, READY) → arena select → **MEADOW MILE** Brawl to 10.
- REMATCH. Stage 1 of the rematch was a staged padlock test; it and stage 2 are excluded from the numbers.
- QUIT TO MENU (lands on mode select) → **Rocketball** 2V2 CENTER PITCH. 3 matches with gates at 3.0 s, then 2 matches at 3.5 s.
- **Trials → GOAL RUSH** (ball goals), then a forced circuit end.
- **WK-93 recording** `CD4_meadow`: bots 2,2,3,3, MEADOW MILE circuit, 30 s of combat.

**Evidence:**
- Screenshots `tools/out/wk/CD4_01..43*`. I looked at every one I cite.
- Data `tools/out/wk/CD4_data/` (m1, m2, rb1-rb5 json, plus the analysis scripts).
- Recording sheets `tools/out/wk/CD4_rec_meadow/`.
- `settings.cfg` was backed up and restored. Its md5 matches the original.

**Not judged:**
- **Audio, by ear.** That includes the dry click, the gate-open whistle and the taunt. This is now the fourth CD pass that cannot
  hear the game. See the closing note.
- **Real-hands feel.** Software GPU, simulated pads.
- **Dropshot**, beyond the lobby.

---

## Verdict

**Is it now a fun, conventional couch party game? Yes. Verdict: SHIP for the front end, sports and Trials. Brawl is a FIX,
but no longer a P1.** I found no P0 and no P1 this pass.

**Front end: SHIP, at the Mario Kart / TowerFall bar.**
- Boot to first bounce took 5 presses. Each friend joins with A and locks with A.
- Arena and court select are now the strongest screens in the flow: a painted preview panel, "EASY · 20 ARENAS", rule and roster
  chips (`CD4_05`, `CD4_20`).
- The B ladder steps back correctly. QUIT TO MENU lands on mode select. The end screens share one kit with an A/B footer.
- A naive press of **A** on READY TO FIGHT! also proceeds, which is what a newcomer tries first.

**Sports: SHIP.**
- The kickoff gates did what WK-131 promised:
  - 0 goals before the open, in 46 kickoffs.
  - At 3.5 s: **0 of 18 goals within 4 s of GO**, and the median rally is **10.2 s**, inside the 8-20 s band.
- Team-framed tags and the persistent CPU tag make "who's on my team" readable.
- The end card still sells REMATCH.

**Trials: SHIP.**
- The gold goal cage reads as a goal net. The clouds under the deck read as falling into sky.
- CIRCUIT CLEAR! with NEXT CIRCUIT is a real payoff (`CD4_38`).

**Brawl: clearly better, and the spawn truce worked.** Against CD3:
- Human self-KOs fell from 33-49 % to **23 %**.
- Opening self-KOs fell to **0**.
- First death moved from 2.8 s to **4.2 s**.
- The median stage grew from 8.4 s to **10.1 s**.
- The super is still the kill on **65 %** of credited KOs.

**Biggest remaining problem: on the default path, Brawl shows its weakest, least varied face.**
- MEADOW MILE is a 20-arena **fixed** order, and **every match and every REMATCH restarts at arena 1**. A first-to-10 uses about
  13 stages, so a group replays the same 13 arenas in the same order. The wild tail of the arc never appears: arenas 15-20,
  including the windmill, hay bales and carousel. Both of my matches ran Grassy Expanse → Islands Void → The Cliff → … in the
  identical order.
- The back half of that run is void arenas where the living fight lasts **5-6 s**. Eight of 25 stages ran 6.3 s or less.
- Islands Void, the 2nd arena of every match, still paints its kill zone as a **flat mint meadow** (CD4-02).
- So the default circuit is long, careful stages up front, then quick void stages, then the same again on REMATCH. That is
  fine for match one; it is what decides whether a couch plays Brawl a third time.

---

## Re-judge table

### MEADOW MILE Brawl (25 stages, 3 human-style seats + CPU L2)

Same driver and arena path as CD3.

| Measure | CD3 | **CD4** | Note |
|---|---|---|---|
| Median stage length | 8.4 s | **10.1 s** | Mean 11.8 s; 2 of 25 under 5 s. Bimodal: stages 1-5 run 14-43 s, the back half 4.5-14 s. Target was ≥ 12 s, not met |
| Human self-KO share of human deaths | 33 % / 49 % (48 % with the bill off) | **23 %** (13/57) | Meets the ≤ 25 % target. Opening self-KOs (< 3 s): **0**. The 13 went: void 8, bottom 4, top 1 |
| First death (median) | 2.8 s | **4.2 s** | m1 4.0, m2 4.5 |
| Super as the last smash on credited KOs | 70 % (35/50) | **65 %** (37/57) | Still the decisive move |
| Interstitial per stage | 5.0 s | **4.8 s** | About 32 % of a Brawl at the median stage |
| Dead-frame share per human seat | median ~25 %, worst 58 % | **12-34 %** (median 19.5 %) | Ghosts keep the dead busy |
| Airborne / boosting share, living humans | 100 % / 20-33 % | **100 % / 21-34 %** | Fantasy intact |
| Super presses dropped by the truce | n/a | **55 of 174** sim super attempts (32 %) | See CD4-04 |
| Winners | CPU 10 once, humans twice | CPU 10-8-8-7, then P1 10-9-7-3 | Competitive |

### Rocketball, CENTER PITCH 2V2 (RED P1 + P3 pads, BLUE P2 keyboard + CPU ZIGGY)

| Measure | CD3 (no gates) | **CD4, gates 3.0 s** (snapshot, 28 goals) | **CD4, gates 3.5 s** (runtime knob = 3c35d59, 18 goals) |
|---|---|---|---|
| Goals within 4 s of GO | 16-26 % | **4/28 = 14 %**, all gate-drop goals at 3.42-3.96 s | **0/18 = 0 %** |
| Goals before the open | n/a | **0** | **0** |
| Goals within 1 s of the open | n/a | 4 | 1 (4.29 s) |
| Median rally (ball clock) | 5.7-7.0 s | **9.0 s** | **10.2 s** |
| Own goals | 4/19 | 5/28 (1 by the CPU) | **8/18 (0 by the CPU)** |
| Gate contacts (NOT YET!) | n/a | 15 in 28 kickoffs | n/a |

- **Own goals.** Most came from the 8-direction keyboard seat (P2 had 3 in one match: "WINNING GOAL · OWN GOAL BY P2",
  `CD4_41`) and from the driver's crude approach angle. CD3 saw the same pattern.
- **Read on sports:** the gates fixed the kickoff and lengthened rallies. The own-goal share is a watch item, not a finding (see
  CD4-09).

---

## Readability for a newcomer

### Kickoff gate

**It reads on the first kickoff. Later kickoffs read mostly through the padlock.**
- **Stage 1:** a gold rule strip says "GOALS OPEN 3 SECONDS AFTER KICK OFF" ("3.5 SECONDS" at 3.5), and every mouth carries a
  padlock with a draining ring (`CD4_21_kick_0`, `CD4_40`). A newcomer gets it.
- **Later kickoffs** (`CD4_24_kick2_0`) have no text. The cue is the padlock badge and its ring.
- **The striped boom pole reads as part of the goal frame, not as a barrier.** The pole is thin and yellow/white against a yellow
  goal trim.
- **The open moment is weak on stage 1.** "GOALS OPEN!" swaps into the rule strip, which has already faded with the legend to about
  25 % alpha, so the call is barely visible (`CD4_21_kick_3`). On later kickoffs only the whistle marks it, which I could not hear.
- **A CPU keeper parks on its own padlock.** ZIGGY and the ZIGGY CPU tag cover the badge and the ring (`CD4_40`).
- See CD4-05.

### Spawn padlock

**It reads as "locked", but not as "why" or "how long".**
- **Staged test:** I held X at GO (`CD4_15_padlock_0..2`). A 48 px cream disc with a gold padlock sits beside P1's head for the
  whole 1.3 s, and the aim arrow is greyed.
- **What a newcomer can read:** that the super is locked.
- **What nothing says:**
  - *why* it is locked. The spawn blink is subtle in stills and at the wide camera.
  - *how long* it lasts. There is no ring or timer, unlike the goal gate's draining ring.
  - The legend never mentions it.
- **Scale:** in play, a third of the driver's super attempts landed in that window. That is frequent friction of the "my super
  doesn't work sometimes" kind.
- See CD4-04.

### Trials nets, goals and backdrops

**They read.**
- **The goal:** the gold cage (mesh, gold frame, silver pillar) reads instantly as a goal at both floor height and top-corner
  height (`CD4_31`, `CD4_34`).
- **The drop:** clouds below the decks say "drop into sky" (WK-85a works).
- **Scoring:** SOLVED! plus the net glow confirms a goal (`CD4_36_trgoal_3`). One nit: the ball ricochets back out over the cage
  after scoring.

---

## Findings

### CD4-01 [P2][S] MEADOW MILE restarts at arena 1 every match, so its last 6-7 arenas never appear

- **Where:** Brawl → MEADOW MILE (the default and first card), any first-to-10, and REMATCH.
- **Evidence:**
  - m1 and m2 played the identical sequence: Grassy Expanse, Islands Void, The Cliff, Twin Chasms, Meadow First Hop, Clover Steps,
    Sunny Shoulders, Three Meadows, Daisy Ring, Long Meadow, Hill and Dale, Bluff Line, Two Hills, Meadow Spine
    (`CD4_data/m1.json`, `m2.json`). The recording also opened on Grassy Expanse.
  - `levels/circuits.json` meadow_mile is an ORDERED 20-arena loop ("a first-to-10 session never repeats"). That holds within a
    match, but no match reaches stepping_bloom, windmill_meadow, hay_bales, high_pasture or the carousel tail.
- **Why it matters:**
  - Variety is what makes a couch say "one more".
  - The arc is mild → wild, so the arenas you never see are the wild ones.
  - It also sets the pacing shape: long, careful mild stages up front, then quick void stages, then a reset.
- **Direction (level-designer + gameplay-programmer):**
  - REMATCH (and the next play of the circuit in a session) **continues from the arena after the last one played**, wrapping at 20.
  - Alternatively, start at a random point in the first third and keep the order.
  - Keep stage 1 of the very first match on Grassy Expanse, so the legend lands on the gentle arena.

### CD4-02 [P2][M] Islands Void (arena 2 of every Brawl) paints its kill zone as a flat mint meadow with floating props

- **Evidence:**
  - `CD4_15_padlock_0/2`, rendered, and recording frames `CD4_42_rec_islands_f800.jpg` / `CD4_43_rec_islands_f905.jpg`.
  - The bottom ~40 % of the screen is flat pale green, read naturally as grass.
  - Bushes and fences float near the deck line, in mid-air between decks (`CD4_43`: the fence at x≈525 and the bush above the
    centre deck).
  - Goats and ghosts fly through it, and the green KO burst fires at the bottom edge of that "lawn".
- **Why it matters:**
  - This is CD3-06's mint-fill problem. WK-85a fixed it **for Trials only** ("meadow props skipped on Trials").
  - In Brawl, the void is where 8 of the 13 human self-KOs happened.
  - "I fell on the grass and died" is the newcomer complaint no spec owns.
- **Direction (art pipeline + level-designer):**
  - Apply the WK-85a sky drop (hills fade to mist, then deep sky, with a cloud bank) to Brawl void arenas, starting with Islands
    Void.
  - Skip or anchor the floating meadow props as Trials does.
  - Check the other MEADOW MILE void arenas with the same eyes. I only saw this one rendered.

### CD4-03 [P2][M] Brawl's back-half stages are 5-6 s, so the median stays under 12 s

- **Evidence:**
  - Stages 6-13 of the circuit: Clover Steps 8.2 / 6.3 s, Three Meadows 11.0 / 6.1, Daisy Ring 11.8 / 5.9, Long Meadow
    10.1 / 6.3, Hill and Dale 5.7 / 6.3, Two Hills 4.5 / 5.5.
  - Stages 1-5 ran 14-43 s. Median 10.1 s overall.
  - These short stages are mostly **credited** KOs (supers landing), not self-destruction. That is the game working, and it is
    why this is no longer P1.
- **Why it still matters:** with 1 life per stage, the "launched, claw back, smash" arc needs room. WK-20d measured victim recovery
  at 65 %, which helps. On void arenas it still rarely happens.
- **Direction (game-designer):** the spec's next rungs, R5 margins and R6 catch shelves, aimed at the back-half void arenas, measured
  with HumanSim seats.
  - Pair it with CD4-01: rotating the start point already changes what a session feels like.
  - Don't touch the spawn truce. It is the reason opening self-KOs went to 0.

### CD4-04 [P2][S] The spawn padlock says "locked" but not why or how long, and a third of the driver's super presses hit it

- **Evidence:**
  - `CD4_15_padlock_0..2`.
  - 55 of 174 driver super attempts were truce-dropped (`sim_stats.locked_presses`).
  - The legend and HUD never mention the truce.
- **Direction (ui-ux-designer):**
  - Give the badge the **same draining ring the goal gate uses** (one visual language: "padlock + ring = opens when the ring
    empties").
  - Optionally strengthen the spawn blink at the wide camera.
  - No new text is needed if the ring exists.

### CD4-05 [P2][S] Kickoff-gate cues get covered or faded at the moments they matter

- **(a) "GOALS OPEN!" is barely visible.** It is drawn in the stage-1 rule strip after that strip has faded with the legend
  (`CD4_21_kick_3`). Pop it as its own word burst at full alpha, or un-fade the strip for the call.
- **(b) The CPU keeper hides its own gate.** It parks on the padlock badge, and its tag sits on top of it (`CD4_40`). Lift the badge
  above goats, or offset it to the top of the mouth.
- **(c) The striped pole reads as part of the goal trim.** If the art lane touches it again, give it a contrasting colour (red and
  white stripes against the yellow trim).

### CD4-06 [P2][S] The Rocketball stage-1 legend hides goats at kickoff

- **Evidence:**
  - `CD4_40`: P3 (orange) flew up into the top-docked legend and is hidden behind the SUPER-SMASH chip and the rule strip. Only a
    sliver of its tag shows.
  - The legend only dims after the first touch (WK-141), and the kickoff toss sends goats straight up into that band.
- **Where:** UX4-10's concern, now relocated rather than solved.
- **Direction:** draw goats and tags above the legend, or start the legend at the dimmed alpha whenever a goat overlaps it.

### CD4-07 [P3][S] Front-end nits UX4 didn't list

- **(a)** The Brawl and sports lobby footers show pad glyphs only, even with a keyboard player seated (`CD4_03`, `CD4_19`).
  Arena select shows "A / ENTER" in the same situation (`CD4_05`), so CC-1.6's mixed-couch rule is applied inconsistently. The
  per-panel prompts are correct.
- **(b)** The FLIGHT SCHOOL shelf card crops the goat to a pink blob at the top edge (`CD4_29`).
- **(c)** The Trials objective panel jumps from screen centre to the top-left mid-course (`CD4_35` → `CD4_36_trgoal_3`).
- **(d)** Sports Victory: a live P1 tag peeks over the top edge of the stats panel (`CD4_22`).
- **(e)** Trials end: the in-world goat sits right behind the celebration goat (`CD4_38`). Dim the world more, or hide the players.

### CD4-08 [P3][S] Trials ball ricochets back out of the cage after a goal

- **Evidence:** `CD4_36_trgoal_3`. SOLVED! fires while the ball is already flying back over the cage top.
- **Direction:** damp the ball inside the cage on solve, as the sports goal does, so the net "catches" it.

### CD4-09 [watch] Sports own-goal share

- **Evidence:** 13 of 46 goals were own goals (5/28 at 3.0 s, 8/18 at 3.5 s). Only 1 was a CPU's. Most came from the keyboard seat
  and the driver's crude approach.
- **Why it's a watch item:** at the couch, real players aim better. If the WK-131 Accept or a real session shows more than 25 %
  own goals, revisit the deflection/credit windows. No action from this pass.

### Re-confirmed closed since CD3
- **Kickoff goals:** WK-131 at 3.5 s gives 0/18.
- **Opening self-KOs:** WK-20e, 0 in 25 stages.
- **Ghosts in terrain:** WK-37f. None seen in recording or play.
- **Front end:**
  - WK-13: BRAWL is the default focus.
  - WK-42/139: no HUD behind the end screens, and one button kit.
  - WK-60/65: arena and court select look like a shipped game.
  - WK-144: quit lands on mode select.
  - WK-142: the Trials celebration.
- **Sports readability:** WK-119/150 team tags; the CPU tag persists.
- **Ghost-tag clutter:** UX4-23 is fixed in what I saw.

---

## Fantasy-fit check

| Check | Answer |
|---|---|
| Airborne and using the jetpack? | **Yes.** Living humans were 100 % airborne and boosting 21-34 % of the time. Sports is all flight. |
| Do distances require boost or super? | **Yes.** Meadow decks are split by voids, and the Trials goals sit at top-corner height. |
| Is the super the decisive kill? | **Yes.** It is the last smash on 65 % of credited Brawl KOs, and the recording shows 7 kills from 10 supers in 30 s. |
| Constant motion, no camping? | **Yes.** In sports one RED pad seat hung near its own mouth (driver), which is not a game issue. |
| Looks and feels like the references in motion? | **Sports: yes.** **Brawl: Duck Game-short rounds with a TowerFall-length score card.** It reads well; the default circuit repeats. |
| Would a first-time group want "one more round"? | **Sports: yes, REMATCH is the obvious press. Brawl: yes for the first rematch.** CD4-01/03 decide the third. |

## Producer re-rank suggestion
1. **CD4-01** (S): rotate the circuit start on REMATCH. This is the cheapest change to how Brawl sessions feel.
2. **CD4-02** (M): the Brawl void sky drop, starting with Islands Void.
3. **CD4-04 + CD4-05** (S, one UI slice): padlock plus ring as one language; gate cues not covered or faded.
4. **CD4-03** (M): WK-20d R5/R6 on the back-half void arenas.
5. **CD4-06**, then the P3s.

**Closing note for the director:** four creative-director passes in a row have marked audio "not judged by ear":
- the bleats;
- the gate whistle;
- the dry click;
- clipping (the master limiter landed in WK-121).

The studio has no way to hear its own game. Before anything is called shipped, someone should run a loudness and frequency check
on a recorded match mix. A short `record_match` capture with audio, plus an LUFS / peak / spectral report, would at least turn
"sounds fine?" into a number.
