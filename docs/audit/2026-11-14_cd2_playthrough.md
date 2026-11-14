# WK-CD2: Creative Director cold playthrough #2 (2026-11-14, evening)

**Build:** `weekend/polish` @ b669912 (about 45 fixes since CD1, including WK-95/95e flight, WK-104/105/106 sports, WK-121 limiter and WK-107 LONG HAUL).
**Display:** rendered at 1920x1080 at **120-121 fps** (`gbplay perf`: display on, valid). I launched Godot directly with run_game's arguments and stopped only my own PIDs. Other agents' headless Godots were running the whole time.

**Method:** a first-time couch group of three, each on its own device: **pad 1 (P1), keyboard (P2), pad 0 (P3)**. The route was:
- boot → mode select → Herd Lobby → a full default **Brawl** to victory (12 stages) → REMATCH → pause flows (pad pause-owner gating, keyboard pause, Options → back, hold-QUIT).
- **Rocketball** 2v2 through the team lobby (CENTER PITCH, to 6) → CHANGE SETUP → hold-B exit.
- **Dropshot** 2v2 (SUNSET BEACH, to 6).
- **Trials**, Flight School lessons 1-3, two players.

In matches, each human was driven by an **injected human-style driver**. It is not repo code: it lives at `scratchpad/HumanSim.gd` and posts real pad and key events per device. It re-plans every 0.14-0.30 s with aim noise; the keyboard player is quantised to 8 directions. It chases the nearest rival, holds FLY to travel, takes an aimed super when in range with a clear line, recovers toward the nearest ground, and goes around platforms. In sports it chases the ball and lines up behind it toward the enemy goal.

For flight feel I also used a **"point-and-go" pilot** (`scratchpad/Pilot.gd`). It points the stick straight at a target and holds A, which is what a newcomer does.

**Recordings (WK-93 Movie Maker, 30 fps, every frame):**
- `tools/out/rec/cd2_brawl_pendulum/`: 3 human-sim players + 1 CPU, 3 LIVES, Pendulum Heights, 40 s of combat. I used direct Movie Maker plus an attached MatchRecorder, with no bot takeover.
- `tools/out/rec/cd2_bots_islands/`: 4 bots (L2/L3/L3/L4), Islands Void, 25 s.
- `tools/out/rec/cd2_bots_singularity/`: 4 bots L3, Singularity, 20 s.

**Evidence:** stills are in `tools/out/cd2/`. Match logs are `m1/` (Brawl: `stats.json`, `log.json`), `rb/` and `ds/` (each with `phase.json` game-time phase logs). Recording crops are `rec_ko_f426-452.png` and `rec_blackhole_zorder.png`.

**Limits:**
- The driver is not a human. It fights whoever is nearest, so the humans fight each other as much as the CPU. Treat the balance numbers as hypotheses.
- I did not judge audio by ear.
- **Tooling trap (affects every wall-clock number):** one 1080p `gbplay screenshot` **stalls the game about 1.25 s**. `phase_log.stall_ms` shows 1254, 1281 and 937 ms. All durations below are **game time** from `phase_log.tick_s` / `round_stats`, or from recordings. They are not the monitor's wall clock.

---

## 1. Verdicts on the owner's check-in asks

| Owner ask | Verdict | Evidence |
|---|---|---|
| **"Record ~20 s of a match and analyse it frame by frame"** | **DONE, and it works as a standard.** | Three new recordings for this pass (above). Contact sheets, overlays, aim reports and trajectories came from `rec_sheet.py`. Direct Movie Maker with an attached recorder also works for **human-driven** matches, not only bot ones (`cd2_brawl_pendulum`). |
| **"The aiming mechanic looks crazy when the bots use it, it spins like nuts"** (WK-94) | **FIXED.** | **36 bot super-aim windows** across the two bot recordings plus the CPU in the human recording. Every window sits at or under its level's sweep cap: L2 1.91°/tick, L3 2.63°/tick, L4 3.58°/tick. There were **0 jumps over 15°**. Bots hold the aim for 36-135 ticks, so the wind-up reads as a deliberate sweep. Reports: `cd2_bots_islands/aim_report.png`, `cd2_bots_singularity/aim_report.png`. (The human-sim's aim windows are jumpy. That is my driver's noise, not the game.) |
| **"Normal flying isn't responsive enough… super should be the way to attack, not to get around"** (WK-95) | **FIXED for flight. Mostly fixed for "super = attack".** One new hole: the tutorial (CD2-01). | **Humans:** pointing the stick at a ring 1,640 px away and holding A **arrived in 2.0 s, passing 34 px from the ring centre** (77 fuel used). The keyboard player, holding only →+FLY with a 0.35 s tap of ↑, **also flew straight through** (sag of about 150 px/s, as specced). A straight 2,000 px climb took **1.7 s**. **Bots:** supers by purpose on Islands Void were **12 ATTACK / 1 DODGE / 1 RECOVERY / 1 TRAVERSAL (7 %)**. On Singularity they were **15 ATTACK / 2 recovery-unneeded / 0 traversal**. Bots spend **37-63 % of alive time on normal boost** (WK-95's target was ≥ 35 %). `traj.png` shows long orange flight arcs, with the red super segments clustered in fights. |
| **"Big swinging pendulums… went right through a player and didn't smash them"**, and **"stiff, poor-quality motion"** (WK-96) | **FIXED.** | In 40 s of human-sim play on Pendulum Heights the recorder logged **29 pendulum contacts → 11 smashes** (impulses 1,100-2,127). It also logged 74 non-lethal shoves and 11 immune touches. 4 of 16 KOs came straight off the pendulum, with no attacker credited. The swing slows at the apex and is fast through the bottom (WK-96 speed sheet; the arc is visible in `cd2_brawl_pendulum/sheet.png`). It no longer reads as a metronome. Cosmetic: the chain hangs from a cloud. |
| **"On a black hole level all the player sprites were behind the black hole"** (WK-97) | **FIXED.** | `rec_blackhole_zorder.png` frame 104: PUFF is drawn fully over the swirl, and a rim-hugging goat in f83 is drawn on top too. |
| **"Sport modes are quite fun, maybe more fun than brawl — focus there too"** (WK-98) | **Agreed. The two full sports matches were the best minutes of the session.** | **Rocketball** 2v2 finished **6-4** in about 137 s, the lead changing hands. **Dropshot** 2v2 finished **6-5 after RED came back from 1-5**. Things that work now: the team lobby ("picking the goat picks the team", RED vs BLUE plates, CPU fill) (`20_rb_lobby_joined.png`); a frozen ball until GO; the **GOAL! / POINT! banner naming the scorer and assist** with a full-screen team-colour flash (`rb/r016`, `ds/d017`); the goal-teaching line on stage 1. Still open: kickoff goals (CD2-03, which reopens WK-104b), the end screen (WK-111), nets and court art (WK-66/66a), and the punch-zoom landing on a wall (SP-09). |

---

## 2. WK-95 feel check (spec §10, six questions)

1. **Does flying feel like "I point, I go there"?** **Yes.** A naive point-and-hold crossed a 1,640 px near-level gap into the ring on the first try, passing 34 px from its centre. The keyboard's 8-way stick made the same flight. The sag is visible but small, so it still reads as an arc rather than rails. I did not run the literal "600 px onto a small pad" test. The longer gap passed with margin.
2. **Is the super now an event?** **For bots, yes.** About 90 % of bot supers are attacks, the aim sweeps slowly, and the fuse ring telegraphs. **For a new human, not yet.** The only place the game teaches the super is Flight School, and lessons 2 and 3 can now be cleared just by holding FLY (CD2-01). A newcomer learns that the super is optional.
3. **Does the bounce still feel like the bounce?** **Yes.** Pressing FLY off a trampoline keeps the launch: vy went from +271 to −800 within 0.44 s, where the old version dropped it to 232. Bounces, springs and pops are intact in every recording.
4. **Did recovering get boring?** **No, it got kinder, and the arena kills now.** Human-sim self-falls dropped to **6 of 33 deaths (18 %)**, against **33 %** in CD1. Deaths moved to smashes and hazards instead. But stages got *shorter*, not longer: median **11.6 s** over 12 stages, against 15 s in CD1. On Islands Void four players died in the first 3 s, and the 3-LIVES pendulum stage burned 11 of 12 lives in one stage. The scared-then-saved beat is still there. What's missing is time to enjoy it (see §5 #1, and WK-20a in §4).
5. **Do bots look like competent pilots?** **Mostly yes.** They carve long arcs, travel on boost (37-63 %) and commit their supers at rivals. One watch item, unverified in motion: on `cd2_bots_islands/traj.png` bots trace tight orange **loop-de-loops** around their target. They keep turning toward a moving rival instead of overshooting and lining up again. At gameplay zoom this may read as buzzing flies. Check it in the next bot recording at --follow zoom.
6. **TowerFall bar: does movement make you feel capable?** **Yes. This is the biggest felt improvement since CD1.** You go where you point, recoveries mostly succeed, and the super is a choice. **Sign-off: SHIP for flight (WK-95 / WK-95e(e) closed)**, with CD2-01 as the follow-up.

---

## 3. NEW findings (BACKLOG checked; not already filed)

### CD2-01 [P1][S] Flight School lessons 2 and 3 no longer teach the super: holding FLY clears them
- **Where:** Trials → FLIGHT SCHOOL → `tut_02_super_shot` ("PRESS + RELEASE X / K — SUPER LAUNCH!") and `tut_03_sky_ladder` ("FLY HIGH FIRST — THEN X / K").
- **What a player experiences:** lesson 1 teaches "hold A to fly". On lesson 2 the newcomer does what they just learned, holds A, and is HOME in 1.7 s without pressing X. The game's only super tutorial ends with the player never having fired one. That cuts against the owner's ruling that the super is *the* attack.
- **Evidence:**
  - Pilot, FLY only, lesson 2: ring reached at **1.72 s with 31 % fuel left** (`47_t2_flyonly.png`, panel "1 of 2 HOME").
  - Lesson 3 from a bounce apex: **reached at 3.3 s on FLY alone**. From a standing start on the floor it fell **about 600 px short** (min y −1812 against the ring bottom at −2410). So lesson 3 is skippable whenever you happen to boost from a bounce.
  - The course premise is now false. The `tut_03` design_intent says "plain-boost ceiling 760 px/s × 3.5 s ≈ 2660 px… tank dies 1000 px short". WK-95 raised the cap to 800 and keeps bounce speed along the thrust.
  - WK-95f's Trials sweep lists Refuel Ridge, ORBIT, cannon and s3, but **not Flight School**.
- **Direction (level-designer + game-designer):** make each lesson fail when you use the verb it is *not* teaching.
  - Teach the super as a **hit**, in the spirit of the owner ruling. For example, lesson 2 becomes "smash the crate or dummy off the ledge" (DestructibleBlock / a target), or a ring past a gap that only the super's 0.45 s / 1,260 px burst crosses.
  - Or lift lesson 3's ring above the post-WK-95 flight ceiling *including* a bounce start.
  - Add "flight-only fails" to the WK-95f sweep's Accept line for all of `tut_02`-`tut_04`.
- **Size:** S (JSON) to M (if a super-hit target is new).

### CD2-02 [P2][S] Co-op Trials: a player already HOME keeps colliding and eats the partner's super
- **Where:** every co-op Trials lesson with a vertical or shared line (`tut_02`, `tut_03`). Both players spawn at the same x (WK-43 covers spawn offsets only).
- **What a player experiences:** P1 reaches the ring and is marked HOME, then falls back down the same column. P2 fires a perfect super and it **dies mid-air**. Twice in three lessons, P2's super was reversed from −2,339 / −3,000 px/s to +518 / +696 px/s within 0.3 s, colliding with HOME P1 in the column. With P1 moved aside, the identical input cleared lesson 3 in 1.2 s.
- **Direction:** once HOME, the goat parks in or behind the ring: frozen, non-colliding, celebrating (this also tells everyone who's done). Alternatively, Trials disables player-vs-player contact. Fold it into WK-43.
- **Size:** S.

### CD2-03 [P1][S] Rocketball kickoff goals are still ~30 % with human-style players: WK-104(b) accept unmet
- **Where:** Rocketball, CENTER PITCH 2v2 (3 human-sim + 1 CPU).
- **Evidence:**
  - 10 goals; rally lengths in game time were 8.3, 4.3, 14.0, 15.4, 12.2, **2.9, 1.75, 1.9**, 9.3 and 10.5 s (`rb/phase.json`).
  - **3 of 10 goals came within 3 s of GO, all scored by human seats** (`rb/r016`-`r020`: "P2 SCORES", "P1 SCORES" ×2).
  - WK-104's Accept was "≤ 10 % within 4 s". The commit 5f34080 reports 22-26 % and attributes the rest to bot pathing (WK-108). With human-style drivers it is still about 30 %, so **WK-108 will not fix it**.
  - The median rally (8.8 s) is inside the 8-20 s band, which is fine.
- **Direction (game-designer):** the vertical tip-off still sends the first contact straight down-court. Try the deep-dive's (c) keeper-plus-midfield formation, or the toss variant where "first touch can't score": the ball is dead until it crosses the centre line, or a goal within 1.5 s of GO is disallowed. Measure with **human-style drivers**, not only bots.
- **Size:** S (tuning plus a small rule).

### CD2-04 [P3][S] The lobby doesn't auto-join the confirming pad when other players carried over
- **Where:** ModeSelect → lobby after a CHANGE SETUP / hold-B round trip.
- **What a player experiences:** from an empty lobby, the pad that confirms BRAWL becomes P1 automatically. After P1 backed out of the Rocketball lobby (P2 and P3 still joined) and chose DROPSHOT, P1's confirm did **not** join them. Their slot stayed "PRESS A TO JOIN" while the other two showed READY (`30_ds_lobby.png`). It cost one extra press and one "why am I not in?" moment.
- **Direction:** always auto-join the confirming device if it isn't already seated.
- **Size:** S.

### CD2-05 [P3][S] Tooling: a 1080p `gbplay screenshot` freezes the game for about 1.25 s
- **Evidence:** `rb/phase.json` `stall_ms` 1254 / 1281 / 937 at every frame where my monitor took a still. Wall-clock "between-stage" times taken with screenshots read 6.2-7.8 s, but the game-time phase log shows the designed ~4-5 s.
- **Why it matters:** any QA timing or feel judgement taken while bursting screenshots is wrong. A human-style driver also gets a 1.25 s freeze mid-flight.
- **Direction:** add the stall to WEEKEND_LESSONS next to the `save_png` note. QA timing reads `phase_log.tick_s`, and motion judgements use WK-93 recordings. Optionally `gbplay screenshot --half`.
- **Size:** S (docs plus an optional flag).

### CD2-06 [P3][S] The P# pip draws over the stage-end banner's sub-line
- **Where:** Brawl STAGE_END. The surviving player's pip sits on top of "P1 +1 · P2 +1 · P3 +1 · P1 SURVIVED" (`m1/h012_STAGE_END.png`).
- **Direction:** hide pips during the STAGE_END banner, or keep the banner on its own layer above them. Fold it into WK-41's overlay ordering.
- **Size:** S.

---

## 4. Regressions vs CD1, and existing items re-judged

**Functional regressions: none found.** Everything CD1 verified still works: title → lobby → arena → full match → victory → REMATCH; pause owner gating (P3's pause ignored P1's A and the keyboard's Esc, `13_pause_others.png`); the keyboard's own pause with ENTER/ESC glyphs (`14_pause_kb.png`); Options → back restoring focus (`16_options_back.png`); hold-confirm QUIT; CHANGE SETUP keeping picks (`26_rb_change_setup.png`). The match ran 12 stages with no script errors.

**Soft regressions / watch:**
- **Sports goal-to-kickoff restart is 3.27 s in game time** (STAGE_END 1.41 + INTRO 0.81 + COUNTDOWN 1.06), against the **2.8 s** on WK-98's PROTECT list. That's about +0.5 s, probably from the WK-106 banner hold. Small, but the PROTECT list said to keep it.
- **Dropshot rallies got longer:** median **14.5 s** in game time (range 9-26 s, 11 points), against the deep-dive's 10.7 s on the same court. That is WK-98 §6.6's predicted effect of easier hovering under the ball. Still healthy, so watch it. Don't act unless rallies cross about 20 s.

**Re-judged:**
- **WK-23/24 (KO readability): delivered, and now the best fix in Brawl.** In `rec_ko_f426-452.png` P2 smashes PUFF: a **blue** impact burst, then PUFF trails a **blue** streak off the bottom. Meanwhile P1's death throws a **pink** edge blast. You can now tell who KO'd whom from the screen alone. **WK-25 (credit pop) is still worth doing**, but as a cherry on top: the score still only changes on the scoreboard, and the −1 for a self-fall is still invisible.
- **WK-20a (who wins and why) has a sharper shape now.** One CPU L2 again beat three humans, **10-6-4-2**. Self-KO −1 is no longer the main reason: humans self-fell only 6 times. The CPU simply out-fought them, with **13 credited KOs against 4/8/5**, and it died 6 times to the humans' 10-12. Add to WK-20a's outcome list: **stage length** (median 11.6 s; 4 of 12 stages under 10 s) and **first-death time** (Islands Void: 4 KOs at 2.0-3.0 s). WK-95's P6 predicted stage length +0-15 %; this run is about −23 % against CD1. The owner's +25 % knockback (2026-07-19) is the knob to test first.
- **WK-21/41 (between-stage flow): budget met in game time** (about 4.1-4.5 s, matching the designed 4.8 / 6.2 s). But stages shrank, so **interstitials are still about 30 % of a Brawl match**. The remaining fix is stage length (WK-20a), not more overlay trimming.
- **WK-37 (ghost goats) matters more.** Human-sim P1 was **dead for 48 % of all combat frames** across the match (4,378 dead against 4,671 alive frames). With 6-12 s stages, "watch the others" is half the evening for a weaker player.
- **WK-86 (powerups follow the stage): verified.** There were no bubbles in sports or Trials. Brawl bubbles appeared inside each arena's own layout.
- **WK-87 (Trials panel avoids the goal): verified** (`43_t1_go.png`, ring top-right and panel top-centre). **WK-85 is still visible:** the bottom third of Trials lesson 1 and of Islands Void is flat mint fill.
- **WK-88 (one name per fighter): verified.** "PUFF" / "PUFF CPU" is consistent across banners, pause chips and the victory plate (`10_victory_b.png`). WK-42 remains: the combat HUD cards are still visible behind the victory screen.
- **WK-13 still open:** mode select still focuses TRIALS first.
- **WK-120 confirmed in play:** with two humans the sports lobby fell back to **1V1, CPUs NONE** (`27_after_holdB.png`). A third player joining flipped it to 2V2.

---

## 5. Fantasy check: the 5 biggest things between this and a proper fun game now

Core verbs, from this run:
- **FLY:** yes, and now it's *good*.
- **BOUNCE:** yes.
- **RECOVER:** yes, and kinder.
- **SUPER-SMASH as the kill:** yes, and visibly attributed.
- **Constant motion:** yes. In sports it's 100 % airborne.
- **"One more round?"** Yes for Dropshot and Rocketball. For Brawl, it's "that was quick, who won?"

The game CD1 said was missing a payoff now has one. What's left is mostly *pacing and teaching*.

1. **Brawl pacing: give the fights room to breathe (WK-20a → WK-20c/b, WK-37).** Flight and KO readability are fixed, but a stage is a 6-12 s blowout, a third of the match is between stages, a weaker player is dead half the time, and the CPU wins the couch night again. Measure the +25 % knockback and the lives/score rules against stage length and the CPU's share, using human-style drivers. Then give the dead something to do (ghost goats).
2. **Teach the game it now is (CD2-01, CD2-02, WK-54, WK-78).** The super is the attack, but the tutorial lets you skip it, and co-op partners block each other in it. Rebuild Flight School lessons 2-3 around the super as a *hit*. Park HOME players. Then consider a short BRAWL SCHOOL (smash-to-ring-out), because nothing teaches the actual Brawl win condition.
3. **Make sports the showcase (CD2-03, WK-108, WK-109, WK-111, WK-110).** It is already the most fun mode. Fix the kickoff freebies for *humans*. Add bot routing, a real power shot, a winning-team celebration with stats, and match-point / golden-goal tension. These turn "fun" into the mode people ask for by name.
4. **One finished look (WK-34/35, WK-85, WK-66/66a, WK-122).** Navy dev panels are still the scoreboard, final score, Options, Trials objective and sports end card. Mint-void lower thirds sit on Trials lesson 1 and Islands Void. Sports courts are a dark stadium in a flat letterbox, and SUNSET BEACH has no beach. With the front end at Mario-Kart quality, these now stand out more.
5. **Couch readability of state (WK-31, WK-25, WK-26, WK-47).** The HUD card still shows only fuel, with no stocks or danger level. The score change is invisible until the scoreboard. A super wind-up has no audio or "!" on the target. Goats are small at brawl zoom. Every one of these is about letting a friend across the couch read what's about to happen.

**Overall verdict: FIX, and much closer than CD1.**
- **Flight (WK-95): SHIP.** The owner's ruling is delivered, for humans and bots.
- **Front end and couch input:** still SHIP.
- **Sports:** one kickoff-fairness fix and an end-screen celebration from SHIP.
- **Brawl:** FIX on pacing and score economy (WK-20a is now the critical path).

**Producer re-rank suggestion:**
- **CD2-01** next to WK-95f (S, JSON, owner-ruling follow-through).
- **CD2-03** folded into WK-108's slot. Measure with human drivers before calling it bot pathing.
- Pull **WK-20a** before any more Brawl content.
- **WK-25** after the WK-20a ruling, as planned.
