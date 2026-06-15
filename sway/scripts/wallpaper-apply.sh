#!/usr/bin/env bash
# Apply wallpapers on Sway via swaybg (no hyprctl / waypaper CLI).
set -euo pipefail

ACTION=${1:?usage: wallpaper-apply.sh restore|random|set <path>}
shift || true

WALLPAPER_DIR=${WALLPAPER_DIR:-$HOME/Pictures/wallpaper}
HYPR_CFG=${HYPR_WAYPAPER_CONFIG:-$HOME/.config/waypaper/config.ini}
SWAY_CFG=${SWAY_WAYPAPER_CONFIG:-$HOME/.config/sway/waypaper/config.ini}
FALLBACK="${WALLPAPER_DIR}/apple-light.jpg"
FILL=fill

read_cfg() {
    python3 - "$1" <<'PY'
import configparser
import pathlib
import sys

cfg = configparser.ConfigParser()
path = pathlib.Path(sys.argv[1]).expanduser()
if not path.is_file():
    sys.exit(0)
cfg.read(path, encoding="utf-8")
raw = cfg.get("Settings", "wallpaper", fallback="", raw=True).strip()
if raw:
    print(pathlib.Path(raw.splitlines()[0]).expanduser())
PY
}

write_cfg_wallpaper() {
    local img=$1
    python3 - "$img" "$HYPR_CFG" "$SWAY_CFG" <<'PY'
import configparser
import pathlib
import sys

img, *paths = sys.argv[1:]
for p in paths:
    path = pathlib.Path(p).expanduser()
    if not path.is_file():
        continue
    cfg = configparser.ConfigParser()
    cfg.read(path, encoding="utf-8")
    if not cfg.has_section("Settings"):
        cfg.add_section("Settings")
    cfg.set("Settings", "wallpaper", img.replace(str(pathlib.Path.home()), "~", 1))
    cfg.set("Settings", "monitors", "All")
    with path.open("w", encoding="utf-8") as f:
        cfg.write(f)
PY
}

pick_image() {
    local from_cfg
    from_cfg=$(read_cfg "$SWAY_CFG" || true)
    [[ -n "$from_cfg" && -f "$from_cfg" ]] && { echo "$from_cfg"; return; }
    from_cfg=$(read_cfg "$HYPR_CFG" || true)
    [[ -n "$from_cfg" && -f "$from_cfg" ]] && { echo "$from_cfg"; return; }
    [[ -f "$FALLBACK" ]] && { echo "$FALLBACK"; return; }
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | head -1
}

pick_random() {
    python3 - "$WALLPAPER_DIR" <<'PY'
import os
import random
import sys
from pathlib import Path

root = Path(sys.argv[1]).expanduser()
imgs = sorted(
    p for p in root.iterdir()
    if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
)
if imgs:
    print(random.choice(imgs))
PY
}

apply_swaybg() {
    local img=$1
    [[ -n "$img" && -f "$img" ]] || { notify-send -t 4000 wallpaper "No image to apply"; return 1; }
    command -v swaymsg >/dev/null || return 0
    command -v swaybg >/dev/null || { notify-send wallpaper "Install swaybg"; return 1; }

    pkill -x swaybg 2>/dev/null || true
    sleep 0.25
    # One swaybg covers all outputs (avoids per-output race on hotplug).
    swaybg -i "$img" -m "$FILL" &
    write_cfg_wallpaper "$img"
}

case "$ACTION" in
    restore)
        apply_swaybg "$(pick_image)"
        ;;
    random)
        img=$(pick_random)
        apply_swaybg "$img"
        notify-send -t 2000 wallpaper "$(basename "$img")"
        ;;
    set)
        apply_swaybg "${1:?missing image path}"
        ;;
    *)
        exit 2
        ;;
esac
