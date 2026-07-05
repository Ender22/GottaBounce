# Asset Catalog — bespoke generated art

Every non-placeholder asset: what it is, how it was made, status. Prompts matter — they are the
"source code" of the art. Style tag: **Glossy Toybox** (see docs/VISION.md).

| Asset | Status | Notes |
|-------|--------|-------|
| `reference/style_north_star.png` | reference | v1 title screen; the style bible image |
| `reference/logo_v1.png` | reference | v1 logo (untrimmed; regenerate for launch) |
| `characters/bouncer_pink_idle.png` | SHIP-CANDIDATE | POGO (pink pygmy-goat, MASCOT). Goat/ram roster art pass #1, 2026-07-05 |
| `characters/bouncer_blue_idle.png` | SHIP-CANDIDATE | BUTCH (blue bighorn ram, curled horns) |
| `characters/bouncer_green_idle.png` | SHIP-CANDIDATE | ZIGGY (green ibex, backswept horns) |
| `characters/bouncer_yellow_idle.png` | SHIP-CANDIDATE | PUFF (yellow fluffy sheep, cloud-fluff silhouette) |
| `characters/bouncer_purple_idle.png` | SHIP-CANDIDATE | VEX (purple markhor, spiral horns) — P5 |
| `characters/bouncer_orange_idle.png` | SHIP-CANDIDATE | BILLY (orange billy goat, beard) — P6 |
| _(squash/charge poses)_ | ART PASS #2 | goat squash + horns-forward super-charge poses pending; old pink-blob squash retired |
| `world/grass/body_std.png` | SHIP-CANDIDATE | 1284x243, 3-slice 22/56/22, plain middle |
| `world/grass/platform_wide.png` | hero-only | 914x335 whole-sprite (mid flowers = unsliceable) |
| `world/tiers/mat_*.png` (x4) | SHIP-CANDIDATE | tier mats per brief; 3-slice 18/64/18; legend check passed |
| `world/bumper_post.png` | SHIP-CANDIDATE | 208x1003 vertical 3-slice |
| `world/trampoline_blue.png` | prop | standalone trampoline prop (NOT the tier mat) |
| `bg/sky_grass_day.png` | SHIP-CANDIDATE | 1672x941 opaque, layer-1 sky |
| `bg/hills_far.png` | SHIP-CANDIDATE | 1536x222 strip, transparent top, layer 2 |
| `bg/cloud_a.png` | SHIP-CANDIDATE | 854x515 soft, no outline, layer 3 |
| `world/grass/decals/tuft_a.png`, `flower_white.png` | SHIP-CANDIDATE | scatter decals |

| `powerups/icon_*.png` (x7) | SHIP-CANDIDATE | mega_bounce, unlimited_boost, star, counter_shield, ball_storm, black_hole, ring_of_fire — briefs in docs/specs/v1_powerups.md |
| `world/spikes_strip.png` | SHIP-CANDIDATE | 987x254 hazard row, repeating |
| `fx/puff_soft.png`, `fx/star_sparkle.png` | procedural | PIL-generated particle sprites |
| `bg/bush_round.png`, `bg/fence_wood.png` | SHIP-CANDIDATE | layer-4 mid props |
| `hazards/hammer.png` | SHIP-CANDIDATE | glossy steel mallet, yellow/black hazard band, chocolate handle — wired into SpinningHammer.gd |
| `hazards/bomb.png` | SHIP-CANDIDATE | glossy black cartoon bomb + lit fuse — wired into Bomb.gd (reused by landmine) |
| `hazards/crusher.png` | SHIP-CANDIDATE | 774x657 metallic press block, hazard chevrons + rivets — wired into Crusher.gd (two mirrored heads) |
| `hazards/wrecking_ball.png` | SHIP-CANDIDATE | 689x772 charcoal iron sphere, rivet ring + top eyelet — falling_debris body (eyelet decorative; collider = sphere) |
| `hazards/flatbed_cart.png` | SHIP-CANDIDATE | 1143x412 rideable toy cart, orange hazard-stripe body + 4 chunky wheels, flat metal standing deck — moving_platform vehicle skin |
| `objects/ball.png` | SHIP-CANDIDATE | 669x642 white glossy sports ball, bold gold equator seam ring — Ball.gd (sports) body |
| `objects/crate.png` | SHIP-CANDIDATE | 912x877 honey-wood breakable crate, steel corner brackets + X-brace — DestructibleBlock.gd body (keyout'd fake checkerboard, tol 45) |
| `objects/token.png` | SHIP-CANDIDATE | glossy gold star coin — Pickup.gd (Trials COLLECT_ALL) token |
| `ui/modes/mode_brawl.png` | SHIP-CANDIDATE | 1000x576 pink+blue goats clashing horns mid-air + impact star — ModeSelect BRAWL card art |
| `ui/modes/mode_trials.png` | SHIP-CANDIDATE | 936x732 green goat rocketing through a ring + stopwatch/flag — ModeSelect TRIALS card art |
| `ui/modes/mode_gauntlet.png` | SHIP-CANDIDATE | 978x776 purple markhor goat defiant vs a horde of glowing-eyed silhouettes — ModeSelect GAUNTLET card art |
| `ui/modes/mode_sports.png` | SHIP-CANDIDATE | 1184x902 orange goat headbutting the gold-seam ball into a net + grass pitch — ModeSelect SPORTS card (keyout'd fake checkerboard, tol 45) |

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
