# Spec: v1 Party Kill-Race — lives-based Duck-Game match across rotating levels

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD (slice C — see §10). **v1 — 2026-07-03.**
>
> Authority: owner directive `docs/feedback/owner_2026-07-03_lives_damage_killrace.md` +
> `docs/DECISIONS.md` (2026-07-03 top entry). This spec **replaces the match/round structure of
> `docs/specs/v0_round_loop.md`** (see §0 kept-vs-replaced). The combat interior it sits on top of —
> the damage system, edge-relative lethality, and level-relative bounds — is specified in the
> companion amendment `docs/specs/v0_kill_zone_recovery.md` **§12–§14 (v3)**. Read that for anything
> about launch/sting/damage/bounds; read THIS for match/stage/lives/SD/rotation/scoring/HUD.
>
> Code surface: `src/modes/PartyMatch.gd` (state machine, scoring, bounds, SD), `src/core/LevelLoader.gd`
> (bounds + level load), `src/entities/Player.gd` (`kill`/`respawn`/`is_dead`/`damage_level`),
> `levels/dev_arena.json`.

## The player fantasy

You press play and you are **already fighting somebody, somewhere new, every fifteen seconds.** No
timer ever tells you to hurry — the *elimination* does. Four bouncers, one life each, last one
flying takes the stage; then the level changes under your feet and you go again, and again, and the
kill you just landed ticked you one closer to winning the whole set. It is Duck Game's churn: fast,
lethal, disposable stages that add up to a race. The best moment in the game is the freeze-frame on
somebody's **tenth kill** — the whole screen stops, the camera slams to the winner, and the set is
theirs.

---

## 0. What of `v0_round_loop.md` is KEPT vs REPLACED

**KEPT (carries over unchanged unless noted):**
- The staggered **pop-in intro** (now `STAGE_INTRO`), the **"3-2-1-BOUNCE!"** countdown, name tags,
  countdown input-lock, the full-fuel start, the ~3s pre-stage budget.
- **Corner HUD cards** (one per player), the **banner system** (CENTER / TOP-BAND), the pop/hold/pop
  animation style. Pips are **re-pointed to KILLS** (§4).
- **Kill credit** rules: last-attacker within the credit window, beyond-the-grave kills count, one
  player can rack multiple kills, credit-fix persists through the launch state (kill-zone §11.2 —
  DO-NOT-TOUCH).
- **Suicide = −1, floored at 0** (anti-grief + L2 comedy). Semantics change: it decrements the
  player's **kill total** (a suicide costs you a kill; being *killed* is never −1).
- **No mid-stage respawn at 1 life** (the old dev-respawn stays deleted).
- **MATCH_END** celebration + `A — REMATCH / B — QUIT`, the 1s input guard, the winner punch-zoom,
  the backing panel (`docs/specs/v0_combat_lethality.md` §7).
- **Bots**: the mixed **2 / 3 / 4** lineup (`Tuning.bot_levels`).
- The **turnaround / 60fps** contracts (§8).
- Camera framing (`_update_camera`, kill-zone §6) — extended to level-relative bounds (§3 of the
  amendment) but the follow/lead logic is unchanged.

**REPLACED:**
- **"Round" → "Stage."** A *stage* = one instance of one level, resolved by elimination. A *match* =
  the whole kill-race across many stages.
- **First-to-10-*rounds*-on-one-arena → first-to-`match_target_kills`-KILLS across FREQUENTLY
  ROTATING levels.** Score is **cumulative kills**, accumulated across stages (§2).
- **The survival point (+1 sole survivor) is REMOVED.** Score is kills only. `survival_requires_contact`
  and the survival-point award are deleted. (Camping is still answered — by idle-hunt, no-standable-
  ground, and stages that end in seconds — but it no longer scores.)
- **The 20s laser-wall sudden death is REMOVED entirely** (directive §2). `sudden_death_time`,
  `laser_close_time`, `laser_revive_start_frac`, `sd_warning_lead`, the `LaserWalls`/`SDWarning`
  nodes and their spawn/tick/cleanup paths are all removed. **The ONLY sudden death is the
  simultaneous double-KO** (§5).
- **Bounds are no longer fixed per-arena JSON constants** — they are **derived from level geometry**
  (amendment §14).
- **`match_target_score` → `match_target_kills`** (semantic rename; default still 10, see §2).

---

## 1. State machine

One authoritative `state` string on `PartyMatch`. `round_index` is renamed `stage_index`
(keep a `round_index` alias if cheap — QA/tools may read it). "Round" language in code comments → "stage."

```
BOOT ─► MATCH_START ─► STAGE_INTRO ─► COUNTDOWN ─► COMBAT ─► STAGE_END ─┬─► STAGE_INTRO  (next stage: ROTATE LEVEL)
                            ▲                          │                └─► MATCH_END ──► (rematch) MATCH_START
                            │                          ▼                                └─► (quit) exit
                            └────────── SUDDEN_DEATH (double-KO revive-once 1v1, returns via STAGE_END)
```

- **MATCH_START** — zero all kill totals, `stage_index = 0`, reset the level shuffle-bag (§6), clear
  `round_stats`. Flow straight into the first `STAGE_INTRO`.
- **STAGE_INTRO** — **rotate to the next level FIRST** (§6), then the v0 pop-in: players suspended &
  invisible at the new level's spawns, popped in one-by-one with name tags. Unchanged timing.
- **COUNTDOWN** — "3-2-1-BOUNCE!", input-locked, aim-only, full-fuel start. Unchanged.
- **COMBAT** — everyone has `lives_per_player` (default **1**) life. All deaths route through
  `KillPipeline`. **No round clock drives anything** (`round_clock` may stay as a stat for QA, but it
  gates NOTHING — no laser trigger, no warning). Stage ends when **≤1 player is alive**
  (last-one-standing, §5). The **match-end check fires on every kill** (§2) — a kill that reaches the
  target ends the match immediately from COMBAT.
- **SUDDEN_DEATH** — a COMBAT sub-phase, entered ONLY by the simultaneous double-KO (§5). Returns via
  STAGE_END when one revived player dies.
- **STAGE_END** (~`round_end_freeze`, unchanged 1.8s) — KO freeze-frame; banner **"Pn SURVIVES!"** (or
  "NOBODY SURVIVES" on a double-KO draw) + the stage's kill deltas; kill pips already animated as they
  were earned (see §4). Then → next STAGE_INTRO (rotate level), or MATCH_END if the target was hit.
- **MATCH_END** — winner punch-zoom + banner + REMATCH/QUIT. Unchanged from v0_round_loop / lethality §7.

**Deleted from the machine:** the `round_clock >= sudden_death_time` transition, the SD warning
flicker, `_enter_sudden_death_timer`, `_activate_lasers`, laser tick/cleanup. `_sudden_death_revive`
is **rewritten** (§5).

---

## 2. Scoring — the kill-race

**Score = cumulative KILLS per player, persisting across stages.** `scores[i]` is player i's running
kill total (0 at MATCH_START, never reset between stages). The corner-card pips visualize it (§4).

- **+1 to the attacker on every credited kill** (all death causes: ring-out, hazard, knocked-into-
  anything). Kill credit / beyond-the-grave / chain-body-credit rules are unchanged (v0_round_loop §2,
  lethality §2.1, kill-zone §11.2). This is the whole economy — there is no survival point.
- **Suicide = −1 to the victim's own kill total, floored at 0.** (An uncaused self-ring-out: no
  living/dead attacker within the credit window.) Being *killed* is never −1. Rationale: keeps the L2
  panic-suicide a visible punchline and discourages ledge-diving to deny a kill, without a negative
  spiral (floor at 0). Configurable; revisit if it feels punishing in the kill-race context.
- **`match_target_kills` (NEW Tuning, default 10).** Rationale for 10 over 15: with 4 players, 1 life,
  last-one-standing, a stage yields ~2–3 credited kills; a leader nets ~1/stage → **~8–11 stages ≈
  3–5 min** to reach 10 — the Duck-Game set length, and it keeps the 10-slot pip card (§4) exactly
  full. 15 pushes matches to ~6–7 min and needs a 3-row card. Left as Tuning so a "long set" is a
  one-number change. (Retire `match_target_score`; alias if cheap.)

### Match-end trigger — fires on the winning KILL

**Checked inside `_on_killed`, after applying the +1:** if `max(scores) >= match_target_kills` **AND
exactly one player holds that max**, transition to **MATCH_END immediately** — freeze on that kill,
punch-zoom to the killer. The final kill IS the hero moment (do not wait for STAGE_END).

- **Tie at target:** if the crossing kill leaves two players tied at ≥ target (only reachable via a
  double-KO registering two kills inside `double_ko_window`), **do not end** — play on (the next kill
  breaks it; a `TIEBREAKER!`-style TOP-BAND banner is optional flavor). Match-end always requires a
  strict single leader at ≥ target.
- **MATCH POINT** banner (TOP-BAND, once per player): fires the first time a player reaches
  `match_target_kills - 1` kills.

---

## 3. Lives, elimination, stage-end, level transition (open sub-questions RESOLVED)

- **Sub-Q "respawn within a stage, or out until next level?" → RULING: with 1 life, a dead player is
  OUT for the stage; they return only when the next stage loads (a fresh level, fresh life).** No
  mid-stage respawn. This is the Duck-Game reading and it is what makes stages fast and disposable.
  Dead players' corner cards dim + skull until the next STAGE_INTRO (unchanged v0 treatment).
  - *Multi-life (`lives_per_player > 1`) is configurable but not the default and not this slice's
    validation target:* if enabled, a death decrements `lives_left[i]` and, while `> 0`, respawns the
    player at a spawn point after `respawn_delay` with the existing `_spawn_protect` invuln and
    `damage_level` reset to 0. A player is "eliminated" (out for the stage) only at 0 lives. The
    stage-end / SD logic below reads *eliminated* count, not *dead-this-instant* count. Ship the 1-life
    path first; the multi-life respawn is a small additive path, not a blocker.

- **Sub-Q "stage-end trigger: last-one-standing or first-elimination?" → RULING: LAST-ONE-STANDING.**
  A stage ends when **≤1 player is not-yet-eliminated.** Rationale: last-one-standing preserves the
  4→1 elimination arc (the `TWO LEFT!` climax, the free-for-all melee where most kills and most
  damage-state chases happen), and yields multiple kills per stage so the race actually progresses.
  First-elimination would make each stage a single trade and delete the melee — too churny, loses the
  best content. (Kept as an alt knob: if the owner wants max churn, a `stage_ends_on_first_elim` flag
  could flip it — flagged, not built.)

- **The lone survivor scores NOTHING extra** (the kill that eliminated the previous player already
  scored). Survival is a **celebration beat only** — the "Pn SURVIVES!" banner. This is the direct
  consequence of "score = kills."

- **Level rotation cadence:** rotate to a **new level every stage** (§6) — maximum Duck-Game churn.
  The rotation happens at the top of `STAGE_INTRO`, before pop-in, so the establishing shot frames the
  new level.

---

## 4. HUD changes

- **Corner-card pips now count KILLS toward `match_target_kills`.** Default 10 → the existing
  2-rows-of-5 card is exactly full at match point. A pip pops in **the instant a kill is credited**
  during COMBAT (not deferred to STAGE_END — the kill-race wants immediate feedback), with the same
  scale-bounce. A suicide pops a pip *out*. HUD must render `match_target_kills` slots (if a future
  target > 10, add rows — note for the HUD scene, not a blocker at 10).
- **Fuel gauge**, dead-this-stage dim + skull, corner placement, the "no persistent UI inside the
  middle 60%×60%" prime directive — all **unchanged**.
- **No damage HUD element.** The damage state is read **on the body** (the red pulse, amendment §12) —
  never a HUD meter (agreed form, Pillar 5, no persistent HP bar).
- **No round timer / no SD warning columns** (removed with the laser SD).
- **Banners** — updated table:

| Moment | Text | Position | Notes |
|---|---|---|---|
| Countdown / Go | `3` `2` `1` / `BOUNCE!` | CENTER | unchanged |
| First kill of the MATCH | `FIRST BLOOD!` | TOP-BAND | once per match |
| Exactly 2 not-eliminated (stage started ≥3) | `TWO LEFT!` | TOP-BAND | once per stage |
| Simultaneous double-KO revive | `SUDDEN DEATH!` | CENTER | §5, revive variant only |
| Stage survivor | `Pn SURVIVES!` (winner color) / `NOBODY SURVIVES` | CENTER | STAGE_END, + kill deltas |
| Match point (player hits target−1) | `MATCH POINT — Pn` | TOP-BAND | once per player, at next COUNTDOWN |
| Match win | `Pn WINS THE MATCH!` + scoreline + prompt | CENTER | unchanged |

---

## 5. Sudden death — the ONLY SD is the simultaneous double-KO

**Trigger (directive §2):** the last two **not-yet-eliminated** players lose their **last life within
`double_ko_window` of each other.** With `lives_per_player = 1` this is simply the final two dying
within the window. Change **`double_ko_window` 0.25 → 0.50s** (directive: "within 0.5s"). This is the
grouping window already implemented in `_on_killed` (`_recent_dead`) — reuse it, widen it.

**A single death, or two deaths > 0.5s apart, NEVER triggers SD** — that resolves to a normal
last-one-standing STAGE_END with a lone survivor.

**Resolution — revive-both-to-Lv2 1v1 overtime (no lasers, no timer):**
1. Both tied players revive at the two spawn points nearest stage center (existing `_spawns_by_center`),
   full fuel, `frozen = true` during the banner.
2. **Both spawn pre-damaged at `damage_level = 2` (fast red pulse, amendment §12).** This is the
   timer-free resolution mechanism: at Lv2 the first clean near-edge hit sends the loser out (+66%
   launch). No standable ground means they cannot stall; the fight resolves in seconds by the same
   combat rules. **This is why we need no laser backstop** — the damage system IS the clock.
3. Banner `SUDDEN DEATH!` (CENTER) holds `SD_REVIVE_LOCK` (0.8s), inputs locked, then combat resumes.
   No 3-2-1 — keep it panicky.
4. The next death ends the stage (that kill scores normally, +1 to its attacker). The other player is
   the stage survivor ("Pn SURVIVES!").
5. **One revive max per stage.** If the two revived players double-KO *again* within the window →
   `NOBODY SURVIVES`, stage ends, rotate. No recursion.

**Fallback (owner-taste, flagged):** if SD 1v1s prove un-fun or ever stall in QA (they should not —
Pillar 2 + pre-applied Lv2), the simpler alternative is to skip the revive and declare the double-KO a
**DRAW** ("NOBODY SURVIVES"), rotate immediately. The revive is primary because the directive kept SD
as a resolution moment, not an anticlimax.

---

## 6. Level rotation

- **`_load_stage()`** already loads a level by path into `_level_root`. Generalize `PartyMatch` to
  hold a **level pool** (an array of level JSON paths). v0 has one file (`levels/dev_arena.json`); the
  pool is `[dev_arena]` until the level-designer adds more (slice D).
- **Rotation = shuffle-bag:** shuffle the pool at MATCH_START; draw sequentially; when exhausted,
  reshuffle (avoid an immediate repeat of the just-played level when the pool has ≥2). With a
  1-level pool, rotation degenerates to replaying that level (current behavior — graceful).
- At each STAGE_INTRO: advance the bag, `_load_stage(next_path)`, re-read spawns / powerup points /
  **derived bounds** (amendment §14), re-frame the camera to the new level's stage rect. Spawns and
  bounds are per-level; nothing arena-specific may remain hardcoded.
- Expose `level_index` / `level_name` (read-only via eval) for QA rotation checks.

---

## 7. New / changed / removed Tuning constants

```
# NEW (match)
match_target_kills   = 10        # first to this many cumulative kills with a strict lead wins
lives_per_player     = 1         # default; >1 enables mid-stage respawn (configurable, non-default)

# CHANGED
double_ko_window     = 0.25 -> 0.50   # directive §2: last-two-within-0.5s = the ONLY SD trigger
match_target_score   -> RETIRED (renamed match_target_kills; alias if cheap)

# REMOVED (laser SD gone — directive §2)
sudden_death_time, laser_close_time, laser_revive_start_frac, sd_warning_lead
survival_requires_contact               # no survival point in a kill-race

# UNCHANGED / reaffirmed
intro_pop_stagger, countdown_beat, round_end_freeze (1.8), kill_credit_window (4.0, persist),
bot_levels [2,3,4], round_end_freeze cap 2.0
```

(Damage-system, bounds-derivation, and sting constants live in the amendment §12–§14.)

---

## 8. Success criteria (QA-verifiable via gbplay eval + screenshots)

`PartyMatch` must expose (read-only via eval): `state`, `stage_index`, `scores` (cumulative kills),
`level_index`/`level_name`, `bounds`, `lives_left[]` (if multi-life), and per-stage `round_stats`
(extended in the amendment §12–§14 with damage fields). Also expose `players[i].damage_level` and the
heal timer for the damage tests (amendment §13).

**Flow & structure**
1. **Cold boot to combat:** launching reaches `COMBAT` within 6s, zero input (unchanged v0 t1).
2. **Kills accumulate across stages:** eval-drive 2 stages; a player who scored 1 kill in stage 1 and
   1 in stage 2 reads `scores[i] == 2` after stage 2 (not reset between stages).
3. **Last-one-standing stage-end:** in a 4-player stage, `state` stays `COMBAT` until exactly ≤1
   player is not-eliminated, then → `STAGE_END`. Killing to 2-alive fires `TWO LEFT!` (screenshot).
4. **No mid-stage respawn (1 life):** eval-kill a bot; wait 5s → still dead, card skulled, until the
   next STAGE_INTRO (screenshot).
5. **Level rotates every stage:** across ≥3 stages, `level_index`/`level_name` changes each stage;
   on a ≥2-level pool, no stage replays the immediately-previous level. (On the 1-level dev pool, the
   same level is expected — assert the rotation *call* fires via a stage counter.)
6. **Match-end on the winning kill:** eval-set `scores=[9,0,0,0]`, credit P1 one more kill mid-COMBAT →
   `state` becomes `MATCH_END` on that kill (not at STAGE_END), punch-zoom to P1, winner banner +
   REMATCH/QUIT prompt (screenshot). With `scores=[9,9,0,0]` and a double-KO crediting both to 10 in
   the same window → match does **not** end (strict-lead required); play continues.
7. **Match-to-target timing (bot-driven):** a full idle-P1 match to `match_target_kills=10` completes
   in **~2.5–5 min** wall-clock across the 2/3/4 lineup (measure ≥3 matches). A match dragging past
   ~7 min flags a stage-length or kill-rate problem.

**Sudden death (double-KO only)**
8. **SD fires only on true simultaneity:** eval-kill the final two players within 0.5s of each other →
   `state == SUDDEN_DEATH`, both revived at center spawns, **both `damage_level == 2`** with a fast
   pulse (screenshot + eval), `SUDDEN DEATH!` banner. Final two deaths **> 0.5s apart** → NO SD, normal
   `STAGE_END` with a lone survivor. A single death → never SD.
9. **SD resolves fast, no timer, no lasers:** after the revive, the 1v1 resolves (one death) in ≤~6s
   with zero laser/warning pixels anywhere in any screenshot of the SD phase. A second double-KO ends
   the stage `NOBODY SURVIVES`, no second revive.

**Scoring**
10. **Kill credit + suicide floor:** a credited kill = +1 to the attacker's kill total (pip pops in
    during COMBAT); an uncaused self-ring-out at score ≥1 = −1 (pip pops out), at score 0 stays 0;
    being killed is never −1. (Reuses v0 t6–t8 harness, re-pointed to kill totals.)

**Stage-length & kill distribution (aggregate, ≥24 idle-P1 stages)**
11. **Stage length:** median COMBAT length **8–18s**; 90th-percentile ≤ **25s**; no laser/timer ends a
    stage (all end by elimination or double-KO SD). A stage > 35s wall-clock flags for review (soft —
    Pillar 2 + damage should prevent it; there is no hard cap by design).
12. **Kills per stage:** median **≥ 2 credited kills/stage**; suicides ≤ ~1/stage median (L2 comedy
    still lands ≥1 suicide/match). Unattributed kills ≤ 18% (credit-fix, kill-zone §11.2).

**Readability & performance**
13. **Corner HUD only:** mid-combat screenshot — 4 corner cards (kill pips + fuel), no persistent UI
    inside the middle 60%×60%; no timer; no HP bar. Damage reads as an on-body red pulse only.
14. **60fps + turnaround:** avg ≥55fps, no hitch >100ms during a smash-heavy stage; last-death →
    next-stage BOUNCE ≤ 4.5s (allow 5.0s hard-fail), over 3 consecutive stages (unchanged v0 t4/t18).

(The old SD-rate / test-31 active-climax / laser-close targets are **MOOT** — there is no timer SD to
rate. The damage/edge/bounds combat criteria live in the amendment §15.)

---

## 9. Out of scope for this spec

Powerup rebalance, title/lobby/menus, local-MP join, audio announcer/music, pause menu, persistent
stats. The `InputBot`/`Playtest` contract fields (`players`, `scores`, `bounds`, `nearest_opponent()`,
`stage_rect()`, `stage_center()`, `idle_hunt_target()`) must survive the refactor unchanged. The
damage/edge/bounds combat internals are the amendment's scope, not this file's.

---

## 10. Depth-first build slice order (Director sequences from this)

The directive suggested (a) combat core incl. lives/elimination + bounds, (b) match mode + rotation,
(c) more levels. **Improved ordering — feel-riskiest thing first, and split bounds from match-mode:**

- **Slice A — DAMAGE COMBAT FEEL (make-or-break; amendment §12–§13).** On the EXISTING single arena
  and EXISTING fixed bounds and EXISTING round loop: add the damage state (Lv1/Lv2, 8s heal, red
  pulse) + the post-cap launch multiplier; remove the compounding sting; keep the base sting. Validate
  the FEEL first: does hitting a damaged player near the edge kill? does a fresh mid-stage player arc
  back? does the flee/chase read on the body? **If this feel is wrong, nothing else matters** — do not
  proceed. (No match-mode rework needed to feel-test this; the current 1-life round loop already ends
  by elimination.)
- **Slice B — LEVEL-RELATIVE BOUNDS + edge-relative validation (amendment §14).** Derive bounds from
  play_rect + margins (values reproduce dev_arena's validated bounds). Re-verify edge-kill-vs-mid-
  survive rates. Low risk once A feels right; unblocks auto-bounding for new levels.
- **Slice C — KILL-RACE MATCH MODE (THIS spec).** Rework PartyMatch: cumulative kills, target 10,
  remove survival point, remove the 20s laser SD + nodes, double-KO SD = revive-both-Lv2 1v1, level
  rotation cadence, match-end on the winning kill, HUD pips → kills, banner table.
- **Slice D — MORE LEVELS (level-designer).** A pool of ≥4–6 hand-built levels feeding the shuffle-bag;
  each auto-bounds via §14. Only meaningful once A–C prove the loop is fun on one level.

Rationale for reordering: the damage-launch feel is the single highest-risk, highest-value change and
must be validated in isolation before we invest in bounds derivation or a whole new match state
machine around it (depth-first: one slice to genuinely-good before widening).
