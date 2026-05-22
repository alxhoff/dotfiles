#!/usr/bin/env bash
# Toggle nm-applet (waybar network right-click)
if pgrep -x nm-applet >/dev/null; then
    pkill nm-applet
else
    nm-applet --indicator &
fi
