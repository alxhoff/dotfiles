#!/usr/bin/env bash
# Install Hyprland session preflight so plasmalogin validates monitors before compositor start.
#
# Installs to /usr/local (overrides /usr/share/wayland-sessions/hyprland.desktop via XDG order).
#
# Usage:
#   ./endeavour/install-hypr-session.sh
#   DRY_RUN=1 ./endeavour/install-hypr-session.sh
#
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SESSION="$DOTFILES_DIR/endeavour/session"
PREFLIGHT_SRC="$SESSION/start-hyprland-preflight.sh"
DESKTOP_SRC="$SESSION/hyprland-system.desktop"
PREFLIGHT_DEST=/usr/local/lib/dotfiles/start-hyprland-preflight.sh
DESKTOP_DEST=/usr/local/share/wayland-sessions/hyprland.desktop
DRY_RUN=${DRY_RUN:-0}

log() { echo "==> $*"; }

[[ -f "$PREFLIGHT_SRC" && -f "$DESKTOP_SRC" ]] || {
    echo "missing session files under $SESSION" >&2
    exit 1
}

install_session() {
    if [[ "$DRY_RUN" == 1 ]]; then
        log "would install $PREFLIGHT_DEST"
        log "would install $DESKTOP_DEST"
        return 0
    fi

    sudo install -d -m755 /usr/local/lib/dotfiles /usr/local/share/wayland-sessions
    sudo install -m755 "$PREFLIGHT_SRC" "$PREFLIGHT_DEST"
    sudo install -m644 "$DESKTOP_SRC" "$DESKTOP_DEST"
    log "installed $PREFLIGHT_DEST"
    log "installed $DESKTOP_DEST (overrides package desktop via /usr/local/share)"
}

install_session
log "Done. Takes effect on next login (no reboot required)."
