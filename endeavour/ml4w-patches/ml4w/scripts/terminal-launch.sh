#!/usr/bin/env bash
# Spawn kitty the same way on Hyprland and Sway (fish, home dir, Wayland).
set -euo pipefail

: "${TERMINAL:=kitty}"
: "${TERMINAL_DIR:=${HOME}}"
: "${TERMINAL_SHELL:=${SHELL:-/usr/bin/fish}}"

export SHELL="$TERMINAL_SHELL"

if (($#)); then
    exec "$TERMINAL" --directory="$TERMINAL_DIR" "$@"
fi

exec "$TERMINAL" --directory="$TERMINAL_DIR"
