# Art Brief — CharacterSelect Beauty-Pose Busts (the roster read)

> **Author:** Art Director, 2026-07-06. **Status:** APPROVED FOR GENERATION (owner greenlit
> "better char select sprites sounds good"). **Priority:** nice-to-have — CharacterSelect already
> ships SHIP-class on the idle sprites; this raises it from "good" to "Mario-Kart-tier." Do
> **Pogo + Butch FIRST** (the owner's start pair; they also double as the title co-stars).
>
> **Replaces (visually, not on disk):** the stand-in where CharacterSelect's big stage pose AND the
> 2x3 grid cards both render the same **side-view idle sprite** (`bouncer_<skin>_idle.png`). The idle
> reads fine (motion sells it) but it is not the roster read — MK cards are front-facing bust
> portraits and the picked driver is a big three-quarter hero pose, not the small sprite enlarged.
> Side-view-facing-right also means every hero on the stage "looks away" from its own name banner.
>
> **Read-with (do not contradict):** `docs/briefs/character_theme_bible.md` (THE cast, LOCKED —
> personalities), `docs/briefs/character_art_bible.md` (§0 hard constraints, §4 the Pogo+Butch beauty
> spec this expands, §5 naming/intake, §6 grading), `docs/briefs/frontend_visual_polish.md` §2 (the
> slot this fills), `assets/CATALOG.md` (proven prompt + intake), `docs/VISION.md` (Glossy Toybox).
> Style ref: `assets/reference/style_north_star.png`.
>
> **This is a brief, not a build ticket and not a grade.** No code here. It specifies the assets +
> the exact generation recipe so a follow-up gen pass executes without re-deriving anything, and the
> Ship/Fix/Reject bar I will grade the results against from in-game screenshots.

---

## 0. The gap we are closing (named)

CharacterSelect (`src/ui/CharacterSelect.gd`) renders two things from ONE texture per hero, pulled by
`_tex(skin)` = `res://assets/characters/bouncer_<skin>_idle.png`:

1. **`$Stage/Pose`** — the big picked-hero showcase (TextureRect, squash-stretch idle + swap-toss).
   Today: the side-view idle scaled up, facing RIGHT — toward the grid, *away* from its own
   `$Stage/NameBanner` on the left.
2. **`$Grid`** (2x3) — six `MenuCard`s, each fed the same idle via `set_card({"art": tex})`. Today:
   six full side-view blobs centered on cream tiles. Reads as a sprite-sheet, not a lineup of faces.

The code was written for exactly this swap — its header says *"today the portrait/beauty_pose are the
six real idle sprites; when painted art lands only the texture swaps."* So this brief is pure art
generation + a one-line load-path note for the lead; **zero layout/motion change.**

---

## 1. What a "beauty-pose bust" IS here (vs the idle)

One dedicated **three-quarter FRONT beauty portrait per hero** — the "pick me" hero card, MK8 driver
select. Deltas from the idle, all deliberate:

| Axis | Idle sprite (shipped) | Beauty-pose bust (this brief) |
|---|---|---|
| **View** | strict side, facing right | **three-quarter FRONT**, presenting to camera |
| **Crop** | full body, small, lots of air | **waist-up / chest-up**, subject FILLS the frame |
| **Energy** | neutral standing idle | **peak-personality signature pose** (see §3) |
| **Horns** | simplified, inside the head-capsule (gameplay-zoom rule) | **ORNATE, un-simplified** — this is the ONE place the horn-simplification rule relaxes (art bible §0.3, §4). Full curl / full spiral / full sweep. |
| **Face** | the idle expression | **cranked** — biggest eyes, widest grin, fullest smirk. Sell the character. |

**One asset serves both slots.** Frame it waist-up so:
- the full portrait drops into `$Stage/Pose` (the big showcase), and
- the same file on the `$Grid` card (250x250, KEEP_ASPECT) reads as a bust — the head + horns + upper
  body sit in the top-center, so the card crop naturally lands on the face.

Do NOT generate separate `bust_<hero>` crops in this pass (art bible §2c: "if we generate the six
beauty poses, the grid busts are free crops"). Only revisit if grading shows the grid card reads
bottom-heavy — then a tight top-crop, no re-gen.

### Framing lock (uniformity is the roster read — hard requirement)
All six busts MUST share the **same crop line, same eye height, same subject scale, same
front-three-quarter head turn.** The grid is a *lineup*; if one hero is zoomed tighter or turned more
than another, the row looks ragged and amateur. Generate them as a set with one framing sentence
(§4), grade them side-by-side at 250px before intake. This is the mats' "hold all four at 64px" rule
applied to faces.

---

## 2. Glossy Toybox style constraints (on-model or Reject)

Inherited verbatim from the art bible §0 — these are pass/fail:

1. **Same character wearing horns.** The bust is the EXACT idle hero rotated to front-three-quarter
   and cropped in — same glossy jelly body, same big white eyes + shine dots, same rosy cheeks, same
   tiny stubby arms/feet, same chunky metallic-orange jetpack, same chocolate outline weight, same
   plastic-toy shine. A redrawn body, a new render style, or a mangled jetpack = **Reject**.
2. **HORNS/BEARD ARE NEUTRAL BONE `#F2E6D0` — never tinted to the body color.** Same chocolate
   outline + plastic shine as the jetpack. A pink-horned Pogo or blue-horned Butch = **auto Reject**
   (it breaks the player-color read the whole cast depends on).
3. **Chocolate outline `#3B2419`, thick and unbroken** — the brand line that makes every screen read
   as one product. This matches the outline on the shipped idles; keep the exact weight.
4. **Vibrant, saturated body color; soft plastic-toy shine highlights.** No washed-out pastel, no
   flat matte fill, no gradient-only body. If it reads flat or desaturated next to the shipped idle,
   that's a Fix.
5. **Transparent background (alpha PNG).** No sky, no ground, no baked shadow, no card behind it — the
   card art comes from the `MenuCard` plate + the stage spotlight, not the asset.

### Body-color palette (FROZEN — theme bible §2; matches `PartyMatch.PLAYER_COLORS`)
| Hero | Color | Body hex | Horns/beard | Outline |
|---|---|---|---|---|
| POGO | pink | `#FF5FA8` | bone `#F2E6D0` | choco `#3B2419` |
| BUTCH | blue | `#4AA8FF` | bone `#F2E6D0` | choco `#3B2419` |
| ZIGGY | green | `#54C94A` | bone `#F2E6D0` | choco `#3B2419` |
| PUFF | yellow | `#FFC93F` | bone `#F2E6D0` | choco `#3B2419` |
| VEX | purple | `#A15FFF` | bone `#F2E6D0` | choco `#3B2419` |
| BILLY | orange | `#FF7A2D` | bone `#F2E6D0` | choco `#3B2419` |

### Readability note (portrait, not gameplay-zoom — but still a floor)
These never appear at 25px gameplay zoom, so ornate horns are fine. BUT the grid card is only ~250px,
and the picked bust on the stage sits behind a spotlight. So: **color reads first, then horn shape,
then face** — same priority order as in-play. Keep even the ornate horns BOLD and thick enough that
Vex's spiral / Butch's curl don't turn to noodles at 250px. Filigree-thin horns that dissolve on the
grid card = Fix (thicken).

---

## 3. Per-character pose direction

Peak personality, three-quarter front, presenting to camera, ornate horns. Each pose must let a
stranger name the character's *attitude* in one glance (blurbs in the code are the tone check).

### DO FIRST — the owner's start pair (also the title co-stars, art bible §4)

**POGO (pink) — the joyful mascot.** *"Can't stop boinging. Won't stop boinging."*
- **Pose:** mid-boing — caught at the top of a bounce, **both tiny arms flung up**, body stretched
  slightly tall, feet tucked/kicked up. Pure launch-joy.
- **Face:** maximum sparkly-eyed open-mouth grin, the biggest eyes in the cast, ears up and eager.
- **Horns:** the two tiny bone nub buds (deliberately the *least* horn — his read is "the little
  one," biggest eyes + smallest roundest body). Keep him reading a touch smaller/rounder even here.
- This is the store/app-icon hero shot. Make it the most instantly lovable frame in the game.

**BUTCH (blue) — the cocky smash co-star.** *"Come at me. I've been stretching."*
- **Pose:** wrestler entrance flex — chest puffed, **one tiny front arm curled into a bicep flex**,
  square-shouldered, jaw set. The macho joke: a 40cm goat doing a heavyweight pose.
- **Face:** confident smirk, half-lidded "come at me" eyes. Smug baby, never a menace.
- **Horns:** the full ornate bighorn CURL wrapping the sides of the head — the biggest, most dominant
  horn shape in the cast, un-simplified. This is THE money horn; make the curl bold and glorious.
- Butch + Pogo side by side = smash meets bounce, the whole game in two cards.

### THEN — the rest of the Herd (same treatment, one signature pose each)

| Hero | Signature pose | Face | Horn (ornate) |
|---|---|---|---|
| **ZIGGY** (green) | mid-trick show-off lean, one arm out doing finger-guns / a "watch THIS" flourish; leaner, taller posture, reads as motion | cocky grin, one eyebrow raised, eyes on the horizon | long backswept scimitar horns flaring UP-and-BACK like speed lines (opposite read from Butch) |
| **PUFF** (yellow) | chaotic wobble-laugh, arms flung out mid-flail, off-balance goofball energy | eyes squeezed shut in an open-mouth laugh (the idle's exact face) | the WOOL is the read — exaggerate the bumpy cloud-fluff silhouette; tiny bone horn tips half-buried, woolly forelock |
| **VEX** (purple) | theatrical diva bow / chin-up flourish, one arm sweeping across in a "you may bow now" presentation | raised chin, lidded confident eyes, little fanged grin — smug, NEVER scary | dramatic full corkscrew spiral horns rising straight up (the markhor signature) — the most ornate shape; go full-detail here |
| **BILLY** (orange) | gruff crossed-arms harrumph (or one-brow-up "hmph"), weight back, unimpressed veteran | bushy brows, a squint, a knowing half-smile under the beard | short forward-jutting straight horns + the cast's ONLY chin beard (bone `#F2E6D0`, tidy goatee) — beard is his strongest silhouette tell |

**Distinctness map (must survive as a set):** Pogo = tiny nubs/smallest · Butch = side curl · Ziggy =
up-back sweep · Puff = fluff outline · Vex = vertical spiral · Billy = forward stubs + beard. Horn
direction + size + (Puff/Billy) outline/beard vary on three axes, so the row separates by shape even
before color.

---

## 4. Generation recipe (execute this — no re-deriving)

Pipeline: `docs/PIPELINE.md` §2 + the art-pipeline skill. ChatGPT-via-Chrome, paste-edit technique.

### Step 1 — attach references (the consistency trick)
For EACH hero, attach BOTH:
- `assets/reference/style_north_star.png` (the style bible), AND
- that hero's shipped idle: `assets/characters/bouncer_<color>_idle.png` (pogo=pink, butch=blue,
  ziggy=green, puff=yellow, vex=purple, billy=orange).

Attaching the idle is what keeps it the SAME character. Say so in the prompt: *"same exact character
as the attached sprite."*

### Step 2 — prompt skeleton (fill the [BRACKETS] per hero from §3)
Expands the art bible §4 portrait frame. One framing sentence shared by all six (the uniformity lock):

> Hero portrait of **[NAME]**, the same exact character as the attached [COLOR] blob goat sprite —
> keep the glossy [COLOR] jelly body, the two big white cartoon eyes, the rosy cheeks, the tiny stubby
> arms and feet, and the chunky metallic-orange toy jetpack EXACTLY. Now turn him to a **three-quarter
> FRONT view facing the camera**, cropped **waist-up so the character fills the frame**, head and
> horns in the top-center. Pose: **[SIGNATURE POSE FROM §3]**. Face: **[FACE FROM §3]**. Horns/beard:
> **[ORNATE HORN FROM §3]**, rendered in neutral warm BONE color (#F2E6D0) with the same chocolate
> outline and plastic shine as the jetpack — NOT tinted to the body color. Big personality, glossy
> toy-figure hero-select portrait.

Then append the **base style suffix VERBATIM** (from `assets/CATALOG.md`):

> Style: high-quality glossy cartoon game art, thick clean dark-chocolate outlines, vibrant saturated
> colors, soft plastic-toy shine highlights. IMPORTANT: fully transparent background (alpha PNG) - no
> sky, no ground, no shadow, just the single subject centered with empty space around it. Square image.

**Generate all six with the identical framing clause** ("three-quarter FRONT... waist-up... head and
horns top-center") so the crop line matches across the set. If ChatGPT drifts the crop/scale between
heroes, re-roll the offender against the first accepted bust as an added reference — do not accept a
ragged lineup.

### Step 3 — download + intake (art.py)
Verify the Downloads timestamp BEFORE intake (a missed click silently reuses the previous file —
CATALOG gotcha). Stage raw as `tools/out/portrait_<hero>_raw.png`, then:

```
python tools/art.py trim  tools/out/portrait_<hero>_raw.png  assets/ui/portraits/portrait_<hero>.png
python tools/art.py check assets/ui/portraits/portrait_<hero>.png
# if check reports "no transparency at all" (baked/fake checkerboard bg — common on ChatGPT edits):
python tools/art.py keyout tools/out/portrait_<hero>_raw.png assets/ui/portraits/portrait_<hero>.png --tol 45
python tools/art.py check assets/ui/portraits/portrait_<hero>.png
python tools/art.py info  assets/ui/portraits/portrait_<hero>.png   # confirm ~1024px + healthy alpha %
```

- **Filenames (locked):** `assets/ui/portraits/portrait_{pogo,butch,ziggy,puff,vex,billy}.png` (art
  bible §5; matches the frontend polish brief). Do NOT overwrite the `bouncer_<color>_idle.png` load
  slots — those stay the in-game sprites; the busts are a separate, additive UI asset set.
- **Target size:** ~1024px on the long edge (busts want more resolution than the ~750px idles because
  the stage scales them up). `keyout --tol 45` is the known setting for ChatGPT's fake-checkerboard
  edit outputs.

### Step 4 — wiring note for the lead (NOT my job to code; flag it)
CharacterSelect must prefer the bust and fall back to the idle so a partial set (Pogo+Butch only)
ships cleanly. The seam already exists: `_tex(skin)` feeds both `$Stage/Pose` and each `$Grid` card's
`"art"`. The minimal change is a portrait-first lookup keyed by **hero id** (not skin) with an
existence-guarded `load()` that falls back to the idle when `portrait_<id>.png` is absent — so Ziggy/
Puff/Vex/Billy keep their idles until their busts land. Deliver the assets `KEEP_ASPECT` (both slots
already avoid stretch); no stylebox/motion change. Confirm the swap-toss + squash-stretch idle still
play on the new texture (they're direction-agnostic, so a front-facing bust is fine).

---

## 5. Grading rubric (Ship / Fix / Reject — from in-game screenshots only)

I grade from the running screen, never the asset file alone (my mandate + PIPELINE loop). **Do NOT
launch the game while another agent holds port 9090.** When the busts are in and the seam is wired,
capture via the rendered playtest loop:
`powershell -File tools/run_game.ps1 res://scenes/ui/ShellRoot.tscn` → navigate to CharacterSelect →
`python tools/gbplay.py screenshot tools/out/charselect_busts.png`. **Submit:** (a) the full grid with
all cards visible, (b) the stage with Pogo picked, (c) the stage with Butch picked, (d) one grid
screenshot at the true on-screen card size (~250px) so I can judge the small read.

Verdict per bust:

1. **Style coherence** — is it unmistakably the SAME hero as the shipped idle, now front-three-quarter?
   Same glossy body, eyes, shine, chocolate outline weight, untouched orange jetpack. Redrawn body /
   different render style / mangled jetpack = **Reject**.
2. **Bone-horn rule (hard pass/fail)** — horns/beard are bone `#F2E6D0`, NOT tinted to body color.
   Any tinted horn = **auto Reject**.
3. **Personality read** — can I name the attitude from the pose alone (Pogo = joy-boing, Butch =
   flex, Ziggy = show-off, Puff = chaos, Vex = diva, Billy = grump)? A generic front-facing standing
   blob with no signature pose = **Fix** (restate the §3 pose).
4. **Presents to camera** — the hero faces the viewer / the name banner, not away. A side-view or a
   hero "looking off-screen" defeats the whole point = **Fix**.
5. **Grid-card readability at ~250px** — color reads first; horn shape second; the face + horns land
   in the card crop (not cropped to a belly or a foot). Ornate horn dissolves to noodles/mush at
   250px = **Fix** (thicken/bolden, don't shrink).
6. **Set uniformity** — held side-by-side in the grid, do all present at the same crop line, eye
   height, subject scale, and head turn? One zoomed/turned differently = **Fix** the outlier
   (re-gen against an accepted bust as reference).
7. **Polish** — clean alpha (no seam halo, no baked bg, no checkerboard), trimmed, no stretching on
   the `$Stage/Pose` TextureRect or grid card, shine intact, outline unbroken.

**Ship** = all seven pass. **Fix** = numbered, specific (which hero, which item, what to change).
**Reject** = body redrawn, wrong style, tinted horns, or side-view (restate: front-three-quarter
beauty crop of the EXACT idle hero with ornate bone horns).

### Partial-ship policy
Pogo + Butch alone may ship the moment they pass (the other four keep their idles via the §4 fallback
— a mixed grid of two busts + four idles is acceptable as a staged rollout, NOT a permanent state).
The full six is the target; log the remaining four as backlog when Pogo+Butch land.
