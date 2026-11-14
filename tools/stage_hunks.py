"""Stage only some hunks of a file (non-interactive `git add -p` for parallel-agent working trees).

usage: python tools/stage_hunks.py <file> --exclude REGEX [--list]
       python tools/stage_hunks.py <file> --include REGEX [--list]
A hunk is kept/dropped if REGEX matches any of its +/- lines. --list prints hunks with a match flag, stages nothing.
Uses `git diff -U0`-free default context; applies with `git apply --cached --recount`.
"""
import re
import subprocess
import sys


def main() -> None:
    f = sys.argv[1]
    mode = sys.argv[2]
    rx = re.compile(sys.argv[3], re.I)
    listing = "--list" in sys.argv
    diff = subprocess.run(["git", "diff", "--", f], capture_output=True).stdout.decode("utf-8")
    if not diff:
        print("no diff for", f)
        return
    lines = diff.splitlines(keepends=True)
    head, hunks, cur = [], [], None
    for ln in lines:
        if ln.startswith("@@"):
            cur = [ln]
            hunks.append(cur)
        elif cur is None:
            head.append(ln)
        else:
            cur.append(ln)
    keep = []
    for i, h in enumerate(hunks):
        changed = "".join(x for x in h[1:] if x[:1] in "+-")
        hit = bool(rx.search(changed))
        take = (not hit) if mode == "--exclude" else hit
        if listing:
            print(f"hunk {i}: match={hit} take={take} {h[0].strip()}")
        if take:
            keep.append(h)
    if listing:
        return
    if not keep:
        print("nothing to stage")
        return
    patch = "".join(head) + "".join("".join(h) for h in keep)
    # bytes, not text: Windows text-mode stdin would turn LF into CRLF and the patch would not apply
    r = subprocess.run(["git", "apply", "--cached", "--recount", "-"], input=patch.encode("utf-8"), capture_output=True)
    err = r.stderr.decode("utf-8", "replace").strip()
    print(("staged" if r.returncode == 0 else "FAILED") + f" {len(keep)}/{len(hunks)} hunks of {f}", err)


if __name__ == "__main__":
    main()
