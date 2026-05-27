#!/usr/bin/env bash
# Waybar custom/media-play — Font Awesome play/pause icon from playerctl status.
set -euo pipefail

status=$(playerctl status 2>/dev/null || echo Stopped)

case "$status" in
	Playing) icon=$'\uf04c' ;; # pause
	*) icon=$'\uf04b' ;;       # play
esac

python3 -c 'import json, sys; print(json.dumps({"text": f" {sys.argv[1]} ", "tooltip": "Play / pause"}))' "$icon"
