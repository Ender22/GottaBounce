# Art Brief — Arena Rendering v1 ("Glossy Toybox" in-game)

> Author: Art Director. Status: APPROVED FOR BUILD.
> Replaces the debug look in `tools/out/verify_1.png` (flat Polygon2D blocks).
> Target: the arena reads like `assets/reference/style_north_star.png` — a toy diorama,
> not sprites pasted on a jpeg. The programmer implements this verbatim; I grade the
> result from in-game screenshots only.

## The gap we are closing

`verify_1.png` fails on every axis: no outlines, no volume, washed-out desaturated colors,
tier is a flat pastel tint you cannot name at a glance, background is a naked gradient,
platforms float with no shadows. The north star succeeds because of five things we will
reproduce systematically: **thick dark-chocolate outlines on everything interactive**,
**saturated toy plastic/candy materials**, **grass-and-dirt chunky platform bodies**,
**bounce surfaces that look like real toys (trampoline canvas, coils)**, and **a soft
painterly background with no outlines** (outline = "you can touch this" — that contrast
IS the depth trick).

Working assumption on bounce power order (confirm with design, colors are mapped to it):
`marshmallow < bubblegum < trampoline < spring`. Bumper = walls/obstacles, bounce but not a tier.

---

## 1. Platform body strategy

### Decision: 3-slice horizontal bodies + theme-agnostic tier mats + vertical 3-slice walls

A platform is rendered as **up to three stacked pieces**:

1. **Body** — themed art (grass+dirt block), 3-sliced horizontally to any width.
2. **Tier mat** — the bounce surface strip laid on top of the body (see §2). This is what
   carries tier readability; the body only carries theme.
3. **Decals** — code-scattered tufts/flowers to break up center-slice repetition.

We do NOT generate per-size platform art and we do NOT snap level design to S/M/L widths —
widths stay free (JSON is authoritative for gameplay). What we DO snap is **height**:

**Canonical body heights (world px): H32, H64, H128.** The renderer snaps the *art* to the
nearest canonical height (colliders stay exact — a ≤20% art/collider height mismatch is
invisible in play; the collider top edge is always the authoritative surface line the mat
sits on). Rationale: horizontal stretch is hideable with slicing; vertical stretch of
painterly grass/dirt is the ugliest possible failure and is hereby banned.

- **H128 "chunky"** (floors, e.g. the 1792×128 dev floor): full grass-top + rocky dirt body.
- **H64 "standard"** (mid platforms, 256×64 etc.): same art family, thinner dirt.
- **H32 "slab"** (thin 30–48px platforms, e.g. 500×36): **no body at all — the tier mat alone
  is the platform.** A grass slab 36px tall reads as a smear; the mat reads as a toy. Rule:
  `h ≤ 48 → mat only`.

### 3-slice spec (all horizontal bodies and mats)

- Source sprite trimmed to alpha. Cut lines: **left cap = leftmost 22%, right cap =
  rightmost 22%, center = middle 56%** (mats: 18/64/18). Caps keep every organic overhang
  (grass tufts, drips) so nothing gets sheared.
- **Caps never stretch non-uniformly.** Uniform scale only, factor = target art height ÷
  source height.
- **Center is TILED, not stretched.** Lay N copies of the center slice at the cap scale
  factor; then apply one shared horizontal correction to all center tiles so the total
  width is exact. Allowed correction: **0.85×–1.20× per tile. Never exceed 1.25×** — if you
  would, add a tile. Never mirror-flip alternate tiles (breaks the light direction — all
  art is lit top-left).
- **Prompt-side rule that makes tiling invisible:** every sliceable body/mat is generated
  with a deliberately *quiet, repeating* middle (no flowers, no unique rocks mid-span —
  see prompts in §4). Uniqueness is added back by code-scattered decals with a seeded
  random (seed = hash of platform x,y so it's stable frame-to-frame and across clients).
- **Art bleed above the collider:** the grass fringe extends **~10–14 world px above the
  collider top** and caps extend **~8 px past the collider sides**. The art is bigger than
  the physics rect on purpose — toys are fluffy. Anchor: collider top edge = the
  grass "soil line" (base of the tufts), not the tip of the blades.

### Vertical walls (the 30×520 / 64×320 bumpers and any future themed pillars)

**Never rotate a horizontal platform 90°** — sideways grass with sideways lighting is an
instant Reject. Walls get their own asset, 3-sliced **vertically** (top cap 22% / middle
56% / bottom cap 22%), same tiling rules rotated. For v0 the only walls are bumpers, which
use the bumper foam-post look (§2). Wall art bleeds ~8 px past the collider on its face side.

### Whole-sprite exception

If a platform's target aspect ratio is within ±20% of a source sprite's native aspect,
skip slicing and draw the whole sprite uniform-scaled (≤10% non-uniform fudge allowed).
This is how one-off hero platforms (the existing `platform_wide.png`) get used.

---

## 2. Tier readability system

### Decision: generated overlay mats (one per tier), theme-agnostic, plus code FX

Per-tier generated *platform* variants would cost 4 tiers × 3 heights × 6 themes = 72
coherent sprites — not achievable with our pipeline, and worse for players because the tier
look would change per theme. Pure code-tinted overlays are what `verify_1.png` already is —
flat and amateur. The answer is **4 generated mat strips, identical in every theme**, laid
on the platform top. Players learn 4 toys once, and they read on grass, candy, lava,
whatever. The mat is the contract: *same mat = same bounce, everywhere in the game.*

Each tier is distinguishable by **three redundant channels** — color, silhouette motif,
and value (brightness) — so it survives colorblindness and far zoom:

| Tier | Toy | Primary hex | Support hex | Deep/shade hex | Silhouette motif (reads at 14 screen px) |
|---|---|---|---|---|---|
| **Marshmallow** (weakest) | quilted marshmallow cushion | `#FFF6EC` warm white | `#FFC9DD` pale pink dust | `#E8C4B8` | soft **puffy quilted bumps**, matte, squishy overhang drips |
| **Bubblegum** | glossy gum slab | `#FF4FA3` hot magenta | `#FF8AC5` gloss highlight | `#D42E7E` | **rounded melty blobs / stretched gum**, wet shine dots |
| **Trampoline** | toy trampoline | rim `#2F6BD8` royal blue | canvas `#FFD23F` golden yellow | `#F5A623` canvas shade, `#1E4CA8` rim shade | **segmented padded rim + flat canvas with X-stitches** — two-color band is unique to this tier |
| **Spring** (strongest) | coil spring row | cap bar `#FF6A2A` safety orange | coils `#D9DEE7` silver | `#D14A12`, coil shade `#9AA6B5` | **visible zigzag coils under a bar** — the only tier with gaps/negative space in its silhouette |
| **Bumper** (not a tier) | foam pool bumper | `#98A1AF` grey | `#F4F6F9` white studs | `#6E7684` | **rounded post with big glossy studs** — the only grey interactive object in the game |
| — outline, all of the above | — | `#3B241B` dark chocolate, thick | | | mandatory on every interactive piece |

Value ramp at a squint: white → hot pink → blue/yellow → orange/silver → grey. Five
distinct brightness/temperature signatures; no two tiers share both hue family and motif.

**Reserved colors:** nothing in any background or platform body may use `#FF4FA3`-family
magenta, safety orange, or the blue+yellow rim/canvas pairing. Grass-theme flowers stay
white/pale-yellow and small. (Note for the character brief: keep bouncer pink rose-leaning
like `bouncer_pink_idle.png` — the bubblegum magenta is deliberately more violet/hot, and
players always carry the chocolate outline + white eyes + jetpack silhouette.)

### Mat geometry (code)

- Mat world height: **28 px** for H64/H128 platforms, drawn sitting on the collider top and
  rising **~8 px above it** (toys have thickness). For mat-only slabs (`h ≤ 48`): mat art is
  uniform-scaled so its height = collider height + 12 px bleed.
- Mat spans the **full collider width** (it IS the bounce surface — a mat narrower than the
  collider is a readability lie and an automatic Fix). 3-slice per §1.
- Draw order: body → mat → end decals (grass tufts overlapping the mat's outer corners,
  ~20% of cap width) → back-edge tufts peeking above the mat. This "grass hugging the toy"
  seam is a big part of the diorama feel.
- Bumpers: no mat. The **whole body** uses the bumper asset (horizontal block or vertical
  post variants) because bumpers bounce on all faces.

### Code FX per tier (cheap, mandatory — this is half the readability)

- **On bounce:** mat does a squash-stretch pulse (scale y 0.8→1.05→1.0, 0.12s) and emits a
  tier-colored ring flash (primary hex, additive, 0.2s). Marshmallow: slow deep squash
  (0.7, 0.25s) + tiny white puff particles. Spring: overshoot stretch (1.25) + metallic
  glint. Trampoline canvas dips (shader or 3-frame sprite swap later; scale pulse for v0).
- **Idle:** springs get a ±1px vertical shimmer every few seconds; others static. No
  constant pulsing on everything — motion must mean something.

### Far-zoom check (do the math before grading)

Dev arena bounds ≈ 3900 world px wide → at 1920 output the far camera is ~0.49 px/world.
Mat = 28 world px → **~14 screen px** plus outline: color band + motif still read. Anything
in this brief that would drop below ~10 screen px at far zoom must be simplified, not
shrunk (that's why mats have exactly one motif each, not texture noise).

---

## 3. Scene assembly — "toybox diorama", not "sprites on a jpeg"

What sells the diorama is exactly four tricks: (1) parallax separation, (2) shadows that
anchor objects to the set, (3) aerial perspective (background cooler, softer, **no
outlines**; gameplay saturated **with outlines**), (4) art physically overlapping other art
(tufts over mats, mats over bodies, platforms over their own shadows). All four are cheap.

Layer stack, back to front (parallax = scroll factor relative to camera):

| # | Layer | Content | Parallax | Notes |
|---|---|---|---|---|
| 0 | Sky gradient | code gradient from JSON `sky_top`/`sky_bottom` | 0 | safety net; visible only past art edges / extreme zoom-out |
| 1 | Sky painting | `assets/bg/sky_grass_day.png` (SHIPPED — use as-is) | 0.05 | scale to cover view at max zoom-out + 10%; never letterbox |
| 2 | Far hills strip | `bg_hills_far.png` (new, transparent top) | 0.18 | tile horizontally; sits at arena floor horizon |
| 3 | Clouds | 2–3 individual cloud sprites | 0.30 | drift 6–14 px/s, wrap around bounds; different scales |
| 4 | Mid props | bushes, wooden fence pieces | 0.55 | placed by hand in level JSON later; v0: 3–5 scattered along the floor line |
| 5 | **Gameplay** | platforms, mats, decals, players, powerups | 1.0 | the only layer with dark outlines |
| 6 | FX | bounce rings, confetti, streaks | 1.0 | additive where glossy |

**Aerial perspective (code):** layers 2–4 get `modulate = (0.88, 0.94, 1.02)` and, if easy,
~15% desaturation — they recede toward the sky color. Layer 1 is already painted soft.
Never put a dark outline on anything behind layer 5.

**Shadows (code-drawn, this is the anchor trick):**
- Under every platform: rounded-rect soft shadow, color `#1E2B40` at **25% alpha**, offset
  `(0, +12)`, corner radius ≈ platform height/3, width = collider width − 8. Drawn behind
  the body on layer 5. No blur required if expensive — the rounded rect at 25% reads fine.
- Under every player when within ~120 px above a surface: soft ellipse contact shadow,
  same color, alpha scales 30%→0% with height. This single feature is the biggest "it's a
  physical toy set" win and helps players judge landings — do not skip it.

**Ambient life (v0-cheap):** the sky art already contains sparkle confetti; add 4–6 slowly
twinkling star/diamond particles on layer 3 using tier support colors at low alpha. Nothing
else — readable chaos beats busy prettiness (VISION pillar 5).

---

## 4. Asset shopping list — v0 grass arena

Every asset: single-subject, transparent PNG, generated in ChatGPT, then
`python tools/art.py trim <dl> <dest>` and `python tools/art.py check`. Log each in
`assets/CATALOG.md` with its prompt.

**Base style suffix — append to EVERY prompt below, verbatim** (from CATALOG.md):
> *"Style: high-quality glossy cartoon game art, thick clean dark-chocolate outlines,
> vibrant saturated colors, soft plastic-toy shine highlights. IMPORTANT: fully transparent
> background (alpha PNG) - no sky, no ground, no shadow, just the single subject centered
> with empty space around it."*

(Existing SHIPPED assets reused: `assets/bg/sky_grass_day.png` (layer 1),
`assets/world/trampoline_blue.png` kept as a standalone round-trampoline prop for later —
it is NOT the trampoline tier mat. `assets/world/grass/platform_wide.png` (914×335) is kept
as a whole-sprite hero body but its mid-span flowers make it unsliceable — it is superseded
for slicing by item 1.)

### Platform bodies

1. **`world/grass/body_std.png`** — gen 1536×1024, subject ≈ 1400×430. 3-slice 22/56/22.
   Used for H64 and H128 (same art, different uniform scale — acceptable for v0; if the
   dirt rocks look too big at H128, I'll order a dedicated chunky variant in v1).
   > "A long wide chunky grass platform for a cartoon platformer game, side view: bright
   > saturated green grass layer on top with a fluffy uneven fringe of grass blades
   > hanging over the edge, thick rounded brown dirt-and-rocks body below with smooth
   > rounded cartoon stones. The left and right ends are rounded caps with a few grass
   > blades sticking out sideways. IMPORTANT: the middle section of the platform must be
   > plain and evenly repeating — no flowers, no unique large rocks, no decorations in the
   > middle; keep all distinctive details near the two ends. Wide landscape composition."
   > + base style suffix.

### Tier mats (the 4-tier readability set — theme-agnostic, highest priority)

All four: gen 1536×1024 landscape, subject a long horizontal strip ≈ 1400×260 (crop/trim
takes the rest). 3-slice 18/64/18. Same camera phrase in all four so they sit identically:
*"long horizontal bouncy platform surface, straight-on side view, uniform height, flat top
you can stand on, wide landscape composition, middle section evenly repeating with no
unique details"*.

2. **`world/tiers/mat_marshmallow.png`**
   > "A long horizontal giant marshmallow cushion platform: soft warm-white matte
   > marshmallow (#FFF6EC) with puffy rounded quilted segments along its length, gentle
   > squishy bulges drooping slightly over the bottom edge, a light dusting of pale pink
   > (#FFC9DD) on the upper surfaces. Matte and soft, only very subtle shine." + camera
   > phrase + base style suffix.
3. **`world/tiers/mat_bubblegum.png`**
   > "A long horizontal glossy bubblegum platform: hot magenta-pink chewing gum (#FF4FA3)
   > with rounded melty blob shapes along its length, stretchy gum texture, wet glossy
   > highlight dots (#FF8AC5), one or two tiny gum drips under the bottom edge near the
   > ends only." + camera phrase + base style suffix.
4. **`world/tiers/mat_trampoline.png`**
   > "A long horizontal toy trampoline platform: royal blue (#2F6BD8) padded rim made of
   > repeating rounded glossy segments running along the whole top edge, golden yellow
   > (#FFD23F) taut canvas surface visible as a band below the rim with small stitched
   > X marks evenly spaced, glossy plastic toy shine on the blue pads." + camera phrase +
   > base style suffix.
5. **`world/tiers/mat_spring.png`**
   > "A long horizontal spring platform: a bright safety-orange (#FF6A2A) rounded glossy
   > bumper bar on top, held up by a row of shiny silver metal coil springs (#D9DEE7)
   > evenly spaced along its length, with visible gaps between the coils. Metallic shine
   > on the coils, plastic toy shine on the orange bar." + camera phrase + base style
   > suffix.

### Bumpers

6. **`world/bumper_post.png`** — gen 1024×1536 portrait, subject ≈ 380×1400 vertical post.
   Vertical 3-slice 22/56/22. Used for the 64×320 / 30×520 walls.
   > "A tall vertical soft foam bumper post for a cartoon game, side view: rounded light
   > grey (#98A1AF) rubbery foam cylinder with a column of big glossy white (#F4F6F9)
   > round stud bumps evenly spaced down its length, rounded cap at top and bottom.
   > IMPORTANT: the middle of the post must repeat evenly with no unique details. Tall
   > portrait composition." + base style suffix.
7. **`world/bumper_block.png`** — gen 1536×1024, same look rotated to a long horizontal
   grey stud block, horizontal 3-slice. (For future horizontal bumpers; order it in the
   same session as #6 by attaching #6 and asking for "the same exact bumper, same style,
   now as a long horizontal block".)

### Decals (kill the tiling repetition — generate individually, never as an atlas)

Each: gen 1024×1024, subject centered, trim hard. Drawn on layer 5 at 40–90 world px,
seeded scatter: ~1 tuft per 140 px of platform width (behind the mat, peeking above), 1
flower per ~400 px (cap ends only), max 2 flowers per platform.

8. **`world/grass/decal_tuft_a.png`** — "A single small tuft of bright green cartoon grass,
   three to five blades, slightly bent as if in a breeze." + base style suffix.
9. **`world/grass/decal_tuft_b.png`** — attach tuft_a: "the same style grass tuft, now a
   different shape with blades leaning the other way."
10. **`world/grass/decal_flower_white.png`** — "A single tiny cute white daisy flower with
    a yellow center and two small green leaves, cartoon game prop." + base style suffix.

### Background & mid props

11. **`bg/hills_far.png`** — gen 1536×1024, subject = rolling hills strip ≈ 1536×450 with
    transparent sky above. Layer 2, horizontal tile (soft unoutlined art tolerates a
    simple overlap-fade seam; if the seam shows, overlap 15% with alpha feather in code).
    > "A wide strip of soft rolling green hills for a cartoon game background, painterly
    > and soft with NO outlines, gentle pastel greens fading to a hazy blue-green in the
    > distance, a few simple soft round bushes. Softer and less saturated than foreground
    > game art. The area above the hills must be fully transparent. Wide landscape
    > composition, left and right edges low and simple." + transparency clause of base
    > suffix only (explicitly: "painterly soft style WITHOUT dark outlines").
12. **`bg/cloud_a.png`**, **`bg/cloud_b.png`** — gen 1024×1024 each. Layer 3 drifters.
    > "A single fluffy white cartoon cloud, soft rounded cauliflower shapes, very subtle
    > pale blue shading underneath, NO outline, soft painterly style." + transparency
    > clause. (cloud_b: attach cloud_a, "same style, different wider shape".)
13. **`bg/bush_round.png`** — gen 1024×1024. Layer 4 mid prop, modulated per §3.
    > "A single round chunky cartoon bush, two stacked lobes of saturated green with soft
    > plastic-toy shine, sitting prop for a game." + base style suffix.
14. **`bg/fence_wood.png`** — gen 1024×1024, subject ≈ 900×450, whole-sprite (no slicing;
    place 2–3 as-is). "A short segment of cute chunky wooden toy fence, three rounded
    posts with two rounded horizontal rails, warm saturated wood brown." + base style
    suffix.

**Total new generations: 14 sprites** (7 world, 3 decals, 4 background). Everything is a
single centered subject — zero tilesets, zero atlases, zero seams requested from the model.

### Intake acceptance per asset (before it enters the game)

- Real alpha (`art.py check`), trimmed, no baked shadow, no baked background.
- Sliceable assets: eyeball the middle 56% — if any unique detail sits there, regenerate
  ("keep the middle plain and repeating" reminder), don't hand-patch.
- Mats: hold all four thumbnails at 64 px wide next to each other — if any two are
  confusable at that size, regenerate the offender before code touches it.

---

## 5. Constraints & grading checklist (what I will Ship/Fix/Reject against)

1. **Far-zoom readability:** screenshot at max zoom-out — every tier nameable by a person
   who has seen the mat legend once; 4 players findable in <1 s (chocolate outlines +
   contact shadows + white eyes carry this).
2. **Close-zoom polish:** screenshot at ~1-platform zoom — no visible center-slice seams,
   no stretched caps, no vertical squash on bodies, tiling not detectable within 3 tiles
   (decals doing their job).
3. **No debug shapes anywhere.** Any Polygon2D flat fill visible = automatic Fix.
4. **Diorama test:** platforms cast shadows, background has zero outlines and is cooler/
   softer than gameplay, parallax visible when the camera pans. If a static screenshot
   could pass as one flat image, it's a Fix.
5. **Color discipline:** no magenta/safety-orange/blue+yellow-pair anywhere except mats
   and powerup FX; bumpers are the only grey.
6. **Everything on this list is a single generated sprite** — if implementation "needs" a
   tileset, the implementation is wrong, come back to me instead.

After implementation: capture `python tools/gbplay.py screenshot` at far zoom, close zoom,
and mid-bounce (for the mat pulse), and send all three for grading.
