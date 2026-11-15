"""court_badge_compose.py - WK-65 painted court badges (docs/briefs/court_cards_2026-11-15.md section 6).

Composites ONE shared stadium-screen frame over 11 per-court interior paintings so every badge has a
pixel-identical frame. Offline tool; needs Pillow + numpy + scipy.

  python tools/court_badge_compose.py frame  RAW_FRAME [--out assets/ui/courts/_frame.png]
  python tools/court_badge_compose.py badges [--raw tools/out/wk/court_raw] [--dy id=N ...]
  python tools/court_badge_compose.py sheets [--out-dir tools/out/court_cards]

frame  : alpha>=240 -> 255, defringe (normalised-convolution colour bleed into alpha<0.02), scale uniformly
         so the rim's outer width = 1216 px, place the RECT (not the bbox) centred at (640,400) on a
         1280x800 canvas (shrinks to >=1180 if an ornament would cross y<4), print the hole bbox.
         The hole/socket masks come from a seeded flood of the transparent region (no chroma key, so the
         red rim and gold never go translucent - the reason the brief bans art.py keyout-color here).
badges : per court id in levels/sports_courts.json, crop the raw interior I_<id>.png to the hole aspect
         (centred, optional --dy), Lanczos-resize UNIFORMLY to the hole bbox (asserted), paste through the
         4px-dilated hole mask, add the inner shadow + top sheen (the only code-made effects), paste the
         real in-game ball into the socket, lay the frame on top -> assets/ui/courts/court_<id>.png.
sheets : proof sheets sheet_full / sheet_cardcrop / sheet_480 per brief section 6.6.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CANVAS = (1280, 800)
RECT_W = 1216
RECT_W_MIN = 1180
CHOC = (0x3B, 0x24, 0x1B)
FRAME_PATH = os.path.join(ROOT, "assets", "ui", "courts", "_frame.png")
COURTS_JSON = os.path.join(ROOT, "levels", "sports_courts.json")


def defringe(rgba):
    """Normalised-convolution colour bleed into alpha<0.02 px (radii 4/16/48) so filtering never pulls
    dark/junk RGB out of transparent pixels."""
    a = rgba[..., 3].astype(np.float32) / 255.0
    rgb = rgba[..., :3].astype(np.float32)
    out = rgb.copy()
    todo = a < 0.02
    for r in (4, 16, 48):
        w = ndimage.gaussian_filter(a, r)
        if not todo.any():
            break
        num = np.stack([ndimage.gaussian_filter(rgb[..., c] * a, r) for c in range(3)], -1)
        ok = todo & (w > 1e-3)
        out[ok] = num[ok] / w[ok][:, None]
        todo = todo & ~ok
    out[todo] = CHOC
    res = rgba.copy()
    res[..., :3] = np.clip(out + 0.5, 0, 255).astype(np.uint8)
    return res


def rect_bbox(alpha):
    """Outer rim rect: x-extent from the widest rows, y-extent from rows whose opaque span covers >=60% of
    that width (pylons and the socket are narrow, so they never qualify)."""
    op = alpha >= 128
    cols = np.where(op.any(0))[0]
    x0, x1 = int(cols[0]), int(cols[-1])
    w = x1 - x0 + 1
    rows = np.where(op.sum(1) >= 0.6 * w)[0]
    return x0, int(rows[0]), x1, int(rows[-1])


def masks(alpha):
    """Hole = transparent component containing the canvas centre; socket = largest enclosed transparent
    component whose centroid is above the hole and near the centre line."""
    clear = alpha < 128
    lab, n = ndimage.label(clear)
    h, w = alpha.shape
    hole_id = lab[h // 2, w // 2]
    assert hole_id != 0, "canvas centre is not transparent - frame interior not empty?"
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    hole = lab == hole_id
    hy0 = np.where(hole.any(1))[0][0]
    best, best_sz = None, 0
    for i in range(1, n + 1):
        if i == hole_id or i in border:
            continue
        m = lab == i
        sz = int(m.sum())
        if sz < 200:
            continue
        ys, xs = np.nonzero(m)
        if ys.mean() < hy0 and abs(xs.mean() - w / 2) < 0.08 * w and sz > best_sz:
            best, best_sz = m, sz
    return hole, best


def bbox(m):
    ys, xs = np.nonzero(m)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def cmd_frame(raw, out=FRAME_PATH):
    im = np.array(Image.open(raw).convert("RGBA"))
    a = im[..., 3]
    a[a >= 240] = 255
    im = defringe(im)
    x0, y0, x1, y1 = rect_bbox(im[..., 3])
    obb = bbox(im[..., 3] >= 16)
    rw = x1 - x0 + 1
    rh = y1 - y0 + 1
    print(f"raw: rect ({x0},{y0})-({x1},{y1}) = {rw}x{rh} aspect {rw / rh:.3f}; opaque bbox {obb}")
    target = RECT_W
    while True:
        s = target / rw
        cy = (y0 + y1) / 2.0
        top = 400 + (obb[1] - cy) * s
        bot = 400 + (obb[3] - cy) * s
        if top >= 4 or target <= RECT_W_MIN:
            break
        target -= 4
    if top < 4:
        print(f"WARNING: ornaments reach y={top:.1f} (<4) even at rect width {target}; they will be clipped")
    pim = Image.fromarray(im)
    nw, nh = round(im.shape[1] * s), round(im.shape[0] * s)
    pim = pim.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", CANVAS, CHOC + (0,))
    ox = round(640 - ((x0 + x1) / 2.0) * s)
    oy = round(400 - cy * s)
    canvas.alpha_composite(pim, (ox, oy)) if (ox >= 0 and oy >= 0) else canvas.paste(pim, (ox, oy), pim)
    arr = np.array(canvas)
    arr[..., 3][arr[..., 3] >= 240] = 255
    arr = defringe(arr)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.fromarray(arr).save(out)
    hole, sock = masks(arr[..., 3])
    rb = rect_bbox(arr[..., 3])
    print(f"scale {s:.4f}; rect width {target}; placed rect {rb}; ornaments top y={top:.1f}, bottom y={bot:.1f}")
    hb = bbox(hole)
    print(f"HOLE bbox {hb} = {hb[2] - hb[0] + 1}x{hb[3] - hb[1] + 1} aspect {(hb[2] - hb[0] + 1) / (hb[3] - hb[1] + 1):.3f}")
    if sock is not None:
        sb = bbox(sock)
        print(f"SOCKET bbox {sb} = {sb[2] - sb[0] + 1}x{sb[3] - sb[1] + 1}")
    else:
        print("WARNING: no enclosed socket found")
    print(f"saved {out}")


def courts():
    d = json.load(open(COURTS_JSON, encoding="utf-8"))
    return [(c["id"], c["sport"]) for c in d["courts"]]


def fit_interior(raw, hw, hh, dy=0):
    im = Image.open(raw).convert("RGB")
    W, H = im.size
    asp = hw / hh
    cw, ch = W, W / asp
    if ch > H:
        ch, cw = H, H * asp
    cx0 = (W - cw) / 2.0
    cy0 = (H - ch) / 2.0 + dy
    cy0 = max(0.0, min(H - ch, cy0))
    box = (cx0, cy0, cx0 + cw, cy0 + ch)
    sx, sy = hw / cw, hh / ch
    assert abs(sx - sy) / sx < 0.002, f"non-uniform interior scale {sx} vs {sy}"
    return im.resize((hw, hh), Image.LANCZOS, box=box), sx


def cmd_badges(rawdir, dys):
    frame = Image.open(FRAME_PATH).convert("RGBA")
    fa = np.array(frame)
    hole, sock = masks(fa[..., 3])
    hole_d = ndimage.binary_dilation(hole, iterations=4)
    sock_d = ndimage.binary_dilation(sock, iterations=4)
    hx0, hy0, hx1, hy1 = bbox(hole_d)
    hw, hh = hx1 - hx0 + 1, hy1 - hy0 + 1
    # inner shadow: chocolate 30%, 14px blur, offset 4px down, clipped to the hole
    outside = (~hole).astype(np.float32)
    sh = ndimage.shift(outside, (4, 0), order=0, cval=1.0)
    sh = ndimage.gaussian_filter(sh, 14 / 2.0)
    sh_a = np.clip(sh * 0.30, 0, 1) * hole_d
    # top sheen: 8% white on the upper 25% of the hole, one gradient
    yy = np.arange(CANVAS[1], dtype=np.float32)[:, None]
    g = np.clip(1.0 - (yy - hy0) / (0.25 * hh), 0, 1) * (yy >= hy0)
    sheen_a = (0.08 * g * np.ones((1, CANVAS[0]), np.float32)) * hole_d
    sb = bbox(sock)
    sdia = max(sb[2] - sb[0] + 1, sb[3] - sb[1] + 1) + 6
    scx, scy = (sb[0] + sb[2]) / 2.0, (sb[1] + sb[3]) / 2.0
    sw, sh_ = sb[2] - sb[0] + 1, sb[3] - sb[1] + 1
    if sh_ < sw:  # the gold join cap overlaps the ring's lower edge: centre the ball on the ring circle
        scy = sb[1] + sw / 2.0
    out_dir = os.path.dirname(FRAME_PATH)
    for cid, sport in courts():
        raw = os.path.join(rawdir, f"I_{cid}.png")
        if not os.path.exists(raw):
            print(f"SKIP {cid}: no {raw}")
            continue
        interior, s = fit_interior(raw, hw, hh, dys.get(cid, 0))
        base = np.zeros((CANVAS[1], CANVAS[0], 4), np.float32)
        base[hy0:hy1 + 1, hx0:hx1 + 1, :3] = np.array(interior, np.float32)
        base[..., 3] = hole_d * 255.0
        rgb = base[..., :3]
        rgb[:] = rgb * (1 - sh_a[..., None]) + np.array(CHOC, np.float32) * sh_a[..., None]
        rgb[:] = rgb * (1 - sheen_a[..., None]) + 255.0 * sheen_a[..., None]
        comp = Image.fromarray(np.clip(base + 0.5, 0, 255).astype(np.uint8))
        ball_p = os.path.join(ROOT, "assets", "objects", "ball_beach.png" if sport == "dropshot" else "ball.png")
        ball = Image.open(ball_p).convert("RGBA")
        bw = sdia
        bh = round(ball.size[1] * bw / ball.size[0])
        ball = ball.resize((bw, bh), Image.LANCZOS)
        layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        layer.paste(ball, (round(scx - bw / 2.0), round(scy - bh / 2.0)), ball)
        la = np.array(layer)
        la[..., 3] = (la[..., 3].astype(np.float32) * sock_d).astype(np.uint8)
        comp.alpha_composite(Image.fromarray(la))
        comp.alpha_composite(frame)
        arr = defringe(np.array(comp))
        p = os.path.join(out_dir, f"court_{cid}.png")
        Image.fromarray(arr).save(p)
        print(f"court_{cid}.png  interior scale {s:.4f} (uniform)  dy={dys.get(cid, 0)}")


def card_crop(im, w=366, h=165):
    s = max(w / im.size[0], h / im.size[1])
    r = im.resize((round(im.size[0] * s), round(im.size[1] * s)), Image.LANCZOS)
    x = (r.size[0] - w) // 2
    y = (r.size[1] - h) // 2
    return r.crop((x, y, x + w, y + h))


def overlay_chips(c):
    d = ImageDraw.Draw(c, "RGBA")
    w, h = c.size
    d.rectangle((0, 0, int(w * 0.22), int(h * 0.28)), fill=(128, 128, 128, 200))
    # LOCKED sash: ~170px screen diagonal on a 366-wide slot
    t = 0.46 * h
    d.polygon([(w - t, 0), (w, 0), (w, t)], fill=(128, 128, 128, 200))
    return c


def preview(im, w=604, h=320, bg=(60, 40, 90)):
    pv = Image.new("RGBA", (w, h), bg + (255,))
    s = min(w / im.size[0], h / im.size[1])
    r = im.resize((round(im.size[0] * s), round(im.size[1] * s)), Image.LANCZOS)
    pv.alpha_composite(r, ((w - r.size[0]) // 2, (h - r.size[1]) // 2))
    return pv


def cmd_sheets(out_dir, wk_sheet):
    ids = [c for c, _ in courts()]
    ims = [Image.open(os.path.join(os.path.dirname(FRAME_PATH), f"court_{c}.png")).convert("RGBA") for c in ids]
    os.makedirs(out_dir, exist_ok=True)
    # full
    tw, th = 640, 400
    full = Image.new("RGBA", (tw * 4, th * 3), (40, 40, 48, 255))
    for i, im in enumerate(ims):
        full.alpha_composite(im.resize((tw, th), Image.LANCZOS), ((i % 4) * tw, (i // 4) * th))
    full.save(os.path.join(out_dir, "sheet_full.png"))
    # card crop with chips, shelf order
    cw, ch, pad = 366, 165, 12
    cc = Image.new("RGBA", (pad + 4 * (cw + pad), pad + 3 * (ch + pad)), (40, 40, 48, 255))
    for i, im in enumerate(ims):
        cc.alpha_composite(overlay_chips(card_crop(im)), (pad + (i % 4) * (cw + pad), pad + (i // 4) * (ch + pad)))
    cc.save(os.path.join(out_dir, "sheet_cardcrop.png"))
    a = full.resize((full.size[0] // 4, full.size[1] // 4), Image.LANCZOS)
    b = cc.resize((cc.size[0] // 4, cc.size[1] // 4), Image.LANCZOS)
    s480 = Image.new("RGBA", (max(a.size[0], b.size[0]), a.size[1] + b.size[1] + 8), (40, 40, 48, 255))
    s480.alpha_composite(a, (0, 0))
    s480.alpha_composite(b, (0, a.size[1] + 8))
    s480.save(os.path.join(out_dir, "sheet_480.png"))
    # WK sheet: per court row = card crop (1920 scale) | preview 604x320 | card at 480 squint | preview at 480
    rows = []
    for im in ims:
        card = overlay_chips(card_crop(im))
        pv = preview(im)
        card4 = card.resize((card.size[0] // 4, card.size[1] // 4), Image.LANCZOS)
        pv4 = pv.resize((pv.size[0] // 4, pv.size[1] // 4), Image.LANCZOS)
        rows.append((card, pv, card4, pv4))
    rh = 320 + 10
    colx = [10, 10 + 366 + 16, 10 + 366 + 16 + 604 + 16, 10 + 366 + 16 + 604 + 16 + 92 + 16]
    W = colx[3] + 151 + 10
    half = (len(rows) + 1) // 2
    sheet = Image.new("RGBA", (W * 2, 10 + half * rh), (40, 40, 48, 255))
    for i, (card, pv, card4, pv4) in enumerate(rows):
        bx = (i // half) * W
        y = 10 + (i % half) * rh
        sheet.alpha_composite(card, (bx + colx[0], y + (320 - 165) // 2))
        sheet.alpha_composite(pv, (bx + colx[1], y))
        sheet.alpha_composite(card4, (bx + colx[2], y + (320 - 41) // 2))
        sheet.alpha_composite(pv4, (bx + colx[3], y + (320 - 80) // 2))
    os.makedirs(os.path.dirname(wk_sheet), exist_ok=True)
    sheet.convert("RGB").save(wk_sheet)
    print("sheets written:", out_dir, wk_sheet)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    cmd = argv[1]
    if cmd == "frame":
        out = argv[argv.index("--out") + 1] if "--out" in argv else FRAME_PATH
        cmd_frame(argv[2], out)
    elif cmd == "badges":
        raw = argv[argv.index("--raw") + 1] if "--raw" in argv else os.path.join(ROOT, "tools", "out", "wk", "court_raw")
        dys = {}
        for i, a in enumerate(argv):
            if a == "--dy":
                k, v = argv[i + 1].split("=")
                dys[k] = int(v)
        cmd_badges(raw, dys)
    elif cmd == "sheets":
        od = argv[argv.index("--out-dir") + 1] if "--out-dir" in argv else os.path.join(ROOT, "tools", "out", "court_cards")
        cmd_sheets(od, os.path.join(ROOT, "tools", "out", "wk", "WK-65_sheet.png"))
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
