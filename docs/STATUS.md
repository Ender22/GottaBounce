# STATUS — current state & next steps

> The single always-current handoff doc. Update after EVERY commit. A fresh context reads this first.
> Durable history/rationale lives in `docs/DECISIONS.md`, `docs/specs/`, `docs/briefs/`,
> `docs/feedback/` — this file is a lean current-state snapshot, not a session log.

**Last updated:** 2026-07-05 — **SCOPE CORRECTION (owner-flagged).** The prior "GAME COMPLETE" label
was WRONG: it certified the *core versus loop* (physics/feel/bots/11 arenas/audio) — the hard ~25% —
as if it were the whole game. It is not. Measured against the actual bar (TowerFall Ascension / Duck
Game), we are ~25%. **What is genuinely done:** the core versus match loop and its feel. **What is
missing (the other ~75%):** a front-end shell (title / character-select / mode-select / arena-select /
options / pause — the game currently BOOTS STRAIGHT INTO a hardcoded 1-human+3-bot match), a real
playable-character roster (goat/ram etc.), themed circuits, and additional game modes (trials/time-
attack, co-op survival, sports, puzzle). Roadmap: `docs/ROADMAP.md`. Everything in "What exists" below
is real and validated — it is the foundation, not the finish line.

## Where we are
The game is a **lives-based, Duck-Game-style kill-race**: no round timer; each player has lives
(default 1); stages end by last-one-standing; players race to a cumulative **10 kills across
frequently-rotating levels**; sudden death = a true simultaneous double-KO only. Combat is
bounce → fly (jetpack REQUIRED to traverse) → **un-charged super-smash (the kill move)** → recover,
with a **transient damage system** (Lv1 slow red pulse / Lv2 fast, +33%/+66% launch, 8s heal) and
**edge-relative, off-screen kills** (near-edge dead-on = out; mid-stage healthy survives = the
recovery gamble). Foundation is healthy (the "crash + 28fps" scare was refuted — see Watch-out).
**CURRENT FOCUS:** DONE — the game is complete & capstone-verified (SHIP). What's left is an optional
polish backlog only (see NEXT STEPS). Historical detail below.

**CURRENT FOCUS (historical):** 10-LEVEL CIRCUIT built, THEMED, and validated per-level; bot head-banging FIXED
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
- **[NEW 2026-07-05] Phase 1 foundation:** `GameConfig` autoload + `MatchConfig` resource, `Settings`
  autoload (user://settings.cfg, applies buses+window on boot), `GameMode` seam + `BrawlMode` (versus
  loop extracted; PartyMatch = generic runner reading GameConfig). `main_scene`=ShellRoot (boots to
  brawl; styled screens IN PROGRESS via gameplay-programmer against `docs/briefs/frontend_ux_spec.md`).
- **[NEW 2026-07-05] The Herd — goat/ram cast (art pass #1):** all 6 idle sprites live in the
  `bouncer_<color>_idle` slots + verified in-engine — Pogo(pink,mascot)/Butch(blue ram)/Ziggy(green ibex)/
  Puff(yellow sheep)/Vex(purple markhor)/Billy(orange billy). Squash/charge poses = pass #2. Bible:
  `docs/briefs/character_theme_bible.md` + `character_art_bible.md`.
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

## NEXT STEPS
> **THE CORE VERSUS LOOP IS DONE; THE GAME IS ~25% BUILT.** See `docs/ROADMAP.md` for the full path to
> a TowerFall/Duck-Game-complete product. Active phase: **Phase 1 — front-end shell + match-config +
> mode framework** (the scaffolding every character/mode/circuit hangs off). The core versus loop
> becomes "Brawl" mode inside that shell. The polish backlog below is deferred behind the roadmap.

**OPEN OWNER DECISION:** `match_target_kills` kept at 10 (owner-set); QA recommends 7-8 for a tighter
~3-min match (10 = ~4.5min/18-21 stages due to the -1 self-fall score volatility). Will apply if the
owner chooses 7/8.

**Optional polish backlog (none blocking):**
- Generate `assets/world/bumper_post.png` to retire the graceful grey bumper stand-in (bumper_gauntlet/
  drop_chamber/wrecking_yard). Pre-existing art backlog.
- Hazard follow-ups: solid moving collider (overlap-only today), metallic clang SFX, sweep-kind visual
  check; wrecking_yard larger-sample left/right spawn-bias check; trivial `hazard_assisted` cross-stage
  carryover cleanup; keep an eye on the_ascent occasional `underside_boosted` (3/stage, not the pathology).
- Sunny-cluster per-level visual signature (CD #6 #2 — reserved generated-tileset upgrade).
- Bot flee-to-heal (RETREAT half of the damage/heal loop — structurally marginal at 8s heal vs short stages).
- Goat/ram shape prototype (non-circular collider + solidity-by-hit-position; DECISIONS 2026-07-03).
- Audio polish: UI-click when a button .tscn exists; per-powerup activate SFX; real announcer VO.
- Minor: atoll radial-well reads a bit linear; grassy K1 marginal (edges 57%/pit 36%); grassy median 29s.
- Whiff-arrest fix `v1a_super_whiff_safety.md` (OPTIONAL — CD #5 ruled the whiff acceptable).
- Historic art-fix list (far-zoom mat, real font, skull icon, black-hole vignette) — see git history.

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
