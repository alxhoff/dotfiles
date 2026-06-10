# Display profiles (simple)

## Idea

1. **Save layouts** in `profiles/*.hypr` in **this repo** (`endeavour/displays/profiles/`).
2. **Detect** which dock is connected by monitor **description** (not `DP-7` vs `DP-11` — connector names change; profiles map via `# description` lines on apply).
3. **Apply** the matching profile to `~/.config/hypr/monitors.conf` and reload.

**Important:** `nwg-displays` only writes `~/.config/hypr/monitors.conf` (runtime). It does **not**
update `profiles/*.hypr`. After arranging in nwg, run `./save-display-profile.sh work` (or `home`).

| File | Role |
|------|------|
| `profiles/home.hypr` | Source of truth — in git |
| `profiles/work.hypr` | Source of truth — in git |
| `~/.config/hypr/display-profiles` | Symlink → repo `profiles/` |
| `~/.config/hypr/monitors.conf` | Generated at runtime; overwritten on hotplug |

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
./save-display-profile.sh home
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

**Waybar:** click the display icon next to network (shows **H** / **W** / **L**). Menu: auto-detect, home, work, laptop, restart hotplug listener. Turns amber when detected profile differs from active.

**Undock / black laptop panel:** **Alt+X → L**, Waybar display menu → **Laptop only**, or `./apply-display-profile.sh laptop`. Open the lid if it was closed at the dock.

**Dock before opening the laptop (or wrong rotations / laptop still on):** plug the dock, open the lid — the listener should re-apply **home** when the internal panel appears or layouts drift. If not: Waybar display icon → **Auto-detect** or **Home dock**.

**Unplug/replug dock:** wait ~5–15s for the listener to switch profiles. Undock now keys off **active** external monitors only (stale `monitors all` entries no longer block **laptop**). Manual: **Alt+X → L** or Waybar **Auto-detect**.

**Invisible windows / Alt+Return does nothing on one monitor:** usually a bad switch while the laptop panel was still active (e.g. home dock from the lock screen). Run `./recover-display-session.sh`, unlock if you were still locked, then try again. Corrupted tiles are floated automatically; re-tile with **Alt+Shift+Space** or move windows to another workspace and back.

If only 1–2 externals are connected (partial dock), auto mode does **nothing** (`skip`) until all home monitors appear or you apply manually.

## Office (later)

```bash
./discover-monitors.sh | tee ~/monitor-discovery-work.txt
# edit config.env WORK_DOCK_DESCRIPTIONS
./save-display-profile.sh work
```

Restore home from git if needed: `git checkout -- profiles/home.hypr` then `./apply-display-profile.sh home` at the home dock.

## Files

| Script | Role |
|--------|------|
| `save-display-profile.sh` | capture live layout → profiles/ + apply |
| `apply-display-profile.sh` | detect + apply |
| `hypr-display-listener.sh` | hotplug → auto |
| `migrate-session.sh` | move windows before undock |
| `capture-layout.sh` | save live layout |
| `restart-display-listener.sh` | safe listener restart |
| `recover-display-session.sh` | fix broken tiles after a bad dock switch |
