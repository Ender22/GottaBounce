# Asset Catalog — bespoke generated art

Every non-placeholder asset: what it is, how it was made, status. Prompts matter — they are the
"source code" of the art. Style tag: **Glossy Toybox** (see docs/VISION.md).

| Asset | Status | Notes |
|-------|--------|-------|
| `reference/style_north_star.png` | reference | v1 title screen; the style bible image |
| `reference/logo_v1.png` | reference | v1 logo (untrimmed; regenerate for launch) |
| `characters/bouncer_pink_idle.png` | SHIP-CANDIDATE | 761x526, real alpha. First-gen hero test |

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
