#!/usr/bin/env bash
# Move every workspace onto one output (before that output is disabled / after undock).
# Usage: migrate-session-sway.sh <target-output-name>
set -euo pipefail

TARGET=${1:?usage: migrate-session-sway.sh OUTPUT_NAME}
LAPTOP_PATTERN=${LAPTOP_PATTERN:-eDP}
DEBUG=${MIGRATE_DEBUG:-0}

export TARGET LAPTOP_PATTERN DEBUG
python3 <<'PY'
import json
import os
import subprocess
import sys
import time

target = os.environ["TARGET"]
edp = os.environ.get("LAPTOP_PATTERN", "eDP")
debug = os.environ.get("DEBUG", "0") not in ("", "0", "false")


def log(msg):
    if debug:
        print(f"migrate(sway): {msg}", file=sys.stderr)


def run(*args):
    r = subprocess.run(["swaymsg", *args], capture_output=True, text=True)
    if r.returncode != 0 and r.stderr.strip():
        print(r.stderr.strip(), file=sys.stderr)
    return r.returncode == 0


def outputs():
    return json.loads(subprocess.check_output(["swaymsg", "-t", "get_outputs"], text=True))


def active_names():
    return {o["name"] for o in outputs() if o.get("active")}


all_names = {o["name"] for o in outputs()}
if target not in all_names:
    print(f"migrate(sway): target {target} not found", file=sys.stderr)
    raise SystemExit(1)

if target not in active_names():
    log(f"enabling inactive target {target}")
    for _ in range(8):
        run("output", target, "enable")
        run("output", target, "mode", "preferred")
        run("output", target, "position", "auto")
        time.sleep(0.25)
        if target in active_names():
            break
    if target not in active_names():
        print(f"migrate(sway): target {target} not active after enable", file=sys.stderr)
        raise SystemExit(1)

try:
    focus_ws = json.loads(
        subprocess.check_output(["swaymsg", "-t", "get_workspaces"], text=True)
    )
    focus_ws = next((w for w in focus_ws if w.get("focused")), None)
    focus_name = str(focus_ws.get("name", "")) if focus_ws else ""
except subprocess.CalledProcessError:
    focus_name = ""

workspaces = json.loads(subprocess.check_output(["swaymsg", "-t", "get_workspaces"], text=True))
ws_moved = 0
for ws in sorted(workspaces, key=lambda w: w.get("num", 0)):
    if ws.get("output") == target:
        log(f"skip ws {ws.get('name')} already on {target}")
        continue
    name = ws.get("name")
    if not name:
        continue
    log(f"move workspace {name} from {ws.get('output')!r} → {target}")
    run("workspace", str(name), "output", target)
    ws_moved += 1

run("focus", "output", target)
if focus_name:
    run("workspace", focus_name)

print(f"migrate(sway) → {target}: {ws_moved} workspace(s)", file=sys.stderr)
PY
