#!/usr/bin/env bash
# Pick a Wi-Fi network (rofi). Falls back to nm-connection-editor if rofi is missing.
set -euo pipefail

wifi_dev() {
    nmcli -t -f TYPE,DEVICE,STATE dev status 2>/dev/null | awk -F: '
        $1 == "wifi" && $3 != "unavailable" { print $2; exit }
    '
}

if ! command -v rofi >/dev/null 2>&1; then
    exec nm-connection-editor
fi

dev=$(wifi_dev)
if [[ -z "$dev" ]]; then
    notify-send -t 4000 "Wi-Fi" "No wireless device found" 2>/dev/null || true
    exit 1
fi

if [[ "$(nmcli -t -f WIFI radio)" != "enabled" ]]; then
    nmcli radio wifi on
fi

nmcli dev wifi rescan ifname "$dev" 2>/dev/null || nmcli dev wifi rescan 2>/dev/null || true
sleep 0.8

mapfile -t entries < <(
    nmcli -t -f SSID,SIGNAL,IN-USE dev wifi list ifname "$dev" 2>/dev/null | awk -F: '
        $1 != "" && $1 != "--" {
            mark = ($3 == "*") ? "▸ " : "  "
            printf "%s%s\t%s\n", mark, $1, $2
        }
    ' | sort -t$'\t' -k2 -nr
)

if ((${#entries[@]} == 0)); then
    notify-send -t 4000 "Wi-Fi" "No networks found — try Rescan" 2>/dev/null || true
    exit 0
fi

selection=$(
    printf '%s\n' "${entries[@]}" |
        rofi -dmenu -i -p "Wi-Fi" -lines 14 -width 420
) || exit 0

[[ -n "$selection" ]] || exit 0

ssid=${selection#▸ }
ssid=${ssid#  }
ssid=${ssid%%$'\t'*}

if nmcli dev wifi connect "$ssid" ifname "$dev"; then
    notify-send -t 3000 "Wi-Fi" "Connected to $ssid" 2>/dev/null || true
else
    notify-send -t 5000 "Wi-Fi" "Could not connect to $ssid" 2>/dev/null || true
    exit 1
fi
