pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../"

Item {
    id: root
    // Only visible liquid surfaces subscribe. No screen capture or disk snapshots.
    property int consumers: 0
    property var surfaces: []
    property int geometryRevision: 0
    function registerSurface(surface) {
        if (surfaces.indexOf(surface) >= 0) return;
        surfaces.push(surface);
        consumers = surfaces.length;
    }
    function unregisterSurface(surface) {
        const index = surfaces.indexOf(surface);
        if (index >= 0) surfaces.splice(index, 1);
        consumers = surfaces.length;
    }
    function intersects(host, screen, data) {
        const x = data.at[0] - screen.x, y = data.at[1] - screen.y;
        for (const surface of surfaces) {
            if (!surface || !surface.active || surface.hostWindow !== host) continue;
            const scale = surface.imageScale || 1;
            const left = -surface.imageX / scale, top = -surface.imageY / scale;
            if (x < left + surface.width / scale && x + data.size[0] > left &&
                y < top + surface.height / scale && y + data.size[1] > top) return true;
        }
        return false;
    }
    readonly property bool enabled: consumers > 0 && ThemeBackend.liquidGlass && !GameMode.enabled
    property var registry: []
    function sceneFor(screen, host) {
        if (!screen || !host) return null;
        for (const scene of registry) {
            if (scene && scene.host === host && scene.modelData.name === screen.name) return scene;
        }
        const scene = sceneComponent.createObject(host.contentItem, {modelData: screen, host: host});
        registry.push(scene);
        return scene;
    }
    Timer {
        interval: 250; repeat: true; running: root.enabled
        onTriggered: { Hyprland.refreshToplevels(); root.geometryRevision++; }
    }
    IpcHandler {
        target: "liveGlass"
        function state(): string {
            let outputs = [];
            for (let i = 0; i < registry.length; i++) {
                const scene = registry[i];
                if (scene) outputs.push({screen: scene.modelData.name, windows: scene.windows.length, ready: scene.readyCount});
            }
            return JSON.stringify({enabled: root.enabled, consumers: root.consumers, outputs: outputs});
        }
    }
    Component {
        id: sceneComponent
        Item {
            id: scene
            required property var modelData
            required property var host
            readonly property bool capturing: root.enabled && host.visible
            width: modelData.width; height: modelData.height
            visible: true
            // Keep the shared texture renderable without painting over shell controls.
            x: -100000
            layer.enabled: scene.capturing
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(Math.max(1, width / 2), Math.max(1, height / 2))
            property int readyCount: {
                let count = 0;
                for (let i = 0; i < captures.count; i++) {
                    const capture = captures.itemAt(i);
                    if (capture && capture.hasContent) count++;
                }
                return count;
            }
            readonly property var monitor: Hyprland.monitors.values.find(m => m.name === modelData.name) || null
            property var windows: []
            property string windowSignature: ""
            function refreshWindows() {
                if (!scene.capturing || !monitor) {
                    if (windowSignature !== "") { windows = []; windowSignature = ""; }
                    return;
                }
                const workspace = monitor.activeWorkspace ? monitor.activeWorkspace.id : -1;
                const special = monitor.lastIpcObject.activeSpecialWorkspace;
                const next = Hyprland.toplevels.values.filter(t => {
                    const data = t.lastIpcObject;
                    return t.wayland && data && data.mapped !== false && !data.hidden &&
                        (data.monitor === monitor.id || (t.monitor && t.monitor.name === modelData.name)) &&
                        data.workspace && (data.workspace.id === workspace || (special && special.id !== 0 && data.workspace.id === special.id)) &&
                        data.at && data.size && data.size[0] > 0 && data.size[1] > 0 &&
                        root.intersects(scene.host, scene.modelData, data);
                }).sort((a,b) => {
                    const x = a.lastIpcObject, y = b.lastIpcObject;
                    if (!!x.floating !== !!y.floating) return x.floating ? 1 : -1;
                    return (y.focusHistoryID || 0) - (x.focusHistoryID || 0);
                });
                const signature = next.map(t => t.address).join(",");
                // Recreating the delegates on every geometry poll interrupts the stream.
                if (signature !== windowSignature) {
                    windowSignature = signature;
                    windows = next;
                }
            }
            onCapturingChanged: refreshWindows()
            onMonitorChanged: refreshWindows()
            Component.onCompleted: refreshWindows()
            Connections {
                target: root
                function onGeometryRevisionChanged() { scene.refreshWindows(); }
            }

            Repeater {
                id: captures
                model: scene.windows
                delegate: ScreencopyView {
                    id: capture
                    required property var modelData
                    readonly property var geometry: modelData.lastIpcObject
                    x: geometry.at[0] - scene.modelData.x
                    y: geometry.at[1] - scene.modelData.y
                    width: geometry.size[0]; height: geometry.size[1]
                    captureSource: scene.capturing ? modelData.wayland : null
                    paintCursor: false
                    live: false
                    visible: hasContent
                    constraintSize: Qt.size(Math.max(1, width / 2), Math.max(1, height / 2))
                    Timer {
                        interval: 150; running: capture.captureSource !== null && Motion.reduced
                        onTriggered: capture.captureFrame()
                    }
                    Timer {
                        interval: 33; repeat: true; running: scene.capturing && !Motion.reduced
                        triggeredOnStart: false
                        onTriggered: capture.captureFrame()
                    }

                }
            }
        }
    }
}
