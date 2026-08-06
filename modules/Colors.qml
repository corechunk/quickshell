// Colors.qml
pragma Singleton
import QtQuick

QtObject {
    // Base
    readonly property color bg:          "#0c0c14"
    readonly property color header:      "#0d0d1a"
    readonly property color surface:     "#161625"
    readonly property color surfaceAlt:  "#1a1a2e"
    readonly property color sidebar:     "#272737"

    // Borders
    readonly property color border:      "#1e1e2e"
    readonly property color borderAlt:   "#313244"
    readonly property color borderSubtle:"#22ffffff"

    // Text
    readonly property color text:        "#e8eaed"
    readonly property color textBright:  "#cdd6f4"
    readonly property color textSub:     "#9aa0a6"
    readonly property color textDim:     "#5f6368"

    // Accents
    readonly property color blue:        "#89b4fa"
    readonly property color green:       "#a6e3a1"
    readonly property color yellow:      "#f9e2af"
    readonly property color orange:      "#fab387"
    readonly property color red:         "#f38ba8"

    // Muted Accents (for backgrounds/borders)
    readonly property color blueMuted:   "#2a6ed440"
    readonly property color yellowMuted: "#c9a84040"
    readonly property color redMuted:    "#c0446040"
    readonly property color greenMuted:  "#3ea36438"

    // Hover / States
    readonly property color hover:       "#2a2a3e"
    readonly property color hoverSubtle: "#0dffffff"
    readonly property color hoverLine:   "#40ffffff"
}