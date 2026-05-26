# Config manifest

All **custom** configs live in this git repo. Setup scripts symlink them into `~/.config` (or into the ML4W tree that `~/.config/hypr` points at).

**Fresh machine:** `./endeavour/setup-hyprland.sh` (or `./install.sh` + `./endeavour/apply-ml4w-patches.sh`).

**After `git pull`:** `./endeavour/apply-ml4w-patches.sh` (re-links + re-patches waybar modules/style).

## Stable path

| Path | Purpose |
|------|---------|
| `~/.config/dotfiles` | Symlink → this repo (used in Hyprland `exec` / binds) |
| `~/.config/dotfiles-path` | Text file with absolute repo path (fallback for scripts) |

Clone location can differ; `~/.config/dotfiles` always resolves correctly once linked.

## Symlinked from repo (source of truth in git)

| Live path | Repo path |
|-----------|-----------|
| `~/.config/dotfiles` | `.` (repo root) |
| `~/.config/hypr/display-profiles` | `endeavour/displays/profiles/` |
| `~/.config/kanshi/config` | `endeavour/displays/kanshi.config` |
| `~/.config/hypr/scripts/dotfiles-display-hook.sh` | `endeavour/displays/dotfiles-display-hook.sh` |
| `~/.config/waypaper/config.ini` | `endeavour/ml4w-patches/waypaper/config.ini` |
| `~/.config/hypr/conf/*-dotfiles.conf`, `layouts.conf`, `autostart.conf`, … | `endeavour/ml4w-patches/hypr/conf/` |
| `~/.config/hypr/hyprlock.conf`, `hypridle.conf`, `hyprpaper.conf` | `endeavour/ml4w-patches/hypr/` |
| `~/.config/ml4w/scripts/*.sh` (patched set) | `endeavour/ml4w-patches/ml4w/scripts/` |
| `~/.config/ml4w/settings/networkmanager.sh` | `endeavour/ml4w-patches/ml4w/settings/` |
| `~/.config/waybar/config-primary.jsonc`, `config-secondary.jsonc`, `config`, `network_menu.xml` | `endeavour/ml4w-patches/waybar/` |
| `~/.config/fish/config.fish`, `conf.d/*` | `fish/` |
| `~/.vim`, `~/.vimrc`, `~/.vim_runtime` | `vim/` (submodule) |
| `~/.gitconfig` | `git/gitconfig` |
| `~/compose.yaml` | `docker/compose.yaml` |
| `~/.local/bin/*` | `bin/` |
| `~/.config/rofi` | `rofi/` (if not overridden by ML4W install keeping dotfiles link) |

Hypr/waybar/ml4w paths above are symlinked **into** `~/.mydotfiles/com.ml4w.hyprlandstarter/.config/`; `~/.config/hypr` → that tree.

## Patched at apply time (ML4W upstream base + repo snippets)

| Live path | How |
|-----------|-----|
| `~/.config/waybar/modules.json` | ML4W base + Python merge of `endeavour/ml4w-patches/waybar/*.jsonc` |
| `~/.config/waybar/style.css` | ML4W base + font line + appended `style-overrides.css` |

Re-run `./endeavour/apply-ml4w-patches.sh` after changing waybar snippets.

## Generated / local only (not in git)

| Path | Why |
|------|-----|
| `~/.config/hypr/monitors.conf` | Runtime layout; save to `profiles/*.hypr` via `save-display-profile.sh` |
| `~/.config/ml4w/wow-classic.env` | Local paths/secrets (example in repo) |
| `~/.config/ml4w/dropdown-terminal.env` | Local overrides (example in repo) |
| `~/.local/share/applications/com.valvesoftware.SteamLink.desktop` | Generated with `$HOME` |

## ML4W upstream only (not in dotfiles repo)

Installed by `install-ml4w-starter.sh` from [hyprland-starter](https://github.com/mylinuxforwork/hyprland-starter):

- `~/.config/hypr/hyprland.conf` (+ append-only `source = *-dotfiles.conf` lines)
- `~/.config/hypr/conf/{animations,decoration,general,input,...}.conf`
- `~/.config/kitty`, `dunst`, `wlogout`, `alacritty`
- ML4W scripts/settings not overridden in `ml4w-patches/`

Pin with `ML4W_TAG=v… ./endeavour/install-ml4w-starter.sh` if you need reproducible upstream versions.

## Scripts

| Script | Role |
|--------|------|
| `install.sh` | Symlink fish/vim/git/bin; skips vanilla `hypr/` when ML4W is installed |
| `endeavour/link-configs.sh` | Symlink all repo-owned Hyprland/ML4W/display configs |
| `endeavour/apply-ml4w-patches.sh` | `link-configs.sh` + waybar modules/style + hyprland.conf sources |
| `endeavour/setup-hyprland.sh` | Full one-shot (ML4W + packages + install.sh + apply) |
