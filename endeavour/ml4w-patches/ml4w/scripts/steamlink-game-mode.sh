#!/usr/bin/env bash
# Hyprland passthrough: release compositor key grabs (Alt+Esc to exit).
# Does not release Steam Link's own pointer grab while a game stream is active.
set -euo pipefail

hyprctl dispatch focuswindow 'class:^(steamlink|com\.valvesoftware\.steamlink)$' 2>/dev/null || true
hyprctl dispatch submap passthrough
notify-send -t 5000 'Passthrough on' 'Alt+Esc to exit. Mouse: Alt+Ctrl+U to focus away from Steam Link.'
