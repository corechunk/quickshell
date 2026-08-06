import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Qt5Compat.GraphicalEffects

PanelWindow {
    // Dynamically resolve paths so it works for any user
    property string daemonScript: Qt.resolvedUrl("../scripts/gc_daemon.py").toString().replace("file://", "")
    property string pythonBin: Qt.resolvedUrl("../scripts/venv/bin/python3").toString().replace("file://", "")
    
    id: classroomWindow
    visible: true
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
    }

    width: 480

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool isOpen: true
    property string activeCourseId: "all"
    property bool _firstLoad: true
    property var expandedIds: ({})
    property bool isSyncing: false
    property bool sidebarVisible: true
    property int  sidebarWidth:   180
    property string lastSeenTime: ""
    property var bookmarkedIds: ({})
    property var pinnedCourseIds: ({})
    property string feedFilter: "all"
    property bool sidebarCustomizing: false

    // Format ISO date "2026-07-24T14:01:50Z" -> "24-07-2026"
    function formatDate(iso) {
        if (!iso) return ""
        let parts = iso.split("T")[0].split("-")
        if (parts.length !== 3) return iso.split("T")[0]
        return parts[2] + "-" + parts[1] + "-" + parts[0]
    }

    // Persist last-seen timestamp on close
    onIsOpenChanged: {
        if (!isOpen) {
            let now = new Date().toISOString()
            writeLastSeen.command = ["sh", "-c",
                "echo '" + now + "' > /tmp/classroom_last_seen"]
            writeLastSeen.running = true
        }
    }

    Process {
        id: writeLastSeen
        command: ["sh", "-c", ""]
    }

    // Read last-seen timestamp on startup
    Process {
        id: readLastSeen
        running: true
        command: ["cat", "/tmp/classroom_last_seen"]
        stdout: SplitParser {
            onRead: data => { lastSeenTime = data.trim() }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: isOpen
        onActivated: isOpen = false
    }

    // ── Data: read JSON via cat process (accumulate full output) ───────────
    property string _jsonBuf: ""

    Process {
        id: catProcess
        command: ["cat", "/tmp/google_classroom_data.json"]
        stdout: SplitParser {
            splitMarker: ""  // empty = read entire stdout as one chunk
            onRead: data => {
                _jsonBuf += data
            }
        }
        onExited: {
            reloadData(_jsonBuf)
            _jsonBuf = ""
            isSyncing = false  // spinner stops here — after data is fully loaded
        }
    }

    Timer {
        id: pollTimer
        interval: 30000
        running: true
        repeat: true
        onTriggered: { _jsonBuf = ""; catProcess.running = true }
    }

    // Kick off a fresh sync via daemon on startup, then read the file
    Process {
        id: syncProcess
        command: [ pythonBin, daemonScript ]
        onExited: { _jsonBuf = ""; catProcess.running = true }
    }

    function triggerRefresh() {
        if (isSyncing) return
        isSyncing = true
        syncProcess.running = true
    }

    Component.onCompleted: {
        // Silent startup sync — no spinner
        Qt.callLater(() => { _jsonBuf = ""; catProcess.running = true })
        syncProcess.running = true
    }

    // ── Models ───────────────────────────────────────────────────────────────
    ListModel { id: courseModel }
    ListModel { id: assignmentModel }
    ListModel { id: announcementModel }
    // In-memory store of all fetched announcements (pre-filter)
    property var _allAnns: []

    // ── Bookmarks persistence ─────────────────────────────────────────────────
    Process {
        id: readBookmarks
        running: true
        command: ["cat", "/tmp/classroom_bookmarks.json"]
        property string _buf: ""
        stdout: SplitParser {
            onRead: data => readBookmarks._buf += data
        }
        onExited: {
            try {
                let b = JSON.parse(readBookmarks._buf.trim())
                bookmarkedIds = b || {}
            } catch(e) { bookmarkedIds = {} }
        }
    }

    function saveBookmarks() {
        let json = JSON.stringify(bookmarkedIds)
        // Use python3 to write safely — avoids shell quoting issues with JSON
        writeBookmarks.command = [
            "python3", "-c",
            "import sys; open('/tmp/classroom_bookmarks.json','w').write(sys.argv[1])",
            json
        ]
        writeBookmarks.running = true
    }

    Process { id: writeBookmarks; command: ["sh", "-c", ""] }

    // ── Pinned courses persistence ────────────────────────────────────────────
    Process {
        id: readPins
        running: true
        command: ["cat", "/tmp/classroom_pins.json"]
        property string _buf: ""
        stdout: SplitParser {
            onRead: data => readPins._buf += data
        }
        onExited: {
            try { pinnedCourseIds = JSON.parse(readPins._buf.trim()) || {} }
            catch(e) { pinnedCourseIds = {} }
        }
    }

    function savePins() {
        writePins.command = [
            "python3", "-c",
            "import sys; open('/tmp/classroom_pins.json','w').write(sys.argv[1])",
            JSON.stringify(pinnedCourseIds)
        ]
        writePins.running = true
    }

    function togglePin(cid) {
        let updated = Object.assign({}, pinnedCourseIds)
        if (updated[cid]) delete updated[cid]
        else updated[cid] = true
        pinnedCourseIds = updated
        savePins()
        rebuildCourseModel()
    }

    function rebuildCourseModel() {
        // Move pinned courses to the front using move() — no clear, no flash
        let dest = 0
        for (let cid in pinnedCourseIds) {
            for (let i = dest; i < courseModel.count; i++) {
                if (courseModel.get(i).courseId === cid) {
                    if (i !== dest) courseModel.move(i, dest, 1)
                    dest++
                    break
                }
            }
        }
    }

    Process { id: writePins; command: ["sh", "-c", ""] }

    // Clipboard copy via wl-copy (Wayland)
    Process {
        id: copyProcess
        command: ["sh", "-c", ""]
    }

    function copyToClipboard(text) {
        copyProcess.command = [
            "python3", "-c",
            "import subprocess,sys,os; p=subprocess.Popen(['wl-copy'],stdin=subprocess.PIPE,preexec_fn=os.setsid); p.stdin.write(sys.argv[1].encode()); p.stdin.close()",
            text
        ]
        copyProcess.running = true
    }

    // Open announcement in browser
    Process { id: openProcess; command: ["sh", "-c", ""] }

    function openInBrowser(url) {
        openProcess.command = ["xdg-open", url]
        openProcess.running = true
    }

    function toggleBookmark(id) {
        let updated = Object.assign({}, bookmarkedIds)
        if (updated[id]) delete updated[id]
        else updated[id] = true
        bookmarkedIds = updated
        saveBookmarks()
        applyFilter()
    }

    // ── Filter / display logic ────────────────────────────────────────────────
    function applyFilter() {
        announcementModel.clear()
        for (let i = 0; i < _allAnns.length; i++) {
            let a = _allAnns[i]
            if (feedFilter === "saved" && !bookmarkedIds[a.annId]) continue
            announcementModel.append(a)
        }
    }

    onFeedFilterChanged: applyFilter()
    onActiveCourseIdChanged: { _jsonBuf = ""; catProcess.running = true }

    // ── Parser ───────────────────────────────────────────────────────────────
    function reloadData(raw) {
        if (!raw) return
        raw = raw.trim()
        if (raw.length < 5) return
        let data
        try { data = JSON.parse(raw) } catch(e) {
            console.log("[Classroom] JSON parse error:", e)
            return
        }
        if (!data || data.status !== "connected") return

        // Courses
        courseModel.clear()
        let courses = data.courses || []
        for (let i = 0; i < courses.length; i++) {
            let c = courses[i]
            if (String(c.courseId) === "all") continue
            if (pinnedCourseIds[String(c.courseId)]) continue
            
            courseModel.append({
                courseId: String(c.courseId || ""),
                title:    String(c.title    || "Untitled"),
                colorHex: String(c.colorHex || "#89b4fa")
            })
        }
        if (_firstLoad && courseModel.count > 0) {
            activeCourseId = courseModel.get(0).courseId
            _firstLoad = false
        }

        // Build in-memory announcement list (full, for filter)
        _allAnns = []
        let anns = data.announcements || []
        for (let j = 0; j < anns.length; j++) {
            let a = anns[j]
            if (activeCourseId !== "all" && String(a.courseId) !== activeCourseId) continue
            let annTime = String(a.timeAgo || "")
            _allAnns.push({
                annId:        String(a.id || (a.courseId + annTime)),
                courseId:     String(a.courseId    || ""),
                courseName:   String(a.courseName  || ""),
                teacherName:  String(a.teacherName || "Faculty"),
                timeAgo:      annTime,
                content:      String(a.content     || ""),
                link:         String(a.link        || ""),
                materialsJson: JSON.stringify(a.materials || []),
                isNew:        lastSeenTime !== "" && annTime > lastSeenTime
            })
        }

        // Build assignment list sorted by due date
        assignmentModel.clear()
        let assignments = data.assignments || []
        // Filter by active course
        let filtered = assignments.filter(a =>
            activeCourseId === "all" || String(a.courseId) === activeCourseId
        )
        // Sort: items with due dates first (ascending), then no-due-date
        filtered.sort((a, b) => {
            if (a.dueDate === "No due date" && b.dueDate === "No due date") return 0
            if (a.dueDate === "No due date") return 1
            if (b.dueDate === "No due date") return -1
            return a.dueDate.localeCompare(b.dueDate)
        })
        for (let k = 0; k < filtered.length; k++) {
            let w = filtered[k]
            assignmentModel.append({
                assignId:    String(w.id        || ""),
                courseId:    String(w.courseId  || ""),
                courseName:  String(w.courseName|| ""),
                title:       String(w.title     || "Untitled"),
                description: String(w.description || ""),
                dueDate:     String(w.dueDate   || "No due date"),
                state:       String(w.state     || "ASSIGNED")
            })
        }

        applyFilter()
    }

    // ── Panel UI ─────────────────────────────────────────────────────────────
    Rectangle {
        id: panel
        width: 460
        height: parent.height
        x: isOpen ? 0 : -width - 24
        color: Colors.bg
        clip: true

        Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header ────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 58
                color: Colors.header

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 10

                    // Sidebar toggle — leftmost button
                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: sidebarToggleHover.containsMouse ? Colors.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: sidebarVisible ? "◧" : "◨"
                            color: sidebarVisible ? Colors.blue : (sidebarToggleHover.containsMouse ? Colors.textBright : Colors.textDim)
                            font.pixelSize: 16
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: sidebarToggleHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sidebarVisible = !sidebarVisible
                        }
                    }

                    // Google Classroom icon
                    Rectangle {
                        width: 38; height: 38; radius: 8
                        color: "transparent"

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4

                            source: "../google-classroom-icon.svg"
                            sourceSize.width: parent.width
                            sourceSize.height: parent.height

                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true

                        Text {
                            text: "Google Classroom"
                            color: Colors.text
                            font.bold: true
                            font.pixelSize: 15
                            font.letterSpacing: 0.3
                        }
                        Text {
                            text: announcementModel.count + " announcements"
                            color: Colors.textDim
                            font.pixelSize: 13
                        }
                    }

                    // Refresh button
                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: refreshHover.containsMouse ? Colors.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: refreshIcon
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: isSyncing ? Colors.blue : (refreshHover.containsMouse ? Colors.textBright : Colors.textDim)
                            font.pixelSize: 15
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RotationAnimator on rotation {
                                running: isSyncing
                                loops: Animation.Infinite
                                from: 0; to: 360
                                duration: 900
                            }
                        }

                        MouseArea {
                            id: refreshHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: triggerRefresh()
                        }
                    }

                    // Close button
                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: closeBtnHover.containsMouse ? Colors.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: closeBtnHover.containsMouse ? Colors.red : Colors.textDim
                            font.pixelSize: 15
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: closeBtnHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: isOpen = false
                        }
                    }
                }

                // Header bottom border
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    height: 1
                    color: Colors.border
                }
            }

            // ── Main content: course sidebar + announcements feed ──────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.topMargin: 14
                Layout.bottomMargin: 14

                                // Course filter sidebar — floating card
                Rectangle {
                    id: sidebarRect
                    Layout.preferredWidth: sidebarVisible ? sidebarWidth : 0
                    Layout.fillHeight: true
                    color: Colors.sidebar
                    radius: 16
                    clip: true
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    // Inner content with padding away from rounded edges
                    Item {
                        anchors.fill: parent
                        anchors.margins: 8

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            // Customize Button
                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                radius: 8
                                color: customizeHover.containsMouse ? Colors.hover : "transparent"
                                border.color: sidebarCustomizing ? Colors.blue : "transparent"
                                border.width: 1
                                visible: courseModel.count > 0

                                Text {
                                    anchors.centerIn: parent
                                    text: sidebarCustomizing ? "Done" : "Customize"
                                    color: sidebarCustomizing ? Colors.blue : Colors.textDim
                                    font.pixelSize: 11
                                    font.bold: sidebarCustomizing
                                }

                                MouseArea {
                                    id: customizeHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: sidebarCustomizing = !sidebarCustomizing
                                }
                            }

                            ListView {
                                id: courseListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: courseModel
                                clip: true
                                spacing: 2

                                delegate: Item {
                                    id: courseItem
                                    width: courseListView.width
                                    height: 40
                                    property bool pinned: pinnedCourseIds[courseId] === true
                                    property bool active: activeCourseId === courseId
                                    property bool hovered: cMouse.containsMouse

                                    // Pill background
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 10
                                        color: active
                                            ? Qt.rgba(
                                                parseInt(colorHex.slice(1,3),16)/255,
                                                parseInt(colorHex.slice(3,5),16)/255,
                                                parseInt(colorHex.slice(5,7),16)/255, 0.22)
                                            : (hovered ? Colors.hoverSubtle : "transparent")
                                        Behavior on color { ColorAnimation { duration: 140 } }

                                        // Active left accent bar
                                        Rectangle {
                                            visible: active
                                            width: 3
                                            height: 20
                                            radius: 2
                                            color: colorHex
                                            anchors.left: parent.left
                                            anchors.leftMargin: 0
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    // Content Row
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 8
                                        spacing: 1

                                        // Left Icon: Drag Handle OR Checkmark OR Color Dot
                                        Loader {
                                            Layout.preferredWidth: sidebarCustomizing ? 18 : (cMouse.containsMouse ? 18 : 9)
                                            Layout.preferredHeight: 18
                                            sourceComponent: sidebarCustomizing ? checkComponent : (cMouse.containsMouse ? gripComponent : dotComponent)

                                            Component {
                                                id: dotComponent
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 7; height: 7; radius: 4
                                                    color: colorHex
                                                    opacity: active ? 1.0 : 0.7
                                                }
                                            }
                                            Component {
                                                id: gripComponent
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "≡"
                                                    color: gripMouse.containsMouse ? Colors.text : Colors.textDim
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    MouseArea {
                                                        id: gripMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.OpenHandCursor
                                                        onClicked: if (index > 0) courseModel.move(index, 0, 1)
                                                    }
                                                }
                                            }
                                            Component {
                                                id: checkComponent
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 16; height: 16; radius: 8
                                                    color: "transparent"
                                                    border.color: Colors.blue
                                                    border.width: 1.5

                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 8; height: 8; radius: 4
                                                        color: Colors.blue
                                                        visible: pinnedCourseIds[courseId] === true
                                                    }
                                                    
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: togglePin(courseId) // Reusing pin logic to toggle hidden
                                                    }
                                                }
                                            }
                                        }

                                        // Course title
                                        Text {
                                            text: title
                                            color: active ? "#ffffff" : (hovered ? Colors.textSub : Colors.textDim)
                                            font.pixelSize: 12
                                            font.bold: active
                                            font.letterSpacing: active ? 0.2 : 0
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            Behavior on color { ColorAnimation { duration: 140 } }
                                        }
                                    }

                                    MouseArea {
                                        id: cMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        z: -1
                                        onClicked: activeCourseId = courseId
                                    }

                                    // Custom tooltip — shown when text is elided
                                    Rectangle {
                                        id: hoverLabel
                                        visible: cMouse.containsMouse
                                        z: 999
                                        parent: courseItem.Window.contentItem  // escape clip boundary
                                        x: {
                                            var pt = courseItem.mapToItem(null, courseItem.width + 4, 0)
                                            return pt.x
                                        }
                                        y: {
                                            var pt = courseItem.mapToItem(null, 0, (courseItem.height - height) / 2)
                                            return pt.y
                                        }
                                        width: hoverLabelText.implicitWidth + 16
                                        height: 28
                                        radius: 7
                                        color: Colors.border

                                        Text {
                                            id: hoverLabelText
                                            anchors.centerIn: parent
                                            text: title
                                            color: Colors.textSub
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }

                            // ── Hidden Courses Section (Only visible in Customize mode) ──
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: sidebarCustomizing && hiddenRepeater.count > 0
                                spacing: 2

                                Text {
                                    text: "Hidden"
                                    color: Colors.textDim
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 0.5
                                    Layout.leftMargin: 4
                                }

                                Repeater {
                                    id: hiddenRepeater
                                    model: {
                                        let hidden = []
                                        for (let cid in pinnedCourseIds) {
                                            hidden.push({
                                                courseId: cid,
                                                title: cid, 
                                                colorHex: Colors.textDim.toString()
                                            })
                                        }
                                        return hidden
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 36
                                        radius: 10
                                        color: Colors.surface

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Rectangle {
                                                width: 16; height: 16; radius: 8
                                                color: "transparent"
                                                border.color: Colors.blue
                                                border.width: 1.5

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 8; height: 8; radius: 4
                                                    color: Colors.blue
                                                    visible: true 
                                                }
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: togglePin(modelData.courseId)
                                                }
                                            }

                                            Text {
                                                text: "Course " + modelData.courseId 
                                                color: Colors.textSub
                                                font.pixelSize: 11
                                                font.italic: true
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Drag divider ──────────────────────────────────────────
                Item {
                    Layout.preferredWidth: sidebarVisible ? 20 : 0
                    Layout.fillHeight: true
                    clip: false
                    visible: sidebarVisible

                    // Visual line — visible only on hover
                    Rectangle {
                        anchors.centerIn: parent
                        width: 4
                        height: parent.height
                        radius: 1
                        color: dividerDrag.containsMouse || dividerDrag.pressed
                               ? Colors.hoverLine : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: dividerDrag
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeHorCursor
                        property int _startX: 0
                        property int _startW: 0
                        onPressed: {
                            _startX = mouseX
                            _startW = sidebarWidth
                        }
                        onPositionChanged: {
                            if (pressed) {
                                let delta = mouseX - _startX
                                sidebarWidth = Math.max(120, Math.min(300, _startW + delta))
                            }
                        }
                    }
                }

                // Announcements feed
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // ── Feed filter tabs: All | Saved ─────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            color: Colors.header

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 4

                                // "All" tab
                                Rectangle {
                                    height: 26
                                    width: allTabLabel.implicitWidth + 20
                                    radius: 8
                                    color: feedFilter === "all"
                                        ? Colors.blueMuted
                                        : (allTabHover.containsMouse ? Colors.hoverSubtle : "transparent")
                                    Behavior on color { ColorAnimation { duration: 130 } }

                                    Text {
                                        id: allTabLabel
                                        anchors.centerIn: parent
                                        text: "All"
                                        color: feedFilter === "all" ? Colors.blue : (allTabHover.containsMouse ? Colors.textSub : Colors.textDim)
                                        font.pixelSize: 11
                                        font.bold: feedFilter === "all"
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                    }
                                    MouseArea {
                                        id: allTabHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: feedFilter = "all"
                                    }
                                }

                                // "Saved" tab
                                Rectangle {
                                    height: 26
                                    width: savedTabLabel.implicitWidth + 20
                                    radius: 8
                                    color: feedFilter === "saved"
                                        ? Colors.yellowMuted
                                        : (savedTabHover.containsMouse ? Colors.hoverSubtle : "transparent")
                                    Behavior on color { ColorAnimation { duration: 130 } }

                                    Text {
                                        id: savedTabLabel
                                        anchors.centerIn: parent
                                        text: "★  Saved" + (Object.keys(bookmarkedIds).length > 0 ? " " + Object.keys(bookmarkedIds).length : "")
                                        color: feedFilter === "saved" ? Colors.yellow : (savedTabHover.containsMouse ? Colors.textSub : Colors.textDim)
                                        font.pixelSize: 11
                                        font.bold: feedFilter === "saved"
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                    }
                                    MouseArea {
                                        id: savedTabHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: feedFilter = "saved"
                                    }
                                }

                                // "Due" tab
                                Rectangle {
                                    height: 26
                                    width: dueTabLabel.implicitWidth + 20
                                    radius: 8
                                    color: feedFilter === "due"
                                        ? Colors.redMuted
                                        : (dueTabHover.containsMouse ? Colors.hoverSubtle : "transparent")
                                    Behavior on color { ColorAnimation { duration: 130 } }

                                    Text {
                                        id: dueTabLabel
                                        anchors.centerIn: parent
                                        text: "󰃰  Due" + (assignmentModel.count > 0 ? " " + assignmentModel.count : "")
                                        color: feedFilter === "due" ? Colors.red : (dueTabHover.containsMouse ? Colors.textSub : Colors.textDim)
                                        font.pixelSize: 11
                                        font.bold: feedFilter === "due"
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                    }
                                    MouseArea {
                                        id: dueTabHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: feedFilter = "due"
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left; anchors.right: parent.right
                                height: 1; color: "#1e1e2e"
                            }
                        }

                        // Empty state (announcements)
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: feedFilter !== "due" && announcementModel.count === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 12

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: feedFilter === "saved" ? "★" : "󰋚"
                                    color: Colors.hover
                                    font.pixelSize: 42
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: feedFilter === "saved" ? "No saved announcements" : "No announcements"
                                    color: Colors.textDim
                                    font.pixelSize: 13
                                }
                            }
                        }

                        // Announcements feed list
                        ListView {
                            id: feedView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: feedFilter !== "due" && announcementModel.count > 0
                            model: announcementModel
                            clip: true
                            spacing: 10
                            topMargin: 10
                            bottomMargin: 10
                            leftMargin: 12
                            rightMargin: 12
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: Rectangle {
                                id: annCard
                                // feedView uses margins so width is already inset
                                width: feedView.width - feedView.leftMargin - feedView.rightMargin

                                property bool expanded:   expandedIds[annId]   === true
                                property bool bookmarked: bookmarkedIds[annId] === true
                                height: expanded ? cardCol.implicitHeight + 28 : 90
                                clip: true
                                radius: 12
                                color: cardHover.containsMouse ? Colors.surfaceAlt : Colors.surface
                                border.color: expanded ? getCourseColor(courseId)
                                                       : (bookmarked ? Colors.yellowMuted : Colors.borderSubtle)
                                border.width: 1

                                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }
                                Behavior on color  { ColorAnimation { duration: 120 } }

                                // Left accent bar
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3; radius: 3
                                    color: getCourseColor(courseId)
                                }

                                // Pulsing green "new" dot
                                Rectangle {
                                    visible: isNew
                                    width: 8; height: 8; radius: 4
                                    color: Colors.green
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: 8
                                    anchors.rightMargin: 8
                                    SequentialAnimation on opacity {
                                        running: isNew; loops: Animation.Infinite
                                        NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                                    }
                                }

                                ColumnLayout {
                                    id: cardCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 12
                                    spacing: 6

                                    // Row 1: teacher · date · chevron
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: teacherName
                                            color: Colors.text
                                            font.bold: true
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            height: 18
                                            width: timeLabel.implicitWidth + 12
                                            radius: 9
                                            color: Colors.border
                                            Text {
                                                id: timeLabel
                                                anchors.centerIn: parent
                                                text: formatDate(timeAgo)
                                                color: Colors.textSub
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            text: expanded ? "󰅃" : "󰅀"
                                            color: Colors.textDim
                                            font.pixelSize: 12
                                        }
                                    }

                                    // Row 2: course name
                                    Text {
                                        text: courseName
                                        color: getCourseColor(courseId)
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 0.3
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Row 3: body text (clipped when collapsed)
                                    Text {
                                        text: linkify(content)
                                        textFormat: Text.RichText
                                        color: Colors.textSub
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                        lineHeight: 1.4
                                        onLinkActivated: (url) => openInBrowser(url)
                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.NoButton
                                            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        }
                                    }

                                    // Attachment chips (shown when expanded and materials exist)
                                    Flow {
                                        visible: expanded && materialsJson !== "[]" && materialsJson !== ""
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: {
                                                try { return JSON.parse(materialsJson) } catch(e) { return [] }
                                            }

                                            Rectangle {
                                                height: 26
                                                width: chipRow.implicitWidth + 16
                                                radius: 6
                                                color: Colors.border
                                                border.color: Colors.borderAlt
                                                border.width: 1

                                                Row {
                                                    id: chipRow
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    spacing: 5

                                                    Text {
                                                        text: modelData.type === "drive"   ? "󰈙" :
                                                              modelData.type === "youtube" ? "󰗃" :
                                                              modelData.type === "form"    ? "󰈚" : "󰌘"
                                                        color: modelData.type === "drive"   ? Colors.blue :
                                                               modelData.type === "youtube" ? Colors.red :
                                                               modelData.type === "form"    ? Colors.green : Colors.yellow
                                                        font.pixelSize: 11
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    Text {
                                                        text: modelData.title.length > 28
                                                              ? modelData.title.substring(0, 28) + "…"
                                                              : modelData.title
                                                        color: Colors.textBright
                                                        font.pixelSize: 10
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (modelData.link) openInBrowser(modelData.link)
                                                }
                                            }
                                        }
                                    }

                                    // Row 4: action buttons — bookmark + copy (only when expanded)
                                    RowLayout {
                                        visible: expanded
                                        Layout.fillWidth: true
                                        spacing: 6

                                        // Bookmark button
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 30
                                            radius: 8
                                            color: bookmarked ? Colors.yellowMuted : (saveHover.containsMouse ? Colors.hoverSubtle : "transparent")
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 5
                                                Text {
                                                    text: bookmarked ? "★" : "☆"
                                                    color: bookmarked ? Colors.yellow : (saveHover.containsMouse ? Colors.textSub : Colors.textDim)
                                                    font.pixelSize: 12
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                }
                                                Text {
                                                    text: bookmarked ? "Saved" : "Save"
                                                    color: bookmarked ? Colors.yellow : (saveHover.containsMouse ? Colors.textSub : Colors.textDim)
                                                    font.pixelSize: 11
                                                    Layout.fillWidth: true
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                }
                                            }
                                            MouseArea {
                                                id: saveHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: toggleBookmark(annId)
                                            }
                                        }

                                        // Copy button
                                        Rectangle {
                                            property bool copied: false
                                            id: copyBtn
                                            Layout.fillWidth: true
                                            height: 30
                                            radius: 8
                                            color: copied ? Colors.greenMuted : (copyHover.containsMouse ? Colors.hoverSubtle : "transparent")
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            Timer {
                                                id: copyResetTimer
                                                interval: 1500
                                                onTriggered: copyBtn.copied = false
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 5
                                                Text {
                                                    text: copyBtn.copied ? "✓" : "󰆏"
                                                    color: copyBtn.copied ? Colors.green : (copyHover.containsMouse ? Colors.textSub : Colors.textDim)
                                                    font.pixelSize: 12
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                }
                                                Text {
                                                    text: copyBtn.copied ? "Copied!" : "Copy"
                                                    color: copyBtn.copied ? Colors.green : (copyHover.containsMouse ? Colors.textSub : Colors.textDim)
                                                    font.pixelSize: 11
                                                    Layout.fillWidth: true
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                }
                                            }
                                            MouseArea {
                                                id: copyHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    copyToClipboard(content)
                                                    copyBtn.copied = true
                                                    copyResetTimer.restart()
                                                }
                                            }
                                        }

                                        // Open in browser button
                                        Rectangle {
                                            visible: link !== ""
                                            Layout.fillWidth: true
                                            height: 30
                                            radius: 8
                                            color: openHover.containsMouse ? Colors.blueMuted : "transparent"
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 5
                                                Text {
                                                    text: "󰏌"
                                                    color: openHover.containsMouse ? Colors.blue : Colors.textDim
                                                    font.pixelSize: 12
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                }
                                                Text {
                                                    text: "Open"
                                                    color: openHover.containsMouse ? Colors.blue : Colors.textDim
                                                    font.pixelSize: 11
                                                    Layout.fillWidth: true
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                }
                                            }
                                            MouseArea {
                                                id: openHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: openInBrowser(link)
                                            }
                                        }
                                    }

                                    Item { height: 2 }
                                }

                                MouseArea {
                                    id: cardHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    z: -1  // sit behind ColumnLayout so bookmark button receives clicks
                                    onClicked: {
                                        let cur = expandedIds[annId] === true
                                        let updated = Object.assign({}, expandedIds)
                                        updated[annId] = !cur
                                        expandedIds = updated
                                    }
                                }
                            }
                        }

                        // ── Assignments / Due dates list ───────────────────
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: feedFilter === "due" && assignmentModel.count === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 12
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰃰"
                                    color: Colors.hover
                                    font.pixelSize: 42
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No assignments"
                                    color: Colors.textDim
                                    font.pixelSize: 13
                                }
                            }
                        }

                        ListView {
                            id: dueView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: feedFilter === "due" && assignmentModel.count > 0
                            model: assignmentModel
                            clip: true
                            spacing: 8
                            topMargin: 10
                            bottomMargin: 10
                            leftMargin: 12
                            rightMargin: 12
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: Rectangle {
                                id: assignCard
                                width: dueView.width - dueView.leftMargin - dueView.rightMargin
                                radius: 12
                                color: dueCardHover.containsMouse ? Colors.surfaceAlt : Colors.surface
                                Behavior on color { ColorAnimation { duration: 120 } }

                                // ── Urgency calculations ───────────────────────────
                                property int daysLeft: {
                                    if (dueDate === "No due date" || dueDate === "--") return 9999
                                    let parts = dueDate.split("-")
                                    if (parts.length < 3) return 9999
                                    let due = new Date(parseInt(parts[0]), parseInt(parts[1])-1, parseInt(parts[2]))
                                    let today = new Date(); today.setHours(0,0,0,0)
                                    return Math.round((due - today) / 86400000)
                                }

                                property string countdown: {
                                    if (daysLeft === 9999) return "No due date"
                                    if (daysLeft < 0)  return "Overdue by " + Math.abs(daysLeft) + "d"
                                    if (daysLeft === 0) return "Due today"
                                    if (daysLeft === 1) return "Due tomorrow"
                                    return "Due in " + daysLeft + " days"
                                }

                                // urgency: 0=safe(green) 1=warning(yellow) 2=critical(orange) 3=overdue(red)
                                property int urgency: {
                                    if (daysLeft === 9999) return -1
                                    if (daysLeft < 0)  return 3
                                    if (daysLeft === 0) return 3
                                    if (daysLeft <= 2)  return 2
                                    if (daysLeft <= 5)  return 1
                                    return 0
                                }

                                property color urgencyColor: {
                                    if (urgency === 3) return Colors.red       // red
                                    if (urgency === 2) return Colors.orange    // orange
                                    if (urgency === 1) return Colors.yellow    // yellow
                                    if (urgency === 0) return Colors.green     // green
                                    return Colors.borderAlt                    // none
                                }

                                property real urgencyAlpha: urgency >= 0 ? 0.85 : 0.0

                                // Glowing left urgency bar
                                Rectangle {
                                    id: urgencyBar
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.topMargin: 6
                                    anchors.bottomMargin: 6
                                    anchors.leftMargin: 0
                                    width: 3
                                    radius: 2
                                    color: assignCard.urgencyColor
                                    opacity: assignCard.urgencyAlpha
                                    Behavior on color { ColorAnimation { duration: 400 } }

                                    // Pulse animation for critical/overdue
                                    SequentialAnimation on opacity {
                                        running: assignCard.urgency >= 2
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutSine }
                                    }
                                }

                                // Subtle urgency background tint on card
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: assignCard.urgencyColor
                                    opacity: assignCard.urgency >= 0 ? 0.05 : 0
                                    Behavior on opacity { NumberAnimation { duration: 400 } }
                                }

                                height: assignCol.implicitHeight + 24

                                ColumnLayout {
                                    id: assignCol
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 14
                                    anchors.topMargin: 14
                                    anchors.bottomMargin: 10
                                    spacing: 6

                                    // Title row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Item {
                                            Layout.preferredWidth: 30
                                            Layout.preferredHeight: 30

                                            Image {
                                                id: assignSvgIcon
                                                anchors.fill: parent
                                                source: "../google-classroom-icon.svg"
                                                sourceSize.width: width
                                                sourceSize.height: height
                                                fillMode: Image.PreserveAspectFit
                                                visible: false
                                            }

                                            ColorOverlay {
                                                anchors.fill: assignSvgIcon
                                                source: assignSvgIcon
                                                color: getCourseColor(courseId)
                                            }
                                        }
                                        Text {
                                            text: title
                                            color: Colors.text
                                            font.pixelSize: 12
                                            font.bold: true
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }

                                        // Due badge — pill style with urgency color
                                        Rectangle {
                                            visible: assignCard.urgency >= 0
                                            height: 22
                                            width: dueBadge.implicitWidth + 14
                                            radius: 11
                                            color: Qt.rgba(
                                                assignCard.urgencyColor.r,
                                                assignCard.urgencyColor.g,
                                                assignCard.urgencyColor.b, 0.18)

                                            Text {
                                                id: dueBadge
                                                anchors.centerIn: parent
                                                text: assignCard.countdown
                                                color: assignCard.urgencyColor
                                                font.pixelSize: 9
                                                font.bold: assignCard.urgency >= 2
                                            }
                                        }
                                    }

                                    // Course name
                                    Text {
                                        text: courseName
                                        color: getCourseColor(courseId)
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 0.3
                                    }

                                    // Description (if any)
                                    Text {
                                        visible: description !== ""
                                        text: description
                                        color: Colors.textDim
                                        font.pixelSize: 10
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: dueCardHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    function linkify(text) {
        var escaped = text.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")
        return escaped.replace(/(https?:\/\/[^\s<]+)/g,
            '<a href="$1" style="color:' + Colors.blue.toString() + ';text-decoration:none;">$1</a>')
    }

    function getCourseColor(cid) {
        for (let i = 0; i < courseModel.count; i++) {
            if (courseModel.get(i).courseId === cid) return courseModel.get(i).colorHex
        }
        return Colors.blue
    }

    function getCourseTitle(cid) {
        for (let i = 0; i < courseModel.count; i++) {
            if (courseModel.get(i).courseId === cid) return courseModel.get(i).title
        }
        return "Course"
    }
}
