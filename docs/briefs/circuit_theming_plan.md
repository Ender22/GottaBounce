# BRIEF — Circuit Theming Plan ("reads varied", affordably)

**Art Director** · 2026-07-04 · Glossy Toybox bar · Scope-fenced: BACKDROP / PALETTE / READ ONLY.
Companion to `docs/briefs/enclosed_interior_backdrop.md` (which added the reusable `backdrop:"enclosed"`
mode) and `docs/specs/v1_level_circuit.md` (the ~11-level roster). Fulfils the owner directive
`docs/feedback/owner_2026-07-04_arena_variety.md` §1: *"different levels can have different STYLES/
gimmicks"* over the shared off-screen-kill through-line.

---

## 0. The core problem (verified against `src/systems/ArenaRenderer.gd` + the four themed levels)

The circuit currently **plays** varied (distinct kill-shapes) but **looks** monotone. `islands_void`
(flagship) and `the_spine` are both `theme:"grass"` + the default meadow backdrop, so they render the
same sunny-meadow parallax despite very different geometry. `drop_chamber` proves distinctness is
achievable — `backdrop:"enclosed"` makes it unmistakable.

**Why palette alone does nothing today (the load-bearing fact):**
- `ArenaRenderer._build_background()` paints the meadow stack **unconditionally** whenever the PNGs
  exist: Layer 1 = `SKY_TEX` (`bg/sky_grass_day.png`, z −95), Layer 2 = `HILLS_TEX` (z −90), Layer 3 =
  clouds + code twinkles (z −85), Layer 4 = bushes/fences (z −80).
- The only level-driven sky knobs, `sky_top`/`sky_bottom`, feed **only** the Layer-0 code gradient
  (z −100) — which the meadow PNGs paint completely over. So on a meadow level, changing the sky hexes
  is invisible (the enclosed brief already documented this at §3).
- Platform **bodies** are hardcoded to grass (`BODY_TEX`/`HERO_TEX` constants — the JSON `theme` field
  is not yet wired to body art). Tier **mats** and the **void** treatment are theme-agnostic *by
  contract* (same mat = same bounce everywhere; the code-drawn chasm reads as death on any level).

**Consequence:** the only cheap per-level differentiator is the **BACKGROUND STACK**. There are exactly
two background modes today — `meadow` (grass PNGs, ignores palette) and `enclosed` (code gradient +
gloss + vignette, honours palette). That is why we have exactly two distinct looks.

**The single highest-leverage move:** add ONE more reusable, code-drawn backdrop mode — an **open-sky**
mode that (like `enclosed`) suppresses the meadow PNGs and lets `sky_top`/`sky_bottom` + a couple of
code atmospherics define the look. Once it exists, **most of the circuit is themed by PALETTE alone**
(pure JSON, no art, no code per level). Grass platform bodies + mats + void stay shared — which is what
keeps readability constant and cost near-zero.

---

## 1. Per-level VISUAL IDENTITY table

All 11 levels keep the shared toybox anchors (chunky **grass-topped** platform bodies, the four
theme-agnostic tier mats, the code-drawn teal→navy void). Distinctness comes from **backdrop mode +
sky palette** only. `sky_*` are candidate values — final hexes are tuned at grade-time from in-engine
screenshots (§4).

| # | Level | Mood / palette name | backdrop mode | sky_top → sky_bottom (candidate) | Distinct at a glance |
|---|---|---|---|---|---|
| 1 | `islands_void` (flagship) | Sunny archipelago | `meadow` (keep) | `#2e6cb0 → #bfe6ff` (PNG covers) | Bright blue sky + green hills + clouds — the one true meadow |
| 2 | `grassy_expanse` | Overcast plains | `open_sky` | `#8FA9BE → #DCE6EC` | Flat pale grey-blue, no hills — a lazy hazy day, clearly NOT the punchy flagship |
| 3 | `drop_chamber` | Dark sealed drum | `enclosed` (keep) | `#101F2A → #0A1720` | Dim mossy-teal interior + vignette — indoors, contained |
| 4 | `twin_chasms` | Golden-hour canyon | `open_sky` + horizon glow | `#46599C → #F2B15E` | Cool top, warm amber lower sky — canyon at sunset |
| 5 | `the_spine` | High thin sky | `open_sky` | `#14386E → #8FC2E6` | Deep saturated blue, no scenery — a ridge alone in the upper sky |
| 6 | `wrecking_yard` | Smoggy yard | `open_sky` (clouds off) | `#6E6A63 → #B8AE9E` | Grimy grey-brown haze — industrial, no cheer |
| 7 | `the_ascent` | Climb into dusk | `open_sky` (strong vertical) | `#212E52 → #C56A4E` | Dark top → warm low: you climb toward a dark lid |
| 8 | `the_cliff` | Bright morning mesa | `open_sky` | `#6FA8D6 → #F3EFDF` | Airy high-key pale sky — wide-open bright |
| 9 | `atoll` | Tropical lagoon | `open_sky` | `#17A0B8 → #CFF2E6` | Turquoise/teal — a sunny coral crater |
| 10 | `bumper_gauntlet` | Arcade cabinet | `open_sky` (or `enclosed`-tint) | `#2A1E4E → #5B3A8C` | Deep violet — a neon pinball table |
| 11 | `spires` | Twilight void | `open_sky` (stars on) | `#101830 → #3A3E66` | Dark indigo + starry twinkles — the deepest, most cosmic |

That is: 1 meadow, 1 enclosed, 8–9 open-sky (differentiated by palette + two optional atmospherics).
No two are confusable at a glance, and every one keeps the grass-toy platforms so the game stays one
coherent world (Glossy Toybox, one theme family, many skies).

---

## 2. Art-cost classification (A / B / C) per level

### A — CHEAP (achievable NOW, params alone; mode already exists)
- **`islands_void`** — `meadow` (already the flagship look). No change. **Done.**
- **`drop_chamber`** — `enclosed` (already built + graded). No change. **Done.**

Nothing else is genuinely category-A today, *because* palette does nothing under `meadow` (§0). The
moment the one open-sky mode below ships, all the (B) levels below become **A-equivalent** — themed by
editing `backdrop` + `sky_top`/`sky_bottom` in JSON, zero art, zero per-level code.

### B — MEDIUM (needs ONE small reusable renderer mode; then palette-only per level)
Every remaining level is themed by the same **one** new code-drawn mode + a distinct palette. No
generated art. The mode is spec'd in §3.

- **`grassy_expanse`, `the_spine`, `the_cliff`, `atoll`** — `open_sky`, palette only.
- **`twin_chasms`, `the_ascent`** — `open_sky` + the optional **horizon-glow** param (one code gradient
  band) for the warm-lower-sky dusk read. Palette + one boolean/hex.
- **`wrecking_yard`** — `open_sky` with the optional **clouds-off** flag (smog reads cleaner without
  cheerful puffs). Palette + one boolean.
- **`spires`** — `open_sky` with **stars on** (just keep the existing code twinkles, brighter, over a
  dark palette — they already read as stars). Palette + one boolean.
- **`bumper_gauntlet`** — `open_sky` deep-violet (primary, cheapest). *Optional upgrade:* reuse
  `enclosed` with a param-tinted Zone-B (a second tiny reusable tweak, §3.3) for a true "cabinet
  interior." Ship the open-sky version first.

### C — EXPENSIVE (GENERATED tile/backdrop ART — flag only, do NOT do now)
Distinct platform **materials** (ice / lava / metal / stone / coral) require: (a) wiring the JSON
`theme` field to a body-art lookup in the renderer (currently `BODY_TEX`/`HERO_TEX` are hardcoded
grass), and (b) a generated tileset per theme (body strip + hero + decals + likely a matching void wall
skin). That is a real art-generation project, not a palette tweak.

**Reserved as a later hero-level upgrade only** (1–2 levels max, after the cheap rollout ships):
- `wrecking_yard` → rusted-metal / oil-drum platform bodies + scrap props (best payoff — the industrial
  read wants hard materials, and the smog palette is a placeholder for it).
- `atoll` → sandstone/coral bodies (tropical material payoff).
- (`the_ascent` / `spires` → stone spires) — third-tier, only if we want a stone hero.

Do NOT assume any (C) work now. The (A)+(B) plan gets the whole circuit to "reads varied" without it.

---

## 3. Renderer work the programmer must add (minimal, reusable, code-drawn)

### 3.1 The ONE required addition — `backdrop:"open_sky"` mode
Add a branch in `ArenaRenderer._build_background()` mirroring the existing `enclosed` early-return
pattern (the code path is already proven). When `backdrop == "open_sky"`:
1. **Suppress the meadow PNG layers:** skip Layer 1 (`SKY_TEX`), Layer 2 (`HILLS_TEX`), Layer 4
   (props/fences). (These are what make every meadow level identical.)
2. **Let the Layer-0 gradient BE the sky:** keep the existing `grad_rect = brect.grow(pad)` gradient
   (z −100) driven by `sky_top`/`sky_bottom` — it already covers the full frame at every zoom, with no
   seam. This is the whole point: `open_sky` makes the palette knobs finally do something.
3. **Keep Layer 3 code atmospherics:** keep the **code twinkles** (they cost nothing and read as
   stars on dark palettes / faint sparkle on bright ones). Keep the **code clouds** by default.

That is roughly a dozen lines — no new assets, no per-level code. It is the single change that unlocks
8–9 levels of variety.

### 3.2 Optional `open_sky` params (small, all code-drawn — add if cheap, skip if not)
Each is a lean, reusable knob read only in the `open_sky` branch. None are required for a first Ship;
they sharpen specific levels.
- **`clouds` (bool, default true):** false = skip the cloud drifters (used by `wrecking_yard` smog,
  `spires` void). Trivial.
- **`horizon_glow` (hex, optional):** one soft additive band low in the frame (a `GradientTexture2D`
  linear/radial sprite, same toolkit as `paint_void`/`enclosed`) — sells dusk/golden-hour
  (`twin_chasms`, `the_ascent`). ~10 lines, reusable.
- **`stars` (bool/int, optional):** brighten/multiply the existing twinkles on dark skies (`spires`,
  `bumper_gauntlet`). Reuses the twinkle code — near-zero cost.

### 3.3 Optional second reusable tweak (defer — for `bumper_gauntlet` upgrade only)
Parameterize the `enclosed` Zone-B interior tint (currently hardcoded mossy-teal `#2C4A44…#18332F`) so
`enclosed` can also read as a violet "arcade cabinet" or a brown "cave" via a level param. Reusable, but
NOT needed for the cheap rollout — `bumper_gauntlet` ships fine on `open_sky` violet first.

**Everything above is gradients/polygons (the same toolkit `paint_void` and `_build_enclosed_interior`
already use), so it adapts to any level size and needs zero generated art.**

---

## 4. Prioritized recommendation — cheapest-first rollout

**Step 1 (programmer, one small task): add `backdrop:"open_sky"`** per §3.1. Optionally the §3.2 params
(`clouds`, `horizon_glow`, `stars`) in the same pass — all tiny. This is the only code needed to theme
the whole circuit.

**Step 2 (data only — level JSON edits, art-director grades):** set `backdrop` + `sky_top`/`sky_bottom`
per the §1 table. No geometry, no art. Reuse map:
- `meadow` (exists): **islands_void** only.
- `enclosed` (exists): **drop_chamber** (+ **bumper_gauntlet** optionally, later).
- `open_sky` (the one new mode): **grassy_expanse, twin_chasms, the_spine, wrecking_yard, the_ascent,
  the_cliff, atoll, bumper_gauntlet, spires** — 9 levels, palette-differentiated.

**Step 3 (grade):** capture each level in-engine at far + combat zoom (`python tools/gbplay.py
screenshot`) and tune the exact `sky_*` hexes against the readability rules in §5. Do NOT trust the
candidate hexes blind — they are starting points; final values are graded from screenshots.

**Step 4 (RESERVED, optional, later):** one or two hero (C) levels get generated material tilesets
(`wrecking_yard` metal, `atoll` coral). Only after the cheap circuit reads varied and only if we want a
showcase level. Not part of getting to "reads varied."

Net cost to a fully varied 11-level circuit: **one small renderer mode + JSON palette edits.** No art-
generation project.

---

## 5. Fence + readability (Pillar 5 — non-negotiable)

**Scope fence:** BACKDROP / PALETTE / READ ONLY. Do NOT touch any gameplay geometry, collider, bounds,
void rect/placement, `kill_shape`, lethality, tuning/feel constant, platform tier, or spawn. If any of
those would move to achieve a look, STOP and re-brief. Platform bodies stay grass, mats stay
theme-agnostic, the void treatment stays shared — changing them is the (C) project, not this plan.

**Readability is the hard constraint.** Players are four saturated blobs (rose-pink, mid-blue, lime-
green, bright-yellow) with chunky orange jetpacks, thick chocolate `#3B241B` outlines, and white
cartoon streaks. A backdrop must keep a **value gap** from all four player hues; when in doubt, go
**darker / desaturated** — bright outlined players pop hardest against mid-to-dark, low-chroma skies.
Grade every palette at combat zoom with all four colors on screen; if any player washes out, adjust the
sky (never the player art) before Ship.

**Risky palettes to watch (call-outs):**
- **`the_spine` (deep blue) — blue bouncer vs blue sky.** Keep `sky_top` dark/low-chroma enough that the
  mid-blue bouncer separates by value; the chocolate outline helps but is not sufficient alone. Highest
  readability risk in the set — grade it hardest.
- **`twin_chasms` / `the_ascent` / `the_cliff` (warm/amber lower sky) — yellow bouncer wash.** The warm
  band sits low, right where players fight. Keep the amber more orange/desaturated than the bouncer's
  pure yellow, and value-separate. `horizon_glow` must stay a soft accent, not a bright wall behind the
  play line.
- **`atoll` (turquoise) — green bouncer vs teal.** Hue-adjacent; the green/cyan split + outline usually
  holds, but verify P2 (lime) at zoom.
- **`islands_void` meadow (existing) — green bouncer vs green hills.** Already flagged in the enclosed
  brief; this plan does not fix it (out of scope), but note that moving the OTHER levels off meadow to
  cooler/darker open skies *improves* green-bouncer readability circuit-wide.
- **Safe by construction:** `wrecking_yard` (neutral grey), `drop_chamber` / `spires` / `bumper_gauntlet`
  (dark) — dark, low-chroma backdrops make all four players pop. Prefer these where a level can take it.

**Twinkles/clouds as stars:** keep them small and dim so they never compete with players for attention;
they are atmosphere, not foreground.
