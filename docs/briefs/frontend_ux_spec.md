# Front-End UX Spec — GottaBounce Shell (Phase 1)

> Owner: UI/UX Designer. Status: **the build contract.** A gameplay-programmer builds every shell
> screen to THIS document without making further UX decisions; I approve the built result from
> in-engine screenshots against §7 before Phase 1 ships.
>
> This spec is the visual+interaction layer on top of two contracts that stay authoritative:
> - **Functional flow / GameConfig / navigation graph:** `docs/specs/v1_frontend_shell.md` (do not
>   re-derive it here — I reference its screen list, its `GameConfig` fields, and its §1.4 input rules).
> - **Art-direction baseline:** `docs/briefs/frontend_shell_visual_brief.md` (palette, backdrop,
>   the 3 new styleboxes, ≤0.3s transitions). I EXTEND it with exact numbers, a full component library,
>   the CharacterSelect showcase, and the per-character slot contract.
> - **The cast:** `docs/briefs/character_theme_bible.md` (the Herd — Pogo/Butch/Ziggy/Puff/Vex/Billy).
>
> The bar is **Mario Kart 8 / Duck Game / TowerFall** front-ends: big confident type, full-bleed art,
> springy tactile motion, focus you can read across a living room, character personality everywhere.
> Bounce is the identity — nothing on any screen is ever perfectly still.
>
> **Design principle for every number below:** overshoot, then settle. Linear motion is banned.
> Every focus, press, and transition uses a spring/back curve so the whole shell feels made of rubber.

---

## 0. Vocabulary & global constants

**Canvas:** 1920×1080 design resolution, everything under one `CanvasLayer` per screen. Positions in
this doc are given as % of viewport unless a px value is stated (px values are at 1080p).

**The 8-point spacing scale** (use ONLY these gaps — this is what makes six screens feel like one
product). Name them as constants in the shell script or a `Layout.gd` helper:

| Token | px | Use |
|---|---|---|
| `SP_XS` | 8 | inside a control (icon↔label), pip gaps |
| `SP_S` | 16 | label↔control, tight stacks |
| `SP_M` | 24 | button-stack separation, card inner padding |
| `SP_L` | 40 | between cards in a row/grid |
| `SP_XL` | 64 | region↔region (header↔content) |
| `SP_XXL` | 96 | outer screen margins (left/right safe area) |

**Safe area:** nothing interactive within 64px (`SP_XL`) of any screen edge — couch TVs overscan.
Header lives in the top 12% band, footer in the bottom 10% band, content in the middle 70% with a
`SP_XXL` (96px) left/right margin.

**Global color roles** (from the visual brief §0 — do not go off-book):
- Chocolate outline `#3B2419` — on EVERY interactive element. The brand line.
- Card cream `#FFFFFF @ 0.94`. Panel navy `#141428 @ 0.85`. Sub-screen scrim `#141428 @ 0.55`.
- Accent default = P1 Pink `#FF5FA8`. Affirmative/confirm = P3 Green `#54C94A`.
- The six hero colors (from the theme bible §2): Pogo `#FF5FA8`, Butch `#4AA8FF`, Ziggy `#54C94A`,
  Puff `#FFC93F`, Vex `#A15FFF`, Billy `#FF7A2D`.

**Global easing grammar** (Godot `Tween.set_trans` / `set_ease`):
- **Focus in / press pop / screen settle:** `TRANS_BACK`, `EASE_OUT` — the springy overshoot. Default.
- **Focus out / press-down / screen exit:** `TRANS_QUAD`, `EASE_IN` — quick, no bounce.
- **Idle breathe / drift / parallax:** `TRANS_SINE`, `EASE_IN_OUT`, looping.
- **Slider knob step & toggle slide:** `TRANS_BACK`, `EASE_OUT`, short (0.10–0.15s).
- **Confirm squash-stretch:** `TRANS_ELASTIC` `EASE_OUT` on the settle leg only (the juicy one).

Durations are capped at 0.3s for anything the player waits on (transitions). Focus/press feedback is
0.10–0.20s. Idle loops are 0.9–3.1s.

**Audio:** call `AudioManager.play_sfx("ui_click")` on every activation (per functional spec §1.4).
Additionally: on focus-move play a lighter `ui_move` if one exists, else pitch-shift `ui_click` to
+4 semitones at 0.6 volume (programmer: if no `ui_move` asset, skip rather than reuse click at full
volume — a loud click on every d-pad tap is fatiguing). Character-select confirm triggers the
character's voice callout (see §3.6) — cheap if the goat-scream/voice SFX exist; skip gracefully if not.

---

## 1. The reusable menu system

Six screens, ONE component vocabulary. Everything below is built once and reused. If a screen needs a
new visual, it is a variation of one of these — never a bespoke widget.

### 1.1 New styleboxes to add to `theme.tres`

The visual brief named these; here are the exact numbers. All keep **4px chocolate `#3B2419` border,
16px corner radius** unless noted (that consistency IS the polish). Add as `StyleBoxFlat` sub-resources
+ theme type-variation entries.

**`MenuButton`** (base_type `Button`) — three styleboxes (`normal`/`hover`/`pressed`) + a `focus`
stylebox equal to `hover`:

| stylebox | bg | border | radius | shadow | content margins |
|---|---|---|---|---|---|
| `normal` | `#FFFFFF @ 0.94` | 4px `#3B2419` | 16 | size 5, offset (0,3), `#1E1109 @ 0.30` | L/R 28, T/B 16 |
| `hover`+`focus` | `#FFFFFF @ 1.0` | **6px** `#3B2419` | 16 | **size 10**, offset (0,5) | same |
| `pressed` | `#EDE6DA` | 6px `#3B2419` | 16 | **size 2**, offset (0,1) | same |

- Fonts: `MenuButton/font_sizes/font_size = 40`, `font_color = #3B2419` (dark ink on cream — reads on
  the bright sky), `font_outline_color = #FFFFFF`, `outline_size = 6` (a thin cream halo so dark text
  never muddies against the card border). Min size **380×76**.
- `MenuButton` also sets `Button/constants/h_separation` and disables the default focus stylebox by
  making `focus` identical to `hover` (Godot draws focus on top of hover; we drive the real focus read
  via the scale/glow tween in §1.3, NOT a border-only ring).

**`MenuButtonPrimary`** (base_type `Button`) — PLAY / CONFIRM / READY / RESUME. Same geometry, larger:
- `normal` bg = P3 Green `#54C94A`; `hover`/`focus` bg = `#63DE57` (brightened green); `pressed` bg =
  `#48B03F`. Border 4px→6px on focus as above. Shadow same schedule.
- Font `font_size = 46`, `font_color = #FFFFFF`, `font_outline_color = #3B2419`, `outline_size = 10`.
  Min size **420×92**. This is the one green thing on the screen — the eye must land on it.

**`MenuCard`** (base_type `PanelContainer`) — mode / character / arena cards.
- `normal` = the existing `StyleBoxFlat_card` verbatim.
- `focus` = duplicate with `border_color` set to the accent/hero color at runtime, `border_width = 8`,
  `shadow_size = 16`, `shadow_color` = accent @ 0.45 (a colored drop-glow, not just grey). Programmer
  builds ONE `focus` stylebox and recolors `border_color`+`shadow_color` per card in code.
- `soon` (locked/coming-soon variant) = duplicate of `normal` with `bg_color = #FFFFFF @ 0.94` but the
  card's inner content modulated to `Color(0.62,0.60,0.58)` (desaturated, NOT greyed to death) and a
  ribbon (see §2.2). The card border stays full chocolate — a locked card is still a beautiful object.

**`MenuCardGlow`** (base_type `Panel`) — an OPTIONAL soft halo drawn BEHIND a focused card: a
`StyleBoxFlat`, bg = accent @ 0.0 (transparent fill), border 0, `shadow_size = 28`,
`shadow_color` = accent @ 0.40, radius 22. It's a pure glow plate; tween its `modulate:a` 0→1 on focus.

**`ToyTrack`** / **`ToyFill`** / **`ToyKnob`** — Options slider (see §4). Reuse `FuelBG`/`FuelFill` DNA.

**`ToyToggleTrack`** / **`ToyToggleKnob`** — Options pill switch (see §4).

**New font variations** (theme type-variations, base_type `Label`):
- `Hint` — `font_size 28`, `font_color #FFFFFF @ 0.90`, `outline_size 8`, chocolate outline. Footer hints.
- `CardName` already exists (26px) — **bump to 34px** for character/mode card names; they are the
  loudest label on those cards. (Add a `CardNameBig` variation at 34 rather than editing CardName if
  CardName is used elsewhere; grep first — it is used on in-match cards, so ADD `CardNameBig` 34px.)
- `CardTag` — `font_size 22`, `font_color #3B2419`, `outline_size 4` cream, for card one-line taglines
  (dark ink on cream cards). `ModeTitle` — `font_size 56`, for the big mode-card titles.
- `StepValue` — `font_size 30`, chocolate outline, for stepper/slider numeric read-outs.

### 1.2 The three interactive primitives

Everything on every screen is one of these, so navigation and focus behave identically everywhere:

1. **Button** (`MenuButton` / `MenuButtonPrimary`) — a labelled action. Vertical stacks (MainMenu,
   Pause) or single confirm buttons (footer).
2. **Card** (`MenuCard`) — a big selectable tile with art + name + optional tagline. Rows (ModeSelect,
   CharacterSelect grid) or grids (ArenaSelect). A card IS a focusable control (make the
   `PanelContainer` a `focus_mode = ALL` `Control`, or wrap in a `Button` with a transparent flat
   style and the card as its child — **decision: wrap the card visuals in a `Button` set to
   `flat=true` with the `MenuCard` styleboxes assigned to the Button; simplest focus + press for free**).
3. **Stepper / Slider / Toggle** — value editors (settings strip + Options). Left/right adjusts.

### 1.3 The focus / selection model (the single most important thing)

On a couch 8 feet from a TV, the player must know what is focused in under 200ms without hunting. Focus
is never a thin ring — it is a **loud, springy, multi-signal state**. The focused control gets ALL of
these AT ONCE, and unfocused siblings get NONE:

**On focus-IN (fires together):**
1. **Scale up** — buttons `1.0 → 1.08`, cards `1.0 → 1.14`. Set `pivot_offset = size * 0.5` FIRST so
   it scales from center. `TRANS_BACK`, `EASE_OUT`, **0.18s**. (This mirrors the in-match HUD banner
   pop at `TRANS_BACK EASE_OUT` — the shell and the game share one motion family.)
2. **Lift** — the `focus` stylebox's bigger shadow (size 10 buttons / 16 cards) makes it float above
   flat siblings. Comes for free with the stylebox swap.
3. **Color glow** — border repaints to the accent color (default P1 Pink; the hero's own color on
   CharacterSelect; the mode/arena theme color elsewhere) at 6–8px width, plus the `MenuCardGlow`
   halo plate fading 0→1 over 0.18s.
4. **Idle wobble** — ONLY the focused item gets a continuous breathe: scale oscillates
   `±2%` around its focused scale (e.g. card `1.12 ↔ 1.16`) on a **0.9s** `TRANS_SINE EASE_IN_OUT`
   loop, plus a micro-rotation `±1.0°` on a **1.3s** offset loop (never synced — organic toy jiggle).
   Unfocused items are dead still. This is what makes the selection feel *alive*, and it's the single
   cheapest "this is a real game" tell.

**On focus-OUT:** reverse scale to 1.0, drop shadow, border back to chocolate, halo fades to 0, wobble
loops killed. `TRANS_QUAD`, `EASE_IN`, **0.12s** — snappier than focus-in so the new item "wins" the
eye. The net read is the selection *bouncing* from the old item to the new one: old shrinks fast, new
pops with overshoot.

**On PRESS / confirm (A / Enter / click):**
- Quick squash-then-pop: scale `→ 0.92` in **0.06s** (`TRANS_QUAD EASE_IN`), then overshoot to `1.16`
  and settle to focused rest with `TRANS_ELASTIC EASE_OUT` over **0.22s**. Play `ui_click`. THEN start
  the screen transition (they overlap — the outgoing screen begins exiting ~0.08s into the pop so the
  press reads before the swap).

**On BACK (B / Esc):** no punishment animation on the control; the whole screen does the reverse
transition (§1.5). Play a lower-pitched `ui_click` (or `ui_back` if it exists).

**Rules that make it bulletproof:**
- **Exactly one thing is always focused** on every screen. Each screen calls `grab_focus()` on its
  designated first control in `_ready`/on-enter (specified per-screen below).
- Full `focus_neighbor_left/right/top/bottom` wired on every control so d-pad, left-stick, arrows, and
  Tab all traverse with no dead ends. Wrap-around at row/grid edges (right on the last card wraps to
  first) — TowerFall/MK convention, feels good.
- **Hover = focus.** Mouse hover calls the same `grab_focus()` so mouse and gamepad drive one identical
  state. No separate hover styling.
- Left-stick uses a deadzone of 0.5 and a re-trigger cooldown of 0.18s so a held stick steps one item
  at a time (not a blur) — same cadence as d-pad.

### 1.4 The shared screen skeleton

Every sub-screen (ModeSelect/CharacterSelect/ArenaSelect/Options) is the SAME three-region frame so
the player's eye never has to re-learn where things are:

```
+-------------------------------------------------------------------+
|  [< BACK]        S C R E E N   T I T L E                          |  header  12% H
|-------------------------------------------------------------------|
|                                                                   |
|                  content region (cards / list / rows)             |  content 78% H
|                                                                   |
|-------------------------------------------------------------------|
|  (A) Select   (B) Back   (<>) Change            v0.x   right-hints |  footer  10% H
+-------------------------------------------------------------------+
```

- **Background:** the SAME living title backdrop as MainMenu (§2.1), dimmed by the `#141428 @ 0.55`
  scrim so content pops. The backdrop keeps parallax-drifting behind the scrim on every screen — the
  world never freezes.
- **Header:** `BannerTop` (58px) screen title, left-aligned starting at `SP_XXL`. A `< BACK`
  chevron-button (`MenuButton`, compact 180×64) pinned far-left; it is a real focusable control but is
  the LAST in focus order (you reach it by pressing B, not by tabbing to it first).
- **Footer:** a single-line `Hint` strip, left-aligned, showing live controls with glyph tokens:
  `(A) Select   (B) Back   (◀ ▶) Change`. The glyph in parentheses is a small chocolate-outlined
  rounded chip (reuse `PipEmpty` DNA at ~34px) with the letter inside — NOT literal Xbox glyphs
  (avoids a platform-glyph asset dependency for Phase 1; a real glyph set is a Phase-2 nicety). Right
  side: version string, `Hint` @ 0.6 alpha.
- Header slides down from -60px and footer up from +60px on screen-enter (`TRANS_BACK EASE_OUT` 0.25s,
  0.04s after content starts) so the frame itself assembles with a bounce.

### 1.5 The screen-transition grammar (one vocabulary, whole shell)

Persistent `ShellRoot` swaps one screen child at a time (per functional spec §1.2 recommendation).
Each screen is a `Control` that owns an `enter()` and `exit()` animation:

- **FORWARD (deeper into flow):** outgoing screen `scale 1.0→0.95`, `modulate:a 1→0` over **0.18s**
  (`TRANS_QUAD EASE_IN`). Incoming starts `scale 1.06`, `a 0`, settles to `1.0`, `a 1` with
  `TRANS_BACK EASE_OUT` over **0.28s**, its content staggering in on top (below). Reads as diving in.
- **BACK:** mirror — incoming from `0.95`, outgoing to `1.06`. Direction is legible from the motion
  alone.
- **Content stagger:** within an entering screen, the cards/buttons cascade: each item starts +60px
  below its rest position at `a 0`, tweens to rest `TRANS_BACK EASE_OUT` 0.30s, staggered **0.05s** per
  item (left→right for rows, top-left→bottom-right for grids). Never all-at-once, never a hard cut.
- **MATCH START (final CONFIRM on ArenaSelect):** the pressed button does its squash-pop, then a fast
  full-screen iris/scale-through wipe (a chocolate-outlined cream circle expands from the button to
  fill the screen over 0.22s) that covers the real `change_scene_to_packed` to `Arena.tscn`. Hand off
  directly to the existing in-match "3-2-1-BOUNCE!" banner — do NOT add a second countdown.
- **Pause overlay** is not a screen swap — see §2.6.

All transition durations ≤0.3s. The shell must feel *instant and springy*, never sluggish.

---

## 2. Per-screen layout + interaction

### 2.1 MainMenu (title)

The store hero shot. Follows the visual brief §1 composition; concrete here.

**Layout (1920×1080):**
- **Backdrop (full-bleed):** `assets/ui/title_bg.png` (copy of `style_north_star.png`),
  `TextureRect STRETCH_KEEP_ASPECT_COVERED`, with a slow Ken-Burns `scale 1.06 → 1.0` over a 12s
  `TRANS_SINE EASE_IN_OUT` ping-pong loop. NO scrim on MainMenu (the art carries the title).
- **The Herd, alive:** the cast are the parallax life. Place **Pogo (pink) and Butch (blue) as the two
  hero bobbers** front-and-center-lower, flanking the button stack (Pogo left, mid-boing; Butch right,
  winding a headbutt) — bounce-kid meets smash-bro, the whole game in one frame (theme bible §3). The
  other four (Ziggy/Puff/Vex/Billy) drift smaller in the mid/background at different depths and speeds.
  Each bobber = a `TextureRect` of the character's idle sprite (Phase-1 placeholder: the four existing
  `bouncer_*_idle.png`; the two extras reuse recolored idles until art lands) on an independent
  vertical bob (`y ±14px`, 1.6–2.4s sine, randomized phase) + slow horizontal drift + a `±3°` sway.
  Nothing is ever still.
- **Logo:** `assets/ui/logo.png` `TextureRect KEEP_ASPECT_CENTERED`, width **46%** of viewport, pinned
  top-center, 8% top margin. Idle breathe `scale 1.0↔1.03` (2.6s sine) + `±1.5°` rotation (3.1s, offset
  so never synced). Enter: drops from `scale 0.6` +40px above, settles `TRANS_BACK EASE_OUT` 0.35s.
  Typographic fallback per visual brief §1 if PNG missing.
- **Button stack:** `VBoxContainer`, centered horizontally, vertical center ~62% down, width ~34%,
  `SP_M` (24px) separation. **PLAY** (`MenuButtonPrimary`, green, heaviest), **OPTIONS**, **QUIT**
  (both `MenuButton`). Enter: cascade bottom-up, each +60px below rest, 0.05s stagger,
  `TRANS_BACK EASE_OUT` 0.30s.
- **Footer:** version bottom-left, "© GottaBounce Studio" bottom-right, both `Hint` @ 0.6. A thin
  grass-green (`#6CC24A`) band across the bottom 8% is optional (ties to the north-star grass).

**First focus:** PLAY.

**Input:**
- Up/Down (d-pad / left-stick / arrows) move focus through PLAY→OPTIONS→QUIT (wrap).
- A / Enter: activate. PLAY → forward-transition to ModeSelect. OPTIONS → Options (opened-from = main).
  QUIT → confirm micro-dialog (see below) then `get_tree().quit()`.
- B / Esc: nothing on MainMenu (per functional spec — MainMenu back is a no-op; do not exit on B).
- **QUIT confirm:** rather than quitting instantly, QUIT pops a small centered navy panel
  (`MatchEndPanel` stylebox) "QUIT GOTTABOUNCE?" with `[STAY]` (primary, first focus) and `[QUIT]`.
  Cheap insurance against a fat-fingered exit; B closes it. (Functional spec left QUIT as an explicit
  button; this confirm is a UX safety add, not a flow change.)

**Animates:** backdrop Ken-Burns, six bobbers, logo breathe+rotate, button cascade on enter, focus
wobble on the selected button.

### 2.2 ModeSelect — SELL the modes

This screen's job: make a first-timer *want* the modes that don't exist yet. COMING-SOON cards must
look like a promise, never a disabled-grey dead end.

**Layout:**
- Shared skeleton. Header title: **"CHOOSE YOUR GAME"**.
- Content: a horizontal `HBoxContainer` of **4 big mode cards**, centered, `SP_L` (40px) gaps. Each
  card is large and portrait-ish (**~380×520**) so the row fills the content band confidently.
- Card order left→right: **BRAWL** (enabled), **TRIALS**, **GAUNTLET**, **SPORTS** (all SOON).

**Each mode card (`MenuCard`) contains, top→bottom:**
1. A **key-art panel** (top ~60% of the card): a rounded inner tile, chocolate-outlined, filled with
   the mode's theme color as a gradient (top brighter→bottom darker) so it's a deliberate colored
   plate, never a flat block. Phase-1 placeholder art: a big centered chocolate-outline glyph/emoji-free
   pictogram drawn from primitives (BRAWL = crossed-horns / impact-star; TRIALS = a stopwatch ring;
   GAUNTLET = a stack of chevrons; SPORTS = a ball). When real mode art lands it drops into this slot.
2. **Mode title** (`ModeTitle` 56px, chocolate ink) — "BRAWL".
3. **One-line tagline** (`CardTag` 22px) — BRAWL: *"Last one flying wins."* TRIALS: *"Beat the clock,
   beat your friends."* GAUNTLET: *"Survive the endless Herd."* SPORTS: *"Headbutt the ball, not each
   other. (Okay, each other too.)"*

**COMING-SOON treatment (make it gorgeous, not dead):**
- Card uses the `soon` variant: inner content desaturated to ~62% (still colored, still glossy), NOT
  greyed out.
- A **chocolate ribbon** sashed across the top-right corner at ~-35°, cream text "SOON" (`CardTag`,
  chocolate outline). The ribbon is a rotated `PanelContainer` with the chocolate fill — a real toy
  ribbon, an intentional object.
- A small padlock chip is NOT used (reads as punishment). Instead the card still gently idle-bobs when
  focused (yes, you can focus it) but on A it does a "locked" wiggle: a quick `±3°` head-shake rotation
  (0.25s `TRANS_BACK`) + a muted low `ui_click` and a footer toast "Coming soon!" — playful, not a
  buzzer. This lets a curious player poke every card and get personality feedback, never a dead press.

**First focus:** BRAWL.

**Input:**
- Left/Right move focus across the four cards (wrap). Focus fires the full §1.3 treatment; the glow/
  border take each card's theme color.
- A on BRAWL: forward-transition to CharacterSelect. A on a SOON card: the locked wiggle + toast above.
- B: back-transition to MainMenu.

**Animates:** cards cascade in left→right on enter; focused card scales 1.14 + wobble + colored glow;
BRAWL's key-art glyph has a tiny idle pulse to draw the eye to the one live mode; locked wiggle on
SOON press.

### 2.3 CharacterSelect — THE SHOWCASE

The most-looked-at screen in a couch party game. This is where "one more round, but as Butch this
time" is born. It must read as Mario Kart's roster: a full grid, the picked character striking a pose
big on stage, a bold name banner in their color, and per-player pick-cursors. Design consumes
**per-character asset slots** so it works with placeholder idles today and the real portraits when the
art bible lands.

#### 2.3.1 The per-character slot contract (art hand-off)

Each hero is one data entry the screen renders from. The programmer builds a
`res://data/characters/*.tres` (or a dict) per hero with these slots; CharacterSelect reads them and
never hardcodes a character. This is the seam the art bible (in parallel) fills:

| Slot | Type | Placeholder (today) | Real art (art bible) |
|---|---|---|---|
| `id` | StringName | `&"pogo"` … | same |
| `display_name` | String | "POGO" | same |
| `color` | Color | `#FF5FA8` … (six hero hexes) | same |
| `blurb` | String | one-liner (below) | same |
| `portrait` | Texture (card thumb) | **cropped idle sprite** (`bouncer_pink_idle.png`) centered on card | painted portrait bust |
| `beauty_pose` | Texture (big stage art) | the SAME idle sprite, scaled up | full beauty/taunt pose |
| `taunt_frames` | Texture[] or SpriteFrames (optional) | none → stage art just bounces | idle/taunt loop |
| `voice_id` | StringName (optional) | none → skip | callout SFX on confirm |

**Slots for the six** (`blurb` = the one-line personality shown under the stage name):
- **POGO** `#FF5FA8` — *"Can't stop boinging. Won't stop boinging."*
- **BUTCH** `#4AA8FF` — *"Come at me. I've been stretching."*
- **ZIGGY** `#54C94A` — *"Watch THIS recovery."*
- **PUFF** `#FFC93F` — *"WHEEEE— wait which way?"*
- **VEX** `#A15FFF` — *"You may bow now."*
- **BILLY** `#FF7A2D` — *"Back in MY day the mountain was TALLER."*

The card + stage read fine with a cropped idle (the fallback is intentional, not a debug rect): the
card shows the sprite on a cream tile with a color name banner; the stage shows the same sprite big,
bouncing. When `beauty_pose`/`taunt_frames` land, only the texture swaps — zero layout change.

#### 2.3.2 Layout — split stage

```
+-------------------------------------------------------------------+
|  [< BACK]     C H O O S E   Y O U R   B O U N C E R               |  header 12%
|-------------------------------------------------------------------|
|                                   |                               |
|   STAGE (left ~42%)               |   GRID (right ~58%)           |
|                                   |                               |
|      big beauty pose,             |   [POGO] [BUTCH] [ZIGGY]      |  2 rows x 3
|      bouncing on a spotlight      |   [PUFF] [ VEX ] [BILLY]      |
|                                   |                               |
|   ####  P O G O  ####  <- banner  |                               |
|   "Can't stop boinging."          |   match-settings strip below  |
|                                   |   grid (steppers)             |
|-------------------------------------------------------------------|
|  (A) Ready   (B) Back   (<>) Pick   (Y) Random    ...P1 READY?    |  footer
+-------------------------------------------------------------------+
```

- **STAGE (left, ~42% width):** a "spotlight" — a soft radial cream glow (a `MenuCardGlow`-style plate)
  tinted to the current hero's color, on which the `beauty_pose` stands **large** (fills ~70% of the
  stage height). The pose continuously idle-bounces (squash-stretch, see §5) and, if `taunt_frames`
  exist, plays the taunt loop. Below the pose: a **name banner** — a chunky chocolate-outlined
  ribbon/plate filled with the hero's color, `BannerCenter`-scale name (use ~92px here, a touch under
  the 132 default) in white with chocolate outline; under it the `blurb` in `CardTag`/`BannerSub`.
  When focus moves to a new hero in the grid, the stage **swaps** with the character-swap animation
  (§5): old pose whips out, new pose bounces in, banner color cross-fades to the new hero color.
- **GRID (right, ~58% width):** a **2×3 grid** of `MenuCard`s (`~300×300`), `SP_L` gaps, centered in
  the right region. Each card: the `portrait` centered on the cream card, a slim color bar + name
  (`CardNameBig` 34px) along the bottom in the hero's color. Resting cards are calm; the focused card
  gets the full §1.3 treatment with ITS hero color as glow/border. This is the Mario-Kart grid.
- **Pick-cursors (couch multiplayer, design now / one active in Phase 1):** each active human player
  has a **color-outlined ring cursor** that lands on a grid card — a chunky rounded frame in that
  player's color (P1 pink … P4 yellow, the pick-cursor color = the PLAYER slot color, distinct from the
  hovered *character's* color) with a little "P1" flag tab pinned to the ring's top-left corner. Two
  players can hover the same card (rings stack/offset); a locked-in player's ring goes solid + a big
  color-matched check stamp pops on the card. Phase 1 shows P1's ring; the system supports up to 4.
- **Match-settings strip:** lives UNDER the grid in the right region (per functional spec §1.3), as a
  horizontal row of compact steppers — see §2.3.4. Keep it a strip, not a screen; it must not add a
  required tap to the "just start" path.

#### 2.3.3 Interaction

**First focus:** the grid card for P1's current character (default Pogo, top-left). The settings strip
is reachable but NOT first-focused.

- **Left/Right/Up/Down:** move P1's pick-cursor across the 2×3 grid (wrap horizontally; vertical moves
  between the two rows). Each move: focused card pops (§1.3), the STAGE swaps to that hero (§5), name
  banner recolors, and the hovered character does a little "notice me" bounce.
- **A (menu_accept):** **lock in** P1 on the hovered hero → ring goes solid, check stamp pops, the
  character plays its confirm callout (voice_id / goat-scream if present) and a big pose-jump on stage.
  Writes `GameConfig.character_ids[0]` + confirms. When ALL active humans are locked, the footer READY
  prompt lights green and A again (or auto-advance after a 0.4s beat) forward-transitions to
  ArenaSelect. In Phase 1 (1 human) one lock = ready.
- **Y / (keyboard R):** **RANDOM** — spins the cursor rapidly across the grid (a 0.5s slot-machine
  blur cycling cards with `ui_move` ticks) and lands on a random hero, then a celebratory pose. A
  beloved party-game beat, cheap to build.
- **B (menu_back):** if P1 is locked, first press UN-locks (ring hollow again); if not locked,
  back-transition to ModeSelect. (Standard fighting-game back semantics: B backs out of your lock
  before it backs out of the screen.)
- **To reach the settings strip:** pressing Down from the bottom grid row moves focus into the strip
  (or a dedicated `menu_settings`/Tab). Left/Right there adjusts the focused stepper; Up returns to the
  grid. The strip's focused stepper uses the row-focus treatment (§4 focus-whole-row).

#### 2.3.4 Match-settings strip (the steppers)

A horizontal row of five compact stepper controls, each `~200×88`, `SP_M` gaps, in a slim navy glass
sub-panel so it reads as a grouped settings tray distinct from the character grid. Each stepper:
a `CardTag` label on top, and a `[◀  VALUE  ◀]` row — two chocolate-outlined round chip buttons
flanking a `StepValue` number. Fields + defaults from functional spec §1.3 / GameConfig §2.2:

| Stepper | Values | Default | Writes |
|---|---|---|---|
| HUMANS | 1–4 | 1 | `human_count` (adds/removes pick-cursors live) |
| BOTS | 0–7 (clamp 2≤H+B≤8) | 3 | `bot_count` |
| BOT SKILL | Mixed, 1–5 | Mixed | `bot_difficulty` (0=Mixed) |
| KILLS | 5/7/8/10 | 10 | `kills_to_win` |
| LIVES | 1/2/3 | 1 | `lives_per_player` |

- Left/Right on a focused stepper decrements/increments with a **knob-bounce**: the value text pulses
  `scale 1.0→1.2→1.0` (0.12s `TRANS_BACK`) and the pressed chip squashes. Clamped values do a red
  micro-shake instead of changing. Every change plays `ui_click` and writes GameConfig immediately.
- Changing HUMANS animates pick-cursors in/out (a cursor bounces onto the grid on +1, poofs on -1).

#### 2.3.5 What animates (the showcase juice)

Stage pose idle-bounce always; character-swap whip-out/bounce-in on every focus move; name-banner
color cross-fade; grid card pop+wobble+glow on focus; slot-machine spin on Random; confirm callout +
pose-jump + check stamp on lock; pick-cursor bounce on add/remove; stepper knob-bounce. This screen
should feel the MOST alive of the six — it's the personality showroom.

### 2.4 ArenaSelect — pick the peak

**Layout:**
- Shared skeleton. Header title: **"PICK YOUR PEAK"**.
- Content: a **grid** of arena cards. 12 tiles (1 Random + the 11 pool levels) → a **3-rows × 4-cols**
  grid, cards `~340×220` (landscape, thumbnail-shaped), `SP_L` gaps, centered. If 12 is tight, use
  4×3; the RANDOM card is always **first (top-left)** and selected by default.
- **RANDOM ROTATION card:** distinct treatment — a card whose thumbnail is a swirling shuffle motif
  (three overlapping chocolate-outline arrows in a ring / dice) on a rainbow-tinted gradient, name
  "RANDOM ROTATION", tagline *"A new peak every round."* It reads as the fun default, not a fallback.
- **Arena cards:** thumbnail slot (Phase-1 placeholder per visual brief §2: a rounded chocolate-outline
  tile filled with the arena's `theme` color as a gradient — an intentional themed tile, NOT a debug
  rect) + arena `name` (`CardNameBig` 34px) on a bottom banner. When real arena thumbnails land they
  drop into the thumbnail slot.

**First focus:** RANDOM ROTATION.

**Input:**
- D-pad/stick/arrows traverse the grid (wrap). Focus = full §1.3, glow tinted to the arena theme color.
- A on RANDOM: sets `arena_mode = RANDOM_ALL`, then **CONFIRM** → match-start transition (§1.5) → launch.
- A on a specific arena: sets `arena_mode = SINGLE` + `single_arena_path`, then CONFIRM → launch.
  (Decision: A directly confirms+launches from the focused card — no separate confirm button needed;
  the footer shows `(A) FIGHT!` so it's clear A launches. This is the fewest-taps path the shell wants.)
- B: back-transition to CharacterSelect.
- Footer hint reads `(A) FIGHT!   (B) Back   (<>) Choose`. The `(A) FIGHT!` chip is green-tinted to
  echo the go-affirmative.

**Animates:** grid cascade on enter (top-left→bottom-right); focused card pop+wobble+themed glow; the
RANDOM card's shuffle motif slowly spins always; on CONFIRM the iris/scale-through match-start wipe.

### 2.5 Options — toy switches, not OS widgets

Reachable from MainMenu AND PauseMenu (same scene). Reads/writes the `Settings` autoload (functional
spec §4).

**Layout:**
- Shared skeleton. Header title: **"OPTIONS"**.
- Content: a centered **navy glass panel** (`MatchEndPanel` stylebox), ~48% width, holding a vertical
  list of setting **rows**, `SP_M` between rows, row height ~88px. Each row: left-aligned label
  (`Label` 34px white + chocolate outline — panel is dark navy) + right-aligned control.
- Rows (functional spec §4.1): **MASTER VOLUME**, **MUSIC VOLUME**, **SFX VOLUME** (sliders),
  **FULLSCREEN** (toggle).

**Row focus:** the WHOLE row highlights (not just the control): row scales `1.0→1.04`
(`TRANS_BACK EASE_OUT` 0.15s) + an accent-color vertical bar (~6px, hero-pink) slides in on the row's
left edge + the row's control brightens to accent. Unmistakable which setting is active on a gamepad.

**Slider styling (`ToyTrack`/`ToyFill`/`ToyKnob`):**
- Track: rounded bar height 16, radius 8, chocolate `#3B2419 @ 0.88` (reuse `FuelBG`).
- Fill: white `#FFFFFF` normally; when the row is focused the fill turns the accent color so the active
  slider glows (reuse `FuelFill`, modulate).
- Knob: a chunky chocolate-outlined circle ~36px, cream fill; on row focus it scales to 1.15 and fills
  accent. Numeric value ("80%") in `StepValue` to the right of the track.
- Adjust: Left/Right nudges **5%** steps; each step does a knob-bounce (`scale 1.0→1.15→1.0`, 0.10s
  `TRANS_BACK`). Every change calls `Settings.set_master/music/sfx(v)` (live apply + persist). Mouse
  can drag the knob.

**Toggle styling (`ToyToggleTrack`/`ToyToggleKnob`) — pill switch, never a checkbox:**
- A rounded pill track ~72×40, radius = half-height, chocolate outline. Cream knob (chocolate-outlined
  circle) slides left(OFF)/right(ON) with `TRANS_BACK EASE_OUT` 0.15s. ON = track fills P3 Green
  `#54C94A`; OFF = track fills `#3B2419 @ 0.25`. Left/Right or A toggles; calls
  `Settings.set_fullscreen(b)`.

**First focus:** MASTER VOLUME row.

**Input:**
- Up/Down move between rows (wrap). Left/Right adjust the focused row's slider/toggle. A on the toggle
  row also flips it.
- B: back-transition to **whoever opened Options** (MainMenu or PauseMenu — the shell tracks the caller
  per functional spec §1.2). No "apply" button; changes are live + write-through.

**Animates:** rows cascade in on enter; focused-row scale + accent bar; knob-bounce on every slider
step; pill-knob slide on toggle.

### 2.6 PauseMenu — overlay, not a screen swap

Appears over the frozen live match (`get_tree().paused = true`, functional spec §5 C8). NOT a
ShellRoot child — it's an overlay `CanvasLayer` the match instances.

**Layout:**
- Full-screen `#141428 @ 0.55` scrim over the frozen game (the match shows through, dimmed — same scrim
  as sub-screens, so pause feels part of the family).
- A centered navy glass panel (`MatchEndPanel` stylebox), title **"PAUSED"** (`BannerCenter`, ~92px),
  and a vertical button stack, `SP_M` gaps: **RESUME** (`MenuButtonPrimary`, first focus), **RESTART**,
  **OPTIONS**, **QUIT TO MENU** (`MenuButton`).
- Panel drops in with `TRANS_BACK` **0.15s** (start scale 0.85 + a 0→1 alpha) — same pop as the HUD
  banners, so pausing feels like the game's own juice, not a separate UI. Un-pausing reverses over
  0.10s.

**First focus:** RESUME.

**Input (functional spec §5 C8):**
- Up/Down through the stack (wrap). A activates. B (or the pause key again) = RESUME.
- RESUME → unpause + panel out. RESTART → restart match with the SAME GameConfig. OPTIONS → open Options
  (opened-from = pause; its B returns to PauseMenu). QUIT TO MENU → `change_scene` to MainMenu (NOT
  app-quit).

**Match-end routing (functional spec §9 C9):** at MATCH_END, the existing match-end banner offers
**REMATCH** (→ new match, same config) and **QUIT** (→ MainMenu, not app-quit). Style these two as
`MenuButtonPrimary` (REMATCH, green, first focus) + `MenuButton` (QUIT), same focus/press juice as the
rest of the shell, dropped into the existing match-end panel — so the loop back to "one more round" is
one obvious green button.

**Animates:** scrim fade-in; panel drop-pop; focus wobble on the selected button. The frozen game
behind does NOT animate (it's paused — the one intentional still moment, which reads as "time stopped").

---

## 3. Character personality — where to spend the cheap wins

The Herd's voice should leak into the shell wherever it's near-free (theme bible tone: "adorable idiots
with rockets who take this WAY too seriously"). Priority order, cheapest first:

1. **CharacterSelect blurbs** (§2.3.1) — already in the slot data, zero extra cost. The loudest
   personality beat.
2. **Locked-mode toast** ("Coming soon!") + locked wiggle (§2.2) — playful, not a buzzer.
3. **ModeSelect / ArenaSelect taglines** (§2.2 / §2.4) — one-liners in the Herd's joke-macho voice.
4. **Confirm callouts** (§2.3.3) — if voice/goat-scream SFX exist, play the picked hero's callout on
   lock-in. Skip silently if the asset isn't there — never block on audio.
5. **Title bobbers doing the verbs** (§2.1) — Pogo boinging, Butch winding a headbutt. The cast is
   never a static lineup.

None of these require new art or code seams beyond the slot contract — they're copy + existing SFX.

---

## 4. Motion / juice — the concrete tween table

Every animation in the shell, in one place, so the programmer never guesses. `T`=`set_trans`,
`E`=`set_ease`, `d`=duration.

| Event | What moves | From → To | T / E | d (s) |
|---|---|---|---|---|
| Focus IN (button) | scale (from center) | 1.0 → 1.08 | BACK / OUT | 0.18 |
| Focus IN (card) | scale | 1.0 → 1.14 | BACK / OUT | 0.18 |
| Focus IN (glow) | halo modulate a | 0 → 1 | QUAD / OUT | 0.18 |
| Focus idle wobble | scale osc | ±2% around focused | SINE / IN_OUT | 0.9 loop |
| Focus idle rotate | rotation osc | ±1.0° | SINE / IN_OUT | 1.3 loop (offset) |
| Focus OUT | scale + shadow + border | → rest | QUAD / IN | 0.12 |
| Press (confirm) down | scale | rest → 0.92 | QUAD / IN | 0.06 |
| Press (confirm) pop | scale | 0.92 → 1.16 → rest | ELASTIC / OUT | 0.22 |
| Screen FORWARD out | scale + a | 1.0→0.95, a1→0 | QUAD / IN | 0.18 |
| Screen FORWARD in | scale + a | 1.06→1.0, a0→1 | BACK / OUT | 0.28 |
| Screen BACK (mirror) | scale + a | 0.95→1.0 / 1.0→1.06 | BACK / OUT + QUAD / IN | 0.28 / 0.18 |
| Content stagger item | y + a | +60px→rest, a0→1 | BACK / OUT | 0.30 (0.05 stagger) |
| Header/footer enter | y | ∓60px → rest | BACK / OUT | 0.25 |
| Logo enter | scale + y | 0.6→1.0, +40px→rest | BACK / OUT | 0.35 |
| Logo breathe | scale | 1.0 ↔ 1.03 | SINE / IN_OUT | 2.6 loop |
| Logo rotate | rotation | ±1.5° | SINE / IN_OUT | 3.1 loop |
| Backdrop Ken-Burns | scale | 1.06 ↔ 1.0 | SINE / IN_OUT | 12 ping-pong |
| Title bobber bob | y | ±14px | SINE / IN_OUT | 1.6–2.4 (randomized) |
| Char stage idle bounce | scale y/x (squash) | 1.0 ↔ (1.06,0.94) | SINE / IN_OUT | 0.7 loop |
| **Char swap OUT** | x + rotation + a | slide 90px + spin -12° + a→0 | QUAD / IN | 0.14 |
| **Char swap IN** | x + scale + a | from +90px & 0.7 → rest | BACK / OUT | 0.26 |
| Name banner recolor | modulate color | old hue → new hue | QUAD / OUT | 0.20 |
| Random slot-machine | cursor step | rapid card→card | (ticks) | 0.5 total |
| Lock-in stamp | check scale | 0 → 1.3 → 1.0 | ELASTIC / OUT | 0.30 |
| Slider knob step | knob scale | 1.0 → 1.15 → 1.0 | BACK / OUT | 0.10 |
| Toggle knob slide | knob x + track color | off↔on | BACK / OUT | 0.15 |
| Stepper value change | value scale | 1.0 → 1.2 → 1.0 | BACK / OUT | 0.12 |
| Clamp / locked reject | rotation shake | ±3° twice | BACK / OUT | 0.25 |
| Pause panel in | scale + a | 0.85→1.0, a0→1 | BACK / OUT | 0.15 |
| Match-start iris | circle scale | 0 → covers screen | QUAD / IN | 0.22 |

**Character-swap detail (§2.3, the showcase move):** when focus moves to a new hero, the current stage
pose slides out toward the grid side (+90px x) while spinning -12° and fading, over 0.14s
(`QUAD IN`); the incoming pose starts on the far side (+90px) at scale 0.7 alpha 0 and bounces to rest
with `BACK OUT` 0.26s, landing with one squash on contact. The spotlight glow and name banner
cross-fade their color over 0.20s underneath. Net feel: the roster physically *tosses* the old goat off
and *bounces* the new one on — pure toybox.

---

## 5. Squash-stretch for character stage art (so a static sprite still feels bouncy)

The stage pose (and title bobbers) must never sit still even with a single idle PNG. Apply a constant
volume-preserving squash loop: at the top of the bob `scale (0.96, 1.06)` (stretch tall), at the bottom
`scale (1.06, 0.94)` (squash wide), synced to the y-bob so it reads as a bouncing jelly goat. 0.7s
sine loop. This is the whole bounce identity expressed on a still asset — it's mandatory for
CharacterSelect and the MainMenu bobbers, and it's why a cropped idle sprite is an acceptable Phase-1
placeholder (motion sells it, not detail).

---

## 6. Focus-order & neighbor map (build reference)

Explicit first-focus + traversal per screen (all wrap; B always = back-nav):

- **MainMenu:** PLAY → OPTIONS → QUIT (vertical). First: PLAY.
- **ModeSelect:** BRAWL → TRIALS → GAUNTLET → SPORTS (horizontal). First: BRAWL.
- **CharacterSelect:** grid [Pogo,Butch,Ziggy / Puff,Vex,Billy] 2×3 (h-wrap, v between rows); Down from
  bottom row → settings strip [Humans→Bots→Skill→Kills→Lives]; Up → back to grid. First: P1's current
  hero card (Pogo).
- **ArenaSelect:** grid (Random first, then 11 arenas), row-major traversal, wrap. First: RANDOM.
- **Options:** MASTER → MUSIC → SFX → FULLSCREEN (vertical). First: MASTER.
- **PauseMenu:** RESUME → RESTART → OPTIONS → QUIT TO MENU (vertical). First: RESUME.

`< BACK` chevron on sub-screens is focusable but placed LAST in the neighbor chain (reached by
over-scrolling or by pointer); the primary way back is the B button.

---

## 7. Grading criteria — how I score the built screens (in-engine, from screenshots)

I grade from `python tools/gbplay.py screenshot` (and short capture bursts / `eval` for motion), never
from the `.tscn`. Verdicts: **Ship** / **Fix** (numbered, specific) / **Reject** (wrong direction).
Every screen must pass ALL:

1. **Mario-Kart bar / first impression** — a stranger seeing a screenshot believes this shipped on
   Steam. Confident oversized type, full-bleed living art, glossy toy cards. Not a prototype, not a
   settings dialog.
2. **Focus is obvious across the room** — from a single screenshot I can instantly tell what's focused
   without hunting: scale-up + color glow + lift + (in a capture) wobble all firing on exactly one
   control. A thin/absent focus read is an automatic Fix.
3. **Springy, on-brand motion** — logo breathes, focus wobbles, transitions overshoot-and-settle, the
   backdrop and bobbers never freeze, CharacterSelect swap tosses/bounces. Any linear tween, hard cut,
   or dead-still screen is a Fix. Bounce is the identity — I must SEE it.
4. **Consistency (one product, not six)** — every screen uses the shared skeleton, the 8-pt spacing
   scale, the same component styleboxes, the same transition grammar. Chocolate outline on every
   interactive element. Any bespoke off-system widget is a Fix.
5. **CharacterSelect is the showcase** — full grid reads as a roster, the picked hero is BIG on stage
   and bouncing, name banner is bold and in-color, blurb present, per-player pick-cursor legible.
   If it doesn't make me want to pick "one more, as Butch," it's not done.
6. **ModeSelect sells the modes** — SOON cards look like gorgeous promises (ribbon + still-colored +
   playful locked feedback), never disabled-grey dead ends. BRAWL is the obvious live one.
7. **Options reads as toys** — sliders are chunky knobbed bars, fullscreen is a pill switch. Zero OS
   widgets. Row-focus obvious on a gamepad.
8. **Contrast / no amateur tells** — cards pop off the scrim, text crisp (outline doing its job),
   nothing washed out, no misalignment, no default font, no square corners, no stretched logo, no
   clipped/overflowing text at 1080p, no debug rectangles, no seams.
9. **Navigation coverage (kbd AND gamepad)** — every screen reachable and escapable both ways;
   something always focused; no dead ends; footer hints visible; wrap-around works.

A screen that reads flat, static, washed out, or uses a default widget is a Fix at minimum. No
rubber-stamps — I drive the real screens before I approve Phase 1.

---

## 8. Open dependencies (flagged, non-blocking)

- **Character art bible** (in parallel) fills the §2.3.1 `portrait`/`beauty_pose`/`taunt_frames` slots.
  Until then CharacterSelect ships with cropped idle placeholders per the slot contract — layout is
  final, only textures swap.
- **Two overflow recolors (P7 teal / P8 red)** don't appear as cards in Phase 1 (theme bible §4) — the
  grid is the six heroes only.
- **Mode art / arena thumbnails / platform glyphs** are Phase-2/3 slot swaps; Phase 1 ships the
  intentional colored-tile + primitive-glyph placeholders specified above (never debug rects).
- **Voice/callout SFX** are optional (§3.4) — skip gracefully if absent.
```
