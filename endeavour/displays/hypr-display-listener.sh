#!/usr/bin/env bash
# Hotplug listener: debounce, then apply the matching profile (with retries).
set -euo pipefail

DOTFILES_DISPLAYS=${DOTFILES_DISPLAYS:-$HOME/.config/dotfiles/endeavour/displays}
APPLY="$DOTFILES_DISPLAYS/apply-display-profile.sh"
# shellcheck source=endeavour/displays/config.env
source "$DOTFILES_DISPLAYS/config.env"

[[ -x "$APPLY" ]] || exit 0

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-listener.pid"
DEBOUNCE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-debounce.pid"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-apply.lock"
STATE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-profile"
LOG="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-listener.log"
echo $$ >"$PIDFILE"

log() {
	echo "$(date -Iseconds) listener: $*" >>"$LOG"
}

cancel_debounce() {
	if [[ -f "$DEBOUNCE" ]]; then
		kill "$(cat "$DEBOUNCE")" 2>/dev/null || true
		rm -f "$DEBOUNCE"
	fi
}

should_apply() {
	local detected=$1
	local current=${2:-}
	[[ "$detected" == skip ]] && return 1
	[[ "$detected" != "$current" ]] && return 0
	[[ "$("$APPLY" needs-refresh 2>/dev/null || echo no)" == yes ]]
}

run_apply() {
	(
		exec 9>"$LOCK"
		flock -n 9 || exit 0

		local retries=${HOTPLUG_RETRY_COUNT:-6}
		local delay=${HOTPLUG_RETRY_SEC:-2}
		local attempt=0 detected current

		while ((attempt <= retries)); do
			detected=$("$APPLY" detect 2>/dev/null || echo skip)
			current=$(cat "$STATE" 2>/dev/null || true)
			log "detect=$detected current=$current attempt=$attempt"
			if should_apply "$detected" "$current"; then
				"$APPLY" auto 2>&1 | tee -a "$LOG"
				exit 0
			fi
			if [[ "$detected" != skip && "$detected" == "$current" ]] \
				&& [[ "$("$APPLY" needs-refresh 2>/dev/null || echo no)" != yes ]]; then
				exit 0
			fi
			((attempt++)) || true
			((attempt <= retries)) && sleep "$delay"
		done
	) &
	wait $! 2>/dev/null || true
}

startup_settle_sec() {
	local detected
	detected=$("$APPLY" detect 2>/dev/null || echo skip)
	if [[ "$detected" == laptop ]]; then
		echo 0
	else
		echo "${HOTPLUG_SETTLE_SEC:-5}"
	fi
}

schedule_apply() {
	local reason=${1:-hotplug}
	local settle
	cancel_debounce
	log "scheduled ($reason)"
	if [[ "$reason" == startup ]]; then
		settle=$(startup_settle_sec)
	else
		settle=${HOTPLUG_SETTLE_SEC:-5}
	fi
	(
		sleep "$settle"
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
				monitoradded*) schedule_apply monitoradded ;;
				monitorremoved*) schedule_apply monitorremoved ;;
				esac
			done
		fi
		sleep 2
	done
}

schedule_apply startup
listen_events
