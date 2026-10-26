pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../../"
Item {
    id: controller
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values : []
    property string status: adapter ? "" : "No Bluetooth adapter"
    property string pendingAction: ""
    property var pendingDevice: null
    property var pairingRequest: ({})
    readonly property bool busy: operation.running || unblock.running
    property int views: 0
    signal feedback(string title, string detail)
    function run(action, device, alreadyUnblocked) {
        if (busy) { status = "Wait for the current Bluetooth operation"; return; }
        if (!adapter) { status = "No Bluetooth adapter"; feedback("Bluetooth", status); return; }
        if (action === "power-on" && adapter.state === BluetoothAdapterState.Blocked && !alreadyUnblocked) {
            status = "Bluetooth is software-blocked; authenticate to unblock it";
            unblock.running = true;
            return;
        }
        pendingAction = action; pendingDevice = device || null;
        const path = device ? device.dbusPath : adapter.dbusPath;
        status = action.replace("-", " ") + "…";
        operation.command = ["python3", Caching.serpantinumDir + "/scripts/coloros/bluetooth-op.py", action, path];
        operation.running = true;
    }
    function scan() {
        if (!adapter || !adapter.enabled) { status = "Turn Bluetooth on to scan"; return; }
        adapter.discovering = true; status = "Scanning for devices…"; scanTimeout.restart();
    }
    function stopScan() {
        scanTimeout.stop();
        if (adapter && adapter.discovering) adapter.discovering = false;
    }
    function confirm(accept, value) {
        agent.write(JSON.stringify({token:pairingRequest.token,accept:accept,value:value || ""}) + "\n");
        pairingRequest = ({});
    }
    Timer { id: scanTimeout; interval: 20000; onTriggered: controller.stopScan() }
    onViewsChanged: if (views <= 0) stopScan()
    Process {
        id: unblock
        command: ["pkexec", "--disable-internal-agent", "/usr/bin/rfkill", "unblock", "bluetooth"]
        onExited: code => {
            if (code === 0) Qt.callLater(() => controller.run("power-on", null, true));
            else { controller.status = "Bluetooth remains blocked: authentication was cancelled or unblocking failed"; controller.feedback("Bluetooth", controller.status); }
        }
    }
    Process {
        id: operation
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    controller.status = result.ok ? (controller.pendingAction === "scan" ? "Scanning for devices…" : "Done") : result.error;
                    controller.feedback(result.ok ? "Bluetooth" : "Bluetooth operation failed", controller.status);
                } catch(error) { controller.status = "Bluetooth operation failed"; }
            }
        }
    }
    Process {
        id: agent
        running: true
        stdinEnabled: true
        command: ["python3", Caching.serpantinumDir + "/scripts/coloros/bluetooth-agent.py"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    if (["confirm","pin","passkey","authorize","display"].indexOf(event.type) !== -1) {
                        controller.pairingRequest = event;
                        IslandController.request("bluetooth", "open", null);
                    } else if (event.type === "cancel") controller.pairingRequest = ({});
                    else if (event.type === "error") controller.status = event.message;
                } catch (error) {}
            }
        }
    }
    IpcHandler {
        target: "bluetooth"
        function power(enabled: string): void { controller.run(enabled === "true" || enabled === "on" ? "power-on" : "power-off", null); }
        function scan(): void { controller.scan(); }
        function stopScan(): void { controller.stopScan(); }
        function action(operation: string, address: string): bool {
            const device = controller.devices.find(d => d.address === address);
            if (!device) { controller.status = "Device is unavailable"; return false; }
            controller.run(operation, device); return true;
        }
        function state(): string {
            return JSON.stringify({present: !!controller.adapter, powered: !!controller.adapter && controller.adapter.enabled, blocked: !!controller.adapter && controller.adapter.state === BluetoothAdapterState.Blocked, discovering: !!controller.adapter && controller.adapter.discovering, status: controller.status,
                devices: controller.devices.map(d => ({address:d.address,name:d.name || d.deviceName,paired:d.paired,connected:d.connected,battery:d.batteryAvailable ? Math.round(d.battery * 100) : null}))});
        }
    }
    Connections {
        target: controller.adapter
        function onDiscoveringChanged() { controller.status = controller.adapter.discovering ? "Scanning for devices…" : "Scan stopped"; }
        function onEnabledChanged() { controller.feedback("Bluetooth", controller.adapter.enabled ? "On" : "Off"); if (!controller.adapter.enabled) controller.stopScan(); }
    }
    Instantiator {
        model: controller.devices
        delegate: QtObject {
            required property var modelData
            property var watch: Connections {
                target: modelData
                function onConnectedChanged() { controller.feedback(modelData.name || modelData.deviceName || "Bluetooth device", modelData.connected ? "Connected" : "Disconnected"); }
            }
        }
    }
}
