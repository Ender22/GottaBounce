# Art grade: WK-37d ghost identity tags + islands_void faintness (b76d36f)

Date 2026-11-15 · Grader: art-director · Brief: `docs/briefs/ghost_goats_2026-11-14.md` (R1-R8) · Godot NOT launched
(the machine was busy). This grade uses existing captures only.

Evidence: `tools/out/wk37d_R1_sheet.png` (graded blind first), `_R1_squint`, `_R1_key`, `_R3_colourblind`,
`_R3_tag_closeup`, `wk37d_tags`, `_park`, `_banner_hide`, `_banner_after`, `_bright_ab`, `_wide_ref`,
`wk37d_lift_islands_void_{field,sky}_{off,on}.png`, `wk37d_islands_lift_{off,on}.png`, and raw frames
`tools/out/rec/wk37d_islands/frame{282,343,1014,1345}.jpg` and `rec/wk37d_mix/frame{204,1113}.jpg` (each one is a few frames
after a ghost `bleated` event in data.json).

## Verdicts

| Item | Verdict |
|---|---|
| Ghost identity tags | **FIX** (4 items below) |
| islands_void readability (bright-backdrop lift + wide-zoom) | **SHIP** |

## Blind read (R1 sheet, before the key)

- **Classification:** 20/20 living vs ghost, each in under 1 s, and the same in the squint sheet. The ghost body channels hold:
  alpha, no chocolate outline, hem and tail.
- **The problem:** the bot tags are often the cue I found the ghost by.
  - In the squint sheet, every bot ghost reads as a **grey rectangle with a smudge under it**.
  - Frames 1, 3, 7, 15, 17 and 18 are the clearest cases. The tag is the highest-contrast object the ghost owns.
  - On the bright meadow it is about as salient as a living goat.
- **The hierarchy is inverted.** A living bot carries no tag mid-fight (the pip fades to 0 after the intro). A dead bot carries a
  two-line dark plate. So the dead player is the most labelled thing on screen. That breaks "ghosts read as secondary".
- **The human tag ("P1") is the right weight.** It is a pink chip at 0.50 that sits beside its ghost and does not shout
  (`wk37d_tags.png`, `wk37d_park.png`, `wk37d_lift_islands_void_field_*.png`). That tag is the target.

## Why the bot tag shouts

- `PlayerPip.setup(cpu=true)` dresses the tab as `CPU_BG`: dark chocolate at 0.94, plus a cream "CPU" second line.
- At 0.50-0.65 alpha over a pale backdrop, that turns into a **muddy khaki/grey slab**. The worst case is PUFF over the meadow
  (`wk37d_park.png`, `wk37d_tags.png`): an olive box with faded gold type, which looks dirty rather than glossy.
- The slab is also about 2x the human tag's height, and larger than the ghost body (about 38-55 px).
- It breaks the house rule the ghost treatment is built on (brief §0: **chocolate = alive/touchable**). The ghost drops its
  chocolate outline, then gets a chocolate plate stuck on its head.
- The builder's concern #1 is confirmed.

## FIX: tags (numbered, in priority order)

1. **Dress bot ghost tags in the human tag style, NAME only. Drop the CPU sub-line and the dark plate on ghost tags.**
   - In `PlayerPips._set_ghost_mode(on=true)` for a CPU slot:
     - hide `Tab/Box/Sub`;
     - override the tab stylebox `bg_color` to the player colour (the human branch of `PlayerPip.setup`);
     - set `_fill.color` = player colour and `_pointer.color` = `CHOCO`;
     - remove the label's goat-colour `font_color` override, so it uses the theme's human cream type plus outline.
   - On undress, call `setup(...)` again so the living CPU intro pip is unchanged.
   - The label stays at 30 px × `ghost_pip_scale` 0.9333 = **28 px**. That is the floor, so do not change the scale.
   - "CPU" is not information a player needs about a ghost; the HUD card already says it. The name carries identity for R3.
   - In all four colourblind filters the names stay legible through the theme's dark text outline (`wk37d_R3_colourblind.png`
     still applies, because the outline carries contrast, not the fill hue).
2. **Hide a ghost's own tag while its BAAA! word burst is up.**
   - Fade it to 0 with the existing `move_toward(..., 0.08)` step, and bring it back when the word ends.
   - Evidence (builder's concern #2, confirmed and worse than described):
     - `rec/wk37d_islands/frame282`: the BUTCH tag prints *through* the bubble, a double-text smear;
     - `frame1014` and `rec/wk37d_mix/frame204`: POGO's "CPU" line pokes out under its own bubble;
     - `wk37d_mix/frame1113`: the bubble overlaps the BUTCH tag.
   - The burst is already owner-tinted and sits on the ghost, so identity is not lost for its 0.7 s.
3. **Ghost tags must not overlap each other.**
   - `wk37d_banner_after.png`: the PUFF CPU and P1 tags stack into one unreadable block.
   - In `_place_ghost_pip`, add the rects of ghost tags already placed this frame to the keep-out list (same as `_living_rects`).
     If both sides still collide, the later slot drops to `ghost_pip_near_alpha`.
4. **The ghost BAAA! word must obey the centre-banner rule too.**
   - `rec/wk37d_islands/frame1345` (STAGE_END): two ghost BAAA! bursts sit on "POGO OOPS! · BUTCH OOPS!".
   - Pass `_banner_rect()` into the ghost `WordBurst.present(...)` keep-out, or cull the ghost word when they intersect.
   - This is the same CD2-06 / WK-41 one-overlay rule the tags already follow.

### Tuning values (`src/core/Tuning.gd`, WK-37d block)

| Knob | Now | Verdict |
|---|---|---|
| `ghost_pip_scale` | 0.9333 | **keep** (28 px floor) |
| `ghost_pip_full_alpha` | 0.65 | **keep 0.65** |
| `ghost_pip_dim_alpha` (the settle alpha; it lives in the WK-37 block, l.639) | 0.50 | **keep 0.50** |
| `ghost_pip_near_alpha` | 0.25 | **keep 0.25** |

- **These values are correct once FIX #1 lands.** A light, goat-filled tag at 0.65 → 0.50 is exactly the P1 tag that already
  reads right. The problem is the plate, not the alpha. Lowering alpha on a dark plate only makes a fainter dirty box.
- **Contingency only:** if #1 is refused and the dark plate stays, use `ghost_pip_full_alpha` 0.50, `ghost_pip_dim_alpha` 0.35
  and `ghost_pip_near_alpha` 0.20. I'd grade that a weaker Fix: still muddy, but no longer louder than the ghost.

### Passes (tags)

- **Banner hide works:** `wk37d_banner_hide.png` has no tag under "BANNER TEST", and the "TWO LEFT!" frames (sheet #14, #15)
  are clean.
- Placement avoids living goats, including the flip-below in `wk37d_park.png`.
- Text size is 28 px.
- Every ghost is identifiable under deut, prot, tritan and greyscale (R3 identity, which was the WK-37c failure, now passes).

## SHIP: islands_void readability

- **The lift is subtle, and that is correct.**
  - Sampled on the P1 ghost over the field: centre RGB (191,178,168) off → (194,173,168) on, over field (165,215,161), luma about
    0.79, so close to the full lift.
  - Up close (`p1_lift` crop, off/on), the face and rim are slightly crisper and the body is not louder.
  - The ghost is **findable when looked for** on the field, sky and cloud band in every islands frame (sheet #1-#10,
    `wk37d_lift_*`, `wk37d_bright_ab.png`). It recedes beside the saturated living goats. That is the brief's intent.
- **Wide zoom:** `wk37d_wide_ref.png` (left) keeps the body findable with no size jump. The eased wide factor showed no snap in
  the stills I have; I can't check motion without a run.
- **Keep** `ghost_bright_alpha_max` 0.50, `ghost_bright_lum_lo` 0.62, `ghost_bright_lum_hi` 0.82, `ghost_wide_alpha_mult` 1.3.
  **Do not raise any of them.** After FIX #1 the tag is the "where is it" cue, and the body should stay a 0.40-0.50 presence.

## Notes (not blocking, track only)

- **PUFF ghost hue over sky:** its ghost reads **mint/teal** over the blue sky (`sky_ab` frames, `wk37d_bright_ab.png` top),
  because 40 % yellow over cyan blends to green. Identity is carried by the tag now; this is expected alpha blending, not a bug.
  Revisit only if the Phase B ghost art (A5) lands and PUFF still reads green.
- **Tag over platform art:** a ghost tag that flips below can sit across platform art (`wk37d_lift_islands_void_field_on.png`,
  PUFF). It is minor at 0.50, but if it shows up in the next sheet, weight platform rects lightly in the side choice.
- **Next regrade:** an R1 sheet plus squint after FIX #1-#4, plus 3 frames picked right after `bleated` events. Pass bar: in the
  squint sheet, no bot ghost reads as "rectangle + smudge"; its tag should weigh the same as the P1 tag.
