import QtQuick
import QtQuick.Effects
import Quickshell.Io
import "../"
Item {
    id: root
    property string artwork: ""
    property real backgroundOpacity: .5
    property bool adaptiveContrast: Config.getSetting("coloros", {}).artworkContrast !== false
    property int blurRadius: 32
    property real blurStrength: .75
    property real luminance: .35
    readonly property real scrimOpacity: adaptiveContrast ? Math.min(.65, .12 + luminance * .50) : 0
    property var current: null
    property string queued: ""
    property string requested: ""
    function loadLatest() {
        if (!artwork) return;
        if (fade.running) { queued = artwork; return; }
        const url = Qt.resolvedUrl(artwork).toString();
        if (current && current.source.toString() === url) return;
        const incoming = current === first ? second : first;
        requested = url;
        incoming.opacity = 0; incoming.z = 2;
        if (current) current.z = 1;
        incoming.source = url;
        if (incoming.status === Image.Ready) ready(incoming);
    }
    function ready(image) {
        if (image.source.toString() !== requested || fade.running || image === current) return;
        fade.target = image; fade.restart();
    }
    onArtworkChanged: loadLatest()
    Component.onCompleted: loadLatest()
    Item {
        anchors.fill: parent
        opacity: root.backgroundOpacity
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blurMax: root.blurRadius; blur: root.blurStrength; autoPaddingEnabled: false }
        Image { id: first; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(720,720); opacity: 0; onStatusChanged: if (status === Image.Ready) root.ready(first) }
        Image { id: second; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(720,720); opacity: 0; onStatusChanged: if (status === Image.Ready) root.ready(second) }
    }
    Rectangle {
        anchors.fill: parent; color: "#000000"; opacity: root.scrimOpacity
        Behavior on opacity { NumberAnimation { duration: Motion.duration(650) } }
    }
    NumberAnimation {
        id: fade; property: "opacity"; from: 0; to: 1; duration: Motion.duration(Config.getSetting("coloros", {}).artworkCrossfade === false ? 0 : 650); easing.type: Easing.InOutCubic
        onFinished: {
            const old = root.current;
            root.current = target;
            if (old && old !== target) old.opacity = 0;
            if (root.adaptiveContrast) analyse.restart();
            if (root.queued) { root.queued = ""; root.loadLatest(); }
        }
    }
    Timer {
        id: analyse; interval: 50
        onTriggered: {
            if (metrics.running) { restart(); return; }
            metrics.command = ["python3", Caching.serpantinumDir + "/scripts/artwork_luminance.py", root.current.source.toString()];
            metrics.running = true;
        }
    }
    Process {
        id: metrics
        stdout: StdioCollector { onStreamFinished: { try { const data = JSON.parse(text); if (root.current && data.url === root.current.source.toString()) root.luminance = data.luminance; } catch(error) {} } }
    }
}
