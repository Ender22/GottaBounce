# WK-20d: Brawl pacing on MEADOW MILE. Diagnosis, one-at-a-time test ladder, guardrails, measurement plan (2026-11-15)

**Owner:** game-designer (diagnosis, ladder, pre-registered rulings) · **Builds:** gameplay-programmer (OFF-by-default knobs, §4) +
level-designer (JSON variants, §4.1 / §4.5 / §4.6) · **Runs it:** qa-playtester · **Source finding:** CD3-01
(`docs/audit/2026-11-15_cd3_playthrough.md`)
**Inputs read:** CD3 audit + `tools/out/cd3/{m1,m2,m3off}/stats.json` + `HumanSim3/TapPilot/SuperPilot.gd.txt` · WK-20a spec + results ·
DECISIONS (WK-128 bill-only, ghosts, WK-20a rulings, WK-95e HOT rule, WK-95 flight ruling, weekend autonomy (c), 2026-07-19
knockback) · owner check-in 2026-11-14 · GAME_ESSENCE · VISION · GDD · FEEL_REFERENCE · `Tuning.gd` · `Player.gd`
(`_fire_super` L721, smash branch L1120-1180, `SPAWN_PROTECT_TIME` L38) · `PartyMatch.gd` (`_spawn_at` L2009,
`_classify_blast_edge` L1164) · `LevelLoader.gd` (`bounds` override L190) · `levels/circuits.json` + the 20 MEADOW MILE level JSONs.
**Rules for this spec:** no code, no BACKLOG edit. Every candidate ships as an OFF-by-default knob or a JSON variant in a QA scratch
copy, so the batch toggles it at runtime and nothing persists.

> **2026-11-15 addendum (§11, after WK-CD4 and the R1-R4 ruling):** T1 (overall median ≥ 12 s) is **retired** and replaced by
> per-arena-class targets. **R5 is Won't do.** **R6 is a conditional**, held for the post-CD4-01 measurement. See §11.

---

## 0. At a glance

**The problem in one line:** on MEADOW MILE, newcomers fire a full-tank super, miss, and leave the stage on an empty tank. About
half of all human deaths have no hit in them. The stage is over before anyone gets launched and claws back.

**What causes it (§3):**
1. **The drain-all super, with nothing under you.** 22 of 27 decomposed human self-KOs came ≤ 4.5 s after the victim's own super.
   16 of those came ≤ 1.5 s after it.
2. **A super that cannot land.** About a third (9/27) followed a super fired while every goat was still spawn-protected. In that
   window a super *cannot* connect, so it is pure self-harm.
3. **Spawn pairing at the outer edge.** In 14 of 20 arenas two of the first four spawns sit 250-700 px apart. Spawn 0 sits 300-400 px
   from the left edge. 8 of the 9 side-edge self-KOs were seats P1/P2 on arenas where they share the left island.
4. **Every gap is lethal.** 19 of 20 MEADOW MILE arenas are `void_is_floor`, and their side runways are 540-600 px. A whiffed
   horizontal super carries about 3,000 px.

**Ladder, in priority order (§4, §5).** Each rung is first A/B'd **alone** against the same baseline. The keepers are then stacked in
this order.

| Rung | Candidate | Class | Targets |
|---|---|---|---|
| R1 | **Spawn spread.** Re-author `player_spawn` on the 20 MEADOW MILE arenas | data (JSON) | pairing, edge proximity |
| R2 | **Spawn truce.** You can't arm a super while you are blinking (spawn-protected) | tiny rule, Brawl-only | the zero-upside opening super |
| R3 | **Whiff brake.** A super that touched nothing bleeds to 700 px/s over 0.15 s when its 0.45 s window ends | rule, Brawl-only | whiff carry off the map |
| R4 | **Fumble reserve.** A whiffed super returns min(15, fuel at fire). That fuel can't arm a super until the next paying bounce | economy rule, Brawl-only | dry-tank fall after a whiff |
| R5 | *(conditional)* Side runway to 720 px on MEADOW void arenas | data (JSON bounds) | marginal side self-KOs |
| R6 | *(conditional)* Catch shelves in the worst arenas' gaps | geometry | the claw-back on void arenas |

**Not on the ladder:** knockback back to 1.0× (owner-only data, §2.2), the score screen / countdown (owner-ruled), KILLS / LIVES /
camera, every DO-NOT-TOUCH constant, and super power scaling.

**Targets (Accept line for WK-20d, §5.3):**
- Median stage **≥ 12 s** (and ≤ 20 s).
- Human self-KO share **≤ 25 %** (and ≥ 12 %; the comedy stays).
- First death median **≥ 4 s**.
- Credited KO/min **≥ 9.5**.
- Super share of credited KOs **60-85 %**.
- Confirmed by a second, independent driver.

**Budget:** one headless batch, ≤ 2 Godot processes at a time, ≈ 880 stages core (cap 1,050), ≈ 3 h of **game time**. Game time
only, because the GPU is in software-rendering mode (§8).

---

## 1. The fantasy at stake (core verbs)

GAME_ESSENCE: *fight, get launched, claw back, super-smash.* All four verbs have to fit inside a stage:
- **BOUNCE** and **FLY** are happening. Humans are airborne 100 % of alive time and boosting 20-33 % of it (CD3).
- **SUPER-SMASH** is the kill. It lands 70 % of credited KOs.
- **RECOVER** is what's missing. With a 2.8 s first death and drain-all supers next to voids, a newcomer's arc is "fly at someone,
  super, miss, gone". The recovery gamble (GDD §4.6) never starts, because the player who just missed has no fuel to gamble with.
  CD3: "readable, fair and frantic. It is not yet a place where comebacks happen."

**What we protect:**
- The super stays a full-power, drain-all, decisive commitment. Missing still costs you.
- Self-destruct comedy stays possible near edges (GDD §4.2 "rocket straight off the opposite side"). It just stops being the default
  outcome of a mid-stage miss.
- The **victim's** triad (hitstun → no mid-flight refuel → fuel-gated recovery, GDD §4.6) is untouched. Every candidate below only
  affects the **shooter** of a missed super, or the opening, or geometry.

**What each rung exercises:**

| Rung | Verbs | How we'll see the verb being used |
|---|---|---|
| R1 | FLY | the opening has distance to cross (spawns ≥ 900 px apart) |
| R2 | SUPER | supers fire when they can land (after 1.3 s), not before |
| R3 | SUPER (attack range) + RECOVER | a missed super ends in flight range, so the stick matters again |
| R4 | RECOVER | a miss leaves one brake's worth of fuel |
| R6 | RECOVER | a fall becomes a claw-back |

M9 (§6) measures claw-backs directly.

---

## 2. Constraints

### 2.1 Hard (owner rulings + studio fences)
- **Knockback array** `dmg_launch_mult` [1.25, 1.66, 2.08] is untouched (owner 2026-07-19).
- **Camera** stays on the owner rules (2026-07-10). `camera_bounds` = platform union + `cam_bounds_pad`. No candidate changes
  platforms except R6, and R6 must be checked against camera bounds.
- **KILLS 10, LIVES 1, Ra scoring** (self-KO costs 0, WK-20a ruling) stay as they are.
- **Flight responsive / super = attack** (WK-95 owner ruling):
  - No candidate touches `normal_boost_*`, grip, or the boost constants.
  - No candidate may make the super a better way to travel. R3 makes it worse at travel. R4 has a re-arm gate so it can't chain
    supers.
- **DO-NOT-TOUCH:**
  - the hitstun triad (0.15 / 0.00025 / 0.55);
  - `sudden_death_time`;
  - super power scaling (`super_boost_impulse_full` 2800 stays constant: power never scales with fuel);
  - `fuel_per_bumper` 20;
  - `round_end_freeze` (cap 2.0);
  - `super_boost_min_fuel` 10 (it sits at the `fuel_per_bounce` ≥ 2 × min invariant);
  - INV-1 (`normal_boost_max_speed` ≤ 800).
- **WK-128 bill constants** (`boost_relight_*`) are not changed by this item. CD3-04 owns them.
- **Sports and Trials / Flight School stay byte-identical.** R2, R3 and R4 are gated to BRAWL through the GameMode seam (§7 G9 / G10).

### 2.2 Owner-only data (not a rung)
CD3 suggested "knockback back to 1.0×" as a test. That is an owner ruling, so it is **not eligible for adoption**. The data also says
it can't fix this problem:
- **No-hit deaths are immune to knockback by construction.** 50 of 105 human deaths across the three CD3 matches had no smash on the
  victim inside the 6 s credit window. Knockback only acts on hit victims.
- **WK-20a already showed that stage length isn't knockback-driven.** In arm A vs arm B, the median stage was 9.1 vs 8.4 s, inside
  the noise.

If the Director wants an owner-facing comparison, it can be one extra 80-stage arm (runtime `dmg_launch_mult = [1.0, 1.33, 1.66]`,
restored after), labelled **OWNER-ONLY DATA**. It is outside the core budget.

---

## 3. Diagnosis (evidence)

**Method.** I hand-extracted the kill, super and stage records from `m1/stats.json` (12 stages) and `m2/stats.json` (15 stages).
That gives a time-ordered decomposition of all **27** human self-KOs (killer = −1).
- `m3off` (17 stages, bill OFF from stage 5) is counted for totals and used as replication.
- **QA's analysis script must reproduce these counts from the same files before any arm runs** (§8.4 step 0). That is the recorder
  sanity check.
- Drivers: 3 × HumanSim3 (pad 1, pad 0, keyboard with 8-way aim) + CPU L2. Ghosts and powerups were at their defaults.

### 3.1 Totals

| | m1 | m2 | m3off | Pooled |
|---|---|---|---|---|
| Human self-KOs / human deaths | 10/30 (33 %) | 17/35 (49 %) | 23/40 (58 %; 48 % in its bill-OFF half) | **50/105 (48 %)** |
| Credited KOs / combat-min | 13.0 | 10.9 | – | 11.8 (m1 + m2) |
| Median stage (m1 + m2, n 27) | | | | **8.41 s** (4/27 under 5 s) |
| Super share of credited KOs | | | | 35/50 = 70 % (CD3) |
| CPU self-KOs | 0/4 | 1/9 | 1/9 | 2/22 |

Two more readings from these totals:
- **"Everyone self-fell, the CPU survived for 0 points" happened 4 times in 44 stages.** That's m1 Islands Void, and m3off Islands
  Void, The Cliff and Hill and Dale.
- **The CPU almost never self-KOs here (2/22).** The bot HOT rule is not the problem in human matches.

### 3.2 Mechanism 1: the drain-all super with nothing underneath (dominant)

`Player._fire_super` sets `fuel = 0.0`. After a whiff, the only horizontal brake is air drift at 1,300 px/s² toward the stick. Rough
physics for a horizontal whiff:
- **Inside the window:** in the 0.45 s `super_active_time` window it travels ≈ 1,130 px (2800 × 0.45 − ½ × 1300 × 0.45²).
- **After the window:** it then coasts another ≈ 1,850 px (2215² / 2600).
- **Total ≈ 3,000 px.** That is 0.8-1.6 arena widths.
- **Over a void:** with gravity 1,600, the goat reaches the void rim in about 1 s. The tank refills only on contact, so it hits the
  rim empty.
- **The bot heuristic is far off.** `InputBot.SUPER_CARRY` = 720 underestimates this by about 4×. That's a side note for the bot lane.

Timing of the 27 human self-KOs relative to the victim's **own last super**:

| Bucket | n | Of which | Edge |
|---|---|---|---|
| **≤ 1.5 s after own super** ("whiff carry", or trade) | **16** (59 %) | 13 after a whiff, **3 after a LANDED super** (attacker stops at 10 % momentum, tank empty, over the void) | 9 side, 7 void |
| **1.5-4.5 s after own whiff** ("dry fall") | **6** (22 %) | all whiffs | 6 void / bottom |
| **No own super within 4.5 s** ("drift / dry flight") | **5** (19 %) | chase flight over the gaps drained the tank | 5 void |

Replication in m3off:
- **Islands Void:** all three humans supered at 0.99-1.23 s with 76-92 fuel. All three died at 1.58-2.28 s.
- **The Cliff:** all three died 1.2-4.1 s after their supers.

### 3.3 Mechanism 2: the opening super that cannot land
- All goats spawn together with `SPAWN_PROTECT_TIME` 1.3 s. Until it expires **no super can land on anyone**, but it still empties
  the tank.
- HumanSim3 fired about 30 supers before 1.3 s across m1 + m2, at 75-100 fuel. Essentially none landed.
- **9 of 27** human self-KOs (33 %) followed a super fired inside that window.
- Including m3off: Islands Void ×3 and Twin Chasms ×1 more.
- Opening self-KOs (< 3 s) are **15/27 (56 %)** of self-KOs and **23 %** of all human deaths.
- **Caveat:** HumanSim3 has no opening idle. WK-20a's newcomer driver had one, and its opening share was only 17-23 %. So this bucket
  is driver-sensitive. That's why the cross-driver check (T7) exists.

### 3.4 Mechanism 3: spawn pairing at the left edge
`PartyMatch._spawn_at(i)` is a fixed `spawns[i % n]`. Seat P1 always gets spawn 0, and P2 gets spawn 1.

| MEADOW MILE arena (circuit order) | spawn0-spawn1 gap | closest pair among spawns 0-3 | spawn0 x (walkable edge = 0) |
|---|---|---|---|
| 1 Grassy Expanse | 2960 | 583 (different heights) | 400 |
| 2 Islands Void | 1540 | 1540 | 480 |
| 3 The Cliff | **550** | 550 | 400 |
| 4 Twin Chasms | 3000 | **250** (spawn1/spawn3) | 500 |
| 5 Meadow First Hop | 700 | 700 | 400 |
| 6 Clover Steps | **270** | 270 | 350 |
| 7 Sunny Shoulders | 700 | 700 | 400 |
| 8 Three Meadows | **400** | 400 | 350 |
| 9 Daisy Ring | 1500 | 520 (vertical stack) | −750 (ring) |
| 10 Long Meadow | 1550 | 1480 | 350 |
| 11 Hill and Dale | 1400 | ~1400 | 370 |
| 12 Bluff Line | **500** | 500 | 400 |
| 13 Two Hills | **550** | 550 | 350 |
| 14 Meadow Spine | **400** | 400 (spawns 0/1/2 in 800 px) | 200 |
| 15 Stepping Bloom | 1280 | 1200 | 340 |
| 16 Windmill Meadow | **400** | 400 | 300 |
| 17 Hay Bales | **500** | 500 | 300 |
| 18 High Pasture | **400** | 400 | 1000 |
| 19 River Split | 600 | 600 | 400 |
| 20 Meadow Carousel | **550** | 550 | 350 |

- **Spawn-protect window:** 14/20 arenas have a pair of the first four spawns closer than 700 px. That is inside HumanSim3's 560 px
  attack trigger, and inside the distance a newcomer covers by reflex in the spawn-protect window.
- **Distance to the blast line:** spawn 0 is 840-1,000 px from the left blast line, which one in-window super covers.
- **Side-edge self-KOs:** **8 of 9** were seats 0/1, at ≤ 2.6 s, ≤ 1.06 s after their own whiff, on arenas where spawns 0 and 1 share
  the left outer island:
  - The Cliff ×2
  - Clover Steps ×2 (both at the same frame, 1.106 s)
  - Sunny Shoulders ×2
  - Two Hills ×2
  - Two Hills again in m3off at 1.05 / 1.18 s
- **Seat skew:** in m2, seats 0/1 took 14 of 17 human self-KOs. Seat 2 (centre spawn) has the fewest pooled.

### 3.5 Mechanism 4: edge geometry and blast margins
- **19/20 arenas are `void_is_floor`.** Every inner gap (≈ 580 px) is lethal for an empty goat.
- **Explicit side runways are 540-600 px** on most void arenas. The derived-bounds doctrine caps runway at 720 (`bounds_side_max`)
  for the reason it gives ("walkable edge always inside the Lv0 band").
- **Whiff carry (≈ 3,000 px) dwarfs any runway the doctrine allows.** So margins can only rescue marginal cases. That's why R5 is
  conditional.
- **Hotspots** (pooled human self-KOs):

  | Arena | Human self-KOs | Share of all 50 |
  |---|---|---|
  | Islands Void | 7 | |
  | The Cliff | 6 | |
  | Hill and Dale | 5 | |
  | **Top three together** | **18** | **36 %, in 20 % of stages** |
  | Two Hills | 4 | |
  | Twin Chasms | 4 | |

  Hill and Dale was short in all three matches (3.3-4.8 s in m1/m2), even though its spawns are well spread. It is the clearest
  geometry candidate (R6).

### 3.6 Things checked and ruled out (or not levers)
- **WK-128 bill:** not the cause. CD3's A/B gave 48 % (bill OFF) vs 33-49 % (bill ON).
- **HOT recovery rule (WK-95e):** bot-only. The CPU self-KO'd 2 of its 22 deaths. HumanSim3 never supers to recover; its recover
  mode only boosts.
- **Recovery reach:** the human problem isn't reach, it's **zero fuel**. After any super, recovery reach is 0 px until the next
  contact.
- **Camera:** no evidence either way. The driver is camera-blind and the owner rules fix the camera, so it is not a lever. The rendered
  check (§8.6) reports the opening frame's body size after R1, because spreading spawns widens the opening zoom.
- **Interstitials:** 5.0 s per stage (37 % of the match), owner-ruled. They are not a lever, but the ladder dilutes them: at 12 s
  stages the share falls to about 29 %.

---

## 4. Candidates (each one OFF by default; one variable per rung)

The general rule for R2, R3 and R4: **BRAWL only** (a GameMode seam). Bots obey the same rules (INV-8). Each rung logs its own
mechanism counters in `round_stats`.

### 4.1 R1: Spawn spread (data only, MEADOW MILE)
**Fantasy:** BOUNCE! is a beat of "where is everyone?" before the first clash, not two goats on the same island at the edge.

**Rules** (the level-designer re-authors `player_spawn`; QA runs a static checker; failures are listed as named exceptions):

| ID | Rule | Rationale |
|---|---|---|
| S1 | Spawns 0 and 1 are on opposite halves of the arena and ≥ 1,500 px apart | the 2-player case, and the two seats humans fill first |
| S2 | Spawns 0-3 are pairwise ≥ 900 px apart, **or** ≥ 500 px with a platform blocking line of sight. No two of spawns 0-3 share an outer island | 900 ≈ max boost speed 800 × (1.3 s protect − 0.2 s reaction): no rival is reachable by flight before protection ends. A super needs line of sight |
| S3 | A spawn on an outer island is as far inboard as the island allows. Target ≥ 1,100 px from the side blast line (today 840-1,000) | ≈ one in-window super carry (1,130 px) |
| S4 | No spawn on a spring tile. A spawn sits over a platform with ≥ 80 px of head-room | a spring spawn launches 480 px at BOUNCE |
| S5 | The prefix property: spawns 0-1 and 0-2 each satisfy S1/S2 on their own | 2- and 3-player matches use only the prefix |
| S6 | `spawns[4+]`, if present, stays (unused at the 4-fighter cap). Sudden-death `center_spawns` is unchanged | |

- **OFF value:** today's JSON. The variant lives only in the QA scratch copy until it is adopted.
- **Edge cases:**
  - Daisy Ring is radial. Apply S2 by Euclidean distance.
  - Meadow Spine and High Pasture may not fit 4 × 900 px. Use the LOS clause or list an exception.
  - Opening camera framing gets wider (owner rule: fit everyone). The rendered check reports this.
- **Not this rung:** shuffling which seat gets which spawn each stage (fairness/variety). That's a possible follow-up; it doesn't
  change the totals.

### 4.2 R2: Spawn truce
**Fantasy:** the blink means "nobody can be hurt yet, and that includes by you". Today a newcomer mashes super at GO and throws away a
full tank on a move that *cannot* connect.

**Mechanic:**
- While a goat's `_spawn_protect > 0` (the same blink everyone sees, 1.3 s), a super press does **not** enter AIM.
- The aim arrow shows locked (greyed, with a small padlock glyph) and a soft dry click plays.
- Normal boost, drift and pre-aim work as usual.
- **A press during the lock is dropped, not buffered.** A fresh press is needed after unlock, so four supers don't all fire on the
  1.3 s frame.

**Knob:** `Tuning.brawl_spawn_super_lock: bool = false` (test: `true`).

**Edge cases:**
- Multi-life respawns use the same rule. That's symmetric: protected goats can't be hit either.
- Sudden-death spawns follow whatever protection SD applies.
- Ghosts are not players, so it doesn't apply to them.
- Sports kickoff is excluded (WK-131 owns kickoff). Trials is excluded.
- Bots already avoid protected targets (WK-127). The lock just makes that universal.

**Why it isn't a camping/stall risk:** it lasts 1.3 s once per life, and you keep moving.

### 4.3 R3: Whiff brake
**Fantasy:**
- The super is a **lunge with a reach**: about 1,130 px of lethal travel inside its window.
- If it hits nothing, the jet sputters out and you are back in flight range, where your stick and boost matter.
- Near an edge you can still rocket yourself off (the comedy stays). From mid-stage you no longer cross the whole map.
- This also serves the owner ruling: a super that's poor at travel is "the attack, not the way to get around".

**Mechanic.** When the `super_active_time` window (0.45 s) ends, check three conditions:
1. The super made **no player contact** (no smash branch ran, including contacts with protected / Star / Counter targets).
2. It made **no surface contact** since firing.
3. The goat is not in hitstun, not dead, not `fuel_locked` (Unlimited Boost), and not black-hole-pulled.

If all three hold, reduce `|v|` toward `super_whiff_brake_speed` over `super_whiff_brake_time`, keeping its direction.
- It never adds speed and never reverses direction.
- Below the target speed it does nothing.

**Knobs:**
- `super_whiff_brake_speed: float = 0.0` (OFF; test value **700**)
- `super_whiff_brake_time: float = 0.15`

**Why these numbers:**
- **700 px/s** is just under `normal_boost_max_speed` 800. That puts the goat inside the WK-95 grip band (≤ 1,300 px/s), so any fuel
  it has steers immediately. Today the post-whiff speed is about 2,200 px/s, above the grip cap, so flight can't steer. 700 is still
  well above `air_drift_max_speed` 340, so it doesn't read as hitting a wall.
- **0.15 s** is one readable beat, in the FEEL §5.1 hitstop-recover family (0.12 s).
- **Estimated total whiff carry:** about 1,130 + 220 + 190 ≈ **1,540 px**, down from about 3,000. That still meets FEEL §3.3
  ("a full super from mid-stage should travel > half the 1920 width").

**Readability:** a sputter puff of 2-3 smoke pops at the nozzle, the exhaust cut, a short "pfft" SFX and a small squash. It must
read as "the jet ran out", never as an invisible wall. This is required before adoption; it is not required for the headless batch.

**Edge cases:**
- A downward super into a bounce surface (GDD ground-slam) counts as surface contact, so it is not braked. The bounce launch is
  sacred.
- A super that ricochets off a bumper inside the window is not braked.
- An up-whiff gets braked too. Top margin 2,650 makes that safe either way.
- Super-vs-super clash: the loser is in hitstun, so not braked. The winner connected, so not braked.

### 4.4 R4: Fumble reserve
**Fantasy:** you missed, you're scared, and you have exactly one brake's worth of fuel to fight your way back. That's the recovery
gamble GDD §4.6 wants, now available to the shooter too.

**Mechanic:**
- On fire, the tank still drains to 0 (drain-all identity). The launch is still constant 2800.
- When the 0.45 s window ends with **no `smash_landed`**, the goat receives
  `reserve = min(super_whiff_reserve, fuel_at_fire)`.
  - A contact on a protected / Star / Counter target is not a landed smash, so it **does** pay the reserve.
- **Re-arm gate:** after a reserve is granted, super cannot be armed until the goat's next paying contact (a bounce or bumper refund).
  - A press shows the dry click and a padlock, as in R2.
  - Boost works normally.
- **No reserve** if, during the window, the goat:
  - made a paying contact;
  - was in hitstun;
  - died;
  - was `fuel_locked`.
- The HUD gauge and the off-screen bubble show the reserve as a differently-tinted sliver until it is spent or a bounce merges it.

**Knob:** `super_whiff_reserve: float = 0.0` (OFF; test value **15**). The gate is active whenever the knob is above 0.

**Why 15:**
- 15 fuel = 0.525 s of thrust (drain 28.57/s). At 5,400 px/s² that is Δv ≈ 2,835 px/s, which just matches one super impulse (2,800).
- It is < `fuel_per_bounce` 20, so a bounce is always worth more.
- It is ≥ `super_boost_min_fuel` 10, so the re-arm gate is **required**. Without it, a 100-fuel whiff followed by a 15-fuel second
  super would make super-chaining a way to travel (WK-95 violation).
- `min(…, fuel_at_fire)` closes the fumes-taxi. Firing at 10 can never return more than 10.

**Pushback recorded:** CD3's wording ("the super leaves 15 fuel when it hits nothing") would have had both holes, the net-positive
whiff at 10 fuel and the double super. This rung is the corrected form.

**Edge cases:**
- WK-128: the first light after a super is free (R1 reset). The reserve doesn't touch bill constants.
- If the goat is smashed after receiving a reserve, sting drains it as usual.
- New invariant to record in Tuning: `super_whiff_reserve` < `fuel_per_bounce`. If `super_whiff_reserve` ≥ `super_boost_min_fuel`,
  the re-arm gate must be on.
- Coordination: lane conflict with CD3-04 and WK-135 (the same fuel ledger in `Player.gd`). Build R4 after CD3-04, or on the same
  build as the baseline (§8.2).

### 4.5 R5 (conditional): side runway to 720 px
**Run only if** the stack of kept R1-R4 misses T1 or T2.

**Change:** on MEADOW MILE `void_is_floor` arenas, set the explicit `bounds.left` / `right` so that
side runway = max(current, **720**) px. That is today's `bounds_side_max`, the documented ceiling ("walkable outer edge stays inside
the Lv0 band").
- Going beyond 720 would break that doctrine.
- It would also quietly offset the owner's +25 % knockback for side kills. The launch distance would feel the same, but victims would
  survive more often. So it is capped, and the director logs it as a lethality-feed change under ruling (c).
- Top and bottom margins are unchanged.
- `camera_bounds` is unchanged (it comes from platforms). The off-screen bubble time is guardrail G7.

**Prediction:** small (§5.4).

### 4.6 R6 (conditional): catch shelves (geometry, worst arenas only)
**Run only if** the stack still misses T1 or T2, and only on the ≤ 5 worst arenas by the baseline scorecard. Expected: Hill and Dale,
Islands Void, The Cliff, Two Hills, Twin Chasms.

**Shape:** one narrow **marshmallow** shelf per inner gap.

| Property | Value |
|---|---|
| Width | ≤ 35 % of the gap (≤ 200 px for a 580 gap) |
| Top | 380-450 px below the lower neighbouring island top. A marshmallow bounce (apex 120) peaks ≥ 260 px below the island, so **flight is still required** to get back (GAME_ESSENCE per-gap check) |
| Height above the void rim | ≥ 250 px |
| Art | a distinct "rescue pad", so it reads as a bounce and not as void art (pillar 5) |

- A falling goat that hits a shelf gets +20 fuel and claws back. That's the fantasy's RECOVER verb.
- Spiked victims can catch too. That is accepted.
- The level-designer owns it. It has to pass the movement-tool-per-gap analysis and stay inside the existing `camera_bounds`.
  Otherwise it widens the frame, and that would need a camera note.

### 4.7 Considered and parked
- **Recovery assist / "second wind" for newcomers:** parked.
  - It is an invisible rule, which is a readability cost.
  - It protects careless play.
  - It blurs the victim triad.
  - As an opt-in handicap it can't fix the default naive group that CD3-01 is about.
  - A visible Smash-style handicap in RULES is a later feature, not a pacing fix.
- **Raising `fuel_per_bounce` or lowering `super_boost_min_fuel`:** the WK-95 invariant forbids it.
- **Reordering the circuit:** not useful, since 19/20 arenas share the void kill shape.
- **Bot changes:** out of scope. A note goes to the bot lane: `SUPER_CARRY` 720 vs about 3,000 real (or about 1,540 with R3).

---

## 5. The ladder: procedure and pre-registered decision rules

### 5.1 Phase 1: singles
Run each of R1-R4 **alone**, 80 stages with HumanSim3, against the same HumanSim3 baseline B0. Rows are evaluated in order; the first
row that matches wins.

| Row | Condition | Ruling |
|---|---|---|
| 0 | Mechanism check (§6.2) failed, **or** < 150 human deaths in either arm | **Inconclusive.** Fix the toggle and rerun once. If it is still inconclusive, DROP |
| 1 | Any guardrail G1-G8 or G11 fails (§7) | **DROP** (harm) |
| 2 | Δ self-KO share ≤ −5 pp **or** Δ median stage ≥ +1.0 s, and neither moves the wrong way (self-KO > +3 pp, median < −0.5 s) | **KEEP** |
| 2a | R1 only: headline misses row 2, but opening (< 3 s) human self-KOs drop ≥ 30 % (relative) and the static checker passes | **KEEP** (data, zero semantics) |
| 3 | Otherwise | **DROP.** No semantics without an effect |

### 5.2 Phase 2: stacks
- Build S_k from the KEEP rungs, always in priority order (R1 → R2 → R3 → R4).
- Run the two most likely stacks side by side, 120 stages with HumanSim3 each.
- **Adopt the smallest S_k** that meets T1-T6 with HumanSim3 **and** T7 with the newcomer driver.

Then:
- **Over-fix guard:** if a stack drives self-KO below 12 % or the median above 20 s, drop the last-added rung.
- **No stack meets the targets:** adopt the best guardrail-clean stack. Run R5, then R6 on top (the conditional slot). If it still
  fails, report to the Director with the per-arena scorecard. That routes to WK-57 and a level-designer geometry pass.
- **Driver disagreement:** if HumanSim-newcomer disagrees in sign with HumanSim3 on a rung's effect, that rung is a driver artefact.
  It is not adopted on HumanSim3 evidence alone.

### 5.3 Targets (the WK-20d Accept line, on the adopted stack)

| ID | Target | Baseline (CD3) |
|---|---|---|
| T1 | Median stage **≥ 12.0 s**, bootstrap CI lower bound ≥ 10.5, and median ≤ 20 s | 8.4 s |
| T2 | Human self-KO share **≤ 25 %** and ≥ 12 % | 48 % pooled |
| T3 | First-death median **≥ 4.0 s** | 2.8 s |
| T4 | Credited KO per combat-minute **≥ 9.5** | 11.8 |
| T5 | Super share of credited KOs **60-85 %** | 70 % |
| T6 | Stages under 5 s **≤ 6 %** | 15 % |
| T7 | HumanSim-newcomer (WK-20a driver) on the same stack vs its own baseline: Δ self-KO ≤ −5 pp **and** Δ median ≥ +1 s | – |
| T8 | First-to-10 replay (Ra, 5.0 s interstitial): mean match length 2.5-5.0 min game time | ≈ 2.9 min |

### 5.4 Pre-registered predictions (written before any data)

| ID | Prediction |
|---|---|
| P0 | **Headless baseline B0 (HumanSim3)** lands inside the calibration band: median 6.5-10.5 s, self-KO 35-55 %, first death 2.0-3.5 s, credited KO/min 9.5-14, super share 60-80 %. If it lands outside, report it and continue; comparisons are relative |
| P1 | **R1:** self-KO −4 to −8 pp. First death +0.6 to +1.5 s. Median +0.5 to +1.5 s. Side-edge self-KOs −50 % |
| P2 | **R2:** human supers before 1.3 s → 0. Self-KO −6 to −12 pp. First death +0.5 to +1.5 s. Median +0.8 to +2.0 s |
| P3 | **R3:** self-KO −5 to −10 pp (it shifts some side deaths into void deaths, so it is sub-additive). Median +0.8 to +2.0 s. Super share ±5 pp |
| P4 | **R4:** "dry fall" bucket −40 to −60 %. Self-KO −5 to −10 pp. Median +1.0 to +2.0 s. Supers per alive-minute −0 to −10 % (re-arm gate) |
| P5 | **R5:** self-KO −1 to −4 pp. Side credited KOs −5 to −15 %. Median +0.3 to +1.0 s |
| P6 | **Stacks** (the rungs target overlapping deaths, so they're sub-additive): S(R1-R3) self-KO 24-33 %, median 10-12.5 s. S(R1-R4) self-KO 18-28 %, median 11-14 s |
| P7 | Credited KO/min stays 9.5-13 in every arm. Fewer self-falls means more players alive for the super to hit |
| **Predicted ruling** | Adopt **R1 + R2 + R3 + R4** (≈ 40 %), **R1-R3** (≈ 30 %), or the conditional R5/R6 is needed (≈ 30 %) |

---

## 6. Metrics and mechanism checks

### 6.1 Metrics
All are computed per arm. CIs: Wilson for proportions, bootstrap for medians and differences.

| ID | Metric | Definition |
|---|---|---|
| M1 | Stage length | median `length_s`; Δ vs baseline with a bootstrap CI; share < 5 s; p90 |
| M2 | **Human self-KO share** | human deaths with killer = −1 (not haunted) / human deaths |
| M3 | First death | median `t` of the first death per stage |
| M4 | Credited KO / combat-minute | credited kills / Σ `length_s` |
| M5 | Super share | credited kills whose killing smash was `by_super` / credited kills |
| M6 | Self-KO cause mix | §3.2 buckets: whiff-carry ≤ 1.5 s / trade (after a landed super) ≤ 1.5 s / dry fall 1.5-4.5 s / no super. Also an opening flag (< 3 s) and the edge (side / void / bottom / pit) |
| M7 | Fuel at death | human self-KOs: share < 5 fuel |
| M8 | Supers | human supers per alive-minute (also with t ≥ 1.3 s only, for R2); landing rate; supers fired while every rival is protected |
| M9 | **Claw-backs** (RECOVER) | a human goat leaves the walkable footprint (outside the stage x-span, or below the lowest island top over a void x) and later makes a paying contact without dying. Count per human alive-minute |
| M10 | Fantasy fit | humans airborne share and boosting share of alive time |
| M11 | Off-screen time | share of human alive time shown as an off-screen bubble |
| M12 | CPU | self-KO share, credited KOs/stage, share of supers tagged TRAVERSAL, `motion_health` (stuck, underside, blocked) |
| M13 | WK-128 | billed-relight sputters per 100 boost presses (CD3: 7.7) |
| M14 | Victim recovery | A4-style: human victims of a Lv0 non-edge smash with fuel ≥ 20 who survive 4 s without a rehit (the triad guard) |
| M15 | Scorecard | per-arena median length and self-KO share (pooled baseline arms for ranking) |
| M16 | Match replay | WK-20a `wk20a_replay.py` (Ra rule, end at the winning kill, 10,000 bootstraps): stages per match and match minutes at 5.0 s per interstitial |
| M17 | Arena subsets | M1-M5 on all 20 arenas (primary, balanced) **and** on circuit arenas 1-13 (what a first-to-10 group actually sees) |

### 6.2 Mechanism checks (run after the first 20 stages of each arm; abort and fix if any fail)
- **R1:**
  - The static checker passes S1-S5 on all 20 JSONs, or has named exceptions.
  - Measured minimum pairwise distance at BOUNCE is ≥ 700 px in ≥ 95 % of stages.
- **R2:**
  - 0 supers fired with the shooter's `_spawn_protect > 0`.
  - The locked-press counter is > 0 (the drivers do press).
  - 0 supers fired within 0.05 s of unlock without a fresh press.
- **R3:**
  - ≥ 95 % of qualifying whiffs reach ≤ 750 px/s within 0.20 s after the window ends.
  - 0 braked supers that had a player or surface contact.
  - 0 brake events outside BRAWL.
- **R4:**
  - Reserves granted equal qualifying whiffs.
  - The reserve is ≤ `fuel_at_fire` in 100 % of grants.
  - 0 supers armed between a grant and the next paying contact.
- **R5:**
  - Bounds in the copy match the intended values.
  - The `camera_bounds` hash is unchanged.
- **R6:** the GAME_ESSENCE per-gap analysis is attached for every added shelf. No route works by bouncing alone.

---

## 7. Guardrails (must not regress; G1-G8 and G11 are row-1 DROP triggers for singles and stacks)

| ID | Guardrail | Bar |
|---|---|---|
| G1 | Credited KO / combat-minute | ≥ 0.8 × baseline |
| G2 | Super stays the kill | super share ≥ 60 % and ≥ baseline − 8 pp |
| G3 | Super stays the verb | human supers per alive-minute ≥ 0.8 × baseline (R2: count only t ≥ 1.3 s) |
| G4 | Fantasy fit | humans airborne ≥ 95 % of alive time; boosting share ≥ baseline − 3 pp; claw-backs (M9) ≥ baseline − 10 % |
| G5 | No stalls | p90 stage ≤ 30 s; no stage > 60 s; SD rate ≤ 15 % |
| G6 | **Bot behaviour** (CPU seat in every arm, plus the 4-bot arm on the adopted stack vs WK-20a's 4-bot numbers) | bot self-KO share ≤ baseline + 5 pp; CPU credited KOs/stage within ±30 %; bot supers tagged TRAVERSAL ≤ 10 % (WK-95e); `motion_health` stuck / underside / blocked ≤ 1.2 × baseline |
| G7 | Camera / readability | off-screen bubble share ≤ baseline + 3 pp (R1, R5, R6) |
| G8 | **WK-128 numbers** | sputters per 100 presses ≤ baseline (CD3: 7.7). No `boost_relight_*` constant differs from HEAD (diff hash) |
| G9 | **Sports byte-identical** | with all knobs ON, a headless 6-goal Rocketball smoke logs 0 lock / brake / reserve events, and goals/min sit inside CD3's range. Plus a static check that every new rule sits behind the BRAWL gate |
| G10 | **Flight School unchanged** | with all knobs ON, 0 events in Trials. SuperPilot: lesson 2 at 35 % → HOME; lesson 3 at 15 % → HOME and at 60 % → fails (663 ± 100 px short). TapPilot: lesson 1 hold arrives in 1.65 ± 0.05 s with 53-54 fuel |
| G11 | Victim triad | M14 within ±8 pp of baseline (no candidate may help a hit victim) |
| G12 | Ghosts (info) | haunted KOs stay 0; puff saves are logged |

---

## 8. Measurement plan

### 8.1 Machine cap and timing
- **One headless batch**, at most **2 Godot processes at a time** (two lanes). Nothing else Godot runs during it.
- **Game time only.** The GPU is in software-rendering mode, so:
  - no wall-clock, fps or perf number goes in any result;
  - all durations come from `round_stats.length_s`, `round_clock` and `phase_log.tick_s`;
  - headless at `--fixed-fps 120`, as WK-20a did.
- Wall time is not a deliverable. WK-20a ran about 4× real time, so plan on very roughly 30-45 min of wall time for both lanes.

### 8.2 Build and copies
- **Build:** one gameplay build for every arm. It must contain the R2-R4 knobs (OFF by default) and their counters.
- **Record:**
  - `git rev-parse HEAD`;
  - the SHA-1 of `git diff src/core/Tuning.gd` before and after (must match: nothing persisted);
  - whether CD3-04 is in the build.
- **If CD3-04 or WK-135 lands mid-batch:** stop and re-baseline.
- **Scratch copies:** run each lane from its own scratchpad copy of the project, with the `McpInteractionServer` autoload removed so
  no port is bound (WK-20a method).
  - R1, R5 and R6 JSON variants exist **only** in the copy.
  - Drivers and recorder go in as `.txt` under `tools/out/wk/` (never `.gd` there).
- **Setup per run** (WK-20a §3, adapted):
  - `GameConfig.match_config`: `human_count = 3`, `bot_count = 1`, MIX → CPU **L2** (verify), `kills_to_win = 999`,
    `lives_per_player = 1`;
  - circuit = **meadow_mile**, ordered, looping;
  - ghosts ON, powerups at defaults;
  - scoreboard skip (`_score_skip`), which is game-neutral.
- **Each 80-stage arm = 4 runs × 20 stages** (one full circuit loop each, 4 seeds), so every arena appears exactly 4 times. Relaunch
  between runs.
- Install drivers and recorder before the first BOUNCE, otherwise discard stage 1.

### 8.3 Drivers
- **Primary: HumanSim3** (`tools/out/cd3/HumanSim3.gd.txt`), seats 0-2 = pad 1, pad 0, keyboard (8-way aim).
  - First try it unmodified, with synthetic device events and `human_device_keys` set.
  - If device events don't route in headless, wrap the identical `_plan` logic as a provider ("HumanSim3P"), keeping the 0.14-0.30 s
    re-plan, the noise, and seat 2's 8-way quantisation. P0's calibration band then decides whether the wrap is faithful.
- **Cross-check: WK-20a HumanSim-newcomer** (`tools/out/wk/wk20a_humansim.txt`, round-2 preset D 0.43, λ 0.25). It has an opening
  idle and a notice delay, so it tests whether an effect survives a different human model. It runs on B0' and on the adopted stack.
- **TapPilot / SuperPilot:** Flight School guardrail G10 only.

### 8.4 Schedule (lane 1 ‖ lane 2)

| Slot | Lane 1 | Lane 2 | Stages |
|---|---|---|---|
| 0 | Analysis-script sanity: reproduce §3 from `cd3/m1`, `m2`, `m3off` (27 decomposed; buckets 16 / 6 / 5; pooled 50/105). No Godot | – | 0 |
| 1 | **B0** baseline, HumanSim3 | **B0'** baseline, HumanSim-newcomer | 80 + 80 |
| 2 | **R1** spawn spread | **R2** truce | 80 + 80 |
| 3 | **R3** whiff brake | **R4** fumble reserve | 80 + 80 |
| 4 | Stack **S_a** (the smaller likely stack, e.g. R1-R3 keepers) | Stack **S_b** (all keepers) | 120 + 120 |
| 5 | Adopted stack, HumanSim-newcomer (T7) | Adopted stack, **4 bots** L2/L3/L3/L4 (G6) | 80 + 40 |
| 6 | B0 repeat, HumanSim3 (drift check) | G9 sports smoke (1 match to 6) + G10 Flight School lessons 1-3 | 40 + smokes |
| 7 *(conditional)* | adopted + **R5** | adopted + **R6** (worst ≤ 5 arenas × 12 stages) | 80 + 60 |

- **Core:** ≈ 880 stages ≈ 176 min game time.
- **Hard cap:** 1,050 stages / 210 min game time.
- **Cut order if over:** slot 7 first, then the slot 6 drift check, then trim slot 4 to 100 + 100.
- **Drift rule:** if the slot-6 B0 repeat differs from B0 by > 6 pp self-KO or > 1.5 s median, flag the session; every Δ is then
  reported against both baselines.

### 8.5 Restore and exit
- Every knob is restored to OFF after each run and at exit.
- Re-hash `Tuning.gd` after the batch; it must match the pre-batch hash.
- Every process stops by its own exit. Stray Godot processes are killed before the rendered check.

### 8.6 After the batch: one rendered motion check (single process, not concurrent with anything)
- **Recording:** a WK-93 Movie Maker recording of 20 s of combat on the adopted stack, with HumanSim3, on **Clover Steps** (opening
  spread and truce) and **Islands Void** (whiff brake and reserve).
  - Movie Maker writes fixed-fps frames, so game time is valid under software rendering. No perf claims.
- **Look at the frames.** Report each of these in one line:
  1. Does the whiff sputter read as "the jet ran out", not as a wall?
  2. Are the padlock / dry-click and the reserve sliver readable at couch scale?
  3. What is the opening frame's smallest goat body, in px, with spread spawns?
  4. Do goats still read as flustered players, not frozen ones?
- This is evidence for the adoption decision. It is not the build sign-off; QA's normal rendered pass still applies.

### 8.7 Deliverables (QA)
- `tools/out/wk/WK-20d_measure.json`:
  - `meta`: head, Tuning hashes, CD3-04 flag, game minutes;
  - `sanity`: the §3 reproduction;
  - `arms`: {B0, B0', R1-R4, S_a, S_b, …}, each with M1-M17, CIs, n, mechanism checks and guardrails;
  - `rows`: the §5.1 / §5.2 traces;
  - `targets`: T1-T8 for the adopted stack;
  - `predictions_hit`: P0-P7.
- Raw per-stage logs `wk20d_raw_<arm>.json`, the static spawn-checker output, the per-arena scorecard, and the rendered contact
  sheets.

---

## 9. Success criteria for this protocol (QA-verifiable)
1. Slot 0 reproduces §3 exactly: 27 decomposed human self-KOs with buckets 16 / 6 / 5, and pooled 50/105.
2. Every arm has ≥ 150 human deaths, or carries an explicit "n/a + reason". Every metric has n and a CI.
3. Every arm's mechanism checks (§6.2) pass, and their numbers are in the JSON.
4. The `Tuning.gd` diff hash is identical before and after. The R1/R5/R6 JSON changes exist only in the scratch copies.
5. No more than 2 Godot processes ran at once, and total game time ≤ 210 min is recorded in `meta`.
6. The rendered check (§8.6) was captured and looked at, with its four one-line answers.
7. The designer can apply the §5 tables without asking for another number. If they can't, the protocol failed, not QA.

## 10. Routing, sequencing and open questions
- **Before the batch:**
  - gameplay-programmer builds the R2/R3/R4 knobs (OFF), the BRAWL gate and the counters;
  - level-designer authors the R1 JSON variants in a scratch copy, with the static-checker result.
  - VFX/SFX for the sputter, padlock and sliver are **required before adoption**, not before measurement.
- **After the ruling:**
  - the Director writes a DECISIONS entry per adopted rung, with a reopen condition. Proposed: "reopen if a cold playthrough shows
    human self-KO > 35 % or median stage < 9 s on MEADOW MILE, or players read the sputter / padlock as a bug".
  - R1 JSON is committed by the level-designer.
  - New invariants are recorded in `Tuning.gd` (§4.4).
- **Open, for the Director:**
  1. **Should R3/R4 later extend to Sports?** Sports is excluded here to protect the showcase. Revisit only with sports-lane data.
  2. **Flight School consistency.** Lesson 2 teaches the super as a distance tool, and that sits uneasily with WK-95's "super = attack".
     If R3 is adopted, a whiffed Brawl super will travel less far than in Flight School. That's acceptable for now: Flight School is
     solo and teaches aim and commitment. It should be noted for the next Flight School pass.
  3. **R5 is a lethality-feed change** under weekend ruling (c). Log it only if it is adopted.
- **Lane conflicts:** R4 shares the fuel ledger with CD3-04 and WK-135, and R2/R3 sit in `Player.gd`'s super path. Serialize with
  those lanes.
- **Bot-lane note (no change here):** `InputBot.SUPER_CARRY` (720) underestimates whiff carry about 4×. Re-derive it if R3 ships.

## Sources
- CD3 audit and data: `docs/audit/2026-11-15_cd3_playthrough.md`; `tools/out/cd3/m1|m2|m3off/stats.json` (kills, supers, stage
  records); `tools/out/cd3/HumanSim3.gd.txt`.
- WK-20a protocol and results: `docs/specs/wk20a_measurement_2026-11-14.md`, `docs/audit/2026-11-14_wk20a_results.md`.
- Feel numbers: `docs/reference/FEEL_REFERENCE.md` §3.3 (super self-destruct math), §5.1 (beat lengths); `src/core/Tuning.gd`
  (gravity 1600, drift 1300 / 340, boost 5400 / 800, grip ≤ 1300, super 2800 / 0.45 s, drain 28.57/s, bounds doctrine L418-435).
- Design: `docs/reference/GAME_DESIGN.md` §3 (10-30 s rounds), §4.2 / §4.6 (super gamble, recovery triad), §7 (early circuits tame);
  `docs/GAME_ESSENCE.md` (core verbs, per-gap flight rule); DECISIONS 2026-07-19, 2026-11-14 (WK-95, WK-95e, WK-20a, autonomy),
  2026-11-15 (WK-128).

---

## 11. ADDENDUM 2026-11-15: per-arena-class targets, R5 / R6 status, and the post-CD4-01 measurement

**Written after:** the R1-R4 batch (`docs/audit/2026-11-15_wk20d_r1.md`, ruling e09d727: R2 adopted, the rest not), WK-20e 4282309
(truce shipped), WK-CD4 (`docs/audit/2026-11-15_cd4_playthrough.md`, CD4-01 / CD4-03) and BACKLOG re-rank #9 (WK-20d is now P2, with
a mis-scope flag on T1).
**Data re-read:** `tools/out/wk/WK-20d_R1_summary.json` (per-arena scorecards, pooled B0b and R2 arms, 8 stages per arena) ·
`tools/out/wk/CD4_data/m1.json`, `m2_trim.json` (per-stage `length_s`, 25 stages in circuit order) · the 20 MEADOW MILE level JSONs
(platforms, gaps, hazards).
**Still in force:** §1 fantasy, §2 constraints, §6 metrics, §7 guardrails (as amended in §11.6). **Do not touch the spawn truce.**

### 11.1 Why T1 is retired
- **It measures the mix, not the design.** One overall median blends wide-deck openers, void archipelagos and gimmick arenas. Once
  CD4-01 changes which arenas a session plays (start rotation or shuffled bag), the overall median moves even if no arena changes.
- **12 s has no anchor.** VISION and GDD §3 set the round band at **10-30 s** ("Duck Game runs ~8-10 s; ours may run slightly
  longer"). The headless baseline already sits at 11.2 s (B0b), and R2 at 11.8 s.
- **It aims at the wrong feeling.** No couch can feel 10.7 s vs 12 s. What CD4-03 describes is the **short tail on void arenas**:
  stages of 5-6 s, where "launched → claw back → smash" has no room. So the new targets are by class, and they include a tail line.
- **Per-arena numbers are noise at n = 8.** The same arena, two arms of the same build family: Hill and Dale 4.89 s (B0b) vs 24.46 s
  (R2); Grassy Expanse 13.6 vs 18.6 s. **Targets are set per class, pooled.** Any per-arena ranking needs n ≥ 12 (§11.8).

### 11.2 Arena classes (a data rule, so WK-57's scorecard can compute it for any circuit)
**Definitions:**
- *Floor decks* = bounce platforms whose top is within 250 px of the lowest platform top. Spring and bubblegum shoulders above that
  row don't count.
- *Coverage* = the union of floor-deck x-extents divided by the walkable span (min to max x of the floor decks).
- *Inner lethal gap* = a gap between floor decks with a lethal void or pit below.

| Class | Rule | MEADOW MILE members (coverage; inner gaps) |
|---|---|---|
| **G: grounded / wide-deck** | coverage ≥ 80 % **and** ≤ 1 inner lethal gap (or `kill_shape` central_pit / enclosed) | grassy_expanse (85 %; 1 pit), meadow_first_hop (84 %; 1), sunny_shoulders (84 %; 1) |
| **H: hazard / gimmick** | any `moving_hazard`, `moving_platform`, lethal hazard object, or a bumper-tier feature | windmill_meadow (pendulum), hay_bales (4 bumpers), high_pasture (bumper side walls, vertical), meadow_carousel (moving cart) |
| **V: void archipelago** | everything else | islands_void (69 %; 3), the_cliff (66 %; 3), twin_chasms (71 %; 2), clover_steps (69 %; 2), three_meadows (70 %; 2), daisy_ring (ring), long_meadow (65 %; 4), hill_and_dale (62 %; 3 + height steps), bluff_line (72 %; 2), two_hills (69 %; 2), meadow_spine (59 %; 2), stepping_bloom (60 %; 4), river_split (74 %; 2) |

- In other circuits: THE SCRAPWORKS, THE FOUNDRY and MAYHEM MILE are mostly H. THE HIGH WIRE is mostly V.
- These targets are measured on MEADOW MILE only. Applying them to other circuits is WK-57's job.

### 11.3 Evidence by class (what we have now)
- Headless class values are the **median of the per-arena medians** (8 stages per arena), so they are an approximation. Phase A
  recomputes them from per-stage logs.
- CD4 values are per-stage (HumanSim4, rendered).

| Class | Headless B0b (no truce) | **Headless R2 (truce; current build family)** | CD4 rendered (truce) |
|---|---|---|---|
| G (3) | 13.6 s (10.8-19.1) | **15.1 s** (14.9-18.6) | 17.8 s (n 5; 1 under 6 s: Sunny Shoulders 4.6) |
| V (13) | 11.1 s (4.9-14.3) | **10.7 s** (7.8-24.5) | 9.4 s (n 20; **4/20 = 20 % under 6 s**, 8/20 ≤ 6.3 s) |
| H (4) | 10.0 s (8.9-12.3) | **14.3 s** (10.8-15.4) | none played: CD4-01 (the fixed order never reaches arenas 15-20) |

**Three readings:**
1. **The class split is real, but smaller than CD4 made it look.** G runs about 15-18 s and V about 9.5-11 s. Both sit inside or at
   the floor of the GDD band.
2. **CD4's bimodality follows circuit position more than arena class.**
   - Islands Void, The Cliff and Twin Chasms are V-class. In CD4 they ran **14.3-17.6 s** as stages 2-4, against 8.7-10.5 s headless
     (R2).
   - The CD4 back half (stages 6-13) was nearly all V, and ran 4.5-14 s.
   - So something position-dependent or rig-dependent is mixed in. Hypotheses:
     - the CD's screenshot bursts are concentrated in the first stages, and the driver's timing may run on frames, not game time;
     - score-state effects (for example, the ghost hush at match point);
     - n = 2 per arena.
   - **Don't design geometry against an effect that may be an artefact.** CD4-01 decorrelates position from arena, so the post-CD4-01
     run can separate the two (§11.8, Phase A lane 2).
3. **Where the deaths are now.** With the truce shipped, side self-KOs are almost gone:
   - R2 primary half: 2 side vs 34 void, of 36 human self-KOs;
   - CD4: 0 side of 13 (void 8, bottom 4, top 1).

   The remaining problem is the **void floor**, on V arenas.

### 11.4 New targets (they replace T1; T2-T8 stand, with the §11.6 fixes)
Measured headless, 3 × HumanSim4 + CPU L2, game time, on the build after WK-153 (and WK-135 p3, if landed). Pooled per class.

| ID | Scope | Target | Why |
|---|---|---|---|
| **T1-G** | G arenas | median 12-25 s; p90 ≤ 40 s; no stage > 60 s | Inside the GDD band. Wide decks are the careful openers. Over 40 s reads as a stall (CD4: Grassy Expanse 39.4 s) |
| **T1-V** | V arenas | median **≥ 10.0 s** (bootstrap CI lower bound ≥ 9.0) **and** stages **< 6 s ≤ 15 %** **and** claw-backs (M9) **≥ 3.0** per human alive-minute | 10 s is the GDD floor. Under 6 s is the stage where the fantasy arc has no room (CD4-03). 3.0 ≈ R2's 3.10, so RECOVER must not get rarer |
| **T1-H** | H arenas | median 10-25 s. Hazard-caused share of deaths is reported (info) | first real data, once CD4-01 lets sessions reach them |
| **T1-S** | session (real match flow with CD4-01, first-to-10) | stage median ≥ 10 s; no run of 3 or more consecutive stages under 6 s in more than 1 match in 8; mean match length 2.5-5.0 min (T8) | what a couch actually lives through |

- **Info, not a target:** interstitial share at 4.8 s per stage (owner-ruled screen). Report it per session.
- **Rendered sanity check, at WK-CD5:** V median ≥ 8.5 s and < 6 s ≤ 25 % in rendered play. Rendered runs are harsher than headless:
  CD3 8.4 s vs B0 10.1 s, CD4 V 9.4 s vs R2 V 10.7 s. A rendered miss with a headless pass sends the **rendered-vs-headless gap** to
  QA as its own item. It does not trigger geometry.

### 11.5 Rulings on R5 and R6

**R5 (side runway to 720 px): WON'T DO.**
- **The thing it could fix is gone.** R5's target was marginal side self-KOs. After the truce they are 2 of 36 (R2) and 0 of 13
  (CD4). R1 already showed that pushing deaths away from the side edges just moves them into the voids.
- **What is left for R5 to change is credited side ring-outs.** Blunting those weakens the super's kills, which is the owner's +25 %
  knockback feed under ruling (c). It also cuts against the fantasy ("smash rivals off the screen"). Wrong direction.
- **Reopen only if** Phase A shows side-edge deaths at ≥ 25 % of human deaths on V arenas.

**R6 (catch shelves): NOT warranted by default. Held as a pre-registered conditional: V arenas only, at most 4 of them, triggered only
by a Phase A miss on T1-V's tail or claw-back lines.**
- **Why R6 is the right conditional lever:**
  - The void floor is now where people die (R2: 34 of 36 self-KOs; CD4: 12 of 13 void or bottom).
  - RECOVER is the verb CD4-03 says rarely happens on V arenas, and a shelf is a direct claw-back opportunity.
  - It changes no rule and no constant.
- **Why not build it now:**
  - The headless V median (10.7 s) already sits at the GDD floor.
  - 8-stage-per-arena data cannot pick the arenas (Hill and Dale flips between 4.9 and 24.5 s).
  - CD4-01 changes what sessions see.
  - The CD4 position effect may be an artefact.
  - Every shelf has costs: it also catches smashed victims (a lethality feed), it extends `camera_bounds` downward, and it needs art
    that reads against the CD4-01 sky drop.
- **Arena selection rule (if triggered):**
  - The arena is in the bottom third of V by Phase A median (n ≥ 12 per arena), **and**
  - it carries a structural flag: ≥ 3 inner lethal gaps, or coverage < 65 %.
  - Pre-registered expected picks: **stepping_bloom, long_meadow, hill_and_dale, islands_void.** Alternate: the_cliff.
  - two_hills (the worst R2 median at 7.8 s) is **not** eligible structurally (2 gaps, 69 %). If it ranks bottom again, it goes to the
    level-designer as a separate note: its short stages likely come from the high-hill → low-centre super line, not the gaps.
- **Shelf spec amendments (on top of §4.6):**
  - **Fuel:** a shelf contact must pay fuel under the build's refund rules (WK-135 p3 refund gates; marshmallow pays about 13.3, not
    20 as §4.6 assumed) on ≥ 95 % of first contacts. Otherwise the shelf is a trampoline to death.
  - **Camera:**
    - A shelf whose top is 380-450 px below the island extends the platform-union bottom by about 300 px, so `camera_bounds` grows
      downward. On every expected pick, horizontal extent dominates: Islands Void is about 5,980 px wide vs about 1,490 × 16/9 ≈
      2,650 px tall. So the zoom-in cap (`cam_close_fraction`) is unchanged.
    - The only framing change is that a falling goat stays in frame lower down instead of turning into a bubble. For a recovery,
      that is the right change.
    - It is still the owner's camera area: before/after rendered stills per arena, and a DECISIONS camera note.
  - **Art:** a "rescue pad" in the platform language (glossy, outlined bounce surface). It must read as a bounce, not as sky or cloud
    art against the CD4-01 sky drop. Art-director grade before adoption.
  - **Flight:** the per-gap flight analysis is attached for each shelf. No island is reachable from a shelf by bouncing alone.
  - **No camping:** marshmallow always bounces. Shelf dwell (alive time within 150 px above a shelf) ≤ 3 %.

### 11.6 Protocol fixes carried in (from the R1-R4 audit, "For the designer" §5)
- **G2** uses only its relative part: super share ≥ baseline − 8 pp. The absolute 60 % bar failed in the baseline itself.
- **T5** is relative as well: super share ≥ baseline − 5 pp.
- **G8:** the WK-128 sputter meter is blind after WK-136. Replace it with "billed relights per 100 boost presses ≤ 1.1 × baseline",
  or drop it if no counter exists. G8 is info only for this addendum, because nothing here touches fuel constants.
- **P0** is re-calibrated to the headless baseline (§11.7 A1-A3 replace it).

### 11.7 Pre-registered predictions (written before any post-CD4-01 data)

**Phase A (measure only):**

| ID | Prediction |
|---|---|
| A1 | G median 13-19 s, p90 ≤ 40 s → **T1-G passes** |
| A2 | V median 10.0-11.5 s (median line passes); V under-6 s share 8-16 % (**borderline**); claw-backs 2.9-3.6 per alive-minute |
| A3 | H median 11-16 s → **T1-H passes**. Hazard deaths 10-30 % of deaths on windmill_meadow and meadow_carousel |
| A4 | Position effect: within class, stages 1-5 vs 6+ differ by < 2 s (CD4's bimodality was rig or noise). 60 % confidence |
| A5 | Session median under CD4-01 is 10.0-11.5 s. It is slightly *lower* than the fixed order would give, because sessions see fewer G arenas: 3 of 20 on average vs 3 of the first 13 |
| A6 | CD4-01 correctness: a fresh session opens on Grassy Expanse; REMATCH does not restart at arena 1; arenas 15-20 appear in sessions; no arena repeats within a match if it's a bag |
| **Ruling forecast** | WK-20d closes with no R6 (≈ 55 %); R6 on 2-4 arenas (≈ 35 %); V needs a geometry pass beyond shelves, routed to WK-57 (≈ 10 %) |

**Phase B (only if R6 runs), on each shelved arena vs its own same-session baseline:**

| ID | Prediction |
|---|---|
| B1 | median +1.5 to +3.5 s; under-6 s share −40 to −60 % (relative); claw-backs +20 to +40 % |
| B2 | credited KO/min −5 to −15 % (G1's ≥ 0.8 × holds); super share −0 to −5 pp |
| B3 | 0.5-1.5 shelf contacts per stage; shelf dwell ≤ 3 % of alive time |
| B4 | off-screen bubble share −1 to −3 pp (the camera now frames recoveries) |

### 11.8 Measurement plan (run AFTER WK-153 / CD4-01 commits; #5 in the headless queue)

**Preconditions:**
- WK-153 is committed (start rotation or shuffled bag, plus the void sky drop).
- Record HEAD and whether WK-135 p3 is in. If WK-135 p3, or any `Player.gd` / fuel change, lands mid-batch: stop and re-baseline.
- **The sky drop must be visual only.** For every arena WK-153 touched, QA diffs `bounds`, `platforms`, `kill_shape` and every
  non-prop `objects[]` entry against the pre-WK-153 blob. Any geometry difference is flagged before Phase A runs. (Example:
  `levels/islands_void.json` is modified in the working tree right now.)
- **The design works with either CD4-01 implementation.**
  - With a **bag**, position and arena decorrelate inside a match.
  - With a **rotating start**, they decorrelate across the REMATCH chain.
  - Lane 2 below logs both and analyses whichever applies.

**Rig** (the same as the R1-R4 batch unless stated):
- One headless batch, at most 2 processes.
- `git archive` scratch copies with the McpInteractionServer autoload removed, `--fixed-fps 120`, game time only.
- 3 × **HumanSim4** (`tools/out/wk/CD4_data/HumanSim4.gd.txt`, with the WK-20d SUDDEN_DEATH fix) + CPU L2.
- Ghosts ON, powerups at defaults, the truce ON (shipped). Nothing else changed.

**Phase A: measure only (about 440 stages, about 90-100 min of game time):**
- **Lane 1, forced arena loop.**
  - The 20 MEADOW MILE arenas in a forced ordered loop (harness, KILLS 999), × 12 seeds = **240 stages**: G 36, V 156, H 48.
  - Every arena gets n = 12, which is the floor for the R6 selection rule.
- **Lane 2, real flow.**
  - **8 first-to-10 matches** through the real match flow (KILLS 10, CD4-01 on), each followed by one REMATCH: 16 matches, about 200
    stages.
  - Per stage, log: arena id, class, position in match, match index in the session, score state, `length_s`, every death with edge
    and killer, claw-backs, and hazard-caused deaths.

**Analysis:**
- T1-G / V / H come from lane 1. Lane 2 stages, pooled by class, are the replication.
- T1-S comes from lane 2.
- **Position effect:** within class on lane 2, the median of stage positions 1-5 minus positions 6+, with a bootstrap CI.
- Side-edge share of human deaths on V, for the R5 reopen test.
- Per-arena V ranking on lane 1, for R6 selection.

**Decision table** (rows 1-3 are mutually exclusive; rows 4-6 can fire alongside any of them):

| Row | Condition | Ruling |
|---|---|---|
| 0 | fewer than 100 V stages, or a precondition fails (geometry diff, CD4-01 not behaving as A6) | **Inconclusive.** Fix and rerun once |
| 1 | T1-V passes (all three lines), and T1-G and T1-H pass | **Close WK-20d:** no R5, no R6. DECISIONS entry with the class numbers |
| 2 | T1-V misses only on the under-6 s or claw-back line, with V median ≥ 9.0 | **Phase B:** R6 on the arenas the §11.5 rule selects |
| 3 | T1-V median < 9.0 | Phase B R6 **and** route V to a level-designer geometry pass (WK-57 scorecard) |
| 4 | T1-G p90 > 40 s or median > 25 s | New item: wide-deck stall (not R6). Likely Grassy Expanse |
| 5 | T1-H outside 10-25 s | New item per arena family. Hazards are tuned, not shelved |
| 6 | Position effect ≥ 3 s, with a CI excluding 0 | New QA item to find the cause **before** any geometry is built. Phase B waits for it |
| 7 | Side-edge deaths ≥ 25 % of human deaths on V | Reopen R5 as a separate single-variable arm |

**Phase B: conditional R6** (a continuation of the same batch if game time allows, otherwise the next headless slot):
- **Variant:** R6 JSON variants (scratch copy only) on the selected arenas, at most 4.
- **Volume:** 24 shelf stages + 24 fresh same-session baseline stages per arena, interleaved by seed. That is at most 192 stages.
- **Mechanism checks:**
  - shelf contacts > 0;
  - the per-gap flight analysis is attached;
  - the new `camera_bounds` values are recorded and the aspect check passes (vertical × 16/9 ≤ horizontal);
  - shelves pay fuel on ≥ 95 % of first contacts.
- **Keep rule, per arena.** The shelf stays only if both hold:
  - under-6 s share falls ≥ 30 % (relative) **or** median rises ≥ +1.5 s; **and**
  - G1 (≥ 0.8 ×), G2 (relative), G5, G7 and shelf dwell ≤ 3 % all hold.
- **Class recompute.** V is then recomputed with the kept shelves (lane 1 data with the shelved arenas swapped in), and it must pass
  T1-V. If it still misses, apply row 3.
- **Rendered (single process, own port):**
  - a WK-93 recording, 20 s per shelved arena, contact sheet looked at:
    - does the shelf read as a rescue bounce, not as backdrop?
    - does a falling goat visibly claw back?
    - does the camera keep it framed with no lurch?
  - before/after stills per arena (owner camera area);
  - art-director grade.

**Budget:** Phase A about 440 + Phase B at most 192 = at most about 630 stages (under the 1,050 cap), about 130 min of game time.

**Deliverables:**
- `tools/out/wk/WK-20d_classes.json`: `meta`, per-class T1-G / V / H / S with n and CIs, position-effect estimate, per-arena
  scorecard at n ≥ 12, side-edge share, Phase B arms if run, and `predictions_hit` for A1-A6 and B1-B4.
- Raw per-stage logs.
- A results doc in `docs/audit/`.
- A DECISIONS entry: close, R6 adopted per arena, or a re-route.

**Success criteria for this addendum's protocol:**
1. Every class has n and a CI. V has n ≥ 100 and every arena has n ≥ 12 on lane 1.
2. The sky-drop geometry diff ran, with its result recorded.
3. The position effect is reported with a CI, whichever CD4-01 shape shipped.
4. The designer can apply the §11.8 decision table without asking for another number.
5. At most 2 Godot processes ran at once, and game time is recorded in `meta`.
