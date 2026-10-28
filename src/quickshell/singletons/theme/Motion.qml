pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
QtObject {
    id: motion
    property bool systemReduced: false
    readonly property bool reduced: GameMode.enabled || systemReduced || Config.getSetting("coloros", {}).reducedMotion === true
    readonly property int press: reduced ? 0 : 110
    readonly property int hover: reduced ? 0 : 150
    readonly property int toggle: reduced ? 0 : 220
    readonly property int menu: reduced ? 0 : 280
    readonly property int morph: reduced ? 0 : 340
    readonly property int notification: reduced ? 0 : 280
    function duration(normal) { return reduced ? 0 : normal; }
    property var accessibility: Process {
        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "enable-animations"]
        stdout: SplitParser { onRead: line => motion.systemReduced = line.indexOf("false") !== -1 }
    }
    property var initialSetting: Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"]
        stdout: StdioCollector { onStreamFinished: motion.systemReduced = text.trim() === "false" }
    }
}
