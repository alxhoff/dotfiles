#!/usr/bin/env bash
# Hyprland passthrough before local Proton gaming (WoW Classic, etc.).
set -euo pipefail

hyprctl dispatch focuswindow 'class:^(steam)$' 2>/dev/null || true
"$(dirname "${BASH_SOURCE[0]}")/passthrough-on.sh"
notify-send -t 5000 'Game mode' 'Alt+Esc to exit passthrough.'
