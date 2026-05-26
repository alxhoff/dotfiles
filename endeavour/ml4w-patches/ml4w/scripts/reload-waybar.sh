#!/usr/bin/env bash
# Reload waybar (per-monitor primary + secondary bars).
set -euo pipefail

launch="${HOME}/.config/ml4w/scripts/waybar-launch.sh"
if [[ -x "$launch" ]]; then
    "$launch"
else
    pkill -x waybar 2>/dev/null || true
    sleep 0.5
    nohup waybar >/tmp/waybar.log 2>&1 &
fi

sleep 0.5
if pgrep -x waybar >/dev/null; then
    notify-send -t 2000 "Waybar" "Reloaded" 2>/dev/null || true
else
    notify-send -t 5000 "Waybar" "Failed to start — see ${XDG_RUNTIME_DIR:-/tmp}/dotfiles-waybar/*.log" 2>/dev/null || true
    exit 1
fi
