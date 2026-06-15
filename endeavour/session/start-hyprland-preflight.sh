#!/usr/bin/env bash
# System session entry (installed to /usr/local/lib/dotfiles/ by install-hypr-session.sh).
set -euo pipefail

HOME="${HOME:-$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)}"
DOTFILES="${DOTFILES:-$HOME/.config/dotfiles}"
VALIDATE="$DOTFILES/endeavour/displays/validate-monitors-conf.sh"

if [[ -x "$VALIDATE" ]]; then
    "$VALIDATE" || true
fi

exec /usr/bin/start-hyprland "$@"
