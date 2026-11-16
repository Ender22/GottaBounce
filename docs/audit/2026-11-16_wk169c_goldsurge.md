# WK-169c GOLD SURGE re-check: lane TG (A1 vs A1'), 2026-11-16, QA

**Plan (pre-registered):** `docs/specs/wk169c_showdown_polish_2026-11-16.md` §1.5 (rig, metrics), §1.6 (predictions), §1.7 (decision table).
The few definitions the spec leaves open were frozen in `tools/out/wk/wk169c_recheck/PREREG.json` after a 2-stage smoke test and before any
batch data existed. · **Data:** `tools/out/wk/WK-169c_goldsurge_summary.json` (every number below) · **Raw + harness + analyzer:**
`tools/out/wk/wk169c_recheck/` (`raw_b8c9d85/T.{A1,A1p}.<seed>.{json,log}`, HumanSim5g / WK169bRec / WK169bBoot copies md5-identical to
`wk169b2_batch/`, `run_169c_recheck.sh`, `wk169c_recheck_stats.py` extending `wk169b2_stats.py`). Arm label `A1p` = A1'.

## Verdict: DON'T SHIP GOLD SURGE (decision row R2). `showdown_drop_arm_s` stays 0.0

- **R2 fires on both of its prongs:**
  - PB was not halved: ratio 0.56 (bar ≤ 0.5), one-sided Fisher p 0.11 (bar < 0.05).
  - H did not move: Δ +0.2 pp (bar ≤ −6 pp).
- **R1 would have failed anyway on its cost bar:** P(PD > 8 s) rose by **+11.7 pp** (bar ≤ +6). Even a PB / H pass would have landed in R3.
- **G9 stays a FLAG.** A1 H = **90.3 %** (56 / 62, Wilson90 82-95 %), the third batch in a row above 85 % on the point estimate. CD6 Q3
  stays its judge. Per R2: if CD6 says "unfair", the §8 ladder resumes (`showdown_drop_dur` 6 → 4, with its own lane-T re-check), then
  KNOCKED LOOSE.
- **What this means for the game:** GOLD SURGE does what it was built to do. The loser now strikes first in 44 % of races, not 18 %. But
  the gold still decides the duel, just a tank later. The tail gets longer, a second golden drop arrives, and whoever holds that one wins.
  Holder-wins can't drop while the tank is still a near-certain finisher.

## Build and rig (as §1.5)

| | |
|---|---|
| Build | `git archive` of **HEAD b8c9d85** (pinned at the start). It includes 169c **83d92d9** (`showdown_drop_arm_s` default 0.0) and WK-183 (sports-only, inert in a Brawl lane). **WK-188 is NOT in it:** there's no WK-188 commit at b8c9d85, and `refund_gates_on = false` in every run's meta. The fuel economy is the pre-WK-188 one in both arms |
| Treatment | Scratchpad copy with `tools/out` excluded, `.godot` imports via `copy_imports.py`, the McpInteractionServer autoload removed, `--headless --fixed-fps 120 --gb-port=0`, APPDATA isolated per lane. Scratch copy and APPDATA deleted afterwards |
| Common args | `flow=loop force2=3.0 stages=15 wall=900 tune_circuit_session_deck=0 tune_showdown_delay=0.5`, env `GB_WK169=a1` (the boot log confirms `showdown_delay 0.5`, deck off) |
| Arms | **A1** = common. **A1'** = common + `tune_showdown_drop_arm_s=1.0` (`arm_s` 1.0 on every A1' tank record, 0.0 on every A1 one) |
| Seeds and order | 501-510, both arms. Lane 1: 501-505, lane 2: 506-510. Seed-major, arms interleaved, each job a fresh process, timeout 1800 s, never more than 2 Godot processes |
| Health | 20 / 20 jobs complete, 300 stages, **0 SCRIPT ERRORs, 0 stalls, 0 censors**, 0 retries. Wall 07:25-07:43 (17 min). 3,568 s of game time |

## Per-arm results vs the pre-registered bars

Population: forced stages. A1: 140 forced, 10 natural (6.7 %). A1': 136 forced, 14 natural (9.3 %). 0 `pre2`, 0 `forced_sd_revive`.

| ID | Metric | **A1** (arm 0.0) | **A1'** (arm 1.0) | Δ / ratio | R-P1 (A1) | R-P2 (A1') | R1 bar |
|---|---|---|---|---|---|---|---|
| **H** | Holder (last collector) wins | **56/62 = 90.3 %** [82-95] | **57/63 = 90.5 %** [83-95] | **+0.2 pp** (boot CI90 −7.8..+8.2) | 84-93 ✓ | 74-85 ✗ | Δ ≤ −6 pp **✗** |
| **F** | First grabber wins | 54/62 = 87.1 % | 51/63 = 81.0 % | −6.2 pp | 78-90 ✓ | | (info) |
| **PB** | Non-holder dead ≤ 2.0 s after the first grab | **14/62 = 22.6 %** | **8/63 = 12.7 %** | **ratio 0.56, Fisher p 0.112** (boot diff CI90 −19.5..−0.3 pp) | 15-30 ✓ | 4-12 ✗ (12.7), ratio ≤ 0.5 ✗ | ratio ≤ 0.5 **and** p < 0.05 **✗** |
| | ... within 1.0 s | 9 | 5 | | | | |
| **PD** | Post-drop tail: median / p90 | **1.91 / 8.24 s** (n 108) | **3.66 / 12.96 s** (n 101) | median **+1.75 s** | 2.5-4.5 ✗ | +0.5..+1.5 ✗ | |
| | P(PD > 8 s) | 12/108 = **11.1 %** | 23/101 = **22.8 %** | **+11.7 pp** | 6-16 ✓ | 0..+6 ✗ | ≤ +6 pp **✗** |
| **FS** | First golden super, s after `t_on`: median (all tanks) | **1.04** (49 tanks with a super; 21 under 1 s, min 0.38) | **2.40** (58; **min 1.005**) | +1.35 s | 0.2-0.8 ✗ | ≥ 1.0 s on 100 % ✓ (58/58) | (knob check ✓) |
| **LS** | Loser smashes the holder before the holder's first super | 11/62 = **17.7 %** | 28/63 = **44.4 %** | **+26.7 pp** | 3-10 ✗ | 10-25 ✗ (over) | |
| **SK** | Self-KO share of tail-enders | 20/140 = 14.3 % | 8/136 = 5.9 % | **−8.4 pp** | | −3..+3 ✗ (better) | ≤ +5 pp ✓ |
| **C** | Collected / (collected + popped) | 68/70 = **97.1 %** | 80/85 = **94.1 %** | −3.0 pp | ≥ 95 ✓ | ±3 ✗ (by 0.02) | ≥ 90 % both ✓ |
| R-P3 | Natural-excluded ≤ 12 %; errors = censors = 0 | 6.7 %, 0, 0 | 9.3 %, 0, 0 | | ✓ | ✓ | R4 not triggered |

**Decision table:**

| Row | Fires? | Why |
|---|---|---|
| R4 | no | C ≥ 90 % in both arms, natural-excluded ≤ 20 % in both, 0 errors / censors / stalls |
| R1 | **no** | PB not halved (0.56, p 0.11), H Δ +0.2 pp, P(PD > 8) Δ +11.7 pp. Three of its five conditions fail |
| R3 | no | Needs PB and H to improve first. PB improved but not to the bar, and H didn't improve at all. (The R3 cost condition, P(PD > 8) Δ > +6, *is* met) |
| **R2** | **YES** | "PB not halved, **or** H Δ > −6 pp": both are true |

## Why H didn't move: the mechanism (info, not a gate)

- **The knob bites exactly as built.**
  - With 1.0 s, no A1' tank fired a super before 1.005 s (58 / 58).
  - The first golden super moved from a median 1.04 s to 2.40 s after the grab. The delay is 1.35 s, not just the 1.0 s lock, because
    HumanSim re-aims after the locked press.
  - The race loser got the first strike far more often: LS went from 18 % to 44 %.
- **That strike matters to the first grabber.**
  - In A1', the first grabber won only **16 / 28** races where the loser struck first, against **35 / 35** where they didn't.
  - First-grabber-wins (F) fell 6 pp.
- **But the duel survives into a second tank, which decides it.**
  - Stages with two or more golden tanks went from **5 to 15**. The second tank went to the other fighter in 7 of 15.
  - G9's "holder = last collector" counts the second holder, and that goat wins about as often as the first one used to. So H stays at 90 %.
  - The same thing makes the tail longer: P(PD > 8 s) doubles, from 11 % to 23 %.
- **The spec's model of the threat was half right.**
  - The point-blank opening is real. PB fell 44 %, and the loser does get to fight back.
  - But a full-fuel, super-every-second holder still finishes the duel once armed, whoever ends up holding it.
  - This supports §1.1 conclusion 2 (the holder leaves the tank with full fuel) over the "opening" theory as the source of the 90 %.
- **Self-KO enders fell** from 14.3 % to 5.9 %. That's a good direction, but it's outside the R-P2 band and not significant at this n
  (most of those stages had no pickup). It's noted, not credited.

## Sample size: below plan

- **Planned vs actual:** only **62 / 63 forced stages per arm got a golden pickup**, 45 % instead of the 75-85 % (about 115 per arm) that §1.5
  planned.
- **Why the drops went unused:**
  - The duel often ended before or right after the drop went live: 47 / 43 drops were still live at stage end, and 19 / 15 never went live.
  - The A1 forced-tail T2c median was 2.4 s.
- **So PB is underpowered:**
  - Its observed 9.9 pp drop is about 1.5 SE.
  - The bootstrap diff CI90 (−19.5 to −0.3 pp) just excludes 0, but the pre-registered Fisher test doesn't pass.
- **This doesn't change the ruling:**
  - H's point estimate is +0.2 pp, nowhere near −6 pp.
  - The P(PD > 8 s) cost alone would block R1.
  - A bigger batch would not flip this to R1.

## Motion health and telemetry

- **CPU motion health** per stage, all 150 stages in each arm. The lane's only CPU (seat 3) is force-removed at 3.0 s, so this covers just the
  opening:

  | Arm | stuck_episodes | stuck_secs | underside_bounces | blocked_ascent | detours |
  |---|---|---|---|---|---|
  | A1 | 0.25 | 0.02 | 0.19 | 0.06 | 7.5 |
  | A1' | 0.23 | 0.02 | 0.15 | 0.06 | 8.9 |

  No pathology, and no arm difference. The duel itself is two HumanSim5g drivers: no bot motion is under test here.
- **Credit hard zeros:** 0 ghost-credited KOs and 0 KM-4 in both arms.
- **Fairness:** pickups split A1 35 / 33 and A1' 44 / 36 (seat 0 / seat 1). Median time to collect 0.72 s and 0.66 s.
- **Telemetry cross-checks:**
  - The new `first_collector` field matches the first collected drop in 0 / 125 mismatches.
  - The kill-record `t_since_grab` differs from the analyzer's first-grab clock on 3 / 8 non-holder deaths. All of them are expected: the
    runtime field counts from the *latest* collect, and those deaths came after a second tank.
- **No WK-93 recording** was made: one headless batch slot only, and the knob doesn't ship. If GOLD SURGE is ever revived (for example at
  0.6 s), its §1.4 feedback and a before / after recording are required first.

## Prediction scorecard (§1.6)

- **R-P1 (A1):**
  - Hits: H, F, PB, P(PD > 8), C.
  - Misses: FS median 1.04 s (predicted 0.2-0.8: HumanSim doesn't fire the instant it grabs), PD median 1.9 s (predicted 2.5-4.5: shorter
    than modelled), LS 17.7 % (predicted 3-10).
- **R-P2 (A1'):**
  - Only the FS knob check hit.
  - H, PB, PB ratio, LS (overshot), PD median Δ, P(PD > 8) Δ, SK Δ (better than the band) and C Δ (−3.02 pp, just outside ±3) all missed.
- **R-P3:** hit.
- **Forecast:** R2 (30 %) is what happened.

## Recommendation (for the game-designer; QA doesn't move knobs)

- **Keep `showdown_drop_arm_s` at 0.0.** No Tuning flip and no §1.4 feedback build.
- **Pass G9 to CD6 Q3 as the spec says.**
- **The data suggests the next lever should target post-arm dominance, not the opening.**
  - Examples: the full-fuel exit, a super cadence above 1.0 s, or KNOCKED LOOSE.
  - §1.7 R2 orders the ladder as dur 6 → 4 first. This batch gives a reason to doubt that step too: tails that run into a second tank are
    already decided by "who holds gold", and a shorter tank wouldn't change who holds it.
- **R3's "try `arm_s` 0.6" doesn't apply.** R3 didn't fire, and a smaller arm would cut PB less while keeping the same second-tank dynamic.
