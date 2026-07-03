# Owner directive — 2026-07-03 — Lives-based Duck-Game kill-race + damage system + edge-relative kills

> High-authority owner design directive (Devin), resolving the recovery-gamble-vs-pacing fork.
> This DISSOLVES the sudden-death-rate tension (no round timer) rather than tuning it, and unifies
> several parked items. Supersedes parts of `v0_round_loop.md`, `v0_combat_lethality.md`,
> `v0_kill_zone_recovery.md`, and the SD-target recalibration. Reconcile every match/combat spec here.

## 1. Match & round structure (this is what dissolves the SD-rate problem)

- **No round time limit.** Rounds are NOT timer-bounded.
- **Lives per character, default 1** (configurable). Default 1 → stages resolve fast and we churn
  through many levels quickly, **like Duck Game**.
- **A stage/round ends by ELIMINATION** (players out of lives), never a timer. With 1 life, the
  first deaths end the stage fast.
- **SUDDEN DEATH is ONLY the simultaneous double-KO case:** it triggers *only* if **2 players lose
  their LAST life within 0.5s of each other**. The 20s laser-wall timer SD is **REMOVED**. (This
  replaces both the old 20s-timer SD and the double-KO-revive path as the SD definition.)
- **MATCH = Duck-Game-style party mode:** players **race to 10–15 KILLS across MULTIPLE levels
  with FREQUENT NEW LEVELS.** Kills accumulate across stages toward the match target; rotate to a
  new level often. (First-to-10-*rounds*-on-one-arena is replaced by a kill-race across rotating
  stages.)

## 2. Lethality model (this is what fixes "nothing kills" without killing the recovery gamble)

- **Edge-relative kills:** a **dead-on hit** on a player who is **near the edge of the walkable
  level** knocks them far enough to die (out the side/off-screen). The **same hit mid-stage does
  NOT kill** — they arc back.
- **Kill sources (the intended kill economy):** most kills come from EITHER (a) hitting an
  **already-damaged** opponent, OR (b) a **dead-on hit near the edge**. Otherwise a player **with
  fuel** should be able to **fly back** (full boost and/or super boost) — the recovery gamble,
  preserved and now the DEFAULT outcome of a non-edge, non-damaged hit.

## 3. Damage system (the red-pulse reeling state — now fully specified; supersedes the compounding sting)

- **Lv1 damage** after **1 hit**: **slow red pulse**, lasts **8 seconds** (heal timer).
- **Lv2 damage** if hit **while already at Lv1**: **fast red pulse**; **resets the heal timer to 8s**.
- **Knockback multiplier:** Lv1 → launched **+33% further**; Lv2 → **+66% further**.
- **Heal:** returns to undamaged after the 8s timer elapses with no new hit.
- This is the escalating-lethality mechanism: hitting a damaged player launches them 33–66% further
  → out (especially near an edge). It IS the flee/chase dynamic (damaged players flee to heal;
  attackers chase to finish before the 8s). It **replaces** the compounding-sting executioner.
- (Composes with the earlier DECISIONS "transient vulnerable state" — this directive sets its exact
  params: 2 levels, 8s heal, 33%/66%, hit-count trigger. Owner chose the longer (8s) flee/chase end.)

## 4. Kill zone / bounds — level-relative

- The kill zone is **relative to the level's edges.** Horizontally-long levels get **horizontally-
  further** kill zones. Bounds derive from level geometry (a margin outside the walkable extent),
  not fixed per-arena constants. (Generalizes the kill-zone runway to scale with each level.)

## 5. What this supersedes / resolves (for the reconciliation)

- **The SD-rate pacing tension is DISSOLVED.** No round timer; rounds are lives-based and Duck-Game
  fast. The ≤25%→≤40% SD-target recalibration and test-31 active-climax gate are **MOOT** (there is
  no timer-SD to rate). SD is now a rare simultaneous-double-KO tiebreaker only.
- **Removed:** the 20s `sudden_death_time` laser-wall mechanic as a round-ender; the first-to-10-
  rounds-on-one-arena loop; the compounding-sting executioner.
- **KEEPER from the kill-zone work (all still good):** the hit-solidity launch model (dead-on vs
  glance), the credit fix (kill_credit_window 4.0 / persist), frequent edge kills, and the runway
  concept — now generalized to level-relative bounds (§4).
- **Needs:** multiple levels (frequent rotation — currently only 1 arena → level-designer),
  significant PartyMatch rework (lives, elimination round-end, kill-race match, level rotation),
  the damage system in Player + a red-pulse visual, and edge-relative bounds derivation.

## 6. Open sub-questions for the spec (flag, don't block)

- With 1 life, on death does a player wait for the stage to end then respawn on the next level, or
  is there a short respawn within a stage? (Duck-Game reading: out for the stage, new stage loads.)
- Stage-end trigger with 1 life + 4 players: last-one-standing, or first-elimination? (Kill-race
  scoring is by kills regardless, but the stage-end + level-rotation cadence needs defining.)
- Match target 10–15 kills: pick a default; how is the winner shown; ties.
- How "near the edge" is defined for the edge-relative kill (a margin band inside the bounds?).
