import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// This file is a modular Quickshell module for audio control.
// It can be launched standalone or via a script that handles positioning.
// If no position is provided via QS_MOUSE_X/Y, it will default to the top-left.

ShellRoot {
    id: root

    // Directory for resources
    property string configDir: Quickshell.env("QS_CONFIG_DIR") || "~/.config/quickshell"
    property string lockDir: "/tmp"
    property string lockFile: "QuickshellMediaControl.lock"

    property int targetX: Quickshell.env("QS_MOUSE_X") !== "" ? parseInt(Quickshell.env("QS_MOUSE_X")) : 0
    property int targetY: Quickshell.env("QS_MOUSE_Y") !== "" ? parseInt(Quickshell.env("QS_MOUSE_Y")) : 0
    property string launchMode: Quickshell.env("QS_LAUNCH_MODE") || "cursor"

    property string title: "No Media Playing"
    property string artist: ""
    property string status: "Stopped"
    property string artUrl: ""
    property real position: 0
    property real length: 1

    Timer {
        id: updateTimer
        interval: 500
        running: true
        repeat: true
        onTriggered: metadataProcess.running = true
    }

    Process {
        id: metadataProcess
        command: ["playerctl", "metadata", "--format", "{{title}}||{{artist}}||{{status}}||{{mpris:artUrl}}||{{mpris:length}}||{{position}}"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text.trim();
                if (text === "") {
                    root.title = "No Media Playing";
                    root.artist = "";
                    root.status = "Stopped";
                    root.artUrl = "";
                    return;
                }
                let parts = text.split("||");
                if (parts.length >= 6) {
                    root.title = parts[0] || "Unknown Title";
                    root.artist = parts[1] || "Unknown Artist";
                    root.status = parts[2] || "Stopped";
                    root.artUrl = parts[3] || "";
                    root.length = (parseInt(parts[4]) / 1000000) || 1;
                    root.position = (parseInt(parts[5]) / 1000000) || 0;
                }
            }
        }
    }

    Process {
        id: controlProcess
        function send(cmd) {
            command = ["playerctl", cmd];
            running = true;
        }
    }

    PanelWindow {
        id: window
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        surfaceFormat.opaque: false
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }

        Rectangle {
            id: menuContainer
            width: 360
            height: 500
            
            // Define margins based on launch mode
            readonly property int screenMargin: root.launchMode === "shortcut" ? 15 : 10

            x: {
                let targetPos = root.launchMode === "shortcut" 
                    ? root.targetX - (width / 2) 
                    : root.targetX - (width / 2);
                return Math.max(screenMargin, Math.min(targetPos, parent.width - width - screenMargin));
            }
            y: {
                let targetPos = root.launchMode === "shortcut"
                    ? root.targetY - height - 10
                    : root.targetY - (height / 2);
                return Math.max(screenMargin, Math.min(targetPos, parent.height - height - screenMargin));
            }
            
            color: Qt.rgba(0.05, 0.05, 0.08, 0.98)
            radius: 30
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
            clip: true

            MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }
            focus: true
            Keys.onEscapePressed: Qt.quit()

            Button {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 15
                width: 30; height: 30; z: 10
                flat: true
                background: Rectangle { radius: 15; color: parent.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent" }
                contentItem: Text { text: "󰅖"; color: "#f38ba8"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: Qt.quit()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 20

                Rectangle {
                    id: artContainer
                    Layout.alignment: Qt.AlignHCenter
                    width: 220; height: 220; radius: 25
                    color: Qt.rgba(1, 1, 1, 0.03)
                    clip: true // Standard rounding method
                    
                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: root.artUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        visible: root.artUrl !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰎈"
                        font.pixelSize: 80
                        color: Qt.rgba(1, 1, 1, 0.08)
                        visible: root.artUrl === ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        color: "white"; font.pixelSize: 20; font.bold: true
                        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.artist || "Unknown Artist"
                        color: "#89b4fa"; font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ProgressBar {
                        id: progress
                        Layout.fillWidth: true
                        value: root.position / root.length
                        background: Rectangle {
                            implicitHeight: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.1)
                        }
                        contentItem: Item {
                            Rectangle {
                                width: progress.visualPosition * parent.width
                                height: parent.height; color: "#89b4fa"; radius: 3
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { 
                            text: new Date(root.position * 1000).toISOString().substr(14, 5)
                            color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 11 
                        }
                        Item { Layout.fillWidth: true }
                        Text { 
                            text: new Date(root.length * 1000).toISOString().substr(14, 5)
                            color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 11 
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 25
                    
                    Button {
                        width: 50; height: 50
                        flat: true
                        background: Rectangle { 
                            radius: 25; color: parent.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05) 
                        }
                        contentItem: Text { text: "󰒮"; color: "white"; font.pixelSize: 24; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: controlProcess.send("previous")
                    }
                    
                    Button {
                        width: 70; height: 70
                        flat: true
                        background: Rectangle { 
                            radius: 35; color: "#89b4fa"
                            opacity: parent.hovered ? 0.9 : 1.0
                        }
                        contentItem: Text { 
                            text: root.status === "Playing" ? "󰏤" : "󰐊"
                            color: "#11111b"; font.pixelSize: 32; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter 
                        }
                        onClicked: controlProcess.send("play-pause")
                    }
                    
                    Button {
                        width: 50; height: 50
                        flat: true
                        background: Rectangle { 
                            radius: 25; color: parent.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05) 
                        }
                        contentItem: Text { text: "󰒭"; color: "white"; font.pixelSize: 24; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: controlProcess.send("next")
                    }
                }
            }
        }
    }
}
