# Spec: v0 Combat Lethality — rounds end by KILLS, not lasers

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD. **Version 2.1 — 2026-07-03.**
>
> **v2.1 changelog (QA re-verification fix, 2026-07-03):** QA's re-verification of the v2 build
> found the core hinge PASSES (6a/6b/9) but 4 criteria fail from ONE root cause: fix-round
> 587d0a1 made `_on_bounced()` unconditionally refund fuel and clear hitstun on EVERY bounce
> (including bumpers), so a smashed victim flying toward the kill line always survives by clipping
> the bumper 660px inboard of it. **New §2.3a is the ruling** — hitstun ends by TIME, never by
> touching a surface; bumper/tier contact during opponent-inflicted hitstun is now a **dry
> reflect** (no fuel, no stun-clear). This does not touch the owner's wall-return shot (that move
> is never in hitstun — see §2.3a rationale). §9 tests 6c/6d are new; tests 11/13/14/15 are
> re-scoped to the same numeric targets and must be re-run against this fix.
>
> **v2 changelog (same day, pre-build):** Reconciled against
> `docs/feedback/owner_2026-07-02_movement_feel.md` (highest-authority design input) BEFORE
> implementation started. Two structural changes from v1:
> 1. **§1 is new: the super boost is redesigned — UN-CHARGED.** Full power at any fuel ≥ a small
>    minimum, dumps the whole tank, brief aim-hover (≤2s) then auto-fire. The charge-hold model
>    (`super_charge_*`) is removed. This supersedes GDD §4.3's "super scales with remaining fuel."
> 2. **§2 contact is now two-tier:** physics SHOVE (no hitstun) vs SMASH (super-active attackers
>    and stunned flying bodies only). v1's light-smash tier (620 gate for boost-rams) is dropped.
>    Bot "bank-then-strike" (`strike_fuel`) is replaced by a refuel-rhythm model (§3).
> Sections on scoring guard, sudden-death pacing/visibility and match-end (§4–§7) carry over from
> v1 unchanged. QA criteria fully rewritten (§9).
>
> Responds to: QA playtest #1 ("kills feel like traffic accidents"; 55–60% laser-decided; L2 won a
> match; idle human scored 9) + the owner movement-feel thesis (TowerFall-caliber movement is the
> product). Sources: `docs/VISION.md`, `docs/reference/GAME_DESIGN.md` §4/§8,
> `docs/reference/FEEL_REFERENCE.md` §3–4, `src/core/Tuning.gd`, `src/entities/Player.gd`,
> `src/core/InputBot.gd`, `src/core/BotProfile.gd`, `levels/dev_arena.json`.

## The player fantasy

**"I read their arc, I pulled the trigger, and they're GONE."** The super boost is the game's one
gun, sword and dodge-roll at once: any time you have a sip of fuel, you can hang in the air for a
breath, aim, and detonate yourself across the screen. Land it on a rival and they rocket off
screaming. Miss, hit the wall behind them, bounce, and fire the return shot. Every touch that
doesn't kill visibly chunks the victim's fuel gauge — and a dry tank means no escape super, so
every hit advances a kill. Rounds are decided by somebody DOING something, in 10–20 seconds, and
the laser walls are the rare "you two cowards, FIGHT" punishment — not the game's executioner.

## Why v2 (design rationale — read before arguing with the numbers)

The v1 spec fixed lethality inside the charge-hold super model. The owner's feedback exposes that
model's real problem: **the game's only kill move was double-taxed.** To land a super you had to
(a) bank fuel (power scaled with fuel fraction), (b) stand still charging (power scaled with hold
time), and (c) still aim it. Result: players hoard, freeze, and whiff — QA's "traffic accidents"
were a symptom of a kill move too expensive to fire. The owner's un-charged model removes both
taxes and keeps only the skill that matters: **aim and timing.**

What the un-charged model buys, measured against the pillars:
- **Pillar 1 (low floor, high ceiling):** floor drops (any fuel = a real blast); ceiling *rises* —
  super-chaining through bounces, dodge-supers, wall-climbs, second-try return shots.
- **Pillar 2 (constant motion):** hoarding dies. Fuel is pure mobility currency; there is no
  "saving up for a big one." The aim-hover is hard-capped at 2s with an auto-fire — it can never
  become camping (same clause that legalizes the Black Hole channel, GDD §2 scope note).
- **Pillar 3 (physics comedy):** every super is all-in (dumps the tank), so every super is a
  commitment gag — and smashed bodies stay lethal projectiles (§2), so chains survive.
- **Pillar 4 (death cheap & funny):** the self-destruct is *always* violent now — a panic recovery
  super at 8 fuel launches just as hard as a full-tank one. Aiming it is the whole gamble.
- **GDD §4.6 recovery triad — PROTECTED and sharpened:** hitstun → no mid-air refuel → fuel-gated
  recovery. The gate changes shape: instead of "did I bank enough *power*," it's "do I have *any*
  fuel above the minimum, and can I snap-aim the counter before I cross the line." The smash sting
  (§2.2) attacks exactly this gate: a stung victim below `super_boost_min_fuel` has NO escape super
  — sting → starve → kill is the new authored kill loop. See §9 test 6, which QA must pass in both
  directions.

Fix order: **(1) rebuild the super, (2) make contact two-tier and decisive, (3) rebuild bot intent
on the new model, (4) gate the freebies, (5) demote sudden death.** Nothing here adds standable
ground, health bars, or HUD clutter.

---

## 1. The un-charged super boost (replaces the charge model)

### 1.1 Behavior (exact)

- **Press super** (with `fuel >= super_boost_min_fuel`): enter **AIM state**.
  - Velocity is kept (`super_aim_velocity_keep = 1.0` — entering aim is NOT a brake, see 1.3),
    then decays under `super_aim_damp` (proportional, per-sec) toward a hover.
  - Gravity is scaled by `super_aim_gravity = 0.25` while aiming — floaty, cinematic, readable.
  - The stick steers the aim arrow. No thrust, no drift, no fuel drain while aiming.
- **Release super** (or reach `super_aim_max = 2.0` s → **AUTO-FIRE** in current aim direction;
  no stick input ever = straight up, which is the funny default):
  - `velocity += aim_dir * super_boost_impulse_full` (2800, unchanged), clamped by `max_speed`.
  - **Fuel set to 0** — the super always dumps the whole tank (GDD §4.2 identity kept). Power is
    **constant regardless of tank level**: 5 fuel fires exactly as hard as 100.
  - `super_active` window opens for `super_active_time = 0.45` s (this is the §2 smash license;
    replaces the hardcoded `_super_recent = 0.6`).
  - `super_refire_lockout = 0.25` s before another aim can start (buffer-spam guard).
- **No cancel.** Once you enter AIM you are committed to firing within 2s — this is the
  telegraph: enemies see the rev-up (§1.4) and get their dodge window. The only out is being
  smashed (below).
- **Smashed while aiming:** aim CANCELS, **fuel retained**, normal knockback/hitstun applies.
  (Firing on stun would dump the victim's recovery tank — that would break the §4.6 triad.)
- **Bounce while aiming:** allowed, does not cancel. The bounce launch then decays under aim damp
  (a floaty pop) and the bounce refunds fuel as normal. This enables "aim during the bounce beat."
- **Shoved while aiming:** the shove impulse applies (you drift), aim continues. Only a smash
  cancels.

### 1.2 Why drain-all (not a flat cost)

A flat cost (e.g. 30) allows 3 airborne supers back-to-back with zero surface contact — floaty,
and hoarding returns ("save enough for two"). Drain-all forces every super chain **through a
bounce** (`fuel_per_bounce = 20 ≥ super_boost_min_fuel = 5`), which is exactly the owner's own
chain scenario ("miss → hit the bounce surface behind them → immediately super back") and keeps
the bounce-powered-jetpack identity load-bearing: **surfaces are the combo system.**

### 1.3 Why aim entry keeps full velocity (the lethality guard)

If entering AIM cut velocity (old model: ×0.25), pressing super would be a **free air-brake** — a
smashed victim flying out at 3000 px/s could erase their death for free. With keep = 1.0 and
`super_aim_damp = 2.5`, decay is honest:

| situation | v₀ | after 0.3s aim | distance drifted in 0.3s / 0.5s / 2.0s |
|---|---|---|---|
| neutral drift | 400 px/s | 189 px/s | 76 / 102 / 143 px — reads as a graceful hover |
| smashed at cap | 3000 px/s | 1417 px/s | 634 / 853 / 1192 px — you are still dying while you aim |

So for neutral play the freeze fantasy holds (near-hover in under half a second), while a smashed
victim who dawdles in aim drifts across the blast line. The recovery gamble becomes **snap-aim the
counter within ~0.2–0.3s of stun end** — the skill moment we want. All four aim constants live in
Tuning so the movement-courses loop (`docs/specs/v1_movement_courses.md`) can retune them.

### 1.4 Telegraphy (readability > prettiness)

- Reuse the existing charge visuals with new meaning: the **ring** (`_charge_ring`) fills over
  `super_aim_max` (a 2s fuse, yellow → red as auto-fire nears); the **arrow** shows aim at full
  size from frame 1 (power no longer scales, so the arrow shouldn't grow); exhaust rev-up stays.
- The read for opponents: *ring appearing = a blast is coming within 2s, arrow = where.* That is
  the dodge/counter window — do not shrink or hide it.

### 1.5 Tuning changes (exact)

| Constant | Current | New | Rationale |
|---|---|---|---|
| `super_boost_impulse_full` | 2800 | **unchanged** | Launch speed was never the problem. |
| `super_boost_min_fuel` | 15.0 | **5.0** | Owner: "even 5%." Also makes the sting-starve kill loop (§2.2) meaningful: 30-fuel sting drops a 34-fuel victim below the line. |
| `super_charge_time` / `super_charge_min_frac` / `super_charge_freeze` / `super_charge_glide_damp` | — | **REMOVED** | Charge model dies. Delete `_sb_charge` scaling in `Player.gd`; the fuel-fraction multiplier on launch (`clampf(fuel/fuel_max...)`) dies with it. |
| **`super_aim_max`** (NEW) | — | **2.0** | Owner cap. Auto-fire, never a hover-camp (Pillar 2). |
| **`super_aim_gravity`** (NEW) | — | **0.25** | Floaty aim; at ≤2s the max free-fall drop is ≤ ~200px — you sag, you don't plummet, you can't hang. |
| **`super_aim_damp`** (NEW) | — | **2.5** | §1.3 table. |
| **`super_aim_velocity_keep`** (NEW) | — | **1.0** | §1.3. Kept as a constant so the courses loop can experiment with entry-snap without code changes. |
| **`super_active_time`** (NEW) | — | **0.45** | Smash license window ≈ 1200px of travel at full speed — beyond that your super is spent and you're a body, not a missile. Replaces the hardcoded `_super_recent = 0.6` (Black Hole channel-break keeps using the same flag). |
| **`super_refire_lockout`** (NEW) | — | **0.25** | Prevents buffered double-fires at a spring. |
| **`pu_unlimited_super_lockout`** (NEW) | — | **1.0** | While `fuel_locked` (Unlimited Boost), the refire lockout is 1.0s instead — the powerup is a super machine-gun by design (GDD §5) but 20 supers in 8s is not a game. ~6 supers per pickup. |
| `fuel_per_bounce` | 20.0 | **unchanged** | 20 ≥ min_fuel 5 = one bounce always re-arms a super. The chain rhythm depends on this ordering — if either number changes, keep `fuel_per_bounce ≥ 2× super_boost_min_fuel`. |

Edge cases: `force_super_boost()` (Ring of Fire) is now fully consistent — every super is
full-power. Aim cannot start while stunned (intent already zeroed), while channeling (existing
cancel rules), or while dead/frozen. Spawn-protected players CAN aim/fire (escaping spawn is
legal). Buffered super presses during hitstun (≤ `input_buffer` before stun end) fire the aim
state on the first free frame — this IS the recovery gamble input.

---

## 2. Two-tier contact: SHOVE vs SMASH

**Owner model adopted:** the super is the only *reliable* launch; ordinary contact is honest
physics. v1's light-smash tier (impact gate at 620 so boost-rams cause hitstun) is **dropped** —
it would have re-created traffic-accident noise with extra steps. But strict "supers only" would
kill chain-reaction comedy (Pillar 3), so smashed bodies stay weapons:

### 2.1 Smash eligibility rule (the one rule to implement)

A body contact is a **SMASH** (knockback + hitstun + kill credit + sting) iff:

```
(attacker.super_active OR attacker.in_hitstun)          # a fired super, or a flying smashed body
AND rel_closing_speed >= smash_impact_min (900)          # safety gate vs spent/grazing contact
AND attacker is the faster body                          # existing tiebreak, unchanged
```

Everything else is a **SHOVE** (§2.3). Existing special contacts are untouched: Star contact-launch,
Counter Shield parry, storm balls, explosions, props (props keep the plain speed gate — a fast
heavy ball doesn't need a super license, it IS one).

| Constant | Current | New | Rationale |
|---|---|---|---|
| `smash_impact_min` (**NEW** — move `Player.gd` const `IMPACT_MIN` into Tuning, INV-6) | 800 (const) | **900** | Only checked for eligible attackers. A super arrives at 2200–2800 within its 0.45s window — always passes. A stunned body launched at cap passes until it decays. Passive spring crossings (~930 px/s) never smash regardless — they fail eligibility. The gate exists so an end-of-window graze doesn't feel random. |
| `smash_impulse_base` | 600 | **500** | Speed-scaled term carries the weight. |
| `smash_impulse_from_attacker` | 1.1 | **1.35** | Super at ~2500 impact → impulse ≈ 500 + 2500×1.35 ≈ 3875 → victim exits at `max_speed` cap. Every clean super launches at cap = decisive. Chain body at cap → same. **This is the first knob DOWN (→1.2) if rounds get too short (<8s median).** |
| `hitstun_base` / `hitstun_per_impulse` / `hitstun_max` | 0.15 / 0.00025 / 0.55 | **unchanged** | GDD §4.6: "protect this interaction." Ring-outs come from momentum, never from being frozen to death. Do not touch — see §9 test 6's explicit both-ways check. |
| `smash_self_retain` | 0.1 | **unchanged** | You stop on impact; you don't ride the victim off the edge. |
| `max_speed` | 3000 | **unchanged** | Cap = your own super ceiling; raising it makes self-destructs unrecoverable too. |

### 2.2 Smash sting — hits have a lasting cost (carried from v1, now the kill-setup engine)

- **NEW `smash_sting_fuel = 30.0`** — on `receive_smash()` with impulse ≥
  `smash_sting_min_impulse`, victim fuel −30 (floored at 0), applied before hitstun.
- **NEW `smash_sting_min_impulse = 1500.0`** — all supers and chain hits sting; Star contact
  (900) and Counter reflect (1400) sit below the line by design (powerups launch, they don't
  starve); explosions sting only near the epicenter (1600 center, linear falloff) — bombs should
  scare people.
- **NO input/fuel lock** — the sting attacks the *fuel* side of the §4.6 triad instead: hitstun →
  no mid-air refuel → and now, if the sting dropped you below `super_boost_min_fuel` (5), **no
  escape super at all**. Sting → starve → kill is the authored 2-hit kill on a mid-tank victim
  (34 fuel − 30 = 4 < 5). A full-tank victim survives one smash with a full-power counter in hand
  — banking fuel still pays, for *defense*.
- **Edge cases:** `invincible`/`_spawn_protect` early-outs skip the sting (already return before
  knockback). `_smash_cd = 0.3` rate-limits sting spam. A victim stung mid-AIM keeps their
  (pre-sting) tank? **No** — sting applies, aim cancels with the *stung* fuel retained. Consistent:
  the hit cost you 30 fuel whether you were aiming or not.

### 2.3 The SHOVE — sub-super contact stops being invisible

Replace `_soft_separate()`'s flat 300 px/s with a momentum-scaled body-check. Since shoves are now
the ONLY sub-super player contact, they get more authority than v1 gave them:

- **NEW `soft_bump_scale = 0.5`**, **`soft_bump_min = 250.0`**, **`soft_bump_max = 700.0`** —
  push = `clamp(rel_speed * soft_bump_scale, min, max)` along the separation axis, applied
  mutually. A committed boost-ram (rel ~700) shoulder-checks the rival at ~350 px/s — visible,
  positional, **no hitstun** (they keep full control and can boost back: honest physics, and near
  an edge it's a real threat that the victim can always answer).
- **NEW `shove_credit_min_rel = 500.0`** — a shove at rel speed ≥ 500 sets the shoved player's
  `last_attacker` (standard `kill_credit_window`). A body-check that carries someone over the
  line must credit the checker, not read as a suicide — that would be a rage generator.
- No sting, no hitstun, no `smashed` event (shoves never satisfy `survival_requires_contact`).

### 2.3a Bounce/bumper recovery gate — v2.1 ruling (2026-07-03, fixes QA re-verification FAILs 11/13/14/15)

**Root cause (confirmed by QA, deterministic repro):** fix-round 587d0a1 made `_on_bounced()`
unconditionally refund fuel (`fuel_per_bumper = 20`) and clear hitstun (`_stun_timer = 0`,
`_stunned_by = null`) on **every** surface contact, bumper or tier, to enable the owner's
wall-return shot. Side effect: because bumpers sit ~660px inboard of the kill line
(`levels/dev_arena.json` §2.4), a smash victim launched toward an edge always clips a bumper
before the blast line, and that touch instantly un-stuns, refuels, and velocity-reflects them to
safety — regardless of who hit them or how hard. This makes off-stage kills structurally
un-earnable (test 15: 1/23 vs ≥3/10 target) and cascades into SD rate (test 11), L2 win-rate
(test 13) and idle-punishment (test 14) all softening back toward the pre-lethality-v2 numbers.

**The ruling — one governing principle:** ***Hitstun ends by TIME, never by touching a surface.***
This was always the implicit contract of GDD §4.6 (hitstun → no mid-air refuel → fuel-gated
recovery); 587d0a1 broke it as a side effect of solving a narrower problem (dry bumper rebounds
felt bad and blocked the owner's wall-return shot). The fix does not need a special bumper-only
carve-out — it applies uniformly to `_on_bounced()` for BOTH bumper and tier contact, because the
underlying bug (a free save mid-flight) is the same wherever it happens:

- **If `_stun_timer <= 0.0` at the moment of contact (the player is NOT currently in
  opponent-inflicted hitstun — this covers all neutral play, all self-triggered bounces, and
  specifically the owner's wall-return shot, which by construction never involves hitstun: he
  describes a **non-stunned attacker** self-supering into a bounce surface):** behavior is
  **unchanged from the current build** — full `fuel_per_bumper`/`fuel_per_bounce` refund, squash
  FX, juicy bounce event, and (already-true) no-op stun clear. **`fuel_per_bumper` stays 20.0** —
  it already satisfies `fuel_per_bumper ≥ super_boost_min_fuel` and matches `fuel_per_bounce`'s
  chain-rhythm rule; the wall-return shot needs no numeric change, only the gate above it removed
  from the stunned case. QA ruling on the pending interpretation: **do not raise or lower it.**
- **If `_stun_timer > 0.0` at the moment of contact (the player IS currently stunned by an
  opponent's smash or counter-launch — a licensed flying body per §2.1):** this is a **DRY
  REFLECT**. The physical bounce/ricochet still resolves exactly as now (`BounceResolver.resolve`
  / `resolve_bumper` are unconditional, upstream of `_on_bounced` — a body still visibly caroms off
  the surface; removing that would look like clipping through geometry). But `_on_bounced` must
  **skip the fuel refund and skip clearing `_stun_timer`/`_stunned_by`** in this branch. Hitstun
  keeps ticking down on its own clock (the existing `_physics_process` decrement at ~line 313
  already does this correctly once nothing else resets it). Squash FX and the juicy-bounce event
  still fire — the clang should still read and feel good, it just doesn't save you.
- **Chosen over the alternatives QA raised, and why:**
  - *(a) "clear hitstun but no refund" or vice versa* — rejected: any partial clear still lets a
    victim regain aim/steer control mid-flight before the blast line, which is the exact bug (a
    bounce ending hitstun early). Both halves of the free save have to go together.
  - *(b) keep launch-speed on reflection vs. dampen it* — **no change**: `resolve_bumper` already
    applies `bumper_restitution = 0.86`, so a body arriving at ~2983 px/s leaves at ~2526 px/s
    reflected back into the stage. That is intentional and stays: under §2.1 a stunned flying body
    already IS a licensed smasher (`attacker.in_hitstun` branch), and `_stunned_by` pairwise
    immunity already prevents the reflected victim from re-smashing their own launcher on the
    rebound. A bumper-reflected body at kill-speed smashing a THIRD player who's standing near the
    bumper is exactly the Pillar-3 pinball chaos we want, and it is now *earned* chaos — it costs
    the victim their own hitstun window instead of buying them a free escape. No new rule needed
    here; §2.1's existing eligibility check already covers it correctly once the free-clear bug is
    gone.
  - *(c) "keep hitstun through the reflect, let it expire naturally, then resume normal rules"* —
    **this is the ruling above**, stated as the general contract rather than a bumper special case.
- **Buffered super interaction (pending interpretation #1 — programmer's "buffer extends through
  empty tank" reading):** **KEEP, unchanged, no cap added.** Re-reading the implementation
  (`_sb_buffer = Tuning.input_buffer` re-armed every held frame, both in the hitstun-buffer path
  and the lockout/empty-tank path): this is not an unbounded buffer — it only ever looks
  `input_buffer` (0.10s) ahead of the CURRENT frame, and only fires the instant a REAL legal
  condition exists (lockout elapsed AND fuel available). It cannot fire off a dry reflect, because
  a dry reflect no longer produces fuel. A player holding super through a sting-starved stun who
  eventually clears hitstun by time and then reaches a genuine (non-stunned) bounce will correctly
  auto-fire the instant that bounce lands — that IS the recovery gamble reading as "I never let go
  of the trigger," which is good feel, not an exploit. No new constant needed.

**Expected effect on the failing tests:** test 15 (edge-guard kills) should recover toward its
≥3/10 target because a stunned victim near a bumper no longer auto-saves; test 11 (SD rate) and
test 13 (L2 win-rate)/14 (idle punishment) should recover toward their pre-regression numbers
(12.5% SD, 0/5 L2 wins, 0 idle score) because kills that were being erased at the bumper line now
land. New §9 tests 6c/6d isolate and lock in this exact behavior for regression protection.

### 2.4 Blast-zone tightening (`levels/dev_arena.json` — data, not code; carried from v1)

| Bound | Current | New | Rationale |
|---|---|---|---|
| `left` / `right` | −1000 / 2900 | **−620 / 2520** | Runway past the stage edge drops to ~660px ≈ 0.22s at cap speed. A cap-speed smash near the edge kills before the stun ends; a mid-stage victim regains control with roughly one snap-aim's worth of runway left (§1.3) — the recovery gamble survives, barely, which is where it belongs. A player who merely drifts off in control recovers in <0.5s of boost. |
| `top` | −1350 | **−950** | Spring + supercharge apex ~y −400; 550px headroom remains. A full vertical super still self-destructs off the top — the comedy knob, 400px sooner. |
| `bottom` | 1780 | **unchanged** | Floor spans the stage; bottom ring-outs are rare and fine. |

Laser walls spawn at the new bounds — §5.

---

## 3. Bot intent overhaul (`InputBot.gd` + `BotProfile.gd`)

Bots keep playing by human rules (INV-8). The v1 "bank-then-strike" model dies with the charge —
there is no power to bank. The new readable rhythm is **bounce → hunt → AIM → BLAST → dive to
refuel → repeat**, and the new skill axes are *aim quality* and *aim speed*.

### 3.1 Dials — retained, replaced, new

| Dial | L1 | L2 | L3 | L4 | L5 | Notes |
|---|---|---|---|---|---|---|
| `aim_error` (rad) | 0.70 | 0.50 | 0.32 | **0.16** | 0.06 | existing; L4 0.18→0.16 |
| `reaction_time` (s) | 0.50 | 0.38 | 0.28 | **0.16** | 0.10 | existing; L4 0.18→0.16 |
| `recovery_skill` | 0.20 | 0.40 | 0.60 | **0.82** | 0.95 | existing; governs recovery-super aim/timing only — the recovery super itself is now always full power |
| `aggression` | 0.25 | 0.45 | **0.65** | **0.85** | 0.95 | existing; L3 0.60→0.65, L4 0.78→0.85 |
| **`target_lead`** (0–1) | 0.0 | 0.15 | 0.5 | 0.85 | 1.0 | NEW (from v1). Aim at `target_pos + target_vel * (dist / super_boost_impulse_full) * target_lead`. The single biggest hit-rate fix. |
| **`commit_time`** (s) | 0.0 | 0.4 | 0.8 | 1.3 | 1.5 | NEW (from v1). Hunt stays TRUE this long once rolled — no re-rolling every tick. |
| **`attack_range`** (px) | 240 | 280 | 340 | 460 | 520 | NEW (from v1). Replaces hardcoded `dist < 280`. |
| **`refuel_floor`** | 15 | 20 | 25 | 35 | 35 | NEW — **replaces v1's `strike_fuel`**. Below this, the bot prioritizes diving to a bounce surface over hunting; it also gates starting an attack run (travel + post-miss escape budget, not power). |
| **`super_aim_time`** (s) | 1.4 | 1.0 | 0.6 | 0.3 | 0.18 | NEW — max time spent in AIM before firing at the best current solution. L1 hangs comically (sometimes hits the 2s auto-fire); L5 snap-fires. Replaces v1's charge-release rule. |
| **`edge_guard`** (0–1) | 0.0 | 0.0 | 0.3 | 0.7 | 0.9 | NEW (from v1). Pursue off-stage victims and smash them outward. Self-preservation gate: own `fuel >= refuel_floor` AND own position inside `bounds.grow(-250)`. |
| **`leader_focus`** (0–1) | 0.0 | 0.0 | 0.25 | 0.6 | 0.8 | NEW (from v1). With this probability, target the score leader if within 1.5× `attack_range`; else nearest. Gives the race a villain; keeps a lucky L2 honest. |
| **`dodge_super`** (0–1) | 0.0 | 0.0 | 0.0 | 0.5 | 0.8 | NEW — the owner's dodge-counter, botified: when an enemy enters AIM within 500px with their aim within 0.5 rad of me, roll per reaction tick → fire my own super perpendicular/away (prefer a direction that lands on a bounce surface — refuel follows). Max once per enemy aim window. |

### 3.2 Behavior rules (implementable, dial-free)

1. **Aim-timed release** (replaces `_sb_hold = randf_range(0.45, 1.1)` and the charge hold): enter
   AIM when hunting, target within `attack_range`, and `fuel >= refuel_floor`. While aiming, keep
   steering at the *led* target; fire when the angle error < `aim_error * 0.5` **or** aim time
   reaches `super_aim_time`. Low-lead bots still whiff constantly — the comedy survives, the
   freeze-and-pray doesn't.
2. **Refuel rhythm** (replaces bank-then-strike): while `fuel < refuel_floor`, dive toward the
   nearest bounce surface (aim down-toward-stage; boost only if falling away from it). One bounce
   = +20 = re-armed; this beat is FAST now and reads as the bot's drum pattern.
3. **Punish passivity (all levels, carried from v1):** arena tracks per-player `secs_since_input`
   (reset on boost/super press, ticks only during COMBAT). Past **`idle_hunt_after = 4.0`** (NEW,
   Tuning), the nearest living bot overrides its targeting to the idler until they press
   something. Pillar 2: passive bouncing is camping.
4. **Survival-first recovery loop untouched** — `_danger_recover()` stays top priority;
   edge-guard sits behind it. Its super is now always full power, so L1's comedy self-destructs
   get *bigger*, not rarer.
5. **Dodge-super (L4/L5)** per the `dodge_super` dial — this is the showcase of the new model:
   the human commits to an aim, the menace bots *move*.

### 3.3 Per-level behavior targets (what QA should see)

- **L2 — the punchline (stays comedic, stops winning):** aim 0.5, lead 0.15, 1.0s hangs in AIM —
  its supers are dodgeable fireworks. Its income streams stay dry (SD <25%, survival gate §4,
  L4/L5 `leader_focus` hunts any lucky lead). Suicides stay.
- **L3 — the fair fight:** a new human trades rounds with it roughly evenly.
- **L4 — the menace:** leads at 0.85, snap-aims in 0.3s, dodge-supers half the time, edge-guards
  at 0.7, focuses the leader. Being ahead should feel *hunted*.
- **L5 — reserved** (campaign/hard mode); table ships so `bot_levels` stays hot-swappable.

---

## 4. Scoring guard — idle accrual (carried from v1 unchanged)

Primary fix is §3.2 rule 3 (idlers get attacked). Backstop that also ships:

- **NEW `survival_requires_contact = true`** (Tuning, bool): the survival point requires the
  survivor to have **dealt or received ≥1 smash** (a `smashed` event; shoves don't count) during
  the round. Contact flags persist across a double-KO revive; reset at ROUND_INTRO.
- Counting *received* smashes keeps skilled evasion legal — surviving under fire scores, hiding
  untouched doesn't. Edge case: rival insta-suicides with zero contact → survivor +0 (banner still
  names them, deltas show `+0` honestly). Show up to score.

---

## 5. Sudden death pacing — demote the lasers to a backstop (carried from v1 unchanged)

Target: **<25% of rounds reach SUDDEN_DEATH** (was 55–60%). §1–§3 do the heavy lifting.

| Constant | Current | New | Rationale |
|---|---|---|---|
| `sudden_death_time` | 20.0 | **unchanged** | Lowering it would *raise* the laser-decided share. |
| `laser_close_time` | 10.0 | **6.0** | Wall speed on new bounds ≈ 263 px/s — visibly scary, dodgeable. Max combat clock 26s. |
| **NEW `laser_revive_start_frac`** | — | **0.4** | Double-KO revive: lasers spawn already 40% closed (≈ visible screen edges — instantly on-camera) and close over ≤3.6s. If already further closed, keep current: `frac = max(current, 0.4)`. |

**Revive-path timing (the 36.3s breach):** worst case double-KO at ~20s → 0.8s banner → ≤3.6s
close → decided ≤ ~25s combat, ≤30s wall-clock BOUNCE→ROUND_END including freezes. Revived players
spawn at the two spawn points nearest stage center (never inside/behind a part-closed wall). One
revive max per round, unchanged.

---

## 6. SD wall visibility — edge warning flicker (carried from v1 unchanged)

- **NEW `sd_warning_lead = 3.0`** (Tuning): from `round_clock = sudden_death_time − 3.0`, two
  full-height ~24px translucent laser-red columns (two ColorRects on a CanvasLayer, no shader)
  pulse at 2Hz (alpha 0.15 ↔ 0.45) at the screen's left/right edges — the round-loop spec §3
  pre-authorized "3s warning flicker."
- At SD start the columns become **wall trackers**: clamped to the screen edge while the laser is
  off-screen, snapping onto the wall's real x when it enters frame. Players always know where
  death is. Revive path: no lead pulse (walls spawn ≈ on-screen); trackers on.

---

## 7. Match-end readability (carried from v1 unchanged)

- **Backing panel:** MATCH_END banner + final scoreline + `A — REMATCH  B — QUIT` on a chunky
  rounded panel (Theme StyleBoxFlat: ~#141428 at 85% opacity, corner radius ~24px, 48px padding,
  thin outline in the winner's color). Built as a .tscn scene per studio UI rules. Legible over
  ANY frozen chaos.
- **Cleanup:** on ROUND_END entry, free (not halt) all SD nodes — walls, glow/particles, warning
  columns. QA screenshots MATCH_END: zero laser pixels.

---

## 8. New/changed constants — one block (implementation checklist)

```
# Tuning.gd — changed
smash_impulse_base          600  -> 500
smash_impulse_from_attacker 1.1  -> 1.35
super_boost_min_fuel        15.0 -> 5.0
laser_close_time            10.0 -> 6.0

# Tuning.gd — REMOVED (charge model dies; delete fuel-fraction launch scaling in Player.gd too)
super_charge_time, super_charge_min_frac, super_charge_freeze, super_charge_glide_damp

# Tuning.gd — new (super v2)
super_aim_max             = 2.0
super_aim_gravity         = 0.25
super_aim_damp            = 2.5
super_aim_velocity_keep   = 1.0
super_active_time         = 0.45    # replaces hardcoded _super_recent = 0.6
super_refire_lockout      = 0.25
pu_unlimited_super_lockout = 1.0

# Tuning.gd — new (contact)
smash_impact_min        = 900.0   # was Player.gd const IMPACT_MIN=800; MOVE into Tuning (INV-6)
smash_sting_fuel        = 30.0
smash_sting_min_impulse = 1500.0
soft_bump_scale         = 0.5     # replaces hardcoded 300.0 in Player._soft_separate
soft_bump_min           = 250.0
soft_bump_max           = 700.0
shove_credit_min_rel    = 500.0

# Tuning.gd — new (round/SD/scoring)
laser_revive_start_frac   = 0.4
sd_warning_lead           = 3.0
idle_hunt_after           = 4.0
survival_requires_contact = true

# Tuning.gd — UNCHANGED, explicitly reaffirmed by v2.1 ruling (§2.3a) — do not touch
fuel_per_bumper = 20.0   # neutral (non-stunned) contact only; stunned contact refunds ZERO (code fix, no constant change)

# Player.gd — v2.1 fix (§2.3a), NO new Tuning constants required
# _on_bounced(): branch on `_stun_timer > 0.0` at entry.
#   - branch true (opponent-inflicted hitstun in progress): DRY REFLECT — skip fuel refund, skip
#     `_stun_timer = 0` / `_stunned_by = null`; still run squash FX + EventBus.bounced/bounced_juicy.
#   - branch false (neutral/self-triggered, includes the owner's wall-return shot): unchanged
#     current behavior (full refund + stun-clear, the latter already a no-op here).
#   Applies uniformly to BOTH call sites (tier-bounce line ~493 and bumper line ~502) — same
#   function, same rule, no per-surface special-casing.

# DO-NOT-TOUCH (by design): hitstun_base/per_impulse/max, smash_self_retain, max_speed,
#   super_boost_impulse_full, sudden_death_time, fuel_per_bounce (keep >= 2x super_boost_min_fuel),
#   fuel_per_bumper (value), the buffered-super-through-empty-tank behavior (§2.3a — keep as built)

# BotProfile.gd — new dials (per-level values in §3.1)
target_lead, commit_time, attack_range, refuel_floor, super_aim_time, edge_guard,
leader_focus, dodge_super          # (v1's strike_fuel is DEAD — do not implement it)

# levels/dev_arena.json — bounds
left -1000 -> -620 · right 2900 -> 2520 · top -1350 -> -950 · bottom unchanged

# Arena — expose for QA (read-only via eval)
round_stats: per-round {length_s, end_cause, entered_sd, kills[{killer,victim,off_stage}],
  survivor_had_contact, supers_fired[{who,fuel_at_fire,aim_time,auto_fired}]}
```

---

## 9. Success criteria (QA-verifiable via gbplay eval + screenshots)

Harness: 10-round bot-driven sample = standard lineup with P1 given an L3 brain via eval; "idle
match" = P1 untouched. Arena must expose `round_stats` (§8).

**The new super**
1. **Full power at any fuel:** eval attacker fires at 100 fuel, then at 6 fuel → victim launch
   speeds identical within 5%. Attacker at 4 fuel (< min) → aim state never starts.
2. **Drain-all + chain rhythm:** scripted: super at a wall → bounce → fuel reads ≥20 → second
   super fires within 1.5s of the first at identical launch speed. (The Chimney course in
   `v1_movement_courses.md` is the full acceptance test of this loop — run its wall-climb script
   as part of this QA pass.)
3. **Aim is bounded:** hold super 3s → auto-fire at 2.0 ± 0.1s, in last-stick direction (straight
   up if never aimed). No state where a player hangs past 2.1s.
4. **Aim is not a brake:** eval a body at 3000 px/s entering aim → after 0.3s its speed is
   1300–1550 px/s (decay curve §1.3, ±10%).
5. **Smashed-while-aiming:** victim in AIM takes a smash → aim cancels, no super fires, fuel =
   pre-hit fuel − sting (eval), normal hitstun applies.

**Lethality & the protected recovery window**
6. **Both directions (GDD §4.6 — the spec fails if EITHER side fails):**
   a. *Kill:* no-input victim at **4 fuel** mid-stage; scripted full super from 400px, flat →
      ring-out ≤2.5s in **≥8/10**.
   b. *Recovery:* same hit, victim at **100 fuel** with a scripted counter-super fired within
      0.25s of stun end, aimed opposite → survives in **≥5/10**. Same victim, no counter → dies
      in ≥7/10. If (b) fails low, dial `smash_impulse_from_attacker` down — never hitstun up.
   c. **NEW (v2.1, the bumper dry-reflect):** repeat 6a's exact setup but place the fuel-starved
      (4-fuel) victim so their launch arc crosses a bumper before the kill line. Expect: on
      contact, `velocity` reflects (per `resolve_bumper`) but `fuel` stays at 4 (no refund) and
      `_stun_timer`/`_stunned_by` are unchanged from pre-contact values (eval both fields
      immediately after the contact frame) — hitstun then continues its own countdown. Victim
      still rings out ≤2.5s in **≥8/10** (same bar as 6a — the bumper must no longer save them).
   d. **NEW (v2.1, the wall-return shot must still work):** a NON-stunned player (`_stun_timer ==
      0` throughout) fires a super, misses, contacts a bumper on the rebound while holding super
      down → fuel reads `fuel_per_bumper` (20) within one physics frame of contact, and a second
      AIM state starts within `super_refire_lockout + input_buffer` (≤0.35s) of that frame at full
      `super_boost_impulse_full` launch speed. **≥9/10** — this is the owner's signature move and
      must reproduce whenever the geometry allows it.
7. **Sting:** qualifying smash drops victim fuel by exactly 30; a shove changes fuel by 0; a
   spawn-protected victim takes no sting. Sting-starve: victim at 34 fuel takes one super → fuel
   4 → their super press does nothing (aim never starts).
8. **Two-tier reads:** two players boost-ram (rel closing 650–750) → zero hitstun events, both
   receive a shove ≥ `soft_bump_min`; a shove at rel ≥500 that carries the victim out credits the
   shover as killer (not a suicide).
9. **Chain smash (Pillar 3):** A, B, C eval-placed in a line; A supers B; B's stunned body
   reaches C → C enters hitstun (a real `smashed` event) in **≥7/10** alignments.

**Pacing**
10. **Kills carry the game:** ≥70% of the 10-round sample ends by ring-out/hazard kill with
    `round_clock < 20s` (`end_cause != "laser"`, `entered_sd == false`).
11. **SD is rare:** ≤25% of rounds enter SUDDEN_DEATH (was 55–60%; regression-tested at 27–33%
    with the bumper-save bug — §2.3a fix must bring this back under the 25% line; re-run required).
12. **Round length:** median combat length 10–22s; every round decided ≤26s combat clock and ≤30s
    wall-clock BOUNCE→ROUND_END — including one QA-forced double-KO revive round (retests the
    36.3s breach).

**Skill hierarchy**
13. **L4 > L2:** across 5 full idle-P1 matches, L4 finishes above L2 in ≥4/5 and L2 wins 0/5. L2
    still suicides ≥1×/match (comedy regression check). (Regression-tested: L2 won 1/5 with the
    bumper-save bug — §2.3a fix must bring this back to 0/5; re-run required.)
14. **Idle human punished:** full idle match → P1 total ≤2, and P1 receives a smash within 8s of
    BOUNCE in ≥70% of rounds (idle-hunt firing). (Regression-tested: P1 scored 3 once with the
    bumper-save bug — §2.3a fix must bring the score cap back under ≤2; re-run required.)
15. **Edge-guarding observable:** ≥3 kills in the sample where the killing smash connected while
    the victim was off-stage (`kills[].off_stage`). (Regression-tested: 1/23 with the bumper-save
    bug — §2.3a fix is the direct target of this test; re-run required and is the primary
    acceptance gate for the fix.)
16. **Dodge-super observable:** ≥2 logged events in the sample where an L4 bot fired a super
    within 0.4s of an enemy entering AIM within 500px (`supers_fired[]` cross-referenced).

**Sudden death & readability**
17. **Warning reads:** QA-stalled round screenshot at `round_clock ≈ 18s` shows the pulsing edge
    columns; at ≈20.5s shows SD banner + wall trackers/walls.
18. **Revive path:** forced double-KO → walls ≥40% closed on the revive frame, both revived
    players spawn between the walls, round decided ≤5s after revive.
19. **MATCH_END clean:** backing panel behind banner/scoreline/prompt, text legible, zero
    laser/warning pixels.
20. **Survival gate:** survivor with no smash dealt/received → +0; survivor who was hit once → +1.

**Regressions (from v0_round_loop.md)**
21. Round turnaround last-death→next BOUNCE ≤4.5s; 60fps criterion (avg ≥55, no hitch >100ms)
    during a smash-heavy round; countdown lock and no-mid-round-respawn unchanged.

## Out of scope / fallback knobs

Powerup rebalance beyond `pu_unlimited_super_lockout`, new arena geometry beyond `bounds`, audio,
L5 in the default lineup, hitstun/recovery-window changes (§4.6 protected), camera changes, online.

**If rounds get too short (<8s median) or feel random:** first knob is
`smash_impulse_from_attacker` 1.35 → 1.2; second is `super_refire_lockout` 0.25 → 0.5. **If
everyone always recovers (kills too rare):** first knob is `smash_sting_fuel` 30 → 40 (starves
the escape super faster); second is `soft_bump_max` up (edge pressure). Never touch hitstun, and
never re-introduce power scaling on the super — that decision is closed
(`docs/DECISIONS.md` 2026-07-02) unless the movement-courses loop produces evidence against it.

**If §2.3a's dry-reflect makes edge kills feel TOO cheap (visually the bumper "does nothing" and
a stunned body just vanishes past it into the blast line with no readable beat):** the fallback is
NOT to bring back the refund/clear — it's to make the dry reflect itself more visible (bigger
squash/flash on a stunned-body bumper hit, a distinct SFX cue) so the "you hit the wall but you're
still going" moment reads clearly rather than being silent. Do not reopen the refund/clear gate;
that is the closed decision this amendment makes (`docs/DECISIONS.md` 2026-07-03).
