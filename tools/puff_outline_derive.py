"""Derive ghost_puff_stroke.png + ghost_puff_dash.png from ghost_puff.png alpha (brief WK-37b E7).
usage: python tools/puff_outline_derive.py BODY STROKE_OUT DASH_OUT [--r 80] [--n 14] [--duty 0.55] [--world 180] [--body-w 1024] [--zoom 0.46]
Stroke = white ring: alpha dilated R px (true Euclidean, antialiased) minus the original alpha. Same canvas => pixel-aligned.
Dash = stroke x dash mask. Dashes are spaced uniformly by ARC LENGTH along the ring midline (an angular mask around the
centroid gives ~2x longer dashes at the ends than on top of a 2.8:1 cloud); dash phase index is by angle about centroid.
"""
import argparse
import numpy as np
from PIL import Image
from scipy import ndimage

ap = argparse.ArgumentParser()
ap.add_argument("body"); ap.add_argument("stroke"); ap.add_argument("dash")
ap.add_argument("--r", type=float, default=80)
ap.add_argument("--n", type=int, default=14)
ap.add_argument("--duty", type=float, default=0.55)
ap.add_argument("--world", type=float, default=180)
ap.add_argument("--body-w", type=float, default=1024)
ap.add_argument("--zoom", type=float, default=0.46)
args = ap.parse_args()

im = Image.open(args.body).convert("RGBA")
A = np.asarray(im)[..., 3].astype(np.float32) / 255.0
H, W = A.shape
body = A >= 0.5
D = ndimage.distance_transform_edt(~body)  # 0 inside body, px distance outside
dil = np.clip(args.r + 0.5 - D, 0, 1)
ring = np.clip(dil * (1.0 - A), 0, 1)
if (ring[0].max() > 0 or ring[-1].max() > 0 or ring[:, 0].max() > 0 or ring[:, -1].max() > 0):
    raise SystemExit("stroke touches canvas edge: pad more")

def save_white(alpha, path):
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(path)

save_white(ring, args.stroke)

# arc-length parameterisation of the ring midline
cy, cx = ndimage.center_of_mass(body)
ys, xs = np.nonzero(np.abs(D - args.r / 2) < 0.75)
th = np.arctan2(ys - cy, xs - cx)
rr = np.hypot(ys - cy, xs - cx)
NB = 2880
bins = ((th + np.pi) / (2 * np.pi) * NB).astype(int) % NB
rad = np.zeros(NB); cnt = np.zeros(NB)
np.add.at(rad, bins, rr); np.add.at(cnt, bins, 1)
ok = cnt > 0
idx = np.arange(NB)
rad = np.interp(idx, idx[ok], rad[ok] / cnt[ok], period=NB)
ang = -np.pi + (idx + 0.5) / NB * 2 * np.pi
px = cx + rad * np.cos(ang); py = cy + rad * np.sin(ang)
seg = np.hypot(np.diff(px, append=px[0]), np.diff(py, append=py[0]))
cum = np.concatenate([[0], np.cumsum(seg)])  # cum[k] = arc length at start of bin k
perim = cum[-1]
period = perim / args.n

from scipy.spatial import cKDTree
# resample the midline densely by arc length; each ring pixel takes the arc position of its NEAREST midline point,
# so dash cuts are perpendicular to the stroke (a radial cut from the centroid reads as sunburst rays on a wide cloud)
ss = np.arange(0, perim, 0.5)
kk = np.interp(ss, cum, np.arange(NB + 1))
qx = np.interp(kk, np.arange(NB + 1), np.append(px, px[0]))
qy = np.interp(kk, np.arange(NB + 1), np.append(py, py[0]))
tree = cKDTree(np.c_[qx, qy])
ry, rx = np.nonzero(ring > 0)
_, ii = tree.query(np.c_[rx, ry])
s = np.zeros((H, W)); s[ry, rx] = ss[ii]
ph = (s / period) % 1.0  # 0..1 within one period
dash_len = args.duty
# antialiased dash edges (~1.5 px of arc)
aa = 1.5 / period
m = np.clip(np.minimum(ph, dash_len - ph) / aa + 0.5, 0, 1)
save_white(ring * m, args.dash)

scale = args.world / args.body_w
print(f"perimeter(mid) {perim:.0f}src px; period {period:.0f}; dash {period*args.duty:.0f}src px")
print(f"at zoom {args.zoom}: stroke {args.r*scale*args.zoom:.1f} screen px thick, dash {period*args.duty*scale*args.zoom:.1f} screen px long, gap {period*(1-args.duty)*scale*args.zoom:.1f}")
