#!/usr/bin/env bash
# Sanity-check the mounted backup home before restore.
#
# Usage:
#   ./migrate/check-backup.sh
#   OLD_HOME=/mnt/btrfs-backup/alxhoff ./migrate/check-backup.sh
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=migrate/lib.sh
source "$SCRIPT_DIR/lib.sh"

MANIFEST=${MANIFEST:-$SCRIPT_DIR/manifest.conf}
migrate_ensure_backup_mounted "$SCRIPT_DIR"
migrate_check_backup_home "" "$MANIFEST"
