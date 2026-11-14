# Art brief: ghost goats + puff cloud (WK-37b)

Date 2026-11-14 · Author: art-director · Backlog WK-37b [M] (build) · Spec: `docs/specs/wk37a_ghost_goats_2026-11-14.md` §5
(readability table), §2.3 (puff phases), §2.4 (bleat). Grading is from **in-game screenshots and WK-93 recordings only** (§7).

## 0. The one-sentence read
A ghost is **the same goat, minus everything that says "alive and touchable"**: no chocolate outline, no feet, no flame, no
bounce, faded to 40 %. It gains a wavy hem, a curling tail and a pale rim. The puff cloud is the reverse: **a touchable toy**
(chocolate outline, white marshmallow top) that carries its owner's colour.

House rule this leans on (`docs/briefs/arena_rendering.md`): **a chocolate outline means "you can touch this".** Living goats and
clouds have one. Ghosts do not. That gives a value read that holds up in colourblind and greyscale views, on top of alpha and motion.

## 1. Per-element decision: shader/code vs new art

| # | Element | Route | Why |
|---|---|---|---|
| E1 | Ghost body (Phase A) | **Shader on the existing `bouncer_<skin>_idle.png`** (`assets/shaders/ghost.gdshader`, new) | Keeps per-hero identity (horns, fluff) at no art cost. Every effect below works with UV and alpha alone. |
| E2 | Pale rim / halo | **Code:** a second Sprite2D with the same texture behind the body, using the existing `flat_tint.gdshader` | Crisp cel-style halo band. Needs no padded quad and no blur haze. |
| E3 | Wavy hem (feet removed) | **Shader** (part of E1) | The classic sheet-ghost hem, animated. It hides the feet, which are the biggest "standing creature" cue. |
| E4 | Tail / wisp | **NEW ART** `assets/fx/ghost_tail.png` (tintable) + shader sway | A shader can't draw outside the sprite rect without procedural shapes, and procedural SDF blobs break the no-SVG-art rule. The tail is the main silhouette change (round to comma/teardrop). |
| E5 | Ghost face (big round eyes, "O" mouth) | **Phase A:** existing idle face, no halo ring (see §3 note). **Phase B: NEW ART** `bouncer_<skin>_ghost.png` x6 | Pillar 6. It also removes the baked jetpack, which Phase A can't mask safely: the orange-hue mask would also eat BILLY. Not build-blocking. |
| E6 | Puff cloud, solid | **NEW ART** `assets/fx/ghost_puff.png` (tintable), drawn with the existing `fx_tint.gdshader` | A bespoke touchable toy. The house grey-plus-chocolate tint contract makes one asset serve all 6 colours. |
| E7 | Cloud owner stroke + dotted telegraph | **Derived at intake** (PIL, deterministic) from E6's alpha: `ghost_puff_stroke.png` + `ghost_puff_dash.png` | Lines up with the body exactly, with no runtime dilation shader. ChatGPT can't produce two pixel-aligned layers. |
| E8 | Puff-ready orbiting mini-cloud | **Reuse** E6 at small scale | No new art. |
| E9 | Cloud pop (super/stun/fade) | **Reuse** `fx/ko_blast_ring.png` (small) + `fx/puff_soft.png` particles, using `fx_tint` | Same VFX family as the KO blast. Add zero shake (spec §4.5). |
| E10 | Dud "fft" wisp | **Reuse** `fx/puff_soft.png`, 3 particles | It's tiny and should be forgettable. |
| E11 | Ghost pop-in | **Reuse** `fx/puff_soft.png` + scale/alpha tween | It rises out of the KO blast that WK-23 already shows. |
| E12 | HUD card ghost head | **NEW ART** `assets/ui/ghost.png` (sibling of `ui/skull.png`) | A shader-washed 40 % goat head at HUD size is mush. It needs a crisp, opaque icon from the same family as the skull it replaces. |
| E13 | HUD cooldown ring + hush | **Code** arc, same style as the WK-36 fuel ring; "SHH" in Lilita One | The style is already established. |
| E14 | "BAAA!" word puff | **Text** in Lilita One + **NEW ART (shared with WK-53)** `assets/fx/word_burst.png` | Text alone reads as a debug label. A tintable shout-burst behind it makes it a toy. Whichever of WK-53/WK-37b lands first generates it, once. |

## 2. Layout sketch (described)

**The ghost, at 1:1 for a 1920x1080 frame at zoom 0.46.** A living goat is about 45 screen px tall. The ghost body is 0.85 of
that, about 38 px.
```
          .-~~~-.            <- pale rim band (E2), ~2-3 screen px wide all round the body silhouette, no chocolate
        (  o   o  )  horns   <- face from the idle art (Phase B: big round eyes, "O" mouth); horns intact (identity)
        (    O    )
         \/\/\/\/\           <- wavy hem (E3): 3 scallops across, animated; feet gone
             \  \__
              \___ )~        <- tail (E4) BEHIND the body: root hidden under the hem, ~0.7 x body height, curls at the tip,
                                trails opposite the velocity
```
- **Bob:** whole root ±6 px at 0.8 Hz (spec). The tail lags the bob by about 0.15 s (spring follow), so it reads as cloth, not a
  rigid sprite.
- **Facing:** follows velocity x, with a 0.15 s deadzone so it doesn't flicker. The tail mirrors with it.
- **Draw order (spec):** platforms < puff clouds < ghosts < living goats < VFX. A ghost is never drawn over a living goat.

**The puff cloud**, 180x64 world px, which is 83-112 screen px wide at zoom 0.46-0.62.
```
      .--.  .---.  .--.          <- 3-4 big round top bumps: white marshmallow top (stays white through fx_tint)
    (   ' o   o '        )       <- tiny chocolate face, centred (dot eyes, small "o" mouth)
     '--.___.--.___.---'         <- smaller underside bumps; grey underside shading -> tinted owner colour
   [==== owner-colour stroke outside the chocolate outline, >= 6 screen px ====]
```
- **Telegraph (0.5 s):** only `ghost_puff_dash.png`, about 14 dashes in the owner colour. It scales 0.55 to 1.0 with ease-out-back
  and an alpha pulse of 0.6 to 1.0 at 6 Hz, and it is non-solid. The body then pops in at the exact same rect (scale 1.08 to 1.0
  over 0.08 s), so "the outline you saw becomes the cloud".
- **Solid (2.0 s):** body plus stroke at 85 % alpha (spec). Wobble on contact: scale-Y 0.85 to 1.0 over 0.15 s when a goat bounces
  on it. Sinks at 120 px/s.
- **Art bleed:** top bumps may rise up to 10 world px above the collider top, and the ends up to 8 px past the sides, the same as
  the platform bleed rule. Colliders stay exact.

## 3. Ghost shader spec (E1/E3, for the programmer; I grade the result)
`ghost.gdshader` (canvas_item). Uniforms: `skin_col`, `t` (or TIME), `hem_y` (per-skin, default 0.80), `hem_amp` 0.035,
`hem_waves` 3.0.
1. **Colour:** keep the hue. Saturation ×0.85, then mix 20 % toward white. Body targets are in the §4 table. **Don't wash it out
   to white:** at 40 % alpha, a pale ghost goes invisible over the bright meadow sky. Colour is what keeps it findable there.
2. **Outer outline replaced:** for a dark pixel (luma < 0.3) where any of 8 taps at ~4 % of texture width has alpha < 0.5, output
   the `rim` colour. The chocolate outline is about 28 source px thick on the 774 px sprites. This is the "not touchable" read.
3. **Inner lines** (pupils, mouth, horn grooves, any other dark pixel): `deep` colour (skin × 0.45). The face must still read.
   Don't let pupils go white, because blank eyes read as creepy, not cute.
4. **Hem:** `cut = hem_y + hem_amp * sin(UV.x * hem_waves * TAU + TIME * 3.0)`, then
   `alpha *= 1 - smoothstep(cut, cut + 0.025, UV.y)`. Keep the edge crisp (0.025), not a soft gradient.
5. **Alpha:** take the node's modulate. The ghost root carries `modulate.a = ghost_alpha` (0.40 / 0.25), so the spec's T9 eval
   check works unchanged. The 0.40 ↔ 0.25 change eases over 0.2 s and never snaps.
6. **The RGB junk in alpha-0 pixels** (the known generation gotcha: dark brown/grey RGB in transparent corners) must not bleed into
   the rim. Gate every output on the sampled alpha.

**Rim layer (E2):** a sibling Sprite2D behind the body. Same texture, `flat_tint` in the `rim` colour, scale ×1.08 about the body
centre, inherits the root alpha. It uses the same hem cut, so the halo doesn't show feet: give it the ghost shader with a
`flat=true` path, or a separate hem uniform.

**No halo ring.** The spec's placeholder idea ("existing face plus a halo") is out. A gold ring reads as angel, not ghost, and
could be confused with pickup or "!" UI. The pale rim is the "halo".

**Tail (E4):** drawn behind the rim layer, using the same ghost shader (its chocolate outline turns into rim the same way). The root
is anchored at body centre plus (0, 0.30 × body h). It rotates ±25° opposite velocity.x, plus a ±8° sway at `ghost_bob_hz`. Add a
UV sine displacement that is 0 at the root and grows toward the tip (amp 0.04, 2 waves).

## 4. Palette (hex)

| Skin | Living (PlayerIdentity) | Ghost body (target) | Rim | Deep (inner lines) |
|---|---|---|---|---|
| POGO pink | `#FF5FA8` | `#F589BA` | `#FFCFE5` | `#732B4C` |
| BUTCH blue | `#4AA8FF` | `#79B9F4` | `#C9E5FF` | `#214C73` |
| ZIGGY green | `#54C94A` | `#7DCC76` | `#CCEFC9` | `#265A21` |
| PUFF yellow | `#FFC93F` | `#F3CF71` | `#FFEFC5` | `#735A1C` |
| VEX purple | `#A15FFF` | `#B589F5` | `#E3CFFF` | `#482B73` |
| BILLY orange | `#FF7A2D` | `#F29864` | `#FFD7C0` | `#733714` |

- Always derive these from `PartyMatch.player_color(i)` (WK-08). The table is the acceptance target, not a second source of truth.
- **Cloud:** top `#FFFFFF`, body `#F2F2F2`, underside shade `#BDBDBD` (tinted to the owner colour by `fx_tint`). Outline
  `#3B241B`, face `#3B241B`, stroke and dashes = owner living colour at full saturation.
- **White on the top is deliberate:** the cloud IS marshmallow tier (`#FFF6EC` family). The "white = softest bounce" lesson carries
  over for free.
- **Hush:** HUD ring `#9AA0A8` + "SHH". **Dud wisp:** `#C4CAD3` at 0.6 alpha.
- **Reserved-colour check:** POGO's cloud stroke (`#FF5FA8`) sits next to bubblegum `#FF4FA3`. That's acceptable only because the
  cloud reads white with a pink edge, never pink-filled. Tested in R6.

## 5. Silhouette / readability requirements (pass/fail)
1. **Ghost vs living** is carried by at least 4 channels that don't depend on hue: alpha (0.40 vs 1.0), outline (none vs
   chocolate), silhouette (hem + tail comma vs round ball with feet), and motion (glide/bob vs constant bounce + squash). Scale
   (0.85) is a 5th, weak channel.
2. **Identity (which player)** is carried by hue + horn silhouette (kept intact by the shader) + the P# pip. Under colour
   blindness, horns + pip must carry it alone.
3. **Minimum sizes at zoom 0.46, 1920x1080:**
   - ghost body ≥ 36 px tall, tail ≥ 20 px long;
   - cloud ≥ 83 px wide, owner stroke ≥ 6 px, telegraph dashes ≥ 6 px thick and ≥ 10 px long;
   - mini orbit cloud ≥ 20 px wide (44 world px; orbit radius 60 world px, period 2.0 s);
   - "BAAA!" cap height ≥ 28 px (WK-18 floor).

   Halve all of these for the 1280x720 gbplay capture.
4. A ghost never hides a living goat: z-order, plus 0.25 alpha within 250 px.
5. **The cloud must not read as:**
   - a level platform (rounded scallops, no flat top, sinks, wobbles, owner colour);
   - a background cloud (bg clouds have no outline and the puff has chocolate);
   - a bubblegum mat.

## 6. Asset list + generation prompts

**Conventions (pipeline skill §3-§5):**
- Append the base style suffix verbatim to every prompt.
- Attach `assets/reference/style_north_star.png`. For tintable FX also attach `assets/fx/ko_blast_core.png` ("same family as this
  attached effect").
- If the clipboard is locked, use the text-only fallback in one chat (KO-blast precedent).
- Intake: `art.py check`, then defringe (normalized-convolution colour bleed, portrait intake pattern), then trim. Check the
  Downloads timestamp first. Record each prompt in `assets/CATALOG.md`.

**Tintable clause** (for A1, A2, A4), the same contract as `ko_blast_*`:
> "Entirely WHITE and light-grey (greyscale only, no colour at all) so the game can tint it any colour; fill ~#F2F2F2 shading down
> to ~#BDBDBD on the underside, pure-white gloss highlights; thick clean dark-chocolate (#3B241B) outline; no glow haze, no soft
> airbrushed edges, no text, no letters."

### Required for the WK-37b build (3 generations)

**A1 `assets/fx/ghost_puff.png`.** Source ≥ 1024 px wide, aspect about 2.8:1. Drawn at 180x64 world px.

Prompt:
> "A single chunky cartoon PUFF CLOUD toy for a 2D party game, wide landscape composition, roughly 3 times wider than tall. Three
> or four big round fluffy bumps along the top, smaller round bumps along the underside, rounded ends, overall a fat bouncy
> marshmallow-like cloud cushion. A tiny cute face in the centre in dark-chocolate: two small dot eyes and a small round 'o' mouth.
> Bold simple silhouette that reads at small size, few large shapes, no tiny detail. [tintable clause] [base suffix, replace
> 'Square image.' with 'Wide landscape composition.']"

Intake:
1. trim, then pad with a 96 px transparent margin on every side (room for the stroke);
2. PIL derives `ghost_puff_stroke.png`: a white ring of alpha dilated 80 source px minus the original alpha. That's ≥ 6 screen px
   at zoom 0.46 when the 1024 px art is drawn at 180 world px;
3. PIL derives `ghost_puff_dash.png`: the stroke × an angular dash mask, 14 dashes at a 55 % duty cycle, around the centroid.

Both derived files are white, tinted by modulate.

**A2 `assets/fx/ghost_tail.png`.** Source about 600x1000 portrait. Drawn at about 0.7 × ghost body height.

Prompt:
> "A single cartoon GHOST TAIL wisp for a 2D game character, tall portrait composition: a wide rounded top end (it attaches under a
> round body, so the top edge is a wide soft dome) that tapers smoothly downward into a thin tail tip that curls into a small hook to
> the right, like the bottom of a classic cartoon ghost or a comma. One smooth flowing shape, no separate strands, no smoke puffs.
> [tintable clause] [base suffix, replace 'Square image.' with 'Tall portrait composition.']"

Reject the generation if it comes back as smoke or wisps of strands (they turn to noise at 20 px), or as a flame shape (flame =
alive).

**A3 `assets/ui/ghost.png`.** 128 px final; generate square. HUD dead-card icon, the sibling of `ui/skull.png`.

Prompt (attach `assets/ui/skull.png` as the family reference, NOT a bouncer: avoid face bleed):
> "A glossy cream-coloured toy GHOST icon in the exact same style as the attached skull icon: classic round-top sheet ghost with a
> wavy scalloped hem of three bumps at the bottom, two big round dark eye holes, a small round open 'O' mouth, and two tiny stubby
> bone-coloured goat horn nubs on top of the head. Same cream colour, same chocolate outline thickness, same soft plastic shine.
> Front view, centred. [base suffix]"

It must read at 48 px on a dimmed card: hold it next to the skull at 48 px, and the two must be the same family at a glance.

### Recommended (shared with WK-53, 1 generation; whoever lands first makes it)

**A4 `assets/fx/word_burst.png`.** Square, about 768 px. Drawn at about 1.6 × the "BAAA!" text width.

Prompt:
> "A single cartoon SHOUT speech-burst bubble for a 2D party game: a chunky jagged comic exclamation balloon with 8-10 fat rounded
> spikes and a short tail pointing down-left, empty in the middle for text to be added by the game. [tintable clause] [base suffix]"

In game: fx_tint to the player colour, with "BAAA!" in Lilita One (cream fill, chocolate outline) on top. Wobble ±8° at 6 Hz,
decaying; rise 40 px over 0.7 s. The ghost variant is the same at 60 % alpha.

### Phase B (Pillar-6 upgrade, 6 generations, not build-blocking; can run now with no game slot)

**A5 `assets/characters/bouncer_<skin>_ghost.png` x6.** Same canvas/scale convention as `_idle` (body diameter / width ratio
matching, so `SPRITE_BALL_FRAC` holds).

Per hero, attach `bouncer_<skin>_idle.png` (plus style_north_star):
> "The same exact character, same style, same colour, same horns, now as a GHOST: big round surprised eyes, a small round open 'O'
> mouth, both tiny arms raised in a spooky 'boo!' wave, NO feet (the bottom of the body is a smooth round dome), NO jetpack. Normal
> fully opaque colours and the same thick dark-chocolate outline. Do NOT make it transparent, glowing or faded; the game does that.
> Side view facing right. [base suffix]"

Add explicit NOT-colour exclusions per hero (the style-bleed lesson from art pass #2, e.g. "NOT yellow, NOT fluffy" for VEX).
Code then swaps it in for the idle texture in the ghost node, and the shader and tail stay identical. Done when all six are SHIP from
the R1 sheet.

**Total generations:** 3 required (A1-A3), +1 shared (A4), +6 Phase B (A5).

## 7. Readability tests the grader (me) will run
All tests run from rendered captures. Durations use game time (CD2-05: each 1080p screenshot stalls about 1.25 s). Capture tools:
`gbplay.py screenshot` + eval, and WK-93 recordings in `tools/out/rec/wk37_ghosts_*`.

- **R1 Classification sheet (spec T9).**
  - Capture 20 random combat frames with ≥ 1 ghost and ≥ 2 living goats at zoom ≈ 0.46. Downscale to 640x360.
  - I must classify every goat as living or ghost: **20/20**, each in under 1 s.
  - Squint variant: the same sheet with a 2 px Gaussian blur must still give 20/20. Alpha, outline and silhouette survive blur;
    detail doesn't.
- **R2 Four-player tracking (spec T10).**
  - A 30 s recording: 4-player brawl, 3 HumanSim + 1 CPU, LIVES 1, zoom 0.46, ending with 2 living + 2 ghosts.
  - On the contact sheet, I must point at both living goats in every frame within 1 s.
  - Fail on: any ghost over a living goat, any vertical bounce reversal on a ghost, or any visible snap when the alpha changes.
- **R3 Colourblind.**
  - Run the Machado-2009 deuteranopia, protanopia and tritanopia matrices plus full greyscale on 6 R1 stills (PIL script in the
    scratchpad).
  - Pass: living vs ghost is still 20/20, which proves it doesn't depend on hue.
  - Pass: ghost identity is resolvable through horns + P# pip for each pair at risk. These are ZIGGY/BILLY/PUFF under deut/prot,
    and POGO/VEX/BUTCH under tritan.
- **R4 Backdrop matrix.**
  - Use eval to park one ghost of each of the 6 skins over sky AND over the void/pit band, on each of the 5 brawl paintings:
    `meadow_day`, `space_nebula`, `ember_foundry`, `dusk_gold`, `overcast_quarry`.
  - Capture at alpha 0.40 and 0.25: 5 shots × 2 alphas.
  - Pass at 0.40: every ghost can be located within 1 s.
  - At 0.25: findable when looked for. It's meant to recede, but it must not vanish.
  - Predicted worst cases (pre-registered):
    - PUFF over the `dusk_gold` horizon;
    - BUTCH over the meadow sky;
    - VEX over the `space_nebula` indigo;
    - BILLY over the `ember_foundry` glow.
  - **Fix path if one fails:** a per-painting `ghost_rim: "deep"` flag in ArenaRenderer.PAINTINGS swaps the rim colour from
    light to `deep` on bright themes. Data, not a new asset. Do not raise `ghost_alpha` (that's the spec's knob, and it goes the
    other way).
- **R5 Puff cloud.**
  - Frame-step a recording through one puff:
    - the telegraph is visible for ≥ 12 frames at 30 fps;
    - dashes are clearly dotted, not solid;
    - telegraph-to-solid lands in the same rect with no jump;
    - the pop VFX is owner-coloured and adds no camera shake.
- **R6 Confusables.**
  - Use eval to spawn a POGO cloud beside a bubblegum mat and a marshmallow mat on meadow, with background clouds in frame.
  - Shown the frame cold, a creative-director must name the puff cloud as "the ghost's cloud", not a platform or sky cloud.
- **R7 Polish (auto-Fix if any is seen):**
  - visible quad edges or clipped rim;
  - dark fringe or halo from alpha-0 RGB junk;
  - hard seam where the tail meets the hem;
  - tail rotating like a rigid stick;
  - hem waves stepping or aliasing;
  - feet visible on any skin (tune `hem_y` per skin);
  - any flame, streak or shadow node on a ghost;
  - a halo ring.
- **R8 HUD.**
  - At 1280x720: the ghost icon reads as a ghost (not a blob or a skull) on a dimmed card.
  - The ring is ≥ 4 px, fills clockwise from 12 o'clock like the fuel ring, and turns grey + "SHH" during hush.
  - The BAA ONLY mode shows no ring.

**Verdict rules:** **Ship** only with R1-R8 all passing. Any R1/R2 miss is a Fix. If the ghost reads as "a second living goat" at a
glance in normal play, that's a **Reject** of the treatment, with the brief restated (the 4 channels in §5.1).
