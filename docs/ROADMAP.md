# ROADMAP — from "core loop done" to "a complete game"

> Created 2026-07-05 after an owner scope-correction. The prior "GAME COMPLETE" label certified only
> the **core versus loop** (the hard ~25%). This doc is the honest path to the actual bar:
> **TowerFall Ascension / Duck Game** levels of completeness. Living doc — reorder as we learn.

## The bar (what "complete" means here)
A player launches the game and finds: a **title screen** → picks a **character** from a real roster →
picks a **mode** → picks an **arena/circuit** → tunes **match settings** → plays → can **pause** →
sees results → rematch or return. Multiple **modes** (not just one), multiple **themed circuits**, a
**character roster with identity**, and an **options** screen. Every mode showcases the thing that is
the product: **the bounce → fly → smash movement feel** (owner north star).

## What is genuinely DONE (the foundation — do not rebuild)
- Core **versus** match loop (`PartyMatch`): lives, cumulative-kills-to-N, level rotation, SD, match-end.
- Combat feel: un-charged super, SHOVE/SMASH solidity, damage system, edge-relative off-screen kills.
- Bots (human-sim, L2–L4), camera, juice, audio layer, 11 validated arenas, VFX telegraphy.
- Validation gates: parse / headless / rendered-playtest / motion-health / CD fantasy-fit.

## The ~75% that remains

### PHASE 1 — Front-end shell + match-config + mode framework  ← ACTIVE (scaffolding)
Everything else hangs off this. No new content until the shell exists.
- `GameConfig` (autoload/resource): mode, chosen characters, arena/circuit, kills-to-win, lives,
  player/bot count, bot difficulty. `PartyMatch` reads it instead of hardcoded constants.
- `Settings` autoload: options persistence (`user://settings.cfg`) — Master/Music/SFX volume,
  fullscreen; applied on boot to AudioServer buses + window.
- Scenes (.tscn + theme.tres, per CLAUDE.md): **MainMenu** (title) → **ModeSelect** → **CharacterSelect**
  → **ArenaSelect** → match, with back-nav. **PauseMenu** overlay (Esc → Resume/Restart/Options/Quit).
  **Options** panel shared by title + pause. Full keyboard + gamepad navigation.
- Mode framework: a `GameMode` contract so PartyMatch's rules (win condition, spawn logic, HUD) are
  pluggable, not hardcoded — the seam every new mode plugs into.
- Main scene becomes MainMenu, not Arena.

### PHASE 2 — Character roster (identity)
- The **goat/ram** prototype (backlog): non-circular collider + solidity-by-hit-position → a character
  that plays differently, not a reskin. Then a small roster (3–5) with distinct silhouette + feel.
- Art per character (Glossy Toybox brief). CharacterSelect wired to the real roster.
- Per-character feel deltas live in data, not code forks.

### PHASE 3 — Content: themed circuits + more arenas
- Group the 11 arenas into named **circuits**; author more to fill them. Circuit = a curated rotation
  with a theme + difficulty arc (TowerFall's arena sets).

### PHASE 4 — Additional modes (each must showcase movement feel)
- **Trials / Time-Attack** (solo skill courses — leverages the "movement courses" idea; TowerFall Trials).
- **Gauntlet / Survival** (solo or co-op vs waves of bots — TowerFall Quest-lite).
- **Sports** (bounce a ball into goals — movement as the whole game).
- **Puzzle** (single-screen "clear the room" using bounce/smash) — evaluate feasibility.

### PHASE 5 — Progression + final polish
- Unlocks (characters/arenas via play), stat tracking, audio VO + per-powerup SFX, achievements,
  final art pass on placeholders (horizontal bumper art, sunny-cluster tilesets, fonts).

## Sequencing rule
Depth-first per CLAUDE.md: Phase 1 to genuinely-good (shell you'd ship) BEFORE Phase 2, etc. Each
phase ends with a rendered playtest + CD fantasy-fit verdict, not "compiles."
