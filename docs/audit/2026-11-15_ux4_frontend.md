# UX4: integrated front-end pass as a couch group (2026-11-15)

**Reviewer:** ui-ux-designer (approval authority on menu screens) · **Bar:** `docs/COUCH_CONVENTIONS.md` (CC-x.y) + the
Mario Kart / Duck Game / TowerFall front-end bar.

**Build:** `weekend/polish` working tree at **097c192** (WK-29 done), plus another lane's uncommitted ghost edits
(GhostBot / GhostGoat / GhostDirector / PartyMatch / Tuning). The commits that landed during the pass (1f5b64d, 472dd8c,
f5709c7) do not touch the front end.

**Rig:** port 9109, rendered at **1920x1080** for the whole route, then **1280x720** spot checks. The viewport is a fixed
1920x1080 canvas scaled uniformly, so 720p is the same layout scaled down; no reflow bugs. GPU is in software rendering,
so this pass makes no fps or timing claims.

**Couch group:** **keyboard** (P1 in Brawl, P2/P3 later) + **simulated pad device 1** + **simulated pad device 2**,
plus pad device 3 as an *unjoined* intruder. I used `eval` only to shorten matches (target KOs / goal cap / course index)
and to trigger the WK-52 unlock card and the lobby disconnect hook.

**Route:**
1. title → options → mode select → Brawl lobby (join, pick, taken goat, random, RULES, un-ready, ready).
2. → arena select (back to lobby and forward again) → match (intro, legend, HUD, pause ×3 owners, hold-RESTART) →
   scoreboard → Brawl Victory → REMATCH → pause QUIT TO MENU.
3. → Rocketball lobby (auto 2V2) → court select → match → Sports Victory → CHANGE SETUP → hold-B exit.
4. → Trials lobby → circuit select → Flight School → Trials end → QUIT.
5. → unlock card → lobby disconnect.

**Screenshots:** `tools/out/ux/UX4_*.png` (95 files, including two burst contact sheets). I looked at every one I cite.

**Harness caveats (not game bugs):**
- (a) Each `gbplay` call costs about 0.45 s. A press and release sent as two separate calls is held long enough to trigger
  the 0.40 s held-direction repeat, so I sent every press/release pair inside one `script` connection.
- (b) A 1080p screenshot freezes the game for about 1.25 s while hold timers keep counting real time. A screenshot taken
  mid-hold therefore completed a hold-RESTART (`UX4_52`/`53`). I re-tested without a screenshot, and early release
  cancels correctly.

---

## Press counts

| Flow | Presses | Notes |
|---|---|---|
| Boot → first bounce (solo, pad) | **5** | A PLAY · A BRAWL (auto-joins P1, CC-4.8) · A lock · Start · A arena |
| Each extra friend | +2 | A join · A lock (in parallel, CC-4.1) |
| Match end → REMATCH | **1** | default focus (CC-10.1) |
| Match end → CHANGE SETUP | **2** | → · A; seats and goats kept, players back to PICKING (CC-4.7) |
| Match end → quit | **2** | B focuses QUIT · A. **Lands on the title**, not a menu (UX4-13) |
| Pause → quit | Start · ↑ (wrap) · hold A 0.9 s | CC-6.1 |

---

## Per-screen verdicts

| Screen | Verdict | CC rules exercised | Findings |
|---|---|---|---|
| Title | **Ship** | 1.4, 5.1, 5.2, 5.6, 6.1, 8.4 | UX4-14 (quit dialog) |
| Options | **Fix** | 5.1, 5.2, 5.4, 5.6, 1.3, 11.1, 3.6 | UX4-01, UX4-16 |
| Mode select | **Ship** | 1.6, 5.1, 5.2, 5.6, 4.8 | UX4-04 (safe area) |
| Herd Lobby (Brawl / Sports / Trials) | **Fix** | 4.1-4.8, 1.6, 1.7, 3.5, 6.2, 9.1 | UX4-02, UX4-03, UX4-04, UX4-05, UX4-15, UX4-17, UX4-18, UX4-19 |
| RULES panel | **Ship** | 4.6, 1.3, 1.5-style ownership | UX4-20 |
| Arena / court / circuit select | **Fix** | 3.3, 5.2, 1.7 | UX4-12, UX4-25 |
| Brawl intro + HUD + legend | **Ship** | 8.3, 8.5, 11.1, 11.2, 1.6 | UX4-11, UX4-23 |
| Sports HUD + legend | **Fix** | 8.3, 11.1, 11.2 | UX4-09, UX4-10 |
| Trials HUD | **Ship** | 11.2, 1.6 | UX4-24 |
| Scoreboard (between stages) | **Ship** | 8.5 | none |
| Pause | **Fix** | 1.5, 7.1-7.4, 6.1, 5.2, 2.4/12.2 | UX4-01 |
| Brawl Victory | **Ship** | 10.1, 10.3, 3.3, 8.5 | UX4-06 |
| Sports Victory | **Ship** | 10.1, 4.7, 8.5 | UX4-06, UX4-21 |
| Trials end | **Fix** | 10.1, 5.6 | UX4-06, UX4-07, UX4-08 |
| Unlock banner (WK-52) | **Ship** | 8.2 | UX4-26 |

**What I verified as passing** (each one rendered):

- **Title:** PLAY is the default focus. D-pad and keyboard both move focus, and the list wraps. B never quits; it only
  moves focus. The quit dialog opens on **STAY** (CC-6.1). Coming back from Options restores focus to OPTIONS (CC-5.6).
- **Mode select:** lands on **BRAWL** (WK-13). The four cards are the same height and carry player-count chips. Stick
  and D-pad both navigate, and the row wraps. Before anyone joins, the glyphs follow the last device used: ENTER/ESC key
  caps or A/B pad glyphs (`UX4_12` vs `UX4_14`).
- **Lobby:**
  - Joining and seats:
    - The confirming device is auto-seated as P1 (CC-4.8).
    - Pads join with A or Start (CC-4.1).
    - Each new player starts on a distinct default goat.
  - Taken goats and locking:
    - A taken goat shows **TAKEN BY P2** on the browsing panel and a P2 badge plus tick on the roster medallion (CC-4.2,
      `UX4_21`).
    - Locking a taken goat is refused.
  - Random: R/Y spins and lands on a free goat.
  - B ladder: READY →B→ PICKING →B→ EMPTY.
  - READY TO FIGHT!:
    - The banner shows **≡ / ENTER** because pads and keyboard are mixed (CC-1.6 amendment).
    - Start or keyboard Enter proceeds (`UX4_29`).
  - The lobby survives:
    - going back from arena select (`UX4_36`);
    - CHANGE SETUP (`UX4_74`);
    - switching modes (Brawl → Rocketball → Trials kept P2/P3).
  - QUIT TO TITLE clears it (`UX4_61`).
  - Sports: picking a goat picks the team, and 3 humans automatically get **2V2** (WK-120, `UX4_62`).
- **RULES panel** (`UX4_24`-`27`):
  - Opening it turns the opener's panel into the rules editor, with an EDITING · P3 chip in the rules strip.
  - Another player's View press gets **P3 HAS THE RULES**.
  - B **UNDO** reverts an edit (KOs went 7 → 10).
- **Arena select:**
  - Pad 3, which never joined, cannot move focus (CC-3.3).
  - Locked circuits carry a LOCKED ribbon, and pressing one is refused (`UX4_33`/`34`).
- **Brawl HUD:**
  - Humans have P# pips; the CPU tag is **PUFF / CPU** (CC-8.5).
  - The stage-1 intro card shows **STAGE 1 · GRASSY EXPANSE · SMASH 'EM OFF-SCREEN · FIRST TO 5 KOs** (CC-11.2,
    `UX4_53`).
  - The legend shows device-aware mixed glyphs.
- **Pause** (`UX4_50`-`57`):
  - Header and ownership:
    - The header reads **PAUSED · P3**, with P3's goat head in P3's colour.
    - It has a context line (mode · arena · target) and score chips.
    - P2's D-pad is ignored (CC-1.5).
  - RESTART:
    - It needs a hold with a radial ring.
    - Releasing early cancels.
  - B or Start resumes.
  - Keyboard pause:
    - Esc pauses with P1 as the owner.
    - The focused button fills with the owner's colour (purple).
    - ↑ wraps to QUIT TO MENU.
  - `Input.mouse_mode` is 1 (hidden) while paused (CC-2.4/12.2).
- **Brawl Victory:**
  - The HUD is hidden (WK-42).
  - REMATCH is the default focus.
  - B moves focus to QUIT (CC-10.1).
  - The unjoined pad is ignored (`UX4_46`).
  - REMATCH kept the 5-KO rule.
- **Sports Victory:** RED WINS!, both winners' portraits, MVP, a stats table, LONGEST RALLY and WINNING GOAL · P3 ·
  ASSIST P1 (CC-8.5 names throughout).
- **Unlock card:** a cream card in the header band that never covers a slot name (`UX4_88`).

**Not assessed (none of these counts as a pass):**
- **Audio by ear.** CC-9.1 is judged from code only (UX4-15).
- **CC-10.2 arming under mashing.** Every end-screen press I made came more than 1 s in.
- **In-match controller disconnect.** WK-28 is not built.
- **Held-direction repeat on title, mode and arena select** (WK-46). The lobby does repeat.
- **Dropshot screens.** They share the sports kit; time.
- **KB-R second-keyboard scheme.**
- **Mouse.**

---

## Findings

Severity is P0-P3, size is S/M/L. Each finding gives its CC rule, its evidence and a fix direction. *Re-confirm* means a
BACKLOG item already covers it.

### P1

**UX4-01 [P1][M] Neither Pause nor Options has a CONTROLS entry.** CC-7.1, CC-11.1.
- **Re-confirms WK-33** (screen) and **WK-44** (Options entry + RUMBLE toggle, CC-3.6).
- **Evidence:**
  - `UX4_51` pause shows RESUME · RESTART · OPTIONS · CHANGE SETUP · QUIT TO MENU.
  - `UX4_06` Options shows 3 volume sliders + FULLSCREEN, and no CONTROLS or RUMBLE.
- **Why P1 at the couch:** the legend only shows on stage 1. A friend who arrives for the second match, or who forgot
  "hold X to aim", has no way to look it up.
- **Fix:** ship WK-33 as specified (one shared scene, device glyphs, "hold X to aim, release to fire"). Add the entry
  between RESTART and OPTIONS in Pause, and at the top of Options.

**UX4-02 [P1][M] A lost pad in the lobby wipes its seat instantly.** CC-3.5.
- **Re-confirms WK-28.**
- **Evidence:** `InputRouter.simulate_device_lost("pad:2")` turned P2's BUTCH panel straight into **PRESS A TO JOIN**
  (`UX4_90`). There is no DISCONNECTED state, no kept goat or colour, and no 10 s takeover window.
- A cable wiggle costs a pick. I could not assess the in-match side (the auto-pause overlay); it is not built.
- **Fix:** WK-28 as specified.

### P2

**UX4-03 [P2][S] "B HOLD: EXIT" does not work for a seated player.** CC-4.3, CC-1.7.
- **Evidence:**
  - P1 (pad 1, PICKING) held B for 1.2 s. The *press* emptied P1's slot at once, no fill ring appeared, and the lobby
    stayed up (`UX4_75`).
  - The ring and the exit only happen for a device that is already unseated when it presses (`UX4_76`).
  - Code: `HerdLobby._on_back_press` only starts `_hold_b` when `si < 0`.
- **Why it matters:** the footer promises "HOLD: EXIT" to everyone. A seated player who tries it loses their pick and
  stays on the screen, which is the lying-prompt pattern.
- **Fix:** start the hold timer on every B press. Apply the tap action (un-ready / leave) on **release** when the hold
  ended before `lobby_hold_ring_show`. This matches CC-4.3's "from any state" and Smash. Keep CC-6.2 intact: a tap
  never exits a populated lobby.

**UX4-04 [P2][S] Header chips and footers sit in the outer 5 % on every select screen.** CC checklist "Resolution & safe
area".
- **Extends WK-83**, which covers the lobby only, to the shared `MenuScreen` header and footer.
- **Evidence (1080p):**
  - BACK chips span y 22-95 (mode select, lobby, arena select).
  - Footers span y 1012-1048 (`UX4_12`, `UX4_17`, `UX4_31`, `UX4_64`).
  - The safe band is y 54-1026.
- **Fix:** move the header chip top to ≥ 54 and the footer bottom to ≤ 1026 in the shared MenuScreen layout, so every
  screen inherits it.

**UX4-05 [P2][S] The lobby footer is a 6-chip wall that contradicts itself.** CC-1.7, CC-8.1.
- **Evidence:**
  - `UX4_17`, keyboard only: **ENTER** JOIN/READY · **ESC** BACK OUT · R RANDOM · ◀▶ GOAT/FLAIR · **ENTER** GO! ·
    **ESC** HOLD: EXIT.
  - The same key is shown with two meanings on one line.
  - Three B/Esc prompts are on screen at once (top BACK chip + BACK OUT + HOLD: EXIT).
  - GO! is advertised while nobody is ready.
- **Fix:**
  - The footer carries only always-true verbs: JOIN/READY, BACK OUT, RANDOM, GOAT/FLAIR, plus HOLD-B with its ring.
  - GO! lives only on the READY TO FIGHT! banner, which already prints it.
  - On the lobby, the top-left chip becomes the hold-B exit (it already shows the ring in `UX4_76`) and the footer
    HOLD: EXIT chip goes.

**UX4-06 [P2][S] The three end screens use two button styles.** WK-14 single focus style, CC-5.1.
- **Evidence:**
  - Brawl and Sports Victory: the unfocused CHANGE SETUP / QUIT TO MENU render **grey and translucent**. They read as
    *disabled* across a room (`UX4_45`, `UX4_73`).
  - Trials end: the same buttons are cream (`UX4_84`).
  - None of the three has a glyph prompt row, so the B → QUIT shortcut (CC-10.1) is undiscoverable.
- **Fix:**
  - Draw the victory buttons above the dim layer, or give them an opaque ToyKit cream fill, so all three end screens
    share the title/pause button kit.
  - Add a footer: **A** select · **B** quit, with PAD glyphs when a pad is joined (CC-1.6 shared prompt).

**UX4-07 [P2][S] The Trials end screen still shows the combat HUD.**
- **Evidence:** `UX4_84`. The P1/P2/P3 cards and the objective panel ("3 of 3 HOME · HOLD A / SPACE — FLY UP TO THE
  RING") sit behind TRIALS COMPLETE!.
- WK-42 hid them on the Brawl Victory only.
- **Fix:** hide the HUD and the TrialsHUD on Trials MATCH_END the same way.

**UX4-08 [P2][M] The Trials end is a flat dialog, and its default focus is the wrong next action.** CC-5.6, bar.
- **Evidence:** `UX4_84`.
  - One cream card: TRIALS COMPLETE! / "All courses cleared." / PLAY AGAIN · CHANGE SETUP · QUIT TO MENU.
  - No goats, no circuit name, no crest, and no "NEXT CIRCUIT UNLOCKED" moment.
  - PLAY AGAIN (default) replays the same 9 courses. After clearing a circuit, the obvious next press is the next circuit.
- **Fix:**
  - Default focus becomes **NEXT CIRCUIT: NEEDLE & KEY** (when one exists), then PLAY AGAIN, CHANGE SETUP, QUIT.
  - Add the Herd cheering, the cleared circuit's name and crest, and the unlock reveal if this clear unlocked something.
    Keep it binary: no times or medals, per v10 §5.
- **Art ask:** a "herd celebrates" panel illustration, transparent PNG.

**UX4-09 [P2][S] Sports: team membership is not readable on the field.** CC-8.3 (identity at a glance).
- **Extends WK-119.**
- **Evidence:**
  - Every player tag uses the *goat's* colour (P1 pink, P3 orange, P2 blue), and nothing marks the team.
  - The green CPU ZIGGY is on BLUE, and its **CPU tag disappears after kickoff** (`UX4_65` frame 2 has it; frame 5 and
    `UX4_69` do not).
  - At the couch, "which side is green on?" depends on remembering the lobby.
- **Fix:**
  - In sports, outline every tag in the team colour and give every goat a thin team-coloured rim (WK-47 rim, team
    variant).
  - Keep a small team-coloured **ZIGGY · CPU** pip on bots during play (WK-119).

**UX4-10 [P2][S] The sports legend covers the top third of the court during live play.** CC-11.1 (teach without
blocking).
- **Fix to WK-113.**
- **Evidence:** `UX4_65` frame 5.
  - The goal chip plus two legend rows span y 135-340 of 1080, inside the court, while the ball flies through that band.
  - The SUPER line is 54 characters: "SUPER-SMASH THE BALL (POWER SHOT) OR A RIVAL (CLEAR THEM)".
  - The ZIGGY CPU tag collides with the legend row in frame 2.
- **Fix:**
  - Shorten the SUPER line to "**X SUPER-SMASH** ball or rival".
  - Fade the legend to about 40 % once the ball is first touched, and remove it at the first goal.
  - Or dock it in the dark stands *above* the court roof (y < 90), which is free space on every court.

**UX4-11 [P2][S] Match-load first frame: the Brawl legend spans the HUD cards.** Checklist "first frame after a
transition".
- **Evidence:** `UX4_39`, about 0.6 s after pressing A on the arena.
  - The legend renders as **one row** from x 165 to 1750, over the P3 card and hiding the PUFF CPU card.
  - It then reflows to the WK-29 two-row layout (`UX4_41`).
- **Fix:** compute the wrap before the legend's first visible frame (lay it out hidden, show it next frame), or start it
  at alpha 0 until its size settles.

**UX4-12 [P2][M] Arena / court / circuit select falls below the bar on composition and art.** CC-1.7 on the last point.
- **Re-confirms WK-60 and WK-65; adds a prompt bug.**
- **Evidence:**
  - Brawl: about 30 % of empty sky above the shelf and 30 % of empty grass below it, with the shelf labelled "WAYS TO
    PLAY" (`UX4_31`).
  - The RANDOM ROTATION card uses the old dark screenshot strip (`UX4_35`).
  - Court select still shows dark-stadium thumbnails, and each card's lower half is blank (`UX4_64`).
  - With a **LOCKED** card focused, the footer still says **A FIGHT!** (`UX4_33`).
- **Fix:**
  - **Layout:** add a large preview region for the focused card in the top half (Mario Kart cup select), filled with the
    circuit's painted key art, its name, and its arena count / difficulty spelled out in words ("EASY · 20 ARENAS", not
    bare stars). The shelf goes in the lower half.
  - **Locked cards:** the footer changes to "LOCKED · win THE HIGH WIRE".
  - **Art:** WK-65 painted court cards, plus a painted RANDOM ROTATION card.

**UX4-14 [P2][S] The title's quit dialog is the last navy panel, and PLAY ghosts through it.**
- **Evidence:** `UX4_05`.
  - A navy rounded panel ("QUIT GOTTABOUNCE?") in an otherwise all-cream product.
  - The PLAY button's outline shows through the panel's lower edge behind QUIT. This is the 0.97-alpha ToyPanel lesson.
- **Fix:**
  - Rebuild it as a cream ToyPanel filled opaque (`ToyKit.fill_panel(p, ToyKit.CREAM)`), with a red QUIT and a green
    STAY.
  - Add A/B glyph hints inside the card.

**UX4-15 [P2][S] The lobby still uses one pitch-shifted click for most answers.** CC-9.1.
- **Re-confirms WK-45; judged from code, not by ear.**
- **Evidence:** in `HerdLobby.gd`, un-ready (line ~704), hold ticks (~723) and the random land and unlock (~1466) are all
  `AudioManager.play_sfx("ui_click", {pitch …})`.
- **Fix:** WK-45's distinct back / deny / ready / all-ready / hold-tick set. Hand to the sound-designer.

**UX4-20 [P2][S] RULES panel: every value pill is solid green, which is the product's focus colour.** CC-5.1.
- **Evidence:** `UX4_24`/`25`. Six green pills, with focus shown only by a thin yellow row ring and arrows.
- Under WK-14's grammar ("only the focused thing is green"), six green pills read as six focused buttons.
- **Fix:** neutral cream value pills with chocolate text. The focused row gets the yellow ring plus a green pill with
  ◀ ▶.

### P3

**UX4-13 [P3][S] "QUIT TO MENU" goes to the title.** Pause (`UX4_59`), Victory and Trials end (`UX4_86`) all land on
the title. A returning group then pays PLAY + mode + re-join.
- **Fix:** land on **mode select** with the lobby cleared, as CC-4.7 requires for a quit. Or rename the button QUIT TO
  TITLE. Prefer the first.

**UX4-16 [P3][S] Options footer and focus.**
- The footer only offers "⊕ Adjust" on every row, including the FULLSCREEN toggle; it should say **A** Toggle there.
- The rows use a yellow-ring focus while buttons use a green fill. Acceptable as a widget-class distinction, but write it
  into the menu-system note so it is deliberate.
- Evidence: `UX4_06`, `UX4_08`.

**UX4-17 [P3][S] A taken-goat panel still advertises "ENTER LOCK IN".** While P1's panel says TAKEN BY P2, the prompt is
unchanged (`UX4_22`). Grey it out or swap it to "TAKEN".

**UX4-18 [P3][S] The FLAIR row reads as a rating.** "★ NONE" / "★ PEAK MENACE" carries no label (`UX4_19`).
- **Fix:** add a small "FLAIR" caption, or swap the star for the flair's own swatch.

**UX4-19 [P3][S] The "P3 HAS THE RULES" chip covers the presser's READY! stamp.** Seen in `UX4_26`. Anchor the chip
below the name bar instead.

**UX4-21 [P3][S] Sports Victory polish.** Evidence: `UX4_73`.
- The **OWN GOALS** header wraps to two lines, so the header row is uneven.
- P1's own goal "1" gets the same gold leader pill as GOALS, which reads as praise. Never highlight own goals.
- RED rows are tinted but BLUE rows are not.
- The live court behind is barely dimmed: a P1 goat and tag, a green goat and a blue goat show around the art.
- **Fix:** use the Brawl Victory's dim strength.

**UX4-23 [P3][S] Ghost / sudden-death HUD collisions.** Evidence: `UX4_56`.
- The "SHH" ghost badge sits over the P2 / PUFF names on the HUD cards.
- A ghost's edge-clamped P2 tag lands on top of the P3 HUD card.

**UX4-24 [P3][S] The Trials HUD gives the same instruction twice.** Evidence: `UX4_80`/`81`.
- The top panel says "HOLD A / SPACE — FLY UP TO THE RING" and the gold chip says "FLY INTO THE GOLD RING".
- The off-screen bubble for P3 overlaps P1's pip next to the P1 card.
- **Fix:** keep one goal surface: the top panel gets the hint, and the chip goes once the panel is up.

**UX4-25 [P3][S] Shelf headers are inconsistent.** "WAYS TO PLAY" (Brawl) vs "COURTS 8" vs "CIRCUITS 6". The Trials
circuit cards show no cleared state or crest (`UX4_79`). Part of WK-60.

**UX4-26 [P3][S] The unlock card's icon is a generic star in a disc** (`UX4_88`). Show the flair itself: the streak or
flame swatch, or a tiny goat wearing it.

**UX4-27 [P3][S] First frame of a sports match.** `UX4_65` frame 0 shows a zoomed camera with no court frame, before
the court snaps in. Hold a black or cream wipe until the court camera settles.

---

## Overall verdict vs the Mario Kart / Duck Game / TowerFall bar

**FIX, close to SHIP.** The parts a couch touches most are now at the TowerFall / Duck Game bar:
- **The lobby:** independent join, taken tokens, per-player RULES, READY TO FIGHT!, and a lobby that survives every
  round trip.
- **The pause:** the pauser owns it, holds guard the destructive options, and it uses the owner's colour.
- **The victory screens:** the winner art and the sports stat card are trailer-worthy.

The CD3 complaints in my lane are closed: WK-13 mode focus, WK-42 Victory HUD, WK-14 single focus style, WK-40 BACK chip,
WK-29 glyphs and the WK-52 toast.

What still reads as "programmer menu" or breaks a convention, in order:
1. **No CONTROLS screen** anywhere (UX4-01).
2. **Lobby disconnect** wipes picks (UX4-02).
3. **Arena / court select:** half-empty screens and old thumbnails (UX4-12). This is the weakest-looking screen in the
   flow.
4. **Trials end** is a dialog, not a celebration, and still shows the HUD (UX4-07/08).
5. **Hold-B exit** lies to seated players (UX4-03).
6. **Sports team identity** on the field (UX4-09).

**Suggested order for the producer:**
1. WK-33 + WK-44 (UX4-01).
2. WK-28 (UX4-02).
3. UX4-03 + UX4-05 together (lobby footer and hold-B, one S slice).
4. UX4-06 + UX4-07 (end-screen kit, one S slice).
5. WK-60 + WK-65 with the UX4-12 layout.
6. UX4-09 + UX4-10 (sports readability).
7. UX4-04 safe area (folds into WK-83).
8. UX4-08.
9. Then the P3s.
