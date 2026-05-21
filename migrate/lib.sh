# shellcheck shell=bash
# Shared helpers for migration scripts. Source this file; do not execute directly.

migrate_die() {
    echo "migrate: $*" >&2
    exit 1
}

migrate_log() {
    echo "==> $*"
}

# Root of the old system (mounted DD backup), e.g. /mnt/oldroot
migrate_resolve_old_root() {
    if [[ -n "${OLD_ROOT:-}" && -d "$OLD_ROOT/etc" ]]; then
        echo "$OLD_ROOT"
        return 0
    fi

    local mnt candidate
    for mnt in /mnt/oldroot /mnt/backup /mnt/old /run/media/*/*; do
        [[ -d "$mnt/etc" ]] || continue
        candidate=$(readlink -f "$mnt" 2>/dev/null || echo "$mnt")
        echo "$candidate"
        return 0
    done

    return 1
}

migrate_old_home() {
    # Explicit path (e.g. btrfs @home mounted at /mnt/btrfs-backup → .../alxhoff)
    if [[ -n "${OLD_HOME:-}" && -d "$OLD_HOME" ]]; then
        echo "$OLD_HOME"
        return 0
    fi

    local old_root=$1
    local old_user=${OLD_USER:-alxhoff}
    local home="$old_root/home/$old_user"

    if [[ -d "$home" ]]; then
        echo "$home"
        return 0
    fi

    # Manjaro/Arch btrfs: @home subvolume mounted directly (no home/ prefix)
    if [[ -d "$old_root/$old_user" ]]; then
        echo "$old_root/$old_user"
        return 0
    fi

    # Fallback: first user home with a git/ directory (common after username change)
    local h
    for h in "$old_root"/home/* "$old_root"/*; do
        [[ -d "$h/git" ]] || continue
        echo "$h"
        return 0
    done

    return 1
}

migrate_new_home() {
    echo "${NEW_HOME:-$HOME}"
}

migrate_rsync_dir() {
    local src=$1
    local dst=$2
    local dry=${3:-0}

    [[ -d "$src" ]] || { migrate_log "skip (missing): $src"; return 0; }

    mkdir -p "$(dirname "$dst")"
    local -a rsync_opts=(-aHAX --info=progress2 --partial)

    if [[ "$dry" == 1 ]]; then
        rsync_opts+=(--dry-run)
    fi

    migrate_log "rsync $(du -sh "$src" 2>/dev/null | cut -f1) $src -> $dst"
    rsync "${rsync_opts[@]}" "$src/" "$dst/"
}

migrate_rsync_file() {
    local src=$1
    local dst=$2
    local dry=${3:-0}

    [[ -f "$src" ]] || { migrate_log "skip (missing): $src"; return 0; }

    mkdir -p "$(dirname "$dst")"
    local -a rsync_opts=(-aHAX)

    if [[ "$dry" == 1 ]]; then
        rsync_opts+=(--dry-run)
    fi

    migrate_log "rsync file $src -> $dst"
    rsync "${rsync_opts[@]}" "$src" "$dst"
}

migrate_estimate_path() {
    local path=$1
    if [[ -e "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1
    else
        echo "—"
    fi
}

migrate_confirm() {
    local prompt=$1
    if [[ "${MIGRATE_YES:-}" == 1 ]]; then
        return 0
    fi
    read -r -p "$prompt [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}
