# Character-Theme Bible — THE CAST (creative identity, LOCKED)

> Authored by the Creative Director, 2026-07-05, at owner direction: the playable cast is a
> **goat/ram theme** and it is LOCKED here before the title screen and character-select are built
> (both are designed around the cast — see `docs/briefs/frontend_shell_visual_brief.md`).
>
> This is the creative core of the game. It feeds two consumers: the **Art role** (ChatGPT image-gen
> pipeline — see `assets/CATALOG.md` prompt pattern) and the **UI/UX + gameplay-programmer** building
> CharacterSelect / MainMenu (ROADMAP Phase 1). It does NOT design gameplay feel-deltas — those are
> flagged as Phase 2 and owned by the game-designer. Grounding: `docs/VISION.md` (Glossy Toybox),
> `docs/GAME_ESSENCE.md` (core verbs), `docs/feedback/owner_2026-07-02_movement_feel.md` ("crazy
> goats"), `docs/briefs/art_goat_identity_eval.md` (minimal-delta horn pass).

---

## 0. TL;DR (read this if you read nothing else)

- **Spine:** goat/ram is the RIGHT theme and it's a bullseye — the core verbs map onto horned ungulates
  1:1 (bounce = springy goat, fly = jetpack on the hooves, **smash = the headbutt**, recover = scramble
  back up the mountain). LOCK IT.
- **Tone:** cute + absurd + a dash of macho, all three at once. Adorable idiots with rockets who take a
  demolition-derby *deadly* seriously. Death is a punchline.
- **World:** the **Bounce** — a king-of-the-mountain rocket-headbutt tournament on the springiest peak
  in the world, **Mount Kaboing / Springhorn Peak**. The cast is **the Herd**.
- **Roster:** **6 marketed heroes** (matches the 6 bouncers already in the north-star art), extensible
  to 8 local players via 2 palette-recolor slots (Duck Game / TowerFall convention).
- **Mascot / face of the game:** **POGO** — the pink pygmy-goat kid. Icon + title hero. Paired on the
  title with **BUTCH** the blue ram as the co-star (bounce kid vs. smash bro = the whole game in one
  image).
- **Build constraint (inherited, non-negotiable):** keep the EXACT existing sphere-blob body, big eyes,
  tiny limbs, chunky jetpack. Horns are an **additive decoration pass**, not a new anatomy. Silhouette
  identity at close-up = horn shape; readability at gameplay zoom = still COLOR first (see §6 risk).

---

## 1. Concept & tone

**The marketer's paragraph:**

> High on the springiest peak in the world lives a herd of absurdly bouncy goats and rams who solved a
> simple problem — the good crags are *really* high up — by strapping surplus rocket-jetpacks to their
> hooves. Now they don't climb the mountain. They *launch* off it. Every ledge is a trampoline, every
> rival is a target, and the only rule of the great tournament called **the Bounce** is: last goat
> still flying is King of the Mountain. Aim your boost, tuck your horns, and headbutt your friends clean
> off the screen. **GottaBounce.**

**Tone — cute + absurd + macho, held in tension (this is the hook):**
- **Cute** is the skin: round jelly bodies, giant shiny eyes, tiny happy hooves, candy colors. You'd
  put any of them on a plushie shelf. This is the store-front, the approachability, the "aww."
- **Absurd** is the engine: goats do not have jetpacks; goats do not scream like *that*; nobody should
  be this happy about being launched into a spike. The comedy is that they are adorable and completely
  unhinged. (Pillar 3 "emergent physics comedy," Pillar 4 "death is cheap and funny.")
- **Macho** is the spice, and it's a JOKE macho: the rams flex, chest-butt, and strut like tiny
  wrestling heavyweights, but they're 40cm tall and squeak when they land. Think a goat kid doing a
  pro-wrestler entrance pose. The bravado is funny *because* they're cute.

The through-line: **"adorable idiots with rockets who take this WAY too seriously."** That single
sentence is the tone bible. Every taunt, face, and pose serves it. If a design choice makes them look
grim, edgy, or actually menacing, it's wrong — the danger is always played for laughs.

**Why goats/rams (why this is a bullseye, not just a theme):**
The verbs demanded a body and the goat *is* the body. Rams headbutt — that's literally the super-smash,
the kill, the thing the owner said the game lives or dies on. Goats are the most naturally springy,
scrambling, sure-footed-then-suddenly-airborne animal alive — that's the bounce and the recovery. The
horns are the readable "pointy end" the super-boost silhouette was missing (per the art eval: today's
blob mid-super reads as "a ball moving right," not "a creature charging horns-first"). And "a crew of
bouncy horned characters" is a *cohesive, ownable, marketable* cast the way Duck Game owns ducks — one
clear animal, infinite personality variations, trivially consistent to generate. It's the tightest
possible fit. Locked.

---

## 2. The roster — 6 heroes (+2 recolor slots for 8-player couch)

**Why 6 marketed heroes:** it's the Duck Game / TowerFall band (a cast you can name and love, not a
palette-swap soup), it exactly matches the **six bouncers already painted into the north-star art**
(pink/blue/green/yellow/purple/orange — the art has been telling us the roster size all along), and it
gives CharacterSelect a full, satisfying grid on day one. The engine supports up to 8 local players, so
**slots 7 & 8 are Duck-Game-style recolors** of existing heroes (a teal Pogo, a red Butch) — honest,
cheap, and genre-standard. We do NOT invent two thin characters just to hit 8.

**The whole family is different animals within the horned-ungulate genus** so every silhouette is
distinct across a living room even before you clock the color. Species chosen so no two horn-shapes
read alike.

### Color identity (the 4 existing colors are heroes 1–4, in order)

| # | Color | Hex | Character | Animal |
|---|---|---|---|---|
| P1 | Pink | `#FF5FA8` | **POGO** (mascot) | Pygmy goat (kid) |
| P2 | Blue | `#4AA8FF` | **BUTCH** | Bighorn ram |
| P3 | Green | `#54C94A` | **ZIGGY** | Alpine ibex |
| P4 | Yellow | `#FFC93F` | **PUFF** | Fluffy sheep (horned) |
| P5 | Purple | `#A15FFF` | **VEX** | Markhor (spiral horns) |
| P6 | Orange | `#FF7A2D` | **BILLY** | Old billy goat (bearded) |
| P7 | Teal | `#2FD0C0` | *(recolor: teal POGO or ZIGGY)* | — |
| P8 | Red | `#FF5A4A` | *(recolor: red BUTCH or VEX)* | — |

> Palette note to Art/UI: P1–P4 are frozen (they match `PartyMatch.PLAYER_COLORS` and the HUD/theme —
> see `frontend_shell_visual_brief.md` §0). P5 purple `#A15FFF` and P6 orange `#FF7A2D` are the new
> extensions — chosen to sit clearly apart from pink (P5 is bluer/darker) and yellow (P6 is redder), so
> six bodies never blur mid-storm. P7/P8 are recolor tints for overflow players only.

---

### P1 — POGO — pink pygmy goat — THE MASCOT

- **Attitude:** the eternal boundless optimist kid. Cannot stop boinging even standing still. Pure joy,
  zero self-preservation. If the game had a heart, it's Pogo. The "this is YOU, first-timer" default.
- **Silhouette hook:** the **smallest, roundest** body in the cast + two tiny **nub horns** (goat-kid
  buds, not grown yet) + the **biggest eyes**. Reads instantly as "the little one."
- **Face/energy:** permanent delighted open-mouth grin, huge sparkly eyes, ears up and eager.
- **Flavor → future feel-delta (Phase 2, do NOT build now):** the featherweight — lightest, springiest,
  fastest, highest bounce; lands soft, hits light. The mobility glass-cannon. Embodies the *bounce*
  verb over the *smash* verb (which is exactly why the mascot is a goat kid, not a ram).

### P2 — BUTCH — blue bighorn ram — THE CO-STAR

- **Attitude:** the cocky heavyweight headbutt bro. Struts, flexes tiny arms, does a wrestler entrance
  pose before every launch. All bravado, secretly a sweetheart. The face of the SMASH.
- **Silhouette hook:** **massive curled bighorn horns** wrapping the sides of the head — the biggest,
  most dominant horn shape in the cast. You see the curl from across the room. Slightly larger, more
  square-shouldered body.
- **Face/energy:** confident smirk, half-lidded "come at me" eyes, jaw set.
- **Flavor → future feel-delta (Phase 2):** the heavyweight — heaviest, slowest, biggest smash launch,
  best hit-solidity. The *smash* verb incarnate. Butch + Pogo are the two poles of the game (smash vs.
  bounce) and belong together on the title screen.

### P3 — ZIGGY — green alpine ibex — THE DAREDEVIL

- **Attitude:** the trick-shot show-off, all style points, always trying the fancy recovery. Skater/
  freestyle energy. Talks fast, aims fancier than necessary.
- **Silhouette hook:** long, **backswept scimitar horns** sweeping up-and-back over the body (opposite
  read from Butch's forward curl) + a slightly leaner, taller body. The "swept-back speed lines" shape.
- **Face/energy:** cocky grin, one eyebrow up, eyes on the horizon.
- **Flavor → future feel-delta (Phase 2):** the technician — best air control / glide, tightest steering
  mid-boost; rewards the *fly* verb and the recovery gamble.

### P4 — PUFF — yellow fluffy sheep — THE WILDCARD

- **Attitude:** the chaotic goofball comic-relief. No plan, ever. Screams with joy, wrong way half the
  time, somehow wins. The reason yellow = the "GOTTA" logo pop.
- **Silhouette hook:** the ONLY **bumpy cloud-fluff outline** in the cast (every other body is a smooth
  sphere) — a woolly popcorn silhouette with two tiny horns half-buried in the fluff. Distinct at any
  distance purely by outline texture, not just color.
- **Face/energy:** eyes-squeezed-shut open-mouth laugh (the north-star yellow bouncer's exact face).
- **Flavor → future feel-delta (Phase 2):** the floaty one — extra bounce/hang-time, slightly
  unpredictable drift; the wool absorbs and re-launches. Pure comedy physics.

### P5 — VEX — purple markhor — THE RIVAL

- **Attitude:** the theatrical smug antagonist — the "villain" you love to beat, all drama and flourish.
  Bows before matches. Not actually evil, just insufferably extra. (Kept cute — smug, never scary.)
- **Silhouette hook:** dramatic **corkscrew / twisted-spiral horns** rising straight up (the markhor's
  signature) — the most ornate horn shape, unmistakable. Sleek body, a little regal posture.
- **Face/energy:** raised chin, lidded confident eyes, a little fanged grin.
- **Flavor → future feel-delta (Phase 2):** wildcard/trickster — a horn shape that could later map to a
  sideways or spin-smash sweet spot (art eval note: shape can affect the super-smash sweet spot). Flag
  only.

### P6 — BILLY — orange old billy goat — THE VETERAN

- **Attitude:** the grizzled crusty grandpa who's won this a hundred times and won't shut up about it.
  Gruff, dry, and secretly the springiest of them all. "Back in MY day the mountain was TALLER."
- **Silhouette hook:** a **chin beard** (the only bearded goat) + short **forward-jutting straight
  horns**. Beard + forward-point = a completely different profile from the others; reads "old goat"
  instantly.
- **Face/energy:** bushy brows, squint, a knowing half-smile under the beard.
- **Flavor → future feel-delta (Phase 2):** all-rounder / "veteran-balanced" — the baseline everyone
  else deviates from. Good default for a player who wants no gimmick.

---

## 3. The mascot / hero of the game

**POGO** (pink pygmy goat) is the face of GottaBounce — store icon, app icon, title-screen hero,
key art, marketing.

**Why Pogo:**
1. **Pink is already the hero of everything shipped** — P1/default, the first sprite ever generated
   (`bouncer_pink_idle.png`), and the lead bouncer in the north-star art. Continuity, zero relearning.
2. **He literally IS the title** — "GottaBounce" is the bounce verb, and Pogo is the pure-bounce
   character. The word and the mascot are the same idea. (A ram would sell "smash"; the game is named
   for bounce.)
3. **Maximum approachability** — the smallest, cutest, biggest-eyed character is the right store icon
   for a party game selling "anyone can pick this up in 5 seconds." Low floor, on the box.

**But market Pogo + Butch together.** The single strongest key-art / title composition is the springy
pink kid mid-boing next to the cocky blue ram winding up a headbutt — **bounce meets smash in one
frame.** That pairing tells a stranger exactly what the game is. Pogo alone = the icon; Pogo + Butch =
the title screen and the store hero shot; the full six = the character-select and the box-back "meet the
Herd" lineup.

---

## 4. How the theme drives the front-end (note to UI/UX + Art)

Feeds directly into `docs/briefs/frontend_shell_visual_brief.md` — that brief built the shell with the
4 color-blobs as placeholders; this bible is what replaces them. Keep every stylebox/motion rule from
that brief; only the *content* (who's on screen) changes.

- **MainMenu (title):** the north-star grassy-sky backdrop with **Pogo and Butch** as the featured
  bobbers front-and-center (bounce kid + smash ram), the other four Herd members drifting/boinging in
  the parallax. The cast should be *doing the verbs* even here — someone always mid-boing, someone
  winding a headbutt, confetti, joy. Never a static lineup. This screen must say "adorable chaos" in one
  glance. (Logo, buttons, motion: unchanged from the shell brief.)
- **CharacterSelect:** the emotional payoff screen. A grid of 6 portrait cards, each = the bouncer on a
  cream card, card border painted THAT hero's color on selection, **name below** (Pogo / Butch / Ziggy /
  Puff / Vex / Billy) in the chunky font. The selected character should **come alive** — a taunt/idle
  loop (Pogo boings, Butch flexes, Puff wobble-laughs, Vex bows, Billy harrumphs) — this is where the
  personalities sell themselves and where "one more round, but as Butch this time" is born. Design for 4
  color-outlined pick-cursors landing on cards (couch multiplayer), per the shell brief. Recolor slots
  7/8 need not appear as cards in Phase 1.
- **Character-select mood:** loud, joyful, a little competitive — like the pre-match banter of a party
  game. The energy the shell brief demanded (nothing static, everything springy) is *carried by the
  cast here*, not by generic bobbers.
- **Art pipeline direction:** keep the proven ChatGPT pattern from `assets/CATALOG.md` — "attach the
  existing bouncer sprite, same character, same Glossy Toybox style, now [this animal's horns/beard/
  fluff]." Horns/beard render in **neutral warm bone** (`#F2E6D0`) with the same chocolate `#3B2419`
  outline and plastic-shine highlight as the jetpack — **do NOT tint horns per player color** (body =
  the color, horns = the neutral accessory, exactly as the jetpack is already neutral metallic-orange
  across all four). This preserves the 4/6-player color read. Per-character deliverable set follows the
  art eval's minimal-delta list (idle + squash + a horns-forward super-aim pose), now × 6 heroes.

---

## 5. Fantasy-fit verdict

**VERDICT: the cast DELIVERS and AMPLIFIES the core fantasy. Ship the theme; build with one guarded eye
on gameplay-zoom readability.**

**How it amplifies each core verb (`GAME_ESSENCE.md`):**
- **BOUNCE** — goats/springy-kid Pogo are the most on-nose bounce mascot possible; the word and the
  animal agree.
- **FLY / BOOST** — jetpacks on hooves is absurd enough to be funny and clear enough to read; unchanged
  from the shipped blob, so no risk to the validated flight feel.
- **SUPER-SMASH (the kill)** — **this is the biggest win.** Horns give the super-boost the readable
  "weapon tip" it lacked. The art eval proved today's blob mid-super reads only as "a ball moving
  right"; horns-first tuck reads as "a creature *charging you*." Both the aimer (sees the point of
  impact) and the victim (sees the thing about to hit) get a readability upgrade tied to the exact
  mechanic the owner said the game lives on. The ram/headbutt fantasy and the kill mechanic are the same
  thing.
- **RECOVER** — sure-footed-goat-scrambling-back-up-the-mountain is a perfect fiction for the recovery
  gamble; Ziggy the daredevil even makes it his personality.
- **Audio bonus (owner's seed):** the **goat scream on super-fire** is now fully motivated by the cast —
  cheap, hilarious, reversible, and it makes the kill move *sound* like the theme (queue it to the
  super-fire event; per the art eval it's a standalone audio ticket, no art dependency).
- **"One more round?"** — a named, personality-rich cast of 6 is a direct driver of it ("let me try as
  Vex"), which a set of 4 anonymous colored blobs was not.

**The ONE real risk (must be gated, not assumed away):** *readability at gameplay zoom.* At `grade_far`
zoom, bouncers are ~25–30px tall; the existing eyes+smile already sit near the legibility floor. Adding
six DIFFERENT horn shapes could turn "instantly distinguishable" into "six lumpy heads" — visual noise
without payoff — and wild horns (Butch's curl, Vex's spiral) can break the sphere-collider silhouette
the hitbox read depends on. **Mitigations, mandatory:**
1. **Color stays the primary in-motion identifier** (as it is today). Horn shape is the identity at
   character-select / portrait / close-up and the secondary cue in play — not the thing you must resolve
   at 25px to tell players apart.
2. Keep each horn within a modest bounding-capsule extension at the top of the head (don't flare so wide
   the body stops reading as "the same-size ball"). Simplify the wild horns for the in-game sprite;
   render them ornate only in portraits/key art.
3. **Inherit the art eval's ship gate:** before locking sprites, take a real in-engine screenshot at
   `grade_far`'s exact zoom with **all six on screen at once** and grade whether each is
   distinguishable and none reads as noise. If a horn washes out, thicken/simplify it. This is a
   hard gate, not a nicety — it's the exact class of miss (`GAME_ESSENCE`) this studio exists to catch.

**North-star check (movement is the product):** the theme is a *skin over the validated feel* — the
minimal-delta rule keeps the exact sphere body, collider, jetpack, and squash/stretch rig, so nothing
here touches the movement the owner cares about most. It cannot undercut the north star because it
changes zero physics. Phase-2 feel-deltas (light Pogo / heavy Butch) are flagged for the game-designer,
NOT designed here, and must be proven against the same fantasy-fit bar when they land.

**Bottom line:** goat/ram is the correct spine, the six-hero Herd is the right cast, Pogo is the right
face, and the theme makes the game *more* itself — as long as the gameplay-zoom horn-readability gate is
honored. LOCKED.
