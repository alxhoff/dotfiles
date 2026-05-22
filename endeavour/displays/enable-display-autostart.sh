#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cp "$REPO_ROOT/endeavour/ml4w-patches/hypr/conf/autostart.conf" \
    "${HOME}/.mydotfiles/com.ml4w.hyprlandstarter/.config/hypr/conf/autostart.conf"
echo "Autostart updated (display listener only). Log out/in or: hyprctl reload"
