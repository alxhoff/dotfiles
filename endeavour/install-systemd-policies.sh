#!/usr/bin/env bash
# Install system-wide policies owned by dotfiles (requires sudo).
#
# Usage:
#   ./endeavour/install-systemd-policies.sh
#   DRY_RUN=1 ./endeavour/install-systemd-policies.sh
#
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SRC="$DOTFILES_DIR/endeavour/systemd/logind/99-dotfiles-lid.conf"
DEST_DIR=/etc/systemd/logind.conf.d
DEST="$DEST_DIR/99-dotfiles-lid.conf"
DRY_RUN=${DRY_RUN:-0}

log() { echo "==> $*"; }

[[ -f "$SRC" ]] || {
    echo "missing: $SRC" >&2
    exit 1
}

active_user_sessions() {
    loginctl list-sessions --no-legend 2>/dev/null | awk '$3 != "greeter" && $4 == "active" { count++ } END { print count + 0 }'
}

install_dropin() {
    if [[ "$DRY_RUN" == 1 ]]; then
        log "would install $DEST"
        return 0
    fi

    sudo install -d -m755 "$DEST_DIR"
    sudo install -m644 "$SRC" "$DEST"
    log "installed $DEST"
}

reload_logind() {
    local active
    active=$(active_user_sessions)

    if [[ "$DRY_RUN" == 1 ]]; then
        log "would reload systemd-logind (active user sessions: $active)"
        return 0
    fi

    if [[ "$active" -gt 0 ]]; then
        log "active graphical session detected — skipping logind restart"
        log "policy file updated; reboot or log out/in to apply if settings do not take effect"
        return 0
    fi

    sudo systemctl restart systemd-logind.service
    log "restarted systemd-logind"
}

install_dropin
reload_logind

if [[ "$DRY_RUN" != 1 ]]; then
    busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager HandleLidSwitchExternalPower 2>/dev/null \
        || true
fi

log "Done."
