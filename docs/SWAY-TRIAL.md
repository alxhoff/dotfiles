# Sway trial (reversible)

Hyprland/ML4W stays your default. Sway is installed as a **second login session** so you can compare tiling behavior — especially native **tabbed/stacked** layouts (`Alt+W` / `Alt+S`) without Hyprland window groups.

## Install

```bash
cd ~/git/Github/dotfiles
./endeavour/sway/install-sway-trial.sh
```

Log out → plasmalogin → **Sway (dotfiles trial)**.

## Switch back

Log out → **Hyprland**. No restore script needed; `~/.config/hypr` and ML4W patches are never modified.

## What was ported

| Source | Sway trial |
|--------|------------|
| `i3/config` | `sway/config.d/` — gaps, colors, most keybinds, window rules |
| `endeavour/ml4w-patches/KEYBINDS.md` | kitty, rofi, grim, workspace binds |
| `endeavour/displays/profiles/*.hypr` | `sway/profiles/*.sway` (manual `output` lines) |
| ML4W waybar | Same bar via `sway/scripts/waybar-launch.sh` (`sway/*` modules) |
| Hyprland wallpapers | waypaper + swaybg, `~/Pictures/wallpaper` |
| ML4W `input.conf` | US keyboard in `sway/config.d/00-base.conf` |

**Layout keys work like i3:** `Alt+W` tabbed, `Alt+S` stacked, `Alt+E` toggle split — on the **focused container**, not “per monitor via groups”.

## Feature parity with Hyprland

Sway trial now uses the same dotfiles stack where possible:

| Feature | Status |
|---------|--------|
| Dual ML4W waybar | Yes (`sway/*` modules) |
| Wallpapers (waypaper folder) | Yes (swaybg) |
| Dropdown terminal F12 | Yes |
| Dropdown Spotify F11 | Yes |
| Display hotplug + profiles | Yes (`apply-display-profile.sh` auto-detects Sway) |
| Passthrough / Steam Link | Yes |
| dunst, nm-applet, cliphist, idle | Yes |

Only **tiling/layout** differs: native i3 `Alt+W/S/E` instead of Hyprland window groups.

## Not included yet

- `equalize-tiling.sh` (Hyprland dwindle-specific)
- Hyprland-only portrait auto-split (`dwindle-auto-split.sh`)

## Displays

Profiles: `sway/profiles/{laptop,home,home-no-laptop,work}.sway`

- **Alt+X** then **l** / **h** / **w**
- Connector names (`DP-7`, `eDP-1`, …) may differ from Hyprland — check:

```bash
swaymsg -t get_outputs
```

Edit the `.sway` files when dock wiring changes.

## Remove trial

```bash
./endeavour/sway/remove-sway-trial.sh
```

Packages remain installed unless you remove them with pacman.

## Files

| Path | Purpose |
|------|---------|
| `sway/config` | Main config |
| `sway/config.d/*.conf` | Base, keybinds, rules, autostart |
| `sway/scripts/start-sway.sh` | Session entry |
| `~/.local/share/wayland-sessions/sway-dotfiles.desktop` | Greeter entry |
