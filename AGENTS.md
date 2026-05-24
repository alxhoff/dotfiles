# Agent context — alxhoff dotfiles (EndeavourOS / Hyprland)

Persistent reference for Cursor and other coding agents. Read this before changing desktop, shell, or setup scripts.

**Canonical clone path:** `~/git/Github/dotfiles` (also works at `~/git/GitHub/dotfiles`; keep one spelling for Cursor workspace IDs). After `install.sh` or `apply-ml4w-patches.sh`, the resolved path is stored in `~/.config/dotfiles-path`.

## Reproduce a fresh machine

```bash
cd ~/git/Github/dotfiles
git pull --recurse-submodules

./packages/install-packages.sh          # optional; curated lists
./endeavour/setup-hyprland.sh           # ML4W + Hyprland + dotfiles + fish theme
git submodule update --init vim && vim +PlugInstall +qall
```

Log out → session **Hyprland**.

Config-only (no pacman): `./endeavour/setup-hyprland.sh --skip-packages`

| Step | Script | What it does |
|------|--------|--------------|
| 1 | `install-ml4w-starter.sh` | Clone ML4W starter → `~/.mydotfiles/com.ml4w.hyprlandstarter/`, symlink `~/.config/hypr`, waybar, kitty, … |
| 2 | `setup-hyprland-default.sh --ml4w` | pacman: hyprland stack, kitty, rofi, fonts, kanshi, jq, xorg-xhost, … |
| 3 | `install.sh` | Symlink fish, vim, docker compose, git, bin, … |
| 4 | `fish/install-theme.sh` | Oh My Fish + bobthefish + JetBrains Mono Nerd Font |
| 5 | `apply-ml4w-patches.sh` | Copy `endeavour/ml4w-patches/` into ML4W tree; write `~/.config/dotfiles-path` |
| 6 | `fix-ml4w-waybar.sh` | Font cache refresh |

Human docs: [docs/ENDEAVOUROS.md](docs/ENDEAVOUROS.md), [docs/HYPRLAND-SETUP.md](docs/HYPRLAND-SETUP.md).

## Architecture: ML4W + dotfiles patches

- **Upstream:** [ML4W Hyprland Starter](https://github.com/mylinuxforwork/hyprland-starter) lives at `~/.mydotfiles/com.ml4w.hyprlandstarter/`.
- **`~/.config/hypr`** (and waybar, ml4w, kitty, …) are **symlinks** into that tree.
- **Overrides** live in `endeavour/ml4w-patches/` and are applied by `endeavour/apply-ml4w-patches.sh` (safe to re-run after `git pull`).
- **Extra Hypr sources** appended to `hyprland.conf`: `binds-dotfiles.conf`, `windowrules-dotfiles.conf`, `general-dotfiles.conf`.
- Templates use `@DOTFILES@`; the apply script substitutes the real repo path.

Do **not** edit ML4W files in place without also updating `ml4w-patches/` — changes will be overwritten on re-apply.

## Hyprland customization summary

| Topic | Location | Notes |
|-------|----------|-------|
| Keybinds (Alt = mod, i3-style) | `ml4w-patches/hypr/conf/binds-dotfiles.conf` | Cheat sheet: `ml4w-patches/KEYBINDS.md`, `Alt+/` |
| Window gaps | `ml4w-patches/hypr/conf/general-dotfiles.conf` | `gaps_in = 5`, `gaps_out = 6 10 10 10`; Hyprland doubles inner gap between adjacent windows |
| Cursor IDE tiling | `ml4w-patches/hypr/conf/windowrules-dotfiles.conf` | `cursor` class forced tiled (was floating → extra top gap) |
| Autostart | `ml4w-patches/hypr/conf/autostart.conf` | waybar-launch, hyprpaper, waypaper, dunst, cliphist, hypridle, nm-applet, display listener |
| Passthrough (games / Steam Link) | `binds-dotfiles.conf` | `Alt+Esc` toggles; `Alt+Ctrl+G` game mode; `Alt+Ctrl+U` ungrab helper |
| Steam Link | `ml4w/scripts/steamlink*.sh`, `.local/share/applications/com.valvesoftware.SteamLink.desktop` | **`--windowed`** fixes mouse captive on Wayland; package: AUR `steamlink` |
| WoW Classic (local Proton) | `ml4w/scripts/wow-classic.sh`, `ml4w/settings/wow-classic.env.example` | Deck-style: Battle.net as non-Steam game + GE-Proton; `wow-classic.sh setup` |

## Dual Waybar (per monitor)

- **Launcher:** `~/.config/ml4w/scripts/waybar-launch.sh` (from patches).
- **Primary monitor** (pattern in `endeavour/displays/config.env`: `WAYBAR_PRIMARY_PATTERN=VX3276-QHD`): full bar → `config-primary.jsonc`.
- **Secondary / portrait:** minimal bar → `config-secondary.jsonc` (workspaces, passthrough, mpris, pulseaudio, clock). **Tray only on primary** — SNI (nm-applet) cannot register on two bars.
- **Restart on display change:** `endeavour/displays/dotfiles-display-hook.sh` calls waybar-launch after profile apply.
- **Logs:** `$XDG_RUNTIME_DIR/dotfiles-waybar/{primary,secondary}.log` if a bar disappears.
- **Idle inhibitor:** text labels “Awake” / “Auto-lock” (no Nerd Font icons in that module).

## Display profiles

- **Config:** `endeavour/displays/config.env`, profiles in `endeavour/displays/profiles/*.hypr`.
- **Hotplug listener:** `endeavour/displays/hypr-display-listener.sh` (autostart).
- **Manual apply:** `Alt+X` menu or `apply-display-profile.sh`.
- Docs: [docs/DISPLAY-SETUP.md](docs/DISPLAY-SETUP.md), [docs/HYPRLAND-DISPLAYS.md](docs/HYPRLAND-DISPLAYS.md).

Home dock monitors (description substrings): DELL UP2516D, VX3276-QHD, B246WL.

## Fish shell

- **Theme:** bobthefish via Oh My Fish (`fish/conf.d/omf.fish`, `fish/conf.d/bobthefish.fish`).
- **Install/repair:** `./fish/install-theme.sh` (clones OMF + theme; installs `ttf-jetbrains-mono-nerd` if missing).
- **Docker GUI on Wayland:** `fish/conf.d/wayland.fish` — `xhost` only if installed (`xorg-xhost`).
- **Container helpers:** `fish/conf.d/ub.fish` (ub20/22/24).

Kitty font: **JetBrainsMono Nerd Font** (matches bobthefish `theme_nerd_fonts yes`).

## Packages worth knowing

| Package | Why |
|---------|-----|
| `ttf-jetbrains-mono-nerd` | Fish prompt + kitty |
| `ttf-fira-sans`, `otf-font-awesome` | Waybar text vs icons |
| `jq` | Steam Link / Hypr helper scripts |
| `xorg-xhost` | Optional; rootless Docker X11 from fish |
| `steamlink` | AUR; remote play client |
| `steam`, `proton-ge-custom-bin` (AUR) | Local WoW Classic via Proton |
| `waypaper` | Wallpaper picker (`Alt+Ctrl+W`) |

Lists: `packages/recommended/pacman.list`, `packages/selected/`, `packages/selected/aur.list`.

## What is *not* fully automated

- **Monitor names** in display profiles — run `endeavour/displays/discover-monitors.sh` at each dock once, edit profiles.
- **Work dock** `WORK_DOCK_DESCRIPTIONS` in `config.env` — fill in after office discovery.
- **Vim plugins** — submodule + `PlugInstall`.
- **Cursor workspace repair** after disk migration — `./migrate/fix-cursor-workspaces.sh` (Cursor must be quit). See `migrate/SESSION-LOG.md`.
- **Spotify adblock** — manual build; see `docs/spotify-adblock.md`.

## Troubleshooting

```bash
Hyprland --verify-config -c ~/.config/hypr/hyprland.conf
cat ~/.cache/hyprland/hyprland.log
~/.config/ml4w/scripts/waybar-launch.sh    # restart dual waybar
./endeavour/apply-ml4w-patches.sh          # re-sync patches after git pull
```

## Legacy

- Minimal vanilla Hypr (not default): `./install.sh --only hypr` — see [hypr/README.md](hypr/README.md).
- Old X11/i3/polybar configs remain in repo for reference; daily driver is ML4W Hyprland.
