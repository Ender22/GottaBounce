# Spec: v0 Round Loop — turning DevArena into the real Party match

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD. **Last updated:** 2026-07-02.
> Sources of truth: `docs/VISION.md` (pillars), `docs/reference/GAME_DESIGN.md` §3 / §7 Mode 1,
> `docs/reference/FEEL_REFERENCE.md`. Builds directly on `src/modes/DevArena.gd` + `KillPipeline`.

## The player fantasy

You press play and **eleven seconds later someone is dead and it's hilarious.** Rounds are a drumbeat:
pop-pop-pop-pop spawn, "3-2-1-BOUNCE!", 10–30 seconds of screaming chaos, a freeze-frame with a big
dumb banner, pips tick up, and you're already fighting again. Death is a punchline, the score is a
running joke, and "one more round" is always true. The match loop IS the party — it must never let
the energy drop.

## v0 scope decisions (made here, now)

- **Boots straight into a match.** No title screen, no lobby, no join screen in v0. Launching the
  game = 1 human (P1, keyboard + gamepad) + 3 bots, one arena (`levels/dev_arena.json`), first to 10.
  Rationale: fastest path to fun; a title screen adds zero information to the feel test. Title/lobby
  is a later spec.
- **One arena, no rotation.** Circuits/shuffling are post-v0. The "leaderboard on the loading screen"
  from GDD §3 is replaced by the always-visible corner score pips (there is no loading screen).
- **No powerups, no mutators, no audio announcer.** All announcer moments are **text banners** in v0.
- **Score floor at 0** (resolves the GDD §3 open question, for v0): a suicide at 0 stays 0. Pips
  can't render negative, and a negative spiral punishes exactly the flailing player we want laughing,
  not raging (Pillar 4). Revisit only if suicide-griefing shows up in playtests.

---

## 1. Match flow state machine

One authoritative state enum in the arena mode (rename/extend `DevArena` → this is now the real
Party mode). States and transitions:

```
BOOT ──► MATCH_START ──► ROUND_INTRO ──► COUNTDOWN ──► COMBAT ──► ROUND_END ─┬─► ROUND_INTRO (next round)
                                             ▲              │                └─► MATCH_END ──► (rematch) MATCH_START
                                             │              ▼                                └─► (quit) exit
                                             └───── SUDDEN_DEATH (a COMBAT sub-phase, returns via ROUND_END)
```

### BOOT → MATCH_START
- Scene loads level, spawns 1 human + 3 bots (existing DevArena code), zeroes all scores, shows the
  four corner HUD cards immediately. No input needed — flows straight into ROUND_INTRO.

### ROUND_INTRO (~1.4s) — the one-by-one pop-in
- All players are placed at their spawn points, **suspended** (physics/gravity off, input off),
  invisible.
- Pop them in one at a time, player-index order, **`intro_pop_stagger = 0.35s`** apart (4 players =
  1.05s to last pop + 0.35s beat = ~1.4s total).
- A "pop" = scale 0 → 1.15 → 1.0 over 0.25s (bounce ease, FEEL_REFERENCE §5.3 energy) + a small
  star/dust particle + **name tag** appearing above the head.
- **Name tags:** `P1` `P2` `P3` `P4`, rendered in the player's skin color (pink/blue/green/yellow),
  chunky outlined text. Tags stay visible through COUNTDOWN and fade out 1.0s into COMBAT.
- Camera: snapped to full-stage framing (existing `CAM_MAX_ZOOM` frame) — the intro is a stage
  establishing shot.

### COUNTDOWN (~1.45s) — "3-2-1-BOUNCE!"
- Starts the moment the last pop-in lands. Center-screen banner beats: **"3" → "2" → "1"** at
  **`countdown_beat = 0.35s`** each, then **"BOUNCE!"** (holds 0.4s then pops away).
- During 3-2-1: players stay suspended at spawn. **Aiming is allowed** (stick rotates the jetpack
  arrow — lets you pre-aim, feels alive), **no thrust, no drift, no movement**.
- On **"BOUNCE!"**: physics + input enable for everyone on the same frame, everyone drops from their
  spawn onto the surfaces below — a synchronized first bounce is the starting gun. All players start
  each round with a **full fuel tank**.
- Total pre-round (intro + countdown) ≈ **2.85s**. Budget cap: **3.0s**.

### COMBAT (10–30s by design)
- Everyone has **1 life**. Existing rules apply: ring-out at `bounds`, hazard instakill, all deaths
  via `KillPipeline.killed`.
- A hidden round clock starts at BOUNCE (drives sudden death; **not** rendered — see HUD §3).
- Dead players do NOT respawn mid-round (delete DevArena's `RESPAWN_DELAY` respawn — that was dev
  glue). Dead players' corner cards get a skull/dimmed treatment.
- Round ends when **≤1 player is alive** → ROUND_END, *unless* the double-KO rule fires (§2) →
  SUDDEN_DEATH.

### SUDDEN_DEATH — closing laser walls (v0-simplest version, decided)
Two triggers:
1. **Anti-stall timer:** round clock reaches **`sudden_death_time = 20s`** with ≥2 players alive.
   Lasers activate in place, mid-combat — no freeze, no revive.
2. **Double-KO tiebreak (GDD §7):** the last living players die within **`double_ko_window = 0.25s`**
   of each other. The tied players (only them) are **revived** at spawn points with **full fuel**,
   a **"SUDDEN DEATH!"** banner holds 0.8s (inputs locked, players suspended), then combat resumes
   with lasers active. No 3-2-1 — keep it fast and panicky.
- **The lasers:** two full-height vertical instakill planes at the left/right blast-zone edges,
  moving toward stage center at constant speed, **fully closing in `laser_close_time = 10s`**
  (≈ each wall travels ~1080px → ~108 px/s at current bounds). Rendered as thick, glowing,
  animated danger lines (readability over prettiness — they must scream "do not touch").
- Laser contact = instakill (`cause = "laser"`), passes through level geometry (kills players only,
  v0). Kill credit rules apply as normal (§2) — smashing someone into the laser is a kill.
- **No recursion:** if the finalists double-KO *again* (in sudden death, or into fully-closed
  lasers), nobody gets the survival point ("NOBODY WINS" banner) and the round just ends. One
  revive max per round.
- Hard consequence: **no round can exceed ~30s of combat** (20s + 10s close). This is the whole
  anti-stalemate system — no other round timer exists.

### ROUND_END (~1.8s freeze)
- Fires the moment the round is decided. **Gameplay freezes** (players halted, physics paused —
  a held freeze-frame, like a fighting-game KO) while UI animates in real time.
- Center banner: **"P3 WINS THE ROUND"** in the winner's color (or **"NOBODY WINS"** on a no-survivor
  round). Below it, smaller: the round's score deltas (e.g. `P3 +2  ·  P1 +1  ·  P4 −1`).
- **Score pips animate during the freeze:** each earned point pops a pip into the winner's/killers'
  corner cards (staggered 0.15s, satisfying tick-tick); a suicide pops a pip *out*.
- Duration **`round_end_freeze = 1.8s`** (≤ 2.0s hard cap — death is cheap, keep the drumbeat).
- Then: if match-over condition (§2 tie rule) → MATCH_END; else → ROUND_INTRO.
- **Timing budget, end to end: last death → next round's "BOUNCE!" ≤ 4.5s** (1.8 freeze + 1.4 intro
  + 1.2 countdown-to-unlock ≈ 4.4s). This number is a pillar-4 contract — QA verifies it (§5).

### MATCH_END — winner celebration + rematch/quit
- Triggered from ROUND_END when a player has **≥ 10 points AND strictly leads** (§2 tie rule).
- Freeze-frame holds; camera does the punch-zoom toward the winner (FEEL_REFERENCE §7); winner plays
  the win pop (scale 1.3→1.0 ×2, §5.3) on a small pedestal framing. Everyone else stays frozen
  mid-chaos (funnier than clearing the stage).
- Banner: **"P1 WINS THE MATCH!"** in winner color + final scoreline for all four players.
- Prompt (appears after a **1.0s input guard** so nobody skips it accidentally):
  **`A — REMATCH      B — QUIT`** (keyboard: `Enter` / `Esc`).
- **REMATCH** → zero all scores → MATCH_START (same arena, same bots). **QUIT** → exit the game
  (v0: quit to desktop; there is no menu to return to).

---

## 2. Scoring rules (GDD §3 decided values + edge cases resolved here)

Base: **+1 per kill · +1 for surviving the round · −1 for a suicide · first to 10 wins · floor at 0.**

### Kill credit — who "caused" a ring-out
- **`kill_credit_window = 2.5s`** (decided N): the last opponent whose smash/knockback touched you
  within 2.5s before your death gets the kill. Implementation seam already exists —
  `Player.last_attacker` / `_attacker_timer` (currently 2.0s at `Player.gd:485`): **bump to 2.5 and
  move it into `Tuning.gd`**.
  - *Rationale:* `hitstun_max` is 0.55s and a full-tank launch (~1400 px/s) crosses the 1920px stage
    in ~1.5–2s; 2.5s also covers the slow lofted arc over the *top* blast zone with margin, while a
    hit from 3+ seconds ago genuinely wasn't the cause anymore.
- Applies to **every death cause**: ring-out, spikes, crusher, laser. Knocked into a hazard =
  attacker's kill (already wired at `Player.gd:517`).
- **Suicide vs killed (classification):** at death, if `last_attacker` is a *living-or-dead opponent*
  within the window → it's a **kill** (+1 attacker, victim scores 0 — being killed is never −1).
  If `last_attacker` is null/expired/yourself → **suicide** (−1 victim, floored at 0).
- **Kills from beyond the grave count.** If P2 smashes P1 and then dies, and P1 ring-outs 1.5s later,
  dead P2 still gets +1. (Fair, and a great punchline.)
- One player killing two others in a round = +2. No cap.

### Survival point
- Awarded to the **sole survivor** at round end (+1, on top of any kills — a dominant round is +2/+3).
- **No survivor** (double-KO after the one allowed sudden-death revive, or everyone dead) → nobody
  gets it. Kills/suicides from that round still count.

### Simultaneous death (the double-KO)
- If the final ≥2 living players die within **0.25s** of each other → no survival point yet; any
  kill/suicide points from those deaths **score normally and immediately**; the tied players revive
  into SUDDEN_DEATH (§1) and fight for the survival point (plus any laser kills).
- A second double-KO in the same round = no survival point, round over. Never revive twice.

### Tie at 10 (match end condition)
- Checked **only at ROUND_END**: match ends iff `max(score) ≥ 10` **and exactly one player holds the
  max**. If two players sit at ≥10 tied, play **another full round** (banner: "TIEBREAKER!") and
  re-check. Simple, no overtime rules, uses the loop we already have. Points past 10 count (11 beats
  10).
- **"MATCH POINT"** banner moment: fires at ROUND_END whenever a player first reaches 9+ (see §3).

---

## 3. HUD spec

**Prime directive (Pillar 5): the center of the screen belongs to the fight.** No persistent HUD
element may sit inside the middle **60% × 60%** of the screen. Banners are the only thing allowed
to enter it, and only transiently (and the big center banners only during freezes/countdown).

### Corner cards (one per player, the whole persistent HUD)
- Placement: **P1 top-left, P2 top-right, P3 bottom-left, P4 bottom-right**, tucked into the corners
  with a safe margin. Chunky rounded card (VISION art direction: no OS-default widgets), tinted with
  the player's skin color.
- Card contents, top to bottom:
  1. **Identity:** small bouncer head icon (skin sprite) + label `P1`…`P4`.
  2. **Score pips: 10 slots, 2 rows of 5.** Filled pip = solid disc in player color; empty = dark
     outline. Pips pop in/out with a scale-bounce during ROUND_END (§1). Ten slots exactly — the
     card itself teaches "first to 10".
  3. **Fuel gauge:** horizontal bar (~120px), mapped to `Player.fuel` 0–100, in the player color
     with a bright edge — glanceable mid-chaos (GDD §10). Flashes briefly when a full tank is banked
     (super-boost-ready tell).
- **Dead this round:** card dims to ~40% + small skull over the head icon until next ROUND_INTRO.
- **No round timer is rendered — decided.** Rounds are 10–30s; a clock is pure clutter and pulls
  eyes off the fight. The 20s sudden-death moment announces *itself* (banner + lasers). If playtests
  show the 20s trigger feels ambush-y, the fix is a 3s "warning flicker" on the screen edges — not
  a clock.

### Banner system (text-only announcer, v0)
One banner visible at a time; later banners queue (max queue 2, drop the oldest non-critical).
Style: oversized chunky outlined type, pop-in 0.15s / hold / pop-out 0.2s.

Two positions:
- **CENTER** (allowed only when gameplay is frozen or pre-round): countdown beats, "BOUNCE!",
  round/match win banners, "SUDDEN DEATH!" (double-KO revive variant), "TIEBREAKER!".
- **TOP-BAND** (upper 15% of screen, smaller type, mid-combat — never blocks the fight):
  "FIRST BLOOD!", "TWO LEFT!", "SUDDEN DEATH!" (20s-timer variant), "MATCH POINT — P2".

| Moment | Text | Position | Hold |
|---|---|---|---|
| Countdown | `3` `2` `1` | CENTER | 0.35s each |
| Go | `BOUNCE!` | CENTER | 0.4s |
| First kill **of the match** (once per match) | `FIRST BLOOD!` | TOP-BAND | 1.0s |
| Exactly 2 alive (once per round, only if round started with ≥3) | `TWO LEFT!` | TOP-BAND | 1.0s |
| Sudden death (either trigger) | `SUDDEN DEATH!` | 20s: TOP-BAND / revive: CENTER | 1.0s / 0.8s |
| Round win | `P3 WINS THE ROUND` (winner color) / `NOBODY WINS` | CENTER | round_end_freeze |
| Match point (player first reaches ≥9, at ROUND_END) | `MATCH POINT — P2` | TOP-BAND, shown at next round's COUNTDOWN | 1.2s |
| Match win | `P1 WINS THE MATCH!` + scoreline + `A — REMATCH  B — QUIT` | CENTER | until input |

("FIRST BLOOD" is per-*match*, not per-round — per-round would fire every ~15s and become wallpaper.
Audio announcer replaces/augments these same trigger points later; the trigger list is the contract.)

---

## 4. Bots — v0 quick-start defaults

- **Count: 3 bots** (fixed) → 4-player chaos, the minimum for "readable chaos" to matter and for
  TWO LEFT / kill-steal dynamics to exist.
- **Difficulty: mixed, decided — levels 2 / 3 / 4** (replacing DevArena's flat `BOT_LEVEL = 3`):
  - **P2 = L2** — the punchline. Flails, panic-boosts itself off the map (free comedy + shows the
    −1 suicide rule working).
  - **P3 = L3** — the solid mid: a fair fight for a new human.
  - **P4 = L4** — the menace: hunts, edge-guards, makes the human sweat and gives the score race a
    villain.
- *Rationale (GDD §8.2):* a mixed lineup makes the first session instantly fun for one human — a
  guaranteed victim, a rival, and a threat — and demonstrates the entire bot skill spread in one
  match. Bots play by human rules, no cheating (inviolable).
- Expose the three levels as an exported array (`bot_levels = [2, 3, 4]`) for tuning; no difficulty
  UI in v0.

---

## 5. Success criteria (QA-verifiable via gbplay + eval + screenshots)

Feel/tuning constants live in `Tuning.gd` as always; the arena must expose (read-only via eval) a
`state` string, `round_index`, `round_clock`, and `scores` so QA can assert the machine, not guess.

**Flow & timing**
1. **Cold boot to combat:** launching the arena scene reaches "BOUNCE!" (state `COMBAT`) within
   **6s** of scene ready, with zero input. (eval `state` polling + timestamps.)
2. **One-by-one intro:** a `burst` capture during ROUND_INTRO shows player counts 1→2→3→4 across
   frames (~0.35s apart), each with a visible colored name tag. (Read the PNGs.)
3. **Countdown lock:** holding boost + a direction during 3-2-1 moves no player: every player's
   position stays within ±2px until BOUNCE (eval positions across the countdown), and fuel stays
   at max (no drain).
4. **Round turnaround ≤ 4.5s:** timestamp the round-ending kill (eval), timestamp the next `COMBAT`
   state; delta ≤ **4.5s** (allow 5.0s hard fail line). Repeat over 3 consecutive rounds.
5. **No mid-round respawn:** kill a bot early (eval `KillPipeline.kill(bot, "ring_out", null)`),
   wait 5s — it must still be dead and its corner card dimmed/skulled (screenshot) until next round.

**Scoring**
6. **Kill credit:** eval-set `bot.last_attacker = p1` then `KillPipeline.kill(bot, "ring_out", p1_path)`
   → `scores[0]` +1, and a screenshot shows P1's new pip filled during ROUND_END.
7. **Credit window expiry:** set `last_attacker`, wait > 2.5s (past `kill_credit_window`), then
   ring-out the bot with no further contact → attacker gets nothing, victim scores −1 (suicide).
8. **Suicide floor:** with P1 at score 0, self-ring-out (drive P1 off the edge, no attacker) →
   `scores[0]` stays 0; at score ≥1, same action decrements by exactly 1 and a pip visibly empties.
9. **Survival point:** let one bot be last alive → its score +1 (plus its kills) at ROUND_END; a
   NOBODY-WINS round awards no survival point to anyone (eval scores before/after).

**Sudden death**
10. **20s trigger:** keep ≥2 players alive to `round_clock` = 20s (eval — neutralize bots by parking
    them via eval if needed) → state `SUDDEN_DEATH`, "SUDDEN DEATH!" text visible in a screenshot,
    two laser walls visible at the arena edges.
11. **Walls close & end the round:** laser walls' x-positions converge at a constant rate and any
    player touching one dies instantly (`cause == "laser"`); the round is **always over by
    round_clock ≤ 31s** across 3 forced-stall rounds.
12. **Double-KO revive:** eval-kill the last two living players on the same frame → both revive at
    spawns with full fuel, lasers active, and **no survival point** was awarded for the double-KO
    (eval scores). A second same-frame double kill ends the round with no survival point and no
    second revive.

**Match end**
13. **First to 10 + tie rule:** eval-set `scores = [9, 9, 0, 0]`, give P1 a kill + survival (reach
    11 vs 10... simplest: set `[9,0,0,0]` and let P1 win a round) → MATCH_END screen with winner
    banner + REMATCH/QUIT prompt (screenshot). With a forced `[10, 10, 0, 0]` tie at ROUND_END, the
    match must **continue** (state returns to ROUND_INTRO, "TIEBREAKER!" banner).
14. **Rematch:** at MATCH_END, press A after the 1s guard → all scores reset to 0, state reaches
    `COMBAT` within 6s. Pressing A within the first 1.0s does nothing.

**HUD & readability**
15. **Corner HUD only:** a mid-combat screenshot shows 4 corner cards (pips + fuel) and **no
    persistent UI pixels inside the middle 60%×60%** of the frame.
16. **Fuel gauge live:** hold boost for 1s → P1's fuel bar visibly shorter in a before/after
    screenshot pair; bounce twice → visibly longer.
17. **Banner moments fire:** across one full observed match, screenshots capture FIRST BLOOD (once
    only), TWO LEFT, a round-win banner with correct player color, and the match-win screen.

**Performance & feel**
18. **60fps under load:** `perf` during a 4-player combat round with shake/hitstop firing reports
    avg ≥ 55 fps, no hitch > 100ms.
19. **Feel check (judgment, evidence-backed):** QA plays 3 full matches vs the 2/3/4 bot lineup and
    reports: did the L2 bot self-destruct at least once per match (comedy check)? Did the human ever
    have to sweat the L4 bot? Was any round > 35s wall-clock from BOUNCE to ROUND_END (must be no)?

---

## 6. New tuning constants (add to `Tuning.gd`)

```
intro_pop_stagger      = 0.35   # s between spawn pop-ins
countdown_beat         = 0.35   # s per 3/2/1 beat
round_end_freeze       = 1.8    # s of KO freeze-frame + pip animation (hard cap 2.0)
sudden_death_time      = 20.0   # s of combat before lasers
laser_close_time       = 10.0   # s for walls to fully meet at center
double_ko_window       = 0.25   # s — simultaneous-death tiebreak window (GDD §7)
kill_credit_window     = 2.5    # s — last-attacker credit (replaces hardcoded 2.0 in Player.gd)
match_target_score     = 10
bot_levels             = [2, 3, 4]
```

## 7. Explicitly out of scope for this spec

Powerups, stage rotation/circuits, title screen & menus, local multiplayer join flow (P1 human only),
audio announcer & music, controller rumble changes, pause menu (nice-to-have; not required to pass),
persistent stats/unlocks. The DevArena dev-respawn behavior is **removed**, and `Playtest`/`InputBot`
contract fields (`players`, `scores`, `bounds`, `nearest_opponent()`, `stage_rect()`) must survive
the refactor unchanged.
