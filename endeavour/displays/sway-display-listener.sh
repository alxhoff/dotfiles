#!/usr/bin/env bash
# Hotplug listener for Sway (same debounce/apply logic as Hyprland).
set -euo pipefail

DOTFILES_DISPLAYS=${DOTFILES_DISPLAYS:-$HOME/.config/dotfiles/endeavour/displays}
APPLY="$DOTFILES_DISPLAYS/apply-display-profile.sh"
# shellcheck source=endeavour/displays/config.env
source "$DOTFILES_DISPLAYS/config.env"
# shellcheck source=endeavour/displays/lib.sh
source "$DOTFILES_DISPLAYS/lib.sh"

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
			detected=$(detect_profile_name "$APPLY")
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

schedule_apply() {
	local reason=${1:-hotplug}
	local settle

	# Each output event used to reset the 5s timer — dock never settled. Coalesce instead.
	if [[ "$reason" == output ]]; then
		if debounce_running "$DEBOUNCE"; then
			log "debounce already pending ($reason)"
			return 0
		fi
	else
		cancel_debounce
	fi

	settle=$(hotplug_settle_sec "$reason" "$APPLY" "$STATE")
	log "scheduled ($reason, settle=${settle}s)"
	(
		trap 'rm -f "$DEBOUNCE"' EXIT
		sleep "$settle"
		run_apply
	) &
	echo $! >"$DEBOUNCE"
}

listen_events() {
	while true; do
		log "subscribing to output events"
		swaymsg -t subscribe -m '["output"]' 2>/dev/null | while read -r _; do
			schedule_apply output
		done || true
		log "subscribe ended — retrying in 2s"
		sleep 2
	done
}

schedule_apply startup
listen_events
