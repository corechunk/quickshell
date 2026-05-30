import QtQuick
import QtQuick.Layouts
import "../../../core/theme" as CoreTheme

/**
 * ResultItem.qml
 * - Rigid layout for pixel-perfect title alignment.
 * - Always shows icons as glyphs.
 * - Uses window.theme for robust color fallback.
 */
Rectangle {
    id: rootItem

    signal hovered()

    property var theme: CoreTheme.AppTheme
    property string title: "Unknown"
    property string type: "Item"
    property string icon: "󰀻"
    property bool active: ListView.isCurrentItem
    
    height: 64
    radius: 12
    
    // Smooth transitions
    color: active ? (theme.highlight || "transparent") : (itemMouse.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
    border.color: theme.accent
    border.width: (active || itemMouse.containsMouse) ? 1 : 0
    opacity: active || itemMouse.containsMouse ? 1.0 : 0.8
    
    scale: active ? 1.01 : 1.0
    Behavior on scale { NumberAnimation { duration: 100 } }
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        spacing: 0

        // 1. Rigid Icon Area (Ensures text always starts at the same spot)
        Item {
            Layout.preferredWidth: 45
            Layout.preferredHeight: 40
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 38; height: 38; radius: 10
                color: active ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
                
                Text {
                    anchors.centerIn: parent
                    // Explicitly use glyphs to prevent text overflow from icon names
                    text: {
                        if (rootItem.icon === "calculator") return "󰪚";
                        if (rootItem.type === "Rice Action") return "󱎫";
                        return ""; 
                    }
                    color: active ? theme.accent : (theme.fg || "white")
                    font.pixelSize: 22
                    opacity: active ? 1.0 : 0.6
                }
            }
        }

        // 2. Text Content (Rigidly left-aligned with zero floating)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            spacing: 0
            
            Text {
                text: rootItem.title.trim()
                color: theme.fg || "white"
                font.pixelSize: 16
                font.bold: active
                elide: Text.ElideRight
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                opacity: active ? 1.0 : 0.8
            }
            
            Text {
                text: rootItem.type.trim()
                color: theme.accent
                opacity: active ? 0.9 : 0.5
                font.pixelSize: 10
                font.capitalization: Font.AllUppercase
                font.bold: active
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
            }
        }
        
        // 3. Action Indicator (Far right)
        Rectangle {
            visible: active || itemMouse.containsMouse
            Layout.alignment: Qt.AlignRight
            height: 24; width: 85; radius: 6
            color: active ? theme.accent : Qt.rgba(1,1,1,0.1)
            
            Text {
                anchors.centerIn: parent
                text: active ? "⏎ EXECUTE" : "SELECT"
                color: active ? (theme.bgDark || "black") : (theme.fg || "white")
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    MouseArea {
        id: itemMouse
        anchors.fill: parent
        hoverEnabled: true
        onEntered: rootItem.hovered()
    }
}
