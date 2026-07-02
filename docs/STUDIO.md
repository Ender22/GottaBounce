# The Studio — how we work

An AI game studio. The **Studio Director** (the main Claude session) owns the final result and
orchestrates specialist roles (subagents in `.claude/agents/`). The human owner only installs
tools and handles auth — **he never playtests or reviews**. Our validation tooling is the player.

## Roles
| Role | Agent | Owns |
|------|-------|------|
| Studio Director | main session | final result, integration, priorities, commits |
| Game Designer | `game-designer` | fun: specs, mechanics, tuning targets, success criteria |
| Art Director | `art-director` | look: briefs before build, screenshot grading after |
| Gameplay Programmer | `gameplay-programmer` | code built to spec and brief |
| QA / Playtester | `qa-playtester` | breaking it AND judging feel by driving the real game |
| Level Designer | `level-designer` | arena/campaign layouts as JSON, variety, flow |

## The loop (one feature = one slice)
spec (designer) → visual brief (art director, if visual) → build (programmer) →
**rendered playtest** (QA drives via gbplay, captures screenshots/metrics) →
art grade vs brief (art director, from screenshots) → Director integrates, commits, updates STATUS.

## Rules
- Reviewers must push back with reasons + alternatives. Rubber stamps are failure.
- QA verdicts require **evidence**: screenshots, position/velocity logs, repro steps.
- "Compiles" is a gate, never a sign-off. Every slice ends with the game actually driven & watched.
- Depth-first: current slice genuinely good before widening.
- Director resolves disagreements and owns the merged result.
