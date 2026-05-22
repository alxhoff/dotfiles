#!/usr/bin/env bash
# Staged full restore: small/fast steps first, ~/git last.
# Each step completes, then you are prompted before the next step starts.
#
# Usage (run as your normal user, not sudo):
#   ./migrate/restore-all.sh
#   BACKUP_DISK=/dev/sda ./migrate/restore-all.sh
#   RESTORE_FROM_STEP=cursor ./migrate/restore-all.sh   # resume
#   DRY_RUN=1 ./migrate/restore-all.sh                  # preview each step
#   MIGRATE_YES=1 ./migrate/restore-all.sh              # no prompts (CI / brave)
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
STEPS_FILE=${STEPS_FILE:-$SCRIPT_DIR/restore-steps.conf}

# shellcheck source=migrate/lib.sh
source "$SCRIPT_DIR/lib.sh"

migrate_refuse_sudo_restore

DRY_RUN=${DRY_RUN:-0}
MANIFEST=${MANIFEST:-$SCRIPT_DIR/manifest.conf}
OLD_USER=${OLD_USER:-alxhoff}
NEW_HOME=$(migrate_new_home)
RESTORE_FROM_STEP=${RESTORE_FROM_STEP:-}

export NEW_HOME

step_banner() {
    local n=$1 total=$2 id=$3 label=$4
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Step $n/$total: $label  ($id)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

run_restore_subset() {
    local only=$1
    ONLY="$only" MANIFEST="$MANIFEST" OLD_USER="$OLD_USER" NEW_HOME="$NEW_HOME" \
        OLD_HOME="${OLD_HOME:-}" DRY_RUN="$DRY_RUN" MIGRATE_YES=1 SKIP_CONFIRM=1 \
        SKIP_ENSURE_MOUNT=1 SKIP_SYSTEM_EXTRAS=1 \
        "$SCRIPT_DIR/restore-from-backup.sh"
}

run_precheck() {
    migrate_ensure_backup_mounted "$SCRIPT_DIR"
    migrate_check_backup_home "${OLD_HOME:-}" "$MANIFEST"
}

run_system_extras() {
    local old_root=${OLD_ROOT:-}
    if [[ -z "$old_root" ]] || [[ ! -d "$old_root/usr/local/lib" ]]; then
        migrate_log "Skipping spotify-adblock.so — set OLD_ROOT to mounted full root (not @home-only backup)"
        return 0
    fi
    local adb_src="$old_root/usr/local/lib/spotify-adblock.so"
    if [[ ! -f "$adb_src" ]]; then
        migrate_log "spotify-adblock.so not found on old root"
        return 0
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
        migrate_log "would install: $adb_src -> /usr/local/lib/spotify-adblock.so"
        return 0
    fi
    if migrate_confirm "Install spotify-adblock.so to /usr/local/lib/?"; then
        sudo install -Dm644 "$adb_src" /usr/local/lib/spotify-adblock.so
        migrate_log "Installed spotify-adblock.so"
    fi
}

# --- Parse steps ---
declare -a STEP_IDS=() STEP_LABELS=() STEP_ONLY=()
while IFS='|' read -r sid label only_paths || [[ -n "$sid" ]]; do
    [[ -z "$sid" || "$sid" =~ ^# ]] && continue
    STEP_IDS+=("$sid")
    STEP_LABELS+=("$label")
    STEP_ONLY+=("${only_paths:-}")
done < "$STEPS_FILE"

total=${#STEP_IDS[@]}
[[ $total -gt 0 ]] || migrate_die "No steps in $STEPS_FILE"

migrate_log "Staged restore → $NEW_HOME"
migrate_log "Steps file: $STEPS_FILE"
[[ "$DRY_RUN" == 1 ]] && migrate_log "DRY RUN — no writes"

# Resume: mount backup if skipping precheck
if [[ -n "$RESTORE_FROM_STEP" && "$RESTORE_FROM_STEP" != precheck ]]; then
    migrate_ensure_backup_mounted "$SCRIPT_DIR"
    export OLD_HOME
    OLD_HOME=$(migrate_resolve_old_home) || migrate_die "Cannot resolve OLD_HOME after mount"
    export OLD_HOME
fi

if ! migrate_confirm "Start staged restore ($total steps, git is last)?"; then
    echo "Aborted."
    exit 0
fi

# Resolve OLD_HOME after mount (precheck sets it)
skip_until=${RESTORE_FROM_STEP:-}
skipping=0
[[ -n "$skip_until" ]] && skipping=1

n=0
for ((i = 0; i < total; i++)); do
    sid=${STEP_IDS[$i]}
    label=${STEP_LABELS[$i]}
    only=${STEP_ONLY[$i]}
    n=$((n + 1))

    if [[ "$skipping" == 1 ]]; then
        if [[ "$sid" == "$skip_until" ]]; then
            skipping=0
        else
            migrate_log "Skipping step $sid (resume from $skip_until)"
            continue
        fi
    fi

    if [[ $i -gt 0 ]]; then
        migrate_prompt_continue "Previous step finished. Start next step?" || {
            echo "Stopped before step $sid. Resume with: RESTORE_FROM_STEP=$sid ./migrate/restore-all.sh"
            exit 0
        }
    fi

    step_banner "$n" "$total" "$sid" "$label"

    case "$sid" in
        precheck)
            run_precheck
            export OLD_HOME
            OLD_HOME=$(migrate_resolve_old_home) || migrate_die "OLD_HOME not set after precheck"
            export OLD_HOME
            ;;
        system)
            run_system_extras
            ;;
        git)
            migrate_log "Running staged ~/git restore (restore-git.sh)..."
            OLD_HOME="${OLD_HOME:-}" NEW_HOME="$NEW_HOME" DRY_RUN="$DRY_RUN" \
                MIGRATE_YES="${MIGRATE_YES:-}" GIT_RESTORE_FROM="${GIT_RESTORE_FROM:-}" \
                "$SCRIPT_DIR/restore-git.sh"
            ;;
        *)
            [[ "$only" == @* ]] && migrate_die "Unknown orchestrator step: $only"
            [[ -n "$only" ]] || migrate_die "Step $sid has no ONLY paths"
            if [[ "$DRY_RUN" == 1 ]]; then
                migrate_log "Dry-run restore: $only"
            fi
            run_restore_subset "$only"
            ;;
    esac

    migrate_log "Step '$sid' done."
done

echo ""
migrate_log "Staged restore complete."
migrate_log "Next: cd $DOTFILES_DIR && ./install.sh && git submodule update --init vim"
migrate_log "Hyprland: ./endeavour/setup-hyprland.sh  (see docs/HYPRLAND-SETUP.md)"
