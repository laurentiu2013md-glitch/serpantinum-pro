import QtQuick
import "../../network"
Item {
    id: root
    property int requestedLayoutTemplate: 1
    property string edge: typeof activeEdge !== "undefined" ? activeEdge : "left"
    property real preferredWidth: edge === "top" || edge === "bottom" ? 470 : 520
    property real preferredExtraLength: edge === "top" || edge === "bottom" ? 520 : 470
    NetworkPanel {
        anchors.fill: parent; anchors.margins: 14
        rotation: root.edge === "right" ? 180 : root.edge === "bottom" ? 90 : root.edge === "top" ? -90 : 0
    }
}
