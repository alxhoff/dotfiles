#!/usr/bin/env bash
# Remove dotfiles Sway trial session links (keeps pacman packages and Hyprland).
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

remove_link() {
    local dest=$1
    if [[ -L "$dest" ]]; then
        local target
        target=$(readlink -f "$dest")
        if [[ "$target" == "$DOTFILES_DIR"* ]]; then
            rm -f "$dest"
            echo "removed link: $dest"
        else
            echo "skip (not dotfiles): $dest"
        fi
    fi
}

remove_link "$HOME/.config/sway"
remove_link "$HOME/.local/bin/dotfiles-start-sway"
rm -f "$HOME/.local/share/wayland-sessions/sway-dotfiles.desktop"

echo ""
echo "Sway trial session removed. Hyprland untouched."
echo "Optional: sudo pacman -Rns sway swaylock swayidle xdg-desktop-portal-wlr"
