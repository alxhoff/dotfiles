#!/usr/bin/env bash
# Debounce auto-equalize after openwindow (only the latest spawn wins).
set -euo pipefail

EQUALIZE="${HOME}/.config/ml4w/scripts/equalize-tiling.sh"
STAMP="${XDG_RUNTIME_DIR:-/tmp}/equalize-tiling.schedule"
DELAY="${EQUALIZE_DELAY_SEC:-0.4}"

[[ -x "$EQUALIZE" ]] || exit 0

token="$$-$(date +%s%N)"
echo "$token" >"$STAMP"
sleep "$DELAY"
[[ "$(cat "$STAMP" 2>/dev/null)" == "$token" ]] || exit 0
exec "$EQUALIZE"
