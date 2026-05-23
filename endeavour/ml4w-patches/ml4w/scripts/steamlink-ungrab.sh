#!/usr/bin/env bash
# Steam Link grabs the pointer while streaming games. Passthrough does not release that.
# Moving focus to another window usually lets the cursor leave the Steam Link surface.
set -euo pipefail

if ! hyprctl clients -j | jq -e '.[] | select(.class|test("^(steamlink|com\\.valvesoftware\\.steamlink)$"))' >/dev/null; then
    notify-send -t 4000 'Steam Link' 'No Steam Link window found.'
    exit 1
fi

hyprctl dispatch focuswindow 'class:^(steamlink|com\.valvesoftware\.steamlink)$'
for _ in 1 2 3 4; do
    hyprctl dispatch movefocus l
    if [[ "$(hyprctl activewindow -j | jq -r '.class')" != "steamlink" ]]; then
        notify-send -t 4000 'Mouse released' 'Focus left Steam Link — cursor should move freely.'
        exit 0
    fi
done

for _ in 1 2 3 4; do
    hyprctl dispatch movefocus r
    if [[ "$(hyprctl activewindow -j | jq -r '.class')" != "steamlink" ]]; then
        notify-send -t 4000 'Mouse released' 'Focus left Steam Link — cursor should move freely.'
        exit 0
    fi
done

notify-send -t 5000 'Mouse still captive' \
    'Stop streaming or press Alt+Ctrl+F to reset the window. Captive pointer is normal while a game stream has focus.'
