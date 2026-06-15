#!/usr/bin/env bash
# Fix broken tiles / invisible windows after a bad dock switch.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "$SCRIPT_DIR/apply-display-profile.sh" recover
