pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel
    required property var bridge
    required property var stack
    readonly property var position: stack.position || {}
    readonly property string anchor: position.anchor || "top-right"
    signal settingsRequested()
    implicitWidth: Math.max(120, Number((stack.size || {}).width) || 400)
    implicitHeight: Math.max(100, Number((stack.size || {}).height) || 240)
    color: "transparent"
    WlrLayershell.namespace: "swiftly-" + stack.id
    WlrLayershell.layer: WlrLayer.Bottom
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: panel.anchor.startsWith("top")
        bottom: panel.anchor.startsWith("bottom")
        left: panel.anchor.endsWith("left")
        right: panel.anchor.endsWith("right")
    }
    margins {
        top: Math.max(0, Number(panel.position.y) || 0)
        bottom: Math.max(0, Number(panel.position.y) || 0)
        left: Math.max(0, Number(panel.position.x) || 0)
        right: Math.max(0, Number(panel.position.x) || 0)
    }
    SwiftlyCard {
        anchors.fill: parent
        bridge: panel.bridge
        stack: panel.stack
        onSettingsRequested: panel.settingsRequested()
    }
}
