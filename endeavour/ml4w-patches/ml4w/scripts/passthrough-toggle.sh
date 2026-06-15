#!/usr/bin/env bash
# Toggle game passthrough (Hyprland submap / Sway mode).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=compositor.sh
source "$SCRIPT_DIR/compositor.sh"

if compositor_is_sway; then
    flag="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-sway-passthrough"
    if [[ -f "$flag" ]]; then
        rm -f "$flag"
        swaymsg mode default
    else
        : >"$flag"
        swaymsg mode passthrough
    fi
    exit 0
fi

unbind_mouse() {
    hyprctl keyword unbind 'ALT,mouse:272' 2>/dev/null || true
    hyprctl keyword unbind 'ALT,mouse:273' 2>/dev/null || true
    hyprctl keyword unbind 'ALT,mouse_down' 2>/dev/null || true
    hyprctl keyword unbind 'ALT,mouse_up' 2>/dev/null || true
}

rebind_mouse() {
    hyprctl keyword bindm 'ALT,mouse:272,movewindow' 2>/dev/null || true
    hyprctl keyword bindm 'ALT,mouse:273,resizewindow' 2>/dev/null || true
    hyprctl keyword bind 'ALT,mouse_down,workspace,e+1' 2>/dev/null || true
    hyprctl keyword bind 'ALT,mouse_up,workspace,e-1' 2>/dev/null || true
}

sub=$(hyprctl submap 2>/dev/null | tr -d '[:space:]')

if [[ "$sub" == "passthrough" ]]; then
    rebind_mouse
    hyprctl dispatch submap reset
else
    unbind_mouse
    hyprctl dispatch submap passthrough
fi
