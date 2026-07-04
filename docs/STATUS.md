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
**CURRENT FOCUS:** CD verdict #4 (FIX) on the integrated islands_void+audio build — concept validated
but the kill fantasy fails (~75% deaths = uncredited self-suicides; the super overshoots the narrow
islands and self-ringouts the attacker). Fixing the flagship (geometry-first, measured) BEFORE the
circuit build. See DECISIONS 2026-07-04 verdict #4 + `docs/briefs/cd_verdict4_2026-07-04_islands_audio.md`.

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
1. **FIX the flagship kill fantasy** (CD verdict #4, BLOCKING the circuit). P1: (a) GEOMETRY fix —
   widen islands so a super smash-off carries the VICTIM off but leaves the ATTACKER on-island (super
   overshoots the narrow islands today); forgiving traversal landing. Measure killer=-1 self-suicide
   share before/after (baseline ~75%); escalate to an arena-relative super ONLY if geometry can't fix
   it. IN PROGRESS. P2: per-level `kill_shape` field + fix `_classify_blast_edge` so QA isn't blind to
   void-floor kills (`docs/specs/v2a_kill_shape_void_floor_addendum.md`). IN PROGRESS.
2. **~10-level circuit — VARIED styles** (level-designer): build the ~9 new levels per the spec
   `docs/specs/v1_level_circuit.md` (drop_chamber/cylinder first, wrecking_yard last — moving-hazard
   gated). Each flight-required, off-screen-kill through-line, islands_void as template. BLOCKED until
   the flagship fix lands (levels inherit the seam). Then pacing/feel/CD QA on the rotation.
3. **Bot flee-to-heal** finish: the RETREAT/flee half is specced (BotProfile `flee_skill`) but only
   ~2% effective — structural (8s heal vs short stages). Reconcile in a bot-AI/melee pass (game-designer
   note in `owner_2026-07-03_lives_damage_killrace.md` addendum).
4. **Goat/ram shape prototype** (un-gated, DECISIONS 2026-07-03): non-circular collider + solidity-by-
   hit-position + taller sprite → richer super-smash sweet-spot variety. After the arena template settles.
- **Arena/audio follow-ups (non-blocking):** void dirt walls only render at arena sides (one full-width
  void rect — per-gap rects or renderer tweak for inner-island cliffs); `_classify_blast_edge` labels
  void deaths "pit" so K1 edge/pit metric misreads on this shape (needs a game-designer note before
  circuit QA); wire UI-click SFX when a button .tscn exists; per-powerup activate SFX + real announcer VO.
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
