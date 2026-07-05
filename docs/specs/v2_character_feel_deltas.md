# v2 — Character Feel Deltas (the Herd get identity through feel)

> **Owner:** Lead Game Designer. **Status:** SPEC for review (no code). **Grounding read:**
> `docs/GAME_ESSENCE.md`, `docs/VISION.md`, `docs/briefs/character_theme_bible.md`,
> `src/core/Tuning.gd`, skills `game-feel-reference` + `gottabounce-tuning-and-flags`.
> **Roadmap:** Phase 2 ("identity through feel"). The theme bible flagged these deltas for the
> game-designer and forbade designing them there — this is that design.

## 0. Doctrine and the hard line

The movement/combat feel is THE product (owner north star: TowerFall bar). The base constants in
`src/core/Tuning.gd` are carefully tuned, invariant-locked, and several are DO-NOT-TOUCH. Therefore
character identity is delivered as a **thin, additive, per-instance multiplier layer applied at the
Player's read sites** — never as an edit to any base Tuning constant.

**The five non-negotiables this spec obeys:**

1. **Additive, per-character, data-driven.** A `CharacterProfile` (all fields default to the
   identity value 1.0 / 0.0) is attached to each Player at spawn. Effective feel = base Tuning value
   × the profile's multiplier, computed *in the Player*, at read time.
2. **Standard == today, byte-for-byte.** The default profile (all levers at identity) reproduces
   the current game exactly. Any character/slot with no profile, and the fallback `"bouncer"`
   character, resolve to Standard. **Billy IS Standard** (the bible's "baseline everyone deviates
   from"), so the current build's feel already ships as a named character with zero risk.
3. **No base Tuning constant is edited.** Zero DO-NOT-TOUCH constants change. The levers *scale*
   computed values; where a scaled value participates in an invariant, the lever's range is proven
   to keep the invariant true, and the lever is FLAGGED for change-control sign-off (§5).
4. **Core invariants survive every allowed value** — proven per lever in §1: flight still REQUIRED
   to traverse, the super is still the one kill move, min-bounce floor is unscaled, the hitstun
   triad constants are untouched, `normal_boost_max_speed < smash_impact_min` still holds.
5. **Readable identity, not power creep.** Deltas are small (mostly ±8–12%), each character trades a
   strength for a weakness, and Billy proves "no gimmick" is a valid pick. No strictly-dominant hero.

**Core verbs exercised (GAME_ESSENCE obligation):** BOUNCE (apex lever), FLY/BOOST (air-control &
boost levers), SUPER-SMASH & RECOVER (knockback dealt/taken, size). Every lever moves a verb the
game is built on; none adds a new system.

---

## 1. The `CharacterProfile` schema — the six levers

Smallest set that yields distinct, legible feel. Each field is a scalar multiplier on ONE Tuning
read site inside `Player`; identity value = 1.0 (Standard). No character uses more than 3 non-default
levers. Ranges below are the **hard clamps** the loader enforces (a profile out of range fails to
load, not silently clamps — surfaces authoring mistakes).

| # | Field | Type | Default | Clamp | Scales (Player read site) | Feel it buys |
|---|---|---|---|---|---|---|
| 1 | `size_scale` | float | 1.0 | 0.90 – 1.10 | `BODY_RADIUS` (collider) **and** the sprite/body draw scale, together | small = nimble/small target; big = looms, easy to hit |
| 2 | `bounce_apex_mult` | float | 1.0 | 0.95 – 1.08 | the tier **target height** `h` passed to `BounceResolver.resolve()` (NOT `min_bounce_height`, NOT the fuel-refund tier lookup) | springy / floaty vs. grounded |
| 3 | `air_control_mult` | float | 1.0 | 0.85 – 1.20 | `air_drift_accel` **and** `air_drift_max_speed`, together | tight steering / good glide vs. drifty |
| 4 | `boost_power_mult` | float | 1.0 | 0.90 – 1.12 | `normal_boost_accel` **and** `normal_boost_max_speed`, together | zippy jetpack vs. sluggish |
| 5 | `knockback_dealt_mult` | float | 1.0 | 0.90 – 1.12 | the smash impulse THIS player applies, **before** the `smash_impulse_max` clamp | how hard your hits land (sub-cap) |
| 6 | `knockback_taken_mult` | float | 1.0 | 0.90 – 1.12 | the smash impulse THIS player RECEIVES, **before** the `max_speed` clamp | how far you fly when clipped |

### 1.1 Why each range is safe (invariant proofs)

- **`size_scale` (0.90–1.10).** Multiplies collider radius and draw scale in the *same* assignment
  so the circle collider always equals the drawn ball (art-bible rule §5 mitigation 2:
  collider==art). At 0.90, radius 44→39.6 px (≈79 px tall body — still above the ~25 px readability
  floor; color, not size, is the in-motion identifier per the bible). At 1.10, 44→48.4 px — must be
  re-checked against spawn spacing and tightest tile gaps (§4 REJECT). Not on any invariant; not
  fenced.
- **`bounce_apex_mult` (0.95–1.08).** Scales the tier launch height linearly. `min_bounce_height`
  (48 px, INV-11 "never settle") is a separate absolute floor inside `resolve()` and is **NOT
  scaled** — every character still kicks back up from rest, no camping posture. Traversal risk: a
  spring bounce (apex 480 px) at 1.08 → 518 px, +38 px. Level designers place flight-required
  platforms above spring-apex *with clearance*; +8% must be re-verified per level (§4 REJECT — the
  per-character traverse check). Because a passive bounce is never `super_active`, raising apex does
  NOT create smash eligibility even where the ~930 px trampoline crossing already sits above the
  900 px `smash_impact_min` gate (the license, not the speed gate, protects neutral play —
  game-feel-reference §3/§5.1). FLAGGED (§5) for the traverse re-verify only.
- **`air_control_mult` (0.85–1.20).** Air drift is "place your landing," never flight (FEEL §2.3);
  it appears in no invariant. At 1.20, `air_drift_max_speed` 340→408 px/s — still far below the
  900 px/s smash gate and the 760 px/s boost ceiling, so it can never reach a smash or fake a super.
  Not fenced.
- **`boost_power_mult` (0.90–1.12).** Touches `normal_boost_max_speed`, the LEFT side of INV-1
  (`normal_boost_max_speed < smash_impact_min` = 760 < 900 — "plain boost must never reach the smash
  gate"). At the 1.12 cap: 760 × 1.12 = **851 < 900 — INV-1 holds with 49 px/s margin.** The clamp
  is set at 1.12 (not higher) *specifically* to preserve this. FLAGGED (§5): any profile using this
  lever needs the INV-1 recheck before build.
- **`knockback_dealt_mult` (0.90–1.12).** Applied to the attacker's impulse *before* the
  `smash_impulse_max` (2200) clamp, so top-end hits still clamp identically for everyone — the lever
  only shapes **sub-cap** hits (chains, grazes, shoves = "hit solidity"). It cannot manufacture a
  bigger-than-designed one-shot. Hitstun is *derived* from the resulting impulse via the protected
  triad constants (unchanged) and still hard-caps at 0.55 s. FLAGGED (§5): lethality-owned math.
- **`knockback_taken_mult` (0.90–1.12).** Applied to the received impulse *before* the `max_speed`
  (3000) clamp. **Proof the super stays the kill move:** a clean centered super delivers impulse
  ≈ 3875 px/s (game-feel-reference §5.2); at the tankiest allowed value, 3875 × 0.90 = 3487 > 3000 →
  still clamps to cap → **a Butch still exits at max_speed from a clean super and dies.** The lever
  only changes fate on grazes/chains/sub-cap hits — exactly "weight," never "immune." FLAGGED (§5):
  lethality-owned math.

### 1.2 What is deliberately NOT a lever (and why)

- **`gravity`** — too load-bearing (bounce heights, apex, hang time, aim-sag all derive from it) and
  entangled with too many invariants. "Floaty vs. heavy" is delivered by `bounce_apex_mult` +
  `air_control_mult` instead, which are locally bounded.
- **Fuel (`fuel_max`, drain, `fuel_per_bounce/bumper`)** — the economy is the recovery-gamble engine
  and largely DO-NOT-TOUCH (INV-2/3/7). A per-character fuel edge is the strongest possible
  power-creep vector and hard to keep legible; excluded from v2.
- **Super impulse / aim time (`super_boost_impulse_full`, `super_aim_max`)** — `super_boost_impulse_full`
  is DO-NOT-TOUCH and the super's constant power is a closed decision. The kill move stays identical
  for every hero on purpose (readability: "the super always hits the same").
- **True randomness (Puff's "unpredictable drift")** — delivered as *low* `air_control_mult` (drifty,
  hard to place), NOT an RNG term. A random lever is unbalanceable and unreadable; rejected.
- **Vex's spin/sideways-smash sweet spot** — DEFERRED. It needs a new smash-shape lever + hitbox
  work the art eval flagged as future; out of scope for v2 (see §2 Vex).

---

## 2. The six profiles (design intent from the theme bible)

Each line: the fantasy → the ≤3 levers → the balancing weakness. All unlisted levers = 1.0.

- **POGO** (pink, the mascot — featherweight mobility glass-cannon):
  `bounce_apex_mult 1.08`, `knockback_taken_mult 1.10`, `size_scale 0.92`.
  Springiest and hardest to clip (small), but flies furthest when caught (light) — the bounce verb
  over the smash verb. *Weakness:* dies easiest to any solid hit.
- **BUTCH** (blue, the co-star — heavyweight smash bro):
  `knockback_dealt_mult 1.12`, `knockback_taken_mult 0.90`, `size_scale 1.08`.
  Hits hardest (sub-cap solidity) and shrugs off grazes, the smash verb incarnate. *Weakness:* the
  biggest target on the mountain — easy to hit, and a clean centered super still kills him (proven
  §1.1).
- **ZIGGY** (green, the daredevil — technician pilot):
  `air_control_mult 1.18`, `boost_power_mult 1.08`.
  Tightest steering and best recovery/glide — owns the fly + recover verbs. *Weakness:* zero combat
  edge (neutral knockback both ways); wins by out-flying, not out-hitting.
- **PUFF** (yellow, the wildcard — floaty comic):
  `bounce_apex_mult 1.10`, `air_control_mult 0.88`.
  Highest, hangiest air in the cast — max comedy physics. *Weakness:* the drifty low air control
  makes that big air hard to *aim* (the "no plan, somehow wins" fantasy without RNG).

  > Note: `bounce_apex_mult 1.10` exceeds the §1 clamp of 1.08. **Puff is capped to 1.08** unless the
  > per-level traverse re-verify (§4) passes for Puff at a higher value under a change-control ticket.
  > Ship Puff at 1.08; treat 1.10 as an aspiration pending that check.
- **VEX** (purple, the rival — slippery trickster, intentionally near-baseline):
  `size_scale 0.96`, `air_control_mult 1.08`.
  Small and slippery — annoying to pin down. Deliberately the lightest-touch profile: the bible
  reserves Vex's real identity (a spin/sideways-smash sweet spot) for a DEFERRED smash-shape lever.
  *Weakness:* no offensive buff; pure evasion, must out-last rather than out-hit.
- **BILLY** (orange, the veteran — THE baseline):
  All levers 1.0. Billy **is** the Standard profile — the "no gimmick" pick and the byte-for-byte
  current feel. He is the balance anchor everyone else is measured against.

Deltas were chosen so each hero trades a strength for a weakness (Pogo small-but-fragile, Butch
hard-but-huge, Ziggy mobile-but-toothless, Puff floaty-but-imprecise, Vex slippery-but-soft), and
Billy proves baseline is competitive — the party-brawler legibility target, not a fighting-game tier
list.

---

## 3. How it plugs in

**Where profiles live.** A `CharacterProfile` **Godot Resource** (`class_name CharacterProfile
extends Resource`, one `@export` float per §1 field, all defaulting to identity), one `.tres` per
character under e.g. `src/core/characters/<id>.tres` (`pogo.tres`, `butch.tres`, …). Resource (not
JSON) matches the existing pattern — `MatchConfig` is already a `Resource` — gives typed `@export`
fields, and lets the loader assert the §1 clamps on load. A tiny registry (`CharacterProfiles.gd`
autoload or a static `for_id(id) -> CharacterProfile`) maps `character_id` → profile and **returns a
fresh all-identity Standard profile for any unknown id or `"bouncer"`** (so absence = today's feel).

**How the Player reads it (the additive layer).** The spawn path already carries the id: the mode's
`spawn_plan()` puts `config.character_for(i)` into each descriptor's `"character"` field
(`src/modes/BrawlMode.gd:46/57`), and `PartyMatch._spawn_player()` already sets `p.skin` from the
descriptor (`src/modes/PartyMatch.gd:221`). Add, right beside it:

- `p.profile = CharacterProfiles.for_id(str(desc.get("character", "bouncer")))` — set **before**
  `add_child(p)` so `_ready()` can size the collider from it.
- `Player` holds `var profile: CharacterProfile` (defaults to a Standard instance so a Player
  constructed without one — dev/test — behaves exactly as today).
- Every feel read the levers touch goes through a small effective-value helper on the Player, e.g.
  `_eff_air_accel()` → `Tuning.air_drift_accel * profile.air_control_mult`, the tier height passed
  into `BounceResolver.resolve()` → `h * profile.bounce_apex_mult`, received impulse in
  `receive_smash()` → `× profile.knockback_taken_mult` before the `max_speed` clamp, etc. **Base
  `Tuning.*` values are read unmodified; the multiply happens only at the Player call site.** This
  keeps `Tuning.gd` the untouched single source of base truth and makes the delta layer greppable
  (`profile.` marks every identity-bearing read).

**Collider stays the sphere (art-bible rule).** `size_scale` multiplies `BODY_RADIUS` and the body
draw scale in one place at `_ready()` (`BODY_RADIUS` becomes a per-instance `_radius = BODY_RADIUS *
profile.size_scale`), so the `CircleShape2D` radius always equals the drawn ball radius. Squash/
stretch remains a cosmetic scale on `_body` on top of that circular collider, exactly as today — the
collider is never made non-circular, and art==collider holds at every size.

**Bots.** Bots play by human rules (INV-8); a bot spawned as a character reads the same profile. This
is a feature: it makes mirror/mixed bot matches the balance instrument (§4).

---

## 4. Balance + validation plan (what QA drives and what triggers REJECT)

All checks run **rendered** (headless is no-crash only). Standard/Billy is the control.

**A. Standard-parity gate (must pass first).** Spawn an all-Billy (or all-`"bouncer"`) match and
confirm every §1-touched metric equals a pre-change capture: apex heights per tier, air-drift top
speed, boost top speed, clean-super victim exit speed, hitstun duration. **Any drift = REJECT** (the
"Standard == today byte-for-byte" contract is broken).

**B. Per-character feel targets (each must be *felt* and measured):**
- *Pogo springy:* on the trampoline tier, Pogo's apex is measurably higher than Billy's by ≈ the
  lever (h ×1.08 → apex ×1.08, ~270→~292 px) and reads as "bouncier" on a burst trajectory.
- *Butch solidity:* in scripted sub-cap chain hits, Butch launches victims measurably further than
  Billy does, and Butch himself travels less far than Billy from an identical sub-cap hit — while a
  clean centered super still launches Butch to max_speed and kills him (the invariant test, both
  directions).
- *Ziggy pilot:* Ziggy's post-launch recovery-to-surface success rate (scripted knockback → boost
  back) exceeds Billy's; steering feels tighter in a slalom burst.
- *Puff air:* Puff's hang time per bounce exceeds Billy's; landing-spot precision (variance of where
  a scripted drift lands) is measurably *looser* — floaty, not just higher.
- *Vex slippery:* Vex is hit less often than Billy in an identical bot-melee (smaller target + higher
  air control), with no knockback advantage.

**C. Traverse re-verify (flight-required invariant, per level × per character).** Re-run the level
designer's movement-tool-per-gap check for **every profile that raises `bounce_apex_mult`** (Pogo,
Puff) on **every shipped arena**. If any character can reach a flight-required platform by bouncing
alone, **REJECT** that lever value (or the level's clearance is fixed first).

**D. Dominance / win-rate spread (the anti-power-creep gate).** Bot-vs-bot, bots at **equal level**
so difference is character-only:
- *Mirror sanity:* 6 same-character matches (all-Pogo, all-Butch, …) should each play cleanly and
  finish (no stalls, no un-killable states, motion-health clean).
- *Mixed spread:* run a large batch of 6-way matches, one of each hero, equal bot level, many seeds.
  **Target: each hero's match-win share is within ±10 percentage points of even (even = 16.7%).**
  A hero consistently outside that band = a delta to trim. (Bots-as-feel-instruments: because bots
  cheat nothing, a lopsided share is a character-balance signal, not "AI difficulty.")
- *Kill-fate spread:* no hero should have a share of *deaths-to-clean-super* meaningfully below
  average (would mean a character is dodging the kill move — a §1 invariant leak).

**E. Motion-health (GAME_ESSENCE gate, every character).** `PartyMatch.bot_motion_health()` —
`stuck_episodes`, `underside_bounces`, `blocked_ascent`, `detours` — must stay clean for every
profile. A lever that induces head-banging, stalls, or jitter (e.g. a size/apex value that makes a
character wedge under a platform) = **REJECT**.

**F. Readability gate (art-bible §5).** In-engine screenshot at `grade_far` zoom with all six on
screen: each still distinguishable, none reads as noise, and no `size_scale` value pushes a body
under the ~25 px readability floor. **REJECT** any size value that fails.

**Any-lever REJECT triggers (summary):** Standard parity drifts (A); a character can traverse a
flight-required gap by bounce alone (C); a character survives a clean centered super (B/D-kill-fate);
a character one-shots from neutral; win share outside ±10 pts (D); motion-health degrades (E);
readability fails at 25 px (F); or INV-1 (`boost×max < 900`) fails for any boost-lever profile.

---

## 5. Change-control flags (sign-off REQUIRED before build)

No lever **edits** a base `Tuning.gd` constant, so **no DO-NOT-TOUCH constant is touched** — the
DNT list is respected in full. Flags below are because a lever *scales* a value that participates in
an invariant or a protected system; per skill `gottabounce-change-control` these need sign-off on the
**ranges** before implementation:

| Lever | Used by | Why flagged | Sign-off needed |
|---|---|---|---|
| `boost_power_mult` | Ziggy | Scales `normal_boost_max_speed`, the left side of **INV-1** (`< smash_impact_min` 900). Proven safe at the 1.12 clamp (851 < 900) — but any range change re-opens INV-1. | INV-1 recheck (tuning owner) |
| `knockback_dealt_mult` | Butch | Scales the **lethality-owned** smash-impulse math (feeds the protected hitstun triad, though the triad *constants* are untouched). | Lethality/feel sign-off |
| `knockback_taken_mult` | Pogo, Butch | Same lethality-owned path on the receive side; the "super is still the kill" invariant depends on the 0.90 floor (proven §1.1). | Lethality/feel sign-off |
| `bounce_apex_mult` | Pogo, Puff | Not a Tuning DNT, but scales tier launch → touches the **flight-required traversal invariant** (GAME_ESSENCE) and interacts with the min-bounce floor (kept unscaled). | Per-level traverse re-verify (level design) |

`size_scale` and `air_control_mult` are **not** fenced (no invariant participation; air drift can
never reach the smash gate; collider==art preserved) and need no change-control sign-off — only the
normal §4 validation.

---

## 6. Implementation order (for the programmer, when greenlit)

1. `CharacterProfile` resource + Standard fallback + registry (`for_id`); wire `p.profile` in
   `_spawn_player`; **ship with every profile at identity** and pass the §4-A parity gate — this
   proves the layer is truly additive before any delta exists.
2. Add the effective-value read helpers in `Player`; still all-identity; re-run parity (A).
3. Land Billy(=Standard) + the two **unfenced** profiles first (Vex, and Ziggy's `air_control`
   only), validate (§4-B/D/E/F).
4. Land the flagged levers **one lever at a time** (tune-one-thing doctrine) after their §5 sign-off:
   `boost_power` (Ziggy), then `bounce_apex` (Pogo/Puff) + traverse re-verify, then the knockback
   pair (Pogo/Butch) + kill-fate/dominance batch.
```
