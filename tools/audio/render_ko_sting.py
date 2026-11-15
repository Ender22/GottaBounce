"""WK-163 KO sting layer, derived ONLY from CC0 / owner-library audio already in the repo (no downloads, no synthesis).

  ko_sting.ogg  0.55 s: a hard broadband CRACK at t=0 + a descending "vanish" sweep held up for ~0.35 s, then a fade.
                Layered OVER the existing KO pop (mm_quickdie.mp3, which fades in over 0.4 s and so has no attack of its own).

  crack  = crunch.mp3 (owner library) played x1.12 (faster/higher), 2nd-order 160 Hz high-pass, kept 0-0.10 s, faded to
           -10 dB by 0.22 s and out by 0.55 s; its own peaks limited 8 dB (1.5 ms look-ahead, 30 ms release) so the crack
           is dense instead of one spike.
  vanish = Kenney New Platformer Pack sfx_disappear.ogg (CC0) + sfx_throw.ogg at -9 dB (CC0) for a 1.4 kHz snap; a gain
           ramp 0 dB at 40 ms -> +4 dB at 300 ms holds the decaying sweep up; tanh drive 2.0; mixed at -2.5 dB under the crack.
  bus    = sum, 120 Hz 2nd-order high-pass, cosine fade 0.38-0.55 s, 2 ms fade-in (no click), limited -2 dB, peak -1.2 dBFS,
           mono 44.1 kHz, Ogg Vorbis q6.

Distinct from the smash family (impact1-3 / slam: a 600 Hz thud with nothing above 2 kHz): centroid ~0.95 kHz, 1-5 kHz only
5 dB under 200 Hz-1 kHz, crack at t=0 (slam.mp3 starts 0.13 s late), tonal falling tail.
Usage: python tools/audio/render_ko_sting.py        (writes assets/sfx/ko_sting.ogg; deterministic)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.ndimage import maximum_filter1d, uniform_filter1d
from scipy.signal import butter, sosfilt

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX = os.path.join(ROOT, "assets", "sfx")
KENNEY = os.path.join(ROOT, "assets", "placeholder", "newplatformer", "Sounds")
LEN = 0.55


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0


def speed(x, ratio):
    n = int(len(x) / ratio)
    return np.interp(np.arange(n) * ratio, np.arange(len(x)), x)


def highpass(x, f):
    return sosfilt(butter(2, f, btype="high", fs=SR, output="sos"), x)


def place(buf, x, gain):
    n = min(len(x), len(buf))
    buf[:n] += gain * x[:n]


def limit(x, ceil_lin, lookahead=0.0015, release=0.03):
    k = int(lookahead * SR)
    need = np.minimum(1.0, ceil_lin / np.maximum(maximum_filter1d(np.abs(x), 2 * k + 1), 1e-9))
    a = np.exp(-1.0 / (release * SR))
    g = np.empty_like(need)
    s = 1.0
    for i in range(len(need)):
        s = need[i] if need[i] < s else a * s + (1.0 - a) * need[i]
        g[i] = s
    g = np.minimum(uniform_filter1d(g, k), need)
    return x * g


def main():
    n = int(LEN * SR)
    t = np.arange(n) / SR
    crunch = highpass(speed(decode(os.path.join(SFX, "crunch.mp3")), 1.12), 160.0)
    disappear = decode(os.path.join(KENNEY, "sfx_disappear.ogg"))
    throw = decode(os.path.join(KENNEY, "sfx_throw.ogg"))

    body = np.zeros(n)
    place(body, disappear, 1.0)
    place(body, throw, 0.35)
    body *= 10 ** (np.interp(t, [0, 0.04, 0.30, LEN], [0, 0, 4.0, 4.0]) / 20)
    body /= np.abs(body).max()
    body = np.tanh(2.0 * body) / np.tanh(2.0)
    body /= np.abs(body).max()

    crack = np.zeros(n)
    place(crack, crunch, 1.0)
    crack *= np.interp(t, [0, 0.10, 0.22, LEN], [1.0, 1.0, 0.3, 0.0])
    crack /= np.abs(crack).max()
    crack = limit(crack, 10 ** (-8 / 20))
    crack /= np.abs(crack).max()

    y = highpass(crack + 0.75 * body, 120.0)
    fo = t > 0.38
    y[fo] *= 0.5 * (1 + np.cos(np.pi * (t[fo] - 0.38) / (LEN - 0.38)))
    k = int(0.002 * SR)
    y[:k] *= np.linspace(0, 1, k)
    y /= np.abs(y).max()
    y = limit(y, 10 ** (-2 / 20))
    y *= 10 ** (-1.2 / 20) / np.abs(y).max()

    fd, tmp = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())
    out = os.path.join(SFX, "ko_sting.ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", out], check=True)
    os.remove(tmp)
    print("wrote", out)


if __name__ == "__main__":
    main()
