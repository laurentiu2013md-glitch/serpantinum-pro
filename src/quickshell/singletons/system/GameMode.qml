pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/serpantinum/game-mode.json"
    property bool enabled: readEnabled()
    readonly property bool busy: !!transition.running
    property string error: ""
    property bool reloadAfterTransition: false

    function readEnabled() {
        try { return JSON.parse(state.text()).enabled === true; }
        catch (e) { return false; }
    }

    function run(action, reloadShell) {
        if (busy) return;
        error = "";
        reloadAfterTransition = reloadShell;
        transition.command = ["python3", Caching.serpantinumDir + "/scripts/game_mode.py", action];
        transition.running = true;
    }

    function toggle() { run(enabled ? "disable" : "enable", true); }
    function reapply() { if (enabled) run("reapply", false); }

    FileView {
        id: state
        path: root.statePath
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.enabled = root.readEnabled()
        onLoadFailed: root.enabled = false
    }

    Process {
        id: transition
        stderr: StdioCollector { id: failure; waitForEnd: true }
        onExited: function(exitCode) {
            state.reload();
            root.enabled = root.readEnabled();
            if (exitCode !== 0) {
                root.error = String(failure.text || "Game Mode could not change compositor settings").trim();
                console.warn(root.error);
            } else if (root.reloadAfterTransition) {
                // Destroy the previous UI and its singletons to release unused resources.
                Qt.callLater(function() { Quickshell.reload(true); });
            }
        }
    }

    IpcHandler {
        target: "gameMode"
        function toggle() { root.toggle(); }
        function disable() { if (root.enabled) root.run("disable", true); }
    }
}
