# v1 — VFX / Juice TELEGRAPHY (make the jetpack READABLE)

> **Status:** SPEC (2026-07-04). Author: Lead Game Designer.
> **Fixes:** circuit QA's biggest FEEL finding — *"you can't feel the jetpack."* Boost reads as a
> faint white speckle; a launch leaves scattered dots; a committed super-smash (the KILL move) looks
> identical to flying fast.
> **Authority chain:** `docs/VISION.md` pillars (2 constant motion, 5 readable chaos, 6 personality),
> `docs/GAME_ESSENCE.md` (BOUNCE / FLY / SMASH / RECOVER are the fantasy),
> `FEEL_REFERENCE.md` §5 (Rule of Three, trauma², hitstop, squash/stretch),
> and the game-feel-reference skill §7 (live juice constants).
> **Companion, does not supersede:** `v0_combat_lethality.md` (contact model), the damage-pulse brief.

---

## 0. Core verbs exercised & the ONE guardrail

This spec touches **FLY/BOOST**, **SUPER-SMASH**, and **RECOVER** (the launch read) — three of the four
core verbs. It does so by changing **what the player SEES**, never what the player *is*.

**THE FENCE (inviolable).** This is a **read/communication** spec. It must NOT change:
- movement values (`normal_boost_accel/max_speed`, `air_drift_*`, `boost_enter_keep`, gravity, tiers),
- launch physics (`smash_impulse_*`, `smash_launch_floor`, `super_boost_impulse_full`, `max_speed`),
- lethality / the hitstun triad (`hitstun_base/per_impulse/max` — DO-NOT-TOUCH),
- the fuel economy (`fuel_*`, `tank_seconds`, `super_boost_min_fuel`, drain-all).

VFX **communicates** the feel constants; it may not alter them. Any proposed effect that would nudge
a body's trajectory, timing, fuel, or hitstun is out of scope and REJECTED. The one sanctioned motion
effect is **global hitstop** on a super connect (already live via `Engine.time_scale`; §4) — it is
symmetric on all bodies and does not change relative outcomes, only sells weight.

**Why the current state fails the fantasy-fit check (GAME_ESSENCE §23):** *"is the player airborne
and USING the jetpack a meaningful fraction of the time?"* — the sim says yes, but the SCREEN says no.
A naive viewer watching `tools/out/boostvfx3/` cannot tell a thrusting Bouncer from a gliding one, and
watching `tools/out/supervfx/` cannot tell a committed super-smash from fast flight. The fantasy is
*happening but not legible*. This spec makes it legible.

**Asset reality (drives the ownership split).** As of 2026-07-04 there are **no files in
`assets/particles/`** — every `FIRE_TEX / MUZZLE_TEX / RING_TEX / SPARK_TEX` guard in `Juice.gd`
and the exhaust in `Player.gd` currently falls back to **textureless scaled squares**. That is the
root cause of "faint speckle." **Prefer code-drawn / procedural effects** (Line2D ribbons, Polygon2D
cones, gradient-ramped CPUParticles2D, `_draw()` beams) over commissioning new PNGs; where a soft
round sprite genuinely reads better (flame core, muzzle burst, shockwave ring) the art-director
supplies ONE small additive-blend PNG per shape and the programmer wires it behind the existing
`ResourceLoader.exists` guard so the code path already in place lights up.

---

## 1. BOOST — the jetpack FLAME (fixes finding #1)

**Player fantasy.** "My jetpack is *roaring* — I'm THRUSTING, and everyone can see the difference
between me flying under power and me coasting."

**Telegraphy goal (measurable).** At gameplay zoom (0.42–0.92) and **in motion**, a naive viewer can
**instantly tell who is boosting vs gliding**, and roughly *how hard* and *which way*. Boost = a
**directional cartoon flame** out the nozzle (opposite thrust), not a sparse dust speckle.

**Pass/fail QA checks:**
- **P1 (naive-viewer still):** Freeze a 4-player frame where ≥1 Bouncer holds boost and ≥1 is
  airborne coasting. A viewer given only the screenshot names the boosting player(s) correctly. FAIL
  if boost is indistinguishable from coasting (the current state).
- **P2 (direction):** The flame points **opposite the aim/thrust** every frame (thrust up ⇒ flame
  below; thrust right ⇒ flame left). Drive `hold-action boost` with aim rotating; screenshot 4 aims;
  flame trails the correct side each time.
- **P3 (magnitude read):** A supercharged / Unlimited-Boost flame is *visibly bigger/longer* than a
  plain boost (the existing `boost_amt` 1.6× and cyan afterburner must READ, not just exist).
- **P4 (no false positive):** A **gliding** (non-boosting) body emits **no flame** — at most a faint
  idle wisp — so the tell is honest.

**Visual treatment (Glossy-Toybox).** A **thick, glossy, tapered flame cone** hugging the nozzle:
a hot near-white core → saturated orange body → soft transparent tip, additive-blended (the
`_fire_grad_normal` ramp is already right — the problem is it's a handful of tiny squares, so it reads
as speckle). Make it read as one CONTINUOUS tongue of fire, ~1.5–2.5 H long under full thrust, widening
slightly at the base. Length/opacity/emission-rate scale with the **thrust fraction**
(`velocity.dot(aim)` toward `normal_boost_max_speed = 760`). A thin heat-shimmer smoke ribbon trails
behind it (the existing `_smoke`, kept subtle so it never muddies the silhouette — Pillar 5). Cyan
afterburner for Unlimited Boost stays as-is but must inherit the new size/length.

Rule of Three for boost is **soft by design** (it's continuous, not an impact): Visual (flame) +
Kinesthetic (the soft `rumble_boost` purr, already specced) + Audio (thrust loop, already wired). No
shake/hitstop on boost — those are for impacts.

**Hook & ownership.**
- **Fires on:** continuous player state — `Player.is_boosting()` / the `boosting` branch of
  `Player._update_visual()` (~L1066). **No EventBus event** (boost is polled, not an event).
- **Gameplay-programmer owns:** driving `_fire`/`_smoke` so the cone reads as a flame — raise
  `amount`, tune `lifetime`, and **make `initial_velocity`, `scale`, and length scale with the live
  thrust fraction** (not a flat `520 * boost_amt`); keep the nozzle offset and `direction = -aim`
  correct; ensure zero emission when not boosting (P4). Wire the optional flame-core PNG behind the
  existing `ResourceLoader.exists(FIRE_TEX)` guard.
- **Art-director owns:** the flame gradient/shape in Glossy-Toybox terms (the core→orange→transparent
  ramp; the optional single soft additive `fire_core` PNG); the cyan afterburner ramp; making sure the
  flame reads at ~10 screen px at far zoom (simplify, don't just shrink — skill §8).

---

## 2. KNOCKBACK-LAUNCH — the JETSTREAM streak (fixes finding #2)

**Player fantasy.** "That hit was *huge* — I got rocketed across the arena leaving a comet-streak."
(And for the attacker: "I *crushed* them.")

**Telegraphy goal (measurable).** A hard launch **reads as powerful**: a launched body leaves a
**motion streak from the point of impact to its current position**, thickness/length scaling with
launch speed, so a big smash looks like a cannon shot and a light shove looks like a nudge.

**Pass/fail QA checks:**
- **P1 (power reads):** After a clean super-smash (victim exits at/near `max_speed = 3000`), the
  victim trails a bold streak clearly visible at gameplay zoom for the launch's fast phase. FAIL if the
  launch leaves only scattered dots (current state).
- **P2 (gradient):** A near-cap launch streak is **visibly longer & thicker** than a `smash_launch_floor`
  baseline launch (~1320 impulse), and a SHOVE (250–700 push, no hitstun) leaves **little or no** streak
  — the streak must track launch magnitude, so it can't fire on every love-tap. Use `smash_landed.info`
  `launch_speed` to verify the visual scale matches the number.
- **P3 (follows the body):** The streak stays glued to the victim as it flies (it is a trail, not a
  one-shot burst at the impact point), and fades out as the body slows below a threshold.

**Visual treatment (Glossy-Toybox).** A **thick white cartoon speed-streak** (VISION: *"thick white
cartoon streaks"*) — a tapered ribbon trailing the launched body along its velocity: bright white/near-
the-skin-color core, feathering to transparent over ~2–4 H. Implement as a **Line2D ribbon** (or
short-lifetime `local_coords=false` CPUParticles2D emitting along `-velocity`) parented to / following
the victim while it is in the "just-launched" state. Width and trail length scale with
`clampf(launch_speed / max_speed, 0, 1)`. Optionally tint faintly toward the ATTACKER's skin for a
"who hit whom" read (nice-to-have, not required). Pair with the already-live impact feedback so the
Rule of Three is complete at the moment of the hit:
- **Visual:** victim white hit-flash (`flash()`, live) + the new jetstream streak.
- **Kinesthetic:** shake `+0.55` trauma (live) + `rumble_impact` (live) + hitstop scaled by impulse
  (live — §4).
- **Audio:** smash SFX by solidity (live).

**Hook & ownership.**
- **Fires on:** `EventBus.smashed(attacker, victim, impulse)` for the moment-of-hit read, and the
  richer `EventBus.smash_landed(attacker, victim, info)` where `info.launch_speed` is the exact
  post-hit victim speed to scale the streak. `receive_counter_launch()` also emits `smashed`, so
  Counter-Shield launches get the streak for free. The **following trail** is best driven by the
  victim's own high-speed-while-stunned state each frame.
- **Gameplay-programmer owns:** spawning/attaching the streak on `smashed`/`smash_landed`, scaling
  it by `launch_speed`, making it FOLLOW the victim and fade as speed drops, and gating it so a SHOVE
  (no `smashed` emit) produces no streak (P2). Because the streak must track the body every frame, a
  **body-attached emitter on `Player` (like the existing `_fire`)** toggled by
  `_stun_timer > 0 and velocity.length() > <threshold>` is the clean home; a Juice-spawned one-shot at
  the impact point is the fallback. (INV-12 note: Juice stays the event subscriber; the body-attached
  trail is a *visual*, same category as `_fire`, and owns no sim state.)
- **Art-director owns:** the streak gradient/shape (thick-white-cartoon, Glossy-Toybox), the taper
  curve, and (if used) a single soft additive streak PNG behind a `ResourceLoader.exists` guard.

---

## 3. SUPER-CHARGE — the aim TELL (fixes finding #3, part A)

**Player fantasy.** "I'm winding up the big one — *everyone can see it coming* (that's my risk), and it
looks DANGEROUS, not like I'm just floating."

**Telegraphy goal (measurable).** During the AIM/hover state, a naive viewer instantly reads
**"someone is charging a super here, pointing THAT way, and it's about to go off"** — distinct from a
Bouncer merely hovering. This is the opponent's dodge window (skill §6: *telegraphy is sacred*) AND the
committing player's swagger — it must feel like a coiled spring, not a thin decal.

**Pass/fail QA checks:**
- **P1 (unmistakable state):** A screenshot of a Bouncer mid-aim is instantly distinguishable from a
  Bouncer hovering/gliding, at gameplay zoom, by a naive viewer. FAIL = the current *thin orange ring +
  small arrow* (see `tools/out/supervfx/`), which reads as nothing.
- **P2 (fuse reads):** The charge tell **visibly intensifies** as `_sb_aim_t` climbs toward
  `super_aim_max = 2.0` (color yellow→red AND a growing energy build), so the imminent-blast beat is
  legible. Screenshot at ~0.2 s and ~1.2 s of aim; the later frame is obviously "more charged."
- **P3 (direction):** The aim arrow/energy points where the blast will go, full-size from frame 1
  (power never scales — the arrow must not imply it does). Verify at 4 aim directions.
- **P4 (no shrink/hide):** The ring keeps its constant SCREEN-px width (`super_ring_screen_width = 9`
  + `super_ring_outline_extra = 6` backing + `super_ring_min_arc = 0.15`) at all zooms — the readability
  fix stays. This spec ADDS to the tell, never removes the ring.

**Visual treatment (Glossy-Toybox).** Keep the screen-space fuse ring + full-size arrow (they work at
zoom) but make the whole state read as **gathering energy**:
- The **nozzle "revs up"** — the existing revving flame/smoke (`rev = 0.4 + 0.9 * fuse`) becomes a
  visibly building glow that pulses faster as the fuse burns (it already scales; make it BOLDER and
  ensure it reads as charge, not just exhaust).
- A **charge glow / gather** on the body: a soft additive halo that brightens and saturates from warm
  yellow → hot orange → danger red as `fuse` → 1, optionally with a few sparks converging inward
  (inverse of a burst) to sell "winding up." Squash the body slightly into an anticipatory pre-stretch
  (a coil) — this can reuse the existing pre-stretch path; keep within the fence (cosmetic scale only,
  the aim-hover physics in `_physics_process` is untouched).
- Color-lock the ring, arrow, and glow to the **same yellow→red fuse ramp** so all three channels read
  as ONE escalating tell.

**Hook & ownership.**
- **Fires on:** continuous state — `Player.is_super_aiming()` / the `_sb_aiming` branch of
  `_update_visual()` (~L1053–1126). No new event (aim is a polled state). `_sb_aim_t / super_aim_max`
  is the fuse fraction already computed as `fuse`.
- **Gameplay-programmer owns:** driving the charge glow / rev intensity / pre-coil from `fuse`; keeping
  the ring's screen-space width math (P4); ensuring the tell clears instantly on fire/cancel
  (`cancel_super_aim()`), on smash-interrupt, and on Black-Hole channel.
- **Art-director owns:** the charge-glow gradient + optional soft additive halo PNG, the converging-
  spark look, and the yellow→red fuse ramp shared across ring/arrow/glow (Glossy-Toybox, readable at
  far zoom).

---

## 4. SUPER-FIRE — the BLAST flash/beam + connect hitstop (fixes finding #3, part B)

**Player fantasy.** "I committed and it went off like a CANNON — a flash, a beam, a boom. When I
connect, the world hitches for a frame and I feel the kill."

**Telegraphy goal (measurable).** A fired super is **unmistakable vs normal flight**: a dramatic
directional BLAST at the muzzle (flash + beam + shockwave), plus — on a super that *connects* — a brief
hitstop that sells the kill. A committed super-smash must never look like "flying fast" (the whole
finding).

**Pass/fail QA checks:**
- **P1 (fire is obvious):** A screenshot within ~0.15 s of a super firing is instantly readable as
  "a super just went off here, aimed THIS way" — a bright muzzle flash + directional beam/cone, not
  just a fast body. FAIL if fire looks like fast boosting.
- **P2 (fire ≠ boost):** Side-by-side, a super-FIRE blast is dramatically bigger/brighter than the
  §1 boost flame (one is a coasting-under-power tongue, the other a one-shot cannon). A naive viewer
  distinguishes them.
- **P3 (connect hitstop):** When a super connects (a `smashed` with impulse near cap), a brief global
  hitstop fires (`Engine.time_scale` dips then eases back). Drive a scripted super into a target;
  `eval` confirms `Engine.time_scale < 1.0` on the connect frame, back to 1.0 within
  `hitstop_recover = 0.12` s. (This is LIVE via `Juice._on_smashed` → `_hitstop(impulse/2800)`; a
  cap-speed super ⇒ strength ≈ 1.0. This spec RATIFIES it and requires the blast VFX not to swallow it.)
- **P4 (whiff still reads):** A super that fires into empty air still shows the full muzzle blast
  (P1) — the tell is on FIRE, not only on connect — so a missed commit is visible (comedy + dodge read).

**Visual treatment (Glossy-Toybox).** The live `Juice._super_blast()` already lays out the right
shapes (fire cone + muzzle flash + shockwave ring) but every textured piece is guarded behind missing
PNGs, so today only the raw fire cone shows. Complete it:
- **Muzzle FLASH:** a bright one-shot burst at the nozzle, oriented along `-aim`, scaling up and
  fading over ~0.22 s (the tween is already written) — the "cannon fired" pop.
- **Directional BEAM/cone:** a short, bold tapered energy cone punching out the nozzle along `-aim`
  (the exhaust of the launch). This is the single biggest "it's a SUPER" read — make it read as a
  violent jet, distinct from the §1 boost tongue by being brighter, wider, and one-shot.
- **Shockwave RING:** an expanding ring at the body (the `_super_blast` ring path), additive, ~0.32 s.
- Full **Rule of Three** on fire (all live in `Juice._on_super`, keep them): Visual (flash+beam+ring)
  + Kinesthetic (shake `+0.7` trauma via `add_trauma`, `rumble_super`, and on connect the §4-P3
  hitstop) + Audio (super SFX, live). Trauma² model means `+0.7` is already a heavy, snappy shake at
  `shake_max_offset = 22` — do not raise it (fence); the READ gap is visual, not shake.

**Hook & ownership.**
- **Fires on:** `EventBus.super_boosted(player)` → `Juice._on_super()` → `_super_blast(pos, aim)` for
  the blast; `EventBus.super_fired(player, fuel_at_fire, aim_time, auto_fired)` carries QA data. The
  connect hitstop rides `EventBus.smashed` (already) — no new hook needed.
- **Gameplay-programmer owns:** the blast geometry/timing (cone length, flash scale-up, ring expansion),
  wiring them behind the existing `ResourceLoader.exists` guards so the art PNGs light up the code path
  already present; confirming the connect hitstop fires and recovers (P3) and is single-flight-guarded
  (`_in_hitstop`, live) so chained supers can't leave the game in slow-mo (skill §7 trap).
- **Art-director owns:** the muzzle-flash, beam, and shockwave-ring assets/gradients (three small soft
  additive PNGs: `muzzle_01`, `fire_01`, `light_01` — the exact paths the code already references), all
  Glossy-Toybox, readable at far zoom.

---

## 5. BOT SUPER-AIM VARIATION (make supers READ as committed aims)

**Finding.** Bots fire supers with median `aim_time ≈ 0.22 s`, **38 % under 0.1 s**, only **1.5 %
over 0.6 s** — they never do the human **stop-and-aim beat**, so even a well-telegraphed charge (§3)
flashes past too fast to read. **Root cause:** `InputBot._tick_aiming()` fires the instant the jitter
roll is inside `aim_error * 0.5` (L223); an accurate bot's roll is small almost immediately, so it
snap-fires. `super_aim_time` is only a *ceiling*, so it rarely bites for skilled bots.

**Recommendation (game-feel / AI — NO lethality change).** Add a **minimum aim DWELL**: for a fraction
of aims (and always in the finisher/showdown beats), a bot must hold the AIM state a sampled floor time
before it may release, spread across a deliberate **0.4–1.0 s** range. Accuracy dials
(`aim_error`, `target_lead`, `reaction_time`) stay **UNTOUCHED** — the bot aims exactly as well, it just
**commits visibly** first, so the §3 charge tell has time to read and supers feel like decisions.

**Intended distribution (starting hypothesis — tune live):**
- Add a `BotProfile` dial, e.g. `super_aim_min` (per-level), and/or roll a per-aim floor from a range:
  - **L1** — leave comically long (already hangs to the 2 s cap sometimes); `super_aim_min` ≈ **0.6–1.0 s**
    for its telegraphed aims (the punching-bag winds up hugely — reads as "here it comes").
  - **L2 (punchline):** floor ≈ **0.5–0.8 s** on ~70 % of aims — the beat is the read.
  - **L3 (fair fight):** floor ≈ **0.4–0.7 s** on ~50 % of aims — reads as committed, still crisp.
  - **L4 (menace):** floor ≈ **0.3–0.5 s** on ~35 % of aims — mostly snappy, occasionally telegraphs.
  - **L5 (hard mode):** keep near-snap (`super_aim_time = 0.18`); optional tiny **0.25–0.35 s** floor
    on a minority of aims so it's not *invisible*, but L5 SHOULD feel scary-fast.
- **Target aggregate after the change:** median `aim_time` up into the **~0.4–0.6 s** band; the sub-0.1 s
  share **< 10 %** (down from 38 %); a healthy tail (**≥ 25 %** of aims) in **0.5–1.0 s** so a watching
  human routinely sees the stop-and-aim beat. Verify via the `super_fired.aim_time` QA feed
  (already emitted) aggregated in `round_stats`.

**Hook & ownership.**
- **Where:** `src/core/InputBot.gd` `_tick_aiming()` (the fire condition at L223–225) + a new
  `super_aim_min` dial in `src/core/BotProfile.gd` `for_level()`. This is a **BotProfile / InputBot
  tweak (game-feel/AI)** — same category as the existing aim dials.
- **Fence:** raises **commitment/telegraph only**, never accuracy — mirrors the finisher-override rule
  in `Tuning.gd` L166–169 (`aim_error / target_lead / super_aim_time` accuracy stays honest; bots never
  cheat, INV-8). No lethality constant changes. The dwell must still respect the 2 s auto-fire cap
  (`super_aim_max`) so a bot can never camp the aim (Pillar 2).
- **Owner of the change:** gameplay-programmer / AI (not art). Called out here because it is part of
  making the super READ as a committed aim — the same telegraphy problem as §3.

---

## 6. Ownership split — summary table

| Effect | Fires on (hook) | Gameplay-programmer wires | Art-director owns |
|---|---|---|---|
| **§1 Boost flame** | `Player.is_boosting()` state, `_update_visual` boosting branch | flame emitter driven by thrust fraction; direction `-aim`; zero when coasting; supercharge/cyan size read | flame gradient/shape, optional `fire_core` PNG, cyan afterburner ramp |
| **§2 Launch jetstream** | `EventBus.smashed` / `smash_landed.launch_speed`; body high-speed-while-stunned state | streak spawned+attached to victim, scaled by launch_speed, follows & fades; gated OFF for shoves | thick-white streak gradient/taper, optional streak PNG |
| **§3 Super-charge tell** | `Player.is_super_aiming()` state, `_sb_aiming` branch (`fuse = aim_t/super_aim_max`) | charge glow / rev / pre-coil from `fuse`; keep screen-px ring math; clear on fire/cancel/interrupt | charge-glow gradient + halo PNG, converging sparks, shared yellow→red fuse ramp |
| **§4 Super blast + hitstop** | `EventBus.super_boosted` → `Juice._super_blast`; connect hitstop via `smashed` | blast cone/flash/ring geometry+timing behind existing guards; confirm connect hitstop fires & recovers, single-flight-guarded | `muzzle_01` / `fire_01` / `light_01` soft additive PNGs + gradients |
| **§5 Bot aim dwell** | `InputBot._tick_aiming` + `BotProfile.super_aim_min` | min-dwell gate before release; sampled floor 0.4–1.0 s by level; respect 2 s cap | — (AI/feel, no art) |

**Constants this spec relies on but MUST NOT change** (read-only references): `normal_boost_max_speed`
760, `super_boost_impulse_full` 2800, `max_speed` 3000, `super_aim_max` 2.0, `super_ring_screen_width`
9 / `super_ring_outline_extra` 6 / `super_ring_min_arc` 0.15, `shake_max_offset` 22 / `trauma_decay`
1.4, hitstop lerp (0.12→0.04 depth, 0.03→0.10 s dur, `hitstop_recover` 0.12), trauma adds (smash 0.55 /
super 0.7 / kill 0.7 / explosion 0.9). VFX reads these to SCALE itself; it never writes them.

---

## 7. Integrated success criteria (the culminating QA check — drive the game, LOOK)

Run a rendered party match (bots enabled, flagship `islands_void`), capture stills AND motion, and
verify — as a **naive human**, per GAME_ESSENCE — every item below. All must pass to call this done:

1. **Boost legibility:** In a mixed 4-player frame, a naive viewer names who's thrusting (§1-P1). ✔/✘
2. **Boost honesty:** A coasting body shows no flame (§1-P4). ✔/✘
3. **Launch power:** A clean super-smash launch leaves a bold comet-streak; a baseline launch a short
   one; a shove none (§2-P1/P2). ✔/✘
4. **Super-charge unmistakable:** A mid-aim Bouncer is obviously "charging a super, pointing that way,
   about to fire" vs a hoverer, and the tell intensifies toward fire (§3-P1/P2). ✔/✘
5. **Super-fire ≠ flight:** A fired super shows a clear muzzle flash + directional beam + ring, and is
   distinct from both boosting and fast coasting (§4-P1/P2). ✔/✘
6. **Connect hitstop:** A connecting super produces a brief, self-recovering global hitstop (§4-P3),
   and the game is never left in slow-mo after chains. ✔/✘
7. **Bot commit reads:** Watching bot supers, a human routinely sees the stop-and-aim beat; aggregate
   `super_fired.aim_time` median ~0.4–0.6 s, sub-0.1 s share < 10 % (§5). ✔/✘
8. **Readability preserved (Pillar 5):** In an 8-body storm, none of the new VFX obscures who's who —
   flames/streaks/blasts read as bold silhouettes, not visual mud. If it muddies tracking, dial it
   back — readability beats prettiness. ✔/✘
9. **Fence held:** `eval` a spot-check that the touched feel constants are unchanged from §6, and that
   no movement/launch/hitstun/fuel value moved. ✔/✘

Evidence to attach: before/after stills of boost (`tools/out/boostvfx3/` is the "before"), super-aim
(`tools/out/supervfx/` is the "before"), a launch streak, and a super blast; plus the aggregated
bot `aim_time` distribution.
