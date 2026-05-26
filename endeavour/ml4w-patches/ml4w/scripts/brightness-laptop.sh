#!/usr/bin/env bash
# Laptop panel backlight only — hypridle dim/restore (external monitors unchanged).
set -euo pipefail

action=${1:?usage: brightness-laptop.sh dim|restore}
state="${XDG_RUNTIME_DIR:-/tmp}/brightness-laptop.saved"

mapfile -t devices < <(
	brightnessctl --list 2>/dev/null | sed -n "s/^Device '\([^']*\)' of class 'backlight':/\1/p"
)
[[ ${#devices[@]} -gt 0 ]] || exit 0

dev="${devices[0]}"
case "$action" in
	dim)
		brightnessctl -m "$dev" get >"$state"
		brightnessctl -q -m "$dev" set 10%
		;;
	restore)
		if [[ -f "$state" ]]; then
			saved=$(cat "$state")
			brightnessctl -q -m "$dev" set "$saved"
			rm -f "$state"
		elif ! brightnessctl -q -m "$dev" -r 2>/dev/null; then
			brightnessctl -q -m "$dev" set 55%
		fi
		;;
	*) exit 2 ;;
esac
