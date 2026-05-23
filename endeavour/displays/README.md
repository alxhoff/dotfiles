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

Listener starts from Hyprland autostart. On plug/unplug it waits **5s**, then applies the matching profile **once** (with an 8s cooldown to avoid reload loops).

```bash
./restart-display-listener.sh
```

Manual:

```bash
./apply-display-profile.sh auto
./apply-display-profile.sh home
./apply-display-profile.sh laptop
```

On **laptop** profile, windows are moved to the internal panel before externals are disabled.

**Alt+X** then **H** / **L** / **W** — home / laptop / work layout  
Manual apply also works if hotplug mis-detects.

If only 1–2 externals are connected (partial dock), auto mode does **nothing** (`skip`) until all home monitors appear or you apply manually.

## Office (later)

```bash
./discover-monitors.sh | tee ~/monitor-discovery-work.txt
# edit config.env WORK_DOCK_DESCRIPTIONS
./capture-layout.sh work > profiles/work.hypr
```

## Files

| Script | Role |
|--------|------|
| `apply-display-profile.sh` | detect + apply |
| `hypr-display-listener.sh` | hotplug → auto |
| `migrate-session.sh` | move windows before undock |
| `capture-layout.sh` | save live layout |
| `restart-display-listener.sh` | safe listener restart |
