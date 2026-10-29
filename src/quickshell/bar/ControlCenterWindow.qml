import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables"
Variants {
    model: Quickshell.screens
    delegate: PanelWindow {
        id: window
        required property var modelData
        screen: modelData
        readonly property bool requested: ControlCenterController.visible && ControlCenterController.screen === modelData
        property real reveal: requested ? 1 : 0
        Behavior on reveal { enabled: !Motion.reduced; SpringAnimation { id: revealSpring; spring: 3.2; damping: .28; mass: 1; epsilon: .002 } }
        visible: requested || revealSpring.running
        onRequestedChanged: { if (requested && !panelHover.hovered) outsideTimer.restart(); else if (!requested) outsideTimer.stop(); }
        Timer { id: outsideTimer; interval: 1000; onTriggered: if (window.requested && !panelHover.hovered) ControlCenterController.close() }
        anchors.top: true; anchors.right: true
        margins.top: 58; margins.right: 16
        implicitWidth: 506
        implicitHeight: Math.min(100,modelData.height-90)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "qs-control-center-coloros-" + modelData.name
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: requested ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        Shortcut { sequence: "Escape"; enabled: window.requested; onActivated: ControlCenterController.close() }
        Item {
            anchors.fill: parent; anchors.margins: 5
            HoverHandler { id: panelHover; onHoveredChanged: { if (hovered) outsideTimer.stop(); else if (window.requested) outsideTimer.restart(); } }
            opacity: Math.max(0,Math.min(1,window.reveal))
            transformOrigin: Item.TopRight
            scale: .94 + .06 * window.reveal
            transform: Translate { y: -12 * (1-window.reveal) }
            ControlCenterPanel {
                anchors.fill: parent; anchors.margins: 8
            }
        }
    }
}
