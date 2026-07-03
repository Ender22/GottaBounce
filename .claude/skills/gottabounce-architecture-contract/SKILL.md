---
name: gottabounce-architecture-contract
description: The load-bearing architecture contract for GottaBounce — the 13 INV invariants (in full, with rationale), autoload order, runtime scene tree, collision layers, the EventBus/KillPipeline signal surface, PartyMatch and Player state machines, the level JSON schema, and known-weak points. Load this BEFORE writing or reviewing any gameplay/system code, adding an entity, autoload, signal, level object type, or collision layer, or when asking "where does X live / who talks to whom / is this allowed?". Do NOT load for live constant values (see skill gottabounce-tuning-and-flags) or game-feel theory like bounce math and hitstun design (see skill game-feel-reference).
---

# GottaBounce architecture contract

**What this covers:** the seams every change must respect — the INV-1…13 invariants restated in
full (their canonical text otherwise lives only in `docs/reference/`), the concrete map of the
running game (autoloads, scene tree, collision layers, signals, state machines, level JSON), and
the known-weak points a new engineer would otherwise trip over.
**Not this skill:** constant values and how to change them (→ skill `gottabounce-tuning-and-flags`),
feel theory / why the numbers are what they are (→ skill `game-feel-reference`), symptom-driven
triage (→ skill `gottabounce-debugging-playbook`), running the game (→ skill
`gottabounce-run-and-playtest`), incident narratives (→ skill `gottabounce-failure-archaeology`).

## Why this contract exists

The previous GottaBounce project (untouched at `D:\Dropbox\MyGames\GottaBounce`; its docs are
copied to `docs/reference/`) failed on execution, not design. Its architecture seams were RIGHT:
because gravity was a queried field, bounce was body-agnostic, and input was an abstract intent
from day one, every later feature was additive instead of a rewrite. This rebuild re-adopted those
seams wholesale. The contract's own framing (docs/reference/ARCHITECTURE.md §0) calls the failure
mode "houses built on stilts": if the core hardcodes the simple case, every rich system on top
becomes a ground-up rewrite. Each seam below costs almost nothing to keep general now and costs a
rewrite to retrofit later. **Honor the seams; design everything else however is best.**

## The 13 invariants (INV-1…INV-13) — audited on every change

Canonical source: `docs/reference/MASTER_BUILD_PLAN.md` §1 (lines 58–82), restating
`docs/reference/ARCHITECTURE.md` §1. Those files are the OLD project's docs — CLAUDE.md's read
order lists a `docs/ARCHITECTURE.md` that does not exist (2026-07-03). **This skill is the
accessible in-repo home of the invariant text.** New specs cite INV numbers directly.

| # | Invariant | Where it lives in THIS repo (verified 2026-07-03) |
|---|---|---|
| INV-1 | **Gravity is a field.** All gravity via `get_gravity_at(pos)`. No hardcoded `Vector2(0, g)`. | `src/core/GravityField.gd` (autoload). Player.gd:328, StormBall.gd:54 both query it. |
| INV-2 | **Bounce is body-agnostic.** A shared resolver bounces anything (players + props); "bounceable" is a capability a body has, surfaces are not assumed static. | `src/core/BounceResolver.gd` — pure static functions `resolve()` / `resolve_bumper()`; surfaces carry tier via metadata (`bounce_tier_height` / `bumper`), set in LevelLoader.gd:85-88. |
| INV-3 | **One radial impulse.** A single `apply_radial_impulse(center, radius, impulse)` moves all dynamic bodies (players + props). | `src/core/Forces.gd` — iterates group `"impulsable"`, calls `apply_impulse_vector()`. Player and StormBall both join the group and implement the method. NOTE: currently has **zero callers** (see Known-weak points). |
| INV-4 | **Player/prop interop.** Players (`CharacterBody2D`, hand-authored) and props (`RigidBody2D`) interact both ways via shared interfaces. | Player = CharacterBody2D (Player.gd:2); StormBall = RigidBody2D implementing `receive_smash` + `apply_impulse_vector` (StormBall.gd:125-129); Player._handle_smashes has a props branch (Player.gd:637-644). |
| INV-5 | **Camera is pluggable.** Locked vs follow-scroll behind one abstraction; no system assumes a fixed camera. | `src/systems/CameraController.gd` — `dynamic` flag; Party sets `dynamic = true` and feeds `set_frame(center, zoom)`; locked/driven modes keep `dynamic = false`. |
| INV-6 | **All feel constants in the Tuning resource.** Nothing feel-related hardcoded. | `src/core/Tuning.gd` (autoload, plain vars — hot-settable via gbplay eval). Known wrinkles listed under Known-weak points. |
| INV-7 | **JSON is the only level source.** Versioned; generator/editor/runtime all use it. | `src/core/LevelLoader.gd` + `levels/dev_arena.json` (`"version": 2`). Schema below. |
| INV-8 | **InputIntent abstraction.** Gameplay reads intent; humans and bots interchangeable; **bots never cheat** (difficulty = input quality only). | `src/core/InputIntent.gd` (RefCounted struct); providers `src/core/InputHuman.gd` (action map only, never raw keycodes) and `src/core/InputBot.gd` (+ `BotProfile.gd` dials). Player consumes `provider.poll()` only (Player.gd:309). |
| INV-9 | **One kill pipeline with a cause.** Only bosses ever have HP; players never do. | `src/systems/KillPipeline.gd` (autoload) — everything routes through it; the sole direct call is `KillPipeline.kill(self, cause, attacker)` at Player.gd:791, funneled through `Player.kill()`. The cited cause-origination lines are `Player.kill()`/`body.kill()` wrappers, NOT direct pipeline calls: `ring_out` (PartyMatch.gd:302 `p.kill(&"ring_out", null)`), `hazard` (Hazard.gd:12 `body.kill(&"hazard", null)`), `laser` (LaserWalls.gd:75 `p.kill(&"laser", null)`). No boss exists yet, so no HP anywhere. |
| INV-10 | **Jetpack rig.** Separate code-rotated sprite + exhaust emitter; exhaust is an ignition source. | Partially realized in v0: exhaust = two world-space CPUParticles2D repositioned per-frame to the nozzle opposite aim (Player.gd:899-935); aim arrow is a code-rotated child. The jetpack itself is currently baked into the character sprite (Player.gd:142 comment). Ignition-source behavior: not implemented (no bombs yet). |
| INV-11 | **No standable ground / no turtling.** Surfaces never let you settle; brief active airborne powerups are fine. | Min-bounce floor in BounceResolver.gd:17 (`min_bounce_height`); idle-hunt rule (PartyMatch.idle_hunt_target, Player.secs_since_input); super aim-hover hard-capped at `super_aim_max` with auto-fire. |
| INV-12 | **Presentation subscribes to events; never owns sim state.** | `src/systems/EventBus.gd` (autoload) + `src/systems/Juice.gd`, `ArenaRenderer.gd`, HUD — all subscribe; none write sim state. Signal inventory below. |
| INV-13 | **One physics core serves both modes.** No mode-forked movement/physics. | Only one mode exists (PartyMatch), but the core (Player/BounceResolver/GravityField) has no mode branches; `src/dev/Playtest.gd` (headless harness) reuses the same core. |

**Why they hold, in one sentence each:** INV-1 makes planetoid/directional-gravity arenas additive
(the single most expensive retrofit); INV-2/3/4 make the physics-prop sandbox (Pillar 3 emergent
comedy — bomb → ball → player chains) possible without a rewrite; INV-5 avoids a camera rewrite
for a scrolling campaign; INV-6 makes the game tunable live — the prototype IS a tuning loop;
INV-7 lets an AI generator, a future editor, and the runtime share one stable format; INV-8 keeps
bots honest and lets devices/online drop in later; INV-9 hangs scoring, sudden death, and juice
off one event; INV-10 preserves aim-any-direction and future fuse-lighting; INV-11 is the design
pillar "never stop bouncing" made mechanical; INV-12 keeps juice/HUD out of the simulation;
INV-13 prevents the classic two-codebases-in-one-game rot.

## Autoload order (project.godot `[autoload]`) — order matters

```
Tuning                res://src/core/Tuning.gd
GravityField          res://src/core/GravityField.gd
EventBus              res://src/systems/EventBus.gd
KillPipeline          res://src/systems/KillPipeline.gd
PowerupSystem         res://src/systems/PowerupSystem.gd
McpInteractionServer  res://src/dev/mcp_interaction_server.gd
```

Godot initializes autoloads top-to-bottom, so an autoload may only reference autoloads ABOVE it
during `_ready()`. Live dependencies: `GravityField.get_gravity_at` reads `Tuning.gravity`;
`PowerupSystem._ready` connects to `KillPipeline.killed` and `EventBus.bounced_juicy`
(PowerupSystem.gd:34-36). Add new autoloads below their dependencies; putting a dependent above
its dependency fails at boot.

### The no-class_name-in-autoloads pattern

None of the six autoload scripts declares `class_name` (mcp_interaction_server.gd:5 says so
explicitly: "No class_name to avoid autoload conflict"). Godot 4 forbids an autoload sharing a
name with a global class, and autoloads cannot resolve `class_name` types at parse time.
Corollary pattern used throughout: **autoloads and hot-loaded systems reference entity scripts via
`load()`/`preload()` at runtime, never by class_name at parse time** — PowerupSystem.gd:20-21
loads StormBall/RingOfFire by path (its header comment states the rule); PartyMatch.gd:27 preloads
LaserWalls.gd, which deliberately has no class_name (LaserWalls.gd:7-8, "avoids a class-cache
rebuild dependency"). Entities that ARE referenced statically by other scripts (Player, InputBot,
BounceResolver, etc.) DO use class_name — after adding one, rebuild the class cache
(`--editor --quit` parse gate; see skill `gottabounce-run-and-playtest` for the command).

## Runtime scene map

Main scene is `scenes/Arena.tscn` — a single Node2D with `src/modes/PartyMatch.gd` attached;
everything else is built in code at `_ready()` (PartyMatch.gd:90-123):

```
Arena (Node2D, PartyMatch.gd)
├── _level_root (Node2D)
│   ├── ArenaRenderer (Node2D)          # ALL visual painting (Glossy Toybox); display-only
│   ├── StaticBody2D × N                # platform colliders from JSON (layer 3, meta tier)
│   └── Hazard (Area2D) × N             # spikes etc. from JSON (layer 4)
├── CameraController (Camera2D)         # dynamic=true in Party (Smash-style framing)
├── Juice (Node)                        # presentation subscriber (shake/hitstop/rumble/bursts)
├── PowerupSpawnDirector (Node)         # spawn pacing; points come from JSON powerup_spawner
├── Player × 4 (CharacterBody2D)        # P1 human (pink) + 3 bots (blue/green/yellow, L2/3/4)
├── MatchHUD (CanvasLayer, .tscn)       # corner cards + banners; UI is .tscn + Theme, always
└── transient: LaserWalls (Node2D), SDWarning (CanvasLayer, .tscn), NameTags, particle one-shots
```

Rules embedded here: UI lives under `CanvasLayer` (else it drags with the camera — old-project
lesson); UI is built as .tscn scenes + `assets/ui/theme.tres`, never imperative `Button.new()`
walls (CLAUDE.md non-negotiable); LevelLoader builds colliders authoritatively from JSON and
delegates every pixel to ArenaRenderer — art bleeds past colliders on purpose, colliders never
follow art.

## Collision layers

Godot layer numbers (bit = layer − 1), verified from the constants in code — there are no named
layers in project.godot:

| Layer | Bit mask | Meaning | Set by |
|---|---|---|---|
| 1 | `1 << 0` | players | Player.gd:10,116 |
| 2 | `1 << 1` | props (balls, future crates/bombs) | StormBall.gd:12,25 |
| 3 | `1 << 2` | bounce surfaces (platforms, bumpers) | LevelLoader.gd:13,78 |
| 4 | `1 << 3` | hazards | LevelLoader.gd:14,99 |

Who senses whom: Player body collides with surfaces only (mask `1 << 2`); Player's `_hit_area`
detects players + props (`(1<<0) | (1<<1)`); Hazard monitors players + props; StormBall collides
with surfaces + other balls ("pachinko"), its hit-area detects players; PowerupBubble/RingOfFire
detect players only. Keep this table true when adding entities — a wrong mask is silent.

## Signal surface (INV-12): who emits, who listens

`src/systems/EventBus.gd` — the sim emits, presentation subscribes. Deaths flow through
`KillPipeline.killed`, NOT EventBus. Verified inventory as of 2026-07-03:

| Signal (args) | Emitters | Subscribers |
|---|---|---|
| `bounced(body)` | Player._on_bounced | Playtest only (bounce counter) |
| `bounced_juicy(body, launch_speed, contact_point)` | Player._on_bounced | Juice (shake/dust), PowerupSystem (pickup-on-bounce FX hook) |
| `surface_bounced(surface, player, normal, contact_point)` | Player._resolve_bounces (tier + bumper paths) | ArenaRenderer (per-tier mat FX) |
| `smashed(attacker, victim, impulse)` | Player (star contact, licensed smash, counter-launch) | Juice, PartyMatch (contact flags + off-stage bookkeeping) |
| `super_boosted(player)` | Player._fire_super, Player.force_super_boost (Ring of Fire) | Juice (blast FX) |
| `super_fired(player, fuel_at_fire, aim_time, auto_fired)` | Player._fire_super | PartyMatch (round_stats QA feed) |
| `exploded(center, radius)` | **NONE** (no emitter exists yet) | Juice |
| `powerup_used(player, id)` | PowerupSystem.try_use | **NONE** (no subscriber yet) |
| `KillPipeline.killed(victim, cause, attacker)` | KillPipeline.kill (sole entry point) | PartyMatch (scoring), Juice (death burst/hitstop), PowerupSystem (death sweep), Playtest |

Contract when adding a mechanic: sim code emits; Juice/HUD/renderer react; nothing in
presentation writes velocity, fuel, scores, or state. `KillPipeline.kill()` is idempotent per
victim (checks `is_dead()`, calls `mark_dead()` before emitting) — never emit `killed` yourself
and never kill a player any other way.

## PartyMatch state machine (src/modes/PartyMatch.gd)

States (string `state` var): `BOOT` → `MATCH_START` (transient) → `ROUND_INTRO` (staggered
pop-ins) → `COUNTDOWN` (3-2-1) → `COMBAT` → optional `SUDDEN_DEATH` (laser walls; entered by
timer at `sudden_death_time` OR by double-KO revive) → `ROUND_END` (KO freeze) → next round, or
`MATCH_END` (first to `match_target_score` with a strict lead; rematch/quit prompt).

**The real-time-vs-scaled-delta trick** (PartyMatch.gd:156-172): hitstop works by scaling
`Engine.time_scale`, which shrinks `_physics_process` delta. Flow/UI beats must run on the wall
clock, so PartyMatch computes `rdelta = delta / maxf(Engine.time_scale, 0.05)` and ticks
intro/countdown/round-end/match-end timers with `rdelta`, while combat gameplay (`round_clock`,
lasers, idle bookkeeping) ticks with raw `delta`. The turnaround contract (death → next BOUNCE
≤ 4.5s) is measured on the wall clock via `last_death_msec` / `combat_start_msec`. If you add a
timed flow beat, pick the correct delta deliberately.

QA contract exposed for gbplay eval (deep interpretation → skill
`gottabounce-diagnostics-and-tooling`): `state`, `round_index`, `round_clock`, `scores`,
`last_death_msec`, `combat_start_msec`, `round_stats` (per-round dicts: `length_s`, `end_cause`,
`entered_sd`, `kills[{killer,victim,off_stage}]`, `survivor_had_contact`,
`supers_fired[{who,fuel_at_fire,aim_time,auto_fired}]`). Arena contract consumed by
InputBot/Playtest: `players`, `scores`, `bounds`, `nearest_opponent()`, `stage_rect()`,
`stage_center()`, `idle_hunt_target()`. Renaming any of these breaks bots, the headless harness,
and every QA eval script.

## Player state machine (src/entities/Player.gd)

One `_physics_process`, states as timers/flags — order per tick: dead check → frozen check
(pre-aim only) → cooldown ticks → black-hole channel (`_channel_timer`, hover + pull, early
return) → poll `InputIntent` → hitstun (`_stun_timer` — intent ZEROED, super press re-buffers
every held frame) → super AIM (`_sb_aiming`: floaty hover, stick steers, release or `super_aim_max`
auto-fires) → gravity → boost/drift → `move_and_slide` → `_resolve_bounces` → `_handle_smashes` →
speed cap → visuals.

Flag summary:
- `frozen` — suspension (intro/countdown/revive/KO freeze): zero velocity, no physics, stick
  still pre-aims the arrow.
- `_stun_timer > 0` — hitstun: no control, body tumbles; `_stunned_by` records the stunner.
- `_sb_aiming` — un-charged super aim-hover (lethality spec v2 §1): full power at any fuel ≥ min,
  drains the whole tank on fire, never scales with fuel (DO-NOT-REOPEN per DECISIONS 2026-07-02).
- `_channel_timer > 0` — Black Hole channel: frozen in place, pulls the `"players"` group.
- `_dead` — set only via `mark_dead()` from KillPipeline.

**The smash license** (Player.gd:616-618, the heart of the two-tier contact model): a contact is
a SMASH — knockback + hitstun + fuel sting + kill credit — only if
`(_super_recent > 0.0 OR (_stun_timer > 0.0 AND b != _stunned_by))` AND relative closing speed
≥ `smash_impact_min` AND I am the faster body (instance-id tiebreak). Everything else is a SHOVE
(`_soft_separate`: mutual momentum-scaled push, no hitstun). The `b != _stunned_by` clause is the
**pairwise smash immunity** that fixed the inverted-kill bug (a victim's out-flying stunned body
counter-smashed its own attacker — landing a super was suicide, 9/9). When a stunned flying body
smashes a third player, `credit_attacker()` reassigns kill credit to the launcher so uncontrolled
projectiles can't farm points. Props skip the license: a fast heavy ball IS a weapon (plain speed
gate). Touch this predicate only through change control with both-directions QA (kill AND
survive sides — see skill `gottabounce-validation-and-qa`).

## Level JSON schema (INV-7) — current, from levels/dev_arena.json + LevelLoader.gd

```json
{
  "name": "Grassy Knoll", "version": 2, "theme": "grass",
  "sky_top": "#2e6cb0", "sky_bottom": "#bfe6ff",
  "bounds": { "left": -620, "right": 2520, "top": -950, "bottom": 1780 },
  "platforms": [ { "x": 64, "y": 980, "w": 1792, "h": 128, "tier": "trampoline" } ],
  "objects":  [ { "type": "player_spawn", "x": 320, "y": 820 },
                { "type": "powerup_spawner", "x": 992, "y": 320 },
                { "type": "spikes", "x": 0, "y": 0, "w": 64, "h": 32 } ]
}
```

- `platforms[].tier` ∈ `marshmallow | bubblegum | trampoline | spring | bumper`. Tiers map to
  bounce heights via `Tuning.bounce_height_for()`; `bumper` gets `bumper` metadata (elastic
  ricochet) instead of a tier height. Unknown tier falls back to marshmallow.
- Colliders are built exactly as authored (x/y = top-left, w/h in px); ArenaRenderer paints art
  around them and is display-only.
- Object types handled today: `player_spawn`, `spikes`, `powerup_spawner` (spawn POINT only —
  pacing lives in PowerupSpawnDirector). Recognized-but-unported types are **push_warning + skip**
  so old levels still load: `physics_prop`, `bomb`, `container`, `physics_structure`,
  `gravity_source`, `moving_platform`, `crusher`, `fan` (LevelLoader.gd:53-56). Unknown types
  warn as unknown.
- `bounds` = the kill rectangle (ring-out when a player leaves it) and camera/renderer extent.
  Loader also returns `play_rect` (union of platforms) and `objects_raw` for mode-specific reads.
- Levels are data, never hardcoded (CLAUDE.md). The fuller palette/grid format from
  GAME_DESIGN §15 is future work; treat the current schema as the stable v0 API and bump
  `version` on breaking changes.

## Known-weak points (stated plainly, as of 2026-07-03)

1. **McpInteractionServer ships in the main autoload list** — a 4,421-line TCP server on
   127.0.0.1:9090 that accepts arbitrary `eval`, input injection, node manipulation
   (src/dev/mcp_interaction_server.gd). It is the studio's validation lifeline (gbplay.py speaks
   to it) and is dev-only by intent. **It must be stripped or gated out for any release build.**
   No release pipeline exists yet, so nothing enforces this today.
2. **Hitstop is a global `Engine.time_scale` write** (Juice.gd:229-246, `_hitstop`). It awaits
   real-time timers to restore 1.0 and has an `_exit_tree` guard, but anything else touching
   `time_scale` (or a crash mid-await) leaves the whole game in slow-mo — a known symptom (see
   skill `gottabounce-debugging-playbook`). PartyMatch's `rdelta` trick exists purely to
   compensate. The deferred Slow-Mo powerup will contend for the same global if built naively.
3. **INV-6 wrinkles — Tuning constants that lie:** `Tuning.hitstop_timescale` and
   `Tuning.hitstop_duration` exist but Juice._hitstop computes its own freeze depth/duration from
   impact strength and reads only `Tuning.hitstop_recover`; `Tuning.boost_rampup` is declared and
   read nowhere. Verify a constant is actually consumed before tuning it (grep its name).
4. **Bounce-clears-hitstun (`Player._on_bounced`) — VOLATILE.** At committed HEAD (0e315b9)
   `_on_bounced` unconditionally refunds fuel and clears hitstun on every bounce; the ruling
   (spec §2.3a, DECISIONS 2026-07-03) is that stunned contact must be a DRY REFLECT instead
   (gate `_on_bounced` on `_stun_timer <= 0.0`). Full incident → skill
   `gottabounce-failure-archaeology` (Incident 10). This state is VOLATILE — as of 2026-07-03 the
   fix was staged uncommitted; re-verify via `git log --oneline -1 -- src/entities/Player.gd` and
   STATUS.md before relying on either behavior. Never reopen the refund/clear gate as a "feel"
   fix — the sanctioned knob is bigger dry-reflect FX (spec §2.3a fallback).
5. **Deferred / unwired systems** — scaffolding exists, feature does not; don't mistake presence
   for shipped:
   - `Forces.apply_radial_impulse` + `EventBus.exploded`: complete seam, **zero callers/emitters**
     (no bombs yet). Juice subscribes to `exploded` and would work when something emits it.
   - `EventBus.powerup_used`: emitted, no subscriber.
   - Gravity sources: `GravityField.register/unregister` and the zone-resolution loop exist; no
     GravitySource entity exists and LevelLoader skips `gravity_source` objects.
   - Slow-Mo powerup: `Tuning.pu_slow_mo_*` + `Player.slow_factor` mechanics exist; `slow_mo` is
     NOT in `PowerupSystem.SHIPPED` — ungrantable.
   - Wings powerup: `Player.wings_flaps` + flap impulse exist; `wings` NOT in SHIPPED —
     ungrantable. (InputHuman maps `flap` to the same edge as `use_powerup`.)
6. **`_hit_area.get_overlapping_bodies()` polling in `_handle_smashes`** runs per player per
   physics tick (120/s) and applies at most one smash/shove per tick with 0.3s cooldowns
   (`_smash_cd`, `_shove_cd`). The shove-vs-overlap interaction has a live watch item
   (resting-overlap shove jitter, STATUS session-3 notes). UNVERIFIED: actual perf cost at >4
   players — only 4-player matches have been measured.
7. **Axis-snapped bounce normals** (`Player._axis_snap`): all level surfaces are assumed
   axis-aligned rectangles. Sloped or rotated colliders will bounce wrongly — the level schema
   doesn't allow them today, but nothing else enforces it.

## Provenance and maintenance

Verified 2026-07-03 against the repo at commit `0e315b9` (working tree had one uncommitted
Player.gd edit — the §2.3a dry-reflect fix, noted above) by reading: project.godot;
src/core/*.gd, src/systems/*.gd, src/entities/Player.gd, StormBall.gd, Hazard.gd, LaserWalls.gd;
src/modes/PartyMatch.gd; src/ui/MatchHUD.gd, SDWarning.gd; src/dev/mcp_interaction_server.gd
(header + protocol loop); levels/dev_arena.json; scenes/*.tscn listing + Arena.tscn;
docs/reference/ARCHITECTURE.md, docs/reference/MASTER_BUILD_PLAN.md §1; docs/DECISIONS.md,
docs/STATUS.md; plus grep sweeps for collision layers, EventBus/KillPipeline connect/emit sites,
`Forces.`, `boost_rampup`, `hitstop_*`, kill causes. All claims are static-read (`verified:
static`) — no game process was launched; runtime behaviors (hitstop feel, shove jitter, perf)
are as-documented in STATUS/specs, not re-measured here.

Drift-prone facts — re-verify with one-liners:
- Autoload list/order: `grep -A8 "\[autoload\]" project.godot`
- Invariant text: read `docs/reference/MASTER_BUILD_PLAN.md` lines 58–82
- Signal inventory: `grep -rn "signal " src/systems/EventBus.gd src/systems/KillPipeline.gd`
  and `grep -rn "EventBus\.\w*\.\(emit\|connect\)" src/`
- Collision layers: `grep -rn "collision_layer\|1 << " src/entities src/core | grep -v mcp`
- PartyMatch states: `grep -n '"BOOT"\|"ROUND_INTRO"\|"COUNTDOWN"\|"COMBAT"\|"SUDDEN_DEATH"\|"ROUND_END"\|"MATCH_END"' src/modes/PartyMatch.gd`
- Smash license predicate: read `src/entities/Player.gd` `_handle_smashes` (search "eligible")
- Bounce/hitstun state (weak point 4): `git log --oneline -3` + read `_on_bounced` in Player.gd
  and the latest entry in docs/STATUS.md
- Unwired scaffolding: `grep -rn "apply_radial_impulse\|exploded.emit\|boost_rampup" src/`
  (still-empty results = still unwired)
- Level object types: read `LevelLoader.gd` `match otype` block
- Shipped powerups: `grep -n "const SHIPPED" src/systems/PowerupSystem.gd`

UNVERIFIED items carried in this skill: per-tick overlap-polling perf beyond 4 players (weak
point 6). Everything else above was read directly from source.
