pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    signal temporary(var targetScreen, string title, string detail, int priority, int timeout)
    function notify(title, detail, priority, timeout, screen) { temporary(screen || Quickshell.cursorScreen || Quickshell.screens[0], title, detail, priority || 50, timeout || 1800); }
    signal osdRequested(var targetScreen)
    function showOsd(screen) { osdRequested(screen || Quickshell.cursorScreen || Quickshell.screens[0]); }
    IpcHandler {
        target: "island"
        function keyboard(kind: string): void {
            if (["music","calendar","bluetooth","network","shelf","focus","battery","controls"].indexOf(kind)!==-1) request(kind,"keyboard");
        }
        function close(): void { request("","close"); }
    }
    signal requested(var targetScreen, string kind, string action)
    function request(kind, action, screen) {
        if (kind === "controls") {
            if (action === "close") ControlCenterController.close();
            else if (action === "toggle" || action === "keyboard") ControlCenterController.toggle(screen);
            else ControlCenterController.open(screen);
            return;
        }
        if (kind) ControlCenterController.close();
        requested(screen || Quickshell.cursorScreen || Quickshell.screens[0], kind, action || "open");
    }
}
