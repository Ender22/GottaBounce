---
name: gottabounce-docs-and-writing
description: Load when writing or updating any GottaBounce doc of record — updating docs/STATUS.md after a commit, adding a docs/DECISIONS.md entry, authoring a new spec in docs/specs/, writing an art/eval brief in docs/briefs/, recording owner feedback, or resolving a conflict between two docs (which doc wins). Also the home of the known-stale-docs list and the doc maintenance backlog. Do NOT load for what gates a change (see gottabounce-change-control), how to run QA or what counts as evidence (see gottabounce-validation-and-qa), or brief CONTENT specifics like palettes and prompts (see gottabounce-art-pipeline).
---

# GottaBounce — Docs of Record and House Writing Style

**What this covers:** the map of `docs/`, the authority order when docs conflict, the
STATUS.md-after-every-commit ritual, DECISIONS.md entry format, the house spec template, the
brief template, the owner-feedback pattern, house prose style, and the known-drift maintenance
backlog. All templates below are extracted from the REAL shipped docs, not invented.
**When NOT to use this:** what review/gate a change needs → skill `gottabounce-change-control`;
evidence doctrine and QA criteria discipline → skill `gottabounce-validation-and-qa`; art brief
content (palettes, prompts, grading) → skill `gottabounce-art-pipeline`; the full incident
stories referenced by doc entries → skill `gottabounce-failure-archaeology`.

## 1. The doc map

All paths relative to repo root `D:\Projects\GottaBounce`.

| Path | What it is | Update cadence |
|---|---|---|
| `CLAUDE.md` | Studio operating manual: non-negotiables, run commands, read order | Rare; Director only |
| `docs/STATUS.md` | THE handoff doc — where we are, what's next | **After EVERY commit** |
| `docs/DECISIONS.md` | Decision log, newest first | On every significant/irreversible choice |
| `docs/VISION.md` | Game identity, pillars, art direction | Rare |
| `docs/STUDIO.md` | Roles, the loop, review rules | Rare |
| `docs/PIPELINE.md` | Validation stack, art pipeline, git discipline | When the pipeline itself changes |
| `docs/specs/*.md` | Game-designer specs (4 as of 2026-07-03: `v0_round_loop`, `v1_powerups`, `v0_combat_lethality`, `v1_movement_courses`) | Versioned in-place (changelog in header) |
| `docs/briefs/*.md` | Art-director briefs/evals (2: `arena_rendering`, `art_goat_identity_eval`) | New file per brief |
| `docs/feedback/*.md` | Owner design input, verbatim-adjacent (1: `owner_2026-07-02_movement_feel.md`) | New file per feedback event |
| `docs/reference/*.md` | The OLD project's docs (good design, failed execution) | **Read-only. Never edit, never treat as current.** |

### Authority order when docs conflict

Highest wins. Cite the winner; if you notice the conflict, add it to the drift backlog (§8).

1. **`src/core/Tuning.gd`** — live constant values. Any doc quoting a number that disagrees with
   Tuning.gd is stale by definition.
2. **`docs/DECISIONS.md`** — closed decisions (e.g. un-charged super; hitstun ends by time).
3. **The newest spec version** on the topic (e.g. `v0_combat_lethality.md` v2.1 supersedes its
   own v1 text and GDD §4.3).
4. **`docs/STATUS.md`** — current state and open items.
5. **Older specs** whose sections were superseded (they keep their own changelogs).
6. **`docs/reference/`** — historical only. Known-stale files listed in §8.

`docs/feedback/owner_*.md` is a special case: it is the **highest-authority design INPUT**
("inputs to evaluation, not decrees" — the owner thesis is the bar), but it becomes binding only
via a DECISIONS.md entry after designer evaluation. Cite the DECISIONS entry, not the raw
feedback, when arguing a point is closed.

## 2. STATUS.md — the after-every-commit ritual

The post-commit hook (`.git/hooks/post-commit`) prints this after every commit — it does NOT
enforce anything (it only echoes; discipline is social, and git history shows it is followed:
code commits are routinely paired with a STATUS commit):

```
==============================================================
 STUDIO RULE: update docs/STATUS.md to reflect this commit
 (and docs/DECISIONS.md if a significant choice was made)
==============================================================
```

### Observed structure (keep it — a fresh context reads this file FIRST)

1. **Header block:** title, the one-line contract ("The single always-current handoff doc.
   Update after EVERY commit."), and a `**Last updated:**` line. Keep the date line current —
   it has drifted before (§8).
2. **`## Where we are`** — 5–8 lines: what the game IS right now, with screenshot pointers
   (`tools/out/*.png`).
3. **`## What exists (all validated, all committed)`** — numbered inventory: studio, validation
   stack, art pipeline, core game.
4. **`## Session N progress (LATEST at bottom)`** — one `## Session N progress` section per
   working session; checkbox bullets `- [x]`, appended in chronological order so the LAST bullet
   is the newest work. Never reorder; never rewrite history in old bullets.
5. **`## NEXT STEPS in priority order`** — numbered; item 1 is what a fresh session does first.
   Re-rank when priorities change; delete items only when done or explicitly retired.
6. **`## Watch out for (hard-won this session)`** — traps and gotchas worth a fresh context's
   attention.

### What a good session bullet looks like (real example, commit e57db01)

A bullet is a compressed report: bold headline verdict, evidence pointers, measured numbers vs
targets, and the explicit NEXT. E.g. STATUS's QA re-verification bullet leads with
"**QA RE-VERIFICATION COMPLETE — verdict: NOT clean-ship yet.**", names the evidence
(`tools/out/qa5_*.png`), lists PASS/FAIL per numbered criterion with the numbers
("test 11 FAIL (SD 27-33% vs ≤25%)"), states the single suspected root cause, and ends with
"NEXT: designer ruling …". Copy that shape.

### Rules

- Update STATUS in the SAME session as the commit it records, as its own commit
  (observed convention: `STATUS: <what changed>` commit messages).
- Record verdicts honestly, including FAILs and open items — STATUS is a truth log, not a
  changelog of wins. Unresolved investigations get flagged as blocking
  (e.g. "NOT QA-signed-off").
- If the commit closed or opened a "Watch out for" item, edit that section too.
- If a significant/irreversible choice was made, ALSO add a DECISIONS.md entry (§3) —
  the hook text says so.

## 3. DECISIONS.md — the decision log

Header contract (verbatim from the file): "One line per significant/irreversible decision.
Newest first." In practice "one line" means **one bullet per decision** — mature entries are
dense multi-line paragraphs, but each is a single self-contained bullet. Newest-first ordering
is strict: prepend, never append.

### Anatomy of an entry (extracted from the real 2026-07-03 entries)

```
- **YYYY-MM-DD** ALL-CAPS HEADLINE WITH VERDICT (context tag): governing principle or ruling in
  bold where there is one. Root cause / rationale — why, with the numbers. What exactly is
  decided (exact constants, exact behavior). What was considered and rejected, and why.
  Pointer to the full doc: `docs/specs/...` §N or `docs/briefs/...`. Reopen condition.
```

Load-bearing parts:
- **Date + ALL-CAPS verdict headline** ("GOAT IDENTITY EVAL COMPLETE — verdict **Adopt-staged**",
  "SUPER BOOST REDESIGNED (owner movement-feel directive, evaluated & adopted)").
- **Rationale with numbers**, not adjectives.
- **Reopen condition** — every closing decision states what evidence would reopen it. Real
  examples: "Reopen only with movement-course evidence" (un-charged super); the goat entry's
  gate ("gated until … movement courses validate the super-fantasy is actually fun").
- **Pointer to the deep doc** (spec §, brief) — DECISIONS is the index, not the essay.

### The double-entry supersede pattern (worked example)

Decisions evolve by ADDING entries, never editing old ones:
1. **2026-07-02** "THEMING SEED RECORDED — 'crazy goats' … Status: **candidate identity only** —
   art director must evaluate … No art now."
2. **2026-07-03** "GOAT IDENTITY EVAL COMPLETE — verdict **Adopt-staged**: … gated until …" —
   a NEW entry above the old one, naming the new status and the gate.

Same pattern for rulings that close QA findings: the 2026-07-03 bumper/bounce-recovery entry
names the root cause (fix-round 587d0a1's unconditional `_on_bounced()` refund), states the
governing principle ("hitstun ends by TIME, never by touching a surface"), lists the rejected
alternatives with reasons, and points at spec §2.3a. When you supersede, your new entry must
name what it supersedes.

What gates whether something IS a decision worth an entry, and who may make it →
see skill `gottabounce-change-control`.

## 4. Spec house template (extracted from the 4 real specs)

File: `docs/specs/vN_<topic>.md`. Versioning is IN-PLACE: one file per topic, version bumps go
in the header changelog (lethality is on v2.1 in the same file that shipped v1). Skeleton:

```markdown
# Spec: vN <Topic> — <one-line thesis>

> **Owner:** Lead Game Designer. **Status:** <READY FOR BUILD | ...>. **Version N — date.**
> **vN changelog (date):** what changed and WHY, naming what it supersedes.
> Responds to: <the QA finding / owner directive that triggered this, with its numbers>.
> Sources: `docs/VISION.md`, relevant reference docs, `src/core/Tuning.gd`, the code files.

## The player fantasy
One paragraph in the player's voice — bold opening quote. ("I read their arc, I pulled the
trigger, and they're GONE.")

## Why vN (design rationale — read before arguing with the numbers)
The reasoning, checked against the pillars.

## 1..N. Mechanic sections
Exact behavior. Tuning changes as tables: | Constant | Current | New | Rationale |.
Explicit edge cases. Amendments get lettered subsections (§2.3a) so criteria can cite them.

## <N-1>. New/changed constants — one block (implementation checklist)
A single fenced block: changed / REMOVED / new constants grouped, plus DO-NOT-TOUCH lines.

## <N>. Success criteria (QA-verifiable via gbplay eval + screenshots)
NUMBERED, measurable criteria with exact thresholds and sample sizes ("ring-out ≤2.5s in
≥8/10"). Grouped by theme. This section is the QA contract.

## Out of scope / fallback knobs
What's excluded; ranked fallback knobs with direction and the forbidden knobs named
("Never touch hitstun, and never re-introduce power scaling on the super").
```

Hard rules observed across all four specs:
- **Every spec ships numbered, measurable QA criteria** (round_loop 19, powerups 17,
  lethality v2.1 has 21 numbered tests — several with lettered sub-tests like 6a–6d). Criteria
  discipline and how a pass is run → skill `gottabounce-validation-and-qa`.
- **Numbers not adjectives**, with the derivation shown (lethality §1.3 ships a decay table).
- **Fallback knobs are pre-committed in the spec**, so tuning under pressure can't improvise
  past a protected constant.
- Superseded sections stay in the file, marked by the changelog — the spec is its own history.
- A spec that responds to a QA finding quotes the finding's numbers in the header
  ("kills feel like traffic accidents; 55–60% laser-decided").

## 5. Brief template (art-director briefs and evals)

Two real shapes in `docs/briefs/`; both end in an explicit verdict vocabulary.

**Build brief** (`arena_rendering.md`): header blockquote (Author, Status: APPROVED FOR BUILD,
what it replaces, target + style ref); "the gap we are closing" (what's wrong, named); numbered
decision sections with rationale; exact palette hex tables and per-asset generation prompts;
math done in-brief (far-zoom px arithmetic); and a closing **grading checklist** the art
director will "Ship/Fix/Reject against", plus which screenshots to submit. The programmer
"implements this verbatim; I grade the result from in-game screenshots only."

**Evaluation brief** (`art_goat_identity_eval.md`): what's being evaluated + source screenshots
reviewed; **`## Verdict:`** near the top (vocabulary observed: ADOPT-STAGED; the grading side
uses Ship / Fix (numbered) / Reject); numbered evaluation sections; a cost/risk table; a
staging/trigger-point sequence (when to revisit); and an explicit **reject condition** ("if
movement-course testing shows the super boost is NOT the fun part … horns lose their
justification").

Brief CONTENT rules (palette discipline, prompts, intake) → skill `gottabounce-art-pipeline`.

## 6. Owner feedback docs

Pattern from `docs/feedback/owner_2026-07-02_movement_feel.md`, the only instance as of
2026-07-03. File name: `owner_<date>_<topic>.md`. Structure:
- Header blockquote declaring provenance and authority: "Verbatim-adjacent record of design
  direction from the studio owner … the highest-authority design input we have" + who must
  reconcile against it ("The game-designer role must reconcile every combat/feel spec against
  this document").
- The owner's points recorded faithfully (verbatim-adjacent: preserve his framing and hedges —
  "Maybe designing those courses reveals…" stays a hypothesis, not a decree).
- A closing **`## Standing instruction`** section stating what is binding vs what is input:
  "These are inputs to evaluation, not decrees — but the *thesis* … is the bar. Pass this
  forward into every spec review."

Owner input flows: feedback doc → designer evaluation → DECISIONS entry (that's where it
becomes binding) → spec. Do not skip the middle.

## 7. House style

Observed consistently across CLAUDE.md, STATUS, DECISIONS, specs, briefs:

1. **Imperative runbook voice.** "Update after EVERY commit." Not "it is recommended that…".
2. **Numbers, not adjectives.** "SD 27–33% vs ≤25% target", never "sudden death is too common".
3. **Evidence citations inline**: commit hashes (587d0a1), file paths with § refs
   (`docs/specs/v0_combat_lethality.md` §2.3a), screenshot names (`tools/out/qa5_*.png`).
4. **Bold for load-bearing phrases; ALL-CAPS sparingly** for verdicts and hard rules
   (NOT QA-signed-off, DO-NOT-TOUCH, READY FOR BUILD).
5. **Date-stamp volatile facts** (every DECISIONS entry, spec versions, "as of" claims).
6. **Blockquote headers** (`> **Owner:** … **Status:** …`) on specs, briefs, feedback docs.
7. **Tables and numbered lists over prose** for anything a reader must act on.
8. **Honest labels**: gated / candidate / adopt-staged / NOT signed off / watch item. A doc
   that oversells state is a bug.

## 8. Known doc drift — the maintenance backlog (as of 2026-07-03)

Verified against the repo 2026-07-03. **Fixing any of these edits repo files → goes through a
normal session and change control (see skill `gottabounce-change-control`); this skill must not
be used as license to hot-fix docs.** Until fixed, cite around them:

| # | Stale claim | Reality | Where |
|---|---|---|---|
| 1 | CLAUDE.md read order lists `docs/ARCHITECTURE.md` | File does not exist; only `docs/reference/ARCHITECTURE.md` (old project). The INV-1…13 invariants live only under docs/reference/ — accessible restatement: skill `gottabounce-architecture-contract` | CLAUDE.md "Read order" §4 |
| 2 | PIPELINE.md §2 says attach `assets/reference/style_sheet.png` | Actual file is `assets/reference/style_north_star.png` (arena brief cites it correctly) | docs/PIPELINE.md §2 |
| 3 | FEEL_REFERENCE starting numbers | Live Tuning.gd differs: gravity 2600→live 1600, normal_boost_accel 4200→4600, normal_boost_max_speed 650→760, super_boost_min_fuel 15→5. Live truth = `src/core/Tuning.gd` | docs/reference/FEEL_REFERENCE.md §2–3 |
| 4 | FEEL_REFERENCE + `docs/specs/v1_powerups.md` describe the CHARGED super (power scales with fuel/charge; `super_charge_time` etc.) | Dead model. Authority: `v0_combat_lethality.md` v2.1 §1 + DECISIONS 2026-07-02 — un-charged, constant 2800, drain-all. NEVER re-introduce scaling | v1_powerups.md lines citing "charge"; FEEL_REFERENCE §3 |
| 5 | STATUS.md header "**Last updated:** 2026-07-02 session 3" | File records 2026-07-03 commits (ea0c133 etc.) — header date drifted | docs/STATUS.md line 5 |
| 6 | STATUS QA re-verification bullet cites evidence "tools/out/qa5_*.png/.json" | qa5_*.png files exist; no qa5 .json does (only `tools/out/qa3_match2_log.json`) — minor stale evidence pointer | docs/STATUS.md session-3 list |

Do NOT "fix" drift by editing `docs/reference/` files to match live values — reference docs are
historical record; the fix for #3/#4 is a stale-warning banner or a pointer, decided through
change control. Incident narratives behind these (why drift happened) →
skill `gottabounce-failure-archaeology`.

## Provenance and maintenance

Verified 2026-07-03 against repo HEAD `0e315b9` (branch master), statically only — no game run
(all facts here are doc/file facts; nothing needed a live run). Method: read in full
`docs/STATUS.md`, `docs/DECISIONS.md`, `docs/PIPELINE.md`, `docs/STUDIO.md`,
`docs/specs/v0_combat_lethality.md`, headers of `v0_round_loop.md` / `v1_powerups.md` /
`v1_movement_courses.md`, both briefs, the owner feedback doc, `.git/hooks/post-commit`
(quoted verbatim); greps against `src/core/Tuning.gd` and `docs/reference/FEEL_REFERENCE.md`
for the drift table; `ls` of `docs/`, `assets/reference/`, `tools/out/`.

Re-verification one-liners for drift-prone facts (run from repo root):
- STATUS structure/date header: `Read docs/STATUS.md` (check `**Last updated:**` vs `git log -1 --format=%cd`).
- Newest decision / supersede state: `Read docs/DECISIONS.md` (top entry).
- Spec version + criteria count: `grep -n "Version\|Status:" docs/specs/*.md`; highest test number: `grep -n "^21\. " docs/specs/v0_combat_lethality.md` (§9 tops out at test 21 as of v2.1).
- Hook text: `cat .git/hooks/post-commit`.
- Drift #1: `ls docs/ARCHITECTURE.md` (still absent → drift stands).
- Drift #2: `grep -n style_sheet docs/PIPELINE.md` + `ls assets/reference/`.
- Drift #3: `grep -n "^var gravity\|normal_boost" src/core/Tuning.gd` vs `grep -n "2600\|4200" docs/reference/FEEL_REFERENCE.md`.
- Drift #4: `grep -in charge docs/specs/v1_powerups.md`.
- Drift #6: `ls tools/out | grep -i "qa5.*json"`.

UNVERIFIED items: none load-bearing. Two soft observations labeled inline: the "STATUS commit
paired with code commit" convention is inferred from `git log --oneline` message shapes (e.g.
`STATUS: spec v2.1 ruling recorded…`), not from a written rule; verdict vocabulary
"Ship/Fix/Reject" appears in PIPELINE/STUDIO/brief text but only ADOPT-STAGED has been used as
a filed eval verdict so far.

Deviation from the authoring charter (repo won): the charter described HEAD as 4a550b2 with the
QA re-verification interrupted/unresolved and fuel_per_bumper awaiting sign-off; the repo is at
0e315b9 — re-verification is COMPLETE (verdict: not clean-ship), the designer ruling shipped as
spec v2.1 (commit ea0c133) and a DECISIONS 2026-07-03 entry, and fuel_per_bumper=20.0 is ruled
(unchanged). The charter also listed a FEEL_REFERENCE `laser_close_time 10 vs live 6` drift —
FEEL_REFERENCE.md contains no `laser_close` mention (the 10→6 change is documented in the
lethality spec §5 table instead), so that item is omitted from §8.
