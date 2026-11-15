# Art brief: TRIALS ball goals (WK-66b, from the WK-66a art grade follow-up 2)

Date 2026-11-15 · Author: art-director · Backlog WK-66b [P1][M], lane V (`GoalZone.gd`, `SportsNetArt.gd`, `levels/courses/*.json`)
Parents: `docs/briefs/sports_nets_2026-11-15.md` (the net kit), `docs/audit/2026-11-15_wk66a_artgrade.md` (follow-up 2)

The programmer and the level-designer build this exactly as written. I grade it from in-game screenshots only, using the tests in section 9.

**New art needed: NO.** Everything is built from the shipped WK-66a kit (`goal_frame.png`, `net_mesh.png`, `net_mesh.gdshader`,
`net_frame.gdshader`) plus `fx/puff_soft.png`. The only new code is a horizontal stretch of the existing goal frame (section 4),
a trials colour path, and four optional display-edge fields in the course JSON.

## 0. Correction to the ticket's premise. Read this first.

The ask was "the goal is a FINISH target: fly here to win". **That is not what these courses are.** All ten `goal_zone` courses
(`s3_*` x8, `t_ball_cannon`, `t_bank_shot`) have `objective.win = "ball_in_goal"`. The **ball** must enter the zone. The player
crossing it does nothing. The fly-here finish already exists and already has its own look: `GoalGate`, the gold ring with the
down-chevron ("FLY INTO THE GOLD RING", `tools/out/wk/WK-35_trials_objective_panel.png`). No course uses both.

So a finish flag, portal or ring would be **actively wrong** here. A newcomer would fly into it, nothing would happen, and the
ball would sit there unexplained. Worse, it would blur the one distinction Trials has to teach: **ring = you go here** versus
**goal = the ball goes here**. The right object is the one every human on a couch already knows: **a soccer goal**. The game's
Rocketball goal from WK-66a already reads that way at every zoom ("red/blue goals, very clear", WK-66a grade step 1). Trials gets
the **same goal**, re-coloured to a neutral objective gold and made to fit any rectangle. One "goal" object across the whole game
means players learn it once.

What separates the two Trials targets at a glance:

| | GoalGate (fly-to finish) | Trials ball goal (this brief) |
|---|---|---|
| Shape | round ring + down chevron, hovering | side-view cage: tubes on 3 sides, open mouth, rope mesh |
| Who enters | the goat | the ball (white with a gold band, always in the same frame) |
| Read | "pass through here" | "put the ball in here" |
| Colour | gold ring + green inner ring | gold tubes + pale-gold mesh + dark pocket shade |

Both are gold, on purpose. In Trials, gold means "the objective" (gold ring, gold tokens, gold key, the ball's gold band). Shape tells
you who the objective is for. Section 9 test 2 checks that the two never get confused.

## 1. What is wrong now

`tools/out/s3_keyhole_01.png`, `tools/out/pinball_scored.png`, `tools/out/s3_wallpass.png` (July captures; the draw path is unchanged
since, `GoalZone._draw`):
- The goal is a flat **red** outlined rectangle with a 4x6 line grid. It is a debug overlay. It is also a team colour in a mode
  with no teams.
- It pulses wider and narrower, a non-uniform stretch, which is banned.
- On a score it floods with a flat green rect (`pinball_scored.png`: a green slab over the art, under "SOLVED!").
- There is no frame, no depth and no net material. At 480 px it reads as "a selection box", not as a goal.
- Data bug that affects art: every trials goal has `team: 0` and no `mouth`, so `_mouth_dir()` says the mouth faces **right**. In
  8 of 9 visible goals the ball actually arrives from the **left**. The score confetti fires into the back wall.

## 2. Decisions

- **Object:** the WK-66a Rocketball cage (`goal_frame.png`), side view, mouth facing the ball's arrival. Same tube thickness and the
  same caps as Rocketball, at the **same 4 src px per wpx scale (s = 0.25)**. It is never uniform-scaled up for a big zone.
- **Any rectangle:** the frame becomes a 9-slice. The vertical 3-slice already exists. Add a horizontal extension of the top and
  bottom tubes (section 4). Tubes, elbows and caps keep **constant world size**, from a 300x320 pocket to the 700x620 Long Ball goal.
- **Colour:** neutral objective gold through the existing gradient-map path (`tint_mode 1`). No team colours. Section 5.
- **Mesh:** the shared `net_mesh.png` at the standard 128 wpx tile, pale gold, over a **dark pocket shade** (chocolate veil). That gives
  the pale cords value contrast on a bright sky. A side effect is the "pocket" read: dark inside means a hole you put things into.
- **Mounting:** where a bumper wall, floor or crossbar sits next to a zone edge, that edge's tube snaps to the platform face and tucks
  **behind the platform art**, the same "mounted in the wall" read as Rocketball. Where nothing is adjacent, the goal is
  free-standing (floating goals are normal in the toybox; every platform floats). Section 3.
- **No front veil** in Trials (Rocketball's cords-only veil at z 42 is dropped). A near-miss ball that overlaps the zone edge would
  otherwise look "in the net" without scoring. The real in-net moment is covered by the bulge and the SOLVED beat.
- **Collision is unchanged** (PROTECT). The frame is display only. The trigger stays the centre-in-rect `w x h` zone. No collider
  is added, so every derived shot in the course `design_intent` stays valid.
- **Delete** `GoalZone._draw`'s legacy path (grid, rim, width pulse, green flood). After WK-66b every non-hidden `goal_zone` draws
  either the Rocketball cage or the Trials cage. A zone with no net data gets the Trials cage at its own edges. **The grid must be
  unreachable.**

## 3. Layout rules for an arbitrary rect

### 3a. Anatomy (mouth "left" shown; "right" = the same sprite set with `flip_h`, allowed because the art is lit from directly above)
```
   o==========TOP TUBE===========\\      <- mouth cap "o" (42 wpx ball) at the mouth plane; top tube on the zone top edge
   |  .  .  .  .  .  .  .  .  .   ||        (or on the snapped crossbar / roof face)
 M |  rope mesh (pale gold)       ||     <- BACK TUBE on the back edge (or tucked behind the adjacent bumper wall)
 O |  over a dark pocket shade    ||
 U |  .  .  .  .  .  .  .  .  .   ||
 T |                              ||
 H o==========BOTTOM TUBE========//      <- on the zone bottom, or RESTING ON THE TURF when a floor is under it
 ~~~~~~~~~~~~~~ turf ~~~~~~~~~~~~~~~~~      (the turf art overlaps the tube's lower edge)
```
- **Display edges.** Four values, each defaulting to the zone edge:
  `mouth_x` (mouth plane, where the caps sit), `back_x` (back tube centre line, or the wall face it tucks behind),
  `top_y` (top tube centre), `bottom_y` (bottom tube centre).
- **Snap rule (level-designer applies it, written into the JSON, never auto-detected):** if a solid platform face is parallel to a
  zone edge, at most **80 wpx** outside it (`trials_goal_snap_max`), and covers at least 70% of that edge, set that display edge to the
  face. Then the tube tucks under that platform's art. Why 80: the ball centre can never come within 60 wpx (its radius) of a face,
  so at most 20 wpx of "looks inside, doesn't score" ground is created. Never snap across a gap wider than 80 wpx.
- **Floor rule:** if a floor top is within 0-80 wpx of the zone bottom (inside or outside), `bottom_y = floor_top - 10`
  (`trials_goal_floor_sink`). The tube rests on the turf, and the mat's raised lip overlaps its lower ~6 wpx (z order, section 8).
- **No tube over a void.** A bottom tube must not bridge a pit or deck gap of more than 40 wpx. A tube there looks like a ledge you
  can land on, and the ball falls through it. If the zone's mouth side overhangs a gap, move `mouth_x` to the floor edge
  (see `s3_tap_in` in 3c).
- **Mouth direction is mandatory in Trials JSON** (`"mouth": "left"|"right"`). It faces the side the **intended solve** enters
  through. It drives the frame flip, the bulge direction and the confetti direction.
- **Up/down mouths:** no visible goal uses one today (`s3_trapdoor` is `style: hidden` and stays invisible). If one is authored later,
  rotate the whole assembly by ±90°. The highlight is centred, so this is acceptable, but grade it before shipping.

### 3b. Aspect range (constant tube = constant language)

| Case | Example | Rule |
|---|---|---|
| Wide (depth > height) | Pinball Alley 550x300 | Top and bottom tubes extend through the horizontal middle tiles. The back tube is short. Caps and elbows unchanged. |
| Square | Top Corner 320x320 | Both extensions are small. Still the full cage. |
| Tall (height > depth) | Bank Shot 300x520, Ball Cannon 420x560 | The back tube tiles vertically (existing 3-slice). The top and bottom tubes need ~0-1 middle tiles. |
| Huge | Long Ball 700x620 | Both extensions. Tubes stay 31 wpx. Do **not** scale up for presence: the mesh area and the gold outline carry it. |
| Minimum | depth < 120 or height < 140 wpx | Fall back to the WK-66a uniform-scale rule (`build_whole`, fudge ≤ 10%). No current goal is this small. |

### 3c. Per-course data (level-designer writes these; I derived them from the platform rects)

| Course | Zone (L-R, T-B) | mouth | Display edges to write | Notes |
|---|---|---|---|---|
| s3_tap_in | 2420-2820, 620-1140 | left | `net_back_x` 2840 (wall face), `net_bottom_y` 1090, `net_mouth_x` **2550** | Deck gap x2350-2550 under the zone's mouth end. Caps go at the apron edge, never over the pit. Accept the 130 wpx early-trigger margin as generosity: the zone stays as is and the derived weakest-touch solve stays valid. |
| s3_top_corner | 1600-1920, 360-680 | left | `net_back_x` 1900 | A pocket mounted high on the wall, top and bottom free. That is literally a "top corner". |
| s3_wall_pass | 1700-2050, 700-1100 | **right** | `net_back_x` 1640 (blocker right face), `net_top_y` 640 (crossbar underside), `net_bottom_y` 1090 | The solve re-enters from the right, after the back-wall carom. The elbows tuck under the blocker and crossbar art. |
| s3_hazard_striker | 2270-2630, 640-1120 | left | `net_back_x` 2600, `net_bottom_y` 1090 | The lip guard at 2180-2250 sits just in front of the bottom cap. That is fine. |
| s3_keyhole | 1610-2010, 720-1080 | left | `net_mouth_x` 1560 (slot wall inner face), `net_back_x` 2080, `net_top_y` 700 (roof underside), `net_bottom_y` 1090 | The caps tuck behind the slot wall, so the slot itself reads as the mouth. |
| s3_long_ball | 2550-3250, 520-1140 | left | `net_back_x` 3300, `net_bottom_y` 1090 | The biggest goal. Section 9 test 5 is graded here. |
| s3_pinball_alley | 1750-2300, 800-1100 | left | `net_back_x` 2320, `net_top_y` 720 (roof underside, gap 80 = allowed), `net_bottom_y` 1090 | The 1900-1960 post draws over the mesh (platform z above the net), as intended. |
| t_ball_cannon | 1540-1960, 340-900 | left | none (free-standing, floating) | Entry descending from the left. |
| t_bank_shot | 1030-1330, 560-1080 | **right** | none (free-standing, floating) | Entry descending down-left off the x1600 wall, so the mouth faces the wall. |
| s3_trapdoor | — | — | none | `style: hidden`. Untouched. The broken floor tile is the mouth. |

Every visible trials zone also gets `"style": "trials"`. Values like 1090 above are floor top 1100 − 10. The level-designer
re-measures from the JSON at build time, and if a platform moved, applies the 3a rules, not my numbers.

## 4. How the frame stretches (code, existing art)

`goal_frame.png` is 680x1704: back tube on the LEFT, elbows with 2 bolts each, open mouth on the RIGHT with round end-on caps.
- **Vertical:** unchanged. ThreeSlice with `GOAL_CAP_FRAC 0.13`, the back tube tiles.
- **Horizontal (new):** cut the source into three columns: **left** (back tube + elbows, src x 0..~185), **middle** (the plain tube run,
  inside src x ~190..~485), **right** (caps, src x ~490..680). The left and right columns are the existing vertical 3-slice built per
  column at s = 0.25. The middle column has only two visible pieces, the top-tube strip and the bottom-tube strip (its middle rows
  are empty). These **tile** horizontally under the ThreeSlice rule (correction factor 0.85-1.20 per tile, add a tile rather than exceed
  it).
- **Intake measurement (programmer, before wiring):** I measured the top band (rows 30-160) as uniform across about x 185-490 (column
  delta ≤ 0.4/255, sampled every 20 px). Confirm the exact range per pixel column on **both** the top and bottom bands, max delta
  ≤ 1.0/255. The tube's gloss streak has rounded ends near x≈215 and x≈470, so pick the tile strip strictly inside the streak's
  constant run. Write the cut points as constants next to `GOAL_TUBE_C_SRC` (`GOAL_MID_L_SRC`, `GOAL_MID_R_SRC`).
- Mirroring for `mouth: left`: flip the whole assembled frame (as team 1 does today). Never flip individual tiles.
- Rocketball goals keep calling the old path, or the new one with zero middle tiles. **They must render pixel-identical** (test 10).

## 5. Palette (hex)

| Use | Hex / value | Notes |
|---|---|---|
| Outline | `#3B241B` | survives the gradient map (authored) |
| Frame gold (gradient-map target, `tint_mode 1`) | `#FFB21E` | Saturated objective gold, hue ~39°. Sits between PUFF `#FFC93F` (44°) and BILLY/safety orange (18-22°). Highlights stay near white, shadows go amber. |
| Mesh (plain modulate) | `lerp(#FFB21E, white, 0.55)` ≈ `#FFDC9A`, alpha 0.95 | Pale gold cords. Not white (a white mesh would merge with the white bumper walls behind it). |
| Pocket shade (mesh shader `veil`) | `#3B241B` at alpha **0.16** | Chocolate, not navy: navy veil + gold tubes would echo the reserved blue+yellow trampoline pair. |
| Score flash | frame to `#FFFFFF` for 0.08 s, back to gold over 0.4 s | Existing WK-66a flash, retargeted. |
| Solved glow | `fx/puff_soft.png` additive, `#FFD86B`, behind the frame at z −3, size (frame w + 120, frame h + 120) | Alpha breathes 0.35↔0.50 at 1 Hz (alpha only, never scale). Holds until stage end. |
| Score confetti | layer 0 `#FFB21E`, layer 1 white `#FFFFFF` (both with the existing white-hot birth) | Replaces `TEAM_COLORS[1 - team]` + GOLD for `style: trials`. |

Reserved-colour check: no `#FF4FA3` magenta family, no safety orange, no blue+yellow rim/canvas pair. Red and blue team colours are
not used anywhere in a trials goal.

## 6. Motion and feedback

- **Idle "the net breathes" (attract cue, required):** every `trials_goal_idle_period` = 2.6 s, inject one synthetic ripple through
  the existing `on_contact` path at a random interior y. Amplitude `trials_goal_idle_amp` = 3 wpx (ripple shader, mesh only, frames
  rigid). It is meant to be noticed by an eye scanning for "the thing", never to read as hit feedback. Stop it after the score.
- **Near-miss:** the ball hitting a bumper that the frame is tucked behind ripples the mesh. This reuses `_tag_goal_colliders`
  (it works for Trials once the frame rect includes the snapped edges). Floating goals have no colliders, so no near-miss ripple
  there. That is correct, because nothing was hit.
- **Score ("reached"), in order on the latch frame:** (1) mesh bulge away from the mouth (existing spring, radius 90, peak 20,
  settled by 0.6 s); (2) frame white flash; (3) gold+white confetti out of the **mouth** (now pointing the right way, via the explicit
  `mouth`); (4) the solved glow fades in over 0.2 s and holds; (5) the idle breathing stops. No green flood, no rect fill, no scale
  pulse on anything.
- **SOLVED! banner:** it currently centres on screen and can overlap the goal (`pinball_scored.png`). That is not in this ticket's
  files. Flag it to lane U only if test 6 shows the banner hiding the bulge in more than half of the 10 courses.

## 7. Size math at trials framing

Trials framing seen in captures runs about 0.65-0.92 (ball diameter 120 wpx measured at ~80-105 screen px in 1920 equivalents).
Co-op spread can push wider, so I check 0.55 as the floor. The legibility floor is ~10 screen px for any detail.

| Element | World px | @0.55 | @0.69 | @0.92 | Verdict |
|---|---|---|---|---|---|
| Tube thickness | 31 | 17 | 21 | 29 | ok |
| Mouth cap | 42 dia | 23 | 29 | 39 | ok |
| Mesh cell | 32 | 18 | 22 | 29 | ok, diamonds read |
| Mesh cord incl. outline | 7 | 3.9 | 4.8 | 6.4 | texture only (the frame carries the silhouette) |
| Smallest goal (Top Corner) | 320x320 | 176 sq | 221 sq | 294 sq | ok, ball (120) visibly fits |
| Largest goal (Long Ball) | ~750x630 framed | 413x347 | 518x435 | — | ok. At 0.92 it may not fit the frame. Fine, the mouth side is what must be on screen. |

## 8. Build and layering (programmer)

**Data (level-designer, `levels/courses/*.json`, lane V):** for each row in 3c add `"style": "trials"`, `"mouth"`, and the listed
`net_mouth_x` / `net_back_x` / `net_top_y` / `net_bottom_y`. Two new optional keys: `net_top_y` and `net_bottom_y`
(display only, like the WK-66a pair). The zone `x, y, w, h` must not change.

**Code (`GoalZone.gd`, `SportsNetArt.gd`, Tuning block `trials_goal_*`):**
- `GoalZone._build_net_art`: `style == "trials"`, or any non-hidden zone without net data, calls a new
  `SportsNetArt.setup_trials_goal(zone, rect_display, mouth_dir)`. `rect_display` is built from the four display edges, defaulting to
  the zone edges.
- `setup_trials_goal` = `setup_goal` minus the front veil, plus the horizontal middle tiles, the gold colour path, the solved glow and
  the idle ripple. Share the helpers. Don't fork the bulge or ripple code.
- `_score_burst`: for `style: trials`, gold + white layers (section 5).
- Delete the legacy body of `GoalZone._draw`. Keep the centre-in-rect latch, the combat gate and `_score_burst` exactly as they are
  (PROTECT).

**Draw order (z, absolute):**

| Layer | z | Notes |
|---|---|---|
| Backdrop / clouds | −100…−80 | unchanged |
| Solved glow | −3 | additive, behind the cage |
| Mesh + pocket shade | −2 | under the platform art |
| Frame (tubes, elbows, caps) | −1 | under the platform art (z 0), so snapped tubes tuck under walls, roofs and the turf lip |
| Platforms / bumpers / turf | 0 | overlap the tucked tube ends and the bottom tube's lower edge |
| Ball | 40 | **always fully visible, in front of the whole goal.** A ball passing an edge without scoring reads as passing in front (the WK-66a F1 precedent). |
| Confetti | 60 | unchanged |

**Tuning (all new, `# WK-66b`):** `trials_goal_color #FFB21E`, `trials_goal_mesh_white_mix 0.55`, `trials_goal_mesh_alpha 0.95`,
`trials_goal_shade_alpha 0.16`, `trials_goal_snap_max 80` (doc value for the level-designer), `trials_goal_floor_sink 10`,
`trials_goal_glow_color #FFD86B`, `trials_goal_glow_a_min 0.35`, `trials_goal_glow_a_max 0.50`, `trials_goal_idle_period 2.6`,
`trials_goal_idle_amp 3.0`.

## 9. Grading tests (screenshots and recordings only)

Capture at 1920x1080 at default trials framing, one port per lane. Shots: all 9 visible courses at spawn, plus a score moment on
Long Ball, Top Corner, Wall Pass and Bank Shot. Also one 4-player co-op spread frame on Long Ball (the widest zoom).

1. **Couch squint (blind):** downscale each spawn frame to 480 px wide. Hand a fresh agent the 480 px Keyhole, Long Ball and
   Ball Cannon thumbs with **no** task context (don't say "goal", "soccer" or "ball") and ask: "what is the player trying to do in this
   level?". Ship needs "get the ball into the goal / net" on all three. If an answer says "fly into the box / portal / cage" = Fix
   (apply lever L1). If it reads as a selection box, grid or crate = Reject.
2. **Ring vs goal:** put the 480 px tutorial-ring thumb (`WK-35_trials_objective_panel.png` style) next to a goal thumb. The blind agent
   must say the ring is for the character to pass through and the goal is for the ball. If it calls both "targets to fly into" = Fix (L1).
3. **Not a bumper, not a ledge:** the frame must not merge with the white studded bumper wall behind it (gold against grey, judged at
   480 px). No tube bridges a void (Tap-In apron check). No goat is seen trying to stand on a floating bottom tube in the co-op
   recording. If the bots or the recording show one landing there, report it; that is a readability lie.
4. **Goat contrast:** a PUFF (yellow `#FFC93F`) goat flying in front of the gold frame stays trackable at 480 px (chocolate outline and
   eyes separate it). If it vanishes, darken `trials_goal_color` toward `#F2A516` before anything else.
5. **Any-size consistency:** at 200% crops of Long Ball (700x620), Top Corner (320x320), Pinball (550x300) and Bank Shot (300x520) at
   the same zoom, tube thickness and cap diameter are equal within ±2 screen px. There is no smear or repeat seam in the extended
   tubes, the caps are round, and no elbow is stretched.
6. **Score moment:** the bulge is visible in ≥ 2 consecutive recorded frames and settled by 0.6 s. The frame flashes white. The
   confetti exits the **mouth** side (not into the back wall). The glow holds until stage end. No green or flat fill at any point.
7. **Mesh at 0.55:** the diamonds are visible in the co-op wide frame, with no moiré or shimmer in a recording during camera motion
   (mipmaps first if it fails). The pocket shade gives the cords visible contrast against the pale sky.
8. **Polish at 200%:** no line grid, no rect rim, no width pulse, no magenta fringe, no seams. Snapped tubes are hidden behind their
   platform art with no gap or double bar (Wall Pass crossbar, Keyhole roof, Pinball roof).
9. **PROTECT regression:** every course still solves with its documented solve (QA: one solve per course, or the existing trials
   solver/bot). Centre-in-rect detection and the 2.8 s reset are unchanged. `s3_trapdoor` still shows nothing.
10. **Rocketball regression:** LONG HAUL and THE BOX goals are pixel-identical to the WK-66a capture (`WK-66a_thumb480_long_haul.png`,
    `_the_box.png`).

**Levers if a test fails (in this order, all with no new art):**
- **L1 (readability: "fly into it"):** a ghost-ball pictogram. Draw `objects/ball.png` at 0.55x ball size, white-silhouetted at
  alpha 0.28, centred in the pocket, with a 1.5 s, 6 wpx vertical bob (translate only). It says "the ball goes here" with no text.
  Hide it on score.
- **L2 (presence on huge goals):** raise `trials_goal_shade_alpha` to 0.24. Never thicken the tubes.

**Verdict rules:** any grid, flat fill or width pulse still visible = Fix. A goal that reads as a fly-through target in test 1 or 2 after
L1 = Reject (restate the brief). Ship needs 1-8 on all 9 courses, plus 9 and 10 confirmed by QA.

## 10. Out of scope
- Off-screen goal indicator at spawn (Keyhole's goal starts partly off-frame in `s3_keyhole_01.png`). That is a camera/HUD ticket if
  CD wants it.
- The SOLVED! banner placement (lane U, see 6).
- A goal SFX (lane A may reuse the Rocketball "fwump").
- Up/down mouth art, until a level needs it.
