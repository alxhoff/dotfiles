#!/usr/bin/env bash
# i3 split h / split v — set split direction for the next window only (no layout flip).
set -euo pipefail

mode=${1:?usage: split-i3.sh h|v}
case "$mode" in h|v) ;; *) exit 2 ;; esac

export SPLIT_MODE="$mode"
python3 <<'PY'
import os
import subprocess

mode = os.environ["SPLIT_MODE"]

# H = side-by-side. V = stacked top/bottom. Only affects the next spawned window.
preselect = "r" if mode == "h" else "d"
label = "tile horizontally" if mode == "h" else "tile vertically"

subprocess.run(
    ["hyprctl", "dispatch", "layoutmsg", "preselect", preselect],
    check=False,
    capture_output=True,
)
subprocess.run(["notify-send", "-t", "1200", label], check=False)
PY
