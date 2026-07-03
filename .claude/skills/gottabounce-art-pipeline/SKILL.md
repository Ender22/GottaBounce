---
name: gottabounce-art-pipeline
description: >
  Load this skill when generating, intaking, processing, or grading art for GottaBounce —
  any task mentioning "generate a sprite", "new asset", "ChatGPT image", "art.py",
  "trim/keyout/check", "tier mat", "Glossy Toybox", "art brief", "grade the art",
  "sprite/asset readability at gameplay zoom", "goat horns", "aim-pose sprite", "CATALOG.md", or "placeholder art".
  Do NOT load it for renderer/ThreeSlice code architecture (see skill
  gottabounce-architecture-contract), for launching the game to take grading screenshots
  (see skill gottabounce-run-and-playtest), or for writing brief/spec documents themselves
  (see skill gottabounce-docs-and-writing).
---

# GottaBounce Art Pipeline — Glossy Toybox production system

**What this covers:** the complete art production loop — brief → generate (ChatGPT via
Chrome) → process (`tools/art.py`) → grade (in-game screenshots) → intake
(`assets/` + `CATALOG.md`) — plus the style prompts that work, the tier-readability color
system, three-slice art rules, far-zoom math, and the current asset inventory with its gaps.

**When NOT to use this:**
- How `ArenaRenderer.gd`/`ThreeSlice.gd` work internally → skill `gottabounce-architecture-contract`.
- Running the game / capturing screenshots (`run_game.ps1`, `gbplay.py`) → skill `gottabounce-run-and-playtest`.
- What counts as QA evidence, verdict discipline → skill `gottabounce-validation-and-qa`.
- Environment setup (Python/Pillow, Chrome, Godot exe) → skill `gottabounce-build-and-env`.

---

## 1. The style: "Glossy Toybox" and why it exists

Defined in `docs/VISION.md` ("Art direction — Glossy Toybox") and locked by a DECISIONS.md
entry (2026-07-02). The look of the generated v1 title screen
(`assets/reference/style_north_star.png` — the style bible image), applied to everything:

| Element | Rule |
|---|---|
| Characters | round blob critters ("Bouncers"): big faces, tiny limbs, chunky jetpacks. Sphere-shaped **so the circle collider matches the art** and squash/stretch reads huge |
| World | saturated high-contrast toy-world: glossy trampolines, candy springs, grass-topped platforms, soft painterly skies |
| VFX | thick white cartoon streaks, star pops, confetti; bold silhouette readability |
| UI | chunky rounded cards, glossy bevels, oversized type; never OS-default widgets |

**Why this style (not just taste):** blobs are the most consistently AI-generatable character
shape; poses are cheap variations; the style stays coherent across ChatGPT generations when a
reference sheet is attached. Chosen for appeal AND reliable AI generatability (DECISIONS.md
2026-07-02). Any proposal to leave this style must go through change control (see skill
`gottabounce-change-control`) — the goat-identity evaluation (§8) is the worked example.

**The two load-bearing visual tricks** (from `docs/briefs/arena_rendering.md`):
1. **Outline = "you can touch this."** Every interactive object gets a thick dark-chocolate
   `#3B241B` outline. Backgrounds get NO outline and are cooler/softer. That contrast IS the
   depth read.
2. **Readability beats prettiness** (VISION pillar 5). Every asset must survive gameplay zoom
   (see far-zoom math, §7).

---

## 2. The 5-step pipeline

From `docs/PIPELINE.md` §2, proven across ~31 bespoke assets:

| Step | Who (role) | What |
|---|---|---|
| 1. Brief | art-director | subject, silhouette, palette hexes, size, transparent bg, style refs attached. Real examples: `docs/briefs/arena_rendering.md`, powerup icon briefs inside `docs/specs/v1_powerups.md` |
| 2. Generate | operator via ChatGPT in Chrome | attach style ref + prior sprites of the same character; always demand transparent background (§3–§4) |
| 3. Process | `tools/art.py` | trim margins, validate alpha, downscale; never hand-place an untrimmed generation (§5) |
| 4. Grade | art-director | reviews the processed sprite **IN GAME via screenshot, never in isolation**; verdicts Ship / Fix (numbered items) / Reject (§7) |
| 5. Intake | operator | `assets/<category>/<name>.png` + entry in `assets/CATALOG.md` (§6) |

Placeholder policy (PIPELINE.md §2.5): CC0 Kenney placeholder use is allowed ONLY as
explicitly-tagged temp with a replacement task. The old project's kit sits in
`assets/placeholder/` — nothing in the live game should use it untagged.

---

## 3. Prompts that work (the "source code" of the art)

All from `assets/CATALOG.md` (prompts are recorded there because they ARE the source).

**Base style suffix — append to EVERY sprite prompt, verbatim:**

> "Style: high-quality glossy cartoon game art, thick clean dark-chocolate outlines, vibrant
> saturated colors, soft plastic-toy shine highlights. IMPORTANT: fully transparent background
> (alpha PNG) - no sky, no ground, no shadow, just the single subject centered with empty
> space around it. Square image."

(The copy in `docs/briefs/arena_rendering.md` §4 omits the final "Square image." — for
landscape/portrait subjects like mats and bumper posts, drop it and state the composition,
e.g. "Wide landscape composition" / "Tall portrait composition".)

**Character prompt template** (CATALOG.md):
> "cute round blob creature… side view facing right, [pose]. Glossy [COLOR] ball with two big
> white cartoon eyes, huge open happy smile, tiny stubby arms, two small stubby feet, chunky
> metallic-orange toy JETPACK strapped to its back with two little rocket nozzles."

**Pose/variant technique** (this is how consistency is achieved): attach the existing sprite
and ask for *"the same exact character, same style, now [pose]"*. Same trick for asset
families ("the same exact bumper, same style, now as a long horizontal block").

**Sliceable bodies/mats — the quiet-middle rule:** every 3-sliceable asset is generated with a
deliberately *plain, evenly repeating* middle (no flowers, no unique rocks mid-span) — say so
in the prompt ("IMPORTANT: the middle section must be plain and evenly repeating … keep all
distinctive details near the two ends"). Uniqueness comes back via code-scattered decals.
Mats additionally share one camera phrase so all four sit identically:
*"long horizontal bouncy platform surface, straight-on side view, uniform height, flat top you
can stand on, wide landscape composition, middle section evenly repeating with no unique
details"*.

**Backgrounds are the exception:** painterly, soft, explicitly **"NO outlines"**, less
saturated than gameplay art; use only the transparency clause of the base suffix, not the
outline clause (worked prompts: `hills_far`, `cloud_a` in `docs/briefs/arena_rendering.md` §4).

**Style reference file:** `assets/reference/style_north_star.png`.
DOC DRIFT (2026-07-03): `docs/PIPELINE.md` §2 says to attach `assets/reference/style_sheet.png`
— that file does not exist; `style_north_star.png` is the real one.

---

## 4. Generation runbook: ChatGPT via Chrome

1. **Start Chrome BEFORE anything else.** The claude-in-chrome extension only connects to a
   running Chrome (hard-won, `docs/STATUS.md` watch-list).
2. Open ChatGPT, attach `assets/reference/style_north_star.png` (plus prior sprites of the
   same character/family for variants), paste the prompt with the base style suffix.
3. Download flow (UNVERIFIED: ChatGPT UI as of 2026-07-03, recorded in CATALOG.md): click the
   generated image → viewer → download icon top-right.
4. **Verify the Downloads-folder file timestamp BEFORE intake.** A missed download click
   silently reuses the *previous* download — this corrupted `hills_far` once (CATALOG.md
   gotcha; the file was regenerated).
5. Stage the raw download in `tools/out/` as `<name>_raw.png` (observed convention:
   `tools/out/bouncer_pink_raw.png`, `body_std_raw.png`, …), then process per §5.

**The fake-checkerboard trap:** some generations bake a FAKE checkerboard "transparency"
pattern into an opaque image instead of real alpha. `python tools/art.py check <file>` catches
it (reports "no transparency at all"); fix with `python tools/art.py keyout <file> --tol 40`.

---

## 5. Processing: `tools/art.py` (verified against source, 2026-07-03)

Requires Pillow — the repo's only pip dependency (see skill `gottabounce-build-and-env`).
Run from repo root. All commands exit 0 on success, non-zero on issues.

| Command | Args | What it does |
|---|---|---|
| `trim` | `IN [OUT]` | crop away fully-transparent margins, +2px padding. OUT defaults to in-place |
| `keyout` | `IN [OUT] [--tol N]` | flood-fill the background color from all four corners → transparent, then auto-trim. Default tol 18; use `--tol 40` for fake checkerboards |
| `resize` | `IN OUT WIDTH` | proportional Lanczos resize to WIDTH px |
| `info` | `IN...` | report size, transparent %, opaque bbox |
| `check` | `IN` | validate: real alpha present? trimmed (max margin ≤12px)? flags large semi-transparent fringe (possible white halo from keying, >5% of pixels at alpha 1–31). Prints `CHECK <file>: OK (WxH)` or numbered ISSUES |
| `sheet` | `IN_DIR OUT COLS` | pack same-size sprites into a row-major sheet (contact-sheet review) |

**Typical intake sequence** (generation has real alpha):
```
python tools/art.py trim tools/out/mynew_raw.png assets/world/grass/mynew.png
python tools/art.py check assets/world/grass/mynew.png
```
If `check` says "no transparency at all": `keyout` first (with `--tol 40` if checkerboard),
which trims automatically. Never hand-place an untrimmed generation.

---

## 6. Intake: where files go and where code consumes them

Convention: `assets/<category>/<name>.png` + a row in `assets/CATALOG.md`. PIPELINE.md asks
for what/prompt/date; observed practice = a status row plus the prompt recorded in
CATALOG.md's "Prompt patterns" section (or git history of that file). Real row format:

```
| `world/tiers/mat_*.png` (x4) | SHIP-CANDIDATE | tier mats per brief; 3-slice 18/64/18; legend check passed |
```

Status vocabulary observed: `reference`, `SHIP-CANDIDATE`, `hero-only`, `prop`, `procedural`.

**Filenames are load-bearing** — code loads by convention or hardcoded constant, and a wrong
name silently no-ops or falls back (each miss has a `push_warning` / `_warn_once`, verified:
static):

| Category | Consumed by | Path pattern |
|---|---|---|
| Characters | `src/entities/Player.gd:160-167` | `res://assets/characters/bouncer_<skin>_idle.png`, `bouncer_<skin>_squash.png` (missing idle → pink fallback + warning; missing squash → silently idle-only) |
| HUD head icons | `src/ui/PlayerCard.gd:36` | `bouncer_<skin>_idle.png` |
| Powerup icons | `src/systems/PowerupSystem.gd:22`, `src/entities/PowerupBubble.gd:40` | `res://assets/powerups/icon_<id>.png` |
| Platform body / sky / hills / clouds / props / bumper | `src/systems/ArenaRenderer.gd:12-21` constants | `world/grass/body_std.png`, `bg/sky_grass_day.png`, `bg/hills_far.png`, `bg/cloud_{a,b}.png`, `bg/{bush_round,fence_wood}.png`, `world/bumper_post.png` |
| Tier mats | `ArenaRenderer.gd` `TIERS` table | `world/tiers/mat_<tier>.png`; missing one mat → marshmallow mat tinted with tier color + warning; ALL missing → tinted grass strip (never a flat polygon) |
| FX particles | `RingOfFire.gd`, `StormBall.gd`, `PowerupSystem.gd` | `fx/puff_soft.png`, `fx/star_sparkle.png` |

**⚠ LIVE PATH MISMATCH (found 2026-07-03, unresolved):** `ArenaRenderer.gd:19-21` expects
`res://assets/world/grass/decal_tuft_a.png`, `decal_tuft_b.png`, `decal_flower_white.png` —
but the files on disk are `assets/world/grass/decals/tuft_a.png`, `tuft_b.png`,
`flower_white.png`. Statically these can't resolve, meaning decal scatter would be skipped
with a one-time warning; yet STATUS session 2 records "Decals/props verified rendering (zero
warnings)", and STATUS's own watch-list says "if not, paths differ (check
assets/world/grass/decals/)". UNVERIFIED: which side is actually live — needs one rendered
run. Do not intake new decals until resolved; fixing either side is a repo change → normal
session through change control, not a skill's job.

---

## 7. Grading doctrine and the readability system

### Grading rules (from `docs/briefs/arena_rendering.md` header + §5, PIPELINE.md §2)
- The art-director grades **in-game screenshots only** — never raw asset files. "The
  programmer implements this verbatim; I grade the result from in-game screenshots only."
- Verdicts: **Ship / Fix (numbered list) / Reject.** Certain failures are automatic: any
  visible flat Polygon2D debug fill = Fix; sideways-rotated grass platform = Reject.
- Standard capture set: **far zoom + close zoom + mid-bounce** (for the mat pulse FX). Capture
  via `python tools/gbplay.py screenshot tools/out/<name>.png` with the game running — see
  skill `gottabounce-run-and-playtest` for launching/driving. Reference frames already on
  disk: `tools/out/grade_far.png`, `tools/out/toybox_close1.png`.
- The arena grading checklist (brief §5, condensed): (1) far-zoom: every tier nameable, 4
  players findable <1s; (2) close-zoom: no slice seams, no stretched caps, tiling invisible
  within 3 tiles; (3) no debug shapes; (4) diorama test: shadows + outline-free cool
  background + visible parallax; (5) color discipline (reserved colors below); (6) everything
  is single generated sprites, no tilesets.

### Far-zoom math (do it BEFORE ordering art)
Dev arena ≈ 3900 world px wide → at 1920 output the far camera is **~0.49 px per world px**
(brief §2). Rules of thumb, as of 2026-07-03:
- Tier mats are 28 world px tall → ~14 screen px. Anything that would drop **below ~10 screen
  px must be simplified, not shrunk** (why each mat has exactly ONE motif, not texture noise).
- Bouncers read ~25–30 px tall at `grade_far.png` zoom on a 1280-wide frame
  (`docs/briefs/art_goat_identity_eval.md` §3) — the face already sits at the legibility
  floor; new head detail must survive that scale or it's noise.
- Lesson already paid for: the fuse ring was invisible at gameplay zoom (≈0.443) until made
  screen-space-width; the same class of mistake applies to any fixed-world-px detail.
  (Incident detail → skill `gottabounce-failure-archaeology`.)
- Note gbplay screenshots are 1280×720 while the viewport renders 1920×1080 — grade with that
  scale factor in mind (details → skill `gottabounce-run-and-playtest`).

### Tier readability table (the color contract — brief §2, implemented in ArenaRenderer TIERS)
Each tier reads through THREE redundant channels: color, silhouette motif, value.

| Tier | Toy | Primary | Support | Motif (reads at 14 screen px) |
|---|---|---|---|---|
| Marshmallow (weakest) | quilted cushion | `#FFF6EC` warm white | `#FFC9DD` pink dust | puffy quilted bumps, matte |
| Bubblegum | glossy gum slab | `#FF4FA3` hot magenta | `#FF8AC5` gloss | rounded melty blobs, wet shine |
| Trampoline | toy trampoline | rim `#2F6BD8` blue | canvas `#FFD23F` yellow | segmented rim + X-stitch canvas (only two-color band) |
| Spring (strongest) | coil row | bar `#FF6A2A` safety orange | coils `#D9DEE7` silver | zigzag coils under a bar (only tier with silhouette gaps) |
| Bumper (not a tier) | foam post | `#98A1AF` grey | `#F4F6F9` studs | rounded post with glossy studs — the ONLY grey interactive object |

- **Outline `#3B241B` dark chocolate, thick, mandatory on every interactive piece.** Never on
  backgrounds (outline = touchable is the depth trick).
- Value ramp at a squint: white → hot pink → blue/yellow → orange/silver → grey.
- **Reserved colors:** no background or platform body may use `#FF4FA3`-family magenta, safety
  orange, or the blue+yellow rim/canvas pair. Grass flowers stay white/pale-yellow and small.
  Bouncer pink stays rose-leaning (distinct from bubblegum magenta).
- Mat intake acceptance: hold all four mat thumbnails at 64 px wide side by side — if any two
  are confusable at that size, regenerate the offender before code touches it.
- The mat is the gameplay contract: *same mat = same bounce, everywhere, in every theme* —
  mats are theme-agnostic on purpose (players learn 4 toys once).

---

## 8. Three-slice art rules (what generation/intake must respect)

"Three-slice" = a sprite cut into left cap / tiling center / right cap so one asset spans any
width. The runtime builder is `src/systems/ThreeSlice.gd` (algorithm details → skill
`gottabounce-architecture-contract`); these are the rules the ART must satisfy, verified
against code call sites and `docs/briefs/arena_rendering.md` §1:

1. Cap fractions: platform **bodies 22%** per cap / 56% center; **tier mats 18%**/64%/18%
   (verified: `ArenaRenderer.gd` passes `cap_frac` 0.22 for bodies and bumpers, 0.18 for mats).
2. Caps never stretch non-uniformly; center is **TILED, not stretched** — shared correction
   factor clamped **0.85–1.20 per tile, never past 1.25** (add a tile instead); narrower than
   one tile → the quiet center is CROPPED, never squashed (`ThreeSlice.gd` CORR_MIN/CORR_MAX).
3. Never mirror-flip alternate tiles — all art is lit top-left.
4. **Height snapping:** body art snaps to canonical H64/H128 (`ArenaRenderer.gd:388`);
   vertical stretch of painterly bodies is banned. Colliders stay exact; the collider top edge
   is the authoritative surface line.
5. **Slab rule:** platform `h ≤ 48` world px → **no body, the tier mat alone is the platform**
   (`SLAB_MAX_H := 48.0`). A 36px grass smear reads as nothing; the mat reads as a toy.
6. **Never rotate a horizontal platform 90°** for walls — sideways grass + sideways lighting
   is an instant Reject. Walls get their own vertically-3-sliced asset (`bumper_post.png`).
7. Art bleeds past physics on purpose (toys are fluffy): grass fringe ~10–14 world px above
   the collider top, caps ~8 px past the sides; mats sit on the collider top and rise 8 px
   above it (`MAT_RISE`); mats span the FULL collider width — a narrower mat is a readability
   lie and an automatic Fix.
8. Whole-sprite exception: if target aspect is within ±20% of the source's native aspect, skip
   slicing, draw whole with ≤10% non-uniform fudge (`ThreeSlice.build_whole`) — how hero
   one-offs like `platform_wide.png` are used.

Generation-side consequences: sliceable subjects need the quiet-middle prompt clause (§3),
distinctive details near the two ends only, and mats/bodies generated as long strips
(≈1400×260 subject for mats, ≈1400×430 for bodies, per brief §4).

---

## 9. Current inventory and open art work (as of 2026-07-03)

**On disk: 34 bespoke/reference PNGs** (find over `assets/`, excluding `placeholder/`):
5 characters (4-color idle + pink squash), 4 tier mats, grass body + hero platform +
3 decals, bumper post, trampoline prop, spikes strip, 6 backgrounds, 2 fx particles,
7 powerup icons, 2 reference images (`style_north_star.png`, `logo_v1.png` — logo untrimmed,
regenerate for launch). Statuses in `assets/CATALOG.md`. Owner-provided music sits in
`assets/music/` (not generated art). `assets/placeholder/` = old project's CC0 Kenney kit,
temp-only policy per §2.

**Known art gaps / debt:**
- Squash pose exists for pink only; blue/green/yellow silently use idle-only (Player.gd §6).
- STATUS art fix list (small): (a) far-zoom floor mat thin; (b) trampoline-floor "rope" up
  close; (c) tumble rotation reads sideways; (d) wire `fx/puff_soft.png` + `star_sparkle.png`
  into Juice particles; (e) real font asset to replace SystemFont stack in theme.tres;
  (f) art skull icon for PlayerCard; (g) name-tag blink inherit; (h) unlimited-boost flame
  telegraph pass; (i) black-hole vignette.
- Decal path mismatch (§6) — resolve before any new decal work.
- Powerup gaps: no black-hole vignette, unlimited-boost telegraph modest (STATUS session 2).

**GATED — goat identity (ADOPT-STAGED, do NOT build yet).**
`docs/briefs/art_goat_identity_eval.md` + DECISIONS.md 2026-07-03. Verdict: horns are a cheap
on-brand decoration pass (NOT an anatomy/style pivot) that gives the head-first super a
readable weapon tip — but **gated until movement courses validate that super-as-kill-move is
actually fun**. Reject condition: if bounce-chaining, not supers, carries the fun, horns lose
their justification. When un-gated:
- ~**8 required regenerations** (idle + squash × 4 colors, horns added via the attach-prior-
  sprite technique); horns neutral bone `#F2E6D0`-ish with chocolate outline, never
  per-player-color; kept inside the head's bounding capsule (collider-match rule).
- **`bouncer_*_super_aim.png` (aim/frozen-hover pose, 4 colors) is needed REGARDLESS of the
  goat verdict** once the un-charged super ships — the aim state currently reuses idle art.
  Commission it goat-ready to avoid a second pass.
- Required pre-ship test: in-engine screenshot at `grade_far.png`'s exact zoom, all 4 colors
  on screen, horns distinguishable from noise; if they wash out, simplify to one bold
  triangle-horn per side.
- Goat scream SFX is separable audio work, gated only on the (already existing)
  `super_fired` EventBus event, not on horn art.

---

## 10. Symptom → action (art-specific)

| Symptom | Cause | Action |
|---|---|---|
| `check` says "no transparency at all" | opaque generation, possibly fake checkerboard | `python tools/art.py keyout <f> --tol 40` (checkerboard) or default tol (solid bg), re-`check` |
| `check` says "large semi-transparent fringe" | white halo from keying | regenerate with the transparent-bg clause, or tighter `--tol` |
| "Downloaded" file is the previous asset | missed download click silently reused prior file | compare Downloads timestamp BEFORE intake; re-download |
| New asset doesn't appear in game | filename/path doesn't match the consuming constant (§6 table) | grep the path in `src/`, rename to match; check the Godot output for `push_warning` |
| Mat shows but in the wrong color | that tier's mat missing → marshmallow tinted fallback | check `assets/world/tiers/mat_<tier>.png` exists and is named exactly |
| Center of platform looks repetitive | quiet-middle held but decals absent | see §6 decal path mismatch |
| Unique detail visibly repeats mid-span | generation ignored quiet-middle clause | regenerate with the reminder; do NOT hand-patch (brief §4 intake rule) |
| Detail invisible at far zoom | below ~10 screen px | simplify the design, don't shrink; re-do far-zoom math (§7) |
| Wrong bouncer color in game | missing `bouncer_<skin>_idle.png` → pink fallback | intake the color, exact name |

Wider debugging (game won't launch, screenshots black, etc.) → skill
`gottabounce-debugging-playbook`.

---

## Provenance and maintenance

Verified 2026-07-03 against repo HEAD `0e315b9` by reading: `assets/CATALOG.md`,
`docs/PIPELINE.md`, `docs/VISION.md`, `docs/STATUS.md`, `docs/DECISIONS.md`,
`docs/briefs/arena_rendering.md`, `docs/briefs/art_goat_identity_eval.md`, `tools/art.py`
(full source), `src/systems/ArenaRenderer.gd`, `src/systems/ThreeSlice.gd`,
`src/entities/Player.gd` (sprite loading), `src/ui/PlayerCard.gd`, `src/systems/PowerupSystem.gd`,
plus a full `assets/` file listing. No game process was run: all runtime behaviors
(fallback tints, warnings, decal scatter, in-game readability) are **verified: static**.

Re-verification one-liners for drift-prone facts:
- Base style suffix / prompt patterns: `Read assets/CATALOG.md` ("Prompt patterns" section).
- art.py commands/flags: `python tools/art.py` (prints usage) or read `tools/art.py` docstring.
- Style ref filename: `ls "assets/reference/"` (expect `style_north_star.png`).
- Consuming path constants: `grep -rn "res://assets/" src/ --include=*.gd`.
- Decal mismatch still open?: `grep -n "decal_tuft" src/systems/ArenaRenderer.gd` vs
  `ls assets/world/grass/decals/` — if either side changed, update §6.
- Tier hexes / cap fractions: `grep -n "cap_frac\|0.18\|0.22\|TIERS" src/systems/ArenaRenderer.gd`.
- Goat gate status: `Read docs/DECISIONS.md` (top entries) — currently ADOPT-STAGED.
- Inventory count: `find assets -name "*.png" ! -path "*placeholder*" | wc -l` (expect 34).

UNVERIFIED items in this skill:
- ChatGPT web UI download flow (click image → viewer → download icon top-right) — recorded
  from CATALOG.md; the live UI may have changed.
- Whether decal scatter currently renders in-game (§6 mismatch): static evidence says the
  paths cannot resolve; STATUS claims decals verified rendering. Needs one rendered run.
- Far-zoom pixel figures (~0.49 px/world, bouncers 25–30 px, ring zoom 0.443) — taken from
  docs/briefs and STATUS, arithmetic checks out, not re-measured live.
