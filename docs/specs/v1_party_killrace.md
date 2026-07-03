# Spec: v1 Party Kill-Race — lives-based Duck-Game match across rotating levels

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD (slice C.2 — see §10; slice C + C.1
> shipped). **v1 — 2026-07-03.**
>
> Authority: owner directive `docs/feedback/owner_2026-07-03_lives_damage_killrace.md` +
> `docs/DECISIONS.md` (2026-07-03 top entry). This spec **replaces the match/round structure of
> `docs/specs/v0_round_loop.md`** (see §0 kept-vs-replaced). The combat interior it sits on top of —
> the damage system, edge-relative lethality, and level-relative bounds — is specified in the
> companion amendment `docs/specs/v0_kill_zone_recovery.md` **§12–§14 (v3)**. Read that for anything
> about launch/sting/damage/bounds; read THIS for match/stage/lives/SD/rotation/scoring/HUD.
>
> **AMENDMENT LOG:** §5.5 (2026-07-03 session-4 finding #1) fixed the 1v1 closeout stall via bot
> finisher mode — SHIPPED (slice C.1), closeout 73s → 4.9s median (criterion 15 PASS). §5.6
> (2026-07-03 session-4 finding #2) **REOPENS and OVERTURNS §5.5's premise** that "3–4-player pacing
> is already good": QA data falsified it — the 3–4p MELEE, not the closeout, is what keeps a
> full match at 6.6–8 min vs the 2.5–5 min target. §5.6 is the ruling on that. Read §5.5 then §5.6.
>
> Code surface: `src/modes/PartyMatch.gd` (state machine, scoring, bounds, SD), `src/core/LevelLoader.gd`
> (bounds + level load), `src/entities/Player.gd` (`kill`/`respawn`/`is_dead`/`damage_level`),
> `src/core/InputBot.gd` + `src/core/BotProfile.gd` (targeting — §5.5/§5.6), `levels/dev_arena.json`.

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
  one-number change. (Retire `match_target_score`; alias if cheap.) **Confirmed by the owner (session-4
  directive re-read): 10 is fine — the lever for match length is STAGE LENGTH, not the kill count (§5.6).**

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

## 5.5 The 1v1 stage-closeout — bot "finisher" mode (RULING, 2026-07-03 session-4 finding #1) — SHIPPED

> **⚠ PREMISE PARTLY OVERTURNED — read §5.6.** This ruling correctly diagnosed and FIXED the 1v1
> closeout stall (SHIPPED, slice C.1; closeout 73s → 4.9s median, criterion 15 PASS). But its
> framing sentence — *"Stages resolve fine at 3–4 players (the melee produces kills); only the
> closeout drags"* — was **falsified by the session-4 C.1 QA** (4-bot self-play). The 3–4-player
> melee does NOT resolve fast: stages dwell 16–102s at ≥3 alive, which is what keeps a full match
> at 6.6–8 min vs the 2.5–5 min target. §5.6 is the ruling on the melee. The finisher fix below
> stands unchanged; §5.6 is additive.

**The finding (QA, 4-bot self-play watched to stage 9):** the match STRUCTURE is sound — stages
rotate, kills accumulate across stages (reached `[2,7,5,6]`), lives reset per stage, last-one-standing
resolves, match-end fires on the winning kill, zero laser SD. But the **2→1 endgame STALLS**: once a
stage is down to the final two players (1 life each), two L3 bots circle and refuel and neither commits
to the kill — **stage 1 sat 2-alive for ~73s.** Only the closeout drags. Net: ~7 kills across 8 stages
in ~7 min → a full match to 10 would run ~10–12 min against the spec's 2.5–5 min target (§2, §8 t7).

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
would regress the 3–4-player melee that already works). *(§5.6 note: the 3–4p melee does NOT already
work — it has the same "hits scatter, victims heal" failure mode, at a different scale; §5.6 fixes it
the same way — bot behavior, not lethality.)*

**THE FIX — a scoped "finisher" mode in `InputBot`, active only when the bot has ≤1 living opponent
left (i.e., 2 players remain).** The bot counts living opponents from the existing `arena.players`
(no new arena contract — preserves the §9 InputBot/Playtest field contract). While
`_alive_opponents(me) <= finisher_opponents_left`, the bot OVERRIDES its profile dials with the
finisher values below; outside the endgame it behaves exactly as today.

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

## 5.6 The 3–4-player melee pacing — CHASE-THE-WOUNDED targeting (RULING, 2026-07-03 session-4 finding #2)

> **This ruling REOPENS §5.5's off-limits premise** ("3–4-player pacing is already good; only the
> closeout drags") because QA data has FALSIFIED it. Per the studio's change-control doctrine a
> premise declared off-limits is reopened only when new evidence contradicts it — that condition
> is met. The reopening is decisive, not tentative.

### The finding (slice C.1 QA, 4-bot self-play)

The finisher fix (§5.5) WORKED — closeout 73s → **4.9s median / p90 12.8s / max 21s** (criterion 15
PASS), gating verified correct across 240 samples (finisher engages only at ≤1 opponent; 3–4p behaviour
byte-identical). **But a full match to 10 kills still runs 6.6–8 min vs the 2.5–5 min target.** The
cause is NOT the closeout — it is the **3–4-PLAYER MELEE**: stages dwell **16–102s while ≥3 are alive**
before the first eliminations. §5.5's premise is falsified.

### The match-length MATH (this bounds the fix — the lever is STAGE LENGTH, not kill count)

To bring ONE leader to 10 kills in a 4-way race takes ~8 stages (kills split ~evenly across 4 players).
- At **~50s/stage** → ~6.7 min (out of target, matches the observed 6.6–8 min).
- At **~15s/stage** → ~2.7 min (in the 2.5–5 min target).

So the ONLY lever that moves match length into target without changing structure is **stage length**:
the melee must produce its first 2–3 eliminations in **~10–15s**, not ~50–100s. The kill target (10) is
CONFIRMED-FINE by the owner (§2); do not touch it. Do not add a round timer (directive §1; §5.5 hard-reject).

### WHY the melee is slow (from the code — the SAME failure as the closeout, at melee scale)

In a 3–4-body scrum the bots **spread soft hits across different targets** and rarely stack **2+ hits
on ONE victim within the 8s `dmg_heal_time` window**. So a victim escalates to Lv1, then heals back to
Lv0 before the next hit lands on *them* — `damage_level` never compounds to the lethal Lv2. Kills
therefore depend on rare dead-on **edge** hits. This is by design in one half (survivable knocks — a
single hit almost never kills; the recovery gamble the owner wants preserved) but broken in the other:
the intended kill economy is *damage escalation from repeat hits* (directive §2/§3), and the bots never
execute the follow-up. **No bot targeting logic weights `damage_level` at all** — `_pick_target`
(`InputBot.gd` ~265) chooses on idle-hunt → leader_focus → edge_guard → nearest, none of which know or
care that a nearby opponent is already at Lv1 and about to heal. The bots are not doing the owner's
explicit dynamic: **"chase the wounded to finish before they heal / flee to survive."**

### RULING — the fix is ON-DESIGN bot CHASE-THE-WOUNDED targeting. This is the prime candidate, CONFIRMED.

Make bots **prioritize already-damaged opponents** and **commit to a wounded target** until it dies,
heals, or escapes range. This converts the melee's scattered hits into kills faster **via the damage
system exactly as the owner designed it** — repeat hits on one victim inside the 8s window compound to
Lv2 → the next near-edge hit rings them out. It changes **WHO** a bot targets, never **HOW LETHAL** a
hit is: no lethality constant changes, and — critically — it **cannot regress the recovery gamble for a
healthy player**, because it only re-weights targeting toward players who are *already past their first
hit*. A healthy, full-fuel player still eats a single hit and arcs back exactly as today; the danger is
the *second* hit landing before they heal — which IS the owner's flee/chase gamble ("flee to survive").
This is the surgical, on-design lever. It is BUILD-READY (see "build-ready vs owner-input" below).

**THE CHANGE — one new BotProfile dial + one Tuning constant + a targeting priority in `_pick_target`:**

1. **New per-difficulty dial `wounded_focus`** (add to `BotProfile`, alongside `edge_guard` /
   `leader_focus`): 0..1 probability that, on a reaction tick, the bot ACQUIRES the most-damaged
   opponent in chase range as its target. Difficulty-scaled table (comedy at the bottom, relentless at
   the top):

   | Level | `wounded_focus` | intent |
   |---|---|---|
   | L1 | **0.0** | oblivious flailer — never coordinates a finish (comedy preserved) |
   | L2 | **0.35** | notices sometimes; sloppy follow-up |
   | L3 | **0.6**  | the shipped-lineup workhorse — reliably chases the wounded |
   | L4 | **0.85** | relentless hunter — finishes what it starts |
   | L5 | **0.95** | (hard-mode) near-certain finisher |

2. **New Tuning constant `wounded_focus_range_mult = 2.0`** — a bot chases a wounded target within
   `_eff_attack_range() * wounded_focus_range_mult` (L3: 340 × 2.0 = **680px**). This is deliberately
   **wider than attack_range** so the bot pursues a *fleeing* wounded target across most of the stage
   (the owner's "chase before they heal"), not just one already in blast range. Scales with tier via
   attack_range (L2 560 / L3 680 / L4 920 — better bots chase further). A wounded target that flees
   past this radius / off-stage is released to `edge_guard`'s existing logic.

3. **`_pick_target` priority insertion** — insert the wounded logic **immediately after the idle-hunt
   override** (idle-hunt stays absolute top — anti-camp is a pillar) and **before `leader_focus`**:

   ```
   # (after the idle_hunt_target override, before leader_focus)

   # COMMIT / follow-up: stick to a wounded target you already committed to, so repeat hits land
   # inside the 8s heal window (the owner's "finish before they heal"). Release when it heals to
   # Lv0, dies, or flees past the chase radius.
   if _target != null and is_instance_valid(_target) and not _target.is_dead() \
           and _target.damage_level >= 1 \
           and me.global_position.distance_to(_target.global_position) <= _eff_attack_range() * Tuning.wounded_focus_range_mult:
       return _target

   # ACQUIRE: roll wounded_focus; on success, target the MOST-damaged opponent in chase range
   # (tie-break: nearest). This is the chase-the-wounded dynamic.
   if profile.wounded_focus > 0.0 and randf() < profile.wounded_focus:
       var prey = _most_wounded_in_range()   # new helper below
       if prey != null:
           return prey
   ```

   with the helper:

   ```
   func _most_wounded_in_range():
       var best = null
       var best_dmg := 0
       var best_d := INF
       var reach := _eff_attack_range() * Tuning.wounded_focus_range_mult
       for p in arena.players:
           if p == me or not is_instance_valid(p) or p.is_dead() or p.damage_level < 1:
               continue
           var d: float = me.global_position.distance_to(p.global_position)
           if d > reach:
               continue
           if p.damage_level > best_dmg or (p.damage_level == best_dmg and d < best_d):
               best_dmg = p.damage_level; best = p; best_d = d
       return best
   ```

**How the two clauses cooperate (the commit is the point):** the ACQUIRE roll (`randf < wounded_focus`,
re-rolled each `reaction_time` tick) makes a bot latch onto a fresh Lv1 victim within ~1–2 ticks; the
COMMIT clause then *holds* that target every subsequent tick as long as it stays wounded and in range,
regardless of the roll — so the bot doesn't flip-flop to `nearest` and abandon the half-finished kill.
This is the "commit to a wounded target" follow-up the directive asked for. When the victim heals to
Lv0 (they successfully fled — the gamble paying off) or dies or escapes the radius, the commit releases
and the bot returns to normal targeting.

**Interaction with §5.5 finisher & existing dials:** wounded-focus composes cleanly — in finisher mode
`_eff_attack_range()` is already ×1.4, so the chase radius widens further (correct: press the lone
survivor harder if they're hurt); if the lone opponent is healthy, `_most_wounded_in_range()` returns
null and targeting falls through to the finisher's "nearest + always-chase" path unchanged.
`edge_guard` (off-stage prey) still runs *below* wounded-focus in the chain and picks up any wounded
target that flees off-stage. `leader_focus` still runs below it — the villain-focus survives but no
longer competes with a live finish. No new arena contract field; the §9 InputBot/Playtest contract is
untouched (reads only `arena.players[i].damage_level`, which the amendment §13 already exposes for QA).

**Why probability < 1.0 (not a hard "always chase wounded"):** a hard gate would make all 3 surviving
bots dogpile the first Lv1 victim every time → an instant, un-flee-able Lv2 kill → the melee collapses
to single trades (fails criterion 16) and the recovery gamble dies (fails the flee-to-survive feel).
The difficulty-scaled probability + reaction_time spread means bots converge on the wounded *often but
not in lockstep*, so a wounded player with fuel can still sometimes flee and heal (criterion 21). This
is the knob to LOWER first (L3 0.6 → 0.45, or `wounded_focus_range_mult` 2.0 → 1.5) if QA shows a
bloodbath — NOT any global lethality constant.

### REJECTED alternatives (per the directive's request to accept/reject each)

- **REJECTED (primary) — damage-system tuning (faster escalation / longer heal).** Making hits compound
  across the scattered melee by lowering `dmg_heal_time` or raising `dmg_launch_mult` is a **global
  lethality change**. STATUS session-4 records that every global lethality lever tried regressed
  pacing (sting 30→40: fixed edge-kills but SD 28→41% and kill-decided 72→59%; edge_guard-up: worse on
  every axis). It ALSO erodes the healthy-player recovery gamble (a longer/heavier damage state makes a
  single hit closer to lethal). The whole value of wounded-focus is that it hits the melee-pacing target
  **without** this cost. Do not touch `dmg_heal_time` / `dmg_launch_mult`. *(If, and only if,
  wounded-focus alone underperforms in QA, the least-bad secondary would be a SMALL `dmg_heal_time`
  8→6 — it lengthens the window to land the follow-up without changing per-hit lethality — but this is
  a fallback to prototype only after wounded-focus is measured, never a first move, and it must re-pass
  criterion 20.)*

- **REJECTED (primary) — extend finisher-mode to ≤2 or ≤3 opponents.** Blunter and off-design: the full
  §5.5 override cranks aggression/range/commit/refuel/dodge for ALL bots across the whole melee, which
  is exactly the "everyone over-commits and whiffs / self-destructs" pattern that DRAGGED rounds in the
  edge_guard-up experiment (STATUS session-4). It also ignores the owner's articulated mechanic (chase
  the *wounded*, not "attack constantly"). Wounded-focus is more surgical and uses the damage system as
  designed. *(Kept as a flagged secondary ONLY: if wounded-focus underperforms, a MILD extension —
  `finisher_opponents_left` 1 → 2 with just the `aggression_floor` and `commit_time_floor`, NOT the
  attack_range/refuel/dodge overrides — would firm up the 3-player phase without the whiff-drag risk.
  Prototype after wounded-focus, not instead of it.)*

### Build-ready vs owner-input (directive point 3)

**BUILD-READY.** Wounded-focus is a small additive `InputBot`/`BotProfile` change that (a) directly
implements the owner's explicitly-stated dynamic, (b) is inherently feel-safe for the healthy-player
recovery gamble (it only re-weights targeting toward the already-damaged), and (c) has a clear
lower-only backoff knob if it over-shortens. No owner decision is required to build it.

**The one escalation trigger (do NOT force a fix past this):** if QA finds that NO setting of
`wounded_focus` + `wounded_focus_range_mult` can bring melee stages to ~15s **without** failing
criterion 20 (healthy full-fuel player survives a single mid-stage hit ≥8/10) or criterion 21
(flee-to-survive stays real) — i.e., the only way to hit 15s stages is to turn the melee into a
recovery-gamble-killing bloodbath — then STOP and escalate to the owner as a **target-vs-feel
calibration**: *is a ~40–50s 4-player brawl-stage actually acceptable for the Duck-Game churn (accept a
longer match or fewer target kills), or is the 2.5–5 min / 10-kill target the thing to bend?* Present
it as a values fork, do not thrash knobs. (This mirrors the earlier SD-rate escalation that resolved
cleanly once routed to the owner.)

### Tuning constants (add to §7)

```
# NEW (bot chase-the-wounded — 3-4p melee pacing, §5.6)
wounded_focus_range_mult = 2.0     # chase a wounded target within attack_range * this (fleers included)
# + per-difficulty dial `wounded_focus` in BotProfile: L1 0.0 / L2 0.35 / L3 0.6 / L4 0.85 / L5 0.95
```

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

# NEW (bot chase-the-wounded — 3-4p melee pacing, §5.6)
wounded_focus_range_mult   = 2.0   # chase a wounded (damage_level>=1) target within attack_range * this
# + per-difficulty dial `wounded_focus` added to BotProfile (NOT Tuning — matches the aggression/
#   edge_guard/leader_focus per-level pattern): L1 0.0 / L2 0.35 / L3 0.6 / L4 0.85 / L5 0.95

# CHANGED
double_ko_window     = 0.25 -> 0.50   # directive §2: last-two-within-0.5s = the ONLY SD trigger
match_target_score   -> RETIRED (renamed match_target_kills; alias if cheap)

# REMOVED (laser SD gone — directive §2)
sudden_death_time, laser_close_time, laser_revive_start_frac, sd_warning_lead
survival_requires_contact               # no survival point in a kill-race

# UNCHANGED / reaffirmed
intro_pop_stagger, countdown_beat, round_end_freeze (1.8), kill_credit_window (4.0, persist),
bot_levels [2,3,4], round_end_freeze cap 2.0
dmg_heal_time (8.0), dmg_launch_mult [1.0,1.33,1.66]   # §5.5 AND §5.6: NOT touched — both pacing fixes are
                                                       # bot behavior (targeting/commitment), never lethality
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
   ~7 min flags a stage-length or kill-rate problem. **(Re-verified post-§5.6 by criterion 17.)**

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
    Pillar 2 + damage should prevent it; there is no hard cap by design). **(Post-§5.6 this must hold
    driven by the melee-pacing fix, not just the closeout — see criteria 18/19.)**
12. **Kills per stage:** median **≥ 2 credited kills/stage**; suicides ≤ ~1/stage median (L2 comedy
    still lands ≥1 suicide/match). Unattributed kills ≤ 18% (credit-fix, kill-zone §11.2).

**1v1 stage-closeout (bot finisher, §5.5 — the session-4 finding-#1 fix; measured in a 4-bot match)**
15. **2-left closeout duration:** instrument the wall-clock from the moment a stage reaches exactly
    **2 not-eliminated players** (the `TWO LEFT!` trigger) to the deciding death. Across ≥20 such
    closeouts in 4-bot matches (2/3/4 lineup): **median ≤ 8s, 90th-percentile ≤ 15s.** A single
    closeout > 20s is a **soft flag** for review; **> 30s is a HARD FAIL** (this is the 73s regression
    guard). **SHIPPED result: median 4.9s / p90 12.8s / max 21s — PASS.**
16. **Finisher does not over-shorten the 3–4-player melee:** the 4→2 phase (COMBAT start → `TWO LEFT!`)
    still yields the bulk of kills; whole-stage median stays **8–18s** (criterion 11) and per-stage
    kills stay **≥ 2** (criterion 12) — i.e. finisher speeds the *closeout*, it must not make the
    early melee a single trade nor spike bot self-destructs (idle-P1 suicide rate stays ≤ ~1/stage,
    criterion 12).
17. **Full-match timing re-verified post-fix:** with the finisher AND wounded-focus (§5.6) live,
    criterion 7 must hold — a full 4-bot idle-P1 match to 10 kills completes in **2.5–5 min** (≥3
    matches), NOT the 6.6–8 min observed after C.1-alone. **Human-play note (judge by inspection):** a
    human-vs-1-bot closeout must also resolve — the finisher bot pushes and trades rather than orbits.

**3–4-player melee pacing (bot chase-the-wounded, §5.6 — the session-4 finding-#2 fix; measured in a 4-bot match, the stress case)**
18. **First-elimination timing (the core §5.6 target):** instrument the wall-clock from COMBAT start
    (BOUNCE) to the FIRST elimination in a 4-player stage. Across ≥20 four-player stages (2/3/4 lineup):
    **median ≤ 10s, 90th-percentile ≤ 18s.** A first-elimination > 30s is a **HARD FAIL** (this is the
    16–102s-dwell regression guard). Baseline to beat: the pre-§5.6 melee dwelled 16–102s.
19. **≥3-alive melee-phase dwell:** instrument the wall-clock from COMBAT start until the stage drops
    to exactly 2 not-eliminated players (`TWO LEFT!`). Across the same ≥20 stages: **median ≤ 12s,
    90th-percentile ≤ 20s.** Combined with criterion 15 (closeout ≤8s median) this yields the whole-stage
    ~8–18s of criterion 11. A ≥3-alive dwell whose median exceeds 20s means wounded-focus is not
    converting hits — re-check `wounded_focus` values and `wounded_focus_range_mult` BEFORE any global knob.
20. **Recovery gamble PRESERVED (the feel guardrail — must not regress):** a **healthy** (`damage_level
    == 0`), **full-fuel** player struck by a single qualifying **mid-stage** (NOT near-edge) hit
    survives — arcs back in bounds, not eliminated — in **≥ 8/10** scripted trials. (Reuse the amendment
    §15 edge-vs-mid harness; wounded-focus must not have changed this at all, since it only re-weights
    targeting toward the already-damaged.) A result < 8/10 is the escalation trigger of §5.6.
21. **Flee-to-survive stays real (bloodbath guardrail, soft):** across the aggregate stages, **≥ 25% of
    Lv1-damage events heal back to Lv0 without the player dying** — i.e. the chase is a *gamble*, not a
    guaranteed dogpile-kill. If < 25% (wounded players almost always die once hit), the melee has become
    a bloodbath: LOWER `wounded_focus` (L3 → 0.45) and/or `wounded_focus_range_mult` (→ 1.5) and re-run;
    do not touch lethality. (Soft flag; read alongside criterion 20 — both must hold together.)

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
finisher mode (§5.5) and the chase-the-wounded targeting (§5.6) read only existing `arena.players`
(and `players[i].damage_level`, already exposed for QA) — they add no new contract field. The
damage/edge/bounds combat internals are the amendment's scope, not this file's.

---

## 10. Depth-first build slice order (Director sequences from this)

The directive suggested (a) combat core incl. lives/elimination + bounds, (b) match mode + rotation,
(c) more levels. **Improved ordering — feel-riskiest thing first, and split bounds from match-mode:**

- **Slice A — DAMAGE COMBAT FEEL (make-or-break; amendment §12–§13).** SHIPPED. On the EXISTING single
  arena / bounds / round loop: damage state (Lv1/Lv2, 8s heal, red pulse) + post-cap launch multiplier;
  removed compounding sting; kept base sting. Feel validated first.
- **Slice B — LEVEL-RELATIVE BOUNDS + edge-relative validation (amendment §14).** SHIPPED. Bounds from
  play_rect + margins; edge-kill-vs-mid-survive rates re-verified.
- **Slice C — KILL-RACE MATCH MODE (THIS spec).** SHIPPED. Cumulative kills, target 10, survival point
  removed, laser SD + nodes removed, double-KO SD = revive-both-Lv2 1v1, level rotation, match-end on
  the winning kill, HUD pips → kills, banner table.
- **Slice C.1 — BOT FINISHER (§5.5; session-4 finding #1).** SHIPPED (08041b6). `_alive_opponents()` +
  finisher dial-overrides gated on `<= Tuning.finisher_opponents_left` + 6 new Tuning constants.
  Criterion 15 PASS (closeout 73s → 4.9s median). REVEALED finding #2 → slice C.2.
- **Slice C.2 — BOT CHASE-THE-WOUNDED (§5.6; session-4 finding #2 — THE CURRENT TASK).** Small additive
  `InputBot`/`BotProfile` change: new `wounded_focus` per-level dial + `wounded_focus_range_mult` Tuning
  constant + `_most_wounded_in_range()` helper + the two-clause (commit + acquire) insertion in
  `_pick_target` (after idle-hunt, before leader_focus). Does NOT touch PartyMatch, the damage system,
  or any lethality constant. Re-run criteria **18, 19, 20, 21** (new) and re-verify **7, 11, 17** hold.
  This is the immediate melee-pacing fix. Backoff knob if it over-shortens: lower `wounded_focus` /
  `wounded_focus_range_mult` (never lethality). Escalate to owner ONLY on the §5.6 trigger (can't hit
  ~15s stages without failing criterion 20/21).
- **Slice D — MORE LEVELS (level-designer).** A pool of ≥4–6 hand-built levels feeding the shuffle-bag;
  each auto-bounds via §14. Only meaningful once A–C prove the loop is fun on one level.

Rationale for reordering: the damage-launch feel is the single highest-risk, highest-value change and
must be validated in isolation before we invest in bounds derivation or a whole new match state
machine around it (depth-first: one slice to genuinely-good before widening).
