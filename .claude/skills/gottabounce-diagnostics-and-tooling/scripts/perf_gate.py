#!/usr/bin/env python3
"""perf_gate.py - sample the running game's performance monitors over port 9090 and grade
them against the perf regression criterion (docs/specs/v0_combat_lethality.md section 9 test 21:
"avg >=55 fps, no hitch >100ms" during a smash-heavy round).

Usage (game already running windowed via tools/run_game.ps1; run during COMBAT for a real read):
  python .claude/skills/gottabounce-diagnostics-and-tooling/scripts/perf_gate.py
  python .claude/skills/gottabounce-diagnostics-and-tooling/scripts/perf_gate.py --samples 60 --interval 0.5

Golden reference (measured, docs/STATUS.md): 79-80 fps, 28 draw calls on the shipped arena.

LIMITATION (be honest in verdicts): this polls Performance monitors at --interval; TIME_PROCESS
reports only the LAST frame's process time, so a hitch between samples is invisible. A "no hitch
observed" here means none was CAUGHT - for a hard hitch gate, also eyeball a burst sequence or
watch the window. stdlib only; never launches anything.
Status: verified static 2026-07-03 (written against mcp_interaction_server.gd _cmd_get_performance;
never yet executed against a live game).
"""
import argparse
import json
import socket
import sys
import time

HOST, PORT, TIMEOUT = "127.0.0.1", 9090, 35.0


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--samples", type=int, default=30)
    p.add_argument("--interval", type=float, default=1.0)
    a = p.parse_args()

    try:
        sock = socket.create_connection((HOST, PORT), timeout=TIMEOUT)
    except (ConnectionRefusedError, OSError) as e:
        print("Cannot reach 127.0.0.1:9090 (%s). Start the game first: powershell -File tools/run_game.ps1" % e)
        return 2
    sock.settimeout(TIMEOUT)
    buf = b""

    def call():
        nonlocal buf
        sock.sendall((json.dumps({"command": "get_performance", "params": {}}) + "\n").encode())
        while b"\n" not in buf:
            chunk = sock.recv(1 << 20)
            if not chunk:
                raise ConnectionError("game closed connection")
            buf += chunk
        line, buf = buf.split(b"\n", 1)
        return json.loads(line.decode())

    fps, ftimes, draws, orphans = [], [], [], []
    for i in range(a.samples):
        r = call()
        if r.get("error", "").startswith("Server busy"):
            time.sleep(1.0)
            continue
        fps.append(float(r.get("fps", 0)))
        ftimes.append(float(r.get("frame_time", 0)))          # TIME_PROCESS, seconds (last frame)
        draws.append(int(r.get("render_total_draw_calls", 0)))
        orphans.append(int(r.get("object_orphan_node_count", 0)))
        time.sleep(a.interval)

    if not fps:
        print("No samples collected.")
        return 2
    avg = sum(fps) / len(fps)
    worst_ms = max(ftimes) * 1000.0
    hitch_caught = worst_ms > 100.0
    ok = avg >= 55.0 and not hitch_caught
    print("=== perf_gate: %d samples @ %.1fs ===" % (len(fps), a.interval))
    print("fps        : avg %.1f  min %.1f  (target avg >=55; golden 79-80)" % (avg, min(fps)))
    print("frame_time : worst sampled %.1f ms  (hitch gate >100ms; sampling can MISS hitches)" % worst_ms)
    print("draw calls : last %d  max %d  (golden 28; a big jump = leaked FX/nodes)" % (draws[-1], max(draws)))
    print("orphans    : max %d  (steady growth = node leak; see queue_free cleanup patterns)" % max(orphans))
    print("VERDICT    : %s  (avg fps %s, hitch %s)" % (
        "PASS" if ok else "FAIL",
        "ok" if avg >= 55.0 else "LOW",
        "caught" if hitch_caught else "none caught (not proof of none)"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
