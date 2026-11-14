# Rendered playthrough audit (Creative Director / Player Advocate), 2026-11-14

**Build:** branch `weekend/polish` @ 11bb63f. Rendered 1280x720 window (design res 1920x1080).
**Method:** I booted cold and played it the way a first-time couch group would: title, modes, character select (1P and two simulated pads), arena select, a full Brawl match to the victory screen, rematch, pause, options, quit, then Trials, Rocketball and Dropshot. Input was simulated Xbox pads (`gamepad` device 0/1), real key events, and a crude human-style driver (chase the nearest rival, hold boost, tap super when close). I looked at every screenshot.
**Evidence root:** `tools/out/cd_audit/` (numbered stills, `d*_` driven-play folders, `*_contact.png` contact sheets of motion).

**Simulation limits (be honest about these):** a virtual pad is not "connected" (`Input.get_connected_joypads()` is empty), so I could test the 2-pad **character select** but not per-pad control **in a match** (both humans fell back to the keyboard). I did not listen to audio. I only confirmed music is playing (`gameplay_4.mp3`).

Owner's verbatim complaint, which this audit confirms in full: *"nonsense controls (like b opens the pause menu on an xbox controller) ... 2 users using 2 controllers totally cant select their character like a normal game."*

---

## P0: breaks normal couch play

### R-01 Pad B opens pause, the POWERUP button can't be used on a controller, and START does nothing
- **Severity:** P0 · **Where:** every live match (all modes)
- **What a player experiences:** The in-match legend says **(B) POWERUP**. A player picks up a powerup, presses B, and the whole game freezes on the PAUSED menu. The powerup is never used. Pressing B again resumes, so a player will keep pausing everyone on the couch over and over. START, the button every player reaches for to pause, does nothing.
- **Evidence:** `20_padB_midmatch.png` (B mid-match opens PAUSED; the legend in `17_launch_1.5s.png` says B = POWERUP). `55_padB_with_powerup.png`: I gave P1 `held_powerup='mega_bounce'` and pressed pad B. Result: `paused=true`, the powerup was still held and `active_powerup` stayed empty. Bindings dump: `menu_back = [Escape, Joypad 1]` and `use_powerup = [L, Joypad 1]`. Joypad 6 (Start) is bound to nothing. I pressed Start during COMBAT and `paused=false`.
- **Suggested direction:** Every console party game works the same way. START (and optionally Back/View) pauses. B is a gameplay button during a match. B means "back" only in menus. Split `menu_back` into a menu-only action plus a `pause` action (Start/Esc), and make sure nothing gameplay-bound shares a button with pause.
- **Size:** S

### R-02 Character select is one shared cursor taking turns, not "each controller picks its own fighter"
- **Severity:** P0 · **Where:** Character select (all modes)
- **What a player experiences:** The second friend picks up pad 2 and presses A. That locks **P1's** character. There is no "press A to join". There's one cursor, one big portrait, and a prompt that reads "P2 — PICK YOUR GOAT", and whoever presses next drives that cursor. Nothing ties a controller to a slot. In the match, pads go to slots by **connect order** (`InputHuman.for_human`), with no link to who picked what. So the friend who picked Vex may end up flying Puff. P1's lock is shown only as a small check mark, and the big portrait always shows whoever picked last.
- **Evidence:** `05_pad1_pressA_lockedP1.png` (pad device 1 pressed A, banner says "P1 READY — (A) FIGHT!", `human_count` still 1). `12_p1_locked_p2_turn.png` (P2's cursor starts on P1's already-taken card). `13_both_locked.png` (one portrait, P1's pick only a check). Code: `CharacterSelect._lock_in` uses a single `_pick_idx`, and `InputHuman.for_human` assigns `pads[index]` with no record of the picker's device.
- **Suggested direction:** Smash/Brawlhalla/Duck Game model. Show four player panels along the bottom, each "Press (A) to join". Each joined device gets its own colored cursor/token and moves it on its own. Its panel shows its fighter and a READY state. B un-readies, then leaves. The device that joined slot N **is** slot N in the match. The human count comes from who joined, so the HUMANS stepper goes away. Empty slots offer "add CPU".
- **Size:** L

### R-03 Raising HUMANS doesn't lower BOTS, so the default 2-player couch game has 5 fighters and a P5 with no HUD
- **Severity:** P0 · **Where:** Character select, then Brawl match
- **What a player experiences:** Two friends set HUMANS to 2. BOTS stays at 3, so they get a 5-fighter free-for-all. The HUD has only four corners, so P5 has no card. P5 is labeled purple but plays as orange Billy, and P5 is the one who wins. "Who is P5?" was the experience of my first couch match.
- **Evidence:** `11_humans2.png` (HUMANS 2 / BOTS 3). `17_launch_1.5s.png` (a P5 nametag on the field, four HUD cards). `d23_brawl_play/f016_SCOREBOARD.png` (P1..P5). `25_victory_settled.png` ("BILLY P5" wins).
- **Suggested direction:** Make the total roster explicit (max 4). Bots fill the empty seats automatically and drop as humans join (this is solved by R-02's join model). Never allow more fighters than HUD slots.
- **Size:** S

---

## P1: obviously amateur

### R-04 Player color identity is broken everywhere (slot color ≠ character color)
- **Severity:** P1 · **Where:** HUD cards, nametags, score screen, banners, victory
- **What a player experiences:** I picked yellow Puff, and my HUD card, nametag and score bar are **pink**. Purple Vex is "blue P2". Blue Butch is "green P3". Orange Billy is announced as "**P5 SURVIVES!**" in purple. On a busy screen you track yourself by color, and here the colors point the wrong way.
- **Evidence:** `17_launch_1.5s.png`, `d23_brawl_play/f016_SCOREBOARD.png` (every row's icon color differs from its bar color), `d23_contact1.png` ("P5 SURVIVES!" in purple), `25_victory_settled.png`.
- **Suggested direction:** Pick one identity system. Either the HUD, tags and bars use the **character's** color (Duck Game), or every slot gets an unmissable slot color as a ring/outline on the character too (Smash's P1-red, P2-blue). Never show both.
- **Size:** M

### R-05 Fighters are tiny on screen and you lose yourself
- **Severity:** P1 · **Where:** Brawl (and the zoomed-out Trials courses)
- **What a player experiences:** Camera zoom sits at about **0.46**, so an 88px body is about 40px tall at 1080p, and that's from a couch across the room. Nametags fade after the intro, so with 4-5 similar round blobs I kept losing which one was me. In the sunset arena, yellow Puff and orange Billy look the same.
- **Evidence:** `d56_contact.png` and `d23_contact0.png` (fighters are specks). Live eval: `_camera.zoom = 0.4588`. `21_after_resume.png` (no tags after the intro).
- **Suggested direction:** Smash keeps a persistent small "P1" pointer over each human. TowerFall uses single-screen arenas sized to the characters. Keep a slot-colored pointer over every human at all times, and either shrink the arenas or raise the minimum zoom so a fighter is about 70-90px at 1080p. Add a stronger outline/rim in the slot color.
- **Size:** M

### R-06 The HUD doesn't show the things that decide the fight (damage, lives, score)
- **Severity:** P1 · **Where:** Brawl HUD
- **What a player experiences:** Each corner card is a portrait plus one unlabeled bar (fuel). There's no damage readout, even though knockback now scales +25%/+66%/+108% per damage level. There's no lives or stock count and no KO score during combat, because score pips were removed. A new player can't tell "I'm about to die" from "I'm fine", or who's winning, until the between-stage score screen.
- **Evidence:** `17_launch_1.5s.png`, `22_now.png` (cards are bar-only). `src/ui/PlayerCard.gd` header ("SCORE PIPS REMOVED").
- **Suggested direction:** Smash shows % plus stocks. Brawlhalla shows a damage color plus stocks. Show the damage state on the card (color/crack stages that match `damage_level`) and a small KO tally or crown on the leader. Label or iconify the fuel bar.
- **Size:** M

### R-07 Brawl pacing: humans get knocked out within seconds, then spectate long bot-only endgames
- **Severity:** P1 · **Where:** Brawl (default KILLS 10 / LIVES 1)
- **What a player experiences:** In the very first stage, idle human P2 and a bot were dead about **5 s** after BOUNCE!, before a real player would have found the buttons. My human-style P1 usually lasted 4-11 s per stage. Then I watched: one stage with two players left ran about **35 s**, mostly with them off the top of the screen as edge chevrons. Getting knocked out early and waiting is the loop, and that kills "one more round".
- **Evidence:** `b19_contact.png` (P2 and P3 skulls within about 6 s of the match start). `d56_brawl_fast/log.json` (P1 dead about 4 s into the stage). `d23_contact0.png`/`d23_contact1.png` (35 s endgame with players off-screen). `round_stats`: "Grassy Expanse" 11.3 s.
- **Suggested direction:** Either use TowerFall-style short rounds on compact single-screen arenas with an instant reset, or use Smash-style stocks (3) with respawn so humans keep playing. Add a sudden-death squeeze (shrinking bounds/hazard) after about 20 s with ≤2 alive. Give dead players something to do (Duck Game spectator taunts, Brawlhalla ghost/bombs). Default LIVES 1 with KILLS 10 is the worst of both models.
- **Size:** M (design + tuning)

### R-08 The first Brawl arena players see (and every rematch) is a flat grey-blue void
- **Severity:** P1 · **Where:** Meadow Mile stage 1 "Grassy Expanse" (and the rematch)
- **What a player experiences:** The opening shot of the headline mode is thin platforms over a flat grey-blue fill with one cloud. Stage 2+ have painted backdrops, so this one looks unfinished by comparison. REMATCH puts you back on it.
- **Evidence:** `17_launch_1.5s.png`, `18_launch_3s.png`, `26_rematch_1.5s.png`. Compare `22_now.png` (painted meadow).
- **Suggested direction:** Every arena gets a backdrop painting (STATUS already notes "grass arenas without a backdrop_painting show a plain sky"). Fix the first one first, because it's the first impression.
- **Size:** S

### R-09 Pause-menu QUIT/RESTART confirm is unreliable, so players get stuck in the pause menu
- **Severity:** P1 · **Where:** Pause menu
- **What a player experiences:** QUIT TO MENU turns into "REALLY?" and reverts after 1.5 s. I pressed A again about 0.3-0.5 s later, four separate times, and it never quit. A quick double-tap with the button held finally worked. A tracing eval shows `_arm_gen` advancing on both press-down and release, so each physical press arms and disarms. A player will conclude QUIT is broken.
- **Evidence:** `29_quit_confirm.png` ("REALLY?"), `30_after_quit.png` and `31_back_at_menu.png` (still paused after repeated presses).
- **Suggested direction:** Use a real modal ("Quit to menu? Yes / No", No focused), or hold-to-confirm with a fill bar (Smash uses a hold-to-quit pattern). Whatever you choose, trigger on one edge only.
- **Size:** S

### R-10 Fonts are OS system fonts, plus unreadable micro-text
- **Severity:** P1 · **Where:** Everywhere
- **What a player experiences:** The theme font is a `SystemFont` chain ("Arial Rounded MT Bold", "Segoe UI Black", "Arial Black", "Verdana"). It renders as a generic heavy sans that doesn't match the chunky candy logo, and it will look different on every PC and Steam Deck. The KO meta chip "48 KOs — NEXT FLAIR AT 50" is too small and compressed to read even at 1080p.
- **Evidence:** `assets/ui/theme.tres` line 4. `04_charselect.png` (KO chip), `20_padB_midmatch.png` ("PAUSED" in a default-looking sans).
- **Suggested direction:** Bundle one licensed display font (rounded, chunky, with an outline) and one UI body font as .ttf/.otf in `assets/fonts`. Set a minimum on-screen size of about 28px at 1080p for any text a player must read.
- **Size:** S-M

### R-11 Two unrelated visual languages: cream toybox menus vs dark-navy debug-ish panels
- **Severity:** P1 · **Where:** Pause, Options, Score screen, Victory final-score, Trials objective banner, Sports scoreboard
- **What a player experiences:** The front end is cream cards with chocolate outlines. Then every in-match panel is a dark navy rounded rectangle with a thin white border, a generic dev-tool look. It feels like two different games.
- **Evidence:** `20_padB_midmatch.png`, `27_pause_options.png`, `d23_brawl_play/f016_SCOREBOARD.png`, `40_trials_3.5s.png`, `25_victory_settled.png`.
- **Suggested direction:** One panel and button kit, used everywhere: the toybox style, with the same frame, header ribbon and button set.
- **Size:** M

### R-12 Sports goal/point banners stack two headlines on top of each other
- **Severity:** P1 · **Where:** Rocketball, Dropshot
- **What a player experiences:** On a goal, a white "GOAL!" appears and, under it, a giant blue "GOAL!  RED 0 — 1 BLUE" that runs edge to edge and clips the court posts. Dropshot does the same with "POINT!". It reads as a bug.
- **Evidence:** `46_rocketball_3.5s.png`, `d53_contact.png` (POINT! frame).
- **Suggested direction:** Show one celebratory banner (Rocket League's GOAL! burst in the scoring team's color), then a scoreboard tick.
- **Size:** S

### R-13 Match settings on the character screen are confusing and fiddly
- **Severity:** P1 · **Where:** Character select settings tray
- **What a player experiences:** "KILLS 10" and "LIVES 1" are shown side by side, and it's not clear which rule wins. "BOT SKILL: MIX" is unexplained. A stepper needs A to enter edit mode before left/right works, and pressing right on a focused stepper just jumps to the next one with no arrows shown. While you edit, the hint bar still says "(A) Ready". In Trials the tray is a large empty dark slab holding one stepper.
- **Evidence:** `04_charselect.png`, `08_focus_settings.png`, `09_humans_right.png` (right moved focus, value unchanged), `11_humans2.png`, `35_trials_charselect.png`.
- **Suggested direction:** Move rules to a separate "Rules" panel (Smash) or a compact "FFA · 3 stocks · CPU Normal" summary chip that opens it. Left/right should change values directly on focus, with arrows always visible. The hint bar should be context-aware.
- **Size:** M

### R-14 Character choice is pointless in Sports, and characters are only recolors
- **Severity:** P1 · **Where:** Rocketball/Dropshot character select; roster overall
- **What a player experiences:** In Rocketball I picked Pogo, and the mode then repaints everyone in team colorways (SportsMode overrides skins). The screen asks for a choice it then ignores. Across modes, every fighter is `character_id = "bouncer"` with a different skin and a joke blurb, with no stats or traits shown. The "pick your character" moment carries no weight.
- **Evidence:** `43_rocketball_cs.png`, `45_rocketball_1s.png`. `CharacterSelect._lock_in` forces `chars[_pick_idx] = "bouncer"`.
- **Suggested direction:** For Sports, replace character select with a team-pick screen (Rocket League's join-blue/orange) or keep the character and add a team-color ring. For the roster, either commit to "cosmetic only" and say so (Duck Game hats), or give each goat one small readable trait (size/weight/boost) shown as 2-3 stat pips.
- **Size:** S (sports flow) / M (traits)

### R-15 Sports/Dropshot presentation looks placeholder
- **Severity:** P1 · **Where:** Court select + Rocketball/Dropshot arenas
- **What a player experiences:** Court cards are dim, near-identical gameplay screenshots with an empty white strip under the name. Next to the illustrated Brawl/Trials cards they look unfinished. "SUNSET BEACH" shows a night stadium, and in-game "Dropshot Beach" is a night stadium too. The Dropshot floor is flat beige rectangles with dark seams. The courts float inside a solid blue or teal-to-khaki letterbox frame. Rocketball goals are thin outlined grid rectangles, and the court floor is a meadow grass strip inside a stadium.
- **Evidence:** `44_rocketball_courts.png`, `50_dropshot_4s.png` (which is the Dropshot court select), `45_rocketball_1s.png`, `51_dropshot_start.png`, `52_dropshot_4s.png`.
- **Suggested direction:** Give courts painted card art like the brawl circuits. Use a real beach for "beach" courts. Make tiled floor art that cracks visibly (the crack mechanic exists, see `d53_contact.png`). Make the stadium fill the frame edge to edge, and give the goals a 3D-ish net/frame sprite.
- **Size:** M

### R-16 Settings leak between modes
- **Severity:** P1 · **Where:** Character select after playing Sports
- **What a player experiences:** After one 1v1 Rocketball, opening Brawl defaults to **BOTS 1**, so the next party brawl is a quiet 1v1 unless someone notices.
- **Evidence:** `54_brawl_cs_after_sports.png` (HUMANS 1 / BOTS 1). Earlier Brawl default was BOTS 3 (`04_charselect.png`).
- **Suggested direction:** Keep a separate remembered rule set per mode.
- **Size:** S

### R-17 CPU fighters are labeled P2-P5 like humans
- **Severity:** P1 · **Where:** HUD cards, nametags, score screen
- **What a player experiences:** With 1 human and 3 bots, the screen shows P1, P2, P3, P4, all identical. You can't tell people from bots. Only the victory screen says "BILLY — CPU".
- **Evidence:** `45_rocketball_1s.png` (bot tagged "P2"), `d56_contact.png`, `d23_brawl_play/f016_SCOREBOARD.png`.
- **Suggested direction:** Label bots "CPU" (Smash) with a grey tag, and keep "P1-P4" for humans.
- **Size:** S

### R-18 Mode select puts the wrong mode first
- **Severity:** P1 · **Where:** Mode select
- **What a player experiences:** The default-focused, leftmost card is **TRIALS**, a course mode, so a group mashing A lands in an obstacle course. BRAWL, the "last one flying wins" headline, is second. The card art panels are different heights (Rocketball/Dropshot images are shorter), so the row looks uneven.
- **Evidence:** `03_modeselect.png`.
- **Suggested direction:** Put BRAWL first and focus it by default (Smash puts Smash first). Make cards the same size, and give Trials a "Solo/Co-op" sub-label.
- **Size:** S

### R-19 Content is locked on the first night with friends
- **Severity:** P1 · **Where:** Battleground select
- **What a player experiences:** 2 of 5 Brawl circuits (THE FOUNDRY, MAYHEM MILE) say "WIN THE ... TO UNLOCK". In a couch party game that means "you can't play the fun chaos stage tonight".
- **Evidence:** `15_arena_select_right.png`.
- **Suggested direction:** Party games ship everything unlocked in versus (Smash's unlock-everything later became a fan demand). Keep unlocks cosmetic (flair) or tied to solo Trials.
- **Size:** S

### R-20 Battleground select: you choose a "circuit" of 20 arenas, not a stage
- **Severity:** P1 · **Where:** Battleground select
- **What a player experiences:** You can't pick a stage, only a circuit that rotates through 18-20 arenas, and you don't know which one is next. The labels "WAYS TO PLAY" and "1 / 6" are odd. The RANDOM ROTATION card is a collage of three dark screenshots. Its copy, "A new peak every round", reads like a typo. Half the screen under the shelf is empty decoration.
- **Evidence:** `14_arena_select.png`, `15_arena_select_right.png`.
- **Suggested direction:** Smash/Brawlhalla stage select: a grid of individual stages with a preview, plus Random, with "playlist/rotation" as an option. Keep circuits as playlists.
- **Size:** M

---

## P2: polish

### R-21 The "primary" green button style looks like focus
- **Severity:** P2 · **Where:** Title, Pause, end screens
- **What a player experiences:** PLAY and RESUME are always green. When focus moves to QUIT (white, scaled), two buttons look selected. I had focus on QUIT while PLAY looked chosen.
- **Evidence:** `30_after_quit.png` (QUIT TO MENU focused, RESUME still green). On the title I saw the same thing (QUIT focused, PLAY green), but that still was overwritten during the session.
- **Suggested direction:** Show focus with one strong treatment (color plus outline plus wobble) that moves with the cursor. Don't give any button permanent "selected" styling.
- **Size:** S

### R-22 Options is thin and misaligned
- **Severity:** P2 · **Where:** Options (title and pause)
- **What a player experiences:** Four settings only. Labels and sliders are staggered on every row (MASTER flush left, MUSIC indented, SFX indented more, sliders different widths). The focus cue is a thin pink tick. There's no controls/remap or button-map view, rumble, screen-shake, display/vsync or language. In pause, the BACK button overlaps the P1 HUD card and "v0.1" overlaps P4's.
- **Evidence:** `34_main_options.png`, `27_pause_options.png`.
- **Suggested direction:** A tabbed options screen (Audio / Video / Controls / Accessibility) with an aligned grid. The Controls tab should at least show the pad layout.
- **Size:** M

### R-23 Input glyphs are inconsistent and leak keyboard keys into pad play
- **Severity:** P2 · **Where:** Menus vs match vs Trials hints
- **What a player experiences:** Menus use plain cream "A"/"B" keycaps and "< >" for the d-pad. The in-match legend uses colored Xbox glyphs (green A, blue X, red B). Trials hints read "HOLD A / SPACE" and "PRESS + RELEASE X / K".
- **Evidence:** `03_modeselect.png`, `17_launch_1.5s.png`, `40_trials_3.5s.png`, `41_contact.png`.
- **Suggested direction:** One glyph set, chosen by last-used device (pad glyphs when a pad is active). Use a real d-pad glyph.
- **Size:** S

### R-24 Character select focus flow fights the player
- **Severity:** P2 · **Where:** Character select
- **What a player experiences:** Left from POGO jumps to the FLAIR stepper. On entering Trials the initial focus landed on FLAIR, not the roster. Moving through the grid to the settings re-picks the hovered goat (my P1 became PUFF without me choosing). The P1 badge lingers on the old card. The "FLAIR UNLOCKED / PARTY-POPPER KO" toast is plain outlined text dropped over the grid.
- **Evidence:** `07_down_to_settings.png`, `08_focus_settings.png`, `35_trials_charselect.png`.
- **Suggested direction:** Mostly solved by R-02's per-player cursors. Make unlock toasts a proper banner card with an icon.
- **Size:** M (folds into R-02)

### R-25 The KO meta counts bot-vs-bot KOs and lives on the character screen
- **Severity:** P2 · **Where:** Character select
- **What a player experiences:** "55 KOs — NEXT FLAIR AT 100" went up from a match a CPU mostly won. It's a device-wide counter shown on a shared couch screen, and nobody knows whose it is.
- **Evidence:** `35_trials_charselect.png`, `43_rocketball_cs.png`.
- **Suggested direction:** Put progression on a separate Collection/Unlocks screen, and count human KOs only.
- **Size:** S

### R-26 QUIT from a match goes all the way to the title
- **Severity:** P2 · **Where:** Pause → Quit
- **What a player experiences:** The group wants to change stage or characters and gets kicked to the title, then has to re-pick mode, re-pick goats and re-set rules.
- **Evidence:** `33_returned_menu.png`.
- **Suggested direction:** Smash returns to the character select with the picks kept. Offer "Change Setup" in pause too.
- **Size:** S

### R-27 Between-stage overlays collide and leak dev naming
- **Severity:** P2 · **Where:** Brawl STAGE_END → SCOREBOARD → STAGE_INTRO
- **What a player experiences:** The stage-intro title "THREE MEADOWS" fades in on top of the still-visible scoreboard, so two overlays overlap. Level names read like dev labels ("ISLANDS VOID", and "GRASSY EXPANSE" on a grey void). The scoreboard says "(A) CONTINUE", but it auto-advances anyway. Unexplained "-1" (self-KO penalty) appears in the score column.
- **Evidence:** `d24_brawl_to_end/f003_STAGE_INTRO.png`, `d56_brawl_fast/f008_STAGE_INTRO.png`, `d23_brawl_play/f016_SCOREBOARD.png`.
- **Suggested direction:** Run the overlays in sequence, never overlapping. Give arenas player-facing names. Show either a countdown ring or an (A) prompt, not both. Label penalties ("SELF-KO -1").
- **Size:** S

### R-28 Victory screen layout collisions
- **Severity:** P2 · **Where:** Victory screen
- **What a player experiences:** The four HUD corner cards stay on top of the victory screen. The REMATCH / CHANGE SETUP / MENU row butts into the P3/P4 cards. "BILLY — CPU" is purple on a yellow burst, which is hard to read. Button widths don't match, and the button says "MENU" here but "QUIT TO MENU" everywhere else.
- **Evidence:** `25_victory_settled.png`.
- **Suggested direction:** Hide the combat HUD on the victory screen. Use a winner podium with 2nd-4th placement poses (Smash results). Use consistent button copy and sizes.
- **Size:** S

### R-29 Trials: co-op players spawn stacked on each other, and the copy says "FIGHT!"
- **Severity:** P2 · **Where:** Trials
- **What a player experiences:** P1 and P2 spawn on top of each other. The circuit select confirm reads "(A) FIGHT!" for a non-combat course mode. "COURSE CLEAR!" and "BOUNCE!" are yellow on pale sky over scenery, which is low contrast. Course 1 clears in about 1.5 s, which feels more like a skipped step than a lesson.
- **Evidence:** `39_trials_1s.png`, `38_trials_circuits.png`, `41_contact.png`.
- **Suggested direction:** Offset co-op spawns, change the copy to "GO!", put the banners on an outline/backplate, and make the first lesson last a few seconds of actual flying.
- **Size:** S

### R-30 Players spend long stretches off-screen as edge chevrons
- **Severity:** P2 · **Where:** Brawl
- **What a player experiences:** Fighters, me included, often sit above the top of the frame, shown only by small chevrons, for seconds at a time. You can't see the fight you're in.
- **Evidence:** `d23_contact0.png`, `d23_contact1.png`, `d24_brawl_to_end/f006_COMBAT.png` (two chevrons at the top, P1 at y≈-1000).
- **Suggested direction:** Smash-style off-screen magnifier bubbles showing the fighter, or a ceiling (soft top bound) so flight stays on stage. Coordinate with the owner camera rules (`docs/feedback/owner_2026-07-10_camera_rules.md`). Don't change the framing rules without the camera owner.
- **Size:** M

### R-31 The super-smash doesn't read as THE hit at gameplay zoom
- **Severity:** P2 · **Where:** Brawl
- **What a player experiences:** Supers show up as a thin white streak and a small ring on a ~40px body. KOs happen, but from the couch I mostly saw specks colliding, not "flying head-first into someone".
- **Evidence:** `d23_contact0.png` (white streak frames), `d56_contact.png`.
- **Suggested direction:** Bigger impact frames on super contact: a 2-3 frame freeze with a screen-wide flash, a camera punch-in toward the hit, a KO blast-line off the screen edge (Smash's KO-column explosion). This partly depends on R-05.
- **Size:** M

---

## P3: nice-to-have

### R-32 No controller onboarding or device feedback
- **Severity:** P3 · **Where:** Global
- **What a player experiences:** There's no "controller 2 connected" toast, no rumble on hits (not observable here, but there's no Options toggle for it), and no disconnect/pause handling I could see. Only one person can open menus at a time, which is normal, but nothing says who owns the menu.
- **Evidence:** `34_main_options.png` (no rumble/controls entries). The rest is inferred, since virtual pads can't be "connected".
- **Suggested direction:** Join/disconnect toasts, rumble on smash/KO, and auto-pause on disconnect.
- **Size:** M

### R-33 Audio not judged by ear
- **Severity:** P3 · **Where:** Global
- **What a player experiences:** Unknown. Music is confirmed playing in-match (`gameplay_4.mp3`) and the SFX library exists.
- **Evidence:** Live eval of `AudioManager._music`.
- **Suggested direction:** Schedule an audio-specific pass: hit and KO sound weight, menu sounds, whether the music suits the mode.
- **Size:** S

---

## Counts

| Severity | Count | IDs |
|---|---|---|
| P0 | 3 | R-01, R-02, R-03 |
| P1 | 17 | R-04 … R-20 |
| P2 | 11 | R-21 … R-31 |
| P3 | 2 | R-32, R-33 |
| **Total** | **33** | |

---

## Fantasy check: does the first 5 minutes deliver "frantic bouncing jetpack brawl, last one flying wins"?

**Partly, and you'd only notice the good part in replay.** The parts underneath are real. In motion, everyone is constantly airborne, the bounce is lively, bots fly and super, arenas have real gaps, and when a human connects a smash someone goes off-screen. The title screen and the character art are Steam-grade. Trials' first ring and Dropshot's crackable floor are good ideas.

What a first-time couch group actually goes through in those 5 minutes:
1. Friend 2's controller can't join. Their A press picks P1's character (R-02).
2. They raise HUMANS and get a 5-player brawl with an un-HUD'd P5 (R-03).
3. The first arena is a grey void (R-08). The fighters are specks with the wrong colors on their HUD cards (R-04/R-05).
4. Someone presses **B for POWERUP** and the game pauses, again and again (R-01).
5. Humans get knocked out within seconds and watch bots finish a 35 s round off the top of the screen (R-07, R-30). A CPU called "P5" wins.

At no point does it feel like **"me, flying head-first into my friend"**. The verbs are there but the player can't see them or feel ownership of them. Is flight needed? Yes, the gaps need boost. Is the super the kill? Mechanically yes, visually it doesn't land. Constant motion? Yes, sometimes too much (off-screen). Would they want one more round? Not after the B-pause and the join confusion.

### The 5 biggest things between this and "a proper fun game"
1. **Couch-controller fundamentals (R-01, R-02, R-03).** START pauses and B is a gameplay button. A real join-in character select with one cursor per controller and slot ownership that carries into the match. Bots fill empty seats automatically. This is table stakes, and today it fails in the first 30 seconds.
2. **Readability of the fight (R-04, R-05, R-06, R-17, R-31).** Fighters big enough to see from a couch, one consistent color identity per player, a persistent "this is you" marker, a HUD that shows damage and standing, CPU labels, and supers that land with impact.
3. **Brawl pacing and structure (R-07, R-30, R-20).** Stop early knockouts followed by spectating. Use stocks with respawn, or TowerFall-short rounds with a sudden-death squeeze, and keep the fight on-screen. Let players pick a stage.
4. **One finished visual language (R-08, R-10, R-11, R-15, R-12).** A bundled display font, one panel/button kit for menus and in-match overlays, painted backdrops on every arena (starting with the first), and real art for sports courts/goals/Dropshot floor. No stacked banners.
5. **Front-end flow (R-18, R-19, R-16, R-09, R-26, R-13).** Brawl first, everything unlocked in versus, per-mode remembered rules, a quit confirm that works, quit back to character select, and a clean rules panel instead of a stepper strip.
