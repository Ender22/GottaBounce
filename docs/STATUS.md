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
**CURRENT FOCUS:** 10-LEVEL CIRCUIT built, THEMED, and validated per-level; bot head-banging FIXED
(obstacle-aware ascent) + a permanent **bot-motion-health probe** in the QA feed + motion-quality now
a QA obligation (GAME_ESSENCE). Circuit levels each have a distinct kill-shape AND a distinct look
(meadow / dark drum / steel high-sky / golden-hour / bright morning / teal atoll / indigo twilight /
arcade violet / dusk). CORE GAME COMPLETE & SHIPPING-QUALITY — **CD VERDICT #6 = SHIP** (couch-ready; all 4 fantasy verbs
confirmed hands-on; credited kills 76%; motion clean; audio/VFX/10 themed levels/match-end/powerups all
land). Circuit-wide QA passed C1-C6; both QA must-fixes done (underside-hover exploit fixed + VFX
telegraphy shipped). Remaining = NON-BLOCKING polish/stretch: (1) match-pacing sanity-check at human
pace (top fun risk — IN PROGRESS); (2) sunny-cluster visual signature; (3) delta-banner edge case;
+ the stretch backlog (moving-hazard/wrecking_yard, bot flee-to-heal, goat, audio polish).

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
> CORE COMPLETE (CD verdict #6 = SHIP) + pacing-polished. Everything below is polish/stretch.
> **OPEN OWNER DECISION:** `match_target_kills` — kept at 10 (owner-set); QA recommends 7-8 for a
>   tighter ~3-min match (10 = ~4.5min/18-21 stages due to the -1 self-fall score volatility). Awaiting
>   owner call; will apply if they choose 7/8.
- DONE: pacing polish (ceremony 3.9s->2.8s, powerup first-spawn ->2.5s, SD survivor-banner fix).
- DONE since SHIP: CAMERA zoom-pump fix (owner concern — pump eliminated, 0.60 floor kept); MOVING-HAZARD
  mechanic + `wrecking_yard` 11th level (two anti-phase wrecking balls, WY1-WY3 pass). **FULL 11-LEVEL
  ROSTER COMPLETE.** Running a capstone integrated smoke (all 11 load/rotate + no-regression from
  camera/hazard/pacing/exploit changes + motion-health).
1. **Remaining = minor polish only** (game is complete + shipping-quality):
   - Hazard follow-ups: solid moving collider (currently overlap-only), metallic clang SFX, sweep-kind
     visual check; wrecking_yard spawn rebalance (left/right side-death asymmetry).
   - Sunny-cluster per-level visual signature (CD #6 item 2 — reserved generated-tileset upgrade).
   - Moving-hazard feature + `wrecking_yard` (11th level, #22).
   - Bot flee-to-heal (RETREAT half of the damage/heal loop; game-designer note in the 2026-07-03
     lives/damage feedback addendum).
   - Goat/ram shape prototype (non-circular collider + solidity-by-hit-position; DECISIONS 2026-07-03).
   - Minor level/metric tweaks: atoll radial-well reads a bit linear (C3 soft note); grassy central_pit
     K1 marginal (edges 57%/pit 36% vs 60%/30%); grassy median 29s slightly slow.
   - Audio polish: wire UI-click when a button .tscn exists; per-powerup activate SFX; real announcer VO.
   - Whiff-arrest fix `v1a_super_whiff_safety.md` (OPTIONAL — CD #5 ruled the whiff acceptable).
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
