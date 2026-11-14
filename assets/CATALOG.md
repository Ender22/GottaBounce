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
| `ui/circuits/crest_trials_*.png` (x6) | SHIP-CANDIDATE | 2026-07-17 trials circuit crests (campaign/navigation/soccer/physics) + 2026-07-19 crest_trials_orbit (ringed periwinkle planet + orbiting moon + jetpack blob slingshot) & crest_trials_varied ("whole toolbox": ball/spiked mallet/toy cannon/cracking crate/gold key burst, warm red glow), gold-shield style matched to the brawl crests (physics crest attached as ref); 1022x1329 opaque. orbit/varied rendered-verified on the PICK YOUR CIRCUIT shelf (QA 2026-07-19: both show painted crest, not fallback plate) |
| `ui/skull.png` | SHIP-CANDIDATE | 2026-07-19 dead-player HUD icon (128x124, real alpha); glossy cream toy skull, dark eye sockets, chocolate outline. Replaces the 4-Panel code-drawn skull in PlayerCard.tscn (Skull node is now a TextureRect, stretch KEEP_ASPECT_CENTERED). No style ref (avoid bouncer-face bleed). QA 2026-07-19: renders crisp on dimmed dead cards |
| `ui/ghost.png` | SHIP-CANDIDATE | 2026-11-14 WK-37b dead-card ghost HUD icon (A3/E12), sibling of ui/skull.png. 130x132 real alpha (128 + 2 px pad); glossy cream sheet ghost, 3-bump scalloped hem, big dark round eye holes, small "O" mouth, two bone goat-horn nubs, chocolate outline. ONLY ui/skull.png attached as ref (no bouncer: face bleed). Checked at 128/48/24 px beside the skull on a dimmed card: same family at a glance, reads ghost not skull (hem). Horns lean slightly devil-curved; watch at R8 |
| `world/earth_tile.png` | SHIP-CANDIDATE | 2026-07-19 seamless TILEABLE cartoon earth/soil (1254x1254 opaque; verified 2x2 no-seam). Warm-brown packed dirt + embedded rocks/pebbles/roots, glossy toybox, even density, no border/grass. For the FLOATING-ISLANDS world rework: platform bodies tile this to full collider height (replaces the ugly void gradient). Generated NO style-ref (a tiling texture must have no outline/border seams) |
| `ui/modes/mode_dropshot.png` | SHIP-CANDIDATE | 2026-07-19 DROPSHOT mode-card diorama (1013x681, real alpha, transparent bg); teal Bouncer spiking a beach ball over a volleyball net, mode_sports attached as style ref. Wired into ModeSelect.MODE_ART -> the DROPSHOT card shows it instead of the "D" glyph. Rendered-verify PENDING |
| `objects/ball_beach.png` | SHIP-CANDIDATE | 2026-07-19 DROPSHOT bespoke beach ball (709x689, body ~705px, real alpha); classic red/white/blue/yellow panels + white cap, glossy, chocolate outline. Ball.gd BEACH_TEX; configure_dropshot sets use_beach_tex + drops the warm tint (sprite carries its own colours). Replaces the tinted soccer ball; rendered-verified on Dropshot Beach |
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
| `fx/ko_blast_{core,column,ring,star}.png` (x4) | SHIP-CANDIDATE | 2026-11-14 WK-22 KO blast layers for WK-23 screen-edge KO (brief docs/briefs/ko_blast_2026-11-14.md). TINTABLE: greyscale white/light-grey + chocolate outline, real alpha, code tints to victim colour (modulate works; gradient-map shader keeps more gloss). core 768x765 POW starburst+cloud; column 603x1024 jagged upward blast plume + debris, origin at bottom-centre (rotate to fire inward from the edge); ring 752x768 puffy shockwave donut, transparent hole + 6 shards; star 512x439 puffy star-KO twinkle w/ glints. One ChatGPT chat, text-only (clipboard locked, no style ref attached), family prompt = 'greyscale only so the game can tint it ... thick dark-chocolate outline ... no glow haze, no text'. Column rejected twice: fused fan read as a scallop shell; separated pointed blades read as a cannabis leaf -> fixed by 'ONE single jagged explosion plume ... NOT a leaf/plant/fan'. Defringed (RGB junk in alpha-0 px incl. a baked dark-red glow) before resize. Tint test tools/out/ko_blast_tint_test.png. AD rendered-frame approval PENDING (WK-23); watch: green-tinted upright column can read as a fir tree |
| `fx/ghost_puff.png` + `fx/ghost_puff_stroke.png` + `fx/ghost_puff_dash.png` | SHIP-CANDIDATE | 2026-11-14 WK-37b ghost puff cloud (brief docs/briefs/ghost_goats_2026-11-14.md A1/E6/E7). All three 1216x557, PIXEL-ALIGNED same canvas: body art 1024 px wide (2.8:1) + a deliberate 96 px transparent margin on every side (room for the stroke; `art.py check` "untrimmed margins" is expected). Map 1024 body px -> 180 world px (canvas = 213.75 world px wide). Body: greyscale marshmallow cloud, 3 big top bumps + end bumps, tiny chocolate dot-eyes + "o" mouth, chocolate outline. stroke/dash = WHITE, tint via modulate (owner colour). Derived deterministically by `python tools/puff_outline_derive.py assets/fx/ghost_puff.png <stroke> <dash> --n 13`: stroke = Euclidean alpha dilation 80 src px minus body alpha (= 6.5 screen px at zoom 0.46); dash = stroke x 13 dashes @ 55 % duty spaced by ARC LENGTH with cuts perpendicular to the stroke (brief said ~14 angular: an angular mask gave sunburst rays and 14 gives 9.4 px dashes < the 10 px floor; 13 -> 10.1 px long, 8.3 px gap). TINT NOTE for the programmer: plain fx_tint fills the whole cloud with owner colour (body luma ~0.92 < fx_tint's 0.93 white knee) = "pink-filled", which the brief's section 4 / R6 forbids; tint test row "puff keep-white" shows the intended read (fx_tint, then luma >= 0.80..0.88 reverts to the authored greyscale) -> needs a white-keep threshold uniform or an untinted body draw. Style refs attached via clipboard: style_north_star + ko_blast_core. Tint test tools/out/ghost_tint_test.png. AD rendered-frame approval PENDING (WK-37b R5/R6) |
| `fx/ghost_tail.png` | SHIP-CANDIDATE | 2026-11-14 WK-37b ghost tail (A2/E4). 666x1004 real alpha, TINTABLE greyscale + chocolate outline. One smooth comma/teardrop: wide dome top (root hides under the hem), tapers to a hooked curl tip to the RIGHT (mirror with facing). Not smoke, not strands, not a flame. Same chat as ghost_puff. Drawn with the ghost shader (outline -> rim); emulation row in the tint test |
| `fx/word_burst.png` | SHIP-CANDIDATE | 2026-11-14 shared WK-37b/WK-53 shout burst (A4/E14). 772x649 real alpha, TINTABLE greyscale + chocolate outline, TEXT-FREE (BAAA! is Lilita One in-engine), big empty middle, ~9 fat ROUNDED spikes + short tail down-left (pivot the wobble near the tail tip). v2 of 2: v1 (sharp pointed spikes, kept at tools/out/ghost_raw/word_burst_v1.png) read as a POW/explosion starburst = confusable with fx/ko_blast_core, so re-asked for "soft rounded nubs ... friendly shout balloon, not an explosion". Same chat as ghost_puff |
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

- 2026-11-14 WK-37b ghost goats (ChatGPT, clipboard WORKED this time via STA PowerShell SetImage + Ctrl+V): exact
  prompts = brief docs/briefs/ghost_goats_2026-11-14.md section 6 A1/A2/A4 (tintable clause + base suffix with the
  composition swap), all three in ONE chat with style_north_star + ko_blast_core attached ("same family as the attached
  effect"); A3 ghost icon in its own chat with only ui/skull.png (upscaled to 512 for legibility) attached. word_burst
  revision prompt: "FATTER, ROUNDER spikes: 8-10 chunky spikes whose tips are soft rounded nubs (like a squishy toy),
  not sharp points, so it reads as a friendly cartoon shout balloon and not an explosion". All four came back with REAL
  alpha (no checkerboard) but ~253 alpha inside the body + a faint low-alpha dark haze ring and black RGB in alpha-0 px:
  intake = `python tools/fx_intake.py <dl> <dest> --width/--maxdim N [--pad P]` (haze clean beyond 7 px of the solid
  body, alpha>=240 -> 255, normalized-convolution defringe before AND after the Lanczos resize, trim, pad).
