# Art brief: painted court cards (WK-65, + UX4-12 RANDOM ROTATION card, + WK-98 SP-17 Dropshot mode card)

Date 2026-11-15 · Author: art-director · Backlog WK-65 [P2][M] (merged: R-15 cards half, WK-98 §4 / SP-17, WK-CD3 CD3-09, UX4-12 art half)
Layout it serves: WK-60b preview + shelf (commit 614f456, `src/ui/ArenaSelect.gd`, `scenes/ui/ArenaSelect.tscn`)
Nets it must agree with: `docs/briefs/sports_nets_2026-11-15.md` (D1 volleyball set, G1 goal cage)

The art pipeline generates these exactly as written. The programmer makes the small wiring changes in section 7. I grade the result
from in-game screenshots only, using the tests in section 8. **One generation session: 14 images** (1 frame + 11 court interiors + 1
RANDOM crest + 1 Dropshot mode card).

## 0. What is on screen now (graded from the WK-60 screenshots)

| Screen | What a newcomer sees | Verdict |
|---|---|---|
| Rocketball court select (`tools/out/wk/WK-60_22_rb_end.png`) | Every court previews as the **same** hero: the Rocketball mode painting (Billy and the gold-band ball) with a dark stadium map inset in its corner. All 8 shelf cards are the same near-black stadium rectangle. Only a few 10 px hazard sprites differ. At 480 px the eight courts can't be told apart. | Reject-level for a select screen |
| Dropshot court select (`WK-60_30_ds_entry.png`) | Same pattern. The hero is the Dropshot mode painting, which shows a **soccer goal cage**. The three cards are identical dark rectangles with a hairline net. | Same, plus a wrong-sport hero |
| Brawl circuit select (`WK-60_10_pad_brawl_entry.png`) | **The bar.** A painted gold-shield crest sits on warm rays. Every card has its own hue and emblem. You can tell the circuits apart at a glance. | Target quality |

The fix: one painted badge per court. Each is a different colour world with the court's real signature feature front and centre, and
all of them sit in one shared frame that says SPORTS the way the gold shield says CIRCUIT.

## 1. Decisions

1. **One file per court serves both uses.** The code already shows art two ways:
   - the shelf card uses `STRETCH_KEEP_ASPECT_COVERED` (a centre crop to about 2.2:1);
   - the preview uses `KEEP_ASPECT_CENTERED` in a 604x320 frame.

   The badge canvas (section 2) is laid out so the card's cover crop lands almost exactly on the painted interior plus the red and blue
   side rims, and the preview shows the whole badge. **Two outputs, one file, no second crop to maintain.**
2. **Composite pipeline, not 11 whole-badge generations.** The frame is generated **once** (F1). The 11 court interiors are generated as
   full-bleed opaque landscape paintings (I1-I11), and an offline script composites them (section 6). Why:
   - frame drift across 11 separate generations is the number-one family risk, and compositing makes the frames pixel-identical;
   - interiors need no keying at all;
   - a re-roll costs one interior, not a whole badge.
3. **The frame shape is a "toy stadium screen".** It is a chunky 16:9 rounded rectangle:
   - the **left half of the rim is team RED and the right half is team BLUE**, which is the sports read and the same layout as the goals in
     every match;
   - a gold inner bezel and gold rivets give it kinship with the gold-shield crests;
   - two little floodlight pylons sit on the top corners;
   - a gold socket at top centre holds the **real in-game ball sprite**, composited in: `objects/ball.png` for Rocketball and
     `objects/ball_beach.png` for Dropshot. That is the per-sport tag, and it costs no generations.
4. **The interior is a toy diorama of the court, true to its mechanics and free in its setting.**
   - The layout signature must match the JSON: hazard type and position, net or goals, floor shape and court proportions. Hazard courts
     attach the **actual in-game hazard sprite** (`assets/hazards/hammer.png`, `bomb.png`, `crusher.png`), so the thing on the card is
     the thing you will dodge.
   - The setting (crate, beach, reef, dome, scrap yard) is per-court flavour that gives each court its own colour identity, like the
     Brawl crests. Note for WK-66: these interiors become the **art target** for future per-court theming (today every court renders the
     same dark stadium interior).
   - **No goats** in court interiors (they compete with the signature and invite style bleed). **No text** anywhere.
5. **RANDOM ROTATION is Brawl-only.**
   - The sports select has **no** random card: `_build_sports` lists courts only, and `rotate_sets` (`calm_ladder`, `chaos_night`) in
     `levels/sports_courts.json` are not surfaced in UI. No court-family random art is made.
   - The card UX4-12 asks for is the **Brawl** RANDOM ROTATION card, which today is a rainbow plate plus a spinning "?". It lives on the
     crest shelf, so it is made in the **gold-shield crest family** (R1), not the court family.
6. **The Dropshot mode card is regenerated, not edited.**
   - The current art has the wrong object (a soccer goal) **and** an off-roster teal goat (there is no teal Bouncer).
   - An edit that swaps a cage for a net changes the composition, and ChatGPT edits drift on that.
   - The regeneration (M1) uses **VEX** (purple markhor), who no other mode card uses, and the D1 net look.
7. **Files:**
   - courts go to a new folder, `assets/ui/courts/court_<id>.png`. Do **not** overwrite `assets/ui/thumbs/court_*.png`: those are
     ThumbBaker outputs, and a re-bake would clobber painted art;
   - RANDOM goes to `assets/ui/circuits/crest_random.png`;
   - the mode card replaces `assets/ui/modes/mode_dropshot.png`. Keep the old one as `tools/out/court_cards/mode_dropshot_v1_goal.png`.

## 2. Layout sketch: the badge canvas (final PNG 1280x800, real alpha)

```
 y=8    .  [lamps]                ( O )                [lamps]  .     <- floodlight pylons + ball socket poke above the rim
 y=58   .-==RED RIM======================*====BLUE RIM===========-.  <- rim outer edge (rounded rect 1216x684, r~110)
        | .--gold bezel-----------------------------------------. |
 y=104  | |                                                     | |  <- HOLE top (interior painting starts)
        |R|  [TIER chip]                         [LOCKED sash]  |B|     card corners: keep plain background here
        |E|                                                     |L|
        |D|   goal(red)       SIGNATURE FEATURE      goal(blue) |U|  <- signature centred, >= 40% of hole height
        | |                (hammer/net/bowl/...)                |E|
        | |                                                     | |
 y=696  | '-----------------------------------------------------' |  <- HOLE bottom (hole ~1124x592, ~1.90:1, inner r~64)
 y=742  '-==RED===========================*=================BLUE==-'
 y=800                  (transparent padding, mirrors the top)
        x=32                                                 x=1248
```

- **Rim:** a uniform ~46 px thick (about 7% of the rect height). Red and blue meet at top centre (under the ball socket) and bottom centre
  (under a small gold cap).
- **The rect is centred on the canvas** (centre y=400), so the card's centred cover crop is symmetric. The ornaments use the top padding,
  and the bottom padding stays empty.
- **What each use shows (measured on the WK-60b layout, 1920x1080):**

| Use | Node / mode | What shows | Screen size |
|---|---|---|---|
| **Shelf card** (400x300 card, art slot about 366x165) | `MenuCard` Plate/Art, COVERED | Canvas y≈111..689: the interior (minus ~7 px top and bottom) plus **thin red (left) and blue (right) rim strips**. Ornaments are cut. | interior about 322x150 |
| **Preview** (ArtFrame 640x356, Art 604x320) | `$Preview/Row/ArtFrame/Art`, KEEP_ASPECT_CENTERED | The **whole badge**, with the ball socket, pylons and full rim, over the tier-colour gradient and the slow rays | badge 512x320, interior about 448x235 |
| 480 px squint (screen ÷4) | n/a | preview interior about 112x59, card interior about 80x37 | the signature must read as one coloured silhouette |

- **Card overlays you must keep clear of** (they sit on the art):
  - the TIER chip at the card's top-left, about 120x45 screen px = the **top-left ~22% x 28%** of the card crop;
  - the LOCKED sash across the **top-right corner**, about a 170x170 px diagonal.

  Interiors keep both upper corners as plain background.

## 3. Palette

### 3a. Frame (all 11 courts, identical)

| Part | Hex |
|---|---|
| Outline | `#3B241B` (house chocolate, thick) |
| Rim left half | team red `#FF4B6A`, underside `#C8324F`, gloss `#FFFFFF` |
| Rim right half | team blue `#3FA9FF`, underside `#2477C8`, gloss `#FFFFFF` |
| Bezel line, rivets, socket ring, bottom cap | warm gold `#F5B82E` → `#C98A12`, gloss `#FFF4C2`. Warm orange-gold, **not lemon**. |
| Floodlight lamps | cream `#FFF6D8` lamps on a gold stalk |

These are the same team red and blue as the WK-66a goal tint, so the frame agrees with the goals in every match. Reserved-colour check:
no magenta `#FF4FA3` family, no safety orange, no blue+yellow pair as a team signal.

### 3b. Per-court identity (no two shelf neighbours share hue family **and** value band)

Shelf order is the `sports_courts.json` order. Value runs **calm = light, chaos = dark**, which matches the tier ramp.

| # | Court | Dominant hue | Value | Background hexes (top → horizon) | Signature colour | Silhouette at squint |
|---|---|---|---|---|---|---|
| 1 | CENTER PITCH | royal blue + emerald | mid | `#1F6EA8` → `#5FB4F0` | emerald floor `#2FBF5A`, white centre spot | symmetric "o · O · o": ball dead centre, two mirrored pucks |
| 2 | THE BOX | kraft tan + cream | light | `#FFF1C9` warm light inside the box | kraft walls `#D9A86C`, lime floor | small square room, white zig-zag |
| 3 | LONG HAUL | sky blue + lime | light | `#3FA9F5` → `#BFE9FF` | lime stripes `#9BE34A` / `#7CC63A` | one huge white arc over a long thin pitch |
| 4 | THE BOWL | apricot + mint | light | `#FFB38A` → `#FFE2B8` | mint bowl `#5FE3B0` | a big U across the width |
| 5 | HAMMER YARD | rust orange + charcoal | dark | `#2A2320` → `#4A3B30` | rust walls `#8A4A2A`, beacons `#FF8A2A` | pendulum "T" with a swoosh arc |
| 6 | MINEFIELD | olive khaki + black | mid-dark | `#4A4A34` → `#8C8A5A` | black bombs with red lights `#FF3B30` | a row of black dots, one bursting |
| 7 | THE CRUSHER | charcoal + hazard yellow | dark | `#241D1A` → `#443029` | yellow/black stripes `#FFC81E`, steel | "> <": two blocks meeting at centre |
| 8 | THE SCRAPHEAP | ember red + orange | dark-mid | `#5A1E14` → `#E0502E` | orange/yellow blasts `#FF9A2A` / `#FFE14A` | a triangle mound with bursts |
| 9 | SUNSET BEACH | sunset gold-orange | light | `#1D6FAE` → `#FF9A4A` → `#FFCA7A` | sand `#F2D29B`, white net, sun disk | white net "Π" with the sun behind it |
| 10 | CORAL COVE | turquoise + coral | light | `#0E7C8C` → `#8FF0DC` | coral `#FF7F50` / yellow, pale sand `#F4E3B5` | white net over a long tile row, coral at the sides |
| 11 | THE DOME | deep indigo + cyan | dark | `#232A52` → `#4C5F96` | gap glow `#7FF6FF`, tiles `#C9D6F2` | dome arcs, net lifted over a cyan slot |

Contrast rule for the dark courts (5, 7, 8, 11): the signature object is the **brightest thing in the frame** (L* ≥ 70 on a background
of L* ≤ 35). "Dark" means a coloured night, never the old black stadium. Mean interior L* must be ≥ 30 for all 11.

## 4. Readability requirements

- **Signature first.** The signature object is ≥ 40% of the hole height (about 60 px on the card, 94 px in the preview, 15 px and 23 px at
  480 squint). It sits in the central 80% x 80% of the interior.
- **Rocketball always shows both goals** (red left, blue right) at mid-height of the side walls. **Dropshot always shows the net dead
  centre** (D1 look: white posts with big knobs, a fat white top tape and diamond mesh) and a sand/tile floor. That is the sport read
  at a glance, and it agrees with the in-match nets.
- **The ball is the real one.** Rocketball uses the white sphere with a gold band (`objects/ball.png`), **never a black-and-white soccer
  ball**. Dropshot uses the red/white/blue/yellow beach ball (`objects/ball_beach.png`).
- **One focal point per court.** At most 3 secondary props. No crowd faces, no scoreboards, no banners. A thumbnail at 120 px must
  still read.
- **No text, letters, numbers, logos or scoreboard digits** in any image. The name, tier and blurb are live UI text.

## 5. Generation session (ChatGPT in Chrome, clipboard Ctrl+V attachments)

Use the technique in memory `gottabounce-chatgpt-image-paste`:
- STA clipboard paste; zoom-verify every attachment thumbnail before sending (the clipboard race happened 2 times in 8);
- download from the image viewer;
- check the Downloads timestamp or hash before intake.

Raws go to `tools/out/court_cards/raw/`.

| Chat | Images | Attach once at the start of the chat |
|---|---|---|
| A: frame | F1 | `assets/reference/style_north_star.png`, `assets/ui/circuits/crest_meadow_mile.png` (gold and finish only) |
| B: interiors | I1 → I11, in this order | `style_north_star.png` + per-prompt attachments listed below |
| C: Brawl and mode | R1, then M1 | per prompt |

**Budget: 14 images.** If a re-roll is needed, re-roll the failing interior and push **M1** to the next session (it ships separately per
SP-17). Re-roll rather than edit for interiors. Edits bake checkerboards and drift the camera.

### 5a. Shared clauses (paste verbatim where a prompt says so)

**[STYLE]**
> "Glossy Toybox style, matching the attached style reference: high-quality glossy cartoon game art, saturated high-contrast colour, soft
> painterly light, thick clean dark-chocolate (#3B241B) outlines on every object, plastic-toy shine highlights, chunky rounded toy
> shapes. Absolutely NO text, NO letters, NO numbers, NO logos, NO scoreboard digits anywhere. NO characters, NO goats, NO animals, NO
> people, NO crowd faces."

**[INTERIOR]**
> "Wide landscape painting that fills the ENTIRE image edge to edge: no border, no frame, no vignette, no rounded corners. A side-on view
> of a small toy sports court, camera at court height and tilted down slightly (about 15 degrees) so the floor reads as a surface, like
> looking into a toy diorama box. The court fills the full width, with walls at the left and right image edges. Everything important
> sits in the middle: the top 11% and bottom 11% of the image will be cropped, and the upper-left and upper-right corners must be plain
> background (labels go there). Bold simple shapes that still read as a tiny 120-pixel thumbnail. Same camera, scale, outline weight and
> lighting style as the previous court image in this chat."
> (Drop the last sentence on I1.)

**[ROCKETBALL]**
> "Rocketball court: chunky white studded bumper-post side walls and ceiling; a goal cage set into a gap at mid-height in each side wall.
> The LEFT goal has glossy RED (#FF4B6A) tubes and the RIGHT goal has glossy BLUE (#3FA9FF) tubes, both with white diamond rope net mesh,
> and both goals sit against the walls, never against the sky. The ball is the attached white sphere with a gold band (NOT a
> black-and-white soccer ball)."

**[DROPSHOT]**
> "Dropshot court: a toy VOLLEYBALL NET stands in the exact centre, tall and bright white, like the attached net frame: two slim glossy
> white posts topped with big round ball knobs, a fat padded white top tape, white diamond rope mesh between. White padded side walls.
> The floor is a row of chunky square floor tiles. The ball is the attached red/white/blue/yellow beach ball. NOT a soccer goal: no goal
> cages anywhere."

### 5b. Chat A: F1 frame `tools/out/court_cards/raw/frame_raw.png` → `assets/ui/courts/_frame.png`

Generate at **1536x1024** landscape.
> "A chunky toy STADIUM SCREEN FRAME for a game menu badge, seen perfectly straight-on, a landscape rounded rectangle in 16:9
> proportions, filling about 95% of the image width, centred. The frame is a thick glossy plastic rim of uniform thickness (about 7% of
> the frame's height) with big rounded corners. The LEFT half of the rim is glossy RED (#FF4B6A) and the RIGHT half is glossy BLUE
> (#3FA9FF); the two colours meet at the top centre and at the bottom centre, each join covered by a small rounded gold cap. A thin shiny
> warm-GOLD bezel line runs around the inner edge of the rim, and small gold rivets are evenly spaced along the rim. At the two top
> corners a small chunky toy FLOODLIGHT pylon (a little grid of round cream lamps on a short gold stalk, angled slightly inward) pokes up
> above the rim. At the top centre a round gold SOCKET RING (an empty circle, like a medal mount, about 20% of the frame height across)
> sits on the rim and pokes above it. The inside of the frame and the inside of the socket ring are completely EMPTY. Gold is warm
> orange-gold, not lemon yellow. Same gold finish and outline weight as the attached crest, but NOT a shield shape. [STYLE: first two
> sentences only] TRANSPARENT background, and the inside of the frame and the socket ring are transparent too. Nothing else in the image."

**Accept at intake:**
- the rim is the same thickness all round;
- red and blue split exactly at the vertical centreline;
- the socket ring is round and empty;
- the pylons are small (≤ 10% of the frame height above the rim);
- no shield shape, no text.

**Fallback** if the transparency comes back as a baked checkerboard: re-ask with "background, frame interior and socket interior are ONE
SOLID FLAT PURE GREEN #00FF00". Do **not** use `art.py keyout-color` on this frame: its chroma ramp turns the red rim translucent under a
magenta key and the gold translucent under a green key. Use the seeded flood in section 6 instead.

### 5c. Chat B: court interiors (each 1536x1024, opaque, no keying)

Each prompt is **[STYLE] + [INTERIOR] + [ROCKETBALL] or [DROPSHOT] + the court text below**. Attach the listed files to that prompt.

**I1 CENTER PITCH** (master; attach `objects/ball.png`, `world/sports/goal_frame.png` as the cage shape, tinted per the clause)
> "Court: CENTER PITCH, the classic. A full-width bouncy emerald-green trampoline floor (#2FBF5A) with a crisp white centre line and a
> round white centre spot. The ball hovers big and gleaming exactly at the centre just above the spot, with one small white sparkle. Two
> identical round glossy white-and-gold bumper pucks float high up, one at one-third and one at two-thirds of the width, perfectly
> mirrored at the same height. Behind: a royal-blue twilight sky (#1F6EA8 at the top to #5FB4F0 at the horizon) over a soft blurred toy
> stadium stand, with four warm-white floodlight starbursts along the top edge (not in the corners). Perfectly left-right symmetric.
> Calm, classic, clean. No hazards of any kind."

**I2 THE BOX** (attach `objects/ball.png`)
> "Court: THE BOX, small and tight. The whole court is built inside an open toy CARDBOARD BOX: kraft-tan cardboard walls (#D9A86C with
> darker fold lines and a strip of blue tape) close in on all sides so the court looks compact, nearly square, clearly smaller than the
> other courts; the box flaps fold open at the top, low-detail. A short lime-green trampoline floor. Two small round white bumper pucks at
> mid-height, mirrored. The ball is mid-ricochet with a bold white dashed ZIG-ZAG trail showing three bank shots, off the left wall, the
> ceiling and the right wall, with a small white impact star at each hit. The red and blue goal mouths are small and close together
> because the court is small. Warm sunny cream light (#FFF1C9) inside the box. NOT a wooden crate, no hazards."

**I3 LONG HAUL** (attach `objects/ball.png`)
> "Court: LONG HAUL, the long pitch with huge flights. A very LONG, low pitch stretching across the whole width, in gentle perspective so
> it feels far longer than a normal court: a lime trampoline floor with alternating mowing stripes (#9BE34A / #7CC63A). The red goal at
> the far left and the blue goal at the far right are small with distance and set high in the walls. The ball is at the peak of one HUGE
> high arc: a bold dotted white flight trail rises from near the left goal, peaks near the top centre and falls toward the right goal,
> with a little white puff where it was struck. Four small round bumper pucks at staggered heights: a high pair near the left and right
> thirds and a low pair near the centre. A huge open bright daytime sky with lots of headroom (#3FA9F5 at the top to #BFE9FF at the
> horizon) and two puffy white clouds. Light and airy. No hazards."

**I4 THE BOWL** (attach `objects/ball.png`)
> "Court: THE BOWL, the floor is a gentle bowl. The floor is a wide, shallow, glossy MINT-GREEN bowl (#5FE3B0 with white gloss): flat in
> the middle and rising in two soft rounded steps toward the left and right walls, a clear U shape across the whole width. The ball
> rests in the dip at dead centre. Two curved white arrow swooshes, one on each slope, sweep down toward the centre (the ball always
> rolls back to the middle). Two round white bumper pucks high up, mirrored. The goals sit at mid-height above the bowl's rim. A warm
> apricot evening sky (#FFB38A at the top to #FFE2B8 at the horizon). Soft and friendly. No hazards."

**I5 HAMMER YARD** (attach `hazards/hammer.png`, `objects/ball.png`)
> "Court: HAMMER YARD, a giant spinning hammer sweeps the middle. The signature, BIG and centred: the giant toy HAMMER from the attached
> image (steel head with yellow-and-black hazard stripes, wooden handle with a red tip) hangs from a chunky bolted pivot hub at the TOP
> CENTRE on a long steel arm, caught mid-swing, with one broad curved white motion-swoosh arc under its head showing it sweeping across
> the middle third of the court. It has just WHACKED the ball: a big white impact star where the head meets the ball, and the ball flying
> off with speed lines. A dark scrap-yard setting: rusty corrugated-iron walls (#8A4A2A), a smoky charcoal-brown sky (#2A2320 at the top
> to #4A3B30), two orange hazard beacons glowing (#FF8A2A), a grey trampoline floor with hazard-stripe edging. The hammer is the
> brightest, highest-contrast object in the image. Exactly ONE hammer: NO crossed hammers, no bombs, no crusher."

**I6 MINEFIELD** (attach `hazards/bomb.png`, `objects/ball.png`)
> "Court: MINEFIELD, landmines everywhere. The signature: the round black toy BOMBS from the attached image (glossy black sphere, rope
> fuse, spark) in a perfectly mirrored pattern. Five sit evenly spaced along the floor across the middle of the court and two hover a
> little higher, one each side, each with a small blinking red light ring. The bomb at dead centre has just gone POP: a chunky white and
> yellow cartoon blast puff launching the ball straight up with speed lines. An olive army-surplus setting: khaki-olive walls and sky
> (#4A4A34 at the top to #8C8A5A at the horizon), low sandbag stacks at both ends, a khaki trampoline floor. The bombs read as a clean
> row of black dots. No hammer, no crusher, no fire."

**I7 THE CRUSHER** (attach `hazards/crusher.png`, `objects/ball.png`)
> "Court: THE CRUSHER, a crusher snaps shut across the middle. The signature, BIG and centred at mid-height: TWO heavy steel crusher
> heads like the attached block (riveted steel with yellow-and-black hazard stripes) on horizontal guide rails, slamming INWARD from the
> left and the right toward the exact centre, with thick white speed lines behind them and a jagged white impact flash where they meet.
> The ball squirts straight UP out of the gap with a motion trail. A translucent red danger band marks the horizontal crush lane. A dark
> charcoal factory setting (#241D1A at the top to #443029), steel girders, a row of amber warning lamps, a grey trampoline floor. The
> crusher heads and their yellow stripes are the brightest objects. No hammer, no bombs."

**I8 THE SCRAPHEAP** (attach `objects/ball.png`; the hammer and bombs are already in this chat)
> "Court: THE SCRAPHEAP, hammer AND mines, pure chaos. The signature: a big triangular HEAP of toy junk in the middle (old tyres, coiled
> springs, gears, bent pipes) rising from the floor like a little mountain, reading as ONE triangle silhouette. The same striped HAMMER as
> the Hammer Yard image swings over the top of the heap from a pivot at the top centre, and two of the same black BOMBS as the Minefield
> image are exploding on the heap's slopes in big orange-and-yellow cartoon blasts (#FF9A2A / #FFE14A). The ball flies out of the chaos
> among scrap bits. A hot ember-red sky (#5A1E14 at the top to #E0502E at the horizon), dark iron walls. The red and blue goals stay
> clearly visible against the dark iron walls, not buried in junk. The busiest card, but one clear focal point. NO crusher, NO cannon,
> NO keys, NO wooden crates, NO black-and-white soccer ball."

**I9 SUNSET BEACH** (attach `objects/ball_beach.png`, `world/sports/net_dropshot_frame.png` as the net shape)
> "Court: SUNSET BEACH, the classic net court. The beach ball arcs high OVER the net from left to right with a dotted white trail. The
> floor is a row of ten chunky square SAND tiles (#F2D29B with #D9B475 seams); one tile on the right half is cracked. A huge low sunset
> sun sits on a strip of deep-blue sea on the horizon, directly behind the net. The sky runs from blue (#1D6FAE) at the very top through
> orange (#FF9A4A) to warm gold (#FFCA7A) at the horizon. One toy palm tree pokes up behind each side wall. The net stays bright white
> against the sunset. Warm and light."

**I10 CORAL COVE** (attach `objects/ball_beach.png`)
> "Court: CORAL COVE, the wide reef court. A WIDER, lower court than the beach one: the same white net in the centre, with a long row of
> twelve narrower pale-sand tiles (#F4E3B5), a tiny starfish on one. The beach ball floats mid-court on the left with a dotted arc toward
> the net. A shallow turquoise lagoon cove setting: clear turquoise water and sky (#0E7C8C at the top to #8FF0DC at the horizon), a
> natural rock arch at the back, big glossy coral branches in coral-orange (#FF7F50) and sunny yellow growing up behind both side walls.
> Cool and bright. NO sunset, NO sun disk, NO palm trees, not underwater."

**I11 THE DOME** (attach `objects/ball_beach.png`)
> "Court: THE DOME, tight and fast, and the net MOVES. An indoor court under a big glass geodesic DOME roof: curved white struts over a
> deep indigo night (#232A52 at the top to #4C5F96), a few stars through the glass, a ring of cool spotlights. The court is narrower, with
> eight wide square pale blue-grey floor tiles (#C9D6F2). The signature: the same white net in the centre, RAISED up off the floor, so a
> glowing cyan (#7FF6FF) GAP shows underneath it with a soft cyan light pool on the tiles, and two chunky white chevron arrows (one
> pointing up, one pointing down) beside the net show that it rises and falls. The beach ball sits just above the net. The net and the
> cyan glow are the brightest things in the image. NO sand, NO sun, NO sea."

### 5d. Chat C: R1 RANDOM ROTATION crest `assets/ui/circuits/crest_random.png`

Attach `assets/ui/circuits/crest_meadow_mile.png` and `crest_mayhem_mile.png`. Generate at **1024x1024**.
> "A circuit crest emblem in EXACTLY the same style, shield shape, proportions, thick shiny gold rim, chocolate outline, framing and
> transparent background as the two attached crests. Subject: RANDOM ROTATION, every circuit shuffled. A big glossy toy PRIZE WHEEL
> fills the shield, caught mid-spin with curved white motion swooshes, with a gold pointer at the top and a gold hub. The wheel has five
> wedges coloured meadow green #54C94A, violet #A15FFF, teal #4AD0A8, molten orange #FF8A2A and danger red #FF5A4A, and each wedge
> carries ONE tiny simple icon: a smiling sun, a silver gear, a snowy mountain peak, a pouring crucible, two crossed toy hammers.
> Confetti and gold sparkles burst around the wheel; the shield field behind it is a candy pink-to-gold sunburst. NO question mark, NO
> text, letters or numbers. Transparent background."

**Intake:** trim and resize to **813 px wide**, the brawl crest canvas. Accept only if the shield outline overlays
`crest_meadow_mile.png` within ±3% at the same width.

### 5e. Chat C: M1 Dropshot mode card `assets/ui/modes/mode_dropshot.png` (SP-17)

Attach `assets/ui/modes/mode_sports.png` (style and composition), `assets/characters/bouncer_purple_idle.png` (VEX) and
`objects/ball_beach.png`. Generate at **1536x1024**.
> "A mode-select card diorama in EXACTLY the style, finish, outline weight and scale of the attached soccer-mode image, with the same
> composition idea: the character on the left, the sport object on the right, a small floating ground patch underneath, and a transparent
> background. Subject: DROPSHOT, the volleyball mode, 'spike it over, don't let it drop'. The attached purple goat (VEX: purple markhor
> with long spiral horns and a chunky jetpack with a flame) leaps high on the left, horns forward, SPIKING the attached beach ball DOWN
> and to the right, with a big white impact flash and speed lines. On the right is a toy VOLLEYBALL NET seen from a three-quarter front
> angle: two slim glossy white posts with big round ball knobs on top, a fat padded white top tape, white diamond rope mesh between. The
> ball is passing just OVER the top tape: it is ABOVE the net, never in it. Under them is a small floating patch of golden sand with a
> little sand splash. NOT a soccer goal: no goal cage, no crossbar box, no goal frame, no grass. Thick chocolate outline, glossy,
> saturated. NO text. Transparent background, landscape about 4:3."

**Intake:** defringe, trim, resize to **1184 px wide** (the mode_sports width). Verify the mesh holes are real alpha. The current card
came out that way. If a checkerboard is baked, re-roll.

## 6. Intake and compose (operator; small script by the tools owner)

Raws go in `tools/out/court_cards/raw/`. Put the composite logic in `tools/court_badge_compose.py` (or as `art.py badge`, the tools
owner's call).

1. **Frame:**
   - `art.py check`, then the standard defringe from the portrait intake (normalised-convolution colour bleed into alpha < 0.02);
   - scale uniformly so the **rim outer width = 1216 px** and place it on a 1280x800 transparent canvas, with the **rect** (not the
     bbox) centred at (640, 400);
   - if an ornament would cross y < 4, scale the frame down (rect width no less than 1180) and re-centre;
   - save `assets/ui/courts/_frame.png` and print the measured hole bbox.
2. **Hole mask:**
   - the transparent connected region containing (640, 400), or the green region if the fallback was used, flood-filled from that seed
     with tol 45. The socket mask uses the same flood, seeded at the socket centre;
   - **dilate both masks by 4 px** (into the inner outline), so anti-aliased key-blend pixels are overwritten and never show as a fringe;
   - on the green fallback, also corner-flood the outside (`art.py keyout --tol 45`) and despill the outer edge pixels (clamp G to
     max(R, B) within 3 px of transparency).
3. **Interior fit (per court):**
   - crop the 1536x1024 raw to the hole aspect (about 1536x808), centred vertically. An optional per-court `--dy` (±60 px) rescues a
     composition; record it in CATALOG;
   - Lanczos-resize **uniformly** to the hole bbox. Assert scale x == scale y: no stretch, ever;
   - paste it under the frame through the dilated hole mask.
4. **Recess:**
   - an inner shadow along the hole edge: chocolate `#3B241B`, 30% alpha, 14 px blur, offset 4 px down, clipped to the hole;
   - a soft 8%-white top sheen on the upper 25% of the hole (one gradient, clipped).

   Those two are the only code-made effects. No borders, no labels.
5. **Ball:** Rocketball courts paste `objects/ball.png` and Dropshot courts paste `objects/ball_beach.png`, scaled to the socket's inner
   diameter + 6 px, centred under the frame through the dilated socket mask.
6. **Output and proofs:**
   - `assets/ui/courts/court_<id>.png` (1280x800 RGBA), one per id in `levels/sports_courts.json`;
   - the import gets **mipmaps on** (the card shows it at about 0.29x; check for shimmer);
   - proof sheets in `tools/out/court_cards/`:
     - `sheet_full.png`: all 11 badges;
     - `sheet_cardcrop.png`: each badge cover-cropped to 2.2:1 with a grey TIER-chip box and LOCKED-sash triangle drawn over it, in shelf
       order;
     - `sheet_480.png`: both sheets downscaled ÷4.
7. **CATALOG:** one row per family (frame + 11 courts, R1, M1), each with its prompt reference (this brief), raw names, `--dy` values,
   re-rolls and `SHIP-CANDIDATE`. In-game AD approval is pending.

## 7. Wiring notes for the programmer (layout untouched; reference only, I don't write code)

- **`_thumb_for` court branch:** load `res://assets/ui/courts/court_<id>.png`, falling back to the existing `thumbs/court_<id>.png` bake
  (existence-guarded as now). The card already applies COVERED.
- **Preview:**
  - `COURT_HERO` → the court's own badge (falling back to the mode painting);
  - hide `$Preview/Row/ArtFrame/Inset` whenever a badge loaded. The dark map inset would cover the badge's lower right and
    reintroduces the dark strip UX4-12 banned.
- **Brawl RANDOM card:**
  - `_make_card` loads `crest_random.png` when present, instead of the rainbow plate and spinning "?";
  - `_show_preview` shows it as `_pv_art` (same as a circuit crest) and hides `Fan`;
  - keep both fallbacks existence-guarded.
- **ModeSelect:** same path, so no code change for M1. Then verify the SP-17 **title baseline**: the DROPSHOT title must sit level with
  its neighbours. If it is still low with the new art, it is a layout bug, not an art one.

## 8. Pass tests (screenshots only, 1920x1080, then downscaled)

Capture each Rocketball court focused (8), each Dropshot court focused (3), one Rocketball shot with a LOCKED court focused, the Brawl
select with RANDOM focused, and ModeSelect. Save to `tools/out/wk/WK-65_*.png`.

1. **480 squint, blind (the headline test).**
   - Hand a fresh agent the 11 preview regions downscaled to 480-px-wide screens, with names masked, plus the 11 blurbs from
     `sports_courts.json`. It must match **≥ 10/11**, including 3/3 Dropshot and 4/4 hazard courts.
   - Card-only variant: from a 480-px shelf screenshot, it must name the hazard on HAMMER YARD, MINEFIELD and THE CRUSHER (3/3).
2. **Neighbours differ.**
   - In shelf order, adjacent cards differ visibly at 480.
   - Numeric guard: the mean L\*a\*b\* of each interior differs from both neighbours by ΔE76 ≥ 20.
   - Mean interior L\* ≥ 30 for every court. No black stadiums.
3. **One family.**
   - All 11 frames are pixel-identical (this is the compose guarantee; spot-check by diffing the rim region).
   - Interiors share camera height, outline weight and lighting style.
   - Put the Rocketball and Brawl selects side by side: the court badges are at the crest polish level (outline weight, saturation,
     gloss).
4. **Reads as SPORTS.** A fresh agent shown one 480 court-select screenshot and asked "what kind of mode is this?" answers
   soccer/sports/volleyball, not "levels" or "arenas". Red/blue goals or the white net must be visible on every card crop.
5. **No text.** At 200% zoom on all 13 new images: zero letters, digits, logos, scoreboard numbers or a "?". Any glyph means a re-roll.
6. **Crop safety.** On every card, the TIER chip and LOCKED sash cover only plain background. The signature object is fully inside the
   card crop (not cut by the cover crop) on all 11.
7. **Locked state.** In the LOCKED-focused shot (preview tint `arena_preview_locked_tint` plus the dimmed card), the court is still
   recognisable by silhouette.
8. **Polish at 200%.**
   - No green, magenta or checkerboard fringe on the frame or ball socket.
   - No gap or halo between the interior and the rim.
   - No stretched interior (the compose assert passed).
   - The ball is centred in its socket.
   - On dark courts, the signature reaches L\* ≥ 70 against a background of L\* ≤ 35.
9. **Mechanical truth** (checked against the JSON, one line per court):
   - CENTER PITCH: two mirrored pucks.
   - BOX: compact, with bank-shot trail.
   - LONG HAUL: longest, with an arc and staggered pucks.
   - BOWL: U floor, ball in the dip.
   - HAMMER YARD: one hammer pivoting from top centre (the in-game sprite).
   - MINEFIELD: in-game bombs, mirrored, mostly on the floor line.
   - CRUSHER: two heads closing horizontally at mid-height, ball ejected vertically.
   - SCRAPHEAP: hammer + bombs.
   - BEACH: net + 10 tiles.
   - CORAL: wider, net + 12 tiles.
   - DOME: lifted net with a glowing under-gap.
   - Rocketball goals are red left and blue right; the Rocketball ball has a gold band, never a soccer pattern.
10. **Dropshot mode card.**
    - At the ModeSelect size and at 480: "net", not "goal".
    - The goat is VEX (on-roster).
    - The ball is visibly over the net.
    - The DROPSHOT title baseline is within ±4 px of its neighbours.
11. **RANDOM ROTATION.** Beside the five circuit crests at 480 it reads as "all of them, shuffled". Same shield and rim. The preview shows
    the painted crest, not the fan.

**Verdict rules:**
- Test 1 below 9/11, or any card still a dark stadium: **Reject** (restate this brief).
- A failing interior on tests 2, 5, 6, 8 or 9: **Fix**, re-roll that interior only.
- **Ship** needs 1-9 and 11 to pass. Test 10 can ship separately (SP-17 is separable).

## 9. Out of scope

- Per-court in-match theming (WK-66). These interiors are its art target, nothing more.
- Surfacing the sports `rotate_sets` as a court-select RANDOM card. If the producer wants one later, it is one more interior in this
  same frame (a spinning wheel of the 8 court emblems).
- Any change to the WK-60b layout, card size or preview geometry.
- Trials crests and Brawl circuit crests, which are shipped.
