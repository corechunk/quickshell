import QtQuick
import QtQuick.Layouts

/**
 * ResultItem.qml
 * Cleaned up for strict left-alignment, hover states, and fixed icons.
 */
Rectangle {
    id: rootItem
    
    property var theme: null
    
    property string title: "Unknown"
    property string type: "Item"
    property string icon: "󰀻"
    property bool active: ListView.isCurrentItem
    
    height: 64
    radius: 12
    
    // Background and border logic
    color: {
        if (active) return (theme.highlight || Qt.rgba(1,1,1,0.1));
        if (mouseArea.containsMouse) return Qt.rgba(1,1,1,0.05);
        return "transparent";
    }
    
    border.color: active ? (theme.accent || "#89b4fa") : "transparent"
    border.width: active ? 1 : 0
    
    // Pop animation on select
    scale: active ? 1.02 : 1.0
    Behavior on scale { NumberAnimation { duration: 150 } }
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        spacing: 15

        // Icon Box (Strictly left)
        Rectangle {
            id: iconBox
            width: 38; height: 38; radius: 10
            color: active ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
            
            Text {
                anchors.centerIn: parent
                // Always use a glyph, never the icon name text
                text: rootItem.icon === "calculator" ? "󰪚" : "󰀻"
                color: active ? (theme.accent || "#89b4fa") : (theme.fg || "#cdd6f4")
                font.pixelSize: 22
                opacity: active ? 1.0 : 0.6
            }
        }

        // Text Content (Strictly left-aligned)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            
            Text {
                text: rootItem.title
                color: theme.fg || "#cdd6f4"
                font.pixelSize: 16
                font.bold: active
                elide: Text.ElideRight
                opacity: active ? 1.0 : 0.8
            }
            
            Text {
                text: rootItem.type
                color: theme.accent || "#89b4fa"
                opacity: active ? 0.9 : 0.5
                font.pixelSize: 10
                font.capitalization: Font.AllUppercase
                font.bold: active
            }
        }
        
        // Execute indicator
        Rectangle {
            visible: active
            height: 22; width: 75; radius: 6
            color: theme.accent || "#89b4fa"
            
            Text {
                anchors.centerIn: parent
                text: "EXECUTE"
                color: theme.bgDark || "#0a0a0f"
                font.pixelSize: 9
                font.bold: true
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: (mouse) => {
            // This is handled by the parent's MouseArea delegate wrapper
            // but we keep it for hover detection.
        }
    }
}
