import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: barWindow

    anchors {
        top: true
        left: true
        right: true
    }
    
    implicitHeight: 36
    color: "transparent"

    Rectangle {
        id: barBackground
        anchors.fill: parent
        color: "#1e1e2e"
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8
        }
    }
}