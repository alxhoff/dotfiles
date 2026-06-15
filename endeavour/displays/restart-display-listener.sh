#!/usr/bin/env bash
# Restart display hotplug listener (Hyprland or Sway).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ML4W="${HOME}/.config/ml4w/scripts/compositor.sh"
# shellcheck source=/dev/null
[[ -f "$ML4W" ]] && source "$ML4W"

if compositor_is_sway 2>/dev/null; then
	LISTENER="$SCRIPT_DIR/sway-display-listener.sh"
elif command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_version >/dev/null 2>&1 \
	&& ! { command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; }; then
	LISTENER="$SCRIPT_DIR/sway-display-listener.sh"
else
	LISTENER="$SCRIPT_DIR/hypr-display-listener.sh"
fi

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-listener.pid"
LOG="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-listener.log"
DEBOUNCE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-debounce.pid"

pkill -f 'displays/hypr-display-listener.sh' 2>/dev/null || true
pkill -f 'displays/sway-display-listener.sh' 2>/dev/null || true
if [[ -f "$DEBOUNCE" ]]; then
	kill "$(cat "$DEBOUNCE")" 2>/dev/null || true
	rm -f "$DEBOUNCE"
fi
rm -f "$PIDFILE"
sleep 0.5

nohup "$LISTENER" >>"$LOG" 2>&1 &
echo $! >"$PIDFILE"
sleep 0.5
kill -0 "$(cat "$PIDFILE")" && echo "listener started (pid $(cat "$PIDFILE"), log: $LOG)"
