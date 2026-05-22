#!/usr/bin/env bash
# Enable passwordless sudo for the current user (personal machine convenience).
#
# Usage:
#   ./migrate/configure-sudo-nopasswd.sh
#   DRY_RUN=1 ./migrate/configure-sudo-nopasswd.sh
#   SKIP_SUDO_NOPASSWD=1 ./migrate/configure-sudo-nopasswd.sh   # no-op
#
# Creates /etc/sudoers.d/99-<user>-nopasswd (mode 0440, validated with visudo).
# Remove that file to restore password prompts.
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=migrate/lib.sh
source "$SCRIPT_DIR/lib.sh"

DRY_RUN=${DRY_RUN:-0}
migrate_configure_nopasswd_sudo "$DRY_RUN"
