#!/usr/bin/env bash
# Steam Link on Hyprland: native Wayland often renders only part of the stream
# when tiled/resized. XWayland avoids that; window rules keep it floating.
set -euo pipefail

export QT_QPA_PLATFORM=xcb
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export GDK_BACKEND=x11
export SDL_VIDEODRIVER=x11

exec /usr/bin/steamlink "$@"
