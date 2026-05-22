#!/usr/bin/env bash
# Disable ML4W Settings app hook if the GUI package was never installed.
# Stock autostart references ~/.config/ml4w-hyprland-settings/hyprctl.sh — harmless
# to comment out; it is not part of the dotfiles repo.
set -euo pipefail

AUTOSTART="${HOME}/.mydotfiles/com.ml4w.hyprlandstarter/.config/hypr/conf/autostart.conf"

if [[ ! -f "$AUTOSTART" ]]; then
    echo "Not found: $AUTOSTART" >&2
    exit 1
fi

if grep -q 'ml4w-hyprland-settings/hyprctl.sh' "$AUTOSTART" && \
   ! grep -q '^#.*ml4w-hyprland-settings' "$AUTOSTART"; then
    if [[ -f "${HOME}/.config/ml4w-hyprland-settings/hyprctl.sh" ]]; then
        echo "ML4W settings app present — leaving autostart as-is."
        exit 0
    fi
    sed -i 's|^exec = ~/.config/ml4w-hyprland-settings/hyprctl.sh|# exec = ~/.config/ml4w-hyprland-settings/hyprctl.sh  # optional ML4W Settings app|' \
        "$AUTOSTART"
    echo "Commented out missing ml4w-hyprland-settings exec in:"
    echo "  $AUTOSTART"
else
    echo "autostart.conf already fixed or unchanged."
fi
