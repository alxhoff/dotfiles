# EndeavourOS daily setup

Post-migration reference for this machine. For backup/restore, see [MIGRATION.md](MIGRATION.md).

## One-time bootstrap

```bash
cd ~/git/Github/dotfiles   # or ~/git/GitHub/dotfiles — keep path consistent for Cursor
git pull --recurse-submodules
./packages/install-packages.sh
./endeavour/setup-hyprland.sh    # ML4W + Hyprland + install.sh + fish theme
git submodule update --init vim
vim +PlugInstall +qall
```

`install.sh` is included in `setup-hyprland.sh`. Run it alone for partial updates: `./install.sh --only fish,vim`.

**Agent context (for Cursor):** [../AGENTS.md](../AGENTS.md)

## Desktop: Hyprland (ML4W starter)

**Full guide:** [HYPRLAND-SETUP.md](HYPRLAND-SETUP.md)

```bash
./endeavour/setup-hyprland.sh    # one-shot: clone ML4W, packages, 0.55 patches, symlinks
```

Re-run after `git pull` to re-apply patches. Config overrides live in `endeavour/ml4w-patches/`.

**Minimal fallback (i3-style Alt binds):** [../hypr/README.md](../hypr/README.md) — `./install.sh --only hypr`

**→ Displays (no arandr):** [DISPLAY-SETUP.md](DISPLAY-SETUP.md) · [HYPRLAND-DISPLAYS.md](HYPRLAND-DISPLAYS.md)

| Path | Role |
|------|------|
| `~/.mydotfiles/com.ml4w.hyprlandstarter/` | Stock ML4W configs |
| `dotfiles/hypr/` | Optional minimal config |
| `endeavour/*.snippet.conf` | Copy into ML4W `conf/` when you want extras |

**Errors:** `~/.cache/hyprland/hyprland.log`, `journalctl --user -b | grep -i hypr`

Reload: `hyprctl reload` or log out/in.

## Shell & containers

| Tool | Notes |
|------|--------|
| Fish | `fish/config.fish`, `fish/conf.d/ub.fish` (Docker ub20/22/24), **bobthefish** via `./fish/install-theme.sh` |
| `windows` | `~/compose.yaml` → dockurr Windows VM |
| Wayland | `fish/conf.d/wayland.fish` sets XWayland-friendly `DISPLAY` / `xhost` for GUI Docker |

Ensure your user is in `docker` and `kvm` groups.

## Cursor chats

If chats are missing or workspaces duplicated after restore:

1. **Quit Cursor completely**
2. `cd ~/git/Github/dotfiles && ./migrate/fix-cursor-workspaces.sh`

Details and history: `migrate/SESSION-LOG.md`.

Keep **`~/git/Github`** vs **`~/git/GitHub`** spelling consistent — Cursor keys workspaces by literal `file://` paths.

## Spotify adblock

```bash
# Build/install .so per docs/spotify-adblock.md, then:
./install.sh --only bin
spotify-adblock   # or bind in Hyprland keybinds
```

## Useful commands

```bash
./install.sh --dry-run
./install.sh --only fish,vim,docker
hyprctl monitors
systemctl --user status pipewire pipewire-pulse wireplumber
```

## Legacy (X11 / Manjaro)

`i3/`, `polybar/`, `rofi/` remain for reference. Do not link with `./install.sh` unless you need an X11 session:

```bash
./install.sh --only i3,polybar,rofi
```
