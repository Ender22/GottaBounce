---
name: gottabounce-research-frontier
description: The honest map of GottaBounce's five open research problems — places where this project could genuinely advance the state of the art (AI-studio-to-Steam with zero human playtesting, feel-as-numbers tuning, bots as feel-regression instruments, style-anchored AI art at production scale, parametric arena generation). Load this when asked "what is novel here", "what could we publish/claim", "what are the open problems", "is X proven yet", when writing outward-facing positioning, or when deciding whether a frontier idea is allowed to start now. Every problem here is OPEN/UNPROVEN with a falsifiable milestone. Do NOT load this for the discipline that turns a hunch into an accepted change (see skill gottabounce-research-methodology), for the executable feel campaign itself (see skill gottabounce-feel-campaign), or for what gates a commit (see skill gottabounce-change-control).
---

# GottaBounce research frontier — open problems, honestly framed

**What this covers:** the five problems where this repo has a real shot at advancing SOTA
(state of the art — the best publicly demonstrated result anywhere), each with: why current
practice falls short, what asset THIS repo specifically has, the first three concrete steps
in this repo, and a falsifiable "you have a result when…" milestone.
**When NOT to use this:** for the evidence bar and idea lifecycle → skill
`gottabounce-research-methodology`; for actually running the feel work → skill
`gottabounce-feel-campaign`; for measurement commands → skill
`gottabounce-diagnostics-and-tooling`; for change gates → skill `gottabounce-change-control`.

## Ground rules (read before quoting anything below)

1. **Every problem on this list is OPEN. Nothing here is a result yet.** Where partial
   in-repo evidence exists it is labeled exactly that. Do not restate any of these as
   achievements in any doc, commit message, or outward-facing text.
2. **The depth-first gate applies to frontier work.** `docs/STATUS.md` NEXT STEPS is the
   queue. As of 2026-07-03 the current slice is combat lethality v2.1, with the dry-reflect fix
   still pending sign-off (full incident → skill `gottabounce-failure-archaeology`, Incident 10).
   This state is VOLATILE — the pending `src/entities/Player.gd` fix will flip it; re-verify via
   `git log --oneline -1 -- src/entities/Player.gd` and STATUS before relying on it. **No new
   frontier hypothesis work starts while that slice is unverified** (see skill
   `gottabounce-research-methodology`, "when NOT to research"). Frontiers 2 and 3 are
   partial exceptions only because their instruments ARE the scheduled next work.
3. **No external-publication machinery exists in this repo.** No Steam export preset, no
   store assets, no marketing/wishlist docs, no blog, no human-playtest channel of any
   kind (grep for `wishlist|marketing` in `docs/` returns nothing; Steam appears only in
   the old project's plan, `docs/reference/MASTER_BUILD_PLAN.md` P20, and as STATUS NEXT
   STEPS item 5). Positioning claims wait for evidence — this file is the internal ledger
   of what WOULD be claimable and what each claim still needs.
4. Jargon used below, defined once: **rendered playtest** = launching the real windowed
   game and driving it with `python tools/gbplay.py` while capturing and LOOKING at
   screenshots (skill `gottabounce-run-and-playtest`). **round_stats** = the per-round QA
   telemetry dictionary PartyMatch records (`src/modes/PartyMatch.gd:47`:
   `{length_s, end_cause, entered_sd, kills[{killer,victim,off_stage}],
   survivor_had_contact, supers_fired[{who,fuel_at_fire,aim_time,auto_fired}]}`).
   **SD** = sudden death (lasers close in when a round runs long). **Feel verdict** = a
   written judgment, with evidence, of whether a mechanic feels good (QA's duty, skill
   `gottabounce-validation-and-qa`). **Blinded verdict** = a feel verdict filed by a judge
   who does not know which build variant they are testing or what outcome was predicted.

---

## Frontier 1 — An AI studio ships a Steam-quality game with ZERO human playtesting

**Status: OPEN.** The studio doctrine exists and has 3 sessions of practice; the claim is
completely unproven until real external humans play a build.

**Why current SOTA fails.** AI-built games to date are validated either by "it compiles /
tests pass" (which this project's predecessor proved worthless — the old repo built phases
P0–P15, P17 and P18, skipping P16, and only P1 was ever run-verified) or by a human playtester in the loop. Game FEEL
judgment is assumed to require humans. No demonstrated pipeline ships a feel-driven game
where every feel verdict was machine-derived. (UNVERIFIED: this characterization of the
outside world is an assessment as of the 2026 knowledge cutoff, not a repo fact.)

**This repo's specific asset.** A complete, exercised validation stack that replaces the
human: rendered playtest driving via `tools/run_game.ps1` + `tools/gbplay.py` (TCP 9090),
screenshot vision review, headless `scenes/Playtest.tscn` sims, and an adversarial role
structure (`docs/STUDIO.md`: five specialist roles, "rubber stamps are failure", QA judges
feel with evidence and does not fix code). This stack has already caught bugs no compile
step could: the inverted-kill bug (landing a super was suicide, attacker died 9/9 — found
by QA driving the game, fixed 587d0a1) and the bumper-save pacing bug (found by the
2026-07-03 metric re-verification, ruled in spec v2.1). The human owner installs tools
only — he has never playtested (CLAUDE.md, `docs/STUDIO.md`).

**First three steps in this repo:**
1. Finish the current slice end-to-end under the doctrine: lethality v2.1 fix → targeted
   re-run of spec §9 tests 11/13/14/15 + 6c/6d → designer sign-off → STATUS. The frontier
   claim is only as strong as the discipline's unbroken record.
2. Make feel verdicts durable. Today they live in agent transcripts and STATUS summaries.
   Propose (through skill `gottabounce-docs-and-writing` + change control) a
   `docs/verdicts/` convention: one file per slice, verdict + evidence artifacts listed,
   so a future external-human comparison can be scored verdict-by-verdict.
3. When STATUS NEXT STEPS reaches item 5 (Steam prep — do not jump the queue), define the
   external-validation proxy IN WRITING BEFORE any build goes out: which metric
   (playtest-program feedback, demo reviews, wishlist conversion) counts, and what number
   counts as confirmation.

**You have a result when…** an externally distributed build whose every feel verdict was
AI-derived receives independent human feedback, and the humans surface **no major
feel-category defect that the verdict ledger had signed off as good**. Falsified the day
external humans find a feel problem the stack certified — that outcome must be recorded in
`docs/DECISIONS.md`, not buried.

---

## Frontier 2 — Feel-as-numbers: objective, pre-registered feel tuning

**Status: OPEN — instrument specced, not built.** Movement courses are STATUS NEXT STEPS
item 2; zero course JSON, CourseMode scene, or course_stats code exists at HEAD.

**Why current SOTA fails.** Game-feel tuning is craft: tune, play, repeat, with a human's
sensation as the only measurement. Nobody has an accepted method that turns "this feels
great" into numeric predictions made BEFORE the change and checked after. (UNVERIFIED:
outside-world assessment, as above.)

**This repo's specific asset.** `docs/specs/v1_movement_courses.md` — five courses that
each isolate one mechanic, each shipping a **pre-registered pass/fail script pair** (the
P-script must clear, the F-script must fail — the fail cases prove the course measures
something), a constant→course coverage map (spec §3), telemetry
(`course_stats = {time_s, attempts, fuel_min_seen, bounces, supers_fired[],
reached_checkpoints[]}`, spec §1), and mandatory written feel verdicts (spec §4 criterion
5). Plus a working precedent: the lethality spec predicted SD ≤25% before implementation;
the first 8-round smoke measured 12.5% (STATUS session 3), and the same metric later
flagged the bumper-save regression at 27–33%.

**First three steps in this repo:**
1. Build courses 1–3 exactly per spec (this IS the scheduled next work after lethality
   sign-off — see skill `gottabounce-feel-campaign` for the phased plan).
2. For the first Tuning constant changed after courses exist: write the predicted course
   telemetry delta and round_stats delta in STATUS/spec BEFORE running, per skill
   `gottabounce-research-methodology` (prediction-first). One constant at a time (spec §3
   binding workflow).
3. Accumulate a predicted-vs-measured ledger (≥10 pairs) across the tuning loop; compute
   the hit rate. A method that can't out-predict a coin flip is not a method.

**You have a result when…** a constant change predicted in writing to improve specific
course metrics (a) measures as predicted AND (b) flips a **blinded** feel verdict — at
minimum a fresh-context QA agent driving A/B build variants (constant toggled via gbplay
eval) without knowing which is which or what was predicted. The ultimate bar is blinded
HUMAN verdicts, and **no human channel exists in this repo today** — say so in any writeup.
Falsified if metrics improve while blinded verdicts don't move (the numbers aren't
capturing feel).

---

## Frontier 3 — Bots as feel-regression instruments

**Status: OPEN, with partial in-repo evidence (one uncorroborated catch).**

**Why current SOTA fails.** QA bots in industry test crashes, soak, and pathing — not
feel. Using human-simulating bots (skill dials, never cheating) as regression detectors
for feel constants, with skill-hierarchy assertions as the tripwire, is not an established
practice. (UNVERIFIED: outside-world assessment.)

**This repo's specific asset.** `src/core/BotProfile.gd`: 12 execution-quality dials
(aim_error, reaction_time, recovery_skill, aggression, target_lead, commit_time,
attack_range, refuel_floor, super_aim_time, edge_guard, leader_focus, dodge_super) with an
L1–L5 table (lethality spec §3.1); bots read the same InputIntent surface as humans (they
shape execution, never cheat). The lethality spec encodes skill-hierarchy assertions as QA
criteria: test 13 (L4 beats L2 ≥4/5 matches, L2 wins 0/5), test 14 (idle human punished),
test 16 (dodge-super observable). **The partial evidence:** on 2026-07-03 the bot-driven
metric battery caught a real regression — L2 won 1/5 matches and SD hit 27–33% (tests
13/11 FAIL), and the root cause was a genuine mechanic bug (bumpers unconditionally
clearing hitstun, saving every edge-bound victim). The unproven half of the claim is
"…that humans confirm": no human has ever corroborated a bot-detected feel regression.

**First three steps in this repo:**
1. After the v2.1 fix lands, re-run tests 11/13/14/15 (spec §9 marks each "re-run
   required") and record whether the bot metrics recover exactly as the spec predicts —
   that closes the loop on the one existing catch.
2. Make the battery standing and cheap: the extraction surface and PASS/FAIL script
   already exist (see skill `gottabounce-diagnostics-and-tooling` — `match_stats.py`
   against round_stats). Run it after every combat-touching commit.
3. Calibrate the instrument: in a live-tune session (gbplay eval only, never committed),
   inject one known-bad constant (e.g. a change the fallback-knob ladder forbids) and
   verify the battery flags it. An alarm that can't detect a planted fault is decoration.

**You have a result when…** a feel regression first detected by bot-derived metrics is
independently confirmed — by an external human once a channel exists, or interim by a
blinded human-style AI playtest that was given no metric data — as a real feel problem.
Falsified if planted known-bad changes pass the battery, or if bot-flagged "regressions"
repeatedly turn out to be measurement artifacts (that already happened once in the OTHER
direction: the 2026-07-03 interrupted-QA scare was a mis-hooked recorder, not a real
regression — instrument error is a live failure mode, treat it per skill
`gottabounce-research-methodology`).

---

## Frontier 4 — Style-anchored AI art at production scale

**Status: OPEN.** Proven at ~22 assets / 1 theme / 1 arena; the claim is about 60+ arenas
across 6+ themes (`docs/VISION.md` scope target, which also names 15–20 powerups and 8+
playable Bouncers).

**Why current SOTA fails.** AI image generation drifts: across hundreds of generations,
palette, proportion, and rendering style wander, and shipped games solve this with human
artists correcting or repainting. A full game art set held coherent by generation
discipline alone is undemonstrated. (UNVERIFIED: outside-world assessment.)

**This repo's specific asset.** A style chosen FOR generatability — "Glossy Toybox" blob
characters were adopted partly because blobs are the most consistently generatable shape
(`docs/DECISIONS.md` 2026-07-02, `docs/VISION.md`); a persistent style anchor
(`assets/reference/style_north_star.png` + the verbatim base-style prompt suffix in
`assets/CATALOG.md`); mechanical guards for known generation failures (`tools/art.py
check` catches baked fake-checkerboard transparency, `keyout --tol 40` fixes it); and an
adversarial grader — the art-director role grades IN-GAME screenshots only, verdicts
Ship/Fix/Reject (see skill `gottabounce-art-pipeline` for the full system). Note the goat
identity is ADOPT-STAGED, gated on movement courses validating the super fantasy
(`docs/briefs/art_goat_identity_eval.md`) — do not count goat art as scheduled volume yet.

**First three steps in this repo:**
1. Clear the STATUS art fix list (a)–(i) within theme 1 — proves the pipeline can maintain
   coherence under revision, not just first-pass generation.
2. When STATUS NEXT STEPS reaches item 4's second half (a second THEME after the 3–5 grass
   arenas), generate the full theme-2 asset set against the same style anchor and have the
   art-director grade cross-theme coherence from in-game screenshots, explicitly, as its
   own graded criterion.
3. Define a drift metric BEFORE scaling: per-batch first-pass grading pass-rate (Ship or
   single-round Fix→Ship). Track it per theme. Falling pass-rate with volume = drift is
   real and the claim dies at that volume.

**You have a result when…** a complete second theme passes art-director grading including
an explicit cross-theme coherence check, AND the first-pass pass-rate holds (does not
trend down) as asset count grows toward the 60-arena / 6-theme scope. Falsified if later
batches systematically need out-of-pipeline correction to stay on style.

---

## Frontier 5 — Parametric arena generation that passes a fun bar

**Status: OPEN — reserved intent only.** One hand-authored arena exists
(`levels/dev_arena.json`); zero generator code exists at HEAD.

**Why current SOTA fails.** Procedural content generation (PCG — algorithmic level
creation) for arenas routinely validates *playability* (connected, survivable) but not
*party-game quality*: a hook that creates stories, spawn fairness, readable-at-full-zoom
composition. Generated levels that pass the same editorial bar as hand-authored ones,
cheaply, remain open. (UNVERIFIED: outside-world assessment.)

**This repo's specific asset.** Levels are already pure data with theme and geometry
separated: JSON with `bounds`, `platforms[{x,y,w,h,tier}]` using the 4-tier + bumper
surface vocabulary, and `objects[]` (player_spawn, powerup_spawner), loaded by
`src/core/LevelLoader.gd` — `docs/VISION.md` risk plan explicitly reserves "parametric
generation later (chaos/density/theme dials)". Crucially, a machine-checkable validation
bar is already written into the level-designer role (`.claude/agents/level-designer.md`):
load rendered + screenshot review, spawn fairness, camera framing, a bot survives 30s in
the headless harness, one hook per arena, no standable ground.

**First three steps in this repo:**
1. Hand-author the 3–5 grass arenas first (STATUS NEXT STEPS item 4). A generator needs a
   corpus that defines what "hook" and "fair" look like here; generating from a corpus of
   one is curve-fitting to an anecdote.
2. Turn the validation bar into code before writing any generator: a harness that takes an
   arbitrary level JSON → headless `scenes/Playtest.tscn` botwar 30s + tunnel-frame check +
   spawn-distance fairness eval (the Playtest modes exist — see skill
   `gottabounce-run-and-playtest`), leaving only hook/readability to level-designer
   screenshot review.
3. Only then write generator v1 (dials: platform count, density, tier mix, bumper
   placement) and measure its harness pass-rate vs the hand-authored corpus.

**You have a result when…** generated arenas pass the SAME two-stage bar as hand-authored
ones (automated harness + level-designer screenshot grading) at a pass-rate that makes
generation cheaper than hand-authoring, and at least one generated arena ships into a
themed circuit on its merits. Falsified if every "shippable" generated arena required
hand-editing that exceeds the cost of authoring from scratch.

---

## What does NOT exist (never imply otherwise)

As of 2026-07-03, this repo has: **no** Steam export preset or store assets, **no** human
playtest channel, **no** marketing/publication docs, **no** movement course code or course
JSONs, **no** arena generator, **one** arena, **one** art theme, and a lethality slice
that is implemented but **not signed off** (v2.1 programmer fix pending). Any outward
claim drafted from this file must survive the evidence bar in skill
`gottabounce-research-methodology` first, and any artifact it requires goes through skill
`gottabounce-change-control`.

## Provenance and maintenance

Written 2026-07-03 against HEAD `0e315b9` (verify: `git log --oneline -1`). All
verification static (no game launched). Facts checked and their one-line re-verification
commands:

| Fact | Re-verify |
|---|---|
| Current slice = v2.1 fix pending; QA re-verification resolved (recorder mis-hook, bumper-save bug) | `git log --oneline -6` + read `docs/STATUS.md` last two session-3 bullets |
| Uncommitted Player.gd fix in working tree | `git status --short` (shows `M src/entities/Player.gd`) |
| Dry-reflect ruling + tests 6c/6d, re-run list 11/13/14/15 | `grep -n "6c\|dry reflect\|re-run required" docs/specs/v0_combat_lethality.md` |
| round_stats shape (killer/victim/off_stage) | `grep -n "supers_fired" src/modes/PartyMatch.gd` |
| BotProfile 12 dials + L1–L5 | `grep -n "^var" src/core/BotProfile.gd` |
| Skill-hierarchy criteria 13/14/16 | `sed -n '477,560p' docs/specs/v0_combat_lethality.md` |
| Course spec: P/F pairs, course_stats, coverage map, ≤10-min battery | read `docs/specs/v1_movement_courses.md` §1–§4 |
| VISION scope 60+ arenas / 6+ themes / 15–20 powerups / 8+ Bouncers; parametric-generation reservation | `grep -n "60+ arenas\|parametric" docs/VISION.md` |
| Level JSON schema + tier vocabulary; single arena | `ls levels` + `head -30 levels/dev_arena.json` |
| Level-designer validation bar (bot 30s, fairness, hook) | read `.claude/agents/level-designer.md` |
| Goat identity ADOPT-STAGED (gated) | `grep -n "Adopt-staged" docs/DECISIONS.md` |
| Base-style prompt suffix + style anchor | `grep -n "Base style suffix" assets/CATALOG.md`; `ls assets/reference` |
| No publication machinery | `grep -ril "wishlist\|marketing" docs` (expect empty); Steam only in `docs/reference/MASTER_BUILD_PLAN.md` P20 + STATUS item 5 |
| Studio roles / owner-never-playtests | read `docs/STUDIO.md` + CLAUDE.md |

`UNVERIFIED:` items — (1) all "why current SOTA fails" characterizations of the outside
world are assessments as of the model knowledge cutoff, not repo facts; re-research before
any external claim. (2) The contents of the pending uncommitted `src/entities/Player.gd`
fix were deliberately not inspected or relied on. (3) The ~22-asset count is STATUS's own
figure, not independently recounted.

Maintenance: re-check this file whenever a frontier's first-3-steps land (courses built,
theme 2 started, arena corpus grown) or a milestone is hit/falsified — record hits and
falsifications in `docs/DECISIONS.md`, then update the status labels here.
