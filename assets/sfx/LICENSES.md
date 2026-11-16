# assets/sfx — sound provenance & licences

Ruling: DECISIONS 2026-11-14 (b2) — CC0 / public-domain audio may be added with a licence note here.
Never add audio of unknown licence. One line per file (or file family).

## Owner library (SamuraiRobot2.0, owner-approved source — docs/feedback/owner_2026-07-04_arena_variety.md §2)
Copied from `D:\Dropbox\MyGames\SamuraiRobot2.0\assets\sounds\fx` (the owner's own project library).
All pre-existing `*.mp3` in this folder (spring, impact1-3, slam, rewardCheer, awYeah, ...) come from here.

| File | Use (AudioManager key) | Added |
|---|---|---|
| `awNo.mp3` | `own_goal_groan` — comedic "aww no" on a sports OWN GOAL | 2026-11-14 WK-105 |
| `lower.mp3` | `sports_fall` — descending slide-whistle "whoop" (1.35 kHz -> 30 Hz, 1.5 s) when a goat falls out of a sports court / through a Dropshot hole (replaces the brawl `death` sting there) | 2026-11-14 WK-105 |
| `spring_short.ogg` | `bounce` — derived from the owner's `spring.mp3`: cut to 0.42 s, fade-out 0.24-0.42 s (`ffmpeg -af "atrim=0:0.42,afade=t=out:st=0.24:d=0.18"`) so the 0.95 s ring stops hogging voices | 2026-11-15 WK-132 |
| `super_aim.ogg` | `super_aim` — WK-26 super-aim wind-up, derived from the owner's `lower.mp3`: tonal slide 0-0.68 s, reversed, first 20 ms cut, stretched x3 (atempo, pitch kept), 180 Hz high-pass, 0.12 s fade-in, loudnorm -18 LUFS, mono (`ffmpeg -af "atrim=0:0.68,areverse,atrim=0.02,asetpts=PTS-STARTPTS,atempo=0.5,atempo=0.66,highpass=f=180,afade=t=in:st=0:d=0.12,loudnorm=I=-18:TP=-2:LRA=7" -ac 1`): a rising 250 Hz -> 1.2 kHz whistle over 1.95 s (the 2 s fuse) | 2026-11-15 WK-26 |
| `crunch.mp3` | `tile_break` — gritty crunch when a Dropshot floor tile BREAKS open (2nd hit) | 2026-11-14 WK-121 |
| `whistle_double.ogg` | `whistle_double` — WK-131 kickoff-gate open: referee pea-whistle "TWEET-TWEET", derived from the owner's `lower.mp3` slide whistle: its steady top 0-0.075 s stretched x4 (atempo, pitch kept) then pitched up an octave (asetrate x2) to ~2.6-3.0 kHz, 1.2 kHz high-pass, 28 Hz vibrato + tremolo (the pea trill), 8 ms / 25 ms fades = one 0.15 s blast; two blasts with a 0.08 s gap, loudnorm -16 LUFS, mono (`ffmpeg -filter_complex "[0:a]atrim=0:0.6,asetpts=PTS-STARTPTS,atempo=0.5,atempo=0.5,atrim=0:0.3,asetrate=88200,aresample=44100,highpass=f=1200,vibrato=f=28:d=0.25,tremolo=f=28:d=0.45,afade=t=in:st=0:d=0.008,afade=t=out:st=0.125:d=0.025,pan=mono\|c0=0.5*c0+0.5*c1,asplit=2[b1][b2];anullsrc=r=44100:cl=mono,atrim=0:0.08[g];[b1][g][b2]concat=n=3:v=0:a=1,loudnorm=I=-16:TP=-1.5:LRA=7"`) | 2026-11-15 WK-131 |

## Kenney (kenney.nl) — Creative Commons Zero (CC0 1.0), http://creativecommons.org/publicdomain/zero/1.0/
Downloaded 2026-11-14 from the official pack pages; files copied verbatim, renamed with a `kenney_` prefix.

| File(s) | Pack (version) | Source page | Use (AudioManager key) |
|---|---|---|---|
| `kenney_impactPunch_medium_000..004.ogg` | Impact Sounds (1.0) | https://kenney.nl/assets/impact-sounds | `ball_hit` — ball touch "thwock", pitch/volume by impact speed |
| `kenney_impactSoft_heavy_000..001.ogg` | Impact Sounds (1.0) | https://kenney.nl/assets/impact-sounds | `ball_body` — low body thump layered under hard touches / power shots |
| `kenney_impactPunch_heavy_000/002/004.ogg` | Impact Sounds (1.0) | https://kenney.nl/assets/impact-sounds | `ball_power` — super/power-shot strike |
| `kenney_impactPlank_medium_000..002.ogg` | Impact Sounds (1.0) | https://kenney.nl/assets/impact-sounds | `tile_crack` — dry crack when a Dropshot floor tile CRACKS (1st hit); also `super_locked` (WK-20e Brawl spawn-truce dry click: a super press dropped while spawn-protected, pitched x1.6 at -11 dB) |
| `kenney_impactWood_medium_000..001.ogg` | Impact Sounds (1.0) | https://kenney.nl/assets/impact-sounds | `tile_break_body` — low knock layered under the tile-break crunch; also `gate_clonk` (WK-131 kickoff-gate block, pitched x1.25 x 0.9-1.15); also `wall_tok` (WK-175c 2026-11-16: the blocked-wall "tok" under the WK-175 WR refund gate, pitched x0.8 = a dull ~120 Hz knock, SFX bus) |
| `kenney_jingles_SAX02.ogg` | Music Jingles | https://kenney.nl/assets/music-jingles | `goal_red` — rising sax run (528 -> 937 Hz) for a RED goal/point |
| `kenney_jingles_SAX10.ogg` | Music Jingles | https://kenney.nl/assets/music-jingles | `goal_blue` — rising sax run (592 -> 786 Hz) for a BLUE goal/point |
| `kenney_jingles_SAX07.ogg` | Music Jingles | https://kenney.nl/assets/music-jingles | `own_goal` — descending "wah-wah-wah-waaah" sax for an OWN GOAL |

Pack licence text (both packs): "License: (Creative Commons Zero, CC0) ... This content is free to use in personal,
educational and commercial projects. Support us by crediting Kenney or www.kenney.nl (this is not mandatory)".

## freesound.org — Creative Commons Zero (CC0 1.0), http://creativecommons.org/publicdomain/zero/1.0/
WK-53 goat bleats. Each source page was checked on 2026-11-15 and shows CC0 1.0 as its only licence. The source is the
freesound HQ preview (`https://cdn.freesound.org/previews/<id/1000>/<id>_<user-id>-hq.ogg`). One bleat was cut from each
preview, high-passed and loudness-matched (~-16 dBFS active RMS, peak <= -1.2 dBFS); pogo/puff/vex also got denoise and a
-5 dB shelf above 4 kHz. The `bleat_ghost_*` variants add a band-limit (280 Hz-2.6 kHz), a 5.5 Hz vibrato and a 4-tap echo
tail. AudioManager adds +3 semitones at playback (spec wk37a §9). Reproduce with `tools/audio/render_bleats.sh`.

| File(s) | Source sound (author) | Cut from preview | Use (AudioManager key) |
|---|---|---|---|
| `bleat_butch.ogg`, `bleat_ghost_butch.ogg` | https://freesound.org/people/Kinoton/sounds/581240/ "Single Goat Bleating 2x" (Kinoton) | 0.36-1.12 s (bleat 1) | `bleat_butch` / `bleat_ghost_butch` — BUTCH (blue), deep adult |
| `bleat_billy.ogg`, `bleat_ghost_billy.ogg` | https://freesound.org/people/Kinoton/sounds/581240/ (Kinoton) | 2.11-2.88 s (bleat 2, tremolo) | `bleat_billy` / `bleat_ghost_billy` — BILLY (orange) |
| `bleat_vex.ogg`, `bleat_ghost_vex.ogg` | https://freesound.org/people/satoristudios3/sounds/677220/ "Nigerian Dwarf Buck Goat" (satoristudios3) | 0.10-0.80 s | `bleat_vex` / `bleat_ghost_vex` — VEX (purple), pulsed buck |
| `bleat_ziggy.ogg`, `bleat_ghost_ziggy.ogg` | https://freesound.org/people/saha213131/sounds/691476/ "goat2.mp3" (saha213131) | 0.03-0.70 s | `bleat_ziggy` / `bleat_ghost_ziggy` — ZIGGY (green), clean "meeh" |
| `bleat_pogo.ogg`, `bleat_ghost_pogo.ogg` | https://freesound.org/people/jsbarrett/sounds/200333/ "Baby goat bleating" (jsbarrett) | 1.40-2.10 s | `bleat_pogo` / `bleat_ghost_pogo` — POGO (pink), kid |
| `bleat_puff.ogg`, `bleat_ghost_puff.ogg` | https://freesound.org/people/jsbarrett/sounds/200333/ (jsbarrett) | 4.86-5.45 s | `bleat_puff` / `bleat_ghost_puff` — PUFF (yellow), smallest kid |

## WK-116 PRESSURE NETS crowd loops — derived only from files already listed above (no new source audio)
Rendered by `python tools/audio/render_wk116_crowd.py` (numpy + ffmpeg, fixed RNG seeds, deterministic). Licences follow the sources.

| File | Derived from | How | Use (AudioManager key) |
|---|---|---|---|
| `crowd_murmur_loop.ogg` | `rewardCheer.mp3` (owner library, see above) | 40 grains of the sustained cheer (0.10-2.20 s), 0.7-1.3 s each, pitch 0.80-1.00, half reversed, Hann windowed, overlap-added on a circular 6.0 s buffer; band-limited 180 Hz-2.6 kHz in the frequency domain (seamless loop); -18 LUFS, peak -1 dBFS, mono | WK-116 crowd murmur bed (anticipation swell +6 dB, held until the goal) |
| `crowd_clap_loop.ogg` | `kenney_impactPlank_medium_000..002.ogg` (Kenney, CC0) | 8 crowd claps in 4.0 s (120 BPM, beats 1/3 accented), each 14 plank cracks cut to 90 ms with an 18 ms decay, pitched x1.7-2.4, onsets ~N(0, 11 ms); 700 Hz-7 kHz band; 0.3 s decaying-noise room tail convolved circularly; tanh soft-clip; -18 LUFS, peak -1 dBFS, mono | WK-116 step-2 clap-chant loop (until the goal) |

WK-116 one-shots reuse listed files at playback: `pressure_ka` = `kenney_impactWood_medium_*` pitched x1.25-1.5, `pressure_chunk` =
`kenney_impactPunch_heavy_*` pitched x0.62-0.78, `pressure_slam` = `slam.mp3` x0.7, `pressure_ooh` = `rewardCheer.mp3` x0.74.

## WK-163 KO sting — derived from files already in the repo (no download, no synthesis). Licences follow the sources.
Rendered by `python tools/audio/render_ko_sting.py` (numpy/scipy + ffmpeg, deterministic).

| File | Derived from | How | Use (AudioManager key) |
|---|---|---|---|
| `ko_sting.ogg` | `crunch.mp3` (owner library, see above) + `assets/placeholder/newplatformer/Sounds/sfx_disappear.ogg` and `sfx_throw.ogg` (Kenney **New Platformer Pack 1.1**, CC0 1.0, https://kenney.nl/assets/new-platformer-pack; pack `License.txt` in `assets/placeholder/newplatformer/`) | crack = crunch x1.12, 160 Hz HPF, 0-0.10 s then faded, peaks limited 8 dB; vanish = sfx_disappear + sfx_throw (-9 dB), +4 dB gain ramp to 0.3 s, tanh drive 2.0, -2.5 dB under the crack; 120 Hz HPF, cosine fade 0.38-0.55 s, limited, peak -1.2 dBFS; 0.55 s mono 44.1 kHz Vorbis q6 | `ko_sting` — WK-163 brawl KO attack layer over the `death` pop (Stingers bus) |

- `slam_tight.ogg` (WK-165, 2026-11-15): `slam.mp3` with its 0.12 s leading silence trimmed (`ffmpeg -af atrim=start=0.12,asetpts=PTS-STARTPTS -c:a libvorbis -q:a 6`). Same source/licence as slam.mp3.
- `super_launch.ogg` (CD5-02, 2026-11-16): the owner library's `fire_missile.mp3` (`D:\Dropbox\MyGames\SamuraiRobot2.0\assets\sounds\fx`, owner-approved source, see the top of this file) with its 0.17 s leading silence trimmed, a 40 ms tail fade, -3.5 dB so the Vorbis encode stays under 0 dBTP (peak -0.8 dBFS), mono (`ffmpeg -af "atrim=start=0.170,asetpts=PTS-STARTPTS,afade=t=out:st=0.66:d=0.04,volume=-3.5dB" -ac 1 -c:a libvorbis -q:a 6`). No other processing. Use: `super_launch`, the bright rocket-launch front layer of the super (Stingers bus) over the `explosion_boss` rumble + `slam_tight` crack.

## WK-169c SHOWDOWN stings (2026-11-16) — derived from files already listed above (no download, no synthesis). Licences follow the sources.
Rendered by `python tools/audio/render_wk169c_showdown.py` (numpy/scipy + ffmpeg, deterministic). Pitch = plain resampling.

| File | Derived from | How | Use (AudioManager key) |
|---|---|---|---|
| `golden_bell.ogg` | `pickup_bubble.mp3` (owner library) | two strikes 110 ms apart: x2.0 (+12 st) then x2.67 (+17 st) at -1 dB, each tail cosine-faded 0.10-0.22 s after its onset; 150 Hz HPF; peak -1 dBFS; 0.36 s mono 44.1 kHz Vorbis q6 | `golden_bell` — WK-169c golden telegraph "ding-ding" (Stingers) |
| `golden_collect.ogg` | `pullOutItem.mp3` + `pickup_bubble.mp3` (owner library) | pullOutItem as is + pickup_bubble x1.335 (+5 st) at -2 dB, together; 80 Hz HPF; cosine fade 0.45-0.60 s; peak -1 dBFS; mono | `golden_collect` — WK-169c gold collect sting (Stingers) |
| `golden_pfff.ogg` | `woosh.mp3` (owner library) | x0.667 (-7 st), cut to 0.30 s with a 60 ms cosine fade; peak -1 dBFS; mono | `golden_pfff` — WK-169c golden-tank-end deflate (SFX) |

WK-169c entry / step cues reuse listed files at playback: the WK-116 `pressure_ka` (`kenney_impactWood_medium_*` x1.5) then `pressure_chunk`
(`kenney_impactPunch_heavy_*` x0.78) 70 ms later; steps 2 / 3 = a single `pressure_chunk` x0.73 / x0.68. The held-UB deny is the WK-20e `super_locked` click.

## WK-183 refuel ding (2026-11-16) — SYNTHESIZED in-house (no source audio, no download). Self-made; no third-party licence.
Rendered by `python tools/audio/render_wk183_refuel_ding.py` (numpy/scipy + ffmpeg, deterministic). Synthesized because every short
bright blip already here carries another meaning (pickup_bubble = powerup pickup / golden bell, pickup_health = heal, btnClick = UI).

| File | Made from | How | Use (AudioManager key) |
|---|---|---|---|
| `refuel_ding.ogg` | sine partials only | glug 0-48 ms (sine swept 240 -> 560 Hz + 25 % 2nd harmonic, -4 dB) + ding from 30 ms (G6 1568 Hz bell partials x1 / x2.76 / x5.40, exp decay tau 26 / 14 / 8 ms); cosine fade 85-110 ms; 150 Hz HPF; peak -1 dBFS; 0.11 s mono 44.1 kHz Vorbis q6 | `refuel_ding` — WK-183 sports fuel-arc refund tick (SFX bus, -16.5 dB = 10 dB under a mid ball touch, +0..+5 st with the fuel gained, <= 1 per 0.15 s per goat) |
