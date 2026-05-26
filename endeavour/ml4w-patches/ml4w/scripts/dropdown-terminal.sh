#!/usr/bin/env bash
# Guake-style dropdown terminal (Hyprland special workspace).
set -euo pipefail

CONFIG="${HOME}/.config/ml4w/dropdown-terminal.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

: "${DROPDOWN_TERM:=kitty}"
: "${DROPDOWN_CLASS:=dropdown-terminal}"
: "${DROPDOWN_TITLE:=Dropdown}"
: "${DROPDOWN_WORKSPACE:=dropdown}"
: "${DROPDOWN_CMD:=}"

client_json() {
    hyprctl clients -j 2>/dev/null || echo '[]'
}

has_dropdown() {
    client_json | DROPDOWN_CLASS="$DROPDOWN_CLASS" python3 -c '
import json, os, sys
want = os.environ["DROPDOWN_CLASS"]
print("yes" if any(c.get("class") == want for c in json.load(sys.stdin)) else "no")
'
}

dropdown_addr() {
    client_json | DROPDOWN_CLASS="$DROPDOWN_CLASS" python3 -c '
import json, os, sys
want = os.environ["DROPDOWN_CLASS"]
for c in json.load(sys.stdin):
    if c.get("class") == want:
        print(c["address"])
        break
'
}

spawn_terminal() {
    local -a cmd=("$DROPDOWN_TERM" "--class=$DROPDOWN_CLASS" "--title=$DROPDOWN_TITLE")
    if [[ -n "$DROPDOWN_CMD" ]]; then
        cmd+=(-e bash -lc "$DROPDOWN_CMD")
    fi
    "${cmd[@]}" &
}

if [[ "$(has_dropdown)" != "yes" ]]; then
    spawn_terminal
    addr=""
    for _ in $(seq 1 50); do
        sleep 0.05
        addr=$(dropdown_addr || true)
        [[ -n "$addr" ]] && break
    done
    if [[ -z "$addr" ]]; then
        echo "dropdown-terminal: failed to spawn $DROPDOWN_TERM (class=$DROPDOWN_CLASS)" >&2
        exit 1
    fi
    hyprctl dispatch movetoworkspacesilent "special:$DROPDOWN_WORKSPACE,address:$addr"
fi

hyprctl dispatch togglespecialworkspace "$DROPDOWN_WORKSPACE"
