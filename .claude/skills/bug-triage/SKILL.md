---
name: bug-triage
description: >-
  Turn raw findings (QA reports, creative-director verdicts, soak/perf/a11y/audio audits, owner
  feedback, STATUS notes) into ranked, deduped entries in docs/BACKLOG.md with priority P0-P3,
  size S/M/L, evidence, and owner; flag systemic hot spots. Load after any review or test pass
  produces findings, when BACKLOG.md feels stale or noisy, or when choosing the next item in the
  autonomous loop. Do NOT load for deciding whether an item is worth doing at all versus widening
  scope (use scope-check), or for running the tests that produce findings.
---

# Bug triage -> docs/BACKLOG.md

The producer owns `docs/BACKLOG.md` (format and ranking rules: `.claude/agents/producer.md`).
This is the recipe for feeding it. No approvals, no sprints — the ranked file IS the plan.

## 1. Collect
- The findings you were handed, plus anything new in `docs/STATUS.md` (NEXT-UP, "Watch out for"),
  `docs/feedback/` (newest first) and recent QA/CD reports referenced there.
- Read `docs/BACKLOG.md` (create it with `## P0`..`## P3`, `## Done (recent)`, `## Won't do` if absent).
- `git log --oneline -30` — anything already fixed?

## 2. Classify each finding
**Priority = player impact** (not effort, not who reported it):
| P | Means | Examples |
|---|-------|----------|
| P0 | Crash, softlock, screen/mode unplayable, pad input dead, a core verb broken, wrong winner | match parks forever; B does nothing on a screen; super never fires |
| P1 | A couch group would notice and complain | camera loses a player; can't tell P2 from P3; KO with no sound; unreadable prompt |
| P2 | Visible polish gap | seam on a platform; stiff transition; inconsistent button style |
| P3 | Nice-to-have | extra flair, alternate SFX, minor copy |
**Size = cost:** S one agent pass / 1-2 files; M one full slice (build -> rendered QA -> gate);
L multi-role or art generation or several slices — split it into M/S pieces before ranking.
**Evidence:** a screenshot path, repro steps, or a metric. Without it the entry is tagged
`unverified` and its first step is a qa-playtester re-check.

## 3. Dedupe and merge
Same root cause = one entry (keep every evidence link, note "seen N times"). Different symptoms of
one system failing 3+ times -> add a **systemic** line at the top of the band naming the system
(e.g. "CameraController: 3 framing bugs this week — needs a design pass, not more patches").

## 4. Rank and write
Within each band order by impact per cost (P1/S above P1/L). Depth-first: items on the slice in
flight, owner-feedback items, and creative-director fantasy gaps rise in their band; new-content
items fall below polish of what exists (run `scope-check` on them). Write entries in the
producer's format with the next free `BL-###` id. Move fixed items to `## Done (recent)` with the
commit hash — only with rendered evidence or a commit that QA verified. Things we deliberately
won't do go to `## Won't do` with one line of reason (the Director decides; nobody else asks).

## 5. Report back
Top 5 open (id, title, P/size, owner), counts per band, what was added / merged / closed, any
systemic flags. Keep it short — the Director pulls the top item next.
