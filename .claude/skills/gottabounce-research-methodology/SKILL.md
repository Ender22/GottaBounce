---
name: gottabounce-research-methodology
description: The discipline that turns a hunch into an accepted change in GottaBounce — the evidence bar ("one mechanism must explain ALL observations"), prediction-first tuning, the idea lifecycle (seed → candidate → adversarial eval → staged/rejected with reopen conditions), and when NOT to start new hypothesis work. Load this when you have a theory about a bug or a design idea and want to know what it takes to get it accepted, when you are tempted to issue a verdict from ambiguous evidence, when someone proposes reopening a settled design, or when deciding whether new exploration is allowed right now. Do NOT load for the list of open SOTA-level problems (see skill gottabounce-research-frontier), for what gates a commit (see skill gottabounce-change-control), for what artifacts count as QA evidence (see skill gottabounce-validation-and-qa), or for concrete analysis recipes like reachability audits (see skill gottabounce-analysis-toolkit).
---

# GottaBounce research methodology — how a hunch becomes an accepted change

**What this covers:** the epistemics of this studio. The evidence bar for declaring a root cause,
prediction-first tuning, the lifecycle every idea travels (owner seed → recorded candidate →
assigned adversarial evaluation → staged adoption or documented retirement), role adversarialism
as the method, and the depth-first rule for when new research is forbidden.
**When NOT to use this:** you want the open frontier problems themselves (see skill
gottabounce-research-frontier); you want commit/review gates (see skill
gottabounce-change-control); you want what a QA verdict must contain (see skill
gottabounce-validation-and-qa); you want step-by-step analysis recipes (see skill
gottabounce-analysis-toolkit); you want the full incident narratives (see skill
gottabounce-failure-archaeology).

Jargon used below, defined once:
- **Hitstun** — a short timed loss of control after being smashed (`_stun_timer` in
  `src/entities/Player.gd`).
- **Smash license** — the eligibility rule for a contact to count as a SMASH: attacker is
  super-active OR itself a stunned flying body (spec `docs/specs/v0_combat_lethality.md` §2.1).
- **SD** — sudden death; laser walls close in when a round runs long.
- **P/F scripts** — pre-registered Pass and Fail input scripts for a movement course; the P-script
  must clear it, the F-script must fail it (`docs/specs/v1_movement_courses.md`).

---

## 1. The evidence bar: one mechanism, all observations, survived refutation

A root-cause claim or design verdict is accepted here only when:

1. **One mechanism explains EVERY observation — including the negatives** (the things that did
   NOT happen). A theory that explains 3 of 4 data points is a hypothesis, not a finding.
2. **It survived an assigned adversarial pass.** Someone whose job was to break the claim tried
   and failed (see §5 — roles ARE the refutation machinery).
3. **If two mechanisms still fit the data, NO VERDICT IS ALLOWED.** You must design a
   discriminating experiment that only one mechanism survives, run it, and only then rule.

### Worked example A — inverted-kill (the bar met, 2026-07-02/03)

QA pass 1 on lethality v2 produced four observations (docs/STATUS.md, session 3):

| Observation | Value |
|---|---|
| Attacker who lands a super then dies | 9/9 |
| Smashed victim survives | 10/10 |
| Chain smashes (A smashes B, B's body hits C) | 0/3 |
| Idle P1 | won a match |

One mechanism explains all four simultaneously: a stunned victim is a licensed smasher (§2.1's
`attacker.in_hitstun` branch), so the victim counter-smashed its own attacker on the very next
frame. Attacker always dies (9/9), victim always survives (10/10), chains never form because the
body's smash is spent point-blank on the launcher (0/3), and with every aggressor suiciding, the
idle player wins. Fix: `_stunned_by` pairwise smash immunity (commit 587d0a1;
`src/entities/Player.gd:49` and the eligibility check at ~line 616). Fix-round verification
measured the inverse numbers: victim ring-out 6/6 with attacker surviving, chain credit 4/4.

That is what "accepted" looks like: one mechanism, four observations including negatives, then a
fix whose predicted inversions were measured.

### Worked example B — the pacing anomaly (the bar correctly BLOCKING a verdict, then resolving)

A QA re-verification agent died mid-run (81 tool calls) leaving contradictory pacing evidence:
all-laser round endings, empty `supers_fired`, `killer: -1`. Two mechanisms fit:
- **H1:** bot pacing genuinely regressed (bots stopped firing supers).
- **H2:** the agent's metrics recorder was mis-hooked (game fine, data garbage).

Because two mechanisms fit, STATUS recorded NO verdict and explicitly blocked calling lethality v2
shipped. The discriminating experiment (fresh samples from a clean session): fresh round 1 showed
**54 supers fired** — impossible under H1, expected under H2. Verdict: mis-hooked recorder, not a
regression (docs/STATUS.md, "QA RE-VERIFICATION COMPLETE" entry, 2026-07-03; commit e57db01).
The discipline paid twice: no false "bots are broken" fix was attempted, and the fresh run
surfaced the REAL problem (example C).

### Worked example C — bumper-save (four failures, one root cause, 2026-07-03)

The completed re-verification found four criteria failing: test 15 off-stage kills 1/23 (target
≥3/10), test 11 SD 27–33% (target ≤25%), test 13 L2 won 1/5 idle matches (target 0/5), test 14
idle P1 scored 3 once (cap ≤2). One mechanism explains all four: fix-round 587d0a1 made
`_on_bounced()` unconditionally refund fuel and clear hitstun on EVERY surface contact, and
bumpers sit ~660px inboard of the kill line — so every edge-bound smash victim was auto-saved.
Edge kills un-earnable → SD rises → L2 survives → idle punishment softens. Ruling: spec §2.3a
"hitstun ends by TIME, never by touching a surface" (dry reflect while stunned), commit ea0c133,
DECISIONS 2026-07-03. As of 2026-07-03 the programmer fix is the immediate next task; tests
11/13/14/15 must be re-run against it (the claim "fix works" is currently only a prediction).

**The anti-pattern this bar exists to kill:** the old project's lone-coder self-grading —
"compiles = done", P0–P18 built with only P1 ever run-verified
(docs/reference/LESSONS_LEARNED.md). Any claim graded solely by its author has not met the bar.

---

## 2. Prediction-first: write the numbers down BEFORE you run

Every hypothesis here must commit to measurable predictions before the measurement exists. This
is not ceremony — it is the only defense against post-hoc rationalization when you are both the
experimenter and the judge (an AI studio has no external skeptic).

How it is practiced, with verified instances:

| Practice | Instance (verified in repo) |
|---|---|
| Spec predicts pacing numbers, then QA measures | Lethality spec targets: SD ≤25% (was 55–60%), kill-endings ≥70%, median combat 10–22s (`docs/specs/v0_combat_lethality.md` §9 tests 10–12). First 8-round smoke after implementation measured 12.5% SD (docs/STATUS.md session 3). |
| Fix ships with expected deltas on the exact failing tests | Spec §2.3a "Expected effect on the failing tests": test 15 recovers toward ≥3/10, SD back under 25%, L2 back to 0/5, idle back to ≤2 — written 2026-07-03, BEFORE the programmer fix ran. |
| Pre-registered pass/fail scripts | Movement courses ship P-scripts (must clear) AND F-scripts (must fail); "the fail cases are load-bearing — they prove the course tests something" (`docs/specs/v1_movement_courses.md` §4 criterion 1). A constant change that breaks another course's F-script is a regression, not a tune (§3 of that spec). |
| Both-directions criteria | Test 6 must pass in BOTH directions — kill the fuel-starved victim ≥8/10 AND the full-tank victim's counter-escape succeeds ≥5/10 (spec §9.6). Testing only the direction your change favors is how the inverted-kill bug shipped unseen. |

Operational rule: before changing a constant or landing a mechanic fix, write in the spec / your
report: "I predict metric M moves from X to Y." Then measure. If you cannot state a number, you
do not yet have a hypothesis — you have a mood. (Recipes for deriving the predicted numbers:
see skill gottabounce-analysis-toolkit. Extracting the measurements: see skill
gottabounce-diagnostics-and-tooling.)

---

## 3. The idea lifecycle

Every design idea travels this pipeline. No stage may be skipped, including for owner ideas.

```
owner/QA/code-reading seed
  → RECORDED as candidate (DECISIONS.md entry; explicitly "no work yet" if applicable)
  → ASSIGNED adversarial evaluation (the role whose domain it threatens)
  → verdict: ADOPT / ADOPT-STAGED (with un-gate trigger AND reject condition) / REJECT
  → if superseding something: the old design gets a documented retirement (§4)
  → build → measure vs pre-stated criteria (§2) → sign-off or fix loop
```

### Worked example — goat identity (full lifecycle, still mid-pipeline as of 2026-07-03)

1. **Seed:** owner directive 2026-07-02 — "crazy goats with horns", goat scream on super fire
   (`docs/feedback/owner_2026-07-02_movement_feel.md`). The owner himself frames seeds as "inputs
   to evaluation, not decrees."
2. **Recorded candidate:** DECISIONS 2026-07-02 "THEMING SEED RECORDED — status: candidate
   identity only... No art now." Note the explicit no-work clause: recording an idea costs one
   line; building it before evaluation costs assets.
3. **Assigned adversarial eval:** the art-director — the role whose established direction (Glossy
   Toybox blobs, chosen partly for AI-generatability) the idea threatens — was tasked to evaluate
   it AGAINST that direction (`docs/briefs/art_goat_identity_eval.md`).
4. **Verdict: ADOPT-STAGED** (DECISIONS 2026-07-03) with all three required parts:
   - *Substance:* horns are a cheap decoration pass on the existing ref sheet (~8 regens), not a
     style pivot; they give the super a readable weapon tip.
   - *Un-gate trigger:* lethality ships QA'd AND movement courses validate that
     super-as-kill-move is actually fun; fold horns into the aim-pose art pass needed anyway.
   - *Reject condition:* "if movement-course testing shows the super boost is NOT the fun part
     (e.g. bounce-chaining carries the fun), horns lose their justification" (brief §5).
5. **Current state (2026-07-03): still gated.** No horn asset exists. Do not "helpfully" start
   horn art — the gate is the methodology working, not an oversight.

The key design of this lifecycle: an ADOPT-STAGED verdict is falsifiable in both directions. It
names what would un-gate it AND what would kill it. A verdict without a reject condition is a
rubber stamp with extra steps.

### Where accepted ideas have actually come from (verified history)

- **Owner directives** — the movement-feel thesis, un-charged super hypothesis, movement courses,
  goat seed, sports-mode seeds (all 2026-07-02, all recorded then evaluated — the un-charged
  super was "evaluated & adopted", not just adopted).
- **QA findings** — the "kills feel like traffic accidents" verdict (QA round-loop pass, session
  2) spawned the entire combat-lethality program; the re-verification's four FAILs produced the
  §2.3a ruling.
- **Code reading** — the founding lethality bug was found by reading constants: `smash_impact_min`
  800 > `normal_boost_max_speed` 760, so deliberate boost-rams could mathematically never smash
  (spec commit d262686). Nobody observed it in play; the inequality was the observation.
- **Old-project lessons** — docs/reference/LESSONS_LEARNED.md; the rebuild's non-negotiables are
  its post-mortem, inverted.

When you have an idea, this table tells you what to do with it: record it as a DECISIONS
candidate and route it to its adversary. (Entry format: see skill gottabounce-docs-and-writing.)

---

## 4. Documented retirement — superseded designs never die silently

When a design loses, it gets a DECISIONS.md entry stating the verdict, the rationale, and the
reopen condition. This is what makes settled battles citable instead of refightable. Verified
retirements:

| Retired design | Retirement record | Reopen condition |
|---|---|---|
| Charged super (power scales with fuel + charge hold) | DECISIONS 2026-07-02 "SUPER BOOST REDESIGNED... un-charged"; `super_charge_*` constants deleted | "Reopen only with movement-course evidence." Never re-introduce power scaling otherwise. |
| v1 light-smash tier (boost-rams cause hitstun) | DECISIONS 2026-07-02 contact-model entry: "v1 lethality spec's light-smash tier... is dead" | none stated — dead. |
| Bot bank-then-strike (`strike_fuel`) | Spec v2 §3: replaced by refuel-rhythm; §8: "v1's strike_fuel is DEAD — do not implement it" | none — the thing it banked (charge power) no longer exists. |
| Bumper refund/stun-clear while stunned | DECISIONS 2026-07-03 dry-reflect ruling; spec §2.3a | Explicitly CLOSED: if dry reflect feels silent, fix FX/SFX — "Do not reopen the refund/clear gate." |

Rules that follow:
1. **Before proposing a mechanic, grep DECISIONS.md** for it. If it was retired, your proposal
   must engage the recorded reopen condition with NEW evidence of that specific kind — or it is
   noise. ("Reopen only with movement-course evidence" means course telemetry + feel verdicts,
   not vibes.)
2. **When your change kills a design, write its retirement entry** in the same commit's doc pass.
   The double-entry pattern is normal: goat identity appears twice in DECISIONS (candidate
   2026-07-02, then adopt-staged 2026-07-03) — the later entry supersedes, the earlier one stays
   as history.
3. Full narratives of settled battles: see skill gottabounce-failure-archaeology. The DECISIONS
   line is the ruling; the archaeology skill is the court record.

---

## 5. Roles ARE the methodology

The studio's role system (docs/STUDIO.md) is not org-chart decoration — it is how a solo AI
studio manufactures adversarial review:

| Role | Methodological function |
|---|---|
| Game Designer | States hypotheses as specs with numbered, measurable success criteria (lethality v2.1 has 21+2; round loop 19; powerups 17; movement courses 5). A spec without criteria is not reviewable. |
| QA / Playtester | The assigned refuter. Verdicts REQUIRE evidence — screenshots, position/velocity logs, repro steps (docs/STUDIO.md rules; .claude/agents/qa-playtester.md). Verifies criteria explicitly, then goes off-script trying to break it. **Does not fix code** — the refuter never grades their own repair. |
| Art Director | Adversarial reviewer of visual ideas against the established direction; grades in-game screenshots vs brief, verdicts Ship/Fix/Reject. |
| Studio Director | Arbiter — resolves disagreements, owns the merged result, commits. |

Binding norms (docs/STUDIO.md, quoted): "Reviewers must push back with reasons + alternatives.
Rubber stamps are failure." and "'Compiles' is a gate, never a sign-off."

Practical consequence for you: when you produce a hypothesis, HAND IT to the role whose job is to
kill it. When you are that role, your deliverable is the strongest attack you can mount, not
agreement. A review that found nothing to push back on should say what it TRIED.

(What specific artifacts a QA verdict must contain, and the 4-layer validation stack: see skill
gottabounce-validation-and-qa. Which changes need which reviewer before commit: see skill
gottabounce-change-control.)

---

## 6. When NOT to research: the depth-first gate

**No new hypothesis work while the current slice is unverified.** (CLAUDE.md non-negotiable:
depth-first, one slice to genuinely-good before widening — the old project died of the opposite.)

The live example, as of 2026-07-03 (docs/STATUS.md NEXT STEPS):
1. Lethality v2 is implemented but NOT signed off — the §2.3a programmer fix plus re-run of
   tests 11/13/14/15 and the full 21-criteria pass come first.
2. Movement courses (the next research instrument) are specced but may NOT be built until (1)
   lands.
3. Goat-identity art is gated behind (2)'s feel verdicts.

So even a good new idea today has exactly one legal move: a one-line DECISIONS candidate entry
(cheap, non-blocking), then back to the unverified slice. Recording is always allowed; building
is what the gate stops.

Signs you are violating this gate: starting a new spec while a QA verdict is pending; "quick"
prototype branches of ungated ideas; evaluating theming for a mechanic that has no feel verdict
yet (the goat eval brief itself states the principle: "Horns amplify a working mechanic; they
cannot fix a not-yet-tuned one").

The one exception: **investigating a blocker IS the current slice.** The pacing-anomaly
investigation (§1B) was not new research — it was the verification debt of the lethality slice.

---

## 7. Quick self-check before you claim anything

Run this list before filing a root cause, verdict, or design recommendation:

1. Does ONE mechanism explain every observation, including what did NOT happen?
2. Could a second mechanism still fit? → design the discriminating experiment; no verdict yet.
3. Did I write my predicted numbers down before measuring?
4. Did I test both directions (the case my change helps AND the case it could hurt)?
5. Has the adversary role seen it — and did they push back with substance?
6. Is this idea already retired in DECISIONS.md? If so, am I engaging its reopen condition with
   the specific evidence type it demands?
7. Is the current slice verified? If not, am I allowed to be doing this at all (§6)?
8. If adopted staged/gated: did I state both the un-gate trigger and the reject condition?

---

## Provenance and maintenance

Verified 2026-07-03 against the repo at HEAD 0e315b9 (`git log --oneline -1`), statically only
(no game runs — port 9090 untouched). Sources read in full: docs/DECISIONS.md, docs/STATUS.md,
docs/STUDIO.md, docs/specs/v0_combat_lethality.md (v2.1), docs/specs/v1_movement_courses.md,
docs/briefs/art_goat_identity_eval.md, docs/feedback/owner_2026-07-02_movement_feel.md,
.claude/agents/qa-playtester.md, src/entities/Player.gd (`_stunned_by` lines 49/315/562/616/
629-630/702/724/811), src/core/Tuning.gd (smash_impact_min 900, normal_boost_max_speed 760,
fuel_per_bumper 20.0), .git/hooks/post-commit, git log.

Drift-prone facts and one-line re-checks:
- Live pipeline state ("programmer fix next; tests 11/13/14/15 re-run required; lethality NOT
  signed off"): `git log --oneline -5` + read the bottom of docs/STATUS.md session-3 list and
  NEXT STEPS. This WILL drift first.
- Goat identity still gated: `grep -n "GOAT IDENTITY" docs/DECISIONS.md` (a newer entry
  supersedes an older one — read the topmost).
- Retired-designs table current: `grep -nE "Supersedes|dead|Do not reopen|Reopen only" docs/DECISIONS.md docs/specs/v0_combat_lethality.md`
- Criteria counts (21+2 lethality incl. 6c/6d; 5 movement-courses): `grep -nE "^[0-9]+\." docs/specs/v0_combat_lethality.md docs/specs/v1_movement_courses.md`
- Founding-bug constants stayed fixed: `grep -n "smash_impact_min\|normal_boost_max_speed" src/core/Tuning.gd` (expect 900 and 760; 900 must be reachable only via super/stunned-body paths).
- `_stunned_by` immunity still present: `grep -n "_stunned_by" src/entities/Player.gd`

Corrections applied vs. the 2026-07-03 charter pack (repo won): the QA re-verification is NOT an
open interrupted case — it completed via salvage + fresh samples (verdict "NOT clean-ship yet",
commit e57db01); the pacing anomaly resolved as a mis-hooked recorder; the fuel_per_bumper /
buffer-through-empty-tank designer sign-off debt is RESOLVED by the 2026-07-03 dry-reflect ruling
(spec v2.1, commit ea0c133); HEAD is 0e315b9, not 4a550b2.

UNVERIFIED / static-only: the "81 tool calls" figure and "54 supers fired" number come from
docs/STATUS.md prose (the dead agent's transcript and live counters are not reproducible
artifacts; STATUS cites tools/out/qa5_*.json but only qa5_*.png and the qa5_fight/ burst frames
exist in tools/out as of 2026-07-03). All QA pass rates (9/9, 10/10, 0/3, 6/6, 4/4, 1/23,
27-33%, 12.5%) are as recorded in docs/STATUS.md and spec changelogs — verified: static, not
re-measured. The sibling skill gottabounce-research-frontier was not yet present in
.claude/skills/ at authoring time (being written in parallel).
