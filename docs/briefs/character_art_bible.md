# Character Art Bible — turning the blobs into the Herd (VISUAL spec + gen prompts)

> Authored by the Art Director, 2026-07-05. Consumes `docs/briefs/character_theme_bible.md` (THE cast,
> LOCKED) and `assets/CATALOG.md` (proven bouncer prompt + intake workflow). Style bible:
> `docs/VISION.md` (Glossy Toybox). This doc is the definitive **look** and the **exact generation
> prompts** to convert the 6 generic glossy blobs into Pogo / Butch / Ziggy / Puff / Vex / Billy.
> It designs NO gameplay and touches NO code.

---

## 0. Hard constraints (inherited — violating any of these is a Reject)

These are lifted straight from the theme bible §0/§4/§6 and are non-negotiable:

1. **KEEP THE BLOB.** The sphere-blob body, big white eyes, huge smile, tiny stubby arms/feet, rosy
   cheeks, plastic shine, chocolate outline, and the chunky metallic-orange back jetpack with two
   rocket nozzles are the EXISTING, VALIDATED sprite. Horns/beard/fluff are an **ADDITIVE decoration
   pass on top of that exact character** — not a redraw, not new anatomy, not a new body shape, not a
   new collider. When in doubt, the generated sprite should look like the current bouncer wearing its
   species' horns.
2. **HORNS ARE NEUTRAL BONE — never per-color.** All horns/beard render in warm bone `#F2E6D0` (mid),
   the SAME chocolate `#3B2419` outline as the body, and the SAME soft plastic-shine highlight as the
   jetpack. Do NOT tint a character's horns toward its body color. Rationale: body = the player color,
   horns = the neutral accessory (exactly like the jetpack is neutral orange on all six). This is what
   keeps the 4/6-player color read alive. A pink-horned Pogo or blue-horned Butch = Reject.
3. **COLOR IS THE PRIMARY IN-MOTION IDENTIFIER.** Horn shape is the identity at select/portrait/close-up
   and a *secondary* cue in play. At ~25px gameplay zoom you must still tell players apart by color
   first. Therefore: **simplify the wild horns for the in-game IDLE sprite** — keep each horn inside a
   modest bounding-capsule extension above the head (roughly +30–40% of head height, not a wide flare),
   thick and chunky enough to survive downscale, never thin filigree. Ornate/dramatic horns live in
   portraits and key art only.
4. **Do not break the ball silhouette.** Horns must not flare so wide the body stops reading as
   "the same-size bouncing ball." The hitbox is a sphere; the sprite must keep looking like one.

**Shared body recipe (unchanged, every character inherits it):** glossy [COLOR] jelly ball, side view
facing right; two big white cartoon eyes with dark pupils + white shine dots; rosy cheek blush; tiny
stubby arms (front arm resting near the jetpack), two small stubby feet; a small ear nub at the back of
the head; chunky metallic-orange toy jetpack on the back (viewer's left) with two little rocket nozzles;
thick dark-chocolate outline `#3B2419`; soft plastic-toy shine highlights.

---

## 1. Per-character visual spec (all 6 — additive layer only)

Colors are frozen from the theme bible §2. Horn/beard = bone `#F2E6D0`. Each entry = the ONE horn shape,
the face/energy delta, and the single silhouette hook that makes it read across a living room.

### P1 — POGO — pink `#FF5FA8` — pygmy-goat KID / MASCOT
- **Horn:** two tiny **nub horns** (goat-kid buds, ~1/4 the size of any adult horn) — little bone
  bumps on top of the head, barely more than dots. Deliberately the *least* horn in the cast.
- **Silhouette hook:** the **smallest, roundest** body + the **biggest eyes** + nub horns = "the little
  one." He should look a touch smaller/rounder than the others even at a glance.
- **Face/energy:** permanent delighted open-mouth grin, huge sparkly eyes, ears up and eager. This is
  the current pink bouncer's face — keep it exactly, just add the two nubs.
- **Flourish:** the most bounce-forward posture; if anything, lean the idle slightly more "up on the
  toes / mid-boing" than the others.

### P2 — BUTCH — blue `#4AA8FF` — bighorn ram / CO-STAR
- **Horn:** **massive curled bighorn horns** — thick bone rams-horns curling down and forward around
  the SIDES of the head (the classic full-curl). The biggest, most dominant horn shape in the cast; the
  one you clock from across the room. **In-game simplify:** keep the curl bold and chunky but tuck it
  close to the head so it stays inside the head-capsule and doesn't spear out past the ball silhouette.
- **Silhouette hook:** the side-wrapping curl + a slightly **larger, more square-shouldered** body.
- **Face/energy:** confident smirk, half-lidded "come at me" eyes, jaw set. Still cute — a smug baby,
  not a menace.
- **Flourish:** tiny flexed front arm (mini wrestler). The macho joke.

### P3 — ZIGGY — green `#54C94A` — alpine ibex / DAREDEVIL
- **Horn:** long **backswept scimitar horns** sweeping UP-and-BACK over the body (the exact opposite
  read from Butch's forward curl) — think "speed lines." Ridged/segmented front edge if it survives
  downscale; otherwise smooth. **In-game simplify:** two clean backswept curves, ridges only hinted.
- **Silhouette hook:** the swept-back horns + a slightly **leaner, taller** body posture. Reads as motion
  even when standing still.
- **Face/energy:** cocky grin, one eyebrow up, eyes on the horizon.
- **Flourish:** the "about to try something dumb and cool" lean.

### P4 — PUFF — yellow `#FFC93F` — fluffy horned sheep / WILDCARD
- **Horn:** two tiny horns **half-buried in wool** — barely-visible bone tips peeking out of the fluff.
  Puff's identity is the WOOL, not the horns.
- **Silhouette hook:** the ONLY **bumpy cloud-fluff outline** in the cast — a woolly popcorn/scalloped
  silhouette instead of a smooth sphere. Distinct at ANY distance by outline texture alone. Keep the
  overall bounding size the same ball (fluff is a rim texture on the sphere, not a bigger body).
- **Face/energy:** eyes-squeezed-shut open-mouth laugh — the current yellow bouncer's exact face. Keep it.
- **Flourish:** the wool is the flourish. Front tuft, cheek fluff, a little woolly forelock.

### P5 — VEX — purple `#A15FFF` — markhor / RIVAL (the villain you love to beat)
- **Horn:** dramatic **corkscrew / twisted-spiral horns** rising straight UP (the markhor signature) —
  the most ornate shape in the cast. **In-game simplify HARD:** two bold upward twists, low twist-count
  (2–3 turns max), thick bone so the spiral doesn't turn to mush at 25px. Save the full ornate spiral
  for the portrait.
- **Silhouette hook:** twin vertical spirals + a **sleek, slightly regal** upright posture.
- **Face/energy:** raised chin, lidded confident eyes, a little fanged grin. Smug, theatrical, NEVER
  scary — a diva, not a demon.
- **Flourish:** chin-up "bow before me" tilt.

### P6 — BILLY — orange `#FF7A2D` — old billy goat / VETERAN
- **Horn:** short **forward-jutting straight horns** (stubby, pointing forward) — plus the cast's ONLY
  **chin beard** (bone-colored, same `#F2E6D0`, a tidy little goatee under the chin).
- **Silhouette hook:** beard + forward-point = a completely different profile — reads "old goat"
  instantly, even in shadow. The beard is the strongest single silhouette tell in the cast.
- **Face/energy:** bushy brows, a squint, a knowing half-smile under the beard. Grizzled but warm.
- **Flourish:** the beard. Give it a slight downward hang so it reads as a beard, not a chin.

**Distinctness map (why no two blur):** Pogo = nub/tiny · Butch = side curl/forward · Ziggy = up-back
sweep · Puff = fluff outline (no smooth ball) · Vex = vertical spiral · Billy = forward stubs + beard.
Three axes vary at once — horn direction, horn size, and (Puff/Billy) an outline/beard tell — so the
cast separates by shape even before color.

---

## 2. PASS #1 — the 6 IDLE generation prompts (generate these FIRST)

Voice matches the CATALOG bouncer pattern. **Workflow for consistency: attach the matching existing
`bouncer_{color}_idle.png` and say "same exact character, same Glossy Toybox style, keep the body, eyes,
smile, arms, feet and metallic-orange jetpack EXACTLY — only ADD [this species' horns/beard/fluff]."**
Append the base style suffix (below) to every prompt.

**Base style suffix (append verbatim to all 6):**
> *"Style: high-quality glossy cartoon game art, thick clean dark-chocolate outlines, vibrant saturated
> colors, soft plastic-toy shine highlights. The horns/beard are neutral warm BONE color (#F2E6D0) with
> the same chocolate outline and plastic shine as the jetpack — NOT tinted to the body color. IMPORTANT:
> fully transparent background (alpha PNG) — no sky, no ground, no shadow, just the single subject
> centered with empty space around it. Square image."*

---

**POGO (pink) — idle:**
> Cute round glossy PINK blob goat-kid, side view facing right, happy idle standing pose. Glossy pink
> jelly ball body with two big white cartoon eyes, huge open happy smile, rosy cheeks, tiny stubby arms,
> two small stubby feet, and a chunky metallic-orange toy JETPACK strapped to its back with two little
> rocket nozzles. ADD: two tiny little BONE-colored baby nub horns on top of the head (a baby goat kid's
> horn buds — small bumps, not grown yet). He is the smallest, roundest, biggest-eyed one — pure joyful
> bouncy baby energy.

**BUTCH (blue) — idle:**
> Cute round glossy BLUE blob ram, side view facing right, cocky idle standing pose. Glossy blue jelly
> ball body with two big white cartoon eyes (confident half-lidded smirk look), open smile, rosy cheeks,
> tiny stubby arms with the front arm slightly flexed, two small stubby feet, and a chunky metallic-orange
> toy JETPACK strapped to its back with two little rocket nozzles. ADD: big thick BONE-colored curled
> BIGHORN ram horns curling down and forward around the sides of the head (the classic full-curl), bold
> and chunky, tucked close to the head. Slightly bigger, square-shouldered body. A smug cute wrestler baby.

**ZIGGY (green) — idle:**
> Cute round glossy GREEN blob ibex, side view facing right, cocky show-off idle pose leaning slightly
> forward. Glossy green jelly ball body with two big white cartoon eyes (one eyebrow raised), open grin,
> rosy cheeks, tiny stubby arms, two small stubby feet, and a chunky metallic-orange toy JETPACK strapped
> to its back with two little rocket nozzles. ADD: two long BONE-colored BACKSWEPT scimitar horns sweeping
> up and back over the body like speed lines. Slightly leaner, taller posture. A stylish daredevil.

**PUFF (yellow) — idle:**
> Cute round glossy YELLOW blob sheep, side view facing right, joyful idle pose. Glossy yellow body with
> two big white cartoon eyes squeezed shut in a happy open-mouth laugh, rosy cheeks, tiny stubby arms,
> two small stubby feet, and a chunky metallic-orange toy JETPACK strapped to its back with two little
> rocket nozzles. CHANGE THE OUTLINE ONLY: the body silhouette is a bumpy, woolly, cloud-fluff popcorn
> outline (scalloped soft wool) instead of a smooth ball — keep it the same overall size. ADD: two tiny
> BONE-colored horn tips half-buried in the wool, and a little woolly forelock. A chaotic goofy wildcard.

**VEX (purple) — idle:**
> Cute round glossy PURPLE blob markhor, side view facing right, smug theatrical idle pose with chin
> raised. Glossy purple jelly ball body with two big white cartoon eyes (lidded confident look), a little
> fanged grin, rosy cheeks, tiny stubby arms, two small stubby feet, and a chunky metallic-orange toy
> JETPACK strapped to its back with two little rocket nozzles. ADD: two dramatic BONE-colored twisted
> CORKSCREW SPIRAL horns rising straight up from the head (markhor spiral, 2 to 3 bold twists, thick).
> Sleek regal posture. A cute smug diva rival — theatrical, never scary.

**BILLY (orange) — idle:**
> Cute round glossy ORANGE blob old billy goat, side view facing right, grizzled idle pose. Glossy orange
> jelly ball body with two big white cartoon eyes (bushy brows, a squint, a knowing half-smile), rosy
> cheeks, tiny stubby arms, two small stubby feet, and a chunky metallic-orange toy JETPACK strapped to
> its back with two little rocket nozzles. ADD: short BONE-colored forward-jutting straight horns, and a
> tidy BONE-colored chin BEARD (goatee) hanging under the chin. A crusty old veteran goat, gruff but warm.

---

## 3. PASS #2 — follow-up poses (generate AFTER the 6 idles are graded & shipped)

For each pose: attach that hero's just-shipped IDLE and ask for "the same exact character, same style,
now [pose]." Two poses × 6 heroes. **Priority: the horns-forward CHARGE pose** — the theme bible §5
calls out that the current blob reads poorly mid-super ("a ball moving right"), and horns-first is the
single highest-value new frame because it upgrades the readability of the kill move the game lives on.

**2a. SQUASH / LANDING (compression frame)** — one per hero:
> "The same exact [NAME] character, same Glossy Toybox style, same bone-colored horns, same jetpack — now
> a SQUASH landing pose: the body squished wide and flat (compressed on impact), feet splayed, eyes wide,
> horns still clearly reading. Transparent background, square." (Mirror `bouncer_pink_squash.png` proportions.)

**2b. HORNS-FORWARD SUPER-CHARGE / AIM (HIGH VALUE)** — one per hero:
> "The same exact [NAME] character, same Glossy Toybox style, same jetpack — now a CHARGING super-boost
> pose: body tucked and leaning hard forward to the right, HORNS DOWN and pointed FORWARD like a charging
> headbutt (the horns are the leading weapon tip of the silhouette), a determined/gleeful battle face,
> jetpack flames implied behind. The pose should read as 'a creature charging horns-first at you,' not
> 'a ball moving right.' Transparent background, square."
> - Per-hero note: Butch's charge = the hero shot of this pose (he's the smash co-star — make his the
>   most iconic). Pogo's is lighter/springier; Ziggy's is a stylish dive; Vex's is theatrical; Billy's
>   is a gruff bull-rush; Puff's is a chaotic wool-cannonball.

Lower priority later: taunt/idle-loop frames for CharacterSelect (Pogo boing, Butch flex, Puff
wobble-laugh, Vex bow, Billy harrumph) — nice-to-have for the "selected character comes alive" moment;
brief separately when the select screen is built.

---

## 4. Title & character-select needs (Pogo + Butch beauty poses)

Per theme bible §3/§4 the strongest key art is **Pogo mid-boing next to Butch winding up a headbutt**
— bounce meets smash in one frame.

- **Design the select screen to CROP THE IDLE by default.** The 6 idle sprites (§2) are the day-one
  source of the CharacterSelect portrait cards — a centered head-and-shoulders crop of the idle on a
  cream card, card border painted that hero's color on selection, name below in the chunky font. No
  dedicated portrait is *required* to ship the select grid. This is the gate: idles must crop well.
  (Compose each idle with the head high enough that a square top-crop gets eyes + full horns.)
- **Portrait "beauty pose" (nice-to-have, later) — Pogo & Butch first.** Two optional dedicated
  three-quarter-front hero portraits with the ORNATE (un-simplified) horns for title key art and premium
  select cards:
  - **Pogo beauty:** three-quarter front, mid-boing, arms up, maximum sparkly-eyed joy — the store/app
    icon and title hero.
  - **Butch beauty:** three-quarter front, wrestler entrance flex, full ornate side-curl bighorns — the
    title co-star, paired with Pogo.
  - Prompt frame: "Hero portrait of [NAME], three-quarter front view, Glossy Toybox style, ornate full
    detailed bone horns, dynamic [boing/flex] pose, big personality, transparent background, square."
  - These are the ONE place the horn-simplification rule relaxes (portrait/key-art only, never the
    in-game sprite).

---

## 5. Intake + naming

### Recommended filename scheme: KEEP the color-slot names
Recommendation: **keep `bouncer_{color}_idle.png` as the in-game load path** and treat the character
name as metadata, not the filename. Reasons:
- P1–P4 slot names (`bouncer_pink/blue/green/yellow_idle.png`) are the frozen contract that matches
  `PartyMatch.PLAYER_COLORS` and the HUD/theme (theme bible §2). Renaming files = code churn in a system
  the Art role does not own and the bible froze. Color is the load key; the character is the skin.
- The new heroes just fill the two remaining color slots:
  - Pogo → `bouncer_pink_idle.png` (overwrite existing)
  - Butch → `bouncer_blue_idle.png` (overwrite)
  - Ziggy → `bouncer_green_idle.png` (overwrite)
  - Puff → `bouncer_yellow_idle.png` (overwrite)
  - Vex → **`bouncer_purple_idle.png`** (new — P5)
  - Billy → **`bouncer_orange_idle.png`** (new — P6)
- Pose variants follow the existing convention: `bouncer_{color}_squash.png`, `bouncer_{color}_charge.png`.
- Optional beauty portraits (do NOT reuse the load slot): `portrait_pogo.png`, `portrait_butch.png`.

(If the team later wants human-readable asset names, add name→color aliases in CATALOG rather than
renaming the load path. Flagged, not recommended for this pass.)

### CATALOG update (when sprites land)
Add character name + species + horn shape to each `bouncer_{color}_idle` row (e.g. "Pogo — pink pygmy
goat, nub horns"), add the two new `purple`/`orange` rows, and record each final prompt in this file's
git history per the CATALOG convention ("prompts are the source code of the art").

### art.py intake steps (per sprite)
```
python tools/art.py trim  <downloaded.png>  assets/characters/bouncer_<color>_idle.png
python tools/art.py check  assets/characters/bouncer_<color>_idle.png
# if check reports missing/fake alpha (baked checkerboard or solid bg):
python tools/art.py keyout <downloaded.png> assets/characters/bouncer_<color>_idle.png --tol 40
python tools/art.py check  assets/characters/bouncer_<color>_idle.png
```
Verify the Downloads timestamp BEFORE intake (CATALOG gotcha: a missed viewer click silently reuses the
previous download). Target ~750px like the existing idles; `art.py info` to confirm size/alpha coverage.

---

## 6. Grading rubric (what I check when you bring the sprites back)

I grade FROM IN-GAME SCREENSHOTS, not asset files alone (per my mandate + PIPELINE loop). Bring me: the
6 trimmed idles AND an in-engine screenshot with **all six on screen at `grade_far` zoom**
(`python tools/gbplay.py screenshot`). Verdict per sprite = Ship / Fix (numbered) / Reject.

1. **Style coherence** — does it look like the SAME character wearing horns? Same glossy jelly body,
   same eyes/smile, same chocolate outline weight, same plastic shine, same untouched orange jetpack. A
   redrawn body, a different render style, or a mangled jetpack = Reject (constraint §0.1).
2. **The bone-horn rule (hard pass/fail)** — horns/beard are bone `#F2E6D0`, NOT tinted to body color.
   Any color-tinted horn = automatic Fix/Reject; it breaks the player-color read.
3. **Silhouette distinctness (close-up)** — with color removed (I'll desaturate a copy), can I still
   name each hero by horn/beard/outline shape? Pogo nub, Butch curl, Ziggy sweep, Puff fluff, Vex
   spiral, Billy beard+stub must each be unmistakable.
4. **Gameplay-zoom readability gate (the hard gate, theme bible §6.3)** — in the all-six ~25px
   screenshot: (a) can I still tell players apart by COLOR at a glance while tracking 4 at once?
   (b) does any horn wash into mush or read as visual noise? (c) does any horn flare break the
   ball/hitbox silhouette? Any "yes" to b/c = Fix (thicken/simplify that horn). This gate must pass
   before any idle is locked — it is the exact class of miss this studio exists to catch.
5. **Polish** — clean alpha (no seam halo, no baked bg, no checkerboard), trimmed, no stretching, no
   debug shapes, shine highlights intact, outline unbroken.

**Ship** = all five pass. **Fix** = numbered, specific horn/color/crop corrections. **Reject** = body
redrawn, wrong style, or horns tinted per-color (restate: additive bone-horn pass on the EXACT blob).
