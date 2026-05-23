#!/usr/bin/env bash
# Clipboard history picker (cliphist + rofi)
set -euo pipefail
command -v cliphist >/dev/null || { notify-send cliphist "Install: pacman -S cliphist wl-clipboard"; exit 1; }
command -v rofi >/dev/null || exit 1

sel=$(cliphist list | rofi -dmenu -i -p clipboard -lines 12 -width 50) || exit 0
[[ -n "$sel" ]] || exit 0
cliphist decode <<<"$sel" | wl-copy
notify-send -t 1500 clipboard "Copied selection"
