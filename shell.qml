import QtQuick
import Quickshell
import Quickshell.Wayland
import "wallpaper"
import "modules/MyBar" as MyBar
import "modules" as Modules

ShellRoot {

    MyBar.MusicPopup {}
    Modules.ClassroomPanel {}

    PanelWindow {
        id: wallWindow
        
        // Hide by default so it doesn't block the screen on launch
        visible: false

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        
        color: "transparent"

        function closeWithFade() {
            picker.opacity = 0.0;
            overlayBg.opacity = 0.0;
            closeTimer.start();
        }

        Timer {
            id: closeTimer
            interval: 360
            onTriggered: {
                wallWindow.visible = false; // Just hide the window, don't quit Quickshell!
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: wallWindow.closeWithFade()
        }

        Rectangle {
            id: overlayBg
            anchors.fill: parent
            color: "#aa000000"
            opacity: 1.0
            Behavior on opacity {
                NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
            }
        }
        
        WallpaperPicker {
            id: picker
            anchors.fill: parent
            opacity: 1.0
            Behavior on opacity {
                NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
            }
            onWallpaperApplied: wallWindow.closeWithFade()
        }
    }
}