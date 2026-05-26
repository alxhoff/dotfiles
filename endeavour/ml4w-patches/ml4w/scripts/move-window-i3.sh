#!/usr/bin/env bash
# i3-style move: reorder within workspace, re-nest dwindle splits, then adjacent monitor.
set -euo pipefail

dir=${1:?usage: move-window-i3.sh l|r|u|d}
case "$dir" in l|r|u|d) ;; *) exit 2 ;; esac

CONFIG_ENV="${HOME}/.config/dotfiles/endeavour/displays/config.env"
[[ -f "$CONFIG_ENV" ]] && source "$CONFIG_ENV"
: "${PORTRAIT_MONITOR_PATTERNS:=Q27q-1L|B246WL|UP2516D}"

export MOVE_DIR="$dir"
export PORTRAIT_MONITOR_PATTERNS
python3 <<'PY'
import json
import os
import subprocess
import sys

direction = os.environ["MOVE_DIR"]
patterns = [p for p in os.environ.get("PORTRAIT_MONITOR_PATTERNS", "").split("|") if p]


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


def is_portrait(mon: dict) -> bool:
    desc = mon.get("description") or ""
    if any(p in desc for p in patterns):
        return True
    if mon.get("transform", 0) in (1, 3):
        return True
    return mon.get("height", 0) > mon.get("width", 0)


def current_monitor() -> dict | None:
    before = win_state()
    if not before:
        return None
    monitors = hypr_json("monitors", "-j")
    return next((m for m in monitors if m.get("id") == before["monitor"]), None)


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
    steps: list[tuple] = []
    mon = current_monitor()
    portrait = bool(mon and is_portrait(mon))

    if direction in ("u", "d"):
        # Portrait monitors often need a split flip before u/d swaps work.
        steps.extend(
            [
                ("layoutmsg", "togglesplit"),
                ("swapwindow", direction),
                ("movewindow", direction),
                ("layoutmsg", "swapsplit"),
                ("swapwindow", direction),
                ("movewindoworgroup", direction),
            ]
        )
        if portrait:
            steps.extend(
                [
                    ("layoutmsg", "movetoroot", "active", "unstable"),
                    ("swapwindow", direction),
                    ("movewindow", direction),
                ]
            )

    steps.extend(
        [
            ("layoutmsg", "togglesplit"),
            ("layoutmsg", "rotatesplit", "90"),
            ("layoutmsg", "swapsplit"),
            ("layoutmsg", "rotatesplit", "-90"),
            ("swapwindow", direction),
            ("movewindow", direction),
        ]
    )

    for msg in steps:
        dispatch(*msg)
        after = win_state()
        if changed(before, after):
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
