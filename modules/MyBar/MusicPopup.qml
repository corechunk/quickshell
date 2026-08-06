import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

PanelWindow {
    id: popupWindow
    visible: true
    color: "transparent"

    // Positioning: Top Right
    anchors {
        top: true
        right: true
    }

    width: 500
    height: 160

    // Internal Properties
    property string currentArt: ""
    property string currentTitle: ""
    property string currentArtist: ""
    property bool isListening: false
    property bool showError: false
    property bool isAudioActive: false
    property bool isPreviewPlaying: false
    property var cavaHeights: [2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2]
    property var artTimestamp: 0
    property int dotStep: 0
    property int phraseIndex: 0
    property var listeningPhrases: isAudioActive ? ["Listening", "Working on it"] : ["Listening", "Working on it", "Still trying"]

    Timer {
        id: dotTimer
        interval: 450
        repeat: true
        running: isListening
        onTriggered: {
            dotStep = (dotStep + 1) % 4
        }
        onRunningChanged: {
            if (!running) dotStep = 0
        }
    }

    Timer {
        id: phraseTimer
        interval: 4500
        repeat: true
        running: isListening
        onTriggered: {
            phraseFadeAnim.start()
        }
        onRunningChanged: {
            if (!running) phraseIndex = 0
        }
    }

    SequentialAnimation {
        id: phraseFadeAnim
        NumberAnimation { target: phraseRow; property: "opacity"; to: 0; duration: 250; easing.type: Easing.InOutQuad }
        ScriptAction { script: phraseIndex = (phraseIndex + 1) % listeningPhrases.length }
        NumberAnimation { target: phraseRow; property: "opacity"; to: 1; duration: 250; easing.type: Easing.InOutQuad }
    }

    Timer {
        id: resetTimer
        interval: 30000
        onTriggered: {
            stopPreviewProcess.running = true
            container.state = "idle"
        }
    }

    Rectangle {
        id: container
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.rightMargin: 10
        
        color: "#181825"
        border.color: recognizeProcess.running ? "#f9e2af" : (container.state === "success" ? "#40ffffff" : "#313244")
        border.width: container.state === "success" ? 1.5 : 1
        clip: true
        
        width: 48
        height: 32
        radius: 8
        
        state: "idle"

        // Full Blurred Album Art Backdrop (Masked to container.radius)
        Image {
            id: bgArtRaw
            anchors.fill: parent
            source: (container.state === "success" && currentArt !== "") ? "file://" + currentArt + "?t=" + artTimestamp : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        FastBlur {
            id: bgArtBlur
            anchors.fill: parent
            source: bgArtRaw
            radius: 40
            visible: false
            cached: true
        }

        Rectangle {
            id: blurMaskRect
            anchors.fill: parent
            radius: container.radius
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: bgArtBlur
            maskSource: blurMaskRect
            opacity: container.state === "success" ? 0.45 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 500 } }
        }

        // Semi-transparent dark tint overlay over blurred background
        Rectangle {
            anchors.fill: parent
            radius: container.radius
            color: "#11111b"
            opacity: container.state === "success" ? 0.65 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 500 } }
        }

        // Inner Translucent Glass Border Highlight
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: container.radius - 1
            color: "transparent"
            border.color: "#25ffffff"
            border.width: 1
            visible: container.state === "success"
        }
        
        Behavior on width {
            NumberAnimation { duration: 400; easing.type: Easing.OutBack }
        }
        Behavior on height {
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
        }
        Behavior on radius {
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }

        states: [
            State {
                name: "idle"
                PropertyChanges { target: container; width: 56; height: 36; radius: 10 }
                PropertyChanges { target: artArea; Layout.preferredWidth: 56; Layout.preferredHeight: 36; radius: 10; color: "transparent" }
                PropertyChanges { target: artLoader; opacity: 0; visible: false }
                PropertyChanges { target: infoCol; opacity: 0; visible: false }
                PropertyChanges { target: iconLabel; opacity: 1; visible: true; text: "󰎈"; color: "#89b4fa"; font.pixelSize: 24 }
                PropertyChanges { target: resetTimer; running: false }
            },
            State {
                name: "listening"
                PropertyChanges { target: container; width: 300; height: 96; radius: 18 }
                PropertyChanges { target: artArea; Layout.preferredWidth: 0; Layout.preferredHeight: 0; visible: false }
                PropertyChanges { target: infoCol; opacity: 1; visible: true }
                PropertyChanges { target: artLoader; opacity: 0; visible: false }
                PropertyChanges { target: iconLabel; opacity: 0; visible: false }
                PropertyChanges { target: resetTimer; running: false }
            },
            State {
                name: "success"
                PropertyChanges { target: container; width: 460; height: 116; radius: 20 }
                PropertyChanges { target: artArea; Layout.preferredWidth: 88; Layout.preferredHeight: 88; radius: 16; color: "#11111b" }
                PropertyChanges { target: artLoader; opacity: currentArt !== "" ? 1 : 0; visible: currentArt !== "" }
                PropertyChanges { target: infoCol; opacity: 1; visible: true }
                PropertyChanges { target: iconLabel; opacity: 0; visible: false }
                PropertyChanges { target: resetTimer; running: true }
            },
            State {
                name: "error"
                PropertyChanges { target: container; width: 260; height: 72; radius: 14 }
                PropertyChanges { target: artArea; Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 21; color: "#2a1e24" }
                PropertyChanges { target: infoCol; opacity: 1; visible: true }
                PropertyChanges { target: artLoader; opacity: 0; visible: false }
                PropertyChanges { target: iconLabel; opacity: 1; visible: true; text: "󰑐"; color: "#f38ba8"; font.pixelSize: 22 }
                PropertyChanges { target: resetTimer; running: true }
            }
        ]

        // Breathing border animation for error state
        SequentialAnimation on border.color {
            running: container.state === "error"
            loops: Animation.Infinite
            ColorAnimation { to: "#f38ba8"; duration: 800; easing.type: Easing.InOutQuad }
            ColorAnimation { to: "#452731"; duration: 800; easing.type: Easing.InOutQuad }
        }

        // Listening Equalizer Bars (Anchored on right side with extra right padding, centered vertically - 12 Bars)
        Row {
            id: listeningBars
            anchors.verticalCenter: container.verticalCenter
            anchors.right: container.right
            anchors.rightMargin: 28
            spacing: 3
            visible: isListening && !isPreviewPlaying
            z: 5

            Repeater {
                model: 12
                Rectangle {
                    width: 4
                    height: 8
                    radius: 2
                    color: "#f9e2af"
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on height {
                        loops: Animation.Infinite
                        running: isListening && !isPreviewPlaying
                        PropertyAnimation { to: 4; duration: 400 + (index % 5) * 85; easing.type: Easing.InOutQuad }
                        PropertyAnimation { to: 18; duration: 400 + (index % 5) * 85; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }

        // CAVA Real-Time Audio Visualizer Bars (Placed behind artwork at z:1, slim 3px bars with 3px spacing)
        Row {
            id: cavaPreviewBars
            anchors.bottom: container.bottom
            anchors.bottomMargin: 0
            anchors.horizontalCenter: container.horizontalCenter
            spacing: 3
            visible: isPreviewPlaying
            z: 1

            Repeater {
                model: 32
                Rectangle {
                    width: 10
                    height: cavaHeights[index] !== undefined ? cavaHeights[index] : 2
                    radius: 0
                    color: "#89b4fa"
                    anchors.bottom: parent.bottom

                    Behavior on height {
                        enabled: isPreviewPlaying
                        NumberAnimation { duration: 45; easing.type: Easing.OutQuad }
                    }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: container.state === "idle" ? 0 : (container.state === "listening" ? 18 : 18)
            anchors.rightMargin: container.state === "idle" ? 0 : 18
            spacing: 14
            z: 15
            
            Rectangle {
                id: artArea
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: "#11111b"
                border.color: container.state === "success" ? "#33ffffff" : "transparent"
                border.width: 1
                clip: true

                // Floating Soft Drop-Shadow behind Album Art
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: artArea.radius + 2
                    color: "#000000"
                    opacity: container.state === "success" ? 0.35 : 0
                    z: -1

                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }

                Behavior on Layout.preferredWidth { NumberAnimation { duration: 300 } }
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 300 } }
                Behavior on radius { NumberAnimation { duration: 300 } }

                Text {
                    id: iconLabel
                    anchors.centerIn: parent
                    text: "󰎈"
                    color: "#89b4fa"
                    font.pixelSize: 22
                    visible: container.state === "idle" || container.state === "error"
                    rotation: (container.state === "error" && retryClickArea.containsMouse) ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }

                Image {
                    id: artLoader
                    anchors.fill: parent
                    source: currentArt !== "" ? "file://" + currentArt + "?t=" + artTimestamp : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: 0
                    visible: false

                    onStatusChanged: {
                        if (artLoader.status === Image.Error) {
                            currentArt = ""
                        }
                    }
                }
                MouseArea {
                    id: retryClickArea
                    anchors.fill: parent
                    z: 10
                    enabled: container.state === "error"
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true

                    onClicked: {
                        if (container.state === "error") {
                            container.state = "listening"
                            isListening = true
                            currentTitle = ""
                            currentArtist = ""
                            currentArt = ""
                            showError = false
                            listenTimeoutTimer.restart()
                            checkAudioProcess.running = true
                            recognizeProcess.running = true
                        }
                    }
                }
            }

            ColumnLayout {
                id: infoCol
                Layout.fillWidth: true
                spacing: 2
                opacity: 0
                visible: false

                // Title Section (With Marquee support for song matches & Per-character glow for Listening)
                Item {
                    id: titleContainer
                    Layout.fillWidth: true
                    implicitHeight: songTitle.implicitHeight
                    clip: true

                    // Normal Song Title (Shown on error or match)
                    Text {
                        id: songTitle
                        text: showError ? "No song found." : currentTitle
                        color: showError ? "#f38ba8" : "#cdd6f4"
                        font.bold: true
                        font.pixelSize: 17
                        visible: !isListening && container.state !== "success"
                    }

                    // Character-by-Character Single Pass Glowing Text (Shown on success match)
                    Item {
                        id: titleGlowContainer
                        visible: !isListening && container.state === "success"
                        width: parent.width
                        height: songTitle.implicitHeight
                        clip: true

                        property real overflowWidth: titleGlowRow.implicitWidth - titleGlowContainer.width

                        onVisibleChanged: {
                            if (visible) {
                                glowTrigger++
                            }
                        }

                        SequentialAnimation on x {
                            running: container.state === "success" && titleGlowContainer.overflowWidth > 0
                            loops: Animation.Infinite
                            PauseAnimation { duration: 1800 }
                            NumberAnimation { to: -titleGlowContainer.overflowWidth - 8; duration: Math.max(2000, titleGlowContainer.overflowWidth * 30); easing.type: Easing.InOutQuad }
                            PauseAnimation { duration: 1200 }
                            NumberAnimation { to: 0; duration: 800; easing.type: Easing.InOutQuad }
                        }

                        property int glowTrigger: 0

                        Row {
                            id: titleGlowRow
                            spacing: 0
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                id: titleCharRepeater
                                model: currentTitle.split("")
                                Text {
                                    id: charItem
                                    text: modelData
                                    font.bold: true
                                    font.pixelSize: 17
                                    color: "#cdd6f4"

                                    SequentialAnimation {
                                        id: charGlowAnim
                                        running: false
                                        PauseAnimation { duration: Math.pow(index / Math.max(1, titleCharRepeater.count - 1), 1.5) * 650 }
                                        ColorAnimation { target: charItem; property: "color"; to: "#ffffff"; duration: 220; easing.type: Easing.OutQuad }
                                        ColorAnimation { target: charItem; property: "color"; to: "#cdd6f4"; duration: 450; easing.type: Easing.OutSine }
                                    }

                                    Connections {
                                        target: titleGlowContainer
                                        function onGlowTriggerChanged() {
                                            charItem.color = "#8087a2"
                                            charGlowAnim.restart()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Per-character Glowing Text (Dynamic Phrase + dynamic dots with smooth crossfade)
                    Row {
                        id: phraseRow
                        visible: isListening
                        spacing: 0
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: 1

                        Behavior on opacity {
                            NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
                        }

                        Repeater {
                            model: listeningPhrases[phraseIndex].split("")
                            Text {
                                text: modelData
                                font.bold: true
                                font.pixelSize: 16
                                color: modelData === " " ? "transparent" : "#8087a2"

                                SequentialAnimation on color {
                                    running: isListening && phraseRow.opacity === 1
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: index * 90 }
                                    ColorAnimation { to: "#ffffff"; duration: 250 }
                                    ColorAnimation { to: "#8087a2"; duration: 350 }
                                    PauseAnimation { duration: Math.max(0, (14 - index) * 90 + 300) }
                                }
                            }
                        }

                        // Animated Dots . .. ...
                        Text {
                            text: ".".repeat(dotStep)
                            font.bold: true
                            font.pixelSize: 16
                            color: "#ffffff"
                        }
                    }
                }

                // Option B: Subtitle Section with Artist Icon Badge & Color Hierarchy
                Item {
                    id: artistContainer
                    Layout.fillWidth: true
                    implicitHeight: artistRow.implicitHeight
                    clip: true
                    visible: !showError

                    RowLayout {
                        id: artistRow
                        spacing: 6
                        width: parent.width

                        Text {
                            text: "󰠃"
                            color: "#74c7ec"
                            font.pixelSize: 14
                            visible: container.state === "success"
                        }

                        Text {
                            id: artistName
                            text: isListening ? "Recording audio" : (showError ? "" : currentArtist)
                            color: container.state === "success" ? "#74c7ec" : (showError ? "#f38ba8" : "#a6adc8")
                            font.pixelSize: container.state === "success" ? 14 : 13
                            font.weight: container.state === "success" ? Font.Medium : Font.Normal
                            horizontalAlignment: Text.AlignLeft
                            Layout.fillWidth: true

                            property real overflowWidth: artistName.implicitWidth - artistContainer.width

                            SequentialAnimation on x {
                                running: container.state === "success" && artistName.overflowWidth > 0
                                loops: Animation.Infinite
                                PauseAnimation { duration: 2000 }
                                NumberAnimation { to: -artistName.overflowWidth - 8; duration: Math.max(2000, artistName.overflowWidth * 35); easing.type: Easing.InOutQuad }
                                PauseAnimation { duration: 1200 }
                                NumberAnimation { to: 0; duration: 800; easing.type: Easing.InOutQuad }
                            }
                        }
                        Row {
                            spacing: 10
                            visible: container.state === "success" && currentTitle !== ""
                            Layout.alignment: Qt.AlignRight

                            // 30-Second Audio Preview Play/Pause Button
                            Text {
                                text: isPreviewPlaying ? "󰏤" : "󰐊"
                                color: playBtnHover.containsMouse ? "#f9e2af" : "#a6adc8"
                                font.pixelSize: 18
                                scale: playBtnHover.pressed ? 0.85 : (playBtnHover.containsMouse ? 1.2 : 1.0)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                MouseArea {
                                    id: playBtnHover
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    z: 20
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        playPreviewProcess.play(currentTitle, currentArtist)
                                    }
                                }
                            }

                            Text {
                                text: "󰓇"
                                color: spotHover.containsMouse ? "#1db954" : "#a6adc8"
                                font.pixelSize: 18
                                scale: spotHover.pressed ? 0.85 : (spotHover.containsMouse ? 1.2 : 1.0)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                MouseArea {
                                    id: spotHover
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    z: 20
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        let query = encodeURIComponent(currentTitle + " " + currentArtist)
                                        openUrlProcess.command = ["xdg-open", "https://open.spotify.com/search/" + query]
                                        openUrlProcess.running = true
                                    }
                                }
                            }

                            Text {
                                text: "󰗃"
                                color: ytHover.containsMouse ? "#ff0000" : "#a6adc8"
                                font.pixelSize: 18
                                scale: ytHover.pressed ? 0.85 : (ytHover.containsMouse ? 1.2 : 1.0)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                MouseArea {
                                    id: ytHover
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    z: 20
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        let query = encodeURIComponent(currentTitle + " " + currentArtist)
                                        openUrlProcess.command = ["xdg-open", "https://music.youtube.com/search?q=" + query]
                                        openUrlProcess.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Process to open external URLs
        Process {
            id: openUrlProcess
        }

        // Process to check if audio stream is active (playing music)
        Process {
            id: checkAudioProcess
            command: ["sh", "-c", "pactl list sink-inputs | grep -i 'corked' | grep -vq 'true'"]

            onExited: (code, status) => {
                isAudioActive = (code === 0)
            }
        }

        MouseArea {
            id: clickArea
            anchors.fill: parent
            enabled: container.state === "idle" || container.state === "listening"
            cursorShape: container.state === "idle" ? Qt.PointingHandCursor : Qt.ArrowCursor
            hoverEnabled: true

            onClicked: {
                if (container.state === "idle") {
                    container.state = "listening"
                    isListening = true
                    currentTitle = ""
                    currentArtist = ""
                    currentArt = ""
                    showError = false
                    listenTimeoutTimer.restart()
                    checkAudioProcess.running = true
                    recognizeProcess.running = true
                } else if (container.state === "listening" && recognizeProcess.running) {
                    recognizeProcess.running = false
                    isListening = false
                    listenTimeoutTimer.stop()
                    container.state = "idle"
                }
            }
        }

        Timer {
            id: listenTimeoutTimer
            interval: 16000
            onTriggered: {
                if (isListening && recognizeProcess.running) {
                    recognizeProcess.running = false
                    isListening = false
                    showError = true
                    container.state = "error"
                }
            }
        }

        // Song Recognition Process (Single Pass JSON Output)
        Process {
            id: recognizeProcess
            command: ["sh", "-c", "songrec recognize --json"]

            stdout: SplitParser {
                onRead: data => {
                    let cleanData = data.trim()
                    if (cleanData.length > 0) {
                        try {
                            let json = JSON.parse(cleanData)
                            if (json.track) {
                                currentTitle = json.track.title || "Unknown"
                                currentArtist = json.track.subtitle || "Unknown"
                                
                                let imgUrl = json.track.images ? json.track.images.coverart : ""
                                if (imgUrl !== "") {
                                    downloadArtProcess.imgUrl = imgUrl
                                    downloadArtProcess.running = true
                                } else {
                                    isListening = false
                                    container.state = "success"
                                }
                            } else {
                                isListening = false
                                showError = true
                                container.state = "error"
                            }
                        } catch (e) {
                            console.log("JSON Parse Error: " + e)
                            isListening = false
                            showError = true
                            container.state = "error"
                        }
                        recognizeProcess.running = false
                    }
                }
            }

            onExited: (code, status) => {
                listenTimeoutTimer.stop()
                if (isListening && currentTitle === "") {
                    isListening = false
                    showError = true
                    container.state = "error"
                }
            }
        }

        // Artwork Downloader
        Process {
            id: downloadArtProcess
            property string imgUrl: ""
            command: ["sh", "-c", "curl -s \"" + imgUrl + "\" -o /tmp/cover.jpg"]
            
            onExited: (code, status) => {
                artTimestamp = Date.now()
                currentArt = "/tmp/cover.jpg"
                isListening = false
                isPreviewPlaying = false
                container.state = "success"
            }
        }

        // 30-Second Audio Preview Player Process (Deezer MP3 API)
        Process {
            id: playPreviewProcess

            function play(title, artist) {
                if (isPreviewPlaying) {
                    stopPreviewProcess.running = true
                    isPreviewPlaying = false
                    return
                }
                
                let cleanTerm = (title + " " + artist).replace(/[^a-zA-Z0-9 ]/g, " ")
                let term = encodeURIComponent(cleanTerm)
                let script = "URL=$(curl -sL \"https://api.deezer.com/search?q=" + term + "\" | jq -r '.data[0].preview // empty'); if [ -n \"$URL\" ]; then mpv --no-video --really-quiet --length=30 \"$URL\"; fi"
                command = ["bash", "-c", script]
                isPreviewPlaying = true
                running = true
            }

            onExited: (code, status) => {
                isPreviewPlaying = false
            }
        }

        // Cava Real-Time Audio Visualizer Process (32 Bars, Max Height 48px)
        Process {
            id: cavaProcess
            running: isPreviewPlaying
            command: ["sh", "-c", "printf '[general]\\nbars = 32\\nframerate = 60\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 48\\nbar_delimiter = 59\\n' | cava -p /dev/stdin"]

            stdout: SplitParser {
                onRead: data => {
                    let parts = data.trim().split(";")
                    if (parts.length >= 32) {
                        let newHeights = []
                        for (let i = 0; i < 32; i++) {
                            let val = parseInt(parts[i])
                            newHeights.push(isNaN(val) ? 2 : Math.max(2, val))
                        }
                        cavaHeights = newHeights
                    }
                }
            }
        }

        // Helper process to stop preview audio
        Process {
            id: stopPreviewProcess
            command: ["sh", "-c", "pkill -f 'mpv' || true"]
            onExited: {
                isPreviewPlaying = false
            }
        }
    }
}