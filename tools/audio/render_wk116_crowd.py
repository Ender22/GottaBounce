"""WK-116 PRESSURE NETS crowd loops, derived ONLY from audio already in assets/sfx (no downloads).

  crowd_murmur_loop.ogg  6.0 s seamless loop: a dense crowd murmur granulated from rewardCheer.mp3 (owner library): 40 grains
                         (0.7-1.3 s each, pitch 0.80-1.00, half reversed, Hann windowed) overlap-added on a CIRCULAR buffer, band
                         limited 180 Hz - 2.6 kHz in the frequency domain (circular, so the loop point is seamless).
  crowd_clap_loop.ogg    4.0 s seamless loop: a crowd clap-chant at 2 claps/s (120 BPM, beats 1 and 3 accented). Each clap = 14
                         Kenney impactPlank cracks (CC0) pitched x1.7-2.4, gains 0.4-1.0, onsets spread ~N(0, 11 ms); high-passed
                         700 Hz; a 0.3 s decaying-noise room tail convolved circularly (the tail wraps into the loop start); tanh soft-clip.

Both are loudness-normalised to -18 LUFS integrated (ffmpeg ebur128 measure, then a linear gain), mono 44.1 kHz, Ogg Vorbis q5.
Usage: python tools/audio/render_wk116_crowd.py            (writes into assets/sfx; deterministic: fixed RNG seeds)
"""
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX = os.path.join(ROOT, "assets", "sfx")
TARGET_LUFS = -18.0


def decode(path):
    fd, tmp = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-ac", "1", "-ar", str(SR), "-sample_fmt", "s16", tmp], check=True)
    with wave.open(tmp) as w:
        d = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    os.remove(tmp)
    return d


def write_wav(path, x):
    x = np.clip(x, -1.0, 1.0)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767.0).astype(np.int16).tobytes())


def resample(x, ratio):
    """Play x at `ratio` speed (ratio < 1 = slower + lower)."""
    n = int(len(x) / ratio)
    return np.interp(np.arange(n) * ratio, np.arange(len(x)), x)


def circ_band(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    g = np.ones_like(f)
    if lo > 0:
        g *= 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-6)) ** 4)   # 2nd-order-ish high-pass magnitude
    if hi > 0:
        g *= 1.0 / np.sqrt(1.0 + (f / hi) ** 4)                      # 2nd-order-ish low-pass magnitude
    return np.fft.irfft(X * g, n=len(x))


def circ_add(buf, grain, start):
    n = len(buf)
    idx = (np.arange(len(grain)) + start) % n
    np.add.at(buf, idx, grain)


def lufs(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", r.stderr)
    return float(m[-1]) if m else None


def finish(x, name):
    x = x - np.mean(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.5
    fd, tmp = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    # measure on 3 loop passes so the gated measurement sees a steady signal
    write_wav(tmp, np.tile(x, 3))
    l0 = lufs(tmp)
    gain = 10 ** ((TARGET_LUFS - l0) / 20.0)
    y = x * gain
    pk = np.max(np.abs(y))
    if pk > 0.89:   # keep <= -1 dBFS
        y *= 0.89 / pk
    write_wav(tmp, y)
    out = os.path.join(SFX, name)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    write_wav(tmp, np.tile(y, 3))
    print("%s: %.2f s, peak %.1f dBFS, %.1f LUFS" % (name, len(y) / SR, 20 * np.log10(np.max(np.abs(y))), lufs(tmp)))
    os.remove(tmp)


def murmur():
    rng = np.random.default_rng(116)
    src = decode(os.path.join(SFX, "rewardCheer.mp3"))
    body = src[int(0.10 * SR):int(2.20 * SR)]          # the sustained cheer (envelope -16..-23 dB), not the onset / decay
    L = int(6.0 * SR)
    buf = np.zeros(L)
    for _ in range(40):
        gl = int(rng.uniform(0.7, 1.3) * SR)
        a = int(rng.uniform(0, max(1, len(body) - gl)))
        g = body[a:a + gl]
        g = resample(g, rng.uniform(0.80, 1.00))
        if rng.random() < 0.5:
            g = g[::-1]
        g = g * np.hanning(len(g)) * rng.uniform(0.5, 1.0)
        circ_add(buf, g, int(rng.uniform(0, L)))
    buf = circ_band(buf, 180.0, 2600.0)
    finish(buf, "crowd_murmur_loop.ogg")


def claps():
    rng = np.random.default_rng(1160)
    planks = []
    for i in range(3):
        p = decode(os.path.join(SFX, "kenney_impactPlank_medium_00%d.ogg" % i))
        p = p[:int(0.09 * SR)]
        p = p * np.exp(-np.arange(len(p)) / (0.018 * SR))   # dry: the crack only
        planks.append(p)
    L = int(4.0 * SR)
    buf = np.zeros(L)
    beat = int(0.5 * SR)
    for b in range(8):
        accent = 1.0 if b % 2 == 0 else 0.72
        for _ in range(14):
            p = planks[int(rng.integers(0, 3))]
            c = resample(p, rng.uniform(1.7, 2.4))
            on = b * beat + int(rng.normal(0.0, 0.011) * SR)
            circ_add(buf, c * rng.uniform(0.4, 1.0) * accent, on % L)
    buf = circ_band(buf, 700.0, 7000.0)
    n = int(0.3 * SR)
    ir = rng.normal(0.0, 1.0, n) * np.exp(-np.arange(n) / (0.07 * SR))
    ir = ir / np.sqrt(np.sum(ir ** 2))
    irp = np.zeros(L)
    irp[:n] = ir
    wet = np.fft.irfft(np.fft.rfft(buf) * np.fft.rfft(irp), n=L)
    buf = buf + 0.35 * wet
    buf = np.tanh(3.0 * buf / (np.max(np.abs(buf)) + 1e-9))   # soft-clip the crack peaks (crest factor down ~6 dB)
    finish(buf, "crowd_clap_loop.ogg")


if __name__ == "__main__":
    murmur()
    claps()
    sys.exit(0)
