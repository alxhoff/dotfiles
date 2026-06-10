#!/usr/bin/env bash
# Portrait monitors: default new windows to vertical stack. Respects Alt+H/V preselect.
set -euo pipefail

CONFIG_ENV="${HOME}/.config/dotfiles/endeavour/displays/config.env"
[[ -f "$CONFIG_ENV" ]] && source "$CONFIG_ENV"
: "${PORTRAIT_MONITOR_PATTERNS:=Q27q-1L|B246WL|UP2516D}"

LOCK="${XDG_RUNTIME_DIR:-/tmp}/dwindle-auto-split.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

export PORTRAIT_MONITOR_PATTERNS
exec python3 <<'PY'
import json
import os
import socket
import subprocess
import sys
import time

patterns = [p for p in os.environ.get("PORTRAIT_MONITOR_PATTERNS", "").split("|") if p]
last_portrait = {"monitor": None}


def hypr_json(*args):
    return json.loads(subprocess.check_output(["hyprctl", *args], text=True))


def dispatch(*args):
    subprocess.run(["hyprctl", "dispatch", *args], check=False, capture_output=True)


def is_portrait(mon: dict) -> bool:
    desc = mon.get("description") or ""
    if any(p in desc for p in patterns):
        return True
    if mon.get("transform", 0) in (1, 3):
        return True
    return mon.get("height", 0) > mon.get("width", 0)


def preselect_portrait(name: str | None) -> None:
    """Only portrait monitors get an automatic preselect (vertical stack)."""
    if not name:
        return
    monitors = hypr_json("monitors", "-j")
    mon = next((m for m in monitors if m.get("name") == name), None)
    if not mon or not is_portrait(mon):
        return
    if last_portrait["monitor"] == name:
        return
    dispatch("layoutmsg", "preselect", "d")
    last_portrait["monitor"] = name


def active_monitor() -> str | None:
    try:
        w = hypr_json("activewindow", "-j")
    except subprocess.CalledProcessError:
        return None
    if not w.get("address"):
        return None
    monitors = {m["id"]: m["name"] for m in hypr_json("monitors", "-j")}
    return monitors.get(w.get("monitor"))


def handle_event(line: str) -> None:
    line = line.strip()
    if not line:
        return
    if line.startswith("focusedmon>>"):
        preselect_portrait(line.split(">>", 1)[1])
        return
    if line.startswith("openwindow>>"):
        # Do not touch preselect here — Alt+H/V must stick (permanent_direction_override).
        return
    if line.startswith("monitoradded>>") or line.startswith("monitorremoved>>"):
        last_portrait["monitor"] = None
        preselect_portrait(active_monitor())


def main() -> int:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not sig or not runtime:
        return 1
    sock_path = f"{runtime}/hypr/{sig}/.socket2.sock"

    preselect_portrait(active_monitor())

    while True:
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(sock_path)
            buf = ""
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                buf += chunk.decode(errors="replace")
                while "\n" in buf:
                    line, buf = buf.split("\n", 1)
                    handle_event(line)
        except OSError:
            time.sleep(1)


if __name__ == "__main__":
    raise SystemExit(main())
PY
