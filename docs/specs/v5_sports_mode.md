# v5 — SPORTS MODE (bounce-ball / goal-scoring — the 4th GameMode)

> **Spec owner:** Lead Game Designer. **Scope:** the fourth `GameMode` (after BRAWL / TRIALS /
> GAUNTLET): two teams knock a big bouncy BALL into the enemy GOAL. It is the movement game applied
> to a ball — you fly / bounce / smash to move the BALL, not to kill. First team to N goals wins.
> **Read alongside:** `docs/GAME_ESSENCE.md` (the fantasy-fit gate), `docs/VISION.md` (pillars —
> inviolable), `docs/specs/v3_content_plan.md` (the `GameMode` seam + the additive-hook pattern),
> `src/modes/GameMode.gd` / `BrawlMode.gd` / `TrialsMode.gd` / `GauntletMode.gd` (the seam + the two
> reference non-brawl modes), `src/entities/StormBall.gd` (the ball prop we reuse), `src/entities/
> GoalGate.gd` (the goal trigger we mirror). **No code here** — a build-ready design contract.
>
> **Fence (requirement 7):** SPORTS touches **NO fenced feel/lethality constant** in `src/core/
> Tuning.gd`. The BALL's physics are **NEW, mode-owned constants** (they live on `Ball.gd` /
> `SportsMode.gd`, exactly as `TrialsMode.FALL_PENALTY` and `GauntletMode` wave data live on their
> modes), kept **deliberately separate** from the player-feel constants (`gravity`, `super_boost_
> impulse_full`, `smash_impulse_max`, `normal_boost_max_speed`, ...). Any change that would edit a
> fenced Tuning constant is out of scope and must be escalated, not silently done.

---

## 0. Player fantasy & core-verb declaration (GAME_ESSENCE obligation)

**Fantasy:** *"I flew across the pitch, met the ball at full boost, and rocketed it past the keeper
into the goal — and my teammate followed it in for the rebound."* SPORTS is the movement game with
the KILL replaced by the GOAL. The joy is unchanged: the arc of a boost, the commit of a super, the
scramble of a loose ball. Death is demoted from the loop; **positioning to strike the ball IS the
entire game** — the purest "movement as the whole loop" of any mode.

**Core verbs exercised** (the game is these — a build that doesn't exercise them fails):
- **BOUNCE** — the pitch floor + walls are all bouncy; you and the ball never settle (Pillar 2).
- **FLY / BOOST** — traversal from your half to the ball at centre / to the far goal **requires
  flight** (arena sized so > a bounce's reach; §5, §6-SP4). This is load-bearing, not scenery.
- **SUPER-SMASH → POWER SHOT** — the aimed super is re-skinned from "kill move" to "the cannon
  shot": a super-launched body meeting the ball is the fastest, farthest strike (the highlight goal).
- **RECOVER** — after you whiff a shot or get body-checked off the ball, you claw back into the play
  (the recovery gamble, now for possession instead of survival).

**What SPORTS deliberately does NOT do:** it is NOT a kill-race. Smashing a rival is legal comedy
(knock them off the ball) but **scores nothing and eliminates no one**. The ball is the only score.

---

## 1. Core loop

**Two teams, ball at centre, first to N goals.**

1. **Teams.** Team 0 (RED) vs Team 1 (BLUE). Recommended sizes **1v1 and 2v2**; bots fill empty
   slots. Team membership is derived from roster position (§4 `spawn_plan`) — **no new MatchConfig
   field**: humans occupy indices `0..human_count-1`, bots fill after, and the roster splits in half
   (`team = 0 if index < total/2 else 1`). 1v1 = 2 players; 2v2 = 4. (Odd totals are disallowed by
   the config flow, same as BRAWL's `2 <= humans+bots <= 8` invariant — SPORTS additionally requires
   an **even** total; the shell clamps to the nearest even count and logs, never crashes.)
2. **Kickoff.** A single `Ball` spawns at arena centre; both teams spawn at mirrored ends. The
   existing STAGE_INTRO pop-in + "3-2-1-BOUNCE!" countdown is the kickoff whistle (reused verbatim).
3. **Play.** Players fly/bounce/smash into the ball to drive it toward the enemy goal. Body contact
   moves it; a **super-launched or knocked-flying body = a bigger impulse** (the power shot, §2).
4. **Goal.** The ball entering a team's `goal_zone` scores **+1 for the OTHER team**, freezes play
   with a "GOAL!" beat (reuses STAGE_END), and **resets ball + all players to kickoff** (reuses
   `_begin_stage`). A goal = one "stage" (the machine-mapping trick §4, exactly as GAUNTLET maps a
   wave and TRIALS maps a course to a runner STAGE).
5. **Win.** First team to **N goals** (default N=5, the goal cap) wins the match → winner banner +
   punch-zoom (reused). Recommend **N=5** for 1v1, **N=7** for 2v2 (config `kills_to_win` reused as
   the goal cap, §4).

**Do players die / get eliminated?** **NO — pure ball focus (recommended, adopted).** A smash just
knocks a player back (full existing knockback comedy, Pillar 3), but:
- it **never scores** (`on_kill` does no team scoring, §4), and
- it **never eliminates** — `lives_per_player` is forced high (the TRIALS/GAUNTLET pattern) so any
  rare out-of-bounds is an **instant respawn at the player's kickoff spot**, and the match never ends
  on a death. The enclosed bouncy pitch (§5) makes ring-outs rare anyway; high lives is the
  belt-and-suspenders that keeps the focus on the ball. **Sudden death never triggers** (its double-KO
  condition needs `<=1 not-eliminated`, unreachable when no one is eliminable) — same as TRIALS.

This keeps SPORTS a **movement showcase**: constant flight and body contact, no death downtime.

---

## 2. The BALL — the ONE genuinely-new entity (`src/entities/Ball.gd`)

**Reuse verdict:** the shipped **`StormBall.gd` is the model** — a `RigidBody2D` that already: takes
field gravity in `_integrate_forces` (`GravityField.get_gravity_at`), caps to a max speed, ricochets
off surfaces via a `PhysicsMaterial` (`bounce`), owns a player-sensing `Area2D`, exposes
`receive_smash(impulse, attacker)` (adds `impulse/mass`), and draws a glossy toybox ball. `Ball` is
**`StormBall` with the powerup-weapon behavior stripped and persistence added** — do NOT extend the
combat pipeline; do NOT touch the fenced player-feel constants.

**`class_name Ball extends RigidBody2D`** — the only new entity. Spec (all values mode-owned consts
on `Ball.gd`, NOT in `Tuning.gd`):

| Property | Value | Rationale (from shipped `Tuning.gd`, the source of truth per v3_content_plan B.3) |
|---|---|---|
| `BALL_RADIUS` | **60 px** | Chunky + readable at pitch zoom; ~1.35x the 44px player body so a contact reads as a real physical strike (StormBall's 15 is a tiny projectile — wrong read for a hero ball). |
| `mass` | **0.6** | Light enough that a boost drives it, heavy enough to feel weighty. Impulse math below is tuned around this. |
| restitution (`PhysicsMaterial.bounce`) | **0.85** | Lively caroms off bumper walls/floor, loses a little each hit so loose balls settle back into play rather than pinballing forever (Pillar 5 readability). |
| `friction` | **0.1** | Same as StormBall — keeps rolls from sticking. |
| gravity | **field** (`gravity_scale = 0`, add `GravityField.get_gravity_at` in `_integrate_forces`) | Identical to StormBall/Player — the ball falls onto the bouncy floor and bounces = constant motion (Pillar 2). Uses the shipped `Tuning.gravity` READ-ONLY (no new gravity constant, no fence touch). |
| `BALL_MAX_SPEED` | **2400 px/s** | Below the player `max_speed` (3000) so even a power shot stays **chaseable** — a rocketed ball a fast flier can still catch = the highlight chase. Applied as `limit_length` in `_integrate_forces` (StormBall pattern). |
| `continuous_cd` | `CCD_MODE_CAST_RAY` | StormBall setting — a fast ball never tunnels through a wall or the goal mouth. |
| collision layer | **`1 << 6` (a new, unused "ball" bit)** | See "collision & who-drives-it" below. |
| collision mask | **`1 << 2` (surfaces)** | Bounces off every platform / bumper wall / floor (all on `LAYER_SURFACES`, mirroring StormBall's surface mask). |
| lifetime / pop | **NONE** | Unlike StormBall, the Ball is **persistent for the stage** — it never times out and never pops on contact. It is re-created fresh each kickoff (§4 `on_stage_ready`). |
| hitstun / damage to players | **NONE** | The ball is **not a weapon** — it never calls `player.receive_smash`, never stuns, never stings, never sets `last_attacker`. Players are unaffected by touching it; they *drive* it. |

**Collision & who-drives-it (the clean, one-entity design):** the Ball is on its **own layer
(`1<<6`)** which the Player's `_hit_area` (mask `players | props`) does **NOT** sense, and the
Player's body mask (`MASK_SURFACES` only) does **NOT** collide with. Therefore the Player's existing
smash pipeline never touches the ball, and **ALL ball-force logic lives in the ONE new entity** — so
the drive strength is a mode-owned constant, cleanly outside the fenced smash/impulse constants
(requirement 7). The Ball owns a **player-sensing `Area2D`** (mask `1<<0`, radius `BALL_RADIUS + 8`),
exactly like StormBall's `_hit_area`, and each physics frame, for every overlapping live Player, it
imparts force to ITSELF (never to the player):

- **Contact direction:** `dir = (ball - player).normalized()` (push the ball away from the body) —
  blended toward the player's travel direction `player.velocity.normalized()` so a moving body
  "carries" the ball the way it's flying (the natural dribble/strike read). Recommend
  `strike_dir = (0.5*away + 0.5*player_vel_dir).normalized()`.
- **Impulse magnitude** (mode-owned consts on `Ball.gd`):
  - `BALL_TOUCH_IMPULSE = 500` — a floor so even a gentle nudge visibly moves the ball (matches the
    shipped `pu_ball_hit_impulse = 500` feel — a known-good "ball gets knocked" number).
  - plus `BALL_DRIVE_GAIN = 0.9 * player.velocity.length()` — the faster you fly into it, the harder
    it goes. A plain boost tops out near `normal_boost_max_speed = 760`, so a boosted strike imparts
    ~`500 + 0.9*760 ≈ 1184` before the mass divide → the ball clearly travels goal-ward.
  - **× `BALL_SMASH_MULT = 2.0`** when the contacting player `is_super_active()` **OR**
    `in_hitstun()` (a fired-super body or a knocked-flying body — the "smash = bigger impulse" the
    brief asks for). A super-launched body flies far above 760 (impulse 2800 → capped chase), so a
    power shot easily saturates `BALL_MAX_SPEED = 2400` = the cannon.
  - Apply as `apply_central_impulse(strike_dir * mag)` (or `linear_velocity += strike_dir*mag/mass`,
    StormBall's `receive_smash` form), then `limit_length(BALL_MAX_SPEED)`.
  - **Per-player contact cooldown** (`_touch_cd` ~0.12s per player, StormBall's `_reflect_cd`
    pattern) so an overlap doesn't machine-gun impulses every frame — one clean strike per touch.

**Measurable feel targets** (verified in §6): a boosting body (~760 px/s) strike sends the ball
**≥ 900 px/s** toward its travel line; a super-launched-body strike sends it **≥ 1800 px/s** (the
power shot); a dead-rest ball takes **≥ 500 px/s** from a slow touch (never "dead" on contact).

**Bounces off players (brief requirement):** satisfied by the sensing push — the ball is shoved away
from any body it contacts, which reads as bouncing off the player. No hard rigid player-ball
collision is needed (and none exists, by the layer choice) — this keeps players from being jostled
off their own line by the ball, preserving movement feel.

---

## 3. Goals — `goal_zone` level object (`src/entities/GoalZone.gd`)

**Reuse verdict:** mirror **`GoalGate.gd`** (the TRIALS trigger) — a display-only `Area2D` that
latches on overlap and is read via a group. The only differences: it senses the **BALL layer**
(not players), it is **team-tagged**, and it draws a **team-colored net/mouth** instead of a portal
ring.

`{ "type": "goal_zone", "x", "y", "w", "h", "team": <int> }` — `x,y` = CENTER, `w,h` = the trigger
rectangle (a tall goal mouth). `team` = the **DEFENDING** team (the team whose goal this is), so a
ball entering it scores for the OTHER team (soccer convention — the natural read).

`class_name GoalZone extends Area2D`:
- `collision_layer = 0`, `collision_mask = 1 << 6` (the Ball layer) — senses ONLY the ball.
- `add_to_group("goal_zone")`; stores `team: int` and `scored: bool` (latches once on
  `body_entered` when `body is Ball`), plus `_flash` for the GOAL pop.
- Display (Pillar 5): a high-contrast team-colored goal mouth / net + a bright rim, drawn code-side
  like GoalGate's `_draw` (no OS widgets, reads at pitch zoom). Flashes on `scored`.
- **Scoring detection:** `SportsMode.is_stage_over()` scans `get_nodes_in_group("goal_zone")`; if any
  `scored`, the stage ends (via `polls_goal()`), and `stage_end_banner()` (called ONCE) reads WHICH
  zone latched to credit the scoring team (§4). Idempotent — the increment happens once at
  STAGE_END, never in the per-frame poll (the TRIALS `_course_results` pattern).

**Ball containment behind the goal:** the pitch (§5) has a short **back wall behind each goal_zone**
(bumper tier) so a scored ball can't leave `bounds`; the stage ends the instant it enters the zone
anyway, so the ball is torn down at kickoff regardless.

---

## 4. GameMode contract — `SportsMode extends GameMode`

`src/modes/SportsMode.gd` (`class_name SportsMode extends GameMode`), registry entry
`{&"sports": preload("res://src/modes/SportsMode.gd")}` alongside brawl/trials/gauntlet in
`PartyMatch.MODE_REGISTRY`. Fills the SAME seam methods — **no `PartyMatch` rewrite**, exactly ONE
new additive hook (§4.1). Mode-owned state: `_team_scores := [0, 0]`, `_teams: Array` (index→team,
built in `spawn_plan`), `_goal_cap: int`, `_arena_path: String`, `_last_scoring_team := -1`.

| Seam method | SportsMode behavior |
|---|---|
| `id()` | `&"sports"` |
| `display_name()` | `"SPORTS"` |
| `hud_scene()` | new `res://scenes/ui/SportsHUD.tscn` (§5) — two big team scores + GOAL flash. NOT MatchHUD. |
| `polls_goal()` | **`true`** (reuses the existing additive seam). The runner polls `is_stage_over()` every COMBAT frame and ends the stage on a goal — no death required. (This is the SAME hook TRIALS/GAUNTLET already flip; BRAWL stays `false` → C7 parity, no new plumbing here.) |
| `configure(runner, config)` | Force the runner's own economy inert so it never eliminates or ends on a kill-race (the TRIALS/GAUNTLET pattern): `runner.lives_per_player = 99`, `runner.match_target_kills = 999999`. Read the **goal cap from the reused `config.kills_to_win`** (`_goal_cap = maxi(1, config.kills_to_win)`; default 5). Resolve `_arena_path` (`config.single_arena_path` or the default `res://levels/sports_court.json`). Reset `_team_scores=[0,0]`, `_last_scoring_team=-1`. Idempotent (also called on rematch). |
| `spawn_plan(runner, config)` | Humans first, then bots, to an **even** total (clamp + log if odd). Build `_teams` in the SAME order the runner spawns (plan[i] → player i), splitting the roster in half: `team = 0 if i < total/2 else 1`. Each descriptor sets `team` (the field ALREADY in the descriptor — reused, per the brief) plus a **team colorway skin** (team 0 → warm skins e.g. `pink`/`orange`; team 1 → cool skins e.g. `blue`/`purple`) so teammates read as one side on-field. `bot_level` from config (GAUNTLET/BRAWL pattern). |
| `next_level_path(runner)` | **The single sports arena every stage** (`_arena_path`) — GAUNTLET's single-arena pattern. Each stage IS one point; the arena reloads → fresh goals + kickoff for free. |
| `on_stage_ready(runner)` | **THE ONE NEW HOOK (§4.1).** (Re)spawn the `Ball` at arena centre and free any prior ball. Called at the tail of `_begin_stage` after players are placed (so the ball exists for the kickoff, and is torn down + re-centred every point). |
| `is_stage_over(runner)` | `true` when any `goal_zone` in the group has `scored` (a goal went in). NOT last-one-standing. A smash/knockback never satisfies this (only the ball crossing a goal line does). |
| `wave_spawn_plan(runner)` | `[]` — SPORTS has a fixed roster (no per-stage bot swap). Returns empty → the runner skips the despawn/respawn-wave block entirely (parity; teams stay stable across points). |
| `on_kill(runner, killer, victim, cause)` | **No team scoring, no elimination side-effects.** A "kill" here is a rare out-of-bounds knock; the runner already respawns it (high lives). SportsMode does nothing to `runner.scores` (kill-race scores stay 0). Optional: record a stat only. |
| `match_winner(runner)` | Return a **representative player index of the team that reached `_goal_cap` with a strict lead**, else -1. (The runner needs a *player* index for the winner pop/punch-zoom/`PLAYER_COLORS`; return the first player index whose `_teams[idx] == winning_team`.) Guarded to fire only from the STAGE_END check path (a goal ends the stage; the cap is evaluated at STAGE_END, like GAUNTLET's victory guard) so a mid-play poll can never declare a premature win. |
| `stage_end_banner(runner)` | Read the latched `goal_zone` → scoring team = the OTHER team; **increment `_team_scores[scoring]` ONCE here** (idempotent per stage), set `_last_scoring_team`. Return `{text: "GOAL!  RED %d — %d BLUE" % [...], color: <scoring team color>}`. |
| `match_end_banner(runner)` | `{text: "%s WINS!" % team_name, color: team_color, subline: "RED %d — %d BLUE" % _team_scores}`. |
| HUD read helpers | `team_scores() -> Array`, `goal_cap() -> int`, `last_scoring_team() -> int` — polled by SportsHUD each frame (the GAUNTLET/TRIALS `runner._mode`-poll pattern). |

**Explicitly reused runner plumbing (unchanged):** STAGE_INTRO pop-in + countdown (the kickoff
whistle), camera framing, `LevelLoader` + `pit_void_rendering`, squash/stretch juice, name tags, the
multi-life respawn path (any out-of-bounds → respawn), the full smash/knockback pipeline (legal
comedy), `_enter_match_end` winner pop + punch-zoom. The powerup director is disabled by authoring
**zero `powerup_spawner`s** in the sports arena (no new toggle — TRIALS' trick). **No fenced Tuning
constant is read or written** (the field-gravity READ is the same read StormBall/Player already do).

### 4.1 The ONE new additive runner hook — `on_stage_ready(runner)`

**Why a new hook is needed (precisely):** the Ball is a **stage-scoped, non-player prop** that must
be (re)created at arena centre **after** `_load_stage` rebuilds the arena each point. The existing
hooks do NOT fit: `spawn_plan`/`wave_spawn_plan` build **players/bots** (`_spawn_player`), not props;
`configure` runs once at match start and `_load_stage` clears `_level_root` every stage, so a
ball spawned there is destroyed and, worse, there is no per-stage "re-centre the ball" moment.
There is **no generic "stage is built, add your props" seam** today.

**The minimal, BRAWL-safe addition** (mirrors exactly how `polls_goal` and `wave_spawn_plan` were
added in v3/v4):
1. Add to `GameMode` base: `func on_stage_ready(_runner) -> void: pass` (default no-op).
2. Add ONE call in `PartyMatch._begin_stage()`, at the **tail** (after the per-player respawn/pop-in
   loop, after the `wave_spawn_plan` block): `_mode.on_stage_ready(self)`.

**Parity proof:** BRAWL/TRIALS/GAUNTLET inherit the no-op → `_mode.on_stage_ready(self)` does
literally nothing for them → **byte-for-byte behavior unchanged** (the identical argument that
protects C7 for `wave_spawn_plan`). SPORTS is the only override. This is the entire runner delta for
the mode: **one no-op seam + one call site.**

### 4.2 MatchConfig needs (reuse-first)

**No new field required.** SPORTS reuses:
- `mode_id = &"sports"`, `human_count` + `bot_count` (team sizes derived as roster-halves, §1/§4),
- `kills_to_win` **reused as the goal cap** (semantically "the number to win"),
- `skin_ids` / `character_ids` (SportsMode overrides skins by team colorway in `spawn_plan`),
- `arena_mode = SINGLE` + `single_arena_path = res://levels/sports_court.json` (GAUNTLET pattern;
  empty → the mode's default arena).

The only flow rule SPORTS adds is the **even-total** requirement (§1), enforced by clamp-and-log in
`spawn_plan` (never a crash). A dedicated ModeSelect "SPORTS" flow can pre-set 1v1 / 2v2 presets that
write these existing fields — no schema change.

---

## 5. New-pieces list (the whole build)

1. **`src/entities/Ball.gd`** — `class_name Ball extends RigidBody2D`. The one new entity (§2).
   Reuses StormBall's field-gravity + `PhysicsMaterial` + sensing-Area architecture; strips
   pop/lifetime/hitstun; adds persistence + the mode-owned drive constants + the glossy team-neutral
   (white/gold) ball art (BallGloss pattern).
2. **`src/entities/GoalZone.gd`** + a `"goal_zone"` case in `LevelLoader.load_level` (§3). Mirrors
   `GoalGate` + its LevelLoader case; senses the Ball layer, team-tagged, group `goal_zone`.
3. **`scenes/ui/SportsHUD.tscn` + `src/ui/SportsHUD.gd`** — built as a .tscn + `theme.tres` (Pillar 5,
   CLAUDE.md). Two big team-colored scores (RED left / BLUE right) with a goal-cap read, a full-screen
   **"GOAL!"** flash on `last_scoring_team` change, and a centre score readout. **Must implement the
   full HUD interface the runner calls** (as TrialsHUD/GauntletHUD do): `setup(players, colors,
   skins)`, `reset_scores()`, `hide_center()`, `show_center()`, `show_top()`, `set_dead()`,
   `animate_scores()`, `show_match_end()`, `show_match_prompt()` — the per-player-pip ones can be
   no-ops; the team-score display polls `runner._mode.team_scores()` each frame.
4. **`levels/sports_court.json`** — a **symmetric, two-goal, all-bouncy** arena (§6-SP4 flight gate):
   - Full-width **trampoline-tier floor** (NO flat standable ground — Pillar 2 / "no standable
     ground"). Bumper **side walls** with a **goal mouth (gap)** at mid-height each end; a `goal_zone`
     just inside each mouth (`team:0` left, `team:1` right) with a **bumper back wall** behind it.
     A bumper **ceiling** (or bounds top) keeps the ball in. A few free-standing **bumpers** near
     centre for carom chaos (reuses the shipped `bumper` tier — zero new primitive).
   - Mirrored `player_spawn`s at each end (2 per side for 2v2). **Zero `powerup_spawner`s** (disables
     the director).
   - **Sizing for the flight gate:** centre-to-goal and end-spawn-to-centre distances **> 527 px**
     (max spring drift) and **> 395 px** (trampoline drift) so reaching the ball at centre and
     pressing it to the far goal **REQUIRE boost** (GAME_ESSENCE Rule A). Elevated bumpers force
     aerial contests. `kill_shape` is cosmetic here (enclosed pitch); document it as `enclosed_hole`
     or a new `sports_court` label — data-only, no lethality change. (`level_index` will be -1/0 for a
     non-pool arena — cosmetic only, same as GAUNTLET/TRIALS arenas.)
5. **`src/modes/SportsMode.gd`** + registry entry `&"sports"` (§4).
6. **Runner delta:** the one additive hook `GameMode.on_stage_ready()` + its single call site in
   `PartyMatch._begin_stage()` (§4.1). **Enable a "SPORTS" ModeSelect card** routing to a 1v1/2v2
   preset that writes the existing MatchConfig fields (§4.2).
7. **Team readability polish (flag, not required for v1):** name-tag hue is per-index `PLAYER_COLORS`;
   teammates are distinguished by **team colorway skin** on-field, which is sufficient. A per-team tint
   of the name tags is a nice-to-have that would need a tiny runner-agnostic tweak — **do not** fold it
   into v1; note it for a polish pass.

---

## 6. Validation plan (QA drives rendered; movement-first, measurable)

Reuse `tools/run_game.ps1` + `python tools/gbplay.py` (screenshot / key / hold-action / eval / tree).
Boot a SPORTS config (`GameConfig.match_config.mode_id = &"sports"`).

- **SP1 Reachability:** ModeSelect → SPORTS (1v1) launches to live play; SportsHUD shows `0 — 0`, a
  single Ball is visible at centre, two goal mouths read at pitch zoom (screenshot + `eval` on
  `state`, and `get_tree().get_nodes_in_group("goal_zone").size() == 2`, and exactly one `Ball`).
- **SP2 Ball is drivable by MOVEMENT (the fantasy):** a driven human boosts into the resting ball;
  the ball's speed goes from ~0 to **≥ 900 px/s** within 1 frame of contact and travels toward the
  boost direction (`eval` the Ball's `linear_velocity` before/after). A slow touch imparts **≥ 500
  px/s** (never dead-on-contact).
- **SP3 Power shot:** a super-launched body (or a knocked-flying body) meeting the ball drives it
  **≥ 1800 px/s** (`eval` ball speed after a scripted super-into-ball). Proves "smash = bigger
  impulse" and that the super re-skins to the cannon.
- **SP4 Flight-required (GAME_ESSENCE gate):** a zero-boost / fuel-pinned driven attempt **cannot**
  reach the centre ball from an end spawn (falls short / never contacts) ≥ 9/10; every real ball
  contact from spawn logs ≥ 1 boost activation. Proves the pitch tests movement, not bounce-hopping.
- **SP5 Goals score + reset:** driving the ball through the enemy goal mouth fires `is_stage_over`,
  shows "GOAL!", increments the correct team's score by exactly **+1** (own-goal into your OWN zone
  scores the other team — verify the convention), and **resets** ball to centre + players to spawns
  for the next kickoff (`eval` `team_scores` and Ball position across the STAGE_END → next STAGE_INTRO).
- **SP6 Team wins at N:** with `_goal_cap` set low (e.g. 3) for the test, one team reaching 3 goals
  ends the match with the correct "TEAM WINS!" banner + punch-zoom on a member of that team; the
  match does NOT end before N (`eval` `state == MATCH_END` only at/after the Nth goal).
- **SP7 No one dominates / no degenerate line:** across a bot-vs-bot match, both goals are reachable
  and scored on (goals recorded at BOTH zones over a match), and the mean time-to-goal is a real
  rally (> ~3s, not an instant centre-tap) — proves the pitch isn't a one-shot funnel.
- **SP8 Movement-showcase, not degenerate (motion-health):** a driven full match shows a **high
  continuous airborne fraction** and **zero locomotion pathologies** in `bot_motion_health()` (no
  `stuck_episodes`, no `underside_bounces` head-banging, no camping) — a goal that only happened via
  a motion pathology is a FAIL even if SP5 passes (the GAME_ESSENCE motion gate).
- **SP9 No kill-race / no elimination:** `runner.scores` stays all-zero across the match; no player is
  ever eliminated (`lives_left` never hits 0 → respawns); sudden death never triggers; no kill banner
  ever shows (`eval` scores + a driven out-of-bounds respawns, not ends).
- **SP10 Seam parity — no runner rewrite (C7):** BRAWL still passes `v1_frontend_shell` **C7** and
  TRIALS/GAUNTLET their criteria verbatim after SPORTS lands (SPORTS added ONLY via the registry +
  the new mode class + new entities/HUD/arena + the ONE no-op `on_stage_ready` hook). Parse gate
  clean (`--headless --path . --editor --quit`; grep no `Parse Error` / `hides a native` /
  `Failed to load script` / `not declared`).
- **SP11 No-widget / looks-like-the-game:** SportsHUD uses `theme.tres` (no OS-default labels), the
  Ball is a glossy readable sphere and the goal mouths are high-contrast team-colored at match zoom
  (Pillar 5). Teammates read as one side (team colorway skins).

## 7. Fence & pillar summary

- **Fenced feel constants: UNTOUCHED.** The Ball's physics (`BALL_RADIUS`, `mass`, restitution,
  `BALL_MAX_SPEED`, `BALL_TOUCH_IMPULSE`, `BALL_DRIVE_GAIN`, `BALL_SMASH_MULT`, `_touch_cd`) are NEW,
  **mode-owned** constants on `Ball.gd`/`SportsMode.gd` — deliberately separate from the player-feel
  constants in `Tuning.gd` (`gravity`, `super_boost_impulse_full`, `smash_impulse_max`,
  `normal_boost_max_speed`, ...). Field gravity is READ-ONLY (the same read StormBall/Player do).
- **Pillars honored:** constant motion (all-bouncy pitch, no standable ground, no camping — Pillar 2);
  flight-required traversal (SP4 gate — GAME_ESSENCE); readability over prettiness (chunky ball, team
  colorways, high-contrast goal mouths — Pillar 5); death is cheap/absent-here (players never die,
  focus on the ball — Pillar 4 re-skinned); emergent physics comedy preserved (legal knockback +
  loose-ball scrambles — Pillar 3).
- **New mechanics are minimal as required:** exactly **ONE new entity (`Ball`)**, **ONE new level
  object (`goal_zone`/`GoalZone`)**, **team scoring** in the mode, and **ONE new no-op runner hook
  (`on_stage_ready`)**. Everything else is reuse.
```
```
