#!/usr/bin/env bash
# On hotplug: wait for outputs to settle, then apply the matching profile once.
# Also applies on startup (dock may already be connected before this script runs).
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
STATE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-profile"
echo $$ >"$PIDFILE"

cancel_debounce() {
	if [[ -f "$DEBOUNCE" ]]; then
		kill "$(cat "$DEBOUNCE")" 2>/dev/null || true
		rm -f "$DEBOUNCE"
	fi
}

in_cooldown() {
	[[ -f "$COOLDOWN" ]] && (($(date +%s) < $(cat "$COOLDOWN")))
}

run_apply() {
	in_cooldown && return 0
	(
		exec 9>"$LOCK"
		flock -n 9 || exit 0
		in_cooldown && exit 0

		local retries=${HOTPLUG_RETRY_COUNT:-6}
		local delay=${HOTPLUG_RETRY_SEC:-3}
		local attempt=0 detected current

		while ((attempt <= retries)); do
			detected=$("$APPLY" detect 2>/dev/null || echo skip)
			if [[ "$detected" != skip ]]; then
				current=$(cat "$STATE" 2>/dev/null || true)
				if [[ "$detected" == "$current" ]]; then
					exit 0
				fi
				"$APPLY" auto
				exit 0
			fi
			((attempt++)) || true
			((attempt <= retries)) && sleep "$delay"
		done
	) &
	wait $! 2>/dev/null || true
}

schedule_apply() {
	cancel_debounce
	(
		sleep "${HOTPLUG_SETTLE_SEC:-5}"
		run_apply
	) &
	echo $! >"$DEBOUNCE"
}

listen_events() {
	local sig sock
	while true; do
		sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
		sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$sig/.socket2.sock"
		if [[ -S "$sock" ]]; then
			socat -u "UNIX-CONNECT:$sock" - 2>/dev/null | while read -r line; do
				case $line in
				monitoradded* | monitorremoved*) schedule_apply ;;
				esac
			done
		fi
		sleep 2
	done
}

# Dock may already be connected when Hyprland starts (no monitoradded events after this).
schedule_apply
listen_events
