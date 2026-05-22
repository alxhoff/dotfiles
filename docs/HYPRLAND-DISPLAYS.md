# Hyprland default session + home/work monitors

## Goals

1. **Boot into Hyprland** (ML4W config at `~/.config/hypr`) instead of Plasma.
2. **Auto layout** when docking at home vs work — like the old `i3/display_scripts/` + `polybar/launch.sh` logic.

## 1. Install Hyprland and set default session

You currently log in via **plasmalogin** with **Plasma** only (`/usr/share/wayland-sessions/plasma.desktop`). Hyprland must be installed as a session:

```bash
cd ~/git/Github/dotfiles
./endeavour/setup-hyprland-default.sh
```

Log out → on the login screen pick **Hyprland** → set as default if prompted.

ML4W configs under `~/.mydotfiles/com.ml4w.hyprlandstarter/` stay as-is; `~/.config/hypr` should already symlink there.

## 2. Calibrate monitor names (required once per site)

Hyprland names differ from old **xrandr** names (`DisplayPort-7`, `DP2-2`, …).

At **home dock**, in Hyprland:

```bash
cd ~/git/Github/dotfiles/endeavour/displays
./discover-monitors.sh | tee ~/monitor-discovery-home.txt
```

At **work dock**, run again and save `~/monitor-discovery-work.txt`.

Edit:

| File | Purpose |
|------|---------|
| `profiles/home.hypr` | Home + laptop panel |
| `profiles/home-no-laptop.hypr` | Home, internal screen off |
| `profiles/work.hypr` | Work triple 1920×1200 |
| `profiles/laptop.hypr` | Undocked |
| `kanshi.config` | Optional auto-switcher (description/name based) |

Old reference layouts:

- **Home:** 2560×1440 + 3840×2160 + eDP (see `i3/display_scripts/home-displays.sh`)
- **Work:** three 1920×1200, rotated (see `work-displays.sh`)
- **Work detection:** HDMI connected (`HDMI-A-*`) — same idea as `polybar/launch.sh`

## 3. Auto-apply on plug/unplug

### Option A — kanshi (recommended)

```bash
./endeavour/setup-hyprland-default.sh   # symlinks ~/.config/kanshi/config
# Arch has no kanshi systemd unit — start via hypr autostart:
#   exec-once = kanshi
```

Tune `endeavour/displays/kanshi.config` so each `profile { }` matches outputs present at that dock.

### Option B — Hyprland socket listener

Add to `~/.config/hypr/conf/autostart.conf`:

```
exec-once = ~/git/Github/dotfiles/endeavour/displays/hypr-display-listener.sh
```

Waits `HOTPLUG_SETTLE_SEC` (default 2s) after monitor add/remove, then runs `apply-display-profile.sh`.

### Manual test

```bash
./endeavour/displays/apply-display-profile.sh auto
./endeavour/displays/apply-display-profile.sh work
./endeavour/displays/apply-display-profile.sh home
```

Detection heuristics live in `config.env` (HDMI → work, 3840×2160 + externals → home, else laptop).

## 4. Detection tuning

Edit `endeavour/displays/config.env`:

- `WORK_HDMI_PATTERN` — work dock has HDMI (`HDMI-A` substring)
- `HOME_MIN_EXTERNAL` — how many non-eDP monitors for “docked”
- `HOTPLUG_SETTLE_SEC` — delay for slow docks

If the wrong profile triggers, use **kanshi** with monitor **description** strings from `discover-monitors.sh` (more stable than `DP-7` vs `DP-6`).

## 5. Polybar / waybar

ML4W ships **waybar**; your old polybar `launch.sh` monitor detection is replaced by kanshi + these profiles. Reload waybar after layout change if modules look wrong: `~/.config/ml4w/scripts/reload-waybar.sh` or `killall waybar && waybar`.
