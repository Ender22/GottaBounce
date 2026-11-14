# Game-design gap audit — 2026-11-14 (Lead Game Designer)

> **Trigger:** owner verdict after his latest play: *"kinda fun but more like a shitty prototype with a
> lot of weird things… probably 500 improvements we could make."* He will not be involved further; the
> studio runs unattended. **Lens:** the game design itself. What keeps a couch group playing for a whole
> evening, and where GottaBounce falls short. Controls/menus and the rendered playthrough are covered by
> other agents' audits, so they are referenced here only where they are load-bearing for design.
>
> **Method:** docs + code reading only (no game launch). Read: VISION, GAME_ESSENCE, ROADMAP, STATUS,
> DECISIONS, every file in `docs/feedback/`, `Tuning.gd`, all `src/modes/*`, `Player.gd` (contact/super/
> fuel paths), `PowerupSystem`/`PowerupSpawnDirector`, `InputHuman`/`InputBot` (powerup tick),
> `CharacterSelect`/`ModeSelect`/`MatchHUD`/`ScoreScreen`/`EdgeIndicators`/`ControlsLegend`,
> `Juice`/`AudioManager`/`EventBus`, `levels/*.json` structure, the change-control and game-feel skills.
>
> **Benchmarks:** Smash Ultimate, Duck Game, TowerFall Ascension, Brawlhalla, Gang Beasts, Stick Fight,
> Mario Kart. **Bias:** depth over widening. Fix the brawl you already have before adding anything new.
>
> **Protected values respected (flagged, never proposed for change):** hitstun triad
> (`hitstun_base/per_impulse/max`), un-charged super with no power scaling, `fuel_per_bumper` 20,
> `round_end_freeze` hard cap 2.0, `match_target_kills` 10 (owner-set), `dmg_launch_mult` (owner ruling
> 2026-07-19), camera framing rules (owner, 2026-07-10), between-stage ScoreScreen existence (owner),
> ModeSelect order (owner), Trials binary completion (owner), no round timer and no timer-SD (owner
> directive 2026-07-03), Gauntlet removed (owner).

---

## The one-paragraph diagnosis

The movement core is real. Bounce, fly and super are deep enough, and the CD verdicts and owner
both say it is "kinda fun". What makes it feel like a prototype is everything that wraps the core
loop and turns it into an *evening with friends*. **Three problems stack up:**
1. **The climax is invisible.** KOs happen past the camera's guard rect, so you see no blast, no
   killer, no score change. Combat shows no score at all.
2. **Identity is muddled.** Name tags, banners and chevrons use slot colors that disagree with the
   goat each player picked. The six heroes all play identically through a dead wire. The game says
   "last one flying wins", but surviving scores zero.
3. **There is nothing to vary or remember an evening by.** No team brawl, no house rules or variants,
   no awards, no session standings. There is also no quack/taunt, and dead players get nothing to do.

None of this needs new modes. Almost all of it is presentation, rules plumbing on top of the
existing `GameMode` seam, or data.

---

## Findings

Severity: **P0** core fun broken · **P1** clearly below the genre bar · **P2** notable · **P3** polish.
Each finding lists a **Verify** line: a measurable criterion QA can check by driving the game.

### D-01 — KOs happen off-camera: the punchline is never seen
- **Severity:** P0
- **Gap:** The camera is built so it can never show past the kill bounds
  (`PartyMatch._update_camera` "Outer guard: keep the visible rect inside the KILL bounds"). Camera
  bounds are platforms + 200px, while the blast lines sit 480–720px out at the sides
  (`bounds_side_*`), 2650px up (`bounds_top_margin`) and 670px down. `Juice._death_burst` spawns at
  `victim.global_position`, which is **outside the viewport by construction**. So a ring-out is shake,
  hitstop and a sound with nothing to see. The off-screen chevron simply vanishes.
- **Why it matters for a couch group:** In Smash and Brawlhalla the KO is a giant, player-colored
  blast column pinned to the screen edge where the fighter left, pointing back into the stage. It is
  the loudest visual in the game and the moment the room yells. Pillar 4 says "death is a punchline",
  and right now the punchline happens in another room. It also hurts readability (Pillar 5): with
  4 players you often can't tell *who* just died until the HUD card greys out.
- **Proposed change:** Add a `KOEdgeBlast` presentation node (a CanvasLayer under the HUD, subscribing to
  `KillPipeline.killed`). Project the victim's death position onto the viewport edge, using the same
  math as `EdgeIndicators._draw`. Spawn a screen-space blast there: a wedge/column of thick white
  cartoon streaks aimed inward, tinted with the **victim's** identity color (see D-03), with the
  victim's goat head popping out of it and a star burst. Art: one generated "KO blast" sprite strip
  (art-director brief). Variants by `_classify_blast_edge`: **top** = Smash-style "star KO", where the
  victim shrinks into the painted sky with a twinkle (about 0.8s, comedy). **sides/bottom** = edge
  column. **Hazard deaths inside bounds** keep the existing in-world burst. Keep the hitstop and shake.
  The blast plays during them.
- **Size:** S–M (one node + one art asset).
- **Risk:** None to feel. It is presentation only (INV-12) and the camera rules are untouched. Must
  not linger into the middle 60% of the screen (MatchHUD prime directive). Keep it under about 0.6s
  and anchored to the edge.
- **Verify:** Force 20 ring-outs across 3 arenas (all 4 edges) with a screenshot burst at kill+0.05s and
  +0.3s. In 100% of them a victim-colored KO effect is visible inside the viewport at the edge nearest
  the exit point.

### D-02 — Kill credit and score are invisible during play
- **Severity:** P0
- **Gap:** Brawl scores **only credited KOs** (+1), with self-falls at −1 (`BrawlMode.on_kill`).
  Credit often goes to whoever touched the victim up to 6s earlier (`kill_credit_window_ringout`).
  Nothing on screen says who got credit: there is no kill feed, no "+1", and no killer cue. The corner
  pips were removed (`PlayerCard.set_score` is a no-op, DECISIONS 2026-07-16), so combat shows **no
  score at all**. A −1 for falling is never shown when it happens. Historical credited share runs
  roughly 55–60% of deaths (Twin Moons 55%; session-3 memory "credited 25→59%"). So about 4 in 10
  deaths score nothing for anyone, silently.
- **Why it matters for a couch group:** The kill race is the win condition, and players can't see it
  move. Smash's timed mode floats "+1" and "−1" over fighters at the instant of a KO. TowerFall makes
  the killer obvious (your arrow, their skull). Duck Game keeps no in-round score, but every kill is a
  visible gunshot by a visible duck, and the round winner is obvious. Here a "kill" is often a
  delayed ring-out 3–5s after a hit, so it is the case that most *needs* attribution, and it has none.
  The owner's "weird things" plausibly include "why does he have 4 and I have 1?"
- **Proposed change (three parts, all presentation, no scoring change):**
  1. **KO credit pop:** On a credited kill, a chunky "+1" chip in the killer's identity color launches
     from the KO edge-blast (D-01) and flies into the killer's corner card. The card does a
     one-beat bounce and shows the new total for 1.5s, then hides again, which respects the owner's
     "no persistent score" ruling. A self-fall pops "−1 OOPS" in the victim's color, falling off the
     victim's card. A dead attacker still scores and gets a tiny ghost "+1".
  2. **Last-touch tag:** While a victim holds a live `last_attacker` (inside the credit window) and is
     in hitstun or off-stage, draw a thin ring in the **attacker's** color around the victim. This
     shows "whose kill this will be" without text. Read `Player.last_attacker`/`_attacker_timer`.
  3. **ScoreScreen kill list:** Add one line per stage under the race bars: tiny head icons
     "P2 ▶ P3 (smash)", "P4 fell −1". The data already exists in `round_stats[...].kills`.
- **Size:** M.
- **Risk:** Low. The owner ruled no persistent combat score readout. The pop is transient (≤1.5s),
  so it fits that ruling. Keep the chips out of the central 60% box.
- **Verify:** In a 4-bot match, every credited kill produces a killer-colored "+1" reaching the correct
  card within 1.0s (eval `scores` before and after, plus a screenshot). Every uncredited death
  produces a "−1" or "+0" cue on the victim card. 0 mismatches over 30 deaths.

### D-03 — Player identity colors contradict the goat each player picked
- **Severity:** P0 (cheap, and it breaks "who is who")
- **Gap:** Everything that identifies a player in combat uses **slot** color
  `PartyMatch.PLAYER_COLORS[i]` (P1 pink, P2 blue, P3 green, P4 yellow…). That covers name tags
  (`_pop_in`), stage banners ("P%d SURVIVES!"), FIRST BLOOD, match point, edge chevrons
  (`EdgeIndicators`), HUD card rims, ScoreScreen and VictoryScreen rows. The **body** wears the
  **picked skin**. If P1 picks Butch (blue) and P2 picks Pogo (pink), P1's chevron and banners are
  pink while P1 is a blue goat, and vice versa: fully inverted. Bots take free skins from
  `SKIN_ROSTER`, so a bot in slot 2 might be green-bodied with a blue tag.
- **Why it matters for a couch group:** Every benchmark binds one color to one player across body,
  HUD, pointer and banners. Smash uses port colors on the nameplate *matching* the costume tint in
  team battles, and TowerFall archer color is everything. Pillar 5 depends on "find yourself in 0.2s".
- **Proposed change:** Derive each player's display color from their **skin**. Add a
  `skin -> Color` table (CharacterSelect `HEROES` already holds the six exact colors) and pass
  `players[i].skin`'s color everywhere `PLAYER_COLORS[i]` is used (about 10 call sites, listed by
  grep). Name tags should read the hero name ("BUTCH"), with "P1" only as a small badge.
- **Size:** S.
- **Risk:** None to feel. Sports keeps its team colors via its own path.
- **Verify:** Run P1=Butch(blue), P2=Pogo(pink) with 2 bots. Screenshots of the name tags at pop-in,
  an off-screen chevron, the stage banner and a ScoreScreen row all show blue for P1 and pink for P2.

### D-04 — The game tells players to survive, then scores only kills
- **Severity:** P1
- **Gap:** The BRAWL card tagline and the VISION one-liner say **"Last one flying wins."** The stage
  end celebrates "P2 SURVIVES!". But BRAWL awards **0** for surviving
  (`PartyMatch._decide_stage_end`: "NO survival point in a kill-race"). Lethal hazards and
  self-destructs make about 40% of deaths score nothing (D-02). So a cautious survivor can win stage
  after stage and lose the match. New players read the tagline, play evasively, and get confused at
  the ScoreScreen. Playing evasively is exactly the behavior Pillar 2 is trying to prevent.
- **Why it matters for a couch group:** Duck Game, TowerFall (Last Man Standing) and Stick Fight all
  score the **round survivor**. TowerFall's kill-scored variant is a separate, clearly named mode
  ("Headhunters"). Groups learn the goal from the name and the banner. A win condition that
  contradicts its own messaging reads as "weird".
- **Proposed change:**
  1. **Messaging (no rules change, do now):** tagline → "Smash 'em off-screen. First to 10 KOs."
     (`ModeSelect.MODES`). Stage-end banner leads with the stage's KOs ("P2 +2!"), with the
     survivor as a sub-line. StageIntroCard on stage 1 states the rule line (see D-13).
  2. **RULES option (additive, owner default kept):** a `scoring` field on `MatchConfig` with
     `KO RACE` (default, today's behavior), `SURVIVOR` (+1 last one flying, Duck Game/TowerFall), and
     `HYBRID` (+1 per KO, +1 survivor). Implement it in `BrawlMode.on_kill` plus a survivor award in
     the stage-end hook. Add a stepper row in the settings tray.
- **Size:** S (messaging) + S–M (rule option).
- **Risk:** The default must stay KO RACE (owner directive 2026-07-03). **Flag for owner reversal
  (studio recommendation, not acted on):** HYBRID would likely make evenings better, because it
  rewards both play styles and keeps hazard-heavy arenas from stalling the race. Record it in
  DECISIONS as a candidate.
- **Verify:** With SURVIVOR, a stage the human survives with 0 KOs gives that human +1 (eval
  `scores`). With KO RACE, behavior is byte-identical to today (parity run over 10 stages).

### D-05 — The recovery gamble (the owner's favorite fun) happens off-screen
- **Severity:** P1
- **Gap:** The owner's 2026-07-03 thesis is that the fun is "get knocked, arc out, fight your way back".
  Under the owner camera rules, a player beyond camera bounds (platforms + 200) is shown only as a
  60px flat chevron (`EdgeIndicators`). Recovery arcs travel up to 2650px above the top platform, so
  the clawing-back moment is a colored triangle. Nobody can tell whether the victim has fuel, is
  aiming a super, or is doomed.
- **Why it matters for a couch group:** Smash solved this exact problem without moving the camera:
  an off-screen fighter appears in a **magnifying bubble** at the edge, with the bubble's size
  scaled by distance. You watch your friend's desperate recovery live. That is half of Smash's drama.
- **Proposed change:** Upgrade `EdgeIndicators` to a magnifier mode. Draw a circular bubble with a
  SubViewport or a re-rendered sprite of the player (goat head, facing, squash), a **fuel ring**
  around it, a red pulse when `damage_level>0`, and a flashing aim arrow while
  `is_super_aiming()`. The bubble shrinks with distance past the camera bounds. Keep the chevron
  tip pointing at the true position. Camera framing is unchanged.
- **Size:** M.
- **Risk:** None to feel or camera (presentation only). Screen space must stay in the edge band.
- **Verify:** Knock a player 1500px above the top platform. A screenshot shows a bubble at the top edge
  with the goat sprite and a fuel ring whose fill matches `get_fuel_ratio()` within 10%. When the
  player aims a super off-screen, the bubble shows the aim arrow within 1 frame.

### D-06 — In a 4-goat pile you can't tell who hit whom
- **Severity:** P1
- **Gap:** A landed smash flashes the victim white (`Juice._on_smashed` → `victim.flash()`) and shakes
  the screen. Nothing carries the **attacker's** identity. Launch streaks and tumble are uncolored.
  In a scrum the chain-credit rule (stunned bodies credit their launcher) is also invisible.
- **Why it matters for a couch group:** Smash tints hit sparks per player in team play. Brawlhalla
  colors hit effects by team. TowerFall arrows carry the shooter's color. "Who did that?!" should
  answer itself.
- **Proposed change:** Tint the smash impact burst and the victim's knockback streak (`_update_streak`)
  with the attacker's identity color for the duration of hitstun. This doubles as the
  "last-touch tag" from D-02. For chain hits, use the credited launcher's color.
- **Size:** S.
- **Risk:** Readability only. Keep streak luminance at or above the launch-telegraph floor (the flair
  rule `value >= 0.8`) so tinted streaks still read as "launch".
- **Verify:** Frame-grab 10 smashes. The impact burst hue matches the attacker's identity color in 10/10.

### D-07 — The super-aim telegraph has no audio and no "you're the target" warning
- **Severity:** P1
- **Gap:** Super AIM is the dodge window, and its telegraphy is sacred (game-feel §6). It is
  visual-only, though: the fuse ring plus arrow. There is no `super_aim_started` event and no aim SFX
  (`AudioManager.SFX` has `super_fire` only). The targeted player gets no cue unless they are
  watching the aimer. That breaks the Rule of Three on the single most important counterplay read.
- **Why it matters for a couch group:** Counterplay you can't perceive feels like randomness. Smash
  charge moves have a rising audio charge. TowerFall's arrow-catch works because the threat is
  readable. With 4 players and the camera zoomed out, the arrow is small.
- **Proposed change:** (a) Emit `EventBus.super_aim_started(player)` when entering AIM. Play a rising
  "wind-up" whine pitched to the 2.0s fuse, with a per-character goat bleat layered on fire (the
  owner's 2026-07-02 "goat scream" seed, see D-15). (b) **Target warning:** if the aim ray passes
  within 140px of an opponent inside `attack_range`-ish distance (about 1400px), pop a small "!" in
  the aimer's color over the targeted goat's head while the aim holds.
- **Size:** S.
- **Risk:** None to feel. Must not add delay or reveal more than the arrow already does. Bots may
  read the same signal (`dodge_super` already exists), so no unfair advantage.
- **Verify:** Over 10 scripted aims at a target, the "!" appears on the correct target in ≥9/10 within
  2 frames of the ray crossing it. `AudioManager.last_sfx == "super_aim"` on aim entry.

### D-08 — Dead players have nothing to do (Pillar 4: "sub-2s to next action")
- **Severity:** P1
- **Gap:** Default lives = 1 (owner). Once out, a player sits through the rest of the stage, the 1.4s
  freeze, the 3.4s ScoreScreen, about 1s of pop-ins and the 1.05s countdown. With stage medians of
  roughly 7–16s, the first player out waits about 15–25s for their next input, every stage. With 8
  players this is the main experience for half the room.
- **Why it matters for a couch group:** Party classics give the eliminated a toy. Bomberman has
  Revenge carts, Mario Kart 64 battle turns popped players into Bob-omb karts, and Gang Beasts
  players watch a short physics farce. Idle hands on a couch become phone hands.
- **Proposed change:** **Ghost goats.** On elimination, the player becomes a translucent ghost in
  their color. The ghost floats freely (drift only, no collision with players), can **quack/taunt**
  (D-15), and gets **one heckle per stage**: press powerup to drop a *slow-falling* bounce-puff (a
  0.5s-telegraphed, 180px marshmallow-tier puff that lasts 2s). It nudges a fight but is never lethal
  and gives no credit. Ghosts are excluded from camera framing and are drawn at 40% alpha behind
  living players.
- **Size:** M.
- **Risk:** Readability (Pillar 5): ghosts must never be mistaken for living goats, so use 40% alpha, a
  halo and no jetpack flame. Balance: heckles must not decide stages. Keep them non-lethal and
  non-crediting, and make them an option (`GHOSTS: ON/OFF/QUACK ONLY`).
- **Verify:** In a 4-player stage, an eliminated human produces input-driven ghost motion within 1.0s of
  elimination. Over 20 stages, heckle-puffs are present within 1.5s of 0 credited kills (they never
  directly decide a kill).

### D-09 — About 7 seconds of dead time between every stage
- **Severity:** P1
- **Gap:** Per-stage overhead is `round_end_freeze` 1.4 + `SCORE_HOLD` 3.4 + pop-in
  (`intro_pop_stagger` 0.2 × players + 0.2) + countdown 3×0.35, which is **≈6.9s** with 4 players.
  Against 7–16s stage medians, that is 30–50% of session time spent not playing. The accept-skip
  needs `menu_accept`/`ui_accept` after a 0.8s guard.
- **Why it matters for a couch group:** Smash has zero downtime between stocks. TowerFall's per-round
  tally is short and skippable, and Stick Fight flips to the next map almost instantly. Downtime is
  where couch energy dies.
- **Proposed change (owner's ScoreScreen kept):** Make `SCORE_HOLD` **adaptive**: 2.0s by default and the
  full 3.4s only when the lead changed, someone hit match point, or there was a tiebreaker. Let
  **any** player's FLY button skip after the 0.8s guard (players' hands are on FLY, not A-in-menu).
  Do not touch `round_end_freeze` (hard cap 2.0) or the iconic countdown.
- **Size:** S.
- **Risk:** Owner-directed screen, so only the hold length changes and the screen stays.
  DECISIONS names SCORE_HOLD as the knob.
- **Verify:** Median death→next-BOUNCE over 20 non-dramatic stages is ≤5.0s (was ~6.9s). Dramatic stages
  still hold 3.4s.

### D-10 — Character choice is cosmetic by accident (dead wire)
- **Severity:** P1
- **Gap:** `CharacterSelect._lock_in` writes `chars[_pick_idx] = "bouncer"` for **every** hero
  (CharacterSelect.gd:292). `CharacterProfiles.for_id("bouncer")` is the all-identity Standard
  profile, so Pogo/Butch/Ziggy/Puff/Vex all play like Billy. Bots are always `"character": "bouncer"`
  (`BrawlMode.spawn_plan`) even while wearing a hero's skin. Meanwhile DECISIONS 2026-07-05 says
  "roster now plays differently", STATUS says the Herd "PLAY differently", and the CharacterSelect
  blurbs promise identity ("Watch THIS recovery.").
- **Why it matters for a couch group:** Choice that secretly does nothing is the worst outcome. Either
  be Smash/Brawlhalla (choice matters, visibly) or be TowerFall/Duck Game (honestly cosmetic).
- **Proposed change:** **Wire it** (designer recommendation, because the deltas are small and data-only):
  `chars[_pick_idx] = str(h["id"])`, and bots get the profile matching their skin. Show two tiny
  stat pips under the blurb (e.g. POGO: BOUNCE+ / WEIGHT−) so the choice reads. Then re-run the v2
  feel-delta QA battery. It was validated on 2026-07-05, **before** the bounds rework,
  `boost_gravity_scale` 0.8 and the +25% `dmg_launch_mult`.
- **Size:** S (code) + S (QA re-validation).
- **Risk:** Pogo's `knockback_taken_mult` 1.10 now stacks with Lv0 ×1.25 (D-18), so Pogo may be the
  lightest kill. Re-check the profile on-read clamps. If QA fails, the fallback is to declare
  cosmetic and rewrite the blurbs as personality, not ability.
- **Verify:** Eval `players[i].profile.size_scale` matches the picked hero for all 4 slots. In the v2
  battery, no hero's self-fall rate exceeds the Standard rate by >1.5× over 40 stages.

### D-11 — No team play in BRAWL (2v2, couple-vs-bots)
- **Severity:** P1
- **Gap:** BRAWL is free-for-all only. Teams exist in Sports (`team` field, team skins, team-side
  respawn), but not in the flagship mode. The first real couch playtest was the owner and his wife,
  and "two of us vs the bots" or 2v2 is the most common couch setup.
- **Why it matters for a couch group:** Smash, Brawlhalla and TowerFall all ship team versus.
  Mixed-skill groups pair a strong player with a weak one, and couples play co-op against CPUs.
  Without it, the weaker player gets farmed.
- **Proposed change:** A `teams` field on `MatchConfig` (OFF / 2 TEAMS) plus a `FRIENDLY FIRE: OFF/ON`
  row. In `BrawlMode`: spawn the plan with teams, color teams via the Sports team skins (keep hero
  identity with a team-colored rim), make team KOs pool toward the target, skip `_handle_smashes`
  between teammates when friendly fire is OFF (a shove still applies, which is funny and harmless),
  and end the stage when ≤1 team is not eliminated. **Co-op vs CPU preset:** all humans on team A.
- **Size:** M.
- **Risk:** Medium. It touches the smash license (a teammate gate). Needs a spec with QA criteria.
  Chain-credit across teammates must not score own-team kills.
- **Verify:** In 2v2 with FF OFF, 0 smashes between teammates over 10 stages (eval `round_stats.smashes`
  attacker/victim teams). The stage ends at the first frame only one team is alive. Team totals sum
  the members' credited KOs.

### D-12 — No match variants or house rules: every match feels the same
- **Severity:** P1
- **Gap:** BRAWL settings are HUMANS / BOTS / BOT SKILL / KILLS / LIVES. There are no items switch, no
  gravity or speed modifiers, and no "chaos" toggles. Variety comes only from arena rotation.
- **Why it matters for a couch group:** TowerFall Ascension's long evening life comes largely from its
  dozens of **match variants** (toggled per match or randomized per round). Smash has item switches,
  stage hazards on/off and custom rules. Mario Kart has items presets. A group settles in for the
  night by finding "our rules".
- **Proposed change:** A `variants` list on `MatchConfig`, applied as **per-match Tuning overrides**
  (snapshot the Tuning values at match start and restore them at MATCH_END). Data in
  `levels/variants.json`. A starter set that only touches safe knobs:
  `MOON GRAVITY` (gravity ×0.6), `MEGA BOUNCE FOR ALL` (bounce_mult 1.5), `BOTTOMLESS TANKS`
  (fuel_locked all), `STAR RAIN` (pu_spawn_interval 3, weight star), `SUPERS ONLY` (no powerups),
  `TINY GOATS` (size_scale 0.8), `NO HAZARDS`, `ITEMS OFF`, plus `RANDOM VARIANT EACH STAGE`
  (announced on the StageIntroCard).
- **Size:** M.
- **Risk:** Variants must **never** touch the hitstun triad, `super_boost_impulse_full` or
  `fuel_per_bumper`. Hard-code a deny-list in the variant loader. INV-1 must hold, meaning plain boost
  can never reach `smash_impact_min` (validate `TINY GOATS` and `MOON GRAVITY` against it). Restoring
  Tuning on quit-to-menu must be bulletproof.
- **Verify:** Starting a MOON GRAVITY match gives `Tuning.gravity == 960`. Quitting to menu restores 1600
  (eval). The deny-list rejects a variant JSON that names `hitstun_base`.

### D-13 — Onboarding: the goal is never stated, and the legend disappears after 4s
- **Severity:** P1
- **Gap:** On stage 1 the `ControlsLegend` shows MOVE / FLY / SUPER SMASH / POWERUP for 4s into combat,
  then fades. **Nothing states the goal** ("knock them off-screen, first to 10 KOs"), which compounds
  D-04. Head-stomp, the red damage pulse (×2 launch), self-fall −1 and the boost-bounce supercharge
  are taught nowhere.
- **Why it matters for a couch group:** A first-timer must get both *how* and *why* in 30s. Mario Kart
  needs no words because the goal (finish line) is spatial. In a kill-race it is not. Gang Beasts and
  Duck Game teach in the lobby, where you play before the match. Smash and Brawlhalla rotate tips on
  loading screens.
- **Proposed change:** (a) Stage-1 StageIntroCard adds a rule line: "SMASH 'EM OFF-SCREEN · FIRST TO
  10 KOs". (b) Make the legend **per-player**: it holds until each human has used FLY and SUPER once,
  with chips ticking off in that player's color (cap 12s, and it never blocks play). (c) A one-line
  **tip** rotates on every StageIntroCard from `levels/tips.json` ("Land on a head to bounce higher",
  "Red pulsing goats fly twice as far", "Boost into a bounce = SUPERCHARGE"). Tips are suppressed after
  the first 3 matches in a profile.
- **Size:** S.
- **Risk:** None. It adds no time because it rides the existing intro window.
- **Verify:** On a fresh save, the stage-1 card shows the rule line (screenshot). The legend persists
  until each of the 2 humans has pressed FLY and SUPER, logged per player, or 12s.

### D-14 — No post-match awards or stats: nothing to laugh about afterwards
- **Severity:** P1
- **Gap:** VictoryScreen shows the winner bust plus race bars. The per-stage data needed for awards is
  **already collected** (`round_stats`: supers_fired with auto_fired, smashes with solidity and
  victim, kills with cause/blast_edge/off_stage, self-falls via score deltas, head-stomps via
  `bounced` events), but it is only used for QA.
- **Why it matters for a couch group:** TowerFall hands out post-match awards ("Comeback Kid" and others),
  and the room roasts each other over them. Smash's results screen sparks "how did you fall 9 times".
  Awards are a cheap "one more round" engine and a source of personality (Pillar 6).
- **Proposed change:** An `Awards` resolver run at MATCH_END over `round_stats`, data-driven via
  `levels/awards.json` (id, title, stat, comparator, flavor line). Show 3 awards (one per non-winner
  where possible) as cards on VictoryScreen after the bars. Seed list: **HEADBANGER** (most head-stomps),
  **KAMIKAZE** (most self-falls), **SNIPER** (highest mean solidity), **FUSE BURNER** (most auto-fired
  2s supers), **CLUTCH** (most off-stage survivals), **VULTURE** (most KOs on Lv2 victims),
  **COMEBACK KID** (won after trailing by ≥4).
- **Size:** S–M.
- **Risk:** None. Do not add time before REMATCH is armed: awards animate after `ARM_TIME` and
  fast-forward with the rest.
- **Verify:** Every finished 4-player match shows exactly 3 award cards, each with a stat that matches
  `round_stats` (spot-check 5 matches by eval).

### D-15 — No quack: Pillar 6 says taunts, and the game has none
- **Severity:** P1
- **Gap:** There is no taunt or emote verb (grep finds none). There is no character voice and no goat
  scream (the owner's 2026-07-02 seed). `super_fire` is a generic explosion. The announcer is music
  stings, not a voice. The powerup button doubles as `flap`, and Wings is deferred.
- **Why it matters for a couch group:** Duck Game's **quack button** is one of the most beloved party
  verbs ever made. It is pure social glue, and people quack at the scoreboard. Smash taunts exist to
  be disrespectful. Pillar 6 lists "taunts, reactions" explicitly.
- **Proposed change:** A `taunt` action on a free pad input (d-pad or a stick click; the controls audit
  owns the binding) → InputIntent `taunt` edge. The effect is a per-hero **bleat** (one goat sample
  pitched per hero, with ±8% random pitch), a 0.3s face/pose swap (reuse the squash pose until the
  expression art from D-27 exists), and a puff of the word "BAAA!" in their color. It is usable while
  bouncing (no movement lock, so Pillar 2 is fine), usable as a ghost (D-08), and usable on the
  ScoreScreen/VictoryScreen. Layer the same bleat on super fire (D-07).
- **Size:** S.
- **Risk:** Audio spam. Rate-limit to 1 per 0.4s per player and duck the bleat under the music bus.
- **Verify:** Pressing taunt gives `AudioManager.last_sfx` starting "bleat_" within 1 frame. It works in
  COMBAT, as a ghost and on the ScoreScreen. 10 presses in 1s produce ≤3 sounds.

### D-16 — 94 arenas and zero human fun pass: quantity outran quality
- **Severity:** P1
- **Gap:** The brawl expansion added about 71 arenas in one day via agents. Auto-QA confirms only that
  they "load, frame, float, spawn fair". STATUS itself says "~55 fresh arenas want a human fun pass."
  Most are islands-over-void variations. Circuits draw 12–14 per match, so every evening rolls
  through untested content. Nothing on screen tells players an arena's gimmick before it kills them.
- **Why it matters for a couch group:** TowerFall's arena sets are few, distinct and memorable ("the
  one with the lava"). A party remembers maps by their *hook*. Twenty interchangeable grass islands
  read as filler, which is part of "shitty prototype".
- **Proposed change:** (a) **Arena scorecard tool:** run N=10 4-bot stages per arena (L3 mixed) and write
  `tools/out/arena_scorecard.json` with median stage length, credited-KO share, self-fall share,
  hazard-death share, distinct killers, motion-health flags and min camera zoom. (b) **Cull/feature
  pass:** add a `"quality"` tier field to each pool entry in `circuits.json`. The draw prefers top
  scorers, and anything with credited-KO share <45% or a median stage >25s goes to
  re-tune-or-retire. (c) **Hook line:** a required `"hook"` string per arena JSON ("WATCH THE
  HAMMERS", "THE FLOOR CRACKS"), shown on the StageIntroCard under the name. This is JSON-only.
- **Size:** M (tool) + S per arena (JSON).
- **Risk:** None to feel. The bot scorecard is a filter, not a fun verdict. Top picks still need the
  human-style QA drive (GAME_ESSENCE).
- **Verify:** The scorecard exists for all 94 arenas. Each circuit's draw pool has ≥12 arenas passing
  the thresholds. 100% of arena JSONs carry a non-empty `hook`.

### D-17 — 8-player support is half-built
- **Severity:** P1
- **Gap:** The invariant allows humans+bots ≤ 8 (BOTS stepper 0–7). `MatchHUD` has **4** cards
  (`_cards = [Card0..Card3]`), so players 5–8 have no fuel or powerup readout. There are only 6 skins,
  so bots 5+ reuse colors (`_bot_skin`). STATUS lists "ScoreScreen row sizing >4 players" as open.
  VISION promises "track 4–8 players".
- **Why it matters for a couch group:** Two identical yellow goats with no HUD card each is the exact
  "readable chaos" failure Pillar 5 forbids. Smash's 8-player mode exists because every slot gets a
  unique color plus a nameplate.
- **Proposed change:** **Now:** cap BRAWL at 6 total (BOTS stepper max = 6 − humans) until identity
  scales. **Later (M):** 2 more skins (art), a compact 8-card HUD layout, and ScoreScreen rows that
  scale.
- **Size:** S (cap) / M (full).
- **Risk:** None.
- **Verify:** The BOTS stepper never lets humans+bots exceed 6 (UI drive). With 6 players, all 6 have
  distinct skins and HUD cards (screenshot).

### D-18 — The +25% knockback ruling silently changed the sting, escalation and hitstun rules
- **Severity:** P1 (strong evidence; it threatens the owner's recovery-gamble fun)
- **Gap:** `dmg_launch_mult[0]` went 1.0 → 1.25 (owner ruling). The multiplied impulse is what
  `receive_smash` reads for **three** other rules:
  1. **Sting/escalation gate** `impulse.length() >= smash_sting_min_impulse (1500)`. A baseline graze
     (launch floor 0.6 × 2200 = 1320) is now ×1.25 = **1650 ≥ 1500**, so **every eligible smash, even
     a pure graze, now stings fuel and escalates damage**. The v2 "glance-0 property" (grazes never
     sting or escalate, kill-zone spec §3.2/§12) is gone. Before, solidity s ≥ ~0.21 was needed.
  2. **Hitstun** = `0.15 + impulse×0.00025` capped at 0.55. A graze moves from 0.48s to the **0.55 cap**,
     so effectively every hit is now max hitstun. The triad *constants* are untouched, but the
     triad's *behavior* moved.
  3. **Runway math:** the side-bounds clamp (`bounds_side_max` 720, "never exceeds Lv0 band") was
     derived for a Lv0 center exit of about 2200 px/s. Lv0 center hits now exit at about 2750.
  So the knockback ruling probably made first hits deadlier in four ways, not one. Rounds may now
  one-shot, which is exactly what the 2026-07-19 DECISIONS watch item fears.
- **Why it matters for a couch group:** The owner's 07-03 feedback ("I never see a player get knocked
  at 45° and fly back") is the core fun. If every graze is max-stun plus Lv1 plus a sting, the
  scared-then-saved moment disappears again.
- **Proposed change (honors the owner ruling, since launch distance stays +25%):** Compute the
  sting/escalation gate **and** hitstun from the **pre-multiplier** impulse at Lv0, i.e. pass
  `impulse_pre_mult` alongside the impulse into `receive_smash`. Lv1/Lv2 keep the spec's
  multiplier-fed behavior. Then run the lethality QA battery (spec §9 tests 6 a–d, 11–15 and
  criterion 21 flee-to-heal). This is a mechanic-semantics fix, so it gets a designer ruling plus a
  DECISIONS entry. Do **not** touch the hitstun constants or the owner's array.
- **Size:** S (code) + M (QA).
- **Risk:** This is exactly the class of "fix that adds semantics" that change control warns about.
  Spec first, then build, then QA. If owner-intent reading is ambiguous, keep today's behavior and
  only run the QA, then report.
- **Verify:** Graze (s≤0.15) on a Lv0 victim gives `damage_level` 0 and `_last_sting_applied` 0, with
  hitstun ≈0.48s. Center hit: unchanged (Lv1, full sting, 0.55s). Over 40 stages, ≥50% of Lv0
  non-edge smashes on a victim with fuel ≥20 are survived (the recovery gamble is alive).

### D-19 — You can't see who is out of fuel (the key read for committing)
- **Severity:** P2
- **Gap:** Fuel lives only in the corner cards. Whether an opponent can super, counter or recover
  (`fuel < super_boost_min_fuel` = no escape super) is the central read of the sting→starve→kill
  design, and it has no on-body tell.
- **Why it matters for a couch group:** TowerFall shows each archer's arrow count **over their head**.
  That is why "he's out, GO!" is a shout in TowerFall.
- **Proposed change:** An on-body "dry tank" tell. While fuel < `super_boost_min_fuel` the jetpack
  sputters (black smoke puffs plus a rattling SFX loop at low volume). At 100% there is a brief
  "ding" glint. Put it in `Player._update_visual`, which reuses the `_smoke` emitter.
- **Size:** S.
- **Risk:** Visual noise. Show it only in the starved state.
- **Verify:** With fuel set to 3 (eval), the screenshot shows the sputter emitter active. At 50 it is
  inactive.

### D-20 — Powerups are unreadable, unswitchable, and ignored by bots
- **Severity:** P2
- **Gap:** There are 7 powerups (`PowerupSystem.SHIPPED`). They share **one** activation SFX
  (`pullOutItem`) and have no name callout on pickup (just a 32px icon overhead). There is no
  items on/off or frequency setting. Bots don't seek bubbles; they only use what they touch
  (`InputBot._tick_powerup`, "no seeking brain yet"). Counter Shield and Black Hole require knowing
  rules nobody is told.
- **Why it matters for a couch group:** Mario Kart's item icons are instantly recognizable, with
  distinct sounds. Smash has a full item switch with per-item toggles and frequency. Items should
  produce "oh no, he got STAR" moments, which needs everyone to *know* he got Star.
- **Proposed change:** (a) On pickup, a 0.8s name pop ("STAR!", "BLACK HOLE!") in the holder's color
  over their head, plus a per-item activation SFX (7 picks from the owner's SFX library). (b) An
  `ITEMS: OFF / LOW / NORMAL / HIGH` setting mapped to `pu_spawn_interval` 0/10/7/4 as a per-match
  override (D-12 plumbing), plus per-item toggles stored as WEIGHTS overrides. (c) A bot powerup
  brain v1: L3+ bots detour to a bubble within 600px when not finishing, and use Counter Shield
  when an opponent's super ray targets them (D-07 signal).
- **Size:** M.
- **Risk:** Bot detours must not create motion pathologies, so watch motion-health.
- **Verify:** Each powerup's activation sets a distinct `last_sfx`. ITEMS OFF gives 0 bubbles over 10
  stages. L4 bots collect ≥40% of bubbles in all-bot matches (was touch-only).

### D-21 — No comeback or handicap tools for mixed-skill groups
- **Severity:** P2
- **Gap:** Bots at L3+ deliberately target the leader (`leader_focus`), but humans get nothing. There
  is no handicap. Mixed-skill couples are the owner's own test group.
- **Why it matters for a couch group:** Mario Kart's position-weighted items and Smash's handicap
  exist so a new player stays in it. Without them the weakest player quits.
- **Proposed change:** (a) A **per-player handicap** row on each human's hero card, `STURDY` =
  `knockback_taken_mult` 0.90 (the CharacterProfile lever, within its on-read floor of 0.90). This is
  data-only. (b) An optional **CROWN BOUNTY** rule: the match leader starts each stage wearing a crown
  (the crown.png art order already exists), and KOing the crowned player is worth +2. Off by default
  in KO RACE, and it would be on in a "PARTY" preset.
- **Size:** S (handicap) / S–M (bounty).
- **Risk:** Bounty changes scoring math, so it is an option only, with the owner default kept.
  Handicap must not push below the profile floor of 0.90, so a clean centered super stays lethal.
- **Verify:** With STURDY on P1, `players[0].profile.eff_knockback_taken() == 0.90`. With bounty, a KO on
  the crowned player adds 2 (eval `scores`).

### D-22 — No session-level stakes across rematches
- **Severity:** P2
- **Gap:** REMATCH resets everything. Nothing records that P2 has won 3 of tonight's 4 matches.
- **Why it matters for a couch group:** Mario Kart's Grand Prix cup totals across races, and every
  friend group's informal "best of 5", are what make "one more" automatic.
- **Proposed change:** A `SessionTally` on GameConfig (cleared on app launch). Match wins per hero
  (keyed by skin, since slots shuffle) are shown as small trophy pips on VictoryScreen rows and
  CharacterSelect cards, with a "TONIGHT'S CHAMPION" crown on the leader.
- **Size:** S.
- **Risk:** None.
- **Verify:** After 3 rematches won by the blue hero, VictoryScreen shows 3 trophies on blue. Relaunching
  the app clears it.

### D-23 — Stage stalls have no non-timer breaker
- **Severity:** P2
- **Gap:** There is no round timer (owner directive). Bots have a finisher mode, and `idle_hunt_after`
  only punishes *zero input*. Two cautious humans in a 1v1 on a 3600px arena can drift indefinitely
  while 2 others watch.
- **Why it matters for a couch group:** Smash's sudden-death bombs and Stick Fight's falling weapons
  exist to force a resolution. Dead air with spectators is the worst party state.
- **Proposed change (respects "no timer ends a stage"):** **Escalation, not elimination.** After 20s of
  stage combat with no qualifying smash in the last 8s, `pu_spawn_interval` drops to 3s with
  chaos-weighted drops. After 30s, a **golden bubble** (Star) spawns at the stage center with a
  top-band callout "GOLDEN GOAT!". Nothing kills and nothing ends the stage.
- **Size:** S.
- **Risk:** Could read as a soft timer. Keep it *offers*, never forced. Check against owner directive §1:
  no timer ends the stage, and this doesn't.
- **Verify:** In a scripted 1v1 with no smashes for 30s, a golden bubble spawns between 30 and 31s.
  Stage-end causes are unchanged.

### D-24 — Head-on supers have no "clash" moment
- **Severity:** P2
- **Gap:** Two super_active goats meeting head-on resolve by "faster body wins", with instance-id
  tiebreak (`_handle_smashes`). Mutual supers, the most dramatic exchange, resolve invisibly or
  arbitrarily.
- **Why it matters for a couch group:** Smash's clank and TowerFall's arrow-catch turn a mutual attack
  into a skill moment and a shout.
- **Proposed change:** If both bodies are `super_active` and `velocity_a·velocity_b < −0.5·|a||b|`,
  trigger **CLASH**: both rebound at bumper restitution along the line of centers, with no hitstun,
  no sting and no credit. Add a big white star burst, a 0.1s hitstop and a "CLANG!". No fuel refund
  (heads are not refuel stations, per the head-bounce rule).
- **Size:** S–M.
- **Risk:** It touches the smash license. Needs a spec plus QA criteria 6 a–d to still pass.
- **Verify:** Over 10 scripted head-on super pairs, 10/10 produce CLASH with both victims at
  `damage_level` unchanged.

### D-25 — Built but invisible: tech and rules nobody will discover
- **Severity:** P2
- **Gap:** Supercharge (boost held through a bounce gives ×1.4 bounce and ×1.6 thrust, read only as a
  bigger flame), the head-stomp, the wall-return super chain, the 8s heal, self-fall −1, the
  flair ladder (CharacterSelect stepper, P1 only), and pity circuit unlocks.
- **Why it matters for a couch group:** "Low floor, high ceiling" (Pillar 1) requires the ceiling to
  be *findable*. TowerFall's dodge-catch is famous because it reads.
- **Proposed change:** (a) Supercharge feedback: a distinct "ka-CHING" spring SFX plus a gold ring
  burst at the contact (Juice, `bounced_juicy` with a supercharged flag). (b) Tips from D-13.
  (c) A **"BRAWL SCHOOL" Trials circuit** (JSON plus one passive dummy-goat target entity, which
  could reuse `Ball` with a goat sprite) teaching smash-to-ring-out, stomp, finishing a red goat and
  the wall-return shot. This is the bridge from Trials to Brawl.
- **Size:** S (a, b) / M (c).
- **Risk:** None.
- **Verify:** A supercharged bounce emits a distinct SFX id. BRAWL SCHOOL's 4 courses complete via
  injected human-style input.

### D-26 — Bots are faceless stand-ins
- **Severity:** P2
- **Gap:** There is only one skill setting for all bots (MIX or fixed). Bots are labeled "CPU", play
  the Standard profile in hero skins (D-10), have no powerup brain (D-20), don't use cannons or keys,
  and fly clumsily in orbital arenas (STATUS).
- **Why it matters for a couch group:** Smash sets CPU level per CPU. TowerFall and Duck Game bots are
  weak, but humans fill those lobbies. Here, bots fill most slots in small groups, so they need
  personality.
- **Proposed change:** Per-bot skill in the settings tray (a row per bot slot, MIX default). Bots get
  their hero's name and a playstyle bias via existing BotProfile dials (Butch = aggression+,
  Ziggy = recovery_skill+, Puff = commit_time−), which is data-only. Bots taunt after a KO at
  L3+ (D-15).
- **Size:** M.
- **Risk:** Dial changes alter L-ladder ordering, so re-verify "L4 beats L2".
- **Verify:** Over 10 all-bot matches L4 vs L2, L4 wins ≥70%. A bot's name tag shows its hero name.

### D-27 — Goats don't react: no hurt, panic or smug faces
- **Severity:** P2
- **Gap:** The poses are idle, squash and charge. Hitstun shows a spin, and Lv2 shows a crimson flush.
  There are no expression swaps for being stunned, near death, landing a KO or winning a stage.
- **Why it matters for a couch group:** Pillar 6. Gang Beasts and Duck Game get laughs from reactions,
  and Smash fighters wince, panic and gloat.
- **Proposed change:** 3 expression overlays × 6 heroes: DIZZY (hitstun), PANIC (Lv2 or off-stage
  with fuel <5), SMUG (1.0s after a credited KO). They swap via `_update_visual`. This is an
  art-director brief plus a generation batch, and is goat-gated like the super-aim poses.
- **Size:** M (art).
- **Risk:** Art consistency across 6 heroes. Batch with the pending super-aim pose ×6.
- **Verify:** Frame grabs show DIZZY during hitstun on all 6 skins.

### D-28 — No playable lobby: waiting while others pick
- **Severity:** P2
- **Gap:** The HUMANS stepper plus sequential hero picks means 3 people watch 1 person choose, with no
  way to try the controls before the match.
- **Why it matters for a couch group:** Duck Game's join screen gives each player a little room to run
  around in while others join. Gang Beasts' lobby is itself a toy. That is where first-timers learn
  FLY and SUPER with zero stakes.
- **Proposed change:** A "warm-up pen" behind CharacterSelect. Every joined pad spawns its goat in a
  shared bouncy pen (a no-kill, bounds-bouncing mini arena), and players press-to-join instead of
  using the HUMANS stepper. The menus audit owns the UI. This finding owns the design intent.
- **Size:** L.
- **Risk:** Large UI/flow change, so the depth-first rule says do it after the P0/P1 set.
- **Verify:** 4 pads join by pressing A in the pen, and each goat flies and supers while the others pick.

### D-29 — Mode menu dilutes the flagship
- **Severity:** P3
- **Gap:** ModeSelect order is TRIALS, BRAWL, ROCKETBALL, DROPSHOT (owner order). Two cards run one
  `SportsMode`, and neither sport has settings (goal cap fixed at 6, max 2v2).
- **Why it matters for a couch group:** The flagship should be the default choice. Every extra card
  is a decision a group has to argue about.
- **Proposed change:** Keep the owner's order. **Default focus** goes to BRAWL on first boot and to the
  last-played mode after that. Freeze sports widening and put that effort into BRAWL (D-01..D-18).
- **Size:** S.
- **Risk:** None (order unchanged).
- **Verify:** On a fresh save, the ModeSelect initial focus is the BRAWL card.

### D-30 — Progression is single-player in a couch game
- **Severity:** P3
- **Gap:** Flair rides **P1 only** (`_spawn_player`: `i == 0 and human`). It is unlocked by banked
  human KOs, but P2–P4 can never wear it.
- **Why it matters for a couch group:** Smash and Mario Kart unlocks are global to the console, so
  everyone at the couch enjoys them.
- **Proposed change:** A FLAIR row per human hero card. The unlocked set stays global.
- **Size:** S.
- **Risk:** Sports keeps its suppression.
- **Verify:** P2 equips GOLDEN JETSTREAM and their streak is gold in-match.

### D-31 — New verb-amplifying powerups (only after D-20)
- **Severity:** P3 (widening, so it is deliberately last)
- **Gap:** There are 7 powerups and the VISION target is 15–20. Several of the current ones are generic
  (Star, Ball Storm) rather than amplifying *this* game's verbs.
- **Why it matters for a couch group:** Duck Game's weapons each create a distinct situation.
  Variety is renewable fun, but only once the existing items read (D-20).
- **Proposed change:** Candidates that exercise BOUNCE/FLY/SUPER: **DOUBLE SUPER** (one free refire
  without a bounce, consumed on use), **SPRING DROP** (plants a 2s spring-tier pad under you, a
  bounce launcher anyone can use), **ANVIL** (5s: knockback_taken 0.6, gravity ×1.6, stomps launch
  victims at smash baseline, so head-stomp becomes a weapon), and **SWAP** (Duck-Game-style position
  swap with the farthest opponent, telegraphed 0.5s). Each one needs a mini-spec plus INV-1 checks.
- **Size:** M each.
- **Risk:** Each one touches lethality, so it gets a spec with QA criteria. ANVIL must not violate the
  head-bounce "no fuel refund" rule.
- **Verify:** Per spec.

---

## Counts

| Severity | Count | IDs |
|---|---|---|
| P0 | 3 | D-01, D-02, D-03 |
| P1 | 15 | D-04 … D-18 |
| P2 | 10 | D-19 … D-28 |
| P3 | 3 | D-29, D-30, D-31 |
| **Total** | **31** | |

Size mix: about 15 S, 12 M, 1 L, plus art batches. More than half of the P0/P1 set is presentation or
data with zero feel risk.

---

## Top 10 design moves in priority order

1. **Make the KO visible and credited (D-01 + D-02 + D-06).** Screen-edge KO blast, "+1/−1" credit pop
   flying to the card, and attacker-colored hits. This is the climax of the core loop, and today it
   happens off-camera and anonymously.
2. **One player = one color everywhere (D-03).** Derive the display color from the picked skin. It's an S
   fix for the most basic "who is who" failure.
3. **Fix the +25% knockback side effects, then re-run lethality QA (D-18).** Gate sting, escalation and
   hitstun on the pre-multiplier impulse at Lv0 so the owner's knockback ruling stops silently killing
   the recovery gamble.
4. **Tell players the actual goal and add the rules option (D-04 + D-13).** Fix the tagline, banner and
   stage-1 rule line now. Add the KO RACE / SURVIVOR / HYBRID option with the owner default kept.
5. **Show the recovery (D-05).** Smash-style magnifier bubbles with a fuel ring, without touching the
   owner's camera.
6. **Give the dead something to do and cut downtime (D-08 + D-09).** Ghost goats with quack and a
   heckle, plus an adaptive ScoreScreen hold so Pillar 4's "death is cheap" is true again.
7. **Add the quack, the aim wind-up and the goat scream (D-15 + D-07).** The cheapest charm and
   counterplay win in the game.
8. **Team BRAWL and co-op vs CPU (D-11).** The most common couch configuration isn't supported in the
   flagship mode.
9. **Match variants and items switch (D-12 + D-20b).** TowerFall-style house rules give an evening its
   variety at near-zero content cost, through per-match Tuning overrides with a deny-list for the
   protected constants.
10. **Curate the 94 arenas, wire the roster, finish with awards (D-16 + D-10 + D-14).** Score and cull
    the arenas with a bot scorecard plus a per-arena hook line. Either wire the hero feel deltas or
    honestly declare them cosmetic. End matches with TowerFall-style awards built from the
    `round_stats` the game already collects.

**Explicitly NOT recommended this weekend:** new modes, more arenas, or more sports courts. Depth-first:
the brawl that exists needs to read, credit, vary and charm before anything widens.
