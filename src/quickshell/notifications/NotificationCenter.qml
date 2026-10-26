import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: root
    visible: false
    focus: true

    function s(val) { 
        return Scaler.s(val); 
    }

    property real introContent: 0.0

    Timer {
        id: focusTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    onVisibleChanged: {
        NotificationManager.sysPanelOpen = visible;
        if (visible) {
            startupSequence.restart();
            focusTimer.restart();
        } else {
            startupSequence.stop();
            closeSequence.stop();
        }
    }

    Component.onCompleted: {
        if (visible) {
            startupSequence.start();
            focusTimer.start();
        }
    }

    property var exitCallback: null

    function startExit(onFinished) {
        startupSequence.stop();
        exitCallback = onFinished;
        closeSequence.restart();
    }

    SequentialAnimation {
        id: startupSequence
        NumberAnimation { 
            target: root
            property: "introContent"
            to: 1.0
            duration: Motion.notification
            easing.type: Easing.OutQuart
        } 
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation {
            NumberAnimation { 
                target: root
                property: "introContent"
                to: 0.0
                duration: Motion.menu
                easing.type: Easing.InQuart
            }
        }
        ScriptAction { 
            script: {
                if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                } else {
                    Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]);
                }
            } 
        }    
    }

    Keys.onEscapePressed: (event) => {
        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
            masterWindow.switchWidget("hidden", "");
        } else {
            closeSequence.restart();
        }
        event.accepted = true;
    }

    Component.onDestruction: NotificationManager.sysPanelOpen = false
    ClippingRectangle {
        id: sidebarPanel
        anchors.fill: parent
        color: ThemeBackend.surfaceColor(QsWindow.window ? QsWindow.window.screen : null)
        radius: ThemeBackend.borderRadius
        border.width: 1
        border.color: ThemeBackend.borderColor
        opacity: root.introContent
        WallpaperBlur { anchors.fill: parent; z: -1; radius: sidebarPanel.radius }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Notifications"; font.family: ThemeBackend.fontFamily; font.pixelSize: 22; font.bold: true; color: ThemeBackend.text; Layout.fillWidth: true }
                ClickButton { buttonText: "Clear"; enabled: NotificationManager.globalNotificationHistory.count > 0; onClicked: NotificationManager.clearNotifications() }
            }
            Label { visible: NotificationManager.globalNotificationHistory.count === 0; text: "No notifications"; color: ThemeBackend.subtext0; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 30 }
            ListView {
                id: history
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 12
                model: NotificationManager.globalNotificationHistory
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    id: card
                    required property int index
                    readonly property var entry: NotificationManager.globalNotificationHistory.get(index) || ({uid: -1, appName: "", summary: "", body: "", actionsJson: "[]"})
                    property bool expanded: false
                    width: history.width
                    implicitHeight: contents.implicitHeight + 24
                    radius: ThemeBackend.cardRadius
                    color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
                    ColumnLayout {
                        id: contents
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: card.entry.appName; textFormat: Text.PlainText; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                            ClickButton { buttonText: "×"; implicitWidth: 28; onClicked: NotificationManager.dismissNotification(card.entry.uid) }
                        }
                        Label { text: card.entry.summary; textFormat: Text.PlainText; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.bold: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        Label { text: card.entry.body; textFormat: Text.PlainText; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; wrapMode: Text.Wrap; Layout.fillWidth: true; maximumLineCount: card.expanded ? 100 : 4; elide: Text.ElideRight }
                        ClickButton { visible: card.entry.body.length > 100; buttonText: card.expanded ? "Show less" : "Show more"; onClicked: card.expanded = !card.expanded }
                        Flow {
                            Layout.fillWidth: true; spacing: 6
                            Repeater {
                                model: { try { return JSON.parse(card.entry.actionsJson || "[]"); } catch(error) { return []; } }
                                ClickButton { required property var modelData; buttonText: modelData.text; onClicked: NotificationManager.invokeAction(card.entry.uid, modelData.id) }
                            }
                        }
                    }
                }
            }
        }
    }
}
