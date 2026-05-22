#!/usr/bin/env bash
# Staged ~/git restore: small Github repos first, large trees last.
# cartken skips sdkmanager_docker_output/ (git-cartken.exclude)
# kernel_builder bulk (rootfs, storage, usb_disk) are separate prompt steps.
#
# Usage (normal user, backup mounted or will auto-mount):
#   ./migrate/restore-git.sh
#   DRY_RUN=1 ./migrate/restore-git.sh
#   GIT_RESTORE_FROM=kb-storage ./migrate/restore-git.sh
#   ./migrate/restore-all.sh   # git step invokes this automatically
#   MIGRATE_YES=1 ./migrate/restore-git.sh
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEPS_FILE=${STEPS_FILE:-$SCRIPT_DIR/git-restore-steps.conf}

# shellcheck source=migrate/lib.sh
source "$SCRIPT_DIR/lib.sh"

export MIGRATE_SCRIPT_DIR="$SCRIPT_DIR"
migrate_refuse_sudo_restore

DRY_RUN=${DRY_RUN:-0}
OLD_USER=${OLD_USER:-alxhoff}
NEW_HOME=$(migrate_new_home)
GIT_RESTORE_FROM=${GIT_RESTORE_FROM:-${RESTORE_FROM_STEP:-}}

export NEW_HOME

step_banner() {
    local n=$1 total=$2 id=$3 label=$4
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Git step $n/$total: $label  ($id)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

run_git_step() {
    local path_key=$1
    local exclude_name=${2:-}

    case "$path_key" in
        git-scaffold)
            migrate_git_scaffold "$NEW_HOME" "$DRY_RUN"
            ;;
        github-exclude-large)
            migrate_git_rsync_github_small "$SCRIPT_DIR" "$OLD_HOME" "$NEW_HOME" "$DRY_RUN" "$exclude_name"
            ;;
        git/*)
            local exclude_file=""
            [[ -n "$exclude_name" ]] && exclude_file="$SCRIPT_DIR/$exclude_name"
            migrate_git_rsync "$OLD_HOME" "$NEW_HOME" "$path_key" "$DRY_RUN" "$exclude_file"
            ;;
        *)
            migrate_die "Unknown git path key: $path_key"
            ;;
    esac
}

declare -a STEP_IDS=() STEP_LABELS=() STEP_PATHS=() STEP_EXCLUDES=()
while IFS='|' read -r sid label path_key exclude_name || [[ -n "$sid" ]]; do
    [[ -z "$sid" || "$sid" =~ ^# ]] && continue
    STEP_IDS+=("$sid")
    STEP_LABELS+=("$label")
    STEP_PATHS+=("$path_key")
    STEP_EXCLUDES+=("${exclude_name:-}")
done < "$STEPS_FILE"

total=${#STEP_IDS[@]}
[[ $total -gt 0 ]] || migrate_die "No steps in $STEPS_FILE"

if ! OLD_HOME=$(migrate_resolve_old_home 2>/dev/null); then
    migrate_ensure_backup_mounted "$SCRIPT_DIR"
    OLD_HOME=$(migrate_resolve_old_home) || migrate_die "Cannot resolve OLD_HOME"
fi
export OLD_HOME

migrate_log "Git staged restore → $NEW_HOME"
migrate_log "Backup:  $OLD_HOME"
migrate_log "Steps:   $STEPS_FILE"
[[ "$DRY_RUN" == 1 ]] && migrate_log "DRY RUN"

echo ""
echo "Size overview on backup:"
du -sh "$OLD_HOME/git" "$OLD_HOME/git/Github" "$OLD_HOME/git/cartken" 2>/dev/null || true
du -sh "$OLD_HOME/git/Github/kernel_builder" "$OLD_HOME/git/Github/kernel_builder/storage" \
    "$OLD_HOME/git/Github/kernel_builder/scripts/rootfs" \
    "$OLD_HOME/git/Github/kernel_builder/scripts/usb_disk" 2>/dev/null || true
echo ""

if ! migrate_confirm "Start staged ~/git restore ($total sub-steps)?"; then
    echo "Aborted."
    exit 0
fi

skip_until=${GIT_RESTORE_FROM:-}
skipping=0
[[ -n "$skip_until" ]] && skipping=1

n=0
for ((i = 0; i < total; i++)); do
    sid=${STEP_IDS[$i]}
    label=${STEP_LABELS[$i]}
    path_key=${STEP_PATHS[$i]}
    exclude_name=${STEP_EXCLUDES[$i]}
    n=$((n + 1))

    if [[ "$skipping" == 1 ]]; then
        if [[ "$sid" == "$skip_until" ]]; then
            skipping=0
        else
            migrate_log "Skipping git step $sid (resume from $skip_until)"
            continue
        fi
    fi

    if [[ $i -gt 0 ]]; then
        migrate_prompt_continue "Previous git step finished. Start next?" || {
            echo "Stopped before git step $sid."
            echo "Resume: GIT_RESTORE_FROM=$sid ./migrate/restore-git.sh"
            echo "Or from full restore: RESTORE_FROM_STEP=git GIT_RESTORE_FROM=$sid ./migrate/restore-all.sh"
            exit 0
        }
    fi

    step_banner "$n" "$total" "$sid" "$label"
    run_git_step "$path_key" "$exclude_name"
    migrate_log "Git step '$sid' done."
done

echo ""
migrate_log "~/git staged restore complete."
