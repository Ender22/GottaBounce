# Owner feedback — 2026-07-10 — UI audits required; ArenaSelect fails the bar

**Source:** owner message, 2026-07-10, reacting to a live ArenaSelect screenshot (post-Foundry, 17 cards).

## Verbatim (lightly trimmed)

> add to the list to do UI audits of the screens, like a UI agent would not approve this — it's a
> screen that doesn't show which game mode you are in, has tiny tiles and graphics, the spacing of
> the tiles aren't uniform, there is no space for expansion, the controls in bottom left overlap
> with tiles, and so on and so on. i think a UI agent would probably call for larger tiles in a
> carousel so that any number could fit and there would be lots of breathing room etc. im sure
> there are many other screens with similar issues

## Confirmed defects on ArenaSelect (from the same screenshot)

1. **No mode context** — nothing on the screen says you are configuring a BRAWL match.
2. **Header occluded** — "PICK YOUR PEAK" is hidden BEHIND the top card row (only letter fragments
   visible between the LOCKED ribbons).
3. **Tiny tiles / art** — 340x210 cards with ~60px art plates; thumbnails unreadable at couch distance.
4. **Non-uniform spacing / overflow** — 17 cards (6 circuits + RANDOM + 11 arenas — grew again with
   THE FOUNDRY) jammed into a fixed 4-col grid; the last row bleeds off the bottom of the screen.
5. **No expansion room** — every new circuit/arena makes it worse; the layout has no scroll/paging model.
6. **Footer overlap** — the A/B/</> control hints overlap the bottom-left tile.

## Owner's suggested direction

Larger tiles in a **carousel** (or equivalent scalable container) so ANY number of entries fits with
breathing room. Not prescriptive — the ui-ux-designer owns the final layout — but "big tiles +
scales with content + breathing room" is the bar.

## Actions

- UI-UX audit of EVERY front-end screen (title / ModeSelect / CharacterSelect / ArenaSelect /
  Options / Pause / per-mode HUD chrome) against this class of defect: context, scale-with-content,
  couch readability, uniform spacing, safe-area/footer collisions.
- ArenaSelect redesign to the audited spec (carousel-class layout, mode context visible).
- Sports court-select UI (already on the backlog) must be designed inside the SAME layout system —
  do not bolt another fixed grid onto a screen class that just failed its audit.
