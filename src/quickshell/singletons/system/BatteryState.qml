pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../../"
QtObject {
    id: root
    property var customLimits: ({})
    property var profileConfig: FileView {
        path: "/etc/ryzen-performance-limits.json"; blockLoading: true; watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.customLimits = JSON.parse(text()); } catch(e) { root.customLimits = {}; } }
    }
    function wattsLabel(key) {
        const value = customLimits[key];
        if (!value) return "";
        const slow = Number(value["slow-limit"]) / 1000, fast = Number(value["fast-limit"]) / 1000;
        if (!(slow > 0 && fast > 0)) return "";
        return " · " + slow + (slow !== fast ? "/" + fast : "") + " W";
    }
    readonly property var profileOptions: {
        let choices=[(customLimits.power_saver_mw ? "Efficiency" : "Power saver") + wattsLabel("power_saver_mw"), "Balanced" + wattsLabel("balanced_mw")];
        if (performance) choices.push("Performance" + wattsLabel("performance_mw"));
        return choices;
    }
    readonly property var battery: UPower.displayDevice
    readonly property var physical: UPower.devices.values.find(device => device.isLaptopBattery && device.healthSupported) || battery
    readonly property bool ready: battery.ready && battery.isLaptopBattery
    readonly property bool charging: battery.state === UPowerDeviceState.Charging
    readonly property bool full: battery.state === UPowerDeviceState.FullyCharged
    readonly property real percent: ready ? Math.round(battery.percentage * 100) : 0
    property int views: 0
    property real liveWatts: -1
    readonly property real watts: liveWatts >= 0 && views > 0 ? liveWatts : ready ? Math.abs(battery.changeRate) : 0
    property var liveReader: Process {
        command: ["python3", Caching.serpantinumDir + "/scripts/battery_live.py"]
        running: root.views > 0
        stdout: SplitParser {
            onRead: data => { try { const reading=JSON.parse(data); root.liveWatts=reading.watts === null ? -1 : Number(reading.watts); } catch(e) {} }
        }
    }
    readonly property real health: physical.healthSupported ? physical.healthPercentage : -1
    readonly property string timeLeft: {
        if (!ready) return "No battery information";
        if (full) return "Fully charged";
        const seconds=charging ? battery.timeToFull : battery.timeToEmpty;
        if (seconds <= 0) return charging ? "Charging · estimating time" : "Estimating time remaining";
        const minutes=Math.max(1,Math.round(seconds/60));
        return (minutes < 60 ? minutes + " min " : Math.floor(minutes/60) + "h " + (minutes%60) + "m ") + (charging ? "until full" : "remaining");
    }
    readonly property int profile: PowerProfiles.profile
    readonly property bool performance: PowerProfiles.hasPerformanceProfile
    function selectProfile(index) { PowerProfiles.profile = index === 0 ? PowerProfile.PowerSaver : index === 2 && performance ? PowerProfile.Performance : PowerProfile.Balanced; }
    property var ipc: IpcHandler {
        target: "battery"
        function state(): string { return JSON.stringify({ready:root.ready,percent:root.percent,watts:root.watts,health:root.health,time:root.timeLeft,profile:root.profile,profiles:root.profileOptions}); }
    }
}
