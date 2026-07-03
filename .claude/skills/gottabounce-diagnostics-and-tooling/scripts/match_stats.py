#!/usr/bin/env python3
"""match_stats.py - pull PartyMatch round_stats over the game's TCP eval channel (port 9090)
and grade them against the lethality-v2 pacing targets (docs/specs/v0_combat_lethality.md section 9).

Usage (run from the repo root; the game must ALREADY be running windowed via tools/run_game.ps1):
  python .claude/skills/gottabounce-diagnostics-and-tooling/scripts/match_stats.py
  python .claude/skills/gottabounce-diagnostics-and-tooling/scripts/match_stats.py --min-rounds 10 --timeout 900
  python .claude/skills/gottabounce-diagnostics-and-tooling/scripts/match_stats.py --once   # grade whatever is recorded right now, no waiting

This script NEVER launches the game. stdlib only. It polls until `min_rounds` completed rounds
are recorded (or MATCH_END is reached, or timeout), then fetches the full round_stats array,
prints an interpretation block with PASS/FAIL vs the spec targets, and writes the raw JSON to
--out (default tools/out/match_stats_raw.json) so nothing is lost to terminal truncation.

Failure modes:
  ConnectionRefusedError  -> game not running / not windowed / wrong machine. Start it first.
  {"error": "Server busy..."} -> another client is mid-command (single-flight server). Retried.
  n == -1 in poll output  -> current scene has no round_stats (SmokeTest/Playtest/course scene,
                             or the OLD project is on 9090 - check the printed scene path).
  n went DOWN mid-poll    -> a rematch started (round_stats is cleared on rematch); warned.
Status: verified static 2026-07-03 (written against the code of PartyMatch.gd, gbplay.py and
mcp_interaction_server.gd; never yet executed against a live game).
"""
import argparse
import json
import os
import socket
import sys
import time

HOST, PORT, TIMEOUT = "127.0.0.1", 9090, 35.0

POLL_CODE = (
    "var cs = get_tree().current_scene\n"
    "var rs = cs.get(\"round_stats\")\n"
    "if rs == null:\n"
    "\treturn {\"scene\": cs.scene_file_path, \"state\": str(cs.get(\"state\")), \"n\": -1}\n"
    "return {\"scene\": cs.scene_file_path, \"state\": str(cs.get(\"state\")), \"n\": rs.size()}"
)
FETCH_CODE = "return get_tree().current_scene.round_stats"


class Client:
    def __init__(self):
        self.sock = socket.create_connection((HOST, PORT), timeout=TIMEOUT)
        self.sock.settimeout(TIMEOUT)
        self.buf = b""

    def eval(self, code, retries=3):
        for attempt in range(retries):
            self.sock.sendall((json.dumps({"command": "eval", "params": {"code": code}}) + "\n").encode())
            while b"\n" not in self.buf:
                chunk = self.sock.recv(1 << 20)
                if not chunk:
                    raise ConnectionError("game closed connection")
                self.buf += chunk
            line, self.buf = self.buf.split(b"\n", 1)
            resp = json.loads(line.decode())
            if resp.get("error", "").startswith("Server busy"):
                time.sleep(2.0)
                continue
            if resp.get("error"):
                raise RuntimeError("eval error: %s" % resp["error"])
            return resp.get("result")
        raise RuntimeError("server stayed busy after %d retries" % retries)


def grade(rounds, out_path):
    n = len(rounds)
    if n == 0:
        print("No completed rounds recorded yet - nothing to grade.")
        return 1
    lengths = sorted(float(r.get("length_s", 0.0)) for r in rounds)
    median = lengths[n // 2] if n % 2 else (lengths[n // 2 - 1] + lengths[n // 2]) / 2.0
    sd = sum(1 for r in rounds if r.get("entered_sd"))
    hist = {}
    for r in rounds:
        hist[str(r.get("end_cause"))] = hist.get(str(r.get("end_cause")), 0) + 1
    # test 10: decided by a kill, fast, never reached SD. NOTE: includes suicide ring-outs
    # (round_stats does not tag the DECIDING kill; check kills[-1].killer if that matters).
    kill_decided = sum(1 for r in rounds
                       if str(r.get("end_cause")) != "laser" and not r.get("entered_sd")
                       and float(r.get("length_s", 99.0)) < 20.0)
    kills = [k for r in rounds for k in r.get("kills", [])]
    unattributed = sum(1 for k in kills if int(k.get("killer", -1)) == -1)
    off_stage = sum(1 for k in kills if k.get("off_stage"))
    supers = [len(r.get("supers_fired", [])) for r in rounds]
    zero_super_rounds = sum(1 for s in supers if s == 0)

    def verdict(ok):
        return "PASS" if ok else "FAIL"

    sd_pct = 100.0 * sd / n
    kd_pct = 100.0 * kill_decided / n
    print("=== match_stats: %d completed rounds ===" % n)
    print("end_cause histogram : %s" % "  ".join("%s=%d" % kv for kv in sorted(hist.items())))
    print("SD rate             : %5.1f%%  (target <=25%%)   %s  [spec s9 test 11]" % (sd_pct, verdict(sd_pct <= 25.0)))
    print("kill-decided <20s   : %5.1f%%  (target >=70%%)   %s  [spec s9 test 10]" % (kd_pct, verdict(kd_pct >= 70.0)))
    print("median combat length: %5.1fs  (target 10-22s)  %s  [spec s9 test 12]" % (median, verdict(10.0 <= median <= 22.0)))
    print("max combat length   : %5.1fs  (target <=26s)   %s  [spec s9 test 12]" % (lengths[-1], verdict(lengths[-1] <= 26.0)))
    print("supers per round    : avg %.1f  rounds-with-zero=%d %s" % (
        sum(supers) / float(n), zero_super_rounds,
        "(zero-super rounds usually mean a mis-hooked recorder or a frozen scene - eyeball a burst)" if zero_super_rounds else ""))
    print("unattributed kills  : %d/%d  (killer == -1: suicide / no last-attacker credit)" % (unattributed, len(kills)))
    ten = "  [spec s9 test 15: >=3 per 10-round sample]" if n >= 10 else "  [test 15 needs >=10 rounds; sample too small]"
    print("off-stage kills     : %d%s" % (off_stage, ten))
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(rounds, f, indent=2)
    print("raw round_stats     : %s" % out_path)
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--min-rounds", type=int, default=8)
    p.add_argument("--timeout", type=float, default=600.0, help="max seconds to wait for rounds")
    p.add_argument("--poll", type=float, default=5.0, help="seconds between polls")
    p.add_argument("--once", action="store_true", help="skip waiting; grade current round_stats now")
    p.add_argument("--out", default=os.path.join("tools", "out", "match_stats_raw.json"))
    a = p.parse_args()

    try:
        c = Client()
    except (ConnectionRefusedError, OSError) as e:
        print("Cannot reach 127.0.0.1:9090 (%s). Start the game first: powershell -File tools/run_game.ps1" % e)
        return 2

    last_n = -1
    deadline = time.time() + a.timeout
    while True:
        st = c.eval(POLL_CODE)
        scene, state, n = st.get("scene"), st.get("state"), int(st.get("n", -1))
        print("[poll] scene=%s state=%s completed_rounds=%d" % (scene, state, n))
        if n == -1:
            print("Current scene exposes no round_stats. Boot Arena.tscn (PartyMatch) and confirm")
            print("the scene path above belongs to THIS project (wrong-project-on-9090 trap).")
            return 2
        if n < last_n:
            print("WARNING: round_stats shrank (%d -> %d) - a rematch cleared it. Restarting count." % (last_n, n))
        last_n = n
        if a.once or n >= a.min_rounds or state == "MATCH_END":
            break
        if time.time() > deadline:
            print("Timeout after %.0fs with %d/%d rounds - grading what we have." % (a.timeout, n, a.min_rounds))
            break
        time.sleep(a.poll)

    rounds = c.eval(FETCH_CODE) or []
    return grade(rounds, a.out)


if __name__ == "__main__":
    sys.exit(main())
