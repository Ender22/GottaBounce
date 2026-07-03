---
name: gottabounce-tuning-and-flags
description: The complete catalog of every constant in src/core/Tuning.gd (value, unit, meaning, status as of 2026-07-03), the cross-constant invariants that must never be violated, the DO-NOT-TOUCH list, the documented fallback-knob ladders, and the runbooks for changing or adding a tuning constant. Load this when you need to know what a Tuning value is, whether you may change it, what else it interacts with, how to live-tune it via gbplay eval, or where a new feel constant belongs. Do NOT load this for WHY the feel math works (see skill game-feel-reference), for the feel-tuning campaign sequencing (see skill gottabounce-feel-campaign), or for what gates/reviews a change needs (see skill gottabounce-change-control).
---

# GottaBounce — Tuning constants and flags catalog

**What this covers:** every variable in `src/core/Tuning.gd` with its live value (2026-07-03),
unit, meaning, and status; the relationship invariants between constants; the sanctioned
fallback knobs; how to read/live-tune/change/add a constant.
**When NOT to use this:** feel THEORY and derivations → skill `game-feel-reference`; the
phased feel campaign → skill `gottabounce-feel-campaign`; review gates and sign-off rules →
skill `gottabounce-change-control`; how to launch/drive the game → skill
`gottabounce-run-and-playtest`; how to measure effects → skill `gottabounce-diagnostics-and-tooling`.

## Ground rules

- **`src/core/Tuning.gd` is the live truth for every feel number.** It beats every doc: the doc
  authority order is Tuning.gd > docs/DECISIONS.md > newest spec > docs/STATUS.md > older specs >
  docs/reference/. In particular `docs/reference/FEEL_REFERENCE.md` has stale numbers (gravity
  2600 vs live 1600, boost 4200/650 vs live 4600/760, super_boost_impulse_full 1400 vs live 2800,
  super_boost_min_fuel 15 vs live 5) and still
  describes the dead charged-super model — never copy numbers from it. Tuning.gd's own header
  says "record back to FEEL_REFERENCE" — in practice that has NOT been kept up; treat the file
  itself as the record.
- Tuning is an **autoload Node** (`project.godot` `[autoload]`: `Tuning="*res://src/core/Tuning.gd"`),
  so any script reads `Tuning.gravity` directly. No `class_name`, no preload.
- All values below were read from `src/core/Tuning.gd` at commit 0e315b9, **2026-07-03**.
  Reference scale: character height H ≈ 110 px, design space 1920x1080, y-down, physics 120 ticks/s.

## Reading and live-tuning values (gbplay eval)

With the game running (launching it → skill `gottabounce-run-and-playtest`):

```
python tools/gbplay.py eval "return Tuning.smash_impact_min"
python tools/gbplay.py eval "Tuning.smash_impulse_from_attacker = 1.2; return Tuning.smash_impulse_from_attacker"
```

Facts about eval (verified: static, against `src/dev/mcp_interaction_server.gd` `_cmd_eval`):
- Your code is wrapped as a **function body** — you MUST `return` a value or you get null back.
- Multiple statements on one line separated by `;` are legal GDScript (verified: static).
- **Eval changes are RAM-only.** Restarting the game resets everything to the file values.
  Live-tune first, then persist the winner by editing `Tuning.gd` (runbook below).
- Typed-array trap: `bot_levels` is `Array[int]`. Assigning a plain literal
  (`Tuning.bot_levels = [3,3,4]`) can fail the typed-array check at runtime; use
  `Tuning.bot_levels.assign([3,3,4])` instead (verified: static — GDScript typed-array semantics).

## Status legend

| Status | Meaning |
|---|---|
| PROD | Wired into gameplay code, live |
| DNT | DO-NOT-TOUCH — changing it requires reopening a closed decision (see list below) |
| UNWIRED | Declared in Tuning.gd but **no consumer in src/** — editing it does nothing today |
| DEFERRED | Reserved for an unshipped feature by spec; do not delete, do not expect effect |

## The catalog (all values as of 2026-07-03)

### Gravity and bounce (FEEL §2)

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `gravity` | 1600.0 | px/s² | World gravity (lowered from 2200 — floatier) | PROD |
| `bounce_height_marshmallow` | 120.0 | px | Tier launch height ≈1.1 H; also the fallback for unknown tiers in `bounce_height_for()`; no marshmallow tile in dev_arena today | PROD |
| `bounce_height_bubblegum` | 180.0 | px | ≈1.6 H (dev_arena uses it) | PROD |
| `bounce_height_trampoline` | 270.0 | px | ≈2.5 H — the "basic" floor bounce | PROD |
| `bounce_height_spring` | 480.0 | px | ≈4.4 H — the big one | PROD |
| `min_bounce_height` | 48.0 | px | Never settle (INV-11) — floor of every bounce | PROD |
| `bounce_di` | 260.0 | px/s | DI (directional influence): holding a direction during a bounce nudges the launch that way, at full stick tilt | PROD |
| `tangential_retention` | 0.98 | fraction | Momentum kept across a bounce | PROD |
| `bumper_restitution` | 0.86 | fraction | Wall rebound; <1 so boost+wall can't pump speed forever | PROD |
| `max_speed` | 3000.0 | px/s | Global hard speed cap (anti-runaway/anti-tunnel); sized above the 2800 super | DNT |

Tier heights are consumed via the helper `Tuning.bounce_height_for(tier)` (called from
`src/core/LevelLoader.gd:88`), not by name — a name-grep for the tier constants outside
Tuning.gd finds nothing, and that is expected.

### Air drift and boost (FEEL §2.3/§3.2)

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `air_drift_accel` | 1300.0 | px/s² | In-air steering acceleration | PROD |
| `air_drift_max_speed` | 340.0 | px/s | In-air steering top speed | PROD |
| `normal_boost_accel` | 4600.0 | px/s² | Jetpack thrust response | PROD |
| `normal_boost_max_speed` | 760.0 | px/s | Thrust top speed — deliberately BELOW `smash_impact_min` (see invariants) | PROD |
| `boost_rampup` | 0.06 | s | Declared but **no consumer anywhere in src/** | UNWIRED |
| `boost_enter_keep` | 0.25 | fraction | Starting a boost cuts momentum to this — a boost tap reclaims trajectory control | PROD |

### Fuel (FEEL §3.1)

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `fuel_max` | 100.0 | fuel | Tank size | PROD |
| `tank_seconds` | 3.5 | s | Full tank duration; consumed only via `normal_boost_drain()` = fuel_max/tank_seconds ≈ 28.6 fuel/s (`Player.gd:386`) | PROD |
| `fuel_per_bounce` | 20.0 | fuel | Refund per tier bounce — the chain-rhythm engine. NOTE: the actual refund is scaled by `sqrt(tier_h / bounce_height_trampoline)` at Player.gd:493, so 20 is the trampoline value only (marshmallow ~13.3, bubblegum ~16.3, spring ~26.7); the flat 20 applies to bumpers (Player.gd:502) | DNT |
| `fuel_per_bumper` | 20.0 | fuel | Refund per bumper hit (**neutral, non-stunned contact only** per spec §2.3a v2.1) — enables the owner's wall-return shot | DNT |

**Stale in-file comment (2026-07-03):** `Tuning.gd:38` still says fuel_per_bumper is "FLAGGED FOR
DESIGNER REVIEW". That review HAPPENED: the designer ruled 2026-07-03 (DECISIONS.md entry;
`docs/specs/v0_combat_lethality.md` §2.3a) — **keep 20.0, do not raise or lower**; the bug was the
stun-clear/refund GATE in code (dry reflect while stunned), not the value. Spec §8 v2.1 lists
`fuel_per_bumper (value)` as do-not-touch. Full incident + the pending code fix →
skill `gottabounce-failure-archaeology` (Incident 10); that gate state is VOLATILE (as of
2026-07-03 the fix was staged uncommitted — re-verify via
`git log --oneline -1 -- src/entities/Player.gd`), but the **value stays 20.0** regardless.

### Super boost v2 — UN-CHARGED (lethality spec §1)

Power NEVER scales with fuel or hold time. That decision is closed (DECISIONS.md 2026-07-02,
reopen only with movement-course evidence). Never re-introduce `super_charge_*` constants.

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `super_boost_impulse_full` | 2800.0 | px/s | Constant launch impulse — 5 fuel fires as hard as 100 | DNT |
| `super_boost_min_fuel` | 5.0 | fuel | Min fuel to enter AIM ("even 5%") | PROD |
| `super_aim_max` | 2.0 | s | Aim-hover hard cap, then auto-fire (never a camp — Pillar 2) | PROD |
| `super_aim_gravity` | 0.25 | multiplier | Gravity scale while aiming — sag, don't plummet | PROD |
| `super_aim_damp` | 2.5 | 1/s | Proportional velocity decay while aiming | PROD |
| `super_aim_velocity_keep` | 1.0 | fraction | Velocity kept on aim ENTRY — 1.0 = aim is NOT a free air-brake (lethality guard, spec §1.3) | PROD |
| `super_active_time` | 0.45 | s | Smash-license window after firing (replaced hardcoded `_super_recent = 0.6`) | PROD |
| `super_refire_lockout` | 0.25 | s | Min gap before the next aim (buffer-spam guard) | PROD |
| `pu_unlimited_super_lockout` | 1.0 | s | Refire lockout while fuel_locked (Unlimited Boost) — ~6 supers per pickup, not 20 | PROD |

### Aim-ring readability (lethality §1.4; QA fix 587d0a1)

Screen-space so the fuse reads at any camera zoom (a 7 px world line was ≈3 px on screen at
zoom 0.443 — invisible).

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `super_ring_screen_width` | 9.0 | screen px | Fuse-ring line width, zoom-independent | PROD |
| `super_ring_outline_extra` | 6.0 | screen px | Dark backing ring extra width (contrast on any background) | PROD |
| `super_ring_min_arc` | 0.15 | fraction | Minimum visible fuse arc from frame 1 | PROD |

### Boost-bounce supercharge (FEEL §3.4)

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `supercharge_window` | 0.20 | s | Boost-held-through-bounce timing window | PROD |
| `supercharge_thrust_mult` | 1.6 | multiplier | Thrust bonus inside the window | PROD |
| `supercharge_bounce_mult` | 1.4 | multiplier | Bounce-height bonus inside the window | PROD |

### Two-tier contact: SHOVE vs SMASH (lethality spec §2)

A contact SMASHES only if the attacker is super-active OR a stunned flying body (minus its own
stunner — `_stunned_by` pairwise immunity), AND closing speed ≥ `smash_impact_min`, AND the
attacker is the faster body (`src/entities/Player.gd:616-618`). Everything else is a SHOVE.

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `smash_impact_min` | 900.0 | px/s | Min relative closing speed for an ELIGIBLE hit to smash (was Player.gd const `IMPACT_MIN=800` — moved into Tuning per INV-6) | PROD |
| `smash_impulse_base` | 500.0 | px/s | Flat knockback term | PROD |
| `smash_impulse_from_attacker` | 1.35 | multiplier | Speed-scaled knockback term. **First fallback knob DOWN (→1.2) if rounds get too short (<8 s median)** | PROD |
| `smash_self_retain` | 0.1 | fraction | Attacker keeps only this much momentum on a landed smash — you stop, they fly | DNT |
| `smash_sting_fuel` | 30.0 | fuel | Qualifying smashes chunk the victim's tank (sting → starve → kill loop) | PROD |
| `smash_sting_min_impulse` | 1500.0 | px/s | Sting threshold — supers/chains sting; Star (900) and Counter (1400) sit below by design | PROD |
| `hitstun_base` | 0.15 | s | Hitstun floor. **Protected recovery triad (GDD §4.6)** | DNT |
| `hitstun_per_impulse` | 0.00025 | s per px/s | Hitstun scaling | DNT |
| `hitstun_max` | 0.55 | s | Hitstun ceiling | DNT |

### The SHOVE (lethality spec §2.3)

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `soft_bump_scale` | 0.5 | multiplier | push = clamp(rel_speed x scale, min, max), mutual (replaced hardcoded 300.0) | PROD |
| `soft_bump_min` | 250.0 | px/s | Shove floor | PROD |
| `soft_bump_max` | 700.0 | px/s | Shove ceiling. Second fallback knob UP if kills too rare | PROD |
| `shove_credit_min_rel` | 500.0 | px/s | Shove at rel ≥ this sets `last_attacker` (body-check over the line credits the checker, not a suicide) | PROD |

### Explosions (FEEL §4.1) — no emitter exists yet

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `explosion_radius` | 280.0 | px | Blast radius | UNWIRED |
| `explosion_impulse_center` | 1600.0 | px/s | Center impulse, linear falloff | UNWIRED |
| `chain_detonate_delay` | 0.08 | s | Chain-reaction stagger | UNWIRED |

`EventBus.exploded` and `src/core/Forces.gd` exist and Juice subscribes, but nothing in src/
emits the signal or reads these three constants as of 2026-07-03 (bombs not yet built).

### Impact juice (FEEL §5)

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `hitstop_timescale` | 0.05 | multiplier | Intended freeze depth — **bypassed**: `Juice.gd:234` hardcodes `lerpf(0.12, 0.04, strength)` instead | UNWIRED |
| `hitstop_duration` | 0.07 | s | Intended freeze length — **bypassed**: `Juice.gd:235` hardcodes `lerpf(0.03, 0.10, strength)` | UNWIRED |
| `hitstop_recover` | 0.12 | s | Ease-back-to-full-speed time (`Juice.gd:243`) | PROD |
| `shake_max_offset` | 22.0 | px | Camera shake cap (trauma model) | PROD |
| `trauma_decay` | 1.4 | 1/s | Shake trauma decay | PROD |

The two bypassed hitstop constants are an INV-6 (all-feel-constants-in-Tuning) violation inside
`src/systems/Juice.gd:229-245`. Flag it, don't silently fix — wiring them changes felt hitstop
strength and needs a rendered playtest (routing → skill `gottabounce-change-control`).

### Input (FEEL §6)

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `stick_deadzone` | 0.22 | fraction | Declared but **not consumed** — the real deadzone is 0.2 per action in `project.godot` (`InputHuman.gd` uses `get_vector`'s built-in deadzone) | UNWIRED |
| `input_buffer` | 0.10 | s | Buffered-input window (e.g. super press held through hitstun/lockout re-arms every frame — behavior reviewed and KEPT as-built, spec §2.3a) | PROD |

### v0 round loop (docs/specs/v0_round_loop.md §6)

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `intro_pop_stagger` | 0.35 | s | ROUND_INTRO spawn pop-in stagger | PROD |
| `countdown_beat` | 0.35 | s | Per 3/2/1 countdown beat | PROD |
| `round_end_freeze` | 1.8 | s | KO freeze-frame + pip animation — **hard cap 2.0** (turnaround budget) | PROD |
| `sudden_death_time` | 20.0 | s | Combat time before laser walls. Lowering it RAISES the laser-decided share | DNT |
| `laser_close_time` | 6.0 | s | Lasers fully meet at center (max combat clock = 26 s) | PROD |
| `laser_revive_start_frac` | 0.4 | fraction | Double-KO revive: lasers spawn already this far closed | PROD |
| `sd_warning_lead` | 3.0 | s | Pulsing edge-column warning before SD | PROD |
| `idle_hunt_after` | 4.0 | s | No input this long → nearest bot hunts the idler | PROD |
| `survival_requires_contact` | true | bool | Survival point needs ≥1 smash dealt/received (idle-farm backstop) | PROD |
| `double_ko_window` | 0.25 | s | Simultaneous-death tiebreak window | PROD |
| `kill_credit_window` | 2.5 | s | Last-attacker kill credit (replaced Player.gd's hardcoded 2.0) | PROD |
| `match_target_score` | 10 | points | First to this with a strict lead wins | PROD |
| `bot_levels` | [2, 3, 4] | Array[int] | P2 punchline / P3 fair fight / P4 menace; P1 is the human seat. L1–L5 dial table lives in `src/core/BotProfile.gd` (`for_level()`); dial THEORY → skill `game-feel-reference` | PROD |

### Powerups (docs/specs/v1_powerups.md §6)

Spawner pacing: `pu_first_spawn` 4.0 s · `pu_spawn_interval` 7.0 s · `pu_spawn_telegraph` 1.0 s ·
`pu_max_on_field` 2 (all PROD).

| Constant | Value | Unit | Meaning | Status |
|---|---|---|---|---|
| `pu_unlimited_boost_dur` | 8.0 | s | Unlimited Boost duration (10→8 for short rounds) | PROD |
| `pu_mega_bounce_dur` | 8.0 | s | Mega Bounce duration | PROD |
| `pu_star_dur` | 5.0 | s | Star duration (6→5) | PROD |
| `pu_counter_dur` | 2.0 | s | Counter Shield duration | PROD |
| `pu_black_hole_dur` | 2.0 | s | Black Hole channel | PROD |
| `pu_ring_lifetime` | 8.0 | s | Ring of Fire lifetime | PROD |
| `pu_mega_bounce_mult` | 2.0 | multiplier | Bounce-height multiplier | PROD |
| `pu_star_contact_impulse` | 900.0 | px/s | Star contact launch (below sting line 1500 by design) | PROD |
| `pu_counter_reflect_impulse` | 1400.0 | px/s | Counter parry (half a super; below sting line by design) | PROD |
| `pu_ball_count` | 16 | count | Storm ball count | PROD |
| `pu_ball_hit_impulse` | 500.0 | px/s | Storm ball hit, along ball velocity | PROD |
| `pu_ball_lifetime` | 6.0 | s | Storm ball lifetime | PROD |
| `pu_ball_owner_grace` | 0.5 | s | Owner immune to own balls | PROD |
| `pu_black_hole_radius` | 700.0 | px | Pull zone | PROD |
| `pu_black_hole_pull` | 2600.0 | px/s² | Constant in-zone pull — **must stay < `normal_boost_accel`** (escapable) | PROD |
| `pu_ring_max_triggers` | 3 | count | Ring of Fire trigger cap | PROD |
| `pu_ring_retrigger_cd` | 1.5 | s | Ring retrigger cooldown | PROD |
| `pu_ring_owner_grace` | 1.0 | s | Ring owner grace | PROD |
| `pu_slow_mo_dur` | 3.0 | s | Slow-mo powerup waits (spec §1 defers it) | DEFERRED |
| `pu_slow_mo_factor` | 0.5 | multiplier | Slow-mo factor | DEFERRED |
| `bot_powerup_delay` | 1.5 | s | Bot sits on a pickup this long (+ level-scaled variance) before using (`InputBot.gd:316`) | PROD |

### Derived helpers (functions, not vars)

- `Tuning.normal_boost_drain()` → `fuel_max / tank_seconds` ≈ 28.6 fuel/s.
- `Tuning.bounce_height_for(tier: StringName)` → tier height; unknown tier falls back to marshmallow.

## Cross-constant invariants (violating these caused or causes real bugs)

| # | Invariant | Live check (2026-07-03) | Why / incident |
|---|---|---|---|
| 1 | Plain boost must NOT reach the smash gate: `normal_boost_max_speed < smash_impact_min`; smash reachable ONLY via super (2800) or stunned-body launch | 760 < 900 OK | THE founding bug inverted this intent: old `IMPACT_MIN` 800 > boost 760 made kills mathematically unreachable ("nothing was lethal"). Today the eligibility rule (super_active/stunned) is the primary gate; the speed gate is anti-graze |
| 2 | `fuel_per_bounce >= 2 x super_boost_min_fuel` | 20 ≥ 10 OK | One bounce must always re-arm a super — surfaces are the combo system (spec §1.2) |
| 3 | `fuel_per_bumper >= super_boost_min_fuel` and (current design) = `fuel_per_bounce` | 20 = 20 OK | Wall-return shot (spec §2.3a); value ruled frozen 2026-07-03 |
| 4 | `pu_black_hole_pull < normal_boost_accel` | 2600 < 4600 OK | Black Hole must be escapable by boosting |
| 5 | `round_end_freeze <= 2.0` | 1.8 OK | Turnaround budget: last death → next BOUNCE ≤ 4.5 s (round_loop spec; measured 4.28–4.29 s) |
| 6 | `smash_sting_min_impulse` above `pu_star_contact_impulse` and `pu_counter_reflect_impulse` | 1500 > 900, 1400 OK | Powerups launch, they don't starve (spec §2.2) |
| 7 | `super_boost_min_fuel < fuel_max/3 - smash_sting_fuel` shape: a mid-tank victim (34) minus one sting (30) lands BELOW the min (5) | 34-30=4 < 5 OK | The authored sting → starve → kill 2-hit loop depends on this ordering |
| 8 | `max_speed > super_boost_impulse_full` | 3000 > 2800 OK | The cap must not neuter the kill move |
| 9 | `bumper_restitution < 1.0` | 0.86 OK | Boost+wall must not pump speed forever |
| 10 | `sudden_death_time + laser_close_time` = max combat clock | 20+6 = 26 s | Every round decided ≤26 s combat / ≤30 s wall-clock (spec §9.12) |
| 11 | Test 6d timing: `super_refire_lockout + input_buffer <= 0.35` | 0.25+0.10 = 0.35 OK | Wall-return second aim must start within this of the bumper frame |

If you change ANY constant on the left side of an invariant, re-check the whole row and run a
reachability audit (method → skill `gottabounce-analysis-toolkit`).

## DO-NOT-TOUCH list (as of 2026-07-03 — spec §8 v2.1 + DECISIONS.md)

Touching any of these means reopening a closed decision through change control
(→ skill `gottabounce-change-control`), never a quiet edit:

- `hitstun_base` / `hitstun_per_impulse` / `hitstun_max` — the GDD §4.6 protected recovery triad.
  Ring-outs come from momentum, never from being frozen to death. "Never hitstun up" is written
  into the fallback rules.
- `sudden_death_time` — lowering it raises the laser-decided share (the exact failure lethality v2 fixed).
- `super_boost_impulse_full`, `max_speed`, `smash_self_retain` — reaffirmed unchanged in spec §2.1/§8.
- `fuel_per_bounce` (keep ≥ 2x `super_boost_min_fuel`), `fuel_per_bumper` (value frozen by the
  2026-07-03 designer ruling).
- **Never re-introduce super power scaling** (with fuel OR hold time) — decision closed
  (DECISIONS.md 2026-07-02); reopen only with movement-course evidence.
- The buffered-super-through-empty-tank behavior — reviewed and kept as-built (spec §2.3a).

## Sanctioned fallback-knob ladders (lethality spec, "Out of scope / fallback knobs")

Use these IN ORDER; do not invent alternative knobs for these symptoms:

| Symptom | Knob 1 | Knob 2 | Forbidden |
|---|---|---|---|
| Rounds too short (<8 s median) or feel random | `smash_impulse_from_attacker` 1.35 → 1.2 | `super_refire_lockout` 0.25 → 0.5 | hitstun changes |
| Everyone always recovers (kills too rare) | `smash_sting_fuel` 30 → 40 | `soft_bump_max` up | hitstun up; power scaling |
| Dry reflect feels silent (stunned bumper hit "does nothing") | Bigger squash/flash FX | Distinct SFX cue | Reopening the refund/stun-clear gate (closed, DECISIONS 2026-07-03) |

## Runbook: change an existing constant

1. **Classify.** Is it on the DO-NOT-TOUCH list or an invariant's left side? If yes → change
   control first (skill `gottabounce-change-control`). Feel-relevant tweak → designer sign-off
   will be needed before commit.
2. **Live-tune** in a running game (RAM-only, safe):
   `python tools/gbplay.py eval "Tuning.<name> = <value>; return Tuning.<name>"`
3. **Measure, don't eyeball** — round_stats / perf / burst screenshots
   (→ skill `gottabounce-diagnostics-and-tooling`).
4. **Persist**: edit `src/core/Tuning.gd` — value AND its comment (the comment is documentation
   of record; stale comments have already bitten us, see fuel_per_bumper above). Update the spec
   tuning block if the constant is spec-owned.
5. **Parse gate** (no-crash check only, never a sign-off):
   `"C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --editor --quit`
   then grep output for `Parse Error|hides a native|Failed to load script|not declared`.
   (Run via the Bash tool with `dangerouslyDisableSandbox: true` — see skill
   `gottabounce-build-and-env` for the Windows traps.)
6. **Rendered playtest** of the affected behavior + screenshots
   (→ skill `gottabounce-run-and-playtest`); re-run any spec criteria the constant participates
   in (→ skill `gottabounce-validation-and-qa`).
7. **Commit + STATUS.md update** (→ skill `gottabounce-change-control`).

## Runbook: add a new constant

1. **Never hardcode a feel number in an entity/system** (INV-6). Four historical hardcodes had
   to be migrated later — don't add a fifth: `kill_credit_window` (was 2.0 in Player.gd),
   `super_active_time` (was `_super_recent = 0.6`), `smash_impact_min` (was Player.gd const
   `IMPACT_MIN = 800`), `soft_bump_scale` (was 300.0 in `_soft_separate`).
2. Check nothing existing covers it (this catalog; grep Tuning.gd).
3. Place it in the matching `# --- Group (spec ref) ---` block; new system → new block with a
   spec reference in the header.
4. Declare with an explicit type and a comment: unit + meaning + spec §. Example pattern from
   the file: `var super_refire_lockout: float = 0.25   # min gap before another aim can start`.
5. Consume it as `Tuning.<name>` (autoload — no import needed). **Wire it in the same commit**:
   declared-but-unwired constants rot (see boost_rampup, stick_deadzone, hitstop_timescale
   above). If genuinely deferred, say so in the comment like the `pu_slow_mo_*` block does.
6. Add it to the owning spec's tuning block; note the addition in docs/STATUS.md after commit.
7. If it creates a relationship with another constant, write the inequality into BOTH comments
   (the `super_boost_min_fuel` / `fuel_per_bounce` pair is the model) and add it to the
   invariants table in this skill.

## Known wiring gaps and comment drift (as of 2026-07-03)

- `boost_rampup`, `stick_deadzone`, `explosion_radius`, `explosion_impulse_center`,
  `chain_detonate_delay`, `hitstop_timescale`, `hitstop_duration`: declared, zero effect
  (see per-group notes). Editing them and expecting a change is a known time sink.
- Real input deadzone = 0.2 per action in `project.godot`, not `stick_deadzone` 0.22.
- `Tuning.gd:38` fuel_per_bumper "FLAGGED FOR DESIGNER REVIEW" comment is stale — ruled
  2026-07-03, keep 20.0.
- Hitstop depth/length hardcoded in `src/systems/Juice.gd:234-235` (INV-6 wrinkle).
- Fixing any of the above edits repo files → normal session through change control; this skill
  documents, it does not authorize.

## Provenance and maintenance

Authored 2026-07-03 against commit 0e315b9 (`master`). At authoring time the working tree had
uncommitted `src/entities/Player.gd` changes (the in-progress spec-§2.3a dry-reflect fix); no
Tuning.gd changes were pending. All values above were read line-by-line from
`src/core/Tuning.gd`; wiring status was established by grepping every constant name across
`src/` and inspecting consumers (`Player.gd`, `Juice.gd`, `LevelLoader.gd`, `BounceResolver.gd`,
`InputBot.gd`, `PartyMatch.gd`, `PowerupSystem.gd`, `project.godot`). Statuses were reconciled
against `docs/specs/v0_combat_lethality.md` v2.1 §8, `docs/specs/v0_round_loop.md` §6,
`docs/DECISIONS.md`, and `docs/STATUS.md`. No game process was launched: all gbplay/eval
commands are `verified: static` (against `tools/gbplay.py` and
`src/dev/mcp_interaction_server.gd:541-577`), as are the GDScript semicolon-separator and
typed-array `assign()` claims.

Re-verification one-liners (run on drift suspicion):

- Whole catalog: `git log --oneline -3 -- src/core/Tuning.gd` then re-read the file if it moved.
- Any single value (game running): `python tools/gbplay.py eval "return Tuning.smash_impact_min"`
- Unwired check for a constant: `grep -rn "boost_rampup" src --include="*.gd"` (only Tuning.gd → still unwired).
- Hitstop bypass still present: `grep -n "lerpf(0.12" src/systems/Juice.gd`
- fuel_per_bumper stale comment: `grep -n "FLAGGED" src/core/Tuning.gd`
- DO-NOT-TOUCH list source: `grep -n "DO-NOT-TOUCH" docs/specs/v0_combat_lethality.md`
- Bot dial table: `git log --oneline -1 -- src/core/BotProfile.gd` (values in `for_level()`).

UNVERIFIED / static-only items: the exact eval one-liners and the semicolon/typed-array GDScript
behaviors were never executed live in this authoring session (port 9090 off-limits); the
`bounce_height_marshmallow` "no marshmallow tile in dev_arena" claim reflects
`levels/dev_arena.json` at 0e315b9 only.
