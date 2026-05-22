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
    if [[ -n "${NEW_HOME:-}" ]]; then
        echo "$NEW_HOME"
        return 0
    fi

    local user home
    user=${SUDO_USER:-${LOGNAME:-$(id -un)}}
    home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6)
    [[ -n "$home" && "$home" != "/root" ]] || home=$HOME

    if [[ "$(id -u)" -eq 0 && "$home" == "/root" && "${ALLOW_ROOT_DEST:-}" != 1 ]]; then
        migrate_die "Restore destination would be /root. Run as your user, not sudo."
    fi
    echo "$home"
}

migrate_rsync_dir() {
    local src=$1
    local dst=$2
    local dry=${3:-0}

    [[ -d "$src" ]] || { migrate_log "skip (missing): $src"; return 0; }

    mkdir -p "$(dirname "$dst")"
    local -a rsync_opts=(-aHAX --numeric-ids --info=progress2 --partial)

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
    local -a rsync_opts=(-aHAX --numeric-ids)

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
    if [[ "${MIGRATE_YES:-}" == 1 || "${SKIP_CONFIRM:-}" == 1 ]]; then
        return 0
    fi
    read -r -p "$prompt [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

migrate_prompt_continue() {
    migrate_confirm "$1"
}

migrate_refuse_sudo_restore() {
    if [[ "$(id -u)" -eq 0 && -z "${SUDO_USER:-}" ]]; then
        migrate_die "Do not run restore scripts as root. Use: ./migrate/restore-from-backup.sh"
    fi
}

migrate_resolve_old_home() {
    if [[ -n "${OLD_HOME:-}" && -d "$OLD_HOME" ]]; then
        echo "$OLD_HOME"
        return 0
    fi

    local user=${OLD_USER:-alxhoff}
    if [[ -d "/mnt/btrfs-backup/$user/git" ]]; then
        echo "/mnt/btrfs-backup/$user"
        return 0
    fi

    local old_root
    if old_root=$(migrate_resolve_old_root 2>/dev/null); then
        migrate_old_home "$old_root"
        return $?
    fi
    return 1
}

migrate_ensure_backup_mounted() {
    local script_dir=$1
    if migrate_resolve_old_home >/dev/null 2>&1; then
        return 0
    fi
    if [[ "${SKIP_ENSURE_MOUNT:-}" == 1 ]]; then
        return 0
    fi
    migrate_log "Backup home not mounted — running mount-btrfs-backup.sh"
    sudo "$script_dir/mount-btrfs-backup.sh"
}

migrate_check_backup_home() {
    local old_home_hint=${1:-}
    local manifest=${2:-}
    local old_home

    if [[ -n "$old_home_hint" && -d "$old_home_hint" ]]; then
        old_home=$old_home_hint
    elif ! old_home=$(migrate_resolve_old_home); then
        migrate_die "Cannot find backup home (mount disk or set OLD_HOME)"
    fi

    migrate_log "Backup home: $old_home"
    [[ -d "$old_home/git" ]] || migrate_die "Expected $old_home/git on backup"
    [[ -d "$old_home/.config/Cursor" ]] || migrate_log "WARNING: no .config/Cursor on backup"

    local relpath
    while IFS= read -r relpath || [[ -n "$relpath" ]]; do
        [[ -z "$relpath" || "$relpath" =~ ^# ]] && continue
        if [[ -e "$old_home/$relpath" ]]; then
            printf "  OK  %-36s %s\n" "$relpath" "$(migrate_estimate_path "$old_home/$relpath")"
        else
            printf "  --  %-36s (missing on backup)\n" "$relpath"
        fi
    done < "$manifest"
}

migrate_cursor_running() {
    pgrep -x cursor >/dev/null 2>&1 || \
        pgrep -f '/usr/share/cursor/cursor' >/dev/null 2>&1 || \
        pgrep -f '/opt/Cursor/cursor' >/dev/null 2>&1
}

migrate_require_cursor_closed() {
    if [[ "${ALLOW_CURSOR_OPEN:-}" == 1 ]]; then
        migrate_log "WARNING: Cursor appears to be running (ALLOW_CURSOR_OPEN=1)"
        return 0
    fi
    if migrate_cursor_running; then
        migrate_die "Quit Cursor completely before restoring or fixing chat history."
    fi
}

migrate_fix_cursor_workspaces() {
    local home=$1
    local dry=${2:-0}
    local lib_dir
    lib_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    local py="${MIGRATE_SCRIPT_DIR:-$lib_dir}/fix-cursor-workspaces.py"

    [[ -d "$home/.config/Cursor/User/workspaceStorage" ]] || {
        migrate_log "No Cursor workspaceStorage — skipping workspace fix"
        return 0
    }

    migrate_require_cursor_closed

    migrate_log "Fixing duplicate Cursor workspace IDs (chat history)"
    local -a args=(--home "$home")
    [[ -n "${OLD_HOME:-}" && -d "$OLD_HOME" ]] && args+=(--backup-home "$OLD_HOME")
    [[ "$dry" == 1 ]] && args+=(--dry-run)
    python3 "$py" "${args[@]}"
}

migrate_restore_includes_cursor() {
    [[ "${SKIP_CURSOR_FIX:-}" == 1 ]] && return 1
    [[ -z "${ONLY:-}" ]] && return 0
    echo ",$ONLY," | grep -qE ',(\.config/Cursor|\.cursor)(,|$)'
}

migrate_git_scaffold() {
    local new_home=$1
    local dry=${2:-0}
    if [[ "$dry" == 1 ]]; then
        migrate_log "would mkdir $new_home/git/Github"
        return 0
    fi
    mkdir -p "$new_home/git/Github"
}

migrate_git_rsync() {
    local old_home=$1
    local new_home=$2
    local relpath=$3
    local dry=${4:-0}
    local exclude_file=${5:-}

    local src="$old_home/$relpath"
    local dst="$new_home/$relpath"
    [[ -d "$src" ]] || { migrate_log "skip (missing): $src"; return 0; }

    local -a rsync_opts=(-aHAX --numeric-ids --info=progress2 --partial)
    [[ "$dry" == 1 ]] && rsync_opts+=(--dry-run)
    [[ -n "$exclude_file" && -f "$exclude_file" ]] && rsync_opts+=(--exclude-from="$exclude_file")

    migrate_log "rsync $(du -sh "$src" 2>/dev/null | cut -f1) $src -> $dst"
    mkdir -p "$(dirname "$dst")"
    rsync "${rsync_opts[@]}" "$src/" "$dst/"
}

migrate_git_rsync_github_small() {
    local script_dir=$1
    local old_home=$2
    local new_home=$3
    local dry=${4:-0}
    local exclude_list=${5:-git-large-repos.txt}

    local src="$old_home/git/Github"
    local dst="$new_home/git/Github"
    [[ -d "$src" ]] || { migrate_log "skip (missing): $src"; return 0; }

    local exclude_file="$script_dir/$exclude_list"
    local -a rsync_opts=(-aHAX --numeric-ids --info=progress2 --partial)
    [[ "$dry" == 1 ]] && rsync_opts+=(--dry-run)
    [[ -f "$exclude_file" ]] && rsync_opts+=(--exclude-from="$exclude_file")

    migrate_log "rsync Github/ (excluding large repos) $src -> $dst"
    mkdir -p "$dst"
    rsync "${rsync_opts[@]}" "$src/" "$dst/"
}

migrate_configure_nopasswd_sudo() {
    local dry=${1:-0}
    [[ "${SKIP_SUDO_NOPASSWD:-}" == 1 ]] && return 0

    local user=${SUDO_USER:-${LOGNAME:-$(id -un)}}
    local dropin="/etc/sudoers.d/99-${user}-nopasswd"
    local line="$user ALL=(ALL:ALL) NOPASSWD: ALL"

    if [[ "$dry" == 1 ]]; then
        migrate_log "would write $dropin"
        return 0
    fi

    if [[ ! -w /etc/sudoers.d && "$(id -u)" -ne 0 ]]; then
        migrate_log "Installing passwordless sudo (requires sudo once)..."
        printf '%s\n' "$line" | sudo tee "$dropin" >/dev/null
        sudo chmod 0440 "$dropin"
        sudo visudo -cf "$dropin"
    else
        printf '%s\n' "$line" >"$dropin"
        chmod 0440 "$dropin"
        visudo -cf "$dropin"
    fi
    migrate_log "Passwordless sudo enabled via $dropin"
}
