#!/usr/bin/env python3
"""make_particles.py - generate the small additive-blend VFX textures for GottaBounce.

Produces the PNGs the code already references behind ResourceLoader.exists guards
(Player.gd exhaust, Juice.gd _super_blast / _death_burst / _dust_puff / _shockwave) plus a
soft glow for the super-charge halo. All are WHITE-RGB masks: the shape lives in the alpha
channel so additive blend + the per-emitter color_ramp / modulate does the tinting. This keeps
one texture reusable across warm-flame / cyan-afterburner / danger-red charge, etc.

Glossy-Toybox: soft, glowy, bold silhouettes that survive far zoom. Output -> assets/particles/.
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "particles")
OUT = os.path.abspath(OUT)


def _grid(size):
    # normalized coords in [-1, 1], plus radius
    ax = (np.arange(size) + 0.5) / size * 2.0 - 1.0
    xx, yy = np.meshgrid(ax, ax)
    r = np.sqrt(xx * xx + yy * yy)
    return xx, yy, r


def _save(alpha, name, warm=None):
    """alpha: HxW float 0..1. warm: optional (r,g,b) 0..1 baked tint, else white."""
    size = alpha.shape[0]
    a = np.clip(alpha, 0.0, 1.0)
    if warm is None:
        rgb = np.ones((size, size, 3), dtype=np.float32)
    else:
        rgb = np.ones((size, size, 3), dtype=np.float32) * np.array(warm, dtype=np.float32)
    img = np.zeros((size, size, 4), dtype=np.uint8)
    img[..., 0] = (rgb[..., 0] * 255).astype(np.uint8)
    img[..., 1] = (rgb[..., 1] * 255).astype(np.uint8)
    img[..., 2] = (rgb[..., 2] * 255).astype(np.uint8)
    img[..., 3] = (a * 255).astype(np.uint8)
    path = os.path.join(OUT, name)
    Image.fromarray(img, "RGBA").save(path)
    print(f"wrote {path} ({size}x{size})")


def fire(size=96):
    # soft warm blob with a hot white plateau core -> dense overlapping particles read as one
    # continuous tongue of flame. White-hot centre baked slightly; ramp/modulate does the orange.
    _, _, r = _grid(size)
    core = np.exp(-((r / 0.30) ** 2))          # bright body
    plateau = np.clip(core * 1.5, 0.0, 1.0)    # flatten the centre to a hot core
    _save(plateau, "fire_01.png")


def spark(size=48):
    # tight little glow-dot for sparks / dust kicks
    _, _, r = _grid(size)
    a = np.exp(-((r / 0.28) ** 2)) ** 1.4
    _save(a, "spark_01.png")


def glow(size=128):
    # wide, very soft filled halo for the super-charge gather (§3)
    _, _, r = _grid(size)
    a = np.exp(-((r / 0.55) ** 2))
    _save(a, "glow_01.png")


def light_ring(size=128):
    # bright soft-edged annulus -> reads as an expanding shockwave ring when a sprite is scaled up
    _, _, r = _grid(size)
    R = 0.62
    w = 0.11
    a = np.exp(-(((r - R) / w) ** 2))
    _save(a, "light_01.png")


def muzzle(size=128):
    # bright cannon-flash star: hot core + 4 long axis spikes + 4 short diagonal spikes
    xx, yy, r = _grid(size)
    core = np.exp(-((r / 0.16) ** 2))
    a = core.copy()
    # long axis spikes (up/down/left/right)
    axis_len, axis_w = 0.52, 0.05
    a = np.maximum(a, np.exp(-((yy / axis_len) ** 2)) * np.exp(-((xx / axis_w) ** 2)))
    a = np.maximum(a, np.exp(-((xx / axis_len) ** 2)) * np.exp(-((yy / axis_w) ** 2)))
    # short diagonal spikes
    diag_len, diag_w = 0.34, 0.045
    d1 = (xx + yy) / np.sqrt(2.0)
    d2 = (xx - yy) / np.sqrt(2.0)
    a = np.maximum(a, np.exp(-((d1 / diag_len) ** 2)) * np.exp(-((d2 / diag_w) ** 2)))
    a = np.maximum(a, np.exp(-((d2 / diag_len) ** 2)) * np.exp(-((d1 / diag_w) ** 2)))
    _save(np.clip(a, 0.0, 1.0), "muzzle_01.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    fire()
    spark()
    glow()
    light_ring()
    muzzle()
    print("done ->", OUT)
