# Art Brief — Themed Platform Bodies + Enclosed Interior Backdrops

> Author: Art Director. Status: APPROVED FOR BUILD. Scope: ONE build session.
> Owner direction (2026-07-18): the painted backdrops shipped and look great, but the
> PLATFORMS still wear grass art (green top + brown dirt) on every theme — a grassy ledge
> floating in the space nebula / the ember foundry reads as a bug. AND the enclosed
> courts/sports arenas got no painted background last pass. Owner: **"do both."**
> Extends `docs/briefs/arena_rendering.md` (still the law for 3-slice / mats / diorama) and
> `docs/briefs/painted_backdrops_2026-07-18.md` (the painting manifest/knob pattern this reuses).
> Nothing here touches the tier MATS — the gameplay contract stays theme-agnostic.

---

## The two problems (owner diagnosis, confirmed in code)

1. **One grass body everywhere.** `ArenaRenderer.gd:12` hardcodes
   `const BODY_TEX := "res://assets/world/grass/body_std.png"`. `_platform_body()` (line 709)
   feeds that single texture into every bodied platform on every level — so a bright-green
   grass ledge with brown dirt floats in front of the space nebula and the foundry furnace.
   The tier mat on top is correct (theme-agnostic by design); it's the BODY under the mat and
   the grass DECALS (tufts/flowers) that are miscast off-grass.
2. **Enclosed arenas are unpainted.** `backdrop:"enclosed"` levels render via
   `_build_enclosed_interior(play_rect)` (line 319): a code-drawn dim teal vertical gradient +
   white gloss sheen + radial vignette, clipped to the play AABB. No painting. The 10 sealed
   levels (all `levels/sports/*` + `sports_court` + `drop_chamber`) look like the same teal drum.

Both fixes reuse the **painted-backdrops pattern**: a small const manifest keyed by id →
texture path + params, a per-level JSON knob, graceful fallback to today's look if a file is
missing. No new tools, no shaders.

---

# PART A — THEMED PLATFORM BODIES

## A.0 What "themed platform" means (and what it must NOT touch)

The body is the **chunky block UNDER the mat** — grass-top + dirt strip today. It:

- 3-slices horizontally (**bodies 22% caps / 56% center**, per `arena_rendering.md §1`),
- snaps its art height to canonical **H64 / H128** (`_canonical_height`, line 705 — vertical
  stretch of painterly bodies is banned),
- bleeds **~12 world px above the collider** (`BODY_BLEED_TOP`) and **8 px past the sides**
  (`BODY_BLEED_SIDE`) — this ~12px top fringe is the ONLY part of the body that pokes above
  the mat, so it is the part that carries the theme read.

**The tier MATS stay untouched.** `TIERS` (`ArenaRenderer.gd:24`, mats
marshmallow/bubblegum/trampoline/spring + bumper) are the GAMEPLAY CONTRACT: *same mat = same
bounce everywhere in the game.* Do NOT retint or re-theme mats. "Themed platforms" =
**a themed BODY texture per theme, swapped by a manifest/knob; mats unchanged.**

## A.1 The body set — 3 new + grass = covers everything

Minimal, matched to the four painted open-sky themes (grass keeps `body_std`):

| Body id | File | Covers (levels with this `backdrop_painting`) | Notes |
|---|---|---|---|
| `grass` | `world/grass/body_std.png` — **SHIPPED, keep** | all meadow + grass-day open_sky | default; grass decals ON |
| `space_rock` | `world/bodies/body_space_rock.png` — NEW | `space_nebula`: singularity, twin_moons, spires, g6_*, bumper_gauntlet, p4_swing_shot | dark cratered/crystal rock |
| `foundry_steel` | `world/bodies/body_foundry_steel.png` — NEW | `ember_foundry`: foundry_* ×4, meltdown_box, p4_chain_reaction | riveted industrial steel |
| `quarry_stone` | `world/bodies/body_quarry_stone.png` — NEW | `overcast_quarry`: hammer/gauntlet/mine grey levels **AND** `dusk_gold`: the_ascent, convoy, twin_chasms (via warm tint) | grey layered rock; dusk warm-tints it to sandstone |

**Dusk decision (the "reuse one" saving):** `dusk_gold` reuses `quarry_stone` with a warm
`body_tint` modulate (~`#E8C79E`) so grey layered rock reads as sandstone/canyon at golden
hour, matching the dusk painting + its warm wall triple. This keeps us to **3 new generations**
instead of 4. GRADE THIS SPECIFICALLY (§A.5): if warm-tinted quarry reads muddy against the
gold painting, the follow-up is a dedicated `body_canyon` — not a reason to hold this session.

**Enclosed levels are out of Part A** — their bodies stay `grass` this session (the mat +
Part-B interior carry the read; the small grass strip under a sealed sports floor is mostly
hidden and low-priority). Flagged for follow-up in §B.4.

## A.2 The top fringe per theme (this is the make-or-break read)

The mat sits on top; only the body's **~12px fringe** pokes above it. On grass that fringe is
the blade overhang. Per theme the fringe must read as the theme's own lip — **never grass:**

- **space_rock:** a **rough rocky lip** — a few small angular rock chips / a crystal facet or
  two catching cool top-left light. No blades, no organic overhang.
- **foundry_steel:** a **bevelled steel edge** — a clean bright top chamfer with 1–2 rivet
  heads near the ends. Machined, not organic.
- **quarry_stone:** a **flat stone shelf lip** — a slightly lighter weathered top course, a
  couple of small rounded pebbles at the very ends only.

## A.3 Void walls + decals (also grass-coded — handled)

- **Void walls** (the receding dirt strata, `_void_wall` line 1028) are **already themed** —
  they draw from `_void_palette` wall triple (`wall_top/wall_deep/wall_strata`) which the
  painted-backdrops manifest already carries per theme (space=indigo rock, foundry=dark iron,
  quarry=grey stone). **No change needed** — reference `PAINTINGS` in `ArenaRenderer.gd:59-80`.
  Confirm at grade time the wall hues sit under the new body hues without a seam.
- **Grass decals** (tufts `_scatter_back_tufts` line 772, flowers `_scatter_end_decals` line
  792) are grass-only art. **Suppress them on non-grass bodies.** The body manifest carries a
  `grass_decals: true` flag ON only for `grass`; themed bodies render bare. The center-slice
  repetition is then broken by the themed body's own end detail + rockier surface (that's why
  each themed body's ends carry distinctive chips/rivets/pebbles — §A.4). Themed decals
  (rock chips, ember sparks) are a nice-to-have, explicitly OUT of scope this session.

## A.4 The art orders — 3 sliceable body strips

Each: gen **1536×1024**, subject ≈ **1400×430**, transparent PNG, 3-slice **22/56/22**, lit
**top-left**. **Append the base style suffix verbatim** (CATALOG.md / `arena_rendering.md §4`):

> *"Style: high-quality glossy cartoon game art, thick clean dark-chocolate outlines, vibrant
> saturated colors, soft plastic-toy shine highlights. IMPORTANT: fully transparent background
> (alpha PNG) - no sky, no ground, no shadow, just the single subject centered with empty space
> around it."*  (drop "Square image." — these are wide strips; say **"Wide landscape composition."**)

**The quiet-middle clause is CRITICAL and non-negotiable in every prompt** — it is what makes
the 3-slice tiling invisible:
> *"IMPORTANT: the middle section of the platform must be plain and evenly repeating — no unique
> rocks, no cracks, no decorations in the middle; keep all distinctive details near the two ends."*

### 1. `world/bodies/body_space_rock.png`
Palette: basalt body `#2A2A44`, crater/underside shadow `#14142A`, cool crystal facets
`#4A4E86` / faint teal glint `#3E7E82`, lit top lip `#4C4C6A`. (Harmonizes with the
space_nebula wall triple `#3A3A5E/#0B0C22/#17173A`.) **No magenta.**
> "A long wide chunky floating space-rock platform for a cartoon game, side view: a solid slab
> of dark indigo-basalt rock (#2A2A44) with smooth rounded cartoon boulders below, a few small
> cool-violet crystal facets (#4A4E86) catching light near the ends, and a rough rocky top lip
> with small angular chips (NOT grass, no plants). The left and right ends are rounded rocky
> caps with a crystal shard poking out. The rock is mid-value, not black, lit from the top-left."
> + quiet-middle clause + base style suffix + "Wide landscape composition."

### 2. `world/bodies/body_foundry_steel.png`
Palette: gunmetal body `#5A5150` (WARM steel, see readability flag §A.6), dark underside
`#2E2826`, bright bevel/rivet highlight `#9A9088`, sparing rust streak `#6E4A30`. (Harmonizes
with foundry wall triple `#5A3320/#1C0E06/#2A1408`.) **No safety-orange; any warmth stays deep
and dull.**
> "A long wide chunky industrial steel platform for a cartoon game, side view: a riveted warm
> gunmetal steel plate body (#5A5150) with a bright bevelled top edge, a row of round rivet
> heads (#9A9088) near the two ends only, a couple of faint warm rust streaks (#6E4A30), and a
> dark shadowed steel underside (#2E2826). The left and right ends are rounded machined caps.
> Machined and solid, lit from the top-left. No plants, no grass, no bright orange."
> + quiet-middle clause + base style suffix + "Wide landscape composition."

### 3. `world/bodies/body_quarry_stone.png`
Palette: warm-grey stone body `#7C7468` (lean beige, see §A.6), strata lines `#4E4A42`, top
shelf course `#948C7E`, rounded end boulders. (Harmonizes with quarry wall triple
`#6A6258/#22201A/#33302A`; dusk reuses via `#E8C79E` warm tint.)
> "A long wide chunky layered quarry-stone platform for a cartoon game, side view: a solid slab
> of warm grey sedimentary rock (#7C7468) with a few horizontal strata lines (#4E4A42), a flat
> weathered stone top shelf (#948C7E, NOT grass), and rounded cartoon boulders and small pebbles
> at the two ends. Left and right ends are rounded stone caps. Solid and calm, lit from the
> top-left. No plants, no moss." + quiet-middle clause + base style suffix + "Wide landscape composition."

## A.5 3-slice acceptance criteria (before code touches the file)

1. Real alpha (`python tools/art.py check`), trimmed, no baked shadow/background.
2. **Middle 56% is plain and evenly repeating** — eyeball it; if any unique chip/crack/rivet
   sits mid-span, regenerate with the reminder (do NOT hand-patch — `arena_rendering.md §4` rule).
3. **Caps don't stretch** — the distinctive detail lives in the outer 22% only, so uniform-scale
   caps never shear it.
4. **Top ~12px fringe reads as the themed lip** (rocky chips / steel bevel / stone shelf), NOT
   grass — hold the strip and squint at just the top band.
5. **Lit top-left, no directional detail that breaks under tiling** (no cast shadow implying a
   fixed light across the span); center must survive being tiled N× with no mirror-flip.
6. Chocolate outline present on the body silhouette (it is a gameplay-layer object).

---

# PART B — ENCLOSED INTERIOR BACKDROPS

## B.0 Code facts (confirmed)

`_build_enclosed_interior(play_rect)` (`ArenaRenderer.gd:319`) draws three code sprites sized
to `shell = play_rect.grow(16)`:

- **Zone-B teal gradient** (`#2C4A44 → #21403C → #18332F`), z **-92** — the flat "wall".
- **Gloss sheen** (soft white radial highlight upper-centre), z **-91** — the curved-plastic tell.
- **Vignette** (transparent → `#0A1720` a0.45 corners), z **-91** — sells cylinder curvature.

Everything ABOVE the lid / OUTSIDE the walls stays the Layer-0 dark housing gradient for free
(these sprites only cover `shell`). No painting today.

## B.1 The interior set — 2 paintings covers all 10 enclosed levels

| Interior id | File | Covers |
|---|---|---|
| `arena_stadium` | `assets/bg/interior_arena_stadium.png` — NEW | `sports_court` + all `levels/sports/*` (dropshot_beach, hammer_yard, long_haul, minefield, the_bowl, the_crusher, the_box, the_scrapheap) = 9 levels |
| `silo_cavern` | `assets/bg/interior_silo_cavern.png` — NEW | `drop_chamber` |

These are **OPAQUE full-bleed paintings** (same asset class as the backdrops: NO alpha, do not
run `check`'s transparency test — use `art.py info`), **painterly, NO outlines, muted**, that
read as **"the wall behind the sealed arena."**

## B.2 Integration — painting BEHIND the plastic shell (keep sheen + vignette on top)

Add an `INTERIORS` manifest (const dict, mirrors `PAINTINGS`) and a per-level knob
`"interior_painting": "arena_stadium"`. In `_build_enclosed_interior`:

- When `interior_painting` is set and the file loads: **draw the painting instead of the flat
  teal gradient**, as a plain Sprite2D **stretched to fill the `shell` rect** (`centered=false`,
  `position = shell.position`, `scale = shell.size / tex_size` — the exact sizing the teal
  gradient uses via `_gradient_sprite`, so it never bleeds past `shell` into Zone-A and needs no
  clip node), z **-93** (behind where the teal was).
- **KEEP the gloss sheen (z-91) and vignette (z-91) UNCHANGED, drawn ON TOP of the painting.**
  This is deliberate: the code sheen+vignette give the sealed-plastic-drum curvature read and
  adapt to any box AABB — baking them into the painting would fight the toybox plastic tell and
  lock one aspect ratio. Painting = the wall; sheen+vignette = the plastic drum over it.
- **Drop the flat teal gradient sprite when a painting is present** (the painting replaces it).
- **Fallback:** `interior_painting` absent, unknown, or file missing → `_warn_once` + **exactly
  today's teal/sheen/vignette look** (the existing graceful-skip pattern; never a black screen).

Because the painting is **stretched to fit** the shell (not scaled-to-cover), both paintings
must be composed to survive **±20% horizontal stretch** — soft, centred-symmetric, no crisp
verticals (§B.5). Sports courts are wide (~1.75:1 interior); drop_chamber is near-square.

## B.3 The art orders — 2 interior paintings

**Append the painterly interior suffix verbatim** (the painted-backdrops background pattern —
no outline clause, no transparency clause):
> *"Soft dreamy painterly style with NO outlines anywhere, muted and less saturated than
> foreground cartoon game art, low detail density, no characters, no text, no borders.
> Full-bleed wide landscape composition filling the entire image."*

### `interior_arena_stadium.png` — gen ≈1536×1024, OPAQUE
Palette: deep cool slate stands `#2A3038`, blurred crowd speckle in **team-NEUTRAL** greys/tan
`#4A4E56` / `#6E645A`, dim warm-white floodlight glows high `#E8E0C8` (low intensity), dark
teal-green pitch band low `#24382E`. **Dark-ish overall so the ball + players pop.**
> "A vast zoomed-out painted interior of a sports stadium at night, seen from pitch level as a
> soft dark backdrop for a cartoon game: dim tiered crowd stands in deep cool slate greys
> (#2A3038) receding into shadow, the crowd only a soft low-contrast speckle of neutral grey and
> tan (no bright colors, no team colors, no red, no blue), a few soft warm-white floodlight
> glows high up (#E8E0C8) that do not flare, and a dark teal-green pitch band low across the
> bottom (#24382E). Everything muted, dark and out of focus so nothing reads as a solid object.
> Team-neutral, calm, low detail." + painterly interior suffix.

### `interior_silo_cavern.png` — gen ≈1024×1024 (near-square), OPAQUE
Palette: dark stone/concrete `#2C2A2E`, cool teal-grey echo `#21403C` (matches the shipped
interior so it harmonizes), faint vertical light shaft `#3A4A46`, near-black edges `#0A1720`
(so the vignette blends). drop_chamber is a drum with a lethal bottom hole — a cavern shaft
reads perfectly.
> "A vast zoomed-out painted interior of a deep industrial silo / rock cavern for a cartoon game:
> curved dark stone-and-concrete walls in charcoal (#2C2A2E) with a cool teal-grey cast
> (#21403C), one or two faint soft vertical light shafts falling from above (#3A4A46), and the
> walls fading to near-black at the left, right and bottom edges (#0A1720). Damp, quiet,
> low-detail, no ledges or openings that look like a floor, no characters. Muted and dark."
> + painterly interior suffix.

## B.4 Enclosed platform bodies (flag, not this session)

Sports floors are `trampoline` (mat covers most of the body) and walls are `bumper` (no body),
so the grass strip under a sealed floor is small. It stays `grass` this session. **Follow-up
candidate:** give the industrial sports variants (hammer_yard, the_crusher, the_scrapheap,
minefield) a `quarry_stone` or `foundry_steel` body via the same `platform_body` knob once the
stadium interior is graded — a one-line-per-JSON change, no new art. Not blocking.

## B.5 Interior acceptance criteria

1. **Opaque full-bleed**, no alpha, no outlines anywhere (a single outline = auto-Reject).
2. **Survives ±20% horizontal stretch** — soft, centred-symmetric, boring near the side edges.
3. **Dark enough that a light ball + outlined players pop** in front of it (grade in-game, §B.6).
4. **Stadium is team-neutral** — zero red or blue crowd bias (a false team read on a soccer
   pitch is a gameplay lie = auto-Reject).
5. **No false gameplay silhouette** — no shape in either painting reads as a platform, ledge,
   goal, ball, or player. Crowd = blur; cavern = no standable-looking ledges.
6. Reserved-color scan by eye: no bubblegum magenta `#FF4FA3`, no safety orange `#FF6A2A`, no
   royal-blue `#2F6BD8` + golden-yellow `#FFD23F` pair, no hazard-red `#E6402C`.

---

## Integration points for the programmer (design intent, not code)

| Where (`src/systems/ArenaRenderer.gd`) | Change |
|---|---|
| `const BODY_TEX` (line 12) | Keep as the grass default + last-ditch fallback (used by `_mat_texture` line 733 and `_paint_bumper` line 754 "never a flat polygon" stand-ins). Add a `BODIES` const manifest: id → `{ path, cap_frac:0.22, tint (opt), grass_decals:bool }`. |
| `setup(json)` (line 111) | Resolve `_body_id` once: `json["platform_body"]` if present, else derive from `backdrop_painting` (space_nebula→space_rock, ember_foundry→foundry_steel, overcast_quarry→quarry_stone, dusk_gold→quarry_stone+warm tint, meadow_day/absent→grass). Store the resolved `{path, tint, grass_decals}` as a member. **Zero new JSON edits for painted open-sky levels — they already carry `backdrop_painting`.** |
| `_platform_body()` (line 709) | Take the resolved body path/tint instead of the hardcoded `BODY_TEX`. Only use `HERO_TEX` (grass `platform_wide`, has mid-span flowers) when body id == `grass`. Apply `body_tint` modulate for dusk. |
| `paint_platform()` (line 634) | Gate `_scatter_back_tufts` (682) + `_scatter_end_decals` (700) on the body's `grass_decals` flag — no grass tufts/flowers on themed bodies. |
| `_void_wall` / `_void_palette` (lines 1028 / 142) | **No change** — already themed from the `PAINTINGS` wall triple. Verify at grade. |
| `_build_enclosed_interior()` (line 319) | Add `INTERIORS` manifest + `interior_painting` knob. When set: draw painting (stretched-to-fill `shell`, z-93) IN PLACE OF the teal gradient; KEEP sheen (z-91) + vignette (z-91) on top; fallback to today's teal on missing/absent. |

---

## ART ORDERS (generate these — 5 total)

| # | File | Type | Prompt (one line — full prompt + palette in §A.4 / §B.3) |
|---|---|---|---|
| 1 | `assets/world/bodies/body_space_rock.png` | body strip, 3-slice 22/56/22, transparent | dark indigo-basalt platform, cool crystal facets at ends, rough rocky top lip, quiet middle |
| 2 | `assets/world/bodies/body_foundry_steel.png` | body strip, 3-slice 22/56/22, transparent | warm gunmetal riveted steel plate, bevelled top edge, rivets at ends only, quiet middle |
| 3 | `assets/world/bodies/body_quarry_stone.png` | body strip, 3-slice 22/56/22, transparent | warm-grey layered quarry stone, strata lines, flat stone shelf top, pebbles at ends, quiet middle |
| 4 | `assets/bg/interior_arena_stadium.png` | opaque full-bleed painting, no alpha/outline | dark team-neutral night stadium interior, blurred crowd, dim floodlights, ball/players must pop |
| 5 | `assets/bg/interior_silo_cavern.png` | opaque full-bleed painting, no alpha/outline | dark cavern/silo interior, curved stone walls, faint light shafts, near-black edges |

**Scope: 3 body strips + 2 interior paintings = 5 generations, one focused build session.**
Dusk reuses body #3 (warm-tinted) → no 4th body. Enclosed levels keep grass bodies (flag §B.4).

---

## Readability-pillar flags (pillar 5 — mats stay legible, no false silhouettes)

1. **Bodies stay subordinate to mats.** The mat is the loud gameplay contract; every themed body
   must be quieter (lower contrast, no motif that competes with a mat's silhouette). If a graded
   frame lets a body out-shout its mat, the body is too busy → Fix.
2. **Foundry steel vs. the bumper grey.** Bumpers are *"the only grey interactive object"*
   (`arena_rendering.md §2`). The steel body must lean **warm gunmetal**, clearly distinct from
   the cool bumper grey `#98A1AF`, so a steel platform-body is never mistaken for a bumper wall.
   The chocolate-outline + bright mat on top separate them, but keep the hue distinct too.
   Likewise quarry stone leans **warm beige**, not pure grey.
3. **Space rock stays mid-value, not black** — a near-black body swallows player silhouettes;
   players carry chocolate outlines + contact shadows, but the body must not be a black hole.
4. **Interiors must not create false gameplay silhouettes** (§B.5 #5) and must stay dark enough
   that the ball + 4 players read at gameplay zoom (§B.5 #3). If a painting is too bright/busy
   behind the action, the PAINTING gets darkened/simplified — never the players or the ball.
5. **Stadium team-neutrality is load-bearing** — any red/blue crowd bias on a two-goal soccer
   pitch is a false team-side read = auto-Reject.

---

## Grading plan (Ship / Fix / Reject — from in-game screenshots only)

Capture per new asset via `python tools/gbplay.py screenshot`:

- **Themed bodies** — one representative level each, far zoom + close zoom:
  twin_moons (space_rock), foundry_smelter (foundry_steel), hammer_arena (quarry_stone),
  the_ascent (quarry_stone warm-tinted for dusk). Check: no grass anywhere on the platform,
  themed lip reads at the fringe, no slice seam / stretched cap / mirror-flip mid-span, body
  quieter than its mat, void walls seamless under the new body.
- **Interiors** — sports_court + one industrial sports variant (the_crusher) for `arena_stadium`,
  drop_chamber for `silo_cavern`, all with 4 players (and a ball on the courts) spawned. Check:
  no seam where the painting meets the Zone-A housing, sheen+vignette still sell the plastic drum,
  ball + players pop, team-neutral, no false silhouettes, fallback exercised once (rename a file →
  warn + today's teal).

**Auto-Reject:** any grass on a themed platform; a body that out-reads its mat; a steel body that
reads as a bumper; any outline in an interior painting; red/blue team bias in the stadium; a
visible seam at the enclosed painting's edge; a painting so bright/detailed the ball or players
get lost.
