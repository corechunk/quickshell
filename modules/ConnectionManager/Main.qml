import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth

// This file is a modular Quickshell module for network and bluetooth management.
// It can be launched standalone or via a script that handles positioning.
// If no position is provided via QS_MOUSE_X/Y, it will default to the top-left.

ShellRoot {
    id: root

    // Directory for resources
    property string configDir: Quickshell.env("QS_CONFIG_DIR") || "~/.config/quickshell"
    property string lockDir: "/tmp"
    property string lockFile: "quickshell-network-menu.lock"

    // Mouse coordinates or target position passed from the script
    property int targetX: Quickshell.env("QS_MOUSE_X") !== "" ? parseInt(Quickshell.env("QS_MOUSE_X")) : 0
    property int targetY: Quickshell.env("QS_MOUSE_Y") !== "" ? parseInt(Quickshell.env("QS_MOUSE_Y")) : 0
    property string launchMode: Quickshell.env("QS_LAUNCH_MODE") || "cursor"

    property var wifiNetworks: []
    property var savedConnections: []
    property bool wifiScanning: false
    property string password: ""
    property string targetSsid: ""

    // Auto-scan on startup
    Component.onCompleted: {
        root.wifiScanning = true;
        wifiRescanProcess.running = true;
        if (Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = true;
        }
    }

    // Timer for WiFi scan timeout (30 seconds)
    Timer {
        id: wifiScanTimeout
        interval: 30000
        repeat: false
        onTriggered: root.wifiScanning = false
    }

    // Timer for Bluetooth scan timeout (30 seconds)
    Timer {
        id: btScanTimeout
        interval: 30000
        repeat: false
        onTriggered: {
            if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = false
        }
    }

    // Monitor Bluetooth discovery to start/stop timeout
    Connections {
        target: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter : null
        function onDiscoveringChanged() {
            if (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering) {
                btScanTimeout.restart();
            } else {
                btScanTimeout.stop();
            }
        }
    }

    // Timer to refresh wifi list in background
    Timer {
        id: refreshTimer
        interval: 20000
        running: true
        repeat: true
        onTriggered: {
            if (!root.wifiScanning && !wifiListProcess.running) {
                wifiListProcess.running = true;
            }
        }
    }

    // Process to send notifications
    Process {
        id: notificationProcess
        function notify(title, message, icon) {
            command = ["notify-send", title, message, "-i", icon];
            running = true;
        }
    }

    // Process to check saved connections
    Process {
        id: savedConnectionsProcess
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n");
                let saved = [];
                for (let line of lines) {
                    if (line.trim() === "") continue;
                    let parts = line.split(":");
                    if (parts.length >= 2 && parts[1] === "802-11-wireless") {
                        saved.push(parts[0]);
                    }
                }
                root.savedConnections = saved;
            }
        }
    }

    // Process to list wifi networks
    Process {
        id: wifiListProcess
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,BARS,ACTIVE", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text;
                let lines = output.split("\n");
                let networks = [];
                for (let line of lines) {
                    if (line.trim() === "" || line.startsWith("--")) continue;
                    let parts = line.split(":");
                    if (parts.length < 5) continue;
                    let ssid = parts[0];
                    if (ssid === "") continue;
                    if (networks.some(n => n.ssid === ssid)) continue;
                    networks.push({
                        ssid: ssid,
                        signal: parts[1],
                        security: parts[2],
                        bars: parts[3],
                        active: parts[4].toLowerCase().includes("yes") || parts[4].includes("*")
                    });
                }
                root.wifiNetworks = networks;
                root.wifiScanning = false;
                savedConnectionsProcess.running = true;
            }
        }
    }

    // Process to rescan wifi
    Process {
        id: wifiRescanProcess
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: {
            wifiListProcess.running = true;
        }
    }

    // Process to connect to wifi
    Process {
        id: connectProcess
        property string lastSsid: ""
        function connect(ssid, pass) {
            lastSsid = ssid;
            if (pass !== "") {
                command = ["nmcli", "device", "wifi", "connect", ssid, "password", pass];
            } else {
                command = ["nmcli", "device", "wifi", "connect", ssid];
            }
            running = true;
        }
        onExited: (exitCode) => {
            if (exitCode === 0) {
                notificationProcess.notify("Wi-Fi Connected", "Successfully connected to " + lastSsid, "network-wireless");
            }
            wifiListProcess.running = true;
            root.targetSsid = "";
            root.password = "";
        }
    }

    // Process to forget connection
    Process {
        id: forgetProcess
        function forget(ssid) {
            command = ["nmcli", "connection", "delete", ssid];
            running = true;
        }
        onExited: {
            savedConnectionsProcess.running = true;
            wifiListProcess.running = true;
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
            width: 380
            height: 550

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

            color: Qt.rgba(0.07, 0.07, 0.1, 0.95)
            radius: 20
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
            clip: true

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            focus: true
            Keys.onEscapePressed: Qt.quit()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    property int activeTab: 0

                    Repeater {
                        model: ["󰖩  Wi-Fi", "󰂯  Bluetooth"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 45
                            radius: 20
                            color: parent.activeTab === index ? Qt.rgba(0.5, 0.7, 1, 0.2) : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05))
                            border.color: parent.activeTab === index ? Qt.rgba(0.5, 0.7, 1, 0.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: parent.parent.activeTab === index ? "#89b4fa" : "#cdd6f4"
                                font.pixelSize: 14
                                font.bold: parent.parent.activeTab === index
                            }
                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: parent.parent.activeTab = index
                            }
                        }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: parent.children[0].activeTab

                    // Wi-Fi Tab
                    ColumnLayout {
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Wireless Connection"; color: "white"; font.bold: true; Layout.fillWidth: true }
                            Button {
                                id: wifiScanBtn
                                text: root.wifiScanning ? "󰅖" : "󰑐"
                                flat: true
                                contentItem: Text {
                                    text: wifiScanBtn.text
                                    color: root.wifiScanning ? "#f38ba8" : "#89b4fa"
                                    font.pixelSize: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    if (root.wifiScanning) {
                                        root.wifiScanning = false;
                                        wifiScanTimeout.stop();
                                    } else {
                                        root.wifiScanning = true;
                                        wifiRescanProcess.running = true;
                                        wifiScanTimeout.restart();
                                    }
                                }
                            }
                        }

                        ListView {
                            id: wifiView
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8
                            model: root.wifiNetworks
                            delegate: ColumnLayout {
                                width: wifiView.width; spacing: 5
                                property bool isSaved: root.savedConnections.indexOf(modelData.ssid) !== -1
                                Rectangle {
                                    id: wifiItem
                                    Layout.fillWidth: true; height: 60; radius: 20
                                    color: modelData.active ? Qt.rgba(0.5, 0.7, 1, 0.2) : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 12; spacing: 10
                                        Text { text: modelData.bars; font.pixelSize: 18; color: "#89b4fa" }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Text { text: modelData.ssid; color: "white"; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: (isSaved ? "Saved • " : "") + modelData.security; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10 }
                                        }
                                        RowLayout {
                                            Layout.alignment: Qt.AlignRight; spacing: 8
                                            Button {
                                                visible: isSaved && !modelData.active
                                                flat: true; Layout.preferredWidth: 30
                                                contentItem: Text { text: "󰆴"; color: "#f38ba8"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter }
                                                onClicked: forgetProcess.forget(modelData.ssid)
                                            }
                                            Button {
                                                text: modelData.active ? "Connected" : (isSaved ? "Connect" : "Join")
                                                enabled: !modelData.active
                                                onClicked: {
                                                    if (isSaved || !modelData.security.includes("WPA")) {
                                                        connectProcess.connect(modelData.ssid, "")
                                                    } else {
                                                        root.targetSsid = modelData.ssid
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: itemMouse; anchors.fill: parent; hoverEnabled: true
                                        onClicked: {
                                            if (!modelData.active) {
                                                if (isSaved || !modelData.security.includes("WPA")) {
                                                    connectProcess.connect(modelData.ssid, "")
                                                } else {
                                                    root.targetSsid = modelData.ssid
                                                }
                                            }
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; height: 50; radius: 20; color: Qt.rgba(1, 1, 1, 0.1); visible: root.targetSsid === modelData.ssid
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 10
                                        TextField {
                                            id: passField; Layout.fillWidth: true; placeholderText: "Password..."
                                            echoMode: TextInput.Password; color: "white"; background: null
                                            onTextChanged: root.password = text
                                            onVisibleChanged: if (visible) forceActiveFocus()
                                        }
                                        Button { text: "Join"; onClicked: connectProcess.connect(modelData.ssid, root.password) }
                                        Button { text: "󰅖"; flat: true; onClicked: root.targetSsid = "" }
                                    }
                                }
                            }
                        }
                    }

                    // Bluetooth Tab
                    ColumnLayout {
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Bluetooth Devices"; color: "white"; font.bold: true; Layout.fillWidth: true }
                            Button {
                                id: btScanBtn
                                text: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering) ? "󰅖" : "󰑐"
                                flat: true
                                contentItem: Text {
                                    text: btScanBtn.text
                                    color: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering) ? "#f38ba8" : "#89b4fa"
                                    font.pixelSize: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering
                            }
                            Switch {
                                id: btSwitch
                                checked: !!(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
                                onToggled: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = checked
                                indicator: Rectangle {
                                    implicitWidth: 44; implicitHeight: 24; x: btSwitch.leftPadding; y: parent.height / 2 - height / 2; radius: 12
                                    color: btSwitch.checked ? "#89b4fa" : "#313244"; border.color: btSwitch.checked ? "#89b4fa" : "#45475a"
                                    Rectangle {
                                        x: btSwitch.checked ? parent.width - width - 2 : 2; y: 2; width: 20; height: 20; radius: 10; color: "white"
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                        }

                        ListView {
                            id: btView; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8
                            model: Bluetooth.devices
                            delegate: Rectangle {
                                id: btItem; width: btView.width; height: 60; radius: 20
                                color: modelData.connected ? Qt.rgba(0.5, 1, 0.7, 0.15) : (btItemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
                                Behavior on color { ColorAnimation { duration: 150 } }
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 10
                                    Text { text: "󰂯"; font.pixelSize: 18; color: modelData.connected ? "#a6e3a1" : "#cdd6f4" }
                                    
                                    Connections {
                                        target: modelData
                                        function onConnectedChanged() {
                                            if (modelData.connected) {
                                                notificationProcess.notify("Bluetooth Connected", "Successfully connected to " + (modelData.name || "Unknown Device"), "bluetooth");
                                            } else {
                                                notificationProcess.notify("Bluetooth Disconnected", "Disconnected from " + (modelData.name || "Unknown Device"), "bluetooth");
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { text: modelData.name || "Unknown Device"; color: "white"; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text { text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available"); color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10 }
                                    }
                                    Button {
                                        text: modelData.connected ? "Disconnect" : "Connect"
                                        Layout.alignment: Qt.AlignRight
                                        onClicked: if (modelData.connected) modelData.disconnect(); else modelData.connect()
                                    }
                                }
                                MouseArea {
                                    id: btItemMouse; anchors.fill: parent; hoverEnabled: true
                                    onClicked: if (modelData.connected) modelData.disconnect(); else modelData.connect()
                                }
                            }
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true; height: 45; flat: true
                    contentItem: Text { text: "Close Menu"; color: "#f38ba8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true }
                    background: Rectangle { color: Qt.rgba(1, 0.5, 0.5, 0.05); radius: 20 }
                    onClicked: Qt.quit()
                }
            }
        }
    }

    /**
     * plan bin:
     * We considered using process name matching (pgrep/rg) to prevent duplicates,
     * but decided on a lock-file (/tmp/QuickshellConnectionManager.lock) as it's more 
     * robust for shell-launched scripts and avoids potential regex errors.
     */
}
