# BACKLOG — weekend polish run (owner: producer)

Ranked top-to-bottom. Seeded 2026-11-14 from the three audits in `docs/audit/2026-11-14_*` (C-xx controls/front-end,
R-xx rendered playthrough, D-xx game design) and the owner's verdict: *"kinda fun but... a shitty prototype with a lot
of weird things, nonsense controls (like b opens the pause menu on an xbox controller...) and the character select
totally doesnt make sense, 2 users using 2 controllers totally cant select their character like a normal game"*.
Standard: `docs/COUCH_CONVENTIONS.md` (CC-x.y). Procedure: `docs/WEEKEND_LOOP.md`. Rulings: `docs/DECISIONS.md` 2026-11-14.

## How to use (every loop tick)
1. Take the **first unchecked item** in the Next 10 (or 2-3 small related S items). Skip `BLOCKED`. Respect `Deps`.
2. Build -> verify RENDERED per its `Accept` line (keyboard AND simulated pads on >= 2 device ids) -> screenshots
   to `tools/out/wk/<ID>_*.png`, LOOKED at. UI items also need a ui-ux-designer Ship verdict vs COUCH_CONVENTIONS.
3. Mark the heading: `[x] ... — <commit hash>` on a pass; `[~] attempted — <one-line reason>` after 2 failed fix
   rounds (revert the item's files, move on). Never mark `[x]` on a builder's word: the Accept check must pass.
4. Items tagged **OWNER-RULED** touch an owner feel/rule decision (DECISIONS ruling (c)): the owner's value stays;
   only what *feeds* it may change, and the change gets a DECISIONS entry in the same commit.
5. Size L never gets pulled: it is already split below. If an item turns out bigger than its size, split it here
   first. Producer re-ranks after every creative-director cold playthrough (~every 6 items).

Legend: `[ ]` open · `[~]` attempted · `[x]` done · Size S = one pass, 1-2 files · M = one full slice · L = split it.

## Next 10
1. ~~WK-01~~ done 933a77a
2. ~~WK-02~~ done 933a77a
3. WK-03 InputRouter autoload + device keys + gbplay simulated-pad testability
4. WK-04 Each human driven by exactly one device (`InputHuman.for_device`, no keyboard sharing)
5. WK-05 Herd Lobby slice 1: press-A-to-join panels, independent goat cycling
6. WK-06 Herd Lobby slice 2: ready / banner / Start proceeds / devices carry into the match
7. WK-07 Herd Lobby slice 3: RULES panel + lobby persistence + CHANGE SETUP
8. WK-08 One player = one colour = their goat's colour, everywhere
9. WK-09 Pause menu finish: hold-to-confirm RESTART/QUIT + "PAUSED · P2" header
10. WK-10 Persistent P# pip over humans, CPU tags on bots

---

### [ ] WK-80 [P1][S] QA nits from WK-01 verification (focus restore, glyph unity, stray errors)
- Source: qa-playtester WK-01 pass 2026-11-14. Owner: gameplay-programmer + ui-ux-designer.
- (a) Backing out of a submenu must restore focus to the item that opened it: PauseMenu `_close_options` focuses
  RESUME (should be OPTIONS); MainMenu back-from-Options lands on PLAY; ModeSelect returns focus to TRIALS after
  B from CharacterSelect (should be the mode you came from) — players accidentally enter the wrong thing.
- (b) One START glyph style: legend uses charcoal pill, PauseMenu hint bar a cream "START" keycap — unify.
- (c) Options opened from pause should show "START Resume" in its hint bar; label pause-top B as "Resume".
- (d) `PowerupSystem.gd:255` "invalid previously freed instance" x10 from round_sweep at stage change — fix.
- (e) Painted backdrop doesn't reach screen edges (pale strips L/B on Daisy Ring, L/R on meadow).
- (f) Options: focus bar overlaps the "M" of MASTER VOLUME; from pause, Options BACK + hint bar overlap HUD cards.
- Accept: each sub-item screenshot-verified in tools/out/wk/WK-80_*.png; no PowerupSystem errors across 3 stages.

## P0 — broken normal couch play (controls, joining/selecting, roster)

> **SYSTEMIC — input/device model** (C-01..C-07, C-10, C-14, R-01, R-02, R-03, R-32): one global action map, one
> shared focus cursor, devices by `get_connected_joypads()` order. Fix is the InputRouter + Herd Lobby chain
> (WK-03 -> WK-07), not more per-screen patches. Any new input bug: check whether the router already owns it.

### [x] WK-01 [P0][S] Pause = Start/Esc/P only; B never pauses; pause owner gating; swallow-until-release on resume — 933a77a
- Sources: C-01, C-02 (action-map part: `pause`, `menu_start`, `menu_view`, `menu_random`+R), C-19, R-01; partial C-06 (owner device gating only)
- Area: brawl/trials/sports (all live matches) · Owner: gameplay-programmer · Deps: none
- Evidence: tools/out/cd_audit/20_padB_midmatch.png, 55_padB_with_powerup.png; PartyMatch.gd:986-991 (pre-fix)
- Files (uncommitted, in working tree): project.godot, PartyMatch.gd, PauseMenu.gd/.tscn, InputHuman.gd, ControlsLegend.gd, PadGlyph.gd, CharacterSelect.gd
- Accept (rendered): mid-match pad B with `held_powerup` set -> `paused=false` and powerup activates; pad Start -> PAUSED;
  Esc -> PAUSED; P -> PAUSED; pad1 opens pause, pad0 A/stick ignored, pad1 A resumes; A-resume -> goat does not boost
  on the first 10 frames; B-resume -> no powerup fires; super held through pause is not fired by resume; legend shows
  START glyph. Screens `tools/out/wk/WK-01_*.png`.
- Status: **built, rendered verification in progress**

### [x] WK-02 [P0][S] Roster cap = 4 fighters; HUMANS up lowers BOTS; HUD hides unused cards — 933a77a
- Sources: R-03, C-15 (hide part + out-of-bounds `skins[i]`), D-17 (cap part — see Deferred for 6-8 players)
- Area: menus/HUD · Owner: gameplay-programmer · Deps: none
- Evidence: tools/out/cd_audit/11_humans2.png, 17_launch_1.5s.png, 25_victory_settled.png ("BILLY P5" wins); MatchHUD.gd:32-34 (VERIFY error)
- Do: `MatchConfig.MAX_FIGHTERS = 4` (= HUD corners); current CharacterSelect: raising HUMANS lowers BOTS so total <= 4,
  BOTS max = 4 − humans; PartyMatch clamps `bot_count` defensively; MatchHUD hides cards i >= players.size(). The
  stepper coupling is throwaway once WK-06 lands; the cap constant is not (lobby CPU tray reads it — this
  overrides the audit's "CPUs 0..8−humans").
- Accept (rendered): default Brawl = 1H+3CPU, 4 cards; HUMANS->2 shows BOTS 2 -> match has 4 fighters, no P5 tag; 1H+1CPU
  Brawl shows exactly 2 HUD cards, no ghost "P1" cards, no script error in the log; BOTS cannot exceed 4−humans.
- Status: open

### [ ] WK-03 [P0][M] InputRouter autoload + device keys + simulated pads testable from gbplay
- Sources: C-05 (infrastructure), C-06/C-07/C-10/C-26 (enablers), audit §E.8
- Area: tooling/menus · Owner: gameplay-programmer · Deps: WK-01
- Do: `src/core/InputRouter.gd` (autoload via `load()`): `device_key(e)` (`kb` / `pad:N` by EVENT CLASS, CC-3.2),
  `last_device_key`, `last_device_kind`, `joined` registry + `is_joined()`, `device_lost/device_found` signals from
  `joy_connection_changed`, `rumble(key, …)` stub, and **test hooks** `simulate_device_lost(key)/found(key)` for QA.
  Keys off events seen, never enumeration (simulated pads are not in `get_connected_joypads()`). Replace
  `PartyMatch._device_key` / PauseMenu's inline copy with the router. Parse gate (new class_name).
- Accept (rendered): via gbplay, keyboard + `gamepad` device 0/1/2 presses -> `eval InputRouter.last_device_key` reads
  `kb`, `pad:0`, `pad:1`, `pad:2` in turn; keyboard after pad 0 is `kb` (not `pad:0`); `simulate_device_lost("pad:1")`
  emits the signal (eval a counter). WK-01 pause gating still passes (regression).
- Status: open

### [ ] WK-04 [P0][M] Each human is driven by exactly one device (`InputHuman.for_device`)
- Sources: C-05, C-04 (match half), R-02 (match half)
- Area: brawl/trials/sports · Owner: gameplay-programmer · Deps: WK-03
- Evidence: InputHuman.gd:45-56 (enumeration order, overflow humans share keyboard, P1 = pad0 + keyboard)
- Do: `MatchConfig.human_devices: PackedStringArray` + `human_labels: PackedInt32Array`; `InputHuman.for_device(key)`
  scopes to exactly that device; PartyMatch spawn uses it when `human_devices.size() > i`; legacy any-device path
  ONLY when `human_devices` is empty (cold boot / QA harness); delete the "share the keyboard" overflow.
- Accept (rendered): set `human_devices=["kb","pad:0","pad:1"]` via eval + 3 humans, start Brawl; drive each device in turn
  and `eval` positions: keyboard moves only P1, pad0 only P2, pad1 only P3 (0 cross-moves over 3 trials each);
  cold-boot Arena.tscn still drives P1 from any device.
- Status: open

### [ ] WK-05 [P0][M] Herd Lobby slice 1: press A/Enter to join, per-player panels, independent goat cycling
- Sources: C-03, C-04, C-34 ("CHOOSE YOUR GOAT"), C-21 (lobby per-device repeat), R-02, R-24, D-28 (join intent), CC-4.1/4.2/4.8
- Area: menus · Owner: ui-ux-designer (layout/motion) + gameplay-programmer · Deps: WK-03
- Do: audit §E.2 data model (`GameConfig.lobby`), §E.3 EMPTY<->PICKING, §E.4 join/cycle/leave rows, §E.9 layout (4 panels,
  roster ribbon, header, footer), §E.10 join/cycle motion; `_input` routing by device, all panel controls
  `focus_mode=NONE`; per-device D-pad/LS repeat (0.40/0.09 s, hysteresis 0.5/0.3); auto-join the device that
  confirmed the mode card. Build as `scenes/ui/HerdLobby.tscn` + `LobbySlot.tscn`, **not yet routed** (old
  CharacterSelect stays live so the tree remains playable) — WK-06 swaps the route.
- Accept (rendered, launch the scene directly): E.13 steps 1-3 — Enter -> P1 [kb] PICKING; pad0 A -> P2 joins; pad1 A -> P3 joins;
  all three cycle simultaneously and each panel shows a different goat, no panel moved by another device; B on a
  PICKING slot -> EMPTY. Screens `tools/out/wk/WK-05_*.png`; ui-ux-designer verdict vs CC-4.x, CC-5.1, CC-8.1.
- Status: open

### [ ] WK-06 [P0][M] Herd Lobby slice 2: lock/ready, exclusive goats, READY banner, Start proceeds, devices carry into the match
- Sources: C-03, C-04, C-17 (delete shared tray focus), R-02, R-24, CC-4.3/4.4/4.5, E.5, E.6 (Trials variant)
- Area: menus · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-04, WK-05, WK-02
- Do: PICKING<->READY, taken goats skipped + P-badge on roster medallion, same-frame lock tie -> lower slot wins + deny
  shake; READY banner (>= 0.35 s before proceed counts); BRAWL CPU tray on LB/RB · Q/E (0..4−humans) + solo hint "RB ADD
  A CPU, OR GRAB A FRIEND"; hold-B 1.0 s exit with ring; proceed compacts slots -> `human_count/human_devices/
  human_labels/skin_ids`. Trials variant (no CPU tray, "READY TO FLY!"). Sports keeps today's humans-first split
  until WK-27. Route ModeSelect -> HerdLobby; delete HUMANS/BOTS steppers, SettingsTray, `_pick_idx/_picked/_locked`,
  P1Flag, accept_override hack, ReadyPrompt. KILLS/LIVES/SKILL use MatchConfig defaults until WK-07.
- Accept (rendered): E.13 steps 4, 5, 7 — P3 cannot land on P2's locked BUTCH (medallion wiggles); B un-readies then leaves;
  banner appears only when all joined are READY; pad1 Start -> ArenaSelect -> match where pad0 drives only P2's goat,
  pad1 only P3's, keyboard only P1's (eval positions); solo: Mode -> A (lock) -> A/Start (go) = 2 presses; 1H+0CPU
  shows the amber hint, never a dead end; Trials + Rocketball still launch. Screens `tools/out/wk/WK-06_*.png`.
- Status: open

### [ ] WK-07 [P0][M] Herd Lobby slice 3: RULES panel, lobby survives round trips, CHANGE SETUP, per-mode rule memory
- Sources: C-17, C-25 (Stepper B reverts), C-29, R-13, R-16, R-26, CC-4.6/4.7, CC-10.3, E.7
- Area: menus · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-06
- Do: View/Tab opens RULES modal owned by the opener (BRAWL: CPUs, CPU SKILL, KOs TO WIN, LIVES; SPORTS: FORMAT,
  CPU SKILL), "P2 IS SETTING RULES" chip for others; always-visible rules summary bar; Stepper: A commits, B reverts;
  remembered rule set **per mode**; `GameConfig.lobby` persists Back-from-ArenaSelect (all READY), CHANGE SETUP
  (PICKING with goats + devices), REMATCH; add CHANGE SETUP to Pause; QUIT TO TITLE clears.
- Accept (rendered): E.13 step 6 (back from ArenaSelect -> all three still READY on the same devices); pad0 Tab/View opens RULES,
  pad1 input ignored inside it; edit KOs 10->7 then B -> reverts to 10; play Rocketball then open Brawl -> CPUs still
  3 (no leak); Pause -> CHANGE SETUP lands in the lobby with picks kept. Screens `tools/out/wk/WK-07_*.png`.
- Status: open

---

## P1 — obviously amateur next to Smash / Duck Game / TowerFall

> **SYSTEMIC — identity** (C-08, C-09, R-04, R-05, R-17, D-03, D-06): colour, tag and CPU labelling are driven by slot,
> not by the goat. WK-08 lands the shared `player_color()` first; every later identity item reads it.
> **SYSTEMIC — two visual languages** (R-11, R-22, R-28, R-12): in-match panels are dark-navy dev-look; WK-34/35 own it.

### [ ] WK-08 [P1][S] One player = one colour = their goat's colour, everywhere
- Sources: C-08, R-04, D-03 (design audit rated P0)
- Area: HUD/brawl · Owner: gameplay-programmer · Deps: none
- Evidence: tools/out/cd_audit/17_launch_1.5s.png, d23_brawl_play/f016_SCOREBOARD.png, d23_contact1.png ("P5 SURVIVES!" purple), 25_victory_settled.png
- Do: shared SKIN_COLORS table (CharacterSelect.gd:17-30 values) in `PlayerIdentity.gd`/CharacterProfiles;
  `PartyMatch.player_color(i)` from `players[i].skin`; replace every `PLAYER_COLORS[i]` read (HUD rims, tags, banners,
  FIRST BLOOD, match point, EdgeIndicators chevrons, ScoreScreen, VictoryScreen). Sports team skins follow automatically.
- Accept (rendered): P1=BUTCH(blue), P2=POGO(pink) + 2 CPU: name tag at pop-in, an off-screen chevron, a stage banner, the
  ScoreScreen row and the Victory row are blue for P1 and pink for P2 (5 screenshots).
- Status: open

### [ ] WK-09 [P1][S] Pause finish: hold-to-confirm RESTART/QUIT, "PAUSED · P2" header with goat head, context line
- Sources: C-18, R-09, C-20 (header/context; CONTROLS entry lands with WK-33), C-06 (header part), CC-6.1, CC-7.2
- Area: menus · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-01, WK-08 (colour); owner->player label via WK-04 (fallback kb->P1)
- Evidence: tools/out/cd_audit/29_quit_confirm.png, 30_after_quit.png, 31_back_at_menu.png (QUIT never fired; `_arm_gen` advances on press AND release)
- Do: `HoldButton` component (0.9 s, radial fill in owner colour, rising ticks, early release drains); replace the
  "REALLY?" double-press; header "PAUSED · P#" + portrait in owner colour; sub-line mode · arena · score.
- Accept (rendered): hold A 1.0 s on QUIT -> menu; release at 0.5 s -> still paused, ring drained; mashing A x6 never quits;
  pad1 pauses -> header reads P2/P3 per label in that goat's colour. Screens `tools/out/wk/WK-09_*.png`.
- Status: open

### [ ] WK-10 [P1][S] Persistent P# pip over every human; bots tagged CPU
- Sources: C-09, R-17, R-05 (pointer part), C-15 (label part), CC-8.3
- Area: HUD/brawl · Owner: gameplay-programmer · Deps: WK-08; uses `human_labels` from WK-04 when present
- Evidence: tools/out/cd_audit/21_after_resume.png (no tags after intro), 45_rocketball_1s.png (bot tagged "P2"), d56_contact.png
- Accept (rendered): 2H+2CPU Brawl at 10 s into combat: both humans show a 28-32 px "P#" pip in goat colour (~70 % alpha),
  full alpha 1 s after respawn; bots show "CPU" during intro only; HUD cards for bots read "CPU", never "P3".
- Status: open

### [ ] WK-11 [P1][S] End-screen input gate (fresh presses only, arm >= 1.0 s) + shared menus ignore unjoined devices
- Sources: C-14, C-06 (shell part), CC-3.3, CC-10.2; resolves D-09 "FLY skips" conflict (a FLY press only counts if it began after the screen appeared)
- Area: menus · Owner: gameplay-programmer · Deps: WK-03 (joined filter needs WK-06 for real data)
- Evidence: VictoryScreen.gd:234-235/311 (fast-forward arms instantly), PartyMatch.gd:74/849-850 (code, VERIFY rendered)
- Accept (rendered): hold pad A through the winning KO -> Victory does not REMATCH and ScoreScreen tally is not skipped;
  a fresh A after 1.0 s works; an unjoined pad2 cannot press REMATCH once a lobby exists.
- Status: open

### [ ] WK-12 [P1][S] First impression: every brawl arena gets a painted backdrop (Grassy Expanse first)
- Sources: R-08 (+ STATUS "grass arenas without a backdrop_painting show a plain sky")
- Area: art/brawl · Owner: level-designer · Deps: none
- Evidence: tools/out/cd_audit/17_launch_1.5s.png, 18_launch_3s.png, 26_rematch_1.5s.png vs 22_now.png
- Accept (rendered): screenshot Grassy Expanse at BOUNCE! shows the meadow painting, not flat grey-blue; grep confirms
  every brawl level JSON has `backdrop_painting`; spot-render 5 previously-bare arenas.
- Status: open

### [ ] WK-13 [P1][S] Mode select: BRAWL default focus, equal card heights, player-count chips
- Sources: R-18, D-29, C-35 · **OWNER-RULED**: card ORDER is owner-set (TRIALS, BRAWL, …) — keep it, change focus only
- Area: menus · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/03_modeselect.png
- Accept (rendered): fresh save -> ModeSelect focus on BRAWL; after playing Trials, focus = last-played; all 4 card art panels
  same height; chips read e.g. "2-4 VERSUS", "1-4 CO-OP", "1V1 / 2V2"; Trials has a "SOLO / CO-OP" sub-label.
- Status: open

### [ ] WK-14 [P1][S] Focus is singular: style swaps on focus, no permanently "primary" button
- Sources: C-13, R-21, CC-5.1
- Area: menus · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/30_after_quit.png (QUIT focused, RESUME still green)
- Accept (rendered): screenshots with focus on the LAST button of Title, Pause, Victory, Sports end row, Trials end row: exactly
  one element looks focused in each (shared `FocusRow` helper replaces the three `_set_focus` copies).
- Status: open

### [ ] WK-15 [P1][S] Teach the goal: controls legend on every mode's stage 1, rule line, honest BRAWL tagline
- Sources: C-12 (legend part), D-13a, D-04 (messaging part), CC-11.1
- Area: HUD · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-01 (legend glyphs)
- Do: legend out of the `wants_scoreboard()` gate, mode chips (Sports "HEADBUTT the ball", Trials "LAND on the pad");
  stage-1 StageIntroCard rule line "SMASH 'EM OFF-SCREEN · FIRST TO 10 KOs"; BRAWL tagline -> "Smash 'em off-screen.
  First to 10 KOs."; stage banner leads with KOs, survivor as sub-line.
- Accept (rendered): stage-1 screenshots of Brawl, Trials, Rocketball, Dropshot each show the legend; Brawl intro shows the rule line.
- Status: open

### [ ] WK-16 [P1][S] Sports: one goal/point banner, not two stacked headlines
- Sources: R-12
- Area: sports · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/46_rocketball_3.5s.png, d53_contact.png
- Accept (rendered): goal in Rocketball and point in Dropshot each show one scoring-team-coloured burst + score tick, nothing clipped by posts.
- Status: open

### [ ] WK-17 [P1][S] Bundle a real display font (OFL) — NOT blocked (DECISIONS ruling b)
- Sources: C-32, R-10, CC-12.3, STATUS "real FONT"
- Area: art/menus · Owner: ui-ux-designer (pick) + art pipeline (import) · Deps: none
- Do: OFL rounded heavy face (Fredoka / Baloo 2 ExtraBold / Lilita One) + licence file in `assets/fonts/`; theme default
  font replaces the SystemFont chain; check MenuCard auto-shrink and long labels.
- Accept (rendered): Title, Lobby/CharacterSelect, Pause, ScoreScreen, Victory screenshots all render the bundled face; no text overflow.
- Status: open

### [ ] WK-18 [P1][S] 28 px floor for anything a player reads
- Sources: C-27, R-10 (micro-text), R-25 (KO chip legibility), CC-8.1
- Area: menus/HUD · Owner: ui-ux-designer · Deps: WK-17
- Accept (rendered): theme tokens CardTag/CardName/HintStrip/ControlsLegend/FLAIR >= 28 px; screenshots of the 5 affected screens
  at 1080p show no overflow; KO meta chip readable.
- Status: open

### [ ] WK-19 [P1][S] Rumble goes only to the concerned player's pad
- Sources: C-10, R-32 (rumble part), CC-3.6
- Area: brawl · Owner: gameplay-programmer · Deps: WK-04 (player -> device)
- Accept: eval-log `start_joy_vibration` calls during 10 smashes in a 2-pad match: only the victim's/attacker's device id appears.
  (Rumble can't be seen; the call log is the evidence.) Options toggle lands in WK-44.
- Status: open

### [ ] WK-20 [P1][M] Brawl pacing: measure the +25 % knockback side effects, then fix what feeds sting/hitstun at Lv0
- Sources: D-18, R-07 (early KOs), DECISIONS 2026-07-19 watch item · **OWNER-RULED**: `dmg_launch_mult` array and hitstun triad
  constants do NOT change; only the impulse fed to the sting/escalation gate and hitstun at Lv0 (pre-multiplier) may.
  Needs a game-designer ruling + DECISIONS entry before building.
- Area: brawl · Owner: game-designer (ruling) + gameplay-programmer + qa-playtester · Deps: none
- Evidence: tools/out/cd_audit/b19_contact.png (2 deaths within ~6 s), d56_brawl_fast/log.json (P1 dead ~4 s in)
- Do: step 1 QA measurement (graze s<=0.15 on Lv0: damage_level, sting, hitstun; median time-to-first-death over 20
  stages). Step 2 only if graze stings/max-stuns: gate on `impulse_pre_mult` at Lv0, re-run lethality battery §9.
- Accept: graze on Lv0 -> damage_level 0, `_last_sting_applied` 0, hitstun ~0.48 s; centre hit unchanged; >= 50 % of Lv0
  non-edge smashes on victims with fuel >= 20 survived over 40 stages; rendered contact sheet of 3 recoveries.
- Status: open

### [ ] WK-21 [P1][S] Adaptive ScoreScreen hold (2.0 s normal, 3.4 s on lead change / match point)
- Sources: D-09, R-07 (dead time) · **OWNER-RULED**: ScoreScreen stays (owner 2026-07-16); `SCORE_HOLD` is the sanctioned knob; `round_end_freeze` and countdown untouched
- Area: brawl · Owner: gameplay-programmer · Deps: WK-11 (skip uses the fresh-press gate)
- Accept: median death->next-BOUNCE over 20 non-dramatic stages <= 5.0 s (was ~6.9 s); a lead-change stage holds 3.4 s (eval timestamps + screenshots).
- Status: open

### [ ] WK-22 [P1][S] KO blast sprite strip (art)
- Sources: D-01 (art half)
- Area: art · Owner: art pipeline (art-director brief) · Deps: none
- Accept: `assets/fx/ko_blast_*.png` strip, transparent, toybox style, approved by art-director on a rendered test frame.
- Status: open

### [ ] WK-23 [P1][M] Screen-edge KO blast in the victim's colour (the punchline becomes visible)
- Sources: D-01 (design audit rated P0), R-31 (KO blast-line part) · **OWNER-RULED**: camera rules untouched — presentation only
- Area: brawl · Owner: gameplay-programmer · Deps: WK-22, WK-08
- Do: `KOEdgeBlast` CanvasLayer on `KillPipeline.killed`; project death point onto viewport edge (EdgeIndicators math);
  top = star-KO twinkle, sides/bottom = column; <= 0.6 s, edge-anchored, never in the middle 60 %.
- Accept (rendered): 20 forced ring-outs across 3 arenas, all 4 edges, burst screenshots at +0.05 s and +0.3 s: 20/20 show a
  victim-coloured blast at the nearest edge.
- Status: open

### [ ] WK-24 [P1][S] Hits carry the attacker's colour (impact burst, knockback streak, last-touch ring)
- Sources: D-06, D-02 (part 2 last-touch tag)
- Area: brawl · Owner: gameplay-programmer · Deps: WK-08
- Accept (rendered): frame-grab 10 smashes: burst/streak hue = attacker colour 10/10; victim in credit window shows a thin
  attacker-coloured ring; streak value >= 0.8 (launch read kept).
- Status: open

### [ ] WK-25 [P1][M] KO credit pop (+1 flies to killer's card, −1 OOPS on self-fall) + ScoreScreen kill list
- Sources: D-02 (parts 1+3), R-27 (unlabelled "−1"), R-06 (score-visibility half) · **OWNER-RULED**: no persistent combat score — the pop is transient (<= 1.5 s)
- Area: brawl/HUD · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-23, WK-08
- Accept (rendered): 4-bot match, 30 deaths: every credited kill shows a killer-coloured +1 reaching the right card within 1.0 s,
  every uncredited death shows −1/+0 on the victim card (eval `scores` before/after, 0 mismatches); ScoreScreen lists
  "P2 ▶ P3" / "P4 SELF-KO −1".
- Status: open

### [ ] WK-26 [P1][S] Super-aim wind-up sound + "!" over the targeted goat
- Sources: D-07
- Area: brawl/audio · Owner: gameplay-programmer + sound-designer · Deps: none (bleat layer waits for WK-53 asset)
- Accept: `EventBus.super_aim_started` fires; `AudioManager.last_sfx == "super_aim"` on aim entry; 10 scripted aims -> "!" on
  the correct target >= 9/10 within 2 frames (rendered screenshots of 3).
- Status: open

### [ ] WK-27 [P1][M] Herd Lobby slice 4: Sports — picking the goat picks the team
- Sources: C-16 (sports half), C-31, R-14 (sports half), E.6
- Area: menus/sports · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-07
- Do: carousel = POGO/BILLY (RED), BUTCH/VEX (BLUE), team ribbon, full-team goats skipped; `MatchConfig.team_ids`;
  `SportsMode.spawn_plan` honours team_ids + human skins (keep even-total clamp, bot mirroring); CPUs fill seats.
- Accept (rendered): 2 humans pick POGO + VEX with 2 CPUs -> 2v2 with one human per team; the picked goat skins appear in
  the match (no repaint); 2 humans both RED -> 2 humans vs 2 CPUs.
- Status: open

### [ ] WK-28 [P1][M] Controller disconnect: auto-pause overlay in match, DISCONNECTED slot in lobby, connect toasts
- Sources: C-07, R-32 (toasts/disconnect), CC-3.4/3.5
- Area: brawl/menus · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-03, WK-06
- Accept (rendered, via `InputRouter.simulate_device_lost`): mid-match pad1 lost -> "P3 CONTROLLER DISCONNECTED" overlay in
  P3's colour; pad1 A resumes; unjoined pad2 A takes over P3; RESUME WITHOUT P3 works; in lobby the slot shows
  RECONNECT ring 10 s then EMPTY. Screens `tools/out/wk/WK-28_*.png`.
- Status: open

### [ ] WK-29 [P1][M] One device-aware glyph component (pad circles/pills, key caps) used everywhere
- Sources: C-23, R-23, C-11 (glyph half), CC-1.6/1.7
- Area: menus/HUD · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-03
- Accept (rendered): HintStrip, ControlsLegend, lobby panels, Trials hints show Xbox glyphs after pad input and key caps after
  keyboard input (screenshot pairs); no ASCII "(A)" or "< >" left (grep); Trials no longer says "HOLD A / SPACE".
- Status: open

### [ ] WK-30 [P1][S] Keyboard parity in menus (WASD nav, Q/E pages, prompts tell the truth)
- Sources: C-11 (bindings half), CC-2.1 (R/Tab/Enter already added in WK-01)
- Area: menus · Owner: gameplay-programmer · Deps: WK-01
- Accept (rendered): ModeSelect/ArenaSelect/Options fully navigable with WASD only; Q/E page the shelf; every footer prompt
  works on keyboard.
- Status: open

### [ ] WK-31 [P1][M] HUD card shows danger: damage-level state, labelled fuel, stocks when LIVES > 1
- Sources: R-06 (damage/lives half) · **OWNER-RULED**: no persistent KO score on cards (see Deferred)
- Area: HUD · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-08
- Accept (rendered): eval damage_level 0/1/2 on P1 -> card shows three distinct states; fuel bar has an icon; LIVES 3 shows 3 pips.
- Status: open

### [ ] WK-32 [P1][M] Make the goat pick real: wire CharacterProfiles OR declare cosmetic and rewrite blurbs
- Sources: D-10, C-16 (roster half), R-14 (roster half) · feel-adjacent: re-run the v2 feel-delta battery if wired
- Area: brawl · Owner: game-designer (decision) + gameplay-programmer · Deps: WK-20 (lethality baseline first)
- Accept: wired -> `players[i].profile` matches pick for 4 slots and no hero's self-fall rate > 1.5x Standard over 40 stages,
  stat pips visible in the lobby (screenshot); cosmetic -> blurbs rewritten as personality, DECISIONS entry.
- Status: open

### [ ] WK-33 [P1][M] CONTROLS screen (full move set, device glyphs) reachable from Pause and Options
- Sources: C-12 (screen half), C-20 (CONTROLS entry), R-22 (controls view), CC-11.1, CC-7.1
- Area: menus · Owner: ui-ux-designer · Deps: WK-29, WK-09
- Accept (rendered): Pause -> CONTROLS and Options -> CONTROLS open the same scene; shows "hold X to aim, release to fire",
  B returns one level; pad and keyboard glyph variants screenshotted.
- Status: open

### [ ] WK-34 [P1][M] Toybox panel kit A: Pause, in-match Options, ScoreScreen
- Sources: R-11, R-22 (pause BACK overlaps P1 card, v0.1 overlaps P4)
- Area: menus/art · Owner: ui-ux-designer · Deps: WK-17
- Accept (rendered): the three screens use the cream/chocolate frame + header ribbon + shell buttons; no dark-navy plate;
  nothing overlaps HUD cards. art-director/ui-ux verdict.
- Status: open

### [ ] WK-35 [P1][M] Toybox panel kit B: Victory final score, Trials objective banner, Sports scoreboard
- Sources: R-11
- Area: menus/art · Owner: ui-ux-designer · Deps: WK-34
- Accept (rendered): same kit on the three screens (screenshots); ui-ux verdict Ship.
- Status: open

### [ ] WK-36 [P1][M] Off-screen magnifier bubbles (watch the recovery live)
- Sources: D-05, R-30 · **OWNER-RULED**: camera framing untouched (owner rules 2026-07-10) — EdgeIndicators upgrade only
- Area: brawl/HUD · Owner: gameplay-programmer · Deps: WK-08
- Accept (rendered): player knocked 1500 px above top platform -> edge bubble with goat sprite + fuel ring within 10 % of
  `get_fuel_ratio()`; aim arrow shows within 1 frame of super aim off-screen.
- Status: open

### [ ] WK-37 [P1][M] Ghost goats: eliminated players float, quack and get one non-lethal heckle per stage
- Sources: D-08, R-07 (spectating half)
- Area: brawl · Owner: game-designer (spec) + gameplay-programmer · Deps: WK-04 (device per ghost); quack needs WK-53
- Accept (rendered): eliminated human's ghost moves from their device within 1.0 s; 40 % alpha, no flame; excluded from camera;
  heckle puff never credits a kill over 20 stages; option GHOSTS ON/OFF in RULES.
- Status: open

---

## P2 — visible polish gaps

### [ ] WK-38 [P2][S] Gate the 9090 automation server behind `--gb-dev` AND update run_game.ps1 in the SAME commit; version label only on title + Options
- Sources: C-28, CC-12.1, CC-8.4 · **WARNING**: landing the gate without `run_game.ps1` passing `-- --gb-dev` breaks gbplay and every later rendered QA — one commit, verify both
- Area: tooling · Owner: gameplay-programmer · Deps: none (do not interleave with a running QA session)
- Accept: `PLAY GOTTABOUNCE.bat` run -> nothing listening on 9090 (`netstat`); `tools/run_game.ps1` -> "Interaction server UP on 9090"
  and a gbplay screenshot succeeds; "v0.1" absent from ModeSelect/Lobby/ArenaSelect screenshots.
- Status: open

### [ ] WK-39 [P2][S] Hide the mouse cursor on pad/keyboard input and always in gameplay; hover focuses only after real motion
- Sources: C-26, CC-2.4, CC-12.2
- Area: menus · Owner: gameplay-programmer · Deps: WK-03
- Accept (rendered): screenshot mid-match shows no cursor; resting cursor over a sliding-in screen does not steal pad focus.
- Status: open

### [ ] WK-40 [P2][S] "B BACK" is a glyph chip, not a focus stop; fix ModeSelect back wiring
- Sources: C-24, CC-5.5, CC-5.2
- Area: menus · Owner: ui-ux-designer · Deps: WK-29 (glyph)
- Accept (rendered): pad focus never lands on a back button on ModeSelect/ArenaSelect/Options; mouse click on the chip goes back.
- Status: open

### [ ] WK-41 [P2][S] Between-stage overlays run in sequence; one prompt (countdown ring OR A); SELF-KO label
- Sources: R-27 (overlap + prompt; names go to WK-59, −1 label pairs with WK-25)
- Area: brawl/HUD · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/d24_brawl_to_end/f003_STAGE_INTRO.png, d56_brawl_fast/f008_STAGE_INTRO.png
- Accept (rendered): STAGE_END -> SCOREBOARD -> STAGE_INTRO burst shows no frame with two overlays at once.
- Status: open

### [ ] WK-42 [P2][S] Victory screen: hide combat HUD, consistent button copy/size, readable CPU name
- Sources: R-28
- Area: menus · Owner: ui-ux-designer · Deps: WK-14
- Evidence: tools/out/cd_audit/25_victory_settled.png
- Accept (rendered): no HUD corner cards on Victory; buttons equal width, "QUIT TO MENU" copy; winner name contrast >= 4.5:1.
- Status: open

### [ ] WK-43 [P2][S] Trials co-op polish: offset spawns, "GO!" not "FIGHT!", banner backplates, longer first lesson
- Sources: R-29
- Area: trials · Owner: level-designer + ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/39_trials_1s.png, 38_trials_circuits.png, 41_contact.png
- Accept (rendered): 2P course 1 spawns visibly apart; circuit confirm reads "GO!"; COURSE CLEAR has an outline/backplate; course 1 takes >= 4 s of flying for a human-style drive.
- Status: open

### [ ] WK-44 [P2][M] Options rebuild: aligned grid, RUMBLE toggle, SCREEN SHAKE (OFF/LOW/FULL), CONTROLS entry
- Sources: C-30, R-22, C-10 (toggle), R-32 (rumble option)
- Area: menus · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-19, WK-33
- Accept (rendered): rows aligned at the same x; toggles persist across relaunch (eval Settings); SCREEN SHAKE OFF -> zero trauma on a smash (eval).
- Status: open

### [ ] WK-45 [P2][S] Distinct UI sounds (move/confirm/back/deny/join x4/ready/all-ready/hold-tick)
- Sources: C-22, CC-9.1
- Area: audio · Owner: sound-designer · Deps: none · Note: source from the 34 existing samples first; any CC0 download needs the Director to extend DECISIONS ruling (b) to audio (not owner-blocked)
- Accept: each UI event sets a distinct `AudioManager.last_sfx` id (eval across ModeSelect/Lobby/Pause); join pitch rises P1->P4.
- Status: open

### [ ] WK-46 [P2][M] Menu nav repeat on held D-pad/stick + explicit LS axes on `ui_*`
- Sources: C-21 (global half; lobby half in WK-05), CC-5.3
- Area: menus · Owner: gameplay-programmer · Deps: WK-03
- Accept (rendered): holding pad right on ArenaSelect moves >= 5 cards in 1 s after 0.40 s delay; LS navigates with hysteresis (no double-steps).
- Status: open

### [ ] WK-47 [P2][S] Identity-colour rim on each goat body
- Sources: R-05 (rim part), R-04 (Smash-ring alternative) — sunset arena PUFF/BILLY confusion
- Area: brawl/art · Owner: gameplay-programmer + art-director · Deps: WK-08
- Accept (rendered): sunset arena with PUFF + BILLY: rims distinguishable at gameplay zoom (art-director verdict).
- Status: open

### [ ] WK-48 [P2][S] Dry-tank tell: jetpack sputters when fuel < super minimum
- Sources: D-19
- Area: brawl · Owner: gameplay-programmer · Deps: none
- Accept (rendered): eval fuel=3 -> sputter emitter visible; fuel=50 -> not.
- Status: open

### [ ] WK-49 [P2][S] Powerup name pop on pickup + a distinct activation sound per powerup
- Sources: D-20a
- Area: brawl/audio · Owner: gameplay-programmer + sound-designer · Deps: WK-08
- Accept: each of the 7 powerups sets a distinct `last_sfx`; pickup shows "STAR!" etc. in holder colour (3 screenshots).
- Status: open

### [ ] WK-50 [P2][S] Supercharge feedback (distinct spring SFX + gold ring burst)
- Sources: D-25a
- Area: brawl · Owner: gameplay-programmer · Deps: none
- Accept: supercharged bounce emits a distinct SFX id and a visible ring (burst screenshot).
- Status: open

### [ ] WK-51 [P2][M] Super contact reads as THE hit (bigger impact burst + screen flash)
- Sources: R-31 · **OWNER-RULED**: no camera punch-in (owner camera rules); hitstop duration is a feel constant — leave it unless game-designer rules
- Area: brawl · Owner: gameplay-programmer + art-director · Deps: WK-23, WK-24
- Accept (rendered): contact sheet of 5 super hits at gameplay zoom: impact readable from a downscaled 640x360 frame (CD verdict).
- Status: open

### [ ] WK-52 [P2][S] KO meta counts human KOs only and moves off the shared lobby; unlock toast becomes a banner card
- Sources: R-25, R-24 (toast part)
- Area: menus · Owner: gameplay-programmer + ui-ux-designer · Deps: WK-06
- Accept: all-bot match -> counter unchanged (eval); lobby shows no KO chip; unlock toast renders as a card with icon.
- Status: open

### [ ] WK-53 [P2][S] Taunt / quack (goat bleat per hero) — needs a bleat sample
- Sources: D-15 · Binding: pad Y [3] / keyboard per CC-2.2 (Y is unused in gameplay per CC-1.1)
- Area: brawl/audio · Owner: sound-designer + gameplay-programmer · Deps: none · Note: no bleat in assets/sfx; source/generate one (same ruling note as WK-45)
- Accept: taunt -> `last_sfx` starts "bleat_" within 1 frame in COMBAT and on ScoreScreen; 10 presses/s -> <= 3 sounds; "BAAA!" puff in colour (screenshot).
- Status: open

### [ ] WK-54 [P2][S] Rotating tips + per-player legend that holds until each human has used FLY and SUPER (cap 12 s)
- Sources: D-13b, D-13c, D-25b
- Area: HUD · Owner: ui-ux-designer · Deps: WK-15, WK-29
- Accept (rendered): fresh save, 2 humans: legend persists until both used FLY + SUPER (logged) or 12 s; tips suppressed after 3 matches.
- Status: open

### [ ] WK-55 [P2][M] Post-match awards from `round_stats` (HEADBANGER, KAMIKAZE, SNIPER, …)
- Sources: D-14
- Area: menus · Owner: game-designer + gameplay-programmer · Deps: WK-35, WK-11 (awards animate after arm, never delay REMATCH)
- Accept: every finished 4-player match shows 3 award cards whose stats match `round_stats` (eval spot-check 5 matches, screenshots).
- Status: open

### [ ] WK-56 [P2][S] Stall breaker by escalation (faster powerups at 20 s, golden bubble at 30 s)
- Sources: D-23, R-07 (sudden-death alternative) · **OWNER-RULED**: no timer may END a stage (owner 2026-07-03) — this only offers
- Area: brawl · Owner: gameplay-programmer · Deps: none
- Accept: scripted 1v1 no smashes 30 s -> golden bubble spawns at 30-31 s; stage-end causes unchanged.
- Status: open

### [ ] WK-57 [P2][M] Arena scorecard tool (10 bot stages per arena -> stage length, credited share, self-falls, min zoom)
- Sources: D-16a, R-05 (min camera zoom per arena = the lever that feeds the owner camera rule)
- Area: tooling · Owner: qa-playtester / tooling · Deps: WK-20 (lethality baseline)
- Accept: `tools/out/arena_scorecard.json` covers all 94 arenas with every metric populated.
- Status: open

### [ ] WK-58 [P2][M] Arena quality tiers + cull/retune pass
- Sources: D-16b, STATUS "~55 fresh arenas want a fun pass"
- Area: brawl/levels · Owner: level-designer · Deps: WK-57
- Accept: each circuit pool keeps >= 12 arenas passing (credited share >= 45 %, median stage <= 25 s); top picks get a human-style QA drive.
- Status: open

### [ ] WK-59 [P2][M] Arena hook line + player-facing names on the StageIntroCard
- Sources: D-16c, R-27 (dev-ish names "ISLANDS VOID", "GRASSY EXPANSE")
- Area: levels/HUD · Owner: level-designer · Deps: none
- Accept: 100 % of arena JSONs have a non-empty `hook`; stage intro screenshot shows name + hook.
- Status: open

### [ ] WK-60 [P2][S] ArenaSelect copy and layout fixes ("WAYS TO PLAY", "1 / 6", RANDOM card copy, empty lower half)
- Sources: R-20 (copy/layout half)
- Area: menus · Owner: ui-ux-designer · Deps: none
- Evidence: tools/out/cd_audit/14_arena_select.png, 15_arena_select_right.png
- Accept (rendered): screenshot shows corrected copy, no dead half-screen; ui-ux verdict.
- Status: open

### [ ] WK-61 [P2][M] Pick a single stage inside a circuit (circuits stay as playlists)
- Sources: R-20 (stage-pick half) · run `scope-check` first (adds a flow)
- Area: menus · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-60, WK-59
- Accept (rendered): choose circuit -> STAGE grid -> pick one arena -> match loads that arena; RANDOM ROTATION still works.
- Status: open

### [ ] WK-62 [P2][S] Team Brawl spec (2v2, co-op vs CPU, friendly fire) — spec only
- Sources: D-11 · touches the smash licence -> spec with QA criteria first; `scope-check` (new system)
- Area: brawl · Owner: game-designer · Deps: WK-07
- Accept: `docs/specs/` entry with QA criteria (0 teammate smashes with FF off, stage ends when one team left, team totals).
- Status: open

### [ ] WK-63 [P2][M] Team Brawl build
- Sources: D-11
- Area: brawl/menus · Owner: gameplay-programmer · Deps: WK-62, WK-27 (team UI pattern)
- Accept: spec criteria pass in a rendered 2v2 + a 2-humans-vs-2-CPU run (eval `round_stats`).
- Status: open

### [ ] WK-64 [P2][M] Scoring rule option KO RACE / SURVIVOR / HYBRID in RULES
- Sources: D-04 (rule half) · **OWNER-RULED**: default stays KO RACE; HYBRID-as-default is only a recorded candidate
- Area: brawl · Owner: gameplay-programmer · Deps: WK-07
- Accept: SURVIVOR -> survivor with 0 KOs gets +1 (eval); KO RACE byte-identical over a 10-stage parity run.
- Status: open

### [ ] WK-65 [P2][M] Painted court-select cards (Rocketball + Dropshot, 11 courts)
- Sources: R-15 (cards half) · art generation
- Area: art/sports · Owner: art pipeline + art-director · Deps: none
- Evidence: tools/out/cd_audit/44_rocketball_courts.png, 50_dropshot_4s.png
- Accept (rendered): court select screenshots show illustrated cards matching Brawl/Trials quality; art-director approval.
- Status: open

### [ ] WK-66 [P2][M] Court in-game art: tiled crackable Dropshot floor, goal net sprite, a real beach, frame-filling stadium
- Sources: R-15 (in-game half) · art generation
- Area: art/sports · Owner: art pipeline + level-designer · Deps: WK-65 (shared style)
- Evidence: tools/out/cd_audit/45_rocketball_1s.png, 51_dropshot_start.png, 52_dropshot_4s.png
- Accept (rendered): SUNSET BEACH shows a beach; floor tiles visibly crack; goals have a framed net; no letterbox frame.
- Status: open

---

## P3 — nice-to-have

### [ ] WK-67 [P3][M] Second keyboard player (KB-R scheme, `kb2` device key)
- Sources: C-33, CC-2.2 · Owner: gameplay-programmer · Deps: WK-06
- Accept (rendered): kb and kb2 join separate lobby slots and drive separate goats (eval positions).

### [ ] WK-68 [P3][S] Hold-View score glance + trigger alternate bindings (RT boost, RB super)
- Sources: C-36 · **OWNER-RULED**: on-demand only, never a persistent combat score · Owner: gameplay-programmer · Deps: WK-35
- Accept (rendered): holding View shows the corner score overlay, release hides; RT boosts.

### [ ] WK-69 [P3][S] Per-slot FLAIR row in each lobby panel (everyone can wear unlocks)
- Sources: D-30, E.4 FLAIR row · Owner: ui-ux-designer + gameplay-programmer · Deps: WK-06
- Accept (rendered): P2 equips GOLDEN JETSTREAM and their streak is gold in-match; Sports suppression kept.

### [ ] WK-70 [P3][S] Session tally across rematches ("TONIGHT'S CHAMPION")
- Sources: D-22 · Owner: gameplay-programmer · Deps: WK-07
- Accept: 3 rematches won by blue -> 3 trophies on blue on Victory; relaunch clears.

### [ ] WK-71 [P3][S] ITEMS switch (OFF/LOW/NORMAL/HIGH) in RULES
- Sources: D-20b · Owner: gameplay-programmer · Deps: WK-07
- Accept: ITEMS OFF -> 0 bubbles over 10 stages (eval).

### [ ] WK-72 [P3][M] Bot powerup brain v1 (detour to nearby bubbles, shield vs aimed super)
- Sources: D-20c, D-26 (part) · Owner: gameplay-programmer · Deps: WK-26 (aim signal)
- Accept: L4 bots collect >= 40 % of bubbles in all-bot matches; motion-health clean.

### [ ] WK-73 [P3][M] Match variants (MOON GRAVITY, TINY GOATS, …) as per-match Tuning overrides
- Sources: D-12 · **OWNER-RULED**: hard deny-list (hitstun triad, super impulse, fuel_per_bumper, dmg_launch_mult); `scope-check` (new system)
- Owner: game-designer + gameplay-programmer · Deps: WK-07
- Accept: MOON GRAVITY -> `Tuning.gravity == 960`, quit restores 1600; loader rejects a JSON naming `hitstun_base`.

### [ ] WK-74 [P3][S] Handicap (STURDY) + optional CROWN BOUNTY
- Sources: D-21 · scoring option, default off · Owner: gameplay-programmer · Deps: WK-07
- Accept: STURDY -> `eff_knockback_taken() == 0.90`; bounty KO adds 2 (eval).

### [ ] WK-75 [P3][M] Head-on super CLASH
- Sources: D-24 · touches the smash licence -> spec first · Owner: game-designer + gameplay-programmer · Deps: WK-20
- Accept: 10/10 scripted head-on super pairs CLASH with damage_level unchanged; lethality criteria 6 a-d still pass.

### [ ] WK-76 [P3][M] Bot personalities (per-bot skill, hero playstyle bias, hero names)
- Sources: D-26 · Owner: gameplay-programmer · Deps: WK-07
- Accept: L4 beats L2 >= 70 % over 10 all-bot matches; bot tag shows hero name.

### [ ] WK-77 [P3][M] Expression overlays (DIZZY/PANIC/SMUG) x6 + pending super-aim pose x6
- Sources: D-27, STATUS "super-aim pose x6" · art generation · Owner: art pipeline + art-director · Deps: none
- Accept (rendered): frame grabs show DIZZY during hitstun on all 6 skins.

### [ ] WK-78 [P3][M] BRAWL SCHOOL trials circuit (teaches smash-to-ring-out, stomp, finishing)
- Sources: D-25c · new content -> `scope-check` · Owner: level-designer · Deps: WK-15
- Accept: 4 courses complete via injected human-style input; rendered screenshots.

### [ ] WK-79 [P3][S] Audio mix pass (loudness numbers, menu vs hit weight)
- Sources: R-33 · Owner: sound-designer · Deps: WK-45
- **BLOCKED (partial):** the subjective "does it sound good" judgment needs a human ear; do the numeric loudness/headroom part only.
- Accept: per-bus loudness report; no SFX clipping; music ducks under KO stings (eval bus levels).

---

## Done (recent)
_(none yet — first commit of the run will be WK-01)_

## Deferred / Cut (this weekend) — every finding not covered by an item above
- **R-07 (default 3 stocks / sudden-death squeeze)** — owner rulings: LIVES default 1, KILLS 10, no timer sudden-death. Mitigated by WK-20/21/37/56; LIVES stays selectable in RULES (WK-07).
- **R-05 (raise the minimum zoom)** — owner camera rules 2026-07-10. Mitigated by WK-10 (pip), WK-47 (rim), WK-36 (bubbles), WK-57/58 (cull arenas that force tiny zoom).
- **R-30 (soft ceiling / top bound)** — changes bounds/framing under owner camera rules; WK-36 magnifier instead.
- **R-31 (camera punch-in on super hit)** — owner camera rules; the rest of R-31 is WK-51.
- **R-18 (put BRAWL first in the row)** — owner set the ModeSelect order; default focus moves to BRAWL instead (WK-13).
- **R-19 (unlock all circuits in versus)** — owner ruling 2026-07-16 (`FREE_CIRCUITS = 3`, 4+ locked). Reopen only on owner reversal.
- **R-06 (in-combat KO tally / leader crown on cards)** — owner ruling 2026-07-16 (no persistent combat score). Transient credit pop = WK-25; damage/lives = WK-31.
- **D-17 / C-15 (6-8 player HUD + 2 more skins)** — capped at 4 fighters (WK-02): needs 2 new skins (art) + compact HUD + ScoreScreen row sizing. Revisit after the lobby ships.
- **D-28 (warm-up pen behind the lobby)** — L, new system; only after WK-05..07 ship and a CD pass asks for it.
- **D-31 (new powerups)** — widening; after WK-49/71/72 make the existing 7 read.
- **D-04 (HYBRID scoring as default)** — needs owner reversal; recorded as a candidate only (option ships in WK-64).
- **D-29 (freeze sports widening)** — adopted as policy, no item.
- **R-28 (winner podium with 2nd-4th poses)** — nice-to-have, needs pose art; cut this weekend.
- **R-22 (Video / Language tabs)** — no localisation planned; fullscreen already exists; cut.
- **C-16 note to CD (blurbs promise traits)** — handled by the WK-32 decision.

## Coverage index (source -> item)
C-01 01 · C-02 01 (usage in 05-07) · C-03 05,06 · C-04 05,06,04 · C-05 03,04 · C-06 01,09,11 · C-07 28 · C-08 08 · C-09 10 ·
C-10 19,44 · C-11 29,30 · C-12 15,33 · C-13 14 · C-14 11 · C-15 02 (+Deferred) · C-16 27,32 · C-17 06,07 · C-18 09 · C-19 01 ·
C-20 09,33 · C-21 05,46 · C-22 45 · C-23 29 · C-24 40 · C-25 07 · C-26 39 · C-27 18 · C-28 38 · C-29 07 · C-30 44 · C-31 27 ·
C-32 17 · C-33 67 · C-34 05 · C-35 13 · C-36 68
R-01 01 · R-02 05,06,04 · R-03 02 · R-04 08,47 · R-05 10,47 (+Deferred) · R-06 25,31 (+Deferred) · R-07 20,21,37,56 (+Deferred) ·
R-08 12 · R-09 09 · R-10 17,18 · R-11 34,35 · R-12 16 · R-13 07 · R-14 27,32 · R-15 65,66 · R-16 07 · R-17 10 · R-18 13 (+Deferred) ·
R-19 Deferred · R-20 60,61 · R-21 14 · R-22 34,44 (+Deferred) · R-23 29 · R-24 05,06,52 · R-25 18,52 · R-26 07 · R-27 41,25,59 ·
R-28 42 (+Deferred) · R-29 43 · R-30 36 (+Deferred) · R-31 23,51 (+Deferred) · R-32 19,28,44 · R-33 79
D-01 22,23 · D-02 24,25 · D-03 08 · D-04 15,64 (+Deferred) · D-05 36 · D-06 24 · D-07 26 · D-08 37 · D-09 21,11 · D-10 32 ·
D-11 62,63 · D-12 73 · D-13 15,54 · D-14 55 · D-15 53 · D-16 57,58,59 · D-17 02 (+Deferred) · D-18 20 · D-19 48 · D-20 49,71,72 ·
D-21 74 · D-22 70 · D-23 56 · D-24 75 · D-25 50,54,78 · D-26 76,72 · D-27 77 · D-28 05 (+Deferred) · D-29 13 · D-30 69 · D-31 Deferred
