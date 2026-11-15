# WK-175a: Gate the walls, not the floors (refund-gates retune) (2026-11-16)

**Owner:** game-designer (this ruling) · **Builds it:** gameplay-programmer · **Verifies:** qa-playtester (one headless batch +
rendered checks) + creative-director (feel check) · **Backlog:** WK-175 [P3][M], split item 175a (this spec). The build is S
once this ruling stands.
**Inputs read:** VISION · GAME_DESIGN (Pillar 2, §4.3) · FEEL_REFERENCE §3.1 and §3.4 · `docs/audit/2026-11-16_wk135_p3_ab.md`
(+ `tools/out/wk/wk135_p3_ab/` harness and raw) · `tools/out/wk/wk135_p3/p135_A.json` (mechanism probes) · specs
`wk128_fuel_exploits_2026-11-14.md` (§2.2, §4.2 F1-F7, §10) and `wk135_bumper_min_bounce_2026-11-15.md` (§4.2 C1-C6, §10) ·
DECISIONS 2026-11-15 WK-128 bill-only, 2026-11-16 WK-135 phase-3 ruling · BACKLOG WK-167 (bots spend last fuel, ON) ·
`Tuning.gd` (WK-128 / WK-135 / WK-167 blocks, `gate_*` helpers) · `Player.gd` (`_on_bounced`, `_wk128_contact_pays`,
`_wk128_track_faces`, `refund_rearm_pending`) · `InputBot.gd` (`poll` BR-128 reflex, `_decide` refuel dive, BR-135a) ·
`levels/bumper_gauntlet.json`, `levels/meadow_carousel.json`.
**Numbers:** pen-and-paper unless they cite the audit. g = 1600, drain 28.57 fuel/s, cruise cap 800 (Ziggy 896), refunds 20,
natural trampoline income 20 / 1.16 s = 17.2 fuel/s, `BODY_RADIUS` 44. No game was run for this spec.

---

## 0. Ruling (summary)

1. **The exploit is the wall, so gate only the walls.** FLOOR-class faces (tier floors, bumper tops, round cores, moving decks)
   **always pay, exactly as today.** WALL-class faces (tier sides and bumper sides) pay **once**, then pay again only after you
   have flown **400 px** away from that face. There is no speed gate and no time valve on walls. Ceilings still pay nothing.
   This is gate set **WR**, the ship candidate.
2. **Why not retune the floor gate (re-arm frac 0.9 → 0.75 / 0.6)?** The audit says the floor gate is what starved the bots,
   and a lower fraction doesn't touch why:
   - About 65 % of the lost refunds were on floors: tier floor 24.8 → 20.6, bumper floor 15.9 → 10.1 per bot air-minute.
   - Bots dribble about once per bot-stage in **both** arms (`dribble` 1.04 vs 1.08). Their excursions are under 0.2 of their
     launch height, so any fraction ≥ 0.25 still blocks them.
   - Honest low-altitude fighting (bounce, then dive back at a target) is blocked by any fraction too.
   - Moving 0.9 → 0.75 only frees bounces that reach 75-90 % of their apex, which is a thin slice.
   - The fix is scope (which faces get gated), not fraction.
3. **The carousel deck fix and the valve finding go away under WR by construction.** A deck is floor-class, so it always pays.
   The valve has nothing left to act on.
4. **No bot brain change is needed for WR.** Floors pay as today, and bots never refuel off walls (flat dives aim down,
   radial dives skip wall-class faces through BR-135a), so BR-128 goes inert. A dribble brain (BR-175) is sketched only for a
   possible future floor gate (§8).
5. **The 400 px number is derived, not picked.** A goat ping-ponging between two facing walls at cruise earns at most
   20 × v / d. Keeping that at or below natural bouncing for every profile needs
   d ≥ 20 × 896 / (17.2 + 28.6) = **391 px**, and 400 is the next round value (new invariant #18).
6. **One batch, four gate sets.** OFF / **WR** / WS (the WK-128 wall rules, floors free) / FULL (WK-135 phase 3 + deck fix,
   re-run on the WK-167 HEAD), plus a repeat of OFF to measure noise. WR ships only if it passes every bar in §9. WS and FULL
   are there to split the cost between the speed gate and the floor gate. Neither ships from this item.

---

## 1. Player fantasy and pillar check

**Fantasy:** *"Every bounce fills my tank. A wall is a backboard: bank off it and it pays me, but leaning on it gets me
nothing."* The floor loop (bounce = fuel) stays exactly as players know it today. The only thing that dies is the hover:
holding FLY into a wall with a full tank, beside a goal mouth or a ledge, forever.

**Player-facing rule (COUCH_CONVENTIONS / tutorial copy):** *"Bounces refuel you. A wall refuels you once. Fly away from it to
get it back."*

| Pillar | Effect |
|---|---|
| **P2 Constant motion / no camping** | **Fixed where it matters.** The wall hover is the only mid-air, fixed-position, infinite-fuel camp in the game. Today: tier side +48 fuel/s, bumper wall pinned at ~98 (audit probe A6 OFF). Under WR it becomes one +20, then −28.6/s. |
| **P1 Low floor** | Untouched. New players earn fuel only from floors, and floors are byte-for-byte today's rules. |
| **P1 High ceiling** | Preserved: wall ricochets still pay once per face, so pinball chains across different faces still feed you (Bumper Gauntlet's design intent). |
| **P3 Physics comedy** | Cruise ricochets keep their refund (WS would remove it). Launched-body caroms and the wall-return shot keep theirs (F3 plus first contact). |
| **P5 Readable chaos** | No physics change. "Walls refuel once" is learnable from the gauge. The paying-contact "ding" (WK-128 §7.5, still unbuilt) would make it obvious. Routed, not blocking. |

**Residual I accept (stated, not hidden):** the **floor dribble** (hold FLY down into a floor, about 3-4 contacts/s, ~+36 fuel/s
net, from the audit's A8 contact rate with every contact paying) stays as it is today. Why I accept it:
- It happens at floor level, in constant visible bouncing, at the bottom of the arena. That's the most exposed spot a goat can
  be (a free super target), not a hover.
- No CD pass (CD1-CD5) has flagged it.
- Gating it is exactly what starved the bots.

It is filed as WK-175b (§8), to be pulled only if a CD pass or human session flags floor-refuelling as degenerate.

---

## 2. Why the WK-135 phase-3 gates failed (diagnosis this ruling rests on)

1. **The floor gate is the main brawl cost.** Of ~15.5 refunds/bot air-minute lost, walls account for ~5.5 (bumper wall 6.0 → 1.5,
   tier wall 3.1 → 2.1). Floors account for ~10 (the valve gave back 3.3).
   - The re-arm rule needs **0.9 × the launch height including the ×1.4 supercharge**: ~476 px on a trampoline bounce with boost
     held, and ~850 px on a spring.
   - Bots hold boost a lot, so almost any honest re-contact during low-altitude fighting is blocked (`refunds_blocked_rearm`
     13.8 vs `_speed` 2.9 per bot-minute).
2. **The bots' fuel economy runs on floor contacts that aren't natural bounces.** `dribble_episodes` was about 4 per stage in
   **both** arms, so bots dribble with gates OFF too. Gates OFF pays those contacts, and gates ON stops the pay. BR-128 only
   guards the refuel dive, but the dribbles come from hunt and plan paths near floors.
3. **In bumper arenas the WALL side is also expensive.** Wall refunds there went 15.66 → 5.30 per bot air-minute, about 80 % of the
   arena's income drop. Most of that is F2: cruise post caroms during recoveries. Bumper Gauntlet went from 1 of 33 to 13 of 35
   self-KOs. WR drops F2 for this reason; the WS arm measures what it costs.
4. **WK-167 changed the baseline.** 56 of 106 bot self-KOs used to die holding ~3.9 fuel, and that is now spent. The old OFF
   numbers can't be reused, so every arm is re-run on HEAD.

---

## 3. Options considered

| Option | Verdict | Why |
|---|---|---|
| Re-arm frac 0.9 → 0.75 or 0.6, all faces | REJECT | Doesn't free dribbles or low-altitude re-contacts (§0.2). WK-128 §10 itself put 0.75 at "dribble income ~25/s", a cosmetic change |
| BR-128 extended to every bot path (the dribble breaker) | DEFER (BR-175, §8) | Only needed if floors are gated. It changes how bots hunt near floors, which is a bigger behaviour change than this P3 item deserves |
| Deck-only fix (drop the 60 px floor on tier-less decks) | SUBSUMED | Under WR decks are floor-class and always pay. Kept in the FULL arm so the fix is still measured |
| **Gates on WALL-class faces only, floors always pay (WR)** | **CHOSEN** | Kills the hover farm. Leaves the floor loop exactly as today. Nothing is left that can strand a goat |
| WK-128 wall rules exactly (F1 200 + F2 900), floors free (WS) | ARM, not candidate | It also kills cruise-ricochet income, the bumper-arena cost in §2.3. Measured to split the cost |
| Per-player wall pay cooldown (Alt B) | REJECT | A time gate leaves a 20/T pump. WK-128 and WK-135 rejected it for sports (rewards the goal-wall keeper) |
| Valve on walls (WK-135 C4) | REMOVE for WR | Liveness is a floor problem: gravity always slides you off a wall. On walls the valve was an income source: a two-face zigzag valve pays ~26.7/s against a 28.6 drain, which made n2_wall_climb almost free again |
| Gate the floor dribble now | DEFER (WK-175b) | §1 residual. Unflagged, exposed, today's behaviour. Gating it is the thing that failed |

---

## 4. The change

### 4.1 Rules (gate set WR = `wk175_gate_set` 1)

- **G1 Face class:**
  - Every non-stunned, non-underside contact is classed by the local gravity at the contact, `up = −g_dir`. This is
    WK-135 C1, now applied to **tier faces as well as bumpers**:
    - `n·up > bumper_floor_dot` (0.5) is **FLOOR**;
    - otherwise it is **WALL**. Ceilings never reach the gate (existing underside rule).
  - Round colliders are always FLOOR.
  - The class is decided **per contact**. In a radial well, one face key can be FLOOR at one end and WALL at the other.
- **G2 FLOOR faces always pay.** They don't read, write or re-base arm state, so they behave exactly like gates OFF. That covers
  tier floors, bumper tops, round cores and tier-less moving decks.
- **G3 WALL faces pay once per departure.** After a wall face pays, it pays again only when your body centre has moved at least
  `E_wall` from the paying position, measured along the face's outward normal (F1 machinery, world space, the maximum reached
  counts):
  - **bumper walls:** `E_wall = wk175_wall_rearm_px` (400);
  - **tier walls:** `E_wall = max(wk175_wall_rearm_px, refund_rearm_frac × h_launch)`. The second term only matters for
    supercharged spring sides.
  - **A blocked wall contact re-bases** the paying position to the current position (E is re-computed from this contact). So
    a hugger has to leave 400 px from the **latest** touch, and creeping away 100 px per touch never re-arms.
- **G4 No speed gate (F2 off) and no time valve on WALL faces** (`wk175_wall_valve` false).
- **G5 Unchanged:**
  - F3: super contacts always pay;
  - F4: stunned dry reflect and underside contacts never pay and never touch arm or relight state;
  - F5: the supercharge thrust window opens only on paying contacts;
  - F7: refund amounts;
  - the WK-128 relight bill (ON);
  - the WK-135 kick floor;
  - the sports ball refuel (ON).
- **G6 Bots:** no change. `refund_rearm_pending()` keeps its contract. Under WR it can only be true for a wall face, which flat
  dives never ask about (`into` = down) and radial dives already skip through BR-135a.

### 4.2 The four gate sets (what QA arms, and what each face does)

| Face class | OFF (today) | **WR (set 1, candidate)** | WS (set 2) | FULL (set 3) |
|---|---|---|---|---|
| FLOOR tier | pays every contact | pays every contact | pays every contact | P3: F1 `max(60, 0.9 h)` + valve 1.5 s |
| FLOOR bumper (tops, cores) | pays | pays | pays | P3: C2 tier rules + valve |
| FLOOR tier-less moving deck | pays | pays | pays | F1 `0.9 h`, **no 60 px minimum** (deck fix) + valve |
| WALL tier | pays | F1 `max(400, 0.9 h)`, re-base on block, no valve | P3: F1 `max(60, 0.9 h)` + valve | = WS |
| WALL bumper | pays | F1 400, **no F2**, no valve | P3: F1 200 + **F2 900** + valve | = WS |
| CEILING | never | never | never | never |
| Super contact (F3) | pays | pays | pays | pays |

WS is FULL with floors freed, so WS → FULL isolates the floor gate on the WK-167 HEAD. WR vs WS isolates F2 and the wall details.

### 4.3 Tuning knobs (new block "WK-175 refund-gate scope" next to the WK-135 phase-3 block)

| Knob | Value | Meaning / rationale |
|---|---|---|
| `refund_gates_on` (existing master) | **false** | **OFF = today**: every contact pays, and every knob below is ignored. Shipping WR later means flipping this to true |
| `wk175_gate_set` | **1** | Which set the master turns on: 1 WR (candidate), 2 WS, 3 FULL (§4.2). Default 1, so the eventual ship is a one-line flip |
| `wk175_wall_rearm_px` | **400.0** | px a WALL face needs before it pays again. Invariant #18: ≥ 20 × 896 / (17.2 + 28.57) = 391. Below 350 even Standard cruise ping-pong beats natural bouncing |
| `wk175_wall_valve` | **false** | WR: no C4 valve on WALL faces (gravity frees you from a wall; on walls the valve was income). WS/FULL keep P3's valve whatever this says |
| `wk175_deck_exempt` | **true** | FULL only: tier-less moving-deck FLOOR faces re-arm at `refund_rearm_frac × h_launch` without `refund_rearm_min_px`, so a 48 px deck hop re-arms (0.9 × 48 = 43) |
| Env `GB_WK175` | unset | `off`/`0` → master false; `wr`/`1`, `ws`/`2`, `full`/`3` → master true + that set. Read in `Tuning._ready`, and it **wins over `GB_WK135_GATES`**. Every run's `meta.tuning` logs the set and the effective per-class values |

Untouched: `refund_rearm_frac` 0.9, `refund_rearm_min_px` 60, `refund_rearm_bumper_px` 200, `bumper_refund_min_speed` 900,
`refund_rearm_timeout` 1.5, `bumper_floor_dot` 0.5, `bumper_floor_pays_as_tier` true, every protected constant. WS and FULL
read these as today. WR reads only `refund_rearm_frac` (the tier-wall term) and `bumper_floor_dot`.

**Helper shape (programmer's call):** the `gate_*` helpers become class-aware, e.g. `gate_rules(cls, is_bumper, is_deck) ->`
`{e_min, e_frac, min_speed, valve}`. With the master false, every field is 0, which is exactly today.

### 4.4 Invariants (append to the Tuning comment and to skill tuning-and-flags)

- **#18 (WR):** `wk175_wall_rearm_px ≥ fuel_per_bumper × normal_boost_max_speed × BOOST_MAX / (natural trampoline income +`
  `normal_boost_drain())`, i.e. 400 ≥ 391. A cruise-speed ping-pong between two walls never out-earns natural bouncing.
  Re-derive if refunds, cap, profile boost, trampoline height or tank change.
- **#18b (residual, accepted):** with supercharged exits (cap 1280 for 0.2 s after a paying wall hit), the same bound would be
  559. The best case is a frame-perfect stick flip at every wall across an exposed lane, which is skill (P1 ceiling) and
  constant motion (P2). Probe P4 measures it. Ladder in §10.
- **#12, #13, #15, #16** are live only in WS/FULL. **#16 restated per face** (finding 2 of the audit): `qa_valve_over_natural`
  counts per face key. Two faces valving at once (≤ 26.7/s) is under the drain, so it isn't a bug.

### 4.5 Telemetry the build adds (Player.wk128 dict → round_stats; telemetry only)

- `refunds_blocked_rearm_floor` / `refunds_blocked_rearm_wall`: the audit couldn't split these.
- `wall_hug_contacts`: wall-class contacts with another contact on the **same face key within the previous 1.0 s**, paid or
  not.
- **`refunds_wall_hug`**: wall-class refunds that meet the same test. **This is the "wall-hug income" metric** for every bar in
  §9.
- `qa_valve_over_natural_face`: the per-face version of the old counter.
- `zero_fuel_alive_max_s`: the longest unbroken alive streak at fuel < 1 (liveness watch for removing the wall valve).
- `meta.tuning`: `refund_gates_on`, `wk175_gate_set`, and the effective rules per class.

---

## 5. Pre-registered predictions (written before any data)

Ratios are against the OFF arm of **this** batch, on HEAD with WK-167 ON, nets ON and the ball ON.

### 5.1 Brawl, bots (114 stages per arm; same slices as WK-135 p3)

| Metric | WR | WS | FULL |
|---|---|---|---|
| Floor refunds (tier floor + bumper floor) per bot air-min | **0.95-1.05x** | 0.95-1.05x | 0.70-0.85x |
| Wall refunds per bot air-min (all) | 0.55-0.80x | 0.30-0.45x | 0.30-0.45x |
| Wall refunds per bot air-min, 5 bumper arenas | 0.55-0.75x | 0.30-0.40x | 0.30-0.40x |
| **`refunds_wall_hug` per bot air-min** | **≤ 0.25x** | ≤ 0.15x | ≤ 0.15x |
| Fuel income per bot air-min | 0.88-0.96x | 0.82-0.90x | 0.68-0.80x |
| Credited KO/min | **0.95-1.05x** | 0.88-0.98x | 0.80-0.90x (fails) |
| Median stage | ±8 % | +3 to +12 % | +12 to +22 % (fails) |
| Bot self-KO share | −1 to +2 pp | +1 to +4 pp | +2 to +5 pp |
| Self-KO share, 5 bumper arenas | 0 to +3 pp | +4 to +9 pp (fails D8) | +5 to +10 pp |
| Bumper Gauntlet self-KOs | OFF + 0..2 | OFF + 4..8 | OFF + 5..10 |
| Time below refuel floor | 1.00-1.15x | 1.1-1.3x | 1.3-1.6x |
| Stuck / bot-stage | 0.95-1.05x | 0.9-1.05x | 0.75-0.95x (bots fall instead) |
| Surface contacts/s max | ≤ 12 | ≤ 12 | may exceed 12 (deck/core) |
| `qa_valve_over_natural_face` | 0 (valve inert) | 0 | 0 |
| `zero_fuel_alive_max_s` | ≤ 4 s | ≤ 4 s | ≤ 4 s |
| `dribble_episodes` per stage | = OFF ±15 % (pre-existing) | = OFF | = OFF |

The OFF repeat (OFF-r) predicts every OFF-r/OFF ratio within ±8 %. A wider spread means the bars are noise-limited (§9.4).

### 5.2 Sports (Rocketball, 4 courts × 240 s, seats `hum` and `bot`)

| Metric | WR | WS |
|---|---|---|
| hum goals/min | 0.92-1.08x | 0.90-1.10x |
| hum touches/min | 0.97-1.03x | 0.90-0.97x |
| hum starved share (all / CPU seat) | 1.00-1.15x / 1.00-1.20x | 1.2-1.45x |
| hum human wall refunds/min | 0.45-0.75x | 0.15-0.25x |
| hum own-goal share | ±3 pp | ±5 pp |
| bot touches/min | 0.92-1.00x | 0.70-0.85x (fails) |
| **bot starved share** | **1.05-1.35x (the at-risk bar)** | 1.6-2.2x (fails) |
| bot goals/min | 0.85-1.05x (noisy) | 0.70-0.85x |
| CPU wall refunds/min (bot) | 0.45-0.70x | 0.30-0.40x |

### 5.3 Mechanism probes (scripted pilot; run per arm)

| ID | Probe | OFF | **WR** | WS | FULL |
|---|---|---|---|---|---|
| P1 | Hold FLY into a trampoline-tier side, straight, 5 s from 50 fuel | rises to and stays near 100 | **exactly 1 refund**, then −28.6 ± 1 /s, empty by ≤ 2.6 s after the first touch | 1 refund, then valve ≤ 1 per 1.5 s | = WS |
| P1b | Same at 45° | rises | ≤ 1 refund, net trend < 0 | ≤ 1 per 1.5 s | = WS |
| P2 | Hold FLY into a bumper wall (sports_court side), straight and 45°, 5 s from 50 | pinned ~98 | **1 refund**, then −28.6/s | 0 refunds | 0 |
| P3 | Zigzag up n2_wall_climb chimney 1 (420 px) | pays every contact | **≤ 1 refund per face** (2 total) | 0 bumper refunds | 0 |
| P4 | Ping-pong: Bumper Gauntlet LEFT block right face (x700) ↔ POST-L left face (x1220), 432 px of centre travel, FLY held, stick flipped at each contact, 8 s from 50 | every contact pays | every contact pays (432 ≥ 400). Net **+8 (cruise) to +30 (supercharged) fuel/s**; x-range per cycle ≥ 400 px | 0 refunds at cruise | = WS |
| P5 | Floor hold-down dribble, trampoline, 4 s from 60 | net ≈ +36/s | **= OFF** (§1 residual) | = OFF | drains (A8: 3 refunds / 4 s) |
| P6 | Natural trampoline bouncing, 6 s from 0, no input | 5/5 pay | **5/5** | 5/5 | 5/5 |
| P7 | Drop 300 px onto a bumper top, no input, 10 s, 0 fuel | every contact pays | **= OFF** | = OFF | 5-6 distance refunds, then valve |
| P8 | Ride the Meadow Carousel deck, no input, 10 s, 0 fuel | every hop pays | **= OFF** | = OFF | every hop pays (deck fix: 43 < 48) |
| P9 | Super into a bumper wall at 0° / 45°; wall-return shot (test 6d) | pays / fires | pays 2/2 / ≥ 9/10 | same | same |
| P10 | Flight School tut_02 and tut_03: feather `pulse:5,10`; super `combo50` / `combo30` | feather fails (rise ~2157), super HOME 3.1 / 3.9 s | **bit-identical to OFF** | identical | identical |

---

## 6. Edge cases

- **E1 Radial wells (Singularity, Orbit set):** the class is per contact (G1). A FLOOR contact on a face key never reads or writes
  that key's wall arm state, so a face that curves from floor into wall can't lock you out of the floor half. Round cores are
  FLOOR, so a pinned or thrust-dribbling goat on a core is paid every contact as today. BR-135 still breaks the pin.
- **E2 Liveness without the wall valve:** wall-class means the face normal is within 60° of horizontal relative to local
  gravity, so gravity has a component along the face and you slide off. A 0-fuel goat can't press into a wall either.
  `zero_fuel_alive_max_s` watches for a counter-example, such as a V-pocket of two wall-class faces in a well. Ladder §10.
- **E3 Corners (floor + wall in one tick):** classes are independent. The floor pays and the wall is judged by G3. Today's
  first-resolved-contact order is unchanged.
- **E4 Bumper post tops vs sides:** a post is four face keys. Its top (FLOOR) always pays. Each side pays once per 400 px
  departure.
- **E5 Moving walls (KeyDoor, DropTile, pendulums, cart sides):** excursion is measured in world space from the paying position
  (WK-128 E5). A wall that chases you back inside 400 px doesn't pay again. That's intended, and it's rare.
- **E6 Supers and launched bodies:** F3 always pays, so the wall-return shot and super chimneys are intact. A smash-launched
  victim's first post-hitstun wall contact pays at any speed under WR (WS needs ≥ 900).
- **E7 Stunned / underside / head-bounce / ghost puff:** unchanged. These never pay and never touch arm state.
- **E8 Sports:**
  - The goal-wall keeper hover dies (P2).
  - Banking off a side wall pays once per 400 px departure, and the side walls are 2220 px apart, so chasing the ball across
    the court re-arms naturally.
  - Mid-block tops are FLOOR, so they always pay. Ball refuel is unchanged.
  - The WK-135 ruling "sports' refund source is the ball, not the walls" was about the wall *pump*, and WR kills the pump.
    Recorded as an amendment, not a reversal.
- **E9 Trials:**
  - No course gets easier than today: floors are equal and walls pay less.
  - n2_wall_climb gets ≤ 2 wall refunds per climb (intent: "walls refund nothing", close enough; P3).
  - The tut_02/03 "NO side walls" caveat is closed for hover farming.
  - n2_slalom-style bumper mouths now pay once per face instead of every contact.
- **E10 Profiles:** Ziggy (896 cruise) gives the bound behind #18. Every other profile is slower, so it's safer.
- **E11 Tier chimneys:** the WK-128 E11 level lint (no tier-faced walls taller than 400 px facing each other within 600 px)
  stays in force. Under WR a tier wall needs ≥ 400 px of departure anyway.
- **E12 Respawn:** clears face memory (unchanged).

---

## 7. Side effects

- **Brawl recovery:** recovering goats keep cruise post caroms (one pay per face), so Bumper Gauntlet's "bumpers refund fuel to
  sustain ricochet chains" intent survives. Only a re-hit of the same face within 400 px is lost.
- **Bots:** behaviour is identical on floors. The wall income loss is ~3 refunds per bot air-minute (prediction §5.1).
  `dribble_episodes` stays at its pre-existing ~4 per stage. That's a motion pathology, not an economy one, and it's routed to the
  WK-168 motion-health bucket so it doesn't block this item.
- **Sports CPUs:** the at-risk number. CPUs lose repeat wall income in scrums near walls. Mitigations already live: the ball
  refuel and the trampoline floors.
- **Feel:** no physics change. The only felt difference: lean on a wall and the gauge drains instead of filling.

---

## 8. Deferred (filed, not built here)

- **WK-175b [P3][S] Floor-dribble gate.** Pull it only if a CD pass or human session flags floor refuelling as degenerate, or if
  FULL passes every bar in this batch. Sketch:
  - Gate a FLOOR contact only when it is made **while thrusting into the face** (FLY held, `aim·n < −0.5`) **and** the
    face's last pay was less than `max(100 px, 0.5 × h_launch)` ago. Natural bounces, released dives and dive-into-bounce
    supercharges (first contact) always pay.
  - Pair it with **BR-175**: in every non-recovery bot path, release FLY while within E of a just-blocked floor face until the
    apex (BR-128 generalised beyond the refuel dive).
  - Needs its own CD feel pass on "does boosting into the floor feel dead?".
- **Refuel ding** (WK-128 §7.5) → ui-ux-designer + sound-designer. Not blocking. It makes "walls refuel once" learnable without
  text.
- **Bot dribble pathology** (~4 per stage, both arms, bar 0.2) → WK-168 motion-health bucket (gameplay-programmer).

---

## 9. A/B plan and acceptance (ONE headless batch, at most 2 Godot processes)

### 9.1 Setup (reuse `tools/out/wk/wk135_p3_ab/`)
- **Scratch copy:** `mkcopy.py` / `install.py` exactly as before. No `.git` or `tools/out`, every working-tree-modified file
  pinned to its HEAD blob, hashes checked against `git ls-tree HEAD`, McpInteractionServer removed, custom user dir, and
  `Tuning.circuit_session_deck = false` in the scratch copy only.
- **Settings:** HEAD defaults otherwise (WK-167 ON, nets ON, ball ON, WK-161b OFF, WK-109 OFF, WK-169 unset).
- **Arms:** environment only, `GB_WK175=off|wr|ws|full`. `GB_WK135_GATES` and `GB_WK135_BALL` are unset.
- **Harness:** `P3Boot` / `P3Rec` / `HumanSim3` unchanged, plus the new §4.5 counters in the recorder.
- **Scripts:** copy `jobs.py` → `jobs175.py` and `st.py` → `st175.py`.
- **Output:** `tools/out/wk/wk175_ab/` (raw/, batch.log, `WK-175_ab_summary.json`). The audit goes in
  `docs/audit/<date>_wk175_ab.md`.
- **Mechanism probes:** reuse `tools/out/wk/wk135_p3/Probe135.gd.txt` (A6 tier/bumper wall-hug, A8 dribble, A9c, A10) and
  `tools/out/wk/wk128_harness/Wk128Mech.gd.txt` (A7 zigzag, 6d). QA adds two plans: P4 ping-pong and P8 deck ride.
- **Pre-flight:** 2 smoke runs (OFF and WR) inside the batch. Each must log the right `wk175_gate_set` and effective values,
  0 SCRIPT ERRORs, and `refund_gates_on` matching the arm.

### 9.2 Jobs (about 57 min of batch at 2 processes, using the WK-135 p3 timings)

| Group | Arms | Content | Jobs |
|---|---|---|---|
| Brawl | OFF, WR, WS, FULL, **OFF-r** | Same 13 jobs per arm as WK-135 p3: Singularity 13/17 ×10; pinball_pit, hay_bales, bumper_gauntlet, sky_ladder_brawl, high_pasture seed 7 ×8; meadow_carousel 7/13/17 ×8; rotation 13/17/19 ×10. 4 bots L3/L2/L3/L4, LIVES 1. **114 stages per arm** | 65 |
| Sports | OFF, WR, WS | Rocketball on CENTER, BOX, HAUL, BOWL, seed 13, 240 s, goal target 999. Seats `hum` (3 HumanSim3 + CPU L2) and `bot` (4× L3). Arm order rotated per block | 24 |
| Probes | OFF, WR, WS, FULL | P1-P9 suite, 1 job per arm; P10 Flight School, 4 plans per arm | 20 |
| Human brawl (optional) | OFF, WR | Rotation seed 13 ×10 with `seats=hum`, **only if P3Boot already supports it** (checked in the smoke run, no new harness code). Pays the audit's owed "human self-KO under gates" | 2 |

**Trim order if the slot is short** (pre-registered, cut from the top):
1. the WS `hum` sports block (4 jobs);
2. FULL Singularity (2 slow jobs);
3. OFF-r outside the rotation and bumper slices.

Never trim OFF, WR or the probes.

### 9.3 Ship bars for WR (every one must pass on its point estimate; the stats are as in the WK-135 p3 audit)

**Brawl (WR vs OFF, all 114 unless stated):**

| ID | Bar |
|---|---|
| D1 | Credited KO/min **0.90-1.15x** (all 114 and the rotation slice) |
| D2 | Median stage **±15 %** |
| D3 | Bot self-KO share **≤ +3 pp** |
| D4 | Post-smash survival ±5 pp |
| D5 | Stuck ≤ 1.1x; time below refuel floor ≤ 1.3x; surface contacts/s max ≤ 12; rest_episodes 0; stages never ended 0; `zero_fuel_alive_max_s` ≤ 6 s |
| D6 | **Floor refunds 0.95-1.05x** (proves natural income is left alone) |
| D7 | **Wall-hug income** (`refunds_wall_hug` per bot air-min) **≤ 50 % of OFF**. If OFF's own rate is < 1.0 per bot air-min, the ratio is reported only and P1/P2 decide |
| D8 | 5 bumper arenas: self-KO ≤ +3 pp; empty-tank falls (uncredited deaths with ≤ 4 fuel in the last 3 s) ≤ 1.3x OFF; **Bumper Gauntlet self-KOs ≤ OFF + 3**, with Fisher p ≥ 0.10 vs OFF |
| D9 | Meadow Carousel: self-KOs whose last contact was the deck ≤ OFF + 2 |
| D10 | Relight bill share ≤ 10 % (unchanged rule; sanity check) |

**Sports (WR vs OFF), "unaffected unless intended":**

| ID | Bar |
|---|---|
| E1 | `hum`: goals/min ≥ 0.90x; touches ≥ 0.90x; starved share ≤ 1.25x **for all seats and for the CPU seat**; own goals ≤ +3 pp |
| E2 | `bot`: touches ≥ 0.90x; starved ≤ 1.25x; goals ≥ 0.90x **or** p ≥ 0.10 (Poisson, pooled courts). All-bot goals moved 0.72x on one court with no relevant change in the last batch, so goals alone can't fail WR |
| E3 (intended) | Human wall refunds/min fall (reported); human `refunds_wall_hug` ≤ 50 % of OFF |
| E4 | Kickoff and restart unchanged: gates open 3.508 s, restart 2.667 s, kickoff goals under 4 s ≤ 10 % |

**Probes:**
- P1 and P2 hit their WR row exactly. This is the "wall-hug farming is dead" proof, and it governs over D7.
- P3 ≤ 1 refund per face.
- P4 net ≤ **+34 fuel/s** (2x natural), with an x-range ≥ 400 px per cycle (it must be travel, not a hover).
- P5-P8 equal OFF.
- P9: P9 passes.
- **P10: Flight School feather still fails** on tut_02 and tut_03, and the super goes HOME, bit-identical to OFF.

**Noise control:** OFF-r vs OFF must sit inside the D1, D2, D3 and E bars itself. If OFF-r/OFF breaks a bar, that bar is
noise-limited. A WR result on that bar inside the OFF-r spread is then judged "no detectable effect", and doesn't count as a fail.

### 9.4 Decision table (pre-registered)

| Result | Action |
|---|---|
| WR passes every bar | Run the rendered checks (§9.5) and the CD feel check (§9.6). If those pass, the director flips `refund_gates_on = true` (`wk175_gate_set` 1) and writes the DECISIONS entry (§11). WK-175 closes |
| WR fails only E2 (all-bot sports starved or touches) | Ladder row 2 (§10). The gates stay OFF until it re-measures |
| WR fails any brawl bar | Ladder row 1. The gates stay OFF |
| WR fails P1/P2 | Build bug: fix and re-probe (probes only, no batch) |
| WS or FULL pass | Recorded as attribution only. If FULL passes **everything**, WK-175b is pulled with that evidence for a CD floor-feel review. **Nothing but WR ships from this item** |

Attribution recorded either way:
- OFF → WR: the cost of the hug gate.
- WR → WS: the cost of F2 (prediction: WS fails D8 and E2).
- WS → FULL: the cost of the floor gate on the WK-167 HEAD (prediction: FULL fails D1/D2).

### 9.5 Rendered checks (after the batch, WR only; headless numbers are not the validation)

1. **sports_court wall hug, rendered:**
   - Steps: `tools/run_game.ps1`, then `gbplay eval Tuning.refund_gates_on = true` (set 1), then a Rocketball lobby, P1 at 50 fuel.
     Hold FLY into the left side wall for 5 s.
   - Pass: the gauge ticks up **once** (+20), then empties within ≤ 3.0 s of the first touch, and the goat drops to the floor.
   - Evidence: screenshots at 0, 1, 2 and 3 s, LOOKED at.
2. **Natural loop, rendered:**
   - Steps: Bumper Gauntlet, P1 dropped onto island A at 0 fuel, no input.
   - Pass: gauge ≥ 80 after 4 bounces (≤ 5 s), identical to OFF.
3. **WK-93 recordings,** contact sheet plus overlay (paying contact / blocked contact / boosting), LOOKED at:
   - 30 s of 4-bot WR on bumper_gauntlet, plus meadow_carousel. These are owed from the WK-135 p3 audit.
   - Pass: no bot hovers beside a wall; bots still visibly pinball off posts; no deck buzz over 12 contacts/s.

### 9.6 Creative-director feel check (SHIP or a numbered FIX list)
1. Do walls still feel like part of the toybox (bank off one and keep going), or do they feel dead?
2. Is there any moment where you expected fuel from a wall and didn't get it, and it felt unfair rather than learnable?
3. Is the floor loop exactly as before?
4. Sports: is anyone starved or stuck near a wall?

Any "no" is a FIX, whatever the numbers say.

---

## 10. Fallback ladder (pre-registered; one step at a time, re-measured after each)

| Symptom | Rung 1 | Rung 2 | Forbidden |
|---|---|---|---|
| WR fails brawl D1-D3/D8 (unexpected: floors are untouched) | Read `refunds_blocked_rearm_wall` per arena. If one arena carries the fail, it's a level-designer geometry fix | `wk175_wall_rearm_px` 400 → 350 (Standard-profile parity; Ziggy sits ~10 % over natural). If that still fails: **Won't do**. Gates stay OFF, and WK-175 closes with the evidence (a P3 exploit no CD flagged) | Floor gates; F2; refund amounts; per-arena or per-mode economy flags |
| WR fails only E2 (all-bot sports) | **BR-175s**: sports CPUs below the refuel floor take a floor bounce before re-engaging. That's a bot knob, not an economy fork. Measured in a sports-only follow-up batch (16 jobs) | Director's call: ship WR with an all-bot watch if E1 (including the CPU seat) passes | A per-mode surface refund rule; `wk175_wall_rearm_px` < 350 |
| P4 ping-pong net > +34/s | `wk175_wall_rearm_px` 400 → 560 (the supercharge-cap bound, #18b) | WS wall rules on bumper walls only | Supercharge constants |
| `zero_fuel_alive_max_s` > 6 s against a wall-class face | `wk175_wall_valve = true` (C4 at 1.5 s, walls only) | Level geometry (the pocket) | Lethal walls |
| CD Q1/Q2: walls feel dead or unfair | Build the refuel ding (WK-128 §7.5) first, then re-ask | `wk175_wall_rearm_px` 400 → 350 | F2 |

---

## 11. Change control

- **Class:** an economy-rule **scope** change (which faces the existing WK-128 F1 gate covers) plus telemetry. No physics, no
  protected constant, no bot brain change. Ships OFF. The ship is a director flip after §9.
- **Files for the programmer:**
  - `Tuning.gd`: the §4.3 block; `GB_WK175` in `_ready`; class-aware `gate_*` helpers; invariant #18/#18b comments; a note in
    the WK-135 phase-3 header that the master now means "the `wk175_gate_set` scope".
  - `Player.gd`:
    - `_wk128_contact_pays`: G1 class for tier faces too; G2 floors bypass the gate; G3 wall re-arm with re-base; G4 no F2 /
      no valve on walls under WR; the deck exemption for FULL;
    - `_wk128_track_faces`: the valve honours `wk175_wall_valve` per class;
    - the §4.5 counters.
  - `InputBot.gd`: **no change.** Verify only that `refund_rearm_pending()` stays false on floors under WR (log it in the smoke
    run).
  - **No level JSON change.**
- **DECISIONS entry (draft for the Director, only after §9 passes):**
  > **<date> REFUND GATES: WALLS ONLY (WK-175).** The WK-128 (b) refund gate now covers WALL-class faces only. A wall (tier side
  > or bumper side) pays once, then again only after you fly 400 px away from it (`wk175_wall_rearm_px`; invariant #18: a cruise
  > ping-pong never out-earns natural bouncing). No speed gate, and no time valve on walls. FLOOR-class faces (floors, bumper
  > tops, cores, moving decks) always pay, exactly as before, so natural bouncing income is unchanged. This kills the wall-hover
  > farm (the P2 camp) without the bot starvation the full gate caused: [A/B numbers]. The floor dribble is accepted as a
  > residual (WK-175b if ever flagged). Switch: `refund_gates_on` (false = every contact pays).
  > Amends the WK-135 sports ruling: walls in sports may pay once per departure. The pump is what was banned, and it stays dead.
- **Findings routed:** bot dribble pathology → WK-168 bucket; refuel ding → ui-ux + sound; per-face valve counter → done in
  this build.

## 12. Out of scope
- Floor gating of any kind (WK-175b).
- Refund amounts, tank, physics and supercharge.
- Ball refuel.
- Per-mode or per-level economy rules.
- WK-161b.
- The level lint run (E11 stays as is).
