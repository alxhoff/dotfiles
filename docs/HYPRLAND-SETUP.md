# Hyprland setup (reproducible)

Automated **ML4W Hyprland Starter** install with dotfiles fixes for **Hyprland 0.55+** and Waybar.

## Fresh EndeavourOS (after dotfiles clone)

```bash
cd ~/git/Github/dotfiles
git pull --recurse-submodules

# Optional: install package lists first
./packages/install-packages.sh

# Hyprland + ML4W + fish dotfiles + bobthefish (one shot)
./endeavour/setup-hyprland.sh
```

That single script runs `install.sh`, `fish/install-theme.sh`, ML4W clone, packages, and patches. You can still run `./install.sh` alone if you only need shell/editor links.

Log out → login session **Hyprland**.

## What `setup-hyprland.sh` does

| Step | Script | Purpose |
|------|--------|---------|
| 1 | `install-ml4w-starter.sh` | Clone [hyprland-starter](https://github.com/mylinuxforwork/hyprland-starter) → `~/.mydotfiles/`, symlink `~/.config/hypr`, waybar, … |
| 2 | `setup-hyprland-default.sh --ml4w` | pacman: hyprland, waybar, kitty, dunst, rofi, fonts, kanshi, jq, … |
| 3 | `install.sh` | Symlink fish, vim, docker, git, bin, …; write `~/.config/dotfiles-path` |
| 4 | `fish/install-theme.sh` | Oh My Fish + bobthefish + JetBrains Mono Nerd Font |
| 5 | `apply-ml4w-patches.sh` | Hypr 0.55 fixes + Waybar + display scripts (from `endeavour/ml4w-patches/`) |
| 6 | `fix-ml4w-waybar.sh` | Font cache refresh (idempotent) |

All scripts are **safe to re-run** after `git pull`.

**Agent / onboarding doc:** [AGENTS.md](../AGENTS.md)

## Config-only (packages already installed)

```bash
./endeavour/setup-hyprland.sh --skip-packages
```

## Individual scripts

```bash
./endeavour/install-ml4w-starter.sh      # clone + symlinks + patches
./endeavour/setup-hyprland-default.sh --ml4w
./endeavour/apply-ml4w-patches.sh
./endeavour/fix-ml4w-hypr055.sh            # legacy; patches supersede most of this
./endeavour/fix-ml4w-waybar.sh
./endeavour/switch-ml4w-hypr.sh            # re-link ~/.config/hypr only
```

## Vanilla minimal config (optional)

Not the default. For i3-style **Alt** binds only:

```bash
./install.sh --only hypr
```

See [hypr/README.md](../hypr/README.md).

## Monitor profiles (later)

[HYPRLAND-DISPLAYS.md](HYPRLAND-DISPLAYS.md) — kanshi, home/work docks.

## Pin ML4W starter version

```bash
ML4W_TAG=<tag> ./endeavour/install-ml4w-starter.sh
```

## Troubleshooting

```bash
Hyprland --verify-config -c ~/.config/hypr/hyprland.conf
cat ~/.cache/hyprland/hyprland.log
killall waybar; waybar &
```
