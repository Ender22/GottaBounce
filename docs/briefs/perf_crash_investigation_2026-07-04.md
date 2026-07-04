# Foundation-health investigation — fps 79→28 + native crash ~12 stages (2026-07-04)

> STATIC root-cause (read-only, no launch). Two PRE-EXISTING bugs surfaced during the kill-shape QA,
> neither caused by it. Empirical confirmation (needs the port) + fixes are the follow-up. This is the
> current TOP priority (foundation health before more features — a crashing 28fps game can't be
> feel-validated).

## Baseline anchor
79 fps / 28 draw calls = `fdda24f` (session-1: DevArena + Toybox renderer, NO PartyMatch dynamic
camera / powerups / damage overlay / pit-void / edge indicators / 2× grassy_expanse). Neither 120 Hz
physics nor gl_compatibility is the regression (both present since commit 1) — they are cost amplifiers.

## BUG 1 — fps 79→28, ranked suspects (confirm via gbplay perf)
1. **Draw-call/overdraw explosion (highest).** ~150-250 canvas items/frame vs the golden 28, many
   breaking 2D batching via additive `CanvasItemMaterial`/distinct textures. Sources: pit-void ~26
   nodes/stage incl. a PERMANENTLY-emitting additive `motes` CPUParticles2D (ArenaRenderer.gd:590-612);
   full parallax background always drawn over the 4880×4308 2× arena (sky Sprite2D scaled to MAX_VIEW*1.1
   :100-116, hills/clouds/twinkles/props); per-platform ThreeSlice sprites (dozens per wide floor,
   ThreeSlice.gd:66-80) + ~11 tufts/floor + decals; per-player additive exhaust×2 + fuse Line2Ds ×4;
   per-bounce `_ring_flash` additive Line2D + Juice additive bursts.
   Confirm: perf on dev_arena vs grassy_expanse; then with paint_void disabled (skip "void" in
   LevelLoader:55-58); then with _build_background early-returned.
2. **Dynamic camera every PHYSICS tick (120Hz) + forces full-2×-background redraw.** _update_camera
   called from _physics_process (PartyMatch.gd:224-240 → 775-879): loops players, nearest_opponent O(n),
   allocs living/cluster arrays, changes zoom+pos every tick → the oversized background is always
   on-screen, no frame-to-frame stability. Did not exist at baseline (added c6229c4, intensified e663427).
   Confirm: eval `_camera.dynamic=false`/pin, read perf; gate _update_camera to every 2nd tick.
3. **120Hz amplifies all newly-added per-tick sim** (NOT the regression, but compounds): 4× Player
   _physics_process (move_and_slide, get_slide_collision loop, _handle_smashes get_overlapping_bodies,
   a per-player raycast every tick _update_contact_shadow:1122-1125), PowerupSystem, StormBalls.
   Confirm: TIME_PROCESS vs TIME_PHYSICS_PROCESS. If physics dominates, test 60Hz in a scratch run
   (owner decision — feel-affecting, do NOT commit).
4. (low) per-frame allocs: 29-pt PackedVector2Array rebuilt while aiming (Player.gd:1102-1106); intent
   alloc when stunned (:357). Minor.
Ranking: #1 draw-calls ≳ #2 camera+2×bg > #3 sim amplification ≫ #4 allocs. Some drop is legit
(2× arena + more systems) but 79→28 is too big to be only content.

## BUG 2 — native crash ~12 combat stages (hard exit, no GDScript error), ranked
Framing: 50 PURE reloads were clean → accumulation is driven by COMBAT + per-stage rebuild, not load.
Stage rotation keeps PartyMatch/players/HUD/camera/Juice/PowerupSystem alive, swaps only _level_root
(PartyMatch.gd:211-214).
1. **Per-stage GPU texture/RID creation in the rebuilt ArenaRenderer (top suspect — best fit for
   native/no-error/~12-iter).** _load_stage builds a NEW ArenaRenderer each stage (LevelLoader.gd:29-32)
   whose _build_background creates new GPU textures every stage: `_feathered_texture`→ImageTexture.
   create_from_image for hills (ArenaRenderer.gd:265-284, called 122-124); paint_void→GradientTexture2D
   (:549-555); _extend_below/_feathered do get_image()+decompress()+per-pixel loops each stage. RefCounted
   (should free on old-renderer queue_free) but deferred-free + gl_compat driver + 12 rebuilds is exactly
   where native VRAM/RID growth hides.
   Confirm (decisive): after each stage eval `RenderingServer.get_rendering_info(RENDERING_INFO_TEXTURE_MEM_USED)`
   + texture counts across 12 stages; monotonic climb (no plateau) = confirmed. Likely FIX: cache/reuse
   the theme background textures across same-theme stages, or don't rebuild the whole renderer per stage.
2. **Physics-RID churn from StormBalls/powerup bodies during combat** (StormBall.gd:21-51 spawned
   PowerupSystem.gd:225-235, added to PartyMatch not _level_root; rely on self-despawn + round_sweep
   group-free PartyMatch.gd:617-619). Combat-only, invisible to reloads.
   Confirm: get_orphan_node_count() + OBJECT_NODE_COUNT + PHYSICS_2D_ACTIVE_OBJECTS after each stage;
   assert group "pu_field" size==0 right after STAGE_END. (match-end path :654-672 does NOT sweep — fine
   for game-over, but verify SD→stage always sweeps.)
3. (lower) transient combat FX (Juice/PowerupSystem/ring_flash) added to current_scene, freed by
   timers/tweens — self-cleaning but pile up under heavy combat.
Cleared low-risk by inspection (state, don't chase first): EventBus connection accumulation (only
per-stage subscriber is ArenaRenderer:60, Godot4 auto-disconnects on free — cheap check:
`EventBus.surface_bounced.get_connections().size()` should stay ≈1 across stages; if it climbs, the old
renderer isn't being freed → re-rank #1); void node IS freed (child of _level_root); players/HUD/nametags
created once, not per-stage.
Decisive single confirmation: watch TEXTURE_MEM_USED + get_orphan_node_count() across 12 stages/session.

## git-bisect plan (measure gbplay perf fps+draw-calls, oldest→newest; record which scene each boots)
fdda24f (~79/28 anchor, DevArena) → a8de63c (round loop/HUD) → cdd925d (powerups+FX) → 03894ac
(lethality) → c6229c4 (wider bounds + FIRST dynamic camera) → d767262 (2× grassy primary) → e663427
(camera-at-2x heavy _update_camera) → 7c2bb7f (pit-void) → HEAD(64af1b8 ~28). Expected big steps:
d767262 (2× bg), e663427 (per-tick camera), 7c2bb7f (void), cdd925d (additive FX).

## Speculation flags
Magnitudes are code-inferred, not measured (read-only). Crash suspect #1 (texture-RID growth) is a
hypothesis consistent with the symptom; the in-engine texture-mem/orphan trend is the decisive test.
