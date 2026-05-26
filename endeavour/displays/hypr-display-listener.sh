#!/usr/bin/env bash
# On hotplug: wait for outputs to settle, then apply the matching profile once.
set -euo pipefail

DOTFILES_DISPLAYS=${DOTFILES_DISPLAYS:-$HOME/.config/dotfiles/endeavour/displays}
APPLY="$DOTFILES_DISPLAYS/apply-display-profile.sh"
# shellcheck source=endeavour/displays/config.env
source "$DOTFILES_DISPLAYS/config.env"

[[ -x "$APPLY" ]] || exit 0

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-listener.pid"
DEBOUNCE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-debounce.pid"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-apply.lock"
COOLDOWN="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-cooldown"
echo $$ >"$PIDFILE"

cancel_debounce() {
    if [[ -f "$DEBOUNCE" ]]; then
        kill "$(cat "$DEBOUNCE")" 2>/dev/null || true
        rm -f "$DEBOUNCE"
    fi
}

in_cooldown() {
    [[ -f "$COOLDOWN" ]] && (( $(date +%s) < $(cat "$COOLDOWN") ))
}

run_apply() {
    in_cooldown && return 0
    (
        exec 9>"$LOCK"
        flock -n 9 || exit 0
        in_cooldown && exit 0
        "$APPLY" auto
    )
}

schedule_apply() {
    cancel_debounce
    (
        sleep "${HOTPLUG_SETTLE_SEC:-5}"
        run_apply
    ) &
    echo $! >"$DEBOUNCE"
}

sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$sig/.socket2.sock"
[[ -S "$sock" ]] || { echo "hypr socket2 not found" >&2; exit 1; }

socat -u "UNIX-CONNECT:$sock" - | while read -r line; do
    case $line in
        monitoradded*|monitorremoved*) schedule_apply ;;
    esac
done
