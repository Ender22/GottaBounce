#!/usr/bin/env python3
"""gbplay - drive the running GottaBounce game over the in-game TCP server (port 9090).

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
  python tools/gbplay.py perf                      # fps / memory
  python tools/gbplay.py raw '{"command":"gamepad","params":{...}}'
  python tools/gbplay.py script demo.jsonl         # run a sequence of raw commands
  python tools/gbplay.py burst out_dir 10 --interval 0.5   # screenshot burst -> frames

Exit code 0 on success; prints JSON responses to stdout.
"""
import argparse
import base64
import json
import os
import socket
import sys
import time

HOST = "127.0.0.1"
PORT = 9090
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
    a = p.parse_args()

    c = GameClient()
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
            out(c.send("get_performance"))
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
