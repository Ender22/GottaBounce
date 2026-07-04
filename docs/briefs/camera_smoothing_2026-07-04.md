# Camera-smoothing brief — kill the zoom "pump" (owner camera-feel concern)

> Owner cares about camera feel ("flies around" / not Smash-smooth). CD verdict #5 confirmed the
> follow-cluster CONCEPT is correct and I fixed follow-TARGETING (P1 always framed + cluster hysteresis).
> This brief is the DEEPER, separate issue: the zoom TARGET pumps, so the (already-present) lerp is
> smoothing a noisy target. Diagnosed from `CameraController.gd` + `PartyMatch._update_camera()`.

## Root cause — the target zoom is recomputed noisily every tick (NOT missing smoothing)
`CameraController` DOES lerp pos+zoom toward the target at `follow_speed=6.0` (~0.17s). The jank is in how
`PartyMatch._update_camera()` (~lines 834-990) builds the target:
1. **Velocity lead is folded into the ZOOM extent** (~line 960: `p.velocity.limit_length(700)*0.32` into
   the fit-extent). Player velocity swings constantly in a bounce game → the zoom target jitters at high
   frequency → the camera chases the jitter. FIX: velocity should lead the PAN (position), not inflate
   the zoom extent.
2. **Hard launch-cam regime toggle** (~866-876, 970-973): any player > `LAUNCH_SPEED_FOR_CAM=1300 px/s`
   outward instantly drops the zoom floor 0.60→0.42, eased back over only `0.4s`. Players cross 1300 on
   nearly every smash/bounce → the floor keeps snapping out/in = the "breathing pump." FIX: remove the
   hard regime; let a fast flier's POSITION naturally widen the smoothed frame (AABB + margin).
3. **Symmetric in/out rate** — zoom-in and zoom-out lerp at the same speed. Smash's signature: zoom OUT
   FAST, zoom IN SLOW, so transient spreads don't snap-in-then-snap-back. FIX: asymmetric damping rates.
4. **No zoom dead-zone + framerate-dependent lerp** — `clampf(follow_speed*delta,0,1)` is fps-dependent
   (Freya Holmér); and small extent changes still move the target. FIX: `1-exp(-k*dt)` (fps-independent)
   + a dead-zone / min-change threshold below which the target is ignored.

## The fix model (Smash / Cinemachine standard)
Compute the AABB (or weighted centroid + extents) of the players to keep on screen → add margin → derive
zoom-to-fit → then **critically-damp** (or exp-smooth, fps-independent) BOTH pos and zoom toward it, with:
- **Asymmetric rates**: out fast, in slow.
- **Zoom dead-zone**: ignore sub-threshold target changes.
- **Velocity leads the PAN, not the zoom.**
- **No hard launch-cam floor**: keep the `CAM_MIN_ZOOM=0.60` readability floor, but let position widen the
  smoothed frame instead of a regime toggle. (Preserve the 0.60 readability floor — the reason the floor
  exists at all, see camera_2x_policy.md.)

## Fence / preserve
- Keep the follow-cluster concept + the P1-always-framed + cluster-hysteresis fix (already shipped).
- Keep `CAM_MIN_ZOOM=0.60` readability floor (bouncers must stay legible — camera_2x_policy.md).
- No change to movement/lethality/feel constants — this is camera math only.

## References (hand to the programmer)
- Itay Keren, "Scroll Back: The Theory and Practice of Cameras in Side-Scrollers" (GDC 2015 + article) — canonical.
- Unity Cinemachine Target Group + Framing Transposer (dead zone / soft zone / damping) — the productized Smash pattern.
- Freya Holmér, "Lerp smoothing is broken" — fps-independent `1-exp(-k*dt)`.
- t3ssel8r "Giving Personality to Procedural Animations" + Game Programming Gems 4 "Critically Damped Ease-In/Out" (SmoothDamp) — buttery no-overshoot damping.
- Melee reverse-engineered camera ("Magus camera" / Slippi) — bounding-box + margin + damped zoom + blast-zone framing.

## Validation
Burst-capture a smash crossing 1300 px/s BEFORE (zoom steps out then eases in = the pump) vs AFTER
(smooth, no regime snap); drive a spread-then-converge and confirm out-fast/in-slow reads smooth; confirm
players stay framed + legible (>=0.60); confirm no per-frame zoom jitter during normal bounce combat.
