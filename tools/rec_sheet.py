"""WK-93 recording analysis: contact sheets, per-player overlays, aim/hazard reports, strobes.

Reads a folder written by tools/record_match.ps1 (Godot Movie Maker frames frameNNNNNNNN.png|jpg plus
the MatchRecorder's data.json) and produces:

  sheet.png          contact sheet: every Nth frame from COMBAT start (labelled frame# / t)
  sheet_overlay.png  same frames + per-player overlay (marker, short trail, aim line; thick = super aim)
  aim_report.png     per super-aim window: aim angle per physics tick (unwrapped) + per-tick step vs cap
  traj.png           (--traj) WK-95: per-goat WORLD trajectory over the whole recording, coloured by state:
                     grey = drift/bounce, orange = normal boost, red = super-active, white = super aim; X = death.
                     Overlay markers also get an orange ring while boosting / red ring while super-active.
  strobe.png         (--strobe A:B) one background frame with every frame's pendulum-ball position drawn
                     as numbered dots -> spacing shows speed (bunched = slow apex, spread = fast bottom)
  text summary       (--report) aim windows by bot level, hazard contact/smash counts, event counts

Usage:
  python tools/rec_sheet.py tools/out/rec/<name> [--every 10] [--count 48] [--cols 6] [--thumb 320]
         [--range A:B] [--overlay] [--report] [--strobe A:B] [--compact] [--prefix sheet]
         [--follow N --zoom 0.3]   (zoomed crop that tracks player N, e.g. to watch a super wind-up)

--range A:B uses absolute frame numbers (as printed on the REC stamp / in data.json "f").
--compact converts frame PNGs to JPEG (q90) and deletes the PNGs AFTER the sheets are built (Dropbox-
friendly: ~1.2 MB -> ~0.15 MB per frame). Requires Pillow.
"""
import argparse
import json
import math
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

PCOL = [(255, 95, 168), (74, 168, 255), (84, 201, 74), (255, 201, 63)]
FRAME_RE = re.compile(r"frame(\d+)\.(png|jpg)$", re.I)


def load_frames(d):
    out = {}
    for fn in os.listdir(d):
        m = FRAME_RE.search(fn)
        if m:
            n = int(m.group(1))
            # prefer png if both exist
            if n not in out or fn.lower().endswith(".png"):
                out[n] = os.path.join(d, fn)
    return out


def font(sz):
    for f in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(f, sz)
        except OSError:
            pass
    return ImageFont.load_default()


def parse_range(s):
    a, b = s.split(":")
    return int(a), int(b)


def pick_frames(frames, data, args):
    nums = sorted(frames)
    if not nums:
        return []
    if args.range:
        a, b = parse_range(args.range)
    else:
        a = data.get("combat_frame", -1) if data else -1
        a = nums[0] if a is None or a < 0 else a
        b = nums[-1]
    sel = [n for n in nums if a <= n <= b][:: max(1, args.every)]
    return sel[: args.count]


def by_frame(data):
    return {fr["f"]: fr for fr in data.get("frames", [])} if data else {}


def draw_overlay(img, sample, history, scale):
    d = ImageDraw.Draw(img, "RGBA")
    if not sample:
        return
    # pendulum balls
    for h in sample.get("hz", []):
        x, y = h["sx"] * scale, h["sy"] * scale
        r = 6
        d.ellipse([x - r, y - r, x + r, y + r], outline=(255, 60, 60, 255), width=2)
    for p in sample.get("p", []):
        if p.get("dead") or not p.get("vis", True):
            continue
        c = PCOL[p["i"] % 4]
        # trail from history (previous samples)
        pts = []
        for h in history:
            for q in h.get("p", []):
                if q["i"] == p["i"] and not q.get("dead"):
                    pts.append((q["sx"] * scale, q["sy"] * scale))
        if len(pts) >= 2:
            d.line(pts, fill=c + (170,), width=2)
        x, y = p["sx"] * scale, p["sy"] * scale
        r = 5
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (255,), outline=(0, 0, 0, 255))
        a = math.radians(p["a"])
        L = 34 if p.get("sa") else 16
        w = 4 if p.get("sa") else 2
        d.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=(255, 255, 255, 255) if p.get("sa") else c + (255,), width=w)
        if p.get("stun"):
            d.ellipse([x - 9, y - 9, x + 9, y + 9], outline=(255, 255, 255, 220), width=1)
        if p.get("sup"):      # WK-95: super-active (the attack) = red ring
            d.ellipse([x - 11, y - 11, x + 11, y + 11], outline=(235, 40, 40, 255), width=3)
        elif p.get("b"):      # WK-95: normal boost (flight) = orange ring
            d.ellipse([x - 9, y - 9, x + 9, y + 9], outline=(255, 150, 30, 255), width=2)


def traj_plot(data, path, size=1600):
    """WK-95: world-space trajectory per goat, segments coloured by flight state (see module doc)."""
    fr = [f for f in data.get("frames", []) if f.get("st") in ("COMBAT", "SUDDEN_DEATH")]
    pts = [(p["x"], p["y"]) for f in fr for p in f["p"] if not p.get("dead")]
    if not pts:
        return None
    x0 = min(q[0] for q in pts) - 100
    x1 = max(q[0] for q in pts) + 100
    y0 = min(q[1] for q in pts) - 100
    y1 = max(q[1] for q in pts) + 100
    sc = size / max(x1 - x0, y1 - y0)
    W, H = int((x1 - x0) * sc), int((y1 - y0) * sc) + 40
    img = Image.new("RGB", (max(W, 400), H), (24, 28, 38))
    d = ImageDraw.Draw(img)
    f = font(16)
    d.text((8, 6), "%s  trajectory (world)   grey drift  orange BOOST  red SUPER-ACTIVE  white super aim  x death"
           % data.get("meta", {}).get("name", ""), fill=(230, 230, 230), font=f)
    cols = {"drift": (120, 120, 130), "boost": (255, 150, 30), "super": (235, 40, 40), "aim": (255, 255, 255)}
    prev = {}
    for f_ in fr:
        for p in f_["p"]:
            i = p["i"]
            if p.get("dead"):
                if i in prev:
                    px, py = prev.pop(i)
                    d.line([(px - 6, py - 6), (px + 6, py + 6)], fill=PCOL[i % 4], width=3)
                    d.line([(px - 6, py + 6), (px + 6, py - 6)], fill=PCOL[i % 4], width=3)
                continue
            q = ((p["x"] - x0) * sc, (p["y"] - y0) * sc + 40)
            st = "aim" if p.get("sa") else ("super" if p.get("sup") else ("boost" if p.get("b") else "drift"))
            if i in prev and math.dist(prev[i], q) < 120 * sc + 40:
                d.line([prev[i], q], fill=cols[st], width=3 if st != "drift" else 2)
            prev[i] = q
    for f_ in fr[:1]:
        for p in f_["p"]:
            q = ((p["x"] - x0) * sc, (p["y"] - y0) * sc + 40)
            d.ellipse([q[0] - 7, q[1] - 7, q[0] + 7, q[1] + 7], fill=PCOL[p["i"] % 4], outline=(0, 0, 0))
    img.save(path)
    return path


def contact_sheet(frames, sel, data, args, overlay, path):
    if not sel:
        return None
    fr0 = Image.open(frames[sel[0]])
    W, H = fr0.size
    tw = args.thumb
    scale = tw / W
    # data sx/sy are WINDOW pixels; Movie Maker frames are rendered at the project viewport size
    win_w = float((data or {}).get("meta", {}).get("win_w", W) or W)
    oscale = tw / win_w
    th = int(H * scale)
    cols = args.cols
    rows = math.ceil(len(sel) / cols)
    lab = 20
    sheet = Image.new("RGB", (cols * tw, rows * (th + lab)), (18, 16, 22))
    fmap = by_frame(data)
    keys = sorted(fmap)
    f = font(13)
    for k, n in enumerate(sel):
        s = fmap.get(n)
        src = Image.open(frames[n]).convert("RGB")
        if args.follow >= 0 and s:
            # zoomed crop centred on player `follow` (window px -> frame px), same aspect as the frame
            pq = [q for q in s.get("p", []) if q["i"] == args.follow]
            if pq:
                k2 = W / win_w
                cw, ch = int(W * args.zoom), int(H * args.zoom)
                cx = min(max(int(pq[0]["sx"] * k2) - cw // 2, 0), W - cw)
                cy = min(max(int(pq[0]["sy"] * k2) - ch // 2, 0), H - ch)
                src = src.crop((cx, cy, cx + cw, cy + ch)).resize((W, H), Image.LANCZOS)
        im = src.resize((tw, th), Image.LANCZOS)
        if overlay and data and args.follow < 0:
            hist = [fmap[q] for q in keys if n - 12 <= q < n]
            draw_overlay(im, s, hist, oscale)
        x = (k % cols) * tw
        y = (k // cols) * (th + lab)
        sheet.paste(im, (x, y + lab))
        t = s["t"] if s else None
        txt = "f%d" % n + ("  t%.2f" % t if t is not None else "") + ("  %s" % s["st"] if s else "")
        ImageDraw.Draw(sheet).text((x + 4, y + 3), txt, fill=(230, 230, 230), font=f)
    sheet.save(path)
    return path


def aim_report(data, path):
    wins = data.get("aim_windows", [])
    if not wins:
        return None
    wins = sorted(wins, key=lambda w: (w["lvl"], w["f0"]))
    n = len(wins)
    cols = 4
    rows = math.ceil(n / cols)
    cw, ch = 330, 230
    img = Image.new("RGB", (cols * cw, rows * ch), (24, 22, 28))
    d = ImageDraw.Draw(img)
    f = font(12)
    for k, w in enumerate(wins):
        ox, oy = (k % cols) * cw, (k // cols) * ch
        path_deg = w.get("path_deg", [])
        # unwrap
        un = []
        for a in path_deg:
            if un:
                prev = un[-1]
                while a - prev > 180:
                    a -= 360
                while a - prev < -180:
                    a += 360
            un.append(a)
        d.rectangle([ox + 4, oy + 4, ox + cw - 4, oy + ch - 4], outline=(70, 66, 80))
        title = "P%d L%d f%d  %d ticks  max %.1f deg/tick (cap %.1f)  sweep %.0f" % (
            w["who"] + 1, w["lvl"], w["f0"], w["ticks"], w["max_step_deg"], w["cap_deg_tick"], w["sweep_deg"])
        col = (120, 230, 120) if w["max_step_deg"] <= w["cap_deg_tick"] + 0.05 else (255, 90, 90)
        d.text((ox + 8, oy + 7), title, fill=col, font=f)
        # angle plot (top), step plot (bottom)
        px0, px1 = ox + 10, ox + cw - 10
        ay0, ay1 = oy + 26, oy + 130
        sy0, sy1 = oy + 140, oy + ch - 10
        d.rectangle([px0, ay0, px1, ay1], outline=(50, 48, 58))
        d.rectangle([px0, sy0, px1, sy1], outline=(50, 48, 58))
        if len(un) >= 2:
            lo, hi = min(un), max(un)
            if hi - lo < 30:
                mid = (hi + lo) / 2
                lo, hi = mid - 15, mid + 15
            pts = [(px0 + (px1 - px0) * i / (len(un) - 1), ay1 - (ay1 - ay0) * (a - lo) / (hi - lo)) for i, a in enumerate(un)]
            d.line(pts, fill=(255, 220, 90), width=2)
            d.text((px0 + 3, ay0 + 2), "aim %.0f..%.0f deg" % (lo, hi), fill=(150, 150, 160), font=f)
            steps = [abs(un[i] - un[i - 1]) for i in range(1, len(un))]
            smax = max(max(steps), w["cap_deg_tick"] * 1.5, 1.0)
            capy = sy1 - (sy1 - sy0) * w["cap_deg_tick"] / smax
            d.line([(px0, capy), (px1, capy)], fill=(120, 230, 120), width=1)
            spts = [(px0 + (px1 - px0) * i / max(1, len(steps) - 1), sy1 - (sy1 - sy0) * s / smax) for i, s in enumerate(steps)]
            if len(spts) >= 2:
                d.line(spts, fill=(255, 120, 120), width=1)
            d.text((px0 + 3, sy0 + 2), "step/tick (green = cap)", fill=(150, 150, 160), font=f)
    img.save(path)
    return path


def strobe(frames, data, rng, path):
    a, b = parse_range(rng)
    fmap = by_frame(data)
    nums = [n for n in sorted(frames) if a <= n <= b]
    if not nums:
        return None
    bg = Image.open(frames[nums[len(nums) // 2]]).convert("RGB")
    W, H = bg.size
    k = W / float(data.get("meta", {}).get("win_w", W) or W)
    d = ImageDraw.Draw(bg, "RGBA")
    f = font(11)
    prev = None
    for n in nums:
        s = fmap.get(n)
        if not s or not s.get("hz"):
            continue
        h = s["hz"][0]
        x, y = h["sx"] * k, h["sy"] * k
        if prev:
            d.line([prev, (x, y)], fill=(255, 255, 255, 90), width=1)
        r = 5
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 60, 60, 230), outline=(0, 0, 0, 255))
        if (n - a) % 5 == 0:
            d.text((x + 6, y - 6), str(n), fill=(255, 255, 255, 255), font=f)
        prev = (x, y)
    d.text((10, 10), "strobe f%d..f%d: one dot per frame (1/30 s). Bunched = slow, spread = fast." % (a, b), fill=(255, 255, 255, 255), font=font(16))
    bg.save(path)
    return path


def swing(frames, data, rng, every, cols, thumb, d):
    """One pendulum swing: (1) a sheet of frames A..B cropped to the bounding box of hazard 0's ball path
    (static crop, so frame-to-frame ball spacing = speed); (2) ball speed per frame chart."""
    a, b = parse_range(rng)
    fmap = by_frame(data)
    nums = [n for n in sorted(frames) if a <= n <= b and fmap.get(n, {}).get("hz")]
    if not nums:
        return None
    W, H = Image.open(frames[nums[0]]).size
    k = W / float(data.get("meta", {}).get("win_w", W) or W)
    xs = [fmap[n]["hz"][0]["sx"] * k for n in nums]
    ys = [fmap[n]["hz"][0]["sy"] * k for n in nums]
    pad = 140
    x0, x1 = max(0, int(min(xs)) - pad), min(W, int(max(xs)) + pad)
    y0, y1 = max(0, int(min(ys)) - pad - 260), min(H, int(max(ys)) + pad)
    sel = nums[:: max(1, every)]
    cw, ch = x1 - x0, y1 - y0
    tw = thumb
    th = int(ch * tw / cw)
    lab = 18
    rows = math.ceil(len(sel) / cols)
    sheet = Image.new("RGB", (cols * tw, rows * (th + lab)), (18, 16, 22))
    f = font(12)
    for i, n in enumerate(sel):
        im = Image.open(frames[n]).convert("RGB").crop((x0, y0, x1, y1)).resize((tw, th), Image.LANCZOS)
        x, y = (i % cols) * tw, (i // cols) * (th + lab)
        sheet.paste(im, (x, y + lab))
        ImageDraw.Draw(sheet).text((x + 4, y + 2), "f%d  v=%d px/s" % (n, fmap[n]["hz"][0]["v"]), fill=(230, 230, 230), font=f)
    p1 = os.path.join(d, "swing_%d-%d_sheet.png" % (a, b))
    sheet.save(p1)
    # speed chart
    vs = [fmap[n]["hz"][0]["v"] for n in nums]
    cwid, chei = 900, 260
    img = Image.new("RGB", (cwid, chei), (24, 22, 28))
    dr = ImageDraw.Draw(img)
    vmax = max(max(vs), 1.0)
    pts = [(40 + (cwid - 60) * i / max(1, len(vs) - 1), chei - 30 - (chei - 60) * v / vmax) for i, v in enumerate(vs)]
    for i, (px, py) in enumerate(pts):
        dr.line([(px, chei - 30), (px, py)], fill=(90, 60, 60), width=1)
    dr.line(pts, fill=(255, 120, 90), width=2)
    for px, py in pts:
        dr.ellipse([px - 2, py - 2, px + 2, py + 2], fill=(255, 220, 120))
    dr.text((44, 8), "pendulum ball speed per frame (1/30 s), f%d..f%d   max %d px/s" % (a, b, vmax), fill=(230, 230, 230), font=font(14))
    dr.text((44, chei - 24), "flat at 0 = dead stop (stiff); smooth valleys = apex hang", fill=(150, 150, 160), font=f)
    p2 = os.path.join(d, "swing_%d-%d_speed.png" % (a, b))
    img.save(p2)
    return p1, p2


def report(data):
    print("== aim windows (super aim) ==")
    wins = data.get("aim_windows", [])
    by = {}
    for w in wins:
        by.setdefault(w["lvl"], []).append(w)
    for lvl in sorted(by):
        ws = by[lvl]
        mx = max(w["max_step_deg"] for w in ws)
        cap = ws[0]["cap_deg_tick"]
        over = sum(1 for w in ws if w["max_step_deg"] > w["cap_deg_tick"] + 0.05)
        big = sum(1 for w in ws if w["max_step_deg"] > 15.0)
        print("  L%d: %d windows  max step %.2f deg/tick (cap %.2f)  over-cap windows %d  >15deg-jumps %d  mean ticks %.0f" % (
            lvl, len(ws), mx, cap, over, big, sum(w["ticks"] for w in ws) / len(ws)))
    print("== hazards ==")
    for h in data.get("hazards", []):
        print("  %s %s/%s: contacts %d  fast %d  smashes %d  shoves %d  immune %d" % (
            h["name"], h["kind"], h["contact_mode"], h["contacts"], h["fast_contacts"], h["smashes"], h["shoves"], h["immune"]))
    ev = {}
    for e in data.get("events", []):
        ev[e["type"]] = ev.get(e["type"], 0) + 1
    print("== events ==", json.dumps(ev))
    pt = [e for e in data.get("events", []) if e["type"] == "pendulum_test_result"]
    if pt:
        print("  pendulum_test: %d/%d dropped players smashed" % (sum(1 for e in pt if e["smashed"]), len(pt)))
    hs = [e for e in data.get("events", []) if e["type"] == "smashed" and e.get("hazard")]
    if hs:
        print("  hazard smashes (impulse): " + ", ".join(str(e["impulse"]) for e in hs))


def extract_avi(d):
    """Godot Movie Maker MJPEG .avi -> frameNNNNNNNN.jpg (each '00dc' chunk is a complete JPEG)."""
    avi = os.path.join(d, "movie.avi")
    if not os.path.exists(avi):
        return 0
    with open(avi, "rb") as fh:
        buf = fh.read()
    i = buf.find(b"movi")
    if i < 0:
        return 0
    i += 4
    n = 0
    L = len(buf)
    while i + 8 <= L:
        cid = buf[i:i + 4]
        size = int.from_bytes(buf[i + 4:i + 8], "little")
        if cid == b"idx1":
            break
        data = buf[i + 8:i + 8 + size]
        if cid[2:4] in (b"dc", b"db") and data[:2] == b"\xff\xd8":   # Godot writes '00db'
            with open(os.path.join(d, "frame%08d.jpg" % n), "wb") as out:
                out.write(data)
            n += 1
        elif cid == b"LIST":
            i += 12   # descend into nested LIST (rec ) chunks
            continue
        i += 8 + size + (size & 1)
    if n > 0:
        os.remove(avi)
        print("extracted %d JPEG frames from movie.avi" % n)
    else:
        j = buf.find(b"movi")
        print("WARNING: no JPEG chunks found in movie.avi (kept). movi at %d, next ids: %r" % (j, buf[j:j + 64]))
    return n


def compact(frames):
    n = 0
    for k, p in frames.items():
        if p.lower().endswith(".png"):
            Image.open(p).convert("RGB").save(p[:-4] + ".jpg", quality=90)
            os.remove(p)
            n += 1
    print("compacted %d PNG frames -> JPEG" % n)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--every", type=int, default=10)
    ap.add_argument("--count", type=int, default=48)
    ap.add_argument("--cols", type=int, default=6)
    ap.add_argument("--thumb", type=int, default=320)
    ap.add_argument("--range", default="")
    ap.add_argument("--overlay", action="store_true")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--strobe", default="")
    ap.add_argument("--compact", action="store_true")
    ap.add_argument("--prefix", default="sheet")
    ap.add_argument("--swing", default="", help="A:B one pendulum swing: arc-cropped sheet + speed chart")
    ap.add_argument("--follow", type=int, default=-1, help="crop each thumb around player index N (0-based)")
    ap.add_argument("--zoom", type=float, default=0.3, help="crop size as a fraction of the frame (with --follow)")
    ap.add_argument("--traj", action="store_true", help="WK-95: world trajectory plot coloured by boost/super state")
    args = ap.parse_args()
    d = args.dir
    extract_avi(d)
    frames = load_frames(d)
    data = None
    dp = os.path.join(d, "data.json")
    if os.path.exists(dp):
        with open(dp, encoding="utf-8") as fh:
            data = json.load(fh)
    print("%s: %d frames, data.json %s" % (d, len(frames), "yes" if data else "MISSING"))
    sel = pick_frames(frames, data, args)
    p = contact_sheet(frames, sel, data, args, False, os.path.join(d, args.prefix + ".png"))
    if p:
        print("wrote", p)
    if args.overlay and data:
        p = contact_sheet(frames, sel, data, args, True, os.path.join(d, args.prefix + "_overlay.png"))
        if p:
            print("wrote", p)
    if data:
        p = aim_report(data, os.path.join(d, "aim_report.png"))
        if p:
            print("wrote", p)
    if args.strobe and data:
        p = strobe(frames, data, args.strobe, os.path.join(d, "strobe_%s.png" % args.strobe.replace(":", "-")))
        if p:
            print("wrote", p)
    if args.swing and data:
        r = swing(frames, data, args.swing, args.every, args.cols, args.thumb, d)
        if r:
            print("wrote", r[0])
            print("wrote", r[1])
    if args.traj and data:
        p = traj_plot(data, os.path.join(d, "traj.png"))
        if p:
            print("wrote", p)
    if args.report and data:
        report(data)
    if args.compact:
        compact(frames)


if __name__ == "__main__":
    sys.exit(main())
