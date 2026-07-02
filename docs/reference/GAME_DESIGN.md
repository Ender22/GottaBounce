# GottaBounce — Game Design Document

> **Status:** Concept / early planning. Living document.
> **Last updated:** 2026-06-21
> **One-liner:** A physics-based, side-view multiplayer party game where cute jetpack creatures are *always bouncing* — aim your jetpack boosts to smash rivals off the stage (without flinging yourself off too). Last one bouncing wins.

---

## 1. Elevator Pitch

GottaBounce is a fast, silly, physics-driven party brawler. Think **Duck Game's** frantic 10-second rounds and "death is a punchline" energy, crossed with **Smash Bros'** knock-'em-off-the-stage combat — but there are **no guns and no shooting**. Instead, the whole world is made of **bouncy surfaces** (trampolines, springy pads, squishy stuff), and your character **never stops bouncing**. You win by using physics, momentum, and powerups to send everyone else flying off the screen.

**Closest reference for feel:** Duck Game (frantic, funny, short rounds, local + online + AI).

---

## 2. Design Pillars (what we are protecting)

These are lifted from what makes Duck Game work, adapted to bouncing:

1. **Low floor, high ceiling.** Anyone understands "bounce around and boost into people" in 5 seconds. Mastering fuel management, super-boost aim/timing, and powerup tech takes much longer.
2. **Constant motion = constant tension (INVIOLABLE RULE).** **Every surface in the game is either a bounce surface or a hazard; standable/solid ground does not exist anywhere** — you can never land and stand/camp on a platform, and bounce-powered fuel (§4.3) means you can't turtle. The pressure never lets up.
   - **Scope (clarified):** the rule is about **surfaces and turtling** — *no standable ground, no resting/camping indefinitely.* It does **NOT** forbid a brief, active, **temporary powerup** state that holds you airborne for a couple seconds (e.g. **Wings**, **Black Hole** channel). Those are short, committed, can't be used to camp, and don't break the pillar. What's banned is *standable ground / passive indefinite rest*, not transient airborne abilities. (This still cut the "Sticky Feet / cling to a surface" idea — that was passive camping.)
3. **Emergent comedy from physics.** Ragdolls, chain-reactions, and silly knockbacks should generate their own funny moments. The game tells the jokes.
4. **Death is cheap and funny.** Sub-2-second respawn into the next round. Getting launched should make people laugh, not rage.
5. **Readable chaos.** High-contrast characters and clear surfaces so you can track 4–8 players mid-storm. Never sacrifice readability for prettiness.
6. **Personality everywhere.** Emotes/taunts, squashy animations, reactions — the equivalent of Duck Game's "quack."

---

## 3. Core Loop

```
one-by-one spawn intro → "BOUNCE!" → ~10–30s of bounce-combat (everyone 1 life) →
score the round (kills + survival − suicides) → leaderboard on the loading screen →
next stage → ... repeat until someone hits 10 points → winner!
```

- **Round length:** target **10–30 seconds** (Duck Game runs ~8–10s; ours may run slightly longer because eliminations come from positioning, not instant one-hit kills).
- **Scoring (Party — decided):** **+1 per kill** (smashing a rival off / into a hazard), **+1 for surviving** the round (being the last one bouncing), **−1 for a self ring-out** (accidental suicide-boost off the map). This beats pure last-one-standing — it rewards *aggression* and *survival* while punishing reckless self-destructs. The near-simultaneous-death tie is resolved by **Sudden Death** (see §7 Mode 1). (Open tuning: floor score at 0 or allow negative? — decide later.)
- **Match length:** **first to 10 points** takes the match.
- **Stage rotation:** stages are grouped into **themed circuits** (§7 Mode 1); a match picks one circuit and plays its stages in a **shuffled order** (repeating the cycle if needed) until first-to-10. Aim for high variety so no two rounds feel the same (Duck Game ships 80–100+ stages total).

---

## 4. Core Mechanics

> **Characters:** cute creatures with **oversized jetpacks**. The jetpack is the primary way you
> influence your character — bouncing is passive, thrust is active.

### 4.1 The Bounce (passive base layer)
- Characters **bounce automatically and continuously** off surfaces — there is no "stand" or "walk" idle state, and **no surface anywhere lets you stop**: every tile is a bounce surface or a hazard (§6). The character is *always* in motion.
- Bounce height is set by the **surface tier** you land on (marshmallow → bubblegum → trampoline → spring; see §15). Reading and chaining surfaces is part of mastery.
- **Minimum bounce floor:** every bounce surface always launches you to at least a **minimum height**, even if you arrive nearly motionless. There is no way to "settle" or decay to a stop — the surface always kicks you back up. This guarantees the no-standing-still rule holds even at low speed.
- **Slight air drift:** pressing left/right nudges your trajectory a *little* — enough to fine-tune where you land, but not enough to fly. Real directional power comes from the jetpack.

### 4.2 The Jetpack (active control — the heart of the game)
Two thrust controls, both **aimable in any direction** (up, down, sideways, diagonal):

- **Normal Boost** — sustained, controllable thrust. Burns through a full tank in **~3.5 seconds** of continuous use. The workhorse: steer your arc, climb, and especially **recover back to a platform** when you've been knocked toward the edge.
- **Super Boost** — dumps your **entire remaining fuel** in a single **~0.3s** burst. A huge, violent launch in the aimed direction. This is the primary offensive/aggressive move:
  - **Smash into another player** → big screen shake, heavy collision, they go flying (Smash-Bros-punch feel).
  - **Super-boost downward into the ground** as a rival lands nearby → triggers the surface's bounce physics and flings them off-screen. *(This replaces a separate "ground pound" — down is just one direction you can super-boost.)*
  - **Recovery gamble:** flung off the edge? A super-boost can save you — but **boost too hard and you rocket straight off the opposite side into oblivion.** Hilarity ensues. High risk, high reward.

### 4.3 Fuel (the resource that gates everything) — **bounce-powered jetpacks**
- One shared tank powers both boosts. **Full tank = ~3.5s of normal boost** (super boost dumps it all in ~0.3s).
- **Fuel refills ONLY by bouncing** — the jetpacks are bounce-powered. This is the elegant heart of the economy: you must keep bouncing to bank fuel, then spend it on boosts/smashes. **You can never just turtle** — stop bouncing and you go dry. Mechanically enforces Pillar #2 (no standing still).
- **Super-boost strength scales with remaining fuel** — a full-tank super-boost flings hardest (and is most dangerous to yourself); a near-empty one is a weak nudge. So spending fuel on positioning weakens your next smash, and vice-versa.
- **Tuning question (not blocking):** how much fuel per bounce — flat, or proportional to bounce height (so a `spring` bounce refuels more than a `marshmallow`)? Height-proportional would make high-tier surfaces doubly valuable. Decide during movement tuning.

### 4.4 Physics Knockback / Collisions
- The game is **physics-based**. A **super-boost collision** sends players flying; landing near someone's downward super-boost launches them via bounce physics. Direct body collisions transfer momentum.
- **Chain reactions** are encouraged — knock player A into player B into a bumper wall into a hazard, etc.

### 4.5 Death Model — **Ring-Out + Hazard Instakill** (decided)
- **No health bars, no damage, no hit points.** Still no HP — death is always instant, from one of two causes:
  1. **Ring-out** — crossing a blast-zone edge (§15 `bounds`), whether launched there by a rival, knocked by a hammer, **or by over-committing your own super-boost into oblivion.**
  2. **Hazard contact** — **spikes impale and crushers squish: instant death** (decided). Adds "don't touch that" stakes, closer to Duck Game's instakill chaos. (Note: swinging **hammers** *knock*, they don't kill — they fling you toward the edge.)
- Still no whittling-down — every interaction is about **position and momentum**, just with a few lethal surfaces to avoid.
- *(Future option noted, not in v1: a Smash-style "damage %" variant where repeated hits make you fly further. Deliberately excluded for now to keep it clean.)*
- **Sole HP exception:** campaign **bosses** have a health pool (§7 Mode 2 Boss levels). Bosses aren't players, so this keeps the *player* experience 100% HP-free while letting boss fights have a damage arc.

### 4.6 Hitstun & Knockback Recovery (decided) — *the skill-heart of the game*
When you get smashed (super-boost collision, hammer, chain knock), you're **launched and lose control for a brief stun**, then regain control and can fight to recover. The exact tuning of this is what separates a funny, fair game from a frustrating one.

- **Stun duration = `hitstun_base` + (knock impulse × `hitstun_per_impulse`), clamped to `hitstun_max`.** The harder you're hit ("knocked-into-power"), the longer you're helpless — but **capped**, so a recovery *window* always exists. Ring-outs should come from your **velocity/position carrying you over the edge**, NOT from being frozen the whole way out. (Get hit hard enough and you still die — because you can't cancel that much momentum in time, not because you're stunned to death.)
- **During stun:** no input; play the `Hit` animation + a **code-driven tumble** (spin/rotation). Optional tiny "dizzy" tell.
- **The crucial interaction with fuel (§4.3):** while stunned you're airborne and **not bouncing → not refilling fuel.** So the instant control returns, the recovery gamble is: *aim opposite your launch vector and super-boost to kill the momentum — but only if you banked enough fuel before the hit.* This triad **(hitstun → no mid-flight refuel → fuel-gated recovery)** is the core skill expression and the engine of the "high-risk recovery" comedy. **Protect this interaction.**
- **Hazards bypass stun** — spikes/crushers are instakill (§4.5); stun only applies to knockback.
- **Open tuning question (playtest):** should **bouncing off a surface while stunned shorten/cancel the stun** (a "bounce-out" tech — adds skill + comedy) or not (cleaner, harsher)? Decide during the feel loop.
- **Feel-critical `@export` vars:** `hitstun_base`, `hitstun_per_impulse`, `hitstun_max` (+ whether bounce-out is on).

> **This is the first entry in a growing category — "Player States & Timing Rules"** (stun, spawn
> invulnerability, respawn/round-reset timing, super-boost recovery lag, powerup durations, etc.).
> As we pin these down they live here; they're prime `@export` tuning numbers and key input for Fable.

### 4.7 Boost-Bounce Supercharge — the "bounce-jump" flow tech (decided)
Timing your jetpack *with* a bounce is rewarded — exactly like deliberately jumping at the peak of a trampoline to go higher. This is the skill/flow layer sitting on top of the core loop.
- **Tap/hold Normal Boost as you launch off a bounce surface** → the bounce is **amplified** (bigger, snappier launch than a natural bounce).
- **Boost INTO a bounce surface** → it kicks you back **harder** than simply falling onto it.
- **One unifying rule:** whenever **Normal Boost is active during a surface contact**, a brief **~0.2 s "supercharge" window** fires — boost thrust *and* the resulting bounce launch are both amplified for that window. The jetpack is bounce-powered, so syncing thrust with bounces is the natural flow/skill mechanic.
- **Skill ceiling:** chaining well-timed boosted bounces builds speed/height (Sonic-spring / Tony-Hawk flow); mistiming just wastes fuel. Low-floor (anyone bounces) / high-ceiling (chainers fly).
- **Feel-critical `@export` vars:** supercharge window, thrust multiplier, bounce multiplier (`FEEL_REFERENCE.md` §3.4). Part of the "Player States & Timing Rules" category (§4.6).

### 4.8 Gravity Fields & Gravity-Generating Surfaces (decided concept — **post-v0**, but architecture must accommodate from day 1)
Gravity is a **field**, not a fixed global "down." The default is normal gravity (pulls down), but **certain bounce surfaces/objects also generate gravity that pulls players toward them** — unlocking wild 360° arenas. Two flavors:
- **Radial / planetoid:** a circular bounce body in the center of the arena is the gravity source. Everyone bounces around its *outside*, from all sides — players "below" it fall **upward** toward it (Super Mario Galaxy-style). The loop still works perfectly: the surface bounces you **outward** (along its normal), gravity pulls you back **in** → continuous bounce in every direction. Super-boost too hard and you fling off the planetoid **into the void = ring-out self-destruct** (on-theme).
- **Directional / planar:** a surface (e.g. the whole left wall) generates gravity **perpendicular to itself**. You can fly up along it, bounce sideways off it, and fall back toward it — turning a wall into a "floor."

**Why it fits:** it's the gravity analogue of the already-decided "every surface bounces, including curved/walls, via angular reflection." The bounce-powered-fuel and no-standing-still rules generalize cleanly (bounce surfaces kick you along their normal; gravity returns you; min-bounce applies along the *local* gravity axis).

**Three decisions this forces (see `FEEL_REFERENCE.md` §6 controls / §1 conventions):**
1. **Aim frame** — does the left stick aim **screen-relative** (up = top of screen, always) or **gravity-relative** (up = away from local gravity)? *Recommendation: screen-relative*, so players never get disoriented as gravity rotates; the on-screen aim arrow is the source of truth.
2. **Character rotation** — do characters visually rotate so their feet point toward local gravity (sells the mechanic, Galaxy-style) while the jetpack still aims via the screen-relative arrow? *Recommendation: yes, rotate the body for readability of "which way is down here," keep aim on the arrow.*
3. **Multiple sources** — when default-down + a wall + a planetoid overlap, how do they combine? *Recommendation: **zone/region-based** (each gravity volume defines its field; overlaps resolve by priority, optionally blended in a transition band)* rather than naive N-body vector-sum, which is chaotic and hard to author. Strength **constant within a zone** (gamey, readable) over realistic 1/r² falloff — tune later.

**Scope & the critical architecture rule:** this is **NOT in the v0 prototype** (v0 proves the basic loop). BUT the movement/physics core must be **gravity-agnostic from the start** — query gravity as a **vector from the environment** at the character's position (`get_gravity_at(pos) -> Vector2`), never hardcode `Vector2(0, gravity)`. If gravity is a queried field on day 1, planetoids/walls drop in later with no rewrite; if it's hardcoded, adding this is a ground-up rebuild. **This is a keeper-architecture decision — flag for `ARCHITECTURE.md`.**

**Level-format implication:** add a `gravity_source` object type (shape: point/disc/line/rect; mode: radial vs directional; strength; radius/zone; priority) — see §15.

---

## 5. Powerups & Items

Powerups **spawn into the stage** mid-round (often as a **block you bounce/boost into** to trigger). They should be chaotic, visual, and short-lived. Grouped by what they do:

### A. Buff yourself (mobility / fuel)
- **Wings** — **repeatedly tap the powerup button to flap**; move freely in any direction (and still boost when needed). Lasts **~30 flaps**, then they're gone. *(Still active motion — flapping, not resting — respects the no-standing-still rule.)*
- **Unlimited Boost** — **activatable**: for **~10 seconds**, the fuel tank never drains — boost freely (still must aim/steer; super-boost can be spammed). A mobility/aggression power spike.
- **Star / Invincible** (Mario-star-style) — go **shiny and invincible for ~6 seconds**. **Any contact** launches the other player — even a gentle touch sends them flying — and you take *zero* knockback: if someone smashes into you, **they** go flying instead. The "everyone scatter!" moment.
- **Mega Bounce** — temporarily supercharges your passive bounce height.
- **Nitro / Big Tank** — temporary oversized fuel tank → longer boosts before empty.
- **Overcharge (2× Boost Power)** — doubles boost *output* for a while: normal boost gives ~2× thrust, and a super-boost becomes a **double super-boost** (huge launch). Distinct from a bigger tank — this is raw power, not capacity.
- **Instant Refuel** — snap your tank back to full (grab-and-smash combo enabler).
- **Heavy Mode** — become briefly heavy/dense: super-boost collisions hit like a truck, but you bounce low and steer sluggishly.
- **Counter Shield** — activates for **~2 seconds only**: if anyone runs/smashes into you while it's up, **they** get launched (counter-attack) and you're unharmed. An *active, offensive* shield (replaces the old passive "absorb one hit" idea — fits the "no boring defensive powerups" rule). Short window = you must time it.
- **Giant / Tiny** — size changes affecting mass and hitbox.

### B. Mess with others (offensive / disruptive)
- **Ball Storm** — hit the block and it bursts into **~20 bouncy balls** that ricochet around smashing everyone. *(from original idea)*
- **Slow-Mo** — slows **all other players to ~half speed for ~3 seconds** while *you* keep moving normally — turning everyone else into easy targets to smash into. (Cleaner than a freeze: slowed players are still *moving*, so it fully respects the no-standing-still rule.)
- **Magnet** — pulls nearby players toward you (into your super-boost or off the edge). *(The black hole below is the dramatic, big-radius cousin.)*
- **Black Hole** — **freeze in the air for ~2s and summon a black hole centered on you** that pulls everyone in; when it ends, they're clustered and **perfect targets for your super-boost smash**. (The ~2s airborne hover is an active, temporary powerup state — fine under the clarified no-standing-still scope, §Pillar 2. You're exposed while channeling = the risk that balances the payoff.)
- **Air Mine** — on use, **arm an explosive in mid-air** (it hangs where you place it); it detonates on contact → an explosion (radial knockback, `FEEL_REFERENCE.md` §4.1). A trap you leave in a popular bounce lane.
- **Ring of Fire** — drop a fiery ring on the stage; **anyone who passes through it gets their super-boost force-triggered as if on a full tank** — they instantly blast off in **whatever direction they were aiming**. Chaotic: a free escape if they're aimed safely, instant **self-destruct** if they're aimed at a blast zone. Great offensive/area-denial trap.
- **Banana / Slip** — drop a slippery patch that ruins others' landings/aim.

### C. Change the whole arena
- **Super Bouncy** — **all surfaces become 2× bouncier for ~1 minute** (everyone launches way higher — global chaos).
- **Floor-is-lava / surface remover** — temporarily disables some platforms.

> Design rule: every powerup should be **readable at a glance**, create a **visible/funny consequence**, and **respect the no-standing-still rule** (§Pillar 2) — i.e. no powerup that lets you **camp on a surface or rest indefinitely**. (Brief active airborne states like Wings or the Black Hole channel are fine — see the §Pillar 2 scope note.) Avoid anything purely defensive/boring. *(This rule cut a "Sticky Feet / cling to surface" idea — that was passive camping.)*

---

## 6. Stage / Level Design

- **Every surface is bounce-or-hazard — NO standable ground exists** (inviolable, see Pillar #2). Every tile a player can touch either bounces them or kills them. There is no flat, solid, "land and stand" surface anywhere in any level. Level generation/editing must never place ground a player could rest on.
- **Surfaces vary in bounce level** — mix marshmallow/bubblegum/trampoline/spring so players must read the stage.
- **Moving / dynamic hazards** (a key chaos source):
  - **Swinging hammers** — sweep through and knock players flying. *(from original idea)*
  - **Spikes** — fixed spiky surfaces (see lethality question below).
  - **Crusher platforms** — two platforms that quickly slam together and might crush whatever's between them.
  - **Moving platforms** — bounce surfaces that travel along a path.
  - Plus room to grow: rotating bouncers, pistons, conveyor-bouncers.
- **Dynamic physics props (emergent-comedy weapons — Pillar #3):** free-moving physics bodies with **mass** that **obey the bounce surfaces themselves** and **smash players on contact**. The toolkit weaponizes the environment:
  - e.g. **boost a giant heavy metal ball into a trampoline** → it launches and bounces around the arena, smashing whoever it hits (huge knockback / ring-out). Crates, boulders, spiked balls (spiked = instakill, cf. the placeholder `Spiked Ball` asset).
  - Props are affected by gravity, bounce tiers, and knockback exactly like the world expects, so the chaos is **emergent** — nobody scripted "ball hits player," physics did. This is the §2 Pillar-3 "the game tells the jokes" generator, and it doubles as the **Ball Storm** powerup's payload (§5).
  - **Damage model:** a fast/heavy prop hit = big **knockback** (same as a player smash → ring-out potential); spiked/lethal variants instakill. Consistent with §4.5, no HP.
  - **Momentum is the rule (not "heavy bounces higher"):** props carry **momentum = mass × velocity**; bounce surfaces **redirect** it. So a **heavy metal ball parked on a high platform** that you boost off → it rolls, falls, gathers speed, lands on a **trampoline**, and its big momentum is redirected into a **devastating low, fast smash** across the arena. Heavy + fast = wrecking ball. This is physically honest *and* gives the feel you want.
  - **Containers / buckets** — a prop that **spills its contents when hit/broken**: a bucket of small bouncy balls, a bucket of bombs, etc. (piñata energy; the level-object cousin of the Ball Storm powerup §5).
  - **Bombs + explosions (emergent chaos):**
    - A **bomb** is a physics prop with a **fuse**. Light the fuse by **flying past it with your jetpack exhaust** (exhaust = a fire/ignition source), or by another explosion (**chain reactions!**), or a timer.
    - **Explosion = a radial knockback blast:** everyone (and every prop) near it gets flung **away from the center**, **harder the closer they are** (impulse falls off with distance). Big ones ring people out; they also launch heavy balls and **detonate other bombs** → glorious chains. Lethality: pure knockback by default (instakill only at point-blank, TBD). Numbers in `FEEL_REFERENCE.md` §4.1.
  - *Implementation/architecture note:* props can be true `RigidBody2D` (let the engine simulate them) while players stay `CharacterBody2D` with hand-authored bounce (§13) — the two must interact (player boosts prop; prop smashes player), **bounce surfaces must launch props too** (physics material or a "launch anything" area, not just players), and there must be a **unified "apply radial impulse in radius" that affects BOTH players and props** (so explosions move everything). Flag for `ARCHITECTURE.md`.
- **Collapsible physics structures (Angry-Birds-style — emergent destruction):** large structures **built out of bouncy blocks** that are **held in place by a breakable support / anchor** until disturbed. Example: a **tall vertical wall of bouncy surfaces balanced on a small support at its base** — **boost-smash the support** and the whole wall **topples sideways**, each block becoming an **independent physics body** that tumbles, bounces, and can **smash players flying** on the way down. Pure Pillar-#3 chaos.
  - **Reuses existing seams, no new systems:** a block here is simultaneously a **bounce surface AND a physics body** — i.e. a `physics_prop` that's also bounceable. While the support holds, the blocks are effectively static (sleeping/anchored); breaking the support **releases them to dynamic physics** (gravity + collisions + bounce). This is why "a bounce surface can itself be a dynamic body" matters (`ARCHITECTURE.md` §1.2/§1.4).
  - **Level-design potential:** balanced towers, stacked walls, bridges on a keystone, a pile you detonate — authored as a structure + its support/trigger. Triggered by boost-smash, explosion, or a heavy prop impact (chains!).
- **Open edges** — stages must have ledges/gaps so ring-outs are possible (Smash-style blast zones).
- **Variety mandate:** many distinct layouts; consider themed sets once art direction is chosen.

---

## 7. Game Modes

> **Launch contains BOTH modes below.** "Party first" is **build order, not a release split** — we build & polish Party Mode first to nail the core mechanics, then build Campaign on top of those proven mechanics, and ship them together.

### Mode 1 — Party Mode (*Last One Bouncing*) — **BUILD FIRST**
The Duck-Game-style competitive party mode. Battle royale per round, scored as in §3 (kills + survival − suicides), **first to 10 points** wins.
- **Lobby:** players join a match together (couch co-op), **optionally add AI bots** to fill it out or to play solo. Local multiplayer is the priority; bots use the §8 human-sim bot.
- **Round flow (the moment-to-moment polish):**
  1. **Quick load** into the next stage (keep energy up — never a long wait).
  2. **One-by-one spawn intro** — each player materializes into the level *one at a time in a cool way* (a beat of anticipation / showing off the roster), camera framing the stage.
  3. **"BOUNCE!"** — go signal, everyone starts moving at once.
  4. **~10–30s** of bounce-combat, **everyone on 1 life**.
  5. **Leaderboard shown on the loading screen** between rounds (running point totals), then straight into the next.
- **Sudden Death (decided — tie-breaker):** if the **final players are eliminated within 0.25s of each other** (a near-simultaneous double-KO with no clear survivor), the tied finalists are **revived into a Sudden Death duel** instead of ambiguously awarding the survival point. The Sudden Death arena has **two giant hazardous lasers on the left & right screen edges that slowly close toward the center**, shrinking the space until someone is forced into a laser or ring-out — the last one bouncing takes the round. *(Lasers = instakill on contact. This doubles as the natural anti-stalemate pressure; a round timer could also trigger the closing lasers if a round ever drags — TBD.)*
- **Why build first:** it's the purest test of the core bounce/jetpack/smash loop, surfaces, hazards, and powerups. Get this feeling *great* before building Campaign — Campaign reuses all of it, so locking the feel here de-risks everything.
- **Camera:** **fixed single-screen** — whole arena visible, no scroll (`FEEL_REFERENCE.md` §7).
- **Circuits (themed level groups — decided):** Party stages are grouped into **themed circuits** à la Mario Kart cups (e.g. ~**10 levels per circuit**: a Mushroom-ish circuit, a Star-ish circuit, etc. — theme = visual set + mechanical flavor).
  - **Difficulty/craziness ramps across circuits:** early circuits are **easy and tame** (pure bounce/jetpack/smash on simple stages); later ones get **wilder, harder, crazier** — introducing the bigger mechanics gradually (gravity fields §4.8, heavy physics props & bombs §6, wilder powerups §5, nastier hazards). **This doubles as onboarding** — players learn the wild stuff one circuit at a time instead of all at once. (Within a circuit, levels can also ramp slightly.)
  - **Unlocking:** clear/play earlier circuits enough (earn enough points / plays) to **unlock the next** (see Progression below).
  - **Match structure (decided):** a match = **pick one circuit**, then **race to 10 points across that circuit's levels** (Mario-Kart-cup feel). At match start the circuit's levels are **shuffled into a random order**; you play through them in that order, and if the circuit has **fewer levels than the match needs, the cycle repeats** (re-using levels in the same shuffled order) until someone hits 10 points. (One circuit per match — not the whole unlocked pool.)
  - **Unlock pace (decided): PACED SCARCITY — a tuned drip, NOT unlock-all.** Scarcity is intentional: unlocks only *mean* something if you have to earn them. The goal is to time content drops so fresh stuff appears at exciting beats *within* a session — e.g. a new circuit unlocking around the **~25-min mark** of a play session and another around **~45 min**, each landing as an **"OMG something new — we gotta try this!"** moment. **No "unlock all" option** (it would kill that payoff). The skill is in *pacing the drip*: never so slow it feels like a grind, never so fast that unlocks stop being events. Tune the unlock economy to hit that cadence.

### Mode 2 — Campaign — **BUILD SECOND (ships at launch too)**
> **Single-player with optional co-op**, played through a **series of missions/levels**. Each level is a **side-scrolling platforming journey** (camera scrolls left→right), and you have **~5 lives per level**.

**The 3-part level structure (most levels):**
1. **Part 1 — Exploration (scrolling).** Travel through the level staying alive: read and clear **terrain/hazard obstacles** (spikes, crushers, gaps, moving bounce-platforms) and fight the **occasional enemy** along the way — blast them away before they smash you. Pace = momentum + light combat.
2. **Part 2 — Arena (camera locks).** You arrive at a **fighting-arena platform layout** and the **screen stops scrolling**. **Out-smash waves of enemies** (the wave-survival beat — waves scale by count + skill + archetype mix, §8.3). Clearing the waves opens the way forward.
3. **Part 3 — The Escape (scrolling).** A **final journey to the safe zone** that completes the mission and leads to the next.

**Boss levels (every few missions):**
Every few levels is a **boss fight** instead of the 3-part journey — **no exploration/escape scrolling, just a dedicated (camera-locked) boss arena**.
- **A big boss monster with a HEALTH POOL** that you whittle down. **This is the ONLY HP in the game** — players never have HP (ring-out + instakill only, §4.5); a boss is not a player, so this exception keeps the *player* experience HP-free while giving the boss a satisfying damage arc.
- **You damage the boss with the existing toolkit + the environment — no new attack verbs.** Examples:
  - **Super-boost into a weak spot** (when exposed).
  - **Boost a destructible, reforming platform** so it drops a **spike onto the boss's head**.
  - **Smash/knock the boss into a hazard** — a ball of lava, a crusher machine, spikes, etc.
- **Boss loop = telegraph → attack → vulnerable window.** The boss threatens you with knockback/slams/hazards (it can ring you out or smash you into instakill hazards — your normal death rules still apply, and you're on the level's ~5 lives). The damage opportunity opens during its vulnerable window — read it, line up the bounce/boost, land the environmental hit.
- **Variety:** each boss uses a different damage gimmick (weak-spot vs drop-spike vs lava-smash vs crusher), so fights feel distinct. (Roster TBD.)
- **New level-format pieces this needs:** a **destructible/reforming platform** and **boss-specific hazard triggers** — see §15 (`destructible_platform`, trigger objects).

- **Optional co-op** — play solo or with friends on the couch.
- **Lives:** ~5 per level (vs Party's one-and-done) so a mission has a longer arc; running out = retry the level.
- **Enemy archetypes** defined in §8.3 (Heavy / Aggressive / Evasive / Flyer / Shielded), all built on the shared bot core; difficulty curves across the mission list.
- **Camera (differs from Party):** **left→right scrolling** in Parts 1 & 3, **locks** for the Part 2 arena. *(Architecture note: the movement/physics core must support BOTH a following/scrolling camera and a locked single-screen one; and death sources differ — Campaign scrolling sections kill via pits/hazards/falling-behind, while the arena uses Smash-style ring-out like Party. See `FEEL_REFERENCE.md` §7.)*
- *Reuse:* movement, surfaces, hazards, level format, bots, juice all come from Party Mode — Campaign mainly adds enemy AI variety, the 3-part mission flow, scrolling camera, a lives system, and progression. That reuse is why we build Party first.

### Progression & Unlockables (both modes — part of launch)
Gamification gives both modes a reason to keep playing and a sense of growth.
- **Campaign progression:** advancing through missions **unlocks new characters and powerups** (and other content), which then become available across the game. Campaign is the main "earn your roster" path.
- **Party progression:** **milestone-based unlocks** — hitting thresholds of **total kills, matches played, powerups used**, etc. unlocks:
  - **new circuits** (themed ~10-level groups, §7 Mode 1),
  - **new characters**,
  - **game modifiers / mutators** (e.g. **double-speed-boost mode**, super-high gravity, everyone-giant, one-platform) that players can toggle on for a match.
  - **Pace = paced scarcity / tuned drip** (§7 Mode 1) — unlocks are earned events timed to land mid-session ("we gotta try this!"); **no "unlock all"** — scarcity is what makes them matter.
- **Shared unlock pool:** characters/powerups earned in one mode carry over (one roster, one collection).
- *Design intent:* unlocks should feel like *new toys / new ways to play*, not power creep that breaks balance (all characters play by the same rules; cosmetic + variety, not strictly stronger). Exact unlock thresholds + reward list = TBD.

### Later / post-launch (noted, NOT in the initial launch)
> Duck-Game-style competitive variety + online, once the launch is solid:
- **Online multiplayer** (hard — physics netcode; deferred — launch is couch-only).
- **Coin Collect** — grab the most coins before time runs out.
- **King of the Hill** — hold a target platform.
- **Race to the Top** — vertical climb race.
- **Mutators** — per-round modifiers (super-high gravity, everyone giant, one platform, etc.), à la Duck Game.
- **Team modes** (2v2 etc.).

---

## 8. Players & AI

- **Local multiplayer** is the priority experience (couch party). Decide max count later — Duck Game does up to 8 on PC, 4 on console.
- **Online multiplayer** — post-launch goal (physics netcode is the hard problem; launch is couch-only).

### 8.1 The Bot Core (shared by both modes)
Every AI agent runs the same behavior loop — and **plays by the exact same rules as a human** (same fuel, physics, limits; **no cheating**). All difficulty/variety comes from *how well* it executes, never from bending the rules.

**Behavior loop:** keep bouncing to bank fuel → assess targets & threats → aim/time super-boosts to smash rivals → **recover** from edge knockbacks without over-boosting into oblivion → grab/use powerups.

### 8.2 Party-Mode Bots — one human-sim bot, **5 difficulty levels**
A single bot type that **simulates a human player**, scaled across **5 skill levels**. The four dials that separate L1 from L5 (all confirmed important):
- **Super-boost aim** — wild misses → frame-perfect target leading.
- **Reaction time** — sluggish → near-instant response to threats/openings.
- **Recovery skill** — *the funniest dial:* L1 bots frequently ring **themselves** out (panic-boost off the map); L5 bots almost always make it back.
- **Aggression & powerup use** — L1 mostly bounces passively; L5 actively hunts, edge-guards, and grabs/uses powerups well.

> **Design principle:** low-level bots aren't just *slow* — they're *funny* (flailing, self-destructing, whiffing). High-level bots feel genuinely scary and precise. The skill spread should map onto these four dials together (e.g. L1 = low all-around with frequent comedic flubs; L5 = high all-around, ruthless).

### 8.3 Campaign Enemy Archetypes (built on the bot core)
Distinct enemy types for the co-op campaign — **less distinct than TowerFall**, more like flavored variants of the core bot. Starting roster ideas:
- **Heavy** — bigger/heavier; hard to launch, hits hard, slow.
- **Aggressive** — relentless hunter, always closing in for smashes.
- **Evasive** — dodgy, hard to hit, plays keep-away.
- **Flyer** — can fly freely (jetpack-like) rather than relying on bounces.
- **Shielded** — has a shield (à la Shield Bubble powerup) that must be broken first.
- *(More TBD; each is the shared movement core + a behavior/stat tweak — cheap to add.)*
- **Wave scaling:** waves get harder by **raising count + bot skill + archetype mix**, not by cheating.

---

## 9. Art Direction — **UNDECIDED (Yulia to lead)**

> Visual style is **Yulia's call.** Recording the current thinking, nothing locked.

- **Characters:** **cute creatures with oversized jetpacks** (jetpack is a defining visual + the core mechanic). Leaning toward cute animals (reference: *Cult of the Lamb* character charm); species/roster **not confirmed** (Yulia). The jetpack should read clearly and its flame/exhaust telegraph thrust direction.
- **Rendering style — OPEN:**
  - Option A: **Pixel art** (retro, Duck-Game-adjacent, readable, cheaper to animate).
  - Option B: **Cult-of-the-Lamb-style** hand-drawn/illustrated 2D (more charm, more art cost).
- **World theme — OPEN** (toy/playground vs neon/arcade vs squishy-nature vs something else). Decide alongside character style.
- **Non-negotiable regardless of style:** characters and surfaces must stay **highly readable** during 4–8 player chaos. Squash-and-stretch animation on bounces will sell the physics in any style.

---

## 10. Game Feel Checklist (the polish that matters)

- Satisfying **squash-and-stretch** on every bounce.
- Chunky **jetpack flame/exhaust** that visibly reads direction + thrust; a violent burst on super-boost.
- **Screen shake** + heavy impact effects on super-boost collisions and ring-outs.
- **Controller rumble (decided):** **soft** on Normal Boost, **medium** on bounce, **hard & powerful** on Super Boost, **heavy & quick** on impact (hitting or being hit). The kinesthetic feedback channel (see `FEEL_REFERENCE.md` §5.5).
- A **launch "whoosh"** and comedic reaction when someone gets ringed out (including self-destructs).
- Clear, glanceable **fuel gauge** per player (the core resource — must be readable mid-chaos).
- **Minimal HUD:** per-player point pips along the top (Duck Game style) + fuel gauge, nothing else cluttering the action.
- **Fast respawn** between rounds — keep momentum, never let the energy drop.

---

## 11. Open Questions / To Decide Later

- [ ] Max player count (local + online).
- [x] ~~Engine/tech choice~~ → **Godot 4 + GDScript** (see §13).
- [x] ~~Level editor approach~~ → **custom JSON format + phased custom in-engine editor** (see §14).
- [ ] Online netcode approach for physics sync (known hard problem) — **deferred: v1 is couch-only**.
- [ ] Art style: pixel vs illustrated (Yulia).
- [ ] Character species/roster (Yulia).
- [ ] World theme(s).
- [x] ~~Fuel refill mechanic~~ → **bounce-powered: fuel refills only by bouncing** (§4.3). (Sub-tuning: flat vs height-proportional per bounce — TBD.)
- [x] ~~Hazard lethality~~ → **spikes & crushers instakill on contact**; hammers only knock (§4.5). Death model is now ring-out + hazard instakill.
- [x] ~~Controls / button mapping~~ → **controller-only for v0; Xbox-360 layout (tentative):** **left stick** = aim thrust direction, **A** = Normal Boost (hold), **RT** = Super Boost ("heavy boost"). **Y *and* RB both** = **use powerup** (same action mapped to two buttons — common in low-control games, easy to reach). (Mouse/keyboard deferred.)
- [ ] **Super-boost tuning** — how strong at full tank, and how easy is the "fly off the far side" self-destruct? (the comedy/skill knob)
- [ ] Final powerup roster + balance.

---

## 12. Prototype (v0) — First Build Brief for Fable

> **The mission:** prove the *feel* is fun **before any custom art exists**. This is a throwaway,
> placeholder-art playtest build. If the core bounce/jetpack/smash loop isn't fun here, nothing else
> matters yet. **Do not** build menus, progression, the level editor, or campaign — just the core loop
> in one hand-made level.

### Goal of the prototype
Get **two humans (or one human + bots) on couch controllers** bouncing around one level, super-boosting
each other off the stage, and have it feel **good and funny**. That's the whole bar.

### Must-have scope
- **One handcrafted level** — authored directly as a JSON file (§15 format). **No level editor needed** — Fable just writes the JSON (and may generate a few variations to pick from).
  - Includes **different surface tiers** (at least marshmallow / trampoline / spring) and **a couple of hazards** (e.g. one swinging hammer + some spikes).
  - Open edges / blast zone for ring-outs.
- **Core movement** — passive continuous bounce, minimum-bounce floor, slight L/R air drift (§4.1).
- **Jetpack** — Normal Boost (aimable, ~4s tank) + Super Boost (dump remaining fuel, aimable) (§4.2).
- **Bounce-powered fuel** — refills only by bouncing (§4.3); on-screen fuel gauge per player.
- **Physics knockback + ring-out + hazard instakill** (§4.4–4.5).
- **2-controller local multiplayer** + **AI bots** (the §8 human-sim bot; even a single mid-level bot is enough to test feel). **Add keyboard controls for P1** too, so the owner can playtest solo without two gamepads.
- **Round flow** — spawn → fight → last-one-bouncing → quick reset → repeat. (A running score is fine; the full first-to-10 + scoreboard polish can wait.)

### Explicitly OUT of scope for v0 (don't build yet)
- Level editor, menus/UI beyond a minimal HUD, campaign/waves, online, the full powerup roster.
- **Powerups:** optional stretch — if the core feels good, add **just one** (e.g. Ball Storm or Mega Bounce) to sanity-check that powerups are fun. Not required for the first feel-test.

### Placeholder art — AI sources it online (owner provides NONE)
Fable should **find free, openly-licensed placeholder assets** so the owner doesn't make any art yet:
- **License discipline:** prefer **CC0 / public-domain** (or clearly free-for-commercial-use) assets so there's zero legal baggage even though we'll replace them. Good sources: **Kenney.nl** (CC0, has platformer characters, tile/jump packs, particle packs), **OpenGameArt.org**, free **itch.io** asset packs. Record each asset's source + license in a `CREDITS`/`ASSETS.md`.
- **Need:** 1–2 **character sprites with animations** (idle/squash, in-air, etc.), **~5 bouncy-looking tile types**, a **particle effect** for jetpack exhaust, and basic SFX if easy.
- Doesn't need to match final style — just readable and "bouncy-ish."

### Jetpack must be a SEPARATE, code-driven sprite (key architecture note)
The jetpack **cannot be baked into the character's animation** — it must aim independently in any direction.
- Character = its own sprite/animations. **Jetpack = a separate sprite** attached as a child, which **code rotates to point along the aim/thrust direction** (so thrust can go up/down/sideways regardless of which way the character faces).
- **Exhaust = a particle emitter** at the jetpack nozzle, firing opposite the thrust; bigger violent burst on super-boost.
- For v0 this can be a found "jetpack" sprite (or even a simple shape) + a found particle effect — the point is to nail the *mechanic*, with the visual attached programmatically.

### What we're evaluating in the playtest (success criteria)
- Does **bouncing** feel good on its own (rhythm, the minimum-bounce floor, reading surfaces)?
- Is **super-boost** satisfying to land — and is the **self-destruct overshoot** funny rather than annoying?
- Is the **bounce-powered fuel economy** fun (banking fuel, the bank-vs-spend tension)?
- Is getting **smashed off / ringed out** funny (the "death is a punchline" pillar)?
- Can a human have a fair, fun fight against the bots?

### Tuning must be easy (so we can dial in feel fast)
Expose the feel-critical numbers as **easily-tweakable constants** (Godot `@export` vars or a single tuning
resource/config) — gravity, per-tier bounce heights, min-bounce, tank size (~4s), normal-boost thrust,
super-boost impulse, knockback strength, fuel-per-bounce, **hitstun (`hitstun_base` /
`hitstun_per_impulse` / `hitstun_max`)** (§4.6), and impact feel (screen-shake amount, hitstop/slow-mo
duration). The playtest *is* a tuning loop; we'll be changing these constantly, so they must not be
buried in code.

---

## 13. Technology / Engine — **DECIDED: Godot 4 + GDScript**

**Decision driver:** This game is **AI-coded by Fable** with a **mostly hands-off** owner, so the
winning engine is the one where (a) the *entire project is text-authorable* by the AI, and (b) a
real runtime (physics, rendering, gamepad input) comes for free so the AI isn't rebuilding
fundamentals.

- **Godot 4 + GDScript** — chosen.
  - Whole project is text (`.gd`, `.tscn`, `.tres`) → Fable can author everything, no GUI wiring required of the owner.
  - Built-in **2D physics**, **multi-gamepad input** (couch play), rendering, particles, audio.
  - GDScript = concise, Python-like, well-represented in AI training data, readable if the owner peeks.
  - Free/open-source, trivial **Windows/Steam** export; console path later via porting houses (only "if reviews are great").
- **Rejected — Unity:** too editor-dependent (inspector wiring the AI can't do for you → fights hands-off). Console/training-data edge only matters post-success.
- **Rejected — web/TS from scratch:** would force the AI to rebuild physics/rendering/editor; worse "native" feel; clumsier Steam packaging.
- **Physics-feel note:** lean toward **semi-custom movement** (`CharacterBody2D` + hand-authored velocity/bounce/pound math) over pure `RigidBody2D` simulation, for tight arcade "juice" and exact per-surface bounce control. Decide during movement design.

## 14. Level Design Pipeline — **DECIDED: custom JSON format + phased custom editor**

**Decision driver:** Map work to AI strengths/weaknesses.
- AI is **strong** at: systems/logic code, and **generating level *data* as text** (mass-producing layout variations) + encoding generation *rules*.
- AI is **weak** at: spatial "is this *fun*?" judgment, anything needing to see/playtest, and curation.
- Therefore **humans own spatial design** (curate + tweak + hand-build); **AI owns systems + candidate generation**.

**Physics-coupled levels:** reachability depends on which bouncy surface you launch from + boost
timing, not a fixed jump arc. AI-generated levels can be structurally valid but physically broken,
so the editor should eventually preview **bounce reachability/arcs**. This is why the editor wants
to be **in-engine** (live playtest) rather than external (e.g. Tiled, which is blind to physics).

**Precedent:** Duck Game ships a custom in-game editor (paint tiles + place objects) with Steam
Workshop sharing — same two-layer shape we're adopting.

**The pipeline:**
1. **Own a simple, human-readable JSON level format** (see §15) — one file per level. This is the shared language for the AI generator, the editor, and the runtime.
2. **Phase 1 (now): no editor.** Levels are JSON files. Fable generates batches; owner curates and hand-edits JSON. Instant, zero tooling — proves the game is fun first.
3. **Phase 2 (after fun is proven): lightweight custom in-engine editor** reading/writing the same JSON — paint tiles, place objects, and a **toggle between edit-mode and live-playtest**, eventually with bounce-arc preview. Just a UI on top of the existing format.

> **Known tradeoff:** the editor UI is the *one* area the owner must be hands-on — UI feel is the visual-iteration thing AI is weak at. Acceptable: it's Phase 2 and small.

## 15. Level File Format (draft — needs review)

> Draft schema; the **tile types** and **object types** below are the spine everything hangs off. Reviewing/expanding these lists is the next design task.

```jsonc
{
  "name": "Trampoline Towers",
  "version": 1,

  // Grid for the painted TILE layer (the bouncy terrain).
  "grid": { "width": 32, "height": 18, "tileSize": 32 },

  // Tile palette: IDs map to properties ONCE, so the grid stays a compact int array
  // the AI can generate/edit easily and a human can read.
  // `bounceHeight` = RELATIVE bounce height (marshmallow = 1 baseline). Each tier ~2x the last,
  // so the surface's look telegraphs how high you'll go — readable at a glance.
  "palette": {
    "0": { "type": "empty" },
    "1": { "type": "bounce", "name": "marshmallow", "bounceHeight": 1 },  // lowest, squishy
    "2": { "type": "bounce", "name": "bubblegum",   "bounceHeight": 2 },  // pink, 2x marshmallow
    "3": { "type": "bounce", "name": "trampoline",  "bounceHeight": 4 },  // 2x bubblegum
    "4": { "type": "bounce", "name": "spring",      "bounceHeight": 8 },  // coiled spring, super high
    "5": { "type": "bumper", "name": "bumper_wall", "bounciness": 1.0 }   // walls/ceilings: deflect sideways too
  },

  // Row-major grid of palette IDs.
  "tiles": [
    [0,0,0,0,0,0,0,0],
    [0,0,3,0,0,3,0,0],
    [2,2,0,0,0,0,2,2]
    // ...
  ],

  // Discrete OBJECT layer — free pixel positions (not grid-snapped), so hazards/spawns
  // can sit anywhere. Each object has a type + type-specific properties.
  "objects": [
    { "type": "player_spawn",    "x": 96,  "y": 480 },
    { "type": "powerup_spawner", "x": 512, "y": 120, "interval": 8 },
    { "type": "swinging_hammer", "x": 400, "y": 0,   "armLength": 160, "arcDegrees": 120, "speed": 1.2 },
    { "type": "spikes",          "x": 256, "y": 540, "width": 64, "facing": "up" },
    { "type": "crusher",         "x": 700, "y": 200, "axis": "horizontal", "gap": 128, "interval": 2.0, "slamSpeed": 900 },
    { "type": "moving_platform", "x": 200, "y": 320, "tile": 2, "path": [[200,320],[440,320]], "speed": 60 },

    // Destructible / reforming platform (boss levels §7) — break it (e.g. boost into it) to drop
    // whatever sits on it (a spike onto the boss), then it reforms after `reform` seconds.
    { "type": "destructible_platform", "x": 700, "y": 150, "tile": 1, "drops": "spikes", "reform": 3.0 },

    // Gravity fields (§4.8) — pull players toward them. POST-v0 feature; engine queries
    // gravity as a vector field so these drop in without a rewrite.
    { "type": "gravity_source", "mode": "radial",      "x": 512, "y": 360, "radius": 480, "strength": 2600, "priority": 1 },
    { "type": "gravity_source", "mode": "directional", "dir": "left", "rect": [0,0,64,1080], "strength": 2600, "priority": 1 }
  ],

  // Blast zone: cross any edge and you're ringed-out.
  "bounds": { "left": -64, "right": 1088, "top": -240, "bottom": 820 }
}
```

**Schema design notes:**
- **Palette indirection** keeps grids compact and lets the AI generate big layouts as plain int arrays while properties are defined once.
- **`bounceHeight`** (bounce tiles) = relative *height* of the bounce, marshmallow = 1 baseline, ~2x per tier (1 / 2 / 4 / 8). Engine converts height → launch velocity. The visual telegraphs the tier.
- **`bumper`** tiles deflect on contact from any side (walls, ceilings) rather than launching straight up — `bounciness` is how much velocity is preserved on the bounce (1.0 = elastic). Used for level edges/obstacles you ricochet off.
- **Tiles are grid-snapped; objects are free pixel coords** — matches "paint terrain, then drop hazards/spawns anywhere."
- **`bounds`** drives ring-out detection (Smash-style blast zone), independent of the visible grid. *(For radial-gravity planetoid arenas, the blast zone can be a **max radius** from the source — fly too far out and you ring out into the void.)*
- **`gravity_source`** (§4.8, post-v0): `mode` = `radial` (point/disc pull, uses `x/y/radius`) or `directional` (planar pull, uses `dir` + `rect`); `strength` in px/s²; `priority` resolves overlaps (zone-based, not summed). A level with no gravity_source just uses default global down-gravity.
- **`destructible_platform`** (boss levels §7): a bounce tile that **breaks when hit** (e.g. boosted into), `drops` whatever sits above it (e.g. `spikes`) as a falling object, then **reforms** after `reform` seconds. The core "boost a platform to drop a spike on the boss" gimmick.
- **`physics_prop`** (§6 dynamic props): a free physics body (mass, bounces off surfaces, knocks players) — e.g. `heavy_ball`, `crate`, `spiked_ball`. `mass` tunes how hard it hits (momentum). See §6.
- **`container`** (§6): a prop that **spills `contents`** when hit/broken — e.g. `{ "contents": "bouncy_balls", "count": 12 }` or `{ "contents": "bombs", "count": 4 }`.
- **`bomb`** (§6): physics prop with a `fuse` (seconds); ignites on **jetpack-exhaust contact**, timer, or nearby explosion (chain). Explodes → radial knockback (`radius`, `impulse`; falloff — `FEEL_REFERENCE.md` §4.1).
- **`physics_structure`** (§6 collapsible structures): a group of **bouncy blocks held by a breakable `support`/anchor**; blocks are static-ish until the support is destroyed (boost-smash / explosion / heavy impact), then **release to full physics** and topple — each block a bounce-surface + physics body. e.g. `{ "blocks": [...grid or list...], "support": {x,y,hp}, "block_tile": 3 }`.

## 16. Reference: Duck Game Takeaways (research summary)

- 2D side-view pixel platformer; frantic local/online multiplayer (up to 8 PC / 4 console) + AI.
- Rounds ~8–10s; spawn unarmed, grab a weapon, **last duck standing** scores; **first to 10 wins**.
- **One-hit deaths** make death cheap and funny.
- **80–100+ stages** randomly cycled + **mutators** for freshness.
- **5-button** control scheme: massive accessibility, deep mastery.
- Personality (quacking, hats, ragdolls) is core to the fun.
- *Sources: Wikipedia, Steam store page, Nintendo Life, COGconnected reviews.*
