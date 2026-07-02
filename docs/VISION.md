# GottaBounce — Vision & Creative Direction

> Owned by the Studio Director. Changes here are deliberate and rare.

## One-liner
A frantic couch/online party brawler where round jetpack critters **never stop bouncing** —
aim your boosts, smash rivals off the screen, last one flying wins. **Duck Game × Smash Bros, no guns.**

## The fantasy
You are an adorable, slightly unhinged balloon-animal with a jetpack strapped to its back.
Everything is a trampoline. Death is a punchline. Rounds are 10–30 seconds of screaming chaos
with your friends, and "one more round" is always true.

## Design pillars (inviolable — inherited from the GDD, re-affirmed)
1. **Low floor, high ceiling** — learn in 5 seconds, master for weeks (fuel economy, super-boost aim).
2. **Constant motion** — every surface bounces or kills. No standing, no camping, ever.
3. **Emergent physics comedy** — the game tells the jokes (chain reactions, ragdoll launches).
4. **Death is cheap and funny** — sub-2s to next action; getting launched makes you laugh.
5. **Readable chaos** — track 4–8 players mid-storm. Readability beats prettiness.
6. **Personality everywhere** — squash & stretch, faces, taunts, reactions.

## Art direction — "Glossy Toybox"
The look of the (genuinely good) generated title screen, applied to everything:
- **Characters:** round blob critters ("Bouncers") with big expressive faces, tiny limbs, chunky
  jetpacks. Sphere-shaped so the circle collider matches the art and squash/stretch reads huge.
- **World:** saturated, high-contrast toy-world — glossy trampolines, candy-colored springs,
  chunky grass-topped platforms, soft painterly skies. Every theme reads like a playset.
- **VFX:** thick white cartoon streaks, star pops, confetti bursts; bold silhouette readability.
- **UI:** chunky rounded cards, glossy bevels, oversized type. Never OS-default widgets.
- **Reference images:** `assets/reference/` (title screen from v1 = the north star).
- **Why this works for an AI studio:** blobs are the most consistently generatable character shape;
  poses are cheap variations; style stays coherent across ChatGPT generations with a ref sheet.

## Scope target (Steam launch quality)
- **Party mode** (the product): 4–8 players local + bots, first-to-10 rounds, themed circuits.
  Target **60+ arenas across 6+ themes**, 15–20 powerups, 8+ playable Bouncers.
- **Solo/duo Campaign** (the retention layer): challenge gauntlets + arena fights + bosses.
- **Bots that are actually fun to fight** at 5 difficulty levels.
- Full controller support, rebindable input, juice everywhere (hitstop, shake, announcer).

## Risk plan (decided upfront)
- All feel constants in `Tuning.gd`; live-tunable while the game runs (via gbplay eval).
- Levels are JSON data with theme + geometry separated → art/scale/feel changes never orphan content.
- Arena geometry supports parametric generation later (chaos/density/theme dials) if we need volume.
- Every art asset generated against a persistent style-reference sheet so the set stays coherent.
