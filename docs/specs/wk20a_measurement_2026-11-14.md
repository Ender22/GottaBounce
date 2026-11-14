# WK-20a: Who wins and why. Measurement protocol and pre-registered decision rules (2026-11-14)

**Owner:** game-designer (protocol + rulings) · **Runs it:** qa-playtester · **Backlog:** WK-20a (feeds WK-20b, WK-20c, WK-25, WK-89)
**Inputs read:** BACKLOG WK-20a/b/c + WK-89 · audit D-18 · CD1-02 / CD1-06 · DECISIONS 2026-07-19 (knockback +25 %) and
2026-11-14 (weekend autonomy, ruling c) · `Tuning.gd` · `Player.gd` (`_handle_smashes` ~L844-897, `receive_smash` L1003-1063,
`kill` L1167) · `PartyMatch.gd` (`_bounce_go`, `_on_killed`, `_on_smash_landed`) · `BrawlMode.on_kill` · `InputBot.gd` · `BotProfile.gd`.
**Budget:** at most 90 min of rendered game time. Plan ≈ 55 min, with the rest kept for extensions (§9).
**Rules for this session:** no code edits, no commits, and nothing written to `Tuning.gd`. Every override is a runtime `gbplay eval`
toggle, restored at the end of each run, and the game process exits at the end. Ephemeral driver/recorder scripts are saved as
**`.txt`** under `tools/out/wk/`. Never use `.gd`: `tools/out` has no `.gdignore`, so a `.gd` file there gets parsed by the editor and
class-cache gate. This session uses the game slot, so serialize it with builders.

---

## 0. Run order at a glance (QA)

| Step | What | Stages | ≈ game time |
|---|---|---|---|
| 0 | WK-89 / CD1-06 repro: 3 LIVES-3 stages, `kills` vs `scores` | 3 | 4 min |
| A | Knockback side effects: 4 bots, arms A/B alternate per stage | 40 (extend to 56) | 14 min (+6) |
| B-cal | HumanSim calibration (discarded) | ≤ 12 | 4 min |
| B1 | 3 HumanSim-newcomer + 1 CPU (MIX → L2) | 30 | 10 min |
| R | Recovery contact sheet segment (excluded from stats) | ~6 | 3 min |
| B3 | 3 HumanSim-newcomer + 1 CPU **L1** | 16 | 5 min |
| B2 | 3 HumanSim-regular + 1 CPU L2 | 16 | 5 min |
| C | (optional) gate-only arm, only if A ≠ B | 12 | 4 min |

If time runs short, cut from the bottom up: C goes first, then B2. Steps 0, A, B1 and R are mandatory.

---

## 1. The fantasy at stake (why we measure before building)

- **Q-A, knockback:** you get clipped and you're scared, then you fight the jetpack back to the island and you're saved. That
  "scared-then-saved" beat is the recovery gamble (FEEL_REFERENCE §4: *"recovery window always exists — ring-out comes from
  velocity, not from being frozen"*). D-18 claims the owner's +25 % launch silently made every graze a damaging, max-stun hit.
  If that's true in play, the gamble is dead and WK-20b is justified. If it's only true on paper, we don't add semantics.
- **Q-B, self-KO:** *"I KO'd five people, I have 2 points, and the robot won."* Pillar 4 says death is cheap and funny, and pillar
  1 says low floor. An invisible −1 that lands only on the people still learning recovery works against both. But the −1 is
  also the GDD's brake on reckless self-destructs. We need numbers on what it costs, and on whether the CPU result is really a
  scoring problem at all.

**Owner guardrails (non-negotiable, DECISIONS 2026-07-19 + 2026-11-14 (c)):**
- `dmg_launch_mult` [1.25, 1.66, 2.08] and the hitstun triad (0.15 / 0.00025 / 0.55, DO-NOT-TOUCH) **stay**. Only what *feeds*
  them may change.
- KILLS 10, LIVES 1 default and no timer stay.
- The self-KO −1 is a **studio** rule (GDD §3, v1 spec §2). The designer may change it.

---

## 2. What the code actually does (static read; QA confirms with the mechanism checks in §5.4)

### 2.1 D-18 is correct, but only the Lv0 row changed
`_handle_smashes` multiplies by the victim's `damage_launch_mult()` **before** calling `receive_smash` (Player.gd ~L864). So the
sting gate (L1033), the escalation gate (L1043) and hitstun (L1060) all read the multiplied impulse. The L1050 comment
"keep the unscaled impulse" refers only to `knockback_taken_mult`, not to the damage multiplier.

Lv0 numbers for a Standard-profile victim on a cap-limited hit (super attacker; impulse = 2200 × (0.6 + 0.4 s)):

| solidity s | pre-mult | ×1.25 (today) | gate ≥1500, before → today | sting (30·s), before → today | hitstun, before → today |
|---|---|---|---|---|---|
| 0.00 | 1320 | 1650 | no → **yes** | 0 → 0 | 0.480 → **0.550** |
| 0.10 | 1408 | 1760 | no → **yes** | 0 → 3.0 | 0.502 → 0.550 |
| 0.15 | 1452 | 1815 | no → **yes** | 0 → 4.5 | 0.513 → 0.550 |
| 0.2045 | 1500 | 1875 | threshold → yes | 6.1 → 6.1 | 0.525 → 0.550 |
| ≥ 0.318 | ≥ 1600 | ≥ 2000 | yes → yes | unchanged | 0.550 → 0.550 (cap) |

What this means for design:
1. **Graze fuel drain is tiny.** It's at most 4.5 fuel for s ≤ 0.15, less than a quarter of one bounce refill (20). The sting
   formula is `30·s`, so a true graze still drains about 0.
2. **Graze hitstun goes up by at most 0.07 s**, from 0.48 to 0.55, and only on hits with s < 0.32.
3. **Escalation is the real change.** Every Lv0 graze now takes the victim to Lv1. The next hit within the 8 s heal window then
   launches ×1.66 instead of ×1.25 (+33 %). Lv1 and Lv2 grazes escalated before the owner's ruling too (1320 × 1.33 = 1756 ≥ 1500).
   So **only Lv0 changed**, which matches WK-20b's "at Lv0" scope.
4. **Launch velocity is identical with or without WK-20b**, because the owner's +25 % is applied either way. Any lethality
   that comes from velocity is owner-ruled and out of scope.

### 2.2 Why bots (almost) never self-KO (`InputBot.gd`)
1. **Zero-latency recovery.** `_danger_recover` runs every physics frame (120 Hz) and is not gated by `reaction_time` (L185-188).
   A human needs about 0.2-0.35 s just to notice, and longer for a speck at 0.46-0.62 zoom.
2. **All-knowing void sense.** It raycasts 2200 px down (`_over_void`), does fuel-reach arithmetic (`_can_reach`,
   `CROSS_FUEL_PER_PX`), and aborts on a 0.45 s velocity look-ahead (L339-352). A human can't compute reachability. They commit
   and find out.
3. **White-noise "panic".** L1 `recovery_skill` 0.2 rotates the aim ±0.8 rad, **re-rolled every frame** (L372-373). At 120 Hz that
   averages out to the correct heading. Human error is low-frequency: a wrong heading held for hundreds of ms.
4. **Whiff guard.** Bots won't whiff a super out over open void (`SUPER_CARRY` 720). Humans do, and that's the GDD's
   self-destruct comedy.
5. **No opening idle.** Bots act on the BOUNCE frame. Humans read the screen (R-07; CD1: idle P2 was dead about 4 s in).
6. **Perfect recovery-super trigger** (fuel ≤ 12 or out-speed > 1400 or stranded, L387).

So the BotProfile comment "L1 = funny/flailing (self-rings-out a lot)" and GDD §8 ("low-level bots… self-destructing") are
**not delivered by the implementation**. That's a separate bot-fun finding, routed in §7.3.
Note: "bots 0 self-falls" is n = 6 deaths from one match. In July, 4-bot batches showed 41 % uncredited deaths (DECISIONS
verdict #5). Study A re-measures the bot self-KO share properly.

### 2.3 Two of the CD's three options are no-ops as written
- **(b) "No penalty until a player has scored once" is identical to today's rule.** The score is already floored at 0
  (`BrawlMode.on_kill` L224). A player who has never scored has 0 and the floor absorbs the −1, and once they've scored, both
  rules apply the −1. It's excluded from measurement, and a meaningful variant (Rb′) is in §6.4.
- **(c) "With 2+ humans, CPU MIX resolves to L1-L2" is already what happens for 3H + 1 CPU.** MIX gives bot 0
  `bot_levels[0]` = **L2** (`BrawlMode` L155-156). CD1's CPU *was* L2. The meaningful variant is "MIX → **L1**" (Rc′, §6.4).

### 2.4 CD1-06 static read
`_on_killed` appends to `_cur_stats.kills` and calls `_mode.on_kill` (scoring) **in the same function, behind the same state gate**
(PartyMatch L688-718). A credited score without a `kills` entry would need `_cur_stats` to be empty during COMBAT, and I found
no path that does that. Leading hypotheses, which the repro (§4) tells apart:
- **H1:** the CD read `round_stats[0]`, which is the match's first stage, not the 3-lives stage.
- **H2:** the CD read mid-stage, while the live stage still sat in `_cur_stats`. `round_stats` holds only completed stages.
- **H3:** a real gap.

---

## 3. Common session setup (both studies)

1. **Build record.** Write `git rev-parse HEAD`, `git status --short`, and the SHA-1 of `git diff src/core/Tuning.gd` to
   `meta`. The tree is dirty today: `Tuning.gd`, `Player.gd` and `PowerupSpawnDirector.gd` are modified by in-flight work. Re-hash
   at the end. The hashes must match, which proves QA persisted nothing.
2. **Launch:** `powershell -File tools/run_game.ps1 res://scenes/Arena.tscn`.
   Confirm the scene with `python tools/gbplay.py eval "return get_tree().current_scene.scene_file_path"`. The old project also
   serves port 9090.
3. **Standard profile check:** `eval "return get_tree().current_scene.players.map(func(p): return p.profile.eff_knockback_taken())"`
   → all 1.0 (cold boot = "bouncer" for every slot).
4. **No match end:** `eval "get_tree().current_scene.match_target_kills = 999; return true"` (ScoreScreen's race bar clamps; safe).
5. **Scoreboard skip.** The recorder sets `cs._score_skip = true` 0.2 s into each SCOREBOARD (saves 3.2 s per stage, game-neutral).
6. **Relaunch the game between studies.** It gives clean signal connections and a clean RNG, and it fixes the slow-run zombies.
   Call `seed(<batch id>)` once at batch start for best-effort reproducibility.
7. **Recorder.** Build one ephemeral eval-installed Node, `WK20aRecorder`, kept as `tools/out/wk/wk20a_recorder.txt`.
   It writes JSON to `ProjectSettings.globalize_path("res://tools/out/wk/")` at every STAGE_END, so gbplay's 4000-char limit
   doesn't apply. It connects to:
   - **`EventBus.smash_landed`** fires in the same call stack right after `receive_smash`, so the victim's live state is the
     post-hit state. Per smash, log: `t` (`round_clock`), `state`, `attacker` (credited idx), `victim`, `s`, `launch_scale`,
     `launch_speed`, `angle_deg`, `by_super`, `pre_level` (= `info.victim_damage_level`), `post_level` (= `victim.damage_level`
     now), `sting` (= `info.sting_applied`), `fuel_before` (= `victim_fuel_after + sting`), `hitstun` (= `victim._stun_timer`
     now, which is exactly the value just set), `pos`, `off_stage` (= `cs.is_off_stage(victim)`), and three edge distances:
     - `d_launch`: distance from `pos` along the launch unit vector to the `cs.bounds` edge.
     - `d_side`: distance to the nearer side bound.
     - `d_bottom`: distance to the bottom bound.
     Outcome fields are filled in later:
     - `rehit_t`: the next smash on the same victim.
     - `death_t`, `death_killer`, `death_cause`.
     - `died_no_rehit_4s`: true if the victim died ≤ 4.0 s after the hit with no other smash received in between.
     - `carry_px`: max displacement along the launch vector over 1.5 s, or until death/rehit.
     - `recovery_super`: the victim fired a super ≤ 2.0 s after the hit.
   - **`KillPipeline.killed(victim, cause, attacker)`.** The attacker is already credit-resolved: 6.0 s ring-out window, smash or
     shove ≥ 500 or stomp (`Player.kill` L1167). Per death, log `t`, `victim`, `killer` (−1 if null), `cause`, `self_ko` (killer
     < 0 or == victim), `fuel`, `damage_level`, `opening` (`t` < 3.0), `off_stage`, `dt_last_smash_received`,
     `dt_last_own_super` (whiff proxy: the victim fired a super ≤ 1.5 s earlier and landed no smash in that window),
     `score_before` (the recorder's cached copy) and `score_after` (`cs.scores`).
   - **`EventBus.super_fired`** feeds `recovery_super` and the whiff proxy.
   - **`EventBus.combat_started`** applies the arm (Study A) and starts the HumanSim opening timers (Study B).
   - **4 Hz sampler**, per player: `damage_level`, `fuel`, alive.
   - **Per stage:** `batch`, `arm`, `stage_index`, `level_name`, `explosive_arena`, a live snapshot of
     `{smash_sting_min_impulse, hitstun_per_impulse, pu_max_on_field}` taken at the stage's first smash, `length_s`,
     `entered_sd`, roster `[{idx, role}]`, `round_stats[-1].kills.size()` (cross-check against the recorder's death count; this
     is a free, continuous WK-89 check), and `scores`, `raw_kills` and `_stage_deltas` before and after.

---

## 4. Step 0: WK-89 / CD1-06 repro (first; about 4 min)

1. Arena cold boot, then `P1 → InputBot L3` (`cs.players[0].set_provider(InputBot.new(cs.players[0], cs, 3))`),
   `cs.lives_per_player = 3` (read at the next `_begin_stage`), and target 999. Install the recorder. Let the current stage run
   out; the stages that follow are LIVES 3.
2. Run 3 stages. At each STAGE_END, check:
   - **I1:** `round_stats[-1].kills.size()` == the recorder's death count for that stage (COMBAT + SUDDEN_DEATH).
   - **I2:** the count of `kills` with killer ≥ 0 and ≠ victim == Σ `raw_kills` delta.
   - **I3:** Σ `_stage_deltas` == credited − (self-KOs where `score_before` > 0).
3. Also, once per stage, log what the CD's read would have returned: `round_stats[0].kills.size()` and, mid-stage,
   `round_stats.size()` and `_cur_stats.kills.size()`.
4. **Verdict:**
   - I1-I3 hold in 3/3 stages, and `round_stats[0]` ≠ the 3-lives stage: **H1/H2 confirmed, so WK-89 → Won't do** with the
     numbers attached.
   - Any invariant fails: **WK-89 confirmed** (gameplay-programmer). Study A/B still proceed, because they run LIVES 1 and use the
     recorder's own death log as the source of truth.

---

## 5. Study A: the +25 % knockback side effects

### 5.1 Question and pre-registered hypotheses
Does feeding the multiplied impulse to the Lv0 sting/escalation gate and hitstun measurably kill the recovery gamble or
compress pacing, compared with feeding them the pre-multiplier impulse (= the WK-20b candidate)?

| ID | Prediction (written before data) |
|---|---|
| P-A1 | Mechanism: arm A escalates ≈100 % of Lv0 grazes (s ≤ 0.15); arm B ≈0 %. |
| P-A2 | Lv0 graze sting mean ≈ 2 fuel (A) vs 0 (B). Negligible against a 100 tank and a 20/bounce refill. |
| P-A3 | Lv0 hitstun at the 0.55 cap ≥ 90 % in A; in B, Lv0 grazes sit at 0.48-0.53. |
| P-A4 | Lv0 non-edge survival (fuel ≥ 20): A 55-70 %; B no more than +8 pp above A. |
| P-A5 | Graze-primed kills are 5-15 % of credited kills in A. |
| P-A6 | Median stage length differs by < 10 % between arms. |
| **Predicted ruling** | **WK-20b → Won't do** (about 60 % confidence). Velocity kills and velocity is identical across arms. The cap already guarantees a recovery window. Escalation is pulled back by the 8 s heal. |

### 5.2 Design
- **Roster:** 4 bots. Cold boot gives P1 human + bots L2/L3/L4; set P1 → L3, giving **L3, L2, L3, L4**. LIVES 1, target 999.
  Standard profiles.
- **Powerups off:** `Tuning.pu_max_on_field = 0`. The director then skips every beat (`_bubble_count() >= cap`). This is required:
  Counter Shield (1400, not multiplied) and explosions (`apply_impulse_vector`, 1600 at the centre) share the gate and hitstun
  constants, so the arm-B proxy would distort them.
- **Arms, alternating by `stage_index` parity** (odd = A, even = B). Applied at STAGE_INTRO, and on `combat_started` at the latest.
  Alternating balances the arena shuffle-bag and session drift.
  - **Arm A (today):** `Tuning.smash_sting_min_impulse = 1500.0` · `Tuning.hitstun_per_impulse = 0.00025`
  - **Arm B (WK-20b proxy):** `Tuning.smash_sting_min_impulse = 1875.0` · `Tuning.hitstun_per_impulse = 0.0002`
  - Why the proxy is exact at Lv0: the Lv0 impulse = 1.25 × pre, so `1.25·pre ≥ 1875 ⇔ pre ≥ 1500`, and
    `0.15 + 1.25·pre·0.0002 = 0.15 + pre·0.00025`. At Lv1/Lv2, cap-limited hits are unchanged: the minimum is 1320 × 1.66 = 2191,
    which is ≥ 1875 and gives hitstun ≥ 0.588, capped to 0.55.
  - Where the proxy is inexact: slow chain-body hits at Lv≥1 with raw impulse < 1130 (attacker < ~573 px/s). The recorder flags
    any Lv≥1 smash with `post_level == pre_level < 2` and s > 0. If such smashes are > 3 % of Lv≥1 smashes in B, report it.
  - **Change control:** `hitstun_per_impulse` is DO-NOT-TOUCH. Here it is a **runtime-only measurement proxy** for "feed hitstun
    the pre-multiplier impulse". It is restored after every arm-B stage and at session end, and is never persisted. The WK-20b
    build must pass `impulse_pre_mult` into `receive_smash` and **must not** change any constant (D-18, BACKLOG WK-20b).
- **Explosive-prop arenas:** minefield, bumper_mines, press_and_mines, swing_mines, spark_yard, everything_yard and
  pandemonium_prime hold mines/bombs that share the 1500 gate. Flag their stages `explosive_arena`. The **primary analysis
  excludes them**; a secondary run includes them.
- **Sample size:** 40 stages (20 per arm). The floor is **≥ 40 qualifying A4 events per arm**. If either arm is below 40, extend to
  56 stages. At n = 40 the Wilson 95 % CI is about ±15 pp; at 80 it's about ±11 pp. Report CIs on every proportion.
- **Secondary read, no extra time:** compute A4 for **HumanSim victims** in B1 (arm A conditions only). Bot victims recover
  reflexively, so a bot-only survival rate overstates human survival.

### 5.3 Metrics (all computed per arm, primary set = non-explosive stages)

| ID | Metric | Exact definition | Source |
|---|---|---|---|
| A1 | Graze escalation rate | share of smashes with `pre_level` 0 and s ≤ 0.15 where `post_level` = 1 | recorder smashes |
| A2 | Graze fuel drain | mean `sting` for Lv0 smashes, bins s ≤ 0.15 / 0.15-0.2045 / > 0.2045; plus total sting fuel per player-minute | recorder |
| A3 | Hitstun distribution | Lv0 `hitstun` histogram (0.40-0.45-0.50-0.55); median, p10, p90, share at the 0.55 cap; per s-bin | recorder |
| A4 | **Lv0 non-edge survival** (D-18 KPI) | Among smashes with `pre_level` 0, `off_stage` false, `fuel_before` ≥ 20, state COMBAT (SD excluded, since SD seeds Lv2): share with `died_no_rehit_4s` = false | recorder |
| A5 | Graze-primed kills | share of credited kills where the victim's killing smash had `pre_level` ≥ 1 **and** the hit that escalated them from Lv0 that life had s < 0.2045 | recorder chain |
| A6 | Ring-out geometry | Lv0 conversion rate (`died_no_rehit_4s`) by `d_launch` bin (0-400 / 400-800 / 800-1200 / > 1200 px); median `carry_px` for Lv0 centre hits (s ≥ 0.8) vs the median `d_side` at hit time | recorder |
| A7 | Escalation matrix | P(0→1), P(1→2), heal re-arms per hit, by s-bin; share of player-time at Lv ≥ 1 (4 Hz sampler) | recorder |
| A8 | Pacing | median `length_s`; median time-to-first-death per stage; deaths per stage; credited KOs per combat-minute; SD rate | recorder + `round_stats` |
| A9 | One-shot share (DECISIONS 07-19 watch item) | share of credited kills where the killing smash was the victim's **first** smash received that life | recorder |
| A10 | Bot self-KO share | self-KO deaths / all deaths, per bot level (pooled across arms; the reference for Study B) | recorder deaths |

### 5.4 Mechanism checks (run after the first 6 stages; abort and fix the toggle if any fail)
- **A1:** arm A ≥ 95 % and arm B ≤ 5 %.
- **Lv0 hitstun, s ≤ 0.05:** arm A median in [0.54, 0.55]; arm B median in [0.46, 0.50].
- **Snapshot:** every stage's live Tuning snapshot matches its arm.
- **Launch speed:** median Lv0 centre-hit `launch_speed` is equal across arms within ±3 %. Launch is not supposed to move. If it
  does, the proxy is leaking into the sim.

### 5.5 Optional arm C (gate-only), only if WK-20b looks like a GO
Run arm C (`sting 1875`, `hitstun_per 0.00025`) for 12 stages after B2. If C recovers ≥ 75 % of B's A4 gain, WK-20b ships
**gate-only**. It leaves every hitstun read alone, so the semantic change is smaller.

### 5.6 Edge cases (QA handles these as stated)
- **SUDDEN_DEATH** (both players seeded Lv2): exclude it from A1-A5 and A9, and count it in A8's SD rate.
- **Chain hits:** use `attacker` as recorded (the credited launcher). The physical body is irrelevant for credit.
- **Spawn protect / Star / Counter:** with powerups off, a smash on a spawn-protected victim never reaches `smash_landed` with a
  sting. Any such row is a bug report, not data.
- **Victim dies to a hazard after a smash:** it counts as not survived if it's ≤ 4 s and no rehit, whatever the cause. That's the
  gamble the player lost.
- **Restore:** at session end run `Tuning.smash_sting_min_impulse = 1500.0`, `Tuning.hitstun_per_impulse = 0.00025` and
  `Tuning.pu_max_on_field = 2`, then stop the game and re-hash `Tuning.gd`.

---

## 6. Study B: the self-KO rule, measured with human-style drivers

### 6.1 Why a new driver
Bots are rule-blind, so they're perfect for replaying rules, but they can't fall (§2.2). A bot-only batch would say "fine". We
need a driver that self-KOs the way CD1's humans did and the morning audit described (R-07).

### 6.2 HumanSim driver (ephemeral; source in `tools/out/wk/wk20a_humansim.txt`)
HumanSim is a provider object that wraps an inner `InputBot` (for decisions) and is installed with `players[i].set_provider(...)`
during STAGE_INTRO. Contract:
- `poll() -> InputIntent`, evaluated **once per physics frame**. Guard it with `Engine.get_physics_frames()`, because Player also
  polls in `_frozen_preaim`.
- Forward `reset_motion_health()` and `motion_health()` to the inner bot.
- Copy intent fields. Never return the inner bot's reused `InputIntent` instance.
- Set `inner.profile.leader_focus = 0.0` so drivers stay score-blind and the rule replays (§6.5) stay exact.

| Layer | Behaviour (what to emulate) | Newcomer | Regular | Rationale |
|---|---|---|---|---|
| H1 Opening idle | from `combat_started`, neutral intent (no boost, no aim) for U(a, b) s | U(0.5, 1.5) | U(0.15, 0.5) | R-07 / CD1: humans read the legend at BOUNCE; idle P2 was dead about 4 s in |
| H2 Danger notice delay | while `inner._in_danger()` has been continuously true (0.15 s hysteresis) for less than D: keep emitting the **last pre-danger intent** and suppress `super_hold`; after D, pass through the inner recovery intent | D = 0.35 s | D = 0.22 s | Choice reaction under clutter is 0.3-0.5 s, simple reaction about 0.2-0.25 s, plus pad/display latency. Inverts §2.2 points 1, 2 and 6 |
| H3 Slow aim wobble | outside AIM state, rotate the output aim by θ, **re-rolled every 0.35 s** (not per frame) | ±0.35 rad | ±0.15 rad | Low-frequency error is what actually sends people off the map. Inverts §2.2 point 3 |
| H4 Boost release lag | when the inner bot releases boost, keep it held for L s | 0.10 s (≈2.9 fuel) | 0.05 s | Humans over-hold, so tanks run dry and the late-recovery chain starts (FEEL §3.1: 28.6 fuel/s) |
| H5 Reckless super | when an opponent is within 450 px, fuel ≥ 5 and we're not already aiming: Poisson rate λ; on a hit, press super, aim at the opponent's **current** position (no lead, ignore the void), hold U(0.15, 0.40) s, release | λ = 0.20/s | λ = 0.06/s | Inverts the whiff guard (§2.2 point 4), which is the GDD's self-destruct comedy |
| Base | inner InputBot level | L2 | L3 | Newcomers are aggressive but sloppy |

**Calibration (B-cal, discarded; at most 2 rounds of 6 stages).** Anchor to CD1, the only human-ish data we have:
- **Newcomer:** HumanSim self-KO share **25-45 %** (CD1: 33 %); credited KOs per HumanSim per stage **0.35-0.65 ×** the CPU L2's
  (CD1: ≈ 0.47 ×).
- **Regular:** self-KO share **10-20 %**; KO rate **0.8-1.2 ×** CPU L2.
- **Adjustment order:** H2 D ± 0.08 s first, then H5 λ ± 0.05/s. If still off after 2 rounds, proceed with the closest preset
  and report the miss.
- **Honesty note:** calibrating to CD1 and then measuring is deliberate. What Study B adds is a bigger sample (CD1 is one match),
  counterfactual replays of every rule from the same games, a second skill band, and the L1 option.

**Motion check (validate motion, not just outcomes):** capture a 12-frame burst at 0.3 s of one B1 stage
(`tools/out/wk/wk20a_humansim_burst/`) and **look at it**. HumanSim goats must read as flustered players: moving, overshooting,
recovering late. They must not be frozen, jittering or orbiting. Their inner `motion_health` stuck/blocked numbers must stay
within 1.5 × the Study A bot baseline. If not, fix the driver before B1.

### 6.3 Batches
- **Setup:** `GameConfig.match_config` gets `human_count = 3`, `bot_count = 1`, `bot_difficulty = 0` (MIX), `kills_to_win = 999`,
  `lives_per_player = 1`, then `get_tree().reload_current_scene()`. Verify `players.size() == 4`, `players[3].provider.level == 2`
  (MIX → L2), and that P1-P3 are in group `human`. Install HumanSim on 0-2 and the recorder before the first BOUNCE (otherwise
  discard stage 1). **Powerups stay at default** (no proxy toggles here, so there's no confound). Record whether WK-86 is in the
  build.
- **B1:** 3 × HumanSim-newcomer + CPU (MIX → L2), **30 stages** (extend to 40 if time allows).
- **B3:** the same as B1, but `players[3].set_provider(InputBot.new(players[3], cs, 1))`, giving CPU **L1**, **16 stages**.
- **B2:** 3 × HumanSim-regular + CPU L2, **16 stages**.
- **Bot reference:** A10 from Study A (no extra time).

### 6.4 Rules evaluated (offline replay; no extra game time except Rc′)

| Rule | Definition | Status |
|---|---|---|
| **R0** today | credited +1; self-KO −1, floored at 0 | baseline |
| **Ra** | self-KO costs 0 by default; "SELF-KO −1" becomes a RULES toggle | CD option (a) |
| Rb | "no penalty until scored once" | **≡ R0** (§2.3). Reported as identical; not replayed |
| **Rb′** | self-KO −1 **only for the strict current leader** | variant of (b): the leader plays careful (catch-up flavour) |
| Rc | "2+ humans → MIX = L1-L2" | **≡ today** for 1 CPU (§2.3) |
| **Rc′** | 2+ humans on MIX → every CPU = **L1** | measured by B3 (combined with R0 / Ra / Rd) |
| **Rd** | opening grace: self-KO with `round_clock` < 3.0 s costs 0; otherwise −1 | targets the R-07 / CD1 stage-2 opening collapse |
| *Genre: Smash* | time mode: SD = −1 by default; Melee and Smash 4 let the rule menu set 0 / −1 / −2. Stock mode: losing the stock is the only cost | supports Ra (an adjustable penalty, and with stocks or LIVES the elimination is the cost) |
| *Genre: TowerFall* | Versus: a suicide can cost a point (the "Steak in the Mouth" award implies it; **not verified against official rules**) | supports R0 for a competitive crowd |
| *Genre: Duck Game* | no kill scoring; last duck standing scores; a self-death just forfeits the round | excluded. It violates the owner's KILLS 10 kill-race; its spirit (death = lose the round, nothing more) equals Ra at LIVES 1 |

### 6.5 Counterfactual replay (why one batch covers every scoring rule)
Drivers and CPUs are score-blind (leader_focus 0; the finisher keys on alive count, not score). So **the stage kill logs don't
depend on the scoring rule**, and each rule is a pure function of the logs.
- Write a stdlib Python script, `tools/out/wk/wk20a_replay.py`.
- Bootstrap **10,000 matches per rule per batch**: draw stage logs with replacement, apply the rule death by death in time order
  (the floor depends on the running score), and end the match **at the winning kill** (later events in that stage are dropped,
  as `_enter_match_end` does). Cap matches at 60 stages; a match that hits the cap counts as "no winner".
- Limitation to state in the report: real humans may take more risks once a rule stops punishing them. The drivers can't show
  this. With LIVES 1 the elimination still costs the stage, which caps that risk.

### 6.6 Metrics

| ID | Metric | Definition |
|---|---|---|
| B-M1 | Self-KO share per driver type | self-KO deaths / deaths for HumanSim-newcomer, HumanSim-regular, CPU L2, CPU L1, and bots L2/L3/L4 (A10), with Wilson CIs |
| B-M2 | Self-KO cause mix (humans) | opening (< 3 s) / whiff (`dt_last_own_super` ≤ 1.5 s, no own smash) / dry tank (fuel < 5 at death) / other |
| B-M3 | KO → score gap | per human per match: credited KOs − final score (mean, p90) |
| B-M4 | Inversion rate | share of simulated matches with ≥ 1 pair where credited_i > credited_j but score_i < score_j; also the subset where the **CPU outranks a human with ≥ the CPU's credited KOs** |
| B-M5 | CPU match-win rate | per rule (fair share is 25 %) |
| B-M6 | Zero-pinned stages | per human per match: stages after stage 3 that end with score 0 (CD1: two humans spent about 8 stages at 0) |
| B-M7 | Match length | mean stages per match per rule (feeds the WK-21/41 downtime budget) |
| B-M8 | CPU participation (B3) | CPU credited KOs per stage and deaths per stage. L1 must stay a participant, not a punching bag |

### 6.7 Pre-registered prediction (Study B)
- **P-B1:** bot self-KO share is 10-25 % (not 0; CD1's 0/6 is a small sample). HumanSim-newcomer lands at 25-45 % (calibrated),
  so humans self-KO about 2-3 × as often as bots.
- **P-B2:** in B1, CPU match-win is **R0 50-70 %**, **Ra 40-55 %** and Rd in between; Rb′ is about the same as Ra.
- **P-B3:** inversions under R0 occur in ≥ 30 % of matches. Under Ra they are about 0 **by construction** (score = credited KOs).
- **P-B4:** CD1's CPU out-killed the best human on *credited* KOs (10 vs 7), so **Ra alone will not stop the CPU winning
  newcomer nights**. B3 (L1) brings the CPU's win rate to 10-25 %.
- **Predicted ruling: Ra** (self-KO costs 0; "SELF-KO −1" as a RULES toggle, default OFF) **plus Rc′** (MIX → L1 when there are
  2+ humans). Confidence: Ra about 75 %, Rc′ needed about 65 %.
- **Why Ra:** at LIVES 1 a self-fall already costs the rest of the stage (Duck Game's cost, Smash's stock logic), so −1 is a
  second penalty. It's invisible (a readability problem, pillar 5), and it lands on the learners (pillars 1 and 4). The
  competitive group keeps the toggle, as Smash does.

---

## 7. Decision rules (pre-registered; the designer applies these mechanically, then writes DECISIONS)

### 7.1 Study A → WK-20b
Evaluate in order. The first row that matches wins. "A4_A" is arm A's survival point estimate; "n" is qualifying events per arm.

| # | Condition | Ruling |
|---|---|---|
| 0 | Mechanism checks (§5.4) failed, or n < 40 in either arm after the extension | **Inconclusive.** Keep today's behaviour (= the owner ruling). WK-20b → Won't do *for now*; re-measure inside WK-57 |
| 1 | B makes pacing worse: B median stage > 22 s, **or** B's SD rate > 25 %, **or** B's credited KOs per minute < 0.75 × A | **WK-20b → Won't do** (the fix would stall rounds). Log it as a watch item |
| 2 | A4_A < 50 % **and** A4_B − A4_A ≥ 10 pp | **WK-20b GO**, the exact gate as in BACKLOG: sting + escalation + hitstun on the pre-multiplier impulse at Lv0. If arm C ran and recovered ≥ 75 % of the gain, scope it **gate-only** |
| 3 | A4_A ≥ 50 % **and** A5_A ≥ 25 % **and** A8 median stage (A) < 10 s **and** B's median is ≥ 15 % longer | **WK-20b GO, gate-only** (grazes are priming kills and rounds are too short; hitstun isn't the culprit) |
| 4 | otherwise | **WK-20b → Won't do.** The side effects are real in the formula but small in play. DECISIONS records the measured A1-A9 |
| W | Any row, if A9 ≥ 60 % **and** the median time-to-first-death < 4 s | additionally flag the 2026-07-19 watch item to the Director ("rounds one-shotting"). The only knob is the owner's array, so this is a re-ruling question for the owner. Never hitstun, never a feed change beyond WK-20b |

### 7.2 Study B → WK-20c
Use B1 (newcomer) as the deciding batch. Use B2 (regular) only as a tie-breaker and sanity check.

| # | Condition | Ruling |
|---|---|---|
| 1 | Under R0: inversions ≤ 10 % of matches **and** mean KO→score gap ≤ 1.0 **and** CPU-win(R0) − CPU-win(Ra) ≤ 5 pp | **Keep R0. WK-20c → Won't do** (the −1 is cheap; it keeps its deterrent role) |
| 2 | Not row 1, **and** opening self-KOs (B-M2) ≥ 60 % of human self-KOs **and** inversions under Rd ≤ 10 % | **Adopt Rd** (opening grace 3.0 s; −1 stays mid-stage). WK-25's "−1 OOPS" pop stays, but not inside the grace window |
| 3 | Not row 1 or 2 | **Adopt Ra:** self-KO 0 by default, RULES toggle "SELF-KO −1" (OFF/ON, persisted per mode by WK-07). WK-25 drops "−1 OOPS" by default (it shows only when the toggle is ON) |
| 4 | After rows 1-3: CPU-win (B1, chosen rule) > 30 % **and** B3 (L1, same rule) ≤ 30 % **and** B-M8 L1 credited KOs ≥ 0.25 per stage | **Also adopt Rc′:** 2+ humans on MIX → every CPU = L1. Explicit CPU SKILL 1-5 is untouched |
| 5 | After row 4: CPU-win > 30 % even at L1, **or** L1 fails B-M8 | No CPU-mix change. **File a new item** (game-designer spec): "bot human-latency layer for L1-L2", meaning H2/H3/H5-style latency inside InputBot so low tiers fall comically, as GDD §8 and BotProfile promise. It's outside WK-20 |
| — | Rb′ (leader-only) | **Report only.** Not eligible this pass: it adds invisible, situational semantics (a readability cost) unless rows 2 and 3 both fail |

### 7.3 Interactions and routing
- The two rulings are independent. WK-20b changes lethality; WK-20c changes accounting and CPU mix. Write two DECISIONS
  entries, each with a reopen condition:
  - **Knockback:** reopen on a failed lethality-pacing QA or an owner re-ruling.
  - **Self-KO:** reopen if CD2 or later shows reckless self-destruct spam under Ra (more than 1 self-KO per human per 2 stages
    at LIVES 1).
- WK-25 waits for the self-KO ruling. WK-32a waits for the WK-20b ruling (lethality baseline).
- The §2.2 bot-fidelity finding is filed whatever row 5 says (it's a P2 bot-fun gap), and it is linked to WK-76.

---

## 8. Deliverables (QA)
- `tools/out/wk/WK-20a_measure.json`:
  `{meta:{head, dirty, tuning_diff_sha_before, tuning_diff_sha_after, date, minutes_game_time},`
  `repro:{stages:[{I1,I2,I3, round_stats0_kills, verdict}]},`
  `studyA:{arms:{A:{A1..A10 + CIs + n}, B:{...}, C?:{...}}, mechanism_checks, proxy_inexact_share, secondary_humansim_A4},`
  `studyB:{calibration:{presets_final, rounds}, batches:{B1,B2,B3:{B-M1,B-M2,B-M6,B-M8}}, rules:{R0,Ra,Rb_equiv_R0:true,Rb_prime,Rd, Rc_prime_from_B3}:{B-M3,B-M4,B-M5,B-M7}},`
  `predictions_hit:{P-A1..P-A6, P-B1..P-B4}}`
- Raw logs: `tools/out/wk/wk20a_raw_{repro,A,Bcal,B1,B2,B3,C}.json`. Driver, recorder and replay sources go in `.txt`/`.py` under
  `tools/out/wk/`.
- **Contact sheet of 3 recoveries:** `tools/out/wk/wk20a_recover_sheet.png`, from segment R (arm A conditions, 4 bots,
  excluded from stats). The recorder snaps half-res frames at +0, 0.25, 0.5, 0.75, 1.0 and 1.5 s after each qualifying Lv0
  non-edge smash (budget 8 sequences). Pick 3 that survived and **look at them**: the scared-then-saved beat must be visible on
  screen.
- HumanSim motion burst `tools/out/wk/wk20a_humansim_burst/` with a one-line motion verdict.

## 9. Time budget and stop rules
- Plan: Step 0 4 min · A 14 min · B-cal 4 · B1 10 · R 3 · B3 5 · B2 5 · C 4. That's about 49 min of game time, plus about 6 min of
  relaunch/setup overhead.
- Extensions, if needed, in this order: A to 56 stages (+6), then B1 to 40 stages (+3). **Hard stop at 90 min of game time.**
- If the hard stop is hit before B1 completes, report Study B as inconclusive; the Study B ruling defaults to "measure again
  in CD2". Study A still rules.
- A stage roughly equals 15 s of combat plus about 5 s of interstitial with the scoreboard skip. Measured median in CD1: 15 s.

## 10. Success criteria for this protocol (QA-verifiable)
1. `WK-20a_measure.json` exists, and every metric ID in §5.3 and §6.6 is populated with n and a CI, or carries an explicit
   "n/a + reason".
2. The §5.4 mechanism checks pass, and their numbers are in the JSON.
3. The `Tuning.gd` diff hash is identical before and after. Nothing was persisted.
4. The repro verdict (WK-89 confirmed / Won't do) is stated with I1-I3 for 3 stages.
5. The HumanSim calibration lands inside the §6.2 bands, or the miss is reported. A motion burst was captured and viewed.
6. The recovery contact sheet shows 3 survived Lv0 non-edge recoveries.
7. Total game time ≤ 90 min, recorded in `meta`.
8. The game-designer can apply the §7 tables without asking for any extra number. If they can't, the protocol failed, not QA.

## Sources (genre references)
- SmashWiki, Self-destruct (SD = −1 by default in Time; 0/−1/−2 configurable in Melee/Smash 4): https://www.ssbwiki.com/SD
- SmashWiki, Time (falls and SDs cost a point): https://ssbwiki.com/Time
- SmashWiki, KO (a fall with no last attacker counts as an SD): https://www.ssbwiki.com/KO
- TowerFall Ascension Versus awards ("Steak in the Mouth": a winning point lost to a suicide; secondary source, unverified):
  https://www.gamerevolution.com/?p=65353
- Duck Game scoring (last duck standing): `docs/reference/GAME_DESIGN.md` L495.
