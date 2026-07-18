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
| `characters/bouncer_{color}_squash.png` (x6) + `bouncer_{color}_charge.png` (x6) | SHIPPED | ART PASS #2 complete 2026-07-11 (art bible §3): squash landing + horns-forward super-charge per hero. AD graded FIX→SHIP: Billy charge re-rolled (read tan at zoom → brighter orange, beard cut), 4 squashes re-generated flame-free (a flame on a landing was a logic error + muddied color reads), all-six-alive gate passed (poses_allsix_spread2.png). Logged next-regen: Puff's charge horn larger than her tiny-tips spec. Wiring: Player.gd 3-pose priority swap (squash bounce-window > charge super-aim+0.35s launch > idle); charge = the kill move's readability upgrade. Gen note: text-referencing earlier chat attachments works (no clipboard); watch style bleed between consecutive heroes (Vex squash came out Puff-colored once — re-roll with explicit NOT-color exclusions). |
| `ui/circuits/crest_{meadow_mile,scrapworks,high_wire,the_foundry,mayhem_mile}.png` (x5) | SHIPPED | Circuit crest emblems (audit brief §3.7): gold-shield heraldic badges, subjects per frontend_visual_polish §3c + Foundry = crucible/gear pour on iron-charcoal. AD graded 2026-07-11: 4x Ship + Foundry re-rolled once (style bleed: inherited High Wire's tightrope; re-gen with explicit NO-rope + darker field). Loaded by ArenaSelect crest_<circuit_id> (existence-guarded). Same defringe intake as portraits. |
| `ui/modes/mode_trials.png` | SHIPPED (v10 de-clocked) | Replaced 2026-07-11: stopwatch + checkered flag removed via surgical ChatGPT edit (v10 killed the clock); goal chevron added. EDIT GOTCHA x2: edit outputs bake the checkerboard opaque (keyout --tol 45) AND enclosed regions (ring interior) keep checker remnants the corner flood can't reach — cleared via a grayish-opaque mask pass. AD: Ship. |
| `ui/portraits/portrait_{pogo,butch,ziggy,puff,vex,billy}.png` (x6) | SHIPPED | CharacterSelect beauty-pose busts (docs/briefs/character_select_busts.md), art-director SHIP all six 2026-07-11. Three-quarter front, ornate bone horns, waist-up-ish. Gen: brief §4 recipe (idle attached per hero + shared framing clause); raws in tools/out/portrait_*_raw.png. INTAKE GOTCHA: generations bake dark RGB junk into transparent px (invisible composited, but bilinear filtering bleeds halos) — defringed via normalized-convolution color bleed (scratchpad intake_portrait.py pattern) before trim. Pogo runs hotter magenta than the idle (accepted; re-roll only if a flair recolor narrows the Pogo–Vex gap). |
| `world/grass/body_std.png` | SHIP-CANDIDATE | 1284x243, 3-slice 22/56/22, plain middle |
| `world/grass/platform_wide.png` | hero-only | 914x335 whole-sprite (mid flowers = unsliceable) |
| `world/tiers/mat_*.png` (x4) | SHIP-CANDIDATE | tier mats per brief; 3-slice 18/64/18; legend check passed |
| `objects/cannon.png` | SHIP-CANDIDATE | 2026-07-17 rideable-cannon body (trials circuit 4); whole toy rocks around its mount in Cannon.gd (BAKED_ANGLE -30deg, PIVOT_FRAC 0.44/0.55); graded in-game on p4_cannon_school |
| `objects/key.png` | SHIP-CANDIDATE | 2026-07-17 gold key collectible (trials circuit 2); drawn centred by aspect in KeyToken (halo/flash stay code VFX); graded in-game on n2_locksmith |
| `objects/door_tile.png` | SHIP-CANDIDATE | 2026-07-17 vault-panel TILE (full-bleed 488px, alpha flattened opaque, 6px edge crop); KeyDoor tiles it w x h; gold lock ring stays code telegraph |
| `ui/circuits/crest_trials_*.png` (x4) | SHIP-CANDIDATE | 2026-07-17 trials circuit crests (campaign/navigation/soccer/physics), gold-shield style matched to the brawl crests (meadow crest attached as ref); rendered-verified on the trials PICK YOUR CIRCUIT shelf. crest_trials_varied + crest_trials_orbit PENDING |
| `objects/moon.png` | SHIP-CANDIDATE | 2026-07-18 cratered toy planetoid (853x846, real alpha, chocolate outline); GravitySource "moon" visual draws it at body_r*2.08 (round bounce body); rendered-verified on Twin Moons — replaces the code-drawn circles (owner: no SVG-looking art) |
| `objects/black_hole.png` | SHIP-CANDIDATE | 2026-07-18 gold/violet candy accretion swirl (893x825, real alpha); GravitySource "black_hole" visual spins it at ~0.5 rad/s, dark core sized to the event-horizon collider (core_r*4.4 span); rendered-verified on Singularity |
| `bg/painting_space_nebula.png` | SHIP-CANDIDATE | 2026-07-18 PAINTED BACKDROP (1536x1024 opaque full-bleed, NO alpha — painterly no-outline exception). Indigo nebula + 2 pale moons, horizon glow ~0.58, abyss to near-black. ArenaRenderer PAINTINGS manifest; wired to singularity/twin_moons/spires/g6_*/bumper_gauntlet(+tint). Owner: "no svg, 100% ai gen"; replaces the code sky-gradient + green void |
| `bg/painting_ember_foundry.png` | SHIP-CANDIDATE | 2026-07-18 PAINTED BACKDROP; smoky foundry cavern + amber furnace glow, horizon ~0.55; foundry_*/meltdown_box/p4_chain_reaction |
| `bg/painting_dusk_gold.png` | SHIP-CANDIDATE | 2026-07-18 PAINTED BACKDROP; blue->violet->golden-amber horizon ~0.60, canyon depth; the_ascent/convoy/twin_chasms |
| `bg/painting_overcast_quarry.png` | SHIP-CANDIDATE | 2026-07-18 PAINTED BACKDROP; grey overcast quarry terraces + crane, horizon ~0.58, grey pit depth; hammer_arena/wrecking_yard/hazard_yard/minefield/gauntlet_*/course_04/t_hammer_* |
| `ui/victory_rays.png` | SHIP-CANDIDATE | 2026-07-18 ceremony gold radial sunburst (785x821, real alpha); VictoryScreen RAYS_PATH, spins behind the winner bust; rendered-verified |
| `world/bodies/body_space_rock.png` | SHIP-CANDIDATE | 2026-07-18 THEMED PLATFORM BODY (3-slice 22/56/22, real alpha, ~1468x243); dark indigo basalt + crystal-facet caps + rocky lip. ArenaRenderer BODIES manifest, auto-derived on space_nebula levels. Replaces grass body (owner: no grass floating in space) |
| `world/bodies/body_foundry_steel.png` | SHIP-CANDIDATE | 2026-07-18 THEMED BODY; riveted warm gunmetal plate (distinct from bumper grey), rivets at ends; ember_foundry levels |
| `world/bodies/body_quarry_stone.png` | SHIP-CANDIDATE | 2026-07-18 THEMED BODY; warm-grey layered stone + shelf lip + end pebbles; overcast_quarry levels AND dusk_gold (warm-tinted #E8C79E to sandstone via DUSK_BODY_TINT) |
| `bg/interior_arena_stadium.png` | SHIP-CANDIDATE | 2026-07-18 ENCLOSED INTERIOR (1536x1024 opaque); dark team-neutral night stadium (blurred crowd, dim floodlights, teal pitch band). ArenaRenderer INTERIORS manifest, drawn behind the sealed court; sheen+vignette kept on top. All sports courts |
| `bg/interior_silo_cavern.png` | SHIP-CANDIDATE | 2026-07-18 ENCLOSED INTERIOR (1536x1024 opaque); dark charcoal silo/cavern + light shaft, near-black edges; drop_chamber |
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

- 2026-07-17 objects batch (ChatGPT, style_north_star attached): cannon = "cartoon toy CANNON ... chunky rounded steel barrel with glossy navy-blue metal bands and rivets, wide round muzzle ring ... on a small steel pivot ball mount. little gold star emblem" + base suffix, wide landscape. First take baked a dark backdrop panel INSIDE the subject bbox (corners were transparent so keyout can't reach it) — the fix was a regen asking for "ZERO background ... every pixel outside the cannon fully transparent", which worked. key = "cartoon golden KEY ... big circular bow with a star-shaped hole, thick shaft, two fat square teeth" + suffix. door_tile = "square VAULT DOOR PANEL tile ... TILING texture segment, plain and evenly repeating, no keyhole, plate fills the ENTIRE square edge to edge" (then 6px edge crop + alpha flatten for seamless tiling).
