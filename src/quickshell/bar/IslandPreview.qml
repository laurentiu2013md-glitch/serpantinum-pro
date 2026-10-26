import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../media"
import "../quickactions/actions" as Actions

Item {
    id: preview
    IpcHandler {
        target: "island-" + (preview.barWindow && preview.barWindow.screen ? preview.barWindow.screen.name : "default")
        function state(): string { return JSON.stringify({opened:preview.opened,kind:preview.kind,clockOnly:preview.parent.clockOnly,temporary:preview.temporaryActive,event:preview.eventTitle,dnd:Config.getSetting("notifications", {}).dnd,cursor:Quickshell.cursorScreen ? Quickshell.cursorScreen.name : "",screen:preview.barWindow && preview.barWindow.screen ? preview.barWindow.screen.name : ""}); }
    }
    property var barWindow
    property string kind: ""
    property string pendingKind: ""
    property real contentOpacity: 0
    property real collapsedWidth: 0
    readonly property real maximumHeight: s(550)
    readonly property real revealProgress: Math.min(1, expansionHeight / Math.max(1, contentHeight))
    property real surfaceWidth: opened ? Math.max(collapsedWidth, s(600)) : collapsedWidth
    Behavior on surfaceWidth { NumberAnimation { duration: Motion.duration(430); easing.type: Easing.OutBack; easing.overshoot: preview.opened ? 1.15 : 0.65 } }
    property bool opened: false
    property bool triggerHovered: false
    property bool triggerDragging: false
    readonly property bool shelfDragging: DropShelfStore.activeDragUri !== ""
    property int eventUid: -1
    property string eventTitle: ""
    property string eventDetail: ""
    property int eventPriority: 0
    property string restoreKind: ""
    property bool restoreOpened: false
    property bool temporaryActive: false
    function receiveEvent(title, detail, priority, timeout, uid) {
        if (triggerDragging || shelfDragging || priority < eventPriority) return;
        eventUid = uid === undefined ? -1 : uid;
        eventTitle = title; eventDetail = detail; eventPriority = priority;
        eventTimer.interval = timeout;
        if (!temporaryActive && !(opened && (panelHover.hovered || sourceHovered || kind === "bluetooth"))) {
            restoreKind = kind; restoreOpened = opened;
            temporaryActive = true; show("event");
        }
        eventTimer.restart();
    }
    Timer {
        id: eventTimer
        onTriggered: {
            preview.eventPriority = 0;
            if (preview.temporaryActive) {
                preview.temporaryActive = false;
                if (preview.restoreOpened) preview.show(preview.restoreKind);
                else preview.opened = false;
            }
        }
    }
    Connections {
        target: BluetoothController
        function onFeedback(title, detail) { preview.receiveEvent(title, detail, 50, 2000); }
    }
    Connections {
        target: NotificationManager
        function onPopupAdded(uid, notification) {
            if (Config.getSetting("notifications", {}).dnd === true) return;
            if (preview.barWindow && preview.barWindow.screen === (Quickshell.cursorScreen || Quickshell.screens[0]))
                preview.receiveEvent(notification.appName || "Notification", (notification.summary || "") + (notification.body ? "\n" + notification.body : ""), 70, 4000, uid);
        }
    }
    Connections {
        target: MprisController
        function onTrackTitleChanged() {
            if (MprisController.isPlaying && MprisController.trackTitle && preview.barWindow && preview.barWindow.screen === (Quickshell.cursorScreen || Quickshell.screens[0]))
                preview.receiveEvent("Now playing", MprisController.trackTitle, 20, 1800);
        }
    }
    function show(type) {
        pendingKind = type;
        openTimer.stop();
        closeTimer.stop();
        if (opened && kind !== type) modeTransition.restart();
        else { kind = type; opened = true; revealContent.restart(); }
    }
    function requestClose() { closeTimer.restart(); }
    onTriggerHoveredChanged: { if (triggerHovered) closeTimer.stop(); else closeTimer.restart(); }
    onTriggerDraggingChanged: { if (triggerDragging) show("shelf"); else closeTimer.restart(); }
    onShelfDraggingChanged: { if (shelfDragging) closeTimer.stop(); else closeTimer.restart(); }
    Connections {
        target: IslandController
        function onTemporary(targetScreen, title, detail, priority, timeout) {
            if (preview.barWindow && targetScreen === preview.barWindow.screen) preview.receiveEvent(title, detail, priority, timeout);
        }
        function onRequested(targetScreen, type, action) {
            if (!preview.barWindow || targetScreen !== preview.barWindow.screen) return;
            const mode = type === "calendar" ? "calendar" : type;
            if (action === "close" || (action === "toggle" && preview.opened && preview.kind === mode)) preview.opened = false;
            else preview.show(mode);
        }
    }
    property var sourceModule: null
    property bool sourceHovered: false
    property bool atBottom: barWindow && barWindow.barPosition === "bottom"
    readonly property var player: MprisController.activePlayer
    property date month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    readonly property var today: { const dateRevision = DateTime.fullDate; return new Date(); }
    readonly property var forecast: Weather.forecast || []
    function s(v) { return barWindow ? barWindow.s(v) : v; }
    function enter(module, type) {
        if (temporaryActive) { temporaryActive = false; eventTimer.stop(); eventPriority = 0; }
        if (triggerDragging || bodyDrop.containsDrag || shelfDragging) return;
        sourceModule = module;
        sourceHovered = true;
        closeTimer.stop();
        pendingKind = type;
        if (kind !== type || !opened) openTimer.restart();
    }
    function leave(module) {
        if (sourceModule !== module) return;
        sourceHovered = false;
        openTimer.stop();
        closeTimer.restart();
    }
    function shiftMonth(delta) { month = new Date(month.getFullYear(), month.getMonth() + delta, 1); }
    function formatTime(value) {
        const n = Math.max(0, Math.floor(value || 0));
        return Math.floor(n / 60) + ":" + String(n % 60).padStart(2, "0");
    }
    Timer {
        id: openTimer
        interval: 140
        onTriggered: {
            if (preview.opened && preview.kind !== preview.pendingKind) modeTransition.restart();
            else {
                preview.kind = preview.pendingKind;
                preview.opened = true;
                revealContent.restart();
            }
        }
    }
    SequentialAnimation {
        id: revealContent
        NumberAnimation { target: preview; property: "contentOpacity"; to: 0; duration: 0 }
        PauseAnimation { duration: Motion.duration(70) }
        NumberAnimation { target: preview; property: "contentOpacity"; to: 1; duration: Motion.menu; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: modeTransition
        NumberAnimation { target: preview; property: "contentOpacity"; to: 0; duration: Motion.duration(100); easing.type: Easing.OutCubic }
        ScriptAction { script: preview.kind = preview.pendingKind }
        NumberAnimation { target: preview; property: "contentOpacity"; to: 1; duration: Motion.toggle; easing.type: Easing.OutCubic }
    }
    Timer {
        id: closeTimer
        interval: 350
        onTriggered: if (!preview.temporaryActive && !preview.sourceHovered && !panelHover.hovered && !preview.triggerHovered && !preview.triggerDragging && !bodyDrop.containsDrag && !preview.shelfDragging) preview.opened = false
    }
    readonly property real contentHeight: s(kind === "music" ? 510 : kind === "shelf" ? 330 : kind === "bluetooth" ? 470 : kind === "event" ? (eventUid >= 0 ? 170 : 110) : 420)
    property real expansionHeight: opened ? contentHeight : 0
    Behavior on expansionHeight { NumberAnimation { duration: Motion.duration(preview.opened ? 450 : 340); easing.type: Easing.OutBack; easing.overshoot: preview.opened ? 0.85 : 0.45 } }
    height: expansionHeight
    visible: expansionHeight > 0.1
    clip: true
    HoverHandler {
        id: panelHover
        onHoveredChanged: {
            if (hovered) closeTimer.stop();
            else closeTimer.restart();
        }
    }
    DropArea {
        id: bodyDrop
        anchors.fill: parent
        onEntered: preview.show("shelf")
        onExited: preview.requestClose()
        onDropped: drop => {
            if (DropShelfStore.acceptsDrop(drop)) { DropShelfStore.addDrop(drop); drop.accept(Qt.CopyAction); }
            else { drop.accepted = false; DropShelfStore.statusText = "Unsupported drop"; }
            preview.show("shelf");
            preview.requestClose();
        }
    }
    Item {
        id: card
        width: parent.width
        height: preview.contentHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: preview.atBottom ? preview.expansionHeight - height : 0
        opacity: preview.contentOpacity * preview.revealProgress
        transform: Translate { y: (preview.atBottom ? -1 : 1) * preview.s(8) * (1 - preview.revealProgress) }
        MusicPopup {
            id: compactPlayer
            embedded: true
            width: preview.s(625)
            height: preview.s(565)
            scale: 0.86
            transformOrigin: Item.TopLeft
            x: (parent.width - width * scale) / 2
            y: preview.s(12)
            visible: preview.kind === "music" && preview.expansionHeight > 0.5
        }
        Column {
            anchors.centerIn: parent
            width: parent.width - preview.s(48)
            spacing: preview.s(8)
            visible: preview.kind === "event"
            LabelText { width: parent.width; text: preview.eventTitle; font.pixelSize: 18; font.bold: true }
            LabelText { width: parent.width; text: preview.eventDetail; wrapMode: Text.Wrap; maximumLineCount: 3; font.pixelSize: 14 }
            Flow {
                width: parent.width; spacing: 8
                Repeater {
                    model: preview.eventUid >= 0 && NotificationManager.liveNotifs[preview.eventUid] ? NotificationManager.liveNotifs[preview.eventUid].actions : []
                    ClickButton { required property var modelData; buttonText: modelData.text || "Open"; onClicked: modelData.invoke() }
                }
                ClickButton { visible: preview.eventUid >= 0; buttonText: "Dismiss"; onClicked: { NotificationManager.dismissNotification(preview.eventUid); preview.opened = false; } }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: preview.s(12)
            width: parent.width - preview.s(40); height: preview.s(42)
            radius: ThemeBackend.smallRadius
            color: ThemeBackend.surface0
            visible: eventTimer.running && preview.kind !== "event"
            z: 100
            LabelText { anchors.fill: parent; anchors.margins: 10; text: preview.eventTitle + " · " + preview.eventDetail; verticalAlignment: Text.AlignVCenter }
        }
        BluetoothPanel {
            anchors.fill: parent
            anchors.margins: preview.s(20)
            visible: preview.kind === "bluetooth"
        }
        Actions.DropShelf {
            anchors.fill: parent
            anchors.margins: preview.s(12)
            embedded: true
            visible: preview.kind === "shelf"
        }
        Loader {
            width: Math.min(parent.width - preview.s(48), preview.s(440))
            height: preview.s(380)
            anchors.horizontalCenter: parent.horizontalCenter
            y: preview.s(20)
            visible: preview.kind === "calendar"
            sourceComponent: calendar
        }
    }
    component LabelText: Text {
        textFormat: Text.PlainText
        color: ThemeBackend.text
        font.family: ThemeBackend.fontFamily
        font.pixelSize: preview.s(13)
        elide: Text.ElideRight
    }
    component Control: Button {
        id: control
        property bool primary: false
        opacity: enabled ? 1 : 0.35
        implicitWidth: preview.s(primary ? 44 : 36)
        implicitHeight: preview.s(primary ? 44 : 36)
        contentItem: Text {
            text: control.text
            font.family: ThemeBackend.iconFont
            font.pixelSize: preview.s(control.primary ? 22 : 18)
            color: control.primary ? ThemeBackend.base : ThemeBackend.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: height / 2
            color: control.primary ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.text, control.hovered ? 0.14 : 0.06)
        }
    }
    Component {
        id: calendar
        ColumnLayout {
            spacing: preview.s(10)
            RowLayout {
                Layout.fillWidth: true
                spacing: preview.s(12)
                LabelText { text: Weather.currentIcon; font.family: ThemeBackend.iconFont; font.pixelSize: preview.s(34); color: Weather.currentHex }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: preview.s(2)
                    LabelText { Layout.fillWidth: true; text: Weather.currentTempFormatted; font.pixelSize: preview.s(24); font.weight: Font.DemiBold }
                    LabelText { Layout.fillWidth: true; text: preview.forecast.length ? preview.forecast[0].desc : (Weather.isLoading ? "Loading weather…" : "Weather unavailable"); opacity: 0.6; font.pixelSize: preview.s(12) }
                }
                LabelText { text: preview.forecast.length ? "H " + Math.round(Number(preview.forecast[0].max)) + "°  L " + Math.round(Number(preview.forecast[0].min)) + "°" : ""; opacity: 0.6; font.pixelSize: preview.s(12) }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(ThemeBackend.text, 0.1) }
            RowLayout {
                LabelText { Layout.fillWidth: true; text: Qt.formatDate(preview.month, "MMMM yyyy"); font.pixelSize: preview.s(17); font.weight: Font.DemiBold }
                Control { text: "‹"; onClicked: preview.shiftMonth(-1); Accessible.name: "Previous month" }
                Control { text: "›"; onClicked: preview.shiftMonth(1); Accessible.name: "Next month" }
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                rowSpacing: preview.s(2)
                columnSpacing: preview.s(2)
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    LabelText { required property string modelData; text: modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; opacity: 0.45; font.pixelSize: preview.s(11) }
                }
                Repeater {
                    model: 42
                    Rectangle {
                        required property int index
                        readonly property date day: new Date(preview.month.getFullYear(), preview.month.getMonth(), index - (preview.month.getDay() + 6) % 7 + 1)
                        readonly property bool isToday: day.toDateString() === preview.today.toDateString()
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: preview.s(27)
                        radius: preview.s(10)
                        color: isToday ? ThemeBackend.mauve : "transparent"
                        LabelText {
                            anchors.centerIn: parent
                            text: parent.day.getDate()
                            color: parent.isToday ? ThemeBackend.base : ThemeBackend.text
                            opacity: parent.day.getMonth() === preview.month.getMonth() ? 1 : 0.25
                            font.weight: parent.isToday ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(ThemeBackend.text, 0.1) }
            Row {
                Layout.fillWidth: true
                Repeater {
                    model: preview.forecast.slice(0, 4)
                    Column {
                        required property var modelData
                        width: parent.width / Math.max(1, Math.min(4, preview.forecast.length))
                        spacing: preview.s(5)
                        LabelText { text: modelData.day; anchors.horizontalCenter: parent.horizontalCenter; opacity: 0.6; font.pixelSize: preview.s(11) }
                        LabelText { text: modelData.icon; font.family: ThemeBackend.iconFont; font.pixelSize: preview.s(22); color: modelData.hex; anchors.horizontalCenter: parent.horizontalCenter }
                        LabelText { text: Math.round(Number(modelData.max)) + "° / " + Math.round(Number(modelData.min)) + "°"; font.pixelSize: preview.s(11); anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }
        }
    }
}
