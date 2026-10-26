pragma Singleton
import QtQuick
import Quickshell

Scope {
    id: controller
    readonly property var config: bridge.config
    readonly property var indices: bridge.indices
    readonly property var runtime: bridge
    readonly property real edgeStart: {
        const value = Number(config.interaction.clickEdgeStart);
        return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0.9;
    }

    SwiftlyBridge {
        id: bridge
        requirePointerZone: true
        onSettingsRequested: controller.openSettings()
    }
    SwiftlySettings { id: settings; bridge: controller.runtime }

    function openSettings() {
        settings.visible = true;
        settings.requestActivate();
    }

    function stackForWidget(widgetId, monitorName) {
        return config.stacks.find(s => s.enabled
            && (!s.monitor || s.monitor === monitorName)
            && s.widgets && s.widgets.some(w => w.id === widgetId));
    }

    function isVisible(widgetId, monitorName) {
        // Read transient indices here so visibility stays bound to switching.
        const currentIndices = indices;
        const stack = stackForWidget(widgetId, monitorName);
        return !stack || stack.widgets[bridge.indexFor(stack.id)].id === widgetId;
    }

    function canSwitch(widgetId, monitorName) {
        const stack = stackForWidget(widgetId, monitorName);
        return !!stack && stack.widgets.length > 1;
    }

    function next(widgetId, monitorName) {
        const stack = stackForWidget(widgetId, monitorName);
        if (stack) bridge.step(stack.id, 1);
    }
}
