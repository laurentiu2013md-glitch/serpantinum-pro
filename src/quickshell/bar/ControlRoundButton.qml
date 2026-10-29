import QtQuick
import QtQuick.Controls
import "../"
import "../reusables"
Button {
        id: control
        property string glyph: ""
        property string label: ""
        property bool selected: false
        implicitWidth: 70; implicitHeight: 70
        Accessible.name: label
        contentItem: Text { text: control.glyph; font.family: ThemeBackend.iconFont; font.pixelSize: 28; color: control.selected ? ThemeBackend.primary : ThemeBackend.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { radius: height/2; color: control.selected ? Qt.alpha("#ffffff",.92) : Qt.alpha("#ffffff",control.down ? .2 : control.hovered ? .14 : .07); border.width: 1; border.color: Qt.alpha("#ffffff",.18) }
        scale: down ? .94 : hovered ? 1.035 : 1
        Behavior on scale { enabled: !Motion.reduced; SpringAnimation { spring: 3.2; damping: .28; mass: 1; epsilon: .002 } }
    }
