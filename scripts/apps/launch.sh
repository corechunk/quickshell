#!/bin/bash

# specialized: Centered/Full-screen overlays.
# Usage: ./launch.sh AppName

APP_NAME=$1

if [[ -z "$APP_NAME" ]]; then
    echo "Usage: $0 AppName"
    exit 1
fi

# Set Config Directory
export QS_CONFIG_DIR="$HOME/.config/quickshell"
LOCK_DIR="/tmp"
# Sanitize app name for lockfile
SAFE_NAME=$(echo "$APP_NAME" | tr '/' '-')
LOCK_FILE="Quickshell${SAFE_NAME}.lock"
LOCK_PATH="$LOCK_DIR/$LOCK_FILE"

# Ensure only one instance runs
exec 9>"$LOCK_PATH"
if ! flock -n 9; then
    echo "${APP_NAME} is already running."
    exit 0
fi

# Center/Overlay launch mode logic (centering is usually handled by the QML Window, 
# but we can set environment variables if needed by the mathematical model)
export QS_LAUNCH_MODE="centered"

# Launch Quickshell app from the config root to ensure relative imports are scoped correctly
cd "$QS_CONFIG_DIR" || exit 1
exec quickshell -p "apps/${APP_NAME}/Main.qml"
