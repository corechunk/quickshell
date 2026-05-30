#!/usr/bin/env bash

# Current directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set library paths
export QML2_IMPORT_PATH="$DIR/imports:$QML2_IMPORT_PATH"
export QML_XHR_ALLOW_FILE_READ=1

# Get session type
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-$(loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type --value 2>/dev/null || echo wayland)}"

# Theme Resolution Logic
if [ -d "$DIR/current-lockscreen-theme" ]; then
    # Priority 1: Use the developer-managed symlink
    export QS_THEME_PATH="$DIR/current-lockscreen-theme"
    export QS_THEME=$(basename "$(readlink -f "$DIR/current-lockscreen-theme")")
elif [ -n "$1" ]; then
    # Priority 2: Command line argument
    export QS_THEME="$1"
    export QS_THEME_PATH="$DIR/../themes/$QS_THEME"
elif [ -f "$HOME/.config/qylock/theme" ]; then
    # Priority 3: Config file
    export QS_THEME=$(cat "$HOME/.config/qylock/theme")
    export QS_THEME_PATH="$DIR/../themes/$QS_THEME"
else
    # Fallback: Default theme
    export QS_THEME="pixel-night-city"
    export QS_THEME_PATH="$DIR/../themes/$QS_THEME"
fi

# Secondary Fallback for path resolution (handles local vs installed layouts)
if [ ! -d "$QS_THEME_PATH" ] && [ -d "$DIR/themes_link/$QS_THEME" ]; then
    export QS_THEME_PATH="$DIR/themes_link/$QS_THEME"
fi

echo "Locking with Quickshell using theme: $QS_THEME"
echo "Theme path: $QS_THEME_PATH"

# Kill active lockers
killall -9 hyprlock swaylock wlogout 2>/dev/null || true

# Execute lock screen
quickshell -p "$DIR/lock_shell.qml"
