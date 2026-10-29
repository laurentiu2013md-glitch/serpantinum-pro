pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
QtObject {
    id: root
    property bool visible: false
    property var screen: null
    function open(target) { IslandController.request("","close",target); screen=target || Quickshell.cursorScreen || Quickshell.screens[0]; visible=true; }
    function close() { visible=false; }
    function toggle(target) { if (visible) close(); else open(target); }
    property var ipc: IpcHandler {
        target: "quickControls"
        function open() { root.open(null); }
        function close() { root.close(); }
        function toggle() { root.toggle(null); }
        function state(): string { return JSON.stringify({visible:root.visible,screen:root.screen ? root.screen.name : ""}); }
    }
}
