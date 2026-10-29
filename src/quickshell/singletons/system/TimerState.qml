pragma Singleton
import QtQuick
import Quickshell.Io
QtObject {
    id: root
    property var entries: []
    readonly property bool isActive: entries.length > 0
    property var owner: null
    property bool focusRunning: false
    property bool focusActive: false
    property int focusRemaining: 25 * 60 * 1000
    property string focusPhase: "Focus"
    readonly property string focusLabel: {
        const seconds=Math.max(0, Math.ceil(focusRemaining / 1000));
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2,"0");
    }
    signal startFocusRequested(int minutes)
    signal toggleFocusRequested()
    signal resetFocusRequested()
    function startFocus(minutes) { startFocusRequested(minutes); }
    function toggleFocus() { toggleFocusRequested(); }
    function resetFocus() { resetFocusRequested(); }
    property var ipc: IpcHandler {
        target: "focusTimer"
        function start(minutes: int) { root.startFocus(Math.max(1,Math.min(180,minutes))); }
        function toggle() { root.toggleFocus(); }
        function reset() { root.resetFocus(); }
        function state(): string { return JSON.stringify({ready:root.owner!==null,running:root.focusRunning,active:root.focusActive,remaining:root.focusRemaining,phase:root.focusPhase,label:root.focusLabel}); }
    }
}
