#!/bin/bash

# specialized: "Rectangular Path" & Cursor math for Flyouts.
# Usage: ./launch.sh ModuleName [--fromShortcut]

MODULE_NAME=$1
FLAG=$2

if [[ -z "$MODULE_NAME" ]]; then
    echo "Usage: $0 ModuleName [--fromShortcut]"
    exit 1
fi

# Set Config Directory
export QS_CONFIG_DIR="$HOME/.config/quickshell"
LOCK_DIR="/tmp"
# Sanitize module name for lockfile (replace / with -)
SAFE_NAME=$(echo "$MODULE_NAME" | tr '/' '-')
LOCK_FILE="Quickshell${SAFE_NAME}.lock"
LOCK_PATH="$LOCK_DIR/$LOCK_FILE"

# Use flock to ensure only one instance of THIS module runs.
exec 9>"$LOCK_PATH"
if ! flock -n 9; then
    echo "${MODULE_NAME} is already running."
    exit 0
fi

# Determine positioning mode
if [[ "$FLAG" == "--fromShortcut" ]]; then
    # Get active monitor info for fixed positioning (bottom-right)
    MONITOR_INFO=$(hyprctl monitors -j | jq '.[] | select(.focused == true)')
    WIDTH=$(echo "$MONITOR_INFO" | jq '.width')
    HEIGHT=$(echo "$MONITOR_INFO" | jq '.height')
    
    # Target bottom-right corner of the monitor.
    export QS_MOUSE_X=$WIDTH
    export QS_MOUSE_Y=$HEIGHT
    export QS_LAUNCH_MODE="shortcut"
else
    # Default: Follow Cursor
    CURSOR_POS=$(hyprctl cursorpos -j)
    RAW_X=$(echo "$CURSOR_POS" | jq '.x')
    RAW_Y=$(echo "$CURSOR_POS" | jq '.y')

    # Get the monitor containing the cursor to calculate relative coordinates
    MONITOR_INFO=$(hyprctl monitors -j | jq ".[] | select(.x <= $RAW_X and .y <= $RAW_Y and .x + .width > $RAW_X and .y + .height > $RAW_Y)")
    
    # Fallback to focused monitor if cursor detection fails
    if [[ -z "$MONITOR_INFO" ]]; then
        MONITOR_INFO=$(hyprctl monitors -j | jq '.[] | select(.focused == true)')
    fi

    OFFSET_X=$(echo "$MONITOR_INFO" | jq '.x')
    OFFSET_Y=$(echo "$MONITOR_INFO" | jq '.y')

    export QS_MOUSE_X=$((RAW_X - OFFSET_X))
    export QS_MOUSE_Y=$((RAW_Y - OFFSET_Y))
    export QS_LAUNCH_MODE="cursor"
fi

# Launch Quickshell module
exec quickshell -p "$QS_CONFIG_DIR/modules/${MODULE_NAME}/Main.qml"
