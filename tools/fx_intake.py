"""Ghost-goat FX intake: haze clean + defringe + trim + resize + pad.
usage: python tools/fx_intake.py IN OUT --width W | --maxdim M  [--pad P] [--keep-r R]
- haze clean: alpha pixels farther than R px from the solid (a>=128) body are zeroed (stray low-alpha dark haze);
  alpha >= 240 snapped to 255 (generations come back at ~253 inside the body).
- defringe: RGB of alpha-0 px filled by normalized-convolution colour bleed from the body (no dark junk to bleed at
  bilinear filtering / shader taps).
"""
import argparse
import numpy as np
from PIL import Image, ImageFilter

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("dst")
ap.add_argument("--width", type=int, default=0)
ap.add_argument("--maxdim", type=int, default=0)
ap.add_argument("--pad", type=int, default=2)
ap.add_argument("--keep-r", type=int, default=7)
args = ap.parse_args()

im = Image.open(args.src).convert("RGBA")
a = np.asarray(im).astype(np.float32)
al = a[..., 3].copy()
solid = Image.fromarray(((al >= 128) * 255).astype(np.uint8))
near = np.asarray(solid.filter(ImageFilter.MaxFilter(2 * args.keep_r + 1))) > 0
al[~near] = 0
al[al >= 240] = 255
a[..., 3] = al


def defringe(arr):
    rgb = arr[..., :3] / 255.0
    w = arr[..., 3:4] / 255.0
    filled = rgb.copy()
    mask = w[..., 0] < 0.02
    for r in (4, 16, 48):
        def blur(x):
            out = []
            for c in range(x.shape[2]):
                ch = Image.fromarray((np.clip(x[..., c], 0, 1) * 255 + 0.5).astype(np.uint8), "L")
                out.append(np.asarray(ch.filter(ImageFilter.GaussianBlur(r)), dtype=np.float32) / 255)
            return np.stack(out, -1)
        num = blur(rgb * w); den = blur(w)
        bled = num / np.maximum(den, 1e-6)
        ok = (den[..., 0] > 0.5 / 255) & mask
        filled[ok] = bled[ok]
        mask = mask & ~ok
    # anything still unfilled (far corners): body mean colour
    if mask.any():
        filled[mask] = (rgb * w).sum((0, 1)) / max(w.sum(), 1e-6)
    return np.concatenate([filled * 255, arr[..., 3:4]], -1)


a = defringe(a)
img = Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8), "RGBA")
bbox = img.getchannel("A").getbbox()
img = img.crop(bbox)
if args.width:
    s = args.width / img.size[0]
elif args.maxdim:
    s = args.maxdim / max(img.size)
else:
    s = 1.0
if abs(s - 1) > 1e-6:
    img = img.resize((max(1, round(img.size[0] * s)), max(1, round(img.size[1] * s))), Image.LANCZOS)
# re-defringe after resize (Lanczos pulls alpha-0 RGB into the edge), then pad with edge-bled RGB
p = args.pad
arr = np.asarray(img).astype(np.float32)
padded = np.zeros((arr.shape[0] + 2 * p, arr.shape[1] + 2 * p, 4), np.float32)
padded[p:p + arr.shape[0], p:p + arr.shape[1]] = arr
padded = defringe(padded)
out = Image.fromarray(np.clip(padded + 0.5, 0, 255).astype(np.uint8), "RGBA")
out.save(args.dst)
print("wrote", args.dst, out.size)
