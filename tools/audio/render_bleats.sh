#!/bin/bash
# Render per-hero bleats (normal + ghost) from CC0 freesound previews. args: SRC_DIR OUT_DIR
# WK-53. SRC_DIR holds the freesound CC0 HQ previews (cdn.freesound.org/previews/.../<id>_<user>-hq.ogg) of
# sounds 581240 (Kinoton), 677220 (satoristudios3), 691476 (saha213131), 200333 (jsbarrett); see assets/sfx/LICENSES.md.
# Needs ffmpeg (libvorbis) + python numpy/scipy. Output: bleat_<hero>.ogg + bleat_ghost_<hero>.ogg (copy to assets/sfx).
S="$1"; O="$2"; mkdir -p "$O/tmp"
norm() { # in out target_rms_db
  local rms=$(python -I "$(dirname "$0")/bleat_active_rms.py" "$1")
  local g=$(python -c "print(round($3 - ($rms), 2))")
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$1" -af "volume=${g}dB,alimiter=limit=0.84:attack=1:release=40:level=disabled" -ar 44100 -ac 1 -c:a libvorbis -q:a 6 "$4" 2>/dev/null || \
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$1" -af "volume=${g}dB,alimiter=limit=0.84:attack=1:release=40:level=disabled" -ar 44100 -ac 1 "$2"
  echo "$4 rms_in=$rms gain=$g"
}
one() { # name src ss to hp extra
  local n=$1 src=$2 ss=$3 to=$4 hp=$5 extra=$6
  local d=$(python -c "print(round($to-$ss,3))"); local fo=$(python -c "print(round($to-$ss-0.08,3))")
  ffmpeg -nostdin -hide_banner -loglevel error -y -ss $ss -t $d -i "$S/$src" -ac 1 -ar 44100 \
    -af "highpass=f=$hp,highpass=f=$hp${extra},afade=t=in:st=0:d=0.008,afade=t=out:st=$fo:d=0.08" "$O/tmp/$n.wav"
  norm "$O/tmp/$n.wav" x -16 "$O/bleat_$n.ogg"
  # ghost variant: thinner (band-limited), wobbly, echoing; +3 semitones is applied at runtime
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$O/tmp/$n.wav" \
    -af "apad=pad_dur=0.45,highpass=f=280,lowpass=f=2600,lowpass=f=2600,vibrato=f=5.5:d=0.18,aecho=0.85:0.7:65|130|210|320:0.45|0.3|0.18|0.1,afade=t=out:st=$(python -c "print(round($d+0.15,3))"):d=0.3" "$O/tmp/${n}_g.wav"
  norm "$O/tmp/${n}_g.wav" x -17 "$O/bleat_ghost_$n.ogg"
}
one butch  581240_2247456.ogg 0.36 1.12 110 ""
one billy  581240_2247456.ogg 2.11 2.88 110 ""
one vex    677220_14166079.ogg 0.10 0.80 160 ",afftdn=nf=-40,treble=g=-5:f=4000,lowpass=f=8000"
one ziggy  691476_14040168.ogg 0.03 0.70 200 ""
one pogo   200333_3159560.ogg 1.40 2.10 280 ",afftdn=nf=-35,treble=g=-5:f=4000,lowpass=f=8000"
one puff   200333_3159560.ogg 4.86 5.45 280 ",afftdn=nf=-35,treble=g=-5:f=4000,lowpass=f=8000"
