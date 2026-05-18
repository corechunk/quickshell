import QtQuick
import Quickshell
import Quickshell.Io

// Singleton to define DESIGN LOGIC and handle RELOADING
pragma Singleton

Item {
    id: root

    // --- RELOAD LOGIC ---
    readonly property string colorsPath: "file://" + Quickshell.env("QS_CONFIG_DIR") + "/core/theme/Colors.qml"
    
    property var colors: null

    function reload() {
        console.log("Quickshell: Attempting theme reload from: " + colorsPath);
        let component = Qt.createComponent(colorsPath);
        
        const finish = () => {
            if (component.status === Component.Ready) {
                if (root.colors) root.colors.destroy();
                root.colors = component.createObject(root);
                console.log("Quickshell: Theme successfully loaded.");
            } else if (component.status === Component.Error) {
                console.error("Quickshell: Failed to load Colors.qml: " + component.errorString());
            }
        };

        if (component.status === Component.Loading) {
            component.statusChanged.connect(finish);
        } else {
            finish();
        }
    }

    FileWatcher {
        path: Quickshell.env("QS_CONFIG_DIR") + "/core/theme/Colors.qml"
        onFileChanged: root.reload()
    }

    Component.onCompleted: reload()

    // --- FUNCTIONAL PROPERTIES ---
    // Hardcoded fallbacks ensure the UI is never white/black if loading fails
    readonly property color bg: colors ? colors.background : "#0f0f14"
    readonly property color fg: colors ? colors.foreground : "#cdd6f4"
    readonly property color accent: colors ? colors.color4 : "#89b4fa"

    // --- DERIVED COLORS ---
    readonly property color bgDark: colors ? Qt.darker(bg, 1.2) : "#0a0a0f"
    readonly property color surface: colors ? Qt.rgba(fg.r, fg.g, fg.b, 0.05) : Qt.rgba(1, 1, 1, 0.05)
    readonly property color highlight: colors ? Qt.rgba(accent.r, accent.g, accent.b, 0.15) : Qt.rgba(0.5, 0.7, 1.0, 0.15)
    readonly property color border: colors ? Qt.rgba(accent.r, accent.g, accent.b, 0.3) : Qt.rgba(0.5, 0.7, 1.0, 0.3)

    // Status colors
    readonly property color error: colors ? colors.color1 : "#f38ba8"
    readonly property color success: colors ? colors.color2 : "#a6e3a1"
}
