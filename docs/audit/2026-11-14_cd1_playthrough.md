# WK-CD1: Creative Director cold playthrough after the weekend's first 15 fixes (2026-11-14)

**Build:** `weekend/polish` @ 26a9da0 (WK-01..12, 22, 80, 81 landed). Rendered at **1920x1080** (design res), project path verified via eval.
**Method:** I played it like a first-time couch group of three: **pad 1, the keyboard, and pad 0**, all simulated, each joined on its own device. The route was title → mode → Herd Lobby → RULES flip → arena → a **full default Brawl match to victory** (11 stages) → REMATCH → pause flows → CHANGE SETUP (one player leaves, a CPU is added, LIVES 3) → a 3-lives Brawl stage → QUIT → Rocketball → Dropshot → Trials (Flight School). In-match "humans" were a human-style driver: it chases the nearest rival, holds boost to climb or cross, aims and releases super when close, and tries to recover toward the stage. Each device drove only its own goat. I looked at every screenshot.
**Evidence:** `tools/out/cd1/` (numbered stills; `m1..m4/` match frame dumps + `log.json`; `sheet_*.png` contact sheets; `rb/ ds/` sports frames).
**Limits:**
- The driver is not a real human. Read its outcome numbers as a hypothesis, not a verdict on balance.
- I did not judge audio by ear.
- My 1.2 s full-res captures in `m2/` stalled the game, so those wall-clock durations are inflated. Every duration quoted below comes from `round_stats` (game time) or from the low-overhead runs.

---

## 1. Verdict on the owner's specific complaints

| Owner complaint | Verdict | Evidence |
|---|---|---|
| **"B opens the pause menu on an xbox controller"** | **FIXED** | Pad 0 B mid-COMBAT → `paused=false`. Pad 1 Start → **PAUSED · P1** with the goat's head and colour (`22_pause_p1.png`). While P1 owns the pause, P3's pad A and the keyboard's Esc are both ignored (`23_pause_p3_input.png`, eval `paused=true`). The legend reads (B) POWERUP and (≡) PAUSE. The RESTART/QUIT/CHANGE SETUP confirm is now a hold with a visible ring and a "Hold to confirm" hint (`24_restart_tap.png`): a tap does nothing, a 1.3 s hold works. The morning's "QUIT never confirms" (R-09) is gone. |
| **"2 users using 2 controllers totally can't select their character like a normal game"** | **FIXED. This is now the best screen in the game.** | Pad 1 confirming BRAWL auto-joins it as P1. Keyboard Enter → P2, pad 0 A → P3, each panel labelled with its device (`05_three_joined.png`). All three cycle at once, and no device moves another's panel (`06_cycled.png`). P3 tries to lock P1's BUTCH and gets **"TAKEN BY P1"** (`07_lock_conflict.png`). The CPU tray drops from 3 → 1 as humans join and re-skins itself when a human takes its goat. A **READY TO FIGHT!** banner appears (`08_all_ready.png`). P3 opens RULES as a panel flip with an "EDITING · P3" chip (`09_rules_open.png`). An unjoined pad 2 cannot drive ArenaSelect (`11_pad2_unjoined_A.png`). In the match, `human_devices = [pad:1, kb, pad:0]`, and across 11 stages each device drove only its own goat. REMATCH keeps devices and goats. Pause → CHANGE SETUP returns to the lobby with picks kept (`26_change_setup_lobby.png`). |
| **"nonsense controls"** (general) | **Mostly fixed.** The leftovers are already filed. | Start pauses, B is the powerup, A flies, X supers, and View opens RULES. What is still off is all in the backlog: the keyboard player sees only pad glyphs in the match legend (WK-29/30), Trials says "HOLD A / SPACE" (WK-29), and Trials circuit select says "(A) FIGHT!" (WK-43, see §2 re-judge). |
| **"a shitty prototype with a lot of weird things"** | **Partly fixed.** | The front end now reads like a real party game: title, mode cards, lobby, pause and victory. The weird things left are mostly *inside* the match: invisible KOs, a score that goes down, overlays between stages, and a powerup-placement bug that sends bubbles into the wrong places in every mode (CD1-01). |

**Bottom line:** both of the owner's specific complaints are fixed, with rendered evidence on multiple devices. A first-time couch group now gets through the front door in about 30 seconds with no confusion. The remaining problems are in the match itself.

---

## 2. NEW findings (not already in `docs/BACKLOG.md`)

### CD1-01 [P1][S] Every powerup bubble in every mode spawns at Islands Void's coordinates. Every other arena's spawner layout is ignored.
- **Where:** all modes, all arenas/courts/courses, every match since July (git: `PartyMatch.gd` lines date from a8de63c / 9fafa66, 2026-07-02/05). **Not a weekend regression.**
- **What a player experiences:**
  - Powerup bubbles appear where the arena clearly wasn't designed for them. In **Rocketball** a jetpack bubble parks *outside the right wall* in the letterbox, where it can't be reached and is visible at the screen edge (`rb_edge_crop.png`, `36_crop_edge.png`).
  - In **Dropshot** a bubble floats in the left half-court (`sheet_ds.png`, frames f000/f001).
  - On the **very first Trials lesson** ("hold A, fly to the ring") a `ball_storm` bubble sits on a bush, and P2 grabbed it (`47_trials_flying.png`, `48_trials_after.png`).
  - In Brawl, the 94 arenas' hand-placed spawners never fire. Every arena gets the same three points, one of which (x=5100) is beyond most arenas' blast lines.
- **Evidence (eval, live Rocketball match):** `_pu_director.points = [(480,900), (2810,600), (5100,780)]` (exactly `levels/islands_void.json`'s three `powerup_spawner`s) while `_pu_points = []` (`sports_court.json` has none). Live bubbles were at (480,908) and (5100,777). The same three points showed up in Dropshot ((2810,607), outside its 0..2800 court) and in Trials ((480,902)).
- **Root cause:** `PartyMatch._ready()` calls `_load_stage(LEVEL_POOL[0])` (= `islands_void.json`) as a placeholder. `_pu_director.setup(self, _pu_points)` then captures *that array*. Every later `_load_stage()` does `_pu_points = data.get("powerup_spawners", [])`, which rebinds the member to a **new** array, so the director never sees it.
- **Suggested direction:** have `_load_stage()` push the points into the director (`_pu_director.points = _pu_points`, or re-`setup`), or have the director read `arena._pu_points` in `reset()`. Then **QA every mode**:
  - Sports courts and Trials courses have no spawners, so they should get **no** powerups (confirm that's the intended design with game-designer).
  - Brawl arenas should spawn at *their own* points. Those 94 placements have **never been exercised live**, so run them through the WK-57 scorecard.
- **Size:** S (fix). The arena re-check rides on WK-57.

### CD1-02 [P1][M] Default Brawl makes the CPU the favourite on a couch night. Self-KO −1 wipes out newcomers' KOs, and bots never self-KO.
- **Where:** Brawl, default rules (FIRST TO 10 KOs · 1 LIFE · CPU SKILL MIX → one "CPU L2").
- **What a player experiences:** three friends lose to one CPU, **10-4-2-1**. P1 KO'd five rivals and finished with **2** points, and P3 KO'd seven and finished with **4**. Every fall off the stage costs a point, the floor is 0, and nothing on screen shows the subtraction (WK-25 adds the "−1 OOPS" visual, but not the rule question). Two of the three humans sat at 0 for the first ~8 stages. A newcomer who is still learning recovery is pinned at zero while the bot climbs.
- **Evidence:** `round_stats` across the 11-stage match (192 s of combat, game time):
  - Humans died 27 times, **9 of them self-falls (33%)**. The CPU died 6 times with **0 self-falls**.
  - Credited KOs vs final score: P1 5→2, P2 2→1, P3 7→4, CPU 10→10.
  - Stage 2 "Islands Void": all three humans fell in the first 3 s with no attacker. A crude driver, yes, but also exactly the morning audit's first-time-human pattern (R-07).
  - Frames: `m1/`, `sheet_m1_c.png` ("VEX +4" in one stage), `20_victory_4.png`.
- **Suggested direction:** a game-designer ruling. This is a studio spec rule (spec §2 "suicide = −1"), **not** an owner ruling: the owner's 2026-07-03 directive sets KILLS/LIVES/no-timer and is silent on the penalty. Options:
  - (a) Self-KO costs nothing by default, with "SELF-KO −1" as a RULES toggle.
  - (b) No penalty until a player has scored once.
  - (c) When 2 or more humans are in, CPU SKILL MIX resolves to L1-L2 only.
  - Measure in the WK-20a batch with **human-style drivers, not only bots** (bots don't self-fall, so a bot batch will say this is fine).
- **Size:** M (ruling + small change + measurement).

### CD1-03 [P2][S] The Trials objective panel covers the goal ring
- **Where:** Trials, Flight School lesson 1 ("FIRST FLIGHT").
- **What a player experiences:** the course's whole instruction is "fly up to the ring", and the dark "1 of 2 HOME" panel is drawn over the top-centre of the screen, where the ring ends up once the camera re-frames. You can see only a green arc of the target peeking over the panel (`48_trials_after.png`).
- **Suggested direction:** put the objective panel in a corner, or collapse it to a small chip after ~3 s. Or reserve a top band in the framing that the owner-19 `camera_focus_points` seam avoids. WK-35 restyles this panel, so fold placement into its Accept line.
- **Size:** S.

### CD1-04 [P3][S] One fighter, three names: "CPU" on the card, "VEX" in banners, "VEX — CPU" on victory
- **Where:** Brawl HUD, stage-end banners, victory.
- **What a player experiences:**
  - The bot's HUD card and pip say **CPU**, but the stage banners say **"VEX SURVIVES!"** and **"P1 +1 · P2 +1 · VEX +1"**.
  - The victory screen says **"VEX — CPU"** in purple over a yellow burst, which is hard to read.
  - Humans are "P1" in banners but "BUTCH P1" on victory.
  - A first-timer reads "VEX" and asks "who is Vex?" (`m1/f005_STAGE_END.png`, `m1/f029_STAGE_END.png`, `20_victory_4.png`).
- **Suggested direction:** pick one naming rule for all in-match text. For example, humans are "P#" everywhere, and CPUs are "CPU" plus their goat colour, or "VEX (CPU)" everywhere. WK-42 covers only the victory-screen legibility.
- **Size:** S.

### CD1-05 [P3][S] Lobby small text: same-colour outlines fill in the letter counters
- **Where:** Herd Lobby flavour lines, the "NONE"/flair row, and the rules summary bar.
- **What a player experiences:** dark brown text with a dark brown outline (`outline_size` 4-12 in `LobbySlot.tscn`) closes up the holes in letters like "e", "a" and "g". Lines like "Come at me. I've been stretching." and "FIRST TO 10 KOs · 1 LIFE" look muddy, like a photocopy, at couch distance (`05_crop_lobbytext.png`). The lobby is also now a *second* type style next to the system-font menus.
- **Suggested direction:** drop the outline on dark-on-light body text, or use a light outline. Fold this into WK-17 (font) / WK-18 (28 px floor) so the bundled font lands without fake-bold outlines.
- **Size:** S.

### CD1-06 [P3][S] `round_stats` seems to under-record kills when LIVES > 1 (instrumentation; verify)
- **Where:** Brawl, 3 lives.
- **What I saw:** the 3-lives stage on Grassy Expanse ran 63.5 s (game time) and ended with scores **2-0-5-1**, but `round_stats[0].kills` held **one** entry (P1's self-fall at t=1). I saw this once and didn't root-cause it.
- **Why it matters:** WK-20a, WK-55 and WK-57 all make decisions from `round_stats`. If multi-life kills go missing, those measurements are wrong for any non-default LIVES setting.
- **Suggested direction:** qa-playtester reproduces it (one 3-lives stage, count `kills` vs `scores` deltas). If confirmed, gameplay-programmer fixes it.
- **Size:** S.

### Existing backlog items: re-judged as a player (worse or better than described)
- **WK-82 is worse than described:** a device that has **already left** the lobby can still hold B and eject everyone. Pad 0 backed out (B), then held B for 1.5 s. Pad 1, still PICKING, was thrown back to mode select (`39_lobby_after_B.png` → `40_after_holdB.png`, lobby state `[EMPTY, pad:1 PICKING, EMPTY, EMPTY]`). Add to WK-82's Accept: hold-B exit counts **only from a joined device**, or only when no other slot is joined.
- **WK-21 / WK-41 (dead time) are worse than described.** Measured cadence:
  - STAGE_END → next COMBAT takes **~9-13 s** every stage (STAGE_END banner → SCOREBOARD → STAGE_INTRO → COUNTDOWN), against a **median stage of 15 s of combat** (11 stages: 35, 3, 12, 15, 21, 11, 17, 15, 24, 31, 7 s).
  - So roughly **35-40% of a default match is interstitial**, *before* counting the time eliminated players spend watching.
  - Recommend that WK-21's Accept line becomes a **total between-stage budget** (e.g. ≤ 6 s normal, ≤ 8 s on lead change), not just the ScoreScreen hold. SCORE_HOLD is the owner-sanctioned knob; the STAGE_INTRO card + COUNTDOWN on every stage is the other half.
- **WK-37 (ghost goats) matters more with LIVES 3.** When the group raises LIVES to 3 to "play longer", P3 is eliminated ~30 s in and then watches a 1v1 for over a minute (`sheet_m4.png`). Raising LIVES makes waiting *longer*. Also no stock count is shown (WK-31).
- **WK-85 is broader than "tall arenas":** the **first Trials course** shows the same thing. The bottom ~35% of the screen is a flat mint-green fill under the painted hills, and goats fly through what looks like an unpainted void (`46_trials_go.png`, `48_trials_after.png`). First impression of Trials.
- **WK-43 also needs the front-end copy:** Trials circuit select's footer says **"(A) FIGHT!"** (`44_trials_select.png`) in the co-op mode.
- **R-07 is unchanged (owner-ruled; WK-20a/37 mitigate):** idle players still die within seconds of BOUNCE. In the REMATCH, keyboard P2 sat still while reading the legend and was dead in ~4 s (`22_pause_p1.png` shows the skull).
- **Better than described:** WK-12 backdrops make the first Brawl impression good, with a painted meadow sky on Grassy Expanse (`12_launch_3.png`). WK-80(a) focus restore works for both pause → OPTIONS → back and lobby → mode select.

---

## 3. Fantasy check: the 5 biggest things between this and a proper fun game NOW

The morning's #1 (couch-controller fundamentals) is **done**. The front end now delivers "grab a pad, press A, pick your goat, go." What's left is in the match, where the fantasy lives.

Core-verb read from 11 driven stages:
- **FLY:** players are airborne and on the jetpack most of the time, and gaps need boost. **Yes.**
- **BOUNCE:** constant. **Yes.**
- **RECOVER:** happens, but off-screen and unwatchable. **Partly.**
- **SUPER-SMASH as the kill:** mechanically yes. As *felt*, no: at 0.46-0.62 zoom a KO is a speck leaving the frame, and the score just changes on the next screen.
- **One more round?** The lobby makes you *want* to start. The match makes you ask "wait, who got that?"

1. **Make the KO the climax (WK-23/24/25/51).** Still the #1 gap. Across 11 stages I could rarely tell who killed whom from the screen. Points appear and disappear between overlays. Without a visible KO there's no "flying head-first into my friend" moment.
2. **Fix the score economy for newcomers (CD1-02) and stop spawning powerups in the wrong places (CD1-01).** "I KO'd five people and I have 2 points, and the robot won" is exactly the "weird prototype" feeling the owner described. CD1-01 is an S-size bug that has silently overridden every arena's design since July.
3. **Cut the dead time (WK-21/41 budget, WK-37 ghosts).** About a third of a match is overlays between ~15 s fights, plus eliminated players watching. Duck Game's appeal is that the next round is *right now*.
4. **Readability at couch distance (WK-31 danger/stocks, WK-36 off-screen bubbles, WK-47 rims).** Goats are small (owner camera rules stand), the HUD card shows only fuel, and the recovery gamble mostly happens off-screen as a chevron.
5. **One finished look + teach the goal (WK-15, WK-17 + CD1-05, WK-34/35, WK-66).** There are still two type styles and dark-navy dev panels for the scoreboard, final score, Trials objective and Options. Sports courts are a dark stadium in a flat blue letterbox, and Dropshot's "SUNSET BEACH" is that same stadium. Rocketball and Trials start with no controls legend.

**Overall verdict: FIX.** The front-end/couch-input slice can **SHIP**. Brawl in motion is still a FIX: the verbs are present, but the payoff (seeing your KO, keeping your points, getting back in fast) isn't.

**Producer re-rank suggestion:**
- **CD1-01 goes to the top** (S, a bug, affects every mode).
- Fold CD1-02's measurement into **WK-20a** before item 1. WK-20a's knockback question and the self-KO rule are the same "who wins and why" study, and it needs human-style drivers.
- Then continue the KO readability run (WK-24/23/25) as planned.

---

## 4. Regression list (worked in the morning audit, broken now)

**None found.** Re-verified working on the integrated build:
- Title → mode → lobby → arena → match → victory → REMATCH → CHANGE SETUP → match, and QUIT → title.
- The full default Brawl match ran to MATCH_END with no script errors (the log has only art-stub warnings: grass tufts/white flowers skipped on 22 arena loads, and the `bumper_post` stand-in 5×).
- Victory REMATCH: an unjoined pad 2's A was ignored (WK-11 gate), and P3's A started the rematch.
- Pause (Start/Esc owner-gated) → Options → back (focus returns to OPTIONS).
- Rocketball, Dropshot and Trials all launch from the new lobby on two pads. Trials per-player fuel cards work, and the course is completable (1 of 2 HOME reached).

Not regressions but carried over unchanged:
- Mode select still defaults to TRIALS (WK-13).
- QUIT TO MENU still lands on the title and clears the lobby (R-26; the label says MENU).
