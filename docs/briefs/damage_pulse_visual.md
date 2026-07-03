# Art Ruling — Cross-Skin "Damaged" Pulse

> Author: Art Director. Status: **FIX** (current `Color(1,g,g)` multiply is rejected as-is).
> Scope: the on-body damage read from `docs/specs/v0_kill_zone_recovery.md §12`.
> Grades from: `tools/out/dmg_pulse_states2.png` (3 skins mid-pulse), `tools/out/lv2_trough_6.png`,
> `tools/out/pink_lv2_a.png` / `pink_lv2_b.png`. Code: `src/entities/Player.gd` `_update_visual`.
> The programmer implements this verbatim; I re-grade from in-game screenshots of all four skins.

---

## Verdict: FIX

The intent is right and the pink result is genuinely good — `lv2_trough_6.png` / `pink_lv2_*`
read as a clean crimson flush that says "hurt, chase me." Ship the *behavior* (slow Lv1 throb,
fast Lv2 flush, on-body, no HUD). **Reject the mechanism.**

`_sprite.self_modulate = Color(1.0, g, g)` is a **multiply**. Multiply can only ever *subtract*
green and blue — it cannot *add* red. So it works on pink (a sprite that is already mostly red
channel: darkening G and B leaves red = crimson) and fails on every cool/mixed skin:

- **Blue** (`bouncer_blue_idle`, body ≈ `#3E73F2`): red channel is low, so `Color(1,g,g)` just
  scales down G and B → a **muddy dark navy**. `dmg_pulse_states2.png` confirms it reads as
  "in shadow," not "bleeding red."
- **Green** (`bouncer_green_idle`, ≈ `#9BD91F`): dulls to **olive/khaki** — reads as "dirty,"
  not "hurt."
- **Yellow** (`bouncer_yellow_idle`, ≈ `#FFD21A`): dulls to **mustard/brown** — reads as "dim."

A red damage state that only reads on 1 of 4 skins fails Pillar 5 (readable chaos — you must be
able to spot the vulnerable player of any color across the arena) and is an automatic Fix.

---

## The fix: an ADDITIVE-position red overlay that LERPS the body toward crimson

Not additive-blend (a red *add* blows blue→magenta, green→olive, yellow→white — inconsistent).
Not multiply (the current bug). The one operation that yields the **same red on any base color**
is **lerp the body toward a fixed crimson**: `result = base·(1−a) + crimson·a`. That is exactly
what a solid-crimson **Sprite2D overlay of the same silhouette, drawn on top at normal
(alpha) blend**, does. Pulse the overlay's alpha `a`; the base skin only controls how far it has
to travel, and at peak every skin lands on the same red-orange. Whole-body color change is also
the single most readable damage cue at 25–30 px (Pillar 5) — far better than a rim or an emblem,
which vanish at that size.

Checked math at Lv2 peak (`a = 0.70`, crimson `#E32020`):

| Skin | base ≈ | result at a=0.70 | reads |
|---|---|---|---|
| Pink | `#FF73A6` | `#E0385C` | deep rose-red |
| Blue | `#3E73F2` | `#B33A5E` | red-maroon (was blue) |
| Green | `#9BD91F` | `#CC5722` | red-orange |
| Yellow | `#FFD21A` | `#EB571F` | red-orange |

All four converge to red/red-orange at the peak and pulse back toward their own hue at the
trough — an unmistakable, color-independent "flushing red" throb. This is the whole ruling.

### Why not the other candidates (for the record)
- **Pulsing red rim/outline:** dies below ~2 px at gameplay zoom; the chocolate outline already
  owns the silhouette. Reject for v0.
- **Damage emblem/decal, sweat/anger marks (Pillar 6):** don't read at 25–30 px and add clutter
  during a storm (Pillar 5 loses). Fine as a *close-up* Lv2 garnish in a later pass; not the
  primary read. Out of v0.
- **Desaturate-toward-red via shader:** same visual result as the overlay lerp but adds a shader
  and a per-material for a state that a 20-line node change already nails. Overlay wins on cost.

---

## Implementation spec

### Node (add once, in the sprite setup near line 179–182)
Add a second `Sprite2D`, **child of `_skin_flip`, inserted AFTER `_sprite`** so it renders on top
and inherits the facing flip:

```gdscript
var _dmg_overlay: Sprite2D            # crimson damage flush (lerp-to-red), normal blend
...
_dmg_overlay = Sprite2D.new()
_dmg_overlay.texture = _idle_tex      # kept in sync each frame below
_dmg_overlay.visible = false
_skin_flip.add_child(_dmg_overlay)    # added after _sprite -> draws above it
```
Leave `_dmg_overlay.material = null` (default = normal/alpha blend — do NOT set additive).

### Drive it in `_update_visual` — replace the two `damage_level` branches
Remove both `Color(1.0, g1, g1)` / `Color(1.0, g2, g2)` lines entirely. The body sprite stays
`Color.WHITE`; the overlay does all the work. The overlay is only visible in the plain damaged
state, so it slots cleanly UNDER the existing priority (flash > rainbow > silhouette):

```gdscript
if _flash_timer > 0.0:
    _flash_timer = maxf(0.0, _flash_timer - delta)
    _sprite.self_modulate = Color(2.6, 2.6, 2.6)
    _dmg_overlay.visible = false            # white hit-flash wins
elif rainbow:
    _sprite.self_modulate = Color.from_hsv(fmod(_anim_t * 6.0, 1.0), 0.62, 1.0)
    _dmg_overlay.visible = false            # Star = invulnerable, never show "vulnerable" red
elif silhouette:
    _sprite.self_modulate = Color(0.2, 0.13, 0.28)
    _dmg_overlay.visible = false            # Black Hole silhouette wins
elif damage_level >= 1:
    _sprite.self_modulate = Color.WHITE
    # mirror the body's draw params so the overlay is a pixel-exact silhouette copy
    _dmg_overlay.texture  = _sprite.texture   # follows idle<->squash swap
    _dmg_overlay.offset   = _sprite.offset
    _dmg_overlay.scale    = _sprite.scale
    _dmg_overlay.position = _sprite.position
    var a: float
    if damage_level == 1:
        # Lv1 reeling: slow, gentle rosy throb (a 0.00 <-> 0.35)
        a = Tuning.dmg_lv1_alpha_mid + Tuning.dmg_lv1_alpha_amp * sin(_anim_t * TAU * Tuning.dmg_pulse_slow_hz)
    else:
        # Lv2 critical: fast, deep crimson flush (a 0.25 <-> 0.70)
        a = Tuning.dmg_lv2_alpha_mid + Tuning.dmg_lv2_alpha_amp * sin(_anim_t * TAU * Tuning.dmg_pulse_fast_hz)
    _dmg_overlay.modulate = Color(Tuning.dmg_tint.r, Tuning.dmg_tint.g, Tuning.dmg_tint.b, a)
    _dmg_overlay.visible = true
else:
    _sprite.self_modulate = Color.WHITE
    _dmg_overlay.visible = false
```

Note: the root-node spawn-protection blink (`modulate.a`, line 927) still multiplies the whole
creature including the overlay — correct and harmless (damage_level is 0 during spawn protect).

### Tuning constants (`src/core/Tuning.gd`)
Keep `dmg_pulse_slow_hz = 1.5` and `dmg_pulse_fast_hz = 4.0` (unchanged). Add:

```gdscript
var dmg_tint: Color        = Color(0.89, 0.125, 0.125)  # crimson #E32020 the body lerps toward
var dmg_lv1_alpha_mid: float = 0.175   # Lv1 throb centre  -> range 0.00 .. 0.35 (gentle, alive)
var dmg_lv1_alpha_amp: float = 0.175
var dmg_lv2_alpha_mid: float = 0.475   # Lv2 flush centre  -> range 0.25 .. 0.70 (deep, critical)
var dmg_lv2_alpha_amp: float = 0.225
```

Rationale for the amounts: Lv1 troughs at 0 (full skin color returns each cycle) and peaks at a
light 0.35 wash — "reeling but fine," identity still dominant. Lv2 never fully returns (floor
0.25) and peaks at a heavy 0.70 flush — always visibly hurt, hard pulse = "finish them." The
frequency (1.5 vs 4.0 Hz) plus the depth (light-throb vs hard-flush) give a doubly-redundant
Lv1/Lv2 distinction.

---

## Layering contract (must not regress)
1. **White hit-flash** (`_flash_timer`, `Color(2.6…)`) — top priority, overlay hidden. The
   moment-of-impact pop must never be tinted red.
2. **Star rainbow** — overlay hidden. Invulnerable must never wear the "vulnerable" color (it
   would be a lie and the rainbow already reads as "don't touch me").
3. **Black Hole silhouette** (`Color(0.2,0.13,0.28)`) — overlay hidden; the dark-purple
   silhouette state owns the body.
4. **Damaged (Lv1/Lv2)** — overlay visible, body sprite forced to WHITE.
5. **Normal** — overlay hidden, body WHITE.

No new color collisions: the crimson `#E32020` is distinct from the reserved bubblegum magenta
`#FF4FA3` (arena brief §2) and from the Black Hole purple. It sits on the character, never in the
world, so it does not touch the tier/background color discipline.

---

## Re-grade checklist (capture after build — all four skins, one screenshot each)
1. **Cross-skin read:** blue, green, yellow at Lv2 peak each read as clearly RED/red-orange, not
   "darker" — hold them next to the pink; if a cool skin still reads as "just dim," it's a Fix.
2. **Lv1 vs Lv2 distinct at a glance:** slow light throb vs fast hard flush, tellable in <1 s.
3. **Zoom survival:** at gameplay zoom (25–30 px bouncers, far camera) the flush still reads —
   this is the whole reason we chose whole-body over rim/emblem.
4. **Face/facing preserved:** at Lv1 trough and between Lv2 pulses the eyes, mouth and jetpack
   silhouette are still readable (chocolate outline stays dark through the overlay).
5. **No state collision:** get hit while damaged (white flash beats red), grab a Star while
   damaged (red disappears), enter Black Hole while damaged (silhouette wins) — verify each.
6. **No seam/ghost:** the overlay tracks the idle<->squash swap and the facing flip exactly (it
   copies `texture/offset/scale/position` each frame) — no doubled/offset silhouette on bounce.
