#!/usr/bin/env bash
# waypaper GUI for Sway (may print one harmless hyprctl line on startup).
set -euo pipefail
cfg="${SWAY_WAYPAPER_CONFIG:-$HOME/.config/sway/waypaper/config.ini}"
command -v waypaper >/dev/null || { notify-send wallpaper "waypaper not installed"; exit 1; }
exec waypaper --config-file "$cfg" --backend swaybg --no-post-command "$@"
