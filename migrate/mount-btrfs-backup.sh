#!/usr/bin/env bash
# Mount a DD'd btrfs disk (Manjaro-style @ / @home layout) for migration.
#
# Usage:
#   sudo BACKUP_DISK=/dev/sdb ./migrate/mount-btrfs-backup.sh
#
# Then dry-run restore:
#   OLD_HOME=/mnt/btrfs-backup/alxhoff DRY_RUN=1 MIGRATE_YES=1 ./migrate/restore-from-backup.sh
#
set -euo pipefail

BACKUP_DISK=${BACKUP_DISK:-/dev/sdb}
MOUNT_POINT=${MOUNT_POINT:-/mnt/btrfs-backup}
# nvme0n1p2 start sector on source disk (default for this machine's layout)
PART_OFFSET_SECTORS=${PART_OFFSET_SECTORS:-618496}

die() { echo "mount-btrfs-backup: $*" >&2; exit 1; }
log() { echo "==> $*"; }

[[ $(id -u) -eq 0 ]] || die "Run with sudo"

if [[ ! -b "$BACKUP_DISK" ]]; then
    die "$BACKUP_DISK is not a block device"
fi

disk_sectors=$(blockdev --getsz "$BACKUP_DISK")
offset=$((PART_OFFSET_SECTORS * 512))
sizelimit=$((disk_sectors * 512 - offset))

log "Disk $BACKUP_DISK ($((disk_sectors * 512 / 1024 / 1024 / 1024)) GiB)"
log "Partition offset: $offset bytes, max size: $sizelimit bytes"

mkdir -p "$MOUNT_POINT"
if findmnt "$MOUNT_POINT" >/dev/null 2>&1; then
    log "Already mounted at $MOUNT_POINT"
    findmnt "$MOUNT_POINT"
    exit 0
fi

BTRFS_DEV=""

# Prefer kpartx when the DD includes a valid partition table (works after btrfs resize)
if kpartx -l "$BACKUP_DISK" 2>/dev/null | grep -q 'sdb2\|'"${BACKUP_DISK##*/}"'2'; then
    kpartx -av "$BACKUP_DISK" >/dev/null 2>&1 || true
    BTRFS_DEV="/dev/mapper/${BACKUP_DISK##*/}2"
    if [[ -b "$BTRFS_DEV" ]] && btrfs inspect-internal dump-super "$BTRFS_DEV" &>/dev/null; then
        log "Using partition device: $BTRFS_DEV"
    else
        BTRFS_DEV=""
        kpartx -d "$BACKUP_DISK" 2>/dev/null || true
    fi
fi

if [[ -z "$BTRFS_DEV" ]]; then
    # Fallback: loop + fix-device-size (truncated DD to smaller disk)
    while read -r line; do
        dev=$(echo "$line" | cut -d: -f1)
        [[ "$line" == *"$BACKUP_DISK"* ]] && losetup -d "$dev" 2>/dev/null || true
    done < <(losetup -a 2>/dev/null || true)

    BTRFS_DEV=$(losetup -f --show -o "$offset" --sizelimit "$sizelimit" "$BACKUP_DISK")
    log "Loop device: $BTRFS_DEV"

    if ! btrfs inspect-internal dump-super "$BTRFS_DEV" &>/dev/null; then
        die "No btrfs superblock — wrong BACKUP_DISK or partition offset?"
    fi

    log "Fixing btrfs device size (truncated DD)..."
    btrfs rescue fix-device-size "$BTRFS_DEV"
fi

log "Mounting @home subvolume read-only at $MOUNT_POINT"
mount -t btrfs -o ro,norecovery,subvol=/@home "$BTRFS_DEV" "$MOUNT_POINT"

if [[ ! -d "$MOUNT_POINT/${OLD_USER:-alxhoff}/git" ]]; then
    die "Expected $MOUNT_POINT/${OLD_USER:-alxhoff}/git — check OLD_USER or backup integrity"
fi

log "Backup home is readable."
echo ""
echo "Dry-run restore:"
echo "  OLD_HOME=$MOUNT_POINT/${OLD_USER:-alxhoff} DRY_RUN=1 MIGRATE_YES=1 ./migrate/restore-from-backup.sh"
