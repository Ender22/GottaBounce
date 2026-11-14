# Art brief: sports nets (WK-66a, from WK-98 SP-13)

Date 2026-11-15 · Author: art-director · Backlog WK-66a [P1][M], lane V, after WK-122 · Parent WK-66 (court art, P2)

The programmer builds this exactly as written. I grade the result from in-game screenshots only, using the tests in section 9.

## 1. What is wrong now (from the WK-122 after-frames)

| Court | What a couch player sees | Why it fails |
|---|---|---|
| BEACH / CORAL COVE (`after_dropshot_beach.jpg`) | The net is a 30 px column of white balls, the same `bumper_post` art as the side walls. | It reads as a fourth wall or a pole. Nothing says "net", and it shares a silhouette with the walls. |
| DOME (`after_dropshot_dome.jpg`, `_dome_30s.jpg`) | The net is a dark slate rod (`MovingPlatform._draw_deck` steel rects) on a dark stadium. When it is low, it draws over the floor tiles. | It has almost no value contrast, is flat code-drawn, and shows no "gap is open" cue. It is the worst-reading object in the mode. |
| Rocketball, all 8 courts (`after_long_haul.jpg`) | The goal is a flat red or blue outlined rectangle with a 4x6 line grid (`GoalZone._draw`) that pulses wider and narrower. A goal floods it green. | It is a debug-looking grid. The pulse is a non-uniform stretch, which is banned. The green flood is a flat fill. There is no frame, no depth and no net material. |

Shared root cause: none of these are toy objects. Each one is code-drawn rects/lines or another object's art. The fix is a small kit
of three generated, tintable assets plus one shader for motion.

## 2. Decisions (art vs code)

- **Generated art (3 assets):** a shared net MESH tile, a Dropshot net FRAME (tape, posts, hem) and a Rocketball goal FRAME (tubes).
  Both frames have **empty interiors**, and the mesh is tiled into them by code. That gives one net material across both modes, and
  the mesh can ripple and bulge without warping the solid frame.
- **Code/shader (no art):** mesh ripple on contact, goal bulge, the DOME gap glow (reuses `fx/puff_soft.png` additively), the
  per-court and per-team tint, and the clipping.
- **Not generated:** a separate DOME net. All three Dropshot courts use the **same net**, so players learn "net" once (the tier-mat
  principle). DOME differs only in its motion cue.
- **Collision is unchanged** (PROTECT). The net collider stays a 30x490 bumper column (static or `moving_platform`), and the goal
  trigger stays the centre-in-rect `goal_zone`. Art bleeds past colliders only within the house ~8-17 px rule (section 4).

## 3. Layout sketches (described)

### 3a. Dropshot net (BEACH, CORAL COVE, DOME): a toy volleyball set squeezed front-on
```
      o          o        <- post knobs poke ~16 wpx above the tape (white balls, chocolate outline)
   [==TOP TAPE=====]      <- fat padded white band, 88 x 26 wpx, top edge 12 wpx above collider top
    |\/\/\/\/\/\/|        <- two slim glossy posts (8 wpx) at x = +-28 from net centre
    |/\/\/\/\/\/\|           diamond rope mesh (tile) between them, + 10% white veil in the holes
    |\/\/\/\/\/\/|           panel 64 wpx wide over the 30 wpx collider (17 px bleed each side)
    |  ...490...  |
   [=== HEM ======]       <- slimmer padded band, 64 x 14 wpx, bottom edge on the floor line (y1350)
 ---feet hidden behind the DropTiles (tiles z5 draw over the net)---
```
- The silhouette is a **"Π with two knobs"**: wide white T at the top, see-through body, posts down both edges. That is the opposite
  of a solid studded wall, so it can't be mistaken for one.
- DOME: the whole set rides the MovingPlatform. Anything below the floor top (y1350) is **clipped** (never drawn over tiles). When the
  under-gap is ≥ 88 wpx (a goat fits), the hem lights up: an additive `#7FF6FF` bar along the hem, a 2 Hz pulse between alpha 0.55
  and 0.9, plus a soft light pool on the tiles under the slot (`puff_soft`, 150x40 wpx, alpha 0.35). When the gap closes, both fade
  out over 0.15 s. That is the "under-gap is open" cue SP-13 asks for.

### 3b. Rocketball goal: a side-view cage mounted in the wall gap
```
 back post |==TOP TUBE===========o|  <- top tube centred on the mouth top edge, tucked BEHIND the upper wall column cap
 (wall art)||/\/\/\/\/\/\/\/\/\/\ |     mouth post cap "o" (40 wpx round) at the mouth corner, <= 8 wpx past the wall face
           ||\/\/\/\/\/\/\/\/\/\/ |  <- mesh tile fills the interior, tinted pale team colour, + 18% team veil
           ||/\/ (ball sits here) | MOUTH (open, faces court)
           ||\/\/\/\/\/\/\/\/\/\/ |
           |==BOTTOM TUBE========o|  <- tucked behind the lower wall column cap
 back tube on the LEFT, against the back post inner face (tucked behind it)
```
- Horizontal extent: from the back post's inner face (−6 wpx, tucked) to the court-side wall face (+8 wpx). That is 150 wpx on
  LONG HAUL / BOWL family and 140 wpx on THE BOX. **Data, not code:** the level-designer adds `"net_back_x"` (world x of the back
  post inner face) to each `goal_zone`. Default when absent: mouth face − 150.
- Vertical extent: the mouth (= zone `h`, 260-340) plus the tubes, which overlap the wall caps by half a tube.
- The right-hand goal (team 1) is the same sprite with `flip_h`. This is allowed because the frame is generated lit from **directly
  above**, so mirroring flips nothing visible.

## 4. Size math at court framing (zoom 0.60-0.90)

Court zooms: LONG HAUL 0.60 (clamped) · CORAL COVE 0.62 · BEACH and most Rocketball 0.69 · DOME 0.77 · THE BOX ~0.90.
The legibility floor is ~10 screen px for any detail.

| Element | World px | @0.60 | @0.69 | @0.90 | Verdict |
|---|---|---|---|---|---|
| Mesh cell (knot-to-knot horizontal period) | 32 | 19 | 22 | 29 | ok, reads as diamonds |
| Mesh cord incl. outline | 7 | 4.2 | 4.8 | 6.3 | ok as texture (the silhouette is carried by the frame) |
| Dropshot panel width | 64 | 38 | 44 | 58 | ok, 2 diamonds across |
| Dropshot top tape | 88 x 26 | 53 x 16 | 61 x 18 | 79 x 23 | the key read, ok |
| Post knobs | 18 dia | 11 | 12 | 16 | at the floor, keep them BIG in the art |
| Goal tube thickness | 22 | 13 | 15 | 20 | ok |
| Goal mouth post cap | 40 dia | 24 | 28 | 36 | ok |
| Goal box | 150 x 300 | 90 x 180 | 104 x 207 | 135 x 270 | ok, the soccer ball (r60) fits |

Bleed limits (readability lie guard):
- The Dropshot visual is ≤ 17 wpx wider than the collider per side. A ball resting against the net overlaps the mesh by ≤ 17 px, which
  reads as "pressing the net", and the ripple sells it.
- The top tape must not exceed 88 wpx, so a ball skimming over the top never visibly passes through the tape.

## 5. Palette (hex)

| Use | Hex | Notes |
|---|---|---|
| Outline, every piece | `#3B241B` | house chocolate, thick |
| Authored art fill (all 3 assets) | `#F2F2F2` → `#BDBDBD` underside, `#FFFFFF` gloss | greyscale only (tintable contract) |
| Dropshot per-court modulate (plain multiply on frame + mesh) | BEACH `#FFF3DC` · CORAL COVE `#E2FFF6` · DOME `#E4EEFF` | subtle. The net must stay **white** against the stadium (value L≈92 vs backdrop ≈15) |
| Dropshot mesh veil (holes) | white, alpha 0.10 | added in the shader, not as a rect |
| DOME gap glow | `#7FF6FF` additive | team-neutral, not a reserved colour |
| Goal frame | live team colour via `fx_tint.gdshader` (`self_modulate` = team colour; RED `#ff4b6a` / BLUE `#3fa9ff` or the WK-27 colourway) | tubes become saturated team colour, gloss and outline survive |
| Goal mesh | `lerp(team, white, 0.30)` plain modulate, alpha 0.95 | kept fairly saturated so the WHITE soccer ball separates from it |
| Goal veil (holes) | team colour, alpha 0.18 | replaces the current 0.16 fill |
| Goal flash on score | frame to `#FFFFFF` for 0.08 s, then back to team over 0.4 s | replaces the green flood (flat fill = Fix) |

Reserved-colour check: no magenta `#FF4FA3` family, no safety orange, no blue+yellow pair. The magenta `#FF00FF` used in generation is
a **chroma key** and must not survive intake.

## 6. Asset list and generation prompts

New folder `assets/world/sports/`. Generate all three in **one ChatGPT chat** (family consistency). Attach
`assets/reference/style_north_star.png` and `assets/fx/ko_blast_core.png` ("same tintable family as the attached effect"). Use the
clipboard Ctrl+V technique, and check the Downloads timestamp before intake.

**Why magenta, not transparent:** all three subjects have **enclosed holes**. The corner flood (`keyout`) can't reach them. A baked
fake checkerboard in the holes is white/grey, so a global key would also eat the white cords. So we ask for a solid key colour.

**Tintable clause** (verbatim, same as `ko_blast_*` / ghost brief):
> "Entirely WHITE and light-grey (greyscale only, no colour at all) so the game can tint it any colour; fill ~#F2F2F2 shading down to
> ~#BDBDBD on the underside, pure-white gloss highlights; thick clean dark-chocolate (#3B241B) outline; no glow haze, no soft
> airbrushed edges, no text, no letters."

**Key-colour suffix** (replaces the base suffix's transparency sentence for this brief only):
> "Style: high-quality glossy cartoon game art, thick clean dark-chocolate outlines, soft plastic-toy shine highlights. IMPORTANT:
> the background, AND every hole or empty space inside the object, is ONE SOLID FLAT PURE MAGENTA colour #FF00FF: no gradient, no
> shadow, no checkerboard, no floor, no sky. No magenta or pink anywhere on the object itself."

### N1 `assets/world/sports/net_mesh.png`: shared seamless mesh tile
- **Final:** 256x256, real alpha, seamless in both axes. Exactly 4x4 diamond periods (64 px per period). Drawn tiled at 128 wpx per tile
  (= 32 wpx cell). Import with **mipmaps ON** (a ~0.3x effective downscale on thin cords will shimmer without them) and
  `texture_repeat` enabled.
- **Generate:** 1024x1024 swatch. Prompt:
> "A flat straight-on swatch of chunky cartoon toy NET MESH for a 2D party game, filling the ENTIRE square image edge to edge: a
> perfectly regular DIAMOND lattice, cords running at exactly 45 degrees in both directions, 8 diamonds across and 8 down, every
> opening the same size, cords perfectly straight and evenly spaced, a small round knot bead at every crossing. Thick soft rope cords
> with a subtle twisted-rope texture. Perfectly flat: no curvature, no sag, no perspective, no vignette, no frame, no border.
> [tintable clause] [key-colour suffix] Square image."
- **Intake:** chroma-key (section 7). Then crop exactly one 4x4 period, **knot centre to knot centre** on both axes, from the most regular
  area, and resize to 256. Seam proof: tile it 3x3 (`art.py sheet` on 9 copies) and look at the joins at 200%. Like the `door_tile`
  precedent, a few px of edge crop plus re-tile is fine. Re-roll rather than hand-paint if the lattice is irregular.

### D1 `assets/world/sports/net_dropshot_frame.png`: volleyball set frame, vertical 3-slice
- **Final:** source width 352 px (4x the 88 wpx draw width), real alpha. Height whatever the generation gives (≥ 1200). Built with
  `ThreeSlice.build(tex, 88, visible_h, cap_frac, true)`. The cap fraction is chosen at intake so the top cap holds knobs+tape and the
  bottom cap holds hem+feet (expect ~0.14).
- **Generate:** 1024x1536 portrait. Prompt:
> "A toy VOLLEYBALL NET SET frame for a 2D party game, seen straight-on from the front, very TALL and NARROW (about 1 part wide to 6
> parts tall), filling the full image height. Top to bottom: (1) two slim smooth glossy upright POSTS, one at each side, each topped
> by a big round ball knob; (2) a fat padded horizontal TOP TAPE band joining the posts just under the knobs, like a soft pillow strip
> with one stitched seam line along its middle and a round grommet at each end, slightly wider than the posts; (3) the posts run
> straight down the whole height; (4) near the bottom a slimmer padded BOTTOM HEM band joins the posts, and each post ends in a small
> rounded foot. The space BETWEEN the posts is completely EMPTY (no net, no mesh: the game adds it). The middle length of the posts
> must be plain and evenly repeating: perfectly straight, identical, no bolts, no labels; all detail only at the top and bottom ends.
> Lit from directly above. Bold simple silhouette that reads at small size. [tintable clause] [key-colour suffix] Tall portrait
> composition."
- **Accept at intake:** knobs ≥ 20% of the frame width (they must survive at 11 screen px). Tape clearly wider than the post spacing.
  Posts ≤ 12% of the width each.

### G1 `assets/world/sports/goal_frame.png`: Rocketball cage frame, vertical 3-slice, team-tinted
- **Final:** source width 680 px (4x the 170 wpx draw width), real alpha. Built with `ThreeSlice.build(tex, frame_w, mouth_h + 22,
  cap_frac≈0.2, true)`. The width is uniform-scaled to `frame_w` from data (≤ 10% fudge allowed, per the `build_whole` rule).
- **Generate:** 1024x1536 portrait. Prompt:
> "A toy SOCCER GOAL FRAME for a 2D side-view party game, seen exactly from the SIDE, tall portrait (about 2 parts wide to 5 parts
> tall). A cage frame of thick round glossy tubes: a straight horizontal TOP TUBE and a straight horizontal BOTTOM TUBE running the
> full width; a straight vertical BACK TUBE on the LEFT joining them with big rounded elbow corners; the RIGHT side is OPEN (the goal
> mouth): the top and bottom tubes end there in two big round chunky post caps seen end-on, like glossy round buttons. Inside the
> frame is completely EMPTY (no net: the game adds it). The back tube's middle section must be plain and evenly repeating; all detail
> (elbows, caps, two chunky bolts per elbow) only near the top and bottom. Lit from directly above, symmetric lighting so it can be
> mirrored. Bold simple silhouette. [tintable clause] [key-colour suffix] Tall portrait composition."
- **Accept at intake:** tube thickness ≈ 13% of the width. Post caps ≈ 24% of the width. No side-specific highlight.

Record all three prompts plus outcomes in `assets/CATALOG.md` ("Prompt patterns"). Add three `SHIP-CANDIDATE` rows.

## 7. Processing (operator)

1. `python tools/art.py check <raw>`. Expect "no transparency" (magenta).
2. **Global chroma key** (`art.py` has no such mode today; it only flood-fills from the corners). Either use a scratch PIL script or have
   the tools owner add `art.py chroma IN OUT [--key ff00ff] [--tol 90]`. Rules:
   - every pixel within `tol` of the key gets alpha 0;
   - partial pixels get alpha from their distance to the key, then get de-spilled: remove the magenta contribution and pull toward
     chocolate `#3B241B`, since every edge borders the outline;
   - finish with `trim` and `check`.
3. Zoom-check at 200% for purple fringe. Any visible magenta = re-key or re-roll. Do not intake it.
4. N1 only: period crop, 256 resize, and the 3x3 seam proof (section 6).

## 8. How the programmer builds and layers it

**Data hooks (level-designer, `levels/sports/*.json`, lane V):**
- Add `"skin": "net"` to the net platform in `dropshot_beach` / `dropshot_reef` and to the `moving_platform` in `dropshot_dome`.
  `ArenaRenderer` skips `bumper_post` for `skin:"net"`. `MovingPlatform` skips `_draw_deck` and parents the net art instead.
  The colliders are untouched.
- Add `"net_back_x"` to each Rocketball `goal_zone`.

**Draw order (z):**

| Layer | z | Notes |
|---|---|---|
| Dropshot net (frame + mesh) | **4** | Below `DropTile` (5), so the floor line hides the feet and a sunk DOME net. Ball (40) and players draw over it. |
| DOME clip | — | Never draw below the floor top (y1350). Draw via a region-cropped rect or a clip parent; no art under the floor. |
| DOME hem glow + floor pool | 5-6, additive | Over the tiles, so the pool lands on the floor. |
| Goal back layer (mesh + veil, then frame) | **just below the wall art** | The wall column caps and the back post overlap the tube ends: the goal reads as *mounted in the wall*. |
| Ball | 40 | **Always fully visible.** Nothing opaque is ever drawn over it. |
| Goal front veil | 42 | The SAME mesh tile, cords only, **alpha 0.22**, no fill, over the ball inside the goal. This sells "in the net". It must not drop ball contrast below the section 9 test. |
| Score confetti | 60 | unchanged |

Remove from `GoalZone._draw`: the grid lines, the rect rim, the `pulse` width stretch, and the green `scored` flood. Keep the
centre-in-rect latch and `_score_burst` exactly as they are (PROTECT).

**Motion (one shader, `assets/shaders/net_mesh.gdshader`, on the MESH layer only; frames stay rigid):**
- Render the mesh as one quad, tiled UVs, `texture_repeat`, padded by the max displacement on each side. The fragment shader offsets UV
  by the inverse displacement and adds the hole veil: `alpha = max(tex.a, veil)` inside the frame interior mask.
- **Ripple, Dropshot net:** horizontal sine displacement travelling vertically out from the contact y. Amplitude =
  `clamp(ball_speed / 1900, 0.15, 1) * 7 wpx`, wavelength 90 wpx, decays to 0 in 0.35 s. A player body contact uses 0.4x the
  amplitude. The tape dips 3 wpx for 0.1 s on a top-tape contact (frame offset, not stretch).
- **Ripple, goal (near miss):** a ball hitting the goal's back area or tubes plays the same ripple at 0.5x.
- **Bulge, goal score:** fed by the existing latch point (`_score_burst(at)`). A Gaussian push **away from the mouth**, toward the
  back post: radius 90 wpx, peak 20 wpx. A damped spring with 2 visible wobbles, settled by 0.6 s. Frame flash per section 5.
- **Event source:** the ball's existing ricochet contact path (WK-105 "tonk") checks the collider for `skin:"net"` or the goal and
  calls the net node with `(contact_pos, speed)`. No new physics. All amplitudes and times go in a `Tuning.gd` block
  (`net_ripple_*`, `goal_bulge_*`, `dome_gap_glow_min = 88`).

## 9. Grading tests (screenshots and recordings only)

Capture at 1920x1080 (**not** 1280 gbplay thumbs for the couch test). Use one port per lane (WK-130).

1. **Couch squint:** downscale each frame to 480 px wide. On BEACH, CORAL COVE, DOME (gap closed **and** gap open), LONG HAUL (0.60)
   and THE BOX (~0.90), the net and goals are nameable as "net" or "goal" in <1 s, not pole/wall/grid. Blind check: hand a fresh agent
   the 480 px BEACH thumb and ask "what is the object in the middle of the court?". Anything but "a net" = Fix.
2. **Not a wall:** the Dropshot net must not share a silhouette or value pattern with the studded white bumper walls in the same frame.
3. **Mesh at 0.60:** diamonds are visible on LONG HAUL and CORAL COVE stills. In a WK-93 recording during camera shake there is no
   shimmer or moiré. If either fails, check mipmaps first.
4. **Ball in the goal:** in a goal-moment frame the white ball is fully readable through the front veil, with outline intact and clearly
   separated from the pale-team mesh. The bulge is visible in ≥ 2 consecutive recorded frames and settled by 0.6 s.
5. **Ripple:** a recording of a beach ball striking the net mid-height shows a visible ripple that settles in ~0.35 s. Rebound
   behaviour is identical to before (collision unchanged).
6. **DOME:** max-rise frame shows hem glow and floor pool on. Min frame shows no net art below the floor line, glow off, and no steel
   rod anywhere.
7. **Team tint:** both goals show the correct team colour on a default match **and** on a non-default WK-27 colourway pair.
8. **Polish at 200% crop:** no tile seams in the mesh, no stretched caps, no magenta or purple fringe, no flat rect fills, no line
   grids, no width pulse.
9. **PROTECT regression:** the serve still sits frozen above the net, goal detection is still centre-in-rect, and the 2.8 s restart is
   unchanged. QA confirms in one match per mode.

Verdict rules: any code-drawn line grid or flat fill still visible = Fix. A net that still reads as a pole in test 1 = Reject (restate
the brief). Ship needs 1-8 to pass on DOME and BEACH (the WK-66a Accept) plus one Rocketball court at each zoom extreme.

## 10. Out of scope
The beach/stadium court art (WK-66). The DROPSHOT mode card (SP-17 to WK-65; its net should later match D1). The SP-15 goal-mouth growth.
Net SFX (lane A may add a soft "fwump" on the bulge; not required for this grade).
