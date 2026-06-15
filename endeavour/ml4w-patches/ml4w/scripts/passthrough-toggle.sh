#!/usr/bin/env bash
# Toggle game passthrough: release Alt+mouse compositor grabs (i3-style).
set -euo pipefail

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
