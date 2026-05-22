# Display profiles (simple)

## Idea

1. **Save layouts** in `profiles/*.hypr` (from nwg-displays + `capture-layout.sh`).
2. **Detect** which dock is connected by monitor **description** (not `DP-7` vs `DP-10`).
3. **Apply** the matching profile to `~/.config/hypr/monitors.conf` and reload.

| Profile | When |
|---------|------|
| `home` | All of `HOME_DOCK_DESCRIPTIONS` in `config.env` are connected |
| `work` | Set `WORK_DOCK_DESCRIPTIONS` later (office) |
| `laptop` | No live external monitors |

## Home layout (first time or after moving monitors)

1. Plug in the home dock.
2. Open **nwg-displays**, arrange screens (rotations, positions), click **Apply**.
3. Run `./fix-nwg-monitors.sh` (merges split `transform` lines).
4. Save into dotfiles:

```bash
cd ~/git/Github/dotfiles/endeavour/displays
./capture-layout.sh home > profiles/home.hypr
./apply-display-profile.sh home    # test
```

## Daily use

Listener starts from Hyprland autostart. On plug/unplug it waits 3s and runs `apply-display-profile.sh auto`.

```bash
./restart-display-listener.sh
```

Manual:

```bash
./apply-display-profile.sh auto
./apply-display-profile.sh home
./apply-display-profile.sh laptop
```

When **home** applies, all workspaces and windows are moved to the primary external (`HOME_PRIMARY_DESCRIPTION`), then Hyprland **workspace rules** pin workspaces 1–10 to that monitor so they do not spread across screens. Same in reverse for **laptop** (everything → internal panel).

**Super+Shift+H** — home  
**Super+Shift+L** — force laptop panel on  

## Office (later)

```bash
./discover-monitors.sh | tee ~/monitor-discovery-work.txt
# Edit config.env WORK_DOCK_DESCRIPTIONS='...|...'
./capture-layout.sh work > profiles/work.hypr
```

## Files

- `config.env` — which descriptions mean home/work
- `profiles/home.hypr`, `laptop.hypr`, `work.hypr` — your layouts
- `apply-display-profile.sh` — detect + apply
- `hypr-display-listener.sh` — hotplug → auto
