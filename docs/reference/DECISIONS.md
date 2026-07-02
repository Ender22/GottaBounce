# GottaBounce — Decisions Quick-Reference

> **Read me FIRST.** This is the orientation page — every locked decision at a glance, plus what's
> still open. Details live in the deep docs; section refs point you there.
> **Last updated:** 2026-06-27.

## The pitch (one line)
A physics-based, side-view party brawler where cute jetpack creatures **never stop bouncing** — aim
your jetpack boosts to smash rivals off the stage without flinging yourself off too. **No guns.**
Last one bouncing wins. (Think Duck Game frantic + Smash-style ring-outs.)

## Doc map (read order)
1. **DECISIONS.md** (this) — orientation.
2. **`GAME_DESIGN.md`** — what the game is (mechanics, modes, levels). The source of truth.
3. **`FEEL_REFERENCE.md`** — how it feels: concrete starting `@export` numbers + game-feel sources.
4. **`ARCHITECTURE.md`** — the load-bearing seams + keeper/throwaway split (anti-stilts contract).
5. **`assets/placeholder/ASSETS.md`** — the CC0 placeholder art kit + how it maps to mechanics.

---

## ✅ DECIDED

### Tech & build
- **Engine:** Godot 4 + GDScript. Players = `CharacterBody2D` with **hand-authored** bounce (not pure RigidBody). `GAME_DESIGN.md` §13.
- **v0 first:** a throwaway placeholder-art prototype proving the core bounce/jetpack/smash loop is fun. `GAME_DESIGN.md` §12, `ARCHITECTURE.md` §4.
- **Build order:** Party Mode core first, then Campaign on top; both ship at launch.
- **v1 is couch-only** (local). Online deferred.

### Core mechanics
- **Inviolable rule:** NO standable ground / no turtling — every surface is bounce-or-hazard, min-bounce floor means you never settle, and you can't camp/rest indefinitely. *(Scope: about surfaces & turtling — brief active airborne powerup states like Wings / Black Hole channel are fine.)* `GAME_DESIGN.md` §2/§4.1.
- **Characters:** cute creatures with **oversized jetpacks**; bouncing passive, jetpack active.
- **Jetpack:** Normal Boost (sustained, ~3.5s full tank) + Super Boost (dumps all fuel in ~0.3s; strength scales with fuel at use). Aimable any direction. `GAME_DESIGN.md` §4.2.
- **Fuel:** bounce-powered — refills ONLY by bouncing; no refill while airborne/stunned. `GAME_DESIGN.md` §4.3.
- **Boost-Bounce Supercharge:** boost active during a bounce → ~0.2s amplified thrust + bounce (trampoline-pop / boost-into-surface). The flow/skill ceiling. `GAME_DESIGN.md` §4.7.
- **Bounce:** full **angular reflection** off ALL surfaces incl. walls/ceilings/curved; momentum preserved. `GAME_DESIGN.md` §4.1, `FEEL_REFERENCE.md` §2.
- **Hitstun:** smashed → lose control briefly (base + impulse, **capped** so recovery is always possible). `GAME_DESIGN.md` §4.6.
- **Death model:** **ring-out + hazard instakill**, NO player HP. Spikes/crushers/lasers instakill; hammers only knock. `GAME_DESIGN.md` §4.5.
- **Physics props (sandbox):** heavy balls/crates/bombs with mass that bounce off surfaces & smash players (momentum = mass×velocity). `GAME_DESIGN.md` §6.
- **Bombs/explosions:** fuse lit by jetpack exhaust / timer / chain; radial knockback (stronger toward center), affects players + props. `GAME_DESIGN.md` §6, `FEEL_REFERENCE.md` §4.1.
- **Gravity fields (post-v0 concept):** gravity-generating surfaces (radial planetoids / directional walls). Architecture must accommodate now. `GAME_DESIGN.md` §4.8.

### Controls (controller-only for v0; Xbox-360 tentative)
- **Left stick** = aim thrust direction (on-screen arrow). **A** = Normal Boost (hold). **RT** = Super Boost. **Y and RB (both)** = **use powerup** (Wings: repeated taps = flap). Aim is **screen-relative**. `GAME_DESIGN.md` §11, `FEEL_REFERENCE.md` §6.

### Camera
- **Party:** fixed single-screen (whole arena). **Campaign:** scroll L→R (Parts 1 & 3), locks for arena (Part 2). `FEEL_REFERENCE.md` §7.

### Modes & scoring
- **Party (*Last One Bouncing*):** join + optional bots; 10–30s rounds, everyone 1 life. Round flow: quick load → **one-by-one spawn intro → "BOUNCE!"** → fight → **leaderboard on loading screen** → next. `GAME_DESIGN.md` §7.
- **Party scoring:** **+1 per kill, +1 for surviving, −1 for self ring-out; first to 10 points.** `GAME_DESIGN.md` §3.
- **Sudden Death:** if final players die within **0.25s** of each other → revive tied finalists into a duel with **2 closing edge-lasers**. `GAME_DESIGN.md` §7.
- **Circuits:** Party stages grouped into themed ~10-level circuits (Mario-Kart-cup style) that **ramp in difficulty/craziness** (doubles as onboarding). **A match = pick ONE circuit → race to 10 pts across it**; levels shuffled at start, cycle repeats if needed. `GAME_DESIGN.md` §7.
- **Campaign:** series of side-scrolling missions, optional co-op, **~5 lives/level**. Most levels = **3 parts** (Exploration scroll → Arena wave-fight, camera locks → Escape scroll). **Boss levels every few missions** (no journey; big boss with a **health pool — the ONLY HP in the game**; damage via environment: weak-spot super-boost / drop-spike platform / smash into lava/crusher). `GAME_DESIGN.md` §7.

### Progression & unlocks (launch feature)
- **Campaign** unlocks characters/powerups by progressing. **Party** unlocks circuits/characters/modifiers (e.g. double-speed mode) via milestones (kills/matches/powerups-used). Shared roster.
- **Unlock pace = PACED SCARCITY (tuned drip), NO unlock-all.** Time drops to land as mid-session "we gotta try this!" events (~25 & ~45 min). `GAME_DESIGN.md` §7.

### Bots/AI
- All AI plays by the **same rules** (same fuel/physics, **no cheating**); difficulty = input quality only. Bots emit the same `InputIntent` as humans. `GAME_DESIGN.md` §8, `ARCHITECTURE.md` §1.8.

### Levels
- **Custom human-readable JSON format** = the single shared contract (generator/editor/runtime). Phase 1: no editor (AI generates, owner curates). Phase 2: in-engine editor later. `GAME_DESIGN.md` §14/§15.

### Art / assets
- **Placeholder kit (v0): CC0 Kenney bold-outline cartoon** (New Platformer Pack primary + Shape/Jumper/Physics/Particle/UI/Icons), at `assets/placeholder/`. Pixel set kept as backup. Squash/stretch + tumble = code, not frames. `assets/placeholder/ASSETS.md`.
- **Final art = Yulia's call** (leaning cute-animal / Cult-of-the-Lamb-ish) — undecided; placeholder is disposable.

### Architecture (the anti-stilts seams — `ARCHITECTURE.md` §1)
Gravity = queried vector field · bounce affects any body · one radial-impulse for all bodies · player↔prop interop · pluggable camera modes · one hot-editable tuning resource · JSON format as stable API · device-agnostic input + bots-as-providers · unified kill-cause pipeline (+ boss-HP exception) · jetpack = separate code-rotated sprite + exhaust emitter.

---

## ❓ OPEN (not blocking v0)
- **Max player count** (local) — TBD.
- **Art:** final style (pixel vs illustrated), character species/roster, world themes — Yulia.
- **Fuel refill:** flat vs height-proportional per bounce — tune.
- **Super-boost tuning:** full-tank strength & how easy the self-destruct overshoot is (the comedy knob).
- **Powerups:** several now specced (`GAME_DESIGN.md` §5: Counter Shield, Slow-Mo, Unlimited Boost, Air Mine, Wings, Star, Black Hole, Ring of Fire, Ball Storm…); **full roster + balance still open**. (Black Hole's ~2s airborne channel is confirmed fine under the clarified no-standing-still scope.)
- **Scoring:** floor at 0 or allow negative? Mutual-KO handling beyond the 0.25s sudden-death case.
- **Hitstun:** does bouncing-while-stunned cancel stun (`bounce_out_of_stun`)? — tune.
- **Round timeout:** should a timer also trigger the closing lasers if a round drags? — TBD.
- **Super-boost aim assist** (magnetism toward nearest rival) — off by default, try.
- **Gravity fields (post-v0):** confirm aim frame (recommend screen-relative), multi-source blending, falloff, explosion lethal-core radius.
- **Online netcode** — post-launch (hard: physics sync).

---

## v0 build scope (what to make first)
Core loop in **one hand-authored JSON level**: continuous bounce + min-bounce + drift, jetpack
(normal + super) aimed via stick, bounce-powered fuel + gauge, boost-bounce supercharge, knockback +
hitstun + ring-out + hazard instakill, 2-controller local + keyboard P1 + one bot, simple round flow.
All feel numbers in the tuning resource. **OUT:** menus, editor, campaign, bosses, gravity sources,
explosions/props, full powerups (optional: ONE), online, progression, circuits. Build the simple case
**on** the `ARCHITECTURE.md` §1 seams. Full brief: `GAME_DESIGN.md` §12 + `ARCHITECTURE.md` §4.
