#!/usr/bin/env python3
"""art.py - asset intake/processing for generated art (see docs/PIPELINE.md).

Commands:
  trim IN [OUT]              crop away fully-transparent margins (+2px padding)
  keyout IN [OUT] [--tol N]  flood-fill white/solid bg from corners -> transparent, then trim
  resize IN OUT WIDTH        proportional resize (lanczos), width in px
  info IN...                 report size, alpha coverage, bbox of opaque pixels
  sheet IN_DIR OUT COLS      pack same-size sprites into a sheet (row-major)
  check IN                   validate: has alpha? trimmed? report verdict + issues
  keyout-color IN [OUT] [--key ff00ff] [--tol 90] [--no-trim]
                             GLOBAL chroma key (reaches enclosed holes the corner flood can't):
                             alpha from key-chroma, despill, edge pull to outline chocolate,
                             transparent RGB = chocolate (no fringe at filtering), then trim

Typical intake for a ChatGPT-generated sprite:
  python tools/art.py keyout downloaded.png assets/characters/bouncer_pink_idle.png
  python tools/art.py check assets/characters/bouncer_pink_idle.png
"""
import sys
from pathlib import Path
from PIL import Image


def _load(path):
    return Image.open(path).convert("RGBA")


def _bbox_opaque(img, thresh=8):
    alpha = img.getchannel("A").point(lambda a: 255 if a > thresh else 0)
    return alpha.getbbox()


def trim(src, dst=None, pad=2):
    img = _load(src)
    box = _bbox_opaque(img)
    if box is None:
        print(f"ERROR: {src} is fully transparent")
        return 1
    left = max(box[0] - pad, 0)
    top = max(box[1] - pad, 0)
    right = min(box[2] + pad, img.width)
    bottom = min(box[3] + pad, img.height)
    out = img.crop((left, top, right, bottom))
    dst = dst or src
    out.save(dst)
    print(f"trimmed {src}: {img.size} -> {out.size} -> {dst}")
    return 0


def keyout(src, dst=None, tol=18):
    """Flood-fill from all four corners, removing the connected background color."""
    img = _load(src)
    px = img.load()
    w, h = img.size
    from collections import deque
    visited = bytearray(w * h)
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for cx, cy in corners:
        bg = px[cx, cy][:3]
        if px[cx, cy][3] == 0:
            continue  # corner already transparent
        q = deque([(cx, cy)])
        while q:
            x, y = q.popleft()
            i = y * w + x
            if visited[i]:
                continue
            visited[i] = 1
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > tol * 3:
                continue
            px[x, y] = (r, g, b, 0)
            if x > 0: q.append((x - 1, y))
            if x < w - 1: q.append((x + 1, y))
            if y > 0: q.append((x, y - 1))
            if y < h - 1: q.append((x, y + 1))
    dst = dst or src
    img.save(dst)
    print(f"keyed out bg: {src} -> {dst}")
    return trim(dst)


def resize(src, dst, width):
    img = _load(src)
    width = int(width)
    height = round(img.height * width / img.width)
    img.resize((width, height), Image.LANCZOS).save(dst)
    print(f"resized {src}: {img.size} -> ({width}, {height}) -> {dst}")
    return 0


def info(*paths):
    for p in paths:
        img = _load(p)
        alpha = img.getchannel("A")
        hist = alpha.histogram()
        transparent = hist[0]
        total = img.width * img.height
        box = _bbox_opaque(img)
        print(f"{p}: {img.size}, transparent {100*transparent/total:.1f}%, opaque bbox {box}")
    return 0


def check(src):
    img = _load(src)
    issues = []
    alpha = img.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo == 255:
        issues.append("no transparency at all (solid image) — needs keyout?")
    box = _bbox_opaque(img)
    if box:
        margins = (box[0], box[1], img.width - box[2], img.height - box[3])
        if max(margins) > 12:
            issues.append(f"untrimmed margins {margins} — run trim")
    # halo check: count nearly-transparent-but-colored edge pixels
    if img.width * img.height > 0 and lo < 255:
        semi = sum(alpha.histogram()[1:32])
        if semi > img.width * img.height * 0.05:
            issues.append("large semi-transparent fringe — possible white halo from keying")
    if issues:
        print(f"CHECK {src}: ISSUES")
        for i in issues:
            print(f"  - {i}")
        return 1
    print(f"CHECK {src}: OK ({img.size})")
    return 0


def sheet(in_dir, out, cols):
    paths = sorted(Path(in_dir).glob("*.png"))
    if not paths:
        print("no PNGs found")
        return 1
    imgs = [_load(p) for p in paths]
    w = max(i.width for i in imgs)
    h = max(i.height for i in imgs)
    cols = int(cols)
    rows = (len(imgs) + cols - 1) // cols
    canvas = Image.new("RGBA", (cols * w, rows * h), (0, 0, 0, 0))
    for n, img in enumerate(imgs):
        x = (n % cols) * w + (w - img.width) // 2
        y = (n // cols) * h + (h - img.height) // 2
        canvas.paste(img, (x, y))
    canvas.save(out)
    print(f"sheet: {len(imgs)} sprites @ {w}x{h} -> {out} ({cols}x{rows})")
    return 0


def keyout_color(src, dst=None, key="ff00ff", tol=90, no_trim=False, outline="3b241b"):
    """Global chroma key for generations on a solid key colour (brief sports_nets_2026-11-15 s7).

    Works for subjects whose fill is greyscale/near-neutral with a chocolate outline (every
    tintable asset). Per pixel:
      s = chroma of the pixel projected on the key's chroma direction (1.0 = pure key, ~0 = neutral)
      - s >= S_HI or RGB distance to key <= tol  -> alpha 0
      - s <= S_LO                                 -> alpha 255
      - between                                   -> alpha ramps linearly (anti-aliased edge)
    Despill: the key-direction chroma (s * key_chroma) is subtracted from every pixel, then the
    brightness the key added is removed by un-mixing P = a*F + (1-a)*K.  Partial-alpha pixels are
    pulled toward the outline chocolate (every edge borders the outline).  Alpha-0 pixels get
    chocolate RGB so bilinear filtering / mipmaps never bleed the key colour back in.
    """
    import numpy as np
    S_LO, S_HI = 0.10, 0.80
    kk = np.array([int(key[i:i + 2], 16) for i in (0, 2, 4)], np.float32)
    oc = np.array([int(outline[i:i + 2], 16) for i in (0, 2, 4)], np.float32)
    img = _load(src)
    arr = np.asarray(img).astype(np.float32)
    rgb, a0 = arr[..., :3], arr[..., 3] / 255.0
    kc = kk - kk.mean()
    kc2 = float((kc * kc).sum())
    if kc2 < 1:
        print("ERROR: key colour is neutral grey; chroma key needs a saturated key")
        return 1
    chroma = rgb - rgb.mean(-1, keepdims=True)
    s = np.clip((chroma @ kc) / kc2, 0.0, 1.0)
    dist = np.sqrt(((rgb - kk) ** 2).sum(-1))
    alpha = np.clip((S_HI - s) / (S_HI - S_LO), 0.0, 1.0)
    alpha[(dist <= tol) | (s >= S_HI)] = 0.0
    # despill: remove key chroma, then un-mix the key's brightness from partial pixels
    f = rgb - s[..., None] * kc
    am = np.maximum(alpha, 0.25)[..., None]
    unmixed = (f - (1.0 - am) * (kk.mean())) / am
    partial = (alpha > 0) & (alpha < 1)
    f[partial] = unmixed[partial]
    # pull partial edges toward the outline colour (edges border the chocolate outline)
    t = np.where(partial, np.sqrt(1.0 - alpha), 0.0)[..., None]
    f = f * (1 - t) + oc * t
    f[alpha <= 0] = oc
    alpha = alpha * a0
    out = np.concatenate([np.clip(f, 0, 255), (alpha * 255.0)[..., None]], -1)
    res = Image.fromarray((out + 0.5).astype(np.uint8), "RGBA")
    dst = dst or src
    res.save(dst)
    al8 = (alpha * 255).astype(np.uint8)
    # residual fringe audit: visible pixels that still carry key chroma after despill
    fc = np.asarray(res).astype(np.float32)[..., :3]
    s2 = np.clip(((fc - fc.mean(-1, keepdims=True)) @ kc) / kc2, 0, 1)
    fringe = int(((al8 > 16) & (s2 > 0.12)).sum())
    print(f"chroma-keyed #{key} (tol {tol}): {src} -> {dst}; transparent "
          f"{100 * (al8 == 0).mean():.1f}%, partial {100 * ((al8 > 0) & (al8 < 255)).mean():.1f}%, "
          f"residual key-tinted px {fringe}")
    if no_trim:
        return 0
    return trim(dst)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    cmd, args = sys.argv[1], sys.argv[2:]
    kw = {}
    if cmd == "keyout-color":
        if "--key" in args:
            i = args.index("--key")
            kw["key"] = args[i + 1].lstrip("#").lower()
            args = args[:i] + args[i + 2:]
        if "--no-trim" in args:
            kw["no_trim"] = True
            args.remove("--no-trim")
    if "--tol" in args:
        i = args.index("--tol")
        kw["tol"] = int(args[i + 1])
        args = args[:i] + args[i + 2:]
    fn = {"trim": trim, "keyout": keyout, "resize": resize, "info": info,
          "check": check, "sheet": sheet, "keyout-color": keyout_color}.get(cmd)
    if fn is None:
        print(f"unknown command {cmd}\n{__doc__}")
        sys.exit(2)
    sys.exit(fn(*args, **kw))
