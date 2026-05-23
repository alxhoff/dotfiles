#!/usr/bin/env bash
# Optional fallback if native Steam Link mis-renders the stream on Wayland.
# Trade-off: XWayland often traps the mouse inside the window while streaming.
set -euo pipefail

export QT_QPA_PLATFORM=xcb
export QT_AUTO_SCREEN_SCALE_FACTOR=0
unset GDK_BACKEND
unset SDL_VIDEODRIVER

exec /usr/bin/steamlink "$@"
