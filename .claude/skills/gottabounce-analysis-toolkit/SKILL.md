---
name: gottabounce-analysis-toolkit
description: First-principles analysis recipes for GottaBounce — run these BEFORE implementing or approving any spec that touches speed thresholds, contact rules, kill credit, or the fuel economy. Triggers - "is this gate reachable", "will this constant change break X", reviewing or approving a spec that changes kill credit / thresholds / contact rules, designing a course around fuel math, doing the first-principles credit/reachability audit AFTER a live symptom like kills-not-landing / wrong-player-scored / farming is already triaged, or any time you are about to change a Tuning.gd constant and want to know what it will do first. For LIVE triage of those symptoms (game misbehaving right now), load gottabounce-debugging-playbook FIRST — this skill is pen-and-paper analysis, not live debugging. NOT for running the measurements themselves (see gottabounce-diagnostics-and-tooling), the feel-tuning campaign plan (see gottabounce-feel-campaign), or game-feel theory background (see game-feel-reference).
---

# GottaBounce analysis toolkit — prove it before you install it

**What this covers:** six pen-and-paper analysis recipes — reachability audits, frame-order
reasoning, feel-math derivations, prediction-first tuning, credit audits, economy-loop audits —
each with a worked example from this repo's actual bug history. These are the checks that would
have caught every major combat bug in this project *before* it shipped.
**When NOT to use this:** to run live measurements (→ `gottabounce-diagnostics-and-tooling`), to
plan the feel campaign end-to-end (→ `gottabounce-feel-campaign`), for the underlying game-feel
theory (→ `game-feel-reference`), for the full constant catalog (→ `gottabounce-tuning-and-flags`),
or for symptom-driven triage of a live bug (→ `gottabounce-debugging-playbook`).

**Jargon used below (defined once):**
- **hitstun** — a timed no-control state (`_stun_timer` in `src/entities/Player.gd`) applied by a
  smash; input is zeroed while it ticks.
- **smash license** — the eligibility to inflict a SMASH (hitstun + launch): only a recently-fired
  super (`_super_recent > 0`) or a currently-stunned flying body qualifies. Everything else SHOVEs.
- **closing speed** — `(attacker.velocity - victim.velocity).length()`, the relative speed gate.
- **sting** — a qualifying smash chunks the victim's fuel by `smash_sting_fuel` before hitstun.
- **DI (directional influence)** — holding a direction during a bounce nudges the launch
  (`bounce_di`).
- **SD (sudden death)** — laser walls activate after `sudden_death_time` seconds of combat.
- **drain-all** — firing the super always sets fuel to 0 regardless of tank level.
- **tps** — physics ticks per second; this project runs **120** (`project.godot`
  `common/physics_ticks_per_second=120`), so one physics frame ≈ 8.3 ms.
- **ring-out** — death by crossing the level `bounds` (the blast/kill line).

## When to run which recipe

| You are about to... | Run recipe |
|---|---|
| Add/change any speed, impulse, or threshold constant | 1 (reachability), 4 (prediction-first) |
| Add/change a contact rule, license, or state flag | 2 (frame-order), 1 |
| Design a movement course or set a gap/height/par | 3 (feel math) |
| Change any Tuning constant at all | 4 (prediction-first) — mandatory |
| Touch kill credit, scoring, or `last_attacker` | 5 (credit audit) |
| Add/change any fuel source or sink | 6 (economy audit) |
| Review a spec before implementation ("spec touches thresholds/credit/economy") | all that apply — this is the pre-build gate |

Findings from these recipes go into the spec review or QA report, then through
`gottabounce-change-control` like any other change. None of these recipes require launching the
game — that is the point. Measurement to confirm a prediction comes after, via
`gottabounce-diagnostics-and-tooling`.

---

## Recipe 1 — Reachability / inequality audit

**When:** any constant that gates behavior by comparing two numbers (speed vs threshold, fuel vs
minimum, pull vs thrust). **The founding bug of this project was a failed reachability audit.**

**Method:**
1. List every gate: `grep -n ">=\|<=\|min\|max" src/core/Tuning.gd` comments plus the actual
   comparisons in `src/entities/Player.gd` (`_handle_smashes`, `receive_smash`) and the specs'
   tuning blocks.
2. For each gate, enumerate every *intended* path that should pass it, and compute the maximum
   value each path can actually produce from live `Tuning.gd` constants.
3. Check both directions: (a) every intended path CAN pass the gate; (b) no unintended path can.
4. Write the inequality down explicitly with numbers. If a spec says "X should trigger Y",
   the audit output is a line like `path_max (760) < gate (800) → UNREACHABLE — spec broken`.

**Worked example (the founding bug, session 2, spec commit `d262686`):** the old smash gate was a
hardcoded `IMPACT_MIN = 800` in Player.gd, while `normal_boost_max_speed = 760`. A deliberate
boost-ram could never exceed 760, so **the kill gate was mathematically unreachable by the game's
main attack** — kills only happened by accident ("traffic accidents", lasers decided ~60% of
rounds). One inequality on paper (`800 > 760`) would have caught it before a single playtest.
Fixed by the lethality v2 redesign (`03894ac`): the gate moved to Tuning as
`smash_impact_min = 900` and reachability now comes from the *license*, not raw boost speed.

**The current audit (as of 2026-07-03, all values from `src/core/Tuning.gd`) — rerun this table
whenever any of these constants change:**

| Gate | Intended pass paths (computed) | Must-NOT-pass paths | Verdict |
|---|---|---|---|
| `smash_impact_min` 900 (closing speed, licensed attackers only) | super launch adds 2800 → arrives 2200–2800 inside its 0.45 s window ✓; stunned body launched at `max_speed` 3000 ✓ | plain boost caps at 760 alone — but note the gate is on *relative* speed: two head-on boost-rams reach rel ≈ 1520 > 900. They still can't smash because they fail the **license** predicate. The speed gate alone is NOT the protection. | REACHABLE by intended paths only |
| Passive tier crossings vs 900 | trampoline launch = √(2·1600·270) ≈ 930 px/s and spring ≈ 1239 px/s — both EXCEED 900 | passive bouncers must never smash | safe only via the license predicate — never weaken it to a pure speed gate |
| `super_boost_min_fuel` 5 vs `fuel_per_bounce` 20 | one bounce always re-arms a super (20 ≥ 5); invariant written in Tuning.gd: keep `fuel_per_bounce ≥ 2× super_boost_min_fuel` | — | HOLDS (20 ≥ 10) |
| Sting-starve loop | `smash_sting_fuel` 30: a 34-fuel victim → 4 < 5 → no escape super. This is the *authored* kill loop, intentionally reachable | full-tank victim: 100−30 = 70 ≥ 5 → counter-super survives | HOLDS both directions |
| `smash_sting_min_impulse` 1500 | supers: 500 + ~2500·1.35 ≈ 3875 ✓ sting | Star contact (900) and Counter reflect (1400) sit below 1500 **by data** — powerups launch, they don't starve | HOLDS (900 < 1400 < 1500) |
| `pu_black_hole_pull` 2600 < `normal_boost_accel` 4600 | a fueled player must be able to fight out of the pull | — | HOLDS (comment in Tuning.gd line ~152 documents the invariant) |
| `max_speed` 3000 vs super impulse 2800 | a super launch must not be flattened by the cap from rest | smash impulse ~3875 IS clamped to 3000 — intentional ("every clean super launches at cap") | HOLDS |

**What a finding looks like:** "`<gate>` is unreachable by `<intended path>` because
`<path max>` < `<gate>` at live values — spec §N's promised behavior cannot occur." File it
against the spec before build, not as a QA surprise after.

---

## Recipe 2 — Frame-order / state interaction analysis

**When:** any contact rule, license predicate, or state flag that two bodies read of each other.
Physics runs per-body in tree order at 120 tps; a state you set on the victim THIS frame is live
input to the victim's own `_physics_process` NEXT frame (or even later this same frame).

**Method:**
1. Identify the two (or three) bodies and every state flag the rule reads/writes:
   `_stun_timer`, `_stunned_by`, `_super_recent`, `_smash_cd`, `velocity`, `last_attacker`.
2. Build a frame table: columns = bodies, rows = frame N, N+1, N+2. Fill in each flag's value
   after each body's `_physics_process` runs.
3. Evaluate the license predicate for EVERY body against every other body at every row — not just
   the pair you designed the rule for. The predicate at `Player.gd::_handle_smashes()` is:
   `(_super_recent > 0.0 OR (_stun_timer > 0.0 AND b != _stunned_by)) AND rel >= smash_impact_min
   AND attacker-is-faster`.
4. Ask "who is faster?" explicitly — after a smash the victim exits at `max_speed` cap while the
   attacker keeps only `smash_self_retain` (0.1) of their momentum. Speed asymmetry flips who the
   tiebreak favors one frame later.

**Worked example (the inverted-kill bug — CRITICAL, found by QA on lethality v2, fixed
`587d0a1`):**

| Frame | Attacker A | Victim B | Predicate check |
|---|---|---|---|
| N | fires super, `_super_recent` 0.45, hits B; then `velocity *= 0.1` → ~300 px/s | `receive_smash`: `_stun_timer` ≈ 0.55, velocity → 3000 (cap) | A smashes B — intended |
| N+1 (pre-fix) | slow, still overlapping B | stunned + flying = **licensed smasher**; rel ≈ 2700 ≥ 900; B is faster | **B smashes A** — landing a super was suicide. Attacker died 9/9, victim survived 10/10, chains worked 0/3 |
| N+1 (post-fix) | — | `b != _stunned_by` fails: B's stunner IS A | no smash; B smashing a third player C still works (Pillar-3 chains kept) |

The fix (`_stunned_by` pairwise smash immunity, `Player.gd` ~line 616) is surgical because the
frame table showed exactly which cell was wrong: the license was correct for B-vs-C and wrong only
for B-vs-its-own-stunner. `_stunned_by` clears when hitstun expires by time
(`_physics_process` ~line 315) and on respawn.

**Second application of the same method (v2.1 dry-reflect, 2026-07-03):** walk a smashed victim's
frames toward the kill line: frame N smash (stunned, flying at cap) → frame N+k bumper contact.
Pre-v2.1, `_on_bounced()` unconditionally cleared `_stun_timer`/`_stunned_by` and refunded fuel —
so the frame table showed the victim exiting hitstun *by surface contact*, mid-flight, ~660 px
before the blast line. That row is the whole bug. See recipe 6 for the economy half.

---

## Recipe 3 — Feel-math derivations

**When:** designing course geometry, setting gaps/heights, predicting how a constant change moves
the physical envelope. All from live `Tuning.gd` (gravity 1600 px/s², char height H ≈ 110 px).

**Core formulas:**
- **Bounce launch speed:** `v = sqrt(2·g·h)` — implemented verbatim in
  `src/core/BounceResolver.gd::resolve()`. Tier ladder at g = 1600:
  marshmallow 120 → ~620 px/s · bubblegum 180 → ~759 · trampoline 270 → ~930 · spring 480 → ~1239.
- **Hang time:** rise `t = v/g`; full up-and-back ≈ `2v/g`. Trampoline: ~0.58 s up, ~1.16 s total.
- **Aim-hover decay:** while aiming, `velocity *= (1 − super_aim_damp·delta)` per tick
  (`Player.gd` ~line 360) ≈ exponential `v(t) = v₀·e^(−2.5t)`. After 0.3 s: ×0.472
  (3000 → ~1417; 400 → ~189 — the spec §1.3 table reproduces from this).
- **Aim-hover terminal sink rate:** damp balances scaled gravity at
  `v_term = (super_aim_gravity·gravity)/super_aim_damp = (0.25·1600)/2.5 = 160 px/s` — a 2 s aim
  sags ≤ ~300 px. This is why aiming reads as "hover", not "fall".
- **Fuel-distance budget:** drain = `fuel_max/tank_seconds` = 100/3.5 ≈ 28.6 fuel/s; at
  `normal_boost_max_speed` 760 that is ≈ 26.6 px/fuel top-speed, less while accelerating →
  plan on **20–26 px per fuel unit** flat-out. A 900 px gap costs ~40 fuel; a bounce refunds 20.
- **Smash hitstun duration:** `min(hitstun_base + impulse·hitstun_per_impulse, hitstun_max)` —
  a clean super (impulse ≈ 3875) saturates at 0.55 s; at cap speed that is ~1650 px of helpless
  flight. This is the number the blast-zone bounds are tuned against.
- **Bumper ricochet:** speed × `bumper_restitution` 0.86, reflected (`resolve_bumper`); tangential
  momentum across tier bounces keeps `tangential_retention` 0.98 per bounce.

**Worked examples (both from `docs/specs/v1_movement_courses.md`, specced NOT built as of
2026-07-03):**
- **Tank Run (course 1):** gaps 700/800/900/1000 px against the 20–26 px/fuel budget force
  double-bouncing pads (bank +40) — greedy continuous boost runs dry ~platform 4 *by arithmetic*,
  which is the F1 fail-script's job to confirm. Final 1600 px gap > any boost budget → super
  required (2800 px/s launch).
- **The Chimney (course 2):** 4000 px tall vs a full-tank continuous climb of ≈ 3100 px
  (760 px/s × 3.5 s + coast apex ≈ v²/2g ≈ 180 px + starting bounce) — "too tall to fly" is an
  inequality, re-check it if boost constants change. Interior gap 420 px at 2800 px/s ≈ 0.15 s
  wall-to-wall; each wall bounce refunds 20 ≥ min-fuel 5, re-arming the next super. Hesitating in
  aim costs altitude at the 160 px/s sink rate — the skill pressure is derived, not decreed.

Theory behind these (why sqrt(2gh), why restitution < 1, DI, the fuel-economy design intent) →
`game-feel-reference`.

---

## Recipe 4 — Prediction-first tuning

**When:** EVERY Tuning constant change. Non-negotiable discipline: write the predicted metric
delta down BEFORE touching the value, then measure. If you can't predict a number, you don't
understand the change yet — go back to recipes 1–3.

**Method:**
1. State the change: `constant: old → new`.
2. Derive the expected effect via recipes 1–3 (which inequalities flip? which envelope moves?).
3. Write a falsifiable prediction against a measurable: SD %, end-cause mix, median combat
   length, kill counts, course pass/fail — the `round_stats` surface
   (→ `gottabounce-diagnostics-and-tooling` for how to pull it).
4. Measure. A result matching the prediction is evidence FOR your model; a mismatch means your
   model of the game is wrong — investigate before iterating the constant again
   (→ `gottabounce-research-methodology` for the evidence bar).

**Worked example (lethality v2):** the spec predicted the SD rate would fall from the measured
55–60 % to **< 25 %** because §1–§3 restored a reachable kill move. The implementation smoke run
(8-round bot match, commit `03894ac`, recorded in `docs/STATUS.md`) measured **12.5 % SD
(7 ring-out / 1 laser)** — prediction confirmed, and the confirmation is what earned the change
its commit. Contrast: fix-round `587d0a1` shipped `fuel_per_bumper` with *no* predicted
match-stat delta — and its unpredicted side effect (recipe 6) cost a full QA re-verification
cycle and a spec amendment.

**Fallback knobs are pre-registered predictions too:** the lethality spec §8/§10 ranks them
(rounds too short → `smash_impulse_from_attacker` 1.35→1.2, then `super_refire_lockout` 0.25→0.5;
kills too rare → `smash_sting_fuel` 30→40, then `soft_bump_max` up; NEVER hitstun up, NEVER super
power scaling). Use only those knobs in that order — catalog and statuses in
`gottabounce-tuning-and-flags`.

---

## Recipe 5 — Credit / attribution audit

**When:** anything touching kill credit, scoring, or `last_attacker`. The scoring system is a
small economy of blame; leaks become farms.

**Method:**
1. Enumerate every SETTER and CLEARER of credit state. As of 2026-07-03 in
   `src/entities/Player.gd`: set by `receive_smash()` (~line 698), `receive_counter_launch()`
   (~line 722), `credit_attacker()` (~line 731, used by Ring of Fire, shove-credit, chain-credit);
   cleared by the `_attacker_timer` expiry (`kill_credit_window` = 2.5 s, ~line 288) and respawn
   (~line 812: "a new life never owes kill credit to the old one").
2. Trace every death path to who gets the point: `kill(cause, attacker)` (`src/entities/Player.gd:788`)
   falls back to `last_attacker` for hazard/ring-out deaths (`attacker = last_attacker` at line 790).
3. For each path, ask two questions: **(a) farm** — can a player accrue credit for outcomes they
   didn't author? **(b) leak** — can an authored kill read as a suicide/no-credit?
4. Check the uncontrolled-projectile case explicitly: who is credited when a *stunned body*
   (not its launcher) delivers the final contact?

**Worked example (idle point-farming, found by QA, fixed `587d0a1`):** chain-body kills credited
the flying body itself — a player who never pressed a button got credit whenever their smashed
body happened to carry someone out. **Idle P1 scored 12 points** (commit message `587d0a1`) —
and combined with the inverted-kill bug, idle P1 *won a match*. Fix: in `_handle_smashes()`
(~lines 627–631), when a stunned body smashes someone, `credit_attacker()` reassigns credit to
`_stunned_by` (the launcher). Post-fix verification: chain credit to launcher 4/4, and a fresh
idle match scored P1 = 0.

**The leak side (also shipped):** a strong shove that carries someone over the line credits the
shover via `shove_credit_min_rel` = 500 (`_soft_separate()`, ~line 663) — without it a lethal
body-check read as the victim's suicide, a rage generator. Audit BOTH directions every time.

---

## Recipe 6 — Economy loop audit

**When:** adding or changing any fuel source or sink. Fuel is the game's only resource; a
degenerate loop in it warps every fight.

**Method:**
1. Table every source and sink WITH the state it applies in. As of 2026-07-03:

| Flow | Amount | State condition (the column that catches bugs) |
|---|---|---|
| Tier bounce refund | `fuel_per_bounce` 20 × sqrt(tier/270) | only if NOT in opponent-inflicted hitstun (v2.1 dry-reflect rule) |
| Bumper refund | `fuel_per_bumper` 20 | same hitstun gate (v2.1) |
| Normal boost drain | 28.6/s | while boosting, not `fuel_locked` |
| Super fire | ALL fuel → 0 | drain-all identity — do not change to a flat cost (DECISIONS 2026-07-02) |
| Smash sting | −30 | victim of impulse ≥ 1500, not `fuel_locked` |
| Respawn / round reset | refill | — |

2. For each source, ask: can a player harvest it in a loop with no opposing cost? For each sink,
   ask: can a player be locked out of the game entirely (no counter-play)?
3. Cross-check against recipe 2: does the source/sink change any STATE (stun, license, timers)
   as a side effect? A refund that also clears a combat state is two changes, not one.
4. Write the loop out as a cycle diagram in words: "miss → bumper (+20, reflect) → re-aim → fire
   (−all) → ..." and check each arrow's cost/gain against the intended rhythm ("surfaces are the
   combo system": every super chain must route through a bounce).

**Worked example (the bumper-save loop — the full arc, and this project's best cautionary tale):**
1. *The gap:* dry bumper rebounds made the owner's signature wall-return shot (miss → wall →
   return super) impossible — a legitimate finding.
2. *The fix that overshot (`587d0a1`):* `fuel_per_bumper` = 20 routed through `_on_bounced()` —
   which ALSO unconditionally cleared hitstun. Two changes disguised as one (recipe step 3
   violation). Flagged as a watch item at commit time.
3. *The degenerate loop it created (confirmed by QA re-verification, 2026-07-03):* bumpers sit
   ~660 px inboard of the kill line, so every smashed victim flying toward an edge clipped a
   bumper and was instantly un-stunned + refueled + reflected to safety. Edge kills became
   structurally un-earnable: test 15 measured **1 off-stage kill in 23 rounds** (target ≥ 3/10),
   dragging SD % (27–33 % vs ≤ 25), L2 win-rate, and idle-punishment with it — four criteria
   FAILs, one economy loop.
4. *The ruling (spec v2.1 §2.3a, commit `ea0c133`, DECISIONS 2026-07-03):* **hitstun ends by
   TIME, never by touching a surface.** While `_stun_timer > 0`, any surface contact is a dry
   reflect — physics + FX resolve, zero refund, no stun clear. `fuel_per_bumper` stays 20 (the
   number was never the bug; the state condition was). The wall-return shot survives by
   construction: it never involves hitstun.
5. *Status as of 2026-07-03:* ruling committed; the code fix exists in `Player.gd::_on_bounced()`
   (the `if _stun_timer <= 0.0:` gate) but was still an **uncommitted working-tree change** when
   this skill was written — verify before relying on it (command in Provenance). Spec §9 tests
   6c/6d lock the behavior in; targeted re-run of tests 11/13/14/15 is required
   (→ `gottabounce-feel-campaign`).

**Standing watch question for this recipe:** does `fuel_per_bumper` = 20 create a wall-hug
economy (farming bumpers instead of tiers)? Neutral-state bumper farming is currently identical
in payout to tier farming and bumpers don't lift you (restitution 0.86 reflect vs a tier's
sqrt(2gh) launch), so the loop looks non-degenerate on paper — but no measured verdict exists.
UNVERIFIED: no live data on bumper-vs-tier refuel usage rates.

---

## Full incident narratives, verdict labels, and what is settled vs open →
`gottabounce-failure-archaeology`. What counts as evidence for closing a finding →
`gottabounce-validation-and-qa`.

## Provenance and maintenance

Written 2026-07-03 against working tree at HEAD `0e315b9` (note: three commits newer than the
2026-07-03 charter that requested this skill — the QA re-verification was completed and the v2.1
ruling landed between charter and authoring). All constants, code lines, and incident numbers
verified by direct read of the repo; nothing in this file was taken from the charter on trust.
All claims are **verified: static** (no live game runs were performed).

Verified sources: `src/core/Tuning.gd` (every constant cited), `src/entities/Player.gd`
(`_handle_smashes`, `receive_smash`, `receive_counter_launch`, `_on_bounced`, `_soft_separate`,
`credit_attacker`, `_fire_super`, stun/credit timers), `src/core/BounceResolver.gd`,
`project.godot` (120 tps, main scene), `docs/specs/v0_combat_lethality.md` v2.1,
`docs/specs/v1_movement_courses.md`, `docs/STATUS.md`, `docs/DECISIONS.md`, and commit messages
`d262686`, `03894ac`, `587d0a1`, `ea0c133` via `git show`.

Drift-prone facts — one-line re-verification each:
- Live constant values (all of recipe 1's table):
  `grep -n "smash_impact_min\|normal_boost_max_speed\|super_boost_min_fuel\|fuel_per_bounce\|fuel_per_bumper\|smash_sting\|pu_black_hole_pull\|max_speed" src/core/Tuning.gd`
- Dry-reflect fix committed yet?
  `git log --oneline -1 -- src/entities/Player.gd` (fix is in if the newest commit is later than
  `ea0c133` and `git diff --stat src/entities/Player.gd` is empty; the code marker is
  `if _stun_timer <= 0.0:` inside `_on_bounced`)
- License predicate unchanged: `grep -n "_super_recent > 0.0 or (_stun_timer" src/entities/Player.gd`
- Credit window & chain credit: `grep -n "kill_credit_window\|credit_attacker" src/core/Tuning.gd src/entities/Player.gd`
- Physics tick rate: `grep -n "physics_ticks_per_second" project.godot`
- Movement courses still unbuilt: `ls levels/courses/ 2>nul` (spec'd in
  `docs/specs/v1_movement_courses.md`; no course files existed 2026-07-03)
- Current QA/ship state: read `docs/STATUS.md` "Session 3 progress" tail + NEXT STEPS.

UNVERIFIED items (labeled inline above):
- Bumper-vs-tier refuel usage rates (wall-hug economy watch) — no measurement exists.
- Chimney "full-tank climb ≈ 3100 px" is the spec's figure; my arithmetic reproduces its order of
  magnitude but it has never been measured in-game (courses unbuilt).
- All lethality v2.1 expected test outcomes (6c/6d, re-runs of 11/13/14/15) are spec predictions,
  not measurements, as of 2026-07-03.
