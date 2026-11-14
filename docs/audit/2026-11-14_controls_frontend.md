# Controls & Front-End Audit — 2026-11-14 (weekend polish run seed)

**Author:** UI/UX Designer · **Method:** code + docs reading only (the rendered-game slot was held by another
agent). Every finding cites file:line. Findings marked **VERIFY** are high-confidence from code but must be
confirmed in a rendered run before they are fixed.
**Standard:** `docs/COUCH_CONVENTIONS.md` (rules cited as `CC-x.y`).
**Branch / HEAD:** `weekend/polish` @ 11bb63f.

**Verdict on the current controls + front-end: REJECT.** It looks polished, but the input model underneath is a
single-player menu system with couch play bolted on. There is one shared focus cursor, one global action map,
devices are assigned by enumeration order, and the B button is double-booked. Both of the owner's complaints come
straight from code:

1. *"B opens the pause menu"*: **every powerup use pauses the game** (C-01).
2. *"2 users with 2 controllers can't select their character"*: the screen has one shared cursor and picks happen
   one after another. The human count is a hidden stepper that defaults to 1. At the default, **both pads drive
   the same goat** (C-03/C-04/C-05).

---

## A. Input map as shipped (`project.godot` [input], lines 32-112)

Joypad names: 0=A 1=B 2=X 3=Y 4=View 5=Guide 6=Start 9=LB 10=RB. Axis 0 = LS-X, axis 1 = LS-Y.
`device:-1` = all devices.

| Action | Keyboard | Joypad | Used by |
|---|---|---|---|
| `move_left` | A (phys 65) | LS-X −1 | gameplay aim; also Stepper/ToySlider/ToyToggle value edits |
| `move_right` | D (68) | LS-X +1 | same |
| `move_up` | W (87) | LS-Y −1 | gameplay aim |
| `move_down` | S (83) | LS-Y +1 | gameplay aim |
| `boost` | Space (32) | **A** (0) | gameplay fly |
| `super` | K (75) | **X** (2) | gameplay super (hold/release) |
| `use_powerup` | L (76) | **B** (1) | gameplay powerup (edge) |
| `ui_accept` (override) | Enter, KP Enter, Space | **A** (0) | Godot Button activation, all menus |
| `menu_accept` | Enter (phys) | **A** (0) | scoreboard skip, end rows, CharacterSelect launch |
| `menu_back` | Esc (phys) | **B** (1) | every screen's back, **AND opens Pause in a live match** (PartyMatch.gd:989) |
| `menu_page_prev` | PageUp | **LB** (9) | ArenaSelect shelf jump −3 |
| `menu_page_next` | PageDown | **RB** (10) | ArenaSelect shelf jump +3 |
| `menu_random` | *(none)* | **Y** (3) | CharacterSelect random spin (keyboard can't reach it) |
| `ui_left/right/up/down`, `ui_cancel` | Godot defaults (arrows / Esc) | Godot defaults (D-pad; stick axes **VERIFY** on 4.7) | built-in focus nav |
| — **pause** — | — | — | **does not exist** |
| — Start [6], View [4] — | — | — | **bound to nothing anywhere** |

Collisions that matter: **B = `use_powerup` + `menu_back`** (both fire during gameplay → C-01). A = `boost` +
`ui_accept` + `menu_accept` (fine in itself, but end screens poll accept from any device while players are still
mashing boost → C-14). Space = `boost` + `ui_accept` (keyboard, fine).

## B. How devices map to players today (traced)

- Menus: every screen uses Godot's single viewport focus with `ui_*` / `menu_*` on `device:-1`. **Any pad or the
  keyboard drives any menu.** No code anywhere reads `InputEvent.device` (grep: zero hits in `src/ui`, `src/modes`).
- Match spawn: `PartyMatch._spawn_player` → `InputHuman.for_human(i, human_count)` (PartyMatch.gd:288-290).
  - `human_count <= 1` → `InputHuman.new()` = **legacy any-device: the keyboard AND every connected pad drive P1**
    (InputHuman.gd:31-32, 46-47).
  - `pads >= humans` → human *i* gets `get_connected_joypads()[i]`, and P1 also keeps the keyboard (InputHuman.gd:48-50).
  - `pads < humans` → P1 = keyboard only, P2.. = pads in enumeration order, and any overflow human =
    **keyboard too** (InputHuman.gd:51-56, "share the keyboard"), so two goats move off the same keys.
  - Clones are scoped to the device id at spawn (InputHuman.gd:60-73). There is no reconnect path.
- Hot-plug: `Input.joy_connection_changed` is connected nowhere (grep: zero hits).
- Rumble: `Juice._rumble` and `PowerupSystem` loop over **all** connected pads (Juice.gd:289-292, PowerupSystem.gd:239-240).

## C. Trace: two friends, two pads, Brawl (the owner's exact case)

1. Title → PLAY → BRAWL. Either pad can do this, because focus is shared.
2. CharacterSelect opens. `human_count` = 1 (MatchConfig.gd:11 default). The HUMANS stepper sits in the bottom
   tray (CharacterSelect.gd:108). Nothing on screen says "press A to join", and P2's pad has no presence at all.
3. Friend 1 presses A on POGO. It locks as P1 (`_lock_in`, CharacterSelect.gd:276-316). Because humans = 1,
   `_locked = true` and the prompt says "P1 READY — (A) FIGHT!".
4. Friend 2 presses A on *their* pad, expecting to pick. The event reaches the same shared focus →
   `activate()` → `_locked` → `_go_arena()` (CharacterSelect.gd:158-159). **Friend 2's "pick" launches the game
   forward.** If Friend 2 nudges the stick first, `_on_hero_focus` calls `_unlock()` (CharacterSelect.gd:186-187)
   and **un-picks Friend 1**.
5. If they do find HUMANS=2: picks are **sequential on one cursor** ("P2 — PICK YOUR GOAT"), and either pad can make
   either pick. Nothing tells you which pad will become P2.
6. Match: with humans = 1 (the likely case), **both pads plus the keyboard drive the single human goat**. With
   humans = 2, P2 = `get_connected_joypads()[1]`. A Steam Input virtual pad, a DS4Windows duplicate or a
   connected wheel makes that the wrong device, and the player gets a dead stick.
7. Mid-match, someone uses a powerup (B). The game pauses (C-01).

This is the whole complaint, reproduced from code.

---

## D. Findings

Severity: **P0** breaks normal couch play / owner-visible nonsense · **P1** obviously amateur vs a real game ·
**P2** polish · **P3** nice-to-have. Size: S ≤ half a day · M ≈ 1 day · L multi-day.

### P0

**C-01 · P0 · B (use powerup) pauses the game**
- **What's wrong:** `use_powerup` and `menu_back` are both joypad button 1 (project.godot:70-75, 90-95).
  `PartyMatch._unhandled_input` opens the PauseMenu on `menu_back` in every state except BOOT/MATCH_END
  (PartyMatch.gd:986-991). Nothing in gameplay consumes the B event first, so **every powerup press pauses the
  match**. The first-stage legend even teaches "POWERUP = B" (ControlsLegend.gd:16). A second bug follows: the
  pause menu's "B Resume" (PauseMenu.gd:132-135; PauseMenu.tscn:92) means the B used to resume is still held
  when the sim restarts, which fires a powerup (see C-19).
- **Convention:** CC-1.1, CC-1.2.
- **Fix:** add a `pause` action: joypad Start [6] + keyboard Esc (physical 4194305) + P. `PartyMatch._unhandled_input`
  checks `pause` only, never `menu_back`. Keep Esc on `menu_back` for menus (Esc = back in menus, pause in
  gameplay is the PC convention). Record the pausing device for C-06. Files: `project.godot`, `src/modes/PartyMatch.gd`.
- **Size:** S.

**C-02 · P0 · Start/Menu does nothing anywhere; there is no pause button**
- **What's wrong:** no action binds button_index 6 or 4 (project.godot:32-112). Start is the first button any console
  player presses to pause, to proceed from a lobby, or on a title screen. Here it is dead.
- **Convention:** CC-1.1, CC-1.2, CC-4.4.
- **Fix:** `pause` (C-01). Add `menu_start` (Start [6] + Enter) for "proceed" on character select and "confirm" on
  the title. Add `menu_view` (View [4] + Tab) for RULES. Add a keyboard binding to `menu_random` (R).
- **Size:** S (with C-01).

**C-03 · P0 · Character select is one shared cursor with turn-based picking**
- **What's wrong:** one `_current`, one `_pick_idx`, one `_picked` stack (CharacterSelect.gd:54-57). Picks happen in
  order: P1 locks, then the same cursor becomes "P2 — PICK YOUR GOAT" (CharacterSelect.gd:295-312). Input is
  Godot's single viewport focus on `device:-1`, so **any pad picks for any player**. After the final lock, any
  focus move from any pad `_unlock()`s the last pick (CharacterSelect.gd:186-187), and so does the Random spin
  (it moves focus 10-15 times, CharacterSelect.gd:412-419). B pops the most recent pick whoever presses it
  (CharacterSelect.gd:163-165, 320-335). One "P1 flag" is recoloured per turn (CharacterSelect.gd:353-364). The
  frontend spec asked for "per-player pick-cursors" (frontend_ux_spec.md:335). That was never built.
- **Convention:** CC-4.1, CC-4.2, CC-4.3, CC-4.4, CC-3.1.
- **Fix:** rebuild as the per-player lobby in **§E** below. Files: `src/ui/CharacterSelect.gd` +
  `scenes/ui/CharacterSelect.tscn` (rewrite), new `scenes/ui/LobbySlot.tscn` + `src/ui/LobbySlot.gd`, new
  `src/core/InputRouter.gd` autoload, `src/core/MatchConfig.gd` (new fields).
- **Size:** L.

**C-04 · P0 · Joining is a stepper that defaults to 1. With two pads at the default, both drive the same goat**
- **What's wrong:** the human count comes from a "HUMANS" stepper in the bottom tray (CharacterSelect.gd:97,
  108), with default `human_count = 1` (MatchConfig.gd:11). No prompt invites a second player. At humans = 1,
  `InputHuman.for_human` returns the any-device provider (InputHuman.gd:46-47), so the keyboard and **every** pad
  control P1. Two friends who press A on two pads, as in every other party game, end up sharing one goat. This is
  very likely the owner's experience. Solo with CPUs has the same flaw: an idle pad on the couch nudges P1.
- **Convention:** CC-4.1, CC-3.1, CC-2.3.
- **Fix:** join-by-press (§E). Delete the HUMANS stepper. `human_count` = number of joined slots. Each human is
  driven by their joined device only.
- **Size:** part of C-03 (L).

**C-05 · P0 · Devices are assigned by `get_connected_joypads()` order, and overflow humans share the keyboard**
- **What's wrong:** InputHuman.gd:45-56. The order has nothing to do with who pressed what. It includes
  virtual/phantom devices (Steam Input, DS4Windows double-enumeration, wheels), which gives a dead P2. With fewer
  pads than humans, P1 is moved to keyboard-only and **every overflow human also gets the keyboard**
  (InputHuman.gd:56), so 3 humans on 2 pads gives two goats moving in lockstep. Also, when pads ≥ humans, P1 gets
  pad 0 **and** the keyboard (line 50), so a keyboard bump moves P1.
- **Convention:** CC-3.1, CC-3.2, CC-2.3.
- **Fix:** add `MatchConfig.human_devices: PackedStringArray` (`"kb"` / `"pad:N"`), written by the lobby. Add
  `InputHuman.for_device(key)`, which scopes to exactly that device (keyboard events only for `"kb"`, joypad
  events re-scoped to N for `"pad:N"`). Keep the legacy any-device path **only** when `human_devices` is empty
  (cold boot straight into Arena.tscn, QA harness). Delete the "share the keyboard" overflow. Files:
  `src/core/InputHuman.gd`, `src/core/MatchConfig.gd`, `src/modes/PartyMatch.gd:288-290`.
- **Size:** M.

### P1

**C-06 · P1 · Menus and pause accept every device. There is no pause owner and no joined-device filter**
- **What's wrong:** PauseMenu takes navigation and confirm from anyone (PauseMenu.gd:41-53, 129-135, built-in focus
  on `ui_*`). The header is just "PAUSED" (PauseMenu.tscn:51), so nobody knows who paused. ArenaSelect, Victory
  and the Sports/Trials end rows poll global actions (VictoryScreen.gd:237-248; SportsHUD.gd:224-235;
  TrialsHUD.gd:343-354).
- **Convention:** CC-1.5, CC-3.3, CC-7.2.
- **Fix:** InputRouter (§E.8) exposes `device_key(event)` and `is_joined(key)`. PauseMenu gets
  `setup(match, owner_key)` and drops events from other devices (`_input` + `set_input_as_handled` for non-owner
  events, with built-in focus nav disabled for non-owners). Header "PAUSED · P2" plus a goat head in the owner's
  colour. Shell screens after the lobby ignore unjoined devices.
- **Size:** M.

**C-07 · P1 · No controller hot-plug or disconnect handling**
- **What's wrong:** there is zero `joy_connection_changed` handling in the codebase. Mid-match, a dead battery
  leaves that goat idling to its death. A reconnect that comes back as a different id is a permanent dead stick,
  because the scoped clones are bound to the spawn-time id (InputHuman.gd:60-73).
- **Convention:** CC-3.4, CC-3.5.
- **Fix:** InputRouter connects `Input.joy_connection_changed`. In a match it calls `PartyMatch.on_device_lost(key)`
  → auto-pause with a DisconnectOverlay (variant of the PauseMenu scene): "P2 CONTROLLER DISCONNECTED", reclaim by
  pressing A on the same or any unjoined device (rebinds that player's InputHuman via `for_device`), RESUME WITHOUT
  P2, QUIT (hold). In the lobby the slot goes to DISCONNECTED (§E.3).
- **Size:** M.

**C-08 · P1 · A player's colour does not match their goat**
- **What's wrong:** `PLAYER_COLORS` is indexed by **slot** (PartyMatch.gd:50-52) and drives the HUD card tint
  (PlayerCard.gd:23-35), the name tag (PartyMatch.gd:466), score/victory bars (PartyMatch.gd:840, 891, 899), banners
  (BrawlMode.gd:248, 254) and FIRST BLOOD (PartyMatch.gd:639). The goat comes from the pick. Example: P1 picks
  BUTCH (blue) and gets a **pink** HUD card and a pink "P1" tag over a blue goat, while a CPU in green gets a
  **blue** card. The player's identity colour lies to them.
- **Convention:** CC-8.3.
- **Fix:** one `SKIN_COLORS` map (pink #ff5fa8, blue #4aa8ff, green #54c94a, yellow #ffc93f, purple #a15fff, orange
  #ff7a2d, the same values as CharacterSelect.gd:17-30) in a shared place (e.g. `CharacterProfiles` or a new
  `PlayerIdentity.gd`). `PartyMatch.player_color(i)` = colour of `players[i].skin`. Replace every
  `PLAYER_COLORS[i]` read. Sports keeps its team colourway skins, so the colours follow automatically.
- **Size:** S.

**C-09 · P1 · Players lose track of themselves: name tags vanish after 1 s and bots are called "P3"**
- **What's wrong:** NAME_TAG_LINGER = 1.0, then a fade (PartyMatch.gd:109, 518, 1050). There are six goats with the
  same silhouette, so across a room you lose yourself. Bots get "P%d" tags exactly like humans (PartyMatch.gd:466)
  and P# HUD cards (PlayerCard.gd:25).
- **Convention:** CC-8.3.
- **Fix:** humans keep a small persistent pip (28-32 px "P2" in a rounded tab with a chocolate outline in the
  player's colour, 70 % alpha after the intro, full alpha for 1 s after respawn). Bots show "CPU" during the intro
  only. HUD card label shows "CPU" for bots.
- **Size:** S.

**C-10 · P1 · Rumble shakes every controller**
- **What's wrong:** Juice.gd:289-292 and PowerupSystem.gd:239-240 loop over all connected pads. One player's hit
  buzzes everyone. Shake and rumble are also "always on" (Juice.gd:285, 290 comments).
- **Convention:** CC-3.6.
- **Fix:** `Player.rumble(weak, strong, dur)` → InputRouter maps player → device → `start_joy_vibration(id)`.
  Juice/PowerupSystem pass the concerned player. Add `Settings.rumble` (C-30).
- **Size:** S.

**C-11 · P1 · The keyboard was demoted: prompts lie to keyboard users and keyboard can't reach some features**
- **What's wrong:** the 2026-07-19 cleanup stripped every keyboard glyph (ui_professionalism_audit rule 1). But
  keyboard is still a real device (P1's default when pads < humans, InputHuman.gd:51-52). Keyboard users see "A
  Ready / Y Random" (CharacterSelect.tscn:276). `menu_random` has **no keyboard binding** (project.godot:108-112),
  which is the old "R-only" bug turned around. WASD does not navigate menus (only `ui_*` arrows), even though WASD is
  the keyboard movement scheme. ScoreScreen says "A CONTINUE" (ScoreScreen.tscn:134).
- **Convention:** CC-2.1, CC-1.6, CC-1.7.
- **Fix:** keyboard bindings for every menu action (R random, Tab view, Q/E pages, Enter start, WASD added to
  `ui_up/down/left/right`). A device-aware glyph component (C-23) driven by `InputRouter.last_device_kind`.
- **Size:** M.

**C-12 · P1 · Controls are barely taught: one 4-second legend in Brawl only, and no CONTROLS screen**
- **What's wrong:** ControlsLegend is only instantiated under `_mode.wants_scoreboard()`, which is Brawl only
  (PartyMatch.gd:235-245). Trials and both sports never show the controls. Pause has no CONTROLS entry
  (PauseMenu.tscn:54-84) and neither does Options (OptionsScreen.gd:17-29). "Hold X to aim, release to fire" is
  explained nowhere.
- **Convention:** CC-11.1, CC-7.1.
- **Fix:** move the legend out of the scoreboard gate (show it on stage 1 of every mode, with mode-specific chips:
  Sports adds "HEADBUTT the ball", Trials adds "LAND on the pad"). New `scenes/ui/ControlsScreen.tscn` (full move
  set with device glyphs and a goat pose per row: idle/charge/squash sprites exist), reached from Pause and Options.
- **Size:** M.

**C-13 · P1 · Focus can be ambiguous: a permanently "primary" button looks focused when it isn't**
- **What's wrong:** the end rows build buttons with `focus_mode = FOCUS_NONE` and style button 0 as
  `ShellBtnPrimary` permanently (SportsHUD.gd:181-185; TrialsHUD equivalent; VictoryScreen.tscn:227-245). Focus is
  shown by scale 1.12 and alpha 1.0 vs 0.85 only (VictoryScreen.gd:254-270). When QUIT is focused, the big pink
  REMATCH still reads as the selected item from across a room. The same risk exists on the title, where PLAY is
  permanently `ShellBtnPrimary` (MainMenu.tscn:46). **VERIFY** with a screenshot with OPTIONS focused.
- **Convention:** CC-5.1.
- **Fix:** swap the style on focus. Focused = `ShellBtnPrimary` + scale 1.12 + breath. Unfocused = `ShellBtn` at
  alpha 0.75. One rule in a shared `FocusRow` helper used by Victory/SportsHUD/TrialsHUD (the three copies of
  `_set_focus` collapse into it). For the title, either the same swap or a 6 px gold focus ring on top of the style.
- **Size:** S.

**C-14 · P1 · Mashing A (boost) as the round ends skips the score tally or triggers REMATCH**
- **What's wrong:**
  - ScoreScreen skip = any device's `menu_accept`/`ui_accept` after 0.8 s (PartyMatch.gd:74, 849-850). Players
    still flying (A = boost) skip the tally they never saw.
  - VictoryScreen: any accept after 0.05 s **fast-forwards and immediately arms** the row (VictoryScreen.gd:234-235,
    `_fast_forward` → `_arm()` at line 311). The **next** mashed A is REMATCH, about 1 s after the winning KO.
  - Sports/Trials rows arm after PROMPT_GUARD 1.0 s (PartyMatch.gd:112, 950-956) and fire on any `just_pressed`.
- **Convention:** CC-10.2, CC-5.7.
- **Fix:** a shared `InputGate` with two rules. (1) Only presses that **began after** the screen appeared count
  (track per-device "seen released since show"). (2) Arm ≥ 1.0 s after show. Fast-forward never arms: it lands
  the visuals, then the normal arm timer runs (minimum 0.6 s after the fast-forward). Scoreboard skip uses the same
  gate with a 1.2 s guard.
- **Size:** S.

**C-15 · P1 · HUD shows ghost cards with fewer than 4 players and no card at all for players 5-8 (VERIFY)**
- **What's wrong:** MatchHUD always takes 4 cards and calls `_cards[i].setup(i, colors[i], skins[i])` for i < 4
  (MatchHUD.gd:32-34). `skins` has `players.size()` entries (PartyMatch.gd:318-322). In a 1-human + 1-CPU or
  2-human Brawl, `skins[2]` is out of bounds. That is a runtime error, and cards 2/3 stay visible with their
  default "P1" text (PlayerCard.tscn:70). Brawl allows up to 8 players (CharacterSelect.gd:468-476), but players
  5-8 get no fuel or powerup card (MatchHUD.gd:38).
- **Convention:** CC-8.4, CC-8.3.
- **Fix:** `setup` hides `_cards[i]` for i ≥ players.size(). Add an 8-player layout: 4 corner cards plus 4
  compact cards (head + fuel only) in a bottom-centre strip, or two compact rows. **VERIFY** in a rendered
  1H+1CPU Brawl first.
- **Size:** S (hide) / M (8-player layout).

**C-16 · P1 · The goat pick means nothing in Sports, and the "characters" are recolours**
- **What's wrong:** `character_ids[i]` is forced to `"bouncer"` on every pick (CharacterSelect.gd:289-293), so the
  six named heroes with personality blurbs play the same. In ROCKETBALL/DROPSHOT, `SportsMode.spawn_plan` throws
  away the pick and assigns a team colourway skin (SportsMode.gd:236-241, `TEAM_SKINS` line 26). Picking PUFF in
  Rocketball gives you a pink or blue goat anyway. A pick that is silently ignored is nonsense UI.
- **Convention:** CC-4.2 (the pick must be real), CC-1.7.
- **Fix:** in the Sports lobby, the goat carousel offers only that team's colourways. RED = POGO (pink) / BILLY
  (orange). BLUE = BUTCH (blue) / VEX (purple). **Picking the goat picks the team** (§E.6). `SportsMode.spawn_plan`
  honours `MatchConfig.team_ids` and the human skins instead of humans-first halves. Separately, flag to the
  Creative Director that personality blurbs over identical stats is a promise the game doesn't keep (either wire
  `CharacterProfiles` deltas or soften the copy). Not a UI fix.
- **Size:** M.

**C-17 · P1 · Match rules share one focus graph with the goat picks, and touching them un-readies you**
- **What's wrong:** BOTS / BOT SKILL / KILLS / LIVES / HUMANS steppers sit in a tray under the grid, wired into the
  same focus graph as the hero cards and the FLAIR stepper (CharacterSelect.gd:81-121, 485-520). When ALL READY,
  every focus change un-readies (CharacterSelect.gd:186-187), and A on a stepper launches instead of editing
  (accept_override, CharacterSelect.gd:432-436, 500-504). That mode-dependent meaning of A is hidden.
- **Convention:** CC-4.6, CC-5.1.
- **Fix:** a RULES panel opened with View/Tab (§E.7). Rules are not part of the lobby focus graph at all.
- **Size:** part of C-03.

**C-18 · P1 · Destructive pause actions use a double-press "REALLY?" text swap**
- **What's wrong:** RESTART and QUIT TO MENU arm on the first press and fire on a second press within 1.5 s
  (PauseMenu.gd:17-21, 74-95). Two quick A taps get straight through. The label swap reads like a glitch.
- **Convention:** CC-6.1.
- **Fix:** a `HoldButton` component: hold A for 0.9 s, radial fill ring in the owner's colour on the button's left
  cap, ticks rising in pitch every 0.15 s, release before full cancels (ring drains in 0.15 s). Use it on Pause
  RESTART/QUIT and on the DisconnectOverlay QUIT. The MainMenu quit dialog is fine (its default focus is STAY,
  MainMenu.gd:65).
- **Size:** S.

**C-19 · P1 · The press that leaves a menu acts again in gameplay**
- **What's wrong:** `PauseMenu._do_resume` unpauses on the A press itself (PauseMenu.gd:97-99), and A is still held,
  so `InputHuman.poll` sees `boost` pressed and the goat blasts off on resume. With "B Resume"
  (PauseMenu.gd:132-135), `use_powerup` is held on the first poll after unpause and `_prev_pow` is false, so a
  **powerup fires** (InputHuman.gd:81-88).
- **Convention:** CC-5.7, CC-7.3.
- **Fix:** add `InputHuman.swallow_until_release()`, called by PartyMatch on resume, rematch and match start. While
  swallowing, `poll()` reports no boost/super/powerup until each of those is seen released once.
- **Size:** S.

**C-20 · P1 · The pause menu is missing CONTROLS, who paused, and match context**
- **What's wrong:** it has RESUME / RESTART / OPTIONS / QUIT TO MENU only (PauseMenu.tscn:54-84). No CONTROLS, no
  owner, no mode/arena/score.
- **Convention:** CC-7.1, CC-7.2.
- **Fix:** add CONTROLS (opens ControlsScreen in-place like Options, PauseMenu.gd:109-127). Header "PAUSED · P2" plus
  the goat bust (`portrait_<id>.png`) in the owner's colour. A sub-line with mode · arena name (`level_name`) · a
  compact score.
- **Size:** S.

### P2

**C-21 · P2 · Holding a direction doesn't repeat on pads, and stick navigation is unverified**
- **What's wrong:** Godot echoes keyboard keys only. Joypad buttons and axes never repeat, and there is no repeat
  code in `src/ui` (grep "echo|repeat": none). Holding the D-pad on a 20-card shelf moves one card (LB/RB page jump,
  ArenaSelect.gd:504-522, softens this). Stick navigation relies on Godot's default `ui_*` axis events with no
  hysteresis. **VERIFY** that the 4.7 defaults include LS axes.
- **Convention:** CC-5.3.
- **Fix:** a `MenuNav` helper in MenuScreen: per-device held direction (D-pad buttons + LS with press 0.5 /
  release 0.3, dominant axis), 0.40 s delay then 0.09 s repeat. It synthesises `ui_*` presses (or calls
  `find_valid_focus_neighbor`). Add LS axes to the `ui_*` actions explicitly in `project.godot`.
- **Size:** M.

**C-22 · P2 · One sound for every UI event**
- **What's wrong:** AudioManager registers a single `ui_click` sample (AudioManager.gd:33). Move, confirm, back,
  deny and lock are all that sample pitch-shifted (MenuScreen.gd:98-104, 201; Stepper.gd:140-156). Lock-in borrows
  `super_fire` (CharacterSelect.gd:302).
- **Convention:** CC-9.1.
- **Fix:** add `ui_move`, `ui_confirm`, `ui_back`, `ui_deny`, `ui_join` (4 pitches), `ui_ready` (+ goat bleat),
  `ui_all_ready` sting, `ui_hold_tick`. **Art/audio ask:** an 8-sample UI SFX set (CC0 sources are fine).
- **Size:** S (code) + asset sourcing.

**C-23 · P2 · Two glyph systems plus ASCII glyphs**
- **What's wrong:** HintStrip draws cream rounded squares with a chocolate letter (HintStrip.gd:29-62), while PadGlyph
  draws Xbox-coloured circles (PadGlyph.gd:11-13, 40-52). The ready prompt uses ASCII "(A)"
  (CharacterSelect.gd:310). "< >" is a text glyph (CharacterSelect.tscn:276, Options.tscn:93, ArenaSelect.tscn:130).
  Nothing supports Start/View/LB/RB or key caps.
- **Convention:** CC-1.6.
- **Fix:** one `Glyph` control (extend PadGlyph): `A B X Y` coloured circles, `START VIEW LB RB` rounded pills,
  `stick`/`dpad` drawn, `kb:<Key>` cream key caps. Pick it from `InputRouter.kind_for(device)` or `last_device_kind`.
  HintStrip, ControlsLegend, ready banner and lobby panels all use it.
- **Size:** M.

**C-24 · P2 · "< BACK" buttons sit in the pad focus chain, and ModeSelect's back wiring is odd**
- **What's wrong:** header back buttons are registered focusables on ModeSelect/CharacterSelect/ArenaSelect/Options
  (ModeSelect.gd:52-56; CharacterSelect.gd:83, 514-515; ArenaSelect.gd:165, 437-451; OptionsScreen.gd:27-29). They
  take a focus stop that B already covers. On ModeSelect the comment says "right from the final card lands on
  Back", but `wire_row` wraps right to the first card. Back is reachable only by pressing Down on the **last** card
  (ModeSelect.gd:53-56), and Down on the other cards does nothing.
- **Convention:** CC-5.5, CC-5.2.
- **Fix:** make the header back a `Glyph B` + "BACK" chip, mouse-clickable, `focus_mode = NONE`. Remove it from all
  focus wiring.
- **Size:** S.

**C-25 · P2 · Stepper B commits the edit instead of cancelling it**
- **What's wrong:** in edit mode, B confirms the new value (Stepper.gd:173-176). Every console menu treats B as
  cancel.
- **Convention:** CC-1.3.
- **Fix:** store `_edit_start_index` on entering edit. B restores it, emits `changed` if it differs, and exits
  edit. A commits.
- **Size:** S.

**C-26 · P2 · The mouse cursor is always visible, and hover steals focus**
- **What's wrong:** no `Input.mouse_mode` call anywhere outside the dev server. The OS cursor sits over gameplay.
  `mouse_entered` → `grab_focus()` (MenuScreen.gd:59-61, PauseMenu.gd:50-52). Screens scale and slide in under a
  resting cursor (ShellRoot.gd:65-75, MenuScreen.gd:113-119), which can fire `mouse_entered` and pull focus away
  from the pad's default.
- **Convention:** CC-2.4, CC-12.2.
- **Fix:** InputRouter hides the cursor on any key/joypad event and shows it on `InputEventMouseMotion` with
  relative length > 4 px. Hover-to-focus only while the cursor is visible. Always hidden while
  `PartyMatch.state` is COMBAT.
- **Size:** S.

**C-27 · P2 · Text below couch-distance size**
- **What's wrong:** `CardTag` 22 px and `CardName` 26 px (theme.tres:346, 356), HintStrip glyph letters 22 px
  (HintStrip.gd:52), FLAIR value forced to 22 px (CharacterSelect.gd:509), ControlsLegend labels 26 px
  (ControlsLegend.gd:59).
- **Convention:** CC-8.1.
- **Fix:** a 28 px floor for anything a player reads. Raise the theme tokens and re-check layout overflow on the
  cards (MenuCard titles already auto-shrink).
- **Size:** S.

**C-28 · P2 · Dev leftovers in the player build: "v0.1" on every screen and a TCP automation server**
- **What's wrong:** a "v0.1" label in the footers of MainMenu/ModeSelect/CharacterSelect/ArenaSelect/Options
  (MainMenu.tscn:84, ModeSelect.tscn:103, CharacterSelect.tscn:290, ArenaSelect.tscn:145, Options.tscn:107).
  `McpInteractionServer` is an autoload (project.godot:20) that listens on 127.0.0.1:9090 in every run, including
  the owner's `PLAY GOTTABOUNCE.bat`.
- **Convention:** CC-8.4, CC-12.1.
- **Fix:** keep the version only on the title and Options. Gate the MCP server: `_ready` returns unless
  `"--gb-dev" in OS.get_cmdline_user_args()` (or `OS.is_debug_build()` plus the flag). Update
  `tools/run_game.ps1` to pass `-- --gb-dev`. **Coordinate:** this breaks gbplay until run_game.ps1 is updated, so
  land both in one commit.
- **Size:** S.

**C-29 · P2 · CHANGE SETUP claims picks are kept, but it resets them. Nothing persists across the match**
- **What's wrong:** GameConfig.gd:16-19 says "players keep their picks". CharacterSelect is rebuilt with
  `_picked = []` (CharacterSelect.gd:57), so no card shows locked and everyone re-picks. QUIT from a match lands on
  the title (ShellRoot.gd:39-40) and the lobby is lost.
- **Convention:** CC-4.7, CC-10.3.
- **Fix:** `GameConfig.lobby` (slot array, §E.2) persists. CHANGE SETUP restores every slot in PICKING with its goat
  and device. Back from ArenaSelect restores READY. QUIT TO MENU clears it.
- **Size:** S (inside the C-03 rebuild).

**C-30 · P2 · Options is thin**
- **What's wrong:** 3 volume sliders + fullscreen only (OptionsScreen.gd:17-29). No rumble toggle, no screen-shake
  setting (Juice.gd:285 "always on"), no CONTROLS.
- **Convention:** CC-3.6, CC-11.1.
- **Fix:** add RUMBLE (toggle), SCREEN SHAKE (OFF / LOW / FULL stepper → `Juice` trauma scale), and CONTROLS
  (opens ControlsScreen). Persist in Settings.
- **Size:** M.

**C-31 · P2 · Sports teams can't be chosen**
- **What's wrong:** the roster is split humans-first into halves (SportsMode.gd:233-241; CharacterSelect.gd:380-394).
  2 humans + 2 CPUs is always humans vs CPUs, so two friends can't play 1v1 with a CPU each. With 3 humans it is
  always P1+P2 vs P3+CPU.
- **Convention:** CC-4.2, CC-4.5.
- **Fix:** the team is picked through the goat colourway (§E.6). Add `MatchConfig.team_ids`. CPUs fill the empty
  seats on each team.
- **Size:** M (with C-16).

**C-32 · P2 · The font depends on the machine**
- **What's wrong:** the theme default is a `SystemFont` chain "Arial Rounded MT Bold, Segoe UI Black, Arial Black,
  Verdana" (theme.tres:3-5, 320). It renders differently per PC, and it is a stock-font tell. Already listed as
  open (STATUS: "real FONT (owner font pick + download approval)").
- **Convention:** CC-12.3.
- **Fix:** bundle an OFL rounded heavy display face (candidates: Fredoka, Baloo 2 ExtraBold, Lilita One) in
  `assets/fonts/`. **BLOCKED?** STATUS says this needs owner approval to download. The producer should decide
  whether OFL fonts fall under the standing art-pipeline permission.
- **Size:** S once unblocked.

### P3

**C-33 · P3 · Only one keyboard player.** There is one keyboard scheme (project.godot:34-75). Duck Game and
TowerFall support two players on one keyboard. **Convention:** CC-2.2. **Fix:** a KB-R scheme as separate actions
(`move_left_kb2` …) with an InputHuman device key `"kb2"`, and lobby join with Numpad Enter. **Size:** M.

**C-34 · P3 · Naming drift.** The screen title says "CHOOSE YOUR BOUNCER" (CharacterSelect.tscn:72), the prompt says
"PICK YOUR GOAT" (CharacterSelect.gd:312), and the cast is "the Herd". **Convention:** CC-1.7 (say what it is).
**Fix:** "CHOOSE YOUR GOAT" everywhere. **Size:** S.

**C-35 · P3 · Mode cards don't say how many can play.** For example, TRIALS is 1-4 co-op and DROPSHOT is 1v1/2v2
(ModeSelect.gd:11-20). **Convention:** CC-4.5 (no surprises). **Fix:** a player-count chip on each MenuCard
("1-4 CO-OP", "1-4 · 1V1/2V2", "2-8 VERSUS"). **Size:** S.

**C-36 · P3 · View and the triggers do nothing in gameplay.** **Convention:** CC-1.1 table. **Fix:** optional
hold-View score overlay (reuse ScoreScreen in a non-blocking corner variant). Optional RT = alternate boost and
RB = alternate super for players who expect triggers. **Size:** S.

### Count by severity
| P0 | P1 | P2 | P3 | Total |
|---|---|---|---|---|
| 5 | 15 | 12 | 4 | **36** |

---

## E. CHARACTER SELECT REDESIGN SPEC: "THE HERD LOBBY"

Model: **Duck Game / TowerFall panels with Smash's join, ready-banner and rules grammar.** Each player has a panel
and cycles their own goat with their own stick. There are no free-floating cursors: they are mouse-ish and slow on
a stick, and per-panel carousels are faster to build and to use from a couch.

### E.1 Goals (acceptance in one line each)
1. Two to four people with any mix of pads and the keyboard can join, pick and ready **at the same time** without
   talking to each other.
2. The device you joined with is the device that drives your goat in the match (CC-3.1).
3. Nobody can be locked out, nobody can pick for someone else, and one player's input never changes another
   player's panel.
4. A solo player goes Mode → (auto-joined) → A (lock) → A/Start (go) in **two presses**.

### E.2 Data model
```
# GameConfig.lobby : Array[Dictionary], size 4, persists across shell <-> match until QUIT TO TITLE
slot = {
  "state":  "EMPTY" | "PICKING" | "READY" | "DISCONNECTED",
  "device": "" | "kb" | "pad:<id>",      # from InputRouter.device_key(event); never get_connected_joypads order
  "goat":   0..5,                         # index into HEROES (CharacterSelect.gd:17-30), or -1 = RANDOM (resolved on proceed)
  "flair":  "",                           # per-slot flair id (P-slot 0's choice persists to Settings.equipped_flair)
  "team":   -1 | 0 | 1,                   # SPORTS only, derived from goat colourway
  "dc_t":   0.0,                          # DISCONNECTED countdown (10 s)
}
# GameConfig.lobby_cpus : int                (BRAWL 0..(8 - humans))
# MatchConfig new fields: human_devices: PackedStringArray, team_ids: PackedInt32Array, flair_ids: PackedStringArray
```
Slot index = P-number (slot 0 = P1). On proceed, joined slots are **compacted in slot order** into
`human_count / human_devices / skin_ids / flair_ids / team_ids`. A player who joined in slot 3 while slot 2 is
empty is still "P3" in the lobby, but becomes human index 2 in the match. Their tag reads "P3" because the slot
number is carried as `MatchConfig.human_labels` (PackedInt32Array). Name tags and HUD cards use the label, not
the index.

### E.3 Slot state machine (per slot, fully independent)
```
             A/Start from an unassigned device (lowest EMPTY slot; or a DISCONNECTED slot if no EMPTY)
   EMPTY ─────────────────────────────────────────────────────────────▶ PICKING
     ▲                                                                   │  ▲
     │ B (owner)                                              A (owner)  │  │ B (owner)
     └───────────────────────────────────────────────────── PICKING ◀───┘  │
                                                                │          │
                                                                ▼ A        │
                                                              READY ───────┘
   any state with device ──(device disconnects)──▶ DISCONNECTED ──(10 s)──▶ EMPTY
   DISCONNECTED ──(A from that device, or any unassigned device)──▶ PICKING (goat kept)
```

### E.4 Inputs per state (pad · keyboard). Only events from the slot's own device reach the slot.
| State | Input | Effect |
|---|---|---|
| EMPTY | A or Start · Enter/Space (from an **unassigned** device) | join this slot → PICKING; goat = first goat not taken by another human (in slot order) |
| PICKING | Left/Right (D-pad, LS with repeat) · A/D or ←/→ | cycle goat (wraps), skipping only goats **locked (READY)** by another human; two PICKING players may browse the same goat |
| PICKING | Up/Down · W/S or ↑/↓ | move between the GOAT row and the FLAIR row of this panel |
| PICKING (FLAIR row) | Left/Right | cycle this slot's flair (NONE / unlocked items / locked tease shown greyed, can't be equipped) |
| PICKING | A · Enter/Space | lock → READY. If another human locked the same goat in the same frame, the lower slot wins and this panel gets a deny shake |
| PICKING | Y · R | random: the portrait spins 0.6 s through the free goats and lands; stays PICKING (A to lock) |
| PICKING | B · Esc/Backspace | leave → EMPTY (goat released, device unassigned) |
| READY | B · Esc/Backspace | un-ready → PICKING |
| READY | A or Start · Enter | if the READY banner is up (E.5): **proceed**. Otherwise nothing (soft tick) |
| any joined | LB / RB · Q / E | BRAWL: CPUs −/+ (0..8−humans; deny shake at the bounds). SPORTS/TRIALS: nothing |
| any joined | View · Tab | open RULES (E.7), owned by this device |
| any device | hold B 1.0 s · hold Esc | back to ModeSelect (ring fills on the footer's B chip; release cancels). Lobby is kept in GameConfig so coming back restores it |
| no slot joined | B · Esc (tap) | back to ModeSelect |

### E.5 Proceed rule and the READY banner
- **Valid roster:** ≥ 1 slot READY, **every** PICKING slot is READY (EMPTY and DISCONNECTED are ignored), plus a
  mode rule:
  - BRAWL: humans + CPUs ≥ 2.
  - SPORTS: humans ≤ format seats and each team's seats are not overfilled.
  - TRIALS: ≥ 1 human.
- Valid → banner **"READY TO FIGHT!"** (BRAWL) / "READY TO PLAY!" (SPORTS) / "READY TO FLY!" (TRIALS) plus a
  Start glyph. It must be visible for ≥ 0.35 s before a proceed press counts (guards double-tap).
- BRAWL with one human READY and 0 CPUs → banner slot shows an amber hint instead: "RB ADD A CPU, OR GRAB A
  FRIEND". Never a silent dead end.
- Proceed writes MatchConfig (E.2 compaction; RANDOM goats resolved here; `character_ids` = "bouncer"; `bot_count`
  = lobby_cpus or the Sports fill) → `shell.go_forward("arena")`. TRIALS/SPORTS keep today's routing to ArenaSelect
  (CharacterSelect.gd:372-396 logic moves here).

### E.6 Mode variants
- **BRAWL:** all 6 goats. Humans' goats are exclusive. CPU tray visible. CPUs take free goats via the existing
  `BrawlMode._bot_skin` (BrawlMode.gd:161-180). The tray previews exactly those heads, live.
- **SPORTS (ROCKETBALL/DROPSHOT):** the carousel offers **4 goats only**: POGO (pink) and BILLY (orange) = **RED**,
  BUTCH (blue) and VEX (purple) = **BLUE**. ZIGGY/PUFF are hidden. The panel shows a team ribbon (RED/BLUE)
  under the name. Format (1V1 / 2V2) is in RULES. 3-4 humans force 2V2 (existing rule, CharacterSelect.gd:391-392).
  Each team has 1 seat (1v1) or 2 seats (2v2). Goats of a full team are skipped for the remaining players. CPUs
  fill empty seats with the team's unused colourway. LB/RB do nothing. `SportsMode.spawn_plan` reads
  `team_ids` + human skins (replace the humans-first split at SportsMode.gd:233-241; keep the even-total clamp and
  the bot-level mirroring).
- **TRIALS:** all 6 goats, no CPU tray, no RULES (View glyph hidden), banner "READY TO FLY!".

### E.7 RULES panel (modal, owned by the device that opened it)
- A centred overlay 900×620 (`MatchEndPanel` stylebox) with a vertical list of existing **Stepper.tscn** chips:
  - BRAWL: CPUs (0..8−humans), CPU SKILL (MIX, 1-5), KOs TO WIN (5/7/8/10), LIVES (1/2/3).
  - SPORTS: FORMAT (1V1/2V2), CPU SKILL.
- Only the owner's device navigates it. Up/Down move, A edits, B cancels the edit (C-25), and B/View closes.
  Other panels keep working underneath, but their RULES requests are denied with a shake while it is open, and a
  chip reads "P2 IS SETTING RULES".
- The rules summary bar (E.9 layout, row 5) always shows the current values, so nobody has to open the panel just
  to read them.

### E.8 InputRouter autoload (new, `src/core/InputRouter.gd`, loaded via `load()` per the autoload gotcha)
- `device_key(e: InputEvent) -> String`: returns `"kb"` for InputEventKey, `"pad:%d" % e.device` for
  InputEventJoypadButton/Motion, and `""` for mouse.
- `last_device_kind: String` ("kb" | "pad"), updated in `_input`. Drives glyphs (C-23) and cursor hiding (C-26).
- `joined: Dictionary` (key → slot), mirrored from GameConfig.lobby. `is_joined(key)`.
- `joy_connection_changed` → emits `device_lost(key)` / `device_found(key)`. The lobby and PartyMatch subscribe.
- `rumble(key, weak, strong, dur)` (C-10).
- **Note for QA tooling:** simulated pads (`gbplay` gamepad command → `Input.parse_input_event`) are **not** in
  `get_connected_joypads()`. The router must key off events seen, never off enumeration. That is also what makes
  the lobby testable from gbplay with device 0/1/2.

### E.9 Layout (1920×1080 design space)
```
y=0    ┌──────────────────────────────────────────────────────────────────────────────────────────┐
       │ (B) BACK  [glyph chip]          CHOOSE YOUR GOAT  (64px)                 [ BRAWL ] chip    │  header 0-110
y=110  ├──────────────────────────────────────────────────────────────────────────────────────────┤
       │        [POGO] [BUTCH] [ZIGGY] [PUFF] [VEX] [BILLY]   [?]      roster ribbon               │  130-250
       │         P1•            P3•                                     medallions 140x110, gap 20  │  (P-badges on
y=250  ├──────────────────────────────────────────────────────────────────────────────────────────┤   locked goats)
       │ ┌────P1────────┐ ┌────P2────────┐ ┌──────────────┐ ┌──────────────┐                      │
       │ │ [pad] P1     │ │ [kb]  P2     │ │              │ │              │  4 panels 420x530    │  270-800
       │ │   ◀ (bust) ▶ │ │   ◀ (bust) ▶ │ │  (silhouette)│ │  (silhouette)│  x=72,524,976,1428   │
       │ │   POGO       │ │   BUTCH      │ │   PRESS (A)  │ │   PRESS (A)  │  gap 32              │
       │ │ "Can't stop  │ │ "Come at me" │ │   TO JOIN    │ │   TO JOIN    │                      │
       │ │  boinging."  │ │              │ │  ENTER = kb  │ │              │                      │
       │ │ FLAIR: NONE  │ │ FLAIR: CROWN │ │              │ │              │                      │
       │ │ [ READY! ]✓  │ │ (A) LOCK IN  │ │              │ │              │                      │
       │ └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘                      │
y=690  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  READY TO FIGHT!   (START)  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ← banner 1920x110,    │  overlays panel
y=800  ├──────────────────────────────────────────────────────────────────────────────────────────┤  bottoms, skew -3°
       │  CPUs  (LB) −  [ziggy CPU L3] [puff CPU L3] [vex CPU L3]  + (RB)        CPU tray           │  815-905
       ├──────────────────────────────────────────────────────────────────────────────────────────┤
       │  FIRST TO 10 KOs · 1 LIFE · CPU SKILL MIX                         (VIEW) RULES             │  920-990
       ├──────────────────────────────────────────────────────────────────────────────────────────┤
       │  (A) Join/Lock  (B) Back  (Y) Random  (START) Go           (hold B) Exit                   │  footer 1010-1060
y=1080 └──────────────────────────────────────────────────────────────────────────────────────────┘
```
Panel internals (420×530, top to bottom):
- Header strip 56 px: P-badge (cream until a goat is picked, then the goat's colour, 32 px "P2" chocolate outline)
  + device icon (Glyph `pad` / `kb`, 36 px), right-aligned.
- Bust well 280 px: `assets/ui/portraits/portrait_<id>.png` (exists for all 6). ◀ ▶ chevrons 48 px at the sides,
  vertically centred.
- Name banner 64 px: goat name 52 px in the goat's colour plate with a 5 px chocolate border (reuse
  `_set_banner_color` styling, CharacterSelect.gd:254-260). SPORTS adds a team ribbon.
- Blurb 2 lines at 28 px (HEROES blurb).
- FLAIR row 48 px: "FLAIR ◀ NONE ▶". It gets a gold ring when that row is the panel's active row.
- Status bar 60 px: PICKING = Glyph A + "LOCK IN". READY = a "READY!" stamp in white on green with a chocolate
  outline, rotated −6°, plus a check (reuse MenuCard `show_check` art).
- Panel plate: cream glass `StyleBoxFlat` (bg #FFF7EB at 0.92, border chocolate 5 px, radius 22). Once a goat is
  picked the border becomes the goat's colour at 6 px. READY adds an outer glow (shadow 24 px, goat colour at 0.5).
- EMPTY: plate at 0.55 alpha. Silhouette = the idle sprite modulated to `Color(0.23,0.14,0.11,0.25)`. "PRESS A TO
  JOIN" at 40 px, breathing 1.0↔1.05 at 0.8 s sine, with Glyph A, plus "ENTER" key cap if no slot has "kb" yet.
- DISCONNECTED: the bust greys out, the header reads "RECONNECT…" with a 10 s ring, plus "(A) ON ANY CONTROLLER
  TO TAKE OVER".

### E.10 Motion and audio (house grammar: overshoot then settle, never linear)
| Event | Motion | Sound |
|---|---|---|
| Join | panel scale 0.90→1.06→1.00 (TRANS_BACK out, 0.28 s); bust drops from y−80 with TRANS_BOUNCE 0.35 s; P-badge pops 1.4→1.0 | `ui_join` pitched by slot (P1 1.0, P2 1.12, P3 1.26, P4 1.41) |
| Cycle goat | reuse the whip-out/bounce-in (out 0.14 s TRANS_QUAD in + rot −12°; in 0.26 s TRANS_BACK out from scale 0.7, CharacterSelect.gd:211-227); the chevron on the pressed side nudges 8 px for 0.08 s; border recolours over 0.2 s | `ui_move` |
| Skip a taken goat | the medallion of the taken goat wiggles (MenuFX.reject_shake) | none (the move sound covers it) |
| Lock (READY) | bust hops −50 px (0.12 s QUAD out) then TRANS_BOUNCE back (0.28 s); stamp scale 2.0→1.0, rot −14°→−6° (TRANS_BACK, 0.22 s); roster medallion gets the P-badge (pop) | `ui_ready` + goat bleat |
| Un-ready | stamp fades and shrinks to 0.8 (0.12 s); border glow off (0.15 s) | `ui_back` |
| Leave | bust falls out of the bottom (0.20 s EASE_IN); plate dims to EMPTY (0.15 s) | `ui_back` (lower pitch) |
| Banner in | slides from x = −1920 to 0 (0.25 s TRANS_BACK out), then text breathes 1.0↔1.04 (0.6 s sine); hides by sliding right (0.18 s) | `ui_all_ready` sting |
| Deny | MenuFX.reject_shake on the panel | `ui_deny` |
| Hold-B exit | ring on the footer B chip fills over 1.0 s; ticks every 0.2 s rising | `ui_hold_tick` |

### E.11 Assets
**Already exist (reuse):** six portrait busts (`assets/ui/portraits/portrait_*.png`), idle sprites for silhouettes
and CPU heads (`assets/characters/bouncer_*_idle.png`), MenuCard (roster medallions at a smaller size, its
`show_check`), Stepper.tscn (RULES), `MatchEndPanel` stylebox (RULES plate), the ModeContextChip (header), the
Backdrop.
**Can be drawn in code, no art needed:** Glyph set (C-23), device icons (a pad outline and a key cap drawn
PadGlyph-style), READY stamp (StyleBox + label), banner band (StyleBoxFlat skewed via `transform`/rotation).
**Optional art ask (Art Director, non-blocking):** a painted "READY TO FIGHT!" ribbon (1920×140, transparent) and
an "empty slot" goat silhouette with a "?" sign. The screen must read fully with the code-drawn fallbacks.

### E.12 Implementation notes for the programmer
- The lobby screen does **not** use Godot's viewport focus for slots. Every panel control is `focus_mode = NONE`.
  `CharacterSelect._input(e)` (not `_unhandled_input`, so built-in focus never sees the event) maps the event with
  `InputRouter.device_key(e)` → slot → state handler, then calls `set_input_as_handled()`. The RULES overlay is the
  only place that uses viewport focus, and only while open, gated to its owner's device.
- Per-device direction repeat (C-21) is needed here: keep `held_dir[key]`, `t_next[key]`. Process LS motion per
  device with hysteresis.
- Keep `MenuScreen` as the base for enter/stagger/header/footer, but override `_unhandled_input` so `menu_back` is
  not handled globally on this screen (the slots own B).
- Auto-join: ModeSelect stores `InputRouter.last_device_key` when its card activates. Lobby `_ready` joins that key
  into slot 0 if the lobby is empty.
- `PartyMatch._spawn_player`: `InputHuman.for_device(cfg.human_devices[i])` when `human_devices.size() > i`, else
  the legacy path. `p.flair` = `cfg.flair_ids[i]` (replaces the `i == 0` rule at PartyMatch.gd:277-278; keep the
  Sports suppression).
- Delete: the HUMANS/BOTS steppers and the SettingsTray, `_pick_idx/_picked/_locked`, the P1Flag node, the
  accept_override launch hack, and ReadyPrompt (replaced by the banner).
- Parse gate after adding the `InputRouter` and `LobbySlot` class_names (CLAUDE.md).

### E.13 Rendered acceptance script (QA, gbplay; screenshots to `tools/out/wk/lobby_*.png`)
1. Enter from ModeSelect with keyboard Enter → slot 1 = P1 [kb] PICKING. Screenshot.
2. gamepad device 0 A → slot 2 P2 [pad] joins. gamepad device 1 A → slot 3 P3 joins. Screenshot (3 panels live,
   1 EMPTY).
3. All three cycle at the same time (kb D ×2, pad0 right ×1, pad1 left ×3). Each panel shows a different goat and
   no panel moved because of another's input. Screenshot.
4. P2 locks BUTCH. P3 cycles onto BUTCH: it is skipped, and the BUTCH medallion wiggles. Screenshot.
5. P1 B → leaves (EMPTY). P1 Enter → rejoins. P2 B → un-readies. Everyone locks → banner up. Screenshot.
6. pad1 Start → ArenaSelect. B → back to the lobby with all three READY (persisted). Screenshot.
7. Proceed → match. Verify pad0 drives P2's goat only, pad1 drives P3's only, keyboard drives P1's only
   (`eval` player positions after each device's input). HUD/name-tag colours = goat colours (C-08).
8. Mid-match, pad1 B (powerup) → **no pause** (C-01). pad0 Start → pause header "PAUSED · P2". pad1 A → ignored.
   pad0 A RESUME → P2's goat does not boost on resume (C-19).
9. Simulate a disconnect of pad1 (router test hook) → disconnect overlay → pad1 A → resume.

---

## F. Suggested backlog order (for the producer)
1. **C-01 + C-02 + C-19** (pause on Start only, swallow on resume). Small, kills the owner's #1 complaint today.
2. **C-05 + InputRouter (E.8)**: device keys, `for_device`, no keyboard sharing.
3. **C-03/C-04/C-17/C-29 + C-16/C-31**: the Herd Lobby (§E), Brawl first, then the Sports team-by-colourway variant.
4. **C-06 + C-07 + C-10**: pause owner, disconnect overlay, per-player rumble.
5. **C-08 + C-09 + C-15**: identity colour, persistent tags, HUD card count.
6. **C-14 + C-13 + C-18**: end-screen input gate, focus style swap, hold-to-confirm.
7. **C-11 + C-23 + C-21**: device-aware glyphs, keyboard parity, nav repeat.
8. **C-12 + C-20 + C-30**: Controls screen, pause and options content.
9. P2/P3 remainder.
