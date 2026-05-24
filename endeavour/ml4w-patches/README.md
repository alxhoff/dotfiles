# ML4W config overrides

Copied into `~/.mydotfiles/com.ml4w.hyprlandstarter/.config/` (and some paths under `~/.config/`) by `apply-ml4w-patches.sh`.

Re-run after every `git pull` that touches this tree:

```bash
./endeavour/apply-ml4w-patches.sh
```

Agent overview: [../../AGENTS.md](../../AGENTS.md).

## Hypr (`hypr/conf/`)

| File | Purpose |
|------|---------|
| `layouts.conf` | Remove `pseudotile` (Hyprland 0.55) |
| `gestures.conf` | Replace deprecated `workspace_swipe` |
| `autostart.conf` | waybar-launch, hyprpaper, waypaper, cliphist, hypridle, display listener |
| `binds-dotfiles.conf` | i3-style **Alt** binds, passthrough, Steam Link, display menu |
| `windowrules-dotfiles.conf` | Cursor tiled; other app tweaks |
| `general-dotfiles.conf` | Gap tuning (`gaps_in` / `gaps_out` / `float_gaps`) |
| `monitor.conf` | ML4W monitor defaults |
| `hyprlock.conf`, `hypridle.conf` | Lock / idle |

Paths in templates use `@DOTFILES@`; substituted at apply time.

## Waybar

| File | Purpose |
|------|---------|
| `config-primary.jsonc` | Full bar on primary monitor |
| `config-secondary.jsonc` | Minimal bar on portrait/secondary outputs |
| `waybar-launch.sh` | Per-output launcher (reads `WAYBAR_PRIMARY_PATTERN` from displays `config.env`) |
| `style.css.font-family`, `style-overrides.css` | Fira Sans text; Font Awesome on icon modules only |
| `hyprland-workspaces.jsonc` | Workspaces 1–4 (`persistent-only`) |
| Module snippets | `idle-inhibitor`, `custom/passthrough`, `mpris`, stats, etc. |

`modules.json` is patched in Python inside the apply script.

## ML4W scripts (`ml4w/scripts/`)

Notable: `waybar-launch.sh`, `passthrough-waybar.sh`, `steamlink.sh` (`--windowed`), `steamlink-game-mode.sh`, `steamlink-ungrab.sh`, `wallpaper-random.sh`, `keybinds-cheatsheet.sh`.

## Other

| Path | Purpose |
|------|---------|
| `waypaper/config.ini` | Wallpaper tool config |
| `applications/com.valvesoftware.SteamLink.desktop` | Custom launcher → `steamlink.sh` |
| `KEYBINDS.md` | Human-readable bind list |
