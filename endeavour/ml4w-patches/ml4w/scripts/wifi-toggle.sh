#!/usr/bin/env bash
set -euo pipefail

if [[ "$(nmcli -t -f WIFI radio)" == "enabled" ]]; then
    nmcli radio wifi off
    notify-send -t 3000 "Wi-Fi" "Disabled" 2>/dev/null || true
else
    nmcli radio wifi on
    nmcli dev wifi rescan 2>/dev/null || true
    notify-send -t 3000 "Wi-Fi" "Enabled" 2>/dev/null || true
fi
