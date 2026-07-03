---
name: gottabounce-failure-archaeology
description: The GottaBounce incident chronicle — every investigation, bug hunt, dead end, superseded design, and open case, with evidence and status labels. Load this when you are about to re-litigate a past decision, when a bug looks familiar ("wasn't this fixed?"), when you need the story behind a constant or a weird code comment (e.g. _stunned_by, dry reflect, fuel_per_bumper), when writing a post-mortem, or when onboarding and you want to know WHY the old project failed. Do NOT load this for live triage of a current symptom (use gottabounce-debugging-playbook), for the rules that gate changes (use gottabounce-change-control), or for what evidence a sign-off needs (use gottabounce-validation-and-qa).
---

# GottaBounce failure archaeology — the chronicle

**What this covers:** the settled history — the old project's founding failure, every rebuild
incident (symptom → root cause → evidence → fix commit → status), designs that were tried and
killed, the one big resolved investigation, and the honest list of what is still OPEN as of
2026-07-03. Read it so you do not refight settled battles or trust stale docs.
**When NOT to use this:** you have a live symptom right now → `gottabounce-debugging-playbook`
(triage tables). You want the rule/process a change must pass → `gottabounce-change-control`.
You want how to measure or what counts as proof → `gottabounce-diagnostics-and-tooling` /
`gottabounce-validation-and-qa`. You want why the architecture is shaped this way →
`gottabounce-architecture-contract`.

**Status labels used below:**

| Label | Meaning |
|---|---|
| SETTLED | Decision/lesson closed. Reopening needs the recorded reopen condition. |
| FIXED-VERIFIED | Fix committed AND re-measured passing (numbers cited). |
| FIXED-UNVERIFIED | Fix committed; the confirming measurement has not been run (or was inconclusive). |
| OPEN | No fix in code yet, or verdict still owed. |
| GATED | Deliberately not built; has an explicit un-gate trigger. |

All match metrics below (e.g. "9/9", "72.7%") are **as recorded** in `docs/STATUS.md`,
`docs/DECISIONS.md`, and commit messages by the sessions that measured them — this skill verified
the records and the code, not the live runs (verified: static, 2026-07-03).

---

## 1. The founding failure: the OLD project (why this repo exists)

The previous attempt lives untouched at `D:\Dropbox\MyGames\GottaBounce` (its docs are copied to
`docs/reference/`). It failed on **execution, not design**. Status: **SETTLED** — this is the
origin story of every non-negotiable in CLAUDE.md.

- **What happened:** breadth-first, blind execution. All ~18 phases (core → powerups → campaign →
  bosses → progression → menus) were code-built in sequence, validated only by headless Godot
  "loads without script errors". Per `docs/reference/MASTER_BUILD_PLAN.md` §5 change log:
  *"Status = code-built per phase, NOT yet run-verified (owner verified P1 only). Owner authorized
  building straight through w/o waiting for tests."* Only P1 (core bounce) was ever run-verified
  by a human.
- **Owner verdict on first play:** *"feels barely at proof-of-concept"*
  (`docs/reference/LESSONS_LEARNED.md`).
- **The concrete failures** (all would have surfaced in minute one of a real playtest): gamepad
  controlled nothing in the default match; HUD showed bot fuel gauges; bounce ~2× too high
  (owner wanted ~2–2.5× char height, got 4–6×); flat `Polygon2D` rectangles instead of art;
  OS-default-widget menus the owner "rightly hated"; a `class_name` colliding with a native class.
- **The structural cause:** a lone coder that both made and graded its own work — "I wrote it and
  it runs" collapsed design, art, code, and QA into one voice. The fix is the role-based studio
  (`docs/STUDIO.md`) where reviewers must push back.
- **What was RIGHT and got kept:** the architecture seams (gravity-as-field, body-agnostic bounce,
  one radial impulse, kill pipeline, JSON levels, InputIntent) held up — adding features was
  additive with no rewrites. See skill `gottabounce-architecture-contract` for the INV invariants.
- **The doctrine it produced** (deep home: `gottabounce-change-control`): depth-first slices;
  headless = crash gate only; "compiles" is a gate, never a sign-off; look like a real game from
  day one.

---

## 2. Rebuild incident chronicle (2026-07-02 → 07-03, newest last)

The rebuild repo has 25 linear commits on `master`, no branches, no reverts. Each incident below:
symptom → root cause → evidence → fix → status.

### Incident 1 — "Nothing was lethal" (the founding combat bug)
- **Symptom:** session-2 QA round-loop pass: kills felt like "traffic accidents", lasers decided
  ~55–60% of rounds, an L2 (weak) bot won a match, an idle human scored 9.
- **Root cause (found by reading code, not playing):** `smash_impact_min` (800) >
  `normal_boost_max_speed` (760) — the smash gate was **mathematically unreachable** by a
  deliberate boost-ram. Recorded in commit `d262686` title.
- **Fix:** lethality spec v2 (`docs/specs/v0_combat_lethality.md`) replaced the raw threshold with
  a **smash license** model (only super-active attackers and stunned flying bodies can smash;
  threshold now 900 as an anti-graze gate, `src/core/Tuning.gd:80`), implemented in `03894ac`.
- **Status: FIXED-VERIFIED** — QA re-verification: kill fuel-starved 9/10, ring-outs carry rounds.
- **Lesson (method home: `gottabounce-analysis-toolkit`):** run a reachability audit on every
  threshold before shipping it.

### Incident 2 — Inverted kill: landing a super was suicide (CRITICAL)
- **Symptom:** QA pass 1 on lethality v2: the ATTACKER died 9/9 after landing a super; victim
  survived 10/10; chains 0/3; an idle P1 won a match.
- **Root cause:** a smashed (stunned) body is a licensed smasher by design (Pillar-3 chains). The
  victim exits at speed cap while the attacker keeps only `smash_self_retain` (10%) of its speed —
  so the victim's own out-flying body was the faster body and **counter-smashed its attacker the
  very next frame**.
- **Fix (`587d0a1`):** `_stunned_by` pairwise smash immunity in `src/entities/Player.gd`
  (declared ~line 49; eligibility check `b != _stunned_by` in `_handle_smashes()` ~line 616,
  as of 2026-07-03). Your stunned body stays a weapon against everyone EXCEPT your stunner.
- **Status: FIXED-VERIFIED** — fix round: victim ring-out 6/6 @1.12s with attacker surviving;
  re-verification: 6a kill 9/10, 6b full-tank counter-escape 10/10 (control without counter:
  dies 6/6).
- **Lesson:** frame-order/state analysis for any contact rule (both bodies, frames N and N+1) —
  see `gottabounce-analysis-toolkit`.

### Incident 3 — Idle point-farming via chain-body kills
- **Symptom:** chain kills credited the flying BODY, not whoever launched it → an idle P1
  scored 12 points doing nothing.
- **Fix (`587d0a1`):** when a stunned flying body smashes someone, `credit_attacker()` reassigns
  kill/score credit to `_stunned_by` (the launcher) — `src/entities/Player.gd` ~lines 629–631.
- **Status: FIXED-VERIFIED** — idle P1 12 → 0; chain credit to launcher 4/4 in the fix round,
  6/6 in re-verification (test 9).

### Incident 4 — Super chain input eaten
- **Symptom:** holding super through the refire lockout or an empty tank (right after firing) was
  dropped — fast super→bounce→super chains needed a frame-perfect re-press.
- **Fix (`587d0a1`):** the held press re-buffers every held frame (`_sb_buffer =
  Tuning.input_buffer`), so AIM starts on the first legal frame.
- **Status: FIXED-VERIFIED** — re-verification noted "chain buffer immediate". The
  buffer-through-empty-tank semantics were reviewed by the designer 2026-07-03 and **kept
  as-built** (cannot fire off a dry reflect — no fuel — so not an exploit; DECISIONS 2026-07-03).

### Incident 5 — Wall-return shot impossible (dry bumpers)
- **Symptom:** the owner's signature fantasy — miss, rebound off the wall, fire the return shot —
  could not happen: bumper rebounds refunded no fuel, and drain-all supers leave you empty.
- **Fix (`587d0a1`):** bumpers refund fuel via new `fuel_per_bumper = 20.0`
  (`src/core/Tuning.gd:36`), routed through `_on_bounced()`.
- **Status: FIXED-UNVERIFIED (feel side)** — spec v2.1 test 6d (wall-return fires ≥9/10) is owed;
  the one human-capture attempt was inconclusive (test-session artifact). The fix also caused
  Incident 10 (read it before touching this code).

### Incident 6 — Fuse ring invisible at gameplay zoom
- **Symptom:** the super aim ring (a 7.0-width `Line2D` in world px) rendered ≈3px on screen at
  gameplay zoom 0.443 — the game's ONE kill telegraph was unreadable.
- **Fix (`587d0a1`):** screen-space constant width `super_ring_screen_width = 9.0` + dark backing
  ring (`super_ring_outline_extra = 6.0`) + minimum frame-1 arc (`super_ring_min_arc = 0.15`),
  `src/core/Tuning.gd:63-65`.
- **Status: FIXED-VERIFIED** — re-verification: "fuse ring readable". (The earlier watch item
  "frame-1 arc minimal" was addressed by `super_ring_min_arc`.)
- **Lesson:** readability must be specified in SCREEN pixels at gameplay zoom, never world units.
  Theory home: `game-feel-reference`.

### Incident 7 — Four powerup bugs caught pre-commit (validation working as intended)
- During v1 powerup validation (`cdd925d`, 2026-07-02), four real bugs were found and fixed
  BEFORE commit: CPUParticles2D lifetime-write restart, black-hole self-cancel, pull-vs-air-brake
  interaction, ring readability. **Status: FIXED-VERIFIED** (all spec criteria measured PASS at
  commit). This is the positive example: rendered validation catches what "compiles" cannot.

### Incident 8 — Art pipeline silent corruption
- **(a)** A missed ChatGPT download click silently reused the PREVIOUS downloaded file — this
  corrupted `hills_far` once. Guard: verify the Downloads-folder timestamp BEFORE intake.
- **(b)** Some generations bake FAKE checkerboard "transparency" into the pixels. Guard:
  `python tools/art.py check` catches it; `keyout --tol 40` fixes it.
- **Status: SETTLED** (procedural guards recorded in STATUS "Watch out for" + assets/CATALOG.md).
  Deep home: `gottabounce-art-pipeline`.

### Incident 9 — Old-project Godot gotchas that cost real time
One line each; stories in `docs/reference/LESSONS_LEARNED.md`, live triage in
`gottabounce-debugging-playbook`:
- `class_name` colliding with a native class silently resolves to the native one.
- Autoloads cannot reliably resolve `class_name` globals at parse time — use `load()`.
- Stale global class cache after adding `class_name` scripts — rebuild via `--editor --quit`.
- UI not under a `CanvasLayer` drags with the camera (and: only show what should be shown — the
  old HUD showed bot gauges).
- The Playtest harness's `1/60` hardcode ran phases 2× fast at 120 ticks/s — now uses
  `Engine.physics_ticks_per_second` (`src/dev/Playtest.gd:39-40`).

### Incident 10 — The bumper-save bug: Incident 5's fix broke edge kills (NEWEST)
- **Symptom (QA re-verification, 2026-07-03):** four §9 criteria failed together — test 15 FAIL
  (1 off-stage kill in 23 rounds vs ≥3/10 target), test 11 FAIL (SD rate 27–33% vs ≤25%), test 13
  partial FAIL (L2 won 1/5 idle matches vs 0/5), test 14 partial FAIL (idle P1 scored 3 once,
  cap ≤2).
- **One root cause:** fix-round `587d0a1` made `_on_bounced()` unconditionally refund fuel AND
  clear hitstun on EVERY bounce, including bumpers. A smashed victim flying toward the kill line
  always clipped the bumper ≈660px inboard of it and was auto-saved — **edge kills were
  un-earn-able**. (This was flagged as a watch item at fix time: "bumper hit clears hitstun —
  may suppress kills near side bumpers". The watch item was right.)
- **Ruling (designer, spec v2.1, commit `ea0c133`, DECISIONS 2026-07-03):** *"hitstun ends by
  TIME, never by touching a surface."* While `_stun_timer > 0`, any surface contact (tier or
  bumper, one uniform rule) is a **dry reflect**: the physical bounce resolves, FX/signals fire,
  but zero fuel refund and NO stun clear. Neutral contact unchanged — which preserves the
  wall-return shot by construction (that move never involves hitstun). `fuel_per_bumper` stays
  20.0. New tests 6c (dry-reflect kill retained ≥8/10) and 6d (wall-return fires ≥9/10) lock
  this in.
- **Status: OPEN — ruled but NOT implemented.** As of 2026-07-03 (HEAD `0e315b9`),
  `src/entities/Player.gd` `_on_bounced()` (~lines 550–562) still unconditionally clears
  `_stun_timer`/`_stunned_by` and refunds fuel. The programmer fix per spec §8's Player.gd note
  is the immediate next task, followed by re-runs of tests 6c/6d/11/13/14/15.
- **Fallback if dry reflect feels silent:** bigger FX/SFX on the stunned-body bumper hit — NEVER
  reopen the refund/clear gate (closed decision, DECISIONS 2026-07-03).

---

## 3. The resolved investigation: the interrupted QA re-verification

This is the project's best case study in evidence discipline (method home:
`gottabounce-research-methodology`). Chronicled here because a future session WILL see references
to "the dead agent" and "pacing.json" and needs the ending.

- **What happened:** after `587d0a1`, a QA re-verification agent ran 81 tool calls and died at a
  session limit with NO verdict. Its salvaged pacing data was self-contradictory: all-laser round
  endings, `supers_fired` empty, `killer: -1` — while its screenshots showed healthy DKO-revive
  and chain timelines.
- **Two hypotheses were held open** (STATUS at `bff3fd1` explicitly refused a verdict): **H1** a
  bot pacing regression (bots stopped firing supers), vs **H2** the agent's recorder was
  mis-hooked. Because TWO mechanisms fit the evidence, shipping was blocked — that is the rule,
  not an inconvenience.
- **Resolution (fresh session, STATUS at `e57db01`):** **H2.** A fresh sample showed round 1
  alone had 54 supers fired — the anomaly was the dead agent's mis-hooked recorder, NOT a
  regression. The fresh run then produced the REAL finding: Incident 10 (bumper-save), plus the
  core-hinge passes (6a 9/10, 6b 10/10, test 9 6/6) and pacing reads (test 10 borderline PASS
  72.7% kill-decided <20s; test 12 PASS median 15.0s).
- **Artifact note:** the dead agent's `pacing.json` never existed in the repo (it died with the
  agent's scratchpad). Surviving evidence: `tools/out/qa4_*.png` (partial, from the dead run) and
  `tools/out/qa5_*.png` + `tools/out/qa5_fight/` (fresh run). Despite STATUS mentioning
  "qa5_*.png/.json", **no qa5 JSON file exists in `tools/out/`** — the only per-match kill-log
  JSON there is `tools/out/qa3_match2_log.json` (a `tools/out/match_stats_raw.json` dump also
  exists, but it is not a per-match kill log).
- **Status: SETTLED** (the mystery). Its product, Incident 10, is OPEN.

---

## 4. Superseded designs — settled battles, do NOT refight

Each entry: what died, why, where the death certificate is, and the reopen condition.

| Dead design | Killed by | Why | Reopen condition |
|---|---|---|---|
| **Charged super** (power scales with fuel banked and/or hold time; `super_charge_*` constants) | DECISIONS 2026-07-02; spec v2 (`d8c4323`) | Double-taxed the game's only kill move (bank fuel AND stand still) → the hoarding/whiffing QA saw. Replaced by un-charged: full 2800 at any fuel ≥5, drain-all, ≤2s aim-hover. | ONLY with movement-course evidence. Never re-introduce power scaling otherwise — also stated in `src/core/Tuning.gd:45-49`. |
| **v1 light-smash tier** (620 closing-speed gate so boost-rams cause hitstun) | DECISIONS 2026-07-02 (two-tier contact) | Replaced by SHOVE (honest physics, no hitstun) vs SMASH (license-gated). | None recorded — the two-tier model is the adopted owner directive. |
| **Bot "bank-then-strike"** (`strike_fuel` dial: hoard fuel, then attack) | Spec v2 §3 (`d8c4323`), implemented `03894ac` | Died with the charge model — banking power no longer exists; replaced by a refuel-rhythm model (surfaces are the combo system). | None recorded. |
| **DevArena as the match scene** | `a8de63c` (v0 round loop) | Deleted (`src/modes/DevArena.gd`, −128 lines) in favor of `PartyMatch.gd` full state machine with scoring/HUD/sudden death. | n/a — superseded scaffolding. |
| **Bumper/bounce refund + stun-clear while stunned** | Spec v2.1 §2.3a + DECISIONS 2026-07-03 (`ea0c133`) | The bumper-save bug (Incident 10). Hitstun ends by time, never by surface contact. | Closed. Fallback for feel problems is more FX, never the refund/clear gate. |
| **GDD §3 open scoring question** | `docs/specs/v0_round_loop.md` | Resolved for v0: score floor at 0 (a suicide at 0 stays 0); +1 kill / +1 survive / −1 suicide / first to 10. Lethality spec later added the survival gate: a survivor with no contact scores +0 (`survival_requires_contact`, §9 criterion 20). | Normal spec change via `gottabounce-change-control`. |
| **Old project's laser pacing** (`laser_close_time` 10s) | Lethality spec (`d262686`) | Lasers demoted to a backstop: close time 10→6s (`src/core/Tuning.gd:118`) + part-closed revive lasers. | Never dial it back up as a lethality crutch (spec fallback-knob list). |

---

## 5. OPEN cases and gated work, as of 2026-07-03 (HEAD `0e315b9`)

Priority order below tracks the immediate next task called out in the `docs/STATUS.md` body (the
numbered NEXT STEPS list in STATUS leads with the full lethality QA pass — the dry-reflect fix is
the prerequisite the body flags as "immediate"):

1. **OPEN (committed state) — v2.1 dry-reflect fix is NOT in committed code.** Spec §2.3a / §8
   Player.gd note; branch `_on_bounced()` on `_stun_timer > 0.0`. Then targeted re-run of tests
   6c, 6d, 11, 13, 14, 15 plus one clean wall-return feel pass. This is the immediate next task.
   **Note (2026-07-03):** a fix is already **staged uncommitted** in the working-tree
   `src/entities/Player.gd` (the `_stun_timer <= 0.0` guard at ~line 557); this item and Incident
   10 flip to done the moment that change commits — re-verify via
   `git log --oneline -1 -- src/entities/Player.gd` before relying on the OPEN status.
2. **OPEN — lethality v2 has NO overall sign-off.** Core hinge passes are recorded, but a full
   21-criteria §9 pass (including L4>L2 5-match, forced double-KO revive timing, 60fps
   regression, 3-match feel judgment vs the owner thesis) has never completed. Test 10 was only
   a borderline PASS (72.7% vs ≥70%). Do not call this slice shipped.
3. **OPEN — powerup edges untested:** two counter shields colliding, counter vs storm balls,
   two-star clang (code-reviewed only); powerup C1 comedy check never run.
4. **GATED — goat identity = ADOPT-STAGED** (`docs/briefs/art_goat_identity_eval.md`, DECISIONS
   2026-07-03). Horns fold into the aim-pose art pass, but HOLD until movement courses validate
   that the super fantasy is the fun; REJECT if bounce-chaining carries the fun instead. Goat
   scream SFX is separable, gates only on the `super_fired` event (already exists in EventBus).
5. **GATED/UNBUILT — movement courses 1–3** (`docs/specs/v1_movement_courses.md`): specced, NOT
   built. Chimney is the un-charged-super acceptance test. Campaign home:
   `gottabounce-feel-campaign`.
6. **Watch items (no verdict either way):** resting-overlap shove jitter; bot self-destruct rate
   off the lowered arena ceiling; dry-reflect readability once implemented (fallback = FX, §4
   table above); `Tuning.gd:38` comment still says fuel_per_bumper is "FLAGGED FOR DESIGNER
   REVIEW" although the 2026-07-03 ruling resolved it (stays 20.0) — stale comment, fix via
   normal change control.

---

## 6. Known stale doc claims (do not cite these as truth)

Authority order for conflicts: `src/core/Tuning.gd` (live values) > `docs/DECISIONS.md` > newest
spec > `docs/STATUS.md` > older specs > `docs/reference/` (historical). Maintenance/templates:
`gottabounce-docs-and-writing`. Verified stale as of 2026-07-03:

| Stale claim | Reality |
|---|---|
| CLAUDE.md read-order item 4 cites `docs/ARCHITECTURE.md` | That file does not exist. Only `docs/reference/ARCHITECTURE.md` (old project). Accessible home for the INV invariants: skill `gottabounce-architecture-contract`. |
| `docs/reference/FEEL_REFERENCE.md` starting numbers | Drifted: gravity 2600 vs live 1600; `normal_boost_accel` 4200 vs 4600; `super_boost_impulse_full` 1400 vs 2800; `super_boost_min_fuel` 15 vs 5. It also predates the un-charged super. Live truth = `src/core/Tuning.gd`. |
| `docs/specs/v1_powerups.md` describes the charged super (`super_charge_time = 1.0s`, "fully-charged", charge-gated spam) | The charge model is DEAD (§4 table). Authority = `docs/specs/v0_combat_lethality.md` v2.1 + DECISIONS 2026-07-02. |
| `docs/PIPELINE.md:30` references `assets/reference/style_sheet.png` | Actual file: `assets/reference/style_north_star.png`. |
| `docs/STATUS.md` header "Last updated: 2026-07-02 session 3" | Body records 2026-07-03 commits through `ea0c133`. Trust the body + git log. |
| STATUS cites `pacing.json` and `tools/out/qa5_*.json` as evidence | Neither JSON exists in the repo (§3 above). Only per-match kill-log JSON present: `tools/out/qa3_match2_log.json` (a `match_stats_raw.json` dump also exists, but is not a kill log). |

---

## Provenance and maintenance

Written 2026-07-03 against HEAD `0e315b9` (25 commits, linear master). Everything above was
verified by reading the repo: `docs/STATUS.md`, `docs/DECISIONS.md`,
`docs/specs/v0_combat_lethality.md` (v2.1), `docs/specs/v0_round_loop.md`,
`docs/reference/LESSONS_LEARNED.md`, `docs/reference/MASTER_BUILD_PLAN.md` §5,
`src/core/Tuning.gd`, `src/entities/Player.gd`, `src/dev/Playtest.gd`, `tools/out/` listing, and
`git show` of commits `d262686`, `cdd925d`, `03894ac`, `587d0a1`, `bff3fd1`, `ea0c133`.
Constraint honored: no live runs — all QA/match numbers are as-recorded by the measuring
sessions (verified: static).

Re-verification one-liners for the drift-prone facts:

- Chronicle still current? `git log --oneline -8` (new commits after `0e315b9` may close §5 items — update statuses).
- Incident 10 fixed yet? The signal is a `_stun_timer <= 0.0` guard **inside `_on_bounced()`** (not the unrelated pre-existing decrement at ~line 314, nor the word "dry" which already matches a bumper comment at line 500 even when OPEN). Committed check: `git show HEAD:src/entities/Player.gd | grep -A12 "func _on_bounced" | grep "_stun_timer <= 0.0"` — a hit means done; empty means OPEN. Also confirm the code landed on `master`: `git log --oneline -1 -- src/entities/Player.gd` (still `587d0a1` = fix uncommitted; a newer commit = check the guard). When present, flip to FIXED-UNVERIFIED until tests 6c/6d/11/13/14/15 are re-run.
- Live constants cited here: `grep -nE "smash_impact_min|fuel_per_bumper|super_boost_impulse_full|super_ring_screen_width|laser_close_time" src/core/Tuning.gd`
- Lethality sign-off still owed? `grep -n "NEXT STEPS" -A6 docs/STATUS.md`
- Goat gate status: `grep -n "GOAT" docs/DECISIONS.md`
- qa5 JSON still missing: `ls tools/out | grep -E "qa5.*json"` (empty = still missing).
- Doc-drift rows: `grep -n "ARCHITECTURE" CLAUDE.md` · `grep -n "style_sheet" docs/PIPELINE.md` · `grep -nE "gravity.*2600" docs/reference/FEEL_REFERENCE.md` (the row is a markdown table with backticks/pipes between `gravity` and `**2600**`, so a literal-space pattern will not match).

UNVERIFIED / static-only items in this skill:
- All QA match metrics (9/9, 6/6, 72.7%, 54 supers, 27–33% SD, etc.) — as-recorded in STATUS/
  DECISIONS/commit messages; not re-run.
- The hills_far corruption and the dead agent's scratchpad contents — recorded in STATUS only;
  no repo artifact remains to inspect.
- Old-project failure details (gamepad, HUD, 2× bounce) — from `docs/reference/LESSONS_LEARNED.md`;
  the old repo itself was not read (out of scope, by rule untouched).
