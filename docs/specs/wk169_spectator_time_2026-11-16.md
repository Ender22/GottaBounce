# WK-169a: Brawl spectator time. SHOWDOWN: pressure on long 1v1 tails, no stage ender (2026-11-16)

**Owner:** game-designer (this spec, the 169b ruling input) · **Prototype for the A/B:** gameplay-programmer (169b-prep, switches OFF) ·
**A/B:** qa-playtester (169b, one headless batch, at most 2 processes) · **Build of the ruled arm:** gameplay-programmer + sound-designer +
art-director (169c) · **Felt check:** creative-director (WK-CD6).
**Inputs read:** BACKLOG WK-169 (incl. the producer's mis-scope notes), WK-56, WK-168 · `docs/audit/2026-11-16_cd5_playthrough.md` (CD5-01) ·
`docs/audit/2026-11-16_wk20d_phaseA.md` · `docs/specs/wk37a_ghost_goats_2026-11-14.md` · DECISIONS (2026-07-03 owner lives/SD directive, 2026-07-10
camera rules, 2026-07-19 knockback, 2026-11-14 weekend autonomy (c), WK-95 "super = attack", ghost goats, CD4-01 decks, WK-20d) ·
`docs/feedback/owner_2026-07-03_lives_damage_killrace.md`, `owner_2026-07-10_camera_rules.md` · GAME_ESSENCE · VISION · GAME_DESIGN §5/§7/§16 ·
FEEL_REFERENCE §3-§7 · raw data `tools/out/wk/CD5_data/m1.json`, `m2.json` (round_stats kills, smashes, ghosts) · harness
`tools/out/wk/wk20dA_batch/` (boot, recorder, HumanSim4 copy, run script) · `HumanSim5.gd.txt` · `PowerupSpawnDirector.gd`, `PowerupSystem.gd`,
`PartyMatch.gd` (TWO LEFT, SD revive), `Tuning.gd` (ghost, powerup, super, damage blocks).

---

## 0. TL;DR

- **The spectator problem is a tail problem.** In CD5, **82 % of all dead-seat seconds happened while exactly two fighters were left.**
  Six of 21 stages (2-alive tails of 5 s or more) carried 63 % of them, and River Split alone carried 28 %.
- **The long tails are contact droughts, not failed kills.** River Split's 36.6 s duel had 3 smashes, with an 18.3 s gap and none in it.
  Windmill Meadow's 16 s duel had 1 smash, 0.8 s before the KO. In the six long tails, 6 of 11 smashes became the stage-ending KO.
  **Tails end about 1 s after the next solid contact, so the lever is contact rate.**
- **The median share is mostly structural** (LIVES 1, 3 of 4 seats die each stage). Even capping every CD5 tail at 6 s leaves the median human
  share at ~25 %, but it halves the worst seat (65.9 → 32.6 s) and cuts median spectator seconds by 13 %. So the gate measures **seconds and long
  waits** first, and reports the share.
- **Proposal: a SHOWDOWN state.** It starts once two fighters have been alone for 6 s with at least one ghost watching. It escalates in steps
  and **never ends anything**. Three candidate levers ride on it, ranked:
  1. **L1 GOLDEN DROP:** a golden tank (auto-activated Unlimited Boost, 6 s) appears at the *fair point* between the two fighters every 8 s.
     It forces the encounter. This is WK-56's golden bubble, made spatial.
  2. **L2 RESTLESS GHOSTS:** in the showdown, ghost puffs come twice as fast and the per-stage cap rises. Puffs stay the same strength. This
     gives the bored seats a verb exactly when they are most bored.
  3. **L3 ROWDY ARENA:** bounce launches grow ×1.07 per step. It's a pure-physics contact booster that also tests the diagnosis.
- **A/B (169b):** one batch, 2 lanes, about 22 min wall, about 390 stages.
  - Lane T forces a two-human 1v1 tail with two ghosts at 3.0 s, every stage. That powers the tail metric.
  - Lane N plays real first-to-10 matches. That gives the spectator gate and the guardrails.
  - A0-repeat control is included. HumanSim5 gets one pre-registered "shiny" layer that does nothing unless a golden tank exists.
- **The 70.8 s grounded duel from WK-20d Phase A** is the same tail seen from the spectator side. I confirm QA's reading: it's a watch note for
  WK-169, not a WK-20d blocker.

---

## 1. The problem in numbers (diagnosis)

### 1.1 Method
All durations are **game time from `round_stats`**:
- A seat's spectator time in a stage = `length_s − t_death`.
- It excludes the 0.9 s STAGE_END freeze. HumanSim's `dead_f` counter includes that freeze, which is why its shares run about 0.5 pp
  different from the ones below. **169b uses the round_stats method.**

Seats 0-2 are the HumanSim humans; seat 3 is the CPU.

### 1.2 CD5 baseline (21 stages, 2 matches, MEADOW MILE)

| Seat-match | Spectator s | Fighting s | Share |
|---|---|---|---|
| m1 P1 (pad 1) | 45.2 | 110.7 | 40.8 % |
| m1 P2 (pad 0) | 29.4 | 110.7 | 26.6 % |
| m1 P3 (kb) | 25.4 | 110.7 | 22.9 % |
| m2 P1 | 33.4 | 151.5 | 22.1 % |
| m2 P2 | 17.1 | 151.5 | 11.3 % |
| m2 P3 | 65.9 | 151.5 | **43.5 %** |
| **Median / worst** | **31.4 s / 65.9 s** | | **24.8 % / 43.5 %** |

**Human waits** (one per human death that didn't end the stage, n = 34):
- median **4.4 s**, p90 **14.7 s**;
- waits over 10 s: **6 of 34 (18 %)**, and **51 %** of all human spectator seconds;
- waits over 15 s: **4 of 34 (12 %)**: 36.6, 17.5, 16.4 and 15.0 s (rounded).

### 1.3 Where the dead time sits

**2-alive tail** `T2` = the time from the second elimination to the stage end, for stages that started with 3 or more fighters. Across the 21 CD5 stages:
- median **2.3 s**, p75 **5.4 s**, mean **5.1 s**, max **36.6 s**.

| Phase | Share of all dead-seat seconds (all 4 seats) |
|---|---|
| 3 alive (1 dead) | 18 % |
| **2 alive (2 dead)** | **82 %** |

- **The 5 stages with T2 > 6 s** (24 % of stages) carry **59 %** of dead-seat seconds.
- **The 2 stages with T2 > 10 s** (Windmill Meadow 16.0 s, River Split 36.6 s) carry **40 %**.
- **The worst seat is one stage:** River Split's 36.6 s is 56 % of m2 P3's whole-match spectator time.

### 1.4 Why the tails are long: contact droughts

Smashes inside the CD5 tails of 5 s or more:

| Stage | Tail T2 | Smashes in tail | Longest smash-free gap | KO came ... after the last smash |
|---|---|---|---|---|
| River Split (m2 s9) | 36.6 s | 3 | **18.3 s** | 1.5 s |
| Windmill Meadow (m1 s6) | 16.0 s | 1 | **15.3 s** | 0.8 s |
| m1 s9 | 9.0 s | 1 | ~4.9 s | 4.1 s (ring-out) |
| m2 s7 | 8.1 s | 3 | ~4.2 s | 0.9 s |
| m2 s6 | 6.8 s | 1 | ~3.4 s | 3.4 s |
| m1 s10 | 5.4 s | 2 | ~3.9 s | 0.5 s |

- **6 of 11 tail smashes ended the stage, a 55 % conversion.** Hits already kill; nobody connects.
- That matches the driver: HumanSim always chases the nearest rival, 140 px above them. It supers only with a clear line under 560 px, then
  re-plans. On split or wide arenas two such fighters orbit each other.
- Real newcomers do the same. Two cautious, missing beginners are exactly the CD's "two ghosts floating while P1 and P2 duel".

**Consequence for lever choice:**
- **Raise the contact rate in long tails.** Conversion is fine.
- **Do not touch kill power.** The knockback array is owner-ruled, and the damage heal is in the owner directive. See owner question OQ-3.

### 1.5 WK-20d Phase A (419 stages, same driver family) is the same shape
- Grassy Expanse, 70.8 s: P3 self-KO'd at 2.7 s and the CPU was KO'd at 17.9 s. Then came a 52 s human 1v1 (no pin, no SD) that ended in a
  self-KO.
- The R2 batch's 66 s High Pasture duel has the same shape.
- The natural T2 distribution over Phase A's raw logs (`tools/out/wk/wk20dA_batch/raw_b1ca88b/`) has not been computed. **169b computes it
  first, outside the Godot cap, as the large-n A0 reference** (§10.6).

### 1.6 The structural floor: what a tail fix can and cannot do

Counterfactuals on CD5 (stage lengths shrink with the tails):

| Scenario | Median share | Worst share | Median spectator s / match | Worst s |
|---|---|---|---|---|
| Today | 24.8 % | 43.5 % | 31.4 | 65.9 |
| Every tail's excess beyond 6 s cut 40 % | 24.1 % | 38.0 % | 29.2 (−7 %) | 52.5 (−20 %) |
| Every tail capped at 6 s (ideal) | 25.2 % | 32.9 % | 27.3 (−13 %) | 32.6 (−51 %) |

- **The median share barely moves.** Its denominator, fighting time, shrinks with the tail.
- The remainder is the 1-life structure. At today's death timing (first death 4.5 s, median stage 9.4 s), a seat's expected share is
  **~20-21 %** even with instant tails.
- **Only LIVES moves the median share materially.** That is an owner question (OQ-1), never an arm.
- **What a showdown can fix** is the felt pain: **the long wait, the worst seat, and seconds per match.** The gate is built around those (§2).

---

## 2. The metric: "spectator time" and its targets

| ID | Metric | Definition | CD5 baseline | Target for the ruled arm (vs same-batch A0) |
|---|---|---|---|---|
| **S1** | **Spectator seconds per human per match** | Σ over the seat's stages of (`length_s − t_death`), COMBAT + SUDDEN_DEATH, game time. Median and worst (and p90) over human seat-matches | median **31.4 s**, worst **65.9 s** | median **≥ 8 % lower**; seat-match p90 **≥ 20 % lower** |
| **S1s** | Spectator seconds per human seat per stage played (pooled) | Same numerator per stage, averaged over human seats × stages. The powered version of S1 | **3.4 s** (216.4 s / 63 seat-stages) | **≥ 8 % lower**, 90 % CI upper bound < 0 |
| **S2** | **Spectator share per human seat-match** | S1 ÷ the match's combat seconds. Median and worst | median **24.8 %**, worst **43.5 %** | median **≥ 0.5 pp lower** (structural floor, §1.6); worst / p90 **≥ 5 pp lower** |
| **S3** | **Long waits** | Share of human deaths with wait > 15 s; p90 wait | **12 %** (4/34); p90 **14.7 s** | > 15 s share **≥ 40 % lower**; p90 ≤ 12 s |
| **S4** | **2-alive tail** (lane T, the powered test) | `T2` per stage; **excess tail** `E` = mean of min(max(0, T2 − 6), 60) | natural median 2.3 s, mean 5.1 s | `E` **≤ 0.70 × A0** (90 % CI of the ratio < 1.0) |
| **S5** | **Ghost dry share** (felt idleness) | Ghost seconds with no puff available (arming, cooldown, cap reached, hushed) ÷ ghost seconds, inside the showdown | new telemetry (est. 75-90 % in tails > 20 s) | L2 only: **≤ 0.75 × A0** |

**Reporting rule:**
- S1, S2 and S3 come from lane N (real matches). S4 and S5 come from lane T (forced tails).
- S1 and S2 are always shown beside the stage-length median, as BACKLOG asks.
- The WK-169 BACKLOG accept names "median share" and "worst seat". Under the §1.6 floor, the honest pre-registered margins are 0.5 pp and 5 pp.
  **Director question DQ-1:** let S1s and S3 carry the ruling, with S2 reported.

---

## 3. Player fantasy

> *"Two of us left. I'm a ghost, P2's a ghost. For six seconds it's a straight duel. Then the meadow goes quiet: the music drops to a
> drumbeat, the sky dims, both fighters get a gold rim, and **a golden jetpack tank shimmers into the gap right between them.** Both
> dive for it. Pogo grabs it, and now she's firing supers like a machine gun while Butch flies for his life. Me and the other ghost are
> bleating and dropping clouds twice as fast. Eight seconds later it's over, and I'm back in."*

- **The showdown is a prize, not a punishment.** Nothing closes in, nothing burns, nothing counts down. The arena **throws something worth
  fighting over into the middle**, and the ghosts become the crowd.
- **Core verbs (GAME_ESSENCE obligation):**
  - **FLY:** the drop sits at the fair point. On void arenas that's usually a boost across a gap; on wide grounded arenas it's a race.
  - **SUPER-SMASH:** the golden tank is pure super, with fuel pinned and a refire every 1.0 s. The decisive move gets more frequent.
  - **RECOVER:** the holder recovers for free for 6 s. The non-holder's recovery gamble is untouched.
  - **BOUNCE:** L3 makes every bounce bigger.
  - **Measured:** boost share, supers and smashes per showdown-minute (§9, §11).

---

## 4. The fence: owner rulings and what this spec will not do

| Rule (source) | How this spec complies |
|---|---|
| **No timer may END a stage. A stage ends by elimination** (owner 2026-07-03 §1) | The showdown is time-*triggered* but ends nothing. The stage still ends only when ≤ 1 fighter is left. Test T2 (§12) runs a 120 s showdown and asserts the state is still COMBAT. |
| **Sudden death is ONLY the double-KO case; the 20 s laser wall is removed** | No moving boundary, no kill-zone change, no damage over time, no forced death. The showdown clears on SUDDEN_DEATH entry, so SD stays exactly as ruled. |
| **LIVES default 1** | Untouched. LIVES 2 for 3+ humans is OQ-1, never an arm. |
| **Camera rules** (owner 2026-07-10) | No zoom, punch, pan or focus point. Showdown visuals are screen-space dims and rim lights. Test T5 checks camera invariance. |
| **Knockback array, kill target** (DECISIONS (c)) | Untouched. No lever changes launch multipliers, the heal timer, hitstun, sting or the super impulse. |
| **Super = attack, flight = traversal** (WK-95) | L1's tank makes the *attack* more available. Nothing turns the super into traversal. |
| **Ghost fences K-1 to K-7** (WK-37) | Unchanged. L2 changes only cooldown and cap inside the showdown. The match-point hush (K-5) and SD hush (K-6) override it. |
| **Faster stage turnover after the 2nd KO must not end a stage early** (WK-169 note) | No arm shortens round-end freeze, score hold or intro. A stage is shorter only because a fighter died sooner. |

### Suggestions considered and rejected (pushback)
- **Showdown camera zoom-in.** It breaks owner rule 6 (zoom-in cap: most of the level stays visible) and rule 3 (targeting = clamped extremes).
  The "pull-in" becomes a *visual hush* instead (§7): the backdrop dims and the fighters get a rim light. The camera doesn't move. A cinematic
  exception is the owner's call (OQ-2).
- **Shrinking safe zone, shrinking kill bounds, closing vignette lines.** That's the laser wall under a new name. Rejected, including any
  vignette that *moves inward*. The showdown dim is static per step and has no edge line.
- **"Faster super recharge for the last two."** The super has no recharge. It is fuel-gated (min 10), and one bounce pays 20, so in practice
  it's always ready. CD5 tail droughts are approach failures, not empty tanks.
  - A generic fuel surge would mostly buy *recoveries*, and I predict it lengthens tails.
  - The fuel idea survives only as the **earned** golden tank (L1).
- **"Ghost puffs nudge harder."** A harder bonk raises haunted and cloud-decided deaths, which runs into the ghost-decided guardrail. L2 makes
  puffs *more frequent at the same strength*. The cloud stays an ambivalent toy (it rescues as often as it bonks).
- **A forced pull toward the centre (a gravity hand).** It takes the stick away, reads as a magnet or wall, and over a void it creates deaths
  nobody chose. Rejected.
- **Heal pause or pre-damage in the showdown.** It would raise conversion without touching the array, but conversion isn't the problem (55 %)
  and it bends the owner's damage directive. OQ-3, and only if L1 fails.
- **Bumper or hazard intensification.** Bumper restitution stays < 1 (FEEL §2.4: no speed pumping). Moving hazards exist on only 4 of 20
  MEADOW MILE arenas, so that belongs to a level-designer pass. The universal version is L3 (bounce surfaces only).

---

## 5. The SHOWDOWN frame (shared by every arm)

### 5.1 Entry
SHOWDOWN begins when **all** of these hold:
1. BRAWL, state COMBAT (never SUDDEN_DEATH);
2. exactly 2 not-eliminated fighters (the existing `ne == 2`);
3. the stage started with 3 or more (`_stage_start_alive >= 3`, the same condition as TWO LEFT!). So **there is at least one spectator**;
4. the 2-alive phase has lasted **`showdown_delay` = 6.0 s** (game time, pause-aware).

**Why 6.0 s:**
- CD5 tails have a median of 2.3 s and p75 of 5.4 s. A 6 s delay fires on about **24 %** of stages, and those carry **59 %** of dead-seat seconds.
- A decisive 1v1 keeps its TWO LEFT! moment and six clean seconds.
- 6 s is about two full exchanges (super, recover, re-approach ≈ 2.5-3 s in the tail data). That's long enough to be sure it's a drought, not a
  fight.

### 5.2 Steps
- **Steps** come at showdown entry (step 1), then every **`showdown_step_s` = 8.0 s**, up to **`showdown_max_steps` = 3** (tail time 6, 14 and
  22 s). After step 3 the state **holds**: no further escalation, no end.
- L2 and L3 scale with the step. L1's drops repeat every `showdown_drop_interval` for as long as the tail lasts (§6.1).

### 5.3 Exit
- **Exit:** the stage ends (elimination), or SUDDEN_DEATH starts (a double-KO of the last two). On SD entry the showdown clears instantly:
  golden bubbles pop (`on_sudden_death` already pops bubbles), music returns to the bed, and the dim lifts. **The SD is decided by the revived
  pair alone, unchanged.**
- **Multi-life matches (LIVES > 1):** "not-eliminated" includes a fighter in its 1.0 s respawn. The clock runs, but a drop waits until both are
  live (§6.1).
- **Match point:** the showdown and L1 run (fighter-side, fair). L2 is overridden by the K-5 hush (ghosts are silenced).
- **Pause / disconnect overlay:** every showdown clock freezes.

### 5.4 Presentation (built once in 169c for whichever arm ships; §7)
SHOWDOWN! banner, a music hush to a drum layer, a static backdrop dim and fighter rim lights. **No clock UI of any kind.** A countdown would read as
"something ends at zero", and nothing does.

---

## 6. The levers

### 6.1 L1 GOLDEN DROP (rank 1): force the encounter

**Mechanic**
- **When:** at showdown entry, then every **`showdown_drop_interval` = 8.0 s**. Two rules can delay a drop:
  - **tank lock:** no drop while either fighter holds an active golden tank, nor for 1.0 s after it ends;
  - **both live:** with LIVES > 1, wait until neither fighter is respawning (at most 1.5 s, then drop anyway).
- **Where: the fair point.** From the level's authored `powerup_spawner` points (every Brawl arena has 2-3; all authored as reachable), pick the
  one that **minimises max(d_A, d_B)**. d is the straight-line distance from each fighter's position at telegraph start. Only points inside the
  current viewport (inset 120 screen px) qualify. If none is in view, use all points. Ties go to the point nearest the camera centre.
  - **Why minimax:** it is the nearest point that neither fighter is gifted. It's equidistant when they're apart, and close to both when they're
    together.
- **Telegraph:** `showdown_drop_telegraph` = 1.0 s (= `pu_spawn_telegraph`), gold converging sparkles at 1.3× the normal radius, plus a bell
  (§7). It's non-solid. The scramble starts with the telegraph, as with normal powerups.
- **The bubble:**
  - 1.2× normal bubble size, gold, with a jetpack-tank icon;
  - live for **`showdown_drop_life` = 7.0 s**, then it pops with a sad "fft" if nobody took it, so the next drop re-picks a fresh fair point;
  - the normal `pu_max_on_field` cap doesn't count it; the regular spawner keeps its own cadence;
  - **one golden bubble at a time.**
- **Contents: GOLDEN TANK. Auto-activates on touch** (no held slot, no button: the low floor). The toucher gets **Unlimited Boost for
  `showdown_drop_dur` = 6.0 s** (`fuel_locked`, refire lockout `pu_unlimited_super_lockout` 1.0 s). Grabbing it again while active refreshes
  the duration.
  - **Why Unlimited Boost:** it multiplies the core verb directly (up to 6 supers in 6 s) and doesn't depend on the victim fleeing correctly
    (Star does).
  - **Why 6 s, not the powerup's 8 s:** shorter dominance, more drops.
- **Who can collect:** living fighters on touch, the standard pickup rule. Ghosts, clouds, balls and bombs can't (K-rule 4).
  - If both fighters touch in the same physics frame, the closer centre wins. An exact tie is a seeded coin.
- **Bots:** a CPU fighter treats a live or telegraphing golden bubble as a target under the HumanSim5g rule (§10.3). It goes for it when
  `d_me ≤ 1.25 × d_rival` with p 0.5 per decision, at every difficulty.
  - Without this, a human-vs-CPU tail is a free race for the human.
  - **This edits `InputBot.gd` (lane B), after WK-161b commits.**

**Edge cases:**
- A fighter is already inside the point when it goes live: it collects at once (it was there first).
- The fair point is beyond a void the fighter can't cross on its tank: it's still a spawner, which is authored reachable. If the CD calls a
  specific arena unfair, the level-designer moves that spawner. No code rule is needed.
- A golden tank holder dies: the tank ends. If the stage continues, it's a 1-alive stage, which means the stage is over.
- The holder self-KOs by over-committing a super: that's legitimate comedy, and it's guarded by G3.
- A golden bubble is live when the stage ends: it's swept with the field (`round_sweep`).

**Lanes:**
- **lane D:** showdown state + drop director (`PartyMatch.gd`, `PowerupSpawnDirector.gd`, `PowerupSystem.gd` / `PowerupBubble.gd` auto-activate path);
- **lane B:** bot seek (`InputBot.gd`, after WK-161b);
- **lane H:** HUD card gold frame;
- **lane A:** sting, bell and music layer (after WK-170);
- **art:** golden tank bubble + icon (art-director brief, keyout per pipeline).

### 6.2 L2 RESTLESS GHOSTS (rank 2): give the bored seats a verb when it matters

**Mechanic.** These apply only inside the showdown. Outside it, every WK-37 value is unchanged.
- **Puff cooldown** × **`showdown_ghost_cd_mult` = 0.5** (7.0 → 3.5 s; bot ghosts' effective 14 → 7 s). A charge already cooling down gets its
  remaining time halved at entry.
- **Per-stage cap** rises by **`showdown_ghost_cap_per_step` = 3** at each step (3 → 6 → 9 → 12).
- **Unchanged on purpose:**
  - cloud size, tier (marshmallow), life, sink, telegraph and refuel;
  - one live cloud per ghost;
  - every K-rule: no credit, haunted deaths cost nothing, stunned and supering bodies pass through;
  - **the K-5 match-point hush and K-6 SD hush override L2.**
- **Why frequency, not strength:**
  - In River Split, P3's ghost hit the 3-puff cap about 15 s into a 37 s wait, then had ~20 s of nothing. That's the idle problem.
  - A stronger bonk would make ghosts decide KOs. A more frequent ambivalent cloud makes them *matter* without deciding.
  - With two ghosts at 3.5 s, about 1.6 clouds are airborne at once (2.75 s life each). That's busy, but far from a storm in a ~3,500 px view.

**Edge cases:**
- A ghost that spawns after showdown entry gets the showdown cooldown from its first charge. The 1.0 s arm delay is unchanged.
- At match point, puffs stay hushed (K-5). The showdown doesn't un-hush.

**Lanes:** **lane G** (`GhostDirector.gd` holds the cooldown and cap; the lane G map names `GhostGoat*.gd` / `LivingCues.gd`, so add `GhostDirector.gd`
to it for this item) · **lane H** (the ghost ring turns gold in the showdown).

### 6.3 L3 ROWDY ARENA (rank 3): pure-physics contact booster, and the diagnosis check

**Mechanic.** Inside the showdown, every bounce-surface launch (tier launch speed, after supercharge) is multiplied by
**`showdown_bounce_mult_per_step` = 1.07** per step:
- launch ×1.07, 1.145, 1.225;
- **apex ×1.14, 1.31, 1.50**, since height grows with the square of speed.

Unchanged: refuel per bounce, bumpers (restitution stays < 1), ghost clouds and moving hazards.

**Why it's an arm:**
- It is the only lever that needs **no model of human response**. Faster fighters cross paths more often, and more of them reach
  `smash_impact_min` 900 px/s.
- If L3 shortens tails strongly, the drought is about speed. If only L1 does, it's about having a reason to converge.

**Why 1.07 and a 1.5× apex cap:** the GDD's arena-wide "Super Bouncy" is 2× bouncier. Half of that is the most a mid-fight change should do
without making springs fling fighters past the top blast line.

**Risks (pre-registered as guardrails):**
- more top-edge self-KOs;
- a "the floor went weird" feel;
- feel judged only by a CD (no headless proxy).

**Lane:** `Player.gd` / BounceResolver (no current lane; a new **lane P**). It touches every bounce, so it carries the highest regression risk of
the three.

### 6.4 Ranking and expected value

| | Targets | Cost | Owner-safety | Fun read | Prior on S4 |
|---|---|---|---|---|---|
| **L1** | the diagnosed cause (no reason to meet) | M (new drop + auto-activate + bot seek + art + audio) | clean (a prize) | highest: a scramble, then super spam | strong |
| **L2** | felt idleness (S5) | S | clean (WK-37 fences) | high for ghosts, neutral for fighters | weak on S4 |
| **L3** | contact via speed | S code / risky feel | clean | mixed (random-feeling?) | moderate, with self-KO risk |

**Ship hypothesis:** **L1 + L2 together (arm A4).** L1 cuts the long waits, and L2 makes the remaining wait active. L3 ships only if L1 fails and
L3 passes.

---

## 7. Feedback design (169c builds the ruled arm's half; every cue follows the Rule of Three)

| Event | Visual | Audio (sound-designer; must respect WK-170: KO stays the loudest event) | Kinesthetic |
|---|---|---|---|
| **SHOWDOWN entry** (step 1) | Top band **"SHOWDOWN!"** in gold, 1.0 s, the same band and style as TWO LEFT!. Backdrop dims `showdown_dim` 0.10 (screen-space multiply on the backdrop layer only, never on goats, platforms or ghosts). Both fighters get a gold rim light (`showdown_rim_alpha` 0.6). Both fighters' HUD cards get a gold frame | Music **hush**: the bed ducks 6 dB over 1.0 s and a drum/heartbeat stem fades in at `showdown_music_layer_db` −8 dB. A one-shot sting on the Stingers bus, with a **rise below the KO's** (KO +6.5 LU, CD5) | Fighters' pads 0.2 / 0.3 for 0.15 s. Ghosts' pads 0.1 / 0 for 0.1 s ("something's happening") |
| **Step 2 / 3** | Dim +0.03 per step (max 0.16). The rim light pulses once. No banner | The drum stem steps up (stem B, then C; no tempo change, so no "clock" feel) | none |
| **Golden drop telegraph** | Gold converging sparkles (radius ×1.3), a soft gold glow ring at the point | A bright **bell "ding-ding"**. **Never a beep** (WK-170: beeps read as the countdown) | none |
| **Golden bubble live** | Glossy gold bubble 1.2× with a tank icon, slow bob, sparkle. **First drop of a stage only:** the top band shows "GOLDEN TANK!" | Shimmer loop at −18 dB | none |
| **Collect** | "GOLDEN TANK!" word pop in the goat's colour at the goat. The fuel ring turns cyan (the existing `bubble_fuel_locked_color` / HUD Unlimited read) | Gold sting (≤ KO rise) | Holder 0.5 / 0.6 for 0.15 s |
| **Tank ends** | The cyan ring blinks 3× in the last 1.0 s, then turns gold | A small "pfff" | none |
| **L2 active** (ghosts) | The ghost legend line returns for 2 s by each ghost card: **"SHOWDOWN! (X) PUFF FASTER"** (device glyphs). The puff-ready orbit cloud turns gold | The ghost bleat gets a crowd layer (+2 voices) during the showdown | none |
| **L3 step** | The bounce surfaces' rim gets a gold sheen pulse | Bounce SFX pitch +1 semitone per step (an audible "the floor got wilder") | Bounce rumble ×1.15 per step |

**Readability rules (Pillar 5):**
- **The dim may only raise goat contrast.** Test T6 measures goat-vs-backdrop luma contrast and expects it ≥ OFF.
- Ghosts keep their alpha rules.
- The golden bubble must be told apart from a normal bubble 20/20 at couch scale (art-director, T6).
- **Forbidden:** a closing vignette, an edge line, a camera move, a timer digit, or a red "danger" grade. The showdown is gold and warm, never
  hazard red.

---

## 8. Tuning knobs (all in `Tuning.gd`, a new `# --- WK-169 showdown ---` block; **every switch OFF = today, byte for byte**)

| Constant | Default (ship) | A/B value | Rationale |
|---|---|---|---|
| `showdown_enabled` | **false** | per arm | Master switch. False = no state, no node, no telemetry content. |
| `showdown_delay` | 6.0 s | 6.0 | §5.1: touches ~24 % of stages carrying ~59 % of dead-seat seconds. |
| `showdown_step_s` | 8.0 s | 8.0 | = drop interval: one escalation beat per golden tank. |
| `showdown_max_steps` | 3 | 3 | Escalation holds after 22 s of tail. |
| `showdown_drop` | false | A1, A4 | L1 switch. |
| `showdown_drop_interval` | 8.0 s | 8.0 | 1 s telegraph + about 2-3 s race + 6 s tank fills it. |
| `showdown_drop_telegraph` | 1.0 s | 1.0 | = `pu_spawn_telegraph` (a known scramble cue). |
| `showdown_drop_life` | 7.0 s | 7.0 | Pops before the next drop, so every drop re-picks the fair point. |
| `showdown_drop_dur` | 6.0 s | 6.0 | Shorter than `pu_unlimited_boost_dur` 8.0: less dominance, more drops. |
| `showdown_drop_view_inset` | 120 screen px | 120 | The fair point must be visibly on screen. |
| `showdown_drop_tank_lock` | 1.0 s | 1.0 | No drop until a tank has been over for this long (no chain dominance). |
| `bot_golden_seek_p` | 0.5 | 0.5 | Same rule as the HumanSim5g layer; matters only when a drop exists. |
| `showdown_ghost_boost` | false | A2, A4 | L2 switch. |
| `showdown_ghost_cd_mult` | 0.5 | 0.5 | 7.0 → 3.5 s. The idle gap halves. |
| `showdown_ghost_cap_per_step` | 3 | 3 | The cap stops binding in long tails. |
| `showdown_rowdy` | false | A3 | L3 switch. |
| `showdown_bounce_mult_per_step` | 1.07 | 1.07 | Apex ×1.5 at step 3, half of the GDD's Super Bouncy. |
| `showdown_dim` / `_dim_step` / `_dim_max` | 0.10 / 0.03 / 0.16 | n/a (headless) | Raises goat contrast; never a closing edge. |
| `showdown_rim_alpha` | 0.6 | n/a | Fighter focus. |
| `showdown_music_layer_db` | −8.0 | n/a | Under the bed. The sting is sound-designer-owned and must stay below the KO rise. |
| `showdown_banner_time` | 1.0 s | n/a | = TWO LEFT!. |

**Post-QA knobs, applied in order, one variable at a time (FEEL §0):**
- **Golden tank too strong** (holder wins the tail > 85 %, or CD: "unfair"): `showdown_drop_dur` 6 → 4, then grant `star` (pu_star_dur 5 s) instead.
- **Golden tank ignored** (collected < 50 % of drops in lane N): `showdown_drop_life` 7 → 8 and bubble size 1.2 → 1.4. Don't move the point closer to
  one fighter.
- **Tails still long** (`E` ratio 0.70-0.85): `showdown_delay` 6 → 5, then `showdown_drop_interval` 8 → 6.
- **Self-KO over its guardrail under L1:** `pu_unlimited_super_lockout` stays (shared). Instead add `showdown_drop_lockout` 1.0 → 1.4 as its own knob.
- **L2 KM over its band:** `showdown_ghost_cd_mult` 0.5 → 0.7, then `showdown_ghost_cap_per_step` 3 → 1. Never change cloud strength.
- **L3 self-KO over its guardrail:** `showdown_bounce_mult_per_step` 1.07 → 1.04.

---

## 9. Telemetry (169b-prep adds; `round_stats` per stage, MatchRecorder logs the same)

- **Per stage:**
  - `two_alive_t`: stage time when `ne` became 2, or −1;
  - `showdown`: `{t_enter (or −1), steps_t: [], drops: [{t_tel, t_live, pos, d_a, d_b, picked_from_n, collected_by (or −1), t_collect, popped}],
    tank: [{idx, t_on, t_off, supers, smashes}], ended_by: "credited"|"self"|"haunted"|"sd"}`;
  - `tail_smashes`, `tail_supers` and, per fighter, `tail_boost_s` and `tail_air_s`;
  - `tail_bounces` per fighter (L3);
  - `forced: [idx...]` (lane T harness eliminations; excluded from every guardrail).
- **Per kill:** `phase` = "4" | "3" | "2" | "2S" (2-alive in showdown) · `showdown_step` · `edge` (already `blast_edge`) · `golden_holder` (bool for
  killer / victim).
- **Per ghost (GhostDirector):** `dry_s`, `showdown_s`, `showdown_dry_s`, `puffs_in_showdown`, `cap_hits`.
- **Analyzer-derived** (no runtime cost): S1-S4, human waits, `E`, and holder-wins-tail.

---

## 10. A/B plan: WK-169b (one headless batch, at most 2 Godot processes)

### 10.1 169b-prep (gameplay-programmer, S, before the batch; code-only, outside the cap)
- Build the §5 state, L1, L2 and L3 behind the §8 switches, all default OFF, plus §9 telemetry.
  - Minimal presentation is enough: the banner, plus the existing unlimited-boost bubble tinted gold. It's headless-only and stays behind an OFF
    switch.
  - The real art, audio and dim come in 169c for the ruled arm only.
- **Bot golden seek** goes in `InputBot.gd` **after WK-161b commits** (lane B). The prep may land the rest first.
- **Proof that OFF = today:** `showdown_enabled=false` creates no node and no `showdown` key. A 4-bot 5-stage smoke run is identical in stage
  structure (state sequence, phase_log) to HEAD.
- Parse gate (`--headless --editor --quit`, grep for parse errors). Commit, plus a STATUS line.

### 10.2 Build and rig (as WK-20d Phase A; harness copied to `tools/out/wk/wk169b_batch/`)
- `git archive HEAD` into the scratchpad. Same treatment as Phase A: McpInteractionServer autoload removed, renamed, `--gb-port=0`, the repo's
  uncommitted edits not included. Headless, `--fixed-fps 120`, game time only.
- 3 HumanSim seats (pad:1, pad:0, kb) + 1 CPU (MIX → L2). LIVES 1, ghosts ON, powerups default, MEADOW MILE,
  **`tune_circuit_session_deck=0`** (the fixed authored order, so arms see identical arena sequences).
- Arms are set by boot args via the existing `tune_<name>=<v>` mechanism (bool / int / float only; every §8 A/B knob qualifies).

### 10.3 Driver: HumanSim5g = HumanSim5 + one pre-registered layer, identical in every arm
- **Golden-seek layer.** While a golden bubble is telegraphing or live, at each plan tick (0.14-0.30 s):
  - only when the seat is not in RECOVER and not mid-super;
  - with p **0.5**, if the seat's distance to the bubble is ≤ **1.25 ×** the rival's distance to it, the seat steers to the bubble (aim noise
    0.18, boost when |g| > 180 and fuel > 8; the chase rule's boost logic);
  - otherwise it keeps chasing.
  - **Rationale:** the CD reads the powerup telegraph as "the starting gun for the scramble". A newcomer goes for the shiny thing about half the
    time, and only when they think they can win the race.
- **No other change.** HumanSim still never presses POWERUP, so normal powerups stay inert for human seats, exactly as in CD5. The golden tank
  auto-activates on touch.
- **The layer is inert when no golden bubble exists,** so A0, A2 and A3 run HumanSim5 behaviour byte for byte. A0 is the CD5-comparable baseline.
- **Validity caveat:** L1's effect is measured *under a modelled human response*. If HumanSim5g collects < 50 % of drops, the arm is
  untestable, not failed (decision row 6). Real-hands confirmation is the CD6 felt pass plus any owner session.

### 10.4 Lanes, arms, seeds

| Lane | Flow | Purpose | Arms × seeds × stages |
|---|---|---|---|
| **T (forced tail)** | `flow=loop`, KILLS 999, scoreboard skipped. **`force2=3.0`:** at 3.0 s of COMBAT, if seats 0 and 1 are both alive, the harness eliminates every other living seat (kb P3 + CPU) through the normal death path with no attacker. Flagged `forced`; both become ghosts normally. If seat 0 or 1 died before 3.0 s, the stage counts as `natural` and is excluded from S4. | Powers S4 / S5: **every stage is a two-human 1v1 with a human ghost + a CPU ghost**, River Split's exact shape | **A0** 3 × 20 = 60 · **A1** 3 × 20 = 60 · **A0r** 2 × 20 = 40 · **A2** 2 × 20 = 40 · **A3** 2 × 20 = 40 → **240 stages** |
| **N (natural)** | `flow=real`, KILLS 10, first-to-10 + one REMATCH per process (Phase A lane 2), scoreboard, intro and victory on | S1-S3 + every guardrail on the real stage population | **A0** 3 seeds · **A1** 2 · **A4** 2 → 7 processes, ~150 stages |

- **Arms:**
  - **A0** = all OFF;
  - **A0r** = all OFF on *different* seeds (the sampling-noise control);
  - **A1** = `showdown_enabled` + `showdown_drop`;
  - **A2** = `showdown_enabled` + `showdown_ghost_boost`;
  - **A3** = `showdown_enabled` + `showdown_rowdy`;
  - **A4** = A1 + A2.
- **Seeds:**
  - lane T: A0, A1, A2 and A3 share seeds {201, 202, (203 for A0/A1)}; A0r uses {211, 212};
  - lane N: A0 {301, 302, 303}; A1 and A4 {301, 302}.
  - Shared seeds pair stages by arena and sequence. The sim doesn't replay identically (WK-116 note), so the analysis is unpaired with
    arena-stratified bootstrap, and pairing is a bonus.
- **Run order:** seed-major and interleaved across arms inside each lane (A0, A1, A2, A3, A0r, ...), so drift from other agents' load spreads
  across arms.
- **Wall budget:**
  - Lane T ≈ 240 × ~17 s game ≈ 68 game-min. Lane N ≈ 7 × ~7.5 game-min ≈ 52 game-min.
  - At Phase A's ~3.2× realtime per lane, that's **≈ 21 min and ≈ 17 min, both lanes in parallel ≈ 22 min wall.** Phase A was 18.5 min for 419
    stages.
  - Per-process `wall=` limits as in Phase A (2700 s timeout, `wall=1500` lane T, `wall=2400` lane N). A stage still running at 120 s game time
    is recorded as censored at 120 (it isn't expected; the max seen is 70.8 s).

### 10.5 Also logged (watch lines from BACKLOG)
- Opening self-KOs < 3 s, per arm (CD5: 2/21 at 2.8-2.9 s).
- CPU self-KO share (WK-168 watch).
- T1-G's "no stage > 60 s" line on lane N stages.

### 10.6 Analysis (QA; `wk169b_stats.py` beside `phaseA_stats.py`, reusing `stage_rows`)
1. **Before reading arm data:** run the T2 / S1-S3 analyzer on Phase A's raw logs (419 stages, b1ca88b) and record the natural A0 reference
   distribution in the audit. It's for calibration only; decisions compare against same-batch A0.
2. **S4:** `E`, T2 median / p75 / p90, P(T2 > 20 s) per lane-T arm.
   - Bootstrap: 5,000 resamples of stages, stratified by arena, for the ratio `E(arm)/E(A0)` and its 90 % CI.
   - Noise floor: `E(A0r)/E(A0)`.
3. **Projection** (the primary estimate of the natural effect):
   - Fit lane T's per-arm tail survival curve beyond 6 s, measured from the forced elimination.
   - Apply each arm's curve ratio to the natural A0 tails (lane N A0 + the Phase A reference) to project S1s and S3.
   - Lane N's direct A1 / A4 measurement is the **replication**. Its direction must agree.
4. **S1, S2, S3** on lane N per arm: median, worst, p90 seat-match, with CD5 shown for reference. Pooled S1s with a stratified bootstrap.
5. **Guardrails §11** on lane N (all arms run there) and the tail-specific ones on lane T.
6. **Mechanism checks:**
   - drops collected %, time to collect, holder wins tail %;
   - supers and smashes per showdown-minute vs A0's 2-alive minutes beyond 6 s;
   - L2 `showdown_dry_s` share and puffs per ghost-showdown-minute;
   - L3 top-edge deaths.

### 10.7 Pre-registered predictions (written before any prototype or data; QA marks hit or miss)

| ID | Prediction |
|---|---|
| **P1** | Lane T A0: T2 median **6-12 s**, P(T2 > 20 s) **15-30 %**, `E` **6-14 s**. (Fresh fighters at 3.0 s: longer than natural tails.) |
| **P2** | A0r vs A0: `E` ratio within **0.80-1.25**. Outside that, the batch is too noisy to rule (row 6). |
| **P3** | **A1 `E` ratio 0.45-0.70**, P(T2 > 20 s) **−40 to −65 %** relative, T2 p90 **−30 to −45 %**. The T2 median moves only **−5 to −15 %** (most of the effect sits beyond 6 s). |
| **P4** | A1 mechanism: drops collected within 4 s of going live **70-85 %**. Holder wins the tail **55-75 %**. Smashes per showdown-minute **+60 to +120 %** vs A0's equivalent tail time. Super share of tail-ending credited KOs **+5 to +15 pp**. |
| **P5** | **A2 `E` ratio 0.85-1.05** (rescues roughly cancel bonks). Showdown dry share **75-90 % → 50-65 %**. Puffs per ghost-showdown-minute **×2.0-3.0**. Haunted tail-enders **+1 to +4 pp**. KM-1 **+0 to +2 per 100 credited KOs**. |
| **P6** | **A3 `E` ratio 0.70-0.95.** Tail-ending self-KO share **+3 to +8 pp**, mostly top edge. Credited share of tail-enders **−3 to −8 pp**. |
| **P7** | Lane N A1 vs A0: S1s **−6 to −14 %**. S1 median **−5 to −12 %**, worst seat-match **−15 to −40 %**. S2 median **−0.3 to −1.5 pp**, worst **−4 to −10 pp**. S3 > 15 s share **−40 to −70 %**. |
| **P8** | Lane N A1: median stage length **−0 to −3 %** (the showdown never touches stages with short tails). Mean stage **−6 to −14 %**. Credited KO/min **+3 to +10 %**. Max stage **≤ 45 s** (T1-G's > 60 s line passes). |
| **P9** | Lane N A4 ≈ A1 on S1-S3 (within ±5 %), and ≈ A2 on S5 and KM. |
| **P10** | Showdown fires on **20-30 %** of lane N stages (CD5: 24 %). |
| **P11** | Every arm: human self-KO share within **±2 pp** of A0 outside the showdown (the identical-code check), and 0 stages ended by anything but elimination. |
| **Forecast** | Decision row 1 with A4 (L1 + L2): **≈ 55 %**. Row 1 with A1 only (L2 misses KM or S5): **≈ 20 %**. Row 3 or 4: **≈ 15 %**. Row 5 or 6: **≈ 10 %**. |

### 10.8 Decision table (pre-registered)

| Row | Condition | Ruling |
|---|---|---|
| **1** | A1 passes S4 (`E` ≤ 0.70 × A0, CI < 1.0), P2 holds, lane N A1 passes S3 (≥ 40 % fewer > 15 s waits) and S1s (≥ 8 % lower, direction matches the projection), and every §11 guardrail passes | **Ship L1** (169c). If A2 also passes S5 (≤ 0.75 × A0) with KM inside G7, and A4 passes its guardrails on lane N: **ship A4 (L1 + L2).** |
| **2** | A1 passes S4 but one guardrail fails | Apply the matching §8 knob (one), and re-run lane T for A0 / A1 only in the *next* headless slot. No ship on this batch. |
| **3** | A1 fails S4, A3 passes S4 and its guardrails | The drought is about speed. Ship L3 **only after** a rendered CD feel check. Without one, report "Won't do yet". |
| **4** | Only A2 passes (S5, KM) | Ship L2 as "ghost agency". It doesn't meet the BACKLOG accept on share. Report S1-S3 unchanged honestly. WK-169 → partial; OQ-1 stands. |
| **5** | No arm passes | **Won't do**, with the numbers. File the OQs. Keep the Phase A reference distribution as the new baseline. |
| **6** | P2 fails (A0r vs A0 outside 0.80-1.25), or HumanSim5g collects < 50 % of drops | No ruling. Report, resize (more lane T seeds), re-queue. |

---

## 11. Guardrails (same-batch A0 is the reference; CD5 / Phase A for sanity)

| ID | Guardrail | Bar |
|---|---|---|
| **G1** | Credited KO per combat-minute (lane N) | ≥ 0.95 × A0 and ≤ 1.30 × A0 (Phase A 11.9; CD5-era similar) |
| **G2** | Human self-KO share of human deaths (lane N) | ≤ A0 + 3 pp (CD5 16 %, Phase A 17.4 %) |
| **G3** | Self-KO share of tail-ending deaths (lane T, natural-excluded) | ≤ A0 + 8 pp |
| **G4** | Median stage length (lane N) | within −10 % / +5 % of A0. Stages under 6 s within ±2 pp. WK-20d's T1-V median ≥ 10.0 s line not broken |
| **G5** | Super share of credited KOs (lane N) | ≥ A0 − 3 pp (BACKLOG: ≥ CD5 62 % relative) |
| **G6** | **Credit integrity** | **Ghost-credited KOs = 0** (K-1). KOs credited to anyone but the K-3 last attacker = 0. Stages with a death but no credit ≤ A0 + 3 pp |
| **G7** | **Ghost-decided KOs** | **Match-deciding ghost involvement (KM-4) = 0**, every arm, hard. **Cloud-decided credited KOs (KM-1)**: A1 / A3 = A0 ± 1 event (ghosts unchanged); A2 / A4 ≤ A0 + 2 per 100 credited KOs and ≤ 5 % absolute. Haunted stage-enders (KM-3) ≤ 5 % |
| **G8** | SD (double-KO) rate | within ±3 pp of A0 |
| **G9** | Golden tank holder wins the tail | 50-85 % (above 85 % = too strong → §8 knob) |
| **G10** | Motion health (CPU) | stuck episodes and underside bounces ≤ 1.15 × A0. Living humans 100 % airborne. Living-human boost share within −3 / +8 pp of A0 |
| **G11** | **No stage ender** | 100 % of stages end on the final elimination (± 1 frame) or MATCH_END on a kill. 0 state changes caused by the showdown |
| **G12** | Camera | No code path touches `_update_camera` or `camera_focus_points` (code review), plus the T5 invariance check in 169c |
| **G13** | Opening self-KO watch (< 3 s) | logged per arm (info) |

**Interpreting "ghost-decided KOs = 0":** the hard zeros are G6 (a ghost can never be credited) and G7's KM-4 (a ghost can never decide a match).
KM-1 can't be zero by construction under WK-37's K-3 ("living credit stands"), not even in A0, so it is banded. **Director question DQ-3:** if the
director wants a literal KM-1 = 0, the only clean rule is "a credited KO whose last surface contact within the fence was a cloud is voided to
HAUNTED". That changes WK-37 K-3 and would need its own A/B.

---

## 12. Acceptance for 169c (the ruled arm; QA-verifiable by driving the game)

Measurement validity: game time from `phase_log.tick_s` / `round_stats`. Motion is judged from WK-93 recordings. Software GPU caveat: wall-clock
timing isn't valid.

- **T1 Trigger.** 10 scripted stages (4 bots; eval-eliminate seats 2 and 3 at 3.0 s):
  - SHOWDOWN enters at `two_alive_t` + 6.0 s ± 1 frame, 10/10; steps at +8 s and +16 s;
  - 0 entries when the tail ends before 6 s;
  - 0 entries in a 2-seat match, in SPORTS and in TRIALS;
  - a forced double-KO of the last two clears the showdown within 1 frame of SUDDEN_DEATH. Golden bubbles pop, the SD revive is unchanged and
    puffs are hushed.
- **T2 No stage ender.** Two passive bots (InputBot disabled, so they bounce in place on far platforms), showdown ON, 120 s of game time:
  - state stays COMBAT throughout; steps and drops continue on schedule;
  - kill bounds, `_stage_rect` and camera bounds are identical at 0 s and 120 s;
  - eval-killing one bot then ends the stage through the normal path.
- **T3 Fair point.** 20 scripted fighter placements across 5 arenas: the chosen spawner is the in-view minimiser of max(d_A, d_B), 20/20.
- **T4 Golden drop contract (L1):**
  - telegraph 1.0 s (non-solid); live 7.0 s, then pops; on touch, Unlimited Boost for 6.0 s ± 1 frame, fuel pinned, refire lockout 1.0 s;
  - no drop while a tank is active or within 1.0 s after it; one golden bubble max;
  - a ghost, cloud, ball or bomb overlapping the bubble collects nothing; same-frame double touch goes to the closer centre;
  - a CPU fighter seeks it under the §6.1 rule (log check over 20 drops).
- **T5 Camera invariance.** Identical scripted fighter paths, showdown ON vs OFF: camera `global_position` within ≤ 1 px and zoom within
  ≤ 0.001, every frame. Plus the owner-rule check in live play over 5 stages: 0 frames with an in-bounds living player off-viewport.
- **T6 Readability (rendered, looked at):**
  - a 20-frame sheet from showdown tails: living vs ghost classification 20/20;
  - golden vs normal bubble 20/20 (art-director);
  - goat-vs-backdrop luma contrast ≥ the OFF value (measured);
  - no edge line or inward motion visible in a 10-frame burst across a step change.
- **T7 Audio** (`measure_run.py` on a WK-93 capture with a showdown): showdown sting and golden sting rise below the KO rise; the bell is
  present; integrated loudness still −16..−18 LUFS; the countdown rule from WK-170 is intact.
- **T8 L2 (if shipped):**
  - in the showdown, puff cooldown 3.5 s (bot ghosts 7 s) and cap 6 / 9 / 12 per step; outside the showdown, the WK-37 values;
  - at match point, 0 puffs (K-5) even in the showdown;
  - T5 of WK-37 (credit fence) re-run: ghost-credited = 0.
- **T9 L3 (if shipped):** tier launch speed ×1.07^step ± 2 %; refuel per bounce unchanged ± 0.1; bumper rebound unchanged.
- **T10 Motion.** A WK-93 recording of a 2-alive tail of 20 s or more with the showdown (bots 2, 2, 3, 3 or HumanSim, MEADOW MILE), contact
  sheet viewed:
  - fighters converge on the drop;
  - no fighter parks;
  - the dim never hides a goat;
  - plus a one-line felt verdict.
- **T11 OFF parity.** `showdown_enabled=false`: no showdown node, no `showdown` content in round_stats, and a 40-stage seeded run's stage metrics
  inside the A0 / A0r noise band from 169b.
- **T12 Felt pass (WK-CD6, creative-director),** with a 3-seat couch and real flow. Answer in plain language:
  1. When I died early in a long stage, did the wait feel shorter or busier?
  2. Did the showdown ever feel like the game ending the stage for us?
  3. Did the golden tank feel fair to the one who missed it?
  4. Could I tell the golden bubble from the others, and the ghosts from the fighters, with the dim on?

  A "yes" on 2, or a "no" on 4, is a FIX regardless of T1-T11.

---

## 13. Fantasy-fit check (GAME_ESSENCE)

- **Airborne and using the jetpack?** Yes, more so: the drop is a flight race. G10 guards boost share.
- **Do distances require boost or super?** The fair point is where both have to travel. On void arenas it usually sits across a gap.
- **Is the super the decisive kill?** The golden tank is super frequency. P4 predicts the super share of tail KOs rises; G5 guards it.
- **Constant motion, no camping?** A fighter who hangs back now hands the other a golden tank. Ghost clouds still sink and pop.
- **Pillar 4 (death is cheap)?** It goes after the 30-70 s waits directly (S3).
- **Pillar 5?** The dim raises contrast. Gold, not red. No camera motion. T6.
- **Pillar 6?** The ghosts become a crowd: faster puffs and a crowd bleat.
- **First-time human?** "SHOWDOWN!", then a golden thing appears in the middle, then go get it. No rules text is needed. The ghost legend
  re-teaches PUFF FASTER.

---

## 14. Owner questions (separate; none is an arm, none blocks 169b)

- **OQ-1 LIVES 2 default when 3 or more humans are seated?**
  - **Why ask:** it's the only lever that moves the *median* spectator share. Under LIVES 1 the structural floor is ~20-21 % at today's death
    timing (§1.6), and a showdown moves the median by ≤ 1.5 pp (P7).
  - **Counter-evidence:** CD1 saw a LIVES 3 group wait *longer*. The first eliminated waits for everyone's extra lives. LIVES 2 also slows Duck
    Game churn, which the owner's 2026-07-03 directive chose on purpose.
  - **Studio recommendation:** keep LIVES 1. Revisit only after a real couch session.
- **OQ-2 A showdown camera exception?**
  - A slow zoom toward the duel was suggested. It conflicts with camera rule 6 (zoom-in cap) and rule 3 (targeting).
  - We will not build it unless the owner explicitly grants a showdown-only exception.
  - **Studio recommendation:** no. The visual hush does the job without touching the camera.
- **OQ-3 Should wounds stop healing during the showdown (the 8 s heal clock pauses)?**
  - It raises KO conversion without touching the knockback array, but it bends the owner's damage directive §3.
  - The CD5 data says conversion isn't the problem (55 %).
  - **Studio recommendation:** ask only if L1 fails (decision row 5).

## 15. Director questions (studio-level)

- **DQ-1** Restate the WK-169 accept around S1s and S3 (powered, fixable), with S2 reported. Reason: §1.6 shows the median share is structural
  under LIVES 1.
- **DQ-2** Confirm the WK-20d Phase A reading. The 70.8 s grounded duel is a WK-169 tail watch note, not a WK-20d reopen. It is the case lane T
  samples directly. (Designer's answer: yes.)
- **DQ-3** Accept G7's interpretation of "ghost-decided KOs = 0" (hard zero on ghost credit and match-deciding; KM-1 banded), or commission the
  K-3 change as its own item.
- **DQ-4** Lane sequencing: 169b-prep needs lane D (`PartyMatch.gd`, after WK-172) and lane G. Bot golden seek needs lane B after WK-161b. That
  fits the headless queue order (161b batch #1, 169b #2).

## Proposed DECISIONS entry (for the director to log when 169c is accepted; not written by this spec)

"SHOWDOWN (WK-169). When two Brawl fighters have been alone for 6 s with at least one ghost watching, the stage enters SHOWDOWN:
- the music hushes to drums, the backdrop dims, and the fighters get a rim light;
- [L1] a golden tank (6 s Unlimited Boost, auto-activated) drops at the fair point between them every 8 s;
- [L2] ghost puffs cool down twice as fast, with a higher cap.

It **ends nothing**: no timer ends a stage, no boundary moves, the SD stays double-KO only, and the camera, knockback array and LIVES are untouched.
Switch `showdown_enabled`.

Evidence: docs/audit/<169b>.md (S4 E ratio, S1s, S3, guardrails).

Reopen if:
- the CD felt pass reports 'the game ended the stage for us';
- the holder wins > 85 %;
- the owner answers OQ-1/2/3."
