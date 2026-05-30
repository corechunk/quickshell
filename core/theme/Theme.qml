import QtQuick
import Quickshell

pragma Singleton

/**
 * Theme.qml (Defined as AppTheme in qmldir)
 * Unique name avoids conflict with potential internal 'Theme' types.
 */
Item {
    id: root

    // Instantiate local Colors (Colors.qml in same directory)
    Colors { id: colorsSource }

    // Systematically map variables with immediate hardcoded fallbacks (Red)
    readonly property color bg: colorsSource.background || "#1C0000"
    readonly property color fg: colorsSource.foreground || "#F4DADA"
    readonly property color accent: colorsSource.color4 || "#D65151"

    readonly property color bgDark: Qt.darker(bg, 1.2)
    readonly property color surface: Qt.rgba(fg.r, fg.g, fg.b, 0.05)
    readonly property color highlight: Qt.rgba(accent.r, accent.g, accent.b, 0.15)
    readonly property color border: Qt.rgba(accent.r, accent.g, accent.b, 0.3)
}
