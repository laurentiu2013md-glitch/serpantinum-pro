import QtQuick
import QtQuick.Effects
import "../"
Item {
    id: root
    property string artwork: ""
    property bool playing: false
    property bool registered: false
    readonly property real energy: reacting && Cava.barLevels.length ? Cava.barLevels.reduce((sum, level) => sum + level, 0) / Cava.barLevels.length : 0
    readonly property bool reacting: visible && playing && !Motion.reduced
    function subscription() {
        if (reacting && !registered) { Cava.registerConsumer(); registered = true; }
        else if (!reacting && registered) { Cava.unregisterConsumer(); registered = false; }
    }
    onReactingChanged: subscription()
    Component.onCompleted: subscription()
    Component.onDestruction: if (registered) Cava.unregisterConsumer()
    ArtworkBackdrop {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12; width: parent.width * .72; height: Math.min(240, parent.height * .52)
        artwork: root.visible && !GameMode.enabled ? root.artwork : ""
        adaptiveContrast: false; backgroundOpacity: .30; blurRadius: 64; blurStrength: 1
        opacity: root.artwork && !GameMode.enabled ? 1 : 0
        scale: 1 + (root.reacting ? root.energy * .08 : 0)
        Behavior on opacity { NumberAnimation { duration: Motion.duration(650) } }
        Behavior on scale { NumberAnimation { duration: Motion.duration(160) } }
    }
}
