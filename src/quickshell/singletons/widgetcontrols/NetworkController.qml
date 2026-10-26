pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../../"
Item {
    id: controller
    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wired: devices.filter(d => d.type === DeviceType.Wired)
    readonly property var networks: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values.slice().filter(n => n.name).sort((a,b) => Number(b.connected) - Number(a.connected) || Number(b.known) - Number(a.known) || b.signalStrength - a.signalStrength) : []
    readonly property bool powered: Networking.wifiEnabled
    property int views: 0
    property string status: ""
    property var pending: null
    readonly property bool busy: pending !== null
    readonly property bool scanning: scanTimer.running
    function securityName(network) { return WifiSecurityType.toString(network.security); }
    function needsPassword(network) {
        return !network.known && [WifiSecurityType.StaticWep, WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].indexOf(network.security) !== -1;
    }
    function enterprise(network) { return [WifiSecurityType.WpaEap, WifiSecurityType.Wpa2Eap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.DynamicWep, WifiSecurityType.Leap].indexOf(network.security) !== -1; }
    function scan() {
        if (!wifiDevice || !powered) return;
        wifiDevice.scannerEnabled = true;
        scanTimer.restart();
    }
    function stopScan() { scanTimer.stop(); if (wifiDevice) wifiDevice.scannerEnabled = false; }
    onViewsChanged: { if (views > 0) scan(); else stopScan(); }
    onPoweredChanged: { if (!powered) stopScan(); else if (views > 0) scan(); }
    function power(enabled) { Networking.wifiEnabled = enabled; status = ""; }
    function connectNetwork(network, password) {
        if (!network || busy) return;
        pending = network; status = "Connecting to " + network.name + "…";
        connectionTimer.restart();
        try { if (password) network.connectWithPsk(password); else network.connect(); }
        catch(error) { failed(String(error)); }
    }
    function failed(message) { pending = null; connectionTimer.stop(); status = message; IslandController.notify("Network", message, 50, 2500); }
    Timer { id: scanTimer; interval: 8000; onTriggered: if (controller.wifiDevice) controller.wifiDevice.scannerEnabled = false }
    Timer { id: connectionTimer; interval: 35000; onTriggered: controller.failed("Connection timed out. Check the password or try again.") }
    Connections {
        target: controller.pending
        function onConnectedChanged() {
            if (controller.pending && controller.pending.connected) {
                const name = controller.pending.name;
                controller.pending = null; connectionTimer.stop();
                controller.status = "Connected to " + name;
                IslandController.notify("Network", controller.status, 50, 2000);
            }
        }
        function onConnectionFailed(reason) { controller.failed(ConnectionFailReason.toString(reason)); }
    }
    IpcHandler {
        target: "network"
        function state(): string { return JSON.stringify({present:!!controller.wifiDevice,powered:controller.powered,scanning:controller.scanning,busy:controller.busy,views:controller.views,status:controller.status,networks:controller.networks.map(n => ({name:n.name,connected:n.connected,known:n.known,signal:n.signalStrength,security:controller.securityName(n)})),wired:controller.wired.map(d=>({name:d.name,connected:d.connected}))}); }
    }
}
