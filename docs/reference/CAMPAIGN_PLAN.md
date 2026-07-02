# GottaBounce — Campaign Grand Plan

> **Premise (owner's direction):** Campaign is **single-player skill school**. Each level is
> **one exploration platforming challenge + one room fight**, and difficulty grows steadily.
> Exploration areas have **NO enemies** — they're pure movement/physics puzzles that teach the
> jetpack, bounce, super-boost and physics toolkit. Room fights use the **same kill rules as Party**:
> enemies have **no HP** — you must **smash them off-screen or into hazards**. Only **bosses** have HP.

## Structure
- **10 Worlds × 5 levels = 50 levels** + 5 boss levels (one capping each odd world cluster) = **55+**.
- Each level: `[challenge region] → [fight room] → [exit flag]`. Beat the challenge to reach the room;
  clear the room (ring-out / hazard all enemies) to open the exit; touch the flag → next level.
- **~5 lives**, respawn at the level's checkpoint (entrance to whichever section you died in).
- Camera follows + zooms (same controller as Party). Fight rooms are enclosed-ish with open edges /
  hazard pits so knocked enemies actually leave.

## Level primitives available (JSON)
`platforms` (tiers: marshmallow/bubblegum/trampoline/spring + bumper walls), `spikes` (instakill
hazard), `physics_prop` (ball / heavy_ball / spiked_ball / crate), `bomb`, `container`,
`physics_structure` (stack + breakable support), `gravity_source` (radial / directional),
`powerup_spawner`, `campaign_arena` (fight room rect + waves), `enemy_spawn`, `campaign_goal`.
New helpers this plan may add: `moving_platform`, `crusher`, `wind` (directional gravity reuse),
`fan` (updraft), `checkpoint`.

## Enemy archetypes (room fights, NO HP — smash them out)
- **Floater** — drifts at you, light, easy to fling. Teaches basic smashing.
- **Chaser** — runs the ground + bounces, harder to corner.
- **Heavy** — slow, heavy, needs a hard hit / super-boost to move. Teaches power.
- **Spiker** — touching it hurts you; smash it without ramming it head-on.
- **Floaty swarm** — several weak floaters at once (crowd control).

---

## WORLD 1 — Liftoff (teach the jetpack)
1. **First Hop** — small gap; single boost-tap to cross. Room: 1 floater.
2. **The Long Jump** — wide gap; must hold boost to glide across. Room: 2 floaters.
3. **Up & Over** — a tall bumper wall; boost straight up (default up-thrust) and over it. Room: 2 floaters.
4. **Stepping Stones** — 3 small marshmallow pads over a pit; bounce-and-drift between them. Room: 1 chaser.
5. **Fuel Sips** — gap too long for one tank; bounce on a mid pad to refuel, then continue. Room: 2 floaters.

## WORLD 2 — Bounce Basics (the bounce economy)
6. **Trampoline Climb** — stacked trampoline ledges; bounce upward to the exit. Room: 2 floaters.
7. **Spring Launch** — one spring pad flings you across a huge gap; aim the arc. Room: 1 chaser + 1 floater.
8. **Tier Ladder** — marshmallow→bubblegum→spring in sequence; ride increasing bounces up. Room: 2 chasers.
9. **Drift Landing** — spring launches you; air-drift to land on a tiny far pad. Room: 3 floaters.
10. **Pendulum Pads** — first **moving_platform**: time your bounce as it passes. Room: 2 floaters.

## WORLD 3 — Spikes & Precision (don't touch)
11. **Spike Gap** — pit floored with spikes; one clean boost across. Room: 1 chaser (spike pit in room).
12. **Low Ceiling** — boost across under a spiked ceiling without rising into it. Room: 2 floaters.
13. **The Slot** — hover between two horizontal spike walls to reach a platform. Room: 2 chasers.
14. **Spike Stairs** — alternating spiked ledges; precise short hops. Room: 1 heavy.
15. **Needle Threader** — narrow vertical spike corridor; rise slowly without scraping. Room: 3 floaters.

## WORLD 4 — Walls (vertical movement)
16. **Wall Kick** — bounce off one bumper wall to reach a side ledge. Room: 2 chasers.
17. **Chimney** — bounce left↔right up two vertical bumper walls to climb a shaft. Room: 2 floaters.
18. **Zig-Zag Shaft** — staggered wall nubs; alternate wall-bounces upward. Room: 1 heavy + 1 floater.
19. **Narrow Chimney** — tighter shaft, spikes on one side; controlled wall bounces. Room: 3 floaters.
20. **Wall Drop** — descend a shaft tapping walls so you don't fall too fast into spikes. Room: 2 chasers.

## WORLD 5 — Physics Puzzles (use the props) + BOSS
21. **Box Steps** — knock over a stack of crates to build a path up. Room: 2 floaters.
22. **Ball Ramp** — push a heavy_ball into a gap to bridge it, then cross. Room: 2 chasers.
23. **Domino Run** — topple a physics_structure to clear a spiked passage. Room: 1 heavy.
24. **Counterweight** — drop a heavy_ball on a breakable support to open a path. Room: 3 floaters.
25. **BOSS: The Bouncer** — first boss (HP). Super-boost its weak spot when it telegraphs; dodge shockwaves.

## WORLD 6 — Super-Boost School (aim the dump)
26. **Charged Leap** — gap only crossable with a charged super-boost. Room: 2 chasers.
27. **The Keyhole** — super-boost through a tiny gap in a wall to land on a ledge. Room: 2 floaters.
28. **Cancel & Aim** — fall into a pit, charge super-boost (freeze), aim up, blast out. Room: 1 heavy.
29. **Double Tap** — super-boost across, refuel on a pad, super-boost again to finish. Room: 3 floaters.
30. **Pinhole Climb** — chain two super-boosts through stacked keyholes. Room: 2 chasers + 1 floater.

## WORLD 7 — Hazard Choreography (timing)
31. **Crusher Hall** — first **crusher**: pass under a slamming block on rhythm. Room: 2 floaters.
32. **Saw Gauntlet** — moving spike (saw) sweeps a corridor; time your crossing. Room: 2 chasers.
33. **Bomb Bridge** — armed bombs along the only path; trigger + escape the blast. Room: 1 heavy.
34. **Updraft Vents** — **fan** updrafts toggle; ride them up between spike caps. Room: 3 floaters.
35. **Laser Sweep** — a LaserWall sweeps the room; out-maneuver it while smashing enemies.

## WORLD 8 — Gravity (the field) + BOSS
36. **Heavy World** — directional gravity is stronger; heavier jumps, manage fuel. Room: 2 chasers.
37. **Low-G Drift** — weak gravity; floaty control, easy to overshoot into spikes. Room: 3 floaters.
38. **Sideways** — directional gravity pulls LEFT; navigate a vertical-feeling level. Room: 2 floaters.
39. **Planetoid** — radial gravity source; orbit/land on a little planet to the exit. Room: 2 chasers.
40. **BOSS: Gravity Well** — boss that warps local gravity between phases.

## WORLD 9 — Combinations (everything at once)
41. **Spike Chimney** — wall-bounce up a shaft lined with spikes (walls + spikes). Room: 3 floaters.
42. **Physics Gate** — knock a ball to weigh a switch, then super-boost through the opened gap. Room: 2 chasers.
43. **Moving Slot** — hover through a slot between two **moving** spike walls. Room: 1 heavy + 1 floater.
44. **Wind Tunnel** — directional wind pushes you; correct with boost across a spike gap. Room: 3 floaters.
45. **Crusher Climb** — bounce up trampolines between crushers on rhythm. Room: 2 chasers.

## WORLD 10 — Mastery + FINAL BOSS
46. **The Run** — a long combined course: gap → slot → chimney, no checkpoint mid-section. Room: 3 chasers.
47. **No Floor** — all spring pads over a deep pit; never stop moving. Room: 3 floaters + 1 heavy.
48. **Pinball** — bumper-heavy room; ricochet to line up smashes. Room: 4 floaters (swarm).
49. **The Threader** — keyhole super-boost → moving slot → wall-bounce finish. Room: 2 heavies.
50. **Gauntlet** — crushers + saws + spikes + wind together. Room: 3 chasers.
51. **FINAL BOSS: The Champion** — multi-phase boss; uses shockwaves, summons floaters, gravity flips.

---

## Implementation order (so it ships incrementally)
1. **Engine first (this pass):** enemies use Party kill rules (no HP → smash off-screen / into hazards);
   hazards kill enemies too; CampaignMode = data-driven `[challenge → fight room → flag]`, level sequence,
   no enemies in exploration. Build **W1 + early W2/W3/W4 levels** (1–6+) as real playable JSON.
2. Add `moving_platform`, `crusher`, `fan`/`wind` primitives (Worlds 3/7/8) — each unlocks a batch.
3. Fill remaining levels world-by-world; bosses reuse/extend `Boss.gd`.
4. Tune each level by playing (the harness can script-fly a challenge to sanity-check it's possible).

## Authoring notes
- A fight room should have **open edges or a hazard pit** so smashed enemies actually leave — otherwise
  they can't be killed (no HP). Give the player bounce pads to stay in.
- Keep each challenge **readable in one screen** (the camera frames it). One mechanic per early level.
- Exploration checkpoints: respawn at the section entrance, not the level start, so a hard fight doesn't
  replay the platforming.
