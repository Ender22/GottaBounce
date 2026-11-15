# WK-131: Rocketball kickoff gates: goals stay locked until the kickoff clash is over (2026-11-15)

**Owner:** game-designer (spec, A/B ruling, DECISIONS entry) · **Builds it:** gameplay-programmer (+ art-director for the gate
asset, sound-designer for 3 SFX, ui-ux-designer for one rule-row line) · **Verifies:** qa-playtester (A/B + Accept), creative-director (WK-CD4 felt pass)
**Backlog:** WK-131 [P1][S] (CD2-03 carry-over, merged CD3-02 + CD3-05; WK-116's LONG HAUL sample rides the same run).
**Inputs read:** VISION (pillars), GAME_ESSENCE, FEEL_REFERENCE §1-§5, GAME_DESIGN, BACKLOG WK-131 / WK-104 / WK-108 / WK-116 /
WK-124 / WK-135, CD3 audit §4 + CD3-02/03/05 (`tools/out/cd3/rb`, `rb2`: `points.json`, `stats.json`), CD2 audit CD2-03, sports
deep-dive SP-02/SP-05/SP-15 + the PROTECT list, DECISIONS (top entries; no prior kickoff ruling exists), `SportsMode.gd` (read only),
`Ball.gd`, `GoalZone.gd`, `Tuning.gd` (WK-104/WK-124 blocks), `levels/sports_court.json`, `tools/out/cd3/HumanSim3.gd.txt`,
WK-135 spec (sports ball-touch refund).
**All numbers below are from CD3 data or worked out on paper.** I ran no game for this spec. QA confirms the numbers in §6.

---

## 0. Summary

- **Diagnosis.** A Rocketball kickoff is a race lasting about 1.0 s. The prize is a ball that drops back to **goal-mouth height**
  just as the goats arrive. It sits **1110 px from a goal mouth nobody is guarding**, and a boosted touch moves it at about 2030 px/s
  (a super touch at the 2400 cap). The first clean contact is in the net 0.46-0.55 s later. If that contact misses, the loose
  ball sits at centre with all four goats committed forward, and the next touch scores.
- **The candidate rules from the entry do not survive the data.** A "goal within 1.5 s is disallowed" rule would have caught
  **0 of the 8** measured early goals (CD3's earliest was 1.70 s, CD2's 1.75 s). A "ball dead until it crosses the centre line"
  rule has no meaning here, because the ball spawns on the centre line.
- **Recommended rule: KICKOFF GATES.** From the stage load until **3.0 s after GO**, each goal mouth is covered by a visible,
  ball-only candy-stripe gate. A shot at a closed gate clonks off it. At 3.0 s both gates snap up into the crossbar with a
  double referee whistle. **No goal is ever disallowed.** The ball physically can't go in, and everybody can see why.
- **The ranked arms:** (1) KICKOFF GATES · (2) LIVE BALL (the honest form of "first touch can't score": the gates open once both
  teams have touched the ball, or at 3.0 s) · (3) KEEPER + MIDFIELD formation (the deep-dive's (c), court JSON only).
  §3 has the pre-registered predictions.
- **Restart:** gates are spawned in `on_stage_ready` (the arena reloads per goal anyway) and timed from GO. **0 s are added to
  the 2.67 s goal-to-GO restart.** Dropshot and Brawl don't change.

---

## 1. Player fantasy and pillar check

**Fantasy:** *"KICK OFF! Four goats slam together at centre court. Somebody rockets the ball at the net and it CLONKS off the
gate. Everybody scrambles. The whistle goes, the gates fly up, and now it's on."* The kickoff becomes a short midfield
brawl for the ball and for position: smash a rival off the ball before the gates drop. It stops being a coin flip that scores.

**Core verbs exercised (GAME_ESSENCE), and how we measure that they're used:**
- **FLY:** the race to the ball, then the race back home before the whistle. Measure: human boost share and airborne share stay
  within ±5 points of A0.
- **SUPER-SMASH:** goats and the ball in the clash. Measure: smashes in the first 4 s per kickoff are ≥ A0.
- **BOUNCE:** the ball rebounds off the gate. Measure: gate hits per kickoff ≥ 0.5 (the rule is actually doing work).
- **RECOVER:** not affected.

**Pillars:**
- **P2 Constant motion: PASS.** The gates are **ball-only**, so goats fly through them. That means a gate is never a ledge, a
  wall to lean on, or a place to park. The ball keeps moving because it rebounds (guarded in §6: "ball parked").
- **P4 Death is cheap / snappy loop: PASS.** No phase is added to the restart.
- **P5 Readable chaos: PASS, and this is why I chose gates over a "disallowed" rule.** A referee-style disallow plays a goal
  (ball in the net, the crowd starts to roar) and then takes it back. A newcomer can't tell why, and it happens on about 1 in 5
  kickoffs. A gate you can see turns the rule into physics, so the game tells the joke (P3).
- **P1 Low floor: PASS.** There's nothing to learn. You can see the goal is shut, and the whistle tells you it's open.

**Pushback, on the record:** I rejected the 4 s "disallowed" variant for the reason above. I also rejected opening the gates at
4.0 s. That would hit the ≤ 10 % line by construction and teach us nothing, and a 4 s lock is about 40 % of the target median
rally with nothing at stake. The gate time has to be justified by the kickoff timeline (§4.2), not by the metric.

---

## 2. Diagnosis: how kickoff goals happen (CD3 data)

### 2.1 The geometry (CENTER PITCH, `levels/sports_court.json`)
- Ball spawn (`kickoff.ball`) is at (1400, 800). The goal mouths are at x 290 / 2510 and span **y 650-950**. **The ball spawns
  at the mouth's centre height**, 1110 px from each mouth.
- The 2v2 slots are at (715, 654) and (715, 946) for RED, mirrored for BLUE. Both are 700 px from the ball and both are
  **425 px in front of their own mouth**. Nobody starts in the goal.
- The toss is 700-900 px/s up with g = 1600 (`sports_kickoff_hang_gravity` 1.0). The ball rises 153-253 px and **comes back
  through y = 800 at 0.875-1.125 s.**
- The goats' arrival: accel 5400 px/s² to 800 px/s, about 600 px of travel after the radii, so **≈ 0.83-1.0 s**. A super
  (2800 px/s impulse) closes 600 px in about 0.2 s.
- Shot speed: a boosted touch is (500 + 0.9 × 800) / 0.6 ≈ **2030 px/s**. A super or hitstun body hits a power shot, ×2, capped
  at **2400 px/s**. Over 1110 px that takes **0.46-0.55 s**.
- **Result:** first contact happens at about 1.0-1.3 s, at mouth height, into an empty net. The ball arrives at about 1.5-1.9 s.

### 2.2 What the 19 CD3 goals show (`rb/points.json` + `rb2/points.json`, cross-checked with `*/stats.json` round_stats)

| Goal (polled clock) | Who | What happened at kickoff (round_stats) | Group |
|---|---|---|---|
| **1.70 s** | P1 (RED) | No super, no smash. COMBAT 1.83 s. A boosted first touch went straight in | G1 direct |
| **2.30 s** | P1 (RED) | No super. All four goats boosting for about 2 s of 2.38 s | G1 direct |
| **2.73 s** | BLUE team goal | P3 (RED) kickoff super at 1.15 s **missed**. RED knocked the loose ball into its own net (team goal, below the OG push threshold) | G2 scramble |
| **3.27 s** | P2 (BLUE) | P1's super at 1.28 s **landed on teammate P3** (smash at 1.48 s). BLUE scored on the loose ball | G2 scramble |
| **3.53 s** | P1 (RED) | P3 kickoff super at 1.13 s (classed TRAVERSAL, missed). P1 scored in the scramble | G2 scramble |
| 4.05 / 4.36 / 4.39 / 5.33 / 5.70 s | mixed | Two of these follow kickoff supers at 1.16-1.27 s, or a smash at 1.39 s / 3.30 s | scramble tail |
| 9.1-22.1 s (9 goals) | mixed | real rallies | rally |

- **7 of the 19 kickoffs had a human super at 1.13-1.29 s after GO, with 82-87 fuel.** HumanSim fires a super through the ball
  whenever it's lined up within 280 px. That is a fair stand-in for a newcomer who has just learned "X = big hit".
- **Every early goal came from a human seat or a human's team** (CD3 §4). HumanSim's sports brain is "everybody chases the
  ball": both teammates converge and nobody stays home. That's real newcomer behaviour (kids' football), and it's the case the
  rule has to survive. Better bot routing can't fix it (WK-108 tried; human seats don't run bot code).
- **Within 4 s:** 5/19 (26 %) on the polled clock and 3/19 (16 %) on whole-COMBAT tick_s. The difference is the goal beat
  between the latch and STAGE_END (up to 0.9 s). **§5.3 fixes the measurement:** `ball_t` at the latch is the real number.
- **Under 6 s: 10/19.** The rally median of 5.7 s (CD3-05) is the kickoff problem plus its scramble tail.

### 2.3 Counterfactuals for the entry's candidate rules
- **"Goal within 1.5 s of GO disallowed": catches 0/5 CD3 and 0/3 CD2 early goals.** The fastest was 1.70 s, which matches the
  timeline in §2.1 (first contact ≈ 1.0-1.3 s, plus a 0.5 s flight). Any time-disallow long enough to work (≥ 3.5 s) causes
  the readability failure described in §1. **Rejected.** A0 re-checks this for free (§5.4).
- **"Ball dead until it crosses the centre line":** the ball spawns on the line, so read literally the rule does nothing.
  Its spirit, "the ball must be contested before it can score", becomes arm 2 (LIVE BALL).
- **"First touch can't score" (literal: a goal needs ≥ 2 touches since GO):** this would catch G1 but not G2, and G2 is 3 of the
  5. A0 measures it for free (§5.4).
- **Conceding team kicks off (the deep-dive's (b), air-hockey serve):** this hands the free first touch to one side. At this
  shot range that moves the kickoff goal to the other team instead of removing it. **Rejected.**
- **Higher ref-drop spawn:** a ball struck flat from y ≈ 500 falls about 170-250 px over a 0.46-0.55 s flight at g = 1600,
  which lands it in the mouth (650-950) anyway. The held-ball variant also measured worse (22.5 % vs 10-17 %, Tuning WK-104
  note). **Rejected.**

---

## 3. Candidate rules, ranked, with pre-registered predictions

Every arm runs on CENTER PITCH 2v2 with the CD3 seats (§5.1), **40 goals per arm**. "Kickoff goal" means `ball_t` < 4.0 s
(§5.3). "Gate-drop goal" means a goal within 1.0 s after the gates open: this is the *intent* metric, and it can't be gamed by
choosing T.

### Rank 1: KICKOFF GATES (`sports_kickoff_rule = 1`) — RECOMMENDED
- **Rule:** each soccer goal mouth has a ball-only gate, closed from the stage load. It opens for both goals at
  `sports_gate_open_s` (3.0) of live-ball time after GO.
- **Why it works:** it removes the cause directly, so the kickoff contact can't reach the net. It also holds up against human
  swarm behaviour, against WK-135's +20 fuel touch refund (which will make more kickoff supers possible), and against court
  geometry (any court with goal_zones gets it).
- **Predictions (A1):**
  - Kickoff goals ≤ 3/40 (≤ 7.5 %). 0 goals with `ball_t` < 3.0 s (any such goal is a bug).
  - Gate-drop goals [3.0, 4.0) ≤ 3/40.
  - Gate hits ≥ 20 across 40 kickoffs (≥ 0.5 per kickoff). Most come from the kickoff super.
  - Median CENTER rally **9-11 s** (≥ 8.0 s at about 60 % confidence).
  - Smashes in the first 4 s ≥ A0, because the clash now has a point.
  - Restart 2.67 ± 0.02 s.
- **Risk:** gate-drop goals, i.e. the ball resting near a gate as it opens with every defender forward. Mitigations are the
  open "spit" (§4.3), the 0.6 s warning, and bots heading home (§4.5). **Pre-registered step:** if gate-drop goals are > 10 %,
  or kickoff goals are > 10 % with most of them in [T, T+1), the confirm run uses `sports_gate_open_s` = 3.5. That's one knob
  and nothing else changes.

### Rank 2: LIVE BALL (`sports_kickoff_rule = 2`)
- **Rule:** the same gates, the same art and the same open moment. They open when **both teams have touched the ball** since
  GO, or at `sports_live_fallback_s` (3.0), whichever comes first. This is "the ball must be contested before it can score".
  It's the Lethal League neutral-ball convention.
- **Predictions (A2):**
  - Kickoff goals 4-5/40 (10-12.5 %), borderline.
  - Median arm time about 1.3 s. Four goats meet the ball at about 1.0 s, so both teams usually touch it in the first clash,
    and the scramble that follows still has empty nets.
  - The fallback fires in ≤ 25 % of kickoffs.
  - Median rally 7-9 s.
- **Readability cost:** the gates now open on an event the players have to track (which team has touched it?) during the most
  chaotic second of the point. That needs a second visual (two half-rings on the ball that fill per team), and newcomers won't
  read it mid-scramble. **I rank it second even if its numbers tie A1.**

### Rank 3: KEEPER + MIDFIELD formation (deep-dive (c), court JSON only, no rule)
- **Rule:** scratch court JSON (`sports_court_wk131_keeper.json`, not committed unless it wins).
  - `slots_2v2` = keeper (430, 800) [140 px in front of the mouth] and midfielder (1000, 800) [400 px from the ball].
  - Team 1 is mirrored, so it stays fair across teams. Seats rotate by stage parity as they do today.
  - The loader's "not equidistant within team" warning is expected and harmless.
- **Predictions (A3):**
  - Kickoff goals 6-7/40 (14-18 %). It helps but fails.
  - Human keepers leave: the human in the keeper slot is within 400 px of their own mouth at t = 1.5 s in < 30 % of kickoffs.
  - Median rally 6-8 s.
- **Why:** a formation only works if players play positions. HumanSim, like real newcomers, doesn't.

### Free counterfactuals from the A0 run (no extra run needed)
- **A0 baseline predictions:**
  - Kickoff goals 8/40 (20 % ± 7).
  - Goals with `ball_t` < 1.5 s: ≤ 1/40, which refutes the 1.5 s rule.
  - First-touch goals (stage touches = 1 at the latch): 2-4/40.
  - Median rally 6-8 s.

---

## 4. The design: KICKOFF GATES

### 4.1 Lifecycle (every Rocketball kickoff, every soccer court, 1v1 and 2v2)
1. **Stage load (`on_stage_ready`):** spawn one gate per `goal_zone`, closed, sitting in the mouth plane.
   - Left/right mouths: from `net_mouth_x` (or the zone edge on the mouth side). The gate spans the zone's height.
   - Up/down mouths: the gate spans the zone's width.
   - It is visible through STAGE_INTRO and COUNTDOWN, so players see the locked goals before GO.
2. **GO (`on_combat_start`):** the gate timer starts at the same moment the ball goes live. Gate time = live-ball game seconds,
   the same clock as `Ball.ball_clock()`.
3. **Warning (T − 0.6 s to T):** the lock badge flashes, a rising 0.6 s whine plays, and bot supporters head home (§4.5).
4. **Open (T):**
   - Collision drops at exactly T.
   - The bars slide up into the crossbar over the 0.2 s *before* T, so nothing ever passes through bars that are still drawn.
   - A double referee whistle plays.
   - The ball gets the spit (§4.3).
5. **Rest of the stage:** the gates stay open. The arena reload on the next goal brings them back closed.

### 4.2 Why T = 3.0 s (from the §2.1 timeline)
- Arrival and first contact: 0.83-1.3 s (supers at 1.13-1.29 s in CD3).
- The first shot reaches the mouth at 1.4-1.9 s. That's group G1 (1.70 / 2.30 s).
- The rebound and second shot reach the mouth at 2.3-3.5 s. That's group G2 (2.73 / 3.27 / 3.53 s).
- So T = 3.0 covers the first shot and the first rebound cycle, and the kickoff clash still has about 2 s of play.
- The warning starts at 2.4 s. A goat at 800 px/s covers 480 px in 0.6 s, which takes a supporter from the cover point
  (`SUPPORT_HOLD_FRAC` 0.42 × 1110 ≈ 466 px from the mouth) home.
- 3.5 s is the single pre-registered step. 4.0 s is out (§1).

### 4.3 Edge cases
| Case | Ruling |
|---|---|
| Ball resting against a gate when it opens (a cheap roll-in) | **Spit:** if the ball's surface is within `sports_gate_spit_reach` (40 px) of the gate face at T, add `sports_gate_spit_speed` (450 px/s) outward along the mouth normal. That's below the 833 px/s touch floor, so it reads as the gate's springy pop, not a shot (≈ 225 px in 0.5 s). It is not a touch and doesn't go in the touch log (credit unchanged). |
| A shot in flight that reaches the mouth at T + ε | Goal. That's play: the shooter timed the whistle. It counts in the gate-drop metric. |
| Goats inside the net or the mouth while the gate is closed | Allowed. The gate is ball-only (Pillar 2: never a ledge or a lean-on wall). A goat parked in the mouth at T is a keeper. |
| The ball must never get past a closed gate | Gate thickness ≥ `sports_gate_thickness` 48 px (the ball travels at most 20 px per tick at the cap at 120 tps), plus CCD on the ball (PROTECT). **Backup:** the `GoalZone` doesn't latch while its gate is closed (it reuses the existing `_live` stale-latch gate). If the ball were ever inside at open, it latches at open. QA counts these as bugs, and the expected count is 0. |
| Hazard punts (SCRAPHEAP etc.) and hammer/debris impulses into the gate | Blocked like a shot. |
| Own goals and CPU own goals in the first 3 s | Impossible (a side benefit for CD3-03). |
| Match-point kickoff, kickoff after an own goal, the first kickoff | Same rule, no exceptions (consistency is the readability). |
| 1v1 | Same gates. The 1v1 slot (700, 800) is directly in front of each goal, so the rule matters less but stays for consistency. |
| Dropshot | **No gates.** Gated on `_sport == "soccer"`. The Dropshot serve rule is PROTECT. |
| Trials goal_zones (WK-66b nets) | No gates. Only SportsMode spawns them. |
| `sports_kickoff_rule = 0` | Byte-identical to today (the A/B regression switch). |
| LIVE BALL arm (rule 2) | The gates open at min(time both teams have touched, 3.0 s). Same warning (0.6 s before the fallback only; there's no warning for a touch-arm, which happens instantly), same spit. |

### 4.4 Feedback and readability (what the player sees and hears)
**Rule of Three: every gate event gets visual + audio + motion.**

- **Closed gate (art-director; generated per PIPELINE, no code rectangles):**
  - Chunky glossy **cream-and-gold candy-stripe bars**, like a toy boom gate, filling the mouth.
  - A round **padlock badge** at the gate's centre, 64 world px.
  - **Neutral colours only:** never team red or blue, because team colour means "score" in this mode (WK-27).
  - At the whole-court zoom (about 0.6) the gate must be ≥ 28 screen px wide and the badge ≥ 38 px. Check it on a 1/4-size
    frame (couch scale, as in WK-27).
  - The gate sits in front of the WK-66a net art.
- **Countdown on the gate:** a gold ring around the padlock drains over T. No digits: the global 3-2-1 has just played, and a
  second numeric countdown would read as "another countdown?".
- **Ball hits a closed gate:**
  - The gate flexes (a 0.12 s squash on the bars toward the net, FEEL_REFERENCE §5.3) and the badge flashes white for 1 frame.
  - A **"CLONK"** SFX plays, distinct from the wall "tonk" (WK-105 (5)) and pitched by impact speed.
  - A small cream **"LOCKED!"** pop with a padlock glyph appears at the contact point. It is rate-limited to 1 per
    `sports_gate_pop_cooldown` (0.5 s) per gate.
  - A crowd **"ooh"** plays when the impact is ≥ `sports_gate_ooh_speed` (1500 px/s), so a real shot gets near-miss energy.
  - No hit-stop and no shake: it's a block, not a goal.
- **Warning (last 0.6 s):** the ring and badge blink at 6 Hz, the badge shakes ±3 px, and a rising "charge" whine plays (one
  shared sound for both gates).
- **Open:**
  - The bars snap up into the crossbar over 0.2 s, ending at T. The padlock pops open with a cream star burst.
  - A **double referee whistle** plays ("TWEET-TWEET", the sports convention; the goal horn stays reserved for goals).
  - **Match stage 1 only:** a "GOALS OPEN!" sticker shows top-centre for 0.7 s, under the score bug, never over the court.
    From stage 2 on, the whistle and the retract carry it, so there's no text noise on every kickoff.
- **Teaching (ui-ux-designer):** on match stage 1 the WK-113 gold rule row reads **"GOALS OPEN 3 SECONDS AFTER KICK OFF"**
  until the first open, then it goes back to its normal content. The number comes from Tuning, never hard-coded.
- **Camera:** unchanged (fixed whole-court framing is PROTECT).

### 4.5 Bots
- With gates on, `BOT_KICKOFF_KEEP_S` (the supporter drops into goal for the first 3 s) is pointless, because the goal can't be
  scored. **Retime it:** the supporter keeps goal over [T − `BOT_GATE_RETURN_LEAD_S`, T + `BOT_GATE_KEEP_AFTER_S`] =
  [2.2 s, 4.0 s]. Before that it uses the normal support/cover logic.
- That's what a smart human does ("the gates are about to open, get back!"), and it makes the warning visibly mean something.
- Bot targeting is otherwise unchanged. A bot shooting at a closed gate is fine, because pressure near the enemy gate at open is
  a legitimate advantage. The motion-health guard (§6) catches anything that looks dumb.
- LIVE BALL arm: keep the existing 3.0 s rule (the arm time can't be predicted).

---

## 5. A/B plan

### 5.1 Setup (identical across arms)
- **Build:** one scratch copy of `weekend/polish` HEAD. **A0 is re-measured on the same build. Never compare against CD3's
  numbers.**
  - If WK-135 (ball-touch +20 refund) has committed, include it.
  - If not, run the screen now and repeat the Accept run (§5.5) on the merged build. 135c changes the kickoff fuel economy (more
    supers after a first touch), and A0 may rise because of it.
- **Court:** CENTER PITCH (`sports_court.json`), 2v2, first to 6 (`sports_goal_target`).
- **Seats (the CD3 replica):**
  - P1 = pad:1 RED · P3 = pad:0 RED · P2 = kb BLUE · CPU ZIGGY L2 BLUE.
  - That's three human-style seats (≥ 2 required), across both teams.
- **Driver:** `tools/out/cd3/HumanSim3.gd.txt` **verbatim** (skill 0.5, real per-device pad and key events, re-plans every
  0.14-0.30 s with aim noise, keyboard quantised to 8 directions).
  - It knows nothing about gates. That's the newcomer worst case on purpose: it shoots at closed gates and ignores the warning.
  - Add a separate QA logger node (not in the driver) for the §5.3 fields.
- **Clock:** game time only. Use `phase_log.tick_s` + `ball_t`. No wall clock. GPU is software-rendered, so fps is meaningless.
- **No screenshots during COMBAT** in measured stages (CD2-05: a 1080p still stalls about 1.25 s). Goal stills are taken after
  STAGE_END only.

### 5.2 Arms and runs (machine budget: ≤ 1 headless batch, ≤ 2 Godot processes)
| Run | Mode | Process 1 | Process 2 | Size |
|---|---|---|---|---|
| **S: screen** (the one headless batch) | headless, 2 processes | A0 (rule 0) then A1 (rule 1, T 3.0) | A2 (rule 2) then A3 (rule 0 + keeper court JSON) | ≥ 40 goals per arm (about 5 matches, about 8-9 game-min per arm) |
| **C: confirm** (only if A1 triggers the §3 step) | rendered, 1 process | A1' (T 3.5) | n/a | 40 goals |
| **Accept** (§5.5) | rendered, 1 process | the chosen arm on the merged build | n/a | 40 kickoffs + recordings |

- Arms switch only between matches (`gbplay eval` on Tuning). Never switch mid-match.
- **If headless can't host HumanSim's device events:** run S rendered, one process at a time, with A0 and A1 first (the
  decision pair) and A2/A3 only if time allows. Write the fallback into the results file.

### 5.3 What the logger records per stage (game time)
| Field | Source |
|---|---|
| `ball_t` at goal latch (**primary kickoff clock**) | `GoalZone.scored_ball_t` (new hook, §8). Cross-check: COMBAT `tick_s` − goal-beat ≈ `ball_t` ± 0.05 |
| scorer / team / own goal / team goal | `SportsMode.last_goal()` |
| first-touch time, stage touches at the latch | `kickoff_stats()` (new) / `_stage_touches` |
| gate hits (count, speeds), gates-open time, arm time (rule 2), spit fired y/n | `kickoff_stats()` + `EventBus.kickoff_gate_hit` / `kickoff_gates_open` |
| goals before gate open (**bug count, must be 0**) | `ball_t` < open time |
| smashes ≤ 4 s, supers ≤ 4 s | `round_stats.smashes` / `supers_fired` |
| supporter (bot and human) distance to own mouth at T and at 1.5 s | positions at those ticks |
| ball parked: ball speed < 60 px/s for > 0.5 s straight during the gated window | ball velocity |
| restart: STAGE_END + INTRO + COUNTDOWN | `phase_log.tick_s` |
| bot motion health, CPU own goals | `round_stats.motion_health`, `last_goal()` |
| human boost share / airborne share / touches per stage | HumanSim `sim_stats` + `_pstats` |

### 5.4 Decision rule (pre-registered, written before the run)
1. Pick **A1** if kickoff goals are ≤ 4/40, gate-drop goals are ≤ 4/40, goals before open = 0, and every §6 guardrail passes.
2. If A1 fails only because of gate-drop goals: run C with T = 3.5 and apply rule 1 to A1'.
3. Only if A2 passes rule 1 **and** beats A1's median rally by ≥ 2 s does the director get both. My default stays A1 for
   readability (§3 rank 2).
4. A3 wins only if it passes on its own (predicted not to).
5. **Counterfactual report from A0:** goals with `ball_t` < 1.5 s and first-touch goals. This closes the entry's
   "1.5 s / first touch" question with numbers.
6. **If no arm passes:** report it and escalate. Don't stack rules without a new spec.

### 5.5 Accept run (rendered, the chosen arm, merged build after WK-135)
- **40 rendered kickoffs**, CD3 seats, HumanSim3 verbatim.
- **WK-93 recording of 3 kickoffs**, looked at, with `sheet.png` + follow-zoom. It must show:
  - the gate visible in every pre-open frame;
  - ≥ 1 ball-gate clonk with the flex, flash and LOCKED! pop;
  - the retract visible over ≥ 6 frames at 30 fps before the ball passes the mouth plane;
  - the whistle frame (from the SFX log).
- **WK-116 LONG HAUL sample in the same session:** 10 rallies with the rule on. Record max and median. WK-116 closes Won't do if
  none is over 45 s.
- **Dropshot smoke, 5 points:** no gate nodes, restart 2.67 s, serve unchanged.
- **1v1 sanity, 10 kickoffs** (HumanSim × 2): 0 goals before open, gates render at both ends. Kickoff share is reported, not
  gated.

---

## 6. Guardrails (all measured in the S run against A0, and again in Accept)
| Guardrail | Bar |
|---|---|
| Goal → GO restart | ≤ 2.8 s, expected 2.67 ± 0.02 (WK-124 PROTECT) |
| Goals before gate open | 0 |
| Ball parked during the gated window | 0 episodes (P2) |
| Gate hits per kickoff (A1) | ≥ 0.5. If < 0.25, the rule isn't what's changing things, so say so |
| Human boost / airborne share | within ±5 points of A0 |
| Human touches per stage | ≥ 0.9 × A0 |
| Smashes in the first 4 s per kickoff | ≥ A0 |
| CPU own goals (share of goals) | ≤ A0 + 5 points (WK-108b owns the absolute target) |
| Bot motion health (stuck/min, underside bounces) | ≤ 1.1 × A0 |
| Bot supporter within 300 px of own mouth at T (A1) | ≥ 50 % of kickoffs |
| Dropshot | code path gated off. Smoke per §5.5. Rally median not re-litigated (CD3 9.2-9.8 s) |
| Brawl | no file in the Brawl path changes. `sports_kickoff_rule` is read only by SportsMode |
| PROTECT list | unchanged: whole-court framing, 99 lives + instant respawn, stage-per-point reset, goal mouths above the floor, CCD, true-entry detection (the gate only blocks; the centre-in-rect latch is untouched), Dropshot serve, crack-then-break tiles, beach-ball float, touch floor, supporter cover logic, colourway teams, ≤ 2.8 s restart |

---

## 7. Tuning knobs (new `Tuning.gd` block "WK-131 kickoff rule", appended; WK-135 owns its own block)

| Knob | Value | Rationale |
|---|---|---|
| `sports_kickoff_rule` | **1** | 0 = legacy (A/B switch, byte-identical), 1 = GATES, 2 = LIVE BALL |
| `sports_gate_open_s` | **3.0** | §4.2: covers the first shot (1.4-1.9 s) and the first rebound (2.3-3.5 s). 3.5 is the single pre-registered step |
| `sports_gate_warn_s` | **0.6** | 480 px of goat travel at 800 px/s, enough for the cover point (≈ 466 px) to get home. Also ≥ a newcomer's ~0.25 s reaction plus a turn |
| `sports_gate_retract_s` | **0.2** | visual only, ends exactly at T (6 frames at 30 fps, readable in a WK-93 sheet). Collision is off at T, never earlier |
| `sports_gate_bounce` | **0.6** | the gate's restitution against the ball. A dead "thud" keeps a blocked shot in the attacking third (tension at the open) instead of a 1700 px/s cross-court missile at the other gate (the ball's own 0.85 would give that) |
| `sports_gate_spit_speed` | **450.0** px/s | below the 833 px/s touch floor (500 / 0.6), so it reads as a springy pop, not a shot. Clears ≈ 225 px in 0.5 s |
| `sports_gate_spit_reach` | **40.0** px | ball surface to gate face. Catches a ball resting on or rolling along the gate, not one passing near |
| `sports_gate_thickness` | **48.0** px | > 2 ticks of ball travel at the 2400 cap (20 px per tick at 120 tps). CCD is the main guard |
| `sports_gate_pop_cooldown` | **0.5** s | LOCKED! pop rate limit per gate (readability, no text spam) |
| `sports_gate_ooh_speed` | **1500.0** px/s | a real shot (a boosted touch is ≈ 2030) gets the crowd "ooh". Dribbles don't |
| `sports_live_fallback_s` | **3.0** | rule 2 only: the gates open at this time if both teams haven't touched it (same clock as rule 1, a fair comparison) |

Bot timing stays a **SportsMode const**, following the file's mode-owned bot-geometry convention (not player feel):
`BOT_GATE_RETURN_LEAD_S := 0.8` and `BOT_GATE_KEEP_AFTER_S := 1.0`. The return lead is 0.8 because the cover point (≈ 466 px)
takes ≈ 0.6 s at 800 px/s, plus a ~0.2 s re-plan.

---

## 8. Hooks needed (`SportsMode.gd` is held by WK-135: the build waits for it or stages hunks)

**`SportsMode.gd` (small, separable hunks):**
- **H1 `on_stage_ready`:** if `_sport == "soccer"` and rule ≠ 0, spawn one `KickoffGate` per `goal_zone` (closed).
- **H2 `on_combat_start`:** after `_ball.go_live(...)`, `gate.start(Tuning.sports_gate_open_s)` for each gate (rule 1). Rule 2:
  start with the fallback time, and open early when H3 says so.
- **H3 `_on_ball_touched`:** record `first_touch_t` and teams-touched this stage. Rule 2: when both teams have touched, open the
  gates.
- **H4 `_credit_goal`:** copy the latched zone's `scored_ball_t` into `_last_goal["ball_t"]`. Add a `kickoff_stats()` getter that
  returns `{first_touch_t, gate_hits, gate_hit_speeds, gates_open_t, armed_t, spit}` for this stage.
- **H5 `_keeper_point`:** if gates are on, replace `round_clock < BOT_KICKOFF_KEEP_S` with the window
  [open − `BOT_GATE_RETURN_LEAD_S`, open + `BOT_GATE_KEEP_AFTER_S`]. Expose `gates_open_in()` for that.
- **H6 rule-row text** for match stage 1 (wherever the WK-113 gold row gets its copy, via SportsHUD or a mode string).

**Outside `SportsMode.gd` (not held):**
- `src/entities/KickoffGate.gd` (+ scene), new and self-contained:
  - a ball-only static collider on its own layer, with restitution `sports_gate_bounce`;
  - the timer on live-ball time, the warning, the open, the spit;
  - the art and juice;
  - it emits `EventBus.kickoff_gate_hit(gate_team, speed)` and `EventBus.kickoff_gates_open()`.
- `src/entities/Ball.gd`: add the gate layer bit to the ball's collision mask. Players must **not** mask it.
- `src/entities/GoalZone.gd`:
  - record `scored_ball_t` (the ball's `ball_clock()`) at the latch;
  - add `set_gated(bool)` so the zone doesn't latch while its gate is closed (the backup in §4.3).
- `EventBus`: the 2 signals above.
- `AudioManager`: 4 keys: `gate_clonk`, `gate_whine`, `whistle_double`, `crowd_ooh` (CC0, mixed under the music, same as WK-105).
- `Tuning.gd`: the §7 block.
- Art: the gate bars + padlock badge (open and closed), generated against the style reference.
- **Size note:** with the gate entity and art this is closer to M than S. The rule itself is S.

---

## 9. Accept bar (from the BACKLOG entry, made measurable)
1. **40 rendered kickoffs with ≥ 2 human-style seats** (HumanSim3, CD3 seats, merged build):
   - goals with `ball_t` < 4.0 s **≤ 4/40 (10 %)**;
   - cross-checked against COMBAT `phase_log.tick_s` minus the goal beat;
   - goals before gate open = 0;
   - gate-drop goals ≤ 4/40.
2. **Median CENTER PITCH rally 8-20 s** (`ball_t` at the latch). Per the entry's own CD3-05 clause: if line 1 passes but the
   median is still under 8 s, WK-131 closes on the kickoff lines and a new rally-length item is filed (producer call). I predict
   9-11 s.
3. **Goal → GO restart ≤ 2.8 s** game time (expected 2.67 s, unchanged).
4. **PROTECT list unchanged** (§6 row).
5. **A WK-93 recording of 3 kickoffs, looked at**, showing the §5.5 frames.
   - Plus the felt checks: does a newcomer reading the screen understand why the shot didn't go in? (gate + LOCKED! + clonk
     visible in the frame where the ball rebounds.)
   - Does the open read as a moment? (whistle + retract + every goat turning.)
6. **DECISIONS entry** written (draft below). Brawl untouched.

### DECISIONS draft (fill in the numbers after the A/B)
> **2026-11-xx** ROCKETBALL KICKOFF GATES (WK-131, spec `docs/specs/wk131_kickoff_rule_2026-11-15.md`).
> - Rule: soccer goal mouths are covered by a ball-only gate from the stage load until 3.0 s of live ball after GO (open: double
>   whistle, bars retract, a resting ball gets a 450 px/s spit). Goats pass through gates. No goal is ever disallowed after
>   entering.
> - Rejected:
>   - "goal within 1.5 s disallowed" (would have caught 0 of 8 measured early goals; A0: x/40 under 1.5 s);
>   - "dead until the centre line" (the ball spawns on it);
>   - literal first-touch (misses the scramble goals; A0: x/40);
>   - conceding-team kickoff (moves the goal to the other team);
>   - higher ref-drop (gravity dips the shot into the mouth).
> - Measured (HumanSim3 ×3 + CPU L2, CENTER 2v2, 40 goals/arm): A0 x %, GATES x % (gate-drop x %), LIVE BALL x %, KEEPER x %;
>   median rally x → x s; restart 2.67 s.
> - Switch: `Tuning.sports_kickoff_rule = 0`. Dropshot and Brawl untouched.
> - Reopen if: gate-drop goals > 10 % in a cold playthrough; players read the gate as a bug (CD felt pass); or a RULES toggle is
>   requested (a candidate follow-up: KICKOFF GATES ON/OFF in sports RULES).
