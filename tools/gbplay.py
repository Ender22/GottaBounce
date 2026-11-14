#!/usr/bin/env python3
"""gbplay - drive the running GottaBounce game over the in-game TCP server (default port 9090).

The game must be running WINDOWED (not headless) with the McpInteractionServer autoload.
Start it with:  tools/run_game.ps1   (or godot console exe --path . <scene>)

Usage (one-shot commands):
  python tools/gbplay.py screenshot out.png
  python tools/gbplay.py key SPACE                 # tap a key
  python tools/gbplay.py hold RIGHT --ms 500       # hold key for duration
  python tools/gbplay.py action jump               # tap an input action
  python tools/gbplay.py hold-action boost --ms 800
  python tools/gbplay.py eval "return get_tree().current_scene.name"
  python tools/gbplay.py scene res://scenes/Arena.tscn
  python tools/gbplay.py tree                      # scene tree summary
  python tools/gbplay.py ui                        # visible UI elements
  python tools/gbplay.py perf                      # fps / memory (+ WK-100 display-off check)
  python tools/gbplay.py perf --samples 1          # single sample, no fps probe
  python tools/gbplay.py raw '{"command":"gamepad","params":{...}}'
  python tools/gbplay.py script demo.jsonl         # run a sequence of raw commands
  python tools/gbplay.py burst out_dir 10 --interval 0.5   # screenshot burst -> frames

Port (WK-130): --port N (anywhere on the line), else env GB_PORT, else 9090. Parallel agents each
launch their own game on their own port (run_game.ps1 -Port N) and pass the same port here:
  python tools/gbplay.py --port 9101 eval "return OS.get_process_id()"

Exit code 0 on success; prints JSON responses to stdout.
"""
import argparse
import base64
import json
import os
import re
import socket
import subprocess
import sys
import time

HOST = "127.0.0.1"
DEFAULT_PORT = 9090


def default_port():
    """env GB_PORT if set and valid, else 9090."""
    raw = os.environ.get("GB_PORT", "").strip()
    if raw:
        try:
            n = int(raw)
            if 1 <= n <= 65535:
                return n
        except ValueError:
            pass
        print(f"WARNING: ignoring invalid GB_PORT={raw!r}, using {DEFAULT_PORT}", file=sys.stderr)
    return DEFAULT_PORT


PORT = default_port()
TIMEOUT = 35.0


class GameClient:
    def __init__(self, host=HOST, port=PORT):
        self.sock = socket.create_connection((host, port), timeout=TIMEOUT)
        self.sock.settimeout(TIMEOUT)
        self.buf = b""

    def send(self, command, params=None):
        msg = {"command": command, "params": params or {}}
        self.sock.sendall((json.dumps(msg) + "\n").encode("utf-8"))
        return self._read_response()

    def send_raw(self, obj):
        self.sock.sendall((json.dumps(obj) + "\n").encode("utf-8"))
        return self._read_response()

    def _read_response(self):
        while b"\n" not in self.buf:
            chunk = self.sock.recv(1 << 20)
            if not chunk:
                raise ConnectionError("game closed connection")
            self.buf += chunk
        line, self.buf = self.buf.split(b"\n", 1)
        return json.loads(line.decode("utf-8"))

    def screenshot(self, path):
        resp = self.send("screenshot")
        if not resp.get("success"):
            return resp
        data = base64.b64decode(resp["data"])
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
        return {"success": True, "path": path,
                "width": resp.get("width"), "height": resp.get("height"),
                "bytes": len(data)}

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


# WK-100: Windows Modern Standby (laptop display asleep) throttles a windowed Godot to ~30 Hz with
# ~500 ms present() stalls - every perf/timing/feel number taken then is bogus (docs/WEEKEND_LESSONS.md
# "DISPLAY OFF = BOGUS PERF DATA"). The game really runs ~120 fps at 1080p with the screen on.
FPS_SANE_MIN = 50.0
KP_QUERY = ("*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] "
            "and (EventID=506 or EventID=507)]]")


def display_state():
    """Latest Kernel-Power 506/507 event -> (off, detail). off is None when unknown (non-Windows,
    wevtutil missing/failed). Test hook: GB_DISPLAY_STUB=off|506 / on|507."""
    stub = os.environ.get("GB_DISPLAY_STUB", "").strip().lower()
    if stub:
        return (stub in ("off", "506")), f"stubbed by GB_DISPLAY_STUB={stub}"
    if os.name != "nt":
        return None, "not Windows"
    try:
        r = subprocess.run(["wevtutil", "qe", "System", "/q:" + KP_QUERY, "/c:1", "/rd:true", "/f:xml"],
                           capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError) as e:
        return None, f"wevtutil failed: {e}"
    m = re.search(r"<EventID>(\d+)</EventID>", r.stdout or "")
    if not m:
        return None, "no Kernel-Power 506/507 event"
    t = re.search(r"SystemTime='([^']+)'", r.stdout)
    when = t.group(1)[:19] + "Z" if t else "?"
    if m.group(1) == "506":
        return True, f"Kernel-Power 506 (entered Modern Standby) at {when}, no 507 wake since"
    return False, f"last Kernel-Power event 507 (exited Modern Standby) at {when}"


def perf_with_display_check(c, samples):
    """get_performance, plus (samples > 1) an fps probe over ~1 s and the Kernel-Power check. Adds
    'display_check' to the response and prints a WARNING line to stderr when numbers look invalid.
    Never fails the command - it only annotates."""
    resp = c.send("get_performance")
    if not isinstance(resp, dict) or not resp.get("success") or samples <= 1:
        return resp
    fps = [float(resp.get("fps", 0.0))]
    for _ in range(samples - 1):
        time.sleep(0.3)
        r = c.send("get_performance")
        if isinstance(r, dict) and r.get("success"):
            fps.append(float(r.get("fps", 0.0)))
    low = [f for f in fps if f < FPS_SANE_MIN]
    off, detail = display_state()
    chk = {"fps_samples": fps, "fps_min_sane": FPS_SANE_MIN, "display": detail,
           "display_off": off, "valid": True}
    reasons = []
    if off:
        reasons.append("DISPLAY OFF (" + detail + ")")
    if len(low) >= max(2, (len(fps) + 1) // 2):
        reasons.append(f"fps < {FPS_SANE_MIN:.0f} in {len(low)}/{len(fps)} samples "
                       f"(min {min(fps):.0f}) - screen asleep, window minimised/occluded, or a real perf problem")
    if reasons:
        chk["valid"] = False
        chk["warning"] = "timings invalid: " + "; ".join(reasons)
        print("WARNING: " + chk["warning"], file=sys.stderr)
    resp["display_check"] = chk
    return resp


def out(resp):
    print(json.dumps(resp, indent=2)[:4000])
    if isinstance(resp, dict) and resp.get("error"):
        sys.exit(1)


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("cmd")
    p.add_argument("args", nargs="*")
    p.add_argument("--ms", type=int, default=0, help="hold duration in ms")
    p.add_argument("--interval", type=float, default=0.5)
    p.add_argument("--samples", type=int, default=4, help="perf: fps samples for the display check")
    p.add_argument("--port", type=int, default=PORT,
                   help="game server port (default: env GB_PORT, else 9090)")
    a = p.parse_args()

    try:
        c = GameClient(port=a.port)
    except OSError as e:
        print(f"Cannot reach {HOST}:{a.port} ({e}). Is your game running on that port? "
              f"(tools/run_game.ps1 -Port {a.port})", file=sys.stderr)
        sys.exit(2)
    try:
        if a.cmd == "screenshot":
            out(c.screenshot(a.args[0] if a.args else "screenshot.png"))
        elif a.cmd == "key":
            out(c.send("key_press", {"key": a.args[0]}))
        elif a.cmd == "action":
            c.send("key_press", {"action": a.args[0], "pressed": True})
            time.sleep(0.05)
            out(c.send("key_press", {"action": a.args[0], "pressed": False}))
        elif a.cmd == "hold":
            c.send("key_hold", {"key": a.args[0]})
            time.sleep(max(a.ms, 50) / 1000.0)
            out(c.send("key_release", {"key": a.args[0]}))
        elif a.cmd == "hold-action":
            c.send("key_hold", {"action": a.args[0]})
            time.sleep(max(a.ms, 50) / 1000.0)
            out(c.send("key_release", {"action": a.args[0]}))
        elif a.cmd == "eval":
            out(c.send("eval", {"code": a.args[0]}))
        elif a.cmd == "scene":
            out(c.send("change_scene", {"scene_path": a.args[0]}))
        elif a.cmd == "tree":
            out(c.send("get_scene_tree"))
        elif a.cmd == "ui":
            out(c.send("get_ui_elements"))
        elif a.cmd == "perf":
            out(perf_with_display_check(c, a.samples))
        elif a.cmd == "click":
            out(c.send("click", {"x": float(a.args[0]), "y": float(a.args[1])}))
        elif a.cmd == "raw":
            out(c.send_raw(json.loads(a.args[0])))
        elif a.cmd == "script":
            results = []
            with open(a.args[0], encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    obj = json.loads(line)
                    if obj.get("command") == "sleep":
                        time.sleep(float(obj.get("params", {}).get("seconds", 1)))
                        results.append({"slept": True})
                        continue
                    if obj.get("command") == "screenshot_to":
                        results.append(c.screenshot(obj["params"]["path"]))
                        continue
                    results.append(c.send_raw(obj))
            out({"success": True, "steps": len(results), "results": results})
        elif a.cmd == "burst":
            outdir, count = a.args[0], int(a.args[1])
            os.makedirs(outdir, exist_ok=True)
            shots = []
            for i in range(count):
                shots.append(c.screenshot(os.path.join(outdir, f"frame_{i:03d}.png")))
                time.sleep(a.interval)
            out({"success": True, "frames": [s.get("path") for s in shots]})
        else:
            out({"error": f"unknown command: {a.cmd}"})
    finally:
        c.close()


if __name__ == "__main__":
    main()
