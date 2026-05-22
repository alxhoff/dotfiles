# EndeavourOS / Hyprland

Automated setup for **ML4W Hyprland Starter** + dotfiles fixes. Full guide: [docs/HYPRLAND-SETUP.md](../docs/HYPRLAND-SETUP.md).

## One command (fresh install)

```bash
./endeavour/setup-hyprland.sh
```

## Scripts

| Script | Role |
|--------|------|
| **`setup-hyprland.sh`** | **Main entry** — install starter, packages, patches |
| `install-ml4w-starter.sh` | Clone ML4W → `~/.mydotfiles/`, symlink `~/.config/hypr` … |
| `setup-hyprland-default.sh --ml4w` | pacman: Hyprland stack + ML4W deps |
| `apply-ml4w-patches.sh` | Apply `ml4w-patches/` for Hyprland 0.55 + waybar |
| `fix-ml4w-waybar.sh` | Fonts + re-apply patches |
| `fix-ml4w-hypr055.sh` | Alias for `apply-ml4w-patches.sh` |
| `switch-ml4w-hypr.sh` | Re-link `~/.config/hypr` only |
| `switch-vanilla-hypr.sh` | Optional minimal `dotfiles/hypr/` |
| `displays/` | Home/work monitor profiles (optional, later) |

## Patches

`ml4w-patches/` — version-controlled overrides applied on top of upstream ML4W.
