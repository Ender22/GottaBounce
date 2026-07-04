# Art Brief / Ruling — Central Pit as a Readable Lethal Void ("Glossy Toybox")

> Author: Art Director. Status: **APPROVED FOR BUILD** (new rendering feature).
> Trigger: creative-director verdict #2 (`docs/briefs/cd_verdict2_2026-07-04_killshape.md`) — the
> central pit is the arena's #1 felt problem: it is VISUALLY INVISIBLE. A player who falls into the
> x1600..2160 gap reads it as "standing on / falling through grass," like a bug, not a designed death.
> Companion: `docs/briefs/arena_rendering.md` (Glossy Toybox visual language, layer stack, reserved
> colors, the chocolate-outline depth trick). Implementer: gameplay-programmer. I grade from in-game
> screenshots only. The Art Director does not write game code.

---

## 0. The problem, stated as an art problem

Screenshots `tools/out/cd2_flight.png`, `cd2_burst/frame_005.png`, `cd2_combat/frame_009.png`: the two
trampoline floors (x0..1600, x2160..3760) float over a **continuous bright-green field** that is the
same value/hue as the ground the bouncers stand on. The 560px gap between them is painted with nothing
— so the "pit" is literally a strip of safe-looking meadow. There is no depth, no shadow, no danger
cue. It is not a designed death; it looks like a rendering hole. **A death zone that looks identical
to safe ground is the worst readability failure in the game.**

### The inversion that resolves the style tension

Glossy Toybox's core depth trick (arena_rendering.md §1): **a thick dark-chocolate OUTLINE = "you can
touch this."** Everything solid/friendly wears the dark line; backgrounds wear none. The lethal void is
the **exact inverse**, and I want the renderer to express it as an inversion, not a bolted-on scary
texture:

> **Chocolate outline = dark LINE around a bright glossy mass = touchable solid.
> The void = a dark cool FILL / empty mass with NO friendly outline and NO gloss = untouchable death.**

Both live at the dark end of the value range, in opposite roles. This keeps the read *inside* the
existing visual grammar: the void is the **only large dark FILL** in a bright candy world, exactly as
chocolate is the only dark LINE and grey is the only interactive neutral. One dark mass in a bright
meadow reads as "danger / hole" instantly, at any zoom, and is colorblind-safe (it's a **value**
contrast first, hue second). A generic black scary chasm would clash; a *stylized cartoon cave-mouth*
with candy-world craft does not — cartoon worlds have caricatured pits-of-doom and they are on-brand.

**Primary read channel = VALUE (dark vs bright meadow). Color and motifs are secondary polish.** This
matters for far-zoom: a 560px-wide dark mass is ~274 screen px at far zoom and never drops below
threshold (unlike the 14px tier mats), so the read is robust by construction.

---

## 1. Verdict / ruling

**Build a stylized cartoon lethal-void renderer**, combining four cues (all cheap), in priority order:

1. **Depth-shaded bottomless fill** — a cool dark vertical gradient in the gap, meadow-shadow at the
   rim darkening to near-black cool navy at the bottom. *This alone fixes the CD's complaint;* the
   rest is polish that upgrades "dark hole" to "designed lethal void."
2. **Receding cartoon dirt WALLS** on both pit-facing floor edges (the ground visibly continues DOWN
   as rock strata into shadow), slightly tapered/foreshortened toward the bottom → volume + "it goes
   away below you."
3. **A hazard LIP treatment** on the two pit-facing edges (x1600 / x2160): the inverse-of-chocolate
   "you CANNOT stand here" signal — a thin matte hazard-red rim + small down-pointing chevrons, and
   suppression of the cheerful grass tufts/flowers at the death edge.
4. **Falling motes** drifting down into the gap and fading — "things fall in here and are gone."

**Do NOT** use a saturated full-width danger BAND as the primary read (it would fight the candy palette
and risk colliding with the reserved tier colors at a squint). Darkness + depth is the read; the red is
a thin accent only.

---

## 2. Geometry — derive from an explicit `void` object, NOT from the platform gap

**Recommendation: add ONE new level-schema object.** Do not auto-detect the void from the gap between
platforms.

Rationale: "the gap between two platforms" is ambiguous — every arena has gaps that are *not* death
(open air you fly through, space beneath floating pads, the runway beyond the outer floor edges). Which
gap is lethal is a **design decision** and must be declared, not inferred. An explicit object also lets
the level-designer set the exact rim, width, wall thickness, and painted depth, and gives gameplay a
future hook to attach a kill Area to the same rect.

### Schema — new object type `void`

```json
{ "type": "void", "x": 1600, "y": 1000, "w": 560, "h": 798 }
```

For `levels/grassy_expanse.json`, add to `objects`:
- `x` = 1600 (left floor's inner edge, = its right edge).
- `y` = 1000 (pit mouth = the floor top surface line; same top-left convention as platforms).
- `w` = 560 (the gap: right floor inner edge 2160 − 1600). **Must equal the inner-edge span** — a void
  narrower/wider than the actual fall opening is a readability lie (same rule as mats spanning the full
  collider). The renderer should span the fill to `[x, x+w]` and rely on the platforms' 8px dirt bleed
  to overlap the top corners.
- `h` = 798 (rim y=1000 → bounds bottom y=1798). The renderer paints the gradient/walls over `h`, then
  **extends the deepest color solid below** to `bounds.bottom + margin` (reuse the `_extend_below`
  pattern) so no gradient seam can ever show under the hole at any zoom.
- Optional: `"wall_px": 80` (dirt wall width per side, default 80), `"lethal": true` (reserved for a
  future gameplay kill-Area; renderer ignores it).

**No collider.** The void is display-only for v0. The actual kill remains the bounds-bottom line; the
void's job is to make that death legible *before* the player falls.

---

## 3. Visual treatment — exact values

All hexes below are **new and reserved to the lethal void** (see §5). Structure, back to front inside
the gap:

### 3a. Center bottomless fill (the "you fall forever" core)
A vertical gradient spanning the gap between the two dirt walls, i.e. `[x+wall_px, x+w−wall_px]` wide,
from rim to depth. 4-stop cool ramp (top→bottom):

| stop | y | hex | reads as |
|---|---|---|---|
| 0.00 | rim (y=1000) | `#2B5140` | shadowed grass/ground underside (ties to the meadow so it's clearly "ground continues down") |
| 0.18 | | `#143A46` | cold teal-slate |
| 0.50 | | `#0E2536` | deep blue-slate |
| 1.00 | depth + below | `#060E18` | near-black cool navy — bottomless |

Implement as a `GradientTexture2D` (vertical) on a Sprite2D scaled to the rect (cleanest 4-stop), then a
solid `#060E18` extension below to `bounds.bottom + ~600`.

### 3b. Near dirt walls (volume + "it goes down")
Two panels, one per pit-facing edge, each `wall_px` wide (default 80), from rim to depth. **Taper the
bottom inward ~25%** (trapezoid: bottom edge inset toward the gap center) to foreshorten "receding down
and away." Dirt ramp top→bottom, matching the floor bodies so the wall reads as the SAME ground going
down: `#6E4126` (lit top) → `#4A2C18` → `#241408` (deep). Add 2–3 thin darker horizontal strata lines
(`#2A1810`, ~4px) for cartoon rock layering. A 2px warm highlight (`#8A5A38`) on the top inner corner of
each wall catches the top-left light. Walls fade their own bottom into the center fill's deep color.

### 3c. Under-lip ambient-occlusion band
A soft dark band hugging the underside of both floor lips: full gap width, top ~36px, color
`#0A1A24` at 55% alpha fading to 0 downward (vertex alpha). This is the shadow the overhanging grass
fringe casts INTO the hole — it makes the floor visibly overhang the void (undercut), the strongest
"there is no ground here" cue.

### 3d. Falling motes (motion = death)
One `CPUParticles2D`, emission box across the full gap width at the rim, **gravity down**, slow:
`amount ≈ 14`, `lifetime ≈ 2.5s`, `initial_velocity 20..60`, `spread 10°`. Color ramp pale cool
`#CFE6E0` (a≈0.35) → transparent. Additive. Sparse and slow — this is atmosphere, not confetti; readable
chaos over busy prettiness (VISION pillar 5). Only downward motion (down = death); no rising wisps.

### 3e. Hazard LIP accent (the inverse-of-chocolate "cannot stand here" signal) — YES, the lip needs it
The CD explicitly asked whether the lip needs a danger cue. **Yes.** The chocolate outline on the floor
edge currently says "touchable." At the pit-facing edge that is a lie. On each edge (x1600 and x2160):
- **Rim line:** a thin **matte** hazard-red bar `#E6402C`, ~5px tall, tucked just under the grass
  fringe (y ≈ rim−1 .. rim+5). MATTE, not glossy (gloss = toy = touchable; matte = warning).
- **Chevrons:** a row of small down-pointing chevrons `#E6402C` with a thin dark-red outline `#7A1E14`
  (NOT the chocolate `#3B241B` — chevrons are a warning glyph, not a touchable surface, so they get a
  dark-red edge to stay off the "touchable" grammar), spaced ~90px along the lip, pointing INTO the
  pit. Keep them small (~14px) and low-contrast enough not to fight the candy palette.
- **Decal suppression:** within ~50px of a void edge, `_scatter_end_decals` must **skip the cheerful
  grass tuft + daisy** on that cap, and the friendly rounded grass cap on that side is trimmed/darkened
  so the edge looks broken/crumbling, not manicured. A daisy blooming at the lip of a death pit is an
  automatic Fix.

Keep the whole lip accent restrained: it is a hot warning EDGE on a dark hole, a gestalt spring (bright
orange bar on silver coils on a bright glossy platform) never resembles.

---

## 4. Layering / z-order / parallax

The void is **gameplay-tier world geometry (parallax 1.0)**, not a background — it does not scroll-lag.
But it must render **behind** the platform art so the floors' dirt (8px `BODY_BLEED_SIDE`) overhangs and
hides the top seam, and **the lip accent renders above** the platform art so the red rim/chevrons sit on
the very edge.

Void root node: world-locked (add at world coords; if using the `_layers` list, factor = 1.0 so there
is zero parallax offset). Draw order / z within the arena:

| piece | z_index | vs platform art (z≈0) |
|---|---|---|
| center bottomless fill (3a) + solid extension | −8 | behind |
| near dirt walls (3b) | −7 | behind |
| under-lip AO band (3c) | −6 | behind |
| falling motes (3d) | −5 | behind (but in front of fill) |
| **lip hazard accent (3e)** | **+1** | **in front** (sits on the edge, over the grass fringe) |

All background layers are z ≤ −80 (arena_rendering.md §3), so the whole void sits cleanly in front of
sky/hills/clouds/props and behind the touchable platforms. **Optional depth polish:** a single "far
wall" strata sprite behind 3a at parallax ~0.9 gives a subtle depth-shift when the camera pans — nice-
to-have, do not scope-creep for v0.

---

## 5. Reserved-color update (enforce alongside arena_rendering.md §2)

Add to the reserved list — **lethal void only, nothing else may use these:**
- **Hazard red `#E6402C`** (+ outline `#7A1E14`). Distinct from bubblegum magenta `#FF4FA3` (violet-hot
  pink) and from spring safety-orange `#FF6A2A` (brighter, higher hue). It is red, matte, and only ever
  appears on the dark void lip — no bright glossy red surfaces anywhere else.
- **The cool dark void ramp** (`#2B5140`→`#060E18`) as a **large dark FILL/mass**. Backgrounds stay soft
  and cool but never near-black; platform bodies stay warm/saturated. The near-black cool mass is the
  void's signature, mirroring "chocolate is the only dark line, grey is the only interactive neutral."

This preserves the discipline: dark FILL = void, dark LINE = chocolate/touchable, grey = bumper, and the
three tier colors stay untouched.

---

## 6. Build notes for the gameplay-programmer

1. **LevelLoader** (`src/core/LevelLoader.gd`, object switch ~line 40–52): add a case for
   `type == "void"` → `renderer.paint_void(o)`. No collider, no Area for v0.
2. **ArenaRenderer** (`src/systems/ArenaRenderer.gd`): add `func paint_void(v: Dictionary) -> void`.
   Compute `rim_y = v.y`, `left_x = v.x`, `right_x = v.x + float(v.w)`, `depth = float(v.h)`,
   `wall_px = float(v.get("wall_px", 80.0))`. Build the pieces in §3 at the z-indices in §4. Reuse the
   existing `_extend_below` philosophy for the solid deep extension under the fill, and `_warn_once`
   if any optional field is malformed. **No new assets required** — the void is 100% code-drawn
   (gradients, polygons, one CPUParticles2D). This is deliberate: it must adapt to any pit width/theme.
3. **Decal suppression:** `paint_platform` needs to know its edges' void-adjacency. Simplest: LevelLoader
   passes the list of void rects to `paint_platform` (or precomputes, per platform, a
   `suppress_left/suppress_right` bool where a cap is within ~50px of a void edge) so
   `_scatter_end_decals` skips the tuft+flower and trims the friendly cap on the death side.
4. **Order of operations:** call `paint_void` for each void AFTER `setup()` (background stack) and it can
   run before or after `paint_platform` — z-index handles layering, but painting platforms last means
   their dirt bleed reliably overlaps the void's top corners.
5. **Do not** add any collider that changes gameplay — the pit fall is already tuned in the JSON
   (design_intent). This is display-only.

---

## 7. Grading checklist (I will Ship/Fix/Reject from in-game screenshots)

1. **The invisible-pit bug is dead:** in a `cd2_flight`-equivalent shot, the x1600..2160 gap reads as a
   dark hole, obviously distinct from the bright meadow, at gameplay zoom (0.6–0.9) AND at max zoom-out.
   A first-time viewer must be able to point at "the place you die."
2. **Depth reads:** the gradient darkens downward and the walls give volume; it looks bottomless, not
   like a flat dark rectangle painted on the grass.
3. **Lip says "do not stand here":** the hazard rim/chevrons are visible on both edges, the death edge
   has NO cheerful tuft/daisy, and the floor visibly overhangs the hole (under-lip AO).
4. **Still Glossy Toybox:** the void does not look like a grey debug rectangle or a photoreal black pit;
   it reads as a stylized cartoon cave-mouth. The rest of the arena stays bright and candy.
5. **Color discipline:** hazard red only on the void lip; no reserved tier color (magenta / safety-
   orange / blue+yellow) anywhere near the pit; the void is the only large dark fill.
6. **No seam at the bottom** at any zoom (solid extension working); no seam where the floor dirt meets
   the wall top (bleed overlap working).
7. **Motion means death:** motes fall (never rise) and fade; sparse, not busy.

Capture for grading: far zoom (whole arena, pit as a dark shape), gameplay zoom over the pit, and a
mid-fall frame (a bouncer dropping into the void) — send all three.
