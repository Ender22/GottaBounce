# Art brief: Rocketball KICKOFF GATE (WK-131)

Date 2026-11-15 · Author: art-director · Spec `docs/specs/wk131_kickoff_rule_2026-11-15.md` (§4.4 feedback, §7 knobs)
Builds on: `docs/briefs/sports_nets_2026-11-15.md` (WK-66a goal cage) and its grade `docs/audit/2026-11-15_wk66a_artgrade.md`
Screens studied: `tools/out/wk/WK-66a_the_box.png`, `WK-66a_long_haul.png`, `WK-66c_test7_colourway_{idle,goal}.png`

The programmer builds what is written here. I grade it from in-game captures only, using the tests in section 10.
Timing values (open at 3.0 s, 0.6 s warning, 0.2 s retract, 450 px/s spit, 0.6 restitution) belong to the spec and are not
changed here. Every visual number below becomes a `Tuning.gd` knob in the spec's "WK-131 kickoff rule" block (section 9).

---

## 0. Summary

- **The look:** one fat glossy **cream-and-gold candy-stripe pole** fills each goal mouth like a toy boom gate. Its ends
  plug into the cage's own team-coloured post caps. A round **cream padlock badge** sits at the centre of the pole, with a
  **gold ring that drains** from GO until the gate opens.
- **The open:** the badge pops open and bursts into stars, the pole snaps **up into the top post cap**, and a double
  referee whistle plays. Afterwards the mouth looks exactly like the WK-66a goal. Nothing is left behind.
- **The block:** when the ball hits the pole, the pole **bows away from the ball and springs back**. It flashes white,
  makes a hollow toy **CLONK**, and shows a cream **"NOT YET!"** pop. Hard shots also get a crowd "ooh".
- **Reuse:** the pole is a tile of the existing `goal_frame.png` tube run with a new stripe shader. The sockets are
  duplicates of the frame's own cap pieces. The bursts use existing `fx/` sprites, and the ring is drawn in code like the
  player charge ring.
- **New art: one small asset pair.** The padlock badge, closed and open (2 sprites of 256 px, one chat). Nothing in the
  repo can stand in for it (section 2).

---

## 1. The read we need, and what failure looks like

| Moment | A newcomer must think | Failure reads (each is a Fix) |
|---|---|---|
| Pre-GO and live, closed | "That goal is **blocked for now**. The lock and ring mean **it opens soon**." | "the goal is walled off" / "is that part of the wall?" / "a pole, a pipe, a ladder" |
| Ball hits it | "The ball **bounced off the gate**. Not yet." | "the goal is broken" / "glitch" / "it hit the post" / "the ball went in but didn't count" |
| Last 0.6 s | "**Something's about to happen** to the gate. Get back!" | nothing noticed, or "is it breaking?" |
| Open | "**It's open**, goals count now." | "it vanished" (no motion seen) / "did someone score?" (goal-like celebration) |

Three design rules follow from this table:
1. The gate is a **foreground toy that moves**, never a texture on the goal. It has its own stripes and its own material,
   and it is thicker than the cage tubes.
2. **"Temporary"** is shown three ways: the draining ring, the visible socket it will slide into, and the drop-in at stage
   start, where players see it arrive.
3. **The gate never celebrates.** It gets no team colour, no confetti and no goal horn. Those all mean "goal".

---

## 2. Decisions (art vs code, and options I rejected)

**Chosen**
- **Pole body = reuse.** Use `assets/world/sports/goal_frame.png`, back-tube run region **src x 13-139, y 300-1300**. I
  measured it: the rows are uniform, it is greyscale, it has the chocolate outline, and the highlight is centred.
  - Tile it vertically and scale it uniformly to the pole width.
  - Colour it with the new `assets/shaders/kickoff_gate.gdshader`, a fork of the `net_frame.gdshader` tint_mode-1 gradient
    map that uses a per-pixel stripe colour in place of the team tint (section 6).
  - The pole is literally made of the same toy tube as the cage, so it reads as **part of the goal set** (a mechanism of the
    goal, not a wall). The stripes and the thicker gauge make it its own object.
- **Sockets = reuse.** Duplicate the goal ThreeSlice's **top and bottom cap pieces**: same texture region, transform,
  material and team modulate, re-added after the pole. The duplicates are pixel-identical, so nothing visible changes.
  The pole's ends then tuck under the team post caps, and the pole can slide up *into* the top one.
- **Drain ring = code**, drawn the same way as the player charge ring (`Player._charge_ring` family). It is an anti-aliased
  arc with round caps and a chocolate backing. The game already accepts this kind of telegraph (KeyDoor's gold lock ring).
- **Bursts = reuse:** `fx/ko_blast_star.png`, `fx/star_sparkle.png`, `fx/puff_soft.png`, `fx/ko_blast_ring.png`, cream-tinted
  through `fx_tint`.
- **Padlock badge = NEW** (section 8). The repo has no padlock. `objects/key.png` means "go fetch a key" (the Trials key and
  door), which is the wrong instruction. Code-drawn glyphs are banned.

**Rejected**
- **Team-tinted energy shutter / glowing bars.**
  - (a) Team colour means "score" in this mode (WK-27, spec §4.4).
  - (b) A red shutter on a red cage has no figure/ground: the cage silhouette and the "closed" read both get weaker.
  - (c) Energy beams are not Glossy Toybox. Glowing bars read as a laser that kills, and goats fly through them unharmed,
    which contradicts what they see.
- **The vault panel `objects/door_tile.png`.** A solid plate in the mouth reads as "goal walled off" (permanent), it hides
  the cage, and it already means "needs a key" in Trials.
- **Several thin bars (a literal portcullis).** Two 26 wpx bars are 15 screen px each at zoom 0.60, under the spec's 28 px
  gate floor. One fat pole passes the floor and is a single clean silhouette.
- **On/off blinking.** It makes the gate invisible half the time. The warning is a brightness swing instead (section 5).

---

## 3. Layout sketch (LEFT goal, team 0; the right goal is the exact mirror)

```
   wall column (z 0)  ||
   ===TOP TUBE========(O)   <- top post cap: SOCKET overlay (dup of frame cap, team colour), draws OVER the pole
   back |/\/\/\/\/\/\/|#|      pole top end hidden under the cap (pole drawn from y_top-8)
   tube |\/\/\/\/\/\/\|/|   <- POLE: 52 wpx wide, centred on net_mouth_x. Diagonal cream/gold candy stripes,
        |/\/\/\/\/\/ ( @ ) <- BADGE: 64 wpx cream padlock badge centred on (net_mouth_x, zone centre y)
        |\/\/\/\/\/\/(   )      inside the gold DRAIN RING (outer dia 106 wpx)
        |/\/\/\/\/\/\/|\|
   ===BOTTOM TUBE=====(O)   <- bottom post cap: SOCKET overlay, pole bottom end tucked under it
   wall column (z 0)  ||                                   COURT ->   (ball stops against the pole face)
```

- **Pole x:** centred on `net_mouth_x` (the mouth plane). The **collider (48 wpx, spec) shares this centre.** The pole's art
  is 52 wpx, so it bleeds 2 wpx past each collider face. That keeps the ball-touching-pole read honest: the house limit is
  8 wpx, and the ball's outline should meet the pole's outline.
- **Pole y:** visual span = `y_top - 8` to `y_bot + 8`, where `y_top` and `y_bot` are the top and bottom tube centre lines
  (= the zone's top and bottom edges, which is how `SportsNetArt.setup_goal` places them). Both ends are hidden under the
  socket overlays. The collider spans `y_top..y_bot` (spec).
- **Cage visibility:** the pole covers only the 26 wpx of cage interior next to the mouth. On a 150 wpx cage (LONG HAUL /
  BOWL family) that leaves ≥ 60 % of the mesh plus the back tube and both elbows in plain view (140 wpx on THE BOX:
  ≥ 58 %). The team colour stays visible above, below and behind the pole.
- **Badge** at the zone's centre height. A straight shot will sometimes cover it at the moment of impact (the ball wins,
  section 7). The flash and the pop carry that frame.
- **Parenting gotcha:** the gate must **not** inherit a team `modulate`. Parent it beside the frame, never under a node that
  is tinted with `team_col`.

---

## 4. Size math (zoom 0.60 LONG HAUL · 0.69 CENTER and most courts · 0.90 THE BOX · 1/4 couch squint of 0.60)

| Element | World px | @0.60 | @0.69 | @0.90 | 480-px squint @0.60 | Verdict |
|---|---|---|---|---|---|---|
| Pole width | 52 | 31 | 36 | 47 | 7.8 | ≥ 28 px spec floor. At the squint it is a bright bar across the mouth (stripes need not resolve there) |
| Stripe band (period 44, 45°) | 22 | 13 | 15 | 20 | 3.3 | ≥ 10 px floor at play zoom |
| Badge | 64 | 38 | 44 | 58 | 9.6 | = the spec's 38 px floor |
| Drain ring: band 12 + 3 outline each side | 18 total | 10.8 | 12.4 | 16.2 | 2.7 | progress readable at play zoom |
| Drain ring outer diameter | 106 | 64 | 73 | 95 | 16 | fits in the smallest mouth (THE BOX 260) with 77 wpx to spare each side |
| Flex bow peak | 12 | 7.2 | 8.3 | 10.8 | — | about a quarter of the pole width, so you can see it bend |
| Warning lift | 10 | 6 | 6.9 | 9 | — | a visible sliver of mesh opens at the bottom socket |
| "NOT YET!" cap height | 34 | 20 | 23 | 31 | — | Lilita One |
| Mouth (for reference) | 260 / 300 / 340 | | | | | THE BOX / CENTER family / LONG HAUL |

---

## 5. Palette (hex)

| Use | Hex | Notes |
|---|---|---|
| Stripe A (cream) | `#FFF3D6` | the same cream as the WK-37b ghost and skull family |
| Stripe B (honey gold) | `#F2B33D`, shade `#C98A1E` | gold = "locked / rule" in this game (KeyDoor ring, WK-113 rule row) |
| Gloss | `#FFFFFF` | the shader's luma ≥ 0.93 knee (as `net_frame`) |
| Outline | `#3B241B` | survives the shader (luma < 0.22 untouched) |
| Badge face / rim | `#FFF3D6` / `#EBD9B0` | generated |
| Padlock | gold `#F2B33D` body, `#E9E4DA` cream-silver shackle, chocolate keyhole | generated |
| Drain ring fill / track | `#FFC93C` on a `#3B241B` backing; the drained part is shown as the backing at alpha 0.45 | code |
| Warning swing peak | ring and badge toward `#FFFFFF` (additive mix, never transparent) | code |
| Hit flash | pole and badge to `#FFFFFF` | code |
| "NOT YET!" | fill `#FFF3D6`, 6 wpx `#3B241B` outline | Lilita One |
| Open burst | stars `#FFF3D6`, puff `#FFF3D6` at alpha 0.5 | reused fx, fx_tint |

**Banned on the gate:** team red `#ff4b6a`, team blue `#3fa9ff`, the four Rocketball goat hues (pink, orange, blue,
green), safety orange `#FF6A2A`, hazard red `#E6402C`, yellow-and-black hazard banding (the hammer and crusher language
for "this hurts"), and magenta `#FF4FA3`.

**Ball separation risk (watch item):** the ball is white with a gold seam, which is close to the gate's values. The ball
only overlaps the pole by the 2 wpx bleed, and both objects carry the chocolate outline. Test 10.4 decides. **Fallback if
it fails:** darken stripe B to `#D9941A`. If it still fails, swap stripe B to plum `#7A4FB8` (VEX is not offered in
Sports, so purple is free there).

---

## 6. States and motion (every time is on the spec's live-ball clock, T = `sports_gate_open_s`)

### 6.1 Drop-in (stage load, every kickoff)
- At **STAGE_INTRO + 0.15 s** the pole drops out of the top socket to closed in **0.15 s**. Use ease-out, with a 4 wpx
  rebound off the bottom socket.
- The badge scales in from 0.6 to 1.0 with a small overshoot. Sound: the clonk at -8 dB, pitch 1.2.
- Why: players see the pole **arrive**, so they learn it is a mechanism that moves vertically. That primes "it will go back
  up". Knob `sports_gate_drop_in` (bool, true).
- Collision is closed from stage load regardless (spec). The drop-in is visual only and finishes well before GO.

### 6.2 Closed (from the drop-in through COUNTDOWN, then from GO to T - 0.6)
- Before GO, the ring is **full and static**.
- From GO it drains clockwise from 12 o'clock, linearly over [0, T]. No digits (spec).
- The pole is still. No idle pulse, wobble or width breathing (a non-uniform pulse is banned, per WK-66a).

### 6.3 Ball hits the closed gate (contact speed ≥ `sports_gate_fx_min_speed` 150 px/s; below that, no FX)
All of these start on the contact frame. Never add hit-stop or shake (spec).
1. **Flex:** the pole bows **away from the ball** (toward the net).
   - Peak = `clamp(speed / 2000, 0.25, 1.0) * 12 wpx`, a Gaussian centred on the contact y with σ 70 wpx.
   - Both ends stay pinned in the sockets.
   - A damped spring gives 2 visible wobbles and settles by **0.25 s**.
   - Implement it in `kickoff_gate.gdshader` with the padded quad and inverse-UV-offset technique of `net_mesh.gdshader`.
     It is a bend, never a stretch. The spec's "0.12 s squash" is the first half-wobble.
2. **Flash:** the pole and badge go to white for **0.06 s**, then back over 0.12 s. That is 2 frames in a 30 fps recording;
   the spec's "1 frame" is invisible to the eye and to WK-93.
3. **Impact star:** one `fx/star_sparkle.png`, cream, 36 wpx, on the pole's court-side face at the contact y. It lasts
   0.18 s.
4. **"NOT YET!" pop:** limited to one per gate per `sports_gate_pop_cooldown` (0.5 s, spec).
   - It spawns **70 wpx court-side of the pole face and 90 wpx above the contact point**, so it is never over the ball.
   - It is a padlock glyph (the closed badge at 30 wpx) followed by "NOT YET!".
   - Motion: scale 0.6 → 1.15 → 1.0 in 0.12 s, rise 30 wpx, hold, gone by 0.6 s.
5. **Sound:** CLONK, pitched and scaled by speed. Add the crowd "ooh" at ≥ 1500 px/s (spec).
6. **Spit at T (spec §4.3):** add a `fx/ko_blast_ring.png` puff, cream, 50 wpx, 0.15 s, at the ball contact point, so the
   450 px/s nudge reads as the gate's springy pop and not as a phantom shot.

**Copy deviation from the spec:** the pop says **"NOT YET!"**, not "LOCKED!". "LOCKED" plus a padlock invites "find the
key" (the Trials door). "NOT YET!" says *temporary*, which is the exact newcomer read we need. The game-designer may
overrule this, but the string must come from one constant either way.

### 6.4 Warning (T - 0.6 to T)
All the warning cues speed up together. The same clock drives the sound ticks, so sight and sound lock together.
- **Badge and ring swing in brightness** toward white. The rate accelerates from **3 Hz to 8 Hz** (`sports_gate_warn_hz_from`
  / `_to`). It is an additive brightness mix, so alpha never drops and nothing ever blinks out.
- **Badge shake:** ±3 wpx, random direction, re-picked every swing peak.
- **The pole lifts 10 wpx** out of the bottom socket over the first 0.1 s and holds there, trembling ±1.5 wpx vertically.
  This is "it's starting to go up". The collider does **not** move.
- **The stripes start scrolling upward**, from 0 to 2.5 periods/s (like a barber pole spinning up). This shows the
  direction the gate is about to go.
- Both gates run the warning in sync, with one shared sound.

### 6.5 Open (T - 0.2 to T, then T)
- **At T - 0.2:**
  - The ring snaps to empty and disappears.
  - The badge swaps to **`gate_badge_open.png`** with a scale pop (1.0 → 1.3 in 0.06 s), then flies up 40 wpx and fades out
    by T + 0.1.
  - Add a cream burst at the badge: one `ko_blast_star` at 70 wpx plus 5 `star_sparkle` thrown outward, 0.3 s.
- **T - 0.2 to T:** the pole **slides up into the top socket**.
  - The ease is ease-in (cubic), so it accelerates and snaps.
  - It is clipped at the top tube centre line (`clip_top_y` uniform, the mirror of `net_frame`'s `clip_y`).
  - The last 21 wpx of travel vanish under the top socket overlay.
  - The pole's bottom end must be **fully above `y_top` at T**. That makes 6 recorded frames at 30 fps (spec §5.5).
- **At T:**
  - Collision drops (spec, never earlier).
  - The top socket overlay does a uniform squash-pop (1.0 → 1.12 → 1.0 over 0.12 s) and puffs a `puff_soft` (cream, 60 wpx,
    alpha 0.5) out of the cap. That is the "thunk" of the pole slamming home.
  - The double whistle plays.
- **After T:** the gate node draws nothing (free it or hide it). The goal is pixel-identical to WK-66a. The next kickoff
  reload brings back a fresh closed gate with its drop-in.

**LIVE BALL arm (rule 2) note:** if that arm ships, an event-triggered open has no warning. Run the 6.5 sequence from the
event with the pole retract shortened to 0.08 s. Collision is off at the event, so this is a 0.08 s visual lie, accepted
only for rule 2. The arm also needs the spec's per-team half-rings, which are out of scope here and get their own brief.

### 6.6 HUD (ui-ux-designer; style only)
- "GOALS OPEN!" sticker, match stage 1 only (spec): Lilita One, cream `#FFF3D6` on a chocolate rounded card with a gold
  `#F2B33D` rim. It sits top-centre under the score bug for 0.7 s, never over the court.
- The WK-113 rule-row copy follows the spec.

---

## 7. Z-order

| Layer | z (absolute) | Notes |
|---|---|---|
| Goal mesh + team veil | -2 | unchanged (WK-66a) |
| Goal frame (team) | -1 | unchanged |
| **Gate pole** (shader, clip) | -1, added **after** the frame | in front of the cage, behind the walls, goats and ball |
| **Drain ring** then **badge** | -1, after the pole | |
| **Socket overlays** (dup top and bottom cap pieces) | -1, added **last** | the pole's ends tuck under the team caps |
| Wall art | 0 | the upper column also masks the retract path |
| Goats | ≥ 0 | **always draw over the gate.** Goats fly through it (ball-only collider), so they must visibly pass in front of it |
| Hit star, "NOT YET!" pop, open burst | 39 | over goats, **under the ball** |
| Ball | 40 | **never covered by any gate art** |
| Goal front veil | 42 | unchanged. It covers the cage interior only, so the gate is irrelevant to it |

---

## 8. New asset: padlock badge (closed + open)

**Files:**
- `assets/ui/` is wrong because this is world art. Use `assets/world/sports/gate_badge_locked.png` and
  `assets/world/sports/gate_badge_open.png`.
- Each is **256x256** with real alpha, drawn at 64 wpx (4 src px per wpx), with **mipmaps ON** (drawn at about 0.15x).
- Both must sit on an **identical, pixel-registered disc** so the swap at T - 0.2 doesn't jump. Align them by the disc
  centroid at intake if needed.

**Chat:** generate in ONE ChatGPT chat.
- Attach `assets/reference/style_north_star.png` and `assets/objects/key.png` through the clipboard Ctrl+V technique (see
  CATALOG). Paste the prompt text through the clipboard too (long prompts freeze the renderer).
- Don't attach any goat or skull art (face bleed).
- Use the magenta key-colour suffix from the WK-66a brief: it gives a clean global key, and the padlock shackle encloses a
  hole.

**B1 prompt (closed):**
> "Please generate an image. The two attached images are style references: match the glossy toy style of the first, and
> make the gold metal exactly like the attached key (the second). A round glossy toy BADGE for a 2D party game, seen
> straight-on: a thick chunky coin-like disc with a raised rounded rim, cream-white face (#FFF3D6) and a slightly darker
> warm-cream rim (#EBD9B0). In the centre, a big chunky golden PADLOCK, CLOSED: a rounded-square lock body in glossy gold,
> a fat rounded U-shaped shackle on top in pale cream-silver, both legs fully inside the body, and one small dark keyhole
> on the body. The padlock fills about 60 percent of the badge diameter and is perfectly centred. Bold simple silhouette
> that reads at 40 pixels. Lit from the top-left: one soft white gloss highlight on the rim and one on the lock body. No
> text, no letters, no numbers, no stars, no ribbons, no key. Style: high-quality glossy cartoon game art, thick clean
> dark-chocolate (#3B241B) outlines, soft plastic-toy shine highlights. IMPORTANT: the background, AND every hole or empty
> space inside the object, is ONE SOLID FLAT PURE MAGENTA colour #FF00FF: no gradient, no shadow, no checkerboard, no
> floor, no sky. No magenta or pink anywhere on the object itself. Square image."

**B2 edit (open), in the viewer's "Describe edits":**
> "Keep this exact badge and padlock: same size, same position, same colours, same lighting, same outline. Change ONLY
> the shackle: it has popped OPEN. Its right leg is lifted fully out of the lock body and the shackle is swung a little to
> the left, so there is a clear magenta-free gap of cream badge face between the shackle's right end and the lock body.
> The shackle must stay inside the badge rim. Same solid flat magenta #FF00FF background."

**Accept at intake** (re-roll rather than hand-paint):
- The disc is round (ellipse error ≤ 3 %).
- The padlock is ≥ 55 % of the disc diameter.
- The open gap is visible at a 40 px downscale.
- The disc rims of B1 and B2 match within 2 px after centroid alignment.
- 0 residual key-tinted pixels.

**Intake:**
1. `python tools/art.py keyout-color IN OUT --key ff00ff --tol 90 --no-trim`.
2. Crop to a square on the disc bbox plus 4 % padding.
3. Lanczos resize to 256, re-setting alpha-0 RGB to chocolate.
4. `art.py check`.
5. Add two `SHIP-CANDIDATE` rows to `assets/CATALOG.md` with these prompts, plus the KickoffGate reuse notes (the
   goal_frame region and the cap duplicates).

---

## 9. Visual Tuning knobs (append to the spec's WK-131 block; the timing knobs stay the spec's)

| Knob | Value | Knob | Value |
|---|---|---|---|
| `sports_gate_bar_w` | 52.0 | `sports_gate_flash_time` / `_fade` | 0.06 / 0.12 |
| `sports_gate_stripe_period` | 44.0 | `sports_gate_fx_min_speed` | 150.0 |
| `sports_gate_badge_wpx` | 64.0 | `sports_gate_warn_hz_from` / `_to` | 3.0 / 8.0 |
| `sports_gate_ring_r` (centreline) | 44.0 | `sports_gate_warn_lift` | 10.0 |
| `sports_gate_ring_band` | 12.0 | `sports_gate_warn_shake` | 3.0 |
| `sports_gate_flex_amp` | 12.0 | `sports_gate_scroll_max` (periods/s) | 2.5 |
| `sports_gate_flex_sigma` | 70.0 | `sports_gate_drop_in` / `_drop_time` | true / 0.15 |
| `sports_gate_flex_time` | 0.25 | `sports_gate_pop_wpx` (cap height) | 34.0 |

**Stripe shader contract (`kickoff_gate.gdshader`):**
- **Stripe mask:** computed in **local world units** (not UV), so the band size is constant on 260 and 340 mouths. Use
  `s = smoothstep(-aa, aa, sin(...))` with `aa` from `fwidth`. No hard steps; at 0.60 the stripes must not crawl while
  scrolling.
- **Colour:** `mix(cream, gold, s)` fed into the `net_frame` tint_mode-1 gradient map (the outline < 0.22 and the gloss
  > 0.93 survive).
- **Flash:** a uniform that mixes toward white.
- **Retract clip:** the `clip_top_y` uniform.
- **Flex:** a padded-quad UV offset.

---

## 10. Pass tests (graded from rendered captures only, at 1920x1080; never from the asset files)

QA captures; I grade. Use one port per lane (WK-130), and take no stills during measured COMBAT (spec §5.1): use
dedicated capture runs.

1. **Couch squint.** Downscale stills to 480 px wide.
   - Courts: **THE BOX (0.90), CENTER PITCH (0.69), LONG HAUL (0.60)**, one still each during COUNTDOWN.
   - Pass: both mouths show a bright bar across them in under 1 s, **and** both cages are still nameable as red and blue
     goals.
   - Fail: the cage is unreadable, or the bar merges into the white wall columns.
2. **Blind newcomer read.** Use a fresh agent with no task context. Don't say "gate", "lock", "kickoff" or "timer".
   - (a) The CENTER PITCH countdown still: *"Describe what you see at each goal and what you think it means for play."*
     Pass = it names blocked/closed/locked **and** temporary/opening/countdown. "Blocked" alone is a Fix (strengthen the
     ring and the drop-in).
   - (b) A 3-frame strip: the ball approaching, the contact frame (flash + star + NOT YET!), the rebound. Ask *"What
     happened to the ball?"* Pass = bounced off a barrier/gate, or "not allowed yet". **Any "broken", "glitch", "hit the
     post" or "went in but didn't count" = Fix.** If it happens twice after fixes, it is a **Reject**, and I restate the
     brief.
   - (c) A 4-frame open strip ending one frame after T: *"What changed?"* Pass = the barrier went up / the goal opened.
3. **All 8 Rocketball courts:** CENTER PITCH, THE BOX, LONG HAUL, THE BOWL, HAMMER YARD, MINEFIELD, THE CRUSHER, THE
   SCRAPHEAP.
   - One COUNTDOWN still per court, both ends.
   - The pole ends are hidden under the sockets.
   - The ring sits inside the mouth and clear of the wall art.
   - The gate is identical at both ends (neutral).
   - The cage team colour is visible above, below and behind the pole.
   - Hazard courts: the gate doesn't read as a hazard next to the hammer, bomb or crusher art.
4. **Ball separation.** In a still with the ball resting against the pole (any court), at full res and at the 480 squint,
   the ball's silhouette and outline are complete and clearly a separate object. If not, apply the section 5 fallback.
5. **Priority.** No captured frame shows gate art (pole, ring, badge, pop, burst) over the ball. Goats always draw over
   the pole.
6. **Motion: a WK-93 recording of 3 kickoffs.** The `sheet.png` plus a follow-zoom must show:
   - the drop-in;
   - ≥ 1 clonk with the flex visible in ≥ 2 consecutive frames, plus the flash and the pop;
   - the warning lift, scroll and brightness swing;
   - the retract over ≥ 6 frames, with **no pole pixels at or after T**;
   - the badge burst;
   - the socket thunk.
   Also confirm in the SFX log that the whistle frame lines up with T ± 1 frame.
7. **Polish at a 200 % crop.**
   - No seam in the tiled tube.
   - **No double edge or misregistration on the socket overlays.** Any visible doubling of the post cap is a Fix.
   - Stripes are anti-aliased (no stair-steps, no moiré at 0.60).
   - No magenta or purple fringe on the badge.
   - The ring is anti-aliased with its chocolate backing.
   - No flat rect fills and no debug lines.
   - No pixel of the open gate is left in the mouth after T.
8. **Team neutrality and colourway.** On the default RED/BLUE match and on one non-default WK-27 colourway match, the gate
   carries no team hue, and contrast against both cages is adequate.
9. **Flash safety.** Only the pole, badge and ring ever flash. No full-screen or court-wide flash comes from the gate. The
   warning never exceeds 8 Hz.
10. **Scope regression.** Dropshot (BEACH, CORAL COVE, DOME) and Trials goal_zones show no gate art. `sports_kickoff_rule = 0`
    shows no gate art.

**Verdict rules:**
- **Ship** needs tests 1-9 all to pass.
- A bar that reads as wall or pipe in test 1, or a "broken/glitch" read in test 2b, is a **Fix**. If either repeats after
  fixes, it is a **Reject**.
- A code-drawn rect, an unstriped flat bar, or a team-tinted gate is an automatic **Fix**.

---

## 11. Sound cues (character only; the sound-designer picks from existing CC0 and owner assets, logged in `assets/sfx/LICENSES.md`)

| Key | Character | Must NOT sound like |
|---|---|---|
| `gate_clonk` | Short, dry, **hollow toy-plastic or wood-block "CLONK"** (80-150 ms, body around 250-400 Hz) with a tiny rubbery *boing* tail (≤ 120 ms) that says "it bounced". Pitch 0.9-1.15 and volume by impact speed. Reused for the drop-in at -8 dB, pitch 1.2. | the WK-105 wall "tonk" (it must be lower and hollower); metal clang (cage or hazard); glass or crash ("broken") |
| `gate_whine` (rename it `gate_windup` if you like) | 0.6 s **accelerating wind-up ratchet**: toy crank ticks speeding up from about 3 to 8 per second, which locks to the visual brightness swing and ends in a click on T. Light and playful. One shared voice for both gates. | the WK-26 super-aim wind-up (the reversed `lower.mp3` slide whistle) — a reused slide whistle would read as "someone is charging a super"; a siren or alarm |
| `whistle_double` | Referee pea whistle **"TWEET-TWEET"**: two bright blasts of about 0.15 s each with a 0.08 s gap, the first transient on T. The loudest of the four, but under the goal stinger. | the goal horn or stinger (reserved for goals); the countdown beeps |
| `crowd_ooh` | Short crowd **"ooooh!"** near-miss (0.7-1.0 s), swelling and falling back, mixed under the music. Rate-limit it to 1 per 1.5 s. | a cheer (that's a goal) |

---

## 12. Out of scope

- The LIVE BALL per-team half-rings on the ball (rule 2 only, separate brief if that arm wins).
- Bot behaviour, collision, timing values (spec).
- The rule-row copy (ui-ux and spec).
- WK-66a follow-ups (the HUD goal flash, the Trials grid).
