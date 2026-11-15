# WK-CD5: Creative Director cold playthrough #5 (2026-11-16)

**Build:** pinned snapshot of `weekend/polish` @ **0b8ad5f** (`git archive HEAD` into my scratchpad plus a copy of the import
cache; nothing removed). Includes everything listed since CD4: CD4-01 session decks + Islands Void sky drop, WK-154 padlock ring,
WK-155 gate cues, WK-116 pressure nets ON (+75 %), WK-135 p3 ball refuel ON, WK-108b K3/K5, WK-167, WK-31 danger/stocks cards,
WK-79b/c + WK-163/165 audio, WK-166 disconnect fixes, WK-156..159, WK-65b. The snapshot is deleted (junction check clean).

**Rig:**
- Rendered 1920x1080 on port 9129, **software GPU** (still), ~50 fps. Every duration is **game time** (`round_stats.length_s`,
  `phase_log.tick_s`, ball clock). Other agents had 2 Godot processes up meanwhile.
- One WK-93 recording (`CD5_meadow`, bots 2,2,3,3, MEADOW MILE, 30 s) with my game stopped; audio measured with
  `tools/out/wk/WK-79a_scripts/measure_run.py`.
- `settings.cfg` backed up; the diff afterwards was exactly my 2 Brawl + 2 Rocketball matches, so I restored it (md5 matches the
  original).

**Couch group:** Brawl = **pad 1 P1 POGO, pad 0 P2 BUTCH, keyboard P3 ZIGGY + CPU PUFF L2**. Rocketball = **RED: P1 pad 1 POGO +
P3 keyboard BILLY; BLUE: P2 pad 0 BUTCH + ZIGGY CPU L2** (the lobby put the keyboard on RED this time; CD4 had it on BLUE).
Humans driven by **HumanSim5 = CD4's HumanSim4, unchanged** (`tools/out/wk/CD5_data/HumanSim5.gd.txt`), so the numbers compare
with CD3/CD4. Same biases: reckless near edges, 8-direction keyboard, it ignores the padlock ring.

**Route:** Title → mode select (BRAWL default) → lobby (3 devices join + lock, READY TO FIGHT) → arena select → **MEADOW MILE** to 10
→ REMATCH → B, B → mode select → **Rocketball** lobby (RULES panel opened) → CENTER PITCH → REMATCH → 3rd match used only to stage
pressure-net stills (excluded).

**Evidence:** screenshots `tools/out/wk/CD5_01..22*.png` + contact sheets `CD5_sheet_rb1.png`, `CD5_sheet_press.png`,
`CD5_16_rules_strip.png` (all cited ones looked at); data `tools/out/wk/CD5_data/` (m1, m2, rb1, rb2 json + harness);
recording `tools/out/wk/CD5_rec_meadow/` (sheets, data.json, audio.wav; raw frames deleted with the snapshot).

**Not judged:** audio by ear (5th pass in a row); real hands; Trials and Dropshot were not re-played this pass (CD4 shipped Trials;
WK-158/159 are not re-checked here).

---

## Verdict

**Is it a fun, conventional couch party game now? Yes. Would I ship it? Yes: SHIP.** No P0, no P1. This is the first pass where
Brawl is not a FIX.

- **Front end: SHIP.** Title → first bounce in 5 presses. Mixed couch glyphs are everywhere I looked ("A / ENTER", "B / ESC",
  "Y / R", `CD5_04`, `CD5_05`, `CD5_06`); READY TO FIGHT shows both glyphs; end screen B → B lands on mode select.
- **Brawl: SHIP (was FIX).** Both CD4 FIX items are fixed:
  - **Variety.** The session deck put Meadow Carousel at stage 4 and Windmill Meadow at stage 6 of the *first* match. Two matches
    played 20 different arenas in 21 stages. The REMATCH opened on High Pasture, not Grassy Expanse.
  - **Islands Void** now shows hills fading to mist, then clouds, then deep sky under the decks (`CD5_10_m1_p7`). No lawn.
  - The numbers held or improved with the same driver (table below): human self-KO share **16 %** (CD4 23 %), first death
    **4.5 s**, super still the kill on **62 %**.
- **Rocketball: SHIP.** A close 5-6 and a 6-2. Gates, OPEN! pops, own-goal banners and the stats card all read (`CD5_sheet_rb1.png`).
  Own goals fell to **16 %** (CD4 at 3.5 s: 44 %).

**Biggest remaining problem: in Brawl a human spends about a quarter of the fight dead, and the worst seat spends over 40 %.**
- With 1 life per stage, an early death means watching as a ghost. The median human seat was dead **~25 %** of combat time, and the
  worst seat **43 %** (the keyboard P3 in match 2).
- The tail hurts more than the median. In River Split, P3 and the CPU died at 4.3 s and 5.0 s. Then P1 and P2 duelled for
  **37 s** (stage 41.6 s) while two ghosts floated about.
- **Rocketball has no such gap.** Everyone plays every second and the restart is 2.7 s. That fits the studio's own observation
  that sports may be more fun than Brawl (WK-98).
- **This is genre-standard** (Duck Game and TowerFall are 1-life too), so it is a **P2 design call, not a defect**. See CD5-01.

**Structural caveat, unchanged:** five CD passes have used simulated pads on a software GPU, and nobody has heard the game. The
measurable things are in good shape. What is left unverified is exactly what a real couch would notice first: hands, ears and
frame pacing.

---

## Re-judge tables

### MEADOW MILE Brawl (21 stages, 2 matches, 3 HumanSim seats + CPU L2)

| Measure | CD3 | CD4 | **CD5** | Note |
|---|---|---|---|---|
| Median stage length | 8.4 s | 10.1 s | **9.4 s** | Mean 12.5 s, 2 of 21 under 5 s. Per match: m1 8.2 s, m2 12.1 s. Now mixed by deck rather than early-long / late-short |
| Human self-KO share of human deaths | 33-49 % | 23 % (13/57) | **16 % (8/51)** | m1 11 %, m2 21 %. Edges: void 4, top 2, right 2 |
| Opening self-KOs (< 3 s) | many | 0 | **2** | At 2.8 s (Bluff Line) and 2.9 s (Meadow First Hop). Small n |
| First death (median) | 2.8 s | 4.2 s | **4.5 s** | m1 4.0, m2 4.8 |
| Super as the last smash on credited KOs | 70 % | 65 % | **62 % (32/52)** | m1 50 %, m2 75 %. Still the decisive move |
| Stages where somebody died but nobody was credited | n/a | n/a | **0 / 21** | Every stage paid someone |
| Interstitial per stage | 5.0 s | 4.8 s | **4.8 s** | STAGE_END 0.9 + SCOREBOARD 2.0 + INTRO 0.8 + COUNTDOWN 1.06 |
| Dead share of combat per human seat | ~25 % median | 12-34 %, median 19.5 % | **12-43 %, median ~25 %** | CD5-01 |
| Airborne / boosting share, living humans | 100 % / 20-33 % | 100 % / 21-34 % | **100 % / 22-35 %** | Fantasy intact |
| Driver super presses inside the spawn truce | n/a | 55/174 (32 %) | **44/139 (32 %)** | The driver can't read the ring. See readability |
| CPU self-KO share | n/a | n/a | **2/11** | WK-167 era |
| Winners | | CPU 10, P1 10 | **PUFF (CPU) 10-7-6-5; P2 10-6-4-4** | Competitive |

### Rocketball, CENTER PITCH 2v2 (gates 3.5 s, nets ON, ball refuel ON), 19 goals

| Measure | CD3 (no gates) | CD4 @ 3.5 s (18 goals) | **CD5 (19 goals)** | Note |
|---|---|---|---|---|
| Goals within 4 s of GO | 16-26 % | 0 % | **2/19 = 11 %** | 3.72 s and 3.79 s: gate-drop goals 0.2-0.3 s after the open. CD5-03 |
| Goals before the open | n/a | 0 | **0** | |
| Goals within 1 s of the open | n/a | 1 | **4** | 3.72, 3.79, 4.21, 4.45 |
| Median rally (ball clock) | 5.7-7.0 s | 10.2 s | **9.4 s** | rb1 10.4, rb2 7.8. In the 8-20 s band |
| Long rallies (≥ 30 s) | | | **0** (max 25.8 s) | Pressure nets never fired naturally (step -1 on all 19) |
| Own goals | 4/19 | 8/18 | **3/19 = 16 %** (2 by the CPU) | Big improvement (K3 guard + ball refuel) |
| Results | | | **BLUE 6-5; RED 6-2** | |

### Audio (WK-93 `CD5_meadow`, 38.7 s, Brawl; measured, not heard)

| Measure | Value | Read |
|---|---|---|
| Integrated loudness / LRA / true peak | **-16.9 LUFS / 5.8 LU / -1.9 dBTP** | On target (the WK-79 plan was ~-16 to -18). Two ≥ -2 dBFS clusters in combat, no clipping |
| KO (killed) rise over the 2 s bed | **+6.5 LU** (n=3, min +5.3) | Every KO lands audibly. That is the stinger bus working |
| GO rise | **+6.5 LU** (n=2) | Present |
| Countdown rise | **+13.2 LU** (n=2, max +17.3) | **Louder than any KO.** CD5-02 |
| Super fired rise | +3.2 LU median, **min -3.6** | Some supers vanish under the bed. CD5-02 |
| Smash rise | +2.8 LU median, min -3.4 | |
| Combat spectrum | centroid **893 Hz**; 2-5 kHz -13.2 dB, air -25 dB | Dark / dull balance. Worth a listen by anyone with ears |
| Jetpack thrust share in combat / while frozen | -17.9 dB / -22.0 dB | WK-79b fixes hold (no hum dominance, quiet when frozen) |
| Music (gameplay_2) share | -9.2 dB | Bed sits under the SFX |

Event cues exist where expected: countdown, GO, every super, every smash, every KO and the stage end all produce a measurable rise.
The goal stinger was not recorded this pass (Brawl only); WK-163 measured it at +8.7 LU.

---

## Readability for a newcomer

### Spawn padlock + draining ring (WK-154): reads

- At GO each human goat gets a cream disc with a gold padlock and a **gold ring that drains**, beside a ghost-tinted (blinking) goat
  (`CD5_11_m2_go_a`). It is the same language as the goal gate.
- A newcomer now gets "**locked, opens when the ring empties**". CD4's "how long" gap is closed.
- "*What* is locked" still only becomes clear when you press X and get the dry click plus a grey aim. That is acceptable.
- The driver still fires 32 % of its supers into the lock because it doesn't read the ring. A human who has seen the ring once
  probably won't.

### Danger cards (WK-31): read, and they follow Smash convention

- The HUD card escalates: orange border with a **HURT!** sticker, then a jolted red card with a **DANGER!** sticker
  (`CD5_12_m2_p1`, `CD5_10_m1_p11`).
- Corner-HUD damage is exactly Smash's %, so it is conventional. DANGER! in red is the strongest read and is colour-blind safe
  through the words.
- **Nits:**
  - Nothing on the goat itself says "hurt", so you only learn it from the corner.
  - The sticker can sit on top of a goat that flies into a top corner (`CD5_10_m1_p5`: P3 under P2's HURT!; `CD5_12_m2_p1`: P1 beside
    its own sticker).
  - The KO "+1" chip covers a CPU card's name (`CD5_10_m1_p11`: "PU… CP"). See CD5-06.

### Pressure nets (WK-116): read in play, invisible in the menu

- **In play:** the anticipation pulses the trims orange. Step 1 pops **PRESSURE!** and puts outward chevrons on the posts while the
  mouths grow (`CD5_21_press_s1a`). That is self-explanatory: "goals are getting bigger". Step 2 **MAX PRESSURE!** gives
  unmistakably huge nets (`CD5_22_maxp_b`).
- **Stills were staged** by setting the ball clock. In 19 natural rallies the rule never fired (longest 25.8 s), so for most couches
  it is a rarely seen safety valve. That's fine.
- **In the lobby:** the RULES row "PRESSURE NETS: ON" has no explanation (`CD5_16_rules_strip.png`). A newcomer can't tell what
  they would be switching off. See CD5-04.

---

## Findings

### CD5-01 [P2][M] Brawl spectator time: about 25 % of combat dead per human seat, with 30-40 s 1v1 tails

- **Evidence:**
  - Dead share of combat per human seat: m1 40 / 26 / 23 %, m2 23 / 12 / 43 % (`CD5_data/m1.json`, `m2.json`, `sim_stats.dead_f`).
  - River Split (m2): two deaths by 5.0 s, then a 37 s P1-vs-P2 duel; stage length 41.6 s. Other tails: Windmill Meadow 23.2 s
    (16 s with two ghosts), Hill and Dale 20.9 s.
  - Rocketball keeps all four seats live 100 % of the time.
- **Why it matters:**
  - Ghosts (puff, float, baa) soften this, which is why it is P2.
  - Still, the player who dies first in a long stage is the one most likely to put the controller down.
  - WK-20d already logged a 70.8 s grounded duel as a watch item. This is the same tail from the spectator's side.
- **Direction (game-designer):**
  - Treat "spectator seconds per human per match" as a measured gate next to stage length.
  - Candidate levers, all A/B'd with HumanSim seats:
    - a tail clock once 2 fighters remain and at least 2 are ghosts: hush/sudden-death pressure after N s, the Brawl twin of
      pressure nets;
    - give ghosts a stronger (still uncredited) influence on 1v1 tails;
    - a LIVES 2 default when 3+ humans are seated.
  - Owner rulings (kill target, knockback, camera) are untouched by every one of these.

### CD5-02 [P2][S] Audio priority: the countdown is louder than a KO, and some supers sink under the bed

- **Evidence:** `CD5_rec_meadow` / measure_run:
  - countdown rise **+13.2 LU** (max +17.3) against KO **+6.5 LU** and GO +6.5;
  - super rise median +3.2 LU, **min -3.6**; smash min -3.4;
  - combat centroid 893 Hz, with 2-5 kHz 13 dB under the mid band.
- **Why it matters:**
  - The loudest moment of a stage is a pre-fight beep, not the payoff.
  - WK-79a already flagged "countdown loudest"; the KO fix (stinger bus) landed, but the countdown was never brought under it.
  - Supers are the core verb. A super you can't hear over three jetpacks reads as a dud.
- **Direction (sound-designer):**
  - Trim the countdown beeps about 5-7 dB so the KO sting is the loudest event.
  - Give the super launch a 2-5 kHz transient so it cuts through the bed.
  - Re-run measure_run on a 4-bot Brawl and a Rocketball capture.

### CD5-03 [P3][S] Gate-drop goals are back in a small sample (2/19 within 4 s of GO)

- **Evidence:** rb1 goals at 3.72 s and 3.79 s ball time, 0.2-0.3 s after the 3.5 s open. 4/19 came within 1 s of the open.
  CD4 at 3.5 s had 0/18, and the WK-131 A/B had 2.8 %.
- **Read:** probably noise (n=19, two goals in one match by the attacking pad seats). A ball parked against the locked boom when it
  lifts still scores instantly.
- **Direction:** watch item for the next sports A/B. If it holds above 10 %, lower the ball's speed while it sits pinned on the
  closed gate, or extend the boom-lift animation.

### CD5-04 [P3][S] The RULES row "PRESSURE NETS" has no explanation

- **Evidence:** `CD5_16_sports_rules`, `CD5_16_rules_strip.png`. The row shows ON/OFF only, and no rule line or legend mentions it.
- **Direction (ui-ux-designer):** a one-line helper under the focused rules row, for example "Long rallies make the goals bigger".
  The other rows would benefit from the same.

### CD5-05 [P3][S] The deck reshuffle can repeat an arena within one match

- **Evidence:** m2 played Sunny Shoulders at stage 2 and again at stage 10, after the 20-arena session deck ran out
  (`CD5_data/m2.json`).
- **Direction (gameplay-programmer):** when the deck reshuffles mid-match, push arenas already played in the current match to the
  back of the new deck.

### CD5-06 [P3][S] Corner-card stickers and chips overlap the world and the card name

- **Evidence:**
  - `CD5_10_m1_p11`: the "+1" chip covers PUFF's name ("PU… CP").
  - `CD5_10_m1_p5`: the HURT! sticker hangs below the P2 card onto the P3 goat.
  - `CD5_12_m2_p1`: P1's goat sits next to its own HURT! sticker.
- **Direction:** dim the card stickers where a goat is under them, as WK-156 does for the legend chips. Offset the +1 chip clear of
  the name.

### CD5-07 [P3][unconfirmed] RULES panel D-pad focus once failed to leave FORMAT

- **Evidence:** in one sequence (open RULES → D-pad left ×3 on the locked FORMAT row → D-pad down ×2 → stick down ×2), the focus stayed
  on FORMAT (`CD5_16e`, `16f`, `16g`). After A (done) and re-open, D-pad down moved normally (`CD5_16_rules_strip.png`).
- **Read:** it could be simulated-input timing or a stale screenshot frame. I could not reproduce it, so this is a note for QA: try
  "left on a locked row, then down".

### Watch items

- **Opening self-KOs 2 in 21 stages** (CD4 0). Small n; both at 2.8-2.9 s, just after the 1.3 s truce.
- **A CPU L2 won match 1 10-7.** That is fine against newcomer drivers.

### Re-confirmed closed since CD4

| CD4 item | Status | Evidence |
|---|---|---|
| CD4-01 fixed MEADOW MILE order | **Closed.** Wild arenas appear in match 1; 20 unique arenas in 21 stages; REMATCH continues the deck | `CD5_data/m1.json`, `m2.json` |
| CD4-02 Islands Void mint lawn | **Closed.** Sky drop with mist and clouds | `CD5_10_m1_p7` |
| CD4-03 back-half 5-6 s stages | **Closed by WK-20d ruling + deck.** Short stages are now scattered, not a block | table |
| CD4-04 padlock with no "how long" | **Closed.** Draining ring | `CD5_11_m2_go_a` |
| CD4-05 gate cues faded or covered | **Closed.** Full-alpha OPEN! per gate, red/white barrier stripes, badge low in the mouth | `CD5_sheet_rb1.png` p2, `CD5_18_rb_countdown` |
| CD4-06 legend hiding goats at kickoff | **Closed.** Chips fade where goats pass | `CD5_18_rb_go1` |
| CD4-07a lobby footer pad-only on a mixed couch | **Closed** | `CD5_04`, `CD5_05`, `CD5_15` |
| CD4-09 own-goal share | **Improved** 44 % → 16 % | table |

---

## Fantasy-fit check

| Check | Answer |
|---|---|
| Airborne and using the jetpack? | **Yes.** Living humans 100 % airborne, boosting 22-35 %. Sports is all flight |
| Do distances require boost or super? | **Yes.** Meadow decks are split by voids; the wild arenas (carousel, windmill, pillars) now actually appear |
| Is the super the decisive kill? | **Yes.** 62 % of credited KOs; the recording shows 11 supers → 9 smashes → 3 KOs in 30 s |
| Constant motion, no camping? | **Yes,** apart from the dead seats (CD5-01) |
| Looks and feels like the references in motion? | **Yes.** Brawl now has Duck Game's "next arena is a surprise" quality; Rocketball reads like a tiny Rocket League |
| Would a first-time group want "one more round"? | **Yes for both.** REMATCH now brings new arenas, which was CD4's third-match question |

## Producer re-rank suggestion

1. **CD5-02** (S): the countdown under the KO and a super transient. Cheap, and audio is the one channel nobody can check by hand.
2. **CD5-01** (M): a design pass on Brawl spectator time with a measured gate.
3. **CD5-04 + CD5-06** (S, one UI slice).
4. **CD5-05** (S).
5. **CD5-03 / CD5-07:** watch and QA repro.

**Closing note for the director:** the build passes everything a simulated couch can measure. The highest-value next validation is
not another CD pass. It is any real session with real controllers, a real GPU and speakers. If that is impossible this weekend, at
least restore the GPU (owner action) so frame pacing can be judged before "ship".
