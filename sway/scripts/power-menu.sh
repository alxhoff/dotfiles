#!/usr/bin/env bash
# Rofi power menu for Sway trial (same keys as Hyprland power submap).
set -euo pipefail

choice=$(printf '%s\n' \
    'lock\tLock screen' \
    'suspend\tSuspend' \
    'logout\tLog out' \
    'reboot\tReboot' \
    'shutdown\tShutdown' \
    | rofi -dmenu -i -p power -lines 6 -width 28) || exit 0

case "${choice%%$'\t'*}" in
    lock) ~/.config/sway/scripts/lock.sh ;;
    suspend) systemctl suspend ;;
    logout) swaymsg exit ;;
    reboot) systemctl reboot ;;
    shutdown) systemctl poweroff ;;
esac
