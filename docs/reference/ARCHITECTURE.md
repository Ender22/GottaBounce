# GottaBounce — Architecture Contract

> **Status:** Living. **Last updated:** 2026-06-27.
> **Read after** `GAME_DESIGN.md` (what the game is) and `FEEL_REFERENCE.md` (how it feels).
> **Engine:** Godot 4 + GDScript (`GAME_DESIGN.md` §13).

## 0. How to use this doc

This is **not** a prescriptive class design, and it does **not** dictate the build plan — Fable
authors that. This doc defines only two things:

1. **The load-bearing SEAMS** that must be built *general from day 1* (§1).
2. **The keeper-vs-throwaway split** — what must be clean vs. what's deliberately disposable (§3).

**Honor the seams; design everything else however is best.**

**Why this exists (the anti-stilts contract):** GottaBounce is a *simple core loop* (bounce + jetpack +
smash) with *rich systems layered on top* (gravity fields, a physics-prop sandbox, explosions, bosses,
two modes with different cameras). The danger: if the core is hardcoded to the simple case, every rich
system becomes a ground-up rewrite — "houses built on stilts." Each seam below is a spot where building
general **now costs almost nothing**, but **retrofitting later costs a rewrite**. That asymmetry is the
whole point. v0 only *uses* the simple case, but must be *built on* these seams.

---

## 1. The non-negotiable seams (build general from day 1)

### 1.1 Gravity is a queried vector field — never a hardcoded constant
- **Contract:** all gravity comes from `get_gravity_at(pos) -> Vector2`. Default returns global down;
  later, `gravity_source` objects (radial planetoids / directional walls, `GAME_DESIGN.md` §4.8)
  contribute. Zone/priority resolved, not N-body-summed.
- **Why:** the entire 360°-gravity feature (planetoid arenas, gravity walls) depends on this. It's the
  single most expensive thing to retrofit.
- ❌ **Stilt:** `velocity.y += GRAVITY * delta` sprinkled through movement code.
- ✅ **Seam:** `velocity += get_gravity_at(global_position) * delta`. All "down"-relative math (bounce
  launch, min-bounce, air drift) operates **along the local gravity vector**, not screen-down.

### 1.2 Bouncing is an interaction surfaces apply to *any* body — not a player-only behavior
- **Contract:** a bounce surface launches **anything that hits it** — players *and* physics props
  (`GAME_DESIGN.md` §6). One "bounce resolution" path, body-type-agnostic.
- **Why:** "boost a heavy ball into a trampoline so it caroms around" only works if surfaces bounce
  props, not just players.
- ❌ **Stilt:** bounce logic living inside the Player script.
- ✅ **Seam:** surfaces expose their tier/normal; a shared resolver applies the launch to whatever
  body contacts them (players via hand-authored velocity; props via the same launch / a physics
  material tuned to match — §1.4).
- **Don't assume surfaces are static:** a bounce block can *itself* be a dynamic body, and can
  **transition static→dynamic** at runtime (collapsible physics structures, `GAME_DESIGN.md` §6 — a
  block is both a bounce surface and a `physics_prop`, released when its support breaks). Model
  "bounce surface" as a capability a body *has*, not a separate static-only entity.

### 1.3 One radial-impulse system for explosions/blasts — affects all bodies
- **Contract:** a single `apply_radial_impulse(center, radius, impulse_center, falloff)` that pushes
  **every dynamic body in range** (players + props) away from center, scaled by distance
  (`FEEL_REFERENCE.md` §4.1).
- **Why:** bombs, chain reactions, and future blast powerups all route through this; players and props
  must respond uniformly so chains (bomb → ball → player) emerge.
- ✅ **Seam:** bodies expose how to receive an impulse (player: add to velocity + apply hitstun; prop:
  `apply_central_impulse`, i.e. velocity = impulse/mass). The blast doesn't know body types.

### 1.4 Players and props are distinct body types that interoperate
- **Contract:** Players = `CharacterBody2D` with **hand-authored** bounce/movement (arcade control,
  `GAME_DESIGN.md` §13). Props (balls/crates/bombs) = `RigidBody2D` (let the engine sim them). They
  **must interact both ways**: player boosts/knocks a prop; a fast prop smashes a player (knockback
  like a player-smash; spiked/lethal variants instakill).
- **Why:** the physics sandbox (Pillar #3 emergent comedy) is exactly these interactions.
- ✅ **Seam:** a shared "smashable / can-be-knocked" interface both implement, and a collision-impact
  rule (impact severity from relative momentum) that reads either body type.

### 1.5 Camera supports BOTH follow-scroll and locked-single-screen modes (swappable)
- **Contract:** camera mode is data-driven per level / level-section. Party = **locked single-screen**;
  Campaign = **follow-scroll** (Parts 1 & 3) that **locks** for the Part 2 arena (`FEEL_REFERENCE.md`
  §7). Co-op scroll needs a 2-player framing + fall-behind rule.
- **Why:** building only a fixed camera (the v0 case) forces a camera rewrite for Campaign.
- ✅ **Seam:** a Camera controller with pluggable modes (`Locked`, `FollowScroll`) selected by the
  level/section; the rest of the game doesn't care which is active.

### 1.6 All feel constants live in ONE hot-editable tuning Resource
- **Contract:** every number in `FEEL_REFERENCE.md` lives in a single Godot `Resource` (`.tres`) or
  autoload (gravity, bounce tiers, fuel, boost, super-boost, supercharge, hitstun, hitstop, shake,
  squash/stretch, rumble, explosion, input). Gameplay reads from it; nothing hardcoded.
- **Why:** the prototype *is* a tuning loop (`GAME_DESIGN.md` §12). Buried constants kill iteration.
- ✅ **Seam:** `Tuning.gravity`, `Tuning.super_boost_impulse_full`, … editable live, ideally without
  recompile/restart.

### 1.7 The JSON level format is the single shared contract
- **Contract:** the human-readable JSON (`GAME_DESIGN.md` §15) is the **one** language shared by the
  AI generator, the (future) editor, and the runtime loader. Tile palette + grid + free-position
  object layer (incl. `gravity_source`, `destructible_platform`, `physics_prop`, `container`, `bomb`,
  hazards, spawns) + blast-zone bounds.
- **Why:** levels are content; the format must outlive v0 unchanged so the Phase-2 editor and mass AI
  generation just read/write the same files.
- ✅ **Seam:** a loader that turns JSON → scene, and a clean schema. Treat the format as **stable
  API**; version it (`"version"` field).

### 1.8 Input is device-agnostic actions; bots emit the same input as humans
- **Contract:** gameplay consumes an abstract **input intent** (aim vector, boost held, super pressed,
  use-powerup pressed) — not raw device reads. v0 is controller-only (`GAME_DESIGN.md` §11), but the
  abstraction lets keyboard/mouse and online drop in later. **Local multiplayer:** one input source
  per player (device → player slot).
- **Bots (critical):** AI produces the **same input intent struct** a human controller would — bots
  play by identical rules, **no cheating** (`GAME_DESIGN.md` §8). Difficulty = *quality* of that input
  (aim error, reaction delay, recovery skill), never special powers.
- ✅ **Seam:** `InputIntent { aim:Vector2, boost:bool, super:bool, use_powerup:bool }`; humans and bots
  are interchangeable providers.

### 1.9 Death/kill-cause is a unified event with multiple sources
- **Contract:** one death pipeline that records a **cause**: `ring_out`, `hazard` (spikes/crusher/laser),
  `prop_smash`, `explosion`, `self_destruct` (self ring-out), `fell_behind` (campaign scroll). Scoring
  (§3: +kill / +survive / −suicide), sudden-death trigger (0.25s near-simultaneous), lives (campaign),
  and juice all subscribe.
- **Why:** scoring, sudden death, boss HP exception, and mode-specific death sources all hang off this.
- ✅ **Seam:** emit `killed(victim, cause, attacker?)`; systems react. **Boss HP is the one exception**
  — bosses have a health pool (`GAME_DESIGN.md` §4.5 / §7), players never do.

### 1.10 Jetpack = separate code-rotated sprite + exhaust emitter (not baked into character anim)
- **Contract:** the jetpack is a **child sprite** rotated in code to the aim direction, independent of
  character facing; exhaust = a particle emitter at the nozzle firing opposite thrust; super-boost = a
  bigger one-shot burst (`GAME_DESIGN.md` §12). Exhaust is also an **ignition source** (lights bomb
  fuses, §6).
- **Why:** aim-in-any-direction + the exhaust-lights-fuse interaction both require this separation.

---

## 2. Layered module map (dependencies point downward)

Lower layers must not depend on higher ones. (Names illustrative — structure is Fable's call.)

```
PRESENTATION   juice (squash/stretch, hitstop, shake, rumble), HUD (fuel gauge, pips), audio, VFX
     ▲         — subscribes to events (§5); never owns simulation state
META           progression & unlocks, circuits, leaderboards            [post-v0]
MODES          Party (rounds, scoring, sudden-death, circuit cycle) | Campaign (3-part flow, waves,
     ▲         lives, bosses)                                            [Party core minimal in v0]
SYSTEMS        round/match flow, scoring, spawn intro, wave spawner, camera modes (§1.5),
     ▲         powerup spawning, kill/death pipeline (§1.9)
ENTITIES       Player, Bot(=Player+AI input §1.8), Prop/Ball/Crate/Bomb, Hazard, DestructiblePlatform,
     ▲         Boss, Powerup, GravitySource
CORE SIM       movement & hand-authored bounce, gravity field (§1.1), bounce resolver (§1.2),
               radial impulse (§1.3), body interop (§1.4), collision/impact, Tuning resource (§1.6),
               JSON level loader (§1.7), InputIntent (§1.8)
```

**The CORE SIM layer is the keeper crown jewel** — build it on the §1 seams and everything above is
addable without touching it.

---

## 3. Keeper vs throwaway

| KEEPER (build clean — survives v0 → launch) | THROWAWAY (build fast — expected to be replaced) |
|---|---|
| Core sim: movement, bounce resolver, gravity field, radial impulse, body interop | Placeholder **art wiring** (Kenney kit → final art) |
| Tuning resource (§1.6) | v0 **round-flow glue** (minimal spawn→fight→reset) |
| JSON level format + loader (§1.7) | v0 **debug HUD** / on-screen tuning sliders |
| InputIntent + bot-as-input-provider (§1.8) | Hardcoded single test level (before the format matures) |
| Kill/death-cause pipeline (§1.9) | Any "just to see it move" stubs |
| Camera mode abstraction (§1.5) | Placeholder SFX choices |
| Jetpack-as-separate-sprite rig (§1.10) | |
| Event/signal surface (§5) | |

> Throwaway is fine and encouraged for speed — **as long as it sits on keeper seams.** A disposable
> round-flow on top of a clean core sim is healthy; a "temporary" gravity hardcode in the core is a stilt.

---

## 4. The v0 prototype slice (what to actually build first)

v0 (`GAME_DESIGN.md` §12) proves the core loop is fun. It implements only the simple case of each
seam — but **on the seam**, not around it:
- Gravity field §1.1 present, returning **global down only** (no gravity_source yet).
- Bounce resolver §1.2 working for **players**; prop support can be stubbed but the path exists.
- Tuning resource §1.6 **fully populated** (this is what the playtest tunes).
- JSON loader §1.7 loading **one hand-authored level**.
- InputIntent §1.8 with **controller + keyboard P1 + one bot**.
- Kill pipeline §1.9 with `ring_out`, `hazard`, `self_destruct`.
- Jetpack rig §1.10 complete (it's core to the feel).
- Camera §1.5: **locked single-screen only** (but behind the mode abstraction).
- Out: explosions, props, gravity sources, bosses, campaign, progression, circuits, full powerups,
  online — all addable later *because* the seams exist.

---

## 5. Event/signal surface (decouples sim from presentation)

The CORE/SYSTEMS layers **emit signals**; PRESENTATION and scoring **subscribe**. This keeps juice and
HUD out of the simulation. Suggested events:
`bounced(body, tier)`, `fuel_changed(player, amount)`, `boost_started/stopped`, `super_boosted(player,
power)`, `supercharged(player)`, `smashed(attacker, victim, impulse)`, `killed(victim, cause,
attacker?)`, `exploded(center, radius)`, `powerup_used(player, type)`, `round_started/ended`,
`sudden_death_started`, `point_scored(player, reason)`.
- Juice (hitstop, shake, rumble, squash), audio, and HUD react to these — never poll sim internals.

---

## 6. Physics tick / resolution order (per physics step)

A suggested deterministic order (Fable may refine), run in `_physics_process`:
1. Gather `InputIntent` (humans + bots).
2. Apply jetpack thrust / super-boost; drain fuel.
3. `velocity += get_gravity_at(pos) * delta` (§1.1).
4. Apply air drift, clamp.
5. Integrate + resolve collisions (`move_and_slide`).
6. On bounce-surface contact: run bounce resolver (§1.2) — incl. boost-bounce supercharge window
   (`FEEL_REFERENCE.md` §3.4) and fuel refill.
7. Resolve pending radial impulses (explosions, §1.3) and prop↔player smashes (§1.4).
8. Evaluate deaths → kill pipeline (§1.9); apply hitstop/time-scale (§5 / `FEEL_REFERENCE.md` §5.1).
9. Update camera (§1.5); emit events (§5).

---

## 7. Explicitly throwaway (don't polish these in v0)
Placeholder art/SFX wiring, the minimal round loop, debug tuning UI, the single test level. Build them
quick and ugly — their only job is to let the **keeper core** be felt and tuned. They get replaced;
the core does not.
