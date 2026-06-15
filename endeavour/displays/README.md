# Display profiles

One path for dock hotplug: **profiles in git** → **detect** → **apply** → **listener**.

| Piece | Role |
|-------|------|
| `profiles/*.hypr` | Source of truth (home / work / laptop) |
| `config.env` | Dock description strings, retry timing |
| `apply-display-profile.sh` | Detect, apply, recover |
| `hypr-display-listener.sh` | Hotplug + startup (debounced) |
| `validate-monitors-conf.sh` | Pre-login safety (via session preflight) |
| `migrate-session.sh` | Move windows before disabling laptop panel |

`nwg-displays` only writes `~/.config/hypr/monitors.conf`. After arranging, run `./save-display-profile.sh home`.

## Setup (once per dock)

```bash
cd ~/git/Github/dotfiles/endeavour/displays
./discover-monitors.sh | tee ~/monitor-discovery-home.txt
# edit config.env HOME_DOCK_DESCRIPTIONS
./save-display-profile.sh home
```

## Daily use

Listener starts from Hyprland autostart (`restart-display-listener.sh`). On plug/unplug it waits **5s** (0s if already laptop-only), then auto-applies with up to **6 retries**.

```bash
./apply-display-profile.sh auto    # manual detect + apply
./apply-display-profile.sh home
./apply-display-profile.sh laptop
./recover-display-session.sh       # broken tiles / invisible windows
./restart-display-listener.sh
```

**Alt+X** → H / L / W — home / laptop / work  
**Waybar** display icon — same + restart listener

**Undock / black panel:** Alt+X → L, Waybar → Laptop, or `./apply-display-profile.sh laptop`

**Partial dock** (1–2 of 3 home monitors): auto does nothing until all appear, or apply manually.

## Boot safety

`install-hypr-session.sh` installs a preflight that resets `monitors.conf` to laptop when the saved layout would leave zero active outputs (undocked boot).
