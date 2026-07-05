# v8 — SPORTS COURT ROSTER (calm-skill → chaos-luck) + selection/rotation

> **Spec owner:** Lead Game Designer. **Status:** READY FOR BUILD (waved — calm courts now, hazard
> courts follow their v6 mechanic). **2026-07-05.**
>
> **Owner directive:** SPORTS has ONE pitch (`levels/sports_court.json`). Design a VARIETY of courts
> spanning calm-skill → chaotic-luck, reusing the shared v6 gimmick MECHANICS, plus how they're
> selected / rotated / unlocked.
>
> **Required reading already run:** `docs/specs/v5_sports_mode.md` (the mode + Ball/GoalZone contract),
> `src/modes/SportsMode.gd` (arena pick / `_place_teams` / `_spawn_ball` / `_kickoff_center`),
> `src/entities/Ball.gd` + `src/entities/GoalZone.gd`, `levels/sports_court.json`,
> `docs/specs/v6_party_gimmicks_circuits.md` (the shared lethal-hazard MECHANIC catalog + doctrine),
> `docs/DECISIONS.md` (2026-07-05 lethal-hazard doctrine), `docs/VISION.md` (pillars — inviolable).
>
> **DESIGN + fairness rules + ball-hazard interaction + a court-set schema + build order.** The
> programmer owns feasibility; I do not write GDScript.

---

## 0. Fantasy & framing

**Fantasy:** *"Pick your pitch — a clean skill court to settle who's actually better, or a mine-strewn
demolition yard where the winning goal is half physics-comedy accident."* SPORTS is the movement game
with the KILL replaced by the GOAL (v5 §0). This spec keeps that intact and adds **breadth of feel**:
the same fly/bounce/strike loop, re-flavoured from **pure sport** (positioning, reads, power shots) to
**pinball chaos** (the hammer whacks the ball, a landmine punts it goalward, everyone screams).

**The escalation arc is the point.** A calm court is the competitive default (who has the better
movement); a chaos court is a party-night laugh where a rally can end when the central hammer clobbers
a loose ball into the net. Both are the game. The roster lets a lobby dial its own tone.

### Non-negotiables this spec must honour
- **Pillar 2 (constant motion, no camping):** every court is fully bouncy, NO flat standable ground; a
  hazard never creates a safe camp spot. (Same as `sports_court.json`.)
- **Pillar 5 (readability over prettiness):** hazards are periodic + telegraphed; both goal mouths + the
  ball stay legible at the fixed whole-court framing (`SportsMode.camera_framing` returns `runner.bounds`).
- **SYMMETRY (the critical fairness rule, §2):** every court is a strict LEFT/RIGHT mirror — the CD #7
  one-sided-team bug (BLUE won every bot match) was rooted in an asymmetric bumper layout; §2 makes
  symmetry a hard authoring law with a QA gate.
- **v5 fence:** courts touch NO fenced player-feel constant and NO ball-physics constant. Hazard→ball
  force reuses ONE new mode-owned Ball entry point (§3) + the existing v6 hazard objects. No new death
  mechanism (players die via the v6 `kill()` path exactly as in BRAWL).

---

## 1. THE COURT ROSTER (calm → chaos)

Eight courts across four bands. Each is a symmetric two-goal enclosed pitch (the v5 §5 shape): full-width
trampoline floor, bumper side walls with a mid-height goal mouth + `goal_zone` + back wall each end,
bumper ceiling, mirrored `player_spawn`s, **zero `powerup_spawner`s**. Distances obey the v5 flight gate
(nearest-spawn-to-centre > **395 px** trampoline drift AND centre-to-far-goal > **527 px** spring drift,
so reaching the ball and pressing it to the far goal REQUIRE boost — movement is load-bearing).

`tier` = the roster's calm→chaos rank (drives ordering + unlock, §4). `hazard` = which v6 mechanic it
needs (blank = authorable NOW).

| # | Court id | Band | tier | Size | Signature / intent | hazard (v6 dep) |
|---|---|---|---|---|---|---|
| 1 | `center_pitch` *(= existing `sports_court.json`, kept verbatim)* | CALM | 1 | Medium (2800×1600) | **The competitive default.** Pure sport & skill: two mid-field bumpers for caroms, clean lanes to each goal. The court the ladder is played on. | — |
| 2 | `the_box` | CALM · SIZE | 1 | **Small/tight** (2000×1200) | **Scramble.** Short lanes, close walls → fast possession swaps, wall-carom bank shots, constant contact. Rewards quick reads + tight aim over long flights. Still flight-gated (centre-to-goal ~640 px). | — |
| 3 | `long_haul` | CALM · SIZE | 1 | **Big/open** (3600×1900) | **Positioning & long flights.** Wide open middle, tall airspace → long boost runs, midfield interception reads, the biggest power-shot arcs in the set. Rewards spacing + fuel management. | — |
| 4 | `the_bowl` | CALM | 2 | Medium | **Calm variant.** A central symmetric bumper MOUND (two mirrored slopes) deflects centre balls sideways → skill in choosing which side to attack; no hazards, still pure sport. A gentle step toward chaos geometry. | — |
| 5 | `hammer_yard` | HAZARD | 3 | Medium | **The central spinning hammer.** A single lethal rotor on the court's exact centre axis sweeps the midfield: it **whacks the loose BALL around** (the fun) and **splats a careless player** who eats the blade. Learn the rhythm, strike on the clear beat. | `spinning_hammer` (rotor) |
| 6 | `minefield` | HAZARD | 3 | Medium-big | **Scattered landmines.** Symmetric pairs of proximity/timed bombs across the midfield; a detonation **punts the ball** (and kills a nearby player). Goals off a mine-punt = the laugh. Mines kept out of both goal mouths (no own-goal machine, §2). | `bomb` (landmine placement) |
| 7 | `the_crusher` | HAZARD | 4 | Medium | **Mid-field menace.** A telegraphed crusher (or falling-debris cadence) over dead-centre: the ball gets knocked out of the crush zone / punted by a dropped weight; players read the open dwell. More chaos than a single hammer, still readable. | `crusher` OR `falling_debris` |
| 8 | `the_scrapheap` | CHAOS | 5 | Medium-big | **Luck-based madness (the party finale).** Central hammer + symmetric landmine pairs + a falling-debris cadence, all at once. Goals are half-accidental hilarity — a ball ping-ponging off the hammer into a mine that punts it home. Everything symmetric + telegraphed; nobody's side is safer. | `spinning_hammer` + `bomb` + `falling_debris` |

**Roster shape:** 4 CALM (incl. 2 size-variety) + 3 single/double-hazard + 1 full-chaos = a clean
skill→luck spectrum. The lobby dials tone by picking a tier.

---

## 2. THE SYMMETRY + FAIRNESS RULES (critical — the CD #7 fix, generalised)

The `sports_court.json` design_intent already records WHY symmetry is load-bearing: the earlier
point-symmetric bumpers (one high-left, one low-right) systematically deflected rightward drives and
funnelled the ball into the LEFT goal, handing BLUE a bot-match blowout. **A vertical-axis mirror is
mandatory for EVERY court in this set.** The rules below are authoring law + a QA gate.

**SYM-1 — Strict left/right mirror about the centre X.** For every geometry/object at `x`, there is an
identical twin at `2*cx - x` with the same `y`, `w`, `h`, `tier` (goals swap `team`). This applies to
**platforms, bumpers, spawns, goal_zones, AND every hazard**. No point-symmetry, no "close enough."
Both mid-field bumpers (and any mound/slope) sit at the **same Y** so gravity treats both halves
identically (the exact fix noted in `sports_court.json`).

**SYM-2 — Goals equidistant.** Each `goal_zone` centre is the same distance from court centre; goal
mouths are the same size + height. The kickoff ball spawns on the centre axis (`_kickoff_center` already
uses `bounds.get_center().x`).

**SYM-3 — Symmetric hazards only.** A hazard is legal only if it is mirror-symmetric:
- A **single** hazard must sit ON the centre axis (a central hammer/crusher is inherently symmetric).
- Any **off-centre** hazard must be placed in **mirrored pairs** (a left landmine ⇒ an identical right
  landmine at the mirror X, same fuse/period/phase). Debris spawners drop on a symmetric pattern.
- Hazard **phase clocks are mirrored** — paired hazards fire in-phase (or in a deliberately symmetric
  offset), never in a way that pressures one team's half more at any instant.

**SYM-4 — No own-goal machine (hazards away from the goal mouths).** No hazard may sit where its
force/blast can repeatedly shove the ball into a goal it is near. Concretely: **every hazard's
danger/blast extent stays inside the central third of the court** (≥ court-half-width from each goal
mouth), so a hazard hit sends the ball into open play, not reliably into one net. A hazard whose blast
radius or swept arc overlaps a goal mouth is **rejected**. This keeps hazard goals *possible and funny*
without being a coin-flip own-goal generator.

**SYM-5 — No player spawned in a hazard; both teams face the identical threat.** Spawns are mirrored and
clear of every hazard's danger extent at spawn phase (the v6 fairness rule §2.0#3). Because the court is
a strict mirror, "everyone faces the same threat symmetrically" is satisfied by construction.

**SYM-6 — Calm courts are hazard-free.** Tier 1–2 courts (`center_pitch`, `the_box`, `long_haul`,
`the_bowl`) carry **zero hazards** — pure skill play for the competitive default. Lethality/chaos lives
only on tier 3+ courts.

**Lethality on chaos courts (per the 2026-07-05 doctrine):** hazards on tier 3+ courts MAY be lethal to
players (hammer splat, mine blast, crush) via the existing v6 `kill()` path — telegraphed + dodgeable +
symmetric. A player death is still a **respawn** here (SportsMode forces `lives_per_player = 99`), never
an elimination and never a score (v5 §1: no kill-race). So a hazard kill in Sports = a ~2s comedy
respawn + a moment of numbers advantage, NOT a match-ender. Credit is moot (Sports doesn't score kills),
but the hazard still **never sets an attacker / never invents an `environment` scorer** (INV-9 parity).

---

## 3. BALL ↔ HAZARD INTERACTION (the fun — how hazards move the BALL, not just players)

Today `Ball.gd` only self-drives from **player** contact (`_drive_from`, via its player-sensing Area2D on
mask `1<<0`). It has **no path to take a hazard hit** — that must be added. Keep the v5 architecture
intact: **ALL ball-force logic stays on `Ball.gd` behind ONE new mode-owned entry point**, so hazards
just *call* the ball; they never reach into player-feel or ball-physics constants.

### 3.1 The ONE new Ball entry point (mode-owned, reuse-first)

Add to `Ball.gd` a single public method (the same impulse form `_drive_from` already uses internally —
`linear_velocity += impulse / mass`, then re-cap):

```
func receive_hazard_impulse(impulse: Vector2) -> void
    # linear_velocity += impulse / max(mass, 0.01); limit_length(BALL_MAX_SPEED)
```

- This is the FEEL_REFERENCE §4.1 "explosion on props" math verbatim (`velocity = impulse / mass`), the
  same shared radial-impulse path bombs already use on props — so bomb/blast hazards need NO ball-specific
  code, they just include the ball among the props they push.
- The impulse is capped by the existing `BALL_MAX_SPEED = 2400` so even a full hammer whack stays
  **chaseable** (below player `max_speed`) — a hazard can't fling the ball into an untrackable blur
  (Pillar 5). No new constant touched; the cap already exists.

New mode-owned hazard→ball constants live on `Ball.gd` alongside the drive constants (NOT in `Tuning.gd`):

| Const | Value | Rationale (from FEEL_REFERENCE + v5 Ball feel) |
|---|---|---|
| `BALL_HAMMER_IMPULSE` | **1200** | Ball mass 0.6 → ~2000 px/s from rest, plus the blade's tangential velocity blended in. Matches the v5 §2 "power shot ≥ 1800 px/s" band → a hammer whack reads as a cannon-strike (the fun), still ≤ the 2400 cap. |
| `BALL_DEBRIS_IMPULSE` | **900** | ~1500 px/s punt from a dropped weight — a firm knock, below a hammer whack (a falling weight is heavy but slow). |
| Bomb/landmine blast on ball | reuses **FEEL §4.1** `explosion_impulse_center = 1600`, linear falloff `× (1 - dist/radius)` | At epicentre 1600/0.6 = 2667 → capped 2400 (a hard punt); near the ring edge a gentle nudge. Directly reuses the shipped explosion-on-props path — zero new ball math. |

### 3.2 Per-hazard ball effect (what each mechanic does to the ball)

- **spinning_hammer (rotor, `hammer_yard` / `the_scrapheap`):** the rotor's Area2D already senses players
  (to `kill`). Add the ball layer (`1<<6`) to the rotor's sense mask so it also detects the ball; when the
  ball is in the swept arc, call `ball.receive_hazard_impulse(blade_tangential_dir * BALL_HAMMER_IMPULSE)`
  (impulse along the blade's motion at contact — the ball flies off the way the blade is swinging), on the
  same `_touch_cd`-style per-contact cooldown so one clean whack per sweep, not a per-frame machine-gun.
  This is the **headline fun**: a loose ball at centre gets clobbered on the hammer's beat.
- **bomb / landmine (`minefield` / `the_scrapheap`):** on detonation the v6 bomb already does a radial
  lethal blast on players; extend its blast to the shared prop path so the ball (a prop) takes the FEEL
  §4.1 radial impulse away from the blast centre → a **punt**. No ball-specific code (it's just another
  prop in range). A mine under a resting ball rockets it out on the fuse pop.
- **crusher (`the_crusher`):** the closing plates should EJECT the ball rather than trap it — when the ball
  is between the plates at close, call `receive_hazard_impulse` along the open axis (perpendicular to the
  crush) at `BALL_HAMMER_IMPULSE` so it squirts out sideways (comedy + never a softlock; §5 anti-trap).
- **falling_debris (`the_crusher` alt / `the_scrapheap`):** a dropped weight that lands on/near the ball
  calls `receive_hazard_impulse(drop_dir_blended_outward * BALL_DEBRIS_IMPULSE)` → knocks the ball down &
  outward. Debris that misses the ball just bounces off the floor as normal.

**Feel target (verified in §6):** a hammer whack on a resting ball drives it **≥ 1800 px/s** (power-shot
band); a point-blank mine blast drives it **≥ 1500 px/s**; every hazard hit stays **≤ 2400** (chaseable).

### 3.3 What the hazard must NOT do to the ball
- Never trap/hold the ball (anti-softlock, §5) — every hazard EJECTS.
- Never aim its ball-impulse at a specific goal (SYM-4 keeps hazards in the central third, so a whack
  sends the ball into open play; the goal that results is emergent, not engineered).
- The ball is **never destroyed** by a hazard (unlike a player) — it is persistent for the stage (v5 §2);
  a hazard only imparts impulse.

---

## 4. SELECTION / ROTATION / UNLOCK

### 4.1 A `levels/sports_courts.json` court-set (mirrors `course_sets.json` / `circuits.json`)

A Sports match plays ONE court for the whole match (each goal reloads the same arena — the v5 single-arena
pattern; `next_level_path` returns `_arena_path`). So court selection = **pick one court per match**. The
court-set is the LIBRARY that a Sports court-picker UI + the unlock gate read. Minimal schema:

```json
{
  "_comment": "Sports courts. Read by SportsMode. Mirrors circuits.json/course_sets.json. tier = calm->chaos rank (also the unlock order); hazard = which v6 mechanic it needs (blank = no dep); unlock = gate (see 4.3).",
  "default_court": "center_pitch",
  "courts": [
    { "id": "center_pitch", "path": "res://levels/sports_court.json",        "display_name": "CENTER PITCH", "tier": 1, "hazard": "",                 "unlock": "always" },
    { "id": "the_box",      "path": "res://levels/sports/the_box.json",       "display_name": "THE BOX",      "tier": 1, "hazard": "",                 "unlock": "always" },
    { "id": "long_haul",    "path": "res://levels/sports/long_haul.json",     "display_name": "LONG HAUL",    "tier": 1, "hazard": "",                 "unlock": "always" },
    { "id": "the_bowl",     "path": "res://levels/sports/the_bowl.json",      "display_name": "THE BOWL",     "tier": 2, "hazard": "",                 "unlock": "sports_matches:2" },
    { "id": "hammer_yard",  "path": "res://levels/sports/hammer_yard.json",   "display_name": "HAMMER YARD",  "tier": 3, "hazard": "spinning_hammer",  "unlock": "circuit:scrapworks" },
    { "id": "minefield",    "path": "res://levels/sports/minefield.json",     "display_name": "MINEFIELD",    "tier": 3, "hazard": "bomb",             "unlock": "circuit:the_meltdown" },
    { "id": "the_crusher",  "path": "res://levels/sports/the_crusher.json",   "display_name": "THE CRUSHER",  "tier": 4, "hazard": "crusher",          "unlock": "circuit:the_foundry" },
    { "id": "the_scrapheap","path": "res://levels/sports/the_scrapheap.json", "display_name": "THE SCRAPHEAP","tier": 5, "hazard": "spinning_hammer",  "unlock": "sports_wins:3" }
  ],
  "rotate_sets": {
    "calm_ladder": ["center_pitch", "the_box", "long_haul", "the_bowl"],
    "chaos_night": ["hammer_yard", "minefield", "the_crusher", "the_scrapheap"]
  }
}
```

- **Back-compat:** absent file / unknown id → today's `DEFAULT_ARENA` fallback (`sports_court.json`). The
  existing `configure` fallback (`single_arena_path` empty or missing → default) is preserved verbatim.
- `rotate_sets` (optional) = named bundles for a "random from this tier band" lobby option (§4.2).

### 4.2 How `SportsMode.configure` chooses (minimal delta)

`configure` today: `_arena_path = single_arena_path if set else DEFAULT_ARENA` (with a file-exists
fallback). Extend it to resolve through the court-set, keeping the same fallback safety:

1. **Explicit pick (default flow):** the Sports court-picker writes the chosen court's `path` into
   `config.single_arena_path` (exactly as ArenaSelect writes a single arena today) → `configure` uses it
   as-is. **No new MatchConfig field.**
2. **Rotate flow (optional):** if `single_arena_path` names a `rotate_sets` key (e.g.
   `res://levels/sports_courts.json#chaos_night`) OR a new lightweight convention, `configure` picks a
   random court from that set's **unlocked** members. Recommend keeping v1 to explicit-pick only; add
   rotate in a later wave.
3. **Fallback:** unresolved / locked / missing file → `default_court` (`center_pitch`) — never a crash,
   never the ball-through-world bug (the CD #7 empty-path fallback is preserved).

This is a small `configure` extension + a `_load_court_set` helper mirroring `BrawlMode._load_circuit` /
`TrialsMode._load_course_set`. `next_level_path` is unchanged (still returns `_arena_path`).

### 4.3 Unlock progression (tie into v6 §4)

Reuse the v6 `Settings` `[progression]` block; add Sports-specific gating read by
`Settings.is_court_unlocked(court_id)`:
- **`"always"`** — the 3 calm/size courts (`center_pitch`, `the_box`, `long_haul`) are the always-open
  competitive base (parity with `meadow_mile` always-unlocked).
- **`"sports_matches:N"`** — unlocks after N Sports matches played (a new `sports_matches` counter, or
  reuse `matches_played`). `the_bowl` at 2.
- **`"circuit:<id>"`** — a hazard court unlocks when the **BRAWL circuit that owns its mechanic is
  cleared** (a satisfying cross-mode tie-in: you learn the spinning_hammer in `scrapworks`, then it shows
  up as a Sports court). `hammer_yard` ← `scrapworks`; `the_crusher` ← `the_foundry`;
  `minefield` ← `the_meltdown`. Reads `circuits_cleared` (already in v6 progression).
- **`"sports_wins:N"`** — the chaos finale `the_scrapheap` unlocks after 3 Sports match wins (the
  marquee reward, parity with v6's mastery gate).

**Rationale:** calm courts are always available (the ladder is never gated); hazard courts are earned,
and earning them through the matching BRAWL circuit means the player has already met + learned each
mechanic before it complicates a Sports match. Locked courts show greyed on the court-picker (v6 §4.3
pattern) and cannot launch.

---

## 5. ANTI-DEGENERATE / ANTI-SOFTLOCK (Sports-specific)

- **No ball trap.** Every hazard EJECTS the ball (§3.3); no crusher/geometry pocket can hold the ball
  indefinitely. If the ball is somehow motionless for > ~3s away from a kickoff, the mode's existing
  kickoff-recentre on the next stage covers it, but authoring must ensure no dead pocket exists.
- **Both goals always reachable.** SYM-1/2 guarantee mirrored reachable goals; the flight gate guarantees
  a driven ball CAN cross to either net.
- **Hazard can't wall off a half.** SYM-4 (central-third confinement) + no full-lane sweep (v6 hammer must
  leave a ≥120°/~1s clear window) mean a hazard never blocks a team from reaching the ball or a goal.
- **Chaos still scores.** Even on `the_scrapheap`, the clear beats + open lanes mean skilled play still
  drives goals; hazards *add* accidental goals, they don't replace intentional ones (QA SP-CHAOS below).

---

## 6. BUILD ORDER + MEASURABLE VALIDATION

### 6.1 What's authorable NOW (no new mechanic — geometry only)

**Wave 1 (immediate):** `the_box`, `long_haul`, `the_bowl` — plus keep `center_pitch`
(`sports_court.json`) verbatim. These need ONLY the shipped `Ball` + `GoalZone` + trampoline/bumper tiers
+ the v5 §5 court shape. No code. Author the JSON, run the per-gap flight analysis at real coords, ship.
This delivers the **calm + size-variety** breadth the owner asked for with zero mechanic dependency.

Also ship **Wave 1.5 (small code):** the `sports_courts.json` court-set + `SportsMode._load_court_set` +
the court-picker wiring (§4.2) + `Settings.is_court_unlocked` (§4.3). Unblocks selection/unlock for the
calm courts immediately.

### 6.2 What blocks on a v6 mechanic

| Court | Blocks on (v6 Batch-1) | + Ball hook |
|---|---|---|
| `hammer_yard` | `spinning_hammer` (rotor) landed & validated | `Ball.receive_hazard_impulse` + rotor senses ball layer |
| `minefield` | `bomb` (radial lethal blast) landed | bomb blast includes ball in the shared prop radial-impulse path |
| `the_crusher` | `crusher` OR `falling_debris` landed | crusher ejects ball / debris impulse via `receive_hazard_impulse` |
| `the_scrapheap` | ALL of `spinning_hammer` + `bomb` + `falling_debris` | all of the above |

Author each hazard court only after its mechanic passes the v6 per-mechanic gates (M-TELEGRAPH,
M-DODGEABLE, M-LETHAL-CLEAN). The `Ball.receive_hazard_impulse` addition (§3.1) is a tiny prerequisite
shared by all hazard courts — build it alongside the first hazard court (`hammer_yard`).

### 6.3 Measurable QA (QA drives rendered via `tools/run_game.ps1` + `gbplay.py`)

Run per court. Reuse the v5 §6 SPORTS criteria (SP1–SP11) as the baseline; add:

- **SC-SYM (symmetry gate — the CD #7 fix):** static check that every court's geometry/objects/hazards
  are strict left/right mirrors about centre X (mirror every `x`→`2cx−x` with matching y/w/h/tier; goals
  swap team; hazards paired or on-axis). Any un-mirrored element = FAIL. (Author-time lint + a QA `eval`
  over the loaded nodes.)
- **SC-FAIR (win-rate fairness):** across ≥ 10 bot-vs-bot matches per court, neither team wins **> 65%**
  and BOTH goals are scored on (goals recorded at BOTH `goal_zone`s over the sample). This is the direct
  regression test for the one-sided-team bug — a court that funnels to one net FAILS. (Use
  `SportsMode.diag()` `goal_seq` + `contacts`.)
- **SC-REACH (both goals reachable + flight-gated):** the ball reaches and scores in BOTH nets over a
  match; a zero-boost drive from an end spawn cannot reach the centre ball ≥ 9/10 (v5 SP4 per court, at
  real coords).
- **SC-NOTRAP (no softlock):** across ≥ 10 matches per hazard court, the ball is never held motionless by
  a hazard/pocket for > 3s (every hazard ejects); no stage ends in a stuck/unwinnable state; motion-health
  clean (`bot_motion_health()` — no stuck/head-bang/camp).
- **SC-HAZBALL (ball-hazard feel):** hammer whack on a resting ball → ball speed **≥ 1800 px/s** toward
  the blade's swing; point-blank mine blast → **≥ 1500 px/s** away from centre; every hazard hit stays
  **≤ 2400 px/s** (`eval` ball `linear_velocity` before/after a scripted hazard contact).
- **SC-NOOWNGOAL (SYM-4):** across ≥ 10 matches per hazard court, no single hazard accounts for a
  lopsided share of goals into the goal nearest it (a hazard that repeatedly punts the ball into one net
  = FAIL); confirm no hazard's danger/blast extent overlaps a goal mouth (static check).
- **SC-CHAOS (chaos still scores):** on `the_scrapheap`, a bot-vs-bot match still produces goals at a real
  rally cadence (mean time-to-goal > ~3s, not instant), goals happen at BOTH nets, and a skilled scripted
  power-shot line can still deliberately score (chaos adds accidents, doesn't replace skill).
- **SC-NOREG (preserve the shipped pitch):** `sports_court.json` (`center_pitch`) is byte-unchanged and
  still passes v5 SP1–SP11; the court-set falls back to it on any unresolved/locked/missing selection
  (the CD #7 empty-path ball-through-world bug stays fixed).
- **SC-CALM-CLEAN:** tier 1–2 courts contain **zero** hazard objects and zero `powerup_spawner`s (pure
  skill; SYM-6).
- **SC-LETHAL-PARITY (chaos courts):** a hazard kill respawns the player (never eliminates, `lives_left`
  never hits 0), never scores (`runner.scores` all-zero), never sets an attacker / invents an
  `environment` scorer (INV-9 parity), and is telegraphed + dodgeable (v6 M-DODGEABLE ≥ 8/10).

---

## 7. FENCE (restated)

Additive only: new **level-JSON courts** (geometry + the existing `goal_zone`/`player_spawn` + v6 hazard
object types), a `levels/sports_courts.json` court-set + a `_load_court_set` helper + a `configure`
selection extension, `Settings.is_court_unlocked`, a court-picker UI, and **ONE new mode-owned
`Ball.receive_hazard_impulse` method** (the FEEL §4.1 explosion-on-props impulse form the game already
uses). **NO fenced player-feel constant, NO ball-physics constant** (`BALL_RADIUS`/`mass`/restitution/
`BALL_MAX_SPEED`/drive consts) is changed; the new hazard→ball consts are mode-owned on `Ball.gd`
(deliberately separate, v5 §7). Lethal hazards reuse the v6 `kill()` path as-is (no new death impulse).
Any request to make a court asymmetric, put a hazard on/near a goal mouth, add a new death/impulse path,
or invent an `environment` scorer is an **auto-reject** (§2 SYM rules + v6 §2.0 doctrine).
