# Migration guide (Manjaro → EndeavourOS + Hyprland)

This repo holds **configs and scripts** (symlinked via `install.sh`). Large personal data — especially **`~/git` (~770 GB on the current machine)** — lives on disk and is restored from your **DD backup** via `migrate/restore-from-backup.sh`.

## Overview

| What | Where |
|------|--------|
| Dotfiles (fish, vim, bash, docker compose, …) | This git repo → `./install.sh` |
| `~/git`, Cursor, Firefox, SSH, Windows VM, … | DD external disk → `migrate/restore-from-backup.sh` |
| Spotify adblock `.so` | `/usr/local/lib/` on old root → restored by migrate script |

## Phase 1 — Before reinstall (current machine)

1. Commit and push dotfiles changes.
2. Optional: run `DRY_RUN=1 ./migrate/restore-from-backup.sh` is for the *new* machine only.
3. Boot **live USB** (Endeavour or Arch ISO).

## Phase 2 — DD root to external disk (live USB)

Identify devices (`lsblk`):

- `SOURCE_DEV` — your current **root partition** (e.g. `/dev/nvme0n1p2`)
- `BACKUP_DEV` — entire external disk (e.g. `/dev/sda`) — **will be wiped**

```bash
cd /path/to/dotfiles   # mount your home or clone repo on live system if needed
sudo SOURCE_DEV=/dev/nvme0n1p2 BACKUP_DEV=/dev/sda ./migrate/dd-backup.sh
```

This creates a raw sector copy. On the new system you usually mount the **first partition** of that disk, e.g. `sudo mount /dev/sda1 /mnt/oldroot`. If you DD'd a partition to a partition instead of disk-to-disk, adjust accordingly.

See [DD-BACKUP.md](DD-BACKUP.md) for pitfalls (size, partition table).

## Phase 3 — Fresh EndeavourOS install

- Plan **encryption** (LUKS full disk or encrypted `/home`) before install.
- Create your user (username can differ from `alxhoff` — set `OLD_USER` / `OLD_HOME` when restoring).
- Install base packages you need: `fish`, `docker`, `vim`, `git`, `openssh`, `rsync`, `firefox`, `spotify`, Hyprland stack, etc.
- Add user to `docker` and `kvm` groups for `ub22` / `windows`.

## Phase 4 — Clone dotfiles on new system

```bash
mkdir -p ~/git/Github
git clone git@github.com:alxhoff/dotfiles.git ~/git/Github/dotfiles
cd ~/git/Github/dotfiles
git submodule update --init vim
```

## Phase 5 — Restore from DD backup

```bash
sudo mount /dev/sda1 /mnt/oldroot    # adjust device
cd ~/git/Github/dotfiles

# Preview sizes
DRY_RUN=1 OLD_ROOT=/mnt/oldroot OLD_USER=alxhoff ./migrate/restore-from-backup.sh

# Full restore (hours for ~/git)
OLD_ROOT=/mnt/oldroot OLD_USER=alxhoff ./migrate/restore-from-backup.sh

# Or restore in parts:
ONLY=git OLD_ROOT=/mnt/oldroot ./migrate/restore-from-backup.sh
ONLY=ssh,.gnupg,.config/Cursor,.cursor OLD_ROOT=/mnt/oldroot ./migrate/restore-from-backup.sh
```

**Cursor chats:** Quit Cursor before restore. After restoring `.config/Cursor` / `.cursor`, the script deduplicates workspace IDs, rebuilds the Glass agent chat index, and symlinks duplicate IDs to restored data. If you opened Cursor too early:

```bash
# Cursor must be fully quit first
./migrate/fix-cursor-workspaces.sh
```

Re-running `./install.sh` (with Cursor closed) also invokes this repair automatically.

Edit `migrate/manifest.conf` to add paths (e.g. `Cartken`) or comment out what you skip.

After restore, fix root-owned files if needed:

```bash
sudo chown -R "$USER:$USER" ~/git ~/windows ~/.config/Cursor
```

Update git safe directories if kernel paths moved:

```bash
git config --global --add safe.directory ~/git/Github/kernel_builder/scripts/rootfs/5.1.5/Linux_for_Tegra/kernel_src
```

## Phase 6 — Install packages & link dotfiles

On the **old** machine, export and choose packages (see [packages/README.md](../packages/README.md)):

```bash
./packages/export-inventory.sh
./packages/select-packages.sh --merge-recommended
git add packages/selected && git commit -m "Package selection for new install"
```

On the **new** machine:

```bash
./packages/install-packages.sh
./install.sh
vim +PlugInstall +qall
```

## Phase 7 — Hyprland

Hyprland: run `./endeavour/setup-hyprland.sh` after `./install.sh` — see [HYPRLAND-SETUP.md](HYPRLAND-SETUP.md). Fish/docker/vim work unchanged; `ub.fish` may need Wayland/XWayland tweaks instead of `xhost +` over time.

## What not to put in git

- `~/git` (hundreds of GB of projects)
- `~/.ssh`, `~/.gnupg`
- Cursor `state.vscdb`, Firefox profiles
- `~/windows/data.img`, `~/.cache/spotify`
- Spotify `prefs` (credentials)
