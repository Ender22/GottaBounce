# BRAWL Arena Expansion — dedicated ~20-arena sets per circuit (2026-07-19)

> **Owner ask:** every BRAWL circuit should own a dedicated set of ~20 arenas (today 3–8 each) so a
> full first-to-10-kills session (~10–15 rounds) rarely repeats a stage and each circuit has a strong,
> escalating identity. This is a **design doc only** — no JSON/code was written. It scopes the build
> phase: keep every existing arena, add the rest. Level designer implements from here.

## How to read this doc
Each circuit section gives its **identity + escalation arc**, then a table of ALL target arenas
(existing marked `[HAVE]`, new marked with an implementation tag). New arenas give: id/filename, a
one-line hook, within-circuit tier (1 = calm on-ramp → 3 = wild peak), a LAYOUT sketch
(bounds width + platform/tier arrangement + hazards + spawn count), backdrop, and an **implementation
tag**. Full coordinates are the build phase's job; the sketch fixes the shape, scale, gap sizes, and
hazard params so a builder can author the JSON directly.

Implementation tags:
- **[JSON-ONLY]** — buildable today from shipped pieces (platforms/tiers/void + the shipped hazard
  object types). No new art or code. **~90% of this plan is JSON-ONLY** and should be built first.
- **[NEEDS-ART]** — wants a NEW `backdrop_painting` (or platform skin) to hit its sub-theme. Every
  such arena has a JSON-ONLY fallback (ship with an existing painting first; swap art later). Art is a
  polish pass, never a blocker.
- **[NEEDS-CODE]** — wants a mechanic we don't have. Kept to a tiny, clearly-flagged set of STRETCH
  arenas; none are required to hit each circuit's realistic target.

---

## Shared build kit (the reusable vocabulary — memorise before authoring)

### Schema (from `src/core/LevelLoader.gd`)
Top-level: `name, version, theme, kill_shape, design_intent, backdrop, clouds, horizon_glow, stars,
sky_top, sky_bottom, bounds{left,right,top,bottom}, platforms[], objects[], backdrop_painting,
interior_painting, painting_tint`.
- **platforms[]**: `{x, y, w, h, tier}`. `x,y` = top-left. Tiers below.
- **kill_shape** (drives QA target, data-only): `central_pit` (demoted mid-floor hole), `void_is_floor`
  (floating islands over a bottom void — the workhorse), `enclosed_hole` (sealed drum, single bottom
  hole), `dual_blast` (walled shaft, lethal UP-lid + DOWN-void).
- **backdrop**: `open_sky` (parallax sky + floating-island look — DEFAULT for new brawl arenas),
  `enclosed` (sealed interior drum), `meadow`.
- Bounds are DERIVED from the platform AABB unless an explicit `bounds` block overrides (needed for
  hand-tuned side runways, low lids, wide voids). Derived margins: side 480–720, top 2650, bottom 670.

### Surface-tier energy dial (`Tuning.bounce_height_*`)
| tier | apex | zero-boost horizontal drift | role |
|---|---|---|---|
| marshmallow | 120px | ~260px | dead/soft landing, damping |
| bubblegum | 180px | ~320px | gentle floor |
| trampoline | 270px | ~395px | the "basic" floor (most islands) |
| spring | 480px | ~527px (**max possible bounce reach**) | the big launch / thrones |
| bumper | reflect ×0.86 | n/a | NON-lethal walls & pinball obstacles; refunds fuel |

### THE flight-required rule (GAME_ESSENCE #1 — every arena MUST pass)
Spring apex = 480px, max spring drift = 527px. So:
- **Any traversal GAP must be > 527px** (proven-good values: **580 / 600 / 620 / 680**) → a bounce can
  never clear it; boost is mandatory. Miss = fall into the void.
- **Any climb to an upper pad must be > 480px** above the nearest surface (proven: **520–560px**) →
  the jetpack is the only way up.
- `normal_boost_max 760` crosses a 680px gap in ~0.9–1.0s (~26 fuel; a bounce refunds +20).
  `super 2800` clears anything but dumps the tank and rises ~2450px straight up.
- **Recovery sky** under every surface ≥ 650px (surface bottom → bottom blast line) so a fuelled
  knock-off is a real recovery gamble, not an instant loss.
Every new arena's `design_intent` MUST carry a movement-tool-per-gap analysis proving the above
(copy the format from `islands_void.json` / `the_cliff.json`).

### The floating-islands look (NEW — all new arenas adopt it)
Platforms render as `earth_tile.png`-tiled floating bodies over a painted `open_sky` (no flat void
gradient). Set `backdrop: "open_sky"`, a `sky_top`/`sky_bottom` gradient, a `backdrop_painting`, and a
full-width `void` object (`{type:"void", ...}`, display-only lethal-floor treatment; the kill is the
bounds-bottom line). Toggle `clouds`, `horizon_glow`, `stars` per mood. No `bounds`-bottom collider —
the void is painted, the blast line kills.

### Shipped hazard object types (all LETHAL via the same `kill(&ring_out)` pipeline unless noted)
- **spinning_hammer** — LETHAL rotor blade. `{pivot{x,y}, arm_len, arc_deg(<360, ~150), period_s,
  phase, radius, head_len, head_w, dwell_frac}`. Telegraphed sweep + apex dwell = the clear beat.
- **crusher** — LETHAL press. `{axis:"vertical"|"horizontal", anvil, center{x,y}, head_len, head_w,
  open_gap, closed_gap, period_s, phase, close_time, closed_time, retract_time, telegraph_lead}`.
  Only kills when a body is truly SQUEEZED (`Tuning.crusher_crush_gap`).
- **bomb** — LETHAL radial blast + knockback. `{trigger:"proximity"|"fuse", x, y, blast_radius,
  kill_radius, trigger_radius|fuse_s, telegraph_lead, recur}`.
- **falling_debris** — LETHAL drops. `{columns:[x,...], floor_y, spawn_y, fall_speed, chunk_radius,
  cadence, telegraph_lead, max_concurrent, start_delay}`. Ground-shadow telegraph before each drop.
- **moving_hazard** (pendulum) — **NON-lethal** directional SHOVE. `{kind:"pendulum", pivot{x,y},
  arm_len, arc_deg, period_s, phase, radius, dwell_frac}`. Flings you (≤700px/s, no hitstun); the void
  is the killer.
- **moving_platform** — **NON-lethal** solid moving deck (carries riders). `{vehicle, center{x,y},
  axis_deg, amplitude, w, h, period_s, phase, dwell_frac}`. Ride it off-stage = void kill.
- **destructible_block** — timed/HP surface that erodes away (footing lost). `{mode:"erode", group,
  break_on:"timed", telegraph_s, x, y, w, h, tier, break_time}`. The collapsing-arena primitive.
- **gravity_source** — radial gravity well + optional planetoid bounce body. `{x, y, radius, g,
  lethal_core_r, visual:"black_hole"|"moon", body_r, tier}`.
- Static **bumper** platforms = non-lethal reflectors (drum shells, pinball posts, ricochet lids).

### Existing `backdrop_painting` assets (reuse freely; new ones are [NEEDS-ART])
`overcast_quarry` (grey industrial), `ember_foundry` (molten), `space_nebula` (deep space),
`dusk_gold` (golden dusk). Sky gradients + clouds/stars/glow flags give large mood range on top of
these four with zero art cost.

### Fair 2–4P spawn rules (every arena)
5 spawn points (supports up to 5-start free-for-all; modes pick N), spread across ≥3 surfaces, none on
a hazard/trigger-ring/under-a-press/under-a-blade, symmetric-ish so no start is a death seat. Include
1–2 elevated spawns on multi-tier arenas. 2–3 `powerup_spawner`s pulling players into contested space.

---

## CIRCUIT 1 — MEADOW MILE  (difficulty 1 · ORDERED loop)
**Identity:** the grassy on-ramp. Bright, open, sky-blue, **NO lethal hazards** (the void is the only
killer). Teaches bounce-chaining, gap-boosting and the recovery gamble on forgiving, wide geometry.
**Escalation:** wide safe islands & one gap → more gaps / first verticality → radial & asymmetric
shapes → thin perches & the first NON-lethal mover (a lazy meadow pendulum / bumper hay-bale) at the
tail so the jump into Scrapworks is smooth. Everything JSON-ONLY. Backdrops: bright meadow sky
gradients + `open_sky`; the one new painting `meadow_bloom` is optional polish.

**Current: 4 → Target: 20 (16 new).**

| # | id / file | hook | tier | layout sketch | backdrop | tag |
|---|---|---|---|---|---|---|
| 1 | `grassy_expanse` [HAVE] | one open pit, spring throne | 1 | central_pit, 3760w | meadow sky | — |
| 2 | `islands_void` [HAVE] | 4-island archipelago | 2 | 5700w, 580 gaps, 2 thrones | blue sky | — |
| 3 | `the_cliff` [HAVE] | asymmetric mesa + scatter | 2 | 6340w, 3×580 gaps | dusk sky | — |
| 4 | `twin_chasms` [HAVE] | two voids, hot-seat centre | 2 | 5140w, 2×580 | dusk_gold | — |
| 5 | `meadow_first_hop` | ONE 580 gap, two huge trampoline lawns | 1 | 3400w; 2 wide (1500) trampoline islands + 1 bubblegum shoulder each side; 1×580 gap; no throne | bright sky | [JSON-ONLY] |
| 6 | `clover_steps` | three low islands, gentle stair | 1 | 3800w; 3 trampoline islands descending L→R (tops 1040/1080/1120), 2×580 gaps; one bubblegum ledge | bright sky | [JSON-ONLY] |
| 7 | `sunny_shoulders` | wide floor + two boost-only shoulders | 1 | 3600w; 2 trampoline floors, 580 pit; 2 bubblegum shoulders at 520 climb + 1 spring throne over pit | bright sky | [JSON-ONLY] |
| 8 | `three_meadows` | symmetric 3-island, mild | 1 | 4600w; A/B/C trampoline (900) over one void, 680 gaps, no hazards; centre bubblegum perch +520 | bright sky | [JSON-ONLY] |
| 9 | `daisy_ring` | small radial ring (atoll-lite) | 2 | radial ±2000; 4 rim islands + 1 low throne over a central well (640); 2 mid bubblegum shelves +520 | bright sky | [JSON-ONLY] |
| 10 | `long_meadow` | wide 5-island run, horizontal | 2 | 6800w; 5 trampoline/bubblegum islands, 600 gaps; 1 spring throne mid | bright sky | [JSON-ONLY] |
| 11 | `hill_and_dale` | high-low sawtooth, gentle verticality | 2 | 4800w; 4 islands alternating tops 1080/700, 600 gaps, ≤420 climbs; 1 throne | bright sky | [JSON-ONLY] |
| 12 | `bluff_line` | asymmetric: big left mesa, 2 right pads | 2 | 5000w; 1400 mesa + 2×680 pads over void, 580 gaps; far-ledge powerup | dusk sky | [JSON-ONLY] |
| 13 | `two_hills` | mirror twin peaks + valley void | 2 | 4400w; 2 tall trampoline peaks (top 760) flanking a low centre island over void; 620 gaps | bright sky | [JSON-ONLY] |
| 14 | `meadow_spine` | thin ridge + 2 spring perches (spine-lite, calm) | 2 | 4000w; 1200 trampoline ridge, 2 spring perches 600 out; 1 low throne +520; shallow void | bright sky | [JSON-ONLY] |
| 15 | `stepping_bloom` | 5 small pads, committed hops | 3 | 5600w; 5 bubblegum/trampoline pads (680) over deep void, 600 gaps, mild height jitter; 1 throne | bright sky | [JSON-ONLY] |
| 16 | `windmill_meadow` | first NON-lethal meadow pendulum (hay swing) | 3 | 4670w 3-island flagship (680 gaps); ONE `moving_hazard` pendulum over the A↔B gap (non-lethal shove); 1 throne | meadow_bloom | [NEEDS-ART]* |
| 17 | `hay_bales` | pinball meadow: bumper hay-bales over lawns | 3 | 4660w 3-island flagship; 3 free-standing `bumper` blocks (hay bales) in open air + 1 tall post over a gap; 580–680 gaps | bright sky | [JSON-ONLY] |
| 18 | `high_pasture` | 3-tier vertical meadow (ascent-lite, no lid) | 3 | 2600w walled-ish; 3 tiers zigzag up (trampoline→spring→spring), 520 climbs, over void; open top (no lethal lid) | bright sky | [JSON-ONLY] |
| 19 | `river_split` | two long lawns + narrow contested isle | 3 | 5000w; 2 long trampoline banks + a 620 centre isle over two voids; 2 thrones | dusk sky | [JSON-ONLY] |
| 20 | `meadow_carousel` | slow non-lethal moving hay-cart deck | 3 | 4400w; 2 static islands + ONE `moving_platform` (vehicle:false, hay cart) shuttling a 580 gap; 620 static gaps; 1 throne | meadow_bloom | [NEEDS-ART]* |

`*` NEEDS-ART = wants a new `meadow_bloom` painting; ships JSON-ONLY today with `dusk_gold` or a plain
bright sky gradient. **Meadow reaches 20 comfortably** (pure geometry, endless calm variety).

---

## CIRCUIT 2 — THE SCRAPWORKS  (difficulty 2 · ORDERED loop)
**Identity:** the industrial hazard-introduction circuit — grey quarry/scrapyard, gears, girders,
wrecking balls, carts. This is where **hazards enter one family at a time**: static bumpers → the
enclosed drum → NON-lethal wrecking pendulums → the first LETHAL single hazard (one hammer / one
crusher) → moving carts. Each stage adds exactly one new pressure so the difficulty ramps cleanly.
**Escalation:** static reflectors → drum → non-lethal movers → single lethal hazard → mover + hazard.
Backdrops: `overcast_quarry`, `dusk_gold`. Reuses the proven 4670w 3-island / 680-gap skeleton and the
drop-drum & ascent shells.

**Current: 4 → Target: 20 (16 new).**

| # | id / file | hook | tier | layout sketch | backdrop | tag |
|---|---|---|---|---|---|---|
| 1 | `bumper_gauntlet` [HAVE] | pinball posts over void | 1 | 5260w 3-island, 5 bumpers | space_nebula | — |
| 2 | `drop_chamber` [HAVE] | enclosed drum, centre hole | 1 | enclosed_hole drum | silo interior | — |
| 3 | `wrecking_yard` [HAVE] | twin non-lethal pendulums | 2 | 3-island, 2 anti-phase balls | overcast_quarry | — |
| 4 | `the_ascent` [HAVE] | vertical dual-blast shaft | 3 | dual_blast, low lid + void | dusk_gold | — |
| 5 | `scrap_flats` | bare 3-island industrial on-ramp | 1 | 4670w; A/B/C trampoline (900), 680 gaps, no hazards; 1 spring throne over C; scrap skin | overcast_quarry | [JSON-ONLY] |
| 6 | `girder_gap` | two big decks, single 680 pit + bumper post | 1 | 3800w; 2 trampoline decks, one 680 gap with ONE tall `bumper` girder post over it; 2 bubblegum shoulders | overcast_quarry | [JSON-ONLY] |
| 7 | `bolt_yard` | asymmetric scrap mesa + pad scatter | 1 | 5000w; 1400 mesa + 2×680 pads, 580 gaps; far-ledge powerup | overcast_quarry | [JSON-ONLY] |
| 8 | `pinball_pit` | interior-bumper pinball (denser than #1) | 2 | 5000w 3-island; 6 bumper posts/blocks scattered; 580–680 gaps; 1 throne | overcast_quarry | [JSON-ONLY] |
| 9 | `single_swing` | ONE non-lethal wrecking ball, one gap | 2 | 3800w; 2 islands, 680 gap; ONE `moving_hazard` pendulum dipping into the gap lane; 1 throne | overcast_quarry | [JSON-ONLY] |
| 10 | `gantry_climb` | vertical scrap tower, open top | 2 | 2600w; 4 zigzag tiers (trampoline/spring), 520 climbs, over void; bumper side walls; NO lethal lid | dusk_gold | [JSON-ONLY] |
| 11 | `conveyor_run` | moving cart decks bridge two yards | 2 | 5600w; 2 static islands + 2 `moving_platform` vehicle carts shuttling 580 gaps; 620 static gaps; 1 throne | dusk_gold | [JSON-ONLY] |
| 12 | `scrap_atoll` | radial scrap ring, central well | 2 | radial ±2500; 6 rim islands + central throne over well (640); 2 mid shelves +520 | overcast_quarry | [JSON-ONLY] |
| 13 | `first_hammer` | scrapworks' FIRST lethal hazard — one rotor | 2 | 4670w 3-island; ONE `spinning_hammer` over B (period 4.5, arc 150, dwell .24); spawns on A/C only | overcast_quarry | [JSON-ONLY] |
| 14 | `press_gate` | one horizontal crusher between two yards | 2 | 4670w; 2 islands + a narrow centre island B with ONE horizontal `crusher` (anvil) gating the mid-lane; 680 gaps | overcast_quarry | [JSON-ONLY] |
| 15 | `swing_alley` | 3 non-lethal pendulums, rhythm run | 3 | 5600w; 4 islands, 3 anti-phase `moving_hazard` balls (phase .0/.33/.66) over 3 gaps; 1 throne | overcast_quarry | [JSON-ONLY] |
| 16 | `hammer_and_swing` | lethal hammer on B + non-lethal ball on a gap | 3 | 4670w 3-island; `spinning_hammer` over B + one `moving_hazard` over B↔C gap | overcast_quarry | [JSON-ONLY] |
| 17 | `crusher_row` | two vertical presses stamp a shared deck | 3 | 4670w 3-island; TWO vertical `crusher`s on B (offset phase .0/.5, narrow heads, clear lanes at edges/centre) | overcast_quarry | [JSON-ONLY] |
| 18 | `wrecking_towers` | vertical shaft + a swinging ball in the channel | 3 | 2600w dual_blast-ish shaft; 4 tiers + ONE `moving_hazard` pendulum sweeping the mid-channel; open top | dusk_gold | [JSON-ONLY] |
| 19 | `moving_yard` | carts + a lethal hammer at the far deck | 3 | 5600w; 2 static islands + 2 cart `moving_platform`s + a `spinning_hammer` over the far static island | dusk_gold | [JSON-ONLY] |
| 20 | `scrap_crusher_drum` | enclosed drum whose centre island has a press | 3 | enclosed_hole drum + a `crusher` on a mid-shelf over the hole (knock rivals under it, they drop the hole) | silo interior | [JSON-ONLY] |

**Scrapworks reaches 20 cleanly** — the hazard families give lots of honest single-and-double combos
below Mayhem's everything-at-once ceiling.

---

## CIRCUIT 3 — THE HIGH WIRE  (difficulty 3 · ORDERED loop)
**Identity:** exposed heights & nerve. Thin ridges, tall spires, deep bottomless voids, big vertical
spreads, minimal-to-no hazards — **the recovery-gamble circuit**. The danger is the distance and the
fall, not machinery. Cool dusk / starfield / high-altitude palettes. Almost pure geometry (JSON-ONLY).
**Escalation:** a clean wide-island climb → thin ridges & perches → radial rim → extreme spires &
deep voids → a lidded ascent finale where up AND down kill.

**Current: 3 → Target: 18 (15 new). REALISM FLAG below — 18, not 20.**

| # | id / file | hook | tier | layout sketch | backdrop | tag |
|---|---|---|---|---|---|---|
| 1 | `atoll` [HAVE] | radial rim, central well | 2 | radial ±2500, 6 rim + throne | teal sky | — |
| 2 | `the_spine` [HAVE] | thin ridge, all-edge | 3 | 1500 ridge + 2 perches | blue sky | — |
| 3 | `spires` [HAVE] | extreme sawtooth pillars | 3 | 6 spire-tops, deep void | space_nebula | — |
| 4 | `sky_stones` | wide-island high-altitude on-ramp | 1 | 5700w; 4 trampoline islands (900) over a DEEP void (recovery sky ~900), 600 gaps; 1 throne | high sky | [JSON-ONLY] |
| 5 | `catwalk` | one long thin ridge, no perches | 1 | 3200w; single 1400 thin ridge (h56) over deep void; 2 low spring pads at ridge ends +520 | dusk sky | [JSON-ONLY] |
| 6 | `wire_walk` | two thin ridges + a gap between | 2 | 4600w; 2 thin ridges (1000) over deep void, 620 gap; 1 high throne +520 | dusk sky | [JSON-ONLY] |
| 7 | `perch_line` | 5 tiny perches, committed hops | 2 | 5600w; 5 bubblegum perches (600w) over deep void, 600 gaps; 1 throne | space_nebula | [JSON-ONLY] |
| 8 | `high_atoll` | radial rim over a DEEP well | 2 | radial ±2500; 6 rim + throne, void ~300 deeper than atoll | teal sky | [JSON-ONLY] |
| 9 | `stagger_spires` | 4 spires, moderate sawtooth | 2 | 5000w; 4 spire-tops alt tops 1020/620, 600 gaps, ~420 climbs; 1 throne | space_nebula | [JSON-ONLY] |
| 10 | `zenith` | central high throne, rim of low perches | 2 | radial ±2200; 4 low perches + a very high central throne (+560 over perches); spikey verticality | dusk sky | [JSON-ONLY] |
| 11 | `the_gauntlet_ridge` | asymmetric: safe ledge → thin exposed run | 2 | 5400w; 1200 ledge + 3 thin perches (600) over deep void, 600 gaps; far throne | dusk sky | [JSON-ONLY] |
| 12 | `twin_towers` | two tall pillars + a low bridge isle | 3 | 4600w; 2 tall trampoline towers (top 640) + a low 620 centre isle over two deep voids; 2 thrones | space_nebula | [JSON-ONLY] |
| 13 | `deep_spires` | spires over the deepest void, big climbs | 3 | 6400w; 6 spire-tops, 600 gaps, 460–520 climbs, recovery sky ~1200; central throne +520 | space_nebula | [JSON-ONLY] |
| 14 | `pendulum_heights` | thin ridge + ONE non-lethal ball forcing motion | 3 | 4600w; 2 thin ridges, 620 gap; ONE `moving_hazard` pendulum sweeping the gap (shove toward void) | dusk sky | [JSON-ONLY] |
| 15 | `crosswind_pillars` | tall pillars + one lethal hammer up high | 3 | 5000w; 4 spire-tops; ONE `spinning_hammer` over the central-high spire (the only machine in the circuit) | space_nebula | [JSON-ONLY] |
| 16 | `needle_ridge` | razor ridge, max exposure (spine+) | 3 | 3600w; single 1000 razor ridge (h48) + 2 far perches 640 out, only ~460 inside side blast; 1 throne | dusk sky | [JSON-ONLY] |
| 17 | `sky_ladder_brawl` | vertical ascent, open top, deep drop | 3 | 2600w; 5 zigzag tiers (spring-heavy), 520 climbs, DEEP void below; bumper walls; no lid | dusk sky | [JSON-ONLY] |
| 18 | `the_summit` | lidded vertical finale — up AND down kill | 3 | dual_blast shaft; 4 tiers to a wide top deck under a LOW lethal lid, void below, bumper walls | space_nebula | [JSON-ONLY] |

**REALISM FLAG — High Wire: build 18, not 20.** This circuit is deliberately hazard-light (its whole
point is exposure/recovery, not machinery), so distinct-and-GOOD stages come only from geometry
variety (ridge / spire / radial / vertical). Past ~18 the shapes start echoing each other (a 20th thin
ridge is just a worse version of an earlier one). 18 strong stages > 20 with two filler repeats. If we
later want 20, the honest way is +2 mild-hazard variants (one more non-lethal pendulum shape, one more
single-hammer height) rather than +2 more bare ridges — noted but not padded in here.

---

## CIRCUIT 4 — THE FOUNDRY  (difficulty 3 · RANDOM-DRAW, draw 4)
**Identity:** the molten-factory **gimmick** circuit — the level itself fights you. Crusher stamping
presses, molten `falling_debris` drops, destructible floors that **collapse from under everyone**
(the headline last-one-flying archetype), lethal hammers. Ember palette (`ember_foundry`, glow on,
clouds off). Every stage's hook is a MECHANIC, tier-sorted mild→wild each draw.
**Escalation:** single-press on-ramp → destructible + one hazard → multi-hazard smelter → the two
collapsing-arena finales (center-out & outer-in). The draw pool grows toward the v6 ~8–20 target.

**Current: 4 → Target: 16 (12 new). REALISM FLAG below — 16, not 20.**

| # | id / file | hook | tier | layout sketch | backdrop | tag |
|---|---|---|---|---|---|---|
| 1 | `foundry_press_row` [HAVE] | twin vertical stamping presses | 1 | 3-island, 2 crushers on B | ember_foundry | — |
| 2 | `foundry_crucible` [HAVE] | crusher + destructible mid | 2 | multi-hazard | ember_foundry | — |
| 3 | `foundry_smelter` [HAVE] | multi-hazard molten yard | 2 | hammer/debris mix | ember_foundry | — |
| 4 | `foundry_meltdown` [HAVE] | collapse center-out finale | 3 | destructible cascade | ember_foundry | — |
| 5 | `foundry_first_pour` | single vertical press on-ramp | 1 | 4670w 3-island; ONE vertical `crusher` on B (long open dwell, narrow head); molten skin; spawns A/C | ember_foundry | [JSON-ONLY] |
| 6 | `foundry_droplets` | intro to molten falling_debris | 1 | 4670w 3-island; `falling_debris` over B (3 columns, gentle cadence 1.8, max 1); clear edges | ember_foundry | [JSON-ONLY] |
| 7 | `foundry_single_hammer` | one rotor over the smelt-deck | 1 | 4670w 3-island; ONE `spinning_hammer` over B; ember skin | ember_foundry | [JSON-ONLY] |
| 8 | `foundry_slag_run` | horizontal crusher gates the mid-lane | 2 | 4670w; centre island with a horizontal `crusher` (anvil) squeezing the crossing lane; 680 gaps | ember_foundry | [JSON-ONLY] |
| 9 | `foundry_pour_line` | debris columns over TWO islands | 2 | 5600w 4-island; `falling_debris` over B and C (offset start), cadence 1.5; 600 gaps | ember_foundry | [JSON-ONLY] |
| 10 | `foundry_press_gauntlet` | 3 presses across a long deck, weave | 2 | 5000w; one long deck B split by 3 vertical `crusher`s (phase .0/.33/.66), clear gaps between; flanked by 2 islands over void | ember_foundry | [JSON-ONLY] |
| 11 | `foundry_hammer_and_pour` | rotor + molten drops together | 2 | 4670w 3-island; `spinning_hammer` over B + `falling_debris` over C | ember_foundry | [JSON-ONLY] |
| 12 | `foundry_crack_floor` | destructible islands that erode as you fight | 2 | 4670w; the 3 islands are `destructible_block` groups on a slow HP/timed erode (edges first), void below; boost to survive | ember_foundry | [JSON-ONLY] |
| 13 | `foundry_press_and_crack` | one press + a collapsing side deck | 3 | 4670w; vertical `crusher` on B + island C is a timed destructible cascade; 680 gaps | ember_foundry | [JSON-ONLY] |
| 14 | `foundry_inferno` | multi-hazard peak (hammer + debris + press) | 3 | 5000w 3-island; `spinning_hammer` on B + `falling_debris` on B + a `crusher` press on C; clear beats staggered | ember_foundry | [JSON-ONLY] |
| 15 | `foundry_collapse_ring` | RADIAL collapsing arena (new finale shape) | 3 | radial ±2400; ring of `destructible_block` islands erode inward around a central well; last-one-flying | ember_foundry | [JSON-ONLY] |
| 16 | `foundry_cascade` | vertical collapsing shaft finale | 3 | 2600w shaft; stacked `destructible_block` tiers erode bottom-up, forcing a climb; open top, void below | ember_foundry | [JSON-ONLY] |

**REALISM FLAG — Foundry: build 16, not 20.** The Foundry is a single-family gimmick circuit
(crusher / debris / destructible / hammer) on the ember palette. Beyond ~16, "distinct-and-good"
stages start being re-skins of the same press/collapse beats — quality drops fast. 16 covers the full
mechanic matrix (each hazard solo, each pair, plus THREE genuinely different collapse finales:
center-out, outer-in, radial, vertical). To ever push toward 20 honestly we'd need a NEW foundry
mechanic — e.g. a **molten conveyor** (a lethal moving surface / lava-flow band) or **rising-lava**
(a lethal floor that climbs) — both **[NEEDS-CODE]** and out of scope for this build; flagged as the
only real path to a bigger Foundry, not padded here. As a RANDOM-DRAW circuit (draw 4), 16 already
means a session almost never repeats.

---

## CIRCUIT 5 — MAYHEM MILE  (difficulty 4 · RANDOM-DRAW, draw 6)
**Identity:** the WILD finale circuit — everything at once. Multi-hazard chaos, radial gravity wells,
mine fields, moving carts, collapsing boxes, pinball. Each draw shuffles 6 and tier-sorts mild→wild.
Today it **borrows** wrecking_yard / bumper_gauntlet / drop_chamber / islands_void from other circuits;
the owner ask is a DEDICATED set, so this plan gives Mayhem its own 20 and **drops the borrowed 4**
(they still live in their home circuits; Mayhem stops double-listing them).
**Distinct from Scrapworks/Foundry:** Scrapworks = one hazard family at a time; Foundry = molten
gimmick; **Mayhem = COMBOS + the toys no other circuit uses (gravity wells, mines, everything stacked).**
**Escalation:** single readable hazard on-ramp → a bigger single-family threat → multi-hazard + gravity
+ collapse chaos.

**Current: 8 dedicated (+4 borrowed) → Target: 20 dedicated (12 new).**

| # | id / file | hook | tier | layout sketch | backdrop | tag |
|---|---|---|---|---|---|---|
| 1 | `gauntlet_mine_lite` [HAVE] | first sparks — few mines | 1 | wide floor + mines | overcast_quarry | — |
| 2 | `hammer_arena` [HAVE] | single lethal rotor | 1 | 3-island + hammer | overcast_quarry | — |
| 3 | `minefield` [HAVE] | mine seeds + fuse bomb | 2 | wide floor, mine grid | overcast_quarry | — |
| 4 | `gauntlet_twin_swing` [HAVE] | twin lethal swings | 2 | dual hazard | overcast_quarry | — |
| 5 | `gauntlet_dropzone` [HAVE] | falling debris zone | 2 | debris columns | overcast_quarry | — |
| 6 | `hazard_yard` [HAVE] | crusher + debris | 2 | multi-hazard | overcast_quarry | — |
| 7 | `gauntlet_pandemonium` [HAVE] | hammer + twin mines | 3 | 3-island, 3 hazards | overcast_quarry | — |
| 8 | `meltdown_box` [HAVE] | collapsing box finale | 3 | destructible cascade | ember_foundry | — |
| 9 | `spark_yard` | one fuse-bomb pulse, single floor | 1 | 3400w one wide floor over void; ONE central `fuse` bomb (recur 4); knock rivals off ends | overcast_quarry | [JSON-ONLY] |
| 10 | `single_stomp` | one crusher on an open deck | 1 | 4670w 3-island; ONE vertical `crusher` on B; spawns A/C | overcast_quarry | [JSON-ONLY] |
| 11 | `bumper_mines` | pinball posts + a mine pair | 2 | 5000w 3-island; 4 `bumper` posts + 2 proximity mines on side islands | space_nebula | [JSON-ONLY] |
| 12 | `moon_pit` | first gravity well — planetoid bounce body | 2 | ±2000; 4 islands ring a central `gravity_source` (moon, body_r 120, g 900) over void; well curves your arcs | space_nebula | [JSON-ONLY] |
| 13 | `swing_mines` | non-lethal pendulums fling you onto mines | 2 | 5600w 4-island; 2 `moving_hazard` balls + 2 proximity mines under the swing paths | overcast_quarry | [JSON-ONLY] |
| 14 | `cart_chaos` | moving carts through a debris zone | 2 | 5600w; 2 `moving_platform` carts crossing 580 gaps + `falling_debris` over the mid static island | dusk_gold | [JSON-ONLY] |
| 15 | `double_hammer` | two rotors, anti-phase, one deck | 3 | 5000w 3-island; TWO `spinning_hammer`s over a wide centre deck (phase .0/.5); clear beats alternate | overcast_quarry | [JSON-ONLY] |
| 16 | `black_hole_brawl` | lethal-core gravity well centre | 3 | ±2200; ring of islands around a `gravity_source` (black_hole, lethal_core_r >0, g 1100) — the core is a killer | space_nebula | [JSON-ONLY] |
| 17 | `press_and_mines` | crushers + a mine grid + fuse bomb | 3 | 5000w; 2 crushers on centre deck + proximity mines on flanks + central fuse bomb | overcast_quarry | [JSON-ONLY] |
| 18 | `everything_yard` | hammer + crusher + debris + mine (kitchen sink) | 3 | 5600w 4-island; one of each lethal family, staggered clear beats, symmetric | overcast_quarry | [JSON-ONLY] |
| 19 | `gravity_gauntlet` | gravity well + swinging hammer combo | 3 | ±2200; `gravity_source` centre + a `spinning_hammer` orbiting-height over a rim island | space_nebula | [JSON-ONLY] |
| 20 | `pandemonium_prime` | collapsing box seeded with mines + a hammer | 3 | destructible cascade box (meltdown-style) + 2 mines on the last-standing tiers + a hammer up top; last-one-flying | ember_foundry | [JSON-ONLY] |

**Mayhem reaches 20 dedicated cleanly** — combos + the gravity/mine/cart toys give huge distinct-
variety headroom. It stops borrowing from other circuits, satisfying the "dedicated set" ask. (If we
want the borrowed classics still in Mayhem's rotation for flavour, cross-list them without them
counting toward the dedicated 20 — a data decision at circuits.json build time.)

---

## GRAND SUMMARY (scopes the build phase)

| circuit | draw shape | current | target | NEW to build | note |
|---|---|---|---|---|---|
| Meadow Mile | ordered | 4 | **20** | **16** | all JSON-ONLY (2 want optional `meadow_bloom` art) |
| The Scrapworks | ordered | 4 | **20** | **16** | all JSON-ONLY |
| The High Wire | ordered | 3 | **18** | **15** | JSON-ONLY; capped at 18 (exposure-only variety) |
| The Foundry | draw 4 | 4 | **16** | **12** | JSON-ONLY; capped at 16 (single-gimmick family) |
| Mayhem Mile | draw 6 | 8 ded. | **20** | **12** | JSON-ONLY; drops 4 borrowed, gains gravity/mine/cart combos |
| **TOTAL** | — | **23** | **94** | **71 new arenas** | |

### Implementation-tag totals (of the 71 new)
- **[JSON-ONLY]: 69** — buildable now from shipped platforms/tiers/void + the shipped hazard object
  types. Build these first; they are the entire committed scope.
- **[NEEDS-ART]: 2** (`windmill_meadow`, `meadow_carousel`) — want a new `meadow_bloom`
  backdrop_painting; both ship JSON-ONLY today with an existing painting and get the art in a polish
  pass. **Zero art is blocking.**
- **[NEEDS-CODE]: 0 in the committed plan.** The only NEEDS-CODE items are the *optional future*
  Foundry mechanics (molten conveyor / rising-lava) named in the Foundry flag as the path to a bigger
  Foundry someday — deliberately NOT in the 71.

### Realism flags (where ~20 distinct-and-good is hard — de-scoped honestly)
1. **High Wire → 18, not 20.** Hazard-light by identity; geometry-only variety saturates near 18.
   Two more good stages need mild-hazard variants, not more bare ridges.
2. **The Foundry → 16, not 20.** Single-family molten gimmick; 16 covers the full mechanic matrix and
   3 distinct collapse finales. Reaching 20 honestly requires a NEW foundry mechanic ([NEEDS-CODE]).
3. **Mayhem dedup.** Mayhem currently pads its count by borrowing 4 arenas from other circuits. The
   dedicated-set ask means it must stand on its own 20; this plan gives it that and stops the borrow.

### Build-order recommendation
1. Meadow 5–20 and Scrapworks 5–20 first (pure geometry / single-hazard, lowest risk, biggest
   session-variety win, and they're the circuits players see first).
2. High Wire 4–18 (geometry, reuses proven ridge/spire/radial skeletons).
3. Foundry 5–16 and Mayhem 9–20 (hazard-combo tuning is the most QA-heavy — each needs the
   flight-required + spawn-fairness + "a driven player can't cross without boosting" validation, plus
   the motion-health read on bots).
Every new arena ships with its movement-tool-per-gap analysis in `design_intent` and a rendered-scene
screenshot check per the level-designer gate.
