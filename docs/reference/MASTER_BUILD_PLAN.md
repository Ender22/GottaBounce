# GottaBounce — Master Build Plan (0 → polished launch)

> **Status:** Active. **Last updated:** 2026-06-27.
> **This is the single authoritative build roadmap.** It is the *sequenced spine* for building the
> entire game without losing the big picture or redoing work. Design lives in the other docs; this is
> the order of operations + the contracts every step must honor.

---

## 0. HOW TO USE THIS DOCUMENT (humans + AI agents) — THE PROTOCOL

**Read order for any fresh context:** `DECISIONS.md` → `GAME_DESIGN.md` → `FEEL_REFERENCE.md` →
`ARCHITECTURE.md` → this file.

**Numbering:** `Phase P` → `Stage P.S` → `Step P.S.T`. "Continue at **4.3.1**" = Phase 4, Stage 3,
Step 1. Steps are the atomic, do-able unit.

**Every atomic step has these fields:**
- **Goal** — what it achieves, in one line.
- **Touches** — files/systems it creates or changes.
- **Dep** — step(s) that must be done first.
- **Done-when** — the objective acceptance/audit check (how anyone confirms it's correctly done).
- **Status** — `☐ todo` / `◐ wip` / `☑ done` (append commit hash when done).

**Status legend:** ☐ not started · ◐ in progress · ☑ done · ⊘ skipped (with reason)

### Resume protocol (fresh AI: "continue the build")
1. Read the 5 docs (order above).
2. Find the **first non-`☑` step** in phase order.
3. **Verify the previous `☑` step's Done-when still passes** (catch regressions/drift).
4. Do the step exactly as specified. If reality conflicts with the spec, STOP and flag — do not
   improvise around an invariant.
5. Update the step's Status (+ commit hash) and commit.

### Audit protocol (auditor agent)
- Pick a phase/stage. For each `☑` step, **objectively verify its Done-when**.
- Check **no INVARIANT (§1) is violated** by the code as it stands.
- Report: drift from spec, invariant violations, missing Done-when, fixes-on-fixes smell, dead code.
- Auditing changes nothing — it produces a report. Fixes are separate steps.

### Just-in-time expansion rule (prevents false precision → prevents redos)
- Phases marked **[ATOMIC]** are broken into steps and ready to build.
- Phases marked **[SPINE — EXPAND BEFORE STARTING]** are intentionally only at stage level. Their
  atomic steps are written *just before* the phase starts, once that phase's open design questions
  (see `DECISIONS.md` ❓) are resolved. **Expanding a phase to atomic steps is itself the first step
  of that phase.** Never build a phase that's still spine-only.

### Golden rules (the anti-muddy-context rules)
- **Build on the seams (§1), simple-case first.** Never hardcode the simple case in a way that blocks
  the general one.
- **One feature per step; runnable after every stage.** No giant uncommitted changes.
- **Tune via the Tuning resource, never by editing logic.**
- **If you're about to build a fix on top of a fix, STOP** — re-read the relevant design/architecture
  section and fix the root.

---

## 1. INVARIANTS (never violate — audited on every change)

Restated from `ARCHITECTURE.md` §1 + design pillars as checkable rules:

- **INV-1 — Gravity is a field.** All gravity via `get_gravity_at(pos)`. No hardcoded `Vector2(0, g)`.
- **INV-2 — Bounce is body-agnostic.** A shared resolver bounces *anything* (players + props);
  "bounceable" is a capability a body has, surfaces are not assumed static.
- **INV-3 — One radial impulse.** A single `apply_radial_impulse(center, radius, impulse)` moves all
  dynamic bodies (players + props).
- **INV-4 — Player/prop interop.** Players (`CharacterBody2D`, hand-authored) and props
  (`RigidBody2D`) interact both ways via shared interfaces.
- **INV-5 — Camera is pluggable.** Locked vs follow-scroll behind one abstraction; no system assumes
  a fixed camera.
- **INV-6 — All feel constants in the Tuning resource.** Nothing feel-related hardcoded.
- **INV-7 — JSON is the only level source.** Versioned; generator/editor/runtime all use it.
- **INV-8 — InputIntent abstraction.** Gameplay reads intent; humans & bots interchangeable; **bots
  never cheat** (difficulty = input quality).
- **INV-9 — One kill pipeline with a cause.** Only **bosses** have HP; players never do.
- **INV-10 — Jetpack rig.** Separate code-rotated sprite + exhaust emitter; exhaust is an ignition
  source.
- **INV-11 — No standable ground / no turtling** (Pillar 2 scope: surfaces & camping; brief active
  airborne powerups are fine).
- **INV-12 — Presentation subscribes to events** (`ARCHITECTURE.md` §5); never owns sim state.
- **INV-13 — One physics core serves both modes.** No mode-forked movement/physics; Party & Campaign
  share it.

---

## 2. THE FULL SPINE (whole game at a glance)

| Phase | Goal | Detail |
|---|---|---|
| **P0 Foundation** | Runnable project on the seams: config, Tuning, gravity field, JSON loader, 1 test level | **[ATOMIC]** |
| **P1 Core Movement** | The bounce: continuous bounce, min-bounce, tiers, momentum, angular reflection, drift | **[ATOMIC]** |
| **P2 Jetpack** | Aim rig, normal boost, bounce-powered fuel + gauge, boost-bounce supercharge, super-boost | **[ATOMIC]** |
| **P3 Combat & Bot** | Knockback, hitstun/recovery, death pipeline (ring-out + hazard), InputIntent, basic bot | **[ATOMIC]** |
| **P4 Party Loop + Juice** | Round loop, locked camera, hitstop/shake/squash/rumble/particles — **v0 COMPLETE** | **[ATOMIC]** |
| **P5 Feel Tuning Pass** | The playtest loop; lock the `FEEL_REFERENCE.md` numbers; v0 go/no-go | **[ATOMIC]** |
| **P6 Powerups System** | Powerup framework + spawning + the specced roster (§5) | **[EXPANDED]** |
| **P7 Physics Sandbox** | Props (mass/bounce/smash), bombs+explosions, collapsible structures | **[EXPANDED]** |
| **P8 Gravity Fields** | Radial planetoid + directional gravity sources; body rotation; zones | **[EXPANDED]** |
| **P9 Party Mode (full)** | Full scoring, sudden-death lasers, 1-by-1 spawn intro, leaderboard, lobby + bot count | **[EXPANDED]** |
| **P10 Bot AI Depth** | 5 difficulty levels × 4 dials; human-sim behavior loop | **[EXPANDED]** |
| **P11 Content + Circuits** | Level-format maturity, many handcrafted stages, themed circuits + difficulty ramp | **[EXPANDED]** |
| **P12 Level Editor** | In-engine paint-tiles/place-objects editor + live playtest (Phase-2 pipeline) | **[EXPANDED]** |
| **P13 Campaign Framework** | 3-part levels, scrolling+locking camera, lives, wave spawner, enemy archetypes | **[EXPANDED]** |
| **P14 Bosses** | Boss framework (HP exception), environmental-damage gimmicks, boss roster | **[EXPANDED]** |
| **P15 Progression & Unlocks** | Campaign + party unlocks, paced-scarcity economy, shared collection | **[EXPANDED]** |
| **P16 Final Art Integration** | Replace placeholder with Yulia's art; animation/rigging pipeline | **[EXPANDED]** |
| **P17 Audio & Music** | SFX pass, music, mixing, the Rule-of-Three audio channel | **[EXPANDED]** |
| **P18 UI / Menus / Meta** | Title, lobby, options, accessibility (rumble/shake toggles), save system | **[EXPANDED]** |
| **P19 Polish & Performance** | Final game-feel pass, perf (many bodies), edge cases, bug bash | **[EXPANDED]** |
| **P20 Release** | Windows/Steam export, store prep, settings persistence, launch | **[EXPANDED]** |
| *(Post-launch)* | Online netcode, extra modes (Coin/KotH/Race), team modes | out of launch scope |

> Building reaches **hundreds of atomic steps** as P6–P20 are expanded just-in-time. The spine above
> guarantees none of it is ever forgotten.

---

## 3. ATOMIC STEPS — Phases 0–5

> Conventions: file paths are suggestions consistent with `ARCHITECTURE.md` §2; an executing AI may
> refine structure but must honor the INVARIANTS and Done-when.

### Phase 0 — Foundation  [ATOMIC]

**Stage 0.1 — Project skeleton**
- **0.1.1** Goal: project launches. · Touches: `project.godot`, `scenes/Main.tscn`, `src/Main.gd`,
  `.gitignore`, `icon.svg`. · Dep: — · Done-when: opens in Godot 4 and runs to a titled window, no
  errors. · Status: ☑ (scaffolded + **verified running in Godot 4.7**, 2026-06-27)
- **0.1.2** Goal: git repo + first commit. · Touches: repo. · Dep: 0.1.1 · Done-when: `git log` shows
  an initial commit; `.godot/` ignored. · Status: ☐
- **0.1.3** Goal: folder structure. · Touches: `src/`, `scenes/`, `levels/`, `resources/`, `src/core/`,
  `src/entities/`, `src/systems/`. · Done-when: dirs exist, layering matches `ARCHITECTURE.md` §2. · ☐

**Stage 0.2 — Tuning resource** (INV-6)
- **0.2.1** Goal: `Tuning` resource class with **every** `FEEL_REFERENCE.md` constant + sane defaults.
  · Touches: `src/core/Tuning.gd` (Resource), `resources/tuning.tres`. · Dep: 0.1.3 · Done-when: all
  §FEEL values present, editable in Inspector. · ☐
- **0.2.2** Goal: global access (autoload or loaded resource). · Touches: `project.godot` autoload.
  · Done-when: `Tuning.gravity` readable from any script. · ☐

**Stage 0.3 — Core sim seams (stubs that are correct from day 1)**
- **0.3.1** Goal: gravity field (INV-1). · Touches: `src/core/GravityField.gd` with
  `get_gravity_at(pos) -> Vector2` returning `Vector2(0, Tuning.gravity)`. · Dep: 0.2.2 · Done-when:
  returns down-vector; no other code computes gravity. · ☐
- **0.3.2** Goal: bounce resolver skeleton (INV-2). · Touches: `src/core/BounceResolver.gd` —
  `resolve(body, surface_normal, tier)` body-agnostic. · Done-when: callable; player path used in P1.
  · ☐
- **0.3.3** Goal: radial impulse util (INV-3). · Touches: `src/core/Forces.gd` —
  `apply_radial_impulse(center, radius, impulse)`. · Done-when: defined (no callers yet). · ☐
- **0.3.4** Goal: `InputIntent` type (INV-8). · Touches: `src/core/InputIntent.gd`
  `{aim:Vector2, boost:bool, super:bool, use_powerup:bool}`. · Done-when: struct usable. · ☐

**Stage 0.4 — Level format + loader** (INV-7)
- **0.4.1** Goal: JSON schema v1 per `GAME_DESIGN.md` §15 (palette/grid/objects/bounds). · Touches:
  `levels/test_arena.json`. · Done-when: valid JSON with a few tiers + 2 player_spawns + 1 spikes +
  bounds. · ☐
- **0.4.2** Goal: loader JSON→scene. · Touches: `src/core/LevelLoader.gd`. · Dep: 0.4.1 · Done-when:
  loading the JSON builds tiles (as bounce surfaces with tier data), objects, and bounds. · ☐
- **0.4.3** Goal: render test level from Main. · Touches: `src/Main.gd`, `scenes/Main.tscn`. · Done-when:
  running the project shows the test level (tiles + spawns + spike) from JSON. · ☐  *(Phase-0 green)*

### Phase 1 — Core Movement (the bounce)  [ATOMIC] · tune FIRST (`FEEL_REFERENCE.md` §9 step 1–2)

**Stage 1.1 — The bouncing body**
- **1.1.1** Goal: Player `CharacterBody2D` that falls under gravity-field. · Touches:
  `src/entities/Player.gd`, `scenes/Player.tscn` (placeholder sprite from `assets/placeholder/newplatformer`).
  · Dep: 0.3.1 · Done-when: a creature spawns and falls. · ☐
- **1.1.2** Goal: hand-authored bounce off surfaces via BounceResolver — set normal velocity to tier
  launch speed (`sqrt(2*g*height)`), keep tangential * `tangential_retention`. · Dep: 0.3.2,1.1.1 ·
  Done-when: lands on a tier and bounces to ~that tier's height. · ☐
- **1.1.3** Goal: min-bounce floor (INV-11). · Done-when: arriving near-motionless still bounces to
  `min_bounce_height`; never settles. · ☐
- **1.1.4** Goal: angular reflection off walls/ceilings/curved (reflect about normal). · Done-when:
  bounces correctly off a slanted/wall surface in a test. · ☐
- **1.1.5** Goal: per-tier heights read from Tuning + telegraphed. · Done-when: 4 tiers give visibly
  different heights, all live-tunable. · ☐

**Stage 1.2 — Air control**
- **1.2.1** Goal: slight L/R air drift (Tuning). · Touches: Player + InputIntent. · Done-when: stick
  nudges trajectory within `air_drift_max_speed`, can't fly. · ☐  *(Phase-1 green — the make-or-break
  feel checkpoint; linger and tune.)*

### Phase 2 — Jetpack  [ATOMIC] (`FEEL_REFERENCE.md` §9 step 3–5)

**Stage 2.1 — Aim rig** (INV-10)
- **2.1.1** Jetpack as separate child sprite rotated to aim. · Touches: `scenes/Player.tscn`,
  `src/entities/Jetpack.gd`. · Done-when: jetpack points along the left-stick aim, independent of body.
  · ☐
- **2.1.2** On-screen aim arrow (screen-relative). · Done-when: arrow shows aim past deadzone. · ☐
- **2.1.3** Exhaust particle emitter at nozzle, opposite thrust. · Touches: `assets/placeholder/particles`.
  · Done-when: exhaust fires from nozzle when boosting. · ☐

**Stage 2.2 — Normal boost + fuel**
- **2.2.1** Normal boost: aimed sustained thrust (Tuning accel/max), drains fuel (~3.5s tank). · ☐
- **2.2.2** Bounce-powered refill: fuel only from bouncing; none while airborne/stunned. · Done-when:
  you go dry if you stop bouncing; refill on bounce. · ☐
- **2.2.3** Per-player fuel gauge HUD (UI pack slider). · Touches: `src/systems/HUD.gd`. · ☐

**Stage 2.3 — Supercharge & super-boost**
- **2.3.1** Boost-bounce supercharge (`GAME_DESIGN.md` §4.7): boost during contact → ~0.2s amplified
  thrust+bounce. · Done-when: tapping boost on a bounce gives a clear trampoline-pop. · ☐
- **2.3.2** Super-boost: dump fuel in ~0.3s, impulse scales with fuel-at-use, aimed. · Done-when: full
  tank flings hard; near-empty is weak; you can fling yourself off the map. · ☐  *(Phase-2 green)*

### Phase 3 — Combat & Bot  [ATOMIC] (`FEEL_REFERENCE.md` §9 step 6)

**Stage 3.1 — Knockback & hitstun**
- **3.1.1** Super-boost collision transfers momentum → victim launched. · Dep: 3 players/bot present.
  · Done-when: a super-boost hit sends another body flying. · ☐
- **3.1.2** Hitstun (`GAME_DESIGN.md` §4.6): victim loses control (capped), code tumble, no fuel
  refill mid-flight; regains control → recovery gamble. · Done-when: hit → brief stun → recover. · ☐

**Stage 3.2 — Death pipeline** (INV-9)
- **3.2.1** Kill pipeline: `killed(victim, cause, attacker?)` signal. · Touches: `src/systems/Deaths.gd`.
  · ☐
- **3.2.2** Ring-out via blast-zone bounds; cause `ring_out`/`self_destruct`. · Done-when: crossing
  bounds kills. · ☐
- **3.2.3** Hazard instakill (spikes); cause `hazard`. · Done-when: touching spikes kills. · ☐

**Stage 3.3 — Input intent + bot** (INV-8)
- **3.3.1** Per-player input providers: controller + keyboard P1, mapped to `InputIntent`. · Touches:
  `src/core/InputHuman.gd`. · Done-when: 2 controllers + kb P1 each drive a player. · ☐
- **3.3.2** Basic human-sim bot emitting `InputIntent` (bounce→assess→aim super→recover). · Touches:
  `src/core/InputBot.gd`. · Done-when: a bot plays a fair, non-cheating game. · ☐  *(Phase-3 green)*

### Phase 4 — Party Loop + Juice  [ATOMIC] — **v0 feature-complete** (`FEEL_REFERENCE.md` §9 step 7)

**Stage 4.1 — Round loop** *(throwaway glue, but on the mode/camera seam)*
- **4.1.1** Locked single-screen camera behind the camera-mode abstraction (INV-5). · ☐
- **4.1.2** Round flow: spawn-in → fight → last-one-bouncing → quick reset → repeat, running score. · ☐

**Stage 4.2 — Juice** (INV-12 — all via events, `ARCHITECTURE.md` §5)
- **4.2.1** Event bus / signals (`bounced`,`smashed`,`killed`,`super_boosted`,…). · ☐
- **4.2.2** Hitstop / global slow-mo on smash (`FEEL_REFERENCE.md` §5.1). · ☐
- **4.2.3** Trauma screen shake (§5.2). · ☐
- **4.2.4** Squash-stretch + launch tumble (§5.3, code-driven). · ☐
- **4.2.5** Controller rumble (§5.5). · ☐
- **4.2.6** Particle bursts + hit-flash. · ☐  *(Phase-4 green — playable juicy mini-match = v0.)*

### Phase 5 — Feel Tuning Pass  [ATOMIC]
- **5.0.1** Playtest loop against the §12 success criteria; tune the Tuning resource one var at a time
  (`FEEL_REFERENCE.md` §9 order). · Done-when: owner judges the core loop **fun** (bounce rhythm,
  super-boost + funny self-destruct, fuel tension, smash comedy, fair vs bot). · ☐
- **5.0.2** Record final tuned values back into `FEEL_REFERENCE.md`. · ☐
- **5.0.3** **v0 GO / NO-GO decision.** Go → proceed to P6+ (and start replacing placeholder art when
  ready). No-go → iterate mechanics. · ☐

---

## 4. SPINE DETAIL — Phases 6–20 (expand to atomic BEFORE starting each)

> Each below lists its **scope** and the **open questions to resolve first** (from `DECISIONS.md` ❓).
> First step of every phase = "Expand this phase to atomic steps."

### P6 — Powerups System  [EXPANDED — exemplar of target depth]
> Builds entirely on the `ARCHITECTURE.md` §8 backbone + existing seams. No bespoke physics.

**Design (classes & interactions):**
- **`Powerup`** (Resource) — data + behavior contract: `id, display_name, icon, duration`, and hooks
  `on_pickup(player)`, `on_activate(player)`, `on_tick(player, dt)`, `on_end(player)`. One subclass per
  powerup. All numbers come from `Tuning`.
- **`PowerupSystem`** (autoload) — registry; manages each player's **single held slot**; on
  `InputIntent.use_powerup` → `on_activate`; runs durations/ticks; emits `EventBus.powerup_used`.
- **`PowerupPickup`** (`Area2D`, Bounceable block) — in-world; on contact grants its `Powerup` to the
  player's slot. Spawned by **`PowerupSpawner`** (from the `powerup_spawner` JSON object, on `interval`).
- **Concrete powerups** (each via existing seams):
  - `UnlimitedBoost` — sets `player.fuel_locked` for ~10s.
  - `Star` — `invincible` + `contact_launch` ~6s (touch → `receive_smash` on others).
  - `CounterShield` — `counter` flag ~2s (incoming smash → reflected to attacker).
  - `MegaBounce` — per-player bounce-launch ×N for a few s (a modifier `BounceResolver` reads).
  - `Wings` — Wings movement state; `InputIntent.flap` (repeated Y+RB) adds directional impulse; can
    still boost; ~30 flaps then ends. (INV-11 OK — active airborne.)
  - `SlowMo` — per-entity time/speed ×0.5 on **other** players ~3s (NOT global `Engine.time_scale`).
  - `BlackHole` — ~2s exposed channel; each tick `Forces` pulls others toward the player (INV-3,
    INV-11 OK); ends with rivals clustered for a smash.
  - `RingOfFire` — spawns an `Area2D`; a player passing through has their **super-boost force-triggered
    at full power** in their current aim (`Player.super_boost(force_full=true)`).
  - `AirMine` — spawns a stationary armed `Bomb` at the player (→ `Forces` blast on contact). **DEP P7.**
  - `BallStorm` — spawns ~20 `BouncyBall` props. **DEP P7.**
- **Interactions:** PowerupSystem ↔ Player (slot/flags) ↔ `InputIntent` (use_powerup, flap) ↔ `Forces`
  (BlackHole/AirMine) ↔ `BounceResolver` (MegaBounce modifier) ↔ `EventBus` (powerup_used →
  Juice/HUD) ↔ `Spawner`. HUD shows the held-powerup icon (icons/ pack). Bots use powerups via intent.

**⚠ Cross-phase dep (surfaced by this design):** `AirMine` & `BallStorm` need P7 (props/explosions).
So the framework + non-physics powerups build first; physics-payload powerups land after P7. (This is
exactly the kind of ordering trap the detailed plan exists to catch early.)

**Stages → steps (expand fully at 6.0):**
- **6.0** Expand to atomic steps; resolve open Qs (v1 roster scope, balance start-values, Black-Hole channel feel).
- **6.1** Framework: `Powerup` base, `PowerupSystem`, `PowerupPickup`, `PowerupSpawner` (JSON), HUD slot, `use_powerup` wired. · Done-when: a pickup spawns, is grabbed, a no-op powerup activates on Y+RB.
- **6.2** Self-buffs: `UnlimitedBoost`, `Star`, `CounterShield`, `MegaBounce`.
- **6.3** Movement: `Wings` (repeated-press flap).
- **6.4** Disruptive: `SlowMo`, `BlackHole`.
- **6.5** Trap/area: `RingOfFire`.
- **6.6** *(after P7)* Physics-payload: `AirMine`, `BallStorm`.
- **6.7** Balance pass — tune durations/strengths; each must be readable, funny, INV-11-safe.

**Done-when (phase):** each shipped powerup spawns, is grabbed, activates on Y+RB, produces its effect
with readable VFX/SFX **via events**, respects invariants; owner judges the set fun.
**Invariants:** INV-3, INV-8, INV-11, INV-12. **Open:** v1 roster + balance; Black-Hole channel feel.

### Phases P7–P20 (all expanded — design + classes + stages + steps)
> Each phase has its design + collaborators + stages. The `X.0` step of each still does the final
> atomic-step expansion + resolves that phase's open Qs **just before building it** (designs are
> stable; tuning constants and the finest granularity are settled on approach).
### P7 — Physics Sandbox  [EXPANDED]
> The emergent-comedy engine (`GAME_DESIGN.md` §6, `FEEL_REFERENCE.md` §4.1). Dynamic props that
> bounce & smash, bombs + explosions with chains, and collapsible structures. Builds on INV-2/3/4/10.
> **Resolve first:** explosion `lethal_core` radius (default 0 = pure knockback); prop→player
> instakill threshold (spiked only?); max simultaneous-body perf budget (target ≥ 60 bodies @ 60fps).

**Design — classes & interactions** (on `ARCHITECTURE.md` §8 backbone):

- **`Prop` (`RigidBody2D`)** — *base for all dynamic physics objects.*
  - State: `mass`, `restitution`, `lethal` (bool — instakill on player contact), `impact_min_speed`
    (below this, contact is a nudge not a smash).
  - Methods: `apply_bounce(normal, tier_height)` (Bounceable — reflect `linear_velocity` about normal,
    set the normal component to the tier launch speed so surfaces fling props too, INV-2);
    `apply_impulse_vector(v)` (Impulsable — `apply_central_impulse(v * mass)`, INV-3);
    `receive_smash(impulse, attacker)` (Smashable — add impulse); `_on_body_entered(body)` → if `body`
    is a Player and relative speed ≥ `impact_min_speed`, call `body.receive_smash(momentum, self)`;
    if `lethal`, `body.kill("prop_smash", attacker_of_prop)`.
  - Collaborators: `BounceResolver`, `Forces`, `Player`, `EventBus`. Capabilities: Bounceable,
    Smashable, Impulsable. Invariants: INV-2/3/4.
  - Subclasses: `HeavyBall` (high mass → wrecking ball), `Crate` (breakable → may drop nothing or spawn),
    `SpikedBall` (`lethal=true`), `BouncyBall` (low mass, high restitution — Ball Storm payload),
    `Bomb` (below).
- **`Bomb` (`Prop`, Ignitable)** — *fused explosive.*
  - State: `fuse_time`, `lit`, `fuse_timer`, `blast_radius`, `blast_impulse`, `armed_on_spawn`.
  - Methods: `ignite()` (Ignitable — start fuse if not `lit`); `_process(dt)` (count down → `explode()`);
    `explode()` → `Forces.apply_radial_impulse(pos, blast_radius, blast_impulse)`, then for each
    `Ignitable` within radius call `ignite()` after `Tuning.chain_detonate_delay` (chains), emit
    `EventBus.exploded(pos, radius)`, spawn VFX, `queue_free()`.
  - Ignites via: the jetpack **exhaust ignition Area** (§P2 Jetpack) overlapping it; its own timer (if
    `armed_on_spawn`, e.g. AirMine); or being inside another blast. Invariants: INV-3/10.
- **`StructureBlock` (`RigidBody2D`, Bounceable)** — *one block of a collapsible structure.*
  - State: `freeze=true` initially (held rigid), `tier_height`.
  - Methods: `release()` → `freeze=false` (becomes live physics). Is a normal bounce surface while
    frozen AND a tumbling prop once released (INV-2: bounceable is a capability, surfaces aren't static).
- **`BreakableSupport` (`RigidBody2D`/`Area2D` + hp)** — *holds a structure up.*
  - State: `hp`. Methods: `receive_hit(amount, source)` (from boost-smash / explosion / heavy-prop
    impact) → on `hp<=0`, call `parent_structure.release()`; emit `EventBus.structure_collapsed`.
- **`PhysicsStructure` (`Node2D`)** — *a group of blocks + a support.*
  - State: `blocks: Array[StructureBlock]`, `support: BreakableSupport`, `released`.
  - Methods: `release()` → call `release()` on all blocks (they topple under gravity+collisions). Built
    from the `physics_structure` JSON object.
- **`Container` (`Prop`)** — *spills contents when broken.*
  - State: `contents` (`"bouncy_balls"|"bombs"`), `count`. Methods: `_on_break()` → spawn `count` props.
- **`DestructiblePlatform`** — *boss-gimmick (reusable).* Breaks on hit → drops its `drops` object →
  reforms after `reform` seconds. (Shared with P14.)

**Bounce-for-props decision:** props bounce via the **same `BounceResolver`** as players (contact
monitoring → `resolve()`), NOT a separate PhysicsMaterial — one source of bounce truth (INV-2). Fast
props use **continuous collision detection** to avoid tunneling.

**Collision layers (concrete plan):** `1 players`, `2 props`, `3 bounce_surfaces`, `4 hazards`,
`5 blast_query`, `6 pickups`. Masks: players collide with surfaces/props/hazards/pickups; props with
surfaces/props/players; explosions query layers 1+2.

**Data & Tuning additions:** per-prop `mass`/`restitution`/`lethal`/`impact_min_speed`; bomb
`fuse_time`/`blast_radius`/`blast_impulse`/`chain_detonate_delay`/`lethal_core`; structure `support_hp`;
`explosion_*` (already in `FEEL_REFERENCE.md` §4.1). JSON objects: `physics_prop`, `bomb`, `container`,
`physics_structure`, `destructible_platform` (`GAME_DESIGN.md` §15).

**Events:** emits `exploded(center,radius)`, `prop_smash(prop,victim)`, `structure_collapsed`;
consumes nothing (sim layer). Juice subscribes (INV-12).

**Stages → atomic steps** (expand fully at 7.0):
- **7.0** Expand to steps; resolve the 3 open Qs above; define collision-layer constants.
- **7.1 Prop foundation** — `Prop` base + capabilities, collision layers, `BounceResolver` path for
  rigidbodies, prop↔player smash, CCD. Subclasses `HeavyBall`/`Crate`/`SpikedBall`/`BouncyBall`.
  · Done-when: boost a heavy ball into a trampoline → it caroms and smashes a dummy player.
- **7.2 Explosions** — finish `Forces.apply_radial_impulse` (real, was 0.3.3 stub), `Bomb`
  (fuse/explode/chain), **exhaust ignition Area** on the jetpack, `exploded` event + Juice.
  · Done-when: fly past a bomb → fuse lights → it blasts players+props away (closer=stronger); two
  adjacent bombs chain.
- **7.3 Containers** — `Container` spill (bouncy balls / bombs). · Done-when: break it → contents spill
  and physics-interact.
- **7.4 Collapsible structures** — `StructureBlock`, `BreakableSupport`, `PhysicsStructure`. · Done-when:
  smash the support of a balanced bouncy wall → it topples block-by-block and can smash a player.
- **7.5 Destructible platform** — break→drop→reform (reused by P14). · Done-when: boost it → drops its
  object → reforms after `reform`s.
- **7.6 Perf pass** — body sleeping, a soft max-body guard with a `log` when exceeded, pooling for
  Ball Storm. · Done-when: 60+ active bodies hold ~60fps in a stress level.

**Edge cases & risks:** perf with many rigidbodies (Ball Storm + structure + chains simultaneously);
high-speed tunneling (CCD); props crossing `bounds` (despawn, no score); a player can never *rest* on a
prop (it's bounceable, not standable — INV-11 holds); chain explosions must terminate (a bomb explodes
once). **Invariants:** INV-2/3/4/10/11/12.

### P8 — Gravity Fields  [EXPANDED]
> Gravity-generating surfaces — radial planetoids & directional walls (`GAME_DESIGN.md` §4.8). The big
> payoff of INV-1: because gravity was a queried field from day 1, this is additive, not a rewrite.
> **Resolve first:** aim-frame (recommend **screen-relative** — confirm), falloff (recommend
> **constant-within-zone** over 1/r² for readability), multi-source blending (priority/zone +
> transition band), character-rotation feel, do props obey fields too (recommend yes).

**Design — classes & interactions:**
- **`GravityField`** (autoload — extends the P0 stub) — *the field resolver (INV-1).*
  - State: `sources: Array[GravitySource]`.
  - Methods: `register(src)`, `unregister(src)`, `get_gravity_at(pos) -> Vector2`: collect sources whose
    area contains `pos`; if none → global down (`Tuning.gravity`); else pick highest `priority` (or blend
    within a `transition_band`); return that source's `gravity_at(pos)`.
  - Collaborators: all GravityAffected bodies; `GravitySource`s self-register on `_ready`.
- **`GravitySource` (`Node2D`, base)** — State: `strength`, `priority`, shape. Methods: `contains(pos)`,
  `gravity_at(pos) -> Vector2`.
  - **`RadialGravitySource`** — `center`, `radius`; `gravity_at = (center - pos).normalized() * strength`
    (pulls inward → planetoid); `contains = pos.distance_to(center) < radius`.
  - **`DirectionalGravitySource`** — `rect`, `dir`; `gravity_at = dir * strength`; `contains = rect.has_point(pos)`.
- **`GravityOrientation`** (component on `Player`/`Prop`, **visual only**) — lerps the *body sprite's*
  rotation toward local-down so "which way is down here" reads. **Aim stays screen-relative** — the
  jetpack/aim-arrow ignore this (decided). Lerp speed in `Tuning`.
- **Player/Prop movement:** unchanged in logic — already calls `get_gravity_at()` (INV-1), and bounce
  launch / min-bounce / drift already operate **along the local gravity vector** (`FEEL_REFERENCE.md`
  §1). Props (`RigidBody2D`) read the field in `_integrate_forces` and set their gravity (keeps one
  source of truth rather than Godot Area2D gravity).
- **Radial blast zone:** `bounds` gains a radial mode (`max_radius` from a source); `KillPipeline`
  ring-out checks it. Super-boost off a planetoid → cross max-radius → `self_destruct` (on-theme).
- Interactions: `GravityField` ↔ all bodies (read) ↔ `GravitySource`s (register) ↔ `LevelLoader`
  (builds sources from `gravity_source` JSON) ↔ `KillPipeline` (radial bounds).

**Data & Tuning:** per-source `strength`/`priority`/shape (JSON `gravity_source`, `GAME_DESIGN.md` §15);
`transition_band` width; `gravity_orientation_lerp` speed. **Events:** optional `gravity_zone_changed`
(juice/sfx). 

**Stages → steps** (expand at 8.0):
- **8.0** Expand; resolve the open Qs; confirm aim-frame = screen-relative.
- **8.1** `GravitySource` base + `RadialGravitySource` + `GravityField` registry/resolution. Test
  "planetoid" level (ring of bounce surface + central radial source). · Done-when: a player bounces
  around the *outside* of the planetoid from all sides; those "below" fall *up* toward it; loop holds.
- **8.2** `DirectionalGravitySource` (wall) + zone/priority blending + transition band. · Done-when:
  fly up a gravity wall, bounce sideways off it, fall back to it; moving between zones doesn't snap.
- **8.3** `GravityOrientation` (visual body rotation) + confirm aim/arrow stay screen-relative.
  · Done-when: body feet point to local-down; stick-up still thrusts screen-up; arrow correct.
- **8.4** Radial blast zone + super-boost-into-void self-destruct. · Done-when: over-boosting off a
  planetoid rings you out.
- **8.5** Props obey fields (`_integrate_forces`). · Done-when: a heavy ball orbits/falls toward a
  planetoid correctly.
- **8.6** Feel/tuning pass (strength, band, rotation lerp).

**Edge cases & risks:** overlapping sources (priority/blend, avoid jitter at boundaries); pos outside
all sources (global down); smooth zone transitions (no snap); **bots must use local gravity for
recovery/aim** (flag for P10); perf of per-body field queries (cache per physics tick). **Invariants:**
INV-1 (core), INV-11 (still no standing — you bounce off the planetoid surface).

### P9 — Party Mode (full)  [EXPANDED]
> The full competitive mode beyond P4's throwaway loop (`GAME_DESIGN.md` §3, §7). Match flow, scoring,
> sudden-death, spawn intro, leaderboard, lobby, circuit cycling. **Resolve first:** max player count;
> negative-score floor (recommend floor at 0); round-timeout trigger (recommend closing-lasers as
> general anti-stalemate after a max round time).

**Design — classes & interactions:**
- **`PartyMode` (`GameMode` subclass)** — *match orchestrator.*
  - State: `players`, `scores`, `circuit`, `stage_queue` (shuffled), `point_target=10`, a **round state
    machine** (`Lobby → SpawnIntro → Fighting → RoundEnd → [SuddenDeath] → Leaderboard → NextStage …
    → MatchEnd`).
  - Methods: `start_match(config)`, `next_round()`, `_on_killed(victim,cause,attacker)` (→ scoring +
    round-over check), `check_round_over()`, `start_sudden_death(finalists)`, `end_match(winner)`.
  - Collaborators: `KillPipeline`, `SpawnIntroSequencer`, `ScoreSystem`, `SuddenDeath`, `CircuitManager`,
    `LevelLoader`, `CameraController` (Locked), `Leaderboard`, `EventBus`, `ProgressionTracker` (P15).
- **`MatchConfig`** — `player_devices`, `bot_count`, `circuit_id`, `point_target`.
- **`ScoreSystem`** — per-player points; `award_kill(+1)`, `award_survival(+1)`, `penalize_suicide(−1)`;
  floor rule (TBD). Emits `point_scored(player, reason)`.
- **`SpawnIntroSequencer`** — spawns players **one-by-one** with a cool entrance, then fires the
  **"BOUNCE!"** go signal → transitions to Fighting. Timings in `Tuning`.
- **`SuddenDeath`** — listens for the final eliminations; if the last players die **within 0.25s** of
  each other (no clear survivor), revives the tied finalists into a duel and spawns **`LaserWall`
  hazards** on the left/right edges that **close toward center** (instakill `Hazard`s driven inward).
  Last one bouncing wins the round.
- **`CircuitManager`** — circuit definitions; on match start **shuffles** the circuit's stages into
  `stage_queue`; serves next stage, **repeating the cycle** if the circuit is shorter than the match
  needs (`GAME_DESIGN.md` §7).
- **`Leaderboard`** (UI) — running totals, shown on the **loading screen** between rounds.
- **`Lobby`** (UI) — join (device→slot), add/remove bots, pick circuit, start. (Minimal here; P18 polishes.)
- Interactions: `PartyMode` is the hub; everything else subscribes/serves. Camera is **Locked** (INV-5).
  Bots are just players with `InputBot` (INV-8). All deaths flow through `KillPipeline` (INV-9).

**Data & Tuning:** `point_target` (10), `sudden_death_window` (0.25s), laser close-speed/spawn,
spawn-intro per-player delay + go-delay, `round_time_limit` (anti-stalemate trigger). **Events:**
`round_started/ended`, `match_started/ended`, `point_scored`, `sudden_death_started`, `player_spawned`.

**Stages → steps** (expand at 9.0):
- **9.0** Expand; resolve max-players / score-floor / timeout Qs.
- **9.1** Match + round state machine (replaces P4.1 throwaway loop) → first-to-10, stage advance.
  · Done-when: a full match runs start→winner across multiple stages.
- **9.2** `ScoreSystem` (+kill/+survive/−suicide, floor). · Done-when: scores update correctly per rules;
  HUD reflects them.
- **9.3** `SpawnIntroSequencer` (one-by-one entrance + "BOUNCE!"). · Done-when: players appear one at a
  time, then a clear go.
- **9.4** `SuddenDeath` (0.25s tie → finalists duel + closing lasers). · Done-when: a near-simultaneous
  double-KO triggers the duel; lasers close; a winner emerges.
- **9.5** `Leaderboard` on loading screen. · Done-when: standings show between rounds.
- **9.6** `Lobby` (join, bot count, circuit pick) — minimal. · Done-when: configure & start a match.
- **9.7** `CircuitManager` shuffle/cycle integration (stub one circuit until P11). · Done-when: a match
  cycles a circuit's shuffled stages, repeating if needed.

**Edge cases & risks:** 3+ players dying within 0.25s (all become finalists?); negative scores; a bot
winning the match; couch player drop mid-match; round-timeout stalemate (→ closing lasers); ties at the
point target (play until a clear leader). **Invariants:** INV-5, INV-8, INV-9, INV-13.
- **P9 Party Mode (full)** — scoring (+kill/+survive/−suicide), sudden-death closing-lasers, 1-by-1
  spawn intro, loading-screen leaderboard, lobby + bot-count. *Resolve first:* max players, negative
  score floor, round-timeout trigger.
### P10 — Bot AI Depth  [EXPANDED]
> Turn P3's basic bot into the real human-sim with 5 difficulty levels × 4 dials (`GAME_DESIGN.md` §8).
> **Bots never cheat** (INV-8) — difficulty is *execution quality* only.

**Design — classes & interactions:**
- **`InputBot` (`InputProvider`, from P3)** — produces `InputIntent` each tick from a `BotBrain`.
- **`BotBrain`** — the perceive→decide→act loop.
  - **Perceive** (`BotPerception`): self state (pos, vel, fuel, stunned), **local gravity** (P8),
    nearest threats/targets, nearest edge/blast-zone, powerups, incoming props/explosions.
  - **Decide** (utility/behavior selection among modules): `BankFuel`, `HuntTarget`, `EdgeRecovery`,
    `UsePowerup`, `Evade`. Picks by a utility score weighted by the profile dials.
  - **Act**: emit `InputIntent` (aim, boost, super, use_powerup, flap).
- **`BotProfile` (Resource)** — the 4 dials: `aim_error` (radians of jitter + lead error),
  `reaction_time` (s of delay before responding), `recovery_skill` (P(successful edge recovery);
  low → panic-boosts off the map = funny), `aggression` (hunt vs passive + powerup eagerness). 5
  presets **L1–L5** in `Tuning`.
- Behavior modules (each reads perception + dials → candidate intent):
  - `BankFuel` — bounce on good tiers to refill (always-on baseline; respects no-turtle, INV-11).
  - `HuntTarget` — pick a target, position, aim super-boost with `aim_error`, time it; scaled by `aggression`.
  - `EdgeRecovery` — when launched toward a blast zone, aim opposite the velocity and boost back —
    success gated by `recovery_skill` (and **uses local gravity**, P8). L1 over-boosts into oblivion.
  - `UsePowerup` — activate held powerup at a sensible moment; eagerness by `aggression`.
  - `Evade` — dodge incoming smashes/props by `reaction_time`.
- **Campaign archetype hook:** `BotProfile` + a behavior tweak = the campaign enemy archetypes
  (Heavy/Aggressive/Evasive/Flyer/Shielded) consumed by P13.
- Interactions: `InputBot` ↔ `BotBrain` ↔ perception (reads world/`GravityField`) ↔ `Tuning` (profiles).
  Output is just `InputIntent` — fully interchangeable with humans (INV-8).

**Data & Tuning:** 5 profiles × 4 dials; per-behavior weights; perception ranges. **Events:** none
required (bot is a provider); may listen to `EventBus` for reaction cues.

**Stages → steps** (expand at 10.0):
- **10.0** Expand; define utility model + dial ranges.
- **10.1** `BotPerception` (self/threats/targets/edges/gravity/powerups). · Done-when: bot has accurate
  world awareness (debug overlay shows its picks).
- **10.2** Core behavior loop (BankFuel/HuntTarget/EdgeRecovery/UsePowerup/Evade). · Done-when: a
  mid-level bot plays a coherent, fair game.
- **10.3** 4 dials + 5 profiles. · Done-when: L1–L5 are distinguishable in play.
- **10.4** "Funny-low / scary-high" tuning. · Done-when: L1 flails & self-destructs amusingly; L5 feels
  precise and threatening.
- **10.5** Archetype hooks for campaign (profile+tweak presets). · Done-when: archetypes are
  expressible as data for P13.

**Edge cases & risks:** bots must use **local gravity** for recovery (P8 dependency); bots in sudden
death; bots using powerups sensibly; perf with many bots (cap perception cost / stagger thinking).
**Invariants:** INV-8 (no cheating).
### P11 — Content + Circuits  [EXPANDED]
> Mature the level format, build many handcrafted stages, organize into themed circuits with a
> difficulty/craziness ramp (`GAME_DESIGN.md` §7). Content-heavy more than class-heavy. **Resolve
> first:** circuit list/themes; stages-per-circuit (≥10); **which mechanics appear in which circuit**
> (the onboarding gate — tame circuits first, wild mechanics introduced one circuit at a time).

**Design — classes & interactions:**
- **`CircuitDef` (Resource)** — `id`, `theme` (visual set + mechanical flavor), `stages: Array[path]`,
  `difficulty_rank`, `unlock_requirement` (→ P15). Consumed by `CircuitManager` (P9).
- **`LevelValidator`** — automated content audit of a JSON level: **no standable ground** (INV-11!),
  ≥1 spawn per max player, bounds present & sane, palette valid, objects well-formed, basic
  reachability heuristic. Run on every authored/generated level. *This is the guard that keeps
  AI-generated content from shipping broken.*
- **Authoring pipeline:** levels are JSON (Phase-1 no editor; P12 adds one). AI mass-generates
  candidates → `LevelValidator` filters → human curates (spatial "is it fun", `GAME_DESIGN.md` §14).
- Interactions: `CircuitDef` ↔ `CircuitManager` (P9) ↔ `LevelLoader`; `LevelValidator` ↔ authoring.

**Data:** `CircuitDef`s; a `circuits/` content dir; level JSON files in `levels/`. **Stages → steps:**
- **11.0** Expand; decide circuit list/themes + the mechanic-gating-by-circuit map.
- **11.1** Level format hardening v2 + `LevelValidator` (incl. no-standable-ground check). · Done-when:
  validator rejects a level with standable ground and accepts a good one.
- **11.2** Authoring helpers: batch level-preview tool; an AI-generation guidelines note. 
- **11.3** Circuit 1 (tame): ~10 stages, pure bounce/jetpack/smash, no wild mechanics.
- **11.4** Circuit 2: + basic powerups (needs P6).
- **11.5** Circuit 3: + physics sandbox (needs P7).
- **11.6** Circuit 4: + gravity fields (needs P8).
- **11.7** Circuit 5+: wild combos, hardest.
- **11.8** Difficulty/craziness ordering + variety pass. · Done-when: circuits play in a satisfying
  easy→wild ramp; every level passes the validator.

**Edge cases & risks:** content volume (Duck Game ships 80–100+; v1 target fewer but varied); readability
on placeholder art; each level must pass the validator; mechanic-gating must match what's built.
**Invariants:** INV-7 (JSON only), INV-11 (validator enforces).

### P12 — Level Editor  [EXPANDED]
> In-engine paint/place editor + live-playtest toggle, reading/writing the same JSON
> (`GAME_DESIGN.md` §14). **Owner is hands-on here (UI feel).** Phase-2 pipeline. **Resolve first:**
> v1 editor MVP scope (recommend: paint tiles, place objects, set bounds, save/load, playtest toggle;
> bounce-arc preview is later).

**Design — classes & interactions:**
- **`EditorScene`** (tool scene) hosting:
  - **`LevelSerializer`** — scene/edit-state → JSON; **must round-trip** with `LevelLoader` (INV-7:
    `load(save(level)) == level`).
  - **`TilePainter`** + **`PaletteUI`** — paint bounce tiers onto the grid.
  - **`ObjectPlacer`** — drop free-position objects (hazards, spawns, spawners, gravity_sources, props,
    bombs, structures).
  - **`BoundsEditor`** — set the blast-zone.
  - **`PlaytestToggle`** — swap edit-mode ↔ live play **in place** using the real runtime, then back.
  - *(Later)* **`BounceArcPreview`** — simulate a bounce/boost trajectory to show reachability.
- Interactions: editor ↔ `LevelSerializer` ↔ `LevelLoader` (round-trip) ↔ `LevelValidator` (P11, warn
  on violations) ↔ the real game runtime (playtest).

**Stages → steps:**
- **12.0** Expand; lock MVP scope.
- **12.1** `LevelSerializer` round-trip (JSON↔scene). · Done-when: load→save→load is identical.
- **12.2** `TilePainter` + `PaletteUI`. · **12.3** `ObjectPlacer`. · **12.4** `BoundsEditor`.
- **12.5** Save/Load + `LevelValidator` warnings. · Done-when: author & save a playable level from scratch.
- **12.6** `PlaytestToggle` (edit↔live in place). · Done-when: paint → playtest → tweak loop works.
- **12.7** *(later)* `BounceArcPreview`.

**Edge cases & risks:** UI feel is the owner's domain (the one hands-on area, `GAME_DESIGN.md` §14);
round-trip fidelity is critical (INV-7); editing with physics paused. **Invariants:** INV-7.

### P13 — Campaign Framework  [EXPANDED]
> Side-scrolling 3-part missions (explore → arena → escape), scrolling+locking camera, ~5 lives, wave
> spawner, enemy archetypes (`GAME_DESIGN.md` §7 Mode 2). Reuses the entire core (INV-13). **Resolve
> first:** v1 mission count/structure; how sections are defined in level data; in-level checkpoints;
> co-op camera rules.

**Design — classes & interactions:**
- **`CampaignMode` (`GameMode` subclass)** — runs a mission: load level, drive a **section state
  machine** (`Part1 Explore → Part2 Arena → Part3 Escape → Complete`), manage lives/respawn, win/lose.
- **`LevelSection`** — a segment with `type` (explore/arena/escape), `camera_mode`, x-range, and
  (for arenas) wave data. Defined in the level JSON (`sections` array).
- **`CameraController`** (FollowScroll mode, §8) — follows player(s) in explore/escape; **locks** for
  arenas (INV-5). **Co-op:** frame both players; a player who falls too far behind the scroll dies / is
  pulled.
- **`WaveSpawner`** — arena sections: spawn enemy **waves** scaling by count + skill + archetype mix;
  emit `arena_cleared` when done → unlocks forward progress.
- **`EnemyArchetype`** — a `BotProfile` (P10) + stat/behavior tweak: Heavy / Aggressive / Evasive /
  Flyer / Shielded. Enemies are `InputBot`-driven players (INV-8).
- **`LivesSystem`** + **`Checkpoint`** — ~5 lives/level; respawn at last checkpoint; out of lives → retry.
- **`MissionDef` (Resource)** — level path, enemy sets, intro/outro, unlock rewards (→ P15).
- **Death routing (INV-9):** *enemy* death = removed/scored toward wave; *player* death = lose a life
  (explore/escape: pits/hazards/fall-behind; arena: ring-out + hazards). All via `KillPipeline`.
- Interactions: `CampaignMode` ↔ `CameraController` (section-driven mode switch) ↔ `WaveSpawner` ↔
  enemies ↔ `LivesSystem`/`Checkpoint` ↔ `KillPipeline` ↔ `ProgressionSystem` (P15).

**Stages → steps:**
- **13.0** Expand; resolve Qs; define the `sections` schema.
- **13.1** `LevelSection` schema + section state machine (explore→arena→escape→complete).
- **13.2** `CameraController` FollowScroll + arena-lock + co-op framing/fall-behind. · Done-when: camera
  scrolls then locks for the arena then scrolls again; co-op stays framed.
- **13.3** `LivesSystem` + `Checkpoint` + respawn + retry.
- **13.4** `WaveSpawner` (scaling waves, `arena_cleared`). · Done-when: arena spawns escalating waves;
  clearing them opens the path.
- **13.5** 5 `EnemyArchetype`s on the bot core.
- **13.6** Mission flow (intro→parts→outro→next); **1 full sample mission**. · Done-when: a complete
  3-part mission is playable solo & co-op.
- **13.7** A few missions of content.

**Edge cases & risks:** co-op camera with players far apart; correct death-source routing per section;
arena lock entry/exit feel; perf with many enemies. **Invariants:** INV-5, INV-8, INV-9, INV-13.

### P14 — Bosses  [EXPANDED]
> Boss fights every few missions (`GAME_DESIGN.md` §7). The **one HP exception** (INV-9), damaged only
> by the environment + your toolkit. **Resolve first:** v1 boss count; each boss's specific gimmick;
> telegraph/vulnerable-window design.

**Design — classes & interactions:**
- **`Boss` (entity)** — *the ONLY `Killable` with an HP pool (INV-9).*
  - State: `hp`, `phase`, `vulnerable: bool`, `current_attack`.
  - Methods: `take_damage(amount, source)` (**only** during a vulnerable window, via environmental
    hits); a behavior state machine `Telegraph → Attack → VulnerableWindow → …` with phase changes as
    `hp` drops.
- **`BossArena`** — a boss level (no 3-part journey; camera **locked**).
- **`BossAttack`** (modules) — per-boss attacks threatening players via existing systems (knockback,
  spawned hazards, slams) — they can ring you out / smash you into instakill hazards (your lives apply).
- **Damage gimmicks (reuse P7):** weak-spot hitbox (super-boost into it), `DestructiblePlatform` (drop
  a spike on its head), or knock the boss into a hazard (lava/crusher) via `Forces`/smash.
- **`BossDef` (Resource)** — `hp`, phases, attack set, damage gimmick, intro/outro.
- **HUD:** the **one health bar** in the game (boss only).
- Interactions: `Boss` ↔ `BossAttack` ↔ players (knockback) ↔ damage gimmicks (P7) ↔ `KillPipeline`
  (player deaths normal; boss death special) ↔ `CampaignMode` ↔ boss-health HUD.

**Stages → steps:**
- **14.0** Expand; design the specific bosses + gimmicks + telegraphs.
- **14.1** `Boss` base (hp, phase state machine, vulnerable window, health-bar HUD). · Done-when: a boss
  takes environmental damage only during its window and changes phase as hp drops.
- **14.2** `BossAttack`s (telegraph → attack → recovery) that threaten players.
- **14.3** Damage-gimmick integration (weak-spot / drop-spike / smash-into-hazard).
- **14.4** **Boss 1** end-to-end (winnable, readable, fun). 
- **14.5** Boss roster (variety of gimmicks).

**Edge cases & risks:** HP exists *only* here (audit INV-9 — nothing else gains hp); co-op bosses;
player lives during the fight; **the damage opportunity must be telegraphed/readable**. **Invariants:**
INV-9 (the audited exception), INV-3/4 (knock boss into hazards).

### P15 — Progression & Unlocks  [EXPANDED]
> Campaign + party unlocks feeding one shared collection, on a **paced-scarcity** economy
> (`GAME_DESIGN.md` §7 — no unlock-all; drops timed to land as mid-session "we gotta try this!"
> events). **Resolve first:** the unlock thresholds/cadence (tune against **session time**, ~25 & ~45
> min beats), the reward list (characters/circuits/modifiers/powerups).

**Design — classes & interactions:**
- **`ProgressionSystem` (autoload)** — owns stats (total kills, matches, powerups_used, campaign
  progress); evaluates `UnlockDef` conditions; grants unlocks; persists via `SaveSystem` (P18).
- **`ProgressionTracker`** — subscribes to `EventBus` (`killed`, `match_ended`, `powerup_used`,
  mission-complete) → updates stats (INV-12).
- **`UnlockDef` (Resource)** — `id`, `type` (character/circuit/modifier/powerup), `condition` (stat
  threshold or campaign milestone).
- **`Collection`** — owned characters/powerups/modifiers, **shared across both modes**.
- **`ModifierSystem`** — unlockable match modifiers (e.g. double-speed-boost mode) toggleable in the lobby.
- **Unlock fanfare** — a notification surfaced with celebration on unlock.
- Interactions: `ProgressionTracker` ↔ `EventBus` ↔ `ProgressionSystem` ↔ `Collection` ↔ `Lobby`
  (shows unlocks/modifiers) ↔ `SaveSystem`.

**Stages → steps:**
- **15.0** Expand; design thresholds (session-time-tuned) + reward list.
- **15.1** `ProgressionTracker` stats + `EventBus` hooks.
- **15.2** `UnlockDef` + `ProgressionSystem` evaluation + grant.
- **15.3** `Collection` + shared roster across modes.
- **15.4** `ModifierSystem` (match modifiers in lobby).
- **15.5** Unlock fanfare/notification.
- **15.6** Persistence (with P18 `SaveSystem`).
- **15.7** **Paced-scarcity tuning pass** — verify drops land as exciting mid-session events, never a grind, never all-at-once.

**Edge cases & risks:** never gate a party night (no unlock-all, but the cadence must feel generous-yet-meaningful);
save versioning/migration; two unlock sources (campaign + party) feeding one collection. **Invariants:** INV-12.

### P16 — Final Art Integration  [EXPANDED]
> Replace the placeholder kit with Yulia's art while preserving the code rigs. **Resolve first:** final
> art style, character roster, animation pipeline (sprite sheets vs skeletal/Spine), resolution/scale.

**Design — classes & interactions:**
- **`CharacterSkin` (Resource)** — per-character sprite/animation set (idle/fly, boost, hit, celebrate)
  + jetpack art + exhaust. **Squash/stretch + launch tumble stay CODE** (node scale/rotation) — art is
  the static/anim base only (`GAME_DESIGN.md` §10).
- **Asset-replacement convention** — final art keeps the **same pivots/anchors** as placeholders so the
  jetpack rotation rig (INV-10) and code squash keep working unchanged.
- Interactions: skins ↔ `Player` (visual only); jetpack stays a **separate code-rotated sprite** (INV-10).

**Stages → steps:** **16.0** expand + pipeline decision · **16.1** import pipeline + pivot conventions ·
**16.2** character skins replace creatures · **16.3** jetpack + exhaust final · **16.4** surfaces/tiles ·
**16.5** hazards/props/bombs · **16.6** UI/HUD art · **16.7** consistency/readability pass.
· Done-when: final art is in with all code rigs (jetpack aim, squash, tumble) intact and readable in
4–8-player chaos.

**Edge cases & risks:** keep pivots consistent or rigs break; perf of richer art; vector vs raster
scaling. **Invariants:** INV-10 (jetpack rig preserved), INV-12.

### P17 — Audio & Music  [EXPANDED]
> SFX coverage, music, mixing — the Rule-of-Three audio channel (`FEEL_REFERENCE.md` §5).

**Design:** **`AudioManager` (autoload)** plays SFX in response to `EventBus` events
(bounce/boost/smash/explosion/killed/powerup — INV-12), runs per-mode/per-circuit **music** with
transitions, manages buses/mix. Every meaningful action gets an audio channel (Rule of Three).
**Stages:** **17.0** expand · **17.1** `AudioManager` + event→SFX map · **17.2** SFX coverage pass
(every action) · **17.3** music system (per circuit/mode + transitions) · **17.4** mix/buses/ducking
(e.g. duck under hitstop) · **17.5** settings volumes · **17.6** polish. · Done-when: every action reads
clearly in audio; music fits each mode/circuit.
**Edge cases:** audio during hitstop/slow-mo (pitch handling); voice-pool limits under chaos.
**Invariants:** INV-12.

### P18 — UI / Menus / Meta  [EXPANDED]
> Title, navigation, lobby polish, options, accessibility, and the save system.

**Design:** **`MenuSystem`** (title → mode select → lobby → options), **`OptionsMenu`** (audio +
**accessibility toggles**: rumble, screen-shake, slow-mo intensity), **`SaveSystem` (autoload)** —
persist progression/settings/unlocks to `user://` (versioned), **`PauseMenu`**, results screens. All
controller-navigable.
**Stages:** **18.0** expand · **18.1** `SaveSystem` (versioned load/save) · **18.2** title + nav ·
**18.3** mode select + lobby polish (from P9.6) · **18.4** options + accessibility · **18.5**
pause/results screens · **18.6** full controller navigation. · Done-when: a player can navigate the whole
game with a controller; settings/unlocks persist across runs.
**Edge cases:** controller-only menu nav; save versioning/migration; accessibility coverage.
**Invariants:** INV-12 (settings drive systems via config/signals).

### P19 — Polish & Performance  [EXPANDED]
> Final feel pass, performance under worst-case load, edge cases, bug bash. (A pass, not new systems.)

**Scope:** profile worst-case body counts (Ball Storm + collapsing structure + bomb chains + many
bots), add **object pooling** + soft body caps, final juice/feel tuning, **readability pass** for 4–8
player chaos, input feel, controller compatibility, and a **full invariant audit** (§1).
**Stages:** **19.0** plan · **19.1** perf profiling + pooling + body caps · **19.2** readability/feel
final pass · **19.3** edge-case + bug bash (audit ALL invariants) · **19.4** controller-compatibility
matrix · **19.5** full playtest sign-off. · Done-when: holds target framerate at worst case; no invariant
violations; playtests clean.
**Edge cases:** frame pacing; many-player input; worst-case simultaneous physics. **Invariants:** audit ALL.

### P20 — Release  [EXPANDED]
> Windows/Steam export, store prep, persistence finalization, launch.

**Scope:** Windows export preset + test builds; Steam integration (optional/if pursued); settings/save
finalization; store assets (capsule art, trailer, description); release-candidate testing; launch.
**Stages:** **20.0** plan · **20.1** Windows export preset + test build · **20.2** settings/save
finalization · **20.3** Steam page + assets (if Steam) · **20.4** RC testing on target hardware ·
**20.5** launch. · Done-when: a distributable build runs clean on a fresh Windows machine with
controllers, settings persist.
**Edge cases:** export templates/signing/distribution; controller support on target machines.

> **Post-launch (out of this plan's scope):** online netcode (physics sync — the hard one), extra modes
> (Coin Collect / King of the Hill / Race to the Top), team modes, more circuits/bosses/characters.

---

## 5. Change log
- 2026-06-27: Created. P0.1.1 done (skeleton **verified running in Godot 4.7**). Supersedes the
  standalone `BUILD_PLAN.md`.
- 2026-06-27: **All phases P0–P20 expanded** to full design depth (classes + interactions + stages +
  steps + edge cases + invariants). Magnet powerup removed. Doc is now the complete 0→launch spec.
- 2026-06-27: **Phase 0 (0.2–0.4) + Phase 1 code-built** (Tuning, GravityField, InputIntent, Forces
  stub, BounceResolver, LevelLoader, test_arena.json, Player bounce+drift, Main). Committed.
  **Phase 1 RUN-VERIFIED by owner ("it feels good").**
- 2026-06-27: **Phases 2, 3, 4 built & committed** (one commit each) — v0 feature-complete:
  - P2 jetpack/fuel/supercharge/super-boost + InputHuman + HUD fuel gauge.
  - P3 smash knockback + hitstun + KillPipeline + Hazard + InputBot + ring-out/respawn.
  - P4 EventBus + CameraController (locked+shake) + Juice (hitstop/rumble/flash) + round loop
    (eliminate→last-one-scores→first-to-10) + squash. **v0 playable: keyboard vs bot.**
  **Status = code-built per phase, NOT yet run-verified** (owner verified P1 only). Owner authorized
  building straight through w/o waiting for tests; rollback-per-phase is the safety net.
- 2026-06-27: **Phase 6 (partial) built & committed** — powerup framework (PowerupSystem/Pickup/
  Spawner) + unlimited_boost, mega_bounce, star, counter_shield. Deferred (need P7): air_mine,
  ball_storm. Still pending: wings, slow_mo, black_hole, ring_of_fire.
- 2026-06-27: **Phase 7 (Physics Sandbox) + Phase 8 (Gravity Fields) built & committed.**
  - P7: Prop (RigidBody, field gravity, physics-material bounce, smashes players, Impulsable/Smashable)
    + heavy_ball/spiked_ball/crate/bouncy; Bomb (fuse/exhaust-ignite/chain) + explosions via Forces +
    EventBus.exploded + Juice; Container spill; collapsible structures; ball_storm + air_mine powerups.
  - P8: GravitySource (radial planetoid + directional wall), body orients to local-down, test_gravity.json.
  **v0 simplifications noted:** props bounce via PhysicsMaterial (not BounceResolver); players don't
  physically collide with props (interact via hit-areas/smash only); structures topple but aren't solid
  to players. Refine in P19/P11 if needed.
  **Status: P2–P8 code-built, only P1 run-verified.** STOPPED here (after P8) — natural gate: owner
  should run/feel P2–P8 before P9+ (which need bigger Main reworks + human-gated phases). All committed,
  rollback-per-phase.
- 2026-06-27: **Phases 9–15 built & committed** (one commit each):
  - P9 full Party Mode (kill/survive/suicide scoring + attacker credit, sudden-death closing lasers,
    one-by-one spawn intro, deferred round resolution).
  - P10 bot depth (BotProfile, 5 levels × 4 dials, panic-boost low / precise high).
  - P11 content + circuits (CircuitManager shuffle/cycle, LevelValidator, 3-stage circuit, per-round stage load).
  - P12 level-editor foundation (LevelSerializer round-trip + minimal paint/save Editor — owner to flesh UI).
  - P13 campaign (CampaignMode: scroll+lock camera, ~5 lives, wave arena, enemy archetypes, goal).
  - P14 bosses (Boss = sole HP, telegraph→attack→vulnerable, weak-spot super-boost damage; BossArena).
  - P15 progression (SaveSystem + ProgressionSystem: stats→milestone unlocks, persisted, toast).
  **NOW BUILT: P0–P15** (only P1 run-verified; P2–P15 code-built, ~45 files, unverified by running).
  Scenes: Main.tscn (party), Campaign.tscn, BossArena.tscn, Editor.tscn.
- 2026-06-27: **Phases 17 + 18 built & committed** (P16 art skipped — gated on Yulia):
  - P17 audio: AudioManager autoload, event-driven SFX (voice pool + pitch variation). Music = follow-up.
  - P18 UI/menus: Title (mode select), Options (rumble/shake toggles persisted + unlocks list),
    GameFlow autoload (Esc → title). **Title.tscn is now the main scene.**
  **NOW BUILT: P0–P15, P17, P18** (only P1 run-verified; rest code-built, ~50 files, unverified by run).
  13 autoloads. Scenes: Title (main), Main (party), Campaign, BossArena, Editor, Options.
  **Remaining: P16 final art (Yulia), P19 polish/perf, P20 release.** P5 feel-tuning = human pass.
  Strongly recommend a run/verify pass now.
