# COUCH CONVENTIONS — the standard every screen and control must meet

**Owner:** UI/UX Designer · **Status:** BINDING (2026-11-14, weekend polish run) · **Audit against it:**
`docs/audit/2026-11-14_controls_frontend.md`

**Why this exists:** the owner played the build and said: *"nonsense controls (like b opens the pause menu on an
xbox controller, are you kidding me) and like the character select totally doesnt make sense, 2 users using 2
controllers totally cant select their character like a normal game."* Every rule below is something Smash Bros
Ultimate, Mario Kart 8, Duck Game, TowerFall, Overcooked, Brawlhalla and Rocket League all do the same way. When
all seven agree, a player expects it without thinking, and breaking it reads as broken, not as a style choice.

**How to use:** each rule has an ID (`CC-x.y`). A screen or control ships only when every rule that applies
passes. Reviewers cite IDs in Ship/Fix/Reject verdicts. Verify in the rendered game with BOTH keyboard and
simulated pads on at least two different device ids (`gbplay.py raw '{"command":"gamepad","device":1,...}'`).

**Supersedes:** rule 1 of `docs/briefs/ui_professionalism_audit_2026-07-19.md` ("zero keyboard references").
Keyboard is a first-class device (§2). Glyphs now follow the device (CC-1.6), so keyboard players see key caps
and pad players see pad buttons. Rules 2-5 of that brief still stand.

---

## 1. Button semantics (Xbox layout is canonical; joypad `button_index` in brackets)

### 1.1 Gameplay (a live match)
| Input | Meaning | Rule |
|---|---|---|
| Left stick / D-pad | move / aim | — |
| **A** [0] | Boost (fly), the primary verb | — |
| **X** [2] | Super (hold to aim, release to fire) | — |
| **B** [1] | Use powerup | **B NEVER pauses, opens a menu, or goes back during gameplay.** |
| **Start/Menu** [6] | **Pause** | the only pad button that pauses |
| View/Back [4] | secondary info (optional: hold for the score overlay) | never pauses, never quits |
| Y [3], LB [9], RB [10], triggers | unused or alternate bindings only | never menu actions mid-match |
| Guide [5] | reserved by the OS | never bind |

- **CC-1.1** In gameplay, `pause` is its own action: Start [6] + keyboard Esc (+ P optional). Gameplay code never
  reads `menu_back`, `menu_accept` or `ui_*`.
- **CC-1.2** No gameplay action shares a physical pad button with a menu action that can fire *during gameplay*.
  (A = boost and A = confirm is fine because menus and gameplay never run at the same time. B = powerup and
  B = "back → pause" in the same state is the bug the owner hit.)

### 1.2 Menus (every non-gameplay screen and overlay)
| Input | Meaning |
|---|---|
| D-pad / left stick | move focus |
| **A** | confirm / select / lock in |
| **B** | back / cancel, exactly one level |
| **Start** | "go": proceed from a ready lobby, open the pause menu, confirm on the title |
| Y | secondary action on the focused thing (e.g. Random) |
| X | tertiary action (only when the screen has one) |
| View | open the screen's settings or rules panel (e.g. RULES on character select) |
| LB / RB | page or tab left/right, change a count (e.g. CPUs −/+) |

- **CC-1.3** A always confirms and B always cancels. Inside an edit (a stepper or a slider in edit mode), B
  **reverts** to the value from before the edit and leaves edit mode. A commits.
- **CC-1.4** B on the root screen (title) does nothing, or opens the quit-confirm dialog. It never quits right away.
- **CC-1.5** **Whoever pauses owns the pause menu.** Only the device that pressed Start can move focus or confirm
  in it. The header says who paused ("PAUSED · P2" in P2's colour, with their goat head). Other players' presses
  are ignored. The owner's Start or B resumes.
- **CC-1.6** **Glyphs are consistent and device-aware.** There is ONE glyph component (Xbox-coloured A/B/X/Y circles,
  Start/View/LB/RB pills, stick glyph, and key-cap chips for keyboard). A prompt that belongs to one player (a
  character-select panel, the pause menu) shows that player's device glyphs. A shared prompt (footers, end
  screens) shows PAD glyphs if any pad is joined/active, key caps only when the keyboard is the sole device, and
  both on a GO/confirm prompt when pads and keyboard are mixed (amended 2026-11-14 per lobby review: last-device
  glyphs flicker in a 4-player lobby). Never ASCII "(A)", never mixed chip styles.
- **CC-1.7** Prompts name the real binding. If the footer says "Y Random", Y does Random on that screen, and the
  keyboard equivalent works too (and shows when keyboard is the active device).

## 2. Keyboard is a first-class device
- **CC-2.1** Everything a pad can do in menus, the keyboard can do: arrows **and** WASD move focus, Enter/Space
  confirm, Esc/Backspace back, Tab = View, Q/E = LB/RB, R = Y, F or C = X, Enter = Start.
- **CC-2.2** Keyboard gameplay (scheme KB-L): WASD move, Space boost, K super, L powerup, Esc pause. Optional
  scheme KB-R for a second keyboard player (Duck Game/TowerFall do this): arrows move, Numpad0 or RShift boost,
  Numpad1 super, Numpad2 powerup, Numpad Enter join/pause.
- **CC-2.3** The keyboard joins a lobby exactly like a pad does (CC-4). It is a device, not "P1's extra controls".
  It never silently drives a second player.
- **CC-2.4** The mouse is optional. Nothing requires it, and it never steals focus without real mouse motion. The
  cursor is hidden on pad or keyboard input and always hidden in gameplay.

## 3. Devices: ownership, hot-plug, disconnect
- **CC-3.1** **A player is a device.** The device that joined a slot drives that player in menus that belong to a
  player and in the match. Devices are never assigned by `get_connected_joypads()` order. (That order includes
  virtual and phantom devices such as Steam Input or DS4Windows, and has nothing to do with who is holding what.)
- **CC-3.2** Device identity is `kb` or `pad:<id>`, worked out from the **event class**. Godot reports keyboard
  events as device 0, the same number as joypad 0, so the device number alone cannot tell them apart.
- **CC-3.3** Pads that have not joined cannot drive shared menus once a lobby exists (ArenaSelect, the end
  screens). Before the first join, any device drives the front-end.
- **CC-3.4** **Disconnect mid-match → auto-pause.** The overlay shows "P2 CONTROLLER DISCONNECTED" with P2's goat
  and colour. Choices: reconnect and press A on that pad (resume); press A on any device that has not joined
  (that device takes over P2); RESUME WITHOUT P2 (P2's goat goes idle or becomes a CPU); QUIT TO MENU (hold).
  The pause owner is "any remaining joined device".
- **CC-3.5** Disconnect in the lobby: that slot goes to DISCONNECTED (goat and colour kept) for 10 s. The first
  unassigned device to press A takes it over. After 10 s it becomes EMPTY. A newly connected pad does nothing
  until it presses A.
- **CC-3.6** Rumble goes **only** to the device of the player it concerns, and can be switched off in Options.

## 4. Character select = per-player lobby (the Smash / TowerFall / Duck Game model)
- **CC-4.1** Each device presses **A (or Start)** to join and gets its OWN slot panel and cursor. Players join,
  browse, pick and ready **at the same time, independently**. No turn-taking, no shared cursor, no "P2 — pick
  now".
- **CC-4.2** Every player picks a goat (and their goat's colour, which is the player's identity colour)
  independently. A goat another human has taken is shown as taken (with their P-badge). There are 6 goats and at
  most 4 humans, so every player always has at least 3 choices. **No player can ever be locked out.**
- **CC-4.3** **B un-readies, then leaves.** READY →B→ PICKING →B→ EMPTY (goat released). B on an empty lobby goes
  back one screen. Holding B for 1.0 s (with a fill ring) goes back one screen from any state.
- **CC-4.4** When every joined player is READY (and the roster is valid for the mode), a full-width
  **"READY TO FIGHT!"** banner appears. **Any ready player presses Start (or A)** to proceed.
- **CC-4.5** **Bots are added explicitly** (LB/RB = CPUs −/+ in Brawl, or the RULES panel), shown as CPU chips,
  and never take a human's goat. A lone human with 0 CPUs in a versus mode sees a prompt ("RB ADD A CPU, or a
  friend presses A"), not a dead end.
- **CC-4.6** Match rules (KOs, lives, CPU skill, teams) live in a RULES panel (View/Tab) or a separate screen.
  Rules never share one focus graph with the goat picks.
- **CC-4.7** The lobby survives the round trip. Back from arena select, CHANGE SETUP and REMATCH all keep who is
  joined, on which device, with which goat. QUIT TO TITLE clears it.
- **CC-4.8** The device that confirmed the mode card is auto-joined as P1 (Smash does this). Solo players never
  have to "join" a second time.

## 5. Menu navigation
- **CC-5.1** Focus is **always visible and always singular**: exactly one element looks focused (scale ≥1.08 plus a
  ring or colour change of at least 6 px or a full style swap). A permanently "primary"-styled button that looks
  focused when it is not is a violation.
- **CC-5.2** Wrap rules: short vertical or horizontal lists wrap. Grids wrap within a row. Long carousels (shelves)
  do not wrap but give edge feedback (nudge plus a deny tick). Every direction from every focusable either moves
  or gives deny feedback. Nothing is silently dead.
- **CC-5.3** D-pad and left stick both navigate. A held direction repeats: 0.40 s initial delay, then every
  0.09 s. The stick uses hysteresis (press at 0.5, release at 0.3) and the dominant axis on diagonals.
- **CC-5.4** B always goes back exactly one level (closes the overlay, leaves the edit, previous screen). No screen
  is a dead end. Every screen except the title has a B path out.
- **CC-5.5** "Back" is a glyph chip (B Back), clickable for mouse users, **not** a focusable button in the pad
  focus chain.
- **CC-5.6** Default focus on screen entry is the most likely next action. Coming back to a screen restores the
  focus the player left from.
- **CC-5.7** Input that crosses a screen boundary is swallowed. The press that changes a screen (or resumes a
  match) must not act again on the next screen. In particular, gameplay actions are ignored until the button has
  been **released** once after a menu → gameplay transition (no boost, no powerup on RESUME).

## 6. Destructive actions
- **CC-6.1** Restart, quit to menu and quit game need **hold-to-confirm** (0.9 s hold, radial fill in the owner's
  colour, rising tick, early release cancels) or a confirm dialog whose **default focus is the safe option**.
  Double-press "REALLY?" text swaps are banned (mashing A gets straight through them).
- **CC-6.2** Leaving a lobby that has joined players needs hold-B (CC-4.3), never a single tap.

## 7. Pause menu
- **CC-7.1** Content, in order: **RESUME** (default) · **RESTART** (hold) · **CONTROLS** · **OPTIONS** ·
  **QUIT TO MENU** (hold). Optional: CHANGE SETUP.
- **CC-7.2** Header: "PAUSED · P# " plus the goat head in the owner's colour (CC-1.5), plus a context line (mode ·
  arena · score).
- **CC-7.3** RESUME (A) or Start/B from the owner resumes instantly, with input swallowed until release (CC-5.7).
- **CC-7.4** The game simulation, timers, music ducking (−8 dB low-pass optional) and rumble all stop while paused.

## 8. Readable at couch distance (1080p reference, 3 m from a 55" TV)
- **CC-8.1** Any text a player must read: ≥ 28 px. Buttons: ≥ 40 px. Titles: ≥ 64 px. Version or legal text only:
  ≥ 22 px. Nothing a player must read in play sits below 28 px.
- **CC-8.2** Text over art always has a chocolate outline (≥ 6 px) or a backplate. Contrast ≥ 4.5:1.
- **CC-8.3** Player identity is legible at a glance. Each human has ONE identity colour (= their goat's colour),
  used on the HUD card, name tag, score bars, edge chevrons and banners. Humans keep a small persistent "P#" pip
  above their goat during play (fading to ~70 % alpha, never gone). Bots are tagged **CPU**, never "P3".
- **CC-8.4** No placeholder or debug text anywhere: no "P1" on unused HUD cards, no version stamps outside the title
  and Options, no dev servers in a player build.
- **CC-8.5** One fighter, one name (WK-88, audit CD1-04). Every fighter has exactly one **NAME** and may carry one
  small **sub-tag**:

  | | NAME (always, identity colour) | sub-tag (smaller, only where a second token fits) |
  |---|---|---|
  | Human | `P#` — the lobby label (`P3` stays P3 with an empty P2 slot) | their goat's name (`POGO`) |
  | CPU | their goat's name (`VEX`) | `CPU` |

  - The NAME is the only word that names a fighter. HUD cards, identity pips, stage/match banners, MATCH POINT,
    stage tallies, the ScoreScreen, the Victory screen and pause chips all print the same NAME.
  - The sub-tag sits right after or under the NAME, smaller and lower-weight. It is never shown alone and never
    replaces the NAME. Shown on: HUD card (under the name), ScoreScreen row, Victory winner ribbon and standings
    rows, and a CPU's stage-intro pip. Not shown on: one-line announcer text (banners, top band, tallies), pause
    chips, or a human's persistent pip (it stays one token).
  - So `CPU` is a sub-tag, never a name ("who is CPU?"). `P#` never names a CPU (CC-8.3). Two CPUs in one line
    stay distinct ("BILLY +1 · VEX +1").
  - Code: `PartyMatch.player_name(i)` / `player_subtag(i)` (+ `player_names()` / `player_subtags()`). Nothing
    player-facing prints `player_tag(i)` (it is the QA "P#/CPU" kind readout).

## 9. Feedback sounds (every input answers)
- **CC-9.1** Distinct UI sounds: navigate (soft tick), confirm (pop), back (low boop), deny (buzz), join (a chime
  that rises in pitch P1→P4), ready (stamp plus goat bleat), all-ready (sting), hold-to-confirm (rising ticks).
  One pitch-shifted click for everything does not meet this.
- **CC-9.2** Sound starts within one frame of the input. A deny always comes with a visual shake.

## 10. Quick rematch flow
- **CC-10.1** Match end → **REMATCH** is default-focused and takes one press. CHANGE ARENA is ≤ 2 presses. CHANGE
  GOATS/SETUP is ≤ 3 presses. QUIT TO MENU is last, and it is the target of B (first B focuses it, second takes it).
- **CC-10.2** End-screen buttons arm ≥ 1.0 s after they appear **and** only accept a press that started after the
  screen appeared. Someone still mashing A (boost) as the last KO lands must not trigger REMATCH or skip the score
  tally.
- **CC-10.3** Rematch keeps the lobby, rules and arena choice (CC-4.7).

## 11. Teach the controls
- **CC-11.1** Every mode's first stage shows the controls legend (device-aware glyphs, per CC-1.6). A CONTROLS screen
  (one shared scene) can be reached from Pause and Options. It shows the full move set, including "hold X to aim,
  release to fire".
- **CC-11.2** Every mode's first stage also states the goal in one line (WK-15, audit D-04/D-13). The mode owns the
  words (`GameMode.goal_line`) and the verbs the legend teaches (`GameMode.legend_verbs`). BRAWL prints its rule
  under the arena name on the stage-1 intro card ("SMASH 'EM OFF-SCREEN · FIRST TO 10 KOs"). Modes without an intro
  card (Sports, Trials) show it as a gold goal chip above the controls legend. Rule copy never contradicts scoring:
  BRAWL scores KOs, so its banners lead with KOs and the survivor is a sub-line.

## 12. Release hygiene
- **CC-12.1** No dev or automation server runs unless a dev flag is passed. No `push_warning` spam in the console
  of a normal play session.
- **CC-12.2** The mouse cursor is hidden in gameplay (CC-2.4).
- **CC-12.3** Fonts ship with the game (bundled `.ttf`/`.otf`). Never fall back to whatever system font happens to
  be installed.

---

### Reference behaviours (for reviewers settling disputes)
- **Smash Ultimate:** join and cursor per pad, token on the portrait, hold B to leave the CSS, "READY TO FIGHT"
  band, Start proceeds, rules on a separate screen, CPU slots added explicitly, the pauser owns the pause.
- **Mario Kart 8:** per-player cursors on a shared roster at the same time, A confirms and B un-confirms, the next
  step waits for all players.
- **Duck Game / TowerFall:** press A/Start to join on that pad, a panel per player you cycle with left/right, B
  backs out, everyone ready → go. Two keyboard players supported.
- **Overcooked:** a controller-disconnect pause overlay with reassignment.
- **Brawlhalla / Rocket League:** Start/Menu pauses and B never does. Device-aware glyphs (keyboard vs pad).
  Per-player rumble.
