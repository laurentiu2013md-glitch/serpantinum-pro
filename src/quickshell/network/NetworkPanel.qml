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
    property var passwordNetwork: null
    property var forgetNetwork: null
    function registration() {
        if (visible && !registered) { registered = true; NetworkController.views++; }
        else if (!visible && registered) { registered = false; NetworkController.views = Math.max(0, NetworkController.views - 1); password.text = ""; passwordNetwork = null; forgetNetwork = null; }
    }
    onVisibleChanged: registration()
    Component.onCompleted: registration()
    Component.onDestruction: if (registered) NetworkController.views = Math.max(0, NetworkController.views - 1)
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
        Caption { text: "󰤨  Network"; font.pixelSize: 20; font.bold: true; Layout.fillWidth: true }
        MaterialSwitch { checked: NetworkController.powered; enabled: !!NetworkController.wifiDevice && !NetworkController.busy; Accessible.name: "Wi-Fi power"; onClicked: NetworkController.power(checked) }
        Action { text: NetworkController.scanning ? "Stop" : "Scan"; enabled: !!NetworkController.wifiDevice && NetworkController.powered; onClicked: NetworkController.scanning ? NetworkController.stopScan() : NetworkController.scan() }
    }
    Caption { Layout.fillWidth: true; font.pixelSize: 12; opacity: 0.8; wrapMode: Text.Wrap; elide: Text.ElideNone; Accessible.role: Accessible.AlertMessage; text: NetworkController.status || (!NetworkController.wifiDevice ? "No Wi-Fi adapter found" : !NetworkController.powered ? "Wi-Fi is off" : "Select a network to connect") }
    ColumnLayout {
        Layout.fillWidth: true; visible: panel.passwordNetwork !== null
        Caption { Layout.fillWidth: true; text: panel.passwordNetwork ? "Password for " + panel.passwordNetwork.name : ""; font.bold: true }
        TextField { id: password; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Wi-Fi password"; Accessible.name: "Wi-Fi password"; onAccepted: connectButton.clicked() }
        RowLayout {
            Action { text: "Cancel"; onClicked: { password.text = ""; panel.passwordNetwork = null; } }
            Action { id: connectButton; text: "Connect"; enabled: password.text.length > 0 && !NetworkController.busy; onClicked: { if (!enabled) return; NetworkController.connectNetwork(panel.passwordNetwork, password.text); password.text = ""; panel.passwordNetwork = null; } }
        }
    }
    RowLayout {
        Layout.fillWidth: true; visible: panel.forgetNetwork !== null
        Caption { Layout.fillWidth: true; text: "Forget the saved network?"; wrapMode: Text.Wrap }
        Action { text: "Cancel"; onClicked: panel.forgetNetwork = null }
        Action { text: "Forget"; onClicked: { if (panel.forgetNetwork) panel.forgetNetwork.forget(); panel.forgetNetwork = null; } }
    }
    ClippingRectangle {
        Layout.fillWidth: true; Layout.fillHeight: true
        color: "transparent"; radius: ThemeBackend.cardRadius
        ScrollView {
            anchors.fill: parent; clip: true; contentWidth: availableWidth
            ColumnLayout {
                width: parent.width; spacing: 8
                Caption { text: "Wi-Fi networks"; font.bold: true; opacity: 0.7 }
                Caption { text: NetworkController.scanning ? "Looking for networks…" : "No networks available"; visible: NetworkController.networks.length === 0; opacity: 0.6 }
                Repeater {
                    model: NetworkController.networks
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 72; color: "transparent"
                        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: ThemeBackend.borderColor }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            Caption { text: modelData.signalStrength > 0.7 ? "󰤨" : modelData.signalStrength > 0.4 ? "󰤥" : "󰤟"; font.family: ThemeBackend.iconFont; font.pixelSize: 24 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Caption { Layout.fillWidth: true; text: modelData.name; font.bold: true }
                                Caption { Layout.fillWidth: true; font.pixelSize: 11; opacity: 0.65; text: (modelData.connected ? "Connected" : modelData.stateChanging ? "Connecting…" : modelData.known ? "Saved" : "Available") + " · " + Math.round(modelData.signalStrength * 100) + "% · " + NetworkController.securityName(modelData) }
                            }
                            Action {
                                text: modelData.connected ? "Disconnect" : "Connect"
                                enabled: NetworkController.powered && !NetworkController.busy && !modelData.stateChanging
                                onClicked: {
                                    if (modelData.connected) modelData.disconnect();
                                    else if (NetworkController.enterprise(modelData) && !modelData.known) { NetworkController.status = "Configure enterprise credentials in the advanced network editor."; Quickshell.execDetached(["kitty", "nmtui"]); }
                                    else if (NetworkController.needsPassword(modelData)) { panel.passwordNetwork = modelData; password.forceActiveFocus(); }
                                    else NetworkController.connectNetwork(modelData, "");
                                }
                            }
                            Action { text: "×"; visible: modelData.known; enabled: !NetworkController.busy; Accessible.name: "Forget saved network"; onClicked: panel.forgetNetwork = modelData }
                        }
                    }
                }
                Caption { text: "Ethernet"; font.bold: true; opacity: 0.7; visible: NetworkController.wired.length > 0 }
                Repeater {
                    model: NetworkController.wired
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Caption { Layout.fillWidth: true; text: "󰈀  " + modelData.name + (modelData.connected ? " · Connected" : " · Disconnected") }
                        Action { text: modelData.connected ? "Disconnect" : "Connect"; enabled: !!modelData.network; onClicked: modelData.connected ? modelData.disconnect() : modelData.network.connect() }
                    }
                }
            }
        }
    }
    Action { text: "Advanced network settings"; onClicked: Quickshell.execDetached(["kitty", "nmtui"]) }
}
