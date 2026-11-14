# WK-37a: Ghost goats. What eliminated players do while they wait (2026-11-14)

**Owner:** game-designer (spec) · **Builds it:** gameplay-programmer (WK-37b) · **Art brief:** art-director (before build) ·
**Verifies:** qa-playtester + creative-director (WK-CD3 felt pass) · **Gate:** `scope-check` on this spec (new system), per BACKLOG WK-37.
**Inputs read:** BACKLOG WK-37/37a/37b/53/26 · audit D-08, D-09, D-15 (`docs/audit/2026-11-14_game_design_gaps.md`) · CD1 + CD2 playthroughs ·
DECISIONS (2026-07-03 lives/kill-race/SD owner directive, 2026-07-10 camera owner rules, 2026-07-19 knockback +25 %, 2026-11-14 WK-95
flight ruling + HOT rule + weekend autonomy (c)) · `docs/feedback/owner_2026-07-03_lives_damage_killrace.md` ·
`docs/feedback/owner_2026-07-10_camera_rules.md` · GAME_ESSENCE · skills game-feel-reference + change-control ·
`KillPipeline.gd`, `PartyMatch.gd` (`_on_killed`, `_decide_stage_end`, `_sudden_death_revive`, `_update_camera`), `BrawlMode.gd`,
`Player.gd` (`mark_dead`, `_on_bounced`, `receive_shove`, `kill`), `Tuning.gd`, `InputIntent.gd`, `MatchConfig.gd`, `DropTile.gd`.
**Scope:** BRAWL only. SPORTS respawns everyone (lives 99) and TRIALS never eliminates, so neither ever has a ghost.

---

## 0. The problem, in numbers

- **LIVES 1 is the default, and the owner ruled it** (2026-07-03). Dead = out for the stage. That stays.
- CD2: the human-sim P1 was **dead for 48 % of all combat frames** (4,378 dead vs 4,671 alive). The stage median was 11.6 s.
  Between-stage time is still about 30 % of a match.
- CD1: a group that raised LIVES to 3 "to play longer" waited *longer*. P3 was out about 30 s in and then watched a 1v1 for over a minute.
- D-08: the first player out waits about 15-25 s for their next input, every stage. Pillar 4 says "sub-2s to next action".
  Today a dead player has **zero** actions until the next BOUNCE.

Idle hands on a couch become phone hands. Every party classic gives the eliminated a toy:
- **Mario Kart 64 battle:** popped players become Bob-ombs that can still blow up the living, but can't win.
- **Super Bomberman 3 onward:** Revenge Carts throw weak bombs from outside the wall, and they're removed at Sudden Death.
- **TowerFall:** the "Return as Ghosts" variant.
- **Duck Game:** rounds are so short that dead time barely registers, and you quack at the survivors.

## 1. Player fantasy

> *"I got blasted off the screen, and two seconds later I'm a see-through little goat ghost floating back in, bleating at the guy
> who killed me. I drop a puff cloud over his head right as he climbs back up. BONK. He has to burn fuel to save himself and
> everybody screams. Next stage I'm back in the fight."*

The ghost is a **heckler with one rotten tomato**, not a second life:
- You can always **move** (float), always **make noise** (bleat), and **sometimes do one thing that matters** (the puff).
- The puff **can help or hurt.** It's a bouncy cloud, so it can bonk a climber down *or* catch a falling, fuel-dry goat and refuel them.
  That ambiguity is what keeps it a party toy and not a griefing tool. "The ghost SAVED me" is as good a story as "the ghost got me".
- **The living still decide the game.** A ghost can never score, never take a point away, never touch the super, and never touch the
  recovery gamble once someone has been smashed.

### Core-verb fit (GAME_ESSENCE obligation)
Ghosts don't BOUNCE, FLY or SUPER themselves. They are the meta layer that keeps the room playing. The spec still ties into the verbs,
and §8 measures that it doesn't damage them:
- **BOUNCE:** the puff cloud is a bounce surface (marshmallow tier). It obeys the same contract as every other surface.
- **FLY / RECOVER:** an underside bonk taxes about 5 fuel and 0.16 s (worked in §2.3). That pressures the fuel economy without
  deciding it.
- **SUPER-SMASH:** a super punches straight through a cloud and pops it. Ghosts can't block, deflect or soften the kill move
  (owner WK-95 ruling: "super = attack").
- **Measured guardrail:** the living players' boost share, super purpose mix and stage length must not move beyond the bands in §8.4.

---

## 2. The ghost verb set

### 2.1 Becoming a ghost
- **Trigger:** a player is **eliminated** (`lives_left` reaches 0) in BRAWL COMBAT, and GHOSTS is not OFF.
  - In a multi-life match there's no ghost between lives; the 1.0 s respawn path is unchanged.
- **Timing:** the ghost appears `ghost_spawn_delay` (0.6 s) after the elimination and pops in over `ghost_pop_in_time` (0.3 s).
  It takes input from frame one of the pop-in, so the player is **controllable 0.6-0.9 s after death**. Pillar 4 is met, with a 0.1 s
  margin under BACKLOG's ≤ 1.0 s.
- **Why 0.6 s and not 0:**
  1. It must be greater than `double_ko_window` (0.5). A double-KO revives both players into SUDDEN DEATH, so a revived player must
     never have become a ghost first.
  2. The KO edge blast (WK-23) needs about half a second to read as the punchline before the ghost rises out of it.
- **Where:** at the death position, clamped into the **current camera view** (inset `ghost_view_inset`). Since every ring-out
  happens beyond the blast line, in practice the ghost **rises from the screen edge where its KO blast went off**. That continuity
  reads as "you went out there, now you float back in".
- **Who:** the same player index, the same device. Gameplay keeps reading only `InputIntent` (INV-8), so humans and bots are
  interchangeable here too.
- **Data model rule (camera-critical, §4):** the fighter stays `is_dead() == true` for the rest of the stage. The ghost is a
  **separate presentation-plus-input entity** owned by the match. It is never a revived `Player`, never in the living set, never on
  the player or bounce-surface collision layers, and never a target for any bot, super aim, "!" marker (WK-26) or edge chevron.

### 2.2 FLOAT: always on
- The stick moves the ghost freely in 2D. There's no gravity and no collision with anything: platforms, walls, players, hazards,
  balls or bubbles.
- Max speed is `ghost_max_speed` 600 px/s. Holding FLY (A / Space) is **hurry**: ×`ghost_hurry_mult` 1.5 = 900 px/s.
  Acceleration is `ghost_accel` 2400 px/s², so you reach full speed in 0.25 s. With the stick released, `ghost_damp` 4.0 /s
  settles the ghost in about 0.5 s.
- **Rationale (FEEL_REFERENCE / Tuning):**
  - 600 is above air drift (340), so it feels free, not stuck in mud.
  - At couch scale 600 world px/s × zoom 0.46-0.62 is only 280-370 screen px/s, so ghosts glide; they don't zip. Readability
    beats speed (Pillar 5).
  - Hurry at 900 crosses a typical 0.55-zoom view (about 3,490 world px) in about 3.9 s.
  - A ghost never needs to outpace a fighter; it needs to get to the fight.
- **Motion signature (the readability hook):** ghosts **glide and bob**, with a sine bob of `ghost_bob_amp` 6 px at
  `ghost_bob_hz` 0.8. They never squash, never bounce and never thrust. Living goats *never stop bouncing* (INV-11). So **motion
  alone** separates the dead from the living, even before alpha does.
- **View clamp:** each frame the ghost's position is clamped to the camera's visible rect, inset `ghost_view_inset` (60 **screen**
  px, converted by the current zoom). When the camera pans or zooms, the ghost is gently swept along. It is never off-screen, and
  it never moves the camera (§4).

### 2.3 PUFF: the one thing that matters (cooldown-gated)
**Input:** SUPER (X / K) **or** POWERUP (B / L). Both buttons do the same thing, which is forgiving for a newcomer who just
learned "X does the thing".

**What it is:** a small **puff cloud** in the ghost's colour, spawned just below the ghost (`ghost_puff_spawn_offset`).

| Phase | Duration | Behaviour |
|---|---|---|
| **Telegraph** | `ghost_puff_telegraph` 0.5 s | A dotted outline in the ghost's colour inflates. It's **non-solid** and the readable warning. Same doctrine as the super fuse: the dodge window is sacred. |
| **Solid** | `ghost_puff_life` 2.0 s | A **marshmallow-tier bounce surface**, `ghost_puff_size` 180 × 64 px. It sinks at `ghost_puff_sink_speed` 120 px/s. |
| **Fade** | `ghost_puff_fade` 0.25 s | Non-solid, alpha → 0, then removed. |

**Who it affects (the containment rules, all deliberate):**
1. **Living players in neutral control only** collide with it, using the standard surface contract (BounceResolver plus
   `_on_bounced`, unchanged):
   - **Top side:** marshmallow launch (120 px apex, ≈ 620 px/s, 0.39 s to apex). Refuel is the standard tier-scaled
     `20 × sqrt(120/270)` ≈ **+13.3 fuel**. Boost-through supercharge applies as normal.
   - **Underside:** the standard reflect with **no refuel** (the existing underside guard, Player.gd `_on_bounced`).
2. **A `super_active` body passes straight through and POPS the cloud.** Its velocity is unchanged, the cloud is removed with a
   pop VFX, and nothing else happens. A ghost can never block, deflect or soak a super.
3. **A body in hitstun (`_stun_timer > 0`) passes straight through and pops it, unchanged.** Rationale:
   - The recovery triad (hitstun → no mid-air refuel → fuel-gated recovery) is the protected skill-heart of the game.
   - A ghost must not catch a launched victim (stealing the attacker's earned KO) or redirect one (gifting it).
   - This is the same doctrine as the dry-reflect ruling: "hitstun ends by TIME, never by touching a surface."
4. **Nothing else collides:** not balls, bombs, storm balls, debris, powerup bubbles or other clouds. Ghosts can't trigger
   explosions or move props by proxy.
5. **A player overlapping the cloud when it turns solid** is ignored by that cloud until they've fully separated. There are no
   spawn-inside pops or teleports.

**The nudge, quantified (why it can tip the balance but never kill directly):**
- An underside bonk sends a climber down at about 620 px/s.
- Normal boost (accel 5400 against gravity 1600) cancels that in **≈ 0.16 s**, costing **≈ 4.6 fuel** and about 50 px of height.
- So a bonk is lethal only to a goat that is *already* nearly dry and *already* over the void.
- An attentive goat with fuel shrugs it off. The top side mostly helps (+13 fuel, a free hop).

**Charges:**
- The first puff arms `ghost_puff_arm_delay` 1.0 s after the ghost appears. That gives time to find yourself on screen and blocks
  an instant revenge puff in the same exchange.
- Then the cooldown is `ghost_puff_cooldown` 7.0 s. One charge is held at most.
- The cap is `ghost_puff_max_per_stage` 3. Each ghost has one live cloud at a time.
- **Typical LIVES 1 stint** (median stage 11.6 s, first death at about 3-5 s, so about 7-8 s as a ghost): **one puff, sometimes two.**
- **A long LIVES 3 1v1** (60 s): three puffs, then float and bleat only. That keeps a long 1v1 from turning into a cloud storm.
- **Dud press** (cooling down, capped, hushed or blocked): a tiny grey "fft" wisp with no sound and no charge spent.
- **Spawn blocked by static geometry:** if the cloud rect would overlap a platform, try nudging it up to 120 px upward. If it's
  still blocked, it's a dud with no charge spent.

### 2.4 BLEAT: always on (needs WK-53, see §9)
- **Input:** TAUNT, the WK-53 binding (pad Y [3]; keyboard per CC-2.2 / WK-53).
- **Effect:** the hero's bleat sample, ghost variant (§9), plus a "BAAA!" word puff in the ghost's colour at 60 % alpha with a
  wobble.
- **Rate limit:** shared with WK-53, at most one per `ghost_bleat_min_interval` 0.4 s and at most 3 per second. Bleats never hush;
  they're pure noise and never touch the sim.

### 2.5 Tiny haunt effects (cosmetic only; tier 2, ship after the core if cheap)
None of these touch physics, credit or input. Each is a single reaction.
- **Ghost passes through a living goat:** the living goat's eyes go wide for 0.3 s (the face swap from D-27 when that art exists).
  No shiver and no displacement, so it can never read as a hit.
- **Ghost passes through grass tufts or a bubble:** a sway or wobble.
- **"+1 FROM BEYOND!":** if a ghost is credited a kill through the *existing* rules (it smashed someone before dying, and the victim
  dies later inside the credit window), the ghost does a celebration bleat and a "+1" pops at the ghost. Scoring is **unchanged**;
  this is presentation of a rule that already exists ("dead attackers still score", PartyMatch `_on_killed`).

### 2.6 What ghosts deliberately do NOT get (pushback list)
- **No revive.** Not Bomberman's "hit someone to come back", not TowerFall co-op corpse revives. It would break the owner's LIVES 1
  ruling and make elimination meaningless.
- **No kill credit, ever.** No score changes, no damage levels, no fuel sting, no hitstun, no `last_attacker` writes.
- **No direct shove.** A pure push is pure griefing. The cloud is ambivalent by design.
- **No interaction with the super or with stunned bodies** (§2.3 rules 2 and 3).
- **No camera influence** (§4).
- **No pickups,** and no effect on hazards, props or balls.

---

## 3. Anti-kingmaker rules

"Kingmaking" means an eliminated player deciding the outcome between the living. In a KO race the outcomes that matter are:
1. who gets **credit** for a KO;
2. whether a player **loses** a point (self-KO −1 under the current R0 rule; WK-20c may change this);
3. the **match-winning KO**.

Each one is fenced:

| Rule | What it guarantees | Precedent |
|---|---|---|
| **K-1 No ghost credit.** A cloud never writes `last_attacker` and never appears in `KillPipeline.killed` as an attacker. | A ghost can't score. | Mario Kart Bob-ombs can't win. Hazard-shove fence (`receive_shove`). |
| **K-2 Haunted deaths cost nothing.** If a living player dies with **no credited attacker**, and their last surface contact in the previous `ghost_puff_fence_s` (2.0 s) was a ghost cloud, the death is **HAUNTED**: no killer is credited (killer index stays −1, i.e. none), the victim takes **no self-KO point penalty**, and the death is flagged `haunted: true` in `round_stats`. | A ghost can't take a point away. | |
| **K-3 Living credit stands.** If a living attacker already holds credit (`last_attacker` within `kill_credit_window(_ringout)`), the kill credits them exactly as today. The cloud neither steals nor creates credit. | The attacker who earned the tag keeps it. | Existing hazard-assist rule. |
| **K-4 Stunned and supering bodies are immune** (§2.3). | Ghosts can't catch or redirect a launched victim, and can't block a super. The decisive moments of a KO belong to the living. | Dry-reflect doctrine. |
| **K-5 MATCH POINT hush.** While any not-eliminated player's next credited KO would win the match (`BrawlMode.match_winner` with a hypothetical +1 returns them), puffs are disabled. Live clouds pop within 0.2 s. The ghost's puff ring turns grey with a "shh" glyph. The top band shows "MATCH POINT · GHOSTS HUSH" once per stage. Float and bleat continue. | The match is never won with a ghost's help: kingmaker rate on the match decision is **0 by construction**. | Bomberman removes Revenge Carts at Sudden Death. |
| **K-6 SUDDEN DEATH hush.** The same hush applies throughout `SUDDEN_DEATH` (the double-KO 1v1 revive). | The only SD (owner-ruled) is decided by the two revived fighters alone. | Same. |
| **K-7 Caps.** One cloud per ghost, 3 per stage, 7 s cooldown, 0.5 s telegraph. | Ghost influence stays rare and visible. | |

**Why ghosts may still affect the last two survivors (the "TWO LEFT" 1v1), apart from K-5 and K-6:** the 1v1 is where ghost time is
longest and the heckle is worth the most to the room. Shutting ghosts off exactly when they're most bored would gut the feature.
Rules K-1 to K-4 already keep a ghost from deciding a KO directly. The thing worth protecting absolutely is the **match** decision,
and K-5 does that. Revenge-haunting your killer in their 1v1 is the intended social payoff (Bomberman's revenge). It's measured, not
banned (§8, KM-5).

**Self-KO rule independence:** K-2 holds under any WK-20c outcome. Under Ra (self-KO costs 0) it's simply moot.

---

## 4. Camera rule compliance (owner rules 2026-07-10, the acceptance spec)

Ghosts must not change framing. The owner has raised the camera about 5 times; this is non-negotiable.

1. **Ghosts are not players for framing.** `_update_camera` builds its set from `players` where `not p.is_dead()`. The eliminated
   fighter stays dead (§2.1 data model), and the ghost entity is not in `players`. **Rules 2, 3 and 6 are unchanged byte for byte.**
2. **Clouds are not focus points.** `BrawlMode.camera_focus_points()` stays `[]`.
3. **Ghosts follow the camera, never the reverse.** The view clamp (§2.2) means a ghost is always visible to its owner without
   asking the camera to frame it.
   - This is the *only* way to satisfy both "the ghost's owner must see their ghost" (Pillar 5) and "frame = extreme living
     players' clamped positions" (owner rule 3).
4. **Clouds spawn only inside (visible rect ∩ camera_bounds),** because they spawn at the ghost. A cloud that sinks out of the view
   is irrelevant and is despawned on crossing the kill bounds.
5. **No camera shake from ghost verbs.** The puff pop and bleat add zero trauma. Trauma is for the living (smash, super, KO).

**Acceptance (T3 below):** the camera target and zoom are identical (≤ 1 px, ≤ 0.001 zoom) with ghosts sweeping the view corners
versus ghosts parked. There are 0 frames where a ghost is outside the viewport.

---

## 5. Visuals and readability (Pillar 5: readability beats prettiness)

The rule: **a ghost must never be mistaken for a living goat, and must never hide one.** Art-director brief required before build
(WK-37b). Targets:

| Property | Living goat | Ghost goat | Rationale |
|---|---|---|---|
| Alpha | 1.0 | `ghost_alpha` **0.40**; **0.25** (`ghost_alpha_near`) within `ghost_near_radius` 250 px of any living goat | Ghosts recede near fights so they never occlude the action (4-8 players mid-storm). |
| Colour | skin colour | **same hue** (one player = one colour, D-03) with a soft white rim/halo | Identity carries over: "the blue ghost is P2". |
| Scale | 1.0 | `ghost_scale` 0.85 | Smaller reads as "lesser presence". |
| Jetpack flame / streak / shadow | yes | **none.** Instead a wispy tail in the skin colour. | Flame = alive and dangerous (D-08). |
| Motion | never stops bouncing; squash & stretch | glide + 6 px bob; **no squash, no bounce** | Motion is the first read at couch distance. |
| Face | normal set | a dedicated ghost expression (big round eyes, open "O" mouth). Placeholder: the existing face plus a halo until art exists. | Personality (Pillar 6). |
| Draw order | above platforms, below VFX | **below every living goat**, above platforms and clouds | Never on top of a fighter. |
| Name pip | P# pip | P# pip at full alpha for 2 s after spawn and whenever the ghost moves after 1.5 s idle; otherwise 50 % | "Where am I?" without clutter. Pip text obeys the 28 px floor (WK-18). |
| Puff-ready read | n/a | a tiny cloud orbits the ghost when a puff is ready, and the HUD card shows a ring filling over the cooldown | Rule of Three for the one verb that matters: ghost body + HUD card + the telegraph on use. |

- **HUD card:** the skull (`MatchHUD.set_dead`) becomes a **ghost head plus a puff cooldown ring** when GHOSTS is ON or BAA ONLY.
  In BAA ONLY there's no ring. With GHOSTS OFF the skull stays.
- **Puff cloud look:** a fluffy white body at 85 % alpha with a 6 px outline in the ghost's colour (screen-space width, divided by
  zoom, per the fuse-ring lesson) and the ghost's tiny face on it.
  - The telegraph is the same outline, dotted, inflating.
  - It must not read as a level platform. It's rounded, it sinks, it wobbles and it carries the owner's colour.
  - On screen it's 83-112 px wide at zoom 0.46-0.62, which reads at couch distance.
- **Ghost legend:** on becoming a ghost, one line appears for 3 s near the player's HUD card, in device-aware glyphs via the
  existing ControlsLegend/PadGlyph: **"GHOST!  (stick) FLOAT · (X) PUFF · (Y) BAA"**. In BAA ONLY the PUFF item is dropped.

---

## 6. Bots as ghosts

Bots must be charming ghosts, not CPU kingmakers. The policy lives in the bot provider and reads the same `InputIntent` surface (INV-8).

- **Float:**
  - Pick a hover spot `bot_ghost_hover_dist` 500 px from the living-fighter centroid, on the side the bot died, inside the view
    inset.
  - Re-pick every 3-5 s (uniform).
  - Keep at least 200 px from other ghosts, so they never stack.
  - Drift there at 0.6 × ghost speed, with no hurry.
- **Bleat:**
  - Ambient: Poisson with mean interval `bot_ghost_bleat_mean_interval` 8 s.
  - Reactive: with probability `bot_ghost_react_bleat_p` 0.5, bleat 0.3-0.8 s after any KO.
  - Never more than the shared rate limit.
- **Puff:**
  - Rate: the effective cooldown is `ghost_puff_cooldown / bot_ghost_puff_rate_mult` (0.5, so 14 s). In a typical LIVES 1 stint a
    bot ghost puffs **0-1 times**.
  - **Target choice is uniform random among living players.** No leader-focus and no human-focus. A systematic rubber band would be
    CPU kingmaking.
  - Placement is 250-350 px ahead of the target's velocity, at the target's height ±100 px.
  - Never puff during a hush.
- **Difficulty:** none. Ghost behaviour is the same at L1-L5. Bot skill is execution quality for *fighting* (BotProfile doctrine),
  and a smarter heckling bot is not a feature.
- **Living bots treat clouds as transient:**
  - A cloud is never a "safe ground" target for retreat, refuel or HOME logic, and never counts in `_over_void` reachability.
  - A bot that is bonked recovers through its normal danger path.
- **Motion health:** bot ghosts are excluded from `bot_motion_health()` (they're not fighters). A separate `ghost_motion` check
  logs stuck ghosts (zero displacement for more than 6 s while not at a hover spot) and must be 0.

---

## 7. Stage length and pacing (should rounds end faster? sudden death?)

**Ruling: ghosts change nothing about how a stage ends.**
- **No new sudden death, no ghost-driven squeeze, no timer.** The owner's 2026-07-03 directive removed timer/laser SD and limits SD
  to the simultaneous double-KO.
  - A "ghosts fill a meter that ends the round" mechanic is a timer SD in a costume. Rejected.
- **No TowerFall-style end delay.** TowerFall's ghost variant *doubles* the delay from the last kill to the round's end while ghosts
  are alive. We must not lengthen anything; `round_end_freeze`, the score hold and the countdown are untouched.
- **Stage length is WK-20a's lever, not this spec's.**
  - CD2 shows stages are *too short* (median 11.6 s, 4 of 12 under 10 s), not too long. Shortening them further to cut dead time
    would make the blowout problem worse.
  - Ghosts attack the **cost** of being dead instead of its duration. That's the right fix under LIVES 1.
- **Interaction to watch:** clouds can save a dry goat (top-side refuel) or bonk one (underside tax).
  - Net effect predicted: stage length −3 % to +5 % (P-G6).
  - Guardrail: stage-length median within ±10 %, and P(stage > 30 s) up by no more than 3 pp. If it breaks, use the §8.5 knobs.
- **Interstitial (the other ~30 %):** ghosts end at STAGE_END. During the KO freeze they hold still and fade with it. They don't
  exist on the ScoreScreen.
  - The WK-53 bleat works on the ScoreScreen, so the dead (and everyone else) keep a toy through the interstitial.
  - Further interstitial cuts are WK-21/41 (done) and WK-20a.
- **If WK-20a lengthens stages** (e.g. a lethality ruling), ghost time goes up. The puff cap (3) and cooldown (7 s) already bound
  that. Re-check P-G3 if the median stage goes above 20 s.
- **LIVES 3 long 1v1s** (CD1): ghosts make the wait playable, and K-7 caps keep it from becoming a cloud storm. Whether a 60 s 1v1
  at LIVES 3 is too long is a separate pacing question for WK-20a and the producer. It's not solved here, and not by an SD.

---

## 8. Tuning constants, predictions, acceptance tests

### 8.1 Tuning constants (all in `src/core/Tuning.gd`, a new `# --- WK-37 ghost goats ---` block)

| Constant | Value | Rationale |
|---|---|---|
| `ghost_spawn_delay` | 0.6 s | > `double_ko_window` 0.5 (an SD revive never un-ghosts); the KO blast reads first; spawn + pop ≤ 1.0 s (BACKLOG accept). |
| `ghost_pop_in_time` | 0.3 s | Matches the intro pop feel. Controllable from its first frame. |
| `ghost_max_speed` | 600 px/s | > air drift 340 (free); ≈ 280-370 screen px/s at play zoom (glides, doesn't zip). |
| `ghost_hurry_mult` | 1.5 | 900 px/s on FLY held: crosses a 0.55-zoom view in about 3.9 s. |
| `ghost_accel` | 2400 px/s² | Full speed in 0.25 s. Responsive, still floaty. |
| `ghost_damp` | 4.0 /s | Settles in about 0.5 s with the stick released. Never drifts off on its own. |
| `ghost_bob_amp` / `ghost_bob_hz` | 6 px / 0.8 Hz | The "alive but dead" idle. Visibly not a bounce (no squash). |
| `ghost_view_inset` | 60 screen px | Keeps the ghost fully on screen and off the hard edge. Divided by zoom at runtime. |
| `ghost_alpha` / `ghost_alpha_near` | 0.40 / 0.25 | D-08's 40 %; recedes near fights. |
| `ghost_near_radius` | 250 px | About 2.3 H. A fight's personal space. |
| `ghost_scale` | 0.85 | Lesser presence. |
| `ghost_puff_arm_delay` | 1.0 s | Orientation; no same-exchange revenge. |
| `ghost_puff_cooldown` | 7.0 s | About 1 puff per typical LIVES 1 stint (7-8 s). |
| `ghost_puff_max_per_stage` | 3 | Bounds long 1v1s (LIVES 3). |
| `ghost_puff_telegraph` | 0.5 s | A readable warning. Longer than the 0.2-0.35 s human reaction (WK-20a H2). |
| `ghost_puff_life` | 2.0 s | About 2-3 marshmallow hops (0.78 s each). Can't be camped (Pillar 2). |
| `ghost_puff_fade` | 0.25 s | Non-solid exit. |
| `ghost_puff_size` | Vector2(180, 64) | D-08's 180 px. About 1.6 H wide: hittable, not a floor. |
| `ghost_puff_sink_speed` | 120 px/s | Sinks 240 px over its life. A moving, temporary thing, not a platform. |
| `ghost_puff_tier` | &"marshmallow" | The lowest tier: 120 px apex, ≈ 620 px/s, +13.3 fuel. Gentlest possible effect. |
| `ghost_puff_spawn_offset` | Vector2(0, 70) | Just below the ghost body, so the ghost visibly "drops" it. |
| `ghost_puff_fence_s` | 2.0 s | Haunted-death window (K-2). Well under `kill_credit_window_ringout` 6.0. Covers a bonk → fall. |
| `ghost_bleat_min_interval` | 0.4 s | Shared with WK-53 (D-15 rate limit). |
| `ghost_hush_at_match_point` | true | K-5 switch (A/B and safety). |
| `bot_ghost_puff_rate_mult` | 0.5 | Bot ghosts puff half as often. |
| `bot_ghost_bleat_mean_interval` | 8.0 s | Charming, not spammy. |
| `bot_ghost_react_bleat_p` | 0.5 | Reacts to about half of KOs. |
| `bot_ghost_hover_dist` | 500 px | Near the action, out of the fight's personal space. |

**Rules option (not Tuning):** `MatchConfig.ghosts` is an enum, **ON (default) / BAA ONLY / OFF**.
- It lives on the RULES panel back (WK-07) and persists per mode like the other RULES fields.
- **OFF must be byte-for-byte today's behaviour:** skull card, no ghost entities, no clouds.
- The labels say BAA, not QUACK. We're goats.

### 8.2 Telemetry (added to `round_stats` per stage; MatchRecorder logs the same)
- `ghosts: [{idx, human, t_elim, t_spawn, t_first_move, ghost_s, controllable_s, input_active_s, puffs: [{t, pos, hushed_dud,
  contacts: [{player, t, side: "top"|"under", fuel_before, survived_3s}]}], duds, bleats, hushed_s, max_offscreen_frames}]`
  - `input_active_s` = time with |stick| > 0.2 or any ghost button pressed in the last 0.5 s.
  - `controllable_s` = time from the first pop-in frame to STAGE_END.
- **Per death** (in the existing `kills` entries): `haunted` (bool, K-2) and `dt_last_cloud_contact` (s, 9999 if none).
- **Per stage:** `ghosts_mode`, `hush_entered_t` (or −1), `clouds_spawned`, `clouds_popped_by_super`, `clouds_popped_by_stun`.

### 8.3 Predictions (written before any build or data; QA reports hit or miss for each)

| ID | Prediction |
|---|---|
| P-G1 | Elimination → first controllable ghost frame: **0.6 s** (always ≤ 1.0 s). First input-driven displacement ≥ 150 px within 0.5 s of a held stick. |
| P-G2 | Controllable share of each eliminated player's in-COMBAT dead time: **85-90 %** at LIVES 1 (today: 0 %). |
| P-G3 | Clouds per stage (3 HumanSim-newcomer + CPU, LIVES 1): **0.8-1.5**. |
| P-G4 | Living contacts per cloud: **0.3-0.6**. Most clouds miss; it's a nudge, not a weapon. |
| P-G5 | KM-1 (haunt-assisted credited KOs) **1-4 %**; KM-3 (stage-deciding haunted elimination) **≤ 3 %**; KM-4 (match-winning KO with cloud contact) **0**. |
| P-G6 | Median stage length change versus GHOSTS OFF: **−3 % to +5 %**. |
| P-G7 | Living bots' boost share and super purpose mix (WK-95 telemetry) change by **< 3 pp**. |
| P-G8 | Rescues (top-side contact by a player with fuel < 15 who survives ≥ 3 s): **≥ 1 per 10 stages**. The toy really is two-sided. |

### 8.4 Acceptance tests (QA-verifiable by driving the rendered game)
Measurement validity:
- Display awake (≈ 120 fps).
- All durations are **game time** from `phase_log.tick_s` / `round_stats`, never wall clock across a screenshot burst (CD2-05:
  each 1080p `gbplay screenshot` stalls about 1.25 s).
- Judge motion from WK-93 recordings.

**Mechanics**
- **T1 Spawn and control.** 10 human eliminations across 3 devices (pad 0, pad 1, keyboard):
  - The ghost entity exists ≤ 1.0 s after elimination, 10/10.
  - Holding the stick from the eliminated device moves it ≥ 150 px within 0.5 s, 10/10.
  - Its spawn position is inside the viewport inset, 10/10.
- **T2 Device isolation.** While a ghost exists, 5 s of full input from every *other* device moves it 0 px (bob excluded: compare
  the bob-free position). Pause freezes ghosts and clouds.
- **T3 Camera invariance (owner rules).** Script: 2 living bots frozen in place and 2 ghosts.
  - Phase A: ghosts parked mid-view, 3 s. Phase B: ghosts swept to the 4 view corners at hurry speed, 5 s.
  - Camera `global_position` differs by ≤ 1 px and zoom by ≤ 0.001 between A and B, every frame.
  - Then live 4-player play, 5 stages: **0 frames** with an in-bounds living player off-viewport (the existing owner-rule check) and
    **0 frames** with a ghost centre outside the viewport (`max_offscreen_frames` = 0).
- **T4 Cloud contract.** Scripted per row, 10 trials each, all within tolerance:
  - (a) Telegraph: a goat overlapping the cloud during the first 0.5 s has unchanged velocity.
  - (b) Top-side neutral contact: vertical launch 620 px/s ±5 %, fuel +13.3 ±0.5.
  - (c) Underside neutral contact: reflected downward, fuel +0.
  - (d) A `super_active` body passes through. Speed changes < 1 % across the contact frame, the cloud is removed, and
    `clouds_popped_by_super` increments.
  - (e) A hitstunned body passes through. Speed changes < 1 %, fuel +0, `_stun_timer` is unaffected and the cloud pops.
  - (f) Ball, bomb and bubble pass through.
  - (g) The cloud is gone at 2.75 s ±1 frame after the press.
  - (h) Cooldown, arm delay and the stage cap of 3 are honoured. The 4th press is a dud with no charge spent.
- **T5 Credit fence.** 20 scripted haunts with a 0-fuel neutral bot bonked into the void, no prior attacker:
  - 20/20 deaths are `haunted: true` with no credited killer (killer index −1), and the victim's score is unchanged (under R0).
  - 10 more where a living attacker tagged the victim 1-3 s earlier: 10/10 credit the living attacker, with exactly +1.
  - Across everything: **ghost credited kills = 0**.
- **T6 Hush.** Set a living player to target−1 at stage start (eval):
  - Puffs are duds for the whole stage, 0 clouds spawn, the top-band line shows once, and the HUD ring is grey.
  - Raise the score to target−1 mid-stage while a cloud is live: the cloud is gone within 0.2 s.
  - Force a double-KO SD: puffs are duds throughout `SUDDEN_DEATH`.
  - Over 20 full matches: **0 match-winning KOs with `dt_last_cloud_contact` ≤ 2.0** (KM-4).
- **T7 Edge cases.**
  - Double-KO revive never shows a ghost for the revived pair: `ghost_spawn_delay` > the decision window, verified on 5 forced
    double-KOs.
  - LIVES 3: no ghost until the final life is lost.
  - Spawn inside a platform is nudged up or becomes a dud, never embedded.
  - A goat overlapping a solidifying cloud isn't popped out.
  - MATCH_END and STAGE_END remove all ghosts and clouds before the ScoreScreen.
  - SPORTS and TRIALS never create a ghost (eval across one stage of each).
- **T8 Options.** RULES shows GHOSTS ON / BAA ONLY / OFF.
  - The choice persists across a relaunch.
  - BAA ONLY: puff presses are duds, 0 clouds, and the legend omits PUFF.
  - OFF: `round_stats` has no `ghosts` key with content, the skull card is shown, and the node count matches a pre-WK-37 baseline.

**Readability (rendered, looked at)**
- **T9 Still sheet.** 20 random combat frames with ≥ 1 ghost and ≥ 2 living goats, half-res.
  - The art-director classifies every goat as living or ghost: **20/20 correct**.
  - Plus eval checks: ghost modulate alpha is 0.40 (0.25 within 250 px of a living goat), the ghost's z order is below every
    living goat, and no flame or streak node is visible on a ghost.
- **T10 Motion.** A WK-93 recording, 30 s, 3 HumanSim + 1 CPU, GHOSTS ON (`tools/out/rec/wk37_ghosts_*`), contact sheet viewed:
  - Ghosts glide and bob with no vertical bounce reversals.
  - Ghosts never sit on top of a living goat.
  - Every puff telegraph is visible for ≥ 12 frames (0.4 s at 30 fps).
  - Write a one-line felt verdict.

**Bots**
- **T11 Bot ghosts,** over 20 stages:
  - Stuck ghosts (`ghost_motion`) = 0.
  - Pairwise ghost distance ≥ 200 px in ≥ 90 % of sampled frames.
  - Bot puffs per bot-ghost-minute are within ±25 % of `60 / (ghost_puff_cooldown / bot_ghost_puff_rate_mult)` (≈ 4.3/min, before
    caps and hush).
  - Target distribution: no living player receives > 50 % of bot-ghost clouds when 3 or more are alive (χ² vs uniform, p > 0.05).
  - 0 puffs during a hush.
  - Living bots never pick a cloud as retreat or refuel ground (log check).

**Pacing and kingmaker (A/B, pre-registered)**
- **T12 A/B batch.** 3 HumanSim-newcomer (WK-20a §6.2 presets, plus a ghost layer) and 1 CPU on MIX.
  - **40 stages**, GHOSTS ON vs OFF alternating by stage parity (the WK-20a pattern; balances the arena bag).
  - The HumanSim ghost layer: float toward the nearest living fighter at a 300-600 px standoff; puff as soon as armed with
    probability 0.7, placed 300 px ahead of a random living target; bleat Poisson 1 per 5 s.
  - **Pass bands:**
    - Median stage length within ±10 % of OFF; P(stage > 30 s) within +3 pp; credited KOs per combat-minute within ±10 %; SD rate
      within ±3 pp.
    - **KM-1** ≤ 5 % of credited KOs (credited KO where the victim's last cloud contact came after its last received smash and
      ≤ 2.0 s before death).
    - **KM-2** haunted deaths ≤ 0.15 per stage.
    - **KM-3** stages whose final elimination is haunted or KM-1-assisted ≤ 5 %.
    - **KM-4** = 0 (from T6).
    - Rate at which the stage survivor is the current score leader: within ±5 pp of OFF.
  - **Report only (fun signals):**
    - **KM-5 revenge share:** the fraction of a ghost's cloud contacts that land on its own killer.
    - Rescues (P-G8).
  - **Core-verb guardrail (P-G7):** living bots' boost share and supers by purpose within ±3 pp of OFF.
- **T13 Dead-time controllability.** From T12's ON stages:
  - Median `controllable_s / in-COMBAT dead time` ≥ **0.80** per eliminated player.
  - A puff is available at least once in ≥ 80 % of ghost stints ≥ 3 s.
  - `input_active_s / controllable_s` ≥ 0.6 for HumanSim ghosts. That's a plumbing check: HumanSim always plays. **Real
    engagement can't be measured without humans** (see T15).
- **T14 Performance.** 3 ghosts and 3 live clouds: frame time is within +0.3 ms of the GHOSTS OFF baseline; 120 fps held with the
  display awake.
- **T15 Felt pass (WK-CD3, creative-director).** One full default Brawl with 3 human-style seats. Answer in plain language:
  1. Within 2 s of dying, did I have something to do?
  2. Did I ever lose track of which goat was alive?
  3. Did a ghost ever decide a KO in a way that felt cheap?
  4. Did the puff ever save someone?
  5. Is the bleat funny or noise?

  Any "no" on 1, a "yes" on 2, or a "yes" on 3 is a FIX regardless of T1-T14.

### 8.5 Post-QA tuning knobs (apply in order; one variable at a time, FEEL_REFERENCE §0)
- **KM-1 or KM-3 over band:** `ghost_puff_cooldown` 7 → 10, then `ghost_puff_max_per_stage` 3 → 2, then `ghost_puff_life`
  2.0 → 1.5.
  - **Never** add credit. Never make clouds affect stunned or supering bodies.
- **Clouds irrelevant** (contacts per cloud < 0.15 and rescues = 0): `ghost_puff_size` 180 → 220, then `ghost_puff_life`
  2.0 → 2.5.
- **Stage length over +10 %** (rescues prolonging stages): set the top-side refuel on clouds to 0. The bounce still launches.
  That's a new boolean `ghost_puff_refuels` (default true).
- **Ghosts read as clutter** (T9 below 20/20, or the T15 Q2 "yes"): `ghost_alpha` 0.40 → 0.32, then `ghost_near_radius`
  250 → 350.
- **Ghost time boring** (T15 Q1/Q5 say so, even with puffs): don't raise puff frequency. File a follow-up spec for a second
  *cosmetic* toy (the §2.5 haunt effects), keeping the sim fence intact.

---

## 9. Dependency: the bleat (WK-53)

The bleat is half of the ghost's charm (it's Duck Game's quack button). WK-53 owns:
1. **The `taunt` action:** an `InputIntent.taunt` edge, the binding (pad Y [3]; a keyboard key per CC-2.2), and the device-aware
   glyph.
2. **The per-hero bleat samples:** one CC0 goat sample pitched per hero ±8 % (ruling b2; licence in `assets/sfx/LICENSES.md`).
3. **The rate limit** (0.4 s, ≤ 3 per second).
4. **The "BAAA!" word puff visual.**

WK-37b adds only the **ghost variant**:
- the same sample +3 semitones, with a short echo/low-pass ("ghostly"), via a pre-rendered variant or an audio bus effect;
  `AudioManager.last_sfx` starts with `"bleat_ghost_"`;
- the word puff at 60 % alpha with a wobble.

**Sequencing recommendation to the producer:** pull **WK-53 (S) before or alongside WK-37b.**
- If WK-37b lands first, it builds the shared `taunt` intent, binding and word-puff visual itself, and ships with the **audio
  skipped**. No placeholder beep: a fake sound is worse than none (the "real game from day one" rule).
- WK-53 then only adds samples.
- GHOSTS ON is fully playable without the bleat (float + puff), but T15 Q5 can't pass until WK-53 lands.

Other links:
- **WK-26** (super-aim "!") must skip ghosts as targets. They aren't in the living set, so nothing should be needed, but verify.
- **WK-31** (HUD danger and stocks) shares the HUD card with the ghost ring. Coordinate the layout.
- **WK-20c** (self-KO ruling): K-2 holds either way.
- **WK-28** (controller disconnect): a disconnected human's ghost idles in place (bob only) until reconnect. No bot takeover of a
  ghost.
- **D-11 / team Brawl (future):** in teams the cloud's ambivalence becomes partisan (rescue your teammate). Re-run KM-1 and KM-3
  before enabling ghosts in team modes.

---

## 10. Fantasy-fit check (GAME_ESSENCE, run before "done")
- **Is the core fantasy still happening for the living?** Guarded by T12's core-verb band and T4(d)/(e): supers and stunned bodies
  are untouched.
- **Is Pillar 2 safe?** Clouds last 2 s and sink, so they can't be camped. Ghosts aren't fighters.
- **Is Pillar 4 now true for the dead?** It's controllable at 0.6 s (T1/T13).
- **Is Pillar 5 safe?** T9 classification, proximity fade, and draw order below the living.
- **Does Pillar 6 get a voice?** The bleat (WK-53 dependency).
- **Would a first-time human understand it?** The 3 s ghost legend plus the obvious motion difference. T15 asks.

## Proposed DECISIONS entry (for the Director to log when WK-37b is accepted; not written by this spec)
"GHOST GOATS (WK-37). Eliminated BRAWL players become ghosts: float, bleat, and a cooldown-gated, telegraphed marshmallow puff
cloud. Ghosts:
- never score, never cost a point (HAUNTED deaths cost nothing), never affect stunned or supering bodies, and never move the
  camera;
- are hushed at MATCH POINT and in SUDDEN DEATH.

No stage-end change: no ghost squeeze and no added delay (owner SD ruling stands). Option GHOSTS ON / BAA ONLY / OFF, default ON.

Reopen if:
- KM-1 > 5 % or KM-3 > 5 % after both §8.5 knobs;
- a CD felt pass reports a ghost-decided KO felt cheap;
- the owner reverses LIVES 1 (ghost time changes)."

## Sources (genre references)
- TowerFall "Return as Ghosts" variant: the last-kill-to-round-end delay doubles while ghosts are alive, and ghosts can open chests
  (Dark World changelog via search). [TowerFall: Dark World (MobyGames)](https://www.mobygames.com/game/109489/towerfall-dark-world/),
  [TowerFall Dark World (VideoGameGeek)](https://videogamegeek.com/videogame/177950/towerfall-dark-world)
- Bomberman Revenge Carts: eliminated players throw bombs from outside the wall. In Super Bomberman 3 a cart fires one weak bomb
  at a time and carts are removed at Sudden Death.
  [Konami SBR Online manual](https://dds.konami.com/games/manual/sbro/en/page04.html),
  [Hardcore Gaming 101: Super Bomberman 3](https://www.hardcoregaming101.net/super-bomberman-3/),
  [Bomberpedia: Super Bomberman R](https://bomberpedia.shoutwiki.com/wiki/Super_Bomberman_R)
- Mario Kart 64 battle Bob-ombs, Duck Game's quack and short rounds, and Gang Beasts spectating: as cited in audit D-08 and D-15
  (`docs/audit/2026-11-14_game_design_gaps.md`).
