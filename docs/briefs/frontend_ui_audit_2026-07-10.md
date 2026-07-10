# Front-End UI Audit — 2026-07-10 (owner-mandated)

> Author: UI/UX Designer. Trigger: `docs/feedback/owner_2026-07-10_ui_audit.md` (ArenaSelect failed the
> bar in a live screenshot; owner ordered an audit of EVERY screen against the same defect classes).
> All verdicts below are graded from live screenshots captured this session from the running shell
> (1280x720 window = 2/3 of 1920x1080 design res; all px in this doc are DESIGN-RES px unless noted).
> Evidence files live in `tools/out/`. PauseMenu was audited STATICALLY (.tscn + .gd — it lives
> in-match; noted per instruction).
>
> Defect classes: **A** context · **B** scale-with-content · **C** couch readability ·
> **D** uniform spacing/alignment · **E** safe areas · **F** focus/selection feel.

---

## 1. Per-screen verdicts

### 1.1 MainMenu / Title — **SHIP** (`tools/out/audit_mainmenu.png`)
Logo reads big and glossy, the six Herd bobbers are live and full of personality, button stack is
centered with clear primary (green PLAY vs cream secondaries), footer chrome (v0.1 left, studio right)
stays out of content. No defects in any class. This is the bar the other screens are graded against.
(Backlog, unchanged from `frontend_visual_polish.md` §4: the goat-on-logo upgrade remains a
nice-to-have; not a finding.)

### 1.2 ModeSelect — **FIX** (`tools/out/audit_modeselect.png`)
Strong screen: four diorama cards, clear header, focused BRAWL card pops with pink glow + raised
title band — A/B/C/D/E/F all fundamentally pass. Findings:

1. **[stale content] TRIALS card art is off-message for v10.** The diorama
   (`assets/ui/modes/mode_trials.png`) is built around a **stopwatch + checkered flag** — but v10
   removed the clock entirely (binary completion, Pico-Park model). The running build also still
   showed the old "Beat the clock" tagline; `ModeSelect.gd` line 11 already carries the new copy
   ("Fly the line. Land it, and you're home.") so the tagline fixes itself on next launch — **the art
   does not**. Regenerate `mode_trials.png`: same Ziggy-through-the-ring composition, replace
   stopwatch/checkered-flag with a **goal-gate/flag-post** motif (the thing you actually reach).
   Evidence: audit_modeselect.png (stopwatch clearly visible on TRIALS card).
2. **[C/E] Footer hint chips are low-contrast.** The `B`/`< >` chips are dark chocolate on dark
   grass; at 3m only the green `A` chip reads. Fix once in the shared `HintStrip`: put chips on the
   existing cream chip stylebox (like the `A` chip) or add a 55%-alpha chocolate backing pill behind
   the whole strip. Applies to EVERY screen (same component) — see cross-screen list.
3. **[D, minor] Tagline blocks are uneven card-to-card** (SPORTS wraps 3 lines, BRAWL 1). Reserve a
   fixed 2-line tag band (same fix ArenaSelect.gd already applies to name bands) and shorten the
   SPORTS tag to ≤2 lines.

### 1.3 CharacterSelect — **FIX** (`tools/out/audit_characterselect.png`)
The showcase works: big hero stage, P1-badged focused card with pink glow (F passes emphatically),
name banner + tagline full of personality. Findings:

1. **[A] No mode context.** Nothing says this roster pick is for a BRAWL match. The stepper strip
   (HUMANS/BOTS/KILLS/LIVES) *implies* brawl but never states it. Fix: the **ModeContext chip**
   (spec §3.4 below) top-right of the header — this is a shared component, build once.
2. **[E] The match-settings panel bleeds flush to the right screen edge** (panel runs to x=1920 with
   zero margin; every other element respects the 64px safe margin, and `v0.1` floats orphaned below
   it). Inset the panel to the same 64px right margin as the BACK button's left margin.
3. **[C] Stepper labels are ~21px design-res** ("HUMANS", "BOT SKILL"…) — below couch-readable.
   Minimum 28px for the labels, 40px for the values.
4. **[D] The hero tagline nearly collides with the settings panel** ("…Won't stop" ends ~5px from
   the panel edge). Give the left column a hard right bound with a ≥32px gutter, autowrap inside it.
5. **[B, forward-looking] The 3x2 roster grid is fixed.** Hero #7 has no defined behavior. Rule for
   when it happens: grid grows to 4 columns up to 8; ≥9 adopts the Rail component from §3. Not a
   blocker today (6 heroes).

### 1.4 ArenaSelect — **REJECT** (`tools/out/audit_arenaselect.png`, `tools/out/audit_arenaselect_bottom.png`)
Every owner defect confirmed on screen, plus three more. Wrong direction — full redesign, spec in §3.

Confirmed from `audit_arenaselect.png`:
1. **[A] No mode context** — nothing says BRAWL.
2. **[D] Header occluded** — "PICK YOUR PEAK" hidden BEHIND the top card row (only "K…AK" fragments
   visible between LOCKED ribbons). Root cause read from `scenes/ui/ArenaSelect.tscn`: the
   `GridContainer` is anchored 0.18–0.90 with `grow_vertical = 2`, so 5 rows x ~290px actual card
   height overflow the 777px band and CENTER-EXPAND over both header and footer; the grid is later
   in tree order, so it draws on top.
3. **[C] Tiny tiles** — 340x210 cards with a 60px-tall art plate; thumbnails are unreadable strips.
4. **[B/D] 17 cards, no scroll model** — the top row is clipped off the TOP of the screen; the last
   row (Wrecking Yard) bleeds off the BOTTOM.
5. **[E] Footer overlap** — the A/B/<> hints sit ON the Wrecking Yard card.
6. **[F] The focused card can be off-screen.** `audit_arenaselect_bottom.png`: focus moved to
   Wrecking Yard — the focused, glowing card is itself half-clipped below the screen edge and
   overlapped by the hint strip. Focus feel is broken at the root: no scroll-to-focused exists.

New findings from the same shots:
7. **[amateur tell] Difficulty stars render as ASCII garbage** — "*.. 4 arenas" on Meadow Mile
   (ArenaSelect.gd builds `"*"`/`"."` strings). Replace with a real 3-slot star icon row (asset in
   §3.7).
8. **[D] Locked-circuit hint text clips** — "WIN MEADOW MILE TO UNLOCK" runs off the bottom of the
   Scrapworks card (audit_arenaselect.png, focused card, "UNLOCK" cut by the card edge).
9. **[hierarchy] Circuit cards are text-only grey/gradient plates** next to thumbnail'd arena tiles —
   the featured way to play looks like the placeholder.

### 1.5 Options — **FIX** (`tools/out/audit_options.png`)
Clean panel, focused slider reads pink, header/BACK consistent. Findings:

1. **[D] The focus accent bar overlaps the row label** — the pink focus tick is drawn ON the "M" of
   "MASTER VOLUME". Move the tick into a reserved 24px gutter left of the label column (labels
   indent to clear it), or drop the tick and rely on the pink-filled slider + label color shift.
2. **[D] Vertical distribution is top-heavy** — 4 rows packed high with a large dead band below
   FULLSCREEN. Content-fit the panel height (VBox + padding) or center the rows in the panel.
3. **[C/E] Footer hint chips low-contrast** — same HintStrip fix as ModeSelect #2.
4. **[C, minor] The FULLSCREEN toggle knob is small** for a 3m read (~56px). Scale the ToyToggle to
   ~88x48 with the knob at 40px.

### 1.6 PauseMenu — **FIX (minor)** — audited STATICALLY (`scenes/ui/PauseMenu.tscn`, `src/ui/PauseMenu.gd`; not live-driven this session)
Layout is sound: full scrim, centered `MatchEndPanel`, 92px "PAUSED", 420x88 primary RESUME,
focus wiring + MenuFX juice. Findings:

1. **[E/consistency] No footer HintStrip** — every shell screen shows A/B hints; the pause overlay
   shows none, so "B = resume" is undiscoverable. Add the shared HintStrip ("A|Select", "B|Resume")
   inside the panel footer or screen-bottom over the scrim.
2. **[UX guard] QUIT TO MENU and RESTART execute instantly** — one wrong press ends a 4-player
   match. Add a confirm step for both: press once → button label swaps to "REALLY?" with a 1.5s
   revert (cheapest) — no new scene needed.
3. **[A, minor] Optional context line** under PAUSED (mode + arena name, 30px, 70% alpha). Cheap,
   nice, not required.

---

## 2. Prioritized cross-screen fix list

| P | Fix | Screens | Class |
|---|---|---|---|
| **P0** | **ArenaSelect rebuild to §3** (Reject; owner-flagged) | ArenaSelect | A,B,C,D,E,F |
| **P1** | **ModeContext chip component** (§3.4) in the shared header | ArenaSelect, CharacterSelect (later: sports court select) | A |
| **P2** | **HintStrip contrast pass** (cream chips or backing pill; one component, all screens) + enforce the footer band as a hard no-content zone in MenuScreen | ALL | C,E |
| **P3** | **CharacterSelect safe-area + type pass** (panel 64px right inset, 28/40px stepper type, tagline gutter) | CharacterSelect | C,D,E |
| **P4** | **Regenerate `mode_trials.png`** without stopwatch/checkered flag (v10 no-clock) | ModeSelect | content |
| **P5** | Options focus-tick gutter + panel content-fit; star-icon asset replacing ASCII stars; PauseMenu hints + quit confirm; 2-line tag band on ModeSelect | Options, ArenaSelect, PauseMenu, ModeSelect | C,D |

---

## 3. ArenaSelect REDESIGN SPEC — "PICK YOUR PEAK" (the Shelf model)

**Layout call: two horizontally-scrolling SHELVES, not a flat carousel.** The owner's carousel
instinct is right about the container (horizontal rail = infinite capacity + big tiles) but a single
flat carousel mixes circuits, RANDOM, and arenas into one 17-stop row and gives no hierarchy. Two
shelves keep "ways to play" (circuits + RANDOM — the featured row) visually senior to "single
arenas" (the browse row), scale independently to any count, and the same component IS the future
SPORTS court select. This replaces the GridContainer entirely.

### 3.1 Regions (design res 1920x1080)
```
y    0–130   HEADER: BackBtn (180x64 @ x64, unchanged) · centered Title "PICK YOUR PEAK"
             · ModeContext chip right-aligned (§3.4). Nothing may draw above y=140 except these.
y  150–585   SHELF A — "WAYS TO PLAY": RANDOM ROTATION + circuits. Big cards.
y  605–930   SHELF B — "ARENAS": the single-arena pool. Medium cards.
y  950–1080  FOOTER: HintStrip left (x96), Version right (x-64). HARD no-content zone:
             no card, at any focus scale, may intersect y>940 (see 3.6).
```
Both shelves are a clipping `Control` (clip_contents on) containing an `HBoxContainer` rail that the
code translates on X. Clipping bounds = the shelf band, so occlusion of header/footer is
structurally impossible. Left inset of both rails: 96px (aligns with HintStrip).

### 3.2 Shelf anatomy
Each shelf = a label + a rail + edge affordances:
- **Shelf label**: 34px, cream, 90% alpha, chocolate outline 8 — "WAYS TO PLAY" at (96, 150),
  "ARENAS  11" at (96, 605) (count suffix, 60% alpha).
- **Rail**: HBox, h_separation 36 (Shelf A) / 32 (Shelf B), starts 12px below the label.
- **Edge chevrons**: 48px `>` / `<` chocolate-on-cream chips vertically centered on the shelf,
  x=24 and x=1848, visible only when more cards exist off that edge; idle-bob ±4px, 1.2s sine.
- **Position readout**: "4 / 12" 26px, 60% alpha, right-aligned to the shelf label line — replaces
  any scrollbar. Updates on focus move.

### 3.3 Card sizes (MenuCard.tscn unchanged internally; only custom_minimum_size + plate/name-band
sizes set from code, exactly as today)
- **Shelf A card: 460 x 340.** Art plate 460x240 (circuit crest or, for RANDOM, the `_random.png`
  shuffle collage, STRETCH_KEEP_ASPECT_COVERED). Name band 100px, fixed 2 lines: line 1 = name
  (40px), line 2 = star row + "N ARENAS" (26px) or the unlock hint for locked (autowrap, band is
  tall enough — kills finding 1.4#8).
- **Shelf B card: 380 x 280.** Baked thumb 380x200 COVERED; name band 80px, name 34px fixed
  2-line. (Thumb bakes are 512x320 — no regen needed.)
- Shelf A order: RANDOM ROTATION first (default focus, the fun default), then circuits in
  circuits.json order (Meadow Mile → … → Mayhem Mile). Locked circuits keep the LOCKED ribbon +
  grey plate + deny-shake, all existing behavior.
- At these sizes 3.5 Shelf-A cards and ~4.5 Shelf-B cards are visible per screen — big, breathing,
  and the partial card at the right edge is the "there's more" cue (MK8-style).

### 3.4 ModeContext chip (NEW shared component — `scenes/ui/ModeContextChip.tscn`)
Right-aligned in the header (right edge x=1856, vertically centered in the header band), a cream
rounded chip (chocolate outline 4, same stylebox family as HintStrip chips), height 72:
`[mode diorama mini 56x56] BRAWL` — mode name 40px in the mode accent color (#ff5fa8 brawl, etc.),
mini = the existing `mode_<id>.png` scaled down. Reads GameConfig.match_config.mode_id. Drop the
same instance into CharacterSelect's header (fixes 1.3#1). Future SPORTS court select shows
`SPORTS` orange.

### 3.5 Navigation
- **Left/right**: move focus along the current shelf. No wrap (edge press = 6px rail nudge +
  low-pitch tick, the existing deny audio at -6dB — communicates "end of shelf").
- **Up/down**: switch shelves; each shelf REMEMBERS its last focus index and restores it. Down from
  Shelf B focuses BackBtn (existing pattern); up from Shelf A also reaches BackBtn.
- **LB/RB (and PageUp/PageDown)**: jump 3 cards — the 30+ scale answer; 30 arenas = ≤10 presses
  end-to-end.
- **A**: confirm + launch (footer "A|FIGHT!"), locked = deny-shake (unchanged). **B**: back.
- Mouse: hover=focus (existing), wheel scrolls the hovered shelf.

### 3.6 Focus + motion (reuse MenuFX tokens; no new grammar)
- Focus pop: existing `MenuFX.focus_in` — scale to **1.10** (down from 1.12; keeps a 460x340 card's
  scaled bottom edge inside the shelf band), TRANS_BACK EASE_OUT 0.18s, glow, ±1° wobble. Focused
  card z-raised above neighbors.
- **Scroll-to-focused (the core new motion)**: on focus change, tween the rail's X so the focused
  card's CENTER lands at screen center, clamped so the rail never shows dead space past its ends —
  0.26s, TRANS_QUINT, EASE_OUT (glides, doesn't bounce — the card itself does the bouncing).
  Rapid inputs retarget the same tween (kill + retween). The focused card is therefore ALWAYS fully
  on-screen — structurally fixes finding 1.4#6.
- Shelf switch: focused shelf's label + chevrons at 100% alpha, unfocused shelf dims to 82%
  modulate and its focused-card glow drops — one glowing card on screen at a time (F).
- Entry stagger: existing MenuScreen stagger, per shelf left-to-right, Shelf A first.
- Confirm: existing press_pop + launch. Unlock celebration: unchanged, but add
  `scroll_to(card)` before the pop so the celebrated card is centered.
- Footer rule (hard): cards live only inside shelf clip bands ending at y=930; 1.10 focus scale on
  a 340-tall card = +17px each side, max y=938 < 940. Any future card size must re-check this
  inequality.

### 3.7 Art needed (small)
| Prio | File | Subject | Size |
|---|---|---|---|
| MUST | `assets/ui/circuits/crest_<id>.png` x5 (meadow_mile, scrapworks, high_wire, the_foundry, mayhem_mile) | Chocolate-outlined toy emblem per circuit on its accent gradient (subjects per `frontend_visual_polish.md` §3c + Foundry = molten crucible/gear pour, orange `#ff8a2a`) | ~920x480, opaque or transparent |
| MUST | `assets/ui/icons/star_full.png`, `star_empty.png` | Chunky glossy gold star + chocolate-outline hollow star (difficulty row; kills the ASCII `*..`) | 64x64, transparent |
| HAVE | `assets/ui/thumbs/*.png` (11 bakes + `_random.png`) | Already exist; reused as-is | — |
Fallback rule: missing crest → the current themed gradient plate + circuit name (screen still reads).

### 3.8 SPORTS court select (design-ahead — same system, zero new layout)
The shelf component must take a data array, not hardcoded content. Sports court select =
the SAME scene class with: Title "PICK YOUR COURT", ModeContext chip = SPORTS/orange, **one shelf**
("COURTS", 8 cards at Shelf-A size 460x340, centered vertically in the content band when only one
shelf exists), each card carrying: court thumb (bake via the same ThumbBaker), a **tier badge**
(48px chip, top-left of the plate: "TIER 1/2/3" on the circuit-accent chip stylebox) and the
existing LOCKED ribbon + unlock-hint band for locked courts. Tier badge is a new optional MenuCard
slot (`set_badge(text, color)`); hidden when unset so Brawl cards are untouched. 8 courts = one
shelf, ~2 pages of scroll; 20 courts later = same screen, longer rail.

### 3.9 Build notes (gameplay-programmer, no further design input needed)
- Replace `Grid` in ArenaSelect.tscn with two `ShelfRail` instances (new small scene: Label +
  clipping Control + HBox + chevrons + counter; one exported `card_size`). ArenaSelect.gd keeps
  ALL its data/lock/celebration/launch logic — only card parenting, sizes, and `wire_grid` change
  (wire left/right within rail, up/down across rails, per-rail `scroll_to_focused()`).
- `wire_grid(cards, 4)` is replaced by per-shelf `wire_rail(cards)` + cross-shelf up/down using
  remembered indices.
- Acceptance (screenshot-verified, I will grade): (1) header fully visible with focus anywhere;
  (2) focused card fully on-screen at rail ends and middle; (3) no card pixel below y=940 at focus
  scale (720p capture: y=627); (4) chevrons appear/disappear correctly at rail ends; (5) ModeContext
  chip shows BRAWL in the brawl flow; (6) star icons render (no `*` glyphs); (7) locked hint text
  fully inside its band.

---

## 4. Evidence index
| File | Screen / state |
|---|---|
| `tools/out/audit_mainmenu.png` | MainMenu, PLAY focused |
| `tools/out/audit_modeselect.png` | ModeSelect, BRAWL focused |
| `tools/out/audit_characterselect.png` | CharacterSelect, brawl flow, Pogo P1 focused |
| `tools/out/audit_arenaselect.png` | ArenaSelect, focus on Scrapworks (top row) — header occlusion + overflow |
| `tools/out/audit_arenaselect_bottom.png` | ArenaSelect, focus on Wrecking Yard — focused card clipped off-screen, footer overlap |
| `tools/out/audit_options.png` | Options, Master Volume focused — tick/label overlap |
| (static) `scenes/ui/PauseMenu.tscn`, `src/ui/PauseMenu.gd` | PauseMenu — not live-driven |
