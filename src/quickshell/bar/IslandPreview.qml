import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../media"
import "../quickactions/actions" as Actions
import "../calendar" as CalendarWidgets

FocusScope {
    id: preview
    IpcHandler {
        target: "island-" + (preview.barWindow && preview.barWindow.screen ? preview.barWindow.screen.name : "default")
        function state(): string { return JSON.stringify({opened:preview.opened,kind:preview.kind,recording:RecordingState.active,compactRecording:preview.parent.clockOnly && RecordingState.active,clockOnly:preview.parent.clockOnly,workspaceWidth:preview.parent.wWorkspaces,modules:preview.parent.headerGeometry(),pill:preview.parent.headerPillGeometry(),width:preview.surfaceWidth,targetWidth:preview.opened ? Math.max(preview.collapsedWidth,preview.s(600)) : preview.collapsedWidth,height:preview.expansionHeight,targetHeight:preview.opened ? preview.contentHeight : 0,contentOpacity:preview.contentOpacity,temporary:preview.temporaryActive,osd:preview.osdHere,keyboard:preview.keyboardActive,keyboardControls:preview.keyboardActive ? preview.focusableControls().length : 0,keyboardFocus:preview.keyboardTarget ? String(preview.keyboardTarget.objectName || preview.keyboardTarget) : "",notificationQueued:preview.notificationQueue.length,notificationCount:preview.notificationCount,musicEnergy:musicAura.energy,musicReacting:musicAura.reacting,spotify:preview.spotifyPlayer,spotifyArtwork:preview.spotifyArtworkActive,musicTab:["equalizer","spotify","audio","lyrics"][compactPlayer.bottomSectionSwitch.currentIndex],spotifyClientDetected:compactPlayer.spotifyClient!==null,spotifyBrowserMode:compactPlayer.spotifyBrowser.mode,spotifyBrowserItemCount:compactPlayer.spotifyBrowser.items.length,spotifyBrowserBusy:compactPlayer.spotifyBrowser.busy,spotifyBrowserConnected:compactPlayer.spotifyBrowser.connected,spotifyBrowserMessage:compactPlayer.spotifyBrowser.message,spotifyClientTitle:compactPlayer.spotifyClient ? compactPlayer.spotifyClient.trackTitle : "",artworkOpacity:preview.barWindow ? preview.barWindow.barOpacity : 0.5,hovered:panelHover.hovered,sourceHovered:preview.sourceHovered,weatherSky:preview.weatherBackdropActive,event:preview.eventTitle,dnd:Config.getSetting("notifications", {}).dnd,cursor:Quickshell.cursorScreen ? Quickshell.cursorScreen.name : "",screen:preview.barWindow && preview.barWindow.screen ? preview.barWindow.screen.name : ""}); }
        function spotifySearch(query: string): bool {
            if (!compactPlayer.spotifyClient) return false;
            preview.show("music");
            compactPlayer.bottomSectionSwitch.currentIndex = compactPlayer.spotifyTab;
            compactPlayer.spotifyBrowser.search(query);
            return true;
        }
        function spotifyOpen(index: int): bool {
            const browser = compactPlayer.spotifyBrowser;
            if (!compactPlayer.spotifyClient || index < 0 || index >= browser.items.length) return false;
            browser.openItem(browser.items[index]);
            return true;
        }
        function musicTab(tab: string): bool {
            const index = ["equalizer", "spotify", "audio", "lyrics"].indexOf(tab);
            if (index < 0) return false;
            preview.show("music");
            compactPlayer.bottomSectionSwitch.currentIndex = index;
            return true;
        }
    }
    property var barWindow
    readonly property bool weatherBackdropActive: kind === "calendar" && Config.getSetting("coloros", {}).weatherSky !== false && !GameMode.enabled && (opened || expansionHeight > 0.5)
    readonly property string musicArtwork: compactPlayer.activeArtUrl
    readonly property bool spotifyPlayer: {
        const player = compactPlayer.targetPlayer;
        if (!player) return false;
        const identity = String(player.identity || "").toLowerCase();
        const desktop = String(player.desktopEntry || player.dbusName || "").toLowerCase();
        return identity === "spotify" || /(^|\.)spotify($|\.)/.test(desktop);
    }
    readonly property bool spotifyArtworkActive: kind === "music" && spotifyPlayer && Config.getSetting("coloros", {}).spotifyArtwork !== false && musicArtwork !== "" && !GameMode.enabled && (opened || expansionHeight > 0.5)
    readonly property bool osdHere: OsdController.isVisible && OsdController.screen === (barWindow ? barWindow.screen : null)
    function receiveOsd() {
        if (temporaryActive || triggerDragging || shelfDragging) return;
        if (opened && (keyboardActive || panelHover.hovered || sourceHovered || kind === "bluetooth" || kind === "network" || kind === "shelf")) return;
        restoreKind = kind; restoreOpened = opened;
        temporaryActive = true;
        show("osd");
    }
    function restoreTemporary() {
        temporaryActive = false;
        if (restoreOpened) show(restoreKind);
        else opened = false;
    }
    onOsdHereChanged: {
        if (!osdHere && temporaryActive && (kind === "osd" || pendingKind === "osd")) {
            modeTransition.stop(); revealContent.stop(); restoreTemporary();
        }
    }
    property string kind: ""
    property string pendingKind: ""
    property real contentOpacity: 0
    property real collapsedWidth: 0
    readonly property real maximumHeight: s(550)
    readonly property real revealProgress: Math.min(1, expansionHeight / Math.max(1, contentHeight))
    property real surfaceWidth: opened ? Math.max(collapsedWidth, s(600)) : collapsedWidth
    // Springs carry motion through interruptions instead of restarting an easing curve.
    Behavior on surfaceWidth {
        enabled: !Motion.reduced
        SpringAnimation { spring: 3.2; damping: 0.28; mass: 1; epsilon: 0.25 }
    }
    property bool opened: false
    property bool keyboardActive: false
    property var keyboardTarget: null
    onOpenedChanged: {
        if (!opened) { keyboardActive=false; keyboardTarget=null; closeTimer.stop(); }
        else if (!sourceHovered && !panelHover.hovered && !temporaryActive) closeTimer.restart();
    }
    function focusableControls() {
        let controls=[];
        function walk(item) {
            if (!item || !item.visible || !item.enabled) return;
            if (item.activeFocusOnTab) { controls.push(item); return; }
            for (const child of item.children || []) walk(child);
        }
        for (const child of card.children) walk(child);
        return controls;
    }
    function focusControl(delta) {
        if (!panelHover.hovered && !sourceHovered) closeTimer.restart();
        const controls=focusableControls();
        if (!controls.length) { forceActiveFocus(Qt.ShortcutFocusReason); return; }
        let index=controls.findIndex(item => item.activeFocus);
        if (index<0) index=delta<0 ? 0 : -1;
        keyboardTarget=controls[(index+delta+controls.length)%controls.length];
        keyboardTarget.forceActiveFocus(Qt.TabFocusReason);
    }
    Timer { id: keyboardFocusTimer; interval: 180; onTriggered: if (preview.keyboardActive) preview.focusControl(1) }
    Shortcut { sequence: "Tab"; context: Qt.WindowShortcut; enabled: preview.opened && preview.keyboardActive; onActivated: preview.focusControl(1) }
    Shortcut { sequence: "Shift+Tab"; context: Qt.WindowShortcut; enabled: preview.opened && preview.keyboardActive; onActivated: preview.focusControl(-1) }
    Rectangle {
        parent: preview.keyboardTarget || preview
        anchors.fill: parent; anchors.margins: -3
        radius: 8; color: "transparent"; border.width: 2; border.color: ThemeBackend.primary
        visible: preview.keyboardActive && preview.keyboardTarget !== null && preview.keyboardTarget.activeFocus
        z: 999
    }
    property bool triggerHovered: false
    property bool triggerDragging: false
    readonly property bool shelfDragging: DropShelfStore.activeDragUri !== ""
    property int eventUid: -1
    property string eventTitle: ""
    property string eventDetail: ""
    property int eventPriority: 0
    property string restoreKind: ""
    property bool restoreOpened: false
    property var notificationQueue: []
    property string notificationKey: ""
    property var notificationUids: []
    property int notificationCount: 0
    property double notificationLastAt: 0
    function queueNotification(uid, notification) {
        const now = Date.now();
        const key = NotificationManager.resolveApp(notification).groupKey + (notification.urgency === 2 ? ":critical:" + uid : "");
        const detail = (notification.summary || "") + (notification.body ? "\n" + notification.body : "");
        const grouping = Config.getSetting("coloros", {}).notificationGrouping !== false;
        if (grouping && eventUid >= 0 && eventTimer.running && key === notificationKey && now - notificationLastAt < 2000) {
            notificationUids = notificationUids.concat([uid]); notificationCount++;
            notificationLastAt = now; eventUid = uid; eventDetail = detail;
            eventTimer.restart(); return;
        }
        const index = grouping ? notificationQueue.findIndex(item => item.key === key && now - item.lastAt < 2000) : -1;
        const queue = notificationQueue.slice();
        if (index >= 0) {
            const old = queue[index];
            queue[index] = {uid:uid, title:old.title, detail:detail, key:key, uids:old.uids.concat([uid]), count:old.count + 1, lastAt:now};
        } else queue.push({uid:uid, title:notification.appName || "Notification", detail:detail, key:key, uids:[uid], count:1, lastAt:now});
        notificationQueue = queue;
        if (eventUid < 0 || !eventTimer.running) nextNotification();
    }
    function nextNotification() {
        if (triggerDragging || shelfDragging || notificationQueue.length === 0 || (eventUid >= 0 && eventTimer.running)) return;
        const next = notificationQueue[0];
        notificationQueue = notificationQueue.slice(1);
        eventPriority = 0;
        notificationKey = next.key; notificationUids = next.uids; notificationCount = next.count; notificationLastAt = next.lastAt;
        receiveEvent(next.title, next.detail, 70, Math.max(2000, Math.min(15000, Number(Config.getSetting("coloros", {}).notificationTimeout || 5000))), next.uid);
    }
    function finishNotification(dismiss) {
        const uids = notificationUids.length ? notificationUids : eventUid >= 0 ? [eventUid] : [];
        for (const uid of uids) {
            NotificationManager.removePopup(uid);
            if (dismiss) NotificationManager.dismissNotification(uid);
        }
        notificationKey = ""; notificationUids = []; notificationCount = 0;
        eventUid = -1; eventPriority = 0;
        eventTimer.stop();
        if (notificationQueue.length) nextNotification();
        else if (temporaryActive) {
            if (osdHere) show("osd");
            else restoreTemporary();
        }
    }
    property bool temporaryActive: false
    function receiveEvent(title, detail, priority, timeout, uid) {
        if (triggerDragging || shelfDragging || priority < eventPriority) return;
        if (uid === undefined) {
            for (const old of notificationUids) NotificationManager.removePopup(old);
            notificationKey = ""; notificationUids = []; notificationCount = 0;
        }
        eventUid = uid === undefined ? -1 : uid;
        eventTitle = title; eventDetail = detail; eventPriority = priority;
        eventTimer.interval = timeout;
        if (temporaryActive && kind === "osd" && priority >= 60) show("event");
        if (!temporaryActive && !(opened && (keyboardActive || panelHover.hovered || sourceHovered || (kind === "bluetooth" || kind === "network")))) {
            restoreKind = kind; restoreOpened = opened;
            temporaryActive = true; show("event");
        }
        eventTimer.restart();
    }
    Timer {
        id: eventTimer
        onTriggered: {
            if (preview.eventUid >= 0) {
                if (panelHover.hovered) { restart(); return; }
                preview.finishNotification(false); return;
            }
            preview.eventPriority = 0;
            if (preview.notificationQueue.length) { preview.nextNotification(); return; }
            if (preview.temporaryActive) {
                if (preview.osdHere) preview.show("osd");
                else preview.restoreTemporary();
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
                preview.queueNotification(uid, notification);
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
        if (opened && kind !== type) { revealContent.stop(); modeTransition.restart(); }
        else {
            modeTransition.stop();
            const wasOpened = opened;
            kind = type; opened = true;
            if (!wasOpened || contentOpacity < 1) revealContent.restart();
        }
    }
    function requestClose() { closeTimer.restart(); }
    onTriggerHoveredChanged: { if (triggerHovered) closeTimer.stop(); else closeTimer.restart(); }
    onTriggerDraggingChanged: { if (triggerDragging) show("shelf"); else { closeTimer.restart(); nextNotification(); } }
    onShelfDraggingChanged: { if (shelfDragging) closeTimer.stop(); else { closeTimer.restart(); nextNotification(); } }
    Connections {
        target: IslandController
        function onOsdRequested(targetScreen) {
            if (preview.barWindow && targetScreen === preview.barWindow.screen) preview.receiveOsd();
        }
        function onTemporary(targetScreen, title, detail, priority, timeout) {
            if (preview.barWindow && targetScreen === preview.barWindow.screen) preview.receiveEvent(title, detail, priority, timeout);
        }
        function onRequested(targetScreen, type, action) {
            if (!preview.barWindow || targetScreen !== preview.barWindow.screen) return;
            if (preview.temporaryActive) { preview.temporaryActive = false; eventTimer.stop(); preview.eventPriority = 0; }
            const mode = type === "calendar" ? "calendar" : type;
            if (action === "keyboard") {
                if (preview.keyboardActive && preview.opened && preview.kind===mode) { preview.opened=false; return; }
                preview.keyboardActive=true; preview.keyboardTarget=null;
                preview.show(mode); keyboardFocusTimer.restart();
            } else {
                preview.keyboardActive=false;
                if (action === "close" || (action === "toggle" && preview.opened && preview.kind === mode)) preview.opened = false;
                else preview.show(mode);
            }
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
        if (keyboardActive) return;
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
            if (preview.opened && preview.kind !== preview.pendingKind) { revealContent.stop(); modeTransition.restart(); }
            else preview.show(preview.pendingKind);
        }
    }
    NumberAnimation {
        id: revealContent
        target: preview; property: "contentOpacity"; to: 1
        duration: Motion.menu; easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: modeTransition
        NumberAnimation { target: preview; property: "contentOpacity"; to: 0; duration: Motion.duration(100); easing.type: Easing.OutCubic }
        ScriptAction { script: preview.kind = preview.pendingKind }
        NumberAnimation { target: preview; property: "contentOpacity"; to: 1; duration: Motion.toggle; easing.type: Easing.OutCubic }
    }
    Timer {
        id: closeTimer
        interval: 1000
        onTriggered: if ( !preview.temporaryActive && !preview.sourceHovered && !panelHover.hovered && !preview.triggerHovered && !preview.triggerDragging && !bodyDrop.containsDrag && !preview.shelfDragging) preview.opened = false
    }
    readonly property real contentHeight: kind === "calendar" ? calendarLoader.y + calendarLoader.height + s(24) : s(kind === "battery" ? 300 : kind === "controls" ? 710 : kind === "focus" ? 240 : kind === "osd" ? 106 : kind === "music" ? 510 : kind === "shelf" ? 330 : (kind === "bluetooth" || kind === "network") ? 470 : kind === "event" ? (eventUid >= 0 ? 170 : 110) : kind === "calendar" ? 0 : 420)
    property real expansionHeight: opened ? contentHeight : 0
    Behavior on expansionHeight {
        enabled: !Motion.reduced
        SpringAnimation { spring: 3.2; damping: 0.28; mass: 1; epsilon: 0.25 }
    }
    height: Math.max(0, expansionHeight)
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
        MusicAura {
            id: musicAura
            anchors.fill: parent
            visible: preview.kind === "music" && preview.expansionHeight > 0.5 && !preview.spotifyArtworkActive && Config.getSetting("coloros", {}).musicGlow !== false
            artwork: compactPlayer.activeArtUrl
            playing: compactPlayer.targetPlayer ? compactPlayer.targetPlayer.isPlaying : false
        }
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
            PulseIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰋋"; accent: ThemeBackend.green
                visible: preview.eventUid < 0 && preview.eventDetail === "Connected"
                onVisibleChanged: if (visible) pulse()
            }
            LabelText { width: parent.width; text: preview.eventTitle + (preview.notificationCount > 1 ? " · " + preview.notificationCount + " notifications" : ""); font.pixelSize: 18; font.bold: true }
            LabelText { width: parent.width; text: preview.eventDetail; wrapMode: Text.Wrap; maximumLineCount: 3; font.pixelSize: 14 }
            Flow {
                width: parent.width; spacing: 8
                Repeater {
                    model: preview.eventUid >= 0 && NotificationManager.liveNotifs[preview.eventUid] ? NotificationManager.liveNotifs[preview.eventUid].actions : []
                    ClickButton { required property var modelData; buttonText: modelData.text || "Open"; onClicked: modelData.invoke() }
                }
                ClickButton { visible: preview.eventUid >= 0; buttonText: "Dismiss"; onClicked: preview.finishNotification(true) }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: preview.s(12)
            width: parent.width - preview.s(40); height: preview.s(preview.eventUid >= 0 ? 104 : 42)
            radius: ThemeBackend.smallRadius
            color: ThemeBackend.surface0
            visible: eventTimer.running && preview.kind !== "event" && preview.kind !== "osd" && !preview.osdHere
            z: 100
            Column {
                anchors.fill: parent; anchors.margins: 10; spacing: 5
                LabelText { width: parent.width; text: preview.eventTitle + (preview.notificationCount > 1 ? " (" + preview.notificationCount + ")" : "") + " · " + preview.eventDetail; wrapMode: Text.Wrap; maximumLineCount: 2 }
                Row {
                    spacing: 8; visible: preview.eventUid >= 0
                    Repeater {
                        model: preview.eventUid >= 0 && NotificationManager.liveNotifs[preview.eventUid] ? NotificationManager.liveNotifs[preview.eventUid].actions : []
                        ClickButton { required property var modelData; buttonText: modelData.text || "Open"; onClicked: modelData.invoke() }
                    }
                    ClickButton { buttonText: "Dismiss"; onClicked: preview.finishNotification(true) }
                }
            }
        }
        IslandOsd {
            anchors.fill: parent
            anchors.leftMargin: preview.s(18); anchors.rightMargin: preview.s(18)
            visible: preview.kind === "osd"
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: preview.s(8)
            width: parent.width - preview.s(32); height: preview.s(76)
            radius: ThemeBackend.borderRadius
            color: Qt.alpha(ThemeBackend.base, .92)
            visible: preview.osdHere && preview.kind !== "osd"
            z: 101
            IslandOsd { anchors.fill: parent; compact: true }
        }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: preview.s(24)
            visible: preview.kind === "focus"
            spacing: preview.s(12)
            RowLayout {
                LabelText { text: TimerState.focusPhase; font.pixelSize: preview.s(20); Layout.fillWidth: true }
                ClickButton { buttonText: "Calendar"; onClicked: preview.show("calendar") }
            }
            LabelText { text: TimerState.focusLabel; Layout.alignment: Qt.AlignHCenter; font.pixelSize: preview.s(48); font.bold: true }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                ClickButton { buttonText: TimerState.focusRunning ? "Pause" : "Start"; onClicked: TimerState.toggleFocus() }
                ClickButton { buttonText: "Reset"; onClicked: TimerState.resetFocus() }
                ClickButton { buttonText: "15 min"; onClicked: TimerState.startFocus(15) }
                ClickButton { buttonText: "25 min"; onClicked: TimerState.startFocus(25) }
                ClickButton { buttonText: "50 min"; onClicked: TimerState.startFocus(50) }
            }
        }
        BatteryPanel { anchors.fill: parent; anchors.margins: preview.s(24); visible: preview.kind === "battery" }
        ControlCenterPanel { anchors.fill: parent; anchors.margins: preview.s(24); visible: preview.kind === "controls" }
        NetworkPanel {
            anchors.fill: parent
            anchors.margins: preview.s(20)
            visible: preview.kind === "network"
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
            id: calendarLoader
            width: Math.min(parent.width - preview.s(48), preview.s(440))
            height: item ? Math.ceil(item.implicitHeight) : preview.s(420)
            anchors.horizontalCenter: parent.horizontalCenter
            y: preview.s(20)
            visible: preview.kind === "calendar"
            sourceComponent: calendar
        }
    }
    component LabelText: Text {
        textFormat: Text.PlainText
        color: preview.weatherBackdropActive ? "#ffffff" : ThemeBackend.text
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
            color: preview.weatherBackdropActive ? "#ffffff" : control.primary ? ThemeBackend.base : ThemeBackend.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: height / 2
            color: preview.weatherBackdropActive ? Qt.alpha("#ffffff", control.hovered ? .22 : .1) : control.primary ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.text, control.hovered ? 0.14 : 0.06)
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
                    LabelText { Layout.fillWidth: true; text: Weather.data.current_desc || (preview.forecast.length ? preview.forecast[0].desc : (Weather.isLoading ? "Loading weather…" : "Weather unavailable")); opacity: 0.6; font.pixelSize: preview.s(12) }
                }
                LabelText { text: preview.forecast.length ? "H " + Math.round(Number(preview.forecast[0].max)) + "°  L " + Math.round(Number(preview.forecast[0].min)) + "°" : ""; opacity: 0.6; font.pixelSize: preview.s(12) }
            }
            LabelText { Layout.fillWidth: true; text: Qt.formatDate(preview.today,"dddd, d MMMM yyyy"); font.pixelSize: preview.s(12); opacity: .65 }
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(preview.weatherBackdropActive ? "#ffffff" : ThemeBackend.text, 0.12) }
            RowLayout {
                LabelText { Layout.fillWidth: true; text: Qt.formatDate(preview.month, "MMMM yyyy"); font.pixelSize: preview.s(17); font.weight: Font.DemiBold }
                ClickButton { buttonText: "Focus timer"; onClicked: preview.show("focus") }
                Control { text: "‹"; onClicked: preview.shiftMonth(-1); Accessible.name: "Previous month" }
                Control { text: "›"; onClicked: preview.shiftMonth(1); Accessible.name: "Next month" }
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: preview.s(194)
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
                        color: isToday ? (preview.weatherBackdropActive ? Qt.alpha("#ffffff", .22) : ThemeBackend.mauve) : "transparent"
                        LabelText {
                            anchors.centerIn: parent
                            text: parent.day.getDate()
                            color: preview.weatherBackdropActive ? "#ffffff" : parent.isToday ? ThemeBackend.base : ThemeBackend.text
                            opacity: parent.day.getMonth() === preview.month.getMonth() ? 1 : 0.25
                            font.weight: parent.isToday ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(preview.weatherBackdropActive ? "#ffffff" : ThemeBackend.text, 0.12) }
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
            CalendarWidgets.AgendaPanel {
                id: agendaPanel
                Layout.fillWidth: true; Layout.preferredHeight: Agenda.events.length > 0 ? preview.s(145) : 0
            }
        }
    }
}
