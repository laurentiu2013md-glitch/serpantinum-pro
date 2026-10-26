pragma Singleton
import QtQuick
import Quickshell

Item {
    signal temporary(var targetScreen, string title, string detail, int priority, int timeout)
    function notify(title, detail, priority, timeout, screen) { temporary(screen || Quickshell.cursorScreen || Quickshell.screens[0], title, detail, priority || 50, timeout || 1800); }
    signal requested(var targetScreen, string kind, string action)
    function request(kind, action, screen) {
        requested(screen || Quickshell.cursorScreen || Quickshell.screens[0], kind, action || "open");
    }
}
