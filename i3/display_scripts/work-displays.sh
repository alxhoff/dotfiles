#!/bin/sh
xrandr --verbose --output eDP-1 --off --output DP-2 --off --output DP-1 --off --output HDMI-1 --off --output HDMI-2 --off \
    --output DP-1-2 --primary --mode 1920x1200 --crtc 0 --pos 1200x232 --rotate normal \
    --output HDMI-2 --off --output HDMI-1 --off --output DP-1 --off --output DP-1-3 --mode 1920x1200 --crtc 0 --pos 3120x0 --rotate left \
    --output DP-2 --off --output DP-1-1 --mode 1920x1200 --crtc 0 --pos 0x0 --rotate left
