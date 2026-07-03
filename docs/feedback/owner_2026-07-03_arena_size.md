# Owner directive — 2026-07-03 — dev_arena is too tight; the typical level is ~2x wider

> Owner (Devin), from watching playtests. Direct level-design directive.

## The directive
The current arena (`levels/dev_arena.json`, walkable ~1792px wide) is **too tight for proper
playtesting** and should NOT be treated as a typical level. The typical level should be **at least
2× as wide (~3584px+ walkable) with the platforms SPACED OUT.** The current small arena can survive
as a deliberate "mini level" variant, but it is not representative.

## Why this matters (and a caution on prior QA)
All the combat/pacing QA so far (lethality tuning, kill economy, the melee/1v1 pacing findings)
ran on the tight dev_arena. A 2× level with spaced platforms changes travel distances, edge
proximity, and how often 4 players are in contact — so **the pacing numbers (stage length, melee
dwell, match length) should be re-validated on the proper-size level**, and the tight-arena results
treated as provisional / a mini-level data point, not the representative baseline.

## Also — VERTICAL space + traversal (this is the movement-feel thesis at stake)
- The 3 upper platforms are **too close to the ground** — characters constantly hit the "ceiling."
  Add much more **vertical gap between the floor and the upper platforms.** (Currently floor ≈y980,
  upper platforms y540-708 → only ~270-440px, which a single floor bounce (trampoline ~270 / spring
  ~480) already covers → you bonk the platforms without ever flying.)
- Consequence the owner flagged: **there is almost no need to use normal boost to fly anywhere** —
  everything is within a bounce. That means the level is NOT exercising the jetpack, which is the
  core mechanic (movement-feel thesis). A proper level must have distances (horizontal AND vertical)
  that REQUIRE boost/super to traverse — flying between spread platforms should be normal play.
- Design target: spacing tuned so a player must **normal-boost to cross gaps and to reach upper
  platforms**, and super-boost for the biggest leaps — i.e. the arena exercises the full movement
  vocabulary, not just bouncing in place.

## Test on a ~10-LEVEL CIRCUIT, not a single arena (owner, 2026-07-03)
The kill-race mode rotates through levels, so QA must reflect that: **run all tests on a circuit
of ~10 levels** (the real rotation), not one arena. Implications:
- The level pool (was "slice D, later") is now a PREREQUISITE for representative QA — pacing/feel/
  match-length must be measured across a full circuit rotation, not on dev_arena or one 2x arena.
- All prior single-arena pacing QA (lethality, melee, closeout, match-length) is PROVISIONAL and
  must be re-validated on the ~10-level circuit once it exists.
- Depth-first caveat (Director): get ONE proper-size arena (the 2x flagship below) genuinely-good
  in-engine first — flight-required traversal, edge economy at scale, feel — as the template, THEN
  author ~9 more varied levels to that bar to form the circuit, THEN run all QA on the circuit.

## Build
- New primary grass arena, ~2× dev_arena walkable width (~3584px+), platforms spaced out (not just
  scaled — genuinely more room between them so movement/traversal matters). Keep the Glossy Toybox
  look + surface-tier vocabulary. Use the JSON schema; it becomes the default `scenes/Arena.tscn`
  test level. dev_arena stays as a "mini" variant.
- **Level-relative bounds interaction (flag):** slice B derives side kill-zone = `clamp(0.52*width,
  700, 1400)`. A 2× walkable (~3584) → 0.52×3584 ≈ 1864, **capped at 1400** — so a big level's side
  kill zone is proportionally TIGHTER than dev_arena's ~964 relative to its width. Decide: raise
  `bounds_side_max` for large levels, or set an explicit `bounds` override on the 2× arena, or
  accept the cap. The edge-relative kill economy depends on getting this right at 2× scale.
