#!/usr/bin/env bash
# i3 split h / split v — persist split direction for new windows (dwindle preselect).
set -euo pipefail

mode=${1:?usage: split-i3.sh h|v}
case "$mode" in h|v) ;; *) exit 2 ;; esac

export SPLIT_MODE="$mode"
python3 <<'PY'
import json
import os
import subprocess

mode = os.environ["SPLIT_MODE"]

# H = horizontal layout (side-by-side). V = vertical layout (stacked top/bottom).
preselect = "r" if mode == "h" else "d"
label = "tile horizontally" if mode == "h" else "tile vertically"


def hypr_json(*args):
    return json.loads(subprocess.check_output(["hyprctl", *args], text=True))


def dispatch(*args):
    subprocess.run(["hyprctl", "dispatch", *args], check=False, capture_output=True)


def sibling_orientation(active, clients):
    """Return 'horizontal' if focused window sits beside a sibling, 'vertical' if stacked."""
    ax, ay = active.get("at") or [0, 0]
    aw, ah = active.get("size") or [0, 0]
    ws = (active.get("workspace") or {}).get("id")
    addr = active.get("address")

    for c in clients:
        if c.get("address") == addr or c.get("floating"):
            continue
        if (c.get("workspace") or {}).get("id") != ws:
            continue
        bx, by = c.get("at") or [0, 0]
        bw, bh = c.get("size") or [0, 0]

        y_overlap = min(ay + ah, by + bh) - max(ay, by)
        x_overlap = min(ax + aw, bx + bw) - max(ax, bx)
        if y_overlap <= 0 and x_overlap <= 0:
            continue

        if y_overlap > ah * 0.5 and x_overlap > aw * 0.5:
            continue

        if y_overlap > min(ah, bh) * 0.4:
            return "horizontal"
        if x_overlap > min(aw, bw) * 0.4:
            return "vertical"
    return None


try:
    active = hypr_json("activewindow", "-j")
except subprocess.CalledProcessError:
    active = {}

if active.get("address") and not active.get("floating"):
    orient = sibling_orientation(active, hypr_json("clients", "-j"))
    want = "horizontal" if mode == "h" else "vertical"
    if orient and orient != want:
        dispatch("layoutmsg", "togglesplit")

dispatch("layoutmsg", "preselect", preselect)
subprocess.run(["notify-send", "-t", "1200", label], check=False)
PY
