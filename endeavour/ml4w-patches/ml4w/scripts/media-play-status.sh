#!/usr/bin/env bash
# Waybar custom/media-play — Font Awesome play/pause icon from playerctl status.
set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PLAYERCTL="$SCRIPT_DIR/media-playerctl.sh"

status=$("$PLAYERCTL" status 2>/dev/null || echo Stopped)

case "$status" in
	Playing) icon=$'\uf04c' ;; # pause
	*) icon=$'\uf04b' ;;       # play
esac

python3 -c 'import json, sys; print(json.dumps({"text": f" {sys.argv[1]} ", "tooltip": "Play / pause"}))' "$icon"
