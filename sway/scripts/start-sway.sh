#!/usr/bin/env bash
# Sway session entry for plasmalogin (does not touch Hyprland).
set -euo pipefail

export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_TYPE=wayland

# Use wlroots portal in this session; Hyprland portal is unused while logged into Sway.
if command -v systemctl >/dev/null; then
    systemctl --user stop xdg-desktop-portal-hyprland.service 2>/dev/null || true
    systemctl --user start xdg-desktop-portal-wlr.service 2>/dev/null || true
fi

SWAY_BIN=sway
if [[ -x "$(command -v swayfx)" ]] && [[ -f "${HOME}/.config/sway/config.d/05-swayfx.conf" ]]; then
    SWAY_BIN=swayfx
fi

exec "$SWAY_BIN" -d
