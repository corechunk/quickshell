import QtQuick
import Quickshell

pragma Singleton

Item { 
    id: paths 

    property string srcDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper_picker/thumbs"
    property string logDir: Quickshell.env("HOME") + "/.cache/quickshell"

    function getCacheDir(name) { 
        return Quickshell.env("HOME") + "/.cache/quickshell/" + name 
    }

    function getRunDir(name) { 
        return Quickshell.env("HOME") + "/.cache/quickshell/" + name 
    }
}
