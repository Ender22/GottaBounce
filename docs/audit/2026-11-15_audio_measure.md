# WK-79a — audio by numbers (first measured mix)

Sound-designer, 2026-11-15. Nobody has heard this game, so this report measures it instead. No code was edited and
Godot was not launched. All numbers come from one Movie Maker recording plus offline ffmpeg/numpy analysis.

## Source

| | |
|---|---|
| Recording | `tools/out/rec/WK-108b_dropshot_on` (Dropshot Beach, 4 x L3 bots, ghosts on, seed 7, 40 s combat, 4 stages / 3 points) |
| Audio | `movie.avi` audio stream: **PCM s16le, 48 kHz, stereo**. Godot's AVI Movie Maker does carry the master mix, so no settings change is needed to capture it |
| Kept copy | `tools/out/wk/WK-79a_WK-108b_dropshot_on.wav` (49.5 s). The avi itself is gone: `tools/rec_sheet.py:396` deletes `movie.avi` right after extracting the JPEG frames. **That is why no audio had ever been kept** (see T-1) |
| Alignment | Audio time = recorder frame `f` / 30 (not game `t`: hit-stop makes `t` drift 0.25 s behind by the 2nd point). Phases, supers and aim windows come from `data.json` |
| Scripts | `tools/out/wk/WK-79a_scripts/` (`analyze.py`, `loopfit.py`, `musicfit.py`, `filebands.py`, `envelope.py`, `plots.py`), run with `python -I`. Not promoted to `tools/` (no code edits this pass, see T-3) |
| Images | `tools/out/wk/WK-79a_loudness_timeline.png`, `WK-79a_cue_ladder.png`, `WK-79a_spectrum_full.png`, `WK-79a_spectrum_super.png`, `WK-79a_spectrum_goal_countdown.png` |

**Caveat: the recording runs at 18 % real time.** AudioManager's rate limits use `Time.get_ticks_msec()` (wall clock):
`BOUNCE_MIN_GAP`, `BOUNCE_ONSET_GAP`, `BALL_GAP_*`, the bleat and lock-click gaps. In this recording a 40 ms wall gap is
about 7 ms of game time, so cue density here is a worst case. Levels, spectra and the bed are not affected.

**Coverage gap:** this is sports only. Brawl (MEADOW MILE, KOs, smashes, brawl bounce levels) has not been recorded with
audio. Brawl numbers below are predictions from file measurements and gains (see the cue ladder), not measurements.

## 1. Headline numbers vs targets

| Metric | Measured | Target (couch / console) | Verdict |
|---|---|---|---|
| Integrated loudness | **-14.2 LUFS** | -23 to -16 (couch TV: aim at -18 ± 2) | FAIL: 2-4 LU too hot |
| Loudness range (LRA) | **2.4-2.8 LU** | 5-10 LU for an action game | FAIL: a flat wall, no dynamics |
| True peak | **-1.1 dBTP** (sample peak -1.45 dBFS) | <= -1 dBTP (WK-121 bar) | PASS, but only 0.1 dB margin |
| Samples >= -3 dBFS | 0.011 % | — | no clipping. The limiter works |
| 10 ms blocks within 0.5 dB of the ceiling | 18 of 4950 (0.36 %), 16 clusters | — | see §3: mostly the countdown, not gameplay |
| Crest factor (whole) | 15.6 dB (6.0 linear). 400 ms windows: median 14.5 dB | — | dense |
| Momentary loudness, combat | median -14.5, p10 -16.6, p90 -12.5, max -10.0 LUFS (2nd point) | — | events rise only +1 to +6 LU |
| Stereo | L/R RMS -17.01 / -17.04 dB, correlation 0.62, side/mid -6.3 dB | balanced | PASS. Width comes from the music only; every SFX is mono-centre |
| DC offset | +0.0014 (-57 dBFS) | — | harmless (sources: `crunch.mp3` +0.0116, `rewardCheer.mp3` +0.0074) |
| Silence gaps / dropouts | none after 0.08 s; longest stuck-sample run 3 ms | — | PASS |
| Transient rate | 5.2 onsets/s mean, max 11/s (46 s, 4th countdown/GO) | — | no cue machine-guns. Max 11/s is the sum of all cues |

Loudness timeline: `WK-79a_loudness_timeline.png`. The bed sits at -15 LUFS momentary with goal bumps to -10. The
supers barely move the line.

## 2. What the bed is made of (the main finding)

I fit the actual `coke_blast.mp3` loop and the `gameplay_2.mp3` track (identified at correlation 0.46 with no drift; it
starts at rec t=0) into the recording by least squares.

| Window | Thrust-loop energy share | Thrust gain vs file | Music energy share | Music gain vs file |
|---|---|---|---|---|
| combat 2-6 s | **-1.9 dB (65 %)** | -4.3 dB | -12.8 dB (5 %) | -8.9 dB |
| combat 11-15 s | -3.0 dB (50 %) | -4.3 dB | -6.7 dB (21 %) | -8.9 dB |
| combat 22-26 s | -2.7 dB (54 %) | -5.0 dB | -10.6 dB (9 %) | -9.3 dB |
| combat 31-35 s | -3.3 dB (47 %) | -4.6 dB | -7.8 dB (17 %) | -10.1 dB |
| combat 40-43 s | -4.2 dB (38 %) | -5.2 dB | -8.2 dB (15 %) | -10.5 dB |

- **One looped jetpack voice is 38-65 % of all the sound in combat.** It runs 5-9 dB above the music. Its gain matches
  the code: `THRUST_ON_DB -7` + SFX compressor makeup `gain = 4.0`, minus about 1.3 dB of compression = -4.3 dB.
- It is on whenever ANY goat boosts. Goats averaged 3.5 of 4 boosting every second of combat, so it never switches off,
  at one fixed pitch and level: a 3.5 s loop repeating as a drone.
- Its spectrum (centroid 899 Hz; low/mud/mid shares -4.9/-6.3/-4.7 dB) sits on top of the cues that must read: bounce
  ping 1.3 kHz, goal sax 0.3-1.5 kHz, bleats, super_aim 250-1200 Hz, KO pop, slide whistle.
- The music is buried. It is 5-21 % of the energy, with an effective level of about -24 LUFS (file -14.6 LUFS, Music bus
  -8 dB, about -1.5 dB more lost in limiting and fit).
- **Bug, measured:** in stages 2-4 the thrust loop keeps playing through **STAGE_END (the goal celebration),
  STAGE_INTRO and COUNTDOWN**. Its fitted share there is -6.8 to -8.5 dB (14-21 % of the energy), while `data.json` shows
  every goat frozen at v=0 with `b` (is_boosting) = true. Root cause: `Player._boosting_now` stays latched while
  `frozen`, and `AudioManager._any_boosting()` (l.786) doesn't check `frozen`. Stage 1's countdown is clean (share
  -24.8 dB) because nobody has boosted yet.

## 3. Per-event spikes vs the bed

Bed = median momentary loudness over the 2 s before the event. Peak = max sample peak in the 1.5 s after it.

| Event (audio t) | Bed (LUFS) | Max M after | Rise | Peak dBFS | Notes |
|---|---|---|---|---|---|
| countdown 3-2-1 (0.40 / 9.13 / 29.40 / 45.30) | -13.0 to -13.4 | -11.3 to -11.6 | **+1.6 to +2.0** | **-1.4 (ceiling)** | every beep and every "1" hits the limiter |
| GO (1.47 / 10.17 / 30.47 / 46.37) | -12.6 to -15.5 | -11.3 to -11.8 | +1.3 to +3.7 | -1.4 to -2.3 | 3 of 4 hit the ceiling |
| **point / goal stinger** (7.50 / 27.80 / 43.70) | -15.2 to -16.3 | -10.0 to -10.4 | **+4.8 to +6.0** | -1.4 to -2.0 | the best-reading payoff. The crowd (3.3 kHz) and sax run are clearly visible in the spectrogram |
| super_aim wind-up (17.60 / 19.30) | -13.7 / -15.3 | -13.6 / -12.5 | **+0.1 / +2.7** | -2.0 / -3.1 | masked: only a faint 300-450 Hz smear inside the bed (`WK-79a_spectrum_super.png`) |
| **super fired** (18.20 / 19.57) | -14.2 / -13.7 | -12.5 / -13.6 | **+1.7 / +0.1** | -2.3 / -3.1 | see below. RMS jumps 9 dB but the LUFS rise is under 2 LU |

**The super blast, the signature verb, does not read on TV speakers and ducks the mix.**
- `explosion_boss.mp3` is by far the hottest file in the library: active RMS -6.1 dBFS (other SFX are -11 to -23), file
  true peak +0.9 dBTP, **74 % of its energy at 20-60 Hz**, centroid 127 Hz, 2-5 kHz share -22.6 dB.
- Played at `volume_db -2` + 4 dB makeup, its 0 dBFS peaks hit the SFX compressor (threshold -10 dB, ratio 2.5) about
  8 dB over threshold, i.e. roughly 4.8 dB of gain reduction on the whole SFX bus for its 2.8 s length.
- Measured: at 18.25 s the 20-60 Hz band rises about 20 dB and stays up past 20.5 s. Over the same window the 0.5-2 kHz
  band DROPS 5-10 dB, and 1-14 kHz visibly darkens in `WK-79a_spectrum_super.png`.
- K-weighting, like a TV speaker, mostly ignores below 60 Hz. So the loudness meter barely moves and a couch TV plays a
  muffled thump, while the thrust, bounces and wind-up all get pushed down.

**Limiter ceiling hits (16 clusters): 12 are the countdown beeps / GO, 2 are the stage-intro card click, 3 are hard ball
touches** (50 ms 60-500 Hz bursts at 22.0 / 34.4 / 36.6 s). No payoff hits the ceiling. The loudest peaks in a match
come from `countdown_beep*.mp3` (file peaks -1.0 / -0.3 dBFS) + `go` + `ui_click` (default 0 dB), all pushed +4 dB by
the SFX makeup.

## 4. Spectrum balance

Band energy share (dB relative to the total, 20 Hz-20 kHz):

| Segment | sub 20-60 | low 60-200 | mud 200-500 | mid 0.5-2k | harsh 2-5k | pres 5-10k | air 10-20k | centroid |
|---|---|---|---|---|---|---|---|---|
| whole | -9.1 | -6.3 | -7.0 | -4.7 | -11.2 | -15.5 | -23.4 | 928 Hz |
| combat 1.5-7.5 | -18.4 | -5.5 | -6.1 | -4.3 | -12.2 | -16.2 | -23.2 | 890 Hz |
| combat 10.2-27.8 (2 supers) | **-5.8** | -6.0 | -7.3 | -6.3 | -14.1 | -17.8 | -24.9 | **616 Hz** |
| combat 30.5-43.7 | -13.2 | -5.4 | -6.1 | -4.7 | -12.9 | -16.5 | -23.6 | 832 Hz |
| countdown (avg of 4) | -15 to -28 | -9 to -18 | -8 to -10 | -3.0 to -3.5 | **-5.3 to -7.2** | -11 to -12.5 | -18 to -20 | 1.5-2.0 kHz |
| stage end / goal | -15 to -27 | -8 to -10 | -8 | -2.6 to -3.1 | -8.5 to -9.0 | -12.3 to -12.9 | -28 | 1.5-1.6 kHz |

- **Mud / low-heavy, dull combat mix.** The combat centroid is 600-900 Hz, and 60-500 Hz holds as much energy as
  0.5-2 kHz. The sources are the thrust loop, the music lows, and the whole sports ball family:
  - `ball_hit` (impactPunch_medium): centroid 190 Hz
  - `ball_power`: 125 Hz
  - `ball_body`: 90 Hz
  - `tile_crack`: 170 Hz
  - `explode` (explosion_01): 128 Hz

  The "hero sound of sports" lives where TV speakers have nothing.
- **Sub rumble:** the 20-60 Hz band is the biggest band (-5.8 dB) in the segment with supers. It is wasted headroom and
  the compressor trigger.
- **Harsh 2-5 kHz: not a problem.** Combat is -12 to -14 dB. The brightest moments are the countdown beeps (harmonics to
  12 kHz), which is fine for a beep.
- In-band masking check, combat with the super rumble excluded (99th-percentile vs median, 50 ms frames): bounce-ping
  band 1.0-1.6 kHz **+6.8 dB** (p90 only +3.9); whistle/beep band 2-4 kHz +7.9 dB; ball band 100-250 Hz +8.6 dB.
  Cues need about +6-10 dB in-band to read reliably. The bounce, the core verb, scrapes the bottom of that range, and
  only at its loudest instances.

## 5. Cue ladder (predicted level at bus output, `WK-79a_cue_ladder.png`)

Predicted level = file active RMS (10 ms blocks over -40 dBFS) + `volume_db` + bus (SFX: +4 makeup; Music: -8). This
is validated against the recording: thrust predicted -3 vs fitted -4.3 dB; music predicted -8 vs fitted -9 to -11 dB.
The thrust bed sits at **-20.2 dBFS**.

| Cue | Level | vs thrust bed | Note |
|---|---|---|---|
| super_fire | -4.1 | +16.1 | sub only |
| whistle_double (gates) | -7.0 | +13.2 | |
| goal sax | -10.7 | +9.5 | |
| ball_power | -12.3 | +7.9 | 125 Hz |
| countdown_final | -13.0 | +7.2 | |
| tile_break | -14.1 | +6.1 | |
| ball_hit hard | -14.8 | +5.4 | 190 Hz |
| bleat | -16.2 | +4.0 | |
| countdown | -16.7 | +3.5 | |
| **death pop (KO, brawl)** | -17.3 | **+2.9** | |
| **death_whoosh (ring-out)** | -17.5 | **+2.7** | |
| sports_fall | -17.3 | +2.9 | |
| goal_crowd | -18.9 | +1.3 | |
| **super_aim** | -22.0 | **-1.8** | |
| **bounce (brawl)** | -22.9 | **-2.7** | |
| ball_hit soft | -24.8 | -4.6 | |
| music | -24.7 | -4.5 | |
| **bounce (sports)** | -26.9 | **-6.7** | |

The KO, which is the payoff of brawl, and the bounce, the game's core verb, both sit within 3 dB of (or under) a drone
that runs for 87 % of combat and shares their band.

## 6. Silent / wrongly-sounding events in this recording

- Heard: countdown (12 beeps), GO (x4), point stinger + crowd + thump (x3), super_aim (x2, masked), super blast (x2, sub
  only), ball touches and tile hits (low transients), bounce pings (1.1-1.5 kHz dashes in the spectrogram), gameplay
  music from t=0 (gameplay_2, no restart between points: `match_started` fires once per match).
- **Wrongly heard:** the thrust drone through every goal celebration, intro and countdown after stage 1 (§2).
- Not exercised here: KO / sports_fall (0 kills), bleats (no evidence), match_won / scoreboard music (the 40 s cap
  ended the recording mid-match), gate cues (Rocketball only).
- **Silent by code** (EventBus signals with no audio handler):
  - `hazard_shoved` (a hazard shoving a goat): silent
  - `combat_ended`: silent, but covered by the goal stinger in sports
  - `crowd_ooh`: empty list (WK-131b)
  - `bounced` / `bounced_juicy` / `smash_landed` / `super_fired` are QA or legacy feeds already covered by other cues
- **No music ducking exists.** Nothing ducks the music under a goal stinger, KO or match win. The fixes below free
  enough room that this becomes optional polish (R8), not a fix.

## 7. Ranked changes for a programmer (WK-79b)

> **Applied 2026-11-15 by sound-designer (uncommitted, tagged `# WK-79b`):** R1, R2, R3, R4 (AudioManager part only),
> R5, R6, R7 (`AudioManager.gd`, `default_bus_layout.tres`) and T-1 (`tools/rec_sheet.py`). The parse gate is clean.
> Not applied: the R4 trims in `Cannon.gd` / `KeyDoor.gd` / `HerdLobby.gd` (other files; each still drops 4 dB from R1).
> Awaiting a verification recording.

Apply R1-R5 together; they are balanced as a package. Effect on combat, from the fitted energy budget:
- integrated about -17.5 to -18 LUFS, inside the target
- thrust 50 % -> ~15 % of energy, music 12 % -> ~29 %
- payoffs +8 to +12 LU over the bed
- the countdown off the limiter
- LRA should roughly double

Then re-record and re-run the scripts (accept below).

| # | Pri/Size | File : line | Change | Why (measured) |
|---|---|---|---|---|
| R1 | P1/S | `default_bus_layout.tres` `AudioEffectCompressor_sfx` | `gain = 4.0` -> **`0.0`**. Keep threshold -10, ratio 2.5, attack 2 ms, release 150 ms | the +4 dB makeup adds 4 dB to every SFX, including the drone. It drives integrated to -14.2 and pushes countdown/GO/ball_power/UI clicks into the -1 dB limiter (12 of 16 ceiling hits). Makeup is post-detection, so compressor behaviour is unchanged |
| R2 | P1/S | `AudioManager.gd:136` | `THRUST_ON_DB` -7.0 -> **-12.0** (with R1: -9 dB effective, about -29 dBFS RMS, ~4.5 dB **under** the music instead of 4.5 over) | thrust = 38-65 % of combat energy, 5-9 dB over the music, masking bounce/KO/aim/bleat in the 0.5-1.5 kHz band |
| R3 | P1/S | `AudioManager.gd:791` `_any_boosting()` | add `and not bool(p.get("frozen"))` to the condition. Also file to gameplay-programmer: `_boosting_now` stays latched while frozen (check boost VFX for the same stale latch) | drone measured at -6.8 to -8.5 dB share through STAGE_END / INTRO / COUNTDOWN while all goats sit at v=0 |
| R4 | P1/S | `AudioManager.gd:485` `_on_super_boosted` | `volume_db` -2.0 -> **-10.0**. Interim mid layer from an existing file: `play_sfx("super_fire", {"path": "res://assets/sfx/slam.mp3", "volume_db": -3.0, "pitch": 0.8, "pitch_var": 0.05})`. Same trim for other callers: `Cannon.gd:120` -2 -> -10, `KeyDoor.gd:80` -8 -> -16, `HerdLobby.gd:776` -12 -> -20 | super = 74 % sub at -4 dBFS RMS. It ducks the SFX bus about 5 dB for 2.8 s, mids drop 5-10 dB, and it adds under 2 LU of audible loudness. At -10 its peaks sit at the compressor threshold. Proper fix: sourcing S-1 |
| R5 | P1/S | `AudioManager.gd` per-cue gains (after R1, keeps payoff absolute levels while the bed falls about 9 dB) | `_on_killed` death -3 -> **+1**, death_whoosh -3 -> **+1**; `SUPER_AIM_DB` -8 -> **-2**; brawl bounce (l.461) -4 -> **0**; `BOUNCE_DB_SPORTS` -8 -> **-4**; `goal_crowd` (l.583) -2 -> **+2**; `BALL_DB_SOFT` -15 -> **-12**, `BALL_DB_HARD` -5 -> **-1**, `BALL_DB_POWER` -1 -> **0** (file peak -1.0, so it lands at the ceiling, not over it); `BLEAT_DB` -4 -> **-1**, `BLEAT_GHOST_DB` -6 -> **-4**; tile_crack (l.595) -9 -> **-6** with pitch 1.15 -> **1.5** (lifts the 170 Hz centroid); `GATE_WHISTLE_DB` 0 -> **-2**. **Leave alone:** goal sax (+4), countdown (-4 / -2), go (0). R1 alone moves their peaks to -5 / -2.3 / -4.9 dBFS | cue ladder: KO +2.9, ring-out +2.7, bounce -2.7, super_aim -1.8 vs bed. After R1-R5: KO about +11, bounce about +6 broadband (much more in-band), aim about +9, goal sax about +14 over the thrust. Payoffs (KO, sax) end up +7 to +10 over the music; the bounce is about +2 over the music broadband but a narrowband 1.3 kHz ping the music barely occupies |
| R6 | P2/S | `default_bus_layout.tres` `HardLimiter` | `ceiling_db` -1.0 -> **-1.5** | -1.1 dBTP measured at a -1.0 ceiling. Godot's HardLimiter is sample-peak (no oversampling), so bright transients (whistle, beeps) can overshoot between samples. 0.5 dB of margin makes the WK-121 bar robust |
| R7 | P2/S | `default_bus_layout.tres` SFX bus, effect slot 0 (before the compressor) | add `AudioEffectHighPassFilter` `cutoff_hz = 40`, `db = 3` (FILTER_24DB, 24 dB/oct) | the 20-60 Hz band is the biggest band (-5.8 dB) in the super segment: inaudible on TVs, eats headroom, triggers the compressor. Also removes the DC offsets in `crunch.mp3` / `rewardCheer.mp3` |
| R8 | P2/S | `AudioManager.gd:516` `_on_match_started`, `play_music` | per-track trim table: gameplay_1 **+0.9**, gameplay_2 **0**, gameplay_3 **-1.7**, gameplay_4 **-1.6** dB; scoreboard (l.520) 0 -> **-0.5**; title stays -4 (it measures -11.8 LUFS, i.e. -15.8 after trim) | file loudness -15.5 / -14.6 / -12.9 / -13.0 LUFS: a 2.6 LU jump depending on which track `randi()` picks |
| R9 | P2/M | `AudioManager.gd` (new) | music duck: on `goal_scored`, `KillPipeline.killed` (brawl) and `match_won`, tween the Music bus -6 dB (50 ms attack, 0.8 s hold, 600 ms release) | no ducking exists. Optional once R1-R5 land; the backlog asked for it explicitly |
| R10 | P2/S | `AudioManager.gd` `_process` / `_any_boosting` | drive the thrust voice by boosting-goat count: 1 goat -16 dB pitch 0.95 ... 4 goats -12 dB pitch 1.05 (0.03-0.05 random drift per relight) | a single 3.5 s loop at fixed pitch and level for 87 % of combat is a drone, not a jetpack. The count makes it informative |
| R11 | P3/S | `AudioManager.gd` (all wall-clock gaps) | replace `Time.get_ticks_msec()` rate-limit clocks with an accumulated `_clock += delta` in `_process` (`PROCESS_MODE_ALWAYS`, so it still runs while paused) | at Movie Maker's 18 % speed a 40 ms bounce floor is 7 ms of game time, so recorded cue density does not equal play density |
| R12 | P3/S | `SFX["bounce"]` | `balloon_pop.mp3` is 2.5 dB hotter (active RMS -20.4 vs -22.9) than `spring_short.ogg` in the same key, so alternate bounces jump in level. Needs a per-path trim (or a re-derived quieter file) | level jitter on the most frequent cue |

### Tooling (enablers for every future audio check)

| # | Pri/Size | Change |
|---|---|---|
| T-1 | **P2/S** | `tools/rec_sheet.py:396`: before `os.remove(avi)`, extract the audio, either `ffmpeg -v error -y -i movie.avi -vn -c:a pcm_s16le audio.wav` or by writing the `01wb` chunks into a WAV. Every recording then keeps its mix (about 9.5 MB per 50 s) |
| T-2 | P2/S | `src/dev/MatchRecorder.gd`: add AudioManager's QA counters to `data.json` (`sfx_counts`, `sfx_dropped`, `prio_dropped`, `prio_cut_prio`, `steals`, `filler_capped`, `bounce_micro_skipped`, `ball_strikes_seen/heard`). Plus a per-event log `{f, sfx}` from `play_sfx`, so silence and over-firing become exact instead of inferred |
| T-3 | P3/S | promote `tools/out/wk/WK-79a_scripts/` to `tools/audio/measure_mix.py` (one command: ebur128 summary + loop/music fit + band table + event table + the two PNGs) |

### Accept for WK-79b (re-record with T-1)

Record one Dropshot run (same seed 7) and one Brawl MEADOW MILE run with KOs, then check:
- integrated -16 to -20 LUFS
- LRA >= 5 LU
- true peak <= -1.0 dBTP, with 0 ceiling hits during COUNTDOWN
- thrust share <= -8 dB in combat, and <= -30 dB in STAGE_END / COUNTDOWN
- goal, KO and GO each >= +6 LU momentary over the 2 s bed
- super fired: the 0.5-2 kHz band rises (does not drop) in the 0.5 s after the blast
- bounce-band p90 margin >= +6 dB

## 8. Sourcing list (no audio was generated; candidates are files already in the repo)

| # | Event | Character wanted | Candidate |
|---|---|---|---|
| S-1 | `super_fire` crack layer | bright explosive crack/whomp, 0.4-0.8 s, energy 150 Hz-4 kHz, sharp 1-3 kHz transient at onset, short tail. Layered OVER the owner-picked `explosion_boss` rumble (keep the owner pick, just give it a front) | interim: `slam.mp3` pitched 0.8 (R4). Derivative option, following the WK-132 precedent: `explosion_boss.mp3` with `highpass=f=120` + a +6 dB shelf at 2.5 kHz (owner library) |
| S-2 | `ball_hit` / `ball_power` brightness | rubbery ball "thwock", 80-200 ms, centroid 0.6-1.5 kHz with a 2-4 kHz click (current Kenney impactPunch centres at 125-190 Hz, inaudible on TVs and masked by the low bed) | `assets/placeholder/_backup_pixeladventure/sfx/impact_generic_light_000..004.ogg` (Kenney Impact Sounds, CC0; measured centroid 611 Hz, 0.16 s), layered over the punch. Needs a `LICENSES.md` line before promotion |
| S-3 | thrust loop (long-term) | jet/air hiss loop, 2-4 s, seamless, energy mostly 1.5-6 kHz with little below 400 Hz, so it stops sitting on the 0.5-1.5 kHz cue band | none in the repo; needs a CC0 search (also check `assets/placeholder/jetpack/` notes) |
| S-4 | `crowd_ooh` (WK-131b) | short crowd "ooh", 0.6-1.0 s, mid-bright | none (unchanged) |
| S-5 | `hazard_shoved` (silent signal) | short rubber thud/boing, 120-200 ms | existing `gate_boing` (`spring_short.ogg`) at pitch 0.75, -10 dB. Wiring an existing signal to an existing file: S |

## 9. Backlog-ready items

| ID suggestion | Item | Pri / Size | Owner |
|---|---|---|---|
| WK-79b-1 | R1 + R2 + R3 + R5 mix package (thrust drone down and gated, makeup off, payoff gains) | P1 / S | gameplay-programmer (sound-designer numbers above) |
| WK-79b-2 | R4 super blast: -10 dB + slam layer now, S-1 crack later | P1 / S | gameplay-programmer, sound-designer (S-1) |
| WK-79b-3 | T-1 keep the audio from every recording | P2 / S | gameplay-programmer (tooling) |
| WK-79b-4 | R6 + R7 limiter -1.5 + SFX 40 Hz HPF | P2 / S | gameplay-programmer |
| WK-79b-5 | R8 music track trims | P2 / S | gameplay-programmer |
| WK-79b-6 | T-2 audio QA counters + event log into data.json | P2 / S | gameplay-programmer (tooling) |
| WK-79b-7 | Brawl recording with audio (MEADOW MILE, 4 goats, KOs) to cover the predicted-only half | P2 / S | sound-designer (after T-1) |
| WK-79b-8 | R10 thrust voice by boost count | P2 / M | gameplay-programmer |
| WK-79b-9 | S-2 brighter ball touch (promote impact_generic_light) | P2 / S | sound-designer |
| WK-79b-10 | R9 music duck under payoffs | P3 / S | gameplay-programmer |
| WK-79b-11 | R11 game-time rate-limit clock; R12 balloon_pop trim; S-5 hazard_shoved cue | P3 / S | gameplay-programmer |
