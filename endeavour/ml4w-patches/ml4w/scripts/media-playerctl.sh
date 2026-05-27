#!/usr/bin/env bash
# playerctl wrapper for Waybar media controls — ignore browser MPRIS players.
set -euo pipefail

CONFIG="${HOME}/.config/ml4w/media.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

: "${MEDIA_IGNORE_PLAYERS:=firefox,chromium,brave}"

if [[ -n "$MEDIA_IGNORE_PLAYERS" ]]; then
	exec playerctl -i "$MEDIA_IGNORE_PLAYERS" "$@"
fi

exec playerctl "$@"
