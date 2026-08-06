import QtQuick

pragma Singleton

Item {
    id: scaler
    property int currentWidth: 1920
    function s(val) { return val * (currentWidth / 1920); }
}
