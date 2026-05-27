#!/usr/bin/env bash
# Symlink dotfiles-owned configs into ~/.config and the ML4W tree.
# Safe to re-run after git pull or on a fresh machine (after install-ml4w-starter.sh).
#
# Usage: ./endeavour/link-configs.sh [--dry-run]
#
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PATCHES="$DOTFILES_DIR/endeavour/ml4w-patches"
DISPLAYS="$DOTFILES_DIR/endeavour/displays"
ML4W_CFG="${HOME}/.mydotfiles/com.ml4w.hyprlandstarter/.config"
DRY_RUN=0
[[ "${1:-}" == --dry-run ]] && DRY_RUN=1

log() { echo "==> $*"; }

link_path() {
    local src=$1 dest=$2

    [[ -e "$src" ]] || { log "skip missing: $src"; return 0; }

    if [[ "$DRY_RUN" == 1 ]]; then
        echo "  would link: $dest -> $src"
        return 0
    fi

    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        log "ok (already linked): $dest"
        return 0
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        local backup="${dest}.dotfiles-backup.$(date +%Y%m%d%H%M%S)"
        mv "$dest" "$backup"
        log "backed up: $dest -> $backup"
    fi

    ln -sfn "$(readlink -f "$src")" "$dest"
    log "linked: $dest"
}

install_example_if_missing() {
    local example=$1 dest=$2
    [[ -f "$example" ]] || return 0
    if [[ -e "$dest" ]]; then
        log "ok (exists): $dest"
        return 0
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
        echo "  would install example: $dest <- $example"
        return 0
    fi
    install -m600 "$example" "$dest"
    log "installed example: $dest (edit locally; not in git)"
}

require_ml4w() {
    [[ -d "$ML4W_CFG/hypr" ]] || {
        echo "ML4W not installed. Run: $DOTFILES_DIR/endeavour/install-ml4w-starter.sh" >&2
        exit 1
    }
}

require_ml4w

mkdir -p "${HOME}/.config"
if [[ "$DRY_RUN" != 1 ]]; then
    printf '%s\n' "$DOTFILES_DIR" >"${HOME}/.config/dotfiles-path"
fi
log "dotfiles-path -> $DOTFILES_DIR"

# Stable pointer used in Hyprland / scripts (~/.config/dotfiles -> repo)
link_path "$DOTFILES_DIR" "${HOME}/.config/dotfiles"

# --- Display profiles (git is source of truth) ---
# shellcheck source=endeavour/displays/lib.sh
source "$DISPLAYS/lib.sh"
if dest=$(link_display_profiles "$DOTFILES_DIR" 2>/dev/null); then
    log "display-profiles -> $dest"
fi

mkdir -p "${HOME}/.config/kanshi"
link_path "$DISPLAYS/kanshi.config" "${HOME}/.config/kanshi/config"

mkdir -p "$ML4W_CFG/hypr/scripts"
link_path "$DISPLAYS/dotfiles-display-hook.sh" "$ML4W_CFG/hypr/scripts/dotfiles-display-hook.sh"

for s in "$DISPLAYS"/*.sh; do
    [[ -f "$s" ]] || continue
    [[ "$DRY_RUN" == 1 ]] || chmod +x "$s"
done

# --- Hyprland patches (into ML4W tree; ~/.config/hypr symlinks here) ---
for f in layouts.conf gestures.conf autostart.conf monitor.conf binds.conf \
    binds-dotfiles.conf windowrules-dotfiles.conf general-dotfiles.conf group-dotfiles.conf; do
    [[ -f "$PATCHES/hypr/conf/$f" ]] || continue
    link_path "$PATCHES/hypr/conf/$f" "$ML4W_CFG/hypr/conf/$f"
done

for f in hyprlock.conf hypridle.conf; do
    [[ -f "$PATCHES/hypr/conf/$f" ]] || continue
    link_path "$PATCHES/hypr/conf/$f" "$ML4W_CFG/hypr/$f"
done

[[ -f "$PATCHES/hypr/hyprpaper.conf" ]] && \
    link_path "$PATCHES/hypr/hyprpaper.conf" "$ML4W_CFG/hypr/hyprpaper.conf"

# --- Waypaper ---
mkdir -p "${HOME}/.config/waypaper"
link_path "$PATCHES/waypaper/config.ini" "${HOME}/.config/waypaper/config.ini"

# --- ML4W scripts & settings ---
mkdir -p "$ML4W_CFG/ml4w/scripts" "$ML4W_CFG/ml4w/settings"
for s in "$PATCHES/ml4w/scripts/"*.sh; do
    [[ -f "$s" ]] || continue
    [[ "$DRY_RUN" == 1 ]] || chmod +x "$s"
    link_path "$s" "$ML4W_CFG/ml4w/scripts/$(basename "$s")"
done
for s in "$PATCHES/ml4w/settings/"*.sh; do
    [[ -f "$s" ]] || continue
    [[ "$DRY_RUN" == 1 ]] || chmod +x "$s"
    link_path "$s" "$ML4W_CFG/ml4w/settings/$(basename "$s")"
done

install_example_if_missing \
    "$PATCHES/ml4w/settings/wow-classic.env.example" \
    "${HOME}/.config/ml4w/wow-classic.env"
install_example_if_missing \
    "$PATCHES/ml4w/settings/dropdown-terminal.env.example" \
    "${HOME}/.config/ml4w/dropdown-terminal.env"
install_example_if_missing \
    "$PATCHES/ml4w/settings/dropdown-spotify.env.example" \
    "${HOME}/.config/ml4w/dropdown-spotify.env"

# --- Waybar (static files symlinked; modules.json/style.css patched by apply-ml4w-patches.sh) ---
mkdir -p "$ML4W_CFG/waybar"
for f in config-primary.jsonc config-secondary.jsonc network_menu.xml; do
    [[ -f "$PATCHES/waybar/$f" ]] || continue
    link_path "$PATCHES/waybar/$f" "$ML4W_CFG/waybar/$f"
done
link_path "$PATCHES/waybar/config-primary.jsonc" "$ML4W_CFG/waybar/config"

mkdir -p "$ML4W_CFG/kitty"
link_path "$PATCHES/kitty/kitty.conf" "$ML4W_CFG/kitty/kitty.conf"

log "Done. Re-run ./endeavour/apply-ml4w-patches.sh for waybar modules/style overlays."
