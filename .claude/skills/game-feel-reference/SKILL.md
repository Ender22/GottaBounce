---
name: game-feel-reference
description: >-
  Game-feel THEORY as applied to GottaBounce, for someone who has never tuned game feel: bounce
  math (launch_speed = sqrt(2*g*h), the tier ladder, DI, min-bounce, bumper restitution), the fuel
  economy and drain-all super, the two-tier SHOVE/SMASH contact model and why the hitstun triad is
  protected, juice theory (Rule of Three, trauma-squared shake, hitstop, squash & stretch) with
  this repo's live constants, the readability doctrine (why silhouette/contrast/value matter for
  feel), the TowerFall bar, and bot-as-human-sim
  theory with the L1-L5 dial table. Load when you need to UNDERSTAND why a feel constant has the
  value it has, derive hang time / launch speed / decay math, reason about knockback-hitstun-recovery
  interactions, or judge whether a proposed change violates feel doctrine. Do NOT load for the full
  constant catalog or how to change a constant (see skill gottabounce-tuning-and-flags) or for the
  step-by-step feel-tuning campaign (see skill gottabounce-feel-campaign).
---

# Game-feel reference — the theory pack, as applied in this repo

**What this covers:** the domain knowledge behind GottaBounce's feel — bounce physics, fuel
economy, contact/hitstun/knockback theory, juice, readability, and bot-believability — each tied
to the actual live constants and code as of 2026-07-03.

**When NOT to use this:**
- Full catalog of every `Tuning.gd` var, statuses, guards, or the change-a-constant runbook → skill `gottabounce-tuning-and-flags`.
- Executing the feel-tuning campaign (phases, gates, commands) → skill `gottabounce-feel-campaign`.
- Autoloads, seams, INV invariants → skill `gottabounce-architecture-contract`.
- Analysis recipes (reachability audits, frame-order reasoning) → skill `gottabounce-analysis-toolkit`.
- Incident narratives behind the rules cited here → skill `gottabounce-failure-archaeology`.

---

## 1. Vocabulary (define once, use everywhere)

| Term | Meaning here |
|---|---|
| **Game feel** | The moment-to-moment sensation of controlling a character: responsiveness, weight, momentum, feedback. Tuned with numbers, judged by play. |
| **DI (directional influence)** | Holding a stick direction during a bounce nudges the launch that way. Gives the player authorship over "automatic" physics. |
| **Hitstun** | A timed window after being smashed during which the victim has no input. Ends by TIME only (ruled 2026-07-03, see §5.4). |
| **Hitstop** | A global sub-100ms slow-motion freeze on impact that sells weight. Implemented via `Engine.time_scale`. |
| **Knockback / impulse** | Instant velocity added to a smash victim, in px/s. |
| **Sting** | Fuel chunked off a smash victim's tank (in addition to knockback). |
| **Restitution** | Fraction of speed kept when ricocheting off a surface. `< 1` loses energy. |
| **Tangential component** | The part of velocity parallel to a surface (vs the "normal" part, into/away from it). |
| **Smash license** | The eligibility rule deciding whether a body contact may SMASH at all (see §5.1). |
| **Ring-out / kill line** | Death by crossing the blast-zone bounds outside the arena. The game's only damage model. |
| **Juice** | Non-simulation feedback layered on events: shake, particles, squash, flash, rumble, hitstop. |
| **H** | Reference character height ≈ 110 px (design space 1920×1080). All px values scale with H. |

Engine context: Godot 4.7, physics at 120 ticks/s (`project.godot`), y-down (up velocities are
negative), hand-authored velocities on `CharacterBody2D` — NOT RigidBody restitution — so every
number below is an exact design decision, not an emergent physics artifact.

## 2. The bar: movement feel IS the product

Owner directive (`docs/feedback/owner_2026-07-02_movement_feel.md`, highest-authority design
input): *"This game will be fun or not depending on whether the feel of the movement and combat is
enjoyable."* Reference point: **TowerFall Ascension** — movement so polished it makes you feel
capable and cool. Operationally this means:

1. Every combat/feel spec must be reconciled against that document (its own standing instruction).
2. Feel changes are validated on **movement challenge courses** (specced in
   `docs/specs/v1_movement_courses.md`, **not built** as of 2026-07-03) plus rendered party-match
   playtests — never "looks fine in a screenshot".
3. The un-charged super (§6) exists BECAUSE of this doctrine: the charge model double-taxed the
   kill move; the owner hypothesis was adopted 2026-07-02 (`docs/DECISIONS.md`) and reopens only
   with movement-course evidence.
4. The goat identity (horns/scream) is **adopt-STAGED, gated** until courses validate that the
   super fantasy is actually fun (DECISIONS 2026-07-03). Do not oversell it as shipped.

## 3. Bounce math — the passive base layer

Source of truth: `src/core/BounceResolver.gd` (pure static function) + `src/core/Tuning.gd`.
All live values below date-stamped 2026-07-03.

**The core formula.** To launch a body to a target apex height `h` under gravity `g`:

```
launch_speed = sqrt(2 * g * h)        # px/s, along the surface normal
time_to_apex = launch_speed / g       # s
hang_time    = 2 * time_to_apex       # s (up + down, flat surface)
```

`BounceResolver.resolve()` splits incoming velocity into normal + tangential parts, REPLACES the
normal part with `launch_speed` along the outward normal (so arriving fast never inflates the
tier — tiers stay readable), and keeps the tangential part × `tangential_retention` (0.98). It
takes `gravity_mag` as a parameter so it is gravity-field correct (INV-1/INV-2 — see skill
`gottabounce-architecture-contract`).

**The tier ladder** (live `gravity = 1600` px/s², char height H ≈ 110 px). Launch speeds and
times below are derived from the formula — recompute if `gravity` or any height changes:

| Tier | Height (live) | ~H | Launch speed | Time to apex | Feel role |
|---|---|---|---|---|---|
| marshmallow | 120 px | 1.1 | ≈ 620 px/s | 0.39 s | low quick rhythm |
| bubblegum | 180 px | 1.6 | ≈ 759 px/s | 0.47 s | mid |
| trampoline | 270 px | 2.5 | ≈ 930 px/s | 0.58 s | the "basic" floor bounce |
| spring | 480 px | 4.4 | ≈ 1239 px/s | 0.77 s | the big one |
| min-bounce floor | 48 px | 0.44 | ≈ 392 px/s | 0.24 s | see below |

Note the near-coincidence: a passive trampoline crossing (~930 px/s) sits just ABOVE the smash
speed gate (`smash_impact_min` 900). Passive bounces still never smash — the eligibility
**license** (§5.1), not the speed gate, is what protects neutral play. Keep that in mind before
lowering `smash_impact_min` or raising tier heights.

**Min-bounce (never settle, INV-11).** `min_bounce_height = 48` is a floor on the target HEIGHT
inside `resolve()` — even from near-rest a body kicks back up at ≈392 px/s. This enforces the
"no standable ground" identity: Bouncers never stop bouncing, so there is no camping posture and
fuel income (§4) always requires motion.

**Tangential retention (0.98).** You keep your horizontal run/drift momentum across a bounce
(Duck-Game-y, not pogo-stick). Slightly < 1 so pure horizontal speed doesn't persist forever.

**DI (`bounce_di = 260`).** On a tier bounce, `Player.gd:489` adds
`tangent * aim_in.dot(tangent) * 260` — full stick along the surface adds up to 260 px/s of
tangential launch. This is the player's steering authorship over every bounce; it is why "just
bouncing around" can be piloted.

**Bumper restitution (`bumper_restitution = 0.86`, why < 1).** Bumper walls use
`resolve_bumper()`: pure reflection × 0.86. If it were ≥ 1, boost-into-wall would pump speed
every ricochet without limit (boost adds energy, wall returns all of it). 0.86 makes wall play
lossy, and the global `max_speed = 3000` cap is the hard backstop (also the reason a clean super
launch "exits at cap" — see §5.2).

**Supercharge (boost-bounce, the flow tech).** If normal boost is held through a surface contact,
a `supercharge_window = 0.20` s opens: thrust × `supercharge_thrust_mult` 1.6 and the bounce
launch × `supercharge_bounce_mult` 1.4 (passed as the `supercharged` arg into
`BounceResolver.resolve`). Both "tap boost as you leave" and "boost into the surface" open it —
one rule, two techniques. This is the Sonic-spring chain-flow mechanic.

**Stale-source warning:** `docs/reference/FEEL_REFERENCE.md` still lists gravity 2600 and tier
heights 160/320/640/1280 — those are the OLD starting values. Live truth is always
`src/core/Tuning.gd`. Full drift list in §10.

## 4. Fuel economy — surfaces are the combo system

Live constants (2026-07-03): `fuel_max = 100`, `tank_seconds = 3.5`, `fuel_per_bounce = 20`,
`fuel_per_bumper = 20`, `super_boost_min_fuel = 5`.

**The arithmetic.** Normal boost drains `fuel_max / tank_seconds` ≈ **28.6 units/s**
(`Tuning.normal_boost_drain()`), so a full tank is 3.5 s of thrust and a trampoline-tier bounce
(+20) buys 0.7 s of thrust. NOTE: `fuel_per_bounce` is only flat 20 for the trampoline tier — the
tier refund is scaled by `sqrt(tier_h / bounce_height_trampoline)` at Player.gd:493 (marshmallow
~13.3, bubblegum ~16.3, spring ~26.7); the flat 20 is exact only for bumpers (Player.gd:502).
Fuel refills ONLY on surface contact — never airborne, never while stunned.
That single rule is the economy's heart: it converts the bounce (the passive layer) into the
income source for the jetpack (the active layer), forcing constant returns to surfaces.

**Drain-all super + refuel rhythm.** The super always dumps the WHOLE tank and fires at constant
power (§6). A flat cost instead would allow several airborne supers back-to-back and reward
hoarding; drain-all forces every super chain **through a bounce** — the loop is
super → miss → bounce (+20 fuel, ≥ the 5-unit minimum) → super again. This is the owner's
"wall-return shot" and the reason the tier ladder doubles as a combo system.

**The invariant (keep it when tuning either number):**
`fuel_per_bounce >= 2 * super_boost_min_fuel` (20 ≥ 10, stated in `Tuning.gd:51`). One bounce
must always re-arm a super with margin, or the chain rhythm dies.

**Sting-starve — the authored 2-hit kill.** A qualifying smash chunks the victim's tank by
`smash_sting_fuel = 30` (only when impulse ≥ `smash_sting_min_impulse = 1500` — all supers and
chain hits sting; Star contact 900 and Counter reflect 1400 deliberately don't). A mid-tank
victim at 34 fuel drops to 4 < 5 minimum → NO escape super exists. Sting → starve → kill attacks
the fuel leg of the recovery triad (§5.3) instead of the hitstun leg. Banking fuel still pays,
but for *defense* (a full-tank victim survives one smash with a full-power counter in hand).

**The dry-reflect rule (ruled 2026-07-03 — spec §2.3a, DECISIONS entry same date).** Surface
contact while in opponent-inflicted hitstun (`_stun_timer > 0`) refunds ZERO fuel and does NOT
clear hitstun — the body still visibly caroms (BounceResolver runs upstream, unconditionally),
but the touch doesn't save you. Rationale: bumpers sit ~660 px inboard of the kill line, so an
unconditional refund+stun-clear (introduced by fix 587d0a1) auto-saved every edge-bound victim
and made off-stage kills structurally un-earnable. Governing principle: **hitstun ends by TIME,
never by touching a surface.** Neutral (non-stunned) contact is unchanged — the wall-return shot
never involves hitstun by construction. `fuel_per_bumper` stays 20.0 by that same ruling (the
`Tuning.gd:38` comment still says "FLAGGED FOR DESIGNER REVIEW" — the review has since happened;
the flag is stale). Status caveat as of 2026-07-03: the ruling is committed (spec v2.1, ea0c133);
the `Player.gd` code fix was present but **uncommitted** in the working tree when this skill was
written — check `git log -1 -- src/entities/Player.gd` before assuming it shipped.

## 5. Two-tier contact: SHOVE vs SMASH

Model source: `docs/specs/v0_combat_lethality.md` v2.1 §2 (authority), implemented in
`src/entities/Player.gd` `_handle_smashes()` / `receive_smash()` / `_on_bounced()`.

### 5.1 The smash license (the one rule)

A body contact is a **SMASH** (knockback + hitstun + sting + kill credit) iff ALL of:

```
(attacker.super_active OR attacker.in_hitstun)   # a fired super, or a flying smashed body
AND rel_closing_speed >= smash_impact_min (900)   # anti-graze safety gate
AND attacker is the faster body                    # tiebreak
AND attacker's stun was not inflicted BY this victim   # _stunned_by pairwise immunity
```

Everything else is a **SHOVE**: a mutual momentum-scaled push
(`clamp(rel_speed * 0.5, 250, 700)` px/s), **no hitstun**, honest physics. A shove at
rel ≥ 500 still sets `last_attacker` so a body-check over the edge credits the checker.

Theory behind the split: the super is the game's one gun — ordinary contact must never produce
"traffic-accident" kills (the QA verdict that spawned this model), but strict supers-only would
kill Pillar-3 chain-reaction comedy, so smashed bodies stay licensed projectiles. The
`_stunned_by` immunity exists because without it the victim — who becomes a licensed "flying
stunned body" the next frame — counter-smashed their own attacker (landing a super was suicide,
attacker died 9/9). One line here; full story in skill `gottabounce-failure-archaeology`.

`super_active` lasts `super_active_time = 0.45` s after firing ≈ 1260 px of travel at full
launch speed — beyond that your super is spent and you're a body, not a missile.

### 5.2 Knockback math (worked)

Smash impulse = `smash_impulse_base (500) + rel_impact_speed * smash_impulse_from_attacker (1.35)`.
A clean super arrives at ~2200–2800 within its window → impulse ≈ 500 + 2500×1.35 ≈ **3875 px/s**
→ clamped by `max_speed` 3000: every clean super launches the victim at cap. Decisive by design.
The attacker keeps only `smash_self_retain = 0.1` of their own momentum — you stop on impact
instead of riding the victim off the edge.

### 5.3 Why the hitstun triad is PROTECTED

`hitstun = clamp(hitstun_base + impulse * hitstun_per_impulse, ..., hitstun_max)` =
`clamp(0.15 + impulse * 0.00025, ..., 0.55)`. A cap-speed smash (impulse 3875 → raw 1.12 s) always
clamps to **0.55 s** — at 3000 px/s that is ~1650 px of helpless travel, comparable to the
distance from mid-stage to the kill line. The cap guarantees **a recovery window always exists**:
ring-outs come from velocity/position, never from being frozen to death.

The triad — **hitstun → no mid-air refuel → fuel-gated recovery** — is the declared
"skill-heart of the game" (`docs/reference/GAME_DESIGN.md` §4.6: "Protect this interaction").
This is why `hitstun_base / hitstun_per_impulse / hitstun_max` are DO-NOT-TOUCH: raising hitstun
converts skill deaths into freeze deaths; every documented fallback knob for pacing problems
works on impulse, refire, sting, or shove instead — never hitstun (spec §"fallback knobs";
knob directions live in skill `gottabounce-tuning-and-flags`).

### 5.4 The recovery gamble, quantified

A smashed victim regains control after ≤ 0.55 s, cannot refuel mid-air (and, per the dry-reflect
rule §4, cannot refuel or un-stun by clipping a surface), and must snap-aim a counter-super
within ~0.2–0.3 s of stun end — IF the sting left them ≥ 5 fuel. Spec §9 criterion 6 tests this
in BOTH directions (fuel-starved victim dies ≥8/10; full-tank victim with scripted counter
survives ≥5/10) — testing only the kill side once shipped an inverted-kill bug.

## 6. The un-charged super and the aim window

Adopted 2026-07-02 (DECISIONS; reopen only with movement-course evidence). Behavior: press super
with fuel ≥ 5 → AIM state (floaty hover, stick steers arrow) → release, or auto-fire at
`super_aim_max = 2.0` s → constant `super_boost_impulse_full = 2800` px/s launch, fuel set to 0.
**Power NEVER scales with fuel or hold time** — 5 fuel fires exactly as hard as 100; aim and
timing are the only skill axes. Never re-introduce scaling (closed decision).

**Aim-hover math (the lethality guard).** Aim entry keeps full velocity
(`super_aim_velocity_keep = 1.0`) which then decays exponentially under
`super_aim_damp = 2.5` /s: `v(t) = v0 * e^(-2.5t)` → ×0.47 after 0.3 s. So a neutral drifter at
400 px/s settles to a readable hover in under half a second, while a smashed victim at 3000 px/s
is still doing ~1417 px/s after 0.3 s of aiming — **you are still dying while you aim**. If entry
cut velocity instead, pressing super would be a free air-brake that erases knockback. Gravity is
scaled by `super_aim_gravity = 0.25` while aiming; with proportional damp the sag settles toward
`0.25 * 1600 / 2.5 = 160 px/s` — you sag, you don't plummet, and the 2 s cap means you can never
hang (Pillar 2: the hover is a fuse, not a camp).

**Telegraphy is sacred:** the fuse ring + full-size arrow from frame 1 ARE the opponent's dodge
window. Do not shrink, hide, or speed past them (spec §1.4).

## 7. Juice theory — the "feel heavy" layer

Doctrine (FEEL_REFERENCE §5, implemented in `src/systems/Juice.gd` — presentation layer, INV-12:
subscribes to EventBus, owns no sim state):

**Rule of Three:** every meaningful action gets feedback in ≥ 3 channels — Visual + Audio +
Kinesthetic (shake/rumble/hitstop). A bounce = squash + puff (+ rumble); a smash = flash + shake
+ hitstop + rumble. Juice AMPLIFIES good feel; it must never fake it — mechanics first, juice last.

**Screen shake — the trauma² model** (Squirrel Eiserloh). `CameraController.gd` keeps a trauma
scalar [0,1]; per frame `offset = random_dir * shake_max_offset (22 px) * trauma²`, decaying at
`trauma_decay = 1.4` /s. Squaring keeps small events subtle and big ones violent. Live event
levels (Juice.gd): smash +0.55, super fire +0.7, kill +0.7, explosion +0.9, bounce scaled by
launch speed.

**Hitstop** (`Juice._hitstop`, guarded single-flight). Sets `Engine.time_scale` to a strength-
lerped freeze (0.12 → 0.04 for strength 0→1) for a strength-lerped duration (0.03 → 0.10 s),
then eases back to 1.0 over `Tuning.hitstop_recover = 0.12` s in 3 real-time steps. Smash
strength scales with impulse/2800; kills get full strength. Two facts worth knowing:
1. `Tuning.hitstop_timescale` (0.05) and `Tuning.hitstop_duration` (0.07) are **declared but
   unwired** as of 2026-07-03 — `Juice.gd` uses its own lerp constants and only reads
   `hitstop_recover`. Don't expect editing those two to change anything.
2. Because hitstop is GLOBAL `Engine.time_scale`, an interrupted recover leaves the whole game
   in slow-mo (a known trap — see skill `gottabounce-debugging-playbook`); `PartyMatch.gd:159`
   deliberately divides real-time UI beats by `Engine.time_scale` to stay honest during freezes.

**Squash & stretch — live numbers** (`Player.gd` ~858–884, code-driven, zero art cost):
bounce squash lerps to (1.25, 0.75) over `SQUASH_SWAP_TIME = 0.12` s (×1.4 amplitude under Mega
Bounce as telegraphy); fast ascent stretches toward (0.9, 1.12) proportional to upward speed
/1100; idle gets a 2% sine "breathe"; the pink skin swaps to a dedicated squash pose texture.
Victims get a 1-frame-ish white hit flash (`self_modulate` 2.6). FEEL_REFERENCE §5.3's table has
slightly different values — the code is the truth.

**Rumble and audio** channels are specced in FEEL_REFERENCE §5.4–5.5; rumble calls exist in
Juice.gd, audio does not exist yet as of 2026-07-03.

## 8. Readability doctrine (Pillar 5)

`docs/VISION.md` Pillar 5: *"Readable chaos — track 4–8 players mid-storm. Readability beats
prettiness."* The operational math:

- The party camera is dynamic (Smash-style frame-everyone): zoom ranges `CAM_MIN_ZOOM = 0.42` to
  `CAM_MAX_ZOOM = 0.92` (`PartyMatch.gd:29-30`). **Screen px = world px × zoom**, so at gameplay
  zoom-out anything world-sized loses ~10–58% of its pixels.
- **The fuse-ring lesson:** the super aim ring was authored as a 7 px world-space line → ~3 px on
  screen at far zoom → invisible exactly when the telegraph mattered. Fix: widths set per-frame in
  SCREEN px divided by camera zoom (`super_ring_screen_width = 9.0` + a dark 6 px backing outline
  + `super_ring_min_arc = 0.15` so an arc shows from frame 1 — `Player.gd:955-970`). General rule:
  **anything that must read across the couch gets a screen-space size, not a world-space size.**
- Asset-side readability standards (one line each — deep coverage in skill
  `gottabounce-art-pipeline`): powerup icons must read at 40 px (`docs/specs/v1_powerups.md` §1);
  goat horns must survive 25 px scale (goat eval brief); platform mat motifs must read at ~14
  screen px, and anything below ~10 screen px at far zoom is simplified, not shrunk
  (`docs/briefs/arena_rendering.md`).

## 9. Bot-as-human-sim theory

Bots play by human rules — same InputIntent surface, no cheating (INV-8). Difficulty is
**execution quality only**: the dials shape how well a bot aims, reacts, and commits, never what
it is allowed to do. This makes bots usable as feel instruments: if L4 stops beating L2, or L2
starts winning matches, a FEEL regression is the likely cause, not "AI difficulty".

The v2 rhythm the dials serve: **bounce → hunt → AIM → BLAST → dive to refuel → repeat.**

Live dial table (`src/core/BotProfile.gd`, 2026-07-03). Default lineup `bot_levels = [2, 3, 4]` —
L2 punchline / L3 fair fight / L4 menace; L5 reserved for campaign/hard mode:

| Dial | Meaning | L1 | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|---|
| `aim_error` (rad) | random aim jitter | 0.70 | 0.50 | 0.32 | 0.16 | 0.06 |
| `reaction_time` (s) | gap between decisions | 0.50 | 0.38 | 0.28 | 0.16 | 0.10 |
| `recovery_skill` (0–1) | recovery-super aim/timing quality | 0.20 | 0.40 | 0.60 | 0.82 | 0.95 |
| `aggression` (0–1) | hunt-roll probability | 0.25 | 0.45 | 0.65 | 0.85 | 0.95 |
| `target_lead` (0–1) | lead target by dist/impulse × this | 0.0 | 0.15 | 0.5 | 0.85 | 1.0 |
| `commit_time` (s) | a rolled hunt stays true this long | 0.0 | 0.4 | 0.8 | 1.3 | 1.5 |
| `attack_range` (px) | enter AIM inside this | 240 | 280 | 340 | 460 | 520 |
| `refuel_floor` (fuel) | below this: dive to a surface; gates attack runs | 15 | 20 | 25 | 35 | 35 |
| `super_aim_time` (s) | max AIM time before firing | 1.4 | 1.0 | 0.6 | 0.3 | 0.18 |
| `edge_guard` (0–1) | pursue off-stage victims | 0.0 | 0.0 | 0.3 | 0.7 | 0.9 |
| `leader_focus` (0–1) | target the score leader | 0.0 | 0.0 | 0.25 | 0.6 | 0.8 |
| `dodge_super` (0–1) | counter-super an incoming aim | 0.0 | 0.0 | 0.0 | 0.5 | 0.8 |

Theory notes: `target_lead` is the single biggest hit-rate dial (it is what separates "dodgeable
fireworks" from a menace); `recovery_skill` is the funniest one (low = panic-boosts off the map —
L1's comedy self-destructs are a FEATURE, regression-checked in spec §9.13); `refuel_floor`
encodes the refuel rhythm — it replaced the dead "bank-then-strike" model when power banking died
with the charged super.

## 10. Stale sources — cite with care

`src/core/Tuning.gd` is ALWAYS the live truth for values. These reference docs contain
superseded numbers/models (drift verified against Tuning.gd on 2026-07-03):

| Doc | Stale claim | Live truth |
|---|---|---|
| `docs/reference/FEEL_REFERENCE.md` §2.1 | gravity 2600; tiers 160/320/640/1280 | 1600; 120/180/270/480 |
| FEEL_REFERENCE §2.3 | air drift 700 / 190 | 1300 / 340 |
| FEEL_REFERENCE §2.4 | `bumper_restitution = 1.0` | 0.86 |
| FEEL_REFERENCE §3.2 | boost 4200 / 650 | 4600 / 760 |
| FEEL_REFERENCE §3.3 | CHARGED super: 1400 × fuel-fraction, min fuel 15 | un-charged, constant 2800, drain-all, min fuel 5 — **never re-introduce scaling** (DECISIONS 2026-07-02) |
| FEEL_REFERENCE §4 | `smash_impulse_base` 600, `from_attacker` 1.1 | 500 / 1.35 |
| FEEL_REFERENCE §5.1/5.3 | hitstop/squash exact values | Juice.gd/Player.gd code differs (§7 above) |
| `docs/specs/v1_powerups.md` | still describes the charged-super model in places | authority = `docs/specs/v0_combat_lethality.md` v2.1 |
| `docs/reference/GAME_DESIGN.md` §4.3 | "super strength scales with remaining fuel" | superseded by DECISIONS 2026-07-02 |

Still-good theory in FEEL_REFERENCE: §0 (numbers are hypotheses; tune ONE variable at a time;
record back), §5 (juice doctrine), §9 (tuning order: bounce → drift → boost → fuel → super →
knockback → juice LAST), and §10's external sources: Celeste player-physics constants (Maddy
Thorson), "Juice it or Lose it" (Grapefrukt), GameAnalytics juice guide (hitstop 3–5 frames, Rule
of Three), Squirrel Eiserloh's trauma-model GDC talk, More Mountains Feel docs, GMTK "Secrets of
Game Feel and Juice".

## Provenance and maintenance

Written 2026-07-03 against commit `0e315b9` (branch master). All constants and code claims were
verified by READING the repo (static verification only — no live game run; derived numbers such
as launch speeds, apex times, and decay factors are computed from the verified formulas and are
`verified: static`). Files read in full or in relevant part: `src/core/Tuning.gd`,
`src/core/BounceResolver.gd`, `src/core/BotProfile.gd`, `src/entities/Player.gd` (bounce/DI/
smash/squash paths — note: this file had UNCOMMITTED dry-reflect changes in the working tree at
writing time), `src/systems/Juice.gd`, `src/systems/CameraController.gd`, `src/modes/PartyMatch.gd`
(zoom constants), `docs/specs/v0_combat_lethality.md` (v2.1), `docs/DECISIONS.md`,
`docs/feedback/owner_2026-07-02_movement_feel.md`, `docs/reference/FEEL_REFERENCE.md`,
`docs/reference/GAME_DESIGN.md` §4.6, `docs/VISION.md`, `project.godot`.

Re-verification one-liners for drift-prone facts (Grep = static; `gbplay eval` needs a running
game — see skill `gottabounce-run-and-playtest`):

| Fact | Check |
|---|---|
| Gravity / tier heights / DI / restitution | `grep -n "gravity\|bounce_height\|bounce_di\|bumper_restitution" "src/core/Tuning.gd"` |
| Fuel economy block | `grep -n "fuel_\|tank_seconds\|super_boost_min_fuel" "src/core/Tuning.gd"` |
| Contact/hitstun block | `grep -n "smash_\|hitstun_\|soft_bump" "src/core/Tuning.gd"` |
| Live value at runtime | `python tools/gbplay.py eval "return Tuning.gravity"` |
| Dry-reflect fix committed yet? | `git log --oneline -2 -- src/entities/Player.gd` and read `_on_bounced` for the `_stun_timer <= 0.0` branch |
| Hitstop constants still unwired? | `grep -rn "hitstop_timescale\|hitstop_duration" src/` (only Tuning.gd hits = still unwired) |
| Camera zoom range | `grep -n "CAM_MIN_ZOOM\|CAM_MAX_ZOOM" src/modes/PartyMatch.gd` |
| Bot dials | read `src/core/BotProfile.gd` `for_level()` |
| Super still un-charged (closed decision) | `grep -n "2026-07-02.*SUPER BOOST" docs/DECISIONS.md` |

UNVERIFIED / caveats:
- All in-game BEHAVIOR claims (hover feel, decay curves as experienced, hitstop feel) are
  `verified: static` — derived from code/spec, not observed in a live run by this author.
- Lethality v2 overall is implemented but NOT QA-signed-off as of 2026-07-03 (QA re-verification
  found the core hinge passes but the bumper-save bug blocked ship; the §2.3a fix was in-progress/
  uncommitted at writing time). Treat pacing claims (SD%, kill-endings) as targets, not certified
  results — certified numbers live in skill `gottabounce-validation-and-qa`.
- Movement courses: specced, NOT built. Goat identity: adopt-staged, gated.
