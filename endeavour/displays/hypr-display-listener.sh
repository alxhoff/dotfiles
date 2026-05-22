#!/usr/bin/env bash
# Hyprland socket2 listener — re-apply display profile after dock hotplug
# Add to hypr autostart: exec-once = ~/git/Github/dotfiles/endeavour/displays/hypr-display-listener.sh
#
set -euo pipefail

DOTFILES_DISPLAYS=${DOTFILES_DISPLAYS:-$HOME/git/Github/dotfiles/endeavour/displays}
APPLY="$DOTFILES_DISPLAYS/apply-display-profile.sh"
# shellcheck source=endeavour/displays/config.env
source "$DOTFILES_DISPLAYS/config.env"

[[ -x "$APPLY" ]] || exit 0

apply_later() {
    sleep "${HOTPLUG_SETTLE_SEC:-2}"
    "$APPLY" auto
}

handle() {
    case $1 in
        monitoradded*|monitorremoved*)
            apply_later &
            ;;
    esac
}

sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
sock="$runtime/hypr/$sig/.socket2.sock"
[[ -S "$sock" ]] || { echo "hypr socket2 not found: $sock" >&2; exit 1; }

# Initial apply
"$APPLY" auto

socat -u "UNIX-CONNECT:$sock" - | while read -r line; do
    handle "$line"
done
