# Owner feedback — 2026-07-10 — CAMERA (repeated ~5x; still wrong)

**Source:** owner message 2026-07-10. He has raised the camera "like 5 times" — treat every prior
"camera fixed" claim (incl. STATUS 2026-07-05 "frames ALL living players / oscillation fix") as
NOT owner-accepted. This doc is the acceptance spec, in his own rules.

## Verbatim (lightly trimmed)

> the camera is still so wonky and still needs work. it hardly ever has all players on screen and
> it flies left and right so quickly. player can be standing on a left platform of the level and a
> right platform of a level and not both be in the viewport, that doesnt make any sense. the rules
> are: every level has 'camera bounds' which goes i.e. 200 pixels left past the leftmost platform
> and 200 pixels to the right of the rightmost platform, 200 px above the topmost platform and
> 200px below the bottom most. if a player is within the level camera bounds they are 100% always
> shown by the camera (the camera may just need to smoothly zoom out) in the X the camera always
> points to the middle point of furthest left and furthest right player (as long as those players
> are not past the level bounds in which case the level bound position is used instead), and
> similar for the camera Y. the camera motions should be smooth. players are only not within the
> camera viewport if they are beyond the bounds of the level. and of course there should also be a
> max zoom, and at max [zoom] level most of the level should be shown (i.e. even if 2 players left
> dont get too close to them)

## The rules, decomposed (acceptance criteria)

1. **CAMERA BOUNDS per level** = platform extents padded ~200px on every side (left/right/top/bottom
   of the extreme platforms). Derived from level geometry, not hand-authored.
2. **HARD INVARIANT:** a player inside the camera bounds is ALWAYS inside the viewport — 100% of
   frames, no exceptions. Zoom out (smoothly) as far as needed to honor this.
3. **TARGETING:** camera X = midpoint of leftmost & rightmost player X, where each player's X is
   first CLAMPED to the camera bounds (a player beyond the bounds contributes the bound edge, not
   their true position). Same for Y.
4. **SMOOTH:** no rapid left/right flying. Position and zoom both move smoothly.
5. Players may be off-viewport ONLY when they are beyond the level's camera bounds (off-screen-kill
   space).
6. **ZOOM-IN CAP:** even with 2 players close together, do not zoom in tight — at the closest
   allowed zoom, MOST of the level is still visible.

## QA note

Validate with MOTION evidence, not stills ([[gottabounce-validate-motion-not-just-outcomes]]):
scripted worst cases (players parked on extreme left+right platforms; one player dead-and-outside
bounds; 4-player scatter) + burst sequences measuring (a) any frame where an in-bounds player is
off-viewport (must be ZERO), (b) camera velocity spikes (smoothness), (c) zoom-in floor respected.
Owner accepts this only by his own eyes eventually — do not mark owner-accepted without him.
