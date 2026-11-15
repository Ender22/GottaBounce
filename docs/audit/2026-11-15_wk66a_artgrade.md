# WK-66a art grade: sports nets (Dropshot net + Rocketball goals)

Date 2026-11-15 · Grader: art-director · Brief: `docs/briefs/sports_nets_2026-11-15.md` · Build: uncommitted on `weekend/polish`
Graded from in-game captures only (no Godot launch; 3 agents held the machine).

## VERDICT: **Fix**. Rocketball goals are ready to ship. The Dropshot net fails §9 test 1.

The goals are a clear win: they read as goals at every zoom, and the old debug grid is gone. The Dropshot net is well made up
close, but at couch distance it reads as a **lattice tower** (a radio mast or truss). Under the brief's own §9 rule, a net that
reads as a pole is a Reject. I am grading it **Fix**, not Reject, because the brief's direction (white toy frame, rope mesh,
"Π with knobs") is still right. The failure comes from two measured departures from the brief: the top tape is about 60% of the
height it should be, and the mesh lays exactly 2 diamonds between two parallel rails, which is the drawing of a truss. Both can be
fixed in code with the existing art. If the re-squint in F5 still fails, re-art D1 becomes the blocker (see Follow-ups).

## Step 1: blind couch squint (recorded verbatim, BEFORE reading the brief or the builder's report)

I was primed by the task title ("sports goal nets + Dropshot net") and still did not read the Dropshot object as a net.

- `WK-66a_couch_squint_480.png` (6 panels): "Top row + bottom-left: the centre object is a tall thin grey lattice mast/scaffold
  tower (radio mast / crane truss); the ends are pillar walls. Bottom-mid/right: red and blue mesh cages set into the end walls =
  goals (read instantly)."
- `WK-66a_thumb480_beach.png`: "Grey lattice tower/pylon standing on the floor in the middle; not obviously a net. Ends are just pillars."
- `WK-66a_thumb480_reef.png`: "Same lattice mast; dark gap in the floor to its right (a pit?)."
- `WK-66a_thumb480_dome_max.png`: "Lattice tower with a glowing cyan base, like a beacon/antenna/teleporter pad."
- `WK-66a_thumb480_dome_min.png`: "Shorter lattice tower; floor dark on the right half."
- `WK-66a_thumb480_long_haul.png`: "Red goal at left, blue goal at right: mesh cages in wall openings (hockey/soccer goals)."
- `WK-66a_thumb480_the_box.png`: "Same, bigger: red/blue goals, very clear."

Result: goals nameable in under 1 s at both zoom extremes (0.60 and about 0.90). Dropshot net: **not** nameable as a net on any court.

## Step 2: §9 tests

| # | Test | Result | Evidence / notes |
|---|---|---|---|
| 1 | Couch squint | **FAIL (Dropshot)** · PASS (goals) | See above. At 480 px the column is a bright 2-rail strip with a mid-value X texture and a cap barely wider than itself. The "Π" never forms: the tape is 15.2 wpx tall (art rows 83-150 at s 0.227) against 26 in the brief, and it overhangs the posts by only ~8 wpx per side. |
| 2 | Not a wall | PASS | The cream lattice and the studded white ball-columns differ in silhouette and value pattern. |
| 3 | Mesh at 0.60 | PASS (stills) | Diamonds are clear on LONG HAUL goals and on the CORAL COVE net. No moire in any still. I can't judge shimmer during shake from the 320 px recording sheet, so QA should look once at full res (non-blocking). |
| 4 | Ball in goal + bulge | PASS | `dev_bulge2`: the white ball stays readable through the 0.22 front veil with its outline intact and separates from the pale-red mesh. The mouth edge of the mesh visibly bows back around the ball, and the frame flashes white. `goal_bulge_sheet` f521-f524 show the bulge over more than 2 frames. However, the HUD's full-screen team flash covers the whole sheet from f521 to past 700 ms (see Follow-up 1). |
| 5 | Ripple | WEAK PASS | `ripple_sheet` frames 2-3 show cord kinks, visible at crop zoom. At gameplay zoom it is about 4.7 screen px inside a ~39 px panel, which you notice only if you are looking for it. Tune it up (F4). |
| 6 | DOME | PARTIAL | Min: the net is clipped at the floor line, with no steel rod and no art under the tiles. **Pass.** Max: the hem glow is on, but the floor pool is effectively invisible, because additive cyan at 0.35 on the beige tiles adds almost nothing. The cue currently reads as a "beacon base", not as "the gap is open". F3. |
| 7 | Team tint | PASS (default) / **unevidenced** (WK-27 colourway) | Default red/blue is correct on all 4 Rocketball captures. None of the frames I was given shows a non-default colourway pair. Add one capture (non-blocking: the code path is `team_col` end to end). |
| 8 | Polish at 200% | PASS | Goal crops: no seams, the caps are not stretched, no magenta/purple fringe, no flat fills, no grid, no width pulse. Mesh tiles join invisibly. The tubes tuck under the wall caps correctly ("mounted in the wall"). |
| 9 | PROTECT | not graded here | QA. |

**Accepted builder deviations:** goal frame height is mouth + ~44 wpx (post cap above the tube). It looks right in every capture,
the caps tuck under the wall caps, so this is accepted. Dropshot draw width 80 instead of 88 is accepted and superseded by F1.

## Fix list (cheap; no new art)

**F1 [BLOCKER, test 1]: enlarge the top tape + knobs with an overlay sprite (draw change, `SportsNetArt.setup_dropshot`).**
The body stays at 80 wpx. Only the knobs+tape band is redrawn bigger, uniformly scaled (not stretched):
1. Add `const DROP_TAPE_BOTTOM_SRC := 150.0` (measured: centre-column alpha ends at row 150) and Tuning
   `var net_tape_scale: float = 1.45  # WK-66a`.
2. Hide the original top cap: `_top_cap.visible = false`. The body tiles already run 2 px under the cap, so nothing opens up.
3. Add `_tape := Sprite2D` with `texture = DROP_FRAME_TEX`, `region_enabled = true`, `region_rect = Rect2(0, 0, src.x, DROP_TAPE_BOTTOM_SRC + 2)`,
   `scale = Vector2.ONE * s * Tuning.net_tape_scale`, `material = _frame_mat` (keeps the court tint and DOME clip), `modulate = tint`.
   Anchor it on the tape centre row so the tape stays where it is now:
   `H = DROP_TAPE_BOTTOM_SRC + 2; k = s * net_tape_scale; _tape.position.y = (img_top + DROP_TAPE_MID_SRC * s) - (DROP_TAPE_MID_SRC - H * 0.5) * k`, x = 0.
   Add it after `_frame` so it draws on top.
4. Point the tape dip at `_tape` instead of `_top_cap`.
Result at 1.45: tape about 116 x 22 wpx, knobs about 26 wpx, set on the tape ends outside the posts (±36 wpx vs posts ±28). On the
480 thumb that is a T-bar roughly twice as wide as the column, which is the read the brief asks for. Tuning range 1.35-1.6. **Amendment
to brief §4:** the "tape ≤ 88 wpx" bleed limit is lifted for the tape. The ball (z 40) always draws in front of the net (z 4), so a
ball skimming the tape reads as passing in front of it, never through it.

**F2 [BLOCKER, test 1]: finer mesh on the Dropshot net only (Tuning + 1 line).**
Add `var net_dropshot_tile_wpx: float = 80.0  # WK-66a` (cell 20 wpx, about 2.8 diamonds across the 56 wpx interior, so it is no
longer a 2-diamond X-brace between rails, i.e. no longer a truss). In `setup_dropshot` after `_make_mesh_mat`:
`_mesh_mat.set_shader_parameter("tile_wpx", Tuning.net_dropshot_tile_wpx)`. Goals stay at 128, so test 3 on goals is unaffected.
At 0.62 a cell is about 12 screen px, above the 10 px floor. Mipmaps are already on.

**F3 [test 6]: make the DOME floor pool visible.**
Additive cyan on near-white beige saturates to nothing. Give `_pool` its own normal-blend material (`_pool.material = null`; keep the
halo additive) and set `dome_gap_pool_alpha = 0.6`, `dome_gap_pool_size = Vector2(200, 56)`. That gives a teal smudge on the tiles
under the slot, team-neutral. Keep `dome_gap_glow_a_min/max` as they are; the hem itself reads.

**F4 [test 5]: ripple you can see from the couch.**
`net_ripple_amp_px = 11.0` (was 7) and `net_ripple_wavelength = 70.0` (was 90, so more crests fit in the 490 column). Keep
`net_ripple_time = 0.35`. The pin at the posts already prevents any frame-crossing.

**F5 [gate]: re-run test 1 with a truly blind agent.**
Hand a fresh agent the new 480 px BEACH thumb with **no** task context (do not say "sports", "net" or "volleyball") and ask "what is
the object in the middle of the court?". Ship needs "net" (or "volleyball net"). If the answer is still tower, ladder, pylon or
fence, open the re-art follow-up below as a blocker.

## Follow-ups (do not block this commit)

1. **HUD goal flash [lane UI, P2].** The full-screen team-colour wash on a score lasts more than 0.7 s at high alpha. It covers the
   bulge, the frame flash and the score confetti, which are the moments that sell the goal. Cap it at alpha ≤ 0.25 and ≤ 0.25 s, or
   make it an edge vignette.
2. **TRIALS goal_zones still draw the old line grid [P1 before release].** A code-drawn grid is a debug look (brief §9 Fix rule).
   Make it a WK-66b ticket: either a goal frame or a Trials-specific marker. This build does not cover it, so it does not block WK-66a.
3. **Colourway capture for test 7.** One frame on a non-default WK-27 pair.
4. **Contingency only: D1 re-art.** If F5 fails after F1+F2, edit D1 in the same ChatGPT chat: "top tape twice as tall (about 30%
   of the frame width), extends well past the posts, knobs 1.3x bigger". Only in that case does it block.

## Captures graded
`tools/out/wk/WK-66a_couch_squint_480.png`, `WK-66a_thumb480_{beach,reef,dome_max,dome_min,long_haul,the_box}.png`, `WK-66a_beach.png`,
`WK-66a_reef.png`, `WK-66a_dome_max.png`, `WK-66a_dome_min.png`, `WK-66a_bowl.png`, `WK-66a_long_haul.png`, `WK-66a_the_box.png`,
`WK-66a_goal_bulge_sheet.png`, `WK-66a_ripple_sheet.png`, `WK-66a_dev_bulge2.png`, `WK-66a_dev_crop_{red,blue,beachnet}.png`,
`WK-66a_dev_dome_{max,min}_crop.png`, `WK-66a_dev_goalframes.png`, `tools/out/rec/wk66a_box_goal/sheet.png`.
