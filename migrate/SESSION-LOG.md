# Migration session log

**Purpose:** Running notes for humans and Cursor agents. If a chat is lost, read this file plus [docs/MIGRATION.md](../docs/MIGRATION.md) and script headers in `migrate/`.

**Machine context:** EndeavourOS on `nvme0n1` (LUKS). Old Manjaro system imaged with `migrate/dd-backup.sh` onto external USB disk.

---

## 2025-05-22 — Backup disk plugged in, script fixes

### Environment observed

| Item | Value |
|------|--------|
| Backup USB disk | `/dev/sda` (931 GiB, Samsung SSD 980, `usb` transport) |
| System disk | `nvme0n1` — **do not select for backup mount** |
| Default mount (wrong in old docs) | Docs said `/dev/sdb`; actual disk is **`/dev/sda`** |
| @home mount | `/mnt/btrfs-backup` → user `alxhoff` |
| Backup home | `/mnt/btrfs-backup/alxhoff` (git, Cursor, ssh present) |

`sudo BACKUP_DISK=/dev/sda ./migrate/mount-btrfs-backup.sh` succeeds (kpartx → `/dev/mapper/sda2`, btrfs `@home`).

### Bugs fixed this session

1. **Restore target `/root` when run under sudo** — `migrate_new_home()` now resolves the invoking user (`SUDO_USER` / `logname`) instead of root’s `$HOME`. Script aborts if destination would be `/root` unless `ALLOW_ROOT_DEST=1`.
2. **No interactive disk choice** — `migrate_select_backup_disk()` lists external block devices and prompts; `mount-btrfs-backup.sh` uses it when `BACKUP_DISK` is unset.
3. **Dry-run scanned entire ~770GB `git/`** — dry-run for `git` (and `MIGRATE_LARGE_PATHS`) logs intent only, no full rsync traversal.
4. **Ownership** — rsync uses `--numeric-ids` so UID/GID from backup are preserved (root-owned subtrees under user dirs stay root). `FIX_OWNERSHIP=1` remains opt-in (blind `chown -R` breaks mixed ownership).

### Recommended workflow (new machine)

```bash
cd ~/git/Github/dotfiles   # or GitHub — match your clone path

# Mount backup (prompts for disk if BACKUP_DISK unset)
sudo ./migrate/mount-btrfs-backup.sh
# or: sudo BACKUP_DISK=/dev/sda ./migrate/mount-btrfs-backup.sh

./migrate/check-backup.sh

# Quick preview (no full git scan)
DRY_RUN=1 MIGRATE_YES=1 ONLY=ssh,.gnupg,.config/Cursor,.cursor ./migrate/restore-from-backup.sh

# Full restore — run as normal user, NOT sudo ./migrate/...
MIGRATE_YES=1 ./migrate/restore-from-backup.sh
# or in parts: ONLY=git MIGRATE_YES=1 ./migrate/restore-from-backup.sh
```

### Open / follow-up

- [ ] Run full `~/git` restore when ready (hours).
- [ ] Symlink or standardize `git/Github` vs `git/GitHub` for Cursor workspace paths.
- [ ] `OLD_ROOT` mount if `spotify-adblock.so` needed from old `/usr/local/lib`.
- [x] Hyprland via ML4W starter (`~/.config/hypr` → `.mydotfiles`). Dotfiles: `endeavour/` snippets + [docs/ENDEAVOUROS.md](../docs/ENDEAVOUROS.md).

### 2025-05-22 — Ownership bug (root:root after restore)

**Symptom:** e.g. `~/git/Github/my_ubuntu` is `root:root` (mode 700) on the new system but `alxhoff:alxhoff` on the backup. Same pattern seen on `kicad`, `kernel_patcher` (empty root-owned dirs).

**Cause:** Older `lib.sh` used plain `rsync` without `--numeric-ids`. Running the restore script as **`sudo ./migrate/restore-from-backup.sh`** runs rsync as root; if destination dirs were created root-owned first, later rsync cannot fix them.

**Script fixes:** `sudo rsync -aHAX --numeric-ids`, refuse `sudo ./restore-from-backup.sh`, `migrate_fixup_dest_ownership` before each copy.

**Repair existing broken dirs** (example — re-copy one tree):

```bash
sudo rm -rf ~/git/Github/my_ubuntu
sudo rsync -aHAX --numeric-ids /mnt/btrfs-backup/alxhoff/git/Github/my_ubuntu/ ~/git/Github/my_ubuntu/
ls -lan ~/git/Github/my_ubuntu | head
```

Or re-run full `git` restore after `rm` of root-owned empty dirs (long).

### 2025-05-22 — Auto-mount + auto-detect @home

Restore failed with “set OLD_ROOT or OLD_HOME” while backup was already at `/mnt/btrfs-backup` — old script only looked for full root (`/etc`), not btrfs `@home`.

**Fix:** `migrate_resolve_old_home` finds `/mnt/btrfs-backup/alxhoff`; `migrate_ensure_backup_mounted` runs `sudo ./migrate/mount-btrfs-backup.sh` if needed. `check-backup.sh` and `restore-from-backup.sh` call ensure at start.

### 2025-05-22 — Staged ~/git (`restore-git.sh`)

Backup measured on `/dev/sda`: `git/Github` ~725G, `git/cartken` ~45G. Largest: `kernel_builder` (625G) with `storage/kernels` ~344G, `scripts/rootfs` ~133G, `scripts/usb_disk` ~112G.

**Added:** `restore-git.sh` + `git-restore-steps.conf` — small repos first via `git-large-repos.txt` excludes, then large repos one-by-one, then `kernel_builder` bulk paths last.

### 2025-05-22 — Staged orchestrator `restore-all.sh`

**Added:** `./migrate/restore-all.sh` runs steps from `migrate/restore-steps.conf` in order:

1. precheck — mount + `check-backup.sh`
2. secrets — `.ssh`, `.gnupg`
3. cursor — `.config/Cursor`, `.cursor`, `.config/Code`
4. desktop — fish, spotify, gcloud, compose
5. browser — Firefox
6. vm — windows, window_data
7. git — `~/git` (last, hours)
8. system — spotify-adblock.so (needs `OLD_ROOT` full mount)

Each step **finishes**, then prompts before the next (`RESTORE_FROM_STEP=<id>` to resume).

**lib.sh** updated with session-log fixes: `--numeric-ids`, refuse root restore, `migrate_ensure_backup_mounted`, fast dry-run for large paths, `migrate_fixup_dest_ownership`.

### 2025-05-22 — Glass UI + workspace fix v2 (`fix-cursor-workspaces.py`)

**Symptom:** After v1 dedupe, some chats appeared but history looked empty; no Archived section; reopening folders recreated duplicate workspace IDs (e.g. `923582…` for `kernel_builder`).

**Cause:** New Cursor Glass UI auto-created `glass.localAgentProjects.v1` (10 buckets) and lumped ~130 chats into them. Backup had no Glass keys. New Cursor also mints fresh `workspaceStorage` IDs per open, ignoring restored IDs with the actual chat DB.

**Fix:** Enhanced `./migrate/fix-cursor-workspaces.sh` to:
- pick canonical workspace per folder (prefer backup ID + largest DB)
- merge duplicate workspace DB rows, remove dup dir, **symlink** old duplicate ID → canonical
- remap all composer headers to canonical workspace IDs + `hasBeenInSidebar: true`
- rebuild Glass index: **one project per composer chat** (~200), fix membership
- write `migrate-canonical-workspaces.json`

**Verified dry-run:** 200 glass projects, 212 membership entries, symlink `923582…` → `26ffc001…`.

```bash
# Cursor fully quit first
./migrate/fix-cursor-workspaces.sh
```

### 2026-05-22 — Symlink-equivalent workspace merge (`fix-cursor-workspaces.py`)

**Symptom:** `kernels/cartken_5_1_5` symlink restored, but opening that folder shows no chats.

**Cause:** Cursor keys workspace history by literal `file://` path, not resolved directory. After `kernels/` → `storage/kernels/` move, history was split across three workspace IDs for the same directory:
- `7f079aa5…` — old symlink path (13 chats, 244K DB)
- `43f95948…` — new real path (2 chats)
- `a23cf6f6…` — empty ID minted on reopen today (4 new composer headers)

Filesystem symlink does not help; Glass index also stale (55 projects vs 210 composer heads).

**Fix:** Merge workspace groups by `Path.resolve()` before dedupe. Prefer the path the user opens (symlink) as canonical URI; remap composer `fsPath` and symlink duplicate workspace IDs to the canonical DB.

**Verified dry-run:** merges storage URI → symlink URI; keeps `7f079aa5…`; removes/symlinks `a23cf6f6…` + `43f95948…`; rebuilds 210 Glass projects.


When changing migrate scripts: **append a dated section here** (what changed, why, commands verified). Update `docs/MIGRATION.md` if user-facing steps change.
