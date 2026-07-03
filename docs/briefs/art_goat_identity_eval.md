# Art Director Brief — Goat Identity Evaluation

Evaluating: docs/feedback/owner_2026-07-02_movement_feel.md "crazy goats" seed vs the shipped
Glossy Toybox blob Bouncers (docs/VISION.md, assets/CATALOG.md). Source screenshots reviewed:
tools/out/grade_far.png, tools/out/toybox_close1.png, tools/out/lethality_aim.png,
tools/out/qa3_fight_02_super_right.png, tools/out/qa3_combat_first_look.png.

## Verdict: ADOPT-STAGED

Goat horns are a genuine, cheap, on-brand upgrade to the super-boost identity — but they are not
worth touching until the un-charged super/lethality mechanic itself is validated in-engine. Do not
spend art budget on this before the movement-course + lethality work proves the "fly head-first
into people" fantasy is fun. Horns amplify a working mechanic; they cannot fix a not-yet-tuned one.

## 1. Does it strengthen the core fantasy?

Yes, directionally. The owner's thesis is that the super boost is a head-first missile and the
game's only reliable kill. Right now the Bouncers are legless balloon-blobs with no directional
"pointy end" — in `qa3_fight_02_super_right.png` the pink Bouncer mid-super reads only as "a ball
moving right," not as "a creature charging horns-first." A horn pair sitting on the leading
silhouette edge gives the super boost a readable **weapon tip**: the player aiming it sees exactly
where the point of impact will be, and the victim sees the thing that's about to hit them. That is
a genuine readability + fantasy win tied directly to the mechanic the owner cares about most, not
theming for its own sake.

It also answers pillar 6 (personality/humor) better than a generic blob: horns down + a scream on
fire is a complete, self-explanatory sight gag with zero UI cost, and it pays off pillar 4 (death
is cheap and funny) when the attacker face-plants into a wall after a whiff.

## 2. Style compatibility — does it demand a pivot?

No pivot needed. This is the important finding: "goat" does not have to mean a new anatomy
(hooves, fur, legs, snout). The minimal-delta version is:

- Keep the exact existing sphere body, big cartoon eyes, tiny stub arms/feet, jetpack — everything
  that makes the character AI-generatable and collider-matched (VISION.md's stated reason blobs
  were chosen).
- Add: two small curved horns on the forehead (glossy-toybox rendering — same thick outline,
  same plastic-shine highlight language as the jetpack nozzles), and optionally light chin-fuzz
  as a 1-color shape under the mouth (skippable if it hurts the silhouette at small size).
- Everything else — palette, outline weight, shine placement, squash/stretch rig — is unchanged.

This is a **decoration pass on the existing ref sheet**, not a new species. It stays inside Glossy
Toybox and inside the "blobs are AI-generatable" constraint the studio chose blobs for.

## 3. Cost / risk

**Asset regeneration list (minimal-delta goat pass):**
| Asset | Change | Effort |
|---|---|---|
| `characters/bouncer_{pink,blue,green,yellow}_idle.png` (4) | add horns to forehead | 4 gens + intake, ~1 gen each (low retry risk — additive edit to existing ref) |
| `characters/bouncer_pink_squash.png` (+3 colors) | add horns, consistent with idle | 4 gens |
| New: `bouncer_*_super_aim.png` (aim/frozen-hover pose, 4 colors) | horns forward, eyes narrowed/determined, needs to exist regardless of goat verdict once un-charged super ships (currently no distinct aim art — lethality_aim.png shows the plain idle sprite during aim) | 4 gens, NEW pose not just a horn add-on |
| New: `bouncer_*_super_impact` or reuse squash | horns-first "spike" pose on hit | optional, can defer/reuse squash frame |
| Tumble/ragdoll frame(s) | unchanged by goat theming | no new cost from this decision |

Rough total: **8 required regenerations** (idle+squash x4 colors) if going with the minimal delta,
using the same ChatGPT pipeline and prompt pattern already proven in assets/CATALOG.md ("attach
existing sprite, ask for the same character, same style, now with small curved horns"). This is
low-risk, cheap, and reversible — consistent with how the other 22 assets were produced.

The **aim-pose gap is a separate, mechanic-driven cost that exists independent of goat theming**:
once the super boost becomes un-charged with a ≤2s aim-hover (per docs/DECISIONS.md), the game
needs a distinct "aiming" sprite regardless of horns, because currently the aim state reuses idle
art (confirmed in `lethality_aim.png` — the pink Bouncer mid-aim looks identical to standing
still). Don't let the goat decision block that pose from being commissioned when lethality art
needs land; commission it goat-ready from the start to avoid a second regeneration pass.

**Readability at gameplay zoom — the real risk.** At `grade_far.png` zoom, Bouncers are ~25-30px
tall on a 1280-wide frame. The existing face (two eye dots + smile) already sits near the legibility
floor — it reads, but just barely, and mostly by color+silhouette-shape, not by detail. Horns add
detail on TOP of an already-small silhouette:
- Horns must be large and high-contrast enough to survive 25px scale, or they'll disappear into
  antialiasing and just look like a slightly taller, lumpier head — worse than no horns (visual
  noise without payoff).
- Horns must NOT break the sphere-collider-matching silhouette the studio relies on for hitbox
  read. Keep them inside a bounding capsule extension at the top, not flaring wide, so the
  character still reads as "the same size ball" at a glance.
- Test requirement before shipping: a real in-engine screenshot at `grade_far.png`'s exact zoom
  with all 4 colors on screen simultaneously, graded for whether horns are still distinguishable
  from hair/ear-like noise. If they wash out, thicken the outline and shorten/simplify to a single
  bold triangle-horn per side rather than a curved goat horn.

## 4. Audio note

Goat scream on super fire is cheap, reversible, and fully separable from the visual bet. It can
ship independently of any sprite work — sound design has no dependency on horns existing in the
art. Recommend treating it as a standalone audio ticket, gated only on the un-charged super
mechanic landing (need a discrete "super fired" event to hook the SFX to), not on this art
decision. Evaluate/produce it whenever the lethality spec's super-fire event exists in code.

## 5. Staging / trigger point

**Do not adopt now.** Sequence:

1. Ship & QA `docs/specs/v0_combat_lethality.md` (un-charged super, two-tier contact model) —
   already in flight.
2. Build and run the movement courses (`docs/specs/v1_movement_courses.md`) and get a human feel
   verdict that the super-boost-as-kill-move fantasy is actually fun. This is the owner's own
   validation method (docs/DECISIONS.md, movement courses = tuning instrument).
3. **Trigger to revisit this brief:** once (1) and (2) pass and the aim-pose art gap above is being
   commissioned anyway (because un-charged super needs it regardless of goat verdict), fold the
   horn delta into that same art pass — it's a near-zero incremental cost at that point since new
   sprites are being made either way.
4. If the feel verdict from the movement courses is negative or the super mechanic gets redesigned
   again, re-run this evaluation — don't lock in horns against a fantasy that might still change
   shape.

Reject condition (would flip this to Reject rather than Adopt-staged): if movement-course testing
shows the super boost is NOT the fun part of the game (e.g. normal bounce-chaining turns out to
carry the fun and supers stay a rare panic button) — then horns tied to super identity lose their
justification and the studio should not spend the 8-asset regen on it.

## Minimal-delta visual concept (for whoever builds this later)

Keep the current bouncer_*_idle.png silhouette exactly as-is. Add:
- Two small glossy horns, same outline weight and shine-highlight style as existing art, mounted
  symmetrically on the upper-forehead, curving slightly back (not forward-jutting past the head's
  bounding circle at rest — the super-aim pose is where they should look weapon-like, pointed
  toward the travel direction).
- Palette: horns render in a warm off-white/bone tone (`#F2E6D0`-ish) with a thin dark-chocolate
  outline (matches existing outline color used across all assets) — do not tint horns per-player-
  color; keeping them neutral keeps 4-player-color read intact (player color = the ball, horns =
  the accessory, same pattern as the jetpack already being a neutral metallic-orange across all
  colors).
- Aim-pose (new, mechanic-driven): horns tilted forward along the aim vector, eyes narrowed,
  small motion-line/anticipation squash — this is the pose that needs to exist for lethality
  regardless of the goat verdict; build it goat-ready.
