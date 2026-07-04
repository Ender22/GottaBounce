# CD VERDICT #4 — islands_void FLAGSHIP + AUDIO (integrated) — 2026-07-04

**Reviewer:** Creative Director (fantasy-fit + fun gate, GAME_ESSENCE owner).
**Build:** commit bcb4a91 (islands-over-void flagship arena + full AudioManager, both just landed).
**Method:** rendered playtest, `tools/run_game.ps1` + `tools/gbplay.py`, driven human-style input +
deterministic verb probes + natural bot combat + kill-log/round_stats telemetry + audio eval + screenshots.
**Scope vs #3:** verdict #3 blessed `grassy_expanse`. This judges the NEW flagship `islands_void` + audio
as an integrated whole.

## VERDICT: **FIX** (the bones are right; the KILL fantasy is diluted by self-inflicted void deaths)

This is not a RETHINK — islands-over-void is the correct, adopted flagship and it is genuinely
beautiful and flight-forcing. But it is not a clean SHIP either: as an integrated experience the
dominant death mode is **uncredited self-suicide into the void**, not "I smashed YOU off the screen."
The fantasy of the KILL is present mechanically but under-delivered in felt play. Fixable with
tuning + bot-AI + a metric fix, not a redesign.

---

## What genuinely delivers (keep it)

- **FLY is REQUIRED — the headline win, and it's real.** Deterministic gap A→B (680px) probes:
  - No boost (walk off edge): fell into void, died/respawned. Cannot cheese.
  - Flat horizontal boost only: gravity wins, fell into the void before crossing.
  - Proper diagonal jetpack arc (up+right+boost): crossed from x=600 to **x=2514** in ~1.6s — cleared
    a gap AND a whole island. Flight is required to traverse AND feels powerful. This fixes the
    2026-07-03 arena miss at its root. Vertical climbs to spring pads similarly require the jetpack.
- **The void reads as lethal IN MOTION.** Full-width dark chasm, matte hazard-red chevron rim, and
  live falling-mote VFX. Critters are repeatedly seen alive INSIDE the chasm boosting back — the
  recovery gamble is visibly happening (see `cd4_recover2.png`, `cd4_live/frame_005.png`).
- **RECOVER is real.** Confirmed the void band (rim y=1260 → bottom y=1920) is survivable: a player
  dropped to y=1551 is alive and can boost; death is on crossing the bottom bound, not on entering
  the chasm. Genuine gamble, not a fake floor.
- **Constant motion / no camping in practice.** Bots are perpetually airborne, bouncing, flying;
  the arena has no dead space.
- **AUDIO is a true finished-game layer.** Music playing, looping jetpack thrust voice active,
  thousands of SFX fired in combat. Event→cue wiring is CORRECT and complete (verified by emitting):
  heal→heal, pickup→powerup_pickup, dmg L1/L2→damage_1/damage_2, countdown→countdown /
  final→countdown_final, super→super_fire; plus bounce, smash (solidity-scaled), death, two_left seen
  live. All 23 SFX + 5 music files exist on disk (no silent-missing events). Coverage is comprehensive
  for the finished-game bar. Only known polish gaps remain (UI-click unwired, per-powerup activate
  variation, real announcer VO) — non-blocking.

---

## The fantasy gap (why FIX, with evidence)

**Deaths are dominated by uncredited SELF-SUICIDE into the void, not by smash-offs.** Over 6
uninterrupted islands stages (`round_stats` dump), the large majority of kills logged `killer: -1`
(no attacker — a solo fall), e.g. stages 2, 3, 4 were **entirely** killer=-1. Roughly ~25% of deaths
were credited to an attacker; ~75% were self-inflicted falls. Consequences:

1. **The "smash rivals off the screen" identity is diluted into "everyone keeps falling in by
   themselves."** Watching the arena, the story is whiffed traversals into the chasm, not epic
   knock-offs. That is the exact holistic gap this role exists to catch.
2. **The kill-race to 10 is noisy/slow.** Because a suicide decrements the aggressor's own score
   (floored at 0), credited kills get cancelled by the killer's own subsequent void death; scores
   hovered near [0–1] across many stages before anyone pulled ahead.
3. **Two compounding root causes — both integration seams, not single-spec bugs:**
   - **(a) Razor-thin traversal margin over a full-width lethal floor.** Any mistimed boost = death.
     Competent bots (L2/L3/L4) die to this constantly; my own human-style inputs died repeatedly
     (no-boost, flat-boost). The arena punishes the very traversal it forces you to do every few seconds.
   - **(b) The super over-launches the user off the narrow islands.** super_boost_impulse (2800) was
     tuned on the 2×-wide grassy arena; the islands are only 520–640px wide with void on BOTH sides.
     A deliberate human smash-off from island C (x=2950, aim right into a bot at the edge) rocketed
     P1 clear across the island and off the RIGHT bound — **P1 self-ringed-out (dead at x=4882) and
     got no credit**, while the target fell in as its own suicide. The KILL move doubles as a
     SELF-DESTRUCT button near the void. (`cd4_smashoff.png` → stage ended "P2 SURVIVES", P1 +0.)

4. **No automated gate can see this.** `_classify_blast_edge` labels EVERY void death `"pit"` (the
   void spans the full walkable x-span), so QA's kill-shape metric (K1 edge% vs pit%) is blind on
   this arena. This is precisely why the component QA passed while the integrated kill-fantasy did not.

---

## Prioritized FIX list (hand to Director → owning roles)

**P1 — make SMASHES the dominant, credited death (blocks the fantasy):**
1. **Re-tune the super vs narrow-island geometry (gameplay-programmer / game-designer + level-designer).**
   The self-launch overshoots 520–640px islands into the far void. Options (owner/GD call): modestly
   WIDEN the play-tier islands so a super doesn't clear platform+gap in one blast, and/or make the
   super impulse arena-relative rather than a global horizontal cannon (global impulse is tuned OK for
   grassy — don't just cut it and break that). Goal: committing a super near the rim kills the RIVAL,
   not yourself. Evidence: P1 super x2950→dead x4882.
2. **Bot void-avoidance / traversal-abort (game-designer bot-AI pass — ties to STATUS next-step #3).**
   L2–L4 bots flying into the chasm unprovoked is the single biggest driver of the "everyone just
   falls in" feel. Bots need real void-fear and a bail-out when a boost won't clear a gap. Evidence:
   round_stats majority killer=-1.
3. **Kill-credit / suicide economy on a full-width lethal floor (game-designer).** Widen last-
   aggressor ring-out attribution (a recent contact/smash within N s should credit a subsequent loose
   fall), and/or reconsider the self -1 penalty on this arena so aggression isn't net-negative and the
   race to 10 actually advances on smashes. Evidence: 6 stages, scores stalled ~0.

**P2 — restore visibility so this can't hide again:**
4. **Fix `_classify_blast_edge` for the void shape** so void deaths read as a bottom/void blast, not
   "pit," and QA can measure smash-off share vs solo-fall share on this arena. (Already a STATUS
   follow-up — elevate it; it's what let this slip past component QA.)

**P3 — polish (non-blocking):**
5. **Void wall rendering under the inner islands.** Only arena-SIDE dirt walls render; at high camera
   zoom the under-island space shows light-green hills, so a falling player briefly reads "safe green"
   before the dark band. Extend the dark fill / under-lip AO under inner islands so the whole floor
   reads lethal at all zooms. (Known follow-up.)
6. **Audio polish:** wire UI-click when a button .tscn exists; per-powerup activate variation; real
   announcer VO. Non-blocking.

---

## Would a first-time human want "one more round"?
Yes on movement — flying across the islands and clawing back out of the chasm feels great, looks like
the reference in motion, and now SOUNDS like a finished game. But the first-time human's own instinct
(smash the neighbor toward the void) currently kills THEM, and the round often resolves by opponents
falling in on their own rather than by a satisfying knock-off. Fix P1 and the "one more round" becomes
unqualified. Ship-blocking issues are P1(1–3); everything else is follow-up.

## Evidence artifacts (tools/out/)
- `cd4_islands_initial.png`, `cd4_intro.png`, `cd4_live/frame_00{1,3,5}.png` — arena + void read in motion.
- `cd4_arc_mid.png` — diagonal flight arc (traversal requires + rewards flight).
- `cd4_super_aim.png`, `cd4_super_hit.png` — super aim arrow + launch VFX read.
- `cd4_smashoff.png` — the self-ringout smash-off (super overshoots island → attacker dies, no credit).
- `cd4_recover2.png` — recovery gamble at the rim + falling-mote void VFX.
- round_stats / kill-log telemetry (in-session eval): killer=-1 suicide dominance, all blast_edge="pit".
