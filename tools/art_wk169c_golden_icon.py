"""WK-169c golden tank icon: a hue-masked recolour of assets/powerups/icon_unlimited_boost.png (spec
docs/specs/wk169c_showdown_polish_2026-11-16.md §2.4 step 5, "first try, with no generation").

Only the cyan hue band moves to gold (highlight #FFD23F, mid #E09A1A, shadow #8A5212, luminance-mapped); the red cap, the orange
flames and the dark chocolate outline are untouched (outside the band or too dark / unsaturated). Bright, washed-out cyan (the
infinity emblem's core and its glow) goes white-hot (#FFF6D8). The band weight feathers over 12 deg of hue and 0.08 of
saturation so edges never show a seam. Alpha is copied as is.
Usage: python tools/art_wk169c_golden_icon.py   (writes assets/powerups/icon_golden_tank.png; deterministic)
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "assets", "powerups", "icon_unlimited_boost.png")
DST = os.path.join(ROOT, "assets", "powerups", "icon_golden_tank.png")

DEEP = np.array([0x4A, 0x2A, 0x0C], float)
SHADOW = np.array([0x8A, 0x52, 0x12], float)
MID = np.array([0xE0, 0x9A, 0x1A], float)
HIGH = np.array([0xFF, 0xD2, 0x3F], float)
HOT = np.array([0xFF, 0xF6, 0xD8], float)


def ramp(v):
    """Luminance 0..1 -> gold ramp (deep -> shadow -> mid -> highlight)."""
    stops = [(0.0, DEEP), (0.28, SHADOW), (0.58, MID), (0.86, HIGH), (1.0, HIGH)]
    out = np.zeros(v.shape + (3,))
    for (a, ca), (b, cb) in zip(stops[:-1], stops[1:]):
        m = (v >= a) & (v <= b)
        t = ((v - a) / max(b - a, 1e-6))[..., None]
        out[m] = (ca + (cb - ca) * t)[m]
    return out


def main():
    im = np.array(Image.open(SRC).convert("RGBA")).astype(float)
    rgb = im[..., :3] / 255.0
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    # hue in degrees
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    d = np.maximum(mx - mn, 1e-6)
    hue = np.where(mx == r, (g - b) / d % 6.0, np.where(mx == g, (b - r) / d + 2.0, (r - g) / d + 4.0)) * 60.0
    # cyan band 165..215 deg, feathered 12 deg; needs some saturation (feathered 0.06..0.14)
    hw = np.clip(1.0 - np.maximum(0.0, np.maximum(165.0 - hue, hue - 215.0)) / 12.0, 0.0, 1.0)
    sw = np.clip((sat - 0.06) / 0.08, 0.0, 1.0)
    w = hw * sw
    # washed-out bright cyan (the infinity core + glow): white-hot
    lum = 0.30 * r + 0.55 * g + 0.15 * b
    gold = ramp(np.clip(lum * 1.08, 0.0, 1.0))
    hot_w = np.clip((mx - 0.80) / 0.15, 0.0, 1.0) * np.clip((0.45 - sat) / 0.25, 0.0, 1.0)
    gold = gold + (HOT - gold) * hot_w[..., None]
    # near-white pixels that are only faintly cyan (the emblem core) also go white-hot even outside the saturation gate
    core_w = np.clip((mx - 0.88) / 0.08, 0.0, 1.0) * hw * np.clip((0.2 - sat) / 0.2 + 0.0, 0.0, 1.0)
    w = np.maximum(w, core_w)
    out = rgb * 255.0 * (1.0 - w[..., None]) + gold * w[..., None]
    res = np.concatenate([np.clip(out, 0, 255), im[..., 3:4]], -1).astype(np.uint8)
    Image.fromarray(res, "RGBA").save(DST)
    print("wrote", DST, res.shape)


if __name__ == "__main__":
    main()
