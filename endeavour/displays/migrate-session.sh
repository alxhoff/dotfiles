#!/usr/bin/env bash
# Move every workspace and window onto one monitor (before that monitor is disabled).
# Usage: migrate-session.sh <target-monitor-name>
set -euo pipefail

TARGET=${1:?usage: migrate-session.sh MONITOR_NAME}
LAPTOP_PATTERN=${LAPTOP_PATTERN:-eDP}
DEBUG=${MIGRATE_DEBUG:-0}

export TARGET LAPTOP_PATTERN DEBUG
python3 <<'PY'
import json, os, subprocess, sys, time

target = os.environ["TARGET"]
debug = os.environ.get("DEBUG", "0") not in ("", "0", "false")

def log(msg):
    if debug:
        print(f"migrate: {msg}", file=sys.stderr)

def run(*args):
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0 and r.stderr.strip():
        print(r.stderr.strip(), file=sys.stderr)
    return r.returncode == 0

def load_monitors(all_monitors=False):
    cmd = ["hyprctl", "monitors", "all", "-j"] if all_monitors else ["hyprctl", "monitors", "-j"]
    return json.loads(subprocess.check_output(cmd, text=True))

def refresh_active():
    mons = load_monitors()
    return mons, {m["id"]: m["name"] for m in mons}, {m["name"]: m["id"] for m in mons}

all_m = load_monitors(all_monitors=True)
all_names = {m["name"] for m in all_m}
if target not in all_names:
    print(f"migrate: target {target} not found", file=sys.stderr)
    raise SystemExit(1)

mons, mon_ids, mon_names = refresh_active()
if target not in mon_names:
    log(f"enabling disabled target {target}")
    for _ in range(6):
        run("hyprctl", "keyword", "monitor", f"{target},preferred,auto,1")
        time.sleep(0.25)
        mons, mon_ids, mon_names = refresh_active()
        if target in mon_names:
            break
    if target not in mon_names:
        print(f"migrate: target {target} not active after enable", file=sys.stderr)
        raise SystemExit(1)

target_id = mon_names[target]
active_ids = set(mon_ids.keys())

def not_on_target(val):
    if val is None:
        return False
    if isinstance(val, int):
        return val != target_id
    return val != target

try:
    active = json.loads(subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True))
    focus_ws = str(active.get("id", active.get("name", "")))
except subprocess.CalledProcessError:
    focus_ws = ""

try:
    workspaces = json.loads(subprocess.check_output(["hyprctl", "workspaces", "-j"], text=True))
except subprocess.CalledProcessError:
    workspaces = []

ws_moved = 0
for ws in sorted(workspaces, key=lambda w: w.get("id", 0)):
    mon = ws.get("monitor", "")
    mon_id = ws.get("monitorID", ws.get("monitorId"))
    if not (not_on_target(mon) or not_on_target(mon_id)):
        log(f"skip ws {ws.get('id')} already on {target}")
        continue
    wid = str(ws.get("id", ""))
    if not wid:
        continue
    log(f"move workspace {wid} from {mon!r} (id={mon_id}) → {target}")
    run("hyprctl", "dispatch", "moveworkspacetomonitor", wid, target)
    ws_moved += 1

try:
    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True))
except subprocess.CalledProcessError:
    clients = []

def client_ws(c):
    ws = c.get("workspace")
    if isinstance(ws, dict):
        return str(ws.get("id") or ws.get("name") or "")
    return str(ws or "")

win_moved = 0
for c in clients:
    mon = c.get("monitor")
    orphan = isinstance(mon, int) and mon not in active_ids
    if mon == target_id and not orphan:
        log(f"skip client {c.get('class')} already on {target}")
        continue
    addr = c.get("address", "")
    if not addr:
        continue
    ws_id = client_ws(c)
    log(
        f"move window {c.get('class')} ({addr}) from monitor {mon!r}"
        f"{' (orphan)' if orphan else ''} → {target} ws={ws_id}"
    )
    run("hyprctl", "dispatch", "focuswindow", f"address:{addr}")
    run("hyprctl", "dispatch", "movewindow", f"mon:{target}")
    if ws_id:
        run("hyprctl", "dispatch", "movetoworkspacesilent", ws_id)
    win_moved += 1

run("hyprctl", "dispatch", "focusmonitor", target)
if focus_ws:
    run("hyprctl", "dispatch", "workspace", focus_ws)

print(f"migrate → {target}: {ws_moved} workspace(s), {win_moved} window(s)", file=sys.stderr)
PY
