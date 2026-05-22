#!/usr/bin/env bash
# Point ~/.config/hypr at dotfiles vanilla config (not ML4W).
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ -L "$HOME/.config/hypr" ]]; then
    echo "Current hypr link: $(readlink -f "$HOME/.config/hypr")"
fi

"$DOTFILES_DIR/install.sh" --only hypr

echo ""
echo "Log out and log into Hyprland again."
echo "Errors: cat ~/.cache/hyprland/hyprland.log"
echo "Keybinds: Alt+Return (terminal), Alt+C (firefox), Alt+D (launcher)"
