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

## 5.5 The 1v1 stage-closeout — bot "finisher" mode (RULING, 2026-07-03 session-4 finding)

**The finding (QA, 4-bot self-play watched to stage 9):** the match STRUCTURE is sound — stages
rotate, kills accumulate across stages (reached `[2,7,5,6]`), lives reset per stage, last-one-standing
resolves, match-end fires on the winning kill, zero laser SD. But the **2→1 endgame STALLS**: once a
stage is down to the final two players (1 life each), two L3 bots circle and refuel and neither commits
to the kill — **stage 1 sat 2-alive for ~73s.** Stages resolve fine at 3–4 players (the melee produces
kills); only the closeout drags. Net: ~7 kills across 8 stages in ~7 min → a full match to 10 would run
~10–12 min against the spec's 2.5–5 min target (§2, §8 t7).

### RULING 1 — NOT acceptable. This must be fixed for v0.

A 73s two-player circle is a **camp by any other name** (Pillar: no camping / stages end in seconds)
and it directly violates the owner's **Duck-Game-fast churn** intent — the whole fantasy in this spec
is "somewhere new every fifteen seconds," and a stall triples match length. "Humans would push" does
not save it: (a) the bot self-play harness IS a shipping validation surface (the whole studio validates
by driving bots), and a harness that cannot close a stage cannot measure §8 t7/t11/t12; (b) a
**human-vs-evasive-bot** 1v1 — the common case in a party lobby with fewer than 4 humans — would feel
*worse* than bot-vs-bot, because the human is trying to end it and the bot will not cooperate. The stall
is a real defect, not party tension.

### RULING 2 — the fix is BOT FINISHER AGGRESSION. Damage-tuning and any time-based anti-stall are REJECTED.

**Diagnosis (from `InputBot.gd` / `BotProfile.gd`):** the stall is a **bot-commitment** failure, not a
lethality failure. In the endgame the two survivors are each gated *away* from the kill by their own
profile dials:
- `aggression` (L3 0.65) fails its hunt-roll ~35% of ticks → the bot idles/drifts instead of pressing;
- `refuel_floor = 25` makes a bot **break off to dive-refuel** the moment its tank dips under 25, and
  also **blocks entering AIM** below 25 — so two bots take turns retreating to refuel and never overlap
  in an attack window;
- `attack_range` (L3 340px) means they only arm a super when already close, so the circling never
  converts to a committed run;
- `target_ok` (`_decide`, line ~208) drops the hunt when the lone opponent floats past
  `stage.grow(520)` → the chaser disengages exactly when it should close.

With no third body to force exchanges and no time pressure (owner removed the timer), these
break-off gates form a stable orbit. **The lethality/damage system is NOT the primary culprit** — it
*does* eventually force the kill, just too slowly; and note the 8s heal (`dmg_heal_time`) means that in
a slow circle the `damage_level` heals back to 0 between sparse hits, so escalation never compounds. The
fix is to make hits *frequent and committed* (bot behavior), not to make each hit more lethal (which
would regress the 3–4-player melee that already works).

**THE FIX — a scoped "finisher" mode in `InputBot`, active only when the bot has ≤1 living opponent
left (i.e., 2 players remain).** The bot counts living opponents from the existing `arena.players`
(no new arena contract — preserves the §9 InputBot/Playtest field contract). While
`_alive_opponents(me) <= finisher_opponents_left`, the bot OVERRIDES its profile dials with the
finisher values below; outside the endgame it behaves exactly as today (the 3–4-player pacing is
already good and must NOT change).

Finisher overrides (applied on top of any level's profile — floors/caps/mults so they scale sanely for
L2/L3/L4, the shipped lineup):

| Dial | Normal (L3) | In finisher | Rule |
|---|---|---|---|
| `aggression` | 0.65 | **floor 0.95** | commit essentially every tick — no idle drift |
| `attack_range` | 340 | **× 1.4** (→ ~476) | arm the super from further; close-and-blast, do not orbit |
| `commit_time` | 0.8 | **floor 1.5** | a rolled hunt sticks through the whole approach |
| `refuel_floor` | 25 | **10.0** (both the dive-trigger AND the attack-gate) | only bail to refuel when nearly dry; keep pressing while there is fuel to fight with |
| `dodge_super` | 0.0 (L4 0.5, L5 0.8) | **cap 0.15** | kill the counter-super dance so two high-tier bots do not infinitely dodge-cancel in the closeout |
| `target_ok` | dist-gated | **always true for the lone opponent** | never disengage a floating survivor — chase it to the edge (where the kill lives) |

Rationale for the numbers, tied to the tuned combat: `refuel_floor 10` sits safely above
`super_boost_min_fuel = 5` (Tuning) so a finisher bot always retains enough fuel to land one committed
super before it must dive — it presses instead of orbiting, but never suicides on an empty tank.
`attack_range × 1.4` (not more) keeps the approach honest — bigger ranges made bots over-commit and
whiff in the prior `edge_guard`-up experiment (STATUS session-4), which *dragged* rounds; scoping the
range bump to the 2-left endgame (where a whiff just resets a 1v1, not a 4-body scrum) contains that
risk. `aggression 0.95` (not 1.0) preserves a sliver of the L1/L2 flail comedy. Aim quality
(`aim_error`, `target_lead`, `super_aim_time`) is **untouched** — finisher raises *commitment*, never
accuracy; bots still never cheat (INV-8). Committed, frequent trades land repeat hits inside the 8s
heal window → `damage_level` escalates to Lv2 → the next near-edge hit rings the loser out by the
existing combat rules. No standable ground means the loser cannot stall the finish.

**REJECTED — damage-escalation tuning (faster escalation / slower heal).** Lowering `dmg_heal_time`
(8→e.g. 4) or raising `dmg_launch_mult` would speed the closeout but is a **global** combat change that
regresses the hard-won 3–4-player pacing (STATUS session-4 documents that every global lethality lever
tried — sting 30→40, edge_guard-up — traded one metric for two). The 8s heal healing between sparse
hits is a *symptom* of the circle, not the cause; once the finisher makes hits frequent, 8s is plenty
to compound. Leave the damage system exactly as shipped.

**REJECTED (hard) — any time-based anti-stall** ("after N seconds of 2-left, auto-escalate damage /
tighten bounds"). This is the round timer the owner explicitly removed (directive §1: "No round time
limit … never a timer") wearing a costume — it reintroduces the exact time-pressure-vs-recovery tension
the directive *dissolved* (STATUS: "the SD-rate pacing tension is DISSOLVED. No round timer"). The
stall is a bot-commitment bug; fix the bug, do not re-add a clock. Not built, not flagged-for-later —
rejected.

**Note on `dodge_super` for high-tier bots:** L4/L5 (`dodge_super` 0.5/0.8) are the real closeout risk
for a future all-L4/L5 hard-mode match — two dodgers would perpetuate the very dance the finisher is
meant to end. Capping it at 0.15 in finisher is cheap insurance; include it now.

### Tuning constants (add to the bot/pacing section of `Tuning.gd` — one-number tunable, per CLAUDE.md)

```
# NEW (bot finisher — the 2-left stage closeout, §5.5)
finisher_opponents_left      = 1      # enter finisher when a bot has <= this many living opponents (2 players total)
finisher_aggression_floor    = 0.95
finisher_attack_range_mult   = 1.4
finisher_commit_time_floor   = 1.5
finisher_refuel_floor        = 10.0   # > super_boost_min_fuel (5): keep enough to fire, but stop orbit-refueling
finisher_dodge_super_cap     = 0.15
```

These are match-pacing feel constants → they live in `Tuning.gd`, not baked into `InputBot`. `InputBot`
reads them when `_alive_opponents(me) <= Tuning.finisher_opponents_left`. **Note for the programmer:**
`_alive_opponents(me)` counts `arena.players` that are valid, not `me`, and not `is_dead()` — no new
arena field; the §9 InputBot/Playtest contract is untouched.

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

# NEW (bot finisher — 2-left stage closeout, §5.5)
finisher_opponents_left    = 1     # enter finisher when a bot has <= this many living opponents
finisher_aggression_floor  = 0.95
finisher_attack_range_mult = 1.4
finisher_commit_time_floor = 1.5
finisher_refuel_floor      = 10.0  # > super_boost_min_fuel (5)
finisher_dodge_super_cap   = 0.15

# CHANGED
double_ko_window     = 0.25 -> 0.50   # directive §2: last-two-within-0.5s = the ONLY SD trigger
match_target_score   -> RETIRED (renamed match_target_kills; alias if cheap)

# REMOVED (laser SD gone — directive §2)
sudden_death_time, laser_close_time, laser_revive_start_frac, sd_warning_lead
survival_requires_contact               # no survival point in a kill-race

# UNCHANGED / reaffirmed
intro_pop_stagger, countdown_beat, round_end_freeze (1.8), kill_credit_window (4.0, persist),
bot_levels [2,3,4], round_end_freeze cap 2.0
dmg_heal_time (8.0), dmg_launch_mult [1.0,1.33,1.66]   # §5.5: NOT touched — the closeout fix is bot behavior, not lethality
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

**1v1 stage-closeout (bot finisher, §5.5 — the session-4 stall fix; measured in a 4-bot match, the stress case)**
15. **2-left closeout duration:** instrument the wall-clock from the moment a stage reaches exactly
    **2 not-eliminated players** (the `TWO LEFT!` trigger) to the deciding death. Across ≥20 such
    closeouts in 4-bot matches (2/3/4 lineup): **median ≤ 8s, 90th-percentile ≤ 15s.** A single
    closeout > 20s is a **soft flag** for review; **> 30s is a HARD FAIL** (this is the 73s regression
    guard). Compare against the pre-fix baseline (stage-1 = 73s) — the fix must cut the closeout tail
    by an order of magnitude.
16. **Finisher does not over-shorten the 3–4-player melee:** the 4→2 phase (COMBAT start → `TWO LEFT!`)
    still yields the bulk of kills; whole-stage median stays **8–18s** (criterion 11) and per-stage
    kills stay **≥ 2** (criterion 12) — i.e. finisher speeds the *closeout*, it must not make the
    early melee a single trade nor spike bot self-destructs (idle-P1 suicide rate stays ≤ ~1/stage,
    criterion 12). If finisher whiff-and-drag or self-destruct appears, re-check `attack_range × 1.4`
    (lower toward × 1.2) before touching any global knob.
17. **Full-match timing re-verified post-fix:** with the finisher live, criterion 7 must now hold —
    a full 4-bot idle-P1 match to 10 kills completes in **2.5–5 min** (≥3 matches), NOT the ~10–12 min
    observed pre-fix. **Human-play note (not automatable this slice, judge by inspection):** a
    human-vs-1-bot closeout must also resolve — the finisher bot pushes and trades rather than orbits,
    and with no standable ground the human cannot camp the finish either; a designer/QA spot-check of
    one human-driven 1v1 closeout should confirm it ends within a few seconds of sustained contact,
    with no "the bot won't engage" feel.

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
finisher mode (§5.5) reads only existing `arena.players` — it adds no new contract field. The
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
- **Slice C.1 — BOT FINISHER (§5.5; follows the session-4 QA finding).** Small additive `InputBot`
  change: `_alive_opponents()` count + the finisher dial-overrides gated on
  `<= Tuning.finisher_opponents_left`, plus the 6 new Tuning constants. Re-run criteria 15–17 in a
  4-bot match. This is the immediate closeout-stall fix; it does not touch PartyMatch or the damage
  system.
- **Slice D — MORE LEVELS (level-designer).** A pool of ≥4–6 hand-built levels feeding the shuffle-bag;
  each auto-bounds via §14. Only meaningful once A–C prove the loop is fun on one level.

Rationale for reordering: the damage-launch feel is the single highest-risk, highest-value change and
must be validated in isolation before we invest in bounds derivation or a whole new match state
machine around it (depth-first: one slice to genuinely-good before widening).
