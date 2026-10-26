import QtQuick
import QtQuick.Controls
import "../../"
AbstractButton {
    id: control
    checkable: true
    implicitWidth: 60
    implicitHeight: 48
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    opacity: enabled ? 1 : 0.38
    background: Rectangle {
        id: track
        anchors.centerIn: parent
        width: 52; height: 32; radius: 16
        color: control.checked ? ThemeBackend.mauve : ThemeBackend.surface2
        border.width: control.checked ? 0 : 2
        border.color: ThemeBackend.subtext0
        Behavior on color { ColorAnimation { duration: Motion.toggle } }
        Rectangle {
            id: thumb
            width: control.down ? 28 : control.checked ? 24 : 16
            height: width; radius: width / 2
            x: control.checked ? track.width - width - 4 : (32 - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            color: control.checked ? (ThemeBackend.isLight ? "#ffffff" : ThemeBackend.base) : ThemeBackend.subtext0
            Behavior on width { NumberAnimation { duration: Motion.toggle; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
            Behavior on x { NumberAnimation { duration: Motion.toggle; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Motion.toggle } }
            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 16; font.weight: Font.DemiBold
                color: ThemeBackend.mauve
                opacity: control.checked ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.hover } }
            }
            Rectangle {
                anchors.centerIn: parent; width: 40; height: width; radius: width / 2
                color: Qt.alpha(ThemeBackend.mauve, 0.08)
                visible: control.hovered || control.activeFocus
                z: -1
            }
        }
    }
    contentItem: Item {}
}
