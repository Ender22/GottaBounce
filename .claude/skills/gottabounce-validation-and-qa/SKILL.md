---
name: gottabounce-validation-and-qa
description: GottaBounce's evidence doctrine — what counts as proof that a feature works or a slice is "done". Load this when you are about to claim something is done/shipped/passing, when running a QA pass or criteria pass against a spec, when filing a QA verdict or feel judgment, when deciding which validation layer (parse gate / headless sim / rendered playtest / vision review) a change needs, or when asking "is X certified?". Do NOT load this for gbplay/run_game command syntax (see skill gottabounce-run-and-playtest), for extracting metrics like round_stats or perf numbers (see skill gottabounce-diagnostics-and-tooling), or for the phased feel-tuning campaign plan (see skill gottabounce-feel-campaign).
---

# GottaBounce validation & QA — the evidence doctrine

**What this covers:** the 4-layer validation stack and when each layer is REQUIRED; what counts
as evidence for a QA verdict; criteria discipline (every spec ships numbered, measurable QA
criteria — how to run a criteria pass and file a verdict); the golden/certified inventory and the
NOT-certified list as of 2026-07-03; how to add a test; feel verdicts.
**When NOT to use this:** command anatomy for launching/driving the game → skill
`gottabounce-run-and-playtest`. Metric extraction and interpretation (round_stats, perf, burst
analysis) → skill `gottabounce-diagnostics-and-tooling`. What gates a change before commit →
skill `gottabounce-change-control`. Incident narratives → skill `gottabounce-failure-archaeology`.

## 0. The one-sentence doctrine

**"Compiles" is a gate, never a sign-off.** (docs/STUDIO.md Rules; docs/PIPELINE.md.) The old
project died exactly here: 19 phases code-built, only one ever run-verified, "done" meant
"parses" (see skill `gottabounce-failure-archaeology`). In this studio nothing is "done" until
the real rendered game was driven with input, screenshots were captured, and someone actually
LOOKED at them. The human owner never playtests — the validation stack below IS the player.

Jargon used in this file, defined once:
- **Parse gate** — a headless Godot editor launch that only proves scripts/scenes load without
  errors (and rebuilds the class-name cache). Proves nothing about behavior.
- **Rendered playtest** — the game running windowed on screen, driven via `tools/gbplay.py`
  over TCP port 9090, with screenshots captured to `tools/out/`.
- **eval** — `python tools/gbplay.py eval "<GDScript>"`, runs code inside the live game; the
  expression must `return` a value.
- **Criteria pass** — executing every numbered success criterion in a spec's criteria section
  and recording PASS/FAIL per criterion with evidence.
- **SD** — sudden death (closing laser walls at round_clock 20s). **Ring-out** — death by
  crossing the arena bounds. **Hitstun** — the post-smash window where a victim has no control.

## 1. The 4-layer validation stack

Source: docs/PIPELINE.md §1. Layers are cumulative — a higher layer never excuses skipping a
required lower one.

| # | Layer | Command (verified 2026-07-03) | Proves | Is NOT |
|---|-------|-------------------------------|--------|--------|
| 1 | Parse gate | `& "C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --editor --quit` then grep output for `Parse Error`, `hides a native`, `Failed to load script`, `not declared` | No script/scene breakage; rebuilds class cache | Ever a sign-off |
| 2 | Headless sim | `<same exe> --headless --path . res://scenes/Playtest.tscn -- <mode> <seconds>` — modes `observe` / `hover` / `duel` / `botwar` (src/dev/Playtest.gd header); prints a `PLAYTEST SUMMARY` block | Physics/behavior numbers: speeds, ring-outs, tunneling, scores | Proof of looks or feel |
| 3 | Rendered playtest | `powershell -File tools/run_game.ps1 [scene]` + `python tools/gbplay.py ...` + `powershell -File tools/stop_game.ps1` — full anatomy in skill `gottabounce-run-and-playtest` | What it LOOKS like and how it BEHAVES under real input | Done until layer 4 happens |
| 4 | Vision review | Read the captured PNGs (the Read tool on `tools/out/*.png`); review bursts as 3–6 frame motion sequences | Art quality, readability, layout, glitches, motion | Optional — unreviewed screenshots are not evidence |

Godot launches need `dangerouslyDisableSandbox: true` on shell calls, and should go through the
Bash tool, not PowerShell (stderr-wrapping trap — see skill `gottabounce-build-and-env`).

### When each layer is REQUIRED

| Change type | 1 Parse gate | 2 Headless sim | 3 Rendered | 4 Vision review |
|---|---|---|---|---|
| Any `class_name` add/rename | REQUIRED (also rebuilds stale class cache) | — | — | — |
| Any script/scene change | REQUIRED | — | REQUIRED before claiming done | REQUIRED |
| Physics/feel/tuning change | REQUIRED | recommended (fast numbers first) | REQUIRED | REQUIRED |
| Art asset intake or visual change | REQUIRED (if .tscn touched) | — | REQUIRED (grade IN GAME) | REQUIRED |
| Spec sign-off / "SHIPPED" claim | REQUIRED | as criteria demand | REQUIRED — full criteria pass | REQUIRED |
| Doc-only change | — | — | — | — |

**The minimum "done" bar** (docs/PIPELINE.md, verbatim intent): "One rendered playtest with
screenshots reviewed = the minimum bar for calling anything 'done.'" Screenshot bursts reviewed
as a sequence are our "watching gameplay".

## 2. What counts as evidence for a QA verdict

From docs/STUDIO.md and `.claude/agents/qa-playtester.md`:

- **QA verdicts require evidence**: screenshots (actually read), position/velocity logs (via
  eval), repro steps, and measured numbers compared against the spec's numbered criteria.
  "Looks fine" is not a verdict.
- **Rubber stamps are failure.** Reviewers must push back with reasons and alternatives
  (docs/STUDIO.md Rules). A QA pass that finds nothing should make you suspicious, not relieved
  — the QA method explicitly includes going off-script: mash inputs, hold everything at once,
  idle, fly into corners, die on purpose (qa-playtester.md step 4).
- **QA does not fix code.** QA files findings with repro steps and severity; the programmer
  fixes; QA re-verifies. (qa-playtester.md, last line.)
- **Judgments need numbers too**: feel judgments must be supported with frame numbers,
  positions, velocities (qa-playtester.md step 5).
- Evidence artifacts live in `tools/out/` (naming conventions → skill
  `gottabounce-run-and-playtest`). Metrics come from the PartyMatch QA surface — one-liner:
  `python tools/gbplay.py eval "return get_tree().current_scene.round_stats"` (Arena.tscn's
  root script is src/modes/PartyMatch.gd; field shape and interpretation → skill
  `gottabounce-diagnostics-and-tooling`).

## 3. Criteria discipline

Every gameplay spec ships a numbered, measurable success-criteria section. That section is the
contract: a slice is signed off when every criterion has a recorded PASS with evidence, or every
FAIL has an explicit disposition (fix, or a designer-approved gap recorded in STATUS).

### Criteria inventory (verified against docs/specs/ 2026-07-03)

| Spec | Criteria section | Count | Sign-off status as of 2026-07-03 |
|---|---|---|---|
| docs/specs/v0_round_loop.md | §5 | 19 numbered | 18/19 PASS, zero crashes (session 2, STATUS) |
| docs/specs/v1_powerups.md | §5 | 17 (F1–F5, S1–S4, P1–P7, C1) | All measured criteria PASS with recorded gaps (§5 below) |
| docs/specs/v0_combat_lethality.md v2.1 | §9 | 21 numbered (test 6 has sub-parts a–d; 6c/6d new in v2.1) | NOT signed off — see §5 |
| docs/specs/v1_movement_courses.md | §4 | 5 numbered | Not built — spec only |

### How to run a criteria pass

1. Read the spec's criteria section IN FULL first. Each criterion states its own harness
   (eval setup, scripted input, screenshot moment, sample size).
2. Launch the target scene rendered (see skill `gottabounce-run-and-playtest`); use headless
   Playtest only where a criterion is purely numeric and the spec allows it.
3. Execute each criterion literally — the numbers in the spec are the bar, not an aesthetic
   guide. Record: criterion #, measured value, PASS/FAIL, evidence path (`tools/out/...`).
4. Sample sizes matter: criteria like "≥8/10" mean run it 10 times, not once. The lethality
   spec's standard harness is a 10-round bot-driven sample (spec §9 header).
5. Then go OFF the script (qa-playtester.md step 4) and file anything you break as a bug with
   repro steps + severity, separate from the criteria table.
6. File the verdict (§4) and ALWAYS run `tools/stop_game.ps1` when finished.

### The BOTH-DIRECTIONS lesson (test each rule from both sides)

Lethality spec §9 test 6 is the canonical example — the spec **fails if EITHER side fails**:
- 6a *kill side*: fuel-starved victim must ring out ≥8/10.
- 6b *recovery side*: full-tank victim with a scripted counter-super must survive ≥5/10 (and
  the no-counter control must die ≥7/10).

Why this is doctrine: the inverted-kill bug (fix 587d0a1) shipped precisely because the kill
mechanic was only ever tested from the attacker's intent, not from "what does the victim's state
machine do next frame" — landing a super was suicide 9/9 and QA pass 1 caught it only by
watching both bodies. When a criterion tests a rule (a gate, a license, a credit), always write
and run the mirror criterion. Full story → skill `gottabounce-failure-archaeology`.

v2.1 extended the same discipline: test 6c (dry reflect must NOT save a stunned victim) is
paired with 6d (the wall-return shot must STILL work for a non-stunned player) — the fix and
the feature it must not break, tested as a pair.

## 4. Filing a verdict

Report format (from `.claude/agents/qa-playtester.md`):

```
PASS/FAIL per criterion (numbered, with the measured value and evidence path)
+ bug list (repro steps, severity)
+ feel notes (evidence-backed: frame numbers, positions, velocities)
+ screenshots kept in tools/out/
```

Verdict vocabulary observed in practice (STATUS session 3): a full-pass verdict is explicit —
e.g. "NOT clean-ship yet" with the exact failing tests and a suspected root cause. A verdict
without a per-criterion table is not a verdict. After the Director integrates fixes, the
failing criteria get a TARGETED re-run (only the affected tests + regression pair), recorded in
STATUS — see skill `gottabounce-change-control` for the commit/STATUS ritual.

## 5. Golden / certified inventory — as of 2026-07-03 (HEAD 0e315b9)

All numbers below are as recorded in docs/STATUS.md and the specs; they were measured in live
runs by prior sessions (this skill's authoring pass verified them statically against the docs,
not by re-running — `verified: static`).

### Certified (measured PASS, evidence on record)

| Fact | Number | Source |
|---|---|---|
| Round turnaround, last-death → next BOUNCE | 4.28–4.29 s (contract ≤4.5 s) | STATUS session 2; round_loop §5.4 |
| Performance during combat | 79–80 fps, 28 draw calls (criterion: avg ≥55 fps, no hitch >100 ms) | STATUS; round_loop §5.18 |
| Round loop | 18/19 criteria PASS, zero crashes | STATUS session 2 |
| Powerups | all 17 criteria measured PASS (gaps listed below) | STATUS session 2 |
| Lethality fix round (587d0a1) | victim ring-out 6/6 @1.12 s with attacker surviving; B→C chain credit 4/4; idle P1 scored 0 | STATUS session 3 |
| Lethality re-verification, core hinge | 6a kill fuel-starved 9/10; 6b full-tank counter-escape 10/10 (control: no counter dies 6/6); test 9 chain credit 6/6 | STATUS session 3 (evidence tools/out/qa5_*.png) |
| Lethality pacing partials | test 10 borderline PASS (72.7% kill-decided <20 s); test 12 PASS (median 15.0 s) | STATUS session 3 |
| Implementation smoke (03894ac) | 8-round bot match: 7 ring-out / 1 laser = 12.5% SD (target <25%) | STATUS session 3 |

### NOT certified at HEAD (do not claim these ship)

- **Lethality v2 overall: NO sign-off.** The 2026-07-03 QA re-verification verdict is
  "NOT clean-ship yet": tests 11 (SD 27–33% vs ≤25%), 13 (L2 won 1/5 idle matches), 14 (idle P1
  scored 3 once, cap ≤2), 15 (1 off-stage kill in 23 rounds vs ≥3/10) FAILED, all traced to the
  bumper-save bug (spec v2.1 §2.3a dry-reflect ruling). Full incident → skill
  `gottabounce-failure-archaeology` (Incident 10). **This state is VOLATILE:** against committed
  HEAD 0e315b9 the fix is in spec only, NOT in code — but a fix is in-flight in the working tree,
  so this reads stale the moment it commits. Re-verify via
  `git log --oneline -1 -- src/entities/Player.gd` and STATUS NEXT STEPS before relying on it.
  Tests 11/13/14/15 plus new 6c/6d must be re-run after the fix.
- The earlier "pacing.json anomaly" (all-laser endings, empty supers_fired) was resolved as the
  dead QA agent's mis-hooked recorder, NOT a game regression (fresh round showed 54 supers
  fired) — treat that scare as closed; details → skill `gottabounce-failure-archaeology`.
- **Powerup gaps** (recorded at ship, still open): mutual counter-shield and star edge cases
  code-reviewed only (two counter shields colliding, counter vs storm balls, two-star clang
  never exercised); C1 comedy check unrun; unlimited-boost flame telegraph modest; no
  black-hole vignette.
- **Wall-return-shot human feel**: inconclusive (test-session artifact) — needs one clean pass.
- **3-match feel judgment vs the owner thesis**: not yet filed for lethality v2.
- **Movement courses**: specced (v1_movement_courses.md), NOT built. **Goat identity**:
  adopt-STAGED, gated on courses validating the super fantasy (docs/DECISIONS.md 2026-07-03).
- Round loop's one open criterion (the 19th of 18/19) — check the session-2 QA record before
  assuming which; UNVERIFIED: the specific failing criterion number is not recorded in STATUS.

## 6. How to add a test

Three mechanisms, in increasing cost:

1. **A gbplay script** — a `.jsonl` file of raw protocol commands run via
   `python tools/gbplay.py script <file>.jsonl` (one JSON object per line,
   `{"command": ..., "params": ...}`; client-side pseudo-commands `sleep`
   (`{"command":"sleep","params":{"seconds":N}}`) and `screenshot_to` are supported —
   tools/gbplay.py:135-139). Best for reproducible input sequences with screenshots at fixed
   points. Syntax details → skill `gottabounce-run-and-playtest`.
2. **A Playtest mode** — extend src/dev/Playtest.gd (current modes: observe/hover/duel/botwar)
   for headless numeric probes that should run without a rendered session. Adding a mode is a
   code change → normal change control.
3. **A spec criterion** — if the behavior is a lasting contract, add a numbered criterion to
   the owning spec's criteria section (with its harness and exact numbers) so every future
   pass re-checks it. This is how v2.1 locked in the dry-reflect fix (tests 6c/6d). Spec
   editing goes through the designer → skill `gottabounce-change-control` and template → skill
   `gottabounce-docs-and-writing`.

Rule of thumb: bug fix → add the regression criterion to the spec AND capture the repro as a
script if input-driven. One-off measurement → script only.

## 7. Feel verdicts (judgment criteria)

Feel is judged, but the judgment is structured and evidence-backed — never freeform vibes:

- The standing instrument is the **3-match judgment**: QA plays 3 full matches and answers the
  spec's named questions (round_loop §5.19: did L2 self-destruct ≥1×/match? did the human sweat
  the L4 bot? any round >35 s wall-clock BOUNCE→ROUND_END? — must be no. Powerups §5 C1: one
  powerup self-ring-out per match? players converge on star? any two effects confusable in a
  screenshot? — must be no).
- Since the 2026-07-02 owner directive, every feel verdict also reconciles against the owner
  thesis: movement/combat feel IS the product, bar = TowerFall Ascension
  (docs/feedback/owner_2026-07-02_movement_feel.md). The movement-courses spec §4.5 formalizes
  this as written verdicts per course: "did I feel capable and cool, and were failures my
  fault?" — those verdicts, not the pass/fail scripts, are what the designer tunes against
  (spec quote). Courses are NOT built yet; until then, feel verdicts ride on party matches.
- Every claim in a feel verdict cites evidence: burst frame numbers, measured velocities,
  round_stats pacing numbers. "Bounces have rhythm" needs a burst sequence; "kills feel like
  traffic accidents" (the session-2 verdict that spawned the whole lethality program) was backed
  by 55–60% laser-decided rounds and an idle human scoring 9.

## 8. Anti-patterns (each one has already burned this project once)

| Anti-pattern | Why it is banned | Receipt |
|---|---|---|
| "It compiles / parse gate passed" as done | Layer 1 proves loading, nothing else | Old project: P0–P18 built, one verified → skill `gottabounce-failure-archaeology` |
| Testing a rule from one side only | The mirror case is where state machines bite | Inverted-kill: super = suicide 9/9 (fix 587d0a1) |
| Screenshot taken but never read | Unreviewed PNGs are not evidence | Doctrine, docs/PIPELINE.md layer 4 |
| Verdict without per-criterion numbers | Un-falsifiable, un-re-runnable | STUDIO.md: "QA verdicts require evidence" |
| Rubber-stamp review | Reviewer must push back or the loop is decorative | STUDIO.md Rules |
| QA patching the code it is judging | Kills the adversarial role | qa-playtester.md: "You do not fix code" |
| Skipping the targeted re-run after a fix | A fix is a claim, not a fact | v2.1: tests 11/13/14/15 + 6c/6d re-run required before ship |
| Claiming gated/staged things ship | Oversell corrupts STATUS as ground truth | Goat identity = adopt-STAGED; courses = specced only |

## Provenance and maintenance

Authored 2026-07-03 against HEAD `0e315b9` ("STATUS: spec v2.1 ruling recorded; programmer fix
next"). Everything above was verified by reading the repo files listed below. **No live game run
was performed for this skill** — all commands and all measured QA numbers are `verified: static`
(commands checked against the scripts/specs that define them; numbers checked against
docs/STATUS.md and spec records, not re-measured).

Verified sources: docs/PIPELINE.md (§1 stack, done-bar), docs/STUDIO.md (rules, roles),
.claude/agents/qa-playtester.md (method, report format), docs/STATUS.md (all certified/
not-certified numbers), docs/DECISIONS.md (2026-07-03 + 2026-07-02 entries),
docs/specs/v0_round_loop.md §5 (19 criteria), docs/specs/v1_powerups.md §5 (17),
docs/specs/v0_combat_lethality.md §9 (21, v2.1), docs/specs/v1_movement_courses.md §4 (5),
src/dev/Playtest.gd (modes), tools/gbplay.py (script/eval mechanics), scenes/Arena.tscn
(PartyMatch.gd root), src/modes/PartyMatch.gd (round_stats exists), tools/out/ listing
(qa3/qa5 evidence).

Drift-prone facts — re-verify before relying on them:
- HEAD / sign-off state: `git -C "D:\Projects\GottaBounce" log --oneline -5`
  and read docs/STATUS.md "NEXT STEPS" — if the v2.1 dry-reflect fix has landed and tests
  11/13/14/15 + 6c/6d re-ran PASS, §5's NOT-certified list is stale.
- Criteria counts: `grep -n "^## " docs/specs/*.md` then read each criteria section.
- Playtest modes: `grep -n "mode = " src/dev/Playtest.gd`.
- Parse-gate grep terms: read CLAUDE.md "How to run & validate".
- Certified numbers: they live in docs/STATUS.md per-session lists; re-measure via the
  instruments in skill `gottabounce-diagnostics-and-tooling` if a spec pass is at stake.

UNVERIFIED items carried in the body:
- Which single round-loop criterion was the 19th (the non-PASS of 18/19) — not recorded in
  STATUS; the session-2 QA agent transcript (not in repo) holds it.
- STATUS cites re-verification evidence as `tools/out/qa5_*.png/.json`, but no `qa5_*.json`
  exists in tools/out/ (only qa5_*.png, qa5_fight/ frames, and qa3_match2_log.json) — the JSON
  likely lived in the QA agent's scratchpad.
