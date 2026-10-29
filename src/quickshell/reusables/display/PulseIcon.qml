import QtQuick
import "../../"
Item {
    id: root
    property string text: ""
    property bool scanning: false
    property color accent: ThemeBackend.primary
    readonly property bool effectsEnabled: !Motion.reduced && Config.getSetting("coloros", {}).connectionAnimations !== false
    onEffectsEnabledChanged: if (!effectsEnabled) { ring.stop(); bounce.stop(); progress = 1; pop = 1; }
    property real progress: 1
    property real pop: 1
    implicitWidth: 36
    implicitHeight: 36
    function pulse() { if (visible && root.effectsEnabled) { ring.restart(); bounce.restart(); } }
    onScanningChanged: if (scanning) pulse()
    onVisibleChanged: if (!visible) { ring.stop(); bounce.stop(); progress = 1; pop = 1; }
    Connections {
        target: Motion
        function onReducedChanged() { if (Motion.reduced) { ring.stop(); bounce.stop(); root.progress = 1; root.pop = 1; } }
    }
    Timer { interval: 1200; repeat: true; running: root.visible && root.scanning && root.effectsEnabled; onTriggered: root.pulse() }
    NumberAnimation { id: ring; target: root; property: "progress"; from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: bounce
        NumberAnimation { target: root; property: "pop"; from: 0.8; to: 1.12; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "pop"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }
    Repeater {
        model: 2
        Rectangle {
            required property int index
            readonly property real p: Math.max(0, Math.min(1, root.progress * 1.3 - index * .3))
            anchors.centerIn: parent
            width: parent.width * (.45 + .55 * p); height: width; radius: width / 2
            color: "transparent"; border.width: 1.2; border.color: root.accent
            opacity: root.progress < 1 && root.effectsEnabled ? (1 - p) * .6 : 0
        }
    }
    Text {
        anchors.centerIn: parent
        text: root.text; font.family: ThemeBackend.iconFont; font.pixelSize: 24
        color: ThemeBackend.text; scale: root.pop
    }
}
