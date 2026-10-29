import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../"
import "../reusables"
ColumnLayout {
    id: panel
    property bool registered: false
    function registerReader() {
        if (visible && !registered) { registered=true; BatteryState.views++; }
        else if (!visible && registered) { registered=false; BatteryState.views=Math.max(0,BatteryState.views-1); }
    }
    onVisibleChanged: registerReader()
    Component.onCompleted: registerReader()
    Component.onDestruction: if (registered) BatteryState.views=Math.max(0,BatteryState.views-1)
    spacing: 16
    readonly property color batteryColor: BatteryState.charging ? ThemeBackend.green : BatteryState.percent <= 20 ? ThemeBackend.peach : ThemeBackend.primary
    Label { text: "Battery"; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 20; font.bold: true }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 218
        radius: ThemeBackend.borderRadius; clip: true
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
        FluidWave {
            anchors.fill: parent
            radius: parent.radius
            fillLevel: BatteryState.percent / 100
            waveAmp: !Motion.reduced && BatteryState.percent > 0 && BatteryState.percent < 100 ? 6 : 0
            color1: Qt.alpha(panel.batteryColor, .22); color2: Qt.alpha(panel.batteryColor, .22)
            vertical: 0
            property real wavePhase: 0
            phase: wavePhase
            NumberAnimation on wavePhase { from: 0; to: Math.PI*2; duration: BatteryState.charging ? 1200 : 2200; loops: Animation.Infinite; running: panel.visible && !Motion.reduced && BatteryState.percent > 0 && BatteryState.percent < 100 }
        }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 14
            RowLayout {
                Layout.fillWidth: true; spacing: 16
                Label { text: BatteryState.charging ? "󰂄" : "󰁹"; color: ThemeBackend.text; font.family: ThemeBackend.iconFont; font.pixelSize: 32 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Label { text: BatteryState.ready ? BatteryState.percent + "%" : "—"; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 26; font.bold: true }
                    Label { text: BatteryState.timeLeft; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.Wrap }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: "Power · " + (BatteryState.watts > 0 ? BatteryState.watts.toFixed(1) + " W" : "Not reported"); color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 12 }
                Label { Layout.fillWidth: true; text: "Health · " + (BatteryState.health >= 0 ? BatteryState.health.toFixed(1) + "%" : "Not reported"); color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 12 }
            }
            Switch {
                Layout.fillWidth: true; implicitHeight: 38
                options: BatteryState.profileOptions
                currentIndex: BatteryState.profile === PowerProfile.PowerSaver ? 0 : BatteryState.profile === PowerProfile.Performance ? 2 : 1
                onValueChanged: (index,value) => BatteryState.selectProfile(index)
                baseColor: ThemeBackend.surface0; accentColor: panel.batteryColor; textColor: ThemeBackend.text; activeTextColor: ThemeBackend.crust
            }
        }
    }
    Item { Layout.fillHeight: true }
}
