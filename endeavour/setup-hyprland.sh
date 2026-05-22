#!/usr/bin/env bash
# One-shot Hyprland + ML4W setup for a fresh EndeavourOS install (re-run safe).
#
# Usage:
#   ./endeavour/setup-hyprland.sh              # full setup
#   ./endeavour/setup-hyprland.sh --dry-run
#   ./endeavour/setup-hyprland.sh --skip-packages   # configs only (packages already installed)
#
# After install: log out → session "Hyprland" → Super+Return terminal, Super+C browser (ML4W binds)
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=${DRY_RUN:-0}
SKIP_PACKAGES=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --skip-packages) SKIP_PACKAGES=1 ;;
        -h|--help)
            sed -n '2,10p' "$0"
            exit 0
            ;;
        *) echo "Unknown: $arg" >&2; exit 1 ;;
    esac
done

export DRY_RUN

log() { echo ""; echo "======== $* ========"; }

run() {
    local script=$1
    shift
    log "$(basename "$script") $*"
    "$script" "$@"
}

log "Hyprland + ML4W setup (dotfiles)"
echo "Repo: $DOTFILES_DIR"

run "$DOTFILES_DIR/endeavour/install-ml4w-starter.sh"

if [[ "$SKIP_PACKAGES" != 1 ]]; then
    run "$DOTFILES_DIR/endeavour/setup-hyprland-default.sh" --ml4w
fi
run "$DOTFILES_DIR/endeavour/apply-ml4w-patches.sh"
run "$DOTFILES_DIR/endeavour/fix-ml4w-waybar.sh"

cat <<EOF

======== Done ========

1. Log out and choose the **Hyprland** session (not Plasma).
2. Default keybinds are **Super** (Windows key), not Alt — see ML4W binds.conf.
3. Optional: home/work monitors — docs/HYPRLAND-DISPLAYS.md

Re-run anytime after git pull:
  ./endeavour/setup-hyprland.sh

Configs only (no pacman):
  ./endeavour/setup-hyprland.sh --skip-packages

Errors: cat ~/.cache/hyprland/hyprland.log
       Hyprland --verify-config -c ~/.config/hypr/hyprland.conf

EOF
