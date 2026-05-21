#!/usr/bin/env bash
# Export installed packages from this machine into packages/inventory/
#
# Usage: ./packages/export-inventory.sh
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
INV="$SCRIPT_DIR/inventory"
mkdir -p "$INV"

log() { echo "==> $*"; }

log "pacman (official repo, explicitly installed)"
pacman -Qen 2>/dev/null | awk '{print $1}' | sort -u >"$INV/pacman.txt"

log "AUR / foreign (pacman -Qem)"
pacman -Qem 2>/dev/null | awk '{print $1}' | sort -u >"$INV/aur.txt"

log "flatpak applications"
if command -v flatpak >/dev/null; then
    flatpak list --app --columns=application 2>/dev/null | sort -u >"$INV/flatpak-apps.txt"
    flatpak list --runtime --columns=application 2>/dev/null | sort -u >"$INV/flatpak-runtimes.txt"
else
    : >"$INV/flatpak-apps.txt"
    : >"$INV/flatpak-runtimes.txt"
fi

log "pip (user)"
if command -v pip >/dev/null; then
    pip list --user --format=freeze 2>/dev/null | cut -d= -f1 | sort -u >"$INV/pip-user.txt" || : >"$INV/pip-user.txt"
else
    : >"$INV/pip-user.txt"
fi

log "npm (global)"
if command -v npm >/dev/null; then
    npm list -g --depth=0 --parseable 2>/dev/null | xargs -I{} basename {} 2>/dev/null | grep -v '^npm$' | sort -u >"$INV/npm-global.txt" || : >"$INV/npm-global.txt"
else
    : >"$INV/npm-global.txt"
fi

log "snap"
if command -v snap >/dev/null; then
    snap list 2>/dev/null | awk 'NR>1 {print $1}' | sort -u >"$INV/snap.txt"
else
    : >"$INV/snap.txt"
fi

# Metadata for the selection UI
{
    echo "hostname=$(hostname)"
    echo "date=$(date -Iseconds)"
    echo "pacman_count=$(wc -l <"$INV/pacman.txt")"
    echo "aur_count=$(wc -l <"$INV/aur.txt")"
    echo "flatpak_app_count=$(wc -l <"$INV/flatpak-apps.txt")"
} >"$INV/meta.env"

log "Wrote inventory to $INV/"
wc -l "$INV"/*.txt | sed 's/^/  /'
