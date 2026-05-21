#!/usr/bin/env bash
# Restore home-directory data from a DD'd root filesystem on an external disk.
#
# Typical workflow on the NEW machine (after EndeavourOS install):
#   sudo mount /dev/sda1 /mnt/oldroot    # partition containing old /
#   cd ~/git/Github/dotfiles
#   OLD_ROOT=/mnt/oldroot OLD_USER=alxhoff ./migrate/restore-from-backup.sh
#
# Options:
#   DRY_RUN=1          — show what would be copied
#   MIGRATE_YES=1      — skip confirmation prompts
#   SKIP_GIT=1         — skip ~/git (if you will copy it separately)
#   ONLY=git,ssh       — comma-separated subset of manifest paths
#   MANIFEST=path      — alternate manifest file
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=migrate/lib.sh
source "$SCRIPT_DIR/lib.sh"

DRY_RUN=${DRY_RUN:-0}
MANIFEST=${MANIFEST:-$SCRIPT_DIR/manifest.conf}
OLD_USER=${OLD_USER:-alxhoff}
NEW_HOME=$(migrate_new_home)

if ! OLD_ROOT=$(migrate_resolve_old_root); then
    migrate_die "Could not find old root. Mount the DD backup and set OLD_ROOT=/mnt/oldroot"
fi

if ! OLD_HOME=$(migrate_old_home "$OLD_ROOT"); then
    migrate_die "Could not find home for OLD_USER=$OLD_USER under $OLD_ROOT/home/"
fi

migrate_log "Old root:  $OLD_ROOT"
migrate_log "Old home:  $OLD_HOME"
migrate_log "New home:  $NEW_HOME"
migrate_log "Manifest:  $MANIFEST"

if [[ "$DRY_RUN" == 1 ]]; then
    migrate_log "DRY RUN — no changes will be made"
fi

# --- Estimate ---
echo ""
echo "Estimated sizes from backup:"
total_hint=0
while IFS= read -r relpath || [[ -n "$relpath" ]]; do
    [[ -z "$relpath" || "$relpath" =~ ^# ]] && continue
    [[ "${SKIP_GIT:-}" == 1 && "$relpath" == "git" ]] && continue
    if [[ -n "${ONLY:-}" ]]; then
        echo "$ONLY" | tr ',' '\n' | grep -qxF "$relpath" || continue
    fi
    printf "  %-30s %s\n" "$relpath" "$(migrate_estimate_path "$OLD_HOME/$relpath")"
done < "$MANIFEST"
echo ""

if ! migrate_confirm "Proceed with restore to $NEW_HOME?"; then
    echo "Aborted."
    exit 0
fi

# --- Restore manifest paths ---
while IFS= read -r relpath || [[ -n "$relpath" ]]; do
    [[ -z "$relpath" || "$relpath" =~ ^# ]] && continue
    [[ "${SKIP_GIT:-}" == 1 && "$relpath" == "git" ]] && continue
    if [[ -n "${ONLY:-}" ]]; then
        echo "$ONLY" | tr ',' '\n' | grep -qxF "$relpath" || continue
    fi

    src="$OLD_HOME/$relpath"
    dst="$NEW_HOME/$relpath"

    if [[ -f "$src" ]]; then
        migrate_rsync_file "$src" "$dst" "$DRY_RUN"
    elif [[ -d "$src" ]]; then
        migrate_rsync_dir "$src" "$dst" "$DRY_RUN"
    else
        migrate_log "skip (not found): $src"
    fi
done < "$MANIFEST"

# --- System-level: spotify-adblock library ---
adb_src="$OLD_ROOT/usr/local/lib/spotify-adblock.so"
if [[ -f "$adb_src" && "$DRY_RUN" != 1 ]]; then
    if migrate_confirm "Install spotify-adblock.so to /usr/local/lib/ (requires sudo)?"; then
        sudo install -Dm644 "$adb_src" /usr/local/lib/spotify-adblock.so
    fi
elif [[ -f "$adb_src" ]]; then
    migrate_log "would install: $adb_src -> /usr/local/lib/spotify-adblock.so"
fi

# --- Fix ownership (DD copies often preserve root-owned files e.g. ~/windows) ---
if [[ "$DRY_RUN" != 1 ]]; then
    migrate_log "If anything fails with permission errors, run:"
    echo "  sudo chown -R \$USER:\$USER $NEW_HOME/git $NEW_HOME/windows $NEW_HOME/window_data"
fi

migrate_log "Restore pass finished."
migrate_log "Next: ./install.sh && git submodule update --init vim"
