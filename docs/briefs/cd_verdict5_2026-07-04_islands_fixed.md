# CD VERDICT #5 — islands_void FLAGSHIP re-judge after verdict #4 fixes — 2026-07-04

**Reviewer:** Creative Director (fantasy-fit + fun gate, GAME_ESSENCE owner).
**Purpose:** re-judge the integrated flagship after the CD #4 FIX work landed (island widen 960px,
bot void-avoidance AI, per-level `kill_shape` metric). **This verdict GATES the 9-level circuit.**
**Method:** rendered playtest, `tools/run_game.ps1` + `tools/gbplay.py`; watched real-time bot combat
in motion (bursts), drove P1 human-style (fly / aim / super-smash), ran deterministic whiffed-super
probes (flat vs down-aimed), pulled per-level `round_stats`, checked camera in motion + live audio.
Sim was briefly slowed (`Engine.time_scale=0.25`, restored to 1.0) ONLY to overcome remote-input
latency for the hands-on kill/whiff probes — all pacing/feel judgments are from real-time observation.

## VERDICT: **SHIP** — the kill fantasy is now delivered; the flagship is ready to be the circuit template.

The verdict #4 root cause is fixed. The dominant death mode has **flipped** from uncredited self-
suicide to **credited smash-offs into the void**, a real hands-on smash-off lands the victim off the
screen while the attacker survives on-island, and the one remaining self-ringout mode (the down-aimed
whiffed super) is a **fair, legible committal gamble**, not a broken kill move. Ship it and build the
circuit on this template. Four non-blocking follow-ups below (one — the void-read-at-zoom — should be
addressed as the template propagates, since every void level inherits it).

---

## The KILL FANTASY is now delivered (the verdict #4 gap is closed)

**Kill economy, islands_void only (12 stages, 39 kills, `round_stats`):**
- **Credited (killer ≥ 0): 59% · uncredited (killer = −1): 41%.** In verdict #4 this was ~25% / ~75%.
  The death mode has FLIPPED to credited-dominant.
- **Kill shape: 79% off-the-bottom** (`void` 28 + `bottom` 3 of 39) — the intended "knock rivals off
  the screen into the void" is the shape that actually resolves stages; side blasts (`left` 6/`right` 2)
  are the minority. The per-level `kill_shape=void_is_floor` relabel works: void kills report `"void"`,
  not conflated with grassy's `"pit"` (grassy stages in the same run correctly logged `pit`/`left`/`right`).
- **A real hands-on smash-off works** (evidence `cd5_s2_c/d.png`): I flew at a bot sitting on the A→B
  gap rim, the super aim-reticle locked on it, the connect launched it out over the void, and I flew
  on — the victim ended dead in the gap (`x≈1138, y≈1802`) while I stayed alive. This is the exact
  fantasy verdict #4 said was mechanically present but under-delivered. It now delivers on a real hit.
- **The void is a recovery GAMBLE, not a pure suicide pit** (evidence `cd5_open_seq/frame_003.png`):
  bots knocked into the void are repeatedly seen alive DOWN in the dark band, jetpacking to climb back
  out — some make it, some don't. That is Pillar-4 recovery drama happening on screen, not a fake floor.
- The **super reads as "flying head-first into someone"** (evidence `cd5_whiff_c.png`): on fire the
  bouncer becomes a purple energy projectile that rockets along the aim vector. On-fantasy.
- Note: my 41% uncredited is higher than the brief's re-measure (~22–30%) but same direction and a
  small, idle-human-biased sample (an idle P1 lands zero smashes, so the 3 bots' gamble-losses are a
  larger share of total deaths). The verdict-#4 disease — **the super self-destructing the attacker on
  a NORMAL hit** — is gone; the residual uncredited deaths are legitimate recovery-gamble and whiffed-
  super losses, not a broken kill move.

## THE KEY RULING — the whiffed super self-ringout: **ACCEPTABLE committal risk → SHIP** (no arena-relative-super needed to gate the circuit)

I probed this deterministically and it is **not** a random "your kill move kills you":
- **Flat/upward whiff = SAFE.** A super fired horizontally into an empty gap carried me across TWO
  gaps and landed me alive on island C (`cd5_whiff_c/d.png`, P0 ended `x≈3627` alive). You do not die
  for whiffing per se.
- **Down-aimed-near-the-rim whiff = self-ringout.** Only when I deliberately aimed the super DOWNWARD
  toward the void near a rim and hit nothing did I rocket into the gap and ring out (`cd5_wd_aim.png` →
  P0 dead `x≈1387, y≈1933`, inside the A→B gap below the floor).

That is a **fair, legible committal gamble**: you pointed your kill-cannon at the abyss to spike a
rival hanging over the void, and you missed — so you followed them in. This is genre-standard risk
(a whiffed TowerFall off-stage shot, a Smash side-B past the ledge). It is self-caused by an
aggressive read, it is ~1/stage, and it is shared by humans and bots. It does **not** break the
fantasy — it *is* the fantasy's downside, honestly priced. **Ruling: this does not block the circuit.**
The game-designer's parallel arena-relative-super / aim-clamp spec should be kept as an OPTIONAL
backlog polish (revisit only if real multi-human testing shows the whiff-death is felt as cheap); do
NOT hold the circuit or touch the drain-all super constant for it now.

## Constant motion / "one more round" — YES
Perpetual bouncing, flying, and airborne brawling; no camping, no dead space; stages resolve fast
(median islands stage ≈ 7 s). Flight is required and feels powerful (`cd5_fly_mid/late.png` — clean
jetpack arc across the arena into a collision). Audio is live and layered (music playing + 7 SFX
voices firing mid-combat, 3-bus layout) — unchanged since verdict #4's comprehensive pass. A first-
timer would want another round on movement and on the smash-off payoff.

---

## CAMERA (owner-flagged this pass): concept is FINE — ship it; refine the follow-logic (non-blocking)

Judged from a real-time 0.35 s-interval burst during a spread 4-player moment (`cd5_cam2/frame_002-005`).

- **Is it violently jarring / does it hard-CUT or SNAP?** No. Between consecutive real-time frames the
  pan + zoom is **gradually damped** — it eases from a wide framing (`frame_002`) to a tighter cluster
  framing (`frame_004/005`) over ~0.7 s. I did not see a teleport cut or a snap-zoom mid-combat. The
  large jumps I saw earlier (`cd5_watch1`) were STAGE TRANSITIONS (banner → countdown → new-stage
  re-frame), which are expected and fine.
- **So (a) is the concept wrong, or (b) transitions under-damped?** **Neither is the headline** — the
  transitions read acceptably damped, and the concept (follow the action cluster with a 0.60 readability
  zoom floor, off-screen chevrons) is the RIGHT call: fit-everyone bottoms out at ~0.42 zoom / ~30px
  bouncers = unreadable (per `camera_2x_policy.md`), and split-screen would destroy the shared-space
  pinball chaos that IS this game. This is **not** a camera rethink.
- **The real issue is follow-TARGETING, not damping.** When the four players split into two pairs
  (P1+P2 left, P3+P4 right), the camera followed the RIGHT pair and pushed the other two **fully
  off-screen behind chevrons** (`frame_004/005`: pink P1 + blue P2 reduced to left-edge arrows). For a
  human whose own bouncer is in the dropped pair, losing sight of yourself is disorienting and can get
  you killed blind. (Mitigating factor: when the human is actively fighting they ARE in the cluster and
  stay framed — I was always on-screen while driving smashes. The drop happens when the human is passive
  or the arena genuinely splits.) I also saw one earlier frame where the cluster centroid landed on an
  EMPTY island and the camera framed no players at all (`cd5_watch1/frame_009`).
- **Recommendation (non-blocking follow-up, hand to gameplay-programmer):** keep the concept; refine
  the cluster framing to (1) **always weight the local human player into the frame** (never fully
  off-screen behind a chevron for more than a beat), and (2) add **cluster hysteresis + avoid framing
  empty geometry** when the centroid falls into a gap. This is polish, not a circuit gate.

---

## Non-blocking follow-ups (prioritized; track before/with the circuit)

**P1 — address as the template propagates (every void level inherits it):**
1. **Void render is ZOOM-DEPENDENT.** Zoomed OUT it reads as a proper full-width bottomless dark chasm
   (`cd5_watch1/frame_013`, `cd5_s2_c`). Zoomed IN on a single gap it reads as a thin dark strip with
   light-green hills filling the rest of the bottom (`cd5_watch1/frame_000/006`, `cd5_cam2/frame_005`)
   — a falling player briefly reads "safe green" before the dark band. The red chevron rim line is
   always present (so lethality is marked), but at combat zoom the "abyss" read is weaker than intended.
   This is the same known P3 issue from verdict #4, still present. Extend the dark void fill / under-lip
   AO under the inner islands so the whole bottom reads lethal at ALL zooms. Do this as the void-level
   template is finalized so the circuit doesn't inherit a weak void read ×10.

**P2 — game-designer look:**
2. **Incidental-credit inflation.** An **idle** human (zero input) accrued credited kills and even WON
   a match 10–8–8–7 by bots pinballing off its body and ringing out within the last-aggressor credit
   window. This inflates the "credited %" and rewards passivity. Review the ring-out credit window /
   attribution so a completely passive player can't farm kills. (Contributes to the gap between my
   measured 59% credited and the true "intentional-smash" share.)
3. **Race-to-10 pacing.** 24 stages to reach 10 in the unattended run; the −1 suicide penalty keeps
   cancelling progress and a couple of islands stages stalled long (36.6 s, 18.9 s). Better than verdict
   #4 but the economy still drags; partly an idle-survivor artifact. Revisit the suicide penalty / stall
   handling if it persists with active play.

**P3 — carried from verdict #4 (unchanged):** UI-click SFX when a button .tscn exists; per-powerup
activate SFX; real announcer VO.

---

## Evidence artifacts (tools/out/)
- `cd5_watch1/frame_000,006,009,013.png` — void read at different zooms; empty-geometry framing miss (009).
- `cd5_cam2/frame_002-005.png` — real-time camera burst: damped pan/zoom + the split-pair off-screen drop.
- `cd5_fly_mid.png`, `cd5_fly_late.png` — flight required + powerful (jetpack arc into a collision).
- `cd5_s2_c.png`, `cd5_s2_d.png`, `cd5_s2_e.png` — hands-on smash-off: aim-reticle lock → launch victim over the void → constant motion aftermath.
- `cd5_whiff_c.png`, `cd5_whiff_d.png` — FLAT whiff = super-projectile carries you safely across gaps (recoverable).
- `cd5_wd_aim.png`, `cd5_wd_fire.png` — DOWN-aimed whiff near the rim = the self-ringout (fair committal death).
- `cd5_open_seq/frame_003.png` — bots alive IN the void jetpacking to recover (gamble, not pure suicide).
- `cd5_matchend.png` — polished match-end panel ("P1 WINS THE MATCH!" + rematch/quit).
- `round_stats` dump: `C:/Users/dlica/AppData/Roaming/Godot/app_userdata/GottaBounce/cd5_round_stats.json`
  (per-level split: Islands Void 59%/41% credited/uncredited, 79% off-bottom kill shape).
