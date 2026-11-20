---
name: gottabounce-feel-campaign
description: >-
  The executable, decision-gated campaign for GottaBounce's hardest live problem: taking
  movement/combat feel to the TowerFall Ascension bar. Load this when you are asked to "continue
  the feel work", "finish the lethality sign-off", "run the 21 QA criteria", "build the movement
  courses", "tune the super / bounce / fuel constants", or when STATUS.md NEXT STEPS points at
  lethality QA or movement courses. Do NOT load this for command syntax of run_game/gbplay (use
  gottabounce-run-and-playtest), for metric-extraction scripts (use
  gottabounce-diagnostics-and-tooling), for generic evidence doctrine (use
  gottabounce-validation-and-qa), or for the meaning of individual constants (use
  gottabounce-tuning-and-flags).
---

# GottaBounce feel campaign — lethality sign-off → movement courses → tuning loop → promotion

**What this covers:** the phased, gated plan that takes combat/movement feel from its state at
HEAD `0e315b9` (2026-07-03) to "TowerFall bar met", with exact commands, expected observations,
and failure branches at every gate.
**When NOT to use this:** how to launch/drive the game → skill `gottabounce-run-and-playtest`;
how to measure (round_stats interpretation, perf, ready-made scripts) →
`gottabounce-diagnostics-and-tooling`; what counts as evidence and how QA verdicts are filed →
`gottabounce-validation-and-qa`; per-constant meanings/guards → `gottabounce-tuning-and-flags`;
past incidents in depth → `gottabounce-failure-archaeology`; change gates and commit discipline →
`gottabounce-change-control` (EVERY phase below routes through it).

## Jargon (defined once)

| Term | Meaning here |
|---|---|
| **hitstun** | Timed loss of control after a SMASH (`_stun_timer` in `src/entities/Player.gd`). Triad `hitstun_base/per_impulse/max` is DO-NOT-TOUCH. |
| **SMASH vs SHOVE** | Two-tier contact (spec §2.1): SMASH = knockback+hitstun+sting+kill credit, licensed only to super-active attackers and stunned flying bodies at closing speed ≥ `smash_impact_min` (900); everything else is a SHOVE (momentum push, no hitstun). |
| **smash license** | The eligibility predicate above — who is ALLOWED to smash. |
| **sting** | A qualifying smash chunks victim fuel by `smash_sting_fuel` (30); sting → starve → kill is the authored kill loop. |
| **dry reflect** | v2.1 ruling (spec §2.3a, DECISIONS 2026-07-03): surface contact while in opponent-inflicted hitstun still ricochets physically but refunds ZERO fuel and does NOT clear hitstun. "Hitstun ends by TIME, never by touching a surface." |
| **SD** | SUDDEN_DEATH — laser walls at `sudden_death_time` 20s; the backstop, never the executioner (target ≤25% of rounds). |
| **ring-out** | Death by crossing the level `bounds` (dev_arena: left −620 / right 2520 / top −950 / bottom 1780). |
| **DI** | Directional influence — holding a direction during a bounce nudges launch (`bounce_di` 260). |
| **P/F scripts** | Pre-registered pass/fail input scripts for a movement course. The F(ail) script MUST fail — it proves the course tests something. |
| **parse gate** | `--headless --path . --editor --quit` + grep for parse errors. A crash gate, never a sign-off. |
| **TowerFall bar** | Owner thesis (`docs/feedback/owner_2026-07-02_movement_feel.md`): movement feel IS the product; "did I feel capable and cool, and were failures my fault?" |

## Campaign state at 2026-07-03 (verify before acting — this is the most volatile section)

- Lethality spec is at **v2.1** (`docs/specs/v0_combat_lethality.md`, commit `ea0c133`): the QA
  re-verification that a prior charter called "interrupted / unresolved" is **SETTLED** — the
  pacing anomaly was the dead agent's mis-hooked recorder, NOT a bot regression (fresh sample:
  54 supers in round 1; STATUS commit `e57db01`). Do not re-litigate; history lives in skill
  `gottabounce-failure-archaeology`.
- QA re-verification verdict: **core hinge PASSES** (6a kill 9/10, 6b counter-escape 10/10,
  test 9 chain credit 6/6, test 10 borderline 72.7%, test 12 median 15.0s) but **4 FAILS from one
  root cause**: 587d0a1 made `_on_bounced()` unconditionally refund fuel + clear hitstun, so a
  bumper ~660px inboard of the kill line auto-saved every edge-bound victim → tests 15 (edge
  kills 1/23), 11 (SD 27–33%), 13 (L2 won 1/5), 14 (idle P1 scored 3) failed.
- The designer ruling (§2.3a dry reflect) is committed as SPEC + DECISIONS entry. The **code fix
  exists in the working tree of `src/entities/Player.gd` but is UNCOMMITTED at HEAD `0e315b9`**
  (as of 2026-07-03; another session may land it — Phase 0 step 1 checks).
- Lethality v2.1 overall: **implemented, NOT signed off.** Movement courses: **specced, NOT
  built** (no `levels/courses/` dir exists). Goat identity: **adopt-STAGED, gated** on this
  campaign's Phase 4.
- Re-verify this whole block with: `git log --oneline -5` + `git status --short` + read
  `docs/STATUS.md` NEXT STEPS. STATUS outranks this skill when they disagree.

Operating rules for every phase: one game instance at a time (port 9090 is exclusive — see skill
`gottabounce-run-and-playtest`); every commit routes through `gottabounce-change-control`
(reviewer pushback, STATUS.md update after every commit); every verdict needs evidence per
`gottabounce-validation-and-qa` (screenshots + measured numbers vs numbered criteria, never
"looks fine").

---

## PHASE 0 — Land and verify the §2.3a dry-reflect fix (the live blocker)

Goal: the four re-scoped FAILs (tests 11/13/14/15) pass, the two new criteria (6c/6d) pass, and
the fix is committed. Nothing else in the campaign may start first (depth-first rule).

**Step 0.1 — Establish code state.**
```
git -C "D:\Projects\GottaBounce" log --oneline -3
git -C "D:\Projects\GottaBounce" status --short
```
Then read `src/entities/Player.gd` `_on_bounced()` (~line 550). Expected (fix present): the fuel
refund, `_supercharge_timer`, and `_stun_timer = 0.0` / `_stunned_by = null` lines are all inside
an `if _stun_timer <= 0.0:` branch; squash FX + `EventBus.bounced`/`bounced_juicy` emits stay
unconditional below it.
- If you see the OLD body (unconditional refund + stun clear) → implement exactly the §8 comment
  block of `docs/specs/v0_combat_lethality.md` (branch on `_stun_timer > 0.0` at entry; NO new
  Tuning constants; applies uniformly to both call sites — tier ~line 493, bumper ~line 502).
- If the fix is present but uncommitted → it is yours to verify and commit (coordinate via
  STATUS; do not assume another session will).

**Step 0.2 — Parse gate** (only needed if you edited code; always cheap insurance):
```
C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe --headless --path . --editor --quit
```
(run via the Bash tool with `dangerouslyDisableSandbox: true`; then grep output for
`Parse Error|hides a native|Failed to load script|not declared`). Expected: no matches.

**Step 0.3 — Targeted micro-tests 6c/6d** (spec §9; exact setups there). Launch rendered:
```
powershell -File tools/run_game.ps1
python tools/gbplay.py eval "return get_tree().current_scene.scene_file_path"
```
Expected: `res://scenes/Arena.tscn` (the wrong-project-on-9090 trap — see
`gottabounce-run-and-playtest`). Then:
- **6c (dry-reflect kill retained):** stage a 4-fuel no-input victim whose smash arc crosses a
  bumper before the kill line. On bumper contact, eval the victim: `fuel` still 4 (no refund),
  `_stun_timer` > 0 and `_stunned_by` unchanged; victim rings out ≤2.5s in **≥8/10**.
- **6d (wall-return shot preserved):** NON-stunned player fires a super, misses, holds super,
  contacts a bumper → `fuel` reads 20 within one physics frame, second AIM starts ≤0.35s later
  at full launch speed, **≥9/10**.
Staging players and reading private fields is done via `gbplay eval` (code is wrapped in a
function — you MUST `return` a value; GDScript allows `;`-separated statements on one line).
Setup recipes and field-reading snippets: skill `gottabounce-diagnostics-and-tooling`.

**Step 0.4 — Re-run the four regressed tests** (spec §9.11/13/14/15 — full text there):
Use the spec's harness: **idle P1** (the default undriven human), P2–P4 the shipped `bot_levels`
[2,3,4]. Do NOT give P1 a bot brain — tests 13 ("5 full idle-P1 matches") and 14 ("full idle
match") pin the whole §9 sample to idle P1, and a competent P1 measures a different, harder
population (verified 2026-07-03: idle-P1 median combat ≈15s matching QA verdict e57db01; a P1=L3
field dragged median to 19–23s and roughly doubled the SD rate — an artifact, not the real number).
So just launch `scenes/Arena.tscn` and leave P1 alone; no provider swap. A single match ends at
~7–8 rounds on a score win, so aggregate 3–4 matches (rematch via `hold-action menu_accept`;
`round_stats` clears on rematch — pull and stash each match's array before rematching) to reach a
real ≥10-round (ideally ≥30) sample. round_stats shape and the stash-across-rematch caveat →
`gottabounce-diagnostics-and-tooling`.
Expected: SD ≤25% (test 11) · L2 wins 0/5 idle matches with L4 above L2 ≥4/5 (test 13) · idle P1
total ≤2 (test 14) · ≥3 off-stage kills in the sample (test 15, the fix's primary acceptance
gate). Plus one clean human-feel capture of the wall-return shot (prior attempt inconclusive).

**GATE 0 branches:**
- All pass → commit fix + evidence (paired STATUS update), proceed to Phase 1.
- 6d fails (wall-return dead) → the stun gate is mis-scoped: check that the NEUTRAL branch still
  refunds `fuel_per_bumper` (20) and that nothing upstream sets `_stun_timer` on self-triggered
  contact. Do NOT change `fuel_per_bumper` — its value is explicitly reaffirmed (spec §2.3a).
- Test 15 still fails with 6c passing → the bumper was not the only saver; instrument WHERE
  victims are recovering (burst screenshots of an edge-bound victim, per-frame `_stun_timer`
  eval) before touching any constant. Suspects: hitstun expiring before the line (do NOT raise
  hitstun — measure launch speed vs the 660px runway instead) or bot recovery supers (legal).
- Dry reflect feels silent/cheap in screenshots → fallback is MORE FX on stunned-body bumper
  hits (spec's stated fallback), NEVER reopening the refund/clear gate (closed decision,
  DECISIONS 2026-07-03).

---

## PHASE 1 — Full lethality v2.1 sign-off (all 21 criteria + powerup leftovers)

Goal: a filed QA verdict that `docs/specs/v0_combat_lethality.md` §9 passes, so STATUS can call
lethality SHIPPED. The spec's §9 is the authority — the table below is the runbook index, not a
replacement. Harness: idle-P1 sample (P1 = untouched default human; P2–P4 = `bot_levels` [2,3,4]),
aggregated across 3–4 rematches to ≥30 rounds — the same harness as Phase 0.4, NOT a P1 bot brain.
"idle match" = P1 untouched (that is the standing harness here, not a special case).

| # | Test (short) | Expected number (spec §9) |
|---|---|---|
| 1 | Full power at any fuel | launch at 100 vs 6 fuel identical ±5%; at 4 fuel aim never starts |
| 2 | Drain-all + chain rhythm | wall-bounce → fuel ≥20 → 2nd super ≤1.5s at identical speed |
| 3 | Aim bounded | auto-fire at 2.0±0.1s; never hangs past 2.1s |
| 4 | Aim not a brake | 3000 px/s body → 1300–1550 px/s after 0.3s aim |
| 5 | Smashed-while-aiming | aim cancels, no fire, fuel = pre-hit − sting |
| 6a/6b | BOTH directions | kill 4-fuel victim ≥8/10 · full-tank counter survives ≥5/10 (no counter dies ≥7/10) |
| 6c/6d | Dry reflect / wall-return | Phase 0.3 numbers (re-cite, don't re-run if fresh) |
| 7 | Sting | −30 fuel exact; shove −0; spawn-protected −0; 34→4 = no super |
| 8 | Two-tier reads | boost-ram rel 650–750 → zero hitstun, mutual shove ≥250; shove-out at rel ≥500 credits shover |
| 9 | Chain smash | B's stunned body smashes C ≥7/10 alignments |
| 10 | Kills carry the game | ≥70% of rounds end by kill <20s, no SD |
| 11 | SD rare | ≤25% of rounds enter SD |
| 12 | Round length | median combat 10–22s; every round ≤26s combat / ≤30s wall-clock incl. one forced double-KO revive |
| 13 | L4 > L2 | 5 idle matches: L4 above L2 ≥4/5, L2 wins 0/5, L2 suicides ≥1×/match |
| 14 | Idle punished | idle P1 total ≤2; smashed <8s of BOUNCE in ≥70% of rounds |
| 15 | Edge-guarding | ≥3 off-stage kills in sample (`kills[].off_stage`) |
| 16 | Dodge-super | ≥2 L4 supers fired ≤0.4s after enemy AIM within 500px |
| 17 | SD warning reads | screenshot @≈18s shows pulsing edge columns; @≈20.5s SD banner + trackers |
| 18 | Revive path | walls ≥40% closed on revive frame; decided ≤5s after revive |
| 19 | MATCH_END clean | backing panel, legible, zero laser pixels |
| 20 | Survival gate | untouched survivor +0; hit-once survivor +1 |
| 21 | Regressions | turnaround ≤4.5s; avg ≥55fps, no >100ms hitch; countdown lock intact |

Also due in this pass (STATUS NEXT STEPS #1): powerup leftovers — C1 comedy check, two counter
shields colliding, counter vs storm balls, two-star clang (criteria in
`docs/specs/v1_powerups.md`) — and a **3-match feel judgment vs the owner thesis**, filed in
writing (format → `gottabounce-validation-and-qa`).

**GATE 1 branches (fallback knobs are CLOSED-LIST, from spec §9/§10 — nothing else):**
- Rounds too short (<8s median) or random → `smash_impulse_from_attacker` 1.35 → 1.2 first, then
  `super_refire_lockout` 0.25 → 0.5.
- Kills too rare (everyone recovers) → `smash_sting_fuel` 30 → 40 first, then `soft_bump_max` up.
- Test 6b fails low (counters can't survive) → `smash_impulse_from_attacker` DOWN — never
  hitstun up.
- Any knob turn = one constant at a time, predict the metric delta BEFORE measuring
  (prediction-first: `gottabounce-research-methodology`), re-run only the affected tests, record
  in STATUS.
- All green → QA verdict filed, STATUS flips lethality to SHIPPED, DECISIONS notes sign-off.
  Watch items to carry forward, not block on: fuse-ring frame-1 arc minimal, resting-overlap
  shove jitter, bot self-destruct rate off the lowered ceiling (STATUS "Watch").

---

## PHASE 2 — Build movement courses 1–3 (the feel instrument)

Authority: `docs/specs/v1_movement_courses.md` (READY FOR BUILD for courses 1–3; course 4 after
a props pass; course 5 DEFERRED). Build slot is explicitly "immediately after lethality v2 ships
its QA pass — before new arenas, art fix list, audio" (spec header + DECISIONS 2026-07-02).
Roles: level-designer + gameplay-programmer; Director integrates.

Deliverables (spec §1–§2 — verify details there before building; as of 2026-07-03 NONE exist):
1. **CourseMode scene** — loads a course JSON, one player, minimal HUD (run timer, fuel,
   attempts, par) built as .tscn + Theme (never imperative widgets — CLAUDE.md non-negotiable).
2. **Two new level objects** in the JSON `objects[]` schema: `start_gate` (spawn/reset; timer on
   first input) and `goal_ring` (radius 90; touch = clear). Reset on bounds-cross ≤1.5s, fuel
   refilled.
3. **Course JSONs** in `levels/courses/course_XX_name.json` (directory does not exist yet —
   create it): Course 1 "Tank Run" (six 128px trampoline pads, gaps 700/800/900/1000, final
   1600px super gap), Course 2 "The Chimney" (two 4000px trampoline walls, 420px interior gap —
   THE acceptance test of the un-charged super), Course 3 "Bank Shot" (spring pit + bumpers, goal
   ring 2800px away; banked exit speed ≥1400 px/s).
4. **`course_stats` eval hook**: `{time_s, attempts, fuel_min_seen, bounces, supers_fired[],
   reached_checkpoints[]}`.
5. **P+F script pairs per course** (gbplay `.jsonl` scripts — format in
   `gottabounce-run-and-playtest`). The F-scripts are load-bearing: greedy-boost fails Tank Run
   before pad 5; boost-only tops out ≤65% of the Chimney; cold-start lands ≥400px short of the
   Bank Shot ring.

**GATE 2 = spec §4's five criteria, verbatim targets:** (1) courses 1–3 load/run/reset/clear via
P-scripts AND all F-scripts fail as specified; (2) `course_stats` live via eval, reset ≤1.5s;
(3) HUD present as .tscn+Theme, goal ring readable at full-course zoom (screenshot);
(4) full battery (3 × P+F) completes ≤10 min wall clock; (5) feel verdicts filed — QA plays each
course 5+ human-driven runs and answers, in writing, the course's "what it measures" question +
the TowerFall bar question.
Branches: an F-script that PASSES means the course has no teeth — move geometry (gaps up), don't
nerf the tank first (spec course-1 rule). Course geometry moves are tuning and legal, but
re-verify the P+F pair afterward.

---

## PHASE 3 — The tuning loop (one constant at a time)

The instrument exists; now tune. Binding workflow (spec §3, FEEL_REFERENCE discipline):

1. **Pick ONE constant.** The constant→course map is spec §3 (fuel economy → course 1; all
   `super_*` → course 2; momentum/`tangential_retention`/`bumper_restitution` → course 3).
   Guards/status per constant: `gottabounce-tuning-and-flags`.
2. **Write the prediction first** — expected effect on course metrics AND party-match metrics,
   with the theory derivation (skill `game-feel-reference` for the math;
   `gottabounce-analysis-toolkit` for the recipes): touching gravity/`super_aim_damp` → derive
   hang-time and §1.3 drift-table effects first; touching the bounce ladder → recompute
   reachability (does 900 `smash_impact_min` stay super/stun-only?); touching bot dials →
   predict match-stat deltas before running.
3. **Live-tune** via eval, no file edit yet:
   `python tools/gbplay.py eval "Tuning.super_aim_damp = 2.2; return Tuning.super_aim_damp"`
   (verified: static — Tuning is an autoload; eval assignment persists for the process).
4. **Measure:** rerun the affected course's P+F pair + a human-feel run; if the constant is
   combat-relevant, also a bot-match sample (Phase 1 harness). The Chimney is the standing
   un-charged-super acceptance test.
5. **Regression rule:** a change that breaks ANOTHER course's F-script (or any lethality §9
   number) is a regression, not a tune. Revert the eval and rethink.
6. **Adopt:** edit `src/core/Tuning.gd` (with rationale comment + spec ref), parse gate, rendered
   playtest, designer sign-off if feel-relevant, commit + STATUS, record the verdict.

**"Feel still not fun" solution menu, ranked (each with its theory obligation):**
1. Aim feel (`super_aim_damp`/`super_aim_gravity`/`super_aim_max`) — cheapest, course-2 isolated;
   derive drift-table first (spec §1.3 shows the method).
2. Fuel economy (`tank_seconds`, `fuel_per_bounce`) — course-1 isolated; keep
   `fuel_per_bounce ≥ 2× super_boost_min_fuel` (chain-rhythm invariant, Tuning.gd comment).
3. Bounce ladder (`bounce_height_*`, `bounce_di`, `tangential_retention`) — recompute
   `sqrt(2·g·h)` launch speeds and every threshold they feed before touching.
4. Bot dials (`BotProfile.gd`) — only with predicted match-stat deltas; L2-stays-comedic and
   L4-menace targets (spec §3.3) are part of the check.
5. Contact knobs — ONLY the Phase-1 closed list.
Open designer-review item that belongs in this phase, not before: none currently —
`fuel_per_bumper` 20.0 and buffer-through-empty-tank were both RULED and closed in v2.1
(DECISIONS 2026-07-03).

---

## PHASE 4 — Promotion: declare the bar met, un-gate what was staged

**"TowerFall bar met" means, measurably (never "looks fine"):**
1. All 5 course feel-verdicts (GATE 2 criterion 5, plus courses re-run after final tuning) are
   positive in writing;
2. A 3-match party feel judgment vs the owner thesis is filed positive;
3. Lethality §9 criteria still green on a final regression pass (the course battery + 10-round
   sample after the LAST constant change).

Then:
- **Goat identity gate** (DECISIONS 2026-07-03, adopt-STAGED): if the courses validate that the
  super-as-kill-move fantasy is the fun → un-gate horns art (≈8 regens + the new
  `bouncer_*_super_aim.png` aim-pose sprite, which is needed regardless — see
  `gottabounce-art-pipeline`); if bounce-chaining turns out to carry the fun instead → the
  reject condition fires, re-run the art-director evaluation, do NOT ship horns by default.
- **DECISIONS entries** for: lethality signed off, courses adopted as the standing regression
  suite, bar-met declaration (with the evidence links), goat gate outcome.
- **STATUS**: NEXT STEPS re-pointed at arenas/audio (current #4/#5); the campaign's artifacts
  (course battery) become the regression suite every future movement-touching commit must run.

---

## Fenced-off wrong paths (do not "fix" feel with these — each is a closed decision or a proven trap)

| Temptation | Why it is fenced |
|---|---|
| Raise `hitstun_base/per_impulse/max` | GDD §4.6 recovery triad is protected; spec §9.6 tests BOTH directions; DO-NOT-TOUCH in Tuning.gd. |
| Re-introduce super power scaling (fuel or hold time) | Closed (DECISIONS 2026-07-02); it double-taxed the kill move and caused the hoarding/whiffing QA saw. Reopen ONLY with movement-course evidence. |
| Raise `laser_close_time` back toward 10 as a pacing crutch | Lasers are the backstop; slowing them raises the laser-decided share. Fix lethality, not the timer. |
| Widen arena `bounds` to hide lethality problems | 2.4's tightening is load-bearing (660px runway = the recovery gamble); widening reverts the kill geometry. |
| Reopen the bumper refund/stun-clear for stunned bodies | Closed (DECISIONS 2026-07-03). If dry reflect reads badly, add FX — never the refund. |
| Change `fuel_per_bumper` (either direction) | Explicitly reaffirmed at 20.0 by the v2.1 ruling; the stunned-case gate was the bug, not the value. |
| Skip rendered QA because headless/parse passed | "Compiles is a gate, never a sign-off" — the old project died of this (see `gottabounce-failure-archaeology`). |
| Tune two constants at once | The courses exist precisely to make one-variable discipline physical (spec §3 binding workflow). |
| Start Phase N+1 with Phase N unverified | Depth-first non-negotiable (CLAUDE.md); the live example: lethality verdict blocks courses. |

## Provenance and maintenance

Verified 2026-07-03 against the repo at HEAD `0e315b9` by reading:
`docs/specs/v0_combat_lethality.md` (v2.1, all of §1–§10), `docs/specs/v1_movement_courses.md`,
`docs/STATUS.md`, `docs/DECISIONS.md`, `docs/feedback/owner_2026-07-02_movement_feel.md`,
`src/core/Tuning.gd` (full), `src/entities/Player.gd` (`_on_bounced`, smash eligibility, stun
fields), `src/modes/PartyMatch.gd` (round_stats/state surface, `_spawn_player`/`set_provider`),
`src/core/InputBot.gd` (class_name), `tools/gbplay.py` (full), `tools/run_game.ps1`,
`tools/stop_game.ps1`, `scenes/Arena.tscn` (root script), `levels/dev_arena.json` (bounds),
`tools/out/` listing, and `git log`/`git diff`. **No live game run was performed** (port 9090
rule): all gbplay/eval command lines and expected in-game numbers are `verified: static` —
syntax checked against the tool/server source, targets checked against spec/STATUS text.

Drift-prone facts — re-verify before trusting:
- Campaign position / is the §2.3a fix committed:
  `git log --oneline -5` + `git status --short` + read `docs/STATUS.md` NEXT STEPS.
- Dry-reflect code shape: `grep -n -A12 "func _on_bounced" src/entities/Player.gd | grep "_stun_timer <= 0.0"`.
  A bare `grep -n "_stun_timer <= 0.0" src/entities/Player.gd` matches TWO lines — an unrelated
  pre-existing decrement at ~line 314 and (when the fix is in) the `_on_bounced` guard at ~line
  557; against committed HEAD only line 314 appears (the fix's ~557 hit is absent until the
  working-tree change commits). So a hit >~550 (scoped to `_on_bounced`) is the real signal;
  confirm it landed via `git log --oneline -1 -- src/entities/Player.gd`.
- Fallback-knob values: `grep -n "smash_impulse_from_attacker\|smash_sting_fuel\|soft_bump_max\|super_refire_lockout" src/core/Tuning.gd`
  (live: 1.35 / 30.0 / 700.0 / 0.25).
- Courses still unbuilt: `ls levels/courses` (currently: directory absent).
- Criteria text: re-read `docs/specs/v0_combat_lethality.md` §9 and
  `docs/specs/v1_movement_courses.md` §4 — this skill indexes them, the specs rule.
- round_stats eval surface: `grep -n "var round_stats" src/modes/PartyMatch.gd`.

UNVERIFIED / static-only items:
- All expected in-game measurement outcomes (SD%, kill rates, fps, launch speeds) — sourced from
  spec §9 targets and STATUS-reported QA numbers, not re-measured.
- The eval one-liners (P1 bot-brain swap, Tuning live-assignment, round_stats pull) — statically
  consistent with `mcp_interaction_server.gd`'s eval wrapper (code wrapped in a `func _run():`,
  so `return` is required) and with `PartyMatch.gd`'s API, but not executed.
- STATUS cites "evidence tools/out/qa5_*.png/.json"; only qa5 PNGs and a `qa5_fight/` burst dir
  exist in `tools/out/` — no qa5 JSON found (2026-07-03). Treat the STATUS text + spec v2.1 as
  the surviving record of that QA run's numbers.
