#!/usr/bin/env bash
# Show Hyprland keybind cheat sheet in rofi
set -euo pipefail
DOTFILES=${DOTFILES:-$HOME/git/Github/dotfiles}
sheet="$DOTFILES/endeavour/ml4w-patches/KEYBINDS.md"
[[ -f "$sheet" ]] || { notify-send keybinds "Missing $sheet"; exit 1; }
grep -E '^- \`' "$sheet" | sed 's/^- `\(.*\)` — \(.*\)/\1\t\2/' | rofi -dmenu -i -p keybinds -lines 22 -width 72 -no-sort
