"""Weekend loop bookkeeping: mark BACKLOG items done/attempted and append to the STATUS weekend block.

usage: python tools/wk_mark.py done <hash> "<status line>" WK-03 WK-04 ...
       python tools/wk_mark.py tried "<reason>" WK-07
"""
import re
import sys

BL = "docs/BACKLOG.md"
ST = "docs/STATUS.md"


def main() -> None:
    mode = sys.argv[1]
    if mode == "done":
        h, line, ids = sys.argv[2], sys.argv[3], sys.argv[4:]
    elif mode == "tried":
        h, line, ids = "", sys.argv[2], sys.argv[3:]
    else:
        raise SystemExit(__doc__)
    s = open(BL, encoding="utf-8").read()
    for i in ids:
        pat = re.compile(r"### \[[ ~]\] (" + re.escape(i) + r" [^\n]*)")
        m = pat.search(s)
        if not m:
            print("not found / already done:", i)
            continue
        if mode == "done":
            s = s[: m.start()] + "### [x] " + m.group(1) + " — " + h + s[m.end():]
            s = re.sub(r"(\n\d+\. )(" + re.escape(i) + r") ", r"\1~~\2~~ done " + h + " — ", s, count=1)
        else:
            s = s[: m.start()] + "### [~] " + m.group(1) + " — attempted: " + line + s[m.end():]
    open(BL, "w", encoding="utf-8").write(s)
    if mode == "done":
        t = open(ST, encoding="utf-8").read()
        anchor = "NEXT: "
        k = t.find(anchor, t.find("WEEKEND POLISH RUN"))
        if k > 0:
            t = t[:k] + "DONE: " + line + " (" + h + "). " + t[k:]
            open(ST, "w", encoding="utf-8").write(t)
    print("ok")


if __name__ == "__main__":
    main()
