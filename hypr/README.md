# Hyprland (vanilla dotfiles)

Optional **minimal** config when ML4W is too heavy or you want i3-style Alt binds only.

**Preferred starting point:** ML4W starter (`./endeavour/switch-ml4w-hypr.sh` + `./endeavour/setup-hyprland-default.sh --ml4w`).

## Switch from ML4W

```bash
cd ~/git/Github/dotfiles
./install.sh --only hypr
```

This replaces `~/.config/hypr` (symlink to ML4W) with a symlink to `dotfiles/hypr/`.

To go back to ML4W later:

```bash
ln -sfn ~/.mydotfiles/com.ml4w.hyprlandstarter/.config/hypr ~/.config/hypr
```

## Default keybinds (from i3)

| Key | Action |
|-----|--------|
| **Alt+Return** | `konsole` with fish |
| **Alt+C** | Firefox |
| **Alt+D** | `wofi` app launcher |
| Alt+Q | close window |
| Alt+Shift+Q | exit Hyprland |
| Alt+1..0 | workspaces |

i3 used `Mod1` (Alt), not Super.

## Add binds incrementally

Edit `binds.conf` or create `extra.conf` and add to the bottom of `hyprland.conf`:

```
source = ~/.config/hypr/extra.conf
```

Reload: `hyprctl reload`

## Error logs

If the red error overlay disappears too fast:

```bash
# After a Hyprland session:
cat ~/.cache/hyprland/hyprland.log

# From current boot (if logged in elsewhere):
journalctl --user -b | grep -iE 'hypr|config error'

# Last on-screen nag (often error text):
cat ~/.local/share/hyprland/lastNag
```

Validate config:

```bash
hyprctl reload   # in Hyprland
hyprland -c ~/.config/hypr/hyprland.conf   # test parse (may need no display)
```

## Next steps (when ready)

- `endeavour/hypr-autostart.snippet.conf` — nm-applet, blueman, kanshi
- `endeavour/displays/` — home/work monitor profiles
- `pacman -S kitty` or `foot` if you prefer a lighter terminal than konsole
