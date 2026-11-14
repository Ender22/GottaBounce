---
name: scope-check
description: >-
  Depth-first guard for the autonomous loop: decide whether a GottaBounce backlog item (or an
  idea mid-task) deepens what exists or widens scope, whether it is worth its cost versus the rest
  of docs/BACKLOG.md, and whether it must be split, deferred, or cut. Returns DO / SPLIT / DEFER /
  CUT. Load before pulling any L-sized item, any new mode/circuit/system/content batch, any idea
  not already in BACKLOG, or when a slice keeps growing mid-build. Do NOT load for ranking a pile
  of findings (bug-triage) or for running the work (team-polish).
---

# Scope check

The last attempt at this game died by widening before anything was genuinely good (`CLAUDE.md`
non-negotiables; `docs/reference/` post-mortem). Run this honestly — new content is the most
tempting thing an unattended studio can do and usually the least valuable.

## 1. Read
The item; `docs/BACKLOG.md` (what it competes with); `docs/STATUS.md` (slice in flight, known
weak spots); `docs/GAME_ESSENCE.md`; newest `docs/feedback/` (did the owner ask for it?);
`docs/ROADMAP.md`. `git log --oneline -20` if the item claims something is unfinished.

## 2. Answer, one line each
1. **Deepen or widen?** Does it make an existing screen/mode/arena/verb better, or add a new one?
2. **Core verb:** which of BOUNCE / FLY / SUPER-SMASH / RECOVER does it serve? "None" is a red flag.
3. **Who notices?** Would a first-time couch group notice it within one session? Would its absence
   be a complaint?
4. **Cost:** S/M/L, roles needed (art generation and new systems are the expensive ones), and how
   much rendered QA it needs.
5. **Opportunity cost:** name the open P0/P1 items it would delay. Any open P0 -> it waits.
6. **Owner ask?** Explicit owner feedback overrides "widening" concerns (still split it).
7. **Growth check (mid-task):** compared with the item as written, what has been added since work
   started? Additions without a matching cut are creep.

## 3. Verdict
- **DO** — deepens the core, cost justified, no open P0 it would delay.
- **SPLIT** — worth it but L or vague: write the smallest S/M piece that delivers player-visible
  value first; the rest stays in BACKLOG.
- **DEFER** — widening, or fine but outranked; stays in BACKLOG at its real priority with the
  condition that would bring it back ("after menus pass ux-review").
- **CUT** — no core verb, nobody would notice, or duplicates existing value -> `## Won't do` with
  the reason.
```
Scope check: <item> -> DO | SPLIT | DEFER | CUT
Deepen/widen: ... | Verb: ... | Notice: ... | Cost: ... | Delays: ...
Action: <the split piece / the reopen condition / the cut reason>
```
The Director acts on it directly; no one else is asked. Never pad the verdict — "it would be cool"
is not a reason.
