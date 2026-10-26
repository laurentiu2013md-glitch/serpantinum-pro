import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "Model.js" as Model

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    function s(v) {
        return typeof scaleFunc === "function" ? scaleFunc(v) : v;
    }

    property real baseW: s(360)
    property real baseL: s(420)
    property real preferredWidth: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseL : baseW
    property real preferredExtraLength: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseW : baseL

    property real counterRotation: {
        if (root.safeActiveEdge === "right") return 180;
        if (root.safeActiveEdge === "bottom") return 90;
        if (root.safeActiveEdge === "top") return -90;
        return 0;
    }

    property bool embedded: false
    readonly property var entries: DropShelfStore.entries
    readonly property string statusText: DropShelfStore.statusText
    readonly property var lastRemovedEntry: DropShelfStore.lastRemovedEntry
    function addDrop(drop) { DropShelfStore.addDrop(drop); }
    function removeAt(index) { DropShelfStore.removeAt(index); }
    function removeAfterDrag(uri) { DropShelfStore.removeAfterDrag(uri); }
    function undoRemove() { DropShelfStore.undoRemove(); }
    function clearShelf() { DropShelfStore.clearShelf(); }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function mutedColor() { return alpha(ThemeBackend.text, 0.62); }
    function subtleColor() { return alpha(ThemeBackend.text, 0.08); }
    function hairlineColor() { return alpha(ThemeBackend.text, 0.18); }
    function bgColor() { return ThemeBackend.surface0 || alpha(ThemeBackend.text, 0.06); }
    function accentColor() { return ThemeBackend.mauve; }
    // The card is inset 4px from the floating panel; keep its curve concentric.
    function radius() { return Math.max(0, s(ThemeBackend.borderRadius) - s(4)); }

    Item {
        id: rotatedRoot
        anchors.fill: parent
        rotation: root.counterRotation
        transformOrigin: Item.Center

        Rectangle {
            anchors.fill: parent
            radius: root.radius()
            color: root.embedded ? "transparent" : alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
            border.width: root.embedded ? 0 : Math.max(1, root.s(1))
            border.color: hairlineColor()
            clip: true

            DropArea {
                id: dropArea
                anchors.fill: parent
                anchors.margins: root.s(2)

                onDropped: function(drop) {
                    if (DropShelfStore.acceptsDrop(drop)) { drop.accept(Qt.CopyAction); root.addDrop(drop); }
                    else { drop.accepted = false; DropShelfStore.statusText = "Unsupported drop: use files, images, links, or text"; }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.s(5)
                    radius: Math.max(0, root.radius() - root.s(2))
                    color: dropArea.containsDrag ? alpha(accentColor(), 0.10) : "transparent"
                    border.width: dropArea.containsDrag ? root.s(2) : 0
                    border.color: accentColor()
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(14)
                    spacing: root.s(10)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.s(10)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.s(1)

                            Text {
                                Layout.fillWidth: true
                                text: "Drop Shelf"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(18)
                                font.weight: Font.Black
                                font.bold: true
                                color: ThemeBackend.text
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.statusText
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(9)
                                font.weight: Font.Black
                                font.bold: true
                                color: mutedColor()
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            spacing: root.s(6)

                            Rectangle {
                                visible: root.lastRemovedEntry !== null
                                width: undoText.implicitWidth + root.s(18)
                                height: root.s(28)
                                radius: Math.max(0, root.radius() - root.s(2))
                                color: alpha(ThemeBackend.text, 0.07)
                                border.width: root.s(1)
                                border.color: hairlineColor()

                                Text {
                                    id: undoText
                                    anchors.centerIn: parent
                                    text: "Undo"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(9)
                                    font.weight: Font.Black
                                    color: ThemeBackend.text
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.undoRemove()
                                }
                            }

                            Rectangle {
                                visible: root.entries.length > 0
                                width: clearText.implicitWidth + root.s(18)
                                height: root.s(28)
                                radius: Math.max(0, root.radius() - root.s(2))
                                color: alpha(ThemeBackend.text, 0.07)
                                border.width: root.s(1)
                                border.color: hairlineColor()

                                Text {
                                    id: clearText
                                    anchors.centerIn: parent
                                    text: "Clear"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(9)
                                    font.weight: Font.Black
                                    color: ThemeBackend.text
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.clearShelf()
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: root.s(1)
                        color: hairlineColor()
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Column {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, root.s(280))
                            spacing: root.s(8)
                            visible: root.entries.length === 0

                            Text {
                                width: parent.width
                                text: dropArea.containsDrag ? "󰉋" : "󰉋"
                                horizontalAlignment: Text.AlignHCenter
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(38)
                                color: dropArea.containsDrag ? accentColor() : mutedColor()
                            }
                            Text {
                                width: parent.width
                                text: dropArea.containsDrag ? "Release to add" : "Drop files, images, or links here"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(13)
                                font.weight: Font.Black
                                font.bold: true
                                color: ThemeBackend.text
                            }
                            Text {
                                width: parent.width
                                text: "Files stay where they are. Images are saved privately. Links are stored and can be opened or dragged out."
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(9)
                                color: mutedColor()
                            }
                        }

                        GridView {
                            id: shelfGrid
                            anchors.fill: parent
                            visible: root.entries.length > 0
                            clip: true
                            model: root.entries
                            cellWidth: width / Math.max(1, Math.floor(width / root.s(112)))
                            cellHeight: root.s(128)
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Item {
                                id: tile
                                required property var modelData
                                required property int index

                                width: shelfGrid.cellWidth
                                height: shelfGrid.cellHeight

                                readonly property string uri: String(modelData.uri || "")
                                readonly property string name: String(modelData.name || "File")
                                readonly property bool linkItem: String(modelData.kind || "") === "link" || Model.isWebUrl(uri)
                                readonly property bool imageFile: !linkItem && Model.isImage(name)
                                property var grabResult: null

                                Rectangle {
                                    id: tileSurface
                                    anchors.fill: parent
                                    anchors.margins: root.s(5)
                                    radius: Math.max(0, root.radius() - root.s(1))
                                    color: tileMouse.containsMouse || tile.Drag.active ? subtleColor() : "transparent"
                                    border.width: root.s(1)
                                    border.color: tile.Drag.active ? accentColor() : hairlineColor()

                                    Image {
                                        id: thumbnail
                                        anchors.top: parent.top
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.topMargin: root.s(9)
                                        width: root.s(70)
                                        height: root.s(70)
                                        source: tile.imageFile ? tile.uri : ""
                                        visible: tile.imageFile && status === Image.Ready
                                        asynchronous: true
                                        cache: true
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize: Qt.size(width * 2, height * 2)
                                    }

                                    Text {
                                        anchors.centerIn: thumbnail
                                        visible: !thumbnail.visible
                                        text: tile.linkItem ? "󰌷" : "󰈔"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: root.s(34)
                                        color: mutedColor()
                                    }

                                    Rectangle {
                                        visible: tile.linkItem
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: root.s(8)
                                        width: linkBadge.implicitWidth + root.s(10)
                                        height: root.s(20)
                                        radius: root.s(10)
                                        color: alpha(accentColor(), 0.14)
                                        border.width: root.s(1)
                                        border.color: alpha(accentColor(), 0.35)
                                        z: 2

                                        Text {
                                            id: linkBadge
                                            anchors.centerIn: parent
                                            text: "LINK"
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: root.s(7)
                                            font.weight: Font.Black
                                            color: accentColor()
                                        }
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: root.s(8)
                                        text: tile.name
                                        textFormat: Text.PlainText
                                        horizontalAlignment: Text.AlignHCenter
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: root.s(8)
                                        font.weight: Font.Black
                                        color: ThemeBackend.text
                                        elide: Text.ElideMiddle
                                    }

                                    Rectangle {
                                        id: removeButton
                                        width: root.s(22)
                                        height: width
                                        radius: width / 2
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: root.s(5)
                                        visible: tileMouse.containsMouse && !tile.Drag.active
                                        z: 2
                                        color: alpha(ThemeBackend.surface0, 0.92)
                                        border.width: root.s(1)
                                        border.color: hairlineColor()

                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            font.pixelSize: root.s(14)
                                            font.weight: Font.Black
                                            color: ThemeBackend.text
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            z: 3
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.removeAt(tile.index)
                                        }
                                    }
                                }

                                DropArea {
                                    anchors.fill: parent
                                    keys: ["application/x-serpantinum-shelf"]
                                    onDropped: drop => {
                                        if (DropShelfStore.activeDragUri !== "") {
                                            const movingUri = DropShelfStore.activeDragUri; const destination = tile.index;
                                            DropShelfStore.selfDrop = true;
                                            Qt.callLater(() => DropShelfStore.moveTo(movingUri, destination));
                                            drop.accept(Qt.CopyAction);
                                        }
                                    }
                                }
                                Rectangle {
                                    width: root.s(24); height: width; radius: width / 2
                                    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: root.s(8)
                                    visible: tileMouse.containsMouse && !tile.Drag.active
                                    color: ThemeBackend.surface0
                                    z: 3
                                    Text { anchors.centerIn: parent; text: "⧉"; color: ThemeBackend.text }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: DropShelfStore.copyEntry(tile.uri) }
                                }

                                Drag.active: tileMouse.drag.active
                                Drag.mimeData: ({ "text/uri-list": tile.uri + "\r\n", "application/x-serpantinum-shelf": tile.uri })
                                Drag.supportedActions: Qt.CopyAction
                                Drag.proposedAction: Qt.CopyAction
                                Drag.dragType: Drag.Automatic
                                Drag.imageSource: tile.imageFile ? tile.uri : ""
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                Drag.onDragStarted: {
                                    DropShelfStore.activeDragUri = tile.uri;
                                    DropShelfStore.selfDrop = false;
                                }

                                Drag.onDragFinished: function(dropAction) {
                                    tile.x = 0;
                                    tile.y = 0;
                                    const droppedOnShelf = DropShelfStore.selfDrop && DropShelfStore.activeDragUri === tile.uri;
                                    DropShelfStore.activeDragUri = "";
                                    DropShelfStore.selfDrop = false;
                                    if (!droppedOnShelf && dropAction !== Qt.IgnoreAction)
                                        root.removeAfterDrag(tile.uri);
                                }

                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    z: 1
                                    hoverEnabled: true
                                    cursorShape: tile.linkItem ? Qt.PointingHandCursor : Qt.OpenHandCursor
                                    drag.target: tile
                                    preventStealing: true

                                    onPressed: {
                                        if (!tile.imageFile) {
                                            tileSurface.grabToImage(function(result) {
                                                tile.grabResult = result;
                                                tile.Drag.imageSource = result.url;
                                            });
                                        }
                                    }

                                    onDoubleClicked: {
                                        if (tile.linkItem)
                                            Quickshell.execDetached(["xdg-open", tile.uri]);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
