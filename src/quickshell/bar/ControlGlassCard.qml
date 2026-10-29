import QtQuick
import "../"
import "../reusables"
Rectangle {
    radius: 26
    color: ThemeBackend.liquidGlass && glass.active ? "transparent" : Qt.alpha(ThemeBackend.base,ThemeBackend.elementOpacity)
    border.width: 1; border.color: Qt.alpha("#ffffff",.22)
    WallpaperBlur { id: glass; anchors.fill: parent; radius: parent.radius; z: -1 }
}
