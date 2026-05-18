import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "../../core/theme" as CoreTheme
import "../../core/utils" as CoreUtils
import "./services"
import "./components"

ShellRoot {
    Variants {
        model: [Quickshell.screens]

        delegate: PanelWindow {
            id: window
            property var currentScreen: modelData
            property var modelData: null
            
            // Helpful aliases for the children to access singletons safely
            property var theme: CoreTheme.Theme
            property var settings: CoreUtils.SystemSettings

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.namespace: "command-palette"

            Component {
                id: processComponent
                Process {}
            }

            function executeCommand(cmd) {
                if (!cmd) return;
                console.log("CommandPalette: Executing " + cmd);
                
                // Detach from the palette using hyprctl so the app stays alive 
                // after we call Qt.quit().
                let detachedCmd = "hyprctl dispatch exec \"" + cmd + "\"";
                
                try {
                    let proc = processComponent.createObject(window, {
                        "command": ["bash", "-c", detachedCmd]
                    });
                    proc.running = true;
                    container.state = "inactive";
                } catch(e) {
                    console.error("CommandPalette: Failed to launch process: " + e);
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: container.state === "active" ? 0.6 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: container.state = "inactive" 
                }
            }

            Rectangle {
                id: container
                anchors.horizontalCenter: parent.horizontalCenter
                
                // Dynamic width and height
                width: window.width * 0.55
                height: {
                    if (!resultsView || resultsView.count === 0) return 180;
                    let listHeight = (resultsView.count * 64) + ((resultsView.count - 1) * 12);
                    let totalHeight = listHeight + 210;
                    // Max height is screen height - start_y - bottom_margin
                    let maxHeight = (window.height * 0.85) - 40;
                    return Math.min(maxHeight, totalHeight);
                }
                
                y: parent.height; opacity: 0; state: "inactive"
                
                color: theme.bgDark || "#0a0a0f" 
                radius: 24
                border.width: 2
                border.color: theme.accent || "#89b4fa"
                
                layer.enabled: true
                
                Behavior on height { 
                    NumberAnimation { 
                        duration: 300
                        easing.type: Easing.OutBack
                        easing.amplitude: 0.1
                    } 
                }

                // Internal MouseArea to stop clicks inside the container from closing it
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: (mouse) => mouse.accepted = true
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 25
                    spacing: 20

                    // 1. Search Bar
                    Rectangle {
                        Layout.fillWidth: true; height: 70
                        color: theme.surface || Qt.rgba(1,1,1,0.05)
                        radius: 16
                        border.width: 2
                        border.color: searchInput.activeFocus ? (theme.accent || "#89b4fa") : (theme.border || "#2a2a37")

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 5
                            Text { 
                                text: "󰍉"
                                color: theme.accent || "#89b4fa"
                                font.pixelSize: 28; Layout.leftMargin: 20 
                            }

                            TextField {
                                id: searchInput
                                Layout.fillWidth: true; height: 50
                                placeholderText: "Search apps or use prefixes (>, |, !)..."
                                placeholderTextColor: Qt.rgba(theme.fg ? theme.fg.r : 1, theme.fg ? theme.fg.g : 1, theme.fg ? theme.fg.b : 1, 0.3)
                                color: theme.fg || "#cdd6f4"
                                font.pixelSize: 22
                                background: null
                                focus: true
                                
                                onTextChanged: {
                                    try { SearchService.query(text) } catch(e) {}
                                }
                                
                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Down) {
                                        resultsView.currentIndex = (resultsView.currentIndex + 1) % resultsView.count;
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Up) {
                                        resultsView.currentIndex = (resultsView.currentIndex - 1 + resultsView.count) % resultsView.count;
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Right && (event.modifiers & Qt.ControlModifier)) {
                                        let modes = ["apps", "actions", "math"];
                                        let idx = (modes.indexOf(SearchService.mode) + 1) % 3;
                                        if (modes[idx] === "math") text = "|";
                                        else if (modes[idx] === "actions") text = ">";
                                        else text = "";
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Left && (event.modifiers & Qt.ControlModifier)) {
                                        let modes = ["apps", "actions", "math"];
                                        let idx = (modes.indexOf(SearchService.mode) - 1 + 3) % 3;
                                        if (modes[idx] === "math") text = "|";
                                        else if (modes[idx] === "actions") text = ">";
                                        else text = "";
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Return) {
                                        try {
                                            let currentResults = SearchService.currentResults;
                                            if (currentResults && currentResults.length > resultsView.currentIndex) {
                                                executeCommand(currentResults[resultsView.currentIndex].cmd);
                                            }
                                        } catch(e) { console.error("Execution failed: " + e) }
                                        event.accepted = true;
                                    }
                                }
                                Keys.onEscapePressed: container.state = "inactive"
                            }
                        }
                    }

                    // 2. Mode Indicators (Always Visible)
                    RowLayout {
                        Layout.fillWidth: true; Layout.leftMargin: 10
                        spacing: 20
                        
                        Repeater {
                            model: [
                                { "id": "apps", "name": "APPS", "icon": "󰀻" },
                                { "id": "actions", "name": "ACTIONS", "icon": "󱎫" },
                                { "id": "math", "name": "CALC", "icon": "󰪚" }
                            ]
                            delegate: Item {
                                Layout.preferredWidth: 110; Layout.preferredHeight: 40
                                property bool isActive: SearchService.mode === modelData.id
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: isActive ? (theme.highlight || Qt.rgba(1,1,1,0.15)) : (modeMouse.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent")
                                    border.color: isActive ? (theme.accent || "#89b4fa") : "transparent"
                                    border.width: isActive ? 2 : 0
                                    
                                    scale: isActive ? 1.05 : (modeMouse.containsMouse ? 1.02 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 200 } }
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 10
                                    Text { 
                                        text: modelData.icon
                                        color: isActive ? (theme.accent || "#89b4fa") : (theme.fg || "#cdd6f4")
                                        opacity: isActive ? 1.0 : 0.4
                                        font.pixelSize: 18 
                                    }
                                    Text { 
                                        text: modelData.name
                                        color: theme.fg || "#cdd6f4"
                                        opacity: isActive ? 1.0 : 0.4
                                        font.pixelSize: 12
                                        font.bold: isActive
                                        font.letterSpacing: 1
                                    }
                                }
                                MouseArea {
                                    id: modeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (modelData.id === "math") searchInput.text = "|";
                                        else if (modelData.id === "actions") searchInput.text = ">";
                                        else searchInput.text = "";
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    // 3. Results List
                    ListView {
                        id: resultsView
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: false
                        model: {
                            try { return SearchService.currentResults } catch(e) { return [] }
                        }
                        spacing: 12
                        delegate: ResultItem { 
                            width: resultsView.width
                            theme: window.theme
                            title: modelData.title || ""
                            type: modelData.type || "Item"
                            icon: modelData.icon || ""
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: executeCommand(modelData.cmd)
                            }
                        }
                    }
                }

                states: [
                    State {
                        name: "active"
                        PropertyChanges { target: container; y: window.height * 0.15 }
                        PropertyChanges { target: container; opacity: 1 }
                    },
                    State {
                        name: "inactive"
                        PropertyChanges { target: container; y: window.height }
                        PropertyChanges { target: container; opacity: 0 }
                    }
                ]

                transitions: [
                    Transition {
                        from: "inactive"; to: "active"
                        ParallelAnimation {
                            NumberAnimation { properties: "y,width"; duration: 600; easing.type: Easing.OutExpo }
                            NumberAnimation { property: "opacity"; duration: 300 }
                        }
                    },
                    Transition {
                        from: "active"; to: "inactive"
                        SequentialAnimation {
                            ParallelAnimation {
                                NumberAnimation { properties: "y,width"; duration: 400; easing.type: Easing.InBack; easing.amplitude: 0.5 }
                                NumberAnimation { property: "opacity"; duration: 250 }
                            }
                            ScriptAction { script: Qt.quit() }
                        }
                    }
                ]
                
                Timer {
                    interval: 50; running: true; repeat: false
                    onTriggered: { container.state = "active"; searchInput.forceActiveFocus() }
                }
            }
        }
    }
}
