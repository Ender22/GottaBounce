"""WK-169c SHOWDOWN stings, derived ONLY from owner-library audio already in assets/sfx/ (no downloads, no synthesis).
Spec docs/specs/wk169c_showdown_polish_2026-11-16.md §2.2.

  golden_bell.ogg     the golden telegraph "ding-ding": two bell strikes 110 ms apart, both from pickup_bubble.mp3.
                      strike 1 = x2.0 speed (+12 st), strike 2 = x2.67 (+17 st, i.e. +5 st over strike 1) at -1 dB; each strike's
                      tail is cut short (cosine fade 0.10-0.22 s after its onset) so the two never smear into a chord or a
                      third "beat". 150 Hz high-pass, peak -1 dBFS, mono 44.1 kHz. Never a beep: no sine, no countdown sample.
  golden_collect.ogg  the gold collect sting: pullOutItem.mp3 (as is) + pickup_bubble.mp3 x1.335 (+5 st) at -2 dB, starting
                      together; cosine fade 0.45-0.60 s (<= 0.6 s), 80 Hz high-pass, peak -1 dBFS, mono.
  golden_pfff.ogg     the tank-end deflate: woosh.mp3 x0.667 speed (-7 st), cut to 0.30 s with a 60 ms cosine fade, peak -1 dBFS.

Pitch shifts are plain resampling (speed = pitch), like the WK-116 / WK-163 derivations.
Usage: python tools/audio/render_wk169c_showdown.py      (writes the three files into assets/sfx/; deterministic)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX = os.path.join(ROOT, "assets", "sfx")


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0


def speed(x, ratio):
    n = int(len(x) / ratio)
    return np.interp(np.arange(n) * ratio, np.arange(len(x)), x)


def highpass(x, f):
    return sosfilt(butter(2, f, btype="high", fs=SR, output="sos"), x)


def fade_out(x, start_s, end_s):
    y = x.copy()
    a, b = int(start_s * SR), int(end_s * SR)
    b = min(b, len(y))
    if a < b:
        t = np.linspace(0.0, 1.0, b - a)
        y[a:b] *= 0.5 * (1.0 + np.cos(np.pi * t))
    y[b:] = 0.0
    return y[:b]


def fade_in(x, s=0.002):
    y = x.copy()
    n = min(int(s * SR), len(y))
    y[:n] *= np.linspace(0.0, 1.0, n)
    return y


def place(buf, x, at_s, gain_db):
    i = int(at_s * SR)
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += (10.0 ** (gain_db / 20.0)) * x[:n]


def norm(x, peak_db=-1.0):
    p = np.max(np.abs(x))
    return x * (10.0 ** (peak_db / 20.0) / p) if p > 0 else x


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


def main():
    bubble = decode(os.path.join(SFX, "pickup_bubble.mp3"))
    pull = decode(os.path.join(SFX, "pullOutItem.mp3"))
    woosh = decode(os.path.join(SFX, "woosh.mp3"))

    # golden_bell: ding (+12 st) ... ding (+17 st) 110 ms later, short tails
    s1 = fade_out(fade_in(speed(bubble, 2.0)), 0.10, 0.22)
    s2 = fade_out(fade_in(speed(bubble, 2.0 * 2.0 ** (5.0 / 12.0))), 0.10, 0.22)
    bell = np.zeros(int(0.36 * SR))
    place(bell, s1, 0.0, 0.0)
    place(bell, s2, 0.110, -1.0)
    write_ogg(norm(highpass(bell, 150.0)), "golden_bell.ogg")

    # golden_collect: pullOutItem + pickup_bubble +5 st, <= 0.6 s
    col = np.zeros(int(0.60 * SR))
    place(col, fade_in(pull), 0.0, 0.0)
    place(col, fade_in(speed(bubble, 2.0 ** (5.0 / 12.0))), 0.0, -2.0)
    write_ogg(norm(fade_out(highpass(col, 80.0), 0.45, 0.60)), "golden_collect.ogg")

    # golden_pfff: woosh -7 st, cut to 0.30 s
    pf = speed(woosh, 2.0 ** (-7.0 / 12.0))
    pf = np.concatenate([pf, np.zeros(max(0, int(0.30 * SR) - len(pf)))])
    write_ogg(norm(fade_out(fade_in(pf), 0.24, 0.30)), "golden_pfff.ogg")


if __name__ == "__main__":
    main()
