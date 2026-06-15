#!/usr/bin/env bash
# Re-apply dock layout after Sway start and after every `swaymsg reload`.
# Must stay alive: exec_always re-runs when this process exits.
set -euo pipefail

DISPLAYS="${HOME}/.config/dotfiles/endeavour/displays"
APPLY="${DISPLAYS}/apply-display-profile.sh"

sleep 3
if [[ -x "$APPLY" ]]; then
    "$APPLY" auto 2>&1 | while read -r line; do echo "session-bootstrap: $line"; done
fi

exec sleep infinity
