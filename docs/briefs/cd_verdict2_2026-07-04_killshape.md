# Creative Director verdict #2 — 2026-07-04 — kill-economy-at-scale re-pass

> Second fantasy-fit pass, after the kill-economy-at-scale build. Verdict: **FIX** (big leap from
> pass 1 — make-or-break fixed — but the KILL SHAPE is wrong and the flee dynamic is crushed).
> Evidence: 16-stage full match to 10 + manual human session; 176 out-of-bounds body samples.
> Screenshots: cd2_boot.png, cd2_burst/frame_005.png, cd2_flight.png, cd2_combat/frame_009.png,
> cd2_matchend.png.

## The leap (pass-1 P0 is FIXED)
Kills fire (first-elim 4.5s), matches resolve (P2→10 in 16 stages, clean win panel), endgame closes
(1v1 ~1.5s), self-destruct-off-top GONE, flight required on both axes (fell in the pit even while
boosting; zero-boost = certain fall). Constant motion, damage escalation pervasive (d1 61/70 frames,
d2 43/70). **It is genuinely fun to watch now.** The approach is right → not RETHINK.

## THE core miss (why not SHIP): the kill is a central PIT, not an edge BLAST
Measured: **off_stage_kills = 0; 9/9 stages end ring_out; ~100% of 176 OOB bodies at the BOTTOM/central
pit; ZERO side-blast or top kills.** The founding fantasy (GAME_ESSENCE, owner directive) is "smash
rivals OFF THE SCREEN" — Smash/TowerFall/Duck-Game edge blast zones. Instead everyone dies by dropping
into a hole in the middle of the floor. Three counts:
1. **Contradicts the fantasy + the owner's edge-relative-kill directive** — the ±960 side runway (set
   wide for the recovery gamble) + side bumper posts mean the sides NEVER kill, and the super never
   spikes anyone off-screen. The blast-zone fantasy is inert; a platformer death-pit does all the work.
   NOTE the tension: the owner asked for BOTH wide runways (recovery gamble — knocked players fly back)
   AND edge-blast kills ("smash off the screen"). Wide runway defeated the edge blast; the pit filled
   the vacuum. Reconciling these two owner intents is the core of the fix.
2. **28% of deaths are UNCREDITED self-falls** = dead air in a kill-RACE (no "I killed you" beat every
   third death). The other 72% are credited knock-ins, but still "shoved you in a hole," not "smashed
   off-screen."
3. **The pit is visually INVISIBLE** (biggest felt problem): a gap between floating grass islands over a
   continuous bright-green meadow — falling in reads as standing on/through grass, like a bug, not a
   designed death. A naive human falls in constantly without understanding why (cd2_flight.png,
   cd2_burst/frame_005.png).

**CD recommendation:** KEEP the pit as a flight-required TRAVERSAL feature, DEMOTE it as a kill zone,
make the EDGES the primary blast. game-designer: make side/top blast lethal (retune near-edge band /
side runway / super spike / the side bumper posts that block exits) so "super-smash off the screen"
fires; pit becomes secondary/self-inflicted. level-designer: give the pit real danger-readability
(visible chasm/void/darkness/spikes, not safe-field green) or narrow it. gameplay-programmer: pit-fall
credit attribution to shrink the 28% uncredited.

## S6 flee — structural, not just "chase too strong"
Chase is relentless; flee is effectively invisible (RETREAT fires 5/70 frames but never completes a
heal; QA 2%). **Root cause: stages resolve in ~2–7s but the heal window is 8s — the stage ENDS before a
fleeing player can heal, especially 1v1.** Flee-to-heal is near structurally impossible at 1-life stage
pace. Lower severity than the pit (the frantic finish is fun). game-designer: reconcile the 8s heal vs
sub-8s stages (shorter heal / brief flee speed-edge / accept it lives in the 3-4p melee not 1v1) and
recalibrate the ≥25% S6 bar if the structural conflict makes it unreachable.

## Carried-over / other
- **Camera still zooms to 0.42 during 4-player COMBAT** (pass-1 §4, unresolved) → 30-40px bouncers,
  where red-pulse + aim-fuse readability matter most. Intro/2-left framing tightens to ~0.78 (good).
  art-director + gameplay-programmer.
- **Stages so fast a newcomer can die in ~1-2s before acting** — Duck-Game-fast is intended, but a
  borderline "did I even play?" for first-timers. Flag, not a blocker.
- **Audio still absent** (known P0 for "feels like a real game"; owner dependency on SFX sourcing).

## Bottom line
Not SHIP: the game doesn't yet deliver "smash rivals OFF THE SCREEN" — the kill is a green-on-green
central hole, uncredited a quarter of the time. Not RETHINK: loop, motion, flight-required traversal,
damage escalation, and a resolving kill-race all work and are fun. One more targeted round on the kill
SHAPE (edges) + the flee window.
