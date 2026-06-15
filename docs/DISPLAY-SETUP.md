# Display setup on Hyprland (no arandr)

On Wayland, **arandr/xrandr do not apply**. Use Hyprland’s `monitor=` rules plus this repo’s `endeavour/displays/` tools.

**Canonical guide:** [endeavour/displays/README.md](../endeavour/displays/README.md) (hotplug listener only — kanshi removed).

## Overview

| Tool | Role |
|------|------|
| **`discover-monitors.sh`** | List connector names (`DP-1`, `HDMI-A-1`, `eDP-1`) — names change between docks |
| **`capture-layout.sh`** | Save **current** layout to `profiles/*.hypr` (closest thing to “Save as arandr”) |
| **`apply-display-profile.sh`** | Apply a profile (`home`, `work`, `laptop`, or `auto`) |
| **`kanshi.config`** | Auto-switch when you plug/unplug a dock |
| **nwg-displays** (optional GUI) | Drag monitors like arandr, writes Hypr `monitor=` lines |

Profiles live in the repo: `endeavour/displays/profiles/*.hypr`

## Step 1 — Discover (once per dock)

Log into **Hyprland** with the dock connected how you normally use it.

**Home:**

```bash
cd ~/git/Github/dotfiles/endeavour/displays
./discover-monitors.sh | tee ~/monitor-discovery-home.txt
```

**Work:** same at the office → `~/monitor-discovery-work.txt`

Note the **`name`** column (`DP-1`, `HDMI-A-1`, …) and **`description`** (monitor model — more stable in kanshi).

## Step 2 — Build a reference layout

### Option A — GUI (easiest, arandr-like)

```bash
sudo pacman -S nwg-displays
nwg-displays
```

1. Drag monitors, set rotation (portrait = 90°).
2. Click **Apply** in nwg-displays (writes `~/.config/hypr/monitors.conf`).
3. **Required on ML4W:** Hyprland was not loading that file, and nwg splits `transform` onto a second line Hyprland ignores. Run:

```bash
cd ~/git/Github/dotfiles/endeavour/displays
./fix-nwg-monitors.sh
```

4. Optional — copy into git profile:

```bash
./capture-layout.sh home > profiles/home.hypr
```

`monitor.conf` is patched to `source = ~/.config/hypr/monitors.conf` (see `endeavour/ml4w-patches/hypr/conf/monitor.conf`).

### Option B — Capture only (no extra package)

1. Hyprland often auto-places monitors on plug-in; tweak if needed:

```bash
# Example: move/rotate one output (see hyprctl monitors for names)
hyprctl keyword monitor=DP-1,2560x1440@60,0x0,1
hyprctl keyword monitor=DP-2,3840x2160@60,2560x0,1
hyprctl keyword monitor=eDP-1,1920x1080@60,640x1440,1
# Rotation: append ,transform,1  (90°) or ,transform,3 (270°)
```

2. When the layout looks correct:

```bash
./capture-layout.sh home  > profiles/home.hypr
./capture-layout.sh work  > profiles/work.hypr
./capture-layout.sh laptop > profiles/laptop.hypr
```

3. Test:

```bash
./apply-display-profile.sh home
./apply-display-profile.sh work
./apply-display-profile.sh auto   # uses heuristics in config.env
```

Edit captured files if one line is wrong; lines starting with `#` are ignored.

## Step 3 — Auto-switch on dock (optional)

### kanshi (recommended)

```bash
# Already installed by setup-hyprland.sh; enable in autostart:
# Add to ~/.config/hypr/conf/autostart.conf:
#   exec-once = kanshi
```

Edit `endeavour/displays/kanshi.config` using **descriptions** from `discover-monitors.sh` (more stable than `DP-6` vs `DP-7`).

Symlink is created by `setup-hyprland-default.sh`:

`~/.config/kanshi/config` → `endeavour/displays/kanshi.config`

Reload: `pkill kanshi; kanshi &`

### Socket listener (fallback)

In `~/.config/hypr/conf/autostart.conf`:

```
exec-once = ~/git/Github/dotfiles/endeavour/displays/hypr-display-listener.sh
```

Waits `HOTPLUG_SETTLE_SEC` (see `config.env`) then runs `apply-display-profile.sh auto`.

## Home dock auto-apply (exact setup)

When **DP-7, DP-8, DP-9** and **eDP-1** are all connected, the **home** profile applies (portrait sides, laptop off).

```bash
./endeavour/displays/enable-display-autostart.sh   # once: kanshi + hotplug listener
```

- **kanshi** — `endeavour/displays/kanshi.config` (profile `home` must match all four outputs)
- **hypr-display-listener** — fallback: `apply-display-profile.sh auto` after plug/unplug

Match by **monitor description** (stable when port names flip DP-7 ↔ DP-10):

```bash
HOME_DOCK_DESCRIPTIONS='DELL UP2516D|VX3276-QHD|B246WL'
HOME_DOCK_REQUIRE_EDP=1
```

Run `./discover-monitors.sh` after a replug if detection fails — copy substrings from descriptions.

Test: unplug dock → laptop layout; plug dock → wait ~2s → home layout.

## Step 4 — Tune detection

Edit `endeavour/displays/config.env`:

| Variable | Meaning |
|----------|---------|
| `WORK_HDMI_PATTERN` | Work dock has HDMI (`HDMI-A`) |
| `HOME_MIN_EXTERNAL` | Min external monitors for “home docked” |
| `HOTPLUG_SETTLE_SEC` | Delay before apply after plug (slow docks) |

If `auto` picks the wrong profile, rely on **kanshi** profiles matched by connected outputs.

## Hyprland `monitor=` cheat sheet

```
monitor=NAME,RESOLUTION@REFRESH,POSITION,SCALE
monitor=NAME,preferred,auto,1          # let Hypr decide position
monitor=NAME,disable                   # turn off (e.g. laptop when docked)
monitor=NAME,1920x1200@60,0x0,1,transform,1   # 90° rotation
```

**Transform:** `0` normal, `1` 90°, `2` 180°, `3` 270°.

## Old i3/xrandr reference

| Site | Legacy script |
|------|----------------|
| Home | `i3/display_scripts/home-displays.sh` |
| Work | `i3/display_scripts/work-displays.sh` |
| Laptop | `i3/display_scripts/laptop-displays.sh` |

Port positions into `profiles/*.hypr` using names from `discover-monitors.sh`, not the old `DP2-2` xrandr names.

## More

[HYPRLAND-DISPLAYS.md](HYPRLAND-DISPLAYS.md) — session default, polybar/waybar notes.
