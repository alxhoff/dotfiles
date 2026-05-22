#!/usr/bin/env bash
# Repair Cursor chat history after opening Cursor before restore finished.
#
# Fixes duplicate workspaceStorage IDs, rebuilds the Glass agent chat index
# (one chat per project instead of a handful of merged buckets), and symlinks
# duplicate workspace IDs to the canonical restored data.
#
# Usage (Cursor must be fully quit):
#   ./migrate/fix-cursor-workspaces.sh
#   DRY_RUN=1 ./migrate/fix-cursor-workspaces.sh
#   OLD_HOME=/mnt/btrfs-backup/alxhoff ./migrate/fix-cursor-workspaces.sh
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=migrate/lib.sh
source "$SCRIPT_DIR/lib.sh"

DRY_RUN=${DRY_RUN:-0}
NEW_HOME=$(migrate_new_home)
MIGRATE_SCRIPT_DIR=$SCRIPT_DIR

migrate_fix_cursor_workspaces "$NEW_HOME" "$DRY_RUN"
