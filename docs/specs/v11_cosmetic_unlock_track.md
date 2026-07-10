# v11 — COSMETIC UNLOCK TRACK ("Horn Notches") — READY FOR BUILD

> Game-designer spec, 2026-07-10. The long-term-pull layer the game lacks: a cumulative-KO ladder of
> pure-cosmetic flair for YOUR goat. Fills the backlog item "cumulative-kill cosmetic unlock track
> (counter exists)". Grounded in: `docs/VISION.md` (pillars), `docs/GAME_ESSENCE.md` (fantasy-fit run
> below), v10's cosmetic-star doctrine (progression rewards are presentation, never pressure),
> `src/core/Settings.gd` (the existing `[progression]` save + CD 2026-07-06 self-healing discipline),
> `docs/briefs/character_theme_bible.md` (the Herd), and the shipped CharacterSelect / ArenaSelect
> UI grammar. One programmer slice; MVP subset needs ZERO new art.

---

## 0. TL;DR

- **Currency = credited Brawl KOs** (the SUPER-SMASH verb, raw `+1` events — never net score, never
  self-falls). One device-wide counter, already persisted as `Settings.total_kills` (two corrections
  required, §5.1).
- **10-tier ladder, 10 → 1000 KOs.** First unlock lands inside the first session (~1–2 matches);
  the cap is ~11–16 hours of Brawl. Math in §4.
- **All 10 MVP items are parameter cosmetics on EXISTING code-drawn VFX/text channels** (jetstream
  color, exhaust flame tint, KO-burst palette, name-banner title). No new textures. Art-gated
  upgrades (crown, alt hero palettes) are an appendix, not the slice.
- **Equip + progress live on CharacterSelect** (one FLAIR stepper + one KO-tally chip slotted into
  the existing stage — no screen redesign). **Celebration reuses the ArenaSelect one-shot pattern**,
  fired on CharacterSelect entry.
- **Cosmetic-only, hard-guaranteed:** flair never touches physics/Tuning, never gates content,
  yields to every gameplay telegraph, and is suppressed in Sports (team-read is sacred).

---

## 1. The player fantasy

**"I'm earning flair for MY goat."** Every rival you headbutt off the mountain is a notch on your
horns. The Bounce is a tournament; veterans should LOOK like veterans — a gold jetstream when you get
launched, blue-hot burners on your jetpack, a title under your name on the select screen. When a
friend sits down on the couch and sees your rainbow streak, the question is "how do I get THAT?" —
and the answer is always the same as the game's whole point: *go smash somebody.*

**Why KOs and not wins/matches:** the currency must reward the core verb, not attendance and not
outcome. Wins would starve the couch's weaker players (they'd never progress — anti-"one more
round"); matches-played would reward camping out the clock (Pillar 2 violation in spirit). Credited
KOs reward exactly the aggressive, airborne, horns-first play the game IS — even the player who loses
every match banks 2–3 notches and moves up the ladder. Death stays cheap; killing pays.

**Core verbs exercised (GAME_ESSENCE obligation):** the track is a *meta-reward for SUPER-SMASH* —
it adds zero verbs and must subtract zero readability. Its fantasy-fit test is: does the flair make
the smash/launch moments MORE spectacular without making the storm harder to read? (§7 gate C10/C14.)

**Fantasy-fit check (run per GAME_ESSENCE):** no change to airborne time, distances, super
decisiveness, or motion — this layer is presentation-only over the validated feel. It cannot violate
Pillar 2 (it *rewards* aggression), and it is explicitly gated on Pillar 5 (readability beats
prettiness — every item ships through the in-motion readability criterion, §7 C14). Passes.

---

## 2. The mechanic

### 2.1 Earning

- **Counter:** `total_kills` in `Settings` `[progression]` — **credited Brawl KOs banked at match
  end** (see §5.1 for the two required corrections to how it's fed today).
- **What counts:** a `+1` credited-kill event for a HUMAN player slot, in a **finished** BRAWL match
  (any arena_mode — RANDOM, SINGLE, or CIRCUIT). All human slots on the couch bank into the one
  device counter (the couch shares the wardrobe — same convention as the existing circuit unlocks).
- **What never counts:** self-falls (no increment — and the counter NEVER decrements); bot kills;
  bot-on-bot kills; Sports goals; Gauntlet wave kills (would inflate ~10× and cheapen the ladder);
  Trials (nothing to kill); quit/abandoned matches (only MATCH_END banks — cheap anti-grind-exploit
  and matches the existing `record_match_result` call site).
- **Unlock rule:** item *i* is unlocked iff `total_kills >= threshold[i]`. The unlocked set is
  **derived, never stored** — no second source of truth to corrupt or desync (the same reasoning as
  the circuit prefix-guard, applied by construction).

### 2.2 Equipping

- **One flair slot** (device-wide, applies to human P1's goat). Equipping is free, instant,
  reversible, and includes "NONE" (stock look is always available).
- Each item targets exactly one **channel** (jetstream / exhaust / KO-burst / title). One slot means
  no stacking — keeps the readability surface small and the UI to a single stepper. (Multi-slot is
  out of scope, §8.)

### 2.3 Where flair renders (the cosmetic-only contract)

- **Applies in:** BRAWL, TRIALS, GAUNTLET — on the human P1 player entity (and the CharacterSelect
  stage pose where the channel is previewable, minimum: title on the name banner).
- **Suppressed in SPORTS:** SportsMode already overrides skins with team colorways; flair could blur
  the team read of trails/bursts. Whole-mode suppression is the simple, safe rule.
- **Telegraph precedence (hard rule):** any gameplay-communication state OWNS its channel while
  active. Concretely: the super-charge fuse tint on the exhaust fire (`_fire.modulate`
  yellow→red lerp), the sprite hit-flash / super rainbow / damage-flush `self_modulate` states, and
  spawn-protect blink are UNTOUCHED — a cosmetic exhaust tint applies only in the neutral state, and
  cosmetic jetstream colors keep the streak's exact width curve, alpha gradient, and trigger
  conditions (color/gradient stops are the ONLY altered properties).
- **Luminance floor:** jetstream cosmetics must keep peak color value ≥ 0.8 and saturation ≤ 0.9 at
  the head of the ribbon (the streak is a "this player is LAUNCHED" telegraph; a dark streak would
  be a readability regression). This is why there is no "shadow/black" streak in the catalog.

### 2.4 Edge cases

- **Multiple tiers crossed in one match** (a winning human banks 10 KOs): all crossed items unlock;
  the celebration fires ONCE, for the highest new tier; the stepper shows every newly-available item.
- **Match ends by sudden-death / double-KO:** credited kills already banked in the match still count
  (banking reads the raw tally, not the outcome).
- **2–4 humans on the couch:** all human slots' credited kills sum into the counter (couch play
  ranks *faster* — good; the couch is the product).
- **Mid-match quit:** banks nothing (see §2.1). Not worth a partial-bank system.
- **Save rolled back / file deleted:** counter resets with it — acceptable; the save IS the profile.
- **Owner's `match_target_kills = 10` ruling:** untouched. The math in §4 is built ON it.

---

## 3. The catalog (10 tiers, ALL MVP-no-art)

Every item below re-parameterizes an existing code-drawn channel (allowed under the art-debt
doctrine: transient telegraph/VFX and text stay code). Names are Herd-flavored. Channels:
**STREAK** = knockback jetstream (`Player._streak` Line2D color+gradient), **FLAME** = jetpack
exhaust fire tint (neutral-state only), **KO-POP** = own-death burst palette (`Juice._death_burst`
gradient — death is a punchline; your KO is YOUR fireworks), **TITLE** = suffix on the
CharacterSelect name banner (e.g., "POGO — PEAK MENACE"; presentation-only text).

| Tier | KOs | id | Item | Channel | Look | Tag |
|---|---|---|---|---|---|---|
| 1 | 10 | `streak_gold` | GOLDEN JETSTREAM | STREAK | white→gold ribbon | MVP-no-art |
| 2 | 25 | `flame_blue` | BLUE-HOT BURNERS | FLAME | cyan-blue flame core | MVP-no-art |
| 3 | 50 | `kopop_confetti` | PARTY-POPPER KO | KO-POP | multicolor confetti palette | MVP-no-art |
| 4 | 100 | `title_menace` | TITLE: "PEAK MENACE" | TITLE | banner suffix | MVP-no-art |
| 5 | 175 | `streak_candy` | BUBBLEGUM JETSTREAM | STREAK | white→pink candy gradient | MVP-no-art |
| 6 | 275 | `flame_ember` | EMBER BURNERS | FLAME | deep orange + white core | MVP-no-art |
| 7 | 400 | `kopop_starburst` | STARBURST KO | KO-POP | white-gold star palette | MVP-no-art |
| 8 | 550 | `title_king` | TITLE: "KING OF THE MOUNTAIN" | TITLE | banner suffix | MVP-no-art |
| 9 | 750 | `streak_rainbow` | RAINBOW JETSTREAM | STREAK | hue-cycling ribbon (marquee) | MVP-no-art |
| 10 | 1000 | `flame_midnight` | MIDNIGHT BURNERS | FLAME | violet flame, white-hot core | MVP-no-art |

**Art-gated appendix (post-slice; do NOT block the build on these):**

| KOs | Item | Channel | Notes |
|---|---|---|---|
| 1000 | THE CHAMP'S CROWN | new accessory sprite above head | REPLACES tier 10's item as the cap when art lands (`flame_midnight` slides to a mid-tier); must pass the six-on-screen gameplay-zoom readability gate from the theme bible §6 |
| 1300+ | Alt hero palettes ("Berry Pogo", "Storm Butch"…) | tool-recolor of `bouncer_<color>_idle.png` | hue-family-locked per hero (color is the primary in-motion identifier — theme bible §6.1); MUST NOT use reserved P7 teal `#2FD0C0` / P8 red `#FF5A4A` |

Rationale for the mix: STREAK items are the marquee (most visible, moment-of-glory when launched —
and being launched happens to everyone constantly, so the flair shows off even when you're losing:
Pillar 4). FLAME is the always-on subtle one. KO-POP makes your own death funnier (Pillar 4,
literally). TITLEs are the bragging layer and cost the programmer one string concat.

---

## 4. Thresholds — pacing math (show your work)

**Ground truth (from live tuning + round_stats reality):** a 4-player Brawl to
`match_target_kills = 10` banks **~10 credited kills match-total across ~6–12 rounds in ~3–5 min**
(the winner holds 10; rounds are 10–30 s per VISION).

**Human KO rate:**
- **Solo vs 3 bots (the common validation case):** the human banks roughly a quarter-to-half of
  credited kills while learning (~2.5–5/match) and 10/match when winning → assume **avg 5 KOs /
  4-min match ≈ 75 KOs/hour** (range 40–120).
- **Full 4-human couch:** ALL credited kills are human → **~10 KOs / 4-min match ≈ 150 KOs/hour**.

| Tier | KOs | Cumulative time, solo (~75/h) | Couch (~150/h) | Beat |
|---|---|---|---|---|
| 1 | 10 | **~8–20 min** | ~4–8 min | **first session, guaranteed** (one won match = done; a losing learner gets there in 2–4 matches) |
| 2 | 25 | ~20–40 min | ~10–15 min | session 1–2 — "there's a LADDER here" |
| 3 | 50 | ~40–75 min | ~20–30 min | end of a long first evening |
| 4 | 100 | ~1.3–2 h | ~40 min | the first TITLE — the first brag |
| 5 | 175 | ~2.3–3.5 h | ~1.2 h | |
| 6 | 275 | ~3.7–5.5 h | ~1.8 h | |
| 7 | 400 | ~5.3–8 h | ~2.7 h | |
| 8 | 550 | ~7.3–11 h | ~3.7 h | "KING OF THE MOUNTAIN" — the long-game brag |
| 9 | 750 | ~10–15 h | ~5 h | the marquee rainbow — the "how did you GET that" item |
| 10 | 1000 | **~13–20 h** | ~6.7 h | cap; headroom target met |

Step ratio ~1.4–1.8× per tier: dense early (a fresh player unlocks 2–3 things on day one — the hook),
sparse late (~2–5 h between the last tiers — the pull). First unlock inside ~15 min: **met** on both
rates. Visible headroom past 10 hours: **met** on the solo rate (the couch rate finishing in ~7 h is
fine — couch groups burn content faster in every party game, and the art-gated appendix extends the
cap later). Thresholds are data (§5.2) — tune by editing the table, never code.

---

## 5. Build plan

### 5.1 Counter corrections (the load-bearing programmer work)

The backlog says "counter exists" — true (`Settings.total_kills`, persisted, sanitized section), but
it is fed wrong for this purpose. Two corrections, both at the existing seams:

1. **Feed it from ALL finished Brawl matches, not only CIRCUIT.** Today
   `PartyMatch._record_progression` returns early unless `arena_mode == CIRCUIT` — so RANDOM/SINGLE
   play (the fun default!) banks nothing. Split kill-banking from circuit-banking: bank KOs for every
   finished BRAWL match; circuit mastery/pity recording keeps its existing CIRCUIT-only guard
   untouched (do not disturb the CD progression fix).
2. **Bank RAW credited kills, not net score.** Today `human_kills` sums `runner.scores`, and
   `BrawlMode.on_kill` DECREMENTS score on a self-fall (floored at 0) — so a self-fall would erase a
   banked notch. The runner must keep a raw per-slot credited-kill tally (increment exactly where the
   `killer_idx >= 0 and killer_idx != victim_idx` credit branch fires) and bank the human slots' sum
   at MATCH_END. Scores/win logic unchanged.

Migration note: this widens what `total_kills` means (was: net circuit-match human kills; becomes:
credited all-Brawl human kills). **Existing saves keep their banked value as starting credit** —
justification: it can only UNDER-count a veteran's real play (circuit-only, net-of-self-falls), never
over-count, so honoring it is strictly player-friendly, needs zero migration code, and nobody's save
predates this week's dev builds anyway. No version bump needed.

### 5.2 Data

- `res://levels/flair.json` (or `assets/data/` — programmer's call, but DATA, per the levels-are-data
  rule): ordered array of `{id, name, channel, threshold, params}` where `params` are the channel's
  color/gradient-stop/string values. Thresholds and looks tune without code.
- Tuning note: no physics constants involved; color params live in the data file, not `Tuning.gd`
  (they are content, not feel).

### 5.3 Save schema (`user://settings.cfg` `[progression]`) + sanitize

New keys (same write-through + self-heal discipline as the CD fix; the existing sanitize pass gains
these rules — it must never weaken the circuit prefix guard):

| Key | Type | Default | Sanitize rule |
|---|---|---|---|
| `total_kills` | int | 0 (exists) | coerce int; clamp `>= 0` |
| `equipped_flair` | String | `""` | must be a known id in flair.json **AND** `threshold <= total_kills`; else reset to `""` (self-heal, log warning, rewrite save once — mirrors `_sanitize_progression`) |
| `pending_flair_unlock` | String | `""` | must be a known id whose `threshold <= total_kills`; else `""` |

No stored unlocked-list (derived from `total_kills` — see §2.1). `pending_flair_unlock` is
consume-once via a `take_pending_flair_unlock()` twin of the existing `take_pending_unlock()`.
Setting it: when banking KOs crosses ≥1 threshold, set it to the HIGHEST newly-crossed item id.

### 5.4 Surfacing / equip UX (slots into the shipped screens — no redesign)

**CharacterSelect** (the home of "MY goat"):
- **FLAIR stepper** — one additional `Stepper.tscn` instance placed on the Stage under the blurb
  (visible in ALL modes, including Trials/Gauntlet/Sports where the SettingsTray hides — it sits on
  the stage, not in the tray). Entries: `NONE`, every unlocked item (by name), plus ONE locked
  tease entry for the next item: `"<NAME> — <N> MORE KOs"` (non-equippable; selecting it keeps the
  previous equipped value). Changing the stepper writes `equipped_flair` write-through. Focus wiring
  follows the existing register/wire grammar (reachable from the grid via Down on the left column or
  the existing tray chain; ui-ux-designer spot-grades placement — note their open F-class flag about
  stepper focus treatment applies here too).
- **KO-tally chip** — one small cream chip (HintStrip chip grammar) adjacent to the stepper:
  `"★ 137 KOs — NEXT FLAIR AT 175"`. Reads `Settings.total_kills` + flair.json. This is the
  progress surfacing; it exists on the screen every player passes through every session.
- **Live preview:** minimum bar = TITLE items render on the name banner immediately when equipped;
  stage preview of streak/flame/KO-pop is NOT required for the slice (they preview in the next
  match — acceptable; do not build a VFX-preview rig).

**Match end (SHOULD, P2 — cut from the slice if tight):** one line in the existing MATCH_END banner
area: `"+7 KOs (137)"`. The pull loop is stronger with banked-feedback at the moment of banking, but
the CharacterSelect chip alone is a shippable MVP.

### 5.5 Celebration (reuse the ArenaSelect grammar exactly)

On CharacterSelect entry, consume `take_pending_flair_unlock()` (consume in `_ready`, fire after the
entry stagger in `enter()` — the exact `_pending_celebrate` pattern from ArenaSelect): scroll/focus
snap to the FLAIR stepper, banner flash with the item name (`"FLAIR UNLOCKED — GOLDEN JETSTREAM"`),
the win-fanfare sting + ui pop, one-shot. Because the flag was consumed, re-entering is silent.
No mid-match toasts, ever (Pillar 5 — nothing competes with the storm for attention).

### 5.6 What the programmer does NOT build

No shop, no currency besides the counter, no per-item preview rig, no per-hero equip memory, no
multi-slot outfits, no new screens, no new textures.

---

## 6. Out of scope (explicit)

- Per-controller/per-player profiles (P2–P4 equip) — device-wide P1 slot only.
- Per-hero equip memory, multi-channel stacking, outfit sets.
- Art-gated items (crown, alt palettes) — appendix only; each must pass the theme-bible §6
  six-on-screen readability gate before shipping.
- Any Sports/Gauntlet/Trials-specific currencies or tracks (their modes keep their own unlock
  systems untouched).
- Challenges/achievements ("win without dying") — future layer; the KO ladder is the spine.
- Anything timed, rotating, expiring, or purchasable. Never. (v10 doctrine.)

---

## 7. QA success criteria (numbered; driver-verifiable via gbplay eval / screenshots / scripted input)

Setup for all: fresh save unless stated (delete `user://settings.cfg`); Brawl = 1 human + bots
unless stated; read state via `eval` on `Settings`.

- **C1 — credited-only increment.** Fresh save: `Settings.total_kills == 0`. Play one bot Brawl to
  MATCH_END where human slots bank K > 0 credited kills (read the runner's raw tally before end).
  After MATCH_END: `total_kills == K` exactly.
- **C2 — self-falls never count and never erase.** Set `total_kills = 5` (eval). In a match, drive
  P1 into the blast zone twice with no kills, finish the match: `total_kills == 5` (no increment, NO
  decrement — this is the §5.1(2) regression test).
- **C3 — bot kills never count.** Spectate-style match (human passive at a safe spawn is
  insufficient — accept any run where bots score ≥3 credited kills on each other and the human
  scores 0): `total_kills` unchanged.
- **C4 — Brawl-only.** Finish one Sports match (human scores goals) and one Trials course and one
  Gauntlet run with ≥5 wave kills: `total_kills` unchanged after all three.
- **C5 — all Brawl arena modes bank.** One RANDOM-rotation match and one SINGLE-arena match each
  increase `total_kills` (the CIRCUIT-only gap is closed); and a CIRCUIT match still ALSO updates
  circuit mastery/pity exactly as before (regression: `circuit_plays` bumps, prefix guard intact).
- **C6 — threshold + celebration fires once.** Set `total_kills = 9`; finish a match banking ≥1 KO:
  `pending_flair_unlock == "streak_gold"`. Enter CharacterSelect: celebration plays (screenshot the
  banner flash; sting audible in the SFX bus), flag now `""`. Leave and re-enter CharacterSelect:
  silent (screenshot shows no banner).
- **C7 — equip persists across restart.** Equip GOLDEN JETSTREAM via the FLAIR stepper; kill the
  process; relaunch: `equipped_flair == "streak_gold"` and the stepper shows it selected.
- **C8 — flair renders in match.** With `streak_gold` equipped, get P1 launched (smash impulse >
  streak threshold): screenshot shows a GOLD ribbon on P1 while a launched BOT's ribbon stays stock
  white (flair is P1-only).
- **C9 — locked items can't equip.** With `total_kills = 30`, the stepper's tease entry reads
  `"PARTY-POPPER KO — 20 MORE KOs"`; attempting to select/confirm it leaves `equipped_flair`
  unchanged (eval before/after).
- **C10 — zero gameplay delta.** With each of the 4 channel types equipped in turn (streak, flame,
  KO-pop, title), run the same seeded scripted-input sequence (spawn, N fixed bounces + boosts +
  one smash) used against a no-flair control run: per-frame-sampled P1 positions identical within
  float epsilon, and a full bot match reports clean `round_stats.motion_health`. Also assert
  `Tuning.gd` values byte-identical (flair touches no Tuning field).
- **C11 — save self-heals.** Hand-write `equipped_flair = "hax_crown"`, `total_kills = -50`,
  `pending_flair_unlock = "streak_rainbow"` into settings.cfg; boot: no crash/parse error;
  `total_kills == 0`, `equipped_flair == ""`, `pending_flair_unlock == ""` (rainbow's threshold >
  0), warning logged, file rewritten clean. Circuit progression fields untouched by the heal.
- **C12 — multi-tier crossing.** Set `total_kills = 8`; bank a 10-KO winning match (18 total):
  tiers 1 AND 2 both appear unlocked in the stepper; celebration fires ONCE, for `flame_blue`
  (the highest).
- **C13 — telegraph precedence.** With `flame_blue` equipped, hold a super charge: screenshots
  during charge show the fuse tint (yellow→red) on the exhaust, NOT blue; on release/neutral the
  blue flame returns. Damage flush, hit-flash, and spawn-blink states verified visually unchanged.
- **C14 — Sports suppression + readability gate.** (a) Equip any flair, play Sports: screenshots
  show stock team-colorway trails/bursts, zero flair. (b) In a 4-player Brawl with `streak_rainbow`
  equipped, capture P1 mid-launch at gameplay zoom: the streak must still read instantly as the
  launch telegraph (QA grades vs a stock-streak control shot; a FAIL here blocks the item, not the
  system — Pillar 5).
- **C15 — counter surfacing accuracy.** On CharacterSelect the KO chip's number equals
  `Settings.total_kills` (eval + screenshot) and its "NEXT FLAIR AT N" matches the lowest
  threshold `> total_kills` in flair.json; at `total_kills >= 1000` it reads a completed state
  (e.g., `"ALL FLAIR EARNED"`), no crash, no dangling hint.

---

## 8. Notes to roles

- **Programmer:** the whole slice is §5. MVP = §5.1–§5.5 minus the P2 match-end line. Flag anything
  where a channel hook would touch a telegraph path — precedence (§2.3) is the one place this
  feature can rot the game.
- **QA:** C10 and C14 are the pillar guards — run them per-item, not once. Watch MOTION (streak in
  flight), not stills only.
- **UI/UX:** stepper + chip placement on the Stage is yours to spot-grade; grammar is fixed
  (Stepper.tscn, cream chip, no new widget types). Fold in your open stepper-focus F-class fix.
- **Art (later):** crown + alt palettes per §3 appendix; both hard-gated on the six-on-screen zoom
  test. Do not start until the MVP ladder ships.
