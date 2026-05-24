#!/usr/bin/env bash
# i3-style move: reorder within workspace, re-nest dwindle splits, then adjacent monitor.
set -euo pipefail

dir=${1:?usage: move-window-i3.sh l|r|u|d}
case "$dir" in l|r|u|d) ;; *) exit 2 ;; esac

export MOVE_DIR="$dir"
python3 <<'PY'
import json
import os
import subprocess
import sys

direction = os.environ["MOVE_DIR"]


def hypr_json(*args):
    return json.loads(subprocess.check_output(["hyprctl", *args], text=True))


def dispatch(*args):
    subprocess.run(["hyprctl", "dispatch", *args], check=False, capture_output=True)


def win_state():
    try:
        w = hypr_json("activewindow", "-j")
    except subprocess.CalledProcessError:
        return None
    if not w.get("address"):
        return None
    ws = w.get("workspace") or {}
    return {
        "monitor": w.get("monitor"),
        "workspace": ws.get("id"),
        "at": tuple(w.get("at") or []),
        "size": tuple(w.get("size") or []),
    }


def changed(before, after):
    if not before or not after:
        return False
    return (
        before["monitor"] != after["monitor"]
        or before["workspace"] != after["workspace"]
        or before["at"] != after["at"]
        or before["size"] != after["size"]
    )


def try_actions(before):
    for action in (
        ("movewindoworgroup", direction),
        ("movewindow", direction),
        ("swapwindow", direction),
    ):
        dispatch(*action)
        after = win_state()
        if changed(before, after):
            return True
    return False


def try_restructure(before):
    # Side-by-side dwindle nodes have no u/d sibling — rotate or toggle split, then retry.
    restructure = (
        ("layoutmsg", "togglesplit"),
        ("layoutmsg", "rotatesplit", "90"),
        ("layoutmsg", "swapsplit"),
        ("layoutmsg", "rotatesplit", "-90"),
    )
    for msg in restructure:
        dispatch(*msg)
        if try_actions(before):
            return True
    return False


def try_directional_move():
    before = win_state()
    if not before:
        return True

    if try_actions(before):
        return True

    if try_restructure(before):
        return True

    # Last resort: swap entire subtrees at the root (i3-like reparent when stuck).
    dispatch("layoutmsg", "movetoroot", "active", "unstable")
    if try_actions(before):
        return True

    return False


def find_neighbor(monitors, current_name, dir_):
    current = next(m for m in monitors if m["name"] == current_name)
    cx = current["x"] + current["width"] / 2
    cy = current["y"] + current["height"] / 2
    best = None
    best_dist = float("inf")

    for mon in monitors:
        if mon["name"] == current_name:
            continue
        mx = mon["x"] + mon["width"] / 2
        my = mon["y"] + mon["height"] / 2

        if dir_ == "l" and mx >= cx - 1:
            continue
        if dir_ == "r" and mx <= cx + 1:
            continue
        if dir_ == "u" and my >= cy - 1:
            continue
        if dir_ == "d" and my <= cy + 1:
            continue

        if dir_ in ("l", "r"):
            overlap = min(
                current["y"] + current["height"], mon["y"] + mon["height"]
            ) - max(current["y"], mon["y"])
            if overlap <= 0:
                continue
            dist = abs(mx - cx)
        else:
            overlap = min(
                current["x"] + current["width"], mon["x"] + mon["width"]
            ) - max(current["x"], mon["x"])
            if overlap <= 0:
                continue
            dist = abs(my - cy)

        if dist < best_dist:
            best_dist = dist
            best = mon

    return best


if try_directional_move():
    sys.exit(0)

before = win_state()
if not before:
    sys.exit(0)

monitors = hypr_json("monitors", "-j")
names = {m["id"]: m["name"] for m in monitors}
current = names.get(before["monitor"])
if not current:
    sys.exit(0)

neighbor = find_neighbor(monitors, current, direction)
if neighbor:
    dispatch("movewindow", f"mon:{neighbor['name']}")
PY
