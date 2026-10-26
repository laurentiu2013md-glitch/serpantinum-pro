import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import "../"
import "../reusables"
ColumnLayout {
    id: panel
    spacing: 12
    property bool registered: false
    property var forgetDevice: null
    function updateRegistration() {
        if (visible && !registered) { registered = true; BluetoothController.views++; }
        else if (!visible && registered) { registered = false; BluetoothController.views = Math.max(0, BluetoothController.views - 1); }
    }
    onVisibleChanged: updateRegistration()
    Component.onCompleted: updateRegistration()
    Component.onDestruction: if (registered) BluetoothController.views = Math.max(0, BluetoothController.views - 1)
    component Caption: Label { textFormat: Text.PlainText; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; elide: Text.ElideRight }
    component Action: Button {
        id: button
        font.family: ThemeBackend.fontFamily
        contentItem: Caption { text: button.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { radius: 12; color: Qt.alpha(ThemeBackend.mauve, button.down ? 0.3 : button.hovered ? 0.22 : 0.12); Behavior on color { ColorAnimation { duration: Motion.hover } } }
        scale: down ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: Motion.press; easing.type: Easing.OutCubic } }
        opacity: enabled ? 1 : 0.4
        padding: 10
    }
    RowLayout {
        Layout.fillWidth: true
        Caption { text: "󰂯  Bluetooth"; font.pixelSize: 20; font.bold: true; Layout.fillWidth: true }
        MaterialSwitch {
            checked: { const operationRevision = BluetoothController.status; return BluetoothController.adapter && BluetoothController.adapter.enabled; }
            enabled: BluetoothController.adapter && !BluetoothController.busy
            Accessible.name: "Bluetooth power"
            onClicked: BluetoothController.run(checked ? "power-on" : "power-off", null)
        }
        Action { text: BluetoothController.adapter && BluetoothController.adapter.discovering ? "Stop" : "Scan"; enabled: BluetoothController.adapter && BluetoothController.adapter.enabled && !BluetoothController.busy; onClicked: BluetoothController.adapter.discovering ? BluetoothController.stopScan() : BluetoothController.scan() }
    }
    Caption { Layout.fillWidth: true; text: !BluetoothController.adapter ? "No Bluetooth adapter found" : !BluetoothController.adapter.enabled ? "Bluetooth is off" : BluetoothController.status || "Select a device to connect"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; opacity: 0.8; Accessible.role: Accessible.AlertMessage }
    ClippingRectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: pairingContent.implicitHeight + 20
        visible: BluetoothController.pairingRequest.type !== undefined
        radius: ThemeBackend.cardRadius
        color: "transparent"
        ColumnLayout {
            id: pairingContent
            anchors.fill: parent; anchors.margins: 10
            Caption { text: "Bluetooth pairing confirmation"; font.bold: true; Layout.fillWidth: true }
            Caption { text: BluetoothController.pairingRequest.passkey || "Allow this device to pair?"; font.pixelSize: 18; Layout.fillWidth: true }
            TextField { id: pairingCode; Layout.fillWidth: true; visible: ["pin", "passkey"].indexOf(BluetoothController.pairingRequest.type) !== -1; placeholderText: "Pairing code"; Accessible.name: "Bluetooth pairing code" }
            RowLayout {
                Action { text: "Reject"; onClicked: BluetoothController.confirm(false, "") }
                Action { text: "Confirm"; onClicked: BluetoothController.confirm(true, pairingCode.text) }
            }
        }
    }
    RowLayout {
        visible: panel.forgetDevice !== null
        Caption { Layout.fillWidth: true; text: "Forget this device? You will need to pair it again."; wrapMode: Text.Wrap }
        Action { text: "Cancel"; onClicked: panel.forgetDevice = null }
        Action { text: "Forget"; onClicked: { BluetoothController.run("forget", panel.forgetDevice); panel.forgetDevice = null; } }
    }
    ClippingRectangle {
        Layout.fillWidth: true; Layout.fillHeight: true
        radius: ThemeBackend.cardRadius
        color: "transparent"
        ScrollView {
            anchors.fill: parent; anchors.margins: 8
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: parent.width
                spacing: 8
                Repeater {
                    model: [true, false]
                    ColumnLayout {
                        id: section
                        required property bool modelData
                        Layout.fillWidth: true
                        readonly property var devices: BluetoothController.devices.filter(d => Boolean(d.paired || d.bonded || d.connected) === modelData)
                        Caption { text: section.modelData ? "Paired and connected" : "Seen devices"; font.bold: true; opacity: 0.7 }
                        Caption { text: "No devices"; visible: section.devices.length === 0; opacity: 0.5 }
                        Repeater {
                            model: section.devices
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 72
                                radius: 14
                                color: "transparent"
                                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: ThemeBackend.borderColor }
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 10; spacing: 10
                                    Caption { text: modelData.icon && modelData.icon.indexOf("audio") !== -1 ? "󰋋" : "󰂯"; font.family: ThemeBackend.iconFont; font.pixelSize: 24 }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Caption { Layout.fillWidth: true; text: modelData.name || modelData.deviceName || modelData.address; font.bold: true }
                                        Caption { Layout.fillWidth: true; text: (modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Available") + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : ""); font.pixelSize: 11; opacity: 0.65 }
                                    }
                                    Action { text: modelData.connected ? "Disconnect" : modelData.paired || modelData.bonded ? "Connect" : "Pair"; enabled: BluetoothController.adapter && BluetoothController.adapter.enabled && !BluetoothController.busy; onClicked: BluetoothController.run(modelData.connected ? "disconnect" : modelData.paired || modelData.bonded ? "connect" : "pair", modelData) }
                                    Action { text: "×"; visible: modelData.paired || modelData.bonded; Accessible.name: "Forget device"; enabled: !BluetoothController.busy; onClicked: panel.forgetDevice = modelData }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
