pragma Singleton
import QtQuick
// User preference: keep blur in normal use, including occupied workspaces.
// ThemeBackend and the existing GameMode service disable it in Game Mode.
QtObject {
    readonly property bool enabled: false
    function occupied(screen) { return false; }
}
