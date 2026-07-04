# BRIEF — Enclosed Interior Backdrop ("sealed drum" read)

**Art Director** · 2026-07-04 · Glossy Toybox bar · Scope-fenced: BACKDROP / READ ONLY.
Trigger: drop_chamber's gameplay enclosure shipped and reads correctly (grey bumper walls + ceiling
lid, two grass shelves, dark centre hole with hazard rim/chevrons), but the BACKDROP renders the
sunny grass meadow (blue sky, clouds, twinkles, hills, bushes, wooden fences) ABOVE the lid and
OUTSIDE the walls. Result: an open-topped box sitting in a field, not a sealed contained pinball drum.

## 0. Verdict on the current interior read: **FIX**

"Box in a meadow" is below the Steam-quality bar for the owner's flagship-variety seed. Evidence:
- `tools/out/dc_full.png` (zoom-out): bright blue sky + clouds + confetti twinkles sit ABOVE the grey
  bumper lid; wooden fences and round bushes sit ON TOP of the lid; bright meadow-green + far hills
  fill the whole area OUTSIDE both bumper walls. The lid/walls read as the rim of an open crate in a
  park. The single most identity-defining beat of this seed — "you are SEALED inside a drum, the only
  way out is DOWN through the hole into the abyss" — is actively contradicted by the backdrop.
- `tools/out/dc_01.png` (combat zoom): the backfield behind the play area is flat pale meadow-green.
  Beyond killing the "contained" read, that pale warm green is a CONTRAST problem: the lime/green
  player blob (P2) sits closest to backdrop hue, and the whole field reads washed-out rather than the
  saturated pop the shelves/players deserve. A dim cool interior would raise contrast on all four
  players and the grass shelves.

The enclosure geometry is good; do NOT touch it. This is purely the surround/backfield treatment.

## 1. Target read — "glossy contained drum interior"

You are inside a dark, glossy, sealed shell. The grey bumper walls + lid are the drum's INNER
surface; beyond them is the drum's dark housing (not a sky, not a field). The interior backfield is a
dim, cool, faintly-glossy shell — grass-adjacent in hue (this IS the grass theme) but clearly INDOORS
and in shadow, so the bright grass shelves, orange dirt, hazard-red rim, and the four saturated player
blobs POP. The only bright/deep "opening" is the centre hole, whose existing cool teal->navy void
gradient should feel CONTINUOUS with the interior (same cool family): the drum is dim, the hole is the
abyss at the bottom of it.

Coherence anchor: the void mouth is already `#2B5140` (sage) ramping to `#060E18` (near-black navy).
The enclosed backdrop lives in that SAME cool family so the whole drum reads as one contained space.

## 2. Two zones

### Zone A — SURROUND (everything ABOVE the lid and OUTSIDE the walls): dark enclosed housing
Suppress the meadow parallax entirely (see §4) and replace it with a deep cool vertical gradient — the
drum's outer housing seen past the shell:
- top `#101F2A`, bottom `#0A1720` (deep cool slate-teal, near the void's deep stops).
- This is what shows above the lid and beyond both walls at zoom-out. It makes the grey bumpers read
  as a lit shell against dark housing (strong silhouette/contrast) instead of a crate rim in a park.

### Zone B — INTERIOR BACKFIELD (behind the play area, inside the drum): dim glossy shell
A dim mossy-teal vertical gradient, a touch lighter than the surround so the inside of the drum reads
as a faintly-lit curved shell while beyond-the-walls stays darker:
- top `#2C4A44`, mid `#21403C`, bottom `#18332F` (grass-adjacent but dim/cool — NOT sunny green).
- **Gloss sheen** (Glossy Toybox curved-plastic tell): a soft radial highlight near the upper-centre
  of the interior — white `#FFFFFF` at ~0.10 alpha at centre fading to 0 at the edge, as a wide ellipse
  (~70% interior width, ~45% interior height). Sells a curved, glossy shell rather than a flat wall.
- **Vignette** (sells the cylinder curvature + focuses the centre): a radial darkening from
  transparent at centre to `#0A1720` at ~0.45 alpha in the corners, covering the interior.
- **Optional polish — inner-rim AO:** a thin soft dark band (`#0A1720`, ~0.4 alpha, ~24px, fading
  inward) hugging the INSIDE of each bumper wall and the UNDERSIDE of the lid, so the shell edges catch
  shadow and the enclosure reads as having depth. Nice-to-have, not required for a Ship.

Net values, brightest→darkest: grass shelf tops (bright yellow-green) > player blobs / hazard rim >
interior shell (dim mossy-teal) > surround housing (deep slate) > void bottom (near-black). Clean
value stack, everything reads.

## 3. Achievable with level params ALONE? **NO — needs a small RENDERER FEATURE.**

The renderer builds the meadow stack UNCONDITIONALLY in `ArenaRenderer._build_background()` whenever
the assets exist: Layer 1 sky painting (`SKY_TEX`, z −95), Layer 2 far hills (`HILLS_TEX`, z −90),
Layer 3 clouds + twinkles (z −85), Layer 4 mid props / fences (z −80). The only level-driven backdrop
knobs are `sky_top`/`sky_bottom`, and those feed ONLY the Layer-0 code gradient (z −100) — which the
meadow paints completely over. drop_chamber already set `sky_top:#243a63` / `sky_bottom:#7fa6d8` and it
makes no difference, precisely because Layer 1 covers it. There is NO existing field that suppresses
the parallax or fills a contained interior. So this cannot be done from JSON alone.

## 4. Renderer feature spec (for the gameplay-programmer)

Add a **reusable "enclosed" backdrop mode** to `ArenaRenderer` — NOT drop_chamber-specific. Any future
enclosed level (capsule / vault / box) inherits it. Keep it a data flag so backdrop and kill-shape stay
orthogonal (a future enclosed arena might not use a hole; an open arena might want a custom sky).

**New level field:** `"backdrop": "enclosed"` (string). Absent / `"meadow"` / `"parallax"` = current
behavior (unchanged, back-compat). Read it in `setup()` / `_build_background()`.

When `backdrop == "enclosed"`:
1. **Suppress the meadow parallax:** skip Layer 1 (sky painting), Layer 2 (far hills), Layer 4 (mid
   props/fences), and the CLOUD drifters in Layer 3. (Twinkles: skip them, or keep a few at reduced
   alpha recolored cool as faint interior dust — your call; default skip for cleanliness.)
2. **Surround (Zone A):** keep the existing Layer-0 gradient (`grad_rect = brect.grow(pad)`, z −100)
   and drive it from `sky_top`/`sky_bottom` as today — it already covers above-lid + outside-walls +
   behind-everything. With the meadow layers gone, it becomes the dark housing. (Level JSON change in
   §5 supplies the dark hexes.)
3. **Interior backfield (Zone B):** add ONE new element — a vertical gradient rect covering the play
   AABB, at a z BETWEEN the surround and the platform art (e.g. **z = −92**), using the Zone-B stops
   from §2. Use `play_rect` (the merged platform AABB you already compute in `setup()`); optionally
   grow it a few px so it meets the inner wall faces. Because it's clipped to `play_rect`, everything
   ABOVE the lid (y < lid top) and OUTSIDE the walls stays Zone-A surround — that's the two-zone read
   for free, no per-level geometry knowledge, works for any axis-aligned enclosed box.
   - Add the **gloss sheen** (radial `GradientTexture2D`, FILL_RADIAL, white α0.10→0, wide ellipse,
     upper-centre of `play_rect`) at z −91.
   - Add the **vignette** (radial `GradientTexture2D`, transparent centre → `#0A1720` α0.45 corners,
     over `play_rect`) at z −91 (just above the shell gradient, below platform art at z ≥ 0).
   - Optional inner-rim AO strips as in §2.
4. **Leave the void untouched:** `paint_void()` (z −8..+1) already draws on top of the interior
   backfield; the hole + walls + chevrons + motes still read, and the void's cool ramp now sits
   continuous with the dim interior. No change to `paint_void`.

Everything is code-drawn gradients/polygons (same toolkit as `paint_void`), so it adapts to any
enclosed level's size and needs no new art assets.

**Reusability note:** ship it as the generic `backdrop == "enclosed"` treatment. A future refinement
could tint Zone B from the level `theme` (mossy-teal for grass, cool-grey for a metal drum, etc.); not
required now — the cool mossy default reads correctly for the grass seed.

## 5. Level-param change (pairs with the feature, in `levels/drop_chamber.json`)

- Add `"backdrop": "enclosed"`.
- Repoint the surround gradient to the dark housing values (currently tuned for a meadow horizon):
  `"sky_top": "#101F2A"`, `"sky_bottom": "#0A1720"`.
- No geometry, collider, bounds, tier, void, spawn, or feel change. Backdrop/read only.

## 6. Fence

BACKDROP / READ ONLY. Do NOT touch: gameplay geometry, colliders, bounds, lethality, kill_shape, void
rect/collider, tuning/feel constants, platform tiers, or the enclosure bounce behavior. If any of those
would move to achieve the look, STOP and re-brief.

## 7. Grade-back (after build)

Re-grade FROM IN-GAME SCREENSHOTS at both zooms:
- Zoom-out: nothing meadow above the lid or outside the walls; drum reads as a sealed shell in dark
  housing; no seams where interior meets surround; no meadow assets leaking at the corners.
- Combat zoom: dim cool glossy interior (not pale meadow-green); all four players + grass shelves +
  hazard rim POP; the hole/void reads continuous with the interior (one cool space).
- No debug fills, no stretched gradients, no visible rect edges of the interval backfield.
</content>
</invoke>
