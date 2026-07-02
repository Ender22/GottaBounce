# Asset Catalog — bespoke generated art

Every non-placeholder asset: what it is, how it was made, status. Prompts matter — they are the
"source code" of the art. Style tag: **Glossy Toybox** (see docs/VISION.md).

| Asset | Status | Notes |
|-------|--------|-------|
| `reference/style_north_star.png` | reference | v1 title screen; the style bible image |
| `reference/logo_v1.png` | reference | v1 logo (untrimmed; regenerate for launch) |
| `characters/bouncer_pink_idle.png` | SHIP-CANDIDATE | 761x526, real alpha. First-gen hero test |
| `characters/bouncer_{blue,green,yellow}_idle.png` | SHIP-CANDIDATE | consistent species, P2-P4 |
| `characters/bouncer_pink_squash.png` | SHIP-CANDIDATE | 805x284 landing pose |
| `world/grass/body_std.png` | SHIP-CANDIDATE | 1284x243, 3-slice 22/56/22, plain middle |
| `world/grass/platform_wide.png` | hero-only | 914x335 whole-sprite (mid flowers = unsliceable) |
| `world/tiers/mat_*.png` (x4) | SHIP-CANDIDATE | tier mats per brief; 3-slice 18/64/18; legend check passed |
| `world/bumper_post.png` | SHIP-CANDIDATE | 208x1003 vertical 3-slice |
| `world/trampoline_blue.png` | prop | standalone trampoline prop (NOT the tier mat) |
| `bg/sky_grass_day.png` | SHIP-CANDIDATE | 1672x941 opaque, layer-1 sky |
| `bg/hills_far.png` | SHIP-CANDIDATE | 1536x222 strip, transparent top, layer 2 |
| `bg/cloud_a.png` | SHIP-CANDIDATE | 854x515 soft, no outline, layer 3 |
| `world/grass/decals/tuft_a.png`, `flower_white.png` | SHIP-CANDIDATE | scatter decals |

Intake gotchas learned: some generations bake a FAKE checkerboard bg instead of alpha —
`art.py check` catches it; fix with `art.py keyout --tol 40`. ChatGPT viewer download flow:
click image → viewer → download icon top-right; verify Downloads timestamp BEFORE intake
(a missed click silently reuses the previous download).

## Prompt patterns that work (ChatGPT image gen)
- Base style suffix (append to every sprite prompt): *"Style: high-quality glossy cartoon game
  art, thick clean dark-chocolate outlines, vibrant saturated colors, soft plastic-toy shine
  highlights. IMPORTANT: fully transparent background (alpha PNG) - no sky, no ground, no shadow,
  just the single subject centered with empty space around it. Square image."*
- Characters: "cute round blob creature… side view facing right, [pose]. Glossy [COLOR] ball with
  two big white cartoon eyes, huge open happy smile, tiny stubby arms, two small stubby feet,
  chunky metallic-orange toy JETPACK strapped to its back with two little rocket nozzles."
- bouncer_pink_idle exact prompt recorded in git history of this file.
- For pose variants: attach the existing sprite and ask for "the same exact character, same style, now [pose]".
- Intake: `python tools/art.py trim <dl> <dest>` then `check`. Keyout only if alpha missing.
