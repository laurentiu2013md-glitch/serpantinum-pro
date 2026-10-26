// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: bridge
    property alias config: adapter
    property var indices: ({})
    // The bundled GUI enables this gate for compositor swipe IPC too.
    property bool requirePointerZone: false
    property string pointerStackId: ""
    property bool widgetsReady: true
    readonly property string generation: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    readonly property var animationPresets: ["fade", "slide", "zoom", "none"]
    readonly property string animationPreset: animationPresets.indexOf(adapter.interaction.animationPreset) >= 0
            ? adapter.interaction.animationPreset : "fade"
    readonly property int animationDuration: adapter.interaction.animationMs === undefined ? 220
            : Math.max(0, Math.min(2000, Number(adapter.interaction.animationMs) || 0))
    signal settingsRequested()
    signal configSaved()
    signal configSaveFailed(string message)

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
              + "/swiftly/config.json"
        watchChanges: true
        onFileChanged: reload()
        atomicWrites: true
        onLoadFailed: error => console.error("Swiftly config load failed:", error)
        onSaved: bridge.configSaved()
        onSaveFailed: error => bridge.configSaveFailed("Could not save config (error " + error + ").")
        JsonAdapter {
            id: adapter
            property int schemaVersion: 1
            property var theme: ({})
            property var interaction: ({})
            property var gestures: ({})
            property var stacks: []
        }
    }

    function stackFor(stackId) {
        return adapter.stacks.find(s => s.id === stackId);
    }
    function effectiveGestures() {
        // Match support.py's legacy defaults without modifying/saving JSON.
        return Object.assign({enabled: false, fingers: 4,
            nextDirection: "left", previousDirection: "right",
            targetStack: adapter.stacks.length ? adapter.stacks[0].id : ""},
            adapter.gestures);
    }
    function indexFor(stackId) {
        const s = stackFor(stackId);
        if (!s || !s.widgets || s.widgets.length === 0) return 0;
        const i = Object.prototype.hasOwnProperty.call(indices, stackId)
                ? indices[stackId] : s.initialIndex;
        return Math.max(0, Math.min(Math.floor(Number(i) || 0), s.widgets.length - 1));
    }
    function step(stackId, delta) {
        const s = stackFor(stackId);
        if (!s || !s.enabled || !s.widgets || s.widgets.length === 0) return;
        const n = s.widgets.length;
        const i = indexFor(stackId) + delta;
        const next = adapter.interaction.wrap ? (i % n + n) % n : Math.max(0, Math.min(i, n - 1));
        // A null prototype also makes valid IDs such as __proto__ ordinary keys.
        const copy = Object.assign(Object.create(null), indices);
        copy[stackId] = next;
        indices = copy;
    }
    // Call only from the settings GUI's explicit Save action. Reassign whole
    // var objects/arrays before calling; mutating a nested member emits no signal.
    function saveConfig() { file.writeAdapter(); }

    function saveAnimation(preset, duration) {
        if (animationPresets.indexOf(preset) < 0) return false;
        const interaction = Object.assign({}, adapter.interaction);
        interaction.animationPreset = preset;
        interaction.animationMs = Math.max(0, Math.min(2000, Math.round(Number(duration) || 0)));
        adapter.interaction = interaction;
        saveConfig();
        return true;
    }

    function saveSettings(preset, duration, stackId, width, height, position) {
        if (animationPresets.indexOf(preset) < 0 || !stackFor(stackId)
                || !Number.isInteger(width) || width < 120 || width > 8192
                || !Number.isInteger(height) || height < 100 || height > 8192) return false;
        if (position !== undefined && (!position
                || ["top-left", "top-right", "bottom-left", "bottom-right"].indexOf(position.anchor) < 0
                || !Number.isInteger(position.x) || position.x < 0 || position.x > 32768
                || !Number.isInteger(position.y) || position.y < 0 || position.y > 32768)) return false;
        const interaction = Object.assign({}, adapter.interaction);
        interaction.animationPreset = preset;
        interaction.animationMs = Math.max(0, Math.min(2000, Math.round(Number(duration) || 0)));
        const stacks = adapter.stacks.map(stack => stack.id === stackId
            ? Object.assign({}, stack, {
                size: Object.assign({}, stack.size || {}, {width: width, height: height})
            }, position === undefined ? {} : {position: Object.assign({}, stack.position || {}, position)})
            : stack);
        adapter.interaction = interaction;
        adapter.stacks = stacks;
        saveConfig();
        return true;
    }

    IpcHandler {
        target: "swiftly"
        function next(stackId: string): void { bridge.step(stackId, 1); }
        function previous(stackId: string): void { bridge.step(stackId, -1); }
        function index(stackId: string): int { return bridge.indexFor(stackId); }
        function settings(): void { bridge.settingsRequested(); }
        function status(): string {
            return JSON.stringify({generation: bridge.generation,
                ready: adapter.stacks.length > 0 && bridge.widgetsReady,
                stacks: adapter.stacks.map(s => ({id: s.id, widgets: (s.widgets || []).length}))});
        }
        function reload(): string {
            Qt.callLater(() => Quickshell.reload(true));
            return "reloading";
        }
        function swipe(direction: string, fingers: int): void {
            const g = bridge.effectiveGestures();
            // Stale compositor bindings are ignored until the helper is rerun.
            if (!g.enabled || g.fingers !== fingers) return;
            if (bridge.requirePointerZone && bridge.pointerStackId !== g.targetStack) return;
            if (direction === g.nextDirection) bridge.step(g.targetStack, 1);
            else if (direction === g.previousDirection) bridge.step(g.targetStack, -1);
        }
    }
}
