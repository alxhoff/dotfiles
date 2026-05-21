#!/usr/bin/env bash
# Create a block-level copy of your root partition onto an external disk (from live USB).
#
# !!! DESTROYS ALL DATA on BACKUP_DEV !!!
#
# Usage (from live environment, as root):
#   SOURCE_DEV=/dev/nvme0n1p2 BACKUP_DEV=/dev/sda ./migrate/dd-backup.sh
#
# Optional:
#   STATUS=progress   — pv-style progress if using dd from coreutils with status=
#
set -euo pipefail

SOURCE_DEV=${SOURCE_DEV:-}
BACKUP_DEV=${BACKUP_DEV:-}

die() { echo "dd-backup: $*" >&2; exit 1; }

[[ -n "$SOURCE_DEV" && -n "$BACKUP_DEV" ]] || die "Set SOURCE_DEV (root partition) and BACKUP_DEV (external disk, e.g. /dev/sda)"

if [[ ! -b "$SOURCE_DEV" ]]; then
    die "SOURCE_DEV $SOURCE_DEV is not a block device"
fi
if [[ ! -b "$BACKUP_DEV" ]]; then
    die "BACKUP_DEV $BACKUP_DEV is not a block device"
fi

echo "Source:      $SOURCE_DEV ($(lsblk -no SIZE "$SOURCE_DEV"))"
echo "Destination: $BACKUP_DEV ($(lsblk -no SIZE,MODEL "$BACKUP_DEV"))"
echo ""
echo "WARNING: This will overwrite $BACKUP_DEV completely."
read -r -p "Type YES to continue: " confirm
[[ "$confirm" == "YES" ]] || die "Aborted."

# Unmount anything on the backup device
umount "${BACKUP_DEV}"* 2>/dev/null || true

if [[ $(id -u) -ne 0 ]]; then
    die "Run as root (live USB)"
fi

# Prefer same-size or larger target; dd copies min(source, dest) bytes when dest is larger
migrate_log() { echo "==> $*"; }

migrate_log "Starting dd (this may take hours)..."
dd if="$SOURCE_DEV" of="$BACKUP_DEV" bs=64M conv=sync,noerror status=progress

migrate_log "Syncing..."
sync

migrate_log "Done. Label the disk 'old-manjaro-root' and keep it for migrate/restore-from-backup.sh"
migrate_log "On the new system: mount the first partition, e.g.  mount /dev/sda1 /mnt/oldroot"
