"""WK-183 refuel "glug-ding" for the sports fuel arc's refund tick (docs/audit/2026-11-16_wk183_ux.md fix 5).

SYNTHESIZED here from sine partials (numpy), so it is self-made with no third-party source: see assets/sfx/LICENSES.md.
Why not reuse an existing file: every short bright blip already in assets/sfx carries another meaning. pickup_bubble.mp3 is the
powerup pickup (and the WK-169c golden bell is derived from it), pickup_health.mp3 is the brawl heal, and btnClick_Start.mp3 is
the UI click / gate whine. A refuel that sounded like any of them would teach the wrong thing.

  refuel_ding.ogg  0.11 s, mono 44.1 kHz:
    glug  0-48 ms   a rising "bloop": a sine swept 240 -> 560 Hz (exponential) + 25 % 2nd harmonic, 2 ms attack, decay to 0 at 48 ms
    ding  30-110 ms a small bell on G6 (1568 Hz) with inharmonic partials x1 / x2.76 / x5.40 (1.0 / 0.30 / 0.10), 1.5 ms attack,
                    exp decay (tau 26 ms, upper partials faster), cosine fade 0.085-0.110 s
    mix   glug -4 dB under the ding, 150 Hz high-pass, peak -1 dBFS
  AudioManager pitches it up 0 .. +5 st with the fuel gained (Tuning.wk183_ding_*), so the base sits low enough to stay sweet at +5.

It also prints the active RMS of the ding and of the ball-hit files (kenney_impactPunch_medium_*), and the volume_db that puts the
ding 10 dB under a MID ball touch (BALL_DB_SOFT..BALL_DB_HARD midpoint = -6.5 dB), which is Tuning.wk183_ding_db.
Usage: python tools/audio/render_wk183_refuel_ding.py      (writes assets/sfx/refuel_ding.ogg; deterministic)
"""
import glob
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX = os.path.join(ROOT, "assets", "sfx")
BALL_MID_DB = -6.5     # AudioManager: lerp(BALL_DB_SOFT -12, BALL_DB_HARD -1, 0.5)
UNDER_DB = 10.0


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0


def active_rms_db(x, thresh_db=-40.0):
    """RMS over 10 ms blocks louder than thresh_db below the peak (the audible body, not the silence)."""
    n = int(0.010 * SR)
    blocks = [x[i:i + n] for i in range(0, len(x) - n, n)]
    rms = np.array([np.sqrt(np.mean(b * b)) for b in blocks])
    peak = np.max(np.abs(x))
    keep = rms[rms > peak * 10.0 ** (thresh_db / 20.0)]
    return 20.0 * np.log10(np.sqrt(np.mean(keep * keep)))


def env_ad(t, attack, end):
    e = np.clip(t / attack, 0.0, 1.0)
    e *= np.clip((end - t) / max(end - attack, 1e-6), 0.0, 1.0) ** 1.5
    return e


def write_ogg(x, name):
    path = os.path.join(SFX, name)
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "t.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(x, -1.0, 1.0) * 32767.0).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", path], check=True)
    print("wrote", path, "%.3f s" % (len(x) / SR))
    return path


def main():
    n = int(0.110 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)

    # glug: exponential sweep 240 -> 560 Hz over 48 ms
    g_end = 0.048
    f = 240.0 * (560.0 / 240.0) ** np.clip(t / g_end, 0.0, 1.0)
    ph = 2.0 * np.pi * np.cumsum(f) / SR
    glug = (np.sin(ph) + 0.25 * np.sin(2.0 * ph)) * env_ad(t, 0.002, g_end)
    out += 10.0 ** (-4.0 / 20.0) * glug

    # ding: G6 bell, starts at 30 ms
    t0 = 0.030
    td = np.clip(t - t0, 0.0, None)
    on = (t >= t0).astype(np.float64)
    att = np.clip(td / 0.0015, 0.0, 1.0)
    ding = np.zeros(n)
    for ratio, amp, tau in ((1.0, 1.0, 0.026), (2.76, 0.30, 0.014), (5.40, 0.10, 0.008)):
        ding += amp * np.sin(2.0 * np.pi * 1568.0 * ratio * td) * np.exp(-td / tau)
    out += ding * att * on

    # tail fade 85-110 ms, HPF, peak -1 dBFS
    a, b = int(0.085 * SR), n
    out[a:b] *= 0.5 * (1.0 + np.cos(np.pi * np.linspace(0.0, 1.0, b - a)))
    out = sosfilt(butter(2, 150.0, btype="high", fs=SR, output="sos"), out)
    out *= 10.0 ** (-1.0 / 20.0) / np.max(np.abs(out))
    path = write_ogg(out, "refuel_ding.ogg")

    ding_rms = active_rms_db(decode(path))
    ball = [active_rms_db(decode(p)) for p in sorted(glob.glob(os.path.join(SFX, "kenney_impactPunch_medium_*.ogg")))]
    ball_rms = float(np.mean(ball))
    vol = ball_rms + BALL_MID_DB - UNDER_DB - ding_rms
    print("ding active RMS %.1f dBFS; ball_hit active RMS %.1f dBFS (mean of %d)" % (ding_rms, ball_rms, len(ball)))
    print("volume_db for the ding %.0f dB under a mid ball touch (%.1f dB): %.1f" % (UNDER_DB, BALL_MID_DB, vol))


if __name__ == "__main__":
    main()
