pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
QtObject {
    id: zone
    property var upper: ({})
    property bool effectsEnabled: !Motion.reduced && Config.getSetting("coloros", {}).cursorLocator !== false
    onEffectsEnabledChanged: if (watcher.running) watcher.write("effects " + (effectsEnabled ? "1" : "0") + "\n")
    property var ipc: IpcHandler {
        target: "cursor"
        function locate(): void { zone.watcher.write("locate\n"); }
        function state(): string { return JSON.stringify({size: zone.upper._cursorSize || 24, effects: zone.effectsEnabled, native: zone.upper._cursorNative === true, scale: zone.upper._cursorScale || 1}); }
    }
    function nearTop(screen) { return !screen || upper[screen.name] !== false; }
    property var watcher: Process {
        running: true
        stdinEnabled: true
        onStarted: write("effects " + (zone.effectsEnabled ? "1" : "0") + "\n")
        command: ["python3", Caching.serpantinumDir + "/quickshell/bar/pointer-zone.py"]
        stdout: SplitParser { onRead: line => { try { zone.upper = JSON.parse(line); } catch(error) {} } }
        onExited: zone.upper = ({})
    }
}
