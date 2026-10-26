import QtQuick

MouseArea {
    id: edge
    objectName: "swiftlySwitchEdge"
    property real edgeStart: 0.9
    signal switchRequested()
    x: parent.width * edgeStart
    y: 0
    width: parent.width - x
    height: parent.height
    z: 10000
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    preventStealing: true
    onClicked: switchRequested()

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 3
        width: 3
        height: Math.min(24, parent.height / 3)
        radius: 1.5
        color: "white"
        opacity: edge.containsMouse ? 0.6 : 0
    }
}
