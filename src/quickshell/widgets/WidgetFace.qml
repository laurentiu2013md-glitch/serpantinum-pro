// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Controls
import Quickshell.Services.Mpris

Item {
    id: face
    required property var widget
    required property var theme
    property date now: new Date()
    readonly property var player: Mpris.players.values.length ? Mpris.players.values[0] : null
    readonly property string customSource: (widget.options || {}).qmlSource || ""
    Loader {
        anchors.fill: parent
        active: face.customSource !== ""
        source: face.customSource
    }
    SwiftlyPalette { id: colors; theme: face.theme }
    Timer { interval: 1000; running: face.visible; repeat: true; onTriggered: face.now = new Date() }
    Column {
        visible: face.customSource === ""
        width: parent.width
        spacing: 6
        Rectangle {
            width: caption.implicitWidth + 20
            height: 28
            radius: 14
            color: colors.primaryContainer
            Label {
                id: caption
                anchors.centerIn: parent
                color: colors.primary
                text: face.widget.type === "clock" ? "Clock" : face.widget.type === "calendar" ? "Today" : face.widget.type === "media" ? "Now playing" : "Widget"
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
        Label {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: colors.foreground
            font.pixelSize: face.widget.type === "clock" ? 60 : 26
            font.weight: Font.Normal
            font.letterSpacing: face.widget.type === "clock" ? -1.5 : 0
            text: {
                if (face.widget.type === "clock") return Qt.formatTime(face.now, (face.widget.options || {}).format || "HH:mm");
                if (face.widget.type === "calendar") return Qt.formatDate(face.now, "dddd, d MMMM");
                if (face.widget.type === "media") return face.player ? face.player.trackTitle || "Unknown title" : "No player connected";
                return "Unavailable widget";
            }
        }
        Label {
            width: parent.width
            elide: Text.ElideRight
            color: colors.muted
            font.pixelSize: 13
            text: face.widget.type === "media" ? (face.player ? face.player.trackArtist : "Open a media player to see its track") : Qt.formatDate(face.now, "ddd, d MMM yyyy")
        }
    }
}
