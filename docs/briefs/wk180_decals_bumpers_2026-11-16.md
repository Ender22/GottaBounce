# WK-180 Art brief: grass decals, horizontal bumpers, CIRCUIT UNLOCKED banner (2026-11-16)

Owner: Art Director. Style bible: `docs/VISION.md` ("Glossy Toybox"), tier table in
`docs/briefs/arena_rendering.md` §2 (the bumper is "the only grey interactive object: a rounded post with big glossy studs").
Evidence I graded from: `tools/out/wk/CD4-01_grounded_grassy_expanse.png`,
`tools/out/wk/WK-116_longhaul_base.png`, `tools/out/wk/WK-113_02_rb_bowl_combat_2s.png`,
`tools/out/cd_audit/d53_dropshot/f000_COMBAT.png`, `tools/out/wk/WK-179_02_circuit_unlock_banner.png`, plus the source PNGs.

| # | Item | Verdict |
|---|------|---------|
| 1 | Grass decals | **Fix**: wire them in, but NOT with the current placement code. Nothing may sit above the landing line. |
| 2 | Horizontal bumpers (+ a seam bug on all posts) | **Fix**: needs real art. Long rails reuse the post by transposing it (no generation). Square blocks need one new generated sprite. |
| 3 | CIRCUIT UNLOCKED banner | **Fix**: move it into the header band as a gold ToyRibbon, one line only. |

---

## 1. Grass decals

### What the screenshots show
- The wrong paths (`decal_*.png` instead of `decals/*.png`) mean no grass platform has drawn a decal since July. What ships is a clean,
  plain edge (trampoline mat, then the lime fringe, then orange rock).
- That edge is clean, but on long platforms it looks like wallpaper. The rock band repeats one cluster about every 230 px,
  and the 1000 px main platform in grassy_expanse and the 2800 px Long Haul floor show the repeat across the whole screen.
  Only the rare `platform_wide.png` hero sprite (used within ±20% of its aspect) has the baked-in daisies that break it up.
  So the plain edge is acceptable but not good enough to Ship as-is.
- **The placement code as written would be worse than the plain edge.** `_scatter_back_tufts` puts 48-78 px tufts behind
  the mat with their tips 38-61 px ABOVE the mat. That is most of a goat's height of green spikes sticking up through the
  landing line, the one line the tier-colour readability contract protects. `_scatter_end_decals` centres corner tufts on
  the mat top (half above it) and puts 36-50 px daisies above the corners. Those blur exactly where edge-guarding happens.
  The 36-50 px daisy is also about 3x the size of the baked daisies (~12-15 px heads), so it would look like a sticker.
- Asset problems:
  - The tufts are darker and cooler than the fringe (dominant #305010 / #105010 against the fringe's #99C800 / #D0F010),
    so they read as a different weed.
  - All three decals import with `mipmaps/generate=false` and would be shrunk 10-14x, which makes them shimmer as the
    camera moves.

### Rules (apply all of them)

**R0. Hard rule: no decal pixel above `mat_top + 8` on any platform.** The mat's top edge is the landing line and must stay
an unbroken tier-coloured line.

**R1. Asset prep (once, offline, with `tools/art.py` or a small PIL pass; keep the originals untouched):**
- `assets/world/grass/decals/tuft_a_fit.png` and `tuft_b_fit.png`:
  - Recolour in HSV: hue -10° (toward yellow), value x1.25 on pixels with V > 0.25 so the dark outline is kept.
  - Target mid-tone about #90D010 and highlight about #D8F020, so the tuft sits on the fringe's own ramp.
  - Then `art.py resize` to 69 px wide (80 px tall).
- `assets/world/grass/decals/flower_white_fit.png`: no recolour (white #F4F6F9 petals, yellow centre, chocolate outline
  already match the baked daisies). `art.py resize` to 37 px wide (44 px tall).
- Why: each is about 2x its largest display size, so bilinear filtering is clean without mipmaps.
- Point `TUFT_TEXES` / `FLOWER_TEX` in `ArenaRenderer.gd` at the `_fit` files. Log them in `assets/CATALOG.md`.

**R2. Where decals are allowed:**
- Grass bodies only (`_body_grass_decals`). This is already true.
- NOT on mat-only slabs (`h <= SLAB_MAX_H`). Today `_scatter_end_decals` also runs on slabs. Gate it inside the
  `h > SLAB_MAX_H` branch.
- Flowers NOT when the hero whole-sprite (`platform_wide.png`) was used, because it already has daisies.
  `_platform_body` needs to report which art it used. Tufts are fine on both.

**R3. Delete the mid-span back tufts.** Remove the `_scatter_back_tufts` call. Tufts appear only at the ends (R5).

**R4. Fringe daisies (these do the actual repeat-breaking).**
- Define `fringe_bottom = top - BODY_BLEED_TOP + 0.60 * art_h`, where `art_h` is the grass strip height actually drawn
  (`canon + BODY_BLEED_TOP`). 0.60 is where the grass blades end in `body_std.png`, measured from the alpha/colour rows.
  For h≈64 this is `top + 33.6`; for h≈128 it is `top + 72`.
- Only on platforms with `w >= 400`. Count = `clampi(floori(w / 320), 1, 8)`.
- Space them with stratified jitter across `[-w/2 + 70, w/2 - 70]`: `cell = span / count`,
  `x = cell_left + cell * (0.5 + rng.randf_range(-0.35, 0.35))`. Never metronome spacing.
- Height `rng.randf_range(18, 22)` world px (scale = height / tex height). Stem base (sprite bottom) at `fringe_bottom + 3`.
- 35% chance of a buddy daisy at `x ± randf_range(14, 20)` at 0.8x the height. Small clusters look natural, singles look placed.
- Clamp the daisy top to `>= mat_top + MAT_H - 4` (at most 4 px tucked under the mat). Shrink it to fit. If it would
  end up under 14 px, skip it.
- Add as children of `art` AFTER the body art and BEFORE the mat `pivot`, so any overlap tucks behind the mat.
- Skip any daisy within 60 px of a suppressed (void-lip) end. The existing §6.3 rule still applies.

**R5. End tufts (soften the hard rectangle corners).**
- One per end, only when that end is not suppressed and `w >= 160`.
- Left end uses `tuft_b_fit` and right end uses `tuft_a_fit`, so the tall blade leans OUTWARD. Do not flip textures.
  All art is lit top-left.
- Height `rng.randf_range(34, 40)`. Stem base at `fringe_bottom + 6`.
- x = `side * (w/2 + BODY_BLEED_SIDE - 8)`, so the tuft straddles the body's side outline and its blades fan about
  10 px past the silhouette, below the mat.
- Clamp the tuft top to `>= mat_top + 8` (R0). Shrink to fit.
- Same child order as R4: before the mat `pivot`.

**R6. Colour and value check (grade gate).**
- At a squint, the daisies must read as small white dots in the fringe, no bigger than the baked daisies in
  `WK-113_02_rb_bowl_combat_2s.png`.
- The tufts must be no darker than the fringe's shade band (#2E7800).
- If the tufts read as dark blobs at 4-player zoom, remove the tufts and keep only the daisies. Do not ship noise.

### Screenshots I need to grade it (rendered, 1920x1080, 4 goats in frame)
grassy_expanse (long single platform), long_haul (2800 px floor), the_bowl (stepped grass floor),
three_meadows or two_hills (void lips: confirm the corners stay bare), and one slab-heavy level (confirm slabs stay bare).
Also send one 2x crop of a platform end and one of mid-span.

---

## 2. Horizontal bumpers

### Where they appear (w > h, skin != net)
- **Every sports court ceiling**, a 2100-2800 x 80 rail at the very top of the frame:
  sports_court, the_bowl, long_haul, the_box (1600x70), dropshot_beach/reef/dome, hammer_yard, minefield, the_crusher,
  the_scrapheap. It is on screen 100% of every sports match.
- **Hanging blocks** 140-150 x 120 (the_bowl, sports_court, long_haul) and 120x110 (long_haul).
- **Trials courses**, mid-air: s3_pinball_alley 1020x100, s3_keyhole 660x80, p4_chain_reaction 660x80, s3_wall_pass 350x80.
- drop_chamber / scrap_crusher_drum: a 2240x100 ceiling at y=-300.

### Verdict: it is an eyesore
- The ceiling renders as a grey quilted-marshmallow pillow with brown under-drips and little leaf-curl tips. It joins at
  both corners onto chrome posts with pearl studs: two different materials for the same object type in the same frame,
  in every sports match.
- The 140x120 blocks are the worst: the squashed mat strip turns into a **grey garlic bulb / flour sack with a stalk on
  top** (see WK-116_longhaul_base.png, the bowl shots). Nobody reads that as "bounces you".
- Bumpers are a readability tier ("only grey interactive object, studded"). A different shape breaks that rule.

### Bug found on every vertical post (fix in the same pass)
`bumper_post.png` cap_frac 0.22 cuts the pearl column mid-pearl (source pearl period ≈ 120 px; tile = rows 221-782,
which is 4.67 periods). Every tile seam shows a **half-pearl "lens slit"**: visible 2-3 times per post on every court
(crop of WK-116_longhaul_base.png, both goal posts). The gaps between pearls in the source are at rows ≈199, 319, 439,
561, 682, 799, so **cap_frac 0.20** gives a centre tile of rows 200-803. That is exactly 5 periods, with both cuts
inside a gap.
- **Fix B0:** `_paint_bumper` vertical: `ThreeSlice.build(post, ..., 0.20, true)` (was 0.22). The arena_rendering brief's
  22/56/22 is superseded for this asset: 20/60/20.

### Fix B1: long rails (w/h >= 1.6). No generation needed: transpose the post
- Make `assets/world/bumper_rail.png` offline: `bumper_post.png` rotated 90° clockwise and then flipped horizontally
  (PIL `Image.Transpose.TRANSPOSE`, Godot `rotate_90(CLOCKWISE)` + `flip_x()`). Result is 1003x208.
- A transpose maps top-left to top-left, so the lighting stays correct. The pearl speculars stay upper-left and the
  cylinder highlight becomes the top band of a horizontal tube. A plain ±90° rotation would light the studs from
  below, so do NOT just set `rotation`.
- Draw: `ThreeSlice.build(rail, w + 8, h + WALL_FACE_BLEED * 2, 0.20, false)`. No tint: the chrome grey IS the bumper tier.
- What it looks like:
  - An 80 px ceiling gets about 36 px pearls on a ≈51 px period, the same scale as the 50-66 px wide goal posts beside it.
  - The ceiling and posts now read as one chrome pipe frame with rounded collars at the corners.
  - The 2400 px ceiling = 9 tiles, k≈0.98. Seams land in the gaps.
- Log the rail in CATALOG as derived from bumper_post (no prompt).

### Fix B2: square blocks (w/h < 1.6). One new generated sprite
- `assets/world/bumper_block.png`, drawn with `ThreeSlice.build_whole(block, w + 8, h + 8)`. If that returns null
  (aspect outside ±20%), fall back to the B1 rail.
- Source aspect 7:6 (1.167), so 120x110, 140x120 and 150x120 all fit. After trim, `art.py resize` to 300 px wide
  (about 2x the largest display size).
- **Shape and readability:**
  - A chunky rounded-square chrome cushion (corner radius ≈ 30% of height) with a recessed inner panel holding a
    **2x2 grid of the same glossy white pearl studs** as the post.
  - Same chrome ramp: light #D9DDE3, mid #98A1AF, shade #6E7684. Studs #F4F6F9 with grey socket rings.
    Thick #3B241B outline.
  - At 140x120 on screen each pearl is about 40 px, matching the posts. It must read as "the same bumper family" from
    one glance across the frame.
- **Generation (ChatGPT, attach `assets/world/bumper_post.png` + `assets/reference/style_north_star.png`):**
  > "Using the attached tall chrome bumper post as the exact style and material reference: the SAME bumper, now as a
  > single short chunky block for a cartoon game, straight-on side view. A rounded-square chrome cushion, slightly wider
  > than tall (about 7 wide by 6 tall), light silver-grey (#98A1AF) glossy metal with a bright top-left highlight
  > (#D9DDE3) and darker lower edge (#6E7684). Set into its face: a recessed panel holding a 2 by 2 grid of big glossy
  > white (#F4F6F9) pearl studs with thin grey socket rings, identical to the studs on the post, each with a small
  > top-left specular dot. Rounded corners, no screws, no text, no logo, symmetrical. Square-ish composition with the
  > block centred." + **base style suffix** (arena_rendering.md §"Base style suffix", verbatim).
- Generate at 1536x1024. Intake: `python tools/art.py keyout <dl> <tmp> --tol 45` (a baked checkerboard is likely),
  then `trim`, `resize 300`, `check`.
- **Reject the generation if:** the studs differ from the post's (colour, ring, or highlight side), the outline is
  thinner than the post's, or there is any drop shadow or ground. Re-roll instead of hand-patching.

### Fallback order after the fix
Vertical: post (0.20). Horizontal w/h >= 1.6: rail. Horizontal w/h < 1.6: block, else rail. Only if all are missing:
the existing grey mat strip with its warning.

### Screenshots I need to grade it
the_bowl and long_haul at kickoff (ceiling + corners + hanging blocks), one dropshot court (ceiling against the net's
studded frame, which must still read as "net", not as more bumper), s3_pinball_alley and s3_keyhole (mid-air rails with a goat
bouncing off one), plus 2x crops of a ceiling corner and a post seam.

---

## 3. CIRCUIT UNLOCKED banner (ArenaSelect)

### Problem (WK-179_02_circuit_unlock_banner.png)
`UnlockBanner` is a bare `BannerTop` Label (white 58 px, chocolate outline, no plate) anchored 0.15-0.85 x 0.35-0.65.
Its two lines sit exactly on the preview panel's bottom band: "CIRCUIT UNLOCKED" prints over the
"1 PLAYER + 3 CPUs" chip, and "THE HIGH WIRE" sits in the 50 px gap above the card shelf. White outlined text over a cream
panel and coloured chips reads as a rendering bug, not a celebration. The second line is also redundant: the preview
directly below already shows THE HIGH WIRE in 72 px, and the target card pops.

### Layout fix (1920x1080 design space)
Make the banner a toast in the **header band** (y 0-130, which is already celebration territory) that temporarily takes the
title's place. It must not overlap the preview (starts y=144), the shelf, or the popped card.
- Replace the `UnlockBanner` Label with a `PanelContainer` named `UnlockBanner`:
  - `theme_type_variation = &"ToyRibbon"` (gold #FFD23F, 5 px #3B241B border, radius 26; it already exists in theme.tres).
  - `mouse_filter = 2`, `visible = false`.
  - Anchors: `anchor_left = 0.5`, `anchor_right = 0.5`, `anchor_top = 0`, `anchor_bottom = 0`.
  - Offsets: `offset_left = -330`, `offset_right = 330`, `offset_top = 22`, `offset_bottom = 108` (660x86, centred on
    the header's centre line y=65).
  - `grow_horizontal = 2`.
  - That leaves 46 px clear of BackBtn (right edge x=284) and 46 px clear of the ModeChip (left edge x=1556).
  - Keep it as the last child so it draws on top.
- Child `Label`: `theme_type_variation = &"ToyRibbonTitle"`, `theme_override_font_sizes/font_size = 52`,
  text `"CIRCUIT UNLOCKED!"`, centred both ways. **One line only.** Drop the `\n%s` circuit name in
  `_play_unlock_celebration` (set the Label's text, not the Panel's).
- Motion (replaces the current tween; same 0.5 s delay):
  1. `Header/Title` `modulate:a` 1 → 0 over 0.12 s.
  2. Banner `position.y` from rest -110 → rest (0.35 s, TRANS_BACK, EASE_OUT), `modulate:a` 0 → 1 over 0.15 s, scale 0.85 → 1.0
     (pivot = size * 0.5).
  3. Hold 1.6 s.
  4. Banner `position.y` → rest -110 and `modulate:a` → 0 (0.3 s, EASE_IN), then `Header/Title` `modulate:a` → 1 (0.2 s),
     then hide the banner.
  - The card scroll, focus and pop (scale 1.18) are unchanged.
  - Store the banner's rest position once in `_ready` so a second celebration never drifts.

### Screenshot I need to grade it
Capture at about 0.5 s after the banner lands (fully in) and again after it leaves (title restored), BRAWL ArenaSelect with a
pending unlock (`Settings.pending_unlock` set via eval).

---

## Do not
- Put any decal above the landing line, mirror any texture, or tint the bumper chrome per court.
- Hand-fix a generated block in-engine with modulate or polygons. Re-roll it.
- Mark any of the three closed without the listed rendered screenshots going through an art-director grade.
