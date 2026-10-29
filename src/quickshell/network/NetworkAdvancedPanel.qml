import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../"
import "../reusables"
ColumnLayout {
    id: panel
    spacing: 12
    property var connections: []
    property string status: ""
    property string selectedUuid: ""
    property bool autoConnect: true
    property bool metered: false
    property bool manual: false
    property int credentialGeneration: 0
    property string revealedPassword: ""
    property string credentialStatus: ""
    readonly property bool wifiSelected: connections.some(item=>item.uuid===selectedUuid && item.type==="802-11-wireless")
    function clearCredentials() {
        credentialGeneration++; rootPassword.clear(); revealedPassword=""; credentialStatus=""; passwordTimeout.stop();
    }
    function dnsValue() { return dnsMode.currentIndex===1 ? "" : [primaryDns.text.trim(),secondaryDns.text.trim()].filter(value=>value!=="").join(", "); }
    component FieldLabel: Label { color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 12 }

    function select(index) {
        const item=connections[index]; if (!item) return;
        selectedUuid=item.uuid; autoConnect=item.autoconnect; metered=item.metered; manual=item.manual;
        clearCredentials();
        addresses.text=item.addresses; gateway.text=item.gateway;
        const servers=String(item.dns || "").split(",").map(value=>value.trim()).filter(value=>value!=="");
        dnsMode.currentIndex=!servers.length || servers.join(",")==="94.140.14.14,94.140.15.15" ? 0 : 2;
        primaryDns.text=servers[0] || "94.140.14.14"; secondaryDns.text=servers.slice(1).join(", ") || (servers.length ? "" : "94.140.15.15");
    }
    function request(action, argument) {
        if (worker.running) return;
        worker.command=["python3",Caching.serpantinumDir + "/scripts/network_settings.py",action,argument || ""];
        worker.running=true;
    }
    onVisibleChanged: { if (visible) request("list",""); else clearCredentials(); }
    Component.onCompleted: if (visible) request("list","")
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data=JSON.parse(text); panel.status=data.error || data.status || "";
                    if (data.connections) {
                        const previous=panel.selectedUuid; panel.connections=data.connections;
                        const index=panel.connections.findIndex(item=>item.uuid===previous);
                        connectionPicker.currentIndex=index>=0 ? index : 0; panel.select(connectionPicker.currentIndex);
                    }
                } catch(e) { panel.status="Network settings unavailable"; }
            }
        }
    }
    Label { text: "Advanced network settings"; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 20; font.bold: true }
    Dropdown {
        id: connectionPicker; Layout.fillWidth: true; Layout.preferredHeight: 36
        options: panel.connections.map(item=>item.name)
        accentColor: ThemeBackend.mauve; baseColor: ThemeBackend.surface0; hoverColor: ThemeBackend.surface1
        dropdownColor: ThemeBackend.surface0; borderColor: Qt.alpha(ThemeBackend.surface2,.6); cornerRadius: ThemeBackend.borderRadius
        onSelected: (index,value)=>panel.select(index)
        Accessible.name: "Saved network connection"
    }
    Label { text: panel.connections.length ? "" : "No saved Wi-Fi or Ethernet connections"; visible: !panel.connections.length; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily }
    RowLayout {
        Layout.fillWidth: true
        Toggle { Layout.fillWidth: true; buttonText: "Autoconnect"; checked: panel.autoConnect; onToggled: val=>panel.autoConnect=val; enabled: panel.selectedUuid!=="" }
        Toggle { Layout.fillWidth: true; buttonText: "Metered"; checked: panel.metered; onToggled: val=>panel.metered=val; enabled: panel.selectedUuid!=="" }
    }
    Switch { Layout.fillWidth: true; implicitHeight: 36; options: ["Automatic IPv4", "Manual IPv4"]; currentIndex: panel.manual ? 1 : 0; onValueChanged: (index,value)=>panel.manual=index===1 }
    FieldLabel { text: "IPv4 address / prefix"; visible: panel.manual }
    TextField { id: addresses; Layout.fillWidth: true; visible: panel.manual; placeholderText: "IPv4 address / prefix, e.g. 192.168.1.10/24"; Accessible.name: "IPv4 addresses and prefixes" }
    FieldLabel { text: "Gateway"; visible: panel.manual }
    TextField { id: gateway; Layout.fillWidth: true; visible: panel.manual; placeholderText: "Gateway, e.g. 192.168.1.1"; Accessible.name: "IPv4 gateway" }
    FieldLabel { text: "DNS provider" }
    Dropdown {
        id: dnsMode; Layout.fillWidth: true; Layout.preferredHeight: 36
        options: ["AdGuard DNS", "Network default", "Custom DNS"]
        accentColor: ThemeBackend.mauve; baseColor: ThemeBackend.surface0; hoverColor: ThemeBackend.surface1
        dropdownColor: ThemeBackend.surface0; borderColor: Qt.alpha(ThemeBackend.surface2,.6); cornerRadius: ThemeBackend.borderRadius
        Accessible.name: "DNS provider"
        onSelected: (index,value)=> { if (index===0) { primaryDns.text="94.140.14.14"; secondaryDns.text="94.140.15.15"; } }
    }
    RowLayout {
        Layout.fillWidth: true; visible: dnsMode.currentIndex!==1; spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            FieldLabel { text: "Preferred DNS server" }
            TextField { id: primaryDns; Layout.fillWidth: true; text: "94.140.14.14"; placeholderText: "IPv4 address"; Accessible.name: "Preferred DNS server"; onTextEdited: dnsMode.currentIndex=2 }
        }
        ColumnLayout {
            Layout.fillWidth: true
            FieldLabel { text: "Alternate DNS server" }
            TextField { id: secondaryDns; Layout.fillWidth: true; text: "94.140.15.15"; placeholderText: "Optional IPv4 address"; Accessible.name: "Alternate DNS server"; onTextEdited: dnsMode.currentIndex=2 }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        ClickButton { buttonText: "Save"; enabled: panel.selectedUuid!=="" && !worker.running; onClicked: panel.request("save",JSON.stringify({uuid:panel.selectedUuid,autoconnect:panel.autoConnect,metered:panel.metered,manual:panel.manual,addresses:addresses.text,gateway:gateway.text,dns:panel.dnsValue()})) }
        ClickButton { buttonText: "Reconnect"; enabled: panel.selectedUuid!=="" && !worker.running; onClicked: panel.request("reconnect",panel.selectedUuid) }
        Label { Layout.fillWidth: true; text: worker.running ? "Working…" : panel.status; wrapMode: Text.Wrap; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 12 }
    }
    ColumnLayout {
        Layout.fillWidth: true; visible: panel.wifiSelected; spacing: 8
        FieldLabel { text: "Saved Wi-Fi password"; font.bold: true }
        FieldLabel { text: "Root password"; visible: panel.revealedPassword==="" }
        RowLayout {
            Layout.fillWidth: true; visible: panel.revealedPassword===""
            TextField {
                id: rootPassword; Layout.fillWidth: true; echoMode: TextInput.Password
                placeholderText: "Enter root password to verify"; Accessible.name: "Root password"
                enabled: !passwordWorker.running; onAccepted: revealButton.clicked()
            }
            ClickButton {
                id: revealButton; buttonText: passwordWorker.running ? "Verifying…" : "Verify and reveal"
                enabled: rootPassword.text.length>0 && panel.selectedUuid!=="" && !passwordWorker.running
                onClicked: if (enabled) { panel.credentialStatus=""; passwordWorker.requestGeneration=panel.credentialGeneration; passwordWorker.requestUuid=panel.selectedUuid; passwordWorker.running=true; }
            }
        }
        RowLayout {
            Layout.fillWidth: true; visible: panel.revealedPassword!==""
            TextField { Layout.fillWidth: true; readOnly: true; text: panel.revealedPassword; Accessible.name: "Saved Wi-Fi password"; selectByMouse: true }
            ClickButton { buttonText: "Hide"; onClicked: panel.clearCredentials() }
        }
        FieldLabel { Layout.fillWidth: true; visible: panel.credentialStatus!==""; text: panel.credentialStatus; wrapMode: Text.Wrap; textFormat: Text.PlainText }
    }
    Timer { id: passwordTimeout; interval: 30000; onTriggered: panel.clearCredentials() }
    Process {
        id: passwordWorker
        property int requestGeneration: -1
        property string requestUuid: ""
        command: ["python3",Caching.serpantinumDir + "/scripts/network_password.py"]
        stdinEnabled: true
        onStarted: { write(JSON.stringify({uuid:requestUuid,password:rootPassword.text}) + "\n"); closeWriteChannel(); rootPassword.clear(); }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!panel.visible || passwordWorker.requestGeneration!==panel.credentialGeneration || passwordWorker.requestUuid!==panel.selectedUuid) return;
                try {
                    const result=JSON.parse(text); panel.credentialStatus=result.error || result.status || "";
                    panel.revealedPassword=result.password || "";
                    if (panel.revealedPassword!=="") passwordTimeout.restart();
                } catch(e) { panel.credentialStatus="Could not verify the root password."; }
            }
        }
    }

}
