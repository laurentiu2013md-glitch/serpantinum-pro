import QtQuick
import Quickshell
import QtQuick.Layouts
import QtQuick.Controls
import "../"

Item {
    id: osd
    property bool compact: false
    readonly property string kind: OsdController.kind
    readonly property bool toggleKind: ["capslock", "numlock", "airplane"].indexOf(kind) !== -1
    readonly property bool active: OsdController.stateVal === "on" || OsdController.stateVal === "1" || OsdController.stateVal === "true"
    readonly property bool muted: kind === "mic" ? OsdController.sysMicMuted : kind === "volume" && OsdController.sysMuted
    readonly property real level: kind === "brightness" ? OsdController.briVal : kind === "mic" ? OsdController.sysMicVolume : OsdController.sysVolume
    readonly property string title: kind === "brightness" ? "Brightness" : kind === "mic" ? "Microphone" : kind === "capslock" ? "Caps Lock" : kind === "numlock" ? "Num Lock" : kind === "airplane" ? "Airplane mode" : "Volume"
    readonly property string icon: kind === "brightness" ? "󰃠" : kind === "mic" ? (muted ? "󰍭" : "󰍬") : kind === "capslock" ? "󰪛" : kind === "numlock" ? "󰎠" : kind === "airplane" ? (active ? "󰀝" : "󰀞") : muted ? "󰝟" : level > 50 ? "󰕾" : "󰖀"
    implicitHeight: compact ? 76 : 100
    function applyLevel(value) {
        if (kind === "brightness") brightness.target = Math.round(value);
        else if (kind === "mic" && OsdController.activeSource) {
            if (muted && value > 0) Audio.toggleMute(OsdController.activeSource);
            Audio.setVolume(OsdController.activeSource, value);
        } else if (kind === "volume" && OsdController.activeSink) {
            if (muted && value > 0) Audio.toggleMute(OsdController.activeSink);
            Audio.setVolume(OsdController.activeSink, value);
        }
        if (kind === "brightness") brightness.restart();
        OsdController.restartTimer();
    }
    Timer {
        id: brightness
        property int target: -1
        interval: 100
        onTriggered: if (target >= 0) {
            Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/brightness.sh", "set", String(target)]);
            target = -1;
        }
    }
    HoverHandler {
        onHoveredChanged: {
            OsdController.isHovered = hovered;
            if (hovered) OsdController.cancelHide(); else OsdController.requestHide();
        }
    }
    RowLayout {
        anchors.fill: parent
        anchors.margins: osd.compact ? 12 : 18
        spacing: 16
        Text {
            text: osd.icon; color: ThemeBackend.text
            font.family: ThemeBackend.iconFont; font.pixelSize: 28
            Accessible.name: osd.title
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                Layout.fillWidth: true
                Text { text: osd.title; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Text { text: osd.toggleKind ? (osd.active ? "On" : "Off") : osd.muted ? "Muted" : Math.round(osd.level) + "%"; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 14 }
            }
            Slider {
                id: slider
                visible: !osd.toggleKind
                Layout.fillWidth: true; Layout.preferredHeight: 24
                from: 0; to: 100; value: Math.min(100, osd.level)
                onMoved: osd.applyLevel(value)
                Accessible.name: osd.title
                background: Rectangle {
                    x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: slider.availableWidth; height: 6; radius: 3
                    color: Qt.alpha(ThemeBackend.text, .14)
                    Rectangle { width: Math.max(0, slider.visualPosition * parent.width); height: parent.height; radius: 3; color: osd.muted ? Qt.alpha(ThemeBackend.text, .35) : ThemeBackend.mauve }
                }
                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: 5; height: 20; radius: 2.5; color: ThemeBackend.text
                }
            }
        }
    }
}
