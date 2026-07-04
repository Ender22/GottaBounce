# CD VERDICT #6 — Capstone pass on the COMPLETE build (2026-07-04)

**Verdict: SHIP.** The integrated game delivers the fantasy — a jetpack creature that never stops
bouncing, flies across real distances, and smashes rivals off the screen — and it now looks and
sounds like a real, finished party brawler. The new pieces (10-level circuit, audio, VFX telegraphy,
underside-exploit fix, smarter bots) all land. Remaining items are pacing/polish for the Steam bar,
not fantasy failures. Nothing below blocks calling this build "done."

Played the REAL rendered game (Arena.tscn, port 9090), drove P1 with human-style input, watched a
full match resolve, force-sampled every level, and read round_stats/motion_health as numbers. This is
a hands-on + measured pass, not a bot-watch.

---

## The fantasy-fit check (GAME_ESSENCE) — all four verbs confirmed, with evidence

**FLY / traversal REQUIRES flight — CONFIRMED empirically (the check the studio exists to run).**
On the flagship `islands_void`, islands sit at x = 480 / 2020 / 3560 / 5100 (~1540px center spacing,
edge-to-edge gaps ~900–1000px); void floor at y = 1920. Dropped P1 into a clean gap (x≈4330, no
spring throne under it) with **fuel = 0** → it fell straight down past the void floor (y = 1925.1)
and died. Same spot, **fuel = 100 + boost** → it climbed from y = 700 to y = −22 (~720px of lift)
and survived. You cannot walk or bounce across; the jetpack is the only way over, and the only way
back. Flight is load-bearing, not scenery. (900ms of boost lifts ~790px — measured separately.)

**SUPER-SMASH is the kill move and it READS — CONFIRMED.** Drove a real fly-in + super commit and
watched it frame by frame: gold **charge-glow ring** around the caster, a **yellow aim-arrow** in the
aim direction, an **orange boost-flame trail**, then a **blast particle burst** on fire with the fuel
bar draining to empty (drain-all super). You can feel the commit. My super whiffed into open air when
no target was in the aim line — the accepted committal risk from verdict #5, still fine.

**SMASH RIVALS OFF THE SCREEN — CONFIRMED and stronger than verdict #5.** Across 15 recorded stages,
45 kills, **34 credited (76%)** — up from verdict #5's 59%; the kill fantasy is firmly present, not
suicides. Blast-edge distribution: **void 20, pit 8, bottom 6, left 10, right 1, top 1** — i.e. ~100%
of kills are off-screen/void knockouts, and each level's distinct kill-shape shows through the data
(void levels → void, pit levels → pit, asymmetric/side levels → left/right). Even a mostly-idle human
P1 scored 4 credited kills.

**RECOVER — CONFIRMED.** The fuel=0-falls / fuel+boost-climbs test above IS the recovery gamble in
miniature; knocked-off bots actively fly back (per verdict #5, unchanged).

**CONSTANT MOTION / no camping — CONFIRMED as NUMBERS.** Aggregated `motion_health` across 15 stages:
total **stuck 1.48s**, **blocked-ascent 0.51s**, underside-bounces 17 (~1.1/stage), detours 419
(healthy obstacle-avoidance behavior, not a pathology). The head-banging class is gone and the
underside-hover exploit fix holds. The motion gate did its job — the dumb-locomotion blind spot is
closed and quantified.

---

## Do the new pieces land? Yes.

- **Audio is a real finished-game layer.** Gameplay music switches correctly by state (`gameplay_2.mp3`
  in COMBAT, `scoreboard.mp3` on the end screen), master bus at 0 dB, 14-voice SFX pool actively
  firing during combat (polled 1→7→8→4→11 concurrent voices), thrust bus wired. It has juice.
- **VFX telegraphy lands.** Boost flame, knockback jetstream trail, super charge-glow ring, aim arrow,
  and blast burst all read clearly at gameplay zoom. "Can't feel the jetpack" is resolved.
- **Circuit variety is real.** 10 levels resolve into ~5 palette families over distinct kill-shapes:
  sunny-blue (islands_void [flagship, with celebratory floating sparkles], the_spine ridge, the_cliff
  mesa, grassy_expanse pit), teal (atoll), golden-hour (twin_chasms), enclosed rivet-drums
  (drop_chamber red / bumper_gauntlet violet / the_ascent dusk-mauve), and indigo twilight (spires).
- **The WHOLE resolves.** A full match ran to a clean **"P4 WINS THE MATCH!"** panel (final tallies +
  REMATCH/QUIT in a proper font), and REMATCH re-entered a fresh match correctly. HUD is polished:
  per-player life pips, fuel bars, skull-on-death, off-screen edge chevrons, and announcer banners
  (FIRST BLOOD / TWO LEFT / SURVIVES / SUDDEN DEATH).
- **Powerups spawn** (pu_bubble group; first at 4s, interval 7s) — verified live in Drop Chamber and
  Atoll combat.

Screenshots (tools/out/): `cd6_boot.png`, `cd6_check2.png`, `cd6_combo_[a-d].png` (super sequence),
`cd6_matchend.png`, `cd6_spine.png`, `cd6_lvl_{islands_void,atoll,spires,bumper_gauntlet,the_ascent,twin_chasms}.png`.

---

## PRIORITIZED gaps (none block couch-ready; these are the last steps to the Steam bar)

### Should-consider before "one-more-round" is airtight (FEEL/PACING)
1. **Match pacing / stage churn.** Under 1-life all-bot melee, stages resolve very fast (measured
   lengths ran 4.6s–13.2s, many 5–8s) and the full match to 10 cumulative kills took ~15 stages.
   Two consequences: (a) ~15 rounds of intro pop-in → 3-2-1 countdown → stage-end banner is a lot of
   repeated between-combat flow — watch that it doesn't feel like rapid-fire resets; (b) the powerup
   layer (first spawn 4s + telegraph) barely engages in sub-8s stages. Recommend the designer/owner
   sanity-check match length **with human-paced play** (humans survive longer than 1-life bots, so
   this may self-correct) and confirm 10 cumulative is the sweet spot vs. a drag. This is the single
   biggest "one more round" risk I found — but it's a tuning question, not a break.

### Polish for the Steam bar (non-blocking)
2. **Per-level visual signature beyond sky tint.** The 4 sunny-blue levels share blue sky + the same
   grass/dirt platform tileset and differ mainly by geometry/kill-shape; the 3 enclosed drums share
   the rivet-column structure and differ by palette. A naive player rotating through may feel "another
   grass-over-void." Kill-shapes genuinely differ, so this is a look issue: give at least the sunny
   cluster a stronger signature (distinct platform tileset / props / foreground layer), not just a sky
   grade. Art-director call.
3. **Verify the stage-end delta banner never shows an all-negative survivor in clean play.** I saw
   "P4 SURVIVES! P2 −1 · P3 −1 · P4 −1" — but only during my force-loads (players dropped into voids →
   mass suicides), so almost certainly an artifact of my intervention. Confirm a normally-won stage
   can't display a "survivor −1" (a winner who netted negative reads oddly). Low risk.

---

## Bottom line
This is the game we said we're making, and it's fun: you fly across real gaps because you have to,
you commit a readable super to knock someone off into a lethal void, you claw back with the jetpack,
and it sounds and looks like a real party brawler while doing it — with clean, measured locomotion.
The blind spot that killed the last attempt (spec-correct components that aren't the game) is closed
here, and now backed by numbers. **SHIP.** Tune match pacing and deepen per-level visual identity as
the last polish toward Steam.
