#!/usr/bin/env bash
# Run on the CURRENT system before DD / reinstall — sanity checks only.
set -euo pipefail

HOME_DIR=${HOME:-/home/alxhoff}
echo "Pre-migration checklist for: $HOME_DIR"
echo ""

check() {
    local path=$1
    local label=${2:-$path}
    if [[ -e "$HOME_DIR/$path" ]]; then
        printf "  OK  %-36s %s\n" "$label" "$(du -sh "$HOME_DIR/$path" 2>/dev/null | cut -f1)"
    else
        printf "  --  %-36s (missing)\n" "$label"
    fi
}

echo "Critical paths:"
check git "git/ (projects)"
check .ssh "SSH keys"
check .gnupg "GPG"
check .config/Cursor "Cursor"
check .cursor "Cursor agent transcripts"
check .mozilla/firefox "Firefox"
check windows "Windows VM storage"
check window_data "Windows VM /data"
check compose.yaml "docker compose (~/compose.yaml)"

echo ""
echo "Dotfiles repo:"
DOTFILES=${DOTFILES:-$HOME_DIR/git/Github/dotfiles}
if [[ -d "$DOTFILES" ]]; then
    echo "  $DOTFILES"
    git -C "$DOTFILES" status -sb 2>/dev/null || true
else
    echo "  WARNING: dotfiles not found at $DOTFILES"
fi

echo ""
echo "Docker:"
docker ps -a --format '  {{.Names}}' 2>/dev/null | head -15 || echo "  (docker not running)"

echo ""
echo "Suggested before power-off:"
echo "  1. git -C ~/git/Github/dotfiles push"
echo "  2. Commit any local changes in ~/git repos you care about"
echo "  3. Note SOURCE_DEV from: lsblk"
echo "  4. Boot live USB → migrate/dd-backup.sh"
