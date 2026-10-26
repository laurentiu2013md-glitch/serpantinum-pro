pragma ComponentBehavior: Bound
// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material as M3

Rectangle {
    id: card
    required property var bridge
    required property var stack
    readonly property var widgets: stack.widgets || []
    readonly property int selectedIndex: bridge.indexFor(stack.id)
    readonly property string preset: bridge.animationPreset
    readonly property int duration: preset === "none" ? 0 : bridge.animationDuration
    readonly property var theme: bridge.config.theme
    readonly property real switchZoneStart: width * (Number(bridge.config.interaction.clickEdgeStart) || 0.95)
    readonly property alias switchArea: switching
    readonly property alias contentArea: content
    property alias widgetRepeater: faces
    signal settingsRequested()
    implicitWidth: 340
    implicitHeight: 144
    color: "transparent"
    radius: 0
    border.width: 0
    clip: true
    SwiftlyPalette { id: colors; theme: card.theme }

    function inSwitchZone(x) { return width > 0 && x >= switchZoneStart && x < width; }
    function scrollAt(x, delta) {
        if (!inSwitchZone(x) || !bridge.config.interaction.scrollEnabled || delta === 0) return false;
        bridge.step(stack.id, (delta < 0 ? 1 : -1) * (bridge.config.interaction.scrollInvert ? -1 : 1));
        return true;
    }
    function swipeFrom(x, dx, dy) {
        if (!inSwitchZone(x) || !bridge.config.interaction.swipeEnabled) return false;
        const delta = Math.abs(dx) >= Math.abs(dy) ? dx : dy;
        const threshold = Math.max(1, Number(bridge.config.interaction.swipeThreshold) || 48);
        if (Math.abs(delta) < threshold) return false;
        bridge.step(stack.id, delta < 0 ? 1 : -1);
        return true;
    }

    Item {
        id: content
        anchors.fill: parent
        Repeater {
            id: faces
            model: card.widgets
            delegate: WidgetFace {
                required property int index
                required property var modelData
                widget: modelData
                theme: card.theme
                width: parent.width
                height: parent.height
                enabled: index === card.selectedIndex
                visible: opacity > 0
                opacity: index === card.selectedIndex ? 1 : 0
                x: card.preset === "slide" && index !== card.selectedIndex
                        ? (index < card.selectedIndex ? -24 : 24) : 0
                scale: card.preset === "zoom" && index !== card.selectedIndex ? 0.9 : 1
                Behavior on opacity { NumberAnimation { duration: card.duration; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: card.duration; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: card.duration; easing.type: Easing.OutCubic } }
            }
        }
        Label {
            anchors.centerIn: parent
            visible: card.widgets.length === 0
            text: "No widgets"
            color: card.theme.muted || "#FFAFB7CC"
        }
    }

    // Only this physical strip accepts local switching input. A swipe may leave
    // the strip after starting here; it is evaluated against its starting point.
    MouseArea {
        id: switching
        z: 100
        objectName: "switchingStrip"
        x: card.switchZoneStart
        width: card.width - x
        height: card.height
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        property real startX: 0
        property real startY: 0
        property bool swipeHandled: false
        onEntered: card.bridge.pointerStackId = card.stack.id
        onExited: { if (card.bridge.pointerStackId === card.stack.id) card.bridge.pointerStackId = ""; }
        onPressed: mouse => { startX = mouse.x; startY = mouse.y; swipeHandled = false; }
        onReleased: mouse => { swipeHandled = card.swipeFrom(x + startX, mouse.x - startX, mouse.y - startY); }
        onClicked: { if (!swipeHandled) card.bridge.step(card.stack.id, 1); }
        onWheel: wheel => {
            const delta = wheel.angleDelta.y || wheel.angleDelta.x || wheel.pixelDelta.y || wheel.pixelDelta.x;
            if (!wheelCooldown.running && card.scrollAt(x + wheel.x, delta)) wheelCooldown.start();
            wheel.accepted = !!card.bridge.config.interaction.scrollEnabled;
        }
        Timer { id: wheelCooldown; interval: 140 }

    }
    Component.onDestruction: {
        if (bridge.pointerStackId === stack.id) bridge.pointerStackId = "";
    }
}
