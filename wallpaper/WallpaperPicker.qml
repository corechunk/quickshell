import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtCore
import Qt.labs.folderlistmodel
import QtMultimedia
import Quickshell
import Quickshell.Io
import "." 

Item {
    id: window
    width: Screen.width
    
    signal wallpaperApplied()
    
    function s(val) { 
        return Scaler.s(val); 
    }

    property string widgetArg: ""
    property string targetWallName: ""
    property bool initialFocusSet: false
    property int visibleItemCount: -1
    property int scrollAccum: 0
    property real scrollThreshold: window.s(300)

    property string searchQuery: ""
    property string pendingSearch: ""
    property bool isApplying: false
    property bool isMonitorSelectorOpen: false
    property bool isSearchActive: false
    property bool isReady: visible && localFolderModel.status === FolderListModel.Ready

    Timer {
        id: applyUnlockTimer
        interval: 250
        onTriggered: window.isApplying = false
    }

    ListModel { id: monitorModel }

    Process {
        id: monitorProc
        command: ["sh", "-c", "export PATH=$PATH:/usr/bin:/usr/local/bin:/run/current-system/sw/bin && hyprctl monitors -j"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                let response = this.text; 
                if (response && response.trim().length > 0) {
                    try {
                        var monitors = JSON.parse(response);
                        monitorModel.clear();
                        for (var i = 0; i < monitors.length; i++) {
                            monitorModel.append({ "name": monitors[i].name, "selected": true });
                        }
                    } catch(e) {}
                }
            }
        }
    }

    function loadMonitors() {
        if (!monitorProc.running) {
            monitorProc.running = true;
        }
    }

    Process {
        id: activeWallProc
        command: ["sh", "-c", "realpath $HOME/Pictures/wallpapers/selected-image 2>/dev/null || readlink -f $HOME/Pictures/wallpapers/selected-image 2>/dev/null"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let realPath = this.text ? this.text.trim() : "";
                if (realPath && realPath.length > 0) {
                    let parts = realPath.split("/");
                    window.targetWallName = parts[parts.length - 1];
                }
                window._wallNameReady = true;
                window._tryInitialFocus();
            }
        }
    }


    Component.onCompleted: {
        window.loadMonitors();
        activeWallProc.running = true;
        Qt.callLater(() => {
            searchInput.forceActiveFocus();
        });
    }

    Timer {
        id: searchDebounceTimer
        interval: 180
        repeat: false
        onTriggered: {
            window.searchQuery = window.pendingSearch;
            if (!window.searchQuery || window.searchQuery.trim() === "") {
                view.opacity = 0.0;
                window.isSearchActive = false;
                Qt.callLater(() => { view.opacity = 1.0; window.tryFocus(); });
            } else {
                view.opacity = 0.0;
                searchSwapTimer.restart();
            }
        }
    }

    Timer {
        id: searchSwapTimer
        interval: 150
        repeat: false
        onTriggered: {
            window.applySearchFilter();
            window.tryFocus();
            view.opacity = 1.0;
        }
    }

    function getMonitorOutputs() {
        let selected = [];
        for (let i = 0; i < monitorModel.count; i++) {
            let item = monitorModel.get(i);
            if (item.selected) selected.push(item.name);
        }
        if (selected.length === 0) return "none";
        if (selected.length === monitorModel.count) return "all";
        return selected.join(",");
    }

    function applyWallpaper(safeFileName, isVideo) {
        if (!safeFileName || window.isApplying) return;
        
        let outputs = window.getMonitorOutputs();
        if (outputs === "none") return;
        
        window.isApplying = true;
        applyUnlockTimer.restart();
        
        window.targetWallName = safeFileName;
        let cleanName = window.getCleanName(safeFileName);

        const escapeBash = (str) => String(str).replace(/(["\\$`])/g, '\\$1');
        const randomTransition = window.transitions[Math.floor(Math.random() * window.transitions.length)];
        const escOutputs = escapeBash(outputs);
        
        const logFile = Caching.logDir + "/swww_debug.log";

        const originalFile = window.srcDir + "/" + cleanName;
        const thumbFile = Caching.getCacheDir("wallpaper_picker") + "/thumbs/" + safeFileName;
        
        const escOriginal = escapeBash(originalFile);
        const escThumb = escapeBash(thumbFile);

        let wallpaperCmd = "";
        
        if (isVideo) {
            wallpaperCmd = `
                mpvpaper -o 'loop --no-audio --hwdec=auto' '*' "${escOriginal}" >> ${logFile} 2>&1 &
            `;
        } else {
            wallpaperCmd = `
                ln -sf "${escOriginal}" "${Quickshell.env("HOME")}/Pictures/wallpapers/selected-image" || true
                pkill -9 hyprpaper || true
                hyprpaper -c "${Quickshell.env("HOME")}/.config/hypr/hyprpaper.conf" >> ${logFile} 2>&1 &
            `;
        }

        const fullScript = `
            cp "${isVideo ? escThumb : escOriginal}" ${Caching.getCacheDir("wallpaper_picker")}/current_wallpaper.png || true
            pkill mpvpaper || true
            
            ${wallpaperCmd}
            ( wallust run "${escOriginal}" -s || true ) &
        `;
        Quickshell.execDetached(["bash", "-c", fullScript]);
        window.wallpaperApplied();
    }

    readonly property string homeDir: "file://" + Quickshell.env("HOME")
    readonly property string thumbDir: "file://" + Caching.getCacheDir("wallpaper_picker") + "/thumbs"
    readonly property string searchDir: "file://" + Caching.getCacheDir("wallpaper_picker") + "/search_thumbs"
    readonly property string srcDir: {
        const dir = Quickshell.env("WALLPAPER_DIR")
        return (dir && dir !== "") 
        ? dir 
        : Quickshell.env("HOME") + "/Pictures/wallpapers"
    }

    readonly property var transitions: ["simple", "fade", "left", "right", "top", "bottom", "wipe", "grow", "center", "outer", "random", "wave"]

    readonly property real itemWidth: window.s(320)
    readonly property real itemHeight: window.s(320)
    readonly property real borderWidth: window.s(3)
    readonly property real spacing: window.s(20)
    readonly property real skewFactor: -0.35
    property bool isItemAnimating: false

    Timer {
        id: scrollThrottle
        interval: 150
    }


    Timer {
        id: itemAnimationTimer
        interval: 450
        onTriggered: window.isItemAnimating = false
    }

    // Lazy thumbnail generator — one at a time, lowest CPU/IO priority
    QtObject {
        id: thumbGen

        property var queue: []
        property bool busy: false

        function generateThumb(srcPath, thumbPath) {
            queue.push({ src: srcPath, thumb: thumbPath });
            if (!busy) processNext();
        }

        function processNext() {
            if (queue.length === 0) { busy = false; return; }
            busy = true;
            let job = queue.shift();
            thumbProc.src   = job.src;
            thumbProc.thumb = job.thumb;
            thumbProc.running = true;
        }
    }

    Process {
        id: thumbProc
        property string src: ""
        property string thumb: ""

        // nice -n 19: lowest CPU priority
        // ionice -c 3: idle IO class — only runs when disk is otherwise free
        command: ["bash", "-c",
            "nice -n 19 ionice -c 3 magick \"" + src + "\" -resize 600x450^ -gravity Center -extent 600x450 \"" + thumb + "\" 2>/dev/null"
        ]
        running: false

        onRunningChanged: {
            if (!running && src !== "") thumbGen.processNext();
        }
    }

    function checkItemMatchesFilter(fileName, isVid) {
        if (window.searchQuery && window.searchQuery.trim() !== "") {
            if (!String(fileName).toLowerCase().includes(window.searchQuery.trim().toLowerCase())) {
                return false;
            }
        }
        return true;
    }

    function getCleanName(fileName) {
        if (!fileName) return "";
        let str = String(fileName);
        if (str.startsWith("000_")) {
            return str.substring(4);
        }
        return str;
    }

    function updateVisibleCount() {
        window.visibleItemCount = window.activeModel ? window.activeModel.count : 0;
    }

    property bool _wallNameReady: false
    property int _snapTargetIndex: -1

    Timer {
        id: snapTimer
        interval: 16
        repeat: false
        onTriggered: {
            let idx = window._snapTargetIndex;
            if (idx < 0) return;
            view.forceLayout();
            view.positionViewAtIndex(idx, ListView.Center);
            view.currentIndex = idx;
            window.initialFocusSet = true;
        }
    }

    function _tryInitialFocus() {
        if (window.initialFocusSet) return;
        if (!window._wallNameReady || localProxyModel.count === 0) return;

        let cleanTarget = window.targetWallName !== "" ? window.getCleanName(window.targetWallName) : "";
        let targetIndex = -1;

        for (let i = 0; i < localProxyModel.count; i++) {
            let fname = localProxyModel.get(i).fileName || "";
            if (cleanTarget !== "" && window.getCleanName(fname) === cleanTarget) {
                targetIndex = i;
                break;
            }
        }

        // If target not found yet, wait for more items (incremental loading)
        if (targetIndex === -1 && cleanTarget !== "") return;

        let idx = targetIndex !== -1 ? targetIndex : 0;
        window._snapTargetIndex = idx;
        snapTimer.restart();
    }

    function tryFocus(forceSnap) {
        if (!view.model || view.model.count === 0) return;

        let cleanTarget = window.targetWallName !== "" ? window.getCleanName(window.targetWallName) : "";
        let targetIndex = -1;
        let firstValidIndex = -1;

        for (let i = 0; i < view.model.count; i++) {
            let fname = view.model.get(i).fileName || "";
            if (firstValidIndex === -1) firstValidIndex = i;
            if (cleanTarget !== "" && window.getCleanName(fname) === cleanTarget) {
                targetIndex = i;
            }
        }

        let idx = targetIndex !== -1 ? targetIndex : firstValidIndex;
        if (idx !== -1) {
            view.currentIndex = idx;
        }
        window.updateVisibleCount();
    }


    function stepToNextValidIndex(direction) {
        let targetModel = window.activeModel;
        if (!targetModel || targetModel.count === 0) return;

        let start = view.currentIndex;
        let found = -1;

        if (direction === 1) {
            for (let i = start + 1; i < targetModel.count; i++) { found = i; break; }
        } else {
            for (let i = start - 1; i >= 0; i--) { found = i; break; }
        }

        if (found !== -1) view.currentIndex = found;
    }

    Shortcut { sequence: "Left"; enabled: !window.isApplying; onActivated: window.stepToNextValidIndex(-1) }
    Shortcut { sequence: "Right"; enabled: !window.isApplying; onActivated: window.stepToNextValidIndex(1) }
    Shortcut { sequence: "Return"; enabled: !window.isApplying; onActivated: {
        let mdl = window.activeModel;
        if (view.currentIndex >= 0 && view.currentIndex < mdl.count) {
            let fname = mdl.get(view.currentIndex).fileName;
            if (fname) {
                let isVid = String(fname).startsWith("000_");
                window.applyWallpaper(String(fname), isVid);
            }
        }
    }}


    ListModel { id: localProxyModel }
    ListModel { id: searchFilterModel }
    readonly property var activeModel: isSearchActive ? searchFilterModel : localProxyModel

    function applySearchFilter() {
        let query = window.searchQuery ? window.searchQuery.trim().toLowerCase() : "";
        if (!query) {
            window.isSearchActive = false;
            return;
        }
        searchFilterModel.clear();
        let batch = [];
        for (let i = 0; i < localProxyModel.count; i++) {
            let fn = String(localProxyModel.get(i).fileName || "");
            let fu = String(localProxyModel.get(i).fileUrl || "");
            if (fn.toLowerCase().includes(query)) {
                batch.push({ "fileName": fn, "fileUrl": fu });
            }
        }
        searchFilterModel.append(batch);
        window.isSearchActive = true;
    }

    FolderListModel {
        id: localFolderModel
        folder: "file://" + window.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false
        sortField: FolderListModel.Name
        
        // Match original: call syncLocalModel on EVERY count change (incremental)
        // so by the time the target index loads, ListView has already rendered items.
        onCountChanged: window.syncLocalModel()
        onStatusChanged: { if (status === FolderListModel.Ready) window.syncLocalModel() }
    }

    property int _localSyncedCount: 0

    function syncLocalModel() {
        let folderCount = localFolderModel.count;

        // If folder shrank (files deleted), full rebuild
        if (folderCount < window._localSyncedCount) {
            localProxyModel.clear();
            window._localSyncedCount = 0;
        }

        // Incremental append — only new items, exactly like original
        if (folderCount > window._localSyncedCount) {
            let batch = [];
            for (let i = window._localSyncedCount; i < folderCount; i++) {
                let fn = localFolderModel.get(i, "fileName");
                let fu = localFolderModel.get(i, "fileUrl");
                if (fn !== undefined) {
                    let fnStr = String(fn);
                    if (fnStr !== "selected-image" && fnStr !== "current_wallpaper.png") {
                        batch.push({ "fileName": fnStr, "fileUrl": String(fu) });
                    }
                }
            }
            if (batch.length > 0) {
                localProxyModel.append(batch);
            }
            window._localSyncedCount = folderCount;
        }

        window.updateVisibleCount();

        // First-time focus snap — same guard as original
        if (!window.initialFocusSet && localProxyModel.count > 0 && window._wallNameReady) {
            window._tryInitialFocus();
        }
    }


    Item {
        anchors.fill: parent

        ListView {
            id: view
            anchors.fill: parent
            
            opacity: window.isReady ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

            spacing: 0
            orientation: ListView.Horizontal
            clip: false

            interactive: !window.isApplying
            cacheBuffer: 4.5 * (window.itemWidth * 0.7 + window.spacing)

            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2)
            preferredHighlightEnd: (width / 2) + ((window.itemWidth * 1.5 + window.spacing) / 2)
            
            header: Item { width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2)) }
            footer: Item { width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2)) }
            
            highlightMoveDuration: window.initialFocusSet ? 300 : 0
            focus: true
            
            onCurrentIndexChanged: {
                window.isItemAnimating = true;
                itemAnimationTimer.restart();
            }
            
            model: window.activeModel

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton

                onWheel: (wheel) => {
                    if (window.isApplying) {
                        wheel.accepted = true;
                        return;
                    }

                    if (scrollThrottle.running) {
                       wheel.accepted = true
                       return
                    }

                    let dx = wheel.angleDelta.x
                    let dy = wheel.angleDelta.y
                    let delta = Math.abs(dx) > Math.abs(dy) ? dx : dy

                    scrollAccum += delta

                    if (Math.abs(scrollAccum) >= scrollThreshold) {
                        window.stepToNextValidIndex(scrollAccum > 0 ? -1 : 1)
                        scrollAccum = 0
                        scrollThrottle.start()
                    }

                    wheel.accepted = true
                }        
            }

            delegate: Item {
                id: delegateRoot
                
                readonly property string safeFileName: fileName !== undefined ? String(fileName) : ""
                
                readonly property bool isCurrent: ListView.isCurrentItem
                readonly property bool isVisuallyEnlarged: isCurrent
                
                readonly property bool isVideo: safeFileName.startsWith("000_")
                readonly property bool matchesFilter: true
                
                readonly property real targetWidth: isVisuallyEnlarged ? (window.itemWidth * 1.5) : (window.itemWidth * 0.7)
                readonly property real targetHeight: isVisuallyEnlarged ? (window.itemHeight + window.s(30)) : window.itemHeight


                property bool isPlayingVideo: false

                width: matchesFilter ? (targetWidth + window.spacing) : 0
                visible: width > 0.1 || opacity > 0.01
                opacity: matchesFilter ? (isVisuallyEnlarged ? 1.0 : 0.85) : 0.0
                scale: matchesFilter ? 1.0 : 0.01

                height: targetHeight
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: window.s(15)

                z: isVisuallyEnlarged ? 10 : 1
                
                Behavior on scale   { enabled: window.initialFocusSet; NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                Behavior on width   { enabled: window.initialFocusSet; NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                Behavior on height  { enabled: window.initialFocusSet; NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                Behavior on opacity { enabled: window.initialFocusSet; NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                Item {
                    id: innerCard
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: window.s(40) + (((window.itemHeight - height) / 2) * window.skewFactor)
                    
                    width: parent.width > 0 ? parent.width * (targetWidth / (targetWidth + window.spacing)) : 0
                    height: parent.height

                    layer.enabled: true
                    
                    scale: delegateRoot.matchesFilter ? 1.0 : 0.2
                    Behavior on scale { enabled: window.initialFocusSet; NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

                    transform: Matrix4x4 {
                        property real s: window.skewFactor
                        matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        enabled: delegateRoot.matchesFilter && !window.isApplying
                        onClicked: {
                            view.currentIndex = index
                            let mdl = window.activeModel
                            if (index >= 0 && index < mdl.count) {
                                let fname = mdl.get(index).fileName
                                if (fname) {
                                    let isVid = String(fname).startsWith("000_")
                                    window.applyWallpaper(String(fname), isVid)
                                }
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: window.borderWidth
                        Rectangle { anchors.fill: parent; color: _theme.base }
                        clip: true

                        Image {
                            id: wallImage
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: window.s(-50)
                            width: (window.itemWidth * 1.5) + ((window.itemHeight + window.s(30)) * Math.abs(window.skewFactor)) + window.s(50)
                            height: window.itemHeight + window.s(30)
                            sourceSize.width: 600
                            sourceSize.height: 450
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            mipmap: false
                            smooth: true

                            // Try thumbnail first (small = fast), fall back to original
                            property bool triedThumb: false
                            source: (fileUrl !== undefined && safeFileName !== "")
                                    ? (window.thumbDir + "/" + safeFileName)
                                    : ""

                            onStatusChanged: {
                                if (status === Image.Error && !triedThumb) {
                                    triedThumb = true;
                                    source = fileUrl !== undefined ? fileUrl : "";
                                    // Lazily generate thumb in background at lowest priority
                                    thumbGen.generateThumb(
                                        String(fileUrl).replace("file://", ""),
                                        Caching.getCacheDir("wallpaper_picker") + "/thumbs/" + safeFileName
                                    );
                                }
                            }

                            transform: Matrix4x4 {
                                property real s: -window.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                        }

                        // Skeleton shimmer — hides blank card while texture loads
                        Rectangle {
                            id: shimmer
                            anchors.fill: parent
                            color: Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.92)
                            visible: opacity > 0
                            opacity: wallImage.status === Image.Ready ? 0.0 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                            SequentialAnimation {
                                running: wallImage.status !== Image.Ready
                                loops: Animation.Infinite
                                NumberAnimation { target: shimmer; property: "opacity"; to: 0.45; duration: 850; easing.type: Easing.InOutSine }
                                NumberAnimation { target: shimmer; property: "opacity"; to: 0.92; duration: 850; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    // Animated border glow overlay
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: delegateRoot.isVisuallyEnlarged ? _theme.text : "transparent"
                        border.width: window.borderWidth
                        Behavior on border.color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        opacity: delegateRoot.isVisuallyEnlarged ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // Bottom Search Bar
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: window.s(30)
            anchors.horizontalCenter: parent.horizontalCenter
            z: 20
            height: window.s(56)
            width: window.s(340)
            radius: window.s(14)

            color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.90)
            border.color: searchInput.activeFocus ? _theme.text : _theme.surface2
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Row {
                anchors.centerIn: parent
                spacing: 0

                // "Search:" label
                Text {
                    text: "Search:"
                    color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.55)
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: window.s(16)
                    rightPadding: window.s(10)
                }

                TextInput {
                    id: searchInput
                    width: window.s(240)
                    anchors.verticalCenter: parent.verticalCenter
                    focus: true

                    color: _theme.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(14)
                    clip: true

                    Text {
                        text: "type to filter..."
                        color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.35)
                        font: parent.font
                        visible: !parent.text && !parent.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Left) {
                            window.stepToNextValidIndex(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            window.stepToNextValidIndex(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            let mdl = window.activeModel;
                            if (view.currentIndex >= 0 && view.currentIndex < mdl.count) {
                                let fname = mdl.get(view.currentIndex).fileName;
                                if (fname) {
                                    let isVid = String(fname).startsWith("000_");
                                    window.applyWallpaper(String(fname), isVid);
                                }
                            }
                            event.accepted = true;
                        }
                    }

                    onTextChanged: {
                        window.pendingSearch = text;
                        searchDebounceTimer.restart();
                    }
                }
            }
        }
    }
}
