#!/usr/bin/env bash
# Install a reversible Sway trial alongside Hyprland/ML4W.
# Does NOT modify ~/.config/hypr or ML4W patches.
#
# Usage: ./endeavour/sway/install-sway-trial.sh [--dry-run]
#
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DRY_RUN=0
[[ "${1:-}" == --dry-run ]] && DRY_RUN=1

log() { echo "==> $*"; }

run() {
    if [[ "$DRY_RUN" == 1 ]]; then
        echo "  would run: $*"
    else
        "$@"
    fi
}

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

log "Dotfiles Sway trial installer"
log "Hyprland is left unchanged (~/.config/hypr → ML4W)."

PKGS=(sway swaylock swayidle swaybg xdg-desktop-portal-wlr brightnessctl grim slurp wl-clipboard)
if command -v pacman >/dev/null; then
    if [[ "$DRY_RUN" == 1 ]]; then
        echo "  would install: ${PKGS[*]}"
    else
        missing=()
        for p in "${PKGS[@]}"; do
            pacman -Q "$p" &>/dev/null || missing+=("$p")
        done
        if ((${#missing[@]})); then
            log "Installing: ${missing[*]}"
            sudo pacman -S --needed --noconfirm "${missing[@]}"
        else
            log "Packages already installed"
        fi
    fi
else
    log "pacman not found — install manually: ${PKGS[*]}"
fi

link_path "$DOTFILES_DIR/sway" "$HOME/.config/sway"

for s in "$DOTFILES_DIR/sway/scripts/"*.sh; do
    [[ -f "$s" ]] || continue
    if [[ "$DRY_RUN" != 1 ]]; then
        chmod +x "$s"
    fi
done

# ML4W scripts (terminal-launch, dropdowns, etc.)
mkdir -p "$HOME/.config/ml4w/scripts"
for s in "$DOTFILES_DIR/endeavour/ml4w-patches/ml4w/scripts/"*.sh; do
    [[ -f "$s" ]] || continue
    if [[ "$DRY_RUN" != 1 ]]; then
        chmod +x "$s"
    fi
    link_path "$s" "$HOME/.config/ml4w/scripts/$(basename "$s")"
done

link_path "$DOTFILES_DIR/sway/scripts/start-sway.sh" "$HOME/.local/bin/dotfiles-start-sway"

DESKTOP_DIR="$HOME/.local/share/wayland-sessions"
DESKTOP_FILE="$DESKTOP_DIR/sway-dotfiles.desktop"
if [[ "$DRY_RUN" == 1 ]]; then
    echo "  would write: $DESKTOP_FILE"
else
    mkdir -p "$DESKTOP_DIR" "$HOME/.local/bin" "$HOME/Pictures"
    cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Sway (dotfiles trial)
Comment=i3-compatible Wayland compositor — dotfiles trial session
Exec=$HOME/.local/bin/dotfiles-start-sway
TryExec=$HOME/.local/bin/dotfiles-start-sway
Type=Application
DesktopNames=Sway
Keywords=tiling;wayland;i3;sway;
EOF
    log "wrote $DESKTOP_FILE"
fi

echo ""
log "Done."
cat <<EOF

Try Sway:
  1. Log out
  2. plasmalogin → session "Sway (dotfiles trial)"
  3. Alt+W / Alt+S for native tabbed/stacked layouts

Back to Hyprland:
  Log out → pick "Hyprland" (unchanged)

Remove trial only:
  ./endeavour/sway/remove-sway-trial.sh

Docs: docs/SWAY-TRIAL.md
EOF
