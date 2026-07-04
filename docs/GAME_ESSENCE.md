# GAME ESSENCE — what this game IS, and the fantasy-fit check every role must run

> **Required reading for EVERY role (game-designer, level-designer, art-director, gameplay-
> programmer, qa-playtester, creative-director) and the Director, before starting AND before saying
> "done."** VISION.md states the pillars; this doc turns the fantasy into OPERATIONAL checks you
> are OBLIGATED to run. Born from a real miss (2026-07-03): the studio built a bounce-and-FLY game
> on an arena so cramped that flight was never needed, and NO role caught it — because no brief made
> "is the core fantasy actually happening?" a thing anyone had to verify. This doc fixes that.

## The fantasy in one breath
You are a jetpack creature who **never stops bouncing** and **flies across real distances** to
**smash rivals off the screen**. The joy is MOVEMENT — the arc of a boost, the commit of a super,
the clawing recovery after a hit. If a build is mechanically correct but the player isn't
constantly *moving, flying, and smashing*, it is WRONG even if every spec criterion passes.

## The core verbs (the game is these; a build that doesn't exercise them fails)
1. **BOUNCE** — every surface launches you; you never settle.
2. **FLY / BOOST** — the jetpack moves you across the arena. **Traversal must REQUIRE flight** — if
   you can reach everything by bouncing, the core mechanic is dead.
3. **SUPER-SMASH** — the aimed super is THE kill move; flying head-first into someone.
4. **RECOVER** — knocked out toward the edge, you fight your way back (the recovery gamble).

## THE FANTASY-FIT CHECK (run it from first principles, as a naive human, before "done")
Do not only ask "does mechanism X meet its spec." Ask: **"Played as a human, is the CORE FANTASY
actually happening?"** Concretely, every feel/level/build review must answer, with evidence:
- Is the player **airborne and using the jetpack** a meaningful fraction of the time, or standing/
  bouncing in place?
- Do **distances REQUIRE boost/super** to cross, or is everything within a bounce? (The arena miss.)
- Is the **super the decisive kill move**, and does it feel like flying head-first into someone?
- Is there **constant motion** (Pillar 2) — can anyone camp or stall?
- Does it **look and feel like the reference (Duck Game / TowerFall / Smash) IN MOTION**, not in a
  still screenshot?
- Would a **first-time human** understand what's happening and want "one more round"?
If any answer is "no," the build is not done — regardless of green criteria. Say so and fix it.

## Per-role obligation (translate the fantasy into YOUR gate)
- **Level designer:** prove, with a movement-tool-per-gap analysis, that **flight is required** to
  traverse your arena (gaps > a bounce's reach; upper platforms above spring-apex). A level that can
  be played without boosting is REJECTED. Vertical AND horizontal distance are load-bearing, not scenery.
- **Game designer:** every spec states which **core verbs** it exercises and how the build will be
  measured to be USING them (not just "the mechanism works"). Reason from the fantasy down, not the
  feature up.
- **Gameplay programmer:** when you build a mechanic, note which core verb it serves and flag if the
  current level/setup won't actually exercise it.
- **Art director:** grade whether the art reads the fantasy IN MOTION at gameplay zoom, and whether
  character/shape choices carry the fantasy (e.g. shape affects the super-smash sweet spot — a
  gameplay lever, not just a look).
- **QA / playtester:** drive with **human-style input** (not only bots — bots play whatever the level
  allows and never say "this feels cramped"), and report the FELT experience in plain language + the
  core-verb measures, not only pass/fail against criteria. **Watch MOTION, not just outcomes:** run
  burst sequences / trajectories and read the **bot-motion-health** metrics in `round_stats`
  (`stuck_episodes`, `underside_bounces`, `blocked_ascent`, `detours` — `PartyMatch.bot_motion_health()`).
  Aggregate outcome stats (kill%, off-screen%) HIDE dumb motion — a bot can head-bang for seconds and
  still score. Any locomotion pathology (head-banging, stuck, camping, jitter) is a FAIL to report even
  if every outcome number passes. (Born from a real miss: bots head-banged platform undersides for a
  whole build and no role caught it because we only measured outcomes — 2026-07-04.)
- **Creative director (new role):** own the holistic "is this the game we said we're making, and is
  it fun?" pass on the INTEGRATED build. See `.claude/agents/creative-director.md`.

## The meta-lesson
The studio is strong at *building components to spec and verifying components*. Its blind spot is
*validating the integrated experience against the fantasy, as a human would feel it*. Bots don't
complain; specs describe mechanisms; every role optimizes its slice. Guard against it here, every time.
And when you find a blind spot, **build a gate, not just a warning** — this doc warned about exactly the
bot-motion blind spot yet a head-banging bug still shipped, because a warning isn't a detector. The fix
was a `round_stats.motion_health` probe that makes "looks dumb" a number. Prefer turning felt-quality
failures into measurable signals in the QA feed over trusting anyone to remember to look.
