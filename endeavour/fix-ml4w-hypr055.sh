#!/usr/bin/env bash
# Legacy wrapper — use apply-ml4w-patches.sh (called from setup-hyprland.sh).
set -euo pipefail
DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
exec "$DOTFILES_DIR/endeavour/apply-ml4w-patches.sh"
