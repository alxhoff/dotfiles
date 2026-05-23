#!/usr/bin/env bash
# Reload waybar so modules.json / on-click changes take effect.
set -euo pipefail

pkill -x waybar 2>/dev/null || true
sleep 0.5
nohup waybar >/tmp/waybar.log 2>&1 &
disown 2>/dev/null || true
sleep 0.5
if pgrep -x waybar >/dev/null; then
    notify-send -t 2000 "Waybar" "Reloaded" 2>/dev/null || true
else
    notify-send -t 5000 "Waybar" "Failed to start — see /tmp/waybar.log" 2>/dev/null || true
    exit 1
fi
