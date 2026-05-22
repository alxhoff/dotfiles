#!/usr/bin/env bash
# Power menu (waybar + Super+X). Rofi always works; wlogout only if binary exists.
set -eu

WLOGOUT=
for p in /usr/bin/wlogout /usr/local/bin/wlogout; do
    [[ -x "$p" ]] && WLOGOUT=$p && break
done

if [[ -n "$WLOGOUT" ]]; then
    exec "$WLOGOUT" -b 4
fi

choice=$(
    printf '%s\n' \
        'Lock' \
        'Log out' \
        'Suspend' \
        'Reboot' \
        'Shutdown' |
        rofi -dmenu -i -p 'Power' -lines 6 -width 280
) || exit 0

[[ -n "$choice" ]] || exit 0

case "$choice" in
    Lock)
        if command -v hyprlock >/dev/null 2>&1; then
            exec hyprlock
        fi
        loginctl lock-session 2>/dev/null || true
        ;;
    'Log out')
        if command -v hyprctl >/dev/null 2>&1; then
            hyprctl dispatch exit
        else
            loginctl terminate-user "$USER" 2>/dev/null || true
        fi
        ;;
    Suspend) systemctl suspend ;;
    Reboot) systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
esac
