# Art Brief — Painted Backdrops v1 ("one big painting, no cutoffs")

> Author: Art Director. Status: APPROVED FOR BUILD. Scope: ONE build session.
> Owner direction (2026-07-18, verbatim intent): *"why does the background go like purple then
> like a hard cutoff into green and there is some weird red dotted line... why not use big
> zoomed-out chatgpt generated painted backgrounds or something?"* + *"this is a no svg 100%
> ai generated graphics project."*
> Extends `docs/briefs/arena_rendering.md` (still the law for platforms/mats/diorama) and
> supersedes the code-gradient sky/void treatment on non-meadow levels.

## What the owner is seeing (diagnosis)

Two different systems are butting heads at the horizon line:

1. **The purple→green hard cutoff.** On `open_sky` levels the sky is the Layer-0 code
   gradient (`sky_top`/`sky_bottom`, e.g. bumper_gauntlet's `#2A1E4E → #5B3A8C` purple).
   The lethal void below the platform line is painted by `paint_void()` with a HARDCODED
   4-stop cool gradient whose mouth is sage green `#2B5140`. Purple sky meets green abyss
   at a razor edge = looks like a bug. It reads fine on grass (green-on-green); it clashes
   on every themed palette.
2. **The "weird red dotted line"** is the DELIBERATE kill-zone telegraph (matte red rim
   `#E6402C` + small hazard chevrons every 90 px, `pit_void_rendering.md`). The FUNCTION is
   sacred — "below this line = death" must survive — but the current execution (6 px hard
   polygon strip + confetti of 16 px triangles) reads as debug art over any painted scene.

Fix direction, per the owner: **one big zoomed-out AI-painted background per theme where the
sky and the below-horizon abyss are a single composition** — no seam is possible because
there is no second system. Then restyle the kill telegraph so it looks intentional on top
of a painting.

---

## 1. Inventory — who uses what today

How the code consumes backdrops (`src/systems/ArenaRenderer.gd`):

| JSON `backdrop` | Path today | Sky source | Void fill |
|---|---|---|---|
| absent / `"meadow"` | meadow parallax stack | `assets/bg/sky_grass_day.png` painting (Layer 1) + hills + clouds + props | hardcoded sage→navy 4-stop |
| `"open_sky"` | gradient-only sky | Layer-0 `sky_top`/`sky_bottom` code gradient + optional `horizon_glow`/`stars`/`clouds` | hardcoded sage→navy 4-stop ← **the clash** |
| `"enclosed"` | sealed-drum interior | code-drawn shell/sheen/vignette clipped to play rect | n/a (no voids) |

Level census (all `levels/*.json` + `levels/courses/*.json`, checked 2026-07-18):

| Palette family | Levels | Count |
|---|---|---|
| **Grass day** (blue sky `#2e6cb0`-ish, meadow or bright open_sky) | dev_arena, islands_void, grassy_expanse, the_cliff, the_spine, atoll + ~20 blue/green-sky courses (tut_*, t_*, s3_*, n2_*, course_01–03/05) | ~26 |
| **Space night** (indigo `#0b1030`, stars on) | singularity, twin_moons, spires, g6_binary_run, g6_moonwalk, g6_slingshot; near-family: bumper_gauntlet + p4_swing_shot (purple twilight) | 8 |
| **Foundry ember** (dark warm `#1C1510→#963C12`, horizon_glow) | foundry_press_row, foundry_crucible, foundry_smelter, foundry_meltdown, meltdown_box; near-family: p4_chain_reaction | 6 |
| **Dusk gold** (blue→amber, horizon_glow) | the_ascent, convoy, twin_chasms | 3 |
| **Overcast quarry** (grey-beige `#6E6A63`) | hammer_arena, wrecking_yard, hazard_yard, minefield, gauntlet_* (×4), course_04, t_hammer_vigil, t_twin_hammers | 11 |
| **Enclosed interiors** (courts, drop_chamber, sports/*) | 10 levels — code interior, NO painting needed, out of scope | 10 |

### Decision: 4 new paintings + 1 kept = 5 covers everything

| Painting id | File | Covers | Tint variants (`painting_tint` modulate) |
|---|---|---|---|
| `meadow_day` | `assets/bg/sky_grass_day.png` — **SHIPPED, keep as-is** | all grass-day levels | atoll/the_spine get a light teal tint `#D8F2EC`-ish; graded case-by-case |
| `space_nebula` | `assets/bg/painting_space_nebula.png` — NEW | singularity, twin_moons, spires, g6_* | bumper_gauntlet + p4_swing_shot: warm violet tint `#D9C4E8` |
| `ember_foundry` | `assets/bg/painting_ember_foundry.png` — NEW | foundry_* ×4, meltdown_box, p4_chain_reaction | none v1 |
| `dusk_gold` | `assets/bg/painting_dusk_gold.png` — NEW | the_ascent, convoy, twin_chasms | none v1 |
| `overcast_quarry` | `assets/bg/painting_overcast_quarry.png` — NEW | all hammer/gauntlet/mine grey levels | none v1 |

Meadow keeps its current chasm treatment too (sage dirt pit on grass was designed together
and reads correctly — green-on-green). The 4 NEW paintings are full sky+abyss compositions;
their levels drop the code gradient abyss entirely (§4).

---

## 2. The painting spec (per theme)

**Universal rules — every painting:**

- **One composition, sky AND abyss.** Horizon line baked into the painting at **~58% from
  the top** (state it in the prompt; the integration pins that line to the arena floor_y).
  Above: the theme's sky. Below: the same scene falling away into a dark depth — the bottom
  15% of the image must approach a near-black of the theme's own hue (so `_extend_below`
  can extend it seamlessly to any depth).
- **Outline-FREE, softer and less saturated than gameplay art.** Outline = "you can touch
  this" is the depth doctrine; a single outline anywhere in a painting is an auto-Reject.
- **Reserved colors — hard bans:** no bubblegum magenta `#FF4FA3` family, no safety orange
  `#FF6A2A` (ember painting: deep crimson/amber only, duller and darker than the spring
  bar), no royal-blue `#2F6BD8` + golden-yellow `#FFD23F` pairing, and **no saturated red
  band near the horizon** — hazard red `#E6402C` is owned by the kill line (§3).
- **Full-bleed OPAQUE image** — this is the one asset class with NO alpha (do not run
  `art.py check`'s transparency expectation against it; `trim` is a no-op, use `info`).
  Generate landscape (ChatGPT native ≈1536×1024 is fine; code scales to cover
  `MAX_VIEW` 4800×2700 at parallax 0.05, same as the shipped sky).
- **Quiet by design:** no characters, no platforms, no text, no lens flares, nothing with
  a readable silhouette that could be mistaken for gameplay. Detail density LOW — at
  parallax 0.05 the painting barely moves; busy paintings fight pillar 5 (readable chaos).
- **Tile/parallax strategy: single painting, stretched-to-cover, parallax 0.05.** No
  layering, no horizontal tiling for v1 (the existing Layer-3 code clouds/stars/twinkles
  already provide motion on top). If a painting's edges show at extreme zoom-out, the
  Layer-0 gradient remains behind it as the safety net — sky_top/sky_bottom for each level
  should be RETUNED to sample the painting's own top/bottom colors so the net is invisible.

**Prompt pattern** (the pipeline's background exception — painterly clause, no outline
clause, no transparency clause). Append to every prompt below, verbatim:

> *"Soft dreamy painterly style with NO outlines anywhere, muted and less saturated than
> foreground cartoon game art, low detail density, no characters, no text, no borders.
> Full-bleed wide landscape composition filling the entire image."*

### 2a. `painting_space_nebula.png`

Palette: deep indigo `#0B1030`–`#28285A`, violet-blue nebula `#3A3E7A`, star glow warm
white `#F5EFDD` (tiny, sparse), abyss bottom `#05081A`.

> "A vast zoomed-out painted deep-space backdrop for a cartoon game: the upper two thirds
> are a deep indigo night sky with soft violet-blue nebula clouds, sparse tiny glowing
> stars, and one or two small distant pale moons high up. At about 58% from the top there
> is a soft implied horizon; below it the scene falls away into a bottomless starless
> indigo abyss that gets steadily darker until it is almost black at the bottom edge, with
> only the faintest cool haze. No magenta, no orange." + pattern suffix.

### 2b. `painting_ember_foundry.png`

Palette: charcoal `#1C1510`, deep maroon `#4A1E10`, ember amber `#B0561E` (dull — must sit
clearly below spring-orange `#FF6A2A` in saturation), abyss bottom `#120A06`.

> "A vast zoomed-out painted industrial foundry backdrop for a cartoon game: the upper two
> thirds are a dark smoky cavern sky with hazy silhouettes of distant chimneys, pipes and
> gantry cranes in charcoal browns, lit from below by a warm deep-amber furnace glow that
> is strongest just above an implied horizon line at about 58% from the top. Below the
> horizon the scene falls away into a deep charcoal-maroon abyss with a few faint drifting
> ember specks, getting almost black at the bottom edge. Warm colors stay deep and muted —
> no bright orange, no red stripes." + pattern suffix.

### 2c. `painting_dusk_gold.png`

Palette: dusk blue `#243056`, warm amber `#D98A4A`, soft violet clouds `#6E5A8C`, abyss
bottom `#160F14`.

> "A vast zoomed-out painted golden-hour backdrop for a cartoon game: the upper two thirds
> are a dusk sky grading from deep blue at the top through soft violet clouds to a warm
> golden-amber glow sitting low, just above an implied horizon line at about 58% from the
> top. Below the horizon the scene falls away into a hazy warm-brown canyon depth that
> fades to a near-black plum at the bottom edge. No magenta, nothing neon." + pattern
> suffix.

### 2d. `painting_overcast_quarry.png`

Palette: grey-beige `#6E6A63`–`#B8AE9E`, cool stone `#7C7468`, abyss bottom `#14120F`.

> "A vast zoomed-out painted overcast quarry backdrop for a cartoon game: the upper two
> thirds are a soft grey-beige cloudy sky over faint hazy silhouettes of rocky quarry
> terraces and a distant crane, everything desaturated and calm. Implied horizon line at
> about 58% from the top; below it the scene falls away into a cool grey-brown pit depth
> fading to near-black at the bottom edge, with faint dust haze. No warm bright colors."
> + pattern suffix.

**Intake acceptance per painting (before code touches it):** bottom 15% approaches a solid
near-black of its own hue; horizon within 52–64% of height; zero outlines; reserved-color
scan by eye; side edges must be boring (soft gradient-ish) so stretched-to-cover crops are
safe.

---

## 3. Kill-line restyle — the telegraph survives, gorgeously

Function is non-negotiable: **a first-time player must read "below this line = death" in
under one second at gameplay zoom.** Hazard red `#E6402C` stays reserved exclusively for
this. What changes is the execution — from "debug strip + dotted triangles" to a single
integrated danger treatment sitting on the painting's horizon:

1. **Core line:** keep a thin matte rim, but drop it from 6 px to **3 px** at 85% alpha —
   a taut wire, not a plank. Still tucked under the grass/body fringe, z +1.
2. **Danger glow band (NEW — this is the main read):** below the core line, a soft
   vertical gradient band, `#E6402C` → transparent over **~36 world px**, additive blend,
   **slow-pulsing alpha 0.25 → 0.55, ~1.6 s sine loop.** The pulse is what makes it read
   as an ACTIVE hazard over any painting (and it is the only slow-pulsing thing in the
   scene, so motion still means something). Build with the existing `_gradient_sprite`
   toolkit — zero assets.
3. **Chevrons — fewer, larger, still matte:** spacing 90 px → **~260 px**; size 16×11 →
   **~44 wide × 26 tall** world px; keep the dark-red `#7A1E14` outline triangle behind
   (never chocolate — this is the inverse-of-touchable color language); alpha 0.9, matte
   (NEVER additive — they must stay solid-readable over the bright glow). No idle
   animation on the chevrons themselves.
4. **Integration with the painting's horizon:** the void's dirt walls + under-lip AO stay
   (they are anchored to gameplay geometry and carry the "it goes DOWN" volume); the glow
   band draws over the abyss, under the platform art, so the lip reads as one object:
   painted depth → glowing danger seam → chunky outlined platform.

Far-zoom math (party arena ≈3900 world px → ~0.49 px/world at 1920): glow band 36 px →
~18 screen px, chevrons ~22×13 screen px — both comfortably above the 10 px floor. The old
16 px chevrons were ~8 screen px, i.e. literally "a weird red dotted line." The owner was
grading accurately.

---

## 4. Integration notes for the programmer (design intent, not code)

**Per-level JSON knob:** `"backdrop_painting": "space_nebula"` (also accepts `meadow_day`,
`ember_foundry`, `dusk_gold`, `overcast_quarry`). Optional `"painting_tint": "#hex"`
(modulate, default white). Applies on the `open_sky` path (meadow path already has its
painting; enclosed path untouched).

**Small painting manifest** (const Dictionary in ArenaRenderer or a tiny JSON): per
painting id → texture path, `horizon_frac` (default 0.58), and the void recolor hexes:
`abyss_mouth` + `abyss_deep` (replacing the hardcoded sage `#2B5140` → navy `#060E18`
stops) and a wall triple (top/deep/strata) so the dirt walls can shift from grass-browns
to dark iron (foundry/quarry) or indigo rock (space).

**Replaced vs kept:**

| Code path | Verdict |
|---|---|
| Layer-0 sky_top/sky_bottom gradient | KEEP — safety net + fallback; retune per-level hexes to sample the painting |
| `_build_open_sky` | EXTEND — when `backdrop_painting` is set, load the painting, scale-to-cover (same math as the shipped Layer-1 sky), pin image `horizon_frac` line to the arena floor_y, parallax 0.05, run `_extend_below` on it |
| `horizon_glow` band | OFF on painted levels (the glow is baked in); code path stays for unpainted levels |
| Clouds / twinkles / stars (Layer 3) | KEEP — they are the motion on top of the painting |
| Meadow stack (sky/hills/props/decals) | KEEP untouched |
| Enclosed interior | KEEP untouched — out of scope |
| `paint_void` 4-stop fill + `_void_gap_fill` + bridge `mouth` color | RECOLOR from manifest (`abyss_mouth`/`abyss_deep`) — the fill stays (it doubles as the contrast scrim guaranteeing player silhouettes read below the rim) but it now BELONGS to the painting's hue instead of clashing with it |
| `_void_wall` dirt hexes | parameterize from manifest wall triple |
| Rim + chevrons (`paint_void` 3e, `_void_chevron`) | RESTYLE per §3 |
| `src/ui/Backdrop.gd` (title screen) | untouched — uses `assets/ui/title_bg.png`, separate concern |

**Fallback:** painting file missing → `_warn_once` + exactly today's gradient behavior
(the existing graceful-skip pattern). A missing painting must never produce a black or
flat screen.

**Session scope check:** 4 generations + intake, ~1 manifest + 1 branch in
`_build_open_sky`, void recolor plumbing, kill-line restyle, sky-hex retune on ~28 level
JSONs (mechanical), screenshots. One focused session. No new tools, no shaders.

---

## 5. Grading plan (what I will Ship/Fix/Reject against)

Capture per painted theme — one representative level each (suggest: twin_moons,
foundry_smelter, the_ascent, hammer_arena, plus grassy_expanse as the meadow control):

- **Far zoom** (max zoom-out, 4 players spawned): `python tools/gbplay.py screenshot`
- **Close zoom** (~1-platform): same
- **Kill-line beauty shot:** camera framing a void lip, TWO captures ~0.8 s apart (to
  verify the glow pulse actually pulses)
- **Falling shot:** a player mid-fall below the rim (silhouette-contrast check)

Checklist:

1. **No seam anywhere.** Pan the camera top to bottom of the arena — if any horizontal
   line exists where two systems meet (painting edge, gradient net, abyss fill), it's a
   Fix. The purple→green cutoff class of bug must be structurally impossible.
2. **Readability at gameplay zoom:** 4 players findable in <1 s on every painting
   (chocolate outlines + contact shadows carry this — if a painting is too bright or busy
   behind the action, the painting gets darkened/simplified, never the players).
3. **Kill-line function:** cold-read test — does the lip say "death" in <1 s at far zoom?
   Glow band visible ≥10 screen px, pulse perceptible, chevrons solid over the glow.
4. **Aerial doctrine:** painting has zero outlines, is measurably softer/less saturated
   than the platforms in the same frame.
5. **Color discipline:** no reserved colors in any painting; ember foundry clearly duller
   than the spring-orange mat sharing the frame; no red near the horizon except the
   telegraph itself.
6. **Fallback exercised once:** rename one painting, launch, confirm warn + today's look.

**Auto-Reject:** any outline in a painting; hazard-red or reserved colors in a painting;
a visible hard horizontal cutoff at any zoom; kill line that fails the 1-second cold
read; a painting so detailed it produces false gameplay silhouettes; letterboxing or
visible painting edge at max zoom-out.
