# Spec: v6 — PARTY GIMMICK MECHANICS + ESCALATING UNLOCKED CIRCUITS

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD (multi-wave). **v1.1 — 2026-07-05.**
>
> **Goal (owner directive):** make BRAWL *much* richer — many WILD ~10-second gimmick levels grouped
> into escalating themed circuits (~20 authored per circuit, ~10 randomly drawn per play), UNLOCKED as
> you play (meaningful progression / retention).
>
> **v1.1 change (owner, 2026-07-05):** hazards are **LETHAL by default** (was "recoverable/shove-only").
> The recovery-gamble constraint is replaced by a telegraphy + fairness + credit doctrine (§2). Added the
> headline **COLLAPSING ARENA / LAST-ONE-FLYING** archetype (§2.8).
>
> **Required reading already run:** `docs/GAME_ESSENCE.md`, `docs/VISION.md`, `docs/DECISIONS.md`
> (esp. **2026-07-04 moving_hazard ruling** — the credit template this spec extends to every hazard),
> `levels/circuits.json`, `islands_void.json` + `wrecking_yard.json`, `src/core/LevelLoader.gd`,
> `src/systems/ArenaRenderer.gd`, `src/modes/BrawlMode.gd`, `src/core/Settings.gd`, `src/ui/ArenaSelect.gd`,
> `src/core/MatchConfig.gd`.
>
> **This doc is DESIGN + doctrine + measurable targets + build order.** The programmer owns feasibility;
> the level-designer authors JSON geometry inside these constraints. I do not write GDScript.

---

## 0. THE THESIS — why ~10s levels can be far wilder

BRAWL stages already end by **last-one-standing** (no timer), which lands most stages in the **~6-12s**
band. That short TTL is the design lever the owner identified: a level does not have to be *fair over a
long match* — it has to be *legible and fun for ~10 seconds*. A wrecking ball, a crusher, a collapsing
floor, a bomb barrage — mechanics that would be exhausting for 90 seconds are a **perfect punchline for
10**. So this spec designs mechanics with **fast cadences** (crusher period ~2-3s, hammer ~3-5s, debris
~1.5s, bomb fuse ~1.5s, destructible breaks in 2-4 hits, closing walls fully shut ~8-10s) so each
mechanic delivers **2-5 readable beats within one stage**.

**Inviolable through-line (carried from every prior arena spec):** the kill identity stays *"get knocked/
funnelled OFF the screen or SPLATTED by the level"* — flight stays REQUIRED to traverse where it matters,
and **no hazard is a credited scorer** (INV-9): a hazard-kill with no attacker is an **uncredited
self-fall**; a rival who knocked you into the hazard within the 6s window gets the credit. Every gimmick is
either a killer you dodge or a tool that funnels rivals off-screen.

> **LETHALITY RULING (owner, 2026-07-05 — supersedes the earlier "hazards must be recoverable" line).**
> In a game where you die every ~5s, a non-killing hazard is meaningless scenery. **Hazards are LETHAL by
> default** — the hammer that KILLS if it hits you (and the whole level is dodging it) is what creates the
> tension and the laugh. This spec is written to that ruling. See §2 for the doctrine (telegraphy +
> fairness + credit — NOT recoverability). NOTE: the shipped `moving_hazard` stays a non-lethal SHOVER (it
> was validated + is fenced); it is now the *milder* end of the hazard family, not the template for
> lethality. New lethal hazards use the `spikes`/`Hazard.gd` instakill path (`kill(&"ring_out"/&"hazard")`).

**Pillar guards that constrain every mechanic below:**
- **Pillar 2 (constant motion, no camping):** a gimmick may NOT create a new safe camp spot. Hazards add
  motion pressure; they never reward turtling (idle_hunt still applies).
- **Pillar 5 (readability over prettiness):** every hazard is periodic/telegraphed. Unreadable = rejected.
- **Fairness (replaces the old recovery-gamble constraint):** a hazard may instakill, but only if it is
  **learnable and dodgeable with skill** — a clear rhythm/windup/warning + an escape route / safe beat,
  faced symmetrically by everyone. A *random, un-telegraphed, unavoidable* instakill is still rejected (see
  §2). The fun is the dodge/panic timing, not an unfair coin-flip death.

---

## 1. GIMMICK MECHANIC CATALOG

### 1.1 Brainstorm (aim high — 23 ideas, owner seeds marked *)

1. *Moving platform (translating footing on a path)
2. *Crusher (two masses periodically SMASH together, **crush-kill** anyone between)
3. *Destructible block (breaks when hit; "level in a box" whose walls/floor erode)
4. *Bomb / explosive hazard (telegraphed fuse -> lethal blast)
5. *Spinning hammer (giant rotor arm — **kills on contact**, jump the ~5s rhythm)
6. *Drop-on-destroy (destroying things drops lethal weights/spikes onto players below)
7. *Pinball auto-paddle (flings you at intervals)
8. *Falling giant balls (dodge lethal debris from the top while fighting)
9. *Moving vehicles (fight on top of moving futuristic vehicles)
10. **COLLAPSING ARENA / LAST-ONE-FLYING** (owner headline — floor fully erodes; §2.8)
11. Closing walls / shrinking arena (blast bounds squeeze inward over the stage)
12. Fan / wind zone (directional continuous push volume — non-lethal utility)
13. Collapsing floor (platforms fall away shortly after you touch them)
14. Conveyor surface (bounce surface that also drifts you sideways)
15. Timed geyser / launcher (periodic upward blast — a firing spring)
16. Rising lava / floor (a lethal line that climbs, forcing you up)
17. Sinking islands (footing sinks into the void one by one)
18. Gravity well / magnet (a pull volume)
19. Homing rocket / tracking projectile
20. Teleporter / portal (wrap across the arena)
21. Seesaw / tilting physics platform
22. Ice / low-friction surface
23. Proximity mine (static, arms when a player nears, then detonates)

### 1.2 Triage -> buildable set (ranked: fun x reuse / effort)

Effort tiers: **LOW** = a `Hazard`/`MovingHazard`-style clone with new motion params (proven Area2D +
deterministic phase clock). **MED** = new hit-count/despawn/spawn/fuse or bounds animation. **HIGH** = a
solid moving collider that carries riders (does not exist yet — the one genuinely new physics system).

`fun`/`reuse` 1-5 (higher better); `effort` 1-5 (lower = cheaper). **Score = fun x reuse / effort.** Reuse
anchors: `Hazard.gd` (instakill Area2D on layer 4, `body.kill`), `MovingHazard` (kinematic Area2D, layer 5,
deterministic phase clock), springs/tiers, and the display-only `void` renderer.

| Mechanic | New object type(s) | Reuse vs new code | fun | reuse | effort | **score** | Batch |
|---|---|---|---|---|---|---|---|
| **spinning_hammer** (rotor, **lethal**) | `moving_hazard kind:"rotor"` + lethal flag | REUSE MovingHazard motion + `Hazard.kill` on contact; add rotor motion + a clear window | 5 | 5 | 1.5 | **16.7** | **1** |
| **crusher** (**crush-kill**) | `crusher` | REUSE Hazard kill + MovingHazard motion; kills anyone caught at full close | 5 | 4 | 2 | **10.0** | **1** |
| **falling_debris** (**lethal**) | `debris_spawner` + `moving_hazard kind:"drop"` | REUSE Hazard kill + cadence spawner + landing telegraph | 5 | 4 | 2 | **10.0** | **1** |
| **bomb** (**lethal blast**) | `bomb` | REUSE Hazard kill in a radius; NEW fuse/telegraph + trigger | 5 | 3 | 2.5 | **6.0** | **1** |
| **destructible_block** | `destructible` (surface w/ HP) | StaticBody + hit-count + despawn + crack VFX + geometry-integrity guard | 5 | 3 | 3 | **5.0** | **1** |
| **COLLAPSING ARENA** (archetype) | `destructible mode:"erode"` level pattern | Composed from destructible + void; a full-floor-erosion level | 5 | 4 | 2.5 | **8.0** | **1** (headline) |
| **moving_platform** (+ **vehicle** skin) | `moving_platform` | HIGH: solid moving collider carrying riders (fallback: sticky/overlap) | 5 | 2 | 4 | **2.5** | **1** (de-risk LAST) |
| **auto_paddle** (pinball) | `launcher` | REUSE spring-tier fire on a clock; directional timed impulse | 4 | 3 | 2.5 | **4.8** | 2 |
| **closing_walls** (shrink arena) | `shrink_bounds` | Animate the lethal blast bounds inward + void treatment | 4 | 3 | 3 | **4.0** | 2 |
| **collapsing_floor** (touch-drop) | `destructible mode:"on_touch"` | destructible variant (drop shortly after contact) | 4 | 4 | 2 | **8.0** | 2 |
| **fan / wind_zone** (non-lethal) | `wind` | Continuous directional force area | 3 | 4 | 1.5 | **8.0** | 2 |
| **rising_lava** | `rising_hazard` | REUSE Hazard kill on a climbing line (a moving instakill band) | 4 | 4 | 2.5 | **6.4** | 2 |
| gravity_well, homing_rocket, teleporter, seesaw, ice | — | high effort AND/OR poor fantasy-fit / hard to make dodgeable-fair | — | — | — | — | **CUT/DEFER** |

**Composed mechanic (free once Batch 1 ships) — owner seed #6 "drop-on-destroy":** a `destructible` whose
`on_break` emits `falling_debris` = destroy the block above, drop a **lethal** weight on rivals below. No
new code; a JSON `on_break` field wiring Batch-1 mechanics.

### 1.3 Recommended **BATCH 1** (6 mechanics + 1 headline archetype)

**spinning_hammer, crusher, falling_debris, bomb, destructible_block, moving_platform** — plus the
**COLLAPSING ARENA archetype** (§2.8), which is composed from `destructible_block` and ships in the same
wave (its only new code is `destructible`, already in Batch 1).

Rationale: these directly satisfy **7 of the 10 owner seeds** and, composed, cover 2 more (drop-on-destroy;
pinball-ish flinging). Five of six mechanics are **LOW/MED reuse** of the proven `Hazard`/`MovingHazard`
paths or a self-removing StaticBody; only `moving_platform` needs new physics — scheduled **last with a
fallback** so a slip does not block the rest. Batch 2 (`auto_paddle`/pinball, `closing_walls`,
`collapsing_floor`, `fan`, `rising_lava`) layers on after Batch 1 + the first gimmick circuit prove out.

---

## 2. HAZARD DOCTRINE (per mechanic) — the critical section

### 2.0 The four doctrine rules (LETHAL-by-default; apply to EVERY hazard)

1. **LETHAL by default.** A hazard instakills on contact via the existing `Hazard.gd`/`kill()` path (the
   same pipeline `spikes` uses today). No new death mechanism, no hitstun tuning, no new impulse — the
   contact simply routes to `kill(&"ring_out")` (or a `&"hazard"` cause that funnels identically). The
   *shipped* `moving_hazard` stays a non-lethal shover (the mild end of the family); new hazards KILL.
2. **TELEGRAPHY (learnable/dodgeable with skill).** Every hazard is periodic + has a visible windup/warning
   + a bold silhouette (Pillar 5). The player learns the rhythm and dodges it. A hazard whose kill is
   *random / un-telegraphed / unavoidable* is **rejected** — the fun is the dodge/panic timing, not a
   coin-flip. Reuse the shipped telegraphy toolkit (matte hazard-red stripes/chevrons, apex/open dwell, an
   `EventBus` warning signal for Juice, audio ticks).
3. **FAIRNESS (escape + symmetry).** At every beat there is a **safe spot / clear window / escape route**,
   and **everyone faces the same threat symmetrically** (no player is spawned inside a hazard; no side of
   the arena is a free kill). A hazard may never occupy 100% of the survivable space at once (that is an
   unavoidable instakill — reject). Fast cadences are fine *because* the safe beat always returns.
4. **CREDIT (no new scorer, INV-9).** A hazard-kill with **no attacker** is an **uncredited self-fall**
   (killer = -1, floored at 0 — identical to a self-ringout). If a player **knocked/tagged the victim**
   into the hazard within `kill_credit_window_ringout = 6.0s`, the existing tag->ring-out window credits
   that player. That is the WHOLE credit story — the hazard never sets `last_attacker`, never appears as a
   killer id, and there is **NO invented `environment` scorer**. (Verbatim the moving_hazard §2 credit
   ruling; lethality does not change it.)

**Geometry-integrity (separate from hazards; applies to destructible/moving GEOMETRY, §2.5-§2.8):**
destructible/moving footing must never STRAND a living player with no boost route, and a mover must never
PIN a player against static geometry as a silent unavoidable death — a pin resolves as a lethal *crush*
only when it is telegraphed + escapable (rule 2/3), otherwise the geometry must not be able to reach that
state. A **COLLAPSING ARENA** intentionally erodes ALL floor — that is fair *because everyone's floor goes
at once* (§2.8), not because it is recoverable.

**Fence (inviolable):** no mechanic changes ANY movement / launch / hitstun / lethality / fuel / super /
smash / kill-credit constant. Lethal hazards reuse the existing `kill()` pipeline as-is; the shipped
shover reads `soft_bump_*` read-only. **FLAG at change-control any request to:** add a NEW death impulse or
hitstun path, invent an `environment` attacker/scorer, or make a hazard's kill *non-symmetric* or
*un-telegraphed*. Those break INV-9 / the fairness rule and are auto-reject.

### 2.1 spinning_hammer (rotor) — LETHAL
- **Contact = KILL** (`Hazard.kill`). A giant rotor blade sweeps an arc; touching it splats you off-screen.
- **Telegraphy:** a **single bold blade** on a slow, readable rotation (`period_s ~4-5` = the owner's
  "jump every ~5s"); the swept danger-arc shows a hazard-red guide; a whoosh audio cue. The blade sweeps
  ~200-240deg, leaving a **>= 120deg / ~1.0s+ clear window** every revolution — the beat you jump/boost
  through. It must NOT sweep the entire lane with no gap (unavoidable = reject).
- **Fairness:** the clear window returns every period; the hub sits so no player spawns under the blade.
- **Credit:** rule §2.0#4 — dodge-fail = self-fall; knocked-into-it = credited to the knocker.
- **Fence:** none (MovingHazard motion + the existing kill path + one new motion kind).

### 2.2 crusher — CRUSH-KILL
- **Contact at full close = KILL.** Two telegraphed masses converge on a period; anyone caught between at
  the slam is crushed (splat -> off-screen kill).
- **Telegraphy:** plates visibly pull apart + rumble + hazard-stripe on the closing faces during the ~1.0s+
  **open dwell** (the safe window to pass between), then a fast, readable close (~0.3-0.5s). The windup is
  the tell.
- **Fairness:** the open dwell is long enough to cross with skill; the closing period is fixed and
  learnable; the gap between plates is passable at every open beat. Never closes with zero warning.
- **Credit:** rule §2.0#4.
- **Fence:** none. **DO-NOT-SHIP variant:** a crusher that closes with no windup / no open beat (an
  unavoidable random splat) — rejected by rule 2/3.

### 2.3 falling_debris (giant balls / weights from the top) — LETHAL
- **Contact = KILL.** Balls/weights drop from above; a hit splats you into the void.
- **Telegraphy:** a **ground shadow / warning marker** grows where each ball will land ~0.5-0.8s before
  impact (Pillar 5) + a whistle audio cue. The player reads the marker and steps off it.
- **Fairness:** a **cadence** (~1 ball / 1.2-1.8s) with dodge gaps — **never a simultaneous wall of balls
  that fills all footing** (reject). Cap concurrent debris so a safe spot always exists each beat.
- **Composed:** a ball landing on a `destructible` breaks it (owner-seed #6 drop-on-destroy).
- **Credit:** rule §2.0#4.
- **Fence:** none (drop-kind + Hazard kill + a cadence spawner).

### 2.4 bomb — LETHAL BLAST
- **Detonation = KILL in the blast radius.**
- **Telegraphy:** fuse blink (~1.0-1.5s) + an **expanding warning ring showing the exact blast radius** +
  an accelerating audio tick, then the blast. You see precisely where/when it is lethal and clear the ring.
- **Fairness:** the fuse gives time to escape the telegraphed radius; radius is fixed/visible; bombs are
  placed so a safe standoff always exists. v1 = static-placement (timed or contact-fused); thrown/carried
  bombs are a Batch-2+ chaos stretch.
- **Credit:** knocking a rival into a live blast within 6s = credited; else self-fall (rule §2.0#4).
- **Fence:** none — reuse the kill path; **FLAG** any request for a bomb that adds a new launch/hitstun
  impulse (unnecessary — the kill pipeline already handles the off-screen result).

### 2.5 destructible_block (the "level in a box" that erodes) — SURFACE
- **A SURFACE, not a hazard** — no contact-kill. A bounce-tier `StaticBody` with **HP** that breaks after
  N bounces/hits (or one super), despawning its collider + staged crack VFX. Breaking removes footing ->
  reshapes the arena live (owner's eroding-box; reinforces Pillar 2 — a crumbling block is no camp).
- **Telegraphy:** **staged cracks** at each HP step (visible + audible) so a break is never a surprise; a
  final flash the instant before it goes.
- **Geometry-integrity:** breaking may push players toward the void (that is the point) but the *arena*
  must not reach an unwinnable/stranded state — see §2.0 geometry-integrity + GI-1 (below). For a level
  meant to fully erode, use the COLLAPSING ARENA archetype (§2.8), which is fair by "everyone's floor goes
  at once," not by leaving a floor.
- **`on_break` (composed):** optional JSON — `spawn_debris` (drop-on-destroy owner-seed #6) / `open_void`
  (reveal void beneath).
- **Credit:** none directly; a resulting void fall resolves through the normal window (tagged = credited,
  else self-fall).
- **Fence:** none (self-removing geometry).

### 2.6 moving_platform (+ vehicle skin) — MOVING SURFACE
- **A MOVING SURFACE, not a hazard** — footing that translates on a path and carries riders. Vehicles are
  this mechanic themed (truck/hovercraft; same collider + motion).
- **Solidity (the one new system):** IDEAL = `AnimatableBody2D` (`sync_to_physics`) riders ride correctly.
  **FALLBACK** = "sticky" carry (impart platform velocity to a resting/bouncing rider) or overlap-only.
  Ship the fallback if the solid carrier slips.
- **Contact / pin:** a platform moving a player INTO static geometry could pin -> resolve as a telegraphed
  lethal crush (§2.2 doctrine) OR author paths so the pin state is unreachable. No silent, un-telegraphed
  pin-kill.
- **Geometry-integrity / no-strand:** a mover that is the ONLY footing must not travel out of boost range
  and strand a player; because flight is REQUIRED, a boost route to another surface must always exist
  (GI-2 below).
- **Telegraphy:** visible rails/path; the vehicle's motion reads its own trajectory.
- **Credit:** none directly (surface); a carry off-screen -> ring-out window rule.
- **Fence:** none touched, but **touches physics (moving solid collider)** -> change-control (like the
  moving_hazard collision-table add).

### 2.7 Batch-2 doctrine (brief)
- **auto_paddle / launcher / geyser (non-lethal launch):** a timed directional impulse (spring-tier fire on
  a clock) — a *launch*, not a kill. Telegraph: charge-up glow + audio before firing.
- **closing_walls (shrink arena) — LETHAL bound:** animate the existing off-screen blast bound inward over
  ~8-10s. The blast line is already the game's sanctioned killer; it stays fair via the visibly advancing
  wall (full telegraphy) + symmetry (all sides close on all players). Guard: never close to zero (leave a
  min arena); leave a boost route until the wall arrives.
- **collapsing_floor (touch-drop):** `destructible mode:"on_touch"` — drops ~0.5s after contact (Duck Game).
  Telegraph: wobble + crack on touch; the grace window is the tell.
- **fan / wind_zone (non-lethal utility):** continuous directional force area. Telegraph: stream particles
  + gust audio.
- **rising_lava — LETHAL climbing band:** a `Hazard` kill-line that climbs at a readable rate, forcing
  players up. Telegraph: the visibly rising surface. Fair by symmetry + a readable climb speed slower than
  boosted ascent.

### 2.8 HEADLINE ARCHETYPE — COLLAPSING ARENA / LAST-ONE-FLYING

**The fantasy (owner headline):** *"the floor is disappearing under everyone — stay in the air and be the
last one flying."* You fight on a full floor that **erodes block-by-block as the stage runs** until there
is **no floor left**; the level becomes a pure jetpack-survival scramble over the void. Last one still
flying wins; everyone else falls off-screen. This is the ultimate expression of Pillars 2 (no standing) +
4 (death is cheap and funny) — the level itself removes the ground and dares you to fly.

**How it is built (composed, no new mechanic beyond Batch-1 `destructible`):**
- The whole floor is a grid/rows of `destructible` blocks with `mode:"erode"`.
- **Erosion schedule:** blocks break on a **telegraphed timed cascade** (e.g. outer rows first, then inner,
  fully gone by ~8-10s) AND/OR on contact/bounce, so the safe space shrinks continuously. Author the
  cascade to finish *around* the ~10s stage TTL so the "no floor left, everyone's flying" climax lands.
- **Telegraphy (rule §2.0#2):** every block shows **cracks + a countdown shudder** before it breaks; the
  cascade front is visible so players read where the floor goes next and flee upward/inward.
- **Fairness (the ruling's key point):** fair NOT because it is recoverable, but because **everyone's floor
  erodes on the same schedule, symmetrically** — no player keeps ground another loses. The void beneath is
  the shared killer; flight is the shared escape. Spawns are symmetric on the intact floor.
- **Kill identity:** falls into the void = off-screen kills; a rival who smashed you off just before your
  block broke is credited (6s window); a pure "ran out of floor and couldn't stay up" fall is an uncredited
  self-fall (rule §2.0#4). Expect a HIGH uncredited-self-fall share on this archetype **by design** — QA
  should judge it against a relaxed K1' band for this archetype (note it in the level's `design_intent`),
  not the standard void_is_floor target.
- **Ship as:** one Batch-1 headline level (e.g. `foundry_last_floor` or its own `the_meltdown` finale
  stage) using `destructible mode:"erode"`. It is the marquee unlock reward.

---

## 3. CIRCUIT + ROTATION STRUCTURE

### 3.1 Circuit roster (escalating wildness arc)

Keep the 3 shipped circuits; add gimmick circuits keyed to mechanic families. Escalation is **cross-circuit**
(each circuit is a wilder tier) AND a **micro-arc within a play** (the drawn subset plays mild -> wild, §3.3).

| # | Circuit id | Theme | Wildness | Signature mechanics | Batch |
|---|---|---|---|---|---|
| 1 | `meadow_mile` *(shipped)* | Grassy on-ramp | 1 | none (pure movement/smash) — tutorial circuit | — |
| 2 | `scrapworks` *(shipped, expand)* | Industrial scrapyard | 2 | wrecking balls (shover), **spinning_hammer** | 1 |
| 3 | `the_foundry` *(NEW)* | Molten factory | 3 | **crusher** + **destructible** + **COLLAPSING ARENA** + hammer | 1 |
| 4 | `the_midway` *(NEW)* | Carnival / pinball | 3-4 | **auto_paddle** + **falling_debris** + hammer | 1/2 |
| 5 | `the_convoy` *(NEW)* | Highway / futuristic vehicles | 4 | **moving_platform** + **vehicle** rides | 1 |
| 6 | `the_meltdown` *(NEW)* | Demolition / chaos finale | 5 | **bomb** + falling_debris + **closing_walls** + collapsing-arena finale | 1/2 |

Ship circuits **incrementally** as mechanics + levels land (Foundry first — it uses Batch-1
crusher/destructible/collapsing-arena). The wildness arc 1->5 is the retention spine: each unlock is a
*visibly crazier* box of toys, ending in the last-one-flying meltdown.

### 3.2 The "~20 authored, 10 drawn per play" rotation — circuits.json schema extension

Extend each circuit entry with **`pool` + `draw_count`** (back-compat: absent = today's `levels` ordered
loop):

```json
"the_foundry": {
  "display_name": "THE FOUNDRY",
  "difficulty": 3,
  "draw_count": 10,          // stages to play this match (owner: ~10)
  "draw_mode": "random",     // "random" = shuffle+slice per match; "ordered" = today's fixed loop
  "levels": [                // the POOL (target ~20; author over waves, start ~8-12)
    { "id": "foundry_press_row",   "tier": 1 },
    { "id": "foundry_crumble_box", "tier": 2 },
    { "id": "foundry_last_floor",  "tier": 3 }
    // ... up to ~20
  ]
}
```

- **Back-compat:** `levels` may stay a plain `["id", ...]` array (shipped circuits); the loader accepts a
  string id OR `{id, tier}`. Absent `draw_count`/`draw_mode` -> today's ordered loop.
- **`tier` (optional, 1-3):** within-circuit wildness rank, used only to order the drawn subset into a
  mild -> wild micro-arc (§3.3). Absent = tier 1.
- Add a top-level **`"order": [...]`** listing circuit ids in unlock sequence (progression reads this,
  §4.2 — no hardcoded chain).

### 3.3 How BrawlMode picks (extend `configure` + `next_level_path`)

`BrawlMode.configure` already resolves a circuit to `_pool` and sets `_ordered`. Extend `_load_circuit` to
return the richer entry, then in `configure`:
1. Parse `pool` ids + tiers.
2. If `draw_mode == "random"` and `draw_count < pool.size`: **shuffle the pool once, slice `draw_count`**,
   then **stable-sort the slice ascending by `tier`** so the match ramps mild -> wild. Store as `_pool`,
   `_ordered = true` (play the drawn subset in that arc, no repeats within the match).
3. Else (ordered / small pool): today's behavior unchanged.

Result: **every play draws a different 10 of ~20**, ordered into an escalating arc — "a new peak every
round" *within* a themed identity. The off-screen-kill through-line + flight-required hold because every
pool level is authored to them (§6 Wave-B gate). **Minimal delta:** `_load_circuit` returns
`{levels:[{id,tier}], draw_count, draw_mode}`; `configure` does the shuffle/slice/sort; `next_level_path`
unchanged (it already loops `_ordered` pools).

---

## 4. UNLOCK PROGRESSION (retention layer)

### 4.1 Recommended trigger — mastery-first with a pity fallback

**Circuit N+1 unlocks when you WIN a match on circuit N, OR after `M` total matches played (whichever
first; recommend `M = 3` per gate).** Rationale:
- **Win-to-advance** makes the action *meaningful* (you earned the wilder toys) and gates the wildness
  escalation to skill — the strongest "one more play, I almost had it" driver.
- **The pity fallback (3 matches)** guarantees a losing/casual player still progresses, so the wall never
  becomes a hard stop in a party context (bots fill; a human can usually win vs bots).

`meadow_mile` is always unlocked (the on-ramp). SINGLE-arena + RANDOM_ALL stay always available (never gate
the sandbox).

**Secondary reward track (every session banks progress):** cumulative-kill milestones unlock **cosmetics /
extra characters / arena-variant skins** — e.g. every 25 total kills grants a Herd member or a color, so
even a losing session rewards. Circuits gate on mastery; roster/cosmetics gate on volume. Together they
maximize "one more."

### 4.2 Persistence — extend `Settings` (user://settings.cfg)

Add a `[progression]` section (mirrors the existing write-through ConfigFile pattern):

```
[progression]
matches_played = 0
matches_won    = 0
total_kills    = 0
circuits_cleared = "meadow_mile"                 # comma-joined ids of circuits WON
unlocked_characters = "pogo,butch,ziggy,puff"
pending_unlock = ""                              # id to celebrate on next ArenaSelect open (consume-once)
```

**Settings API (new methods, same write-through style as `set_master`):**
- `record_match_result(circuit_id, won: bool, kills_this_match: int)` — bumps counters; if `won`, adds to
  `circuits_cleared`; recomputes character unlocks from `total_kills`; if a new unlock appeared, sets
  `pending_unlock`; saves.
- `is_circuit_unlocked(circuit_id) -> bool` — unlocked if it is `meadow_mile`, OR its **predecessor** in
  the `circuits.json` `order` chain is in `circuits_cleared`, OR `matches_played >= M * (its order index)`
  (the pity path).
- `take_pending_unlock() -> String` — returns + clears `pending_unlock` (drives the one-shot celebration).

**Minimal state:** three counters + two comma-string sets + one pending flag. The unlock chain order lives
in `circuits.json` (`order`), so progression reads data, not hardcode.

**Where recorded:** `PartyMatch`/`BrawlMode` already computes the match winner + per-player kills at
MATCH_END; call `Settings.record_match_result(config.circuit_id, human_won, human_kills)` there (one line,
additive, BRAWL-only; other modes skip or pass their own).

### 4.3 Surfacing in ArenaSelect (locked cards + celebration)

`ArenaSelect._load_circuit_cards` already builds a card per circuit. Extend:
- **Locked card:** if `not Settings.is_circuit_unlocked(cid)`, render greyed/desaturated with a **lock
  glyph** + a hint on the tag line: `"WIN THE SCRAPWORKS TO UNLOCK"` or `"2 more matches"` (whichever is
  closer). `activate()` on a locked card = no-op + a denied buzz (does NOT launch).
- **Unlock celebration (one-shot):** on `_ready`, call `Settings.take_pending_unlock()`; if non-empty,
  after the entry stagger, play a **card flip** on that circuit (locked -> unlocked) with confetti + the win
  announcer sting + focus snap to it. The "you earned it" moment lands exactly where the player next picks a
  circuit — closing the retention loop.
- **Data:** `CIRCUIT_COLORS` gains entries for the new circuit ids (else the pink fallback).

---

## 5. CROSS-MODE NOTE (which gimmicks enrich the other 3 modes)

- **TRIALS (solo reach-goal; CD #7 called it thinnest — the biggest win):** `spinning_hammer`, `crusher`,
  `moving_platform`, `falling_debris`, `rising_lava` are ideal **timing/precision obstacles**. Lethal
  hazards fit Trials perfectly — a fall = respawn (+2s), so the tension is pure dodge-timing with no combat
  needed. Crushers/hammers as timing gates; moving platforms as ride sections; a collapsing floor as a
  don't-stop climb. Deepens the thinnest mode cheaply with Batch-1 mechanics.
- **GAUNTLET (survival vs waves):** lethal hazard arenas raise difficulty **without more bots** — crushers
  + falling_debris + closing_walls make a stage escalate on its own; a collapsing arena = a shrinking safe
  space as waves climb. A natural late-wave intensity knob.
- **SPORTS (bounce-ball):** `auto_paddle`/`fan` can **redirect the ball** (pinball soccer); `moving_platform`
  makes a dynamic pitch. **Fairness constraint:** keep hazards **symmetric + never near the ball's neutral
  path**; a lethal hazard that randomly kills a team or eats the ball breaks the mode's fairness. Prefer
  non-lethal utility (fan/paddle) in Sports; use lethal hazards only symmetrically and away from the goal
  mouths.

---

## 6. BUILD SEQUENCE (de-risked) + MEASURABLE SUCCESS CRITERIA

### Wave A — Batch-1 mechanics (low -> high risk; each validated in isolation before the next)
1. **spinning_hammer** (rotor motion kind + lethal contact) — proves the lethal-on-a-clock pattern.
2. **crusher** (converging pair, crush-kill at full close).
3. **falling_debris** (drop-kind + cadence spawner + landing telegraph, lethal).
4. **bomb** (fuse telegraph + radial lethal blast).
5. **destructible_block** (HP surface + despawn + crack VFX) -> immediately compose the **COLLAPSING ARENA**
   (`mode:"erode"`, full-floor cascade).
6. **moving_platform** (+ vehicle skin) — **LAST**; solid carrier with the sticky/overlap fallback.

**Per-mechanic success criteria (QA drives the game):**
- **M-LETHAL-CLEAN:** the hazard kills via the existing `kill()` pipeline; it **never appears as a killer
  id** in `round_stats` (a hazard-kill with no attacker = uncredited self-fall, killer = -1; a
  tagged-then-hazard death within 6.0s = credited to the tagger). No `environment` scorer exists (INV-9).
- **M-TELEGRAPH (C3):** a naive viewer names the hazard's rhythm/rule in one sentence; burst screenshots
  confirm bold silhouette + windup/warning + safe-beat dwell at gameplay zoom.
- **M-DODGEABLE (fairness):** across >= 20 stages, a skilled line survives the hazard **>= 8/10** (the
  clear window / escape route always returns); the hazard **never occupies 100% of survivable space at
  once** (zero unavoidable-instakill instances); no player is spawned inside a hazard; the threat is
  symmetric (no side is a free kill).
- **GI-1 (destructible, non-collapsing levels):** across >= 20 stages, no stage ends in an unwinnable/
  stranded state on a level that is *not* a designed COLLAPSING ARENA.
- **GI-2 (moving_platform):** across >= 20 stages, no player stranded (mover leaves boost range with no
  alternative footing) and no silent un-telegraphed pin-kill.
- **COLLAPSING-ARENA (archetype):** the floor fully erodes on a telegraphed, symmetric schedule (~8-10s);
  cracks precede every break; the stage resolves as last-one-flying; QA judges its (high, expected)
  uncredited-self-fall share against the archetype's relaxed K1' note, not the standard target.

### Wave B — author gimmick levels + the first new circuit (THE FOUNDRY)
Author ~8-12 `foundry_*` levels using crusher + destructible + collapsing-arena + hammer, each ~10s,
flight-required (re-run the per-gap analysis at real coords), declaring `kill_shape` per level. Assemble
`the_foundry` (pool + draw_count 8-10). **Circuit success (reuse C1-C6):** off-screen kills **>= 88%**
(K1' void_is_floor, except the collapsing-arena level's relaxed note); motion-health clean (no
stuck/head-bang/camp — `PartyMatch.bot_motion_health()`); **no degenerate level** (uncrossable gap,
un-telegraphed/unavoidable death, stranded, hazard-as-killer, asymmetric free-kill); variety C3 read holds;
stage pacing ~6-12s. **Fairness hunt (explicit QA obligation):** drive with human-style input + bots, WATCH
MOTION, and actively try to find a degenerate/unfair-instakill level — report the FELT experience, not just
pass/fail.

### Wave C — rotation schema + draw logic
Extend `circuits.json` (pool/draw_count/draw_mode/tier + top-level `order`), `BrawlMode.configure`
shuffle+slice+tier-sort, `ArenaSelect` display. **Success:** each play draws a distinct `draw_count`
subset; two consecutive plays of one circuit draw **different** subsets (>= 50% turnover typical); the
drawn subset plays mild -> wild by tier; back-compat — shipped circuits (plain `levels` arrays) unchanged.

### Wave D — unlock system
`Settings` `[progression]` + API; record at MATCH_END; `ArenaSelect` locked cards + celebration.
**Success (verify via settings.cfg + driven flow):** winning a match on circuit N flips N+1 to unlocked;
the pity path unlocks N+1 after `M` matches without a win; a locked card **cannot launch**; the celebration
fires exactly **once** per unlock (pending flag consumed); character milestones unlock at the cumulative-
kill thresholds.

### Wave E — iterate (Batch 2 + more circuits)
`auto_paddle`/pinball, `closing_walls`, `collapsing_floor`, `fan`, `rising_lava` -> `the_midway`,
`the_convoy`, `the_meltdown`. Grow each circuit pool toward ~20. Cross-mode: fold Batch-1 lethal hazards
into TRIALS courses (highest cross-mode ROI) + GAUNTLET late waves.

---

## 7. FENCE (restated)

GEOMETRY + theme + additive kinematic props/surfaces that REUSE the existing `Hazard.gd` kill pipeline +
`MovingHazard` motion + self-removing StaticBodies + level-data bounds animation + a circuits.json
pool/draw schema + a Settings `[progression]` block + ArenaSelect locked-card UI. **NO change** to any
movement / launch / hitstun / lethality / fuel / super / smash / kill-credit constant — lethal hazards
reuse the existing `kill()` as-is, adding no new death impulse. New surfaces: a handful of level-JSON
object types (`crusher`, `destructible`, `bomb`, `debris_spawner`, `moving_platform`, `launcher`, `wind`,
`shrink_bounds`, `rising_hazard`) + motion kinds on `moving_hazard` (`rotor`, `drop`) + a lethal-contact
flag, one solid-moving-collider system (moving_platform, change-control like the moving_hazard collision
add), the circuits schema, and the progression persistence + UI — all additive, gated through
`gottabounce-change-control`, none touching a fenced constant. Any hazard that invents an `environment`
scorer, adds a new death/hitstun impulse, or kills *un-telegraphed / unavoidable / asymmetrically* is an
**auto-reject** per §2.0.
