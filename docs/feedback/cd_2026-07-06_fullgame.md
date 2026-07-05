# Creative Director — Full-Game Playthrough Verdict (2026-07-06)

**Role:** Player Advocate / Creative Director. **Method:** Booted `res://scenes/ui/ShellRoot.tscn`,
walked the whole front-end, then played all 4 modes with real human input via `tools/gbplay.py`
(held boosts, aimed supers, drove traversal) — one game instance on port 9090, stopped between
switches, verified zero strays. Watched MOTION in slow-mo bursts, not just outcomes. Evidence
screenshots in `tools/out/` (cd2_*.png, brawl_*/, trials_run/, gaunt_*/, mine_play/, crusher_play/).

---

## 1. OVERALL VERDICT — **SHIP-CLASS, with a short fun-critical punch-list (FIX, not RETHINK)**

This is now a **cohesive, purchasable-looking party brawler**, not a tech demo. The front-end reads
Mario-Kart-tier, the four modes hang together on one consistent Glossy-Toybox skin, and — most
importantly — **BRAWL delivers the core fantasy in full**: you bounce, you *must* fly across lethal
voids, you aim and fire the super head-first into rivals, you get launched off-screen, death is
cheap and funny, rounds resolve in seconds, and Sudden Death is a real 1v1 fly-and-smash duel. The
fantasy-fit check passes on the mode that carries the game.

**Fantasy-fit (Duck Game × Smash, no guns, every surface bounces, jetpack is movement AND weapon,
last one flying wins):** YES for BRAWL/GAUNTLET/SPORTS. TRIALS is deliberately off-fantasy (a solo
platforming change-of-pace with no smash/kill) and that's fine as a retention layer.

The blockers to a clean "SHIP" are **not** design failures — they're a **dirty dev save** and a
couple of **length/tuning knobs**, plus **one whole dimension (audio) that has never actually been
felt-validated.** None require re-architecting. Fix the punch-list in §4 and this is shippable.

---

## 2. WHAT'S GENUINELY GOOD (don't lose these)

- **Front-end is gorgeous and purchasable.** Title (`cd2_title.png`) — logo reads clean, all 6 Herd
  bobbers visible, Vex clear of the logo (the fix landed). ModeSelect (`cd2_modeselect.png`) — four
  mini box-cover dioramas with punchy taglines ("Last one flying wins.", "Hold the line. They keep
  coming, you keep flying."). CharacterSelect — big beauty-pose portrait + color-coded roster + clear
  match settings. ArenaSelect (`cd2_after_ready.png`) — **real baked arena thumbnails**, a genuine
  visual map-select; the circuit-card overflow and locked-ribbon collision are fixed. Nav focus is
  springy and readable. This is the biggest visible jump tonight and it worked.
- **BRAWL is the real thing.** `brawl_super/frame_002.png` shows Pogo wrapped in the golden super-aura
  with an orange directional aim-arrow while the camera zooms in to help aim — the aimed-super
  telegraph is legible and satisfying. Boost jet-trails, off-screen edge-chevrons, "BOUNCE!/TWO LEFT!/
  P1 SURVIVES!" callouts, ring-outs, SD duels — the juice is there.
- **Motion health is clean.** Across every burst (bot dogfights, my own flight, SD), I saw fluid arcs,
  boost across gaps, real engagement — **no head-banging, stuck, jitter, or camping.** The 2026-07-04
  pathology is not present.
- **Art-debt paydown is visually confirmed.** the_crusher heads (`crusher_play/`), the ball, crates,
  hazards all render as real chunky sprites — no code-drawn bodies, no debug rectangles. The
  "tech-demo tells" are gone.
- **Sports is fun and fair-enough.** Minefield (`mine_play/`) stayed competitive (RED 2–BLUE 3) with
  juicy "BOUNCE!" callouts and good scrum energy; the_crusher is a fair, symmetric, chaotic novelty.
- **Nice scoring nuance:** a self-fall is scored **−1** ("P4 −1" round tallies) — discourages suicide
  and rewards clean ring-outs. Pause menu and Options are clean and on-theme.

---

## 3. WEAKEST LINKS / FUN-BLOCKERS (most severe first)

### A. (FUN-CRITICAL) The audio mix has never been felt-validated — all playtesting ran MUTED
`cd2_options.png` shows **MUSIC VOLUME 0%** and MASTER 40% on the dev machine. The code default is
`music = 1.0` (Settings.gd:40) and music IS fully wired — `assets/music/` has title/gameplay_1-4/
boss/scoreboard tracks and `AudioManager.play_music()` fires random gameplay music on match start and
scoreboard music on end (AudioManager.gd:150,216,220). SFX coverage is rich (bounce/smash/super/death/
countdown/first_blood/…). **So audio exists and a real player will hear it — but the mute is a stale
saved setting, which means every playtest to date (mine included) evaluated the game in SILENCE.**
For a party brawler where "10–30 seconds of screaming chaos" is the product, the audio mix is a core
fun dimension and it is currently **unverified** — nobody has confirmed the music loops feel good, the
levels are balanced against SFX, the countdown→GO→gameplay→scoreboard transitions land, or that the
smash/super hits punch. **Why it hurts:** this is exactly the CD-mandated "absence-of-things" blind
spot — the game could ship feeling flat/hollow and no role would have caught it, because we've all
been playing on mute.

### B. (FUN / PACING) Match lengths fight the "one more round" fantasy
- **BRAWL = first to 10 kills.** In an unattended Mixed-bot match a single strong bot ran it out
  **10–0–3–0** (`cd2_brawl_maybe_end.png`) — long and lopsided to watch. QA previously suggested 7–8.
- **SPORTS = first to 10 GOALS** (`cd2_minefield0.png` HUD "TO 10"). Ten bounce-ball goals is a
  multi-minute match — far past the 10–30s round cadence the vision sells.
**Why it hurts:** the pillar is "rounds are 10–30s, one-more-round is always true." Targets this high
push sessions long and let a dominant bot snowball. This is a cheap knob with high impact. Suggest
playtesting Brawl ~7 and Sports ~5–7 goals.

### C. (CORRECTNESS, minor but visible) Progression save is in an impossible state
ArenaSelect shows **THE SCRAPWORKS = LOCKED** but **THE HIGH WIRE = unlocked** (`cd2_after_ready.png`)
— you can't have circuit #3 open while #2 is locked. Root cause (confirmed live): the persisted save
holds `circuits_cleared=["scrapworks"]` while `_circuit_plays={"meadow_mile":1}` — i.e. Scrapworks is
marked *cleared* without ever having been *unlocked* (a dev-test artifact from directly launching it).
`is_circuit_unlocked("high_wire")` then returns true because its predecessor is "cleared". The gate
logic itself is fine and a **fresh player's save would be correct**, so this won't hit a new player —
UNLESS the dirty `user://settings.cfg` ships. **Why it hurts:** if the dev save ships it's a visibly
broken progression; even if not, it signals the dev save needs a reset before any release build.
Cheap fix + a defensive guard (a circuit that is itself locked must not count as "cleared" toward
unlocking its successor).

### D. (FANTASY-THINNESS + unverified) TRIALS is off-fantasy and medal times are provisional
t_pinpoint (`trials_run/`, `trials_progress.png`) is a clean, fair, flight-required precision course
(lethal voids well telegraphed; falls respawn so it's completable). Good change-of-pace. **But it has
no smash/kill/opponent — it does not deliver the headline fantasy**, and medal thresholds
(Gold 12s / Silver 20s / Bronze 34s) are still PROVISIONAL — I could not confirm Gold is achievable
(my high fall count was partly tool-latency, but the times are untuned by design/known-gap). The
courses are **fun regardless of medal tuning** — the precision/route challenge stands on its own — so
this is a retention-layer polish item, not a blocker. New varied courses (t_cart_convoy/t_twin_hammers/
t_bank_shot) I did not reach in-run (they're courses 3/5/8; reaching them requires clearing the
earlier ones); I verified the set is wired and ordered mild→wild in `course_sets.json`.

### E. (MINOR TUNING) Gauntlet solo default = 1 life
GAUNTLET escalation is readable and fun (`gaunt_engage/`, `gaunt_super/` — clear "WAVE N OF 8" banners,
enemy counts ramp, I cleared waves 1–2 into 3, fully fantasy-relevant). But the default DEFENDERS pool
is **1 life** — one mistake ends a solo run. Consider 2–3 for solo so a naive player gets a second
chance and reads the escalation curve.

### F. (MINOR) Minefield ceiling mines under-trigger
In `mine_play/` play hugged the floor and the symmetric ceiling mines never bit. Fairness looks fine
(RED kept pace 2–3 even with me idle on RED — evidence AGAINST the flagged one-sided-BLUE funnel; it
reads as first-touch variance, as the studio suspected). But the signature hazard rarely matters.
Consider lowering the mines or biasing the ball upward so the gimmick actually threatens.

**Regressions from tonight's changes:** none found. Title/ModeSelect/ArenaSelect fixes all confirmed
landed; hazard/object sprites all render correctly; no new crashes or broken screens.

---

## 4. RANKED NEXT-WORK RECOMMENDATION

1. **[FUN-CRITICAL] Audio felt-pass + reset the dev save.** Wipe `user://settings.cfg` (fixes both the
   music-mute and the bogus progression), then do a real listen: full match with music at ship levels,
   countdown→GO→gameplay→SUDDEN DEATH→scoreboard transitions, smash/super punch, loop quality. This is
   the single biggest unverified fun dimension for a party game and we've been blind to it. Cheap to do,
   high risk if skipped.
2. **[FUN / cheap knob] Match-length tuning pass.** Playtest BRAWL ~7 kills and SPORTS ~5–7 goals against
   the "10–30s, one-more-round" pillar; confirm a dominant bot can't snowball an unwatchable blowout.
   Highest fun-per-effort item after audio.
3. **[POLISH / correctness] Progression robustness + save reset.** Guard `is_circuit_unlocked` so a
   still-locked circuit can't count as "cleared" for its successor, and reset the dirty dev save so the
   High Wire/Scrapworks contradiction can't ship.
4. **[RETENTION] Trials medal-time tuning via a movement bot.** Make Gold meaningful and verified across
   the varied battery (currently provisional). Courses are already fun; this is about the mastery hook.
5. **[POLISH] Gauntlet solo lives (1→2–3) + surface the minefield mines** (lower them / bias ball up) so
   the signature hazards actually bite.

**Fun-critical vs polish:** #1 and #2 are fun-critical (they change how the game *feels* to a first-time
player). #3–#5 are polish/retention — real, but they don't block the core "one more round" loop.

---

## Bottom line
The whole is now **more than the sum of its parts** — a coherent, good-looking, genuinely fun party
brawler whose flagship mode nails the fantasy. It is NOT a case of "green specs that aren't the game."
The remaining work is a tuning-and-hygiene punch-list, headlined by *actually hearing the game with the
music on.* Verdict: **FIX (short list), trending SHIP.**
