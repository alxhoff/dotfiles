#!/usr/bin/env bash
# Detect active Wayland compositor (Hyprland vs Sway).
compositor_detect() {
    if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
        echo hyprland
    elif command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_version >/dev/null 2>&1; then
        echo sway
    else
        echo none
    fi
}

compositor_is_sway() {
    [[ "$(compositor_detect)" == sway ]]
}

compositor_is_hypr() {
    [[ "$(compositor_detect)" == hyprland ]]
}
