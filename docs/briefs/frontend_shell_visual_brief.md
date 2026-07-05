# Visual Brief — Front-End Shell (Phase 1)

> Art Director brief for the gameplay-programmer building the title + menus (ROADMAP Phase 1).
> **Ships with existing assets only** — Theme (`assets/ui/theme.tres`), the chunky rounded font, the
> established player palette, and TWO reference PNGs we already own. No new generated art is required
> for Phase 1. Two optional high-leverage assets are flagged at the end.
>
> Style bible: `docs/VISION.md` "Glossy Toybox." North star: `assets/reference/style_north_star.png`.
> This is the player's FIRST impression — it must read as a finished, purchasable game from frame one.

---

## 0. The palette (use these hexes — nothing off-book)

Pulled from `theme.tres` and `PartyMatch.PLAYER_COLORS` so the shell matches the in-game HUD exactly.

| Role | Hex | Notes |
|---|---|---|
| Chocolate outline | `#3B2419` | THE line color. Every card/button/glyph gets this outline. Non-negotiable — it is the brand. |
| Card fill (cream-white) | `#FFFFFF` @ 0.94 a | Existing `StyleBoxFlat_card`. Buttons/cards. |
| Navy panel (glass) | `#141428` @ 0.85 a | Existing `MatchEndPanel` bg. Use for grouped panels/dialogs so the title matches match-end. |
| P1 Pink | `#FF5FA8` | Primary accent / default focus glow. |
| P2 Blue | `#4AA8FF` | Secondary accent. |
| P3 Green | `#54C94A` | "Go / confirm" affirmative. |
| P4 Yellow | `#FFC93F` | "Highlight / selected" pop. Matches the GOTTA in the logo. |
| Sky azure (bg grad top) | `#3FA9F0` | From north-star sky. |
| Sky pale (bg grad bottom) | `#BFEBFF` | Soft horizon. |
| Grass green (accent band) | `#6CC24A` | Optional footer band. |

Type: Theme default `SystemFont` (Arial Rounded MT Bold, weight 900) with chocolate outline. Never
introduce a second typeface. Oversized, tight, chunky — always.

---

## 1. Title screen (MainMenu)

### Composition (16:9, described as a 1920×1080 sketch)

```
+---------------------------------------------------------------+
|   ~ animated azure->pale sky gradient, drifting soft clouds ~ |
|        (o)  <- floating bouncer, slow bob            (o)      |
|                                                               |
|              +-------------------------------+                |
|              |      [ GOTTABOUNCE LOGO ]     |   <- ~46% W,   |
|              +-------------------------------+      top-center |
|                                                               |
|         (o)                                    (o)  <- bobbers |
|                    [  PLAY        ]                            |
|                    [  OPTIONS     ]   <- button stack,         |
|                    [  QUIT        ]      centered, ~34% W      |
|                                                               |
|  ~~~~~ grass strip + a couple of trampolines/springs ~~~~~~~~~ |
|  v0.x                                    (c) GottaBounce Studio|
+---------------------------------------------------------------+
```

### Logo / wordmark

- **We already have a shippable logo:** `assets/reference/logo_v1.png` — "GOTTA" in glossy yellow,
  "BOUNCE" in glossy cyan, chocolate outline, drop shadow, transparent bg. It IS the Glossy Toybox
  brand. Use it as a `TextureRect` (`expand_mode = KEEP_ASPECT_CENTERED`), width ~46% of viewport,
  pinned top-center with ~8% top margin. Copy it into `assets/ui/logo.png` (don't reference from
  `reference/`, which is a scratch dir) and re-import.
- **Logo motion:** the whole lockup gets a slow idle "breathe" — scale 1.0↔1.03 on a 2.6s
  `TRANS_SINE` `EASE_IN_OUT` looping tween, plus a tiny ±1.5° rotation on a 3.1s offset loop so the
  two motions never sync (organic, toy-like). On screen-enter it drops in: start at scale 0.6 + 40px
  above final, tween to rest with `TRANS_BACK EASE_OUT` over 0.35s. This is the bounce motif applied
  to the title itself.
- **Typographic fallback (no art dependency):** if for any reason the PNG is unavailable, render two
  stacked `Label`s using theme `BannerCenter` variation (132px): "GOTTA" font_color `#FFC93F`,
  "BOUNCE" font_color `#4AA8FF`, both chocolate outline (outline_size 20), line 2 offset up to close
  the gap, and a subtle per-line vertical offset (GOTTA sits 6px higher) to echo the logo's arched
  baseline. The idle breathe applies to the container either way.

### Background — reuse, don't generate

Priority order (all Phase-1-shippable):

1. **BEST / cheapest polish:** use `assets/reference/style_north_star.png` as a full-bleed
   `TextureRect` (`STRETCH_KEEP_ASPECT_COVERED`). It is literally the grassy arena with floating
   bouncers, springs and trampolines — the exact scene the title should sell. Copy to
   `assets/ui/title_bg.png`. Add 3–4 `TextureRect` bouncer sprites (or, if no cheap sprite exists,
   reuse the in-game Bouncer scene at rest) that bob and drift for parallax life on top of it. Apply
   a 1.05→1.0 slow Ken-Burns zoom on the bg for subtle life.
2. **If a live backdrop is trivial:** instance an actual arena scene (e.g. the grassy expanse) behind
   the menu with bots-only, camera locked wide, HUD hidden, input disabled — a living attract-mode
   backdrop. Higher wow, but ONLY if it's cheap and stable; a still + bobbers is the safe ship.
3. **Pure-code fallback (zero art):** vertical `GradientTexture2D` sky `#3FA9F0`→`#BFEBFF`, a grass
   band (`#6CC24A`) across the bottom 12%, and 4 procedurally-bobbing circles in the player colors
   (chocolate-outlined) drifting as "bouncers." Even this must never look like a flat solid fill.

**Do not** put a black/flat-grey void behind the menu. The background carries the fantasy.

### Menu buttons (title)

- PLAY (primary), OPTIONS, QUIT. Vertical `VBoxContainer`, centered, ~34% viewport width, 18px
  separation. PLAY is visually heaviest (see §3 button spec — primary variant).
- Enter animation: buttons cascade in bottom-up, each offset +60px below rest and 0.05s staggered,
  `TRANS_BACK EASE_OUT` 0.3s — they "bounce up into place."
- First focus lands on PLAY (see §4 focus).

---

## 2. Menu screens — one consistent system

All of ModeSelect / CharacterSelect / ArenaSelect / Options / Pause share ONE skeleton so they feel
like one product, not six screens.

### Shared skeleton

```
+---------------------------------------------------------------+
|  < BACK          [ SCREEN TITLE ]                             |  <- header, ~12% H
|                                                               |
|                                                               |
|              [   content region: cards / list   ]            |  <- ~70% H
|                                                               |
|                                                               |
|  (A) Confirm   (B) Back   ...            [ hint strip ]       |  <- footer, ~10% H
+---------------------------------------------------------------+
```

- **Background:** the SAME title background (dimmed). Add a full-screen navy scrim `#141428` @ 0.55
  over it on sub-screens so cards pop and the eye goes to content. Pause menu uses the same scrim over
  the frozen live game (the game shows through, dimmed).
- **Header title:** `Label`, theme `BannerTop` variation (58px, chocolate outline), left-aligned with
  a chocolate-outlined back chevron/`< BACK` button on the far left.
- **Footer hint strip:** small `BannerPrompt`-style labels (34px is large; use a new 26px "Hint"
  variation) showing the current controls: `(A) Select   (B) Back   (LB/RB) Tabs`. Couch players must
  always see what buttons do. Keep it to one line, chocolate outline, ~0.85 alpha.
- **Content region** differs per screen but always uses the card/button vocabulary below.

### Per-screen content

- **ModeSelect:** a row of 2–4 big **mode cards** (§3 card spec), each = big title + one-line tagline
  + (later) an icon/thumb. Horizontal `HBoxContainer`, centered, generous 32px gaps. Focused card
  scales up and lifts (see §4). Cards that are locked/coming-soon get a chocolate "SOON" ribbon and
  0.5 desaturated fill — present but obviously not selectable.
- **CharacterSelect:** a grid of character portrait cards (Phase 1 = the 4 existing color skins:
  pink/blue/green/yellow blobs). Each card is a rounded cream card with the bouncer centered and a
  name below (`CardName` variation, 26px). Selection paints the card's border with THAT character's
  color and shows a big color-matched "P1" flag pinned to the corner. Support one player picking for
  Phase 1; design the card so 4 pick-cursors (color-outlined rings) can land on cards later.
- **ArenaSelect:** vertical or grid list of arena cards — name (`CardName`) + a thumbnail slot
  (Phase 1: a solid color-block placeholder tinted to the arena theme + arena name; NOT a debug
  rectangle — give it the chocolate outline, rounded corners, and a small themed emoji-free label so
  it reads as an intentional placeholder tile, e.g. a grass-green tile for grassy arenas). A "?
  Random" card with a shuffle motif belongs at the end.
- **Options:** see §5.
- **PauseMenu:** centered navy glass panel (`MatchEndPanel` stylebox — reuse it), title "PAUSED"
  (`BannerCenter`), vertical buttons: Resume / Restart / Options / Quit to Menu. Resume is primary +
  first focus. Panel drops in with the same `TRANS_BACK` pop as the HUD banners (0.15s) so pause feels
  consistent with in-match juice.

---

## 3. Button & card styling (reuse theme.tres, add 3 small styleboxes)

The existing `StyleBoxFlat_card` (cream, chocolate 4px border, 16px radius, soft shadow) is the base
DNA. Add these theme variations to `theme.tres` (programmer: mirror the card's numbers, only change
what's noted). Keep 4px chocolate `#3B2419` border and 16px radius on ALL of them — that consistency
IS the polish.

- **`MenuButton` (normal):** bg `#FFFFFF` @ 0.94, chocolate 4px, radius 16, content margins 20/14,
  shadow size 5 offset (0,3). Font 34px, chocolate outline 8, font_color `#3B2419` (dark text on
  cream — high contrast, readable). Min height ~72px, min width ~360px.
- **`MenuButton` hover/focus:** bg brightens to `#FFFFFF` @ 1.0, border stays chocolate but grows to
  6px, shadow grows to size 9 (the card lifts). PLUS a color glow (see §4). Focus is driven by scale,
  not just color — see motion.
- **`MenuButton` pressed:** bg dips to `#EDE6DA` (warm off-white), shadow shrinks to size 2, offset
  (0,1) — the button squashes down. Font_color unchanged.
- **`MenuButtonPrimary`** (PLAY / Resume / Confirm): identical geometry but fill is a player-color —
  use P3 Green `#54C94A` for affirmative actions, font_color `#FFFFFF` with chocolate outline 8 so
  white text reads on green. Slightly larger (min height ~84px).
- **`MenuCard`** (mode/character/arena): reuse `StyleBoxFlat_card` as-is for the resting state. Focus
  state = a duplicated stylebox with `border_color` set to the accent/character color and
  `border_width` 6, plus the scale/lift below.

Dark-text-on-cream for menus is deliberate: the in-game HUD uses white-text-on-chocolate for
readability over chaos, but static menus over a bright sky read better as dark ink on cream cards.
Both share the chocolate outline so they're unmistakably one family.

---

## 4. Focus / selection — BIG and OBVIOUS (couch + gamepad)

This is the single most important interaction. On a couch, 8 feet from a TV, the player MUST see where
focus is at a glance. Never rely on a thin OS focus ring.

The focused control gets ALL of these simultaneously:

1. **Scale up:** 1.0 → 1.08 (buttons) / 1.12 (cards), `TRANS_BACK EASE_OUT` over 0.18s. Set
   `pivot_offset = size * 0.5` first so it scales from center. This mirrors the HUD banner pop
   (`MatchHUD.gd` uses `TRANS_BACK EASE_OUT` at 0.15s — stay in that family).
2. **Lift:** shadow grows (bigger stylebox shadow) so it floats above unfocused siblings.
3. **Color glow:** border repaints to the accent color (P1 Pink `#FF5FA8` default; the character's
   own color on CharacterSelect). Optionally a soft outer glow via a second `StyleBoxFlat` behind it
   at the accent color, 0.35 alpha, larger radius — a colored halo.
4. **Idle wobble on the focused item ONLY:** a gentle continuous ±2% scale breathe (1.06↔1.10) on a
   0.9s sine loop so the selection is alive, never static. Unfocused items are dead still.

Unfocus reverses scale/shadow/border over 0.12s. Moving focus should feel like the selection
"bounces" from one item to the next — the previous shrinks as the next pops.

**Confirm (A):** the pressed item does a quick squash-and-pop (scale to 0.92 in 0.06s, then overshoot
to 1.12, settle to rest) before the screen transitions. **Cancel/Back (B):** current screen slides/
scales out; no punishment animation.

**Navigation:** wire full keyboard + gamepad focus neighbors (`focus_neighbor_*`) so D-pad/stick and
arrows both work. Mouse hover should ALSO drive the same focus state (hover = focus) so it's coherent
across input methods. Never leave a screen with nothing focused.

---

## 5. Options screen — sliders + toggles

Content = a vertical list of rows inside a navy glass panel (`MatchEndPanel` stylebox). Each row:
left-aligned label (`Label`, 34px, white + chocolate outline — this panel is dark navy so white text)
+ right-aligned control. Row height ~80px, focus highlights the WHOLE row (scale 1.04 + accent left
edge bar) so it's obvious which setting is active on a gamepad.

Phase 1 rows (from ROADMAP `Settings` autoload): Master Volume, Music Volume, SFX Volume (sliders);
Fullscreen (toggle). Room to grow (resolution, vsync) later.

### Slider styling

- **Track (grabber_area / background):** rounded bar, height 16px, radius 8. Reuse the `FuelBG`
  stylebox DNA — chocolate `#3B2419` @ 0.88. This ties options directly to the in-game fuel gauge.
- **Fill (grabber_area):** white `#FFFFFF` (reuse `FuelFill`), OR the accent color when the row is
  focused so the active slider glows.
- **Grabber (knob):** a chunky chocolate-outlined circle, ~36px, cream fill — reads as a physical
  knob you can grab. On focus it scales to 1.15 and the fill turns accent-colored.
- Left/right on gamepad nudges in ~5% steps with a tiny knob-bounce on each step (scale pulse 1.0→
  1.15→1.0 over 0.1s) so adjustment feels tactile. Show the numeric value (e.g. "80%") to the right.

### Toggle styling

- A pill-shaped switch, not a checkbox: rounded track (chocolate outline, radius = half height),
  ~72×40px, cream knob that slides left(off)/right(on) with a `TRANS_BACK` 0.15s tween. ON track fills
  P3 Green `#54C94A`; OFF track fills `#3B2419` @ 0.25. The knob keeps its chocolate outline. This
  matches the toy-switch language far better than an OS checkbox.

---

## 6. Screen transitions

Cheap, springy, consistent — one transition vocabulary for the whole shell:

- **Forward (into a sub-screen):** outgoing screen scales to 0.95 + fades to 0 over 0.2s; incoming
  screen starts at scale 1.05 + alpha 0 and settles to rest with `TRANS_BACK EASE_OUT` 0.28s. Reads
  as "diving in."
- **Back:** the reverse (incoming from 0.95, outgoing to 1.05) so direction is legible.
- **Content stagger:** on each screen enter, the cards/buttons cascade in (0.04–0.06s stagger,
  `TRANS_BACK`) as in §1 — never all-at-once, never a hard cut.
- **Match start (PLAY → game):** a quick full-screen wipe or scale-through on the logo/PLAY press, then
  hand off to the existing "3-2-1-BOUNCE!" HUD banner. Do not double-up countdowns.
- Keep all durations ≤0.3s: menus must feel snappy, never sluggish. Feel is the product — but a party
  game's menus should never make players wait.

---

## 7. Do / Don't

**Do**
- Reuse `theme.tres` styleboxes and the one font everywhere; add only the few variations named here.
- Keep the chocolate `#3B2419` outline on every interactive element — it is the brand line.
- Make focus impossible to miss (scale + lift + color + idle wobble, all at once).
- Keep a living background behind every screen (reused art or animated gradient + bobbers).
- Always show controller hints in the footer; always have exactly one thing focused.

**Don't**
- No OS-default Buttons/Sliders/CheckBoxes with default skins. No thin default focus rings.
- No flat black/grey voids as backgrounds. No debug rectangles as arena/character placeholders — a
  placeholder must be a properly outlined, rounded, intentional tile.
- No second font, no un-branded colors, no square (0-radius) corners.
- No static, dead menus — if nothing on screen is moving, it's wrong for THIS game.
- No stretched/squished logo (keep aspect). No text without the chocolate outline.

---

## 8. Optional high-leverage art (post-Phase-1, NOT blocking)

Ships without these; they raise the ceiling later:

1. **Clean logo export** — `logo_v1.png` is great but lives in `reference/`. A same-style export at
   2x with tuned padding as `assets/ui/logo.png` is the single highest-leverage title asset (Phase 1
   can just copy the existing one — already covered in §1).
2. **A dedicated title-screen key art / attract backdrop** — a wider, menu-composed variant of the
   north-star scene with clear negative space where the logo + buttons sit (so nothing important is
   ever occluded by a bouncer). Nice-to-have; the reused north-star still works.
3. **Character portrait busts** and **arena thumbnails** — replace the color-block placeholders in
   CharacterSelect/ArenaSelect. These land naturally in Phase 2/3 when the roster and circuits exist.

---

## 9. Grading criteria (how I'll review the built screens in-engine)

I grade FROM IN-GAME SCREENSHOTS (`python tools/gbplay.py screenshot`), not from the scene tree.
Each screen graded on:

1. **Style coherence** — does it read as the same product as the match HUD and the north-star art?
   Chocolate outlines, chunky font, rounded cards, glossy toy world all present and consistent.
2. **First-impression bar** — does the title look like a real, purchasable game (not a prototype)?
   Would a stranger believe this shipped on Steam?
3. **Focus readability at couch distance** — from a screenshot, can I instantly tell what's selected
   without hunting? (Scale + color + lift all firing.)
4. **Contrast / saturation** — cards pop off the background; text is crisp (outline doing its job);
   nothing washed out or muddy.
5. **Polish** — no OS widgets, no debug rects, no seams, no stretched logo, no square corners, no
   dead-flat backgrounds, no clipped/overflowing text at 1080p.
6. **Motion (from a short capture / eval)** — logo breathes, focus wobbles, transitions spring,
   nothing is static or hard-cut. Feel matches the bounce identity.
7. **Navigation coverage** — every screen reachable and escapable by keyboard AND gamepad; something
   always focused; hints visible.

Verdicts: **Ship** / **Fix** (numbered, specific) / **Reject** (wrong direction). A screen that reads
flat, static, washed out, or uses a default widget is a Fix at minimum — no rubber-stamps.
