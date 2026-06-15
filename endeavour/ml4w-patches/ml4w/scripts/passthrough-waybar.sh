#!/usr/bin/env bash
# Waybar JSON: passthrough indicator (Hyprland submap / Sway mode).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=compositor.sh
source "$SCRIPT_DIR/compositor.sh"

if compositor_is_sway; then
	flag="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-sway-passthrough"
	if [[ -f "$flag" ]]; then
		printf '{"text":" PASSTHROUGH ","tooltip":"Passthrough — Alt+Esc to exit","class":"active"}\n'
	else
		printf '{"text":""}\n'
	fi
	exit 0
fi

sub=$(hyprctl submap 2>/dev/null | tr -d '[:space:]')
if [[ "$sub" == "passthrough" ]]; then
	printf '{"text":" PASSTHROUGH ","tooltip":"Passthrough — Alt+Esc to exit","class":"active"}\n'
else
	printf '{"text":""}\n'
fi
