#!/usr/bin/env bash
# Waybar: install icon fonts + trim workspace bar (ML4W defaults show ws 5–20).
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MODULES="${HOME}/.mydotfiles/com.ml4w.hyprlandstarter/.config/waybar/modules.json"
STYLE="${HOME}/.mydotfiles/com.ml4w.hyprlandstarter/.config/waybar/style.css"

log() { echo "==> $*"; }

install_fonts() {
    local pkgs=()
    for p in otf-font-awesome ttf-fira-sans; do
        pacman -Qi "$p" &>/dev/null || pkgs+=("$p")
    done
    if ((${#pkgs[@]} > 0)); then
        log "Installing ${pkgs[*]} (needs sudo)"
        sudo pacman -S --needed --noconfirm "${pkgs[@]}"
    else
        log "Icon fonts already installed"
    fi
    fc-cache -fv 2>/dev/null | tail -3 || true
}

install_fonts
"$DOTFILES_DIR/endeavour/apply-ml4w-patches.sh"

log "Reload waybar when in Hyprland: killall waybar; waybar &"
log "Or log out/in. Stale workspaces 5+ clear on Hyprland restart."
