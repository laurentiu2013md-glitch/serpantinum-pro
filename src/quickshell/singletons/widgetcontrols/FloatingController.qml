pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: controller

    signal previewRequested(var screen, string edge, real position)
    signal setIndexRequested(var screen, string index)
    signal showSystemUsageRequested(var screen)
    signal showNotesRequested(var screen)
    signal toggleCalculatorRequested(var screen)
    signal showDropShelfRequested(var screen)
    signal toggleDropShelfRequested(var screen)

    function targetScreen(screen) {
        if (screen) return screen;
        if (Quickshell.cursorScreen) return Quickshell.cursorScreen;
        return Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function setIndex(index, screen) {
        let target = targetScreen(screen);
        if (target) controller.setIndexRequested(target, index);
    }

    function showSystemUsage(screen) {
        let target = targetScreen(screen);
        if (target) controller.showSystemUsageRequested(target);
    }

    function showNotes(screen) {
        let target = targetScreen(screen);
        if (target) controller.showNotesRequested(target);
    }

    function showDropShelf(screen) {
        let target = targetScreen(screen);
        if (target) controller.showDropShelfRequested(target);
    }

    function toggleCalculator(screen) {
        let target = targetScreen(screen);
        if (target) controller.toggleCalculatorRequested(target);
    }

    function toggleDropShelf(screen) {
        let target = targetScreen(screen);
        if (target) controller.toggleDropShelfRequested(target);
    }

    IpcHandler {
        target: "floating"

        function preview(edge: string, position: string) { controller.previewRequested(controller.targetScreen(null), edge, parseFloat(position)); }
        function setIndex(index: string) {
            controller.setIndex(index, null);
        }

        function showSystemUsage() {
            controller.showSystemUsage(null);
        }

        function showNotes() {
            controller.showNotes(null);
        }

        function toggleCalculator() {
            controller.toggleCalculator(null);
        }

        function showDropShelf() {
            controller.showDropShelf(null);
        }

        function toggleDropShelf() {
            controller.toggleDropShelf(null);
        }

        function forceReload() {
            Quickshell.reload(true)
        }
    }
}
