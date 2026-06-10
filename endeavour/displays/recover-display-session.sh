#!/usr/bin/env bash
# Recover from broken tiles / invisible windows after a bad dock switch.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REFRESH="${HOME}/.config/ml4w/scripts/refresh-session-layouts.sh"

echo "==> Refreshing tiled layouts and dropdown positions"
if [[ -x "$REFRESH" ]]; then
    "$REFRESH"
else
    echo "refresh script missing — run ./endeavour/link-configs.sh" >&2
    exit 1
fi

profile=$(cat "${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-profile" 2>/dev/null || true)
if [[ -n "$profile" && "$profile" != skip ]]; then
    echo "==> Re-applying active profile: $profile"
    "$SCRIPT_DIR/apply-display-profile.sh" "$profile"
fi

echo "==> Done. If one monitor is still broken, move its windows to workspace 2 (Alt+Ctrl+2), then back."
