# Owner check-in — 2026-11-14 (mid weekend run)

Verbatim:
> hey, just checking in, looks like there are some nice UI changes, as for gameplay, do you ever record a video of
> like 20 seconds of a match then analyze it frame by frame? the aiming mechanic looks crazy when the bots use it, it
> spins like nuts. also i think the bots need to rely too much on the super boost because the normal flying isnt
> responsive enough to maneuver around nicely, we should make that more responsive/effective and consider super
> boost more just like the way to attack others rather than the way to get around. also when i watched one match,
> with like big swinging pendulums, i notice they went right through a player and didnt smash them, then on like a
> black hole level, all the player sprites were behind the black hole, so that looked really weird. also i've had
> some feedback that the sport modes are quite fun, maybe more fun than the brawl, so lets ensure we focus efforts
> there too

## Asks -> backlog
1. **Record ~20 s match video, analyse frame by frame** -> WK-93 (tooling: Godot Movie Maker `--write-movie` at fixed
   fps so frames are captured regardless of machine perf; contact sheets; becomes standard QA evidence for motion).
2. **Bot super-aim spins like crazy** -> WK-94 (bot aim must sweep smoothly like a human, no per-frame re-roll).
3. **Normal flight not responsive enough; bots lean on super boost to get around** -> WK-95 (OWNER RULING: make
   normal flight more responsive/effective for manoeuvring; super boost = primarily an ATTACK, not traversal;
   bots follow suit). Supersedes earlier "fuel economy / super as movement" assumptions where they conflict.
4. **Pendulum hazards pass through players without smashing them** -> WK-96 (collision bug).
5. **Black hole level: player sprites draw behind the black hole** -> WK-97 (z-order bug).
6. **Sports modes reported as fun, maybe more than Brawl — focus there too** -> WK-98 (sports deep-dive + polish
   track; producer weights sports items up).

Positive: "some nice UI changes".
