# Hyprland keybinds (Alt = main modifier)

- `Alt+Return` — Terminal (kitty)
- `Alt+Shift+Return` — Terminal with fish `ub`
- `Alt+F12` — Dropdown terminal (Guake-style; press again to hide)
- `Alt+F11` — Dropdown Spotify (toggle; splits 50/50 with Discord when it is running)
- `Alt+Shift+Q` — Close window
- `Alt+D` — App launcher (rofi)
- `Alt+O` — File finder (rofi filebrowser)
- `Alt+C` — Browser
- `Alt+Ctrl+V` — Clipboard history (not in i3; moved off Alt+V)
- `Alt+/` — Keybind cheat sheet
- `Alt+P` — Lock screen (hyprlock; idle lock uses the same path)
- `Alt+Shift+P` — Power menu (l/s/e/h/r/Shift+s)
- `Alt+R` — Resize mode
- `Alt+Shift+C` — Reload Hyprland config
- `Alt+Shift+R` — Reload config + waybar
- `Alt+Shift+E` — File manager (nemo)
- `Alt+M` — Toggle waybar
- `Alt+B` — Last workspace
- `Alt+Tab` — (use `Alt+B` / workspace previous)
- `Alt+1…0` — Workspaces (press again on the same number to jump back — i3-style)
- `Alt+Ctrl+1…0` — Move window, stay on workspace
- `Alt+Shift+1…0` — Move window and follow
- `Alt+J/K/L/;` or arrows — Focus in direction; cycles tabs inside a group, then other windows/monitors
- `Alt+Shift+J/K/L/;` or arrows — Move window within the workspace first (swap/re-nest splits); crosses to the next monitor only at the screen edge
- `Alt+W` — Tabbed layout on **active monitor** (all tiled windows there)
- `Alt+S` — Stacked layout on **active monitor** (tab bar with titles)
- `Alt+E` — Ungroup / exit stack on active monitor; if not grouped, toggle split (i3 `layout toggle split`)
- `Alt+Q` — Toggle split orientation
- `Alt+H` — Next window tiles side-by-side (does not move existing windows)
- `Alt+V` — Next window tiles top/bottom (does not move existing windows)
- Portrait/rotated monitors auto-use vertical stack for new windows (`dwindle-auto-split.sh`)
- New tiled windows auto-equalize their row/column after open (~0.4s; `dwindle-auto-split.sh`)
- **Alt+Ctrl+E** — Equalize widths/heights in the current row/column (manual; always runs)
- `Alt+F` — Fullscreen
- `Alt+Ctrl+W` — Wallpaper picker (waypaper)
- `Alt+Shift+W` — Random wallpaper
- `Alt+Esc` — Game passthrough toggle (releases Alt+mouse window drag/resize and scroll workspace)
- `Alt+Ctrl+G` — Steam Link game mode (focus + passthrough)
- `Alt+Shift+Space` — Floating toggle
- `Alt+Space` — Focus floating/tiled
- `Alt+U` / `Alt+Y` / `Alt+N` — Border off / 1px / normal
- `Alt+X` — Display profiles (W/H/L)
- **Waybar** — click display icon (H/W/L) next to network for profile menu + auto-detect
- `Alt+Ctrl+M` — Pavucontrol
- `Print` — Screenshot (full screen)

Power menu (`Alt+Shift+P`): **l** lock · **s** suspend · **e** logout · **h** hibernate (battery only) · **r** reboot · **Shift+s** shutdown. Waybar power icon (wlogout): **u** suspend. Auto-suspend after 30 min idle skips when on external power.

Display menu (`Alt+X`): **w** work · **h** home · **l** laptop
