pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
QtObject {
    id: zone
    property var upper: ({})
    function nearTop(screen) { return !screen || upper[screen.name] !== false; }
    property var watcher: Process {
        running: true
        command: ["python3", Caching.serpantinumDir + "/quickshell/bar/pointer-zone.py"]
        stdout: SplitParser { onRead: line => { try { zone.upper = JSON.parse(line); } catch(error) {} } }
        onExited: zone.upper = ({})
    }
}
