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
| `kenney_impactPlank_medium_000..002.ogg` | Impact Sounds (1.0) | https://kenney.nl/assets/impact-sounds | `tile_crack` — dry crack when a Dropshot floor tile CRACKS (1st hit) |
| `kenney_impactWood_medium_000..001.ogg` | Impact Sounds (1.0) | https://kenney.nl/assets/impact-sounds | `tile_break_body` — low knock layered under the tile-break crunch; also `gate_clonk` (WK-131 kickoff-gate block, pitched x1.25 x 0.9-1.15) |
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
