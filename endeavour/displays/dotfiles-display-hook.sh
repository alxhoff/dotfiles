#!/usr/bin/env bash
# Called from kanshi exec= after profile apply (install to ~/.config/hypr/scripts/)
DOTFILES_DISPLAYS="${DOTFILES_DISPLAYS:-$HOME/git/Github/dotfiles/endeavour/displays}"
notify-send -t 3000 "Display profile" "${1:-applied}" 2>/dev/null || true
# Optional: reload waybar after display profile changes
if [[ -x "${HOME}/.config/ml4w/scripts/waybar-launch.sh" ]]; then
    "${HOME}/.config/ml4w/scripts/waybar-launch.sh" &
fi
