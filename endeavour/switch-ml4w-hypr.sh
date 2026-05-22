#!/usr/bin/env bash
# Point ~/.config/hypr back at ML4W Hyprland Starter (stock .mydotfiles tree).
set -euo pipefail

ML4W_HYPR="${HOME}/.mydotfiles/com.ml4w.hyprlandstarter/.config/hypr"

if [[ ! -d "$ML4W_HYPR" ]]; then
    echo "ML4W starter not found: $ML4W_HYPR" >&2
    echo "Install from https://github.com/mylinuxforwork/hyprland-starter" >&2
    exit 1
fi

if [[ -L "$HOME/.config/hypr" ]]; then
    echo "Current: $(readlink -f "$HOME/.config/hypr")"
fi

mkdir -p "$HOME/.config"
ln -sfn "$ML4W_HYPR" "$HOME/.config/hypr"

echo "Linked ~/.config/hypr -> ML4W starter"
echo ""
echo "Install ML4W dependencies (if you have not yet):"
echo "  ./endeavour/setup-hyprland-default.sh --ml4w"
echo ""
echo "Log out and log into Hyprland. Errors: cat ~/.cache/hyprland/hyprland.log"
