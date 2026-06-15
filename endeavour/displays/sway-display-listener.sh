#!/usr/bin/env bash
# Hotplug listener for Sway (same debounce/apply logic as Hyprland).
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
	echo "$(date -Iseconds) sway-listener: $*" >>"$LOG"
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
	while true; do
		swaymsg -m '["output"]' 2>/dev/null | while read -r _; do
			schedule_apply output
		done
		sleep 2
	done
}

schedule_apply startup
listen_events
