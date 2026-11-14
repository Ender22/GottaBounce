# CCGS import (2026-11)

Source: **Claude Code Game Studios v1.3.0** — MIT licence,
github.com/Donchitos/Claude-Code-Game-Studios. Read as a reference only; none of its scripts or
hooks were run or copied.

## What we took (adapted, not copied)
CCGS is built "collaborative, not autonomous" (ask the user, present options, "May I write
this?") and engine-generic. Everything below was rewritten for an autonomous studio with no human
reviewer, our rendered-validation pipeline (`tools/run_game.ps1` + `tools/gbplay.py`), and the
one-game-at-a-time port-9090 constraint.

| Ours | From CCGS | What survived |
|---|---|---|
| `.claude/agents/producer.md` | `producer` | backlog ownership, impact/cost ranking, dedupe; sprint/milestone/risk-register machinery dropped — `docs/BACKLOG.md` is the plan |
| `.claude/agents/accessibility-specialist.md` | `accessibility-specialist` | the visual/motor/audio/cognitive checklist and BLOCKING/ADVISORY + NOT ASSESSED discipline, retargeted to couch/TV distance and our player palette |
| `.claude/agents/sound-designer.md` | `sound-designer` | event-coverage and mix responsibilities; given scoped edit rights over existing audio and a hard ban on inventing/sourcing unlicensed audio |
| `.claude/agents/performance-analyst.md` | `performance-analyst` | profile-first, attribute-by-A/B, regression and leak tracking; wired to `gbplay perf`, eval recorders, `perf_gate.py` |
| `ui-ux-designer.md` "Screen checklist" section | `ux-designer`, `ui-programmer` | flow/state/input-completeness/feedback/"UI shows state, never owns it"/safe-area checks |
| skill `ux-review` | `ux-review` | checklist rigor; reviews the rendered screen with raw pad events instead of a spec document |
| skill `bug-triage` | `bug-triage` | priority-vs-impact classification, systemic hot-spot detection; writes `docs/BACKLOG.md` |
| skill `team-polish` | `team-polish` | phase pipeline + "verify the artifact exists" failure rule; our roles and gates |
| skill `soak-test` | `soak-test` | checkpoint cadence and growth-vs-T0 thresholds; bots play instead of a human |
| skill `scope-check` | `scope-check` | "additions without cuts are creep"; turned into a DO/SPLIT/DEFER/CUT depth-first guard |
| `.claude/settings.json` deny rules | its settings deny list | destructive git/rm/format guards, adapted by the Director |

## What we deliberately did NOT take
- **Collaborative-approval protocol** (ask-the-user, options menus, "May I write this?",
  `AskUserQuestion`, no-commit-without-user). Our owner never reviews; gates are role verdicts
  backed by rendered evidence, and the Director commits.
- **The 49-agent hierarchy** (leads/directors per department, engine-specific specialists for
  Unity/Unreal/Godot C#). We keep a flat roster of roles that each own a real gate; more layers
  would add hand-off loss with no reviewer to resolve it.
- **GDD / epic / story / sprint paperwork, gate IDs, registries, `project.yaml` config
  resolution.** Our docs of record are STATUS / VISION / GAME_ESSENCE / specs / BACKLOG; the
  paperwork targets a human-paced team.
- **Bash hooks and helper scripts** (`yaml-helper.sh` etc.) — untrusted, POSIX-centric, and would
  duplicate our post-commit STATUS reminder.
- **Its `CLAUDE.md` and settings files wholesale** — they would clobber our operating manual and
  permissions.
- **Its Godot engine route** (engine-reference docs, version-safety workflow) — unproven for Godot
  4.7 GDScript and redundant with our `gottabounce-*` skills, parse gate, and gotcha lists.
