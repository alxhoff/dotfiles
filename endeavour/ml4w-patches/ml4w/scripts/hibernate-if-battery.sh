#!/usr/bin/env bash
# Hibernate only on battery. Skip (optionally notify) when on external power.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if "$SCRIPT_DIR/on-external-power.sh"; then
    [[ "${1:-}" == --notify ]] &&
        notify-send -t 4000 "Power" "Hibernate skipped — plugged into external power" 2>/dev/null || true
    exit 0
fi

exec systemctl hibernate
