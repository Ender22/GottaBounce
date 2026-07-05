# Front-End Visual-Polish Brief — closing the gap to the Mario-Kart bar

> Author: UI/UX Designer, 2026-07-05. **This is a forward design/art brief, not a build ticket and not
> a grade.** It exists to close the distance between "functional programmer UI" (which we HAVE — the
> shell skeleton, focus system, motion grammar, and styleboxes are all built to `frontend_ux_spec.md`
> and shipped) and the owner's explicit bar: *"gorgeous, approved by UI/UX, think Mario Kart."*
>
> Read-with: `frontend_ux_spec.md` (the interaction contract — DO NOT contradict; this brief only adds
> art + a few visual upgrades on top of it), `frontend_shell_visual_brief.md` (palette/DNA),
> `character_theme_bible.md` + `character_art_bible.md` (the Herd), `assets/CATALOG.md` (what art
> exists + the ChatGPT gen pattern), `docs/briefs/arena_rendering.md` (the per-asset spec style this
> doc mirrors).
>
> **The core finding:** the shell is NOT a bad UI. It is a *correct* UI wearing placeholder skins.
> Every "tech-demo" tell below is a missing or stand-in ART asset, not a broken layout or motion. So
> this brief is 80% an art-generation list (subject/silhouette/palette/size/count, ChatGPT-ready) and
> 20% small wiring upgrades. Ship the art, drop it into slots that already exist, and the screens jump
> from "intentional placeholder" to "purchasable."

---

## 0. What is already built (so we only spend on the gap)

Confirmed by reading the scenes/scripts. All of this is DONE and graded SHIP — do not rebuild it:

- **Shared skeleton** (header/content/footer, 12/78/10 bands, safe margins), the **living backdrop +
  scrim**, **screen-transition grammar** (forward/back scale-fade + content stagger), **footer hint
  chips**. (`MenuScreen.gd`, all `scenes/ui/*`.)
- **The reusable component system**: `MenuCard.tscn` (gradient key-art plate + art slot + glyph slot +
  name strip + tag + focus glow + accent border + SOON/LOCKED ribbon + lock-in check stamp),
  `ShellBtn`/`ShellBtnPrimary`, `Stepper`, `ToySlider`, `ToyToggle`, `Ribbon`, `MenuCardGlow`.
- **The focus/selection model**: springy scale-up + colored glow + lift + idle wobble on exactly one
  control; hover=focus; full neighbor wiring + wrap. Confirm squash-pop. All per spec §1.3.
- **CharacterSelect showcase machinery**: split stage, character-swap toss/bounce (`_apply_hero`),
  name-banner color cross-fade, spotlight glow recolor, squash-stretch idle loop, Random slot-machine,
  lock-in check + goat-roar callout + pose-jump, P1 pick-cursor flag, the stepper strip.
- **The six real goat idle sprites** (`bouncer_{color}_idle.png`) — Pogo/Butch/Ziggy/Puff/Vex/Billy,
  graded SHIP-CANDIDATE. These already render on CharacterSelect cards + stage.

**Therefore the entire remaining gap is:** (a) placeholder art in slots that expect real art, (b) a
placeholder logo, (c) a title screen missing its cast, and (d) a handful of cheap visual upgrades that
raise specific screens from "clean" to "Mario-Kart." Everything below targets exactly those.

---

## 1. ModeSelect — "CHOOSE YOUR GAME"

### 1a. What's tech-demo about it today
- **The four mode cards show a single letter** on a colored gradient plate: `B` / `T` / `G` / `S`
  (`ModeSelect.gd` `glyph` fields, rendered by `MenuCard`'s 120px `Glyph` label). A big chocolate
  letter on a color wash is the single most "programmer placeholder" thing in the whole shell — it
  reads as a wireframe, not a game. Mario Kart never shows you a letter; it shows you the *thing*.
- The four cards are differentiated **only by hue** (pink/blue/purple/orange gradients). Nothing on the
  card communicates what BRAWL vs GAUNTLET actually *is* — the tagline carries 100% of the meaning.
- All four modes are now LIVE (`soon:false`), so there's no "coming soon" drama to lean on — the cards
  have to sell four real modes on art alone, and right now they can't.

### 1b. The Mario-Kart target
Each card's top ~60% (the `Plate`/`Art` slot, ~360×300 inside the 380×520 card) becomes a **dynamic
Glossy-Toybox key-art vignette of the Herd doing that mode** — a tiny action diorama, chocolate-
outlined, on the card's themed gradient. The name (`ModeTitle` 56px) + tagline stay. Result: four cards
that each look like a mini box-cover. The focused card already pops+wobbles+glows; with real art in the
plate it becomes a confident "pick your game" fan, exactly the MK8 mode grid read.
- Keep the themed gradient plate BEHIND the art (art is transparent PNG) so the color-coding survives
  and the chocolate-outlined tile framing stays consistent card-to-card.
- Add a slow idle drift to the live mode's art (BRAWL) — already have `notice_bounce`; extend a gentle
  2s bob on the focused card's `Art` so the diorama breathes (motion is the identity).

### 1c. Art needed (4 assets — MUST-HAVE, this is the screen's whole fix)
Style suffix on all: *Glossy Toybox, thick chocolate `#3B2419` outlines, plastic-toy shine, vibrant
saturated color, transparent background (alpha PNG), square-ish framing with the subject centered.*
Reuse the existing goat cast so the modes feel like one world. Target **~900×700 px** each, transparent.

| # | File | Mode | Subject / silhouette | Palette accent |
|---|---|---|---|---|
| 1 | `assets/ui/modes/mode_brawl.png` | BRAWL | **Two goats clashing horns mid-air** — Butch (blue) and Pogo (pink) colliding head-on with a big cartoon impact-star burst behind them, jetpack flames trailing. The headbutt = the kill; this is the money shot. | P1 pink `#FF5FA8` |
| 2 | `assets/ui/modes/mode_trials.png` | TRIALS | **One goat (Ziggy, green) rocketing through a ring/checkpoint against a stopwatch** — a chunky chocolate-outlined stopwatch behind, a checkered-flag flourish, speed lines. Solo, time-attack energy. | P2 blue `#4AA8FF` |
| 3 | `assets/ui/modes/mode_gauntlet.png` | GAUNTLET | **One hero goat braced/defiant in front while a horde of little goat silhouettes crests behind** (a wave of horns), a shield motif optional. "Hold the line, they keep coming." | P5 purple `#A15FFF` |
| 4 | `assets/ui/modes/mode_sports.png` | SPORTS | **A goat headbutting the big gold-seam ball** (`objects/ball.png` already exists — match it) toward a goal net, grassy pitch stripe. Playful, teamy. | P6 orange `#FF7A2D` |

Wiring: drop each into `MenuCard`'s `Art` slot per mode (already supported via `set_art`); hide the
`Glyph`. Zero layout change.

---

## 2. CharacterSelect — "CHOOSE YOUR BOUNCER" (the showcase)

### 2a. What's tech-demo about it today
This is the **strongest** screen because the real goat art already loads — but it has two stand-in
tells:
- **The "portrait" and the "beauty pose" are the SAME side-view idle sprite.** On the grid card the
  full side-view blob sits centered on a cream tile; on the stage the identical side-view sprite is
  scaled up. It reads fine (motion sells it, per spec §5) but it is not the Mario-Kart *roster read* —
  MK cards are front-facing bust portraits, and the "picked driver" is a big three-quarter hero pose,
  not the same small sprite enlarged. Side-view-facing-right on the stage also means every hero "looks
  away" from the name banner rather than presenting to camera.
- **The name banner is a flat colored `Panel` with text** — clean, but a plain rounded rectangle. MK's
  picked-character nameplate is a designed object (angled, badged). This is a nice-to-have upgrade.
- **The spotlight is a code-drawn radial `StyleBoxFlat` shadow** — acceptable (it's soft + colored,
  not a debug rect) but a painted "stage/podium" plate would lift it.

### 2b. The Mario-Kart target
The layout is right; swap textures + add one nameplate object:
- **Grid cards → head-and-shoulders bust crop** of each hero facing the camera (three-quarter), so the
  2×3 grid reads as a lineup of faces (MK roster). Until busts exist, the current centered idle is an
  acceptable placeholder — but busts are the single biggest CharacterSelect upgrade.
- **Stage → a big three-quarter "beauty pose"** per hero, presenting toward the name banner, keeping
  the squash-stretch idle + swap-toss that already work. Butch flexing, Pogo mid-boing, Vex bowing —
  the poses the art bible §3 already scoped.
- **Nameplate** becomes a proper angled ribbon/plate (art or an upgraded stylebox — see 2c #3).

### 2c. Art needed (prioritized)
**Nice-to-have (the screen ships today on idles) but high ceiling — do these in art-bible PASS #2/#4:**

| Prio | File | Subject | Size | Notes |
|---|---|---|---|---|
| MUST-for-title, nice-for-select | `assets/ui/portraits/portrait_pogo.png`, `portrait_butch.png` | Pogo & Butch three-quarter-front **beauty poses**, ornate horns (art bible §4) | ~1000×1000, transparent | Doubles as title co-star art (§4). Do these two FIRST — they serve two screens. |
| Nice | `portrait_ziggy/puff/vex/billy.png` | The other four three-quarter-front busts, same treatment | ~1000×1000, transparent | Completes the roster bust set. Per-hero personality pose (Vex bow, Billy harrumph). |
| Nice | `assets/ui/portraits/bust_{hero}.png` (×6) | Tight head-and-shoulders crops for the GRID cards (can be crops of the beauty poses) | ~600×600, transparent | If we generate the six beauty poses, the grid busts are free crops — no separate gen. |
| Optional | `assets/ui/nameplate.png` | An angled chocolate-outlined banner plate (9-slice) to replace the flat name `Panel` | 9-slice strip | Or just upgrade the stylebox with a slight skew + double border. Lowest priority. |

**Rule (inherited, hard):** horns stay neutral bone `#F2E6D0`, never tinted to body color; body color is
the player-color read. Any tinted-horn portrait = Reject (art bible §0.2).

**No art dependency to ship** — CharacterSelect already looks good; these raise it from "good" to "MK."

---

## 3. ArenaSelect — "PICK YOUR PEAK" (the worst offender)

### 3a. What's tech-demo about it today
- **All 11 arena cards are colored gradient tiles + a name band. Nothing else.** (`ArenaSelect.gd`
  assigns a spread-palette accent per arena precisely *because* every level's JSON `theme` is "grass"
  — so without the spread they'd be 11 identical green rectangles.) This is the single most tech-demo
  screen in the shell: a grid of 12 near-identical tinted rounded rectangles differentiated only by hue
  and a text label. It reads as a level-select debug menu, not a game. Mario Kart's track select is
  *all thumbnails* — you recognize Rainbow Road by its picture, never by its name.
- The RANDOM card (rainbow gradient + spinning `?`) is actually the best-looking tile on the screen,
  which inverts the intended hierarchy (the real content should out-shine the shuffle option).
- The circuit cards carry 2 lines of text (name + stars + arena count / unlock hint) on the same blank
  gradient — dense text on an empty plate.

### 3b. The Mario-Kart target
Every card gets a **real thumbnail image of the arena** in the plate slot, so the grid becomes a
visual map-select. Two routes, cheapest first:

- **RECOMMENDED (cheap, authentic, no ChatGPT): live-baked thumbnails.** Our arenas already render in
  the Glossy-Toybox `ArenaRenderer`. Build a one-shot tool that loads each level, frames the whole
  arena wide, and screenshots it to `assets/ui/thumbs/<arena_id>.png` (~512×320). Drop those into the
  card `Art` slot. This gives 11 *authentic* thumbnails that look exactly like the game, cost zero art
  generation, and auto-update if a level changes. This is the arena_rendering pipeline pointed at the
  menu. **This is the fix — spec'd as a build task, not an art gen.** (Fallback if per-card static is
  heavy: a single `capture_thumbnails` tool run offline that writes PNGs once; NOT live SubViewports
  per card at runtime.)
- **CEILING-RAISER (later, optional): painted circuit crests.** Give each *circuit* a badge/crest so
  the circuit cards stop being blank text plates. 3–4 assets only (see 3c). The individual arena tiles
  stay on baked thumbnails.

Hierarchy fix: once real thumbnails land, **tone the RANDOM card's rainbow down** (or give it a proper
"shuffle three arenas" collage) so it's the fun default, not the flashiest tile.

### 3c. Art needed
| Prio | File | Subject | Size | Notes |
|---|---|---|---|---|
| MUST (build task, not gen) | `assets/ui/thumbs/<arena_id>.png` ×11 | Baked wide screenshots of each arena via ArenaRenderer | ~512×320, opaque | The core fix. Use the arena's real render. Rounded/outlined framing comes from the card, so a plain rectangular capture is fine. |
| Nice | `assets/ui/circuits/crest_meadow_mile.png`, `crest_scrapworks.png`, `crest_high_wire.png`, `crest_mayhem_mile.png` | A **chocolate-outlined toy emblem per circuit** — Meadow Mile = a grassy hill + sun badge (green); Scrapworks = a gear/wrench + hazard-stripe shield (violet); High Wire = a tightrope/mountain-peak pennant (teal); Mayhem Mile = a cracked-skull-free "danger burst" with crossed hammers (red). Heraldic, readable at 120px. | ~600×600, transparent | Sits on the circuit card as its art; the arena-count/stars text moves to a clean band. Only 4 assets. |
| Optional/ceiling | `assets/ui/thumbs_painted/<arena>.png` | Hand-styled painterly arena thumbnails | ~512×320 | Only if baked screenshots read flat; not expected to be needed. |

---

## 4. MainMenu / Title — the store hero shot

### 4a. What's tech-demo about it today
- **The title screen has NO characters on it.** The scene (`MainMenu.tscn`) is: `title_bg.png` (the
  north-star image, which has *painted* bouncers baked in) + `Logo` + a 3-button stack + footer. The
  spec (§2.1) called for the six Herd bobbing/boinging as live parallax — **that was never built.** So
  the title is a static image + logo + buttons. For a game whose entire identity is "nothing is ever
  still, bounce is the brand," the front door is the one screen with no live cast. Biggest emotional
  miss even though it's technically clean.
- **The logo is a placeholder.** `assets/ui/logo.png` is a 1.3 MB untrimmed copy of `reference/
  logo_v1.png` — a generic "GOTTABOUNCE" wordmark with **no goat in it**. The mascot (Pogo) is the face
  of the game per the theme bible §3; the logo should carry him.
- The `stretch_mode = 5` (keep-aspect-centered) on an untrimmed PNG risks visible bounding-box slack.

### 4b. The Mario-Kart target
The title should say "adorable chaos" in one glance:
- **Add the living Herd** as parallax bobbers over the backdrop, in front of the logo's negative space:
  **Pogo (pink) mid-boing + Butch (blue) winding a headbutt** front-and-center flanking the button
  stack (bounce meets smash — the whole game in one frame, theme bible §3), the other four drifting
  smaller at depth. Reuse the six existing idle sprites — **zero new art**, pure wiring: each a
  `TextureRect` on an independent y-bob (±14px, 1.6–2.4s sine, random phase) + slow x-drift + ±3° sway
  + the §5 squash-stretch. This is the highest-impact, lowest-cost single change in the whole brief.
- **A proper goat logo** with Pogo integrated.

### 4c. Art needed
| Prio | File | Subject | Size | Notes |
|---|---|---|---|---|
| MUST | `assets/ui/logo.png` (replace) | **The goat wordmark:** "GOTTA" glossy yellow `#FFC93F` / "BOUNCE" glossy cyan `#4AA8FF`, thick chocolate outline, drop shadow, **Pogo (pink pygmy goat, nub horns, huge grin) bursting up out of / perched on the wordmark mid-boing**. Trimmed tight (no bounding slack), transparent. | ~2048×1024, transparent | The single highest-leverage title asset. Mascot-on-the-logo is the box art. Keep the existing color split so it stays on-brand. |
| Free (wiring) | *(none — reuse `bouncer_*_idle.png`)* | The six Herd bobbers on the title | — | No art; build task. Do this even before the logo lands — it transforms the title with assets we own. |
| Optional/ceiling | `assets/ui/title_keyart.png` | A dedicated wide title key-art (north-star recomposed with clear negative space for logo+buttons, Pogo+Butch featured) | 1920×1080, opaque | Nice-to-have; the reused north-star + live bobbers already carry it. |

---

## 5. Cross-screen consistency notes (small, cheap, do alongside)
- **Kill every primitive `Glyph` placeholder** once real art lands (mode dioramas, arena thumbnails).
  A single chocolate letter/`?`/emoji on a plate is the recurring tech-demo tell across ModeSelect and
  the RANDOM tile — none should remain after the art pass.
- **Footer hint chips**: currently letter chips (`A`/`B`/`< >`) — fine for Phase 1 per spec §1.4. A real
  gamepad-glyph set is a separate, later, low-priority asset (not in scope here).
- Keep **chocolate `#3B2419` outline on every new asset** (logo, mode art, crests, portraits) — it is
  the brand line that makes six screens read as one product. Any new asset without it is off-model.
- All new art is a **transparent PNG dropped into an existing slot** (except baked arena thumbnails,
  which are opaque captures). No layout, no stylebox, no motion changes required — the shell already
  animates whatever texture you hand it.

---

## 6. Prioritization — if we polish ONE screen first

**Do the TITLE (MainMenu) first**, and do it in two moves: (1) wire the six existing idle sprites as
live Herd bobbers — *free, uses assets we already own, and is the fastest transformation in the brief*;
(2) generate the one goat logo. Rationale:
1. **First impression is the whole ballgame** for "does this look like a real game." The title is the
   frame every screenshot, trailer, and store page leads with. It is currently the one screen with a
   placeholder logo AND no cast — the exact opposite of the bounce identity.
2. **Cheapest max-impact ratio in the brief.** The bobbers cost zero art (reuse the six idles) and turn
   a static poster into a living toybox. The logo is one asset. Two moves, one of them free.
3. It directly answers the owner's phrasing — a Mario-Kart title screen is alive and mascot-forward;
   ours would go from "clean menu" to "purchasable" with the least spend.

**Then, in order of impact-per-asset:**
2. **ModeSelect mode dioramas (4 assets)** — kills the single-letter tell on the first interactive
   screen; four cards become four mini box-covers.
3. **ArenaSelect baked thumbnails (build task, ~0 art)** — fixes the worst-looking screen (11 tinted
   rectangles → a visual map-select) with a tool run, not an art budget.
4. **CharacterSelect beauty poses/busts (6, start with Pogo+Butch)** — the showcase is already good;
   these lift it to great and the Pogo/Butch pair double as the title co-stars.

Net: the entire "gorgeous, Mario-Kart" gap is **~1 logo + 4 mode dioramas + up to 6 portraits + 4
optional crests + one thumbnail-bake tool + one free bobber-wiring pass.** The layouts, motion, and
focus are already there waiting for them.
