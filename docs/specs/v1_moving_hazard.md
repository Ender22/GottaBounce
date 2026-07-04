# Spec: v1 MOVING-HAZARD mechanic + the `wrecking_yard` level

> **Owner:** Lead Game Designer. **Status:** READY FOR BUILD — ADDITIVE STRETCH CONTENT (the game is
> otherwise SHIP-verified; this is the one originally-planned circuit level, §L-6, not yet built).
> **v1 — 2026-07-04.**
>
> **Fulfils:** `docs/specs/v1_level_circuit.md` §L-6 (the `wrecking_yard` sketch + WY1-WY3), §0 (the
> through-line), §1 (the flight-required rulebox), §6 (the moving-hazard programmer flag + static
> fallback). **Companion:** `docs/specs/v2a_kill_shape_void_floor_addendum.md` (kill_shape = `void_is_floor`
> here — QA uses K1', NOT the central_pit K1).
>
> **This doc is MECHANICS + measurable targets + build order.** The level-designer authors the JSON
> geometry within these constraints and re-runs the per-gap analysis at real coordinates (§6). I do not
> write GDScript.
>
> **THE FENCE (restated, inviolable — carried from §L-6 and the lethality specs):** this feature changes
> **NO** movement/launch/hitstun/lethality/fuel/credit-window constant. The hazard READS existing Tuning
> constants (`soft_bump_*`, `shove_credit_min_rel`, `kill_credit_window_ringout`) and REUSES the existing
> shove path. It supplies an impulse *within the existing shove band*; it does **not** redefine the smash
> system, apply hitstun, sting fuel, escalate damage level, or add a new impulse scale. The level is
> GEOMETRY + theme + a kinematic prop. See §5 for the change-control call.

---

## 0. The player fantasy + core-verb fit (GAME_ESSENCE gate)

**Fantasy:** *"The yard itself is trying to knock me into the pit — and I can turn it on my rivals."* A
slab of moving industrial metal sweeps the crossing lane. You read its rhythm, thread your boost through
the clear beat, and — the money play — time a rival's crossing so the arm catches THEM and flings them
off the island into the void. The hazard never kills you; the void does. The hazard is the *tool that
sets up off-screen kills*, exactly the game's identity ("knock rivals OFF into the void").

**Core verbs exercised (GAME_ESSENCE §"the core verbs"):**
- **FLY / BOOST** — the 680px gaps still REQUIRE a boost (Rule A); the hazard makes the *timing* of that
  boost load-bearing (cross on the clear beat, not just when you have fuel). This is the level's twist:
  flight-required PLUS rhythm-required.
- **SUPER-SMASH** — a super across the lane while the arm is clear is a clean throw; a super mistimed into
  the arm gets deflected (shove), a comedy beat (Pillar 3).
- **RECOVER** — the hazard shoves, it does not stun, so a shoved player keeps full control and can boost
  back (the recovery gamble, C5 / Rule 5, is PRESERVED by construction — see §1.2, the reason the hazard
  must NOT use the smash/hitstun path).

**Fantasy-fit self-check (the honest naive read):** a first-time human watching a match names it as *"the
swinging thing knocks people off into the pit"* without prompting — that is the C3 variety read and the
WY1 metric made felt.

---

## 1. THE MECHANIC — a kinematic SHOVE-hazard on a path

### 1.1 Motion (path + speed + JSON)

A **kinematic** (code-moved, not physics-driven) hazard that travels a **defined, periodic, predictable**
path and imparts a **SHOVE** to any player it contacts. Periodicity is the whole point: an unpredictable
hazard is unreadable and violates Pillar "readability over prettiness." Two path kinds, recommended in
priority order:

- **`pendulum` (RECOMMENDED PRIMARY — the wrecking ball).** A heavy ball/slab on a rigid arm anchored to a
  pivot ABOVE the crossing lane; swings through an arc. Self-telegraphing: it *slows to near-zero at each
  apex* (the readable "clear beat" when you cross) and is fastest at the bottom of the arc (the danger
  window). Iconic for a scrapyard. Motion is a driven angle `theta(t) = arc_half * sin(2*pi*t/period + phase)`
  — deterministic, no physics sim needed (it does NOT need a real pendulum ODE; a driven sine reads as a
  pendulum and is trivially predictable).
- **`sweep` (ALTERNATE — the sliding press / traversing bar).** A bar that slides back and forth along a
  straight segment at constant speed, dwelling briefly at each end (the clear beat). Simpler kinematics; a
  good second hazard on the same level for variety, or the whole hazard if the pivot-arm render is too much.
- **`loop` — NOT recommended.** A circular sweep has no natural dwell/clear-beat and reads worst. Omit.

**New level-JSON object type `moving_hazard`** (INV-7; added to `LevelLoader` — currently `moving_platform`/
`crusher` are recognized-but-skipped stubs, this is a NEW explicit type). Proposed schema:

```json
{ "type": "moving_hazard", "kind": "pendulum",
  "pivot": { "x": 1250, "y": 300 },   // pendulum: anchor point
  "arm_len": 620, "arc_deg": 150, "period_s": 3.2, "phase": 0.0,
  "radius": 90,                        // the shove-body size (the ball)
  "shove_cooldown": 0.3 }              // mirrors Player._shove_cd; per-victim re-hit gate
```
For `kind: "sweep"`: replace `pivot`/`arm_len`/`arc_deg` with `p0`/`p1` (segment endpoints) + `speed_px_s`
(or reuse `period_s` for a full there-and-back). `phase` lets two hazards on one level run offset rhythms.
All motion params live in JSON (levels are data — CLAUDE.md). **No motion param is a Tuning constant.**

**Speed / cadence tuning target + rationale (from FEEL / the traversal math):** the crossing a player must
survive is a 680px gap crossed by a `normal_boost` (`normal_boost_max_speed = 760`) in **~0.9-1.0s**
(`v1_level_circuit` §1). So the hazard's **clear-beat dwell must be >= ~1.0s** — long enough that a player
who launches on the beat clears the lane before the arm returns. `period_s` in the **3.0-3.6s** band gives
~1.0-1.2s of readable near-apex dwell per side at a `pendulum arc ~140-160deg`. **This is the load-bearing
feel number:** if the dwell is < the crossing time, the gap becomes effectively uncrossable and the level
fails WY-DODGE (below) — widen the dwell (raise `period_s`), NEVER touch a movement constant.

### 1.2 The SHOVE on contact — reuse `_soft_separate`, NEVER the smash path

**The hazard uses the SHOVE path, not the smash path. This is a design ruling, not an implementation
detail.** Rationale (the recovery-gamble invariant, C5 / Rule 5, is HARD):

- A hazard that applied **hitstun** (`receive_smash` -> `_stun_timer`) would zero the victim's control while
  it flung them toward the void. Near an edge that is a **de-facto unavoidable instant-kill** — the victim
  cannot boost-recover, which violates the through-line §0.1 ("moving hazards SHOVE you toward a void; they
  do not themselves kill") AND the recovery gamble (C5). An environmental hazard you cannot recover from is
  exactly the "unfair death" the identity forbids.
- The **SHOVE** (`Player._soft_separate`, lines ~790-805) is momentum along the separation axis with **no
  hitstun, no sting, no damage-level escalation** — the victim keeps FULL control and can boost back. That
  is precisely the recoverable "delivery mechanism" the fantasy wants.

**Magnitude — reuse the EXISTING soft-bump clamp verbatim, cited relative to the smash constants (no change
to any of them):**

```
push = clampf(rel * Tuning.soft_bump_scale, Tuning.soft_bump_min, Tuning.soft_bump_max)
     = clampf(rel * 0.5, 250, 700)         // rel = |hazard_contact_velocity - player.velocity|
player.velocity += shove_dir * push        // shove_dir = along the hazard's motion (fling you the way it swings)
```

- `rel` for a kinematic hazard = the relative speed between the arm's **contact-point velocity** (from its
  driven path — fast at the pendulum bottom, ~0 at apex) and the player. A fast bottom-of-arc contact
  clamps to `soft_bump_max = 700`; a near-apex graze produces almost nothing. **This makes the danger
  self-telegraphing in the physics too:** getting clipped at the apex barely nudges you; getting clipped at
  full swing throws you hard — the arm's readable speed IS its readable threat.
- **Relative to the smash system (the fence, satisfied):** the shove ceiling `soft_bump_max = 700` sits
  BELOW `smash_impulse_base = 500`... note 700 > 500 in raw px/s, but the *categorical* difference is
  hitstun/control, not magnitude — the shove NEVER reaches the smash path's `receive_smash` (min
  `smash_impulse_base 500` + speed term, capped `smash_impulse_max 2200`, WITH hitstun/sting). The hazard
  **must not** call `receive_smash`, must not touch `_stun_timer`, `smash_sting_fuel`, `damage_level`, or
  `max_speed` handling. It calls a shove only. **`shove_dir` = the hazard's motion direction** (so a
  left-swinging ball flings you left toward the left void) rather than pure radial separation — this is the
  one deliberate difference from player-vs-player `_soft_separate` (which pushes along line-of-centers),
  because the hazard's *job* is to fling you the way it is travelling, toward the void it overhangs.

**Implementation shape (for the programmer, not code):** add `Player.receive_shove(dir: Vector2, contact_rel:
float)` that computes the identical `clampf(contact_rel * soft_bump_scale, soft_bump_min, soft_bump_max)`
push, applies it along `dir`, sets the per-victim `_shove_cd` (reuse the existing 0.3s), and applies the
credit rule in §2. It reuses the exact soft-bump constants — it is the shove path exposed to a non-player
mover, NOT a parallel physics.

### 1.3 Collision layer + entity class

- The moving hazard is its **own entity** (`MovingHazard`, an `Area2D` detector parenting a code-moved body),
  modelled on `Hazard.gd` (Area2D, `body_entered`/overlap, per-frame kinematic reposition along its path) —
  **but it calls `receive_shove`, NOT `body.kill`** (Hazard.gd:11 instakills; the moving hazard must not).
- **Collision layer/mask (flag to programmer — this touches the collision table, §5):** the hazard senses
  players only: `collision_mask = (1 << 0)` (layer 1 = players). Its own `collision_layer` should be a
  distinct value from the instakill `LAYER_HAZARDS` (`1 << 3`, layer 4) so a "hazard" is never ambiguously
  lethal-vs-shove. RECOMMENDED: a new layer bit for `moving/kinematic shovers` (a small collision-table
  addition), OR — to avoid growing the table — keep it on layer 4 but as a distinct `MovingHazard` class
  (behavior differs by class, exactly as bumper-vs-tier surfaces both live on layer 3 and differ by
  metadata). The programmer owns which is cleaner; the invariant is: **its contact path is shove, never
  kill.** Do NOT route it through the player's `_hit_area` prop branch (layer 2) — that branch calls
  `receive_smash` (Player.gd:768), the wrong path.
- **Semi-solid vs solid (feasibility tradeoff, programmer call):** IDEAL = the arm is physically solid (the
  player body collides with it and cannot pass through) AND imparts the shove — a wrecking ball should feel
  like a wall of metal. ACCEPTABLE (lower risk) = an overlap-only Area2D that shoves on contact (you can
  clip through the visual but you get flung), which still reads and still funnels. Ship the acceptable
  version if the moving-collider-solidity work is large; note it as a polish follow-up. Either way the
  behavior on contact is the §1.2 shove.

### 1.4 Telegraphy — you can see it coming and dodge it (Pillar: readability over prettiness)

The hazard must be **predictable and readable in motion** (the whole point of a periodic path). Required
telegraphy layers, reusing existing VFX/juice patterns (INV-12: sim emits, Juice/renderer react):

1. **The path is visibly anchored.** Render the pivot + arm (pendulum) or the rail (sweep) so the player
   reads WHERE it travels before it arrives. The swept danger-arc may show a faint hazard-stripe guide
   (matte hazard-red, reusing the void-rim chevron palette from `pit_void_rendering`) so the lane's danger
   zone is legible at gameplay zoom.
2. **A bold, high-contrast silhouette.** The ball/bar is a chunky dark industrial mass against the smoggy
   grey-brown sky — it reads instantly. No thin/ambiguous shapes (readability pillar).
3. **The apex dwell is the readable "clear beat"** — the arm visibly slows and hangs at each extreme (§1.1).
   This is the built-in "safe to cross now" tell; no extra UI needed.
4. **A SHOVE-contact FX distinct from a smash.** The knockback jetstream (Player.gd ~1210) is **gated on
   hitstun**, so a shove correctly leaves NO streak — which means the shove needs its OWN contact read so
   the player understands *"I got bumped, not smashed."* RECOMMEND a new `EventBus.hazard_shoved(hazard,
   player, impulse)` signal that `Juice` subscribes to for a chunky impact puff + light shake + a metallic
   *clang/whoosh* (audio) — visibly softer than the `smashed` death-burst. This keeps INV-12 (sim emits,
   presentation reacts) and makes the shove legible.
5. **An approach cue on `sweep` hazards** (which lack a pendulum's natural slow-down): a short pre-sweep
   tint/rumble as the bar enters the lane, so a constant-speed sweep is still read-ahead-able.

**Fence on telegraphy:** all of the above is display/audio (Juice + ArenaRenderer + a new EventBus signal).
None of it writes sim state (INV-12). No feel constant is touched.

---

## 2. THE CREDIT QUESTION — who gets the kill when the hazard shoves someone off?

**Recommendation: reuse the existing ring-out credit path exactly — the hazard credits NOBODY directly;
the death resolves through `kill(&"ring_out", null)` -> the `last_attacker` fallback gated by the ring-out
window. If a player tagged the victim within `kill_credit_window_ringout = 6.0s`, they get the kill; else
it is an uncredited self-fall (killer = -1).** This is WY2 as written in §L-6, grounded in the code.

**Why (credit audit, analysis-toolkit Recipe 5 — check farm AND leak):**

- **The hazard is not a `Player`.** `credit_attacker()` (Player.gd:891) and the shove-credit branch of
  `_soft_separate` (line 803) both require `attacker is Player`. The hazard therefore **cannot and must
  not set itself as `last_attacker`** — and the shove path must **not overwrite** an existing player
  `last_attacker`. So the hazard shove leaves the credit record untouched.
- **The intended, fantasy-correct path stays CREDITED.** The money play is "tag a rival, then let the arm/
  void deliver." When a player lands a qualifying hit and the victim rings out within 6.0s (the extended
  ring-out window that already exists specifically to "capture the 3-5s failed-recovery arc",
  Player.gd:951-956), the ring-out death credits that player via the existing `kill()` gate. The hazard
  merely contributes momentum toward the same void the player was already fighting to knock them into. **No
  new credit surface, no new farm** — it is the same 6.0s window the game already sanctions.
- **A pure-hazard shove (no player involved) is an UNCREDITED self-fall — and that is CORRECT.** If the arm
  flings an untouched, un-tagged player into the void, the death has cause `ring_out`, `last_attacker` is
  null/expired, so `attacker` stays null (the `-1` self-floor, `v2_kill_shape` §1b). The hazard is an
  environmental funnel, not an author of the kill. Crediting a stale/random player would be a leak (farm);
  inventing an "environment" scorer has no score slot and no meaning (INV-9: only bosses have HP; the kill
  pipeline funnels a cause + attacker, and environmental causes already pass null -> fallback). **Do NOT
  add an `environment` attacker.**
- **The uncredited-death worry (K1'b <= 12%):** because the hazard adds NO hitstun and shoves at most
  `soft_bump_max = 700` (recoverable), a healthy fuelled player it clips can boost back — so pure-hazard
  uncredited falls should be RARE, dominated instead by hazard-*assisted* credited kills (a player set it
  up). If QA finds pure-hazard uncredited falls pushing the aggregate over 12% (K1'b / C1), the lever is
  **geometry** (widen the clear-beat dwell, move the arm off the dead-center of the crossing so an
  un-tagged player is nudged but not doomed), NEVER lethality or the credit window.

**Instrumentation for WY1 (additive, non-fenced):** stamp a `_last_hazard_contact_msec` on the player when
shoved (mirroring how `last_attacker`/`_attacker_timer` are stamped), and surface a `hazard_assisted: bool`
(or `hazard_contact_dt_s`) on each `kills[]` entry in `round_stats` so QA can measure "void deaths within
~1.5s of a hazard contact" (WY1) directly. This is measurement only — no sim behavior, no fence touch.

---

## 3. `wrecking_yard` LEVEL DESIGN (§L-6)

> Coordinates below are a SKETCH; the level-designer finalizes geometry and re-runs the per-gap analysis at
> real coordinates (§6). The **px GAPS/CLIMBS, the void shape, kill_shape, and the hazard placement rule are
> the load-bearing constraints.**

- **Theme/setting:** a smoggy industrial toybox **scrapyard** — rusted islands / stacked-scrap platforms
  over a bottomless pit, a swinging wrecking ball overhead. **Palette per the circuit theming plan:**
  `backdrop: "open_sky"`, grey-brown smog (`sky_top`/`sky_bottom` desaturated ochre-grey), **`clouds:
  false`** (smog haze, not fluffy clouds). Void reads as death via the `pit_void_rendering` treatment
  (dark bottomless gradient, receding dirt/scrap canyon walls, matte hazard-red rim + chevrons, falling
  motes) — never safe.
- **Void SHAPE + kill_shape:** islands-over-ONE-full-width-void (the flagship shape). **`kill_shape:
  "void_is_floor"`** -> QA uses **K1'** (off-screen >= 88%, uncredited <= 12%), NOT the central_pit K1
  (`v2a_kill_shape` §3). Bounds keep the outer island edges ~600px inside the side blast lines (side
  ring-outs possible but the void is the dominant killer); bottom bound leaves >= 650px recovery sky
  (Rule D). Top bound = derived (`bounds_top_margin`), so top kills stay rare (this is NOT the `dual_blast`
  level).
- **Signature identity (distinct from all 10 shipped/planned levels):** the ONLY level with a **moving
  part** — a rhythm/timing layer on top of the flagship's flight-required crossing. It is NOT bumper_gauntlet
  (elastic interior reflectors) — the hazard is a MOVING directional SHOVER that funnels toward the void.
  One-sentence C3 read: *"cross the pit when the wrecking ball is clear, or let it fling your rival in."*

- **Tier/platform sketch (base on the flagship; hazard over the central crossing):**
  - Island A: `trampoline`, x 0..900, top y1080.
  - Island B: `bubblegum`, x1580..2480, top y1080.
  - Island C: `trampoline`, x3160..4060, top y1080.
  - Gaps A<->B and B<->C = **680px** each (flagship spacing; > 527 spring drift, >> 395 trampoline drift).
  - One elevated `spring` throne, top ~y560 (520px above the islands), offset over a gap (boost-only prize).
  - Bottom void: rim ~y1240, bottom blast bound ~y1900+ (>= 660px recovery sky under the islands).
  - **PENDULUM wrecking ball** anchored at a pivot ~(x1250, y300) — i.e. ABOVE the A<->B crossing lane —
    `arm_len ~620`, `arc_deg ~150`, `period_s ~3.4`, `radius ~90`, so the ball sweeps DOWN through the
    crossing lane (y ~900-1040, at players' crossing height) and hangs at each apex clear of the lane. A
    SECOND `sweep` bar over the B<->C lane (offset `phase`) is OPTIONAL for a two-rhythm map (add only after
    the single-hazard version passes — depth-first).
  - **Hazard placement rule (hard):** the arm's danger-arc must overhang the CROSSING LANE (mid-gap, over
    the void) so a mistimed crossing is flung INTO the void — but its apexes and anchor must NOT sit so that
    the ONLY safe state is standing still on an island (no-camp pillar: idle_hunt still applies; the hazard
    creates motion pressure, it does not reward turtling). Keep the arm clear of the elevated throne so the
    throne stays a boost-contest, not a hazard-denied dead zone.

- **How the hazard funnels toward the void:** the ball sweeps the A<->B gap at players' crossing altitude.
  A player who boosts across on the clear beat (apex dwell) passes safely; a player who mistimes gets a
  bottom-of-arc shove (up to 700 px/s) along the swing direction — out over the void, where they must
  boost-recover or ring out. The aggressor play: bait/time a rival's crossing into the danger window, or
  super them into the arm's path.

- **MOVEMENT-TOOL-PER-GAP ANALYSIS (flight-required proof, Tuning-cited — the level-designer re-derives at
  final coords; these are the intents):**
  - **GAP A<->B (680px over void):** > 527 (max spring drift) and >> 395 (trampoline drift). **NORMAL BOOST
    REQUIRED**; miss = fall into the void. The hazard makes the *timing* of that boost matter (cross on the
    apex beat). Verb: FLY (+ TIME).
  - **GAP B<->C (680px over void):** identical — NORMAL BOOST REQUIRED. Verb: FLY.
  - **CLIMB to the spring throne (~520px above the islands, offset over a gap):** > 480 spring apex ->
    **JETPACK CLIMB REQUIRED**; an under-shot climb drops into the void. Verb: FLY.
  - **RECOVER after a hazard shove:** the shove adds <= 700 px/s with NO hitstun (full control retained) and
    the drop from island bottom to the bottom bound is >= ~660px of open sky -> a healthy fuelled shoved
    player boosts back (recovery gamble, Rule D / C5). A near-edge shove + starved/damaged = gone. Verb: FLY.
  - Zero-boost from any island reaches NO other surface across a 680px gap (falls into the void), so flight
    is REQUIRED; the hazard reshapes/times the boosted line, it never creates a bounce path across a gap.

- **MEASURABLE SUCCESS CRITERIA (level-designer verifies via gbplay eval + burst screenshots; QA applies
  the `void_is_floor` K1' target per `v2a_kill_shape` §3):**
  - **WY1 — the hazard funnels kills (not decorative):** >= 12 four-bot stages: credited off-screen kills
    **>= 88%** (K1'a); AND **>= 15%** of void deaths occur within **~1.5s** of a hazard contact (via the
    `hazard_assisted` instrumentation, §2). If < 15%, the arm is not overhanging the crossing lane enough —
    move it INTO the lane (geometry), never buff the shove past the soft-bump band.
  - **WY2 — hazard SHOVES, does not kill, and credit is clean:** the hazard alone (no player attacker)
    produces **ZERO direct kill credit** (it never sets `last_attacker`); a hazard-shove that lands an
    un-tagged victim in the void within/after the window is an **uncredited self-fall** (killer = -1,
    correct), OR is **credited to the last player attacker** if one hit within `kill_credit_window_ringout
    = 6.0s`. Verify: no `MovingHazard`/environment ever appears as a killer id in `round_stats`.
  - **WY3 — flight-required (>= 9/10):** fuel-pinned direction-hold from an island does NOT cross a 680px
    gap (falls into the void) **>= 9/10**; a real crossing logs >= 1 boost activation (as flagship).
  - **WY-NOHITSTUN — the hazard never stuns/instakills:** a shoved player retains control (no `_stun_timer`
    set by the hazard; no knockback-jetstream FX fires; the shove FX is the distinct puff, §1.4.4); direct
    hazard contact NEVER routes through `kill()` (unlike `Hazard.gd`). Verify a bot shoved mid-island is
    steering again on the next frame.
  - **WY-DODGE — the hazard is fair/dodgeable:** a bot (or human) that crosses on the clear-beat apex makes
    the 680px crossing safely **>= 8/10**; the hazard NEVER makes a required gap uncrossable (if a
    well-timed crossing fails > 2/10, widen the apex dwell via `period_s` — a feel/geometry lever, never a
    movement constant). This is the guard that the rhythm layer adds spice, not unfair denial.
  - **WY-READS — telegraphy:** screenshots/burst confirm the anchored path + bold silhouette read at
    gameplay zoom; a naive viewer names "time the ball / knock them into the pit" as the goal (C3).
  - **WY-RECOVERY (C5):** a mid-island healthy full-fuel bot shoved outward boosts back to an island
    **>= 8/10** (roomy islands-over-void level; the shove is recoverable by construction). If < 8/10, widen
    the island / recovery sky — never touch lethality.

---

## 4. STATIC FALLBACK (per §L-6 / §6) — and when NOT to ship

The moving-hazard feature carries two independent risks: **(a) the shove-contact path** (a `receive_shove`
reusing soft-bump + the credit rule) and **(b) the kinematic motion + its solidity/telegraphy**. The
fallback decision must not produce a redundant level — **`bumper_gauntlet` already ships the "islands-over-
void studded with interior reflectors" identity.** A static wrecking_yard built from elastic bumper posts
would be a bumper_gauntlet clone and MUST NOT ship. The fallback is therefore a decision tree, not a single
alternative:

- **PREFERRED — the full kinematic moving shove-hazard (§1-§3).** Ships the level's whole reason to exist
  (the rhythm/timing layer).

- **ACCEPTABLE FALLBACK — a STATIC directional SHOVE-PLATE version ("hydraulic rams / kicker posts").** If
  the *motion* (risk b) slips but the *shove-contact path* (risk a) lands, ship wrecking_yard with FIXED
  directional shove-plates that impart a one-way shove TOWARD the void on contact (a scrapyard hydraulic
  ram). This is **mechanically distinct from bumper_gauntlet**: bumpers elastically REFLECT your own
  velocity (`resolve_bumper`, restitution 0.86, direction depends on your approach); a shove-plate imparts a
  FIXED directional funnel-push regardless of approach — a one-way "kicker" toward the pit. That directional
  funnel is a different feel (a deliberate push-you-off trap vs a chaotic ricochet) and a legitimate
  distinct identity. It also VALIDATES the shove-contact path in isolation, de-risking the motion add-on
  later (this is the natural first milestone toward the moving version). **Ship this ONLY if it reads
  distinctly from bumper_gauntlet in the C3 naive-read; if a QA/CD pass calls it "bumper_gauntlet again,"
  pull it and DEFER (below).**

- **DO-NOT-SHIP / DEFER — a static ELASTIC-BUMPER version.** A wrecking_yard whose "hazard" is fixed bumper
  posts IS bumper_gauntlet; it is redundant and adds nothing to the rotation. If BOTH the motion AND the
  shove-contact path are too risky this milestone, **DEFER wrecking_yard entirely.** The circuit is already
  SHIP-verified with its distinct levels; a redundant 11th level poisons the C3 "variety is real" criterion
  and the rotation QA. wrecking_yard's identity IS the moving rhythm — without at least the directional-
  shove distinction, it should wait, not ship as a clone. (This is the honest call §6 asked for: "state
  clearly that without motion the level should NOT ship, and why.")

---

## 5. OWNERSHIP / BUILD ORDER / FEASIBILITY FLAGS

**Change-control gate: YES — this needs a gate, but it is ADDITIVE and touches NO fenced constant.** Per
the architecture contract, adding a level-JSON object type + a new entity class + a new contact path +
touching the collision-layer table are contract-level changes (INV-7, INV-12, the collision table) that go
through `gottabounce-change-control`. Confirm at review that the diff: reads `soft_bump_*`,
`shove_credit_min_rel`, `kill_credit_window_ringout` **without modifying them**; adds NO movement/launch/
hitstun/lethality/fuel constant; never calls `receive_smash`/`_stun_timer`/sting/`damage_level` from the
hazard; and the new `EventBus.hazard_shoved` signal has sim as sole emitter and Juice/renderer as sole
subscribers (INV-12). The credit audit (§2) is the Recipe-5 artifact for the gate.

**Gameplay-programmer (owns feasibility — the kinematic hazard):**
1. `Player.receive_shove(dir, contact_rel)` — the shove-contact path: reuse the exact `clampf(contact_rel *
   soft_bump_scale, soft_bump_min, soft_bump_max)` push along `dir`, reuse `_shove_cd`, apply the §2 credit
   rule (do NOT set/overwrite `last_attacker`; leave the existing player credit intact), stamp
   `_last_hazard_contact_msec` for WY1. NO hitstun/sting/damage. (Small, additive.)
2. `MovingHazard` entity — an `Area2D` modelled on `Hazard.gd` but calling `receive_shove`, kinematically
   repositioned per frame along its JSON path (`pendulum` first, `sweep` next). Collision: senses layer-1
   players; its own layer distinct from instakill `LAYER_HAZARDS` (§1.3 — flag the collision-table choice
   at change-control). Decide solid-vs-overlap (§1.3 tradeoff; overlap-only is the low-risk ship).
3. `LevelLoader` — handle the new `moving_hazard` object type (currently `moving_platform`/`crusher` are
   skipped stubs). Build the entity from JSON params.
4. Telegraphy hooks — the `EventBus.hazard_shoved` signal + Juice shove-puff/whoosh; render the path
   anchor/arc (ArenaRenderer). Distinct from the smash jetstream (which stays hitstun-gated).
5. Instrumentation — surface `hazard_assisted`/`hazard_contact_dt_s` into `round_stats.kills[]` for WY1.
   **FEASIBILITY FLAGS:** moving colliders do not exist yet (all current levels are static geometry);
   solid-moving-collider + solidity is the largest risk — the overlap-only shove is the de-risked ship. If
   the whole kinematic piece slips, land item (1) alone and hand the level-designer the STATIC shove-plate
   fallback (§4). **You own whether the kinematic version ships this milestone; I own that the fun is the
   rhythm/shove-into-void, and that the fence holds.**

**Level-designer (owns the JSON):** author `wrecking_yard.json` within the §1 rulebox + §3 sketch; place the
hazard path over the crossing lane per the placement rule; re-run the per-gap flight-required analysis at
real coordinates; declare `kill_shape: "void_is_floor"` in `design_intent`; set `backdrop: "open_sky"`,
`clouds: false`, grey-brown smog palette; verify WY1-WY-RECOVERY via gbplay. If handed the fallback, author
the static shove-plate version and run the C3 distinct-from-bumper_gauntlet read before shipping.

**Art-director:** the smoggy-scrapyard void-readability treatment; the bold hazard silhouette + legible
danger-arc at gameplay zoom; confirm the level reads as "moving-hazard funnel" in MOTION (C3).

**Game-designer (me):** this spec + the §2 credit ruling + the §4 do-not-ship-a-clone ruling. QA cites
`v2a_kill_shape` §3 (K1' selection) for the metric interpretation (C6).

**Suggested build order (depth-first, per §L-6/§5.8 — wrecking_yard is LAST in the circuit):**
1. `Player.receive_shove` (the contact path) — validate in isolation via a driven shove (gbplay eval push).
2. STATIC shove-plate wrecking_yard — validate the shove-into-void + the distinct-from-bumper_gauntlet read
   (this is the acceptable-fallback milestone AND the de-risk step for motion).
3. `MovingHazard` pendulum + telegraphy — validate WY1/WY2/WY-NOHITSTUN/WY-DODGE with a single hazard.
4. Optional second `sweep` hazard (two-rhythm map) — only after the single-hazard version passes.
5. Add to `LEVEL_POOL` last; re-run the C1-C6 circuit-wide QA with wrecking_yard in the rotation.

---

## 6. Fence (restated)

GEOMETRY + theme + an additive kinematic prop that REUSES the existing shove path. **NO change** to any
movement/launch/hitstun/lethality/fuel constant, the drain-all super, the hitstun triad, `max_speed`, the
smash license, or any kill-credit window. The hazard reads `soft_bump_*` / `shove_credit_min_rel` /
`kill_credit_window_ringout` read-only and never applies hitstun, sting, or damage escalation. New surface:
one object type (`moving_hazard`), one entity class (`MovingHazard`), one player method (`receive_shove`),
one EventBus signal (`hazard_shoved`), one `round_stats` field (`hazard_assisted`), and a collision-table
entry — all additive/instrumentation, gated through change-control, none touching a fenced constant.
```
