#!/usr/bin/env bash
# User-level session wrapper (~/.local/bin/dotfiles-start-hyprland).
# plasmalogin uses /usr/local/lib/dotfiles/start-hyprland-preflight.sh after install-hypr-session.sh.
set -euo pipefail

PREFLIGHT=/usr/local/lib/dotfiles/start-hyprland-preflight.sh
if [[ -x "$PREFLIGHT" ]]; then
    exec "$PREFLIGHT" "$@"
fi

DOTFILES=${DOTFILES:-$HOME/.config/dotfiles}
VALIDATE="$DOTFILES/endeavour/displays/validate-monitors-conf.sh"
if [[ -x "$VALIDATE" ]]; then
    "$VALIDATE" || true
fi

exec /usr/bin/start-hyprland "$@"
