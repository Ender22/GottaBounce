# GottaBounce — Lessons Learned (for a clean rebuild)

> Written for **Fable** (or any AI) re-attempting this build from the plan stage. The design docs
> (`GAME_DESIGN`, `FEEL_REFERENCE`, `ARCHITECTURE`, `MASTER_BUILD_PLAN`) are **good — keep them.** The
> problems below were almost all in **execution**, not design. Read this before writing code.

## The one mistake that caused most of the pain
**Breadth-first, blind execution.** I built all ~18 phases (core → campaign → bosses → progression →
menus) in sequence, validating only that the code *loaded without script errors* via headless Godot.
The result: a wide, shallow skeleton that "runs" but isn't playable-good, with programmer-art UI and
debug-rectangle visuals. The owner's reaction on first play: *"feels barely at proof-of-concept."*

**Do the opposite: depth-first vertical slices, each ending in a real human playtest.** Build ONE
thing to *actually good* before widening. The original plan even said this (v0 = "prove the core loop
is fun before anything else") — the error was blowing past v0 into P6–P20 without ever stopping to make
v0 fun. **Stop at the v0 vertical slice and do not proceed until the owner says it feels good.**

## Work as a STUDIO, not a lone coder (the structural fix)
The deepest process mistake was building with a single undifferentiated voice that both made and
graded its own work — so design, art, code, and QA all collapsed into "I wrote it and it runs."
Real studios split these into **roles that check each other**: a designer plans for fun, an art
director briefs the look *before* code and grades it *after*, a programmer builds to spec, QA
breaks it and judges fun — and disagreement between them is the feature, not friction.

We now do this with **subagents as roles** (`.claude/agents/`: `game-planner`, `art-director`,
`gameplay-programmer`, `qa-tester`) and a pipeline documented in `STUDIO.md`:
`plan → art brief → build → art review + QA → owner plays`. Two principles make it work:
- **Reviewers must push back.** A role that rubber-stamps adds nothing; each grades the previous
  role's output against a written standard (spec success criteria, art brief) and can say Reject.
- **The human owner is final QA — always.** The AI loop can catch crashes, spec misses, and
  ugly UI before they waste the owner's time, but it never replaces him playing it. "It compiles"
  remains a gate, never a sign-off.

Why this matters: every concrete failure below (gamepad controlling nothing, programmer-art
menus, 2× bounce, HUD showing bots) is something a dedicated QA or art-director pass would have
caught in minute one. Separating the roles institutionalizes catching them.

## "Runs without errors" ≠ done (the core trap)
- Headless Godot (`--headless … --quit`) only proves **no parse/load crash**. It cannot test **input,
  feel, fun, visuals, UI, or audio**. I repeatedly reported "verified" when I'd only proven "doesn't
  crash." That over-stated progress massively.
- **Treat headless as a no-crash GATE, not validation.** Real validation = the owner plays it. Build in
  a tight loop: small change → owner plays → adjust. Don't batch 14 phases between playtests.
- Several real bugs (controls not wired to a player, HUD showing bots, a `class_name` colliding with a
  native class, the bounce being ~2× too high) only surfaced on the first real play — they'd have been
  caught in minute one of playtesting.

## Make it LOOK like the game from day one
- I rendered surfaces as flat colored `Polygon2D` rectangles and never wired the actual tile art.
  That alone made it read as a tech demo. **Use the real placeholder art immediately** — tiles via a
  `TileMap`/tile atlas, characters/props as the actual sprites — even in the first slice. Placeholder
  ≠ abstract; it should still resemble the intended game (the CC0 Kenney kit + the owner's Hoptron art
  are right there in `assets/`).

## UI needs real design, not default widgets
- I built menus from `OptionButton`/`SpinBox`/tiny centered `Button`s navigated by arrow keys. The
  owner (rightly) hated it. **Menus are a design surface:** a title screen with layout + cover-art
  space; **card/tile-based** selectors (Mario-Kart-style circuit & character pickers), not OS dropdowns;
  full controller navigation; readable scale. Budget real effort here — it's most of the "feels cheap
  vs polished" gap. (The owner expects to be hands-on for UI feel — collaborate, don't ship programmer-art.)

## Tuning: start gentle, expose everything, tune live
- Initial bounce ladder was far too high (basic bounce ~4–6× character height); the owner wanted
  ~2–2.5×. **Start conservative** (low chaos) and let it be dialed UP, not down.
- Put ALL feel constants in one resource (this was done — good) AND build a **live in-game tuning
  panel** so the owner can adjust gravity/bounce/boost while playing. The tuning loop is the whole
  point of v0; make it frictionless.

## Get the fundamentals right before features
Before ANY mode/progression/menu work, nail, with the owner playing:
1. **Controls** — keyboard AND controller, and a *solo* player must be able to use either. Confirm
   input actually drives a spawned player. (I shipped a default match where the gamepad controlled
   nothing.)
2. **The bounce + jetpack feel** — the make-or-break loop.
3. **Camera/framing** — the whole arena nicely on screen.
4. **One real-looking level.** Then, and only then, widen.

## Scope realism
The full game (2 modes + campaign + bosses + editor + progression + 10 powerups + gravity fields) is
**a lot** — too much to truly "one-shot." A realistic one-shot target is the **v0 vertical slice done
excellently** (real art, real controls, great feel, one polished level, basic round flow). Everything
else is follow-up phases, each its own playtested slice. Don't let the breadth of the plan pressure you
into building it all before it's fun.

## Godot 4 technical gotchas (concrete — these cost real time)
- **`class_name` must not collide with native classes** (`Container`, `Timer`, `Camera2D`, `Tween`, …).
  A `class_name Container` silently resolves to the native class in references and errors when the file
  loads. Prefix project classes (e.g. `PropContainer`) or check against the native list.
- **Autoloads can't reliably resolve `class_name` globals at parse time.** In an autoload, reference
  other scripts via `preload()`/`load()` (load at runtime if there's an inheritance chain), or avoid
  `is SomeClass` (use `is Node` + groups). This bit `PowerupSystem`/`SaveSystem`/`ProgressionSystem`.
- **The global class cache goes stale.** After adding `class_name` scripts, run the editor once
  (`--headless --path <p> --editor --quit`) to rebuild `.godot/global_script_class_cache.cfg`, or every
  `class_name` reference fails to resolve. **Run a full `--editor` parse scan as your CI gate**, not
  just per-scene loads (per-scene loads miss scripts that scene doesn't reference).
- **Don't shadow Godot virtuals** (`_set`, `_get`, `_init` signatures, `_input`, etc.). Naming a normal
  method `_set(key,val)` broke a script (clashes with `Object._set`).
- **UI on a `Camera2D`-driven scene:** put HUD/menus on a `CanvasLayer` or the camera (shake/scroll)
  drags them around. Only track what should be shown (I showed bot fuel gauges).
- **Forced-kill output noise:** when you `timeout`-kill a headless run, "Unreferenced static string to
  0" and "Pages in use at exit" are shutdown artifacts, not bugs.
- **Bot/AI must not cheat and must be wired as an input provider** (it was) — but verify it actually
  produces sensible play by *watching it*, not by "it ran 8s without erroring."

## What was actually good (keep doing)
- The upfront design docs + architecture seams (gravity-as-field, body-agnostic bounce, one
  radial-impulse, kill pipeline, JSON levels, InputIntent) — these held up; adding gravity fields and
  physics props was genuinely additive with no rewrites. **The seams were right.**
- One commit per phase (easy rollback).
- Using the owner's own Hoptron assets for music (owned, retro, zero licensing) — check for owned
  assets before sourcing.

## TL;DR for the rebuild
Keep the docs. Build the **v0 vertical slice** — real tiles, real character, working kb+pad controls,
good camera, dialed-in gentle bounce feel, one nice level, minimal round loop — and **make the owner
laugh while playing it before writing a single line of campaign/menus/progression.** Validate by
playing, not by "it compiles." Then expand one playtested slice at a time.
