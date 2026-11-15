# WK-169c: SHOWDOWN polish + the golden-tank holder ruling (2026-11-16)

**Owner:** game-designer (this spec, the G9 ruling) · **Build:** gameplay-programmer (lanes D, B), ui-ux-designer + gameplay-programmer
(lane H), sound-designer (lane A), art-director (golden tank art) · **Re-check:** qa-playtester (one headless batch, 2 processes) ·
**Felt check:** creative-director (WK-CD6).
**Inputs read:** VISION · GAME_DESIGN §2, §4.3, §4.6, §5 · FEEL_REFERENCE §0, §3, §5.5, §7 · `docs/specs/wk169_spectator_time_2026-11-16.md`
(§6.1, §7, §8, §11 G9, §12) · `docs/audit/2026-11-16_wk169b2.md` · DECISIONS 2026-11-16 (WK-169 SHOWDOWN SHIPPED; director answers) ·
`tools/out/wk/WK-169b2_summary.json` · raw tank records `tools/out/wk/wk169b2_batch/raw_6b9cd7e/T.A1.*.json` · `ShowdownDirector.gd`,
`PowerupBubble.gd`, `PowerupSystem.gd` (golden tank, `_end_effect`), `PowerupSpawnDirector.gd`, `InputBot.gd` (`_decide`, `_wk169_golden_seek`,
`_can_reach`), `PartyMatch._update_camera`, `AudioManager.gd` (SFX map, Stingers bus), `PlayerCard.gd`, `Tuning.gd` WK-169 block,
`assets/powerups/icon_unlimited_boost.png`.
**Scope fence:** no code edits, no BACKLOG edits, no commit. Everything here is behind a switch or is presentation.

---

## 0. TL;DR

**Job 1: the holder ruling.**
- **Keep `showdown_drop_dur` at 6 s. Reject 6 → 4 and 6 → 5.**
  - The raw 169b-2 tank records show the duration isn't what makes the holder strong.
  - **29 of the 38 lane-T tails with a golden pickup ended during the first tank, and the median was 2.6 s after the grab.** Only 5 ended
    in the 4-6 s window that a 4 s tank would remove.
  - The holder also leaves the tank with a **full** fuel tank (fuel was pinned at 100), so a shorter tank removes about two refires, not
    the threat.
  - Predicted effect of dur 4: −0 to −4 pp on holder-wins, and slightly longer tails.
- **The real fairness issue is the point-blank opening.**
  - The race puts the loser right next to the winner at the moment the winner becomes armed.
  - 6 of 29 tails ended within 1.0 s of the grab, and 10 within 2.0 s.
  - "I lost the race by a hair and was dead before I could react" is the feel failure. The 88.6 % is a symptom.
- **The candidate lever is a new knob, `showdown_drop_arm_s` (GOLD SURGE).**
  - The golden tank's **super** arms 1.0 s after the grab. Boost works at once.
  - Built OFF in 169c (0.0 = today). It is re-checked A1 vs A1' on a powered lane-T variant (§1.5), with a pre-registered decision table.
- **Rejected:**
  - "no refresh on re-grab": it can't happen today, because the tank lock blocks every drop while a tank runs;
  - a consolation refuel for the loser: unearned fuel breaks the bounce-powered economy (FEEL §3.1, "protect it");
  - "knocked loose": it barely triggers against the measured driver. It's kept as the next idea if CD6 says "unfair".
- **G9 is not re-banded.** It stays a FLAG (50-85 %) carried into CD6 Q3 until the re-check rules.

**Job 2: the 169c polish brief (§2).**
- **Music:**
  - the hush is a Music-bus duck plus a low-pass that steps down with each step (no drum stem exists, so no new assets);
  - entry sting: WK-116's "ka-CHUNK" (the studio's existing "the arena escalates, nothing ends" sound);
  - golden telegraph: a derived bell "ding-ding", never a beep;
  - every sting rises at least 2 LU below the KO.
- **HUD:** a gold outer frame on the two fighters' cards, built as a lazily instanced `.tscn` (OFF parity), never covering the danger border
  or stickers. The holder's card also gets a glint.
- **Golden tank art:**
  - The prototype bubble **is too small and too samey at play zoom.** It's about 40 screen px at the 0.46 reference zoom and about 26 px at
    0.30, and it carries the **same cyan icon** as a normal Unlimited Boost.
  - The fix keeps the tested collider. It adds a gold recolour of the existing jerrycan icon (with a prompt if the recolour reads muddy), a
    visual body 1.25× the collider (the goat-art convention), and a halo of at least 120 screen px and at least 1.8× the body.
- **The ghost "PUFF FASTER" line is not built** (L2 is OFF).
- **The closest-centre tie-break** is already built; 169c verifies it.
- **Camera invariance** is a kinematic-replay frame test (≤ 1 px, ≤ 0.001 zoom) plus a code grep. The camera itself is untouched.
- **Prototype notes, ruled:**
  - **A low-fuel CPU now goes for a nearby, reachable golden bubble.** It's a full tank, so a starving goat should want it most.
  - **A golden drop claims an occupied spawner.** The regular bubble there does an "upgrade" pop, and the fair point never moves.
  - **A new edge case:** a held Unlimited Boost can't be activated while a golden tank runs. Today it would strip the golden flag and unlock
    the next drop.

---

## 1. Job 1: the golden-tank holder ruling (G9)

### 1.1 What the 169b-2 numbers say
- **The G9 headline:** the golden holder wins the tail 39 / 44 = **88.6 %** (lane T 34 / 38, lane N 5 / 6). That's Wilson90 78-94 %, above
  the 85 % band on the point estimate for the second batch running (WK-169b 88 %), but not provably above it.
- **"Holder" = the LAST collector** (`wk169b2_stats.py` line 150).
- **The race is fair.**
  - Pickups split seat 0 24 / seat 1 19.
  - The fair point is the minimax spawner.
  - Collection is 43 / 43 resolved, median 0.58 s from live.
- **My re-read of the 38 lane-T tank records (`raw_6b9cd7e/T.A1.*.json`, the `tank` arrays):**

| | Count | Detail |
|---|---|---|
| Tails that ended **during the first tank** | **29 / 38 (76 %)** | Time from grab to stage end, sorted: 0.09, 0.19, 0.38, 0.52, 0.67, 0.86, 1.11, 1.27, 1.67, 1.86, 2.01, 2.54, 2.54, 2.57, 2.62, 2.65, 2.73, 2.82, 3.09, 3.28, 3.33, 3.42, 3.79, 3.92, 4.22, 4.34, 4.60, 5.17, 5.85 s. **Median 2.62 s** |
| ... within 1.0 s of the grab | 6 | The four under 0.6 s were probably KOs already in flight (the gold didn't cause them) |
| ... within 2.0 s of the grab | 10 (26 % of 38) | The point-blank zone |
| ... in the 4-6 s window (what dur 4 removes) | **5** | 4.22, 4.34, 4.60, 5.17, 5.85 |
| Tanks that ran the full 6.0 s | 9 / 38 | The non-holder survived the gold |
| ... of which a second tank was collected | 5 | **The other fighter got the second tank in 4 of 5** (stages 201, 202, 203, 213; 211 is the exception) |

**Three conclusions:**
1. **The gold decides fast, during the first ~3 s.** A shorter tank barely touches that.
2. **When it ends, the holder still has 100 fuel.**
   - Fuel was pinned to `fuel_max` during the tank, and `_end_effect` only clears `fuel_locked`.
   - So the post-tank holder has one full-power super in hand, and dur 4 just moves where that super happens.
3. **The comeback loop already exists.**
   - Survive the gold, and the next drop re-picks the fair point. The fighter who just super-spammed is usually out of position, and the
     survivor took the next tank 4 times in 5.
   - That's why "holder = last collector" reads high. In those stages the comeback fighter *is* the "holder".
   - **First-grabber-wins** (not computed in 169b-2) is probably about 5-10 pp lower. The re-check reports it.

**The driver caveat (it applies to every G9 number):**
- HumanSim5g's race loser **keeps chasing** the armed holder (the chase rule, 140 px above). It never flees.
- Real players run from a goat glowing gold.
- So 88.6 % is an upper bound on what humans will see. That's no excuse to ignore it, but it does mean the lever must work even against a
  chaser, which the one below does (§1.4).

### 1.2 Options weighed

| Option | What it targets | Predicted effect on holder-wins | Cost / risk | Verdict |
|---|---|---|---|---|
| `showdown_drop_dur` 6 → 4 (the §8 ladder's first knob) | Gold length | **−0 to −4 pp.** Upper bound −6.6 pp if all 5 KOs in the 4-6 s window flipped to coin flips, but the full-fuel exit keeps most of them | Tails a little longer (14 tanks lose 2 s of pressure). The drop cadence barely changes (the next telegraph is due at 8 s either way) | **Reject.** Wrong mechanism |
| `showdown_drop_dur` 6 → 5 | Same | −0 to −2 pp (2 KOs in 5-6 s) | Same, smaller | **Reject** |
| No refresh on re-grab | Chain dominance | **0.** Unreachable: `_tick_drop` won't telegraph while any golden tank runs or for 1.0 s after it, so a holder can never touch a second golden bubble mid-tank | None | **Reject (moot).** Keep the refresh code. It's dead, but harmless |
| Consolation for the race loser (instant refuel) | Loser's agency | −5 to −12 pp | **Pillar breach.** Fuel refills only by bouncing (GAME_DESIGN §4.3, FEEL §3.1 "protect it"). It also gives a free recovery, which breaks the hitstun → no-refuel → recovery-gamble triad, and it turns the race into a coin flip at point-blank range | **Reject** |
| Holder takes extra knockback | Holder's vulnerability | ? | Touches the owner-ruled knockback array (DECISIONS (c)) | **Reject (fence)** |
| **KNOCKED LOOSE**: a smash landed on the holder ends their gold | Counterplay | −1 to −4 pp under the sim (the chasing loser rarely out-hits a fuel-pinned holder) | New rule to teach, though "smash the shiny one" is readable | **Hold.** Next idea if CD6 Q3 = "unfair" |
| Grant Star instead (the ladder's second knob) | Changes the prize | Unknown | Star wins by contact, not by super. It moves the decisive verb away from SUPER-SMASH (GAME_ESSENCE) | **Hold** (ladder step 2, unchanged) |
| **GOLD SURGE: the golden super arms `showdown_drop_arm_s` = 1.0 s after the grab** | **The point-blank opening** | **−6 to −14 pp** (§1.6) | Small: it reuses the refire-lockout idea. It slightly lengthens post-drop tails | **Build OFF in 169c; re-check (§1.5)** |

### 1.3 Ruling
1. **`showdown_drop_dur` stays 6.0 s.** The shipped A1 build is unchanged.
2. **169c builds GOLD SURGE behind `showdown_drop_arm_s` (default 0.0 = today, byte for byte).**
3. **The re-check runs in the next free headless slot** (§1.5). If it lands in row R1, the producer flips one Tuning line to 1.0 and logs it
   in DECISIONS. No other knob moves in the same flip (FEEL §0: one variable at a time).
4. **G9 keeps its pre-registered band (50-85 %) and stays a FLAG.**
   - I'm not re-banding after seeing data that misses the band.
   - CD6 Q3 ("did the golden tank feel fair to the one who missed it?") stays the felt judge.
   - If the re-check lands in R2 *and* CD6 says "unfair", the §8 ladder resumes at dur 6 → 4 with its own re-check. That would test whether
     the felt read and the sim disagree.

### 1.4 GOLD SURGE: the mechanic

**Player fantasy:**
> *"Pogo hits the gold first. FWUMMM: her rim floods gold like a charging meter, and for one heartbeat she can fly but can't fire. Butch
> scatters, or he turns and smashes her before it fills. Then it's full, it goes 'ting', and she starts firing."*

**Mechanic:**
- **When:** on collecting a golden tank.
- **What locks:** for `showdown_drop_arm_s` the holder's **super** is locked.
- **What doesn't lock:** fuel is pinned at max from the first frame, and normal boost works at once (full thrust, steerable).
- **After that:** the tank runs exactly as today, with refire lockout `pu_unlimited_super_lockout` 1.0 s between supers.
- **The arm window counts inside the 6 s tank.** The holder gets 5 s of armed super time, so it's slightly weaker overall too.

**Why 1.0 s:**
- It equals `pu_unlimited_super_lockout`. Players already learn a 1-second golden refire rhythm, and this makes the *first* shot follow the
  same beat ("it fires once a second, starting one second after you grab it").
- What it buys the loser:
  - human reaction is about 0.25 s;
  - boost reaches its 650 px/s cap in about 0.15 s (accel 4200 px/s², FEEL §3.2);
  - so in the remaining ~0.75 s the loser can open about 400-490 px (~4 H).
- That's right around HumanSim's 560 px super line and about a screen-quarter at play zoom: a real escape chance, not a guarantee.
- **0.6 s** buys about 240 px (still point-blank). **1.5 s** buys more than 700 px and wastes a quarter of the prize.

**Why it works against a chasing driver:** during the arm window the *loser* can super the holder, and the holder can't super back.
- Normal-boost body contact is capped at 650 px/s, under `smash_impact_min` 900, so the holder can't smash at all.
- So the race loser gets the first strike window. It's a real counterplay verb (SUPER-SMASH), not just a head start.

**Feedback (Rule of Three; built only if the knob ships ON, §2.9; a stub read is enough for the headless re-check):**

| Beat | Visual | Audio | Kinesthetic |
|---|---|---|---|
| Grab | The holder's gold rim floods clockwise over `arm_s` (a charge sweep on the existing RimLight, ring width ×1.5) | The gold collect sting (§2.2) | Holder pad 0.5 / 0.6 for 0.15 s (spec §7) |
| Super pressed while arming | The existing WK-20e super-lock badge beside the head | The existing `super_locked` dry click | None |
| Armed | The rim flashes white-gold once, then holds gold | A single "ting" (the telegraph bell's second note, §2.2) | Holder pad 0.3 / 0.2 for 0.08 s |

**Edge cases:**
- **The holder is smashed during the arm window:** normal knockback and hitstun. The arm clock keeps running, and the gold isn't lost.
  Knocked loose is not part of this lever.
- **The holder dies during the arm window:** the tank ends. The stage is over (1 alive) or goes to SD.
- **`arm_s` ≥ `showdown_drop_dur`:** clamp to `dur − 1.0`. A tank that can never fire is a bug.
- **An in-flight KO** (the victim was launched before the grab) is unaffected. That's correct: the gold didn't cause it.

**Telemetry (needed for the re-check; 169c lane D):**
- tank record + `arm_s`, `t_first_super` (−1 if none), `t_first_smash`;
- per-stage `first_collector`;
- per-kill `t_since_grab` (−1 if no tank was collected this stage).

### 1.5 The re-check: lane TG (A1 vs A1', one headless batch, 2 processes)

**Why a variant of lane T:**
- In plain lane T only ~21 % of forced stages reach the 6 s showdown: 38 holder stages from 276.
- At 150 stages per arm that's about 21 holder stages, a ±8 pp standard error on G9. Nothing could be ruled.
- **Lane TG keeps the lane-T rig but sets `tune_showdown_delay=0.5` in BOTH arms.**
  - The forced 1v1 starts at 3.0 s, the showdown at 3.5 s, and the drop goes live at 4.5 s.
  - So roughly 75-85 % of stages get a golden pickup.
- **Honest limit:** TG drops the gold into a *fresh* duel, not a 6 s stalemate.
  - It's a **mechanism test of the holder advantage**, not an S4 tail test.
  - The S4 result from 169b-2 stands. The lever can only shift tails by delaying a KO by about a second.

**Rig:**
- **Build and harness:**
  - HEAD after the 169c build, which includes `showdown_drop_arm_s` (default 0.0);
  - `git archive` → scratchpad, the same treatment as 169b-2 (McpInteractionServer removed, `--gb-port=0`, APPDATA isolated);
  - harness: copy `tools/out/wk/wk169b2_batch/` (HumanSim5g / WK169bRec / WK169bBoot, md5-identical) to `tools/out/wk/wk169c_recheck/`.
- **Common args:** `flow=loop force2=3.0 stages=15 wall=900 tune_circuit_session_deck=0 tune_showdown_delay=0.5`, env `GB_WK169=a1`
  (telemetry on; the drop is already ON at HEAD).
- **Arms:**
  - **A1** = the common args;
  - **A1'** = common + `tune_showdown_drop_arm_s=1.0`.
- **Seeds:** 501-510, shared by both arms. That's 10 seeds × 15 stages = **150 forced stages per arm, 300 in total.**
- **Order and processes:**
  - seed-major, arms interleaved (A1 501, A1' 501, A1 502, ...);
  - lane 1 runs seeds 501-505 and lane 2 runs 506-510;
  - **at most 2 Godot processes**, each job a fresh process, timeout 1800 s.
- **Wall estimate:** about 300 stages × ~10 s game at ~3.2× realtime per lane, so **about 12-15 min.**
- **Exclusions:** as in lane T, `natural` (seat 0 or 1 died before 3.0 s) and `pre2` are excluded. Report the counts.

**Metrics (analyzer `wk169c_recheck_stats.py`, extending `wk169b2_stats.py`; T2c / SD-free conventions unchanged):**

| ID | Metric | Definition |
|---|---|---|
| **H** | Holder wins (G9 definition) | winner == last collector, over stages with ≥ 1 collection and a winner |
| **F** | First grabber wins | winner == `first_collector` |
| **PB** | **Point-blank deaths** | Share of first collections followed by the non-holder's death within **2.0 s** of `t_collect` |
| **PD** | Post-drop tail | stage end (SD-free, T2c convention) − first golden `t_live`; median, p90, P(PD > 8 s) |
| **FS** | First golden super | `t_first_super − t_on`; median (knob check) |
| **LS** | Loser strikes first | Share of first collections where the non-holder lands a smash on the holder before the holder's first super |
| **SK** | Self-KO share of tail-enders | G3's definition, per arm |
| **C** | Collection | collected ÷ (collected + popped) |

### 1.6 Pre-registered predictions (written before any build or data)

| ID | Prediction |
|---|---|
| **R-P1** | **A1 (TG):** H **84-93 %**, F **78-90 %**, PB **15-30 %**, FS median **0.2-0.8 s**, PD median **2.5-4.5 s**, P(PD > 8 s) **6-16 %**, LS **3-10 %**, C ≥ 95 %. |
| **R-P2** | **A1' (TG):** H **74-85 %** (Δ **−6 to −14 pp** vs A1), PB **4-12 %** (ratio ≤ 0.5), FS ≥ 1.0 s on **100 %** of tanks with a super (knob check), LS **10-25 %**, PD median **+0.5 to +1.5 s**, P(PD > 8 s) **Δ 0 to +6 pp**, SK **Δ −3 to +3 pp**, C unchanged ± 3 pp. |
| **R-P3** | Natural-excluded stages ≤ 12 % per arm. Errors and censors = 0. |
| **R-P4** (counterfactual, not tested) | dur 6 → 4 would move H by **−0 to −4 pp** (§1.2). If the producer ever runs it anyway, this is the line to grade. |
| **Forecast** | R1 **≈ 55 %**, R2 **≈ 30 %**, R3 **≈ 10 %**, R4 **≈ 5 %**. |

### 1.7 Decision table (pre-registered)

| Row | Condition | Ruling |
|---|---|---|
| **R1** | **PB** ratio A1'/A1 ≤ 0.5 with a one-sided Fisher p < 0.05 (the powered primary), **and** H Δ ≤ −6 pp (point), **and** P(PD > 8 s) Δ ≤ +6 pp, **and** SK Δ ≤ +5 pp, **and** C ≥ 90 % in both arms | **Ship GOLD SURGE:** `showdown_drop_arm_s` 0 → 1.0, plus the §1.4 feedback. G9 clears if H(A1') ≤ 85 %; otherwise it stays a FLAG for CD6 Q3 |
| **R2** | PB not halved, or H Δ > −6 pp | Keep arm 0.0. G9 stays a FLAG and CD6 Q3 is its judge. If CD6 says "unfair": the §8 ladder (dur 6 → 4, its own lane-T re-check), then KNOCKED LOOSE |
| **R3** | PB and H improve, but P(PD > 8 s) Δ > +6 pp or SK Δ > +5 pp | Try `arm_s` 0.6 once in the next free slot (same rig). If the cost persists, R2 |
| **R4** | C < 90 %, natural-excluded > 20 %, or any errors or censors | No ruling. Report, fix, re-queue |

**Why PB is the primary and H is a point-threshold secondary:**
- At about 115 holder stages per arm, H's difference has an SE of about 5 pp, while PB's predicted 15-20 pp drop is 3 SE or more.
- The lever is one reversible Tuning line, and CD6 gives an independent felt read.
- So a pre-registered point bar on H is acceptable here. It would not be for a protected constant.

---

## 2. Job 2: the 169c polish build brief

**What 169c is:** the presentation half of spec §7 for the shipped arm (L1 only), plus three rule fixes (§2.8), the GOLD SURGE knob (OFF),
and the acceptance tests (§3). **No change to any WK-169 timing, the fair-point rule, the collider size or the camera.**

**The fantasy it must deliver (spec §3):** the meadow goes quiet, something gold shimmers into the gap, both dive for it, and the ghosts lean
in. **A prize, never a countdown.** Warm gold, never hazard red. No clock UI of any kind.

### 2.1 Order and lanes (follow the shared-file map at build time)
1. **Lane D** (`ShowdownDirector.gd`, `PartyMatch.gd` hooks, `PowerupSpawnDirector.gd`, `PowerupSystem.gd`, `PowerupBubble.gd`): the spawner
   claim, the held-UB guard, GOLD SURGE (OFF) + telemetry, the bubble visual sizing, the audio/HUD signals.
2. **Lane A** (`AudioManager.gd`, `default_bus_layout.tres`, `assets/sfx/` + `LICENSES.md`): the hush and the stings. Parallel with D once
   the EventBus signals are named.
3. **Lane H** (`PlayerCard.gd` + a new `scenes/ui/ShowdownCardFrame.tscn`, `MatchHUD.gd`): the gold frame. After lane H's current holder.
4. **Lane B** (`InputBot.gd`): the low-fuel golden seek. After lane B's current holder commits.
5. **Art:** the golden tank icon. Independent, starting now (outside the cap).

**New EventBus signals** (own `# WK-169c` block):
- `showdown_entered(fighters)`, `showdown_step(step)`, `showdown_exited(reason)`;
- `golden_telegraph(pos)`, `golden_live(pos)`, `golden_collected(player)`, `golden_armed(player)`, `golden_tank_ended(player)`,
  `golden_popped(pos)`.

Audio and HUD listen; they never call into gameplay (the AudioManager rule).

### 2.2 Audio: hush and stings (sound-designer; existing assets only)

**The rule:**
- No new downloads.
- Derived renders of files already in `assets/sfx/` are allowed: pitch, cut, layer, reverse. That's how `whistle_double` and `super_aim`
  were made. Log each derivation in `assets/sfx/LICENSES.md` and keep the render script under `tools/audio/`.
- **Deviation from spec §7, on purpose:** no drum or heartbeat stem exists, and a looping pulse risks reading as a clock (WK-170). The hush
  is a **filter**, not a new layer.

| Event | Cue | Bus | Level target | Notes |
|---|---|---|---|---|
| **SHOWDOWN entry** | **"ka-CHUNK"**: `pressure_ka` then `pressure_chunk` 70 ms later (the WK-116 Rocketball pressure-nets pair) | Stingers | Rise **≤ KO rise − 2 LU** in the same capture | One sound across modes for "the arena escalates, nothing ends", already taught by Rocketball. Not `two_left` (that's TWO LEFT!'s, 6 s earlier) |
| **Music hush** (entry) | Music bus duck **`showdown_music_duck_db` −5 dB** plus a low-pass **20 kHz → `showdown_music_lpf_hz[0]` 1600 Hz**, both over **`showdown_music_ease_in` 1.0 s** | Music | Integrated loudness still **−16..−18 LUFS** | The melody goes "behind glass" and the SFX bed (bounces, thrust, smashes) sits on top: the duel sounds louder *because* the music stepped back. −5, not the spec's −6, because the LPF already removes perceived loudness |
| **Step 2 / 3** | A single `pressure_chunk` (no "ka"), −3 dB vs the entry pair. The LPF steps to **1100 Hz, then 800 Hz** (0.4 s glide) | Stingers / Music | Rise ≤ entry rise | No tempo, no repetition between steps: nothing to count |
| **Golden telegraph** | **"ding-ding"**: two bell strikes 110 ms apart, derived from `pickup_bubble.mp3` (+12 st, short tail, 2nd strike +5 st). The sound-designer may pick a different existing source if it rings truer | Stingers | Rise ≤ KO − 3 LU | **Never** `countdown_beep*`, and no pure sine (WK-170: beeps read as a countdown). Two strikes, not three: a triplet starts to count |
| **Golden live** | None (no shimmer source exists). The visual glint carries it (§2.4) | | | Don't fake a loop from bounce or thrust material: it would mask the bed |
| **Collect** (gold sting) | Derived layer: `pullOutItem` + `pickup_bubble` (+5 st), ≤ 0.6 s | Stingers | Rise **≤ KO − 2 LU** | Distinct from the normal `powerup_pickup` (an A/B listen: 10/10 told apart). Not `awYeah` (First Blood), not the goal saxes (Rocketball team identity), not `rewardCheer` (match win) |
| **GOLD SURGE armed** (only if R1) | A single "ting" = the telegraph's second strike | SFX | −8 dB | Ties the arm to the drop's voice |
| **Super pressed while arming** (only if R1) | The existing `super_locked` dry click | SFX | existing | Same meaning as the WK-20e spawn truce: "your super is locked" |
| **Tank ends** | A small "pfff": `woosh.mp3` −7 st, cut to 0.3 s | SFX | −10 dB | A deflate, not a fail sting |
| **Exit** (stage end, MATCH_END) | Duck and LPF release over **`showdown_music_ease_out` 0.4 s** | Music | | STAGE_END's own cues play over it |
| **Exit** (SUDDEN_DEATH) | Duck and LPF release **at once** (0 s) | Music | | SD has its own identity; the showdown clears within 1 frame (spec §5.3) |

**Kinesthetic** (FEEL §5.5 scale; fighters only unless stated):
- entry: fighters 0.2 / 0.3 for 0.15 s (softer than a bounce thump at 0.35 strong, so it reads as "something changed", not "you were hit");
- entry: ghosts 0.1 / 0 for 0.1 s;
- collect: the holder 0.5 / 0.6 for 0.15 s (under super-fire's 0.6 / 0.9);
- steps: none.

**OFF parity:** with `showdown_enabled=false`, the Music bus has no active LPF and no duck (the effect is absent or bypassed), and the
`assets/sfx` map is unchanged for every other event.

### 2.3 HUD: the gold card frame (ui-ux-designer + gameplay-programmer, lane H)

- **Scene, not code:**
  - `scenes/ui/ShowdownCardFrame.tscn`, a `Panel` with draw_center off;
  - its stylebox is a named variant in the project Theme (`ShowdownFrame`), never `StyleBoxFlat.new()` in code;
  - **instanced lazily on the first `showdown_entered`**, the way `GhostCardBadge.tscn` is (WK-37 T8), so with the showdown OFF the card's
    node tree is the pre-169c one.
- **Look:**
  - gold `#ffd23f` 5 px border, a 2 px chocolate `#3b241b` keyline outside it, a soft gold outer glow of 6 px (shadow);
  - corner radius = the card's radius + 4;
  - it sits **outside** the card: expand margins 6 px.
- **Never covers:**
  - the crimson danger border (WK-31), which stays inside;
  - the HURT! / DANGER! sticker, the stock tab, the +1 chip or the held-powerup slot (the WK-173 overlap lesson; T-H2 checks it).
- **Motion:**
  - pop-in at entry: scale 1.15 → 1.0 over 0.2 s, TRANS_BACK;
  - one pulse per step (border alpha 1.0 → 0.6 → 1.0 over 0.3 s);
  - fade-out 0.2 s on exit;
  - no continuous animation on a non-holder's frame.
- **Holder read:** while a golden tank runs, the holder's frame shows a diagonal white-gold **glint sweep** every 0.8 s. Everyone can tell
  **who has the gold** from the HUD alone. The fuel bar keeps the existing Unlimited read (cyan, `bubble_fuel_locked_color`). Don't invent a
  second fuel colour.
- **Who gets it:** only the two showdown fighters. Ghost cards stay as they are (dimmed, ghost head, ring).
- **No text, no timer, no step number on the card.**

### 2.4 Golden tank art: size ruling and the asset (art-director)

**Is the prototype bubble too small at play zoom? Yes.**
- **Body:** about 86 world px across (`RADIUS` 36 × 1.2 × 2). At the 0.46 reference play zoom that's **about 40 screen px**; at 0.30 (the
  widest void arenas) **about 26 px**. A goat at play zoom is about 40-80 px (Tuning `super_lock_badge_px` note).
- **Icon:** it's the **same cyan jerrycan** as a normal Unlimited Boost bubble, at about 27 / 17 screen px.
- **The result:** the only difference from a normal bubble is a 0.45-alpha gold tint. The single most important object in the showdown is
  about goat-sized, and it's told apart from a normal pickup by hue alone.
- That fails T6's "golden vs normal 20 / 20" on paper, and Pillar 5 at couch distance.

**The fix (keep gameplay as tested):**
1. **The collider is unchanged:** radius 43.2 world px (`RADIUS` × `showdown_drop_scale` 1.2), as measured in 169b-2.
   - The collider must never depend on zoom: gameplay can't change with the camera.
   - Don't raise `showdown_drop_scale`. That's a collection knob, and collection is already 100 %.
2. **The visual body is 1.25× the collider: 54 world px radius.**
   - That's the house convention (goat art overhangs its collider 1.25×; `showdown_rim_radius_mult`).
   - It's honest: touching the art's inner 80 % collects.
   - It gives about 50 screen px at 0.46 and about 32 px at 0.30.
3. **The halo diameter = max(`showdown_drop_halo_px` 120 screen px at 1080p, `showdown_drop_halo_body_mult` 1.8 × the visual body).**
   - World = px / zoom: the `hit_burst_screen_px` pattern for the floor term.
   - The floor carries wide zooms. The body multiple carries close zooms, where 120 px would be barely bigger than the body.
   - It's a soft radial gold glow with no outline, so it reads as light, not body.
   - Six star sparkles orbit at the halo edge (`assets/fx/star_sparkle.png`, 1 rev / 2.4 s).
   - A white **glint** sweeps across the body every 1.2 s (motion draws the eye; Pillar 5).
4. **The body is the existing code-drawn `BubbleGloss` golden branch** (reuse; it's the established bubble language, not new "SVG art"):
   - body alpha 0.45 → **0.62** (warmer, more solid gold);
   - rim 4.5 → **6 px**;
   - the chocolate outline stays, at 3 px.
5. **The icon is a golden jerrycan, `assets/powerups/icon_golden_tank.png`, shown at `showdown_drop_icon_px` 64 world px** (the normal icon is
   48). The icon is the read, so it fills more of the bubble.
   - **First try, with no generation:** a hue-masked recolour of `icon_unlimited_boost.png`:
     - only the cyan hue band moves to gold (highlight `#FFD23F`, mid `#E09A1A`, shadow `#8A5212`);
     - the red cap, the orange flames and the dark outline are kept;
     - the ∞ emblem goes white-hot (`#FFF6D8` core, gold glow).
   - Grade it **in game** on the T6 sheet. Gold-on-gold can go muddy: the thick dark outline must carry the silhouette.
   - **If the recolour reads muddy or low-contrast, generate.** Attach `assets/reference/style_sheet.png` + `icon_unlimited_boost.png`:

     > Game powerup icon in the Glossy Toybox style of the attached style sheet. Redraw the attached jetpack fuel jerrycan with the SAME
     > silhouette, proportions and three little rocket nozzles with orange flames, but made of polished candy-glossy GOLD: bright highlights
     > #FFD23F, warm mid-tones #E09A1A, deep shadows #8A5212, strong glossy bevels and a big soft specular highlight top-left. Keep the
     > small red screw cap. On the front panel, a glowing white-gold infinity symbol (#FFF6D8 core with a gold glow) and two tiny sparkle
     > stars. Thick dark chocolate outline (#3B241B) around the whole silhouette, 3-4% of the icon width. Front view, centred, no text, no
     > ground, no scenery, no drop shadow. Transparent background (PNG with real alpha, not a checkerboard). 1024x1024 canvas, the can
     > filling about 85% of the height. It must read instantly as "the golden version of the cyan fuel can" at 32 px.

   - **Process:** `tools/art.py` trim and validate alpha; `keyout --tol 45` if a checkerboard got baked in (the WK-pipeline lesson);
     downscale to the existing icon's aspect (about 519 × 706) and long side. Add an `assets/CATALOG.md` entry (what, prompt, date).
6. **Telegraph:** keep the gold converging sparkle (normal blend; additive went white on bright skies). Add a **ground-glow ring** at the
   point, same sizing rule as the halo, fading in over the 1.0 s, so the spot is readable before the bubble exists.
7. **Collect burst:** the existing `_burst`, tinted gold (hue variation 0, gold → white ramp), 1.5× particle count. Plus a **"GOLDEN TANK!"
   word pop** in the goat's colour at the goat (spec §7, the WK-49 name-pop style).

**In-world holder read (so the non-holder can play the counter-game):**
- while the tank runs, the holder's RimLight is ×1.5 width with a slow shimmer (alpha 0.75 ↔ 1.0, 0.8 s);
- a thin trail of `star_sparkle` from the jetpack nozzle (8 / s, 0.4 s life, normal blend);
- the non-holder's rim stays the plain showdown rim;
- when the tank ends, the holder's rim blinks 3× in the last 1.0 s (spec §7), then returns to the plain rim.

### 2.5 The ghost "SHOWDOWN! (X) PUFF FASTER" line: not built
- It belongs to L2 (restless ghosts), which is OFF. Don't build it. Also don't build the gold ghost ring or the crowd-bleat layer.
- Building L2 presentation without L2 would teach ghosts a verb that doesn't exist.
- If L2 ever ships, these three become its required presentation. Spec §7's L2 row stands.
- What ghosts do get in 169c: the SHOWDOWN! banner, the hush, the ka-CHUNK and the 0.1 / 0 rumble. That's enough to say "something's
  happening", which is all a ghost needs while its puff rules are unchanged.

### 2.6 Closest-centre tie-break: verify, don't rebuild
- `PowerupBubble._resolve_golden` already gathers every fighter that touched it this physics frame and resolves once, deferred.
  - The closest centre wins.
  - An exact tie (≤ 0.001 px) is a coin.
  - Dead or frozen fighters are skipped.
- **Design confirmation:**
  - Touches on different physics ticks are first-come, by design. The earlier toucher was there first.
  - A fighter **in hitstun** may collect: being smashed *into* the gold is legitimate physics comedy (Pillar 3).
- 169c adds only the test (§3, T-4c).

### 2.7 Camera invariance: a frame test, no camera change
- **By construction:** `PartyMatch._update_camera` frames only living players' bounds-clamped positions plus `_mode.camera_focus_points()`
  (Brawl returns []). The showdown adds a dim plate, rims, a bubble and particles, and none of them is an input.
- 169c must prove it stays that way (owner camera rules 2026-07-10; spec G12 / T5).
- **Three checks:**
  - **T-5a code grep:** no WK-169 / 169c code writes to `_camera`, `Camera2D.zoom`, `position`, `offset`, `camera_bounds`, or returns focus
    points. `ShowdownDirector._view_rect()` stays read-only.
  - **T-5b kinematic replay:**
    - Record a 20 s path (per physics frame: both fighters' `global_position`) from a real showdown tail.
    - Replay it twice on the same arena, with the fighters' physics disabled by a test hook and positions written per frame:
      - run ON: showdown forced at t = 0, drops on, so a bubble, telegraph, dim and rims all exist;
      - run OFF: `showdown_enabled=false`.
    - Both runs start from the same stage-start camera snap.
    - **Pass:** `get_screen_center_position()` within ≤ 1 px and `zoom.x` within ≤ 0.001 on **every** frame, including the frames of each
      step change, each telegraph, each collect and the exit.
    - Repeat on 3 arenas: one grounded, one void, and the widest-zoom arena.
  - **T-5c live owner rule:** 5 rendered showdown stages, 0 frames where an in-bounds living player is off the viewport.

### 2.8 Prototype notes and one new edge case: rulings

**(a) A low-fuel CPU ignores a nearby golden bubble.** *Ruling: fix it.*
- **Why:**
  - The golden tank *is* fuel: collecting it pins fuel at 100. A starving goat should want it most.
  - Today `_decide` runs the refuel dive (fuel < profile floor 15-35) before `_wk169_golden_seek`, so a CPU at 20 fuel 200 px from the
    bubble dives away from it.
  - HumanSim5g, the measured human model, has no refuel precedence at all.
  - Without the fix, a human-vs-CPU showdown hands the human a free race whenever the CPU is low, and that's exactly when the CPU is closest
    to losing.
- **Rule (`bot_golden_lowfuel_seek`, default ON with 169c):** when fuel is under the refuel floor, the golden seek is evaluated **before** the
  refuel dive, under the same §6.1 rule (d_me ≤ 1.25 × d_rival, p 0.5 per decision), **only if the bubble is reachable on current fuel:**
  - **Over ground** (a bounce surface below the path): fuel ≥ d_me × `CROSS_FUEL_PER_PX` (0.042) + 3, with no landing reserve. If the race
    is lost, the goat falls onto a surface and refuels as usual.
  - **Over void:** fuel ≥ d_me × 0.042 + `CROSS_FUEL_RESERVE` (15), the normal crossing rule. A lost race over the void must not strand it.
  - **And** d_me ≤ `bot_golden_lowfuel_reach` = 480 px (about 4.4 H; a fuel-25 CPU's over-ground budget is about 520 px).
  - Otherwise it does the refuel dive, unchanged.
  - RECOVER and mid-super are still handled first in `poll` (safety always wins).
- **Scope:**
  - Lane T has no CPU fighter, so the 169b-2 results and the §1.5 re-check aren't affected.
  - Lane N human-vs-CPU tails are, mildly and in the spec's intended direction.

**(b) A golden drop can land on an occupied spawner.** *Ruling: the golden drop CLAIMS its point. The fair point never moves.*
- **Why not re-pick the next spawner:** the minimax point is the fairness guarantee measured in 169b-2 (pickups 24 / 19). The runner-up point
  favours one fighter by construction.
- **Why not stack:**
  - two bubbles overlapping is unreadable (Pillar 5);
  - one touch would net a golden tank **and** a held powerup;
  - the auto-activated gold would bury which item went into the slot.
- **Rule:**
  - At golden **telegraph start**, any regular bubble whose centre is within `showdown_drop_claim_r` = **100 world px** of the point plays an
    **"upgrade" pop**: a gold-tinted `_burst`, no grant, no sound beyond the bell (that 100 px = golden collider 43.2 + normal 36 + ~20 px
    clearance so the two never visually kiss).
  - A regular **telegraph** pending on that point is cancelled. The regular director re-arms after a short retry (the existing `CAP_RETRY`
    beat) and picks again.
  - While a golden telegraph or bubble occupies a point, the regular director's `_pick_point` **excludes** it. With one spawner left in the
    level, the regular director waits.
  - No refund or catch-up: the regular cadence just continues.
- **A fighter already overlapping the point** when the bubble goes live still collects at once (spec §6.1).

**(c) New edge case: a held Unlimited Boost activated during a golden tank.** *Ruling: blocked.*
- **Today:** `_activate` on the same id refreshes the timer to the held powerup's 8 s and **erases the golden flag**. The showdown then
  believes the tank ended, the tank lock releases, and the next golden drop telegraphs 1 s later. A holder could chain gold → 8 s → gold.
- **Rule:** while a golden tank runs, pressing POWERUP with a held **Unlimited Boost** does nothing.
  - The existing deny feedback plays (`super_locked` dry click + a 0.3 s shake of the held-slot icon).
  - The item stays in the slot, usable after the gold ends.
- **Any other held powerup** activates normally and, per the one-active-effect rule, **ends the gold early.** That's the player's choice,
  and the tank lock then counts from that moment.
- **The non-holder** activating their own held Unlimited Boost during the showdown is legitimate, earned counterplay. No change.

### 2.9 Tuning additions (append to the WK-169 block, tagged `# WK-169c`; every default keeps today's gameplay except where marked)

| Constant | Default | Rationale |
|---|---|---|
| `showdown_drop_arm_s` | **0.0** (re-check value 1.0) | GOLD SURGE (§1.4). 0 = today, byte for byte |
| `showdown_music_duck_db` | −5.0 | §2.2; integrated loudness stays −16..−18 LUFS |
| `showdown_music_lpf_hz` | [1600, 1100, 800] | Per step; never below 600 Hz (bass-only mud reads as a bug) |
| `showdown_music_ease_in` / `_ease_out` | 1.0 / 0.4 s | Entry eases (= the dim ease); the release is quicker so STAGE_END isn't muffled |
| `showdown_drop_body_mult` | 1.25 | Visual body ÷ collider (goat-art convention). **Visual only** |
| `showdown_drop_halo_px` | 120 | SCREEN px halo floor at 1080p (world = px / zoom) |
| `showdown_drop_halo_body_mult` | 1.8 | Halo ≥ this × the visual body (close zooms) |
| `showdown_drop_icon_px` | 64 | World px of the golden icon (the normal icon is 48) |
| `showdown_drop_glint_s` | 1.2 | Glint sweep period (= `BOB_PERIOD`, so the motion stays in rhythm) |
| `showdown_drop_claim_r` | 100.0 | World px: regular bubbles inside this radius upgrade-pop at golden telegraph start |
| `bot_golden_lowfuel_seek` | **true** | §2.8 (a). false = the 169b-2 bot exactly |
| `bot_golden_lowfuel_reach` | 480.0 | px cap on a low-fuel seek |
| `showdown_holder_rim_mult` | 1.5 | Holder's rim width while a golden tank runs |

**Unchanged on purpose:**
- `showdown_drop_dur` 6.0, `showdown_drop_interval` 8.0, `showdown_drop_life` 7.0, `showdown_drop_scale` 1.2 (collider);
- `showdown_delay` 6.0, the fair-point rule, `bot_golden_seek_p` / `_ratio`;
- every camera constant.

---

## 3. Acceptance for 169c (QA drives the game; game time from `phase_log.tick_s` / `round_stats`; software GPU: wall-clock timing invalid)

Spec §12 T1-T4 and T11 still apply to the shipped build (re-run T1, T2, T4 and T11 on the 169c HEAD). The items below are new or restated
for 169c.

| ID | Test | Pass |
|---|---|---|
| **T-A1** Audio levels | `measure_run.py` on a WK-93 capture (MEADOW MILE, bots 2 / 2 / 3 / 3) containing ≥ 3 showdowns, ≥ 5 golden drops, ≥ 10 KOs | ka-CHUNK rise ≤ KO rise − 2 LU; gold collect sting ≤ KO − 2 LU; bell ≤ KO − 3 LU; integrated −16..−18 LUFS; the WK-170 countdown rule intact |
| **T-A2** Hush | Music-bus capture (or the bus peak meter via eval) 2 s before and 2 s after entry | Music RMS −4 to −6 dB; Music spectral centroid < 1.5 kHz at step 1 and lower at steps 2 and 3; back to the pre-showdown level within 0.5 s of STAGE_END; at SD entry back within 1 frame |
| **T-A3** No-beep | Listen-and-log on the capture | The telegraph has exactly 2 strikes; no cue repeats at a fixed interval inside the showdown (no "clock") |
| **T-H1** Frame | Rendered, 5 showdowns, screenshot at entry + 0.5 s | Exactly the 2 fighters' cards framed gold; ghost cards unframed; the frame gone within 0.3 s after STAGE_END |
| **T-H2** Overlap | The same shots plus one forced danger level 2 on a fighter and a held powerup | 0 px of overlap between the frame and the danger sticker, stock tab, +1 chip or held slot; the crimson danger border still visible inside the gold |
| **T-H3** Holder glint | eval-grant a golden tank | The glint plays on the holder's card only, stops within 1 frame of the tank ending |
| **T-H4** OFF parity | `showdown_enabled=false`, `tree` dump of a card after 5 stages | No `ShowdownCardFrame` node exists |
| **T-G1** Bubble size | Rendered screenshots of a live golden bubble on 5 arenas, including the widest and the closest play zoom | On-screen body diameter ≥ 1.0× the on-screen body of the nearest goat; halo ≥ 120 screen px and ≥ 1.8× the bubble body; collider radius (eval) = 43.2 ± 0.1 world px on every arena |
| **T-G2** Golden vs normal | A 20-frame contact sheet, mixed golden and normal Unlimited Boost bubbles at play zoom, art-director blind-labels | 20 / 20 |
| **T-G3** Contrast | 10 screenshots | Mean luma difference between the golden body ring and a 40 screen-px annulus around the halo ≥ 0.25 (0-1 scale), with the dim on |
| **T-G4** Holder read | A 10-frame burst during a golden tank | The holder is identifiable in 10 / 10 frames by rim + trail alone (HUD hidden) |
| **T-4c** Tie-break | eval places two fighters overlapping the bubble on its go-live frame: 20 placements with unequal distances, then 40 exact ties | Closer centre wins 20 / 20; exact ties split 12-28 either way; a dead or frozen fighter in the pair never wins |
| **T-5a / 5b / 5c** Camera | §2.7 | grep clean; replay ≤ 1 px and ≤ 0.001 zoom on every frame on 3 arenas; 0 off-viewport living-player frames in 5 live stages |
| **T-B1** Low-fuel seek | eval: CPU fuel 20 (< floor), bubble live 250 px away over ground, rival 600 px away; 10 trials | The CPU picks the seek on ≥ 35 % of decision ticks (p 0.5 expected), collects in ≥ 8 / 10 trials within 2.5 s, 0 self-KOs |
| **T-B2** Low-fuel void guard | The same, with the bubble 450 px away over void and fuel 20; 10 trials | The refuel dive 10 / 10; 0 self-KOs |
| **T-B3** Parity | `bot_golden_lowfuel_seek=false` | `_decide` order identical to the 169b-2 build (code review + a 20-drop log match on seek counts ± noise) |
| **T-C1** Claim | eval: a regular bubble placed on each spawner in turn, then force a golden telegraph at it; 20 cases | The regular bubble upgrade-pops at telegraph start 20 / 20; 0 frames with two bubbles within 100 px; 0 double grants; the regular director never telegraphs onto a claimed point (log over 40 showdown drops) |
| **T-C2** Held-UB guard | eval: the holder holds an Unlimited Boost and presses POWERUP during the golden tank | Nothing activates, the item stays, the deny feedback plays, the next golden drop is not telegraphed early (tank lock intact); after the tank ends the item activates normally |
| **T-S1** Surge OFF | `showdown_drop_arm_s=0` | The first golden super is possible on the frame after collect (as 169b-2) |
| **T-S2** Surge ON (for the re-check) | `=1.0`, 20 eval-granted tanks | 0 supers fire before 1.0 s ± 1 frame; boost is available on frame 1; fuel is pinned from frame 1; `t_first_super` logged |
| **T-10** Motion (WK-93 recording, viewed) | A 20 s+ showdown tail, MEADOW MILE | Both fighters converge on the telegraph within 2.0 s in ≥ 4 / 5 drops; no fighter's speed < 60 px/s for > 0.5 s; the dim never hides a goat; the holder's chase reads; plus a one-line felt verdict |
| **T-12** CD6 felt pass | Spec §12 T12, unchanged. **Q3 carries G9** | A "no" on Q3 routes to the §1.7 R2 follow-up |

---

## 4. Fantasy-fit and pillar check

- **Low floor:** gold thing appears, go get it. The holder's gold glow and HUD glint say who's dangerous without any text. GOLD SURGE (if it
  ships) teaches itself: "press super, dry click, rim still filling, wait".
- **Constant motion:** the race is a flight race. The low-fuel CPU fix keeps CPUs in it instead of diving away. GOLD SURGE leaves boost on, so
  nobody stalls during the arm window.
- **Physics comedy:** being smashed *into* the gold stays legal. The holder still self-KOs by over-committing (G3 guards it).
- **Death is cheap:** none of this lengthens anyone's wait beyond the lever's ~1 s delay, and 169b-2's S4 effect stands.
- **Readable chaos:**
  - the bubble gets bigger on screen without changing the collider;
  - one object per spawner;
  - gold, not red;
  - no clock, no countdown sound;
  - the camera is provably untouched.
- **Personality:** the ka-CHUNK, the bell, "GOLDEN TANK!" in the goat's colour, the deflating "pfff".
- **Core verbs:**
  - FLY: the race;
  - SUPER-SMASH: the gold is super frequency, and GOLD SURGE gives the race loser the first-strike window;
  - RECOVER: the holder's free recovery is unchanged, and the non-holder's gamble is untouched (no consolation fuel);
  - BOUNCE: the low-fuel CPU falls back onto a surface when it loses a race over ground.

## 5. Pushback recorded
- **"Just shorten the tank":** rejected with data (§1.1-§1.2). It's the knob the ladder named, but it isn't the mechanism. If CD6 disagrees,
  it's still next in line (R2).
- **A consolation refuel:** rejected. Pillar 2 / §4.3 economy and the recovery triad.
- **A bigger golden collider for readability:** rejected. It's gameplay drift (collection is already 100 %), and a zoom-dependent collider
  would let the camera change outcomes. Readability comes from art, the halo and the glint.
- **A heartbeat or drum loop for the hush:** rejected for 169c. No source exists, and a steady pulse reads as a clock (WK-170).
- **Building the ghost PUFF FASTER line "for later":** rejected. Presentation for a verb that's OFF teaches a lie.
- **Any showdown camera move:** still OQ-2 (owner), with the studio recommending no. T-5 proves we didn't sneak one in.

## 6. Proposed DECISIONS lines (for the director, when the items land; not written by this spec)
- "2026-11-16 WK-169c G9 RULING: `showdown_drop_dur` stays 6 s.
  - 76 % of golden tails end inside the first tank (median 2.6 s after the grab), and the holder leaves the tank with full fuel, so dur 4 is
    predicted at −0 to −4 pp.
  - The candidate lever is GOLD SURGE (`showdown_drop_arm_s`, the golden super arms 1.0 s after the grab), built OFF and re-checked on lane
    TG (spec `docs/specs/wk169c_showdown_polish_2026-11-16.md` §1.5-§1.7).
  - G9 stays a FLAG (band unchanged), judged by CD6 Q3."
- "2026-11-16 WK-169c RULES:
  - a golden drop claims its spawner (a regular bubble there upgrade-pops; the fair point never moves);
  - low-fuel CPUs seek a reachable golden bubble before refuelling;
  - a held Unlimited Boost can't be activated during a golden tank."
