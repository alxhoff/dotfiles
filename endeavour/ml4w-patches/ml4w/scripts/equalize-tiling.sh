#!/usr/bin/env bash
# Equalize tiled windows in the same row/column.
# Manual: Alt+Ctrl+E. Auto: dwindle-auto-split on openwindow (debounced).
set -euo pipefail

LOCK="${XDG_RUNTIME_DIR:-/tmp}/equalize-tiling.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

python3 <<'PY'
import json
import subprocess

Y_TOL = 28
H_TOL = 56
X_TOL = 28
W_TOL = 56
PASSES = 2
EVEN_PX = 28
MIN_SIDE = 80


def hypr_json(*args):
    return json.loads(subprocess.check_output(["hyprctl", *args], text=True))


def batch(commands):
    if not commands:
        return
    subprocess.run(
        ["hyprctl", "--batch", " ; ".join(commands)],
        check=False,
        capture_output=True,
    )


def tiled_on_workspace(ws_id):
    out = []
    for c in hypr_json("clients", "-j"):
        if c.get("floating"):
            continue
        if (c.get("workspace") or {}).get("id") != ws_id:
            continue
        x, y = c.get("at") or [0, 0]
        w, h = c.get("size") or [0, 0]
        if w < 60 or h < 60:
            continue
        out.append({"address": c["address"], "at": (x, y), "size": (w, h)})
    return out


def same_row(a, b):
    return (
        abs(a["at"][1] - b["at"][1]) <= Y_TOL
        and abs(a["size"][1] - b["size"][1]) <= H_TOL
    )


def same_col(a, b):
    return (
        abs(a["at"][0] - b["at"][0]) <= X_TOL
        and abs(a["size"][0] - b["size"][0]) <= W_TOL
    )


def refresh_group(windows, ws_id):
    by_addr = {c["address"]: c for c in tiled_on_workspace(ws_id)}
    return [by_addr[w["address"]] for w in windows if w["address"] in by_addr]


def row_is_stable(windows):
    if any(c["size"][1] < MIN_SIDE for c in windows):
        return False
    ys = [c["at"][1] for c in windows]
    hs = [c["size"][1] for c in windows]
    return max(ys) - min(ys) <= Y_TOL and max(hs) - min(hs) <= H_TOL


def col_is_stable(windows):
    if any(c["size"][0] < MIN_SIDE for c in windows):
        return False
    xs = [c["at"][0] for c in windows]
    ws = [c["size"][0] for c in windows]
    return max(xs) - min(xs) <= X_TOL and max(ws) - min(ws) <= W_TOL


def equalize_row(windows, ws_id):
    for _ in range(PASSES):
        windows = refresh_group(windows, ws_id)
        if not row_is_stable(windows):
            return
        windows = sorted(windows, key=lambda c: c["at"][0])
        n = len(windows)
        if n < 2:
            return
        left = min(c["at"][0] for c in windows)
        right = max(c["at"][0] + c["size"][0] for c in windows)
        total = right - left
        if total < n * MIN_SIDE:
            return
        tw = total // n
        cmds = []
        for i, c in enumerate(windows):
            addr = c["address"]
            h = c["size"][1]
            if i == 0:
                cmds.append(f"dispatch focuswindow address:{addr}")
            cmds.append(f"dispatch resizewindowpixel exact {tw} {h},address:{addr}")
        batch(cmds)
        windows = refresh_group(windows, ws_id)
        widths = [c["size"][0] for c in windows]
        if max(widths) - min(widths) <= EVEN_PX:
            break


def equalize_col(windows, ws_id):
    for _ in range(PASSES):
        windows = refresh_group(windows, ws_id)
        if not col_is_stable(windows):
            return
        windows = sorted(windows, key=lambda c: c["at"][1])
        n = len(windows)
        if n < 2:
            return
        top = min(c["at"][1] for c in windows)
        bottom = max(c["at"][1] + c["size"][1] for c in windows)
        total = bottom - top
        if total < n * MIN_SIDE:
            return
        th = total // n
        cmds = []
        for i, c in enumerate(windows):
            addr = c["address"]
            w = c["size"][0]
            if i == 0:
                cmds.append(f"dispatch focuswindow address:{addr}")
            cmds.append(f"dispatch resizewindowpixel exact {w} {th},address:{addr}")
        batch(cmds)
        windows = refresh_group(windows, ws_id)
        heights = [c["size"][1] for c in windows]
        if max(heights) - min(heights) <= EVEN_PX:
            break


try:
    active_raw = hypr_json("activewindow", "-j")
except subprocess.CalledProcessError:
    raise SystemExit(0)

if not active_raw.get("address") or active_raw.get("floating"):
    raise SystemExit(0)

ws_id = (active_raw.get("workspace") or {}).get("id")
if ws_id is None:
    raise SystemExit(0)

orig = active_raw["address"]
clients = tiled_on_workspace(ws_id)
active = next((c for c in clients if c["address"] == orig), None)
if not active:
    raise SystemExit(0)

row = [c for c in clients if same_row(active, c)]
if len(row) >= 2 and row_is_stable(row):
    equalize_row(row, ws_id)
    batch([f"dispatch focuswindow address:{orig}"])
    raise SystemExit(0)

col = [c for c in clients if same_col(active, c)]
if len(col) >= 2 and col_is_stable(col):
    equalize_col(col, ws_id)
    batch([f"dispatch focuswindow address:{orig}"])
PY
