# MATCH CEREMONY & CHARM — UX brief (2026-07-18)

> Owner-approved priority slice. Author: UI/UX Designer. Design only — the gameplay programmer
> builds from this; I grade from rendered screenshots + bursts before anything ships.
> Bar: Mario Kart / Duck Game / TowerFall. Gamepad-first, readable at 10 feet, springy, zero
> OS-default anything. Three deliverables: (1) STAGE INTRO CARD, (2) FIRST-STAGE CONTROLS LEGEND,
> (3) VICTORY CEREMONY. One focused build session.

## 0. Ground rules shared by all three (the "ceremony grammar")

These reuse the motion + style grammar already shipped (ScoreScreen / MatchHUD / theme.tres) so the
whole match flow feels like one product:

- **Pop-in:** scale 0.3 → 1.0, 0.15–0.18s, TRANS_BACK / EASE_OUT (the house spring).
- **Pop-out:** fade to a=0 over 0.15–0.20s while scaling to 1.2 (the house exit).
- **Slide-settle (new, for the intro card):** enter from off-axis with TRANS_BACK/EASE_OUT 0.28s —
  same spring family, but directional (banners pop, CARDS slide).
- **Stagger beat:** 0.12s between sibling elements (ScoreScreen ROW_STAGGER — keep it).
- **Palette:** dark-chocolate outline `#3B241B` (theme's 0.231,0.141,0.106) on every card/chip;
  cream chip `#FFFFFF @ 0.94` with chocolate text; navy tray `#141428 @ 0.93` for panels over
  gameplay; GOLD `#ffd23f` = celebration; DANGER `#ff4b3a` = match point only. Player identity
  colors ONLY from `PartyMatch.PLAYER_COLORS`.
- **Type:** existing theme variations only — `BannerCenter` (132), `BannerTop` (58), `BannerSub`
  (40), `ShellBtnPrimary` (46), `ShellBtn` (40), `CardTag` (22–26 chip labels). No new font work
  (real-font swap is a separate logged debt); all display text chunky-outlined, ALL CAPS.
- **Cast names (skin → name):** pink=POGO, blue=BUTCH, green=ZIGGY, yellow=PUFF, purple=VEX,
  orange=BILLY (`docs/briefs/character_theme_bible.md`). Ceremony screens say the NAME, with
  "P#" as the small secondary — personality everywhere.
- **No voice-over exists or is planned.** All charm = motion + SFX + typography. Every beat below
  names an SFX hook on the existing AudioManager SFX layer.

Pad glyph chips (used by the legend AND the victory prompt row) are a NEW reusable control,
`PadGlyph`: a 44px circle Panel, chocolate 4px border, colored fill per Xbox convention
(A `#54c94a`, B `#ff4b3a`, X `#4aa8ff`, Y `#ffc93f`, stick = cream circle with a chocolate ⊕ cross
drawn), white 26px letter with 6px chocolate outline. **Drawn from theme styleboxes — zero art
needed.** Keyboard fallback = same chip, cream fill, chocolate text ("SPACE", "K", "L", "WASD"),
width grows to fit. Shown variant follows the device that last produced input (pad connected +
used → pad glyphs; else keyboard).

---

## 1. STAGE INTRO CARD

### Intent
Every Brawl stage gets a title card — "STAGE 3" + arena name — so arenas stop being anonymous and
the circuit feels like a show. **It costs ZERO added seconds:** it rides on top of the existing
STAGE_INTRO pop-in + countdown window (~1.4s pop-ins + 1.8s countdown that already exist), never
gating state. Eager players lose nothing; there is nothing to skip because it delays nothing.

### Sequence (exact, with the existing flow)
```
STAGE_END freeze ends → SCOREBOARD (3.4s hold / skippable ≥0.8s — UNCHANGED)
  → ScoreScreen.dismiss() 0.15s fade (existing)
  → _begin_stage(): level rotated, camera snapped, state = STAGE_INTRO
      t=0.00  intro card SLIDES DOWN into the upper band (spec below)
      t=0.00+ player pop-ins stagger as today (Tuning.intro_pop_stagger)
      t≈1.40  _start_countdown() fires (existing timing)
      t=CD    on the first countdown beat ("3"): card EXITS (pop-out up + fade 0.20s)
  → countdown → BOUNCE! (all existing)
```
First stage of a match: identical (card appears over the very first pop-in). The card NEVER
appears during SUDDEN DEATH revives or tiebreaker banners (those own the drama).

### Layout (1920×1080)
Anchored top-center, vertical center of the card at **y = 190** (below the 15% top band used by
show_top, above the arena's action; corner cards live in corners — no overlap).

```
                 ┌──────────────────┐
                 │   ● STAGE 3 ●    │   ← chocolate RIBBON chip (theme "Ribbon"), cream text
                 └──────────────────┘      CardTag-style 30px, letter-spaced, 2 gold 8px dots
              S I N G U L A R I T Y        ← BannerTop style upsized: 84px white,
                 ═══════════════           16px chocolate outline; gold underline ribbon
                                             (6px tall, 60% of name width, rounded)
```
- Ribbon chip: auto-width, 12px v-padding. Text "STAGE %d" — cream `#FFF` on chocolate.
- Arena name: 84px, white, chocolate outline 16 — reads at 10 feet over any arena art.
- Gold underline: the "confidence stroke"; scales in x 0→1 (0.22s, EASE_OUT) after the name lands.
- Match-point stages: ribbon text becomes "STAGE %d — MATCH POINT" and the ribbon fill goes
  DANGER red (the existing MATCH POINT top banner at countdown stays; they read as one system —
  card at y190, top banner in the 15% band above it, never simultaneous because the card exits on
  beat "3" and MATCH POINT fires at countdown start… **order fix below in §1-integration**).

### Motion timeline
| t | element | motion |
|---|---|---|
| 0.00 | ribbon chip | slide from y −120 → rest, 0.28s TRANS_BACK EASE_OUT, a 0→1 in 0.12s |
| 0.10 | arena name | scale-pop 0.6→1.0, 0.22s TRANS_BACK EASE_OUT (staggered 0.10 behind chip) |
| 0.32 | gold underline | scale_x 0→1, 0.22s EASE_OUT |
| hold | whole card | idle micro-bob: y ±3px sine, 1.8s period (alive, not distracting) |
| countdown beat "3" | whole card | pop-out: scale→1.15 + fade 0.20s, slight upward drift −30px |

SFX hooks: card land = the existing UI "thunk/pop" family; underline sweep = short "shing" (reuse
any existing sweep; if none, silent is acceptable v1).

### Input map
None. The card is non-interactive and non-blocking. Accept during STAGE_INTRO does what it does
today (nothing). This is deliberate — the no-added-time rule IS the skip.

### Degraded states
- **Long names** (e.g. "BUMPER GAUNTLET", future longer): name label max width 1400px with
  autoshrink (84 → floor 56px) before wrapping; never two lines.
- **2 players:** identical (card position independent of roster).
- **Trials/Sports:** OFF for v1 (Brawl only — trials has its own home/hint panel; sports has
  kickoff). The component should still be mode-agnostic so we can opt modes in later.
- **Placeholder-safe:** the card is pure theme styleboxes + text. No art dependency at all.

### Integration points (PartyMatch)
- New `StageIntroCard.tscn` (CanvasLayer, layer above HUD like ScoreScreen) instanced once in
  `PartyMatch._ready()` alongside `_score_screen` (Brawl gate: same `wants_scoreboard()` check is
  fine for v1).
- Show: end of `_begin_stage()` — it already has `stage_index` and `level_name`; add
  `_intro_card.present(stage_index, level_name, match_point_pending)` where
  `match_point_pending = _pending_match_point.size() > 0`.
- Hide: first beat of `_tick_countdown()` (when `_cd_beat` first becomes 0) call
  `_intro_card.exit()`.
- **Sequencing fix:** `_start_countdown()` currently fires the MATCH POINT `show_top` at
  countdown start, which would sit directly above the card for ~0.2s of card-exit. Acceptable
  overlap — but if it reads noisy in capture, delay the MATCH POINT top banner by 0.25s.

---

## 2. FIRST-STAGE CONTROLS LEGEND

### Intent
The owner didn't know powerup = pad B. Fix it with a **charming glyph strip, not a tutorial** —
Duck Game teaches with 5 words, so do we. Shows on **stage 1 of every Brawl match**, vanishes
early into combat. It's small enough to never annoy a veteran and present exactly when a
first-timer's eyes are free (pop-in + countdown = no gameplay yet).

Real input map (verified in project.godot): move = stick/WASD · boost/fly = **A** / SPACE ·
super = **X** / K · powerup = **B** / L. There is NO taunt action — do not show an unbound
glyph; reserve Y for taunt later (logged as a future want, not this slice).

### Layout
Bottom-center strip, anchored y = 1080 − 96 (clear of corner cards which hug the corners), one
row of cream chips in the HintStrip language (chip_normal stylebox), 20px gaps:

```
   ┌────────────┐ ┌───────────────┐ ┌──────────────────┐ ┌──────────────┐
   │ (⊕)  MOVE  │ │ (A)  FLY      │ │ (X)  SUPER SMASH │ │ (B)  POWERUP │
   └────────────┘ └───────────────┘ └──────────────────┘ └──────────────┘
```
- Each chip: `PadGlyph` (44px, §0) + label, `CardTag` style at 26px chocolate-on-cream,
  14px internal padding, chip corner radius 18 (existing chip_normal).
- Word choice is personality: "FLY" not "boost/jetpack" (the fantasy verb), "SUPER SMASH" not
  "super", "POWERUP" plain (it is the thing being taught).
- Keyboard variant swaps glyph chips per §0 (WASD / SPACE / K / L).

### When it shows (exact)
- Condition: `stage_index == 1` of a Brawl match (every match — cost is ~6 quiet seconds; if the
  owner later finds it repetitive, gate behind a `Settings` "matches played < 5" counter, but DO
  NOT build that yet).
- Appear: with the stage intro card at `_begin_stage()` t=0 — chips pop in left→right, 0.15s
  each, 0.12s stagger (the house stagger). Total entrance 0.6s.
- Hold: through pop-in, countdown, "BOUNCE!" and the first **4.0s of COMBAT** (players get to
  TRY the buttons while reading them), then fade a→0 over 0.4s.
- Charm beat: when the player presses a listed button during the hold, that chip does a
  press-bounce (scale 1.0→0.88→1.0, 0.16s) — the strip answers you. (Poll P1's actions in
  `_process`; cheap and delightful.)
- Early out: pressing `use_powerup` (the button we most need to teach) after BOUNCE! fades the
  strip immediately (lesson learned).

### Trials variant — decision: **NO separate legend.**
Flight School (trials circuit 1) already teaches fly/super/combo/refuel with authored on-HUD hint
lines through TrialsHUD's hint-chip slot, which is the same visual language. Adding a second strip
would double-teach and crowd the compact home panel the owner just had us shrink. One addition
only: the Flight School course hints should name the button inline where relevant (e.g. hint text
"HOLD (A) TO FLY" — TrialsHUD hint is plain text; embedding "(A)" as text is acceptable there, no
glyph art). That is a one-line JSON text tweak, not a new system.

### Degraded states
- 2–4 players: unchanged (the strip teaches everyone at once; per-player strips = noise).
- No pad connected: keyboard variant.
- Narrow risk: 4 chips ≈ 900px total — fits 1920 with huge margin. No wrap case.
- Placeholder-safe: zero art (glyphs are drawn).

### Integration points
- New `ControlsLegend.tscn` (Control inside the same CanvasLayer as StageIntroCard, or its own).
- Show from `_begin_stage()` when `stage_index == 1` and mode is Brawl; start the combat fade
  timer from `_bounce_go()` (+4.0s); early-out on `Input.is_action_just_pressed(&"use_powerup")`
  polled in its own `_process` during COMBAT.

---

## 3. VICTORY CEREMONY

### Intent
Today MATCH_END is a text panel ("A/ENTER — REMATCH  B/ESC — QUIT") over the frozen arena. That is
the single most amateur-telling moment in the product. The winning kill is the hero moment — give
it a Mario-Kart-grade ceremony: winner's bust HUGE and mugging, WINNER typography, confetti, the
final tally in the ScoreScreen's own race-bar language, and a proper focused prompt row.

Terminal screen = pacing doctrine does NOT bind (the ≤3.4s hold governs *between-stage* flow;
nothing follows this screen). Still fast: **2.0s from freeze to interactive.**

### Screen composition (1920×1080, new `VictoryScreen.tscn` CanvasLayer over a scrim)
```
┌──────────────────────────────────────────────────────────────────────────┐
│                        (navy scrim 0.60 over frozen arena)               │
│                                                                          │
│              W I N N E R !                 ┌── FINAL SCORE (navy tray) ─┐│
│         ✦ (gold rays behind bust) ✦        │ 🐐 POGO  P1 ██████████ 10  ││ ← winner row gold-rimmed
│              ┌────────────┐               │ 🐐 BUTCH P2 ███████    7   ││
│              │  WINNER'S  │               │ 🐐 PUFF  P4 █████      5   ││
│              │    BUST    │  ← charge     │ 🐐 ZIGGY P3 ███        3   ││
│              │  ~640px    │    pose art   └───────────────────────────┘│
│              └────────────┘                                             │
│           POGO — PLAYER 1                                                │
│                                                                          │
│      ┌─(A) REMATCH─┐   ┌ CHANGE SETUP ┐   ┌     MENU     ┐              │
│      └─────────────┘   └──────────────┘   └──────────────┘              │
└──────────────────────────────────────────────────────────────────────────┘
```
Left column (winner altar) centered at x ≈ 620; standings tray right, x ≈ 1180–1800, vertically
centered. Prompt row bottom-center band, y ≈ 940.

**Type hierarchy**
1. "WINNER!" — BannerCenter family, **140px**, GOLD fill, 20px chocolate outline. THE word.
2. Winner name — "POGO — PLAYER 1", BannerSub 40px, fill = winner's PLAYER_COLORS entry,
   10px chocolate outline.
3. Standings tray header "FINAL SCORE" — StepTitle 28px cream; rows reuse the exact ScoreScreen
   row recipe (goat idle head 72px + name+P# + race bar to `match_target_kills` + tally number).
   Sorted descending by score; winner row gets a 4px GOLD border rim + gold tally.
4. Prompt buttons — ShellBtnPrimary (REMATCH, green primary) / ShellBtn (others), 46/40px.

**Winner art:** `assets/characters/bouncer_<skin>_charge.png` (the coiled hero pose — most
"mugging" of the three shipped poses), rendered ~640px tall, chocolate-outlined drop shadow via a
duplicated sprite tinted chocolate at +8y (cheap, reads as sticker). Fallback if a future skin
lacks charge: `_idle`. Behind it: gold rays (art order V1 below); degrade = a soft radial gold
glow drawn with a gradient — screen still ships.

**Confetti:** CPUParticles2D, two one-shot bursts (120 rects, 6–10px, PLAYER_COLORS palette +
gold, gravity 400, spread 70°) from the two upper corners, plus a lazy 8/s drizzle loop from the
top edge while the screen lives. Zero art.

### Motion choreography (t=0 = winning kill / `_enter_match_end`)
| t | beat |
|---|---|
| 0.00 | EXISTING: freeze, in-world punch-zoom on winner, `match_won` fanfare. Keep. The old `show_match_end` text panel is REMOVED for Brawl. |
| 0.90 | scrim fades in 0→0.60 over 0.25s (the arena beat breathes first — the kill stays visible) |
| 1.00 | bust slams in from below (y +260 → rest, 0.30s TRANS_BACK EASE_OUT) with a squash-settle (scale 1.0/0.85 → 0.92/1.06 → 1/1 over 0.18s after landing); confetti burst #1; big "thump" SFX |
| 1.15 | "WINNER!" pops (0.3→1.0, 0.18s BACK) + confetti burst #2; fanfare stinger already ringing |
| 1.30 | winner name pops (house pop, 0.15s) |
| 1.45 | standings tray slides in from right (x +320 → rest, 0.28s BACK EASE_OUT); rows' bars fill 0→final over 0.5s with 0.12s stagger (ScoreScreen recipe verbatim — it is the same component language, final chapter) |
| 2.00 | prompt row pops in (3 buttons, 0.12s stagger); **input arms here**; REMATCH holds focus with the gold focus ring + idle pulse (scale 1.0↔1.045, 1.2s sine — the "press me" breath) |
| loop | bust idle bob (scale 1.0↔1.03, 1.6s sine); confetti drizzle |

Skip: any accept press between 0.9s and 2.0s **fast-forwards all tweens to their end state**
(everything lands instantly, input arms). Never a black cut — fast-forward, don't skip content.

### Input map (from t=2.0 / fast-forward)
| input | action |
|---|---|
| dpad/stick LEFT-RIGHT | move focus across REMATCH / CHANGE SETUP / MENU (wraps) |
| A / ENTER | activate focused button (default focus = REMATCH → `_start_match()`) |
| B / ESC | first press: focus jumps to MENU (safe, reversible); second press: activates MENU |
| Y / X / triggers | nothing (reserved) |
| before t=2.0 | accept = fast-forward; everything else ignored |

Focus state must be unmistakable at 10 feet: focused button scales 1.12 with the theme's gold
`card_focus`-style ring + `card_glow` bloom behind; unfocused buttons sit at 1.0, 85% opacity.
Focus moves with a 0.12s spring.

Button actions:
- **REMATCH** → existing `_start_match()` (same config, fresh shuffle-bag). Unchanged behavior.
- **CHANGE SETUP** → `change_scene_to_file(SHELL_SCENE)` with a `GameConfig` flag (e.g.
  `GameConfig.resume_setup = true`) so ShellRoot deep-links into the mode's setup/CharacterSelect
  with the current `match_config` intact (players keep their picks; that is the point of the
  button). If the deep-link is more than ~30 min of shell plumbing, v1 fallback = land on
  ModeSelect with config preserved — still honest.
- **MENU** → `change_scene_to_file(SHELL_SCENE)` plain (today's QUIT path).

### Degraded states
- **2 players:** standings tray = 2 rows, tray height shrinks to content (VBox), stays vertically
  centered. Fine.
- **>4 players (5–8):** rows drop the head icon to 56px and row height compacts — this is the
  already-logged "ScoreScreen row sizing >4" issue; the ceremony inherits whatever fix ScoreScreen
  gets. Do not fork the row recipe.
- **Bot wins:** identical ceremony, name reads "BUTCH — CPU" (subline swaps PLAYER n → CPU).
  A bot mugging on the podium is comedy, not a bug.
- **Won-on-points-while-dead:** existing respawn-for-the-bow logic keeps working underneath; the
  scrim covers the arena anyway.
- **Missing rays art:** radial gradient glow fallback (spec'd above) — screen ships regardless.
- **Trials / Sports:** keep their current `show_match_end` panel this slice (their end states have
  different semantics — set summary / team win). The VictoryScreen is Brawl-only v1, but build it
  data-driven (`present(winner_idx, rows, target, title)`) so Sports can adopt it next slice.

### Integration points (exact)
- `PartyMatch._enter_match_end(widx)` — after the existing punch-zoom/fanfare block: instantiate/
  present `VictoryScreen` at t+0.9 (timer), passing winner idx, sorted row dicts (same shape as
  `_enter_scoreboard()` builds: pn/color/skin/score — plus `name` from a skin→name map),
  and `match_target_kills`. Suppress the `_hud.show_match_end(...)` call for Brawl.
- `PartyMatch._tick_match_end()` — delegate: while VictoryScreen is live it owns input; keep
  `PROMPT_GUARD` semantics inside the screen (input arms at its own t=2.0). `_start_match()` must
  also `queue_free`/dismiss the screen (mirror of `_score_screen.dismiss()`).
- `MatchHUD.show_match_end/show_match_prompt` stay (Trials/Sports still call them).
- `EventBus.match_won` already fires the fanfare — no audio plumbing needed; add one generic UI
  "thump" and reuse existing pops for the beats above (whatever exists in AudioManager's SFX set;
  silence over new-audio scope creep).

---

## 4. Art orders (minimal — everything else is theme-drawn or existing assets)

| id | asset | one-line prompt sketch | degrade if absent |
|---|---|---|---|
| V1 | `assets/ui/victory_rays.png` | 1024px square, glossy-toybox radial sunburst of chunky rounded gold rays (#ffd23f core → transparent), chocolate-outlined ray edges, sticker style, transparent bg | radial gold gradient glow |
| V2 (optional) | `assets/ui/crown.png` | small chunky toy crown, gold with chocolate outline + 3 candy gems, 3/4 tilt, sticker style — perched on the winner bust at a jaunty 12° | omit (bust alone reads) |

Explicitly NOT ordered: pad glyphs (drawn), confetti (particles), stage-card ribbon (theme
styleboxes), podium art (race-bar tray replaces a podium — stays in our established score
language and dodges new art risk).

## 5. Pacing-doctrine flags
- **ScoreScreen 3.4s hold: untouched.** Stage intro card adds **0.0s** — it overlaps the existing
  STAGE_INTRO/countdown window and never gates state. This is the load-bearing constraint; if any
  implementation makes the card gate `_start_countdown()`, that is a REJECT.
- Controls legend adds 0.0s (overlay only, self-fades).
- Victory ceremony: 2.0s to interactive on a TERMINAL screen (old flow was 1.0s PROMPT_GUARD).
  Deliberate and owner-aligned (ceremony is the ask); accept fast-forward keeps impatient rematch
  spam at ~1.0s effective. DECISIONS.md ≤4.5s turnaround is already superseded (2026-07-16 entry)
  and never applied to match end.

## 6. Acceptance (how I will grade — screenshots/bursts via run_game.ps1 + gbplay)
1. Intro card burst: slide-settle visible, exits on beat "3", countdown timing byte-identical.
2. Legend: 4 chips, correct glyph colors/letters, press-bounce responds, gone by BOUNCE!+4.4s.
3. Victory burst at 0.9/1.0/1.2/1.5/2.0s: bust slam squash reads, WINNER! gold at 140px,
   bars filled, focus ring unmistakable in a 25%-scale thumbnail (the 10-foot test).
4. 2P and 4P matches, a bot win, and a long arena name ("BUMPER GAUNTLET") all captured.
5. Zero OS widgets, zero misalignment, chocolate outlines on every interactive element.
