#!/usr/bin/env bash
# Pick a random image from ~/Pictures/wallpaper and apply via hyprpaper.
set -euo pipefail

dir=${WALLPAPER_DIR:-$HOME/Pictures/wallpaper}
shopt -s nullglob
mapfile -t imgs < <(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
((${#imgs[@]})) || { notify-send wallpaper "No images in $dir"; exit 1; }

pick=${imgs[RANDOM % ${#imgs[@]}]}
while IFS= read -r mon; do
    [[ -n "$mon" ]] || continue
    hyprctl hyprpaper wallpaper "$mon,$pick,cover"
done < <(hyprctl monitors | awk '/^Monitor/{print $2}')

notify-send -t 2000 wallpaper "$(basename "$pick")"
