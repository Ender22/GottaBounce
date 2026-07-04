# Camera Policy — 2x Arena (grassy_expanse) — Art-Director Ruling

**Date:** 2026-07-04 · **Role:** Art Director · **Mode:** STATIC (from screenshots + code; game NOT launched)
**Pillar under test:** 5 — *Readable chaos: track 4–8 players mid-storm. Readability beats prettiness.*

## VERDICT: FIX

The follow-camera is correct in spirit (Smash-style follow + tighten) and its tight framing is
genuinely good — `cd2_combat/frame_009.png` at ~0.78 reads beautifully (faces, colors, the aim-fuse
all legible). But on the wide `grassy_expanse` arena it violates Pillar 5 during the exact moment
readability matters most: 4-player combat pulls to ~0.42, shrinking bouncers to ~30px
(`cd2_flight.png`, `cd2_burst/frame_005.png`). The crimson damage-pulse rim, the super aim-fuse
ring, and faces stop reading. **Fit-to-global-spread is the wrong policy for a 3760px arena.** Ship
the tight framing behavior; replace the "fit everyone at any cost" zoom-out with a readability-floored,
action-cluster policy plus off-screen indicators.

---

## ROOT CAUSE (code)

`PartyMatch.gd::_update_camera()` (lines 707–731) does two things that force the over-zoom:

1. **It seeds the frame with the entire `stage_rect`** (lines 711–712: `mn = _stage_rect.position;
   mx = _stage_rect.end`). The frame can therefore never be tighter than the whole play area.
2. **It fits ALL living players + a velocity lead clamped to the full `bounds`** (5680px wide),
   then clamps zoom only at `CAM_MIN_ZOOM = 0.37`.

On grassy_expanse, spawns are 2960px apart (x=400 … x=3360). Fit-to-spread + airborne lead →
`z = 1920 / (2960 + margins + lead) ≈ 0.42–0.50`, bottoming toward the 0.37 floor. That 0.37 floor
was set for a *narrower* kill-zone (spec §6.3) and is far too low for this arena.

## READABILITY MATH (the numbers a floor must protect)

Native bouncer ≈ **105px** diameter (derived from the two graded screenshots: 0.78 → ~55px, 0.42 →
~29px in the 1280-wide grabs). On-screen size:

| zoom | bouncer @1080p play | bouncer in 1280 grab | verdict |
|------|--------------------:|---------------------:|---------|
| 0.42 | ~44 px | ~29 px | too small — CD reject |
| 0.60 | ~63 px | ~42 px | body/color/face/damage-pulse read |
| 0.70 | ~74 px | ~49 px | comfortable; aim-fuse reads |
| 0.78 | ~82 px | ~55 px | "reads great" (confirmed in frame_009) |

Feature-legibility thresholds (rim/ring bands scale with the body):
- **Crimson damage-pulse** (rim glow, ~12% of diameter): needs body ≥ ~60px @1080p to read as a
  distinct band → **zoom ≥ 0.60**.
- **Super aim-fuse ring** (thin stroke, ~8% of diameter): needs body ≥ ~85px @1080p → **zoom ≥ 0.80**.
  This is the most demanding element and is impractical as a global floor (see policy — it is
  protected by a *framing bias* toward the charging player, not by the global floor).

---

## THE POLICY (implement exactly)

### 1. Two-tier zoom floor (replace the single 0.37 clamp)
- `CAM_MIN_ZOOM = 0.60` — **normal combat floor.** Never zoom out past this in steady combat.
  Guarantees body ≥ 63px @1080p; color ID, face, and damage-pulse rim all read.
- `CAM_LAUNCH_MIN_ZOOM = 0.42` — **kill-cam exception.** Allowed ONLY while ≥1 living player is in
  high knockback (`velocity.length() > 1300` and heading outward toward `bounds`). Preserves the
  launch-to-blastline payoff (the whole match ends on a kill). Ease back up to 0.60 within ~0.4s
  after knockback settles. During a launch the readable content is the ARC + blast, not the fuse —
  transient zoom-out here is the Smash convention and is NOT what the CD flagged (steady-state combat was).
- `CAM_MAX_ZOOM = 0.92` — **unchanged.** This is why intro / "TWO LEFT!" tighten to ~0.78 and look
  great; keep it.

### 2. Frame the ACTION CLUSTER, not the global spread
- **Stop seeding the fit with `_stage_rect`.** Delete lines 711–712's stage-rect seed; start the
  fit from the players only.
- **Center on the living-player centroid** (average position), NOT the midpoint of extremes. The
  midpoint gets dragged by one straggler and shoves the majority to the edge; the centroid keeps the
  pack centered.
  - *Enhancement (SHOULD):* if any players are "combat-active" (dealt/took damage or firing/charging
    a super in the last 1.2s), take the centroid of ONLY those. This biases the frame to the fight.
- **Compute the zoom to fit the cluster**, then clamp to `[CAM_MIN_ZOOM, CAM_MAX_ZOOM]` (or the
  launch floor when the exception is active). Keep the existing velocity-lead, but the lead is a
  *nudge*, not a spread-forcer — cap each player's lead contribution and let the floor win.
- **Clamp the frame center** so the visible rect (`viewport_size / zoom`) stays inside `bounds` —
  never reveal the void past the blast lines.

**Consequence, accepted:** at the 0.60 floor the visible width is 1920/0.60 = 3200px. Players
spawn 2960px apart, so they *just* fit at spawn; once they spread past ~3200px or fly high, someone
leaves the frame **by design**. That is correct — readability of the fight beats keeping a fleeing
straggler pinned in a 30px-per-bouncer wide shot.

### 3. Off-screen players get indicators (REQUIRED to ship)
Any living player outside the visible rect (+ ~40px inset) gets a **chunky player-colored chevron**
pinned at the screen edge, pointing toward them. Glossy Toybox styling: rounded, glossy bevel, bold
dark outline, ~48–64px, matching the player's card color. Optional small distance pip (bigger =
closer). A player must NEVER vanish with no cue — that's where an unseen smash comes from. Standard
in Brawlhalla/Smash; non-negotiable given the action-cluster policy lets players leave frame.

### 4. Super aim-fuse framing bias (protects the ring)
The aim-fuse needs ~0.80 to read, which is too tight for a global floor. Instead, **while any player
is charging/aiming a super**, add heavy centroid weight to that player and pull the zoom target
UP toward that player + nearest opponent (target the tighter of the two, no lower than ~0.70). In a
1v1 read this naturally lands near 0.78+ and the fuse reads. The super is a headline readable moment
(CD called it out) — it earns a tighter frame at the cost of a distant straggler leaving screen
(they have an edge indicator).

### 5. Split-screen — REJECT for v0
Shared-screen chaos IS the party-brawler identity (everyone bounces off everyone; Duck Game × Smash).
Split-screen fragments cross-player readability and multiplies VFX/UI cost. Out of scope.

---

## VALUES SUMMARY (for Tuning/const)
```
CAM_MIN_ZOOM        = 0.60   # was 0.37 — normal combat readability floor
CAM_LAUNCH_MIN_ZOOM = 0.42   # kill-cam exception, only during high knockback
CAM_MAX_ZOOM        = 0.92   # unchanged
LAUNCH_SPEED_FOR_CAM = 1300  # px/s outward → engages launch floor
LAUNCH_EASE_BACK     = 0.4   # s to ease launch floor back to CAM_MIN_ZOOM
SUPER_BIAS_MIN_ZOOM  = 0.70  # zoom target floor while a super is charging
OFFSCREEN_INSET      = 40    # px; player outside visible rect+inset gets a chevron
COMBAT_ACTIVE_WINDOW = 1.2   # s since damage/super to count for centroid bias
```
Center = combat-active centroid (fallback: all-living centroid), clamped so visible rect ⊂ bounds.
Do NOT seed the fit with `stage_rect`.

## HOW THIS KEEPS COMBAT READABLE WITHOUT LOSING PLAYERS
- Worst case (max spread) is now **0.60 not 0.42** → bouncers 63px not 30px; damage-pulse reads.
- Typical combat sits **higher** than before, because the camera no longer tries to fit the global
  spread — it frames the fighting cluster, so it naturally floats 0.70–0.90 (the "reads great" band).
- A player who leaves the frame is tracked by an edge chevron, so the source of a hit is always known.
- The launch-to-death payoff still zooms out to follow the kill (0.42 exception), transiently.
- The super telegraph is protected by a tighten-toward-the-caster bias, not a punishing global floor.

---

## FEEDBACK TO LEVEL-DESIGNER (grassy_expanse is at the edge of "too wide")
The 2960px spawn spread / 3760px walkable is right at the limit where a *readability-grade* zoom
(≥0.60) can still fit all players at rest. Once combat spreads them, the camera MUST drop players
off-screen to stay readable. Two acceptable resolutions — pick one per-arena:
1. **Narrow it.** A ~2600–2800px walkable (spawns ≤ ~2400px apart) lets a ~0.68 floor fit all four
   at spawn AND keep the aim-fuse legible — no reliance on edge indicators for the common case.
   Best for the *default/tutorial* arena where clean readability matters most.
2. **Embrace the width as a design choice.** Keep 3760px as a deliberately sprawling "chase" arena
   where players DO leave frame and edge indicators + the flight-required 960px pit create long-range
   tension. Valid — but then edge indicators (policy §3) are load-bearing and must be polished, and
   this should not be the first arena a new player sees.

Recommend #1 for the primary arena; #2 only as a later "big map" variant. Either way the camera
policy above ships; the arena choice only changes how often edge indicators fire.
