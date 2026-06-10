#!/usr/bin/env bash
# i3-style move: move the focused window within the workspace, then the next monitor.
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
        "address": w.get("address"),
        "monitor": w.get("monitor"),
        "workspace": ws.get("id"),
        "at": tuple(w.get("at") or []),
        "size": tuple(w.get("size") or []),
    }


def changed(before, after):
    if not before or not after:
        return False
    if before["address"] != after["address"]:
        return False
    return (
        before["monitor"] != after["monitor"]
        or before["workspace"] != after["workspace"]
        or before["at"] != after["at"]
        or before["size"] != after["size"]
    )


def monitor_name(mon_id: int) -> str | None:
    for m in hypr_json("monitors", "-j"):
        if m.get("id") == mon_id:
            return m.get("name")
    return None


def move_focused(before, *args):
    """Move the focused window; undo if it jumped to another monitor."""
    if not before:
        return False
    home = monitor_name(before["monitor"])
    dispatch(*args)
    after = win_state()
    if not after or after["address"] != before["address"]:
        return False
    if after["monitor"] != before["monitor"] and home:
        dispatch("movewindow", f"mon:{home}")
        after = win_state()
    return changed(before, after)


def active_rect():
    state = win_state()
    if not state:
        return None
    x, y = state["at"]
    w, h = state["size"]
    return state, (x, y, x + w, y + h)


def overlap_1d(a0, a1, b0, b1, min_px=24):
    return min(a1, b1) - max(a0, b0) >= min_px


def workspace_peers(state):
    peers = []
    for c in hypr_json("clients", "-j"):
        if c.get("floating"):
            continue
        if c.get("address") == state["address"]:
            continue
        if (c.get("workspace") or {}).get("id") != state["workspace"]:
            continue
        x, y = c.get("at") or [0, 0]
        w, h = c.get("size") or [0, 0]
        if w < 40 or h < 40:
            continue
        peers.append((x, y, x + w, y + h))
    return peers


def layout_mode(state, rect, peers):
    _, (ax0, ay0, ax1, ay1) = state, rect
    has_side = False
    has_stack = False
    for bx0, by0, bx1, by1 in peers:
        if overlap_1d(ay0, ay1, by0, by1) and (bx1 <= ax0 + 8 or bx0 >= ax1 - 8):
            has_side = True
        if overlap_1d(ax0, ax1, bx0, bx1) and (by1 <= ay0 + 8 or by0 >= ay1 - 8):
            has_stack = True
    if has_side:
        return "row"
    if has_stack:
        return "stack"
    return "solo"


def try_in_workspace(before):
    rect_pack = active_rect()
    if not rect_pack:
        return False
    state, rect = rect_pack
    peers = workspace_peers(state)
    mode = layout_mode(state, rect, peers)

    # Stacked top/bottom → move left/right should re-orient to side-by-side first.
    if direction in ("l", "r") and mode == "stack":
        if move_focused(before, "layoutmsg", "togglesplit"):
            return True

    if direction in ("u", "d") and mode == "row":
        if move_focused(before, "layoutmsg", "togglesplit"):
            return True

    for action in (
        ("movewindow", direction),
        ("movewindoworgroup", direction),
    ):
        if move_focused(before, *action):
            return True

    # Second pass after a split flip (e.g. was stacked, now row).
    if direction in ("l", "r") and mode == "stack":
        for action in (("movewindow", direction), ("movewindoworgroup", direction)):
            if move_focused(before, *action):
                return True

    return False


def at_monitor_edge(before):
    names = {m["id"]: m for m in hypr_json("monitors", "-j")}
    mon = names.get(before["monitor"])
    if not mon:
        return True
    x, y = before["at"]
    w, h = before["size"]
    left = mon["x"]
    top = mon["y"] + (mon.get("reserved") or [0, 0, 0, 0])[1]
    right = mon["x"] + mon["width"]
    bottom = mon["y"] + mon["height"]
    margin = 12
    if direction == "r":
        return x + w >= right - margin
    if direction == "l":
        return x <= left + margin
    if direction == "d":
        return y + h >= bottom - margin
    return y <= top + margin


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


before = win_state()
if not before:
    sys.exit(0)

if try_in_workspace(before):
    sys.exit(0)

if not at_monitor_edge(before):
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
