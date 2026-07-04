# Owner directive — 2026-07-04 — Arena direction (islands-over-void, but VARIED) + audio sourcing

> Owner (Devin) answers to the two pending decisions. High-authority. Reconcile arena/level and audio
> work against this. Companion to `owner_2026-07-03_arena_size.md` (2x + flight-required) and
> `owner_2026-07-03_lives_damage_killrace.md` (the kill-race + damage model).

## 1. Arena / kill-shape — islands-over-void ADOPTED, but levels VARY in style
- **Primary/default kill shape = islands-over-a-void** (confirmed). The kill identity is "knock people
  OFF / into a blast void → off the screen" — this delivers the "smash rivals off the screen" fantasy
  and fixes the central-pit dominance (the pit capped edge-kills ~50% and caused all the uncredited
  "dead-air" deaths; 3 independent analyses + CD verdict #3 converged on this).
- **NOT a monoculture — different levels can have different STYLES / gimmicks**, as long as the kill
  identity (knock off/through into a void) holds. The circuit is variety over a shared through-line.
- **Owner's concrete seed (a variety example, build later):** a CHAOTIC level fought **inside a
  CYLINDER with a hole in the BOTTOM** — you try to knock opponents down through the hole. (A
  contained/vertical arena where the "void" is a central floor-hole you funnel people into — note
  this is deliberately the INVERSE of the rejected grassy central-pit: here the enclosed-cylinder
  framing + knock-DOWN-through-the-hole IS the gimmick/identity, not an accidental hole in an open
  floor. Design it so it reads and plays as intentional.)
- **The current `grassy_expanse` (central pit) survives as ONE variant** — a "chase / big map", NOT
  the flagship/tutorial. It's validated and shippable as a variant.
- **Build order:** new islands-over-void FLAGSHIP arena first (becomes the primary test/tutorial level
  + LEVEL_POOL default) → then ~9 more VARIED levels (styles/themes/gimmicks, incl. eventually the
  cylinder) to form the ~10-level circuit → then all pacing/feel/CD QA runs on the circuit rotation.
- Keep the earned constraints: flight required to traverse (GAME_ESSENCE), edge/void = the blast
  zone, level-relative bounds, the readable void treatment (pit_void_rendering brief generalizes).

## 2. Audio — GREENLIT, sourcing decided
- **Reuse the existing SFX library** at `D:\Dropbox\MyGames\SamuraiRobot2.0\assets\sounds\fx`
  (207 mp3 files — bounce/pop/hit/roar/combo/UI/announcer-ish sounds) for anything that fits
  GottaBounce's needs. Copy the chosen ones into the repo (e.g. `assets/sfx/`), don't reference the
  external path at runtime (it's outside the project).
- **For sounds not covered there: find CC0/online SFX packs or GENERATE them.**
- **Music already in-repo** (`assets/music/`: boss/campaign/gameplay_1-4/scoreboard mp3 + title.wav).
- **SFX events the game needs** (from the current build's EventBus + states): bounce (per-tier
  variation nice-to-have), normal-boost thrust, super-boost fire (the "goat scream" seed lives here
  if goats adopted), smash/impact (scaled by solidity), ring-out / off-screen death, damage-escalate
  (Lv1/Lv2), heal, powerup pickup + each powerup activate, countdown/BOUNCE!, first-blood / two-left /
  kill announcer, match-end/win, UI click. Wire via a new AudioManager + an SFX bus (there is
  currently NO Music/SFX bus architecture — master only; zero AudioStreamPlayers). Bus layout +
  AudioManager/MusicManager port were noted in the old reference plan.
