#!/bin/sh

# Terminate already running bar instances
killall -q polybar

# Home
# Define primary, fallback, secondary, and tertiary monitors
PRIMARY_MONITOR="DisplayPort-7"
FALLBACK_MONITOR="eDP"
SECONDARY_MONITOR="DisplayPort-6"
TERTIARY_MONITOR="DisplayPort-8"

# Work
WORK_PRIMARY_MONITOR="DisplayPort-0"
WORK_SECONDARY_MONITOR="HDMI-A-0"
WORK_TERTIARY_MONITOR="DisplayPort-1"

# Check if each monitor is connected
PRIMARY_CONNECTED=$(xrandr --query | grep "$PRIMARY_MONITOR connected")
FALLBACK_CONNECTED=$(xrandr --query | grep "$FALLBACK_MONITOR connected")
SECONDARY_CONNECTED=$(xrandr --query | grep "$SECONDARY_MONITOR connected")
TERTIARY_CONNECTED=$(xrandr --query | grep "$TERTIARY_MONITOR connected")
WORK_PRIMARY_CONNECTED=$(xrandr --query | grep "$WORK_PRIMARY_MONITOR connected")
WORK_SECONDARY_CONNECTED=$(xrandr --query | grep "$WORK_SECONDARY_MONITOR connected")
WORK_TERTIARY_CONNECTED=$(xrandr --query | grep "$WORK_TERTIARY_MONITOR connected")

# Determine which set of monitors to use based on HDMI connection
if [ "$WORK_SECONDARY_CONNECTED" ]; then
    # Use alternative set if HDMI-A-0 is connected
    echo "Using work monitors"
    PRIMARY_MONITOR="$WORK_PRIMARY_MONITOR"
    SECONDARY_MONITOR="$WORK_SECONDARY_MONITOR"
    TERTIARY_MONITOR="$WORK_TERTIARY_MONITOR"
fi

# Kill any running Polybar instances to avoid duplicates
killall -q polybar

# Launch Polybar on primary or fallback monitor
if [ "$PRIMARY_CONNECTED"] || [ "$WORK_PRIMARY_CONNECTED" ]; then
    echo "Primary is connected: $PRIMARY_MONITOR"
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
if [ "$SECONDARY_CONNECTED" ] || [ "$WORK_SECONDARY_CONNECTED" ]; then
    echo "Launching secondary: $SECONDARY_MONITOR"
    MONITOR=$SECONDARY_MONITOR polybar topsecondary &
fi

# Launch Polybar on tertiary monitor if connected
if [ "$TERTIARY_CONNECTED" ] || [ "$WORK_TERTIARY_CONNECTED" ]; then
    echo "Launching tertiary: $TERTIARY_MONITOR"
    MONITOR=$TERTIARY_MONITOR polybar topsecondary &
fi
