import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../"
import "../reusables"
ColumnLayout {
    id: root
    spacing: 6
    visible: Agenda.events.length > 0
    implicitHeight: visible ? 145 : 0
    RowLayout {
        Layout.fillWidth: true
        Label { text: "Upcoming events"; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.bold: true; Layout.fillWidth: true }
    }
    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentWidth: availableWidth
        ColumnLayout {
            width: parent.width; spacing: 8
            Repeater {
                model: Agenda.events
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 2
                    Label { text: modelData.title; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Label { text: Qt.formatDateTime(new Date(modelData.start), modelData.allDay ? "ddd d MMM · 'All day'" : "ddd d MMM · HH:mm") + (modelData.location ? " · " + modelData.location : ""); color: ThemeBackend.text; opacity: .65; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
        }
    }
}
