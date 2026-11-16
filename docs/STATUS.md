# STATUS — current state & next steps

> The single always-current handoff doc. Update after EVERY commit. A fresh context reads this first.
> Durable history/rationale lives in `docs/DECISIONS.md`, `docs/specs/`, `docs/briefs/`,
> `docs/feedback/` — this file is a lean current-state snapshot, not a session log.

**>>> RESUME HERE (2026-11-16 ~08:10, owner left for work; agents may have died with the PC) <<<**
Remote: origin = github.com/Ender22/GottaBounce; agents can't push — owner runs `git push -u origin weekend/polish master`.
Owner checklist: docs/feedback/owner_questions_2026-11-16.md. Tree was CLEAN at d80fb10.
Shipped since 03:40: WK-169 SHOWDOWN ON; WK-169c polish (83d92d9); WK-183 sports fuel arc + refuel ding (UX SHIP); WK-187 + WK-194
end-screen mash guard + WINNER! plate (UX SHIP); WK-175c wall-refund feedback (fc4591c, gate still OFF; per-mode `wk175_gate_modes`);
WK-191-prep SD showdown built OFF (f88027c). Ruled: WK-188 GOLD SURGE not shipped; WK-190 accepted (no lever); WK-161b tune rejected.
IN FLIGHT at 08:10 (re-run any that left no output/commit; on resume check `git status` and revert half-done files with `git restore`):
  1. WK-175d creative-director brawl re-ask (GB_WK175=wr GB_WK175_MODES=brawl) -> docs/audit/2026-11-16_wk175d_feel.md. SHIP => set
     `refund_gates_on = true` (one line; scope is brawl only). Sports flip later (add "sports" to wk175_gate_modes after a Q4 re-ask).
  2. WK-190b SD-showdown A/B on RIG=all (harness tools/out/wk/wk190b_batch, DECISIONS "WK-190b RIG RULING") -> docs/audit/2026-11-16_wk190b_ab.md.
  3. WK-189 golden-drop fair point + L3 seek fix (gameplay-programmer, port 9147).
Next after: WK-195 rematch HURT! carry-over repro; WK-66d Dropshot courts art; WK-164 sports bots; WK-45 UI sounds; WK-CD7.
GPU PROBLEM: both AMD adapters in error -> software rendering since the 02:00 freeze. Visuals OK, perf/timing numbers invalid (WK-90 blocked).
WK-38: automation server is OFF unless --gb-port is passed. Don't pipe/redirect run_game.ps1. Recordings keep audio.wav.
Frame cleanup: `python -I tools/sweep_frames.py tools/out go`. Stall check: no output > 45 min + no Godot -> TaskStop + recovery agent.
CONCURRENCY CAP: <= 3 agents running Godot at once, <= 1 headless batch (and <= 2 processes per batch).

**WEEKEND POLISH RUN (started 2026-11-14, branch `weekend/polish`, UNATTENDED — owner: "i dont want to be
involved much, this project is about seeing what ai can do on its own"):** owner verdict after a 4-month gap:
"kinda fun but a shitty prototype... nonsense controls (B opens pause on xbox)... 2 users using 2 controllers
totally cant select their character like a normal game". Procedure `docs/WEEKEND_LOOP.md` (re-read every tick) + lessons `docs/WEEKEND_LESSONS.md`;
ranked work `docs/BACKLOG.md` (79+ items from 3 audits in `docs/audit/2026-11-14_*`); standard
`docs/COUCH_CONVENTIONS.md`; autonomy rulings DECISIONS 2026-11-14. Studio gained CCGS-adapted roles (producer,
accessibility-specialist, sound-designer, performance-analyst) + skills (ux-review, bug-triage, team-polish,
soak-test, scope-check) — `docs/reference/CCGS_IMPORT.md`. `.claude/settings.json` deny rules block push /
destructive git / recursive deletes (they match whole command text — reword commit messages that mention them).
DONE: WK-01 Start/Esc/P pause, B never pauses, pause-owner gating, no input leak on resume (933a77a, QA 8/8);
WK-02 4-fighter cap + HUD hides unused cards (933a77a). DONE: WK-03 InputRouter + WK-04 one device per human (0 cross-moves, rendered) (1191757). DONE: WK-05/06 Herd Lobby: per-controller join/pick/ready, routed, old CharacterSelect deleted (fe2a99c). DONE: WK-08 goat colour everywhere + WK-10 P# pips / CPU tags (4e7caf6). DONE: WK-81 lobby must-fixes + WK-07 RULES flip panel / per-mode rules / CHANGE SETUP (1080p rendered) (f1a9fdd). DONE: WK-22 KO blast art (4 tintable layers; art-director grade on WK-23 frame) (5a999db). DONE: WK-09 pause finish (hold-confirm, P# header, lobby style) + WK-11 end-screen input gate + WK-80 nits (5926f10). DONE: WK-12 painted backdrops on all brawl arenas (4ba5d88). DONE: WK-23 edge KO blast + WK-24 attacker-colour hits + WK-82 hold-B + WK-86 powerup spawns (4d5d356). DONE: WK-17 bundled Lilita One + Fredoka fonts (5672f04). DONE: WK-21/41 between-stage flow (designed 4.8s/6.2s; wall budget blocked on WK-91 hitches) (43b6abc). DONE: WK-91 closed: slowness was display-off standby throttling; game runs 120fps; texture cache fix (da8337b). DONE: WK-93 recorder + WK-94 smooth bot aim + WK-96 pendulum smash/swing + WK-97 black hole z-order (recording-verified) (9a2ee3f). DONE: WK-15 goal teaching + WK-88 naming + WK-92 font follow-ups + WK-36 off-screen bubbles + WK-27 sports team lobby (a4955e7). DONE: WK-95 owner flight ruling: steerable normal flight + super=attack bot brain (M1-M9 pass; bot traversal supers 27.6->13%) (4135884). DONE: WK-87 Trials panel avoids the goal + WK-100 display-off warnings (843c6c2). DONE: WK-104 kickoff freeze + fair toss, WK-105 sports sounds, WK-106 goal banner + credit (5f34080). DONE: WK-95e bot regressions fixed + HOT rule ON (traversal supers 9.8%) (a362ad4). DONE: WK-121 master limiter + sports hole-fall puff + tile sounds (a1ada05). DONE: WK-107 LONG HAUL fits the screen (834ecda). DONE: WK-18 28px text floor (2aa8f87). DONE: WK-20a measurement study + rulings (self-KO = Ra) (2721c7c). DONE: WK-20c self-KO = 0 by default + RULES toggle (6f4f51b). DONE: WK-123 Flight School teaches the super again + co-op lanes (7fe4ce4). DONE: WK-108 sports bots: route-around, track-back, keeper, cross (own goals 25->21.5%, kickoff goals 32->25%) (ee80867). DONE: WK-25 KO credit pop + kill list (2eef67e). DONE: WK-124 sports restart 2.67s (540f863). DONE: WK-127 bots stop self-KOing (37.8->17.8%), median brawl stage 8.4->13.8s (25e2c86). DONE: WK-111 sports victory screen (team, stats, MVP) (b4eb885). DONE: WK-37b ghost goats (float, bleat, puff cloud; kingmaker fences) (1186bcf). DONE: WK-122 sports courts painted edge-to-edge (e3e11d5). DONE: WK-34 panel kit A (Pause/Options/ScoreScreen one look) (8051d4f). DONE: WK-132 sound voice pool fixed (7764470). DONE: WK-37c ghost follow-ups (stacking, visibility, BAAA placement, blocked feedback) (ee46c22). DONE: WK-35 panel kit B + WK-34 review fixes (whole match flow in one cream look) (9498e0f). DONE: WK-37d ghost identity tags + islands_void lift + consts to Tuning + bleat gap 2s; CD2-06 pip/banner (art-director regrade pending) (b76d36f). DONE: WK-128 relight bill ON (bill-only); refund gates OFF pending WK-135; rr_allpads nav pilot regression accepted (DECISIONS 2026-11-15) (3e1a5b0). DONE: WK-37e art-director tag fixes (4/4 pass rendered + recording) (6c0d612). DONE: WK-66a sports nets in game (goals Ship; Dropshot net F1-F4 + blind read 'volleyball net') (2bd049c). DONE: WK-53b living taunt + WK-26 super-aim wind-up sound and target '!' (rendered + recording; ScoreScreen taunts + bleat-on-fire -> WK-53c) (4ca9472). DONE: WK-66b Trials gold goal cage (blind read 'goal net'; solved glow weak + parallax shows through mesh -> WK-66c) (19d924a). DONE: WK-13 BRAWL default focus + chips + equal heights; WK-42 HUD hidden behind Victory + button sizes/copy (green REMATCH style left for WK-14) (b2ac978). DONE: WK-14 focus style, WK-40 BACK chip, WK-38 stamp + server gate, WK-39 cursor (ab11c61). DONE: WK-120 sports 2V2 auto default + WK-125 lobby auto-join (PARTY PICK ribbon not built) (bbe6996). DONE: WK-85a Trials sky drop + no floating props (blind read: falling = losing a life; no formal art-director grade) (2702dc0). DONE: WK-117 sports copy, WK-52 unlock banner card, WK-113 sports legend top-docked (narrow-court overhang noted) (5a74fa8). DONE: WK-85 tall-arena backdrop horizon + full-height themed bodies (no art-director grade; twin_towers rock fill pebblier) (5ea164e). DONE: WK-66c glow + pocket shade + test-7 capture (Dropshot tape re-art stays contingency) (334b45f). DONE: WK-29 device-aware glyphs (keyboard/pad/mixed) (9eb3c60). DONE: WK-137 Brawl-only callouts + WK-37f ghosts out of terrain (1f5b64d). DONE: WK-28a disconnect grace, WK-138 honest lobby prompts, WK-83 nudge + safe area (ui-ux verdict pending) (6e57111). DONE: WK-33 controls screen, WK-139 end-screen kit, WK-140 quit dialog (7cb2f9f). DONE: WK-143 RULES pills, WK-145 lobby nits, WK-149 horizontal safe area, WK-141 legend first-frame + sports one-row (a1904ba). DONE: WK-142 Trials celebration + next circuit, WK-44 options shake/rumble, WK-144 quit lands on mode select (2e406dc). DONE: WK-119 sports team tags + persistent CPU tag, WK-146 HUD collisions, WK-147 Trials one goal surface (225c9a5). DONE: WK-60 select copy + WK-60b preview layout (painted court art still WK-65) (614f456). DONE: WK-150 tag avoidance + WK-148 sports first-frame cover (root fix in PartyMatch -> WK-148b) (b8be06d). DONE: WK-151 WASD menu navigation (5521929). DONE: WK-28b in-match disconnect overlay + toasts (no ui-ux verdict yet) (ece86c2). DONE: WK-136 near-empty relight min thrust (d23d2a4). DONE: WK-65 painted court cards + RANDOM crest + Dropshot mode card (HAMMER YARD/MINEFIELD dE 17.3 < 20 noted) (e6d7483). DONE: WK-148b sports camera start snap (cover off) + WK-131 badge flash fix (95d4723). DONE: WK-20e R2 spawn truce shipped + carousel soft-lock fix (4282309). DONE: WK-131 kickoff gates at 3.5 s (A/B 2.8 % kickoff goals, rally 10.4 s) (3c35d59). DONE: WK-153 CD4-01 session arena decks + Islands Void sky drop (361b6d2). DONE: WK-79a measured + WK-79b P1 mix applied (verification recording with audio pending) (eb22764). DONE: WK-154 padlock drain ring + WK-155 kickoff gate cues (art grade on red-goal pole contrast pending) (264646f). DONE: WK-162 cloud bank no longer reads as a floor (cb8d40d). DONE: WK-108b round 2 (K3 + K5 ON; rest -> WK-164) (HEAD). DONE: WK-163 stinger bus + KO sting (KO +7.7 LU, goal +8.7 LU) (758e163). DONE: WK-165 slam trimmed (719cf00). DONE: WK-156..159 CD4 nits (1da373f). DONE: WK-31 danger + stocks on player cards; mixed-couch footers (b131ac6). DONE: WK-19 rumble verified (WK-160) (27ead00). DONE: WK-30 keyboard parity verified (WK-160) (27ead00). DONE: WK-160 re-check sweep (27ead00). DONE: WK-166 disconnect follow-ups + bounce rumble threshold (54150be). DONE: WK-116 pressure nets shipped ON at +75 % (14ff3f6). DONE: WK-167 bots spend last fuel (dab9528). DONE: WK-65b MINEFIELD card re-roll (20ae38f). DONE: WK-20d closed (Phase A, no R5/R6) (9684fc6). DONE: WK-170 CD5-02 audio priority (5555fa6). DONE: WK-172 deck repeats + WK-171 RULES helper (9f711f2). DONE: WK-99 notch + bill flash, WK-173 overlaps, WK-178 ghost timing (fa785dc). DONE: WK-176 soak pass (30fdade). DONE: WK-174 not reproduced (held-D-pad wrap; harness tap = hold) (30fdade). DONE: WK-118 not reproduced (30fdade). DONE: WK-46 menu repeat + WK-179 soak fixes (17ffa8d). DONE: WK-110 match point / golden goal + GOALS stepper (1d09784). DONE: WK-181 SD revives only the last two; window in game time (4f5e429). DONE: WK-180 bumper art + decals + unlock ribbon (square bumpers + meadow corner tufts -> WK-182) (d89f7fc). DONE: WK-182 square bumpers + art-grade fixes (bcaba08). DONE: WK-169c showdown polish shipped (audio hush/stings, gold card frames, golden tank art, CPU golden-seek latch + reach guard; race p 0.8 ruled) (83d92d9). DONE: WK-190 accepted (dead share = format arithmetic; spec wk190); WK-191 SD showdown ruled, build OFF + A/B 190b queued (2044882). DONE: WK-175c wall refund feedback (ding+flare paying wall, tok+puff blocked; per-mode gate scope wk175_gate_modes; gate still OFF) (fc4591c). DONE: WK-191-prep SD showdown built OFF + forcesd rig; 190b A/B on RIG=all (f88027c). DONE: WK-187 end-screen mash guard (A+B quiet gap on Brawl/Sports/Trials, arm click, early-arm press, frozen goats fade) + WK-194 WINNER! plate; UX SHIP (2ad8b75, bd82551). NEXT: WK-95 flight ruling (building, baseline first), WK-15/88/92 + WK-36 verifying, then WK-98 sports deep-dive + WK-27 team lobby per BACKLOG Next 10.

**OWNER BATCH 2026-07-19 (4 asks, all shipped + rendered-verified):**
1. **Title layout** — Backdrop bobbers rearranged per owner ("big, at the sides, facing each other"):
   3 BIG goats per side (240/290/340px, sizes step down the column), left column native-right-facing,
   right column `flip_h` to face inward. Rendered-verified (tools/out/owner19_title.png) — reads like a
   real party-game title now.
2. **THE DOME net MOVES** — the dropshot_dome net bumper is now a `moving_platform` (vertical,
   amplitude 110, period 7s, dwell 0.1): top gap breathes 540..760px around beach's 650 average; at
   max-rise a 110px slot opens under the net (players fit, the 168px ball does not). Zero new code —
   reused the v6 MovingPlatform with tier:"bumper". Burst-verified in a live bot match
   (tools/out/owner19_dome/). Note: net now renders as the steel moving-platform column, not themed
   bumper art — art-director pass optional follow-up.
3. **Knockback +25%/damage level** — `dmg_launch_mult` [1.25, 1.66, 2.08] (owner ruling; DECISIONS
   2026-07-19). WATCH: pacing QA pass recommended — if brawl rounds one-shot, this array is the knob.
4. **TRIALS camera frames the goal** — new `GameMode.camera_focus_points()` seam (see DECISIONS
   2026-07-19): trials cluster framing now also contains goal gates / goal zones + ball / un-landed
   pads. Rendered-verified on s3_top_corner (owner's exact complaint shot): goal grid + player + ball
   all in frame (tools/out/owner19_trials_cam.png). Other modes byte-for-byte (default []).

**BRAWL ARENA EXPANSION — all 5 circuits to ~20 (2026-07-19, db26383 Meadow + d30ac75 the rest — owner:
"each circuit needs ~20 dedicated arenas"):** DESIGN docs/briefs/brawl_arena_expansion_2026-07-19.md
(71 new arenas, 69 JSON-only, 0 new code). BUILT + WIRED via 5 level-designer agents: MEADOW 4->20 (pilot,
rendered-verified — floating grass islands over meadow_day), SCRAPWORKS 4->20 (ordered; hazards one family at
a time), HIGH WIRE 3->18 (ordered; ridges/spires/radial/vertical, hazard-light), FOUNDRY 4->16 (draw pool,
draw_count 12; presses/crushers/debris/collapse), MAYHEM 8->20 (draw pool, draw_count 14; dropped 4 borrowed
arenas, added mines/gravity-wells/carts/multi-hazard). circuits.json wired; all 94 slots resolve. QA RENDER PASS
DONE (93b5357): 52/55 SHIP, 3 fixed + verified — black_hole_brawl lethal core WAS a suicide blender (0
credited kills) -> bounce core (lethal_core_r 0, body_r 120), now 3 alive; pandemonium_prime + foundry_collapse_ring
(all-destructible -> empty play_rect -> camera max-zoom-pinned) -> PartyMatch falls back to bounds. Every arena
loads, floats, spawns fair, hazards dodgeable. The BRAWL ARENA EXPANSION IS COMPLETE (94 arenas, 5 circuits).
OWNER NOTE: ~55 fresh arenas want a human fun/playtest pass;
auto-QA only confirms they load/frame/aren't-broken. Props on windmill/carousel/hay use the chrome skin (optional
meadow_bloom art). NEXT ART: super-aim pose x6 (goat-gated).

**FLOATING ISLANDS — void gradient KILLED (2026-07-19, fc9d9da — owner flagged the ugly dark-green void
~5x):** paint_void's abyss (sage-green->black fill + fake dirt-cliffs + AO + motes + on-rim kill-line) now
draws NOTHING. Platforms FLOAT over the painted sky; a fall is a ring-out at bounds.bottom (physics
unchanged — just no drawn pit). Grass platform BODIES fill their FULL collider height with a SEAMLESS TILED
EARTH island (new assets/world/earth_tile.png, generated NO-style-ref so no seam; UV-tiled via Polygon2D so
rock scale is resolution-independent) + chocolate outline + rounded bottom; grass fringe strip still caps the
top. Rendered-verified: n2_pinhole (the flagged shot — now floating grass-earth islands over blue sky+hills),
n2_wall_climb (tall), spires (space theme floats over the nebula painting; themed bodies unchanged for now —
a TALL themed platform would still gap, follow-up). DROPSHOT mode-card art shipped (mode_dropshot.png, teal
Bouncer spiking a beach ball; ModeSelect shows it, not the "D" glyph — all 4 mode cards now have dioramas).
TRIALS: all 16 new courses now SHIP — the 3 QA-failed ones fixed + driven-verified (pad-in-climb/goal bugs +
the ~29deg floor-ball launch limit; commit aa4ae8e+course fixes). UI end-screen BUTTONS rendered-validated
(Sports "RED WINS!" shows real REMATCH/CHANGE SETUP/QUIT, focus-navigable). TRIALS per-player fuel HUD SHIPPED (4039a70): co-op trials
now shows one corner PlayerCard per player (fuel gauge), not a single shared centre bar — rendered-verified 2P.
Thumbnails ALL re-baked via ThumbBaker (56262e6): every arena/court thumb now shows the floating-islands look,
and the 3 DROPSHOT courts got real thumbnails (were fallback plates). STILL OPEN: brawl arena content (~20
dedicated/circuit — DESIGN agent running now, docs/briefs/brawl_arena_expansion_2026-07-19.md); tall THEMED
platforms could still gap (grass-only earth body today; rare — no current themed level has tall platforms);
brawl grass arenas without a backdrop_painting show a plain sky (not the meadow painting) — a consistency
follow-up; super-aim pose x6 (art, goat-gated).

**UI CONTROLLER-ONLY CLEANUP (2026-07-19, e32eb94 — owner: "real games give a rematch BUTTON, not text"):**
audit at docs/briefs/ui_professionalism_audit_2026-07-19.md. SPORTS+TRIALS match-end now use REAL focusable
button rows (REMATCH/PLAY AGAIN · CHANGE SETUP · QUIT TO MENU) mirroring VictoryScreen — replaced the
"A/ENTER — REMATCH  B/ESC — QUIT" caption + raw input polling (new HUD show_match_buttons/match_button_pressed
API; dead MatchPrompt removed from all 3 HUDs). ALL keyboard refs stripped (ScoreScreen->"A|CONTINUE" glyph,
ControlsLegend/PadGlyph kb-chip paths deleted). Random keyboard-R-only -> new menu_random on the Y button.
Parse-clean; RENDERED VALIDATION PENDING (game held by trials QA). WORLD-ART REWORK CONFIRMED + PENDING (owner:
kill the ugly void gradient — floating islands + a seamless tiled-earth body for tall platforms; paint_void
abyss ripped out; needs an earth-tile art gen (ChatGPT) + game to build/validate). Trials per-player fuel HUD
(replace the one shared bar) folds into that pass. Chrome currently FROZEN (blocks earth tile + dropshot card).

**SPORTS SPLIT -> ROCKETBALL + DROPSHOT (2026-07-19, a061502 + 89ee253 — owner menu rework):** CHOOSE
YOUR GAME reordered to TRIALS, BRAWL, ROCKETBALL, DROPSHOT (the old single SPORTS card split by sport).
Both sports cards run SportsMode (PartyMatch registry maps rocketball+dropshot->SportsMode); the mode id
locks the sport + filters the court select — ROCKETBALL = 8 soccer courts, DROPSHOT = 3 dropshot courts.
Courts carry a "sport" field; SportsMode.is_sports_mode()/sport_for_mode() replace the scattered
mode_id==&"sports" checks. +2 dropshot courts (CORAL COVE wide, THE DOME tight; rendered-validated),
dropshot_beach renamed SUNSET BEACH. DROPSHOT SERVE reworked (owner): after each point the ball waits
FROZEN dead-centre above the net through the countdown, then on GO (new GameMode.on_combat_start hook from
_bounce_go) launches toward the team that scored LAST (scorers make the first touch) — rendered-verified.
FIRST BLOOD banner suppressed in sports (owner: killing isn't the point). MenuCard titles auto-shrink
(ROCKETBALL fit). All rendered-verified (mode-select 4 cards, both court filters, dropshot serve). PENDING:
DROPSHOT mode-card art (mode_dropshot.png — card shows "D" glyph until then; ChatGPT was rate-limiting);
dropshot court-select cards use fallback gradient plates (need ThumbBaker bakes). TRIALS EXPANSION (owner greenlit "build all 16 + QA"): design at docs/briefs/trials_expansion_2026-07-19.md
(circuits 2-5 -> 8 courses each, +16, ALL JSON-only, 0 art, 0 mechanics); all 16 AUTHORED +
wired into course_sets.json + committed (aa4ae8e, all parse+schema-clean; circuits 2-5 now 8 courses each with
the teach-then-build order). RENDERED QA pass IN PROGRESS (completability + difficulty + author-flagged risks:
n2_shifting_needle vertical-plug gate, s3_trapdoor drop-tile-in-trials, s3_pinball_alley/keyhole tight shots,
p4_breach/demolition_drop two-stroke break, p4_double_barrel steep window, g6_orbit_ring pickup+gravity,
g6_dead_star/solar_tour lethal-core telegraphy) — each course has a documented JSON-only fallback if QA fails it.
BRAWL circuit-select UX SHIPPED (89ea1a7): title -> CHOOSE BATTLEGROUND, arena-pool shelf removed (pick a
CIRCUIT only), RANDOM ROTATION moved last. BRAWL ARENA CONTENT next (owner: DEDICATED ~20 arenas per circuit,
5 circuits -> ~100 total; big push, not started).

**BOT TEAM-PLAY + ART BACKLOG (2026-07-19, 6df3aa3 + 6c231f2 — "continue bot brains + art backlog"):**
(1) DROPSHOT bots no longer crowd the ball — SportsMode.bot_objective now designates the teammate
NEAREST the ball as the chaser; the rest hold a goal-side cover point on their own half
(_ball_chase_rank / _support_point / _own_goal_center; rank counts human teammates so a bot yields).
QA (2v2 L3 all-bot, rendered): teammate separation ~600px on a 1110px half-court, both-on-ball
crowding ~1.2%, scoring preserved (6-goal cap), motion-health clean (0 head-bangs). (2) ART: the last
two trials crests — crest_trials_orbit (ringed periwinkle planet + orbiting moon + jetpack blob) &
crest_trials_varied ("whole toolbox" burst) — complete the PICK YOUR CIRCUIT shelf (QA-verified on the
shelf). (3) ART: skull.png replaces the 4 code-drawn grey Panels on the dead-player HUD card (Skull node
-> TextureRect; QA-verified crisp on dimmed dead cards). (4) ART: ball_beach.png — bespoke red/white/
blue/yellow beach ball for DROPSHOT, replacing the warm-tinted soccer ball (Ball.gd BEACH_TEX +
use_beach_tex, tint dropped); rendered-verified on Dropshot Beach. STILL OPEN (art): super-aim pose x6
(aim reuses idle; large character-consistency batch, partly goat-gated); dropshot court-select CARD
(needs an offline ThumbBaker bake of the court, not a ChatGPT gen); real FONT (owner font pick + download
approval). STILL OPEN (bots): head-bang undersides in ORBITAL arenas (radial frame skips the ascent-
detour; ~10/match residual, not a slice-2 blocker); bots don't use cannons/keys in trials.

**MATCH CEREMONY SHIPPED (2026-07-18, b4e76dd — owner picked "ceremony & charm" as next):** per
`docs/briefs/match_ceremony_2026-07-18.md`: (1) STAGE INTRO CARD ("STAGE N" ribbon + arena name +
gold underline) rides the existing intro/countdown window — 0.0s added, exits on the "3" beat,
DANGER ribbon on match point, suppressed on tiebreaker; (2) FIRST-STAGE CONTROLS LEGEND — drawn
PadGlyph chips MOVE/FLY/SUPER SMASH/POWERUP (pad A/X/B or WASD/SPACE/K/L auto-variant), fades 4s
into combat, chips press-bounce when you use them (fixes "owner didn't know powerup = B");
(3) VICTORY SCREEN (Brawl-only) — winner bust mugging over gold glow + confetti + FINAL SCORE race
bars (winner gold-rimmed, bots "NAME — CPU") + REMATCH / CHANGE SETUP / MENU focus row; accept
FAST-FORWARDS the choreography (never skips); CHANGE SETUP deep-links to CharacterSelect with
config intact (GameConfig.resume_setup). Field freezes at match end. All rendered-validated incl.
rematch loop + deep-link (tools/out/cer_*.png). ART ORDERS queued: victory_rays.png + optional
crown.png (drawn-glow/no-crown degrades shipped). Bot-brains-v2 (gravity-aware recovery) in
flight in a parallel session at time of writing. OWNER ART FEEDBACK (2026-07-18, new): backdrop
gradient hard-cutoff + code-drawn moons/planets read cheap — painted-backdrop pass + moon/
black-hole sprite generation is the next art priority.

**SPORTS SLICE SHIPPED (2026-07-18, 416998e — owner list, agent-built + rendered-validated):**
compact top-center score chip; crushers kill ONLY on a true squeeze (crusher_crush_gap=100, side
contact harmless); 2v2 up to 4 players (HUMANS+TEAMS steppers, team-side respawn seam); goals
require ball-CENTER inside the net + team-colored net burst; NEW SPORT **DROPSHOT** (floaty beach
ball, 65% center net, ball-only 2-hit crack→break tiles, every contact bounces — point = ball
falls into an ALREADY-open hole; bots finished a full match to 6 unassisted). Follow-ups logged
by the builder: beach-ball bespoke sprite + dropshot court card art; dropshot bot role-separation;
goal burst vs full-screen flash layering; 3-human UI-flow run; crusher design_intent prose stale
in 3 foundry JSONs. Painted-backdrops brief also landed (docs/briefs/painted_backdrops_2026-07-18.md
— 4 paintings cover all open-sky themes; kill-line restyle spec; "backdrop_painting" JSON knob) —
NEXT session executes it. STILL UNCOMMITTED: src/core/InputBot.gd (bot-brains v2 WIP, unvalidated).
PAUSED here for a model switch — victory_rays generated in ChatGPT but not yet downloaded.

**THEMED PLATFORMS + COURT INTERIORS + KILL-LINE OFF-SCREEN (2026-07-18, cb38c9f — owner "do both"
+ "death line off-screen like Smash"):** (1) THEMED BODIES — grass ledges no longer float in
space/foundry/quarry; BODIES manifest + platform_body knob auto-derived from backdrop_painting
(space_rock/foundry_steel/quarry_stone, dusk=quarry warm-tinted); 3 new 3-slice body strips; tier
MATS untouched; grass decals suppressed on themed bodies. (2) ENCLOSED INTERIORS — sealed courts now
sit in a painted interior (INTERIORS manifest + interior_painting knob behind the shell, code
sheen+vignette kept): interior_arena_stadium (team-neutral) on all 9 sports courts, interior_silo_cavern
on drop_chamber. (3) KILL-LINE moved from the void rim to bottom_y (bounds.bottom, ~840px below
platforms, OFF the camera) — no red line in the playfield now; abyss visuals stay at the rim. All
rendered-verified. FOLLOW-UPS: twin_moons uses h=40 mat-only slabs so it shows no themed body (flag if
its space-rock example matters); the flat blue Zone-A surround AROUND sealed courts is unchanged (only
the interior is painted); a future level with a shallow void h could pull the kill-line into view (none
today). docs/briefs/themed_platforms_and_interiors_2026-07-18.md is the brief.

**PAINTED BACKDROPS SHIPPED (2026-07-18, 908cd2d — owner: "every level should have a nice bg image",
"no svg 100% ai gen"):** the code sky-gradient + hardcoded sage-green void (the purple->green hard
cutoff the owner flagged) are REPLACED by full-bleed AI-painted sky+abyss compositions — one painting,
no seam possible. 4 paintings (space_nebula/ember_foundry/dusk_gold/overcast_quarry, 1536x1024 opaque)
via a "backdrop_painting" JSON knob + ArenaRenderer PAINTINGS manifest (path/horizon_frac/void fill
ramp/wall triple, all in the theme hue). 28 level JSONs wired + sky hexes retuned. KILL-LINE restyled
(function kept): 3px rim + pulsing additive red glow band (#E6402C 0.25<->0.55 @1.6s) + bigger/fewer
chevrons. Meadow keeps its grass sky (owner likes it), only void+line change. Rendered-verified all 5
themes. FOLLOW-UPS: (1) themed PLATFORM art — grass mats/dirt still used on space/foundry/quarry levels,
look slightly off floating in space (next art pass; platforms are arena_rendering's domain, out of this
scope); (2) p4_swing_shot/p4_chain_reaction switched meadow->open_sky (lost meadow parallax, carry
themed sky colors); (3) enclosed courts/sports NOT painted this pass (no sky/void — sealed interiors;
owner may want painted interiors later); (4) VictoryScreen victory_rays.png shipped (cba66d8).
Ceremony sunburst + bot gravity-recovery (341ae3d, +23pts credited on Singularity) also committed.

**OPUS SESSION CONTINUATION (2026-07-18, after Fable's pause):**
- Owner net feedback: DROPSHOT net lowered 740→490px (534d476) — the ball lofts over readily now.
- Owner bug: bouncers spawned squished — Player.respawn now resets _squash_timer/_charge_flight_t/
  _anim_t/_spin_vel + body scale/rotation + forces idle sprite (12529be, verified forced-squash→respawn).
- STAGED ON DISK, NOT yet committed/validated (both need the rendered game, currently owned by a QA
  agent measuring bot-brains): assets/ui/victory_rays.png (the ceremony gold sunburst — VictoryScreen
  RAYS_PATH; needs --editor --quit import pass + in-game check behind the bust) and
  assets/bg/painting_space_nebula.png (1536x1024 opaque full-bleed, first of the 4 painted backdrops;
  needs the ArenaRenderer wiring per docs/briefs/painted_backdrops_2026-07-18.md §4 + kill-line restyle).
  PLAN: wire nebula on the space levels as a PROOF-OF-CONCEPT, owner eyes, THEN batch ember/dusk/quarry.
- QA AGENT RUNNING: A/B validation of the uncommitted src/core/InputBot.gd gravity-recovery (credited-
  kill % on Singularity/Twin Moons fix ON vs OFF + flat-arena regression). Commit InputBot.gd only if it
  reports improvement + no flat regression.

**ART PASS 3 (2026-07-18, 8988a82):** bespoke moon.png + black_hole.png shipped and rendered-
verified (Twin Moons / Singularity) — no more code-drawn planets. OWNER ART DIRECTION (verbatim
intent): "no svg, 100% ai generated graphics"; big painted zoomed-out backgrounds wanted instead
of the gradient sky + hard void cutoff; the red dotted kill-line telegraph read as "weird" —
NEXT ART SLICE: art-director brief for painted per-theme backdrops (sky + below-horizon void
treatment as ONE painting; kill-line telegraph restyled to look intentional, function kept),
then generation batch (+ still pending: victory_rays, crest_trials_orbit, crest_trials_varied,
skull icon). OWNER SPORTS LIST (2026-07-18, in flight via agent): compact top-center score chip,
crush-only crusher kills, 4P/2-team support, ball-fully-in-net goal + net explosion, NEW SPORT
"DROPSHOT" (floaty ball volleyball, center net, ball-only destructible floor, 2-hit breakthrough
scoring). Bot-brains-v2 (gravity-aware recovery) agent resumed after a session-limit death —
InputBot.gd/Tuning.gd carry ITS uncommitted work-in-progress edits; do not commit those blind.

**SFX OWNER PICKS (2026-07-18, 920a8df):** jetpack thrust loop = coke_blast.mp3, super boost =
explosion_boss.mp3 (both from the owner's SamuraiRobot2.0 library, copied into assets/sfx/;
thrust verified looping live). Owner audio-mix listen still the acceptance gate.

**Last updated:** 2026-07-17 (owner-direction night, ALL 11 ITEMS SHIPPED — see
`docs/feedback/owner_2026-07-16_night_list.md` for the verbatim list):
1. **GAUNTLET MODE REMOVED** (e12f6c6, DECISIONS 2026-07-16; ModeSelect = 3 live cards; gauntlet ARENAS
   kept — they're Brawl arenas in the Mayhem Mile pool).
2. **FIRST 3 CIRCUITS LAUNCH-UNLOCKED** (6717bed, Settings.FREE_CIRCUITS=3; validated [T,T,T,F,F] live).
3. **PLAYER HEAD-BOUNCE** (28959c8, Mario-coop stomp): fall onto a player -> relaunch up 1150; NO fuel
   refund, denied during hitstun (dry-reflect doctrine), shove credit reused; lateral contact stays SHOVE.
   Measured live (+700 -> -1150 exact, fuel flat, 10-stage bot match healthy).
4. **FLIGHT ~20% LIGHTER WHILE THRUSTING** (28959c8, Tuning.boost_gravity_scale=0.8, owner ask verbatim):
   climb ramp measured -506@150ms (pred -498). CAVEAT for owner: sustained climb SPEED stays pinned at
   the 760 cap (INV-1); if climbing still feels slow the next lever is the vertical thrust cap = designer
   pass against INV-1 margin.
5. **BETWEEN-STAGE SCORE SCREEN** (ba2b7de, DECISIONS 2026-07-16): Duck-Game-style tally between Brawl
   stages (race bars to the kill target + delta chips + match-point staging; auto 3.4s, skippable);
   corner-card PIPS REMOVED (combat has no persistent score readout). Supersedes the <=4.5s turnaround.
6-9. **TRIALS = 5 CIRCUITS** (09b6a24 + 3 course commits): FLIGHT SCHOOL (4 NEW TUTORIALS w/ on-HUD hint
   lines — fly/super/combo/refuel — each completed by real injected-input flight) + NEEDLE & KEY (5
   navigation courses; NEW KeyToken/KeyDoor entities) + GOAL RUSH (4 player-driven soccer courses; Tap-In
   scored by a real boost-drive) + THE PHYSICS LAB (4 courses; NEW rideable Cannon entity — capture/
   auto-fire/sweep validated, boost-assisted carries MEASURED) + MIXED CHALLENGES (v7 battery).
   ArenaSelect gained a trials "PICK YOUR CIRCUIT" shelf (course_sets.json data-driven).
   REAL BUG FOUND+FIXED during QA: Pickup/KeyToken/LandTarget latched via body_entered -> the GoalGate
   stale-position bug falsely collected tokens during stage-load; all three now COMBAT-gated polls.
10. **SETTINGS TRAY FIXED** (cd7daff, owner: "terrible looking… how would a controller use it?"):
   steppers now have a visible focus plate (gold ring) and A on a stepper launches (locked) or hops to
   the hero grid — never dies. Full gorgeous-pass = ui-ux follow-up below.
11. **BOTS NEVER WEAR A HUMAN'S COLOR** (0b3b7c7): spawn plan excludes human picks; 5+ bots reuse BOT
   colors only. Validated live.
**OWNER ROUND 2 (2026-07-17 morning, live playtest feedback — all shipped):** (a) settings tray is now a
VERTICAL list of plated stepper rows (2e8ce4a — up/down walks settings, left/right changes value; the old
horizontal strip made BOTS/BOT SKILL unreachable-by-instinct); FLAIR strip inherits the row layout (330px
value pad had shoved its chevrons to the edges). (b) Trials home/hint panel compacted (347b8b1 — GO 42px,
hint 20px/560px autowrap; wordy n2_/p4_ hints trimmed). (c) Menu music now takes over on EVERY shell
landing (acc86a8 — nothing had ever played title.wav; ALSO fixed: imported WAVs ship loop_end=0 so
LOOP_FORWARD killed playback instantly — play_music sets whole-sample loop points). Music round-trip
verified live. Powerup button for reference: pad B / keyboard L (owner asked — consider an in-game legend).
**OWNER ROUND 3 (2026-07-17 evening, live playtest feedback — all shipped):** (a) Stepper = browse/edit
chips (5cfc74e): LEFT/RIGHT browses the horizontal strip, A opens the value (chevrons appear, LEFT/RIGHT
steps, A/B confirms — B consumed mid-edit), value sits in an inset dark WELL with gold rim while editing
(no ASCII brackets); ALL-READY A still launches via accept_override. (b) BESPOKE ART via the
Chrome+ChatGPT pipeline (14dd78a): objects/cannon.png (whole-toy rocking aim in Cannon.gd), objects/
key.png, objects/door_tile.png (KeyDoor vault tiling) — all keyout/check clean, CATALOG rows + prompts
recorded, graded from in-game screenshots; fallback drawing paths kept. (c) Solo trials drops the
permanent "GO" (same commit — home tracker/pip hidden solo; panel = hint chip only). Powerups = pad B.
**ART PASS 2 (2026-07-17 late, 4ac0c2c):** trials circuit CRESTS x4 shipped (FLIGHT SCHOOL / NEEDLE & KEY /
GOAL RUSH / PHYSICS LAB, gold-shield style matched to brawl crests; ArenaSelect trials cards now show art)
— rendered-verified. STALE-NOTE CORRECTED: squash/charge poses exist for ALL 6 colors and the 5 brawl
crests were already in place (the old backlog line was from the 2026-07-03 snapshot). Gotcha recorded:
new PNGs need one `--editor --quit` import pass before a rendered run can load them.
**REMAINING ART DEBT:** crest_trials_varied (MIXED CHALLENGES) + skull icon — ChatGPT image limit hit
mid-batch, generate when it resets (prompts in CATALOG); real font to replace SystemFont (needs owner
font pick + download approval); super-aim pose x6 (aim state reuses idle).
**ORBITAL GRAVITY (2026-07-18, owner ask — b99b8c5 + 026ba56):** the P8 gravity_source seam is FILLED:
GravitySource = radial constant-g wells (GravityField registry; Player/Ball/StormBall were already
field-correct), round planetoid bounce bodies (meta "round" keeps the true radial normal — axis-snap is
rect-only now), optional lethal core via the existing Hazard path, self-rendered black_hole/moon visuals
(moon sprite queued). Underside no-refund guard is now GRAVITY-RELATIVE (flat levels byte-identical).
NEW BRAWL ARENAS: **Singularity** (black-hole pinball hub — a lethal core was live-measured as a bot
blender, 32/36 uncredited core suicides, and PIVOTED to a bumper event horizon: re-measure 3/3 credited
blast-edge kills, real stage lengths) and **Twin Moons** (two planetoids, radial bounce verified, ~8s
stages, 55% credited, all 4 scoring). NEW TRIALS CIRCUIT **ORBIT** (Moonwalk/Slingshot/Binary Run — all
completed by real injected-input flight). KNOWN v1 LIMITS (watch): bot recovery logic is screen-down
biased (orbital arenas play best with humans; bots survive but fly clumsy); the idle air-drift brake is
global-x (damps orbital coasting when no input held — irrelevant with a stick held); crest_trials_orbit
pending with the other art. —  cannon/key/door PROPER SPRITES (interim = steel-sprite assembly + tinted
token; art-debt logged in entity headers); full HUMAN-skill playthrough QA of n2_/p4_ courses (validated
tonight by loads/gates/mechanic probes + measured carries, not full blind runs); ui-ux-designer formal
grade of ScoreScreen + settings tray; C-CAM zoom on the 10k-px cannon course (entities render tiny);
ScoreScreen row sizing >4 players; consider trials-circuit unlock gating (all 5 open today, owner call). — **FIRST REAL COUCH PLAYTEST found 2 shell-input bugs, BOTH FIXED
(commit 8bbf855):** (1) gamepad A was dead in EVERY menu — ui_accept had no joypad event (Godot 4 default is
keyboard-only; the MenuScreen comment claiming A fires ui_accept was wrong) → JoypadButton 0 added via a
ui_accept override in project.godot; (2) with all humans locked, the "(A) FIGHT!" accept was silently eaten
unless a hero card held focus → CharacterSelect now launches on accept from any focus (+_launching guard).
Validated rendered with injected pad-A-only input through the full TRIALS 2H flow (tools/out/dbg_A_*.png).
CAVEAT: if a REAL pad still does nothing (not even d-pad menu navigation), the pad isn't detected at the
OS/SDL layer — that's a different bug; get the controller model from the owner. — **LOCAL 2-4 PLAYER COUCH PLAY SHIPPED** (owner + wife playtest unblocked): per-device
input (InputHuman runtime-cloned per-pad action sets, INV-8 held), HUMANS stepper in ALL four modes, sequential
P1→P2 hero pick with per-picker cursor flag. Rendered-validated end-to-end (device-scoped intents proven, all 4
modes spawn N humans, full UI flow to live match). — **SHIP-class four-mode party brawler** (creative-director full-game verdict:
purchasable, cohesive, core fantasy lands, no regressions — `docs/feedback/cd_2026-07-06_fullgame.md`).
**2026-07-10 session:** the v10 TRIALS BINARY-COMPLETION rewrite (Pico-Park model, owner-directed) is BUILT + QA'd +
COMMITTED — no clock/medal/par anywhere; all-must-finish multi-player-parallel for REACH_GOAL+SURVIVE; solo for the 4
object-mutation types; 13 course JSONs migrated. Full v10 §7 QA battery PASSED (solo campaign parity, N=2/N=3
all-home, sticky latch, wait-for-dead, per-player SURVIVE). TWO real GoalGate bugs found+fixed during QA (stale
pre-combat latch that auto-cleared course_04; one-step-stale overlap latch on respawn) — see DECISIONS 2026-07-10.
The "movement-bot medal tuning" backlog task is DELETED (no medals to tune). CharacterSelect beauty-pose brief written
(`docs/briefs/character_select_busts.md`, Pogo+Butch first) — generation pass pending. THE FOUNDRY Brawl circuit
(4 arenas, level-designer) is IN FLIGHT — validation next. Only remaining owner-gate = audio mix listen.

## Where we are (the game today)
A goat/ram party brawler — "Duck Game × Smash Bros, no guns" — with a full front-end and four modes,
all on a pluggable `GameMode` seam:
- **BRAWL** — the core versus kill-race (bounce→fly→smash→recover, un-charged super, off-screen kills,
  lives, cumulative-kills-to-N, level rotation, SD-on-double-KO). The proven fantasy.
- **TRIALS** — Pico-Park BINARY completion (v10): no clock/medal/par; 5-course campaign + 8-course varied battery;
  fall = free respawn; multi-player-parallel (all-must-finish) on REACH_GOAL/SURVIVE, solo object-mutation types.
- **GAUNTLET** — solo/co-op survival vs escalating bot waves, shared defender-life pool, score=highest wave.
- **SPORTS** — 2-team bounce-ball into goals (Ball entity, GoalZone, team scoring).
Cast = **the Herd**: 6 goat/ram heroes (Pogo/Butch/Ziggy/Puff/Vex/Billy) that PLAY differently (feel
deltas). Content = 11 arenas in 3 circuits. Front-end = title/mode/character/arena/options/pause.

## What exists (committed + validated)
- **Front-end shell** (Phase 1, UI/UX verdict SHIP): `ShellRoot` screen-stack → MainMenu/ModeSelect/
  CharacterSelect/ArenaSelect/Options/PauseMenu; one springy gamepad-first menu system (`src/ui/*`,
  `scenes/ui/*`, `assets/ui/theme.tres`). Boot = `res://scenes/ui/ShellRoot.tscn`.
- **Config + mode framework:** `GameConfig` autoload + `MatchConfig` resource; `Settings` autoload
  (user://settings.cfg, applies buses+window on boot). `GameMode` seam (`src/modes/GameMode.gd`) with
  additive null-default hooks — `polls_goal`, `wave_spawn_plan`, `on_stage_ready`, `bot_objective`,
  `camera_framing`. `PartyMatch` = generic runner reading GameConfig + delegating to `_mode`.
- **Modes:** `BrawlMode` (versus loop extracted; the baseline — BRAWL is byte-for-byte the old game),
  `TrialsMode` (+ `GoalGate`, `levels/course_sets.json`, `levels/courses/*.json`, `TrialsHUD`),
  `GauntletMode` (+ `levels/gauntlet_waves.json`, `GauntletHUD`, `_despawn_bots`), `SportsMode`
  (+ `Ball`, `GoalZone`, `SportsHUD`, `levels/sports_court.json`). All mutually regression-clean.
- **Roster:** `assets/characters/bouncer_{pink,blue,green,yellow,purple,orange}_idle.png` = the 6 goats;
  `CharacterProfile`/`CharacterProfiles` per-character feel deltas (data, base Tuning UNTOUCHED, Billy=Standard).
- **Circuits:** `levels/circuits.json` — Meadow Mile / Scrapworks / High Wire over the 11 arenas.
- **Combat/feel/bots/audio/arena render:** the original validated core (un-charged super, SHOVE/SMASH
  solidity, damage system, edge-relative kills, ring-out credit; InputBot L2-L4 human-sim; AudioManager;
  Glossy Toybox `ArenaRenderer`). Camera frames ALL living players (2026-07-05 oscillation fix).
- **Studio:** roles in `.claude/agents/` incl. **ui-ux-designer** (front-end approval), creative-director
  (fantasy-fit), art-director, game-designer, level-designer, gameplay-programmer, qa-playtester.

## Read order on fresh context
`docs/STATUS.md` (this) → `docs/ROADMAP.md` → `docs/GAME_ESSENCE.md` → `docs/VISION.md` →
`docs/DECISIONS.md` (newest-first — the 2026-07-05 entries cover the whole rebuild + rulings) → the
mode/content specs: `docs/specs/v1_frontend_shell.md`, `v2_character_feel_deltas.md`, `v3_content_plan.md`,
`v4_gauntlet_mode.md`, `v5_sports_mode.md`, **`v6_party_gimmicks_circuits.md`, `v7_trials_challenge_types.md`,
`v8_sports_courts.md`, `v9_idea_bank.md`** (the content initiative) → `docs/briefs/character_theme_bible.md`
+ `character_art_bible.md` → `docs/PIPELINE.md`. Memory: [[gottabounce-session4-scope-correction]],
[[gottabounce-chatgpt-image-paste]].

## IN-FLIGHT — RESUME HERE (content-expansion initiative)
**Design is DONE (5 committed specs); BUILD is the constraint (one rendered test / game instance at a
time).** The plans all fan out from ONE shared foundation — build the gimmick MECHANICS once, reuse across
Brawl circuits + Trials challenge-types + Sports pitches.

- **Specs ready to build from:** `v6` (lethal gimmick mechanics ranked: spinning_hammer→crusher→
  falling_debris→bomb→destructible_block→moving_platform + collapsing-arena archetype; 4 new circuits
  Foundry/Midway/Convoy/Meltdown w/ 20-authored-10-drawn rotation; mastery-first unlock progression).
  `v7` (Trials objective types: Survive/Destroy-all/Physics-puzzle/Collect/Precision via optional course
  `objective` block, absent=REACH_GOAL back-compat, zero new runner hooks; 8 example courses).
  `v8` (8 Sports pitches calm→chaos, strict mirror-symmetry, `Ball.receive_hazard_impulse` hook).
  `v9` (level-designer's creative idea bank — ice/low-friction, jump-in cannons, + original inventions;
  landing shortly). Hazard doctrine = LETHAL w/ telegraphy+fairness+credit (DECISIONS 2026-07-05).
- **BUILD SEQUENCE (do in this order):**
  1. **v6 mechanics — DONE (ALL 6, validated + committed):** spinning_hammer, destructible_block
     (+ COLLAPSING ARENA meltdown_box), crusher, falling_debris, bomb/landmine (+ `Ball.receive_hazard_impulse`),
     **moving_platform** (commit dfb8dd3 — `MovingPlatform.gd` AnimatableBody2D solid deck, sticky rider-carry since
     Player is MOTION_MODE_FLOATING; re-validated 2026-07-06: sub-pixel carry stability, no jitter/tunnel; test bed
     `levels/platform_test.json`). Reusable plumbing: contact->kill Area2D, phase-clock+dwell oscillator, self-render
     telegraphy, LevelLoader wiring, destructible `group`-count contract. No hard mechanic remains.
  2. **BRAWL circuit — DONE:** MAYHEM MILE (`mayhem_mile`, 12-pool draw-6 tier-sorted). Random-draw rotation
     + UNLOCK PROGRESSION DONE (Settings [progression], mastery+pity, ArenaSelect locked cards + celebration).
  3. **Fan-out DONE across all 3 modes:** TRIALS challenge types (6 types + proof courses, `varied` set) +
     SPORTS pitches (5 courts calm->chaos + court-set + unlock gates) both built + validated. Sports
     bot-fairness fix committed (mirror-symmetric court + per-team skill balance).
- **ART-DEBT PAYDOWN (owner "no code-drawn/SVG assets" rule) — DONE (Task #7 complete).** ALL code-drawn object
  bodies replaced with generated Glossy Toybox sprites (transient telegraph/VFX + gameplay-contract overlays stay
  code). Committed+wired+rendered-validated: `hazards/hammer.png` (SpinningHammer), `bomb.png` (Bomb/landmine),
  `crusher.png` (Crusher heads), `wrecking_ball.png` (FallingDebris chunks + MovingHazard pendulum), `flatbed_cart.png`
  (MovingPlatform vehicle deck), `objects/ball.png` (Ball.gd — rolls via RigidBody transform), `objects/crate.png`
  (DestructibleBlock.gd — 2D grid-tiled off shorter edge so crates stay square on wide floors AND tall walls; tier
  bounce-mat strip kept on top), `objects/token.png` (Pickup.gd). NO code-drawn object body remains — only intended
  telegraph/VFX (RingOfFire/StormBall/GoalZone glow/LandTarget reticle/PowerupBubble shell).
- **UI-POLISH SLICE (owner "gorgeous, Mario-Kart bar" priority) — STARTED.** Brief done: `docs/briefs/frontend_visual_polish.md`
  (finding: the shell is a CORRECT UI wearing placeholder skins; the whole gap is ~1 logo + 4 mode dioramas + baked arena
  thumbnails [a tool, ~0 art] + up to 6 char portraits + a free title bobber-wiring pass — all drop into slots the shell
  already animates). Priority order: TITLE → ModeSelect → ArenaSelect → CharacterSelect.
  - **TITLE — DONE.** Bobbers were ALREADY built (Backdrop.gd, Phase 1 — the brief's "never built" was wrong; agent
    correctly did NOT duplicate). Fixed the one real bug: purple Vex was parked behind the logo → moved to clear sky, all
    6 Herd now visible. Rendered-verified gorgeous (tools/out/title_fixed_2.png). LOGO: current yellow/cyan wordmark reads
    fine + bobbers give mascot presence → §4c goat-on-logo DEFERRED (ChatGPT text-gen is unreliable; poor risk/reward now).
  - **ModeSelect — DONE.** All 4 `ui/modes/mode_{brawl,trials,gauntlet,sports}.png` dioramas generated + WIRED into the cards
    (MODE_ART preload dict + data["art"]; set_art hides the Glyph). Four mini box-covers. Rendered-verified (modeselect_check.png).
  - **ArenaSelect — DONE.** `tools/ThumbBaker.gd/.tscn` bakes each arena via ArenaRenderer → `assets/ui/thumbs/<id>.png` (19
    baked + a RANDOM collage); ArenaSelect loads them into card Art slots (existence-guarded `load()`, KEEP_ASPECT_COVERED) +
    RANDOM tile toned down. Fixed the circuit-card text overflow (name+tag split) + LOCKED-ribbon/header collision (grid band
    shifted down). Rendered-verified (arenaselect_fixed.png) — a real visual map-select. RE-BAKE: `<exe> --path . res://tools/ThumbBaker.tscn` then `--editor --quit` to reimport.
  - **CORE UI-POLISH SLICE = COMPLETE** (title/ModeSelect/ArenaSelect all Mario-Kart-tier; CharacterSelect already solid).
    Remaining nice-to-haves (deferred, non-blocking): CharacterSelect beauty-pose busts (§2c, start Pogo+Butch); goat-on-logo
    (§4c — current wordmark reads fine + bobbers give mascot presence; ChatGPT text-gen unreliable, poor risk/reward unattended).

## NEXT PHASE — content waves (owner-requested variety)
- **Sports pitches — DONE (8 total).** Added `the_bowl` (calm funnel), `minefield` (symmetric landmines), `the_crusher`
  (center horizontal crusher, ejects ball vertically) + `Crusher._eject_ball`. All strict mirror-symmetric, bot-match validated,
  wired into sports_courts.json (unlock gates use REAL circuits). WATCH: minefield leaned BLUE 5/5 but all margins 1-2 goals
  (~58%, under the 65% bar) — reads as first-touch variance; re-sample if it recurs.
- **Trials battery — DONE (8 courses).** `varied` grown 5→8: +t_cart_convoy (COLLECT, void+cart+refuel), +t_twin_hammers
  (SURVIVE hard), +t_bank_shot (PHYSICS bank-shot capstone). Difficulty-ramped, each validated completable in-engine.
  **v10 (2026-07-10): medals/par REMOVED from all courses — binary completion; the medal-tuning task no longer exists.**
- **CREATIVE-DIRECTOR full-game verdict — DONE (`docs/feedback/cd_2026-07-06_fullgame.md`): SHIP-class, no rethink, no
  regressions.** Purchasable-looking cohesive party brawler; BRAWL delivers the full fantasy; motion health clean. Punch-list
  applied (see below).
- **CD PUNCH-LIST — APPLIED + committed:** (1) progression unlock-chain integrity guard (Settings.gd — recursive prefix guard +
  self-healing sanitize; the "High Wire open while Scrapworks locked" impossible state is dead); (2) repaired the dirty DEV save
  (music was 0% → our playtests ran MUTED; now defaults music=1.0 + clean progression); (3) Sports match length 10→6 goals
  (`Tuning.sports_goal_target`, split from Brawl's knob); (4) audio verified FIRING (music + SFX). 

## LOCAL MULTIPLAYER (couch play) — BUILT + validated 2026-07-14
Two-to-four humans on one screen, all four modes, controllers supported:
- **Input:** `InputHuman` now clones the authored `[input]` bindings into per-device action sets at runtime
  (`boost__d1` = boost events re-scoped to pad 1) — bindings stay in project.godot (INV-8), rebinds flow to all
  players. Assignment (`InputHuman.for_human`): enough pads → human i gets pad i, P1 also keeps keyboard; fewer
  pads → P1 keyboard, P2+ take pads in connect order. Solo play byte-for-byte unchanged (legacy any-device path).
- **Modes:** BRAWL uses its existing HUMANS stepper; TRIALS (multi-player-parallel), GAUNTLET (co-op, shared
  4-life pool), SPORTS (HUMANS 2 = human-vs-human 1v1, P1 RED vs P2 BLUE) now expose a HUMANS stepper too.
- **CharacterSelect:** sequential pick — P1 locks, cursor flag recolors to P2 (blue) with "P2 — PICK YOUR GOAT",
  duplicate heroes soft-denied, BACK reverts the last pick, HUMANS change resets the round.
- **Evidence:** device-scoped poll proof (injected device-1 stick read ONLY by the device-1 poller), per-player
  intent split in a live 2H brawl (P2 boost=true while P1 idle, and keyboard → P1 only), spawn counts + team
  split verified in all 4 modes, full real-input UI flow to a live pink-vs-blue match (tools/out/2p_*.png).
- **NOT yet covered:** no physical gamepad existed on the dev box — pad events were injected. The pad-assignment
  mapping is 8 straightforward lines but the first REAL two-controller session is the owner's playtest. If a pad
  misbehaves: pads are assigned in `Input.get_connected_joypads()` order; check Windows sees both pads first.

## ⚠ NEEDS OWNER (flagged, NOT auto-changed)
- **BRAWL kill target — RESOLVED 2026-07-06: owner locked 10.** CD/QA had recommended ~7, but owner's ruling: Brawl is the
  4-player party mode (Duck Game/TowerFall lineage); with 4 players kills bank fast across last-one-standing rounds, so 10 keeps
  matches from ending too soon. Do NOT re-litigate. Knob `Tuning.match_target_kills` (separate from Sports).
- **Audio MIX quality** — a HUMAN must LISTEN. Audio is wired + firing (verified), but no one has judged levels/loop/punch (our
  playtests were accidentally muted until tonight's save repair). AI can't hear this.

## OWNER FEEDBACK 2026-07-10 (drives current priorities)
- **UI audits (owner-flagged):** full audit DONE (`docs/briefs/frontend_ui_audit_2026-07-10.md`) — MainMenu SHIP;
  ModeSelect/CharacterSelect/Options/Pause FIX; ArenaSelect was REJECT → **REBUILT + designer-approved SHIP
  (committed):** two-shelf scrolling layout (WAYS TO PLAY 460x340 / ARENAS 380x280 rails), scroll-to-focused,
  clip bands (header/footer occlusion structurally impossible), ModeContext chip (ArenaSelect + CharacterSelect),
  LB/RB+PgUp/PgDn 3-card jumps, real star icons, per-shelf remembered focus. ShelfRail is reusable — it IS the
  future Sports court-select container — and now IS the Sports court select (see backlog DONE entry). AUDIT
  FOLLOW-UPS CLOSED 2026-07-10: court thumbnails baked (ThumbBaker courts pass, court_<id> namespace);
  HintStrip contrast pass (P2, cream chips shell-wide + footer no-content enforcement); CharacterSelect
  safe-area/type (P3, 64px tray inset + 28/40px stepper type); Options tick-gutter + centered panel;
  PauseMenu hint strip (inside the panel footer — designer caught the first placement overlapping a HUD corner)
  + two-press REALLY? confirm on QUIT/RESTART. Designer re-grade: PASS all items after the relocation.
  ~~Circuit CREST art~~ + ~~de-clocked mode_trials.png~~ **DONE + committed 2026-07-11** (all 5 crests AD-graded —
  Foundry re-rolled once for High-Wire style bleed; TRIALS diorama de-clocked via surgical edit, AD Ship).
  STILL OPEN: ToyToggle knob scale (P5-minor); CharacterSelect stepper focus treatment (designer F-class
  follow-up: nothing visibly reads as focused while focus is in the settings strip).
- **CAMERA (repeated ~5x, owner rules now the acceptance spec):** `docs/feedback/owner_2026-07-10_camera_rules.md`.
  **REWORKED TO THE RULES + committed (see DECISIONS 2026-07-10):** camera_bounds = platform AABB +200; target =
  clamped midpoint of extreme players (cluster/weights/velocity-lead machinery deleted); zoom fits everyone (no
  readability floor); zoom-in cap shows >=75% of the level. Motion-evidence QA: 0 off-screen violations in 679
  combat player-samples across worst-case-spread + live 4-bot matches on grassy_expanse and foundry_press_row;
  0 fast pan reversals; clustered zoom cap exact. **AWAITING OWNER EYES — do not call this fixed until he says so.**
  Knobs if he wants adjustment: Tuning.cam_bounds_pad (200), Tuning.cam_close_fraction (0.75), CAM_MARGIN.

- **v11 COSMETIC UNLOCK TRACK (Horn Notches) — BUILT + committed 2026-07-10** (`docs/specs/v11_cosmetic_unlock_track.md`).
  10-tier credited-KO flair ladder (10→1000), all parameter cosmetics (jetstream/flame/KO-pop/title), zero new art.
  FIXED the total_kills defect (only circuit matches banked; self-falls erased kills → now raw credited kills bank
  from every finished Brawl match via PartyMatch.raw_kills). FLAIR stepper + KO chip on CharacterSelect; consume-once
  celebration; sanitized save fields; Sports suppression + telegraph precedence guards. QA C1-C9/C11-C15 verified
  (evidence tools/out/v11_*.png). OPEN: C10 zero-gameplay-delta needs a seeded-identity QA harness (by construction
  only visual channels are touched; Tuning byte-identical); ui-ux spot-grade (title font shrink at 40px, flair
  stepper 24px density); art-gated appendix (crown/palettes) unbuilt.

- **ART PASS #2 (goat action poses) — DONE + committed 2026-07-11.** All 12 sprites (squash + horns-forward charge
  x 6 heroes) generated, AD-graded FIX→SHIP (Billy charge re-rolled for color read; 4 squashes re-generated
  flame-free; all-six-alive readability gate passed). Player.gd now runs a 3-pose priority swap: squash
  (bounce window) > charge (super aim + 0.35s launch read) > idle — the super finally reads as a creature
  charging horns-first, and squash swaps for ALL six (was pink-only). Logged: Puff's charge horn oversize
  (next regen). The bouncer_*_super_aim.png separate aim-pose idea is superseded by the charge pose serving
  both aim + launch.

## NEXT-UP BACKLOG (autonomous-safe; fresh-session ready)
- CD minor items — DONE: minefield elevated mines now fire (proximity mines detect the ball; Bomb._ball_within, sports-scoped);
  Gauntlet solo lives was a non-issue (already 4 via CharacterSelect — CD saw a dev-launch default).
- ~~Trials medal-time tuning~~ **DELETED by v10** (binary completion — no medals exist to tune).
- ~~Sports court-select UI~~ **DONE + committed 2026-07-10.** ArenaSelect is mode-aware: SPORTS shows "PICK YOUR
  COURT" — one ShelfRail of all 8 courts (tier-sorted, TIER badges, locked ribbons w/ readable unlock hints:
  circuit/matches/wins), launch passes the court ID so SportsMode._resolve_court stays the unlock authority.
  CharacterSelect SPORTS flow now routes through it (1v1 preset kept). Real-input flow verified end-to-end
  (ModeSelect→hero lock-in→court→live 1v1 on Center Pitch); brawl two-shelf regression clean. FOLLOW-UPS:
  bake court thumbnails (7 courts on gradient fallback — extend ThumbBaker to sports courts); ui-ux spot-grade
  of the court screen (built to the approved audit §3.8 grammar).
- ~~THE FOUNDRY circuit validation~~ **DONE + committed 2026-07-10.** 4 arenas bot-match validated (press_row/
  smelter/crucible/meltdown), wired into circuits.json (unlock: win High Wire; Mayhem Mile now gates on Foundry) +
  ArenaSelect color + baked thumbs. TWO spawn-layout bugs fixed during QA: press_row's middle-island spawns sat in
  the crusher lanes (bots died <0.2s EVERY round — deterministic; spawns moved to outer islands) and smelter's 4th
  spawn sat inside the horizontal crusher lane + its right island is fully inside the hammer sweep (primary spawns
  now on the left island, swept spawns demoted to indices 4-5 per the hammer_arena precedent — 4P matches open with
  everyone on island A, flagged for level-designer). Pacing after fixes: press_row hot (~5s rounds, WATCH), smelter
  3.5-15.5s, crucible 8-16s + even scores (best of set), meltdown 6-10s on its ~10s collapse TTL. Also: Hazard.gd
  (spikes) now gates lethality on combat_started like every other hazard (dormant path — no level ships spikes);
  TRIALS ModeSelect tagline de-clocked ("Fly the line. Land it, and you're home.").
- Trials polish follow-ups (from v10 QA): per-COURSE pause restart (today RESTART = whole set); C-CAM watch — author
  multi-player parallel courses screen-scale-aware (>1-screen spread renders far players as edge arrows).
- ~~CharacterSelect beauty-pose busts~~ **DONE + committed 2026-07-11 — ALL SIX, art-director SHIP.** Generated via
  the ChatGPT paste-edit pipeline per the brief's §4 recipe; portrait-first/idle-fallback wired in CharacterSelect
  (_tex_for). New intake gotcha documented in CATALOG.md: defringe transparent-pixel RGB junk before trim
  (bilinear halo risk). Pogo hue runs hotter magenta than the idle — accepted with a re-roll condition.
- More Brawl circuits + the 3 seed arenas; always-on-hazard pre-combat lethality guard; goat-on-logo (deferred, text-gen flaky).
- **CONTENT INITIATIVE = LARGELY COMPLETE** (all 6 gimmick mechanics incl. moving_platform now done). Remaining BACKLOG
  (clearly scoped, none blocking): fuller batteries (the_bowl/minefield/the_crusher Sports pitches,
  v7's full 8 Trials courses, more Brawl circuits + the 3 seed arenas); always-on-hazard pre-combat lethality
  fix (gate on combat_started / raise spawns under blades); Sports court-select UI (plumbing selects by
  court_id today); cumulative-kill cosmetic unlock track (counter exists); CD#7 polish (menu arena-thumbnails
  + mode-card icons, Trials medal-time tuning via a movement bot, plain-button focus accent-border); goat
  squash/charge + super-charge poses (art pass #2, paste-edit technique); goat logo; all-six readability gate.
- **PROCESS WATCH:** a build agent stalled TWICE in a "launch bg sweep -> end turn waiting" loop without
  harvesting; the lead took over + validated with a BOUNDED bot-match sample. If an agent does this, take over.

## Prior polish/quality backlog (behind the content initiative)
Trials medal-time tighten (movement-bot/human run — CD flag), all-six goat readability gate (spawn 6 in a
match), Vex corkscrew horns + goat squash/charge + super-charge poses (art pass #2, use the paste-edit
technique [[gottabounce-chatgpt-image-paste]]), goat-themed logo/key-art, arena thumbnails + mode-card
icons (CD #7 "tech-demo" tells), plain-button focus accent-border, Gauntlet G-BOTFOCUS + victory-drive,
Sports 2v2/co-op presets + end-zoom empty-net, Gauntlet banner overlap, confirm gamepad-A activates shell.
Do NOT build Puzzle mode #5 yet (CD #7: deepen the 4). match_target_kills=10 (owner-set; QA suggested 7-8).

## Watch out for (hard-won)
- **RENDERED BUILDS ARE SERIALIZED:** only ONE game instance (port 9090) — never run two game-driving
  agents at once. Boot now goes through the shell (MainMenu); to test a match directly launch
  `res://scenes/Arena.tscn` (default GameConfig=brawl), or set `GameConfig.match_config.mode_id` via eval
  then `get_tree().change_scene_to_file(...)`. `get_tree().current_scene` on the shell = MainMenu, NOT the match.
- **gbplay `eval`:** context is a Node (has `get_tree()`), NOT the match — reach the match via
  `get_tree().current_scene`. Multi-line evals run (side effects) but return null; single-expression evals
  return values. A `for` loop with `; return` same-line pulls return into the loop.
- **Background agents can zombie** holding port 9090 → next run acts slow/wrong. Kill strays
  (`tools/stop_game.ps1` + taskkill); always launch via `tools/run_game.ps1`; verify scene path.
- **The "crash ~12 stages" + "fps 79→28" were BOTH REFUTED (2026-07-04)** — do not chase; zombie procs +
  unfocused-window throttling. Physics is fixed 120Hz decoupled from render.
- **ChatGPT art:** attach references via clipboard Ctrl+V (STA PowerShell SetImage); edit-outputs need
  `art.py keyout --tol 45`; download via the share-modal Download button. See [[gottabounce-chatgpt-image-paste]].
- Windows/PowerShell/Godot: ASCII-only .ps1; `dangerouslyDisableSandbox:true` on Godot shell calls; console
  exe `C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`; a mis-quoted --path can launch
  the OLD sibling project (also serves 9090 — verify scene path). (CLAUDE.md has the full list.)
