# WK-CD6: Creative Director cold playthrough #6 (2026-11-16)

**Build:** pinned snapshot of `weekend/polish` @ **6bbffea** (includes 83d92d9 WK-169c: showdown hush/stings/bell, gold card frames,
golden tank art, CPU golden-seek latch). `git archive HEAD` into my scratchpad plus a copy of the import cache. Commits that landed while I
played (WK-175 rendered checks 203d86d, **WK-183 sports fuel arc adbb6d6**, its ux FIX 0378863) are **not** in what I judged.

**Rig:**
- Rendered 1920x1080 on port 9144, **software GPU** (still). Every duration is **game time** (`round_stats.length_s`, `round_clock`,
  ball clock). Two other agents ran Godot meanwhile (9143 + a headless batch), so the game ran at about 0.7x real time.
- One WK-93 recording (`CD6_showdown`, bots 3,3,3,3, RIVER SPLIT, 45 combat s, `-Eliminate 2,3` so every stage becomes a 1v1 that can
  reach a showdown), recorded with my game stopped. Audio measured with `tools/out/wk/WK-79a_scripts/measure_run.py`.
- `settings.cfg` and `save.json` backed up first. Afterwards the settings diff was exactly my 4 Brawl + 2 sports matches, so I restored
  it (md5 matches the original). `save.json` was unchanged.

**Couch group:** Brawl = **pad 1 P1 POGO, pad 0 P2 BUTCH, keyboard P3 ZIGGY + CPU PUFF L2** (the CD5 seats). Dropshot = **RED: P1 pad 1
POGO + P3 keyboard BILLY; BLUE: P2 pad 0 BUTCH + ZIGGY CPU L2**. Humans driven by **HumanSim5g** (= CD5's HumanSim5 plus the
pre-registered WK-169 golden-seek layer, inert when no golden bubble exists; `tools/out/wk/wk169b2_batch/HumanSim5g.gd.txt`), so the
numbers compare with CD3-CD5. Trials was driven by hand (scripted pad input, human-style aim).

**Route:** Title → mode select → Brawl lobby (3 devices join + lock, READY TO FIGHT) → MEADOW MILE to 10 → REMATCH → to 10 →
REMATCH (a staged match point for the CC-10.2 mash test; it mashed straight into a 4th match, which I played out) → B, B → mode
select → **Dropshot** lobby (rejoin) → SUNSET BEACH to 6 → QUIT → **Trials** → GOAL RUSH courses 1-3 → pause → hold QUIT → Brawl
1P + 3 CPU and Rocketball 1v1 for the WK-175 feel check → relaunch for a RULES-panel check.

**Evidence:** screenshots `tools/out/wk/WK-CD6_*.png` (every cited one looked at) and the bursts/sheets beside them; data
`tools/out/wk/CD6_data/` (m1, m2, m4, ds1, phases_m3, bank_*, hs175_*, rb175_* json, the watcher logs, and every harness script as
`.txt`); recording `tools/out/wk/CD6_rec_showdown/` (sheet, sheet_overlay, `sd.png` dense showdown span, 3 full frames, data.json,
audio.wav; raw frames left behind with the snapshot, see the closing note).

**Not judged:** audio by ear (6th pass in a row); real hands; frame pacing (software GPU). Rocketball only as part of the WK-175 check.

---

## Verdict

**Is it still a fun, conventional couch party game? Yes. Would I ship it? Yes: SHIP on every mode I played.** No P0, no P1.

| Mode | Verdict | One line |
|---|---|---|
| **Front end** | **SHIP** | Title → first bounce in 5 presses; mixed glyphs on every shared prompt; focus restored on return; RULES helper line (WK-171) reads. One P2 on end-screen mashing (CD6-05) |
| **Brawl** | **SHIP** | Numbers held (table). SHOWDOWN reads as an event and caps the worst tails (max wait 25.6 s, CD5 37 s). But it does not lower the dead share, and the golden race is a coin flip that decides the stage (CD6-01..04) |
| **Dropshot** | **SHIP** | A 6-4 that was the most kinetic match of the session (boost 70-78 % of the time). The courts don't look like their cards (CD6-06) |
| **Trials** | **SHIP** | GOAL RUSH: WK-158 (b)(c) and WK-159 hold. The ball now rests in the cage after SOLVED! |
| **WK-175 WR gate** | **FIX** (2 feedback items, no tuning) | See the "WK-175 feel check" section |

**Biggest remaining problem: the SHOWDOWN is a good climax with a bad tiebreak.**
- When the gold is grabbed, **the holder won the tail 5 of 5 times**.
- **3 of those 5 grabs came within 0.3 s of the bubble going live.** Both goats were already on top of it, so the "race" was decided by
  where you happened to be floating when it appeared, not by flying.
- When nobody grabs it (3 of 8 drops), the showdown fizzles. The gold sits there and the stage ends some other way.
- So it reads as a **climax in the banner and a gimmick in the outcome**. The fix is already built and sitting OFF: GOLD SURGE
  (`showdown_drop_arm_s`), see CD6-01.

**Being dead does not feel shorter on average, only in the worst case.** The median human seat was dead **~29 %** of combat (CD5 ~25 %),
and the worst seat **38 %** (CD5 43 %). The showdown only triggers in 18 % of stages. Most dead time is the 3-alive middle of a stage and
sudden-death duels, and the showdown touches neither (CD6-03, CD6-04).

---

## Re-judge tables

### MEADOW MILE Brawl (38 stages, 3 natural matches, 3 HumanSim5g seats + CPU L2)

| Measure | CD4 | CD5 | **CD6** | Note |
|---|---|---|---|---|
| Median stage length | 10.1 s | 9.4 s | **10.9 s** | Mean 12.2 s. Per match 9.7 / 10.1 / 12.6 s |
| Human self-KO share of human deaths | 23 % | 16 % | **17 % (16/95)** | m1 20 %, m2 19 %, m4 12 % |
| Opening self-KOs (< 3 s) | 0 | 2 | **1** | |
| First death (median) | 4.2 s | 4.5 s | **4.3 s** | |
| Super as the last smash on credited KOs | 65 % | 62 % | **59 % (59/100)** | 74 / 46 / 59 % per match. Still the decisive move |
| Stages where somebody died but nobody was credited | n/a | 0/21 | **0/38** | |
| Dead share of combat per human seat | median 19.5 % | median ~25 %, worst 43 % | **median ~29 %, worst 38 %** | Seats: 14/22/36, 38/34/24, 35/29/18 %. CD6-03 |
| Human waits (a death that didn't end the stage) | | | **n=62, median 5.2 s, p90 12.7 s, max 25.6 s; 2 over 15 s** | CD5's worst was a 37 s River Split duel |
| Airborne / boosting share, living humans | 100 % / 21-34 % | 100 % / 22-35 % | **100 % / 26-36 %** | Fantasy intact |
| Winners | | PUFF 10; P2 10 | **PUFF (CPU) 10-8-7-6; P2 10-9-9-7; P3 10-9-9-6** | Close finishes in 2 of 3 |

### SHOWDOWN (WK-169 + 169c), same 38 stages

| Measure | Value | Read |
|---|---|---|
| Stages reaching SHOWDOWN | **7 / 38 (18 %)** | It is a tail tool. Most stages end before it can fire |
| Stage end after SHOWDOWN entry | **median 4.6 s** (2.9, 3.0, 3.2, 4.6, 5.2, 9.0 SD, 12.7) | It does end tails fast |
| Golden drops / collected | **8 / 5 (63 %)** | Uncollected: two spawned 1,580-1,830 px from both fighters (The Cliff, River Split's 2nd), one cancelled by SD |
| Bubble live → grab | **0.05, 0.08, 0.30, 0.57, 3.6 s** | 3 of 5 within 0.3 s: decided by position at reveal. CD6-01 |
| Holder won the tail | **5 / 5** | Kills 1.1-3.7 s after the grab in 4 of 5; River Split's holder won after the tank ran out |
| Golden bubble vs normal bubble, at play zoom | **Distinct** | Gold coin + jerrycan + sparkles vs a pale blue bubble (`CD6_rec_showdown/frame00001020.jpg`, `frame00001128.jpg`) |
| Ghosts vs fighters with the dim on | **Distinct** | Ghosts are pale, translucent and labelled. The 0.10 dim is barely visible on meadow skies |
| Gold card frames | **Read well** | Both fighters' cards get a gold border (`WK-CD6_m1_L1_sdenter_01.png`, `WK-CD6_m4_L0_sdenter_01b.png`) |

### Dropshot, SUNSET BEACH 2v2 (10 points)

| Measure | CD2 | CD3 | **CD6** | Note |
|---|---|---|---|---|
| Result | 6-5 | 6-4 | **RED 6-4** | MATCH POINT RED banner and SERVE! read (`WK-CD6_19_ds_match_sheet.png`) |
| Median rally (ball clock) | 14.5 s | | **18.5 s** | 3 of 10 over 20 s, longest 34.1 s (74 touches). CD6-07 |
| Human boost share | | | **70-78 %** | The most flight of any mode |
| Touches per human | | 74-86 | **103-134** | |

### Audio (WK-93 `CD6_showdown`, 75.7 s, Brawl; measured, not heard)

| Measure | CD5 | **CD6** | Read |
|---|---|---|---|
| Integrated / LRA / true peak | -16.9 LUFS / 5.8 LU / -1.9 dBTP | **-16.2 LUFS / 10.2 LU / -1.7 dBTP** | On target. 7 ≥ -2 dBFS clusters in combat (CD5 2), no clipping. LRA is higher because 6 stage interstitials sit in 76 s |
| Countdown rise | +13.2 LU (louder than any KO) | **+8.4 LU** (n=6) | **WK-170 fixed the order** |
| KO (killed) rise | +6.5 LU | **+9.7 LU** (n=17, includes fixture eliminations) | The KO is now the loudest event |
| Super fired rise | +3.2 median, min -3.6 | **+7.6 median, min -2.2** | Supers cut through now |
| GO rise | +6.5 | **+6.9** | |
| SHOWDOWN entry sting (ka-CHUNK + bell) | n/a | **+6.7 LU** (n=1, EBU momentary, same method) | ~3 LU under the KO, as the spec wants |
| Combat centroid / 2-5 kHz | 893 Hz / -13.2 dB | **1,013 Hz / -13.5 dB** | Slightly brighter overall. The presence band is unchanged; still worth a listen by anyone with ears |
| Music share (gameplay_1) | -9.2 dB | **-10.9 dB** | |

---

## Answers to the WK-169 T12 felt questions

1. **When I died early in a long stage, did the wait feel shorter or busier?**
   - **Busier, yes.** SHOWDOWN!, gold frames, a gold telegraph, GOLDEN TANK! and a star-trailing holder give a ghost something to watch.
   - **Shorter only in the worst case.** The longest wait fell from 37 s (CD5) to 25.6 s, and only 2 of 62 waits went over 15 s.
   - **Not shorter on average.** The median dead share is ~29 %, against CD5's ~25 %. The showdown fires in 18 % of stages. CD6-03.
2. **Did the showdown ever feel like the game ending the stage for us?** **No.** Every showdown stage ended on a real KO (6) or a
   sudden death (1). Nothing ended by fiat. That stays a "no", so the T12 rule is not tripped. But see 3.
3. **Did the golden tank feel fair to the one who missed it?** **No, not when it spawns on top of both of you.** 3 of 5 grabs came within
   0.3 s of the bubble going live, and the holder then won 5 of 5. "I lost by a hair and was dead 1-3 s later" happened. CD6-01.
4. **Could I tell the golden bubble from the others, and the ghosts from the fighters, with the dim on?** **Yes to both.** The dim itself
   is nearly invisible on meadow skies. That's harmless, but it's not doing anything either.

**Climax or gimmick?** A climax in presentation, which is the right call, and audio sits correctly under the KO. In outcome it is a
gimmick about 60 % of the time: either a point-blank coin flip (3/8 drops) or a no-show (3/8 drops). The 2 of 8 drops that made both
goats fly a real distance to a contested gold (River Split's first, Grassy Expanse) were the best moments of the Brawl session.

---

## Readability for a newcomer (new this pass)

- **RULES helper line (WK-171): reads.** "EDITING · P1 · CPUs: How many computer goats join the brawl", and it updates as focus moves
  ("KOs TO WIN: The first goat to this many KOs wins the match"). D-pad down moved focus normally off the first row (WK-174 not seen)
  (`WK-CD6_39_rules_open.png`, `WK-CD6_40_rules_row3.png`).
- **Corner-card stickers (WK-173): no overlap seen** in 30+ combat stills. HURT!/DANGER! hang under the card, not over a goat
  (`WK-CD6_m1_L0_sdenter_03.png`).
- **Trials (WK-158 / WK-159): fixed.**
  - FLIGHT SCHOOL's card shows the whole goat (`WK-CD6_22_trials_select.png`).
  - The objective panel stays top-centre on all three courses I played.
  - On courses 1 and 2 the ball came to rest inside the cage after SOLVED! (`WK-CD6_24_gr_sheet.png`, `WK-CD6_25_c2_sheet.png`).
- **Trials course 3 (THE LONG BALL):** I missed it 3 times. That was my scripted aim: one shot fell into the gap and one sailed over the
  cage. The ball re-spawned silently at the start each time, which a newcomer will understand. Not a finding.

---

## Findings

### CD6-01 [P2][S] The golden race is decided at point-blank, and the holder then wins: turn GOLD SURGE on

- **Evidence:**
  - 5 grabs in 38 stages (`CD6_data/m1.json`, `m4.json`, `showdown.drops` / `tank`): bubble live → grab 0.05, 0.08, 0.30, 0.57, 3.6 s.
  - The holder won the tail 5/5. Kills came 1.11, 2.98, 3.67, 1.18 s after the grab, plus River Split after the tank ran out.
  - High Pasture: PUFF (CPU) grabbed 0.3 s after live and P3 (human) was dead 1.1 s later.
  - This matches 169b-2 G9 (88.6 %) from the other side: the felt answer to T12 Q3 is "unfair".
- **Direction (game-designer → producer):**
  - This is exactly the case WK-169c built GOLD SURGE for (`showdown_drop_arm_s` 1.0, OFF).
  - If the lane-TG re-check lands in R1, flip it.
  - If it doesn't, the CD vote is still to flip it: the felt problem is the 0-1 s after the grab, and that is the window it closes.
  - KNOCKED LOOSE stays the next idea.

### CD6-02 [P2][S] A third of golden drops never become a race

- **Evidence:**
  - The Cliff: d_a 1,579 / d_b 1,830 px, never collected (stage ended 3 s after entry).
  - River Split: the 1st drop sat 1,783 / 1,674 px from both fighters and took 3.6 s. The 2nd sat 1,577 / 1,696 px.
  - Recording (`CD6_rec_showdown/sd.png`, frames 948-1128): the live bubble sat 7 s next to two L3 bots (POGO flew within about
    80-150 px of it at f1020) and nobody took it. The stage ended on POGO's self-KO ("NO KOs!").
- **Read:** the fair point is picked from the authored powerup spawners (3 per meadow arena). When the two goats are close together
  but far from every spawner, "into the gap right between them" becomes "across the map".
- **Direction (game-designer + gameplay-programmer):**
  - Allow a synthetic midpoint (snapped to open air above a deck) when every spawner is more than ~900 px from the midpoint.
  - Re-check the CPU golden-seek reach on L3 (it ignored a bubble that was in reach).

### CD6-03 [P2][M] SHOWDOWN capped the tails but did not lower the dead share

- **Evidence:**
  - Dead share per human seat over 3 matches: 14, 18, 22, 24, 29, 34, 35, 36, 38 % (median ~29 %, CD5 ~25 %).
  - SHOWDOWN fired in 7/38 stages. Max wait 25.6 s (CD5 37 s).
  - With 1 life and first death at 4.3 s in a 10.9 s stage, about a third of combat is structurally spent with at least one ghost,
    before any tail.
- **Direction (game-designer):** the CD5-01 question is still open for the middle of the stage. Candidates that don't touch owner
  rulings:
  - LIVES 2 as the default when 3+ humans are seated;
  - give ghosts a stronger, uncredited influence in the 3-alive phase (L2 RESTLESS GHOSTS is built OFF);
  - accept it as genre-standard and close it with a DECISIONS entry.
  - Measure "dead share per human seat" as the gate, not tails alone.

### CD6-04 [P3][S] Sudden-death duels sit outside the showdown

- **Evidence:** m2 Long Meadow. A 4-way chain at 5.75-6.54 s revived P1 and PUFF (WK-181 behaviour, correct). The SD duel then ran
  **12.6 s** with two ghosts and no showdown pressure (spec §5.3 clears the showdown on SD by design). Stepping Bloom's SD ran 6.2 s
  (`CD6_data/m2.json`).
- **Direction:** let the SD inherit SHOWDOWN after `showdown_delay` (the revived pair is already pre-damaged Lv2). Or accept it: 2 SD
  stages in 38.

### CD6-05 [P2][S] Mashing A blows through the victory screen in ~2 s (CC-10.2, first assessment)

- **Evidence:**
  - Staged match point (scores set to 9-9-9-9).
  - Injected masher: pads 0/1 A + Enter toggling every 50 ms from score 9 until 5 s after MATCH_END.
  - Phase log: **MATCH_END 538.99 → STAGE_INTRO 541.17**, i.e. REMATCH fired **2.2 s** after the winning KO. A new match was already
    in combat by the time I could screenshot (`CD6_data/phases_m3.json`, `WK-CD6_10_cc102_t1s.png`).
  - The rule's letter holds (1.0 s arm plus fresh presses). Its intent ("someone still mashing A must not trigger REMATCH or skip the
    score tally") doesn't: the winner and the final score were on screen for about a second.
  - A celebrating couch mashes. This also skips the winner's payoff for the other three players.
- **Direction (ui-ux-designer):**
  - Arm REMATCH only after the final-score tally has finished (≥ 2.0 s).
  - Then require a press that follows ≥ 0.3 s of no A from that device (a quiet gap).
  - Or make REMATCH a short hold when the press arrives within 3 s of the screen.
  - Same gate on the sports end card.

### CD6-06 [P2][M] Dropshot courts don't look like their cards (recurring since CD1)

- **Evidence:**
  - The SUNSET BEACH card shows palms, sea and a setting sun (`WK-CD6_16_ds_court.png`). In game it's the dark night stadium with
    floodlights (`WK-CD6_17_ds_start_sheet.png`, `WK-CD6_19_ds_match_sheet.png`).
  - All three dropshot levels set `"backdrop": "enclosed"` (`levels/sports/dropshot_{beach,reef,dome}.json`). CORAL COVE and THE DOME
    get the same stadium.
  - CD1 noted "Dropshot's SUNSET BEACH is that same stadium". WK-122 painted the soccer courts, not these.
- **Why it matters:** picking a court is a promise. A newcomer picks the bright beach and gets the gloomiest screen in the game. In the
  mode that plays best, the look is the weakest.
- **Direction (art-director):** three painted court backdrops (beach / reef / dome) on the WK-122 pipeline. Or, as the cheap stopgap,
  re-art the three cards to the stadium they actually are.

### CD6-07 [P3][—] Dropshot rallies are drifting long (watch)

- **Evidence:** median 18.5 s (CD2 14.5 s), 3/10 over 20 s, longest 34.1 s (`CD6_data/ds1.json`). One match, so small n.
- **Direction:** a watch line in the next sports batch. Act above a 20 s median. Pressure nets are a Rocketball rule. Dropshot has no
  equivalent.

### CD6-08 [P3][S] The Dropshot end card doesn't add up

- **Evidence:** BLUE 4, but the POINTS column for BLUE sums to 3. Point 5 had no scorer (`scorer_idx -1`, `CD6_data/ds1.json`)
  (`WK-CD6_18_ds_end.png`).
- **Direction:** credit the last toucher, or add a "team" line under the rows.

### CD6-09 [P3][S] QUIT TO MENU drops every joined player, so switching modes means rejoining

- **Evidence:** after Brawl (3 devices joined), B,B → mode select → DROPSHOT. Only the confirming pad was in the lobby, and pad 0 and the
  keyboard had to press again (`WK-CD6_14_ds_lobby.png`). CC-4.7 only requires CHANGE SETUP / REMATCH to keep the lobby, so this is
  legal. But a couch going "now let's play the volleyball one" pays 2 presses per extra player and a "why am I out?" moment.
- **Direction (ui-ux):** keep joined devices (not goat picks) when the lobby is left via QUIT TO MENU, and clear them only on QUIT TO
  TITLE.

### CD6-10 [P3][S] The world shows through behind the WINNER! title

- **Evidence:** a pink deck strip cuts through "WINNER!" (`WK-CD6_07_m1_end.png`), and a flying goat sprite sits behind the score panel
  (`WK-CD6_08_m2_end_after_mash.png`, `WK-CD6_11_m4_end.png`).
- **Direction:** dim and blur the arena more behind the victory layer, or freeze the camera off the decks.

### Watch items
- **Ceiling clusters 7** (≥ -2 dBFS) in 76 s of Brawl audio (CD5: 2). No clipping, true peak -1.7 dBTP. One for the sound-designer's next
  measure.
- **CPU L2 won match 1 10-8 again.** That's fine against newcomer drivers.

### Re-confirmed closed since CD5

| CD5 item | Status | Evidence |
|---|---|---|
| CD5-01 Brawl spectator time | **Tails fixed, share not** (WK-169). Re-opened as CD6-03 | tables |
| CD5-02 countdown louder than KO; supers sink | **Closed** (WK-170): countdown +8.4 < KO +9.7; super min -2.2, median +7.6 | audio table |
| CD5-04 RULES row unexplained | **Closed** (WK-171) | `WK-CD6_39`, `WK-CD6_40` |
| CD5-06 sticker / chip overlap | **Closed** (WK-173), none seen | stills |
| CD5-07 / WK-174 RULES focus stuck | **Not seen** | `WK-CD6_40` |
| WK-158 (b)(c), WK-159 Trials | **Closed** | `WK-CD6_22`, `WK-CD6_24_gr_sheet`, `WK-CD6_25_c2_sheet` |

---

## WK-175 feel check (spec §9.6): WR wall-only refund gate

**Verdict: FIX, two feedback items, no tuning change.** The numbers say WR is invisible in normal play. The one moment it bit me was
unreadable, so it needs a cue before it ships.

**What I ran (same session, live-flipped `Tuning.refund_gates_on` / `wk175_gate_set = 1`; data in `tools/out/wk/CD6_data/`):**

**1. A bank probe on BUMPER GAUNTLET** (`bank_off.json`, `bank_wr.json`, sheets `WK-CD6_32_{off,wr}_bank_sheet.png`). CPUs frozen, P1 at
(950, 830) with 50 fuel, real pad input:
- the sequence: fly into the left post face → let go → fly into it again → back off more than 400 px → fly into it again.
- **OFF:** 20 bumper refunds (17 of them wall-hug). Pinned at 100 fuel the whole time, and I could have hovered there forever.
- **WR:** the first touch paid +20, as designed. The re-bank of the same face paid nothing (4 blocked). I ran dry 1.5 s later and fell
  into the pit. My planned re-armed bank never happened. The only tell was the corner bar.

**2. HumanSim5g driving P1** (1P + 3 CPU L2, LIVES 3):

| Run | Wall pays | Blocked | Floor pays | zero-fuel-alive max | Deaths | Data |
|---|---|---|---|---|---|---|
| Bumper Gauntlet, 60 s, OFF | 1 | 0 | 17 | 3.75 s | 0 | `hs175_bg_off.json` |
| Bumper Gauntlet, 60 s, WR | 6 | 6 | 14 | 3.40 s | 0 | `hs175_bg_wr.json` |
| Meadow Carousel, 50 s, OFF | 1 | 0 | 10 | 2.25 s | | `hs175_mc_off.json` |
| Meadow Carousel, 50 s, WR | 1 | 0 | 23 | 3.14 s | | `hs175_mc_wr.json` |

**3. Rocketball 1v1, CENTER PITCH,** 75 s OFF then 75 s WR in one match (`rb175_off.json`, `rb175_wr.json`,
`WK-CD6_37_rb_sheet.png`):

| Arm | Wall-hug pays | Blocked | Zero-fuel max | Floor pays |
|---|---|---|---|---|
| OFF | 7 | 0 | 0.24 s | 26 |
| WR | 1 | 4 | 0.39 s | 32 |

Ball refuel was about 25 per arm. The score went 2-0, then 5-2.

**The four questions:**
1. **Do walls still feel like part of the toybox?** **Yes.** A bank pays once, and a carom across different faces keeps paying. Under
   WR the sim actually banked *more* paying bumper walls (6 vs 1), because it wasn't pinned on one. Bots and humans still pinball
   (`WK-CD6_33_bg_wr_*.png`).
2. **Was there a moment I expected fuel from a wall, didn't get it, and it felt unfair rather than learnable?** **Yes, once:** the
   re-bank of the same post (probe 1).
   - Physically it looks identical to the bank that paid: the goat squashes, the flame keeps burning.
   - The only difference is a corner bar I wasn't watching. I dropped into the pit without knowing why.
   - The rule ("a wall pays once, fly away to re-arm") is learnable, but the game never tells you it exists.
   - It is rare in natural play (6 blocked contacts in 60 s for the sim, no deaths).
3. **Is the floor loop exactly as before?** **Yes.** In every WR run, `refunds_blocked_rearm` equals `refunds_blocked_rearm_wall`
   (6 = 6, 4 = 4, 2 = 2), so not one floor contact was blocked. Tier-floor pays are in the same range as OFF (14-32 per run). The
   §9.5 drop test already showed the floor ladder is tick-identical.
4. **Sports: is anyone starved or stuck near a wall?** **No.** Zero-fuel max was 0.39 s, wall-hug pays fell from 7 to 1, and nobody was
   parked on a wall in the stills.
   - But on this snapshot **Rocketball shows no fuel at all**, so in sports WR is not learnable by sight. A goat that "suddenly drops off
     the wall" has no visible cause.
   - WK-183 (sports fuel arc + refuel tick, adbb6d6, ux FIX 0378863, refuel_ding in progress) landed after my snapshot and is the right
     answer. I have not judged it.

**FIX list (both are the spec's own fallback rung 1, "build the refuel cue first, then re-ask"):**
1. **Make a wall refund audible and visible in Brawl, and make a blocked one feel different.**
   - A short refuel ding plus a flame flare on a *paying wall-class* contact. That's rare enough not to become noise; floors stay silent
     as today.
   - A dull "tok" with no flare on a blocked re-bank.
   - Then a blocked bank teaches itself.
   - The WK-183 `refuel_ding` asset can be reused.
2. **Don't flip WR in sports until WK-183's fuel arc and refuel tick ship and pass their ux re-check.** Then repeat Q4 with the gauge
   visible.

After those two, I expect Q2 to flip to "no" and the gate can ship at `wk175_wall_rearm_px` 400. Nothing I saw argues for 350.

---

## Fantasy-fit check

| Check | Answer |
|---|---|
| Airborne and using the jetpack? | **Yes.** Living humans 100 % airborne; boosting 26-36 % in Brawl, 70-78 % in Dropshot |
| Do distances require boost or super? | **Yes.** Meadow voids, and the best showdown moments were cross-map flights to the gold |
| Is the super the decisive kill? | **Yes.** 59 % of credited KOs, and the golden tank is super frequency. The super is also audible now (+7.6 LU) |
| Constant motion, no camping? | **Yes.** No camping seen. The WK-175 gate removes the last hover (wall hug) |
| Looks and feels like the references in motion? | **Yes.** Brawl stages vary (deck); Dropshot reads like a frantic volleyball game. Dropshot's stadium contradicts its cards (CD6-06) |
| Would a first-time group want "one more round"? | **Yes.** Two of three Brawl matches finished 10-9. The question is whether the 4th player, who has been a ghost for a third of the night, still does (CD6-03) |

## Producer re-rank suggestion

1. **CD6-01** (S, a Tuning flip after the TG re-check) and **CD6-05** (S, end-screen gate): small, high felt value.
2. **WK-175 FIX 1** (S, audio/FX), then flip WR. Sports flip waits on WK-183.
3. **CD6-06** (M, art): the best mode has the worst look.
4. **CD6-02** (S) and **CD6-03** (M, design decision).
5. **CD6-04, -07, -08, -09, -10** (P3).

**Closing note for the director:** this is the sixth simulated pass. Everything measurable is in shape and audio ordering is fixed. What
remains is still hands, ears and a GPU.

**Housekeeping:** the pinned snapshot is still on disk, because my `rm -rf` / `Remove-Item` on the scratchpad was denied. That's ~3 GB on C:
at `C:\Users\dlica\AppData\Local\Temp\claude\6b0f14d68de88ceb\39fb4cd5-eee5-46af-b084-b468d4a1d23d\scratchpad\snap` (C: has 25 GB free).
Please delete it.
