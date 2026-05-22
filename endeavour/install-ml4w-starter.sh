#!/usr/bin/env bash
# Clone ML4W Hyprland Starter and symlink ~/.config/* into it.
#
# Usage: ./endeavour/install-ml4w-starter.sh
#   ML4W_TAG=v1.0.0 ./endeavour/install-ml4w-starter.sh   # optional pin
#   DRY_RUN=1 ./endeavour/install-ml4w-starter.sh
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ML4W_DIR="${HOME}/.mydotfiles/com.ml4w.hyprlandstarter"
ML4W_REPO="${ML4W_REPO:-https://github.com/mylinuxforwork/hyprland-starter.git}"
ML4W_TAG="${ML4W_TAG:-}"
DRY_RUN=${DRY_RUN:-0}

log() { echo "==> $*"; }

link_config() {
    local name=$1
    local src="$ML4W_DIR/.config/$name"
    local dest="${HOME}/.config/$name"

    [[ -e "$src" ]] || { log "skip (missing in starter): $name"; return 0; }

    if [[ "$name" == rofi && ( -L "$dest" || -e "$dest" ) ]]; then
        local target
        target=$(readlink -f "$dest" 2>/dev/null || true)
        if [[ "$target" == *dotfiles* ]] || [[ "$target" == *Github/dotfiles* ]]; then
            log "keep dotfiles rofi: $dest"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" == 1 ]]; then
        echo "  [dry-run] ln -sfn $src -> $dest"
        return 0
    fi

    mkdir -p "${HOME}/.config"
    if [[ -e "$dest" || -L "$dest" ]] && [[ "$(readlink -f "$dest" 2>/dev/null)" != "$(readlink -f "$src")" ]]; then
        mv "$dest" "${dest}.dotfiles-backup.$(date +%Y%m%d%H%M%S)"
        log "backed up existing $dest"
    fi
    ln -sfn "$src" "$dest"
    log "linked $dest"
}

if [[ ! -d "$ML4W_DIR/.git" ]]; then
    log "Cloning ML4W Hyprland Starter"
    if [[ "$DRY_RUN" == 1 ]]; then
        echo "  [dry-run] git clone $ML4W_REPO $ML4W_DIR"
    else
        mkdir -p "$(dirname "$ML4W_DIR")"
        git clone "$ML4W_REPO" "$ML4W_DIR"
        if [[ -n "$ML4W_TAG" ]]; then
            git -C "$ML4W_DIR" checkout "$ML4W_TAG"
        fi
    fi
else
    log "ML4W starter already at $ML4W_DIR"
    if [[ "$DRY_RUN" != 1 && -n "$ML4W_TAG" ]]; then
        git -C "$ML4W_DIR" fetch --tags
        git -C "$ML4W_DIR" checkout "$ML4W_TAG"
    fi
fi

for cfg in hypr waybar ml4w kitty dunst wlogout alacritty rofi; do
    link_config "$cfg"
done

if [[ "$DRY_RUN" != 1 ]]; then
    "$DOTFILES_DIR/endeavour/apply-ml4w-patches.sh"
fi

log "Next: ./endeavour/setup-hyprland-default.sh --ml4w  (packages)"
