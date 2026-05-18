import QtQuick
import Quickshell
import Quickshell.Io

// Singleton for global system-wide behaviors
pragma Singleton

Item {
    id: root

    // --- ANIMATION SETTINGS ---
    // We check Hyprland's global animation setting
    property bool animationsEnabled: true
    
    // Unified durations to be used across all modules
    readonly property int durationLow: animationsEnabled ? 200 : 0
    readonly property int durationMid: animationsEnabled ? 400 : 0
    readonly property int durationHigh: animationsEnabled ? 800 : 0
    
    // Easing style for the whole rice
    readonly property int easingType: Easing.OutExpo

    // Process to fetch the setting from Hyprland
    Process {
        id: hyprCheck
        command: ["hyprctl", "getoption", "animations:enabled", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let json = JSON.parse(this.text);
                    root.animationsEnabled = (json.int === 1);
                } catch (e) {
                    console.error("Quickshell: Failed to parse hyprctl output");
                }
            }
        }
    }
}
