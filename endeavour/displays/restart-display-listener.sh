#!/usr/bin/env bash
# Restart hypr-display-listener (one instance only).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LISTENER="$SCRIPT_DIR/hypr-display-listener.sh"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-listener.pid"
LOG="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-listener.log"
DEBOUNCE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-debounce.pid"

pkill -f 'displays/hypr-display-listener.sh' 2>/dev/null || true
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
