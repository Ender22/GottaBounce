# Spec: v0 Combat Lethality — rounds end by KILLS, not lasers

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD. **Last updated:** 2026-07-02.
> Responds to QA playtest #1 of `v0_round_loop.md` (18/19 PASS, fun diagnosis: "kills feel like
> traffic accidents"; 55–60% of rounds laser-decided; L2 bot won a match; idle human scored 9).
> Sources: `docs/VISION.md` (pillars), `docs/reference/GAME_DESIGN.md` §4/§8,
> `docs/reference/FEEL_REFERENCE.md` §3–4, `src/core/Tuning.gd`, `src/core/InputBot.gd`,
> `src/core/BotProfile.gd`, `src/entities/Player.gd`, `levels/dev_arena.json`.

## The player fantasy

**"I lined that up, I pulled the trigger, and they're GONE."** A super-boost smash is an authored
moment — you banked fuel, read their arc, committed, and the victim rockets off-screen screaming.
Every touch matters: even a hit that doesn't kill visibly chunks the victim's fuel gauge and sets up
the next one. Rounds are decided by somebody DOING something, in 10–20 seconds, and the laser walls
are the rare "you two cowards, FIGHT" punishment — not the game's executioner.

## Diagnosis (why contact currently doesn't decide rounds)

1. **Most contact is a no-op.** `Player.gd` `IMPACT_MIN = 800` (hardcoded const) requires 800 px/s
   *relative closing speed* for a smash; `normal_boost_max_speed` is 760, so a deliberate boost-ram
   into a drifting rival usually falls into `_soft_separate()` (a flat 300 px/s nudge). Four blobs
   drift through each other → "traffic accidents."
2. **Landed hits have no lasting cost.** The victim's first surface contact clears hitstun AND
   refunds fuel (`_on_bounced`), the side **bumper walls reflect them back into play** at 0.86
   restitution, and the blast zone is ~1000px past the stage edge (`dev_arena.json` bounds
   −1000/2900). A smash that doesn't instantly kill resets to zero progress.
3. **Bots don't hunt.** `InputBot._decide()` re-rolls `randf() < aggression` every reaction tick
   (L4 goes passive 22% of ticks mid-chase), supers need `dist < 280 && fuel > 55`, the charge hold
   is a random 0.45–1.1s during which the bot freezes and the target leaves, and aim has zero target
   lead. No edge-guarding, no leader focus, no punishment for idlers.
4. **Sudden death pays too well.** With few kills, most rounds reach 20s; lasers then hand out kill
   credits + survival points to whoever floats longest. That's how L2 won a match and an idle human
   banked 9 points.

Fix order matters: **(1) make contact decisive, (2) make bots seek contact, (3) gate the freebies,
(4) demote sudden death to a backstop.** Pillars touched: 2 (no camping — idle-hunt enforces it),
3 (chain hits are the comedy), 4 (death cheap & authored). Nothing here adds standable ground,
health bars, or HUD clutter.

---

## 1. Contact decisiveness

### 1.1 Tuning changes (`src/core/Tuning.gd` — exact names, current → new)

| Constant | Current | New | Rationale |
|---|---|---|---|
| `smash_impact_min` (**NEW** — move `Player.gd` const `IMPACT_MIN` into Tuning) | 800 (const) | **620** | `normal_boost_max_speed` = 760: a committed boost-ram vs a ~200 px/s drifter closes at ~560–760 and must register as a (light) smash. Passive trampoline bounces launch at ~930 px/s, so incidental crossings already exceeded 800 today — 620 adds *deliberate pokes*, not noise. |
| `smash_impulse_base` | 600 | **500** | With the lower gate, light hits must stay light. The base shrinks; the speed-scaled term carries the weight. |
| `smash_impulse_from_attacker` | 1.1 | **1.35** | The victim must exit meaningfully faster than the attacker arrived. Full-charge super at ~2400 px/s impact → impulse ≈ 500 + 2400×1.35 ≈ 3740, clamped by `max_speed` 3000 → victim launches at cap. A boost-ram at 760 → ~1525 launch: a real poke, not a kill. |
| `hitstun_base` / `hitstun_per_impulse` / `hitstun_max` | 0.15 / 0.00025 / 0.55 | **unchanged** | The recovery window is the skill heart (GDD §4.6, "protect this interaction"). At the 3000 cap a victim is helpless for ~1650px of travel — with the tightened bounds (§1.3) that's lethal from mid-stage, while a hit at the stage's far side still leaves a recovery gamble. Do not touch. |
| `smash_self_retain` | 0.1 | **unchanged** | Attacker stopping on impact is correct (you don't ride your victim off the edge). |
| `max_speed` | 3000 | **unchanged** | Cap = attacker's own super ceiling; raising it makes self-destructs unrecoverable too. |

### 1.2 Smash sting — hits now have a lasting cost (decided: YES, fuel drain; NO input lock)

**Every heavy smash bites a chunk out of the victim's tank.**

- **NEW `smash_sting_fuel = 30.0`** — on `receive_smash()` with `impulse.length() >=
  smash_sting_min_impulse`, victim fuel −30 (floored at 0), applied before hitstun.
- **NEW `smash_sting_min_impulse = 1500.0`** — boost-pokes (~1500 launch) sit right at the line;
  supers and hard chain-hits always sting; soft bumps never do.
- **NO fuel lock / input lock.** A lock would break GDD §4.6 ("a recovery *window* always exists")
  — ring-outs must come from momentum, not from disabled controls. The sting instead attacks the
  *fuel* side of the triad: hitstun → no mid-flight refuel → **now-smaller** tank for the recovery
  gamble. Banking fuel before a fight still pays (a full-tank victim survives one smash and it
  should); a half-tank victim who eats a super is nearly dry — the NEXT hit kills. This converts
  non-lethal hits (wall slams, floor saves) into visible attrition on the HUD fuel bar: every hit
  advances a kill.
- **Edge cases:** `invincible` / `_spawn_protect` early-outs skip the sting (already return before
  knockback). Counter-shield reflection stings the attacker (they got smashed — consistent).
  `_smash_cd = 0.3` already rate-limits sting spam. Sting fires on explosion knockback too (it
  routes through the same impulse path) — correct, bombs should scare people.

### 1.3 Body-contact momentum transfer (sub-threshold contact stops being invisible)

Replace `_soft_separate()`'s flat 300 px/s with a relative-speed-scaled shove:

- **NEW `soft_bump_scale = 0.4`**, **`soft_bump_min = 250.0`**, **`soft_bump_max = 550.0`** —
  push = `clamp(rel_speed * soft_bump_scale, soft_bump_min, soft_bump_max)` along the separation
  axis. Two blobs crossing paths now visibly shoulder-check each other (Pillar 3 chain-reaction
  texture) without triggering hitstun. No kill credit, no sting — it's a shove, not a hit.

### 1.4 Blast-zone tightening (`levels/dev_arena.json` — data, not code)

| Bound | Current | New | Rationale |
|---|---|---|---|
| `left` / `right` | −1000 / 2900 | **−620 / 2520** | Side runway drops ~1000px → ~660px past the stage edge. A stunned victim at ≥2000 px/s horizontal crosses before `hitstun_max` expires (0.55s × 2000 = 1100px) — a clean smash near the edge now KILLS. A player who merely drifts off in control recovers in <0.5s of boost (4600 px/s² accel) — the recovery gamble survives. |
| `top` | −1350 | **−950** | Spring + supercharge apex is ~y −400; 550px of headroom remains. A full vertical super (rise ≈ 2800²/2g ≈ 2450px) still self-destructs off the top — the comedy knob is untouched, just 400px sooner. |
| `bottom` | 1780 | **unchanged** | Floor spans the full stage; bottom ring-outs are rare and fine. |

Laser walls spawn at the new bounds — see §4 for their speed.

---

## 2. Bot intent overhaul (`InputBot.gd` + `BotProfile.gd`)

Bots keep playing by human rules (INV-8, no cheating). All changes are execution/intent quality.

### 2.1 New `BotProfile` dials (6) + retuned existing dials

| Dial | L1 | L2 | L3 | L4 | L5 | What it does |
|---|---|---|---|---|---|---|
| `aim_error` (rad) | 0.70 | 0.50 | 0.32 | **0.16** | 0.06 | (existing; L4 0.18→0.16) |
| `reaction_time` (s) | 0.50 | 0.38 | 0.28 | **0.16** | 0.10 | (existing; L4 0.18→0.16) |
| `recovery_skill` | 0.20 | 0.40 | 0.60 | **0.82** | 0.95 | (existing; L4 0.80→0.82) |
| `aggression` | 0.25 | 0.45 | **0.65** | **0.85** | 0.95 | (existing; L3 0.60→0.65, L4 0.78→0.85) |
| **`target_lead`** (0–1) | 0.0 | 0.15 | 0.5 | 0.85 | 1.0 | Aim at `target_pos + target_vel * (dist / expected_attack_speed) * target_lead` instead of current position. The single biggest hit-rate fix. |
| **`commit_time`** (s) | 0.0 | 0.4 | 0.8 | 1.3 | 1.5 | Once the hunt roll succeeds, `hunt` stays TRUE for this long — no re-rolling every reaction tick. L4 stops abandoning chases mid-flight. |
| **`attack_range`** (px) | 240 | 280 | 340 | 460 | 520 | Replaces hardcoded `dist < 280` super gate. |
| **`strike_fuel`** | 40 | 50 | 55 | 70 | 70 | Replaces hardcoded `fuel > 55`. L4/L5 *bank then strike* — their supers land at ~0.7+ fuel fraction = launch speeds that actually kill (§1.1 math). |
| **`edge_guard`** (0–1) | 0.0 | 0.0 | 0.3 | 0.7 | 0.9 | When an opponent is off-stage (outside `stage_rect()`, inside bounds) and this roll passes, pursue and smash them *outward* instead of waiting. Self-preservation gate: only while own `fuel >= 35` AND own position inside `bounds.grow(-250)` — guards must not become suicides. |
| **`leader_focus`** (0–1) | 0.0 | 0.0 | 0.25 | 0.6 | 0.8 | Target selection: with probability `leader_focus`, target the current score leader (via `arena.scores`) if within 1.5× `attack_range`; else nearest. At 0–0 or self-leading, falls back to nearest. Gives the score race a villain and keeps a lucky L2 honest. |

### 2.2 Behavior rules (implementable, dial-free)

1. **Aim-locked charge release** (replaces `_sb_hold = randf_range(0.45, 1.1)`): while charging,
   keep steering aim at the *led* target; release when the angle to the led target is within
   `aim_error * 0.5` **or** hold reaches 1.2s (forced release). Low-`target_lead` bots (L1/L2)
   still whiff constantly because their lead is wrong — the comedy survives, the freeze-and-pray
   doesn't.
2. **Bank-then-strike:** while hunting with `fuel < strike_fuel`, dive toward the nearest bounce
   surface (aim down-toward-stage, boost only if falling away from it) instead of drifting at the
   target. Produces the readable rhythm: bounce-bounce-bank → charge → BLAST.
3. **Punish passivity (all levels):** arena tracks per-player `secs_since_input` (reset on any
   boost/super press; ticking only during COMBAT). When a living player exceeds
   **`idle_hunt_after = 4.0`** (NEW, Tuning), the **nearest living bot** overrides its target
   selection with that player until they press boost/super. Even L1 flailing *at* the idler is
   correct — Pillar 2 says camping never pays, and passive bouncing is camping.
4. **Existing survival-first recovery loop is untouched** — `_danger_recover()` already works and
   is the reason bots stopped free-falling; edge-guard sits *behind* it in priority.

### 2.3 Per-level behavior targets (what QA should see)

- **L2 — the punchline (stays comedic, stops winning):** no nerf to its comedy (aim 0.5,
  recovery 0.40, suicides stay). It stops winning because its three income streams dry up:
  sudden-death point showers (<25% of rounds, §4), untouched-survivor points (§3), and nobody
  contesting its lucky leads (`leader_focus` on L4/L5 hunts any L2 that gets ahead). Zero
  `edge_guard`, near-zero `target_lead` = its kill rate stays a punchline.
- **L3 — the fair fight:** leads a little, commits a little, guards occasionally. A new human
  should trade rounds with it roughly evenly.
- **L4 — the menace:** banks to 70 fuel, leads shots at 0.85, commits 1.3s to a chase,
  edge-guards at 0.7, focuses the leader. The human should feel *hunted* whenever they're ahead.
- **L5 — reserved (campaign/hard mode):** all dials near max; not in the v0 lineup, but the table
  above ships so `bot_levels` stays hot-swappable.

---

## 3. Scoring guard — idle accrual

**Primary fix is §2.3 rule 3** (idle players get attacked — design-honest, Pillar 2). **Backstop
(also ships):**

- **NEW `survival_requires_contact = true`** (Tuning, bool): the survival point is only awarded if
  the survivor **dealt or received at least one smash** (a `smashed` event where they were attacker
  or victim; soft bumps don't count) during the round. Contact flags persist across a double-KO
  revive within the same round; reset at ROUND_INTRO.
- *Rationale:* kills already require contact by definition; this closes the last freebie. Counting
  *received* smashes keeps skilled evasion legal — surviving under fire scores, hiding untouched
  doesn't. Edge case: a 2-alive round where the rival insta-suicides with zero contact → survivor
  gets +0 (banner still names them; delta shows `+0`). Acceptable — show up to score.
- ROUND_END banner unchanged; the deltas line already communicates `+0` honestly.

---

## 4. Sudden death pacing — demote the lasers to a backstop

Target: **<25% of rounds ever reach SUDDEN_DEATH** (was 55–60%). §1 + §2 do the heavy lifting;
these changes cap the damage when SD does fire:

| Constant | Current | New | Rationale |
|---|---|---|---|
| `sudden_death_time` | 20.0 | **unchanged** | Lowering it would *raise* the share of laser-decided rounds. 20s stays the "you two cowards" line; combat lethality is what keeps rounds under it. |
| `laser_close_time` | 10.0 | **6.0** | Max combat clock drops 30s → 26s. Wall speed on the new bounds: ~1580px to center / 6s ≈ **263 px/s** — visibly scary, still dodgeable. |
| **NEW `laser_revive_start_frac`** | — | **0.4** | Double-KO revive path: lasers spawn **already 40% closed** (walls at ≈ the visible screen edges — immediately on-camera, solving half the visibility problem for free) and close over the remaining ≤3.6s. If lasers were already active and further than 40% (timer-SD then double-KO), keep the current positions: `frac = max(current, laser_revive_start_frac)`. |

**Revive-path timing fix (the 36.3s breach):** worst case is now double-KO at ~20s → 0.8s banner →
≤3.6s close → decided ≤ ~25s combat, ≤30s wall-clock BOUNCE→ROUND_END including freezes. Revived
players spawn at the **two spawn points nearest stage center** (never inside/behind a part-closed
wall). One revive max per round, unchanged.

---

## 5. SD wall visibility — edge warning flicker (decided: cheapest that reads)

Chosen over camera pull-back (camera is fixed single-screen by design, FEEL §7 — don't touch it).

- **NEW `sd_warning_lead = 3.0`** (Tuning): starting at `round_clock = sudden_death_time −
  sd_warning_lead`, two full-height **~24px translucent danger columns** (laser-red, on a
  CanvasLayer — two ColorRects, no shader) pulse at 2Hz (alpha 0.15 ↔ 0.45) at the screen's left
  and right edges. This is the "3s warning flicker" the round-loop spec §3 pre-authorized.
- At SD start the columns stop pulsing and become **wall trackers**: each column clamps to the
  screen edge while its laser is off-screen, then snaps onto the wall's real x once it enters the
  frame (the real wall render replaces/overlaps it). Players always know where death is.
- Revive path: no lead pulse needed (walls spawn at ≈ screen edges, instantly visible); trackers on.

---

## 6. Match-end readability

- **Backing panel:** MATCH_END banner + final scoreline + `A — REMATCH  B — QUIT` prompt sit on a
  single chunky rounded panel (Theme StyleBoxFlat: dark fill ~#141428 at **85% opacity**, corner
  radius ~24px, 48px padding, thin outline in the winner's color). Built in the .tscn as a scene,
  per studio UI rules. Text must be legible over ANY frozen chaos behind it.
- **Laser/SD cleanup:** on **ROUND_END entry**, free (not just halt) all SD nodes — laser walls,
  their glow/particles, and the §5 warning columns. QA screenshots MATCH_END: zero laser pixels.

---

## 7. New/changed constants — one block (implementation checklist)

```
# Tuning.gd — changed
smash_impulse_base          600  -> 500
smash_impulse_from_attacker 1.1  -> 1.35
laser_close_time            10.0 -> 6.0

# Tuning.gd — new
smash_impact_min        = 620.0   # was Player.gd const IMPACT_MIN=800; MOVE into Tuning (INV-6)
smash_sting_fuel        = 30.0
smash_sting_min_impulse = 1500.0
soft_bump_scale         = 0.4     # replaces hardcoded 300.0 in Player._soft_separate
soft_bump_min           = 250.0
soft_bump_max           = 550.0
laser_revive_start_frac = 0.4
sd_warning_lead         = 3.0
idle_hunt_after         = 4.0
survival_requires_contact = true

# BotProfile.gd — new dials (per-level values in §2.1 table)
target_lead, commit_time, attack_range, strike_fuel, edge_guard, leader_focus

# levels/dev_arena.json — bounds
left -1000 -> -620 · right 2900 -> 2520 · top -1350 -> -950 · bottom unchanged

# Arena — expose for QA (read-only via eval)
round_stats: per-round {length_s, end_cause, entered_sd, kills[], survivor_had_contact}
```

---

## 8. Success criteria (QA-verifiable via gbplay eval + screenshots)

Sample harness: 10-round bot-driven sample = standard lineup with P1 given an L3 bot brain via
eval; "idle match" = P1 untouched. Arena must expose `round_stats` (§7).

**Lethality & pacing**
1. **Kills carry the game:** across the 10-round sample, **≥70% of rounds end by ring-out/hazard
   kill with `round_clock < 20s`** (`end_cause != "laser"`, `entered_sd == false`).
2. **SD is rare:** **≤25% of rounds** ever enter SUDDEN_DEATH (was 55–60%).
3. **Round length:** median combat length (BOUNCE→decided) **10–22s**; every round decided by
   combat clock **≤26s** and wall-clock BOUNCE→ROUND_END **≤30s** — including one QA-forced
   double-KO revive round (this retests the 36.3s breach).
4. **Decisive-hit micro-test:** eval-place a no-input victim (40 fuel) at stage center and a
   scripted attacker 400px away; attacker fires a full-tank, full-charge super flat at the victim →
   **victim dies by ring-out within 2.5s in ≥7/10 trials**. Repeat with victim at 100 fuel + a
   scripted stun-end counter-boost → **victim survives in ≥3/10** (the GDD §4.6 recovery window
   still exists — if this fails, lethality went too far; dial `smash_impulse_from_attacker` down,
   not hitstun up).
5. **Sting:** a qualifying smash (impulse ≥ 1500) drops victim fuel by exactly `smash_sting_fuel`
   (eval before/after); a soft bump changes fuel by 0; a spawn-protected victim takes no sting.

**Skill hierarchy**
6. **L4 > L2:** across **5 full idle-P1 matches** (standard [2,3,4] lineup), **L4 finishes above
   L2 in ≥4/5 matches and L2 wins 0/5**. L2 still suicides ≥1×/match (comedy regression check).
7. **Idle human punished:** in a full idle match, **P1 total score ≤2**, and P1 receives a smash
   within **8s of BOUNCE in ≥70% of rounds** (idle-hunt firing).
8. **Edge-guarding observable:** in the 10-round sample, **≥3 kills where the killing smash
   connected while the victim was off-stage** (log flag in `round_stats.kills[]`).

**Sudden death & readability**
9. **Warning reads:** in a QA-stalled round, a screenshot at `round_clock ≈ 18s` shows the pulsing
   edge columns; at ≈20.5s shows the SD banner + wall trackers/walls.
10. **Revive path:** forced double-KO → eval wall positions show **≥40% closed on the revive
    frame**, both revived players spawn between the walls, and the round is decided **≤5s after
    revive**.
11. **MATCH_END clean:** screenshot shows the backing panel behind banner/scoreline/prompt (text
    legible) and **zero laser/warning-column pixels**.
12. **Survival gate:** eval-force a round where the survivor had no smash dealt/received → survivor
    score unchanged (+0); a survivor who was hit once still gets +1.

**Regressions (must still hold from v0_round_loop.md)**
13. Round turnaround last-death→next BOUNCE ≤4.5s; 60fps criterion (avg ≥55, no hitch >100ms)
    during a smash-heavy round; countdown lock and no-mid-round-respawn unchanged.

## Out of scope

Powerup rebalance, new arenas/arena geometry beyond the `bounds` numbers, audio announcer, L5 in
the default lineup, any hitstun/recovery-window changes (§4.6 triad is protected), camera changes,
online. If criteria 1–3 pass but rounds now feel *too* short (<8s median), the first knob back is
`smash_impulse_from_attacker` 1.35 → 1.2 — not the bot dials.
