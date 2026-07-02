#!/usr/bin/env python3
"""art.py - asset intake/processing for generated art (see docs/PIPELINE.md).

Commands:
  trim IN [OUT]              crop away fully-transparent margins (+2px padding)
  keyout IN [OUT] [--tol N]  flood-fill white/solid bg from corners -> transparent, then trim
  resize IN OUT WIDTH        proportional resize (lanczos), width in px
  info IN...                 report size, alpha coverage, bbox of opaque pixels
  sheet IN_DIR OUT COLS      pack same-size sprites into a sheet (row-major)
  check IN                   validate: has alpha? trimmed? report verdict + issues

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


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    cmd, args = sys.argv[1], sys.argv[2:]
    kw = {}
    if "--tol" in args:
        i = args.index("--tol")
        kw["tol"] = int(args[i + 1])
        args = args[:i] + args[i + 2:]
    fn = {"trim": trim, "keyout": keyout, "resize": resize, "info": info,
          "check": check, "sheet": sheet}.get(cmd)
    if fn is None:
        print(f"unknown command {cmd}\n{__doc__}")
        sys.exit(2)
    sys.exit(fn(*args, **kw))
