---
name: gottabounce-change-control
description: Load this BEFORE making, reviewing, or committing ANY change to the GottaBounce repo — code, tuning constants, art, levels, specs, or docs. Answers "am I allowed to change this?", "what review does this change need?", "can I touch hitstun_base / sudden_death_time / fuel_per_bumper?", "do I need a DECISIONS.md entry?", "what happens after I commit?". Do NOT use it for how to RUN validation (see skill gottabounce-validation-and-qa and gottabounce-run-and-playtest), for the full incident narratives (see skill gottabounce-failure-archaeology), or for doc templates (see skill gottabounce-docs-and-writing).
---

# GottaBounce change control — what gates a change, and why

**What this covers:** the project's non-negotiable rules with the historical incident behind each,
the studio review loop as the gating mechanism, how changes are classified and what gate each class
needs, the DO-NOT-TOUCH constants, DECISIONS.md and STATUS.md discipline, and commit conventions.
**When NOT to use this:** how to actually run QA/playtests (→ skill `gottabounce-validation-and-qa`,
`gottabounce-run-and-playtest`); deep incident forensics (→ skill `gottabounce-failure-archaeology`);
doc/spec templates and house style (→ skill `gottabounce-docs-and-writing`); the full tuning-constant
catalog (→ skill `gottabounce-tuning-and-flags`).

## 1. Why change control exists here (the founding failure)

This repo is the second attempt. The first project (`D:\Dropbox\MyGames\GottaBounce`, kept untouched
as reference; its post-mortem is `docs/reference/LESSONS_LEARNED.md`) died from **unreviewed,
breadth-first execution**, not bad design:

- All ~18 phases (core → campaign → bosses → progression → menus) were code-built in sequence,
  validated only by "loads without script errors" in headless Godot.
- `docs/reference/MASTER_BUILD_PLAN.md` §5 change log records it plainly: *"NOW BUILT: P0–P15, P17,
  P18 (only P1 run-verified; rest code-built, ~50 files, unverified by run)"* and *"Owner authorized
  building straight through w/o waiting for tests."*
- Owner's verdict on first play: *"feels barely at proof-of-concept."*
- The post-mortem's diagnosis: a single undifferentiated voice that both made and graded its own
  work — "design, art, code, and QA all collapsed into 'I wrote it and it runs.'"

Every rule below is a scar from that collapse or from a rebuild incident. Change control is not
bureaucracy; it is the mechanism that makes this an AI studio instead of a lone coder.

One doctrine update since the post-mortem: LESSONS_LEARNED.md still says "the human owner is final
QA — always." That clause is **superseded** in the rebuild (CLAUDE.md, `docs/STUDIO.md`,
DECISIONS.md 2026-07-02): the owner installs tools/auth only and NEVER playtests or reviews. All
validation is done by AI sessions driving the real rendered game. The evidence bar did not drop —
it moved onto us.

## 2. The non-negotiables, each with its incident

Source of the rules: `CLAUDE.md` ("Non-negotiables") + `docs/STUDIO.md` + `docs/PIPELINE.md` §3.

| # | Rule | Rationale | The incident that wrote it |
|---|------|-----------|---------------------------|
| 1 | **Depth-first.** One slice to genuinely-good before widening. Never claim "done" for "compiles." | A wide shallow skeleton demos nothing and hides every real bug until someone plays it. | Old project: P0–P18 built, only P1 ever run-verified; owner verdict "barely proof-of-concept." |
| 2 | **Headless = no-crash gate only.** Real validation = run rendered, screenshot, LOOK, drive input. | Headless proves parse/load only. It cannot test input, feel, visuals, UI. | Old project shipped a gamepad that controlled nothing, a HUD showing bot fuel gauges, and a bounce ~2× too high — all "verified" headless, all caught in minute one of real play. |
| 3 | **Look like a real game from day one.** No debug rectangles, no OS-default widgets, no SVG-circle art. | Programmer art makes everything read as a tech demo and masks readability problems. | Old project rendered surfaces as flat `Polygon2D` rectangles and built menus from `OptionButton`/`SpinBox` walls; the owner "(rightly) hated it." |
| 4 | **All feel constants in `src/core/Tuning.gd`. Levels are data (JSON), never hardcoded.** | One tunable surface = live tuning via gbplay eval, reviewable diffs, and reachability audits across constants. | The founding rebuild bug was found BY reading Tuning.gd as one block: `smash_impact_min` (then 800) > `normal_boost_max_speed` (760) — the kill gate was mathematically unreachable by boost-rams (spec commit d262686). Hardcoded values can't be audited like that. |
| 5 | **UI is built as .tscn scenes + Theme resource**, never imperative `Button.new()` walls. | UI is a design surface; imperative widget code is ungradeable by the art director and unfixable without rewrites. | Old-project default-widget menus (see rule 3); DECISIONS.md 2026-07-02 locked ".tscn+Theme" in. |
| 6 | **After every commit: update `docs/STATUS.md`.** | STATUS is the single always-current handoff doc; a fresh context reads it first. Sessions die mid-task (one QA agent died at 81 tool calls) — STATUS is how the next session resumes. | Enforced socially by the post-commit hook reminder (see §7 — it prints, it does not block). Followed in practice: git log shows a STATUS commit paired with nearly every code commit. |
| 7 | **Small commits, one per working slice/fix. No `--no-verify`.** | Per-phase commits were one of the few things the old project got right ("easy rollback"). | `docs/PIPELINE.md` §3 verbatim; LESSONS_LEARNED "What was actually good: one commit per phase." |
| 8 | **Reviewers must push back. Rubber stamps are failure.** | A role that grades its own work reverts to the lone-coder collapse. | `docs/STUDIO.md` Rules; LESSONS_LEARNED "disagreement between them is the feature, not friction." |

"Compiles" is a **gate, never a sign-off** (`docs/STUDIO.md`). The minimum bar for calling anything
done is one rendered playtest with screenshots actually reviewed (`docs/PIPELINE.md` §1).

## 3. The studio loop is the gating mechanism

From `docs/STUDIO.md`. Roles are subagents in `.claude/agents/`; the Studio Director is the main
session and owns integration, priorities, commits, and STATUS.

**The loop (one feature = one slice):**
spec (game-designer) → visual brief (art-director, if visual) → build (gameplay-programmer) →
**rendered playtest** (qa-playtester drives via gbplay, captures screenshots/metrics) →
art grade vs brief (art-director, from screenshots) → Director integrates, commits, updates STATUS.

Who must sign what before the Director commits:

| Gate | Owner | What "pass" requires |
|------|-------|----------------------|
| Spec exists with numbered, measurable QA criteria | game-designer | Every mechanic change ships against a spec (e.g. `docs/specs/v0_combat_lethality.md` §9 has 21 numbered criteria). No spec → no build. |
| Visual brief before any art/visual build | art-director | Brief with subject, silhouette, palette, size, required tests (e.g. `docs/briefs/arena_rendering.md`). |
| Build matches spec + brief | gameplay-programmer | Parse gate clean; deviations from spec listed explicitly for designer review (the lethality build filed "12 spec interpretations" for review — that is the expected shape). |
| QA verdict with EVIDENCE | qa-playtester | Screenshots, position/velocity logs, repro steps, measured numbers vs the spec's numbered criteria. QA breaks it AND judges feel. QA does not fix code — findings route back to the programmer. See skill `gottabounce-validation-and-qa`. |
| Art grade from IN-GAME screenshots | art-director | Verdict vocabulary Ship / Fix (numbered) / Reject. Never grades raw asset files. See skill `gottabounce-art-pipeline`. |
| Integration + commit + STATUS | Studio Director | Resolves disagreements, owns the merged result. |

Reviewers grade against a **written standard** (spec criteria, art brief) and can say Reject. A
review that produces no findings and no measurements is a rubber stamp — treat it as a failed
review, not a pass.

## 4. Change classification — what gate each class needs

Derived from observed practice in git history and the docs of record (as of 2026-07-03):

| Change class | Examples from history | Required gate before commit |
|--------------|----------------------|----------------------------|
| **Tuning tweak** (value change in Tuning.gd, no new mechanic) | `laser_close_time` 10→6; `smash_impact_min` 800→900 | Must be a knob a spec sanctions (specs ship "fallback knobs", e.g. lethality spec "Out of scope / fallback knobs") or a designer-signed change. Live-tune via gbplay eval first, measure, then persist + rendered playtest. Feel-relevant changes need designer sign-off. See skill `gottabounce-tuning-and-flags` for the runbook. |
| **Mechanic change** (new/changed behavior) | un-charged super (03894ac); dry-reflect gate (spec v2.1) | Full loop: spec with numbered criteria → build → rendered QA pass against those criteria → Director commit. Structural redesigns also get a DECISIONS.md entry with a reopen condition. |
| **Bug fix** | 587d0a1 fix round (5 fixes) | Fix + targeted verification of the specific finding with numbers (e.g. "victim ring-out 6/6 @1.12s", "idle P1 scored 0"), recorded in STATUS. A fix that changes semantics beyond the bug (587d0a1's bumper refund did) triggers designer review — that miss cost a whole QA re-verification cycle (§9 below). |
| **Art** | asset drops a899430, db06693, 1623863-era | Art-director brief BEFORE generation; `tools/art.py` intake checks; grade from in-game screenshots; CATALOG.md entry. See skill `gottabounce-art-pipeline`. |
| **Level** | `levels/dev_arena.json` bounds tightening (lethality spec §2.4) | Levels are JSON data, never code. Geometry changes that affect kill pacing are spec-governed (the blast-zone change shipped inside the lethality spec with its own rationale table). |
| **Doc/spec edit** | spec v2 → v2.1 (ea0c133) | Spec amendments carry a changelog header + version bump; superseding a design decision requires a DECISIONS.md entry (see §6). STATUS updates follow every commit regardless. |
| **Process/tooling** | run_game.ps1, gbplay.py additions | Prove the tool works (statically or by driving it), document in PIPELINE.md/CLAUDE.md if it changes the ritual. |

If a change spans classes, it takes the strictest applicable gate.

## 5. DO-NOT-TOUCH and flagged constants

These are marked in `src/core/Tuning.gd` itself (as of 2026-07-03). Verify with:
`grep -n "DO-NOT-TOUCH\|DO NOT\|FLAGGED" src/core/Tuning.gd`

| Constant | Live value | Status | What touching it requires |
|----------|-----------|--------|---------------------------|
| `hitstun_base` (with `hitstun_per_impulse`, `hitstun_max` — the recovery triad) | 0.15 / 0.00025 / 0.55 | **DO-NOT-TOUCH** ("GDD §4.6 recovery triad is protected", Tuning.gd:87) | A designer ruling + re-test of BOTH directions of spec §9 test 6 (kill the fuel-starved AND survive with full-tank counter). The lethality spec's fallback section says outright: "Never touch hitstun." Kills-too-rare has sanctioned knobs instead (`smash_sting_fuel` 30→40, then `soft_bump_max` up). |
| `sudden_death_time` | 20.0 | **DO-NOT-TOUCH** (Tuning.gd:117) | Same bar: SD pacing is a spec-governed contract (≤25% of rounds enter SD, spec §9 test 11). |
| Super power scaling (not a constant — its absence) | `super_boost_impulse_full` = 2800, constant | **CLOSED DECISION** — "DO NOT re-introduce power scaling" (Tuning.gd:47–49; DECISIONS.md 2026-07-02) | Reopen ONLY with movement-course evidence (the DECISIONS entry names that exact condition). Power never scales with fuel or hold time; aim and timing are the only skill axes. |
| `fuel_per_bumper` | 20.0 | **RULED 2026-07-03** — stays 20.0, "not raised, not lowered" (DECISIONS.md 2026-07-03 dry-reflect ruling). NOTE: the Tuning.gd:36-38 comment still says "FLAGGED FOR DESIGNER REVIEW" — that comment is stale; the review happened. | Reopening the stunned-case refund/clear gate is explicitly closed: spec v2.1 fallback is "make the dry reflect more visible… Do not reopen the refund/clear gate." |
| `round_end_freeze` | 1.8 | Hard cap 2.0 (Tuning.gd:116 comment) | Stay under the cap; it protects the ≤4.5s turnaround contract (spec §9 test 21). |

Sanctioned tuning paths exist for pacing problems — use the spec's fallback knobs, in order
(`smash_impulse_from_attacker` 1.35→1.2 then `super_refire_lockout` 0.25→0.5 if rounds too short;
`smash_sting_fuel` 30→40 then `soft_bump_max` up if kills too rare). Full catalog and the
change-a-constant runbook: skill `gottabounce-tuning-and-flags`.

## 6. DECISIONS.md discipline

`docs/DECISIONS.md`: **one line (entry) per significant/irreversible decision, newest first.** An
entry needs: date, verdict, rationale, and — for anything that might be refought — an explicit
reopen condition. Worked examples from the live file:

- **Un-charged super** (2026-07-02): supersedes GDD §4.3 scaling AND the charge-hold
  implementation; rationale (the kill move was double-taxed); *"Reopen only with movement-course
  evidence."* — the model reopen clause.
- **Dry-reflect ruling** (2026-07-03): names the governing principle ("hitstun ends by TIME, never
  by touching a surface"), the root cause it closes, what it deliberately does NOT change
  (`fuel_per_bumper` stays 20), and the spec + QA criteria (6c/6d) that lock it in.
- **Goat identity** (2026-07-03): **Adopt-STAGED** — gated until movement courses validate the
  super-fantasy is fun, with an explicit reject condition (if bounce-chaining carries the fun,
  horns lose justification). The earlier 2026-07-02 "candidate only, no art now" entry stays in
  the file — superseded decisions get a NEW entry, never silent edits or deletions.

Rules of use:
1. Before proposing a design change, grep DECISIONS.md. If a closed decision covers it, you need
   the entry's reopen condition satisfied — with evidence — or you drop the idea.
2. A decision without a reopen condition invites relitigating. Write one.
3. Gated/staged things stay labeled gated (goat identity is adopt-STAGED, not adopted; movement
   courses are SPECCED, not built — as of 2026-07-03).
4. Format details and house style: skill `gottabounce-docs-and-writing`.

## 7. STATUS.md after every commit

The post-commit hook (`.git/hooks/post-commit`) prints, verbatim:

```
==============================================================
 STUDIO RULE: update docs/STATUS.md to reflect this commit
 (and docs/DECISIONS.md if a significant choice was made)
==============================================================
```

It **only prints** — it cannot block a commit and enforces nothing. The discipline is social, and
history shows it is followed: the log alternates code commits with STATUS commits (03894ac→74953c0,
587d0a1→bff3fd1, ea0c133→0e315b9, etc.). Treat "commit landed, STATUS not updated" as an
incomplete task, full stop. Known cosmetic drift: STATUS.md's "Last updated" header still says
2026-07-02 while recording 2026-07-03 commits (as of 2026-07-03) — fix it when you next update
STATUS, through a normal commit.

What a STATUS update contains and the doc authority order (Tuning.gd live values > DECISIONS >
newest spec > STATUS > older specs > docs/reference/): skill `gottabounce-docs-and-writing`. Note
one CLAUDE.md drift item relevant to change review: its read order lists `docs/ARCHITECTURE.md`,
which does not exist — only `docs/reference/ARCHITECTURE.md` (old project) does.

## 8. Commit conventions observed in history (as of 2026-07-03)

Verified against `git log` (25 commits, HEAD = 0e315b9):

- **Linear master, no branches, no reverts.** Single `master` branch; every commit is a working
  slice or its STATUS bookkeeping.
- **Small commits, one per working slice/fix** (PIPELINE.md §3). Message style: terse imperative
  summary, scope prefix when useful ("Spec:", "STATUS:", "Fix …").
- **Code commit paired with a STATUS commit** (or STATUS folded into the same commit when tiny).
- **Never `--no-verify`** (PIPELINE.md §3 verbatim). The only hook is the post-commit reminder,
  so there is no legitimate reason to skip hooks — wanting to is a signal you are routing around
  change control.
- Specs and decisions commit BEFORE the implementation that follows them (d262686 spec → 03894ac
  implementation; ea0c133 ruling → programmer fix as the recorded next task).

## 9. Worked live example: the bumper-save ruling (change control in motion)

This is the current state of the lethality slice as of 2026-07-03 (HEAD 0e315b9) and the best
template for how a finding becomes a change here:

1. **QA pass 1** on lethality v2 found a CRITICAL inverted-kill bug (landing a super was suicide,
   attacker died 9/9) → fix round 587d0a1, with per-fix verification numbers.
2. One of those fixes (`fuel_per_bumper=20` bumper refund + hitstun clear, enabling the owner's
   wall-return shot) changed semantics beyond the bug. QA flagged it as a **watch item needing
   designer sign-off** — it shipped anyway. That was the process miss.
3. **QA re-verification** (verdict recorded in STATUS, commit e57db01): core hinge PASSES (kill
   fuel-starved 9/10, full-tank counter-escape 10/10, chain credit 6/6) but FOUR criteria FAIL
   from ONE root cause — bumpers unconditionally cleared hitstun + refueled, so a bumper 660px
   inboard of the kill line saved every edge-bound smash victim. Verdict: **NOT clean-ship.**
4. **Designer ruling** (spec bumped to v2.1, commit ea0c133 + DECISIONS.md 2026-07-03 entry):
   "hitstun ends by TIME, never by touching a surface" — stunned-contact becomes a dry reflect
   (physics resolves, no fuel refund, no stun clear); `fuel_per_bumper` stays 20; the buffered
   super-through-empty-tank behavior reviewed and kept as-built. Two NEW QA criteria (6c dry-
   reflect kill retained ≥8/10, 6d wall-return shot fires ≥9/10) lock the ruling in.
5. **Open at HEAD:** programmer fix of `_on_bounced()` per §2.3a is the immediate next task, then
   a targeted re-run of spec §9 tests 11/13/14/15 + one clean wall-return-shot feel pass. Until
   that re-run passes, lethality v2 remains **implemented, NOT signed off** — do not describe it
   as shipped.

The lesson encoded: a fix that adds semantics is a mechanic change wearing a bug fix's clothes —
classify it as the former (§4) and get the designer ruling BEFORE commit, not after a failed
re-verification. Full incident chronicle: skill `gottabounce-failure-archaeology`.

## 10. Never do (routing around change control)

- Never claim "done"/"shipped"/"verified" from a parse gate or headless run. Rendered playtest
  with reviewed screenshots is the minimum bar.
- Never edit a DO-NOT-TOUCH constant (§5) or re-introduce super power scaling — closed decisions
  require their reopen conditions.
- Never `git commit --no-verify`, amend away history, or commit without updating STATUS.
- Never silently delete or rewrite a superseded design — file a DECISIONS entry.
- Never let a role self-grade: the programmer does not QA their own slice; QA does not fix code;
  reviews without evidence or pushback are failed reviews.
- Never start the next slice while the current one is unverified (depth-first — the live example:
  movement courses wait behind the lethality sign-off, per STATUS NEXT STEPS).
- Never hardcode a feel constant in an entity or geometry in code — Tuning.gd and JSON levels only.

## Provenance and maintenance

Verified 2026-07-03 against HEAD 0e315b9 (repo `D:\Dropbox\MyGames\GottaBounce - FablePause`), by
reading: CLAUDE.md, docs/STUDIO.md, docs/PIPELINE.md, docs/DECISIONS.md, docs/STATUS.md,
docs/specs/v0_combat_lethality.md (v2.1), docs/reference/LESSONS_LEARNED.md,
docs/reference/MASTER_BUILD_PLAN.md §5, src/core/Tuning.gd, .git/hooks/post-commit, git log.
All claims verified statically (no live game run; nothing here requires one).

Drift-prone facts — re-verify before relying on them:

- HEAD / open sign-off state (§9 will go stale first): `git log --oneline -5` + read
  `docs/STATUS.md` "NEXT STEPS". The programmer fix for spec §2.3a was pending at HEAD 0e315b9
  (an uncommitted `src/entities/Player.gd` edit was in the working tree on 2026-07-03).
- DO-NOT-TOUCH markers + values: `grep -n "DO-NOT-TOUCH\|DO NOT\|FLAGGED" src/core/Tuning.gd`
- Protected values (hitstun 0.15/0.00025/0.55, sudden_death 20.0, super impulse 2800,
  fuel_per_bumper 20.0): `grep -n "hitstun_\|sudden_death_time\|super_boost_impulse_full\|fuel_per_bumper" src/core/Tuning.gd`
- Newest decisions/reopen conditions: `head -60 docs/DECISIONS.md`
- Hook text: `cat .git/hooks/post-commit`
- Spec criteria count (§9 = 21 numbered, criterion 6 has subparts a–d at lines 498/500/503/509
  since v2.1). §9 starts at the "## 9. Success criteria" header; isolate and count it:
  `sed -n '/^## 9\./,$p' docs/specs/v0_combat_lethality.md | grep -cE "^(1?[0-9]|2[01])\. "` (expect 21),
  and confirm the top criterion exists: `grep -nE "^21\. " docs/specs/v0_combat_lethality.md`.
  (Do NOT use `grep "^[0-9]*\. \*\*"` — it also matches the 5 bold bot-intent items in §4 and
  misses criterion 21, which has no bold after its number.)

Known-stale upstream claims flagged in the body (do not "fix" them from a skill — repo edits go
through a normal session and this change-control process): Tuning.gd:38 "FLAGGED FOR DESIGNER
REVIEW" comment on fuel_per_bumper (review completed 2026-07-03); STATUS.md "Last updated" header;
CLAUDE.md pointing at nonexistent docs/ARCHITECTURE.md; LESSONS_LEARNED.md "owner is final QA"
clause (superseded by the AI-validation doctrine).

UNVERIFIED: none — every command, path, value, and quote above was checked against the repo on
2026-07-03.
