# STATUS — current state & next steps

> The single always-current handoff doc. Update after EVERY commit. A fresh context reads this first.
> Durable history/rationale lives in `docs/DECISIONS.md`, `docs/specs/`, `docs/briefs/`,
> `docs/feedback/` — this file is a lean current-state snapshot, not a session log.

**Last updated:** 2026-07-04 (flagship islands-over-void arena + full audio system shipped).
Everything below is committed (git log = history).

## Where we are
The game is a **lives-based, Duck-Game-style kill-race**: no round timer; each player has lives
(default 1); stages end by last-one-standing; players race to a cumulative **10 kills across
frequently-rotating levels**; sudden death = a true simultaneous double-KO only. Combat is
bounce → fly (jetpack REQUIRED to traverse) → **un-charged super-smash (the kill move)** → recover,
with a **transient damage system** (Lv1 slow red pulse / Lv2 fast, +33%/+66% launch, 8s heal) and
**edge-relative, off-screen kills** (near-edge dead-on = out; mid-stage healthy survives = the
recovery gamble). Foundation is healthy (the "crash + 28fps" scare was refuted — see Watch-out).
**CURRENT FOCUS:** 10-LEVEL CIRCUIT COMPLETE (all in-engine validated): islands_void, grassy_expanse,
drop_chamber (enclosed drum), the_spine (ridge), twin_chasms (two-void), the_cliff (asymmetric mesa),
atoll (radial well), spires (verticality), bumper_gauntlet (interior pinball), the_ascent (dual vertical
blast). Backdrop infra: reusable `enclosed` + `open_sky` modes. NOW (owner-flagged, PRIORITY): bots
head-bang platform undersides (downward-only nav, no overhead sensing) → obstacle-aware ascent fix +
a **bot-motion-health probe** (stuck/underside-bounce/blocked-ascent metrics in the QA feed) to catch
motion pathologies automatically. THEN: batch theming/grading pass + circuit-wide QA (with motion-health).

## What exists (committed + validated)
- **Match:** `PartyMatch` kill-race state machine (STAGE_INTRO→COUNTDOWN→COMBAT→STAGE_END→next|MATCH_END;
  SD only via double-KO), lives, cumulative-kills-to-10, level rotation (shuffle-bag), match-end panel.
- **Combat:** un-charged super (aim→blast, drain-all), two-tier SHOVE/SMASH with **hit-solidity**
  launch (dead-center flies / glance spins), damage system (Lv1/Lv2 + cross-skin crimson pulse —
  verified on all skins), edge-relative off-screen kills, ring-out credit (6s window), §2.3a dry-reflect.
- **Bots** (`InputBot`, human-sim, never cheat): refuel-rhythm, dodge-super, 1v1 **finisher**
  (closes the endgame at scale), **chase-the-wounded**; L2/L3/L4 shipped. (FLEE-to-heal is specced
  but only partially effective — see next steps.)
- **Arena/render:** `islands_void` = **FLAGSHIP** (LEVEL_POOL primary): 4 separated islands + 2
  boost-only spring thrones over one full-width lethal void; flight REQUIRED (680px gaps > spring
  drift, pads > spring apex — verified fuel=0 falls in). `grassy_expanse` (2× wide, central-pit
  variant) = secondary pool entry. Glossy Toybox renderer; **camera-at-2x** (0.60 zoom floor,
  action-cluster framing, off-screen edge chevrons). `dev_arena` = deprecated "mini" (out of pool).
- **Audio:** `AudioManager` autoload (INV-12 subscriber, pooled voices, read-only thrust poll) +
  Master→Music/SFX bus layout; 23 SFX in `assets/sfx/` (sourced from SamuraiRobot lib); 9 EventBus
  flow/feedback signals wired (bounce/smash-by-solidity/super/damage/heal/pickup/countdown/announcer/
  win) + gameplay/scoreboard music. Live-verified (408 SFX fired in COMBAT). Follow-ups: UI-click
  unwired (no button .tscn yet); per-powerup activate SFX + real announcer VO are polish.
- **Studio:** roles in `.claude/agents/` incl. **creative-director** (fantasy-fit gate);
  `docs/GAME_ESSENCE.md` (every role runs the fantasy-fit check); validation via `tools/run_game.ps1`
  + `python tools/gbplay.py`.

## Read order on fresh context
`docs/STATUS.md` (this) → `docs/VISION.md` → `docs/GAME_ESSENCE.md` → the recent owner directives in
`docs/feedback/` (2026-07-03 lives/damage/kill-race + arena-size; **2026-07-04 arena-variety+audio**)
→ `docs/DECISIONS.md` (newest-first) → specs: `v1_party_killrace.md`, `v0_kill_zone_recovery.md`
(+ `v1_kill_economy_at_scale.md`, `v2_kill_shape_edges.md`) → `docs/PIPELINE.md`.

## NEXT STEPS in priority order
1. **Bot overhead-pathing fix + motion-health probe** (owner-flagged, IN PROGRESS): stop head-banging
   (obstacle-aware ascent — probe up, detour laterally around overhead platforms); add stuck/underside-
   bounce/blocked-ascent metrics to the QA feed as a permanent motion-pathology gate. Then update QA
   doctrine so QA WATCHES motion + reads motion-health (not just outcome stats) — task board #23/#24.
2. **Batch theming/grading pass** on the 10 levels (`circuit_theming_plan.md`): apply per-level
   backdrop+sky palettes (open_sky/enclosed), art-director grades in-engine for readability (blue-vs-blue
   sky, yellow-vs-amber, green-vs-teal), tune hexes. Makes the circuit LOOK as varied as it plays.
3. **Circuit-wide QA** on the rotation (now with motion-health): pacing/feel/CD across all 10 levels.
   Watch: the_ascent 316s stall outlier; per-void-level uncredited% judged RELATIVE to flagship (~44%
   under all-bot melee is normal), not the absolute ≤12%.
4. **Backlog / stretch:** moving-hazard feature + wrecking_yard (11th level, #22); bot flee-to-heal;
   goat/ram shape prototype; P2 ring-out credit-window inflation review; whiff-arrest fix
   `v1a_super_whiff_safety.md` (OPTIONAL — CD #5 ruled the whiff acceptable).
- **Audio follow-ups (non-blocking):** wire UI-click SFX when a button .tscn exists; per-powerup
  activate SFX + real announcer VO (polish). (Void dirt-walls + `_classify_blast_edge` void-floor
  labelling are DONE — see git.)
- Optional polish backlog: louder damage-pulse at combat zoom; the STATUS-historic art-fix list
  (far-zoom mat, real font, skull icon, FX particles, black-hole vignette) — see git history if needed.

## Watch out for (hard-won)
- **The "native crash ~12 stages" + "fps 79→28" were BOTH REFUTED (2026-07-04) — do NOT chase them.**
  Crash = almost certainly ZOMBIE Godot processes eating VRAM under gl_compatibility (operational, not
  code) → always launch via `tools/run_game.ps1` (kills strays) + assert a single instance before long
  runs. "28fps" = Windows throttling the UNFOCUSED QA window; true fps is 300-1000+, physics is fixed
  120Hz DECOUPLED from render (never corrupts sim/feel). Full record: `docs/briefs/perf_crash_
  investigation_2026-07-04.md` (annotated REFUTED). LESSON: confirm hypotheses EMPIRICALLY before
  escalating/fixing — static analysis produced plausible-but-wrong suspects here.
- **Background agents can zombie** (spawn a monitor then "wait" forever): they leave a stray game/
  python holding port 9090 → the next run acts slow or the wrong instance answers. Kill strays
  (`tools/stop_game.ps1` + taskkill) and verify the scene path before trusting a run.
- **gbplay `eval` gotcha:** a `for` loop with `; return` on the same line pulls the return INTO the
  loop (runs 1 iteration). Put `return` on its own line, or set things explicitly without a loop.
- Windows/PowerShell/Godot: ASCII-only .ps1, `Start-Process` arg quoting (a mis-quoted --path can
  launch the OLD sibling project which ALSO serves 9090 — verify scene path), Bash for Godot runs,
  `dangerouslyDisableSandbox: true` on Godot shell calls. (CLAUDE.md has the full list.)
