#!/usr/bin/env bash
# Waybar JSON: show indicator when Hyprland passthrough submap is active.
sub=$(hyprctl submap 2>/dev/null | tr -d '[:space:]')
if [[ "$sub" == "passthrough" ]]; then
    printf '{"text":" PASSTHROUGH ","tooltip":"Passthrough — Alt+Esc to exit","class":"active"}\n'
else
    printf '{"text":""}\n'
fi
