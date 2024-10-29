#!/bin/sh

# Terminate already running bar instances
killall -q polybar

# Define primary, fallback, secondary, and tertiary monitors
PRIMARY_MONITOR="DisplayPort-7"
FALLBACK_MONITOR="eDP"
SECONDARY_MONITOR="DisplayPort-6"
TERTIARY_MONITOR="DisplayPort-8"

# Check if each monitor is connected
PRIMARY_CONNECTED=$(xrandr --query | grep "$PRIMARY_MONITOR connected")
FALLBACK_CONNECTED=$(xrandr --query | grep "$FALLBACK_MONITOR connected")
SECONDARY_CONNECTED=$(xrandr --query | grep "$SECONDARY_MONITOR connected")
TERTIARY_CONNECTED=$(xrandr --query | grep "$TERTIARY_MONITOR connected")

# Kill any running Polybar instances to avoid duplicates
killall -q polybar

# Launch Polybar on primary or fallback monitor
if [ "$PRIMARY_CONNECTED" ]; then
    MONITOR=$PRIMARY_MONITOR polybar topmain &
    MONITOR=$PRIMARY_MONITOR polybar bottommain &
elif [ "$FALLBACK_CONNECTED" ]; then
    MONITOR=$FALLBACK_MONITOR polybar topmain &
    MONITOR=$FALLBACK_MONITOR polybar bottommain &
else
    # Default to the first available monitor if neither primary nor fallback are connected
    DEFAULT_MONITOR=$(xrandr --query | grep " connected" | awk '{ print $1 }' | head -n 1)
    MONITOR=$DEFAULT_MONITOR polybar topsecondary &
fi

# Launch Polybar on secondary monitor if connected
if [ "$SECONDARY_CONNECTED" ]; then
    MONITOR=$SECONDARY_MONITOR polybar topsecondary &
fi

# Launch Polybar on tertiary monitor if connected
if [ "$TERTIARY_CONNECTED" ]; then
    MONITOR=$TERTIARY_MONITOR polybar topsecondary &
fi
