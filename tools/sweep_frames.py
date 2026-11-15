import os, re, sys, time, shutil
root = sys.argv[1]; dry = sys.argv[2] == "dry"
skip = re.compile(r"cd3|wk-?135|wk37e", re.I)
now = time.time(); tot = 0; n = 0
for d in sorted(os.listdir(os.path.join(root, "rec"))):
    p = os.path.join(root, "rec", d)
    if not os.path.isdir(p) or os.path.islink(p) or skip.search(d): continue
    if now - os.path.getmtime(p) < 1800 and d != "wk66a_box_goal": continue
    for f in os.listdir(p):
        if re.match(r"frame\d+\.(jpg|png)$", f) or f == "movie.avi":
            fp = os.path.join(p, f); tot += os.path.getsize(fp); n += 1
            if not dry: os.remove(fp)
for d in ("rip", "bulge"):
    p = os.path.join(root, "wk", d)
    if os.path.isdir(p) and not os.path.islink(p):
        for f in os.listdir(p):
            fp = os.path.join(p, f)
            if os.path.isfile(fp): tot += os.path.getsize(fp); n += 1; (dry or os.remove(fp))
        if not dry: os.rmdir(p)
for f in ("rip_sheet.png", "WK-66a_beach_a.png", "WK-66a_dev_bowl.png", "WK-66a_dome_max2.png"):
    fp = os.path.join(root, "wk", f)
    if os.path.isfile(fp): tot += os.path.getsize(fp); n += 1; (dry or os.remove(fp))
for f in os.listdir(os.path.join(root, "wk")):
    if f.startswith("rip_now") and f.endswith(".png"):
        fp = os.path.join(root, "wk", f); tot += os.path.getsize(fp); n += 1; (dry or os.remove(fp))
print(("DRY " if dry else "") + f"{n} files, {tot/1e9:.2f} GB")
