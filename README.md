# dotfiles

Personal configs for fish, bash, vim, Docker dev containers, and legacy i3/polybar.  
Migration to **EndeavourOS + Hyprland** is documented in [docs/MIGRATION.md](docs/MIGRATION.md).

## Quick start (new machine)

```bash
git clone --recurse-submodules git@github.com:alxhoff/dotfiles.git ~/git/Github/dotfiles
cd ~/git/Github/dotfiles
./install.sh
vim +PlugInstall +qall
```

## Restore from DD backup

After mounting the old root (e.g. `/mnt/oldroot`):

```bash
OLD_ROOT=/mnt/oldroot OLD_USER=alxhoff ./migrate/restore-from-backup.sh
```

`~/git` (~770 GB) is restored from the backup, **not** stored in this repo.

## Layout

| Path | Purpose |
|------|---------|
| `fish/` | Fish config + `conf.d/ub.fish` (ub20/22/24 Docker) |
| `bash/` | bashrc, profile, fzf |
| `vim/` | Submodule — vimrc, runtime, plugins |
| `docker/compose.yaml` | dockurr/windows VM (`windows` fish function) |
| `git/gitconfig` | Global git config |
| `bin/` | User scripts (e.g. spotify-adblock) |
| `polybar/`, `rofi/`, `i3/` | Legacy X11 desktop (reference) |
| `migrate/` | DD backup + rsync restore from old disk |
| `install.sh` | Symlink configs into `$HOME` |
| `archive/` | Old machine snapshots |

## Fish highlights

- `ub22`, `ub24` — Ubuntu dev containers with home directory bind-mount
- `windows` — Windows 11 VM via Docker (port 8006)
- Search/git helpers: `g`, `f`, `fc`, `gcp`, …

## License

GPL — see [LICENSE](LICENSE).
