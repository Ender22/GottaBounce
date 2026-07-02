# Placeholder Asset Kit — GottaBounce v0

> **Purpose:** throwaway, CC0 placeholder art so the v0 prototype can prove the core
> bounce/jetpack/smash loop is fun **before final art exists** (see `GAME_DESIGN.md` §12).
> Final art direction is Yulia's call (leaning cute-animal / Cult-of-the-Lamb-ish); this kit is
> deliberately disposable.
>
> **Every asset here is CC0 / public domain** — commercial-safe, no attribution required.
>
> **Art-direction principle for this kit:** stay in ONE cohesive style — Kenney's modern
> **bold-outline chunky cartoon** (the "New Platformer Pack" family). Cute, high-contrast,
> readable in 4–8 player chaos, and resolution-independent (SVG vector source included).
> We intentionally did NOT mix in the older, flatter "Platformer Art" series (see Excluded below).

## Folder map (all CC0)

| Folder | Role | Source pack |
|---|---|---|
| `newplatformer/` | **PRIMARY** — characters, terrain tiles, spring, enemies, sounds, **SVG vectors** | Kenney New Platformer Pack |
| `bounce_blocks/` | squishy rounded blocks = distinct **bounce surfaces / blocks** (ignore the faces) | Kenney Shape Characters |
| `jetpack/` | **the jetpack** (separate code-rotated sprite) + flame + spring | Kenney Jumper Pack |
| `physics/` | **balls** (Ball Storm powerup) + crates/physics props | Kenney Physics Assets |
| `particles/` | jetpack exhaust + super-boost burst (flame/fire/smoke/muzzle/spark) | Kenney Particle Pack |
| `ui/` | HUD + menus: **slider = fuel gauge**, **stars = point pips**, panels/buttons (Phase 2) | Kenney UI Pack |
| `icons/` | powerup + gamepad/interface icons (`icons/expansion/` = gamepad set) | Kenney Game Icons (+ Expansion) |
| `_backup_pixeladventure/` | FALLBACK pixel kit (animated chars + tiles + hazards + sfx) if cartoon look is rejected | Pixel Frog Pixel Adventure |

## Sources (all CC0 1.0 Universal)
- New Platformer Pack — https://kenney.nl/assets/new-platformer-pack
- Shape Characters — https://kenney.nl/assets/shape-characters
- Jumper Pack — https://kenney.nl/assets/jumper-pack
- Physics Assets — https://kenney.nl/assets/physics-assets
- Particle Pack — https://kenney.nl/assets/particle-pack
- UI Pack — https://kenney.nl/assets/ui-pack
- Game Icons + Expansion — https://kenney.nl/assets/game-icons , https://kenney.nl/assets/game-icons-expansion
- Pixel Adventure (backup) — https://pixelfrog-assets.itch.io/pixel-adventure-1

## How it maps to GottaBounce mechanics

### Characters (`newplatformer/Sprites/.../character_<color>_*`, 128×128, + SVG in `newplatformer/Vector/`)
5 colors (beige/green/pink/purple/yellow) → **instant 5-player ID, no recoloring**. Poses:
`idle`, `front`, `jump`, `duck`, `hit`, `walk_a/b`, `climb_a/b`.
- **fly / airborne idle** → `idle` / `front`
- **boost** → `jump` (or code lean-tilt)
- **just-got-hit / launched** → `hit` ✓ (the reaction that sells "death is a punchline")
- **celebrate / win** → reuse `front` or `duck` + a code hop/scale-pop (no dedicated win pose)
- **squash-stretch + launch tumble = CODE** (node scale/rotation), not frames — see `GAME_DESIGN.md` §10/§4.6.

### Surfaces / tiles
- `newplatformer/` terrain tiles + **`spring` / `spring_out`** (animated high-tier bounce).
- `bounce_blocks/` (Shape Characters) — discrete squishy blocks; use shape/color to telegraph
  bounce tiers (marshmallow/bubblegum/trampoline/spring). Discrete props, not seamless terrain.

### Jetpack (`jetpack/`) — **real art now**
`jetpack.png` (+ `jetpack_item.png`, `powerup_jetpack.png`, `flame.png`). Wire per `GAME_DESIGN.md` §12:
**separate child sprite, rotated in code** to aim thrust; exhaust = particle emitter at the nozzle.
(Old hand-generated placeholder kept in `jetpack/_generated_backup/`.)

### Hazards
`newplatformer/` enemies + saw/spikes; `physics/` crates for breakables. Spikes = instakill (§4.5),
saw = moving-threat placeholder for the swinging hammer, etc.

### Powerups / props
- **Ball Storm** → `physics/` balls. Other powerup icons → `icons/`.

### Particles (`particles/`)
`flame_0X`/`fire_0X` = thrust flame; `smoke_0X` = trail; `muzzle_0X`/`spark_0X` = super-boost burst.
Emit opposite thrust direction (§4.2).

### HUD / UI (`ui/`)
v0 minimal HUD: **slider/bar = per-player fuel gauge**, **stars = point pips** (§10). Rest of the
pack (panels, buttons, tabs, dropdowns) is for Phase-2 menus — staged so Fable isn't blocked later.

### Sounds
`newplatformer/Sounds/` (`sfx_bump`/`sfx_jump`/`sfx_jump-high`/`sfx_hurt`/`sfx_disappear`/…) cover
bounce/boost/impact/ring-out. More impact/interface SFX in `_backup_pixeladventure/sfx/`.

## Deliberately EXCLUDED (style-cohesion decision)
The older **Platformer Art** series — Extended Tileset, Platformer Art Deluxe, Extended Enemies,
Requests, Mushrooms — is a flatter, older style that would clash with the bold-outline primary and is
largely redundant. Skipped on purpose. If more tile variety is ever needed, pull ONE of these and
accept the older look (mushroom platforms are the most tempting for a bounce theme).

## Known gaps (intentional for v0)
- **No dedicated boost pose** → use `jump` or code lean-tilt.
- **No win/celebration anim** → fake with code hop + scale-pop, or add real art later.
- Characters are cute *blob-creatures in helmets*, not animals — final animals are Yulia's call.
