# Questions + checks for the owner (collected 2026-11-16, weekend run)

The studio decided everything it could on its own (see `docs/DECISIONS.md`). These need you — no rush, nothing is blocked.

## Needs your hands / ears / machine
1. **Reboot the PC.** Both AMD adapters show errors in Device Manager since the 02:00 freeze (RX 6700S "disabled", iGPU
   "failed add"), so the game has been running on software rendering. All perf/timing numbers since then are invalid.
2. **Listen to it.** The audio mix was measured, never heard (loudness ~-17 LUFS, KO/goal payoffs on their own bus). Things only an
   ear can judge: the KO sting, the pressure-nets crowd chant (-4 dB, may dominate long rallies), the super wind-up whistle.
3. **Play with real pads.** Every check used simulated controllers (disconnect overlay, rumble routing, glyphs).
4. **Push to GitHub.** Agents can't push (safety rule). Run: `git push -u origin weekend/polish master`.

## Design questions (studio recommendation in brackets)
- **OQ-1** Brawl: LIVES 2 by default when 3+ humans play, to cut time spent dead? It's the only lever that moves the median
  "dead share" (~25 %). Conflicts with your LIVES 1 ruling. [Keep LIVES 1; we're testing a "showdown" for long 1v1 tails instead.]
- **OQ-2** A camera exception during a 1v1 showdown (slight zoom-in)? Conflicts with your camera rules 3 and 6. [No.]
- **OQ-3** Pause the 8 s damage heal during a showdown? Only if the showdown A/B fails. [No for now.]
- **WK-152** Brawl/Trials stages start zoomed in and ease out over ~15 frames (sports now snaps straight to the court). Change it?
  [Probably harmless to snap, but it's your camera area — we left it.]
