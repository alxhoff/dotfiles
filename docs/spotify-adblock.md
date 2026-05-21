# Spotify adblock

## Files

| File | Role |
|------|------|
| `bin/spotify-adblock` | Wrapper (`LD_PRELOAD`) — installed to `~/.local/bin/` by `install.sh` |
| `/usr/local/lib/spotify-adblock.so` | Built library (system path) |

Source repo on this machine: `~/git/Github/spotify-adblock`

## Install on new system

```bash
sudo pacman -S spotify base-devel git
git clone git@github.com:alxhoff/spotify-adblock.git ~/git/Github/spotify-adblock   # or restore via migrate
cd ~/git/Github/spotify-adblock
# follow upstream build instructions, then:
sudo install -Dm644 spotify-adblock.so /usr/local/lib/spotify-adblock.so
```

Or copy `.so` from DD backup when `migrate/restore-from-backup.sh` offers to install it.

Login state: restore `~/.config/spotify/` via migrate (do not commit `prefs` to git).

Launch: `spotify-adblock` or bind to your launcher.
