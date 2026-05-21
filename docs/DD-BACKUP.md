# DD backup notes

## Disk-to-disk vs partition-to-partition

**Whole disk (`BACKUP_DEV=/dev/sda`):** copies partition table + all partitions. On the new machine, mount the partition that held `/`, e.g. `/dev/sda1` or `/dev/sda2`.

**Partition to partition (`dd if=/dev/nvme0n1p2 of=/dev/sda1`):** only works if the target partition is **≥ source size**. Prefer imaging to a spare disk at least as large as your root partition.

## Size check

```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
sudo blockdev --getsize64 /dev/nvme0n1p2   # source bytes
sudo blockdev --getsize64 /dev/sda         # target bytes
```

## Mounting on the new system

```bash
sudo mkdir -p /mnt/oldroot
sudo mount -o ro /dev/sda1 /mnt/oldroot
ls /mnt/oldroot/home/alxhoff/git   # should exist
```

Use `OLD_ROOT=/mnt/oldroot` for `migrate/restore-from-backup.sh`.

## Encrypted root

If the old root was LUKS, you must unlock before mount:

```bash
sudo cryptsetup open /dev/sda2 cryptbackup
sudo mount /dev/mapper/cryptbackup /mnt/oldroot
```

## Alternative to DD

For **`~/git` only**, a dedicated `rsync -aHAX` from old system to external drive (or NAS) may be faster and resumable than imaging the whole root. DD is still valuable for “find anything we forgot” (Cursor, Firefox, stray configs).
